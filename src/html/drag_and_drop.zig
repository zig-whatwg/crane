//! HTML 6.11.5 "Drag and drop: processing model", for the drags a pointer
//! makes on the page: a press on a draggable element, a move past the drag
//! threshold, the DND events through the drag, and the drop or cancellation
//! at the release.
//!
//! The pointer is the embedder's (html.user_input.Pointer, which owns the
//! `DragOperation` while a drag lasts); user_input hands its moves and its
//! release here first, and suppresses its own events while a drag is in
//! progress ("From the moment that the user agent is to initiate the
//! drag-and-drop operation, until the end of the drag-and-drop operation,
//! device input events ... must be suppressed").
//!
//! Where the browsers depart from the spec text, golden rule 2 decides,
//! each case noted where it applies:
//!   * The drop target follows the element under the pointer (the
//!     immediate user selection): dragenter at the new one, dragleave at the
//!     one before, dragover and drop at the one under the pointer - Blink
//!     EventHandler::UpdateDragAndDrop, WebKit EventHandler::
//!     updateDragAndDrop and Gecko EventStateManager::
//!     GenerateDragDropEnterExit all do; none redirects an unaccepted
//!     target to the body, as the spec's "current target element" steps
//!     would (a page that cancels only dragover - the common pattern - gets
//!     its drop in all three).
//!   * dragenter's relatedTarget is the element left, dragleave's the one
//!     entered (HTML gives dragenter none): Chrome and Firefox
//!     (html/editing/dnd/events/dragenter-dragleave-related-target.html,
//!     wpt.fyi 2358bd4835: Chrome 157 1/1, Firefox 160 1/1, Safari 27.2 0/1);
//!     a related target in another document is null (Blink
//!     MouseEventManager::DispatchDragEvent).
//!   * DND events are composed (Blink DispatchDragEvent setComposed(true),
//!     Gecko's drag events); HTML's "fire a DND event" leaves it unset.
//!   * A drag begins once the pointer, still pressed on a draggable element,
//!     moved 4 CSS pixels or more on either axis (Blink MouseEventManager::
//!     DragThresholdExceeded, kDragThresholdX/Y = 4), and only after a
//!     press whose pointerdown and mousedown were not canceled (Blink skips
//!     HandleMousePressEvent for a swallowed press). Crane has no layout: a
//!     move to another element is taken to pass the threshold; one within
//!     the same element compares the offsets from its centre.
//!   * No application/microdata+json item (step 6): no browser ships
//!     microdata extraction.
//!
//! What a headless engine has no source for stays out, as host concerns:
//! drags that begin outside the user agent (files from a file manager, text
//! from another application), drops into other applications (a non-DOM
//! current target), drawing the drag feedback, and drags of a text
//! selection, whose source is the text under the press point - a caret from
//! a point, which needs layout.
//!
//! Lifetimes: the source and targets are held weakly (user_input.Weak, a
//! generation check). The drag data store is owned by a DataTransfer the
//! operation makes and never exposes (`anchor`), kept alive while the drag
//! lasts (engine.keepPlatformObjectAlive) - its edges keep the store's
//! Files - and released at the end. Each DND event gets a DataTransfer of its
//! own, associated with the store only while its event is dispatched.
//!
//! Spec: https://html.spec.whatwg.org/multipage/dnd.html#drag-and-drop-processing-model

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const user_input = @import("user_input.zig");
const form_associated = @import("form_associated.zig");

const Instance = runtime.Instance;
const Weak = user_input.Weak;
const Pointer = user_input.Pointer;
const Modifiers = user_input.Modifiers;
const drag_data_store = dom.drag_data_store;
const log = std.log.scoped(.drag_and_drop);

/// The current drag operation (HTML 6.11.5).
pub const Operation = enum {
    none,
    copy,
    link,
    move,

    fn name(self: Operation) []const u8 {
        return @tagName(self);
    }
};

/// Blink's kDragThresholdX / kDragThresholdY, in CSS pixels.
const drag_threshold = 4;

