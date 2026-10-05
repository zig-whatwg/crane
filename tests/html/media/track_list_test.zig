//! HTML 4.8.11.11.3 list membership and TrackEvent construction, tests first.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const hooks = @import("dom").media_elements;
fn start() void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
}
fn track(ctx: runtime.Context, id: []const u8) !*runtime.Instance {
    return hooks.createTrackElementTrack(ctx, .subtitles, .initEmpty(), .initEmpty(), .initInterned(id));
}
test "new TextTrackList is empty and missing IDs return null" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const list = try hooks.createTextTrackList(&ctx);
    defer interfaces.TextTrackList.deinit(list);
    try testing.expectEqual(@as(u32, 0), try interfaces.TextTrackList.get_length(list));
    try testing.expect((try interfaces.TextTrackList.call_getTrackById(list, .initInterned("absent"))) == null);
}
test "appendTextTrack is ordered and idempotent for one identity" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const a = try track(&ctx, "same");
    defer interfaces.TextTrack.deinit(a);
    const b = try track(&ctx, "same");
    defer interfaces.TextTrack.deinit(b);
    const list = try hooks.createTextTrackList(&ctx);
    defer interfaces.TextTrackList.deinit(list);
    try hooks.appendTextTrack(list, a);
    try hooks.appendTextTrack(list, a);
    try hooks.appendTextTrack(list, b);
    try testing.expectEqual(@as(u32, 2), try interfaces.TextTrackList.get_length(list));
    try testing.expectEqual(a, try interfaces.TextTrackList.call_getter(list, 0));
    try testing.expectEqual(b, try interfaces.TextTrackList.call_getter(list, 1));
    try testing.expectEqual(a, (try interfaces.TextTrackList.call_getTrackById(list, .initInterned("same"))).?);
}
test "removeTextTrack removes one edge without destroying a held track" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const a = try track(&ctx, "first");
    defer interfaces.TextTrack.deinit(a);
    const b = try track(&ctx, "second");
    defer interfaces.TextTrack.deinit(b);
    const list = try hooks.createTextTrackList(&ctx);
    defer interfaces.TextTrackList.deinit(list);
    try hooks.appendTextTrack(list, a);
    try hooks.appendTextTrack(list, b);
    hooks.removeTextTrack(list, a);
    hooks.removeTextTrack(list, a);
    try testing.expectEqual(@as(u32, 1), try interfaces.TextTrackList.get_length(list));
    try testing.expectEqual(b, try interfaces.TextTrackList.call_getter(list, 0));
    var id = try interfaces.TextTrack.get_id(a);
    defer id.deinit(testing.allocator);
    try testing.expectEqualStrings("first", id.asSlice());
}
test "trackElementParentChanged moves membership between two media lists" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const a = try interfaces.HTMLVideoElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLVideoElement.deinit(a);
    const b = try interfaces.HTMLAudioElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLAudioElement.deinit(b);
    const element = try interfaces.HTMLTrackElement.init(testing.allocator, &ctx);
    defer interfaces.HTMLTrackElement.deinit(element);
    const child = try interfaces.HTMLTrackElement.get_track(element);
    // With no engine the fixture owns every explicitly retrieved child.
    defer interfaces.TextTrack.deinit(child);
    const a_list = try interfaces.HTMLMediaElement.get_textTracks(a);
    defer interfaces.TextTrackList.deinit(a_list);
    const b_list = try interfaces.HTMLMediaElement.get_textTracks(b);
    defer interfaces.TextTrackList.deinit(b_list);
    hooks.trackElementParentChanged(element, null, a);
    try testing.expectEqual(child, try interfaces.TextTrackList.call_getter(a_list, 0));
    hooks.trackElementParentChanged(element, a, b);
    try testing.expectEqual(@as(u32, 0), try interfaces.TextTrackList.get_length(a_list));
    try testing.expectEqual(child, try interfaces.TextTrackList.call_getter(b_list, 0));
    hooks.trackElementParentChanged(element, b, null);
    try testing.expectEqual(@as(u32, 0), try interfaces.TextTrackList.get_length(b_list));
}
test "TrackEvent constructor initializes type flags and nullable track" {
    start();
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const empty = try interfaces.TrackEvent.call_constructor(&ctx, .initInterned("change"), .notPassed());
    defer interfaces.TrackEvent.deinit(empty);
    try testing.expect((try interfaces.TrackEvent.get_track(empty)) == null);
    const child = try track(&ctx, "held");
    defer interfaces.TextTrack.deinit(child);
    const event = try interfaces.TrackEvent.call_constructor(&ctx, .initInterned("addtrack"), .passed(.{ .base = .{ .bubbles = true, .cancelable = true, .composed = true }, .track = .{ .instance = child } }));
    defer interfaces.TrackEvent.deinit(event);
    var name = try interfaces.Event.get_type(event);
    defer name.deinit(testing.allocator);
    try testing.expectEqualStrings("addtrack", name.asSlice());
    try testing.expect(try interfaces.Event.get_bubbles(event));
    try testing.expect(try interfaces.Event.get_cancelable(event));
    try testing.expect(try interfaces.Event.get_composed(event));
    try testing.expectEqual(child, (try interfaces.TrackEvent.get_track(event)).?.instance);
}
