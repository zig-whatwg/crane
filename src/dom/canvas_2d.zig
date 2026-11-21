//! HTML 4.12.5.1 (CanvasRenderingContext2D) and 4.12.5.3.1
//! (OffscreenCanvasRenderingContext2D): the state a 2D rendering context
//! keeps - its output bitmap and the drawing state the context's mixins
//! read and write (the fill and stroke styles, the dash list) - and the
//! painting those mixins share. The two context interfaces include the same
//! mixins (CanvasFillStrokeStyles, CanvasPathDrawingStyles, CanvasRect,
//! CanvasImageData, CanvasDrawImage), and a mixin's members are implemented
//! once, in the mixin's impl: each context owns a `Context2D` and installs
//! the step that finds it (`stateOf`), so the mixins never name a context's
//! impl.
//!
//! The drawing state (4.12.5.1.3) is one value, `DrawingState`, which
//! save() pushes and restore() pops whole. Painting reads the fill and
//! stroke styles, global alpha, line width and line cap; the current
//! transformation matrix and clipping region are not modelled yet (their
//! methods are not implemented), and shadows, filters, the compositing
//! operator other than source-over, dashes and round or bevel joins are not
//! painted yet (TODO: each is kept in the state and read back, as the
//! attributes require, but a shape is still a source-over of its coverage).
//!
//! lint-impls: hook for CanvasRenderingContext2D, OffscreenCanvasRenderingContext2D

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const css = @import("css");
const enums = @import("enums");
const image_sources = @import("image_sources.zig");

/// A CSS color as a 2D context keeps it: sRGB with 8-bit channels and 8-bit
/// alpha, as Chrome, Firefox and Safari keep a canvas color (their
/// serialization of it is 8-bit quantized: fillStyle = "rgba(0,0,0,0.3)"
/// reads back as alpha 0.3 = 77/255).
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const black: Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const transparent_black: Color = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

    /// The color premultiplied by its alpha scaled by `coverage` (0-1): the
    /// premultiplied source a shape covering that much of a pixel paints.
    fn premultipliedSource(self: Color, coverage: f64) [4]u8 {
        const alpha: u8 = @intFromFloat(@round(@as(f64, @floatFromInt(self.a)) * std.math.clamp(coverage, 0, 1)));
        return .{
            image_sources.premultiply(self.r, alpha),
            image_sources.premultiply(self.g, alpha),
            image_sources.premultiply(self.b, alpha),
            alpha,
        };
    }
};

/// A fill or stroke style (4.12.5.1.10): a CSS color. A CanvasGradient or
/// CanvasPattern is the other kind - none can exist yet: their factories
/// (createLinearGradient, createPattern, ...) are not implemented.
pub const Style = union(enum) {
    color: Color,
};

/// A canvas bitmap larger than this many pixels (Blink's limit, 2^28: 1 GiB
/// of RGBA8) gets no pixels: it is 0 x 0, so nothing is drawn on it and it
/// reads back as transparent black.
pub const max_bitmap_pixels: u64 = 1 << 28;

/// The compositing and blending operators (4.12.5.1.17): the values
/// Compositing and Blending 1's <blend-mode> and <composite-mode> take
/// (HTML's [COMPOSITE] reference), in the order of `operators`.
pub const operators = [_][]const u8{
    // <composite-mode>
    "clear",          "copy",       "source-over",     "destination-over", "source-in",
    "destination-in", "source-out", "destination-out", "source-atop",      "destination-atop",
    "xor",            "lighter",
    // <blend-mode>
       "normal",          "multiply",         "screen",
    "overlay",        "darken",     "lighten",         "color-dodge",      "color-burn",
    "hard-light",     "soft-light", "difference",      "exclusion",        "hue",
    "saturation",     "color",      "luminosity",
};
const source_over: u8 = 2;

