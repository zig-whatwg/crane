# Codegen: A returned dictionary cannot carry a present null

**Date**: 2026-10-29
**Lesson**: A nullable dictionary member with no IDL default is generated as a Zig optional (`progress: ?f64 = null`), whose null means "not present" - so an impl that returns the dictionary cannot say "present, and null", and script reads `undefined` where the spec says `null`.

**Why**: WebIDL 3.2.18 writes a dictionary member to the JavaScript object only if it is present; an absent nullable member is no property at all. The generated struct has one null for both states. The V8 converter (conversions.zig `writeDictionaryMembers`) writes a member when the optional is non-null or when `member_defaults` names an IDL default - and `double? progress;` has none.

**What Happened**: Lane rendering2's `AnimationEffect.getComputedTiming()` must return `progress: null`, `currentIteration: null` and `localTime: null` for an effect that is not in effect (Web Animations 6.5.5; every browser returns null). The Crane test `webanim-effect-timing.html` read `undefined` for all three. web-animations/ tests assert `assert_equals(timing.progress, null)` throughout.

**Fix**: Not fixed in the lane (codegen output and the V8 converter are the integrator's). Two shapes: generate a returned dictionary's nullable members without defaults as `webidl.Opt(?T)` (present null expressible), or have the converter write a listed nullable member's null as null for dictionaries returned to script. The Crane test checks `== null` until then, with a comment naming this lesson.

**Takeaway**: **A Zig optional has one null: for a nullable dictionary member without a default, "absent" and "null" need two states, or a returned dictionary reads undefined where the spec says null.**
