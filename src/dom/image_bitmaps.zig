//! HTML 8.11.2 ImageBitmap and 4.12.5.3 OffscreenCanvas: the bitmaps their
//! transfer steps carry to another realm - possibly another thread's - and
//! the steps with no IDL member that the one shared transfer step
//! (dom.transferables) runs for them: whether an object is one of them and
//! detached, its transfer steps (which make its data holder) and its
//! transfer-receiving steps (which make the new object from it). ImageBitmap
//! and OffscreenCanvas install them at process start; nothing else names
//! their impls.
//!
//! A data holder is free of any realm, agent and thread: plain pixels and
//! dimensions, in memory of the allocator of the realm that made it - a
//! realm's allocator is the Browser's, safe to free from any of its threads
//! (dom.port_channels: a message's holders are freed by the receiving
//! thread).
//!
//! lint-impls: hook for ImageBitmap, OffscreenCanvas

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const platform = @import("platform");
const mimesniff = @import("mimesniff");
const image_sources = @import("image_sources.zig");

/// An ImageBitmap's bitmap data (8.11.2): `width` x `height` RGBA8 pixels,
/// rows top down, as `alpha` says, with the origin-clean flag of the bitmap.
/// What an ImageBitmap owns, what createImageBitmap makes for it, and the
/// data holder its transfer steps fill ([[BitmapData]]).
pub const Bitmap = struct {
    allocator: Allocator,
    width: u32,
    height: u32,
    /// `width * height * 4` bytes, OWNED by `allocator`.
    pixels: []u8,
    /// premultiplyAlpha "none" keeps a source's straight alpha; every other
    /// bitmap is premultiplied (a canvas's bitmap is, 4.12.5.7).
    alpha: @FieldType(image_sources.ImageSource, "alpha") = .premultiplied,
    /// 8.11.2: "initially set to true and may be changed to false by the
    /// steps of createImageBitmap()".
    origin_clean: bool = true,

    /// A new transparent black bitmap of `width` x `height`. OWNED:
    /// `destroy`.
    pub fn create(allocator: Allocator, width: u32, height: u32) error{OutOfMemory}!*Bitmap {
        const len = std.math.mul(usize, std.math.mul(usize, width, height) catch return error.OutOfMemory, 4) catch return error.OutOfMemory;
        const pixels = try allocator.alloc(u8, len);
        errdefer allocator.free(pixels);
        @memset(pixels, 0);
        const self = try allocator.create(Bitmap);
        self.* = .{ .allocator = allocator, .width = width, .height = height, .pixels = pixels };
        return self;
    }

    /// A copy of `self`, with its own pixels, in `allocator`. OWNED.
    pub fn clone(self: *const Bitmap, allocator: Allocator) error{OutOfMemory}!*Bitmap {
        const copy = try create(allocator, self.width, self.height);
        @memcpy(copy.pixels, self.pixels);
        copy.alpha = self.alpha;
        copy.origin_clean = self.origin_clean;
        return copy;
    }

    pub fn destroy(self: *Bitmap) void {
        const allocator = self.allocator;
        allocator.free(self.pixels);
        allocator.destroy(self);
    }

    /// The bitmap as an image source a 2D context draws from. BORROWED
    /// while `self` lives.
    pub fn source(self: *const Bitmap) image_sources.ImageSource {
        return .{ .width = self.width, .height = self.height, .pixels = self.pixels, .alpha = self.alpha, .origin_clean = self.origin_clean };
    }
};

/// An OffscreenCanvas's data holder (4.12.5.3, its transfer steps 6-7):
/// [[Width]] and [[Height]] - its bitmap's dimensions - and [[Language]]
/// and [[Direction]], its inherited language and direction. A transferred
/// canvas has no placeholder canvas element here (none is ever made:
/// transferControlToOffscreen is not modelled), so [[PlaceholderCanvas]] is
/// always null.
pub const CanvasHolder = struct {
    allocator: Allocator,
    width: u64,
    height: u64,
    /// The inherited language: null is "explicitly unknown". OWNED.
    language: ?[]u8 = null,
    direction: Direction = .ltr,

    pub const Direction = enum { ltr, rtl };

    pub fn destroy(self: *CanvasHolder) void {
        const allocator = self.allocator;
        if (self.language) |language| allocator.free(language);
        allocator.destroy(self);
    }
};

