//! Implementation for CanvasImageData interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const CanvasImageData = interfaces.CanvasImageData;
const dom = @import("dom");

pub const State = CanvasImageData.State;

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

/// Operation: getImageData. HTML 4.12.5.1.16's getImageData() method steps.
///
/// A negative sw or sh flips the rectangle's corner, as Blink, Gecko and
/// WebKit do (the spec's step 4 initializes the ImageData with sw and sh as
/// given). The bitmap is sRGB, so no colour space conversion is made; a
/// display-p3 ImageData gets the sRGB values (not modelled, stated).
pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) anyerror!*runtime.Instance {
    const bitmap = dom.image_sources.outputBitmap(instance) orelse return error.NotImplemented;
    // 1. If either sw or sh is zero, throw an "IndexSizeError" DOMException.
    if (sw == 0 or sh == 0) return error.IndexSizeError;
    // 2. If the origin-clean flag is false, throw a "SecurityError"
    //    DOMException.
    if (!bitmap.origin_clean) return error.SecurityError;
    var left: i64 = sx;
    var top: i64 = sy;
    if (sw < 0) left += sw;
    if (sh < 0) top += sh;
    const width: u32 = @abs(sw);
    const height: u32 = @abs(sh);
    // 3-4. A new ImageData, initialized given sw, sh, settings and this's
    //      color space.
    var given: dictionaries.ImageDataSettings = if (settings.wasPassed()) settings.getValue() else .{};
    if (given.colorSpace == null) given.colorSpace = contextColorSpace(instance);
    const image_data = try newImageData(instance, width, height, given);
    errdefer interfaces.ImageData.deinit(image_data);
    // 5-7. Its pixels: the bitmap's in the source rectangle, unpremultiplied,
    //      transparent black outside the bitmap.
    const pixels = try instance.ctx.allocator.alloc(u8, @as(usize, width) * height * 4);
    defer instance.ctx.allocator.free(pixels);
    @memset(pixels, 0);
    for (0..height) |row| {
        const y = top + @as(i64, @intCast(row));
        if (y < 0 or y >= bitmap.height) continue;
        for (0..width) |column| {
            const x = left + @as(i64, @intCast(column));
            if (x < 0 or x >= bitmap.width) continue;
            const from: usize = @intCast((y * bitmap.width + x) * 4);
            const p = bitmap.pixels[from..][0..4];
            const to = (row * width + column) * 4;
            pixels[to..][0..4].* = .{
                dom.image_sources.unpremultiply(p[0], p[3]),
                dom.image_sources.unpremultiply(p[1], p[3]),
                dom.image_sources.unpremultiply(p[2], p[3]),
                p[3],
            };
        }
    }
    const data = switch (try interfaces.ImageData.get_data(image_data)) {
        .uint8clamped_array => |array| array,
        // An rgba-float16 ImageData cannot be made yet (ImageData.zig).
        .float16array => return error.NotSupportedError,
    };
    const realm = engine.currentRealm() orelse instance.ctx;
    try engine.writeIntoArrayBufferView(realm, data, pixels, 0);
    // 8. Return imageData.
    return image_data;
}

/// Operation: createImageData(sw, sh, settings)
/// HTML: "1. If one or both of sw and sh are zero, then throw an
/// "IndexSizeError" DOMException. 2. Let newImageData be a new ImageData
/// object. 3. Initialize newImageData given the absolute magnitude of sw,
/// the absolute magnitude of sh, settings, and defaultColorSpace set to
/// this's color space. 4. Initialize the image data of newImageData to
/// transparent black. 5. Return newImageData."
///
/// A context's color space here is always "srgb" (its settings' colorSpace
/// is not modelled); settings["colorSpace"] set to it when absent is the
/// defaultColorSpace step. The ImageData is made in the current realm.
pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) anyerror!*runtime.Instance {
    // Step 1.
    if (sw == 0 or sh == 0) return error.IndexSizeError;
    // Steps 2-4.
    var given: dictionaries.ImageDataSettings = if (settings.wasPassed()) settings.getValue() else .{};
    if (given.colorSpace == null) given.colorSpace = contextColorSpace(instance);
    return newImageData(instance, @abs(sw), @abs(sh), given);
}

/// Operation: createImageData(imageData)
/// HTML: "1. Let newImageData be a new ImageData object. 2. Let settings be
/// the ImageDataSettings object «[ "colorSpace" → imageData's colorSpace,
/// "pixelFormat" → imageData's pixelFormat ]». 3. Initialize newImageData
/// given imageData's width, imageData's height, settings. 4. Initialize the
/// image data of newImageData to transparent black. 5. Return
/// newImageData."
pub fn call_createImageData__1(instance: *runtime.Instance, imageData: *runtime.Instance) anyerror!*runtime.Instance {
    const settings: dictionaries.ImageDataSettings = .{
        .colorSpace = try interfaces.ImageData.get_colorSpace(imageData),
        .pixelFormat = try interfaces.ImageData.get_pixelFormat(imageData),
    };
    const width = try interfaces.ImageData.get_width(imageData);
    const height = try interfaces.ImageData.get_height(imageData);
    return newImageData(instance, width, height, settings);
}

