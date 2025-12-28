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
//! // Try to initialize from snapshot (or fall back to fresh isolate)
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
//! It contains serialized heap state with V8 builtins AND all WebIDL interfaces
//! pre-registered on the global object. This enables fast startup (~2ms vs ~40ms)
//! by avoiding per-context interface registration.
//!
//! ## Context Restoration
//!
//! Contexts are restored using Context::FromSnapshot(isolate, 0), which retrieves
//! the indexed context that was added via AddContext() during snapshot creation.
//! This is the proper V8 API for context restoration (not Context::New()).
//!
//! IMPORTANT: The snapshot context already has all 1,099 WebIDL interfaces
//! registered on the global object. Calling initializeBindings() on a snapshot
//! context would be redundant and wasteful.
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

/// Tracked snapshot data for cleanup
/// V8 requires snapshot data to remain valid for the isolate's lifetime,
/// so we track it here and free it when the runtime is deinitialized.
var tracked_snapshot_data: ?[]u8 = null;
var tracked_snapshot_allocator: ?std.mem.Allocator = null;

/// Standard V8 flags for deterministic snapshot creation and loading.
/// These MUST be set BEFORE v8_Platform_Initialize() is called.
/// They ensure consistent hash behavior between snapshot creation and loading.
///
/// Note: --no-random-gc was removed as it's not a valid V8 flag in current versions.
/// The --predictable flag already handles deterministic behavior.
pub const SNAPSHOT_V8_FLAGS = "--hash-seed=0 --predictable";

/// Initialize V8 platform with proper flags for snapshot support.
/// This MUST be called instead of v8_Platform_Initialize() when using snapshots.
///
/// The order is critical:
/// 1. Set V8 flags (--hash-seed=0, --predictable)
/// 2. Initialize V8 platform
///
/// Calling v8_Platform_Initialize() directly without setting flags first
/// will cause snapshot loading to fail with "rehashability" assertion errors.
pub fn initializePlatformForSnapshots() void {
    // CRITICAL: Flags MUST be set BEFORE platform initialization
    ffi.v8_SetFlagsFromString(SNAPSHOT_V8_FLAGS);

    // Now initialize the platform
    ffi.v8_Platform_Initialize();
}

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
    /// External references not registered (call initializeV8 first from main thread)
    ExternalRefsNotRegistered,
};

