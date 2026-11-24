//! Lane mcp1, batch 2: when a PARSED title reaches its target. A page whose
//! body streams in after its <title> (lane cdpr's /streamed.html: the head
//! and the title in the first chunk, the rest 300 ms later): from the
//! commit on, Target.getTargets names the title before
//! Page.domContentEventFired, as Chrome 157 does - Blink reports a title
//! once its element has its children (HTMLTitleElement's ChildrenChanged /
//! FinishParsingChildren -> Document::UpdateTitle), not at the end of
//! parsing. With the encoding named (/streamed-charset.html) Crane parses
//! the first chunk at once and matches; with none, Crane's parser waits for
//! its meta charset scan, Blink's does not - known red, a queued parser
//! item.
//!
//! COMPARING with Chrome: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port>: it drives that
//! Chrome's browser target instead, and prints what it saw with
//! CRANE_CDP_TRACE_VERBOSE set - the messages from the navigation to a
//! second after the load, with each targetInfoChanged's title.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

fn verbose() bool {
    return std.c.getenv("CRANE_CDP_TRACE_VERBOSE") != null;
}

fn progress(comptime format: []const u8, args: anytype) void {
    if (!verbose()) return;
    std.debug.print("mcp1_title_timing: " ++ format ++ "\n", args);
}

/// The browser target's WebSocket path on `port` (/json/version).
fn browserPath(allocator: Allocator, port: u16) ![]u8 {
    var version = try cdp.httpGet(allocator, port, "/json/version", &.{"Host: 127.0.0.1"});
    defer version.deinit();
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, version.body, .{});
    defer parsed.deinit();
    const ws = parsed.value.object.get("webSocketDebuggerUrl").?.string;
    return allocator.dupe(u8, ws[std.mem.indexOf(u8, ws, "/devtools/").?..]);
}

/// How long before DOMContentLoaded getTargets must name the title for it to
/// count as named while the body streams in (the page's last chunk comes 300
/// ms after its first): a title reported only at the end of parsing comes
/// just before DOMContentLoaded, by however much the threads' timing gives.
const ahead_ms = 100;

const Seen = struct {
    /// Target.getTargets named the title at least `ahead_ms` before
    /// DOMContentLoaded came.
    listed_before_dcl: bool,
    /// A Target.targetInfoChanged named it: before DOMContentLoaded, and
    /// at all up to a second after the load.
    event_before_dcl: bool,
    event_at_all: bool,
};

/// Attach to the page target, navigate it to the streamed page, and poll
/// Target.getTargets from the commit until DOMContentLoaded.
fn titleTiming(allocator: Allocator, client: *cdp.Client, url: []const u8) !Seen {
    var rec = replay.Recorder.init(allocator, client);
    defer rec.deinit();
    _ = try rec.awaitResponse(try rec.send("Target.setDiscoverTargets", "{\"discover\":true}", ""));
    const targets = try rec.result(try rec.send("Target.getTargets", "{}", ""));
    var page_id: ?[]const u8 = null;
    for (targets.object.get("targetInfos").?.array.items) |info| {
        if (std.mem.eql(u8, info.object.get("type").?.string, "page")) page_id = info.object.get("targetId").?.string;
    }
    const target_id = try allocator.dupe(u8, page_id orelse return error.NoPage);
    defer allocator.free(target_id);
    var buffer: [512]u8 = undefined;
    const attached = try rec.result(try rec.send("Target.attachToTarget", try std.fmt.bufPrint(&buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id}), ""));
    const session = try allocator.dupe(u8, attached.object.get("sessionId").?.string);
    defer allocator.free(session);
    _ = try rec.awaitResponse(try rec.send("Page.enable", "{}", session));
    const start = rec.log.items.len;
    _ = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\"}}", .{url}), session);
    _ = try rec.awaitEvent("Page.frameNavigated", session, start, &.{});

    // The title as getTargets lists it, until DOMContentLoaded.
    var listed_at: ?usize = null;
    var listed_time: ?std.Io.Timestamp = null;
    while (rec.eventIndex("Page.domContentEventFired", session, start, &.{}) == null) {
        const id = try rec.send("Target.getTargets", "{}", "");
        const answered = try rec.awaitResponse(id);
        const infos = cdp.at(rec.at(answered), "result.targetInfos") orelse return error.NoResult;
        for (infos.array.items) |info| {
            if (!std.mem.eql(u8, cdp.stringAt(info, "targetId") orelse "", target_id)) continue;
            if (std.mem.eql(u8, cdp.stringAt(info, "title") orelse "", "streamed")) listed_at = answered;
        }
        if (listed_at != null) {
            listed_time = std.Io.Timestamp.now(std.testing.io, .awake);
            break;
        }
        std.Io.sleep(std.testing.io, .fromMilliseconds(10), .awake) catch {};
    }
    const dcl = try rec.awaitEvent("Page.domContentEventFired", session, start, &.{});
    const dcl_time = std.Io.Timestamp.now(std.testing.io, .awake);
    const ahead: i64 = if (listed_time) |t| t.durationTo(dcl_time).toMilliseconds() else -1;
    _ = try rec.awaitEvent("Page.loadEventFired", session, start, &.{});
    // A second more of events (a title event Chrome might send late).
    _ = try rec.awaitResponse(try rec.send("Runtime.evaluate", "{\"expression\":\"new Promise(r => setTimeout(r, 1000))\",\"awaitPromise\":true}", session));
    const titled = rec.eventIndex("Target.targetInfoChanged", "", start, &.{
        .{ .path = "params.targetInfo.targetId", .equals = target_id },
        .{ .path = "params.targetInfo.title", .equals = "streamed" },
    });
    if (verbose()) {
        for (rec.log.items[start..], start..) |m, i| {
            const method = cdp.stringAt(m.value, "method") orelse continue;
            progress("{d}: {s} {s}", .{ i, method, cdp.stringAt(m.value, "params.targetInfo.title") orelse "" });
        }
        progress("getTargets named the title at message {?d}, {d} ms ahead; its targetInfoChanged at {?d}; DOMContentLoaded at {d}", .{ listed_at, ahead, titled, dcl });
    }
    return .{
        .listed_before_dcl = if (listed_at) |at| at < dcl and ahead >= ahead_ms else false,
        .event_before_dcl = if (titled) |at| at < dcl else false,
        .event_at_all = titled != null,
    };
}

