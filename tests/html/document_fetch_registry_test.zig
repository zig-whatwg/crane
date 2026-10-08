const std = @import("std");
const AgentHost = @import("html").agent_host.AgentHost;

test "document resource registries belong to each agent and return their storage" {
    if (comptime !@hasField(AgentHost, "embedded_contents") or !@hasField(AgentHost, "hyperlink_pings")) {
        try std.testing.expect(false);
        return;
    } else {
        var first = AgentHost.init(std.testing.allocator);
        defer first.deinit();
        var second = AgentHost.init(std.testing.allocator);
        defer second.deinit();
        var pending: u8 = 0;
        var realm: u8 = 0;
        try first.embedded_contents.add(&pending, &realm);
        try first.embedded_contents.add(&pending, &realm);
        try first.hyperlink_pings.add(&pending, &realm);
        try std.testing.expectEqual(@as(usize, 1), first.embedded_contents.entries.len);
        try std.testing.expectEqual(@as(usize, 1), first.hyperlink_pings.entries.len);
        try std.testing.expectEqual(@as(usize, 0), second.embedded_contents.entries.len);
        try std.testing.expectEqual(@as(usize, 0), second.hyperlink_pings.entries.len);
        first.embedded_contents.remove(&pending);
        first.hyperlink_pings.remove(&pending);
        try std.testing.expectEqual(@as(usize, 0), first.embedded_contents.entries.len);
        try std.testing.expectEqual(@as(usize, 0), first.hyperlink_pings.entries.len);
    }
}
