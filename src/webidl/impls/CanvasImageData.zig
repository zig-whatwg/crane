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

/// Operation: getImageData
pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = settings;
    return error.NotImplemented;
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

/// Operation: putImageData
pub fn call_putImageData(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32) anyerror!void {
    _ = instance;
    _ = imageData;
    _ = dx;
    _ = dy;
    return error.NotImplemented;
}
