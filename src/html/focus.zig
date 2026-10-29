//! HTML 6.6 Focus: focusable areas, the focus chain, the focusing,
//! unfocusing and focus update steps, sequential focus navigation, and the
//! activeElement getter's steps.
//!
//! A document's focused area is Document's state, designated through the
//! hook Document installs (dom.focused_area). Designation reads use
//! `designatedAreaOf`, without requesting style or performing fixup.
//! `focusedAreaOf` is the separate rendering-time focus fixup.
//! Elements are reached
//! through their interfaces; the navigables through their Browser's list of
//! browsing contexts (dom.browser_state).
//!
//! Stated deviations:
//!   * "Being rendered" has no layout to answer it: computed display and
//!     flat-tree membership answer whether rendering exists or is delegated.
//!   * Every top-level traversable is taken to have system focus.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#focus

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const form_associated = @import("form_associated.zig");

const Instance = runtime.Instance;
const log = std.log.scoped(.focus);

/// The focusing steps' focus trigger.
pub const Trigger = enum { other, click, keyboard };

// ============================================================================
// Nodes, documents and navigables
// ============================================================================

fn isElement(node: *Instance) bool {
    return form_associated.isElement(node);
}

fn isDocument(node: *Instance) bool {
    const node_type = interfaces.Node.get_nodeType(node) catch return false;
    return node_type == interfaces.Node.get_DOCUMENT_NODE();
}

/// `node`'s node document (a Document is its own).
fn nodeDocument(node: *Instance) ?*Instance {
    if (isDocument(node)) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}

fn windowOf(document: *Instance) ?*Instance {
    return interfaces.Document.get_defaultView(document) catch null;
}

/// The navigable container (an iframe) whose content navigable's active
/// document is `document`, or null for a top-level document.
pub fn containerOf(document: *Instance) ?*Instance {
    const window = windowOf(document) orelse return null;
    return dom.navigable_container.of(window);
}

/// The active document of `container`'s content navigable, or null.
fn contentDocumentOf(container: *Instance) ?*Instance {
    // The container's Browser's list, which its content navigable is on.
    const navigables = dom.browser_state.navigablesOf(container.ctx) orelse return null;
    for (navigables.contexts()) |context| {
        if (context.orphaned) continue;
        const owner = context.container orelse continue;
        if (@as(*Instance, @ptrCast(@alignCast(owner))) != container) continue;
        const document = context.getActiveDocument() orelse return null;
        return @ptrCast(@alignCast(document));
    }
    return null;
}

/// The active document of the top-level traversable `document` is in.
pub fn topLevelDocumentOf(document: *Instance) *Instance {
    var current = document;
    var depth: usize = 0;
    while (containerOf(current)) |container| : (depth += 1) {
        if (depth == 64) break;
        current = nodeDocument(container) orelse break;
    }
    return current;
}

// ============================================================================
// Focusable areas (6.6.2, 6.6.3)
// ============================================================================

/// HTML integer parsing with the tabindex IDL-long range. The existing
/// reflection parser owns the syntax, including which whitespace to skip.
fn parseInteger(input: []const u8) ?i32 {
    const parsed = dom.reflection.parseInteger(input) orelse return null;
    if (parsed < std.math.minInt(i32) or parsed > std.math.maxInt(i32)) return null;
    return @intCast(parsed);
}

/// The "tabindex value" of `element`: its tabindex attribute parsed with the
/// rules for parsing integers, or null.
pub fn tabindexValue(element: *Instance) ?i32 {
    if (!form_associated.hasAttribute(element, "tabindex")) return null;
    var value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("tabindex")) catch null) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return parseInteger(value.asSlice());
}

fn named(element: *Instance, comptime name: []const u8) bool {
    return form_associated.isElementNamed(element, name);
}

/// Whether `element` is an editing host: contenteditable in the true or
/// plaintext-only state.
fn isEditingHost(element: *Instance) bool {
    if (!form_associated.hasAttribute(element, "contenteditable")) return false;
    var value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("contenteditable")) catch null) orelse return false;
    defer value.deinit(element.ctx.allocator);
    const v = value.asSlice();
    return v.len == 0 or std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "plaintext-only");
}

/// A summary element that is its parent details element's first summary
/// child.
fn isSummaryForParentDetails(element: *Instance) bool {
    if (!named(element, "summary")) return false;
    const parent = form_associated.parentOf(element) orelse return false;
    if (!named(parent, "details")) return false;
    var child = interfaces.Node.get_firstChild(parent) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (named(c, "summary")) return c == element;
    }
    return false;
}

fn isNavigableContainer(element: *Instance) bool {
    return named(element, "iframe") or named(element, "frame");
}

/// The elements "should be considered as focusable areas and be sequentially
/// focusable" when their tabindex value is null (6.6.3).
fn isFocusableByDefault(element: *Instance) bool {
    if (named(element, "a")) return form_associated.hasAttribute(element, "href");
    if (element.stateAs(interfaces.HTMLOptionElement.State) != null) return @import("forms/select_picker.zig").optionFocusable(element);
    if (form_associated.isSelect(element)) return !(@import("forms/select_picker.zig").isListbox(element) and @import("forms/select_picker.zig").baseAppearance(element));
    if (form_associated.isButton(element) or form_associated.isTextArea(element)) return true;
    if (form_associated.isInput(element)) {
        var buffer: [16]u8 = undefined;
        return !std.mem.eql(u8, form_associated.inputType(element, &buffer), "hidden");
    }
    // Golden rule 2 / row85 Q12: dialog focusing step 6's note leaves this
    // to the UA; no newer spec mandates exclusion from sequential focus.
    // wpt.fyi revision 23b0b89b1a, dialog-focusability.html: Chrome 155 PASS,
    // Firefox 158 and Safari 27 FAIL at step 2/11 by tabbing to dialog1.
    // https://wpt.fyi/results/html/semantics/interactive-elements/the-dialog-element/dialog-focusability.html?sha=23b0b89b1a&label=stable
    // Gecko HTMLDialogElement::TabIndexDefault returns 0:
    // https://searchfox.org/mozilla-central/source/dom/html/HTMLDialogElement.cpp
    // WebKit HTMLDialogElement::supportsFocus returns true:
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLDialogElement.cpp
    if (named(element, "dialog")) return true;
    return isSummaryForParentDetails(element) or isNavigableContainer(element) or isEditingHost(element);
}

