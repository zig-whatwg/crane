//! HTML 7.4.6.5 "persisted history entry state", step 2 of "save persisted
//! state" and of "restore persisted state": the values of form controls,
//! which HTML suggests and leaves implementation-defined. The algorithm is
//! Blink's FormController (core/html/forms/form_controller.cc), whose keys
//! and per-control states WebKit's FormController shares:
//!
//!   - SAVE (Blink DocumentState::ToStateVector, which HistoryItem keeps): every
//!     input, select and textarea of the document, in tree order, that may
//!     save its state, appends (name, type, values) under its form key;
//!   - RESTORE (Blink RestoreAllControlsInDocumentOrder): every such control,
//!     in tree order - a form's controls together, when its first one comes -
//!     takes the first state queued for its form key, name and type, and
//!     restores it unless it is disabled, readonly or edited by the user
//!     already. A restore fires no input or change event (HTML 7.4.6.5's
//!     note): it sets what script's IDL setters set - the value (its dirty
//!     value flag), the checkedness, an option's selectedness and dirtiness -
//!     and those fire none.
//!
//! The controls are reached through their interfaces only; the states and
//! their owner are dom.saved_form_state's. When: html.navigation saves at
//! "activate history entry" step 1, a back/forward traversal gives the new
//! document the entry's state, and Document restores after its parser
//! finishes (a task: Blink Document::SetParsingState -> ScheduleRestore) or,
//! at the latest, right after its window's load event, before pageshow
//! (Blink LocalDOMWindow::DispatchLoadAndPageshowEvents -> RestoreImmediately).
//!
//! Not saved, as in Blink: password and hidden inputs (their input types'
//! ShouldSaveAndRestoreFormControlState is false), a control whose
//! autocomplete attribute or whose form's is "off". A file input saves no
//! value: Blink restores the files a user chose (FileInputType::
//! RestoreFormControlState); Crane's file inputs are filled only by a
//! user's choice. TODO(form-associated custom elements): their
//! formStateRestoreCallback (HTML 4.13.7.3, "restore") once the reaction
//! exists - Blink saves and restores them through ElementInternals.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#persisted-user-state-restoration

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const associated = @import("../form_associated.zig");
const options = @import("options.zig");
const selected_content = @import("selected_content.zig");

const Instance = runtime.Instance;
const Allocator = std.mem.Allocator;
const Saved = dom.saved_form_state.Saved;

/// The form key of a control with no form owner for state (Blink's).
const no_owner = "No owner";

/// A control of the document, and what it saves and restores under.
const Control = struct {
    element: *Instance,
    generation: u64,
    kind: Kind,
    /// Its owner form for state (Blink OwnerFormForState): null when it has
    /// none, or a form attribute.
    form: ?*Instance,

    const Kind = enum { input, select, textarea };

    fn live(self: Control) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.generation;
    }
};

/// The document's inputs, selects and textareas, in tree order (Blink
/// DocumentState::GetControlList: not into shadow trees).
fn collectControls(allocator: Allocator, document: *Instance, out: *std.ArrayList(Control)) Allocator.Error!void {
    var node = interfaces.Node.get_firstChild(document) catch null;
    while (node) |current| : (node = associated.nextInTree(current, document, false)) {
        const kind: Control.Kind = if (associated.isInput(current))
            .input
        else if (associated.isSelect(current))
            .select
        else if (associated.isTextArea(current))
            .textarea
        else
            continue;
        // "Assume controls with form attribute have no owners because we
        // restore state during parsing and form owners of such controls might
        // be indeterminate" (Blink OwnerFormForState).
        const form = if (associated.hasAttribute(current, "form")) null else associated.formOwner(current);
        try out.append(allocator, .{ .element = current, .generation = runtime.SlabAllocator.generationOf(current), .kind = kind, .form = form });
    }
}

/// A copy, owned by `allocator`, of an IDL getter's string, which `element`'s
/// realm allocated.
fn ownedString(allocator: Allocator, element: *Instance, value: runtime.DOMString) Allocator.Error![]u8 {
    var owned = value;
    defer owned.deinit(element.ctx.allocator);
    return allocator.dupe(u8, owned.asSlice());
}

