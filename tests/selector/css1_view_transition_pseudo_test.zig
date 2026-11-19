//! Lane css1: the named view transition pseudo-elements' argument (View
//! Transitions 1 §5.2.1 <pt-name-selector>, 2 §10.4
//! <pt-name-and-class-selector>) - which arguments parse, what the parser
//! keeps for matching, and the specificity. WPT
//! css/css-view-transitions/parsing/pseudo-elements-{valid,invalid}{,-with-classes}.html.

const std = @import("std");
const selector = @import("selector");
const testing = std.testing;

fn parse(input: []const u8) !?selector.SelectorList {
    var tokenizer = selector.Tokenizer.init(testing.allocator, input);
    var parser = selector.Parser.init(testing.allocator, &tokenizer) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
    defer parser.deinit();
    return parser.parse() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
}

fn expectValidity(expected: bool, inputs: []const []const u8) !void {
    var wrong: usize = 0;
    for (inputs) |input| {
        var list = try parse(input);
        const valid = list != null;
        if (list) |*l| l.deinit();
        if (valid != expected) {
            std.debug.print("expected {s}: \"{s}\"\n", .{ if (expected) "valid" else "invalid", input });
            wrong += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

const named = [_][]const u8{ "::view-transition-group", "::view-transition-image-pair", "::view-transition-old", "::view-transition-new" };

test "named view transition pseudo-elements take <pt-name-and-class-selector>" {
    var buffer: [128]u8 = undefined;
    for (named) |name| {
        for ([_][]const u8{ "*", "\\*", "root", "dashed-ident", "*.class", "\\*.class", "*.class.class", "dashed-ident.someclass", "dash-id.dash-id", "foo.bar.baz", ".cls", ".a.b", " foo ", "foo.bar " }) |argument| {
            try expectValidity(true, &.{try std.fmt.bufPrint(&buffer, "{s}({s})", .{ name, argument })});
        }
        for ([_][]const u8{ "*.*", "*. cls", "*.cls. c", "*.cls>cls", "*.cls.foo.*", "", "foo bar", "foo .bar", "1", "initial", "foo.default", ".", "foo.", "**" }) |argument| {
            try expectValidity(false, &.{try std.fmt.bufPrint(&buffer, "{s}({s})", .{ name, argument })});
        }
    }
}

fn pseudoOf(list: *const selector.SelectorList) *const selector.PseudoElementSelector {
    for (list.selectors[0].compound.simple_selectors) |*simple| switch (simple.*) {
        .PseudoElement => |*p| return p,
        else => {},
    };
    unreachable;
}

test "the parser keeps the name and the classes; * and \\* stay apart" {
    {
        var list = (try parse("::view-transition-group(*)")).?;
        defer list.deinit();
        try testing.expect(pseudoOf(&list).name_argument == null);
        try testing.expectEqual(@as(usize, 0), pseudoOf(&list).class_arguments.len);
    }
    {
        var list = (try parse("::view-transition-group(\\*)")).?;
        defer list.deinit();
        try testing.expectEqualStrings("*", pseudoOf(&list).name_argument.?);
    }
    {
        var list = (try parse("::view-transition-old(Root.a.b)")).?;
        defer list.deinit();
        const pseudo = pseudoOf(&list);
        try testing.expectEqualStrings("Root", pseudo.name_argument.?);
        try testing.expectEqual(@as(usize, 2), pseudo.class_arguments.len);
        try testing.expectEqualStrings("a", pseudo.class_arguments[0]);
        try testing.expectEqualStrings("b", pseudo.class_arguments[1]);
    }
    {
        var list = (try parse("::highlight(foo)")).?;
        defer list.deinit();
        try testing.expectEqualStrings("foo", pseudoOf(&list).name_argument.?);
    }
}

test "specificity: a name or a class is a type selector's, * alone zero" {
    const cases = [_]struct { input: []const u8, element: u32 }{
        .{ .input = "::view-transition-group(*)", .element = 0 },
        .{ .input = "::view-transition-group(foo)", .element = 1 },
        .{ .input = "::view-transition-group(*.cls)", .element = 1 },
        .{ .input = "::view-transition-new(.cls)", .element = 1 },
        .{ .input = "::view-transition", .element = 1 },
        .{ .input = "::before", .element = 1 },
    };
    for (cases) |case| {
        var list = (try parse(case.input)).?;
        defer list.deinit();
        const spec = list.selectors[0].calculateSpecificity();
        try testing.expectEqual(@as(u32, 0), spec.id);
        try testing.expectEqual(@as(u32, 0), spec.class);
        try testing.expectEqual(case.element, spec.element);
    }
}
