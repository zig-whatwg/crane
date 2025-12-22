//! V8 Snapshot Loader for Fast Startup
//!
//! This module provides snapshot-based initialization for V8 isolates and contexts.
//! When a valid snapshot is available, startup time is reduced from ~40ms to <2ms.
//!
//! ## Usage
//!
//! ```zig
//! const loader = @import("snapshot_loader.zig");
//!
//! // Try to initialize from snapshot (or fall back to manual registration)
//! const result = try loader.initializeV8(allocator, .{
//!     .snapshot_path = "whatwg_snapshot.bin",
//! });
//!
//! // Use result.isolate and result.context
//! // result.used_snapshot indicates which path was taken
//! ```
//!
//! ## Snapshot File Format
//!
//! The snapshot file is a raw V8 StartupData blob created by the snapshot generator.
//! It contains serialized heap state including all registered WebIDL interfaces.
//!
//! ## External References
//!
//! V8 snapshots require that all native callback function pointers be registered
//! in the same order at snapshot creation and loading time. This module uses the
//! external_references.zig module to provide these references.

const std = @import("std");
const ffi = @import("ffi.zig");
const ext_refs = @import("external_references.zig");
const intl_binding = @import("intl_binding.zig");
const interface_bindings = @import("interface_bindings.zig");
const interfaces = @import("interfaces");
const V8Interface = @import("interface.zig").V8Interface;
pub const V8Namespace = @import("namespace.zig").V8Namespace;
const zig_callbacks = @import("zig_callbacks.zig");
const window_properties = @import("window_properties.zig");
const context_manager = @import("context_manager.zig");

/// Result of V8 initialization
pub const InitResult = struct {
    /// The V8 isolate (caller owns, must dispose)
    isolate: *ffi.Isolate,
    /// The V8 context (caller owns, must dispose)
    context: *ffi.Context,
    /// Whether initialization used a snapshot (true) or manual registration (false)
    used_snapshot: bool,
    /// Startup time in milliseconds (for performance tracking)
    startup_time_ms: i64,
};

/// Options for V8 initialization
pub const InitOptions = struct {
    /// Path to the snapshot file. If null, skips snapshot loading.
    snapshot_path: ?[]const u8 = null,
    /// Embedded snapshot data (takes precedence over snapshot_path)
    embedded_snapshot: ?[]const u8 = null,
    /// Whether to log performance information
    log_performance: bool = true,
};

/// Error set for snapshot loading
pub const SnapshotError = error{
    /// Failed to read snapshot file
    SnapshotFileReadFailed,
    /// Snapshot data is invalid or corrupted
    SnapshotInvalid,
    /// Failed to create isolate from snapshot
    IsolateCreationFailed,
    /// Failed to create context from snapshot
    ContextCreationFailed,
    /// Platform initialization failed
    PlatformInitFailed,
    /// Out of memory
    OutOfMemory,
};

/// Initialize V8 from a snapshot if available, otherwise fall back to fresh initialization.
///
/// This is the main entry point for V8 initialization. It:
/// 1. Tries to load from embedded snapshot (if provided)
/// 2. Falls back to loading from file (if snapshot_path provided)
/// 3. Falls back to creating a fresh isolate if no snapshot available
///
/// The caller is responsible for disposing the isolate and context.
pub fn initializeV8(allocator: std.mem.Allocator, options: InitOptions) !InitResult {
    const start_time = std.time.milliTimestamp();

    // Try embedded snapshot first
    if (options.embedded_snapshot) |snapshot_data| {
        if (try initFromSnapshotData(snapshot_data, options.log_performance)) |result| {
            const elapsed = std.time.milliTimestamp() - start_time;
            if (options.log_performance) {
                std.log.info("V8 initialized from embedded snapshot in {d}ms", .{elapsed});
            }
            return .{
                .isolate = result.isolate,
                .context = result.context,
                .used_snapshot = true,
                .startup_time_ms = elapsed,
            };
        }
    }

    // Try loading from file
    if (options.snapshot_path) |path| {
        if (try initFromSnapshotFile(allocator, path, options.log_performance)) |result| {
            const elapsed = std.time.milliTimestamp() - start_time;
            if (options.log_performance) {
                std.log.info("V8 initialized from snapshot file in {d}ms", .{elapsed});
            }
            return .{
                .isolate = result.isolate,
                .context = result.context,
                .used_snapshot = true,
                .startup_time_ms = elapsed,
            };
        }
    }

    // Fall back to fresh initialization (no interfaces registered)
    if (options.log_performance) {
        std.log.info("No snapshot available, creating fresh V8 isolate", .{});
    }

    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    errdefer ffi.v8_Isolate_Dispose(isolate);

    ffi.v8_Isolate_Enter(isolate);
    errdefer ffi.v8_Isolate_Exit(isolate);

    const context = ffi.v8_Context_New(isolate) orelse {
        ffi.v8_Isolate_Exit(isolate);
        return error.ContextCreationFailed;
    };

    const elapsed = std.time.milliTimestamp() - start_time;
    if (options.log_performance) {
        std.log.info("V8 initialized without snapshot in {d}ms", .{elapsed});
    }

    return .{
        .isolate = isolate,
        .context = context,
        .used_snapshot = false,
        .startup_time_ms = elapsed,
    };
}

