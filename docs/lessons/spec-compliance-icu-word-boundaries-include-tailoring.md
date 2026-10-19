# Spec Compliance: ICU word boundaries include tailoring

**Date**: 2026-10-18
**Lesson**: An untailored UAX #29 word iterator does not reproduce the ICU word boundaries that browsers use.

**Why**: The Unicode Word_Break property places Hangul syllables and Latin letters in ALetter, so untailored WB5 joins them. ICU's word rules exclude dictionary CJK characters from ALetterPlus and group Hangul syllables separately. Browser movement calls ICU's tailored word iterator.

**What Happened**: Crane's Selection remainder work found all three browsers passing the Korean/Latin transitions in `selection/move-by-word-korean.html`, while Crane's existing Intl word helper joins them. Assuming that ICU followed untailored WB5 would have misclassified the defect as a Korean-specific selection movement rule.

**Fix**: Read [ICU's word rules](https://github.com/unicode-org/icu/blob/main/icu4c/source/data/brkitr/rules/word.txt) and [Blink's ICU word iterator](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/text/text_break_iterator_icu.cc). The integrator assigned shared segmentation tailoring to the Intl owner; Selection must consume that shared capability instead of introducing a second Korean-only segmenter.

**Takeaway**: **Compare the browser's concrete segmentation rules, including tailoring, before deciding which subsystem owns a word-boundary failure.**
