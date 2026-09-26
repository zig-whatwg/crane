# Architecture: A short `curl_ws_send` is the middle of a frame

**Date**: 2026-09-26
**Lesson**: When `curl_ws_send` takes fewer bytes than offered, curl keeps the frame open; the next call must pass the rest of the same frame.

**Why**: Treating a short write as an error and moving on to the next message corrupted the stream.

**What Happened**: Large sends and `bufferedAmount` were wrong; frames were dropped under backpressure.

**Fix**: The send queue's head can be part-sent, and it is resumed before anything else (lane/websockets 2bb83ac96).

**Takeaway**: **A partial write is state, not an error.**
