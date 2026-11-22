//! Puppeteer 25.11.0's session, replayed (lane cdpr, part C of the CDP part 1
//! conformance trace, tmp/plans/cdp-conformance-trace.md): what Vue's e2e
//! suite (and Angular's Puppeteer launcher, decision D9) sends through
//! `PUPPETEER_EXECUTABLE_PATH` - discovery and auto-attach to tab targets,
//! `newPage()`, the page's initialisation, `goto`, handle adoption between
//! worlds, `setContent`, request interception, `close` - pipelined in its
//! order, against the events, orders and result fields Chrome for Testing 157
//! gave it (tmp/plans/cdp1-evidence/seq-vue-e2e-one.txt,
//! vue-e2e.protocol.log; puppeteer-core ChromeTargetManager.js,
//! FrameManager.js, LifecycleWatcher.js, NetworkManager.js, Frame.js).
//!
//! Written in the CDP phase, not run (user directive 2026-11-21 5:48 PM ET:
//! implement now, run every test in one later pass). A test that checks a
//! trace finding names it (G1, G3, G6, G7, G9): it fails until that fix
//! lands.

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

/// Puppeteer's utility world (FrameManager UTILITY_WORLD_NAME).
const utility_world = "__puppeteer_utility_world__25.11.0";

/// ChromeTargetManager.initialize: discovery, then auto-attach to tabs; the
/// existing tab's session auto-attaches its page (vue-e2e log l.1-18).
fn launch(fx: *replay.Fixture) !void {
    const rec = &fx.rec;
    const discover = try rec.send("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    const reply = try rec.awaitResponse(discover);
    // The existing tab's two targets, announced before the reply.
    const tab_created = rec.eventIndex("Target.targetCreated", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "tab" }}) orelse return error.NoTabTarget;
    const page_created = rec.eventIndex("Target.targetCreated", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }}) orelse return error.NoPageTarget;
    try testing.expect(tab_created < reply and page_created < reply);
    try testing.expectEqualStrings("about:blank", cdp.stringAt(rec.at(page_created), "params.targetInfo.url").?);

    const start = rec.log.items.len;
    const auto = try rec.send("Target.setAutoAttach", "{\"waitForDebuggerOnStart\":true,\"flatten\":true,\"autoAttach\":true,\"filter\":[{\"type\":\"page\",\"exclude\":true},{}]}", "");
    _ = try rec.result(auto);
    // Puppeteer attaches to TAB targets; the existing one is not waiting.
    const tab = try rec.awaitEvent("Target.attachedToTarget", "", start, &.{.{ .path = "params.targetInfo.type", .equals = "tab" }});
    try testing.expect(!cdp.at(rec.at(tab), "params.waitingForDebugger").?.bool);
    try testing.expect(rec.eventIndex("Target.attachedToTarget", "", start, &.{.{ .path = "params.targetInfo.type", .equals = "page" }}) == null);
    const tab_session = cdp.stringAt(rec.at(tab), "params.sessionId").?;

    // The tab session: auto-attach (its page child) and run, together.
    const child_start = rec.log.items.len;
    const child_auto = try rec.send("Target.setAutoAttach", "{\"waitForDebuggerOnStart\":true,\"flatten\":true,\"autoAttach\":true,\"filter\":[{}]}", tab_session);
    const child_run = try rec.send("Runtime.runIfWaitingForDebugger", "{}", tab_session);
    try rec.awaitAll(&.{ child_auto, child_run });
    const page = try rec.awaitEvent("Target.attachedToTarget", tab_session, child_start, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    try testing.expect(!cdp.at(rec.at(page), "params.waitingForDebugger").?.bool);
}

/// A `newPage()` (Browser._createPageInContext, CdpPage._create): its target
/// and page session, initialised.
const Page = struct {
    target_id: []u8,
    tab_id: []u8,
    tab_session: []u8,
    session: []u8,
    main_context: i64,
    utility_context: i64,

    fn deinit(self: *Page, allocator: std.mem.Allocator) void {
        allocator.free(self.target_id);
        allocator.free(self.tab_id);
        allocator.free(self.tab_session);
        allocator.free(self.session);
    }
};

