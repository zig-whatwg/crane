//! The fetch algorithm as a job that can wait for the network.
//!
//! Fetch's algorithms call one another - fetch, main fetch, HTTP fetch,
//! HTTP-network-or-cache fetch, HTTP-network fetch, and for a redirect
//! HTTP-redirect fetch and main fetch again - and only HTTP-network fetch ever
//! waits, for the network to answer. Written as nested calls, that wait can
//! only be a blocking one. So the algorithms are written in halves around it
//! (`mainFetchStart`/`mainFetchFinish`, `httpNetworkOrCacheFetchStart`,
//! `httpNetworkFetchFinish`, `httpFetchFinish`, `httpRedirectFetchStart`/
//! `httpRedirectFetchFinish`), and this job is the call stack between them: it
//! runs the algorithms until they need the network, says so, and carries on
//! from the network's answer.
//!
//! Who answers is the caller's business. `fetch()` in `fetch.zig` performs
//! each request at once, blocking - navigation and synchronous XHR need that.
//! `AsyncFetch` in `async_fetch.zig` hands it to the network scheduler and
//! resumes the job from the event loop. Both run this job, so there is one
//! fetch algorithm whichever way the network is waited for.

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const InternalResponse = internal_response.InternalResponse;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const fetch_params_mod = @import("../internal/fetch_params.zig");
const FetchParams = fetch_params_mod.FetchParams;
const FetchController = @import("../internal/fetch_controller.zig").FetchController;
const FetchTimingInfo = @import("../internal/fetch_timing.zig").FetchTimingInfo;
const network = @import("../network/root.zig");
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const BodyPipe = @import("../internal/body_pipe.zig").BodyPipe;
const main_fetch = @import("main_fetch.zig");
const http_fetch = @import("http_fetch.zig");
const scheme_fetch = @import("scheme_fetch.zig");
const service_worker_fetch = @import("../internal/service_worker_fetch.zig");

/// Error types for fetch.
pub const FetchError = error{
    OutOfMemory,
    NetworkError,
    AbortError,
};

/// Fetch result containing the response and timing info.
pub const FetchResult = struct {
    response: *InternalResponse,
    timing_info: FetchTimingInfo,
    /// The request's referrer as main fetch left it - step 9's "determine
    /// request's referrer", redone for each redirect - when it is a URL;
    /// null for "no-referrer" (or "client", which main fetch never leaves).
    /// HTML "create and initialize a Document object" step 14 sets a
    /// navigation's new document's referrer from it. Owned, by the
    /// response's allocator; null unless FetchOptions.report_referrer.
    referrer: ?[]u8 = null,

    pub fn deinit(self: *FetchResult) void {
        if (self.referrer) |r| self.response.allocator.free(r);
        self.referrer = null;
        self.response.deinit();
        self.timing_info.deinit();
    }
};

/// Callback type for process response.
pub const ProcessResponseCallback = *const fn (response: *InternalResponse) void;

/// Options for the fetch operation.
pub const FetchOptions = struct {
    /// Process response callback
    process_response: ?ProcessResponseCallback = null,
    /// Use CORS mode
    use_cors: bool = false,
    /// Cross-origin isolated capability
    cross_origin_isolated_capability: bool = false,
    /// Hand the request's final referrer back in FetchResult.referrer. Only
    /// a caller that frees its result with FetchResult.deinit asks: the
    /// others take the response and timing info apart and would leak it.
    report_referrer: bool = false,
    /// The client processes the next manual redirect of a navigate request
    /// itself - HTML's navigation ("create navigation params by fetching"
    /// step 21): HTTP fetch step 6 "manual" hands it the redirect response and
    /// keeps the next manual redirect steps. Any other client of a navigate
    /// request with redirect mode "manual" - a navigation preload's - gets
    /// an opaque-redirect filtered response, which is what browsers hand a
    /// preload (navigation-preload/redirect.https.html).
    follows_manual_redirects: bool = false,
};