/// "Every 350ms (±200ms) thereafter".
const iteration_interval_ms = 350;

/// A drag-and-drop operation in progress. OWNED by its Pointer
/// (`Pointer.drag`), freed by `end` or `abandon`.
pub const DragOperation = struct {
    allocator: std.mem.Allocator,
    /// The source node (step 3): the element being dragged.
    source: Weak,
    /// The DataTransfer whose drag data store this operation uses. Kept
    /// alive by a keep of its own (`kept`), never handed to script.
    anchor: Weak,
    kept: bool,
    /// The drag data store allowed effects state.
    allowed_effects: []const u8 = "uninitialized",
    /// The current target element, and the immediate user selection of the
    /// last iteration.
    current_target: ?Weak = null,
    immediate: ?Weak = null,
    operation: Operation = .none,
    /// What is being dragged is an a element with an href (step 7's table:
    /// "uninitialized" then means link).
    link_drag: bool,
    /// The event loop timer of the next 350ms iteration.
    timer: ?runtime.timer.TimerInterface = null,
    timer_id: ?runtime.timer.TimerId = null,
    /// The pointer whose drag this is (it owns this operation).
    pointer: *Pointer,
    modifiers: Modifiers = .{},
    /// Step 1 of an iteration: one at a time.
    in_iteration: bool = false,

    fn store(self: *DragOperation) ?*drag_data_store.Store {
        const anchor = self.anchor.get() orelse return null;
        return drag_data_store.storeOf(anchor);
    }
};

// ============================================================================
// The pointer's side: press, moves, release
// ============================================================================

/// A primary press whose pointerdown and mousedown were not canceled, at
/// `target`: the node the user may go on to drag.
pub fn pressed(pointer: *Pointer, target: *Instance) void {
    pointer.drag_press = Weak.of(target);
    pointer.press_position = pointer.position;
}

/// The pointer moved onto `hit`. True when the drag-and-drop model took the
/// move - a drag in progress, or one this move began - and the pointer's
/// own events are suppressed.
pub fn moved(pointer: *Pointer, hit: *Instance, modifiers: Modifiers) bool {
    if (pointer.drag) |operation| {
        operation.modifiers = modifiers;
        pointer.hit = Weak.of(hit);
        if (nodeDocument(hit)) |document| pointer.hit_document = Weak.of(document);
        iterate(operation, false);
        return true;
    }
    const press = pointer.drag_press orelse return false;
    if (pointer.buttons & 1 == 0) {
        pointer.drag_press = null;
        return false;
    }
    if (!thresholdExceeded(pointer, hit)) return false;
    pointer.drag_press = null;
    const pressed_node = press.get() orelse return false;
    return start(pointer, pressed_node, hit, modifiers);
}

/// The pointer's `button` went up. True when it ended a drag: the drop (or
/// the cancellation) ran, and pointerup, mouseup and click are not fired.
pub fn released(pointer: *Pointer, button: u3, modifiers: Modifiers) bool {
    if (button == 0) pointer.drag_press = null;
    const operation = pointer.drag orelse return false;
    operation.modifiers = modifiers;
    if (button != 0) return true;
    // "the user ended the drag-and-drop operation (e.g. by releasing the
    // mouse button in a mouse-driven drag-and-drop interface)": the last
    // iteration.
    iterate(operation, true);
    return true;
}

/// The embedder's input session ended with a drag in progress: it is
/// dropped without events (the page or the device has gone).
pub fn abandon(pointer: *Pointer) void {
    const operation = pointer.drag orelse return;
    free(operation);
}

/// Whether the pointer moved far enough from where it was pressed for a
/// drag to begin (see the module comment).
fn thresholdExceeded(pointer: *Pointer, hit: *Instance) bool {
    const from = pointer.press_position orelse return true;
    const to = pointer.position orelse return true;
    const from_origin = from.origin.get() orelse return true;
    const to_origin = to.origin.get() orelse return true;
    if (from_origin != to_origin) return true;
    _ = hit;
    return @abs(to.x - from.x) >= drag_threshold or @abs(to.y - from.y) >= drag_threshold;
}

