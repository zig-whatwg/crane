//! HTML 4.15 and 4.16.3: matching HTML state, through each owner's interfaces.
//! Like WebKit's SelectorCheckerTestFunctions, dispatch first by element kind;
//! constraint matching reads state and never invokes checkValidity or events.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const forms = @import("form_associated.zig");
const Kind = dom.html_pseudo_classes.Kind;
const Instance = runtime.Instance;

pub fn matches(element: *Instance, which: Kind) bool {
    // Directionality is defined for every namespace; only HTML has dir.
    // :hover and :active match any element (a flat-tree ancestor of what the
    // pointer designates can be SVG or MathML).
    switch (which) {
        .dir_ltr => return forms.directionality(element) == .ltr,
        .dir_rtl => return forms.directionality(element) == .rtl,
        .hover => return userActionMatches(element, &.{.hovered}),
        .active => return userActionMatches(element, &.{ .pointed, .activated }),
        else => {},
    }
    if (element.stateAs(interfaces.HTMLElement.State) == null) return false;
    return switch (which) {
        .any_link => (element.stateAs(interfaces.HTMLAnchorElement.State) != null or element.stateAs(interfaces.HTMLAreaElement.State) != null) and has(element, "href"),
        // Crane has no visited history; script cannot observe visited links.
        .visited => false,
        .enabled => if (disabledState(element)) |disabled| !disabled else false,
        .disabled => disabledState(element) orelse false,
        .checked => checked(element),
        .indeterminate => indeterminate(element),
        .default => default(element),
        // This shared HTML algorithm reads native willValidate/validity and
        // ValidityState.valid, and includes form/fieldset and FACE rules.
        .valid => forms.validationState(element) == .valid,
        .invalid => forms.validationState(element) == .invalid,
        .required => required(element) orelse false,
        .optional => if (required(element)) |value| !value else false,
        .in_range => range(element, false),
        .out_of_range => range(element, true),
        .read_write => readWrite(element),
        .read_only => !readWrite(element),
        .placeholder_shown => placeholderShown(element),
        .open => dom.form_controls.pickerOpen(element) or (element.stateAs(interfaces.HTMLDetailsElement.State) != null or element.stateAs(interfaces.HTMLDialogElement.State) != null) and has(element, "open"),
        .popover_open => has(element, "popover") and dom.html_pseudo_classes.popoverShowing(element),
        // Crane has no autofill or picker UI and never locks media volume.
        .autofill, .volume_locked => false,
        // Owner capabilities routed as follow-ups (tables Q4): user validity,
        // dialog/fullscreen modal state, and media's is-currently-stalled flag.
        .user_valid, .user_invalid, .modal, .stalled => false,
        .playing => isMedia(element) and !(interfaces.HTMLMediaElement.get_paused(element) catch true),
        .paused => isMedia(element) and (interfaces.HTMLMediaElement.get_paused(element) catch false),
        .seeking => isMedia(element) and (interfaces.HTMLMediaElement.get_seeking(element) catch false),
        .muted => isMedia(element) and (interfaces.HTMLMediaElement.get_muted(element) catch false),
        .buffering => isMedia(element) and !(interfaces.HTMLMediaElement.get_paused(element) catch true) and
            (interfaces.HTMLMediaElement.get_networkState(element) catch 0) == interfaces.HTMLMediaElement.get_NETWORK_LOADING() and
            (interfaces.HTMLMediaElement.get_readyState(element) catch 5) <= interfaces.HTMLMediaElement.get_HAVE_CURRENT_DATA(),
        .heading => |levels| heading(element, levels),
        .dir_ltr, .dir_rtl, .hover, .active => unreachable,
    };
}

/// HTML 4.16.3. :hover matches the element the user designates with a
/// pointing device; :active an element being activated - being actively
/// pointed at, or in a formal activation state. "Per the definition in
/// Selectors", each also matches the flat-tree ancestors of such an
/// element, and "any element that is the labeled control of a label
/// element that is currently matching" it does too. Disabled elements are
/// no exception (html/semantics/selectors/pseudo-classes/active-disabled.html:
/// a pressed disabled button, its label, its child, a disabled input and
/// textarea all make the control :active - PASS in all three engines at
/// wpt.fyi cc74d2669f).
///
/// Deviation: an element in a formal activation state (a button held by
/// Space) is :active alone - its ancestors are not. Chrome and Safari pass
/// html/semantics/forms/the-button-element/active-onblur.html, whose
/// `querySelector(':active')` must find the button, not the html element
/// above it (Firefox fails it); Blink's KeyboardClickableInputTypeView sets
/// the element's own active flag, outside the document's active chain.
fn userActionMatches(element: *Instance, states: []const dom.pointer_states.State) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    for (states) |state| {
        const designated = dom.pointer_states.get(document, state) orelse continue;
        if (state == .activated) {
            if (designated == element) return true;
            continue;
        }
        var current: ?*Instance = designated;
        while (current) |node| : (current = flatTreeParent(node)) {
            if (node == element) return true;
            if (node.stateAs(interfaces.HTMLLabelElement.State) != null and forms.labeledControl(node) == element) return true;
        }
    }
    return false;
}

