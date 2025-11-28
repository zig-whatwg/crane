//! Implementation for XSLTProcessor interface
//!
//! XSLT 1.0 processor - transforms XML documents using XSLT stylesheets.
//! Per W3C XSLT 1.0: https://www.w3.org/TR/xslt-10/
//!
//! NOTE: XSLT is a complex specification that requires:
//! - Full XPath 1.0 implementation (done in src/dom/xpath/)
//! - XSLT template matching and processing
//! - Output methods (xml, html, text)
//! - Variable and parameter handling
//! - Namespace processing
//!
//! This is a stub implementation. Full XSLT would be a significant undertaking.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XSLTProcessor = interfaces.XSLTProcessor;

pub const State = XSLTProcessor.State;

pub const ImplError = error{
    NotSupported,
    InvalidState,
    TypeError,
    OutOfMemory,
};

/// Internal state for XSLTProcessor
pub const InternalState = struct {
    /// The imported stylesheet (as a Node)
    stylesheet: ?*runtime.Instance,
    /// Parameters set via setParameter
    parameters: std.StringHashMap(Parameter),
    /// Allocator for this instance
    allocator: std.mem.Allocator,

    const Parameter = struct {
        namespace_uri: ?[]const u8,
        local_name: []const u8,
        value: *const anyopaque,
    };

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .stylesheet = null,
            .parameters = std.StringHashMap(Parameter).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.parameters.deinit();
        self.allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    return init(allocator, State, &XSLTProcessor.vtable, ctx);
}

/// Operation: importStylesheet
/// Imports an XSLT stylesheet from a Document or Element node
pub fn call_importStylesheet(instance: *runtime.Instance, style: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Store the stylesheet reference
    internal.stylesheet = style;
}

/// Operation: transformToDocument
/// Transforms the source document and returns a new Document
///
/// TODO: Implement actual XSLT transformation
pub fn call_transformToDocument(instance: *runtime.Instance, source: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.stylesheet == null) {
        return error.InvalidState;
    }

    _ = source;

    // TODO: Implement XSLT transformation
    // This requires:
    // 1. Parse stylesheet to build template rules
    // 2. Create output document
    // 3. Apply templates starting from root
    // 4. Return transformed document
    return error.NotSupported;
}

/// Operation: transformToFragment
/// Transforms the source and returns a DocumentFragment
///
/// TODO: Implement actual XSLT transformation
pub fn call_transformToFragment(instance: *runtime.Instance, source: *runtime.Instance, output: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.stylesheet == null) {
        return error.InvalidState;
    }

    _ = source;
    _ = output;

    // TODO: Implement XSLT transformation to fragment
    return error.NotSupported;
}

/// Operation: setParameter
/// Sets a parameter for the XSLT transformation
pub fn call_setParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString, value: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const ns_str = namespaceURI.asSlice();
    const local_str = localName.asSlice();

    // Create parameter key (namespace + local name)
    const key = local_str;

    try internal.parameters.put(key, .{
        .namespace_uri = if (ns_str.len > 0) ns_str else null,
        .local_name = local_str,
        .value = value,
    });
}

/// Operation: getParameter
/// Gets a parameter value
pub fn call_getParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    _ = namespaceURI;
    const local_str = localName.asSlice();

    if (internal.parameters.get(local_str)) |param| {
        return param.value;
    }

    return error.InvalidState;
}

/// Operation: removeParameter
/// Removes a parameter
pub fn call_removeParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    _ = namespaceURI;
    const local_str = localName.asSlice();

    _ = internal.parameters.remove(local_str);
}

/// Operation: clearParameters
/// Clears all parameters
pub fn call_clearParameters(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.parameters.clearAndFree();
}

/// Operation: reset
/// Resets the processor to initial state
pub fn call_reset(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.stylesheet = null;
    internal.parameters.clearAndFree();
}
