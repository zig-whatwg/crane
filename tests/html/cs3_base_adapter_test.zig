//! Exercise the host adapter before the base-freezing owner connects it.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");
const fetch = @import("fetch");
const dom = @import("dom");
const testing = std.testing;

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body></body>", .{ .base_url = "https://example.test/page" });
    _ = try browser.runEventLoopBlocking(20);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const held_document = try page.evaluateScript("document");
    defer held_document.release();
    const document = engine.convertToPlatformObject(realm, held_document.value) orelse return error.NoDocument;
    const base = "https://other.test/base?q#fragment";

    try testing.expect(dom.csp_violations.isBaseAllowedForDocument(document, base));
    try page.runScript(
        \\window.baseReports = [];
        \\document.addEventListener('securitypolicyviolation', e => baseReports.push({
        \\  directive: e.effectiveDirective, blocked: e.blockedURI,
        \\  disposition: e.disposition, target: e.target === document
        \\}));
    );
    dom.policy_containers.set(document, try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
        .url = "https://example.test/page",
        .csp_report_only = "base-uri 'none'",
    }));
    try testing.expect(dom.csp_violations.isBaseAllowedForDocument(document, base));
    // The queued report must own its metadata even after its policy goes.
    dom.policy_containers.set(document, try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
        .url = "https://example.test/page",
        .csp = "base-uri 'none'",
        .csp_report_only = "base-uri 'none'",
    }));
    try testing.expect(!dom.csp_violations.isBaseAllowedForDocument(document, base));
    _ = try browser.runEventLoopBlocking(20);
    const actual = try page.evaluateScriptToString(
        \\JSON.stringify(baseReports.map(e => [e.directive, e.blocked, e.disposition, e.target]))
    , testing.allocator);
    defer testing.allocator.free(actual);
    try testing.expectEqualStrings(
        "[[\"base-uri\",\"https://other.test/base?q\",\"report\",true],[\"base-uri\",\"https://other.test/base?q\",\"enforce\",true],[\"base-uri\",\"https://other.test/base?q\",\"report\",true]]",
        actual,
    );
}

test "base-uri host adapter reports to its document and preserves policy dispositions" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
