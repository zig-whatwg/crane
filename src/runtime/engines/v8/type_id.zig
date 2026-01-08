//! Snapshot-Stable TypeId System
//!
//! This module provides deterministic type identifiers for WebIDL interfaces
//! that remain stable across builds and snapshots. Unlike the numeric TypeTag
//! system in wrapper_type_info.zig (which uses manually assigned numbers),
//! TypeId is computed as a deterministic hash of the interface name.
//!
//! ## Why This Matters for Snapshots
//!
//! V8 snapshots serialize the entire heap state, including type identifiers.
//! When loading a snapshot, the type IDs must match exactly. Using a
//! deterministic hash of the interface name ensures:
//!
//! 1. **Cross-build stability**: Same interface name = same ID
//! 2. **No manual assignment**: IDs are automatically derived
//! 3. **Collision detection**: Comptime verification of uniqueness
//!
//! ## Hash Algorithm
//!
//! Uses FNV-1a with a fixed seed, matching the pattern used in
//! external_references.zig for consistency. FNV-1a provides:
//! - Excellent distribution for short strings (interface names)
//! - Deterministic output for same input
//! - Fast computation
//!
//! ## Usage
//!
//! ```zig
//! const interfaces = @import("interfaces");
//!
//! // Get TypeId for an interface at comptime
//! const element_id = comptime typeIdFor(interfaces.Element);
//!
//! // Verify no collisions across all interfaces (compile error on collision)
//! comptime {
//!     verifyNoCollisions(interfaces);
//! }
//! ```

const std = @import("std");

/// TypeId is a 64-bit deterministic hash of the interface name.
/// This provides snapshot stability across builds.
pub const TypeId = u64;

/// FNV-1a offset basis (64-bit)
const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;

/// FNV-1a prime (64-bit)
const FNV_PRIME: u64 = 0x100000001b3;

/// Compute a stable hash from an interface name using FNV-1a.
///
/// FNV-1a is chosen for:
/// - Determinism: Same input always produces same output
/// - Speed: Simple byte-by-byte operation
/// - Distribution: Good avalanche properties for short strings
/// - Consistency: Same algorithm used in external_references.zig
pub fn computeStableHash(name: []const u8) TypeId {
    var hash: u64 = FNV_OFFSET_BASIS;
    for (name) |byte| {
        hash ^= byte;
        hash *%= FNV_PRIME;
    }
    return hash;
}

/// Get the TypeId for a WebIDL interface type at comptime.
///
/// The interface type must have a `Meta` declaration with a `name` field.
/// This is the standard pattern for generated interface types.
///
/// Example:
/// ```zig
/// const Element = struct {
///     pub const Meta = struct {
///         pub const name = "Element";
///     };
/// };
///
/// const id = comptime typeIdFor(Element); // Returns hash of "Element"
/// ```
pub fn typeIdFor(comptime InterfaceType: type) TypeId {
    comptime {
        if (!@hasDecl(InterfaceType, "Meta")) {
            @compileError("Interface type must have a Meta declaration");
        }
        const Meta = InterfaceType.Meta;
        if (!@hasDecl(Meta, "name")) {
            @compileError("Interface Meta must have a name field");
        }
        const name = Meta.name;
        return computeStableHash(name);
    }
}

/// Maximum number of interfaces to track for collision detection.
/// This should be larger than the total number of WebIDL interfaces.
/// Current count is ~1100 interfaces, so 2000 provides headroom.
const MAX_INTERFACES: usize = 2000;

/// Entry for collision detection
const CollisionEntry = struct {
    id: TypeId,
    name: []const u8,
};