// ============================================================================
// Beginning a drag (6.11.5, "When the user attempts to begin a drag")
// ============================================================================

fn start(pointer: *Pointer, pressed_node: *Instance, hit: *Instance, modifiers: Modifiers) bool {
    // 1. "It is the first element, going up the ancestor chain, starting at
    // the node that the user tried to drag, that has the IDL attribute
    // draggable set to true. If there is no such element, then nothing is
    // being dragged; return."
    const source = draggableAncestor(pressed_node) orelse return false;
    const realm = source.ctx;
    // 2. "Create a drag data store": the anchor DataTransfer's, emptied to a
    // drag data store's defaults - an empty item list, protected mode.
    const anchor = interfaces.DataTransfer.call_constructor(realm) catch return false;
    const store = drag_data_store.storeOf(anchor) orelse {
        anchor.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(anchor));
        return false;
    };
    store.setMode(.protected);
    const kept = realm.hasEngine();
    if (kept) engine.keepPlatformObjectAlive(anchor);
    const operation = pointer_allocator(pointer, realm).create(DragOperation) catch {
        if (kept) engine.releasePlatformObject(anchor);
        anchor.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(anchor));
        return false;
    };
    operation.* = .{
        .allocator = realm.allocator,
        .source = Weak.of(source),
        .anchor = Weak.of(anchor),
        .kept = kept,
        .link_drag = form_associated.isElementNamed(source, "a") and form_associated.hasAttribute(source, "href"),
        .pointer = pointer,
        .modifiers = modifiers,
        .timer = realm.getTimer() catch null,
    };
    // 3-4. The source node, and the list of dragged nodes: the element.
    // 5. Nothing selected, no files. 6. No microdata (module comment).
    // 7. The URLs of the dragged a and img elements, as text/uri-list.
    addUrls(store, source) catch {};
    // 8. The default feedback is the host's.
    // 9. "Fire a DND event named dragstart at the source node. If the event
    // is canceled, then the drag-and-drop operation should not occur;
    // return."
    if (!fire(operation, "dragstart", source, null).not_canceled) {
        free(operation);
        return false;
    }
    // A dragstart listener may have taken the source's document away.
    if (!isReachable(source)) {
        free(operation);
        return false;
    }
    // 10. "Fire a pointer event at the source node named pointercancel,
    // and fire any other follow-up events as required by Pointer Events":
    // the pointer's event stream is suppressed (Pointer Events 3.1.3.3:
    // pointercancel, pointerout, pointerleave).
    user_input.suppressPointerStream(pointer, modifiers);
    // The move that began the drag put the pointer over `hit`: the first
    // immediate user selection.
    pointer.hit = Weak.of(hit);
    if (nodeDocument(hit)) |document| pointer.hit_document = Weak.of(document);
    // 11. "Initiate the drag-and-drop operation": the pointer's moves are
    // the operation's from now on; its first iteration runs at once, the
    // next every 350ms.
    pointer.drag = operation;
    iterate(operation, false);
    return true;
}

fn pointer_allocator(pointer: *Pointer, realm: runtime.Context) std.mem.Allocator {
    _ = pointer;
    return realm.allocator;
}

/// Step 1: the element itself or the first ancestor (crossing shadow roots
/// to their hosts, the flat tree's way, as Blink's DragController::
/// DraggableNode walks it) whose draggable IDL attribute is true. Only an
/// HTML element has the attribute.
fn draggableAncestor(node: *Instance) ?*Instance {
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (n.stateAs(interfaces.HTMLElement.State) == null) continue;
        if (interfaces.HTMLElement.get_draggable(n) catch false) return n;
    }
    return null;
}

