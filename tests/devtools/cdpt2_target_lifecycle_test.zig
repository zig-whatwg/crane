//! Target lifecycle and loader ids as Chrome reports them (lane cdpt2: lane
//! cdpr's conformance trace, G1, G3 and G7), against Chrome for Testing
//! 157's own protocol log of Vue's e2e suite under Puppeteer 25.11
//! (tmp/plans/cdp1-evidence/vue-e2e.protocol.log.gz):
//! - G1: a created tab's TAB session is told waitingForDebugger, its page
//!   child is not, and the tab session's runIfWaitingForDebugger lets the
//!   tab's first navigation go (Puppeteer's page.goto waited forever);
//! - G7: a closing tab's page target goes first - the page session's
//!   detachedFromTarget on the tab session, the page's targetDestroyed -
//!   then the tab session's detachedFromTarget on the browser session;
//! - G3: one loaderId per document - a navigation's requestId is its
//!   loaderId and the frame's, and a subresource fetch of a document (an
//!   initial about:blank's included) names the frame's loaderId.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

fn connectBrowser(allocator: std.mem.Allocator, server: *devtools.Server) !*cdp.Client {
    var path_buffer: [96]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "/devtools/browser/{s}", .{server.browser_id.slice()});
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    if (client.upgrade_status != 101) return error.UpgradeRefused;
    return client;
}

/// Puppeteer's launch and newPage (vue-e2e log l.1-110): auto-attach to tab
/// targets waiting, Target.createTarget, the tab session's own setAutoAttach
/// and runIfWaitingForDebugger. Returns the page target's id and both
/// session ids, OWNED.
const PuppeteerTab = struct {
    page_id: []u8,
    tab_session: []u8,
    page_session: []u8,

    fn open(allocator: std.mem.Allocator, client: *cdp.Client, url: []const u8) !PuppeteerTab {
        const auto = try client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true,\"filter\":[{\"type\":\"page\",\"exclude\":true},{}]}", "");
        auto.deinit();
        // The tabs that exist already (the Browser's first page) were
        // attached before the answer, not waiting (Chrome: its startup tab,
        // vue-e2e protocol log l.9-12): not the tab this opens.
        _ = client.dropQueued("Target.attachedToTarget");
        var params_buffer: [256]u8 = undefined;
        const created = try client.call("Target.createTarget", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"{s}\"}}", .{url}), "");
        defer created.deinit();
        const page_id = try allocator.dupe(u8, cdp.stringAt(created.value, "result.targetId").?);
        errdefer allocator.free(page_id);

        // The new tab's TAB target, attached waiting (Chrome: waitingForDebugger
        // true for the tab - vue-e2e l.107).
        const tab = blk: while (true) {
            const attached = try client.waitEvent("Target.attachedToTarget");
            if (std.mem.eql(u8, cdp.stringAt(attached.value, "params.targetInfo.type").?, "tab")) break :blk attached;
            attached.deinit();
        };
        defer tab.deinit();
        try testing.expect(cdp.at(tab.value, "params.waitingForDebugger").?.bool);
        const tab_session = try allocator.dupe(u8, cdp.stringAt(tab.value, "params.sessionId").?);
        errdefer allocator.free(tab_session);

        // The tab session's auto-attach: its page child, NOT waiting.
        const child = try client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true,\"filter\":[{}]}", tab_session);
        child.deinit();
        const page = try client.waitEventOn("Target.attachedToTarget", tab_session);
        defer page.deinit();
        try testing.expectEqualStrings("page", cdp.stringAt(page.value, "params.targetInfo.type").?);
        try testing.expectEqualStrings(page_id, cdp.stringAt(page.value, "params.targetInfo.targetId").?);
        try testing.expectEqualStrings(tab_session, cdp.stringAt(page.value, "sessionId").?);
        try testing.expect(!cdp.at(page.value, "params.waitingForDebugger").?.bool);
        const page_session = try allocator.dupe(u8, cdp.stringAt(page.value, "params.sessionId").?);
        return .{ .page_id = page_id, .tab_session = tab_session, .page_session = page_session };
    }

    fn deinit(self: PuppeteerTab, allocator: std.mem.Allocator) void {
        allocator.free(self.page_id);
        allocator.free(self.tab_session);
        allocator.free(self.page_session);
    }
};

