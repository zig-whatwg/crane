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

/// A policy container, as a document state's history policy container keeps
/// one (Fetch's: CSP list, referrer policy).
pub const PolicyContainer = @import("fetch").internal.PolicyContainer;
pub const ReferrerPolicy = @import("fetch").internal.ReferrerPolicy;

/// Whether a document whose referrer policy is `policy` hides its URL from
/// the navigation API of the documents after it: "no-referrer" or "origin".
pub fn protectsUrl(policy: ReferrerPolicy) bool {
    return policy == .no_referrer or policy == .origin;
}

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
    /// The document state's history policy container: the policy container
    /// its document was made with, when the document's URL "requires storing
    /// the policy container in history" (an about: or data: URL) - for a
    /// traversal back to it ("determining navigation params policy
    /// container" step 1). Shared by the entries of the document state, each
    /// holding its own clone. Owned.
    history_policy_container: ?PolicyContainer = null,
    /// "Scroll restoration mode" is "manual".
    scroll_restoration_manual: bool = false,
    /// Its document's referrer policy was "no-referrer" or "origin" when the
    /// document went (`forgetDocument`): a NavigationHistoryEntry for it,
    /// read from another document, has a null url (HTML
    /// NavigationHistoryEntry url getter step 4, as the browsers key it - see
    /// forgetDocument). Shared by the entries of the document state.
    protect_url: bool = false,
    /// What the navigation that committed its document state's document
    /// recorded for that document's navigation.activation - on one entry of
    /// the state (`setActivation`). Owned.
    activation: ?*Activation = null,

    fn deinit(self: *Entry, allocator: Allocator) void {
        allocator.free(self.url);
        self.state.deinit(allocator);
        self.api_state.deinit(allocator);
        allocator.free(self.origin);
        if (self.resource) |r| allocator.free(r);
        self.dropHistoryPolicyContainer();
        self.dropActivation(allocator);
    }

    fn dropHistoryPolicyContainer(self: *Entry) void {
        if (self.history_policy_container) |*container| container.deinit();
        self.history_policy_container = null;
    }

    fn dropActivation(self: *Entry, allocator: Allocator) void {
        const activation = self.activation orelse return;
        activation.deinit(allocator);
        allocator.destroy(activation);
        self.activation = null;
    }
};

/// A NavigationType.
pub const NavigationType = enum { push, replace, reload, traverse };

/// A session history entry as it was at one moment - what a
/// NavigationHistoryEntry records of it - kept after the entry itself has
/// changed or gone (a "replace" changes an entry in place). Owned strings.
pub const EntrySnapshot = struct {
    id: u64,
    navigable: u64,
    url: []u8,
    api_key: [36]u8,
    api_id: [36]u8,
    /// Its document state's origin, serialized.
    origin: []u8,

    pub fn deinit(self: *EntrySnapshot, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.origin);
    }

    /// The entry it describes, for making a NavigationHistoryEntry from:
    /// borrowing this snapshot's strings, with no document and no state.
    pub fn asEntry(self: *const EntrySnapshot) Entry {
        return .{
            .id = self.id,
            .navigable = self.navigable,
            .step = 0,
            .url = self.url,
            .document_state = 0,
            .document = null,
            .api_key = self.api_key,
            .api_id = self.api_id,
            .origin = self.origin,
        };
    }
};

/// HTML "update document for history step application" step 7's inputs for
/// a new document: what the navigation API makes the document's
/// NavigationActivation from. Recorded when a cross-document navigation
/// commits the document, before any of its script runs.
pub const Activation = struct {
    navigation_type: NavigationType,
    /// previousEntryForActivation: the navigable's active entry before the
    /// navigation, as it was then. Null for none.
    previous: ?EntrySnapshot,
    /// The entry the document was activated with - "navigation's current
    /// entry" at that moment.
    entry: EntrySnapshot,

    pub fn deinit(self: *Activation, allocator: Allocator) void {
        if (self.previous) |*p| p.deinit(allocator);
        self.entry.deinit(allocator);
    }
};

