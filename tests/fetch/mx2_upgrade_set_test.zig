//! UIR 3.1/3.3: navigation opt-ins are owned snapshots of host/port pairs.
const std = @import("std");
const fetch = @import("fetch");
const PolicyContainer = fetch.internal.PolicyContainer;
const main = fetch.algorithms.main_fetch;

test "UIR navigation set: empty clone and inheritance allocate nothing" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing.allocator();
    var parent = PolicyContainer.init(allocator);
    defer parent.deinit();
    var child = PolicyContainer.init(allocator);
    defer child.deinit();
    try child.inheritUpgradeInsecureNavigations(&parent);
    var copy = try child.clone(allocator);
    defer copy.deinit();
    try std.testing.expect(!copy.upgradesNavigationTo("http://example.test/"));
}

test "UIR navigation set: report-only contributes no tuple or allocation" {
    var monitor = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://monitor.test:8443/",
        .csp_report_only = "upgrade-insecure-requests",
    });
    defer monitor.deinit();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var child = PolicyContainer.init(failing.allocator());
    defer child.deinit();
    try child.inheritUpgradeInsecureNavigations(&monitor);
    try std.testing.expect(!monitor.upgradesNavigationTo("http://monitor.test:8443/"));
    try std.testing.expect(!child.upgradesNavigationTo("http://monitor.test:8443/"));
}

fn inheritedSnapshot(allocator: std.mem.Allocator) !PolicyContainer {
    var grandparent = try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://grandparent.test:8443/",
        .csp = "upgrade-insecure-requests",
    });
    defer grandparent.deinit();
    var parent = try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://parent.test:8000/",
        .csp = "upgrade-insecure-requests",
    });
    defer parent.deinit();
    try parent.inheritUpgradeInsecureNavigations(&grandparent);
    var child = PolicyContainer.init(allocator);
    defer child.deinit();
    try child.inheritUpgradeInsecureNavigations(&parent);
    // Repeated inheritance is a set union, and remains owned by the child.
    try child.inheritUpgradeInsecureNavigations(&parent);
    return child.clone(allocator);
}

test "UIR navigation set: a clone outlives both levels of inherited policies" {
    var copy = try inheritedSnapshot(std.testing.allocator);
    defer copy.deinit();
    try std.testing.expect(copy.upgradesNavigationTo("http://parent.test:8000/next"));
    try std.testing.expect(copy.upgradesNavigationTo("http://grandparent.test:8443/next"));
    try std.testing.expect(!copy.upgradesNavigationTo("http://parent.test:8443/next"));
    try std.testing.expect(!copy.upgradesNavigationTo("http://foreign.test:8000/next"));
}

fn allocationTrial(allocator: std.mem.Allocator) !void {
    var copy = try inheritedSnapshot(allocator);
    defer copy.deinit();
    try std.testing.expect(copy.upgradesNavigationTo("http://grandparent.test:8443/"));
}

test "UIR navigation set: every inheritance and clone allocation unwinds on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{});
}

fn growthTrial(allocator: std.mem.Allocator) !void {
    // Force array growth through allocation, so every growth failure is
    // exercised by checkAllAllocationFailures as well as each host copy.
    var no_resize = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
    const checked = no_resize.allocator();
    var child = PolicyContainer.init(checked);
    defer child.deinit();
    for (0..12) |index| {
        var buffer: [96]u8 = undefined;
        const url = try std.fmt.bufPrint(&buffer, "https://parent{d}.test:8443/", .{index});
        var parent = try PolicyContainer.fromResponseHeaders(checked, .{
            .url = url,
            .csp = "upgrade-insecure-requests",
        });
        defer parent.deinit();
        try child.inheritUpgradeInsecureNavigations(&parent);
    }
    var copy = try child.clone(checked);
    defer copy.deinit();
    for (0..12) |index| {
        var buffer: [96]u8 = undefined;
        const url = try std.fmt.bufPrint(&buffer, "http://parent{d}.test:8443/", .{index});
        try std.testing.expect(copy.upgradesNavigationTo(url));
    }
}

test "UIR navigation set: growing a union and cloning it unwind every allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, growthTrial, .{});
}

test "UIR navigation set: duplicate inheritance allocates nothing" {
    var parent = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://parent.test/",
        .csp = "upgrade-insecure-requests",
    });
    defer parent.deinit();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var child = PolicyContainer.init(failing.allocator());
    defer child.deinit();
    try child.inheritUpgradeInsecureNavigations(&parent);
    failing.fail_index = failing.alloc_index;
    try child.inheritUpgradeInsecureNavigations(&parent);
    try std.testing.expect(child.upgradesNavigationTo("http://parent.test/"));
    try std.testing.expect(!failing.has_induced_failure);
}

test "UIR navigation set: membership allocates nothing and compares canonical host and port" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var policy = try PolicyContainer.fromResponseHeaders(failing.allocator(), .{
        .url = "https://[2001:db8::1]:8443/start",
        .csp = "upgrade-insecure-requests",
    });
    defer policy.deinit();
    failing.fail_index = failing.alloc_index;
    try std.testing.expect(policy.upgradesNavigationTo("http://user:pass@[2001:db8::1]:8443/next?q#fragment"));
    try std.testing.expect(!policy.upgradesNavigationTo("http://[2001:db8::1]:8000/next"));
    try std.testing.expect(!policy.upgradesNavigationTo("http://[2001:db8::2]:8443/next"));
    try std.testing.expect(!policy.upgradesNavigationTo("data:text/plain,body"));
    try std.testing.expect(!failing.has_induced_failure);
}

test "UIR navigation set: inheritance snapshots a parent's opt-ins" {
    var parent = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://before.test/",
        .csp = "upgrade-insecure-requests",
    });
    defer parent.deinit();
    var child = PolicyContainer.init(std.testing.allocator);
    defer child.deinit();
    try child.inheritUpgradeInsecureNavigations(&parent);
    const replacement = try PolicyContainer.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://after.test/",
        .csp = "upgrade-insecure-requests",
    });
    parent.deinit();
    parent = replacement;
    try std.testing.expect(child.upgradesNavigationTo("http://before.test/next"));
    try std.testing.expect(!child.upgradesNavigationTo("http://after.test/next"));
}

test "UIR navigation request: form marker defaults false and survives clone" {
    const request = try fetch.internal.InternalRequest.init(std.testing.allocator, "http://foreign.test/form");
    defer request.deinit();
    try std.testing.expect(!request.form_submission);
    request.form_submission = true;
    const copy = try request.clone();
    defer copy.deinit();
    request.form_submission = false;
    try std.testing.expect(copy.form_submission);
}

test "UIR navigation request: GET and POST forms upgrade without a host match" {
    const allocator = std.testing.allocator;
    inline for (.{ "GET", "POST" }) |method| {
        const request = try fetch.internal.InternalRequest.init(allocator, "http://foreign.test/form");
        defer request.deinit();
        request.destination = .document;
        request.mode = .navigate;
        request.form_submission = true;
        try request.setMethod(method);
        // A form marker alone does not establish an upgrade policy.
        try std.testing.expect(!main.wouldUpgradeToPotentiallyTrustworthyUrl(request));
        request.setPolicyContainer(try PolicyContainer.fromResponseHeaders(allocator, .{
            .url = "https://example.test/",
            .csp = "upgrade-insecure-requests",
        }));
        try std.testing.expect(main.wouldUpgradeToPotentiallyTrustworthyUrl(request));
        try main.upgradeRequestToPotentiallyTrustworthyUrl(request);
        try std.testing.expectEqualStrings("https://foreign.test/form", request.currentUrl());
    }
}
