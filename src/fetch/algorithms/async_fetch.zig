//! Fetch on the event loop.
//!
//! An `AsyncFetch` runs the same `FetchJob` the blocking `fetch()` does, but
//! hands each request HTTP-network fetch sends to the thread's network
//! scheduler and carries on when it is answered, from the event loop's network
//! step (`pump`). Nothing waits in between: script, timers and other fetches
//! run while the response is on its way.
//!
//! Its client - `fetch()`, the method - hears the result through `done`, and
//! only ever from `pump`: never from inside `start`, and never from inside the
//! scheduler's own completion callback, so the client's code always runs at
//! the top of an event loop step. Queueing the fetch task that settles the
//! promise is the client's.
//!
//! A page can end with its fetches in flight. The client says whether it is
//! still there (`alive`), `pump` asks once a turn, and a fetch whose client is
//! gone is terminated - its transfer cancelled - and the client is told so
//! (`gone`) instead of `done`. Fetch calls this terminating the fetch group,
//! which happens when its document unloads.

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const network = @import("../network/root.zig");
const NetworkScheduler = network.NetworkScheduler;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const fetch_job = @import("fetch_job.zig");
const FetchJob = fetch_job.FetchJob;
const FetchError = fetch_job.FetchError;
const FetchResult = fetch_job.FetchResult;
const FetchOptions = fetch_job.FetchOptions;

pub const AsyncFetch = struct {
    allocator: Allocator,
    job: *FetchJob,
    scheduler: *NetworkScheduler,
    /// The transfer HTTP-network fetch is waiting on, if any.
    transfer: ?*NetworkScheduler.Job = null,
    /// Fetch's outcome, from the moment the job ends until `pump` hands it to
    /// the client.
    outcome: ?(FetchError!FetchResult) = null,
    client: Client,

    /// Who started the fetch, and hears how it ends.
    pub const Client = struct {
        context: *anyopaque,
        /// Fetch has ended: its response, or why there is none. The result is
        /// the client's, and the fetch is over - its handle is gone.
        done: *const fn (context: *anyopaque, result: FetchError!FetchResult) void,
        /// Whether the client is still there to hear.
        alive: *const fn (context: *anyopaque) bool,
        /// The fetch was terminated because `alive` said no. The fetch is
        /// over, and `done` will never run.
        gone: *const fn (context: *anyopaque) void,
    };

    /// Start fetching `request`, whose ownership passes to the fetch - even
    /// when this fails. The client hears nothing before the next `pump`.
    pub fn start(
        allocator: Allocator,
        request: *InternalRequest,
        options: FetchOptions,
        scheduler: *NetworkScheduler,
        client: Client,
    ) FetchError!*AsyncFetch {
        const job = FetchJob.create(allocator, request, true, options) catch |err| {
            request.deinit();
            return err;
        };
        errdefer job.destroy();

        const self = allocator.create(AsyncFetch) catch return FetchError.OutOfMemory;
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .job = job, .scheduler = scheduler, .client = client };
        live.append(std.heap.smp_allocator, self) catch return FetchError.OutOfMemory;

        self.advance(job.start());
        return self;
    }

    /// End the fetch now: its transfer is cancelled, and neither `done` nor
    /// `gone` runs. The handle is gone.
    pub fn terminate(self: *AsyncFetch) void {
        if (self.transfer) |transfer| self.scheduler.cancel(transfer);
        self.transfer = null;
        self.destroy();
    }

    fn destroy(self: *AsyncFetch) void {
        for (live.items, 0..) |f, i| {
            if (f == self) {
                _ = live.orderedRemove(i);
                break;
            }
        }
        if (self.outcome) |outcome| {
            var result = outcome catch null;
            if (result) |*r| r.deinit();
        }
        self.job.destroy();
        self.allocator.destroy(self);
    }

    /// Take the job's next step: hand its request to the network, or keep
    /// its outcome for `pump` to deliver.
    fn advance(self: *AsyncFetch, step: FetchError!FetchJob.Step) void {
        var next = step;
        while (true) {
            const s = next catch |err| {
                self.outcome = err;
                return;
            };
            switch (s) {
                .done => {
                    self.outcome = self.job.takeResult();
                    return;
                },
                .network => |needed| {
                    self.transfer = self.scheduler.start(
                        self.allocator,
                        needed.request,
                        .{ .cookies = needed.cookies },
                        networkAnswered,
                        self,
                    ) catch |err| {
                        // Not sent at all: that is the network's answer.
                        next = self.job.resumeNetwork(err);
                        continue;
                    };
                    return;
                },
            }
        }
    }

    /// The scheduler's completion: HTTP-network fetch has its answer.
    fn networkAnswered(context: ?*anyopaque, result: NetworkError!NetworkResponse) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        self.transfer = null;
        self.advance(self.job.resumeNetwork(result));
    }
};

/// Every fetch on this thread that has not ended, oldest first.
threadlocal var live: std.ArrayListUnmanaged(*AsyncFetch) = .empty;

/// The event loop's network step: one turn's progress for every fetch on this
/// thread, on the thread's scheduler. Returns whether anything happened.
pub fn pump() bool {
    return pumpWith(network.scheduler.existingThreadScheduler());
}

/// `pump`, with the transfers on `scheduler`: fetches whose client is gone are
/// terminated first (`sweep`); then every transfer moves as far as it can
/// without waiting; then each fetch that ended - on the network's answer, or
/// with no network needed - is handed to its client.
pub fn pumpWith(scheduler: ?*NetworkScheduler) bool {
    var progressed = sweep();

    if (scheduler) |s| {
        if (s.pump()) progressed = true;
    }

    // One at a time, from the front afresh: a client may start or terminate
    // fetches from `done`.
    while (nextEnded()) |f| {
        const outcome = f.outcome.?;
        f.outcome = null;
        const client = f.client;
        f.destroy();
        client.done(client.context, outcome);
        progressed = true;
    }
    return progressed;
}

/// Terminate every fetch whose client is gone, and tell each client so -
/// Fetch's "terminate a fetch group" for every group whose document went
/// away. `pump` does this at the start of each turn; teardown can call it
/// directly, right after a realm ends, so the fetches it left release what
/// they hold - a promise, and through it the realm - at once rather than on
/// the next turn. Returns whether any fetch was terminated.
pub fn sweep() bool {
    var terminated = false;
    var i: usize = 0;
    while (i < live.items.len) {
        const f = live.items[i];
        if (f.client.alive(f.client.context)) {
            i += 1;
            continue;
        }
        const client = f.client;
        f.terminate();
        client.gone(client.context);
        terminated = true;
    }
    return terminated;
}

fn nextEnded() ?*AsyncFetch {
    for (live.items) |f| {
        if (f.outcome != null) return f;
    }
    return null;
}

/// Fetches on this thread that have not ended. While there are any, the
/// event loop has work: it must keep turning, and not sleep through them.
pub fn inFlight() usize {
    return live.items.len;
}
