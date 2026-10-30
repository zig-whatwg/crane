# Testing: Classify Listeners by Their Owned Service

**Date**: 2026-10-29
**Lesson**: A new listener is evidence to classify, not proof that a shared WPT server changed.

**Why**: Native test suites can bind temporary loopback sockets while another lane runs WPT. Such a socket cannot answer WPT requests when its ports do not overlap the served tree's ports. A broad exception is unsafe, but rejecting every unrelated listener unnecessarily serializes independent work.

**What Happened**: The CSS Typed OM unparsed-value BASE preflight found another lane's `tests-fetch` listening on `127.0.0.1:57631` and stopped before any runner observation. The captured ancestry led through that lane's `zig build test` and its remote wrapper. The shared WPT server and all pinned inputs were unchanged.

**Fix**: Preserve the stopped receipt and ask for a classification rule. The liaison and integrator required every condition in the same bracket: another mirror's `crane-caches/<mirror>/o/<hash>/tests-*` executable with `--listen=-`; an ancestry chain through that mirror's `zig build --cache-dir ... test`, `test-browser`, or `check`, then its remote wrapper; every observed listening address on loopback and every port in 49152–65535; and no port belonging to the fixed WPT set or the current served tree. Record matches with their full identity and ancestry. Anything outside that predicate retains the existing OPEN/VOID handling. Test both a captured positive and each mismatched attribute. Use a fresh attempt directory after authorization; never rewrite the rejected evidence or imply that a page ran.

**Takeaway**: **Prove which service owns a socket and whether it can interfere; preserve the original observation when refining its classification.**