/// A context's drawing state (4.12.5.1.3), as one value: everything it
/// consists of that this context models, each at its initial value. The
/// owned strings are null at their initial value. Copy it only with
/// `clone`; free it with `deinit`.
pub const DrawingState = struct {
    /// The dash list (CanvasPathDrawingStyles), OWNED.
    line_dash: []f64 = &.{},
    line_dash_offset: f64 = 0,
    /// "Initially, both must be the result of parsing the string
    /// "#000000"."
    fill_style: Style = .{ .color = Color.black },
    stroke_style: Style = .{ .color = Color.black },
    /// 4.12.5.1.4: "initially ... 1.0", "butt", "miter", "10.0".
    line_width: f64 = 1.0,
    line_cap: enums.CanvasLineCap = ._butt_,
    line_join: enums.CanvasLineJoin = ._miter_,
    miter_limit: f64 = 10.0,
    /// 4.12.5.1.17: global alpha 1.0; the operator an index into
    /// `operators`, initially source-over.
    global_alpha: f64 = 1.0,
    composite_operator: u8 = source_over,
    /// 4.12.5.1.19: offsets and blur 0; the shadow color transparent black.
    shadow_offset_x: f64 = 0,
    shadow_offset_y: f64 = 0,
    shadow_blur: f64 = 0,
    shadow_color: Color = Color.transparent_black,
    /// 4.12.5.1.20: the current filter, a string, initially "none"; OWNED.
    filter: ?[]u8 = null,
    /// 4.12.5.1.5: the font, the serialization of the computed font,
    /// initially "10px sans-serif"; OWNED.
    font: ?[]u8 = null,
    text_align: enums.CanvasTextAlign = ._start_,
    text_baseline: enums.CanvasTextBaseline = ._alphabetic_,
    direction: enums.CanvasDirection = ._inherit_,
    /// The letter and word spacing, serialized CSS <length>s, initially
    /// "0px"; OWNED.
    letter_spacing: ?[]u8 = null,
    word_spacing: ?[]u8 = null,
    font_kerning: enums.CanvasFontKerning = ._auto_,
    font_stretch: enums.CanvasFontStretch = ._normal_,
    font_variant_caps: enums.CanvasFontVariantCaps = ._normal_,
    text_rendering: enums.CanvasTextRendering = ._auto_,
    /// The language, initially "inherit"; OWNED.
    lang: ?[]u8 = null,
    /// 4.12.5.1.18: true, and "low".
    image_smoothing_enabled: bool = true,
    image_smoothing_quality: enums.ImageSmoothingQuality = ._low_,

    pub const initial_filter = "none";
    pub const initial_font = "10px sans-serif";
    pub const initial_spacing = "0px";
    pub const initial_lang = "inherit";

    /// A copy owning copies of the strings and the dash list.
    pub fn clone(self: *const DrawingState, allocator: Allocator) Allocator.Error!DrawingState {
        var copy = self.*;
        copy.line_dash = &.{};
        copy.filter = null;
        copy.font = null;
        copy.letter_spacing = null;
        copy.word_spacing = null;
        copy.lang = null;
        errdefer copy.deinit(allocator);
        if (self.line_dash.len > 0) copy.line_dash = try allocator.dupe(f64, self.line_dash);
        inline for (.{ "filter", "font", "letter_spacing", "word_spacing", "lang" }) |name| {
            if (@field(self, name)) |text| @field(copy, name) = try allocator.dupe(u8, text);
        }
        return copy;
    }

    pub fn deinit(self: *DrawingState, allocator: Allocator) void {
        if (self.line_dash.len > 0) allocator.free(self.line_dash);
        inline for (.{ "filter", "font", "letter_spacing", "word_spacing", "lang" }) |name| {
            if (@field(self, name)) |text| allocator.free(text);
        }
        self.* = .{};
    }

    /// Replace the owned string `field` (one of the optional string fields)
    /// with a copy of `text`; its initial value when `text` is `initial`.
    pub fn setText(self: *DrawingState, allocator: Allocator, comptime field: []const u8, text: []const u8, initial: []const u8) Allocator.Error!void {
        const copy: ?[]u8 = if (std.mem.eql(u8, text, initial)) null else try allocator.dupe(u8, text);
        if (@field(self, field)) |old| allocator.free(old);
        @field(self, field) = copy;
    }
};

