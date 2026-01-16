//! WebIDL Runtime Helpers
//!
//! Utilities for querying WebIDL metadata at runtime using the generated
//! Meta struct from the codegen system.
//!
//! Spec: https://webidl.spec.whatwg.org/

const std = @import("std");
const codegen = @import("codegen/root.zig");

/// Global scope identifier for checking interface exposure
pub const GlobalScope = enum {
    /// Window global (browsers)
    Window,

    /// Worker global (Web Workers - matches any worker type)
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

    /// Check if this scope matches a given exposure identifier
    /// Handles the inheritance: DedicatedWorker matches "Worker", "DedicatedWorker"
    pub fn matchesExposure(self: GlobalScope, identifier: []const u8) bool {
        // Direct match
        if (std.mem.eql(u8, identifier, self.toString())) {
            return true;
        }

        // Worker inheritance: [Exposed=Worker] applies to all worker types
        if (std.mem.eql(u8, identifier, "Worker")) {
            return switch (self) {
                .Worker, .DedicatedWorker, .SharedWorker, .ServiceWorker => true,
                else => false,
            };
        }

        return false;
    }
};

/// Check if an interface/namespace is exposed in a given global scope
///
/// Works with the generated Meta struct format:
/// - Meta.exposed_in_all_contexts: bool (for [Exposed=*])
/// - Meta.extended_attributes: tuple of .{ .name, .value } structs
///
/// Usage:
/// ```zig
/// const EventTarget = @import("interfaces").EventTarget;
/// const exposed = isExposedIn(EventTarget, .Window); // true ([Exposed=*])
///
/// const ReadableStream = @import("interfaces").ReadableStream;
/// const exposed_in_worker = isExposedIn(ReadableStream, .DedicatedWorker); // true ([Exposed=*])
/// ```
pub fn isExposedIn(comptime T: type, scope: GlobalScope) bool {
    // Check if type has Meta struct (generated interface format)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;

        // Fast path: check exposed_in_all_contexts flag first
        if (@hasDecl(Meta, "exposed_in_all_contexts")) {
            if (Meta.exposed_in_all_contexts) {
                return true;
            }
        }

        // Check extended_attributes for [Exposed] attribute
        if (@hasDecl(Meta, "extended_attributes")) {
            return checkExposedAttribute(Meta.extended_attributes, scope);
        }

        // No exposure info found in Meta - default not exposed
        return false;
    }

    // Legacy: Check if type has __webidl__ metadata (old format)
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "extended_attrs")) {
            return checkExposedAttribute(metadata.extended_attrs, scope);
        }
    }

    return false;
}

/// Helper to check [Exposed] attribute in an extended_attributes tuple
fn checkExposedAttribute(comptime attrs: anytype, scope: GlobalScope) bool {
    // Iterate through extended attributes looking for [Exposed]
    inline for (attrs) |attr| {
        if (comptime !std.mem.eql(u8, attr.name, "Exposed")) {
            continue;
        }

        // Check the value type
        const ValueType = @TypeOf(attr.value);
        const value_info = @typeInfo(ValueType);

        // [Exposed=*] - check if value is the wildcard identifier
        if (value_info == .@"struct" and @hasField(ValueType, "identifier")) {
            const identifier = attr.value.identifier;
            if (std.mem.eql(u8, identifier, "*")) {
                return true; // Exposed in all contexts
            }
            // [Exposed=Window] or [Exposed=Worker] - single identifier
            return scope.matchesExposure(identifier);
        }

        // [Exposed=(Window,Worker)] - list of identifiers
        if (value_info == .@"struct" and @hasField(ValueType, "identifier_list")) {
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

/// Check if an interface is transferable (can be transferred via postMessage)
///
/// Usage:
/// ```zig
/// const ReadableStream = @import("interfaces").ReadableStream;
/// const can_transfer = isTransferable(ReadableStream); // true ([Transferable])
///
/// const Event = @import("interfaces").Event;
/// const not_transferable = isTransferable(Event); // false (no [Transferable])
/// ```
pub fn isTransferable(comptime T: type) bool {
    return hasExtendedAttribute(T, "Transferable");
}

/// Check if an interface is serializable (can be cloned via structured clone)
///
/// Usage:
/// ```zig
/// const DOMException = @import("interfaces").DOMException;
/// const can_serialize = isSerializable(DOMException); // depends on [Serializable]
/// ```
pub fn isSerializable(comptime T: type) bool {
    return hasExtendedAttribute(T, "Serializable");
}

/// Helper to check if a type has a specific extended attribute
fn hasExtendedAttribute(comptime T: type, comptime attr_name: []const u8) bool {
    // Check Meta.extended_attributes (new format)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;
        if (@hasDecl(Meta, "extended_attributes")) {
            inline for (Meta.extended_attributes) |attr| {
                if (comptime std.mem.eql(u8, attr.name, attr_name)) {
                    return true;
                }
            }
        }
        return false;
    }

    // Legacy: Check __webidl__.extended_attrs
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "extended_attrs")) {
            inline for (metadata.extended_attrs) |attr| {
                if (comptime std.mem.eql(u8, attr.name, attr_name)) {
                    return true;
                }
            }
        }
    }

    return false;
}

