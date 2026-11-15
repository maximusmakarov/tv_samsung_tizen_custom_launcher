#!/usr/bin/env python3
"""Grab one still from the Mac's camera (aim it at the TV) for visual verification.

Usage:  .venv/bin/python tv/snap.py [out.jpg]
Needs macOS camera permission for the process running this script (grant once).
"""
import sys, time
import cv2

out = sys.argv[1] if len(sys.argv) > 1 else "backup/live/tv.jpg"
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("CAMERA_NOT_OPENED", file=sys.stderr)
    sys.exit(2)
# warm up: the first frames from the built-in camera are dark/blurry
for _ in range(12):
    ok, frame = cap.read()
    if not ok:
        time.sleep(0.1)
        continue
ok, frame = cap.read()
cap.release()
if not ok or frame is None:
    print("CAMERA_NO_FRAME", file=sys.stderr)
    sys.exit(3)
cv2.imwrite(out, frame)
print(out, frame.shape[1], "x", frame.shape[0])
