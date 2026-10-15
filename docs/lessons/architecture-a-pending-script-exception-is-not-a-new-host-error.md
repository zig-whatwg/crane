# Architecture: A pending script exception is not a new host error

**Date**: 2026-10-14
**Lesson**: A binding must preserve an impl's ExceptionPending completion instead of translating its error name into a new JavaScript exception.

**Status**: 2026-10-15 - fixed in the adapter (lane setterleak): throwMemberError throws nothing over ExceptionPending, so the setter path rethrows script's own object; crane/ar-internals-iterator-error-isolated.html went 0/1 -> 1/1 and crane/stl-setter-exception-identity.html pins hidden and the ARIA arrays.

**Why**: Conversion can happen in a binding or inside an impl that receives a raw JSValue. Both paths may execute user code. An error signal that says script has already thrown is different from a request to create a TypeError or DOMException.

**What Happened**: ElementInternals' array setter used engine.iterate for per-item conversion. Iterator exceptions propagated correctly through the engine protocol and left the stored array unchanged, but the setter binding caught ExceptionPending and passed it to throwMemberError. Script received Error('ExceptionPending') instead of its original object. String setter conversion already recognized this completion and passed the corresponding test.

**Fix**: The follow-up belongs in src/runtime/engines/v8/interface.zig: makeSetterCallback's impl-error catch (8284 at the lane's base) and throwMemberError (1232). Apply the same pending-exception rule as the argument-conversion catch, with a regression test for exception identity. This lane cannot edit the adapter, so the defect remains open and crane/ar-internals-iterator-error-isolated.html records it. Do not swallow the error in an individual impl and return a successful native completion as a workaround.

**Takeaway**: **Test the identity of a thrown object across each binding path, not merely that some exception was thrown.**
