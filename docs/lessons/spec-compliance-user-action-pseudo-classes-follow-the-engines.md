# Spec Compliance: :hover and :active follow the engines' observable rules

**Date**: 2026-10-16
**Lesson**: Implementing :hover and :active, the per-subtest browser results decided three rules the HTML prose does not state: keyboard activation is the element alone, a removed element hands its state to its parent, and moving the focus with Tab ends :active.

**Why**: HTML 4.16.3 says :active "also matches flat tree ancestors of elements that are being activated" and is silent on removal and focus changes. The engines agree among themselves on narrower behaviour, and WPT (forms/the-button-element/active-onblur.html, the-input-element/checkable-active-onblur*.html, css/selectors/active-observable.html) observes it.

**What Happened**: Lane selectors first applied the ancestor rule to a button held by Space; active-onblur.html's `querySelector(':active')` then found `<html>` instead of the button (Chrome and Safari pass it: Blink sets the element's own active flag, outside the document's active chain). Pointer presses do include ancestors (active-observable.html, all three). Blink's Document::ActiveChainNodeDetached and HoveredElementDetached move the state to the detached element's parent; Tab clears :active even with the pointer still held (checkable-active-onblur-with-click.html, Chrome and Firefox).

**Fix**: dom.pointer_states (hovered, pointed, activated - weak links on the Document); html/pseudo_classes.zig applies ancestors and the label rule to the pointer states only; Document's removing steps pass a removed element's states to its old parent; user_input.zig clears :active on Tab navigation.

**Takeaway**: **For user-action state, read each subtest's browser result before applying the prose: the engines' narrower rules are what WPT checks.**
