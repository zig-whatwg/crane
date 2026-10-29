//! Lane coi1: HTTP fetch step 5 (the cross-origin resource policy check on
//! an opaque response) and HTTP-network-or-cache fetch step 8.4
//! ("Cross-Origin-Embedder-Policy allows credentials"), with the client's
//! embedder policy read from the request's policy container clone.

const std = @import("std");
const fetch = @import("fetch");
const internal = fetch.internal;
const http_fetch = fetch.algorithms.http_fetch;

const testing = std.testing;

const Setup = struct {
    request: *internal.InternalRequest,
    controller: *internal.FetchController,
    timing: internal.FetchTimingInfo,
    params: *internal.FetchParams,

    fn init(self: *Setup, url: []const u8, coep: ?[]const u8) !void {
        const a = testing.allocator;
        self.request = try internal.InternalRequest.init(a, url);
        errdefer self.request.deinit();
        try self.request.setOrigin("https://a.test");
        self.request.mode = .no_cors;
        self.request.response_tainting = .@"opaque";
        if (coep) |value| {
            self.request.setPolicyContainer(try internal.PolicyContainer.fromResponseHeaders(a, .{
                .url = "https://a.test/",
                .coep = value,
                .environment_secure = true,
            }));
        }
        self.controller = try internal.FetchController.init(a);
        self.timing = internal.FetchTimingInfo.init(a);
        self.params = try internal.FetchParams.init(a, self.request, self.controller, &self.timing);
    }

    fn deinit(self: *Setup) void {
        self.params.deinit();
        self.timing.deinit();
        self.controller.deinit();
        self.request.deinit();
    }

    /// Run step 5 over a 200 from `url` with `corp`: whether it came back as
    /// the response (true) or a network error (false).
    fn passes(self: *Setup, url: []const u8, corp: ?[]const u8, includes_credentials: bool) !bool {
        const a = testing.allocator;
        const response = try internal.InternalResponse.init(a);
        response.status = 200;
        response.request_includes_credentials = includes_credentials;
        try response.addUrl(url);
        if (corp) |value| try response.header_list.append("Cross-Origin-Resource-Policy", value);
        const next = try http_fetch.httpFetchFinish(a, self.params, .{}, response);
        const got = next.response;
        defer got.deinit();
        return got == response;
    }
};

test "HTTP fetch step 5: CORP same-origin blocks an opaque cross-origin response, with or without COEP" {
    var setup: Setup = undefined;
    try setup.init("https://b.test/x", null);
    defer setup.deinit();
    try testing.expect(!try setup.passes("https://b.test/x", "same-origin", true));
    try testing.expect(try setup.passes("https://b.test/x", "cross-origin", true));
    try testing.expect(try setup.passes("https://b.test/x", null, true));
    try testing.expect(!try setup.passes("https://b.test/x", "same-site", true));
    try testing.expect(try setup.passes("https://www.a.test/x", "same-site", true));
    // A basic (not opaque) response is not checked.
    setup.request.response_tainting = .basic;
    try testing.expect(try setup.passes("https://b.test/x", "same-origin", true));
}

test "HTTP fetch step 5: require-corp blocks an opaque response without CORP" {
    var setup: Setup = undefined;
    try setup.init("https://b.test/x", "require-corp");
    defer setup.deinit();
    try testing.expect(!try setup.passes("https://b.test/x", null, true));
    try testing.expect(try setup.passes("https://b.test/x", "cross-origin", true));
    try testing.expect(try setup.passes("https://a.test/x", null, true));
}

test "HTTP fetch step 5: credentialless blocks only a credentialed opaque response without CORP" {
    var setup: Setup = undefined;
    try setup.init("https://b.test/x", "credentialless");
    defer setup.deinit();
    try testing.expect(try setup.passes("https://b.test/x", null, false));
    try testing.expect(!try setup.passes("https://b.test/x", null, true));
}

test "includeCredentials: a credentialless client omits a cross-origin no-cors request's credentials" {
    var setup: Setup = undefined;
    try setup.init("https://b.test/x", "credentialless");
    defer setup.deinit();
    setup.request.credentials_mode = .include;
    try testing.expect(!http_fetch.httpNetworkFetchUsesCookies(setup.request));
    // Same origin: credentials go.
    var same: Setup = undefined;
    try same.init("https://a.test/x", "credentialless");
    defer same.deinit();
    same.request.credentials_mode = .include;
    try testing.expect(http_fetch.httpNetworkFetchUsesCookies(same.request));
    // A cors request is not restricted.
    setup.request.mode = .cors;
    try testing.expect(http_fetch.httpNetworkFetchUsesCookies(setup.request));
    // require-corp does not restrict credentials.
    var corp: Setup = undefined;
    try corp.init("https://b.test/x", "require-corp");
    defer corp.deinit();
    corp.request.credentials_mode = .include;
    try testing.expect(http_fetch.httpNetworkFetchUsesCookies(corp.request));
}
