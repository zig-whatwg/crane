//! Implementation for CanvasDrawImage interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasDrawImage = interfaces.CanvasDrawImage;
const dom = @import("dom");

pub const State = CanvasDrawImage.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: drawImage(image, dx, dy).
pub fn call_drawImage(instance: *runtime.Instance, image: typedefs.CanvasImageSource, dx: f64, dy: f64) anyerror!void {
    return drawImage(instance, image, null, .{ .x = dx, .y = dy, .w = null, .h = null });
}

/// Operation: drawImage(image, dx, dy, dw, dh).
pub fn call_drawImage__1(instance: *runtime.Instance, image: typedefs.CanvasImageSource, dx: f64, dy: f64, dw: f64, dh: f64) anyerror!void {
    return drawImage(instance, image, null, .{ .x = dx, .y = dy, .w = dw, .h = dh });
}

/// Operation: drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh).
pub fn call_drawImage__2(instance: *runtime.Instance, image: typedefs.CanvasImageSource, sx: f64, sy: f64, sw: f64, sh: f64, dx: f64, dy: f64, dw: f64, dh: f64) anyerror!void {
    return drawImage(instance, image, .{ sx, sy, sw, sh }, .{ .x = dx, .y = dy, .w = dw, .h = dh });
}

/// A destination rectangle; a null size defaults to the source's.
const Destination = struct { x: f64, y: f64, w: ?f64, h: ?f64 };

/// HTML 4.12.5.1.15, the drawImage() method steps, as pixel copies: this
/// context has no transformation matrix, global alpha, shadows, clipping
/// region or compositing operator other than the defaults (identity, 1.0,
/// none, none, source-over), whose effects are exactly a source-over copy.
///
/// Not modelled, stated: drawing at a different size, or at a fractional
/// position, needs the spec's filtering ("the user agent may use any
/// filtering algorithm ... when scaling up ... nearest-neighbor" only with
/// imageSmoothingEnabled false) - NotSupportedError, until the context has
/// a resampler (TODO). Video, ImageBitmap, OffscreenCanvas, VideoFrame and
/// SVG image sources are not implemented.
fn drawImage(instance: *runtime.Instance, image: typedefs.CanvasImageSource, given_source: ?[4]f64, given_destination: Destination) anyerror!void {
    const bitmap = dom.image_sources.outputBitmap(instance) orelse return error.NotImplemented;
    // 1. "If any of the arguments are infinite or NaN, then return."
    if (given_source) |values| for (values) |v| if (!std.math.isFinite(v)) return;
    for ([_]?f64{ given_destination.x, given_destination.y, given_destination.w, given_destination.h }) |value| {
        if (value) |v| if (!std.math.isFinite(v)) return;
    }
    // 2. Let usability be the result of checking the usability of image.
    const usability: dom.image_sources.Usability = switch (image) {
        .htmlor_svgimage_element => |element| switch (element) {
            .htmlimage_element => |img| dom.image_sources.imageUsability(img),
            // An SVG image element would be an img's twin; not implemented.
            .svgimage_element => return error.NotImplemented,
        },
        .htmlcanvas_element => |canvas| dom.image_sources.canvasUsability(canvas),
        // A video's readyState is not modelled past HAVE_NOTHING here: bad.
        .htmlvideo_element => .bad,
        .image_bitmap, .offscreen_canvas, .video_frame => return error.NotImplemented,
    };
    // 3. If usability is bad, return without drawing anything; an
    //    InvalidStateError is thrown by the check itself.
    const source_image = switch (usability) {
        .good => |good| good,
        .bad => return,
        .invalid_state => return error.InvalidStateError,
    };
    // 4. The source rectangle defaults to the whole image at its natural
    //    size; the destination size defaults to the source's.
    var sx, var sy, var sw, var sh = given_source orelse [4]f64{ 0, 0, @floatFromInt(source_image.width), @floatFromInt(source_image.height) };
    var dx = given_destination.x;
    var dy = given_destination.y;
    var dw = given_destination.w orelse sw;
    var dh = given_destination.h orelse sh;
    // "The image data must be processed in the original direction, even if
    // the dimensions given are negative": a negative size flips the
    // rectangle's corner, not the image.
    if (sw < 0) {
        sx += sw;
        sw = -sw;
    }
    if (sh < 0) {
        sy += sh;
        sh = -sh;
    }
    if (dw < 0) {
        dx += dw;
        dw = -dw;
    }
    if (dh < 0) {
        dy += dh;
        dh = -dh;
    }
    // 5. "If one of the sw or sh arguments is zero, then return."
    if (sw == 0 or sh == 0) return;
    // TODO: a resampler. Only a same-size copy at whole-pixel positions is
    // painted; anything else would need the spec's filtering.
    if (dw != sw or dh != sh) return error.NotSupportedError;
    if (!isWhole(sx) or !isWhole(sy) or !isWhole(sw) or !isWhole(sh) or !isWhole(dx) or !isWhole(dy)) return error.NotSupportedError;
    // "When the source rectangle is outside the source image, the source
    // rectangle must be clipped to the source image and the destination
    // rectangle must be clipped in the same proportion" - at scale 1, by the
    // same amounts.
    var left = sx;
    var top = sy;
    var right = sx + sw;
    var bottom = sy + sh;
    const image_width: f64 = @floatFromInt(source_image.width);
    const image_height: f64 = @floatFromInt(source_image.height);
    if (left < 0) {
        dx -= left;
        left = 0;
    }
    if (top < 0) {
        dy -= top;
        top = 0;
    }
    right = @min(right, image_width);
    bottom = @min(bottom, image_height);
    if (right <= left or bottom <= top) return;
    // 6. Paint the source rectangle onto the destination rectangle. Pixels
    //    landing outside the output bitmap are discarded.
    try paint(bitmap, source_image, .{
        .source_x = @intFromFloat(left),
        .source_y = @intFromFloat(top),
        .width = @intFromFloat(right - left),
        .height = @intFromFloat(bottom - top),
        .destination_x = @intFromFloat(dx),
        .destination_y = @intFromFloat(dy),
    });
    // 7. "If image is not origin-clean, then set the
    //    CanvasRenderingContext2D's origin-clean flag to false."
    if (!source_image.origin_clean) bitmap.origin_clean = false;
}

