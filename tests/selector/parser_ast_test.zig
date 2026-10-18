//! What a valid selector parses into: decoded escapes, namespace
//! constraints, names kept as written beside their lowercase (HTML 4.16.2
//! picks one per element), attribute case modifiers, An+B values, relative
//! :has() arguments, :lang() ranges and :host() arguments.

const std = @import("std");
const testing = std.testing;
const selector = @import("selector");

fn parse(input: []const u8) !selector.SelectorList {
    return selector.parse(testing.allocator, input);
}

fn firstSimple(list: *const selector.SelectorList) selector.SimpleSelector {
    return list.selectors[0].compound.simple_selectors[0];
}

test "escapes decode into the id, class and attribute value the list owns" {
    var id = try parse("#\\30 nextIsWhiteSpace");
    defer id.deinit();
    try testing.expectEqualStrings("0nextIsWhiteSpace", firstSimple(&id).Id.id);

    var class = try parse(".test\\.foo\\[5\\]bar");
    defer class.deinit();
    try testing.expectEqualStrings("test.foo[5]bar", firstSimple(&class).Class.class_name);

    var value = try parse("[data-attr-whitespace~=\"\\0000e9\"]");
    defer value.deinit();
    try testing.expectEqualStrings("\u{E9}", firstSimple(&value).Attribute.matcher.Includes.value);

    var eof = try parse("#eof\\");
    defer eof.deinit();
    try testing.expectEqualStrings("eof\u{FFFD}", firstSimple(&eof).Id.id);
}

test "type selectors keep the name as written and lowercased, and their namespace" {
    var plain = try parse("SVG");
    defer plain.deinit();
    const t = firstSimple(&plain).Type;
    try testing.expectEqualStrings("SVG", t.tag_name);
    try testing.expectEqualStrings("svg", t.lower_name);
    try testing.expect(t.namespace == .any);

    var none = try parse("|div");
    defer none.deinit();
    try testing.expect(firstSimple(&none).Type.namespace == .none);

    var any = try parse("*|coreProperties");
    defer any.deinit();
    try testing.expect(firstSimple(&any).Type.namespace == .any);
    try testing.expectEqualStrings("coreProperties", firstSimple(&any).Type.tag_name);

    var universal_none = try parse("|*");
    defer universal_none.deinit();
    try testing.expect(firstSimple(&universal_none).Universal.namespace == .none);
}

test "attribute selectors: namespace, names, case modifier and HTML's value list" {
    var any = try parse("[*|TiTlE]");
    defer any.deinit();
    const a = firstSimple(&any).Attribute;
    try testing.expect(a.namespace == .any);
    try testing.expectEqualStrings("TiTlE", a.name);
    try testing.expectEqualStrings("title", a.lower_name);
    try testing.expect(a.matcher == .Presence);

    var plain = try parse("[viewBox]");
    defer plain.deinit();
    try testing.expect(firstSimple(&plain).Attribute.namespace == .none);
    try testing.expectEqualStrings("viewBox", firstSimple(&plain).Attribute.name);

    var flagged = try parse("[class=CasE I]");
    defer flagged.deinit();
    try testing.expect(firstSimple(&flagged).Attribute.case == .insensitive);
    var sensitive = try parse("[type=a s]");
    defer sensitive.deinit();
    try testing.expect(firstSimple(&sensitive).Attribute.case == .sensitive);

    // HTML 4.16.2's list, decided at parse time from the lowercase name.
    var listed = try parse("[TYPE^=hey]");
    defer listed.deinit();
    try testing.expect(firstSimple(&listed).Attribute.html_case_insensitive_value);
    var unlisted = try parse("[title^=hey]");
    defer unlisted.deinit();
    try testing.expect(!firstSimple(&unlisted).Attribute.html_case_insensitive_value);
    try testing.expect(selector.isHtmlCaseInsensitiveValueAttribute("http-equiv"));
    try testing.expect(!selector.isHtmlCaseInsensitiveValueAttribute("id"));
}

test "An+B values" {
    const Case = struct { []const u8, i32, i32 };
    const cases = [_]Case{
        .{ ":nth-child(4n-1)", 4, -1 }, .{ ":nth-child(4n \n- \n1)", 4, -1 },
        .{ ":nth-child(odd)", 2, 1 },   .{ ":nth-child(even)", 2, 0 },
        .{ ":nth-child(-n+3)", -1, 3 }, .{ ":nth-child(+n)", 1, 0 },
        .{ ":nth-child(n- 2)", 1, -2 }, .{ ":nth-child(-n-3)", -1, -3 },
        .{ ":nth-child(7)", 0, 7 },     .{ ":nth-child(2n -1)", 2, -1 },
        .{ ":nth-child(3N+0)", 3, 0 },  .{ ":nth-child(-2n+ 5)", -2, 5 },
    };
    for (cases) |case| {
        var list = try parse(case[0]);
        defer list.deinit();
        const pattern = firstSimple(&list).PseudoClass.kind.NthChild;
        testing.expectEqual(case[1], pattern.a) catch |err| {
            std.debug.print("{s}\n", .{case[0]});
            return err;
        };
        try testing.expectEqual(case[2], pattern.b);
    }
}

