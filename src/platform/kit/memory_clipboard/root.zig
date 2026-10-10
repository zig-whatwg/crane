//! kit/memory_clipboard: a per-Browser in-memory clipboard
//! (docs/platform-protocol.md 6.10.6) - the testing platform's, and that of a
//! platform with no system clipboard (a display-less server). A platform
//! embeds a `Clipboard` in its per-Browser state and answers `readClipboard`
//! and `writeClipboard` through it. Deviation from a system clipboard, for the
//! platform's `.emulated` constant: nothing leaves the Browser, and nothing
//! another application copies arrives.

const std = @import("std");
const platform = @import("platform");

const Representation = struct {
    mime_type: []u8,
    data: []u8,
};

/// The clipboard's contents: what the last write put there, owned.
pub const Clipboard = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    /// One list of representations per item.
    items: std.ArrayList(std.ArrayList(Representation)) = .empty,

    pub fn init(allocator: std.mem.Allocator) Clipboard {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Clipboard) void {
        self.clear();
        self.items.deinit(self.allocator);
    }

    fn clear(self: *Clipboard) void {
        for (self.items.items) |*item| {
            for (item.items) |representation| {
                self.allocator.free(representation.mime_type);
                self.allocator.free(representation.data);
            }
            item.deinit(self.allocator);
        }
        self.items.clearRetainingCapacity();
    }

    /// Replace the contents with a copy of `items`; delivers when done, drops
    /// when out of memory (the write rejects).
    pub fn write(self: *Clipboard, items: *const platform.ClipboardItems, reply: platform.Reply(platform.Unit)) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.copyIn(items) catch {
            self.clear();
            return reply.drop(reply.context);
        };
        reply.deliver(reply.context, &platform.Unit{});
    }

    fn copyIn(self: *Clipboard, items: *const platform.ClipboardItems) error{OutOfMemory}!void {
        self.clear();
        for (items.ptr[0..items.len]) |item| {
            var copy: std.ArrayList(Representation) = .empty;
            errdefer copy.deinit(self.allocator);
            for (item.ptr[0..item.len]) |representation| {
                const mime_type = try self.allocator.dupe(u8, representation.mime_type.slice());
                errdefer self.allocator.free(mime_type);
                const data = try self.allocator.dupe(u8, representation.data.slice());
                errdefer self.allocator.free(data);
                try copy.append(self.allocator, .{ .mime_type = mime_type, .data = data });
            }
            try self.items.append(self.allocator, copy);
        }
    }

    /// Deliver the contents, keeping only representations of `types` (all of
    /// them when `types` is empty). The value is borrowed for `deliver`.
    pub fn read(self: *Clipboard, types: []const platform.Str, reply: platform.Reply(platform.ClipboardItems)) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const items = self.view(arena, types) catch return reply.drop(reply.context);
        reply.deliver(reply.context, &items);
    }

    fn view(self: *Clipboard, arena: std.mem.Allocator, types: []const platform.Str) error{OutOfMemory}!platform.ClipboardItems {
        const out = try arena.alloc(platform.ClipboardEntry, self.items.items.len);
        for (self.items.items, out) |item, *target| {
            var kept: std.ArrayList(platform.ClipboardRepresentation) = .empty;
            for (item.items) |representation| {
                if (!wanted(types, representation.mime_type)) continue;
                try kept.append(arena, .{ .mime_type = platform.Str.from(representation.mime_type), .data = platform.Bytes.from(representation.data) });
            }
            target.* = .{ .ptr = kept.items.ptr, .len = kept.items.len };
        }
        return .{ .ptr = out.ptr, .len = out.len };
    }
};

fn wanted(types: []const platform.Str, mime_type: []const u8) bool {
    if (types.len == 0) return true;
    for (types) |t| {
        if (std.mem.eql(u8, t.slice(), mime_type)) return true;
    }
    return false;
}
