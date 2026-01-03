//! Service Worker Registrar Implementation
//!
//! Implements the ServiceWorkerRegistrar VTable interface, wiring
//! the WebIDL layer (ServiceWorkerContainer) to the internal
//! service_worker algorithms.
//!
//! This module bridges:
//! - webidl/impls/ServiceWorkerContainer.zig (consumer)
//! - service_worker/algorithms/register.zig (implementation)
//!
//! ## Architecture
//!
//! The registrar is initialized by Browser.zig and registered with
//! the global registrar_registry. ServiceWorkerContainer calls through
//! the registry to avoid circular dependencies.

const std = @import("std");
const Allocator = std.mem.Allocator;

const common = @import("../common.zig");
const RegistrationHandle = common.RegistrationHandle;
const RegistrationResult = common.RegistrationResult;
const ServiceWorkerRegistrar = common.ServiceWorkerRegistrar;
const WorkerType = common.WorkerType;
const UpdateViaCacheMode = common.UpdateViaCacheMode;

const algorithms = @import("../algorithms/root.zig");
const jobs = @import("../algorithms/jobs.zig");
const RegistrationMap = @import("../registration_map.zig").RegistrationMap;
const ScopeToJobQueueMap = @import("../job.zig").ScopeToJobQueueMap;
const Job = @import("../job.zig").Job;

