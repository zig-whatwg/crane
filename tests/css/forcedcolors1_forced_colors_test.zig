//! CSS Color Adjustment Level 1 §3 (Forced Colors Mode) unit tests (lane forcedcolors1).
//!
//! Covers:
//! - Default `forced-colors: none`: authored colors, shadows, gradients, color-scheme,
//!   accent-color, scrollbar-color, font-variant-emoji untouched.
//! - `forced-colors: active` (light and dark §5.2 palettes):
//!   - Computed value (`style.get()`) stays unforced for color properties (WPT forced-colors-mode-40),
//!     while resolved/used value (`serializeResolved()`) is forced (WPT forced-colors-mode-41).
//!   - `background-color` preserves alpha (`rgba(..., 0.3)` -> `Canvas` with 0.3; transparent stays
//!     transparent) and pairs with the opposite of used `color`'s system color.
//!   - Explicit `<system-color>` values are never forced and resolve against the §5.2 palette.
//!   - UA-origin `color` rules (`:link`, `mark`, etc.) inherit their forced color to descendants.
//!   - `forced-color-adjust: none` opts out; `preserve-parent-color` computes inherited `color`
//!     to parent's used color while acting like `none` for other properties.
//!   - Computed-value adjustments: `box-shadow`, `text-shadow`, `background-image` (gradient vs url),
//!     `color-scheme`, `scrollbar-color`, `accent-color` (except system color), `font-variant-emoji`.
//!   - Highlight pseudo-elements honor originating element's `forced-color-adjust`.
//!   - `color-mix()` computed vs used color, and `revert` to UA origin.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;
const Longhand = css.properties.Longhand;
const MediaValues = css.media_queries.MediaValues;
const Matched = css.cascade.Matched;

const light_forced_media: MediaValues = .{ .forced_colors = true, .prefers_color_scheme = .light };
const dark_forced_media: MediaValues = .{ .forced_colors = true, .prefers_color_scheme = .dark };
const normal_media: MediaValues = .{ .forced_colors = false, .prefers_color_scheme = .light };

fn cascadeOne(
    parent: ?*const Style,
    ua_text: ?[]const u8,
    author_text: []const u8,
    media: *const MediaValues,
    extra: struct {
        is_root: bool = false,
        highlight: bool = false,
        highlight_parent: ?*const Style = null,
    },
) !*Style {
    var ua_block: ?Block = null;
    defer if (ua_block) |*b| b.deinit();
    if (ua_text) |t| ua_block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, t);

    var author_block = try Block.parse(.{ .allocator = testing.allocator }, author_text);
    defer author_block.deinit();

    var matched: [2]Matched = undefined;
    var count: usize = 0;
    if (ua_block) |*b| {
        matched[count] = .{ .block = b, .source = .{ .origin = .user_agent } };
        count += 1;
    }
    matched[count] = .{ .block = &author_block, .source = .{ .origin = .author } };
    count += 1;

    const preferred: css.color_scheme.Scheme = if (media.prefers_color_scheme == .dark) .dark else .light;
    return css.cascade.cascade(.{
        .allocator = testing.allocator,
        .parent = parent,
        .is_root = extra.is_root,
        .pseudo = if (extra.highlight) "selection" else null,
        .highlight = extra.highlight,
        .highlight_parent = extra.highlight_parent,
        .page_color_scheme = preferred,
        .preferred_color_scheme = preferred,
        .media_values = media,
    }, matched[0..count]);
}

fn expectResolved(style: *const Style, l: Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    if (!std.mem.eql(u8, out.items, expected)) {
        std.debug.print("resolved {s}: expected \"{s}\", got \"{s}\"\n", .{ l.name(), expected, out.items });
    }
    try testing.expectEqualStrings(expected, out.items);
}

