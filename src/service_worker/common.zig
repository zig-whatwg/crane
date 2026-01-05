//! Service Worker Common Types - SELF-CONTAINED LEAF MODULE
//!
//! This module is COMPLETELY SELF-CONTAINED with NO imports from other
//! service_worker files. This is critical to avoid Zig module ownership
//! conflicts when both sw_common and service_worker modules exist.
//!
//! Leaf types that have NO WebIDL dependencies.
//! Safe to import from Browser and other modules that cannot import WebIDL.
//!
//! This module breaks the circular dependency:
//! Browser -> service_worker -> webidl/interfaces -> browser

const std = @import("std");

// =============================================================================
// Core Enums (Self-contained definitions)
// =============================================================================

/// Worker type - classic or module.
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-type
pub const WorkerType = enum {
    classic,
    module,

    pub fn name(self: WorkerType) []const u8 {
        return switch (self) {
            .classic => "classic",
            .module => "module",
        };
    }
};

/// Update via cache mode.
/// Spec: https://w3c.github.io/ServiceWorker/#enumdef-serviceworkerupdateviacache
pub const UpdateViaCacheMode = enum {
    imports,
    all,
    none,

    pub fn name(self: UpdateViaCacheMode) []const u8 {
        return switch (self) {
            .imports => "imports",
            .all => "all",
            .none => "none",
        };
    }
};

// =============================================================================
// Opaque Handles for Cross-Layer Communication
// =============================================================================

/// Opaque handle for a service worker registration.
/// Used by Browser to reference registrations without importing WebIDL types.
pub const RegistrationHandle = struct {
    id: u64,

    pub const invalid: RegistrationHandle = .{ .id = 0 };

    pub fn isValid(self: RegistrationHandle) bool {
        return self.id != 0;
    }
};

/// Opaque handle for a service worker instance.
/// Used by Browser to reference workers without importing WebIDL types.
pub const ServiceWorkerHandle = struct {
    id: u64,

    pub const invalid: ServiceWorkerHandle = .{ .id = 0 };

    pub fn isValid(self: ServiceWorkerHandle) bool {
        return self.id != 0;
    }
};

/// Registration key for looking up registrations by scope.
/// This is a value type that can be used as a hash map key.
pub const RegistrationKey = struct {
    /// The serialized storage key (origin).
    storage_key: []const u8,
    /// The scope URL.
    scope: []const u8,

    pub fn hash(self: RegistrationKey) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(self.storage_key);
        hasher.update(self.scope);
        return hasher.final();
    }

    pub fn eql(a: RegistrationKey, b: RegistrationKey) bool {
        return std.mem.eql(u8, a.storage_key, b.storage_key) and
            std.mem.eql(u8, a.scope, b.scope);
    }
};

// =============================================================================
// ServiceWorkerRegistrar VTable Interface
// =============================================================================

/// Result of a registration operation.
/// This is a value type that can cross module boundaries without WebIDL deps.
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
///
/// Pattern: Same as FetchInterceptor - interface defined in leaf module,
/// implementation in integration/, wired by Browser.
pub const ServiceWorkerRegistrar = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Register a service worker for the given script URL.
        /// Returns a RegistrationResult immediately (may be pending for async).
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
// RunContext VTable Interface (Execution Layer Callbacks)
// =============================================================================

/// Result of a job execution.
/// Used by RunContext callbacks to report success/failure.
pub const JobResult = struct {
    success: bool,
    value: ?*anyopaque = null,
};

/// Opaque job reference for RunContext callbacks.
/// Contains only the scheduling-layer-safe information needed for execution.
pub const JobInfo = struct {
    /// The script URL to fetch/execute.
    script_url: []const u8,
    /// The scope URL for this registration.
    scope_url: []const u8,
    /// Worker type (classic or module).
    worker_type: WorkerType,
    /// Update via cache mode.
    update_via_cache: UpdateViaCacheMode,
};

