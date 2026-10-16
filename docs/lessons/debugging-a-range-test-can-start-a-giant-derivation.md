# Debugging: A range test can start a giant derivation

**Date**: 2026-10-13
**Lesson**: Check the generated argument's integer-conversion mode before diagnosing a stalled cryptographic operation.

**Why**: An unsigned-long argument without EnforceRange converts modulo 2^32. Passing -8 as a bit length requests 4,294,967,288 bits, nearly 512 MiB. At 100,000 PBKDF2 iterations, that is vast computation rather than an immediate validation error.

**What Happened**: WebCrypto's derived_bits_length WPT stalled until Crane's supervisor killed its runner after 150 seconds. The current spec and WPT IDL carry EnforceRange, while the pinned IDL does not. Registering the tests outside a promise_test still stalled, disproving a harness-registration theory. Browser subtest records showed Chrome and Safari also converting modulo and timing out at PBKDF2 -8; Firefox enforces the newer range. Crane's existing crypto task executes native work on the realm thread, so its own harness timer cannot interrupt the computation (src/webcrypto/tasks.zig:81).

**Fix**: For diagnosis, exercise range conversions with HKDF, whose output bound rejects huge lengths promptly, and keep ordinary PBKDF2 vectors. Preserve the browser-majority conversion until the owning lane reconciles a pin update with that deviation. Parallel native work requires the shared queue facility; do not insert an arbitrary key-size cap, add an ad-hoc thread pool, or try to recover a lost original value from an already converted u32.

**Takeaway**: **A tiny negative test input can become valid, expensive work after binding conversion; isolate it with a bounded operation before blaming the primitive or harness.**
