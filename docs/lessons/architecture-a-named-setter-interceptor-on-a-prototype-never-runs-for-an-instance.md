# Architecture: A named setter interceptor on a prototype never runs for an instance

**Date**: 2026-09-26
**Lesson**: V8 calls a setter interceptor only on the receiver itself (`objects.cc` `SetPropertyInternal`, INTERCEPTOR case); one on a prototype is skipped and an own data property is created on the instance.

**Why**: The lazy-property mechanism serves attributes like `lang`, `accessKey`, `inert`, `tabIndex` and `dir` from a named interceptor on the prototype.

**What Happened**: `div.lang = x` made an own property and never reached the impl - 2,142 reflection-suite subtests each for lang and accessKey (lane/reflection).

**Fix**: Pending - lazy properties need real accessors (or a setter path that runs for instances).

**Takeaway**: **An interceptor on a prototype can serve reads; it cannot serve writes.**