/// "this's color space": a context's is "srgb" unless its settings chose
/// another, which is not modelled.
fn contextColorSpace(instance: *runtime.Instance) enums.PredefinedColorSpace {
    _ = instance;
    return ._srgb_;
}

/// A new ImageData of `width` x `height` transparent black pixels, made in
/// the current realm through ImageData's constructor steps - which run
/// "initialize an ImageData object" and "initialize the image data" for it.
fn newImageData(instance: *runtime.Instance, width: u32, height: u32, settings: dictionaries.ImageDataSettings) !*runtime.Instance {
    const realm = engine.currentRealm() orelse instance.ctx;
    return interfaces.ImageData.call_constructor(realm, .{ .unsigned_long_unsigned_long_ImageDataSettings = .{
        .sw = width,
        .sh = height,
        .settings = webidl.Opt(dictionaries.ImageDataSettings).passed(settings),
    } });
}

/// Operation: putImageData(imageData, dx, dy): put pixels from an ImageData
/// onto a bitmap, given imageData, this's output bitmap, dx, dy, 0, 0, and
/// imageData's width and height.
pub fn call_putImageData(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32) anyerror!void {
    const width = try interfaces.ImageData.get_width(imageData);
    const height = try interfaces.ImageData.get_height(imageData);
    return putPixels(instance, imageData, dx, dy, 0, 0, @intCast(width), @intCast(height));
}

/// Operation: putImageData(imageData, dx, dy, dirtyX, dirtyY, dirtyWidth,
/// dirtyHeight).
pub fn call_putImageData__1(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32, dirtyX: i32, dirtyY: i32, dirtyWidth: i32, dirtyHeight: i32) anyerror!void {
    return putPixels(instance, imageData, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight);
}

/// HTML "put pixels from an ImageData onto a bitmap". The globalAlpha,
/// compositing and shadows do not apply: pixels are replaced wholesale,
/// premultiplied (4.12.5.7).
fn putPixels(instance: *runtime.Instance, image_data: *runtime.Instance, dx: i32, dy: i32, given_dirty_x: i32, given_dirty_y: i32, given_dirty_width: i32, given_dirty_height: i32) anyerror!void {
    const bitmap = dom.image_sources.outputBitmap(instance) orelse return error.NotImplemented;
    const realm = engine.currentRealm() orelse instance.ctx;
    const data = switch (try interfaces.ImageData.get_data(image_data)) {
        .uint8clamped_array => |array| array,
        .float16array => return error.NotSupportedError,
    };
    // 1-2. If imageData's data's [[ViewedArrayBuffer]] is detached, throw an
    //      "InvalidStateError" DOMException.
    const description = engine.describeArrayBufferView(realm, data) orelse return error.InvalidStateError;
    if (description.detached) return error.InvalidStateError;
    const buffer = try engine.getViewedArrayBuffer(realm, data);
    defer buffer.release();
    const bytes = engine.borrowArrayBufferBytes(realm, buffer.value) orelse return error.InvalidStateError;
    const source = bytes[description.byte_offset..][0..description.byte_length];
    const width: i64 = try interfaces.ImageData.get_width(image_data);
    const height: i64 = try interfaces.ImageData.get_height(image_data);
    var dirty_x: i64 = given_dirty_x;
    var dirty_y: i64 = given_dirty_y;
    var dirty_width: i64 = given_dirty_width;
    var dirty_height: i64 = given_dirty_height;
    // 3. A negative dirty size moves its corner.
    if (dirty_width < 0) {
        dirty_x += dirty_width;
        dirty_width = -dirty_width;
    }
    if (dirty_height < 0) {
        dirty_y += dirty_height;
        dirty_height = -dirty_height;
    }
    // 4. Clamp the dirty rectangle's origin at 0.
    if (dirty_x < 0) {
        dirty_width += dirty_x;
        dirty_x = 0;
    }
    if (dirty_y < 0) {
        dirty_height += dirty_y;
        dirty_y = 0;
    }
    // 5. ... and its far edges at the ImageData's.
    if (dirty_x + dirty_width > width) dirty_width = width - dirty_x;
    if (dirty_y + dirty_height > height) dirty_height = height - dirty_y;
    // 6. Nothing left: return.
    if (dirty_width <= 0 or dirty_height <= 0) return;
    // 7. Each pixel (x, y) of the dirty rectangle to (dx + x, dy + y).
    var y = dirty_y;
    while (y < dirty_y + dirty_height) : (y += 1) {
        const ty = dy + y;
        if (ty < 0 or ty >= bitmap.height) continue;
        var x = dirty_x;
        while (x < dirty_x + dirty_width) : (x += 1) {
            const tx = dx + x;
            if (tx < 0 or tx >= bitmap.width) continue;
            const from: usize = @intCast((y * width + x) * 4);
            if (from + 4 > source.len) continue;
            const p = source[from..][0..4];
            const to: usize = @intCast((ty * bitmap.width + tx) * 4);
            bitmap.pixels[to..][0..4].* = .{
                dom.image_sources.premultiply(p[0], p[3]),
                dom.image_sources.premultiply(p[1], p[3]),
                dom.image_sources.premultiply(p[2], p[3]),
                p[3],
            };
        }
    }
}
