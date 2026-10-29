//! HTML's image sources for 2D rendering contexts (4.12.5.1.9) and the 2D
//! context's output bitmap (4.12.5.1, 4.12.5.7): the pixels behind
//! drawImage, getImageData and putImageData, which have no IDL member.
//!
//! An img element's current image, a canvas element's bitmap and a context's
//! output bitmap each belong to their own type, and the CanvasDrawImage and
//! CanvasImageData mixins - implemented once, for every context that
//! includes them - read and write them through this module: each owner
//! installs its steps at process start, and the mixins never name an impl.
//!
//! It also carries an img's facts for the platform's layout STOPGAP
//! (decision 19b, platform.replacedElementBox): Element's clientWidth and
//! clientHeight ask it for any element, and only an img answers.
//!
//! lint-impls: hook for HTMLImageElement, HTMLCanvasElement, CanvasRenderingContext2D

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const process_start = @import("process_start.zig");

/// Pixels a context can draw: `width` x `height`, RGBA8, rows top down.
/// BORROWED for the call that asked: the source's owner keeps them.
pub const ImageSource = struct {
    width: u32,
    height: u32,
    pixels: []const u8,
    /// A decoded image is straight alpha; a canvas bitmap is premultiplied
    /// (4.12.5.7).
    alpha: enum { straight, premultiplied },
    /// 4.12.5.1.9 "an object image is not origin-clean if ...": false for an
    /// img whose image data is CORS-cross-origin, and for a canvas whose
    /// bitmap's origin-clean flag is false.
    origin_clean: bool,
};

/// HTML "check the usability of the image argument" (4.12.5.1.9), with the
/// image a good one draws.
pub const Usability = union(enum) {
    good: ImageSource,
    /// Nothing is drawn: an img that is not fully decodable or has a zero
    /// natural size.
    bad,
    /// An "InvalidStateError" DOMException: a broken img, a canvas with a
    /// zero dimension.
    invalid_state,
};

/// A 2D context's output bitmap: premultiplied RGBA8 (4.12.5.7), rows top
/// down, with its origin-clean flag (4.12.5.1.2). The context's: the canvas
/// element shares it (the 2D context creation algorithm, step 4).
pub const OutputBitmap = struct {
    allocator: std.mem.Allocator,
    width: u32 = 0,
    height: u32 = 0,
    /// `width * height * 4` bytes, OWNED by `allocator`.
    pixels: []u8 = &.{},
    /// Initially true; false once a source that is not origin-clean is drawn.
    /// Resizing does not reset it.
    origin_clean: bool = true,

    /// Resize to `width` x `height` of transparent black (the canvas's "set
    /// bitmap dimensions" step 2).
    pub fn resize(self: *OutputBitmap, width: u32, height: u32) error{OutOfMemory}!void {
        const len = std.math.mul(usize, std.math.mul(usize, width, height) catch return error.OutOfMemory, 4) catch return error.OutOfMemory;
        const pixels = try self.allocator.alloc(u8, len);
        @memset(pixels, 0);
        self.allocator.free(self.pixels);
        self.pixels = pixels;
        self.width = width;
        self.height = height;
    }

    pub fn deinit(self: *OutputBitmap) void {
        self.allocator.free(self.pixels);
        self.pixels = &.{};
        self.width = 0;
        self.height = 0;
    }
};

/// The steps each owner installs.
pub const Implementation = struct {
    /// HTMLImageElement: its usability as an image source.
    image_usability: ?*const fn (image: *runtime.Instance) Usability = null,
    /// HTMLImageElement: an element's replaced-element facts - null for an
    /// element that is no img. STOPGAP (decision 19b).
    replaced_facts: ?*const fn (element: *runtime.Instance) ?platform.ReplacedElementFacts = null,
    /// HTMLImageElement: run the image update for a relevant mutation.
    update_image_data: ?*const fn (image: *runtime.Instance) void = null,
    /// HTMLCanvasElement: its usability as an image source - its bitmap.
    canvas_usability: ?*const fn (canvas: *runtime.Instance) Usability = null,
    /// CanvasRenderingContext2D: its output bitmap; null for a context whose
    /// state is gone.
    output_bitmap: ?*const fn (context: *runtime.Instance) ?*OutputBitmap = null,
    /// CanvasRenderingContext2D: the 2D context creation algorithm's steps 3
    /// and 5 for a context just made for `canvas` - its canvas attribute,
    /// and its bitmap dimensions.
    attach_context: ?*const fn (context: *runtime.Instance, canvas: *runtime.Instance, width: u32, height: u32) anyerror!void = null,
    /// CanvasRenderingContext2D: "set bitmap dimensions" steps 1 and 2 -
    /// reset the context to its default state and resize its output bitmap.
    set_bitmap_dimensions: ?*const fn (context: *runtime.Instance, width: u32, height: u32) anyerror!void = null,
};

// process-wide: hook table written only by its owners at process start (B0); immutable while Browsers run, comptime in B9
var implementation: Implementation = .{};

pub fn installImageElement(
    usability: *const fn (*runtime.Instance) Usability,
    replaced_facts: *const fn (*runtime.Instance) ?platform.ReplacedElementFacts,
    update_image_data: *const fn (*runtime.Instance) void,
) void {
    process_start.assertInstalling();
    implementation.image_usability = usability;
    implementation.replaced_facts = replaced_facts;
    implementation.update_image_data = update_image_data;
}

