//! Update Algorithm
//!
//! Handles updating a service worker registration.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#update-algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;

const Registration = @import("../registration.zig").Registration;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const types = @import("../types.zig");
const WorkerType = types.WorkerType;
const ServiceWorkerState = types.ServiceWorkerState;

/// Result of the update algorithm.
pub const UpdateResult = union(enum) {
    /// Update succeeded, new worker is installing.
    installing: *ServiceWorker,
    /// Script unchanged, no update needed.
    unchanged,
    /// No newest worker to update from.
    no_worker,
    /// Script fetch failed.
    fetch_failed: []const u8,
    /// Script parse failed.
    parse_failed: []const u8,
};

/// Context for the update algorithm.
pub const UpdateContext = struct {
    /// Allocator for creating workers.
    allocator: Allocator,

    /// Force bypass cache flag.
    force_bypass_cache: bool = false,

    /// Callback for fetching the script.
    /// Returns the script content or null on failure.
    fetch_script: ?*const fn (url: []const u8, bypass_cache: bool) ?ScriptContent = null,

    /// Callback for parsing/evaluating the script.
    /// Returns true if the script is valid.
    parse_script: ?*const fn (content: []const u8) bool = null,
};

/// Script content returned by fetch.
pub const ScriptContent = struct {
    /// The script source code.
    source: []const u8,
    /// Hash or ETag for byte-for-byte comparison.
    hash: ?[]const u8 = null,
};

/// Run the update algorithm.
///
/// Spec: https://w3c.github.io/ServiceWorker/#update-algorithm
///
/// Algorithm:
/// 1. Let newestWorker be registration's newest worker
/// 2. If newestWorker is null, abort
/// 3. Let scriptURL be newestWorker's script URL
/// 4. Fetch script (with bypass cache if force flag set)
/// 5. If fetch failed, reject with error
/// 6. Byte-for-byte comparison with existing script
/// 7. If unchanged AND not forced, abort (no update)
/// 8. Create new ServiceWorker in "parsed" state
/// 9. Set registration's installing worker
/// 10. Fire "updatefound" event on registration
/// 11. Return success
pub fn update(
    registration: *Registration,
    context: UpdateContext,
) UpdateResult {
    // Step 1 & 2: Get newest worker
    const newest_worker = registration.getNewestWorker() orelse {
        return .no_worker;
    };

    const script_url = newest_worker.script_url;

    // Step 3 & 4: Fetch script
    var script_content: ?ScriptContent = null;
    if (context.fetch_script) |fetch| {
        script_content = fetch(script_url, context.force_bypass_cache);
    }

    if (script_content == null) {
        return .{ .fetch_failed = script_url };
    }

    const content = script_content.?;

    // Step 5 & 6: Byte-for-byte comparison
    if (!context.force_bypass_cache) {
        // Check if script hash matches existing
        if (content.hash) |new_hash| {
            if (newest_worker.script_hash) |old_hash| {
                if (std.mem.eql(u8, new_hash, old_hash)) {
                    return .unchanged;
                }
            }
        }
    }

    // Step 7: Parse/validate script
    if (context.parse_script) |parse| {
        if (!parse(content.source)) {
            return .{ .parse_failed = script_url };
        }
    }

    // Step 8: Create new worker
    const new_worker = ServiceWorker.init(
        context.allocator,
        script_url,
        newest_worker.worker_type,
    ) catch {
        return .{ .parse_failed = script_url };
    };

    // Set script hash if available
    if (content.hash) |hash| {
        new_worker.setScriptHash(hash) catch {};
    }

    // Step 9: Set as installing worker
    // Clear existing installing worker if any
    if (registration.installing_worker) |old| {
        old.setState(.redundant);
        registration.clearInstallingWorker();
    }

    registration.setInstallingWorker(new_worker);

    // Step 10: Update check time
    registration.markChecked();

    // Step 11: Return success
    return .{ .installing = new_worker };
}

/// Run the update algorithm synchronously with default behavior.
///
/// This creates a new worker without fetching a script.
pub fn updateSync(
    registration: *Registration,
    allocator: Allocator,
) !UpdateResult {
    const newest_worker = registration.getNewestWorker() orelse {
        return .no_worker;
    };

    // Create new worker
    const new_worker = try ServiceWorker.init(
        allocator,
        newest_worker.script_url,
        newest_worker.worker_type,
    );

    // Set as installing
    if (registration.installing_worker) |old| {
        old.setState(.redundant);
        registration.clearInstallingWorker();
    }

    registration.setInstallingWorker(new_worker);
    registration.markChecked();

    return .{ .installing = new_worker };
}

// =============================================================================
// Tests
// =============================================================================

test "update - no worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const result = update(reg, .{ .allocator = allocator });
    try std.testing.expectEqual(UpdateResult.no_worker, result);
}

test "update - fetch failed" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    reg.setActiveWorker(sw);

    const ctx = UpdateContext{
        .allocator = allocator,
        .fetch_script = struct {
            fn fetch(_: []const u8, _: bool) ?ScriptContent {
                return null; // Fetch fails
            }
        }.fetch,
    };

    const result = update(reg, ctx);
    switch (result) {
        .fetch_failed => {},
        else => try std.testing.expect(false),
    }
}

test "update - unchanged script" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    try sw.setScriptHash("abc123");
    reg.setActiveWorker(sw);

    const ctx = UpdateContext{
        .allocator = allocator,
        .fetch_script = struct {
            fn fetch(_: []const u8, _: bool) ?ScriptContent {
                return .{
                    .source = "// same script",
                    .hash = "abc123", // Same hash
                };
            }
        }.fetch,
    };

    const result = update(reg, ctx);
    try std.testing.expectEqual(UpdateResult.unchanged, result);
}

test "update - new script creates installing worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    try sw.setScriptHash("old-hash");
    reg.setActiveWorker(sw);

    const ctx = UpdateContext{
        .allocator = allocator,
        .fetch_script = struct {
            fn fetch(_: []const u8, _: bool) ?ScriptContent {
                return .{
                    .source = "// new script",
                    .hash = "new-hash", // Different hash
                };
            }
        }.fetch,
        .parse_script = struct {
            fn parse(_: []const u8) bool {
                return true;
            }
        }.parse,
    };

    const result = update(reg, ctx);
    switch (result) {
        .installing => |new_worker| {
            defer new_worker.deinit();
            try std.testing.expectEqual(new_worker, reg.installing_worker.?);
            try std.testing.expectEqualStrings("new-hash", new_worker.script_hash.?);
        },
        else => try std.testing.expect(false),
    }
}

test "updateSync" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .module);
    defer sw.deinit();
    reg.setActiveWorker(sw);

    const result = try updateSync(reg, allocator);
    switch (result) {
        .installing => |new_worker| {
            defer new_worker.deinit();
            try std.testing.expectEqual(new_worker, reg.installing_worker.?);
            try std.testing.expectEqualStrings("https://example.com/sw.js", new_worker.script_url);
            try std.testing.expectEqual(WorkerType.module, new_worker.worker_type);
        },
        else => try std.testing.expect(false),
    }
}
