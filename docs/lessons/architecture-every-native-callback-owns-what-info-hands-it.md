# Architecture: Every native callback owns what `info` hands it - a dispatcher written beside interface.zig repeats its leaks

**Date**: 2026-10-11
**Lesson**: Every V8 adapter callback receives owned Globals: from `info.get(i)`, `info.getData()` and `info.getThis()`, and from every value it makes to `setReturnValue`. interface.zig's operation, getter and setter paths learned to release them one leak at a time, but each dispatcher written apart from them had none of those fixes. That covers the namespace binding, the observable array's Proxy traps, Intl, and the setter and [PutForwards] tails.

**Why**: `setReturnValue` copies the handle into the call's return slot, and an argument handle is a fresh `new Global<Value>`. Nothing about the callback's signature says so: the code reads like V8's own Local-based API, where no release is needed. The rules - release what a conversion copied out, release what a value does not refer to, keep only what is stored - live in interface.zig's predicates (`argHandleIsCopied`, `keptArgumentHandle`, `releaseAnyArgument`, `getterValueIsOwned`). A file that converts with `conv.fromV8Value` directly bypasses all of them.

**What Happened**: Lane callleak was sent after a "660 B per DOM call" receiver leak that turned out to be gc_bench's allocator (testing-a-debugallocator-that-captures-traces-grows-rss-per-allocation.md); the receiver was released on every path. A survey of about 100 statements, each run 10,000 times under `gc_bench --c-alloc` and read by `global_handle_bytes`, found the real per-call leaks. All of them were outside interface.zig's main paths:
- `CSS.escape("a")`: namespace.zig never released an argument.
- `console.groupEnd()`: conv.setReturnUndefined made an undefined and kept it.
- `el.onclick = null`, `el.hidden = false`: the setter released only `argHandleIsCopied` types.
- `el.classList = "a b"`: the [PutForwards] setter's undefined result.
- `sheets.length`: 4 Globals per read. The observable array traps released nothing, [[data]] included.
- `collator.compare(a, b)`: 5 Globals per call; intl_binding.zig, left for its own lane.

**Fix**:
1. Route a new dispatcher's arguments through `interface.convertArgReleasing` and release them after the call with `interface.freeArgument` / `releaseAnyArgument`. namespace.zig now does both.
2. Set a result that is undefined with `conv.setReturnUndefined`, which makes no handle. For any other result the callback made, set it and then release it. observable_array.zig has `returnOwned` / `returnBoolean` for this.
3. Decide a setter value's release by the value, with an allowlist whose default keeps the handle (`setterValueLeavesHandle`, pinned in retention_predicate_test.zig).
4. Test each callback kind by reading `global_handle_bytes` over 64 calls after a warm-up (tests/v8/per_call_handle_test.zig).

**Takeaway**: **Before trusting a native callback, run its statement 10,000 times under `gc_bench --c-alloc` and read `global_handle_bytes`: anything above the control is a Global per call. A dispatcher that does not go through interface.zig's release predicates has to be checked on its own.**
