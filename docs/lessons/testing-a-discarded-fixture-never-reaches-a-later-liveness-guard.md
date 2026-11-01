# Testing: A discarded fixture never reaches a later liveness guard

**Date**: 2026-11-01
**Lesson**: Verify that a controlled object survives every setup step and enters the snapshot whose later liveness check the test intends to exercise.

**Why**: Detaching a realm and retiring a subsystem object are distinct operations. A realm can remain usable while an earlier document-discard step has already removed an object from consideration.

**What Happened**: A FontFaceSet.load regression created a foreign face, removed its iframe, then ended the kept realm inside an earlier face's author-defined then getter. The realm-end and later-live-face assertions passed, but the pending record remained. Document discard had already marked the foreign face retired, so LoadingFaces excluded it before the reentrant guard ran. The failure tested setup order rather than the intended guard.

**Fix**: Keep the foreign realm with a non-FontFace object, detach the iframe, then construct the foreign face in that still-live realm. Assert its realm and non-retired state before loading. Preserve the original getter, explicit realm end, later-face load, handled-rejection and pending-record assertions. The corrected exact fixture ran RED before GREEN; all three realm cases then passed without changing product behavior.

**Takeaway**: **A later guard needs an input that actually survives into its guarded operation. Pin that precondition in the test.**
