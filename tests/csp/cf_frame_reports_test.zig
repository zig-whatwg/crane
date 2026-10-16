const std = @import("std");
const csp = @import("csp");

test "navigation response reports each violated policy once, including report-only" {
    const Recorder = struct {
        count: usize = 0,
        reports: usize = 0,
        fn report(context: *anyopaque, v: *const csp.violation_events.Violation) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            std.testing.expectEqualStrings("frame-ancestors", v.effective_directive) catch unreachable;
            std.testing.expectEqualStrings("https://child.test/page", v.resource.url) catch unreachable;
            std.testing.expect(v.element == null) catch unreachable;
            self.count += 1;
            if (v.policy.disposition == .report) self.reports += 1;
        }
    };
    var list = csp.CSPList.init(std.testing.allocator);
    defer list.deinit();
    for ([_]csp.PolicyDisposition{ .report, .enforce }) |disposition| {
        var policy = try csp.parseSerializedCSP(std.testing.allocator, "frame-ancestors 'none'", .header, disposition);
        errdefer policy.deinit();
        try list.append(policy);
    }
    var recorder: Recorder = .{};
    const reporter: csp.violation_events.Reporter = .{ .context = &recorder, .report = Recorder.report };
    const ancestors = [_]csp.directives.frame_ancestors.AncestorOrigin{ .{ .scheme = "https", .host = "parent.test" }, null };
    try std.testing.expect(csp.directives.frame_ancestors.checkNavigationResponse(&list, false, &ancestors, "https://child.test/page", reporter));
    try std.testing.expectEqual(@as(usize, 2), recorder.count);
    try std.testing.expectEqual(@as(usize, 1), recorder.reports);
    recorder = .{};
    try std.testing.expect(!csp.directives.frame_ancestors.checkNavigationResponse(&list, true, &ancestors, "about:blank", reporter));
    try std.testing.expectEqual(@as(usize, 0), recorder.count);
    list.policies.items[1].disposition = .report;
    try std.testing.expect(!csp.directives.frame_ancestors.checkNavigationResponse(&list, false, &ancestors, "https://child.test/page", reporter));
    try std.testing.expectEqual(@as(usize, 2), recorder.count);
}
