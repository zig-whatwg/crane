//! Lane coi2: the URL and endpoint list an inherited opener policy reports
//! with (an initial about:blank document's, from its creator's top-level
//! document), kept with the container's opener policy.

const std = @import("std");
const PolicyContainer = @import("fetch").internal.PolicyContainer;

test "an inherited opener policy's reporter: copied URL and endpoints, owned by the container, not cloned" {
    var creator = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://a.test/opener",
        .reporting_endpoints = "coop-report-endpoint=\"/reports\"",
    });
    defer creator.deinit();

    var blank = PolicyContainer.init(std.testing.allocator);
    defer blank.deinit();
    try std.testing.expect(blank.openerPolicyReporter() == null);
    try blank.setOpenerPolicy(.{ .value = .same_origin, .reporting_endpoint = try std.testing.allocator.dupe(u8, "coop-report-endpoint") });
    try blank.setOpenerPolicyReporter("https://a.test/opener", creator.endpoints);

    const reporter = blank.openerPolicyReporter().?;
    try std.testing.expectEqualStrings("https://a.test/opener", reporter.url);
    const endpoint = reporter.endpoints.?.find("coop-report-endpoint").?;
    try std.testing.expectEqualStrings("https://a.test/reports", endpoint.url);
    // A copy: the creator's list is not the reporter's.
    try std.testing.expect(reporter.endpoints.? != creator.endpoints.?);

    // HTML's clone does not carry the opener policy, nor its reporter.
    var clone = try blank.clone(std.testing.allocator);
    defer clone.deinit();
    try std.testing.expect(clone.openerPolicyReporter() == null);

    // A creator with no Reporting-Endpoints: a reporter with no list.
    var bare = PolicyContainer.init(std.testing.allocator);
    defer bare.deinit();
    try bare.setOpenerPolicyReporter("https://a.test/", null);
    try std.testing.expect(bare.openerPolicyReporter().?.endpoints == null);
}

test "setting an opener policy reporter fails cleanly at every allocation" {
    var creator = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://a.test/opener",
        .reporting_endpoints = "e=\"/reports\", f=\"/other\"",
    });
    defer creator.deinit();
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, endpoints: ?*@import("fetch").internal.policy_container.Endpoints) !void {
            var container = PolicyContainer.init(allocator);
            defer container.deinit();
            try container.setOpenerPolicyReporter("https://a.test/opener", endpoints);
        }
    }.run, .{creator.endpoints});
}
