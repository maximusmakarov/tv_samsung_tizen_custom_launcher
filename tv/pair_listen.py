#!/usr/bin/env python3
"""Connect to the TV remote channel and log every message for N seconds; save a token if one arrives."""
import json, ssl, sys, time, base64, os
import websocket

TV_IP = os.environ.get("TV_IP")
if not TV_IP:
    raise SystemExit("set TV_IP to the TV LAN address")
PORT = 8002
name = sys.argv[1] if len(sys.argv) > 1 else "dsh-agent"
secs = int(sys.argv[2]) if len(sys.argv) > 2 else 25
b64 = base64.b64encode(name.encode()).decode()
url = f"wss://{TV_IP}:{PORT}/api/v2/channels/samsung.remote.control?name={b64}"
ws = websocket.create_connection(url, timeout=5, sslopt={"cert_reqs": ssl.CERT_NONE, "check_hostname": False})
end = time.time() + secs
while time.time() < end:
    try:
        raw = ws.recv()
    except Exception as e:
        print("recv-exc", e, flush=True); break
    print("MSG", raw, flush=True)
    try:
        msg = json.loads(raw)
    except Exception:
        continue
    ev = msg.get("event")
    if ev == "ms.channel.connect":
        tok = (msg.get("data") or {}).get("token")
        if tok:
            tf = os.path.join(os.path.dirname(os.path.abspath(__file__)), "token.json")
            data = {}
            try: data = json.load(open(tf))
            except Exception: pass
            data[f"{TV_IP}|{name}"] = tok
            json.dump(data, open(tf, "w"), indent=2)
            print("SAVED_TOKEN", tok, flush=True)
ws.close()
