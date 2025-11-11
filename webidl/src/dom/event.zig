//! Event interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-event

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const EventTarget = @import("event_target").EventTarget;

/// EventPath struct - used by event dispatch algorithm
/// DOM §2.9.1: Each path struct consists of:
pub const EventPathItem = struct {
    invocation_target: *EventTarget,
    invocation_target_in_shadow_tree: bool,
    shadow_adjusted_target: ?*EventTarget,
    related_target: ?*EventTarget,
    touch_target_list: std.ArrayList(*EventTarget),
    root_of_closed_tree: bool,
    slot_in_closed_tree: bool,
};

/// Event WebIDL interface
pub const Event = webidl.interface(struct {
    allocator: Allocator,
    event_type: []const u8,
    target: ?*EventTarget,
    current_target: ?*EventTarget,
    event_phase: u16,
    bubbles: bool,
    cancelable: bool,
    composed: bool,

    // DOM §2.3 - Event flags (initially unset)
    stop_propagation_flag: bool,
    stop_immediate_propagation_flag: bool,
    canceled_flag: bool,
    in_passive_listener_flag: bool,
    initialized_flag: bool,
    dispatch_flag: bool,

    is_trusted: bool,
    time_stamp: f64,

    // DOM §2.3 - Event path (initially empty)
    path: std.ArrayList(EventPathItem),

    // DOM §2.3 - Related target (initially null)
    related_target: ?*EventTarget,

    // DOM §2.3 - Touch target list (initially empty)
    touch_target_list: std.ArrayList(*EventTarget),

    pub const NONE: u16 = 0;
    pub const CAPTURING_PHASE: u16 = 1;
    pub const AT_TARGET: u16 = 2;
    pub const BUBBLING_PHASE: u16 = 3;

    /// Constructor: new Event(type, eventInitDict)
    /// Spec: https://dom.spec.whatwg.org/#dom-event-event
    pub fn init(allocator: Allocator, event_type: []const u8, options: ?EventInit) !Event {
        const event_init = options orelse EventInit{};

        return .{
            .allocator = allocator,
            .event_type = event_type,
            .target = null,
            .current_target = null,
            .event_phase = NONE,
            .bubbles = event_init.bubbles,
            .cancelable = event_init.cancelable,
            .composed = event_init.composed,
            // DOM §2.3 - All flags initially unset
            .stop_propagation_flag = false,
            .stop_immediate_propagation_flag = false,
            .canceled_flag = false,
            .in_passive_listener_flag = false,
            .initialized_flag = false,
            .dispatch_flag = false,
            .is_trusted = false,
            .time_stamp = 0,
            // DOM §2.3 - Path initially empty
            .path = std.ArrayList(EventPathItem).init(allocator),
            // DOM §2.3 - Related target initially null
            .related_target = null,
            // DOM §2.3 - Touch target list initially empty
            .touch_target_list = std.ArrayList(*EventTarget).init(allocator),
        };
    }

    pub fn deinit(self: *Event) void {
        self.path.deinit();
        self.touch_target_list.deinit();
    }

    /// stopPropagation()
    /// Spec: https://dom.spec.whatwg.org/#dom-event-stoppropagation
    pub fn call_stopPropagation(self: *Event) void {
        self.stop_propagation_flag = true;
    }

    /// stopImmediatePropagation()
    /// Spec: https://dom.spec.whatwg.org/#dom-event-stopimmediatepropagation
    pub fn call_stopImmediatePropagation(self: *Event) void {
        self.stop_propagation_flag = true;
        self.stop_immediate_propagation_flag = true;
    }

    /// DOM §2.3 - set the canceled flag
    /// To set the canceled flag, given an event event, if event's cancelable
    /// attribute value is true and event's in passive listener flag is unset,
    /// then set event's canceled flag, and do nothing otherwise.
    fn setCanceledFlag(self: *Event) void {
        if (self.cancelable and !self.in_passive_listener_flag) {
            self.canceled_flag = true;
        }
    }

    /// preventDefault()
    /// Spec: https://dom.spec.whatwg.org/#dom-event-preventdefault
    /// The preventDefault() method steps are to set the canceled flag with this.
    pub fn call_preventDefault(self: *Event) void {
        self.setCanceledFlag();
    }

    /// composedPath()
    /// Spec: https://dom.spec.whatwg.org/#dom-event-composedpath
    pub fn call_composedPath(self: *Event) ![]EventTarget {
        _ = self;
        // Return the composed path
        return &[_]EventTarget{};
    }

    /// DOM §2.3 - initialize an event
    /// To initialize an event, with type, bubbles, and cancelable, run these steps:
    fn initializeEvent(self: *Event, event_type: []const u8, bubbles: bool, cancelable: bool) void {
        // Step 1: Set event's initialized flag
        self.initialized_flag = true;

        // Step 2: Unset event's stop propagation flag, stop immediate propagation flag, and canceled flag
        self.stop_propagation_flag = false;
        self.stop_immediate_propagation_flag = false;
        self.canceled_flag = false;

        // Step 3: Set event's isTrusted attribute to false
        self.is_trusted = false;

        // Step 4: Set event's target to null
        self.target = null;

        // Step 5: Set event's type attribute to type
        self.event_type = event_type;

        // Step 6: Set event's bubbles attribute to bubbles
        self.bubbles = bubbles;

        // Step 7: Set event's cancelable attribute to cancelable
        self.cancelable = cancelable;
    }

    /// initEvent(type, bubbles, cancelable)
    /// Spec: https://dom.spec.whatwg.org/#dom-event-initevent
    /// The initEvent(type, bubbles, cancelable) method steps are:
    /// 1. If this's dispatch flag is set, then return.
    /// 2. Initialize this with type, bubbles, and cancelable.
    pub fn call_initEvent(self: *Event, event_type: []const u8, bubbles: bool, cancelable: bool) void {
        // Step 1: If dispatch flag is set, return
        if (self.dispatch_flag) return;

        // Step 2: Initialize this
        self.initializeEvent(event_type, bubbles, cancelable);
    }

    /// Getters
    pub fn get_type(self: *const Event) []const u8 {
        return self.event_type;
    }

    pub fn get_target(self: *const Event) ?*EventTarget {
        return self.target;
    }

    /// DOM §2.3 - srcElement getter (legacy)
    /// The srcElement getter steps are to return this's target.
    pub fn get_srcElement(self: *const Event) ?*EventTarget {
        return self.target;
    }

    pub fn get_currentTarget(self: *const Event) ?*EventTarget {
        return self.current_target;
    }

    pub fn get_eventPhase(self: *const Event) u16 {
        return self.event_phase;
    }

    pub fn get_bubbles(self: *const Event) bool {
        return self.bubbles;
    }

    pub fn get_cancelable(self: *const Event) bool {
        return self.cancelable;
    }

    pub fn get_defaultPrevented(self: *const Event) bool {
        return self.canceled_flag;
    }

    pub fn get_composed(self: *const Event) bool {
        return self.composed;
    }

    pub fn get_isTrusted(self: *const Event) bool {
        return self.is_trusted;
    }

    pub fn get_timeStamp(self: *const Event) f64 {
        return self.time_stamp;
    }

    /// DOM §2.3 - cancelBubble getter (legacy)
    /// The cancelBubble getter steps are to return true if this's stop propagation
    /// flag is set; otherwise false.
    pub fn get_cancelBubble(self: *const Event) bool {
        return self.stop_propagation_flag;
    }

    /// DOM §2.3 - cancelBubble setter (legacy)
    /// The cancelBubble setter steps are to set this's stop propagation flag if
    /// the given value is true; otherwise do nothing.
    pub fn set_cancelBubble(self: *Event, value: bool) void {
        if (value) {
            self.stop_propagation_flag = true;
        }
    }

    /// DOM §2.3 - returnValue getter (legacy)
    /// The returnValue getter steps are to return false if this's canceled flag
    /// is set; otherwise true.
    pub fn get_returnValue(self: *const Event) bool {
        return !self.canceled_flag;
    }

    /// DOM §2.3 - returnValue setter (legacy)
    /// The returnValue setter steps are to set the canceled flag with this if
    /// the given value is false; otherwise do nothing.
    pub fn set_returnValue(self: *Event, value: bool) void {
        if (!value) {
            self.setCanceledFlag();
        }
    }
}, .{
    .exposed = &.{.global},
});

pub const EventInit = struct {
    bubbles: bool = false,
    cancelable: bool = false,
    composed: bool = false,
};
