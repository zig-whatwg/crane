//! HTML 2.7.1 serializable objects: the Record a [Serializable] interface's
//! serialization steps fill and its deserialization steps read - engine-
//! neutral, so the same steps serve every adapter's structured serialization
//! (V8's ValueSerializer delegate; the walker an engine without one uses).
//!
//! A step's fields are written as an ordered stream of bytes - [[X]], then
//! [[Y]] - and read back in the same order (the record is "very symmetric",
//! 2.7.1). A field that is itself a JavaScript value is a sub-serialization
//! (2.7.3 step 26.3): the steps hand the value over, and the adapter
//! serializes it with the same `memory` as the rest of the graph, so identity
//! and cycles hold across it. Nothing in either record names an engine type,
//! and nothing a step writes may be a pointer: "the resulting data serialized
//! into serialized must be independent of any realm" - and of any agent and
//! thread, since a worker's message is deserialized on the worker's thread
//! and an IndexedDB record outlives the process.
//!
//! The steps are each [Serializable] interface's own, in its impl; the
//! generated interface publishes them as `serializable_steps`
//! (`SerializableSteps`), which is how an adapter finds them, by the
//! identifier of a platform object's primary interface.
//!
//! Spec: https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const JSValue = @import("js_value.zig").JSValue;
const Context = @import("context.zig").Context;