/// VTable-based interface for service worker execution.
///
/// This defines the scheduling→execution boundary. The scheduling layer
/// (algorithms/, integration/registrar_impl.zig) calls these callbacks
/// to delegate actual execution work to the browser layer.
///
/// The execution layer (browser/service_worker/ServiceWorkerManager.zig)
/// implements these callbacks and owns V8/GlobalScope interactions.
///
/// Pattern: Same as ServiceWorkerRegistrar - interface defined in leaf module,
/// implementation in browser layer, wired by Browser.init().
///
/// ## Layer Architecture
///
/// - **Layer 2 (Scheduling)**: `src/service_worker/algorithms/*`, `integration/registrar_impl.zig`
///   - Pure scheduling/state-machine logic
///   - NO imports of GlobalScope, WebIDL interfaces, or browser modules
///   - Calls RunContext callbacks for execution
///
/// - **Layer 3 (Execution)**: `src/browser/service_worker/ServiceWorkerManager.zig`
///   - Creates/owns ServiceWorkerGlobalScope and V8 contexts
///   - Implements RunContext callbacks
///   - MAY import runtime/V8/WebIDL types
pub const RunContext = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Called when a register job needs to execute.
        /// Should fetch the script, create a GlobalScope, and execute.
        on_register: *const fn (self: *anyopaque, job: JobInfo) JobResult,

        /// Called when an update job needs to execute.
        /// Should check for script changes and update if needed.
        on_update: *const fn (self: *anyopaque, job: JobInfo) JobResult,

        /// Called when an unregister job needs to execute.
        /// Should terminate workers and clean up registrations.
        on_unregister: *const fn (self: *anyopaque, job: JobInfo) JobResult,

        /// Called when a service worker needs to be terminated.
        /// Should abort fetches, clear timers, and detach GlobalScope.
        on_terminate: *const fn (self: *anyopaque, worker: ServiceWorkerHandle) void,

        /// Called when the install event should fire.
        /// Should create InstallEvent and dispatch to GlobalScope.
        on_install: *const fn (self: *anyopaque, worker: ServiceWorkerHandle) JobResult,

        /// Called when the activate event should fire.
        /// Should create ActivateEvent and dispatch to GlobalScope.
        on_activate: *const fn (self: *anyopaque, worker: ServiceWorkerHandle) JobResult,
    };

    /// Execute a register job.
    pub fn runRegister(self: RunContext, job: JobInfo) JobResult {
        return self.vtable.on_register(self.ptr, job);
    }

    /// Execute an update job.
    pub fn runUpdate(self: RunContext, job: JobInfo) JobResult {
        return self.vtable.on_update(self.ptr, job);
    }

    /// Execute an unregister job.
    pub fn runUnregister(self: RunContext, job: JobInfo) JobResult {
        return self.vtable.on_unregister(self.ptr, job);
    }

    /// Terminate a service worker.
    pub fn terminate(self: RunContext, worker: ServiceWorkerHandle) void {
        self.vtable.on_terminate(self.ptr, worker);
    }

    /// Fire install event.
    pub fn install(self: RunContext, worker: ServiceWorkerHandle) JobResult {
        return self.vtable.on_install(self.ptr, worker);
    }

    /// Fire activate event.
    pub fn activate(self: RunContext, worker: ServiceWorkerHandle) JobResult {
        return self.vtable.on_activate(self.ptr, worker);
    }

    /// Create a RunContext from a concrete implementation type.
    pub fn create(comptime T: type, impl: *T) RunContext {
        return .{
            .ptr = @ptrCast(impl),
            .vtable = &.{
                .on_register = struct {
                    fn call(ptr: *anyopaque, job: JobInfo) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onRegister(job);
                    }
                }.call,
                .on_update = struct {
                    fn call(ptr: *anyopaque, job: JobInfo) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onUpdate(job);
                    }
                }.call,
                .on_unregister = struct {
                    fn call(ptr: *anyopaque, job: JobInfo) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onUnregister(job);
                    }
                }.call,
                .on_terminate = struct {
                    fn call(ptr: *anyopaque, worker: ServiceWorkerHandle) void {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        self.onTerminate(worker);
                    }
                }.call,
                .on_install = struct {
                    fn call(ptr: *anyopaque, worker: ServiceWorkerHandle) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onInstall(worker);
                    }
                }.call,
                .on_activate = struct {
                    fn call(ptr: *anyopaque, worker: ServiceWorkerHandle) JobResult {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.onActivate(worker);
                    }
                }.call,
            },
        };
    }
};

// =============================================================================
// RunContext Registry (Global Singleton)
// =============================================================================

