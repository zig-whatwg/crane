//! A realm's platform objects that its document's destruction or abort must
//! reach as a whole are on lists of the realm's own (runtime.ContextData
//! objects(kind); lane gstate3): its MessagePorts (HTML "destroy a document"
//! step 5), its WebSockets ("make disappear"), its fetch() calls, XHR fetches,
//! classic script fetches and style sheet loads ("abort a document"). They
//! were one list per THREAD, every realm's objects in it, filtered by realm at
//! each walk - and never given back.
//!
//! A pin: the walks filtered by realm, so the old lists answered right; the
//! test shows each object on its own realm's list and on no other's - a page
//! and its frame, and another Browser's page on the same thread - and a frame's
//! end leaves the page's alone. (Nothing listens on 127.0.0.1:59999: what is
//! fetched there fails, after the checks have read the lists.)
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}

fn openBrowser(url: []const u8) !*Browser {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body><iframe></iframe>", .{ .base_url = url });
    return browser;
}

fn run(browser: *Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn count(realm: runtime.Context, kind: runtime.ContextData.ObjectKind) usize {
    return realm.objects(kind).items.len;
}

fn objectsAreTheirRealms() !void {
    const a = try openBrowser("http://gs3-lists-a.test/");
    defer a.deinit();
    const b = try openBrowser("http://gs3-lists-b.test/");
    defer b.deinit();
    const page = a.getRealm().?;
    const other = b.getRealm().?;
    const frame_function = try a.evaluateScript("document.querySelector('iframe').contentWindow.MessageChannel");
    defer frame_function.release();
    const frame = engine.functionRealm(frame_function.borrow()) orelse return error.NoFrameRealm;
    try testing.expect(frame != page);

    // The page makes one of each kind.
    try run(a,
        \\globalThis.channel = new MessageChannel();
        \\globalThis.socket = new WebSocket("ws://127.0.0.1:59999/");
        \\globalThis.call = fetch("http://127.0.0.1:59999/fetch").catch(() => {});
        \\globalThis.xhr = new XMLHttpRequest();
        \\xhr.open("GET", "http://127.0.0.1:59999/xhr");
        \\xhr.send();
        \\const script = document.createElement("script");
        \\script.src = "http://127.0.0.1:59999/script.js";
        \\document.head.appendChild(script);
        \\const style = document.createElement("style");
        \\style.textContent = "@import url(http://127.0.0.1:59999/sheet.css);";
        \\document.head.appendChild(style);
    );
    try testing.expectEqual(@as(usize, 2), count(page, .message_ports));
    try testing.expectEqual(@as(usize, 1), count(page, .web_sockets));
    try testing.expectEqual(@as(usize, 1), count(page, .fetch_calls));
    try testing.expectEqual(@as(usize, 1), count(page, .xhr_fetches));
    try testing.expectEqual(@as(usize, 1), count(page, .classic_script_fetches));
    try testing.expectEqual(@as(usize, 1), count(page, .style_sheet_loads));
    // None of them is the frame's, or the other Browser's.
    inline for (.{ .message_ports, .web_sockets, .fetch_calls, .xhr_fetches, .classic_script_fetches, .style_sheet_loads }) |kind| {
        try testing.expectEqual(@as(usize, 0), count(frame, kind));
        try testing.expectEqual(@as(usize, 0), count(other, kind));
    }

    // The frame's own port pair is the frame's.
    try run(a, "globalThis.frameChannel = new (document.querySelector('iframe').contentWindow.MessageChannel)();");
    try testing.expectEqual(@as(usize, 2), count(frame, .message_ports));
    try testing.expectEqual(@as(usize, 2), count(page, .message_ports));

    // The frame goes: its document is destroyed, which disentangles its
    // ports; the page's are untouched.
    try run(a, "document.querySelector('iframe').remove(); globalThis.frameChannel = null;");
    try testing.expectEqual(@as(usize, 2), count(page, .message_ports));
}

test "a realm's ports, sockets, fetches and loads are on its own lists, and on no other realm's" {
    try onThread(objectsAreTheirRealms);
}
