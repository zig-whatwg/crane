//! Implementation for DOMTokenList interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist
//! WHATWG DOM Standard §7.1
//!
//! A DOMTokenList represents a set of space-separated tokens. It's used for
//! Element.classList to manage CSS classes.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const DOMTokenList = interfaces.DOMTokenList;

pub const State = DOMTokenList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    SyntaxError,
    InvalidCharacterError,
};

/// Internal state for DOMTokenList implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of tokens
    tokens: infra.List(runtime.DOMString),

    /// Associated element (for attribute updates)
    element: ?*runtime.Instance = null,

    /// Associated attribute name (e.g., "class")
    attr_name: ?runtime.DOMString = null,

    /// Supported tokens (for supports() method)
    supported_tokens: ?[]const []const u8 = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .tokens = infra.List(runtime.DOMString).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Free owned DOMStrings
        const slice = self.tokens.toSliceMut();
        for (slice) |*token| {
            token.deinit(self.allocator);
        }
        self.tokens.deinit();
        if (self.attr_name) |*attr| {
            attr.deinit(self.allocator);
        }
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
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

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Initialize length to 0
    state.own.length = 0;
    state.own.value = runtime.DOMString.initEmpty();

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.tokens.size());
}

/// Getter for value
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-value
/// Returns the serialized value (space-separated tokens)
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();

    // Serialize tokens to space-separated string
    const tokens = internal.tokens.toSlice();
    if (tokens.len == 0) {
        return runtime.DOMString.initEmpty();
    }

    // Calculate total length
    var total_len: usize = 0;
    for (tokens, 0..) |token, i| {
        total_len += token.len();
        if (i < tokens.len - 1) total_len += 1; // space
    }

    // Build the string
    const buf = try internal.allocator.alloc(u8, total_len);
    var pos: usize = 0;
    for (tokens, 0..) |token, i| {
        const slice = token.asSlice();
        @memcpy(buf[pos..][0..slice.len], slice);
        pos += slice.len;
        if (i < tokens.len - 1) {
            buf[pos] = ' ';
            pos += 1;
        }
    }

    return runtime.DOMString.initOwned(buf);
}

/// Setter for value
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-value
/// Parses the value and replaces all tokens
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;

    // Clear existing tokens
    const slice = internal.tokens.toSliceMut();
    for (slice) |*token| {
        token.deinit(internal.allocator);
    }
    internal.tokens.clear();

    // Parse new tokens (split by whitespace)
    const val_slice = value.asSlice();
    var iter = std.mem.tokenizeAny(u8, val_slice, " \t\n\r\x0c");
    while (iter.next()) |token| {
        const owned = try runtime.DOMString.initDupe(internal.allocator, token);
        try internal.tokens.append(owned);
    }

    // Update length
    const state = instance.getState(State);
    state.own.length = @intCast(internal.tokens.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-item
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const token = internal.tokens.get(index) orelse return runtime.DOMString.initEmpty();
    return token;
}

/// Operation: contains(token)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-contains
pub fn call_contains(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const token_slice = token.asSlice();

    const tokens = internal.tokens.toSlice();
    for (tokens) |t| {
        if (std.mem.eql(u8, t.asSlice(), token_slice)) {
            return true;
        }
    }
    return false;
}

/// Operation: add(tokens...)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-add
pub fn call_add(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const token_slice = tokens.asSlice();

    // Validate token
    if (token_slice.len == 0) return error.SyntaxError;
    if (std.mem.indexOfAny(u8, token_slice, " \t\n\r\x0c")) |_| {
        return error.InvalidCharacterError;
    }

    // Check if already present
    const existing = internal.tokens.toSlice();
    for (existing) |t| {
        if (std.mem.eql(u8, t.asSlice(), token_slice)) {
            return; // Already exists
        }
    }

    // Add the token
    const owned = try runtime.DOMString.initDupe(internal.allocator, token_slice);
    try internal.tokens.append(owned);

    // Update length
    const state = instance.getState(State);
    state.own.length = @intCast(internal.tokens.size());
}

/// Operation: remove(tokens...)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-remove
pub fn call_remove(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const token_slice = tokens.asSlice();

    // Validate token
    if (token_slice.len == 0) return error.SyntaxError;
    if (std.mem.indexOfAny(u8, token_slice, " \t\n\r\x0c")) |_| {
        return error.InvalidCharacterError;
    }

    // Find and remove
    const slice = internal.tokens.toSliceMut();
    var i: usize = 0;
    while (i < internal.tokens.len) {
        if (std.mem.eql(u8, slice[i].asSlice(), token_slice)) {
            var token = internal.tokens.remove(i) catch continue;
            token.deinit(internal.allocator);
        } else {
            i += 1;
        }
    }

    // Update length
    const state = instance.getState(State);
    state.own.length = @intCast(internal.tokens.size());
}

/// Operation: toggle(token, force?)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-toggle
pub fn call_toggle(instance: *runtime.Instance, token: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
    const contains = try call_contains(instance, token);

    if (contains) {
        if (!force) {
            try call_remove(instance, token);
            return false;
        }
        return true;
    } else {
        if (force) {
            try call_add(instance, token);
            return true;
        }
        return false;
    }
}

/// Operation: replace(token, newToken)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-replace
pub fn call_replace(instance: *runtime.Instance, token: runtime.DOMString, newToken: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    const token_slice = token.asSlice();
    const new_slice = newToken.asSlice();

    // Validate tokens
    if (token_slice.len == 0 or new_slice.len == 0) return error.SyntaxError;
    if (std.mem.indexOfAny(u8, token_slice, " \t\n\r\x0c")) |_| {
        return error.InvalidCharacterError;
    }
    if (std.mem.indexOfAny(u8, new_slice, " \t\n\r\x0c")) |_| {
        return error.InvalidCharacterError;
    }

    // Find and replace
    const slice = internal.tokens.toSliceMut();
    for (slice) |*t| {
        if (std.mem.eql(u8, t.asSlice(), token_slice)) {
            t.deinit(internal.allocator);
            t.* = try runtime.DOMString.initDupe(internal.allocator, new_slice);
            return true;
        }
    }

    return false;
}

/// Operation: supports(token)
/// Spec: https://dom.spec.whatwg.org/#dom-domtokenlist-supports
pub fn call_supports(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return false;

    // Check if supported tokens are defined
    if (internal.supported_tokens) |supported| {
        const token_slice = token.asSlice();
        for (supported) |s| {
            if (std.ascii.eqlIgnoreCase(s, token_slice)) {
                return true;
            }
        }
        return false;
    }

    // No supported tokens defined - throw TypeError
    return error.NotImplemented;
}

/// Operation: forEach(callback)
/// Spec: https://webidl.spec.whatwg.org/#es-forEach
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
    const internal = getInternal(instance) orelse return;
    _ = callback;

    // forEach requires JS callback invocation
    const tokens = internal.tokens.toSlice();
    for (tokens) |_| {
        // TODO: Invoke callback(token, index, this) via V8
    }
}

// ============================================================================
// Internal helper functions
// ============================================================================

/// Set supported tokens for supports() method
pub fn setSupportedTokens(instance: *runtime.Instance, tokens: []const []const u8) void {
    const internal = getInternal(instance) orelse return;
    internal.supported_tokens = tokens;
}

/// Set the associated element and attribute
pub fn setElement(instance: *runtime.Instance, element: ?*runtime.Instance, attr_name: ?runtime.DOMString) void {
    const internal = getInternal(instance) orelse return;
    internal.element = element;
    internal.attr_name = attr_name;
}