pub const FetchJob = struct {
    allocator: Allocator,
    request: *InternalRequest,
    /// Whether `destroy` frees `request`. A blocking fetch borrows its
    /// caller's; one that outlives the call that started it owns its own.
    owns_request: bool,
    options: FetchOptions,
    timing_info: FetchTimingInfo,
    controller: *FetchController,
    params: *FetchParams,
    /// How many recursive main fetches deep the algorithm is: 0 is fetch's
    /// own main fetch, and each redirect followed is one more.
    depth: u32 = 0,
    /// The request HTTP-network fetch is waiting on the network for, and when
    /// it was handed over.
    network_request: ?NetworkRequest = null,
    network_start_time: f64 = 0,
    /// Whether `network_request` is a CORS-preflight fetch's: its answer
    /// decides whether the request itself goes out.
    network_request_is_preflight: bool = false,
    /// Set once the job is `.done`.
    response: ?*InternalResponse = null,
    /// Main fetch step 23's response, owned until its full body is checked.
    pending_response: ?*InternalResponse = null,
    is_authentication_fetch: bool = false,
    authentication_realm: ?[]u8 = null,
    /// HTTP fetch step 3's call to a service worker, while its answer is
    /// awaited (the job's reference), with step 3.3's serviceWorkerStartTime
    /// and whether step 4 would make a CORS-preflight request.
    service_worker_call: ?*service_worker_fetch.Call = null,
    service_worker_start_time: f64 = 0,
    service_worker_preflight: bool = false,
    /// Handle Fetch 13.3.4: the call races the network ("race-network-and-
    /// fetch-handler"). The event loop's driver (AsyncFetch) fetches
    /// `raceRequest()` beside it and resumes with the race's winner as the
    /// service worker's answer. Stated deviation: the blocking driver
    /// (fetch.zig) does not race - it waits for the fetch event's answer
    /// alone, as for a "fetch-event" source.
    service_worker_race: bool = false,
    /// Fetch response handover step 4's report timing steps, waiting for the
    /// end of the body of the response handed over (`handOverTiming`).
    deferred_timing: ?DeferredTiming = null,
    /// The body's sizes, when it ended before the handover that reports it.
    body_sizes: ?BodySizes = null,
    /// The fetch controller's next manual redirect steps (HTTP fetch step 6
    /// "manual", a navigation): HTTP-redirect fetch given fetchParams and
    /// the redirect response handed over - `processNextManualRedirect`.
    /// Null when the response handed over is no such redirect.
    next_manual_redirect: ?ManualRedirect = null,

    /// What the next manual redirect steps keep of the redirect response.
    const ManualRedirect = struct {
        /// A copy of the redirect response but its body: what HTTP-redirect
        /// fetch reads (status, headers, URL list). OWNED.
        response: *InternalResponse,
        /// Its location URL given the request's current URL's fragment,
        /// serialized - null for failure. OWNED.
        location: ?[]u8,
    };

    /// What the job needs next.
    pub const Step = union(enum) {
        /// HTTP-network fetch's request, for the network to answer. Hand the
        /// answer to `resumeNetwork`. Borrowed from the job until then.
        network: NetworkStep,
        /// HTTP fetch step 3: a service worker handles the request. Wait for
        /// the call's answer (`take` from the event loop, `wait` blocking),
        /// give a response its body (its relay's), and hand it to
        /// `resumeServiceWorker`. Borrowed from the job until then.
        service_worker: *service_worker_fetch.Call,
        /// Main fetch step 23 needs the whole response body. Resume with
        /// resumeBody once its pipe has ended (finished or failed).
        body,
        /// Fetch has its response; `takeResult` hands it over.
        done,
    };

    /// Cookies are not the network's business: HTTP-network-or-cache fetch
    /// has put them in `request` already, and HTTP-network fetch stores the
    /// answer's (algorithms/cookies.zig).
    pub const NetworkStep = struct {
        request: *const NetworkRequest,
    };

    /// A service worker's answer, as `resumeServiceWorker` takes it: a
    /// response's body is attached by the driver (a pipe its relay fills, or
    /// the relay's bytes), so the response is all there is.
    pub const ServiceWorkerAnswer = union(enum) {
        fallback,
        network_error,
        /// Taken.
        response: *InternalResponse,
    };

    /// A job fetching `request`. With `owns_request`, the job frees it.
    pub fn create(allocator: Allocator, request: *InternalRequest, owns_request: bool, options: FetchOptions) FetchError!*FetchJob {
        const self = allocator.create(FetchJob) catch return FetchError.OutOfMemory;
        errdefer allocator.destroy(self);

        // Step 7-8: Create fetch controller and params
        const controller = FetchController.init(allocator) catch return FetchError.OutOfMemory;
        errdefer controller.deinit();

        self.* = .{
            .allocator = allocator,
            .request = request,
            .owns_request = owns_request,
            .options = options,
            // Step 6: Let timingInfo be a new fetch timing info
            .timing_info = FetchTimingInfo.init(allocator),
            .controller = controller,
            .params = undefined,
        };
        self.params = FetchParams.init(allocator, request, controller, &self.timing_info) catch {
            self.timing_info.deinit();
            return FetchError.OutOfMemory;
        };
        return self;
    }

    pub fn destroy(self: *FetchJob) void {
        const allocator = self.allocator;
        if (self.authentication_realm) |realm| allocator.free(realm);
        if (self.network_request) |request| http_fetch.freeNetworkRequest(allocator, request);
        // A service worker still answering: its answer is freed when it comes.
        if (self.service_worker_call) |call| {
            call.abandon();
            call.release();
        }
        if (self.response) |response| response.deinit();
        if (self.pending_response) |response| response.deinit();
        self.dropManualRedirect();
        // A body that never ended: nothing is reported.
        self.dropDeferredTiming();
        self.params.deinit();
        self.controller.deinit();
        self.timing_info.deinit();
        if (self.owns_request) self.request.deinit();
        allocator.destroy(self);
    }

    /// Run fetch until it needs the network or has its response.
    ///
    /// Per Fetch spec §4:
    /// 1. Let request be the request argument
    /// 2. If request's client is non-null and is not a secure context...
    /// 3. Let taskDestination be null
    /// 4. Let crossOriginIsolatedCapability be false
    /// 5. If useParallelQueue is true, set taskDestination to parallel queue
    /// 6. Let timingInfo be a new fetch timing info
    /// 7. Let fetchParams be a new fetch params
    /// 8. Set fetchParams's items
    /// 9. If request's body is a byte sequence, convert to Body
    /// 10. If request's window is "client", set to current global object
    /// 11. If request's origin is "client", set to current origin
    /// 12. If all requests are local, set local-URLs-only
    /// 13. If response is null, main fetch
    /// 14. Return response
    pub fn start(self: *FetchJob) FetchError!Step {
        // Record start time
        self.timing_info.start_time = http_fetch.getCurrentTimeMs();
        // Fetch step 7: resource timing preserves the request's blocking
        // decision, including when the timing info later becomes opaque.
        self.timing_info.render_blocking = self.request.render_blocking;

        // Set options
        self.params.cross_origin_isolated_capability = self.options.cross_origin_isolated_capability;
        if (self.options.process_response) |callback| {
            self.params.process_response = callback;
        }

        // Step 12: a request whose header list does not contain `Accept`
        // gets one, before main fetch - and so before a service worker sees
        // the request (fetch-event.https.html "Service Worker headers in the
        // request of a fetch event": Chrome, Firefox and Safari all pass).
        if (!self.request.header_list.contains("Accept")) {
            self.request.header_list.append("Accept", acceptValue(self.request)) catch return FetchError.OutOfMemory;
        }

        // Step 13: main fetch - for every scheme. Its step 12 decides
        // between scheme fetch (data:, about:, blob:, with the tainting and
        // filtering that come with it) and HTTP fetch, and turns any other
        // scheme into a network error; step 20 gives HEAD a null body. A
        // local scheme used to skip it, so a data: response came back
        // unfiltered - type "default", not "basic".
        return self.mainFetch();
    }

    /// Carry on from the network's answer to the request the last `.network`
    /// step asked for.
    pub fn resumeNetwork(self: *FetchJob, result: NetworkError!NetworkResponse) FetchError!Step {
        const allocator = self.allocator;
        const request = self.network_request orelse unreachable; // no request was asked for
        self.network_request = null;
        http_fetch.freeNetworkRequest(allocator, request);

        var network_response = result catch |err| switch (err) {
            NetworkError.OutOfMemory => return FetchError.OutOfMemory,
            else => return self.transportFailed(),
        };
        defer network_response.deinit();
        if (self.network_request_is_preflight) return self.corsPreflightAnswered(&network_response);

        const response = http_fetch.httpNetworkFetchFinish(allocator, self.params, &network_response, self.network_start_time, null) catch |err| {
            return self.httpFetchFailed(err);
        };
        return self.httpNetworkOrCacheFetchReturned(response);
    }

    /// Carry on from the network's answer to the request the last `.network`
    /// step asked for, as soon as its headers are in: `head` is the response
    /// without a body, whose ownership passes in, and `body` the pipe the
    /// body arrives through, which passes in too. The response fetch hands
    /// on reads its body from the pipe - unless it is not the one handed on
    /// (a redirect followed, a network error), when the pipe goes with it
    /// and, with no reader left, stops the transfer.
    pub fn resumeNetworkHead(self: *FetchJob, head: NetworkResponse, body: *BodyPipe) FetchError!Step {
        const allocator = self.allocator;
        const request = self.network_request orelse unreachable; // no request was asked for
        self.network_request = null;
        http_fetch.freeNetworkRequest(allocator, request);

        var network_response = head;
        defer network_response.deinit();
        if (self.network_request_is_preflight) {
            // A preflight's body is nobody's: letting the pipe go stops it.
            body.release();
            return self.corsPreflightAnswered(&network_response);
        }

        const response = http_fetch.httpNetworkFetchFinish(allocator, self.params, &network_response, self.network_start_time, body) catch |err| {
            return self.httpFetchFailed(err);
        };
        return self.httpNetworkOrCacheFetchReturned(response);
    }

    /// The result, once the job is `.done`. Called once.
    pub fn takeResult(self: *FetchJob) FetchResult {
        const response = self.response orelse unreachable; // the job is not done
        self.response = null;
        // A redirect of a navigation followed by hand: the fetch goes on, and
        // its timing info with it, to the response that ends it.
        if (self.next_manual_redirect != null) {
            return .{ .response = response, .timing_info = FetchTimingInfo.init(self.allocator) };
        }
        const timing_info = self.timing_info;
        self.timing_info = FetchTimingInfo.init(self.allocator);
        // Out of memory, the referrer is left out (null): the document gets
        // the empty string, as for no referrer.
        const referrer: ?[]u8 = if (!self.options.report_referrer) null else switch (self.request.referrer) {
            .url => |url| response.allocator.dupe(u8, url) catch null,
            .no_referrer, .client => null,
        };
        return .{ .response = response, .timing_info = timing_info, .referrer = referrer };
    }

    /// Whether the response handed over is a navigation's redirect, with
    /// the fetch controller's next manual redirect steps set.
    pub fn hasNextManualRedirect(self: *const FetchJob) bool {
        return self.next_manual_redirect != null;
    }

    /// The location URL of the redirect handed over (HTML "create
    /// navigation params by fetching" step 21.14's locationURL); null when
    /// there is no next manual redirect, or the location is failure.
    pub fn nextManualRedirectUrl(self: *const FetchJob) ?[]const u8 {
        const next = self.next_manual_redirect orelse return null;
        return next.location;
    }

    /// Fetch "process the next manual redirect": the controller's next
    /// manual redirect steps - HTTP-redirect fetch given fetchParams and the
    /// redirect response - and main fetch, one deeper, as far as it can go:
    /// the next hop's request, with every per-request check main fetch makes
    /// (as a redirect that is followed gets), and HTTP fetch step 3 - its
    /// service worker - again.
    pub fn processNextManualRedirect(self: *FetchJob) FetchError!Step {
        const next = self.next_manual_redirect orelse return FetchError.NetworkError;
        self.next_manual_redirect = null;
        if (next.location) |location| self.allocator.free(location);
        const redirected = http_fetch.httpRedirectFetchStart(self.allocator, self.params, next.response) catch |err| {
            return self.httpFetchFailed(err);
        };
        switch (redirected) {
            // A network error: a location that is failure or not HTTP(S), too
            // many redirects, a body that cannot be sent again.
            .response => |r| return self.mainFetchFetched(r),
            .recursive_main_fetch => {
                self.depth += 1;
                return self.mainFetch();
            },
            .manual_redirect => |r| return self.manualRedirect(r),
        }
    }

    /// HTTP fetch step 6 "manual" for a navigation: `response` (taken) is
    /// HTTP fetch's response, and the next manual redirect steps keep a copy
    /// of it. A redirect with no `Location` has no location URL - HTML takes
    /// it as the response that ends the navigation's fetch - so it keeps no
    /// steps either.
    fn manualRedirect(self: *FetchJob, response: *InternalResponse) FetchError!Step {
        const allocator = self.allocator;
        // A client that does not follow them: an opaque-redirect.
        if (!self.options.follows_manual_redirects) {
            response.response_type = .opaqueredirect;
            return self.mainFetchFetched(response);
        }
        const location: ?[]u8 = http_fetch.locationUrl(allocator, response, self.request.currentUrl()) catch |err| switch (err) {
            error.OutOfMemory => {
                response.deinit();
                return FetchError.OutOfMemory;
            },
            error.InvalidLocation => null,
        };
        const has_location = location != null or hasLocationHeader(response);
        if (!has_location) return self.mainFetchFetched(response);
        const kept = manualRedirectCopy(allocator, response) catch {
            if (location) |l| allocator.free(l);
            response.deinit();
            return FetchError.OutOfMemory;
        };
        self.dropManualRedirect();
        self.next_manual_redirect = .{ .response = kept, .location = location };
        return self.mainFetchFetched(response);
    }

    fn hasLocationHeader(response: *const InternalResponse) bool {
        for (response.header_list.iterator()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "Location")) return true;
        }
        return false;
    }

    /// What HTTP-redirect fetch reads of a redirect response: its status,
    /// type, headers and URL list - not its body.
    fn manualRedirectCopy(allocator: Allocator, response: *const InternalResponse) Allocator.Error!*InternalResponse {
        const copy = try InternalResponse.init(allocator);
        errdefer copy.deinit();
        copy.response_type = response.response_type;
        copy.status = response.status;
        copy.header_list.deinit();
        copy.header_list = try response.header_list.clone(allocator);
        for (response.url_list.items) |url| try copy.addUrl(url);
        return copy;
    }

    fn dropManualRedirect(self: *FetchJob) void {
        const next = self.next_manual_redirect orelse return;
        self.next_manual_redirect = null;
        next.response.deinit();
        if (next.location) |location| self.allocator.free(location);
    }

    /// Main fetch, at the current depth, as far as it can go.
    fn mainFetch(self: *FetchJob) FetchError!Step {
        const allocator = self.allocator;
        const begun = main_fetch.mainFetchStart(allocator, self.params, self.depth > 0) catch {
            return FetchError.OutOfMemory;
        };
        const make_cors_preflight = switch (begun) {
            .response => |response| return self.mainFetchFetched(response),
            .http_fetch => false,
            .http_fetch_with_cors_preflight => true,
        };

        // HTTP fetch step 3: a service worker, before any request goes out
        // (a preflight is the network's, step 4.1).
        const handled = http_fetch.handleFetchStart(self.params) catch |err| return self.httpFetchFailed(err);
        if (handled) |started| {
            self.service_worker_call = started.call;
            self.service_worker_start_time = started.start_time;
            self.service_worker_preflight = make_cors_preflight;
            self.service_worker_race = started.race;
            return .{ .service_worker = started.call };
        }
        return self.httpFetchFromNetwork(make_cors_preflight);
    }

    /// Carry on from a service worker's answer to the `.service_worker`
    /// step: HTTP fetch step 3.5 - or 3.6, nothing: step 4, the network.
    pub fn resumeServiceWorker(self: *FetchJob, answer: ServiceWorkerAnswer) FetchError!Step {
        const call = self.service_worker_call orelse unreachable; // no service worker was asked
        self.service_worker_call = null;
        self.service_worker_race = false;
        call.release();
        switch (answer) {
            .fallback => return self.httpFetchFromNetwork(self.service_worker_preflight),
            .network_error => return self.mainFetchFetched(try networkError(self.allocator)),
            .response => |response| {
                const next = http_fetch.serviceWorkerResponse(self.allocator, self.params, response, self.service_worker_start_time) catch |err| {
                    return self.httpFetchFailed(err);
                };
                switch (next) {
                    .response => |r| return self.mainFetchFetched(r),
                    .recursive_main_fetch => {
                        // HTTP-redirect fetch steps 20-22 for the service
                        // worker's redirect: main fetch again, one deeper.
                        self.depth += 1;
                        return self.mainFetch();
                    },
                    .manual_redirect => |r| return self.manualRedirect(r),
                }
            },
        }
    }

    /// Whether the `.service_worker` step's call races the network (Handle
    /// Fetch 13.3.4).
    pub fn serviceWorkerRaces(self: *const FetchJob) bool {
        return self.service_worker_call != null and self.service_worker_race;
    }

    /// Handle Fetch 13.3.4.5.2's "fetch given request", for the race's
    /// network side: a clone of the request (OWNED by the caller) as it is
    /// now - its URL list, its client's cookie jar and network. Its
    /// service-workers mode is "none": the spec's request would reach Handle
    /// Fetch again, and Chromium's race request bypasses the worker
    /// (ServiceWorkerMainResourceLoader::StartRaceNetworkRequest). It reports
    /// nothing of its own - the raced fetch reports the one Resource Timing
    /// entry - and checks no integrity: the raced fetch's main fetch step 23
    /// does, for whichever answer wins.
    pub fn raceRequest(self: *FetchJob) FetchError!*InternalRequest {
        const copy = self.request.clone() catch return FetchError.OutOfMemory;
        copy.service_workers_mode = .none;
        copy.service_worker = null;
        copy.reserved_client = null;
        copy.initiator_type = null;
        copy.timing_reporter = null;
        if (copy.integrity_metadata.len != 0) {
            copy.allocator.free(copy.integrity_metadata);
            copy.integrity_metadata = "";
        }
        return copy;
    }

    /// HTTP fetch step 4, from the network: a CORS-preflight first when
    /// `make_cors_preflight` asks for one (4.1), then HTTP-network-or-cache
    /// fetch.
    fn httpFetchFromNetwork(self: *FetchJob, make_cors_preflight: bool) FetchError!Step {
        const allocator = self.allocator;
        // 4.2. "If request's redirect mode is "follow", then set request's
        // service-workers mode to "none"": redirects from the network are
        // not exposed to a service worker - the recursive main fetch of one
        // goes to the network too.
        if (self.request.redirect_mode == .follow) self.request.service_workers_mode = .none;
        if (!make_cors_preflight) return self.httpNetworkOrCacheFetch();

        // HTTP fetch step 4.1, with makeCORSPreflight: a CORS-preflight fetch
        // first, when the request needs one. Its answer arrives through
        // `resumeNetwork`/`resumeNetworkHead`, which hand it to
        // `corsPreflightAnswered`.
        const needed = http_fetch.corsPreflightNeeded(allocator, self.request) catch return FetchError.OutOfMemory;
        if (!needed) return self.httpNetworkOrCacheFetch();
        const preflight = http_fetch.corsPreflightFetchStart(allocator, self.request) catch |err| {
            return self.httpFetchFailed(err);
        };
        self.network_request = preflight;
        self.network_request_is_preflight = true;
        self.network_start_time = http_fetch.getCurrentTimeMs();
        // A CORS-preflight request never carries credentials: its
        // credentials mode is "same-origin" and its tainting "cors".
        return .{ .network = .{ .request = &self.network_request.? } };
    }

    /// CORS-preflight fetch steps 7-8, once the network answered the
    /// preflight: a network error, or on to HTTP fetch step 4.3.
    fn corsPreflightAnswered(self: *FetchJob, network_response: *const NetworkResponse) FetchError!Step {
        self.network_request_is_preflight = false;
        const allowed = http_fetch.corsPreflightFetchFinish(self.allocator, self.request, network_response) catch {
            return FetchError.OutOfMemory;
        };
        if (!allowed) return self.httpFetchFailed(http_fetch.HttpFetchError.CorsError);
        return self.httpNetworkOrCacheFetch();
    }

    /// HTTP fetch step 4.3: HTTP-network-or-cache fetch, as far as it can go.
    /// Main fetch passes HTTP fetch no options.
    fn httpNetworkOrCacheFetch(self: *FetchJob) FetchError!Step {
        const allocator = self.allocator;
        const network_start = http_fetch.httpNetworkOrCacheFetchStart(allocator, self.params, .{
            .is_authentication_fetch = self.is_authentication_fetch,
            .authentication_realm = self.authentication_realm,
        }) catch |err| {
            return self.httpFetchFailed(err);
        };
        switch (network_start) {
            .response => |response| return self.httpNetworkOrCacheFetchReturned(response),
            .network => |request| {
                self.network_request = request;
                self.network_start_time = http_fetch.getCurrentTimeMs();
                return .{ .network = .{ .request = &self.network_request.? } };
            },
        }
    }

    /// HTTP fetch, once HTTP-network-or-cache fetch has returned `response`.
    fn httpNetworkOrCacheFetchReturned(self: *FetchJob, network_response: *InternalResponse) FetchError!Step {
        // The rest of HTTP-network-or-cache fetch (step 14, a 401).
        const finished = http_fetch.httpNetworkOrCacheFetchFinish(self.allocator, self.params, .{
            .is_authentication_fetch = self.is_authentication_fetch,
            .authentication_realm = self.authentication_realm,
        }, network_response) catch |err| {
            return self.httpFetchFailed(err);
        };
        const response = switch (finished) {
            .response => |r| r,
            .authentication_retry => |realm| {
                if (self.authentication_realm) |old| self.allocator.free(old);
                self.authentication_realm = realm;
                self.is_authentication_fetch = true;
                // The normal network step: both drivers schedule it in the
                // same way as the first request, never inside a curl callback.
                return self.httpNetworkOrCacheFetch();
            },
        };
        const next = http_fetch.httpFetchFinish(self.allocator, self.params, .{}, response) catch |err| {
            return self.httpFetchFailed(err);
        };
        switch (next) {
            .response => |r| return self.mainFetchFetched(r),
            .manual_redirect => |r| return self.manualRedirect(r),
            .recursive_main_fetch => {
                self.is_authentication_fetch = false;
                if (self.authentication_realm) |realm| self.allocator.free(realm);
                self.authentication_realm = null;
                // HTTP-redirect fetch steps 20-22: main fetch again, one deeper.
                self.depth += 1;
                return self.mainFetch();
            },
        }
    }

    /// Preserve the known transport failure for HTML 9.2.2 step 15.2's
    /// retry decision. Policy, scheme and CORS errors keep the default;
    /// a failed preflight is not a retryable event-stream connection either.
    fn transportFailed(self: *FetchJob) FetchError!Step {
        const response = try networkError(self.allocator);
        if (!self.network_request_is_preflight) response.network_error_cause = .transport;
        return self.mainFetchFetched(response);
    }

    /// Main fetch, when the HTTP fetch it ran failed: a network error is its
    /// response.
    fn httpFetchFailed(self: *FetchJob, err: http_fetch.HttpFetchError) FetchError!Step {
        switch (err) {
            http_fetch.HttpFetchError.OutOfMemory => return FetchError.OutOfMemory,
            http_fetch.HttpFetchError.NetworkError,
            http_fetch.HttpFetchError.CorsError,
            => return self.mainFetchFetched(try networkError(self.allocator)),
        }
    }

    /// Main fetch at the current depth, once its step 12 fetch has produced
    /// `response`: the rest of it, and of every HTTP-redirect fetch and HTTP
    /// fetch waiting on it, out to fetch itself.
    fn mainFetchFetched(self: *FetchJob, response: *InternalResponse) FetchError!Step {
        // Main fetch 12, CORS-with-preflight branch, step 3: every network
        // error clears these entries, including the actual request's failure.
        // Success never computes the branch predicate or touches the store.
        if ((response.response_type == .@"error" or response.status == 0) and self.request.response_tainting == .cors) {
            const request = self.request;
            const with_preflight = request.use_cors_preflight or (request.unsafe_request and blk: {
                if (!main_fetch.isCorsSafelistedMethod(request.method)) break :blk true;
                const names = @import("../internal/validation.zig").getCORSUnsafeRequestHeaderNames(self.allocator, &request.header_list) catch {
                    response.deinit();
                    return FetchError.OutOfMemory;
                };
                defer {
                    for (names) |name| self.allocator.free(name);
                    self.allocator.free(names);
                }
                break :blk names.len > 0;
            });
            if (with_preflight) http_fetch.clearPreflightEntries(self.allocator, request) catch {
                response.deinit();
                return FetchError.OutOfMemory;
            };
        }
        var r = response;
        while (self.depth > 0) {
            // A recursive main fetch returns its response to the HTTP-redirect
            // fetch that ran it, which returns it to HTTP fetch, which returns
            // it to the main fetch one level out.
            r = main_fetch.mainFetchFinish(self.params, true, r);
            self.depth -= 1;
            r = http_fetch.httpRedirectFetchFinish(self.allocator, self.params, r) catch {
                return FetchError.OutOfMemory;
            };
        }
        const final_response = main_fetch.mainFetchFinish(self.params, false, r);
        // Main fetch step 23 precedes handover only when integrity is set.
        // Recursive redirect fetches return at step 13, above this branch.
        if (self.request.integrity_metadata.len != 0) {
            if (!main_fetch.integrityBodyEligible(final_response))
                return self.finish(main_fetch.mainFetchIntegrity(self.params, final_response));
            self.pending_response = final_response;
            return .body;
        }
        return self.finish(final_response);
    }

    /// Resume main fetch step 23 after the complete body (or its error).
    /// Timing and process_response remain in finish, after verification.
    pub fn resumeBody(self: *FetchJob) FetchError!Step {
        const response = self.pending_response orelse return FetchError.NetworkError;
        self.pending_response = null;
        return self.finish(main_fetch.mainFetchIntegrity(self.params, response));
    }

    /// Fetch's steps after main fetch returned `response`.
    fn finish(self: *FetchJob, response: *InternalResponse) Step {
        // A navigation's redirect followed by hand: handed over to HTML,
        // whose navigation goes on with the next manual redirect. The fetch
        // is not over - its end time, Server-Timing, resource timing entry
        // and process response are the response's that ends it, as for a
        // redirect fetch follows itself.
        if (self.next_manual_redirect != null) {
            self.body_sizes = null;
            self.response = response;
            return .done;
        }
        // Record end time
        self.timing_info.end_time = http_fetch.getCurrentTimeMs();

        // Fetch response handover step 2, before either resource reporting
        // or handing full timing info to navigation. The internal response
        // still has its headers: consumers apply the response filter later.
        // Expose in non-secure contexts too, as Fetch permits and Blink does;
        // reportTiming's opaque timing info removes metrics without TAO.
        // getDecodeSplit allocates nothing when the header is absent.
        if (response.response_type != .@"error") {
            if (response.header_list.getDecodeSplit(self.allocator, "Server-Timing") catch null) |headers| {
                self.timing_info.server_timing_headers = .{ .items = @constCast(headers), .capacity = headers.len };
            }
        }

        // Fetch response handover step 4: the report timing steps - now, or
        // at the end of a body still arriving.
        self.handOverTiming(response);

        // Call process response callback if set
        if (self.options.process_response) |callback| {
            callback(response);
        }

        self.response = response;
        return .done;
    }

    /// Fetch "fetch response handover" step 4 for `response`, the response
    /// handed over: the report timing steps run from processResponseEndOfBody
    /// - at the end of the body. A body all there already (collected, or
    /// none) is reported now; one still arriving keeps what the steps read of
    /// the response, and the timing info as it is now, until the driver
    /// reports its end (`bodyEnded`) - Chromium's point in time, the loader's
    /// end, the body received or failed (resource_fetcher.cc
    /// HandleLoaderFinish / HandleLoaderError), not the consumer's read of
    /// its last chunk (stated). A job that goes before then reports nothing.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#fetch-finale
    fn handOverTiming(self: *FetchJob, response: *const InternalResponse) void {
        if (!self.reportsTiming()) return;
        var facts = self.timingFacts(response);
        if (self.body_sizes == null and bodyArriving(response)) {
            const copy = cloneTimingInfo(&self.timing_info) catch {
                facts.deinit(self.allocator);
                return;
            };
            self.dropDeferredTiming();
            self.deferred_timing = .{ .facts = facts, .timing_info = copy };
            return;
        }
        defer facts.deinit(self.allocator);
        if (self.body_sizes) |sizes| facts.setSizes(sizes);
        self.body_sizes = null;
        self.reportFacts(&facts, &self.timing_info);
    }

    /// The driver's word that the body of the response handed over has
    /// ended - finished, failed, or with no reader left - with `sizes`, what
    /// arrived of it: the report timing steps run now (handover step 4.1's
    /// unsafeEndTime is this moment), once. Before the handover that reports
    /// it (main fetch step 23 waiting for an integrity check's body, a
    /// race's network body), the sizes wait for it.
    pub fn bodyEnded(self: *FetchJob, sizes: BodySizes) void {
        var deferred = self.deferred_timing orelse {
            self.body_sizes = sizes;
            return;
        };
        self.deferred_timing = null;
        defer deferred.deinit(self.allocator);
        deferred.timing_info.end_time = http_fetch.getCurrentTimeMs();
        deferred.facts.setSizes(sizes);
        self.reportFacts(&deferred.facts, &deferred.timing_info);
    }

    /// Whether the job waits for its body's end: a report deferred to it, or
    /// main fetch step 23 waiting for the whole body.
    pub fn awaitsBodyEnd(self: *const FetchJob) bool {
        return self.deferred_timing != null or self.pending_response != null;
    }

    fn dropDeferredTiming(self: *FetchJob) void {
        if (self.deferred_timing) |*deferred| deferred.deinit(self.allocator);
        self.deferred_timing = null;
    }

    /// 4.2.1 and 4.3: a request whose report timing steps run - one with an
    /// initiator type, whose client's global hears it, and an HTTP(S) URL.
    fn reportsTiming(self: *const FetchJob) bool {
        const request = self.request;
        if (request.initiator_type == null or request.timing_reporter == null) return false;
        const url = request.getUrl();
        return std.mem.startsWith(u8, url, "http:") or std.mem.startsWith(u8, url, "https:");
    }

    /// Whether `response`'s body is still arriving through its pipe.
    fn bodyArriving(response: *const InternalResponse) bool {
        const internal = response.internal orelse response;
        const body = internal.body orelse response.body orelse return false;
        const pipe = body.pipe orelse return false;
        return pipe.state == .open;
    }

    /// 4.2.3-4.2.7 for `response`: what the report reads of it.
    fn timingFacts(self: *FetchJob, response: *const InternalResponse) TimingFacts {
        const request = self.request;
        // 4.2.3-4.2.4. cacheState and bodyInfo.
        var facts: TimingFacts = .{
            .cache_state = switch (response.cache_state) {
                .empty => "",
                .local => "local",
                .validated => "validated",
            },
            .body_info = response.body_info,
            .timing_allow_passed = response.timing_allow_passed,
        };
        // The body info's strings are the response's, which is its client's
        // once handed over: kept as copies.
        facts.body_info.content_type = "";
        facts.body_info.content_encoding = "";
        if (response.body_info.content_encoding.len > 0) {
            if (self.allocator.dupe(u8, response.body_info.content_encoding)) |owned| {
                facts.content_encoding = owned;
                facts.body_info.content_encoding = owned;
            } else |_| {}
        }
        const opaque_response = response.response_type == .@"opaque" or response.response_type == .opaqueredirect;
        // 4.2.5. A response whose timing allow passed flag is not set (a
        // network error too) is reported with an opaque timing info
        // (`reportFacts`) and no cache state.
        if (!response.timing_allow_passed) {
            facts.cache_state = "";
            // Body sizes are CORS-protected, not TAO-protected (whatwg/fetch
            // PR #1556, 2023-01-25): a CORS response's body info stays, and
            // only the opaque filters below hide it. Firefox 157 ships it
            // (resource-timing/body-size-cross-origin.https.html 6/6; Chrome
            // 154 4/6, Safari 27 3/6 at wpt.fyi cc74d2669f). Golden rule 2 as
            // refined 2026-10-17: a newer spec one browser ships wins
            // (gr2audit D4).
        }
        // 4.2.4 reads the filtered response's body info. Both opaque and
        // opaque-redirect filters hide it, including a same-origin manual
        // redirect whose request tainting is still basic.
        if (opaque_response) {
            facts.body_info = .{};
            facts.hides_body = true;
        }
        // A network error has no body to size.
        if (response.response_type == .@"error") facts.hides_body = true;
        // 4.2.6-4.2.7. responseStatus and the minimized content type, unless
        // this is a navigation redirected across origins.
        if (request.mode != .navigate or response.redirect_taint == .same_origin) {
            // 4.2.7.1 reads the filtered response's status, not its
            // internal response. TAO exposes timing, never an opaque
            // response's status (including same-origin manual redirects).
            facts.response_status = if (opaque_response) 0 else response.status;
            if (!opaque_response) {
                if (@import("../internal/mime.zig").extractMimeType(self.allocator, &response.header_list) catch null) |mime_type| {
                    var parsed = mime_type;
                    defer parsed.deinit();
                    facts.content_type = @import("mimesniff").minimizeSupportedMimeType(self.allocator, &parsed) catch null;
                    if (facts.content_type) |c| facts.body_info.content_type = c;
                }
            }
        }
        return facts;
    }

    /// 4.2.2, 4.2.5 and 4.2.8: mark resource timing with `facts` and
    /// `timing_info` (made opaque when the timing allow check failed), given
    /// the request's client's global - its timing reporter.
    fn reportFacts(self: *FetchJob, facts: *const TimingFacts, timing_info: *const FetchTimingInfo) void {
        const request = self.request;
        const reporter = request.timing_reporter orelse return;
        const initiator_type = request.initiator_type orelse return;
        var opaque_timing: ?FetchTimingInfo = null;
        defer if (opaque_timing) |*o| o.deinit();
        var reported: *const FetchTimingInfo = timing_info;
        if (!facts.timing_allow_passed) {
            opaque_timing = @import("../internal/fetch_timing.zig").createOpaqueTimingInfo(self.allocator, timing_info);
            reported = &opaque_timing.?;
        }
        // 4.2.8. Mark resource timing (the reporter's global does).
        reporter.report(reporter.context, &.{
            .timing_info = reported,
            .url = request.getUrl(),
            .initiator_type = initiator_type,
            .cache_state = facts.cache_state,
            .body_info = facts.body_info,
            .response_status = facts.response_status,
            .timing_allow_passed = facts.timing_allow_passed,
        });
    }
};

