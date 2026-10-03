# Spec Compliance: Validating a buffer does not copy its bytes

**Date**: 2026-10-02
**Lesson**: Preserve a BufferSource object's identity during WebIDL conversion and copy its bytes at the consuming algorithm's specified step.

**Why**: A BufferSource is an object with mutable, detachable backing storage. Converting the argument validates the object's type; it does not authorize freezing its contents before the method's own algorithm reads them.

**What Happened**: WebCrypto's planned adapter conversion copied BufferSource bytes before entering an impl. The August 2026 editor's draft normalizes the algorithm first, then copies the data. A `name` getter can restore a modified message or detach its buffer during normalization. An early adapter copy loses both changes. WPT exercises these cases as "altered plaintext during call" and "transferred plaintext during call". Reviewing the complete algorithm exposed the mismatch before the adapter change landed; the integrator revised the design in codex-webcrypto question Q18.

**Fix**: Let the binding carry a borrowed reference to the buffer object for the synchronous call, with a defined release point. After normalization, call the engine protocol's BufferSource-copy operation at the numbered spec step. That operation reads only a view's byte range and treats a detached buffer as empty. Pass only the resulting owned bytes to the native computation task. Keep WebIDL argument conversion in argument order as well: converting a later AlgorithmIdentifier before an earlier JsonWebKey dictionary can change which exception wins.

**Takeaway**: **Validation, object lifetime, and byte-copy timing are three separate requirements.**