/// HTML "actually disabled" (4.15), including custom form controls (4.10.19.5).
fn isActuallyDisabled(element: *Instance) bool {
    if (form_associated.isButton(element) or form_associated.isInput(element) or
        form_associated.isSelect(element) or form_associated.isTextArea(element) or named(element, "fieldset") or
        form_associated.isFormAssociatedCustom(element))
    {
        return form_associated.isDisabled(element);
    }
    if (named(element, "optgroup")) return form_associated.hasAttribute(element, "disabled");
    if (named(element, "option")) {
        // HTML option disabledness (cached 2026-10-17) crosses ordinary
        // wrappers and stops at the nearest optgroup or ownership barrier.
        return @import("forms/options.zig").isDisabled(element);
    }
    return false;
}

/// HTML "inert": an inclusive ancestor has the inert attribute or is a
/// select's own button (4.10.6), whose whole subtree is inert.
pub fn isHostInert(node: *Instance) bool {
    if (dom.dialog.inertness(node)) |inert| return inert;
    var current: ?*Instance = node;
    while (current) |n| : (current = form_associated.parentOf(n)) {
        // HTML 6.3.2: inert is an HTML global attribute, not a foreign one.
        const inert_attribute = form_associated.hasAttribute(n, "inert") and html_namespace: {
            var namespace = (interfaces.Element.get_namespaceURI(n) catch null) orelse break :html_namespace false;
            defer namespace.deinit(n.ctx.allocator);
            break :html_namespace std.mem.eql(u8, namespace.asSlice(), "http://www.w3.org/1999/xhtml");
        };
        if (isElement(n) and (inert_attribute or
            @import("forms/select_picker.zig").isSelectButton(n))) return true;
    }
    return false;
}

/// CSS UI 4 §6.3 adds target computed inertness after HTML's own rule.
/// A modal's authoritative host escape does not bypass its own CSS value.
fn isInert(node: *Instance) bool {
    if (isHostInert(node)) return true;
    if (!isElement(node)) return false;
    const style = (dom.style.engine.computedStyle(node, null) catch null) orelse return false;
    return style.keyword(.interactivity) == .inert;
}

/// HTML 6.6.2 accepts rendered elements and those delegating rendering to
/// their children. The style owner checks flat-tree membership and display
/// on the element and its ancestors, including display:contents (Q35/Q37).
fn isBeingRendered(element: *Instance) bool {
    if (!(interfaces.Node.get_isConnected(element) catch false)) return false;
    // A document with no browsing context (`new Document()`) renders nothing.
    const document = nodeDocument(element) orelse return false;
    if (windowOf(document) == null) return false;
    return dom.style.engine.isRenderedForFocus(element) catch false;
}

/// Whether `element` is a focusable area (6.6.2's first row): its tabindex
/// value is non-null or it is focusable by default, it is not actually
/// disabled, not inert, and being rendered.
pub fn isFocusableArea(element: *Instance) bool {
    if (!isElement(element)) return false;
    if (element.stateAs(interfaces.HTMLAreaElement.State) != null) return isImageMapAreaFocusable(element);
    if (tabindexValue(element) == null and !isFocusableByDefault(element)) return false;
    // HTML 6.6.2: a slot without a box owns a navigation scope but is not
    // itself a focusable area. A styled slot that generates a box can be.
    if (element.vtable == &interfaces.HTMLSlotElement.vtable) {
        const style = (dom.style.engine.computedStyle(element, null) catch null) orelse return false;
        if (style.display().box == .contents) return false;
    }
    // HTML 6.6.2, first row: a host that delegates focus is not itself a
    // focusable area, even with a tabindex. Focusing step 1 finds its delegate.
    if (delegatingShadowRoot(element) != null) return false;
    if (isActuallyDisabled(element)) return false;
    if (isHostInert(element)) return false;
    return isBeingRendered(element);
}

/// Whether `element` is click focusable: every focusable area (as in Blink
/// and Gecko on non-Mac platforms).
pub fn isClickFocusable(element: *Instance) bool {
    return isFocusableArea(element);
}

/// Whether `element` is sequentially focusable: a focusable area whose
/// tabindex value is not negative.
pub fn isSequentiallyFocusable(element: *Instance) bool {
    if (!isFocusableArea(element)) return false;
    if (element.stateAs(interfaces.HTMLOptionElement.State) != null) {
        const picker = @import("forms/select_picker.zig");
        if (picker.ownerSelect(element)) |select| {
            if (picker.isListbox(select) and picker.baseOptions(select)) return picker.firstFocusable(select, true) == element;
        }
    }
    if ((tabindexValue(element) orelse 0) < 0) return false;
    return @import("forms/radio_focus.zig").isSequentialRepresentative(element);
}

// ============================================================================
// The focused area of a document, and of a top-level traversable (6.6.2)
// ============================================================================

/// The DOM anchor designated in this document, or null for its viewport.
/// HTML 6.6.2's designation and 6.6.6's activeElement step 1 are reads, not
/// focusability checks. The generation, connection and document checks
/// observe synchronous removing steps without style or state writes.
pub fn designatedAreaOf(document: *Instance) ?*Instance {
    const designation = dom.focused_area.get(document) orelse return null;
    if (!designation.isLive()) return null;
    const element = designation.element;
    if (!(interfaces.Node.get_isConnected(element) catch false) or nodeDocument(element) != document) return null;
    return element;
}