fn attributeIsOff(allocator: Allocator, element: *Instance) bool {
    const value = associated.attributeValue(allocator, element, "autocomplete") catch return false;
    const text = value orelse return false;
    defer allocator.free(text);
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, text, " \t\n\r\x0c"), "off");
}

/// The control's type as its IDL `type` reads it (Blink ControlType).
fn typeOf(allocator: Allocator, control: Control) Allocator.Error![]u8 {
    const value = switch (control.kind) {
        .input => interfaces.HTMLInputElement.get_type(control.element),
        .select => interfaces.HTMLSelectElement.get_type(control.element),
        .textarea => interfaces.HTMLTextAreaElement.get_type(control.element),
    } catch return allocator.dupe(u8, "");
    return ownedString(allocator, control.element, value);
}

/// Its name attribute's value, or "".
fn nameOf(allocator: Allocator, control: Control) Allocator.Error![]u8 {
    return (associated.attributeValue(allocator, control.element, "name") catch null) orelse try allocator.dupe(u8, "");
}

/// Blink HTMLFormControlElementWithState::ShouldSaveAndRestoreFormControlState
/// and its input types' (password and hidden: false).
fn mayPersist(allocator: Allocator, control: Control, kind: []const u8) bool {
    if (!control.live()) return false;
    if (!(interfaces.Node.get_isConnected(control.element) catch false)) return false;
    if (control.kind == .input and (std.mem.eql(u8, kind, "password") or std.mem.eql(u8, kind, "hidden"))) return false;
    if (associated.formOwner(control.element)) |form| if (attributeIsOff(allocator, form)) return false;
    return !attributeIsOff(allocator, control.element);
}

/// Form keys, one per form, made in the order they are first asked for
/// (Blink FormKeyGenerator): "<signature> #<n>", n counting the forms with
/// that signature.
const KeyGenerator = struct {
    allocator: Allocator,
    forms: std.ArrayList(struct { form: *Instance, key: []u8 }) = .empty,
    // tombstones: short-lived - one save or one restore pass, in its arena; nothing is removed but a failed insert.
    counts: std.StringHashMapUnmanaged(u32) = .empty,

    fn deinit(self: *KeyGenerator) void {
        for (self.forms.items) |entry| self.allocator.free(entry.key);
        self.forms.deinit(self.allocator);
        var it = self.counts.keyIterator();
        while (it.next()) |name| self.allocator.free(name.*);
        self.counts.deinit(self.allocator);
    }

    fn key(self: *KeyGenerator, control: Control, controls: []const Control) Allocator.Error![]const u8 {
        const form = control.form orelse return no_owner;
        for (self.forms.items) |entry| if (entry.form == form) return entry.key;
        const signature = try formSignature(self.allocator, form, controls);
        defer self.allocator.free(signature);
        const slot = try self.counts.getOrPut(self.allocator, signature);
        if (!slot.found_existing) {
            slot.key_ptr.* = self.allocator.dupe(u8, signature) catch |err| {
                self.counts.removeByPtr(slot.key_ptr);
                return err;
            };
            slot.value_ptr.* = 0;
        }
        const index = slot.value_ptr.*;
        slot.value_ptr.* += 1;
        const made = try std.fmt.allocPrint(self.allocator, "{s} #{d}", .{ signature, index });
        errdefer self.allocator.free(made);
        try self.forms.append(self.allocator, .{ .form = form, .key = made });
        return made;
    }
};

/// Blink FormSignature: the form's action URL without its query (when it
/// has an action attribute), then " [" and the names of its first two
/// named controls that save state, each followed by a space, then "]".
fn formSignature(allocator: Allocator, form: *Instance, controls: []const Control) Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (associated.hasAttribute(form, "action")) {
        if (interfaces.HTMLFormElement.get_action(form)) |url| {
            defer form.ctx.allocator.free(url);
            // "Remove the query part because it might contain volatile
            // parameters such as a session key" (the fragment stays).
            const query = std.mem.indexOfScalar(u8, url, '?');
            const fragment = std.mem.indexOfScalar(u8, url, '#');
            if (query != null and (fragment == null or query.? < fragment.?)) {
                try out.appendSlice(allocator, url[0..query.?]);
                if (fragment) |f| try out.appendSlice(allocator, url[f..]);
            } else try out.appendSlice(allocator, url);
        } else |_| {}
    }
    try out.appendSlice(allocator, " [");
    var named: usize = 0;
    for (controls) |control| {
        if (named == 2) break;
        if (control.form != form) continue;
        const name = try nameOf(allocator, control);
        defer allocator.free(name);
        if (name.len == 0) continue;
        named += 1;
        try out.appendSlice(allocator, name);
        try out.append(allocator, ' ');
    }
    try out.append(allocator, ']');
    return out.toOwnedSlice(allocator);
}

