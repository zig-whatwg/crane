# Testing: A ported test driver's actions ignore opacity; its assertions do not

**Date**: 2026-11-11
**Lesson**: Cypress decides "visible" two ways - its `be.visible` / `:visible` assertions count `opacity: 0` as hidden, its actions (`check`, `click`, `type`) do not - so a port of its commands must carry that option to each call site.

**Why**: Cypress 15.14.2's `isHidden(el, method, { checkOpacity })` defaults `checkOpacity` to true (packages/driver/src/dom/visibility.ts:25, :108, :435), and the actionability check passes `{ checkOpacity: false }` (packages/driver/src/cypress/ensure.ts:134). TodoMVC's stylesheet draws each todo's checkbox on its label and makes the real `<input class="toggle">` `opacity: 0`; the spec clicks it with `.check()` and no `{force: true}`.

**What Happened**: Lane fw1 b3's first Chrome run of Crane's in-page port of TodoMVC's app spec (tests/frameworks/todomvc/) failed 9 of React's 28 tests with "`.find('.toggle').check()`: it is not visible": the port's one visibility predicate counted opacity for actions too. Chrome was right and the port was wrong; had the port been run in Crane first, the 9 failures would have read as Crane's.

**Fix**: `hiddenByStyle(el, checkOpacity = true)` in tests/frameworks/todomvc/driver.js; the actionability wait calls `isVisible(el, false)`. All 28 then passed in Chrome.

**Takeaway**: **When porting a test driver, port each of its predicates with the options every call site passes, and prove the port in a real browser before any engine result counts.**
