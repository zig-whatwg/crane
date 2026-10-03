# Architecture: Link the library your dependency actually built

**Date**: 2026-10-02
**Status**: 2026-10-03 - the root entries are now the ones linked: configureStaticLibcurl builds root's `.mbedtls` (3.6.6) and `.zlib` (1.3.2) and points libcurl's link entries at them, so libcurl and WebCrypto share mbedTLS 3.6.6. The takeaway stands; see [Override a transitive Zig pin in the build graph](architecture-override-a-transitive-zig-pin-in-the-build-graph.md).
**Lesson**: A root dependency declaration does not identify the library linked by a transitive consumer.

**Why**: Two package declarations can name different versions of the same C library. Linking both introduces separate global stores and can pair headers with an incompatible binary.

**What Happened**: WebCrypto needed the mbedTLS already used by curl. Crane's root package declared 3.6.6, but that declaration was unused: the pinned curl package built and linked 3.6.4. Its PSA key store also belongs to the library, and curl's cleanup frees that store. A CryptoKey therefore cannot safely keep a PSA key identifier between calls.

**Fix**: Have the existing curl configuration return the mbedTLS compile artifact from curl's link objects. Link that same artifact into WebCrypto so its headers propagate with it. Match the library's `MBEDTLS_THREADING_C` and `MBEDTLS_THREADING_PTHREAD` definitions, and supply SDK include paths on the importing module for iOS. Keep CryptoKey material in owned, erasable bytes; initialize PSA and import/destroy transient keys within each operation. When system curl supplies no artifact, compile the dependent algorithms out explicitly.

**Takeaway**: **Trace the actual linked artifact, its headers, and its lifetime owner before sharing a C library across subsystems.**