/// A 2D rendering context's state: its output bitmap (shared with its
/// canvas), its drawing state and the stack save() pushes it on.
pub const Context2D = struct {
    allocator: Allocator,
    /// The output bitmap: premultiplied RGBA8 with its origin-clean flag.
    bitmap: image_sources.OutputBitmap,
    /// The current drawing state.
    drawing: DrawingState = .{},
    /// The drawing state stack (4.12.5.1.3), OWNED.
    stack: std.ArrayList(DrawingState) = .empty,
    /// CanvasState's context lost flag: "initialized to false when the
    /// object is created". Nothing loses a context here (no GPU).
    context_lost: bool = false,

    pub fn init(allocator: Allocator) Context2D {
        return .{ .allocator = allocator, .bitmap = .{ .allocator = allocator } };
    }

    /// "Reset the rendering context to its default state" (4.12.5.1.3)
    /// steps 3 and 4 for the state this context models: the drawing state
    /// stack is cleared and the drawing state is reset to its initial
    /// values (step 2's path is not modelled). Step 1, clearing the bitmap,
    /// is the caller's ("set bitmap dimensions" resizes it; reset() clears
    /// it: `clearBitmap`).
    pub fn reset(self: *Context2D) void {
        for (self.stack.items) |*saved| saved.deinit(self.allocator);
        self.stack.clearRetainingCapacity();
        self.drawing.deinit(self.allocator);
    }

    /// save(): "push a copy of the current drawing state onto the drawing
    /// state stack".
    pub fn save(self: *Context2D) Allocator.Error!void {
        var copy = try self.drawing.clone(self.allocator);
        errdefer copy.deinit(self.allocator);
        try self.stack.append(self.allocator, copy);
    }

    /// restore(): "pop the top entry in the drawing state stack, and reset
    /// the drawing state it describes. If there is no saved state, then the
    /// method must do nothing."
    pub fn restore(self: *Context2D) void {
        const saved = self.stack.pop() orelse return;
        self.drawing.deinit(self.allocator);
        self.drawing = saved;
    }

    /// Step 1 of resetting to the default state: "Clear canvas's bitmap to
    /// transparent black."
    pub fn clearBitmap(self: *Context2D) void {
        @memset(self.bitmap.pixels, 0);
    }

    pub fn deinit(self: *Context2D) void {
        self.reset();
        self.stack.deinit(self.allocator);
        self.bitmap.deinit();
    }
};

/// The step each kind of context installs: its Context2D, or null for an
/// object that is not that kind (or whose state is gone).
pub const StateOf = *const fn (context: *runtime.Instance) ?*Context2D;

/// The steps OffscreenCanvasRenderingContext2D installs: its state, and
/// the resize its OffscreenCanvas's width and height setters run.
pub const OffscreenSteps = struct {
    state_of: StateOf,
    /// "Reset the rendering context to its default state and resize the
    /// OffscreenCanvas object's bitmap to the new values of the width and
    /// height attributes" (4.12.5.3).
    set_bitmap_dimensions: *const fn (context: *runtime.Instance, width: u64, height: u64) anyerror!void,
};

/// CanvasRenderingContext2D's installHooks (the step lives in
/// dom.image_sources' one hook table).
pub fn installElementContext(state_of: StateOf) void {
    image_sources.installElementContextState(state_of);
}

/// OffscreenCanvasRenderingContext2D's installHooks.
pub fn installOffscreenContext(steps: OffscreenSteps) void {
    image_sources.installOffscreenContextSteps(steps);
}

/// The OffscreenCanvas width and height setters' steps for its 2d context
/// `context`.
pub fn resizeOffscreen(context: *runtime.Instance, width: u64, height: u64) !void {
    const offscreen = image_sources.installed().offscreen_context orelse return error.NotSupported;
    return offscreen.set_bitmap_dimensions(context, width, height);
}