/// The steps ImageBitmap installs.
pub const ImageBitmapSteps = struct {
    /// Whether `instance` is an ImageBitmap, and a detached one (HTML 2.7.8
    /// StructuredSerializeWithTransfer steps 2.1 and 5.2).
    state: *const fn (instance: *runtime.Instance) runtime.TransferableState,
    /// ImageBitmap's transfer steps for `instance`: its bitmap data, taken
    /// (the holder is the caller's), and `instance` detached.
    /// error.DataCloneError when its bitmap is not origin-clean (step 1).
    transfer: *const fn (instance: *runtime.Instance) anyerror!*Bitmap,
    /// ImageBitmap's transfer-receiving steps: a new ImageBitmap of `realm`
    /// with `bitmap`, which it takes - also on failure.
    receive: *const fn (realm: runtime.Context, bitmap: *Bitmap) anyerror!*runtime.Instance,
};

/// The steps OffscreenCanvas installs.
pub const OffscreenCanvasSteps = struct {
    /// Whether `instance` is an OffscreenCanvas, and a detached one.
    state: *const fn (instance: *runtime.Instance) runtime.TransferableState,
    /// OffscreenCanvas's transfer steps for `instance` (InvalidStateError
    /// when its context mode is not none, step 1).
    transfer: *const fn (instance: *runtime.Instance) anyerror!*CanvasHolder,
    /// OffscreenCanvas's transfer-receiving steps: a new OffscreenCanvas of
    /// `realm` from `holder`, which it takes - also on failure.
    receive: *const fn (realm: runtime.Context, holder: *CanvasHolder) anyerror!*runtime.Instance,
};

/// ImageBitmap's installHooks, once, at process start (the steps live in
/// dom.image_sources' one hook table).
pub fn installImageBitmap(steps: ImageBitmapSteps) void {
    image_sources.installImageBitmapTransfer(steps);
}

/// OffscreenCanvas's installHooks, once, at process start.
pub fn installOffscreenCanvas(steps: OffscreenCanvasSteps) void {
    image_sources.installOffscreenCanvasTransfer(steps);
}

/// The steps their owners installed, as dom.image_sources' table holds them.
const Installed = struct {
    image_bitmap: ?ImageBitmapSteps,
    offscreen_canvas: ?OffscreenCanvasSteps,

    fn read() Installed {
        const table = image_sources.installed();
        return .{ .image_bitmap = table.image_bitmap_transfer, .offscreen_canvas = table.offscreen_canvas_transfer };
    }
};

/// Whether `instance` is a transferable ImageBitmap or OffscreenCanvas
/// (StructuredSerializeWithTransfer step 2.1), and a detached one (5.2).
pub fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const steps = Installed.read();
    if (steps.image_bitmap) |owner| {
        const state = owner.state(instance);
        if (state != .not_transferable) return state;
    }
    if (steps.offscreen_canvas) |owner| return owner.state(instance);
    return .not_transferable;
}

/// What a transfer of an ImageBitmap or OffscreenCanvas holds.
pub const Holder = union(enum) {
    image_bitmap: *Bitmap,
    offscreen_canvas: *CanvasHolder,
};

/// StructuredSerializeWithTransfer steps 5.2-5.6 for an ImageBitmap or an
/// OffscreenCanvas: refused when detached (5.2, DataCloneError), its
/// interface's transfer steps (5.5) and [[Detached]] set (5.6, by them).
/// null when `instance` is neither.
pub fn transfer(instance: *runtime.Instance) !?Holder {
    const steps = Installed.read();
    if (steps.image_bitmap) |owner| switch (owner.state(instance)) {
        .not_transferable => {},
        .detached => return error.DataCloneError,
        .transferable => return .{ .image_bitmap = try owner.transfer(instance) },
    };
    if (steps.offscreen_canvas) |owner| switch (owner.state(instance)) {
        .not_transferable => {},
        .detached => return error.DataCloneError,
        .transferable => return .{ .offscreen_canvas = try owner.transfer(instance) },
    };
    return null;
}

