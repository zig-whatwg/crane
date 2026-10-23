//! Implementation for HTMLTextAreaElement interface

const std = @import("std");
const runtime = @import("runtime");
const forms = @import("html").forms;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLTextAreaElement = interfaces.HTMLTextAreaElement;

// A Text node's data lives in CharacterData's inline/heap storage, NOT in
// Node.InternalState.node_value - that field stays null for parsed and created
// text alike, so reading it yields "" for every textarea. It is read in place
// through dom.character_data, as Node.zig's collectTextContent reads it.
const form_associated = @import("html").form_associated;
const dom = @import("dom");
const log = std.log.scoped(.textarea);

pub const State = HTMLTextAreaElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Per-instance state, stored BY VALUE in a map of this module's own rather than
/// through `utils.InstanceRegistry`.
///
/// `InstanceRegistry.createIn` takes a block out of the process-wide
/// `ArenaAllocator` and hands it back on `remove`, so the block lands on a shared
/// size-class free list and is reissued to the next caller of that size. Adding
/// that alloc/free pair to an element the PARSER creates destabilised the DOM:
/// measured on the 5-file shard of html/semantics/forms/the-textarea-element/
/// containing textarea-minlength.html, 8 runs each, same tree, one file differing
///
///     textarea stubs (no state at all)          0 / 8 runs aborted
///     state via InstanceRegistry.createIn     1-7 / 8 runs aborted
///     state in this map (no arena block)        0 / 8 runs aborted
///
/// The abort was a SIGABRT from a SEGV in `Node.getFirstChild`, reading a
/// corrupted `node_base` under `Document.getElementsByTagName` in a LATER test
/// file - a block that had moved on being read or written through something's
/// stale view of it.
///
/// Storing the state inline in the map removes the arena from the picture
/// entirely: the map owns its own memory, so a stale entry can only ever give a
/// wrong answer, never corrupt a neighbour. The map is keyed on the instance
/// address and is its Browser's (a side table of its runtime.BrowserScope).
///
/// TODO: the same alloc/free pair is in HTMLInputElement.zig, HTMLFormElement.zig
/// and ~17 other impls. This is a local workaround, not the fix; the fix is in
/// whatever holds a block past `ArenaAllocator.destroy`.
const StateMap = struct {
    /// One Browser's table - a side table of its runtime.BrowserScope, so
    /// its entries are its own and end with it (instances B1) - with its
    /// tombstones kept in check: every textarea script writes to enters it at
    /// an address it has usually never seen and leaves it at its teardown
    /// (dom.InstanceStateMap; src/infra/tombstones.zig).
    const Table = dom.InstanceStateMap(InternalState);

    /// `instance`'s Browser's table, made on first use.
    fn ensure(instance: *runtime.Instance) !*Table {
        return runtime.BrowserScope.ofInstance(instance).table(.textarea_states, Table);
    }

    /// `instance`'s Browser's table, if it has one.
    fn existing(instance: *runtime.Instance) ?*Table {
        return runtime.BrowserScope.ofInstance(instance).existingTable(.textarea_states, Table);
    }

    fn put(instance: *runtime.Instance, value: InternalState) !void {
        try (try ensure(instance)).put(instance, value);
    }

    /// BORROWED until the next `put` or `getOrPut`, which may move every
    /// entry (a growth or a rehash).
    fn get(instance: *runtime.Instance) ?*InternalState {
        return (existing(instance) orelse return null).get(instance);
    }

    /// The entry for `instance`, creating a default one if this is the first
    /// write. Nothing is stored until something assigns, so a parser-created
    /// element that script never touches costs nothing at all. BORROWED as
    /// `get`'s is.
    fn getOrPut(instance: *runtime.Instance) !*InternalState {
        return (try ensure(instance)).getOrPut(instance);
    }

    fn remove(instance: *runtime.Instance) ?InternalState {
        return (existing(instance) orelse return null).remove(instance);
    }

    /// Forget every one of `scope`'s entries, each state deinit'd first.
    fn sweep(scope: *runtime.BrowserScope) void {
        const table = scope.existingTable(.textarea_states, Table) orelse return;
        table.clear();
    }
};

