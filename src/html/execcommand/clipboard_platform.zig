//! The clipboard actions' way to the clipboard: the platform protocol's
//! clipboard operations (docs/platform-protocol.md 6.10.6, `readClipboard`
//! and `writeClipboard` behind `platform.capabilities.clipboard`), reached
//! through the Browser's platform state (html.platform_state). Which
//! clipboard answers - the built-in platforms' in-memory one
//! (kit/memory_clipboard, D2), NSPasteboard, UIPasteboard or an OS's - is
//! the platform adapter's choice; this file sees only the protocol.
//!
//! A WRITE (copy, cut) does not wait: the protocol's note for execCommand
//! copy/cut. A `WriteRequest` owns the items the platform borrows until
//! its `deliver` or `drop`, which free it (from any thread, freeing bytes
//! only) - Blink's SystemClipboard::CommitWrite likewise posts the write
//! to the browser process and goes on.
//!
//! A READ (paste) is synchronous, as every browser reads for a paste
//! event: Blink's [Sync] mojo SystemClipboard::ReadHTML / ReadPlainText
//! inside ClipboardCommands::ExecutePaste, WebKit's synchronous Pasteboard
//! IPC in Editor::paste, Gecko's nsIClipboard GetData /
//! GetDataSnapshotSync under nsCopySupport::FireClipboardEvent. Over the
//! asynchronous protocol that is section 4's "Synchronous spec steps over
//! asynchronous platforms": the agent's thread waits for the Reply WITHOUT
//! running the agent's tasks. A `ReadRequest` has two references - the
//! caller's and the Reply's - and an atomic state word: `deliver` copies the
//! items into the request ("Crane copies what it keeps") and sets the word,
//! `drop` sets it; both wake the waiter, then let their reference go, and
//! whoever lets go last frees the request. kit/memory_clipboard answers
//! inside the call, so the wait usually returns at once; a late answer from
//! another thread, or a drop (the platform cannot answer, or its Browser
//! ends), ends the wait too.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const platform_state = @import("../platform_state.zig");

const log = std.log.scoped(.clipboard);

/// A clipboard part: one representation of what was copied - a MIME type
/// and its data.
pub const Part = struct {
    mime_type: []const u8,
    data: []const u8,
};

/// The parts a read delivered, OWNED.
pub const Contents = struct {
    allocator: std.mem.Allocator,
    /// Each part's two slices are owned.
    parts: std.ArrayList(Part) = .empty,

    pub fn init(allocator: std.mem.Allocator) Contents {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Contents) void {
        for (self.parts.items) |part| {
            self.allocator.free(part.mime_type);
            self.allocator.free(part.data);
        }
        self.parts.deinit(self.allocator);
    }

    /// The data of the first part of type `mime_type`, BORROWED.
    pub fn find(self: *const Contents, mime_type: []const u8) ?[]const u8 {
        for (self.parts.items) |part| {
            if (std.ascii.eqlIgnoreCase(part.mime_type, mime_type)) return part.data;
        }
        return null;
    }

    fn append(self: *Contents, mime_type: []const u8, data: []const u8) error{OutOfMemory}!void {
        const mime = try self.allocator.dupe(u8, mime_type);
        errdefer self.allocator.free(mime);
        const bytes = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(bytes);
        try self.parts.append(self.allocator, .{ .mime_type = mime, .data = bytes });
    }
};

/// The futex calls, as runtime.TaskSink makes them: a futex wait and wake
/// are plain system calls on an address, the same through the standard
/// library's static Io (synchronisation, not OS access: lint-platform).
fn futexWake(word: *std.atomic.Value(u32)) void {
    std.Io.Threaded.global_single_threaded.io().futexWake(u32, &word.raw, 1);
}

fn futexWait(word: *std.atomic.Value(u32), expected: u32) void {
    std.Io.Threaded.global_single_threaded.io().futexWaitTimeout(u32, &word.raw, expected, .none) catch {};
}

/// One synchronous clipboard read (see the file comment). The allocator
/// must be usable from any thread: `deliver` copies on the platform's.
pub const ReadRequest = struct {
    allocator: std.mem.Allocator,
    /// The caller's and the Reply's.
    refs: std.atomic.Value(u32) = .init(2),
    /// pending, delivered or dropped: the futex word the caller waits on.
    state: std.atomic.Value(u32) = .init(pending),
    /// What `deliver` copied; read by the caller once the state is
    /// `delivered`.
    contents: Contents,

    pub const pending: u32 = 0;
    pub const delivered: u32 = 1;
    pub const dropped: u32 = 2;

    pub fn create(allocator: std.mem.Allocator) error{OutOfMemory}!*ReadRequest {
        const self = try allocator.create(ReadRequest);
        self.* = .{ .allocator = allocator, .contents = .init(allocator) };
        return self;
    }

    /// The Reply the platform completes: exactly one of deliver and drop,
    /// once, from any thread, at any time after the call - inside it
    /// included.
    pub fn reply(self: *ReadRequest) platform.Reply(platform.ClipboardItems) {
        return .{ .context = self, .deliver = &deliver, .drop = &drop };
    }

    fn deliver(context: *anyopaque, value: *const platform.ClipboardItems) callconv(.c) void {
        const self: *ReadRequest = @ptrCast(@alignCast(context));
        // The value is borrowed for the call: copy every representation.
        const copied = self.copyIn(value);
        if (!copied) self.contents.deinit();
        if (!copied) self.contents = .init(self.allocator);
        self.finish(if (copied) delivered else dropped);
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *ReadRequest = @ptrCast(@alignCast(context));
        self.finish(dropped);
    }

    fn copyIn(self: *ReadRequest, value: *const platform.ClipboardItems) bool {
        for (value.ptr[0..value.len]) |entry| {
            for (entry.ptr[0..entry.len]) |representation| {
                self.contents.append(representation.mime_type.slice(), representation.data.slice()) catch return false;
            }
        }
        return true;
    }

    /// Set the answer, wake the waiter, then let the Reply's reference go -
    /// in that order, so the word is still there to wake.
    fn finish(self: *ReadRequest, state: u32) void {
        self.state.store(state, .release);
        futexWake(&self.state);
        self.release();
    }

    /// The caller's pause: wait for the answer without running the agent's
    /// tasks. Whether the read delivered (false: dropped).
    pub fn wait(self: *ReadRequest) bool {
        while (true) {
            const state = self.state.load(.acquire);
            if (state != pending) return state == delivered;
            futexWait(&self.state, pending);
        }
    }

    /// Let one reference go; the last frees the request.
    pub fn release(self: *ReadRequest) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.contents.deinit();
        self.allocator.destroy(self);
    }
};

