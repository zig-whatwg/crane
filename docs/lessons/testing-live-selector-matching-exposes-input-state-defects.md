# Testing: Live selector matching can expose an input-state defect

**Date**: 2026-10-29
**Lesson**: When correct invalidation reveals incorrect state, repair the state transition and preserve invalidation.

**Validation**: Eight checks pass through real native pointer/key input with warm computed styles: Ctrl, Alt and Meta alone and with Shift+k, plus ordinary k and Shift alone. The new Crane page and final targeted A/B remain required after freezing.

**Why**: An unconditional keydown modality update treats Ctrl, Alt and Meta shortcuts as evidence that pointer focus should become visibly keyboard-focused. A stale computed-style cache can hide that transition.

**What Happened**: focus-visible-012.html lost its only passing test in three isolated pairs after the lane made focus-visible matching live. Pointer focus followed by Ctrl incorrectly acquired focus-visible styling. All three aligned browsers pass the test. Blink excludes keydowns with Ctrl, Alt or Meta from its keyboard-modality update; Shift alone still counts.

**Fix**: Q124 grants a guard only around the existing noteInputModality call. Do not suppress key dispatch, change focus navigation, or weaken selector invalidation. Test real pointer/key input, warm computed styles before the key, retain the focused element, and include ordinary-key and Shift controls.

**Takeaway**: **A new cache regression can be an old owner-state bug made observable. Pin both the owner transition and the public computed result.**

References: Selectors 4 section 9.4; Chromium 97f9cf6fa75ffd2d1f6847c167d11efc2683c833, third_party/blink/renderer/core/input/keyboard_event_manager.cc, KeyEvent lines355–359 (design only).