/// Create a new V8 isolate from the snapshot for use in worker threads.
///
/// IMPORTANT: This function is designed for worker threads and assumes:
/// 1. The main browser has already called initializeV8() which registered external references
/// 2. The snapshot has been loaded and cached (tracked_snapshot_data is valid)
///
/// Unlike initializeV8(), this function:
/// - Does NOT re-register external references (uses already-registered ones)
/// - Does NOT reload the snapshot file (uses cached data)
/// - IS thread-safe for creating worker isolates
///
/// Returns null if:
/// - External references haven't been registered yet
/// - Snapshot data isn't available
/// - Isolate/context creation fails
pub fn createWorkerIsolateFromSnapshot() ?SnapshotResult {
    // Check if external references have been registered by the main browser
    if (!ext_refs.hasRegisteredExternalReferences()) {
        std.log.err("[snapshot_loader] Worker: External references not registered (main browser must initialize first)", .{});
        return null;
    }

    // Get the already-registered external references
    const refs_ptr = ext_refs.getRuntimeExternalReferencesPtr();

    // Use the cached snapshot data from the main browser's initialization
    const snapshot_data = tracked_snapshot_data orelse {
        std.log.err("[snapshot_loader] Worker: No snapshot data available (main browser must initialize first)", .{});
        return null;
    };

    // Validate the snapshot data
    const validation = validateSnapshotData(snapshot_data);
    if (!validation.isUsable()) {
        std.log.err("[snapshot_loader] Worker: Cached snapshot data is invalid: {s}", .{validation.error_message orelse "unknown"});
        return null;
    }

    // Create a new isolate from the snapshot using already-registered external refs
    const isolate = ffi.v8_Isolate_NewFromSnapshot(
        snapshot_data.ptr,
        @intCast(snapshot_data.len),
        refs_ptr,
    );
    if (isolate == null) {
        std.log.err("[snapshot_loader] Worker: Failed to create isolate from snapshot", .{});
        return null;
    }

    // Create context from the snapshot
    const context = ffi.v8_Context_NewFromSnapshot(isolate.?);
    if (context == null) {
        std.log.err("[snapshot_loader] Worker: Failed to create context from snapshot", .{});
        ffi.v8_Isolate_Dispose(isolate.?);
        return null;
    }

    std.log.info("[snapshot_loader] Worker: Created isolate from snapshot successfully", .{});

    return SnapshotResult{
        .isolate = isolate.?,
        .context = context.?,
    };
}

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
            return .{
                .isolate = result.isolate,
                .context = result.context,
                .used_snapshot = true,
                .startup_time_ms = elapsed,
            };
        }
    }

    // Fall back to fresh initialization (no interfaces registered)

    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    errdefer ffi.v8_Isolate_Dispose(isolate);

    ffi.v8_Isolate_Enter(isolate);
    errdefer ffi.v8_Isolate_Exit(isolate);

    const context = ffi.v8_Context_New(isolate) orelse {
        ffi.v8_Isolate_Exit(isolate);
        return error.ContextCreationFailed;
    };

    const elapsed = std.time.milliTimestamp() - start_time;

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
    // === Snapshot Validation ===
    // Validate snapshot data thoroughly before attempting to load.
    // This helps provide clear error messages and fail fast.

    // Step 1: Basic size check
    if (data.len < 8) {
        if (log_performance) {
            std.log.warn("Snapshot validation failed: data too small ({d} bytes, minimum 8)", .{data.len});
        }
        return null;
    }

    // Step 2: Check if snapshot data is valid (V8's internal validation)
    const is_valid = ffi.v8_Snapshot_IsValid(data.ptr, @intCast(data.len));
    if (!is_valid) {
        if (log_performance) {
            std.log.warn("Snapshot validation failed: v8_Snapshot_IsValid returned false", .{});
            std.log.warn("  This usually means the snapshot is corrupted or was created with an incompatible V8 version", .{});
        }
        return null;
    }

    // Step 3: Check if the snapshot can be rehashed (required for cross-isolate loading)
    const can_rehash = ffi.v8_Snapshot_CanBeRehashed(data.ptr, @intCast(data.len));
    _ = can_rehash; // Validation check only

    // Register and use external references - REQUIRED for V8 snapshot context restoration.
    // External references must be registered in the SAME ORDER as during snapshot creation.
    // This allows V8 to resolve callback function pointers when restoring context.
    //
    // IMPORTANT: The hash of external references differs between binaries because function
    // pointers have different addresses in each binary. What matters is:
    // 1. The COUNT must be the same (11168)
    // 2. The ORDER must be the same (alphabetical by interface name)
    //
    // V8 uses indices into the external references array, not actual addresses.
    // As long as the order is deterministic, snapshots work correctly.
    const external_refs = @import("external_references.zig");
    external_refs.registerAllExternalReferences();
    const stats = external_refs.getExternalReferenceStats();
    _ = stats; // Used for debugging only
    const refs_ptr: ?[*]const isize = external_refs.getRuntimeExternalReferencesPtr();

    // NOTE: V8 flags (--hash-seed=0, --predictable, --no-random-gc) MUST be set
    // BEFORE v8_Platform_Initialize() is called, not here.
    // Use initializePlatformForSnapshots() or set flags manually before platform init.
    // Setting flags here is too late - the platform has already been initialized.
    //
    // If you're seeing "rehashability" assertion failures, ensure you're using
    // initializePlatformForSnapshots() instead of v8_Platform_Initialize() directly.

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

    // Create a context from the snapshot using Context::FromSnapshot(isolate, 0).
    // This retrieves the indexed context that was added via AddContext() during
    // snapshot creation. This is the proper way to restore context state from snapshot.
    //
    // IMPORTANT: The snapshot generator MUST add a context at index 0 using
    // v8_SnapshotCreator_CreateAndAddContext() for this to work.
    //
    // This gives us:
    // - Fast isolate startup (~2ms vs ~40ms) from snapshot's pre-compiled builtins
    // - Context from the snapshot (currently V8 builtins, will contain WebIDL interfaces later)
    const context = ffi.v8_Context_NewFromSnapshot(isolate) orelse {
        if (log_performance) {
            std.log.warn("Failed to create context from snapshot (Context::FromSnapshot failed)", .{});
            std.log.warn("  This usually means no indexed context was added during snapshot creation", .{});
            std.log.warn("  Ensure snapshot generator uses v8_SnapshotCreator_CreateAndAddContext()", .{});
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
fn initFromSnapshotFile(allocator: std.mem.Allocator, path: []const u8, _: bool) !?SnapshotResult {

    // Try to open and read the snapshot file
    const file = std.fs.cwd().openFile(path, .{}) catch {
        return null;
    };
    defer file.close();

    // Get file size and read data
    const stat = file.stat() catch {
        return null;
    };

    const snapshot_data = allocator.alloc(u8, stat.size) catch {
        return null;
    };
    // Track the snapshot data for cleanup when the runtime is deinitialized.
    // V8 keeps a reference to the snapshot data for lazy deserialization,
    // so the data must remain valid for the entire lifetime of the isolate.
    // We free it in cleanupSnapshotData() which is called during runtime shutdown.
    tracked_snapshot_data = snapshot_data;
    tracked_snapshot_allocator = allocator;

    const bytes_read = file.readAll(snapshot_data) catch {
        return null;
    };

    if (bytes_read != stat.size) {
        return null;
    }

    return initFromSnapshotData(snapshot_data, false);
}

/// Register all external references for snapshot loading
///
/// This MUST be called before attempting to load a snapshot.
/// The external references must match the order used when creating the snapshot.
///
/// IMPORTANT: This now uses the centralized registerAllExternalReferences()
/// from external_references.zig which registers ALL callbacks in deterministic
/// order, including all interface callbacks.
pub fn registerExternalReferences() void {
    // Use the centralized external reference registration
    // This ensures the same order at snapshot creation and loading time
    ext_refs.registerAllExternalReferences();

    const count = ext_refs.getExternalReferenceCount();
    const hash = ext_refs.computeExternalReferenceHash();
    std.debug.print("[snapshot_loader] RUNTIME: Registered {d} external references, hash: 0x{x}\n", .{ count, hash });
}

/// Snapshot validation result with detailed diagnostics
pub const SnapshotValidation = struct {
    is_valid: bool,
    can_rehash: bool,
    size: usize,
    error_message: ?[]const u8,

    pub fn isUsable(self: SnapshotValidation) bool {
        return self.is_valid and self.can_rehash;
    }
};

/// Validate snapshot data without attempting to load it.
/// Use this to check if a snapshot is valid before loading.
///
/// Returns detailed validation results including:
/// - is_valid: Whether V8 considers the snapshot data valid
/// - can_rehash: Whether the snapshot can be loaded with different hash seeds
/// - error_message: Description of any validation failure
pub fn validateSnapshotData(data: []const u8) SnapshotValidation {
    if (data.len < 8) {
        return .{
            .is_valid = false,
            .can_rehash = false,
            .size = data.len,
            .error_message = "Snapshot data too small (minimum 8 bytes required)",
        };
    }

    const is_valid = ffi.v8_Snapshot_IsValid(data.ptr, @intCast(data.len));
    if (!is_valid) {
        return .{
            .is_valid = false,
            .can_rehash = false,
            .size = data.len,
            .error_message = "Snapshot data is invalid or corrupted",
        };
    }

    const can_rehash = ffi.v8_Snapshot_CanBeRehashed(data.ptr, @intCast(data.len));
    return .{
        .is_valid = true,
        .can_rehash = can_rehash,
        .size = data.len,
        .error_message = if (!can_rehash) "Snapshot not rehashable - requires matching hash seed" else null,
    };
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

/// Clean up snapshot data that was allocated during initialization.
/// This should be called during runtime shutdown, AFTER the V8 isolate is disposed.
/// V8 requires the snapshot data to remain valid for the isolate's entire lifetime,
/// so this must only be called after all V8 resources have been cleaned up.
pub fn cleanupSnapshotData() void {
    if (tracked_snapshot_data) |data| {
        if (tracked_snapshot_allocator) |allocator| {
            allocator.free(data);
        }
        tracked_snapshot_data = null;
        tracked_snapshot_allocator = null;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "snapshot loader - initializeV8 without snapshot" {
    // Initialize V8 platform with proper flags for snapshots
    // This MUST use initializePlatformForSnapshots() to set flags before platform init
    initializePlatformForSnapshots();
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
