//! Job Processing Algorithms
//!
//! Algorithms for creating, scheduling, and running service worker jobs.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#create-job

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("../types.zig");
const JobType = types.JobType;
const WorkerType = types.WorkerType;
const UpdateViaCacheMode = types.UpdateViaCacheMode;

const Job = @import("../job.zig").Job;
const JobQueue = @import("../job.zig").JobQueue;
const ScopeToJobQueueMap = @import("../job.zig").ScopeToJobQueueMap;

/// Job completion callback type.
pub const JobCompletionCallback = *const fn (success: bool, result: ?*anyopaque) void;

/// Schedule a job.
///
/// This adds a job to the appropriate queue and triggers processing if needed.
///
/// Spec: https://w3c.github.io/ServiceWorker/#schedule-job
///
/// Algorithm:
/// 1. Let queue be the result of getting the job queue for job's scope URL
/// 2. If queue has an existing job with the same scope URL:
///    a. Append job to existing job's equivalent jobs list
///    b. Return
/// 3. Append job to queue
/// 4. If queue is not currently processing, run the job
pub fn scheduleJob(
    job_queue_map: *ScopeToJobQueueMap,
    job: *Job,
) !void {
    const queue = try job_queue_map.getOrCreateQueue(job.scope_url);

    // Check for equivalent job already in queue
    for (queue.jobs.items) |existing_job| {
        if (existing_job.isEquivalentTo(job)) {
            // Add as equivalent job rather than enqueueing separately
            try existing_job.addEquivalentJob(job);
            return;
        }
    }

    // No equivalent job, enqueue this one
    try queue.enqueue(job);
}

/// Run the next job from a queue.
///
/// Spec: https://w3c.github.io/ServiceWorker/#run-job
///
/// Algorithm:
/// 1. Dequeue the next job
/// 2. Run the job based on its type
/// 3. When complete, finish the job and run next if any
pub fn runNextJob(
    queue: *JobQueue,
    run_context: *RunContext,
) !void {
    if (queue.processing) {
        // Already processing a job
        return;
    }

    const job = queue.dequeue() orelse return;
    queue.processing = true;

    defer {
        queue.processing = false;
        // Try to run next job
        runNextJob(queue, run_context) catch {};
    }

    // Run job based on type
    const result = switch (job.job_type) {
        .register => run_context.runRegister(job),
        .update => run_context.runUpdate(job),
        .unregister => run_context.runUnregister(job),
    };

    // Finish the job
    finishJob(job, result.success, result.value);
}

/// Finish a job and resolve its promise.
///
/// Spec: https://w3c.github.io/ServiceWorker/#finish-job
///
/// Algorithm:
/// 1. Resolve or reject the job's promise
/// 2. Resolve equivalent jobs' promises
/// 3. Clean up the job
pub fn finishJob(job: *Job, success: bool, result: ?*anyopaque) void {
    // Resolve this job and all equivalent jobs
    job.resolve(success, result);
}

/// Context for running jobs.
///
/// This provides the callbacks needed to actually perform job operations.
/// In a real implementation, these would connect to script fetching, worker creation, etc.
pub const RunContext = struct {
    /// Callback for register jobs.
    on_register: ?*const fn (job: *const Job) JobResult = null,

    /// Callback for update jobs.
    on_update: ?*const fn (job: *const Job) JobResult = null,

    /// Callback for unregister jobs.
    on_unregister: ?*const fn (job: *const Job) JobResult = null,

    fn runRegister(self: *RunContext, job: *Job) JobResult {
        if (self.on_register) |callback| {
            return callback(job);
        }
        // Default: success with no result
        return .{ .success = true, .value = null };
    }

    fn runUpdate(self: *RunContext, job: *Job) JobResult {
        if (self.on_update) |callback| {
            return callback(job);
        }
        return .{ .success = true, .value = null };
    }

    fn runUnregister(self: *RunContext, job: *Job) JobResult {
        if (self.on_unregister) |callback| {
            return callback(job);
        }
        return .{ .success = true, .value = null };
    }
};

