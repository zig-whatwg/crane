//! Lane cascadefast2's storage characterization: element chains whose
//! computed values pin what ComputedStyle answers, rendered as text.
//!
//! cascadefast2_storage_test.zig compares the rendering with
//! cascadefast2_storage_golden.txt, which was rendered from the flat
//! one-slot-per-longhand storage (main ed32910c383, and byte-identical
//! again from mains b847f16a4db and 45e43dd24c6) before the grouped
//! storage replaced it: every resolved value of every longhand, for initial,
//! inherited, explicit inherit/initial/unset, the root, a display:contents
//! parent, pseudo-elements, registered custom properties, `all`, revert,
//! revert-layer, logical longhands and the adjustments between values.
const std = @import("std");
const css = @import("css");
const support = @import("vars2_support.zig");

const Allocator = std.mem.Allocator;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Longhand = css.properties.Longhand;
const Origin = cascade_mod.Origin;

/// One block of an element: its text and where it enters the cascade.
const Block = struct {
    text: []const u8,
    origin: Origin = .author,
    layer: u16 = cascade_mod.unlayered,
    order: u32 = 1,
};

/// One element of a chain, the root first. Its parent is the element
/// before it, or `parent` (an index into the chain) for a sibling.
const Element = struct {
    blocks: []const Block = &.{},
    pseudo: ?[]const u8 = null,
    parent: ?usize = null,
};

const Case = struct {
    name: []const u8,
    chain: []const Element,
    registered: bool = false,
};

const counted =
    \\font-family: "A Font", monospace; text-shadow: 1px 2px 3px red, 0 0 blue;
    \\cursor: url(c.png) 2 3, pointer; list-style-image: url(l.png);
    \\quotes: auto; text-emphasis-style: "x"; font-feature-settings: "liga" 0;
    \\box-shadow: 1px 1px 2px green inset; transform: rotate(10deg) translate(2px, 3em);
    \\filter: blur(2px) drop-shadow(1px 1px red); grid-template-areas: "a b" "c d";
    \\grid-template-columns: [x] 10px repeat(2, 1fr); animation-name: one, two;
    \\animation-duration: 1s, 2s; mask-image: url(m.png), linear-gradient(red, blue);
    \\background-image: url(b.png), radial-gradient(red, currentcolor);
    \\content: "a" counter(c) url(i.png); clip-path: circle(10px at 2px 3px);
    \\border-image-source: url(bi.png); border-top-left-radius: 3px 4px;
    \\width: calc(10px + 2em); margin-left: min(5px, 1em); caret-color: currentcolor
;

