# Spec Compliance: Keeping a spec concept means implementing every step that writes it

**Date**: 2026-11-19
**Lesson**: When Crane starts keeping a piece of state that the spec defines (here the sequential focus navigation starting point), every algorithm step that moves, sets or unsets it belongs to the same change - list them from the spec's links to the concept, not from the bug being fixed.

**Why**: While the state is not kept, the steps that write it are harmless no-ops, and the code says so ("step 12: the starting point is not modelled"). Once the state is kept, each writer still missing leaves a stale value that another algorithm reads - in a directory nobody was looking at.

**What Happened**: Lane blk4 made the starting point a live Range on the Document (Blink's model) so that Tab after the focused element is removed or blurred continues from where it was (css/selectors/invalidation/user-action-pseudo-classes-in-has.html; Chrome and Firefox pass the tentative starting-point cases). The targeted runs covered focus and selection and were clean. The FULL A/B against generation 232 then lost 8 subtests in navigation-api/focus-reset/: "potentially reset the focus" step 12 ("Move the sequential focus navigation starting point to focusTarget") was one of the no-ops, so after the reset the point stayed on the button focused before the navigation and Tab went to the next one. "Sequential navigation" step 7 ("unset the starting point" when no candidate is found) was missing too: a viewport-focused document whose point had nothing after it found nothing on every later Tab.

**Fix**: `grep -n 'sequential-focus-navigation-starting-point' specs/whatwg/html.md` lists every writer: potentially reset the focus step 12, sequential navigation step 7, scroll to the fragment step 7 (whose focusing steps are still a TODO in dom/fragment_scroll.zig, so its move waits with them). dom.focused_area gained `moveStartPoint` and `unsetStartPoint`; Navigation's reset and html.focus's navigation call them (tests/html/blk4_sequential_start_test.zig). A subtest-by-subtest diff of the wptreport streams then showed 0 lost.

**Takeaway**: **Making a "not modelled" spec concept real changes every algorithm that writes it: list its writers from the spec's links before the first A/B, and judge the batch on a full A/B, not on the directories of the bug being fixed.**
