//! Implementation for Blob interface
//!
//! W3C File API: https://www.w3.org/TR/FileAPI/#blob-section
//!
//! A Blob represents immutable raw binary data. This implementation
//! wires the WebIDL interface to the internal BlobData storage and
//! the W3C File API algorithms.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const file = @import("file");
const Blob = interfaces.Blob;

const engine = @import("engine");
const encoding = @import("encoding");
const webidl = @import("webidl");

// The byte stream "get stream" returns.
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const same_object = @import("same_object.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = Blob.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for Blob implementation
///
/// Holds the BlobData pointer which stores the actual bytes and MIME type.
/// This follows the InternalState pattern used by ReadableStream and other impls.
pub const InternalState = struct {
    /// The internal blob data (bytes + type)
    blob_data: *file.BlobData,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.blob_data.deinit();
        // Don't destroy self here - let the caller handle it
    }
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Fetch, FormData's encoding and fetch()'s upload read a Blob's bytes
    // through this hook.
    @import("dom").blob_bytes.install(.{ .bytes_of = &bytesOf, .set_bytes = &setBytes });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// dom.blob_bytes: this Blob's bytes, borrowed - a Blob's data never changes.
fn bytesOf(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.blob_data.bytes;
}

/// dom.blob_bytes: give a new Blob a copy of `bytes`, and `mime_type` as its
/// type (BlobData lowercases it, or drops one with a character outside
/// U+0020-U+007E).
fn setBytes(instance: *runtime.Instance, bytes: []const u8, mime_type: []const u8) anyerror!void {
    const allocator = instance.ctx.allocator;
    const blob_data = try file.BlobData.init(allocator, bytes, mime_type);
    errdefer blob_data.deinit();
    try setBlobData(instance, allocator, blob_data);
}

/// Deinitialize instance - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here!
/// The GC integration layer (gc_integration.onObjectFreed) handles:
/// 1. Calling this deinit function (via vtable.deinit)
/// 2. Freeing the Instance handle back to the SlabAllocator
/// Calling Instance.deinit from here would cause infinite recursion.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Constructor implementation
///
/// Spec: https://www.w3.org/TR/FileAPI/#constructorBlob
///
/// Steps:
/// 1. If blobParts is empty or missing, create empty Blob
/// 2. Process blobParts using "process blob parts" algorithm
/// 3. Normalize type from options
/// 4. Return new Blob
pub fn call_constructor(ctx: runtime.Context, blobParts: webidl.Opt(runtime.JSValue), options: webidl.Opt(dictionaries.BlobPropertyBag)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    // Determine if we have blob parts and what endings mode to use
    const endings_mode: file.algorithms.Endings = blk: {
        if (options.wasPassed()) {
            if (options.value.endings) |endings| {
                // endings is now an enum, check if it's "native"
                if (endings == ._native_) {
                    break :blk .native;
                }
            }
        }
        break :blk .transparent;
    };

    // Get MIME type from options
    const mime_type: []const u8 = if (options.wasPassed() and options.value.type != null) options.value.type.?.asSlice() else "";

    // Process blob parts if provided. An optional argument that is
    // undefined is missing (WebIDL 3.7.x "overload resolution", step 12.1).
    const parts: ?runtime.JSValue = if (blobParts.wasPassed() and engine.typeOf(ctx, blobParts.value) != .undefined) blobParts.value else null;
    const bytes = try processBlobParts(ctx, parts, endings_mode);
    defer if (bytes.len > 0) ctx.allocator.free(bytes);

    // Create the internal BlobData
    const blob_data = try file.BlobData.init(ctx.allocator, bytes, mime_type);
    errdefer blob_data.deinit();
    try setBlobData(instance, ctx.allocator, blob_data);

    return instance;
}

/// The `endings` member of BlobPropertyBag, as "process blob parts" takes it.
pub const Endings = file.algorithms.Endings;

/// FileAPI "process blob parts" for a JS `sequence<BlobPart>`: `parts`
/// converted to the IDL sequence (WebIDL 3.2.21), each item to the union
/// (Blob or BufferSource or USVString) (3.2.24), then their bytes in order,
/// a string's line endings converted when `endings` is native
/// (file.algorithms.processBlobParts). Shared with File, whose constructor's
/// first step is the same algorithm. Missing parts are no bytes.
///
/// OWNED by `realm.allocator` when non-empty; an empty result allocates
/// nothing.
pub fn processBlobParts(realm: runtime.Context, parts: ?runtime.JSValue, endings: Endings) ![]const u8 {
    const value = parts orelse return "";
    var converted: BlobPartSequence = .{ .realm = realm, .allocator = realm.allocator };
    defer converted.deinit();
    // 3.2.21: not an Object (step 1), or one with no @@iterator (step 3),
    // is a TypeError.
    if (!try engine.iterate(realm, value, BlobPartSequence.each, &converted)) return error.TypeError;
    const bytes = try file.algorithms.processBlobParts(realm.allocator, converted.parts.items, .{ .endings = endings });
    if (bytes.len == 0) {
        realm.allocator.free(bytes);
        return "";
    }
    return bytes;
}

/// A `sequence<BlobPart>` as it is converted, item by item: every part's
/// bytes are copied, as a later item's conversion runs script that can drop
/// the last reference to an earlier Blob or detach an earlier buffer.
const BlobPartSequence = struct {
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    parts: std.ArrayListUnmanaged(file.algorithms.BlobPart) = .empty,

    fn deinit(self: *BlobPartSequence) void {
        for (self.parts.items) |part| switch (part) {
            .blob => {},
            .buffer => |bytes| self.allocator.free(bytes),
            .string => |text| self.allocator.free(text),
        };
        self.parts.deinit(self.allocator);
    }

    fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
        const self: *BlobPartSequence = @ptrCast(@alignCast(data.?));
        try self.parts.ensureUnusedCapacity(self.allocator, 1);
        self.parts.appendAssumeCapacity(try convertBlobPart(self.realm, item, self.allocator));
    }
};

