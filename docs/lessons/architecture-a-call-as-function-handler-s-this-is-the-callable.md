# Architecture: A call-as-function handler's This is the callable object

**Date**: 2026-10-01
**Lesson**: `document.all(x)` answered undefined, and the diagnosis handed to the next lane was that the legacy caller's handler read the call's receiver (the Document, or the global for `const a = document.all; a(x)`) instead of the collection. V8 makes that impossible: the handler's `info.This()` is always the called object. The collection's impl was an untouched stub.

**Why**: V8 calls a non-function callable (an ObjectTemplate with a call-as-function handler, as HTMLAllCollection's is) through `Builtins::Call`, which "Overwrite[s] the original receiver with the (original) target" before tail-calling the call-as-function delegate (`builtins-arm64.cc`, Generate_Call); `HandleApiCallAsFunctionOrConstructorDelegate` (`builtins-api.cc`) then builds the FunctionCallbackArguments with that receiver. Whatever `this` the script passes is gone by then.

**What Happened**: HTMLAllCollection's `get_length`, `call_item` and `call_namedItem` all returned `error.NotImplemented`, and `Document.get_all` makes the collection without telling it its document - there is nothing for it to answer from. The handler swallowed the error and returned undefined, which read like a type confusion. What WAS wrong in the handler: with no argument it answered undefined (WebIDL legacycaller + HTML item() step 1: null), and each call left its current context, the argument and the result behind (64 calls: 64 Context Globals, 6,144 bytes).

**Fix**: the handler converts its argument as item()'s (undefined is "not provided"), throws item()'s errors, returns null or the result, and releases everything it made; item() step 1 is in the impl. The collection itself (rooted at its document, "all"-named elements, the legacy caller returning a collection) is a feature, queued.

**Takeaway**: **Before blaming a binding for the object it hands an impl, check what the engine passes and what the impl does with it - a stub that fails quietly looks like a wrong receiver.** For V8's call-as-function handlers, This() is the callable.
