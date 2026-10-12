# Spec Compliance: Preserve quotes until MIME parsing

**Date**: 2026-10-11
**Lesson**: Fetch header-list splitting and MIME parameter parsing consume different representations of an HTTP quoted string.

**Why**: Header splitting must preserve the quoted substring, including its quotes and backslashes. MIME parsing later extracts its value. Removing quotes in the first step turns a quoted semicolon into parameter syntax in the second.

**What Happened**: A private header-list collector always extracted quoted values. `x/x;a="a,b;c"` therefore reached MIME parsing without its quotes and lost `;c`. The existing split assertion expected the incorrect unquoted representation. A separate allocation-failure test also exposed an unowned duplicate when appending a split value failed. Once that was fixed, the same test exposed a temporary MIME essence left behind by a failing charset copy.

**Fix**: Use the existing Fetch collector with `extract_value=false`, delete the duplicate collector, and retain the raw-quote expectation at the split boundary. Cover the full extraction chain and the quoted nosniff caller, then test every allocation failure with std.testing.allocator.

**Takeaway**: **Follow the representation at each algorithm boundary, and test composed algorithms as well as each helper.**