/// Apply rendering-time focus fixup and return the document's focused area.
///
/// HTML update-the-rendering step 17 focuses the viewport when its focused
/// area stops being focusable, then clears the navigation focus flag.
/// Designation reads never repair focus. Blink Document's
/// ClearFocusedElementIfNeeded/TimerFired at 8d5ba1795f0c50b90072399d0403389df6eebbd6
/// defers an element.blur() until style has updated. Use this existing
/// rendering opportunity and focus update steps, without a new timer.
pub fn focusedAreaOf(document: *Instance) ?*Instance {
    if (dom.focused_area.get(document) == null) return null;
    if (designatedAreaOf(document)) |element| {
        if (isFocusableArea(element)) return element;
        const generation = runtime.SlabAllocator.generationOf(document);
        focusUpdateSteps(focusChain(element), focusChain(document), document);
        // A blur listener can navigate or choose a new focus target. The
        // existing update steps preserve that target; do not clear it here.
        if (runtime.SlabAllocator.generationOf(document) != generation) return null;
        if (windowOf(document)) |window| dom.navigation_api.setFocusChanged(window, false);
        return designatedAreaOf(document);
    }
    dom.focused_area.set(document, null);
    // HTML removing steps, applied lazily with this focus fixup: removal
    // clears the navigation flag rather than counting as a focus update.
    if (windowOf(document)) |window| dom.navigation_api.setFocusChanged(window, false);
    return null;
}

/// HTML "currently focused area of a top-level traversable", for the one
/// `document` is in: an element, or a Document standing for its viewport.
pub fn currentlyFocusedArea(document: *Instance) *Instance {
    // Step 1: every traversable has system focus (stated deviation).
    // Step 2: "Let candidate be traversable's active document."
    var candidate = topLevelDocumentOf(document);
    // Step 3: while its focused area is a navigable container with a content
    // navigable, descend into that navigable's active document.
    var depth: usize = 0;
    while (designatedAreaOf(candidate)) |area| : (depth += 1) {
        if (depth == 64 or !isNavigableContainer(area)) break;
        candidate = contentDocumentOf(area) orelse break;
    }
    // Steps 4-5.
    return designatedAreaOf(candidate) orelse candidate;
}

/// HTML "has focus steps" for `document`.
pub fn hasFocus(document: *Instance) bool {
    var candidate = topLevelDocumentOf(document);
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        if (candidate == document) return true;
        // Has-focus steps 3.2–3.3 read the designation, without fixup.
        const area = designatedAreaOf(candidate) orelse return false;
        if (!isNavigableContainer(area)) return false;
        candidate = contentDocumentOf(area) orelse return false;
    }
    return false;
}

// ============================================================================
// The focus chain and the focus update steps (6.6.4)
// ============================================================================

/// A focus chain: elements and Documents (a Document stands for its
/// viewport), each with its slab generation, since the dispatches between
/// entries run script.
const Chain = struct {
    const capacity = 32;
    items: [capacity]*Instance = undefined,
    generations: [capacity]u64 = undefined,
    len: usize = 0,

    fn append(self: *Chain, object: *Instance) void {
        if (self.len == capacity) return;
        self.items[self.len] = object;
        self.generations[self.len] = runtime.SlabAllocator.generationOf(object);
        self.len += 1;
    }

    fn last(self: *const Chain) ?*Instance {
        return if (self.len == 0) null else self.items[self.len - 1];
    }

    fn isLive(self: *const Chain, index: usize) bool {
        return runtime.SlabAllocator.generationOf(self.items[index]) == self.generations[index];
    }
};

/// HTML "focus chain" of `subject`, an element or a Document: the subject,
/// then up through the documents and navigable containers to the top-level
/// traversable's document.
fn focusChain(subject: *Instance) Chain {
    var chain: Chain = .{};
    var current: ?*Instance = subject;
    while (current) |object| {
        chain.append(object);
        if (chain.len == Chain.capacity) break;
        // Step 3.3: a focusable area continues at its DOM anchor's node
        // document; a Document whose navigable has a parent, at that
        // navigable's container (the object that stands for it in its
        // parent document).
        current = if (isElement(object)) nodeDocument(object) else if (isDocument(object)) containerOf(object) else null;
    }
    return chain;
}

/// HTML "fire a focus event" named `event_type` at `target` with related
/// target `related`, then the UI Events focusin/focusout companion when the
/// target is an element (browsers fire it right after, as Blink's
/// Element::DispatchFocusInEvent does).
fn fireFocusEvent(target: *Instance, comptime event_type: []const u8, related: ?*Instance) void {
    const view: ?*Instance = if (isElement(target)) (if (nodeDocument(target)) |d| windowOf(d) else null) else target;
    fireFocusEventNamed(target, event_type, related, view, false);
    if (!isElement(target)) return;
    const companion = comptime if (std.mem.eql(u8, event_type, "focus")) "focusin" else "focusout";
    fireFocusEventNamed(target, companion, related, view, true);
}

fn fireFocusEventNamed(target: *Instance, comptime event_type: []const u8, related: ?*Instance, view: ?*Instance, bubbles: bool) void {
    const init: dictionaries.FocusEventInit = .{
        .base = .{ .base = .{ .bubbles = bubbles, .composed = true }, .view = view },
        .relatedTarget = related,
    };
    const event = interfaces.FocusEvent.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.FocusEventInit).passed(init),
    ) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return;
    };
    // A listener can keep the event; otherwise it is done after dispatch.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = dom.fire_event.dispatchTrusted(target, event) catch {};
}

/// The relevant global object of `document`, for a Document chain entry.
fn globalOf(document: *Instance) ?*Instance {
    return windowOf(document);
}

