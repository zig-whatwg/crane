//! HTML 4.11.4 dialog lifecycle (HTML cached 2026-10-17).
//! Design: WebKit HTMLDialogElement::{show,showModal,close,removingSteps}
//! revalidate after beforetoggle and keep modal membership separate from open.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const html = @import("html");
const forms = html.form_associated;
const focus = html.focus;
const Instance = runtime.Instance;
const HTMLDialogElement = interfaces.HTMLDialogElement;
const KeptInstance = dom.custom_elements.KeptInstance;
const focus_slot: engine.TracedSlot = .{ .name = "dialog:previous-focus" };
const request_close_source_slot: engine.TracedSlot = .{ .name = "dialog:request-close-source" };
const close_watchers = html.close_watchers;
const log = std.log.scoped(.dialog);

pub const State = HTMLDialogElement.State;
pub const ImplError = error{ NotImplemented, InvalidStateError, OutOfMemory };

/// Lazy state with both exits: generated destruction and the orphan sweep.
/// The saved focus uses the existing MemberHold, including its teardown net.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    owner: KeptInstance,
    return_value: runtime.DOMString = .empty,
    previous_focus: dom.node_holds.MemberHold = .{},
    /// HTML "enable close watcher for request close".
    enable_close_watcher_for_request_close: bool = false,
    /// HTML "request close return value": null or a string. OWNED.
    request_close_return_value: ?runtime.DOMString = null,
    /// HTML "request close source element", kept for the close action.
    request_close_source: dom.node_holds.MemberHold = .{},

    pub fn deinit(self: *InternalState) void {
        // As top_layer.State.releaseAfterRealmEnded: an orphan's realm can
        // have ended before the sweep. Its native hold must still unlink.
        if (self.owner.get() == null) {
            self.previous_focus.kept = false;
            self.request_close_source.kept = false;
        }
        self.previous_focus.release(self.owner.instance, focus_slot);
        self.request_close_source.release(self.owner.instance, request_close_source_slot);
        self.setRequestCloseReturnValue(null);
        self.return_value.deinit(self.allocator);
    }

    /// Replace the request close return value with a copy of `value`.
    fn setRequestCloseReturnValue(self: *InternalState, value: ?runtime.DOMString) void {
        if (self.request_close_return_value) |*old| old.deinit(self.allocator);
        self.request_close_return_value = null;
        const given = value orelse return;
        self.request_close_return_value = given.clone(self.allocator) catch null;
    }

    /// Replace the request close source element.
    fn setRequestCloseSource(self: *InternalState, source: ?*Instance) void {
        const dialog = self.owner.get() orelse return;
        self.request_close_source.release(dialog, request_close_source_slot);
        if (source) |element| self.request_close_source.take(dialog, element, request_close_source_slot);
    }
};
const States = dom.orphan_states.Swept(.html_dialog_element, InternalState);

fn internalState(instance: *Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const internal = try States.create(instance, .{
        .allocator = instance.ctx.allocator,
        .owner = KeptInstance.of(instance),
    });
    state.own._internal = internal;
    return internal;
}

/// Install the dialog's non-IDL algorithms once at process startup.
pub fn installHooks() void {
    dom.dialog.install(.{ .show_modal = &showModal, .close = &closeDialog, .request_close = &requestCloseDialog, .inert = &modalInertness });
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch |err| {
        log.warn("dialog removing steps not registered: {}", .{err});
    };
    dom.mutation.registerInsertionStepsCallback(&insertionSteps) catch |err| {
        log.warn("dialog insertion steps not registered: {}", .{err});
    };
    dom.attribute_change_steps.install("dialog", &attributeChangeSteps);
    States.installSweep();
}

pub fn deinitOwn(instance: *Instance) void {
    const state = instance.getState(State);
    state.own._internal = null;
    States.destroy(instance);
}

pub fn call_constructor(ctx: runtime.Context) !*Instance {
    return HTMLDialogElement.init(ctx.allocator, ctx);
}

/// returnValue is independent of attributes and starts as the empty string.
pub fn get_returnValue(instance: *Instance) !runtime.DOMString {
    const internal = instance.getState(State).own._internal orelse return .empty;
    return internal.return_value.clone(instance.ctx.allocator);
}

