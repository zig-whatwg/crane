//! HTML 6.12 popovers, cached 2026-10-17. Document owns the top layer;
//! this module implements its algorithms without a rendering backend.
//! Design: Blink HTMLElement::ShowPopoverInternal / HidePopoverInternal
//! revalidate after callbacks and trace their stack snapshots.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const forms = @import("form_associated.zig");
const focus = @import("focus.zig");
const layer = dom.top_layer;
const Instance = runtime.Instance;
const Mode = layer.Mode;

fn attributeMode(value: ?[]const u8) ?Mode {
    const text = value orelse return null;
    if (text.len == 0 or std.ascii.eqlIgnoreCase(text, "auto")) return .auto;
    if (std.ascii.eqlIgnoreCase(text, "hint")) return .hint;
    return .manual;
}

fn mode(element: *Instance) ?Mode {
    const data = dom.element_data.of(element) orelse return null;
    const attr = data.findAttribute(null, "popover") orelse return null;
    return attributeMode(attr.value);
}

fn nodeDocument(element: *Instance) !*Instance {
    return (try interfaces.Node.get_ownerDocument(element)) orelse error.InvalidStateError;
}

fn showingKind(element: *Instance, picker: bool) bool {
    const state = (layer.ofElement(element, false) catch null) orelse return false;
    return state.findKind(element, picker) != null;
}

pub const showing = layer.showing;

/// Check popover validity, steps 1–4. A select picker is the select's
/// anonymous Auto popover, represented by the host plus a distinct entry.
fn valid(element: *Instance, expected_showing: bool, expected_document: ?*Instance, picker: bool) !bool {
    if (!picker and mode(element) == null) return error.NotSupportedError;
    if (showingKind(element, picker) != expected_showing) return false;
    const document = try nodeDocument(element);
    if ((!expected_showing and (!(try interfaces.Node.get_isConnected(element)) or
        !dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document)))) or
        (expected_document != null and expected_document != document)) return error.InvalidStateError;
    // TODO(dialog/CloseWatcher row after row 61): the modal owner will
    // supply this existing hook; until then no dialog can become modal.
    if (dom.html_pseudo_classes.matches(element, .modal) or
        (try interfaces.Document.get_fullscreenElement(document)) == element) return error.InvalidStateError;
    return true;
}

fn validate(element: *Instance, expected: bool, document: ?*Instance, picker: bool, throws: bool) !bool {
    return valid(element, expected, document, picker) catch |err| {
        if (throws) return err;
        return false;
    };
}

fn beforeToggle(element: *Instance, opening: bool, source: ?*Instance) !bool {
    const event = try interfaces.ToggleEvent.call_constructor(element.ctx, runtime.DOMString.initInterned("beforetoggle"), .passed(.{
        .base = .{ .cancelable = opening },
        .oldState = runtime.DOMString.initInterned(if (opening) "closed" else "open"),
        .newState = runtime.DOMString.initInterned(if (opening) "open" else "closed"),
        .source = source,
    }));
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(element, event);
}

fn flatParent(node: *Instance) ?*Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = forms.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    return parent;
}

