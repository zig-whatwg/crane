//! Fetch on the event loop.
//!
//! An `AsyncFetch` runs the same `FetchJob` the blocking `fetch()` does, but
//! hands each request HTTP-network fetch sends to its agent's network
//! scheduler and carries on as it is answered, from the agent's event loop's
//! network step (`AgentFetches.pump`). Nothing waits in between: script,
//! timers and other fetches run while the response is on its way.
//!
//! An agent's fetches are its own (`AgentFetches`, on the agent's host): the
//! window agent's and each worker's, each on its own thread, each pumped by
//! its own event loop - never by another agent's, and never by another
//! Browser's.
//!
//! `start` hands the response on with its whole body, as bytes: the client
//! hears nothing until the body has arrived. `startStreaming` hands it on as
//! soon as its headers are in, as HTTP-network fetch does (step 20): its body
//! arrives afterwards, through the pipe the response's body reads
//! (`internal/body_pipe.zig`), which this fetch fills from the transfer.
//! Streaming is the opt-in: a client that reads `body.getBytes()` and knows
//! nothing of pipes would otherwise read an empty body - and freeing the
//! response would cancel the transfer.
//!
//! Its client - `fetch()`, the method, or an XMLHttpRequest - hears the
//! response through `done`, and only ever from `pump`: never from inside
//! `start`, and never from inside a scheduler callback, so the client's code
//! always runs at the top of an event loop step. Queueing the task that acts
//! on it is the client's. When the fetch is entirely over - its body ended,
//! or no one left to read it - the client hears `finished`.
//!
//! A page can end with its fetches in flight. The client says whether it is
//! still there (`alive`), `pump` asks once a turn, and a fetch whose client is
//! gone is terminated - its transfer cancelled, its body failed - and the
//! client is told so (`gone`), and nothing else after. Fetch calls this
//! terminating the fetch group, which happens when its document unloads.

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.async_fetch);
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const internal_response = @import("../internal/response.zig");
const body_pipe = @import("../internal/body_pipe.zig");
const PipeSource = body_pipe.PipeSource;
const clock = @import("clock");
const network = @import("../network/root.zig");
const NetworkScheduler = network.NetworkScheduler;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const fetch_job = @import("fetch_job.zig");
const FetchJob = fetch_job.FetchJob;
const FetchError = fetch_job.FetchError;
const FetchResult = fetch_job.FetchResult;
const FetchOptions = fetch_job.FetchOptions;

pub const Failure = body_pipe.Failure;