/// HTML "focus update steps".
fn focusUpdateSteps(old_chain_in: Chain, new_chain_in: Chain, new_focus_target: ?*Instance) void {
    var old_chain = old_chain_in;
    var new_chain = new_chain_in;
    // Step 1: "If the last entry in old chain and the last entry in new chain
    // are the same, pop the last entry from old chain and the last entry from
    // new chain and redo this step."
    while (old_chain.len > 0 and new_chain.len > 0 and old_chain.last().? == new_chain.last().?) {
        old_chain.len -= 1;
        new_chain.len -= 1;
    }
    const old_last: ?*Instance = old_chain.last();
    const new_last: ?*Instance = new_chain.last();
    const target_document = if (new_focus_target) |target| nodeDocument(target) else null;
    const target_document_generation = if (target_document) |document| runtime.SlabAllocator.generationOf(document) else 0;
    var expected_target_focus: ?dom.focused_area.Designation = if (target_document) |document| designation: {
        break :designation if (designatedAreaOf(document) != null) dom.focused_area.get(document) else null;
    } else null;
    const target_had_focus = expected_target_focus != null;
    // Step 2: for each entry in old chain, in order.
    for (0..old_chain.len) |i| {
        if (!old_chain.isLive(i)) continue;
        const entry = old_chain.items[i];
        // Step 2.1: a user edit not committed while the control was focused
        // fires change first.
        if (isElement(entry)) commitUserEdit(entry);
        if (!old_chain.isLive(i)) continue;
        const document = nodeDocument(entry);
        const document_generation = if (document) |d| runtime.SlabAllocator.generationOf(d) else 0;
        // Browsers over the spec's later designation in step 4.1:
        // Blink Document::SetFocusedElement, WebKit Document::setFocusedElement,
        // and Gecko nsFocusManager::SetFocusInner/BlurImpl clear focus before
        // blur and preserve a handler's new focus, even the original element.
        if (document) |d| {
            if (isElement(entry) and designatedAreaOf(d) == entry) {
                dom.focused_area.set(d, null);
                if (d == target_document) expected_target_focus = null;
            }
        }
        // Step 2.2: the blur event target.
        const blur_target: ?*Instance = if (isElement(entry)) entry else if (isDocument(entry)) globalOf(entry) else null;
        // Step 2.3: the related blur target.
        const related: ?*Instance = if (i == old_chain.len - 1 and isElement(entry) and new_last != null and isElement(new_last.?)) new_last else null;
        // Step 2.4.
        if (blur_target) |target| fireFocusEvent(target, "blur", related);
        if (document) |d| {
            if (runtime.SlabAllocator.generationOf(d) == document_generation and designatedAreaOf(d) != null) return;
        }
    }
    if (target_document) |document| {
        if (runtime.SlabAllocator.generationOf(document) != target_document_generation) return;
        const current = if (designatedAreaOf(document) != null) dom.focused_area.get(document) else null;
        if (!std.meta.eql(current, expected_target_focus)) return;
    }
    // Step 3: no platform conventions.
    // Step 4: for each entry in new chain, in reverse order.
    var i = new_chain.len;
    while (i > 0) {
        i -= 1;
        if (!new_chain.isLive(i)) continue;
        const entry = new_chain.items[i];
        // Step 4.1: designate a focusable area as its document's focused area.
        if (isElement(entry)) {
            if (nodeDocument(entry)) |document| {
                if (designatedAreaOf(document) != entry) {
                    if (windowOf(document)) |window| dom.navigation_api.setFocusChanged(window, true);
                    dom.focused_area.set(document, entry);
                }
            }
        } else if (isDocument(entry)) {
            if (designatedAreaOf(entry) != null or (entry == target_document and target_had_focus)) {
                if (windowOf(entry)) |window| dom.navigation_api.setFocusChanged(window, true);
                dom.focused_area.set(entry, null);
            }
        }
        // Step 4.2: the focus event target.
        const focus_target: ?*Instance = if (isElement(entry)) entry else if (isDocument(entry)) globalOf(entry) else null;
        // Step 4.3: the related focus target.
        const related: ?*Instance = if (i == new_chain.len - 1 and isElement(entry) and old_last != null and isElement(old_last.?)) old_last else null;
        // Step 4.4.
        if (focus_target) |target| fireFocusEvent(target, "focus", related);
    }
    // The viewport of a document whose chain entry step 1 popped (the
    // unfocusing steps focus the top document's viewport, which is always
    // in both chains): designate it all the same, or the element that lost
    // the focus would stay the document's focused area.
    if (new_focus_target) |target| {
        if (target == target_document and runtime.SlabAllocator.generationOf(target) == target_document_generation and isDocument(target) and
            (designatedAreaOf(target) != null or target_had_focus))
        {
            if (windowOf(target)) |window| dom.navigation_api.setFocusChanged(window, true);
            dom.focused_area.set(target, null);
        }
    }
}

/// HTML 4.8.14 and 2.3.9: resolve usemap against the first map in the image's
/// own tree whose name OR id matches the suffix after the first '#'. An id
/// reference is nonconforming authoring, but still participates in parsing.
fn imageMapOf(image: *Instance) ?*Instance {
    var usemap = (interfaces.Element.call_getAttribute(image, runtime.DOMString.initInterned("usemap")) catch null) orelse return null;
    defer usemap.deinit(image.ctx.allocator);
    const value = usemap.asSlice();
    const hash = std.mem.indexOfScalar(u8, value, '#') orelse return null;
    const name = value[hash + 1 ..];
    if (name.len == 0) return null;
    const root = rootOf(image);
    var current: ?*Instance = root;
    while (current) |node| : (current = form_associated.nextInTree(node, root, false)) {
        if (node.stateAs(interfaces.HTMLMapElement.State) == null) continue;
        for ([_][]const u8{ "name", "id" }) |attribute| {
            var candidate = (interfaces.Element.call_getAttribute(node, runtime.DOMString.initInterned(attribute)) catch null) orelse continue;
            defer candidate.deinit(node.ctx.allocator);
            if (std.mem.eql(u8, candidate.asSlice(), name)) return node;
        }
    }
    return null;
}