fn newPage(fx: *replay.Fixture, allocator: std.mem.Allocator) !Page {
    const rec = &fx.rec;
    var buffer: [512]u8 = undefined;
    const start = rec.log.items.len;
    const created = try rec.send("Target.createTarget", "{\"url\":\"about:blank\"}", "");
    const target_id = try replay.dupeAt(allocator, try rec.result(created), "targetId");
    errdefer allocator.free(target_id);

    // The new tab target, attached on the browser session - waiting: its
    // page's first navigation is held until the tab session runs (G1;
    // vue-e2e log l.107: tab waitingForDebugger true).
    const tab = try rec.awaitEvent("Target.attachedToTarget", "", start, &.{.{ .path = "params.targetInfo.type", .equals = "tab" }});
    try testing.expect(cdp.at(rec.at(tab), "params.waitingForDebugger").?.bool);
    const tab_id = try replay.dupeAt(allocator, rec.at(tab), "params.targetInfo.targetId");
    errdefer allocator.free(tab_id);
    const tab_session = try replay.dupeAt(allocator, rec.at(tab), "params.sessionId");
    errdefer allocator.free(tab_session);
    // Discovery saw the tab and its page (Target.targetCreated).
    _ = try rec.awaitEvent("Target.targetCreated", "", start, &.{.{ .path = "params.targetInfo.targetId", .equals = target_id }});

    // The tab session's auto-attach brings the page child, NOT waiting
    // (l.267); the tab's run releases the page.
    const child_start = rec.log.items.len;
    const child_auto = try rec.send("Target.setAutoAttach", "{\"waitForDebuggerOnStart\":true,\"flatten\":true,\"autoAttach\":true,\"filter\":[{}]}", tab_session);
    const child_run = try rec.send("Runtime.runIfWaitingForDebugger", "{}", tab_session);
    try rec.awaitAll(&.{ child_auto, child_run });
    const attached = try rec.awaitEvent("Target.attachedToTarget", tab_session, child_start, &.{.{ .path = "params.targetInfo.targetId", .equals = target_id }});
    try testing.expect(!cdp.at(rec.at(attached), "params.waitingForDebugger").?.bool);
    try testing.expectEqualStrings("page", cdp.stringAt(rec.at(attached), "params.targetInfo.type").?);
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    errdefer allocator.free(session);

    // CdpPage.#initialize and FrameManager.initialize, one batch
    // (seq-vue-e2e-one.txt #10-#20).
    const init_start = rec.log.items.len;
    const page_auto = try rec.send("Target.setAutoAttach", "{\"waitForDebuggerOnStart\":true,\"flatten\":true,\"autoAttach\":true,\"filter\":[{}]}", session);
    const run = try rec.send("Runtime.runIfWaitingForDebugger", "{}", session);
    const network = try rec.send("Network.enable", "{}", session);
    const page_enable = try rec.send("Page.enable", "{}", session);
    const tree = try rec.send("Page.getFrameTree", "{}", session);
    const lifecycle = try rec.send("Page.setLifecycleEventsEnabled", "{\"enabled\":true}", session);
    const runtime_enable = try rec.send("Runtime.enable", "{}", session);
    const audits = try rec.send("Audits.enable", "{}", session);
    const performance = try rec.send("Performance.enable", "{}", session);
    const log_enable = try rec.send("Log.enable", "{}", session);
    const webmcp = try rec.send("WebMCP.enable", "{}", session);
    const batch = [_]i64{ page_auto, run, network, page_enable, tree, lifecycle, runtime_enable, audits, performance, log_enable };
    try rec.awaitAll(&batch);
    for (batch) |id| try testing.expectEqual(@as(?i64, null), try rec.errorCode(id));
    // A domain Crane does not have: Chrome's -32601, which Puppeteer catches.
    try testing.expectEqual(@as(?i64, -32601), try rec.errorCode(webmcp));
    try testing.expectEqualStrings(target_id, cdp.stringAt(try rec.result(tree), "frameTree.frame.id").?);
    const main_created = rec.eventIndex("Runtime.executionContextCreated", session, init_start, &.{
        .{ .path = "params.context.auxData.isDefault", .equals = "true" },
        .{ .path = "params.context.auxData.frameId", .equals = target_id },
    }) orelse return error.NoMainContext;
    try testing.expect(main_created < rec.responseIndex(runtime_enable).?);
    const main_context = cdp.at(rec.at(main_created), "params.context.id").?.integer;

    // The utility world: on every new document, and now (#21-#22).
    const world_script = try rec.send("Page.addScriptToEvaluateOnNewDocument", "{\"source\":\"//# sourceURL=pptr:internal\",\"worldName\":\"" ++ utility_world ++ "\"}", session);
    _ = try rec.result(world_script);
    const world_start = rec.log.items.len;
    const world = try rec.send("Page.createIsolatedWorld", try std.fmt.bufPrint(&buffer, "{{\"frameId\":\"{s}\",\"worldName\":\"" ++ utility_world ++ "\",\"grantUniveralAccess\":true}}", .{target_id}), session);
    const world_reply = try rec.awaitResponse(world);
    const utility_created = rec.eventIndex("Runtime.executionContextCreated", session, world_start, &.{
        .{ .path = "params.context.name", .equals = utility_world },
        .{ .path = "params.context.auxData.frameId", .equals = target_id },
    }) orelse return error.NoUtilityContext;
    try testing.expect(utility_created < world_reply);
    const utility_context = cdp.at(try rec.result(world), "executionContextId").?.integer;

    // The viewport and touch (#23-#24), then the suite's own script (#25).
    const metrics = try rec.send("Emulation.setDeviceMetricsOverride", "{\"mobile\":false,\"width\":800,\"height\":600,\"deviceScaleFactor\":1,\"screenOrientation\":{\"angle\":0,\"type\":\"portraitPrimary\"}}", session);
    const touch = try rec.send("Emulation.setTouchEmulationEnabled", "{\"enabled\":false}", session);
    const storage_script = try rec.send("Page.addScriptToEvaluateOnNewDocument", "{\"source\":\"(() => {\\n\\t\\t\\tlocalStorage.clear();\\n\\t\\t})()\"}", session);
    try rec.awaitAll(&.{ metrics, touch, storage_script });
    for ([_]i64{ metrics, touch, storage_script }) |id| try testing.expectEqual(@as(?i64, null), try rec.errorCode(id));

    return .{ .target_id = target_id, .tab_id = tab_id, .tab_session = tab_session, .session = session, .main_context = main_context, .utility_context = utility_context };
}