fn expectComputed(style: *const Style, l: Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    const v = style.get(l);
    if (v == .color) {
        try v.color.serializeComputed(&out, testing.allocator);
    } else {
        try css.properties.serializeValue(l, v, &out, testing.allocator);
    }
    if (!std.mem.eql(u8, out.items, expected)) {
        std.debug.print("computed {s}: expected \"{s}\", got \"{s}\"\n", .{ l.name(), expected, out.items });
    }
    try testing.expectEqualStrings(expected, out.items);
}

test "forced-colors: none leaves authored colors and effects untouched" {
    const style = try cascadeOne(null, null,
        \\color: green;
        \\background-color: purple;
        \\border-color: red;
        \\outline-color: blue;
        \\box-shadow: 2px 2px purple;
        \\text-shadow: 1px 1px orange;
        \\background-image: linear-gradient(red, yellow);
        \\color-scheme: dark;
        \\accent-color: green;
        \\scrollbar-color: green red;
        \\font-variant-emoji: unicode;
    , &normal_media, .{ .is_root = true });
    defer style.destroy();

    try expectResolved(style, .color, "rgb(0, 128, 0)");
    try expectResolved(style, .background_color, "rgb(128, 0, 128)");
    try expectResolved(style, .border_top_color, "rgb(255, 0, 0)");
    try expectResolved(style, .outline_color, "rgb(0, 0, 255)");
    try expectResolved(style, .box_shadow, "rgb(128, 0, 128) 2px 2px 0px 0px");
    try expectResolved(style, .text_shadow, "rgb(255, 165, 0) 1px 1px 0px");
    try expectResolved(style, .background_image, "linear-gradient(rgb(255, 0, 0), rgb(255, 255, 0))");
    try expectResolved(style, .color_scheme, "dark");
    try expectResolved(style, .accent_color, "rgb(0, 128, 0)");
    try expectResolved(style, .scrollbar_color, "rgb(0, 128, 0) rgb(255, 0, 0)");
    try expectResolved(style, .font_variant_emoji, "unicode");
}

test "forced-colors: active forces resolved color properties while preserving computed values (WPT 40 & 41)" {
    const light = try cascadeOne(null, null,
        \\color: green;
        \\background-color: green;
        \\border-color: green;
        \\caret-color: green;
        \\column-rule-color: green;
        \\row-rule-color: green;
        \\fill: green;
        \\stroke: green;
        \\flood-color: green;
        \\lighting-color: green;
        \\outline-color: green;
        \\stop-color: green;
        \\text-decoration-color: green;
        \\text-emphasis-color: green;
        \\-webkit-text-fill-color: green;
        \\-webkit-text-stroke-color: green;
    , &light_forced_media, .{ .is_root = true });
    defer light.destroy();

    // Computed values (what computedStyleMap() sees) stay unforced: rgb(0, 128, 0).
    const unforced_computed = [_]Longhand{
        .color,               .background_color,        .border_top_color,          .border_right_color,
        .border_bottom_color, .border_left_color,       .caret_color,               .column_rule_color,
        .row_rule_color,      .fill,                    .stroke,                    .flood_color,
        .lighting_color,      .outline_color,           .stop_color,                .text_decoration_color,
        .text_emphasis_color, ._webkit_text_fill_color, ._webkit_text_stroke_color,
    };
    for (unforced_computed) |l| try expectComputed(light, l, "rgb(0, 128, 0)");

    // Resolved/used values (what getComputedStyle() sees) are forced to §5.2 light palette.
    try expectResolved(light, .color, "rgb(0, 0, 0)"); // CanvasText
    try expectResolved(light, .background_color, "rgb(255, 255, 255)"); // Canvas
    for ([_]Longhand{
        .border_top_color,          .border_right_color,       .border_bottom_color,
        .border_left_color,         .border_block_start_color, .border_inline_end_color,
        .caret_color,               .column_rule_color,        .row_rule_color,
        .fill,                      .stroke,                   .flood_color,
        .lighting_color,            .outline_color,            .stop_color,
        .text_decoration_color,     .text_emphasis_color,      ._webkit_text_fill_color,
        ._webkit_text_stroke_color,
    }) |l| try expectResolved(light, l, "rgb(0, 0, 0)");

    // Dark §5.2 palette: CanvasText = #FFFFFF, Canvas = #000000.
    const dark = try cascadeOne(null, null, "color: green; background-color: green; border-color: green;", &dark_forced_media, .{ .is_root = true });
    defer dark.destroy();
    try expectComputed(dark, .color, "rgb(0, 128, 0)");
    try expectResolved(dark, .color, "rgb(255, 255, 255)");
    try expectResolved(dark, .background_color, "rgb(0, 0, 0)");
    try expectResolved(dark, .border_top_color, "rgb(255, 255, 255)");
}

