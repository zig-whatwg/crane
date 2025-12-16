//! Implementation for HTMLFormElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLFormElement = interfaces.HTMLFormElement;

// Import related impls for attribute access
const ElementImpl = @import("Element.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");

pub const State = HTMLFormElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Internal state for HTMLFormElement implementation
pub const InternalState = struct {
    /// Cached relList DOMTokenList instance
    rel_list: ?*runtime.Instance = null,

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);

    // Initialize HTMLFormElement's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = .{};
    try Registry.set(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);

    // Chain to parent class (via interface per Golden Rule #13)
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLFormElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for acceptCharset
pub fn get_acceptCharset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for action
pub fn get_action(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for enctype
pub fn get_enctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for encoding
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for method
pub fn get_method(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-name
/// Reflects the name attribute.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Use Element's attribute access
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Look for the "name" attribute
    if (elem_internal.findAttribute(null, "name")) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for noValidate
pub fn get_noValidate(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for target
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rel
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-rel
/// Reflects the rel attribute.
pub fn get_rel(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Use Element's attribute access
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Look for the "rel" attribute
    if (elem_internal.findAttribute(null, "rel")) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for relList
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-rellist
/// Returns a DOMTokenList reflecting the rel attribute.
pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Return cached DOMTokenList if it exists
    if (internal.rel_list) |existing| {
        return existing;
    }

    // Create a new DOMTokenList
    const token_list = interfaces.DOMTokenList.init(elem_internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Initialize with current rel attribute value
    if (elem_internal.findAttribute(null, "rel")) |entry| {
        interfaces.DOMTokenList.set_value(token_list, runtime.DOMString.initInterned(entry.value)) catch return error.OutOfMemory;
    }

    // Associate with this element and the "rel" attribute
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("rel"));

    // Cache for future access
    internal.rel_list = token_list;

    return token_list;
}

/// Getter for elements
pub fn get_elements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for acceptCharset
pub fn set_acceptCharset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for action
pub fn set_action(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for autocomplete
pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for enctype
pub fn set_enctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for encoding
pub fn set_encoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for method
pub fn set_method(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for name
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-name
/// Sets the name attribute.
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("name"), value);
}

/// Setter for noValidate
pub fn set_noValidate(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for target
pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for rel
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-rel
/// Sets the rel attribute.
pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("rel"), value);
}

/// Operation: requestSubmit
pub fn call_requestSubmit(instance: *runtime.Instance, submitter: webidl.Opt(?*runtime.Instance)) anyerror!void {
    _ = instance;
    _ = submitter;
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: submit
pub fn call_submit(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}
