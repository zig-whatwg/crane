//! Media setters queue rooted events and require a real engine realm.
//! Q39 browser controls: default/explicit mute match :muted; volume zero does not.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn defaultMute() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const video = document.createElement('video');
        \\if (video.matches(':muted')) throw new Error('initial muted');
        \\video.defaultMuted = true;
        \\if (!video.matches(':muted')) throw new Error('default mute');
        \\video.defaultMuted = false;
        \\if (video.matches(':muted')) throw new Error('default mute cleared');
        \\if (!video.matches(':paused')) throw new Error('remains paused');
    );
}

fn explicitMute() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const video = document.createElement('video');
        \\video.muted = true;
        \\if (!video.matches(':muted')) throw new Error('explicit mute');
        \\video.muted = false;
        \\if (video.matches(':muted')) throw new Error('explicit mute cleared');
        \\if (!video.matches(':paused')) throw new Error('remains paused');
    );
}

fn zeroVolume() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const video = document.createElement('video');
        \\video.volume = 0;
        \\if (video.matches(':muted')) throw new Error('zero volume is not mute');
        \\if (!video.matches(':paused')) throw new Error('remains paused');
    );
}

test "default mute selector reads preserve the media flag" {
    errdefer std.debug.print("CP1_NATIVE_CASE FAIL: default mute selector reads preserve the media flag\n", .{});
    try helpers.onFreshThread(defaultMute);
    std.debug.print("CP1_NATIVE_CASE PASS: default mute selector reads preserve the media flag\n", .{});
}

test "explicit mute selector reads preserve the media flag" {
    errdefer std.debug.print("CP1_NATIVE_CASE FAIL: explicit mute selector reads preserve the media flag\n", .{});
    try helpers.onFreshThread(explicitMute);
    std.debug.print("CP1_NATIVE_CASE PASS: explicit mute selector reads preserve the media flag\n", .{});
}

test "zero media volume does not match muted" {
    errdefer std.debug.print("CP1_NATIVE_CASE FAIL: zero media volume does not match muted\n", .{});
    try helpers.onFreshThread(zeroVolume);
    std.debug.print("CP1_NATIVE_CASE PASS: zero media volume does not match muted\n", .{});
}
