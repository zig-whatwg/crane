//! The network scheduler: every asynchronous transfer, driven by one libcurl
//! multi handle, a step at a time from the event loop.
//!
//! `LibcurlBackend.send` blocks in `curl_easy_perform` until its response has
//! arrived, and everything on the thread - script, timers, other fetches -
//! waits with it. A transfer started here instead is added to the multi
//! handle, and `pump` moves every transfer as far as its sockets allow
//! without waiting (`curl_multi_perform`), then hands each one that finished
//! to its completion callback. The event loop calls `pump` once per turn.
//!
//! The design is WebKit's curl port (`CurlRequestScheduler`,
//! `Source/WebCore/platform/network/curl/`), less its thread: a scheduler owns
//! the multi handle and the map from easy handle to client; a transfer is
//! finalized exactly once, whether it completed or was cancelled; the easy
//! handle is removed outside curl's own iteration; and the completion reaches
//! its requester as a separate step - WebKit's `callOnMainThread`, here the
//! caller's own task queueing. WebKit runs the multi handle on a network
//! thread. This engine runs script, workers included, on one thread, so the
//! scheduler is driven from that thread's event loop instead and needs no lock.
//!
//! A transfer is the same `Transfer` a blocking send performs, so a request is
//! configured and its response built one way on both paths.

const std = @import("std");
const Allocator = std.mem.Allocator;
const clock = @import("clock");
const curl = @import("curl_ffi.zig");
const curl_backend = @import("curl_backend.zig");
const backend = @import("backend.zig");
const Transfer = curl_backend.Transfer;
const NetworkRequest = backend.NetworkRequest;
const NetworkResponse = backend.NetworkResponse;
const NetworkError = backend.NetworkError;

const log = std.log.scoped(.network_scheduler);

/// Called once when a transfer ends, with its response or the reason there is
/// none. The response is the callee's. It runs inside `pump`, so it must not
/// block; it may start and cancel other transfers.
pub const Completion = *const fn (context: ?*anyopaque, result: NetworkError!NetworkResponse) void;

pub const StartOptions = struct {
    /// Send and store cookies for this transfer - HTTP-network fetch does,
    /// unless the request's credentials mode is "omit".
    cookies: bool = true,
};