/// WebIDL 3.2.24, converting `item` to (Blob or BufferSource or USVString).
/// OWNED by `allocator`.
fn convertBlobPart(realm: runtime.Context, item: runtime.JSValue, allocator: std.mem.Allocator) engine.Error!file.algorithms.BlobPart {
    // 4. A platform object that implements Blob is the Blob: its bytes. Any
    //    other platform object is no member here but the string (12).
    if (engine.convertToPlatformObject(realm, item)) |object| {
        if (object.stateAs(State)) |state| {
            const bytes: []const u8 = if (state.own._internal) |internal| internal.blob_data.bytes else "";
            return .{ .buffer = try allocator.dupe(u8, bytes) };
        }
    }
    // 5-9. An ArrayBuffer or ArrayBufferView: a copy of the bytes it holds
    //      (a view on a shared buffer is a TypeError - BufferSource is not
    //      [AllowShared]).
    if (try engine.getCopyOfBufferSourceBytes(realm, item, allocator)) |bytes| return .{ .buffer = bytes };
    // 12. Anything else is the USVString it converts to, as UTF-8.
    return .{ .string = try engine.convertToUSVString(realm, item, allocator) };
}

/// Give `instance`'s Blob part its byte sequence, taking `blob_data` on
/// success. For a File that is the File's own Blob state: Instance.getState
/// finds an ancestor's state at its real offset.
pub fn setBlobData(instance: *runtime.Instance, allocator: std.mem.Allocator, blob_data: *file.BlobData) !void {
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .blob_data = blob_data,
        .allocator = allocator,
    };
    instance.getState(State).own._internal = internal;
}