/// HTML 6.6.2/6.6.4, represented by the area itself as browsers expose it.
/// Blink HTMLAreaElement::IsFocusableStyle and WebKit's isFocusable use the
/// associated image's rendering: areas have no box. All three pass WPT's
/// autofocus-area.html with the AREA as activeElement (5d23b743bb), despite
/// the spec's shape table naming IMG as DOM anchor. No shape geometry here.
fn isImageMapAreaFocusable(area: *Instance) bool {
    if (!(interfaces.Node.get_isConnected(area) catch false)) return false;
    if (isInert(area) or isActuallyDisabled(area)) return false;
    const tabindex = tabindexValue(area);
    // Chrome/Safari reject negative area tabindex even for programmatic
    // focus. Blink/Gecko accept explicit nonnegative tabindex without href;
    // Gecko: nsFocusManager::IsAreaElementFocusable -> IsFocusableWithoutStyle.
    if (tabindex) |value| if (value < 0) return false;
    if (tabindex == null and !form_associated.hasAttribute(area, "href")) return false;
    const root = rootOf(area);
    var current: ?*Instance = root;
    while (current) |image| : (current = form_associated.nextInTree(image, root, false)) {
        if (image.stateAs(interfaces.HTMLImageElement.State) == null) continue;
        const map = imageMapOf(image) orelse continue;
        // Image-map processing collects all descendant areas, not only
        // direct children. Association cannot cross a tree/shadow boundary.
        var ancestor = form_associated.parentOf(area);
        const contains = while (ancestor) |node| : (ancestor = form_associated.parentOf(node)) {
            if (node == map) break true;
        } else false;
        if (!contains or isHostInert(image)) continue;
        if (!(dom.style.engine.isBeingRendered(image) catch false)) continue;
        const style = (dom.style.engine.computedStyle(image, null) catch null) orelse continue;
        if (style.keyword(.visibility) == .visible and style.keyword(.interactivity) != .inert) return true;
    }
    return false;
}

/// HTML "get the focusable area" for `focus_target`, an element that is not
/// a focusable area.
pub fn getFocusableArea(focus_target: *Instance, trigger: Trigger) ?*Instance {
    // HTML 4.10.4's platform label behavior, used by focusing step 1:
    // WebKit HTMLLabelElement::focus forwards only when the label itself
    // is not focusable. All three browsers pass forward-focus-to-associated-
    // element.html (6/6, wpt.fyi 23b0b89b1a), including a hidden label.
    if (focus_target.stateAs(interfaces.HTMLLabelElement.State) != null) {
        const control = (interfaces.HTMLLabelElement.get_control(focus_target) catch null) orelse return null;
        return if (isFocusableArea(control)) control else getFocusableArea(control, trigger);
    }
    // "If focus target is the document element of its Document": its viewport.
    if (nodeDocument(focus_target)) |document| {
        if ((interfaces.Document.get_documentElement(document) catch null) == focus_target) return document;
    }
    // "If focus target is a navigable container with a non-null content
    // navigable": that navigable's active document.
    if (isNavigableContainer(focus_target)) return contentDocumentOf(focus_target);
    // Shadow-host case, steps 1–2: keep its already focused descendant.
    // Read the existing designation; do not run rendering-time fixup here.
    if (delegatingShadowRoot(focus_target) != null) {
        if (nodeDocument(focus_target)) |document| {
            const focused = currentlyFocusedArea(document);
            if (isShadowIncludingInclusiveAncestor(focus_target, focused)) return focused;
        }
        // Step 3.
        return focusDelegate(focus_target, trigger);
    }
    // Area focusability is handled by isFocusableArea; scrollable regions
    // still require layout-backed focus areas.
    return null;
}

/// A host's delegating root, including closed roots. The public shadowRoot
/// attribute is intentionally not the internal tree algorithm's lookup.
fn delegatingShadowRoot(element: *Instance) ?*Instance {
    const root = dom.shadow_hosts.rootForHost(element) orelse return null;
    return if (interfaces.ShadowRoot.get_delegatesFocus(root) catch false) root else null;
}

/// HTML "focus delegate", steps 1–7. WebKit's Element::focusDelegate uses
/// ordinary descendants and recurses only through delegating shadow hosts.
pub fn focusDelegate(focus_target: *Instance, trigger: Trigger) ?*Instance {
    // Steps 1–3.
    var where_to_look = focus_target;
    if (dom.shadow_hosts.rootForHost(focus_target)) |root| {
        if (!(interfaces.ShadowRoot.get_delegatesFocus(root) catch false)) return null;
        where_to_look = root;
    }
    // Steps 4–5.
    if (autofocusDelegate(where_to_look, trigger)) |area| return area;
    // Step 6: ordinary tree order, not shadow-including or flattened order.
    const is_dialog = focus_target.stateAs(interfaces.HTMLDialogElement.State) != null;
    var descendant = following(where_to_look, where_to_look);
    while (descendant) |element| : (descendant = following(element, where_to_look)) {
        if (!isElement(element)) continue;
        // Steps 6.1–6.3.
        if (if (is_dialog) isSequentiallyFocusable(element) else isFocusableArea(element)) return element;
        // Steps 6.4–6.5: getFocusableArea recurses for a delegating host.
        if (getFocusableArea(element, trigger)) |area| return area;
    }
    // Step 7.
    return null;
}

/// HTML "autofocus delegate": the first suitable autofocus descendant in
/// tree order. Query the existing focusability rules without new state.
pub fn autofocusDelegate(focus_target: *Instance, trigger: Trigger) ?*Instance {
    var descendant = following(focus_target, focus_target);
    while (descendant) |element| : (descendant = following(element, focus_target)) {
        // Step 1.1.
        if (!isElement(element) or !form_associated.hasAttribute(element, "autofocus")) continue;
        // Steps 1.2-1.3.
        const area = if (isFocusableArea(element)) element else getFocusableArea(element, trigger) orelse continue;
        // Steps 1.4-1.5.
        if (trigger == .click and !isClickFocusable(area)) continue;
        return area;
    }
    // Step 2.
    return null;
}

