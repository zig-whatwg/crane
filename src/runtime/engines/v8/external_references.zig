//! V8 External References Registry for Snapshot Support
//!
//! This module collects all FunctionCallback pointers used by V8 interface bindings.
//! These external references are REQUIRED for V8 snapshots to work correctly.
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
//! ## Critical Requirement: Deterministic Ordering
//!
//! The external references array MUST:
//! 1. Contain ALL callback pointers used in interface bindings
//! 2. Be in the SAME ORDER at snapshot creation and loading time
//! 3. Be null-terminated
//!
//! If any callback is missing or in a different order, V8 will crash when loading
//! the snapshot because it cannot resolve the callback addresses.
//!
//! ## Determinism Guarantees
//!
//! This implementation provides deterministic ordering through:
//!
//! 1. **Interface Order**: Interfaces are processed in declaration order from the
//!    `interfaces` module, which is alphabetical (as defined in root.zig).
//!
//! 2. **Callback Order**: Within each interface, callbacks are registered in a
//!    fixed order: constructor → property getters → property setters → methods →
//!    static methods → iterator callbacks → property handlers.
//!
//! 3. **Fixed Prefix**: Core callbacks (async iterators, Zig callbacks, Intl, etc.)
//!    are always registered first in a fixed order.
//!
//! The resulting array has ~11,168 callbacks for ~1,099 interfaces, consistently
//! ordered across builds.
//!
//! ## Hash Verification
//!
//! Use `computeExternalReferenceHash()` to compute a hash of the external reference
//! array for debugging. Note that the hash will differ between binaries (snapshot
//! generator vs. runtime) because function pointers have different addresses.
//! However, the ORDER is deterministic, which is what V8 requires.
//!
//! ## Usage
//!
//! When creating a snapshot:
//! ```zig
//! external_references.registerAllExternalReferences();
//! const refs = external_references.getRuntimeExternalReferencesPtr();
//! const creator = v8.v8_SnapshotCreator_New(refs);
//! ```
//!
//! When loading a snapshot:
//! ```zig
//! external_references.registerAllExternalReferences();
//! const refs = external_references.getRuntimeExternalReferencesPtr();
//! const isolate = v8.v8_Isolate_NewFromSnapshot(data, size, refs);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");

/// Registration context types for tracking which part of an interface is being registered
pub const RegistrationContextType = enum {
    interface_constructor,
    interface_property_getter,
    interface_property_setter,
    interface_method,
    interface_static_method,
    interface_iterator,
    interface_indexed_property,
    interface_named_property,
};

/// Current registration context - used for debugging and manifest tracking
var current_interface_name: []const u8 = "";
var current_context_type: RegistrationContextType = .interface_constructor;

/// Set the current registration context for manifest tracking
/// This is called before registering callbacks to track which interface/context they belong to
pub fn setRegistrationContext(interface_name: []const u8, context_type: RegistrationContextType) void {
    current_interface_name = interface_name;
    current_context_type = context_type;
}

