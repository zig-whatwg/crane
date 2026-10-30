//! CSS Nesting 1, Conditional 5 and the bounded Cascade 6 rule model.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const selector = @import("selector");
const a = std.testing.allocator;

fn keyframeRuns(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "@keyframes k { from { color: red; @x; width: 1px; :invalid { height: 9px } height: 2px; @y {} color: blue !important; animation-name: ignored; opacity: 0.5 } }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    const frame = list.items[0].children().?.items[0];
    const text = try frame.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("0% { color: red; width: 1px; height: 2px; opacity: 0.5; }", text);
}

test "keyframes keep declarations after discarded rules in keyframe context" {
    try keyframeRuns(a);
    try std.testing.checkAllAllocationFailures(a, keyframeRuns, .{});
}

test "nested rule payloads fit the existing font-rule payload budget" {
    if (comptime @hasDecl(selector, "nesting")) {
        // A rule without nesting must not grow merely to represent another
        // rule kind. FontRule is the pre-existing largest union arm.
        const Data = dom.style.rules.Data;
        const budget = @sizeOf(@FieldType(Data, "font_face"));
        inline for (.{ "style", "nested_declarations", "container", "scope" }) |kind|
            try std.testing.expect(@sizeOf(@FieldType(Data, kind)) <= budget);
    } else return error.MissingNesting;
}

fn ordered(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "article { color: red; & .child { color: blue; } color: green; @media all { color: black; } }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const parent = list.items[0];
    try std.testing.expect(parent.children() != null);
    const children = parent.children().?.items;
    try std.testing.expectEqual(@as(usize, 3), children.len);
    try std.testing.expectEqualStrings("style", @tagName(children[0].kind()));
    try std.testing.expectEqualStrings("nested_declarations", @tagName(children[1].kind()));
    try std.testing.expectEqualStrings("media", @tagName(children[2].kind()));
    try std.testing.expectEqualStrings("nested_declarations", @tagName(children[2].children().?.items[0].kind()));
    for (children) |child| try std.testing.expect(child.parent_rule == parent);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 4), compiled.rules.items.len);
    for (compiled.rules.items, 0..) |rule, i| {
        try std.testing.expectEqual(@as(u32, @intCast(i)), rule.position);
        var one = [_]selector.ComplexSelector{rule.complex.*};
        const view = selector.SelectorList{ .allocator = allocator, .selectors = &one };
        try std.testing.expect(!selector.nesting.contains(&view));
    }
    const text = try parent.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "color: red;").? < std.mem.indexOf(u8, text, "& .child").?);
    try std.testing.expect(std.mem.indexOf(u8, text, "& .child").? < std.mem.indexOf(u8, text, "color: green;").?);
}

test "nested rule models preserve declaration identity and cascade order" {
    if (comptime @hasDecl(selector, "nesting")) {
        try ordered(a);
    } else return error.MissingNesting;
}

fn retained(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "#parent, .other { & .child { color: green; } }", .{});
    var owns = true;
    defer if (owns) record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    const parent = list.items[0];
    try std.testing.expect(parent.children() != null);
    try std.testing.expectEqual(@as(usize, 1), parent.children().?.items.len);
    const child = parent.children().?.items[0];
    child.ref();
    defer child.unref();
    record.unref();
    owns = false;
    try std.testing.expect(child.parent_rule == null);
    const complex = &child.matchingSelectors().?.selectors[0];
    const parents = complex.combinators[0].compound.simple_selectors[0].PseudoClass.kind.Is;
    try std.testing.expectEqualStrings("parent", parents.selectors[0].compound.simple_selectors[0].Id.id);
    try std.testing.expectEqualStrings("other", parents.selectors[1].compound.simple_selectors[0].Class.class_name);
    const text = try child.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("& .child { color: green; }", text);
}

test "a retained nested rule owns the selector names copied from its destroyed parent" {
    if (comptime @hasDecl(selector, "nesting")) {
        try retained(a);
    } else return error.MissingNesting;
}