/// Step 7: for an a element with an href, or an img with a src, the URL
/// "encoding-parsed-and-serialized" relative to its node document, as a
/// text/uri-list item.
fn addUrls(store: *drag_data_store.Store, source: *Instance) !void {
    const attribute: []const u8 = if (form_associated.isElementNamed(source, "a")) "href" else if (form_associated.isElementNamed(source, "img")) "src" else return;
    const view = dom.element_data.of(source) orelse return;
    const value = view.findValue(null, attribute) orelse return;
    const url = (try dom.encoding_parse.encodingParseAndSerialize(source, value)) orelse return;
    defer source.ctx.allocator.free(url);
    // "If urls is still empty, then return." 4-5: one URL, no CRLF.
    store.setMode(.read_write);
    defer store.setMode(.protected);
    _ = store.addText(url, "text/uri-list") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.NotSupportedError => {},
    };
}

// ============================================================================
// The iterations (6.11.5, "as soon as the drag operation is initiated and
// every 350ms (±200ms) thereafter")
// ============================================================================

fn armTimer(operation: *DragOperation) void {
    const timer = operation.timer orelse return;
    if (operation.timer_id) |id| _ = timer.clearTimeout(id);
    operation.timer_id = timer.setTimeout(iteration_interval_ms, &timerFired, operation);
}

fn timerFired(data: ?*anyopaque) void {
    const operation: *DragOperation = @ptrCast(@alignCast(data orelse return));
    operation.timer_id = null;
    iterate(operation, false);
}

/// One iteration of the drag-and-drop operation; `ended`: the user released
/// the pointer, the last one.
fn iterate(operation: *DragOperation, ended: bool) void {
    // 1. "If the user agent is still performing the previous iteration of
    // the sequence (if any) when the next iteration becomes due, return."
    if (operation.in_iteration) return;
    operation.in_iteration = true;
    // 2. "Fire a DND event named drag at the source node. If this event is
    // canceled, the user agent must set the current drag operation to
    // "none"."
    var drag_canceled = false;
    if (liveTarget(operation.source)) |source| {
        drag_canceled = !fire(operation, "drag", source, null).not_canceled;
    }
    if (drag_canceled) operation.operation = .none;
    if (!drag_canceled and !ended) {
        // 3. Check the state of the drag-and-drop operation.
        updateTargets(operation);
        operation.in_iteration = false;
        armTimer(operation);
        return;
    }
    // 4. The user ended the operation, or drag was canceled: the last
    // iteration.
    finish(operation);
}

/// Step 3: the element under the pointer is the immediate user selection;
/// dragenter and dragleave as it changes (module comment, golden rule 2),
/// then dragover at the current target element, and the current drag
/// operation from what dragover's listeners did.
fn updateTargets(operation: *DragOperation) void {
    const pointer = operation.pointer;
    const selection = pointer.currentTarget();
    const previous = liveTarget(operation.immediate);
    if (selection != previous) {
        operation.immediate = if (selection) |s| Weak.of(s) else null;
        if (selection) |entered| {
            _ = fire(operation, "dragenter", entered, previous);
        }
        if (previous) |left| {
            if (isReachable(left)) _ = fire(operation, "dragleave", left, liveTarget(operation.immediate));
        }
        operation.current_target = operation.immediate;
    }
    // 3.3. "If the current target element is a DOM element, then fire a DND
    // event named dragover at this current target element."
    const target = liveTarget(operation.current_target) orelse {
        // 3.4: no target: no operation.
        operation.operation = .none;
        return;
    };
    const result = fire(operation, "dragover", target, null);
    if (result.not_canceled) {
        // "If the current target element is a text control ... or an
        // editing host or editable element, and the drag data store item
        // list has an item with the drag data item type string "text/plain"
        // and the drag data item kind text": copy (Crane drags no
        // selection, so nothing is moved); otherwise none.
        operation.operation = if (acceptsTextDrop(operation, target)) .copy else .none;
    } else {
        operation.operation = operationFromEffects(result.effects);
    }
}