/// dom.teardown_sweeps: no entry outlives its browser. A textarea in its
/// document is deinit'd by its tree; what is left at the end is an orphan's
/// (none, over 2,881 files at leaks3's tip), and init frees an entry it finds
/// at a new textarea's address - which must never be one whose raw value
/// came from an allocator that has gone with an earlier browser.
pub fn cleanupAllRemainingInternal(scope: *runtime.BrowserScope) void {
    StateMap.sweep(scope);
}

fn isTextArea(instance: *runtime.Instance) bool {
    return form_associated.isTextArea(instance);
}

/// dom.form_controls: "The reset algorithm for textarea elements is to set
/// the user validity and dirty value flag back to false, and set the raw
/// value of element to its child text content."
fn resetAlgorithm(instance: *runtime.Instance) void {
    const internal = StateMap.get(instance) orelse return;
    // HTML 4.10.11 reset: custom validity and its object are not reset.
    if (internal.raw_value) |value| if (internal.allocator) |allocator| allocator.free(value);
    internal.raw_value = null;
    internal.last_user_edit = false;
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-textarea-raw-value
///
/// `value` is element state with a dirty value flag, exactly like
/// `input.value`: it starts out tracking the element's CHILD TEXT CONTENT and
/// detaches permanently once anything assigns to it.
///
///     <textarea>a</textarea>        .value -> "a"   (tracking the children)
///     el.textContent = "b";          .value -> "b"   (still tracking)
///     el.value = "c";                .value -> "c"   (now dirty)
///     el.textContent = "d";          .value -> "c"   (children no longer win)
///                                    .defaultValue -> "d"
///
/// Dirtiness is encoded as the optional being non-null, so a set flag with no
/// value behind it is unrepresentable.
///
/// The stored string is the RAW value. `value` returns the API value, which is
/// the raw value with CRLF and lone CR normalised to LF - so
/// `el.value = "a\r\nb"` reads back "a\nb", which
/// `value-defaultValue-textContent.html` asserts in two places.
pub const InternalState = struct {
    validation: forms.Validation = .{},
    labels: form_associated.LabelsCache = .{},
    /// Owned by `allocator`. Non-null means the dirty value flag is set.
    raw_value: ?[]u8 = null,
    last_user_edit: bool = false,
    /// The allocator raw_value came from, recorded with it: final
    /// teardown's sweep has no element to ask.
    allocator: ?std.mem.Allocator = null,

    /// The selection or text entry cursor, in UTF-16 code units of the API
    /// value (§ 4.10.20); children changed steps persist clamping when the
    /// clean API value shrinks, so later growth cannot restore old offsets.
    selection: form_associated.TextSelection = .{},
    /// Selection API: this control's has-scheduled-selectionchange-event flag.
    selectionchange_scheduled: bool = false,
    /// Select event tasks still queued (form_associated.queueSelectEvent).
    pending_select_tasks: u32 = 0,

    /// Releases what the state OWNS. Deliberately does not null the field
    /// afterwards: the block is handed back to the arena immediately, so the
    /// write would be pointless, and a write through a registry pointer is the
    /// one thing worth not doing on a teardown path.
    pub fn deinit(self: *InternalState) void {
        if (self.allocator) |allocator| self.validation.deinit(allocator);
        if (self.raw_value) |v| {
            if (self.allocator) |a| a.free(v);
        }
    }

    fn setRawValue(self: *InternalState, allocator: std.mem.Allocator, value: []const u8) !void {
        const copy = try allocator.dupe(u8, value);
        // Free AFTER the new copy succeeds, so a failed allocation leaves the
        // old value intact rather than clearing it.
        if (self.raw_value) |old| {
            if (self.allocator) |a| a.free(old);
        }
        self.raw_value = copy;
        self.allocator = allocator;
        self.last_user_edit = false;
    }
};

fn validationState(instance: *runtime.Instance) !*forms.Validation {
    const internal = try StateMap.getOrPut(instance);
    if (internal.allocator == null) internal.allocator = instance.ctx.allocator;
    return &internal.validation;
}

fn constraintFlags(instance: *runtime.Instance) forms.ValidityFlags {
    const internal = StateMap.get(instance);
    var flags = forms.ValidityFlags{ .customError = if (internal) |state| !state.validation.custom_error.isEmpty() else false };
    const value = currentApiValue(instance) catch return flags;
    defer instance.ctx.allocator.free(value);
    // HTML 4.10.11: required, mutable, and an empty API value.
    flags.valueMissing = form_associated.hasAttribute(instance, "required") and
        !form_associated.isDisabled(instance) and !form_associated.hasAttribute(instance, "readonly") and value.len == 0;
    if (internal) |state| if (state.last_user_edit) {
        // HTML 4.10.19.3–4: dirty and last changed by a user edit. Count
        // normalized API newlines, not the raw CRLF pair.
        const length = form_associated.utf16Length(value);
        const maximum = interfaces.HTMLTextAreaElement.get_maxLength(instance) catch -1;
        const minimum = interfaces.HTMLTextAreaElement.get_minLength(instance) catch -1;
        flags.tooLong = maximum >= 0 and length > @as(u32, @intCast(maximum));
        flags.tooShort = value.len != 0 and minimum >= 0 and length < @as(u32, @intCast(minimum));
    };
    return flags;
}

fn editorText(instance: *runtime.Instance) !runtime.DOMString {
    // HTML 4.10.20: selection offsets refer to the API value. Editing must
    // splice that same normalized string, including clean child text content.
    return runtime.DOMString.initOwned(try currentApiValue(instance));
}

fn userEdit(instance: *runtime.Instance, edit: dom.form_controls.UserEdit) !void {
    const internal = try StateMap.getOrPut(instance);
    try internal.setRawValue(instance.ctx.allocator, edit.text);
    // HTML 4.10.19.3–4: script value/setRangeText writes clear this marker.
    internal.last_user_edit = true;
    const previous_selection = internal.selection;
    internal.selection = .{ .start = edit.selection_start, .end = edit.selection_end, .direction = .none };
    // Selection API selectionchange: user edits also notify an extent or
    // direction change, coalescing through this control's existing flag.
    if (!std.meta.eql(previous_selection, internal.selection))
        dom.selection.scheduleTextControlSelectionchange(instance, &selectionchangeScheduled) catch {};
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The steps other code runs on textareas (each idempotent).
    dom.form_controls.install(.{ .is = &isTextArea, .reset = &resetAlgorithm, .validity_flags = &constraintFlags, .user_edit = &userEdit, .editor_text = &editorText });
    dom.teardown_sweeps.install(.element_types, &cleanupAllRemainingInternal);
    dom.cloning_steps.install(&cloningSteps);
    dom.mutation.registerChildrenChangedCallback(&childrenChangedSteps) catch |err| {
        log.warn("textarea children changed steps not registered: {}", .{err});
    };
}

/// HTML 4.10.11 updates a clean raw value from child text on each mutation.
/// 4.10.20's relevant-value-change steps 1.1–2 clamp the selection/cursor
/// immediately, including the empty interval of a replace-all operation.
fn childrenChangedSteps(parent: *dom.NodeBase, _: dom.mutation.ChildrenChange) void {
    if (parent.node_type != 1) return;
    const instance_ptr = dom.instance_bridge.getInstance(parent) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    if (!isTextArea(instance)) return;
    const internal = StateMap.get(instance) orelse return;
    if (internal.raw_value != null or (internal.selection.start == 0 and internal.selection.end == 0)) return;
    const value = currentApiValue(instance) catch return;
    defer instance.ctx.allocator.free(value);
    internal.selection = internal.selection.clamped(form_associated.utf16Length(value));
}

/// HTML 4.10.11: "The cloning steps for textarea elements given node, copy,
/// and subtree are to propagate the raw value and dirty value flag from node
/// to copy." They run for every clone (dom.cloning_steps): only a textarea
/// has a state entry, and one with a clean value has nothing to propagate -
/// the copy starts clean, tracking its own children.
///
/// Beyond the spec's list, Crane's record that the value was last changed
/// by a user edit (`last_user_edit`, read by tooLong and tooShort) travels
/// with it: Gecko HTMLTextAreaElement::Clone copies
/// mLastValueChangeWasInteractive and Blink
/// TextControlElement::CloneNonAttributePropertiesFrom copies
/// last_change_was_user_edit_ (html/semantics/selectors/pseudo-classes/
/// invalid-after-clone.html, PASS in all three at wpt.fyi cc74d2669f).
fn cloningSteps(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) anyerror!void {
    _ = subtree;
    const source = StateMap.get(node) orelse return;
    const raw = source.raw_value orelse return;
    if (!isTextArea(copy)) return;
    const last_user_edit = source.last_user_edit;
    const target = try StateMap.getOrPut(copy);
    try target.setRawValue(copy.ctx.allocator, raw);
    target.last_user_edit = last_user_edit;
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {

    // Chain to parent class (HTMLElement)
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);

    // A new textarea at this address: an entry already under it is a dead
    // textarea's that a teardown missed. `StateMap` fills lazily, so left in
    // place it would be taken for this one's - a raw value nobody gave it
    // (docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md).
    if (StateMap.remove(instance)) |stale| {
        var dead = stale;
        dead.deinit();
        log.err("stale HTMLTextAreaElement state at a reissued address: a teardown missed it", .{});
    }

    // No state is recorded here on purpose: `StateMap` fills in lazily on the
    // first assignment, so an element the parser created and script never
    // touched allocates nothing and leaves nothing to clean up.
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Take the entry out first, then free what it owned: the freeing happens
    // against a copy, so nothing is written back through a map slot that has
    // already been reused.
    if (StateMap.remove(instance)) |taken| {
        var state = taken;
        state.labels.deinit(instance);
        if (state.validation.validity_traced) @import("engine").forgetTracedChild(instance, .{ .name = "validity" });
        state.deinit();
    }

    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLTextAreaElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// ---------------------------------------------------------------------------
// Raw value / API value
// ---------------------------------------------------------------------------

/// The element's child text content: the data of the Text node CHILDREN only.
///
/// Not `textContent`, which descends: `<textarea>foo<span>baz</span></textarea>`
/// has textContent "foobaz" and a child text content of "foo", and
/// `value-defaultValue-textContent.html` asserts that difference directly.
fn childTextContent(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]u8 {
    var out = std.ArrayListUnmanaged(u8).empty;
    errdefer out.deinit(allocator);

    var child = interfaces.Node.get_firstChild(instance) catch null;
    while (child) |c| {
        const node_type = interfaces.Node.get_nodeType(c) catch 0;
        if (node_type == interfaces.Node.get_TEXT_NODE() or
            node_type == interfaces.Node.get_CDATA_SECTION_NODE())
        {
            if (dom.character_data.dataOf(c)) |data| {
                try out.appendSlice(allocator, data);
            }
        }
        child = interfaces.Node.get_nextSibling(c) catch null;
    }
    return out.toOwnedSlice(allocator);
}

/// https://html.spec.whatwg.org/multipage/form-elements.html#concept-textarea-api-value
///
/// The raw value with every CRLF pair and every lone CR turned into a single LF.
/// Runs over bytes, which is safe: CR and LF are ASCII and cannot appear inside a
/// multi-byte UTF-8 sequence.
fn apiValue(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    var out = std.ArrayListUnmanaged(u8).empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, raw.len);

    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        if (raw[i] == '\r') {
            out.appendAssumeCapacity('\n');
            // Swallow the LF of a CRLF pair so it does not become a second break.
            if (i + 1 < raw.len and raw[i + 1] == '\n') i += 1;
            continue;
        }
        out.appendAssumeCapacity(raw[i]);
    }
    return out.toOwnedSlice(allocator);
}

