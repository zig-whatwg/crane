//! XHR handle-errors step 1 ignores completed requests during document abort.
const std = @import("std");
const browser_mod = @import("browser");

const Scenario = enum { head_load, head_progress, data_load, data_loadend, network_error };

fn exercise(scenario: Scenario) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
    const setup = try std.fmt.allocPrint(std.testing.allocator,
        \\globalThis.events = [];
        \\globalThis.stoppedDuringProgress = false;
        \\globalThis.request = new XMLHttpRequest();
        \\request.open('{s}', '{s}');
        \\for (const type of ['load', 'loadend', 'error', 'abort'])
        \\  request.addEventListener(type, () => {{
        \\    events.push(type);
        \\    if (type === '{s}') window.stop();
        \\  }});
        \\request.addEventListener('readystatechange', () => {{
        \\  if (request.readyState === 4) events.push('readystatechange(4)');
        \\}});
        \\request.onprogress = () => {{ if ({s}) {{ stoppedDuringProgress = true; window.stop(); }} }};
        \\request.send();
    , .{
        if (scenario == .head_load or scenario == .head_progress) "HEAD" else "GET",
        if (scenario == .network_error) "http://127.0.0.1:65533/refused" else "data:text/plain,completed",
        if (scenario == .network_error) "error" else if (scenario == .data_loadend) "loadend" else "load",
        if (scenario == .head_progress) "true" else "false",
    });
    defer std.testing.allocator.free(setup);
    try page.runScript(setup);
    _ = try browser.runEventLoopBlocking(2000);
    const verify = try std.fmt.allocPrint(std.testing.allocator,
        \\if (stoppedDuringProgress !== {s}) throw new Error('progress stop was not reached');
        \\if (events.join(',') !== 'readystatechange(4),{s},loadend')
        \\  throw new Error('terminal events repeated or missing: ' + events.join(','));
        \\if (request.readyState !== 4 || request.status !== {d})
        \\  throw new Error('completed response was changed by queued document abort');
    , .{ if (scenario == .head_progress) "true" else "false", if (scenario == .network_error) "error" else "load", @as(u16, if (scenario == .network_error) 0 else 200) });
    defer std.testing.allocator.free(verify);
    try page.runScript(verify);
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

test "document stop from HEAD load preserves completed response and terminal events" {
    try check(.head_load);
}
test "document stop from data load preserves completed response and terminal events" {
    try check(.data_load);
}
test "document stop from data loadend does not dispatch a second loadend" {
    try check(.data_loadend);
}
test "document stop from network error does not dispatch a subsequent abort" {
    try check(.network_error);
}

test "queued abort rechecks send flag after terminal progress completes the request" {
    try check(.head_progress);
}
