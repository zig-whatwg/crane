//! Lane anim1 batch 5 (item 5): a custom property keyframe that substitutes
//! another ANIMATED custom property computes with that property's animated
//! value. Web Animations 1 5.3.2 "Computing property values": "When
//! computing a property value, the computed values of dependencies held by
//! value must be calculated first" - and a dependency's computed value
//! includes its own animation's effect value.
//!
//! The first case is WPT css/css-properties-values-api/animation/
//! registered-var-to-registered-animating.html. Chrome 157 passes it;
//! Firefox 159 (100) and Safari 27.2 (75) fail it, each differently (wpt.fyi
//! aligned stable run 8c04fb8d43): all three differ and no mechanism
//! majority forms a shipping browser's behaviour, so golden rule 2 follows
//! the spec, which is Chrome's (the integrator's ruling, 2026-11-08 02:51).
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

const setup =
    \\for (const name of ['--test', '--static', '--animated', '--chain']) {
    \\  CSS.registerProperty({ name, syntax: '<number>', initialValue: '0', inherits: false });
    \\}
    \\const target = document.body.appendChild(document.createElement('div'));
    \\target.style.setProperty('--static', '100');
    \\const read = (name) => getComputedStyle(target).getPropertyValue(name);
;

test "anim1b5: a keyframe's var() reads the referenced property's animated value, across animations" {
    try check(setup ++
        \\const animation = target.animate({ '--test': ['var(--static)', 'var(--animated)'] }, 100);
        \\const referenced = target.animate({ '--animated': ['200', '300'] }, 100);
        \\const out = [];
        \\for (const r of [25, 75]) {
        \\  referenced.currentTime = r;
        \\  for (const t of [25, 75]) { animation.currentTime = t; out.push(read('--test')); }
        \\}
        \\out.join(' ');
    , "131.25 193.75 143.75 231.25");
}

test "anim1b5: a chain of animated custom properties resolves in dependency order" {
    // --chain's keyframes read --test, whose keyframes read --animated: at
    // 50% everywhere, --animated is 250, --test lerp(100, 250) = 175 and
    // --chain lerp(0, 175) = 87.5 - whatever order the animations started.
    try check(setup ++
        \\const chain = target.animate({ '--chain': ['0', 'var(--test)'] }, 100);
        \\const test = target.animate({ '--test': ['var(--static)', 'var(--animated)'] }, 100);
        \\const animated = target.animate({ '--animated': ['200', '300'] }, 100);
        \\for (const a of [chain, test, animated]) a.currentTime = 50;
        \\[read('--animated'), read('--test'), read('--chain')].join(' ');
    , "250 175 87.5");
}

test "anim1b5: a keyframe that substitutes no animated property is unchanged" {
    try check(setup ++
        \\const animation = target.animate({ '--test': ['var(--static)', '300'] }, 100);
        \\animation.currentTime = 50;
        \\read('--test');
    , "200");
}