fn containers(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "@container Name (widTH>=10PX), style(--flag) { .child { color: green } }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const rule = list.items[0];
    try std.testing.expectEqualStrings("container", @tagName(rule.kind()));
    try std.testing.expectEqual(@as(usize, 1), rule.children().?.items.len);
    try std.testing.expectEqualStrings("Name (width >= 10px), style(--flag)", rule.prelude);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    // Preservation pin: no layout-backed container evaluator is installed.
    // Parsing the rule must not make its conditional children unconditional.
    try std.testing.expectEqual(@as(usize, 0), compiled.rules.items.len);
}

test "container rules preserve conditions and keep unevaluated children inert" {
    try containers(a);
}

fn scopes(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "@scope (.root) to (> .limit) { & { color: green } } .ordinary { color: red }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    const rule = list.items[0];
    try std.testing.expectEqualStrings("scope", @tagName(rule.kind()));
    try std.testing.expectEqual(@as(usize, 1), rule.children().?.items.len);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    // Q21 preservation pin: CSS @SCOPE EVALUATION is routed. The parsed
    // children cannot affect style until that capability actually exists.
    try std.testing.expectEqual(@as(usize, 1), compiled.rules.items.len);
    try std.testing.expectEqualStrings("ordinary", compiled.rules.items[0].complex.compound.simple_selectors[0].Class.class_name);
    const text = try rule.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expect(std.mem.startsWith(u8, text, "@scope (.root) to (> .limit) {"));
}

test "scope rules retain their CSSOM while their children remain inert" {
    if (comptime @hasDecl(selector, "nesting")) {
        try scopes(a);
    } else return error.MissingNesting;
}

test "rule tree parsing compilation and detached ownership unwind every allocation failure" {
    if (comptime @hasDecl(selector, "nesting")) {
        try std.testing.checkAllAllocationFailures(a, ordered, .{});
        try std.testing.checkAllAllocationFailures(a, retained, .{});
        try std.testing.checkAllAllocationFailures(a, containers, .{});
        try std.testing.checkAllAllocationFailures(a, scopes, .{});
    } else return error.MissingNesting;
}

fn edits() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const record = try dom.style.SheetRecord.create(a, ".old { & .child { & .grandchild { color: green } } }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    const parent = list.items[0];
    try std.testing.expect(parent.children() != null);
    const child = parent.children().?.items[0];
    const object = try interfaces.CSSStyleRule.initWith(a, &ctx, .{ .css_rule = parent });
    defer interfaces.CSSStyleRule.deinit(object);
    try interfaces.CSSStyleRule.set_selectorText(object, runtime.DOMString.initInterned("#replacement"));
    const copied_parent = child.matchingSelectors().?.selectors[0].combinators[0].compound.simple_selectors[0].PseudoClass.kind.Is;
    try std.testing.expectEqualStrings("replacement", copied_parent.selectors[0].compound.simple_selectors[0].Id.id);
    const grandchild = child.children().?.items[0];
    try std.testing.expectEqual(@as(u32, 1), grandchild.matchingSelectors().?.selectors[0].calculateSpecificity().id);
    try std.testing.expectEqual(@as(u32, 0), try interfaces.CSSGroupingRule.call_insertRule(object, runtime.DOMString.initInterned("color: blue"), .{ .was_passed = true, .value = 0 }));
    try std.testing.expectEqualStrings("nested_declarations", @tagName(parent.children().?.items[0].kind()));
    try std.testing.expectEqual(@as(u32, 1), parent.children().?.items[0].matchingSelectors().?.selectors[0].calculateSpecificity().id);
    child.ref();
    defer child.unref();
    try interfaces.CSSGroupingRule.call_deleteRule(object, 1);
    try std.testing.expect(child.parent_rule == null);
    try std.testing.expectEqual(@as(u32, 0), child.matchingSelectors().?.selectors[0].calculateSpecificity().id);
    try std.testing.expectEqual(@as(u32, 0), grandchild.matchingSelectors().?.selectors[0].calculateSpecificity().id);
}

test "selectorText and CSSOM edits rebuild nested descendants" {
    if (comptime @hasDecl(selector, "nesting")) {
        const Run = struct {
            fn run(result: *?anyerror) void {
                edits() catch |err| {
                    result.* = err;
                };
            }
        };
        var result: ?anyerror = null;
        const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
        thread.join();
        if (result) |err| return err;
    } else return error.MissingNesting;
}

