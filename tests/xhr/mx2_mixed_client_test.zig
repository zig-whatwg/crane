//! XHR send() step 6 keeps the relevant settings object's restriction.
const std = @import("std");
const xhr = @import("xhr");
const fetch = @import("fetch");

test "XHR client capture preserves and replaces the mixed-content restriction before dispatch" {
    const allocator = std.testing.allocator;
    var state = xhr.XMLHttpRequestState.init(allocator);
    defer state.deinit();
    try xhr.open.open(&state, "GET", "http://example.test/resource", true, null, null, null, false);

    // Reusing the state must also clear a previous restriction. The value
    // is captured, not recomputed from an origin (data workers are opaque).
    for ([_]bool{ true, false, true }) |restricted| {
        var client: fetch.internal.RequestClient = .{
            .origin = "null",
            .prohibits_mixed_security_contexts = restricted,
        };
        try state.setClient(client);
        client.prohibits_mixed_security_contexts = !restricted;
        try std.testing.expectEqual(restricted, state.client.prohibits_mixed_security_contexts);
        const request = try xhr.send.createRequest(allocator, &state, null);
        defer request.deinit();
        try std.testing.expectEqual(restricted, request.prohibits_mixed_security_contexts);

        const controller = try fetch.internal.FetchController.init(allocator);
        defer controller.deinit();
        var timing = fetch.internal.FetchTimingInfo.init(allocator);
        defer timing.deinit();
        const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
        defer params.deinit();
        const started = try fetch.algorithms.main_fetch.mainFetchStart(allocator, params, false);
        switch (started) {
            .response => |response| {
                defer response.deinit();
                try std.testing.expect(restricted);
                try std.testing.expectEqual(.@"error", response.response_type);
            },
            .http_fetch => try std.testing.expect(!restricted),
            else => return error.TestUnexpectedResult,
        }
    }
}