/// What the driver measured of a body, at its end (FetchJob.bodyEnded): the
/// network hands its body over decoded, and a service worker's relay its
/// bytes as written, so the encoded and decoded sizes are equal there.
pub const BodySizes = struct {
    encoded: u64,
    decoded: u64,
};

/// What the report timing steps read of a response (Fetch response handover
/// 4.2.3-4.2.7), taken when it is handed over. OWNED (`deinit`).
const TimingFacts = struct {
    cache_state: []const u8,
    body_info: @import("../internal/fetch_timing.zig").ResponseBodyInfo,
    response_status: u16 = 0,
    timing_allow_passed: bool,
    /// An opaque filter hides the body info: no sizes either.
    hides_body: bool = false,
    /// Owned copies of the body info's strings.
    content_type: ?[]const u8 = null,
    content_encoding: ?[]const u8 = null,

    fn setSizes(self: *TimingFacts, sizes: BodySizes) void {
        if (self.hides_body) return;
        self.body_info.encoded_size = sizes.encoded;
        self.body_info.decoded_size = sizes.decoded;
    }

    fn deinit(self: *TimingFacts, allocator: Allocator) void {
        if (self.content_type) |c| allocator.free(c);
        if (self.content_encoding) |c| allocator.free(c);
        self.* = undefined;
    }
};