pub const NetworkScheduler = struct {
    allocator: Allocator,
    /// Made on the first `start`.
    multi: ?*curl.CURLM = null,
    /// Every transfer not yet finalized: in the multi handle, or waiting out
    /// a retry's backoff.
    jobs: std.ArrayListUnmanaged(*Job) = .empty,

    /// A transfer the scheduler drives, and who hears when it ends.
    pub const Job = struct {
        /// The transfer's allocator, which made this job too.
        allocator: Allocator,
        transfer: *Transfer,
        on_complete: Completion,
        context: ?*anyopaque,
        /// Attempts that ended without a connection.
        attempt: u8 = 0,
        /// In the multi handle. False while a retry waits for `retry_at_ns`,
        /// and once the transfer has ended.
        running: bool = false,
        retry_at_ns: i128 = 0,
        /// How the last attempt ended, from the moment curl reports it until
        /// `pump` delivers it.
        ended: ?curl.CURLcode = null,
    };

    pub fn init(allocator: Allocator) NetworkScheduler {
        return .{ .allocator = allocator };
    }

    /// Cancel every transfer, with no callbacks, and close the multi handle.
    pub fn deinit(self: *NetworkScheduler) void {
        while (self.jobs.items.len > 0) self.cancel(self.jobs.items[self.jobs.items.len - 1]);
        self.jobs.deinit(self.allocator);
        if (self.multi) |multi| _ = curl.multi_cleanup(multi);
        self.multi = null;
    }

    /// Start a transfer for `request`, whose response `on_complete` receives.
    /// The transfer and the response are made with `allocator`. It is under
    /// way when this returns, but only `pump` delivers its end; and `request`
    /// is not needed after this returns - the transfer copies what curl reads.
    pub fn start(
        self: *NetworkScheduler,
        allocator: Allocator,
        request: *const NetworkRequest,
        options: StartOptions,
        on_complete: Completion,
        context: ?*anyopaque,
    ) NetworkError!*Job {
        if (curl_backend.getGlobalShare() == null) curl_backend.globalInit() catch return NetworkError.Unknown;
        const multi = self.multi orelse blk: {
            const m = curl.multi_init() orelse return NetworkError.OutOfMemory;
            self.multi = m;
            break :blk m;
        };

        const transfer = try Transfer.create(allocator, request, .{ .own_cookies = options.cookies });
        errdefer transfer.destroy();

        const job = allocator.create(Job) catch return NetworkError.OutOfMemory;
        errdefer allocator.destroy(job);
        job.* = .{
            .allocator = allocator,
            .transfer = transfer,
            .on_complete = on_complete,
            .context = context,
        };
        self.jobs.append(self.allocator, job) catch return NetworkError.OutOfMemory;
        errdefer _ = self.jobs.pop();

        transfer.prepareAttempt();
        if (curl.multi_add_handle(multi, transfer.handle) != curl.CURLM_OK) return NetworkError.OutOfMemory;
        job.running = true;

        kick(multi, transfer);
        return job;
    }

    /// Rounds `kick` gives a new transfer to put its request on the wire, and
    /// the longest each waits for its sockets.
    const kick_rounds = 4;
    const kick_wait_ms = 1;

    /// Get a new transfer under way - resolve, connect, send its request - as
    /// far as that goes without waiting. A browser's network thread would;
    /// left for the next pump, the request would not leave until the script
    /// that made it had finished, and a long task would count against a
    /// timeout time the server never had (xhr/xhr-timeout-longtask.any.js).
    /// A non-blocking connect is not writable within the `perform` that
    /// started it, so this goes a few rounds - perform, then ask the sockets
    /// without waiting - and stops once the request is sent. Across a DNS
    /// lookup or a TLS handshake it gets no further than those allow. What
    /// ends here is delivered by `pump`: nothing is read from the queue.
    fn kick(multi: *curl.CURLM, transfer: *Transfer) void {
        var round: usize = 0;
        while (round < kick_rounds) : (round += 1) {
            var still_running: c_int = 0;
            _ = curl.multi_perform(multi, &still_running);
            var sent: c_long = 0;
            _ = curl.easy_getinfo(transfer.handle, curl.c.CURLINFO_REQUEST_SIZE, &sent);
            if (sent > 0 or still_running == 0) return;
            var ready: c_int = 0;
            _ = curl.multi_poll(multi, kick_wait_ms, &ready);
        }
    }

    /// End `job` now. Its callback never runs, and what it received is
    /// dropped. Safe from a completion callback, including for a job that
    /// ended in the same `pump` and has not been delivered yet. `job` must not
    /// have been delivered: its callback is the end of it.
    pub fn cancel(self: *NetworkScheduler, job: *Job) void {
        const index = self.indexOf(job) orelse return;
        _ = self.jobs.orderedRemove(index);
        if (job.running) _ = curl.multi_remove_handle(self.multi.?, job.transfer.handle);
        job.transfer.destroy();
        job.allocator.destroy(job);
    }

    /// Transfers not yet finalized.
    pub fn inFlight(self: *const NetworkScheduler) usize {
        return self.jobs.items.len;
    }

    /// Move every transfer as far as it can go without waiting, and deliver
    /// the ones that finished. Returns whether any callback ran.
    pub fn pump(self: *NetworkScheduler) bool {
        const multi = self.multi orelse return false;
        if (self.jobs.items.len == 0) return false;

        // A retry whose backoff has run out goes back in the multi handle.
        const now = clock.monotonicNanos();
        for (self.jobs.items) |job| {
            if (job.running or job.retry_at_ns > now) continue;
            job.transfer.prepareAttempt();
            if (curl.multi_add_handle(multi, job.transfer.handle) == curl.CURLM_OK) job.running = true;
        }

        var still_running: c_int = 0;
        _ = curl.multi_perform(multi, &still_running);

        // Note what ended. A message does not survive the removal of its
        // handle, so each is read out first; and no callback runs while curl
        // is iterating its queue.
        while (true) {
            var queued: c_int = 0;
            const msg = curl.multi_info_read(multi, &queued) orelse break;
            if (msg.msg != curl.CURLMSG_DONE) continue;
            const handle: *curl.CURL = @ptrCast(msg.easy_handle orelse continue);
            const result = msg.data.result;
            const job = for (self.jobs.items) |j| {
                if (j.running and j.transfer.handle == handle) break j;
            } else continue;
            _ = curl.multi_remove_handle(multi, handle);
            job.running = false;
            job.ended = result;
        }

        // Deliver them one at a time, finding the next afresh each time: a
        // callback may cancel a job that also ended, or start one that takes
        // a freed job's address - and a new job has not ended.
        var delivered = false;
        while (self.nextEnded()) |job| {
            const result = job.ended.?;
            job.ended = null;
            if (Transfer.retryBackoffNs(result, job.attempt)) |backoff_ns| {
                job.attempt += 1;
                job.retry_at_ns = clock.monotonicNanos() + backoff_ns;
                log.debug("{s} {s}: connection failed, retrying in {d}ms", .{ job.transfer.method, job.transfer.url, backoff_ns / std.time.ns_per_ms });
                continue;
            }
            const index = self.indexOf(job).?;
            _ = self.jobs.orderedRemove(index);
            const on_complete = job.on_complete;
            const context = job.context;
            const response = job.transfer.finish(result);
            job.transfer.destroy();
            job.allocator.destroy(job);
            on_complete(context, response);
            delivered = true;
        }
        return delivered;
    }

    fn nextEnded(self: *const NetworkScheduler) ?*Job {
        for (self.jobs.items) |job| {
            if (job.ended != null) return job;
        }
        return null;
    }

    fn indexOf(self: *const NetworkScheduler, job: *const Job) ?usize {
        for (self.jobs.items, 0..) |j, i| {
            if (j == job) return i;
        }
        return null;
    }
};

// =============================================================================
// The thread's scheduler
// =============================================================================

/// The scheduler the event loop pumps. One per thread: script, and the
/// transfers it starts, belong to the thread that runs it.
threadlocal var thread_scheduler: ?NetworkScheduler = null;

/// This thread's scheduler, made on first use. Only its list of jobs is its
/// own, kept for the thread's lifetime; each job, its transfer and its
/// response use the allocator the caller passes to `start`.
pub fn threadScheduler() *NetworkScheduler {
    if (thread_scheduler == null) thread_scheduler = NetworkScheduler.init(std.heap.smp_allocator);
    return &thread_scheduler.?;
}

/// This thread's scheduler if one was ever made - null costs nothing to pump.
pub fn existingThreadScheduler() ?*NetworkScheduler {
    return if (thread_scheduler) |*scheduler| scheduler else null;
}
