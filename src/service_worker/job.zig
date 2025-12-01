//! Service Worker Job Queue System
//!
//! Jobs are used to serialize registration, update, and unregistration operations.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-job

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const JobType = types.JobType;
const WorkerType = types.WorkerType;
const UpdateViaCacheMode = types.UpdateViaCacheMode;
const client_mod = @import("client.zig");
const Client = client_mod.Client;

/// A job.
///
/// Jobs are used to serialize and manage service worker operations.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-job
pub const Job = struct {
    allocator: Allocator,

    /// Unique identifier for this job.
    id: u64,

    /// Job type (register, update, unregister).
    job_type: JobType,

    /// Storage key.
    storage_key: []const u8,

    /// Scope URL.
    scope_url: []const u8,

    /// Script URL (for register/update jobs).
    script_url: ?[]const u8 = null,

    /// Worker type (classic or module).
    worker_type: WorkerType = .classic,

    /// Update via cache mode.
    update_via_cache_mode: UpdateViaCacheMode = .imports,

    /// Client that initiated the job.
    client: ?*Client = null,

    /// Referrer URL.
    referrer: ?[]const u8 = null,

    /// Force bypass cache flag.
    force_bypass_cache: bool = false,

    /// List of equivalent jobs.
    /// Jobs with the same scope URL are equivalent and their promises
    /// are resolved together.
    equivalent_jobs: std.ArrayListUnmanaged(*Job),

    /// Job promise (in real impl, would be a Promise).
    /// For now, we use a callback.
    on_complete: ?*const fn (success: bool, result: ?*anyopaque) void = null,

    /// Counter for generating unique IDs.
    var next_id: u64 = 0;

    const Self = @This();

    /// Create a new job.
    pub fn init(
        allocator: Allocator,
        job_type: JobType,
        storage_key: []const u8,
        scope_url: []const u8,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const storage_key_copy = try allocator.dupe(u8, storage_key);
        errdefer allocator.free(storage_key_copy);

        const scope_url_copy = try allocator.dupe(u8, scope_url);

        self.* = .{
            .allocator = allocator,
            .id = next_id,
            .job_type = job_type,
            .storage_key = storage_key_copy,
            .scope_url = scope_url_copy,
            .equivalent_jobs = .{},
        };
        next_id += 1;

        return self;
    }

    /// Create a register job.
    pub fn createRegisterJob(
        allocator: Allocator,
        storage_key: []const u8,
        scope_url: []const u8,
        script_url: []const u8,
        worker_type: WorkerType,
        update_via_cache: UpdateViaCacheMode,
    ) !*Self {
        const job = try init(allocator, .register, storage_key, scope_url);
        errdefer job.deinit();

        job.script_url = try allocator.dupe(u8, script_url);
        job.worker_type = worker_type;
        job.update_via_cache_mode = update_via_cache;

        return job;
    }

    /// Create an update job.
    pub fn createUpdateJob(
        allocator: Allocator,
        storage_key: []const u8,
        scope_url: []const u8,
        force_bypass_cache: bool,
    ) !*Self {
        const job = try init(allocator, .update, storage_key, scope_url);
        job.force_bypass_cache = force_bypass_cache;
        return job;
    }

    /// Create an unregister job.
    pub fn createUnregisterJob(
        allocator: Allocator,
        storage_key: []const u8,
        scope_url: []const u8,
    ) !*Self {
        return init(allocator, .unregister, storage_key, scope_url);
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.storage_key);
        self.allocator.free(self.scope_url);
        if (self.script_url) |url| {
            self.allocator.free(url);
        }
        if (self.referrer) |ref| {
            self.allocator.free(ref);
        }
        self.equivalent_jobs.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Add an equivalent job.
    ///
    /// Equivalent jobs have their promises resolved together.
    pub fn addEquivalentJob(self: *Self, job: *Job) !void {
        try self.equivalent_jobs.append(self.allocator, job);
    }

    /// Check if this job is equivalent to another.
    ///
    /// Two jobs are equivalent if they have the same scope URL.
    pub fn isEquivalentTo(self: *const Self, other: *const Job) bool {
        return std.mem.eql(u8, self.scope_url, other.scope_url);
    }

    /// Set the client that initiated the job.
    pub fn setClient(self: *Self, client: *Client) void {
        self.client = client;
    }

    /// Set the referrer URL.
    pub fn setReferrer(self: *Self, referrer: []const u8) !void {
        if (self.referrer) |ref| {
            self.allocator.free(ref);
        }
        self.referrer = try self.allocator.dupe(u8, referrer);
    }

    /// Resolve the job (call completion callback).
    pub fn resolve(self: *Self, success: bool, result: ?*anyopaque) void {
        if (self.on_complete) |callback| {
            callback(success, result);
        }

        // Also resolve equivalent jobs
        for (self.equivalent_jobs.items) |eq_job| {
            if (eq_job.on_complete) |callback| {
                callback(success, result);
            }
        }
    }
};