/// A report waiting for its body's end: the facts, and the timing info as it
/// was handed over (`takeResult` gives the job's own to the client).
const DeferredTiming = struct {
    facts: TimingFacts,
    timing_info: FetchTimingInfo,

    fn deinit(self: *DeferredTiming, allocator: Allocator) void {
        self.facts.deinit(allocator);
        self.timing_info.deinit();
    }
};

/// A copy of `info` that owns its own Server-Timing headers.
fn cloneTimingInfo(info: *const FetchTimingInfo) Allocator.Error!FetchTimingInfo {
    var copy = info.*;
    copy.server_timing_headers = .empty;
    errdefer copy.deinit();
    for (info.server_timing_headers.items) |header| try copy.addServerTimingHeader(header);
    return copy;
}

fn networkError(allocator: Allocator) FetchError!*InternalResponse {
    return internal_response.networkError(allocator) catch FetchError.OutOfMemory;
}

/// Fetch: the document `Accept` header value.
const document_accept_value = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";

/// Fetch "fetch" steps 12.1-12.3: the `Accept` value for `request`.
fn acceptValue(request: *const InternalRequest) []const u8 {
    // 12.2. A prefetch: the document `Accept` header value.
    if (request.initiator == .prefetch) return document_accept_value;
    // 12.3. By destination; 12.1 otherwise.
    return switch (request.destination) {
        .document, .frame, .iframe => document_accept_value,
        .image => "image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5",
        .json => "application/json,*/*;q=0.5",
        .style => "text/css,*/*;q=0.1",
        .text => "text/plain,*/*;q=0.5",
        else => "*/*",
    };
}

