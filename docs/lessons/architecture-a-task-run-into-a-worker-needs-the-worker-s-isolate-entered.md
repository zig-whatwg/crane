# Architecture: A task run into a worker needs the worker's isolate entered

**Date**: 2026-09-26
**Lesson**: A WebSocket created in a worker was pumped from the page's timer with a HandleScope on the worker's isolate and its context entered, but without `v8_Isolate_Enter` - so its events never reached the worker.

**Why**: Worker isolates share the page's thread; every entry into worker script from outside its own trampoline must enter the isolate, open a scope, enter the context, and finish the worker's turn (docs/lessons/architecture-a-task-fired-into-a-worker-from-outside-must-end.md).

**What Happened**: The old code carried a comment saying three attempts had failed, so the cause must be elsewhere; 17 Close-* files timed out on it. The missing step was already written down in the AbortSignal lesson.

**Fix**: Enter the isolate, then a JsScope, then `finishTaskIn` (lane/websockets 4f661b969).

**Takeaway**: **A dead end written in a comment is a hypothesis; grep `docs/lessons/` for the symptom first.**
