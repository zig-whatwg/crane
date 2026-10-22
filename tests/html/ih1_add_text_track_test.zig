//! IDL member behavior through script, including allocator-checked teardown.
const std = @import("std");
const browser_mod = @import("browser");

fn check(comptime script: []const u8, comptime expected: []const u8) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }

        fn exercise() !void {
            const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.NoPage;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
            const result = try page.evaluateScriptToString(script, std.testing.allocator);
            defer std.testing.allocator.free(result);
            try std.testing.expectEqualStrings(expected, result);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "addTextTrack initializes and appends independent hidden tracks" {
    try check(
        \\(() => {
        \\  const video = document.createElement('video');
        \\  const first = video.addTextTrack('subtitles', 'English', 'en');
        \\  const second = video.addTextTrack('metadata');
        \\  return JSON.stringify([first.kind, first.label, first.language, first.id, first.mode,
        \\    first.cues.length, first.activeCues.length, first.cues === first.cues,
        \\    second.label, second.language, video.textTracks.length,
        \\    video.textTracks[0] === first, video.textTracks[1] === second]);
        \\})()
    , "[\"subtitles\",\"English\",\"en\",\"\",\"hidden\",0,0,true,\"\",\"\",2,true,true]");
}
