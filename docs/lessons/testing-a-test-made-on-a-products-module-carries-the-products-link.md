# Testing: A test made on a product's module carries the product's link, and every pass over the tests reaches the product

**Date**: 2026-11-22
**Lesson**: `b.addTest(.{ .root_module = m })` over a module that a product already links into shares that product's link objects and flags: any build-wide pass over the test executables (ThreadSanitizer instrumentation, a check hung off every suite) then reaches the product's module. A test of a product module gets its own clone with the tests' link (`addModuleTestWithEngine`), and a per-executable check hangs off that executable's own suite run, never off `test`.

**Why**: Zig keeps link objects (C sources, archives) and the sanitizer flags on the MODULE, and a module is shared by every compile that names it. libwhatwg_full's root module carries the product engine link: v8_wrapper.cpp compiled inside the module, against Chromium's libc++ headers and flags.txt's `-D_LIBCPP_*` defines. Its C ABI test was `b.addTest(.{ .root_module = lib_exports_mod })`, the same module. Under -Dsanitize-thread, `instrumentForThreadSanitizer` walks every suite's executable and sets `sanitize_thread` on the modules it reaches, this one included. Zig then links its ThreadSanitizer runtime with its OWN libc++ into that compilation and puts that libc++'s `-D_LIBCPP_*` macros on every C++ file it builds. That is the clash the engine adapter's "apart" library exists to avoid (src/runtime/engines/v8/engine_build.zig, `addSource`).

**What Happened**: On 2026-11-22, `zig build test -Dspec=v8 -Dtest-file=<a tests/v8 file> -Dsanitize-thread` failed on Linux (lane tpc, server1) in two ways:
- "compile test debug native, 24 errors": `'_LIBCPP_HARDENING_MODE' macro redefined` (`<command line>:22`, previous definition `<command line>:19`), then `_LIBCPP_ABI_NAMESPACE`, `_LIBCPP_ABI_VERSION` and `_LIBCPP_ASSERTION_SEMANTIC_DEFAULT` redefined by Chromium's `__config_site`, and errno/FP_NAN undeclared.
- About 57 "thread-local block" checks failed: "1992 bytes; the budget is 1024. Largest: __tsan::cur_thread_placeholder 1856".

The `test-verify -Dsanitize-thread` gate was clean, so the report blamed the day's ICU-enabled V8 archive. Neither failure was ICU's. A new loop (lane tpf, the same day) hung a thread-local check for EVERY registered test executable directly on `test`. That pulled test-browser's lib-exports executable into `test`, which made even a plain `-Dtest-file` run compile a whole engine executable for an unrelated file. Under the sanitizer it reached the product module, and it held instrumented executables to a production budget their sanitizer runtime alone exceeds.

**Fix** (lane flk4):
1. lib_exports_test is `addModuleTestWithEngine(b, lib_exports_mod, target, tests_engine_link)`: its own module, the same root file and imports, and the tests' engine link, which compiles the wrapper apart under the sanitizer.
2. `TestLaunch.test_runs` records each suite's run beside its executable, and the thread-local check hangs off that run. A step builds and checks only the suites it runs.
3. The check is not made under -Dsanitize-thread (tools/thread_local_size_scope.zig, pinned by the tool's tests). The plain build holds the same executables to the budget.

**Takeaway**: **Never make a test executable over a module a product links into: clone it with the tests' own link. And hang a per-executable check off that executable's own run, so `-Dspec`/`-Dtest-file` select it, and so a variant build (TSAN) can say it does not apply.**
