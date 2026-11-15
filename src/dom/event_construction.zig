//! The event constructing steps an Event subclass runs and no IDL member
//! reaches: DOM's "inner event creation steps" (the initialized flag,
//! timeStamp, bubbles, cancelable, composed), the dispatch flag the legacy
//! init*Event() methods consult, UIEventInit's members (view, detail, the
//! legacy which), which every UIEvent subclass's constructor sets, and
//! MouseEventInit's relatedTarget, which every MouseEvent subclass's
//! constructor sets and the MouseEvent keeps.
//!
//! Event, UIEvent and MouseEvent install their steps here once, at process
//! start (their installHooks), and the subclasses ask, never naming the
//! impls.
//!
//! Spec: https://dom.spec.whatwg.org/#inner-event-creation-steps
//!
//! lint-impls: hook for Event, UIEvent, MouseEvent

const std = @import("std");
const Hook = @import("hook.zig").Hook;
const runtime = @import("runtime");
const event_listener_list = @import("event_listener_list.zig");

/// EventInit's members.
pub const EventInit = struct {
    bubbles: bool = false,
    cancelable: bool = false,
    composed: bool = false,
};

/// UIEventInit's own members.
pub const UIEventInit = struct {
    view: ?*runtime.Instance = null,
    detail: i32 = 0,
    which: u32 = 0,
};

/// An EventInit dictionary's members (any dictionary with EventInit's
/// optional bubbles, cancelable and composed), defaults applied.
pub fn eventInitFrom(dictionary: anytype) EventInit {
    return .{
        .bubbles = dictionary.bubbles orelse false,
        .cancelable = dictionary.cancelable orelse false,
        .composed = dictionary.composed orelse false,
    };
}

/// A UIEventInit dictionary's own members (view, detail, which), defaults
/// applied.
pub fn uiEventInitFrom(dictionary: anytype) UIEventInit {
    return .{
        .view = dictionary.view,
        .detail = dictionary.detail orelse 0,
        .which = dictionary.which orelse 0,
    };
}

/// The value an event keeps for its type attribute, given the string its
/// constructor or initEvent() received (BORROWED: the argument conversion
/// frees it when the call returns). A type the engine lists - every type a
/// specification names (dom.event_listener_list's table) - is kept as the
/// table's own string: no copy and no allocation, as a listener keeps a
/// listed type (dom.event_listener_list.EventType), and as Blink and WebKit
/// keep an event's type as an atom shared by every event of that type
/// (Event's type_ and m_type). Any other type is copied. OWNED either way:
/// `DOMString.deinit` frees the copy and leaves a listed type alone.
pub fn ownedType(allocator: std.mem.Allocator, event_type: runtime.DOMString) error{OutOfMemory}!runtime.DOMString {
    const bytes = event_type.asSlice();
    if (event_listener_list.Key.of(bytes).static_bits != 0) {
        // A listed type's EventType is its id: nothing is allocated.
        const listed = try event_listener_list.EventType.init(allocator, bytes);
        return runtime.DOMString.initInterned(listed.slice());
    }
    return event_type.clone(allocator);
}

/// What the Event impl supplies.
pub const EventSteps = struct {
    /// DOM "inner event creation steps" for `event`, then "initialize
    /// event's type attribute to type". `event_type` is copied.
    inner_event_creation_steps: *const fn (event: *runtime.Instance, event_type: runtime.DOMString, init: EventInit) anyerror!void,
    /// Whether `event`'s dispatch flag is set.
    dispatch_flag: *const fn (event: *runtime.Instance) bool,
    /// Set the canceled flag directly (HTML "abort the ongoing navigation"
    /// step 6), independently of cancelable and the passive-listener flag.
    force_canceled_flag: *const fn (event: *runtime.Instance) void,
};

/// What the UIEvent impl supplies.
pub const UIEventSteps = struct {
    /// Initialize `event`'s view, detail and which from UIEventInit.
    initialize: *const fn (event: *runtime.Instance, init: UIEventInit) void,
};

/// What the MouseEvent impl supplies.
pub const MouseEventSteps = struct {
    /// Set `event`'s relatedTarget to `target` and keep it - an edge from the
    /// event's wrapper, which the MouseEvent's teardown ends.
    set_related_target: *const fn (event: *runtime.Instance, target: ?*runtime.Instance) error{OutOfMemory}!void,
};

