//! Document-owned top-layer membership and the nodes popover algorithms keep.
//! Rendering is supplied by the host. Entries use existing marked MemberHolds,
//! as Blink's Document top layer traces Member<Element> entries.
//! lint-impls: hook for Document
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const MemberHold = @import("node_holds.zig").MemberHold;
const TaskHold = @import("node_holds.zig").TaskHold;
const controls = @import("form_controls.zig");
const KeptInstance = @import("custom_elements.zig").KeptInstance;
const Hook = @import("hook.zig").Hook;
const inspector_probes = @import("inspector_probes.zig");

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
    /// Fullscreen 2: the element's fullscreen flag. An element has it only
    /// while it is in the top layer ("fullscreen an element" adds it there,
    /// "unfullscreen an element" removes it immediately), so the flag is kept
    /// on its own entry: one with no popover or modal membership, which the
    /// popover and dialog algorithms never read (they read `showing` and
    /// `modal`). html.fullscreen owns the algorithms.
    fullscreen: bool = false,
    /// Fullscreen 2: an iframe's iframe fullscreen flag (requestFullscreen
    /// step 13.3), on its fullscreen entry.
    iframe_fullscreen: bool = false,
    /// Fullscreen 2: the keyboard lock flag (requestFullscreen step 14), on
    /// the element's fullscreen entry: "unfullscreen an element" unsets it.
    keyboard_lock: bool = false,
    /// CSS Position 4 §3.3 "pending top layer removals": `dialog.close()` and
    /// `hidePopover()` (when firing events) request removal instead of
    /// removing immediately; update-the-rendering step 23
    /// (`processTopLayerRemovals`) finishes removal once the element is not
    /// rendered or its computed `overlay` is `none`.
    pending_removal: bool = false,

    /// Whether this entry represents an element contained in the document's
    /// top layer (active membership OR pending top layer removal). A scoped
    /// pin alone is not membership.
    pub fn isTopLayerMember(self: *const Entry) bool {
        return self.showing or self.modal or self.fullscreen or self.pending_removal;
    }

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

/// Open-dialog registration is separate from modal top-layer membership.
/// This record's address stays fixed while its MemberHold is linked.
pub const OpenDialog = struct {
    id: usize,
    element: MemberHold = .{},
    slot_name: [64]u8 = undefined,
    slot_len: usize = 0,

    fn slot(self: *const OpenDialog) engine.TracedSlot {
        return .{ .name = self.slot_name[0..self.slot_len] };
    }
};

/// Fullscreen 2: one (type, element) tuple of a document's list of pending
/// fullscreen events. The element is held and kept until "run the
/// fullscreen steps" fires the event (html.fullscreen) or the document goes.
/// This record's address stays fixed while its MemberHold is linked.
pub const FullscreenEvent = struct {
    pub const Type = enum {
        fullscreenchange,
        fullscreenerror,
    };

    id: usize,
    type: Type,
    element: MemberHold = .{},
    slot_name: [64]u8 = undefined,
    slot_len: usize = 0,

    fn slot(self: *const FullscreenEvent) engine.TracedSlot {
        return .{ .name = self.slot_name[0..self.slot_len] };
    }
};

