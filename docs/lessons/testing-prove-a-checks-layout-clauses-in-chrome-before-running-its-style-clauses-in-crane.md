# Testing: Prove a check's layout clauses in Chrome before running only its style clauses in Crane

**Date**: 2026-11-11
**Lesson**: A visibility check mixes computed-style clauses (no box, `visibility`, `opacity`) with layout clauses (zero size, overflow clipping, covered); run the style clauses in Crane, and prove in a real browser - by evaluating the layout clauses beside them and failing on any disagreement - that the layout clauses change no answer for the pages under test.

**Why**: Crane draws nothing, so every layout clause answers "hidden" there (no box has a size). Cypress's visibility rules (visibility.ts:143-172) decide even `display: none` through `getClientRects().length`, and TodoMVC's spec asserts `cy.contains('h1', /^todos$/i).should('be.visible')` in the `beforeEach` of all 29 tests: run whole, every test is a rendering test in Crane, and the React, Vue, Svelte and Angular rows would show nothing run. Excluding whole tests (the jQuery rule: a test with any layout assertion is excluded) would have measured nothing; dropping the layout clauses unproven would be weakening the test.

**What Happened**: Lane fw1 b3 split the port's predicate into `hiddenByStyle` (run) and `hiddenByLayout` (evaluated only with `?prove=layout`, where a global `afterEach` asserts the layout clauses changed no answer). Headless Chrome 157 passed every test of the four apps with the proof on (React, Vue, Svelte 28, Angular 27); the same proof in Crane failed all 111 runs on that one assertion - the control that shows the proof is not vacuous - while the style clauses passed all 111.

**Fix**: tests/frameworks/todomvc/driver.js (`hiddenByStyle`, `hiddenByLayout`, `?prove=layout`); the split and the Chrome result are written in tools/fw_matrix/excluded/todomvc-port.txt and on the report.

**Takeaway**: **Split a check into what computed style decides and what geometry decides; prove in Chrome that geometry changes no answer for these pages, keep the proof re-runnable, and run a Crane control so the proof is seen to bite.**
