# Architecture: A paused thread is answered through shared state, never through its own task queue

**Date**: 2026-11-21
**Lesson**: When a Browser's thread pauses (HTML's "pause" for alert/confirm/prompt/beforeunload, the debugger's nested loop), whoever answers it from another thread must reach a lock-guarded record and a futex word - not post a task to that thread's loop, which is exactly what is not running.

**Why**: HTML's pause forbids the event loop from running further tasks; a debugger pause (V8 runMessageLoopOnPause) runs only the inspector's messages. A host on another thread - WebDriver's Accept Alert, CDP's Page.handleJavaScriptDialog on the devtools thread, Debugger.resume - would deadlock if its answer were a posted command (BrowserHost.call blocks until the paused thread runs it, which it never does). And a host's waits on that thread (a navigation's readiness, an evaluation) never end on their own while it is paused.

**What Happened**: Lane cdph's host API sent every command through the Browser's TaskSink. Designing dialogs for CDP and WebDriver (with lane cdpt, through the integrator, 8:06-8:09 PM ET 2026-11-21), every answer path would have been a posted task. Chrome answers dialogs in the browser process (PageHandler) and Blink runs paused-debugger messages from InspectorTaskRunner's interrupting queue inside ClientMessageLoop.

**Fix**: One primitive, two policies (src/runtime/browser_pause.zig): the paused thread waits on a futex word that any thread bumps; `.dialog` waits for its answer alone, `.debugger` also runs the session messages queued for it (BrowserHost.postSessionMessage puts each page-session message on that queue AND posts a loop task that runs the oldest, so normal operation stays FIFO). A dialog's answer is a thread-safe record per Browser (html.simple_dialogs.PendingPrompt, first answer wins, serials ignore late platform replies) whose DialogAnswer any host calls. A dialog opening also ends the host's own waits on that tab (error.UserPromptOpen), from the Browser thread, before it pauses.

**Takeaway**: **Design the answer path of every pause first: it must work while the paused thread runs nothing - shared state plus a wake, never a task for that thread.**