/// Create a Blob from raw bytes (internal helper)
///
/// This is used by other APIs (File, slice) that need to create Blobs
/// directly from bytes without going through the WebIDL constructor.
pub fn createFromBytes(allocator: std.mem.Allocator, ctx: runtime.Context, bytes: []const u8, mime_type: []const u8) !*runtime.Instance {
    const instance = try init(allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    const blob_data = try file.BlobData.init(allocator, bytes, mime_type);
    errdefer blob_data.deinit();
    try setBlobData(instance, allocator, blob_data);

    return instance;
}

/// Create a Blob from existing BlobData (internal helper)
///
/// Takes ownership of the BlobData - caller should NOT deinit it.
pub fn createFromBlobData(allocator: std.mem.Allocator, ctx: runtime.Context, blob_data: *file.BlobData) !*runtime.Instance {
    const instance = try init(allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    try setBlobData(instance, allocator, blob_data);

    return instance;
}

/// Get internal state from instance
/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Getter for size
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-size
/// Returns the size of the byte sequence in number of bytes.
pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.blob_data.size();
}

/// Getter for type
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-type
/// Returns ASCII-encoded string in lower case representing the media type.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const type_str = internal.blob_data.getType();
    if (type_str.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initInterned(type_str);
}

/// Operation: slice
///
/// Spec: https://www.w3.org/TR/FileAPI/#slice-method-algo
/// Returns a new Blob object with bytes from start to end and optional contentType.
pub fn call_slice(instance: *runtime.Instance, start: webidl.Opt(i64), end: webidl.Opt(i64), contentType: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Get contentType as optional slice (unwrap Opt)
    const ct: ?[]const u8 = blk: {
        if (contentType.wasPassed()) {
            const slice = contentType.value.asSlice();
            if (slice.len > 0) {
                break :blk slice;
            }
        }
        break :blk null;
    };

    // Run slice blob algorithm - unwrap Opt for start/end
    const start_val: ?i64 = if (start.wasPassed()) start.value else null;
    const end_val: ?i64 = if (end.wasPassed()) end.value else null;
    const sliced_data = file.algorithms.sliceBlob(
        allocator,
        internal.blob_data,
        start_val,
        end_val,
        ct,
    ) catch {
        return error.OutOfMemory;
    };
    errdefer sliced_data.deinit();

    // Create new Blob instance with the sliced data
    return createFromBlobData(allocator, ctx, sliced_data) catch {
        return error.OutOfMemory;
    };
}

/// Operation: text
///
/// Spec: https://www.w3.org/TR/FileAPI/#dom-blob-text
/// Returns a Promise that resolves with the blob contents as a UTF-8 string.
///
/// Algorithm:
/// 1. Let stream be the result of calling get stream on this.
/// 2. Let reader be the result of getting a reader from stream.
/// 3. Let promise be the result of reading all bytes from stream with reader.
/// 4. Return the result of transforming promise with UTF-8 decode.
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // The blob's bytes are in memory and never change, so reading all of
    // them through a stream (steps 1-3) is those bytes, and the promise is
    // fulfilled with them already. A new promise, and the values it is
    // fulfilled with, are the current realm's (the transform's handler).
    const realm = engine.currentRealm() orelse instance.ctx;
    // 4. ... UTF-8 decode on its first argument.
    const text = try utf8Decode(realm.allocator, internal.blob_data.bytes);
    defer realm.allocator.free(text);
    const promise = try engine.createResolvedPromise(realm, runtime.JSValue.fromStringRef(text));
    return promise.take();
}

/// Encoding "UTF-8 decode" of `bytes` - a leading BOM stripped, each invalid
/// sequence U+FFFD - held as UTF-8, as the engine takes a string. OWNED.
fn utf8Decode(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const code_units = try encoding.utf8Decode(allocator, bytes);
    defer allocator.free(code_units);
    // A decoder's output is scalar values: no surrogate is unpaired.
    return std.unicode.utf16LeToUtf8Alloc(allocator, code_units) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => unreachable,
    };
}