pub fn set_returnValue(instance: *Instance, value: runtime.DOMString) !void {
    const internal = try internalState(instance);
    const copy = try value.clone(internal.allocator);
    internal.return_value.deinit(internal.allocator);
    internal.return_value = copy;
}

/// HTML "computed closed-by state", steps 1–2.
pub fn get_closedBy(instance: *Instance) !runtime.DOMString {
    if (dom.element_data.of(instance)) |data| if (data.findAttribute(null, "closedby")) |attribute| {
        for ([_][]const u8{ "any", "closerequest", "none" }) |keyword| {
            if (std.ascii.eqlIgnoreCase(attribute.value, keyword)) return runtime.DOMString.initInterned(keyword);
        }
    };
    return runtime.DOMString.initInterned(if (dom.dialog.isModal(instance)) "closerequest" else "none");
}

/// The requestClose(returnValue) method steps: request to close this with
/// returnValue (null if not given) and null.
pub fn call_requestClose(instance: *Instance, return_value: webidl.Opt(runtime.DOMString)) !void {
    try requestCloseDialog(instance, return_value, null);
}

/// HTML "request to close" the dialog `subject`, given null or a string
/// returnValue and null or an Element source (a command's invoker).
fn requestCloseDialog(subject: *Instance, return_value: webidl.Opt(runtime.DOMString), source: ?*Instance) !void {
    // 1. If subject does not have an open attribute, then return.
    if (!hasOpen(subject)) return;
    // 2. If subject is not connected or its node document is not fully
    // active, then return.
    if (!(try interfaces.Node.get_isConnected(subject))) return;
    const document = try nodeDocument(subject);
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return;
    // 3. Assert: subject's close watcher is not null. (The setup steps set
    // it; a realm with no Window has no manager to set it in.)
    const window = close_watchers.relevantWindow(subject) orelse return;
    if (!close_watchers.isActive(window, .dialog, subject)) return;
    const internal = try internalState(subject);
    // 4. Set subject's enable close watcher for request close to true.
    internal.enable_close_watcher_for_request_close = true;
    // 5. Set subject's request close return value to returnValue.
    internal.setRequestCloseReturnValue(if (return_value.wasPassed()) return_value.value else null);
    // 6. Set subject's request close source element to source.
    internal.setRequestCloseSource(source);
    // 7. Request to close subject's close watcher with false. Its cancel
    // action runs script; the watcher keeps subject meanwhile.
    _ = close_watchers.requestClose(window, .dialog, subject, false);
    // 8. Set subject's enable close watcher for request close to false.
    if (subject.getState(State).own._internal) |state| state.enable_close_watcher_for_request_close = false;
}

/// "Set the dialog close watcher" step 3's actions, given the dialog.
const close_watcher_actions: close_watchers.Actions = .{
    .cancel = &closeWatcherCancel,
    .close = &closeWatcherClose,
    .enabled = &closeWatcherEnabled,
};

/// cancelAction given canPreventClose: "return the result of firing an
/// event named cancel at dialog, with the cancelable attribute initialized
/// to canPreventClose".
fn closeWatcherCancel(dialog: *Instance, can_prevent_close: bool) bool {
    return fireEvent(dialog, "cancel", can_prevent_close);
}

/// closeAction: "close the dialog given dialog, dialog's request close
/// return value, and dialog's request close source element".
fn closeWatcherClose(dialog: *Instance) void {
    const internal = dialog.getState(State).own._internal;
    // Copied: the close's beforetoggle listeners can request again, which
    // replaces the dialog's own value.
    var result: ?runtime.DOMString = null;
    if (internal) |state| if (state.request_close_return_value) |value| {
        result = value.clone(dialog.ctx.allocator) catch null;
    };
    defer if (result) |*value| value.deinit(dialog.ctx.allocator);
    const source = if (internal) |state| state.request_close_source.get() else null;
    const passed: webidl.Opt(runtime.DOMString) = if (result) |value| .passed(value) else .notPassed();
    closeDialog(dialog, passed, source) catch |err| log.warn("dialog not closed by its close watcher: {}", .{err});
}

