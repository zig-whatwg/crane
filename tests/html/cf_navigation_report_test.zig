const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");

fn capture(allocator: std.mem.Allocator, sender: *runtime.Instance, container: *fetch.internal.PolicyContainer) !void {
    const previous = sender.ctx.allocator;
    sender.ctx.allocator = allocator;
    defer sender.ctx.allocator = previous;
    for (container.csp_list.policies.items) |*policy| {
        // A bare realm has no loop: construct the complete owned snapshot,
        // then drop it. No network operation or event is allowed here.
        try dom.csp_violations.reportNavigationResponse(sender, &.{
            .policy = policy,
            .effective_directive = "frame-ancestors",
            .resource = .{ .url = "https://child.test/path#fragment" },
        }, .{
            .url = "https://child.test/path#fragment",
            .referrer = "https://parent.test/ref#private",
            .status = 403,
            .endpoints = container.endpoints,
        });
    }
}

test "navigation response reporting copies and releases legacy and modern snapshots, including OOM" {
    const a = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const sender = try interfaces.Window.init(a, &ctx);
    defer interfaces.Window.deinit(sender);
    var container = try fetch.internal.PolicyContainer.fromResponseHeaders(a, .{
        .url = "https://child.test/path",
        .csp = "frame-ancestors 'none'; report-uri /legacy /second, frame-ancestors 'none'; report-to child",
        .reporting_endpoints = "child=\"https://child.test/modern\"",
    });
    defer container.deinit();
    try std.testing.checkAllAllocationFailures(a, capture, .{ sender, &container });
}
