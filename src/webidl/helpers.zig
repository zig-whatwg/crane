//! WebIDL Runtime Helpers
//!
//! Utilities for querying WebIDL metadata at runtime using the generated
//! __webidl__ metadata from the codegen system.
//!
//! Spec: https://webidl.spec.whatwg.org/

const std = @import("std");
const codegen = @import("codegen/root.zig");

/// Global scope identifier for checking interface exposure
/// Aligned with runtime.GlobalScopeKind for unified scope handling
/// Note: Conversion to/from GlobalScopeKind is in src/runtime/realm.zig
pub const GlobalScope = enum {
    /// Window global (browsers)
    Window,

    /// Generic Worker (matches "Worker" in [Exposed=Worker])
    Worker,

    /// DedicatedWorker global
    DedicatedWorker,

    /// SharedWorker global
    SharedWorker,

    /// ServiceWorker global
    ServiceWorker,

    /// Generic Worklet (matches "Worklet" in [Exposed=Worklet])
    Worklet,

    /// AudioWorklet global
    AudioWorklet,

    /// PaintWorklet global
    PaintWorklet,

    /// AnimationWorklet global
    AnimationWorklet,

    /// LayoutWorklet global
    LayoutWorklet,

    /// SharedStorageWorklet global
    SharedStorageWorklet,

    /// ShadowRealm global
    ShadowRealm,

    /// Convert from string identifier (WebIDL exposure attribute value)
    pub fn fromString(identifier: []const u8) ?GlobalScope {
        // Direct enum name matches
        inline for (std.meta.fields(GlobalScope)) |field| {
            if (std.mem.eql(u8, identifier, field.name)) {
                return @enumFromInt(field.value);
            }
        }
        return null;
    }

    /// Convert to string identifier
    pub fn toString(self: GlobalScope) []const u8 {
        return @tagName(self);
    }

    /// Check if this scope matches an exposure identifier from WebIDL
    /// Handles abstract categories like "Worker" matching all worker types
    pub fn matchesExposure(self: GlobalScope, exposure_id: []const u8) bool {
        // Direct match
        if (std.mem.eql(u8, exposure_id, self.toString())) {
            return true;
        }

        // Abstract "Worker" matches all worker types
        if (std.mem.eql(u8, exposure_id, "Worker")) {
            return switch (self) {
                .Worker, .DedicatedWorker, .SharedWorker, .ServiceWorker => true,
                else => false,
            };
        }

        // Abstract "Worklet" matches all worklet types
        if (std.mem.eql(u8, exposure_id, "Worklet")) {
            return switch (self) {
                .Worklet, .AudioWorklet, .PaintWorklet, .AnimationWorklet, .LayoutWorklet, .SharedStorageWorklet => true,
                else => false,
            };
        }

        return false;
    }
};

/// Check if an interface/namespace is exposed in a given global scope
///
/// Handles abstract categories like [Exposed=Worker] matching DedicatedWorker,
/// SharedWorker, and ServiceWorker scopes.
///
/// Usage:
/// ```zig
/// const EventTarget = @import("dom").EventTarget;
/// const exposed = isExposedIn(EventTarget, .Window); // true ([Exposed=*])
///
/// const ReadableStream = @import("streams").ReadableStream;
/// const exposed_in_worker = isExposedIn(ReadableStream, .Worker); // true ([Exposed=*])
///
/// // Abstract category matching:
/// // If an interface has [Exposed=Worker], it matches DedicatedWorker, SharedWorker, ServiceWorker
/// const exposed_in_dedicated = isExposedIn(SomeWorkerInterface, .DedicatedWorker); // true
/// ```
pub fn isExposedIn(comptime T: type, scope: GlobalScope) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;

    // Iterate through extended attributes looking for [Exposed]
    inline for (metadata.extended_attrs) |attr| {
        if (comptime !std.mem.eql(u8, attr.name, "Exposed")) {
            continue;
        }

        // Check the value type - could be .wildcard, .{ .identifier = ... }, or .{ .identifier_list = ... }
        const ValueType = @TypeOf(attr.value);

        // [Exposed=*] - exposed in all globals (value is enum literal .wildcard)
        if (ValueType == @TypeOf(.wildcard)) {
            return true;
        }

        // [Exposed=Window] - single identifier (value is struct with identifier field)
        if (@hasField(ValueType, "identifier")) {
            return scope.matchesExposure(attr.value.identifier);
        }

        // [Exposed=(Window,Worker)] - list of identifiers (value is struct with identifier_list field)
        if (@hasField(ValueType, "identifier_list")) {
            for (attr.value.identifier_list) |id| {
                if (scope.matchesExposure(id)) {
                    return true;
                }
            }
            return false;
        }

        return false;
    }

    // No [Exposed] attribute found - default is not exposed
    return false;
}