fn flatDescendant(node: *Instance, ancestor: *Instance, inclusive: bool) bool {
    var current = if (inclusive) @as(?*Instance, node) else flatParent(node);
    while (current) |item| : (current = flatParent(item)) if (item == ancestor) return true;
    return false;
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

fn topmost(state: *layer.State, wanted: ?Mode) ?*layer.Entry {
    // The combined list puts hints after autos, independent of top-layer
    // order. Manual popovers belong to neither stack.
    for ([_]Mode{ .hint, .auto }) |kind| {
        if (wanted != null and wanted != kind) continue;
        var i = state.entries.items.len;
        while (i != 0) {
            i -= 1;
            const entry = state.entries.items[i];
            if (entry.showing and entry.mode == kind) return entry;
        }
    }
    return null;
}

fn topmostAncestor(state: *layer.State, element: *Instance, source: ?*Instance) ?*layer.Entry {
    for ([_]Mode{ .hint, .auto }) |kind| {
        var i = state.entries.items.len;
        while (i != 0) {
            i -= 1;
            const entry = state.entries.items[i];
            if (!entry.showing or entry.mode != kind) continue;
            const ancestor = entry.node() orelse continue;
            if (flatDescendant(element, ancestor, false) or
                (if (source) |s| flatDescendant(s, ancestor, false) else false)) return entry;
        }
    }
    return null;
}

/// Hide stack until, steps 1–8: snapshot both slices with marked holds.
/// A beforetoggle handler can remove any item, including a later one.
fn hideStack(state: *layer.State, endpoint: ?*Instance, kind: Mode, restore: bool, events: bool) anyerror!void {
    const Item = struct { pin: usize, picker: bool, remain: bool };
    var snapshot: std.ArrayListUnmanaged(Item) = .empty;
    defer {
        for (snapshot.items) |item| state.remove(item.pin);
        snapshot.deinit(state.allocator);
    }
    var last_hide: usize = 0;
    const original_len = state.entries.items.len;
    for (state.entries.items[0..original_len], 0..) |entry, i| {
        if (entry.showing and entry.mode == kind and entry.node() == endpoint) last_hide = i + 1;
    }
    // pin() can grow entries, so never retain a slice of that list here.
    var i: usize = 0;
    while (i < original_len) : (i += 1) {
        const entry = state.entries.items[i];
        if (!entry.showing or entry.mode != kind) continue;
        const picker = entry.picker;
        const pin = try state.pin(entry.node() orelse continue);
        snapshot.append(state.allocator, .{ .pin = pin.id, .picker = picker, .remain = i < last_hide }) catch |err| {
            state.remove(pin.id);
            return err;
        };
    }
    i = snapshot.items.len;
    while (i != 0) {
        i -= 1;
        const item = snapshot.items[i];
        if (!item.remain) if (state.byId(item.pin).?.node()) |node| try hide(node, restore, events, false, null, item.picker);
    }
    // Show is forbidden while hide callbacks run. The second pass still
    // implements the spec's check for any unexpected additional entries.
    while (topmost(state, kind)) |entry| {
        var remains = false;
        for (snapshot.items) |item| {
            if (item.remain and state.byId(item.pin).?.node() == entry.node() and item.picker == entry.picker) {
                remains = true;
                break;
            }
        }
        if (remains) break;
        const id = entry.id;
        try hide(entry.node() orelse break, restore, false, false, null, entry.picker);
        if (state.byId(id) != null) break;
    }
}

pub fn hidePopoversUntil(document: *Instance, endpoint: ?*Instance, restore: bool, events: bool) anyerror!void {
    const state = (try layer.ofDocument(document, false)) orelse return;
    const is_hint = if (endpoint) |node| if (state.find(node) orelse state.findKind(node, true)) |entry| entry.mode == .hint else false else false;
    // Keep the endpoint while another stack's closing event removes it.
    const pin = if (endpoint) |node| try state.pin(node) else null;
    defer if (pin) |entry| state.remove(entry.id);
    try hideStack(state, endpoint, .hint, restore, events);
    try hideStack(state, if (is_hint) state.hint_parent.get() else endpoint, .auto, restore, events);
}

pub fn showPopover(element: *Instance, throw_exceptions: bool, source: ?*Instance) anyerror!void {
    try show(element, throw_exceptions, source, false);
}

pub fn showPicker(select: *Instance) anyerror!void {
    // HTML "open the picker", step 3: the select is the source of its
    // anonymous popover, including for the topmost-ancestor relation.
    try show(select, false, select, true);
}

fn show(element: *Instance, throws: bool, source: ?*Instance, picker: bool) anyerror!void {
    const document = try nodeDocument(element);
    const state = (try layer.ofDocument(document, true)) orelse return;
    // Show steps 2–8: forbid reentrant show, even during another hide.
    if (state.showing_popover or state.hiding_nesting != 0) {
        if (throws) return error.InvalidStateError;
        return;
    }
    if (!try validate(element, false, null, picker, throws)) return;
    const pin = try state.pin(element);
    const pin_id = pin.id;
    defer state.remove(pin_id);
    pin.keepSource(document, source);
    state.showing_popover = true;
    defer state.showing_popover = false;
    // The anonymous select picker has no script-visible event target.
    if (!picker and !try beforeToggle(element, true, source)) return;
    if (!try validate(element, false, document, picker, throws)) return;
    const original = if (picker) Mode.auto else mode(element).?;
    var effective = original;
    var restore = false;
    var ancestor_pin: ?usize = null;
    defer if (ancestor_pin) |id| state.remove(id);
    if (original != .manual) {
        if (topmostAncestor(state, element, source)) |ancestor| {
            if (ancestor.mode == .hint) effective = .hint;
            ancestor_pin = (try state.pin(ancestor.node().?)).id;
        }
        const ancestor = if (ancestor_pin) |id| state.byId(id).?.node() else null;
        try hideStack(state, ancestor, .hint, false, true);
        if (effective == .auto) try hideStack(state, ancestor, .auto, false, true);
        if (!picker and original != mode(element)) {
            if (throws) return error.InvalidStateError;
            return;
        }
        if (!try validate(element, false, document, picker, throws)) return;
        restore = topmost(state, null) == null;
        // TODO(dialog/CloseWatcher row after row 61): show step 15.10,
        // establish the popover's close watcher. No private substitute.
    }
    pin.keepPreviousFocus(document, focus.designatedAreaOf(document));
    const active = try state.pin(element);
    active.mode = effective;
    active.picker = picker;
    active.showing = true;
    active.keepSource(document, source);
    if (picker) try dom.form_controls.setPickerOpen(element, true);
    if (effective == .hint) if (ancestor_pin) |id| {
        const ancestor = state.byId(id).?.node();
        if (ancestor) |node| if (state.find(node) orelse state.findKind(node, true)) |entry| {
            if (entry.mode == .auto) state.setHintParent(node);
        };
    };
    // Steps 23–24. Focus listeners may hide/remove the active entry.
    if (picker) @import("forms/select_picker.zig").focusPicker(element) else focusingSteps(element);
    if (restore) if (state.findKind(element, picker)) |entry| entry.keepPreviousFocus(document, pin.previous_focus.get());
    // TODO(unwrapped task holder, row 52 Q9 / row 61 Q3(c)): step 26,
    // queue/coalesce the popover toggle event task. Never fire it inline.
}

/// The fixed command-owner API suppresses exceptions, as HTML activation
/// does. The IDL method below requests exceptions separately.
pub fn hidePopover(element: *Instance, focus_previous: bool, fire_events: bool, source: ?*Instance) anyerror!void {
    try hide(element, focus_previous, fire_events, false, source, false);
}

pub fn hideMethod(element: *Instance) anyerror!void {
    try hide(element, true, true, true, null, false);
}

pub fn hidePicker(select: *Instance, restore: bool) anyerror!void {
    try hide(select, restore, true, false, null, true);
}

fn hide(element: *Instance, restore: bool, events: bool, throws: bool, source: ?*Instance, picker: bool) anyerror!void {
    try hideImpl(element, restore, events, throws, source, picker, false);
}

fn validateHide(element: *Instance, document: ?*Instance, picker: bool, throws: bool, attribute_change: bool) !bool {
    if (attribute_change and mode(element) == null) {
        if (!showingKind(element, picker)) return false;
        if (document != null and document != (try nodeDocument(element))) {
            if (throws) return error.InvalidStateError;
            return false;
        }
        return true;
    }
    return validate(element, true, document, picker, throws);
}

fn hideImpl(element: *Instance, restore: bool, events: bool, throws: bool, source: ?*Instance, picker: bool, attribute_change: bool) anyerror!void {
    if (!try validateHide(element, null, picker, throws, attribute_change)) return;
    const document = try nodeDocument(element);
    const state = (try layer.ofDocument(document, false)).?;
    const active = state.findKind(element, picker) orelse return;
    const nested = active.hiding;
    active.hiding = true;
    state.hiding_nesting += 1;
    defer {
        if (!nested) if (state.findKind(element, picker)) |entry| {
            entry.hiding = false;
        };
        state.hiding_nesting -= 1;
    }
    const fire = events and !nested;
    const opened = active.mode;
    const pin = try state.pin(element);
    defer state.remove(pin.id);
    pin.keepSource(document, source);
    pin.keepPreviousFocus(document, active.previous_focus.get());
    // Hide steps 9–11. Stacks are derived from top-layer membership.
    if (opened != .manual) {
        if (opened == .hint) try hideStack(state, element, .hint, restore, fire);
        if (state.hint_parent.get() == element) try hideStack(state, null, .hint, restore, fire);
        if (opened == .auto) try hideStack(state, element, .auto, restore, fire);
        if (!try validateHide(element, document, picker, throws, attribute_change)) return;
    }
    if (fire and !picker) {
        _ = try beforeToggle(element, false, source);
        if (!try validateHide(element, document, picker, throws, attribute_change)) return;
    }
    // Capture the designation before making picker options unfocusable.
    // Crane's focusedAreaOf applies focus fixup on read; browsers perform
    // that fixup during rendering, after this restoration step.
    const focus_inside = if (focus.designatedAreaOf(document)) |current| shadowDescendant(current, element) else false;
    // No rendering transition: remove immediately after beforetoggle.
    if (state.findKind(element, picker)) |entry| state.remove(entry.id);
    if (state.hint_parent.get() == element or topmost(state, .hint) == null) state.setHintParent(null);
    // TODO(unwrapped task holder, row 52 Q9 / row 61 Q3(c)): hide step18,
    // queue the toggle task when fire is true.
    // The anonymous picker uses HTML's generic restoration too (row61
    // Q19). A click-opened picker saved the select; showPicker() may have
    // saved another element. Do not add Blink's subsequent select focus.
    if (restore and focus_inside) if (pin.previous_focus.get()) |previous| focus.focusingSteps(previous, null, .other);
    // TODO(dialog/CloseWatcher row after row 61): hide step21 destroys
    // the watcher established by show step15.10.
}

pub fn focusingSteps(subject: *Instance) void {
    // Popover focusing steps 1–6; focusingSteps checks allow-focus itself.
    // TODO(dialog/CloseWatcher row after row 61): dialog focusing delegate.
    const control = if (forms.hasAttribute(subject, "autofocus")) subject else focus.autofocusDelegate(subject, .other) orelse return;
    focus.focusingSteps(control, null, .other);
    // TODO(autofocus owner, row55 Q1 / row61 Q10): steps 7–10 require
    // the general autofocus queue and processed flag.
}

pub fn attributeChanged(element: *Instance, _: []const u8, old: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null or attributeMode(old) == attributeMode(value)) return;
    // Deviation: the attribute-change steps call hide after removal, while
    // validity step1 now rejects the missing attribute. Browsers hide the
    // prior showing entry: wpt.fyi df642c4142, popover-attribute-basic.html,
    // Chrome155/Firefox158 249/249, Safari27 186/249 (row61 Q12).
    // Use the same reentrancy, stack and focus algorithm; only this initial
    // prior-entry transition permits the absent attribute.
    hideImpl(element, true, true, false, null, false, true) catch {};
}

