# Debugging: An interface on the bindings' skip list is never installed - its impl can be finished and script still sees nothing

**Date**: 2026-10-16
**Lesson**: `src/runtime/engines/v8/interface_bindings.zig`'s `interface_skip_list` keeps an interface off every global, whatever its impl does. A Zig-made instance of a skipped interface still dispatches, but V8 has no template to wrap it in: a listener is called with `undefined`, and `typeof Name` is "undefined".

**Why**: The skip list was written when codegen could not bind some types (unions, unknown typedefs). Its entries carry a reason and no test, so nothing notices when the reason stops being true, and the impl behind it can be completed by a lane that never reads the list.

**What Happened**: Lane sw1-b2 implemented ServiceWorker.postMessage and the ExtendableMessageEvent the service worker's thread dispatches. The trace showed every step - posted, the worker started, the task run, the event dispatched - and crane/sw1b2-messages.https.html still timed out. A BroadcastChannel from the worker reported the listener's view: `typeof e` was "undefined" and `ExtendableMessageEvent is not defined`. Both ExtendableMessageEvent ("Union type issues") and WindowClient ("Missing VisibilityState type") were on the skip list; with the two lines deleted the bindings built clean and the test went TIMEOUT 1/6 -> OK 6/6.

**Fix**: Delete the stale entries (granted - the file is the V8 adapter's), and check `typeof Interface` from the realm that should expose it before debugging the path that makes its instances.

**Takeaway**: **When an event is dispatched but its listener sees `undefined`, check that the event's interface is installed at all - grep the bindings' skip list before tracing the dispatch.**
