//! Implementation for DOMException interface
//!
//! WHATWG DOM Standard § 4.3
//! https://webidl.spec.whatwg.org/#idl-DOMException
//!
//! DOMException represents an abnormal event that occurred during a DOM operation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DOMException = interfaces.DOMException;

pub const State = DOMException.State;

pub const ImplError = error{
    OutOfMemory,
};

/// Internal state for DOMException
/// Stores the message, name, and legacy error code
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    message: []const u8,
    name: []const u8,
    code: u16,
    /// Whether we own the message/name memory (allocated by us)
    owns_message: bool,
    owns_name: bool,

    pub fn deinit(self: *InternalState) void {
        if (self.owns_message and self.message.len > 0) {
            self.allocator.free(self.message);
        }
        if (self.owns_name and self.name.len > 0) {
            self.allocator.free(self.name);
        }
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
    }
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
///
/// Per WebIDL spec:
/// - message: Optional message string, defaults to ""
/// - name: Optional name string, defaults to "Error"
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: webidl.Opt(runtime.DOMString), name: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &DOMException.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // Get message (default to empty string)
    const msg_str = if (message.was_passed) message.value.asSlice() else "";
    // Get name (default to "Error")
    const name_str = if (name.was_passed) name.value.asSlice() else "Error";

    // Duplicate strings so we own them
    const owned_message = if (msg_str.len > 0) try allocator.dupe(u8, msg_str) else "";
    errdefer if (owned_message.len > 0) allocator.free(owned_message);

    const owned_name = try allocator.dupe(u8, name_str);

    // Get legacy error code from name
    const code = getLegacyCodeForName(name_str);

    internal.* = .{
        .allocator = allocator,
        .message = owned_message,
        .name = owned_name,
        .code = code,
        .owns_message = owned_message.len > 0,
        .owns_name = true,
    };

    state.own._internal = internal;

    return instance;
}

/// Getter for name
/// Returns the error name (e.g., "NotSupportedError", "InvalidStateError")
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return try runtime.DOMString.initDupe(instance.ctx.allocator, "Error");
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
}

/// Getter for message
/// Returns the error message
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_message(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return runtime.DOMString.empty;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.message);
}

/// Getter for code
/// Returns the legacy error code (0 for newer error names)
pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return 0;
    return internal.code;
}

/// Get legacy error code for a DOMException name
/// Per WebIDL spec: https://webidl.spec.whatwg.org/#idl-DOMException-error-names
fn getLegacyCodeForName(name: []const u8) u16 {
    const legacy_codes = std.StaticStringMap(u16).initComptime(.{
        .{ "IndexSizeError", 1 },
        .{ "HierarchyRequestError", 3 },
        .{ "WrongDocumentError", 4 },
        .{ "InvalidCharacterError", 5 },
        .{ "NoModificationAllowedError", 7 },
        .{ "NotFoundError", 8 },
        .{ "NotSupportedError", 9 },
        .{ "InUseAttributeError", 10 },
        .{ "InvalidStateError", 11 },
        .{ "SyntaxError", 12 },
        .{ "InvalidModificationError", 13 },
        .{ "NamespaceError", 14 },
        .{ "InvalidAccessError", 15 },
        .{ "TypeMismatchError", 17 },
        .{ "SecurityError", 18 },
        .{ "NetworkError", 19 },
        .{ "AbortError", 20 },
        .{ "URLMismatchError", 21 },
        .{ "QuotaExceededError", 22 },
        .{ "TimeoutError", 23 },
        .{ "InvalidNodeTypeError", 24 },
        .{ "DataCloneError", 25 },
    });
    return legacy_codes.get(name) orelse 0;
}