/// The transfer-receiving steps of an ImageBitmap's data holder in
/// `realm`. Takes `bitmap`, also on failure.
pub fn receiveImageBitmap(realm: runtime.Context, bitmap: *Bitmap) !*runtime.Instance {
    const owner = Installed.read().image_bitmap orelse {
        bitmap.destroy();
        return error.NotSupported;
    };
    return owner.receive(realm, bitmap);
}

/// The transfer-receiving steps of an OffscreenCanvas's data holder in
/// `realm`. Takes `holder`, also on failure.
pub fn receiveOffscreenCanvas(realm: runtime.Context, holder: *CanvasHolder) !*runtime.Instance {
    const owner = Installed.read().offscreen_canvas orelse {
        holder.destroy();
        return error.NotSupported;
    };
    return owner.receive(realm, holder);
}

// ---------------------------------------------------------------------------
// createImageBitmap's bitmap data (8.11.2)
// ---------------------------------------------------------------------------

/// createImageBitmap's `sx`, `sy`, `sw` and `sh`.
pub const Crop = struct { sx: i32, sy: i32, sw: i32, sh: i32 };

/// The ImageBitmapOptions the formatting steps read.
pub const Formatting = struct {
    flip_y: bool = false,
    premultiply_alpha: enum { default, premultiply, none } = .default,
    resize_width: ?u32 = null,
    resize_height: ?u32 = null,
    resize_quality: enum { pixelated, low, medium, high } = .low,
};

/// HTML 8.11.2 "crop bitmap data to the source rectangle with formatting"
/// for `input`, given `crop` (the sx, sy, sw, sh arguments, when given) and
/// `formatting`: a new bitmap. error.TooLarge for an output past
/// canvas_2d's pixel limit (the browsers reject such a bitmap: it cannot be
/// allocated). colorSpaceConversion has nothing to do here: every bitmap is
/// sRGB.
pub fn cropWithFormatting(allocator: Allocator, input: image_sources.ImageSource, crop: ?Crop, formatting: Formatting) error{ OutOfMemory, TooLarge }!*Bitmap {
    // 1-2. sourceRectangle: the crop's corners - a negative sw or sh puts
    //      the top-left corner left of or above (sx, sy) - or the whole
    //      input.
    const left: i64, const top: i64, const width: u64, const height: u64 = if (crop) |c| .{
        @as(i64, c.sx) + @min(c.sw, 0),
        @as(i64, c.sy) + @min(c.sh, 0),
        @abs(@as(i64, c.sw)),
        @abs(@as(i64, c.sh)),
    } else .{ 0, 0, input.width, input.height };
    // 3-4. outputWidth and outputHeight: the resize options, the other one
    //      in proportion (rounded up), or the source rectangle's.
    const output_width: u64 = if (formatting.resize_width) |w| w else if (formatting.resize_height) |h|
        divCeil(width * h, height)
    else
        width;
    const output_height: u64 = if (formatting.resize_height) |h| h else if (formatting.resize_width) |w|
        divCeil(height * w, width)
    else
        height;
    if (output_width == 0 or output_height == 0) return error.TooLarge;
    if (output_width > std.math.maxInt(u32) or output_height > std.math.maxInt(u32)) return error.TooLarge;
    if ((std.math.mul(u64, output_width, output_height) catch return error.TooLarge) > canvas_max_pixels) return error.TooLarge;
    // 10's choice for "default": premultiplied, what a 2D context draws.
    const premultiplied = formatting.premultiply_alpha != .none;
    const output = try Bitmap.create(allocator, @intCast(output_width), @intCast(output_height));
    errdefer output.destroy();
    output.alpha = if (premultiplied) .premultiplied else .straight;
    output.origin_clean = input.origin_clean;
    // 5-6. The input on an infinite transparent black plane; output is the
    //      plane's sourceRectangle.
    const region: Region = .{ .input = input, .left = left, .top = top, .width = width, .height = height };
    const out_w: usize = @intCast(output_width);
    const out_h: usize = @intCast(output_height);
    for (0..out_h) |row| {
        // 8. flipY: "output must be flipped vertically".
        const source_row = if (formatting.flip_y) out_h - 1 - row else row;
        for (0..out_w) |column| {
            const pixel: *[4]u8 = output.pixels[(row * out_w + column) * 4 ..][0..4];
            if (output_width == width and output_height == height) {
                // No scaling: the region's own pixel, in the alpha form
                // asked for (10: "untouched" when it already is).
                pixel.* = region.at(@intCast(column), @intCast(source_row), premultiplied);
                continue;
            }
            // 7. Scaled to outputWidth x outputHeight: "pixelated" - for
            //    each axis, nearest neighbour to the integer multiple of the
            //    natural size closest to the target, then bilinear the rest
            //    of the way; the other qualities bilinear. In premultiplied
            //    space, then (10) unpremultiplied for "none".
            var sample = switch (formatting.resize_quality) {
                .pixelated => region.pixelated(column, source_row, out_w, out_h),
                .low, .medium, .high => region.bilinear(@floatFromInt(width), @floatFromInt(height), column, source_row, out_w, out_h, 1, 1),
            };
            if (!premultiplied) sample = .{
                image_sources.unpremultiply(sample[0], sample[3]),
                image_sources.unpremultiply(sample[1], sample[3]),
                image_sources.unpremultiply(sample[2], sample[3]),
                sample[3],
            };
            pixel.* = sample;
        }
    }
    return output;
}