fn mutationFailure(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, ".old { & .child { & .grandchild { color: green; } } color: red; }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    const parent = list.items[0];
    try std.testing.expect(parent.children() != null);
    const child = parent.children().?.items[0];
    const old_child_selectors = child.matchingSelectors().?;
    const grandchild = child.children().?.items[0];
    const old_grandchild_selectors = grandchild.matchingSelectors().?;
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    const version = record.contents_version;
    var parsed = try dom.style.rules.parseCssomSelector(allocator, try allocator.dupe(u8, "#replacement"), null);
    var owns = true;
    defer if (owns) {
        parsed.selectors.deinit();
        allocator.free(parsed.text);
    };
    dom.style.rules.replaceStyleSelector(parent, parsed) catch |err| {
        // Every failing allocation in any descendant must leave the whole
        // existing model and its compiled index untouched.
        try std.testing.expectEqualStrings(".old", parent.prelude);
        try std.testing.expect(child.matchingSelectors().? == old_child_selectors);
        try std.testing.expect(grandchild.matchingSelectors().? == old_grandchild_selectors);
        try std.testing.expect(record.compiled.? == compiled);
        try std.testing.expectEqual(version, record.contents_version);
        return err;
    };
    owns = false;
    try std.testing.expectEqualStrings("#replacement", parent.prelude);
    try std.testing.expectEqual(@as(u32, 1), grandchild.matchingSelectors().?.selectors[0].calculateSpecificity().id);
    try std.testing.expectEqual(version +% 1, record.contents_version);
    _ = try record.contentsOf(.{ .allocator = allocator });
}

test "parent selector rebuilding is atomic across every allocation failure" {
    if (comptime @hasDecl(selector, "nesting")) {
        try mutationFailure(a);
        try std.testing.checkAllAllocationFailures(a, mutationFailure, .{});
    } else return error.MissingNesting;
}

fn hierarchy(allocator: std.mem.Allocator) !void {
    // Chrome/Firefox parse, all-three CSSOM insertion, probe Q36 on
    // 2026-10-27: the style-ancestor restriction persists through @scope.
    const record = try dom.style.SheetRecord.create(allocator, ".a { @font-face {} @layer one; @media all { @font-face {} } @scope { @font-face {} @keyframes x { to { color: red } } } } @scope { @font-face {} } @media all { color: red; }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 3), list.items.len);
    const nested = list.items[0].children() orelse return error.MissingNestedRules;
    try std.testing.expectEqual(@as(usize, 2), nested.items.len);
    for (nested.items) |group| try std.testing.expectEqual(@as(usize, 0), group.children().?.items.len);
    const top_scope = list.items[1];
    try std.testing.expectEqual(@as(usize, 1), top_scope.children().?.items.len);
    try std.testing.expectEqualStrings("font_face", @tagName(top_scope.children().?.items[0].kind()));
    // Existing top-level media declaration dropping is a preservation pin.
    try std.testing.expectEqual(@as(usize, 0), list.items[2].children().?.items.len);
    const empty_scope_text = try nested.items[1].serialize(allocator);
    defer allocator.free(empty_scope_text);
    try std.testing.expectEqualStrings("@scope {\n}", empty_scope_text);
}

test "global rules are rejected through nested scope but retained in top-level scope" {
    if (comptime @hasDecl(selector, "nesting")) {
        try hierarchy(a);
        try std.testing.checkAllAllocationFailures(a, hierarchy, .{});
    } else return error.MissingNesting;
}

// Native model checks own only this wrapper. The separate real-Window
// holder fixture exercises objects.ruleObject and its GC-traced parent chain.
fn modelObject(rule: *dom.style.Rule, context: runtime.Context) !*runtime.Instance {
    const args = .{ .css_rule = rule };
    return switch (rule.kind()) {
        .style => interfaces.CSSStyleRule.initWith(a, context, args),
        .scope => interfaces.CSSScopeRule.initWith(a, context, args),
        .media => interfaces.CSSMediaRule.initWith(a, context, args),
        .supports => interfaces.CSSSupportsRule.initWith(a, context, args),
        .layer_block => interfaces.CSSLayerBlockRule.initWith(a, context, args),
        .container => interfaces.CSSContainerRule.initWith(a, context, args),
        else => error.UnexpectedModelKind,
    };
}

fn hierarchyEdits() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const Case = struct { sheet: []const u8, child: bool = false, insert: []const u8, failure: ?anyerror = null, kind: []const u8 = "nested_declarations" };
    const cases = [_]Case{
        .{ .sheet = ".a {}", .insert = "@font-face {}", .failure = error.HierarchyRequestError },
        .{ .sheet = ".a { @media all {} }", .child = true, .insert = "@font-face {}", .failure = error.HierarchyRequestError },
        .{ .sheet = ".a { @scope {} }", .child = true, .insert = "@font-face {}", .failure = error.HierarchyRequestError },
        .{ .sheet = "@scope {}", .insert = "@font-face {}", .kind = "font_face" },
        // Preservation pins for the three already-rejected contexts.
        .{ .sheet = "@media all {}", .insert = "color: red", .failure = error.SyntaxError },
        .{ .sheet = "@supports (color: red) {}", .insert = "color: red", .failure = error.SyntaxError },
        .{ .sheet = "@layer l {}", .insert = "color: red", .failure = error.SyntaxError },
        .{ .sheet = "@scope {}", .insert = "color: red" },
        .{ .sheet = ".a { @media all {} }", .child = true, .insert = "color: red" },
    };
    for (cases) |case| {
        const record = try dom.style.SheetRecord.create(a, case.sheet, .{});
        defer record.unref();
        const list = try record.rulesWith(.{ .allocator = a });
        try std.testing.expectEqual(@as(usize, 1), list.items.len);
        var rule = list.items[0];
        if (case.child) {
            try std.testing.expect(rule.children() != null);
            try std.testing.expectEqual(@as(usize, 1), rule.children().?.items.len);
            rule = rule.children().?.items[0];
        }
        const object = try modelObject(rule, &ctx);
        defer runtime.Instance.deinit(object);
        const insertion = interfaces.CSSGroupingRule.call_insertRule(object, runtime.DOMString.initInterned(case.insert), .{ .was_passed = true, .value = 0 });
        if (case.failure) |failure| {
            try std.testing.expectError(failure, insertion);
            try std.testing.expectEqual(@as(usize, 0), rule.children().?.items.len);
        } else {
            try std.testing.expectEqual(@as(u32, 0), try insertion);
            try std.testing.expectEqualStrings(case.kind, @tagName(rule.children().?.items[0].kind()));
            if (std.mem.eql(u8, case.kind, "nested_declarations")) {
                const text = try rule.children().?.items[0].serialize(a);
                defer a.free(text);
                try std.testing.expectEqualStrings("color: red;", text);
            }
        }
    }
}

