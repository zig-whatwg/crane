//! Lane anim1 (C2): @keyframes rules as the style engine indexes them, and
//! CSS Animations 2 3.2 "processing keyframes" (dom.animations.css_animations
//! buildKeyframes): groups by offset, timing function and composite; the
//! last declaration wins; !important and the animation-* properties dropped;
//! generated 0% / 100% keyframes holding IMPLICIT values (the underlying
//! value at sampling, the computed value in getKeyframes()).
const std = @import("std");
const dom = @import("dom");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const css_animations = dom.animations.css_animations;
const keyframes = dom.animations.keyframes;

fn parse(text: []const u8) !*dom.style.sheet.Contents {
    return dom.style.sheet.Contents.parse(testing.allocator, text, .{});
}

fn valueOf(frame: *const keyframes.Keyframe, name: []const u8) ?[]const u8 {
    for (frame.properties.items) |p| if (std.mem.eql(u8, p.name, name)) return p.value;
    return null;
}

test "@keyframes rules are indexed with their condition and layer" {
    const contents = try parse("@keyframes a { to { opacity: 0 } } @layer l { @keyframes a { to { opacity: 1 } } } @media print { @keyframes b { } } div { color: red }");
    defer contents.destroy();
    const indexed = contents.keyframes_rules.items;
    try testing.expectEqual(@as(usize, 3), indexed.len);
    try testing.expectEqualStrings("a", indexed[0].rule.prelude);
    try testing.expect(indexed[0].layer == null);
    try testing.expect(indexed[0].condition == null);
    try testing.expect(indexed[1].layer != null);
    try testing.expectEqualStrings("b", indexed[2].rule.prelude);
    try testing.expect(indexed[2].condition != null);
}

test "keyframe blocks group by offset, timing function and composite, in offset order" {
    const contents = try parse(
        \\@keyframes k {
        \\  from { margin-left: 0px; animation-timing-function: linear }
        \\  50% { opacity: 0.5 }
        \\  to { margin-left: 100px }
        \\  from { opacity: 0 }
        \\  50%, 100% { color: red }
        \\}
    );
    defer contents.destroy();
    var list = try css_animations.buildKeyframes(testing.allocator, contents.keyframes_rules.items[0].rule, "ease", .replace);
    defer list.deinit(testing.allocator);
    const frames = list.frames.items;
    try testing.expectEqual(@as(usize, 4), frames.len);
    // 0%, linear: margin-left.
    try testing.expectEqual(@as(f64, 0), frames[0].computed_offset);
    try testing.expectEqualStrings("linear", frames[0].easing.text);
    try testing.expectEqualStrings("0px", valueOf(&frames[0], "margin-left").?);
    // 0%, ease: opacity, and color made implicit there (no 0% sets it).
    try testing.expectEqual(@as(f64, 0), frames[1].computed_offset);
    try testing.expectEqualStrings("0", valueOf(&frames[1], "opacity").?);
    try testing.expectEqualStrings("", valueOf(&frames[1], "color").?);
    try testing.expect(frames[1].composite == .auto);
    // 50%: opacity and the color of the shared "50%, 100%" block.
    try testing.expectEqual(@as(f64, 0.5), frames[2].computed_offset);
    try testing.expectEqualStrings("0.5", valueOf(&frames[2], "opacity").?);
    try testing.expect(valueOf(&frames[2], "color") != null);
    // 100%: margin-left, color, and opacity implicit.
    try testing.expectEqual(@as(f64, 1), frames[3].computed_offset);
    try testing.expectEqualStrings("100px", valueOf(&frames[3], "margin-left").?);
    try testing.expectEqualStrings("", valueOf(&frames[3], "opacity").?);
}

test "a missing end makes a generated keyframe with the defaults" {
    const contents = try parse("@keyframes g { 50% { opacity: 0.5 } }");
    defer contents.destroy();
    var list = try css_animations.buildKeyframes(testing.allocator, contents.keyframes_rules.items[0].rule, "ease-in", .add);
    defer list.deinit(testing.allocator);
    const frames = list.frames.items;
    try testing.expectEqual(@as(usize, 3), frames.len);
    try testing.expectEqual(@as(f64, 0), frames[0].computed_offset);
    try testing.expectEqualStrings("ease-in", frames[0].easing.text);
    try testing.expect(frames[0].composite == .add);
    try testing.expectEqualStrings("", valueOf(&frames[0], "opacity").?);
    try testing.expect(css_animations.isImplicit(frames[0].properties.items[0]));
    try testing.expectEqualStrings("ease-in", frames[1].easing.text);
    try testing.expect(frames[1].composite == .auto);
    try testing.expectEqual(@as(f64, 1), frames[2].computed_offset);
    try testing.expectEqualStrings("", valueOf(&frames[2], "opacity").?);
}

test "the last declaration wins; !important and animation-* are dropped" {
    const contents = try parse(
        \\@keyframes d {
        \\  to { margin-top: 150px !important; margin-bottom: 200px; animation-duration: 3s }
        \\  to { margin-bottom: 250px }
        \\}
    );
    defer contents.destroy();
    var list = try css_animations.buildKeyframes(testing.allocator, contents.keyframes_rules.items[0].rule, "ease", .replace);
    defer list.deinit(testing.allocator);
    const last = &list.frames.items[list.frames.items.len - 1];
    try testing.expectEqualStrings("250px", valueOf(last, "margin-bottom").?);
    try testing.expect(valueOf(last, "margin-top") == null);
    try testing.expect(valueOf(last, "animation-duration") == null);
}

test "a shorthand waiting for var() stays one declaration with its text" {
    const contents = try parse("@keyframes v { from { border: 1px solid blue } to { border: 1px solid var(--end) } }");
    defer contents.destroy();
    var list = try css_animations.buildKeyframes(testing.allocator, contents.keyframes_rules.items[0].rule, "ease", .replace);
    defer list.deinit(testing.allocator);
    const last = &list.frames.items[list.frames.items.len - 1];
    const border = valueOf(last, "border") orelse return error.NoShorthand;
    try testing.expect(std.mem.indexOf(u8, border, "var(--end)") != null);
    try testing.expect(valueOf(last, "border-top-color") == null);
}

test "custom properties and var() in keyframes keep their text" {
    const contents = try parse("@keyframes c { from { --value: blue; color: var(--value) } to { --value: green } }");
    defer contents.destroy();
    var list = try css_animations.buildKeyframes(testing.allocator, contents.keyframes_rules.items[0].rule, "ease", .replace);
    defer list.deinit(testing.allocator);
    const first = &list.frames.items[0];
    try testing.expectEqualStrings("blue", std.mem.trim(u8, valueOf(first, "--value").?, " "));
    try testing.expect(std.mem.indexOf(u8, valueOf(first, "color").?, "var(--value)") != null);
}