/// HTML relevant mutations: the source element notifies following img
/// siblings through the image owner's installed step.
pub fn updateImageData(image: *runtime.Instance) void {
    const steps = implementation.update_image_data orelse return;
    steps(image);
}

/// `element`'s facts as a replaced element, when it is one (an img).
pub fn replacedFacts(element: *runtime.Instance) ?platform.ReplacedElementFacts {
    const steps = implementation.replaced_facts orelse return null;
    return steps(element);
}

/// The layout node id of `node` for the layout STOPGAP (decision 19b): its
/// address, opaque to the platform - an id for the queried element only,
/// with no table behind it. 0 is none.
pub fn layoutNode(node: ?*runtime.Instance) platform.LayoutNode {
    return .{ .id = if (node) |n| @intFromPtr(n) else 0 };
}

pub fn installCanvasElement(usability: *const fn (*runtime.Instance) Usability) void {
    process_start.assertInstalling();
    implementation.canvas_usability = usability;
}

pub fn installContext2D(
    output_bitmap: *const fn (*runtime.Instance) ?*OutputBitmap,
    attach_context: *const fn (*runtime.Instance, *runtime.Instance, u32, u32) anyerror!void,
    set_bitmap_dimensions: *const fn (*runtime.Instance, u32, u32) anyerror!void,
) void {
    process_start.assertInstalling();
    implementation.output_bitmap = output_bitmap;
    implementation.attach_context = attach_context;
    implementation.set_bitmap_dimensions = set_bitmap_dimensions;
}

/// An img element's usability; `bad` when no owner installed one.
pub fn imageUsability(image: *runtime.Instance) Usability {
    const steps = implementation.image_usability orelse return .bad;
    return steps(image);
}

/// A canvas element's usability; `bad` when no owner installed one.
pub fn canvasUsability(canvas: *runtime.Instance) Usability {
    const steps = implementation.canvas_usability orelse return .bad;
    return steps(canvas);
}

/// `context`'s output bitmap, if it has one.
pub fn outputBitmap(context: *runtime.Instance) ?*OutputBitmap {
    const steps = implementation.output_bitmap orelse return null;
    return steps(context);
}

pub fn attachContext(context: *runtime.Instance, canvas: *runtime.Instance, width: u32, height: u32) !void {
    const steps = implementation.attach_context orelse return error.NotSupported;
    return steps(context, canvas, width, height);
}

pub fn setBitmapDimensions(context: *runtime.Instance, width: u32, height: u32) !void {
    const steps = implementation.set_bitmap_dimensions orelse return error.NotSupported;
    return steps(context, width, height);
}

// ---------------------------------------------------------------------------
// Pixel arithmetic shared by the context's operations
// ---------------------------------------------------------------------------

/// `component` * `alpha` / 255, rounded: straight to premultiplied.
pub fn premultiply(component: u8, alpha: u8) u8 {
    const product = @as(u32, component) * alpha + 128;
    return @intCast((product + (product >> 8)) >> 8);
}

/// `component` * 255 / `alpha`, rounded and clamped: premultiplied to
/// straight. Alpha 0 is transparent black.
pub fn unpremultiply(component: u8, alpha: u8) u8 {
    if (alpha == 0) return 0;
    if (alpha == 255) return component;
    const value = (@as(u32, component) * 255 + alpha / 2) / alpha;
    return @intCast(@min(value, 255));
}

/// Source-over (Compositing 9.1.4 with the default operator) of one
/// premultiplied pixel onto another: co = cs + cb x (1 - as).
pub fn sourceOver(destination: *[4]u8, source: [4]u8) void {
    const inverse = 255 - source[3];
    for (destination, source) |*d, s| {
        d.* = @intCast(@min(@as(u32, s) + premultiply(d.*, inverse), 255));
    }
}

test "premultiply and unpremultiply round opaque and transparent pixels exactly" {
    for (0..256) |c| {
        try std.testing.expectEqual(@as(u8, @intCast(c)), premultiply(@intCast(c), 255));
        try std.testing.expectEqual(@as(u8, 0), premultiply(@intCast(c), 0));
        try std.testing.expectEqual(@as(u8, @intCast(c)), unpremultiply(@intCast(c), 255));
    }
    try std.testing.expectEqual(@as(u8, 0), unpremultiply(200, 0));
    // round(224 * 41 / 255) = 36; back: round(36 * 255 / 41) = 224.
    try std.testing.expectEqual(@as(u8, 36), premultiply(224, 41));
    try std.testing.expectEqual(@as(u8, 224), unpremultiply(36, 41));
}

test "source-over: an opaque source replaces, a transparent one leaves the destination" {
    var d: [4]u8 = .{ 10, 20, 30, 255 };
    sourceOver(&d, .{ 1, 2, 3, 255 });
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 255 }, &d);
    sourceOver(&d, .{ 0, 0, 0, 0 });
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 255 }, &d);
    // Half-transparent red over opaque blue: (128, 0, 0, 128) + blue x 127/255.
    var blue: [4]u8 = .{ 0, 0, 255, 255 };
    sourceOver(&blue, .{ 128, 0, 0, 128 });
    try std.testing.expectEqualSlices(u8, &.{ 128, 0, 127, 255 }, &blue);
}