pub fn removingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    if (node.node_type != 1) return;
    const element: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    const state = (layer.ofElement(element, false) catch null) orelse return;
    // HTML removal steps: hide without events or focus restoration.
    if (state.find(element) != null) hide(element, false, false, false, null, false) catch {};
    if (state.findKind(element, true) != null) hide(element, false, false, false, null, true) catch {};
    if (state.pointerdown_target.get() == element) state.setPointerdownTarget(null);
}

pub fn toggleMethod(element: *Instance, value: ?runtime.JSValue) !bool {
    var force: ?bool = null;
    var source: ?*Instance = null;
    if (value) |options| {
        const kind = engine.typeOf(element.ctx, options);
        if (kind == .boolean) force = engine.toBoolean(element.ctx, options) else if (kind == .object and !options.isNullOrUndefined()) {
            force = try engine.getPropertyBoolean(element.ctx, options, "force");
            source = try engine.getPropertyPlatformObject(element.ctx, options, "source");
            if (source) |node| if (node.stateAs(interfaces.HTMLElement.State) == null) return error.TypeError;
        } else if (kind != .undefined and kind != .null) force = engine.toBoolean(element.ctx, options);
    }
    if (showing(element) and force != true) try hideMethod(element) else if (force != false) try showPopover(element, true, source) else _ = try valid(element, showing(element), null, false);
    return showing(element);
}