test "CSSOM hierarchy and declaration fallback follow the three-browser boundary probe" {
    if (comptime @hasDecl(selector, "nesting")) {
        const Run = struct {
            fn run(result: *?anyerror) void {
                hierarchyEdits() catch |err| {
                    result.* = err;
                };
            }
        };
        var result: ?anyerror = null;
        const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
        thread.join();
        if (result) |err| return err;
    } else return error.MissingNesting;
}

const conditional_groups = [_][]const u8{ "@media all", "@supports (color: red)", "@layer l", "@container (width > 0px)" };

fn scopedGroupCases(allocator: std.mem.Allocator) !void {
    // Q38, 2026-10-27: Firefox/Safari keep parsed declarations through
    // each group; Chrome drops them. All three permit CSSOM insertion.
    for (conditional_groups) |group| {
        for ([_]bool{ false, true }) |style_parent| {
            for ([_]bool{ false, true }) |extra_group| {
                const text = try std.fmt.allocPrint(allocator, "{s}@scope {{ {s} {{ {s}color: red;{s} }} }}{s}", .{
                    if (style_parent) ".parent { " else "",   group,
                    if (extra_group) "@media all { " else "", if (extra_group) " }" else "",
                    if (style_parent) " }" else "",
                });
                defer allocator.free(text);
                const record = try dom.style.SheetRecord.create(allocator, text, .{});
                defer record.unref();
                const list = try record.rulesWith(.{ .allocator = allocator });
                try std.testing.expectEqual(@as(usize, 1), list.items.len);
                var current = list.items[0];
                if (style_parent) current = try onlyChild(current);
                try std.testing.expectEqualStrings("scope", @tagName(current.kind()));
                current = try onlyChild(current);
                if (extra_group) current = try onlyChild(current);
                const declaration = try onlyChild(current);
                try std.testing.expectEqualStrings("nested_declarations", @tagName(declaration.kind()));
                try std.testing.expectEqual(selector.Specificity{}, declaration.matchingSelectors().?.selectors[0].calculateSpecificity());
            }
        }
    }
}