/// Extract scheme from URL string.
pub fn extractScheme(url_str: []const u8) []const u8 {
    const colon_pos = std.mem.indexOf(u8, url_str, ":");
    if (colon_pos) |pos| {
        return url_str[0..pos];
    }
    return "";
}

const TestTimingReports = struct {
    count: usize = 0,
    url: [64]u8 = undefined,
    url_len: usize = 0,
    initiator: ?internal_request.InitiatorType = null,
    status: u16 = 0,
    start_time: f64 = 0,

    fn report(context: *anyopaque, timing: *const internal_request.TimingReport) void {
        const self: *TestTimingReports = @ptrCast(@alignCast(context));
        self.count += 1;
        @memcpy(self.url[0..timing.url.len], timing.url);
        self.url_len = timing.url.len;
        self.initiator = timing.initiator_type;
        self.status = timing.response_status;
        self.start_time = timing.timing_info.start_time;
    }
};

fn testAnswer(status: u16) NetworkResponse {
    return .{
        .allocator = std.testing.allocator,
        .status = status,
        .http_version = .http_1_1,
        .headers = std.testing.allocator.alloc(NetworkResponse.Header, 0) catch unreachable,
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

test "fetch response handover: a request with an initiator type reports its timing to its client's global, once" {
    const allocator = std.testing.allocator;
    var reports: TestTimingReports = .{};
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.initiator_type = .fetch;
    request.timing_reporter = .{ .context = &reports, .report = &TestTimingReports.report };
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    try std.testing.expect(step == .network);
    const done = try job.resumeNetwork(testAnswer(204));
    try std.testing.expect(done == .done);
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqualStrings("http://a.test/x", reports.url[0..reports.url_len]);
    try std.testing.expectEqual(internal_request.InitiatorType.fetch, reports.initiator.?);
    try std.testing.expectEqual(@as(u16, 204), reports.status);
    try std.testing.expect(reports.start_time > 0);
}

test "fetch response handover: no initiator type, or a scheme that is not HTTP(S), reports nothing" {
    const allocator = std.testing.allocator;
    var reports: TestTimingReports = .{};
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.timing_reporter = .{ .context = &reports, .report = &TestTimingReports.report };
        const job = try FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        _ = try job.start();
        _ = try job.resumeNetwork(testAnswer(200));
    }
    {
        const request = try InternalRequest.init(allocator, "data:,hello");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.initiator_type = .fetch;
        request.timing_reporter = .{ .context = &reports, .report = &TestTimingReports.report };
        const job = try FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .done);
    }
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

test "fetch result: the request's referrer as main fetch determined it" {
    const allocator = std.testing.allocator;
    // Same origin, the default policy (strict-origin-when-cross-origin): the
    // referrer stripped for use as a referrer - its fragment gone.
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        try request.setReferrerUrl("http://a.test/page?q=1#frag");
        const job = try FetchJob.create(allocator, request, false, .{ .report_referrer = true });
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        try std.testing.expect(try job.resumeNetwork(testAnswer(200)) == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqualStrings("http://a.test/page?q=1", result.referrer.?);
    }
    // Cross origin, the same policy: the referrer's origin only.
    {
        const request = try InternalRequest.init(allocator, "http://b.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        try request.setReferrerUrl("http://a.test/page?q=1");
        const job = try FetchJob.create(allocator, request, false, .{ .report_referrer = true });
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        try std.testing.expect(try job.resumeNetwork(testAnswer(200)) == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqualStrings("http://a.test/", result.referrer.?);
    }
    // "no-referrer", and a policy that sends none: no referrer.
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.setReferrer(.no_referrer);
        const job = try FetchJob.create(allocator, request, false, .{ .report_referrer = true });
        defer job.destroy();
        _ = try job.start();
        _ = try job.resumeNetwork(testAnswer(200));
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expect(result.referrer == null);
    }
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        try request.setReferrerUrl("http://a.test/page");
        request.referrer_policy = .no_referrer;
        const job = try FetchJob.create(allocator, request, false, .{ .report_referrer = true });
        defer job.destroy();
        _ = try job.start();
        _ = try job.resumeNetwork(testAnswer(200));
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expect(result.referrer == null);
    }
    // Not asked for: none, whatever the request's referrer - the callers that
    // take a result apart without FetchResult.deinit never see one to free.
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        try request.setReferrerUrl("http://a.test/page");
        const job = try FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        _ = try job.start();
        _ = try job.resumeNetwork(testAnswer(200));
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expect(result.referrer == null);
    }
}

