//! Removing a load delay must not enter parser script on the caller's stack.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");

const Scenario = enum { iframe_removal, resource_undelay, load_recheck };

fn exercise(scenario: Scenario) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
    try page.runScript(
        \\globalThis.order = [];
        \\document.open();
        \\document.write("<!doctype html><body><iframe id='child'></iframe>" +
        \\  "<link id='sheet' rel='stylesheet' href='http://127.0.0.1:65533/pending.css'>" +
        \\  "<script>order.push('parser')<\/script>");
        \\if (order.length !== 0) throw new Error('stylesheet did not block parser');
    );
    const document = page.document_instance orelse return error.TestUnexpectedResult;
    try std.testing.expect(dom.document_scripts.of(document).?.pending_parsing_blocking_script != null);
    if (scenario == .resource_undelay) dom.document_lifecycle.delayLoadEvent(document);
    try page.runScript("document.getElementById('sheet').remove()");
    switch (scenario) {
        .iframe_removal => try page.runScript("document.getElementById('child').remove()"),
        .resource_undelay => dom.document_lifecycle.undelayLoadEvent(document),
        .load_recheck => dom.document_lifecycle.loadDelayMayHaveEnded(document),
    }
    try page.runScript(
        \\order.push('after');
        \\if (order.join(',') !== 'after') throw new Error('parser resumed in synchronous undelay: ' + order);
    );
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\if (order.join(',') !== 'after,parser') throw new Error('queued parser did not resume: ' + order);
        \\document.close();
    );
}

fn check(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise(self.scenario) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "iframe removal queues a waiting parser resume after the DOM operation" {
    try check(.iframe_removal);
}
test "resource undelay queues a waiting parser resume after the caller returns" {
    try check(.resource_undelay);
}
test "load delay recheck queues a waiting parser resume after the caller returns" {
    try check(.load_recheck);
}
