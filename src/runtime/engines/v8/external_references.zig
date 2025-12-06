//! V8 External References Registry for Snapshot Support
//!
//! This module collects all FunctionCallback pointers used by V8 interface bindings
//! at compile time. These external references are REQUIRED for V8 snapshots to work.
//!
//! ## Background
//!
//! When V8 creates a snapshot, it serializes the heap including all FunctionTemplates.
//! These templates contain pointers to C++ callback functions. When loading a snapshot,
//! V8 needs to know where these callback functions are located in memory.
//!
//! The external references array tells V8: "These are all the native function pointers
//! that may be referenced from the snapshot. Use this array to resolve them."
//!
//! ## Critical Requirement
//!
//! The external references array MUST:
//! 1. Contain ALL callback pointers used in interface bindings
//! 2. Be in the SAME ORDER at snapshot creation and loading time
//! 3. Be null-terminated
//!
//! If any callback is missing or in a different order, V8 will crash when loading
//! the snapshot because it cannot resolve the callback addresses.
//!
//! ## Architecture
//!
//! The external references are collected at comptime by:
//! 1. V8Interface calls `collectInterfaceCallbacks()` which returns all callbacks for that interface
//! 2. `getAllExternalReferences()` iterates over all interfaces and collects all callbacks
//! 3. The result is a comptime-known array of function pointers
//!
//! ## Usage
//!
//! When creating a snapshot:
//! ```zig
//! const refs = external_references.getAllExternalReferences();
//! const creator = v8.v8_SnapshotCreator_New(refs.ptr);
//! ```
//!
//! When loading a snapshot:
//! ```zig
//! const refs = external_references.getAllExternalReferences();
//! const isolate = v8.v8_Isolate_NewFromSnapshot(data, size, refs.ptr);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");

/// Maximum number of external references we can collect
/// This needs to be large enough for all interfaces * (methods + properties + callbacks)
/// Estimate: ~1200 interfaces * ~20 callbacks each = ~24000 callbacks
/// Plus namespaces, iterators, etc. = ~30000 total
const MAX_EXTERNAL_REFS = 50000;

/// A single external reference entry
pub const ExternalRef = struct {
    ptr: isize,
    name: []const u8 = "", // For debugging
};

/// Dynamic collection for runtime registration
/// Used as a fallback when comptime collection isn't possible
var runtime_refs: [MAX_EXTERNAL_REFS]isize = [_]isize{0} ** MAX_EXTERNAL_REFS;
var runtime_ref_count: usize = 0;

/// Register a callback at runtime
///
/// This is used when callbacks cannot be collected at comptime.
/// Must be called before snapshot creation.
pub fn registerCallbackRuntime(callback: v8.FunctionCallback) void {
    registerPointer(@intFromPtr(callback));
}

/// Register any pointer as an external reference
///
/// This is the generic version that accepts any pointer type.
/// Use this for non-FunctionCallback callbacks (e.g., NamedPropertyCallback).
pub fn registerPointer(ptr: usize) void {
    const ptr_value: isize = @intCast(ptr);

    // Check if already registered
    for (runtime_refs[0..runtime_ref_count]) |ref| {
        if (ref == ptr_value) return;
    }

    if (runtime_ref_count >= MAX_EXTERNAL_REFS) {
        std.debug.panic("Too many external references - increase MAX_EXTERNAL_REFS", .{});
    }

    runtime_refs[runtime_ref_count] = ptr_value;
    runtime_ref_count += 1;
}

/// Register a callback at comptime
///
/// Returns the callback unchanged but records it for later collection.
/// This is designed to be used inline in V8Interface:
/// ```zig
/// const callback = ext_refs.comptimeRegister(myCallback, "MyInterface.myMethod");
/// ```
pub inline fn comptimeRegister(
    comptime callback: v8.FunctionCallback,
    comptime _: []const u8, // name for debugging
) v8.FunctionCallback {
    // At comptime, we just return the callback
    // The actual collection happens via collectInterfaceCallbacks
    return callback;
}