fn onlyChild(rule: *dom.style.Rule) !*dom.style.Rule {
    const list = rule.children() orelse return error.MissingNestedRules;
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    return list.items[0];
}

test "scope declaration context crosses every conditional group and style boundary" {
    if (comptime @hasDecl(selector, "nesting")) {
        try scopedGroupCases(a);
    } else return error.MissingNesting;
}

fn scopedGroupEdits() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    for (conditional_groups) |group| {
        for ([_]bool{ false, true }) |style_parent| {
            for ([_]bool{ false, true }) |extra_group| {
                const text = try std.fmt.allocPrint(a, "{s}@scope {{ {s} {{ {s}{s} }} }}{s}", .{
                    if (style_parent) ".parent { " else "",   group,
                    if (extra_group) "@media all { " else "", if (extra_group) " }" else "",
                    if (style_parent) " }" else "",
                });
                defer a.free(text);
                const record = try dom.style.SheetRecord.create(a, text, .{});
                defer record.unref();
                const list = try record.rulesWith(.{ .allocator = a });
                try std.testing.expectEqual(@as(usize, 1), list.items.len);
                var current = list.items[0];
                if (style_parent) current = try onlyChild(current);
                current = try onlyChild(current);
                if (extra_group) current = try onlyChild(current);
                const object = try modelObject(current, &ctx);
                defer runtime.Instance.deinit(object);
                try std.testing.expectEqual(@as(u32, 0), try interfaces.CSSGroupingRule.call_insertRule(object, runtime.DOMString.initInterned("color: red"), .{ .was_passed = true, .value = 0 }));
                const declaration = try onlyChild(current);
                try std.testing.expectEqualStrings("nested_declarations", @tagName(declaration.kind()));
                try std.testing.expectEqual(selector.Specificity{}, declaration.matchingSelectors().?.selectors[0].calculateSpecificity());
            }
        }
    }
}

test "CSSOM declaration fallback inherits scope context at any conditional depth" {
    if (comptime @hasDecl(selector, "nesting")) {
        const Run = struct {
            fn run(result: *?anyerror) void {
                scopedGroupEdits() catch |err| {
                    result.* = err;
                };
            }
        };
        var result: ?anyerror = null;
        const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
        thread.join();
        if (result) |err| return err;
    } else return error.MissingNesting;
}

const ScopeProbe = struct {
    sheet: []const u8,
    nested: bool = true,
    start: ?[]const u8,
    end: ?[]const u8 = null,
    css_text: []const u8,
    parent_text: ?[]const u8 = null,
};

// Q43's Chrome 156 / Firefox 158 / Safari 27 probe (2026-10-27):
// all three store the implicit start anchor, but never add one to the end.
const scope_probes = [_]ScopeProbe{
    .{ .sheet = ".parent { @scope (.child) to (.limit) {} }", .start = "& .child", .end = ".limit", .css_text = "@scope (& .child) to (.limit) {\n}", .parent_text = ".parent {\n  @scope (& .child) to (.limit) {\n}\n}" },
    .{ .sheet = ".parent { @scope (> .child) {} }", .start = "& > .child", .css_text = "@scope (& > .child) {\n}" },
    .{ .sheet = ".parent { @scope (& .child) {} }", .start = "& .child", .css_text = "@scope (& .child) {\n}" },
    .{ .sheet = ".parent { @scope (.child) to (& .limit) {} }", .start = "& .child", .end = "& .limit", .css_text = "@scope (& .child) to (& .limit) {\n}" },
    .{ .sheet = ".parent { @scope {} }", .start = null, .css_text = "@scope {\n}" },
    .{ .sheet = ".parent { @scope to (.limit) {} }", .start = null, .end = ".limit", .css_text = "@scope to (.limit) {\n}" },
    .{ .sheet = "@scope (.outer) { @scope (.inner) {} }", .start = ".inner", .css_text = "@scope (.inner) {\n}" },
    .{ .sheet = "@scope (.child) to (.limit) {}", .nested = false, .start = ".child", .end = ".limit", .css_text = "@scope (.child) to (.limit) {\n}" },
};

