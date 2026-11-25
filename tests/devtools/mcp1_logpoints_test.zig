//! Lane mcp1, batch 4b item 3a: set_logpoints on script URLs as
//! chrome-devtools-mcp v1.13.0 answers it (src/tools/logpoints.ts over
//! LogpointManager and DevTools' BreakpointManager in its second, "DevTools
//! universe" session). Each answer below is Chrome for Testing 157's,
//! recorded by the differential suite (tools/mcp_diff case "logpoints:
//! script URLs", chat2, 2026-11-25) on the same two files, served here:
//! - a location binds when V8 resolves it, and keeps the line and column
//!   asked for (a column 0 when none was given: DevTools' raw location);
//! - an inline script's location is the document's;
//! - output is console.log's, and an expression that throws is V8's
//!   exception with no text (V8Debugger::BreakpointConditionEvaluated);
//! - the set replaces the last one, survives a reload, and a location no
//!   script contains is reported after the logpoints that were applied.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const LoopbackListener = @import("loopback_listener").LoopbackListener;

/// tools/mcp_diff/fixtures/logpoints.js: line numbers matter.
const script =
    \\// Logpoint fixture: line numbers matter (tools/mcp_diff cases "logpoints: ...").
    \\function add(x, y) {
    \\  const sum = x + y;
    \\  return sum;
    \\}
    \\
    \\// a comment line
    \\window.run = n => {
    \\  const doubled = add(n, n);
    \\  return doubled;
    \\};
    \\
;

/// tools/mcp_diff/fixtures/logpoints.html.
const page =
    \\<!doctype html>
    \\<title>Logpoints</title>
    \\<script src="logpoints.js"></script>
    \\<script>
    \\  window.inline = n => {
    \\    const tripled = n * 3;
    \\    return tripled;
    \\  };
    \\</script>
    \\
;

/// tools/mcp_diff/fixtures/logpoints-dup.html: two scripts of one file name.
const duplicates_page =
    \\<!doctype html>
    \\<title>Duplicates</title>
    \\<script src="lp-a/same.js"></script>
    \\<script src="lp-b/same.js"></script>
    \\
;

const Site = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    fn start(self: *Site) !void {
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *Site) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
    }

    fn serve(self: *Site) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Site, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        answer(stream) catch {};
    }

    fn answer(stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next();
        const path = parts.next() orelse return;
        const body: []const u8, const content_type: []const u8 = if (std.mem.eql(u8, path, "/logpoints.html"))
            .{ page, "text/html" }
        else if (std.mem.eql(u8, path, "/logpoints.js"))
            .{ script, "text/javascript" }
        else if (std.mem.eql(u8, path, "/logpoints-dup.html"))
            .{ duplicates_page, "text/html" }
        else if (std.mem.eql(u8, path, "/lp-a/same.js"))
            .{ "window.a = () => 1;\n", "text/javascript" }
        else if (std.mem.eql(u8, path, "/lp-b/same.js"))
            .{ "window.b = () => 2;\n", "text/javascript" }
        else if (std.mem.eql(u8, path, "/title.html"))
            .{ "<!doctype html><title>Fixture title</title><p>hello</p>\n", "text/html" }
        else
            .{ "", "text/plain" };
        var output: [1024]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const status = if (body.len == 0) "404 Not Found" else "200 OK";
        try writer.interface.print("HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ status, content_type, body.len });
        try writer.interface.writeAll(body);
        try writer.interface.flush();
    }
};

/// One call and Chrome's answer to it ("{fixture}": the site's origin).
const Step = struct {
    tool: []const u8,
    args: []const u8,
    answer: []const u8,
    is_error: bool = false,
};

const logged = "Logged output appears in list_console_messages once a line executes; objects show as [object Object] there, get_console_message shows them as JSON.";

