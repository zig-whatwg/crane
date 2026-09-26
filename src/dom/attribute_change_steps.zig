//! Per-element-type "attribute change steps" (DOM 4.9), which HTML defines
//! for many elements - an iframe's src and srcdoc navigate it, for one.
//!
//! Element runs its own change steps (id, class, slot, event handlers) and
//! then asks this hook, which calls the steps the element's own type
//! installed. An element type's steps read and write that type's state, so
//! its impl installs them here and Element never imports it. The shape of
//! `navigable_container.zig`, keyed by element: each owner installs steps for
//! the HTML local name it implements.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
//!
//! lint-impls: hook for HTMLIFrameElement

const std = @import("std");
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

/// Few element types have steps, so a short list beats a map.
const max_entries = 16;
threadlocal var entries: [max_entries]Entry = undefined;
threadlocal var count: usize = 0;

/// Install `steps` for HTML elements whose local name is `element` (a string
/// that lives for the program). Idempotent: installing the same steps again
/// changes nothing; installing different ones replaces them.
pub fn install(element: []const u8, steps: Steps) void {
    for (entries[0..count]) |*entry| {
        if (std.mem.eql(u8, entry.element, element)) {
            entry.steps = steps;
            return;
        }
    }
    if (count == max_entries) return;
    entries[count] = .{ .element = element, .steps = steps };
    count += 1;
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
    for (entries[0..count]) |entry| {
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
    defer count = saved_count;
    count = 0;
    test_calls = 0;
    install("x-test", &testSteps);
    install("x-test", &testSteps);
    try std.testing.expectEqual(@as(usize, 1), count);
    // Never dereferenced: the steps ignore the element.
    var element: runtime.Instance = undefined;
    run(&element, "x-test", "src", null, "a", null);
    run(&element, "div", "src", null, "a", null);
    try std.testing.expectEqual(@as(usize, 1), test_calls);
}
