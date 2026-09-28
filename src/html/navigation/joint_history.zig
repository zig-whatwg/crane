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
//! Each entry also carries what the navigation API reads (HTML 7.2.6): its
//! navigation API key and ID, its navigation API state, and its document
//! state's origin, serialized, which decides the contiguous same-origin run
//! of entries `navigation.entries()` shows.
//!
//! Engine-free: documents are opaque, and a state is bytes (the
//! StructuredSerializeForStorage wire format, or a primitive).

const std = @import("std");
const Allocator = std.mem.Allocator;

extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;

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
    /// Navigation API state (navigation.currentEntry.getState()), initially
    /// the serialization of undefined.
    api_state: SerializedState = .undefined,
    /// Navigation API key - shared with the entries a "replace" put in its
    /// place - and ID, each a random UUID.
    api_key: [36]u8 = undefined,
    api_id: [36]u8 = undefined,
    /// Its document state's origin, serialized. Owned.
    origin: []u8 = &.{},
    /// The document state's resource when it is a string: an iframe srcdoc
    /// document's markup, which a traversal loads again rather than the
    /// srcdoc attribute's current value. Owned.
    resource: ?[]u8 = null,
    /// "Scroll restoration mode" is "manual".
    scroll_restoration_manual: bool = false,

    fn deinit(self: *Entry, allocator: Allocator) void {
        allocator.free(self.url);
        self.state.deinit(allocator);
        self.api_state.deinit(allocator);
        allocator.free(self.origin);
        if (self.resource) |r| allocator.free(r);
    }
};

pub const HistoryHandling = enum { push, replace };

/// What an entry records of a document when it is first given one: its URL
/// and origin, serialized, owned by the allocator the caller was given.
pub const DocumentInfo = struct {
    url: []u8,
    origin: []u8,
};

