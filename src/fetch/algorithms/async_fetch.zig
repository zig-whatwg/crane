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
//!
//! Except a keepalive one: Fetch 2.4's "terminated" step 1 leaves a record
//! whose request's keepalive is true, and such a fetch goes on without its
//! client - KEPT (`AsyncFetch.keep`) - on its agent's network side, until it
//! is over, it has run for `AgentFetches.kept_limit_ms`, or its agent ends.
//! See `keep` for what a kept fetch may still reach.

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.async_fetch);
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const internal_response = @import("../internal/response.zig");
const body_pipe = @import("../internal/body_pipe.zig");
const PipeSource = body_pipe.PipeSource;
const clock = @import("clock");
const platform = @import("platform");
const network = @import("../network/root.zig");
const NetworkScheduler = network.NetworkScheduler;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const fetch_job = @import("fetch_job.zig");
const FetchJob = fetch_job.FetchJob;
const FetchError = fetch_job.FetchError;
const FetchResult = fetch_job.FetchResult;
const FetchOptions = fetch_job.FetchOptions;
const service_worker_fetch = @import("../internal/service_worker_fetch.zig");
const BodyRelay = service_worker_fetch.BodyRelay;
const Body = @import("../internal/body.zig").Body;

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
    awaiting_body: bool = false,
    /// The network end of the body arriving now: this fetch is its producer
    /// until the body ends, or until nobody reads it.
    source: ?*PipeSource = null,
    /// HTTP fetch step 3's call to a service worker, while its answer is
    /// awaited: `AgentFetches.pump` asks it every turn. BORROWED from the job,
    /// which holds it.
    service_worker_call: ?*service_worker_fetch.Call = null,
    /// A service worker's response body arriving from its thread (this
    /// fetch's reference), and the source it is drained into each turn - the
    /// one its response's body reads. Both null once the body has ended or
    /// nobody reads it.
    relay: ?*BodyRelay = null,
    relay_source: ?*PipeSource = null,
    /// HTTP fetch step 3.2's tee of a stream request body for the service
    /// worker that handles it: this fetch writes its branch to the relay the
    /// worker's realm reads, each turn (`pumpUpload`), until the body ends or
    /// the worker stops reading. The fetch is not over while it does.
    upload: ?service_worker_fetch.Upload = null,
    /// The `.request_body` step: HTTP fetch step 4 waits for the request's
    /// stream body to arrive whole (`pump` asks each turn).
    awaiting_request_body: bool = false,
    /// The `.document_resource` step: main fetch step 12 waits for its
    /// preloaded response candidate (`pump` asks each turn).
    awaiting_document_resource: bool = false,
    /// Handle Fetch 13.3.4's race, while the call races the network (and,
    /// when the network's response won, until its body has arrived).
    race: Race = .{},
    /// A streamed body's transfer pauses while its readers fall behind. Off
    /// for a race's network side whose raced fetch collects: nobody reads
    /// that body until it has all arrived.
    pause_body: bool = true,
    /// For a race's network side: the raced fetch, which hears its body's
    /// end (`raceBodyEnded`) - the raced fetch's job reports it.
    race_owner: ?*AsyncFetch = null,
    /// The body arriving now is the one whose end the job waits for
    /// (FetchJob.awaitsBodyEnd: its report timing steps run then) - or, for a
    /// race's network side, the one its raced fetch does.
    track_body_end: bool = false,
    /// The bytes of the body arriving now, as its producer gave them - the
    /// network's with their content codings undone (the body info's decoded
    /// size, HTTP-network fetch 18.1.1.1.10).
    body_bytes: u64 = 0,
    /// The same body as it arrived, before its codings were undone (the
    /// encoded size, 18.1.1.1.8): the network's count (`networkEncoded`);
    /// a service worker's body has none to undo.
    encoded_bytes: u64 = 0,
    /// Whether the body's end may still be reported: false once the
    /// client has gone (`sweep`) - its global hears nothing more.
    reporting: bool = true,
    /// Fetch's outcome, from the moment the job ends until `pump` hands it to
    /// the client.
    outcome: ?(FetchError!FetchResult) = null,
    /// `done` has run.
    delivered: bool = false,
    /// The Browser's fetch observer holds this fetch (network/observer.zig):
    /// at the REQUEST stage (the request HTTP-network fetch was about to
    /// send), the RESPONSE stage (the network's answer: `held_head` and
    /// `held_pipe`, or `held_error`) or the AUTH stage (the job's `.auth`
    /// prompt). The fetch waits for the decision (`resumeIntercepted`).
    held: ?network.observer.Stage = null,
    /// How many holders let it go at this stage already (each continue asks
    /// the next: chained sessions).
    hold_chain: u32 = 0,
    /// The response stage's answer until the decision: its head and the pipe
    /// its body arrives through (the transfer goes on into it), or no
    /// response at all. OWNED.
    held_head: ?NetworkResponse = null,
    held_pipe: ?*body_pipe.BodyPipe = null,
    held_error: ?NetworkError = null,
    /// Interception.readBody: a second reader of the held body (`tee`), what
    /// it read, and who waits for its end. The held pipe keeps every byte
    /// for the fetch, whatever the decision.
    body_tee: ?*body_pipe.BodyPipe = null,
    body_read: std.ArrayListUnmanaged(u8) = .empty,
    body_readers: std.ArrayListUnmanaged(network.observer.BodyReader) = .empty,
    body_read_failed: bool = false,
    body_read_done: bool = false,
    /// When its client went and it was kept (`keep`, the agent's monotonic
    /// clock in milliseconds); null while it has a client.
    kept_since_ms: ?i64 = null,
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

    /// Service Workers Handle Fetch 13.3.4, "race-network-and-fetch-handler":
    /// the request is fetched from the network ("fetch given request",
    /// 13.3.4.5.2) by a second AsyncFetch on the same agent's fetches, beside
    /// the worker's fetch event, and the first usable answer is this fetch's
    /// - the spec's queue of race results:
    ///
    /// 1. the network's response with an ok status, while the worker has not
    ///    answered (13.3.4.5.2.1.2): the network wins - the call is lost
    ///    (its event still runs, its answer is freed) and the response, its
    ///    body still arriving through the network side, is handed to HTTP
    ///    fetch step 3.5 as Handle Fetch's (13.3.4.14);
    /// 2. the worker's response or network error first (13.3.4.7.2-7.4):
    ///    the network side is aborted - its transfer cancelled, a response
    ///    it kept freed;
    /// 3. the worker falls back: the race's response, whatever its status,
    ///    once it has one (Create Fetch Event and Dispatch step 21.3, "wait
    ///    until raceResponse's value is not pending"). Stated deviation: the
    ///    network side is not aborted then, where step 13.3.4.7.2 would abort
    ///    the fetch whose response it returns - Chromium commits that
    ///    response instead (ServiceWorkerMainResourceLoader::
    ///    DidDispatchFetchEvent: a fallback after the race started is
    ///    kWithoutServiceWorker, "not to dispatch additional network request
    ///    for fallback");
    /// 4. the network's response without an ok status (or a network error)
    ///    while the worker has not answered: kept - it is not enqueued, and
    ///    the worker decides.
    ///
    /// The network side is this fetch's: it is ended with it, and this
    /// fetch is not over - nor, collected, deliverable - until the winning
    /// network response's body has arrived.
    const Race = struct {
        /// The network side, until it is over. In `fetches.live`, after this
        /// fetch.
        network: ?*AsyncFetch = null,
        /// Its outcome, delivered while the worker had not decided: kept
        /// (case 4) until the worker does.
        kept: ?(FetchError!FetchResult) = null,
        /// The worker fell back before the network side delivered: its
        /// outcome is the answer (case 3).
        fallback: bool = false,
        /// The network side's response is the answer: its body's end is this
        /// fetch's job's to report.
        network_taken: bool = false,
        /// The network side's body ended before its response was taken: the
        /// sizes its handover reports.
        body_sizes: ?fetch_job.BodySizes = null,
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
        // SRI must fully read before handover. Existing collect mode gives
        // the source a producer that never pauses waiting for a reader.
        const collect_body = collect or request.integrity_metadata.len != 0;
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
            .collect = collect_body,
            .client = client,
        };
        fetches.live.append(fetches.allocator, self) catch return FetchError.OutOfMemory;

        // A client that takes the whole body: its response may be kept for
        // its document (FetchJob.keepForDocument).
        job.keeps_whole_body = collect;
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
        // The client ended the fetch - an abort, or its element stopped
        // loading - while the body handed over was still arriving: for
        // Resource Timing that body ends here, with what arrived of it, as
        // Chromium reports a load its client cancelled (resource_fetcher.cc
        // HandleLoaderError; resource-timing/initiator-type/video.html's
        // <video src>, whose media element stops reading). A fetch whose
        // client has gone (`sweep`) reports nothing.
        if (self.reporting) self.endBody() else self.track_body_end = false;
        if (self.transfer) |transfer| self.fetches.scheduler.cancel(transfer);
        self.transfer = null;
        if (self.source) |source| {
            self.source = null;
            source.fail(failure);
        } else if (self.relay_source) |source| {
            self.relay_source = null;
            source.fail(failure);
        } else if (failure.reason) |reason| {
            if (failure.release_reason) |release| release(reason);
        }
        self.destroy();
    }

    /// Whether this fetch fills an entry its document keeps
    /// (FetchJob.keepForDocument) and has not handed its response over: a
    /// client that lets go of it may leave it running for the document
    /// (`rebind`) rather than terminate it.
    pub fn keepsForDocument(self: *const AsyncFetch) bool {
        return !self.delivered and self.job.document_registration != null;
    }

    /// The fetch goes on for a new client - one that only drops its response
    /// (a style sheet fetch its element left, for its document's entry). The
    /// old client hears nothing more.
    pub fn rebind(self: *AsyncFetch, client: Client) void {
        self.client = client;
    }

    /// Whether this fetch goes on without its client once the client is
    /// gone: its request's keepalive is true (Fetch 2.4 "terminated" step 1
    /// terminates only the others) and its response has not been handed
    /// over - once it has, the request is done with the network as far as a
    /// keepalive request goes, and nobody is left to read the response.
    /// WebKit's rule: NetworkResourceLoader::abort keeps a load whose
    /// `options.keepAlive` is set and whose `m_response.isNull()`. A race's
    /// network side is its raced fetch's to end.
    pub fn outlivesClient(self: *const AsyncFetch) bool {
        return self.job.request.keepalive and !self.delivered and self.race_owner == null and self.kept_since_ms == null;
    }

    /// The fetch's client is gone and the fetch goes on without it, its
    /// response ignored, on its agent's network side (`fetches`), from
    /// `now_ms`. The client hears nothing more: the caller tells it it is
    /// gone. The design is WebKit's and Chromium's, not their code -
    /// WebKit's NetworkResourceLoader::abort sets m_isKeptAlive and
    /// transfers the loader to its session (NetworkSession::addKeptAliveLoad),
    /// whose end aborts it; Chromium's KeepAliveURLLoader, owned by its
    /// storage partition's KeepAliveURLLoaderService, drops the response
    /// once its renderer is gone.
    ///
    /// What a kept fetch may still reach: its own request - the policy
    /// container, URL and body are the request's clones, its CSP check on a
    /// redirect reads the clone - and what its Browser owns and frees only
    /// after every agent's fetches (the cookie jar, the network context, the
    /// blob URL store, the service worker route). Nothing of its client:
    /// the request's reporters - which name the client's realm, resolved at
    /// use and answering nothing once it retired - are dropped here, and so
    /// are its traversable (no prompt can be shown for a document that is
    /// gone) and the job's process-response callback. It reports nothing.
    pub fn keep(self: *AsyncFetch, now_ms: i64) void {
        self.kept_since_ms = now_ms;
        self.client = kept_client;
        self.reporting = false;
        self.job.options.process_response = null;
        const request = self.job.request;
        request.csp_violation_reporter = null;
        request.timing_reporter = null;
        request.integrity_violation_reporter = null;
        request.coep_violation_reporter = null;
        if (request.traversable_for_user_prompts == .traversable) request.traversable_for_user_prompts = .no_traversable;
        request.user_agent_client = null;
    }

    /// A kept fetch's client: no one. A response is dropped as it comes.
    const kept_client: Client = .{ .context = undefined, .done = keptDone, .alive = keptAlive, .gone = keptGone };

    fn keptDone(_: *anyopaque, outcome: FetchError!FetchResult) void {
        var result = outcome catch return;
        result.deinit();
    }

    fn keptAlive(_: *anyopaque) bool {
        return true;
    }

    fn keptGone(_: *anyopaque) void {}

    fn destroy(self: *AsyncFetch) void {
        self.track_body_end = false;
        // The race's network side is this fetch's to end.
        self.endRace();
        const live = &self.fetches.live;
        for (live.items, 0..) |f, i| {
            if (f == self) {
                _ = live.orderedRemove(i);
                break;
            }
        }
        if (self.transfer) |transfer| self.fetches.scheduler.cancel(transfer);
        if (self.source) |source| source.fail(.{ .kind = .network });
        if (self.relay_source) |source| source.fail(.{ .kind = .network });
        // A request its observer still holds: the hold is dead (the fetch
        // is dropped as one waiting for its transfer is), and a held
        // response goes with it.
        if (self.held != null) {
            self.held = null;
            if (network.observer.of(self.job.request)) |o| if (o.interception_dropped) |dropped| dropped(o.context, self.job.request.request_id);
        }
        self.endBodyRead();
        if (self.held_pipe) |pipe| pipe.release();
        self.held_pipe = null;
        if (self.held_head) |*head| head.deinit();
        self.held_head = null;
        self.letRelayGo();
        // A stream request body's branch still written to a worker: its body
        // fails there.
        if (self.upload) |*u| u.abandon();
        self.upload = null;
        // The job abandons a service worker call still unanswered.
        self.service_worker_call = null;
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
        return !self.collect or (self.source == null and self.relay == null and self.race.network == null);
    }

    /// Static data: the outcome of a fetch of a data: URL that settled
    /// inside `start` - scheme fetch answers a data: URL with no network, so
    /// a collected fetch of one is over before `start` returns - taken by
    /// the client NOW, rather than handed to it by the next `pump`. The
    /// fetch is gone afterwards (`finished` is not called: the caller has
    /// the outcome in hand). Null - nothing taken, the fetch goes on as
    /// usual - for any other fetch, or one not settled yet.
    ///
    /// For the clients whose resources the browsers load at once from a
    /// data: URL: Blink's ResourceFetcher makes a data: URL's resource from
    /// the URL synchronously (CreateResourceForStaticData), and a style
    /// sheet's client hears it synchronously (Resource's synchronous cache
    /// hit for kCSSStyleSheet). The outcome is the same one `pump` would
    /// hand over: every step of the fetch - CSP's "should request be
    /// blocked", the response's tainting - ran in `start`.
    pub fn takeStaticOutcome(self: *AsyncFetch) ?(FetchError!FetchResult) {
        if (!std.ascii.startsWithIgnoreCase(self.job.request.currentUrl(), "data:")) return null;
        if (!self.collect or !self.deliverable() or self.transfer != null or self.job.hasNextManualRedirect()) return null;
        var outcome = self.outcome.?;
        self.outcome = null;
        outcome = AsyncFetch.settleCollected(outcome);
        self.delivered = true;
        self.destroy();
        return outcome;
    }

    /// Whether this fetch's response has started arriving and not ended:
    /// lines of its header block are in, or its head is and its body is still
    /// coming off a transfer that is not paused. What `catchUp` waits on.
    pub fn isArriving(self: *const AsyncFetch) bool {
        // A service worker's body comes off no socket: catching up with the
        // network does nothing for it.
        const job = self.transfer orelse return false;
        if (job.paused) return false;
        if (!self.awaiting_head) return self.source != null;
        var header_bytes: c_long = 0;
        _ = network.curl_ffi.easy_getinfo(job.transfer.handle, network.curl_ffi.c.CURLINFO_HEADER_SIZE, &header_bytes);
        return header_bytes > 0;
    }

    /// Whether the fetch is over: its response delivered, and no body left
    /// arriving - and no next manual redirect for the client to process (a
    /// navigation's redirect: the fetch goes on when the client asks).
    fn over(self: *const AsyncFetch) bool {
        return self.delivered and self.source == null and self.transfer == null and self.relay == null and
            self.race.network == null and self.upload == null and !self.job.hasNextManualRedirect();
    }

    /// Whether the response delivered is a navigation's redirect whose next
    /// hop waits for the client (HTTP fetch step 6 "manual", FetchJob).
    pub fn hasNextManualRedirect(self: *const AsyncFetch) bool {
        return self.delivered and self.job.hasNextManualRedirect();
    }

    /// The request's current URL (BORROWED until the fetch goes): HTML
    /// "create and initialize a Document object" step 3's creationURL.
    pub fn requestCurrentUrl(self: *const AsyncFetch) []const u8 {
        return self.job.request.currentUrl();
    }

    /// That redirect's location URL; null for failure (or none).
    pub fn nextManualRedirectUrl(self: *const AsyncFetch) ?[]const u8 {
        return self.job.nextManualRedirectUrl();
    }

    /// Fetch "process the next manual redirect", for the client (HTML's
    /// navigation, step 21.6): the next hop starts, and its response is
    /// delivered through `done` again. The request's reserved client and its
    /// route are the caller's for this hop (HTML step 21.1-21.2 may have
    /// replaced them): BORROWED, as when the fetch started.
    pub fn processNextManualRedirect(self: *AsyncFetch, reserved_client: ?*anyopaque, route: ?service_worker_fetch.Route) void {
        if (!self.hasNextManualRedirect()) return;
        self.job.request.reserved_client = reserved_client;
        self.job.request.service_worker = route;
        self.delivered = false;
        self.advance(self.job.processNextManualRedirect());
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
                .body => {
                    // The body's producer - the network's source, or a
                    // service worker's relay (`drainRelay`) - has ended
                    // already: verify it now. Otherwise its end resumes.
                    if (self.source == null and self.relay_source == null and self.race.network == null) {
                        next = self.job.resumeBody();
                        continue;
                    }
                    self.awaiting_body = true;
                    self.track_body_end = self.source != null or self.relay_source != null;
                    return;
                },
                .done => {
                    self.outcome = self.job.takeResult();
                    // The response handed over: its body's end reports it.
                    const arriving = self.source != null or self.relay_source != null;
                    self.track_body_end = arriving and (self.job.awaitsBodyEnd() or self.race_owner != null);
                    return;
                },
                .document_resource => {
                    // Asked again at every turn of the loop (`pump`).
                    if (self.job.documentResourceReady()) {
                        next = self.job.resumeDocumentResource();
                        continue;
                    }
                    self.awaiting_document_resource = true;
                    return;
                },
                .request_body => {
                    // The body's end resumes it (`awaitRequestBody`).
                    if (!self.job.requestBodyArriving() or self.requestBodyEnded()) {
                        next = self.job.resumeRequestBody();
                        continue;
                    }
                    self.awaiting_request_body = true;
                    return;
                },
                .service_worker => |call| {
                    // A stream body's tee for the worker: written from here.
                    if (call.takeUpload()) |upload| {
                        if (self.upload) |*old| old.abandon();
                        self.upload = upload;
                    }
                    // Asked again at every turn of the loop (`pump`).
                    self.service_worker_call = call;
                    // 13.3.4.5: the network races the worker.
                    if (self.job.serviceWorkerRaces()) self.startRace();
                    return;
                },
                .network => |needed| {
                    // Where Chrome's DevToolsURLLoaderInterceptor sits: the
                    // request is final, the transfer not started. The
                    // Browser's fetch observer may hold it (the request
                    // stage).
                    self.hold_chain = 0;
                    if (self.holdRequest(needed.request)) return;
                    self.startTransfer(needed.request) catch |err| {
                        // Not sent at all: that is the network's answer.
                        next = self.job.resumeNetwork(err);
                        continue;
                    };
                    return;
                },
                .auth => |*auth_step| {
                    // HTTP-network-or-cache fetch's prompt: the observer may
                    // answer it (Fetch.authRequired); with nobody to, the
                    // default - there is no prompting UI.
                    if (self.holdAuth(&auth_step.challenge)) return;
                    next = self.job.resumeAuth(.default);
                    continue;
                },
            }
        }
    }

    /// Hand the waiting request to the network now: the observer hears
    /// what is sent (Network.requestWillBeSentExtraInfo), and the transfer
    /// starts.
    fn startTransfer(self: *AsyncFetch, request: *const network.NetworkRequest) NetworkError!void {
        self.job.observeRequestSent();
        self.awaiting_head = true;
        self.transfer = self.fetches.scheduler.startStreaming(
            self.allocator,
            request,
            .{ .context = self, .head = networkHead, .data = networkData, .end = networkEnd, .encoded = networkEncoded },
        ) catch |err| {
            self.awaiting_head = false;
            return err;
        };
    }

    /// The handle the observer answers a hold of this fetch through.
    fn interceptionAt(self: *AsyncFetch, stage: network.observer.Stage) network.observer.Interception {
        return .{
            .context = self,
            .resume_fn = resumeIntercepted,
            .request_id = self.job.request.request_id,
            .stage = stage,
            .chain = self.hold_chain,
            .read_body_fn = if (stage == .response) readHeldBody else null,
        };
    }

    /// The request stage: whether the observer holds `request`. A
    /// CORS-preflight request is no request of the page's: never held.
    fn holdRequest(self: *AsyncFetch, request: *const network.NetworkRequest) bool {
        if (self.job.isPreflight() or self.job.isRetry()) return false;
        const o = network.observer.of(self.job.request) orelse return false;
        const intercept = o.intercept_request orelse return false;
        self.held = .request;
        if (intercept(o.context, self.job.request, request, self.interceptionAt(.request))) return true;
        self.held = null;
        return false;
    }

    /// The response stage: whether the observer holds the network's answer.
    fn holdResponse(self: *AsyncFetch, answer: network.observer.NetworkAnswer) bool {
        if (self.job.isPreflight()) return false;
        const request = self.job.pendingNetworkRequest() orelse return false;
        const o = network.observer.of(self.job.request) orelse return false;
        const intercept = o.intercept_response orelse return false;
        self.held = .response;
        if (intercept(o.context, self.job.request, request, answer, self.interceptionAt(.response))) return true;
        self.held = null;
        return false;
    }

    /// The auth stage: whether the observer answers the prompt.
    fn holdAuth(self: *AsyncFetch, challenge: *const network.observer.AuthChallenge) bool {
        const o = network.observer.of(self.job.request) orelse return false;
        const intercept = o.intercept_auth orelse return false;
        self.held = .auth;
        if (intercept(o.context, self.job.request, challenge, self.interceptionAt(.auth))) return true;
        self.held = null;
        return false;
    }

    /// The observer's decision for the fetch it held (observer.zig
    /// `Interception.decide`), on this fetch's thread.
    fn resumeIntercepted(context: *anyopaque, decision: *const network.observer.Decision) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        const stage = self.held orelse return;
        self.held = null;
        switch (stage) {
            .request => self.resumeRequestStage(decision.*),
            .response => self.resumeResponseStage(decision.*),
            .auth => self.advance(self.job.resumeAuth(switch (decision.*) {
                .auth => |answer| answer,
                else => .default,
            })),
        }
    }

    /// Request stage: send it (changed as asked - and the next holder may
    /// hold it again), answer it, or fail it.
    fn resumeRequestStage(self: *AsyncFetch, decision: network.observer.Decision) void {
        switch (decision) {
            .@"continue", .auth => {
                if (decision == .@"continue") self.job.overrideNetworkRequest(decision.@"continue") catch {
                    return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
                };
                const request = self.job.pendingNetworkRequest() orelse return;
                self.hold_chain += 1;
                if (self.holdRequest(request)) return;
                self.startTransfer(request) catch |err| return self.advance(self.job.resumeNetwork(err));
            },
            .fulfill => |fulfillment| {
                const response = network.observer.fulfilledResponse(self.allocator, self.job.request.currentUrl(), fulfillment) catch {
                    return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
                };
                self.advance(self.job.resumeNetwork(response));
            },
            .fail => |reason| self.advance(self.job.resumeNetwork(reason.networkError())),
        }
    }

    /// Response stage (Chrome's InterceptionJob at kResponseReceived): hand
    /// the answer on as it came; give it a head of the holder's and keep
    /// its body (fulfill without a body: continueResponse's new head);
    /// replace it whole (fulfill with a body); or fail it.
    fn resumeResponseStage(self: *AsyncFetch, decision: network.observer.Decision) void {
        const head = self.held_head;
        const pipe = self.held_pipe;
        const failed = self.held_error;
        self.held_head = null;
        self.held_pipe = null;
        self.held_error = null;
        self.endBodyRead();
        const keeps_body = switch (decision) {
            .@"continue", .auth => true,
            .fulfill => |f| f.body == null and head != null,
            .fail => false,
        };
        if (keeps_body) {
            if (failed) |err| return self.advance(self.job.resumeNetwork(err));
            var h = head.?;
            if (decision == .fulfill) network.observer.replaceHead(&h, decision.fulfill) catch {
                h.deinit();
                pipe.?.release();
                return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
            };
            // What arrived while it was held, for the observer; the rest as
            // it comes (`networkData`).
            self.job.observeData(pipe.?.buffered.items);
            // A body that ended while it was held ended unreported (its
            // response was nobody's yet): its sizes go to the job now, for
            // the report timing steps of the response it hands over.
            const ended = self.source == null;
            self.advance(self.job.resumeNetworkHead(h, pipe.?));
            if (ended and self.reporting and self.job.awaitsBodyEnd()) self.job.bodyEnded(.{ .encoded = self.encoded_bytes, .decoded = self.body_bytes });
            return;
        }
        // The answer goes: its pipe lets the transfer stop.
        if (pipe) |p| p.release();
        if (head) |h| {
            var dropped = h;
            dropped.deinit();
        }
        switch (decision) {
            .fulfill => |fulfillment| {
                const response = network.observer.fulfilledResponse(self.allocator, self.job.request.currentUrl(), fulfillment) catch {
                    return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
                };
                self.advance(self.job.resumeNetwork(response));
            },
            .fail => |reason| self.advance(self.job.resumeNetwork(reason.networkError())),
            .@"continue", .auth => unreachable, // kept the body above
        }
    }

    /// Interception.readBody at the response stage: the held body read to
    /// its end by a second reader (Chrome's InterceptionJob BodyReader),
    /// the held pipe keeping every byte for the fetch.
    fn readHeldBody(context: *anyopaque, reader: network.observer.BodyReader) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        if (self.held != .response or self.held_pipe == null) return reader.done(reader.context, null);
        if (self.body_read_done) return reader.done(reader.context, if (self.body_read_failed) null else self.body_read.items);
        self.body_readers.append(self.allocator, reader) catch return reader.done(reader.context, null);
        if (self.body_tee == null) {
            const tee = self.held_pipe.?.tee() catch {
                self.body_read_failed = true;
                return self.finishBodyRead();
            };
            tee.consumer = .{ .context = self, .notify = bodyReadProgress };
            self.body_tee = tee;
        }
        bodyReadProgress(self);
    }

    fn bodyReadProgress(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        const tee = self.body_tee orelse return;
        if (tee.hasBytes()) {
            const bytes = tee.take() catch {
                self.body_read_failed = true;
                return self.finishBodyRead();
            };
            defer self.allocator.free(bytes);
            self.body_read.appendSlice(self.allocator, bytes) catch {
                self.body_read_failed = true;
                return self.finishBodyRead();
            };
        }
        switch (tee.state) {
            .open => {},
            .closed => self.finishBodyRead(),
            .errored => {
                self.body_read_failed = true;
                self.finishBodyRead();
            },
        }
    }

    /// The held body is read (or failed): every reader hears it, and the
    /// second reader goes.
    fn finishBodyRead(self: *AsyncFetch) void {
        self.body_read_done = true;
        if (self.body_tee) |tee| tee.release();
        self.body_tee = null;
        var readers = self.body_readers;
        self.body_readers = .empty;
        defer readers.deinit(self.allocator);
        for (readers.items) |reader| reader.done(reader.context, if (self.body_read_failed) null else self.body_read.items);
    }

    /// The hold ends: a read not finished fails, and what was read goes.
    fn endBodyRead(self: *AsyncFetch) void {
        if (self.body_readers.items.len > 0) {
            self.body_read_failed = true;
            self.finishBodyRead();
        }
        if (self.body_tee) |tee| tee.release();
        self.body_tee = null;
        self.body_readers.deinit(self.allocator);
        self.body_readers = .empty;
        self.body_read.deinit(self.allocator);
        self.body_read = .empty;
        self.body_read_done = false;
        self.body_read_failed = false;
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
        source.producer = if (self.collect or !self.pause_body)
            .{ .context = self, .cancel = stopProducing }
        else
            .{ .context = self, .cancel = stopProducing, .pause = pauseTransfer, .unpause = unpauseTransfer };
        self.source = source;
        self.body_bytes = 0;
        self.encoded_bytes = 0;
        const pipe = source.branch() catch {
            var h = head;
            h.deinit();
            self.source = null;
            source.fail(.{ .kind = .network });
            self.cancelTransfer();
            return self.advance(self.job.resumeNetwork(NetworkError.OutOfMemory));
        };
        // The head as it came, for the observer
        // (Network.responseReceivedExtraInfo) - before anything holds it.
        self.job.observeResponseHead(&head);
        // The response stage: the observer may hold it; the body goes on
        // arriving into the held pipe meanwhile.
        if (self.holdResponse(.{ .response = &head })) {
            self.held_head = head;
            self.held_pipe = pipe;
            return;
        }
        // If fetch does not keep this response - a redirect it follows, a
        // network error - its pipe goes, and with no reader left the source
        // stops this transfer (`stopProducing`) before the next step begins.
        self.advance(self.job.resumeNetworkHead(head, pipe));
    }

    fn networkData(context: ?*anyopaque, bytes: []const u8) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        if (self.source) |source| {
            self.body_bytes += bytes.len;
            // The observer sees the body as it comes - not while a holder
            // has the response (what came meanwhile is reported when it is
            // handed on, `resumeResponseStage`).
            if (self.held == null) self.job.observeData(bytes);
            source.push(bytes);
        }
    }

    fn networkEncoded(context: ?*anyopaque, total: u64) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        self.encoded_bytes = total;
    }

    fn networkEnd(context: ?*anyopaque, result: NetworkError!void) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context.?));
        self.transfer = null;
        if (self.awaiting_head) {
            // No response at all: that is the network's answer - which the
            // observer may hold too (the response stage with an error,
            // requestPaused's responseErrorReason).
            self.awaiting_head = false;
            const err = if (result) |_| NetworkError.ProtocolError else |e| e;
            if (self.holdResponse(.{ .failed = err })) {
                self.held_error = err;
                return;
            }
            return self.advance(self.job.resumeNetwork(err));
        }
        const source = self.source orelse return;
        self.source = null;
        if (result) |_| source.finish() else |_| source.fail(.{ .kind = .network });
        // The body of the response handed over: its observer hears its end
        // (Network.loadingFinished / loadingFailed).
        if (self.job.response != null) self.job.observeBodyEnd(self.encoded_bytes, if (result) |_| false else |_| true);
        // Received, or failed: the job's report timing steps run now.
        self.endBody();
        if (self.awaiting_body) {
            self.awaiting_body = false;
            self.advance(self.job.resumeBody());
        }
    }

    /// The body arriving now has ended - finished, failed, or no reader left
    /// - with `body_bytes` of it: the job's report timing steps
    /// (FetchJob.bodyEnded), or the raced fetch's for a race's network side.
    fn endBody(self: *AsyncFetch) void {
        if (!self.track_body_end) return;
        self.track_body_end = false;
        // A fetch whose client has gone, or whose global is ending
        // (`AgentFetches.stopReporting`), reports nothing: the global it
        // would report to is going. Its body can still end after - its
        // reader freed with the realm (stopProducing, stopRelay).
        if (!self.reporting) return;
        const sizes: fetch_job.BodySizes = .{ .encoded = self.encoded_bytes, .decoded = self.body_bytes };
        if (self.race_owner) |owner| {
            if (owner.reporting) owner.raceBodyEnded(sizes);
            return;
        }
        self.job.bodyEnded(sizes);
    }

    /// The body's source has no reader left: stop the transfer. The source is
    /// not this fetch's to touch after this.
    fn stopProducing(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        self.source = null;
        // Nobody reads it: it ended for Resource Timing too (Chromium's
        // HandleLoaderError reports a cancelled load).
        self.endBody();
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

    /// `pump`: the service worker's answer, if it has come.
    fn askServiceWorker(self: *AsyncFetch) bool {
        const call = self.service_worker_call orelse return false;
        const answer = call.take() orelse return false;
        if (self.race.network != null or self.race.kept != null) return self.raceWorkerAnswered(answer);
        self.service_worker_call = null;
        self.advance(self.job.resumeServiceWorker(self.attachRelay(answer)));
        return true;
    }

    /// `pump`: the stream request body's branch for the service worker,
    /// written to its relay. Whether it ended (the body's end written, or the
    /// worker stopped reading it).
    fn pumpUpload(self: *AsyncFetch) bool {
        const upload = if (self.upload) |*u| u else return false;
        if (upload.pump()) return false;
        self.upload = null;
        return true;
    }

    /// Whether the request body's pipe has ended (finished or failed).
    fn requestBodyEnded(self: *const AsyncFetch) bool {
        const b = self.job.request.body orelse return true;
        return switch (b) {
            .bytes => true,
            .body => |body| if (body.pipe) |pipe| pipe.state != .open else true,
        };
    }

    /// `pump`: the `.document_resource` step's wait, over once the
    /// candidate's fetch has its response (or failed).
    fn awaitDocumentResource(self: *AsyncFetch) bool {
        if (!self.awaiting_document_resource or !self.job.documentResourceReady()) return false;
        self.awaiting_document_resource = false;
        self.advance(self.job.resumeDocumentResource());
        return true;
    }

    /// `pump`: the `.request_body` step's wait, over once the body has
    /// arrived whole or failed.
    fn awaitRequestBody(self: *AsyncFetch) bool {
        if (!self.awaiting_request_body or !self.requestBodyEnded()) return false;
        self.awaiting_request_body = false;
        self.advance(self.job.resumeRequestBody());
        return true;
    }

    /// Whether the race keeps the network side's response for the worker to
    /// decide on (case 4).
    pub fn raceHasNetworkResponse(self: *const AsyncFetch) bool {
        return self.race.kept != null;
    }

    /// 13.3.4.5.2: the race's network side, started beside the worker's
    /// fetch event. A network side that cannot start leaves the worker's
    /// answer alone, as for a "fetch-event" source.
    fn startRace(self: *AsyncFetch) void {
        // A previous hop's race whose network side still delivers that hop's
        // body (a navigation's redirect, handed over and followed): nobody
        // reads it now.
        self.endRace();
        const request = self.job.raceRequest() catch return;
        const network_side = startStreaming(self.allocator, request, .{
            .cross_origin_isolated_capability = self.job.options.cross_origin_isolated_capability,
        }, self.fetches, .{
            .context = self,
            .done = raceNetworkDone,
            .alive = raceNetworkAlive,
            .gone = raceNetworkGone,
            .finished = raceNetworkFinished,
        }) catch return;
        // Nothing has been heard yet: the client hears only from `pump`.
        network_side.pause_body = !self.collect;
        network_side.race_owner = self;
        self.race.network = network_side;
    }

    /// The race's network side and a response it kept go (13.3.4.7.2's
    /// abort); its transfer is cancelled, and its client - this fetch -
    /// hears nothing more from it.
    fn endRace(self: *AsyncFetch) void {
        if (self.race.network) |network_side| {
            self.race.network = null;
            network_side.terminate();
        }
        if (self.race.kept) |kept| {
            self.race.kept = null;
            var result = kept catch null;
            if (result) |*r| r.deinit();
        }
        self.race.fallback = false;
        self.race.network_taken = false;
        self.race.body_sizes = null;
    }

    /// The race's network side's body has ended: this fetch's job reports
    /// it - now if its response is the answer, at its handover otherwise.
    fn raceBodyEnded(self: *AsyncFetch, sizes: fetch_job.BodySizes) void {
        if (self.race.network_taken) return self.job.bodyEnded(sizes);
        self.race.body_sizes = sizes;
    }

    /// The worker's answer while the network races it.
    fn raceWorkerAnswered(self: *AsyncFetch, answer: service_worker_fetch.Call.Answer) bool {
        switch (answer) {
            .fallback => {
                // Case 3: the race's response, as soon as it has one.
                if (self.race.kept) |kept| {
                    self.race.kept = null;
                    self.raceTakeNetwork(kept);
                } else if (self.race.network == null) {
                    // No network side: HTTP fetch step 4, the network.
                    self.service_worker_call = null;
                    self.advance(self.job.resumeServiceWorker(.fallback));
                } else {
                    self.race.fallback = true;
                }
            },
            .response, .network_error => {
                // Case 2: the worker won; the network side is aborted.
                self.endRace();
                self.service_worker_call = null;
                self.advance(self.job.resumeServiceWorker(self.attachRelay(answer)));
            },
        }
        return true;
    }

    /// The network side's outcome is the answer (cases 1 and 3): Handle
    /// Fetch returns it, and HTTP fetch step 3.5 takes it as a service
    /// worker's response. Its body - the network side's pipe - is still
    /// arriving; the network side fills it until it is over.
    fn raceTakeNetwork(self: *AsyncFetch, outcome: FetchError!FetchResult) void {
        self.race.fallback = false;
        self.service_worker_call = null;
        var result = outcome catch {
            self.advance(self.job.resumeServiceWorker(.network_error));
            return;
        };
        // The network side's own timing info goes: this fetch's is the one
        // reported (13.3.4.12 gives the routed response the raced fetch's
        // service worker timing info).
        result.timing_info.deinit();
        if (result.referrer) |referrer| result.response.allocator.free(referrer);
        self.race.network_taken = true;
        // Its body ended already: the handover reports its sizes.
        if (self.race.body_sizes) |sizes| {
            self.race.body_sizes = null;
            self.job.bodyEnded(sizes);
        }
        self.advance(self.job.resumeServiceWorker(.{ .response = result.response }));
    }

    /// 13.3.4.5.2.1.2's "ok status", of the response fetch handed over (an
    /// opaque filtered response's status is 0).
    fn raceResponseOk(outcome: *const (FetchError!FetchResult)) bool {
        const result = outcome.* catch return false;
        return switch (result.response.response_type) {
            .@"error", .@"opaque", .opaqueredirect => false,
            else => result.response.status >= 200 and result.response.status <= 299,
        };
    }

    /// The network side's client: its response.
    fn raceNetworkDone(context: *anyopaque, outcome: FetchError!FetchResult) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        // Case 3: the worker fell back - this is the answer.
        if (self.race.fallback) return self.raceTakeNetwork(outcome);
        // Case 1: an ok response before the worker answered wins.
        if (raceResponseOk(&outcome)) if (self.service_worker_call) |call| {
            call.lose();
            return self.raceTakeNetwork(outcome);
        };
        // Case 4: kept for the worker to decide on.
        self.race.kept = outcome;
    }

    /// The network side is this fetch's to end: it is always wanted.
    fn raceNetworkAlive(_: *anyopaque) bool {
        return true;
    }

    /// Never: the network side's client is always alive.
    fn raceNetworkGone(_: *anyopaque) void {}

    /// The network side is over (and gone): a winning response's body has
    /// arrived, and main fetch step 23 can go on.
    fn raceNetworkFinished(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        self.race.network = null;
        if (self.awaiting_body and self.source == null and self.relay_source == null) {
            self.awaiting_body = false;
            self.advance(self.job.resumeBody());
        }
    }

    /// The answer as the job takes it: a response's body is a pipe of a
    /// source this fetch fills from the relay (`drainRelay`), as the
    /// network's is filled from its transfer.
    fn attachRelay(self: *AsyncFetch, answer: service_worker_fetch.Call.Answer) FetchJob.ServiceWorkerAnswer {
        return switch (answer) {
            .fallback => .fallback,
            .network_error => .network_error,
            .response => |r| blk: {
                const relay = r.body orelse break :blk .{ .response = r.response };
                const failed: FetchJob.ServiceWorkerAnswer = .network_error;
                const source = PipeSource.create(self.allocator) catch {
                    service_worker_fetch.freeAnswer(answer);
                    break :blk failed;
                };
                // No pause: the service worker's side keeps no backpressure
                // (BodyRelay).
                source.producer = .{ .context = self, .cancel = stopRelay };
                const pipe = source.branch() catch {
                    source.producer = null;
                    source.fail(.{ .kind = .network });
                    service_worker_fetch.freeAnswer(answer);
                    break :blk failed;
                };
                const body = Body.fromPipe(self.allocator, pipe) catch {
                    pipe.release();
                    service_worker_fetch.freeAnswer(answer);
                    break :blk failed;
                };
                r.response.body = body;
                self.relay = relay;
                self.relay_source = source;
                // The observer sees the worker's body as it is drained
                // (Network.dataReceived for a response fromServiceWorker).
                // A worker's response is never the HTTP cache's to store,
                // so the source's observer slot is free.
                if (network.observer.of(self.job.request)) |o| if (o.data_received != null) {
                    source.observer = .{ .context = self, .data = relayData, .end = relayEnd };
                };
                break :blk .{ .response = r.response };
            },
        };
    }

    fn relayData(context: *anyopaque, bytes: []const u8) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        self.job.observeData(bytes);
    }

    fn relayEnd(context: *anyopaque, complete: bool) void {
        _ = .{ context, complete };
    }

    /// `pump`: what the service worker wrote since the last turn, into the
    /// response's body; its end once it has ended.
    fn drainRelay(self: *AsyncFetch) bool {
        const relay = self.relay orelse return false;
        const source = self.relay_source orelse return false;
        const end = relay.drainInto(source);
        self.body_bytes = relay.drained;
        self.encoded_bytes = relay.drained;
        if (end == .open) return true;
        self.relay_source = null;
        relay.release();
        self.relay = null;
        self.endBody();
        // Main fetch step 23 waited for the whole body, as networkEnd's.
        if (self.awaiting_body) {
            self.awaiting_body = false;
            self.advance(self.job.resumeBody());
        }
        return true;
    }

    /// The body's source has no reader left: the service worker's writer is
    /// told to stop.
    fn stopRelay(context: *anyopaque) void {
        const self: *AsyncFetch = @ptrCast(@alignCast(context));
        self.relay_source = null;
        if (self.relay) |relay| {
            self.body_bytes = relay.drained;
            self.encoded_bytes = relay.drained;
        }
        self.endBody();
        self.letRelayGo();
    }

    fn letRelayGo(self: *AsyncFetch) void {
        const relay = self.relay orelse return;
        self.relay = null;
        relay.cancel();
        relay.release();
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
    /// Every fetch of the agent that has not ended, oldest first - kept
    /// ones (`AsyncFetch.keep`) among them.
    live: std.ArrayListUnmanaged(*AsyncFetch) = .empty,
    /// How long a kept fetch may run without its client before it is
    /// terminated (`sweep`). An ENGINE RESOURCE BOUND, not a compatibility
    /// ruling: once its client is gone nothing on the web can observe when
    /// a kept fetch ends (WPT cannot), so golden rule 2 does not apply; the
    /// bound exists so that a hanging server cannot keep a request, its
    /// transfer and its connection for a long-lived Browser's whole life.
    /// The engines: Chromium bounds it at 30 s after the renderer goes -
    /// kDefaultDisconnectedKeepAliveURLLoaderTimeout, "Prevents this loader
    /// from staying alive indefinitely" (content/browser/loader/
    /// keep_alive_url_loader.cc, OnURLLoaderDisconnected and
    /// OnDisconnectedLoaderTimerFired, at f510e70030) - and this takes its
    /// value; WebKit sets no time limit (~NetworkSession aborts its
    /// m_keptAliveLoads, Source/WebKit/NetworkProcess/NetworkSession.cpp at
    /// 3ef14dfb52); Gecko sets none either (dom/fetch/FetchService.cpp at
    /// 5a78f4525f caps only their number, dom.fetchKeepalive.*_limit). A
    /// field, not a constant, so that a test can shorten it.
    kept_limit_ms: i64 = 30 * std.time.ms_per_s,
    /// Request bodies another thread writes for this agent's realms - a
    /// stream body a page's fetch hands to a service worker of this agent
    /// (`readRelay`) - each drained into the pipe its realm reads, every
    /// turn (`drainRelayReaders`).
    relay_readers: std.ArrayListUnmanaged(*RelayReader) = .empty,

    /// A body arriving through a relay another thread writes: what this
    /// agent's loop drains into its source each turn. The source's producer:
    /// when its last reader goes - the realm's body stream cancelled or
    /// collected - the relay is cancelled, which the writer sees
    /// (service_worker_fetch.Upload), and this reader is dropped at the next
    /// turn.
    pub const RelayReader = struct {
        relay: *BodyRelay,
        /// Null once its producer was cancelled: the source may be gone.
        source: ?*PipeSource,

        fn cancel(context: *anyopaque) void {
            const self: *RelayReader = @ptrCast(@alignCast(context));
            // Called inside a delivery to the source, or from a reader's
            // release: only marked here, and dropped by the next turn.
            self.source = null;
            self.relay.cancel();
        }
    };

    pub fn init(allocator: Allocator) AgentFetches {
        return .{ .allocator = allocator, .scheduler = NetworkScheduler.init(allocator) };
    }

    /// The agent's end, after its realms' (each of which swept the fetches
    /// it left, while the agent lived): the kept fetches end - they reach no
    /// client and no realm, so ending them needs no engine - and the
    /// scheduler closes its multi handle. Another fetch still here was never
    /// swept - its client outlived its agent - and is left as it is: ending
    /// it would reach an engine that is gone.
    ///
    /// A worker's agent ends with its global, so a keepalive fetch of a
    /// worker ends here too, soon after the worker: unlike the browsers -
    /// Chromium's KeepAliveURLLoaderService and Gecko's parent-process
    /// FetchService outlive every worker - Crane has no network side above
    /// the agent to hand it to (a worker's transfers are on its own
    /// thread's multi handle). Feature-queue "KEEPALIVE PAST A WORKER'S END".
    pub fn deinit(self: *AgentFetches) void {
        var i: usize = 0;
        while (i < self.live.items.len) {
            const f = self.live.items[i];
            if (f.kept_since_ms == null) {
                i += 1;
                continue;
            }
            // Removes it from `live`.
            f.terminateWith(.{ .kind = .network });
        }
        if (self.live.items.len != 0) log.warn("{d} fetches outlived their agent", .{self.live.items.len});
        self.live.deinit(self.allocator);
        // A relayed body nobody read to its end: the writer stops, and its
        // readers' body fails.
        for (self.relay_readers.items) |reader| {
            if (reader.source) |source| {
                source.producer = null;
                source.fail(.{ .kind = .network });
            }
            reader.relay.cancel();
            reader.relay.release();
            self.allocator.destroy(reader);
        }
        self.relay_readers.deinit(self.allocator);
        self.scheduler.deinit();
    }

    /// A pipe of this agent fed from `relay` - a request body another thread
    /// writes (service_worker_fetch.Upload) - as this agent's loop drains it
    /// (`pump`). It takes the reader's reference to `relay`; on failure that
    /// stays the caller's.
    pub fn readRelay(self: *AgentFetches, relay: *BodyRelay) Allocator.Error!*body_pipe.BodyPipe {
        const reader = try self.allocator.create(RelayReader);
        errdefer self.allocator.destroy(reader);
        const source = try PipeSource.create(self.allocator);
        // No pause: the writer keeps no backpressure (BodyRelay).
        source.producer = .{ .context = reader, .cancel = RelayReader.cancel };
        const pipe = source.branch() catch |err| {
            source.producer = null;
            source.fail(.{ .kind = .network });
            return err;
        };
        reader.* = .{ .relay = relay, .source = source };
        self.relay_readers.append(self.allocator, reader) catch |err| {
            // The pipe's release would cancel the relay through the
            // producer: the relay is still the caller's.
            source.producer = null;
            pipe.release();
            return err;
        };
        return pipe;
    }

    /// `pump`: what each relay's writer wrote since the last turn, into its
    /// pipe; its end once it has ended. A reader whose source's last reader
    /// went, or whose relay ended, goes.
    fn drainRelayReaders(self: *AgentFetches) bool {
        var progressed = false;
        var i: usize = 0;
        while (i < self.relay_readers.items.len) {
            const reader = self.relay_readers.items[i];
            const ended = if (reader.source) |source| blk: {
                const before = reader.relay.drained;
                const end = reader.relay.drainInto(source);
                if (reader.relay.drained != before) progressed = true;
                // The delivery may have cancelled it (`RelayReader.cancel`).
                break :blk end != .open or reader.source == null;
            } else true;
            if (!ended) {
                i += 1;
                continue;
            }
            // drainInto finished or failed the source, which let its
            // producer go - and may have freed it, once its last reader went
            // in that delivery; a cancelled one's producer went first. The
            // source is not touched again.
            _ = self.relay_readers.orderedRemove(i);
            reader.relay.release();
            self.allocator.destroy(reader);
            progressed = true;
        }
        return progressed;
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

        // Service workers answer from their own threads: each fetch waiting
        // on one asks its call, and each response body coming from one takes
        // what was written. Asked here, once a turn, as the transfers are
        // pumped: the loop slices its waits at 1 ms while a fetch is in
        // flight (browser/event_loop.zig step 2c, worker_event_loop.zig), so
        // an answer waits at most that long, with no wake-up of its own.
        var i: usize = 0;
        while (i < self.live.items.len) : (i += 1) {
            const f = self.live.items[i];
            if (f.askServiceWorker()) progressed = true;
            if (f.drainRelay()) progressed = true;
            if (f.pumpUpload()) progressed = true;
            if (f.awaitRequestBody()) progressed = true;
            if (f.awaitDocumentResource()) progressed = true;
        }
        // Request bodies other threads write for this agent's service
        // worker realms (`readRelay`).
        if (self.drainRelayReaders()) progressed = true;

        // One at a time, from the front afresh: a client may start or
        // terminate fetches from its callbacks.
        while (true) {
            if (self.nextDeliverable()) |f| {
                var outcome = f.outcome.?;
                f.outcome = null;
                if (f.collect) outcome = AsyncFetch.settleCollected(outcome);
                // The whole response, for the document that keeps it.
                f.job.keepForDocument(&outcome);
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
    /// than on the next turn. Returns whether any fetch was terminated or
    /// kept.
    ///
    /// Step 1 terminates only a record whose request's keepalive is false:
    /// a keepalive fetch whose response has not come is kept instead
    /// (`AsyncFetch.keep`) - its client still hears it is gone, and the
    /// fetch goes on here, reporting to no one - until it is over, or until
    /// it has been kept for `kept_limit_ms`, when it is terminated.
    pub fn sweep(self: *AgentFetches) bool {
        var changed = false;
        var now_ms: ?i64 = null;
        var i: usize = 0;
        while (i < self.live.items.len) {
            const f = self.live.items[i];
            if (f.kept_since_ms) |since| {
                const now = now_ms orelse platform.monotonicMillis();
                now_ms = now;
                if (now - since < self.kept_limit_ms) {
                    i += 1;
                    continue;
                }
                // Kept too long: it ends, and no one hears.
                f.terminateWith(.{ .kind = .network });
                changed = true;
                continue;
            }
            if (f.client.alive(f.client.context)) {
                i += 1;
                continue;
            }
            const client = f.client;
            changed = true;
            if (f.outlivesClient()) {
                const now = now_ms orelse platform.monotonicMillis();
                now_ms = now;
                f.keep(now);
                client.gone(client.context);
                // Still in `live`, wherever the client's gone left it.
                continue;
            }
            // Its client is gone: nothing is reported for it.
            f.reporting = false;
            f.terminateWith(.{ .kind = .network });
            client.gone(client.context);
        }
        return changed;
    }

    /// The agent's global is ending - a worker's, whose agent has that one
    /// global, at the start of its realm's end (html
    /// WorkerHost.teardownRealm), before anything of the realm is freed: no
    /// fetch of the agent reports anything more (`reporting`). Resource
    /// Timing's "mark resource timing" marks an entry for the global, which
    /// is going. Blink comes to the same when a worker's context is
    /// destroyed: FetchManager::ContextDestroyed disposes each loader, which
    /// first prevents its notifications (Loader::Dispose: "Prevent
    /// notification"), before WorkerThread::PerformShutdownOnWorkerThread
    /// disposes the global scope; WebKit's prepareForDestruction stops its
    /// active DOM objects first.
    ///
    /// The fetches go on, keepalive or not, until the fetch group is
    /// terminated after the realm's end (`sweep`, their clients read as
    /// gone). Nothing is called here: a closing worker's event loop drops a
    /// task at once, inside whatever queued it, so terminating a fetch now
    /// - failing its body - runs its readers' drop steps inside the failure,
    /// and an EventSource's closes the source, terminating the fetch being
    /// terminated. Muted only after the realm's objects were freed, a body
    /// they held ended its fetch and reported timing to a global scope the
    /// same teardown may already have freed (lane workerteardown1:
    /// fetch/api/basic/stream-response.any.js [worker] crashed in
    /// Performance.performanceOfRealm).
    pub fn stopReporting(self: *AgentFetches) void {
        for (self.live.items) |f| f.reporting = false;
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
        return self.live.items.len + self.relay_readers.items.len;
    }
};