/// The API value, owned by the caller.
fn currentApiValue(instance: *runtime.Instance) ![]u8 {
    const allocator = instance.ctx.allocator;

    if (StateMap.get(instance)) |internal| {
        if (internal.raw_value) |raw| {
            // Dirty: the element's own value wins over the children.
            return apiValue(allocator, raw);
        }
    }
    // Clean: track the child text content.
    const raw = try childTextContent(instance, allocator);
    defer allocator.free(raw);
    return apiValue(allocator, raw);
}

// ---------------------------------------------------------------------------
// IDL attributes
// ---------------------------------------------------------------------------

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return @import("html").autofill.idlValue(instance, .expectation);
}

/// Getter for form: the element's form owner.
pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return form_associated.formOwner(instance);
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // A constant, not a reflection.
    _ = instance;
    return runtime.DOMString.initInterned("textarea");
}

/// Getter for defaultValue
pub fn get_defaultValue(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // The child text content, RAW - defaultValue keeps the CRs that `value`
    // normalises away.
    const allocator = instance.ctx.allocator;
    const text = try childTextContent(instance, allocator);
    if (text.len == 0) {
        allocator.free(text);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(text);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const allocator = instance.ctx.allocator;
    const text = try currentApiValue(instance);
    if (text.len == 0) {
        allocator.free(text);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(text);
}

/// Getter for textLength
pub fn get_textLength(instance: *runtime.Instance) anyerror!u32 {
    // The LENGTH of the API value, which WebIDL measures in UTF-16 code units -
    // not bytes and not codepoints. `textarea-textLength.html` pins this with
    // "你好，世界!", 18 UTF-8 bytes and 6 code units.
    const allocator = instance.ctx.allocator;
    const text = try currentApiValue(instance);
    defer allocator.free(text);
    const units = std.unicode.calcUtf16LeLen(text) catch return @intCast(text.len);
    return @intCast(units);
}

/// Getter for willValidate
pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
    return !forms.isBarred(instance) and !form_associated.hasAttribute(instance, "readonly");
}

/// Getter for validity
pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // HTML 4.10.21.3: the same live ValidityState on every access.
    const internal = try validationState(instance);
    if (forms.liveChild(internal.validity, internal.validity_generation)) |validity| return validity;
    const validity = try interfaces.ValidityState.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(validity);
    try @import("dom").custom_elements.setValidityControl(validity, instance);
    if (instance.ctx.hasEngine()) {
        @import("engine").traceChild(instance, validity, .{ .name = "validity" });
        internal.validity_traced = true;
    }
    internal.validity = validity;
    internal.validity_generation = runtime.SlabAllocator.generationOf(validity);
    return validity;
}