/// Job queue for a specific scope.
///
/// Jobs for the same scope are queued and processed in order.
pub const JobQueue = struct {
    allocator: Allocator,

    /// Scope URL this queue is for.
    scope_url: []const u8,

    /// Queue of pending jobs.
    jobs: std.ArrayListUnmanaged(*Job),

    /// Whether a job is currently being processed.
    processing: bool = false,

    const Self = @This();

    /// Create a new job queue.
    pub fn init(allocator: Allocator, scope_url: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .scope_url = try allocator.dupe(u8, scope_url),
            .jobs = .{},
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.scope_url);
        self.jobs.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Enqueue a job.
    pub fn enqueue(self: *Self, job: *Job) !void {
        try self.jobs.append(self.allocator, job);
    }

    /// Dequeue the next job.
    pub fn dequeue(self: *Self) ?*Job {
        if (self.jobs.items.len == 0) {
            return null;
        }
        return self.jobs.orderedRemove(0);
    }

    /// Peek at the next job without removing it.
    pub fn peek(self: *const Self) ?*Job {
        if (self.jobs.items.len == 0) {
            return null;
        }
        return self.jobs.items[0];
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.jobs.items.len == 0;
    }

    /// Get the number of pending jobs.
    pub fn count(self: *const Self) usize {
        return self.jobs.items.len;
    }
};

/// Global scope-to-job-queue map.
///
/// Maps scope URLs to their job queues.
pub const ScopeToJobQueueMap = struct {
    allocator: Allocator,

    /// Map from scope URL to job queue.
    map: std.StringHashMapUnmanaged(*JobQueue),

    /// Mutex for thread-safe access.
    mutex: std.Thread.Mutex = .{},

    const Self = @This();

    /// Initialize the map.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .map = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.map.deinit(self.allocator);
    }

    /// Get or create a job queue for a scope.
    pub fn getOrCreateQueue(self: *Self, scope_url: []const u8) !*JobQueue {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.map.get(scope_url)) |queue| {
            return queue;
        }

        // Create new queue
        const queue = try JobQueue.init(self.allocator, scope_url);
        errdefer queue.deinit();

        const key = try self.allocator.dupe(u8, scope_url);
        errdefer self.allocator.free(key);

        try self.map.put(self.allocator, key, queue);
        return queue;
    }

    /// Get a job queue for a scope (returns null if doesn't exist).
    pub fn getQueue(self: *Self, scope_url: []const u8) ?*JobQueue {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.get(scope_url);
    }

    /// Remove an empty queue.
    pub fn removeEmptyQueue(self: *Self, scope_url: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.map.get(scope_url)) |queue| {
            if (queue.isEmpty()) {
                if (self.map.fetchRemove(scope_url)) |entry| {
                    self.allocator.free(entry.key);
                    entry.value.deinit();
                }
            }
        }
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Job.init and deinit" {
    const allocator = std.testing.allocator;

    const job = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job.deinit();

    try std.testing.expectEqual(JobType.register, job.job_type);
    try std.testing.expectEqualStrings("https://example.com", job.storage_key);
    try std.testing.expectEqualStrings("https://example.com/", job.scope_url);
}

