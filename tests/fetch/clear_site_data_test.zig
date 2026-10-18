//! Clear Site Data (https://w3c.github.io/webappsec-clear-site-data/): the
//! `Clear-Site-Data` response header as fetch parses it (4.1) and what
//! "clear site data for response" (4.2) hands the request's Browser, and the
//! Fetch Integration step (3.2) in HTTP-network fetch.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const csd = fetch.algorithms.clear_site_data;
const HeaderList = fetch.HeaderList;
const Types = csd.Types;

fn parse(values: []const []const u8) !Types {
    var headers = HeaderList.init(testing.allocator);
    defer headers.deinit();
    for (values) |value| try headers.append("Clear-Site-Data", value);
    return csd.parseHeader(&headers);
}

test "4.1: each type, with clientHints for cache and cookies, and the wildcard" {
    try testing.expectEqual(Types{ .storage = true }, try parse(&.{"\"storage\""}));
    try testing.expectEqual(Types{ .cache = true, .client_hints = true }, try parse(&.{"\"cache\""}));
    try testing.expectEqual(Types{ .cookies = true, .client_hints = true }, try parse(&.{"\"cookies\""}));
    try testing.expectEqual(Types{ .execution_contexts = true }, try parse(&.{"\"executionContexts\""}));
    try testing.expectEqual(Types{ .client_hints = true }, try parse(&.{"\"clientHints\""}));
    try testing.expectEqual(
        Types{ .cache = true, .cookies = true, .storage = true, .execution_contexts = true, .client_hints = true },
        try parse(&.{"\"*\""}),
    );
    try testing.expectEqual(Types{ .storage = true, .cookies = true, .client_hints = true }, try parse(&.{"\"storage\", \"cookies\""}));
}

test "4.1, as the browsers parse: OWS and empty elements are skipped, unknown and malformed entries ignored" {
    // Whitespace around an element, and empty elements (#rule).
    try testing.expectEqual(Types{ .storage = true }, try parse(&.{" \t\"storage\" ,, "}));
    // An unknown type is ignored (4.1: "User agents MUST ignore unknown
    // types"); so is a malformed entry beside a known one - Chrome, Firefox
    // and Safari match each comma-separated entry on its own.
    try testing.expectEqual(Types{ .storage = true }, try parse(&.{"\"foo\", storage, \"storage\""}));
    // Exact, case-sensitive, quoted.
    try testing.expectEqual(Types{}, try parse(&.{"\"Storage\""}));
    try testing.expectEqual(Types{}, try parse(&.{"storage"}));
    try testing.expectEqual(Types{}, try parse(&.{"\"storage"}));
    // More than one header line: their values combine.
    try testing.expectEqual(Types{ .storage = true, .cache = true, .client_hints = true }, try parse(&.{ "\"storage\"", "\"cache\"" }));
    // No header.
    try testing.expectEqual(Types{}, try parse(&.{}));
}

/// A Browser's clearer that records what it was asked.
const Recording = struct {
    calls: u32 = 0,
    origin: [64]u8 = undefined,
    origin_len: usize = 0,
    types: Types = .{},

    fn clearer(self: *Recording) csd.Clearer {
        return .{ .context = self, .clear = clear };
    }

    fn clear(context: *anyopaque, origin: []const u8, types: Types) void {
        const self: *Recording = @ptrCast(@alignCast(context));
        self.calls += 1;
        @memcpy(self.origin[0..origin.len], origin);
        self.origin_len = origin.len;
        self.types = types;
    }

    fn originSeen(self: *const Recording) []const u8 {
        return self.origin[0..self.origin_len];
    }
};

fn clearFor(recording: *Recording, url: []const u8, value: []const u8) !void {
    var headers = HeaderList.init(testing.allocator);
    defer headers.deinit();
    try headers.append("Clear-Site-Data", value);
    try csd.clearSiteDataForResponse(testing.allocator, recording.clearer(), url, &headers);
}

test "4.2: the response URL's origin and the parsed types reach the Browser" {
    var recording: Recording = .{};
    try clearFor(&recording, "https://example.com:443/logout?x=1", "\"storage\"");
    try testing.expectEqual(@as(u32, 1), recording.calls);
    try testing.expectEqualStrings("https://example.com", recording.originSeen());
    try testing.expectEqual(Types{ .storage = true }, recording.types);
}

test "4.2 step 1: only an a priori authenticated URL clears; no recognized type clears nothing" {
    var recording: Recording = .{};
    // Not a priori authenticated: http on a public host.
    try clearFor(&recording, "http://example.com/logout", "\"storage\"");
    try testing.expectEqual(@as(u32, 0), recording.calls);
    // A potentially trustworthy origin is: localhost.
    try clearFor(&recording, "http://localhost:8000/logout", "\"storage\"");
    try testing.expectEqual(@as(u32, 1), recording.calls);
    try testing.expectEqualStrings("http://localhost:8000", recording.originSeen());
    // Nothing recognized: nothing to clear (Chrome: "No recognized types
    // specified").
    try clearFor(&recording, "https://example.com/", "\"unknown\"");
    try testing.expectEqual(@as(u32, 1), recording.calls);
}

fn networkAnswer(headers: []fetch.NetworkResponse.Header) fetch.NetworkResponse {
    return .{
        .allocator = testing.allocator,
        .status = 200,
        .http_version = .http_1_1,
        .headers = headers,
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

test "3.2: HTTP-network fetch clears for a response with the header when includeCredentials is true" {
    const allocator = testing.allocator;
    var network = fetch.network.NetworkContext.init(allocator);
    defer network.deinit();
    var recording: Recording = .{};
    network.site_data = recording.clearer();

    const request = try fetch.internal.InternalRequest.init(allocator, "https://example.com/clear");
    defer request.deinit();
    request.network = &network;
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    var headers = [_]fetch.NetworkResponse.Header{.{ .name = "Clear-Site-Data", .value = "\"storage\"" }};
    const answer = networkAnswer(&headers);

    // The credentials flag unset: the header is not acted on (3.2 step 15,
    // "If credentials flag is set").
    request.credentials_mode = .omit;
    const ignored = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 0, null);
    ignored.deinit();
    try testing.expectEqual(@as(u32, 0), recording.calls);

    request.credentials_mode = .same_origin;
    const cleared = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 0, null);
    cleared.deinit();
    try testing.expectEqual(@as(u32, 1), recording.calls);
    try testing.expectEqualStrings("https://example.com", recording.originSeen());
    try testing.expectEqual(Types{ .storage = true }, recording.types);
}