/// Page.navigate as Frame.goto sends it, and what LifecycleWatcher waits
/// for (waitUntil 'load'). The new main and utility contexts, and the
/// navigation's loaderId (OWNED).
const Navigated = struct { loader: []u8, main_context: i64, utility_context: i64 };

fn goto(fx: *replay.Fixture, allocator: std.mem.Allocator, page: *const Page, url: []const u8) !Navigated {
    const rec = &fx.rec;
    var buffer: [256]u8 = undefined;
    const start = rec.log.items.len;
    const navigate = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\",\"frameId\":\"{s}\"}}", .{ url, page.target_id }), page.session);
    // G1: with the tab's hold never released this never comes.
    const reply = try rec.awaitResponse(navigate);
    const r = try rec.result(navigate);
    try testing.expect(cdp.at(r, "errorText") == null);
    const loader = try replay.dupeAt(allocator, r, "loaderId");
    errdefer allocator.free(loader);

    // frameStartedLoading (Frame._hasStartedLoading), then the navigation
    // request: isNavigationRequest = requestId == loaderId && type Document
    // (NetworkManager / CdpHTTPRequest), the loaderId Page.navigate gave (G3).
    _ = rec.eventIndex("Page.frameStartedLoading", page.session, start, &.{.{ .path = "params.frameId", .equals = page.target_id }}) orelse return error.NoFrameStartedLoading;
    const sent = rec.eventIndex("Network.requestWillBeSent", page.session, start, &.{
        .{ .path = "params.type", .equals = "Document" },
        .{ .path = "params.requestId", .equals = loader },
        .{ .path = "params.loaderId", .equals = loader },
        .{ .path = "params.frameId", .equals = page.target_id },
    }) orelse return error.NoNavigationRequest;
    try testing.expect(sent < reply);

    // The commit: init (Frame._loaderId, lifecycle cleared), cleared,
    // frameNavigated with the loaderId, the two contexts (l.48-56).
    const navigated = try rec.awaitEvent("Page.frameNavigated", page.session, reply, &.{
        .{ .path = "params.frame.id", .equals = page.target_id },
        .{ .path = "params.frame.loaderId", .equals = loader },
    });
    _ = rec.eventIndex("Page.lifecycleEvent", page.session, start, &.{
        .{ .path = "params.name", .equals = "init" },
        .{ .path = "params.loaderId", .equals = loader },
    }) orelse return error.NoInit;
    try testing.expect((rec.eventIndex("Runtime.executionContextsCleared", page.session, reply, &.{}) orelse return error.NotCleared) < navigated);
    const main_created = try rec.awaitEvent("Runtime.executionContextCreated", page.session, navigated, &.{
        .{ .path = "params.context.auxData.isDefault", .equals = "true" },
        .{ .path = "params.context.auxData.frameId", .equals = page.target_id },
    });
    const utility_created = try rec.awaitEvent("Runtime.executionContextCreated", page.session, navigated, &.{
        .{ .path = "params.context.name", .equals = utility_world },
        .{ .path = "params.context.auxData.frameId", .equals = page.target_id },
    });

    // What goto(waitUntil 'load') waits for: lifecycle load of the new
    // loader (after init), then frameStoppedLoading (l.75-79).
    const load = try rec.awaitEvent("Page.lifecycleEvent", page.session, navigated, &.{
        .{ .path = "params.name", .equals = "load" },
        .{ .path = "params.frameId", .equals = page.target_id },
        .{ .path = "params.loaderId", .equals = loader },
    });
    _ = try rec.awaitEvent("Page.frameStoppedLoading", page.session, load, &.{.{ .path = "params.frameId", .equals = page.target_id }});
    // The navigation's response (page.goto's return value).
    _ = rec.eventIndex("Network.responseReceived", page.session, start, &.{.{ .path = "params.requestId", .equals = loader }}) orelse return error.NoResponse;
    _ = try rec.awaitEvent("Network.loadingFinished", page.session, start, &.{.{ .path = "params.requestId", .equals = loader }});

    return .{
        .loader = loader,
        .main_context = cdp.at(rec.at(main_created), "params.context.id").?.integer,
        .utility_context = cdp.at(rec.at(utility_created), "params.context.id").?.integer,
    };
}

