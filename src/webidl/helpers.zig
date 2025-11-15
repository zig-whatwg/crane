//! WebIDL Runtime Helpers
//!
//! Utilities for querying WebIDL metadata at runtime using the generated
//! __webidl__ metadata from the codegen system.
//!
//! Spec: https://webidl.spec.whatwg.org/

const std = @import("std");
const codegen = @import("codegen/root.zig");

/// Global scope identifier for checking interface exposure
pub const GlobalScope = enum {
    /// Window global (browsers)
    Window,

    /// Worker global (Web Workers)
    Worker,

    /// Worklet global (Audio/Paint/Layout worklets)
    Worklet,

    /// ServiceWorker global
    ServiceWorker,

    /// SharedWorker global
    SharedWorker,

    /// DedicatedWorker global
    DedicatedWorker,

    /// Convert from string identifier
    pub fn fromString(identifier: []const u8) ?GlobalScope {
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
};

/// Check if an interface/namespace is exposed in a given global scope
///
/// Usage:
/// ```zig
/// const EventTarget = @import("dom").EventTarget;
/// const exposed = isExposedIn(EventTarget, .Window); // true ([Exposed=*])
///
/// const ReadableStream = @import("streams").ReadableStream;
/// const exposed_in_worker = isExposedIn(ReadableStream, .Worker); // true ([Exposed=*])
/// ```
pub fn isExposedIn(comptime T: type, scope: GlobalScope) bool {
    // Check if type has __webidl__ metadata
    if (!@hasDecl(T, "__webidl__")) {
        return false;
    }

    const metadata = T.__webidl__;

    // Iterate through extended attributes looking for [Exposed]
    for (metadata.extended_attrs) |attr| {
        if (!std.mem.eql(u8, attr.name, "Exposed")) {
            continue;
        }

        switch (attr.value) {
            // [Exposed=*] - exposed in all globals
            .wildcard => return true,

            // [Exposed=Window] - single identifier
            .identifier => |id| {
                return std.mem.eql(u8, id, scope.toString());
            },

            // [Exposed=(Window,Worker)] - list of identifiers
            .identifier_list => |list| {
                for (list) |id| {
                    if (std.mem.eql(u8, id, scope.toString())) {
                        return true;
                    }
                }
                return false;
            },

            else => return false,
        }
    }

    // No [Exposed] attribute found - default is not exposed
    return false;
}

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
    for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Transferable")) {
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
    for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Serializable")) {
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
    for (metadata.extended_attrs) |attr| {
        if (!std.mem.eql(u8, attr.name, "Exposed")) {
            continue;
        }

        switch (attr.value) {
            // [Exposed=*] - return null to indicate "all globals"
            .wildcard => return null,

            // [Exposed=Window] - single identifier
            .identifier => |id| {
                return &.{id};
            },

            // [Exposed=(Window,Worker)] - list of identifiers
            .identifier_list => |list| {
                return list;
            },

            else => return null,
        }
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

/// Check if a type is a WebIDL interface
///
/// Usage:
/// ```zig
/// const EventTarget = @import("dom").EventTarget;
/// const is_iface = isInterface(EventTarget); // true
/// ```
pub fn isInterface(comptime T: type) bool {
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
    try testing.expectEqual(@as(?GlobalScope, null), GlobalScope.fromString("InvalidScope"));

    try testing.expectEqualStrings("Window", GlobalScope.Window.toString());
    try testing.expectEqualStrings("Worker", GlobalScope.Worker.toString());
}

// Note: Integration tests with actual generated interfaces are in tests/webidl/helpers_test.zig
