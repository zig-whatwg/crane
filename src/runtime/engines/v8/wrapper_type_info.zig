//! WrapperTypeInfo - Type metadata for V8 bindings
//!
//! This module implements a Chrome-style WrapperTypeInfo system that provides:
//! - Static type metadata per WebIDL interface
//! - Tag-based type checking for safe unwrapping
//! - Inheritance chain tracking via parent pointers
//! - Contiguous tag ranges for efficient subclass checking
//!
//! ## Design (following Chrome/Blink patterns)
//!
//! Each WebIDL interface gets a unique WrapperTypeInfo with:
//! - A unique type tag (assigned by codegen in inheritance order)
//! - A max_subclass_tag covering all descendants
//! - A parent pointer for walking the inheritance chain
//!
//! When unwrapping a V8 object to a specific Zig type:
//! 1. Read the tag from the object's internal field
//! 2. Check if tag is in range [this_tag, max_subclass_tag]
//! 3. If valid, the C++ pointer is safe to cast
//!
//! ## Tag Assignment Strategy
//!
//! Tags are assigned in DFS order through the inheritance tree:
//! ```
//! EventTarget (tag: 100, max: 199)
//!   └─ Node (tag: 110, max: 189)
//!       ├─ Element (tag: 120, max: 179)
//!       │   ├─ HTMLElement (tag: 130, max: 169)
//!       │   │   ├─ HTMLDivElement (tag: 140, max: 140)
//!       │   │   └─ HTMLSpanElement (tag: 141, max: 141)
//!       │   └─ SVGElement (tag: 170, max: 179)
//!       └─ Document (tag: 180, max: 189)
//! ```
//!
//! This ensures:
//! - All descendants have tags > parent's this_tag
//! - All descendants have tags <= parent's max_subclass_tag
//! - Subclass checking is O(1): just compare tag ranges

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");

/// Type tag for WebIDL interfaces
/// Tags are assigned by codegen and form contiguous ranges for inheritance
pub const TypeTag = u16;

/// Wrapper class IDs for garbage collection
/// Matches Chrome's WrapperClassId enum
pub const WrapperClassId = enum(u8) {
    /// No internal field (shouldn't happen for wrapped objects)
    none = 0,
    /// DOM Node and subclasses (special GC treatment)
    node = 1,
    /// Regular WebIDL objects
    object = 2,
    /// Custom wrappable (user-defined)
    custom = 3,
};

/// IDL definition kind
pub const IdlDefinitionKind = enum(u8) {
    interface,
    namespace,
    callback_interface,
    dictionary,
    enumeration,
};

/// Static type metadata for a WebIDL interface
///
/// Each interface has exactly one WrapperTypeInfo instance (defined by codegen).
/// This provides O(1) type checking and safe unwrapping.
pub const WrapperTypeInfo = struct {
    /// Human-readable interface name (e.g., "Element", "Document")
    interface_name: [*:0]const u8,

    /// Parent interface's WrapperTypeInfo (null for root interfaces like EventTarget)
    parent: ?*const WrapperTypeInfo,

    /// Unique type tag for this interface
    this_tag: TypeTag,

    /// Maximum tag of any subclass (for range checking)
    /// If this interface has no subclasses, equals this_tag
    max_subclass_tag: TypeTag,

    /// Wrapper class ID for GC
    wrapper_class_id: WrapperClassId,

    /// IDL definition kind
    idl_definition_kind: IdlDefinitionKind,

    /// Function to install the V8 FunctionTemplate for this interface
    install_template_fn: *const fn (*v8.Isolate) *v8.FunctionTemplate,

    /// Check if this type is a subclass of another
    /// Walks the parent chain (O(depth) but depth is typically small)
    pub fn isSubclassOf(self: *const WrapperTypeInfo, ancestor: *const WrapperTypeInfo) bool {
        var current: ?*const WrapperTypeInfo = self;
        while (current) |info| {
            if (info == ancestor) return true;
            current = info.parent;
        }
        return false;
    }

    /// Check if a tag is valid for this type (including subclasses)
    /// O(1) range check
    pub fn isValidTag(self: *const WrapperTypeInfo, tag: TypeTag) bool {
        return tag >= self.this_tag and tag <= self.max_subclass_tag;
    }

    /// Get the interface name as a Zig slice
    pub fn getName(self: *const WrapperTypeInfo) []const u8 {
        return std.mem.span(self.interface_name);
    }
};