/// What a cross-document commit reserves before the document it makes
/// exists: the new entry's id, navigation API key and navigation API ID -
/// HTML's targetEntry, which the pageswap event names before the old
/// document unloads.
pub const Prepared = struct {
    id: u64,
    api_key: [36]u8,
    api_id: [36]u8,
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

    /// Give `document` to every entry of `document_state` - a document the
    /// engine committed to the history before its parser ran, whose
    /// pushState and fragment entries made meanwhile share its state.
    pub fn setDocumentOfState(self: *JointHistory, document_state: u64, document: ?*anyopaque) void {
        for (self.entries.items) |*entry| {
            if (entry.document_state == document_state) entry.document = document;
        }
    }

    /// The size of `navigable`'s session history entries - its own, not the
    /// steps its descendants add to the joint history.
    pub fn entryCount(self: *const JointHistory, navigable: u64) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (entry.navigable == navigable) count += 1;
        }
        return count;
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
        try self.append(navigable, self.current_step, url, doc_state, document, .null, .undefined, origin, null, null);
    }

    /// HTML "create a new child navigable" step 12 for `navigable`, a child
    /// of `parent`: its first entry, at the step of the first of the
    /// parent's entries that share the parent's current document state -
    /// the step the parent's document began at, not the current one, so a
    /// later truncation of the parent's forward entries leaves it. At the
    /// current step when the parent has no entry. Nothing when it has one.
    pub fn addChildInitialEntry(self: *JointHistory, navigable: u64, parent: u64, url: []const u8, document: ?*anyopaque, origin: []const u8) !void {
        if (self.hasNavigable(navigable)) return;
        var step = self.current_step;
        if (self.currentEntry(parent)) |parent_entry| {
            step = parent_entry.step;
            for (self.entries.items) |entry| {
                if (entry.navigable == parent and entry.document_state == parent_entry.document_state and entry.step < step) step = entry.step;
            }
        }
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.append(navigable, step, url, doc_state, document, .null, .undefined, origin, null, null);
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
        prepared: ?Prepared,
    ) !void {
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        const owned_origin = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(owned_origin);
        const id = if (prepared) |p| p.id else self.next_id;
        try self.entries.append(self.allocator, .{
            .id = id,
            .navigable = navigable,
            .step = step,
            .url = owned_url,
            .document_state = doc_state,
            .document = document,
            .state = state,
            .api_state = api_state,
            .api_key = if (prepared) |p| p.api_key else api_key orelse self.randomUuid(),
            .api_id = if (prepared) |p| p.api_id else self.randomUuid(),
            .origin = owned_origin,
        });
        if (prepared == null) self.next_id += 1;
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
        try self.commitPreparedDocument(navigable, url, document, origin, handling, self.prepareDocument(navigable, origin, handling));
    }

    /// Reserve the entry a cross-document commit of a document of `origin`
    /// to `navigable` will make: a new id and navigation API ID, and a new
    /// navigation API key - or, for a "replace" by a same-origin document,
    /// the key of the entry it replaces (step 9.3). An id reserved is never
    /// handed out again, committed or not.
    pub fn prepareDocument(self: *JointHistory, navigable: u64, origin: []const u8, handling: HistoryHandling) Prepared {
        const id = self.next_id;
        self.next_id += 1;
        const kept: ?[36]u8 = if (handling == .replace) blk: {
            const current = self.currentEntry(navigable) orelse break :blk null;
            break :blk if (std.mem.eql(u8, current.origin, origin)) current.api_key else null;
        } else null;
        return .{ .id = id, .api_key = kept orelse self.randomUuid(), .api_id = self.randomUuid() };
    }

    /// `commitDocument` with the entry `prepareDocument` reserved.
    pub fn commitPreparedDocument(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, origin: []const u8, handling: HistoryHandling, prepared: Prepared) !void {
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.commit(navigable, url, doc_state, document, .null, .undefined, origin, handling, true, prepared);
    }

    /// A copy of `entry` as it is now, owned by this history's allocator.
    pub fn snapshot(self: *JointHistory, entry: *const Entry) !EntrySnapshot {
        const url = try self.allocator.dupe(u8, entry.url);
        errdefer self.allocator.free(url);
        const origin = try self.allocator.dupe(u8, entry.origin);
        return .{ .id = entry.id, .navigable = entry.navigable, .url = url, .api_key = entry.api_key, .api_id = entry.api_id, .origin = origin };
    }

    /// The entry a commit with `prepared` will make for `navigable` - its
    /// URL `url` and origin `origin` - as a snapshot owned by this history's
    /// allocator: the pageswap event's targetEntry, named before it exists.
    pub fn preparedSnapshot(self: *JointHistory, navigable: u64, url: []const u8, origin: []const u8, prepared: Prepared) !EntrySnapshot {
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        const owned_origin = try self.allocator.dupe(u8, origin);
        return .{ .id = prepared.id, .navigable = navigable, .url = owned_url, .api_key = prepared.api_key, .api_id = prepared.api_id, .origin = owned_origin };
    }

    /// Record the activation of the document a cross-document navigation
    /// of type `navigation_type` committed to the entry `entry_id`: its
    /// previousEntryForActivation (taken, owned by this history's
    /// allocator) and the entry as it is now.
    pub fn recordActivation(self: *JointHistory, entry_id: u64, navigation_type: NavigationType, previous: ?EntrySnapshot) !void {
        var owned_previous = previous;
        errdefer if (owned_previous) |*p| p.deinit(self.allocator);
        const entry = self.entryById(entry_id) orelse return error.NoSuchEntry;
        const now = try self.snapshot(entry);
        const activation: Activation = .{
            .navigation_type = navigation_type,
            .previous = owned_previous,
            .entry = now,
        };
        owned_previous = null;
        try self.setActivation(entry_id, activation);
    }

    /// Record `activation` (taken, its snapshots owned by this history's
    /// allocator) for the document of the entry `entry_id`'s document state:
    /// it replaces any other entry of that state's - one document state has
    /// one document at a time.
    pub fn setActivation(self: *JointHistory, entry_id: u64, activation: Activation) !void {
        var owned = activation;
        errdefer owned.deinit(self.allocator);
        const target = self.entryById(entry_id) orelse return error.NoSuchEntry;
        const state = target.document_state;
        for (self.entries.items) |*entry| {
            if (entry.document_state == state) entry.dropActivation(self.allocator);
        }
        const kept = try self.allocator.create(Activation);
        kept.* = owned;
        target.activation = kept;
    }

    /// The activation recorded for `document_state`'s document, if any.
    pub fn activationOf(self: *const JointHistory, document_state: u64) ?*const Activation {
        for (self.entries.items) |entry| {
            if (entry.document_state != document_state) continue;
            if (entry.activation) |a| return a;
        }
        return null;
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
        // And so is its history policy container.
        var history_container: ?PolicyContainer = if (current.history_policy_container) |*c| try c.clone(self.allocator) else null;
        errdefer if (history_container) |*c| c.deinit();
        const new_api_state = api_state orelse try current.api_state.clone(self.allocator);
        try self.commit(navigable, url, current.document_state, current.document, state, new_api_state, origin, handling, true, null);
        const committed = self.currentEntry(navigable) orelse unreachable;
        if (committed.resource) |old| self.allocator.free(old);
        committed.resource = resource;
        committed.dropHistoryPolicyContainer();
        committed.history_policy_container = history_container;
        history_container = null;
    }

    /// HTML "populate a session history entry" step 7.2.3: `document_state`'s
    /// history policy container becomes a clone of `container` - on every
    /// entry of the state.
    pub fn setHistoryPolicyContainer(self: *JointHistory, document_state: u64, container: *const PolicyContainer) !void {
        for (self.entries.items) |*entry| {
            if (entry.document_state != document_state) continue;
            const copy = try container.clone(self.allocator);
            entry.dropHistoryPolicyContainer();
            entry.history_policy_container = copy;
        }
    }

    /// The history policy container of the document state of the entry whose
    /// id is `entry_id`, if it has one. BORROWED: the entry keeps it.
    pub fn historyPolicyContainer(self: *JointHistory, entry_id: u64) ?*const PolicyContainer {
        const entry = self.entryById(entry_id) orelse return null;
        if (entry.history_policy_container) |*container| return container;
        return null;
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
        prepared: ?Prepared,
    ) !void {
        switch (handling) {
            .push => {
                self.clearForward();
                const step = self.current_step + 1;
                try self.append(navigable, step, url, doc_state, document, state, api_state, origin, null, prepared);
                self.current_step = step;
            },
            .replace => {
                const current = self.currentEntry(navigable) orelse {
                    try self.append(navigable, self.current_step, url, doc_state, document, state, api_state, origin, null, prepared);
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
                if (prepared) |p| {
                    current.api_key = p.api_key;
                    current.api_id = p.api_id;
                    current.id = p.id;
                } else {
                    if (!keep_key_on_replace) current.api_key = self.randomUuid();
                    current.api_id = self.randomUuid();
                    current.id = self.next_id;
                    self.next_id += 1;
                }
                // A new document state has a resource, a history policy
                // container and an activation of its own, if any.
                if (current.document_state != doc_state) {
                    if (current.resource) |r| self.allocator.free(r);
                    current.resource = null;
                    current.dropHistoryPolicyContainer();
                    current.dropActivation(self.allocator);
                }
                current.document_state = doc_state;
                current.document = document;
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

    /// The used step nearest the current one at which `entry` is its
    /// navigable's entry - the step a navigation API traversal to it applies.
    /// HTML's "perform a navigation API traversal" applies the entry's own
    /// step (the first at which it was current); Blink and Gecko go to the
    /// nearest joint entry that shows it, so a frame's back() after its
    /// parent pushed leaves the parent where it is (WPT
    /// navigation-api/navigation-methods/disambigaute-*.html). Ties go back.
    pub fn nearestStepOf(self: *JointHistory, entry: *const Entry) u32 {
        var steps: std.ArrayListUnmanaged(u32) = .empty;
        defer steps.deinit(self.allocator);
        self.usedSteps(self.allocator, &steps) catch return entry.step;
        var best: ?u32 = null;
        var best_distance: u32 = std.math.maxInt(u32);
        for (steps.items) |step| {
            const at = self.entryAt(entry.navigable, step) orelse continue;
            if (at != entry) continue;
            const distance = if (step > self.current_step) step - self.current_step else self.current_step - step;
            if (distance < best_distance) {
                best = step;
                best_distance = distance;
            }
        }
        return best orelse entry.step;
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
    /// repopulated by a traversal. `document` is still alive here (the
    /// callers forget it once it has unloaded, before it is destroyed), so
    /// its referrer policy is recorded on those entries as it is now.
    pub fn forgetDocument(self: *JointHistory, document: *anyopaque) void {
        const container = @import("dom").policy_containers.of(@ptrCast(@alignCast(document)));
        self.forgetDocumentWithPolicy(document, if (container) |c| c.referrer_policy else null);
    }

    /// `forgetDocument`, given the leaving document's referrer policy (null
    /// when it has no policy container).
    ///
    /// HTML's NavigationHistoryEntry url getter step 4 censors an entry of
    /// another document whose document state's REQUEST referrer policy is
    /// "no-referrer" or "origin". The browsers key it on the document's own
    /// referrer policy instead, as it stands when the document leaves - the
    /// one its response's Referrer-Policy header or a meta referrer element
    /// gave it, changed after load or not (golden rule 2). Chromium keeps
    /// protect_url_in_navigation_api per FrameNavigationEntry, set from the
    /// document's policy container at commit and updated by
    /// NavigationControllerImpl::DidChangeReferrerPolicy until the document
    /// leaves (content/browser/renderer_host/navigation_controller_impl.cc,
    /// ShouldProtectUrlInNavigationApi: kNever or kOrigin); WebKit records
    /// the leaving document's referrerPolicy when the next document clones
    /// its entries (NavigationHistoryEntry::DocumentState::fromContext). So
    /// recording the policy at leave time gives Chromium's flag. wpt.fyi
    /// (cc74d2669f): navigation-history-entry/no-referrer-url-censored and
    /// no-referrer-from-meta-url-censored pass in Chrome 154, Firefox 157
    /// and Safari 27; no-referrer-dynamic-url-censored, the meta added after
    /// load that separates the two readings, passes in Chrome and Safari
    /// only (a 2-of-3 majority).
    pub fn forgetDocumentWithPolicy(self: *JointHistory, document: *anyopaque, referrer_policy: ?ReferrerPolicy) void {
        const protect = if (referrer_policy) |policy| protectsUrl(policy) else false;
        for (self.entries.items) |*entry| {
            if (entry.document != document) continue;
            entry.document = null;
            entry.protect_url = protect;
        }
    }

    /// The entry whose id is `id`, if it is still in the history.
    pub fn entryById(self: *JointHistory, id: u64) ?*Entry {
        for (self.entries.items) |*entry| {
            if (entry.id == id) return entry;
        }
        return null;
    }

    /// An entry of `navigable` whose navigation API key is `key`, if the
    /// history still has one.
    pub fn entryByKey(self: *JointHistory, navigable: u64, key: *const [36]u8) ?*Entry {
        for (self.entries.items) |*entry| {
            if (entry.navigable == navigable and std.mem.eql(u8, &entry.api_key, key)) return entry;
        }
        return null;
    }
};
