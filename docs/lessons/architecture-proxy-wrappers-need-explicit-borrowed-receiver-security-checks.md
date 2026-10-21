# Architecture: Proxy wrappers need explicit borrowed-receiver security checks

**Date**: 2026-10-21
**Lesson**: Putting an access-checked platform object behind a JavaScript Proxy does not make borrowed WebIDL member functions check the target's origin.

**Why**: V8's SetAcceptAnyReceiver(false) examines the function call's receiver. The Proxy itself has no access check, while Crane's brand lookup unwraps it to the platform target. The brand can therefore succeed without the target's origin check running.

**What Happened**: A Location prototype getter borrowed from the calling realm accepted a foreign Location Proxy. Borrowed hash setters and assign methods reached Symbol conversion and threw TypeError instead of the required SecurityError. Ordinary property access still threw, so testing only foreign.href missed the bypass.

**Fix**: Apply WebIDL's security check to the unwrapped receiver before argument conversion, in the member function's realm. Use Local handles for that check. Preserve HTML's cross-origin href setter and replace operation, ordinary wrong-receiver TypeError, and promise rejection behavior. The native test changes origin policy after saving the object and checks borrowed local and foreign functions, then identity after GC.

**Takeaway**: **When introducing a Proxy around a platform object, test borrowed getters, setters and methods as well as ordinary access. Origin and brand checks are separate obligations.**