/// One clipboard write: the items the platform borrows until it completes
/// the Reply, freed then (see the file comment).
const WriteRequest = struct {
    allocator: std.mem.Allocator,
    contents: Contents,
    representations: []platform.ClipboardRepresentation,
    entries: [1]platform.ClipboardEntry,
    items: platform.ClipboardItems,

    fn create(allocator: std.mem.Allocator, parts: []const Part) error{OutOfMemory}!*WriteRequest {
        const self = try allocator.create(WriteRequest);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .contents = .init(allocator), .representations = &.{}, .entries = undefined, .items = undefined };
        errdefer self.contents.deinit();
        for (parts) |part| try self.contents.append(part.mime_type, part.data);
        self.representations = try allocator.alloc(platform.ClipboardRepresentation, parts.len);
        for (self.contents.parts.items, self.representations) |part, *representation| {
            representation.* = .{ .mime_type = platform.Str.from(part.mime_type), .data = platform.Bytes.from(part.data) };
        }
        // One clipboard item holding every representation (Blink writes
        // one ui::ClipboardWriter batch; an empty list clears).
        self.entries = .{.{ .ptr = self.representations.ptr, .len = self.representations.len }};
        self.items = .{ .ptr = &self.entries, .len = if (parts.len == 0) 0 else 1 };
        return self;
    }

    fn destroy(self: *WriteRequest) void {
        self.allocator.free(self.representations);
        self.contents.deinit();
        self.allocator.destroy(self);
    }

    fn reply(self: *WriteRequest) platform.Reply(platform.Unit) {
        return .{ .context = self, .deliver = &deliver, .drop = &drop };
    }

    fn deliver(context: *anyopaque, value: *const platform.Unit) callconv(.c) void {
        _ = value;
        const self: *WriteRequest = @ptrCast(@alignCast(context));
        self.destroy();
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *WriteRequest = @ptrCast(@alignCast(context));
        log.debug("the platform dropped a clipboard write", .{});
        self.destroy();
    }
};

/// Read the clipboard for a paste in `realm`, waiting for the answer: the
/// parts of `types` (every type when empty), OWNED by `allocator`, or null
/// when there is no clipboard to read (no capability, no platform state)
/// or the platform dropped the request.
pub fn read(realm: runtime.Context, allocator: std.mem.Allocator, transient_activation: bool, types: []const []const u8) error{OutOfMemory}!?Contents {
    if (platform.capabilities.clipboard == .unsupported) return null;
    const browser = platform_state.of(realm) orelse return null;
    var parts = (try platform_state.requester(realm, transient_activation)) orelse return null;
    defer parts.deinit();
    const requester = parts.requester();
    var type_list: [8]platform.Str = undefined;
    const count = @min(types.len, type_list.len);
    for (types[0..count], type_list[0..count]) |t, *out| out.* = platform.Str.from(t);
    const request = try ReadRequest.create(allocator);
    defer request.release();
    if (platform.capabilities.clipboard != .unsupported) {
        platform.readClipboard(browser, &requester, type_list[0..count], request.reply());
    }
    if (!request.wait()) return null;
    // The request is the caller's alone once answered (the Reply let its
    // reference go): move its contents out.
    const contents = request.contents;
    request.contents = .init(allocator);
    return contents;
}

/// Write `parts` to the clipboard for a copy or cut in `realm` (an empty
/// list clears it), without waiting. Whether a write was asked of the
/// platform.
pub fn write(realm: runtime.Context, allocator: std.mem.Allocator, transient_activation: bool, parts: []const Part) error{OutOfMemory}!bool {
    if (platform.capabilities.clipboard == .unsupported) return false;
    const browser = platform_state.of(realm) orelse return false;
    var requester_parts = (try platform_state.requester(realm, transient_activation)) orelse return false;
    defer requester_parts.deinit();
    const requester = requester_parts.requester();
    const request = try WriteRequest.create(allocator, parts);
    // The platform owns the request from here: its deliver or drop frees it.
    if (platform.capabilities.clipboard != .unsupported) {
        platform.writeClipboard(browser, &requester, &request.items, request.reply());
    }
    return true;
}
