//! Implementation for HTMLFormControlsCollection interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLFormControlsCollection = interfaces.HTMLFormControlsCollection;

pub const State = HTMLFormControlsCollection.State;

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
    return interfaces.HTMLCollection.initWithState(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.HTMLCollection.deinit(instance);
}

/// Operation: namedItem
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.JSValue {
    // HTML 2.6.4.2 steps 1–5: duplicates are a live filtered RadioNodeList.
    if (name.asSlice().len == 0) return null;
    const length = try interfaces.HTMLCollection.get_length(instance);
    var first: ?*runtime.Instance = null;
    var index: u32 = 0;
    while (index < length) : (index += 1) {
        const element = (try interfaces.HTMLCollection.call_item(instance, index)) orelse continue;
        if (!@import("html").form_associated.hasControlName(element, name.asSlice())) continue;
        if (first == null) {
            first = element;
            continue;
        }
        const list = try interfaces.RadioNodeList.init(instance.ctx.allocator, instance.ctx);
        errdefer runtime.Instance.deinit(list);
        try @import("dom").node_lists.namedControls(list, instance, name.asSlice());
        return .{ .instance = list };
    }
    return if (first) |element| .{ .instance = element } else null;
}

/// Get supported property names for named property enumeration
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    return interfaces.HTMLCollection.getSupportedPropertyNames(instance, allocator);
}