/// tools/mcp_diff case "logpoints: script URLs": Chrome 157's answers.
const chrome_157 = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/logpoints.html\"}", .answer = "Successfully navigated to {fixture}/logpoints.html.\n## Pages\n1: Logpoints ({fixture}/logpoints.html) [selected]" },
    .{
        .tool = "set_logpoints",
        .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 'sum', sum\",\"logpoints.html:7 'tripled', tripled\",\"logpoints.js:6 'blank'\",\"logpoints.js:3:9 'column', x\"]}",
        .answer = "4 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `'sum', sum` [bound]\n- {fixture}/logpoints.html:7:1 logging `'tripled', tripled` [bound]\n- {fixture}/logpoints.js:6:1 logging `'blank'` [bound]\n- {fixture}/logpoints.js:3:9 logging `'column', x` [bound]\n" ++ logged,
    },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => [window.run(2), window.inline(3)]\"}", .answer = "Script ran on page and returned:\n```json\n[4,9]\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-3 of 3 (Page 1 of 1).\nmsgid=1 [log] column 2 (2 args)\nmsgid=2 [log] sum 4 (2 args)\nmsgid=3 [log] tripled 9 (2 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 'sum again', sum\"]}", .answer = "1 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `'sum again', sum` [bound]\n" ++ logged },
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"type\":\"reload\"}", .answer = "Successfully reloaded the page.\n## Pages\n1: Logpoints ({fixture}/logpoints.html) [selected]" },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => window.run(5)\"}", .answer = "Script ran on page and returned:\n```json\n10\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-1 of 1 (Page 1 of 1).\nmsgid=4 [log] sum again 10 (2 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"missing.js:1 x\"]}", .is_error = true, .answer = "Error: No parsed script or original source file matches \"missing.js\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 sum)\"]}", .is_error = true, .answer = "Error: The logpoint expression `sum)` does not compile: Unexpected token ')'. Provide the expression like arguments to console.log(...)." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js 1\"]}", .is_error = true, .answer = "Error: Invalid logpoint \"logpoints.js 1\". Expected the format <url>:<lineNumber>[:<columnNumber>] <expression>, for example \"src/app.ts:42 'total', cart.total\"." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:0 x\"]}", .is_error = true, .answer = "Error: Invalid logpoint \"logpoints.js:0 x\": line and column numbers are 1-based." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 'kept'\",\"logpoints.js:30 'past the end'\"]}", .is_error = true, .answer = "1 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `'kept'` [bound]\nError: No executable code at {fixture}/logpoints.js:30 (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"logpoints.js:4 (() => { throw new Error('boom') })()\"]}", .answer = "1 logpoint(s) set on the page:\n- {fixture}/logpoints.js:4:1 logging `(() => { throw new Error('boom') })()` [bound]\n" ++ logged },
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => window.run(1)\"}", .answer = "Script ran on page and returned:\n```json\n2\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\nShowing 1-2 of 2 (Page 1 of 1).\nmsgid=4 [log] sum again 10 (2 args)\nmsgid=5 [error]  (0 args)" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[]}", .answer = "No logpoints are set on the page." },
};

/// tools/mcp_diff case "logpoints: lookups, documents, pauses": Chrome
/// 157's answers (chat2, 2026-11-25).
const chrome_157_lookups = [_]Step{
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/logpoints-dup.html\"}", .answer = "Successfully navigated to {fixture}/logpoints-dup.html.\n## Pages\n1: Duplicates ({fixture}/logpoints-dup.html) [selected]" },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"same.js:1 'x'\"]}", .is_error = true, .answer = "Error: \"same.js\" matches multiple sources: {fixture}/lp-a/same.js, {fixture}/lp-b/same.js. Specify a longer path." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"c/same.js:1 'x'\"]}", .is_error = true, .answer = "Error: No parsed script or original source file matches \"c/same.js\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix. Sources with the same file name: {fixture}/lp-a/same.js, {fixture}/lp-b/same.js." },
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"lp-a/same.js:1 'a'\"]}", .answer = "1 logpoint(s) set on the page:\n- {fixture}/lp-a/same.js:1:1 logging `'a'` [bound]\n" ++ logged },
    // The universe skips all pauses: the debugger statement does not stop.
    .{ .tool = "evaluate_script", .args = "{\"pageId\":1,\"function\":\"() => { debugger; return window.a() + window.b(); }\"}", .answer = "Script ran on page and returned:\n```json\n3\n```" },
    .{ .tool = "list_console_messages", .args = "{\"pageId\":1}", .answer = "## Console messages\n<no console messages found>" },
    .{ .tool = "navigate_page", .args = "{\"pageId\":1,\"url\":\"{fixture}/title.html\"}", .answer = "Successfully navigated to {fixture}/title.html.\n## Pages\n1: Fixture title ({fixture}/title.html) [selected]" },
    // A document with no script: found, never bound.
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"title.html:1 'doc'\"]}", .is_error = true, .answer = "No logpoints are set on the page.\nError: No executable code at {fixture}/title.html:1 (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied." },
    // The last page's scripts are gone from the workspace.
    .{ .tool = "set_logpoints", .args = "{\"pageId\":1,\"logpoints\":[\"lp-a/same.js:1 'a'\"]}", .is_error = true, .answer = "Error: No parsed script or original source file matches \"lp-a/same.js\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix." },
};

fn run(steps: []const Step) !void {
    var site: Site = undefined;
    try site.start();
    defer site.stop();
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const origin = try std.fmt.allocPrint(a, "http://127.0.0.1:{d}", .{site.listener.port()});
    for (steps, 1..) |step, call| {
        const args = try std.mem.replaceOwned(u8, a, step.args, "{fixture}", origin);
        const expected = try std.mem.replaceOwned(u8, a, step.answer, "{fixture}", origin);
        const r = h.tool(step.tool, args) catch |err| {
            std.debug.print("call {d} ({s}) failed: {t}\n", .{ call, step.tool, err });
            return err;
        };
        testing.expectEqualStrings(expected, r.text) catch |err| {
            std.debug.print("call {d} ({s})\n", .{ call, step.tool });
            return err;
        };
        try testing.expectEqual(step.is_error, r.is_error);
    }
}

test "set_logpoints: script URLs and an inline script, as Chrome 157's server answers" {
    try run(&chrome_157);
}

test "set_logpoints: an ambiguous suffix, the same-file-name hint, a document with no script, a navigation; no pause" {
    try run(&chrome_157_lookups);
}
