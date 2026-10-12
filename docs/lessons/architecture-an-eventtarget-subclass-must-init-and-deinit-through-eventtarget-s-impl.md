# Architecture: An EventTarget subclass must init and deinit through EventTarget's impl

**Date**: 2026-09-26
**Status** (2026-10-12, lane implsb2): superseded in form - an impl no longer names EventTarget's impl to chain. The generated interface's chain runs EventTarget's initOwn/deinitOwn; an impl defines its own part only (codegen-the-generated-interface-is-the-class.md).

**Lesson**: WebSocket kept its own listener registry keyed by address and bypassed EventTarget's init/deinit.

**Why**: An address-keyed side table outlives its object unless its owner's deinit clears it, and the slab reissues addresses.

**What Happened**: `ws.onX` handlers leaked, and a new object at a recycled address could inherit an old one's listeners.

**Fix**: Handlers go through EventTarget's impl, which inits and deinits the state (lane/websockets 2bb83ac96).

**Takeaway**: **An address-keyed side table needs its owner's deinit.**