test "forced-colors: active computed-value adjustments (shadows, background-image, color-scheme, accent-color, scrollbar-color, font-variant-emoji)" {
    const grad = try cascadeOne(null, null,
        \\box-shadow: 2px 2px purple;
        \\text-shadow: 1px 1px orange;
        \\background-image: linear-gradient(red, yellow);
        \\color-scheme: dark;
        \\scrollbar-color: green red;
        \\accent-color: green;
        \\font-variant-emoji: unicode;
    , &light_forced_media, .{ .is_root = true });
    defer grad.destroy();

    try expectResolved(grad, .box_shadow, "none");
    try expectResolved(grad, .text_shadow, "none");
    try expectResolved(grad, .background_image, "none");
    try expectResolved(grad, .color_scheme, "light dark");
    try expectResolved(grad, .scrollbar_color, "auto");
    try expectResolved(grad, .accent_color, "auto");
    try expectResolved(grad, .font_variant_emoji, "text");

    // background-image with url() is preserved (including via var()).
    const with_url = try cascadeOne(null, null,
        \\--img: url("https://example.test/a.png");
        \\background-image: var(--img);
        \\accent-color: CanvasText;
        \\font-variant-emoji: emoji;
    , &light_forced_media, .{ .is_root = true });
    defer with_url.destroy();
    try expectResolved(with_url, .background_image, "url(\"https://example.test/a.png\")");
    try expectResolved(with_url, .accent_color, "rgb(0, 0, 0)"); // system color kept (WPT 50)
    try expectResolved(with_url, .font_variant_emoji, "emoji"); // emoji kept (WPT 60)

    // Initial font-variant-emoji: normal also computes to text in forced colors mode.
    const def = try cascadeOne(null, null, "", &light_forced_media, .{ .is_root = true });
    defer def.destroy();
    try expectResolved(def, .font_variant_emoji, "text");
}

test "forced-colors: active preserves background-color alpha and transparent backgrounds (WPT 07, 20, 21)" {
    const semi_light = try cascadeOne(null, null, "background-color: rgba(114, 173, 218, 0.3);", &light_forced_media, .{ .is_root = true });
    defer semi_light.destroy();
    try expectResolved(semi_light, .background_color, "rgba(255, 255, 255, 0.3)");

    const semi_dark = try cascadeOne(null, null, "background-color: rgba(114, 173, 218, 0.3);", &dark_forced_media, .{ .is_root = true });
    defer semi_dark.destroy();
    try expectResolved(semi_dark, .background_color, "rgba(0, 0, 0, 0.3)");

    const transparent_bg = try cascadeOne(null, null, "color: transparent; background-color: transparent;", &light_forced_media, .{ .is_root = true });
    defer transparent_bg.destroy();
    try expectResolved(transparent_bg, .color, "rgb(0, 0, 0)"); // color: transparent IS forced
    try expectResolved(transparent_bg, .background_color, "rgba(0, 0, 0, 0)"); // transparent bg stays transparent
}

