# Performance: A settings getter may recompute security

**Date**: 2026-10-19
**Lesson**: Read an expensive settings hook once within a native operation when several steps need the same answer.

**Why**: `global_settings.Settings.is_secure_context` is a function, not a stored boolean. Window's hook computes document and ancestor security through `secure_context.ofDocument`, including URL parsing and temporary allocations. Worker settings can answer the same interface more cheaply; the interface alone does not tell the caller its cost.

**What Happened**: Adding permission keys made a query compute secure-context once for its key and again for its fallback state. Seven alternating priority pairs of 10,000 queries measured a median of 274.1 ms at base and 480.2 ms in that candidate. A one-second sample captured 86 samples inside the query task: 44 and 32 entered the two security-hook call sites. The initial suspicion of a subscription-list scan was not supported by that sample.

**Correction**: Resolve the settings and secure-context result once inside `QueryTask.steps`, then use it for the key and fallback state. This shares work only within that synchronous native operation; it introduces no cache across tasks, navigation or ancestor changes. The rebuilt candidate's seven-pair medians were 265.8 ms at base and 282.9 ms with the feature (+6.43%); XHR was -0.04% and parsing unchanged. The functional comparison gained 19 passing subtests. The duplicate work was removed, but the remaining query cost still required an integrator ruling under the three-percent bar.

**Takeaway**: Profile the hook before redesigning the registry around it. A getter-shaped API can perform an entire algorithm.
