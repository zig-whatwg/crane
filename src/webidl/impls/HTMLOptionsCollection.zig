//! Implementation for HTMLOptionsCollection interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLOptionsCollection = interfaces.HTMLOptionsCollection;
const forms = @import("html").forms;
const collections = @import("dom").live_collections;

pub const State = HTMLOptionsCollection.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    if (collections.rootOf(instance) == null) return 0;
    return interfaces.HTMLCollection.get_length(instance);
}

/// Getter for selectedIndex
pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
    const select = collections.rootOf(instance) orelse return -1;
    return interfaces.HTMLSelectElement.get_selectedIndex(select);
}

/// Setter for length
pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
    const select = collections.rootOf(instance) orelse return;
    // HTML 2.6.4.3 length setter, steps 1–3. The select exposes these same
    // steps through its length IDL member.
    try forms.options.setLength(select, value);
}

/// Setter for selectedIndex
pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    const select = collections.rootOf(instance) orelse return;
    try interfaces.HTMLSelectElement.set_selectedIndex(select, value);
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, element: typedefs.HTMLOptionElementOrHTMLOptGroupElement, before: webidl.Opt(?runtime.JSValue)) anyerror!void {
    const select = collections.rootOf(instance) orelse return;
    const option = switch (element) {
        inline else => |object| object,
    };
    try forms.options.add(select, option, before);
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance, index: i32) anyerror!void {
    const select = collections.rootOf(instance) orelse return;
    try forms.options.remove(select, index);
}

/// HTML 2.6.4.3 indexed setter, steps 1–5: the select's identical operation.
pub fn call_setter(instance: *runtime.Instance, index: u32, option: ?*runtime.Instance) anyerror!void {
    const select = collections.rootOf(instance) orelse return;
    try forms.options.setIndex(select, index, option);
}