/// HTML "focusing steps" for `new_focus_target`, an element or a Document
/// (its viewport).
pub fn focusingSteps(new_focus_target_in: *Instance, fallback_target: ?*Instance, trigger: Trigger) void {
    var new_focus_target: ?*Instance = new_focus_target_in;
    // Step 1: "If new focus target is not a focusable area, then set it to
    // the result of getting the focusable area for it."
    if (isElement(new_focus_target_in) and !isFocusableArea(new_focus_target_in)) {
        new_focus_target = getFocusableArea(new_focus_target_in, trigger);
    }
    // Step 2: fall back, or return.
    const target = new_focus_target orelse fallback_target orelse return;
    // Step 3: a navigable container focuses its content navigable's document.
    var resolved = target;
    if (isElement(target) and isNavigableContainer(target)) {
        if (contentDocumentOf(target)) |document| resolved = document;
    }
    // Step 4: "If new focus target is a focusable area and its DOM anchor is
    // inert, then return."
    if (isElement(resolved) and isInert(resolved)) return;
    const document = nodeDocument(resolved) orelse return;
    // Step 5: already the currently focused area.
    if (currentlyFocusedArea(document) == resolved) return;
    // Step 6: "Let old chain be the current focus chain of the top-level
    // traversable in which new focus target finds itself."
    const old_chain = focusChain(currentlyFocusedArea(document));
    // Step 7: "Let new chain be the focus chain of new focus target."
    const new_chain = focusChain(resolved);
    // Step 8.
    focusUpdateSteps(old_chain, new_chain, resolved);
}

/// HTML "unfocusing steps" for `old_focus_target`.
pub fn unfocusingSteps(old_focus_target_in: *Instance) void {
    var old_focus_target = old_focus_target_in;
    const document = nodeDocument(old_focus_target) orelse return;
    // Step 1: a delegating host unfocuses the currently focused area only
    // when its shadow root is that area's shadow-including ancestor.
    if (delegatingShadowRoot(old_focus_target)) |root| {
        const focused = currentlyFocusedArea(document);
        if (isShadowIncludingInclusiveAncestor(root, focused)) old_focus_target = focused;
    }
    // Step 2: "If old focus target is inert, then return."
    if (isInert(old_focus_target)) return;
    // Step 3: area shapes and scrollable regions need layout-backed areas.
    // Step 4: "Let old chain be the current focus chain of the top-level
    // traversable in which old focus target finds itself."
    const old_chain = focusChain(currentlyFocusedArea(document));
    // Step 5: "If old focus target is not one of the entries in old chain,
    // then return."
    const in_chain = for (old_chain.items[0..old_chain.len]) |entry| {
        if (entry == old_focus_target) break true;
    } else false;
    if (!in_chain) return;
    // Browsers over step 6: an explicit blur still unfocuses a designated
    // element whose tabindex was just removed. All three pass 15/15 in
    // shadow-dom/focus/focus-method-delegatesFocus.html at WPT ffc4686d11.
    // Blink Element::blur (8d5ba1795f0c50b90072399d0403389df6eebbd6) checks
    // AdjustedFocusedElementInTreeScope, without checking IsFocusable.
    // Step 5 above already established membership in the current chain.
    // Steps 7-8: the top document has system focus: run the focusing steps
    // for its viewport.
    const top_document = old_chain.last() orelse return;
    focusingSteps(top_document, null, .other);
}

/// Selection's editing-host focus side effect uses the supplied boundary
/// position without rewriting its Range.
pub const focusSelectionPosition = @import("selection_focus.zig").focusPosition;

/// The HTMLOrSVGElement focus(options) method steps (6.6.6), for every
/// element type that includes the mixin.
pub fn focusMethod(element: *Instance) void {
    // Step 1: "If the allow focus steps given this's node document return
    // false, then return."
    const document = nodeDocument(element) orelse return;
    if (!allowFocusSteps(document)) return;
    // Step 2: "Run the focusing steps for this."
    focusingSteps(element, null, .other);
    // Steps 3-4 (indicate focus, scroll into view): nothing is rendered.
}

/// HTML "allow focus steps". The focus-without-user-activation feature's
/// default allowlist is 'self' (HTML 2.2), inherited through every ancestor.
/// A cross-origin document can instead use its own transient activation.
/// Follow the newer spec; Blink's Element::EnqueueAutofocus also rejects a
/// cross-origin ancestor. Declared policies await the Document/iframe policy
/// implementation (PERMISSIONS POLICY, rows 70/79; row111 Q3).
pub fn allowFocusSteps(document: *Instance) bool {
    // Step 1: the effective default policy, with no declared policy yet.
    const allowed = ancestors: {
        var current = document;
        while (containerOf(current)) |container| {
            const parent = nodeDocument(container) orelse break :ancestors false;
            if (!@import("autofocus.zig").sameOrigin(document, parent)) break :ancestors false;
            current = parent;
        }
        break :ancestors true;
    };
    if (allowed) return true;
    // Steps 2–3: activation is observed, not consumed.
    const window = windowOf(document) orelse return false;
    return @import("user_activation.zig").hasTransientActivation(window);
}

/// The HTMLOrSVGElement blur() method steps (6.6.6): "The user agent should
/// run the unfocusing steps given this."
pub fn blurMethod(element: *Instance) void {
    unfocusingSteps(element);
}

/// The activeElement getter steps (6.6.6) for `this`, a Document or a
/// ShadowRoot.
pub fn activeElement(this: *Instance) ?*Instance {
    const document = nodeDocument(this) orelse return null;
    // Step 1: "Let candidate be this's node document's focused area's DOM
    // anchor." (The viewport's DOM anchor is the Document.)
    // This step does not run rendering-time fixup (Q42's Q16 reversal).
    var candidate: *Instance = designatedAreaOf(document) orelse document;
    // Step 2: "Set candidate to the result of retargeting candidate against
    // this."
    candidate = retarget(candidate, this);
    // Step 3: "If candidate's root is not this, then return null."
    if (rootOf(candidate) != this) return null;
    // Step 4: "If candidate is not a Document object, then return candidate."
    if (!isDocument(candidate)) return candidate;
    // Step 5: "If candidate has a body element, then return that body element."
    if (interfaces.Document.get_body(candidate) catch null) |body| return body;
    // Step 6: "If candidate's document element is non-null, then return that
    // document element."
    // An unfocused SVG document is a browser split: Chrome/Safari return
    // null, Firefox returns its root (5d23b743bb, autofocus-attribute.svg).
    // Keep this existing spec step, per row111 Q11(2)'s integrator ruling:
    // adopting null would deliberately lose a passing subtest.
    if (interfaces.Document.get_documentElement(candidate) catch null) |element| return element;
    // Step 7.
    return null;
}

