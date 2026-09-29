//! Implementation for ImageData interface
//!
//! HTML §4.12.5.1.16 - Pixel manipulation, the ImageData interface
//! Spec: https://html.spec.whatwg.org/multipage/canvas.html#imagedata
//!
//! A rectangular bitmap: `width` x `height` pixels whose colour components,
//! row by row from the top left, are `data` - a Uint8ClampedArray of four
//! bytes per pixel for "rgba-unorm8", a Float16Array of four halves for
//! "rgba-float16" - in the colour space `colorSpace`.
//!
//! Float16Array: V8 13.1 has it behind a flag that is still off (the
//! reflection lane's queue item 10), and the engine protocol has no view type
//! for it. Until it is on, an ImageData that would make one fails with a
//! NotSupportedError; one given a Float16Array cannot be reached, because the
//! binding cannot recognise one. Nothing is faked.
//!
//! Not modelled, stated: ImageData is [Serializable], and no platform object
//! is serializable yet - that is a protocol operation, queued by the
//! integrator.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const ImageData = interfaces.ImageData;

pub const State = ImageData.State;

pub const ImplError = error{
    NotImplemented,
    IndexSizeError,
    InvalidStateError,
    NotSupportedError,
    RangeError,
};

/// Which ImageDataArray an ImageData's `data` is.
const ArrayKind = enum { uint8_clamped, float16 };

/// An ImageData's width, height, pixel format, colour space and data.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    width: u32 = 0,
    height: u32 = 0,
    pixel_format: enums.ImageDataPixelFormat = ._rgba_unorm8_,
    color_space: enums.PredefinedColorSpace = ._srgb_,
    /// The ImageDataArray, held for as long as this ImageData lives: `data`
    /// returns this same object every time.
    data: ?engine.Owned = null,
    data_kind: ArrayKind = .uint8_clamped,

    fn deinit(self: *InternalState) void {
        if (self.data) |owned| owned.release();
        self.data = null;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// The two constructors.
pub fn call_constructor(ctx: runtime.Context, args: interfaces.ImageData.ConstructorArgs) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &ImageData.vtable, ctx);
    errdefer deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    switch (args) {
        // "new ImageData(sw, sh, settings)": "1. If one or both of sw and sh
        // are zero, then throw an "IndexSizeError" DOMException. 2.
        // Initialize this given sw, sh, and settings. 3. Initialize the image
        // data of this to transparent black."
        .unsigned_long_unsigned_long_ImageDataSettings => |a| {
            if (a.sw == 0 or a.sh == 0) return error.IndexSizeError;
            const settings: dictionaries.ImageDataSettings = if (a.settings.wasPassed()) a.settings.getValue() else .{};
            try initialize(ctx, internal, a.sw, a.sh, settings, null, null);
        },
        // "new ImageData(data, sw, sh, settings)".
        .ImageDataArray_unsigned_long_unsigned_long_ImageDataSettings => |a| {
            const settings: dictionaries.ImageDataSettings = if (a.settings.wasPassed()) a.settings.getValue() else .{};
            // "1. Let bytesPerPixel be 4 if settings["pixelFormat"] is
            // "rgba-unorm8"; otherwise 8."
            const bytes_per_pixel: usize = if (pixelFormatOf(settings) == ._rgba_unorm8_) 4 else 8;
            // "2. Let length be the buffer source byte length of data."
            const array = arrayValue(a.data);
            const description = engine.describeArrayBufferView(ctx, array) orelse return error.TypeError;
            var length: usize = description.byte_length;
            // "3. If length is not a nonzero integral multiple of
            // bytesPerPixel, then throw an "InvalidStateError" DOMException."
            if (length == 0 or length % bytes_per_pixel != 0) return error.InvalidStateError;
            // "4. Let length be length divided by bytesPerPixel."
            length /= bytes_per_pixel;
            // "5. If length is not an integral multiple of sw, then throw an
            // "IndexSizeError" DOMException." (length is nonzero, so a zero sw
            // throws here.)
            if (a.sw == 0 or length % a.sw != 0) return error.IndexSizeError;
            // "6. Let height be length divided by sw."
            const height = length / a.sw;
            // "7. If sh was given and its value is not equal to height, then
            // throw an "IndexSizeError" DOMException."
            if (a.sh.wasPassed() and a.sh.getValue() != height) return error.IndexSizeError;
            // "8. Initialize this given sw, sh, settings, and source set to
            // data." With sh absent, the rows are height.
            const rows = std.math.cast(u32, height) orelse return error.IndexSizeError;
            try initialize(ctx, internal, a.sw, rows, settings, a.data, null);
        },
    }
    return instance;
}

