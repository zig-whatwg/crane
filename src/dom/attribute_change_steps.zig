//! Per-element-type "attribute change steps" (DOM 4.9), which HTML defines
//! for many elements - an iframe's src and srcdoc navigate it, for one.
//!
//! Element runs its own change steps (id, class, slot, event handlers) and
//! then asks this hook, which calls the steps the element's own type
//! installed. An element type's steps read and write that type's state, so
//! its impl installs them here and Element never imports it. The shape of
//! `navigable_container.zig`, keyed by element: each owner installs steps for
//! the HTML local name it implements.
//! Namespace-wide attributes, such as HTML and SVG nonce, use a second list
//! keyed by attribute local name and element namespace. Their owners may
//! install a borrowed private-value reader beside the change step.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
//!
//! lint-impls: hook for HTMLIFrameElement, HTMLScriptElement, HTMLDetailsElement, HTMLLinkElement, HTMLInputElement, HTMLSlotElement, HTMLElement, SVGElement

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// The attribute change steps of one element type: given the element, the
/// attribute's local name, its old value and new value (null when absent),
/// and its namespace.
pub const Steps = *const fn (
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void;

const Entry = struct {
    /// The element's local name, in the HTML namespace.
    element: []const u8,
    steps: Steps,
};

/// A namespace-wide attribute step, and an optional reader for its private
/// value. The reader borrows until that value next changes; IDL getters copy.
pub const AttributeSteps = struct {
    change: Steps,
    read: ?*const fn (element: *runtime.Instance) []const u8 = null,
};

const AttributeEntry = struct {
    element_namespace: []const u8,
    attribute: []const u8,
    steps: AttributeSteps,
};

/// Few element types have steps, so a short list beats a map. Sixteen types
/// install steps (the slot element made it sixteen); an entry dropped here is
/// a type whose steps never run, so the bound stays well above the count.
const max_entries = 32;
var entries: struct {
    elements: [max_entries]Entry = undefined,
    attributes: [4]AttributeEntry = undefined,
} = .{};
var count: struct { elements: usize = 0, attributes: usize = 0 } = .{};

/// Install `steps` for HTML elements whose local name is `element` (a string
/// that lives for the program). Idempotent: installing the same steps again
/// changes nothing; installing different ones replaces them.
pub fn install(element: []const u8, steps: Steps) void {
    process_start.assertInstalling();
    for (entries.elements[0..count.elements]) |*entry| {
        if (std.mem.eql(u8, entry.element, element)) {
            entry.steps = steps;
            return;
        }
    }
    std.debug.assert(count.elements < max_entries);
    if (count.elements == max_entries) return;
    entries.elements[count.elements] = .{ .element = element, .steps = steps };
    count.elements += 1;
}

/// Install once, at process start, for an ATTRIBUTE local name on every
/// element in `namespace`. The strings live for the process.
pub fn installForAttribute(namespace: []const u8, attribute_local_name: []const u8, steps: AttributeSteps) void {
    process_start.assertInstalling();
    for (entries.attributes[0..count.attributes]) |*entry| {
        if (std.mem.eql(u8, entry.attribute, attribute_local_name) and std.mem.eql(u8, entry.element_namespace, namespace)) {
            entry.steps = steps;
            return;
        }
    }
    std.debug.assert(count.attributes < entries.attributes.len);
    entries.attributes[count.attributes] = .{ .element_namespace = namespace, .attribute = attribute_local_name, .steps = steps };
    count.attributes += 1;
}

/// HTML 2.5.6's nonce step applies to both HTML and SVG elements. Compare
/// the attribute's length and bytes FIRST: ordinary attributes do no
/// namespace lookup, state lookup or allocation in this hook.
pub fn runForAttribute(element: *runtime.Instance, element_namespace: []const u8, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    for (entries.attributes[0..count.attributes]) |entry| {
        if (!std.mem.eql(u8, entry.attribute, local_name)) continue;
        if (!std.mem.eql(u8, entry.element_namespace, element_namespace)) continue;
        entry.steps.change(element, local_name, old_value, value, namespace);
        return;
    }
}

/// Read the private value installed beside an attribute's change step.
/// Borrowed until its next change: callers copy anything they keep.
pub fn readForAttribute(element: *runtime.Instance, element_namespace: []const u8, local_name: []const u8) ?[]const u8 {
    for (entries.attributes[0..count.attributes]) |entry| {
        if (!std.mem.eql(u8, entry.attribute, local_name)) continue;
        if (!std.mem.eql(u8, entry.element_namespace, element_namespace)) continue;
        const read = entry.steps.read orelse return null;
        return read(element);
    }
    return null;
}

/// Run the attribute change steps `element`'s type installed, if any.
/// `element_local_name` is the element's local name; the caller has already
/// checked it is an HTML element.
pub fn run(
    element: *runtime.Instance,
    element_local_name: []const u8,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    for (entries.elements[0..count.elements]) |entry| {
        if (std.mem.eql(u8, entry.element, element_local_name)) {
            entry.steps(element, local_name, old_value, value, namespace);
            return;
        }
    }
}

var test_calls: usize = 0;
fn testSteps(_: *runtime.Instance, _: []const u8, _: ?[]const u8, _: ?[]const u8, _: ?[]const u8) void {
    test_calls += 1;
}

test "steps run only for the element type that installed them, once however often installed" {
    const saved_count = count;
    const saved_entries = entries;
    defer {
        count = saved_count;
        entries = saved_entries;
    }
    count = .{};
    test_calls = 0;
    install("x-test", &testSteps);
    install("x-test", &testSteps);
    try std.testing.expectEqual(@as(usize, 1), count.elements);
    // Never dereferenced: the steps ignore the element.
    var element: runtime.Instance = undefined;
    run(&element, "x-test", "src", null, "a", null);
    run(&element, "div", "src", null, "a", null);
    try std.testing.expectEqual(@as(usize, 1), test_calls);
}

test "attribute steps dispatch by attribute then element namespace, with an independent reader" {
    const saved_count = count;
    const saved_entries = entries;
    defer {
        count = saved_count;
        entries = saved_entries;
    }
    count = .{};
    test_calls = 0;
    const Read = struct {
        fn read(_: *runtime.Instance) []const u8 {
            return "private slot";
        }
    };
    installForAttribute("urn:a", "nonce", .{ .change = &testSteps, .read = &Read.read });
    installForAttribute("urn:a", "nonce", .{ .change = &testSteps, .read = &Read.read });
    try std.testing.expectEqual(@as(usize, 1), count.attributes);
    var element: runtime.Instance = undefined;
    runForAttribute(&element, "urn:a", "nonce", null, "value", null);
    runForAttribute(&element, "urn:a", "class", null, "value", null);
    runForAttribute(&element, "urn:b", "nonce", null, "value", null);
    try std.testing.expectEqual(@as(usize, 1), test_calls);
    try std.testing.expectEqualStrings("private slot", readForAttribute(&element, "urn:a", "nonce").?);
    try std.testing.expect(readForAttribute(&element, "urn:b", "nonce") == null);
}