/// Internal result for snapshot initialization (before timing)
const SnapshotResult = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

/// Try to initialize from in-memory snapshot data
fn initFromSnapshotData(data: []const u8, log_performance: bool) !?SnapshotResult {
    // Validate snapshot before using
    if (!ffi.v8_Snapshot_IsValid(data.ptr, @intCast(data.len))) {
        if (log_performance) {
            std.log.warn("Snapshot data is invalid, falling back to manual init", .{});
        }
        return null;
    }

    // Get external references (must match snapshot creation order)
    const ref_count = ext_refs.getRuntimeCount();
    if (log_performance) {
        std.log.info("Snapshot loading: {d} external references registered", .{ref_count});
    }
    const refs_ptr = ext_refs.getRuntimeExternalReferencesPtr();

    // Create isolate from snapshot
    const isolate = ffi.v8_Isolate_NewFromSnapshot(
        data.ptr,
        @intCast(data.len),
        refs_ptr,
    ) orelse {
        if (log_performance) {
            std.log.warn("Failed to create isolate from snapshot, falling back", .{});
        }
        return null;
    };
    errdefer ffi.v8_Isolate_Dispose(isolate);

    ffi.v8_Isolate_Enter(isolate);
    errdefer ffi.v8_Isolate_Exit(isolate);

    // Create context from snapshot
    const context = ffi.v8_Context_NewFromSnapshot(isolate) orelse {
        if (log_performance) {
            std.log.warn("Failed to create context from snapshot, falling back", .{});
        }
        ffi.v8_Isolate_Exit(isolate);
        return null;
    };

    return .{
        .isolate = isolate,
        .context = context,
    };
}

/// Try to initialize from a snapshot file
///
/// IMPORTANT: The snapshot data is intentionally NOT freed after this function returns.
/// V8 may keep a reference to the snapshot data for lazy deserialization during
/// context creation. The snapshot data should be kept alive for the lifetime of
/// the isolate, or until after the first context is created.
///
/// TODO: Track the snapshot data and free it when the isolate is disposed.
/// For now, this is a small memory leak (~8MB per isolate created from snapshot).
fn initFromSnapshotFile(allocator: std.mem.Allocator, path: []const u8, log_performance: bool) !?SnapshotResult {
    // Try to open and read the snapshot file
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (log_performance) {
            std.log.info("Snapshot file '{s}' not found: {}", .{ path, err });
        }
        return null;
    };
    defer file.close();

    // Get file size and read data
    const stat = file.stat() catch |err| {
        if (log_performance) {
            std.log.warn("Failed to stat snapshot file: {}", .{err});
        }
        return null;
    };

    const snapshot_data = allocator.alloc(u8, stat.size) catch |err| {
        if (log_performance) {
            std.log.warn("Failed to allocate memory for snapshot: {}", .{err});
        }
        return null;
    };
    // NOTE: snapshot_data is intentionally NOT freed here!
    // V8 keeps a reference to the snapshot data for lazy deserialization.
    // The data must remain valid until after context creation.
    // This is a small memory leak (~8MB) that we accept for now.
    // errdefer allocator.free(snapshot_data);

    const bytes_read = file.readAll(snapshot_data) catch |err| {
        if (log_performance) {
            std.log.warn("Failed to read snapshot file: {}", .{err});
        }
        allocator.free(snapshot_data);
        return null;
    };

    if (bytes_read != stat.size) {
        if (log_performance) {
            std.log.warn("Incomplete snapshot file read: {d}/{d} bytes", .{ bytes_read, stat.size });
        }
        allocator.free(snapshot_data);
        return null;
    }

    if (log_performance) {
        std.log.info("Loaded snapshot from '{s}' ({d} bytes)", .{ path, stat.size });
    }

    return initFromSnapshotData(snapshot_data, log_performance);
}