/// CSS Scoping: a node's parent in the flat tree - its assigned slot, else
/// its parent element, a shadow root's host for a shadow tree's top level.
fn flatTreeParent(node: *Instance) ?*Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = forms.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    if (!forms.isElement(parent)) return null;
    return parent;
}

fn has(element: *Instance, comptime name: []const u8) bool {
    return interfaces.Element.call_hasAttribute(element, runtime.DOMString.initInterned(name)) catch false;
}

fn inputType(element: *Instance, buffer: []u8) []const u8 {
    return forms.inputType(element, buffer);
}

fn isOneOf(value: []const u8, comptime values: anytype) bool {
    inline for (values) |candidate| if (std.mem.eql(u8, value, candidate)) return true;
    return false;
}

fn disabledState(element: *Instance) ?bool {
    if (dom.custom_elements.disabledState(element)) |disabled| return disabled;
    if (forms.isInput(element) or forms.isButton(element) or forms.isSelect(element) or forms.isTextArea(element) or element.stateAs(interfaces.HTMLFieldSetElement.State) != null) return forms.isDisabled(element);
    const option = element.stateAs(interfaces.HTMLOptionElement.State) != null;
    const group = element.stateAs(interfaces.HTMLOptGroupElement.State) != null;
    if (!option and !group) return null;
    if (has(element, "disabled")) return true;
    // HTML 4.15: nearest select's disabled state also disables its options
    // and optgroups. Nested selects/datalists/options delimit that association.
    var parent = forms.parentOf(element);
    var option_disabled = false;
    var group_search = option;
    while (parent) |ancestor| : (parent = forms.parentOf(ancestor)) {
        if (forms.isSelect(ancestor)) return option_disabled or forms.isDisabled(ancestor);
        if (ancestor.stateAs(interfaces.HTMLDataListElement.State) != null or ancestor.stateAs(interfaces.HTMLOptionElement.State) != null) break;
        if (group_search) {
            if (ancestor.stateAs(interfaces.HTMLHRElement.State) != null) group_search = false;
            if (ancestor.stateAs(interfaces.HTMLOptGroupElement.State) != null) {
                option_disabled = has(ancestor, "disabled");
                group_search = false;
            }
        }
    }
    return option_disabled;
}

fn checked(element: *Instance) bool {
    if (forms.isInput(element)) {
        var buffer: [24]u8 = undefined;
        return isOneOf(inputType(element, &buffer), .{ "checkbox", "radio" }) and (interfaces.HTMLInputElement.get_checked(element) catch false);
    }
    return element.stateAs(interfaces.HTMLOptionElement.State) != null and (interfaces.HTMLOptionElement.get_selected(element) catch false);
}

fn indeterminate(element: *Instance) bool {
    if (element.stateAs(interfaces.HTMLProgressElement.State) != null) return !has(element, "value");
    if (!forms.isInput(element)) return false;
    var buffer: [24]u8 = undefined;
    const kind = inputType(element, &buffer);
    if (std.mem.eql(u8, kind, "checkbox")) return interfaces.HTMLInputElement.get_indeterminate(element) catch false;
    if (!std.mem.eql(u8, kind, "radio")) return false;
    if (interfaces.HTMLInputElement.get_checked(element) catch false) return false;
    var name = interfaces.HTMLInputElement.get_name(element) catch return true;
    defer name.deinit(element.ctx.allocator);
    if (name.isEmpty()) return true;
    const owner = interfaces.HTMLInputElement.get_form(element) catch null;
    const root = forms.rootOf(element);
    var node: ?*Instance = root;
    while (node) |other| : (node = forms.nextInTree(other, root, false)) {
        if (other == element or !forms.isInput(other)) continue;
        if (!std.mem.eql(u8, inputType(other, &buffer), "radio")) continue;
        if (!(interfaces.HTMLInputElement.get_checked(other) catch false)) continue;
        var other_name = interfaces.HTMLInputElement.get_name(other) catch continue;
        defer other_name.deinit(other.ctx.allocator);
        if (std.mem.eql(u8, name.asSlice(), other_name.asSlice()) and (interfaces.HTMLInputElement.get_form(other) catch null) == owner) return false;
    }
    return true;
}