/// getEnabledState: "return true if dialog's enable close watcher for
/// request close is true or dialog's computed closed-by state is not None;
/// otherwise false".
fn closeWatcherEnabled(dialog: *Instance) bool {
    if (dialog.getState(State).own._internal) |state| if (state.enable_close_watcher_for_request_close) return true;
    const closed_by = get_closedBy(dialog) catch return false;
    return !std.mem.eql(u8, closed_by.asSlice(), "none");
}

/// HTML "set the dialog close watcher" given `dialog`.
fn setCloseWatcher(dialog: *Instance) void {
    // 1-2. Assert: no close watcher yet; dialog has an open attribute and a
    // fully active node document (the callers' checks).
    const window = close_watchers.relevantWindow(dialog) orelse return;
    // 3. Establish a close watcher given dialog's relevant global object.
    close_watchers.establish(window, .dialog, dialog, &close_watcher_actions) catch |err| {
        log.warn("dialog close watcher not established: {}", .{err});
    };
}

/// HTML "dialog setup steps" given `subject`.
fn setupSteps(subject: *Instance) void {
    // 1-3. Asserts: open, connected, not in the open dialogs list.
    // 4. Add subject to its node document's open dialogs list. The list
    // serves only dialog light dismiss (4.11.5, closedby=any by pointer),
    // which Crane does not run yet: no list is kept.
    // 5. Set the dialog close watcher with subject.
    setCloseWatcher(subject);
}

/// HTML "dialog cleanup steps" given `subject`.
fn cleanupSteps(subject: *Instance) void {
    // 1. Remove subject from its node document's open dialogs list (none
    // is kept, see setupSteps).
    // 2. If subject's close watcher is not null: destroy it, set it to null.
    const window = close_watchers.relevantWindow(subject) orelse return;
    close_watchers.destroy(window, .dialog, subject);
}