/// `context`'s state: a CanvasRenderingContext2D's or an
/// OffscreenCanvasRenderingContext2D's; null for anything else.
pub fn stateOf(context: *runtime.Instance) ?*Context2D {
    const table = image_sources.installed();
    if (table.element_context_state) |element| if (element(context)) |state| return state;
    const offscreen = table.offscreen_context orelse return null;
    return offscreen.state_of(context);
}

// ---------------------------------------------------------------------------
// Colors (4.12.5.1.10)
// ---------------------------------------------------------------------------

/// HTML "parse a CSS <color> value" for a fill or stroke style given
/// `text`: the color, or null on failure. With no context element,
/// currentcolor is opaque black (CSS Color 4 4.5 step 2: the initial value
/// of 'color' - an OffscreenCanvas's context, and a canvas element's until
/// its computed 'color' is read here: stated, the element's own color is
/// not consulted yet).
pub fn parseColor(text: []const u8) ?Color {
    // The parser's scratch on the stack: its error set has no OutOfMemory,
    // so an allocation failure would read as "not a color".
    var buffer: [4096]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const float = css.ColorParser.parseWithoutContext(text, fixed.allocator()) catch return null;
    const quantized = float.quantize();
    return .{
        .r = quantized.r,
        .g = quantized.g,
        .b = quantized.b,
        .a = @intFromFloat(@round(std.math.clamp(quantized.a, 0, 1) * 255)),
    };
}

/// The serialization of `color` with HTML-compatible serialization
/// requested (CSS Color 4 15.2 / HTML 4.12.5.1.10): "#rrggbb" in lowercase
/// hex when opaque, otherwise "rgba(r, g, b, a)" with the alpha in its
/// shortest form at 8 bits. OWNED by `allocator`.
pub fn serializeColor(allocator: Allocator, color: Color) Allocator.Error![]u8 {
    if (color.a == 255) return std.fmt.allocPrint(allocator, "#{x:0>2}{x:0>2}{x:0>2}", .{ color.r, color.g, color.b });
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try css.style_values.serializeRgba(.{ .r = color.r, .g = color.g, .b = color.b, .a = @as(f32, @floatFromInt(color.a)) / 255 }, &out, allocator);
    return out.toOwnedSlice(allocator);
}

// ---------------------------------------------------------------------------
// Text styles (4.12.5.1.5) and filters (4.12.5.1.20)
// ---------------------------------------------------------------------------

const Block = css.declarations.DeclarationBlock;

/// Whether every longhand of `block`'s declaration of `longhands` is a value:
/// no CSS-wide keyword ("without supporting property-independent style sheet
/// syntax like 'inherit'"), and no var() (property-independent too).
fn plainValues(block: *const Block, longhands: []const css.properties.Longhand) bool {
    for (longhands) |l| {
        const declaration = block.get(l) orelse return false;
        switch (declaration.value) {
            .css_wide => return false,
            .value => |v| if (v == .pending) return false,
        }
    }
    return true;
}