/// Global registry of all WrapperTypeInfo instances
/// Allows looking up type info by tag (for debugging/reflection)
pub const TypeRegistry = struct {
    /// Map from tag to WrapperTypeInfo
    by_tag: std.AutoHashMap(TypeTag, *const WrapperTypeInfo),
    /// Map from name to WrapperTypeInfo
    by_name: std.StringHashMap(*const WrapperTypeInfo),
    /// Allocator for the maps
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TypeRegistry {
        return .{
            .by_tag = std.AutoHashMap(TypeTag, *const WrapperTypeInfo).init(allocator),
            .by_name = std.StringHashMap(*const WrapperTypeInfo).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TypeRegistry) void {
        self.by_tag.deinit();
        self.by_name.deinit();
    }

    pub fn register(self: *TypeRegistry, info: *const WrapperTypeInfo) !void {
        try self.by_tag.put(info.this_tag, info);
        try self.by_name.put(info.getName(), info);
    }

    pub fn getByTag(self: *const TypeRegistry, tag: TypeTag) ?*const WrapperTypeInfo {
        return self.by_tag.get(tag);
    }

    pub fn getByName(self: *const TypeRegistry, name: []const u8) ?*const WrapperTypeInfo {
        return self.by_name.get(name);
    }
};

/// Global type registry singleton
var global_registry: ?TypeRegistry = null;

pub fn getGlobalRegistry() *TypeRegistry {
    if (global_registry == null) {
        global_registry = TypeRegistry.init(std.heap.page_allocator);
    }
    return &global_registry.?;
}

// ============================================================================
// V8 Object Wrapping/Unwrapping
// ============================================================================

/// Internal field indices in V8 objects
const InternalFieldIndex = struct {
    /// Slot 0: Pointer to Zig instance (*runtime.Instance)
    const instance: c_int = 0;
    /// Slot 1: Pointer to WrapperTypeInfo (for type checking)
    const type_info: c_int = 1;
};

/// Number of internal fields required for wrapped objects
pub const INTERNAL_FIELD_COUNT: c_int = 2;

/// Wrap a Zig instance into a V8 object
///
/// Stores both the instance pointer and the type info for later unwrapping.
pub fn wrapInstance(
    v8_object: *v8.Object,
    instance: *runtime.Instance,
    type_info: *const WrapperTypeInfo,
) void {
    // Store instance pointer in slot 0
    v8.v8_Object_SetAlignedPointerInInternalField(
        v8_object,
        InternalFieldIndex.instance,
        @ptrCast(instance),
    );
    // Store type info pointer in slot 1
    v8.v8_Object_SetAlignedPointerInInternalField(
        v8_object,
        InternalFieldIndex.type_info,
        @ptrCast(@constCast(type_info)),
    );
}

/// Get the WrapperTypeInfo from a V8 object
pub fn getTypeInfo(v8_object: *v8.Object) ?*const WrapperTypeInfo {
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(
        v8_object,
        InternalFieldIndex.type_info,
    ) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

/// Unwrap a V8 object to a Zig instance with type checking
///
/// Returns the instance if:
/// 1. The object has internal fields set
/// 2. The stored type tag is valid for the expected type
///
/// This is the safe way to convert V8 objects to Zig instances.
pub fn unwrapInstance(
    v8_object: *v8.Object,
    expected_type: *const WrapperTypeInfo,
) ?*runtime.Instance {
    // Get stored type info
    const stored_type_info = getTypeInfo(v8_object) orelse return null;

    // Check if the stored type is compatible with expected type
    // The stored tag must be in the expected type's valid range
    if (!expected_type.isValidTag(stored_type_info.this_tag)) {
        return null;
    }

    // Type check passed, get the instance pointer
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(
        v8_object,
        InternalFieldIndex.instance,
    ) orelse return null;

    return @ptrCast(@alignCast(ptr));
}

/// Unwrap a V8 object to any Zig instance (no type checking)
///
/// Use this only when you need to accept any WebIDL object.
/// For type-safe unwrapping, use unwrapInstance with a specific type.
pub fn unwrapAnyInstance(v8_object: *v8.Object) ?*runtime.Instance {
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(
        v8_object,
        InternalFieldIndex.instance,
    ) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

// ============================================================================
// Tests
// ============================================================================

test "WrapperTypeInfo.isSubclassOf" {
    // Create a simple hierarchy: Child -> Parent -> GrandParent
    const grandparent_info = WrapperTypeInfo{
        .interface_name = "GrandParent",
        .parent = null,
        .this_tag = 100,
        .max_subclass_tag = 199,
        .wrapper_class_id = .object,
        .idl_definition_kind = .interface,
        .install_template_fn = undefined,
    };

    const parent_info = WrapperTypeInfo{
        .interface_name = "Parent",
        .parent = &grandparent_info,
        .this_tag = 110,
        .max_subclass_tag = 150,
        .wrapper_class_id = .object,
        .idl_definition_kind = .interface,
        .install_template_fn = undefined,
    };

    const child_info = WrapperTypeInfo{
        .interface_name = "Child",
        .parent = &parent_info,
        .this_tag = 120,
        .max_subclass_tag = 120,
        .wrapper_class_id = .object,
        .idl_definition_kind = .interface,
        .install_template_fn = undefined,
    };

    // Test isSubclassOf
    try std.testing.expect(child_info.isSubclassOf(&child_info)); // Self
    try std.testing.expect(child_info.isSubclassOf(&parent_info)); // Direct parent
    try std.testing.expect(child_info.isSubclassOf(&grandparent_info)); // Ancestor
    try std.testing.expect(!grandparent_info.isSubclassOf(&child_info)); // Not a subclass
}

test "WrapperTypeInfo.isValidTag" {
    const info = WrapperTypeInfo{
        .interface_name = "Test",
        .parent = null,
        .this_tag = 100,
        .max_subclass_tag = 150,
        .wrapper_class_id = .object,
        .idl_definition_kind = .interface,
        .install_template_fn = undefined,
    };

    try std.testing.expect(info.isValidTag(100)); // Own tag
    try std.testing.expect(info.isValidTag(125)); // Subclass tag
    try std.testing.expect(info.isValidTag(150)); // Max subclass tag
    try std.testing.expect(!info.isValidTag(99)); // Below range
    try std.testing.expect(!info.isValidTag(151)); // Above range
}