/// Verify that no two interfaces in a module have colliding TypeIds.
///
/// This function is designed to be called at comptime to catch
/// hash collisions before runtime. If a collision is detected,
/// it produces a compile error with the names of the colliding interfaces.
///
/// Example:
/// ```zig
/// const interfaces = @import("interfaces");
///
/// comptime {
///     verifyNoCollisions(interfaces);
/// }
/// ```
///
/// The function scans all declarations in the provided struct,
/// filters for types that have `Meta.name`, and verifies uniqueness.
pub fn verifyNoCollisions(comptime interfaces: type) void {
    comptime {
        const decls = @typeInfo(interfaces).@"struct".decls;

        var seen: [MAX_INTERFACES]CollisionEntry = undefined;
        var count: usize = 0;

        for (decls) |decl| {
            const field_type = @TypeOf(@field(interfaces, decl.name));

            // Only check types (not values)
            if (@typeInfo(field_type) != .type) continue;

            const T = @field(interfaces, decl.name);

            // Only check types with Meta.name
            if (@typeInfo(T) != .@"struct") continue;
            if (!@hasDecl(T, "Meta")) continue;

            const Meta = T.Meta;
            if (!@hasDecl(Meta, "name")) continue;

            const name = Meta.name;
            const id = computeStableHash(name);

            // Check for collision with previously seen entries
            for (seen[0..count]) |entry| {
                if (entry.id == id) {
                    @compileError("TypeId collision detected: '" ++
                        name ++ "' and '" ++ entry.name ++
                        "' both hash to " ++ std.fmt.comptimePrint("{d}", .{id}));
                }
            }

            // Add to seen list
            if (count >= MAX_INTERFACES) {
                @compileError("Too many interfaces - increase MAX_INTERFACES");
            }
            seen[count] = .{ .id = id, .name = name };
            count += 1;
        }
    }
}

/// Verify a list of interface types have no colliding TypeIds.
///
/// This is an alternative to verifyNoCollisions that takes an explicit
/// tuple of types instead of scanning a module.
///
/// Example:
/// ```zig
/// comptime {
///     verifyNoCollisionsForTypes(.{
///         Element,
///         Document,
///         Node,
///         EventTarget,
///     });
/// }
/// ```
pub fn verifyNoCollisionsForTypes(comptime types: anytype) void {
    comptime {
        const fields = @typeInfo(@TypeOf(types)).@"struct".fields;

        var seen: [MAX_INTERFACES]CollisionEntry = undefined;
        var count: usize = 0;

        for (fields) |field| {
            const T = @field(types, field.name);

            // Get the name from Meta
            if (!@hasDecl(T, "Meta")) {
                @compileError("Type must have Meta declaration");
            }
            const Meta = T.Meta;
            if (!@hasDecl(Meta, "name")) {
                @compileError("Meta must have name field");
            }

            const name = Meta.name;
            const id = computeStableHash(name);

            // Check for collision
            for (seen[0..count]) |entry| {
                if (entry.id == id) {
                    @compileError("TypeId collision detected: '" ++
                        name ++ "' and '" ++ entry.name ++
                        "' both hash to " ++ std.fmt.comptimePrint("{d}", .{id}));
                }
            }

            seen[count] = .{ .id = id, .name = name };
            count += 1;
        }
    }
}

