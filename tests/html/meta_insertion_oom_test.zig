//! A `<meta http-equiv="Content-Security-Policy">` inserted into a document's
//! head out of memory still fails closed, whichever allocation fails: once
//! the element is in the head, its policy is in the document's CSP list, or
//! the list is unenforceable (csp.CSPList.unenforceable). Never neither.
//!
//! HTMLMetaElement's insertion steps read the http-equiv attribute with
//! `catch return`: a read that failed dropped the pragma - a policy among
//! them - without a word (lane leaks4's report). That read allocates nothing
//! for "http-equiv" (Element.getAttribute lowercases into a buffer), so no
//! allocation failure reaches it, and this sweep is a guard over the rest of
//! the insertion path: the element's insertion (DOM "insert" step 7.7 falls
//! back to a walk that allocates nothing), the referrer metadata name, the
//! Content Security Policy state's steps 1-2 and enforceMetaPolicy's 3-5
//! (tests/csp/meta_policy_fails_closed_test.zig sweeps those alone).
//!
//! Each round fails the i-th allocation of `document.head.appendChild(meta)`
//! for a meta element made beforehand, checks the document's list, then
//! takes the element out again and clears the flag for the next round.
//! The Browser's allocator is a FailingAllocator over c_allocator (an
//! out-of-memory path elsewhere may leak; that is not this test's).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const page_html =
    \\<!doctype html>
    \\<head></head>
    \\<body></body>
;

const prepare =
    \\(() => {
    \\  window.m = document.createElement("meta");
    \\  window.m.setAttribute("http-equiv", "Content-Security-Policy");
    \\  window.m.setAttribute("content", "img-src 'none'");
    \\  return "prepared";
    \\})()
;

fn expectScript(page: anytype, script: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("`{s}` answered {s}, expected {s}\n", .{ script, got, expected });
    try testing.expectEqualStrings(expected, got);
}

fn documentContainer(page: anytype, realm: runtime.Context) !*dom.policy_containers.PolicyContainer {
    const owned = try page.evaluateScript("document");
    defer owned.release();
    const document = engine.convertToPlatformObject(realm, owned.value) orelse return error.NoDocument;
    return dom.policy_containers.of(document) orelse error.NoContainer;
}

fn sweep(rounds: usize) !void {
    var failing = std.testing.FailingAllocator.init(std.heap.c_allocator, .{});
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(50);
    const realm = browser.getRealm() orelse return error.NoRealm;
    try expectScript(page, prepare, "prepared");
    const container = try documentContainer(page, realm);
    try testing.expectEqual(@as(usize, 0), container.csp_list.policies.items.len);

    var round: usize = 0;
    var failed_closed: usize = 0;
    var enforced: usize = 0;
    while (round < rounds) : (round += 1) {
        const before = container.csp_list.policies.items.len;
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round;
        page.runScript("document.head.appendChild(window.m);") catch {};
        failing.fail_index = std.math.maxInt(usize);
        const induced = failing.has_induced_failure;

        const inserted = try page.evaluateScriptToString("String(window.m.parentNode === document.head)", testing.allocator);
        defer testing.allocator.free(inserted);
        if (std.mem.eql(u8, inserted, "true")) {
            const after = container.csp_list.policies.items.len;
            if (container.csp_list.unenforceable) {
                failed_closed += 1;
            } else if (after == before + 1) {
                enforced += 1;
            } else {
                std.debug.print("failing allocation {d}: the meta element is in the head, and its policy is neither enforced nor failed closed ({d} -> {d} policies)\n", .{ round, before, after });
                if (induced) std.debug.dumpStackTrace(&failing.getStackTrace());
                return error.FailedOpen;
            }
        }
        // The next round inserts the element again, into a list that is
        // not unenforceable.
        container.csp_list.unenforceable = false;
        try expectScript(page, "(() => { window.m.remove(); return 'removed'; })()", "removed");
        // A sweep past the insertion's last allocation fails nothing.
        if (!induced) break;
    }
    // The sweep reached both outcomes, and the end of the insertion.
    try testing.expect(enforced > 0);
    try testing.expect(round < rounds);
}

test "a CSP meta element inserted out of memory is enforced or fails closed, never dropped" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(2000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
