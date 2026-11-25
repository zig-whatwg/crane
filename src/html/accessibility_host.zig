//! What the accessibility tree asks the host language (dom.accessibility_tree
//! Options): whether an element is a focusable area, inert, or actually
//! disabled. One set for both of its readers - the Accessibility domain
//! (src/devtools/domains/accessibility.zig) and WebDriver's computed role and
//! label (tests/wpt_runner/test_driver.zig) - so that they answer from the
//! same tree (lane a11y1).

const std = @import("std");
const runtime = @import("runtime");
const dom = @import("dom");
const focus = @import("focus.zig");
const form_associated = @import("form_associated.zig");
const options_list = @import("forms/options.zig");

/// HTML 6.6.2 "focusable area".
fn isFocusable(node: *runtime.Instance) bool {
    return focus.isFocusableArea(node);
}

/// HTML 6.6.1 "inert".
fn isInert(node: *runtime.Instance) bool {
    return focus.isInertNode(node);
}

/// HTML 4.15 "actually disabled", for the elements that can be: a
/// form-associated control (button, input, select, textarea, a
/// form-associated custom element) and a fieldset by their disabledness, an
/// optgroup by its disabled attribute, an option by its own steps.
fn isDisabled(element: *runtime.Instance) bool {
    const fa = form_associated;
    if (fa.isButton(element) or fa.isInput(element) or fa.isSelect(element) or fa.isTextArea(element) or fa.isFormAssociatedCustom(element)) return fa.isDisabled(element);
    if (!dom.accessibility.isHtml(element)) return false;
    const name = dom.accessibility.localName(element);
    if (std.mem.eql(u8, name, "fieldset")) return fa.isDisabled(element);
    if (std.mem.eql(u8, name, "optgroup")) return dom.accessibility.attribute(element, "disabled") != null;
    if (std.mem.eql(u8, name, "option")) return options_list.isDisabled(element);
    return false;
}

/// The tree's options, as HTML answers them.
pub const options: dom.accessibility_tree.Options = .{ .is_focusable = &isFocusable, .is_inert = &isInert, .is_disabled = &isDisabled };
