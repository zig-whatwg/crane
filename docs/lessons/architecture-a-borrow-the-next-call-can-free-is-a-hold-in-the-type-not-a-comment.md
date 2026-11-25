# Architecture: A borrow the next call can free is a hold in the type, not a comment

**Date**: 2026-11-24
**Lesson**: When an engine cache answers a pointer that its next read may free, make the answer an owning hold (a reference the caller releases) and keep the raw borrow private, instead of documenting "valid until the next read" and auditing callers.

**Why**: `dom.style.computedStyle` answered a `*const ComputedStyle` "valid until the next style read of the element". A volatile style (a form control matched against a state pseudo-class - and, through the UA sheet's universal `:autofill` rule, every style inside a `<form>`) is resolved again on every read of the element or of anything below it, and `ElementStyle.setCached` destroyed the old one. Whether a caller was safe depended on what every callee between its read and its last use did, transitively, and on invariants nobody wrote down (a pseudo-element's cache entry is replaced only by a read of that pseudo-element). Production builds read the freed bytes silently; only the poisoning allocator of the unit tests and the bug-finding WPT run showed it, and only for a volatile element.

**What Happened**: Lane a11y1's bug-finding run crashed in `hiddenViaStyle` (a style read across `rendered()`, fixed f6ff67afb). Lane cs1 surveyed about 80 call sites: none was live after that fix, but one latent (`font_loading.selectControl`'s `orelse style` after a `::placeholder` read) and six were safe only by call order. Five red tests on a std.testing.allocator realm (e0c063b12) crashed at the first field of the freed style; the UA-only `<form>` case confirmed that every style inside a form is volatile with no author sheet at all.

**Fix**:
1. `ComputedStyle.refs` (one byte, in the word its narrow fields share: 0 B): `retain`, `release` (the last one frees), `destroy` for a sole owner (Debug panics while another holder reads it). The element's cache releases instead of destroying. Blink kept `scoped_refptr<const ComputedStyle>` until Oilpan; WebKit counts borrows with `CanMakeCheckedPtr` and crashes on a destroy while one lives.
2. `dom.style.computedStyle` answers `?HeldStyle` (`style` until `release()`); the raw borrow is `resolvedStyle`, private to engine.zig. A full count holds a clone - no panic in any build.
3. Holds never cross into script: Debug counts them on the agent (`DeferredTeardown.native_holds`, `void` outside Debug) and `runtime.native_holds.assertNone` panics at every script entry of the engine protocol's generic layer and at each Browser event-loop turn. That also makes a discarded hold (`_ = computedStyle(...)`, a leak) loud at the next script entry.
4. A comptime test pins that no public `dom.style` function answers a bare style.

**Takeaway**: **"Borrowed until the next read" is a lifetime only every future callee can keep; put it in the type - an owning hold the caller releases, the raw pointer private - and check in Debug that the hold never outlives the native call that took it.**
