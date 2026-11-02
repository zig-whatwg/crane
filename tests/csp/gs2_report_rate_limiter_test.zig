//! CSP violation reports' rate limiter (csp.RateLimiter) is state a Browser
//! owns - a supplement of its scope, which a reporting caller passes in
//! ReportingConfig.rate_limiter - never a limiter reporting keeps of its own:
//! a thread-local default limited every page the thread ran together, and two
//! Browsers on one thread shared it. A Browser supplement is reached from
//! several threads (its workers'), so the limiter locks its own state.
const std = @import("std");
const testing = std.testing;
const csp = @import("csp");

const Counting = struct {
    sent: u32 = 0,

    fn send(ctx: *anyopaque, _: []const u8, _: []const u8) bool {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.sent += 1;
        return true;
    }

    fn sender(self: *Counting) csp.ReportSender {
        return .{ .ctx = self, .sendFn = send };
    }
};

const endpoints = [_][]const u8{"https://example.com/csp-report"};

fn reportMany(allocator: std.mem.Allocator, n: usize, counting: *Counting, limiter: ?*csp.RateLimiter) !void {
    var policy = csp.types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();
    var script_src = try csp.types.Directive.create(allocator, "script-src");
    try script_src.value.append(csp.types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(script_src);
    var violation = try csp.createViolation(allocator, &policy, "script-src", .inline_script, .{ .document_uri = "https://example.com" });
    defer violation.deinit();
    for (0..n) |_| try csp.reportViolation(allocator, &violation, &endpoints, .{
        .sender = counting.sender(),
        .rate_limiter = limiter,
        .allocator = allocator,
    });
}

test "a report given no rate limiter is sent: reporting keeps no limiter of its own" {
    var counting: Counting = .{};
    // One more than a limiter's default allowance (100 a window).
    try reportMany(testing.allocator, 101, &counting, null);
    try testing.expectEqual(@as(u32, 101), counting.sent);
}

test "each Browser's limiter limits its own reports, and only its own" {
    var first = csp.RateLimiter.init(testing.allocator);
    defer first.deinit();
    var second = csp.RateLimiter.init(testing.allocator);
    defer second.deinit();
    var counting: Counting = .{};
    try reportMany(testing.allocator, 101, &counting, &first);
    try testing.expectEqual(@as(u32, 100), counting.sent);
    try reportMany(testing.allocator, 1, &counting, &second);
    try testing.expectEqual(@as(u32, 101), counting.sent);
}

test "a limiter reached from several threads at once allows exactly its limit" {
    var limiter = csp.RateLimiter.initWithLimits(testing.allocator, 1000, 3600);
    defer limiter.deinit();
    const Run = struct {
        allowed: std.atomic.Value(u32) = .init(0),
        fn attempts(self: *@This(), shared: *csp.RateLimiter) void {
            for (0..500) |_| {
                if (shared.shouldAllowReport("https://example.com/csp-report")) _ = self.allowed.fetchAdd(1, .monotonic);
            }
        }
    };
    var run: Run = .{};
    var threads: [4]std.Thread = undefined;
    for (&threads) |*thread| thread.* = try std.Thread.spawn(.{}, Run.attempts, .{ &run, &limiter });
    for (threads) |thread| thread.join();
    try testing.expectEqual(@as(u32, 1000), run.allowed.load(.monotonic));
}
