# Spec Compliance: Sizes validates math before CSS clamping

**Date**: 2026-10-27
**Lesson**: Image sizes needs both the raw result and a zero-division diagnostic before CSS replaces NaN or saturates infinity.

**Why**: The shared CSS math API applies outer-result range rules in computedNumber(): NaN becomes zero and infinities clamp to finite bounds. Simplification also erases division nodes and keyword provenance. A consumer cannot reconstruct those distinctions from the normalized scalar alone.

**What Happened**: The integrator's cache-busted 2026-10-27 probes (codex-fetchlater Q31 and Q39-Q41) tested both img.sizes and source.sizes in Chrome 156, Firefox 158 and Safari 27. All three clamp finite negative math to zero and reject a negative literal. Plain numeric overflow saturates in all three; arithmetic overflow saturates, and overflow cancellation becomes zero, in Chrome and Firefox. Chrome and Safari reject zero division and nonfinite results involving infinity/NaN keywords. A finite keyword branch remains usable in Firefox and Safari, but zero division invalidates even a finite branch. The integrator ruled each observed majority; no single browser's blanket treatment of nonfinite results fits every case.

**Fix**: Parse with the existing length grammar and minimum zero. A caller-owned flag observes a divisor equal to zero before parse-time or compute-time simplification erases it. No flag pointer escapes into the expression, and ordinary CSS callers ignore the diagnostic. Sizes rejects the flag first. For a nonfinite raw result only, it checks the original CSS tokens for escape-decoded infinity/NaN keywords and rejects those cases. Other results use computedNumber(), preserving numeric overflow normalization. Plain lengths clamp after px conversion. Pin the browser cases for both receivers, and pin default CSS arithmetic and serialization byte-for-byte through both entrypoints.

**Takeaway**: **Preserve only the diagnostic a consumer needs before shared simplification erases it; keep the common arithmetic unchanged.**
