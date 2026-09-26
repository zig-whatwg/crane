# Codegen: Deduplicating operations by name deleted every overload

## Overloads were deduplicated keep-first

**Date**: 2026-09-22
**Lesson**: `deduplicateOperations` kept the first operation of each name, so
`XMLHttpRequest.open(method, url, async, ...)` was never bound and every XHR
was asynchronous - about 96 overload sets across the IDL lost a signature.

**Takeaway**: **Check the generated `methods` arity before debugging an
operation: the overload you are testing may not exist.**

## Deduplicating operations by name deleted every overload

**Date**: 2026-09-22
**Lesson**: `deduplicateOperations` kept the first operation of each name, so every overloaded operation bound only overload 0, and the binding layer stopped at four arguments.

**What Happened**: `open(m, url, false)` ran asynchronously; `postMessage(msg, options)`, `FormData.append(name, blob)` and ~50 other overload sets silently dropped arguments. Every five-argument operation threw "not yet implemented".

**Fix**: codegen emits `call_<op>__<k>` delegates and an `overloads` table; `interface.zig` runs WebIDL overload resolution inside overload 0's callback; `callMethodWithArgs` has an `ArgsTuple` fallback for any arity. `sameOverloadSignature` treats all string types as equal (one operation declared as DOMString and CSSOMString in two IDL sources is not an overload). The supplementary codegen run rewrites every `root.zig` and `typedefs/{CSSOMString,WindowProxy}.zig` with only its own definitions - restore them from HEAD. To implement an overload, add `call_<op>__<k>` to the impl; until then overload 0 runs.

**Takeaway**: **Dedupe by signature, not by name, and read a hand-unrolled arity switch's `else` branch - it is an undocumented limit.**