/// Getter for validationMessage
pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return forms.validationMessage(instance.ctx.allocator, try get_willValidate(instance), constraintFlags(instance), (try validationState(instance)).custom_error);
}

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try StateMap.getOrPut(instance)).labels.get(instance);
}

/// The API value's length in UTF-16 code units, for clamping the cursor.
fn apiValueLength(instance: *runtime.Instance) u32 {
    const allocator = instance.ctx.allocator;
    const text = currentApiValue(instance) catch return 0;
    defer allocator.free(text);
    // HTML 4.10.20 counts code units of the API value, including lone
    // surrogates. That DOMString is WTF-8, not necessarily valid UTF-8.
    return form_associated.utf16Length(text);
}

/// The selection as it reads now.
fn currentSelection(instance: *runtime.Instance) form_associated.TextSelection {
    const internal = StateMap.get(instance) orelse return .{};
    return internal.selection.clamped(apiValueLength(instance));
}

fn pendingSelectTasks(instance: *runtime.Instance) ?*u32 {
    const internal = StateMap.get(instance) orelse return null;
    return &internal.pending_select_tasks;
}

fn selectionchangeScheduled(instance: *runtime.Instance) ?*bool {
    const internal = StateMap.get(instance) orelse return null;
    return &internal.selectionchange_scheduled;
}