/// Operation: stream
///
/// Spec: https://w3c.github.io/FileAPI/#stream-method-algo - "get stream":
/// a new ReadableStream set up with byte reading support, into which the
/// blob's bytes are enqueued as Uint8Arrays, and which is closed once all
/// of them have been.
///
/// The bytes are enqueued as the stream pulls, a chunk at a time, rather
/// than all at once in parallel: a Blob's data is in memory and never
/// changes, so reading it when asked is the same bytes in the same order,
/// and a stream nobody reads holds none of them.
pub fn call_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidState;
    const realm = try js.Realm.of(instance);
    return BlobStream.create(realm, instance);
}

/// The most "get stream" enqueues per pull.
const chunk_size: usize = 64 * 1024;

/// The underlying source of a Blob's stream. It reads the Blob's own bytes,
/// so it keeps the Blob alive (`keep`) until the stream is done with it.
const BlobStream = struct {
    allocator: std.mem.Allocator,
    blob: *runtime.Instance,
    keep: same_object.Pin = .{},
    /// Bytes of the blob already enqueued.
    position: usize = 0,
    /// Every byte is enqueued, or the stream was cancelled: the blob is let
    /// go, and must not be read again.
    done: bool = false,
    /// The stream is done with this source (its algorithms were cleared).
    detached: bool = false,
    /// Calls into the stream under way from here: freeing waits for them.
    busy: u32 = 0,

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancel, .deinit = deinitSource };

    fn create(realm: js.Realm, blob: *runtime.Instance) !*runtime.Instance {
        const allocator = blob.ctx.allocator;
        const self = try allocator.create(BlobStream);
        self.* = .{ .allocator = allocator, .blob = blob };
        self.keep.hold(blob);
        // A failed setup clears the source's algorithms, which must not free
        // it under this call.
        self.busy += 1;
        const stream = srd.createReadableByteStream(realm, blob.ctx, .{ .ctx = self, .vtable = &vtable });
        self.busy -= 1;
        if (stream) |st| return st else |err| {
            self.detached = true;
            self.freeIfDone();
            return err;
        }
    }

    fn start(_: ?*anyopaque, realm: js.Realm, _: *runtime.Instance) js.Error!js.Completion {
        return .{ .normal = try realm.undefinedValue() };
    }

    /// Enqueue the next chunk, and close the stream after the last.
    fn pull(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
        const self: *BlobStream = @ptrCast(@alignCast(ctx.?));
        self.busy += 1;
        defer {
            self.busy -= 1;
            self.freeIfDone();
        }
        if (self.done) return realm.promiseResolvedWithUndefined();
        const bytes = if (getInternal(self.blob)) |internal| internal.blob_data.bytes else &[_]u8{};
        if (self.position < bytes.len) {
            const chunk = bytes[self.position..][0..@min(chunk_size, bytes.len - self.position)];
            self.position += chunk.len;
            const buffer = js.allocateBufferIn(realm, chunk.len) orelse return error.V8Failure;
            defer js.dispose(buffer);
            if (js.bufferBytes(buffer)) |dest| @memcpy(dest[0..chunk.len], chunk);
            const view = try js.newView(.uint8, buffer, 0, chunk.len);
            defer js.dispose(view);
            try srd.byteControllerEnqueue(realm, controller, view);
        }
        if (!self.detached and self.position >= bytes.len) {
            // All of it is enqueued: nothing more to read, so let the blob go.
            self.done = true;
            self.keep.release();
            try srd.byteControllerClose(realm, controller);
        }
        return realm.promiseResolvedWithUndefined();
    }

    fn cancel(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, _: js.Value) js.Error!js.Value {
        const self: *BlobStream = @ptrCast(@alignCast(ctx.?));
        self.done = true;
        self.keep.release();
        return realm.promiseResolvedWithUndefined();
    }

    fn deinitSource(ctx: ?*anyopaque, _: std.mem.Allocator) void {
        const self: *BlobStream = @ptrCast(@alignCast(ctx.?));
        self.detached = true;
        self.freeIfDone();
    }

    fn freeIfDone(self: *BlobStream) void {
        if (!self.detached or self.busy > 0) return;
        self.keep.release();
        self.allocator.destroy(self);
    }
};

