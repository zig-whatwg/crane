//! HTML 6.6 Focus: focusable areas, the focus chain, the focusing,
//! unfocusing and focus update steps, sequential focus navigation, and the
//! activeElement getter's steps.
//!
//! A document's focused area is Document's state, designated through the
//! hook Document installs (dom.focused_area) and read only through
//! `focusedAreaOf`, which applies the focus fixup rule. Elements are reached
//! through their interfaces; the navigables through html_core's browsing
//! contexts.
//!
//! Stated deviations:
//!   * "Being rendered" has no layout to answer it: an element is taken to be
//!     rendered when it is connected, not inside a `hidden` subtree (the UA
//!     style sheet's `[hidden] { display: none }`) and not inside `head`.
//!   * Focus navigation scopes are the document's tree only: shadow trees,
//!     slots and delegatesFocus are not flattened into the sequential focus
//!     navigation order, and a shadow host is focused as itself.
//!   * The focus fixup rule is applied when the focused area is read, rather
//!     than as the state change the spec makes it during "update the
//!     rendering" (see `focusedAreaOf`); nothing observes the difference,
//!     since the rule fires no event.
//!   * Every top-level traversable is taken to have system focus.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#focus

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const html_core = @import("html_core");
const form_associated = @import("form_associated.zig");

const Instance = runtime.Instance;
const BrowsingContext = html_core.window.BrowsingContext;
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
fn containerOf(document: *Instance) ?*Instance {
    const window = windowOf(document) orelse return null;
    return dom.navigable_container.of(window);
}