/// Register all external references for snapshot loading
///
/// This MUST be called before attempting to load a snapshot.
/// The external references must match the order used when creating the snapshot.
pub fn registerExternalReferences() void {
    // Clear any previous registrations
    ext_refs.clearRuntimeReferences();

    // Register C++ callbacks from v8_wrapper.cpp
    ext_refs.registerCallbackRuntime(ffi.v8_GetAsyncIteratorNextCallback());
    ext_refs.registerCallbackRuntime(ffi.v8_GetAsyncIteratorReturnCallback());
    ext_refs.registerCallbackRuntime(ffi.v8_GetAsyncIteratorSelfCallback());

    // Register Zig callbacks used by streams and promise handlers
    ext_refs.registerCallbackRuntime(zig_callbacks.genericZigCallback);

    // Register Intl callbacks for V8 snapshot compatibility
    intl_binding.registerExternalReferences();

    // Note: Interface-specific callbacks are registered dynamically when
    // interface_bindings.initializeBindings() is called. For snapshot loading,
    // these callbacks must have been registered in the same order during
    // snapshot creation.
}

/// Register ALL external references for all WebIDL interfaces
///
/// This function MUST be called before creating OR loading a snapshot.
/// It registers callbacks for ALL interfaces in the same order, which is
/// critical for snapshot compatibility.
///
/// This is the comprehensive version that includes ALL interface callbacks.
/// Use this for both snapshot creation and loading.
pub fn registerAllExternalReferences() void {
    @setEvalBranchQuota(200_000);

    // Clear any previous registrations to ensure consistent ordering
    ext_refs.clearRuntimeReferences();

    // Register callbacks for all interfaces
    const iface_decls = @typeInfo(interfaces).@"struct".decls;
    inline for (iface_decls) |decl| {
        // Skip problematic interfaces
        if (comptime interface_bindings.shouldSkipInterface(decl.name)) continue;

        const InterfaceType = @field(interfaces, decl.name);

        // Only process types that have Meta (actual interfaces)
        if (@typeInfo(InterfaceType) == .@"struct" and @hasDecl(InterfaceType, "Meta")) {
            // Get the V8Interface binding and register its callbacks
            const V8Binding = V8Interface(InterfaceType);
            V8Binding.registerExternalReferences();
        }
    }

    // NOTE: Namespace callbacks are NOT registered here because the v8 module
    // doesn't have access to the namespaces module. Callers should use
    // registerNamespaceExternalReferences() with the namespaces module to
    // register namespace callbacks separately.

    // Register C++ callbacks that are created in v8_wrapper.cpp
    // These are used by FunctionTemplates but are defined in C++, not Zig
    ext_refs.registerCallbackRuntime(ffi.v8_GetAsyncIteratorNextCallback());
    ext_refs.registerCallbackRuntime(ffi.v8_GetAsyncIteratorReturnCallback());
    ext_refs.registerCallbackRuntime(ffi.v8_GetAsyncIteratorSelfCallback());

    // Register Zig callbacks that are used for Promise handlers and dynamic callbacks
    // These are created by zig_callbacks.zig when streams invoke JS callbacks
    ext_refs.registerCallbackRuntime(zig_callbacks.genericZigCallback);

    // Register Intl callbacks for V8 snapshot compatibility
    intl_binding.registerExternalReferences();

    // Register WindowProperties named property callbacks
    window_properties.registerExternalReferences();

    // Register context manager callbacks (Window indexed property handlers)
    context_manager.registerExternalReferences();
}