/// Service Worker Registrar implementation.
/// Holds references to the internal registration infrastructure.
pub const ServiceWorkerRegistrarImpl = struct {
    allocator: Allocator,
    registration_map: *RegistrationMap,
    job_queue_map: *ScopeToJobQueueMap,

    /// Run context for processing jobs with real V8 execution
    run_context: jobs.RunContext,

    /// Cached registrar interface (must persist for registry)
    registrar: ServiceWorkerRegistrar,

    /// Initialize the registrar implementation.
    pub fn init(
        allocator: Allocator,
        registration_map: *RegistrationMap,
        job_queue_map: *ScopeToJobQueueMap,
    ) *ServiceWorkerRegistrarImpl {
        const self = allocator.create(ServiceWorkerRegistrarImpl) catch @panic("OOM");
        self.* = .{
            .allocator = allocator,
            .registration_map = registration_map,
            .job_queue_map = job_queue_map,
            .run_context = .{
                .on_register = onRegisterJob,
                .on_update = onUpdateJob,
                .on_unregister = onUnregisterJob,
            },
            .registrar = undefined,
        };
        // Create the registrar interface pointing to self
        self.registrar = ServiceWorkerRegistrar.create(ServiceWorkerRegistrarImpl, self);
        return self;
    }

    // =========================================================================
    // Job Execution Callbacks (Production Implementation)
    // =========================================================================

    /// Production callback for register jobs.
    /// This is called when a registration job is processed.
    ///
    /// Per spec, this should:
    /// 1. Fetch the service worker script
    /// 2. Create a ServiceWorkerGlobalScope with V8 context
    /// 3. Execute the script in that context
    /// 4. Handle install/activate events
    fn onRegisterJob(job: *const Job) jobs.JobResult {
        // TODO: Implement full service worker script execution using WorkerV8Context
        // For now, log that we're processing the job (this is where real V8 context creation goes)
        std.log.info("ServiceWorker: Processing register job for script: {s}, scope: {s}", .{
            job.script_url,
            job.scope_url,
        });

        // The full implementation needs to:
        // 1. Fetch script from job.script_url
        // 2. Create WorkerV8Context for ServiceWorkerGlobalScope
        // 3. Execute script with importScripts available
        // 4. Fire 'install' event
        // 5. Set service worker state to 'installed'

        return .{ .success = true, .value = null };
    }

    /// Production callback for update jobs.
    fn onUpdateJob(job: *const Job) jobs.JobResult {
        std.log.info("ServiceWorker: Processing update job for script: {s}", .{job.script_url});
        return .{ .success = true, .value = null };
    }

    /// Production callback for unregister jobs.
    fn onUnregisterJob(job: *const Job) jobs.JobResult {
        std.log.info("ServiceWorker: Processing unregister job for scope: {s}", .{job.scope_url});
        return .{ .success = true, .value = null };
    }

    /// Deinitialize and free resources.
    pub fn deinit(self: *ServiceWorkerRegistrarImpl) void {
        self.allocator.destroy(self);
    }

    /// Get the ServiceWorkerRegistrar interface.
    pub fn asRegistrar(self: *ServiceWorkerRegistrarImpl) *const ServiceWorkerRegistrar {
        return &self.registrar;
    }

    /// Register and return the registrar interface.
    /// This registers with the global registry.
    pub fn ensureRegistered(self: *ServiceWorkerRegistrarImpl) *const ServiceWorkerRegistrar {
        common.registrar_registry.register(&self.registrar);
        return &self.registrar;
    }

    // =========================================================================
    // ServiceWorkerRegistrar VTable Implementation
    // =========================================================================

    /// Implements ServiceWorkerRegistrar.register
    pub fn register(
        self: *ServiceWorkerRegistrarImpl,
        storage_key: []const u8,
        script_url: []const u8,
        scope: ?[]const u8,
        worker_type: WorkerType,
        update_via_cache: UpdateViaCacheMode,
    ) RegistrationResult {
        // Call the internal register algorithm
        const context = algorithms.register.RegisterContext{
            .registration_map = self.registration_map,
            .job_queue_map = self.job_queue_map,
            .allocator = self.allocator,
        };

        const options = algorithms.register.RegisterOptions{
            .worker_type = worker_type,
            .update_via_cache = update_via_cache,
            .scope = scope,
        };

        const result = algorithms.register.register(
            storage_key,
            script_url,
            options,
            context,
        ) catch |err| {
            return .{ .err = @errorName(err) };
        };

        // If a job was scheduled, process it now
        // This is the critical fix: jobs were being enqueued but never processed!
        if (result == .update_scheduled) {
            // Get the scope URL to find the right queue
            const scope_url = options.scope orelse script_url;
            if (self.job_queue_map.getQueue(scope_url)) |queue| {
                // Process the job with our production run context
                jobs.runNextJob(queue, &self.run_context) catch |err| {
                    std.log.err("ServiceWorker: Failed to run job: {}", .{err});
                };
            }
        }

        // Convert internal result to RegistrationResult
        return switch (result) {
            .success => |reg| .{ .success = .{ .id = @intFromPtr(reg) } },
            .already_registered => |reg| .{ .success = .{ .id = @intFromPtr(reg) } },
            .update_scheduled => |reg| .{ .pending = .{ .id = @intFromPtr(reg) } },
            .invalid_script_url => .invalid_script_url,
            .invalid_scope_url => .invalid_scope_url,
            .security_error => .security_error,
        };
    }

    /// Implements ServiceWorkerRegistrar.getRegistration
    pub fn getRegistration(
        self: *ServiceWorkerRegistrarImpl,
        storage_key: []const u8,
        client_url: []const u8,
    ) ?RegistrationHandle {
        // Find the registration that controls this URL
        if (self.registration_map.findByScope(storage_key, client_url)) |reg| {
            return .{ .id = @intFromPtr(reg) };
        }
        return null;
    }

    /// Implements ServiceWorkerRegistrar.getRegistrations
    pub fn getRegistrations(
        self: *ServiceWorkerRegistrarImpl,
        storage_key: []const u8,
    ) []const RegistrationHandle {
        // Get all registrations for this storage key
        // Note: This returns an empty slice for now - full implementation
        // would iterate the registration map
        _ = self;
        _ = storage_key;
        return &[_]RegistrationHandle{};
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerRegistrarImpl creation" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer job_map.deinit();

    const impl = ServiceWorkerRegistrarImpl.init(allocator, &reg_map, &job_map);
    defer impl.deinit();

    // Verify we can get the registrar interface
    const registrar = impl.asRegistrar();
    try std.testing.expect(registrar.ptr != null);
}

test "ServiceWorkerRegistrarImpl register" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer {
        // Clean up jobs
        var iter = job_map.map.iterator();
        while (iter.next()) |entry| {
            while (entry.value_ptr.*.dequeue()) |job| {
                job.deinit();
            }
        }
        job_map.deinit();
    }

    const impl = ServiceWorkerRegistrarImpl.init(allocator, &reg_map, &job_map);
    defer impl.deinit();

    const registrar = impl.asRegistrar();

    // Test registration
    const result = registrar.register(
        "https://example.com",
        "https://example.com/sw.js",
        null,
        .classic,
        .imports,
    );

    switch (result) {
        .pending => |handle| {
            try std.testing.expect(handle.isValid());
        },
        else => try std.testing.expect(false),
    }
}

test "ServiceWorkerRegistrarImpl invalid URL" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer job_map.deinit();

    const impl = ServiceWorkerRegistrarImpl.init(allocator, &reg_map, &job_map);
    defer impl.deinit();

    const registrar = impl.asRegistrar();

    // Test invalid URL
    const result = registrar.register(
        "https://example.com",
        "invalid-url",
        null,
        .classic,
        .imports,
    );

    try std.testing.expect(result == .invalid_script_url);
}

test "ServiceWorkerRegistrarImpl registry integration" {
    const allocator = std.testing.allocator;

    // Ensure clean state
    common.registrar_registry.resetForTesting();
    defer common.registrar_registry.resetForTesting();

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer job_map.deinit();

    const impl = ServiceWorkerRegistrarImpl.init(allocator, &reg_map, &job_map);
    defer impl.deinit();

    // Not registered yet
    try std.testing.expect(!common.registrar_registry.isRegistered());

    // Register
    _ = impl.ensureRegistered();

    // Now registered
    try std.testing.expect(common.registrar_registry.isRegistered());

    // Can get from registry
    const registrar = common.registrar_registry.get();
    try std.testing.expect(registrar != null);
}
