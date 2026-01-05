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

/// Opaque handle to a service worker instance.
pub const ServiceWorkerHandle = u64;

// =============================================================================
// RunContext VTable Interface (for execution layer callbacks)
// =============================================================================

/// Information about a job to be executed.
pub const JobInfo = struct {
    script_url: []const u8,
    scope_url: []const u8,
    worker_type: WorkerType = .classic,
    update_via_cache: UpdateViaCacheMode = .imports,
};

/// Result of a job execution.
pub const JobResult = struct {
    success: bool,
    value: ?*anyopaque = null,
};

/// VTable-based interface for service worker execution.
/// The browser layer implements this to handle actual V8/GlobalScope work.
/// The scheduling layer (algorithms/) calls these without importing V8.
pub const RunContext = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Called when a register job needs to execute.
        on_register: ?*const fn (self: *anyopaque, job: JobInfo) JobResult = null,
        /// Called when an update job needs to execute.
        on_update: ?*const fn (self: *anyopaque, job: JobInfo) JobResult = null,
        /// Called when an unregister job needs to execute.
        on_unregister: ?*const fn (self: *anyopaque, job: JobInfo) JobResult = null,
        /// Called when a service worker needs to be terminated.
        on_terminate: ?*const fn (self: *anyopaque, worker: ServiceWorkerHandle) void = null,
        /// Called when the install event should fire.
        on_install: ?*const fn (self: *anyopaque, worker: ServiceWorkerHandle) JobResult = null,
        /// Called when the activate event should fire.
        on_activate: ?*const fn (self: *anyopaque, worker: ServiceWorkerHandle) JobResult = null,
    };

    /// Execute a register job.
    pub fn onRegister(self: RunContext, job: JobInfo) JobResult {
        if (self.vtable.on_register) |f| return f(self.ptr, job);
        return .{ .success = false };
    }

    /// Execute an update job.
    pub fn onUpdate(self: RunContext, job: JobInfo) JobResult {
        if (self.vtable.on_update) |f| return f(self.ptr, job);
        return .{ .success = false };
    }

    /// Execute an unregister job.
    pub fn onUnregister(self: RunContext, job: JobInfo) JobResult {
        if (self.vtable.on_unregister) |f| return f(self.ptr, job);
        return .{ .success = false };
    }

    /// Terminate a service worker.
    pub fn onTerminate(self: RunContext, worker: ServiceWorkerHandle) void {
        if (self.vtable.on_terminate) |f| f(self.ptr, worker);
    }

    /// Fire install event.
    pub fn onInstall(self: RunContext, worker: ServiceWorkerHandle) JobResult {
        if (self.vtable.on_install) |f| return f(self.ptr, worker);
        return .{ .success = false };
    }

    /// Fire activate event.
    pub fn onActivate(self: RunContext, worker: ServiceWorkerHandle) JobResult {
        if (self.vtable.on_activate) |f| return f(self.ptr, worker);
        return .{ .success = false };
    }

    /// Create a RunContext from a concrete implementation type.
    pub fn create(comptime T: type, impl: *T) RunContext {
        return .{
            .ptr = @ptrCast(impl),
            .vtable = &.{
                .on_register = if (@hasDecl(T, "onRegister")) struct {
                    fn call(ptr: *anyopaque, job: JobInfo) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onRegister(job);
                    }
                }.call else null,
                .on_update = if (@hasDecl(T, "onUpdate")) struct {
                    fn call(ptr: *anyopaque, job: JobInfo) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onUpdate(job);
                    }
                }.call else null,
                .on_unregister = if (@hasDecl(T, "onUnregister")) struct {
                    fn call(ptr: *anyopaque, job: JobInfo) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onUnregister(job);
                    }
                }.call else null,
                .on_terminate = if (@hasDecl(T, "onTerminate")) struct {
                    fn call(ptr: *anyopaque, worker: ServiceWorkerHandle) void {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        self.onTerminate(worker);
                    }
                }.call else null,
                .on_install = if (@hasDecl(T, "onInstall")) struct {
                    fn call(ptr: *anyopaque, worker: ServiceWorkerHandle) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onInstall(worker);
                    }
                }.call else null,
                .on_activate = if (@hasDecl(T, "onActivate")) struct {
                    fn call(ptr: *anyopaque, worker: ServiceWorkerHandle) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onActivate(worker);
                    }
                }.call else null,
            },
        };
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
// RunContext Registry (Global Singleton)
// =============================================================================

/// Global registry for the active RunContext (execution layer).
/// Thread-safe via atomic operations.
pub const run_context_registry = struct {
    var g_run_context: std.atomic.Value(?*const RunContext) = .{ .raw = null };

    /// Register a RunContext instance.
    pub fn register(run_context: *const RunContext) void {
        g_run_context.store(run_context, .release);
    }

    /// Unregister the current RunContext.
    pub fn unregister() void {
        g_run_context.store(null, .release);
    }

    /// Get the registered RunContext, if any.
    pub fn get() ?RunContext {
        if (g_run_context.load(.acquire)) |ptr| {
            return ptr.*;
        }
        return null;
    }

    /// Check if a RunContext is registered.
    pub fn isRegistered() bool {
        return g_run_context.load(.acquire) != null;
    }

    /// Reset for testing.
    pub fn resetForTesting() void {
        g_run_context.store(null, .release);
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
