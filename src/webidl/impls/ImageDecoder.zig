//! Implementation for ImageDecoder interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ImageDecoder = interfaces.ImageDecoder;

pub const State = ImageDecoder.State;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(instance: *runtime.Instance, init_data: dictionaries.ImageDecoderInit) !void {
    // The generated constructor made `instance` (WebIDL 3.7.1 step 1.8)
    // and frees it whole when a step fails (lane ctor1).
    const ctx = instance.ctx;
    // WebCodecs ImageDecoder constructor step 1: "If init is not valid
    // ImageDecoderInit, throw a TypeError." Firefox 160 throws it for a type
    // "invalid" (webidl/ecmascript-binding/allow-shared.https.html), as the
    // spec says; Chrome 157 does not.
    if (!isValidImageDecoderInit(ctx, &init_data)) return error.TypeError;

    // TODO: Implement the constructor's remaining steps (the decoder).
}

/// WebCodecs "valid ImageDecoderInit" steps 1, 4 and 5: a valid image MIME
/// type, and desiredWidth and desiredHeight both present or both absent.
/// Steps 2-3 (a disturbed or locked ReadableStream, a detached or empty
/// BufferSource) are not checked yet: they need the data's state, which the
/// stub constructor does not read (TODO with the decoder).
fn isValidImageDecoderInit(ctx: runtime.Context, init_data: *const dictionaries.ImageDecoderInit) bool {
    // 1. "If type is not a valid image MIME type, return false."
    if (!isValidImageMimeType(ctx.allocator, init_data.type.asSlice())) return false;
    // 4-5.
    if ((init_data.desiredWidth == null) != (init_data.desiredHeight == null)) return false;
    return true;
}

/// WebCodecs: "A string is a valid image MIME type if it is a valid MIME type
/// string and, when parsed, the MIME type's type is image."
fn isValidImageMimeType(allocator: std.mem.Allocator, text: []const u8) bool {
    var mime = (@import("mimesniff").mime_type.parseMimeType(allocator, text) catch return false) orelse return false;
    defer mime.deinit();
    const image = "image";
    if (mime.type.len != image.len) return false;
    for (mime.type, image) |unit, byte| if (unit != byte) return false;
    return true;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for complete
pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for completed
pub fn get_completed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for tracks
pub fn get_tracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: decode
pub fn call_decode(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ImageDecodeOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isTypeSupported
pub fn call_static_isTypeSupported(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}
