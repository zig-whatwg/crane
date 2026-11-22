//! Playwright's connect-over-CDP session, replayed (lane cdpr, part C of the
//! CDP part 1 conformance trace, tmp/plans/cdp-conformance-trace.md): the
//! commands Playwright 1.51-1.64 sends - htmx's web-test-runner, Svelte's
//! runtime-browser, Vue's browser mode, React's three suites - pipelined in
//! its order, and the events, orders and result fields it depends on, as
//! Chrome for Testing 157 gave them (tmp/plans/cdp1-evidence/seq-svelte.txt,
//! svelte.protocol.log, htmx.protocol.log, vue-e2e-browser.protocol.log,
//! react-probe.protocol.log; playwright-core crBrowser.ts, crPage.ts,
//! crNetworkManager.ts, frames.ts).
//!
//! Written in the CDP phase, not run (user directive 2026-11-21 5:48 PM ET:
//! implement now, run every test in one later pass). A test that checks a
//! trace finding names it (G3, G4, G6): it fails until that fix lands.

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

/// Playwright's utility world for a page (crPage.ts UTILITY_WORLD_NAME and
/// its guid).
const utility_world = "__playwright_utility_world_page@c4ac11879d29c0b7b88a797d151117c4";

/// A page Playwright made and initialised.
const Page = struct {
    target_id: []u8,
    session: []u8,
    context_id: []u8,
    window_id: i64,
    /// The loaderId of its about:blank.
    first_loader: []u8,
    main_context: i64,
    utility_context: i64,

    fn deinit(self: *Page, allocator: std.mem.Allocator) void {
        allocator.free(self.target_id);
        allocator.free(self.session);
        allocator.free(self.context_id);
        allocator.free(self.first_loader);
    }
};

/// CRBrowser.connect (seq-svelte.txt #1-#21): the version, auto-attach with
/// waitForDebuggerOnStart, downloads; the existing page arrives attached,
/// not waiting. Returns Browser.getVersion's userAgent, OWNED.
fn connect(fx: *replay.Fixture, allocator: std.mem.Allocator) ![]u8 {
    const rec = &fx.rec;
    const version = try rec.send("Browser.getVersion", "{}", "");
    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", "");
    const downloads = try rec.send("Browser.setDownloadBehavior", "{\"behavior\":\"allowAndName\",\"downloadPath\":\"/tmp/playwright-artifacts\",\"eventsEnabled\":true}", "");
    try rec.awaitAll(&.{ version, auto, downloads });

    // Decision D4: product Crane/0.1 and Crane's own user agent - the fields
    // Playwright reads (product for its version, userAgent for headless).
    const v = try rec.result(version);
    try testing.expectEqualStrings("1.3", cdp.stringAt(v, "protocolVersion").?);
    try testing.expectEqualStrings("Crane/0.1", cdp.stringAt(v, "product").?);
    try testing.expect(cdp.stringAt(v, "userAgent").?.len > 0);
    try testing.expect(cdp.stringAt(v, "revision") != null);
    try testing.expect(cdp.stringAt(v, "jsVersion") != null);
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(downloads));

    // The existing page, attached on the browser session, not waiting;
    // before setAutoAttach's reply (svelte log l.5 vs l.22).
    const existing = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    try testing.expect(!cdp.at(rec.at(existing), "params.waitingForDebugger").?.bool);
    try testing.expect(cdp.stringAt(rec.at(existing), "params.targetInfo.browserContextId") != null);
    try testing.expect(existing < rec.responseIndex(auto).?);

    const info = try rec.send("Target.getTargetInfo", "{}", "");
    try testing.expectEqualStrings("browser", cdp.stringAt(try rec.result(info), "targetInfo.type").?);
    return replay.dupeAt(allocator, v, "userAgent");
}