fn fullyActiveDocument(subject: *Instance) bool {
    const document = nodeDocument(subject) catch return false;
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

/// The dialog's attribute change steps.
fn attributeChangeSteps(element: *Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    // 1. If namespace is not null, then return.
    if (namespace != null) return;
    // 2. If localName is not open, then return.
    if (!std.mem.eql(u8, local_name, "open")) return;
    if (element.stateAs(State) == null) return;
    // 3. If value is null and oldValue is not null, then run the dialog
    // cleanup steps given element.
    if (value == null and old_value != null) cleanupSteps(element);
    // 4. If element's node document is not fully active, then return.
    if (!fullyActiveDocument(element)) return;
    // 5. If element is not connected, then return.
    if (!(interfaces.Node.get_isConnected(element) catch false)) return;
    // 6. If value is not null and oldValue is null, then run the dialog
    // setup steps given element.
    if (value != null and old_value == null) setupSteps(element);
}

/// The dialog's HTML element insertion steps.
fn insertionSteps(node: *dom.NodeBase) void {
    if (node.node_type != 1) return;
    const subject: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    if (subject.stateAs(State) == null) return;
    // 1. If insertedNode's node document is not fully active, then return.
    if (!fullyActiveDocument(subject)) return;
    // 2. If insertedNode has an open attribute and is connected, then run
    // the dialog setup steps given insertedNode.
    if (hasOpen(subject) and (interfaces.Node.get_isConnected(subject) catch false)) setupSteps(subject);
}

/// DOM "fire an event" named `event_type` at `dialog`: whether it was not
/// canceled. An event that cannot be made is not canceled.
fn fireEvent(dialog: *Instance, comptime event_type: []const u8, cancelable: bool) bool {
    const event = interfaces.Event.call_constructor(dialog.ctx, runtime.DOMString.initInterned(event_type), .passed(.{ .cancelable = cancelable })) catch |err| {
        log.warn("{s} not fired at a dialog: {}", .{ event_type, err });
        return true;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(dialog, event) catch true;
}

/// A dialog's queued toggle event task (HTML "queue a dialog toggle event
/// task", step 2): it keeps the dialog and the source until it runs, is
/// cancelled or is dropped (dom.node_holds.ElementTask).
const DialogToggle = struct {
    /// The dialog (the task is queued given it) and the source.
    pub const held_count = 2;
    old_state: []const u8,
    new_state: []const u8,

    pub fn steps(self: *DialogToggle, held: []const dom.node_holds.TaskHold) void {
        const dialog = held[0].get() orelse return;
        // 2.1. Fire an event named toggle at element, using ToggleEvent,
        // with oldState, newState and source. 2.2 (the tracker to null)
        // happened when the task started.
        const event = interfaces.ToggleEvent.call_constructor(dialog.ctx, runtime.DOMString.initInterned("toggle"), .passed(.{
            .base = .{},
            .oldState = runtime.DOMString.initInterned(self.old_state),
            .newState = runtime.DOMString.initInterned(self.new_state),
            .source = held[1].get(),
        })) catch |err| {
            log.warn("toggle not fired at a dialog: {}", .{err});
            return;
        };
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        _ = dom.fire_event.dispatchTrusted(dialog, event) catch {};
    }
};

/// The dialog toggle task tracker is the queued DialogToggle task given the
/// dialog (`ToggleTask.pending`).
const ToggleTask = dom.node_holds.ElementTask(DialogToggle);

/// HTML "queue a dialog toggle event task" given element, oldState,
/// newState and source.
fn queueToggleEventTask(element: *Instance, old_state_given: []const u8, new_state: []const u8, source: ?*Instance) void {
    var old_state = old_state_given;
    // 1. If element's dialog toggle task tracker is not null: take its old
    // state, remove its task from its task queue, set the tracker to null.
    if (ToggleTask.pending(element)) |tracker| {
        old_state = tracker.payload.old_state;
        tracker.cancel();
    }
    // 2-3. Queue an element task on the DOM manipulation task source given
    // element; the task is the tracker while it is pending.
    _ = ToggleTask.queue(.{ element, source }, .{ .old_state = old_state, .new_state = new_state });
}

/// "Close the dialog" step 13's task: fire close at the dialog, keeping it
/// until the task runs or is dropped.
const DialogClose = struct {
    pub const held_count = 1;

    pub fn steps(_: *DialogClose, held: []const dom.node_holds.TaskHold) void {
        const dialog = held[0].get() orelse return;
        _ = fireEvent(dialog, "close", false);
    }
};

pub fn call_showModal(instance: *Instance) !void {
    try showModal(instance, null);
}

pub fn call_show(instance: *Instance) !void {
    // show steps 1–2: only a modal open dialog rejects show().
    if (hasOpen(instance)) {
        if (dom.dialog.isModal(instance)) return error.InvalidStateError;
        return;
    }
    const kept = KeptInstance.of(instance);
    var hold = try retain(instance);
    defer if (hold) |*owned| owned.release();
    // Steps 3–4: listeners may open or remove the dialog, or end its realm.
    if (!try beforeToggle(instance, true, null)) return;
    const subject = kept.get() orelse return;
    if (hasOpen(subject)) return;
    // Step 5: queue a dialog toggle event task given subject, "closed",
    // "open" and null.
    queueToggleEventTask(subject, "closed", "open", null);
    // Step 6.
    try dom.element_attributes.set(subject, "open", "", .{});
    // Step 7 must precede focus-changing popover callbacks.
    try savePreviousFocus(subject);
    // Steps 8–10.
    try html.popover.hidePopoversForDialog(subject);
    if (kept.get() == null) return;
    // Step 11.
    dialogFocusingSteps(subject);
}

pub fn call_close(instance: *Instance, return_value: webidl.Opt(runtime.DOMString)) !void {
    try closeDialog(instance, return_value, null);
}

fn nodeDocument(instance: *Instance) !*Instance {
    return (try interfaces.Node.get_ownerDocument(instance)) orelse error.InvalidStateError;
}

fn hasOpen(instance: *Instance) bool {
    return forms.hasAttribute(instance, "open");
}

fn retain(instance: *Instance) !?engine.Owned {
    return if (instance.ctx.hasEngine()) try engine.retainValue(instance.ctx, .{ .instance = instance }) else null;
}

fn beforeToggle(instance: *Instance, opening: bool, source: ?*Instance) !bool {
    // As in Node's native-storage cleanup, an engine-free context has no
    // agent. A retired realm keeps its agent and must retain the existing
    // releaseIfUnwrapped contract even after hasEngine becomes false.
    const native_context = !instance.ctx.hasEngine() and instance.ctx.agent == null;
    const event = try interfaces.ToggleEvent.call_constructor(instance.ctx, runtime.DOMString.initInterned("beforetoggle"), .passed(.{
        .base = .{ .cancelable = opening },
        .oldState = runtime.DOMString.initInterned(if (opening) "closed" else "open"),
        .newState = runtime.DOMString.initInterned(if (opening) "open" else "closed"),
        .source = source,
    }));
    const generation = runtime.SlabAllocator.generationOf(event);
    defer {
        // Dispatch is synchronous. With no engine a listener cannot keep
        // this internally created event, so its native caller owns cleanup.
        if (native_context and runtime.SlabAllocator.generationOf(event) == generation)
            Instance.deinit(event)
        else
            event.releaseIfUnwrapped(generation);
    }
    return dom.fire_event.dispatchTrusted(instance, event);
}

fn savePreviousFocus(subject: *Instance) !void {
    const internal = try internalState(subject);
    const previous = focus.designatedAreaOf(try nodeDocument(subject));
    if (internal.previous_focus.get() == previous) return;
    // Root the replacement across releasing the old edge, using the same
    // existing synchronous retention operation as command dispatch.
    var hold = if (previous) |element| try retain(element) else null;
    defer if (hold) |*owned| owned.release();
    internal.previous_focus.release(subject, focus_slot);
    if (previous) |element| internal.previous_focus.take(subject, element, focus_slot);
}

/// HTML "show a modal dialog", including the command invoker as source.
fn showModal(instance: *Instance, source: ?*Instance) !void {
    // Steps 1–5.
    if (hasOpen(instance)) {
        if (!dom.dialog.isModal(instance)) return error.InvalidStateError;
        return;
    }
    const document = try nodeDocument(instance);
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document)) or
        !(try interfaces.Node.get_isConnected(instance)) or dom.top_layer.showing(instance)) return error.InvalidStateError;
    const kept = KeptInstance.of(instance);
    var hold = try retain(instance);
    defer if (hold) |*owned| owned.release();
    var source_hold = if (source) |element| try retain(element) else null;
    defer if (source_hold) |*owned| owned.release();
    // Steps 6–9: the callbacks can change the document and open/popover state.
    if (!try beforeToggle(instance, true, source)) return;
    const subject = kept.get() orelse return;
    if (hasOpen(subject) or !(try interfaces.Node.get_isConnected(subject)) or dom.top_layer.showing(subject)) return;
    // Step 10: queue a dialog toggle event task given subject, "closed",
    // "open" and source.
    queueToggleEventTask(subject, "closed", "open", source);
    // Step 11. Its attribute change steps run the dialog setup steps, which
    // set the dialog close watcher.
    try dom.element_attributes.set(subject, "open", "", .{});
    // Step 12: assert subject's close watcher is not null (absent only in a
    // realm with no Window, whose manager does not exist).
    // Steps 13–15: membership is the shared modal truth. With no layout or
    // transitions, the top layer is a Document-owned list of marked holds.
    const layer = (try dom.top_layer.ofElement(subject, true)) orelse return error.InvalidStateError;
    _ = try layer.addModal(subject);
    // Steps 16–19.
    try savePreviousFocus(subject);
    try html.popover.hidePopoversForDialog(subject);
    if (kept.get() == null) return;
    // Step 20.
    dialogFocusingSteps(subject);
}