/// Get all global scope names where an interface is exposed
///
/// Returns a list of global scope identifiers (e.g., ["Window", "Worker"])
/// Returns null for [Exposed=*] (exposed everywhere) or no [Exposed] attribute.
///
/// Usage:
/// ```zig
/// const EventTarget = @import("interfaces").EventTarget;
/// const globals = getGlobalNames(EventTarget);
/// // Returns null for [Exposed=*] (exposed everywhere)
///
/// const Node = @import("interfaces").Node;
/// const window_only = getGlobalNames(Node);
/// // Returns &.{"Window"} for [Exposed=Window]
/// ```
pub fn getGlobalNames(comptime T: type) ?[]const []const u8 {
    // Check Meta.extended_attributes (new format)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;

        // Fast path: exposed in all contexts
        if (@hasDecl(Meta, "exposed_in_all_contexts") and Meta.exposed_in_all_contexts) {
            return null; // null means "all contexts"
        }

        if (@hasDecl(Meta, "extended_attributes")) {
            return getGlobalNamesFromAttrs(Meta.extended_attributes);
        }
        return null;
    }

    // Legacy: Check __webidl__.extended_attrs
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "extended_attrs")) {
            return getGlobalNamesFromAttrs(metadata.extended_attrs);
        }
    }

    return null;
}

/// Helper to extract global names from extended attributes
fn getGlobalNamesFromAttrs(comptime attrs: anytype) ?[]const []const u8 {
    inline for (attrs) |attr| {
        if (comptime !std.mem.eql(u8, attr.name, "Exposed")) {
            continue;
        }

        const ValueType = @TypeOf(attr.value);
        const value_info = @typeInfo(ValueType);

        if (value_info == .@"struct" and @hasField(ValueType, "identifier")) {
            const identifier = attr.value.identifier;
            if (std.mem.eql(u8, identifier, "*")) {
                return null; // Exposed in all contexts
            }
            return &.{identifier};
        }

        if (value_info == .@"struct" and @hasField(ValueType, "identifier_list")) {
            return attr.value.identifier_list;
        }

        return null;
    }

    return null;
}

/// Get the parent interface name if this interface inherits
///
/// Returns null if no parent (interface doesn't inherit).
///
/// Usage:
/// ```zig
/// const Element = @import("interfaces").Element;
/// const parent = getParent(Element); // "Node"
///
/// const EventTarget = @import("interfaces").EventTarget;
/// const no_parent = getParent(EventTarget); // null
/// ```
pub fn getParent(comptime T: type) ?[]const u8 {
    // Check Meta.BaseType (new format - it's a type, not a string)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;
        if (@hasDecl(Meta, "BaseType")) {
            if (Meta.BaseType) |BaseType| {
                // BaseType is a type, return its name
                if (@hasDecl(BaseType, "Meta") and @hasDecl(BaseType.Meta, "name")) {
                    return BaseType.Meta.name;
                }
            }
        }
        return null;
    }

    // Legacy: Check __webidl__.parent
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "parent")) {
            return metadata.parent;
        }
    }

    return null;
}

/// Check if an interface is a namespace (static-only API)
///
/// Usage:
/// ```zig
/// const console = @import("namespaces").console;
/// const is_ns = isNamespace(console); // true
/// ```
pub fn isNamespace(comptime T: type) bool {
    // Check Meta.is_namespace or similar flag (new format)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;
        // Namespaces typically don't have has_constructor and don't have BaseType
        // Check for namespace-specific indicators
        if (@hasDecl(Meta, "is_namespace")) {
            return Meta.is_namespace;
        }
        // Heuristic: namespaces have no constructor and no instances
        if (@hasDecl(Meta, "has_constructor") and !Meta.has_constructor) {
            // Further check: namespaces typically don't have State
            if (!@hasDecl(T, "State")) {
                return true;
            }
        }
        return false;
    }

    // Legacy: Check __webidl__.kind
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "kind")) {
            return metadata.kind == .namespace;
        }
    }

    return false;
}

/// Check if a type is a WebIDL interface (type-based check)
///
/// Usage:
/// ```zig
/// const EventTarget = @import("interfaces").EventTarget;
/// const is_iface = isInterfaceType(EventTarget); // true
/// ```
///
/// Note: This checks if a TYPE is a WebIDL interface at comptime.
/// For runtime value checking, use interfaces.isInterface(value).
pub fn isInterfaceType(comptime T: type) bool {
    // Check if has Meta with interface indicators (new format)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;
        // Interfaces have is_mixin = false and typically have name
        if (@hasDecl(Meta, "is_mixin") and !Meta.is_mixin) {
            if (@hasDecl(Meta, "name")) {
                return true;
            }
        }
        return false;
    }

    // Legacy: Check __webidl__.kind
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "kind")) {
            return metadata.kind == .interface;
        }
    }

    return false;
}

/// Check if a type is a WebIDL mixin
///
/// Usage:
/// ```zig
/// const ParentNode = @import("mixins").ParentNode;
/// const is_mix = isMixin(ParentNode); // true
/// ```
pub fn isMixin(comptime T: type) bool {
    // Check Meta.is_mixin (new format)
    if (@hasDecl(T, "Meta")) {
        const Meta = T.Meta;
        if (@hasDecl(Meta, "is_mixin")) {
            return Meta.is_mixin;
        }
        return false;
    }

    // Legacy: Check __webidl__.kind
    if (@hasDecl(T, "__webidl__")) {
        const metadata = T.__webidl__;
        if (@hasDecl(@TypeOf(metadata), "kind")) {
            return metadata.kind == .mixin;
        }
    }

    return false;
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
