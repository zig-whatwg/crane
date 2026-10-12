//! An empty MIME boundary must never turn a bare "--" into a delimiter.
const std = @import("std");
const Browser = @import("browser").Browser;

fn checkEmptyBoundary() !void {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const context = browser.current_context orelse return error.NoContext;
    const started = try browser.evaluateScript(
        \\globalThis.boundaryResult = "pending";
        \\(async () => {
        \\  const bodies = ["----", '--\r\nContent-Disposition: form-data; name="n"\r\n\r\nv\r\n----'];
        \\  for (const body of bodies) {
        \\    for (const request of [false, true]) {
        \\      const headers = {"Content-Type": 'multipart/form-data; boundary=""'};
        \\      const object = request ? new Request("https://example.test/", {method: "POST", body, headers}) : new Response(body, {headers});
        \\      let rejected = false;
        \\      try { await object.formData(); } catch (error) {
        \\        if (!(error instanceof TypeError)) throw error;
        \\        rejected = true;
        \\      }
        \\      if (!rejected) throw new Error("empty boundary accepted");
        \\    }
        \\  }
        \\})().then(() => { boundaryResult = "pass"; }, error => { boundaryResult = String(error); });
    );
    started.release();
    for (0..100) |_| {
        const result = try context.evaluateScriptToString("boundaryResult", allocator);
        defer allocator.free(result);
        if (!std.mem.eql(u8, result, "pending")) {
            try std.testing.expectEqualStrings("pass", result);
            return;
        }
        _ = try browser.runEventLoopBlocking(1);
    }
    return error.PromiseDidNotSettle;
}

test "formData rejects an empty boundary before parsing any parts" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            checkEmptyBoundary() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
