# Architecture: After DetachGlobal, the old context's Global() is the new Window's proxy

**Date**: 2026-09-26
**Lesson**: A navigation that makes a new Window detaches the global proxy from the old context and hands it to `Context::FromSnapshot` as the new context's global; V8 keeps the OLD native context pointing at that proxy, now attached to the new context.

**Why**: The WindowProxy's identity survives a navigation (Blink `LocalWindowProxy::CreateContext`, V8 `bootstrapper.cc` DetachGlobal / HookUpGlobalProxy). The old global OBJECT is a different thing, and after detaching it is reachable only through a handle taken before.

**What Happened**: Anything that reached "the global" through the old context - teardown looking up the old Window, a retired realm's cleanup - got the new Window instead.

**Fix**: Take the old global object (V1 `GetPrototype` on the proxy) before detaching, and use that handle for the old realm's cleanup (lane/navigation 41d2c27e0).

**Takeaway**: **Take the handles you'll need for cleanup before you detach.**
