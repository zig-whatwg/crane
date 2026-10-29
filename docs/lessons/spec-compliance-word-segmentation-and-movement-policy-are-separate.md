# Spec Compliance: Word boundaries and movement policy are separate

**Date**: 2026-10-27
**Lesson**: Sharing Unicode word segmentation does not require changing the platform's caret-movement convention.

**Why**: The word iterator answers where segments start and end. A movement command then chooses a boundary and may consume following spaces. Conflating the two changes passing caret offsets when fixing a script boundary.

**What Happened**: Chrome, Firefox and Safari all separated adjacent Hangul and Latin in row129's probe. Their macOS forward word movement stopped at a word's end, whereas Crane's existing passing UTF-16 fixture used the Windows-style next-word start. Emoji and punctuation also needed per-case majorities: apostrophes stay inside a word in Chrome/Safari; backward movement across a comma skips it in Firefox/Safari. A second probe showed that Unicode spaces cannot all be skipped: NBSP behaves like ASCII space, NNBSP remains inside a word, and EM/IDEOGRAPHIC spaces are stops on both sides in Chrome/Firefox. Checking the actual iterator then found that three Glue spaces had the wrong Word_Break property.

**Fix**: Keep the shared WordIterator as the segmentation source, with the narrowly authorized ICU Hangul tailoring. Correct the three properties from Unicode's property data: U+202F is ExtendNumLet; U+00A0 and U+2007 are Other, excluded from WSegSpace because their Line_Break property is Glue. This also fixes WB3d joining ASCII space with NBSP. Put movement policy in a borrowed-text helper that works in UTF-16 units, keeps the existing next-start convention and symbol-run behavior, and serves both Selection.modify and text-control word keys. Under that convention, forward movement chooses the next backward stop: classify a whitespace segment by its first character, and never split a mixed WB3d group. In `ab<EM SPACE><NBSP>cd`, forward from two reaches four; three is a macOS end stop, not a word start. Bind the key modifier to navigator.platform: Alt on Mac, Ctrl elsewhere. Test those choices independently, including mid-surrogate offsets, range direction, cancellation and readonly controls.

Design sources: ICU's word.txt HangulSyllable/dictionaryCJK rules at revision a86a32e67b8d1384b33f8fa48c83a6079b86f8cd; Blink SelectionModifier::NextWordPositionForPlatform / MoveCommands at revision 8d5ba1795f0c50b90072399d0403389df6eebbd6; UAX #29 and WordBreakProperty-18.0.0.txt. Browser evidence: row129 Q15, Q22 and Q30-Q33, 2026-10-27. No engine implementation code was copied.

**Takeaway**: **Segmentation, movement convention and keyboard binding are separate decisions.** Pin each one with evidence, and never trade an existing passing offset while repairing another script's boundary.
