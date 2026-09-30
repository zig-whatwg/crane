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
const engine = @import("engine");
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
    /// Parameters set via setParameter, by `parameterKey` - the processor's
    /// own copy of the namespace and local name - each value held by the
    /// processor (engine.retainValue) until it is replaced, removed or
    /// cleared, or the processor goes. The arguments are the binding's,
    /// borrowed for the call: stored as they came, the names were freed bytes
    /// once setParameter returned and the value was the argument's handle.
    parameters: std.StringHashMapUnmanaged(engine.Owned) = .empty,
    /// Allocator for this instance
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .stylesheet = null,
            .allocator = allocator,
        };
    }

    /// Release every parameter: its key and its value.
    fn clearParameters(self: *InternalState) void {
        var it = self.parameters.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.release();
        }
        self.parameters.clearAndFree(self.allocator);
    }

    pub fn deinit(self: *InternalState) void {
        self.clearParameters();
        self.allocator.destroy(self);
    }
};

/// A parameter's key: its namespace and local name, NUL-separated (neither
/// can be told apart otherwise: a null namespace is the empty string, as
/// XSLT's QName resolution treats it). OWNED by `allocator`.
fn parameterKey(allocator: std.mem.Allocator, namespace_uri: runtime.DOMString, local_name: runtime.DOMString) ![]u8 {
    return std.mem.concat(allocator, u8, &.{ namespace_uri.asSlice(), "\x00", local_name.asSlice() });
}

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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    return init(ctx.allocator, State, &XSLTProcessor.vtable, ctx);
}

/// Operation: importStylesheet
/// Imports an XSLT stylesheet from a Document or Element node
pub fn call_importStylesheet(instance: *runtime.Instance, style: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Store the stylesheet reference
    internal.stylesheet = style;
}

/// Operation: transformToDocument
/// Transforms the source document and returns a new Document
///
/// TODO: Implement actual XSLT transformation
pub fn call_transformToDocument(instance: *runtime.Instance, source: *runtime.Instance) anyerror!*runtime.Instance {
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
pub fn call_transformToFragment(instance: *runtime.Instance, source: *runtime.Instance, output: *runtime.Instance) anyerror!*runtime.Instance {
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
/// Sets a parameter for the XSLT transformation: the processor keeps the
/// value under (namespaceURI, localName), replacing any value there.
pub fn call_setParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString, value: runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // The value is the binding's, borrowed for this call: the processor
    // keeps a hold of its own.
    const held = try engine.retainValue(instance.ctx, value);
    errdefer held.release();
    const key = try parameterKey(internal.allocator, namespaceURI, localName);
    errdefer internal.allocator.free(key);

    if (internal.parameters.fetchRemove(key)) |old| {
        internal.allocator.free(old.key);
        old.value.release();
    }
    try internal.parameters.put(internal.allocator, key, held);
}

/// Operation: getParameter
/// Gets a parameter value, or undefined when none is set.
pub fn call_getParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const key = try parameterKey(internal.allocator, namespaceURI, localName);
    defer internal.allocator.free(key);
    if (internal.parameters.get(key)) |held| {
        // The processor keeps its hold; the result is a hold of the
        // binding's own.
        return (try engine.retainValue(instance.ctx, held.value)).take();
    }

    // Return undefined if parameter not found
    return runtime.JSValue.jsUndefined;
}

/// Operation: removeParameter
/// Removes a parameter
pub fn call_removeParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const key = try parameterKey(internal.allocator, namespaceURI, localName);
    defer internal.allocator.free(key);
    if (internal.parameters.fetchRemove(key)) |old| {
        internal.allocator.free(old.key);
        old.value.release();
    }
}

/// Operation: clearParameters
/// Clears all parameters
pub fn call_clearParameters(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.clearParameters();
}

/// Operation: reset
/// Resets the processor to initial state
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.stylesheet = null;
    internal.clearParameters();
}