/// Which later work this file waits on: a red case pinning what it must
/// achieve passes while it is red and fails when it turns green unannounced
/// (lesson testing-a-red-test-for-an-unlanded-step-asserts-that-it-is-still-red.md).
const landed = struct {
    /// The queued parser item (main, 11:54 PM ET 2026-11-23, not batch 2):
    /// the navigation parser decodes and parses each chunk while the meta
    /// charset scan runs, as Blink's TextResourceDecoder::Decode does,
    /// instead of holding the bytes until the scan concludes
    /// (src/html/scripted_parser.zig receiveBytes, NetworkInput.prescan).
    const network_parser_decodes_while_scanning = false;
};

/// Assert `holds`, or - while `step_landed` is false - that it does not.
fn knownRed(comptime step_landed: bool, holds: bool, what: []const u8) !void {
    if (step_landed) {
        if (!holds) {
            std.debug.print("REGRESSION (its step has landed): {s}\n", .{what});
            return error.PropertyLost;
        }
        return;
    }
    if (holds) {
        std.debug.print("TURNED GREEN (mark its step landed): {s}\n", .{what});
        return error.KnownRedTurnedGreen;
    }
    std.debug.print("known red until its step: {s}\n", .{what});
}

/// What the browser showed for the streamed page at `page_path`: Chrome for
/// Testing when CRANE_CDP_TRACE_CHROME_PORT names one, else a Crane.
fn observe(allocator: Allocator, page_path: []const u8) !struct { seen: Seen, chrome: bool } {
    const site = try replay.Site.start(allocator);
    defer site.stop();
    var url_buffer: [96]u8 = undefined;
    const url = try site.url(&url_buffer, page_path);

    if (std.c.getenv("CRANE_CDP_TRACE_CHROME_PORT")) |port_text| {
        const port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
        const path = try browserPath(allocator, port);
        defer allocator.free(path);
        const client = try cdp.Client.openWebSocket(allocator, port, path, null);
        defer client.close();
        if (client.upgrade_status != 101) return error.UpgradeRefused;
        const seen = try titleTiming(allocator, client, url);
        progress("Chrome {s}: listed before DOMContentLoaded {}, event before {}, event at all {}", .{ page_path, seen.listed_before_dcl, seen.event_before_dcl, seen.event_at_all });
        return .{ .seen = seen, .chrome = true };
    }

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const path = try browserPath(allocator, server.port);
    defer allocator.free(path);
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    defer client.close();
    const seen = try titleTiming(allocator, client, url);
    progress("Crane {s}: listed before DOMContentLoaded {}, event before {}, event at all {}", .{ page_path, seen.listed_before_dcl, seen.event_before_dcl, seen.event_at_all });
    return .{ .seen = seen, .chrome = false };
}

test "a parsed title is in Target.getTargets before DOMContentLoaded when the body streams in after it, as Chrome's: its encoding known up front" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const result = try observe(gpa.allocator(), "/streamed-charset.html");
    try testing.expect(result.seen.listed_before_dcl);
    // No event tells a title (Chrome sends targetInfoChanged for a commit
    // only: mcp1_target_title_test.zig).
    try testing.expect(!result.seen.event_at_all);
}

test "a parsed title is in Target.getTargets before DOMContentLoaded with no charset named (knownRed until the network parser decodes while it scans)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const result = try observe(gpa.allocator(), "/streamed.html");
    try testing.expect(!result.seen.event_at_all);
    // Chrome: its decoder hands the 60-byte first chunk to the parser while
    // the meta charset scan reads on; Crane holds the bytes until the scan
    // has read 1024 characters or the body ended.
    if (result.chrome) return testing.expect(result.seen.listed_before_dcl);
    try knownRed(landed.network_parser_decodes_while_scanning, result.seen.listed_before_dcl, "a no-charset streamed page's title is in getTargets before DOMContentLoaded");
}