test "G1: the TAB session waits for the debugger, its page child does not, and the tab session's runIfWaitingForDebugger lets the first navigation go" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    discover.deinit();
    const url = "data:text/html,<title>released</title>";
    const tab = try PuppeteerTab.open(allocator, client, url);
    defer tab.deinit(allocator);

    // Held until the tab session runs: the page is still on about:blank.
    const before = try client.call("Target.getTargetInfo", "{}", tab.page_session);
    defer before.deinit();
    try testing.expectEqualStrings("about:blank", cdp.stringAt(before.value, "result.targetInfo.url").?);

    const run = try client.call("Runtime.runIfWaitingForDebugger", "{}", tab.tab_session);
    run.deinit();
    // Released: the page commits the URL it was created with (Puppeteer's
    // page.goto then proceeds).
    while (true) {
        const changed = try client.waitEvent("Target.targetInfoChanged");
        defer changed.deinit();
        if (!std.mem.eql(u8, cdp.stringAt(changed.value, "params.targetInfo.targetId").?, tab.page_id)) continue;
        if (std.mem.eql(u8, cdp.stringAt(changed.value, "params.targetInfo.url").?, url)) break;
    }
}

test "G1: a tab session that detaches without running releases its tab's hold" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    discover.deinit();
    const url = "data:text/html,<title>detached</title>";
    const tab = try PuppeteerTab.open(allocator, client, url);
    defer tab.deinit(allocator);
    var params_buffer: [96]u8 = undefined;
    const detach = try client.call("Target.detachFromTarget", try std.fmt.bufPrint(&params_buffer, "{{\"sessionId\":\"{s}\"}}", .{tab.tab_session}), "");
    detach.deinit();
    while (true) {
        const changed = try client.waitEvent("Target.targetInfoChanged");
        defer changed.deinit();
        if (!std.mem.eql(u8, cdp.stringAt(changed.value, "params.targetInfo.targetId").?, tab.page_id)) continue;
        if (std.mem.eql(u8, cdp.stringAt(changed.value, "params.targetInfo.url").?, url)) break;
    }
}

test "G7: a closing tab's page target goes first - its session's detach on the tab session, its targetDestroyed - then the tab session's detach on the browser session" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    discover.deinit();
    const tab = try PuppeteerTab.open(allocator, client, "about:blank");
    defer tab.deinit(allocator);
    const run = try client.call("Runtime.runIfWaitingForDebugger", "{}", tab.tab_session);
    run.deinit();

    var params_buffer: [96]u8 = undefined;
    const closed = try client.call("Target.closeTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\"}}", .{tab.page_id}), "");
    closed.deinit();

    // Chrome's order (vue-e2e l.9551-9577): the page session's detach on the
    // tab session, the page's targetDestroyed, then the tab session's detach
    // on the browser session.
    const order = [_][]const u8{ "Target.detachedFromTarget", "Target.targetDestroyed" };
    const first = try client.nextEventOf(&order);
    defer first.deinit();
    try testing.expectEqualStrings("Target.detachedFromTarget", cdp.stringAt(first.value, "method").?);
    try testing.expectEqualStrings(tab.page_session, cdp.stringAt(first.value, "params.sessionId").?);
    try testing.expectEqualStrings(tab.tab_session, cdp.stringAt(first.value, "sessionId").?);
    const second = try client.nextEventOf(&order);
    defer second.deinit();
    try testing.expectEqualStrings("Target.targetDestroyed", cdp.stringAt(second.value, "method").?);
    try testing.expectEqualStrings(tab.page_id, cdp.stringAt(second.value, "params.targetId").?);
    const third = try client.nextEventOf(&order);
    defer third.deinit();
    try testing.expectEqualStrings("Target.detachedFromTarget", cdp.stringAt(third.value, "method").?);
    try testing.expectEqualStrings(tab.tab_session, cdp.stringAt(third.value, "params.sessionId").?);
    // On the browser session: no sessionId.
    try testing.expect(cdp.at(third.value, "sessionId") == null);
}

test "G7: the last session's detach first reports the target not attached (targetInfoChanged), then detachedFromTarget" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true}", "");
    discover.deinit();
    const listed = try client.call("Target.getTargets", "{}", "");
    defer listed.deinit();
    const page_id = cdp.stringAt(cdp.at(listed.value, "result.targetInfos").?.array.items[0], "targetId").?;
    var params_buffer: [128]u8 = undefined;
    const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page_id}), "");
    defer attached.deinit();
    const session = cdp.stringAt(attached.value, "result.sessionId").?;
    // Attaching made it attached: targetInfoChanged attached true.
    const on = try client.waitEvent("Target.targetInfoChanged");
    defer on.deinit();
    try testing.expect(cdp.at(on.value, "params.targetInfo.attached").?.bool);

    const detach = try client.call("Target.detachFromTarget", try std.fmt.bufPrint(&params_buffer, "{{\"sessionId\":\"{s}\"}}", .{session}), "");
    detach.deinit();
    const order = [_][]const u8{ "Target.targetInfoChanged", "Target.detachedFromTarget" };
    const first = try client.nextEventOf(&order);
    defer first.deinit();
    try testing.expectEqualStrings("Target.targetInfoChanged", cdp.stringAt(first.value, "method").?);
    try testing.expect(!cdp.at(first.value, "params.targetInfo.attached").?.bool);
    const second = try client.nextEventOf(&order);
    defer second.deinit();
    try testing.expectEqualStrings("Target.detachedFromTarget", cdp.stringAt(second.value, "method").?);
}

