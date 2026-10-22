//! XML 1.0 §4.3.3: document navigation rejects malformed encoded input.
//! XHR document responses use replacement decoding through a separate caller.
const std = @import("std");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");
const http = @import("module1_http_server.zig");

fn expectRejected(comptime source: []const u8) !void {
    const OnThread = struct {
        fn run() !void {
            const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            const encoder = std.base64.standard.Encoder;
            const data = try std.testing.allocator.alloc(u8, encoder.calcSize(source.len));
            defer std.testing.allocator.free(data);
            _ = encoder.encode(data, source);
            const url = try std.fmt.allocPrint(std.testing.allocator, "data:application/xml;base64,{s}", .{data});
            defer std.testing.allocator.free(url);
            try browser.navigate(url, .window);
            try browser.current_context.?.runScript(
                \\if (!document.getElementsByTagName('parsererror').length) throw new Error('malformed XML bytes accepted');
            );
        }
    };
    try helpers.onFreshThread(OnThread.run);
}

test "XML navigation rejects malformed UTF-8" {
    try expectRejected("<r>\xff</r>");
}

test "XML navigation rejects truncated UTF-8" {
    try expectRejected("<r>\xe2\x82</r>");
}

test "XML navigation rejects lone UTF-16 surrogates" {
    try expectRejected("\xff\xfe<\x00r\x00>\x00\x00\xd8<\x00/\x00r\x00>\x00");
}

test "XML navigation rejects invalid Shift_JIS" {
    try expectRejected("<?xml version='1.0' encoding='Shift_JIS'?><r>\x82</r>");
}

fn expectIframeRejected(comptime source: []const u8) !void {
    const OnThread = struct {
        fn run() !void {
            const routes = [_]http.Route{
                .{ .path = "/page.html", .content_type = "text/html", .body =
                \\<!doctype html><body><script>globalThis.xm1Loaded = false;</script>
                \\<iframe id="xm1Frame" src="/bad.xml" onload="xm1Loaded = true"></iframe>
                },
                .{ .path = "/bad.xml", .content_type = "application/xml", .body = source },
            };
            const server = try http.Server.start(std.testing.allocator, &routes);
            defer server.stop();
            var proxy_buffer: [64]u8 = undefined;
            const browser = try browser_mod.Browser.init(std.testing.allocator, .{
                .persist_storage = false,
                .snapshot_path = "",
                .proxy = .{ .manual = .{ .http = try server.proxyUrl(&proxy_buffer), .no_proxy = "" } },
            });
            defer browser.deinit();
            try browser.navigate("http://xm1.test/page.html", .window);
            const context = browser.current_context orelse return error.NoPage;
            for (0..500) |_| {
                const loaded = try context.evaluateScriptToString("xm1Loaded", std.testing.allocator);
                defer std.testing.allocator.free(loaded);
                if (std.mem.eql(u8, loaded, "true")) break;
                _ = try browser.runEventLoopBlocking(10);
            }
            try context.runScript(
                \\if (!xm1Loaded) throw new Error('XML iframe did not load');
                \\const frame = document.getElementById('xm1Frame');
                \\if (!frame.contentDocument) throw new Error('XML iframe document unavailable');
                \\if (!frame.contentDocument.getElementsByTagName('parsererror').length)
                \\  throw new Error('malformed XML iframe bytes accepted');
                \\frame.remove();
            );
        }
    };
    try helpers.onFreshThread(OnThread.run);
}

test "XML iframe navigation rejects malformed UTF-8" {
    try expectIframeRejected("<r>\xff</r>");
}

test "XML iframe navigation rejects truncated UTF-8" {
    try expectIframeRejected("<r>\xe2\x82</r>");
}

test "XML iframe navigation rejects lone UTF-16 surrogates" {
    try expectIframeRejected("\xff\xfe<\x00r\x00>\x00\x00\xd8<\x00/\x00r\x00>\x00");
}

test "XML iframe navigation rejects invalid Shift_JIS" {
    try expectIframeRejected("<?xml version='1.0' encoding='Shift_JIS'?><r>\x82</r>");
}
