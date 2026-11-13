# Architecture: A cache keyed by an object's address must exclude objects their owner rewrites in place

**Date**: 2026-11-11
**Lesson**: Pointer correspondence ("the same declaration block") is exact only for objects that never change while the cache can see them; a per-element block kept by value in the element's state keeps its address when the element's style attribute changes, so a cache comparing addresses would answer the old style for the new value.

**Why**: Lane style1 batch 2 made the matched-properties cache skip the cascade on a hit, comparing each matched declaration block by address, as WebKit's MatchedDeclarationsCache does. That is safe for a rule's block: every sheet, rule or CSSOM change moves the style engine's generation, which clears the cache before any compare. It is not safe for the blocks an element owns: `ElementStyle.inline_block` is a `?DeclarationBlock` stored BY VALUE, so `setAttribute('style', ...)` reparses into the same address; the background and font presentational hints live in the element's state too, and a freed element's state is reused by the next element.

**What Happened**: The first engine test for style attributes checked only that 100 rows with `style="margin-top: 3px"` computed 3px, which passes even without the exclusion (each row's block has its own address). The test that bites changes ONE element's style attribute in place and reads it again: the same block address, the same parent, the same Source - a lookup that compares addresses finds the old entry. The engine now never looks up a resolution that matched a block of the element's own (`Resolution.own_blocks`, set where collectMatched appends the style attribute's and the hints' blocks); WebKit makes a mutable inline set uncacheable for the same reason, and Blink compares inline sets by content.

**Fix**:
1. List every object the key compares by address and ask who frees or rewrites each one, and when.
2. Objects that live as long as the cache's generation (a sheet's rules) can be compared by address; objects with a shorter or per-element life must be excluded, compared by content, or held by the cache.
3. Test the in-place rewrite, not only distinct objects: change one owner's value and read it again.

**Takeaway**: **An address is an identity only while nobody can rewrite or reuse the object behind it: exclude per-owner objects from pointer correspondence, and test the in-place change.**