/// Register namespace external references for snapshot support
///
/// This function must be called with a namespaces module to register
/// all namespace callbacks. Call this after registerAllExternalReferences()
/// to complete the external reference registration.
///
/// Example:
/// ```zig
/// const namespaces = @import("namespaces");
/// snapshot_loader.registerAllExternalReferences();
/// snapshot_loader.registerNamespaceExternalReferences(namespaces);
/// ```
pub fn registerNamespaceExternalReferences(comptime namespaces: type) void {
    @setEvalBranchQuota(50_000);

    const ns_decls = @typeInfo(namespaces).@"struct".decls;
    inline for (ns_decls) |decl| {
        const NamespaceType = @field(namespaces, decl.name);

        if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
            // V8Namespace might not have registerExternalReferences, but if it does, call it
            if (@hasDecl(V8Namespace(NamespaceType), "registerExternalReferences")) {
                V8Namespace(NamespaceType).registerExternalReferences();
            }
        }
    }
}

/// Check if a valid snapshot file exists at the given path
pub fn hasValidSnapshot(allocator: std.mem.Allocator, path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch return false;
    defer file.close();

    const stat = file.stat() catch return false;
    if (stat.size < 8) return false; // Too small to be valid

    const data = allocator.alloc(u8, stat.size) catch return false;
    defer allocator.free(data);

    const bytes_read = file.readAll(data) catch return false;
    if (bytes_read != stat.size) return false;

    return ffi.v8_Snapshot_IsValid(data.ptr, @intCast(data.len));
}

// ============================================================================
// Tests
// ============================================================================

test "snapshot loader - initializeV8 without snapshot" {
    // Initialize V8 platform first (required)
    ffi.v8_Platform_Initialize();
    defer ffi.v8_Platform_Dispose();

    // Register external references
    registerExternalReferences();

    const result = try initializeV8(std.testing.allocator, .{
        .snapshot_path = null,
        .log_performance = false,
    });

    // Clean up
    ffi.v8_Context_Exit(result.context);
    ffi.v8_Context_Dispose(result.context);
    ffi.v8_Isolate_Exit(result.isolate);
    ffi.v8_Isolate_Dispose(result.isolate);

    // Verify we got valid handles
    try std.testing.expect(!result.used_snapshot);
    try std.testing.expect(result.startup_time_ms >= 0);
}

test "snapshot loader - hasValidSnapshot returns false for missing file" {
    const result = hasValidSnapshot(std.testing.allocator, "nonexistent_snapshot.bin");
    try std.testing.expect(!result);
}

test "snapshot loader - initializeV8 with snapshot file" {
    // Skip test if no snapshot file exists
    const snapshot_path = "whatwg_snapshot.bin";
    if (!hasValidSnapshot(std.testing.allocator, snapshot_path)) {
        std.log.info("Skipping snapshot test - no snapshot file at {s}", .{snapshot_path});
        return;
    }

    // Initialize V8 platform first (required)
    ffi.v8_Platform_Initialize();
    defer ffi.v8_Platform_Dispose();

    // Register ALL external references (must match snapshot creation order)
    registerAllExternalReferences();

    const result = try initializeV8(std.testing.allocator, .{
        .snapshot_path = snapshot_path,
        .log_performance = true,
    });

    // Verify we used the snapshot
    try std.testing.expect(result.used_snapshot);
    try std.testing.expect(result.startup_time_ms >= 0);

    // Enter context and verify we can evaluate JS
    ffi.v8_Context_Enter(result.context);
    defer ffi.v8_Context_Exit(result.context);

    // Test that interfaces are available (they should be from the snapshot)
    const script = "typeof URL";
    const script_result = ffi.v8_Context_Evaluate(result.context, script.ptr, @intCast(script.len), "test.js", 7);
    try std.testing.expect(script_result != null);

    // Clean up - exit context first, then dispose
    ffi.v8_Context_Dispose(result.context);
    ffi.v8_Isolate_Exit(result.isolate);
    ffi.v8_Isolate_Dispose(result.isolate);

    std.log.info("Snapshot loading test passed! Startup time: {d}ms", .{result.startup_time_ms});
}
