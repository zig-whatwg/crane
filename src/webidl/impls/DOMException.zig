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

/// Internal state for DOMException: its name, message and legacy code.
///
/// Its lifetime is its object's (lane leak3): the block is a block of the
/// Browser's state arena, made by `initializeException` and given back by
/// `deinit` (runtime.arenaOf: `create`/`destroy`, its free lists), and the two
/// strings are the Browser allocator's (runtime.allocatorOf), freed with it.
/// They were the arena's `dupe` - its bump path, which never frees - with no
/// destroy at all, so every exception a page made, threw or cloned kept its
/// state and both strings until its Browser ended (allocator-hardening design
/// 10.1 item 1).
pub const InternalState = struct {
    /// Owned by the instance's Browser allocator; "" is not allocated.
    message: []const u8,
    /// Owned by the instance's Browser allocator.
    name: []const u8,
    code: u16,

    /// Free the strings and give the block back: `instance` is the
    /// exception whose state this is.
    fn destroy(self: *InternalState, instance: *runtime.Instance) void {
        const allocator = runtime.allocatorOf(instance);
        if (self.message.len > 0) allocator.free(self.message);
        allocator.free(self.name);
        runtime.arenaOf(instance).destroy(InternalState, self);
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

/// Deinitialize instance: its internal state goes with it (a derived
/// exception's chain reaches here through DOMException's deinitChain).
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        internal.destroy(instance);
    }
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
///
/// Per WebIDL spec:
/// - message: Optional message string, defaults to ""
/// - name: Optional name string, defaults to "Error"
pub fn call_constructor(instance: *runtime.Instance, message: webidl.Opt(runtime.DOMString), name: webidl.Opt(runtime.DOMString)) !void {
    // WebIDL §2.8.1 constructor steps 1-2, shared with derived exceptions.
    try initializeException(instance, if (name.was_passed) name.value.asSlice() else "Error", if (message.was_passed) message.value.asSlice() else "");
}

pub fn installHooks() void {
    @import("dom").dom_exceptions.install(.{ .initialize = initializeException });
}

/// Set `instance`'s name and message (and so its legacy code): the
/// constructor's steps 1-2, the deserialization steps' 1-2, and every
/// exception the platform makes (dom.dom_exceptions). The state is the
/// instance's own, freed by `deinit` (`InternalState`).
fn initializeException(instance: *runtime.Instance, name_str: []const u8, msg_str: []const u8) !void {
    const state = instance.getState(State);
    const allocator = runtime.allocatorOf(instance);
    const arena = runtime.arenaOf(instance);

    const internal = try arena.create(InternalState);
    errdefer arena.destroy(InternalState, internal);
    const owned_message: []const u8 = if (msg_str.len > 0) try allocator.dupe(u8, msg_str) else "";
    errdefer if (owned_message.len > 0) allocator.free(owned_message);
    const owned_name = try allocator.dupe(u8, name_str);

    internal.* = .{
        .message = owned_message,
        .name = owned_name,
        // The legacy code is the name's (WebIDL 2.8.1, the error names table).
        .code = getLegacyCodeForName(name_str),
    };

    // Set once per exception; a second setting replaces the first, freed.
    if (state.own._internal) |previous| previous.destroy(instance);
    state.own._internal = internal;
}

// ============================================================================
// Serializable objects (HTML 2.7.1; WebIDL 4.4: DOMException is [Serializable])
// ============================================================================

/// WebIDL 4.4, DOMException's serialization steps, given `value` and
/// `serialized`:
///
/// 1. Set serialized.[[Name]] to value's name.
/// 2. Set serialized.[[Message]] to value's message.
/// 3. Set serialized.[[Stack]] to an implementation-defined string derived
///    from value.[[Stack]].
/// 4. (Optional accompanying data, such as line and column: none kept.)
///
/// Crane keeps no [[Stack]] on a DOMException yet, so step 3 writes the
/// empty string - Blink writes a null string for the same reason, keeping
/// the slot so the record's layout need not change when one is kept.
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    const internal = value.getState(State).own._internal;
    // Step 1: a DOMException made without its constructor's steps has the
    // default name, as `name` answers it.
    try serialized.writeString(if (internal) |i| i.name else "Error");
    // Step 2.
    try serialized.writeString(if (internal) |i| i.message else "");
    // Step 3.
    try serialized.writeString("");
}

/// WebIDL 4.4, DOMException's deserialization steps, given `value` and
/// `serialized`:
///
/// 1. Set value's name to serialized.[[Name]].
/// 2. Set value's message to serialized.[[Message]].
/// 3. Set value.[[Stack]] to serialized.[[Stack]] (none kept: see above).
/// 4. (No other data is attached.)
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    _ = target_realm;
    const name = try serialized.readString();
    const message = try serialized.readString();
    _ = try serialized.readString();
    // Steps 1-2 (and the legacy code, which name determines).
    try initializeException(value, name, message);
}

/// Getter for name
/// Returns the error name (e.g., "NotSupportedError", "InvalidStateError")
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, "Error");
    };
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
