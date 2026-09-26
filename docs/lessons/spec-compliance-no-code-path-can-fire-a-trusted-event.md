# Spec Compliance: No code path can fire a trusted event

**Date**: 2026-09-22
**Lesson**: `call_dispatchEvent` resets `isTrusted`, as the spec requires of
`dispatchEvent()`, and the interface has no delegate for DOM's internal
"dispatch" - so every engine-fired event reads `isTrusted === false`. The three
script fetch-src files now complete and still fail their `isTrusted` asserts.

**Takeaway**: **"Fire an event" needs its own interface-level entry point,
distinct from the script-facing `dispatchEvent`.**
