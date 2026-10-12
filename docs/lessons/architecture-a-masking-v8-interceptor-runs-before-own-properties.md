# Architecture: A masking V8 interceptor runs before the holder's own properties

**Date**: 2026-10-12
**Lesson**: A named interceptor installed without kNonMasking is consulted before the object's own properties, so it must ask WebIDL's own-property question itself.

**Why**: V8's LookupIterator visits a holder's interceptor before the holder's own properties (src/objects/lookup.cc, LookupInSpecialHolder). Only a kNonMasking interceptor is skipped until the own properties and the prototype chain have no P (SkipInterceptor). Crane installs a masking interceptor for [LegacyOverrideBuiltIns]. The named property visibility algorithm (WebIDL 3.9.7) still says, at step 2, that an own property named P hides the named property. [LegacyOverrideBuiltIns] skips only the prototype chain (step 3).

**What Happened**: namedGet asked a masking interceptor only step 1, whether P is a supported name, on the reading that V8 had answered the rest. It had not. With Codex row 23's form named getter, `form.x = 5` followed by appending `<input name=x>` read the input instead of 5 (form-nameditem.html, two subtests; codex-lpo Q9). The query, descriptor and deleter interceptors already ran the whole algorithm, so only reads were wrong.

**Fix**: For a masking WebIDL interceptor, namedGet runs isVisible (steps 1-3), as the forwarded-index path already did. A non-masking interceptor asks step 1 only. isVisible checks own properties only for a supported name, so a property miss costs nothing more (lane bindlpo, 37ee1c0ecc).

**Takeaway**: **Before an interceptor skips a step of the spec's algorithm because "V8 already did it", check the order: with kNonMasking V8 has looked at own properties and the prototype chain, and without it V8 has looked at nothing.**