test "G3: one loaderId per document - a navigation's requestId is its loaderId and the frame's; a subresource fetch names its document's, an initial about:blank's included" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const tab_id = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const listed = try client.call("Target.getTargets", "{}", "");
    defer listed.deinit();
    // The PAGE target of the tab this test made - the newest page: the list
    // also has the Browser's first page, and each tab's TAB target, which
    // the first entry is (a session on it saw none of the tab's requests:
    // the test waited for good).
    const page_id = blk: {
        var newest: ?[]const u8 = null;
        for (cdp.at(listed.value, "result.targetInfos").?.array.items) |info| {
            if (std.mem.eql(u8, cdp.stringAt(info, "type").?, "page")) newest = cdp.stringAt(info, "targetId").?;
        }
        break :blk newest orelse return error.NoPageTarget;
    };
    var params_buffer: [160]u8 = undefined;
    const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page_id}), "");
    defer attached.deinit();
    const session = cdp.stringAt(attached.value, "result.sessionId").?;
    for ([_][]const u8{ "Page.enable", "Network.enable" }) |m| {
        const r = try client.call(m, "{}", session);
        r.deinit();
    }

    // The initial about:blank: the frame's loaderId is the one its fetches name.
    const blank_tree = try client.call("Page.getFrameTree", "{}", session);
    defer blank_tree.deinit();
    const blank_loader = cdp.stringAt(blank_tree.value, "result.frameTree.frame.loaderId").?;
    const fetched = try host.evaluate(allocator, tab_id, "fetch('data:text/plain,a').then(r => r.text())", .{ .await_promise = true }, 10_000);
    fetched.deinit(allocator);
    const sub = try client.waitEvent("Network.requestWillBeSent");
    defer sub.deinit();
    try testing.expectEqualStrings(blank_loader, cdp.stringAt(sub.value, "params.loaderId").?);

    // A navigation: requestId == loaderId == the committed frame's loaderId.
    const navigated = try client.call("Page.navigate", "{\"url\":\"data:text/html,<p>doc</p>\"}", session);
    defer navigated.deinit();
    const nav_loader = cdp.stringAt(navigated.value, "result.loaderId").?;
    const request = blk: while (true) {
        const sent = try client.waitEvent("Network.requestWillBeSent");
        if (std.mem.eql(u8, cdp.stringAt(sent.value, "params.type").?, "Document")) break :blk sent;
        sent.deinit();
    };
    defer request.deinit();
    try testing.expectEqualStrings(cdp.stringAt(request.value, "params.requestId").?, cdp.stringAt(request.value, "params.loaderId").?);
    try testing.expectEqualStrings(nav_loader, cdp.stringAt(request.value, "params.loaderId").?);
    const frame = try client.waitEvent("Page.frameNavigated");
    defer frame.deinit();
    try testing.expectEqualStrings(nav_loader, cdp.stringAt(frame.value, "params.frame.loaderId").?);
    try testing.expect(!std.mem.eql(u8, nav_loader, blank_loader));
}

