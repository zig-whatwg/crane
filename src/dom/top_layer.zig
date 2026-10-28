//! Document-owned top-layer membership and the nodes popover algorithms keep.
//! Rendering is supplied by the host. Entries use existing marked MemberHolds,
//! as Blink's Document top layer traces Member<Element> entries.
//! lint-impls: hook for Document
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const MemberHold = @import("node_holds.zig").MemberHold;
const controls = @import("form_controls.zig");
const process_start = @import("process_start.zig");
const KeptInstance = @import("custom_elements.zig").KeptInstance;

pub const Mode = enum { auto, hint, manual };

pub const Entry = struct {
    id: usize,
    element: MemberHold = .{},
    source: MemberHold = .{},
    previous_focus: MemberHold = .{},
    node_slot: [64]u8 = undefined,
    source_slot: [64]u8 = undefined,
    focus_slot: [64]u8 = undefined,
    node_slot_len: usize = 0,
    source_slot_len: usize = 0,
    focus_slot_len: usize = 0,
    showing: bool = false,
    hiding: bool = false,
    mode: Mode = .manual,
    picker: bool = false,
    /// Modal membership is independent of a dialog's open attribute and of
    /// popover visibility (HTML 4.11.4 and 6.3.1).
    modal: bool = false,

    pub fn node(self: *const Entry) ?*runtime.Instance {
        return self.element.get();
    }

    fn nodeSlot(self: *const Entry) engine.TracedSlot {
        return .{ .name = self.node_slot[0..self.node_slot_len] };
    }

    fn sourceSlot(self: *const Entry) engine.TracedSlot {
        return .{ .name = self.source_slot[0..self.source_slot_len] };
    }

    fn focusSlot(self: *const Entry) engine.TracedSlot {
        return .{ .name = self.focus_slot[0..self.focus_slot_len] };
    }

    pub fn keepSource(self: *Entry, owner: *runtime.Instance, source: ?*runtime.Instance) void {
        self.source.release(owner, self.sourceSlot());
        if (source) |member| self.source.take(owner, member, self.sourceSlot());
    }

    pub fn keepPreviousFocus(self: *Entry, owner: *runtime.Instance, previous: ?*runtime.Instance) void {
        self.previous_focus.release(owner, self.focusSlot());
        if (previous) |member| self.previous_focus.take(owner, member, self.focusSlot());
    }
};

