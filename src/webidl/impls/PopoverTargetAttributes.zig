//! Implementation for the PopoverTargetAttributes mixin (HTML §6.12):
//! popoverTargetElement and popoverTargetAction, shared by HTMLButtonElement
//! and HTMLInputElement.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const PopoverTargetAttributes = interfaces.PopoverTargetAttributes;

pub const State = PopoverTargetAttributes.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for popoverTargetElement.
pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Setter for popoverTargetElement.
pub fn set_popoverTargetElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Getter for popoverTargetAction (HTML §6.12): enumerated attribute limited
/// to "toggle" (missing/invalid default), "show", and "hide".
pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!runtime.DOMString {
    var attr = (try interfaces.Element.call_getAttribute(instance, runtime.DOMString.initInterned("popovertargetaction"))) orelse
        return runtime.DOMString.initInterned("toggle");
    defer attr.deinit(instance.ctx.allocator);
    const value = attr.asSlice();
    inline for (.{ "toggle", "show", "hide" }) |keyword| {
        if (std.ascii.eqlIgnoreCase(value, keyword)) return runtime.DOMString.initInterned(keyword);
    }
    return runtime.DOMString.initInterned("toggle");
}

/// Setter for popoverTargetAction (HTML §6.12).
pub fn set_popoverTargetAction(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("popovertargetaction"), .{ .domstring = value });
}
