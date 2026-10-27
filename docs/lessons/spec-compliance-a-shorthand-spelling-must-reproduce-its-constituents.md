# Spec Compliance: A shorthand spelling must reproduce its constituents

**Date**: 2026-10-27
**Lesson**: When repairing shorthand serialization, test the matching parser expansion and initial longhand tuple together.

**Why**: Returning a plausible shorthand string can conceal a different declaration. Its parser must reproduce every constituent, including properties reset by the shorthand.

**What Happened**: Overflow 4's legacy clamp text set block-ellipsis to ellipsis even for none, while the initial longhand value is no-ellipsis. Crane therefore could not reconstruct the initial tuple as a legacy shorthand. Two aggregate CSSOM tests lost their PASS names, reproducibly in three isolated BASE/TIP pairs. CSSWG [issue 14673](https://github.com/w3c/csswg-drafts/issues/14673) proposes the matching none expansion, with the editor's agreement; Chromium's flagged implementation already uses it. The issue is still open as of this ruling, rather than an adopted resolution.

**Fix**: The integrator approved changing both legacy-none parsing and reconstruction to auto/no-ellipsis/normal, with the current specification departure and evidence documented in the code. Pin parse and initial-value round trips in failing native tests first; keep positive integers and incompatible numeric states as controls. Revisit the rule when issue 14673 resolves, and require the original CSSOM PASS identities and newer-model gains in a fresh matched A/B.

**Takeaway**: **A serializer fix must remain an inverse of parsing; preserve both the original passing behavior and the newly implemented semantics.**
