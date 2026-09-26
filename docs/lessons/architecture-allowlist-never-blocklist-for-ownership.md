# Architecture: Allowlist, never blocklist, for ownership predicates

**Date**: 2026-09-21
**Lesson**: A predicate deciding whether a handle may be released must default to "no".

**What Happened**: Written as a blocklist twice — "retains unless it's an
Instance pointer", then "retains only for `*runtime.CallbackWrapper`" — and
twice an unlisted type slipped through into a use-after-free. 2–3 crashes per
timers run the first time; 10 of 12 files the second, because `setTimeout`'s
handler is `typedefs.TimerHandler`, a union whose `function` arm is a callback.

**Fix**: `typeRetainsContext` and `argHandleIsCopied` are allowlists of provably
inert types. Unrecognised types get the conservative answer, which costs memory
and never correctness. Both have tests pinning the default.

**Takeaway**: **A blocklist over an open set of types is wrong by default —
every type nobody thought of falls on the dangerous side.**