fn isWhole(value: f64) bool {
    return @floor(value) == value and @abs(value) < 1 << 31;
}

const Copy = struct {
    source_x: i64,
    source_y: i64,
    width: i64,
    height: i64,
    destination_x: i64,
    destination_y: i64,
};

/// Source-over each pixel of the source rectangle onto the bitmap. "When a
/// canvas element is drawn onto itself, the drawing model requires the
/// source to be copied before the image is drawn": a source that is this
/// bitmap is copied first.
fn paint(bitmap: *dom.image_sources.OutputBitmap, source_image: dom.image_sources.ImageSource, copy: Copy) !void {
    var pixels = source_image.pixels;
    var stride: usize = @as(usize, source_image.width) * 4;
    var origin_x = copy.source_x;
    var origin_y = copy.source_y;
    var copied: ?[]u8 = null;
    defer if (copied) |c| bitmap.allocator.free(c);
    if (pixels.ptr == bitmap.pixels.ptr) {
        const row_bytes: usize = @intCast(copy.width * 4);
        const c = try bitmap.allocator.alloc(u8, row_bytes * @as(usize, @intCast(copy.height)));
        for (0..@intCast(copy.height)) |row| {
            const from = (@as(usize, @intCast(copy.source_y)) + row) * stride + @as(usize, @intCast(copy.source_x)) * 4;
            @memcpy(c[row * row_bytes ..][0..row_bytes], pixels[from..][0..row_bytes]);
        }
        copied = c;
        pixels = c;
        stride = row_bytes;
        origin_x = 0;
        origin_y = 0;
    }
    const bitmap_width: i64 = bitmap.width;
    const bitmap_height: i64 = bitmap.height;
    var row: i64 = 0;
    while (row < copy.height) : (row += 1) {
        const y = copy.destination_y + row;
        if (y < 0 or y >= bitmap_height) continue;
        var column: i64 = 0;
        while (column < copy.width) : (column += 1) {
            const x = copy.destination_x + column;
            if (x < 0 or x >= bitmap_width) continue;
            const from: usize = @as(usize, @intCast(origin_y + row)) * stride + @as(usize, @intCast(origin_x + column)) * 4;
            const s = pixels[from..][0..4];
            const source_pixel: [4]u8 = switch (source_image.alpha) {
                .premultiplied => s.*,
                .straight => .{
                    dom.image_sources.premultiply(s[0], s[3]),
                    dom.image_sources.premultiply(s[1], s[3]),
                    dom.image_sources.premultiply(s[2], s[3]),
                    s[3],
                },
            };
            const to: usize = @as(usize, @intCast(y * bitmap_width + x)) * 4;
            dom.image_sources.sourceOver(bitmap.pixels[to..][0..4], source_pixel);
        }
    }
}
