//! Register Algorithm
//!
//! Handles the registration of a new service worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#register-algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;

const Registration = @import("../registration.zig").Registration;
const RegistrationMap = @import("../registration_map.zig").RegistrationMap;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const Job = @import("../job.zig").Job;
const ScopeToJobQueueMap = @import("../job.zig").ScopeToJobQueueMap;
const types = @import("../types.zig");
const WorkerType = types.WorkerType;
const UpdateViaCacheMode = types.UpdateViaCacheMode;

/// Result of the register algorithm.
pub const RegisterResult = union(enum) {
    /// Registration succeeded, returns registration.
    success: *Registration,
    /// Registration already exists with same script URL.
    already_registered: *Registration,
    /// Script URL validation failed.
    invalid_script_url: []const u8,
    /// Scope URL validation failed.
    invalid_scope_url: []const u8,
    /// Security check failed.
    security_error,
    /// Update job was scheduled.
    update_scheduled: *Registration,
};

/// Options for registration.
pub const RegisterOptions = struct {
    /// Worker type (classic or module).
    worker_type: WorkerType = .classic,
    /// Update via cache mode.
    update_via_cache: UpdateViaCacheMode = .imports,
    /// Optional scope URL (defaults to script directory).
    scope: ?[]const u8 = null,
};

/// Context for the register algorithm.
pub const RegisterContext = struct {
    /// Registration map for looking up existing registrations.
    registration_map: *RegistrationMap,
    /// Job queue map for scheduling update jobs.
    job_queue_map: *ScopeToJobQueueMap,
    /// Allocator for creating registrations.
    allocator: Allocator,
};

/// Run the register algorithm.
///
/// Spec: https://w3c.github.io/ServiceWorker/#register-algorithm
///
/// Algorithm:
/// 1. Validate scriptURL (same-origin, secure context)
/// 2. Resolve scope URL (use scriptURL directory if not specified)
/// 3. Get or create registration
/// 4. If registration exists with same scriptURL:
///    a. Check if update needed
///    b. Return registration
/// 5. Otherwise, schedule Update job
pub fn register(
    storage_key: []const u8,
    script_url: []const u8,
    options: RegisterOptions,
    context: RegisterContext,
) !RegisterResult {
    // Step 1: Validate script URL
    if (!isValidUrl(script_url)) {
        return .{ .invalid_script_url = script_url };
    }

    // Step 2: Resolve scope URL
    const scope_url = options.scope orelse getScopeFromScriptUrl(script_url);
    if (!isValidUrl(scope_url)) {
        return .{ .invalid_scope_url = scope_url };
    }

    // Step 3: Check same-origin
    if (!isSameOrigin(script_url, scope_url)) {
        return .security_error;
    }

    // Step 4: Get or create registration
    const registration = try context.registration_map.getOrCreate(storage_key, scope_url);
    registration.setUpdateViaCache(options.update_via_cache);

    // Step 5: Check if we already have a worker with this script URL
    if (registration.getNewestWorker()) |worker| {
        if (std.mem.eql(u8, worker.script_url, script_url)) {
            // Same script URL, already registered
            return .{ .already_registered = registration };
        }
    }

    // Step 6: Schedule update job
    const job = try Job.createRegisterJob(
        context.allocator,
        storage_key,
        scope_url,
        script_url,
        options.worker_type,
        options.update_via_cache,
    );

    const queue = try context.job_queue_map.getOrCreateQueue(scope_url);
    try queue.enqueue(job);

    return .{ .update_scheduled = registration };
}

/// Simplified validation - checks if URL looks valid.
fn isValidUrl(url: []const u8) bool {
    // Basic validation - starts with http:// or https://
    return std.mem.startsWith(u8, url, "http://") or
        std.mem.startsWith(u8, url, "https://");
}

/// Extract scope from script URL (directory of the script).
fn getScopeFromScriptUrl(script_url: []const u8) []const u8 {
    // Find the last slash and return up to that point
    var last_slash: usize = 0;
    for (script_url, 0..) |c, i| {
        if (c == '/') {
            last_slash = i;
        }
    }
    // Return up to and including the last slash
    if (last_slash > 0) {
        return script_url[0 .. last_slash + 1];
    }
    return script_url;
}

