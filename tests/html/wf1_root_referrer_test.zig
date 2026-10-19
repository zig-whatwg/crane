//! Q9's additive root-referrer patch is held for row 68's merge. Until the
//! integrator applies it, the Crane wf1-root-referrer test is expected-fail
//! and this native ownership pin is explicitly skipped.
const std = @import("std");
const script_fetch = @import("html_core").workers.script_fetch;

fn copiedReferrer(allocator: std.mem.Allocator) !void {
    if (comptime @hasField(script_fetch.WorkerScriptFetchOptions, "referrer_source")) {
        var source = "https://wf1.test/creator.html".*;
        const request = try script_fetch.workerScriptRequest(allocator, "https://wf1.test/worker.js", .{
            .requesting_origin = "https://wf1.test",
            .referrer_source = &source,
        });
        defer request.deinit();
        // The borrow can disappear or change after the synchronous call.
        // Its request owns the URL for redirects and referrer computation.
        @memset(&source, 'x');
        try std.testing.expect(request.referrer == .url);
        try std.testing.expectEqualStrings("https://wf1.test/creator.html", request.referrer.url);
    } else return error.SkipZigTest;
}

test "worker root request owns its borrowed creator referrer" {
    if (comptime @hasField(script_fetch.WorkerScriptFetchOptions, "referrer_source")) {
        try copiedReferrer(std.testing.allocator);
        try std.testing.checkAllAllocationFailures(std.testing.allocator, copiedReferrer, .{});
    } else return error.SkipZigTest;
}

test "worker root request suppresses an opaque creator referrer" {
    if (comptime @hasField(script_fetch.WorkerScriptFetchOptions, "referrer_source")) {
        const request = try script_fetch.workerScriptRequest(std.testing.allocator, "https://wf1.test/worker.js", .{
            .requesting_origin = "null",
            .referrer_source = "https://wf1.test/creator.html",
        });
        defer request.deinit();
        try std.testing.expect(request.referrer == .no_referrer);
    } else return error.SkipZigTest;
}