/// What `control` saves (Blink SaveFormControlState), owned by `allocator`.
fn saveControl(allocator: Allocator, control: Control, kind: []const u8) (Allocator.Error || error{Unreadable})![]const []const u8 {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (values.items) |v| allocator.free(v);
        values.deinit(allocator);
    }
    switch (control.kind) {
        .input => {
            if (std.mem.eql(u8, kind, "checkbox") or std.mem.eql(u8, kind, "radio")) {
                // BaseCheckableInputType: its checkedness, always.
                const checked = interfaces.HTMLInputElement.get_checked(control.element) catch return error.Unreadable;
                try values.append(allocator, try allocator.dupe(u8, if (checked) "on" else "off"));
            } else if (!std.mem.eql(u8, kind, "file")) {
                // InputTypeView: the value, when it is not the default one.
                const value = try ownedString(allocator, control.element, interfaces.HTMLInputElement.get_value(control.element) catch return error.Unreadable);
                errdefer allocator.free(value);
                const default = try ownedString(allocator, control.element, interfaces.HTMLInputElement.get_defaultValue(control.element) catch return error.Unreadable);
                defer allocator.free(default);
                if (std.mem.eql(u8, value, default)) allocator.free(value) else try values.append(allocator, value);
            }
        },
        .textarea => {
            // Blink HTMLTextAreaElement: the value when the dirty value flag
            // is set - which a value equal to the default restores to itself.
            const value = try ownedString(allocator, control.element, interfaces.HTMLTextAreaElement.get_value(control.element) catch return error.Unreadable);
            errdefer allocator.free(value);
            const default = try ownedString(allocator, control.element, interfaces.HTMLTextAreaElement.get_defaultValue(control.element) catch return error.Unreadable);
            defer allocator.free(default);
            if (std.mem.eql(u8, value, default)) allocator.free(value) else try values.append(allocator, value);
        },
        .select => {
            // Blink HTMLSelectElement: each selected option's value and its
            // index - the first one alone in a single select.
            var list: std.ArrayListUnmanaged(*Instance) = .empty;
            defer list.deinit(allocator);
            options.collect(control.element, allocator, &list) catch return error.Unreadable;
            const multiple = associated.hasAttribute(control.element, "multiple");
            for (list.items, 0..) |option, index| {
                if (!(interfaces.HTMLOptionElement.get_selected(option) catch false)) continue;
                const value = try ownedString(allocator, option, interfaces.HTMLOptionElement.get_value(option) catch return error.Unreadable);
                values.append(allocator, value) catch |err| {
                    allocator.free(value);
                    return err;
                };
                try values.append(allocator, try std.fmt.allocPrint(allocator, "{d}", .{index}));
                if (!multiple) break;
            }
        },
    }
    return values.toOwnedSlice(allocator);
}

/// "Save persisted state" step 2: `document`'s control states, encoded
/// (dom.saved_form_state.encode) and owned by `allocator`; null when it has
/// no control that saves one.
pub fn save(allocator: Allocator, document: *Instance) Allocator.Error!?[]u8 {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var controls: std.ArrayList(Control) = .empty;
    try collectControls(arena, document, &controls);
    if (controls.items.len == 0) return null;
    var keys: KeyGenerator = .{ .allocator = arena };
    const Group = struct { key: []const u8, controls: std.ArrayList(dom.saved_form_state.ControlState) = .empty };
    var groups: std.ArrayList(Group) = .empty;
    for (controls.items) |control| {
        const kind = try typeOf(arena, control);
        if (!mayPersist(arena, control, kind)) continue;
        const values = saveControl(arena, control, kind) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.Unreadable => continue,
        };
        const key = try keys.key(control, controls.items);
        const group = for (groups.items) |*g| {
            if (std.mem.eql(u8, g.key, key)) break g;
        } else blk: {
            try groups.append(arena, .{ .key = key });
            break :blk &groups.items[groups.items.len - 1];
        };
        try group.controls.append(arena, .{ .name = try nameOf(arena, control), .type = kind, .values = values });
    }
    const forms = try arena.alloc(dom.saved_form_state.FormState, groups.items.len);
    for (groups.items, forms) |group, *form| form.* = .{ .key = group.key, .controls = group.controls.items };
    return dom.saved_form_state.encode(allocator, forms);
}