/// A pending fullscreen event taken out of the list (`takeFullscreenEvents`).
/// Its hold keeps the element (empty when the element was already gone)
/// until the caller releases it, exactly once.
pub const TakenFullscreenEvent = struct {
    type: FullscreenEvent.Type,
    hold: TaskHold = .{},
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
    open_dialogs: std.ArrayListUnmanaged(*OpenDialog) = .empty,
    /// Fullscreen 2: the document's list of pending fullscreen events, an
    /// ordered set, in the order the tuples were appended.
    fullscreen_events: std.ArrayListUnmanaged(*FullscreenEvent) = .empty,
    dialog_pointerdown_target: MemberHold = .{},
    /// A logically non-null removed target, unequal to every node, without
    /// retaining the detached subtree (Q47 addendum, 2026-10-29).
    dialog_pointerdown_target_removed: bool = false,

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

    /// Position 4 §3.3: whether `node` is contained in the document's top
    /// layer — a showing popover or picker, a modal dialog, a fullscreen
    /// element, OR an element in `pending top layer removals` (which remains
    /// rendered in the top layer while its computed `overlay` is `auto`). A
    /// scoped pin alone is not membership.
    pub fn inTopLayer(self: *const State, node: *runtime.Instance) bool {
        for (self.entries.items) |entry| {
            if (entry.isTopLayerMember() and entry.node() == node) return true;
        }
        return false;
    }

    /// Position 4 §3.3 "in the top layer": contained in the document's top
    /// layer AND NOT in `pending top layer removals`.
    pub fn inTopLayerNotPending(self: *const State, node: *runtime.Instance) bool {
        for (self.entries.items) |entry| {
            if ((entry.showing or entry.modal or entry.fullscreen) and entry.node() == node) return true;
        }
        return false;
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
        // Position 4 §3.3 "add an element to the top layer" step 2: if el is
        // already in doc's top layer (pending removal), remove it from both
        // top layer and pending removals before appending at the end.
        self.removePendingRemovalsFor(node, false);
        const entry = try self.pin(node);
        entry.modal = true;
        self.last_modal = entry;
        self.revision +%= 1;
        self.membersChanged();
        return entry;
    }

    /// Position 4 §3.3 "request an element to be removed from the top layer":
    /// ends modal/popover active state immediately (so :modal / :popover-open
    /// and the UA !important `overlay: auto` rule stop matching right away),
    /// keeps the element in the document's top layer marked `pending_removal`,
    /// and requests a rendering opportunity so step 23
    /// (`processTopLayerRemovals`) finishes removal once the element is not
    /// rendered or its computed `overlay` is `none`.
    ///
    /// Matches Blink's `Document::ScheduleForTopLayerRemoval` /
    /// `RemoveFinishedTopLayerElements`: `probe::TopLayerElementsChanged` is
    /// NOT fired here — it fires in step 23 when removal completes.
    pub fn requestRemoval(self: *State, entry: *Entry) void {
        if (entry.pending_removal) return;
        if (!(entry.showing or entry.modal or entry.fullscreen)) return;
        if (entry.modal) {
            entry.modal = false;
            if (self.last_modal == entry) self.recomputeLastModal();
        }
        if (entry.showing) {
            if (entry.picker) if (entry.node()) |n| controls.setPickerOpen(n, false) catch {};
            entry.picker = false;
            entry.showing = false;
        }
        entry.previous_focus.release(self.owner, entry.focusSlot());
        entry.source.release(self.owner, entry.sourceSlot());
        entry.pending_removal = true;
        self.revision +%= 1;
        @import("update_the_rendering.zig").requestFrame(self.owner);
    }

    /// Remove any `pending_removal` entries for `node`. `notify` is true for
    /// "remove an element from the top layer immediately" (e.g. DOM removing
    /// steps) and false for "add an element to the top layer" step 2 (whose
    /// caller immediately appends the new entry and notifies).
    pub fn removePendingRemovalsFor(self: *State, node: *runtime.Instance, notify: bool) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const entry = self.entries.items[i];
            if (entry.pending_removal and entry.node() == node) {
                if (notify) {
                    self.remove(entry.id);
                } else {
                    _ = self.entries.orderedRemove(i);
                    self.revision +%= 1;
                    entry.previous_focus.release(self.owner, entry.focusSlot());
                    entry.source.release(self.owner, entry.sourceSlot());
                    entry.element.release(self.owner, entry.nodeSlot());
                    self.allocator.destroy(entry);
                }
                continue;
            }
            i += 1;
        }
    }

    fn recomputeLastModal(self: *State) void {
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

    /// The top layer gained or lost a member - a showing popover or picker,
    /// a modal dialog, a fullscreen element: CDP's DOM agents hear it
    /// (dom.inspector_probes; one load while none is enabled), as Blink's
    /// Document::AddToTopLayer and RemoveFromTopLayerImmediately call
    /// probe::TopLayerElementsChanged. Pins alone are no membership.
    pub fn membersChanged(self: *State) void {
        if (inspector_probes.active()) inspector_probes.topLayerElementsChanged(self.owner);
        // Top-layer membership changes :modal, :popover-open and :fullscreen
        // with no DOM mutation: wake step 16 when CSS transitions/animations
        // are declared so they start without relying on volatile styles.
        if (@import("style/engine.zig").declaresAnimations(self.owner)) @import("update_the_rendering.zig").requestFrame(self.owner);
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
            const was_member = entry.isTopLayerMember();
            defer if (was_member) self.membersChanged();
            if (self.last_modal == entry) self.recomputeLastModal();
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

    pub fn hasOpenDialog(self: *const State, dialog: *runtime.Instance) bool {
        for (self.open_dialogs.items) |entry| if (entry.element.get() == dialog) return true;
        return false;
    }

    pub fn addOpenDialog(self: *State, dialog: *runtime.Instance) !void {
        if (self.hasOpenDialog(dialog)) return;
        var id: usize = 0;
        while (true) : (id += 1) {
            var used = false;
            for (self.open_dialogs.items) |entry| if (entry.id == id) {
                used = true;
                break;
            };
            if (!used) break;
        }
        const entry = try self.allocator.create(OpenDialog);
        errdefer self.allocator.destroy(entry);
        entry.* = .{ .id = id };
        entry.slot_len = (try std.fmt.bufPrint(&entry.slot_name, "open_dialog:{d}", .{id})).len;
        try self.open_dialogs.append(self.allocator, entry);
        entry.element.take(self.owner, dialog, entry.slot());
    }

    pub fn removeOpenDialog(self: *State, dialog: *runtime.Instance) void {
        // Closing ends open-list membership, not the remembered gesture.
        // Light dismiss step 3 preserves the target while the list is empty;
        // step 6.2 clears it only after that guard. Removal releases its node
        // through a distinct marker; teardown releases any remaining hold.
        for (self.open_dialogs.items, 0..) |entry, index| {
            if (entry.element.get() != dialog) continue;
            _ = self.open_dialogs.orderedRemove(index);
            entry.element.release(self.owner, entry.slot());
            self.allocator.destroy(entry);
            return;
        }
    }

    pub fn lastOpenDialog(self: *const State) ?*runtime.Instance {
        if (self.open_dialogs.items.len == 0) return null;
        return self.open_dialogs.items[self.open_dialogs.items.len - 1].element.get();
    }

    // === Fullscreen 2 (the algorithms are html.fullscreen's) ===

    /// `node`'s entry while its fullscreen flag is set, or null.
    pub fn fullscreenEntry(self: *State, node: *runtime.Instance) ?*Entry {
        for (self.entries.items) |entry| {
            if (entry.fullscreen and entry.node() == node) return entry;
        }
        return null;
    }

    /// "Fullscreen an element" steps 3-5: set `node`'s fullscreen flag,
    /// "remove from the top layer immediately" given it, and "add to the top
    /// layer" given it - its fullscreen entry, moved to the end.
    pub fn addFullscreen(self: *State, node: *runtime.Instance) !*Entry {
        if (self.fullscreenEntry(node)) |entry| self.remove(entry.id);
        self.removePendingRemovalsFor(node, false);
        const entry = try self.pin(node);
        entry.fullscreen = true;
        self.membersChanged();
        return entry;
    }

    /// "Unfullscreen an element": unset its fullscreen, iframe fullscreen
    /// and keyboard lock flags, and remove it from the top layer
    /// immediately. Whether it had the flag.
    pub fn removeFullscreen(self: *State, node: *runtime.Instance) bool {
        const entry = self.fullscreenEntry(node) orelse return false;
        self.remove(entry.id);
        return true;
    }

    /// The document's fullscreen element: "the topmost element in the
    /// document's top layer whose fullscreen flag is set, if any, and null
    /// otherwise".
    pub fn fullscreenElement(self: *const State) ?*runtime.Instance {
        var i = self.entries.items.len;
        while (i != 0) {
            i -= 1;
            const entry = self.entries.items[i];
            if (entry.fullscreen) if (entry.node()) |node| return node;
        }
        return null;
    }

    /// How many elements in the top layer have their fullscreen flag set
    /// (one: a "simple fullscreen document").
    pub fn fullscreenCount(self: *const State) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (entry.fullscreen and entry.node() != null) count += 1;
        }
        return count;
    }

    /// "Append (type, element) to the list of pending fullscreen events" -
    /// an ordered set, so a tuple already in it is not added again.
    pub fn appendFullscreenEvent(self: *State, event_type: FullscreenEvent.Type, element: *runtime.Instance) !void {
        for (self.fullscreen_events.items) |event| {
            if (event.type == event_type and event.element.get() == element) return;
        }
        var id: usize = 0;
        while (true) : (id += 1) {
            var used = false;
            for (self.fullscreen_events.items) |event| if (event.id == id) {
                used = true;
                break;
            };
            if (!used) break;
        }
        const event = try self.allocator.create(FullscreenEvent);
        errdefer self.allocator.destroy(event);
        event.* = .{ .id = id, .type = event_type };
        event.slot_len = (try std.fmt.bufPrint(&event.slot_name, "fullscreen_event:{d}", .{id})).len;
        try self.fullscreen_events.append(self.allocator, event);
        event.element.take(self.owner, element, event.slot());
    }

    /// "Run the fullscreen steps" steps 1-2: "Let pendingEvents be
    /// document's list of pending fullscreen events" and "Empty" it. The
    /// events come back in order, OWNED by `allocator`, each element held by
    /// its TaskHold (taken before the list lets it go), which the caller
    /// releases once it fired the event. Out of memory empties the list all
    /// the same: those events are not fired.
    pub fn takeFullscreenEvents(self: *State, allocator: std.mem.Allocator) error{OutOfMemory}![]TakenFullscreenEvent {
        const taken = allocator.alloc(TakenFullscreenEvent, self.fullscreen_events.items.len) catch |err| {
            self.dropFullscreenEvents();
            return err;
        };
        for (self.fullscreen_events.items, taken) |event, *out| {
            out.* = .{ .type = event.type };
            if (event.element.get()) |element| out.hold.take(element);
        }
        self.dropFullscreenEvents();
        return taken;
    }

    fn dropFullscreenEvents(self: *State) void {
        for (self.fullscreen_events.items) |event| {
            event.element.release(self.owner, event.slot());
            self.allocator.destroy(event);
        }
        self.fullscreen_events.clearRetainingCapacity();
    }

    pub fn setDialogPointerdownTarget(self: *State, dialog: ?*runtime.Instance) void {
        const slot: engine.TracedSlot = .{ .name = "open_dialog:pointerdown" };
        self.dialog_pointerdown_target_removed = false;
        self.dialog_pointerdown_target.release(self.owner, slot);
        if (dialog) |node| self.dialog_pointerdown_target.take(self.owner, node, slot);
    }

    pub fn removeDialogPointerdownTarget(self: *State, dialog: *runtime.Instance) void {
        if (self.dialog_pointerdown_target.get() != dialog) return;
        self.setDialogPointerdownTarget(null);
        // Lifetime form of the spec's retained target: an outside release
        // must not match null and dismiss another dialog. Chrome 156 and
        // Firefox 158 agree (tmp/probes/q47-remove/RESULT.md, 2026-10-29).
        // Identity is lost across removal: if A is reinserted, another dialog
        // opens after it, and pointerup lands inside A, this marker cannot
        // match A as the spec's retained node would (Q47 addendum).
        self.dialog_pointerdown_target_removed = true;
    }

    /// Every node the top layer holds for script - each entry's element, its
    /// source and saved focus, the open dialogs, the pointerdown targets and
    /// the hint parent - named to the collector from the Document's trace
    /// (the wrapper redesign's P6, design 4.4 "Holders"; Blink's Document
    /// traces top_layer_elements_ and its popover and dialog pointers). In
    /// the collector's atomic pause: reads only.
    pub fn trace(self: *const State, tracer: *engine.Tracer) void {
        for (self.entries.items) |entry| {
            entry.element.trace(tracer);
            entry.source.trace(tracer);
            entry.previous_focus.trace(tracer);
        }
        for (self.open_dialogs.items) |dialog| dialog.element.trace(tracer);
        for (self.fullscreen_events.items) |event| event.element.trace(tracer);
        self.pointerdown_target.trace(tracer);
        self.hint_parent.trace(tracer);
        self.dialog_pointerdown_target.trace(tracer);
    }

    pub fn deinit(self: *State) void {
        self.setDialogPointerdownTarget(null);
        for (self.open_dialogs.items) |entry| {
            entry.element.release(self.owner, entry.slot());
            self.allocator.destroy(entry);
        }
        self.open_dialogs.deinit(self.allocator);
        for (self.fullscreen_events.items) |event| {
            event.element.release(self.owner, event.slot());
            self.allocator.destroy(event);
        }
        self.fullscreen_events.deinit(self.allocator);
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
        self.dialog_pointerdown_target_removed = false;
        self.releaseOrphanHold(&self.dialog_pointerdown_target, .{ .name = "open_dialog:pointerdown" }, owner_live);
        for (self.open_dialogs.items) |entry| {
            self.releaseOrphanHold(&entry.element, entry.slot(), owner_live);
            self.allocator.destroy(entry);
        }
        self.open_dialogs.deinit(self.allocator);
        for (self.fullscreen_events.items) |event| {
            self.releaseOrphanHold(&event.element, event.slot(), owner_live);
            self.allocator.destroy(event);
        }
        self.fullscreen_events.deinit(self.allocator);
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
var access: Hook(?Access) = .init(null);

pub fn install(implementation: Access) void {
    access.install(implementation);
}

pub fn ofDocument(document: *runtime.Instance, create: bool) !?*State {
    return (access.get() orelse return error.NotSupported).get(document, create);
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

/// Read-only: whether `document` currently has any entries in `pending top
/// layer removals`. Never allocates top-layer state.
pub fn hasPendingRemovals(document: *runtime.Instance) bool {
    const state = (ofDocument(document, false) catch null) orelse return false;
    for (state.entries.items) |entry| {
        if (entry.pending_removal) return true;
    }
    return false;
}

/// HTML 8.1.7.3 step 23: CSS Position 4 §3.3 "process top layer removals"
/// given `document` (Blink: `Document::RemoveFinishedTopLayerElements`).
/// Read-only when `document` has no top-layer state or no pending removals
/// (0 allocations on idle frames).
pub fn processTopLayerRemovals(document: *runtime.Instance, frame: @import("update_the_rendering.zig").Frame) void {
    _ = frame;
    const state = (ofDocument(document, false) catch null) orelse return;
    // Fast read-only check: avoid any work when nothing is pending removal.
    var stack_ids: [32]usize = undefined;
    var stack_len: usize = 0;
    var overflow: std.ArrayListUnmanaged(usize) = .empty;
    defer overflow.deinit(state.allocator);

    for (state.entries.items) |entry| {
        if (!entry.pending_removal) continue;
        if (stack_len < stack_ids.len) {
            stack_ids[stack_len] = entry.id;
            stack_len += 1;
        } else {
            overflow.append(state.allocator, entry.id) catch continue;
        }
    }
    if (stack_len == 0) return;

    const style_engine = @import("style/engine.zig");
    // Position 4 §3.3 step 1: "For each element el in doc's pending top layer
    // removals: if el's computed value of overlay is none, or el is not
    // rendered, remove from the top layer immediately el."
    for (stack_ids[0..stack_len]) |id| finishIfReady(state, style_engine, id);
    for (overflow.items) |id| finishIfReady(state, style_engine, id);
}

fn finishIfReady(state: *State, comptime style_engine: type, id: usize) void {
    const entry = state.byId(id) orelse return;
    if (!entry.pending_removal) return;
    const element = entry.node() orelse {
        state.remove(id);
        return;
    };
    const rendered = style_engine.isBeingRendered(element) catch false;
    const overlay_is_none = if (rendered) blk: {
        const held = (style_engine.computedStyle(element, null) catch null) orelse break :blk true;
        defer held.release();
        break :blk held.style.keyword(.overlay) == .none;
    } else true;
    if (!rendered or overlay_is_none) state.remove(id);
}
