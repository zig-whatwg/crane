# Testing: A counter that drifts per call hides a leak per call

**Date**: 2026-09-27
**Lesson**: `live_context_globals` fell by one per binding getter or method call, because one creation site was never counted. So a one-per-read Context Global leak read as 0.00, and a leak-free lane read -1.00.

**Why**: `v8_Context_Dispose` subtracts one for every Context Global it is handed. `v8_FunctionCallbackInfo_GetFunctionCreationContext` makes one with no `fetch_add`, and every getter and method callback takes it and then disposes it. Twelve more creation sites did the same: GetCreationContext, the prototype and function creation contexts, GlobalHandle_New, and the Context_New* / NewFromSnapshot* family, which is where engine-boundary's -1 per worker realm came from.

**What Happened**: With `gc_bench --body`, main read +1.00 per `probe.ownerDocument` and the lane read -1.00. So did the control, `probe.nodeType`. Only the difference from the control carried the result: main kept one Context Global per lazy read (callLazyGetter's undisposed GetCurrentContext), and the lane kept none.

**Fix**: Every function in v8_wrapper.cpp that returns a new Global<Context> calls `countContextGlobal()`. tests/v8/context_counter_test.zig pins the balance for 128 binding calls and for contexts made and disposed, so a creation site added without its count turns it red. `global_handle_bytes`, V8's own used-global-handles size, is now among the diagnostic counters as the cross-check with no bookkeeping in it.

**Takeaway**: **Read a leak counter against a control statement run the same way, and cross-check it with V8's global handle bytes. A counter kept by hand is only as good as its least-counted creation site.**