/// The `font` setter's parsing (4.12.5.1.5): `text` parsed as a CSS
/// <'font'> value without CSS-wide keywords, computed - "with the
/// 'line-height' component forced to 'normal', with the 'font-size'
/// component converted to CSS pixels" - and serialized as the getter
/// returns it, "with no 'line-height' component". OWNED; null when it does
/// not parse (the setter then ignores it). Relative sizes and weights are
/// computed against "the normal-weight 10px sans-serif default". TODO: a
/// canvas element being rendered is the font style source object, its
/// computed font the base instead; the element is not consulted yet (as
/// parseColor's currentcolor is not).
pub fn parseFont(allocator: Allocator, text: []const u8) Allocator.Error!?[]u8 {
    const options: css.properties.ParseOptions = .{ .allocator = allocator };
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(options, "font", text, "")) return null;
    const longhands = &css.font_shorthand.longhands;
    if (!plainValues(&block, longhands)) return null;

    var default_block = Block.init(allocator);
    defer default_block.deinit();
    _ = try default_block.setProperty(options, "font", DrawingState.initial_font, "");
    const default_style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &default_block, .source = .{ .origin = .author } }});
    defer default_style.destroy();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = default_style }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();

    var assigned: [longhands.len]css.properties.Assigned = undefined;
    for (longhands, 0..) |l, i| assigned[i] = .{ .value = if (l == .line_height) css.style_values.Value.kw(.normal) else style.get(l) };
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (!try css.properties.serializeShorthand(.font, &assigned, .computed, &out, allocator)) {
        out.deinit(allocator);
        return null;
    }
    return try out.toOwnedSlice(allocator);
}

/// The letterSpacing and wordSpacing setters' parsing: `text` as a CSS
/// <length>, serialized; OWNED, or null when it is not one (ignored then).
pub fn parseLength(allocator: Allocator, text: []const u8) Allocator.Error!?[]u8 {
    const options: css.properties.ParseOptions = .{ .allocator = allocator };
    var stream = css.properties.Stream.init(text);
    // outline-offset's grammar is exactly <length>, of either sign.
    const value = (try css.properties.parseLonghand(options, .outline_offset, &stream)) orelse return null;
    defer value.release();
    if (!stream.atEnd()) return null;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try css.properties.serializeValue(.outline_offset, value, &out, allocator);
    return try out.toOwnedSlice(allocator);
}

/// The filter setter's step 2: whether `text` parses as a
/// <filter-value-list> with no property-independent syntax.
pub fn isFilterValueList(allocator: Allocator, text: []const u8) Allocator.Error!bool {
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, "filter", text, "")) return false;
    if (!plainValues(&block, &.{.filter})) return false;
    // `none` is filter's other value, not a <filter-value-list> (step 1
    // takes the exact string "none").
    const declaration = block.get(.filter).?;
    return !declaration.value.value.isKeyword(.none);
}

// ---------------------------------------------------------------------------
// Painting (4.12.5.1.14, CanvasRect)
// ---------------------------------------------------------------------------

/// An axis-aligned rectangle in bitmap coordinates, with a positive size.
pub const Rect = struct {
    left: f64,
    top: f64,
    right: f64,
    bottom: f64,

    /// The rectangle with corners (x, y) and (x + w, y + h): a negative
    /// width or height puts the corner on the other side.
    pub fn of(x: f64, y: f64, w: f64, h: f64) Rect {
        return .{ .left = @min(x, x + w), .top = @min(y, y + h), .right = @max(x, x + w), .bottom = @max(y, y + h) };
    }

    fn isEmpty(self: Rect) bool {
        return !(self.right > self.left and self.bottom > self.top);
    }

    /// The fraction of the pixel at (column, row) this rectangle covers.
    fn coverage(self: Rect, column: usize, row: usize) f64 {
        const x: f64 = @floatFromInt(column);
        const y: f64 = @floatFromInt(row);
        const width = @min(x + 1, self.right) - @max(x, self.left);
        const height = @min(y + 1, self.bottom) - @max(y, self.top);
        if (width <= 0 or height <= 0) return 0;
        return width * height;
    }
};

/// The pixels of `bitmap` a shape could touch: its bounds, clamped to the
/// bitmap. Empty when it touches none.
const Span = struct {
    first_column: usize,
    end_column: usize,
    first_row: usize,
    end_row: usize,

    fn of(bitmap: *const image_sources.OutputBitmap, bounds: Rect) ?Span {
        const width: f64 = @floatFromInt(bitmap.width);
        const height: f64 = @floatFromInt(bitmap.height);
        const left = @max(bounds.left, 0);
        const top = @max(bounds.top, 0);
        const right = @min(bounds.right, width);
        const bottom = @min(bounds.bottom, height);
        if (!(right > left and bottom > top)) return null;
        return .{
            .first_column = @intFromFloat(@floor(left)),
            .end_column = @intFromFloat(@ceil(right)),
            .first_row = @intFromFloat(@floor(top)),
            .end_row = @intFromFloat(@ceil(bottom)),
        };
    }
};