fn stackPosition(state: *layer.State, node: ?*Instance) usize {
    if (node == null) return 0;
    var position: usize = 0;
    for ([_]Mode{ .auto, .hint }) |kind| for (state.entries.items) |entry| {
        if (!entry.showing or entry.mode != kind) continue;
        position += 1;
        if (entry.node() == node) return position;
    };
    return 0;
}

/// Target popover / popover target element, read-only resolution. Explicit
/// popoverTargetElement IDL references await their owners' holder-backed API
/// (row61 Q12); content attributes use the existing tree-scoped ID lookup.
fn targetPopover(node: *Instance) ?*Instance {
    const button = node.stateAs(interfaces.HTMLButtonElement.State) != null;
    if (!button and !forms.isInput(node)) return null;
    if (forms.isDisabled(node)) return null;
    const data = dom.element_data.of(node) orelse return null;
    var target: ?*Instance = null;
    if (button) target = interfaces.HTMLButtonElement.get_commandForElement(node) catch null;
    if (target != null) {
        if (forms.formOwner(node) != null and (forms.isSubmitButton(node) or forms.buttonType(node) == .reset or forms.buttonType(node) == .auto)) return null;
        const command = (data.findAttribute(null, "command") orelse return null).value;
        if (!std.ascii.eqlIgnoreCase(command, "toggle-popover") and !std.ascii.eqlIgnoreCase(command, "show-popover") and !std.ascii.eqlIgnoreCase(command, "hide-popover")) return null;
    } else {
        if (!button) {
            var buffer: [16]u8 = undefined;
            const kind = forms.inputType(node, &buffer);
            if (!std.mem.eql(u8, kind, "button") and !std.mem.eql(u8, kind, "submit") and !std.mem.eql(u8, kind, "reset") and !std.mem.eql(u8, kind, "image")) return null;
        }
        if (forms.formOwner(node) != null and forms.isSubmitButton(node)) return null;
        const id = (data.findAttribute(null, "popovertarget") orelse return null).value;
        target = forms.firstElementWithId(forms.rootOf(node), id);
    }
    const result = target orelse return null;
    return if (mode(result) != null) result else null;
}

