# Spec compliance: Recognizing a property can change its CSSOM readback

**Date**: 2026-10-25
**Lesson**: Registering a property changes the path that stores it, including values its typed grammar cannot yet accept.

**Why**: An unsupported name may be preserved as unparsed text. Once the name is recognized, a failed typed parse can discard text that CSSOM previously returned.

**What Happened**: Registering the font shorthand moved var()/env() values from generic unparsed storage into a parser that rejects substitution functions. Two existing CSSOM serialization PASS names became failures. The typed font tests and full native gates still passed; a comparison by subtest identity found the loss and three isolated pairs reproduced it.

**Fix**: Audit the old storage route when adding a property name. Test both parsed blocks and setProperty, shorthand getters, constituent getters, cssText, priority, replacement and removal. The temporary shared shorthand readback seam was explicitly scoped to original-text storage; its comments and tests name the missing per-longhand pending model. Mixed declarations and overlapping shorthands need explicit invalidation and priority rules even when the stored value is opaque. Validate ownership with source destruction and all-allocation-failure tests, then require every baseline PASS name to survive.

**Takeaway**: **Property registration changes storage semantics as well as grammar acceptance; preserve the old observable contract or deliver its complete replacement.**