/// A new context and a page in it, initialised as CRPage._initialize does
/// (seq-svelte.txt #22-#44, svelte log l.55-116).
fn newPage(fx: *replay.Fixture, allocator: std.mem.Allocator) !Page {
    const rec = &fx.rec;
    var buffer: [512]u8 = undefined;
    const made = try rec.send("Target.createBrowserContext", "{\"disposeOnDetach\":true}", "");
    const context_id = try replay.dupeAt(allocator, try rec.result(made), "browserContextId");
    errdefer allocator.free(context_id);
    const downloads = try rec.send("Browser.setDownloadBehavior", try std.fmt.bufPrint(&buffer, "{{\"behavior\":\"allowAndName\",\"browserContextId\":\"{s}\",\"downloadPath\":\"/tmp/playwright-artifacts\",\"eventsEnabled\":true}}", .{context_id}), "");
    _ = try rec.result(downloads);

    const before = rec.log.items.len;
    const created = try rec.send("Target.createTarget", try std.fmt.bufPrint(&buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{context_id}), "");
    const reply = try rec.awaitResponse(created);
    const target_id = try replay.dupeAt(allocator, try rec.result(created), "targetId");
    errdefer allocator.free(target_id);
    // A page target's id is its main frame's: 32 hex digits.
    try testing.expectEqual(@as(usize, 32), target_id.len);

    // attachedToTarget, waiting, before createTarget's reply (l.64-66).
    const attached = rec.eventIndex("Target.attachedToTarget", "", before, &.{.{ .path = "params.targetInfo.targetId", .equals = target_id }}) orelse return error.NotAttachedBeforeReply;
    try testing.expect(attached < reply);
    const a = rec.at(attached);
    try testing.expect(cdp.at(a, "params.waitingForDebugger").?.bool);
    try testing.expectEqualStrings("page", cdp.stringAt(a, "params.targetInfo.type").?);
    try testing.expectEqualStrings("about:blank", cdp.stringAt(a, "params.targetInfo.url").?);
    try testing.expectEqualStrings(context_id, cdp.stringAt(a, "params.targetInfo.browserContextId").?);
    const session = try replay.dupeAt(allocator, a, "params.sessionId");
    errdefer allocator.free(session);

    // The window first (#27), then the rest in one batch, as Playwright.
    const window = try rec.send("Browser.getWindowForTarget", "{}", session);
    const w = try rec.result(window);
    const window_id = cdp.at(w, "windowId").?.integer;
    try testing.expect(cdp.at(w, "bounds.width") != null);
    try testing.expect(cdp.at(w, "bounds.height") != null);

    const start = rec.log.items.len;
    const page_enable = try rec.send("Page.enable", "{}", session);
    const tree = try rec.send("Page.getFrameTree", "{}", session);
    const log_enable = try rec.send("Log.enable", "{}", session);
    const lifecycle = try rec.send("Page.setLifecycleEventsEnabled", "{\"enabled\":true}", session);
    const runtime_enable = try rec.send("Runtime.enable", "{}", session);
    const world_script = try rec.send("Page.addScriptToEvaluateOnNewDocument", "{\"source\":\"\",\"worldName\":\"" ++ utility_world ++ "\"}", session);
    const network = try rec.send("Network.enable", "{}", session);
    const page_auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", session);
    const focus = try rec.send("Emulation.setFocusEmulationEnabled", "{\"enabled\":true}", session);
    const bounds = try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"width\":1280,\"height\":720}}}}", .{window_id}), session);
    const metrics = try rec.send("Emulation.setDeviceMetricsOverride", "{\"mobile\":false,\"width\":1280,\"height\":720,\"screenWidth\":1280,\"screenHeight\":720,\"deviceScaleFactor\":1,\"screenOrientation\":{\"angle\":0,\"type\":\"landscapePrimary\"}}", session);
    const media = try rec.send("Emulation.setEmulatedMedia", "{\"media\":\"\",\"features\":[{\"name\":\"prefers-color-scheme\",\"value\":\"light\"},{\"name\":\"prefers-reduced-motion\",\"value\":\"no-preference\"},{\"name\":\"forced-colors\",\"value\":\"none\"},{\"name\":\"prefers-contrast\",\"value\":\"no-preference\"}]}", session);
    const run = try rec.send("Runtime.runIfWaitingForDebugger", "{}", session);
    const batch = [_]i64{ page_enable, tree, log_enable, lifecycle, runtime_enable, world_script, network, page_auto, focus, bounds, metrics, media, run };
    try rec.awaitAll(&batch);
    // Every one succeeds: Playwright's page initialisation awaits them all.
    for (batch) |id| try testing.expectEqual(@as(?i64, null), try rec.errorCode(id));

    // The frame tree: the page's main frame, its about:blank, its loaderId.
    const t = try rec.result(tree);
    try testing.expectEqualStrings(target_id, cdp.stringAt(t, "frameTree.frame.id").?);
    try testing.expectEqualStrings("about:blank", cdp.stringAt(t, "frameTree.frame.url").?);
    try testing.expectEqualStrings("text/html", cdp.stringAt(t, "frameTree.frame.mimeType").?);
    try testing.expect(cdp.stringAt(t, "frameTree.frame.domainAndRegistry") != null);
    try testing.expect(cdp.stringAt(t, "frameTree.frame.securityOrigin") != null);
    try testing.expect(cdp.stringAt(t, "frameTree.frame.secureContextType") != null);
    try testing.expect(cdp.stringAt(t, "frameTree.frame.crossOriginIsolatedContextType") != null);
    try testing.expect(cdp.at(t, "frameTree.frame.parentId") == null);
    const first_loader = try replay.dupeAt(allocator, t, "frameTree.frame.loaderId");
    errdefer allocator.free(first_loader);
    try testing.expectEqual(@as(usize, 32), first_loader.len);

    // setLifecycleEventsEnabled replays the about:blank's lifecycle in
    // Chrome's order, with its loaderId, before its reply (l.97-102).
    var from = start;
    for ([_][]const u8{ "commit", "DOMContentLoaded", "load", "networkAlmostIdle", "networkIdle" }) |name| {
        const at = rec.eventIndex("Page.lifecycleEvent", session, from, &.{
            .{ .path = "params.name", .equals = name },
            .{ .path = "params.frameId", .equals = target_id },
            .{ .path = "params.loaderId", .equals = first_loader },
        }) orelse return error.LifecycleNotReplayed;
        try testing.expect(at < rec.responseIndex(lifecycle).?);
        from = at + 1;
    }

    // Runtime.enable reports the main world's context before its reply,
    // with Chrome's auxData (l.103).
    const main_created = rec.eventIndex("Runtime.executionContextCreated", session, start, &.{
        .{ .path = "params.context.auxData.isDefault", .equals = "true" },
        .{ .path = "params.context.auxData.type", .equals = "default" },
        .{ .path = "params.context.auxData.frameId", .equals = target_id },
    }) orelse return error.NoMainContext;
    try testing.expect(main_created < rec.responseIndex(runtime_enable).?);
    const main_context = cdp.at(rec.at(main_created), "params.context.id").?.integer;
    try testing.expectEqualStrings("", cdp.stringAt(rec.at(main_created), "params.context.name").?);
    try testing.expect(cdp.stringAt(rec.at(main_created), "params.context.uniqueId") != null);

    // The new-document script's identifier is a string (Chrome: "1").
    try testing.expect(cdp.stringAt(try rec.result(world_script), "identifier") != null);
    // A device metrics override with Page enabled: Page.frameResized first.
    const resized = rec.eventIndex("Page.frameResized", session, start, &.{}) orelse return error.NoFrameResized;
    try testing.expect(resized < rec.responseIndex(metrics).?);

    // After the frame tree, the utility world (#44): its context comes,
    // named, isolated, of the frame, before the reply that names it.
    const world_start = rec.log.items.len;
    const world = try rec.send("Page.createIsolatedWorld", try std.fmt.bufPrint(&buffer, "{{\"frameId\":\"{s}\",\"grantUniveralAccess\":true,\"worldName\":\"" ++ utility_world ++ "\"}}", .{target_id}), session);
    const world_reply = try rec.awaitResponse(world);
    const utility_created = rec.eventIndex("Runtime.executionContextCreated", session, world_start, &.{
        .{ .path = "params.context.name", .equals = utility_world },
        .{ .path = "params.context.auxData.isDefault", .equals = "false" },
        .{ .path = "params.context.auxData.type", .equals = "isolated" },
        .{ .path = "params.context.auxData.frameId", .equals = target_id },
    }) orelse return error.NoUtilityContext;
    try testing.expect(utility_created < world_reply);
    const utility_context = cdp.at(rec.at(utility_created), "params.context.id").?.integer;
    try testing.expectEqual(utility_context, cdp.at(try rec.result(world), "executionContextId").?.integer);
    try testing.expect(utility_context != main_context);

    return .{
        .target_id = target_id,
        .session = session,
        .context_id = context_id,
        .window_id = window_id,
        .first_loader = first_loader,
        .main_context = main_context,
        .utility_context = utility_context,
    };
}

