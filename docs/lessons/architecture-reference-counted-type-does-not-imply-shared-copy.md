# Architecture: A reference-counted type does not imply a shared copy

**Date**: 2026-10-28
**Lesson**: Follow the actual copy constructor through every owned container before describing an engine's ownership model.

**Why**: A type can inherit a reference counter while its ordinary copy constructor allocates and copies the payload. A container's copy may also clone storage. The type name, a pointer field, and the destructor's release operation do not establish which operation acquires ownership during a copy.

**What Happened**: During the CSS nesting work, I incorrectly reported that WebKit's immutable CSSSelector copy retained RareData, while only its mutable overload deep-copied. That claim became part of a proposed fix for Crane's measured exponential selector storage. A later audit, before the shared-owner code was applied, found that the pinned ordinary constructor calls RareData.deepCopy, the RareData copy constructs another CSSSelectorList, and FixedVector clones its storage. The mutable overload delegates to the ordinary constructor. I retracted the claim and sent the corrected evidence for another design ruling. The integrator reaffirmed the counted-node design on Crane's measured storage and lifetime tests, explicitly separating those grounds from browser precedent. The storage measurements themselves were unchanged.

**Fix**: Read the constructor, the payload's constructor, the owning container's copy, and the destructor as one ownership chain. Record the exact revision and distinguish a borrowed semantic design from a new ownership mechanism. Pin the latter independently with reference-count, copied-holder, mutation, allocation-failure and final-zero tests.

Primary sources: [CSSSelector's copy constructors](https://github.com/WebKit/WebKit/blob/3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c/Source/WebCore/css/CSSSelector.cpp#L825), [CSSSelectorList's copy](https://github.com/WebKit/WebKit/blob/3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c/Source/WebCore/css/CSSSelectorList.cpp#L40), and [FixedVector's copy](https://github.com/WebKit/WebKit/blob/3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c/Source/WTF/wtf/FixedVector.h#L48).

**Takeaway**: **The operation that acquires ownership defines the copy contract; the existence of a reference counter does not.**
