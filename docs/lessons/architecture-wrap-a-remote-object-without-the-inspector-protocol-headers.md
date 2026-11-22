# Architecture: Wrap a RemoteObject without V8's generated inspector headers - the session's `$0`

**Date**: 2026-11-21
**Lesson**: The V8 prebuilt ships `v8-inspector.h` but not the generated `inspector/Runtime.h`, so `V8InspectorSession::wrapObject` and `V8StackTrace::buildInspectorObject` cannot be used (incomplete return types); a host that must hand a value to a CDP client as a RemoteObject makes it the session's inspected object and evaluates the command line API's `$0`.

**Why**: `wrapObject` returns `std::unique_ptr<protocol::Runtime::API::RemoteObject>`, a type declared only in the generated headers; without them it cannot even be destroyed. The public API that remains - `addInspectedObject`, `dispatchProtocolMessage`, `unwrapObject`, `V8StackTrace::frames()` - is enough.

**What Happened**: CDP's DOM.resolveNode must answer a RemoteObject of the CLIENT's session for a node in a given world (Puppeteer adopts every element handle between worlds through describeNode -> resolveNode). Lane cdph found the headers missing (tmp/plans/cdph-inspector-notes.md); lane cdpw built engine.inspectorWrap on `$0`.

**Fix**: `session->addInspectedObject(Inspectable holding the value)`, then dispatch on the same session `{"id":<negative>,"method":"Runtime.evaluate","params":{"expression":"$0","includeCommandLineAPI":true,"silent":true,"contextId":<the realm's id>,"objectGroup":<group>}}`; the channel captures the reserved negative id's response (never forwarded) and the host reads `result.result`. The objectId is that session's, as the client needs. A stack for a host-built message is `V8StackTrace::frames()` serialized by hand (V8StackFrame's lines are 1-based; CDP's 0-based). (v8_wrapper.cpp CraneInspectorSession::Wrap, v8_Inspector_StackTrace.)

**Takeaway**: **When an engine's convenience API needs headers the prebuilt lacks, look for the public protocol path that produces the same object - here the session's own Runtime.evaluate of `$0` - rather than shipping private headers or re-implementing the protocol's serialization.**