/// Result of running a job.
pub const JobResult = struct {
    success: bool,
    value: ?*anyopaque = null,
};

// =============================================================================
// Tests
// =============================================================================

test "scheduleJob - enqueues job" {
    const allocator = std.testing.allocator;

    var map = ScopeToJobQueueMap.init(allocator);
    defer map.deinit();

    const job = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job.deinit();

    try scheduleJob(&map, job);

    const queue = map.getQueue("https://example.com/").?;
    try std.testing.expectEqual(@as(usize, 1), queue.count());
}

test "scheduleJob - equivalent jobs combined" {
    const allocator = std.testing.allocator;

    var map = ScopeToJobQueueMap.init(allocator);
    defer map.deinit();

    const job1 = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job1.deinit();

    const job2 = try Job.init(allocator, .update, "https://example.com", "https://example.com/");
    defer job2.deinit();

    try scheduleJob(&map, job1);
    try scheduleJob(&map, job2);

    const queue = map.getQueue("https://example.com/").?;
    // Only one job in queue (job2 added to job1's equivalent list)
    try std.testing.expectEqual(@as(usize, 1), queue.count());
    try std.testing.expectEqual(@as(usize, 1), job1.equivalent_jobs.items.len);
}

test "scheduleJob - different scopes not combined" {
    const allocator = std.testing.allocator;

    var map = ScopeToJobQueueMap.init(allocator);
    defer map.deinit();

    const job1 = try Job.init(allocator, .register, "https://example.com", "https://example.com/a/");
    defer job1.deinit();

    const job2 = try Job.init(allocator, .register, "https://example.com", "https://example.com/b/");
    defer job2.deinit();

    try scheduleJob(&map, job1);
    try scheduleJob(&map, job2);

    // Different queues
    const queue_a = map.getQueue("https://example.com/a/").?;
    const queue_b = map.getQueue("https://example.com/b/").?;

    try std.testing.expectEqual(@as(usize, 1), queue_a.count());
    try std.testing.expectEqual(@as(usize, 1), queue_b.count());
}

test "finishJob - resolves job" {
    const allocator = std.testing.allocator;

    const job = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job.deinit();

    var called = false;
    var success_result: bool = false;

    const callback = struct {
        fn cb(called_ptr: *bool, success_ptr: *bool) *const fn (bool, ?*anyopaque) void {
            const S = struct {
                var called_ref: *bool = undefined;
                var success_ref: *bool = undefined;

                fn callback(success: bool, _: ?*anyopaque) void {
                    called_ref.* = true;
                    success_ref.* = success;
                }
            };
            S.called_ref = called_ptr;
            S.success_ref = success_ptr;
            return &S.callback;
        }
    }.cb(&called, &success_result);

    job.on_complete = callback;

    finishJob(job, true, null);

    try std.testing.expect(called);
    try std.testing.expect(success_result);
}

test "finishJob - resolves equivalent jobs" {
    const allocator = std.testing.allocator;

    const job1 = try Job.init(allocator, .register, "https://example.com", "https://example.com/");
    defer job1.deinit();

    const job2 = try Job.init(allocator, .update, "https://example.com", "https://example.com/");
    defer job2.deinit();

    try job1.addEquivalentJob(job2);

    var job1_called = false;
    var job2_called = false;

    const make_callback = struct {
        fn make(flag: *bool) *const fn (bool, ?*anyopaque) void {
            const S = struct {
                var flag_ref: *bool = undefined;
                fn callback(_: bool, _: ?*anyopaque) void {
                    flag_ref.* = true;
                }
            };
            S.flag_ref = flag;
            return &S.callback;
        }
    }.make;

    job1.on_complete = make_callback(&job1_called);
    job2.on_complete = make_callback(&job2_called);

    finishJob(job1, true, null);

    try std.testing.expect(job1_called);
    try std.testing.expect(job2_called);
}