fn expectBoundary(expected: ?[]const u8, actual: ?[]const u8) !void {
    if (expected) |text| {
        try std.testing.expect(actual != null);
        try std.testing.expectEqualStrings(text, actual.?);
    } else try std.testing.expect(actual == null);
}

fn scopeSerialization(allocator: std.mem.Allocator) !void {
    for (scope_probes) |probe| {
        const record = try dom.style.SheetRecord.create(allocator, probe.sheet, .{});
        defer record.unref();
        const list = try record.rulesWith(.{ .allocator = allocator });
        try std.testing.expectEqual(@as(usize, 1), list.items.len);
        const parent = list.items[0];
        const scope = if (probe.nested) try onlyChild(parent) else parent;
        try std.testing.expectEqualStrings("scope", @tagName(scope.kind()));
        try expectBoundary(probe.start, scope.data.scope.start);
        try expectBoundary(probe.end, scope.data.scope.end);
        const text = try scope.serialize(allocator);
        defer allocator.free(text);
        try std.testing.expectEqualStrings(probe.css_text, text);
        if (probe.parent_text) |expected| {
            const parent_text = try parent.serialize(allocator);
            defer allocator.free(parent_text);
            try std.testing.expectEqualStrings(expected, parent_text);
        }
    }
}

test "scope boundary serialization follows the three-browser implicit anchor probe" {
    if (comptime @hasDecl(selector, "nesting")) {
        try scopeSerialization(a);
        try std.testing.checkAllAllocationFailures(a, scopeSerialization, .{});
    } else return error.MissingNesting;
}

fn scopeAccessors() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    for (scope_probes) |probe| {
        const record = try dom.style.SheetRecord.create(a, probe.sheet, .{});
        defer record.unref();
        const list = try record.rulesWith(.{ .allocator = a });
        try std.testing.expectEqual(@as(usize, 1), list.items.len);
        const parent = list.items[0];
        const scope = if (probe.nested) try onlyChild(parent) else parent;
        const object = try modelObject(scope, &ctx);
        defer runtime.Instance.deinit(object);
        var start = try interfaces.CSSScopeRule.get_start(object);
        defer if (start) |*text| text.deinit(a);
        var end = try interfaces.CSSScopeRule.get_end(object);
        defer if (end) |*text| text.deinit(a);
        try expectBoundary(probe.start, if (start) |text| text.asSlice() else null);
        try expectBoundary(probe.end, if (end) |text| text.asSlice() else null);
    }
}

test "CSSScopeRule accessors return stored boundaries including implicit start anchors" {
    if (comptime @hasDecl(selector, "nesting")) {
        const Run = struct {
            fn run(result: *?anyerror) void {
                scopeAccessors() catch |err| {
                    result.* = err;
                };
            }
        };
        var result: ?anyerror = null;
        const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
        thread.join();
        if (result) |err| return err;
    } else return error.MissingNesting;
}

fn groups(allocator: std.mem.Allocator) !void {
    const pairs = .{
        .{ "@media all {}", "@media all {\n}" },
        .{ "@supports (color: red) {}", "@supports (color: red) {\n}" },
        .{ "@layer named {}", "@layer named {\n}" },
        .{ "@container (width>10px) {}", "@container (width > 10px) {\n}" },
        .{ "@media all { .a { color: red } }", "@media all {\n  .a { color: red; }\n}" },
        .{ "@container FUTURE( URL(\"x\") ,  [a]) {}", "@container FUTURE( URL(\"x\") ,  [a]) {\n}" },
    };
    inline for (pairs) |pair| {
        const record = try dom.style.SheetRecord.create(allocator, pair[0], .{});
        defer record.unref();
        const list = try record.rulesWith(.{ .allocator = allocator });
        try std.testing.expectEqual(@as(usize, 1), list.items.len);
        const text = try list.items[0].serialize(allocator);
        defer allocator.free(text);
        try std.testing.expectEqualStrings(pair[1], text);
    }
}

test "empty group serialization follows browsers and nonempty indentation stays intact" {
    try groups(a);
}

test "empty group serialization unwinds every OOM" {
    try std.testing.checkAllAllocationFailures(a, groups, .{});
}
