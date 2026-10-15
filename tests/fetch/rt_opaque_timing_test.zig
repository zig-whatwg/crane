const std = @import("std");
const fetch = @import("fetch");

test "opaque timing keeps completion and render blocking while clearing network details" {
    const allocator = std.testing.allocator;
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    timing.start_time = 10.125;
    timing.post_redirect_start_time = 20.125;
    timing.redirect_start_time = 10.125;
    timing.redirect_end_time = 20.125;
    timing.final_network_request_start_time = 25.125;
    timing.final_network_response_start_time = 30.125;
    timing.end_time = 50.125;
    timing.render_blocking = true;
    timing.final_connection_timing_info = fetch.internal.ConnectionTimingInfo.forReusedConnection(20.125);
    var opaque_info = fetch.internal.createOpaqueTimingInfo(allocator, &timing);
    defer opaque_info.deinit();
    try std.testing.expectEqual(timing.end_time, opaque_info.end_time);
    try std.testing.expect(opaque_info.render_blocking);
    try std.testing.expectEqual(timing.start_time, opaque_info.start_time);
    try std.testing.expectEqual(timing.start_time, opaque_info.post_redirect_start_time);
    try std.testing.expectEqual(@as(f64, 0), opaque_info.redirect_start_time);
    try std.testing.expectEqual(@as(f64, 0), opaque_info.redirect_end_time);
    try std.testing.expectEqual(@as(f64, 0), opaque_info.final_network_request_start_time);
    try std.testing.expectEqual(@as(f64, 0), opaque_info.final_network_response_start_time);
    try std.testing.expect(opaque_info.final_connection_timing_info == null);
}
