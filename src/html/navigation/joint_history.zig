//! A traversable navigable's session history (HTML 7.4.1), flattened: every
//! session history entry of the traversable and of its descendant navigables
//! in one list, each tagged with its navigable and its step.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#session-history
//!
//! The spec nests a child navigable's entries in its parent entry's document
//! state ("nested histories") so they can be restored when a parent document
//! is recreated. Crane keeps no document for traversal (no bfcache), and a
//! child navigable does not survive its parent document, so the entries of a
//! destroyed navigable are dropped instead (`removeNavigable`) and the nesting
//! is not needed: "get session history entries" of a navigable is the
//! entries tagged with it, and "get all used history steps" is every entry's
//! step.
//!
//! Engine-free: documents are opaque, and a state is bytes (the
//! StructuredSerializeForStorage wire format, or a primitive).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Serialized state: a primitive, a string, or V8's serialization of an
/// object - "StructuredSerializeForStorage" output. Owned by the entry.
pub const SerializedState = union(enum) {
    undefined,
    null,
    boolean: bool,
    number: f64,
    string: []u8,
    bytes: []u8,

    pub fn deinit(self: *SerializedState, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .bytes => |b| allocator.free(b),
            else => {},
        }
        self.* = .null;
    }

    pub fn clone(self: SerializedState, allocator: Allocator) !SerializedState {
        return switch (self) {
            .string => |s| .{ .string = try allocator.dupe(u8, s) },
            .bytes => |b| .{ .bytes = try allocator.dupe(u8, b) },
            else => self,
        };
    }
};

/// A session history entry.
pub const Entry = struct {
    /// Unique among this history's entries, for the engine to hold across
    /// turns (the navigation that repopulates an entry).
    id: u64,
    /// The navigable it belongs to (a browsing context's id).
    navigable: u64,
    step: u32,
    /// Its URL, serialized. Owned.
    url: []u8,
    /// Entries sharing a document state - a document and the pushState or
    /// fragment entries on it - share this.
    document_state: u64,
    /// The document state's document, or null once it is gone.
    document: ?*anyopaque,
    /// Classic history API state (history.state).
    state: SerializedState = .null,
    /// "Scroll restoration mode" is "manual".
    scroll_restoration_manual: bool = false,

    fn deinit(self: *Entry, allocator: Allocator) void {
        allocator.free(self.url);
        self.state.deinit(allocator);
    }
};

pub const HistoryHandling = enum { push, replace };