test "Puppeteer: launch (tab targets), newPage(), its initialisation, goto - the new tab is held until its tab session runs, then navigates (G1)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    try launch(fx);
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    var url_buffer: [96]u8 = undefined;
    const nav = try goto(fx, allocator, &page, try site.url(&url_buffer, "/"));
    defer allocator.free(nav.loader);

    // The page ran: in its new main world.
    const rec = &fx.rec;
    const check = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&url_buffer, "{{\"expression\":\"String(window.appRan)\",\"contextId\":{d},\"returnByValue\":true}}", .{nav.main_context}), page.session);
    try testing.expectEqualStrings("true", cdp.stringAt(try rec.result(check), "result.value").?);
}

test "Puppeteer handle adoption (waitForSelector, $eval): describeNode by objectId, resolveNode into the other world, callFunctionOn there; addBinding in the utility world (G9: no children)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    try launch(fx);
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    var buffer: [512]u8 = undefined;
    const nav = try goto(fx, allocator, &page, try site.url(&buffer, "/"));
    defer allocator.free(nav.loader);
    const rec = &fx.rec;

    // Its ARIA bindings, in the utility world by name (#27).
    const binding = try rec.send("Runtime.addBinding", "{\"name\":\"puppeteer___ariaQuerySelector\",\"executionContextName\":\"" ++ utility_world ++ "\"}", page.session);
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(binding));

    // The poller's result: an element handle in the utility world (#34).
    const found = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"document.querySelector('#x')\",\"contextId\":{d}}}", .{nav.utility_context}), page.session);
    const handle = try rec.result(found);
    try testing.expectEqualStrings("node", cdp.stringAt(handle, "result.subtype").?);
    const object_id = try replay.dupeAt(allocator, handle, "result.objectId");
    defer allocator.free(object_id);

    // describeNode {objectId} -> backendNodeId (#36): Chrome 157's node has
    // no `children` (1,229 results in vue-e2e.protocol.log: G9).
    const described = try rec.send("DOM.describeNode", try std.fmt.bufPrint(&buffer, "{{\"objectId\":\"{s}\"}}", .{object_id}), page.session);
    const d = try rec.result(described);
    try testing.expectEqual(@as(i64, 0), cdp.at(d, "node.nodeId").?.integer);
    try testing.expectEqualStrings("P", cdp.stringAt(d, "node.nodeName").?);
    try testing.expectEqual(@as(i64, 1), cdp.at(d, "node.nodeType").?.integer);
    try testing.expect(cdp.at(d, "node.childNodeCount") != null);
    try testing.expect(cdp.at(d, "node.children") == null);
    const backend = cdp.at(d, "node.backendNodeId").?.integer;

    // resolveNode into the main world (#38): the same node, that world's
    // wrapper.
    const resolved = try rec.send("DOM.resolveNode", try std.fmt.bufPrint(&buffer, "{{\"backendNodeId\":{d},\"executionContextId\":{d}}}", .{ backend, nav.main_context }), page.session);
    const o = try rec.result(resolved);
    try testing.expectEqualStrings("object", cdp.stringAt(o, "object.type").?);
    try testing.expectEqualStrings("node", cdp.stringAt(o, "object.subtype").?);
    try testing.expectEqualStrings("HTMLParagraphElement", cdp.stringAt(o, "object.className").?);
    const main_object = try replay.dupeAt(allocator, o, "object.objectId");
    defer allocator.free(main_object);
    try testing.expect(!std.mem.eql(u8, main_object, object_id));

    // $eval runs in the main world on the adopted handle (#48).
    const text = try rec.send("Runtime.callFunctionOn", try std.fmt.bufPrint(&buffer, "{{\"functionDeclaration\":\"(node) => node.textContent\",\"objectId\":\"{s}\",\"arguments\":[{{\"objectId\":\"{s}\"}}],\"returnByValue\":true,\"awaitPromise\":true}}", .{ main_object, main_object }), page.session);
    try testing.expectEqualStrings("hello", cdp.stringAt(try rec.result(text), "result.value").?);

    // Both handles released (#37, #39).
    for ([_][]const u8{ object_id, main_object }) |id| {
        const release = try rec.send("Runtime.releaseObject", try std.fmt.bufPrint(&buffer, "{{\"objectId\":\"{s}\"}}", .{id}), page.session);
        try testing.expectEqual(@as(?i64, null), try rec.errorCode(release));
    }
}

