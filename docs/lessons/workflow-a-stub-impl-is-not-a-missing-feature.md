# Workflow: A stub impl is not a missing feature - check what the interface delegates to and what the sweep passes

**Date**: 2026-11-06
**Lesson**: Before planning "build feature X", find where X's behaviour actually lives and how many of its WPT subtests already pass. An impl file that still carries the codegen's `ImplError{ NotImplemented }` boilerplate, or a mixin impl left as a stub, says nothing about whether the feature exists.

**Why**: Crane implements a type's steps outside its impl. The steps go in a `src/dom/<subsystem>/` module that the impl delegates to, or that a hook reaches. Codegen also leaves `ImplError{ NotImplemented }` in every impl it stubs, and nothing removes it once the impl is written. A mixin's members are implemented in each includer's impl until the mixin joins `codegen/inherited_mixins.zig`, so the mixin's own impl stays a stub. So a grep of `src/webidl/impls/` for NotImplemented matches files that are complete.

**What Happened**:
- The animation plan (2026-11-05) said "Crane has no animation engine: Animatable.call_animate and call_getAnimations return NotImplemented, and the Animation, KeyframeEffect and DocumentTimeline impls are stubs". It sized a five-phase lane on that, starting with designing the engine.
- In fact, lanes rendering2 and rendering3 had built it in src/dom/animations/ (5,300 lines): the timing model, "update animations and send events", the effect stack, the cascade's animation and transition origins, and commitStyles.
- The impls named were thin delegates with leftover boilerplate. Animatable was a stub only because Element's impl carried its members.
- The generation sweep already showed 3,598 passing subtests in web-animations/.
- Lane anim1 found this in its first ten minutes by reading the impls' imports and the sweep. Its design batch became a gap analysis of real failures: no CSS transitions or animations made from style, custom properties skipped in keyframes, a discarded iterationComposite option.

**Fix**:
1. Read the impl's imports. A `@import("dom").<subsystem>` or a hooks call means the behaviour lives there; read that module's header.
2. Count the feature's passing and failing subtests in the newest generation sweep (`journal.wptreport.jsonl`). Group the failures by message before you name a cause.
3. Before writing a plan, `git log --oneline -- src/dom/<subsystem>/` to see which lanes built what. Read their handoffs' queues, which list what is still missing.

**Takeaway**: **The sweep and the subsystem module are the truth about a feature. An impl's NotImplemented boilerplate or a stub mixin impl is not. Plan from the failures, grouped by cause.**