const canvas_max_pixels: u64 = 1 << 28;

fn divCeil(numerator: u64, denominator: u64) u64 {
    return (numerator + denominator - 1) / denominator;
}

/// The source rectangle of an input on the transparent black plane.
const Region = struct {
    input: image_sources.ImageSource,
    left: i64,
    top: i64,
    width: u64,
    height: u64,

    /// The region's pixel at (x, y), as premultiplied RGBA8 or straight.
    fn at(self: Region, x: i64, y: i64, premultiplied: bool) [4]u8 {
        const ix = self.left + x;
        const iy = self.top + y;
        if (self.input.pixels.len == 0) return .{ 0, 0, 0, 0 };
        if (ix < 0 or iy < 0 or ix >= self.input.width or iy >= self.input.height) return .{ 0, 0, 0, 0 };
        const index = (@as(usize, @intCast(iy)) * self.input.width + @as(usize, @intCast(ix))) * 4;
        const p = self.input.pixels[index..][0..4].*;
        return switch (self.input.alpha) {
            .premultiplied => if (premultiplied) p else .{
                image_sources.unpremultiply(p[0], p[3]),
                image_sources.unpremultiply(p[1], p[3]),
                image_sources.unpremultiply(p[2], p[3]),
                p[3],
            },
            .straight => if (!premultiplied) p else .{
                image_sources.premultiply(p[0], p[3]),
                image_sources.premultiply(p[1], p[3]),
                image_sources.premultiply(p[2], p[3]),
                p[3],
            },
        };
    }

    /// The region scaled by whole factors (`kx`, `ky`) - nearest neighbour -
    /// at (x, y), premultiplied.
    fn scaledAt(self: Region, x: i64, y: i64, kx: u64, ky: u64) [4]u8 {
        return self.at(@divFloor(x, @as(i64, @intCast(kx))), @divFloor(y, @as(i64, @intCast(ky))), true);
    }

    /// Bilinear sample, premultiplied, of the region scaled by whole factors
    /// (`kx`, `ky`: 1 for the region itself) - `virtual_width` x
    /// `virtual_height` - at the center of output pixel (column, row) of an
    /// `out_w` x `out_h` output; edges clamp.
    fn bilinear(self: Region, virtual_width: f64, virtual_height: f64, column: usize, row: usize, out_w: usize, out_h: usize, kx: u64, ky: u64) [4]u8 {
        const u = (@as(f64, @floatFromInt(column)) + 0.5) * virtual_width / @as(f64, @floatFromInt(out_w)) - 0.5;
        const v = (@as(f64, @floatFromInt(row)) + 0.5) * virtual_height / @as(f64, @floatFromInt(out_h)) - 0.5;
        const max_x: f64 = virtual_width - 1;
        const max_y: f64 = virtual_height - 1;
        const cu = std.math.clamp(u, 0, max_x);
        const cv = std.math.clamp(v, 0, max_y);
        const x0: i64 = @intFromFloat(@floor(cu));
        const y0: i64 = @intFromFloat(@floor(cv));
        const x1: i64 = @min(x0 + 1, @as(i64, @intFromFloat(max_x)));
        const y1: i64 = @min(y0 + 1, @as(i64, @intFromFloat(max_y)));
        const fx = cu - @as(f64, @floatFromInt(x0));
        const fy = cv - @as(f64, @floatFromInt(y0));
        const a = self.scaledAt(x0, y0, kx, ky);
        const b = self.scaledAt(x1, y0, kx, ky);
        const c = self.scaledAt(x0, y1, kx, ky);
        const d = self.scaledAt(x1, y1, kx, ky);
        var result: [4]u8 = undefined;
        for (&result, 0..) |*channel, i| {
            const top_mix = @as(f64, @floatFromInt(a[i])) * (1 - fx) + @as(f64, @floatFromInt(b[i])) * fx;
            const bottom_mix = @as(f64, @floatFromInt(c[i])) * (1 - fx) + @as(f64, @floatFromInt(d[i])) * fx;
            channel.* = @intFromFloat(std.math.clamp(@round(top_mix * (1 - fy) + bottom_mix * fy), 0, 255));
        }
        return result;
    }

    /// "pixelated": per axis, the integer multiple k > 0 of the natural size
    /// closest to the target, nearest neighbour to it, then bilinear to the
    /// target.
    fn pixelated(self: Region, column: usize, row: usize, out_w: usize, out_h: usize) [4]u8 {
        const kx = multiple(self.width, out_w);
        const ky = multiple(self.height, out_h);
        return self.bilinear(@floatFromInt(self.width * kx), @floatFromInt(self.height * ky), column, row, out_w, out_h, kx, ky);
    }

    fn multiple(natural: u64, target: usize) u64 {
        const ratio = @as(f64, @floatFromInt(target)) / @as(f64, @floatFromInt(natural));
        return @max(1, @as(u64, @intFromFloat(@round(ratio))));
    }
};

