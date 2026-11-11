# Testing: A small per-object saving is read from heap's block-size histogram, not from the footprint

**Date**: 2026-11-11
**Lesson**: To measure a saving of a few bytes per element on a real page (tens of kilobytes in megabytes), read the live process with macOS `heap` and compare the counts of each small block size between base and tip. The footprint and even heap's total-bytes line carry more noise than the signal.

**Why**: A 12-byte-per-element saving on a 1,600-element page is 20 KB. The process holds 6 MB of malloc blocks, and between two runs of one binary the large blocks alone move by 10 KB (one 10-KB block more or less, by timing). The blocks the change removes are small (16 to 128 bytes), and `heap` prints an exact count for every block size under 1 KB (`Sizes: ... 48[810] 32[3392] 16[3479]`), so the difference of the per-size median counts times the size is the saving, with a noise of 1-5 KB per side on these pages.

**What Happened**: Lane nd2 batch 4's census (a JS walker computing block bytes from the DOM) predicted what attribute-block sharing would save on 17 pages. The walker cannot see which elements share, so the saving had to be measured. Each page was loaded in the release console (base and tip, three fresh processes a side), held idle on a timer, and read with `heap <pid>`; the console copy is signed ad hoc with `com.apple.security.get-task-allow`, as `leaks --atExit` needs. Measured against predicted bytes per element: pythondocs 12.43 / 12.43, github 12.88 / 12.64, guardian 13.11 / 12.79, hackernews 9.74 / 9.72 - and three pages saved MORE than predicted (jquery 14.37 / 10.41, vue-ssr 13.56 / 5.85, allbirds 12.81 / 10.55), which the model had no term for. Pages that build their DOM with createElement read 0 within the noise, as predicted. AG Grid's page varies by 1.6 MB of small blocks between runs: a page like that needs another method.

**Fix**:
1. Run each side in fresh processes (three or more); when the page is ready, hold the process idle and run `heap <pid>`.
2. Parse the `All zones: ... Sizes:` line; for each size under 1 KB take the median count over a side's runs; the saving is the sum of size x (base count - tip count).
3. Report each side's spread (max - min of its small-block bytes) as the noise, and say so where the saving is inside it.
4. Keep the model's prediction beside the measurement: where they differ by more than the noise, the model is missing a term.

**Takeaway**: **For a per-object saving of a few bytes, count blocks by size class with `heap` on the live process, base against tip, medians over fresh runs - totals and footprints drown it.**