/// Runtime.evaluate of `expression` (JSON-escaped already) in context
/// `context_id`, by value: the result's string value, OWNED.
fn evaluateString(rec: *replay.Recorder, allocator: std.mem.Allocator, session: []const u8, context_id: i64, expression: []const u8) ![]u8 {
    var buffer: [1024]u8 = undefined;
    const id = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"{s}\",\"contextId\":{d},\"returnByValue\":true}}", .{ expression, context_id }), session);
    const r = try rec.result(id);
    if (cdp.at(r, "exceptionDetails") != null) return error.EvaluationThrew;
    return replay.dupeAt(allocator, r, "result.value");
}

/// Target.disposeBrowserContext ends the test's context: the page's session
/// detaches, announced before the reply (svelte log l.132-133).
fn disposeContext(fx: *replay.Fixture, page: *const Page) !void {
    const rec = &fx.rec;
    var buffer: [128]u8 = undefined;
    const start = rec.log.items.len;
    const dispose = try rec.send("Target.disposeBrowserContext", try std.fmt.bufPrint(&buffer, "{{\"browserContextId\":\"{s}\"}}", .{page.context_id}), "");
    const reply = try rec.awaitResponse(dispose);
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(dispose));
    const detached = rec.eventIndex("Target.detachedFromTarget", "", start, &.{
        .{ .path = "params.sessionId", .equals = page.session },
        .{ .path = "params.targetId", .equals = page.target_id },
    }) orelse return error.NotDetached;
    try testing.expect(detached < reply);
}