/// Thread-safe, reference-counted sidecar of engine-neutral attachments (such
/// as file-backed `file.BlobData` handles) carried alongside a structured
/// serialization so file-backed Blobs and Files preserve their snapshot and
/// file token across `structuredClone`, `postMessage`, `BroadcastChannel`,
/// Workers, and IndexedDB's synchronous clone step without reading from disk.
///
/// Each entry transfers one owned reference to `ptr` and supplies a
/// thread-safe `release_fn` invoked when the last `SerializedAttachments`
/// owner drops. `retain` and `release` use atomic refcounting and never touch
/// engine/isolate state.
pub const SerializedAttachments = struct {
    /// Attachment tag for a retained `*file.BlobData`.
    pub const blob_tag: u32 = 0x424C4F42;

    pub const Entry = struct {
        tag: u32,
        ptr: *anyopaque,
        release_fn: *const fn (*anyopaque) void,
    };

    allocator: std.mem.Allocator,
    ref_count: std.atomic.Value(usize),
    items: std.ArrayListUnmanaged(Entry) = .empty,

    pub fn create(allocator: std.mem.Allocator) std.mem.Allocator.Error!*SerializedAttachments {
        const self = try allocator.create(SerializedAttachments);
        self.* = .{
            .allocator = allocator,
            .ref_count = std.atomic.Value(usize).init(1),
            .items = .empty,
        };
        return self;
    }

    pub fn retain(self: *SerializedAttachments) *SerializedAttachments {
        _ = self.ref_count.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn release(self: *SerializedAttachments) void {
        if (self.ref_count.fetchSub(1, .acq_rel) == 1) {
            for (self.items.items) |entry| entry.release_fn(entry.ptr);
            self.items.deinit(self.allocator);
            self.allocator.destroy(self);
        }
    }

    /// Append an attachment (transfers one owned reference to `ptr` on
    /// success; on OOM the caller still owns `ptr`). Returns its index.
    pub fn append(self: *SerializedAttachments, tag: u32, ptr: *anyopaque, release_fn: *const fn (*anyopaque) void) std.mem.Allocator.Error!u32 {
        const index: u32 = std.math.cast(u32, self.items.items.len) orelse return error.OutOfMemory;
        try self.items.append(self.allocator, .{ .tag = tag, .ptr = ptr, .release_fn = release_fn });
        return index;
    }

    /// Borrow attachment `index` if in bounds and its `tag` matches.
    pub fn get(self: *const SerializedAttachments, index: u32, expected_tag: u32) ?*anyopaque {
        if (index >= self.items.items.len) return null;
        const entry = self.items.items[index];
        if (entry.tag != expected_tag) return null;
        return entry.ptr;
    }
};

/// Lazy writer for a serialization's `SerializedAttachments` sidecar: creates
/// the heap sidecar only when a platform object actually attaches a handle,
/// keeping non-attachment serializations allocation-free.
pub const AttachmentWriter = struct {
    allocator: std.mem.Allocator,
    slot: *?*SerializedAttachments,
};

/// The serialization steps' `serialized`, being filled. `for_storage` is the
/// steps' forStorage argument: true only under StructuredSerializeForStorage
/// (IndexedDB, history state); steps that must not be stored refuse with
/// `error.DataCloneError`.
pub const SerializationRecord = struct {
    allocator: std.mem.Allocator,
    for_storage: bool,
    /// The steps' own fields, in the order they wrote them.
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    /// The sub-serializations, in the order the steps asked for them. BORROWED
    /// until the serialization steps return: the adapter serializes them
    /// then, into the same record and with the same memory. Each one must
    /// therefore live at least that long - it is the platform object's own
    /// state (a quad's points, an ImageData's data array), never a value the
    /// steps made and released.
    sub_values: std.ArrayListUnmanaged(JSValue) = .empty,
    /// Optional attachment sidecar writer for callers that carry a
    /// `SerializedAttachments` alongside the serialized bytes. Null for
    /// persistent inline storage (`structuredSerializeForStorage`).
    attachments: ?AttachmentWriter = null,

    pub const Error = error{OutOfMemory};

    pub fn init(allocator: std.mem.Allocator, for_storage: bool) SerializationRecord {
        return .{ .allocator = allocator, .for_storage = for_storage };
    }

    pub fn deinit(self: *SerializationRecord) void {
        self.bytes.deinit(self.allocator);
        self.sub_values.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn writeUint32(self: *SerializationRecord, value: u32) Error!void {
        var buffer: [4]u8 = undefined;
        std.mem.writeInt(u32, &buffer, value, .little);
        try self.bytes.appendSlice(self.allocator, &buffer);
    }

    pub fn writeUint64(self: *SerializationRecord, value: u64) Error!void {
        var buffer: [8]u8 = undefined;
        std.mem.writeInt(u64, &buffer, value, .little);
        try self.bytes.appendSlice(self.allocator, &buffer);
    }

    pub fn writeInt64(self: *SerializationRecord, value: i64) Error!void {
        try self.writeUint64(@bitCast(value));
    }

    /// A double by its bits: -0, the infinities and NaN survive.
    pub fn writeDouble(self: *SerializationRecord, value: f64) Error!void {
        try self.writeUint64(@bitCast(value));
    }

    pub fn writeBool(self: *SerializationRecord, value: bool) Error!void {
        try self.bytes.append(self.allocator, @intFromBool(value));
    }

    /// A byte sequence, copied: its length, then its bytes.
    pub fn writeBytes(self: *SerializationRecord, value: []const u8) Error!void {
        try self.writeUint64(value.len);
        try self.bytes.appendSlice(self.allocator, value);
    }

    /// A string, as its bytes (the steps say which encoding they keep).
    pub fn writeString(self: *SerializationRecord, value: []const u8) Error!void {
        try self.writeBytes(value);
    }

    /// HTML "sub-serialization" of `value`: StructuredSerializeInternal(value,
    /// forStorage, memory). `value` BORROWED until the steps return (see
    /// `sub_values`).
    pub fn subSerialize(self: *SerializationRecord, value: JSValue) Error!void {
        try self.sub_values.append(self.allocator, value);
    }

    /// Whether this serialization carries a sidecar attachment table.
    pub fn supportsAttachments(self: *const SerializationRecord) bool {
        return self.attachments != null;
    }

    /// Attach an owned handle (`ptr`, released by `release_fn`) to the
    /// serialization's sidecar and return its index. On OOM the caller still
    /// owns `ptr`.
    pub fn addAttachment(self: *SerializationRecord, tag: u32, ptr: *anyopaque, release_fn: *const fn (*anyopaque) void) Error!u32 {
        const writer = self.attachments orelse unreachable;
        const list = writer.slot.* orelse blk: {
            const created = try SerializedAttachments.create(writer.allocator);
            writer.slot.* = created;
            break :blk created;
        };
        return list.append(tag, ptr, release_fn);
    }
};

/// The deserialization steps' `serialized`, being read in the order it was
/// written. A record shorter than its steps expect is a DataCloneError: it
/// was not written by them (or not by this build's).
pub const DeserializationRecord = struct {
    bytes: []const u8,
    position: usize = 0,
    /// The sub-deserializations, in order: each StructuredDeserialize(sub,
    /// targetRealm, memory), already made in the target realm. BORROWED until
    /// the deserialization steps return; a step that keeps one retains it.
    sub_values: []const JSValue = &.{},
    next_sub_value: usize = 0,
    /// Optional sidecar attachment table (BORROWED for the call).
    attachments: ?*const SerializedAttachments = null,

    pub const Error = error{DataCloneError};

    fn take(self: *DeserializationRecord, n: usize) Error![]const u8 {
        if (self.bytes.len - self.position < n) return error.DataCloneError;
        const out = self.bytes[self.position..][0..n];
        self.position += n;
        return out;
    }

    pub fn readUint32(self: *DeserializationRecord) Error!u32 {
        return std.mem.readInt(u32, (try self.take(4))[0..4], .little);
    }

    pub fn readUint64(self: *DeserializationRecord) Error!u64 {
        return std.mem.readInt(u64, (try self.take(8))[0..8], .little);
    }

    pub fn readInt64(self: *DeserializationRecord) Error!i64 {
        return @bitCast(try self.readUint64());
    }

    pub fn readDouble(self: *DeserializationRecord) Error!f64 {
        return @bitCast(try self.readUint64());
    }

    pub fn readBool(self: *DeserializationRecord) Error!bool {
        return switch ((try self.take(1))[0]) {
            0 => false,
            1 => true,
            else => error.DataCloneError,
        };
    }

    /// A byte sequence `writeBytes` wrote. BORROWED until the steps return:
    /// copy what you keep.
    pub fn readBytes(self: *DeserializationRecord) Error![]const u8 {
        const len = try self.readUint64();
        if (len > self.bytes.len - self.position) return error.DataCloneError;
        return self.take(@intCast(len));
    }

    pub fn readString(self: *DeserializationRecord) Error![]const u8 {
        return self.readBytes();
    }

    /// HTML "sub-deserialization" of the next value `subSerialize` wrote.
    /// BORROWED until the steps return.
    pub fn subDeserialize(self: *DeserializationRecord) Error!JSValue {
        if (self.next_sub_value >= self.sub_values.len) return error.DataCloneError;
        defer self.next_sub_value += 1;
        return self.sub_values[self.next_sub_value];
    }

    /// Borrow an attachment written with `addAttachment`. Steps that retain
    /// the handle must take their own reference before returning.
    pub fn readAttachment(self: *const DeserializationRecord, index: u32, expected_tag: u32) Error!*anyopaque {
        const list = self.attachments orelse return error.DataCloneError;
        return list.get(index, expected_tag) orelse error.DataCloneError;
    }
};

/// A [Serializable] interface's two algorithms (HTML 2.7.1), as its generated
/// interface publishes them (`serializable_steps`).
pub const SerializableSteps = struct {
    /// The serialization steps, given `value` - a platform object whose
    /// PRIMARY interface is this one - and `serialized` (which carries
    /// forStorage).
    serialize: *const fn (value: *Instance, serialized: *SerializationRecord) anyerror!void,
    /// StructuredDeserialize steps 22.3 and 24.4: "a new instance of the
    /// interface identified by interfaceName, created in targetRealm", set up
    /// by the deserialization steps given `serialized`, it and
    /// `target_realm`. The instance is returned unwrapped; the adapter wraps
    /// it in `target_realm`.
    deserialize: *const fn (serialized: *DeserializationRecord, target_realm: Context) anyerror!*Instance,
};