/// Check if an interface/namespace is exposed in a given runtime scope
///
/// This is the main entry point for runtime exposure checking, using GlobalScopeKind.
/// Note: Use runtime.GlobalScopeKind.toGlobalScope() to convert from GlobalScopeKind,
/// then call isExposedIn() with the result.
///
/// Usage:
/// ```zig
/// const scope = runtime.GlobalScopeKind.window.toGlobalScope();
/// const exposed = isExposedIn(EventTarget, scope);
/// ```
/// (This function is commented out because webidl module cannot import runtime.
/// The conversion should happen at the call site in runtime code.)
/// Check if an interface is transferable (can be transferred via postMessage)
///
/// Usage:
/// ```zig
/// const ReadableStream = @import("streams").ReadableStream;
/// const can_transfer = isTransferable(ReadableStream); // true ([Transferable])
///
/// const Event = @import("dom").Event;
/// const not_transferable = isTransferable(Event); // false (no [Transferable])
/// ```
pub fn isTransferable(comptime T: type) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;

    // Look for [Transferable] attribute
    inline for (metadata.extended_attrs) |attr| {
        if (comptime std.mem.eql(u8, attr.name, "Transferable")) {
            return true;
        }
    }

    return false;
}

/// Check if an interface is serializable (can be cloned via structured clone)
///
/// Usage:
/// ```zig
/// const DOMException = @import("webidl").DOMException;
/// const can_serialize = isSerializable(DOMException); // depends on [Serializable]
/// ```
pub fn isSerializable(comptime T: type) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;

    // Look for [Serializable] attribute
    inline for (metadata.extended_attrs) |attr| {
        if (comptime std.mem.eql(u8, attr.name, "Serializable")) {
            return true;
        }
    }

    return false;
}

/// Get all global scope names where an interface is exposed
///
/// Returns a list of global scope identifiers (e.g., ["Window", "Worker"])
/// Returns empty slice if not exposed anywhere or no [Exposed] attribute.
///
/// Usage:
/// ```zig
/// const EventTarget = @import("dom").EventTarget;
/// const globals = getGlobalNames(EventTarget);
/// // Returns null for [Exposed=*] (exposed everywhere)
///
/// const Node = @import("dom").Node;
/// const window_only = getGlobalNames(Node);
/// // Returns &.{"Window"} for [Exposed=Window]
/// ```
pub fn getGlobalNames(comptime T: type) ?[]const []const u8 {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return null;
    }

    const metadata = T.__webidl__;

    // Look for [Exposed] attribute
    inline for (metadata.extended_attrs) |attr| {
        if (comptime !std.mem.eql(u8, attr.name, "Exposed")) {
            continue;
        }

        // Check the value type - could be .wildcard, .{ .identifier = ... }, or .{ .identifier_list = ... }
        const ValueType = @TypeOf(attr.value);

        // [Exposed=*] - return null to indicate "all globals" (value is enum literal .wildcard)
        if (ValueType == @TypeOf(.wildcard)) {
            return null;
        }

        // [Exposed=Window] - single identifier (return as single-element slice)
        if (@hasField(ValueType, "identifier")) {
            return &.{attr.value.identifier};
        }

        // [Exposed=(Window,Worker)] - list of identifiers
        if (@hasField(ValueType, "identifier_list")) {
            return attr.value.identifier_list;
        }

        return null;
    }

    // No [Exposed] attribute
    return null;
}

/// Get the parent interface name if this interface inherits
///
/// Returns null if no parent (interface doesn't inherit).
///
/// Usage:
/// ```zig
/// const Element = @import("dom").Element;
/// const parent = getParent(Element); // "Node"
///
/// const EventTarget = @import("dom").EventTarget;
/// const no_parent = getParent(EventTarget); // null
/// ```
pub fn getParent(comptime T: type) ?[]const u8 {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return null;
    }

    const metadata = T.__webidl__;
    return metadata.parent;
}

/// Check if an interface is a namespace (static-only API)
///
/// Usage:
/// ```zig
/// const Console = @import("console").console;
/// const is_ns = isNamespace(Console); // true
/// ```
pub fn isNamespace(comptime T: type) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;
    return metadata.kind == .namespace;
}

