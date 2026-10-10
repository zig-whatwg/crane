# Codegen: An anonymous indexed getter is gated like an overload

**Date**: 2026-10-09
**Lesson**: The binding installed indexed access only for a named `item` getter (`call_item`); an anonymous `getter T (unsigned long index)` (`call_getter`) got none, and it cannot simply be wired, because most impls of such interfaces do not implement it and the binding may not ask the impls.

**Why**: Codegen emitted every anonymous getter's delegate as an unconditional call into the impl. Nothing analysed it, so the 12 impls that lack `call_getter` (AudioTrackList, SourceBufferList, the CSS typed OM lists, HTMLAllCollection, ...) compiled. The moment the binding referenced `Interface.call_getter` for all of them, those 12 would fail to compile, and the impls boundary forbids the adapter from importing "impls" to check.

**What Happened**: `new DataTransfer().items[0]` read undefined with `items.length === 1` (lane cxsupport). The fix follows the overloads' existing pattern (`.implemented = @hasDecl(Impl, ...)`): the anonymous indexed getter's delegate is gated - it answers error.NotImplemented until the impl declares `call_getter` - and `Meta.indexed_getter_implemented` is `@hasDecl(<X>Impl, "call_getter")`. interface.zig installs indexed access (getter, query, descriptor, enumerator, %Symbol.iterator%) for `call_item` or for an implemented anonymous getter, and checks `index < length` first for the anonymous one (an impl answers IndexSizeError past the end, where an `item` answers null). HTMLFormElement is not covered: codegen merges its anonymous indexed and named getters into one union-argument delegate.

**Fix**: writer.zig `isAnonymousIndexedGetter` / `soleAnonymousIndexedGetter`; tests/codegen/anonymous_indexed_getter_test.zig pins the gated, ungated and merged cases; tests/v8/anonymous_indexed_getter_test.zig pins implemented and unimplemented interfaces at comptime and obj[i], `i in obj`, descriptors and keys through the binding.

**Takeaway**: **When the binding needs to know whether an impl implements a member, codegen states it next to the gated delegate; never have the adapter reach into impls, and never wire a delegate the impl may not have.**
