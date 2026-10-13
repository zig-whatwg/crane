# Testing: A named interceptor changes ordinary property reads

**Date**: 2026-10-12
**Lesson**: Benchmark ordinary property reads whenever implementing a named getter causes a masking interceptor to be installed.

**Why**: A LegacyOverrideBuiltIns interceptor runs before normal properties and prototype lookup. Its supported-name query therefore runs even when a page never uses named access.

**What Happened**: Row 23 implemented HTMLFormElement's named getter. The binding consequently asked for the full supported-name list on every `form.submit`, `form.elements`, `form.method` and `form.addEventListener` read. Constructing that list walked the document. Review measured roughly 37–550 microseconds per read as documents grew from 100 to 5,000 divs. The existing parser benchmark contained no forms and missed the regression.

**Fix**: Add a repeatable benchmark with a 20-input form and 100, 1,000 and 5,000 unrelated divs. Measure ordinary reads, named hits and collection hits separately, with div reads as the control. Cache only data whose invalidation and lifetime are established; test form attributes, target IDs, insertion, adoption and custom-element upgrades before relying on a tree version. The adapter's eventual per-name query must be measured with this same benchmark.

**Takeaway**: **The cost of registering an interceptor includes ordinary operations that fall through it. Exercise those operations explicitly.**
