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
    defer allocator.free(snapshot_data);

    const bytes_read = file.readAll(snapshot_data) catch |err| {
        if (log_performance) {
            std.log.warn("Failed to read snapshot file: {}", .{err});
        }
        return null;
    };

    if (bytes_read != stat.size) {
        if (log_performance) {
            std.log.warn("Incomplete snapshot file read: {d}/{d} bytes", .{ bytes_read, stat.size });
        }
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
    const zig_callbacks = @import("zig_callbacks.zig");
    ext_refs.registerCallbackRuntime(zig_callbacks.genericZigCallback);

    // Note: Interface-specific callbacks are registered dynamically when
    // interface_bindings.initializeBindings() is called. For snapshot loading,
    // these callbacks must have been registered in the same order during
    // snapshot creation.
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
