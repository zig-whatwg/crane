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

    pub fn deinit(self: *FetchResult) void {
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

    pub const NetworkStep = struct {
        request: *const NetworkRequest,
        /// See `http_fetch.httpNetworkFetchUsesCookies`.
        cookies: bool,
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
        const allocator = self.allocator;

        // Record start time
        self.timing_info.start_time = http_fetch.getCurrentTimeMs();

        // Set options
        self.params.cross_origin_isolated_capability = self.options.cross_origin_isolated_capability;
        if (self.options.process_response) |callback| {
            self.params.process_response = callback;
        }

        // Step 13: Dispatch based on URL scheme
        const url_str = self.request.currentUrl();
        const url_scheme = extractScheme(url_str);

        if (scheme_fetch.isLocalScheme(url_scheme)) {
            // Handle local schemes (about, blob, data) directly
            const result = scheme_fetch.schemeFetch(allocator, url_scheme, url_str) catch {
                return FetchError.OutOfMemory;
            };
            return self.finish(switch (result) {
                .response => |r| r,
                .network_error => try networkError(allocator),
            });
        }
        if (scheme_fetch.isHttpScheme(url_scheme)) {
            // HTTP(S) requests go through main fetch -> HTTP fetch
            return self.mainFetch();
        }
        // Unsupported scheme
        return self.finish(try networkError(allocator));
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
        return .{ .response = response, .timing_info = timing_info };
    }

    /// Main fetch, at the current depth, as far as it can go.
    fn mainFetch(self: *FetchJob) FetchError!Step {
        const allocator = self.allocator;
        const begun = main_fetch.mainFetchStart(allocator, self.params, self.depth > 0) catch {
            return FetchError.OutOfMemory;
        };
        switch (begun) {
            .response => |response| return self.mainFetchFetched(response),
            .http_fetch => {},
        }

        // HTTP fetch, step 4: HTTP-network-or-cache fetch. Main fetch passes
        // HTTP fetch no options.
        const network_start = http_fetch.httpNetworkOrCacheFetchStart(allocator, self.params, .{}) catch |err| {
            return self.httpFetchFailed(err);
        };
        switch (network_start) {
            .response => |response| return self.httpNetworkOrCacheFetchReturned(response),
            .network => |request| {
                self.network_request = request;
                self.network_start_time = http_fetch.getCurrentTimeMs();
                return .{ .network = .{
                    .request = &self.network_request.?,
                    .cookies = http_fetch.httpNetworkFetchUsesCookies(self.request),
                } };
            },
        }
    }

    /// HTTP fetch, once HTTP-network-or-cache fetch has returned `response`.
    fn httpNetworkOrCacheFetchReturned(self: *FetchJob, response: *InternalResponse) FetchError!Step {
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

        // Call process response callback if set
        if (self.options.process_response) |callback| {
            callback(response);
        }

        self.response = response;
        return .done;
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