pub const JointHistory = struct {
    allocator: Allocator,
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    /// "Current session history step".
    current_step: u32 = 0,
    next_id: u64 = 1,
    next_document_state: u64 = 1,

    pub fn init(allocator: Allocator) JointHistory {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *JointHistory) void {
        for (self.entries.items) |*entry| entry.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    /// `navigable`'s entry at `step`: "get the target history entry" - the
    /// one with the greatest step less than or equal to `step` - or null when
    /// it has none there yet.
    pub fn entryAt(self: *JointHistory, navigable: u64, step: u32) ?*Entry {
        var best: ?*Entry = null;
        for (self.entries.items) |*entry| {
            if (entry.navigable != navigable or entry.step > step) continue;
            if (best == null or entry.step >= best.?.step) best = entry;
        }
        return best;
    }

    /// `navigable`'s current session history entry.
    pub fn currentEntry(self: *JointHistory, navigable: u64) ?*Entry {
        return self.entryAt(navigable, self.current_step);
    }

    pub fn hasNavigable(self: *const JointHistory, navigable: u64) bool {
        for (self.entries.items) |entry| {
            if (entry.navigable == navigable) return true;
        }
        return false;
    }

    /// HTML "initialize the navigable" (and, for a child, "create a new child
    /// navigable" step 12): `navigable`'s first entry, at the current step -
    /// it adds no step. Nothing when it has one already.
    pub fn addInitialEntry(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque) !void {
        if (self.hasNavigable(navigable)) return;
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.append(navigable, self.current_step, url, doc_state, document, .null);
    }

    fn append(self: *JointHistory, navigable: u64, step: u32, url: []const u8, doc_state: u64, document: ?*anyopaque, state: SerializedState) !void {
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        try self.entries.append(self.allocator, .{
            .id = self.next_id,
            .navigable = navigable,
            .step = step,
            .url = owned_url,
            .document_state = doc_state,
            .document = document,
            .state = state,
        });
        self.next_id += 1;
    }

    /// "Clear the forward session history": every entry past the current
    /// step goes.
    pub fn clearForward(self: *JointHistory) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].step > self.current_step) {
                var removed = self.entries.orderedRemove(i);
                removed.deinit(self.allocator);
            } else i += 1;
        }
    }

    /// "Finalize a cross-document navigation" steps 5-10 for a new document:
    /// "push" clears the forward history and adds an entry one step on, and
    /// makes that the current step; "replace" puts the entry in place of the
    /// navigable's current one, at its step.
    pub fn commitDocument(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, handling: HistoryHandling) !void {
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.commit(navigable, url, doc_state, document, .null, handling);
    }

    /// "URL and history update steps" / "navigate to a fragment": an entry on
    /// the navigable's current document - sharing its document state - with
    /// `state`, pushed or replacing the current one.
    pub fn commitSameDocument(self: *JointHistory, navigable: u64, url: []const u8, state: SerializedState, handling: HistoryHandling) !void {
        const current = self.currentEntry(navigable) orelse return error.NoCurrentEntry;
        try self.commit(navigable, url, current.document_state, current.document, state, handling);
    }

    fn commit(self: *JointHistory, navigable: u64, url: []const u8, doc_state: u64, document: ?*anyopaque, state: SerializedState, handling: HistoryHandling) !void {
        switch (handling) {
            .push => {
                self.clearForward();
                const step = self.current_step + 1;
                try self.append(navigable, step, url, doc_state, document, state);
                self.current_step = step;
            },
            .replace => {
                const current = self.currentEntry(navigable) orelse {
                    try self.append(navigable, self.current_step, url, doc_state, document, state);
                    return;
                };
                const owned_url = try self.allocator.dupe(u8, url);
                self.allocator.free(current.url);
                current.url = owned_url;
                current.state.deinit(self.allocator);
                current.state = state;
                current.document_state = doc_state;
                current.document = document;
                current.id = self.next_id;
                self.next_id += 1;
            },
        }
    }

    /// "Get all used history steps", sorted and unique, into `out`.
    pub fn usedSteps(self: *const JointHistory, allocator: Allocator, out: *std.ArrayListUnmanaged(u32)) !void {
        out.clearRetainingCapacity();
        for (self.entries.items) |entry| {
            if (std.mem.indexOfScalar(u32, out.items, entry.step) == null) try out.append(allocator, entry.step);
        }
        std.mem.sort(u32, out.items, {}, std.sort.asc(u32));
    }

    /// "Get the history object length and index" for the current step:
    /// (the number of used steps, the current step's index among them).
    pub fn lengthAndIndex(self: *const JointHistory) struct { length: u32, index: u32 } {
        var steps: std.ArrayListUnmanaged(u32) = .empty;
        defer steps.deinit(self.allocator);
        self.usedSteps(self.allocator, &steps) catch return .{ .length = 1, .index = 0 };
        if (steps.items.len == 0) return .{ .length = 1, .index = 0 };
        const index = std.mem.indexOfScalar(u32, steps.items, self.current_step) orelse steps.items.len - 1;
        return .{ .length = @intCast(steps.items.len), .index = @intCast(index) };
    }

    /// "Traverse the history by a delta" step 4.1-4.4: the used step `delta`
    /// away from the current one, or null when there is none.
    pub fn stepByDelta(self: *const JointHistory, delta: i64) ?u32 {
        var steps: std.ArrayListUnmanaged(u32) = .empty;
        defer steps.deinit(self.allocator);
        self.usedSteps(self.allocator, &steps) catch return null;
        const current = std.mem.indexOfScalar(u32, steps.items, self.current_step) orelse return null;
        const target = @as(i64, @intCast(current)) + delta;
        if (target < 0 or target >= @as(i64, @intCast(steps.items.len))) return null;
        return steps.items[@intCast(target)];
    }

    /// A navigable was destroyed: its entries go ("update for navigable
    /// creation/destruction"), and the current step becomes the used step at
    /// or before it ("get the used step").
    pub fn removeNavigable(self: *JointHistory, navigable: u64) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (self.entries.items[i].navigable == navigable) {
                var removed = self.entries.orderedRemove(i);
                removed.deinit(self.allocator);
            } else i += 1;
        }
        var used: u32 = 0;
        var found = false;
        for (self.entries.items) |entry| {
            if (entry.step <= self.current_step and (!found or entry.step > used)) {
                used = entry.step;
                found = true;
            }
        }
        if (found) self.current_step = used;
    }

    /// A document was destroyed: entries that held it keep their URL, to be
    /// repopulated by a traversal.
    pub fn forgetDocument(self: *JointHistory, document: *anyopaque) void {
        for (self.entries.items) |*entry| {
            if (entry.document == document) entry.document = null;
        }
    }

    /// The entry whose id is `id`, if it is still in the history.
    pub fn entryById(self: *JointHistory, id: u64) ?*Entry {
        for (self.entries.items) |*entry| {
            if (entry.id == id) return entry;
        }
        return null;
    }
};