test "Playwright: launch over CDP, a new context and page, the page's initialisation in Chrome 157's order, the context's disposal" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    allocator.free(try connect(fx, allocator));
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    try disposeContext(fx, &page);
}

test "Playwright page.setContent (Svelte's harness): document.open/write/close in the utility world - the console tag, then DOMContentLoaded and load; Chrome's documentOpened and init at the open (G6)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    allocator.free(try connect(fx, allocator));
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    // frames.ts setContent: in the utility world, with its tag logged
    // between the open and the write (svelte log l.118-126).
    const tag = "--playwright--set--content--148052d2e58407979576c72bc54a9185--";
    const start = rec.log.items.len;
    var buffer: [512]u8 = undefined;
    const set = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"(() => {{ document.open(); console.debug('" ++ tag ++ "'); document.write('<p id=x>set</p>'); document.close(); }})()\",\"contextId\":{d},\"awaitPromise\":true}}", .{page.utility_context}), page.session);
    _ = try rec.result(set);

    // The tag, from the utility world's context.
    const logged = try rec.awaitEvent("Runtime.consoleAPICalled", page.session, start, &.{.{ .path = "params.type", .equals = "debug" }});
    const message = rec.at(logged);
    try testing.expectEqual(page.utility_context, cdp.at(message, "params.executionContextId").?.integer);
    const args = cdp.at(message, "params.args").?.array.items;
    try testing.expectEqualStrings(tag, cdp.stringAt(args[0], "value").?);

    // What setContent waits for once its tag came: DOMContentLoaded and
    // load of the frame, after the tag (Playwright clears the frame's
    // lifecycle at the tag), each after its Page event as Chrome sends them.
    const dcl = try rec.awaitEvent("Page.lifecycleEvent", page.session, logged, &.{
        .{ .path = "params.name", .equals = "DOMContentLoaded" },
        .{ .path = "params.frameId", .equals = page.target_id },
    });
    const load = try rec.awaitEvent("Page.lifecycleEvent", page.session, dcl, &.{
        .{ .path = "params.name", .equals = "load" },
        .{ .path = "params.frameId", .equals = page.target_id },
    });
    const dcl_fired = rec.eventIndex("Page.domContentEventFired", page.session, logged, &.{}) orelse return error.NoDomContentEventFired;
    try testing.expect(dcl_fired < dcl);
    const load_fired = rec.eventIndex("Page.loadEventFired", page.session, dcl, &.{}) orelse return error.NoLoadEventFired;
    try testing.expect(load_fired < load);

    // G6 - Chrome at the open (l.119-120): Page.documentOpened for the frame,
    // then lifecycle init with the document's loaderId, both before the tag.
    const opened = rec.eventIndex("Page.documentOpened", page.session, start, &.{.{ .path = "params.frame.id", .equals = page.target_id }}) orelse return error.NoDocumentOpened;
    const init = rec.eventIndex("Page.lifecycleEvent", page.session, start, &.{
        .{ .path = "params.name", .equals = "init" },
        .{ .path = "params.frameId", .equals = page.target_id },
    }) orelse return error.NoInitAtOpen;
    try testing.expect(opened < init);
    try testing.expect(init < logged);

    // The page has the content (Svelte's evaluate, in the main world).
    const text = try evaluateString(rec, allocator, page.session, page.main_context, "document.getElementById('x').textContent");
    defer allocator.free(text);
    try testing.expectEqualStrings("set", text);
    try disposeContext(fx, &page);
}