test "G12: disposing a context with several tabs removes every tab and page target, each session detached, and nothing reads past the target list" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    discover.deinit();
    // Playwright's: auto-attach to pages, waiting.
    const auto = try client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", "");
    auto.deinit();
    const context = try client.call("Target.createBrowserContext", "{}", "");
    defer context.deinit();
    const context_id = cdp.stringAt(context.value, "result.browserContextId").?;
    var params_buffer: [192]u8 = undefined;
    // Three tabs: six targets the disposal removes, pair by pair.
    for (0..3) |_| {
        const created = try client.call("Target.createTarget", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{context_id}), "");
        created.deinit();
    }
    const dispose = try client.call("Target.disposeBrowserContext", try std.fmt.bufPrint(&params_buffer, "{{\"browserContextId\":\"{s}\"}}", .{context_id}), "");
    defer dispose.deinit();
    try testing.expect(cdp.at(dispose.value, "result") != null);
    // Every page session detached and all six targets destroyed.
    var detached: usize = 0;
    var destroyed: usize = 0;
    while (detached < 3 or destroyed < 6) {
        const event = try client.nextEventOf(&.{ "Target.detachedFromTarget", "Target.targetDestroyed" });
        defer event.deinit();
        if (std.mem.eql(u8, cdp.stringAt(event.value, "method").?, "Target.detachedFromTarget")) detached += 1 else destroyed += 1;
    }
    // The registry holds none of them.
    const left = try client.call("Target.getTargets", "{}", "");
    defer left.deinit();
    for (cdp.at(left.value, "result.targetInfos").?.array.items) |info| {
        try testing.expect(!std.mem.eql(u8, context_id, cdp.stringAt(info, "browserContextId") orelse ""));
    }
}

test "G12: a disposeOnDetach context with tabs goes with its connection, without reading past the target list" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    {
        const client = try connectBrowser(allocator, server);
        defer client.close();
        const context = try client.call("Target.createBrowserContext", "{\"disposeOnDetach\":true}", "");
        defer context.deinit();
        const context_id = cdp.stringAt(context.value, "result.browserContextId").?;
        var params_buffer: [192]u8 = undefined;
        for (0..2) |_| {
            const created = try client.call("Target.createTarget", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{context_id}), "");
            created.deinit();
        }
    }
    // A second connection soon sees the context gone (the first one's end
    // reaches the devtools thread on its own; each call is a round trip).
    const watcher = try connectBrowser(allocator, server);
    defer watcher.close();
    var gone = false;
    for (0..2000) |_| {
        const contexts = try watcher.call("Target.getBrowserContexts", "{}", "");
        defer contexts.deinit();
        if (cdp.at(contexts.value, "result.browserContextIds").?.array.items.len == 0) {
            gone = true;
            break;
        }
    }
    try testing.expect(gone);
}

test "G15: a new page target has title \"\" and no parentId, its tab target the URL \"\"; the commit's targetInfoChanged brings the URL, the document's <title> one more" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    discover.deinit();
    // The targets that exist already (the Browser's first page: its tab and
    // page) were reported before the answer: not the ones this creates.
    _ = client.dropQueued("Target.targetCreated");
    const url = "data:text/html,<title>Hello</title><p>x";
    var params_buffer: [160]u8 = undefined;
    const created = try client.call("Target.createTarget", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"{s}\"}}", .{url}), "");
    defer created.deinit();
    const page_id = cdp.stringAt(created.value, "result.targetId").?;

    // targetCreated: tab first (url ""), then the page (about:blank, title "",
    // no parentId) - vue-e2e protocol log l.103-110.
    var saw_tab = false;
    var saw_page = false;
    while (!(saw_tab and saw_page)) {
        const event = try client.waitEvent("Target.targetCreated");
        defer event.deinit();
        const info = cdp.at(event.value, "params.targetInfo").?;
        const kind = cdp.stringAt(info, "type").?;
        if (std.mem.eql(u8, kind, "tab")) {
            saw_tab = true;
            try testing.expectEqualStrings("", cdp.stringAt(info, "url").?);
            try testing.expectEqualStrings("", cdp.stringAt(info, "title").?);
        } else if (std.mem.eql(u8, kind, "page")) {
            saw_page = true;
            try testing.expectEqualStrings(page_id, cdp.stringAt(info, "targetId").?);
            try testing.expectEqualStrings("about:blank", cdp.stringAt(info, "url").?);
            try testing.expectEqualStrings("", cdp.stringAt(info, "title").?);
            try testing.expect(cdp.at(info, "parentId") == null);
        }
    }
    // Then the page's title: the document's own once it is parsed.
    while (true) {
        const changed = try client.waitEvent("Target.targetInfoChanged");
        defer changed.deinit();
        const info = cdp.at(changed.value, "params.targetInfo").?;
        if (!std.mem.eql(u8, cdp.stringAt(info, "targetId").?, page_id)) continue;
        try testing.expect(cdp.at(info, "parentId") == null);
        if (std.mem.eql(u8, cdp.stringAt(info, "title").?, "Hello")) {
            try testing.expectEqualStrings(url, cdp.stringAt(info, "url").?);
            break;
        }
        // Before the title: the committed URL stands for it, or "" before
        // the commit.
        const title = cdp.stringAt(info, "title").?;
        try testing.expect(title.len == 0 or std.mem.eql(u8, title, cdp.stringAt(info, "url").?));
    }
}