/// The option of `list` whose value is `value`, searched from `from` to
/// `to` (Blink SearchOptionsForValue).
fn optionWithValue(allocator: Allocator, list: []const *Instance, value: []const u8, from: usize, to: usize) ?usize {
    var index = from;
    while (index < @min(to, list.len)) : (index += 1) {
        const own = ownedString(allocator, list[index], interfaces.HTMLOptionElement.get_value(list[index]) catch continue) catch continue;
        defer allocator.free(own);
        if (std.mem.eql(u8, own, value)) return index;
    }
    return null;
}

fn optionMatches(allocator: Allocator, list: []const *Instance, index_text: []const u8, value: []const u8) ?usize {
    const index = std.fmt.parseInt(usize, index_text, 10) catch return null;
    if (index >= list.len) return null;
    return if (optionWithValue(allocator, list, value, index, index + 1) != null) index else null;
}

/// Blink HTMLSelectElement::RestoreFormControlState: each saved option
/// selected again - the one at its saved index when its value still
/// matches, else the first with that value - and, with nothing to select in
/// a single select, its default selection; then its selectedcontent updated
/// at once (Blink UpdateAllSelectedcontentsSingle), before the next control
/// is restored (selectedcontent-restore.optional.html: a control inside the
/// selectedcontent goes with its old contents).
fn restoreSelect(allocator: Allocator, select: *Instance, values: []const []const u8) !void {
    var list: std.ArrayListUnmanaged(*Instance) = .empty;
    defer list.deinit(allocator);
    try options.collect(select, allocator, &list);
    if (list.items.len == 0 or values.len < 2) return;
    // SelectOption(nullptr, kDeselectOtherOptionsFlag).
    for (list.items) |option| try interfaces.HTMLOptionElement.set_selected(option, false);
    if (!associated.hasAttribute(select, "multiple")) {
        const found = optionMatches(allocator, list.items, values[1], values[0]) orelse
            optionWithValue(allocator, list.items, values[0], 0, list.items.len);
        if (found) |index| {
            try interfaces.HTMLOptionElement.set_selected(list.items[index], true);
        } else {
            // "If we couldn't restore any option, then reset to default
            // selection instead of leaving this select in a broken state".
            dom.form_controls.reset(select);
        }
        try selected_content.updateAll(select);
        return;
    }
    var start: usize = 0;
    var at: usize = 0;
    while (at + 1 < values.len) : (at += 2) {
        const found = optionMatches(allocator, list.items, values[at + 1], values[at]) orelse
            optionWithValue(allocator, list.items, values[at], start, list.items.len) orelse
            optionWithValue(allocator, list.items, values[at], 0, start) orelse continue;
        try interfaces.HTMLOptionElement.set_selected(list.items[found], true);
        start = found + 1;
    }
}

/// Blink FormController::RestoreControlStateInternal for one control.
fn restoreControl(allocator: Allocator, saved: *Saved, keys: *KeyGenerator, controls: []const Control, control: Control) !void {
    const kind = try typeOf(allocator, control);
    defer allocator.free(kind);
    // "We don't save state of a control with
    // ShouldSaveAndRestoreFormControlState() == false. But we need to skip
    // restoring process too because a control in another form might have
    // the same pair of name and type and saved its state."
    if (!mayPersist(allocator, control, kind)) return;
    const name = try nameOf(allocator, control);
    defer allocator.free(name);
    const values = saved.take(try keys.key(control, controls), name, kind) orelse return;
    if (values.len == 0) return;
    if (associated.isDisabled(control.element) or associated.hasAttribute(control.element, "readonly")) return;
    // "If a user already edited the control, we should not overwrite it."
    if (dom.form_controls.userValidity(control.element)) return;
    switch (control.kind) {
        .input => {
            if (std.mem.eql(u8, kind, "checkbox") or std.mem.eql(u8, kind, "radio")) {
                try interfaces.HTMLInputElement.set_checked(control.element, std.mem.eql(u8, values[0], "on"));
            } else if (!std.mem.eql(u8, kind, "file")) {
                try interfaces.HTMLInputElement.set_value(control.element, runtime.DOMString.initInterned(values[0]));
            }
        },
        .textarea => try interfaces.HTMLTextAreaElement.set_value(control.element, runtime.DOMString.initInterned(values[0])),
        .select => try restoreSelect(allocator, control.element, values),
    }
}