test "Playwright page.goto (htmx, React, Vue browser mode): one loaderId for the navigation in Page and Network (G3), Chrome's commit order, the subresource's loaderId, the named frame" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    allocator.free(try connect(fx, allocator));
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    var url_buffer: [96]u8 = undefined;
    const url = try site.url(&url_buffer, "/");
    var buffer: [256]u8 = undefined;
    const start = rec.log.items.len;
    const navigate = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\",\"frameId\":\"{s}\",\"referrerPolicy\":\"unsafeUrl\"}}", .{ url, page.target_id }), page.session);
    const reply = try rec.awaitResponse(navigate);
    const r = try rec.result(navigate);
    try testing.expectEqualStrings(page.target_id, cdp.stringAt(r, "frameId").?);
    try testing.expect(cdp.at(r, "errorText") == null);
    const loader = cdp.stringAt(r, "loaderId") orelse return error.NoLoaderId;
    try testing.expectEqual(@as(usize, 32), loader.len);
    try testing.expect(!std.mem.eql(u8, loader, page.first_loader));

    // The navigation request (htmx log l.155-189): Network names it by the
    // navigation's loaderId - requestId == loaderId == Page.navigate's
    // (G3: Playwright's frameCommittedNewDocumentNavigation matches the
    // pending request by it; Puppeteer's isNavigationRequest too).
    const sent = rec.eventIndex("Network.requestWillBeSent", page.session, start, &.{
        .{ .path = "params.type", .equals = "Document" },
        .{ .path = "params.frameId", .equals = page.target_id },
    }) orelse return error.NoNavigationRequest;
    const s = rec.at(sent);
    try testing.expectEqualStrings(url, cdp.stringAt(s, "params.request.url").?);
    try testing.expectEqualStrings(loader, cdp.stringAt(s, "params.requestId").?);
    try testing.expectEqualStrings(loader, cdp.stringAt(s, "params.loaderId").?);
    try testing.expect(sent < reply);
    // Chrome answers Page.navigate once the response is in (ready to
    // commit): after responseReceived, before frameNavigated.
    const received = rec.eventIndex("Network.responseReceived", page.session, sent, &.{.{ .path = "params.requestId", .equals = loader }}) orelse return error.NoResponseReceived;
    try testing.expect(received < reply);
    try testing.expectEqual(@as(i64, 200), cdp.at(rec.at(received), "params.response.status").?.integer);
    try testing.expect(!cdp.at(rec.at(received), "params.hasExtraInfo").?.bool);

    // The commit: executionContextsCleared, lifecycle init, frameNavigated,
    // then the new document's contexts - main and utility (l.190-207).
    const navigated = try rec.awaitEvent("Page.frameNavigated", page.session, reply, &.{
        .{ .path = "params.frame.id", .equals = page.target_id },
        .{ .path = "params.frame.loaderId", .equals = loader },
    });
    try testing.expectEqualStrings(url, cdp.stringAt(rec.at(navigated), "params.frame.url").?);
    try testing.expectEqualStrings("Navigation", cdp.stringAt(rec.at(navigated), "params.type").?);
    const cleared = rec.eventIndex("Runtime.executionContextsCleared", page.session, reply, &.{}) orelse return error.NotCleared;
    try testing.expect(cleared < navigated);
    const init = rec.eventIndex("Page.lifecycleEvent", page.session, start, &.{
        .{ .path = "params.name", .equals = "init" },
        .{ .path = "params.loaderId", .equals = loader },
    }) orelse return error.NoInit;
    try testing.expect(init < navigated);
    const main_created = try rec.awaitEvent("Runtime.executionContextCreated", page.session, navigated, &.{
        .{ .path = "params.context.auxData.isDefault", .equals = "true" },
        .{ .path = "params.context.auxData.frameId", .equals = page.target_id },
    });
    const main_context = cdp.at(rec.at(main_created), "params.context.id").?.integer;
    _ = try rec.awaitEvent("Runtime.executionContextCreated", page.session, navigated, &.{
        .{ .path = "params.context.name", .equals = utility_world },
        .{ .path = "params.context.auxData.frameId", .equals = page.target_id },
    });

    // The document's lifecycle, each Page event before its lifecycleEvent,
    // then frameStoppedLoading (seq-vue-e2e-one.txt).
    const dcl = try rec.awaitEvent("Page.lifecycleEvent", page.session, navigated, &.{
        .{ .path = "params.name", .equals = "DOMContentLoaded" },
        .{ .path = "params.frameId", .equals = page.target_id },
        .{ .path = "params.loaderId", .equals = loader },
    });
    const load = try rec.awaitEvent("Page.lifecycleEvent", page.session, dcl, &.{
        .{ .path = "params.name", .equals = "load" },
        .{ .path = "params.frameId", .equals = page.target_id },
        .{ .path = "params.loaderId", .equals = loader },
    });
    try testing.expect((rec.eventIndex("Page.domContentEventFired", page.session, navigated, &.{}) orelse return error.NoDomContentEventFired) < dcl);
    try testing.expect((rec.eventIndex("Page.loadEventFired", page.session, dcl, &.{}) orelse return error.NoLoadEventFired) < load);
    _ = try rec.awaitEvent("Page.frameStoppedLoading", page.session, load, &.{.{ .path = "params.frameId", .equals = page.target_id }});

    // The subresource: its document's loaderId (G3), its type, its frame.
    const script = rec.eventIndex("Network.requestWillBeSent", page.session, navigated, &.{.{ .path = "params.type", .equals = "Script" }}) orelse return error.NoScriptRequest;
    try testing.expectEqualStrings(loader, cdp.stringAt(rec.at(script), "params.loaderId").?);
    try testing.expectEqualStrings(page.target_id, cdp.stringAt(rec.at(script), "params.frameId").?);
    try testing.expect(std.mem.endsWith(u8, cdp.stringAt(rec.at(script), "params.request.url").?, "/app.js"));

    // The named frame (Vue browser mode's page.frame("vitest-iframe")):
    // attached under the page, then navigated with its name and parent,
    // then its main world's context.
    const frame_attached = rec.eventIndex("Page.frameAttached", page.session, start, &.{.{ .path = "params.parentFrameId", .equals = page.target_id }}) orelse return error.NoFrameAttached;
    const frame_id = try replay.dupeAt(allocator, rec.at(frame_attached), "params.frameId");
    defer allocator.free(frame_id);
    const frame_navigated = try rec.awaitEvent("Page.frameNavigated", page.session, frame_attached, &.{
        .{ .path = "params.frame.id", .equals = frame_id },
        .{ .path = "params.frame.parentId", .equals = page.target_id },
        .{ .path = "params.frame.name", .equals = "vitest-iframe" },
    });
    _ = try rec.awaitEvent("Runtime.executionContextCreated", page.session, frame_navigated, &.{
        .{ .path = "params.context.auxData.isDefault", .equals = "true" },
        .{ .path = "params.context.auxData.frameId", .equals = frame_id },
    });

    // The page ran its script, in its new main world.
    const text = try evaluateString(rec, allocator, page.session, main_context, "(window.appRan ? 'ran:' : 'no:') + document.getElementById('x').textContent");
    defer allocator.free(text);
    try testing.expectEqualStrings("ran:hello", text);
    try disposeContext(fx, &page);
}