fn default(element: *Instance) bool {
    if (element.stateAs(interfaces.HTMLOptionElement.State) != null) return has(element, "selected");
    if (forms.isInput(element)) {
        var buffer: [24]u8 = undefined;
        if (isOneOf(inputType(element, &buffer), .{ "checkbox", "radio" })) return has(element, "checked");
    }
    if (!forms.isSubmitButton(element)) return false;
    const owner = forms.formOwner(element) orelse return false;
    const root = forms.rootOf(element);
    var node: ?*Instance = root;
    while (node) |candidate| : (node = forms.nextInTree(candidate, root, false)) {
        if (forms.isSubmitButton(candidate) and forms.formOwner(candidate) == owner) return candidate == element;
    }
    return false;
}

fn required(element: *Instance) ?bool {
    if (forms.isSelect(element)) return interfaces.HTMLSelectElement.get_required(element) catch false;
    if (forms.isTextArea(element)) return interfaces.HTMLTextAreaElement.get_required(element) catch false;
    if (!forms.isInput(element)) return null;
    var buffer: [24]u8 = undefined;
    const supported = isOneOf(inputType(element, &buffer), .{ "text", "search", "url", "tel", "email", "password", "date", "month", "week", "time", "datetime-local", "number", "checkbox", "radio", "file" });
    // Blink/WebKit make unsupported input states optional. HTML's prose
    // restricts optional to states supporting required; follow the majority:
    // wpt.fyi cc74d2669f (2026-10-06), required-optional-hidden.html:
    // Chrome 1/1, Safari 1/1, Firefox 0/1, all harness OK.
    // Blink HTMLInputElement::IsRequiredFormControl checks SupportsRequired;
    // WebKit HTMLInputElement uses the same type predicate.
    return supported and (interfaces.HTMLInputElement.get_required(element) catch false);
}

fn range(element: *Instance, outside: bool) bool {
    if (!forms.isInput(element)) return false;
    if (!(interfaces.HTMLInputElement.get_willValidate(element) catch false)) return false;
    if (!dom.form_controls.hasRangeLimitations(element)) return false;
    const validity = interfaces.HTMLInputElement.get_validity(element) catch return false;
    const out = (interfaces.ValidityState.get_rangeUnderflow(validity) catch false) or (interfaces.ValidityState.get_rangeOverflow(validity) catch false);
    return out == outside;
}

fn readWrite(element: *Instance) bool {
    if (forms.isInput(element)) {
        var buffer: [24]u8 = undefined;
        const supported = isOneOf(inputType(element, &buffer), .{ "text", "search", "url", "tel", "email", "password", "date", "month", "week", "time", "datetime-local", "number" });
        return supported and !(interfaces.HTMLInputElement.get_readOnly(element) catch true) and !forms.isDisabled(element);
    }
    if (forms.isTextArea(element)) return !(interfaces.HTMLTextAreaElement.get_readOnly(element) catch true) and !forms.isDisabled(element);
    return interfaces.HTMLElement.get_isContentEditable(element) catch false;
}

fn placeholderShown(element: *Instance) bool {
    const textarea = forms.isTextArea(element);
    if (!textarea) {
        if (!forms.isInput(element)) return false;
        var buffer: [24]u8 = undefined;
        if (!isOneOf(inputType(element, &buffer), .{ "text", "search", "url", "tel", "email", "password", "number" })) return false;
    }
    // Blink TextControlElement::PlaceholderShouldBeVisible and WebKit
    // HTMLTextFormControlElement::placeholderShouldBeVisible check presence,
    // including an empty placeholder, independently of styling/layout.
    if (!has(element, "placeholder")) return false;
    var value = (if (textarea) interfaces.HTMLTextAreaElement.get_value(element) else interfaces.HTMLInputElement.get_value(element)) catch return false;
    defer value.deinit(element.ctx.allocator);
    // The presentation state requires no geometry: an applicable placeholder
    // is presented while the text editor is empty.
    if (!value.isEmpty()) return false;
    if (dom.form_controls.editorText(element) catch null) |raw_value| {
        var raw = raw_value;
        defer raw.deinit(element.ctx.allocator);
        if (!raw.isEmpty()) return false;
    }
    return true;
}

fn isMedia(element: *Instance) bool {
    return element.stateAs(interfaces.HTMLMediaElement.State) != null;
}

fn heading(element: *Instance, levels: u6) bool {
    if (element.stateAs(interfaces.HTMLHeadingElement.State) == null) return false;
    var local = interfaces.Element.get_localName(element) catch return false;
    defer local.deinit(element.ctx.allocator);
    const name = local.asSlice();
    if (name.len != 2 or name[0] != 'h' or name[1] < '1' or name[1] > '6') return false;
    return levels & (@as(u6, 1) << @as(u3, @intCast(name[1] - '1'))) != 0;
}