fn rootOf(node: *Instance) *Instance {
    return interfaces.Node.call_getRootNode(node, webidl.Opt(dictionaries.GetRootNodeOptions).notPassed()) catch node;
}

fn isShadowRoot(node: *Instance) bool {
    return node.stateAs(interfaces.ShadowRoot.State) != null;
}

/// DOM "retarget A against B": while A's root is a shadow root that is not a
/// shadow-including inclusive ancestor of B, A becomes that root's host.
fn retarget(a_in: *Instance, b: *Instance) *Instance {
    var a = a_in;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const root = rootOf(a);
        if (!isShadowRoot(root)) return a;
        if (isShadowIncludingInclusiveAncestor(root, b)) return a;
        a = interfaces.ShadowRoot.get_host(root) catch return a;
    }
    return a;
}

fn isShadowIncludingInclusiveAncestor(ancestor: *Instance, node_in: *Instance) bool {
    var node: ?*Instance = node_in;
    var depth: usize = 0;
    while (node) |n| : (depth += 1) {
        if (n == ancestor) return true;
        if (depth == 4096) return false;
        node = form_associated.parentOf(n) orelse (if (isShadowRoot(n)) (interfaces.ShadowRoot.get_host(n) catch null) else null);
    }
    return false;
}

// ============================================================================
// :focus, :focus-within, :focus-visible
// ============================================================================

/// The shadow-including parent of `node`: its parent, or a shadow root's host.
fn shadowIncludingParent(node: *Instance) ?*Instance {
    if (form_associated.parentOf(node)) |parent| return parent;
    if (isShadowRoot(node)) return interfaces.ShadowRoot.get_host(node) catch null;
    return null;
}

/// HTML 4.16.3: "For the purposes of the CSS :focus pseudo-class, an element
/// has the focus when: it is not itself a navigable container; and any of
/// the following are true: it is one of the elements listed in the current
/// focus chain of the top-level traversable; or its shadow root shadowRoot
/// is not null and shadowRoot is the root of at least one element that has
/// the focus."
pub fn matchesFocus(element: *Instance) bool {
    if (!isElement(element) or isNavigableContainer(element)) return false;
    const document = nodeDocument(element) orelse return false;
    const chain = focusChain(currentlyFocusedArea(document));
    for (chain.items[0..chain.len]) |entry| {
        if (!isElement(entry)) continue;
        if (entry == element) return true;
        // A shadow host of the entry, at any depth.
        var node = entry;
        var depth: usize = 0;
        while (depth < 64) : (depth += 1) {
            const root = rootOf(node);
            if (!isShadowRoot(root)) break;
            const host = interfaces.ShadowRoot.get_host(root) catch break;
            if (host == element) return true;
            node = host;
        }
    }
    return false;
}

/// Selectors 4 :focus-within: the element matches :focus, or one of its
/// shadow-including descendants does (the focused element's
/// shadow-including ancestors, and the containers of the frames it is in).
pub fn matchesFocusWithin(element: *Instance) bool {
    if (!isElement(element)) return false;
    const document = nodeDocument(element) orelse return false;
    const chain = focusChain(currentlyFocusedArea(document));
    for (chain.items[0..chain.len]) |entry| {
        if (!isElement(entry)) continue;
        // A focus chain crosses documents; take each entry's owner once
        // for this synchronous walk, not the queried element's document.
        const top_layer = dom.top_layer.ofElement(entry, false) catch null;
        var node: ?*Instance = entry;
        var depth: usize = 0;
        while (node) |n| : (node = shadowIncludingParent(n)) {
            if (n == element) return true;
            // Selectors 4 section 9: popover and modal boundaries are
            // inclusive. Non-modal dialogs remain ordinary ancestors.
            if (top_layer) |layer| if (layer.find(n) != null or layer.findModal(n) != null) break;
            depth += 1;
            if (depth == 4096) break;
        }
    }
    return false;
}

/// The input modality of the last user interaction, for :focus-visible: a
/// pointer press or a key press, in the top-level document it happened in
/// (held with its generation: a later page is a new document).
const Modality = struct { document: *Instance, generation: u64, pointer: bool };
threadlocal var last_modality: ?Modality = null;

/// user_input: the user pressed a pointer button (`pointer`) or a key in the
/// top-level traversable `document` is in.
pub fn noteInputModality(document: *Instance, pointer: bool) void {
    const top = topLevelDocumentOf(document);
    last_modality = .{ .document = top, .generation = runtime.SlabAllocator.generationOf(top), .pointer = pointer };
}