/// "Set the selection range": changes queue selectionchange and select.
fn setSelectionRange(instance: *runtime.Instance, start: ?u32, end: ?u32, direction: ?[]const u8) !void {
    const internal = try StateMap.getOrPut(instance);
    if (internal.selection.setRange(start, end, direction, apiValueLength(instance))) {
        dom.selection.scheduleTextControlSelectionchange(instance, &selectionchangeScheduled) catch {};
        form_associated.queueSelectEvent(instance, &pendingSelectTasks);
    }
}

/// Getter for selectionStart
pub fn get_selectionStart(instance: *runtime.Instance) anyerror!u32 {
    // There is no rendered text entry cursor here - no layout, no focus - so this
    // is the API-visible cursor only: what was last assigned, clamped to the
    // current value. React reads selectionStart/selectionEnd to restore the
    // caret after a controlled re-render, which is why this reports a position
    // rather than throwing.
    return currentSelection(instance).start;
}

/// Getter for selectionEnd
pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!u32 {
    return currentSelection(instance).end;
}

/// Getter for selectionDirection
pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned(currentSelection(instance).direction.keyword());
}

/// Setter for defaultValue
pub fn set_defaultValue(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // "String replace all", i.e. what textContent does: every child goes,
    // elements included.
    try interfaces.Node.set_textContent(instance, value);
}