test "Puppeteer page.setContent: Page.setDocumentContent sends documentOpened and lifecycle init before its reply, then DOMContentLoaded and load (G6)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    try launch(fx);
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    // Frame.setContent: "We rely upon the fact that document.open() will
    // reset frame lifecycle with "init" lifecycle event" - it sends the
    // content, then waits for `load` (vue-e2e log l.221-227).
    var buffer: [256]u8 = undefined;
    const start = rec.log.items.len;
    const set = try rec.send("Page.setDocumentContent", try std.fmt.bufPrint(&buffer, "{{\"frameId\":\"{s}\",\"html\":\"<div id=\\\"app\\\">x</div>\"}}", .{page.target_id}), page.session);
    const reply = try rec.awaitResponse(set);
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(set));
    const opened = rec.eventIndex("Page.documentOpened", page.session, start, &.{.{ .path = "params.frame.id", .equals = page.target_id }}) orelse return error.NoDocumentOpened;
    const init = rec.eventIndex("Page.lifecycleEvent", page.session, start, &.{
        .{ .path = "params.name", .equals = "init" },
        .{ .path = "params.frameId", .equals = page.target_id },
    }) orelse return error.NoInitAtOpen;
    try testing.expect(opened < init and init < reply);
    const dcl = try rec.awaitEvent("Page.lifecycleEvent", page.session, init, &.{
        .{ .path = "params.name", .equals = "DOMContentLoaded" },
        .{ .path = "params.frameId", .equals = page.target_id },
    });
    _ = try rec.awaitEvent("Page.lifecycleEvent", page.session, dcl, &.{
        .{ .path = "params.name", .equals = "load" },
        .{ .path = "params.frameId", .equals = page.target_id },
    });
    const content = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"document.getElementById('app').textContent\",\"contextId\":{d},\"returnByValue\":true}}", .{page.main_context}), page.session);
    try testing.expectEqualStrings("x", cdp.stringAt(try rec.result(content), "result.value").?);
}

