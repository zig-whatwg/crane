//! HTML 6.6.7: the autofocus candidates and processed flag owned by Document.
//! Stable entries keep their nodes through MemberHold. A removed first entry
//! can outlive the queue while focusing runs script, including realm teardown.
//! lint-impls: hook for Document
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const MemberHold = @import("node_holds.zig").MemberHold;
const KeptInstance = @import("custom_elements.zig").KeptInstance;

/// One owned candidate. Neither the linked hold nor its traced-slot name moves.
pub const Candidate = struct {
    allocator: std.mem.Allocator,
    owner: KeptInstance,
    element: MemberHold = .{},
    previous: ?*Candidate = null,
    next: ?*Candidate = null,
    previous_id: ?*Candidate = null,
    next_id: ?*Candidate = null,
    id: usize,
    slot_bytes: [48]u8 = undefined,
    slot_len: usize = 0,

    fn slot(self: *const Candidate) engine.TracedSlot {
        return .{ .name = self.slot_bytes[0..self.slot_len] };
    }

    /// Release the native hold, and its traced edge while the owner still lives.
    /// The generation/realm check is only the coordinated-teardown safety net.
    pub fn release(self: *Candidate) void {
        if (self.owner.get() == null) self.element.kept = false;
        self.element.release(self.owner.instance, self.slot());
        self.allocator.destroy(self);
    }
};

/// Lazily owned by Document. Empty documents allocate nothing; processing an
/// empty queue leaves `processed` false so a later insertion remains eligible.
pub const State = struct {
    processed: bool = false,
    first: ?*Candidate = null,
    last: ?*Candidate = null,
    /// The same entries ordered by slot id, independent of insertion order.
    /// Finding the first free slot is one scan, with no second allocation.
    first_id: ?*Candidate = null,

    /// Publish only a fully initialized state. A failed allocation leaves the
    /// owning Document's slot null and acquires no candidate hold.
    pub fn ensure(slot: *?*State, allocator: std.mem.Allocator) !*State {
        if (slot.*) |state| return state;
        const state = try allocator.create(State);
        state.* = .{};
        slot.* = state;
        return state;
    }

    pub fn destroy(self: *State, allocator: std.mem.Allocator) void {
        self.clear();
        allocator.destroy(self);
    }

    pub fn hasCandidates(self: *const State) bool {
        return !self.processed and self.first != null;
    }

    /// Insertion step 7: remove an existing candidate, then append it. Moving
    /// an entry does not allocate or move its hold. New entries reuse free ids,
    /// so repeated empty/append cycles do not intern unbounded slot names.
    pub fn append(self: *State, allocator: std.mem.Allocator, owner: *runtime.Instance, element: *runtime.Instance) !void {
        if (self.processed) return;
        var current = self.first;
        while (current) |entry| : (current = entry.next) {
            if (entry.element.get() == element) {
                self.unlink(entry);
                self.linkLast(entry);
                return;
            }
        }
        var id: usize = 0;
        var previous_id: ?*Candidate = null;
        var next_id = self.first_id;
        while (next_id) |entry| {
            if (entry.id != id) break;
            id += 1;
            previous_id = entry;
            next_id = entry.next_id;
        }
        const entry = try allocator.create(Candidate);
        errdefer allocator.destroy(entry);
        entry.* = .{
            .allocator = allocator,
            .owner = KeptInstance.of(owner),
            .id = id,
            .previous_id = previous_id,
            .next_id = next_id,
        };
        entry.slot_len = (try std.fmt.bufPrint(&entry.slot_bytes, "autofocus:{d}", .{id})).len;
        entry.element.take(owner, element, entry.slot());
        if (previous_id) |previous| previous.next_id = entry else self.first_id = entry;
        if (next_id) |next| next.previous_id = entry;
        self.linkLast(entry);
    }

    fn unlink(self: *State, entry: *Candidate) void {
        if (entry.previous) |previous| previous.next = entry.next else self.first = entry.next;
        if (entry.next) |next| next.previous = entry.previous else self.last = entry.previous;
        entry.previous = null;
        entry.next = null;
    }

    fn linkLast(self: *State, entry: *Candidate) void {
        entry.previous = self.last;
        if (self.last) |last| last.next = entry else self.first = entry;
        self.last = entry;
    }

    /// Transfer ownership of the first candidate to the caller, who releases
    /// it after focusing. Document teardown no longer reaches this entry.
    /// Release it before appending to an unprocessed queue. The HTML flush
    /// sets processed before invoking script, so its slot cannot be reused
    /// while the focusing call still owns this entry.
    pub fn takeFirst(self: *State) ?*Candidate {
        const entry = self.first orelse return null;
        self.unlink(entry);
        if (entry.previous_id) |previous| previous.next_id = entry.next_id else self.first_id = entry.next_id;
        if (entry.next_id) |next| next.previous_id = entry.previous_id;
        entry.previous_id = null;
        entry.next_id = null;
        return entry;
    }

    /// Empty the list without changing the processed flag. Also valid during
    /// the orphan-state sweep after the realm ended (Candidate.release).
    pub fn clear(self: *State) void {
        while (self.takeFirst()) |entry| entry.release();
    }

    /// Flush step 4 / 5.11 and dialog focusing steps 9–10.
    pub fn complete(self: *State) void {
        self.processed = true;
        self.clear();
    }
};

/// Reach Document's state through its existing process-start lifecycle table.
pub fn ofDocument(document: *runtime.Instance) ?*State {
    return @import("document_lifecycle.zig").autofocusState(document, false);
}

/// Only insertion and dialog completion need to create Document state.
/// Rendering queries and an empty flush always use the read-only lookup.
pub fn ensureForDocument(document: *runtime.Instance) ?*State {
    return @import("document_lifecycle.zig").autofocusState(document, true);
}

/// Native rendering work remains only while candidates can still be processed.
pub fn hasCandidates(document: *runtime.Instance) bool {
    const state = ofDocument(document) orelse return false;
    return state.hasCandidates();
}
