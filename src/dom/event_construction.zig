//! The event constructing steps an Event subclass runs and no IDL member
//! reaches: DOM's "inner event creation steps" (the initialized flag,
//! timeStamp, bubbles, cancelable, composed), the dispatch flag the legacy
//! init*Event() methods consult, and UIEventInit's members (view, detail,
//! the legacy which), which every UIEvent subclass's constructor sets.
//!
//! Event and UIEvent install their steps here from their init - which every
//! subclass's init chains through - and the subclasses ask, never naming
//! either impl.
//!
//! Spec: https://dom.spec.whatwg.org/#inner-event-creation-steps
//!
//! lint-impls: hook for Event, UIEvent

const std = @import("std");
const runtime = @import("runtime");

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

/// What the Event impl supplies.
pub const EventSteps = struct {
    /// DOM "inner event creation steps" for `event`, then "initialize
    /// event's type attribute to type". `event_type` is copied.
    inner_event_creation_steps: *const fn (event: *runtime.Instance, event_type: runtime.DOMString, init: EventInit) anyerror!void,
    /// Whether `event`'s dispatch flag is set.
    dispatch_flag: *const fn (event: *runtime.Instance) bool,
};

/// What the UIEvent impl supplies.
pub const UIEventSteps = struct {
    /// Initialize `event`'s view, detail and which from UIEventInit.
    initialize: *const fn (event: *runtime.Instance, init: UIEventInit) void,
};

/// Per thread, like the events themselves.
threadlocal var event_steps: ?EventSteps = null;
threadlocal var ui_event_steps: ?UIEventSteps = null;

/// Called by the Event impl. Idempotent.
pub fn installEvent(steps: EventSteps) void {
    event_steps = steps;
}

/// Called by the UIEvent impl. Idempotent.
pub fn installUIEvent(steps: UIEventSteps) void {
    ui_event_steps = steps;
}

/// DOM "inner event creation steps" for `event` - made by its interface's
/// init, which chains through Event's - then its type.
pub fn innerEventCreationSteps(event: *runtime.Instance, event_type: runtime.DOMString, init: EventInit) !void {
    const steps = event_steps orelse return error.NotSupported;
    try steps.inner_event_creation_steps(event, event_type, init);
}

/// Whether `event`'s dispatch flag is set.
pub fn dispatchFlag(event: *runtime.Instance) bool {
    const steps = event_steps orelse return false;
    return steps.dispatch_flag(event);
}

/// Initialize `event`'s UIEventInit members.
pub fn initializeUIEvent(event: *runtime.Instance, init: UIEventInit) void {
    const steps = ui_event_steps orelse return;
    steps.initialize(event, init);
}

test "without installed steps, event construction reports NotSupported and does nothing else" {
    const saved_event = event_steps;
    const saved_ui = ui_event_steps;
    defer {
        event_steps = saved_event;
        ui_event_steps = saved_ui;
    }
    event_steps = null;
    ui_event_steps = null;
    // Never dereferenced: with no steps installed nothing reads it.
    var event: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, innerEventCreationSteps(&event, runtime.DOMString.initInterned("x"), .{}));
    try std.testing.expect(!dispatchFlag(&event));
    initializeUIEvent(&event, .{});
}
