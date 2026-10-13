# Spec Compliance: Capture cookie changes before queueing

**Date**: 2026-10-13
**Lesson**: A queued cookie change event owns the records captured for that notification, including their strings, until execution or teardown.

**Why**: Reading a shared pending list when a task runs changes the event's contents according to which other writes happen before dispatch.

**What Happened**: The jar correctly reported each mutation once. CookieStore queued only one task and appended later notifications to its pending list. A Secure-only overwrite after a microtask then reported two changed cookies. The isolated script test failed while the native jar notification control passed. All three aligned stable browsers passed the upstream assertion.

**Fix**:

1. Follow process-cookie-changes steps 1.2–1.4: capture changes, then queue the task. WebKit's `CookieStore::cookiesAdded` and `cookiesDeleted` prepare their event lists before `queueTaskToDispatchEvent`.
2. Move the existing observer's owned list into each existing ChangeTask immediately. Later writes and reentrant listeners get independent tasks.
3. Free captured strings on run, dead-target return, queue drop and task-allocation failure. If recording the clone fails to grow the observer's list, free that clone too.
4. Test consecutive and reentrant mutations and page completion with queued tasks. Use `std.testing.checkAllAllocationFailures` for partial ownership.
5. Prove native test reachability: an intentional failing test inside CookieStore.zig did not execute in `zig build test -Dspec=cookiestore`. Remove such a test and cover the actual task run/drop paths with script fixtures under `leaks --atExit`.

The existing V8 adapter `event_loop.zig` queueTask append-failure branch logs and returns without calling the task's drop. That separate adapter defect is an integrator follow-up (row 27 Q7); ordinary teardown measurements do not exercise or clear it.

Evidence: [process cookie changes](https://cookiestore.spec.whatwg.org/#process-cookie-changes), [WebKit CookieStore.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/cookie-store/CookieStore.cpp), [Blink CookieStore::OnCookieChange](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/cookie_store/cookie_store.cc). Aligned stable WPT revision cc74d2669f: Chrome, Firefox and Safari pass all five attribute-change assertions.

**Takeaway**: **Capture event data at the algorithm's prescribed step, and give the queued task one explicit cleanup path.**
