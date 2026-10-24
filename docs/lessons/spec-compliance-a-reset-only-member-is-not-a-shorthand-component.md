# Spec Compliance: A reset-only member is not a shorthand component

**Date**: 2026-10-24
**Lesson**: Model the properties a shorthand resets separately from the components its grammar serializes.

**Why**: Adding a reset-only property to a shared longhand list changes every consumer of that list, including code that divides it into repeated component groups.

**What Happened**: Adding border-image-source to border's longhands correctly included CSS-wide expansion and removal, but border serialization had assumed the list held exactly four width/style/color triplets. The extra reset-only member is not a fifth component to serialize.

**Fix**: Keep border-image-source in the reset set, append its initial value when parsing ordinary border syntax, and require that value to be initial before serializing border. Iterate the four actual sides explicitly. Pin side-shorthand preservation, reset order, CSS-wide values and shorthand omission in native and script tests.

**Takeaway**: **A shorthand's reset set can be larger than its visible grammar; test both directions.**
