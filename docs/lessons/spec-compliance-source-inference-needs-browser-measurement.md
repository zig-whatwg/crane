# Spec Compliance: Source Inference Needs Browser Measurement

**Date**: 2026-10-22
**Lesson**: An engine callback's apparent behavior does not establish what its browser exposes.

**Why**: Parser options, callbacks, error handling and the surrounding document loader together decide the observable result. Reading only one of them can predict the wrong browser behavior.

**What Happened**: Chrome continued after an unread external XML parameter entity. WebKit/libxml2 source inspection suggested Safari might do the same. Actual Safari 27 measurement returned a parse error; Firefox 158 skipped later declarations without standalone, and processed them with standalone=yes. The measured standalone majority was therefore a parse error, while non-standalone behavior was a three-way split.

**Fix**: Preserve a small identical probe and the actual browser outputs. Compare each mechanism, follow the browser majority where one exists, and use the spec for a split that cannot be composed into one shipping browser's behavior. Revert a provisional implementation when the measurements contradict its premise.

**Takeaway**: **Label source-based predictions as inferences until an actual browser run confirms them.**
