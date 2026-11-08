# Spec Compliance: A per-scope field nothing sets can hide a retargeting step

**Date**: 2026-11-08
**Lesson**: ShadowRoot's state had its own fullscreen, pointer lock, Picture-in-Picture and active element fields (32 B a shadow root), and nothing ever set them. The spec keeps no such state per shadow root. Each getter retargets the node DOCUMENT's one element against `this`, and Document's getters skipped that step too.

**Why**: The mixin DocumentOrShadowRoot declares the same attributes for both kinds of scope, and an impl generated or written attribute-by-attribute gives each scope a field per attribute. Since nothing sets these elements yet (Crane runs no fullscreen, pointer lock or PiP request), a field returning null and the spec's computation agree on every page. The mistake shows only once a request algorithm lands. Then document.fullscreenElement would have leaked an element from inside a shadow tree, and a shadow root's getter would never have seen it.

**What Happened**: Lane perf2 batch 8 had the ShadowRoot fields on its node-size queue as "never set, move to rare data". Reading the getter steps showed they should not exist at all:
- Fullscreen's fullscreenElement getter steps: null when this is a shadow root whose host is not connected; otherwise retarget the fullscreen element against this, and return it if it is in this's tree.
- Picture-in-Picture 4.3: the same four steps.
- Pointer Lock 2.0: the same retargeting and same-tree test, with no host check (its own #host1/#canvas1 example became the unit test).

dom.designated_elements now reads the document's element and retargets it for both scopes. Blink keeps each element once per document and adjusts it to the asking scope (Fullscreen::FullscreenElementForBindingFrom -> TreeScope::AdjustedElement).

**Fix**: Before moving a never-set field to rare data, read the attribute's getter steps: a mixin attribute whose steps start from the node document's state needs no per-scope field, only a getter that retargets.

**Takeaway**: **A field that nothing sets is a question, not a saving: read the getter's steps first, because the state may belong to another object and the getter may owe a retargeting step.**
