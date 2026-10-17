//! Navigation preload's fetch (Service Workers Handle Fetch step 15.1), on the
//! service worker's thread: the preload request - a clone of the navigation
//! request with its `Service-Worker-Navigation-Preload` header and
//! service-workers mode "none" - fetched while the fetch event runs, and the
//! event's preloadResponse resolved with a Response object for what came back
//! (rejected with a TypeError for a network error).
//!
//! Handle Fetch decides it on the fetching thread (manager.handleFetch: a GET
//! navigation of a registration whose navigation preload enabled flag is set
//! and whose active worker handles fetch) and hands the header value over with
//! the fetch's dispatch; the fetch itself starts here, from the fetch event's
//! task, through the same fetch machinery fetch() runs in the worker
//! (fetch.algorithms.AsyncFetch on the worker agent's fetches).
//!
//! Stated deviations:
//! - The preload starts when the fetch event's task runs on the worker's
//!   thread, after Run Service Worker - not in parallel with the worker's
//!   start, as the spec's "in parallel" (and Chromium, whose browser process
//!   starts it before the worker runs) allows. The request it sends is the
//!   same; only how early it goes out differs.
//! - Its request's client is the service worker's environment - its cookie
//!   jar, network, and timing reporter - rather than the navigation's: the
//!   request already carries the navigation's origin, referrer, mode and
//!   destination (HTTP fetch step 3 copied them resolved), and Chromium
//!   reports the preload's resource timing to the service worker's
//!   performance timeline, with initiatorType "navigation"
//!   (navigation-preload/resource-timing.https.html reads it there). No
//!   policy container is taken from the worker: its CSP is not the
//!   navigation's.
//! - It is not aborted when the navigation's fetch is (15.1.7's "abort when
//!   fetchController's state is terminated or aborted"): it ends with its
//!   response, or with the worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#handle-fetch (step 15)

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");
const webidl = @import("webidl");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const manager_mod = @import("manager.zig");

const InternalRequest = fetch.internal.InternalRequest;
const AsyncFetch = fetch.algorithms.AsyncFetch;
const FetchOutcome = fetch.algorithms.FetchError!fetch.algorithms.FetchResult;

const log = std.log.scoped(.service_worker);

/// The header the preload request carries (15.1.4).
pub const header_name = "Service-Worker-Navigation-Preload";

/// Handle Fetch steps 15.1.1-15.1.7, for the navigation request `request`
/// (BORROWED: the fetch event's copy) and the registration's navigation
/// preload header value `header_value`, in the worker's realm `realm` whose
/// global is `global_scope`: preloadResponse, a promise in `realm` (OWNED by
/// the caller), settled when the preload's response - or its network error -
/// comes. A preload that cannot start is a network error: the promise is
/// rejected.
pub fn start(realm: runtime.Context, global_scope: *runtime.Instance, request: *const InternalRequest, header_value: []const u8) !engine.Owned {
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    const promise = try engine.retainValue(realm, capability.promise);
    errdefer promise.release();
    const call = try realm.allocator.create(PreloadCall);
    call.* = .{ .allocator = realm.allocator, .realm = realm, .capability = capability };
    call.begin(global_scope, request, header_value) catch |err| {
        log.debug("a navigation preload did not start: {s}", .{@errorName(err)});
        call.fetch_holds = false;
        call.rejectTypeError();
        call.maybeRelease();
    };
    return promise;
}

