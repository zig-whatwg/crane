# Testing: An allocation per element makes the allocation-failure sweep quadratic

**Date**: 2026-10-23
**Lesson**: A parser that allocates once per element (per glyph, per record) turns `std.testing.checkAllAllocationFailures` quadratic: it reruns the whole parse once per allocation, so a font with thousands of glyphs never finishes.

**Why**: `checkAllAllocationFailures` first counts the allocations a successful run makes, then reruns the function that many times, failing allocation 0, 1, 2, ... in turn. Each rerun parses everything before the failing allocation, so the total work is about (allocations x elements). With one allocation per element, that is elements squared.

**What Happened**: kit/sfnt (lane fontcap1) checked each simple glyph by allocating a flags array, and each composite's components with a fresh stack. On WPT's Ahem.ttf the font_decoding allocation-failure test already took 21 s. In a Linux container, the same test reached fontconfig's DejaVu Sans Mono (about 3,000 glyphs) through `genericFontFace` and ran for over ten minutes without finishing. The parse itself was fast; nothing hung. The test simply ran 3,000+ full parses of 3,000 glyphs each.

**Fix**: Read a simple glyph's flag stream twice instead of storing it: once to check it and size the x coordinates, once to read the y coordinates that follow them. Keep one component stack for the whole glyf table and clear it per composite. Checking a font now costs a handful of allocations whatever its size, and the sweep over DejaVu finishes with the rest of the suite.

**Takeaway**: **Allocate per input, never per element, in code that parses untrusted data. If an allocation-failure sweep is slow, count the allocations before suspecting a hang.**