/// Step 3.3's table: the current drag operation from a canceled dragover's
/// effectAllowed and dropEffect.
fn operationFromEffects(effects: drag_data_store.Effects) Operation {
    const allowed = effects.effect_allowed;
    const drop = effects.drop_effect;
    if (std.mem.eql(u8, drop, "copy") and oneOf(allowed, &.{ "uninitialized", "copy", "copyLink", "copyMove", "all" })) return .copy;
    if (std.mem.eql(u8, drop, "link") and oneOf(allowed, &.{ "uninitialized", "link", "copyLink", "linkMove", "all" })) return .link;
    if (std.mem.eql(u8, drop, "move") and oneOf(allowed, &.{ "uninitialized", "move", "copyMove", "linkMove", "all" })) return .move;
    return .none;
}

fn oneOf(value: []const u8, choices: []const []const u8) bool {
    for (choices) |choice| if (std.mem.eql(u8, value, choice)) return true;
    return false;
}

/// Whether `target` is a text control, editing host or editable element
/// and the store has a text/plain text item.
fn acceptsTextDrop(operation: *DragOperation, target: *Instance) bool {
    const store = operation.store() orelse return false;
    if (store.textIndex("text/plain") == null) return false;
    return user_input.isMutableTextControl(target) or isEditable(target);
}

fn isEditable(target: *Instance) bool {
    return @import("execcommand/root.zig").isEditableTarget(target);
}

/// Step 4: the drop, or the failure, then dragend.
fn finish(operation: *DragOperation) void {
    const target = liveTarget(operation.current_target);
    if (operation.operation == .none or target == null) {
        // 4.1 "the drag operation failed": dragleave at the current target
        // element, and no operation.
        if (target) |t| if (isReachable(t)) {
            _ = fire(operation, "dragleave", t, null);
        };
        operation.operation = .none;
    } else {
        // "the drag operation might be a success".
        const drop_target = target.?;
        const result = fire(operation, "drop", drop_target, null);
        if (!result.not_canceled) {
            // "set the current drag operation to the value of the dropEffect
            // attribute ... as it stood after the event dispatch finished."
            operation.operation = operationNamed(result.effects.drop_effect);
        } else if (acceptsTextDrop(operation, drop_target)) {
            // The default action: insert the first text/plain item's data
            // into the text control or editing host - at the end of a text
            // control (the spec's own "inserting it at the end of the
            // field"; where the pointer is would need layout).
            insertTextData(operation, drop_target);
        } else {
            operation.operation = .none;
        }
    }
    // 4.2. "Fire a DND event named dragend at the source node."
    if (liveTarget(operation.source)) |source| _ = fire(operation, "dragend", source, null);
    // 4.3. dragend's default action: Crane drags no selection, so nothing
    // is deleted; a failed drag is the host's to show.
    // The pointer's event stream was suppressed when the drag began: its
    // next move enters what it is over afresh (pointerover, pointerenter).
    operation.pointer.hit = null;
    free(operation);
}

fn operationNamed(name: []const u8) Operation {
    inline for (.{ Operation.copy, Operation.link, Operation.move }) |op| {
        if (std.mem.eql(u8, name, op.name())) return op;
    }
    return .none;
}

