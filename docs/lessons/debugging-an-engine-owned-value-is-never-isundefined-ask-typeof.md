# Debugging: An engine-owned value is never `isUndefined()` - ask `engine.typeOf`

**Date**: 2026-11-14
**Lesson**: `JSValue.isUndefined()` answers only for an inline JSValue; a value the engine hands back as `engine.Owned` (`engine.getProperty`, a sequence's items) is a handle, and its `.value.isUndefined()` is false even when the property is absent - test it with `engine.typeOf(realm, value) == .undefined`.

**Why**: An Owned value carries the engine's handle, not the inline undefined tag `isUndefined()` looks for. Code that also checks the type afterwards (`typeOf(...) == .string` in test_driver's `stringProperty`) hides it: the absent property falls through to the type check and reads as "not a string". Code that branches on `isUndefined()` alone takes the wrong branch for every absent property.

**What Happened**: Lane quick2 taught the WPT runner's test_driver (WebDriver Perform Actions) to read a pointer source's optional `parameters` and an action's optional `width`/`pressure`/... properties, each guarded by `value.value.isUndefined()`. Every action sequence of every test then failed with "invalid argument: parameters is not an object" or "an action is not well formed": testdriver-actions.js omits absent properties, and each read as present. 90 pointerevents files went from passing to ERROR on the lane's first runner; the native tests drove user_input directly and never saw it. A five-subtest probe page (tests/wpt/crane) named the cause in one run.

**Fix**: `switch (engine.typeOf(realm, owned.value)) { .undefined => ..., .number => ..., else => ... }` for every optional member read through `engine.getProperty`. The pre-existing `origin` check in parseAction had the same latent bug (testdriver always sends an origin, so it never showed); fixed with it.

**Takeaway**: **An Owned value is a handle: only `engine.typeOf` says it is undefined. And a native test that bypasses the remote end proves nothing about the remote end's parsing - run one real action sequence through it before trusting a runner.**