/// "Restore persisted state" step 2 (Blink
/// FormController::RestoreAllControlsInDocumentOrder): once, for a document
/// a traversal gave states, while it is fully active. Its states go after,
/// taken or not.
pub fn restoreAll(document: *Instance) void {
    const saved = dom.saved_form_state.of(document) orelse return;
    if (saved.restored_all) return;
    // "if (!document_->IsActive() ...) return": a document no window shows
    // keeps its states for a later call.
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return;
    saved.restored_all = true;
    const allocator = document.ctx.allocator;
    restoreAllWith(allocator, document, saved) catch |err| std.log.scoped(.forms).debug("form state restore stopped: {s}", .{@errorName(err)});
    dom.saved_form_state.release(document);
}

fn restoreAllWith(allocator: Allocator, document: *Instance, saved: *Saved) !void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // A copy: restoring a select with a selectedcontent changes the DOM
    // (Blink copies its control list for the same reason). Each element's
    // generation is checked before use; a restore runs no script.
    var controls: std.ArrayList(Control) = .empty;
    try collectControls(arena, document, &controls);
    var keys: KeyGenerator = .{ .allocator = arena };
    // Every key made before any restore changes the DOM, as Blink's
    // generator keeps the key it first made for a form - and in the order
    // the save made them: a form's key is asked for by its first control
    // that saves a state (Blink calls FormKey only past
    // ShouldSaveAndRestoreFormControlState, in both directions).
    for (controls.items) |control| {
        const kind = try typeOf(arena, control);
        if (mayPersist(arena, control, kind)) _ = try keys.key(control, controls.items);
    }
    var finished: std.ArrayList(*Instance) = .empty;
    for (controls.items) |control| {
        const form = control.form orelse {
            try restoreControl(arena, saved, &keys, controls.items, control);
            continue;
        };
        if (std.mem.indexOfScalar(*Instance, finished.items, form) != null) continue;
        try finished.append(arena, form);
        // Blink RestoreControlStateIn(form): the form's controls together.
        for (controls.items) |member| {
            if (member.form == form) try restoreControl(arena, saved, &keys, controls.items, member);
        }
    }
}

/// Whether `document` holds states a traversal gave it that wait for its
/// controls (Blink FormController::HasControlStates).
pub fn hasStates(document: *Instance) bool {
    const saved = dom.saved_form_state.of(document) orelse return false;
    return !saved.restored_all;
}

/// "Restore persisted state" for the document a back/forward traversal
/// made: `bytes` - its entry's persisted user state - become the states for
/// its new controls (Blink Document::SetStateForNewControls). They are
/// restored in a task once its parser has finished (`scheduleRestore`: now,
/// when it has), or at the latest right after its window's load event.
pub fn setStateForNewControls(document: *Instance, bytes: []const u8) void {
    dom.saved_form_state.set(document, bytes) catch |err| {
        std.log.scoped(.forms).debug("form states not kept: {s}", .{@errorName(err)});
        return;
    };
    const readiness = interfaces.Document.get_readyState(document) catch return;
    if (readiness != ._loading_) scheduleRestore(document);
}

const RestoreTask = struct {
    pub const held_count: usize = 1;

    pub fn steps(_: *RestoreTask, held: []const dom.node_holds.TaskHold) void {
        const document = held[0].get() orelse return;
        restoreAll(document);
    }
};

/// The document's parser has finished: restore its controls in a task
/// (Blink Document::SetParsingState(kFinishedParsing) ->
/// FormController::ScheduleRestore, a kInternalLoading task) - when a
/// traversal gave it states.
pub fn scheduleRestore(document: *Instance) void {
    if (!hasStates(document)) return;
    _ = dom.node_holds.ElementTask(RestoreTask).queue(.{document}, .{});
}
