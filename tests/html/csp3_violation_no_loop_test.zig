//! A loop-less realm must not start a report upload inside its violation finder.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");

fn makeWindow(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(std.testing.allocator, realm) catch null;
}

fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn exercise() !void {
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    // The agent's host, whose fetches a report upload would start on.
    var agent_host = @import("html_core").agent_host.AgentHost.init(allocator);
    defer agent_host.deinit();
    const agent = try engine.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .allocator = allocator,
        .hooks = &.{},
        .host = &agent_host,
    });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = allocator,
        .from_snapshot = false,
        .timer = null,
        .create_global_object = makeWindow,
    });
    defer {
        engine.destroyWindowRealm(realm, .global_detached);
        // Clean even the red run's unexpected upload after its client retires.
        _ = agent_host.fetches.sweep();
    }
    try std.testing.expect(realm.hasEngine());
    try std.testing.expect(realm.getOptionalEventLoop() == null);
    const global = dom.reporting.globalOf(realm) orelse return error.NoGlobal;
    try engine.runClassicScript(realm, .{ .utf8 =
        \\globalThis.violations = 0;
        \\addEventListener('securitypolicyviolation', () => { ++violations; });
    }, "csp3-no-loop.js", null, .{ .report = report });

    var container = try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://example.test/page",
        // An invalid network scheme completes synchronously inside FetchJob,
        // but AsyncFetch still remains in flight until its client is pumped.
        // This observes a start deterministically without network traffic.
        .csp = "style-src 'none'; report-uri data:application/csp-report,ignored",
    });
    defer container.deinit();
    const before = agent_host.fetches.inFlight();
    dom.csp_violations.reportViolation(global, &.{
        .policy = &container.csp_list.policies.items[0],
        .effective_directive = "style-src-attr",
        .resource = .@"inline",
    });
    const observed = try engine.evaluateClassicScript(realm, .{ .utf8 = "violations === 1" }, "csp3-no-loop-event.js", null, .{ .report = report });
    defer observed.release();
    try std.testing.expect(engine.toBoolean(realm, observed.value));
    try std.testing.expectEqual(before, agent_host.fetches.inFlight());
}

test "CSP violation without an event loop fires its event without starting AsyncFetch" {
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