/// Process-wide, written once at start-up (process_start.zig).
var event_steps: Hook(?EventSteps) = .init(null);
var ui_event_steps: Hook(?UIEventSteps) = .init(null);
// process-wide: an immutable function pointer installed once at process start, before Browsers start; each call acts only on the event it is given.
var mouse_event_steps: Hook(?MouseEventSteps) = .init(null);

/// Called by Event's installHooks, once, at process start (process_start.zig).
pub fn installEvent(steps: EventSteps) void {
    event_steps.install(steps);
}

/// Called by UIEvent's installHooks, once, at process start (process_start.zig).
pub fn installUIEvent(steps: UIEventSteps) void {
    ui_event_steps.install(steps);
}

/// Called by MouseEvent's installHooks, once, at process start (process_start.zig).
pub fn installMouseEvent(steps: MouseEventSteps) void {
    mouse_event_steps.install(steps);
}

/// Set a MouseEvent's (or a subclass's) relatedTarget from its init
/// dictionary, kept by the event for as long as it lives.
pub fn setMouseRelatedTarget(event: *runtime.Instance, target: ?*runtime.Instance) error{ NotSupported, OutOfMemory }!void {
    const steps = mouse_event_steps.get() orelse return error.NotSupported;
    try steps.set_related_target(event, target);
}

/// DOM "inner event creation steps" for `event` - made by its interface's
/// init, which chains through Event's - then its type.
pub fn innerEventCreationSteps(event: *runtime.Instance, event_type: runtime.DOMString, init: EventInit) !void {
    const steps = event_steps.get() orelse return error.NotSupported;
    try steps.inner_event_creation_steps(event, event_type, init);
}

/// Whether `event`'s dispatch flag is set.
pub fn dispatchFlag(event: *runtime.Instance) bool {
    const steps = event_steps.get() orelse return false;
    return steps.dispatch_flag(event);
}

/// HTML's direct canceled-flag assignment; not DOM's guarded cancel steps.
pub fn forceCanceledFlag(event: *runtime.Instance) void {
    const steps = event_steps.get() orelse return;
    steps.force_canceled_flag(event);
}

/// Initialize `event`'s UIEventInit members.
pub fn initializeUIEvent(event: *runtime.Instance, init: UIEventInit) void {
    const steps = ui_event_steps.get() orelse return;
    steps.initialize(event, init);
}

test "an event keeps a listed type as the table's string and copies any other" {
    const allocator = std.testing.allocator;
    // The argument is the binding's: gone when the call returns.
    const given = try allocator.dupe(u8, "click");
    var listed = try ownedType(allocator, runtime.DOMString.initInterned(given));
    allocator.free(given);
    defer listed.deinit(allocator);
    try std.testing.expect(listed == .interned);
    try std.testing.expectEqualStrings("click", listed.asSlice());
    // A listed type allocates nothing: an allocator that cannot allocate serves it.
    var other = try ownedType(std.testing.failing_allocator, runtime.DOMString.initInterned("DOMContentLoaded"));
    defer other.deinit(std.testing.failing_allocator);
    try std.testing.expectEqualStrings("DOMContentLoaded", other.asSlice());

    // A type no specification names is the event's own copy.
    const custom_given = try allocator.dupe(u8, "ev1-custom-type");
    var custom = try ownedType(allocator, runtime.DOMString.initInterned(custom_given));
    allocator.free(custom_given);
    defer custom.deinit(allocator);
    try std.testing.expect(custom == .owned);
    try std.testing.expectEqualStrings("ev1-custom-type", custom.asSlice());
    try std.testing.expectError(error.OutOfMemory, ownedType(std.testing.failing_allocator, runtime.DOMString.initInterned("ev1-custom-type")));

    // Matching is exact: another case of a listed type is not that type.
    var upper = try ownedType(allocator, runtime.DOMString.initInterned("Click"));
    defer upper.deinit(allocator);
    try std.testing.expect(upper == .owned);
    // The empty string is the empty DOMString.
    var empty = try ownedType(allocator, runtime.DOMString.initEmpty());
    defer empty.deinit(allocator);
    try std.testing.expectEqualStrings("", empty.asSlice());
}

test "without installed steps, event construction reports NotSupported and does nothing else" {
    const event_override = event_steps.overrideForTest(null);
    defer event_override.restore();
    const ui_override = ui_event_steps.overrideForTest(null);
    defer ui_override.restore();
    // Never dereferenced: with no steps installed nothing reads it.
    var event: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, innerEventCreationSteps(&event, runtime.DOMString.initInterned("x"), .{}));
    try std.testing.expect(!dispatchFlag(&event));
    initializeUIEvent(&event, .{});
}
