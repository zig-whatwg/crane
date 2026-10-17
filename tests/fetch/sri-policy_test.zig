//! Integrity-Policy enforcement and reporting before network dispatch.
const std = @import("std");
const fetch = @import("fetch");
const pc = fetch.internal.policy_container;
const rm = fetch.internal.request;
const Job = fetch.algorithms.FetchJob;

fn container(header: []const u8, report_only: bool) !pc.PolicyContainer {
    if (comptime @hasField(pc.ResponseHeaders, "integrity_policy")) {
        return pc.PolicyContainer.fromResponseHeaders(std.testing.allocator, if (report_only)
            .{ .integrity_policy_report_only = header }
        else
            .{ .integrity_policy = header });
    }
    return pc.PolicyContainer.init(std.testing.allocator);
}

fn check(header: []const u8, report_only: bool, mode: rm.RequestMode, metadata: []const u8, destination: rm.Destination, blocked: bool) !void {
    const a = std.testing.allocator;
    var policy = try container(header, report_only);
    defer policy.deinit();
    var copy = try policy.clone(a);
    defer copy.deinit();
    const r = try rm.InternalRequest.init(a, "https://sri.test/resource");
    defer r.deinit();
    r.mode = mode;
    r.destination = destination;
    try r.setOrigin("https://sri.test");
    try r.setIntegrityMetadata(metadata);
    r.setPolicyContainer(try copy.clone(a));
    const job = try Job.create(a, r, false, .{});
    defer job.destroy();
    const step = try job.start();
    try std.testing.expectEqualStrings(if (blocked) "done" else "network", @tagName(step));
    if (blocked) {
        var result = job.takeResult();
        defer result.deinit();
        try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
    }
}

test "sri policy accepts only known destination/source tokens and validates the whole field" {
    const enforced = "blocked-destinations=(script style), endpoints=(one two)";
    try check(enforced, false, .cors, "", .script, true);
    try check(enforced, false, .cors, "sha256-AAAA", .script, false);
    try check(enforced, false, .same_origin, "sha512-AAAA", .script, false);
    try check(enforced, false, .no_cors, "sha256-AAAA", .script, true);
    try check(enforced, false, .cors, "unknown-AAAA", .script, true);
    try check(enforced, false, .cors, "SHA256-AAAA", .script, true);
    try check(enforced, false, .cors, "sha256-...", .script, true);
    // Browser majority only ships the script policy destination.
    try check(enforced, false, .cors, "", .style, false);
    try check(enforced, false, .cors, "", .json, false);
    try check(enforced, false, .cors, "", .image, false);
    try check(enforced, false, .cors, "", .empty, false);
    try check(enforced, true, .cors, "", .script, false);
    for ([_][]const u8{ "", "blocked-destinations=script", "blocked-destinations=(\"script\")", "blocked-destinations=(script), sources=(elsewhere)", "blocked-destinations=(script), sources=(\"inline\")", "blocked-destinations=(script), sources=()", "blocked-destinations=(script", "blocked-destinations=(script,style)", "(script)" }) |header| {
        try check(header, false, .cors, "", .script, false);
    }
    try check("blocked-destinations=(script), blocked-destinations=(style)", false, .cors, "", .script, false);
    try check("blocked-destinations=(style), blocked-destinations=(script)", false, .cors, "", .script, true);
    try check("blocked-destinations=(\"style\" script 3), sources=(?1 inline)", false, .cors, "", .script, true);
    try check("blocked-destinations=(script), sources=elsewhere", false, .cors, "", .script, true);
    try check("blocked-destinations=(script), sources=\"elsewhere\"", false, .cors, "", .script, true);
    try check("blocked-destinations=(Script)", false, .cors, "", .script, false);
    try check("blocked-destinations=(script), sources=(Inline)", false, .cors, "", .script, false);
}

test "sri policy reports enforced and report-only violations with cloned owned endpoints" {
    if (comptime @hasDecl(rm, "IntegrityViolation")) {
        const Recorder = struct {
            calls: usize = 0,
            invalid: bool = false,
            fn report(context: *anyopaque, violation: *const rm.IntegrityViolation) void {
                const self: *@This() = @ptrCast(@alignCast(context));
                self.invalid = self.invalid or
                    !std.mem.eql(u8, violation.blocked_url, "https://sri.test/resource#fragment") or
                    violation.destination != .script or
                    violation.report_only != (self.calls == 1) or
                    violation.endpoints.len != 2;
                if (violation.endpoints.len == 2) {
                    self.invalid = self.invalid or
                        !std.mem.eql(u8, violation.endpoints[0], if (self.calls == 0) "one" else "three") or
                        !std.mem.eql(u8, violation.endpoints[1], if (self.calls == 0) "two" else "four");
                }
                self.calls += 1;
            }
        };
        const a = std.testing.allocator;
        var original = try pc.PolicyContainer.fromResponseHeaders(a, .{
            .integrity_policy = "blocked-destinations=(script), endpoints=(one two)",
            .integrity_policy_report_only = "blocked-destinations=(script), endpoints=(three four)",
        });
        const copied = original.clone(a) catch |err| {
            original.deinit();
            return err;
        };
        original.deinit();
        const r = try rm.InternalRequest.init(a, "https://sri.test/resource#fragment");
        defer r.deinit();
        r.setPolicyContainer(copied);
        r.mode = .cors;
        r.destination = .script;
        var recorder: Recorder = .{};
        r.integrity_violation_reporter = .{ .context = &recorder, .report = Recorder.report };
        const cloned = try r.clone();
        defer cloned.deinit();
        const job = try Job.create(a, cloned, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .done);
        try std.testing.expectEqual(@as(usize, 2), recorder.calls);
        try std.testing.expect(!recorder.invalid);
    } else return error.TestUnexpectedResult;
}

test "sri policy exempts local schemes before checking metadata" {
    const a = std.testing.allocator;
    for ([_][]const u8{ "data:text/javascript,", "about:blank", "blob:https://sri.test/no-such-blob" }) |url| {
        const r = try rm.InternalRequest.init(a, url);
        defer r.deinit();
        r.setPolicyContainer(try container("blocked-destinations=(script)", false));
        r.mode = .no_cors;
        r.destination = .script;
        // Native response behavior differs for missing blob/about, but the
        // policy must not report any of these local requests.
        var result = try fetch.fetch(a, r, .{});
        defer result.deinit();
        if (std.mem.startsWith(u8, url, "data:"))
            try std.testing.expectEqual(fetch.internal.ResponseType.basic, result.response.response_type);
    }
}

fn allocationTrial(a: std.mem.Allocator) anyerror!void {
    if (comptime @hasField(pc.ResponseHeaders, "integrity_policy")) {
        var original = try pc.PolicyContainer.fromResponseHeaders(a, .{
            .integrity_policy = "blocked-destinations=(script), endpoints=(one two)",
            .integrity_policy_report_only = "blocked-destinations=(script), endpoints=(three four)",
        });
        defer original.deinit();
        var copy = try original.clone(a);
        defer copy.deinit();
    } else return error.TestUnexpectedResult;
}

test "sri policy parsing and cloning release endpoint ownership on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{});
}
