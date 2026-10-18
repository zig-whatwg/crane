//! A CSP decision that cannot find the policy container it is made against
//! is "Blocked": not knowing a global's policies is not having none.
//!
//! The containers are reached through two hooks: dom.policy_containers (a
//! Document's) and a global's settings object (a Window's is its document's).
//! Each answered null when the container could not be found - a Window with
//! no document, a Document with no internal state - and every host read null
//! as "nothing to check" (`orelse return false`, `orelse return .allowed`, a
//! request left on "client"): lane leaks4's report found a frame's Document
//! with no internal state during an out-of-memory sweep, whose checks then
//! allowed everything. Now the Window's settings answer the static
//! fetch.internal.PolicyContainer.unavailable and dom.csp_violations reads a
//! missing Document container as csp.CSPList.unavailable: an empty,
//! unenforceable list, against which src/csp's every entry point is Blocked.
//!
//! The global whose container cannot be found is a Window with no document
//! (interfaces.Window.init in the page's realm, never given one); the
//! control is the page's own Window, whose document has an empty policy
//! container: everything is allowed there. Each pair is one decision host:
//! the global's CSP list (eval, Function, wasm and Trusted Types read it),
//! html.code_generation's eval check, main fetch's request check through
//! "populate request from client", the target's javascript: URL check, and
//! dom.csp_violations' document list.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const fetch = @import("fetch");

fn pageWindow(page: anytype, realm: runtime.Context) !*runtime.Instance {
    const owned = try page.evaluateScript("window");
    defer owned.release();
    return engine.convertToPlatformObject(realm, owned.value) orelse error.NoWindow;
}

fn pageDocument(page: anytype, realm: runtime.Context) !*runtime.Instance {
    const owned = try page.evaluateScript("document");
    defer owned.release();
    return engine.convertToPlatformObject(realm, owned.value) orelse error.NoDocument;
}

/// Main fetch step 7 for a request whose client is `global`: populated from
/// the global's settings object, as fetch() populates one.
fn requestBlocked(global: *runtime.Instance) !bool {
    const allocator = testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "https://example.test/image.png");
    defer request.deinit();
    var client = try dom.global_settings.requestClient(global);
    defer client.deinit();
    try fetch.internal.populateRequestFromClient(request, client.request);
    return fetch.algorithms.csp_check.shouldRequestBeBlocked(request);
}

fn exercise() !void {
    const allocator = testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body></body>", .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    const realm = browser.getRealm() orelse return error.NoRealm;

    const window = try pageWindow(page, realm);
    const document = try pageDocument(page, realm);
    // A Window whose document cannot be found: one never given a document.
    const orphan = try interfaces.Window.init(allocator, realm);
    defer interfaces.Window.deinit(orphan);

    // The global's CSP list - what eval, Function, wasm and the Trusted
    // Types checks read (dom.trusted_types.cspListOf).
    {
        const control = dom.trusted_types.cspListOf(window) orelse return error.NoList;
        try testing.expect(control.isEmpty());
        const missing = dom.trusted_types.cspListOf(orphan) orelse return error.MissingListAllowsEverything;
        try testing.expect(!missing.isEmpty());
        try testing.expect(missing.blocksEverything());
    }
    // eval (html.code_generation, CSP 4.4.1): allowed, then blocked.
    try testing.expectEqual(html.code_generation.Result.allowed, html.code_generation.ensureCSPDoesNotBlockStringCompilation(window, "1 + 1", .eval, false));
    try testing.expectEqual(html.code_generation.Result.blocked, html.code_generation.ensureCSPDoesNotBlockStringCompilation(orphan, "1 + 1", .eval, false));
    // A Trusted Types sink requires trusted types against a list that fails
    // closed (CSP require-trusted-types-for).
    try testing.expect(!dom.trusted_types.doesSinkTypeRequireTrustedTypes(window, dom.trusted_types.script_sink_group, true));
    try testing.expect(dom.trusted_types.doesSinkTypeRequireTrustedTypes(orphan, dom.trusted_types.script_sink_group, true));
    // A request (main fetch step 7, through "populate request from
    // client" step 3's clone of the settings object's container).
    try testing.expect(!try requestBlocked(window));
    try testing.expect(try requestBlocked(orphan));
    // The target's javascript: URL check (dom.csp_violations): a target
    // with no document fails closed.
    try testing.expect(!dom.csp_violations.shouldTargetBlockJavascriptUrl(window, "javascript:void 0"));
    try testing.expect(dom.csp_violations.shouldTargetBlockJavascriptUrl(orphan, "javascript:void 0"));
    // A Document's list (dom.csp_violations.documentCspList, which the
    // inline check and the plugin check read): an instance with no
    // Document state - here a Window - has no container to find.
    try testing.expect(dom.csp_violations.documentCspList(document).isEmpty());
    try testing.expect(dom.csp_violations.documentCspList(orphan).blocksEverything());

    // The page itself still runs and loads everything: its own checks were
    // not changed by the orphan's.
    const got = try page.evaluateScriptToString("(() => { try { return String(eval('2')); } catch (e) { return e.constructor.name; } })()", allocator);
    defer allocator.free(got);
    try testing.expectEqualStrings("2", got);
}

test "a global or document whose policy container cannot be found is blocked; one with an empty container is not" {
    // A Browser of its own, on a thread of its own (tests/html shares one
    // process: no per-thread state from another file).
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