/// Get the current registration context (for debugging)
pub fn getRegistrationContext() struct { interface_name: []const u8, context_type: RegistrationContextType } {
    return .{ .interface_name = current_interface_name, .context_type = current_context_type };
}

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

    // Debug: log first few and some key positions
    if (runtime_ref_count < 5 or runtime_ref_count == 11000 or runtime_ref_count == 11400) {
        std.debug.print("[ext_refs] Position {d}: ptr=0x{x}\n", .{ runtime_ref_count, ptr });
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

// ============================================================================
// Comptime Collection - Deterministic External Reference Collection
// ============================================================================
//
// V8 snapshots require that external references (callback pointers) be provided
// in the EXACT same order at snapshot creation and loading time.
//
// This module collects ALL callbacks at comptime in deterministic alphabetical
// order by:
// 1. Sorting interface names alphabetically
// 2. For each interface, collecting callbacks in deterministic order:
//    - Constructor callback
//    - Property getters (alphabetical)
//    - Property setters (alphabetical)
//    - Methods (alphabetical)
//    - Static methods (alphabetical)
//    - Iterator callbacks (if applicable)
//    - Property handlers (if applicable)
//
// The result is a comptime-known array that can be used at both snapshot
// creation and loading time.

/// Register all external references for all interfaces at runtime.
/// This MUST be called before snapshot creation or loading.
/// Uses runtime registration but iterates in deterministic order.
pub fn registerAllInterfaceCallbacks() void {
    @setEvalBranchQuota(50_000_000);
    const interface_bindings = @import("interface_bindings.zig");
    const interfaces = @import("interfaces");
    const V8Interface = @import("interface.zig").V8Interface;

    // Get all interface declarations - these are already in declaration order
    // which is deterministic (alphabetical in root.zig)
    const decls = @typeInfo(interfaces).@"struct".decls;

    // Register callbacks for each interface in order
    inline for (decls) |decl| {
        // Skip interfaces in the skip list
        if (comptime interface_bindings.shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        // Only process types that have Meta (actual interfaces)
        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            // Skip mixin interfaces - they don't have their own callbacks
            const is_mixin = comptime blk: {
                const Meta = InterfaceType.Meta;
                if (@hasDecl(Meta, "is_mixin")) {
                    break :blk Meta.is_mixin;
                }
                break :blk false;
            };
            if (is_mixin) continue;

            // Register all callbacks for this interface
            V8Interface(InterfaceType).registerExternalReferences();
        }
    }
}

/// Register all external references required for V8 snapshot support.
/// This includes:
/// 1. C++ callbacks from v8_wrapper.cpp
/// 2. Zig callbacks for streams/promises
/// 3. Intl callbacks
/// 4. All interface callbacks (in deterministic order)
/// 5. Namespace callbacks
/// 6. Window properties callbacks
/// 7. Context manager callbacks
var registration_call_count: usize = 0;

/// Check if external references have been registered.
/// Workers use this to verify the main browser has initialized before creating isolates.
pub fn hasRegisteredExternalReferences() bool {
    return registration_call_count > 0;
}

pub fn registerAllExternalReferences() void {
    registration_call_count += 1;
    std.debug.print("[registerAllExternalReferences] CALL #{d}\n", .{registration_call_count});

    // Clear any previous registrations to ensure clean state
    clearRuntimeReferences();

    // Register C++ callbacks from v8_wrapper.cpp
    // These MUST be registered first and in a fixed order
    registerCallbackRuntime(v8.v8_GetAsyncIteratorNextCallback());
    registerCallbackRuntime(v8.v8_GetAsyncIteratorReturnCallback());
    registerCallbackRuntime(v8.v8_GetAsyncIteratorSelfCallback());
    std.debug.print("[registerAllExternalReferences] After C++ callbacks: count={d}\n", .{runtime_ref_count});

    // Register Zig callbacks used by streams and promise handlers
    const zig_callbacks = @import("zig_callbacks.zig");
    registerCallbackRuntime(zig_callbacks.genericZigCallback);
    std.debug.print("[registerAllExternalReferences] After Zig callbacks: count={d}\n", .{runtime_ref_count});

    // Register Intl callbacks
    const intl_binding = @import("intl_binding.zig");
    intl_binding.registerExternalReferences();
    std.debug.print("[registerAllExternalReferences] After Intl: count={d}\n", .{runtime_ref_count});

    // Register window properties callbacks
    const window_properties = @import("window_properties.zig");
    window_properties.registerExternalReferences();
    std.debug.print("[registerAllExternalReferences] After window_properties: count={d}\n", .{runtime_ref_count});

    // Register context manager callbacks
    const context_manager = @import("context_manager.zig");
    context_manager.registerExternalReferences();
    std.debug.print("[registerAllExternalReferences] After context_manager: count={d}\n", .{runtime_ref_count});

    // Register all interface callbacks in deterministic order
    registerAllInterfaceCallbacks();
    std.debug.print("[registerAllExternalReferences] After interfaces: count={d}\n", .{runtime_ref_count});

    // Register namespace callbacks
    registerAllNamespaceCallbacks();
    std.debug.print("[registerAllExternalReferences] After namespaces: count={d}\n", .{runtime_ref_count});
}

/// Register callbacks for all namespaces
fn registerAllNamespaceCallbacks() void {
    @setEvalBranchQuota(10_000_000);
    const V8Namespace = @import("namespace.zig").V8Namespace;

    // Import namespaces module directly (added as build dependency to v8_mod)
    const namespaces = @import("namespaces");
    const ns_decls = @typeInfo(namespaces).@"struct".decls;

    inline for (ns_decls) |decl| {
        const NamespaceType = @field(namespaces, decl.name);
        if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
            V8Namespace(NamespaceType).registerExternalReferences();
        }
    }
}

/// Get the count of registered external references
pub fn getExternalReferenceCount() usize {
    return runtime_ref_count;
}

/// Compute a hash of the external reference array for determinism verification.
///
/// This hash can be used to verify that snapshot creation and loading use
/// the EXACT same set of external references in the EXACT same order.
///
/// Returns a 64-bit hash computed from all registered external references.
/// The hash is order-dependent - same references in different order = different hash.
///
/// Usage:
/// 1. During snapshot creation: log/store the hash
/// 2. During snapshot loading: compute hash and compare
/// 3. If hashes differ, the snapshot may crash when V8 tries to resolve callbacks
pub fn computeExternalReferenceHash() u64 {
    // Use FNV-1a hash for simplicity and determinism
    // This is fast, order-dependent, and provides good distribution
    var hash: u64 = 0xcbf29ce484222325; // FNV offset basis

    for (runtime_refs[0..runtime_ref_count]) |ref| {
        // FNV-1a: XOR then multiply
        const ref_bytes: [8]u8 = @bitCast(@as(i64, ref));
        for (ref_bytes) |byte| {
            hash ^= byte;
            hash *%= 0x100000001b3; // FNV prime
        }
    }

    return hash;
}

/// Get external reference statistics for debugging
pub const ExternalRefStats = struct {
    count: usize,
    hash: u64,
};

pub fn getExternalReferenceStats() ExternalRefStats {
    return .{
        .count = runtime_ref_count,
        .hash = computeExternalReferenceHash(),
    };
}

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

test "external references - hash determinism" {
    // Hash should be deterministic for the same set of references
    clearRuntimeReferences();

    const dummy1: v8.FunctionCallback = @ptrFromInt(0x1000);
    const dummy2: v8.FunctionCallback = @ptrFromInt(0x2000);
    const dummy3: v8.FunctionCallback = @ptrFromInt(0x3000);

    registerCallbackRuntime(dummy1);
    registerCallbackRuntime(dummy2);
    registerCallbackRuntime(dummy3);

    const hash1 = computeExternalReferenceHash();

    // Clear and re-register in same order - should get same hash
    clearRuntimeReferences();
    registerCallbackRuntime(dummy1);
    registerCallbackRuntime(dummy2);
    registerCallbackRuntime(dummy3);

    const hash2 = computeExternalReferenceHash();

    try std.testing.expectEqual(hash1, hash2);

    // Different order should give different hash
    clearRuntimeReferences();
    registerCallbackRuntime(dummy2);
    registerCallbackRuntime(dummy1);
    registerCallbackRuntime(dummy3);

    const hash3 = computeExternalReferenceHash();
    try std.testing.expect(hash1 != hash3);

    clearRuntimeReferences();
}
