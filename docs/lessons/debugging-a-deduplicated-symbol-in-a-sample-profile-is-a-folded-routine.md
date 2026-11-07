# Debugging: A `<deduplicated_symbol>` in a sample profile is a folded routine - name it by its address before reading the share

**Date**: 2026-11-07
**Lesson**: macOS `sample` prints every function the linker folded with an identical one as `<deduplicated_symbol>`, and in Crane's release console the biggest of them is Zig's own `compiler_rt.fastMemset` - where every ReleaseSafe `= undefined` fill lands - so a profile that shows a large `<deduplicated_symbol>` share is usually showing safety fills, and nothing names them until you look up the address.

**Why**:
- The release console links Zig's compiler_rt, whose `memset` and `memcpy` are identical-code-folded with other functions, so `sample` cannot give them a name. libSystem's `_platform_memset`/`bzero` keep theirs.
- Zig lowers the 0xAA fill of a ReleaseSafe `var buf: [N]T = undefined` to compiler_rt's memset; Crane's explicit `@memset(x, 0)` zeroing showed up as `_platform_memset`/`bzero`. Count only the named routines and you miss the fills.
- std's own allocator path fills too: `std.mem.Allocator.alignedAlloc`/`alloc`/`create` end in `allocBytesAligned`, which does `@memset(bytes, undefined)` - 0xAA over the whole allocation in ReleaseSafe, before the caller writes anything.

**What Happened**: Lane perf2's batch 3 profiled named-property reads (`el.dataset.k`, `el.attributes.title`) in the ReleaseSafe `-Dcpu=apple_m1` console. The top of the self-time list was `<deduplicated_symbol>` at 36% and 31%; `_platform_memset` showed under 2%. The frame above it was `isSupportedPropertyName + 88`. `lldb -b -o "image lookup -v -a 0x1000ceb94" ./repl` on the same console said `compiler_rt.fastMemset`, range 0x1000ceb94-0x1000cec98: the 0xAA fill of an 8 KB stack buffer, 30% of the read. The same routine was mutation.insert's 2 KB buffer (1.7% of insert-remove) and the parser's fills, and the neighbouring folded routine, `compiler_rt.memcpy.memcpyFast`, was 12.6% of inner-html-set, called straight from `TreeBuilder.parse`. The state arena zeroed each new block twice, and a fresh block had first been filled with 0xAA by `alignedAlloc`. After the fixes (wrappers that declare only the buffer, with `@setRuntimeSafety(false)` per the user's approval; `rawAlloc` plus one zeroing of the request), the same pages on the same host showed: dataset read 35.7% -> 4.0%, attributes read 30.4% -> 2.3%, insert-remove 1.7% -> 0.0%, create-element 2.3% -> 0.8%.

**Fix**:
1. Take the console's load address from the `Binary Images:` line for `repl` in the sample file. File address = sampled address - load address + 0x100000000.
2. Name it on the same binary: `lldb -b -o "image lookup -v -a <file address>" ./repl` gives the function and its range.
3. Attribute self time by range: tmp/plans/perf2-evidence/batch3/prof_self.py takes `--ranges lo-hi:name,...` and prints the fill share of each calling frame (memset, bzero and the named fastMemset).
4. Before blaming a buffer, check whether the fill comes from std's allocator rather than a stack `undefined`. Where you zero the block anyway, take it with `rawAlloc`, which writes nothing.

**Takeaway**: **A large `<deduplicated_symbol>` in a ReleaseSafe profile is a folded routine, most often Zig's compiler_rt memset doing `undefined` fills: look up its address with lldb on the same binary, then attribute it by calling frame.**
