# Spec Compliance: Editor text and selection must use the same value

**Date**: 2026-10-09
**Lesson**: Textarea edits must splice the normalized API value because its selection offsets count that value's UTF-16 code units.

**Why**: A raw CRLF pair occupies two code units, while the textarea API exposes one LF. An owned copy prevents stale storage access but does not make offsets into a different representation correct.

**What Happened**: Row 9's editor hook returned textarea raw text, following an integrator ruling later corrected in review. Typing after `a\r\nb` inserted before `b`, Backspace removed only the LF of the pair, and maxlength refused input one character early. Both script value writes and clean child text content exposed the defect.

**Fix**: Return an owned current API value from the textarea editor hook. Keep input's raw editor text contract, which preserves incomplete number input. Pin normalized content and ownership with the testing allocator, and test typing, deletion and maxlength for both textarea value sources.

**Takeaway**: **An edit's text, offsets and length limits must describe the same representation.**