test "forced-colors: active preserves explicit system colors and pairs background-color opposite color" {
    // Author sets HighlightText on color, non-system purple on background-color -> background-color pairs to Highlight (#37006E light).
    const paired = try cascadeOne(null, null, "color: HighlightText; background-color: purple; border-color: LinkText;", &light_forced_media, .{ .is_root = true });
    defer paired.destroy();
    try expectResolved(paired, .color, "rgb(255, 255, 255)"); // HighlightText light
    try expectResolved(paired, .background_color, "rgb(55, 0, 110)"); // Highlight light (#37006E)
    try expectResolved(paired, .border_top_color, "rgb(0, 0, 159)"); // LinkText light (#00009F)

    // Canvas opposite is CanvasText (§3.1).
    const inverted = try cascadeOne(null, null, "color: Canvas; background-color: purple;", &light_forced_media, .{ .is_root = true });
    defer inverted.destroy();
    try expectResolved(inverted, .color, "rgb(255, 255, 255)"); // Canvas
    try expectResolved(inverted, .background_color, "rgb(0, 0, 0)"); // CanvasText
}

test "forced-colors: UA forced colors inherit to descendants and preserve mark/link colors (WPT 03)" {
    const root = try cascadeOne(null, null, "color: red;", &light_forced_media, .{ .is_root = true });
    defer root.destroy();
    try expectResolved(root, .color, "rgb(0, 0, 0)");

    // Link with UA `:link { color: LinkText; }` and author `color: red`: forced to LinkText (#00009F).
    const link = try cascadeOne(root, "color: LinkText;", "color: red;", &light_forced_media, .{});
    defer link.destroy();
    try expectResolved(link, .color, "rgb(0, 0, 159)");

    // Child <em> inside link inherits link's forced color (LinkText), NOT CanvasText.
    const em = try cascadeOne(link, null, "color: green;", &light_forced_media, .{});
    defer em.destroy();
    try expectResolved(em, .color, "rgb(0, 0, 159)");

    // <mark> with UA `color: MarkText; background-color: Mark;` and author `color: orange; background-color: purple`.
    const mark = try cascadeOne(root, "color: MarkText; background-color: Mark;", "color: orange; background-color: purple;", &light_forced_media, .{});
    defer mark.destroy();
    try expectResolved(mark, .color, "rgb(0, 0, 0)"); // MarkText
    try expectResolved(mark, .background_color, "rgb(255, 255, 0)"); // Mark
}