/// Global registry for the active RunContext.
/// Thread-safe via atomic operations.
pub const run_context_registry = struct {
    var g_run_context: std.atomic.Value(?*const RunContext) = .{ .raw = null };

    /// Register a RunContext instance.
    pub fn register(ctx: *const RunContext) void {
        g_run_context.store(ctx, .release);
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
// ServiceWorkerRegistrar Registry (Global Singleton)
// =============================================================================

/// Factory function type for creating a ServiceWorkerRegistrar.
/// This allows Browser to provide the factory without circular dependencies.
/// The factory is called lazily when a registrar is first needed.
pub const RegistrarFactory = *const fn () ?*const ServiceWorkerRegistrar;

// =============================================================================
// Shared Resource Storage (for lazy registrar initialization)
// =============================================================================

/// Storage for shared resources needed by registrar initialization.
/// Browser sets these during init, registrar factory reads them.
/// This breaks the circular dependency by using opaque pointers.
pub const shared_resources = struct {
    var g_registration_map: std.atomic.Value(?*anyopaque) = .{ .raw = null };
    var g_job_queue_map: std.atomic.Value(?*anyopaque) = .{ .raw = null };
    var g_allocator: std.atomic.Value(?*std.mem.Allocator) = .{ .raw = null };

    /// Set the registration map (called by Browser during init).
    pub fn setRegistrationMap(map: *anyopaque) void {
        g_registration_map.store(map, .release);
    }

    /// Get the registration map.
    pub fn getRegistrationMap() ?*anyopaque {
        return g_registration_map.load(.acquire);
    }

    /// Set the job queue map (called by Browser during init).
    pub fn setJobQueueMap(map: *anyopaque) void {
        g_job_queue_map.store(map, .release);
    }

    /// Get the job queue map.
    pub fn getJobQueueMap() ?*anyopaque {
        return g_job_queue_map.load(.acquire);
    }

    /// Set the allocator (called by Browser during init).
    pub fn setAllocator(alloc: *std.mem.Allocator) void {
        g_allocator.store(alloc, .release);
    }

    /// Get the allocator.
    pub fn getAllocator() ?*std.mem.Allocator {
        return g_allocator.load(.acquire);
    }

    /// Reset for testing.
    pub fn resetForTesting() void {
        g_registration_map.store(null, .release);
        g_job_queue_map.store(null, .release);
        g_allocator.store(null, .release);
    }
};

/// Global registry for the active ServiceWorkerRegistrar.
/// Thread-safe via atomic operations.
///
/// Supports two initialization patterns:
/// 1. Direct: Call register() with an already-created registrar
/// 2. Lazy: Call setFactory() with a factory function, registrar created on first get()
pub const registrar_registry = struct {
    var g_registrar: std.atomic.Value(?*const ServiceWorkerRegistrar) = .{ .raw = null };
    var g_factory: std.atomic.Value(?RegistrarFactory) = .{ .raw = null };

    /// Register a ServiceWorkerRegistrar instance directly.
    pub fn register(registrar: *const ServiceWorkerRegistrar) void {
        g_registrar.store(registrar, .release);
    }

    /// Set a factory function for lazy initialization.
    /// The factory will be called on first get() if no registrar is registered.
    pub fn setFactory(factory: RegistrarFactory) void {
        g_factory.store(factory, .release);
    }

    /// Unregister the current registrar.
    pub fn unregister() void {
        g_registrar.store(null, .release);
    }

    /// Get the registered ServiceWorkerRegistrar, if any.
    /// If no registrar is registered but a factory is set, calls the factory.
    pub fn get() ?ServiceWorkerRegistrar {
        // First check if we have a registrar
        if (g_registrar.load(.acquire)) |ptr| {
            return ptr.*;
        }

        // No registrar - try the factory for lazy initialization
        if (g_factory.load(.acquire)) |factory| {
            if (factory()) |new_registrar| {
                // Store it for future calls
                g_registrar.store(new_registrar, .release);
                return new_registrar.*;
            }
        }

        return null;
    }

    /// Check if a registrar is registered (doesn't trigger lazy init).
    pub fn isRegistered() bool {
        return g_registrar.load(.acquire) != null;
    }

    /// Check if a factory is set.
    pub fn hasFactory() bool {
        return g_factory.load(.acquire) != null;
    }

    /// Reset for testing.
    pub fn resetForTesting() void {
        g_registrar.store(null, .release);
        g_factory.store(null, .release);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "RegistrationHandle validity" {
    const invalid = RegistrationHandle.invalid;
    try std.testing.expect(!invalid.isValid());

    const valid = RegistrationHandle{ .id = 42 };
    try std.testing.expect(valid.isValid());
}

test "ServiceWorkerHandle validity" {
    const invalid = ServiceWorkerHandle.invalid;
    try std.testing.expect(!invalid.isValid());

    const valid = ServiceWorkerHandle{ .id = 42 };
    try std.testing.expect(valid.isValid());
}

test "RegistrationKey hashing" {
    const key1 = RegistrationKey{
        .storage_key = "https://example.com",
        .scope = "/app/",
    };
    const key2 = RegistrationKey{
        .storage_key = "https://example.com",
        .scope = "/app/",
    };
    const key3 = RegistrationKey{
        .storage_key = "https://other.com",
        .scope = "/app/",
    };

    try std.testing.expectEqual(key1.hash(), key2.hash());
    try std.testing.expect(key1.hash() != key3.hash());
    try std.testing.expect(key1.eql(key2));
    try std.testing.expect(!key1.eql(key3));
}