pub const AsyncFetch = struct {
    allocator: Allocator,
    job: *FetchJob,
    /// The agent's fetches this one is among, and whose scheduler moves its
    /// transfers.
    fetches: *AgentFetches,
    collect: bool,
    /// The transfer HTTP-network fetch is waiting on, or whose body is
    /// arriving.
    transfer: ?*NetworkScheduler.Job = null,
    /// The transfer has not delivered its headers yet.
    awaiting_head: bool = false,
    /// The network end of the body arriving now: this fetch is its producer
    /// until the body ends, or until nobody reads it.
    source: ?*PipeSource = null,
    /// Fetch's outcome, from the moment the job ends until `pump` hands it to
    /// the client.
    outcome: ?(FetchError!FetchResult) = null,
    /// `done` has run.
    delivered: bool = false,
    client: Client,

    /// Who started the fetch, and hears how it goes.
    pub const Client = struct {
        context: *anyopaque,
        /// Fetch has its response, or knows there is none. The result is the
        /// client's. Unless the fetch collected its body, the body is still
        /// arriving through its pipe.
        done: *const fn (context: *anyopaque, result: FetchError!FetchResult) void,
        /// Whether the client is still there to hear.
        alive: *const fn (context: *anyopaque) bool,
        /// The fetch was terminated because `alive` said no. The fetch is
        /// over, and neither `done` (if it had not run) nor `finished` will
        /// run.
        gone: *const fn (context: *anyopaque) void,
        /// After `done`, the fetch is entirely over: its body has ended, or
        /// nobody was left to read it. The client's last word from it.
        finished: ?*const fn (context: *anyopaque) void = null,
    };

    /// Start fetching `request`, whose ownership passes to the fetch - even
    /// when this fails - on `fetches`, the agent's whose loop will pump it
    /// (dom.agent_fetches; null - no agent - is a network error). The client
    /// hears nothing before the next `pump`, and then hears the response
    /// with its whole body, as bytes.
    pub fn start(
        allocator: Allocator,
        request: *InternalRequest,
        options: FetchOptions,
        fetches: ?*AgentFetches,
        client: Client,
    ) FetchError!*AsyncFetch {
        return begin(allocator, request, options, true, fetches, client);
    }

    /// As `start`, but the client hears the response at its headers, with
    /// its body still arriving through its pipe.
    pub fn startStreaming(
        allocator: Allocator,
        request: *InternalRequest,
        options: FetchOptions,
        fetches: ?*AgentFetches,
        client: Client,
    ) FetchError!*AsyncFetch {
        return begin(allocator, request, options, false, fetches, client);
    }

    fn begin(
        allocator: Allocator,
        request: *InternalRequest,
        options: FetchOptions,
        collect: bool,
        agent_fetches: ?*AgentFetches,
        client: Client,
    ) FetchError!*AsyncFetch {
        // No agent to pump it (a realm with no agent): a network error.
        const fetches = agent_fetches orelse {
            request.deinit();
            return FetchError.NetworkError;
        };
        const job = FetchJob.create(allocator, request, true, options) catch |err| {
            request.deinit();
            return err;
        };
        errdefer job.destroy();

        const self = allocator.create(AsyncFetch) catch return FetchError.OutOfMemory;
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .job = job,
            .fetches = fetches,
            .collect = collect,
            .client = client,
        };
        fetches.live.append(fetches.allocator, self) catch return FetchError.OutOfMemory;

        self.advance(job.start());
        return self;
    }

    /// End the fetch now: its transfer is cancelled, a body still arriving
    /// fails as aborted, and the client hears nothing more. The handle is
    /// gone.
    pub fn terminate(self: *AsyncFetch) void {
        self.terminateWith(.{ .kind = .aborted });
    }

    /// As `terminate`, with the failure a body still arriving ends with.
    /// `failure`'s reason, if any, is the body's from here - or freed, if
    /// there is no body to fail.
    pub fn terminateWith(self: *AsyncFetch, failure: Failure) void {
        if (self.transfer) |transfer| self.fetches.scheduler.cancel(transfer);
        self.transfer = null;
        if (self.source) |source| {
            self.source = null;
            source.fail(failure);
        } else if (failure.reason) |reason| {
            if (failure.release_reason) |release| release(reason);
        }
        self.destroy();
    }

    fn destroy(self: *AsyncFetch) void {
        const live = &self.fetches.live;
        for (live.items, 0..) |f, i| {
            if (f == self) {
                _ = live.orderedRemove(i);
                break;
            }
        }
        if (self.transfer) |transfer| self.fetches.scheduler.cancel(transfer);
        if (self.source) |source| source.fail(.{ .kind = .network });
        if (self.outcome) |outcome| {
            var result = outcome catch null;
            if (result) |*r| r.deinit();
        }
        self.job.destroy();
        self.allocator.destroy(self);
    }

    /// Whether `pump` can hand the outcome to the client now: a collected
    /// body has to have arrived first.
    fn deliverable(self: *const AsyncFetch) bool {
        if (self.outcome == null) return false;
        return !self.collect or self.source == null;
    }

    /// Whether this fetch's response has started arriving and not ended:
    /// lines of its header block are in, or its head is and its body is still
    /// coming off a transfer that is not paused. What `catchUp` waits on.
    pub fn isArriving(self: *const AsyncFetch) bool {
        const job = self.transfer orelse return false;
        if (job.paused) return false;
        if (!self.awaiting_head) return self.source != null;
        var header_bytes: c_long = 0;
        _ = network.curl_ffi.easy_getinfo(job.transfer.handle, network.curl_ffi.c.CURLINFO_HEADER_SIZE, &header_bytes);
        return header_bytes > 0;
    }

    /// Whether the fetch is over: its response delivered, and no body left
    /// arriving.
    fn over(self: *const AsyncFetch) bool {
        return self.delivered and self.source == null and self.transfer == null;
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
                    self.awaiting_head = true;
                    self.transfer = self.fetches.scheduler.startStreaming(
                        self.allocator,
                        needed.request,
                        .{ .context = self, .head = networkHead, .data = networkData, .end = networkEnd },
                    ) catch |err| {
                        // Not sent at all: that is the network's answer.
                        self.awaiting_head = false;
                        next = self.job.resumeNetwork(err);
                        continue;
                    };
                    return;
                },
            }
        }
    }

    /// The response's headers are in: fetch carries on from here, and its
    /// body will arrive through a pipe this fetch fills.
    fn networkHead(context: ?*anyopaque, head: NetworkResponse) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        self.awaiting_head = false;
        const source = PipeSource.create(self.allocator) catch {
            var h = head;
            h.deinit();
            self.cancelTransfer();
            return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
        };
        // A collected body is taken only at its end: pausing it would wait
        // for a reader that never comes. A streamed one pauses while its
        // readers fall behind.
        source.producer = if (self.collect)
            .{ .context = self, .cancel = stopProducing }
        else
            .{ .context = self, .cancel = stopProducing, .pause = pauseTransfer, .unpause = unpauseTransfer };
        self.source = source;
        const pipe = source.branch() catch {
            var h = head;
            h.deinit();
            self.source = null;
            source.fail(.{ .kind = .network });
            self.cancelTransfer();
            return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
        };
        // If fetch does not keep this response - a redirect it follows, a
        // network error - its pipe goes, and with no reader left the source
        // stops this transfer (`stopProducing`) before the next step begins.
        self.advance(self.job.resumeNetworkHead(head, pipe));
    }

    fn networkData(context: ?*anyopaque, bytes: []const u8) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        if (self.source) |source| source.push(bytes);
    }

    fn networkEnd(context: ?*anyopaque, result: NetworkError!void) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        self.transfer = null;
        if (self.awaiting_head) {
            // No response at all: that is the network's answer.
            self.awaiting_head = false;
            result catch |err| return self.advance(self.job.resumeNetwork(err));
            return self.advance(self.job.resumeNetwork(NetworkError.ProtocolError));
        }
        const source = self.source orelse return;
        self.source = null;
        if (result) |_| source.finish() else |_| source.fail(.{ .kind = .network });
    }

    /// The body's source has no reader left: stop the transfer. The source is
    /// not this fetch's to touch after this.
    fn stopProducing(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        self.source = null;
        self.cancelTransfer();
    }

    /// Every reader of the body is behind: stop reading from the socket.
    fn pauseTransfer(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        if (self.transfer) |transfer| self.fetches.scheduler.pause(transfer);
    }

    fn unpauseTransfer(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        if (self.transfer) |transfer| self.fetches.scheduler.unpause(transfer);
    }

    fn cancelTransfer(self: *AsyncFetch) void {
        if (self.transfer) |transfer| self.fetches.scheduler.cancel(transfer);
        self.transfer = null;
    }

    /// A collected response gets its body as bytes; if the body failed, the
    /// response is a network error, as the collected fetch always reported.
    fn settleCollected(outcome: FetchError!FetchResult) FetchError!FetchResult {
        var result = outcome catch |err| return err;
        const body = result.response.body orelse return result;
        const pipe = body.pipe orelse return result;
        if (pipe.state == .errored) {
            const allocator = result.response.allocator;
            result.response.deinit();
            result.response = internal_response.networkError(allocator) catch {
                result.timing_info.deinit();
                return FetchError.OutOfMemory;
            };
            return result;
        }
        body.settlePipe() catch {
            result.deinit();
            return FetchError.OutOfMemory;
        };
        return result;
    }
};

