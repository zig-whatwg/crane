# Testing: A blocking-file headline can hide large subtest regressions

**Date**: 2026-10-05

**Lesson**: Review every file's lost passing subtests as well as newly blocking files before accepting an A/B result.

**Why**: A file with one surviving pass remains nonblocking even if most of its assertions regress. An improving aggregate can hide that loss behind gains elsewhere.

**What Happened**: Custom-element activation reduced the first full sweep's blockers by 68 and added 890 passing subtests. Yet Node-cloneNode.html lost 123 passes and a selector file lost four. They still passed other assertions. The shared clone path had removed the old caller's empty-prefix normalization: a legacy getter returned an empty string for an absent prefix, and direct initialization then invented names such as :DIV.

**Fix**: Sort all per-file passing-count decreases, compare the exact failure messages, and restore normalization at the granted caller with tests for absent and nonempty prefixes. Keep the original sweep as pre-fix evidence, then gate and sweep the corrected tip. Record other owners' newly reached defects separately instead of using the headline to dismiss them.

**Takeaway**: **A better blocking count is not proof of no regression; inspect all lost passes and preserve the conversion semantics of replaced call paths.**