const cases = [_]Case{
    .{ .name = "initial root and child", .chain = &.{ .{}, .{} } },
    .{ .name = "inherited and counted values", .chain = &.{
        .{ .blocks = &.{.{ .text = "color: red; font-size: 20px; letter-spacing: 2px; visibility: hidden; line-height: 1.5; word-spacing: 3px; text-indent: 2em; " ++ counted }} },
        .{},
        .{ .blocks = &.{.{ .text = "font-size: 2em; color: currentcolor; text-shadow: inherit" }} },
    } },
    .{ .name = "explicit inherit initial unset", .chain = &.{
        .{ .blocks = &.{.{ .text = "margin-top: 5px; background-color: green; color: blue; display: flex; border-top-width: 7px; border-top-style: solid; " ++ counted }} },
        .{ .blocks = &.{.{ .text = "margin-top: inherit; background-color: inherit; color: initial; font-size: unset; display: unset; border-top-width: inherit; border-top-style: inherit; box-shadow: inherit; transform: inherit; font-family: initial; text-shadow: unset; width: inherit" }} },
        .{ .blocks = &.{.{ .text = "margin-top: unset; background-color: unset; color: inherit; filter: inherit; grid-template-areas: inherit; content: inherit" }} },
    } },
    .{ .name = "root display contents and none", .chain = &.{
        .{ .blocks = &.{.{ .text = "display: contents; color: green" }} },
        .{ .blocks = &.{.{ .text = "display: none" }} },
        .{ .blocks = &.{.{ .text = "display: grid; grid-template-columns: subgrid" }} },
    } },
    .{ .name = "display contents parent in a grid", .chain = &.{
        .{ .blocks = &.{.{ .text = "display: grid; justify-items: legacy center" }} },
        .{ .blocks = &.{.{ .text = "display: contents; color: green; padding-left: 3px; font-size: 30px" }} },
        .{ .blocks = &.{.{ .text = "display: grid; grid-template-columns: subgrid; grid-template-rows: subgrid; padding-left: inherit; justify-items: legacy" }} },
        .{},
    } },
    .{ .name = "pseudo-elements", .chain = &.{
        .{ .blocks = &.{.{ .text = "color: purple; font-size: 12px; content: \"p\"" }} },
        .{ .blocks = &.{.{ .text = "content: normal; margin-left: 1em" }}, .pseudo = "before" },
        .{ .blocks = &.{.{ .text = "color: inherit" }}, .pseudo = "after" },
    } },
    .{ .name = "registered custom properties", .registered = true, .chain = &.{
        .{ .blocks = &.{.{ .text = "--len: 10px; --col: blue; --any: foo; width: var(--len); background-color: var(--col); font-size: 18px; --em: 2em" }} },
        .{ .blocks = &.{.{ .text = "height: var(--len); color: var(--col); margin-left: var(--em); --len: 4px; padding-left: var(--len)" }} },
        .{ .blocks = &.{.{ .text = "border-top-width: var(--len, 1px); border-top-style: solid; outline-color: var(--col)" }} },
    } },
    .{ .name = "all", .chain = &.{
        .{ .blocks = &.{.{ .text = "color: red; margin-left: 4px; direction: rtl; " ++ counted }} },
        .{ .blocks = &.{.{ .text = "all: inherit" }} },
        .{ .blocks = &.{.{ .text = "all: initial; color: green" }} },
        .{ .blocks = &.{.{ .text = "all: unset; margin-left: 9px" }} },
        .{ .blocks = &.{.{ .text = "all: revert" }} },
    } },
    .{ .name = "revert and revert-layer", .chain = &.{
        .{ .blocks = &.{
            .{ .text = "display: block; margin-top: 8px; color: gray; font-weight: bold", .origin = .user_agent, .order = 0 },
            .{ .text = "color: olive; margin-bottom: 2px", .origin = .user, .order = 1 },
            .{ .text = "display: revert; margin-top: revert; color: revert; font-weight: 300; margin-bottom: revert", .order = 2 },
        } },
        .{ .blocks = &.{
            .{ .text = "color: red; margin-left: 1px; padding-top: 2px", .layer = 0, .order = 1 },
            .{ .text = "color: revert-layer; margin-left: revert-layer; padding-top: 6px", .layer = 1, .order = 2 },
            .{ .text = "padding-top: revert-layer", .order = 3 },
        } },
    } },
    .{ .name = "logical longhands", .chain = &.{
        .{ .blocks = &.{.{ .text = "writing-mode: vertical-rl; direction: rtl" }} },
        .{ .blocks = &.{.{ .text = "margin-inline-start: 7px; padding-block-end: 3px; border-inline-end-width: 5px; border-inline-end-style: solid; border-block-start-color: red; inset-block-start: 2px; inline-size: 50px; max-block-size: 10px; min-inline-size: 1px; margin-top: 4px" }} },
        .{ .blocks = &.{.{ .text = "writing-mode: horizontal-tb; margin-inline-start: inherit; padding-inline: 2px 9px" }} },
    } },
    // Integrator condition 1: a logical longhand set to inherit, and a
    // physical one inherited, where parent and child differ in writing mode
    // or direction (each child a sibling under the same parent).
    .{ .name = "logical inherit across writing modes", .chain = &.{
        .{ .blocks = &.{.{ .text = "writing-mode: vertical-rl; direction: rtl; margin-top: 1px; margin-right: 2px; margin-bottom: 3px; margin-left: 4px; padding-top: 5px; padding-right: 6px; padding-bottom: 7px; padding-left: 8px; border-top-width: 9px; border-top-style: solid; border-left-width: 10px; border-left-style: dashed; border-right-color: red; width: 11px; height: 12px; min-width: 13px; max-height: 14px; top: 15px; right: 16px; bottom: 17px; left: 18px" }} },
        .{ .blocks = &.{.{ .text = "writing-mode: horizontal-tb; direction: ltr; margin-inline-start: inherit; margin-block-start: inherit; margin-inline-end: inherit; padding-inline-start: inherit; padding-block-end: inherit; border-inline-start-width: inherit; border-inline-start-style: inherit; border-block-start-width: inherit; border-block-start-style: inherit; border-inline-end-color: inherit; inline-size: inherit; block-size: inherit; min-inline-size: inherit; max-block-size: inherit; inset-inline-start: inherit; inset-block-end: inherit" }}, .parent = 0 },
        .{ .blocks = &.{.{ .text = "writing-mode: horizontal-tb; margin-top: inherit; margin-left: inherit; padding-right: inherit; width: inherit; height: inherit; border-top-width: inherit; border-top-style: inherit; border-left-width: inherit; border-left-style: inherit; top: inherit; left: inherit" }}, .parent = 0 },
        .{ .blocks = &.{.{ .text = "direction: ltr; margin-inline: inherit; padding-block: inherit; inset-inline: inherit; border-inline-start-width: inherit; border-inline-start-style: inherit" }}, .parent = 0 },
        .{ .blocks = &.{.{ .text = "writing-mode: vertical-lr; margin-block-start: inherit; padding-inline-end: inherit; inline-size: inherit" }}, .parent = 0 },
        .{ .blocks = &.{.{ .text = "all: inherit" }}, .parent = 1 },
        .{ .blocks = &.{.{ .text = "writing-mode: sideways-rl; margin-inline-start: 5px; margin-block-end: inherit" }}, .parent = 4 },
    } },
    // Integrator condition 5: pseudo-elements inherit from their originating
    // element, and ::first-line / ::first-letter keep their allowlists.
    .{ .name = "pseudo-elements of one originating element", .chain = &.{
        .{ .blocks = &.{.{ .text = "color: teal; font-size: 20px; letter-spacing: 1px" }} },
        .{ .blocks = &.{.{ .text = "display: block; color: navy; font-weight: bold; margin-left: 3px; text-transform: uppercase; writing-mode: vertical-rl" }} },
        .{ .blocks = &.{.{ .text = "content: \"b\"; color: red; margin-left: 2px; display: inline-block; float: left" }}, .pseudo = "before", .parent = 1 },
        .{ .blocks = &.{.{ .text = "content: \"a\"; color: inherit; font-size: 2em; position: absolute" }}, .pseudo = "after", .parent = 1 },
        .{ .blocks = &.{.{ .text = "color: green; margin-left: 5px; padding-left: 2px; font-style: italic; letter-spacing: 3px; text-decoration-line: underline; display: block; float: left; position: absolute; width: 10px; background-color: yellow; word-spacing: 4px" }}, .pseudo = "first-line", .parent = 1 },
        .{ .blocks = &.{.{ .text = "color: green; margin-left: 5px; padding-left: 2px; float: left; position: absolute; initial-letter: 2; border-top-width: 3px; border-top-style: solid; width: 10px; font-size: 3em; display: block" }}, .pseudo = "first-letter", .parent = 1 },
        .{ .blocks = &.{.{ .text = "color: red; content: \"*\"; font-size: 10px; margin-inline-start: 4px" }}, .pseudo = "marker", .parent = 1 },
    } },
    .{ .name = "adjustments", .chain = &.{
        .{ .blocks = &.{.{ .text = "display: flex" }} },
        .{ .blocks = &.{.{ .text = "display: inline; position: absolute; float: left; overflow-x: hidden; overflow-y: visible; contain: strict" }} },
        .{ .blocks = &.{.{ .text = "display: inline-block; float: right; overflow-x: clip; overflow-y: scroll; contain: size layout; content-visibility: auto" }} },
        .{ .blocks = &.{.{ .text = "display: grid; grid-template-columns: subgrid" }} },
    } },
};

