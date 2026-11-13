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
const hook = @import("hook.zig");
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
/// Per (namespace, attribute) steps: nine at lane quick1 (2026-11-12: the
/// nonce step for each of the three namespaces whose elements include
/// HTMLOrSVGOrMathMLElement); past the bound, the process start panics.
const max_attribute_entries = 16;
const Tables = struct {
    elements: hook.List(Entry, max_entries) = .empty,
    attributes: hook.List(AttributeEntry, max_attribute_entries) = .empty,
};
/// Process-wide, written once at start-up (hook.zig).
var entries: hook.Hook(Tables) = .init(.{});

/// A test's swap of the steps tables for empty ones, whose own steps it may
/// install until the returned guard's `restore()` (Hook.overrideForTest;
/// global_settings.zig's shape). Lane nd2 batch 2's red test needs a step
/// that runs before another and changes the element, which no installed
/// step does today.
pub fn overrideForTest() @TypeOf(entries).Override {
    return entries.overrideForTest(.{});
}

/// Install `steps` for HTML elements whose local name is `element` (a string
/// that lives for the program). Idempotent: installing the same steps again
/// changes nothing; installing different ones replaces them.
pub fn install(element: []const u8, steps: Steps) void {
    const tables = entries.installing();
    for (tables.elements.mutableSlice()) |*entry| {
        if (std.mem.eql(u8, entry.element, element)) {
            // The same steps again write nothing (hook.zig, Hook.install).
            if (entry.steps != steps) entry.steps = steps;
            return;
        }
    }
    tables.elements.append(.{ .element = element, .steps = steps });
}

/// Install once, at process start, for an ATTRIBUTE local name on every
/// element in `namespace`. The strings live for the process.
pub fn installForAttribute(namespace: []const u8, attribute_local_name: []const u8, steps: AttributeSteps) void {
    const tables = entries.installing();
    for (tables.attributes.mutableSlice()) |*entry| {
        if (std.mem.eql(u8, entry.attribute, attribute_local_name) and std.mem.eql(u8, entry.element_namespace, namespace)) {
            if (!std.meta.eql(entry.steps, steps)) entry.steps = steps;
            return;
        }
    }
    tables.attributes.append(.{ .element_namespace = namespace, .attribute = attribute_local_name, .steps = steps });
}

/// HTML 2.5.6's nonce step applies to both HTML and SVG elements. Compare
/// the attribute's length and bytes FIRST: ordinary attributes do no
/// namespace lookup, state lookup or allocation in this hook.
pub fn runForAttribute(element: *runtime.Instance, element_namespace: []const u8, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    for (entries.read().attributes.slice()) |entry| {
        if (!std.mem.eql(u8, entry.attribute, local_name)) continue;
        if (!std.mem.eql(u8, entry.element_namespace, element_namespace)) continue;
        entry.steps.change(element, local_name, old_value, value, namespace);
        return;
    }
}

/// Read the private value installed beside an attribute's change step.
/// Borrowed until its next change: callers copy anything they keep.
pub fn readForAttribute(element: *runtime.Instance, element_namespace: []const u8, local_name: []const u8) ?[]const u8 {
    for (entries.read().attributes.slice()) |entry| {
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
    for (entries.read().elements.slice()) |entry| {
        if (std.mem.eql(u8, entry.element, element_local_name)) {
            entry.steps(element, local_name, old_value, value, namespace);
            return;
        }
    }
}

test "steps run only for the element type that installed them, once however often installed" {
    const override = entries.overrideForTest(.{});
    defer override.restore();
    // The test's steps: their count lives in the test, not in the product.
    const Test = struct {
        var calls: usize = 0;
        fn steps(_: *runtime.Instance, _: []const u8, _: ?[]const u8, _: ?[]const u8, _: ?[]const u8) void {
            calls += 1;
        }
    };
    install("x-test", &Test.steps);
    install("x-test", &Test.steps);
    try std.testing.expectEqual(@as(usize, 1), entries.get().elements.len);
    // Never dereferenced: the steps ignore the element.
    var element: runtime.Instance = undefined;
    run(&element, "x-test", "src", null, "a", null);
    run(&element, "div", "src", null, "a", null);
    try std.testing.expectEqual(@as(usize, 1), Test.calls);
}

test "attribute steps dispatch by attribute then element namespace, with an independent reader" {
    const override = entries.overrideForTest(.{});
    defer override.restore();
    const Test = struct {
        var calls: usize = 0;
        fn steps(_: *runtime.Instance, _: []const u8, _: ?[]const u8, _: ?[]const u8, _: ?[]const u8) void {
            calls += 1;
        }
    };
    const Read = struct {
        fn read(_: *runtime.Instance) []const u8 {
            return "private slot";
        }
    };
    installForAttribute("urn:a", "nonce", .{ .change = &Test.steps, .read = &Read.read });
    installForAttribute("urn:a", "nonce", .{ .change = &Test.steps, .read = &Read.read });
    try std.testing.expectEqual(@as(usize, 1), entries.get().attributes.len);
    var element: runtime.Instance = undefined;
    runForAttribute(&element, "urn:a", "nonce", null, "value", null);
    runForAttribute(&element, "urn:a", "class", null, "value", null);
    runForAttribute(&element, "urn:b", "nonce", null, "value", null);
    try std.testing.expectEqual(@as(usize, 1), Test.calls);
    try std.testing.expectEqualStrings("private slot", readForAttribute(&element, "urn:a", "nonce").?);
    try std.testing.expect(readForAttribute(&element, "urn:b", "nonce") == null);
}