pub const State = struct {
    allocator: std.mem.Allocator,
    owner: *runtime.Instance,
    /// Teardown safety net only. Normal membership always uses its live
    /// Document owner and marked holds; this never weakens a script read.
    owner_at_creation: KeptInstance,
    /// Stable allocated entries: linked MemberHolds must never be moved by
    /// ArrayList growth. Non-showing entries pin synchronous event snapshots.
    entries: std.ArrayListUnmanaged(*Entry) = .empty,
    /// Pulled by the style engine. Scoped pins share this entry list;
    /// every insertion, promotion and removal advances its revision.
    revision: u64 = 0,
    /// Non-owning index into the stable entries above. Removal updates this
    /// before freeing an entry; no modal means a single null check.
    last_modal: ?*Entry = null,
    showing_popover: bool = false,
    hiding_nesting: usize = 0,
    pointerdown_target: MemberHold = .{},
    hint_parent: MemberHold = .{},

    pub fn init(allocator: std.mem.Allocator, owner: *runtime.Instance) State {
        return .{ .allocator = allocator, .owner = owner, .owner_at_creation = KeptInstance.of(owner) };
    }

    pub fn byId(self: *State, id: usize) ?*Entry {
        for (self.entries.items) |entry| if (entry.id == id) return entry;
        return null;
    }

    pub fn find(self: *State, node: *runtime.Instance) ?*Entry {
        return self.findKind(node, false);
    }

    pub fn findKind(self: *State, node: *runtime.Instance, picker: bool) ?*Entry {
        for (self.entries.items) |entry| {
            if (entry.showing and entry.picker == picker and entry.node() == node) return entry;
        }
        return null;
    }

    pub fn findModal(self: *State, node: *runtime.Instance) ?*Entry {
        for (self.entries.items) |entry| {
            if (entry.modal and entry.node() == node) return entry;
        }
        return null;
    }

    pub fn lastModal(self: *State) ?*runtime.Instance {
        return (self.last_modal orelse return null).node();
    }

    pub fn addModal(self: *State, node: *runtime.Instance) !*Entry {
        if (self.findModal(node)) |entry| return entry;
        const entry = try self.pin(node);
        entry.modal = true;
        self.last_modal = entry;
        self.revision +%= 1;
        return entry;
    }

    /// Keep a node for a synchronous algorithm. Promoting this entry to
    /// showing adds it to the top layer; otherwise it is only a scoped pin.
    pub fn pin(self: *State, node: *runtime.Instance) !*Entry {
        var id: usize = 0;
        while (self.byId(id) != null) : (id += 1) {}
        const entry = try self.allocator.create(Entry);
        errdefer self.allocator.destroy(entry);
        entry.* = .{ .id = id };
        // Reuse an unused id: repeated show/hide must not intern an unbounded
        // sequence of distinct private-property names in the engine.
        entry.node_slot_len = (try std.fmt.bufPrint(&entry.node_slot, "top_layer:{d}:node", .{id})).len;
        entry.source_slot_len = (try std.fmt.bufPrint(&entry.source_slot, "top_layer:{d}:source", .{id})).len;
        entry.focus_slot_len = (try std.fmt.bufPrint(&entry.focus_slot, "top_layer:{d}:focus", .{id})).len;
        try self.entries.append(self.allocator, entry);
        self.revision +%= 1;
        entry.element.take(self.owner, node, entry.nodeSlot());
        return entry;
    }

    pub fn remove(self: *State, id: usize) void {
        for (self.entries.items, 0..) |entry, index| {
            if (entry.id != id) continue;
            _ = self.entries.orderedRemove(index);
            self.revision +%= 1;
            if (self.last_modal == entry) {
                self.last_modal = null;
                var remaining = self.entries.items.len;
                while (remaining != 0) {
                    remaining -= 1;
                    if (self.entries.items[remaining].modal) {
                        self.last_modal = self.entries.items[remaining];
                        break;
                    }
                }
            }
            if (entry.picker) if (entry.node()) |node| controls.setPickerOpen(node, false) catch {};
            entry.previous_focus.release(self.owner, entry.focusSlot());
            entry.source.release(self.owner, entry.sourceSlot());
            entry.element.release(self.owner, entry.nodeSlot());
            self.allocator.destroy(entry);
            return;
        }
    }

    pub fn setPointerdownTarget(self: *State, node: ?*runtime.Instance) void {
        const slot: engine.TracedSlot = .{ .name = "top_layer:pointerdown" };
        self.pointerdown_target.release(self.owner, slot);
        if (node) |value| self.pointerdown_target.take(self.owner, value, slot);
    }

    pub fn setHintParent(self: *State, node: ?*runtime.Instance) void {
        const slot: engine.TracedSlot = .{ .name = "top_layer:hint_parent" };
        self.hint_parent.release(self.owner, slot);
        if (node) |value| self.hint_parent.take(self.owner, value, slot);
    }

    pub fn deinit(self: *State) void {
        self.setPointerdownTarget(null);
        self.setHintParent(null);
        while (self.entries.items.len != 0) self.remove(self.entries.items[self.entries.items.len - 1].id);
        self.entries.deinit(self.allocator);
    }

    /// The orphan Document-state sweep may run after its realm/instance
    /// ended. Unlink every hold without behavior hooks or events. Forget a
    /// traced slot only while the existing generation/realm net says its
    /// owner is live (row61 Q15); an ended wrapper has no edge left to clear.
    /// AGENTS.md "DOM lifetime": this generation check is a teardown net.
    /// No known production path reaches this net: navigation and a removed
    /// iframe whose Document remains referenced both use deinitOwn (Q38).
    /// Keep it because Registry.deinitAllAndClear can free Document state
    /// without deinitOwn; the saved-state native test pins the ended realm.
    pub fn releaseAfterRealmEnded(self: *State) void {
        const owner_live = self.owner_at_creation.get() != null;
        self.last_modal = null;
        self.releaseOrphanHold(&self.pointerdown_target, .{ .name = "top_layer:pointerdown" }, owner_live);
        self.releaseOrphanHold(&self.hint_parent, .{ .name = "top_layer:hint_parent" }, owner_live);
        for (self.entries.items) |entry| {
            self.revision +%= 1;
            self.releaseOrphanHold(&entry.previous_focus, entry.focusSlot(), owner_live);
            self.releaseOrphanHold(&entry.source, entry.sourceSlot(), owner_live);
            self.releaseOrphanHold(&entry.element, entry.nodeSlot(), owner_live);
            self.allocator.destroy(entry);
        }
        self.entries.deinit(self.allocator);
    }

    fn releaseOrphanHold(self: *State, hold: *MemberHold, slot: engine.TracedSlot, owner_live: bool) void {
        if (!owner_live) hold.kept = false;
        // With kept cleared, release only unlinks and clears the native hold;
        // it does not dereference owner (node_holds.MemberHold's contract).
        hold.release(self.owner, slot);
    }
};

pub const Access = struct {
    get: *const fn (document: *runtime.Instance, create: bool) anyerror!?*State,
};
// process-wide: Document installs one immutable accessor at process startup; each returned State belongs to that Document and its Browser
var access: ?Access = null;

pub fn install(implementation: Access) void {
    process_start.assertInstalling();
    access = implementation;
}

pub fn ofDocument(document: *runtime.Instance, create: bool) !?*State {
    return (access orelse return error.NotSupported).get(document, create);
}

/// Read without allocating the Document's optional top-layer state.
pub fn revisionOf(document: *runtime.Instance) u64 {
    const state = (ofDocument(document, false) catch null) orelse return 0;
    return state.revision;
}

pub fn ofElement(element: *runtime.Instance, create: bool) !?*State {
    const document = (try interfaces.Node.get_ownerDocument(element)) orelse return null;
    return ofDocument(document, create);
}

pub fn showing(element: *runtime.Instance) bool {
    const state = (ofElement(element, false) catch null) orelse return false;
    return state.find(element) != null;
}
