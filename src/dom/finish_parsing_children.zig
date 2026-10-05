//! What the HTML parser tells an element type about the elements it creates:
//! that it created one and pushed it onto its stack of open elements, and
//! that it popped it off - "the element is popped off the stack of open
//! elements of an HTML parser", when all of its children have been parsed.
//!
//! HTML keys several element types' processing on that pop: the object
//! element (re)determines what it represents (4.8.7), media elements and
//! select do work once their children are parsed. Their state is their
//! impls', so each element type installs its steps here, keyed by its HTML
//! local name, and the parser's DOM adapter calls them without naming an
//! impl. The shape of `attribute_change_steps.zig`.
//!
//! The design is Blink's and WebKit's: an element the parser creates is
//! created "by the parser" (Blink's CreateElementFlags::CreatedByParser,
//! Element::BeginParsingChildren), and every removal from the stack of open
//! elements calls Element::FinishParsingChildren - Blink's
//! HTMLElementStack::PopCommon (every pop, the popUntil* family and implied
//! end tags among them), RemoveNonTopCommon (the adoption agency's removal
//! of a node that is not the current node, "after head"'s removal of head)
//! and PopAll (stop parsing).
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#stack-of-open-elements
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element
//!
//! lint-impls: hook for HTMLObjectElement

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// The steps of one element type.
pub const Steps = struct {
    /// The parser created `element` and pushed it onto its stack of open
    /// elements: its children are not parsed yet. Optional.
    created: ?*const fn (element: *runtime.Instance) void = null,
    /// The parser removed `element` from its stack of open elements: its
    /// children are parsed (Blink's FinishParsingChildren). An element the
    /// parser pushes more than once - head, reprocessed in "after head" -
    /// hears it more than once.
    finished: *const fn (element: *runtime.Instance) void,
};

const Entry = struct {
    /// The element's local name, in the HTML namespace.
    local_name: []const u8,
    steps: Steps,
};

/// Few element types have steps, so a short list beats a map: the parser
/// asks it for every element it creates and pops.
const max_entries = 8;

const Table = struct {
    entries: [max_entries]Entry = undefined,
    count: usize = 0,
};

// process-wide: a hook table, written once by crane.Process while it starts (process_start.zig) and read-only after; every element type's steps are the same for every instance and thread
var table: Table = .{};

/// Install `steps` for HTML elements whose local name is `local_name` (a
/// string that lives for the program), from the owner's installHooks.
/// Installing again replaces the steps.
pub fn install(local_name: []const u8, steps: Steps) void {
    process_start.assertInstalling();
    for (table.entries[0..table.count]) |*entry| {
        if (std.mem.eql(u8, entry.local_name, local_name)) {
            entry.steps = steps;
            return;
        }
    }
    if (table.count == max_entries) return;
    table.entries[table.count] = .{ .local_name = local_name, .steps = steps };
    table.count += 1;
}

fn find(local_name: []const u8) ?*const Steps {
    for (table.entries[0..table.count]) |*entry| {
        if (entry.local_name.len == local_name.len and std.mem.eql(u8, entry.local_name, local_name)) return &entry.steps;
    }
    return null;
}

/// Whether HTML elements named `local_name` have steps here - what the
/// parser's adapter asks before it looks the element up.
pub fn hasSteps(local_name: []const u8) bool {
    return find(local_name) != null;
}

/// The parser created `element`, an HTML element named `local_name`, and
/// pushed it onto its stack of open elements.
pub fn createdByParser(element: *runtime.Instance, local_name: []const u8) void {
    const steps = find(local_name) orelse return;
    const created = steps.created orelse return;
    created(element);
}

/// The parser removed `element`, an HTML element named `local_name`, from
/// its stack of open elements.
pub fn finishedParsingChildren(element: *runtime.Instance, local_name: []const u8) void {
    const steps = find(local_name) orelse return;
    steps.finished(element);
}

const testing = std.testing;

test "steps run only for the element type that installed them, once however often installed" {
    const saved = table;
    defer table = saved;
    table = .{};
    // Declared in the test: no container-level state outlives it.
    const C = struct {
        var created: usize = 0;
        var finished: usize = 0;
        fn onCreated(_: *runtime.Instance) void {
            created += 1;
        }
        fn onFinished(_: *runtime.Instance) void {
            finished += 1;
        }
    };
    install("x-test", .{ .created = &C.onCreated, .finished = &C.onFinished });
    install("x-test", .{ .created = &C.onCreated, .finished = &C.onFinished });
    try testing.expectEqual(@as(usize, 1), table.count);
    try testing.expect(hasSteps("x-test"));
    try testing.expect(!hasSteps("x-tes"));
    try testing.expect(!hasSteps("div"));
    // Never dereferenced: the steps ignore the element.
    var element: runtime.Instance = undefined;
    createdByParser(&element, "x-test");
    createdByParser(&element, "div");
    finishedParsingChildren(&element, "x-test");
    finishedParsingChildren(&element, "x-test");
    finishedParsingChildren(&element, "div");
    try testing.expectEqual(@as(usize, 1), C.created);
    try testing.expectEqual(@as(usize, 2), C.finished);
}

test "a type with no created steps hears only the pop" {
    const saved = table;
    defer table = saved;
    table = .{};
    const C = struct {
        var created: usize = 0;
        var finished: usize = 0;
        fn onCreated(_: *runtime.Instance) void {
            created += 1;
        }
        fn onFinished(_: *runtime.Instance) void {
            finished += 1;
        }
    };
    install("x-pop", .{ .finished = &C.onFinished });
    var element: runtime.Instance = undefined;
    createdByParser(&element, "x-pop");
    finishedParsingChildren(&element, "x-pop");
    try testing.expectEqual(@as(usize, 0), C.created);
    try testing.expectEqual(@as(usize, 1), C.finished);
}
