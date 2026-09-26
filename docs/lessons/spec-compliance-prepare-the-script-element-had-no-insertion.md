# Spec Compliance: "Prepare the script element" had no insertion-steps caller

**Date**: 2026-09-22
**Lesson**: `prepareScriptElement` was only ever called by the two parser paths,
so a script created by `document.createElement` and appended never ran.

**Why**: HTML lists "the script element becomes connected" as a trigger for
preparing a script that is *not* parser-inserted. `src/dom/mutation.zig` has the
registry for exactly this (`registerInsertionStepsCallback`), and only
`HTMLIFrameElement` had ever used it.

**What Happened**: `execution-timing/` builds 140 of its 153 files out of
`testlib.addScript()`, which is `createElement('script')` + `appendChild`. None
of those scripts ran. Three further defects were hiding behind that one, each
invisible until the one in front of it was fixed:

1. `handleScriptScheduling` tested `has_async` where step 35.1 says "has an
   `async` attribute **OR** force async is true", so a dynamically-inserted
   `<script src>` fell through all four cases onto a bare `return true`.
2. Nothing drained the "execute as soon as possible" queues - `executeScriptsAsap`
   and `executeScriptsInOrderAsap` existed and had no callers.
3. `Document.InternalState.base_uri` is assigned by nothing in the tree, so every
   relative `src` resolved to itself. An absolute URL in the same position
   worked, which is what isolated it.

**Fix**: register the insertion steps from `HTMLScriptElement.init`. The parser
is excluded by the spec's own condition and needs no extra flag: both tree
builders set the parser document on the element *before* appending it, so
`isParserInserted` is already true. That ordering is load-bearing - the parser
appends the script while it is still EMPTY and adds its text children
afterwards, so preparing it on insertion would mark a sourceless script
already-started and kill it.

**Takeaway**: **When a directory of tests all hang on the same idiom, look for
the algorithm that idiom triggers and ask who calls it. "No caller" is a
likelier answer than "wrong implementation", and grep answers it in one line.**