/// HTML "close the dialog". Missing and empty return values differ.
fn closeDialog(instance: *Instance, return_value: webidl.Opt(runtime.DOMString), source: ?*Instance) !void {
    // Step 1.
    if (!hasOpen(instance)) return;
    const kept = KeptInstance.of(instance);
    var hold = try retain(instance);
    defer if (hold) |*owned| owned.release();
    var source_hold = if (source) |element| try retain(element) else null;
    defer if (source_hold) |*owned| owned.release();
    // Steps 2–3. The closing event is not cancelable.
    _ = try beforeToggle(instance, false, source);
    const subject = kept.get() orelse return;
    if (!hasOpen(subject)) return;
    // Step 4: queue a dialog toggle event task given subject, "open",
    // "closed" and source.
    queueToggleEventTask(subject, "open", "closed", source);
    // Step 5. Direct removal alone deliberately does NOT clear modal state.
    // Its attribute change steps run the dialog cleanup steps.
    dom.element_attributes.remove(subject, null, "open");
    // Steps 6–8. No rendering transition delays top-layer removal.
    const layer = try dom.top_layer.ofElement(subject, false);
    const modal_entry = if (layer) |state| state.findModal(subject) else null;
    const was_modal = modal_entry != null;
    if (modal_entry) |entry| layer.?.remove(entry.id);
    // Step 9 updates the internal IDL value without invoking a JS setter.
    if (return_value.wasPassed()) try set_returnValue(subject, return_value.value);
    // Steps 10-11: the request close return value and source element to
    // null.
    if (subject.getState(State).own._internal) |internal| {
        internal.setRequestCloseReturnValue(null);
        internal.setRequestCloseSource(null);
    }
    // Step 12 clears the saved member before running focus callbacks.
    if (subject.getState(State).own._internal) |internal| {
        const previous = internal.previous_focus.get();
        var previous_hold = if (previous) |element| try retain(element) else null;
        defer if (previous_hold) |*owned| owned.release();
        internal.previous_focus.release(subject, focus_slot);
        if (previous) |element| {
            const document = try nodeDocument(subject);
            const focused_inside = if (focus.designatedAreaOf(document)) |current| shadowDescendant(current, subject) else false;
            if (was_modal or focused_inside) focus.focusingSteps(element, null, .other);
        }
    }
    // Step 13: queue an element task on the user interaction task source
    // given subject to fire an event named close at subject.
    _ = dom.node_holds.ElementTask(DialogClose).queue(.{subject}, .{});
}

