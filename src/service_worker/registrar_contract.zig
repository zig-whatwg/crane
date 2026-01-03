//! ServiceWorker Registrar Contract
//!
//! This file is a STANDALONE leaf module with ZERO imports from service_worker.
//! It can be safely used as a separate module without file ownership conflicts.
//!
//! Used by:
//! - webidl/impls/ServiceWorkerContainer.zig (via sw_common module)
//! - service_worker (internally for type compatibility)
//! - Browser.zig (for wiring)

const std = @import("std");

// =============================================================================
// Types (self-contained, no external imports)
// =============================================================================

/// Worker type for service worker scripts.
pub const WorkerType = enum {
    classic,
    module,
};

/// Update via cache mode for service worker registration.
pub const UpdateViaCacheMode = enum {
    imports,
    all,
    none,
};

/// Opaque handle to a service worker registration.
/// Uses an integer ID that can be used to look up the actual registration.
pub const RegistrationHandle = struct {
    id: u64,

    pub fn isValid(self: RegistrationHandle) bool {
        return self.id != 0;
    }

    pub fn invalid() RegistrationHandle {
        return .{ .id = 0 };
    }
};

// =============================================================================
// ServiceWorkerRegistrar VTable Interface
// =============================================================================

/// Result of a registration operation.
pub const RegistrationResult = union(enum) {
    /// Registration succeeded or already exists.
    success: RegistrationHandle,
    /// Registration is pending (async operation).
    pending: RegistrationHandle,
    /// Script URL validation failed.
    invalid_script_url,
    /// Scope URL validation failed.
    invalid_scope_url,
    /// Security check failed (cross-origin, etc).
    security_error,
    /// No registrar is registered.
    not_available,
    /// Other error.
    err: []const u8,
};

/// VTable-based interface for service worker registration.
/// This allows ServiceWorkerContainer (in webidl/impls) to call into
/// service_worker/integration without creating circular dependencies.
pub const ServiceWorkerRegistrar = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Register a service worker for the given script URL.
        register: *const fn (
            self: *anyopaque,
            storage_key: []const u8,
            script_url: []const u8,
            scope: ?[]const u8,
            worker_type: WorkerType,
            update_via_cache: UpdateViaCacheMode,
        ) RegistrationResult,

        /// Get an existing registration for the given scope.
        getRegistration: *const fn (
            self: *anyopaque,
            storage_key: []const u8,
            client_url: []const u8,
        ) ?RegistrationHandle,

        /// Get all registrations for the given storage key.
        getRegistrations: *const fn (
            self: *anyopaque,
            storage_key: []const u8,
        ) []const RegistrationHandle,
    };

    /// Register a service worker.
    pub fn register(
        self: ServiceWorkerRegistrar,
        storage_key: []const u8,
        script_url: []const u8,
        scope: ?[]const u8,
        worker_type: WorkerType,
        update_via_cache: UpdateViaCacheMode,
    ) RegistrationResult {
        return self.vtable.register(self.ptr, storage_key, script_url, scope, worker_type, update_via_cache);
    }

    /// Get an existing registration.
    pub fn getRegistration(
        self: ServiceWorkerRegistrar,
        storage_key: []const u8,
        client_url: []const u8,
    ) ?RegistrationHandle {
        return self.vtable.getRegistration(self.ptr, storage_key, client_url);
    }

    /// Get all registrations.
    pub fn getRegistrations(
        self: ServiceWorkerRegistrar,
        storage_key: []const u8,
    ) []const RegistrationHandle {
        return self.vtable.getRegistrations(self.ptr, storage_key);
    }

    /// Create a ServiceWorkerRegistrar from a concrete implementation type.
    pub fn create(comptime T: type, impl: *T) ServiceWorkerRegistrar {
        return .{
            .ptr = @ptrCast(impl),
            .vtable = &.{
                .register = struct {
                    fn call(
                        ptr: *anyopaque,
                        storage_key: []const u8,
                        script_url: []const u8,
                        scope: ?[]const u8,
                        worker_type: WorkerType,
                        update_via_cache: UpdateViaCacheMode,
                    ) RegistrationResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.register(storage_key, script_url, scope, worker_type, update_via_cache);
                    }
                }.call,
                .getRegistration = struct {
                    fn call(ptr: *anyopaque, storage_key: []const u8, client_url: []const u8) ?RegistrationHandle {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.getRegistration(storage_key, client_url);
                    }
                }.call,
                .getRegistrations = struct {
                    fn call(ptr: *anyopaque, storage_key: []const u8) []const RegistrationHandle {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.getRegistrations(storage_key);
                    }
                }.call,
            },
        };
    }
};

// =============================================================================
// ServiceWorkerRegistrar Registry (Global Singleton)
// =============================================================================

/// Global registry for the active ServiceWorkerRegistrar.
/// Thread-safe via atomic operations.
pub const registrar_registry = struct {
    var g_registrar: std.atomic.Value(?*const ServiceWorkerRegistrar) = .{ .raw = null };

    /// Register a ServiceWorkerRegistrar instance.
    pub fn register(registrar: *const ServiceWorkerRegistrar) void {
        g_registrar.store(registrar, .release);
    }

    /// Unregister the current registrar.
    pub fn unregister() void {
        g_registrar.store(null, .release);
    }

    /// Get the registered ServiceWorkerRegistrar, if any.
    pub fn get() ?ServiceWorkerRegistrar {
        if (g_registrar.load(.acquire)) |ptr| {
            return ptr.*;
        }
        return null;
    }

    /// Check if a registrar is registered.
    pub fn isRegistered() bool {
        return g_registrar.load(.acquire) != null;
    }

    /// Reset for testing.
    pub fn resetForTesting() void {
        g_registrar.store(null, .release);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "RegistrationHandle validity" {
    const valid = RegistrationHandle{ .id = 123 };
    try std.testing.expect(valid.isValid());

    const invalid = RegistrationHandle.invalid();
    try std.testing.expect(!invalid.isValid());
}

test "registrar_registry operations" {
    // Ensure clean state
    registrar_registry.resetForTesting();
    defer registrar_registry.resetForTesting();

    try std.testing.expect(!registrar_registry.isRegistered());
    try std.testing.expect(registrar_registry.get() == null);
}
