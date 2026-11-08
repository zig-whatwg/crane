//! Lane anim1 batch 5 (item 1): a registered custom property's combined
//! values travel typed through one evaluation of the effect stack
//! (dom.animations.effect_stack TypedCustoms), so a <color> accumulated past
//! 255 is not clamped by its text before the final value (CSS Values 4 3.1).
//!
//! The cases are WPT's css/css-properties-values-api/animation/
//! custom-property-animation-color*.html iterationComposite cases (Chrome
//! 157, Firefox 159 and Safari 27.2 pass them): three iterations, sampled in
//! the middle of the third.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn check(comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, failure: *?anyerror) void {
            exercise(want) catch |err| {
                failure.* = err;
            };
        }
        fn exercise(want: []const u8) !void {
            const page = try helpers.Page.open();
            defer page.close();
            const actual = try page.evaluate(source);
            defer std.testing.allocator.free(actual);
            try std.testing.expectEqualStrings(want, actual);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &failure });
    thread.join();
    if (failure) |err| return err;
}

fn sample(comptime syntax: []const u8, comptime initial: []const u8, comptime from: []const u8, comptime to: []const u8, comptime composite: []const u8) []const u8 {
    return "CSS.registerProperty({ name: '--c', syntax: '" ++ syntax ++ "', initialValue: '" ++ initial ++ "', inherits: false });\n" ++
        "const target = document.body.appendChild(document.createElement('div'));\n" ++
        "const animation = target.animate({ '--c': ['" ++ from ++ "', '" ++ to ++ "'] }, { iterationComposite: '" ++ composite ++ "', iterations: 3, duration: 1000 });\n" ++
        "animation.pause();\n" ++
        "animation.currentTime = 2500;\n" ++
        "getComputedStyle(target).getPropertyValue('--c');";
}

test "anim1b5: a registered <color> accumulates past 255 across iterations" {
    // 200 -> 300 at 0.5: 250, where a text clamped to 255 gives 228.
    try check(sample("<color>", "black", "rgb(0, 0, 0)", "rgb(100, 100, 100)", "accumulate"), "rgb(250, 250, 250)");
}

test "anim1b5: a registered <color>+ list keeps each item unclamped" {
    try check(sample("<color>+", "black", "rgb(0, 0, 0) rgb(0, 0, 0)", "rgb(50, 50, 50) rgb(100, 100, 100)", "accumulate"), "rgb(125, 125, 125) rgb(250, 250, 250)");
}

test "anim1b5: without accumulation the same keyframes stay in range" {
    try check(sample("<color>", "black", "rgb(0, 0, 0)", "rgb(100, 100, 100)", "replace"), "rgb(50, 50, 50)");
}