test "Job.createRegisterJob" {
    const allocator = std.testing.allocator;

    const job = try Job.createRegisterJob(
        allocator,
        "https://example.com",
        "https://example.com/",
        "https://example.com/sw.js",
        .module,
        .none,
    );
    defer job.deinit();

    try std.testing.expectEqual(JobType.register, job.job_type);
    try std.testing.expectEqualStrings("https://example.com/sw.js", job.script_url.?);
    try std.testing.expectEqual(WorkerType.module, job.worker_type);
    try std.testing.expectEqual(UpdateViaCacheMode.none, job.update_via_cache_mode);
}

test "Job.createUpdateJob" {
    const allocator = std.testing.allocator;

    const job = try Job.createUpdateJob(
        allocator,
        "https://example.com",
        "https://example.com/",
        true,
    );
    defer job.deinit();

    try std.testing.expectEqual(JobType.update, job.job_type);
    try std.testing.expect(job.force_bypass_cache);
}

test "Job.createUnregisterJob" {
    const allocator = std.testing.allocator;

    const job = try Job.createUnregisterJob(
        allocator,
        "https://example.com",
        "https://example.com/",
    );
    defer job.deinit();

    try std.testing.expectEqual(JobType.unregister, job.job_type);
}

test "Job.isEquivalentTo" {
    const allocator = std.testing.allocator;

    const job1 = try Job.init(allocator, .register, "https://example.com", "https://example.com/a/");
    defer job1.deinit();

    const job2 = try Job.init(allocator, .update, "https://example.com", "https://example.com/a/");
    defer job2.deinit();

    const job3 = try Job.init(allocator, .register, "https://example.com", "https://example.com/b/");
    defer job3.deinit();

    // Same scope = equivalent
    try std.testing.expect(job1.isEquivalentTo(job2));

    // Different scope = not equivalent
    try std.testing.expect(!job1.isEquivalentTo(job3));
}

test "JobQueue.enqueue and dequeue" {
    const allocator = std.testing.allocator;

    const queue = try JobQueue.init(allocator, "https://example.com/");
    defer queue.deinit();

    const job1 = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job1.deinit();

    const job2 = try Job.init(allocator, .update, "https://example.com", "https://example.com/");
    defer job2.deinit();

    try queue.enqueue(job1);
    try queue.enqueue(job2);

    try std.testing.expectEqual(@as(usize, 2), queue.count());

    const dequeued1 = queue.dequeue();
    try std.testing.expectEqual(job1, dequeued1.?);

    const dequeued2 = queue.dequeue();
    try std.testing.expectEqual(job2, dequeued2.?);

    try std.testing.expect(queue.isEmpty());
}

test "JobQueue.peek" {
    const allocator = std.testing.allocator;

    const queue = try JobQueue.init(allocator, "https://example.com/");
    defer queue.deinit();

    const job = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job.deinit();

    try queue.enqueue(job);

    const peeked = queue.peek();
    try std.testing.expectEqual(job, peeked.?);

    // Still in queue
    try std.testing.expectEqual(@as(usize, 1), queue.count());
}

test "ScopeToJobQueueMap.getOrCreateQueue" {
    const allocator = std.testing.allocator;

    var map = ScopeToJobQueueMap.init(allocator);
    defer map.deinit();

    const queue1 = try map.getOrCreateQueue("https://example.com/a/");
    const queue2 = try map.getOrCreateQueue("https://example.com/a/");

    // Same scope should return same queue
    try std.testing.expectEqual(queue1, queue2);

    const queue3 = try map.getOrCreateQueue("https://example.com/b/");

    // Different scope should return different queue
    try std.testing.expect(queue1 != queue3);
}

test "ScopeToJobQueueMap.removeEmptyQueue" {
    const allocator = std.testing.allocator;

    var map = ScopeToJobQueueMap.init(allocator);
    defer map.deinit();

    _ = try map.getOrCreateQueue("https://example.com/");
    try std.testing.expect(map.getQueue("https://example.com/") != null);

    map.removeEmptyQueue("https://example.com/");
    try std.testing.expect(map.getQueue("https://example.com/") == null);
}
