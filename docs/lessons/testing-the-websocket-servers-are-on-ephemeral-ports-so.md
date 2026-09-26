# Testing: The WebSocket servers are on EPHEMERAL ports, so `lsof :9001` proves nothing

**Date**: 2026-09-22
**Lesson**: `tests/wpt/config.json` pins the http and https ports and omits
`ws`/`wss`, so wptserve assigns those two at random on every start - one run
had `ws on port 62088` and `wss on port 62089`. Tests reach them through
`constants.sub.js` substitution, so that is not a defect. What it defeats is
the obvious probe: `lsof -iTCP:9001` is empty, and reads as "no WebSocket
server".

**What Happened**: two working websockets sweeps were killed as "doomed -
nothing is listening on the WebSocket port", on that probe alone. The runner
also spawns the server with `.stdout = .ignore, .stderr = .ignore`, so the
lines that would have shown the real ports were thrown away. Running
`python3 wpt.py serve --config config.json` by hand for thirty seconds with
its output kept showed them at once.

**Fix**: ask the server, not the port: `lsof -nP -a -p <pid> -iTCP
-sTCP:LISTEN`; any two ports outside 8000-9000 are ws and wss. Pin `ws`/`wss`
in `config.json` if a fixed port ever matters.

**Takeaway**: **A negative probe on a port you assumed is not evidence.** Run
the server by hand with its output visible before concluding a component is
missing.
