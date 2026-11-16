# Architecture: A Zig `export fn` the C++ wrapper calls is compiled into every binary that holds the adapter's Zig - it may name no symbol of the wrapper

**Date**: 2026-11-16
**Lesson**: When v8_wrapper.cpp calls a Zig function (`export fn`), the Zig file must be referenced from the adapter's root so that the symbol exists in every binary that links the wrapper. That same reference puts the function in binaries that hold the adapter's Zig and do NOT link the wrapper. So the exported code may call nothing that v8_wrapper.cpp defines: what it needs from the C++ side comes in as arguments.

**Why**: Some test executables compile the V8 adapter's Zig module without linking V8 (src/dom's own tests among them; the build's `Engine.isLinkedInto` records which artifacts link it). Zig analyses lazily, so an `extern fn` nobody calls costs nothing there - but an `export fn` is always analysed and emitted, and everything it calls with it. The wrapper direction (C++ calls Zig) is new in the adapter: until lane ab1 every call went from Zig to C++.

**What Happened**: Lane ab1's allocator is Zig called from C++ (sandbox_allocator_exports.zig: `crane_SandboxAllocator_*`), and its four page operations were `extern fn v8_SandboxPages_*` defined in v8_wrapper.cpp. Three one-file test executables and the WPT runner linked. The whole native test step then failed 3 of 626 steps on both hosts: "undefined symbol: v8_SandboxPages_Discard ... referenced by root.o:sandbox_allocator_exports.SandboxPages.discard" in the test executables that have the adapter's Zig and no wrapper.

**Fix**:
1. The wrapper hands the Zig side what it needs when the state is made: a constant table of the four functions (`CraneSandboxPageOps` in C++, `PageOps` in Zig) and the page size, as arguments of `crane_SandboxAllocator_create`.
2. The exports file keeps only `export fn`s and the tests' `pub extern fn` declarations (lazy: only a test that links the wrapper names them).
3. root.zig keeps the comptime reference that makes the exports exist everywhere; no build.zig change.
4. Run the whole native test step before trusting one-file test builds: only it compiles the executables without the wrapper.

**Takeaway**: **Code that C++ calls into Zig is in every binary that has the Zig, with or without the C++: give it what it needs through its arguments, and let it name no symbol of the wrapper.**
