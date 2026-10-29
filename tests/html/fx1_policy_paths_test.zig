//! Policy construction keeps every existing iframe document-creation path.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const dom = @import("dom");

fn script(browser: *browser_mod.Browser, source: []const u8) !void {
    const result = try browser.evaluateScript(source);
    result.release();
}

fn waitFor(browser: *browser_mod.Browser, predicate: []const u8) !void {
    for (0..500) |_| {
        const result = try browser.evaluateScript(predicate);
        const done = engine.toBoolean(browser.getRealm() orelse return error.NoRealm, result.borrow());
        result.release();
        if (done) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.ChildDocumentDidNotArrive;
}

fn expectPolicy(browser: *browser_mod.Browser, enabled: bool) !void {
    const parent = browser.current_context.?.document_instance.?;
    const frame = (try interfaces.Document.call_getElementById(parent, .initInterned("fx1-frame"))) orelse return error.NoFrame;
    const child = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoChildDocument;
    const origin = (try dom.document_origin.shareable(child)) orelse return error.NoChildOrigin;
    const parent_origin = (try dom.document_origin.shareable(parent)) orelse return error.NoParentOrigin;
    try std.testing.expect(dom.origin_record.sameOrigin(.{ .serialized = origin.serialized.?, .record = origin }, .{ .serialized = parent_origin.serialized.?, .record = parent_origin }));
    const policies = dom.policy_containers.permissionsOf(child) orelse return error.NoPolicy;
    const result = try policies.check(.deferred_fetch, .{ .serialized = origin.serialized.?, .record = origin });
    try std.testing.expectEqual(enabled, result.enabled);
}

fn run() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const url = "https://fx1.test/policy-parent";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = url });

    // Initial about:blank inherits the actual allow attribute at creation.
    try script(browser,
        \\globalThis.fx1Frame = document.createElement('iframe');
        \\fx1Frame.id = 'fx1-frame';
        \\fx1Frame.allow = "deferred-fetch 'none'";
        \\document.body.append(fx1Frame);
    );
    try expectPolicy(browser, false);
    try script(browser, "fx1Frame.allow = 'deferred-fetch *'");
    try expectPolicy(browser, false); // no retroactive policy mutation

    // A src navigation exercises the fetched-document factory without an
    // external server; a blob URL carries its creator's same-origin identity.
    try script(browser,
        \\globalThis.fx1Blob = URL.createObjectURL(new Blob(['<!doctype html><p id=src-loaded>src</p>'], {type: 'text/html'}));
        \\fx1Frame.src = fx1Blob;
    );
    try waitFor(browser, "!!fx1Frame.contentDocument?.getElementById('src-loaded')");
    try expectPolicy(browser, true);
    try script(browser, "URL.revokeObjectURL(fx1Blob); fx1Frame.allow = \"deferred-fetch 'none'\"; fx1Frame.srcdoc = '<p id=srcdoc-loaded>srcdoc</p>'");
    try waitFor(browser, "!!fx1Frame.contentDocument?.getElementById('srcdoc-loaded')");
    try expectPolicy(browser, false);

    // Re-insertion makes a fresh initial document and navigates from srcdoc.
    try script(browser, "fx1Frame.remove(); fx1Frame.allow = 'deferred-fetch *'; document.body.append(fx1Frame)");
    try waitFor(browser, "!!fx1Frame.contentDocument?.getElementById('srcdoc-loaded')");
    try expectPolicy(browser, true);

    // A javascript: result replaces the document using the initiator origin.
    try script(browser,
        \\fx1Frame.removeAttribute('srcdoc');
        \\fx1Frame.allow = "deferred-fetch 'none'";
        \\fx1Frame.src = 'javascript:"<!doctype html><p id=javascript-loaded>js</p>"';
    );
    try waitFor(browser, "!!fx1Frame.contentDocument?.getElementById('javascript-loaded')");
    try expectPolicy(browser, false);
}

test "permissions policy preserves initial, src, srcdoc, reinserted and javascript iframe documents" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn start(out: *anyerror!void) void {
            out.* = run();
        }
    }.start, .{&result});
    thread.join();
    try result;
}
