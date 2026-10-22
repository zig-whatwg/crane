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

    pub fn deinit(self: *InternalState) void {
        // As top_layer.State.releaseAfterRealmEnded: an orphan's realm can
        // have ended before the sweep. Its native hold must still unlink.
        if (self.owner.get() == null) self.previous_focus.kept = false;
        self.previous_focus.release(self.owner.instance, focus_slot);
        self.return_value.deinit(self.allocator);
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
    dom.dialog.install(.{ .show_modal = &showModal, .close = &closeDialog, .inert = &modalInertness });
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch |err| {
        log.warn("dialog removing steps not registered: {}", .{err});
    };
    States.installSweep();
    // TODO(closewatch1, row85 Q3): insertion steps 1–2 and open-attribute
    // change steps 1–6 run dialog setup/cleanup. Their open-dialog list and
    // close watcher belong to the routed Window-owned manager.
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

pub fn call_requestClose(instance: *Instance, return_value: webidl.Opt(runtime.DOMString)) !void {
    // Request-to-close steps 1–2 are independent of the pending manager.
    if (!hasOpen(instance) or !(try interfaces.Node.get_isConnected(instance))) return;
    const document = try nodeDocument(instance);
    if (!dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return;
    _ = return_value;
    // TODO(closewatch1, row85 Q3): steps 3–8 require the shared close watcher,
    // including cancel-action recursion and its source/return-value slots.
    return error.NotImplemented;
}

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
    // TODO(closewatch1, feature-queue :1091): step 5 queues/coalesces the
    // dialog toggle task, holding the dialog and its source until run/drop.
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
    // TODO(closewatch1, feature-queue :1091): step 10 queues the toggle task.
    // Step 11.
    try dom.element_attributes.set(subject, "open", "", .{});
    // TODO(closewatch1, row85 Q3): step 12 asserts the watcher installed by
    // the open attribute's setup steps.
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
    // TODO(closewatch1, feature-queue :1091): step 4 queues the toggle task.
    // Step 5. Direct removal alone deliberately does NOT clear modal state.
    dom.element_attributes.remove(subject, null, "open");
    // Steps 6–8. No rendering transition delays top-layer removal.
    const layer = try dom.top_layer.ofElement(subject, false);
    const modal_entry = if (layer) |state| state.findModal(subject) else null;
    const was_modal = modal_entry != null;
    if (modal_entry) |entry| layer.?.remove(entry.id);
    // Step 9 updates the internal IDL value without invoking a JS setter.
    if (return_value.wasPassed()) try set_returnValue(subject, return_value.value);
    // TODO(closewatch1, row85 Q3): steps 10–11 clear request-close slots.
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
    // TODO(closewatch1, feature-queue :1091): step 13 queues the trusted
    // close event on the user-interaction task source, never synchronously.
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
    // TODO(closewatch1, row85 Q3): step 1 runs dialog cleanup when open.
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