/// Check if two URLs have the same origin.
fn isSameOrigin(url1: []const u8, url2: []const u8) bool {
    // Extract origins and compare
    const origin1 = getOrigin(url1);
    const origin2 = getOrigin(url2);
    return std.mem.eql(u8, origin1, origin2);
}

/// Extract origin from URL (scheme + host + port).
fn getOrigin(url: []const u8) []const u8 {
    // Find end of origin (third slash)
    var slash_count: usize = 0;
    for (url, 0..) |c, i| {
        if (c == '/') {
            slash_count += 1;
            if (slash_count == 3) {
                return url[0..i];
            }
        }
    }
    return url;
}

// =============================================================================
// Tests
// =============================================================================

test "isValidUrl" {
    try std.testing.expect(isValidUrl("https://example.com/sw.js"));
    try std.testing.expect(isValidUrl("http://localhost:8080/sw.js"));
    try std.testing.expect(!isValidUrl("file:///path/to/sw.js"));
    try std.testing.expect(!isValidUrl("sw.js"));
}

test "getScopeFromScriptUrl" {
    try std.testing.expectEqualStrings(
        "https://example.com/",
        getScopeFromScriptUrl("https://example.com/sw.js"),
    );
    try std.testing.expectEqualStrings(
        "https://example.com/app/",
        getScopeFromScriptUrl("https://example.com/app/sw.js"),
    );
}

test "getOrigin" {
    try std.testing.expectEqualStrings(
        "https://example.com",
        getOrigin("https://example.com/path/to/file"),
    );
    try std.testing.expectEqualStrings(
        "http://localhost:8080",
        getOrigin("http://localhost:8080/sw.js"),
    );
}

test "isSameOrigin" {
    try std.testing.expect(isSameOrigin(
        "https://example.com/sw.js",
        "https://example.com/app/",
    ));
    try std.testing.expect(!isSameOrigin(
        "https://example.com/sw.js",
        "https://other.com/app/",
    ));
}

test "register - invalid script URL" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer job_map.deinit();

    const ctx = RegisterContext{
        .registration_map = &reg_map,
        .job_queue_map = &job_map,
        .allocator = allocator,
    };

    const result = try register("https://example.com", "invalid-url", .{}, ctx);
    switch (result) {
        .invalid_script_url => |url| {
            try std.testing.expectEqualStrings("invalid-url", url);
        },
        else => try std.testing.expect(false),
    }
}

test "register - schedules update job" {
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

    const ctx = RegisterContext{
        .registration_map = &reg_map,
        .job_queue_map = &job_map,
        .allocator = allocator,
    };

    const result = try register(
        "https://example.com",
        "https://example.com/sw.js",
        .{ .worker_type = .module },
        ctx,
    );

    switch (result) {
        .update_scheduled => |reg| {
            try std.testing.expectEqualStrings("https://example.com/", reg.scope_url);
        },
        else => try std.testing.expect(false),
    }

    // Verify job was enqueued
    const queue = job_map.getQueue("https://example.com/").?;
    try std.testing.expectEqual(@as(usize, 1), queue.count());
}

test "register - already registered" {
    const allocator = std.testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer {
        var iter = job_map.map.iterator();
        while (iter.next()) |entry| {
            while (entry.value_ptr.*.dequeue()) |job| {
                job.deinit();
            }
        }
        job_map.deinit();
    }

    // Pre-create registration with a worker
    const reg = try reg_map.getOrCreate("https://example.com", "https://example.com/");

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    reg.setActiveWorker(sw);

    const ctx = RegisterContext{
        .registration_map = &reg_map,
        .job_queue_map = &job_map,
        .allocator = allocator,
    };

    const result = try register(
        "https://example.com",
        "https://example.com/sw.js",
        .{},
        ctx,
    );

    switch (result) {
        .already_registered => |returned_reg| {
            try std.testing.expectEqual(reg, returned_reg);
        },
        else => try std.testing.expect(false),
    }
}