/// settings["pixelFormat"], whose default is "rgba-unorm8".
fn pixelFormatOf(settings: dictionaries.ImageDataSettings) enums.ImageDataPixelFormat {
    return settings.pixelFormat orelse ._rgba_unorm8_;
}

fn arrayValue(array: typedefs.ImageDataArray) runtime.JSValue {
    return switch (array) {
        .uint8clamped_array => |v| v,
        .float16array => |v| v,
    };
}

/// HTML "initialize an ImageData object" `internal`, given `pixels_per_row`,
/// `rows`, `settings`, an optional `source` and an optional
/// `default_color_space`.
fn initialize(
    realm: runtime.Context,
    internal: *InternalState,
    pixels_per_row: u32,
    rows: u32,
    settings: dictionaries.ImageDataSettings,
    source: ?typedefs.ImageDataArray,
    default_color_space: ?enums.PredefinedColorSpace,
) !void {
    const pixel_format = pixelFormatOf(settings);
    if (source) |array| {
        // Step 1.1: "If settings["pixelFormat"] equals "rgba-unorm8" and
        // source is not a Uint8ClampedArray, then throw an
        // "InvalidStateError" DOMException."
        // Step 1.2: the same for "rgba-float16" and a Float16Array.
        const kind: ArrayKind = switch (array) {
            .uint8clamped_array => .uint8_clamped,
            .float16array => .float16,
        };
        switch (pixel_format) {
            ._rgba_unorm8_ => if (kind != .uint8_clamped) return error.InvalidStateError,
            ._rgba_float16_ => if (kind != .float16) return error.InvalidStateError,
        }
        // Step 1.3: "Initialize the data attribute of imageData to source" -
        // the object given, not a copy.
        internal.data = try engine.retainValue(realm, arrayValue(array));
        internal.data_kind = kind;
    } else switch (pixel_format) {
        // Step 2.1: "a new Uint8ClampedArray object" over "a new ArrayBuffer"
        // of "4 × rows × pixelsPerRow bytes", zero offset, its whole length.
        // AllocateArrayBuffer zeroes it: transparent black.
        ._rgba_unorm8_ => {
            const length = std.math.mul(usize, @as(usize, rows) * 4, pixels_per_row) catch return error.RangeError;
            // Step 2.3: "If the storage ArrayBuffer could not be allocated,
            // then rethrow the RangeError thrown by JavaScript."
            const buffer = engine.allocateArrayBuffer(realm, length) catch return error.RangeError;
            defer buffer.release();
            internal.data = engine.createArrayBufferView(realm, .uint8_clamped_array, buffer.borrow(), 0, length) catch return error.RangeError;
            internal.data_kind = .uint8_clamped;
        },
        // Step 2.2: a new Float16Array - which this engine cannot make yet
        // (see the file comment).
        ._rgba_float16_ => return error.NotSupportedError,
    }
    // Steps 3-5: width, height, pixel format.
    internal.width = pixels_per_row;
    internal.height = rows;
    internal.pixel_format = pixel_format;
    // Steps 6-8: settings["colorSpace"], else defaultColorSpace, else "srgb".
    internal.color_space = settings.colorSpace orelse default_color_space orelse ._srgb_;
}

/// Getter for width: "the width attribute ... initialized" by "initialize an
/// ImageData object".
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.width;
}

/// Getter for height.
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.height;
}

/// Getter for data: the same ImageDataArray every time. BORROWED - this
/// ImageData keeps it.
pub fn get_data(instance: *runtime.Instance) anyerror!typedefs.ImageDataArray {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const data = internal.data orelse return error.InvalidStateError;
    return switch (internal.data_kind) {
        .uint8_clamped => .{ .uint8clamped_array = data.borrow() },
        .float16 => .{ .float16array = data.borrow() },
    };
}

/// Getter for pixelFormat.
pub fn get_pixelFormat(instance: *runtime.Instance) anyerror!enums.ImageDataPixelFormat {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.pixel_format;
}

/// Getter for colorSpace.
pub fn get_colorSpace(instance: *runtime.Instance) anyerror!enums.PredefinedColorSpace {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.color_space;
}