/// Paint `color` over the area `outer` covers less what `inner` covers
/// (inner inside outer, or null), source-over, each pixel by its coverage
/// (the edges anti-aliased by area, as the browsers' rasterizers do).
fn paint(bitmap: *image_sources.OutputBitmap, outer: Rect, inner: ?Rect, color: Color) void {
    if (outer.isEmpty() or color.a == 0) return;
    const span = Span.of(bitmap, outer) orelse return;
    const stride = @as(usize, bitmap.width) * 4;
    var row = span.first_row;
    while (row < span.end_row) : (row += 1) {
        var column = span.first_column;
        while (column < span.end_column) : (column += 1) {
            var covered = outer.coverage(column, row);
            if (inner) |hole| if (!hole.isEmpty()) {
                covered -= hole.coverage(column, row);
            };
            if (covered <= 0) continue;
            const pixel: *[4]u8 = bitmap.pixels[row * stride + column * 4 ..][0..4];
            image_sources.sourceOver(pixel, color.premultipliedSource(covered));
        }
    }
}

/// A style's color with the global alpha applied (4.12.5.1.17: "an alpha
/// value that is applied to shapes and images before they are composited").
fn withGlobalAlpha(color: Color, global_alpha: f64) Color {
    var out = color;
    out.a = @intFromFloat(@round(@as(f64, @floatFromInt(color.a)) * std.math.clamp(global_alpha, 0, 1)));
    return out;
}

/// fillRect(x, y, w, h) steps 2-3 (step 1, the non-finite check, is the
/// caller's): paint the rectangle with `style`.
pub fn fillRect(state: *Context2D, x: f64, y: f64, w: f64, h: f64) void {
    switch (state.drawing.fill_style) {
        .color => |color| paint(&state.bitmap, Rect.of(x, y, w, h), null, withGlobalAlpha(color, state.drawing.global_alpha)),
    }
}

/// clearRect(x, y, w, h) step 2: "Let pixels be the set of pixels in the
/// specified rectangle that also intersect the current clipping region",
/// cleared to transparent black - a pixel the rectangle only partly covers
/// keeps the uncovered part.
pub fn clearRect(state: *Context2D, x: f64, y: f64, w: f64, h: f64) void {
    const bitmap = &state.bitmap;
    const rect = Rect.of(x, y, w, h);
    if (rect.isEmpty()) return;
    const span = Span.of(bitmap, rect) orelse return;
    const stride = @as(usize, bitmap.width) * 4;
    var row = span.first_row;
    while (row < span.end_row) : (row += 1) {
        var column = span.first_column;
        while (column < span.end_column) : (column += 1) {
            const covered = rect.coverage(column, row);
            if (covered <= 0) continue;
            const keep: u8 = @intFromFloat(@round((1 - std.math.clamp(covered, 0, 1)) * 255));
            const pixel: *[4]u8 = bitmap.pixels[row * stride + column * 4 ..][0..4];
            for (pixel) |*channel| channel.* = image_sources.premultiply(channel.*, keep);
        }
    }
}

