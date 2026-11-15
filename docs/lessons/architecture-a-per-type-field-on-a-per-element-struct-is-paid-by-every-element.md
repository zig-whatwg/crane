# Architecture: A per-type field on a per-element struct is paid by every element; a per-element copy of shared data is paid again

**Date**: 2026-11-14
**Lesson**: A pointer that only a few element types use, added to a struct every element allocates (ElementStyle), costs 8 bytes on every element. Merge such rare per-type pointers into one tagged slot. Data that many elements hold equal (a presentational hint's declarations) belongs in a cache shared by key, not in a copy per element.

**Why**: ElementStyle is allocated for every element whose style is computed. Its two small fields leave 6 bytes of padding, so a third pointer does not fit; it adds 8 bytes to every div. The background hint (eight HTML table and body tags), the font hint (HTML font) and the SVG presentation hint (SVG elements) belong to disjoint sets of element types, so one element never needs two of them. Separately, each SVG element's own hint (its declarations, a copy of its attributes, a block) was +583 bytes per element with one presentation attribute, while equal attributes give equal blocks.

**What Happened**: Lane quick1 b4 put SVG presentation attributes into the cascade. A plain `svg_hint` field would have grown every ElementStyle by 8 bytes. Merging the background and font pointers with the new one into `hint: ?*Hint` (a kind tag each hint type starts with; a slot asked to hold a second kind panics) made ElementStyle 280 -> 272 bytes instead (pinned in tests/dom/node_block_sizes_test.zig). A bytes-per-element smoke then showed an SVG rect with fill="blue" at 1,650 bytes against main's 1,067. A per-document cache keyed by the local name, the attributes' names and values in name order, and the base URL when a value has url() - Blink's PresentationAttributeCache design, bounded at its 4,096 entries and cleared past them - brought it to 1,069. The same measurement showed HTML's font hint at about +370 bytes per element, which is now a queue item.

**Fix**:
1. Before adding a field to a struct every element allocates, check whether a few element types use it. If so, put it in a shared tagged slot, or pin the struct's size first and justify the growth.
2. Before caching per element, measure bytes per element (a retained page of 100,000 elements, control subtracted) with and without the attribute.
3. Share immutable per-element data through a refcounted, bounded cache keyed by everything that changes its content. Give the map a TombstoneGuard if its entries come and go.

**Takeaway**: **Measure bytes per element before and after. A rare per-type pointer belongs in one tagged slot, and data equal across elements belongs in a shared cache, not in every element.**
