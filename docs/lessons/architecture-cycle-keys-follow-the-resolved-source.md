# Architecture: Cycle keys follow the resolved source

**Date**: 2026-10-25
**Lesson**: A dependency key must identify the object actually read, as well as the member name, when resolution can change the source object.

**Why**: A key that was complete while every declaration read one element can become ambiguous after a new scoping rule. Two different elements may expose the same expanded attribute name without forming a cycle.

**What Happened**: CSSWG issue 12721 changed attr() on exported parts to read the host selected by each declaration's tree scope. An outer declaration can therefore read a host's data-v containing var(--inner), while --inner reads the part's own data-v. A name-only attribute guard confuses those reads and can make the result depend on custom-property resolution order. The old substitution-context wording and WebKit's name-only implementation predate that distinction. Row 122 Q25 accepted the resolved-origin identity as part of the key.

**Fix**: Carry the actual origin's existing opaque identity through the synchronous attribute lookup, then key the shared cycle guard by that identity and the canonical expanded name. Do not use declaration scope as a substitute: own rules and :host rules can read the same host from different scopes. Do not create a second cycle stack or a new identity counter. Pin both directions of custom-property resolution with swapped property names, and keep namespace aliases on one origin equivalent.

**Takeaway**: **When the source of a read changes, re-check what makes its dependency identity unique.**
