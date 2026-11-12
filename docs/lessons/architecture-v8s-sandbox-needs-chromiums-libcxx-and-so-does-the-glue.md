# Architecture: V8's sandbox needs Chromium's libc++ - and so does the embedder's glue

**Date**: 2026-11-10
**Lesson**: From V8 14.x a sandboxed V8 builds only against Chromium's own hardened libc++ (std::__Cr). An embedder whose glue passes std types across V8's API must compile that glue against the same headers and link that one C++ runtime, not its own.

**Why**: V8 BUILD.gn:896 asserts `!v8_enable_sandbox || use_safe_libcxx` ("The sandbox requires libc++ hardening", 5958585ab32, 2026-02-20), and Chromium's build/config/c++/c++.gni:119 computes `use_safe_libcxx = use_custom_libcxx && enable_safe_libcxx` - not an argument. So `use_custom_libcxx = false` (the system's or Zig's libc++, std::__1), which Crane's 13.1 archives used, is refused with the sandbox on. V8's API passes std::unique_ptr, std::shared_ptr, std::function and std::vector, so the glue must agree with the archive's namespace and ABI.

**What Happened**: Lane v8up's first gn gen of 15.7.112.43 with out/static's arguments stopped at that assert; batch 1's plan had read the GN arguments but not the asserts. The archive was rebuilt Chrome's way (use_custom_libcxx = true) and the build script now also archives Chromium's libc++ and libc++abi objects (libc++_chromium.a), installs their headers, and records the flags GN gives every C++ consumer, read from a real compile command. A Zig-compiled smoke program (`zig cc`, which adds no libc++) compiled against those headers and linked with libc++_chromium.a ran `1+1`, Temporal and a cppgc collection, with 11,530 std::__Cr symbols and 0 std::__1 ones (macOS; Linux the same). One catch: Zig puts its own -isystem directories first, so the libc++ directories must be -I, or <cstdio> finds the C library's <stdio.h>. Temporal's Rust (and Rust's std) is not in GN's complete static monolith either: d8's link recipe names it.

**Fix**: Build V8 as Chrome does (custom libc++, sandbox on); ship libc++_chromium.a, the headers and the consumer flags with the archive; compile v8_wrapper.cpp against them (-I) and link with `link_libcpp = false`. Read Rust's and the system libraries' part of the link from d8's own link (ninja -d keeprsp).

**Takeaway**: **Before building a new V8, read BUILD.gn's asserts, not only its arguments: the sandbox decides which C++ library everything that touches V8's API must use.**
