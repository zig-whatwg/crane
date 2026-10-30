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
//! What a document's script reads of the session history - its History
//! object's length and index, and its navigation API's entry list and
//! current entry - is not read from the entries live: each navigable has a
//! `View`, written by `updateViews`, and History, Navigation and
//! NavigationHistoryEntry read only that. HTML keeps these per document and
//! writes them only at given moments ("update document for history step
//! application" steps 3-4 and 6, "apply the history step" step 18, the URL
//! and history update steps, "initialize/update the navigation API
//! entries"), so a leaving document keeps seeing the history it last saw
//! while the traversable's history moves on. One view per navigable is one
//! per document here: only a navigable's active document - the fully active
//! one - reads its history (the History members throw, and the navigation
//! API has entries and events disabled, for any other). Today every change
//! of the history rewrites every view (`beginChange`/`endChange`), so a view
//! is always what a live read gives; the spec's moments replace that
//! writer one by one (docs/lessons/architecture-the-order-of-a-history-
//! update-is-observable-only-through-each-documents-view.md).
//!
//! Synchronous navigations (lane nav2 E): "the URL and history update steps"
//! and "navigate to a fragment" make their new entry the navigable's ACTIVE
//! session history entry at once (`navigateSameDocument`), but the entry is
//! LISTED - given a step, in the joint history's steps and every traversal
//! endpoint - only by "finalize a same-document navigation" on the traversal
//! queue (`finalizeSameDocument`). Until then it is a PENDING entry: in
//! `entries`, flagged, with no meaningful step; `entryById`, `activeEntry`,
//! `currentEntry` and the state-wide setters see it; `entryAt`, `usedSteps`,
//! `stepByDelta` and `lengthAndIndex` do not. A navigable's pending entries
//! form a FIFO chain (see `finalizeSameDocument`). The views read the
//! history as the pending entries will make it once listed (`writeViews`),
//! so what script reads moves at once, as before; only the traversal
//! endpoints wait.
//!
//! Engine-free: documents are opaque, and a state is bytes (the
//! StructuredSerializeForStorage wire format, or a primitive).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A policy container, as a document state's history policy container keeps
/// one (Fetch's: CSP list, referrer policy).
pub const PolicyContainer = @import("fetch").internal.PolicyContainer;
pub const NotRestoredReasons = @import("not_restored_reasons.zig").NotRestoredReasons;
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
    /// The document state's not restored reasons (HTML "document state"
    /// item): why its document was not kept in the back/forward cache, built
    /// when it was unloaded as a top-level traversable's active document
    /// (`setNotRestoredReasons`). The document a back/forward traversal
    /// makes for the state reports them. Shared by the entries of the
    /// document state, each holding its own copy. Owned.
    not_restored_reasons: ?NotRestoredReasons = null,
    /// Its document came from a GET of an HTTP(S) URL answered 200: what the
    /// back/forward cache keeps (Blink's eligibility, BackForwardCacheImpl
    /// CanStoreDocument: kHTTPStatusNotOK, kSchemeNotHTTPOrHTTPS,
    /// kHTTPMethodNotGET). Recorded at the commit; shared by the entries of
    /// the document state.
    keepable_response: bool = false,
    /// A synchronous navigation made it its navigable's active entry and its
    /// "finalize a same-document navigation" has not listed it yet: it has
    /// no step in the joint history (`step` means nothing until then; see
    /// the file comment).
    pending: bool = false,
    /// A pending entry's history handling: a push - which clears the forward
    /// history when it is listed - or a replace of the entry whose id is
    /// `pending_replaces`.
    pending_push: bool = false,
    pending_replaces: u64 = 0,

    fn deinit(self: *Entry, allocator: Allocator) void {
        allocator.free(self.url);
        self.state.deinit(allocator);
        self.api_state.deinit(allocator);
        allocator.free(self.origin);
        if (self.resource) |r| allocator.free(r);
        self.dropHistoryPolicyContainer();
        self.dropActivation(allocator);
        self.dropNotRestoredReasons(allocator);
    }

    fn dropNotRestoredReasons(self: *Entry, allocator: Allocator) void {
        if (self.not_restored_reasons) |*reasons| reasons.deinit(allocator);
        self.not_restored_reasons = null;
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

/// What `listCrossDocument` did: the step "apply the push/replace history
/// step" applies (targetStep), the new entry's id, and whether a push
/// cleared forward entries.
pub const ListedCrossDocument = struct {
    step: u32,
    entry: u64,
    removed: bool,
};

/// What `navigateSameDocument` made: its new entry's id - HTML's newEntry or
/// historyEntry - and, for a replace, the id of the entry it replaces
/// (entryToReplace).
pub const SameDocumentNavigation = struct {
    entry: u64,
    replaces: ?u64,
};

/// What `finalizeSameDocument` did: the step the entry was listed at - the
/// targetStep its push/replace history step applied - and whether a push
/// cleared forward entries from the history.
pub const Finalized = struct {
    step: u32,
    removed: bool,
};

/// What an entry records of a document when it is first given one: its URL
/// and origin, serialized, owned by the allocator the caller was given.
pub const DocumentInfo = struct {
    url: []u8,
    origin: []u8,
};

/// "Get the history object length and index": the History length, and the
/// current step's index among the used steps.
pub const LengthAndIndex = struct { length: u32, index: u32 };

/// What a navigable's active document reads of the session history: its
/// History object's length and index, and its navigation API's entry list
/// (entry ids, in order) with the current entry's index there, and its
/// current entry. Written by `JointHistory.updateViews`; see the file
/// comment.
pub const View = struct {
    /// The History object's length and index.
    length: u32 = 1,
    index: u32 = 0,
    /// The navigation API's entry list, by session history entry id.
    api_ids: std.ArrayListUnmanaged(u64) = .empty,
    /// Its current entry index in `api_ids` (0 when the list is empty).
    api_index: usize = 0,
    /// The navigation API's current entry - `api_ids[api_index]`, except
    /// that a navigable whose kept active entry is not one of its own has an
    /// empty list and that entry as its current one (`activeEntry`).
    api_current: ?u64 = null,
    /// The `updateViews` pass that last wrote it.
    epoch: u64 = 0,

    fn deinit(self: *View, allocator: Allocator) void {
        self.api_ids.deinit(allocator);
    }
};

pub const JointHistory = struct {
    allocator: Allocator,
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    /// Each entry's index in `entries`, by id, and each navigable's entries'
    /// indexes in list order, with how many entries are pending (lane nav2
    /// H): every lookup by id or navigable reads these, not a scan of the
    /// whole list - a fragment navigation makes several, and the list holds
    /// every navigable's entries. An append adds to them; a change that
    /// removes or moves entries rebuilds them (`reindex`) in one pass. False
    /// after a rebuild ran out of memory: the lookups scan the list again
    /// until a later rebuild succeeds.
    positions: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    lists: std.AutoArrayHashMapUnmanaged(u64, std.ArrayListUnmanaged(u32)) = .empty,
    pending_count: u32 = 0,
    pending_push_count: u32 = 0,
    indexes_valid: bool = true,
    /// "Current session history step".
    current_step: u32 = 0,
    next_id: u64 = 1,
    next_document_state: u64 = 1,
    /// For the navigation API's keys and IDs.
    prng: std.Random.DefaultPrng,
    /// The navigables whose active session history entry is not the one at
    /// the current step (`keepActiveEntry`): a traversal moved the step, and
    /// their target entry's document could not be populated.
    update_only: std.AutoHashMapUnmanaged(u64, UpdateOnly) = .empty,

    /// Each navigable's `View`, by navigable id: what its active document
    /// reads.
    /// (An array hash map: it removes without tombstones.)
    views: std.AutoArrayHashMapUnmanaged(u64, View) = .empty,
    /// False after an `updateViews` ran out of memory: until one succeeds,
    /// the views are read from the entries instead.
    views_valid: bool = true,
    views_epoch: u64 = 0,
    /// How many changes of the history are in progress (`beginChange`): the
    /// views are rewritten when the outermost one ends.
    change_depth: u32 = 0,
    /// The navigables whose views are held (`holdView`): a traversal is
    /// changing their entries, and their documents keep reading what they
    /// read before until their target document is made active.
    held: std.ArrayListUnmanaged(u64) = .empty,
    /// The "apply the history step" that is running, from its step 8 to its
    /// step 20 (`beginApply`, `endApply`): null when none is.
    apply: ?Apply = null,
    /// `writeViews`' buffers, kept between calls (lane nav2 H).
    view_scratch: ViewScratch = .{},

    const ViewScratch = struct {
        projected: std.ArrayListUnmanaged(?u32) = .empty,
        pending: std.ArrayListUnmanaged(u32) = .empty,
        steps: std.ArrayListUnmanaged(u32) = .empty,
        order: std.ArrayListUnmanaged(u32) = .empty,

        fn deinit(self: *ViewScratch, allocator: Allocator) void {
            self.projected.deinit(allocator);
            self.pending.deinit(allocator);
            self.steps.deinit(allocator);
            self.order.deinit(allocator);
        }
    };

    /// HTML "apply the history step" as the session history sees it while
    /// one runs (lane nav2 C2). The traversable's current session history
    /// step stays where it was until step 20; each changing navigable's
    /// current session history entry is its target entry from step 8.2; and
    /// what the documents read is computed given targetStep (steps 14.7,
    /// 14.9 and 17), so a view written meanwhile - a changing navigable's at
    /// its "update document for history step application", a non-changing
    /// one's at step 18, a navigable made meanwhile - reads `target`.
    pub const Apply = struct {
        /// The queue item running it (traversal_queue Item.token).
        token: u64,
        /// Step 2's targetStep.
        target: u32,
        /// Step 8.2: "set navigable's current session history entry to
        /// targetEntry" - entry ids, by navigable id.
        current: std.AutoArrayHashMapUnmanaged(u64, u64) = .empty,

        fn deinit(self: *Apply, allocator: Allocator) void {
            self.current.deinit(allocator);
        }
    };

    /// A navigable's kept active entry, and the step it was kept at.
    const UpdateOnly = struct { entry: u64, step: u32 };

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
        self.positions.deinit(self.allocator);
        for (self.lists.values()) |*list| list.deinit(self.allocator);
        self.lists.deinit(self.allocator);
        self.update_only.deinit(self.allocator);
        for (self.views.values()) |*view| view.deinit(self.allocator);
        self.views.deinit(self.allocator);
        self.held.deinit(self.allocator);
        if (self.apply) |*apply| apply.deinit(self.allocator);
        self.view_scratch.deinit(self.allocator);
    }

    /// A change of the entries, the current step or a kept active entry
    /// begins: every method that makes one brackets it with this and
    /// `endChange`, on every path out.
    fn beginChange(self: *JointHistory) void {
        self.change_depth += 1;
    }

    /// The change `beginChange` began ends: when it is the outermost one,
    /// every navigable's view is rewritten.
    fn endChange(self: *JointHistory) void {
        self.change_depth -= 1;
        if (self.change_depth == 0) self.updateViews();
    }

    // =========================================================================
    // The indexes (lane nav2 H)
    // =========================================================================

    /// Room in the indexes for one more entry of `navigable`, made before the
    /// entry is appended, so that `indexAppended` cannot fail.
    fn reserveIndex(self: *JointHistory, navigable: u64) !void {
        try self.positions.ensureUnusedCapacity(self.allocator, 1);
        const slot = try self.lists.getOrPut(self.allocator, navigable);
        if (!slot.found_existing) slot.value_ptr.* = .empty;
        try slot.value_ptr.ensureUnusedCapacity(self.allocator, 1);
    }

    /// The entry at `index` - the last - was appended, with room reserved.
    fn indexAppended(self: *JointHistory, index: usize) void {
        if (!self.indexes_valid) return self.reindex();
        const entry = &self.entries.items[index];
        if (entry.pending) {
            self.pending_count += 1;
            if (entry.pending_push) self.pending_push_count += 1;
        }
        self.positions.putAssumeCapacityNoClobber(entry.id, @intCast(index));
        self.lists.getPtr(entry.navigable).?.appendAssumeCapacity(@intCast(index));
    }

    /// Rebuild the indexes from the list, in one pass: after a change that
    /// removed or moved entries, or gave one a new id. The capacity a rebuild
    /// needs is the capacity the indexes have unless the list grew, so it
    /// allocates only to make an invalid index valid again.
    fn reindex(self: *JointHistory) void {
        self.pending_count = 0;
        self.pending_push_count = 0;
        for (self.entries.items) |entry| {
            if (!entry.pending) continue;
            self.pending_count += 1;
            if (entry.pending_push) self.pending_push_count += 1;
        }
        self.positions.clearRetainingCapacity();
        for (self.lists.values()) |*list| list.clearRetainingCapacity();
        self.indexes_valid = false;
        for (self.entries.items, 0..) |entry, index| {
            self.positions.put(self.allocator, entry.id, @intCast(index)) catch return;
            const slot = self.lists.getOrPut(self.allocator, entry.navigable) catch return;
            if (!slot.found_existing) slot.value_ptr.* = .empty;
            slot.value_ptr.append(self.allocator, @intCast(index)) catch return;
        }
        // The lists of navigables with no entry left go.
        var i: usize = 0;
        while (i < self.lists.count()) {
            if (self.lists.values()[i].items.len > 0) {
                i += 1;
                continue;
            }
            self.lists.values()[i].deinit(self.allocator);
            self.lists.swapRemoveAt(i);
        }
        self.indexes_valid = true;
    }

    /// The entries of one navigable, as indexes into `entries` in list order:
    /// its index list, or - when the indexes are invalid - a scan.
    const NavigableEntries = struct {
        entries: []const Entry,
        navigable: u64,
        list: ?[]const u32,
        at: usize = 0,

        fn next(self: *NavigableEntries) ?usize {
            if (self.list) |list| {
                if (self.at >= list.len) return null;
                self.at += 1;
                return list[self.at - 1];
            }
            while (self.at < self.entries.len) {
                self.at += 1;
                if (self.entries[self.at - 1].navigable == self.navigable) return self.at - 1;
            }
            return null;
        }
    };

    fn entriesOf(self: *const JointHistory, navigable: u64) NavigableEntries {
        const list: ?[]const u32 = if (!self.indexes_valid) null else if (self.lists.getPtr(navigable)) |l| l.items else &.{};
        return .{ .entries = self.entries.items, .navigable = navigable, .list = list };
    }

    /// Remove every entry `drop` selects, keeping the others in order, in one
    /// pass, and rebuild the indexes: whether any went.
    fn removeWhere(self: *JointHistory, context: anytype, comptime drop: fn (@TypeOf(context), *const Entry) bool) bool {
        var kept: usize = 0;
        const items = self.entries.items;
        for (items, 0..) |*entry, i| {
            if (drop(context, entry)) {
                entry.deinit(self.allocator);
                continue;
            }
            if (kept != i) items[kept] = items[i];
            kept += 1;
        }
        if (kept == items.len) return false;
        self.entries.shrinkRetainingCapacity(kept);
        self.reindex();
        return true;
    }

    /// HTML "apply the history step" step 20: the traversable's current
    /// session history step becomes `step`.
    pub fn setCurrentStep(self: *JointHistory, step: u32) void {
        self.beginChange();
        defer self.endChange();
        self.current_step = step;
    }

    /// The step what the documents read is computed at: the running
    /// apply's targetStep, else the current session history step (see
    /// `Apply`).
    pub fn viewStep(self: *const JointHistory) u32 {
        if (self.apply) |apply| return apply.target;
        return self.current_step;
    }

    /// "Apply the history step" step 8 begins for the queue item `token`,
    /// whose targetStep is `target`. One runs at a time: the queue runs one
    /// item at a time, and a commit made inside one settles it first
    /// (`settleApply`).
    pub fn beginApply(self: *JointHistory, token: u64, target: u32) void {
        if (self.apply) |*running| running.deinit(self.allocator);
        self.apply = .{ .token = token, .target = target };
    }

    /// Whether the apply of the queue item `token` is running (begun, not
    /// ended or settled).
    pub fn isApplying(self: *const JointHistory, token: u64) bool {
        const apply = self.apply orelse return false;
        return apply.token == token;
    }

    /// Step 8.2 for `navigable`: its current session history entry is the
    /// entry `entry_id` until step 20. Out of memory, it is read from the
    /// current step meanwhile.
    pub fn setCurrentEntry(self: *JointHistory, navigable: u64, entry_id: u64) void {
        const apply = if (self.apply) |*a| a else return;
        apply.current.put(self.allocator, navigable, entry_id) catch {};
    }

    /// Step 20 for the apply of the queue item `token`: the current session
    /// history step becomes its targetStep, and every navigable's current
    /// entry is the one at that step again. Nothing when that apply is not
    /// the running one (another item's, or settled).
    pub fn endApply(self: *JointHistory, token: u64) void {
        if (!self.isApplying(token)) return;
        self.beginChange();
        defer self.endChange();
        var apply = self.apply.?;
        self.apply = null;
        self.current_step = apply.target;
        apply.deinit(self.allocator);
    }

    /// Stated deviation (integrator, 2026-10-28; since lane nav2 E and F1
    /// only for the commits that are still made inline - an embedder's own
    /// load, top_level_traversables.recordLoad; a javascript: URL's result;
    /// a commit that found no queue to append its finalize to): HTML queues
    /// "finalize a cross-document navigation" on the traversal queue, so it
    /// never runs inside an apply (`listCrossDocument` is the queued one). A
    /// commit made inline while an apply runs settles it first - the step moves to its target (step 20
    /// early, and the apply's own does nothing) and the views of the
    /// navigables it does not change are released (their step 18 early) -
    /// so the commit lands after the apply, as it would from the queue, and
    /// the changing navigables' documents keep reading what they read until
    /// their targets are active (lane nav2 C1's behaviour for this case;
    /// tests/html/navigation/nav2_apply_history_step_test.zig pins it).
    fn settleApply(self: *JointHistory) void {
        var apply = self.apply orelse return;
        self.apply = null;
        self.current_step = apply.target;
        var i: usize = 0;
        while (i < self.held.items.len) {
            if (apply.current.contains(self.held.items[i])) {
                i += 1;
            } else _ = self.held.swapRemove(i);
        }
        apply.deinit(self.allocator);
    }

    /// HTML "getting the used step" for `step`: the greatest used step at
    /// or before it, or null when there is none.
    pub fn usedStepAtOrBefore(self: *const JointHistory, step: u32) ?u32 {
        var best: ?u32 = null;
        for (self.entries.items) |entry| {
            if (entry.pending) continue;
            if (entry.step <= step and (best == null or entry.step > best.?)) best = entry.step;
        }
        return best;
    }

    /// `navigable`'s entry at `step`: "get the target history entry" - the
    /// one with the greatest step less than or equal to `step` - or null when
    /// it has none there yet.
    pub fn entryAt(self: *JointHistory, navigable: u64, step: u32) ?*Entry {
        var best: ?*Entry = null;
        var it = self.entriesOf(navigable);
        while (it.next()) |index| {
            const entry = &self.entries.items[index];
            if (entry.pending or entry.step > step) continue;
            if (best == null or entry.step >= best.?.step) best = entry;
        }
        return best;
    }

    /// `navigable`'s current session history entry, as the traversal
    /// endpoints read it: its target entry while an apply that changes it
    /// runs (step 8.2), else its listed entry at the current step. Pending
    /// entries are not in it.
    pub fn listedCurrentEntry(self: *JointHistory, navigable: u64) ?*Entry {
        if (self.apply) |apply| {
            if (apply.current.get(navigable)) |id| {
                if (self.entryById(id)) |entry| return entry;
            }
        }
        return self.entryAt(navigable, self.current_step);
    }

    /// `navigable`'s entry as its document's own steps read it - History's
    /// state and scroll restoration, the navigation API's current entry, the
    /// entry a reload or a navigation replaces: its latest pending entry,
    /// which a synchronous navigation made active, else its listed current
    /// entry (`listedCurrentEntry`).
    pub fn currentEntry(self: *JointHistory, navigable: u64) ?*Entry {
        return self.lastPending(navigable) orelse self.listedCurrentEntry(navigable);
    }

    /// `navigable`'s active session history entry: its latest pending entry
    /// (a synchronous navigation made it active); else its current one,
    /// unless a traversal to this step could not populate its target entry's
    /// document (`keepActiveEntry`) - then the entry it still displays. The
    /// navigation API's current entry is this one.
    pub fn activeEntry(self: *JointHistory, navigable: u64) ?*Entry {
        if (self.lastPending(navigable)) |entry| return entry;
        if (self.update_only.get(navigable)) |kept| {
            if (kept.step == self.viewStep()) {
                if (self.entryById(kept.entry)) |entry| return entry;
            }
        }
        return self.listedCurrentEntry(navigable);
    }

    /// The entry `navigable`'s document shows as it last had its view written
    /// - "displayedEntry" of "apply the history step" 12.1, which a
    /// synchronous navigation that jumped a waiting traversal moved past the
    /// entry that traversal's step 8.2 made current: the view's current
    /// entry; with no view, the active entry.
    pub fn displayedEntry(self: *JointHistory, navigable: u64) ?*Entry {
        if (self.validView(navigable)) |view| {
            if (view.api_current) |id| {
                if (self.entryById(id)) |entry| return entry;
            }
        }
        return self.activeEntry(navigable);
    }

    /// HTML "apply the history step" step 12.8, afterDocumentPopulated
    /// step 1: "If targetEntry's document is null, then set
    /// changingNavigableContinuation's update-only to true" - a traversal's
    /// population of `navigable`'s target entry made no document (a 204, a
    /// 205, a download), so "activate history entry" never runs for it
    /// (step 14.12.2), and its active session history entry stays
    /// `displayed`, the entry it was on, though the traversable's current
    /// step moved (step 20). Kept for this step, until a document is
    /// committed to the navigable or it goes. Kept at the step the apply
    /// running goes to (`viewStep`): the population ends before its step 20.
    pub fn keepActiveEntry(self: *JointHistory, navigable: u64, displayed: u64) !void {
        self.beginChange();
        defer self.endChange();
        try self.update_only.put(self.allocator, navigable, .{ .entry = displayed, .step = self.viewStep() });
    }

    /// Give `document` to every entry of `document_state` - a document the
    /// engine committed to the history before its parser ran, whose
    /// pushState and fragment entries made meanwhile share its state.
    pub fn setDocumentOfState(self: *JointHistory, document_state: u64, document: ?*anyopaque) void {
        self.beginChange();
        defer self.endChange();
        for (self.entries.items) |*entry| {
            if (entry.document_state != document_state) continue;
            entry.document = document;
            // A document made for the state: its navigable displays it.
            if (document != null) _ = self.update_only.remove(entry.navigable);
        }
    }

    /// The size of `navigable`'s session history entries - its own, not the
    /// steps its descendants add to the joint history - as script sees them:
    /// with its pending entries, as browsers count an entry pushed in the
    /// same task (the window's "script-closable").
    pub fn entryCount(self: *const JointHistory, navigable: u64) usize {
        var count: usize = 0;
        var it = self.entriesOf(navigable);
        if (it.list) |list| return list.len;
        while (it.next()) |_| count += 1;
        return count;
    }

    pub fn hasNavigable(self: *const JointHistory, navigable: u64) bool {
        var it = self.entriesOf(navigable);
        while (it.next()) |index| {
            if (!self.entries.items[index].pending) return true;
        }
        return false;
    }

    /// HTML "initialize the navigable" (and, for a child, "create a new child
    /// navigable" step 12): `navigable`'s first entry, at the current step -
    /// it adds no step. Nothing when it has one already.
    pub fn addInitialEntry(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, origin: []const u8) !void {
        if (self.hasNavigable(navigable)) return;
        self.beginChange();
        defer self.endChange();
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.append(navigable, self.viewStep(), url, doc_state, document, .null, .undefined, origin, null, null);
    }

    /// HTML "create a new child navigable" step 12 for `navigable`, a child
    /// of `parent`: its first entry, at the step of the first of the
    /// parent's entries that share the parent's current document state -
    /// the step the parent's document began at, not the current one, so a
    /// later truncation of the parent's forward entries leaves it. At the
    /// current step when the parent has no entry. Nothing when it has one.
    pub fn addChildInitialEntry(self: *JointHistory, navigable: u64, parent: u64, url: []const u8, document: ?*anyopaque, origin: []const u8) !void {
        if (self.hasNavigable(navigable)) return;
        self.beginChange();
        defer self.endChange();
        var step = self.viewStep();
        if (self.listedCurrentEntry(parent)) |parent_entry| {
            step = parent_entry.step;
            var it = self.entriesOf(parent);
            while (it.next()) |index| {
                const entry = &self.entries.items[index];
                if (entry.pending) continue;
                if (entry.document_state == parent_entry.document_state and entry.step < step) step = entry.step;
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
        try self.reserveIndex(navigable);
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
        self.indexAppended(self.entries.items.len - 1);
        if (prepared == null) self.next_id += 1;
    }

    /// "Clear the forward session history": every entry past the current
    /// step goes. A running apply is settled first (`settleApply`).
    pub fn clearForward(self: *JointHistory) void {
        self.beginChange();
        defer self.endChange();
        self.settleApply();
        _ = self.clearForwardListed();
    }

    /// "Clear the forward session history" of the listed entries - pending
    /// ones have no step - as it runs on the traversal queue, with no apply
    /// settled: whether any entry went.
    fn clearForwardListed(self: *JointHistory) bool {
        // One compaction of the list (lane nav2 H), not a removal per entry.
        return self.removeWhere(self.current_step, struct {
            fn forward(current: u32, entry: *const Entry) bool {
                return !entry.pending and entry.step > current;
            }
        }.forward);
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

    /// `commitDocument` with the entry `prepareDocument` reserved. A running
    /// apply is settled first (`settleApply`).
    pub fn commitPreparedDocument(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, origin: []const u8, handling: HistoryHandling, prepared: Prepared) !void {
        self.beginChange();
        defer self.endChange();
        self.settleApply();
        // Stated, with settleApply, for the inline commits (see there): the
        // synchronous navigations' finalize steps queued before this commit
        // would run before it on the queue - their pending entries are listed first, in order (their
        // queued finalize steps then find nothing to do).
        self.flushPending();
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        try self.commit(navigable, url, doc_state, document, .null, .undefined, origin, handling, true, prepared);
    }

    /// HTML "finalize a cross-document navigation" steps 5-9 as they run on
    /// the traversal queue (lane nav2 F1, apply_history_step's .push_replace
    /// apply): `navigable`'s new entry for a document of `origin` at `url`.
    /// "push" clears the forward session history - its listed entries past
    /// the current step; nothing is settled, the caller is the queue's
    /// running item - and lists the entry at the current step + 1;
    /// "replace" puts it in place of the navigable's current entry, at its
    /// step, keeping its navigation API key when the two are same origin,
    /// and applies the current step (step 9's targetStep).
    /// The current step does not move: "apply the push/replace history step"
    /// sets it to the returned step at its step 20 (`endApply`). Unlike
    /// `commitPreparedDocument`, no pending entry is listed: the synchronous
    /// navigations' finalize steps queued before this one have run, and
    /// those queued after it run after it.
    pub fn listCrossDocument(self: *JointHistory, navigable: u64, url: []const u8, document: ?*anyopaque, origin: []const u8, handling: HistoryHandling, prepared: ?Prepared) !ListedCrossDocument {
        self.beginChange();
        defer self.endChange();
        // The entry's id and keys: those pageswap named, or - with none
        // reserved - made now (a replace keeps a same-origin key).
        const reserved = prepared orelse self.prepareDocument(navigable, origin, handling);
        _ = self.update_only.remove(navigable);
        const doc_state = self.next_document_state;
        self.next_document_state += 1;
        switch (handling) {
            .push => {
                const removed = self.clearForwardListed();
                const step = self.current_step + 1;
                try self.append(navigable, step, url, doc_state, document, .null, .undefined, origin, null, reserved);
                return .{ .step = step, .entry = reserved.id, .removed = removed };
            },
            .replace => {
                // Step 9 (replace) 4: "Set targetStep to traversable's
                // current session history step" - not the replaced entry's
                // step (a frame's first entry sits at the step its parent's
                // document began at).
                try self.commit(navigable, url, doc_state, document, .null, .undefined, origin, .replace, true, reserved);
                return .{ .step = self.current_step, .entry = reserved.id, .removed = false };
            },
        }
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

    /// `navigateSameDocument` with its finalize at once
    /// (`finalizeSameDocument`): the entry is listed now - pushed one step on
    /// and made current, or in place of the current one. For a traversable
    /// with no traversal queue, and for native tests.
    pub fn commitSameDocument(self: *JointHistory, navigable: u64, url: []const u8, state: SerializedState, handling: HistoryHandling, api_state: ?SerializedState) !void {
        const nav = try self.navigateSameDocument(navigable, url, state, handling, api_state);
        _ = self.finalizeSameDocument(navigable, nav.entry, nav.replaces);
    }

    /// HTML "URL and history update steps" 2-7 and 10-11, and "navigate to a
    /// fragment" 6-14: a new entry on the navigable's active entry's document
    /// - sharing its document state, origin, resource, history policy
    /// container, not restored reasons and scroll restoration mode - with
    /// classic history API `state`, made the navigable's active entry now,
    /// and PENDING until `finalizeSameDocument` lists it. A replace keeps the
    /// replaced entry's navigation API key (step 6 / step 8). Its navigation
    /// API state is `api_state`, or, when null, the active entry's (a
    /// fragment navigation's). `state` and `api_state` are taken, on every
    /// path.
    ///
    /// The views read the new entry at once (`writeViews`): for a push,
    /// History index + 1 and length = index + 1 ("these are temporary
    /// best-guess values for immediate synchronous access") and the
    /// navigation API's entry list cut after its current entry with the new
    /// one appended ("update the navigation API entries for a same-document
    /// navigation" step 4); for a replace, the current entry replaced in
    /// place (step 5). A view a waiting traversal holds is written so for the
    /// navigable's own document only.
    pub fn navigateSameDocument(self: *JointHistory, navigable: u64, url: []const u8, state: SerializedState, handling: HistoryHandling, api_state: ?SerializedState) !SameDocumentNavigation {
        const allocator = self.allocator;
        var owned_state = state;
        var owned_api_state = api_state;
        errdefer {
            owned_state.deinit(allocator);
            if (owned_api_state) |*a| a.deinit(allocator);
        }
        // Room for the entry first - `active` points into the list - and for
        // the view's new navigation API entry: nothing changes unless all of
        // it can.
        try self.entries.ensureUnusedCapacity(allocator, 1);
        try self.reserveIndex(navigable);
        if (self.validView(navigable)) |view| try view.api_ids.ensureUnusedCapacity(allocator, 1);
        // The active entry as the document shows it: while a traversal that
        // changes the navigable waits, its step 8.2 has made the target
        // current, but the document still shows the entry it showed
        // (`displayedEntry`) until the traversal activates the target.
        const active = self.displayedEntry(navigable) orelse return error.NoCurrentEntry;
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);
        const origin = try allocator.dupe(u8, active.origin);
        errdefer allocator.free(origin);
        // The document state is shared, so its resource is too.
        const resource: ?[]u8 = if (active.resource) |r| try allocator.dupe(u8, r) else null;
        errdefer if (resource) |r| allocator.free(r);
        // And so is its history policy container.
        var history_container: ?PolicyContainer = if (active.history_policy_container) |*c| try c.clone(allocator) else null;
        errdefer if (history_container) |*c| c.deinit();
        // And its not restored reasons.
        var reasons: ?NotRestoredReasons = if (active.not_restored_reasons) |*r| try r.clone(allocator) else null;
        errdefer if (reasons) |*r| r.deinit(allocator);
        if (owned_api_state == null) owned_api_state = try active.api_state.clone(allocator);
        const replaces: ?u64 = if (handling == .replace) active.id else null;
        const id = self.next_id;
        self.next_id += 1;
        self.entries.appendAssumeCapacity(.{
            .id = id,
            .navigable = navigable,
            .step = active.step,
            .url = owned_url,
            .document_state = active.document_state,
            .document = active.document,
            .state = owned_state,
            .api_state = owned_api_state.?,
            .api_key = if (replaces != null) active.api_key else self.randomUuid(),
            .api_id = self.randomUuid(),
            .origin = origin,
            .resource = resource,
            .history_policy_container = history_container,
            .scroll_restoration_manual = active.scroll_restoration_manual,
            .protect_url = active.protect_url,
            .not_restored_reasons = reasons,
            .keepable_response = active.keepable_response,
            .pending = true,
            .pending_push = handling == .push,
            .pending_replaces = replaces orelse 0,
        });
        self.indexAppended(self.entries.items.len - 1);
        // The navigable displays it: a traversal's kept entry no longer is.
        _ = self.update_only.remove(navigable);
        // The views read it (`writeViews`); a view a waiting traversal holds
        // is written as the synchronous steps write their own document's.
        if (self.isViewHeld(navigable)) self.writeSameDocumentView(navigable, id, handling);
        self.beginChange();
        self.endChange();
        return .{ .entry = id, .replaces = replaces };
    }

    /// The view the synchronous steps write for `navigable`'s document while
    /// a waiting traversal holds it (see `navigateSameDocument`); room for it
    /// was made first.
    fn writeSameDocumentView(self: *JointHistory, navigable: u64, id: u64, handling: HistoryHandling) void {
        const view = self.validView(navigable) orelse return;
        switch (handling) {
            .push => {
                view.index += 1;
                view.length = view.index + 1;
                if (view.api_ids.items.len > 0) {
                    view.api_ids.shrinkRetainingCapacity(view.api_index + 1);
                    view.api_ids.appendAssumeCapacity(id);
                    view.api_index = view.api_ids.items.len - 1;
                }
            },
            .replace => {
                if (view.api_ids.items.len > 0) view.api_ids.items[view.api_index] = id;
            },
        }
        view.api_current = id;
    }

    /// HTML "finalize a same-document navigation" steps 2-6 for the pending
    /// entry `entry_id` of `navigable`, run on the traversal queue; null when
    /// it is no longer pending.
    ///
    /// Step 2 reads "If targetNavigable's active session history entry is not
    /// targetEntry, then return." Deviation, stated (golden rule 2): taken
    /// literally, two synchronous navigations in one task lose an entry - the
    /// first finalize returns, since the second entry is active by then, and
    /// a replace of the first then finds nothing to replace
    /// (whatwg/html#10232, open). Every browser keeps every entry (wpt.fyi,
    /// WPT 07ce6e987a, Chrome 156 / Firefox 159 / Safari 27 all PASS:
    /// html/browsers/history/the-history-interface/combination_history_003
    /// and _004, history_back, history_go_minus; navigation-api/
    /// navigation-history-entry/current-basic and
    /// sameDocument-after-fragment-navigate; history-traversal/event-order/
    /// after-load-hash-twice). So a navigable's pending entries are a FIFO
    /// chain: this lists every earlier pending entry of the navigable, then
    /// this one. The case step 2 exists for - a traversal that activated
    /// another entry for the navigable since - drops the chain
    /// (`dropPending`), and an inline cross-document commit lists it
    /// (`flushPending`; a queued one, `listCrossDocument`, runs after the
    /// finalize steps queued before it, and drops the navigable's chain
    /// made after it when its document is made active).
    ///
    /// Step 5: a push clears the forward session history and is listed at
    /// the current step + 1; a replace takes its replaced entry's place, at
    /// its step, with the current step as targetStep.
    ///
    /// Step 6, "apply the push/replace history step", runs here, inline, not
    /// as an apply with per-navigable tasks. Deviation, stated (lane nav2 E,
    /// integrator, 2026-10-29):
    /// - the spec's own nested apply resets the current step: a finalize that
    ///   jumps a waiting traversal (14.1) sets the step to its push's at its
    ///   step 20, and the traversal's step 20 sets it to the traversal's
    ///   target after; two nested finalize applies leave it at the earlier
    ///   push's (whatwg/html#10232, #12961: no engine resolves targets so);
    /// - the push/replace apply fires no event: its tasks are observable only
    ///   as WHEN the other documents see the new history.length - here, at
    ///   once - and the navigable's own view is the one its synchronous steps
    ///   wrote until its chain is listed;
    /// - the one residual difference: while a traversal waits, the views it
    ///   holds are written at its own update and step 18, so a non-changing
    ///   navigable's history.length between the jumped listing and that step
    ///   18 is the one it had.
    pub fn finalizeSameDocument(self: *JointHistory, navigable: u64, entry_id: u64, replaces: ?u64) ?Finalized {
        _ = replaces; // recorded on the pending entry (pending_replaces)
        if (!self.isPendingOf(navigable, entry_id)) return null;
        self.beginChange();
        defer self.endChange();
        var removed = false;
        while (self.firstPendingIndex(navigable)) |index| {
            const id = self.entries.items[index].id;
            const listed = self.listPending(index);
            if (listed) |l| removed = removed or l.removed;
            if (id == entry_id) {
                const l = listed orelse return null;
                return .{ .step = l.step, .removed = removed };
            }
        }
        return null;
    }

    /// List the pending entry at `index` (see `finalizeSameDocument`): its
    /// step, or null when the entry it replaces is gone (it is dropped).
    /// Within a change.
    fn listPending(self: *JointHistory, index: usize) ?Finalized {
        const entry = &self.entries.items[index];
        const id = entry.id;
        if (entry.pending_push) {
            const removed = self.clearForwardListed();
            const at = self.indexOfId(id) orelse return null;
            const listed = &self.entries.items[at];
            const step = self.current_step + 1;
            listed.step = step;
            listed.pending = false;
            listed.pending_push = false;
            self.pending_count -= 1;
            self.pending_push_count -= 1;
            // "Apply the push/replace history step" step 20, inline.
            self.current_step = step;
            return .{ .step = step, .removed = removed };
        }
        const replaced_id = entry.pending_replaces;
        var moved = self.entries.orderedRemove(index);
        const slot_index = for (self.entries.items, 0..) |e, i| {
            if (e.id == replaced_id and !e.pending and e.navigable == moved.navigable) break i;
        } else {
            // "Replace entryToReplace with targetEntry in targetEntries": it
            // is no longer there - nothing to put the entry in place of.
            moved.deinit(self.allocator);
            self.reindex();
            return null;
        };
        const slot = &self.entries.items[slot_index];
        moved.step = slot.step;
        moved.pending = false;
        moved.pending_replaces = 0;
        // One activation per document state: it stays with the state.
        moved.dropActivation(self.allocator);
        moved.activation = slot.activation;
        slot.activation = null;
        slot.deinit(self.allocator);
        slot.* = moved;
        // The entry moved into its replaced one's place: one rebuild.
        self.reindex();
        return .{ .step = self.current_step, .removed = false };
    }

    /// A traversal activated another entry for `navigable` ("activate
    /// history entry", or a cross-document traversal's new document): its
    /// pending entries are dropped, unlisted - "finalize a same-document
    /// navigation" step 2's case - and its view is written from the history
    /// again (unless held).
    pub fn dropPending(self: *JointHistory, navigable: u64) void {
        if (self.lastPending(navigable) == null) return;
        self.beginChange();
        defer self.endChange();
        _ = self.removeWhere(navigable, struct {
            fn pendingOf(n: u64, entry: *const Entry) bool {
                return entry.pending and entry.navigable == n;
            }
        }.pendingOf);
    }

    /// Every pending entry is listed, in order, now - an inline
    /// cross-document commit (see commitPreparedDocument). Within a change.
    fn flushPending(self: *JointHistory) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (!self.entries.items[i].pending) {
                i += 1;
                continue;
            }
            const navigable = self.entries.items[i].navigable;
            // Its navigable's chain in order: the first is at or before `i`.
            const first = self.firstPendingIndex(navigable) orelse i;
            _ = self.listPending(first);
            i = 0;
        }
    }

    /// Whether the entry `entry_id` is pending (see the file comment).
    pub fn isPending(self: *const JointHistory, entry_id: u64) bool {
        const index = self.indexOfId(entry_id) orelse return false;
        return self.entries.items[index].pending;
    }

    fn isPendingOf(self: *const JointHistory, navigable: u64, entry_id: u64) bool {
        const index = self.indexOfId(entry_id) orelse return false;
        const entry = &self.entries.items[index];
        return entry.pending and entry.navigable == navigable;
    }

    /// Whether `navigable` has pending entries.
    pub fn hasPending(self: *const JointHistory, navigable: u64) bool {
        return self.firstPendingIndex(navigable) != null;
    }

    /// Whether a pending push - which clears the forward history when it is
    /// listed - waits to be finalized.
    pub fn hasPendingPush(self: *const JointHistory) bool {
        return self.pending_push_count > 0;
    }

    fn lastPending(self: *JointHistory, navigable: u64) ?*Entry {
        if (self.pending_count == 0) return null;
        var last: ?*Entry = null;
        var it = self.entriesOf(navigable);
        while (it.next()) |index| {
            const entry = &self.entries.items[index];
            if (entry.pending) last = entry;
        }
        return last;
    }

    fn firstPendingIndex(self: *const JointHistory, navigable: u64) ?usize {
        if (self.pending_count == 0) return null;
        var it = self.entriesOf(navigable);
        while (it.next()) |index| {
            if (self.entries.items[index].pending) return index;
        }
        return null;
    }

    fn indexOfId(self: *const JointHistory, id: u64) ?usize {
        if (self.indexes_valid) {
            const index = self.positions.get(id) orelse return null;
            return index;
        }
        for (self.entries.items, 0..) |entry, i| {
            if (entry.id == id) return i;
        }
        return null;
    }

    /// Whether the navigation API entry list `navigable`'s document reads
    /// has an entry whose key is `key` - with no view, the history does.
    pub fn viewHasKey(self: *JointHistory, navigable: u64, key: *const [36]u8) bool {
        if (self.validView(navigable)) |view| {
            for (view.api_ids.items) |id| {
                const entry = self.entryById(id) orelse continue;
                if (std.mem.eql(u8, &entry.api_key, key)) return true;
            }
            return false;
        }
        return self.entryByKey(navigable, key) != null;
    }

    /// Whether `document_state`'s document came from a response the
    /// back/forward cache may keep (`Entry.keepable_response`).
    pub fn keepableResponse(self: *const JointHistory, document_state: u64) bool {
        for (self.entries.items) |entry| {
            if (entry.document_state == document_state) return entry.keepable_response;
        }
        return false;
    }

    /// Record whether `document_state`'s document came from a response the
    /// back/forward cache may keep - on every entry of the state.
    pub fn setKeepableResponse(self: *JointHistory, document_state: u64, keepable: bool) void {
        for (self.entries.items) |*entry| {
            if (entry.document_state == document_state) entry.keepable_response = keepable;
        }
    }

    /// Whether an entry of `document_state` is still in the history.
    pub fn hasDocumentState(self: *const JointHistory, document_state: u64) bool {
        for (self.entries.items) |entry| {
            if (entry.document_state == document_state) return true;
        }
        return false;
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

    /// HTML "build not restored reasons for document state" step 7:
    /// `document_state`'s not restored reasons become `reasons` (taken) - a
    /// copy on every entry of the state. Out of memory, an entry keeps none.
    pub fn setNotRestoredReasons(self: *JointHistory, document_state: u64, reasons: NotRestoredReasons) void {
        var owned = reasons;
        defer owned.deinit(self.allocator);
        for (self.entries.items) |*entry| {
            if (entry.document_state != document_state) continue;
            entry.dropNotRestoredReasons(self.allocator);
            entry.not_restored_reasons = owned.clone(self.allocator) catch null;
        }
    }

    /// The not restored reasons of the document state of the entry whose id
    /// is `entry_id`, if it has them. BORROWED: the entry keeps them.
    pub fn notRestoredReasons(self: *JointHistory, entry_id: u64) ?*const NotRestoredReasons {
        const entry = self.entryById(entry_id) orelse return null;
        if (entry.not_restored_reasons) |*reasons| return reasons;
        return null;
    }

    /// The document state whose document is `document`, if an entry still
    /// has it.
    pub fn documentStateOf(self: *const JointHistory, document: *anyopaque) ?u64 {
        for (self.entries.items) |entry| {
            if (entry.document == document) return entry.document_state;
        }
        return null;
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

    /// updateCurrentEntry() step 4 writes the entry captured before
    /// serialization, which can run script that changes the current entry.
    /// Takes `api_state` on every path, including a removed entry.
    pub fn setEntryApiState(self: *JointHistory, entry_id: u64, api_state: SerializedState) void {
        var owned = api_state;
        const entry = self.entryById(entry_id) orelse {
            // Disposed NavigationHistoryEntries currently expose undefined
            // state; retaining their serialized state is separate work.
            owned.deinit(self.allocator);
            return;
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
        var it = self.entriesOf(navigable);
        while (it.next()) |index| {
            const entry = &self.entries.items[index];
            if (!entry.pending) try raw.append(allocator, entry);
        }
        std.mem.sort(*Entry, raw.items, {}, struct {
            fn lessThan(_: void, a: *Entry, b: *Entry) bool {
                return a.step < b.step;
            }
        }.lessThan);
        const current = self.activeEntry(navigable) orelse return 0;
        const start = std.mem.indexOfScalar(*Entry, raw.items, current) orelse return 0;
        var first = start;
        while (first > 0 and std.mem.eql(u8, raw.items[first - 1].origin, current.origin)) first -= 1;
        var last = start;
        while (last + 1 < raw.items.len and std.mem.eql(u8, raw.items[last + 1].origin, current.origin)) last += 1;
        try out.appendSlice(allocator, raw.items[first .. last + 1]);
        return start - first;
    }

    /// Record `resource` - a srcdoc document's markup - as the document
    /// state's resource of the entry `entry_id` (a cross-document finalize's
    /// new entry, before its navigable's current entry is it).
    pub fn setEntryResource(self: *JointHistory, entry_id: u64, resource: ?[]const u8) !void {
        const entry = self.entryById(entry_id) orelse return error.NoCurrentEntry;
        const copy: ?[]u8 = if (resource) |r| try self.allocator.dupe(u8, r) else null;
        if (entry.resource) |old| self.allocator.free(old);
        entry.resource = copy;
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
        // A document committed to the navigable is the one it displays.
        _ = self.update_only.remove(navigable);
        switch (handling) {
            .push => {
                self.clearForward();
                const step = self.current_step + 1;
                try self.append(navigable, step, url, doc_state, document, state, api_state, origin, null, prepared);
                self.current_step = step;
            },
            .replace => {
                const current = self.listedCurrentEntry(navigable) orelse {
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
                // It has a new id.
                self.reindex();
            },
        }
    }

    /// "Get all used history steps", sorted and unique, into `out`.
    pub fn usedSteps(self: *const JointHistory, allocator: Allocator, out: *std.ArrayListUnmanaged(u32)) !void {
        out.clearRetainingCapacity();
        try out.ensureTotalCapacity(allocator, self.entries.items.len);
        for (self.entries.items) |entry| {
            if (!entry.pending) out.appendAssumeCapacity(entry.step);
        }
        std.mem.sort(u32, out.items, {}, std.sort.asc(u32));
        // Unique, in place.
        var kept: usize = 0;
        for (out.items) |step| {
            if (kept > 0 and out.items[kept - 1] == step) continue;
            out.items[kept] = step;
            kept += 1;
        }
        out.shrinkRetainingCapacity(kept);
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
            const from = self.viewStep();
            const distance = if (step > from) step - from else from - step;
            if (distance < best_distance) {
                best = step;
                best_distance = distance;
            }
        }
        return best orelse entry.step;
    }

    /// "Get the history object length and index" for the step the
    /// documents read (`viewStep`): (the number of used steps, that step's
    /// index among them).
    pub fn lengthAndIndex(self: *const JointHistory) LengthAndIndex {
        var steps: std.ArrayListUnmanaged(u32) = .empty;
        defer steps.deinit(self.allocator);
        self.usedSteps(self.allocator, &steps) catch return self.lengthAndIndexInPlace();
        return lengthAndIndexIn(steps.items, self.viewStep());
    }

    /// `lengthAndIndex` with no allocation, for when there is no memory for
    /// the sorted steps: quadratic in the entries.
    fn lengthAndIndexInPlace(self: *const JointHistory) LengthAndIndex {
        const entries = self.entries.items;
        const step = self.viewStep();
        var length: u32 = 0;
        var at_or_below: u32 = 0;
        for (entries, 0..) |entry, i| {
            if (entry.pending) continue;
            const seen = for (entries[0..i]) |earlier| {
                if (!earlier.pending and earlier.step == entry.step) break true;
            } else false;
            if (seen) continue;
            length += 1;
            if (entry.step <= step) at_or_below += 1;
        }
        if (length == 0) return .{ .length = 1, .index = 0 };
        return .{ .length = length, .index = if (at_or_below > 0) at_or_below - 1 else 0 };
    }

    /// `lengthAndIndex` given the used steps, sorted and unique, at `step`
    /// - taken as its used step ("getting the used step"): a destroyed
    /// navigable can leave the current step unused until the queued update
    /// for its destruction runs.
    fn lengthAndIndexIn(steps: []const u32, step: u32) LengthAndIndex {
        if (steps.len == 0) return .{ .length = 1, .index = 0 };
        return .{ .length = @intCast(steps.len), .index = @intCast(usedIndexIn(steps, step)) };
    }

    /// The index among `steps` (sorted, unique, non-empty) of the used step
    /// for `step`: the greatest at or before it, else the first.
    fn usedIndexIn(steps: []const u32, step: u32) usize {
        var index: usize = 0;
        for (steps, 0..) |used, i| {
            if (used > step) break;
            index = i;
        }
        return index;
    }

    // =========================================================================
    // The views (see the file comment)
    // =========================================================================

    /// The History length and index `navigable`'s active document reads.
    pub fn historyView(self: *const JointHistory, navigable: u64) LengthAndIndex {
        if (self.views_valid) {
            if (self.views.getPtr(navigable)) |view| return .{ .length = view.length, .index = view.index };
        }
        return self.lengthAndIndex();
    }

    /// The navigation API entry list `navigable`'s active document reads,
    /// into `out`, and its current entry index there: the session history
    /// entries of the view, in order.
    pub fn apiView(self: *JointHistory, navigable: u64, allocator: Allocator, out: *std.ArrayListUnmanaged(*Entry)) !usize {
        if (self.validView(navigable)) |view| resolved: {
            out.clearRetainingCapacity();
            try out.ensureTotalCapacity(allocator, view.api_ids.items.len);
            for (view.api_ids.items) |id| out.appendAssumeCapacity(self.entryById(id) orelse break :resolved);
            return view.api_index;
        }
        // No view, or one naming an entry the history no longer has (every
        // change rewrites the views, so none should): read the entries.
        return self.apiEntries(navigable, allocator, out);
    }

    /// The navigation API's current entry for `navigable`'s active document.
    pub fn apiCurrentView(self: *JointHistory, navigable: u64) ?*Entry {
        if (self.validView(navigable)) |view| {
            const id = view.api_current orelse return null;
            if (self.entryById(id)) |entry| return entry;
        }
        return self.activeEntry(navigable);
    }

    /// The index of the entry `entry_id` in the navigation API entry list
    /// `navigable`'s active document reads, or null when it is not there.
    /// `allocator` is for a read of the entries, when there is no view.
    pub fn apiIndexOf(self: *JointHistory, navigable: u64, entry_id: u64, allocator: Allocator) ?usize {
        if (self.validView(navigable)) |view| return std.mem.indexOfScalar(u64, view.api_ids.items, entry_id);
        var entries: std.ArrayListUnmanaged(*Entry) = .empty;
        defer entries.deinit(allocator);
        _ = self.apiEntries(navigable, allocator, &entries) catch return null;
        for (entries.items, 0..) |entry, i| {
            if (entry.id == entry_id) return i;
        }
        return null;
    }

    /// "Apply the history step" changes `navigable`'s current entry: its
    /// view is not rewritten until `releaseView` - HTML updates a document's
    /// History and navigation API when the target entry's document becomes
    /// active ("update document for history step application", after
    /// "unload a document and its descendants" for another document), so
    /// the document it leaves keeps reading the history it last saw in its
    /// navigate, pageswap, pagehide and unload handlers. Out of memory, it is
    /// not held.
    pub fn holdView(self: *JointHistory, navigable: u64) void {
        if (std.mem.indexOfScalar(u64, self.held.items, navigable) != null) return;
        self.held.append(self.allocator, navigable) catch {};
    }

    /// "Apply the history step" begins: every navigable's view is held, and
    /// written again only where the spec writes it - a changing navigable's
    /// at its "update document for history step application", the others'
    /// at step 18 - or when the apply ends. Out of memory, a view is not
    /// held.
    pub fn holdAllViews(self: *JointHistory) void {
        for (self.views.keys()) |navigable| self.holdView(navigable);
    }

    /// `navigable`'s target entry's document is active: its view is written
    /// again, from the history as it is now.
    pub fn releaseView(self: *JointHistory, navigable: u64) void {
        const index = std.mem.indexOfScalar(u64, self.held.items, navigable) orelse return;
        _ = self.held.swapRemove(index);
        self.updateViews();
    }

    /// Every held view is written again: the traversal that held them ended.
    pub fn releaseAllViews(self: *JointHistory) void {
        if (self.held.items.len == 0) return;
        self.held.clearRetainingCapacity();
        self.updateViews();
    }

    /// Whether `navigable`'s view is held.
    pub fn isViewHeld(self: *const JointHistory, navigable: u64) bool {
        return std.mem.indexOfScalar(u64, self.held.items, navigable) != null;
    }

    /// `navigable`'s view, when the views are current and it has one.
    fn validView(self: *JointHistory, navigable: u64) ?*View {
        if (!self.views_valid) return null;
        return self.views.getPtr(navigable);
    }

    /// Rewrite every navigable's view from the history as it is now - each
    /// equal to what a live read gives (`lengthAndIndex`, `apiEntries`,
    /// `activeEntry`) - and drop the views of navigables it no longer has.
    /// Out of memory, the views are read from the entries until a later
    /// update succeeds.
    pub fn updateViews(self: *JointHistory) void {
        self.writeViews() catch {
            self.views_valid = false;
            return;
        };
        self.views_valid = true;
    }

    fn writeViews(self: *JointHistory) !void {
        const allocator = self.allocator;
        const entries = self.entries.items;
        self.views_epoch += 1;
        const epoch = self.views_epoch;

        // The history the documents read is the one the synchronous
        // navigations pending now will make once listed (lane nav2 E): their
        // finalize steps run in order on the traversal queue, each push one
        // step on with the forward history cleared, each replace in place of
        // the entry it replaces. So a document's History and navigation API
        // read its own and the other navigables' synchronous navigations at
        // once, as every browser shows them (html/browsers/history/
        // the-history-interface/001.html: a frame's location.hash and
        // pushState() change its parent's history.length synchronously,
        // Chrome/Firefox/Safari), while the traversal endpoints read the
        // listed history ("same-document traversals ... calculate their
        // endpoint based on the original placement"). Each entry's projected
        // step, or null when it is not in that history.
        //
        // Its buffers are the history's own, kept between calls (lane nav2
        // H): every change writes the views - a fragment navigation twice.
        const base = self.viewStep();
        const scratch = &self.view_scratch;
        try scratch.projected.resize(allocator, entries.len);
        const projected = scratch.projected.items;
        const pushes = self.pending_push_count;
        for (entries, 0..) |entry, i| {
            projected[i] = if (entry.pending or (pushes > 0 and entry.step > base)) null else entry.step;
        }
        var next = base;
        // The pending entries, in list order: few, and each navigable's last
        // is its current one below.
        const pending = &scratch.pending;
        pending.clearRetainingCapacity();
        if (self.pending_count > 0) for (entries, 0..) |entry, i| {
            if (!entry.pending) continue;
            try pending.append(allocator, @intCast(i));
            if (entry.pending_push) {
                next += 1;
                projected[i] = next;
                continue;
            }
            // A replace takes its replaced entry's place - listed, or a
            // pending one earlier in the list.
            if (self.indexOfId(entry.pending_replaces)) |r| {
                projected[i] = projected[r];
                projected[r] = null;
            }
        };
        const step = next;

        // The History length and index: one pair for the traversable.
        const steps = &scratch.steps;
        steps.clearRetainingCapacity();
        try steps.ensureTotalCapacity(allocator, entries.len);
        for (projected) |at| {
            if (at) |s| steps.appendAssumeCapacity(s);
        }
        // Mostly in order already: each push is listed after the entries
        // before it.
        if (!std.sort.isSorted(u32, steps.items, {}, std.sort.asc(u32))) std.mem.sort(u32, steps.items, {}, std.sort.asc(u32));
        {
            var kept: usize = 0;
            for (steps.items) |s| {
                if (kept > 0 and steps.items[kept - 1] == s) continue;
                steps.items[kept] = s;
                kept += 1;
            }
            steps.shrinkRetainingCapacity(kept);
        }
        const length_index = lengthAndIndexIn(steps.items, step);

        // Each navigable's entries in that history, by step - in list order
        // among equal steps, as `apiEntries` and `entryAt` have them (a
        // stable sort): grouped by navigable from the index lists, each group
        // sorted only when it is not in order already; with no valid
        // indexes, one sort of them all.
        const order_list = &scratch.order;
        order_list.clearRetainingCapacity();
        try order_list.ensureTotalCapacity(allocator, entries.len);
        const Sort = struct {
            list: []const Entry,
            at: []const ?u32,
            fn lessThan(context: @This(), a: u32, b: u32) bool {
                if (context.list[a].navigable != context.list[b].navigable) return context.list[a].navigable < context.list[b].navigable;
                return context.at[a].? < context.at[b].?;
            }
        };
        const sort_context = Sort{ .list = entries, .at = projected };
        if (self.indexes_valid) {
            for (self.lists.values()) |list| {
                const start = order_list.items.len;
                for (list.items) |i| {
                    if (projected[i] != null) order_list.appendAssumeCapacity(i);
                }
                const group = order_list.items[start..];
                if (!std.sort.isSorted(u32, group, sort_context, Sort.lessThan)) std.mem.sort(u32, group, sort_context, Sort.lessThan);
            }
        } else {
            for (projected, 0..) |at, i| {
                if (at != null) order_list.appendAssumeCapacity(@intCast(i));
            }
            std.mem.sort(u32, order_list.items, sort_context, Sort.lessThan);
        }
        const order = order_list.items;

        var group_start: usize = 0;
        while (group_start < order.len) {
            const navigable = entries[order[group_start]].navigable;
            var group_end = group_start + 1;
            while (group_end < order.len and entries[order[group_end]].navigable == navigable) group_end += 1;
            const group = order[group_start..group_end];
            group_start = group_end;

            const slot = try self.views.getOrPut(allocator, navigable);
            if (!slot.found_existing) slot.value_ptr.* = .{};
            const view = slot.value_ptr;
            view.epoch = epoch;
            // A held view keeps what it has (`holdView`).
            if (slot.found_existing and self.isViewHeld(navigable)) continue;
            view.length = length_index.length;
            view.index = length_index.index;
            view.api_ids.clearRetainingCapacity();
            view.api_index = 0;
            view.api_current = null;

            // `activeEntry`: the navigable's latest pending entry - a
            // synchronous navigation made it active, even while a traversal
            // that changes the navigable holds its target as the current
            // entry (step 8.2); else the kept entry, at the step it was kept
            // at; else `entryAt` the current step - the last of the group
            // (list order among equal steps) at or before it.
            var current: ?*const Entry = null;
            {
                var p = pending.items.len;
                while (p > 0) {
                    p -= 1;
                    if (entries[pending.items[p]].navigable == navigable) {
                        current = &entries[pending.items[p]];
                        break;
                    }
                }
            }
            if (current == null) {
                if (self.update_only.get(navigable)) |kept| {
                    if (kept.step == step) current = self.entryById(kept.entry);
                }
            }
            if (current == null) {
                if (self.apply) |apply| {
                    if (apply.current.get(navigable)) |id| current = self.entryById(id);
                }
            }
            if (current == null) {
                for (group) |position| {
                    if (projected[position].? > step) break;
                    current = &entries[position];
                }
            }
            const active = current orelse continue;
            view.api_current = active.id;

            // `apiEntries`: the contiguous same-origin run around it.
            var start: ?usize = null;
            for (group, 0..) |position, i| {
                if (&entries[position] == active) {
                    start = i;
                    break;
                }
            }
            const at = start orelse continue;
            var first = at;
            while (first > 0 and std.mem.eql(u8, entries[group[first - 1]].origin, active.origin)) first -= 1;
            var last = at;
            while (last + 1 < group.len and std.mem.eql(u8, entries[group[last + 1]].origin, active.origin)) last += 1;
            try view.api_ids.ensureTotalCapacity(allocator, last + 1 - first);
            for (group[first .. last + 1]) |position| view.api_ids.appendAssumeCapacity(entries[position].id);
            view.api_index = at - first;
        }

        // The views of navigables the history no longer has.
        var i: usize = 0;
        while (i < self.views.count()) {
            const view = &self.views.values()[i];
            if (view.epoch == epoch) {
                i += 1;
                continue;
            }
            view.deinit(allocator);
            self.views.swapRemoveAt(i);
        }
    }

    /// "Traverse the history by a delta" step 4.1-4.4: the used step `delta`
    /// away from the current one, or null when there is none.
    /// Counted from the step the documents read (`viewStep`), taken as its
    /// used step.
    pub fn stepByDelta(self: *const JointHistory, delta: i64) ?u32 {
        var steps: std.ArrayListUnmanaged(u32) = .empty;
        defer steps.deinit(self.allocator);
        self.usedSteps(self.allocator, &steps) catch return null;
        if (steps.items.len == 0) return null;
        const current = usedIndexIn(steps.items, self.viewStep());
        const target = @as(i64, @intCast(current)) + delta;
        if (target < 0 or target >= @as(i64, @intCast(steps.items.len))) return null;
        return steps.items[@intCast(target)];
    }

    /// Where `stepByDelta`'s traversal goes once the synchronous navigations
    /// pending now are listed (`PredictedStep`).
    pub const PredictedStep = union(enum) {
        /// A listed step.
        listed: u32,
        /// The step of one of the pending pushes: on its navigable's
        /// document.
        pushed,
    };

    /// "Traverse the history by a delta" step 4's target for `delta` as its
    /// queued steps will compute it, asked when they are appended: after the
    /// finalize steps of the synchronous navigations pending now - queued
    /// ahead of them - have listed their entries, each push one step on with
    /// the forward history cleared. Null when out of range.
    pub fn predictedStepByDelta(self: *const JointHistory, delta: i64) ?PredictedStep {
        var pushes: usize = 0;
        for (self.entries.items) |entry| {
            if (entry.pending and entry.pending_push) pushes += 1;
        }
        if (pushes == 0) return .{ .listed = self.stepByDelta(delta) orelse return null };
        var steps: std.ArrayListUnmanaged(u32) = .empty;
        defer steps.deinit(self.allocator);
        self.usedSteps(self.allocator, &steps) catch return null;
        const base = self.viewStep();
        var kept: usize = 0;
        for (steps.items) |step| {
            if (step <= base) kept += 1;
        }
        const length: i64 = @intCast(kept + pushes);
        const target = length - 1 + delta;
        if (target < 0 or target >= length) return null;
        if (target >= kept) return .pushed;
        return .{ .listed = steps.items[@intCast(target)] };
    }

    /// A navigable was destroyed: its entries go - "destroy a child
    /// navigable" step 7 removes its nested history - and so does its view.
    /// The current step is left to the "update for navigable
    /// creation/destruction" its destruction queues (step 9), which takes the
    /// used step at or before it (`usedStepAtOrBefore`, "getting the used
    /// step"); until then the step may be unused, and its readers take its
    /// used step.
    ///
    /// Deviation, stated (golden rule 2; integrator's ruling of 2026-10-28):
    /// the other documents' views - their History length - are written now,
    /// not at that update's step 18. The browsers split three ways: Firefox
    /// 158 removes the entries at once, which is what WPT expects
    /// (discard_iframe_history_3 and _4, Firefox 1/1, read history.length
    /// right after removeChild; initial-empty-document/iframe-nosrc and
    /// iframe-src-204 read it right after the previous case's frame was
    /// removed); Chrome 156 and Safari 27 keep the entries (0/1 at wpt.fyi
    /// ffc4686d11); the spec writes the length at the queued update's step 18.
    /// Crane keeps main's existing behaviour, because both the literal spec
    /// timing and the Chrome/Safari majority would lose 8 PASS names (lane
    /// nav2 C2's full A/B). Open question for the user (feature queue). A held
    /// view (an apply running) stays held.
    pub fn removeNavigable(self: *JointHistory, navigable: u64) void {
        self.beginChange();
        defer self.endChange();
        _ = self.update_only.remove(navigable);
        if (std.mem.indexOfScalar(u64, self.held.items, navigable)) |index| _ = self.held.swapRemove(index);
        if (self.apply) |*apply| _ = apply.current.swapRemove(navigable);
        _ = self.removeWhere(navigable, struct {
            fn of(n: u64, entry: *const Entry) bool {
                return entry.navigable == n;
            }
        }.of);
        if (self.views.fetchSwapRemove(navigable)) |kv| {
            var view = kv.value;
            view.deinit(self.allocator);
        }
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
        const index = self.indexOfId(id) orelse return null;
        return &self.entries.items[index];
    }

    /// An entry of `navigable` whose navigation API key is `key`, if the
    /// history still has one.
    pub fn entryByKey(self: *JointHistory, navigable: u64, key: *const [36]u8) ?*Entry {
        var it = self.entriesOf(navigable);
        while (it.next()) |index| {
            const entry = &self.entries.items[index];
            if (std.mem.eql(u8, &entry.api_key, key)) return entry;
        }
        return null;
    }
};
