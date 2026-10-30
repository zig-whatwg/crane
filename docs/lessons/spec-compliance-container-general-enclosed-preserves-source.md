# Spec Compliance: Container general-enclosed preserves source

**Date**: 2026-10-27
**Lesson**: Keep authored container-query source available until the recognized grammar has been distinguished from general-enclosed.

**Why**: A known feature has canonical names, operators and values. An unknown or deferred production is an extensibility branch whose serialization preserves its source. Normalizing the whole prelude before that distinction loses information that later serialization cannot recover.

**What Happened**: Crane's generic at-rule prelude serializer would normalize function spelling, token separators and values before the container parser received them. That is wrong for unknown functions and for ordinary-property style queries deliberately deferred by all three browsers. The 2026-10-27 Q28/Q42 probe preserves `style( COLOR : RED )`, while recognized custom-property and size queries have their own serialization rules.

**Fix**: Bound the container prelude with token-stream positions and preserve its authored text. Parse components with source spans, try recognized productions first, and retain the complete source span when taking general-enclosed. Apply CSS input preprocessing without rewriting that source as a recognized feature. Keep parsing separate from query evaluation: an unevaluated container body remains inert.

**Takeaway**: **An extensible grammar needs its original source until the parser knows which serialization algorithm applies.**