/// The active document of `container`'s content navigable, or null.
fn contentDocumentOf(container: *Instance) ?*Instance {
    for (BrowsingContext.liveContexts()) |context| {
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

/// HTML "rules for parsing integers" (2.3.4.1), or null on an error.
fn parseInteger(input: []const u8) ?i32 {
    var i: usize = 0;
    while (i < input.len and std.ascii.isWhitespace(input[i])) : (i += 1) {}
    var sign: i64 = 1;
    if (i < input.len and (input[i] == '-' or input[i] == '+')) {
        if (input[i] == '-') sign = -1;
        i += 1;
    }
    if (i == input.len or !std.ascii.isDigit(input[i])) return null;
    var value: i64 = 0;
    while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {
        value = value * 10 + (input[i] - '0');
        if (value > std.math.maxInt(i32) + 1) return null;
    }
    const signed = sign * value;
    if (signed > std.math.maxInt(i32) or signed < std.math.minInt(i32)) return null;
    return @intCast(signed);
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
    if (form_associated.isButton(element) or form_associated.isSelect(element) or form_associated.isTextArea(element)) return true;
    if (form_associated.isInput(element)) {
        var buffer: [16]u8 = undefined;
        return !std.mem.eql(u8, form_associated.inputType(element, &buffer), "hidden");
    }
    return isSummaryForParentDetails(element) or isNavigableContainer(element) or isEditingHost(element);
}

/// HTML "actually disabled" (4.10.19.5 and friends).
fn isActuallyDisabled(element: *Instance) bool {
    if (form_associated.isButton(element) or form_associated.isInput(element) or
        form_associated.isSelect(element) or form_associated.isTextArea(element) or named(element, "fieldset"))
    {
        return form_associated.isDisabled(element);
    }
    if (named(element, "optgroup")) return form_associated.hasAttribute(element, "disabled");
    if (named(element, "option")) {
        if (form_associated.hasAttribute(element, "disabled")) return true;
        const parent = form_associated.parentOf(element) orelse return false;
        return named(parent, "optgroup") and form_associated.hasAttribute(parent, "disabled");
    }
    return false;
}

/// HTML "inert": an inclusive ancestor has the inert attribute.
fn isInert(node: *Instance) bool {
    var current: ?*Instance = node;
    while (current) |n| : (current = form_associated.parentOf(n)) {
        if (isElement(n) and form_associated.hasAttribute(n, "inert")) return true;
    }
    return false;
}

/// "Being rendered", without layout (stated deviation): connected in a
/// document with a browsing context, and no inclusive ancestor is `hidden`
/// (other than until-found) or a `head`.
fn isBeingRendered(element: *Instance) bool {
    if (!(interfaces.Node.get_isConnected(element) catch false)) return false;
    // A document with no browsing context (`new Document()`) renders nothing.
    const document = nodeDocument(element) orelse return false;
    if (windowOf(document) == null) return false;
    var current: ?*Instance = element;
    while (current) |n| : (current = form_associated.parentOf(n)) {
        if (!isElement(n)) continue;
        if (named(n, "head")) return false;
        if (form_associated.hasAttribute(n, "hidden")) {
            var value = (interfaces.Element.call_getAttribute(n, runtime.DOMString.initInterned("hidden")) catch null) orelse return false;
            defer value.deinit(n.ctx.allocator);
            if (!std.ascii.eqlIgnoreCase(value.asSlice(), "until-found")) return false;
        }
    }
    return true;
}

/// Whether `element` is a focusable area (6.6.2's first row): its tabindex
/// value is non-null or it is focusable by default, it is not actually
/// disabled, not inert, and being rendered.
pub fn isFocusableArea(element: *Instance) bool {
    if (!isElement(element)) return false;
    if (tabindexValue(element) == null and !isFocusableByDefault(element)) return false;
    if (isActuallyDisabled(element)) return false;
    if (isInert(element)) return false;
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
    const value = tabindexValue(element) orelse return true;
    return value >= 0;
}

// ============================================================================
// The focused area of a document, and of a top-level traversable (6.6.2)
// ============================================================================

/// The DOM anchor of `document`'s focused area, or null for its viewport.
///
/// HTML "focus fixup rule": "When the designated focused area of the
/// document is removed from that Document in some way (e.g. it stops being a
/// focusable area, it is removed from the DOM, it becomes inert, etc.),
/// designate the Document's viewport to be the new focused area of the
/// document." The spec runs it as a state change in "update the rendering";
/// here it runs when the designation is read (stated deviation), which every
/// reader of the focused area does through this function. The rule fires no
/// event, so the two cannot be told apart.
pub fn focusedAreaOf(document: *Instance) ?*Instance {
    const designation = dom.focused_area.get(document) orelse return null;
    if (designation.isLive()) {
        const element = designation.element;
        const in_document = (interfaces.Node.get_isConnected(element) catch false) and
            nodeDocument(element) == document;
        if (in_document and isFocusableArea(element)) return element;
    }
    dom.focused_area.set(document, null);
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
    while (focusedAreaOf(candidate)) |area| : (depth += 1) {
        if (depth == 64 or !isNavigableContainer(area)) break;
        candidate = contentDocumentOf(area) orelse break;
    }
    // Steps 4-5.
    return focusedAreaOf(candidate) orelse candidate;
}

/// HTML "has focus steps" for `document`.
pub fn hasFocus(document: *Instance) bool {
    var candidate = topLevelDocumentOf(document);
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        if (candidate == document) return true;
        const area = focusedAreaOf(candidate) orelse return false;
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
    // Step 2: for each entry in old chain, in order.
    for (0..old_chain.len) |i| {
        if (!old_chain.isLive(i)) continue;
        const entry = old_chain.items[i];
        // Step 2.1: a user edit not committed while the control was focused
        // fires change first.
        if (isElement(entry)) commitUserEdit(entry);
        // Step 2.2: the blur event target.
        const blur_target: ?*Instance = if (isElement(entry)) entry else if (isDocument(entry)) globalOf(entry) else null;
        // Step 2.3: the related blur target.
        const related: ?*Instance = if (i == old_chain.len - 1 and isElement(entry) and new_last != null and isElement(new_last.?)) new_last else null;
        // Step 2.4.
        if (blur_target) |target| fireFocusEvent(target, "blur", related);
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
                if (focusedAreaOf(document) != entry) dom.focused_area.set(document, entry);
            }
        } else if (isDocument(entry)) {
            if (focusedAreaOf(entry) != null) dom.focused_area.set(entry, null);
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
        if (isDocument(target) and focusedAreaOf(target) != null) dom.focused_area.set(target, null);
    }
}

/// HTML "get the focusable area" for `focus_target`, an element that is not
/// a focusable area.
fn getFocusableArea(focus_target: *Instance) ?*Instance {
    // "If focus target is the document element of its Document": its viewport.
    if (nodeDocument(focus_target)) |document| {
        if ((interfaces.Document.get_documentElement(document) catch null) == focus_target) return document;
    }
    // "If focus target is a navigable container with a non-null content
    // navigable": that navigable's active document.
    if (isNavigableContainer(focus_target)) return contentDocumentOf(focus_target);
    // Area shapes, scrollable regions and delegatesFocus: not implemented.
    return null;
}

/// HTML "focusing steps" for `new_focus_target`, an element or a Document
/// (its viewport).
pub fn focusingSteps(new_focus_target_in: *Instance, fallback_target: ?*Instance, trigger: Trigger) void {
    _ = trigger;
    var new_focus_target: ?*Instance = new_focus_target_in;
    // Step 1: "If new focus target is not a focusable area, then set it to
    // the result of getting the focusable area for it."
    if (isElement(new_focus_target_in) and !isFocusableArea(new_focus_target_in)) {
        new_focus_target = getFocusableArea(new_focus_target_in);
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
pub fn unfocusingSteps(old_focus_target: *Instance) void {
    // Steps 1 and 3 (delegatesFocus, area shapes, scrollable regions): not
    // implemented. Step 2: "If old focus target is inert, then return."
    if (isInert(old_focus_target)) return;
    const document = nodeDocument(old_focus_target) orelse return;
    // Step 4: "Let old chain be the current focus chain of the top-level
    // traversable in which old focus target finds itself."
    const old_chain = focusChain(currentlyFocusedArea(document));
    // Step 5: "If old focus target is not one of the entries in old chain,
    // then return."
    const in_chain = for (old_chain.items[0..old_chain.len]) |entry| {
        if (entry == old_focus_target) break true;
    } else false;
    if (!in_chain) return;
    // Step 6: "If old focus target is not a focusable area, then return."
    if (isElement(old_focus_target) and !isFocusableArea(old_focus_target)) return;
    // Steps 7-8: the top document has system focus: run the focusing steps
    // for its viewport.
    const top_document = old_chain.last() orelse return;
    focusingSteps(top_document, null, .other);
}

/// The HTMLOrSVGElement focus(options) method steps (6.6.6), for every
/// element type that includes the mixin.
pub fn focusMethod(element: *Instance) void {
    // Step 1: "If the allow focus steps given this's node document return
    // false, then return." The "focus-without-user-activation" feature's
    // default allowlist is *, and Crane has no permissions policy that
    // narrows it: always allowed.
    // Step 2: "Run the focusing steps for this."
    focusingSteps(element, null, .other);
    // Steps 3-4 (indicate focus, scroll into view): nothing is rendered.
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
    var candidate: *Instance = focusedAreaOf(document) orelse document;
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
// Sequential focus navigation (6.6.5)
// ============================================================================

pub const Direction = enum { forward, backward };

/// The next node after `node` in tree order within `root`.
fn following(node: *Instance, root: *Instance) ?*Instance {
    return form_associated.nextInTree(node, root, false);
}

/// `document`'s sequential focus navigation order (stated deviation: its
/// tree only), into `out`: positive tabindex values first, ascending, then
/// the rest in tree order; how many.
fn sequentialOrder(document: *Instance, out: []*Instance) usize {
    var count: usize = 0;
    // Positive tabindex values, in ascending order, ties in tree order: one
    // pass per distinct value would be quadratic, so collect then sort.
    var positives: [512]struct { value: i32, index: usize, element: *Instance } = undefined;
    var positive_count: usize = 0;
    var tree_index: usize = 0;
    var node = following(document, document);
    while (node) |n| : (node = following(n, document)) {
        tree_index += 1;
        if (!isElement(n) or !isSequentiallyFocusable(n)) continue;
        const value = tabindexValue(n) orelse 0;
        if (value > 0 and positive_count < positives.len) {
            positives[positive_count] = .{ .value = value, .index = tree_index, .element = n };
            positive_count += 1;
        }
    }
    const Positive = @TypeOf(positives[0]);
    std.sort.pdq(Positive, positives[0..positive_count], {}, struct {
        fn lessThan(_: void, a: Positive, b: Positive) bool {
            return if (a.value != b.value) a.value < b.value else a.index < b.index;
        }
    }.lessThan);
    for (positives[0..positive_count]) |p| {
        if (count == out.len) return count;
        out[count] = p.element;
        count += 1;
    }
    node = following(document, document);
    while (node) |n| : (node = following(n, document)) {
        if (!isElement(n) or !isSequentiallyFocusable(n)) continue;
        if ((tabindexValue(n) orelse 0) > 0) continue;
        if (count == out.len) return count;
        out[count] = n;
        count += 1;
    }
    return count;
}

/// HTML "sequential navigation search algorithm" for `starting_point` in
/// `document` (null: the document itself, the navigable row).
fn sequentialSearch(document: *Instance, starting_point: ?*Instance, direction: Direction) ?*Instance {
    var order: [1024]*Instance = undefined;
    const count = sequentialOrder(document, &order);
    const items = order[0..count];
    var candidate: ?*Instance = null;
    if (starting_point) |start| {
        const position = std.mem.indexOfScalar(*Instance, items, start);
        if (position) |p| {
            // The "sequential" selection mechanism.
            candidate = switch (direction) {
                .forward => if (p + 1 < items.len) items[p + 1] else null,
                .backward => if (p > 0) items[p - 1] else null,
            };
        } else {
            // The "DOM" selection mechanism: the suitable area nearest after
            // (before) the starting point in tree order.
            var node = following(start, document);
            if (direction == .forward) {
                while (node) |n| : (node = following(n, document)) {
                    if (std.mem.indexOfScalar(*Instance, items, n) != null) {
                        candidate = n;
                        break;
                    }
                }
            } else {
                var last: ?*Instance = null;
                var walk = following(document, document);
                while (walk) |n| : (walk = following(n, document)) {
                    if (n == start) break;
                    if (std.mem.indexOfScalar(*Instance, items, n) != null) last = n;
                }
                candidate = last;
            }
        }
    } else if (items.len > 0) {
        candidate = if (direction == .forward) items[0] else items[items.len - 1];
    }
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
    var starting_point = currentlyFocusedArea(document);
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
    // User validity: not implemented (constraint validation is queued).
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