/// createImageBitmap's Blob arm, steps 2-3: apply the image sniffing rules
/// to `bytes` with `blob_type` as the official type, and decode the image
/// through the platform - its bitmap data, straight alpha, as an image
/// source OWNED by `allocator` (`pixels`); null when it is not in a
/// supported format or its dimensions cannot be obtained.
pub fn decodeBlob(allocator: Allocator, bytes: []const u8, blob_type: []const u8) ?DecodedBlob {
    if (comptime platform.capabilities.image_decoding == .unsupported) return null;
    var supplied = mimesniff.parseMimeType(allocator, blob_type) catch return null;
    defer if (supplied) |*mime| mime.deinit();
    // MIME Sniffing 5.2: at most the resource header (1445 bytes).
    const header = bytes[0..@min(bytes.len, 1445)];
    var computed = (mimesniff.sniffInImageContext(allocator, supplied, header) catch return null) orelse return null;
    defer computed.deinit();
    const mime = mimesniff.serializeMimeTypeToBytes(allocator, computed) catch return null;
    defer allocator.free(mime);
    const decoded = platform.decodeImage(allocator, platform.Str.from(mime), platform.Bytes.from(bytes), .{
        .max_dimension = std.math.maxInt(u16),
        .max_pixels = canvas_max_pixels,
    }) catch return null;
    return .{ .allocator = allocator, .width = decoded.width, .height = decoded.height, .pixels = @constCast(decoded.pixels.slice()) };
}