/// Whether `element` takes text input: a text control or an editing host.
fn takesTextInput(element: *Instance) bool {
    if (form_associated.isTextArea(element)) return true;
    if (isEditingHost(element)) return true;
    if (!form_associated.isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    const input_type = form_associated.inputType(element, &buffer);
    const not_text = [_][]const u8{ "checkbox", "radio", "submit", "reset", "button", "image", "file", "color", "range", "hidden" };
    for (not_text) |t| if (std.mem.eql(u8, input_type, t)) return false;
    return true;
}

/// Selectors 4 :focus-visible, with the heuristic Blink applies (a stated
/// heuristic, as the selector's definition allows): a focused element
/// matches when it takes text input, or when the last user interaction in
/// its top-level traversable was not a pointer press - keyboard focus, and
/// script focus with no pointer interaction before it.
pub fn matchesFocusVisible(element: *Instance) bool {
    if (!matchesFocus(element)) return false;
    if (takesTextInput(element)) return true;
    const modality = last_modality orelse return true;
    const document = nodeDocument(element) orelse return true;
    const top = topLevelDocumentOf(document);
    if (modality.document != top or runtime.SlabAllocator.generationOf(top) != modality.generation) return true;
    return !modality.pointer;
}

// ============================================================================
// Sequential focus navigation (6.6.5)
// ============================================================================

pub const Direction = enum { forward, backward };

/// The next node after `node` in tree order within `root`.
fn following(node: *Instance, root: *Instance) ?*Instance {
    return form_associated.nextInTree(node, root, false);
}

/// HTML "sequential navigation search algorithm" for `starting_point` in
/// `document` (null: the document itself, the navigable row).
fn sequentialSearch(document: *Instance, starting_point: ?*Instance, direction: Direction) ?*Instance {
    const candidate = @import("focus_navigation.zig").search(document, starting_point, direction);
    // Step 2: a navigable container with a content navigable: search inside.
    if (candidate) |c| {
        if (isNavigableContainer(c)) {
            if (contentDocumentOf(c)) |inner| {
                if (sequentialSearch(inner, null, direction)) |found| return found;
                return sequentialSearch(document, c, direction);
            }
        }
    }
    return candidate;
}

/// HTML sequential focus navigation, when the user requests the next
/// (forward) or previous (backward) control from the currently focused area
/// of the top-level traversable `document` is in.
pub fn navigateSequentially(document: *Instance, direction: Direction) void {
    // Step 1: the starting point.
    // A removal-stable starting point needs a document-owned live Range;
    // tracked separately as "SEQUENTIAL FOCUS NAVIGATION STARTING POINT"
    // in tmp/plans/feature-queue.md (row 129 Q7). Until then the focused
    // area, or the document start, supplies the point without new ownership.
    var starting_point = currentlyFocusedArea(document);
    if (starting_point.stateAs(interfaces.HTMLOptionElement.State) != null) {
        const picker = @import("forms/select_picker.zig");
        if (picker.ownerSelect(starting_point)) |select| {
            if (picker.isListbox(select) and picker.baseOptions(select)) {
                starting_point = picker.firstFocusable(select, true) orelse starting_point;
            }
        }
    }
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const starting_document = nodeDocument(starting_point) orelse return;
        const start: ?*Instance = if (isDocument(starting_point)) null else starting_point;
        // Steps 4-5.
        if (sequentialSearch(starting_document, start, direction)) |candidate| {
            // Step 6.
            focusingSteps(candidate, null, .keyboard);
            return;
        }
        // Step 8: at the top-level traversable, focus would move to the user
        // agent's own controls; a headless one has none, and stays put.
        const container = containerOf(starting_document) orelse return;
        // Step 9: continue from the child navigable's container.
        starting_point = container;
    }
}

// ============================================================================
// Committing a user's edit (6.6.4 focus update steps, step 2.1)
// ============================================================================

/// The text controls whose value the user changed since they were focused
/// or last committed, with the value's hash when the first uncommitted edit
/// began. A control is removed when its change is committed; the table
/// holds no heap memory, and an entry whose element was freed is never
/// matched again (its generation).
const PendingEdit = struct {
    element: *Instance,
    generation: u64,
    original_hash: u64,
};
const max_pending_edits = 16;
threadlocal var pending_edits: [max_pending_edits]PendingEdit = undefined;
threadlocal var pending_edit_count: usize = 0;

fn valueHash(element: *Instance) ?u64 {
    var value = if (form_associated.isInput(element))
        interfaces.HTMLInputElement.get_value(element) catch return null
    else if (form_associated.isTextArea(element))
        interfaces.HTMLTextAreaElement.get_value(element) catch return null
    else
        return null;
    defer value.deinit(element.ctx.allocator);
    return std.hash.Wyhash.hash(0, value.asSlice());
}

/// The user is about to change `element`'s value: remember what it was, if
/// no uncommitted edit is pending for it already.
pub fn willEditByUser(element: *Instance) void {
    const generation = runtime.SlabAllocator.generationOf(element);
    for (pending_edits[0..pending_edit_count]) |edit| {
        if (edit.element == element and edit.generation == generation) return;
    }
    const hash = valueHash(element) orelse return;
    const entry: PendingEdit = .{ .element = element, .generation = generation, .original_hash = hash };
    if (pending_edit_count == max_pending_edits) {
        // The oldest goes: its control lost the change it would have fired.
        std.mem.copyForwards(PendingEdit, pending_edits[0 .. max_pending_edits - 1], pending_edits[1..max_pending_edits]);
        pending_edit_count -= 1;
    }
    pending_edits[pending_edit_count] = entry;
    pending_edit_count += 1;
}

/// Take `element`'s pending edit: whether the user changed its value (it
/// now differs from what it was when the edit began).
fn takePendingEdit(element: *Instance) bool {
    const generation = runtime.SlabAllocator.generationOf(element);
    for (pending_edits[0..pending_edit_count], 0..) |edit, index| {
        if (edit.element != element or edit.generation != generation) continue;
        std.mem.copyForwards(PendingEdit, pending_edits[index .. pending_edit_count - 1], pending_edits[index + 1 .. pending_edit_count]);
        pending_edit_count -= 1;
        const now = valueHash(element) orelse return false;
        return now != edit.original_hash;
    }
    return false;
}

/// Focus update steps step 2.1 for `entry`: "If entry is an input element,
/// and the change event applies to the element, and the element does not
/// have a defined activation behavior, and the user has changed the
/// element's value ... while the control was focused without committing
/// that change ..., then: set entry's user validity to true; fire an event
/// named change at the element, with the bubbles attribute initialized to
/// true." A textarea commits the same way (its section: "any time the user
/// commits the change"), as in every browser.
fn commitUserEdit(entry: *Instance) void {
    if (!form_associated.isInput(entry) and !form_associated.isTextArea(entry)) return;
    if (!takePendingEdit(entry)) return;
    // HTML focus update step 2.1: commit user validity before change.
    dom.form_controls.setUserValidity(entry, true) catch return;
    form_associated.fireSimpleEvent(entry, "change", .{ .bubbles = true }) catch {};
}

test "rules for parsing integers" {
    try std.testing.expectEqual(@as(?i32, 3), parseInteger("3"));
    try std.testing.expectEqual(@as(?i32, -1), parseInteger(" -1"));
    try std.testing.expectEqual(@as(?i32, 12), parseInteger("+12abc"));
    try std.testing.expectEqual(@as(?i32, null), parseInteger(""));
    try std.testing.expectEqual(@as(?i32, null), parseInteger("x1"));
    try std.testing.expectEqual(@as(?i32, null), parseInteger("-"));
    try std.testing.expectEqual(@as(?i32, null), parseInteger("99999999999"));
}
