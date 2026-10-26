//! Typed syntax matching and computation, independent of the cascade.
const std = @import("std");
const css = @import("css");
const syntax = css.syntax_definitions;
const testing = std.testing;

fn expectSpecified(allocator: std.mem.Allocator, grammar: []const u8, text: []const u8, expected: []const u8) !void {
    var definition = try syntax.parse(allocator, grammar);
    defer definition.deinit();
    var value = (try definition.parseValue(.{ .allocator = allocator }, text)) orelse return error.TestExpectedValue;
    defer value.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try value.serialize(&out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "pr1 numeric syntax matching uses exact types and ordered alternatives" {
    for ([_][3][]const u8{
        .{ "<length>", "0", "0px" },
        .{ "<length>", "2px", "2px" },
        .{ "<length>", "1in", "1in" },
        .{ "<number>", "2.5e2", "250" },
        .{ "<percentage>", "-10%", "-10%" },
        .{ "<integer>", "-109", "-109" },
        .{ "<angle>", "1turn", "1turn" },
        .{ "<time>", "500ms", "500ms" },
        .{ "<resolution>", "96dpi", "96dpi" },
        .{ "<length>+ | <length>#", "2px, 3px", "2px, 3px" },
        .{ "<length># | <length>+", "2px 3px", "2px 3px" },
    }) |case| try expectSpecified(testing.allocator, case[0], case[1], case[2]);
}

test "pr1 identifiers strings colors URLs and universal values retain type" {
    for ([_][3][]const u8{
        .{ "red | <color>", "red", "red" },
        .{ "<custom-ident>", "banan\\61", "banana" },
        .{ "<custom-ident>#", "foo, --bar", "foo, --bar" },
        .{ "<string>", "'foo bar'", "\"foo bar\"" },
        .{ "<string>+", "'foo' \"bar\"", "\"foo\" \"bar\"" },
        .{ "<string>#", "'foo', 'bar'", "\"foo\", \"bar\"" },
        .{ "<url>", "url(example.png)", "url(\"example.png\")" },
        .{ "*", "foo /* retained */  bar", "foo /* retained */  bar" },
        .{ "*", "", "" },
    }) |case| try expectSpecified(testing.allocator, case[0], case[1], case[2]);
}

test "pr1 typed mismatches reject trailing components and wrong separators" {
    for ([_][2][]const u8{
        .{ "<length>", "1" },              .{ "<length>", "10%" },                     .{ "<percentage>", "0" },
        .{ "<integer>", "1.0" },           .{ "<integer>", "1e0" },                    .{ "<angle>", "0" },
        .{ "<time>", "2px" },              .{ "<resolution>", "-1dpi" },               .{ "<resolution>", "1" },
        .{ "<length>", "calc(1px + 2%)" }, .{ "<length>+", "1px,2px" },                .{ "<length>#", "1px 2px" },
        .{ "<length>#", "1px," },          .{ "<length>+", "" },                       .{ "<integer>+ | <percentage>+", "1 2%" },
        .{ "<length>", "1px !important" }, .{ "<custom-ident>", "inherit" },           .{ "<custom-ident>", "default" },
        .{ "Foo | bar", "foo" },           .{ "<string>", "foo" },                     .{ "<string>", "'foo' bar" },
        .{ "<url>", "none" },              .{ "<url>", "linear-gradient(red, blue)" }, .{ "<image>", "none" },
        .{ "<image>", "banana.png" },      .{ "*", ")" },                              .{ "*", "foo;bar" },
        .{ "*", "foo!" },
    }) |case| {
        var definition = try syntax.parse(testing.allocator, case[0]);
        defer definition.deinit();
        var value = try definition.parseValue(.{ .allocator = testing.allocator }, case[1]);
        defer if (value) |*v| v.deinit();
        try testing.expect(value == null);
    }
}

test "pr1 complete Transforms 1 and 2 function grammars" {
    for ([_][2][]const u8{
        .{ "matrix(1, 0, 0, 1, 10, 20)", "matrix(1, 0, 0, 1, 10, 20)" },
        .{ "matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)" },
        .{ "translate(1px)", "translate(1px)" },
        .{ "translate(1px, 2%)", "translate(1px, 2%)" },
        .{ "translateX(2px)", "translateX(2px)" },
        .{ "translateY(2px)", "translateY(2px)" },
        .{ "translateZ(2px)", "translateZ(2px)" },
        .{ "translate3d(1px,2%,3px)", "translate3d(1px, 2%, 3px)" },
        .{ "scale(2)", "scale(2)" },
        .{ "scale(2,3)", "scale(2, 3)" },
        .{ "scaleX(50%)", "scaleX(0.5)" },
        .{ "scaleY(2)", "scaleY(2)" },
        .{ "scaleZ(3)", "scaleZ(3)" },
        .{ "scale3d(50%,100%,150%)", "scale3d(0.5, 1, 1.5)" },
        .{ "rotate(0)", "rotate(0deg)" },
        .{ "rotateX(1deg)", "rotateX(1deg)" },
        .{ "rotateY(2deg)", "rotateY(2deg)" },
        .{ "rotateZ(3deg)", "rotateZ(3deg)" },
        .{ "rotate3d(0,1,0,90deg)", "rotate3d(0, 1, 0, 90deg)" },
        .{ "skew(0)", "skew(0deg)" },
        .{ "skew(1deg,2deg)", "skew(1deg, 2deg)" },
        .{ "skewX(1deg)", "skewX(1deg)" },
        .{ "skewY(2deg)", "skewY(2deg)" },
        .{ "perspective(0)", "perspective(0px)" },
        .{ "perspective(none)", "perspective(none)" },
        .{ "RoTaTe(3deg)", "rotate(3deg)" },
    }) |case| try expectSpecified(testing.allocator, "<transform-function>", case[0], case[1]);
    try expectSpecified(testing.allocator, "<transform-list>", "translateX(2px) rotate(90deg)", "translateX(2px) rotate(90deg)");
    try expectSpecified(testing.allocator, "<transform-function>#", "scale(2), rotate(90deg)", "scale(2), rotate(90deg)");
}

test "pr1 transform arity units separators and function names reject invalid input" {
    for ([_][]const u8{
        "none",                   "scale()",                   "scale(1 2)",        "scale(1,)",            "scale(1,2,3)",          "rotate(2)",
        "translateZ(2%)",         "translate3d(1px, 2px, 3%)", "rotate3d(1, 2, 3)", "rotate3d(1, 2, 3, 4)", "matrix(1, 2, 3)",       "matrix(1px,0,0,1,0,0)",
        "perspective(-1px)",      "perspective(10%)",          "skew(1deg 2deg)",   "unknown(1)",           "scale(1) rotate(2deg)", "rotateX(1deg, 2deg)",
        "translate(1px) garbage",
    }) |text| {
        var definition = try syntax.parse(testing.allocator, "<transform-function>");
        defer definition.deinit();
        var value = try definition.parseValue(.{ .allocator = testing.allocator }, text);
        defer if (value) |*v| v.deinit();
        try testing.expect(value == null);
    }
}

fn expectComputed(allocator: std.mem.Allocator, grammar: []const u8, input: []const u8, expected: []const u8) !void {
    var definition = try syntax.parse(allocator, grammar);
    defer definition.deinit();
    var specified = (try definition.parseValue(.{ .allocator = allocator }, input)) orelse return error.TestExpectedValue;
    defer specified.deinit();
    var computed = try specified.compute(allocator, .{ .math = .{ .font_size = 10, .root_font_size = 16 } });
    defer computed.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try computed.serialize(&out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "pr1 computed values canonicalize units and keep percentages unresolved" {
    for ([_][3][]const u8{
        .{ "<length>", "1in", "96px" },                                             .{ "<length>", "10em", "100px" },
        .{ "<angle>", "1turn", "360deg" },                                          .{ "<time>", "500ms", "0.5s" },
        .{ "<resolution>", "96dpi", "1dppx" },                                      .{ "<percentage>", "25%", "25%" },
        .{ "<number>", "calc(1 / 2)", "0.5" },                                      .{ "<integer>", "calc(3.5)", "4" },
        .{ "<length>+", "1in 2em", "96px 20px" },                                   .{ "<transform-list>", "translateX(10em) scale(2) rotate(1turn)", "translateX(100px) scale(2) rotate(360deg)" },
        .{ "<transform-function>", "translate(10%, 2em)", "translate(10%, 20px)" },
    }) |case| try expectComputed(testing.allocator, case[0], case[1], case[2]);
}

test "pr1 transform serialization keeps specified arguments and normalizes computed defaults" {
    // Browser majority, integrator-probes-1025h: specified and computed differ.
    for ([_][3][]const u8{
        .{ "translate(2px, 0px)", "translate(2px, 0px)", "translate(2px)" },
        .{ "translate(2px, 0%)", "translate(2px, 0%)", "translate(2px, 0%)" },
        .{ "scale(2, 2)", "scale(2, 2)", "scale(2)" },
        .{ "skew(1deg, 0deg)", "skew(1deg, 0deg)", "skew(1deg)" },
        .{ "rotate(1turn)", "rotate(1turn)", "rotate(360deg)" },
        .{ "perspective(none)", "perspective(none)", "perspective(none)" },
        .{ "scale(calc(50% + 25%))", "scale(calc(75%))", "scale(0.75)" },
        .{ "scaleX(2)", "scaleX(2)", "scaleX(2)" },
        .{ "skewY(1turn)", "skewY(1turn)", "skewY(360deg)" },
    }) |case| {
        try expectSpecified(testing.allocator, "<transform-function>", case[0], case[1]);
        try expectComputed(testing.allocator, "<transform-function>", case[0], case[2]);
    }
}

fn matchingOom(allocator: std.mem.Allocator) !void {
    try expectSpecified(allocator, "<length># | <length>+", "1px 2px", "1px 2px");
    try expectSpecified(allocator, "<string>#", "'hello', 'world'", "\"hello\", \"world\"");
    try expectComputed(allocator, "<transform-list>", "translateX(2em) rotate(calc(1turn / 2))", "translateX(20px) rotate(180deg)");
}

test "pr1 typed values and transform functions unwind every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, matchingOom, .{});
}

test "pr1 computational independence follows the browser ruling for typed values" {
    const cases = [_]struct { grammar: []const u8, text: []const u8, independent: bool }{
        .{ .grammar = "<length>", .text = "1px", .independent = true },
        .{ .grammar = "<length>", .text = "1em", .independent = false },
        .{ .grammar = "<length>", .text = "1rem", .independent = false },
        .{ .grammar = "<length>", .text = "0em", .independent = false },
        .{ .grammar = "<length>", .text = "1rcap", .independent = false },
        .{ .grammar = "<length>", .text = "1cqw", .independent = false },
        .{ .grammar = "<length>", .text = "1vi", .independent = true },
        .{ .grammar = "<percentage>", .text = "25%", .independent = true },
        .{ .grammar = "<number>", .text = "calc(1em / 1em)", .independent = false },
        .{ .grammar = "<number>", .text = "sign(1em - 1px)", .independent = false },
        .{ .grammar = "<number>", .text = "sibling-index()", .independent = false },
        .{ .grammar = "<number>", .text = "random(fixed 0.5, 0, 1)", .independent = false },
        .{ .grammar = "<number>", .text = "calc(1 + random(fixed 0.5, 0, 1))", .independent = false },
        .{ .grammar = "<color>", .text = "currentcolor", .independent = true },
        .{ .grammar = "<color>", .text = "light-dark(red, blue)", .independent = true },
        .{ .grammar = "<image>", .text = "linear-gradient(red 1em, blue)", .independent = true },
        .{ .grammar = "<transform-function>", .text = "translateX(1em)", .independent = false },
        .{ .grammar = "<transform-function>", .text = "translateX(10%)", .independent = true },
        .{ .grammar = "<length>+", .text = "1px 2em", .independent = false },
        .{ .grammar = "*", .text = "1em", .independent = true },
        .{ .grammar = "*", .text = "var(--x)", .independent = false },
        .{ .grammar = "*", .text = "env(safe-area-inset-top)", .independent = false },
        .{ .grammar = "*", .text = "f(attr(data-x))", .independent = false },
        .{ .grammar = "*", .text = "'var(--x)'", .independent = true },
        .{ .grammar = "*", .text = "/* env(x) */ 1px", .independent = true },
    };
    for (cases) |case| {
        var definition = try syntax.parse(testing.allocator, case.grammar);
        defer definition.deinit();
        var value = (try definition.parseValue(.{ .allocator = testing.allocator }, case.text)) orelse return error.TestExpectedValue;
        defer value.deinit();
        const actual = value.isComputationallyIndependent(case.text);
        if (case.independent != actual) std.debug.print("independence mismatch: {s} / {s}\n", .{ case.grammar, case.text });
        try testing.expectEqual(case.independent, actual);
    }
}

const Resolver = struct {
    calls: usize = 0,
    oom: bool = false,
    fn resolve(context: *const anyopaque, allocator: std.mem.Allocator, raw: []const u8) ?[]u8 {
        const self: *Resolver = @ptrCast(@alignCast(@constCast(context)));
        self.calls += 1;
        return std.mem.concat(allocator, u8, &.{ "https://source.test/css/", raw }) catch {
            self.oom = true;
            return null;
        };
    }
};

fn resourceOwnership(allocator: std.mem.Allocator) !void {
    var resolver = Resolver{};
    const source = try css.style_values.ResourceSource.create(allocator, .{
        .base_url = "https://source.test/css/main.css",
        .referrer_policy = "no-referrer",
    });
    defer source.unref();
    for ([_][3][]const u8{
        .{ "<url>", "url(a.png)", "url(\"https://source.test/css/a.png\")" },
        .{ "<image>", "image-set(url(a.png) 1x, 'b.png' 2x)", "image-set(url(\"https://source.test/css/a.png\") 1dppx, url(\"https://source.test/css/b.png\") 2dppx)" },
    }) |case| {
        var definition = try syntax.parse(allocator, case[0]);
        defer definition.deinit();
        var value = (try definition.parseValue(.{
            .allocator = allocator,
            .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve },
            .resource_source = source,
        }, case[1])) orelse return error.TestExpectedValue;
        var specified_owned = true;
        defer if (specified_owned) value.deinit();
        if (resolver.oom) return error.OutOfMemory;
        const calls = resolver.calls;
        var computed = try value.compute(allocator, .{});
        defer computed.deinit();
        value.deinit();
        specified_owned = false;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try computed.serialize(&out, allocator);
        try testing.expectEqualStrings(case[2], out.items);
        try testing.expectEqual(calls, resolver.calls);
        const resource = switch (computed.data.single) {
            .image, .url => |r| r.value,
            else => return error.TestUnexpectedResult,
        };
        for (resource.resourceUrls()) |url| {
            try testing.expect(url.source == source);
            try testing.expectEqualStrings("no-referrer", url.source.?.referrer_policy);
        }
    }
}

test "pr1 computed URL and image values keep frozen source after specified teardown" {
    try resourceOwnership(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, resourceOwnership, .{});
}

test "pr1 images compute their typed components with the shared context" {
    try expectComputed(testing.allocator, "<image>", "linear-gradient(red 2em, blue 3em)", "linear-gradient(rgb(255, 0, 0) 20px, rgb(0, 0, 255) 30px)");
    try expectComputed(testing.allocator, "<image>", "radial-gradient(at 20% 2em, red, blue)", "radial-gradient(at 20% 20px, rgb(255, 0, 0), rgb(0, 0, 255))");
}
