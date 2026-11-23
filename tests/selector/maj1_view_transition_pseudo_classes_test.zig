//! Lane maj1: which pseudo-classes may follow a view transition
//! pseudo-element. View Transitions 1 §3.1: in the pseudo-element tree,
//! ":only-child matches" a descendant of the pseudo-element root that has no
//! siblings, so `::view-transition-new(x):only-child` is valid; nothing else
//! may follow them but the logical combinations (Selectors 4 3.6.3), and
//! ::view-transition, the root, takes no :only-child. Chrome, Firefox and
//! Safari agree (wpt.fyi 2358bd4835,
//! css/css-view-transitions/parsing/pseudo-elements-{valid,valid-with-classes,invalid}.html).
//! An :only-child there tests the pseudo-element, not its originating
//! element: the parser keeps it as its own kind.

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

fn expectValidity(expected: bool, input: []const u8) !void {
    var list = try parse(input);
    const valid = list != null;
    if (list) |*l| l.deinit();
    if (valid != expected) std.debug.print("expected {s}: \"{s}\"\n", .{ if (expected) "valid" else "invalid", input });
    try testing.expectEqual(expected, valid);
}

const named = [_][]const u8{ "::view-transition-group", "::view-transition-image-pair", "::view-transition-old", "::view-transition-new" };

test "only :only-child and the logical combinations follow a named view transition pseudo-element" {
    var buffer: [160]u8 = undefined;
    for (named) |name| {
        for ([_][]const u8{ "*", "root", "foo.bar.baz", "*.class" }) |argument| {
            for ([_][]const u8{ "", ":root", ".a", "div " }) |prefix| {
                try expectValidity(true, try std.fmt.bufPrint(&buffer, "{s}{s}({s}):only-child", .{ prefix, name, argument }));
            }
            try expectValidity(true, try std.fmt.bufPrint(&buffer, "{s}({s}):not(:only-child)", .{ name, argument }));
            for ([_][]const u8{ ":hover", ":active", ":first-child", ":last-child", ":empty", ":visited", ":enabled", ":focus", ".a", " div" }) |after| {
                try expectValidity(false, try std.fmt.bufPrint(&buffer, "{s}({s}){s}", .{ name, argument, after }));
            }
        }
    }
}

test "nothing but the logical combinations follows ::view-transition" {
    for ([_][]const u8{ "::view-transition:only-child", "::view-transition:hover", "::view-transition:active", "::view-transition:first-child", "::view-transition.a" }) |input| {
        try expectValidity(false, input);
    }
    try expectValidity(true, "::view-transition");
    try expectValidity(true, ":root::view-transition");
}

test "the user action pseudo-classes still follow other pseudo-elements" {
    try expectValidity(true, "::before:hover");
    try expectValidity(true, "::part(x):focus");
    try expectValidity(false, "::before:only-child");
}

fn kindsAfterPseudoElement(list: *const selector.SelectorList, out: []selector.PseudoClassKind) usize {
    var n: usize = 0;
    var seen = false;
    for (list.selectors[0].compound.simple_selectors) |*simple| switch (simple.*) {
        .PseudoElement => seen = true,
        .PseudoClass => |pseudo| if (seen) {
            out[n] = pseudo.kind;
            n += 1;
        },
        else => {},
    };
    return n;
}

test ":only-child after a named view transition pseudo-element tests the pseudo-element" {
    var list = (try parse("::view-transition-new(x):only-child")).?;
    defer list.deinit();
    var kinds: [2]selector.PseudoClassKind = undefined;
    try testing.expectEqual(@as(usize, 1), kindsAfterPseudoElement(&list, &kinds));
    try testing.expect(kinds[0] == .PseudoElementOnlyChild);
    // One pseudo-class's specificity.
    const specificity = list.selectors[0].calculateSpecificity();
    try testing.expectEqual(@as(u32, 1), specificity.class);

    var negated = (try parse("::view-transition-group(*):not(:only-child)")).?;
    defer negated.deinit();
    try testing.expectEqual(@as(usize, 1), kindsAfterPseudoElement(&negated, &kinds));
    const inner = kinds[0].Not.selectors[0].compound.simple_selectors;
    try testing.expect(inner[inner.len - 1].PseudoClass.kind == .PseudoElementOnlyChild);

    // An element's own :only-child stays the structural one.
    var plain = (try parse("div:only-child")).?;
    defer plain.deinit();
    try testing.expect(plain.selectors[0].compound.simple_selectors[1].PseudoClass.kind == .OnlyChild);
}
