//! Registered custom properties in the cascade (lane vars1b2; CSS
//! Properties and Values API 1 §§2.4, 3; design sections 3-4): the initial
//! value instead of the guaranteed-invalid value, inherits: false, the
//! CSS-wide keywords, var() of a registered property, and what an element
//! that sets nothing pays (nothing: no record of its own).
const std = @import("std");
const css = @import("css");
const support = @import("vars2_support.zig");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const cascade_mod = css.cascade;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;
const Snapshot = css.registered_properties.Snapshot;

const Tree = support.Tree;
const expectCustom = support.expectCustom;

const defs = [_]support.Def{
    .{ .name = "--len", .syntax = "<length>", .inherits = false, .initial = "10px" },
    .{ .name = "--inh", .syntax = "<length>", .inherits = true, .initial = "5px" },
    .{ .name = "--any", .syntax = "*", .inherits = true, .initial = null },
    .{ .name = "--own-any", .syntax = "*", .inherits = false, .initial = null },
};

fn withRegistrations(allocator: Allocator) !Tree {
    return .{ .allocator = allocator, .registered = try support.snapshotOf(allocator, .{}, &defs) };
}

fn endTree(tree: *Tree) void {
    tree.deinit();
    if (tree.registered) |r| r.release();
}

test "an unset registered property is its initial value; a universal one without one is guaranteed-invalid" {
    var tree = try withRegistrations(testing.allocator);
    defer endTree(&tree);
    const root = try tree.element("color: red");
    try expectCustom(root, "--len", "10px");
    try expectCustom(root, "--inh", "5px");
    try expectCustom(root, "--any", null);
    try expectCustom(root, "--unregistered", null);
    // Nothing set: no record of its own (the initial values are the
    // snapshot's), and no non-inherited record.
    try testing.expect(root.custom == null);
    try testing.expect(root.custom_own == null);
}

test "inherits: false - a child takes the initial value, not its parent's" {
    var tree = try withRegistrations(testing.allocator);
    defer endTree(&tree);
    const parent = try tree.element("--len: 20px; --inh: 30px; --own-any: a; --any: b");
    try expectCustom(parent, "--len", "20px");
    try expectCustom(parent, "--own-any", "a");
    const child = try tree.element("color: red");
    try expectCustom(child, "--len", "10px");
    try expectCustom(child, "--own-any", null);
    try expectCustom(child, "--inh", "30px");
    try expectCustom(child, "--any", "b");
    // The child sets nothing: it shares its parent's inherited record and
    // has no non-inherited one.
    try testing.expectEqual(parent.custom.?, child.custom.?);
    try testing.expect(child.custom_own == null);
}

test "initial, inherit and unset on registered properties" {
    var tree = try withRegistrations(testing.allocator);
    defer endTree(&tree);
    _ = try tree.element("--len: 20px; --inh: 30px");
    const child = try tree.element("--len: inherit; --inh: initial");
    try expectCustom(child, "--len", "20px");
    try expectCustom(child, "--inh", "5px");
    const grandchild = try tree.element("--len: unset; --inh: unset");
    // unset: inherit for an inherited property, initial otherwise.
    try expectCustom(grandchild, "--len", "10px");
    try expectCustom(grandchild, "--inh", "5px");
}

test "var() of a registered property reads its initial or inherited value" {
    var tree = try withRegistrations(testing.allocator);
    defer endTree(&tree);
    _ = try tree.element("--len: 20px; --inh: 30px");
    const child = try tree.element("--a: var(--len); --b: var(--inh); --c: var(--any, fallback)");
    try expectCustom(child, "--a", "10px");
    try expectCustom(child, "--b", "30px");
    try expectCustom(child, "--c", "fallback");
}

test "getComputedStyle's custom names: set values and non-null initial values, in code-point order" {
    var tree = try withRegistrations(testing.allocator);
    defer endTree(&tree);
    const root = try tree.element("--z: 1; --own-any: q");
    const names = try root.customNames(testing.allocator);
    defer testing.allocator.free(names);
    const expected = [_][]const u8{ "--inh", "--len", "--own-any", "--z" };
    try testing.expectEqual(expected.len, names.len);
    for (expected, names) |e, n| try testing.expectEqualStrings(e, n);
    // A non-inherited universal property set on the parent only is not the
    // child's (get-computed-style-enumeration.html).
    const child = try tree.element("color: red");
    const child_names = try child.customNames(testing.allocator);
    defer testing.allocator.free(child_names);
    const child_expected = [_][]const u8{ "--inh", "--len", "--z" };
    try testing.expectEqual(child_expected.len, child_names.len);
    for (child_expected, child_names) |e, n| try testing.expectEqualStrings(e, n);
}

fn keywordsUnderOom(allocator: Allocator) !void {
    var tree = try withRegistrations(allocator);
    defer endTree(&tree);
    _ = try tree.element("--len: 20px; --inh: 30px; --own-any: a");
    const child = try tree.element("--len: inherit; --x: var(--inh)");
    try expectCustom(child, "--len", "20px");
    try expectCustom(child, "--x", "30px");
    const names = try child.customNames(allocator);
    allocator.free(names);
}

test "registered properties in the cascade survive every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, keywordsUnderOom, .{});
}

test "no snapshot: every custom property is unregistered, as before" {
    var tree: Tree = .{ .allocator = testing.allocator };
    defer tree.deinit();
    _ = try tree.element("--len: 20px");
    const child = try tree.element("color: red");
    try expectCustom(child, "--len", "20px");
    try testing.expect(child.custom_own == null);
}
