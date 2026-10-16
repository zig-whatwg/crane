//! HTML 8.1.8.1: initialized targets use the shared event handler map.
//! The null-context check also exercises allocation cleanup with the testing allocator.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn checkDefaults() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.createNullContext(allocator);
    defer ctx.deinit();

    inline for (.{ interfaces.Element, interfaces.HTMLBodyElement, interfaces.HTMLMediaElement, interfaces.HTMLVideoElement, interfaces.HTMLPortalElement, interfaces.Keyboard }) |Interface| {
        const target = try Interface.init(allocator, &ctx);
        defer Interface.deinit(target);
        const names = if (Interface == interfaces.Element)
            .{ "onfullscreenchange", "onfullscreenerror" }
        else if (Interface == interfaces.HTMLBodyElement)
            .{"onorientationchange"}
        else if (Interface == interfaces.HTMLMediaElement)
            .{ "onencrypted", "onwaitingforkey" }
        else if (Interface == interfaces.HTMLVideoElement)
            .{ "onenterpictureinpicture", "onleavepictureinpicture" }
        else if (Interface == interfaces.HTMLPortalElement)
            .{ "onmessage", "onmessageerror" }
        else
            .{"onlayoutchange"};
        inline for (names) |name| {
            try std.testing.expect((try @field(Interface, "get_" ++ name)(target)) == null);
            try @field(Interface, "set_" ++ name)(target, null);
            try std.testing.expect((try @field(Interface, "get_" ++ name)(target)) == null);
        }
    }
}

fn runDefaults(result: *?anyerror) void {
    checkDefaults() catch |err| {
        result.* = err;
    };
}

test "handler attributes initially return null and accept null on initialized targets" {
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, runDefaults, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