test "Playwright same-document goto and the frame owner (React): no loaderId, navigatedWithinDocument; DOM.getFrameOwner and describeNode name the frame" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    allocator.free(try connect(fx, allocator));
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    var url_buffer: [96]u8 = undefined;
    var buffer: [256]u8 = undefined;
    const start = rec.log.items.len;
    const first = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\",\"frameId\":\"{s}\",\"referrerPolicy\":\"unsafeUrl\"}}", .{ try site.url(&url_buffer, "/"), page.target_id }), page.session);
    _ = try rec.result(first);
    const load = try rec.awaitEvent("Page.lifecycleEvent", page.session, start, &.{
        .{ .path = "params.name", .equals = "load" },
        .{ .path = "params.frameId", .equals = page.target_id },
    });
    const frame_attached = rec.eventIndex("Page.frameAttached", page.session, start, &.{.{ .path = "params.parentFrameId", .equals = page.target_id }}) orelse return error.NoFrameAttached;
    const frame_id = try replay.dupeAt(allocator, rec.at(frame_attached), "params.frameId");
    defer allocator.free(frame_id);

    // React's page.goto('/#abc') (react log l.1074-1079): answered at once
    // with no loaderId, then navigatedWithinDocument.
    const fragment_url = try site.url(&url_buffer, "/#abc");
    const same = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\",\"frameId\":\"{s}\",\"referrerPolicy\":\"unsafeUrl\"}}", .{ fragment_url, page.target_id }), page.session);
    const r = try rec.result(same);
    try testing.expect(cdp.at(r, "loaderId") == null);
    try testing.expect(cdp.at(r, "errorText") == null);
    const within = try rec.awaitEvent("Page.navigatedWithinDocument", page.session, load, &.{
        .{ .path = "params.frameId", .equals = page.target_id },
        .{ .path = "params.navigationType", .equals = "fragment" },
    });
    try testing.expectEqualStrings(fragment_url, cdp.stringAt(rec.at(within), "params.url").?);

    // React's frame locator: the frame's owner element, by backendNodeId
    // (react log l.154/172), described with its frame.
    const owner = try rec.send("DOM.getFrameOwner", try std.fmt.bufPrint(&buffer, "{{\"frameId\":\"{s}\"}}", .{frame_id}), page.session);
    const backend = cdp.at(try rec.result(owner), "backendNodeId").?.integer;
    const described = try rec.send("DOM.describeNode", try std.fmt.bufPrint(&buffer, "{{\"backendNodeId\":{d}}}", .{backend}), page.session);
    const d = try rec.result(described);
    try testing.expectEqualStrings("IFRAME", cdp.stringAt(d, "node.nodeName").?);
    try testing.expectEqualStrings("iframe", cdp.stringAt(d, "node.localName").?);
    try testing.expectEqual(@as(i64, 1), cdp.at(d, "node.nodeType").?.integer);
    try testing.expectEqual(backend, cdp.at(d, "node.backendNodeId").?.integer);
    try testing.expectEqualStrings(frame_id, cdp.stringAt(d, "node.frameId").?);
    try disposeContext(fx, &page);
}