test ":has() arguments are relative selectors, descendant when no combinator is written" {
    var list = try parse(":has(span, > a b, + c, ~ d)");
    defer list.deinit();
    const args = firstSimple(&list).PseudoClass.kind.Has.selectors;
    try testing.expectEqual(@as(usize, 4), args.len);
    for (args) |arg| try testing.expect(arg.is_relative);
    try testing.expect(args[0].initial_combinator.? == .Descendant);
    try testing.expect(args[1].initial_combinator.? == .Child);
    try testing.expectEqual(@as(usize, 1), args[1].combinators.len);
    try testing.expect(args[2].initial_combinator.? == .NextSibling);
    try testing.expect(args[3].initial_combinator.? == .SubsequentSibling);
}

test ":lang() keeps each range; :dir() keeps an unknown direction; :host() its compound" {
    var lang = try parse(":lang(en, \"fr-BE\", \\*-CH)");
    defer lang.deinit();
    const ranges = firstSimple(&lang).PseudoClass.kind.Lang;
    try testing.expectEqual(@as(usize, 3), ranges.len);
    try testing.expectEqualStrings("en", ranges[0]);
    try testing.expectEqualStrings("fr-BE", ranges[1]);
    try testing.expectEqualStrings("*-CH", ranges[2]);

    var dir = try parse(":dir(foo)");
    defer dir.deinit();
    try testing.expect(firstSimple(&dir).PseudoClass.kind.Dir == .other);

    var host = try parse(":host(.a)");
    defer host.deinit();
    try testing.expectEqual(@as(usize, 1), firstSimple(&host).PseudoClass.kind.Host.?.selectors.len);
    var bare = try parse(":host");
    defer bare.deinit();
    try testing.expect(firstSimple(&bare).PseudoClass.kind.Host == null);
}

test "forgiving lists drop what is invalid; legacy pseudo-elements are pseudo-elements" {
    var list = try parse(":is(%, .a, ::before, ns|b)");
    defer list.deinit();
    try testing.expectEqual(@as(usize, 1), firstSimple(&list).PseudoClass.kind.Is.selectors.len);

    var legacy = try parse("p:after");
    defer legacy.deinit();
    const simples = legacy.selectors[0].compound.simple_selectors;
    try testing.expectEqualStrings("after", simples[1].PseudoElement.name);
    try testing.expect(legacy.selectors[0].compound.hasPseudoElement());
}

test "::slotted() keeps its compound argument and adds its specificity" {
    var list = try parse("slot::slotted(span.a)");
    defer list.deinit();
    const compound = list.selectors[0].compound;
    try testing.expectEqual(@as(usize, 2), compound.simple_selectors.len);
    const pseudo = compound.simple_selectors[1].PseudoElement;
    try testing.expectEqualStrings("slotted", pseudo.name);
    const argument = pseudo.argument orelse return error.TestExpectedArgument;
    try testing.expectEqual(@as(usize, 1), argument.selectors.len);
    const inner = argument.selectors[0].compound.simple_selectors;
    try testing.expectEqualStrings("span", inner[0].Type.lower_name);
    try testing.expectEqualStrings("a", inner[1].Class.class_name);
    // CSS Scoping 3.2.2: a pseudo-element's (0,0,1) plus the argument's
    // (0,1,1), with the slot's type selector: (0,1,3).
    const spec = list.selectors[0].calculateSpecificity();
    try testing.expectEqual(@as(u32, 0), spec.id);
    try testing.expectEqual(@as(u32, 1), spec.class);
    try testing.expectEqual(@as(u32, 3), spec.element);
}

test "::part() keeps its names, decoded, and pseudo-classes after it" {
    var list = try parse("x-host::part(label \\69 con):hover");
    defer list.deinit();
    const simples = list.selectors[0].compound.simple_selectors;
    const pseudo = simples[1].PseudoElement;
    try testing.expectEqualStrings("part", pseudo.name);
    try testing.expectEqual(@as(usize, 2), pseudo.part_names.len);
    try testing.expectEqualStrings("label", pseudo.part_names[0]);
    try testing.expectEqualStrings("icon", pseudo.part_names[1]);
    try testing.expect(pseudo.argument == null);
    try testing.expect(simples[2] == .PseudoClass);
    // ::part() is a pseudo-element's (0,0,1) with no argument's added.
    const spec = list.selectors[0].calculateSpecificity();
    try testing.expectEqual(@as(u32, 1), spec.class);
    try testing.expectEqual(@as(u32, 2), spec.element);
}

test "a failed parse after ::slotted() or ::part() frees what it kept" {
    // testing.allocator fails the test on a leaked argument or name array.
    const invalid = [_][]const u8{ "::slotted(span)::slotted(b)", "::slotted(span) div", "::part(a)::part(b)", "::part()", "::part(a, b)", "::slotted(a b)" };
    for (invalid) |input| {
        if (parse(input)) |parsed| {
            var list = parsed;
            list.deinit();
            std.debug.print("parsed as valid: {s}\n", .{input});
            return error.TestExpectedInvalid;
        } else |_| {}
    }
}