/// A route's owner for the tests: Handle Fetch hands every request to a
/// "service worker" (or to none), and the test answers as the worker would.
const TestServiceWorkers = struct {
    handles: bool = true,
    asked: u32 = 0,
    /// The worker side's reference to the last call.
    call: ?*service_worker_fetch.Call = null,

    fn route(self: *TestServiceWorkers) internal_request.ServiceWorkerRoute {
        return .{ .context = self, .client = 7, .handle = handle };
    }

    fn handle(context: *anyopaque, request: *const InternalRequest, client: u64) std.mem.Allocator.Error!service_worker_fetch.Route.Start {
        const self: *TestServiceWorkers = @ptrCast(@alignCast(context));
        _ = request;
        std.debug.assert(client == 7);
        self.asked += 1;
        if (!self.handles) return .network;
        const call = try service_worker_fetch.Call.create(std.testing.allocator);
        self.call = call;
        return .{ .call = call };
    }

    /// The worker answers the last call and lets go of it.
    fn answer(self: *TestServiceWorkers, value: service_worker_fetch.Call.Answer) void {
        const call = self.call.?;
        self.call = null;
        call.answer(value);
        call.release();
    }
};

fn testServiceWorkerResponse(status: u16) !*InternalResponse {
    const response = try InternalResponse.init(std.testing.allocator);
    response.status = status;
    return response;
}

