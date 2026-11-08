# Debugging: A layout change that crashes a type it never touched - look for an unchecked cast

**Date**: 2026-11-08
**Lesson**: When shrinking one struct makes code of an unrelated type crash (here 65 stylesheet files crashed after Element's state shrank), suspect a cast that reads one type's state as another's: a hook that fans out to every owner type hands each impl instances of the other types, and an impl whose accessor has no brand check reads whatever bytes now lie at its offset.

**Why**: `webidl.utils.InternalStateAccessor(...).get(instance)` is `instance.getState(State).own._internal` - no check that `instance` is that interface. `dom.style.hooks.sheetOf` asks the style, the link and then the processing-instruction hook in turn, and `linkSheetArrived` gives a fetched sheet to the link's step and then the PI's. HTMLLinkElement and HTMLStyleElement read their state through `instance.stateAs(State)` (the ancestry check) and decline foreign instances; ProcessingInstruction used the unchecked accessor, so for a link element it read the link's State at the PI's `own._internal` offset as a pointer. On main those bytes happened to be harmless - main was only lucky.

**What Happened**: Lane perf3 D1 moved an element's attributes out of line: Element's embedded state went 848 -> 416 bytes inside perf2 b5's one block per node. Its FULL A/B crashed 65 files (ABRT), all on stylesheet loading paths (the-link-element, cssom HTMLLinkElement-*, resource-timing, CSP style-src, service-worker css) - none of which D1 touched. An in-process run of one file gave `Segmentation fault at address 0xaaaaaaaaaaaaaa4b` in `ProcessingInstruction.sheetArrived` <- `dom/style/hooks.zig linkSheetArrived` <- `style_sheet_loading.processResponse`: 0xaa.. is undefined memory in a safe build, now at the offset the PI read.

**Fix**:
1. ProcessingInstruction's getInternal became the checked one, as HTMLLinkElement's: `const state = instance.stateAs(State) orelse return null; return state.own._internal;`.
2. The test makes the bug deterministic on any layout: it writes 0xaa over the 8 bytes at the PI state's `own._internal` offset of a link, style and div element's State (computed at comptime from the generated States, asserted not to overlap the element's own state pointer), calls `sheetOf` / `linkSheetArrived`, and restores the bytes. Red at main and at the D1 tip (SEGV), green with the fix (tests/dom/perf3d1_sheet_hooks_test.zig).
3. The other 33 impls with the unchecked accessor went to the feature queue as a SAFETY item, the ones a hook can hand a foreign instance marked.

**Takeaway**: **A crash in code the change never touched, after a struct changed size, is a reader of the wrong type's bytes: find the cast with no brand check (a hook that fans out to every owner type is where foreign instances arrive), and make the test poison the bytes at the reader's offset so it fails on every layout, not only the unlucky one.**