/// Get the current count of runtime-registered references
pub fn getRuntimeCount() usize {
    return runtime_ref_count;
}

/// Get runtime external references array (null-terminated)
pub fn getRuntimeExternalReferences() []const isize {
    runtime_refs[runtime_ref_count] = 0; // null-terminate
    return runtime_refs[0 .. runtime_ref_count + 1];
}

/// Get a raw pointer to runtime external references
pub fn getRuntimeExternalReferencesPtr() [*]const isize {
    runtime_refs[runtime_ref_count] = 0;
    return &runtime_refs;
}

/// Clear all runtime registrations (for testing)
pub fn clearRuntimeReferences() void {
    runtime_ref_count = 0;
}

/// Verify that a callback is registered at runtime
pub fn isRegisteredRuntime(callback: v8.FunctionCallback) bool {
    const ptr_value: isize = @intCast(@intFromPtr(callback));
    for (runtime_refs[0..runtime_ref_count]) |ref| {
        if (ref == ptr_value) return true;
    }
    return false;
}

/// Print all runtime-registered external references (for debugging)
pub fn debugPrintRuntimeReferences() void {
    std.debug.print("Runtime External References ({d} total):\n", .{runtime_ref_count});
    for (runtime_refs[0..runtime_ref_count], 0..) |ref, i| {
        std.debug.print("  [{d}] 0x{x}\n", .{ i, @as(usize, @intCast(ref)) });
    }
}

// ============================================================================
// Comptime Collection (future implementation)
// ============================================================================
//
// The ideal approach is to collect ALL callbacks at comptime by iterating
// over all interfaces. This would look like:
//
// pub fn getAllExternalReferences() []const isize {
//     comptime {
//         var refs: [MAX_EXTERNAL_REFS]isize = undefined;
//         var count: usize = 0;
//
//         // Iterate over all interfaces
//         const interfaces = @import("interfaces");
//         const decls = @typeInfo(interfaces).@"struct".decls;
//         inline for (decls) |decl| {
//             const InterfaceType = @field(interfaces, decl.name);
//             if (@hasDecl(InterfaceType, "Meta")) {
//                 const V8Binding = @import("interface.zig").V8Interface(InterfaceType);
//                 const interface_callbacks = V8Binding.getCallbacks();
//                 for (interface_callbacks) |cb| {
//                     refs[count] = @intCast(@intFromPtr(cb));
//                     count += 1;
//                 }
//             }
//         }
//
//         refs[count] = 0; // null-terminate
//         return refs[0..count + 1];
//     }
// }
//
// This requires V8Interface to expose a getCallbacks() function that returns
// all callbacks for that interface. See interface.zig for implementation.

// ============================================================================
// Tests
// ============================================================================

test "external references - runtime registration" {
    clearRuntimeReferences();

    // Register some callbacks
    const dummy1: v8.FunctionCallback = @ptrFromInt(0x1000);
    const dummy2: v8.FunctionCallback = @ptrFromInt(0x2000);

    registerCallbackRuntime(dummy1);
    registerCallbackRuntime(dummy2);

    try std.testing.expectEqual(@as(usize, 2), getRuntimeCount());
    try std.testing.expect(isRegisteredRuntime(dummy1));
    try std.testing.expect(isRegisteredRuntime(dummy2));

    // Duplicate registration should not increase count
    registerCallbackRuntime(dummy1);
    try std.testing.expectEqual(@as(usize, 2), getRuntimeCount());

    // Get references
    const refs = getRuntimeExternalReferences();
    try std.testing.expectEqual(@as(usize, 3), refs.len); // 2 refs + null terminator
    try std.testing.expectEqual(@as(isize, 0), refs[2]); // null terminated

    clearRuntimeReferences();
}

test "external references - comptimeRegister" {
    // comptimeRegister should just return the callback unchanged
    const dummy: v8.FunctionCallback = @ptrFromInt(0x3000);
    const result = comptimeRegister(dummy, "test.dummy");
    try std.testing.expectEqual(dummy, result);
}
