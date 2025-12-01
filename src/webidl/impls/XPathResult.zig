//! Implementation for XPathResult interface
//!
//! XPath 1.0 result object - holds the result of evaluating an XPath expression.
//! Per DOM Level 3 XPath: https://www.w3.org/TR/DOM-Level-3-XPath/
//!
//! NOTE: This is a stub implementation. The XPath core is implemented in
//! src/dom/xpath/ but needs module wiring to be connected to this WebIDL interface.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XPathResult = interfaces.XPathResult;

pub const State = XPathResult.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    NotSupported,
};

/// Result type constants (matching WebIDL constants)
pub const ResultType = struct {
    pub const ANY_TYPE: u16 = 0;
    pub const NUMBER_TYPE: u16 = 1;
    pub const STRING_TYPE: u16 = 2;
    pub const BOOLEAN_TYPE: u16 = 3;
    pub const UNORDERED_NODE_ITERATOR_TYPE: u16 = 4;
    pub const ORDERED_NODE_ITERATOR_TYPE: u16 = 5;
    pub const UNORDERED_NODE_SNAPSHOT_TYPE: u16 = 6;
    pub const ORDERED_NODE_SNAPSHOT_TYPE: u16 = 7;
    pub const ANY_UNORDERED_NODE_TYPE: u16 = 8;
    pub const FIRST_ORDERED_NODE_TYPE: u16 = 9;
};

/// Internal state for XPathResult
pub const InternalState = struct {
    /// The result type
    result_type: u16,
    /// Number value (for NUMBER_TYPE)
    number_value: f64,
    /// String value (for STRING_TYPE)
    string_value: []const u8,
    /// Boolean value (for BOOLEAN_TYPE)
    boolean_value: bool,
    /// Snapshot length (for snapshot types)
    snapshot_length: u32,
    /// Iterator position (for iterator types)
    iterator_position: usize,
    /// Whether the iterator is invalid (document modified)
    invalid_iterator_state: bool,
    /// Allocator used for this result
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
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

/// Getter for resultType
pub fn get_resultType(instance: *runtime.Instance) ImplError!u16 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.result_type;
}

/// Getter for numberValue
pub fn get_numberValue(instance: *runtime.Instance) ImplError!f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    if (internal.result_type != ResultType.NUMBER_TYPE) {
        return error.TypeError;
    }
    return internal.number_value;
}

/// Getter for stringValue
pub fn get_stringValue(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    if (internal.result_type != ResultType.STRING_TYPE) {
        return error.TypeError;
    }
    return runtime.DOMString.initInterned(internal.string_value);
}

/// Getter for booleanValue
pub fn get_booleanValue(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    if (internal.result_type != ResultType.BOOLEAN_TYPE) {
        return error.TypeError;
    }
    return internal.boolean_value;
}

/// Getter for singleNodeValue
pub fn get_singleNodeValue(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Valid for ANY_UNORDERED_NODE_TYPE and FIRST_ORDERED_NODE_TYPE
    if (internal.result_type != ResultType.ANY_UNORDERED_NODE_TYPE and
        internal.result_type != ResultType.FIRST_ORDERED_NODE_TYPE)
    {
        return error.TypeError;
    }

    // TODO: Return actual node when XPath core is wired up
    return null;
}

/// Getter for invalidIteratorState
pub fn get_invalidIteratorState(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.invalid_iterator_state;
}

/// Getter for snapshotLength
pub fn get_snapshotLength(instance: *runtime.Instance) ImplError!u32 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Valid for snapshot types
    if (internal.result_type != ResultType.UNORDERED_NODE_SNAPSHOT_TYPE and
        internal.result_type != ResultType.ORDERED_NODE_SNAPSHOT_TYPE)
    {
        return error.TypeError;
    }

    return internal.snapshot_length;
}

/// Operation: snapshotItem
pub fn call_snapshotItem(instance: *runtime.Instance, index: u32) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = index;

    // Valid for snapshot types only
    if (internal.result_type != ResultType.UNORDERED_NODE_SNAPSHOT_TYPE and
        internal.result_type != ResultType.ORDERED_NODE_SNAPSHOT_TYPE)
    {
        return error.TypeError;
    }

    // TODO: Return actual node when XPath core is wired up
    return null;
}

/// Operation: iterateNext
pub fn call_iterateNext(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Valid for iterator types only
    if (internal.result_type != ResultType.UNORDERED_NODE_ITERATOR_TYPE and
        internal.result_type != ResultType.ORDERED_NODE_ITERATOR_TYPE)
    {
        return error.TypeError;
    }

    // Check for invalid state
    if (internal.invalid_iterator_state) {
        return error.InvalidState;
    }

    // TODO: Return actual node when XPath core is wired up
    return null;
}
