//! document.open step 16 replaces parsers installed by steps 11-12 callbacks.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");

const Scenario = enum { current_entry_change, child_unload };

fn exercise(scenario: Scenario) !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/start" });
    const document = page.document_instance orelse return error.TestUnexpectedResult;
    try page.runScript(
        \\globalThis.reentrantOpens = 0;
        \\globalThis.reenterOpen = () => {
        \\  if (reentrantOpens++) return;
        \\  document.open();
        \\};
    );
    switch (scenario) {
        .current_entry_change => try page.runScript(
            \\if (!navigation.currentEntry) throw new Error('missing current entry');
            \\navigation.oncurrententrychange = () => reenterOpen();
        ),
        .child_unload => try page.runScript(
            \\globalThis.child = document.body.appendChild(document.createElement('iframe'));
            \\child.contentWindow.onunload = () => reenterOpen();
        ),
    }
    try page.runScript(
        \\document.open();
        \\if (reentrantOpens === 0) throw new Error('reentrant callback was not reached');
        \\document.write('<p id="outer">outer</p>');
        \\if (document.getElementById('outer')?.textContent !== 'outer')
        \\  throw new Error('outer stream cannot continue');
        \\document.close();
    );
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    // std.testing.allocator catches the nested parser overwritten at step 16.
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

test "document.open replaces a parser installed by currententrychange" {
    try check(.current_entry_change);
}

test "document.open replaces a parser installed by child unload" {
    try check(.child_unload);
}
