const std = @import("std");
const csp = @import("csp");
const navigation = csp.navigation_check;
const testing = std.testing;

const Reports = struct {
    count: usize = 0,
    url: []const u8 = "",
    directive: []const u8 = "",

    fn reporter(self: *Reports) csp.violation_events.Reporter {
        return .{ .context = self, .report = record };
    }

    fn record(context: *anyopaque, violation: *const csp.violation_events.Violation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
        self.url = violation.resource.url;
        self.directive = violation.effective_directive;
    }
};

test "form-action matches the current URL but reports the original navigation URL" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    list.self_origin = csp.types.Origin.createBorrowed("https", "source.test", null);
    try list.append(try csp.parseSerializedCSP(testing.allocator, "form-action 'self'", .header, .enforce));
    const original = "https://source.test/redirect?to=other";
    var request = navigation.NavigationRequest.ofSerialized("https://other.test/submit");
    request.original_url = original;
    request.redirect_count = 1;
    var reports: Reports = .{};
    try testing.expectEqual(navigation.Result.blocked, navigation.preNavigationChecks(&list, request, .form_submission, reports.reporter()));
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqualStrings("form-action", reports.directive);
    try testing.expectEqualStrings(original, reports.url);
}

test "form-action reports all violated policies and ignores them for ordinary navigation" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "form-action 'none'", .header, .enforce));
    try list.append(try csp.parseSerializedCSP(testing.allocator, "form-action 'none'", .header, .report));
    var reports: Reports = .{};
    const request = navigation.NavigationRequest.ofSerialized("https://other.test/submit");
    try testing.expectEqual(navigation.Result.blocked, navigation.preNavigationChecks(&list, request, .form_submission, reports.reporter()));
    try testing.expectEqual(@as(usize, 2), reports.count);
    reports = .{};
    try testing.expectEqual(navigation.Result.allowed, navigation.preNavigationChecks(&list, request, .other, reports.reporter()));
    try testing.expectEqual(@as(usize, 0), reports.count);
}

test "form-action path matching is skipped after a redirect but origin matching remains" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "form-action https://allowed.test/start", .header, .enforce));
    var request = navigation.NavigationRequest.ofSerialized("https://allowed.test/finish");
    try testing.expectEqual(navigation.Result.blocked, navigation.preNavigationChecks(&list, request, .form_submission, null));
    request.redirect_count = 1;
    try testing.expectEqual(navigation.Result.allowed, navigation.preNavigationChecks(&list, request, .form_submission, null));
    request.url = csp.request_check.Url.ofSerialized("https://other.test/start");
    try testing.expectEqual(navigation.Result.blocked, navigation.preNavigationChecks(&list, request, .form_submission, null));
}

test "form-action has no default-src fallback and report-only never blocks" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "default-src 'none'", .header, .enforce));
    try list.append(try csp.parseSerializedCSP(testing.allocator, "form-action 'none'", .header, .report));
    var reports: Reports = .{};
    const request = navigation.NavigationRequest.ofSerialized("https://other.test/submit");
    try testing.expectEqual(navigation.Result.allowed, navigation.preNavigationChecks(&list, request, .form_submission, reports.reporter()));
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqualStrings(request.serialized_url, reports.url);
}

test "frame-src self blocks a data URL under an opaque origin" {
    var list = csp.CSPList.init(testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(testing.allocator, "frame-src 'self'", .meta, .enforce));
    const request: csp.request_check.Request = .{
        .url = csp.request_check.Url.ofSerialized("data:text/html,blocked"),
        .destination = "iframe",
    };
    try testing.expectEqual(csp.request_check.Result.blocked, csp.request_check.shouldRequestBeBlocked(&list, request, null));
}