/// One agent's fetches on its event loop: the network scheduler that moves
/// their transfers - a curl multi handle, driven by the agent's thread alone
/// - and every fetch not yet over, oldest first. Owned by the agent's host
/// (html AgentHost.fetches) and pumped by the agent's event loop once a
/// turn; reached from a realm through its agent (dom.agent_fetches). A
/// worker's are its own, on its own thread.
pub const AgentFetches = struct {
    allocator: Allocator,
    scheduler: NetworkScheduler,
    /// Every fetch of the agent that has not ended, oldest first.
    live: std.ArrayListUnmanaged(*AsyncFetch) = .empty,

    pub fn init(allocator: Allocator) AgentFetches {
        return .{ .allocator = allocator, .scheduler = NetworkScheduler.init(allocator) };
    }

    /// The agent's end, after its realms' (each of which swept the fetches
    /// it left, while the agent lived): the scheduler closes its multi
    /// handle. A fetch still here was never swept - its client outlived its
    /// agent - and is left as it is: ending it would reach an engine that is
    /// gone.
    pub fn deinit(self: *AgentFetches) void {
        if (self.live.items.len != 0) log.warn("{d} fetches outlived their agent", .{self.live.items.len});
        self.live.deinit(self.allocator);
        self.scheduler.deinit();
    }

    /// The event loop's network step: one turn's progress for every fetch of
    /// the agent. Fetches whose client is gone are terminated first
    /// (`sweep`); then every transfer moves as far as it can without
    /// waiting; then each fetch that has its response - on the network's
    /// answer, or with no network needed - is handed to its client, and each
    /// that is over tells its client so. Returns whether anything happened.
    pub fn pump(self: *AgentFetches) bool {
        var progressed = self.sweep();

        if (self.scheduler.pump()) progressed = true;

        // One at a time, from the front afresh: a client may start or
        // terminate fetches from its callbacks.
        while (true) {
            if (self.nextDeliverable()) |f| {
                var outcome = f.outcome.?;
                f.outcome = null;
                if (f.collect) outcome = AsyncFetch.settleCollected(outcome);
                f.delivered = true;
                // If it is over already, the next round tells the client so.
                f.client.done(f.client.context, outcome);
                progressed = true;
                continue;
            }
            if (self.nextOver()) |f| {
                const client = f.client;
                f.destroy();
                if (client.finished) |finished| finished(client.context);
                progressed = true;
                continue;
            }
            break;
        }
        return progressed;
    }

    /// INTERIM - let the network catch up with a response that is arriving,
    /// for at most `budget_ms`, before a deadline is judged. It emulates the
    /// socket reads a browser's network thread makes during a long task:
    /// Crane's networking advances only between tasks, so a response that
    /// started arriving while script held the loop sits half-read until the
    /// next pump - and a peer that holds the rest until its first segment is
    /// acknowledged (Nagle; wptserve writes a header block line by line)
    /// releases it only after that read, one round trip later.
    /// xhr/xhr-timeout-longtask.any.js timed out when the 150 ms timer's
    /// single network step found the header block incomplete, its rest ~1 ms
    /// away
    /// (docs/lessons/architecture-single-threaded-networking-must-send-the-request.md
    /// - "read the socket before declaring a timeout"). The real fix is
    /// networking that progresses while script runs; this goes when that
    /// lands.
    ///
    /// Bounded and inert: it pumps the network and waits on its sockets -
    /// never runs script, never dispatches an event, never past the budget -
    /// and only while `fetch_slot`'s fetch is arriving
    /// (`AsyncFetch.isArriving`). A response that has not started arriving
    /// returns at once, and is judged as it always was. `fetch_slot` is the
    /// caller's handle, which the fetch's `finished`/`gone` callbacks clear:
    /// a pump may end and free the fetch.
    pub fn catchUp(self: *AgentFetches, fetch_slot: *const ?*AsyncFetch, budget_ms: u32) void {
        const deadline = clock.monotonicMillis() + budget_ms;
        while (fetch_slot.*) |f| {
            if (!f.isArriving()) return;
            const now = clock.monotonicMillis();
            if (now >= deadline) return;
            self.scheduler.waitForSockets(@intCast(@min(deadline - now, 1)));
            _ = self.pump();
        }
    }

    /// Terminate every fetch whose client is gone, and tell each client so -
    /// Fetch's "terminate a fetch group" for every group whose document went
    /// away. `pump` does this at the start of each turn; teardown can call it
    /// directly, right after a realm ends, so the fetches it left release
    /// what they hold - a promise, and through it the realm - at once rather
    /// than on the next turn. Returns whether any fetch was terminated.
    pub fn sweep(self: *AgentFetches) bool {
        var terminated = false;
        var i: usize = 0;
        while (i < self.live.items.len) {
            const f = self.live.items[i];
            if (f.client.alive(f.client.context)) {
                i += 1;
                continue;
            }
            const client = f.client;
            f.terminateWith(.{ .kind = .network });
            client.gone(client.context);
            terminated = true;
        }
        return terminated;
    }

    fn nextDeliverable(self: *const AgentFetches) ?*AsyncFetch {
        for (self.live.items) |f| {
            if (f.deliverable()) return f;
        }
        return null;
    }

    fn nextOver(self: *const AgentFetches) ?*AsyncFetch {
        for (self.live.items) |f| {
            if (f.over()) return f;
        }
        return null;
    }

    /// The agent's fetches that have not ended. While there are any, its
    /// event loop has work: it must keep turning, and not sleep through them.
    pub fn inFlight(self: *const AgentFetches) usize {
        return self.live.items.len;
    }
};
