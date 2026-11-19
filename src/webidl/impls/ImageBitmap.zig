//! Implementation for ImageBitmap interface
//!
//! HTML 8.11.2: an ImageBitmap is a bitmap image (`dom.image_bitmaps.Bitmap`:
//! pixels, dimensions, origin-clean) that a 2D context draws without undue
//! latency. createImageBitmap() makes one with its bitmap data
//! (`construction_args`: `bitmap`, taken); close() and the transfer steps
//! detach it ([[Detached]]) and unset its bitmap data.
//!
//! It is [Serializable] and [Transferable]: its serialization steps copy its
//! bitmap data into the record (an origin-tainted one is a DataCloneError);
//! its transfer steps hand the bitmap itself to the data holder
//! (dom.image_bitmaps, run by the one shared transfer step,
//! dom.transferables), which its transfer-receiving steps give to a new
//! ImageBitmap in the receiving realm.
//!
//! Spec: https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ImageBitmap = interfaces.ImageBitmap;
const Bitmap = dom.image_bitmaps.Bitmap;

pub const State = ImageBitmap.State;

pub const ImplError = error{
    NotImplemented,
};

/// createImageBitmap's bitmap data, given at construction.
pub const construction_args = .{"bitmap"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The bitmap data, OWNED; null once unset (closed or transferred) - or
    /// before a deserialized one's steps set it.
    bitmap: ?*Bitmap = null,
    /// [[Detached]]: set by close() and by the transfer steps.
    detached: bool = false,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// ImageBitmap's own construction steps. `args.bitmap`, when given, is the
/// new object's bitmap data: taken on success only - the caller frees it
/// when construction fails.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    if (comptime @hasField(@TypeOf(args), "bitmap")) internal.bitmap = args.bitmap;
    instance.getState(State).own._internal = internal;
}

/// ImageBitmap's own teardown: its bitmap data goes with it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    if (internal.bitmap) |bitmap| bitmap.destroy();
    internal.allocator.destroy(internal);
}

/// The steps with no IDL member: an ImageBitmap as an image source (HTML
/// 4.12.5.1.9) and its transfer and transfer-receiving steps.
pub fn installHooks() void {
    dom.image_sources.installImageBitmap(usability);
    dom.image_bitmaps.installImageBitmap(.{ .state = transferableState, .transfer = transferSteps, .receive = transferReceivingSteps });
}

/// HTML "check the usability of the image argument" for an ImageBitmap: a
/// detached one is an InvalidStateError; otherwise its bitmap data.
fn usability(instance: *runtime.Instance) dom.image_sources.Usability {
    const internal = getInternal(instance) orelse return .invalid_state;
    if (internal.detached) return .invalid_state;
    const bitmap = internal.bitmap orelse return .invalid_state;
    return .{ .good = bitmap.source() };
}

/// Getter for width: "If this's [[Detached]] internal slot's value is
/// true, then return 0. Return this's width, in CSS pixels."
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    if (internal.detached) return 0;
    return if (internal.bitmap) |bitmap| bitmap.width else 0;
}

/// Getter for height, as width.
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    if (internal.detached) return 0;
    return if (internal.bitmap) |bitmap| bitmap.height else 0;
}

/// Operation: close. 1. Set this's [[Detached]] internal slot value to
/// true. 2. Unset this's bitmap data.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return;
    internal.detached = true;
    if (internal.bitmap) |bitmap| bitmap.destroy();
    internal.bitmap = null;
}

// ============================================================================
// Serializable objects (HTML 2.7.1): ImageBitmap is [Serializable]
// ============================================================================

/// HTML 8.11.2, ImageBitmap's serialization steps, given `value` and
/// `serialized`:
///
/// 1. If value's origin-clean flag is not set, then throw a
///    "DataCloneError" DOMException.
/// 2. Set serialized.[[BitmapData]] to a copy of value's bitmap data.
///
/// StructuredSerializeInternal step 19.1 comes first: a detached one
/// ([[Detached]] true) is a DataCloneError too. [[BitmapData]] is written
/// as its width, height, alpha, then its pixels.
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    const internal = getInternal(value) orelse return error.DataCloneError;
    if (internal.detached) return error.DataCloneError;
    const bitmap = internal.bitmap orelse return error.DataCloneError;
    // Step 1.
    if (!bitmap.origin_clean) return error.DataCloneError;
    // Step 2.
    try serialized.writeUint32(bitmap.width);
    try serialized.writeUint32(bitmap.height);
    try serialized.writeBool(bitmap.alpha == .premultiplied);
    try serialized.writeBytes(bitmap.pixels);
}

/// HTML 8.11.2, ImageBitmap's deserialization steps, given `serialized`,
/// `value` and `targetRealm`:
///
/// 1. Set value's bitmap data to serialized.[[BitmapData]].
///
/// A record whose pixels are not width x height RGBA8 did not come from
/// the steps above: a DataCloneError.
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    _ = target_realm;
    const internal = getInternal(value) orelse return error.DataCloneError;
    const width = try serialized.readUint32();
    const height = try serialized.readUint32();
    const premultiplied = try serialized.readBool();
    const pixels = try serialized.readBytes();
    const expected = std.math.mul(u64, std.math.mul(u64, width, height) catch return error.DataCloneError, 4) catch return error.DataCloneError;
    if (pixels.len != expected) return error.DataCloneError;
    // Step 1: a bitmap of value's own, copied from the record (which only
    // lends its bytes).
    const bitmap = try Bitmap.create(internal.allocator, width, height);
    @memcpy(bitmap.pixels, pixels);
    bitmap.alpha = if (premultiplied) .premultiplied else .straight;
    if (internal.bitmap) |old| old.destroy();
    internal.bitmap = bitmap;
}

// ============================================================================
// Transferable objects (HTML 2.7.2): ImageBitmap is [Transferable]
// ============================================================================

/// Whether `instance` is an ImageBitmap, and its [[Detached]].
fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const internal = getInternal(instance) orelse return .not_transferable;
    return if (internal.detached) .detached else .transferable;
}

/// HTML 8.11.2, ImageBitmap's transfer steps, given `value` and
/// `dataHolder`:
///
/// 1. If value's origin-clean flag is not set, then throw a
///    "DataCloneError" DOMException.
/// 2. Set dataHolder.[[BitmapData]] to value's bitmap data.
/// 3. Unset value's bitmap data.
///
/// The bitmap data itself is the holder (the caller's now), and
/// StructuredSerializeWithTransfer step 5.6 sets [[Detached]].
fn transferSteps(instance: *runtime.Instance) anyerror!*Bitmap {
    const internal = getInternal(instance) orelse return error.DataCloneError;
    if (internal.detached) return error.DataCloneError;
    const bitmap = internal.bitmap orelse return error.DataCloneError;
    // Step 1.
    if (!bitmap.origin_clean) return error.DataCloneError;
    // Steps 2-3, then 5.6.
    internal.bitmap = null;
    internal.detached = true;
    return bitmap;
}

/// HTML 8.11.2, ImageBitmap's transfer-receiving steps, given `dataHolder`
/// and `value` - a new ImageBitmap of `realm`:
///
/// 1. Set value's bitmap data to dataHolder.[[BitmapData]].
///
/// The bitmap is taken, also on failure.
fn transferReceivingSteps(realm: runtime.Context, bitmap: *Bitmap) anyerror!*runtime.Instance {
    return ImageBitmap.initWith(realm.allocator, realm, .{ .bitmap = bitmap }) catch |err| {
        bitmap.destroy();
        return err;
    };
}
