# Architecture: An EventTarget subclass must init and deinit through EventTarget's impl

**Date**: 2026-09-26
**Lesson**: WebSocket kept its own listener registry keyed by address and bypassed EventTarget's init/deinit.

**Why**: An address-keyed side table outlives its object unless its owner's deinit clears it, and the slab reissues addresses.

**What Happened**: `ws.onX` handlers leaked, and a new object at a recycled address could inherit an old one's listeners.

**Fix**: Handlers go through EventTarget's impl, which inits and deinits the state (lane/websockets 2bb83ac96).

**Takeaway**: **An address-keyed side table needs its owner's deinit.**