/// Setter for value: "1. Let oldAPIValue be this element's API value. 2.
/// Set this element's raw value to the new value. 3. Set this element's dirty
/// value flag to true. 4. If the new API value is different from
/// oldAPIValue, then move the text entry cursor position to the end of the
/// text control, unselecting any selected text and resetting the selection
/// direction to "none"."
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const allocator = instance.ctx.allocator;
    const old = try currentApiValue(instance);
    defer allocator.free(old);
    const internal = try StateMap.getOrPut(instance);
    try internal.setRawValue(allocator, value.asSlice());
    const now = try currentApiValue(instance);
    defer allocator.free(now);
    if (!std.mem.eql(u8, old, now)) {
        const end = form_associated.utf16Length(now);
        internal.selection = .{ .start = end, .end = end, .direction = .none };
    }
}

/// Setter for selectionStart: "2. Let end be the value of this element's
/// selectionEnd attribute. 3. If end is less than the given value, set end
/// to the given value. 4. Set the selection range with the given value, end,
/// and the value of this element's selectionDirection attribute."
pub fn set_selectionStart(instance: *runtime.Instance, value: u32) anyerror!void {
    const current = currentSelection(instance);
    try setSelectionRange(instance, value, @max(current.end, value), current.direction.keyword());
}

/// Setter for selectionEnd: "Set the selection range with the value of this
/// element's selectionStart attribute, the given value, and the value of
/// this element's selectionDirection attribute."
pub fn set_selectionEnd(instance: *runtime.Instance, value: u32) anyerror!void {
    const current = currentSelection(instance);
    try setSelectionRange(instance, current.start, value, current.direction.keyword());
}

/// Setter for selectionDirection: "Set the selection range with the value of
/// this element's selectionStart attribute, the value of this element's
/// selectionEnd attribute, and the given value."
pub fn set_selectionDirection(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const current = currentSelection(instance);
    try setSelectionRange(instance, current.start, current.end, value.asSlice());
}

/// Operation: select - "Set the selection range with 0 and infinity."
pub fn call_select(instance: *runtime.Instance) anyerror!void {
    try setSelectionRange(instance, 0, std.math.maxInt(u32), null);
}

/// Operation: setSelectionRange
pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: webidl.Opt(runtime.DOMString)) anyerror!void {
    try setSelectionRange(instance, start, end, if (direction.was_passed) direction.value.asSlice() else null);
}

/// setRangeText() steps 2-14 over the API value (textarea: the relevant
/// value), for both overloads.
fn setRangeText(instance: *runtime.Instance, replacement: []const u8, range: ?[2]u32, mode: ?form_associated.SelectionMode) !void {
    const allocator = instance.ctx.allocator;
    const current = try currentApiValue(instance);
    defer allocator.free(current);
    // 3-13.
    const result = try form_associated.setRangeText(allocator, current, currentSelection(instance), replacement, range, mode);
    defer allocator.free(result.value);
    // 2. Set the dirty value flag; 9-10 the relevant value changed.
    const internal = try StateMap.getOrPut(instance);
    try internal.setRawValue(allocator, result.value);
    // 14. Set the selection range with selection start and selection end.
    try setSelectionRange(instance, result.selection_start, result.selection_end, null);
}

/// Operation: setRangeText(replacement)
pub fn call_setRangeText(instance: *runtime.Instance, replacement: runtime.DOMString) anyerror!void {
    try setRangeText(instance, replacement.asSlice(), null, null);
}

/// Operation: setRangeText(replacement, start, end, selectionMode)
pub fn call_setRangeText__1(instance: *runtime.Instance, replacement: runtime.DOMString, start: u32, end: u32, selectionMode: webidl.Opt(enums.SelectionMode)) anyerror!void {
    try setRangeText(instance, replacement.asSlice(), .{ start, end }, selectionModeOf(selectionMode));
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    return forms.checkValidity(instance, try get_willValidate(instance), constraintFlags(instance));
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    // HTML reportValidity steps 1–2; a headless host has no validation UI.
    return forms.checkValidity(instance, try get_willValidate(instance), constraintFlags(instance));
}

/// Operation: setCustomValidity
pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
    // HTML setCustomValidity steps 1–2: normalize newlines, then replace.
    try (try validationState(instance)).setCustomError(instance.ctx.allocator, @"error".asSlice());
}

/// The SelectionMode argument of setRangeText(replacement, start, end,
/// selectionMode): "preserve" when not given.
fn selectionModeOf(mode: webidl.Opt(enums.SelectionMode)) form_associated.SelectionMode {
    if (!mode.was_passed) return .preserve;
    return switch (mode.value) {
        ._select_ => .select,
        ._start_ => .start,
        ._end_ => .end,
        ._preserve_ => .preserve,
    };
}