fn topmostClicked(state: *layer.State, target: *Instance) ?*Instance {
    var clicked: ?*Instance = null;
    var invoked: ?*Instance = null;
    var current: ?*Instance = target;
    while (current) |node| : (current = flatParent(node)) {
        if (clicked == null and stackPosition(state, node) != 0) clicked = node;
        if (invoked == null) if (targetPopover(node)) |popover| {
            if (stackPosition(state, popover) != 0) invoked = popover;
        };
        if (clicked != null and invoked != null) break;
    }
    return if (stackPosition(state, clicked) > stackPosition(state, invoked)) clicked else invoked;
}

/// HTML light dismiss steps 1–6, called only for trusted pointerdown/up.
/// Geometry/hit testing belongs to the host; this uses the dispatched target.
/// No connectedness exception: Firefox 158 and Safari 27 both dismiss in
/// light-dismiss-remove-target.html (wpt.fyi df642c4142), agreeing with the
/// spec's null-ancestor comparison; Chrome's expectation differs (row61 Q41).
pub fn lightDismiss(target: *Instance, down: bool) void {
    const document = nodeDocument(target) catch return;
    const state = (layer.ofDocument(document, false) catch null) orelse return;
    if (topmost(state, null) == null) {
        if (!down) state.setPointerdownTarget(null);
        return;
    }
    const ancestor = topmostClicked(state, target);
    if (down) {
        state.setPointerdownTarget(ancestor);
    } else {
        const same = ancestor == state.pointerdown_target.get();
        // The endpoint is showing and kept by its stack while the
        // pointerdown slot is cleared. hidePopoversUntil pins its snapshot.
        state.setPointerdownTarget(null);
        if (same) hidePopoversUntil(document, ancestor, false, true) catch {};
    }
}
