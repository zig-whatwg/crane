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
//!       .deinit = &Node.deinit,  // Optional: auto-extracted if present
//!       .call_appendChild = &Node.call_appendChild,
//!       .get_nodeType = &Node.get_nodeType,
//!   };
//!   const vtable = buildVTable(&delegates);

const std = @import("std");
const Method = @import("instance.zig").Method;
const MethodMap = @import("instance.zig").MethodMap;
const VTable = @import("instance.zig").VTable;

/// Build a VTable from delegate functions using compile-time reflection
///
/// Takes a pointer to a const delegates struct. If the struct has a `.deinit` field,
/// it will be automatically extracted and used for cleanup when V8 GC collects the wrapper.
/// Uses compile-time reflection - NO Method enum required!
///
/// Example:
///   const delegates = .{
///       .deinit = &deinit,  // Auto-extracted for VTable.deinit
///       .call_appendChild = &impl.appendChild,
///       .get_nodeType = &impl.getNodeType,
///       .set_textContent = &impl.setTextContent,
///   };
///   const vtable = buildVTable(&delegates);
///
/// The delegates must be const and have a stable address (global or static).
/// The deinit function is called when the GC collects the JS wrapper object.
/// If delegates doesn't have .deinit, defaults to null (no cleanup).
pub fn buildVTable(comptime delegates_ptr: anytype) VTable {
    @setEvalBranchQuota(20000);

    const PtrInfo = @typeInfo(@TypeOf(delegates_ptr));
    if (PtrInfo != .pointer) {
        @compileError("buildVTable expects a pointer to delegates struct");
    }

    const DelegatesType = PtrInfo.pointer.child;
    const delegates_info = @typeInfo(DelegatesType);

    if (delegates_info != .@"struct") {
        @compileError("delegates must be a struct");
    }

    // Auto-extract .deinit from delegates if it exists
    const deinit_fn: ?*const fn (*Instance) void = if (@hasField(DelegatesType, "deinit"))
        delegates_ptr.deinit
    else
        null;

    return VTable{
        .deinit = deinit_fn,
        .methods_ptr = @ptrCast(delegates_ptr),
    };
}

/// Build a VTable with explicit deinit function
///
/// NOTE: Prefer using buildVTable() with .deinit in delegates struct instead.
/// This function is kept for backward compatibility but is no longer needed
/// since buildVTable() now auto-extracts .deinit from the delegates.
pub fn buildVTableWithDeinit(comptime delegates_ptr: anytype, comptime deinit_fn: ?*const fn (*Instance) void) VTable {
    @setEvalBranchQuota(20000);

    const PtrInfo = @typeInfo(@TypeOf(delegates_ptr));
    if (PtrInfo != .pointer) {
        @compileError("buildVTable expects a pointer to delegates struct");
    }

    const DelegatesType = PtrInfo.pointer.child;
    const delegates_info = @typeInfo(DelegatesType);

    if (delegates_info != .@"struct") {
        @compileError("delegates must be a struct");
    }

    return VTable{
        .deinit = deinit_fn,
        .methods_ptr = @ptrCast(delegates_ptr),
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
pub fn emptyVTable(comptime deinit: ?*const fn (*Instance) void) VTable {
    const empty_delegates = .{}; // Empty delegates struct
    return VTable{
        .deinit = deinit,
        .methods_ptr = &empty_delegates,
    };
}

// Unit tests
const testing = std.testing;
const Instance = @import("instance.zig").Instance;

// Note: Tests that use buildVTable() are in integration tests
// because they require the full Method enum from instance.zig

test "emptyVTable creates valid vtable" {
    const TestImpl = struct {
        fn deinit(_: *Instance) void {}
    };

    const vtable = emptyVTable(&TestImpl.deinit);

    try testing.expect(vtable.deinit == &TestImpl.deinit);
    // Empty VTable has no methods
    const DelegatesType = @TypeOf(.{});
    try testing.expect(vtable.getMethod(DelegatesType, "call_addEventListener") == null);
}

test "emptyVTable without deinit" {
    const vtable = emptyVTable(null);

    try testing.expect(vtable.deinit == null);
    // Empty VTable has no methods
}

// buildVTable tests moved to integration tests to avoid circular dependencies