test "Puppeteer setRequestInterception: Fetch.requestPaused names the request's Network id; fulfillRequest answers the page's fetch" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    try launch(fx);
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    var buffer: [512]u8 = undefined;
    const nav = try goto(fx, allocator, &page, try site.url(&buffer, "/"));
    defer allocator.free(nav.loader);
    const rec = &fx.rec;

    // NetworkManager.setRequestInterception(true): the cache off, Fetch on.
    const cache = try rec.send("Network.setCacheDisabled", "{\"cacheDisabled\":true}", page.session);
    const enable = try rec.send("Fetch.enable", "{\"handleAuthRequests\":true,\"patterns\":[{\"urlPattern\":\"*\"}]}", page.session);
    try rec.awaitAll(&.{ cache, enable });
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(cache));
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(enable));

    const start = rec.log.items.len;
    const kick = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"window.answer = fetch('/data.json').then(r => r.text()); 0\",\"contextId\":{d}}}", .{nav.main_context}), page.session);
    _ = try rec.result(kick);
    // Puppeteer pairs requestWillBeSent and requestPaused by networkId, and
    // drops the pair if the URL or method differ.
    const paused = try rec.awaitEvent("Fetch.requestPaused", page.session, start, &.{});
    const p = rec.at(paused);
    const network_id = cdp.stringAt(p, "params.networkId") orelse return error.NoNetworkId;
    const sent = try rec.awaitEvent("Network.requestWillBeSent", page.session, start, &.{.{ .path = "params.requestId", .equals = network_id }});
    try testing.expectEqualStrings(cdp.stringAt(rec.at(sent), "params.request.url").?, cdp.stringAt(p, "params.request.url").?);
    try testing.expectEqualStrings(cdp.stringAt(rec.at(sent), "params.request.method").?, cdp.stringAt(p, "params.request.method").?);
    try testing.expectEqualStrings(page.target_id, cdp.stringAt(p, "params.frameId").?);
    try testing.expectEqualStrings("Fetch", cdp.stringAt(p, "params.resourceType").?);

    // HTTPRequest.respond: status, headers, base64 body ("intercepted").
    const fulfill = try rec.send("Fetch.fulfillRequest", try std.fmt.bufPrint(&buffer, "{{\"requestId\":\"{s}\",\"responseCode\":200,\"responsePhrase\":\"OK\",\"responseHeaders\":[{{\"name\":\"content-type\",\"value\":\"text/plain\"}}],\"body\":\"aW50ZXJjZXB0ZWQ=\"}}", .{cdp.stringAt(p, "params.requestId").?}), page.session);
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(fulfill));
    const answer = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"window.answer\",\"contextId\":{d},\"awaitPromise\":true,\"returnByValue\":true}}", .{nav.main_context}), page.session);
    try testing.expectEqualStrings("intercepted", cdp.stringAt(try rec.result(answer), "result.value").?);
}

test "Puppeteer page.close() and browser.close(): the page session's detachedFromTarget on the tab session before the tab's (G7); both targets destroyed; Browser.close answers" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    try launch(fx);
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    var buffer: [128]u8 = undefined;
    const start = rec.log.items.len;
    const close = try rec.send("Target.closeTarget", try std.fmt.bufPrint(&buffer, "{{\"targetId\":\"{s}\"}}", .{page.target_id}), "");
    try testing.expect(cdp.at(try rec.result(close), "success").?.bool);
    // vue-e2e log l.9552 then l.9577.
    const page_gone = try rec.awaitEvent("Target.detachedFromTarget", page.tab_session, start, &.{
        .{ .path = "params.sessionId", .equals = page.session },
        .{ .path = "params.targetId", .equals = page.target_id },
    });
    const tab_gone = try rec.awaitEvent("Target.detachedFromTarget", "", start, &.{
        .{ .path = "params.sessionId", .equals = page.tab_session },
        .{ .path = "params.targetId", .equals = page.tab_id },
    });
    try testing.expect(page_gone < tab_gone);
    _ = try rec.awaitEvent("Target.targetDestroyed", "", start, &.{.{ .path = "params.targetId", .equals = page.target_id }});
    _ = try rec.awaitEvent("Target.targetDestroyed", "", start, &.{.{ .path = "params.targetId", .equals = page.tab_id }});

    const bye = try rec.send("Browser.close", "{}", "");
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(bye));
    try testing.expect(fx.server.isClosed());
}