/// A Blob's decoded image (`decodeBlob`).
pub const DecodedBlob = struct {
    allocator: Allocator,
    width: u32,
    height: u32,
    /// Straight-alpha RGBA8, OWNED.
    pixels: []u8,

    pub fn source(self: *const DecodedBlob) image_sources.ImageSource {
        return .{ .width = self.width, .height = self.height, .pixels = self.pixels, .alpha = .straight, .origin_clean = true };
    }

    pub fn deinit(self: *DecodedBlob) void {
        self.allocator.free(self.pixels);
    }
};

test "crop with formatting: a crop past the input is transparent black outside it" {
    const allocator = std.testing.allocator;
    // A 2 x 1 input: opaque red, then half-transparent blue (premultiplied).
    const pixels = [_]u8{ 255, 0, 0, 255, 0, 0, 128, 128 };
    const input: image_sources.ImageSource = .{ .width = 2, .height = 1, .pixels = &pixels, .alpha = .premultiplied, .origin_clean = false };
    const whole = try cropWithFormatting(allocator, input, null, .{});
    defer whole.destroy();
    try std.testing.expectEqualSlices(u8, &pixels, whole.pixels);
    try std.testing.expect(!whole.origin_clean);
    // sx = 1, sw = -2: the rectangle from x = -1 to 1.
    const flipped_corner = try cropWithFormatting(allocator, input, .{ .sx = 1, .sy = 0, .sw = -2, .sh = 1 }, .{});
    defer flipped_corner.destroy();
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 255, 0, 0, 255 }, flipped_corner.pixels);
    // premultiplyAlpha "none": straight alpha out.
    const straight = try cropWithFormatting(allocator, input, .{ .sx = 1, .sy = 0, .sw = 1, .sh = 1 }, .{ .premultiply_alpha = .none });
    defer straight.destroy();
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 255, 128 }, straight.pixels);
}

test "crop with formatting: resize in proportion, flipY, and pixelated doubling" {
    const allocator = std.testing.allocator;
    // 1 x 2: red over green.
    const pixels = [_]u8{ 255, 0, 0, 255, 0, 255, 0, 255 };
    const input: image_sources.ImageSource = .{ .width = 1, .height = 2, .pixels = &pixels, .alpha = .premultiplied, .origin_clean = true };
    const flipped = try cropWithFormatting(allocator, input, null, .{ .flip_y = true });
    defer flipped.destroy();
    try std.testing.expectEqualSlices(u8, &.{ 0, 255, 0, 255, 255, 0, 0, 255 }, flipped.pixels);
    // resizeWidth 2 alone: the height follows, 2 * 2 / 1 = 4.
    const doubled = try cropWithFormatting(allocator, input, null, .{ .resize_width = 2, .resize_quality = .pixelated });
    defer doubled.destroy();
    try std.testing.expectEqual(@as(u32, 2), doubled.width);
    try std.testing.expectEqual(@as(u32, 4), doubled.height);
    // Pixelated by a whole factor is nearest neighbour: rows 0-1 red, 2-3 green.
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 0, 255 }, doubled.pixels[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 0, 255 }, doubled.pixels[8..12]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 255, 0, 255 }, doubled.pixels[16..20]);
    try std.testing.expectError(error.TooLarge, cropWithFormatting(allocator, input, null, .{ .resize_width = 1 << 20, .resize_height = 1 << 20 }));
}

test "a bitmap is created transparent black and cloned with its own pixels" {
    const allocator = std.testing.allocator;
    const bitmap = try Bitmap.create(allocator, 2, 1);
    defer bitmap.destroy();
    const zeros: [8]u8 = @splat(0);
    try std.testing.expectEqualSlices(u8, &zeros, bitmap.pixels);
    bitmap.pixels[0] = 7;
    bitmap.origin_clean = false;
    const copy = try bitmap.clone(allocator);
    defer copy.destroy();
    bitmap.pixels[0] = 9;
    try std.testing.expectEqual(@as(u8, 7), copy.pixels[0]);
    try std.testing.expect(!copy.origin_clean);
    try std.testing.expectEqual(@as(u32, 2), copy.source().width);
}
