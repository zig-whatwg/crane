//! Implementation for StorageManager interface
//!
//! Connects WebIDL interface to Storage Standard backend at src/storage/storage_manager.zig
//!
//! Spec: https://storage.spec.whatwg.org/#storagemanager
//!
//! StorageManager provides methods for querying and managing storage persistence:
//! - persisted() - Check if storage is in persistent mode
//! - persist() - Request persistent storage
//! - estimate() - Get storage usage and quota estimates
//! - getDirectory() - Get the origin-private file system root

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const StorageManagerInterface = interfaces.StorageManager;

// Backend imports
const storage = @import("storage");
const BackendStorageManager = storage.storage_manager.StorageManager;

pub const State = StorageManagerInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    SecurityError,
};

/// Internal state for StorageManager
///
/// Stores the backend StorageManager instance that manages storage operations.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend storage manager
    manager: *BackendStorageManager,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.manager.deinit();
        allocator.destroy(self.manager);
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);

    // Create internal state
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;

    // Create backend storage manager
    internal.manager = try allocator.create(BackendStorageManager);
    errdefer allocator.destroy(internal.manager);

    // Initialize with default origin
    // TODO: Get origin from runtime context
    internal.manager.* = try BackendStorageManager.init(allocator, "default-origin");

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Operation: getDirectory
///
/// Returns the root directory of the origin-private file system.
///
/// Spec: https://fs.spec.whatwg.org/#dom-storagemanager-getdirectory
///
/// Note: This requires the File System Access API which is not yet implemented.
pub fn call_getDirectory(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    // TODO: Implement File System Access API integration
    // Returns Promise<FileSystemDirectoryHandle>
    return error.InvalidState; // Not implemented
}

/// Operation: persist
///
/// Requests persistent storage for the origin.
///
/// Spec: https://storage.spec.whatwg.org/#dom-storagemanager-persist
///
/// Returns a Promise that resolves to true if persistence was granted.
pub fn call_persist(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const result = internal.manager.persist() catch {
        return error.SecurityError;
    };

    // TODO: Convert bool result to Promise<boolean>
    _ = result;
    return error.InvalidState; // Placeholder until Promise integration
}

/// Operation: estimate
///
/// Returns storage usage and quota estimates.
///
/// Spec: https://storage.spec.whatwg.org/#dom-storagemanager-estimate
///
/// Returns a Promise that resolves to a StorageEstimate dictionary.
pub fn call_estimate(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const estimate = internal.manager.estimate() catch {
        return error.SecurityError;
    };

    // TODO: Convert StorageEstimate to Promise<StorageEstimate>
    _ = estimate;
    return error.InvalidState; // Placeholder until Promise integration
}

/// Operation: persisted
///
/// Checks if storage is currently in persistent mode.
///
/// Spec: https://storage.spec.whatwg.org/#dom-storagemanager-persisted
///
/// Returns a Promise that resolves to true if storage is persistent.
pub fn call_persisted(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const result = internal.manager.persisted() catch {
        return error.SecurityError;
    };

    // TODO: Convert bool result to Promise<boolean>
    _ = result;
    return error.InvalidState; // Placeholder until Promise integration
}
