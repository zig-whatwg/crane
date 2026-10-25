# Architecture: Dependencies must follow effective values

**Date**: 2026-10-24
**Lesson**: Query dependencies over the components computation will actually evaluate.

**Why**: An aggregate may preserve overridden input for specified serialization while ignoring it when computing its value.

**What Happened**: Font feature and variation settings preserve repeated tags in specified order, but the last occurrence wins. Counting a superseded tag's tree, random or unavailable-metric dependency can incorrectly reject a computable candidate or request an input that computation never uses.

**Fix**: Use the same last-occurrence predicate in computation and all dependency queries. Preserve every specified entry for serialization. Test both orders of duplicate tags, inherited ownership, and the winning cascade source under allocation failure.

**Takeaway**: **Dependency discovery must agree with evaluation, including which inputs are superseded.**
