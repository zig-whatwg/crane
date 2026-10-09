# Codegen: An iterable declaration's members are not operations

**Date**: 2026-10-09
**Lesson**: Codegen added a synthetic `forEach` operation for every `iterable<>`. Each NodeList and DOMTokenList bound forEach to an impl stub that never called its callback (`classList.forEach` saw 0 of 2 tokens). Meanwhile a value iterator's @@iterator, entries, keys and values were the adapter's own iterator objects instead of the realm's Array.prototype functions.

**Why**: WebIDL 3.7.9 "define the iteration methods" makes the members. With an indexed property getter, @@iterator is %Array.prototype.values%. With a value iterator (one type parameter), entries, keys, values and forEach are %Array.prototype.entries%, %Array.prototype.keys%, %Array.prototype.values% and %Array.prototype.forEach%, the same function objects. A pair iterator gets functions of its own: one F named "entries" serves as both %Symbol.iterator% and entries. None of these members is an operation. An operation the generator invents is a map entry (`call_forEach`) that some impl has to fill in, and a stub fills it with nothing.

**What Happened**: The generator added forEach three times: to own_ops, to all_ops, and to Meta.methods (twice). It also wrote a NotImplemented stub into impls_tmp. For a pair iterator the adapter's setUpPrototype overwrote the bound forEach at runtime, so seventeen `call_forEach` stubs sat behind the map unreached. For a value iterator it installed a forEach that read `getEntriesForIterable`, which value iterators do not have, so it did nothing.

**Fix**: The generator emits no member for an iterable declaration, only `Meta.iterable` with `key_type = null` for a value iterator. The adapter installs a value iterator's members on the prototype template with `SetIntrinsicDataProperty` (kArrayProto_entries/keys/values/forEach). Each instantiation resolves these from its own context, so every realm holds its own functions; Blink's bind_gen/interface.py installs the same four. A [Global] interface gets none (step 12). The stubs nothing bound any more were deleted.

**Takeaway**: **When the spec says "define" members, the binding defines them. Codegen must not turn them into operations for an impl to implement.**