fn shadowDescendant(node: *Instance, ancestor: *Instance) bool {
    var current: ?*Instance = node;
    while (current) |item| {
        if (item == ancestor) return true;
        current = if (item.stateAs(interfaces.ShadowRoot.State) != null)
            interfaces.ShadowRoot.get_host(item) catch null
        else
            forms.parentOf(item);
    }
    return false;
}

fn dialogFocusingSteps(subject: *Instance) void {
    // Step 1.
    const document = nodeDocument(subject) catch return;
    if (!focus.allowFocusSteps(document)) return;
    // Steps 2–5: autofocus on the dialog takes precedence over its generic
    // focus delegate; an absent delegate falls back to the dialog itself.
    const control = if (forms.hasAttribute(subject, "autofocus"))
        subject
    else
        focus.focusDelegate(subject, .other) orelse subject;
    // The focus handler can remove/adopt control, collect it, or end its
    // realm. Keep it through steps 7–10, and revalidate after script.
    const kept = KeptInstance.of(control);
    var hold = retain(control) catch return;
    defer if (hold) |*owned| owned.release();
    // Step 6.
    focus.focusingSteps(control, null, .other);
    // Steps 7–10. No node navigable (native-only or removed frame): return.
    html.autofocus.completeForDialog(kept.get() orelse return);
}

/// HTML removing steps: modal state is cleared even without an open attr.
fn removingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    if (node.node_type != 1) return;
    const subject: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    if (subject.stateAs(State) == null) return;
    // Step 1: if removedNode has an open attribute, run the dialog cleanup
    // steps given it.
    if (hasOpen(subject)) cleanupSteps(subject);
    // Steps 2–3 remove modal membership without closing or restoring focus.
    const layer = (dom.top_layer.ofElement(subject, false) catch null) orelse return;
    if (layer.findModal(subject)) |entry| layer.remove(entry.id);
}

/// HTML 6.3.1: only the topmost modal's flat-tree subtree escapes blocking.
/// Null preserves the existing no-modal focus path.
fn modalInertness(node: *Instance) ?bool {
    const layer = (dom.top_layer.ofElement(node, false) catch null) orelse return null;
    const modal = layer.lastModal() orelse return null;
    if (!(interfaces.Node.get_isConnected(node) catch false)) return null;
    var inert = false;
    var current: ?*Instance = node;
    while (current) |item| {
        if (forms.hasAttribute(item, "inert") or html.forms.select_picker.isSelectButton(item)) inert = true;
        if (item == modal) return inert;
        current = flatParent(item);
    }
    return true;
}

fn flatParent(node: *Instance) ?*Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = forms.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    return parent;
}