fn insertTextData(operation: *DragOperation, target: *Instance) void {
    const store = operation.store() orelse return;
    const data = store.textData("text/plain") orelse return;
    // A copy: the insertion runs script, which may change the store.
    const text = operation.allocator.dupe(u8, data) catch return;
    defer operation.allocator.free(text);
    if (user_input.isMutableTextControl(target)) {
        user_input.dropIntoTextControl(target, text);
        return;
    }
    // An editing host or editable element: the caret at its end, then the
    // insertText action as user input (execcommand.insertFromDrop).
    const document = nodeDocument(target) orelse return;
    const selection = (interfaces.Document.call_getSelection(document) catch return) orelse return;
    interfaces.Selection.call_selectAllChildren(selection, target) catch return;
    interfaces.Selection.call_collapseToEnd(selection) catch return;
    // Input Events 2: insertFromDrop's dataTransfer in an editing host holds
    // what is dropped - a read-only DataTransfer, as the paste's
    // (execcommand/clipboard.zig pastedDataTransfer).
    const dropped: ?*Instance = blk: {
        const made = interfaces.DataTransfer.call_constructor(document.ctx) catch break :blk null;
        const made_store = drag_data_store.storeOf(made) orelse break :blk made;
        _ = made_store.addText(text, "text/plain") catch {};
        made_store.setMode(.read_only);
        break :blk made;
    };
    const dropped_generation: u64 = if (dropped) |d| runtime.SlabAllocator.generationOf(d) else 0;
    defer if (dropped) |d| d.releaseIfUnwrapped(dropped_generation);
    _ = @import("execcommand/root.zig").insertFromDrop(document, text, dropped);
}

/// End the operation: no more iterations, the store's DataTransfer let go.
fn free(operation: *DragOperation) void {
    if (operation.timer_id) |id| if (operation.timer) |timer| {
        _ = timer.clearTimeout(id);
    };
    operation.timer_id = null;
    if (operation.pointer.drag == operation) operation.pointer.drag = null;
    if (operation.anchor.get()) |anchor| {
        if (operation.kept) engine.releasePlatformObject(anchor);
        anchor.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(anchor));
    }
    operation.allocator.destroy(operation);
}

// ============================================================================
// "Fire a DND event" (6.11.4)
// ============================================================================

const Fired = struct {
    not_canceled: bool = true,
    /// effectAllowed and dropEffect as they stood after the dispatch.
    effects: drag_data_store.Effects = .{},
};

fn fire(operation: *DragOperation, comptime event_type: []const u8, target: *Instance, related_in: ?*Instance) Fired {
    const store = operation.store() orelse return .{};
    const anchor = operation.anchor.get() orelse return .{};
    const realm = target.ctx;
    // 1. dataDragStoreWasChanged.
    var changed = false;
    // 2. No related target: null. A related target in another document is
    // not exposed (Blink MouseEventManager::DispatchDragEvent).
    const related: ?*Instance = if (related_in) |r| (if (nodeDocument(r) == nodeDocument(target)) r else null) else null;
    // 3. The target's Document's relevant global object.
    const window: ?*Instance = if (nodeDocument(target)) |d| (interfaces.Document.get_defaultView(d) catch null) else null;
    // 4. dragstart: read/write mode; drop: read-only mode.
    if (comptime std.mem.eql(u8, event_type, "dragstart")) {
        store.setMode(.read_write);
        changed = true;
    }
    if (comptime std.mem.eql(u8, event_type, "drop")) store.setMode(.read_only);
    // 5. "a newly created DataTransfer object associated with the given
    // drag data store".
    const data_transfer = drag_data_store.makeForStore(realm, store) catch {
        if (changed) store.setMode(.protected);
        return .{};
    };
    const data_transfer_generation = runtime.SlabAllocator.generationOf(data_transfer);
    // 6. effectAllowed: the drag data store allowed effects state. 7.
    // dropEffect.
    drag_data_store.setEffects(data_transfer, .{ .effect_allowed = operation.allowed_effects, .drop_effect = dropEffectFor(operation, event_type) });
    // 8-11. A DragEvent: it bubbles, is cancelable unless dragleave or
    // dragend, its view the window, its relatedTarget and dataTransfer;
    // the mouse attributes as the input device's state is.
    const cancelable = comptime !(std.mem.eql(u8, event_type, "dragleave") or std.mem.eql(u8, event_type, "dragend"));
    const buttons: u16 = if (comptime std.mem.eql(u8, event_type, "drop") or std.mem.eql(u8, event_type, "dragend")) 0 else operation.pointer.buttons;
    const modifiers = operation.modifiers;
    const init: dictionaries.DragEventInit = .{
        .base = .{
            .base = .{
                .base = .{
                    .base = .{ .bubbles = true, .cancelable = cancelable, .composed = true },
                    .view = window,
                    .detail = 0,
                },
                .ctrlKey = modifiers.ctrl,
                .shiftKey = modifiers.shift,
                .altKey = modifiers.alt,
                .metaKey = modifiers.meta,
            },
            .button = 0,
            .buttons = buttons,
            .relatedTarget = related,
            .clientX = 0,
            .clientY = 0,
        },
        .dataTransfer = data_transfer,
    };
    var result: Fired = .{};
    const event = interfaces.DragEvent.call_constructor(realm, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.DragEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        // No event holds it: it goes now.
        drag_data_store.disassociate(data_transfer);
        data_transfer.releaseIfUnwrapped(data_transfer_generation);
        if (interfaces.DataTransfer.get_files(anchor)) |files| store.setFiles(files) else |_| {}
        if (changed) store.setMode(.protected);
        return result;
    };
    const event_generation = runtime.SlabAllocator.generationOf(event);
    // 12. Dispatch. The event keeps its DataTransfer (DragEvent's traced
    // edge), so the DataTransfer is the event's from here, as a clipboard
    // event's is (execcommand/clipboard.zig).
    result.not_canceled = dom.fire_event.dispatchTrusted(target, event) catch true;
    // 13. "Set the drag data store allowed effects state to the current
    // value of dataTransfer's effectAllowed attribute."
    result.effects = drag_data_store.effectsOf(data_transfer);
    operation.allowed_effects = result.effects.effect_allowed;
    // 15. Break the association; the store's files list is the anchor's
    // again.
    drag_data_store.disassociate(data_transfer);
    event.releaseIfUnwrapped(event_generation);
    if (interfaces.DataTransfer.get_files(anchor)) |files| store.setFiles(files) else |_| {}
    // 14. "If dataDragStoreWasChanged is true, then set the drag data store
    // mode back to the protected mode."
    if (changed) store.setMode(.protected);
    return result;
}

