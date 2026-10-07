//! Implementation for RadioNodeList interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const RadioNodeList = interfaces.RadioNodeList;

pub const State = RadioNodeList.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return interfaces.NodeList.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.NodeList.deinit(instance);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // HTML 2.6.4.2 getter steps 1–4.
    const length = try interfaces.NodeList.get_length(instance);
    var index: u32 = 0;
    while (index < length) : (index += 1) {
        const element = (try interfaces.NodeList.call_item(instance, index)) orelse continue;
        if (!isRadio(element) or !(try interfaces.HTMLInputElement.get_checked(element))) continue;
        if (!@import("html").form_associated.hasAttribute(element, "value")) return runtime.DOMString.initInterned("on");
        return (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("value"))) orelse runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initEmpty();
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Setter steps 1–2: only the first matching radio becomes checked.
    const length = try interfaces.NodeList.get_length(instance);
    var index: u32 = 0;
    while (index < length) : (index += 1) {
        const element = (try interfaces.NodeList.call_item(instance, index)) orelse continue;
        if (!isRadio(element)) continue;
        var attribute = if (@import("html").form_associated.hasAttribute(element, "value"))
            (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("value"))) orelse runtime.DOMString.initEmpty()
        else
            runtime.DOMString.initInterned("on");
        defer attribute.deinit(instance.ctx.allocator);
        if (!std.mem.eql(u8, attribute.asSlice(), value.asSlice())) continue;
        try interfaces.HTMLInputElement.set_checked(element, true);
        return;
    }
}

fn isRadio(element: *runtime.Instance) bool {
    const forms = @import("html").form_associated;
    if (!forms.isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    return std.mem.eql(u8, forms.inputType(element, &buffer), "radio");
}
