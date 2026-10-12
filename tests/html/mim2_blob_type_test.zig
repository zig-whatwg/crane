//! Body presence, including zero-byte bodies, determines Blob MIME packaging.
const std = @import("std");
const Browser = @import("browser").Browser;

fn checkBlobTypes() !void {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const context = browser.current_context orelse return error.NoContext;
    const started = try browser.evaluateScript(
        \\globalThis.blobResult = "pending";
        \\(async () => {
        \\  for (const request of [false, true]) {
        \\    for (const body of ["x", "", null]) {
        \\      const headers = {"Content-Type": "Text/Plain; A=First;A=Second"};
        \\      const object = request ? new Request("https://example.test/", {method: "POST", body, headers}) : new Response(body, {headers});
        \\      const expected = body === null ? "text/plain;a=first" : "text/plain; a=first;a=second";
        \\      const blob = await object.blob();
        \\      if (blob.type !== expected) throw new Error("expected " + expected + ", got " + blob.type);
        \\    }
        \\  }
        \\})().then(() => { blobResult = "pass"; }, error => { blobResult = String(error); });
    );
    started.release();
    for (0..100) |_| {
        const result = try context.evaluateScriptToString("blobResult", allocator);
        defer allocator.free(result);
        if (!std.mem.eql(u8, result, "pending")) {
            try std.testing.expectEqualStrings("pass", result);
            return;
        }
        _ = try browser.runEventLoopBlocking(1);
    }
    return error.PromiseDidNotSettle;
}

test "blob preserves raw MIME for non-null bodies and extracts MIME for null bodies" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            checkBlobTypes() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