pub const JointHistory = struct {
    allocator: Allocator,
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    /// "Current session history step".
    current_step: u32 = 0,
    next_id: u64 = 1,
    next_document_state: u64 = 1,
    /// For the navigation API's keys and IDs.
    prng: std.Random.DefaultPrng,

    pub fn init(allocator: Allocator) JointHistory {
        var seed: u64 = 0;
        if (getentropy(std.mem.asBytes(&seed).ptr, @sizeOf(u64)) != 0) seed = @intFromPtr(&seed);
        return .{ .allocator = allocator, .prng = std.Random.DefaultPrng.init(seed) };
    }

    /// "Generate a random UUID": a version 4 UUID, lowercase.
    fn randomUuid(self: *JointHistory) [36]u8 {
        var bytes: [16]u8 = undefined;
        self.prng.random().bytes(&bytes);
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        var out: [36]u8 = undefined;
        const hex = "0123456789abcdef";
        var o: usize = 0;
        for (bytes, 0..) |b, i| {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                out[o] = '-';
                o += 1;
            }
            out[o] = hex[b >> 4];
            out[o + 1] = hex[b & 0x0f];
            o += 2;
        }
        return out;
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
    pub fn addInitialEntry(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, origin: []const u8) !void {
        if (self.hasNavigable(navigable)) return;
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.append(navigable, self.current_step, url, doc_state, document, .null, .undefined, origin, null);
    }

    fn append(
        self: *JointHistory,
        navigable: u64,
        step: u32,
        url: []const u8,
        doc_state: u64,
        document: ?*anyopaque,
        state: SerializedState,
        api_state: SerializedState,
        origin: []const u8,
        api_key: ?[36]u8,
    ) !void {
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        const owned_origin = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(owned_origin);
        try self.entries.append(self.allocator, .{
            .id = self.next_id,
            .navigable = navigable,
            .step = step,
            .url = owned_url,
            .document_state = doc_state,
            .document = document,
            .state = state,
            .api_state = api_state,
            .api_key = api_key orelse self.randomUuid(),
            .api_id = self.randomUuid(),
            .origin = owned_origin,
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

    /// "Finalize a cross-document navigation" steps 5-10 for a new document
    /// of `origin`: "push" clears the forward history and adds an entry one
    /// step on, and makes that the current step; "replace" puts the entry in
    /// place of the navigable's current one, at its step - keeping its
    /// navigation API key when the two are same origin (step 9.3).
    pub fn commitDocument(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, origin: []const u8, handling: HistoryHandling) !void {
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        const keep_key = if (self.currentEntry(navigable)) |current| std.mem.eql(u8, current.origin, origin) else false;
        try self.commit(navigable, url, doc_state, document, .null, .undefined, origin, handling, keep_key);
    }

    /// "URL and history update steps" / "navigate to a fragment": an entry on
    /// the navigable's current document - sharing its document state and
    /// origin - with classic history API `state`, pushed or replacing the
    /// current one (a replace keeps the navigation API key). Its navigation
    /// API state is `api_state`, or, when null, carried over from the
    /// current entry (a fragment navigation's).
    pub fn commitSameDocument(self: *JointHistory, navigable: u64, url: []const u8, state: SerializedState, handling: HistoryHandling, api_state: ?SerializedState) !void {
        const current = self.currentEntry(navigable) orelse return error.NoCurrentEntry;
        // The document state is shared, so its resource is too.
        const resource: ?[]u8 = if (current.resource) |r| try self.allocator.dupe(u8, r) else null;
        errdefer if (resource) |r| self.allocator.free(r);
        const origin = try self.allocator.dupe(u8, current.origin);
        defer self.allocator.free(origin);
        const new_api_state = api_state orelse try current.api_state.clone(self.allocator);
        try self.commit(navigable, url, current.document_state, current.document, state, new_api_state, origin, handling, true);
        const committed = self.currentEntry(navigable) orelse unreachable;
        if (committed.resource) |old| self.allocator.free(old);
        committed.resource = resource;
    }

    /// navigation.updateCurrentEntry() and navigate()'s state: `navigable`'s
    /// current entry's navigation API state becomes `api_state` (taken).
    pub fn setCurrentApiState(self: *JointHistory, navigable: u64, api_state: SerializedState) !void {
        var owned = api_state;
        const entry = self.currentEntry(navigable) orelse {
            owned.deinit(self.allocator);
            return error.NoCurrentEntry;
        };
        entry.api_state.deinit(self.allocator);
        entry.api_state = owned;
    }

    /// HTML "get session history entries for the navigation API" for
    /// `navigable` at the current step: its entries, by step, that are
    /// contiguous with its current one and same origin with it, into `out`.
    /// Returns the current entry's index there. (The spec's backward walk
    /// reads "while i > 0", which would leave the first entry out; every
    /// engine, and WPT, includes it.)
    pub fn apiEntries(self: *JointHistory, navigable: u64, allocator: Allocator, out: *std.ArrayListUnmanaged(*Entry)) !usize {
        out.clearRetainingCapacity();
        var raw: std.ArrayListUnmanaged(*Entry) = .empty;
        defer raw.deinit(allocator);
        for (self.entries.items) |*entry| {
            if (entry.navigable == navigable) try raw.append(allocator, entry);
        }
        std.mem.sort(*Entry, raw.items, {}, struct {
            fn lessThan(_: void, a: *Entry, b: *Entry) bool {
                return a.step < b.step;
            }
        }.lessThan);
        const current = self.currentEntry(navigable) orelse return 0;
        const start = std.mem.indexOfScalar(*Entry, raw.items, current) orelse return 0;
        var first = start;
        while (first > 0 and std.mem.eql(u8, raw.items[first - 1].origin, current.origin)) first -= 1;
        var last = start;
        while (last + 1 < raw.items.len and std.mem.eql(u8, raw.items[last + 1].origin, current.origin)) last += 1;
        try out.appendSlice(allocator, raw.items[first .. last + 1]);
        return start - first;
    }

    /// Record `resource` - a srcdoc document's markup - as the document
    /// state's resource of `navigable`'s current entry.
    pub fn setCurrentResource(self: *JointHistory, navigable: u64, resource: ?[]const u8) !void {
        const entry = self.currentEntry(navigable) orelse return error.NoCurrentEntry;
        const copy: ?[]u8 = if (resource) |r| try self.allocator.dupe(u8, r) else null;
        if (entry.resource) |old| self.allocator.free(old);
        entry.resource = copy;
    }

    fn commit(
        self: *JointHistory,
        navigable: u64,
        url: []const u8,
        doc_state: u64,
        document: ?*anyopaque,
        state: SerializedState,
        api_state: SerializedState,
        origin: []const u8,
        handling: HistoryHandling,
        keep_key_on_replace: bool,
    ) !void {
        switch (handling) {
            .push => {
                self.clearForward();
                const step = self.current_step + 1;
                try self.append(navigable, step, url, doc_state, document, state, api_state, origin, null);
                self.current_step = step;
            },
            .replace => {
                const current = self.currentEntry(navigable) orelse {
                    try self.append(navigable, self.current_step, url, doc_state, document, state, api_state, origin, null);
                    return;
                };
                const owned_url = try self.allocator.dupe(u8, url);
                const owned_origin = self.allocator.dupe(u8, origin) catch |err| {
                    self.allocator.free(owned_url);
                    return err;
                };
                self.allocator.free(current.url);
                current.url = owned_url;
                self.allocator.free(current.origin);
                current.origin = owned_origin;
                current.state.deinit(self.allocator);
                current.state = state;
                current.api_state.deinit(self.allocator);
                current.api_state = api_state;
                if (!keep_key_on_replace) current.api_key = self.randomUuid();
                current.api_id = self.randomUuid();
                // A new document state has a resource of its own, if any.
                if (current.document_state != doc_state) {
                    if (current.resource) |r| self.allocator.free(r);
                    current.resource = null;
                }
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