/// Operation: bytes
///
/// Spec: https://www.w3.org/TR/FileAPI/#dom-blob-bytes
/// Returns a Promise that resolves with a Uint8Array of the blob contents.
///
/// Algorithm:
/// 1. Let stream be the result of calling get stream on this.
/// 2. Let reader be the result of getting a reader from stream.
/// 3. Let promise be the result of reading all bytes from stream with reader.
/// 4. Return the result of transforming promise to create Uint8Array from bytes.
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // Steps 1-3 as in text(): the bytes are the blob's own.
    const realm = engine.currentRealm() orelse instance.ctx;
    // 4. ... a new Uint8Array wrapping an ArrayBuffer containing its first
    //    argument.
    const bytes = internal.blob_data.bytes;
    const buffer = try engine.createArrayBuffer(realm, bytes);
    defer buffer.release();
    const view = try engine.createArrayBufferView(realm, .uint8_array, buffer.value, 0, bytes.len);
    defer view.release();
    const promise = try engine.createResolvedPromise(realm, view.value);
    return promise.take();
}

/// Operation: arrayBuffer
///
/// Spec: https://www.w3.org/TR/FileAPI/#dom-blob-arraybuffer
/// Returns a Promise that resolves with an ArrayBuffer of the blob contents.
///
/// Algorithm:
/// 1. Let stream be the result of calling get stream on this.
/// 2. Let reader be the result of getting a reader from stream.
/// 3. Let promise be the result of reading all bytes from stream with reader.
/// 4. Return the result of transforming promise to create ArrayBuffer from bytes.
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // Steps 1-3 as in text(): the bytes are the blob's own.
    const realm = engine.currentRealm() orelse instance.ctx;
    // 4. ... a new ArrayBuffer whose contents are its first argument.
    const buffer = try engine.createArrayBuffer(realm, internal.blob_data.bytes);
    defer buffer.release();
    const promise = try engine.createResolvedPromise(realm, buffer.value);
    return promise.take();
}

// ============================================================================
// Tests
// ============================================================================

test "Blob - empty constructor" {
    const allocator = std.testing.allocator;

    // Create a minimal context
    const ctx = runtime.createNullContext();

    // Create empty blob (simulating constructor with no parts)
    const blob = try createFromBytes(allocator, ctx, "", "");
    defer deinit(blob);

    const size = try get_size(blob);
    try std.testing.expectEqual(@as(u64, 0), size);

    const type_str = try get_type(blob);
    try std.testing.expectEqualStrings("", type_str.asSlice());
}

test "Blob - with bytes and type" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello, World!", "text/plain");
    defer deinit(blob);

    const size = try get_size(blob);
    try std.testing.expectEqual(@as(u64, 13), size);

    const type_str = try get_type(blob);
    try std.testing.expectEqualStrings("text/plain", type_str.asSlice());
}

test "Blob - slice basic" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello, World!", "text/plain");
    defer deinit(blob);

    // Slice to get "Hello"
    const sliced = try call_slice(blob, 0, 5, runtime.DOMString.initEmpty());
    defer deinit(sliced);

    const size = try get_size(sliced);
    try std.testing.expectEqual(@as(u64, 5), size);

    // Type should be empty (not inherited) when contentType not specified
    const type_str = try get_type(sliced);
    try std.testing.expectEqualStrings("", type_str.asSlice());
}

test "Blob - slice with contentType" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello", "text/plain");
    defer deinit(blob);

    const sliced = try call_slice(blob, 0, 5, runtime.DOMString.initInterned("application/json"));
    defer deinit(sliced);

    const type_str = try get_type(sliced);
    try std.testing.expectEqualStrings("application/json", type_str.asSlice());
}

test "Blob - slice negative indices" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello, World!", "");
    defer deinit(blob);

    // Slice with -6 should give us "World!"
    const sliced = try call_slice(blob, -6, 13, runtime.DOMString.initEmpty());
    defer deinit(sliced);

    const size = try get_size(sliced);
    try std.testing.expectEqual(@as(u64, 6), size);
}
