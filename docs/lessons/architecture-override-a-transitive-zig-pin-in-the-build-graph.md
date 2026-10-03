# Architecture: Override a transitive Zig pin in the build graph, and test the binary's version

**Date**: 2026-10-03
**Lesson**: Zig 0.16 cannot override a dependency's own pin from build.zig.zon; the build graph can, and a test that asks the linked library its version is the only proof it worked.

**Why**: A package's build.zig.zon pins its dependencies by hash, and the consuming package has no override table (`zig build --fork=<path>` swaps in a local checkout from the command line; it is not a pin anyone else gets). Declaring a newer version of the same library in the root build.zig.zon does nothing unless something calls `dependency()` on it. So a security release of a transitive C library reaches the binary only if the consumer's link entries are pointed at it.

**What Happened**: Crane's TLS ran on mbedTLS 3.6.4 and its HTTP decompression on zlib 1.3.1, the versions allyourcodebase/curl pins (c59c65cd, its newest commit). Root build.zig.zon declared mbedTLS 3.6.6 and zlib 1.3.2, the security releases, and the Zig 0.16 migration had bumped those entries in the belief that they were linked; nothing consumed them. No newer curl package pinned 3.6.6.

**Fix**: In `configureStaticLibcurl` (build.zig), build root's `.mbedtls` and `.zlib` with the arguments curl passes (`.threading = true` for mbedTLS), then `replaceLinkedLibrary(libcurl, "mbedtls", ...)` and `(libcurl, "z", ...)`:

1. Replace the artifact in BOTH `root_module.link_objects` (what the linker reads) and `root_module.include_dirs` (the installed headers the C sources compile against). These are the two entries `Module.linkLibrary` appends; the build runner derives step dependencies from them (`createModuleDependenciesForStep`), so curl's copies become unreachable and are fetched but never compiled.
2. Panic unless exactly one of each was replaced, so a curl bump that links the library some other way fails the build instead of quietly linking its own pin.
3. Drop curl's `-DMBEDTLS_VERSION=3.6.4`: no C source reads it, but it lies on every compile line.
4. `tests/linked_libraries/versions_test.zig` (`zig build test-deps`, part of `test`) asks the linked code: `curl_version_info()`'s `ssl_version` and `libz_version`, and `mbedtls_version_get_string()` against the headers' `MBEDTLS_VERSION_STRING`. It failed first with `mbedTLS/3.6.4, zlib 1.3.1`.

Header-layout macros travel with the library, not the header: re-measure them across the version change (`sizeof(mbedtls_entropy_context)` was 832/904 with MBEDTLS_THREADING_C off/on in 3.6.4 and again in 3.6.6).

**Takeaway**: **A version in a manifest is a claim; the linked binary's own version string is the fact. When a pin is transitive, override it where the link is made, guard the override so a dependency bump breaks it loudly, and test what the binary reports.**
