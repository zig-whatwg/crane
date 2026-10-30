//! CSS Syntax 3 sections 5.5.2–5.5.5 and CSS Nesting 1 section 5:
//! discarded rules do not create CSSOM declaration boundaries (Q122–Q123).
const std = @import("std");
const dom = @import("dom");
const a = std.testing.allocator;

fn value(allocator: std.mem.Allocator, rule: *dom.style.rules.Rule, name: []const u8, expected: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try rule.block().?.getPropertyValue(name, &text);
    try std.testing.expectEqualStrings(expected, text.items);
}

fn leading(allocator: std.mem.Allocator) !void {
    const inputs = [_][]const u8{
        ".x { @unknown {} color: green; }",
        ".x { @unknown prelude; color: green; }",
        ".x { color: red; @unknown {} color: green; }",
        ".x { color: red; @unknown; @another {} color: green; }",
    };
    for (inputs) |input| {
        const sheet = try dom.style.SheetRecord.create(allocator, input, .{});
        defer sheet.unref();
        const rules = try sheet.rulesWith(.{ .allocator = allocator });
        try std.testing.expectEqual(@as(usize, 1), rules.items.len);
        const parent = rules.items[0];
        try std.testing.expectEqual(@as(usize, 0), parent.children().?.items.len);
        try value(allocator, parent, "color", "green");
    }
}

test "discarded at-rules keep leading declarations in the parent style" {
    try leading(a);
}

fn invalidQualified(allocator: std.mem.Allocator) !void {
    // The four var-with-blocks.html recovery shapes. The invalid ordinary
    // declaration is discarded; the later declaration still belongs to the
    // same CSSOM block. No substitution is involved in this parse-time check.
    const invalid_values = [_][]const u8{
        "var(--x) { }", "{ } var(--x)", "{ var(--x) } A", "A { var(--x) }",
    };
    for (invalid_values) |invalid| {
        for ([_]bool{ false, true }) |after_child| {
            const source = try std.fmt.allocPrint(
                allocator,
                ".x {{ {s} color: rgb(2, 2, 2); color: {s}; background-color: rgb(1, 1, 1); }}",
                .{ if (after_child) "& {}" else "", invalid },
            );
            defer allocator.free(source);
            const sheet = try dom.style.SheetRecord.create(allocator, source, .{});
            defer sheet.unref();
            const rules = try sheet.rulesWith(.{ .allocator = allocator });
            try std.testing.expectEqual(@as(usize, 1), rules.items.len);
            const parent = rules.items[0];
            const children = parent.children().?.items;
            try std.testing.expectEqual(@as(usize, if (after_child) 2 else 0), children.len);
            const declaration_rule = if (after_child) children[1] else parent;
            try value(allocator, declaration_rule, "color", "rgb(2, 2, 2)");
            try value(allocator, declaration_rule, "background-color", "rgb(1, 1, 1)");
        }
    }
}

test "discarded invalid qualified rules preserve surrounding declarations" {
    try invalidQualified(a);
}

fn trailing(allocator: std.mem.Allocator) !void {
    const sheet = try dom.style.SheetRecord.create(allocator,
        \\.x { color: red; & {} color: green; @unknown {}
        \\ background-color: blue; @another; width: 1px;
        \\ @media all {} color: black; }
    , .{});
    defer sheet.unref();
    const rules = try sheet.rulesWith(.{ .allocator = allocator });
    const parent = rules.items[0];
    try value(allocator, parent, "color", "red");
    const children = parent.children().?.items;
    // Empty but retained style/media rules still separate the runs.
    try std.testing.expectEqual(@as(usize, 4), children.len);
    try std.testing.expectEqualStrings("style", @tagName(children[0].kind()));
    try std.testing.expectEqualStrings("nested_declarations", @tagName(children[1].kind()));
    try value(allocator, children[1], "color", "green");
    try value(allocator, children[1], "background-color", "blue");
    try value(allocator, children[1], "width", "1px");
    try std.testing.expectEqualStrings("media", @tagName(children[2].kind()));
    try std.testing.expectEqualStrings("nested_declarations", @tagName(children[3].kind()));
    try value(allocator, children[3], "color", "black");
    for (children) |child| try std.testing.expect(child.parent_rule == parent);
}

test "discarded at-rules merge only adjacent trailing declaration runs" {
    try trailing(a);
}

fn importance(allocator: std.mem.Allocator) !void {
    const sheet = try dom.style.SheetRecord.create(allocator,
        \\.x { color: red !important; --token: first !important;
        \\ @unknown {} color: green; --token: second;
        \\ & {} color: blue; --token: third; @unknown;
        \\ color: black !important; --token: fourth !important; }
    , .{});
    defer sheet.unref();
    const rules = try sheet.rulesWith(.{ .allocator = allocator });
    const parent = rules.items[0];
    try value(allocator, parent, "color", "red");
    try value(allocator, parent, "--token", "first");
    try std.testing.expect(parent.block().?.getPropertyPriority("color"));
    try std.testing.expect(parent.block().?.getPropertyPriority("--token"));
    const children = parent.children().?.items;
    try std.testing.expectEqual(@as(usize, 2), children.len);
    try value(allocator, children[1], "color", "black");
    try value(allocator, children[1], "--token", "fourth");
    try std.testing.expect(children[1].block().?.getPropertyPriority("color"));
    try std.testing.expect(children[1].block().?.getPropertyPriority("--token"));
}

test "recovered declaration runs preserve importance and custom property order" {
    try importance(a);
}

fn groups(allocator: std.mem.Allocator) !void {
    const groups_to_test = [_][]const u8{ "@media all", "@supports (color: red)", "@layer named", "@container (width > 0px)" };
    for (groups_to_test) |group| {
        const source = try std.fmt.allocPrint(allocator,
            \\.x {{ {s} {{ @unknown {{}} color: red; @another; color: green;
            \\ & {{}} width: 1px; @unknown; height: 2px; }} }}
        , .{group});
        defer allocator.free(source);
        const sheet = try dom.style.SheetRecord.create(allocator, source, .{});
        defer sheet.unref();
        const rules = try sheet.rulesWith(.{ .allocator = allocator });
        const parent = rules.items[0];
        try std.testing.expectEqual(@as(usize, 1), parent.children().?.items.len);
        const group_rule = parent.children().?.items[0];
        const children = group_rule.children().?.items;
        // A group cannot hold declarations directly; its first run keeps a wrapper.
        try std.testing.expectEqual(@as(usize, 3), children.len);
        try std.testing.expectEqualStrings("nested_declarations", @tagName(children[0].kind()));
        try value(allocator, children[0], "color", "green");
        try std.testing.expectEqualStrings("style", @tagName(children[1].kind()));
        try std.testing.expectEqualStrings("nested_declarations", @tagName(children[2].kind()));
        try value(allocator, children[2], "width", "1px");
        try value(allocator, children[2], "height", "2px");
        for (children) |child| try std.testing.expect(child.parent_rule == group_rule);
    }
}

test "conditional groups keep their leading declaration wrapper after recovery" {
    try groups(a);
}

test "declaration run recovery unwinds every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, leading, .{});
    try std.testing.checkAllAllocationFailures(a, invalidQualified, .{});
    try std.testing.checkAllAllocationFailures(a, trailing, .{});
    try std.testing.checkAllAllocationFailures(a, importance, .{});
    try std.testing.checkAllAllocationFailures(a, groups, .{});
}