/// strokeRect(x, y, w, h) step 2: the path of the rectangle traced with the
/// line styles and filled with `style`. Both w and h zero: an empty path,
/// nothing drawn. One zero: a single line from (x, y) to (x + w, y + h),
/// capped: a butt cap ends it at its points, a square cap half the line
/// width past them. Otherwise a closed path of four lines whose
/// right-angled corners are mitred, so the trace is the rectangle grown by
/// half the line width less the rectangle shrunk by it. TODO: round caps,
/// round and bevel joins, a miter limit under sqrt 2 (which bevels the
/// corners) and the dash list are not traced yet: those shapes paint as
/// butt caps and miter joins.
pub fn strokeRect(state: *Context2D, x: f64, y: f64, w: f64, h: f64) void {
    const half = state.drawing.line_width / 2;
    const color = withGlobalAlpha(switch (state.drawing.stroke_style) {
        .color => |color| color,
    }, state.drawing.global_alpha);
    if (w == 0 and h == 0) return;
    const rect = Rect.of(x, y, w, h);
    if (w == 0 or h == 0) {
        // One line: its caps end it at its points (butt) or half the line
        // width past them (square).
        const cap: f64 = if (state.drawing.line_cap == ._square_) half else 0;
        const line: Rect = if (w == 0)
            .{ .left = x - half, .right = x + half, .top = rect.top - cap, .bottom = rect.bottom + cap }
        else
            .{ .left = rect.left - cap, .right = rect.right + cap, .top = y - half, .bottom = y + half };
        return paint(&state.bitmap, line, null, color);
    }
    const outer: Rect = .{ .left = rect.left - half, .top = rect.top - half, .right = rect.right + half, .bottom = rect.bottom + half };
    const inner: Rect = .{ .left = rect.left + half, .top = rect.top + half, .right = rect.right - half, .bottom = rect.bottom - half };
    paint(&state.bitmap, outer, inner, color);
}

test "parseColor quantizes to 8-bit sRGB with 8-bit alpha; serializeColor is HTML-compatible" {
    const allocator = std.testing.allocator;
    const red = parseColor("red").?;
    try std.testing.expectEqual(Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, red);
    const opaque_text = try serializeColor(allocator, red);
    defer allocator.free(opaque_text);
    try std.testing.expectEqualStrings("#ff0000", opaque_text);
    const translucent = parseColor("rgba(0, 0, 255, 0.3)").?;
    try std.testing.expectEqual(@as(u8, 77), translucent.a);
    const translucent_text = try serializeColor(allocator, translucent);
    defer allocator.free(translucent_text);
    try std.testing.expectEqualStrings("rgba(0, 0, 255, 0.3)", translucent_text);
    try std.testing.expect(parseColor("not a color") == null);
    try std.testing.expectEqual(Color.black, parseColor("currentcolor").?);
}

test "fillRect paints whole pixels exactly and a half-covered pixel at half alpha" {
    const allocator = std.testing.allocator;
    var state = Context2D.init(allocator);
    defer state.deinit();
    try state.bitmap.resize(3, 1);
    state.drawing.fill_style = .{ .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 } };
    fillRect(&state, 0, 0, 1.5, 1);
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 0, 255 }, state.bitmap.pixels[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 128, 0, 0, 128 }, state.bitmap.pixels[4..8]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, state.bitmap.pixels[8..12]);
    // A negative size draws on the other side of the corner.
    fillRect(&state, 3, 1, -1, -1);
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 0, 255 }, state.bitmap.pixels[8..12]);
}

test "clearRect clears what it covers; strokeRect traces the rectangle's outline" {
    const allocator = std.testing.allocator;
    var state = Context2D.init(allocator);
    defer state.deinit();
    try state.bitmap.resize(4, 4);
    state.drawing.fill_style = .{ .color = Color.black };
    fillRect(&state, 0, 0, 4, 4);
    clearRect(&state, 1, 1, 2, 2);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 255 }, state.bitmap.pixels[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, state.bitmap.pixels[(1 * 4 + 1) * 4 ..][0..4]);
    clearRect(&state, 0, 0, 4, 4);
    // A 1-wide stroke of the rectangle (0.5, 0.5)-(3.5, 3.5) covers the
    // edge pixels exactly and leaves the middle.
    strokeRect(&state, 0.5, 0.5, 3, 3);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 255 }, state.bitmap.pixels[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, state.bitmap.pixels[(1 * 4 + 1) * 4 ..][0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 255 }, state.bitmap.pixels[(3 * 4 + 3) * 4 ..][0..4]);
}