/// Step 7: dropEffect for an event of `event_type`.
fn dropEffectFor(operation: *DragOperation, comptime event_type: []const u8) []const u8 {
    if (comptime std.mem.eql(u8, event_type, "dragstart") or std.mem.eql(u8, event_type, "drag") or std.mem.eql(u8, event_type, "dragleave")) return "none";
    if (comptime std.mem.eql(u8, event_type, "drop") or std.mem.eql(u8, event_type, "dragend")) return operation.operation.name();
    // dragenter and dragover: from effectAllowed and the drag-and-drop
    // source (the first of each row's values; no platform override).
    const allowed = operation.allowed_effects;
    if (std.mem.eql(u8, allowed, "none")) return "none";
    if (oneOf(allowed, &.{ "copy", "copyLink", "copyMove", "all" })) return "copy";
    if (oneOf(allowed, &.{ "link", "linkMove" })) return "link";
    if (std.mem.eql(u8, allowed, "move")) return "move";
    // "uninitialized": an a element with an href, link; anything else that
    // Crane drags (no selection), copy.
    return if (operation.link_drag) "link" else "copy";
}

// ============================================================================
// Helpers
// ============================================================================

fn nodeDocument(node: *Instance) ?*Instance {
    return interfaces.Node.get_ownerDocument(node) catch null;
}

fn parentOf(node: *Instance) ?*Instance {
    const parent = form_associated.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    if (!form_associated.isElement(parent)) return null;
    return parent;
}

fn isReachable(node: *Instance) bool {
    if (!(interfaces.Node.get_isConnected(node) catch false)) return false;
    const document = nodeDocument(node) orelse return false;
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

/// The node `weak` names, while it is allocated and its document is fully
/// active (user_input's rule for what an input device remembers).
fn liveTarget(weak: ?Weak) ?*Instance {
    const node = (weak orelse return null).get() orelse return null;
    const document = nodeDocument(node) orelse return null;
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return null;
    return node;
}