/// Runtime TypeId registry for looking up types by ID.
///
/// While TypeIds are computed at comptime, this registry allows
/// runtime lookup of type information by ID. Useful for debugging
/// and reflection scenarios.
pub const TypeIdRegistry = struct {
    /// Map from TypeId to interface name
    by_id: std.AutoHashMap(TypeId, []const u8),
    /// Allocator for the map
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TypeIdRegistry {
        return .{
            .by_id = std.AutoHashMap(TypeId, []const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TypeIdRegistry) void {
        self.by_id.deinit();
    }

    /// Register an interface name with its TypeId
    pub fn register(self: *TypeIdRegistry, name: []const u8) !void {
        const id = computeStableHash(name);
        try self.by_id.put(id, name);
    }

    /// Look up an interface name by TypeId
    pub fn getNameById(self: *const TypeIdRegistry, id: TypeId) ?[]const u8 {
        return self.by_id.get(id);
    }

    /// Get the TypeId for an interface name
    pub fn getIdByName(name: []const u8) TypeId {
        return computeStableHash(name);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "computeStableHash - determinism" {
    // Same input should always produce same output
    const hash1 = computeStableHash("Element");
    const hash2 = computeStableHash("Element");
    try std.testing.expectEqual(hash1, hash2);

    // Different inputs should produce different outputs
    const hash3 = computeStableHash("Document");
    try std.testing.expect(hash1 != hash3);
}

test "computeStableHash - known values" {
    // These values should remain stable across builds
    // If they change, snapshot compatibility will break
    const element_hash = computeStableHash("Element");
    const document_hash = computeStableHash("Document");
    const node_hash = computeStableHash("Node");
    const event_target_hash = computeStableHash("EventTarget");

    // Verify they're all different
    try std.testing.expect(element_hash != document_hash);
    try std.testing.expect(element_hash != node_hash);
    try std.testing.expect(element_hash != event_target_hash);
    try std.testing.expect(document_hash != node_hash);
    try std.testing.expect(document_hash != event_target_hash);
    try std.testing.expect(node_hash != event_target_hash);

    // Verify specific hash values (these serve as regression tests)
    // If FNV-1a implementation is correct, these should match
    // These values MUST remain stable across builds for snapshot compatibility
    try std.testing.expectEqual(@as(TypeId, 0x190747c04bd639f7), element_hash);
    try std.testing.expectEqual(@as(TypeId, 0xa311a24c1471a974), document_hash);
    try std.testing.expectEqual(@as(TypeId, 0x66bd1cc6d2f6b68d), node_hash);
    try std.testing.expectEqual(@as(TypeId, 0x3434bcdb2add7b02), event_target_hash);
}

test "typeIdFor - basic usage" {
    const TestInterface = struct {
        pub const Meta = struct {
            pub const name = "TestInterface";
        };
    };

    const id = comptime typeIdFor(TestInterface);
    const expected = computeStableHash("TestInterface");
    try std.testing.expectEqual(expected, id);
}

test "verifyNoCollisionsForTypes - no collision" {
    const InterfaceA = struct {
        pub const Meta = struct {
            pub const name = "InterfaceA";
        };
    };

    const InterfaceB = struct {
        pub const Meta = struct {
            pub const name = "InterfaceB";
        };
    };

    const InterfaceC = struct {
        pub const Meta = struct {
            pub const name = "InterfaceC";
        };
    };

    // This should compile without error
    comptime {
        verifyNoCollisionsForTypes(.{ InterfaceA, InterfaceB, InterfaceC });
    }
}

test "TypeIdRegistry - basic operations" {
    var registry = TypeIdRegistry.init(std.testing.allocator);
    defer registry.deinit();

    try registry.register("Element");
    try registry.register("Document");
    try registry.register("Node");

    const element_id = computeStableHash("Element");
    const document_id = computeStableHash("Document");

    try std.testing.expectEqualStrings("Element", registry.getNameById(element_id).?);
    try std.testing.expectEqualStrings("Document", registry.getNameById(document_id).?);
    try std.testing.expectEqual(@as(?[]const u8, null), registry.getNameById(0));
}

test "computeStableHash - empty string" {
    const empty_hash = computeStableHash("");
    // Empty string should just return the offset basis
    try std.testing.expectEqual(FNV_OFFSET_BASIS, empty_hash);
}

test "computeStableHash - all printable ASCII" {
    // Verify that all common interface name characters work correctly
    const test_names = [_][]const u8{
        "HTMLElement",
        "SVGElement",
        "XMLHttpRequest",
        "WebGLRenderingContext",
        "CSSStyleDeclaration",
        "DOMParser",
        "AbortController",
        "ReadableStream",
        "WritableStream",
        "TransformStream",
    };

    var seen: [test_names.len]TypeId = undefined;
    for (test_names, 0..) |name, i| {
        seen[i] = computeStableHash(name);

        // Verify no collision with previous entries
        for (0..i) |j| {
            try std.testing.expect(seen[i] != seen[j]);
        }
    }
}

test "FNV-1a constants" {
    // Verify our constants match the FNV-1a specification
    try std.testing.expectEqual(@as(u64, 0xcbf29ce484222325), FNV_OFFSET_BASIS);
    try std.testing.expectEqual(@as(u64, 0x100000001b3), FNV_PRIME);
}