/// Check if a type is a WebIDL interface (type-based check)
///
/// Usage:
/// ```zig
/// const EventTarget = @import("dom").EventTarget;
/// const is_iface = isInterfaceType(EventTarget); // true
/// ```
///
/// Note: This checks if a TYPE is a WebIDL interface at comptime.
/// For runtime value checking, use interfaces.isInterface(value).
pub fn isInterfaceType(comptime T: type) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;
    return metadata.kind == .interface;
}

/// Check if a type is a WebIDL mixin
///
/// Usage:
/// ```zig
/// const ParentNode = @import("dom").ParentNode;
/// const is_mix = isMixin(ParentNode); // true
/// ```
pub fn isMixin(comptime T: type) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;
    return metadata.kind == .mixin;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "GlobalScope.fromString and toString" {
    try testing.expectEqual(GlobalScope.Window, GlobalScope.fromString("Window").?);
    try testing.expectEqual(GlobalScope.Worker, GlobalScope.fromString("Worker").?);
    try testing.expectEqual(GlobalScope.DedicatedWorker, GlobalScope.fromString("DedicatedWorker").?);
    try testing.expectEqual(GlobalScope.SharedWorker, GlobalScope.fromString("SharedWorker").?);
    try testing.expectEqual(GlobalScope.ServiceWorker, GlobalScope.fromString("ServiceWorker").?);
    try testing.expectEqual(GlobalScope.AudioWorklet, GlobalScope.fromString("AudioWorklet").?);
    try testing.expectEqual(GlobalScope.PaintWorklet, GlobalScope.fromString("PaintWorklet").?);
    try testing.expectEqual(GlobalScope.ShadowRealm, GlobalScope.fromString("ShadowRealm").?);
    try testing.expectEqual(@as(?GlobalScope, null), GlobalScope.fromString("InvalidScope"));

    try testing.expectEqualStrings("Window", GlobalScope.Window.toString());
    try testing.expectEqualStrings("Worker", GlobalScope.Worker.toString());
    try testing.expectEqualStrings("AudioWorklet", GlobalScope.AudioWorklet.toString());
}

// Note: Conversion tests between GlobalScope and GlobalScopeKind are in
// src/runtime/realm.zig where both types are accessible.

test "GlobalScope.matchesExposure - direct matches" {
    try testing.expect(GlobalScope.Window.matchesExposure("Window"));
    try testing.expect(GlobalScope.DedicatedWorker.matchesExposure("DedicatedWorker"));
    try testing.expect(GlobalScope.ServiceWorker.matchesExposure("ServiceWorker"));
    try testing.expect(GlobalScope.AudioWorklet.matchesExposure("AudioWorklet"));
    try testing.expect(GlobalScope.ShadowRealm.matchesExposure("ShadowRealm"));

    // Non-matches
    try testing.expect(!GlobalScope.Window.matchesExposure("Worker"));
    try testing.expect(!GlobalScope.ShadowRealm.matchesExposure("Window"));
}

test "GlobalScope.matchesExposure - abstract Worker category" {
    // [Exposed=Worker] should match all worker types
    try testing.expect(GlobalScope.Worker.matchesExposure("Worker"));
    try testing.expect(GlobalScope.DedicatedWorker.matchesExposure("Worker"));
    try testing.expect(GlobalScope.SharedWorker.matchesExposure("Worker"));
    try testing.expect(GlobalScope.ServiceWorker.matchesExposure("Worker"));

    // But Window and worklets should not match Worker
    try testing.expect(!GlobalScope.Window.matchesExposure("Worker"));
    try testing.expect(!GlobalScope.AudioWorklet.matchesExposure("Worker"));
    try testing.expect(!GlobalScope.ShadowRealm.matchesExposure("Worker"));
}

test "GlobalScope.matchesExposure - abstract Worklet category" {
    // [Exposed=Worklet] should match all worklet types
    try testing.expect(GlobalScope.Worklet.matchesExposure("Worklet"));
    try testing.expect(GlobalScope.AudioWorklet.matchesExposure("Worklet"));
    try testing.expect(GlobalScope.PaintWorklet.matchesExposure("Worklet"));
    try testing.expect(GlobalScope.AnimationWorklet.matchesExposure("Worklet"));
    try testing.expect(GlobalScope.LayoutWorklet.matchesExposure("Worklet"));
    try testing.expect(GlobalScope.SharedStorageWorklet.matchesExposure("Worklet"));

    // But Window and workers should not match Worklet
    try testing.expect(!GlobalScope.Window.matchesExposure("Worklet"));
    try testing.expect(!GlobalScope.DedicatedWorker.matchesExposure("Worklet"));
    try testing.expect(!GlobalScope.ShadowRealm.matchesExposure("Worklet"));
}

// Note: Integration tests with actual generated interfaces are in tests/webidl/helpers_test.zig
