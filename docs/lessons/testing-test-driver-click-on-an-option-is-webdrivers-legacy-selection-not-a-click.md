# Testing: test_driver.click on an option is WebDriver's legacy selection, not a click

**Date**: 2026-11-18
**Lesson**: WebDriver's Element Click turns a click on an `<option>` into its own selection sequence at the option's select, so a test that picks a customizable-select option with `test_driver.click(option)` never runs the picker's "pick an option" and the picker stays open.

**Why**: WebDriver 2's Element Click special-cases option elements: the events go to the option's container (the select) - mouseover, mousemove, mousedown, focus, input and change after it sets the option's selectedness itself, mouseup, click - with no pointer input at the option. HTML's "pick an option", whose step 7 hides a base-appearance select's picker, belongs to a real click in the picker; the WebDriver shortcut bypasses it.

**What Happened**: Lane blk2 found select-pick-option-dirtiness.html and select-picker-hover-after-picking.html blocking ("Select should be closed after picking an option. expected false got true"). Chrome 157 and Safari 27.2 fail them with the same message (Firefox has no base-select). A probe in Crane logged `mousedown@s | input@s | change@s | mouseup@s | click@s` - every event at the select, no pointerdown, the value changed - and `:open` still true: Crane's runner follows WebDriver, exactly as the browsers' drivers do.

**Fix**: Nothing in the engine. The test should pick with pointer actions at the option (`new test_driver.Actions().pointerMove(0, 0, {origin: option}).pointerDown().pointerUp()`); an upstream issue draft is in tmp/plans/blk2-upstream-drafts/5-customizable-select-test-driver-click-option.md.

**Takeaway**: **Before "fixing" a picker that does not close after `test_driver.click(option)`, log where the events land: at the select with no pointer events means WebDriver's option shortcut, a test bug, not an engine bug.**