/// The preload's fetch, from its start until both the fetch and the task
/// that settles preloadResponse have let go of it - FetchCall's shape
/// (WindowOrWorkerGlobalScope.zig): the fetch holds it until it is over, the
/// settle task from `done` until it runs.
const PreloadCall = struct {
    allocator: Allocator,
    realm: runtime.Context,
    /// preloadResponse's capability, until it is settled.
    capability: ?engine.PromiseCapability,
    outcome: ?FetchOutcome = null,
    in_flight: ?*AsyncFetch = null,
    fetch_holds: bool = true,
    task_holds: bool = false,

    fn begin(self: *PreloadCall, global_scope: *runtime.Instance, request: *const InternalRequest, header_value: []const u8) !void {
        // 15.1.1. preloadRequest: a clone of request.
        const preload = (try manager_mod.copyRequestForWorker(self.allocator, request)) orelse return error.NetworkError;
        var owned = true;
        errdefer if (owned) preload.deinit();
        // 15.1.4. `Service-Worker-Navigation-Preload`: the registration's
        // header value.
        try preload.header_list.append(header_name, header_value);
        // 15.1.5. service-workers mode "none".
        preload.service_workers_mode = .none;
        // The service worker's settings as its client (stated): its cookie
        // jar, network, blob URL store and timing reporter; no policy
        // container, no CSP reporter.
        var settings = try dom.global_settings.requestClient(global_scope);
        defer settings.deinit();
        settings.request.policy_container = null;
        settings.request.csp_violation_reporter = null;
        settings.request.service_worker = null;
        try fetch.internal.populateRequestFromClient(preload, settings.request);
        // Resource Timing: the preload's entry is the service worker's, with
        // initiatorType "navigation" (Chromium's
        // ServiceWorkerNavigationPreloadRequest reports it so).
        preload.initiator_type = .navigation;
        // 15.1.7.1. Fetch preloadRequest; processResponse settles
        // preloadResponse. The fetch owns the request from here - also when
        // it cannot start.
        owned = false;
        self.in_flight = try AsyncFetch.startStreaming(self.allocator, preload, .{}, dom.agent_fetches.of(self.realm), self.fetchClient());
    }

    fn fetchClient(self: *PreloadCall) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone, .finished = finished };
    }

    fn alive(context: *anyopaque) bool {
        const self: *PreloadCall = @ptrCast(@alignCast(context));
        return self.realm.engine_ctx != null;
    }

    /// The worker's realm ended with the preload in flight: nothing is left
    /// to settle.
    fn gone(context: *anyopaque) void {
        const self: *PreloadCall = @ptrCast(@alignCast(context));
        self.in_flight = null;
        self.fetch_holds = false;
        self.maybeRelease();
    }

    /// The preload is entirely over - its body ended or nobody read it.
    fn finished(context: *anyopaque) void {
        const self: *PreloadCall = @ptrCast(@alignCast(context));
        self.in_flight = null;
        self.fetch_holds = false;
        self.maybeRelease();
    }

    /// processResponse: a task on the worker's loop settles preloadResponse.
    fn done(context: *anyopaque, outcome: FetchOutcome) void {
        const self: *PreloadCall = @ptrCast(@alignCast(context));
        self.outcome = outcome;
        self.task_holds = true;
        if (self.realm.getOptionalEventLoop()) |loop| {
            loop.queueTask(.{ .callback = settle, .context = self, .drop = drop });
            return;
        }
        settle(self);
    }

    fn settle(context: ?*anyopaque) void {
        const self: *PreloadCall = @ptrCast(@alignCast(context.?));
        if (self.realm.engine_ctx != null) engine.runTaskInRealm(self.realm, settleSteps, self) catch {};
        self.taskDone();
    }

    fn drop(context: ?*anyopaque) void {
        const self: *PreloadCall = @ptrCast(@alignCast(context.?));
        self.taskDone();
    }

    fn settleSteps(data: ?*anyopaque) void {
        const self: *PreloadCall = @ptrCast(@alignCast(data.?));
        self.processResponse();
    }

    /// 15.1.7.1's processResponse for navigationPreloadResponse.
    fn processResponse(self: *PreloadCall) void {
        const outcome = self.outcome orelse return;
        self.outcome = null;
        var result = outcome catch return self.rejectTypeError();
        result.timing_info.deinit();
        const response = result.response;
        // 1. A network error: reject preloadResponse with a TypeError.
        if (response.response_type == .@"error") {
            response.deinit();
            return self.rejectTypeError();
        }
        // 2. preloadResponseObject (15.1.3: its Headers immutable),
        // associated with navigationPreloadResponse - the filtered response
        // main fetch made.
        response.filter() catch {
            response.deinit();
            return self.rejectTypeError();
        };
        const object = interfaces.Response.call_constructor(self.realm, webidl.Opt(?typedefs.BodyInit).notPassed(), webidl.Opt(dictionaries.ResponseInit).notPassed()) catch {
            response.deinit();
            return self.rejectTypeError();
        };
        if (!dom.fetch_objects.adoptResponse(object, @ptrCast(response), .immutable)) {
            response.deinit();
            return self.rejectTypeError();
        }
        // 3. Resolve preloadResponse with it.
        var capability = self.capability orelse return;
        self.capability = null;
        defer engine.releasePromiseCapability(&capability);
        engine.resolvePromise(&capability, runtime.JSValue.fromInstance(object)) catch {};
    }

    fn rejectTypeError(self: *PreloadCall) void {
        var capability = self.capability orelse return;
        self.capability = null;
        defer engine.releasePromiseCapability(&capability);
        const reason = engine.createSimpleException(self.realm, .TypeError, "The navigation preload failed") catch return;
        defer reason.release();
        engine.rejectPromise(&capability, reason.value) catch {};
    }

    fn taskDone(self: *PreloadCall) void {
        self.task_holds = false;
        if (self.outcome) |outcome| {
            self.outcome = null;
            var result = outcome catch null;
            if (result) |*r| r.deinit();
        }
        self.maybeRelease();
    }

    fn maybeRelease(self: *PreloadCall) void {
        if (self.fetch_holds or self.task_holds) return;
        if (self.outcome) |outcome| {
            var result = outcome catch null;
            if (result) |*r| r.deinit();
            self.outcome = null;
        }
        // A preloadResponse never settled (the realm went first) lets its
        // resolver go.
        if (self.capability) |*capability| engine.releasePromiseCapability(capability);
        self.capability = null;
        self.allocator.destroy(self);
    }
};