pub const case_count = cases.len;

/// Every case's chain, rendered: the initial root in full, then each
/// element's custom properties and every longhand whose resolved value
/// differs from the initial root's.
pub fn render(allocator: Allocator, out: *std.ArrayList(u8)) !void {
    return renderCases(allocator, out, 0, cases.len);
}

/// render for cases[first..end] only (the initial root always).
pub fn renderCases(allocator: Allocator, out: *std.ArrayList(u8), first: usize, end: usize) !void {
    const initial = try ComputedStyle.initial(allocator);
    defer initial.destroy();
    var baseline: [Longhand.count][]u8 = undefined;
    var made: usize = 0;
    defer for (baseline[0..made]) |b| allocator.free(b);
    for (0..Longhand.count) |i| {
        baseline[i] = try resolved(allocator, initial, @fromBackingInt(@intCast(i)));
        made += 1;
    }
    try out.appendSlice(allocator, "== initial\n");
    for (baseline, 0..) |b, i| try line(allocator, out, @as(Longhand, @fromBackingInt(@intCast(i))).name(), b);

    for (cases[first..end]) |case| {
        const snapshot: ?*css.registered_properties.Snapshot = if (case.registered) try support.snapshotOf(allocator, .{}, &.{
            .{ .name = "--len", .syntax = "<length>", .inherits = false, .initial = "3px" },
            .{ .name = "--col", .syntax = "<color>", .inherits = true, .initial = "red" },
            .{ .name = "--em", .syntax = "<length>", .inherits = true, .initial = "0px" },
        }) else null;
        defer if (snapshot) |s| s.release();
        var styles: std.ArrayList(*ComputedStyle) = .empty;
        defer {
            for (styles.items) |s| s.destroy();
            styles.deinit(allocator);
        }
        for (case.chain, 0..) |element, depth| {
            var blocks: std.ArrayList(DeclarationBlock) = .empty;
            defer {
                for (blocks.items) |*b| b.deinit();
                blocks.deinit(allocator);
            }
            var matched: std.ArrayList(cascade_mod.Matched) = .empty;
            defer matched.deinit(allocator);
            try blocks.ensureTotalCapacity(allocator, element.blocks.len);
            for (element.blocks) |b| blocks.appendAssumeCapacity(try DeclarationBlock.parse(.{ .allocator = allocator }, b.text));
            for (element.blocks, blocks.items) |b, *parsed| try matched.append(allocator, .{
                .block = parsed,
                .source = .{ .origin = b.origin, .layer = b.layer, .order = b.order, .specificity = .{ .b = 1 } },
            });
            const parent: ?*const ComputedStyle = if (depth == 0) null else styles.items[element.parent orelse depth - 1];
            try styles.ensureUnusedCapacity(allocator, 1);
            const style = try cascade_mod.cascade(.{
                .allocator = allocator,
                .parent = parent,
                .is_root = depth == 0 and element.pseudo == null,
                .pseudo = element.pseudo,
                .registered = snapshot,
            }, matched.items);
            styles.appendAssumeCapacity(style);
            try out.print(allocator, "== {s} / {d}{s}{s}\n", .{ case.name, depth, if (element.pseudo != null) " ::" else "", element.pseudo orelse "" });
            if (element.parent) |p| try out.print(allocator, "(parent {d})\n", .{p});
            const names = try style.customNames(allocator);
            defer allocator.free(names);
            for (names) |name| try line(allocator, out, name, if (style.customValue(name)) |t| t.bytes else "<invalid>");
            for (0..Longhand.count) |i| {
                const text = try resolved(allocator, style, @fromBackingInt(@intCast(i)));
                defer allocator.free(text);
                if (!std.mem.eql(u8, text, baseline[i])) try line(allocator, out, @as(Longhand, @fromBackingInt(@intCast(i))).name(), text);
            }
        }
    }
}

fn resolved(allocator: Allocator, style: *const ComputedStyle, l: Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    return out.toOwnedSlice(allocator);
}

fn line(allocator: Allocator, out: *std.ArrayList(u8), name: []const u8, value: []const u8) !void {
    try out.print(allocator, "{s}: {s}\n", .{ name, value });
}
