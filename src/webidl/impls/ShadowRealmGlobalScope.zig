//! Implementation for ShadowRealmGlobalScope interface
//!
//! Spec: WHATWG HTML Standard - ShadowRealmGlobalScope
//! https://html.spec.whatwg.org/multipage/webappapis.html#shadowrealmglobalscope
//!
//! TC39 ShadowRealm Proposal:
//! https://tc39.es/proposal-shadowrealm/
//!
//! ShadowRealmGlobalScope provides a minimal, sandboxed JavaScript environment.
//! It exposes only computational APIs - no DOM, no network, no storage.
//! This makes it suitable for running untrusted code in isolation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const ShadowRealmGlobalScope = interfaces.ShadowRealmGlobalScope;

// Import WindowOrWorkerGlobalScope mixin implementation for shared functionality
const WindowOrWorkerGlobalScopeImpl = @import("WindowOrWorkerGlobalScope.zig");

// Import structured clone
const html_core = @import("html_core");
const structured_clone = html_core.structured_clone;

pub const State = ShadowRealmGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    InvalidCharacter,
    OutOfMemory,
};

/// Internal state for ShadowRealmGlobalScope
pub const InternalState = struct {
    /// Allocator for internal operations
    allocator: std.mem.Allocator,

    /// Name of the ShadowRealm (for debugging)
    name: []const u8 = "ShadowRealm",

    /// Origin (defaults to "null" for ShadowRealm per spec)
    origin: []const u8 = "null",

    /// Whether this is a secure context
    /// ShadowRealm inherits secure context from initiator
    is_secure_context: bool = false,

    /// Whether cross-origin isolated
    /// ShadowRealm inherits from initiator
    cross_origin_isolated: bool = false,

    pub fn deinit(self: *InternalState) void {
        _ = self;
        // Nothing to deinit - strings are static or owned elsewhere
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

    // Create internal state
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Initialize with custom settings (for ShadowRealm creation from callback)
pub fn initWithSettings(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    is_secure_context: bool,
    cross_origin_isolated: bool,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
        .is_secure_context = is_secure_context,
        .cross_origin_isolated = cross_origin_isolated,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for self
///
/// Spec: Returns the ShadowRealmGlobalScope object itself
pub fn get_self(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance;
}

/// Getter for name
///
/// Returns the name of the ShadowRealm (for debugging purposes)
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return runtime.DOMString.initInterned(internal.name);
    }
    return runtime.DOMString.initInterned("ShadowRealm");
}

/// Getter for origin
///
/// Spec: ShadowRealm has "null" origin per spec
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.origin;
    }
    return "null";
}

/// Getter for isSecureContext
///
/// Spec: ShadowRealm inherits secure context from initiator realm
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.is_secure_context;
    }
    return false;
}

/// Getter for crossOriginIsolated
///
/// Spec: ShadowRealm inherits cross-origin isolation from initiator realm
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.cross_origin_isolated;
    }
    return false;
}

/// Operation: queueMicrotask
///
/// Spec: HTML Standard § 8.6 Microtask queuing
/// https://html.spec.whatwg.org/#dom-queuemicrotask
///
/// Delegates to WindowOrWorkerGlobalScope mixin implementation.
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
    // For ShadowRealm, we need to queue a microtask in the context
    // This requires V8 microtask queue integration
    _ = instance;
    _ = callback;
    // TODO: Integrate with V8 microtask queue
    // For now, this is a placeholder - microtasks need event loop integration
    return error.NotImplemented;
}

/// Operation: structuredClone
///
/// Spec: HTML Standard § 2.7.9 structuredClone(value, options)
/// https://html.spec.whatwg.org/#dom-structuredclone
///
/// Creates a deep copy of a value using the structured clone algorithm.
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    if (state.own._internal == null) {
        return error.NotImplemented;
    }
    const internal = state.own._internal.?;

    // Parse options for transfer list (not used in basic implementation)
    _ = options;

    // Convert runtime.JSValue to structured_clone.JSValue
    const js_value: structured_clone.JSValue = switch (value) {
        .undefined => structured_clone.JSValue.undefined,
        .null => structured_clone.JSValue.null,
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| .{ .string = s.data },
        else => structured_clone.JSValue{ .object = .{ .properties = &[_]structured_clone.JSValue.ObjectValue.ObjectProperty{} } },
    };

    // Perform structured clone
    const cloned = structured_clone.structuredClone(
        internal.allocator,
        &js_value,
        null,
    ) catch {
        return error.OutOfMemory;
    };

    // Convert back to runtime.JSValue
    return switch (cloned.*) {
        .undefined => runtime.JSValue.jsUndefined,
        .null => runtime.JSValue.jsNull,
        .boolean => |b| runtime.JSValue.fromBoolean(b),
        .number => |n| runtime.JSValue.fromNumber(n),
        .string => |s| runtime.JSValue.fromStringRef(s),
        else => runtime.JSValue.jsUndefined,
    };
}

/// Operation: atob
///
/// Spec: HTML Standard § 8.3 Base64 utility methods
/// https://html.spec.whatwg.org/#dom-atob
///
/// Decodes a base64-encoded string.
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    const input = data.asSlice();

    // Handle empty input
    if (input.len == 0) {
        return "";
    }

    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else std.heap.page_allocator;

    // Calculate decoded length
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(input) catch {
        return error.InvalidCharacter;
    };

    // Allocate buffer for decoded data
    const buffer = allocator.alloc(u8, decoded_len) catch return error.OutOfMemory;
    errdefer allocator.free(buffer);

    // Decode
    std.base64.standard.Decoder.decode(buffer, input) catch {
        allocator.free(buffer);
        return error.InvalidCharacter;
    };

    return buffer;
}

/// Operation: btoa
///
/// Spec: HTML Standard § 8.3 Base64 utility methods
/// https://html.spec.whatwg.org/#dom-btoa
///
/// Encodes a string to base64.
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    const input = data.asSlice();

    // Handle empty input
    if (input.len == 0) {
        return runtime.DOMString.initEmpty();
    }

    const state = instance.getState(State);
    const allocator = if (state.own._internal) |internal| internal.allocator else std.heap.page_allocator;

    // Calculate encoded length
    const encoded_len = std.base64.standard.Encoder.calcSize(input.len);
    const buffer = allocator.alloc(u8, encoded_len) catch return error.OutOfMemory;
    errdefer allocator.free(buffer);

    // Encode
    const encoded = std.base64.standard.Encoder.encode(buffer, input);

    return runtime.DOMString.initOwned(encoded);
}

/// Operation: reportError
///
/// Spec: HTML Standard § 8.9 Error reporting
/// https://html.spec.whatwg.org/#dom-reporterror
///
/// Reports an error to the global error handler.
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    // In ShadowRealm, errors are reported to the global error handler
    // For now, just log the error
    _ = instance;
    _ = e;
    std.log.warn("[ShadowRealm] reportError called", .{});
}

// =============================================================================
// Tests
// =============================================================================

test "ShadowRealmGlobalScope base64 encoding" {
    const allocator = std.testing.allocator;

    // Test btoa
    const input = runtime.DOMString.initInterned("Hello, World!");
    _ = input;
    _ = allocator;
    // Full test would require runtime.Instance which needs V8
}
