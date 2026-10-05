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
    /// response's allocator.
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

    /// What the job needs next.
    pub const Step = union(enum) {
        /// HTTP-network fetch's request, for the network to answer. Hand the
        /// answer to `resumeNetwork`. Borrowed from the job until then.
        network: NetworkStep,
        /// Fetch has its response; `takeResult` hands it over.
        done,
    };

    /// Cookies are not the network's business: HTTP-network-or-cache fetch
    /// has put them in `request` already, and HTTP-network fetch stores the
    /// answer's (algorithms/cookies.zig).
    pub const NetworkStep = struct {
        request: *const NetworkRequest,
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
        if (self.network_request) |request| http_fetch.freeNetworkRequest(allocator, request);
        if (self.response) |response| response.deinit();
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

        // Set options
        self.params.cross_origin_isolated_capability = self.options.cross_origin_isolated_capability;
        if (self.options.process_response) |callback| {
            self.params.process_response = callback;
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
            else => return self.httpFetchFailed(http_fetch.HttpFetchError.NetworkError),
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
        const timing_info = self.timing_info;
        self.timing_info = FetchTimingInfo.init(self.allocator);
        // Out of memory, the referrer is left out (null): the document gets
        // the empty string, as for no referrer.
        const referrer: ?[]u8 = switch (self.request.referrer) {
            .url => |url| response.allocator.dupe(u8, url) catch null,
            .no_referrer, .client => null,
        };
        return .{ .response = response, .timing_info = timing_info, .referrer = referrer };
    }

    /// Main fetch, at the current depth, as far as it can go.
    fn mainFetch(self: *FetchJob) FetchError!Step {
        const allocator = self.allocator;
        const begun = main_fetch.mainFetchStart(allocator, self.params, self.depth > 0) catch {
            return FetchError.OutOfMemory;
        };
        switch (begun) {
            .response => |response| return self.mainFetchFetched(response),
            .http_fetch => return self.httpNetworkOrCacheFetch(),
            .http_fetch_with_cors_preflight => {},
        }

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
        const network_start = http_fetch.httpNetworkOrCacheFetchStart(allocator, self.params, .{}) catch |err| {
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
        const response = http_fetch.httpNetworkOrCacheFetchFinish(self.allocator, self.request, network_response) catch |err| {
            return self.httpFetchFailed(err);
        };
        const next = http_fetch.httpFetchFinish(self.allocator, self.params, .{}, response) catch |err| {
            return self.httpFetchFailed(err);
        };
        switch (next) {
            .response => |r| return self.mainFetchFetched(r),
            .recursive_main_fetch => {
                // HTTP-redirect fetch steps 20-22: main fetch again, one deeper.
                self.depth += 1;
                return self.mainFetch();
            },
        }
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
        return self.finish(main_fetch.mainFetchFinish(self.params, false, r));
    }

    /// Fetch's steps after main fetch returned `response`.
    fn finish(self: *FetchJob, response: *InternalResponse) Step {
        // Record end time
        self.timing_info.end_time = http_fetch.getCurrentTimeMs();

        // Fetch response handover step 4: the report timing steps.
        self.reportTiming(response);

        // Call process response callback if set
        if (self.options.process_response) |callback| {
            callback(response);
        }

        self.response = response;
        return .done;
    }

    /// Fetch "fetch response handover" steps 4.2 and 4.3 for `response`: the
    /// report timing steps, run given the request's client's global - the
    /// request's timing reporter, which makes its Resource Timing entry - for
    /// a request with an initiator type. They run here, when fetch hands the
    /// response over: the end time is now, and a body still streaming in is
    /// not waited for (its sizes are not known yet).
    ///
    /// Spec: https://fetch.spec.whatwg.org/#fetch-finale
    fn reportTiming(self: *FetchJob, response: *const InternalResponse) void {
        const request = self.request;
        // 4.3. Only a request with an initiator type, whose client's global
        // hears it.
        const initiator_type = request.initiator_type orelse return;
        const reporter = request.timing_reporter orelse return;
        // 4.2.1. If request's URL's scheme is not an HTTP(S) scheme, return.
        const url = request.getUrl();
        if (!std.mem.startsWith(u8, url, "http:") and !std.mem.startsWith(u8, url, "https:")) return;
        // 4.2.2. The end time (now, set by `finish`) is the reporter's to make
        // relative to its global.
        // 4.2.3-4.2.4. cacheState and bodyInfo.
        var cache_state: []const u8 = switch (response.cache_state) {
            .empty => "",
            .local => "local",
            .validated => "validated",
        };
        var body_info = response.body_info;
        // 4.2.5. A response whose timing allow passed flag is not set (a
        // network error too) is reported with an opaque timing info and no
        // cache state.
        var opaque_timing: ?FetchTimingInfo = null;
        defer if (opaque_timing) |*o| o.deinit();
        var timing_info: *const FetchTimingInfo = &self.timing_info;
        if (!response.timing_allow_passed) {
            opaque_timing = @import("../internal/fetch_timing.zig").createOpaqueTimingInfo(self.allocator, &self.timing_info);
            timing_info = &opaque_timing.?;
            cache_state = "";
            // Nor its sizes (Resource Timing 3.5.1: transferSize is TAO-
            // protected; encodedBodySize, decodedBodySize and contentType
            // with it).
            body_info = .{};
        }
        // A CORS-cross-origin response (opaque tainting) exposes no body
        // sizes, content type or encoding (Resource Timing 3.5.1).
        if (request.response_tainting == .@"opaque") body_info = .{};
        // 4.2.6-4.2.7. responseStatus and the minimized content type, unless
        // this is a navigation redirected across origins.
        var response_status: u16 = 0;
        var content_type: ?[]const u8 = null;
        defer if (content_type) |c| self.allocator.free(c);
        if (request.mode != .navigate or response.redirect_taint == .same_origin) {
            response_status = response.status;
            if (request.response_tainting != .@"opaque") {
                if (@import("../internal/mime.zig").extractMimeType(self.allocator, &response.header_list) catch null) |mime_type| {
                    var parsed = mime_type;
                    defer parsed.deinit();
                    content_type = @import("mimesniff").minimizeSupportedMimeType(self.allocator, &parsed) catch null;
                    if (content_type) |c| body_info.content_type = c;
                }
            }
        }
        // 4.2.8. Mark resource timing (the reporter's global does).
        reporter.report(reporter.context, &.{
            .timing_info = timing_info,
            .url = url,
            .initiator_type = initiator_type,
            .cache_state = cache_state,
            .body_info = body_info,
            .response_status = response_status,
            .timing_allow_passed = response.timing_allow_passed,
        });
    }
};

fn networkError(allocator: Allocator) FetchError!*InternalResponse {
    return internal_response.networkError(allocator) catch FetchError.OutOfMemory;
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
        const job = try FetchJob.create(allocator, request, false, .{});
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
        const job = try FetchJob.create(allocator, request, false, .{});
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
        const job = try FetchJob.create(allocator, request, false, .{});
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
        const job = try FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        _ = try job.start();
        _ = try job.resumeNetwork(testAnswer(200));
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expect(result.referrer == null);
    }
}
