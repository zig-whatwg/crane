# Architecture: A proxy with a `get` trap pays an invariant check on every read

**Date**: 2026-09-23
**Lesson**: ES 10.5.8 step 9 makes V8 compare a `get` trap's result against the target's own property descriptor on every read. On a legacy platform object that descriptor comes from our indexed interceptor, so `list[i]` built a descriptor object per access - two thirds of a profiled NodeList loop.

**Fix**: no `get` trap (2eb625514). V8 then forwards `[[Get]]` with the proxy as receiver, which is safe because every path that unwraps a receiver's internal fields looks through a proxy. NodeList index read 3.4 us -> 0.7 us. The `NodeList-static-length-getter-tampered-*` files do ~125M indexed reads and still need about 10x more; the remaining cost is a heap-allocated `Global` per handle crossing the FFI, plus `v8_wrapper.cpp` compiled at `-O0` in Debug.

**Takeaway**: **Profile before optimising a binding: the cost was in V8's proxy semantics, not in our code.**
