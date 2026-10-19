//! Three policy-container reads that answered "no restriction" when they
//! could not read the policy (lane leaks6, item 5; lanes leaks4 and leaks5's
//! follow-ups). Not knowing the policy is not "no policy": each now answers
//! the closed value.
//!
//! - dom.sandboxing.cspDerivedSandboxingFlags read only a list's policies, so
//!   an unenforceable list (a policy that could not be recorded, or
//!   CSPList.unavailable) derived NO sandboxing flags - unlike
//!   csp.directives.sandbox's getCombinedSandboxFlags, which answers every
//!   restriction for it.
//! - Nonce hiding (HTML 2.5.6, an HTML or SVG element becoming browsing
//!   context connected) skipped a document whose list it could not trust:
//!   one with no policy container (`orelse return`), or an unenforceable one
//!   (it has no header policy recorded). Hiding is the closed answer.
//! - html.worker_host.creatorPolicyContainer answered null for a creator
//!   realm with no realm record, global or settings - and a data: or blob:
//!   worker then got an empty container (no CSP), its script fetch no client
//!   container. It answers PolicyContainer.unavailable now.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const fetch = @import("fetch");
const html = @import("html");
const Browser = @import("browser").Browser;

const unavailable = &fetch.internal.PolicyContainer.unavailable;

test "leaks6 fail closed: an unenforceable CSP list derives every sandboxing flag" {
    const sandboxing = dom.sandboxing;
    // What `sandbox` with no keyword sets: every restriction a directive can.
    const every = sandboxing.parseSandboxingDirective("");
    try testing.expect(!every.isEmpty());
    try testing.expect(sandboxing.cspDerivedSandboxingFlags(&unavailable.csp_list).eql(every));
}

test "leaks6 fail closed: a worker creator realm with no realm record answers the unavailable container" {
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    try testing.expect(context.getRealm() == null);
    const container = html.worker_host.creatorPolicyContainer(&context) orelse return error.NoContainer;
    try testing.expect(container.csp_list.blocksEverything());
}

const page_url = "https://leaks6.test/page.html";

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn answer(realm: runtime.Context, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport });
}

fn expectAnswer(realm: runtime.Context, source: []const u8, want: []const u8) !void {
    const got = try answer(realm, source);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(want, got);
}

const insert_html =
    \\(() => { const d = document.createElement('div'); d.setAttribute('nonce', 'abc'); document.body.append(d); return d.getAttribute('nonce') + '|' + d.nonce; })()
;
const insert_svg =
    \\(() => { const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); s.setAttribute('nonce', 'abc'); document.body.append(s); return s.getAttribute('nonce'); })()
;

fn nonceHiding() !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer if (debug.deinit() == .leak) @panic("leaked");
    const browser = try Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    const realm = browser.getRealm() orelse return error.NoRealm;

    // The control: no header-delivered policy, so the nonce stays visible.
    try expectAnswer(realm, insert_html, "abc|abc");
    // Crane's SVG elements have no nonce IDL attribute yet: the content
    // attribute alone says whether it was hidden.
    try expectAnswer(realm, insert_svg, "abc");

    // The document's list can no longer be trusted.
    const owned = try page.evaluateScript("document");
    defer owned.release();
    const document = engine.convertToPlatformObject(realm, owned.value) orelse return error.NoDocument;
    const container = dom.policy_containers.of(document) orelse return error.NoContainer;
    container.csp_list.unenforceable = true;
    defer container.csp_list.unenforceable = false;

    // Hidden: the content attribute is emptied, the internal slot kept.
    try expectAnswer(realm, insert_html, "|abc");
    try expectAnswer(realm, insert_svg, "");
}

test "leaks6 fail closed: nonce hiding hides the nonce in a document whose CSP list cannot be trusted" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            nonceHiding() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
