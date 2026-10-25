//! Font load events keep a frozen array through an owner-traced edge.
const std = @import("std");
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const first = try interfaces.FontFace.init(std.testing.allocator, realm);
    const first_generation = runtime.SlabAllocator.generationOf(first);
    defer first.releaseIfUnwrapped(first_generation);
    const second = try interfaces.FontFace.init(std.testing.allocator, realm);
    const second_generation = runtime.SlabAllocator.generationOf(second);
    defer second.releaseIfUnwrapped(second_generation);
    var members = [_]*runtime.Instance{ first, second, first };
    const event = try interfaces.FontFaceSetLoadEvent.call_constructor(realm, .initInterned("loadingdone"), .{
        .was_passed = true,
        .value = .{ .base = .{ .bubbles = true, .cancelable = true, .composed = true }, .fontfaces = &members },
    });
    const event_generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(event_generation);
    members[0] = second;
    const array: engine.Owned = .{ .value = try interfaces.FontFaceSetLoadEvent.get_fontfaces(event) };
    defer array.release();
    const again: engine.Owned = .{ .value = try interfaces.FontFaceSetLoadEvent.get_fontfaces(event) };
    defer again.release();
    try std.testing.expect(engine.sameValue(realm, array.borrow(), again.borrow()));
    const copy = try engine.convertToSequenceOfObjects(realm, array.borrow(), std.testing.allocator);
    defer {
        for (copy) |value| value.release();
        std.testing.allocator.free(copy);
    }
    try std.testing.expectEqual(@as(usize, 3), copy.len);
    for (copy, [_]*runtime.Instance{ first, second, first }) |value, expected| {
        try std.testing.expect(engine.convertToPlatformObject(realm, value.borrow()).? == expected);
    }
    try std.testing.expect(try interfaces.Event.get_bubbles(event));
    try std.testing.expect(try interfaces.Event.get_cancelable(event));
    try std.testing.expect(try interfaces.Event.get_composed(event));
    var event_type = try interfaces.Event.get_type(event);
    defer event_type.deinit(realm.allocator);
    try std.testing.expectEqualStrings("loadingdone", event_type.asSlice());

    const empty = try interfaces.FontFaceSetLoadEvent.call_constructor(realm, .initInterned("loading"), .{ .was_passed = false, .value = undefined });
    const empty_generation = runtime.SlabAllocator.generationOf(empty);
    defer empty.releaseIfUnwrapped(empty_generation);
    const empty_array: engine.Owned = .{ .value = try interfaces.FontFaceSetLoadEvent.get_fontfaces(empty) };
    defer empty_array.release();
    const empty_members = try engine.convertToSequenceOfObjects(realm, empty_array.borrow(), std.testing.allocator);
    defer {
        for (empty_members) |value| value.release();
        std.testing.allocator.free(empty_members);
    }
    try std.testing.expectEqual(@as(usize, 0), empty_members.len);
    try std.testing.expect(!try interfaces.Event.get_bubbles(empty));
}

test "FontFaceSetLoadEvent copies ordered members and ends its unwrapped traced edge" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