test "HTTP fetch step 3: Handle Fetch returning null goes to the network, and the network's redirects never reach a service worker" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{ .handles = false };
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.service_worker = workers.route();
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    try std.testing.expectEqual(@as(u32, 1), workers.asked);
    // Step 4.2: a request that follows redirects is "none" from here: the
    // recursive main fetch of a redirect the network answers asks no one.
    try std.testing.expectEqual(internal_request.ServiceWorkersMode.none, request.service_workers_mode);

    // A request whose mode is "none" never asks.
    const other = try InternalRequest.init(allocator, "http://a.test/y");
    defer other.deinit();
    try other.setOrigin("http://a.test");
    other.service_worker = workers.route();
    other.service_workers_mode = .none;
    const other_job = try FetchJob.create(allocator, other, false, .{});
    defer other_job.destroy();
    try std.testing.expect(try other_job.start() == .network);
    try std.testing.expectEqual(@as(u32, 1), workers.asked);
}

test "HTTP fetch step 3.5: a service worker's response is fetch's, with no network step and its start time recorded" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{};
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.service_worker = workers.route();
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    try std.testing.expect(step == .service_worker);
    workers.answer(.{ .response = .{ .response = try testServiceWorkerResponse(201) } });
    const answer = step.service_worker.take().?;
    const done = try job.resumeServiceWorker(.{ .response = answer.response.response });
    try std.testing.expect(done == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(u16, 201), result.response.status);
    // Main fetch step 14 filtered the service worker's new Response().
    try std.testing.expectEqual(internal_response.ResponseType.basic, result.response.response_type);
    try std.testing.expect(result.timing_info.final_service_worker_start_time > 0);
}

test "HTTP fetch step 3: a fallback answer goes to the network; a network error answer is fetch's" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{};
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.service_worker = workers.route();
        const job = try FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        const step = try job.start();
        workers.answer(.fallback);
        _ = step.service_worker.take().?;
        try std.testing.expect(try job.resumeServiceWorker(.fallback) == .network);
        try std.testing.expect(try job.resumeNetwork(testAnswer(200)) == .done);
    }
    {
        const request = try InternalRequest.init(allocator, "http://a.test/x");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.service_worker = workers.route();
        const job = try FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        const step = try job.start();
        workers.answer(.network_error);
        _ = step.service_worker.take().?;
        try std.testing.expect(try job.resumeServiceWorker(.network_error) == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(internal_response.ResponseType.@"error", result.response.response_type);
    }
}

test "HTTP fetch step 3.5.7: a response the request may not use is a network error" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{};
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .same_origin;
    request.service_worker = workers.route();
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    const step = try job.start();
    const cors = try testServiceWorkerResponse(200);
    cors.response_type = .cors;
    workers.answer(.{ .response = .{ .response = cors } });
    const answer = step.service_worker.take().?;
    try std.testing.expect(try job.resumeServiceWorker(.{ .response = answer.response.response }) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(internal_response.ResponseType.@"error", result.response.response_type);
}

test "a service worker's redirect is followed by main fetch again, which asks the service worker again" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{};
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.service_worker = workers.route();
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    const first = try job.start();
    const redirect = try testServiceWorkerResponse(302);
    // Response.redirect() makes an absolute Location: a service worker's
    // response has no URL to resolve a relative one against.
    try redirect.header_list.append("Location", "http://a.test/y");
    workers.answer(.{ .response = .{ .response = redirect } });
    const answer = first.service_worker.take().?;
    const second = try job.resumeServiceWorker(.{ .response = answer.response.response });
    try std.testing.expect(second == .service_worker);
    try std.testing.expectEqual(@as(u32, 2), workers.asked);
    try std.testing.expectEqualStrings("http://a.test/y", request.currentUrl());
    workers.answer(.{ .response = .{ .response = try testServiceWorkerResponse(200) } });
    const final = second.service_worker.take().?;
    try std.testing.expect(try job.resumeServiceWorker(.{ .response = final.response.response }) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.response.url_list.items.len);
}

test "a fetch ended while a service worker answers abandons the call: the late answer is freed" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{};
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.service_worker = workers.route();
    const job = try FetchJob.create(allocator, request, false, .{});
    try std.testing.expect(try job.start() == .service_worker);
    job.destroy();
    try std.testing.expect(workers.call.?.isAbandoned());
    workers.answer(.{ .response = .{ .response = try testServiceWorkerResponse(200) } });
}

fn testRedirect(status: u16, location: []const u8) NetworkResponse {
    var answer = testAnswer(status);
    std.testing.allocator.free(answer.headers);
    answer.headers = std.testing.allocator.alloc(NetworkResponse.Header, 1) catch unreachable;
    answer.headers[0] = .{
        .name = std.testing.allocator.dupe(u8, "Location") catch unreachable,
        .value = std.testing.allocator.dupe(u8, location) catch unreachable,
    };
    return answer;
}

test "HTTP fetch step 6 manual, a navigation: the redirect response itself is handed over, and the next manual redirect runs the next hop" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .navigate;
    request.destination = .iframe;
    request.redirect_mode = .manual;
    const job = try FetchJob.create(allocator, request, false, .{ .follows_manual_redirects = true });
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    try std.testing.expect(try job.resumeNetwork(testRedirect(302, "/y")) == .done);
    {
        var hop = job.takeResult();
        defer hop.deinit();
        // Not an opaque-redirect: the response, which HTML reads.
        try std.testing.expectEqual(@as(u16, 302), hop.response.status);
        try std.testing.expect(hop.response.response_type != .opaqueredirect);
    }
    try std.testing.expectEqualStrings("http://a.test/y", job.nextManualRedirectUrl().?);
    // Process the next manual redirect: the next hop's request goes out.
    try std.testing.expect(try job.processNextManualRedirect() == .network);
    try std.testing.expectEqualStrings("http://a.test/y", request.currentUrl());
    try std.testing.expectEqual(@as(u32, 1), request.redirect_count);
    try std.testing.expect(try job.resumeNetwork(testAnswer(200)) == .done);
    try std.testing.expect(job.nextManualRedirectUrl() == null);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    try std.testing.expectEqual(@as(usize, 2), result.response.url_list.items.len);
}

