//! Vendored JPEG/SVG decoders for the testing platform. The returned pixels
//! use the caller's allocator; native codec contexts are scoped to one call.
const std = @import("std");
const platform = @import("platform");
// image_codecs.h, translated by build.zig (addCImport).
const c = @import("image_codecs_c");

fn pixels(allocator: std.mem.Allocator, width: u32, height: u32, limits: platform.ImageLimits) platform.ImageError![]u8 {
    const count = @as(u64, width) * height;
    if (width > limits.max_dimension or height > limits.max_dimension or count > limits.max_pixels or count > std.math.maxInt(usize) / 4)
        return error.TooLarge;
    const output = try allocator.alloc(u8, @as(usize, @intCast(count)) * 4);
    @memset(output, 0);
    return output;
}

pub fn jpeg(allocator: std.mem.Allocator, bytes: []const u8, limits: platform.ImageLimits) platform.ImageError!platform.DecodedImage {
    var width: u32 = 0;
    var height: u32 = 0;
    var result: c_int = 0;
    const codec = c.crane_jpeg_open(bytes.ptr, bytes.len, &width, &height, &result) orelse
        return if (result == c.CRANE_OOM) error.OutOfMemory else error.Corrupt;
    defer c.crane_jpeg_close(codec);
    var output = try pixels(allocator, width, height, limits);
    errdefer allocator.free(output);
    // jpeg_finish_decompress releases saved APP markers: read metadata first.
    const orientation = c.crane_jpeg_orientation(codec);
    var empty: c_int = 0;
    result = c.crane_jpeg_decode(codec, output.ptr, &empty);
    if (result == c.CRANE_OOM) return error.OutOfMemory;
    if (orientation != 1) {
        // EXIF/TIFF orientation, CSS Images 3 5.1's from-image default.
        const oriented = try allocator.alloc(u8, output.len);
        const target_width = if (orientation >= 5) height else width;
        for (0..height) |y| for (0..width) |x| {
            const target_x = switch (orientation) {
                2, 3 => width - 1 - x,
                5, 8 => y,
                6, 7 => height - 1 - y,
                else => x,
            };
            const target_y = switch (orientation) {
                3, 4 => height - 1 - y,
                5, 6 => x,
                7, 8 => width - 1 - x,
                else => y,
            };
            @memcpy(oriented[(target_y * target_width + target_x) * 4 ..][0..4], output[(y * width + x) * 4 ..][0..4]);
        };
        allocator.free(output);
        output = oriented;
        if (orientation >= 5) std.mem.swap(u32, &width, &height);
    }
    return .{
        .width = width,
        .height = height,
        .pixels = .from(output),
        .status = switch (result) {
            c.CRANE_COMPLETE => .complete,
            c.CRANE_TRUNCATED => .truncated,
            else => .corrupt,
        },
        .empty = empty != 0,
    };
}

pub fn svg(allocator: std.mem.Allocator, bytes: []const u8, limits: platform.ImageLimits) platform.ImageError!platform.DecodedImage {
    var width_f: f64 = 0;
    var height_f: f64 = 0;
    var result: c_int = 0;
    const codec = c.crane_svg_open(bytes.ptr, bytes.len, &width_f, &height_f, &result) orelse
        return if (result == c.CRANE_OOM) error.OutOfMemory else error.Corrupt;
    defer c.crane_svg_close(codec);
    if (!std.math.isFinite(width_f) or !std.math.isFinite(height_f) or width_f < 0 or height_f < 0) return error.Corrupt;
    if (width_f > @as(f64, @floatFromInt(@min(limits.max_dimension, std.math.maxInt(c_int) / 4))) or
        height_f > @as(f64, @floatFromInt(@min(limits.max_dimension, std.math.maxInt(c_int))))) return error.TooLarge;
    const width: u32 = @intFromFloat(@ceil(width_f));
    const height: u32 = @intFromFloat(@ceil(height_f));
    // NanoSVG indexes rows with signed int arithmetic.
    if (@as(u64, width) * height > std.math.maxInt(c_int) / 4) return error.TooLarge;
    const output = try pixels(allocator, width, height, limits);
    errdefer allocator.free(output);
    result = c.crane_svg_render(codec, output.ptr, @intCast(width), @intCast(height));
    if (result == c.CRANE_OOM) return error.OutOfMemory;
    return .{ .width = width, .height = height, .pixels = .from(output), .status = if (result == c.CRANE_COMPLETE) .complete else .corrupt, .empty = result != c.CRANE_COMPLETE };
}
