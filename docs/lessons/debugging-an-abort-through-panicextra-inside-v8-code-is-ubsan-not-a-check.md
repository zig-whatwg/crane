# Debugging: An abort through panicExtra inside V8 code is UBSan, not a V8 CHECK

**Date**: 2026-09-30
**Lesson**: When a crash report shows `debug.panicExtra <- <deduplicated_symbol> <- v8_Something`, the abort is Zig's UBSan runtime trapping undefined behaviour in C++ code (the wrapper or V8's inline headers). It is not a V8 CHECK. The handler's static data tells you which load failed and where, and you can read that data out of the binary.

**Why**: Zig builds the C++ it compiles (v8_wrapper.cpp, and V8's inline header code expanded into it) with `-fsanitize=undefined`, and its UBSan runtime (`___ubsan_handle_*`, written in Zig) reports through `std.debug.panicExtra`. The linker folds the handlers into one symbol, so the report names none of them. A real V8 CHECK looks different: it fails inside `v8::internal` frames, prints `# Fatal error in ...` and raises SIGTRAP (see the `v8::Module` lesson).

**What Happened**: Two lanes saw a sweep-only SIGABRT "in v8_Object_SetPrototype from wrapInstanceAsV8Object", once while wrapping getSelection's result and once for a load event. The brief called it a V8 CHECK and asked which precondition failed. None of the three crash reports on chat had V8 frames under the wrapper function. Each had `v8_Object_SetPrototype + 1068 -> <deduplicated_symbol> + 420 -> debug.panicExtra`, and the panic text had gone to a child's stderr that nothing kept. Here is what the frozen runner's code showed:
- `otool -tV -p _v8_Object_SetPrototype` showed `bl ___ubsan_handle_type_mismatch_v1` at +1064. The call is guarded by `cbz x8` (null) and `and x9, x8, #0x7` (misaligned).
- The handler's first argument pointed at `TypeMismatchData`. That data named `v8-internal.h:1668:12`, type `const Address`, kind 0 (a load). This is `Internals::ValueAsAddress`: a Local whose slot is null or misaligned.
- `wrapInstanceAsV8Object + 1880` is the return address of the CACHE-HIT path's SetPrototype. It comes after `WrapperCache.get` and `v8_GetGlobalPrototype`. The prototype Global there is freshly made and the context is the current one, so the bad handle is the cached wrapper.

**Fix**: To read an abort like this:
1. Look at the report's frames. `panicExtra` directly under a C/C++ function means UBSan.
2. Disassemble the function (`otool -tV -p _<symbol> <binary>`; lldb crashed on the 700 MB runner). Find the `bl ___ubsan_handle_*` just before the return address.
3. Read its data argument from the Mach-O. The argument is an `adrp`/`add` pair. Map the address through the segment load commands. The struct is `{ const char *file; u32 line, col; TypeDescriptor *type; u8 log_align, kind }`. Pointers are chained fixups, so the low 36 bits plus the image base give the target. The descriptor holds `{ u16 kind, u16 info, char name[] }`.
4. The file, line and type name tell you which expression failed. Trace that value back to its producer.

**Takeaway**: **`panicExtra` under a C++ frame is UBSan. Decode the handler's source location from the binary before theorising about V8's preconditions: a check kind and a line number replace a guess.**