test "HTTP fetch step 6 manual, not a navigation: an opaque-redirect, with no next manual redirect" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .same_origin;
    request.redirect_mode = .manual;
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    try std.testing.expect(try job.resumeNetwork(testRedirect(302, "/y")) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(internal_response.ResponseType.opaqueredirect, result.response.response_type);
    try std.testing.expect(!job.hasNextManualRedirect());
}

test "a navigation's manual redirect with no Location is the response, with nothing to follow" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .navigate;
    request.destination = .iframe;
    request.redirect_mode = .manual;
    const job = try FetchJob.create(allocator, request, false, .{ .follows_manual_redirects = true });
    defer job.destroy();
    _ = try job.start();
    try std.testing.expect(try job.resumeNetwork(testAnswer(302)) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(u16, 302), result.response.status);
    try std.testing.expect(!job.hasNextManualRedirect());
}

test "an uncontrolled navigation's redirect chain followed by hand ends where following it ends: final URL, URL list, redirect count, timing" {
    const allocator = std.testing.allocator;
    var finals: [2]struct { url: [64]u8 = undefined, url_len: usize = 0, hops: usize = 0, redirects: u32 = 0, redirect_end: bool = false } = .{ .{}, .{} };
    for ([_]internal_request.RedirectMode{ .follow, .manual }, 0..) |mode, i| {
        const request = try InternalRequest.init(allocator, "http://a.test/one");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.mode = .navigate;
        request.destination = .iframe;
        request.redirect_mode = mode;
        const job = try FetchJob.create(allocator, request, false, .{ .follows_manual_redirects = true });
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        var step = try job.resumeNetwork(testRedirect(302, "http://b.test/two"));
        if (mode == .manual) {
            try std.testing.expect(step == .done);
            var hop = job.takeResult();
            hop.deinit();
            step = try job.processNextManualRedirect();
        }
        try std.testing.expect(step == .network);
        step = try job.resumeNetwork(testRedirect(301, "/three"));
        if (mode == .manual) {
            try std.testing.expect(step == .done);
            var hop = job.takeResult();
            hop.deinit();
            step = try job.processNextManualRedirect();
        }
        try std.testing.expect(step == .network);
        try std.testing.expect(try job.resumeNetwork(testAnswer(200)) == .done);
        var result = job.takeResult();
        defer result.deinit();
        const final_url = result.response.url().?;
        @memcpy(finals[i].url[0..final_url.len], final_url);
        finals[i].url_len = final_url.len;
        finals[i].hops = result.response.url_list.items.len;
        finals[i].redirects = request.redirect_count;
        finals[i].redirect_end = result.timing_info.redirect_end_time > 0;
    }
    try std.testing.expectEqualStrings(finals[0].url[0..finals[0].url_len], finals[1].url[0..finals[1].url_len]);
    try std.testing.expectEqualStrings("http://b.test/three", finals[1].url[0..finals[1].url_len]);
    try std.testing.expectEqual(finals[0].hops, finals[1].hops);
    try std.testing.expectEqual(@as(usize, 3), finals[1].hops);
    try std.testing.expectEqual(finals[0].redirects, finals[1].redirects);
    try std.testing.expectEqual(finals[0].redirect_end, finals[1].redirect_end);
}

test "a service worker sees every hop of a navigation followed by hand; its own redirect is a hop too" {
    const allocator = std.testing.allocator;
    var workers: TestServiceWorkers = .{};
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .navigate;
    request.destination = .iframe;
    request.redirect_mode = .manual;
    request.service_worker = workers.route();
    const job = try FetchJob.create(allocator, request, false, .{ .follows_manual_redirects = true });
    defer job.destroy();
    const first = try job.start();
    try std.testing.expect(first == .service_worker);
    // The worker answers with Response.redirect(): handed over as it is.
    const redirect = try testServiceWorkerResponse(302);
    try redirect.header_list.append("Location", "http://a.test/y");
    workers.answer(.{ .response = .{ .response = redirect } });
    const answer = first.service_worker.take().?;
    try std.testing.expect(try job.resumeServiceWorker(.{ .response = answer.response.response }) == .done);
    {
        var hop = job.takeResult();
        defer hop.deinit();
        try std.testing.expectEqual(@as(u16, 302), hop.response.status);
    }
    // The next hop asks the worker again; it falls back; the network's 302
    // is a hop of its own, which the worker sees in turn.
    const second = try job.processNextManualRedirect();
    try std.testing.expect(second == .service_worker);
    try std.testing.expectEqual(@as(u32, 2), workers.asked);
    workers.answer(.fallback);
    _ = second.service_worker.take().?;
    try std.testing.expect(try job.resumeServiceWorker(.fallback) == .network);
    try std.testing.expectEqual(internal_request.ServiceWorkersMode.all, request.service_workers_mode);
    try std.testing.expect(try job.resumeNetwork(testRedirect(302, "http://a.test/z")) == .done);
    {
        var hop = job.takeResult();
        defer hop.deinit();
    }
    const third = try job.processNextManualRedirect();
    try std.testing.expect(third == .service_worker);
    try std.testing.expectEqual(@as(u32, 3), workers.asked);
    try std.testing.expectEqualStrings("http://a.test/z", request.currentUrl());
    workers.answer(.{ .response = .{ .response = try testServiceWorkerResponse(200) } });
    const final = third.service_worker.take().?;
    try std.testing.expect(try job.resumeServiceWorker(.{ .response = final.response.response }) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(@as(u16, 200), result.response.status);
}

test "a hop main fetch blocks when the fetch follows it (mixed content) is blocked the same when the navigation follows it by hand" {
    const allocator = std.testing.allocator;
    for ([_]internal_request.RedirectMode{ .follow, .manual }) |mode| {
        const request = try InternalRequest.init(allocator, "https://a.test/x");
        defer request.deinit();
        try request.setOrigin("https://a.test");
        request.mode = .navigate;
        request.destination = .iframe;
        request.redirect_mode = mode;
        request.prohibits_mixed_security_contexts = true;
        const job = try FetchJob.create(allocator, request, false, .{ .follows_manual_redirects = true });
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        var step = try job.resumeNetwork(testRedirect(302, "http://b.test/y"));
        if (mode == .manual) {
            try std.testing.expect(step == .done);
            var hop = job.takeResult();
            hop.deinit();
            step = try job.processNextManualRedirect();
        }
        // Main fetch step 4's mixed content check, for the next hop: no
        // request goes out, a network error is the answer.
        try std.testing.expect(step == .done);
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(internal_response.ResponseType.@"error", result.response.response_type);
    }
}

test "a navigate request whose client follows no manual redirects (a navigation preload's) gets an opaque-redirect" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .navigate;
    request.destination = .iframe;
    request.redirect_mode = .manual;
    const job = try FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    try std.testing.expect(try job.resumeNetwork(testRedirect(302, "/y")) == .done);
    try std.testing.expect(!job.hasNextManualRedirect());
    var result = job.takeResult();
    defer result.deinit();
    try std.testing.expectEqual(internal_response.ResponseType.opaqueredirect, result.response.response_type);
}
