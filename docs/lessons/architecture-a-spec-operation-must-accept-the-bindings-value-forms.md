# Architecture: A spec operation must accept the binding's value forms

**Date**: 2026-10-03
**Lesson**: Test a protocol operation with the representations its real callers receive, including inline primitives as well as engine handles.

**Why**: A legacy helper can have a narrower contract than the specification algorithm named by the protocol. Testing only its old callers preserves that mismatch.

**What Happened**: IndexedDB calls `structuredSerializeForStorage` on the value supplied by the binding. That binding turns numbers, strings, booleans, null and undefined into inline `JSValue` tags. The adapter accepted only `.handle`, and its existing test explicitly expected a number to fail with DataCloneError. HTML StructuredSerializeInternal step 4 requires those values to serialize. History's caller-side primitive handling had hidden the mismatch.

**Fix**: Ask the protocol owner to implement the existing operation's complete contract. The integrator accepted this as lane Q24, converted inline inputs into temporary owned engine values, and replaced the rejection test with primitive round trips. The IndexedDB caller stays unchanged; its new Crane fixture exercises add, put, get and count with the same script values. That fixture waits for the signaled adapter merge before running.

**Takeaway**: **An adapter unit test can preserve the wrong contract; derive its input forms and expectations from the binding and the specification together.**
