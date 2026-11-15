#!/usr/bin/env python3
"""Samsung Tizen TV remote control over the LAN websocket API (port 8002).

Usage:
  tv_remote.py pair            # pair: TV shows "Allow connection", press Allow; saves token
  tv_remote.py key KEY_HOME    # send one key (repeatable)
  tv_remote.py keys KEY_HOME KEY_DOWN KEY_ENTER
  tv_remote.py --name NAME ... # custom client name shown on the TV dialog

Token is stored in tv/token.json (per TV IP + client name).
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import ssl
import sys
import time

import websocket

TV_IP = os.environ.get("TV_IP")
if not TV_IP:
    raise SystemExit("set TV_IP to the TV LAN address")
TV_PORT = int(os.environ.get("TV_PORT", "8002"))
DEFAULT_NAME = os.environ.get("TV_CLIENT_NAME", "dsh-agent")
HERE = os.path.dirname(os.path.abspath(__file__))
TOKEN_FILE = os.path.join(HERE, "token.json")

KEY_ALIASES = {
    "HOME": "KEY_HOME",
    "BACK": "KEY_RETURN",
    "OK": "KEY_ENTER",
    "ENTER": "KEY_ENTER",
    "UP": "KEY_UP",
    "DOWN": "KEY_DOWN",
    "LEFT": "KEY_LEFT",
    "RIGHT": "KEY_RIGHT",
    "MENU": "KEY_MENU",
    "EXIT": "KEY_EXIT",
    "TOOLS": "KEY_TOOLS",
    "SOURCE": "KEY_SOURCE",
    "GUIDE": "KEY_GUIDE",
    "INFO": "KEY_INFO",
    "POWER": "KEY_POWER",
    "PLAY": "KEY_PLAY",
    "PAUSE": "KEY_PAUSE",
    "CHUP": "KEY_CHUP",
    "CHDOWN": "KEY_CHDOWN",
    "VOLUP": "KEY_VOLUP",
    "VOLDOWN": "KEY_VOLDOWN",
    "MUTE": "KEY_MUTE",
}


def norm_key(k: str) -> str:
    k = k.strip().upper()
    if not k.startswith("KEY_"):
        k = KEY_ALIASES.get(k, k)
    if k.isdigit():
        k = "KEY_" + k
    return k


def load_token(name: str) -> str | None:
    try:
        with open(TOKEN_FILE) as f:
            data = json.load(f)
        return data.get(f"{TV_IP}|{name}")
    except Exception:
        return None


def save_token(name: str, token: str) -> None:
    data = {}
    try:
        with open(TOKEN_FILE) as f:
            data = json.load(f)
    except Exception:
        pass
    data[f"{TV_IP}|{name}"] = token
    os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
    with open(TOKEN_FILE, "w") as f:
        json.dump(data, f, indent=2)
    os.chmod(TOKEN_FILE, 0o600)


def url_for(name: str, token: str | None) -> str:
    b64name = base64.b64encode(name.encode()).decode()
    u = (f"wss://{TV_IP}:{TV_PORT}/api/v2/channels/samsung.remote.control"
         f"?name={b64name}")
    if token:
        u += f"&token={token}"
    return u


def connect(name: str, token: str | None, timeout: float = 10.0):
    ws = websocket.create_connection(
        url_for(name, token),
        timeout=timeout,
        sslopt={"cert_reqs": ssl.CERT_NONE, "check_hostname": False},
    )
    return ws


def pair(name: str, attempts: int = 60, per_attempt: float = 20.0) -> int:
    """Keep a pairing connection alive so the TV dialog can be accepted."""
    print(f"pairing as {name!r} with {TV_IP}:{TV_PORT}; attempts={attempts}", flush=True)
    for i in range(1, attempts + 1):
        try:
            ws = connect(name, None, timeout=per_attempt)
        except Exception as e:  # noqa: BLE001
            print(f"[{i}] connect failed: {e}", flush=True)
            time.sleep(4)
            continue
        deadline = time.time() + per_attempt
        got = None
        try:
            while time.time() < deadline:
                ws.settimeout(max(1.0, deadline - time.time()))
                try:
                    raw = ws.recv()
                except websocket.WebSocketTimeoutException:
                    continue
                except Exception as e:  # noqa: BLE001
                    print(f"[{i}] recv error: {e}", flush=True)
                    break
                if not raw:
                    continue
                try:
                    msg = json.loads(raw)
                except Exception:
                    print(f"[{i}] non-JSON: {raw!r}", flush=True)
                    continue
                ev = msg.get("event") or msg.get("method")
                print(f"[{i}] event={ev} raw={raw[:400]}", flush=True)
                if ev == "ms.channel.connect":
                    tok = (msg.get("data") or {}).get("token")
                    if tok:
                        save_token(name, tok)
                        print(f"PAIRED token={tok}", flush=True)
                        return 0
                    print("connected without token?", flush=True)
                    return 0
                if ev == "ms.channel.unauthorized":
                    got = "unauthorized"
                    break
        finally:
            try:
                ws.close()
            except Exception:
                pass
        if got == "unauthorized":
            print(f"[{i}] unauthorized (press Allow on the TV)", flush=True)
        time.sleep(3)
    print("PAIRING FAILED", flush=True)
    return 1


def send(name: str, keys: list[str], delay: float = 0.6, wait: float = 4.0) -> int:
    token = load_token(name)
    ws = connect(name, token, timeout=wait)
    connected = False
    deadline = time.time() + wait
    try:
        while time.time() < deadline and not connected:
            ws.settimeout(max(1.0, deadline - time.time()))
            try:
                raw = ws.recv()
            except websocket.WebSocketTimeoutException:
                break
            except Exception:  # noqa: BLE001
                break
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            ev = msg.get("event") or msg.get("method")
            if ev == "ms.channel.connect":
                connected = True
                print("channel ready", flush=True)
            elif ev == "ms.channel.unauthorized":
                print("UNAUTHORIZED: token invalid, re-pair", file=sys.stderr)
                return 3
        if not connected:
            print("no ms.channel.connect; trying anyway", file=sys.stderr)
        for k in keys:
            cmd = {
                "method": "ms.remote.control",
                "params": {
                    "Cmd": "Click",
                    "DataOfCmd": k,
                    "Option": "false",
                    "TypeOfRemote": "SendRemoteKey",
                },
            }
            ws.send(json.dumps(cmd))
            print(f"sent {k}", flush=True)
            time.sleep(delay)
        time.sleep(0.4)
        return 0
    finally:
        try:
            ws.close()
        except Exception:
            pass


def send_text(name: str, text: str) -> int:
    """Send text (works on TVs that accept SendInputString)."""
    token = load_token(name)
    ws = connect(name, token)
    try:
        cmd = {
            "method": "ms.remote.control",
            "params": {
                "Cmd": "SendInputString",
                "DataOfCmd": base64.b64encode(text.encode()).decode(),
                "TypeOfRemote": "SendInputString",
            },
        }
        ws.send(json.dumps(cmd))
        time.sleep(1)
        return 0
    finally:
        try:
            ws.close()
        except Exception:
            pass



def hold(name: str, key: str, seconds: float = 5.0) -> int:
    """Long-press a key: Press, wait, Release (e.g. KEY_POWER for 5 s = restart)."""
    token = load_token(name)
    ws = connect(name, token, timeout=8.0)
    try:
        deadline = time.time() + 6.0
        while time.time() < deadline:
            ws.settimeout(2.0)
            try:
                raw = ws.recv()
            except Exception:
                break
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            if (msg.get("event") or msg.get("method")) == "ms.channel.connect":
                break
        for act in ("Press", "Release"):
            ws.send(json.dumps({"method": "ms.remote.control", "params": {
                "Cmd": act, "DataOfCmd": key, "Option": "false",
                "TypeOfRemote": "SendRemoteKey"}}))
            print(f"sent {act} {key}", flush=True)
            if act == "Press":
                time.sleep(seconds)
        return 0
    finally:
        try:
            ws.close()
        except Exception:
            pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", default=DEFAULT_NAME)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("pair")
    p.add_argument("--attempts", type=int, default=60)
    p.add_argument("--per-attempt", type=float, default=20.0)
    k = sub.add_parser("key")
    k.add_argument("keys", nargs="+")
    k.add_argument("--delay", type=float, default=0.6)
    sub.add_parser("token")
    t = sub.add_parser("text")
    t.add_argument("text")
    h = sub.add_parser("hold")
    h.add_argument("key")
    h.add_argument("--seconds", type=float, default=5.0)
    args = ap.parse_args()

    if args.cmd == "pair":
        return pair(args.name, args.attempts, args.per_attempt)
    if args.cmd == "key":
        return send(args.name, [norm_key(x) for x in args.keys], args.delay)
    if args.cmd == "text":
        return send_text(args.name, args.text)
    if args.cmd == "hold":
        return hold(args.name, norm_key(args.key), args.seconds)
    if args.cmd == "token":
        print(load_token(args.name) or "no token")
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