test "Playwright context with a locale (React's configs): setUserAgentOverride {userAgent: \"\"} keeps Crane's user agent and sets the language (G4); setLocaleOverride en-US succeeds" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const user_agent = try connect(fx, allocator);
    defer allocator.free(user_agent);
    var page = try newPage(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    // crPage.ts _updateUserAgent / _updateLocale with only `locale` set
    // (react log l.82-83, l.119-120).
    const ua = try rec.send("Emulation.setUserAgentOverride", "{\"userAgent\":\"\",\"acceptLanguage\":\"en-US\"}", page.session);
    const locale = try rec.send("Emulation.setLocaleOverride", "{\"locale\":\"en-US\"}", page.session);
    try rec.awaitAll(&.{ ua, locale });
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(ua));
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(locale));

    // An empty userAgent is no user agent override (Chrome's
    // EmulationHandler sets the header only for a non-empty one); the
    // language is.
    const navigator_ua = try evaluateString(rec, allocator, page.session, page.main_context, "navigator.userAgent");
    defer allocator.free(navigator_ua);
    try testing.expectEqualStrings(user_agent, navigator_ua);
    const language = try evaluateString(rec, allocator, page.session, page.main_context, "navigator.language");
    defer allocator.free(language);
    try testing.expectEqualStrings("en-US", language);
    try disposeContext(fx, &page);
}
