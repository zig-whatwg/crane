# Architecture: A codegen-stub `init` silently produces a stateless node

**Date**: 2026-09-22
**Lesson**: `CDATASection.zig` and `ProcessingInstruction.zig` still had the
generated stub `init` - `runtime.Instance.init(...)` plus `// TODO: Initialize
your instance state here if needed` - so they never chained through
`CharacterDataImpl.init` -> `NodeImpl.init` -> `EventTargetImpl.init`.

**Why**: An impl's `init` IS the inheritance chain. Skipping it produces an
instance with the right vtable and the right `State` type - so it wraps, it
passes every pointer guard, and `instanceof` is correct - but with none of the
state its parents own. Its data, node type, parent, owner document and listener
list are all simply absent, and every accessor returns `InvalidStateError`.

**What Happened**: `document.createCDATASection()` and
`createProcessingInstruction()` had never returned a usable node. That is not
niche, because `dom/ranges` and much of `dom/nodes` build their fixtures in
`dom/common.js`, which calls both inside `setup()` - and testharness rethrows
out of `setup()`, so ONE DOMException there turns the whole file into a harness
ERROR with zero subtests. 20 of 30 `dom/ranges` files reported ERROR for this,
and the runner shows only `Error: [object DOMException]`, naming neither the
call nor the file.

The same shape hid elsewhere: `Event.init` allocates the instance but leaves
`_internal` null, and only `Event.call_constructor` creates it. So
`Event.init` + `initEvent` took `initEvent`'s `getInternal(...) orelse return`
early exit, the initialized flag was never set, and `dispatchEvent` rejected the
event per DOM 2.8 step 1 - which is why DOMContentLoaded never fired on any
document.

**Fix**: Chain `init` to the parent impl. To find the rest:

```bash
grep -rn "TODO: Initialize your instance state" src/webidl/impls/
grep -rln "runtime.Instance.init" src/webidl/impls/   # should be rare
```

Then check the constructor, not just `init`: if `X.call_constructor` creates
`_internal` and `X.init` does not, every engine-side caller of `init` gets a
stateless object.

**Takeaway**: **A stub `init` fails as `InvalidStateError` from somewhere else
entirely, long after construction. When a whole directory ERRORs with zero
subtests, suspect one throwing call in a shared `setup()` before suspecting the
tests.**
