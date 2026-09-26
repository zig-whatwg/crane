# Architecture: `event_utils.dispatchEvent` invokes no listeners, on purpose

**Date**: 2026-09-22
**Lesson**: `event_utils.fireSimpleEvent` cannot be used to fire an event that
script is supposed to hear.

**Why**: `fireEvent` synthesises a `ContextData` on the CALLER'S STACK when
handed a null context, and `Event.call_constructor` stores it in
`instance.ctx`. The only thing keeping that from becoming a dangling pointer is
that `dispatchEvent` runs no listener, so the event is never wrapped by V8 and
never outlives the frame. The file says so in capitals, and it is correct.

**What Happened**: `script_execution.fireLoadEvent` and `fireErrorEvent` both
went through it, so neither `script.onload = fn` nor
`script.addEventListener("load", fn)` had ever fired for a `<script>` element -
in either direction, for any script, ever. Tests that wait on a script's load
event waited out the full harness timeout, which is most of
`the-script-element/microtasks/` and a good part of `module/`. The symptom is a
hang, so it reads as a scheduling bug rather than a dispatch one.

**Fix**: a script element has a real context whose entry outlives every Instance
in it, so fire at it with `interfaces.EventTarget.call_dispatchEvent` instead -
that walks the event path, invokes listeners, and calls
`invokeIdlEventHandler` for the `on*` IDL attribute. Do NOT `defer
Event.deinit`: a listener can hand the event to script and V8 will hold a
wrapper. `errdefer` only, exactly as `HTMLParser.fireDOMContentLoadedEvent` does.

**Takeaway**: **A stub whose comment explains why it is safe is describing a
precondition, not a TODO. Check whether your caller meets it before reusing it.**
