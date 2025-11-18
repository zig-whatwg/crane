//! Compile-time VTable construction for WebIDL interfaces
//!
//! This module provides compile-time utilities for building VTables from
//! interface delegate functions.
//!
//! Design:
//! - VTable is populated at compile time
//! - Method slots are filled by name matching
//! - Type-erased function pointers for polymorphism
//! - Zero runtime overhead (all resolved at compile time)
//!
//! Example usage:
//!   const delegates = .{
//!       .call_appendChild = &Node.call_appendChild,
//!       .get_nodeType = &Node.get_nodeType,
//!   };
//!   const vtable = buildVTable(delegates, &Node.deinit_wrapper);

const std = @import("std");
const Method = @import("instance.zig").Method;
const MethodMap = @import("instance.zig").MethodMap;
const VTable = @import("instance.zig").VTable;

/// Build a VTable from delegate functions
///
/// Takes a struct of delegate functions and builds a complete VTable.
/// The struct fields must match Method enum names.
///
/// Example:
///   const delegates = .{
///       .call_appendChild = &impl.appendChild,
///       .get_nodeType = &impl.getNodeType,
///       .set_textContent = &impl.setTextContent,
///   };
///   const vtable = buildVTable(delegates, &deinit_wrapper);
///
/// The function pointers are type-erased to *const anyopaque for storage
/// in the VTable, enabling polymorphism.
pub fn buildVTable(
    comptime delegates: anytype,
    comptime deinit_fn: ?*const fn (*anyopaque) void,
) VTable {
    var method_map = MethodMap.initFill(null);

    // Populate method map from delegates struct
    const DelegatesType = @TypeOf(delegates);
    const delegates_info = @typeInfo(DelegatesType);

    if (delegates_info != .@"struct") {
        @compileError("delegates must be a struct");
    }

    inline for (delegates_info.@"struct".fields) |field| {
        // Convert field name to Method enum
        const method_enum = std.meta.stringToEnum(Method, field.name);

        if (method_enum) |m| {
            // Get the delegate function pointer
            const delegate_fn = @field(delegates, field.name);

            // Cast to type-erased pointer and store in map
            method_map.set(m, @as(*const anyopaque, @ptrCast(delegate_fn)));
        } else {
            // Unknown method - this will cause a compile error with better context
            @compileError("Unknown method in delegates struct: '" ++ field.name ++ "'. Check that it matches a Method enum value.");
        }
    }

    return VTable{
        .deinit_fn = deinit_fn,
        .fns = method_map,
    };
}

/// Helper to validate a delegate struct at compile time
///
/// Checks that all delegate function pointers are valid.
/// This is called automatically by buildVTable.
pub fn validateDelegates(comptime delegates: anytype) void {
    const DelegatesType = @TypeOf(delegates);
    const delegates_info = @typeInfo(DelegatesType);

    if (delegates_info != .@"struct") {
        @compileError("delegates must be a struct");
    }

    // Verify each field
    inline for (delegates_info.@"struct".fields) |field| {
        // Check that field name maps to a Method
        _ = std.meta.stringToEnum(Method, field.name) orelse {
            @compileError("Unknown method name in delegates: " ++ field.name);
        };

        // Check that field type is a function pointer
        const field_info = @typeInfo(field.type);
        if (field_info != .pointer) {
            @compileError("Delegate field must be a pointer: " ++ field.name);
        }

        if (field_info.pointer.size != .One) {
            @compileError("Delegate must be a single-item pointer: " ++ field.name);
        }

        const child_info = @typeInfo(field_info.pointer.child);
        if (child_info != .@"fn") {
            @compileError("Delegate must point to a function: " ++ field.name);
        }
    }
}

/// Build an empty VTable (for testing or base interfaces)
pub fn emptyVTable(comptime deinit_fn: ?*const fn (*anyopaque) void) VTable {
    return VTable{
        .deinit_fn = deinit_fn,
        .fns = MethodMap.initFill(null),
    };
}

// Unit tests
const testing = std.testing;
const Instance = @import("instance.zig").Instance;

// Note: Tests that use buildVTable() are in integration tests
// because they require the full Method enum from instance.zig

test "emptyVTable creates valid vtable" {
    const TestImpl = struct {
        fn deinit(_: *anyopaque) void {}
    };

    const vtable = emptyVTable(&TestImpl.deinit);

    try testing.expect(vtable.deinit_fn == &TestImpl.deinit);
    try testing.expect(vtable.get(.call_addEventListener) == null);
    try testing.expect(vtable.get(.get_nodeType) == null);
}

test "emptyVTable without deinit" {
    const vtable = emptyVTable(null);

    try testing.expect(vtable.deinit_fn == null);
    try testing.expect(vtable.get(.call_addEventListener) == null);
}

// buildVTable tests moved to integration tests to avoid circular dependencies