test "forced-color-adjust: none opts out and preserve-parent-color inherits parent used color (WPT 03)" {
    const body = try cascadeOne(null, null, "color: red;", &light_forced_media, .{ .is_root = true });
    defer body.destroy();
    try expectComputed(body, .color, "rgb(255, 0, 0)");
    try expectResolved(body, .color, "rgb(0, 0, 0)"); // CanvasText

    // forced-color-adjust: none keeps authored colors & effects, and inherits parent's unforced computed color.
    const optout = try cascadeOne(body, null,
        \\forced-color-adjust: none;
        \\background-color: purple;
        \\box-shadow: 2px 2px orange;
        \\color-scheme: light;
        \\accent-color: green;
        \\scrollbar-color: green red;
        \\font-variant-emoji: unicode;
    , &light_forced_media, .{});
    defer optout.destroy();
    try expectResolved(optout, .color, "rgb(255, 0, 0)"); // inherited unforced computed color from body
    try expectResolved(optout, .background_color, "rgb(128, 0, 128)");
    try expectResolved(optout, .box_shadow, "rgb(255, 165, 0) 2px 2px 0px 0px");
    try expectResolved(optout, .color_scheme, "light");
    try expectResolved(optout, .accent_color, "rgb(0, 128, 0)");
    try expectResolved(optout, .scrollbar_color, "rgb(0, 128, 0) rgb(255, 0, 0)");
    try expectResolved(optout, .font_variant_emoji, "unicode");

    // Descendant re-opting into auto forces inherited non-auto values too.
    const reopt = try cascadeOne(optout, null, "forced-color-adjust: auto;", &light_forced_media, .{});
    defer reopt.destroy();
    try expectResolved(reopt, .color, "rgb(0, 0, 0)");
    try expectResolved(reopt, .color_scheme, "light dark");
    try expectResolved(reopt, .accent_color, "auto");
    try expectResolved(reopt, .scrollbar_color, "auto");
    try expectResolved(reopt, .font_variant_emoji, "text");

    // preserve-parent-color with explicit color keeps explicit color.
    const ppc_explicit = try cascadeOne(body, null, "forced-color-adjust: preserve-parent-color; color: orange; background-color: purple;", &light_forced_media, .{});
    defer ppc_explicit.destroy();
    try expectResolved(ppc_explicit, .color, "rgb(255, 165, 0)");
    try expectResolved(ppc_explicit, .background_color, "rgb(128, 0, 128)");

    // preserve-parent-color with no color / inherit / currentColor computes to parent's USED color (CanvasText).
    const ppc_default = try cascadeOne(body, null, "forced-color-adjust: preserve-parent-color; background-color: currentColor;", &light_forced_media, .{});
    defer ppc_default.destroy();
    try expectResolved(ppc_default, .color, "rgb(0, 0, 0)");
    try expectResolved(ppc_default, .background_color, "rgb(0, 0, 0)");

    const ppc_inherit = try cascadeOne(body, null, "forced-color-adjust: preserve-parent-color; color: inherit; background-color: purple;", &light_forced_media, .{});
    defer ppc_inherit.destroy();
    try expectResolved(ppc_inherit, .color, "rgb(0, 0, 0)");
    try expectResolved(ppc_inherit, .background_color, "rgb(128, 0, 128)");

    const ppc_current = try cascadeOne(body, null, "forced-color-adjust: preserve-parent-color; color: currentColor; background-color: purple;", &light_forced_media, .{});
    defer ppc_current.destroy();
    try expectResolved(ppc_current, .color, "rgb(0, 0, 0)");
    try expectResolved(ppc_current, .background_color, "rgb(128, 0, 128)");
}

test "forced-colors: color-mix() computed vs used, revert, and highlight pseudo-elements" {
    // §3.1 color-mix() example: computed value is blend; used value is forced to CanvasText.
    const mix = try cascadeOne(null, null, "color: color-mix(in srgb, CanvasText, Canvas);", &light_forced_media, .{ .is_root = true });
    defer mix.destroy();
    try expectComputed(mix, .color, "color(srgb 0.5 0.5 0.5)");
    try expectResolved(mix, .color, "rgb(0, 0, 0)");

    // revert rolls back to UA origin (LinkText).
    const reverted = try cascadeOne(null, "color: LinkText;", "color: red; color: revert;", &light_forced_media, .{ .is_root = true });
    defer reverted.destroy();
    try expectResolved(reverted, .color, "rgb(0, 0, 159)");

    // Highlight pseudo-element honors originating element's forced-color-adjust (WPT 14).
    const orig_auto = try cascadeOne(null, null, "", &light_forced_media, .{ .is_root = true });
    defer orig_auto.destroy();
    const sel_ignored = try cascadeOne(orig_auto, null, "forced-color-adjust: none; color: blue;", &light_forced_media, .{ .highlight = true });
    defer sel_ignored.destroy();
    try expectResolved(sel_ignored, .color, "rgb(0, 0, 0)");

    const orig_none = try cascadeOne(null, null, "forced-color-adjust: none;", &light_forced_media, .{ .is_root = true });
    defer orig_none.destroy();
    const sel_optout = try cascadeOne(orig_none, null, "color: blue;", &light_forced_media, .{ .highlight = true });
    defer sel_optout.destroy();
    try expectResolved(sel_optout, .color, "rgb(0, 0, 255)");
}
