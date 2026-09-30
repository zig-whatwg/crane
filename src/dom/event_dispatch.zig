//! What DOM's dispatch algorithm does to an Event that no IDL member does.
//!
//! Dispatch runs in EventTarget's impl, and the event's state is Event's. Most
//! of what dispatch sets has an attribute that reads it back but no setter;
//! the one step here so far is "invoke" step 9, which renames a trusted
//! animation or transition event to its legacy WebKit type while the legacy
//! listeners run, and back again. Event installs the implementation from its
//! init, which every event's init chains through.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-event-listener-invoke
//!
//! lint-impls: hook for Event

const std = @import("std");
const runtime = @import("runtime");

/// What the Event impl supplies.
pub const Implementation = struct {
    /// Set `event`'s type attribute value to `event_type`, which the event
    /// then holds, and hand back the value it held (its owner is the caller).
    /// No copy, no free: the swap is undone with the value it returned.
    swap_type: *const fn (event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString,
};

/// Per thread, like the events.
threadlocal var implementation: ?Implementation = null;

/// Called by Event. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `event`'s type attribute value becomes `event_type`; the previous value is
/// returned, to be swapped back. Null when `event` is not an Event.
pub fn swapType(event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString {
    const impl = implementation orelse return null;
    return impl.swap_type(event, event_type);
}

/// "Invoke" step 9.2: the legacy type an event type is renamed to for
/// listeners registered only under that name - the table's second column for
/// the first - or null.
pub fn legacyEventType(event_type: []const u8) ?[]const u8 {
    const table = [_][2][]const u8{
        .{ "animationend", "webkitAnimationEnd" },
        .{ "animationiteration", "webkitAnimationIteration" },
        .{ "animationstart", "webkitAnimationStart" },
        .{ "transitionend", "webkitTransitionEnd" },
    };
    for (table) |row| {
        if (std.mem.eql(u8, event_type, row[0])) return row[1];
    }
    return null;
}

test "invoke step 9.2 maps the four unprefixed types, exactly, and nothing else" {
    try std.testing.expectEqualStrings("webkitAnimationEnd", legacyEventType("animationend").?);
    try std.testing.expectEqualStrings("webkitAnimationIteration", legacyEventType("animationiteration").?);
    try std.testing.expectEqualStrings("webkitAnimationStart", legacyEventType("animationstart").?);
    try std.testing.expectEqualStrings("webkitTransitionEnd", legacyEventType("transitionend").?);
    try std.testing.expect(legacyEventType("AnimationEnd") == null);
    try std.testing.expect(legacyEventType("webkitAnimationEnd") == null);
    try std.testing.expect(legacyEventType("transitionrun") == null);
}
