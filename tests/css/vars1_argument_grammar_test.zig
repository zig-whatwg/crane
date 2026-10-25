//! Values 5 Appendix A argument grammars at parse time (lane vars1): the
//! value of a declaration with an arbitrary substitution function is valid
//! exactly when every such function matches its argument grammar.
//!
//! Cases: css/css-variables/var-parsing.html (the newer var() grammar,
//! integrator Q1), css/css-env/env-parsing.html and syntax.tentative.html
//! (env() strict at parse time), the reftests' top-level `!` fallbacks
//! (variable-reference-08/-10), and random-item()'s grammar unchanged.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const substitution = css.substitution;

fn valid(text: []const u8) !bool {
    return substitution.validate(testing.allocator, text);
}

fn expectValid(text: []const u8) !void {
    if (!try valid(text)) {
        std.debug.print("expected valid: {s}\n", .{text});
        return error.TestExpectedValid;
    }
}

fn expectInvalid(text: []const u8) !void {
    if (try valid(text)) {
        std.debug.print("expected invalid: {s}\n", .{text});
        return error.TestExpectedInvalid;
    }
}

test "var(): the newer argument grammar (var-parsing.html)" {
    for ([_][]const u8{
        "var(--x)",                "var(--x,)",               "var(--x, )",
        // The name is a <declaration-value>, substituted and only then
        // parsed as a <custom-property-name>.
        "var(--x ())",             "var(--x () )",            "var(--x() )",
        "var(--x (),)",            "var(--x(),)",
        // A {}-wrapped free-form name argument.
                    "var({--x})",
        "var({--x}, 10px)",        "var({--x, --y})",
        // Names from another substitution, and nesting.
                "var(var(--n))",
        "var(var(var(--n)), 1px)", "calc(var(--a) + 1px)",    "var(--a, var(--b, var(--c)))",
        // The fallback is non-strict: commas and blocks are allowed.
        "var(--x, red, blue)",     "var(--x, (!))",           "var(--x, {a, b})",
        "var(--x, [a] {b} (c))",
        // Syntax 3 closes blocks at EOF (missing-closing-nested-fallback).
          "var(--x, var(--y, 10px)", "VAR(--x)",
    }) |text| try expectValid(text);
    for ([_][]const u8{
        // A free-form production not starting with "{" matches no top-level
        // {} block; one starting with "{" is just that block.
        "var(--x {--y})",    "var({--x} --y)",  "var(--x {--y}, 10px)",
        // An empty name, wrapped or not.
        "var()",             "var({})",         "var({}, 10px)",
        "var(, 10px)",       "var( )",
        // A fallback starting with "{" must be exactly that block.
                 "var(--x, {a} b)",
        // <declaration-value> excludes a top-level "!" (variable-reference-08).
        "var(--x,!)",        "var(--x, a !)",   "var(--x !)",
        // An invalid function nested anywhere invalidates the value.
        "calc(var() + 1px)", "var(--x, var())",
        // Bad tokens and unmatched closers.
        "var(--x, \"a\n)",
        "var(--x))",         "var(--x, ])",
    }) |text| try expectInvalid(text);
}

test "env(): strict name grammar at parse time (env-parsing.html, syntax.tentative.html)" {
    for ([_][]const u8{
        "env(safe-area-inset-top)", "env(safe-area-inset-top,)", "env(safe-area-inset-top, )",
        "env(test)",                "ENV(test)",                 "env(test, 10px)",
        "env(test, env(another))",  "env(-test)",                "env(--test)",
        "env( test)",               "env(test )",                "env( test )",
        "env(test /**/, blue)",     "env(test, {})",             "env(test 0)",
        "env(test 0, green)",       "env(test 0,)",              "env(test 0 1 2 3 4, green)",
        "env(test +0)",             "env(test -0)",
    }) |text| try expectValid(text);
    for ([_][]const u8{
        "env(safe-area-inset-top ())",  "env(safe-area-inset-top () )", "env(safe-area-inset-top() )",
        "env(safe-area-inset-top (),)", "env(safe-area-inset-top(),)",  "env(10px)",
        "env(env(test))",               "env(test, {)",                 "env()",
        "env(, 1px)",                   "env(test -1)",                 "env(test 1.5)",
        "env(test 1e2)",                "env(initial)",                 "env(DEFAULT)",
        "env({test})",                  "env(test,!)",
    }) |text| try expectInvalid(text);
}

test "the whole value is a <declaration-value>" {
    try expectValid("1px var(--x) 2px");
    try expectInvalid("var(--x) !");
    try expectInvalid("var(--x); a");
    try expectInvalid("var(--x) \"bad\n");
}

test "random-item() keeps row 118's grammar" {
    try expectValid("random-item(--k, a, b)");
    try expectValid("random-item(--k, {a, b}, c)");
    try expectValid("random-item(--k, var(--x), c)");
    try expectInvalid("random-item(--k)");
    try expectInvalid("random-item(, a)");
    try expectInvalid("random-item(--k, (a), b)");
    try expectInvalid("random-item(--k, a !, b)");
}

test "a spread defers the argument grammar to substitution" {
    // Values 5 Appendix A: `...var()` is substituted before the split.
    try expectValid("random-item(...var(--items))");
    try expectValid("var(...var(--args))");
    // Not a spread: whitespace or comments between the periods.
    try expectInvalid("random-item(. . .var(--items))");
}

test "functions are recognized at any depth and only by function tokens" {
    try testing.expect(substitution.mentionsFunction("calc(1px + var(--x))"));
    try testing.expect(substitution.mentionsFunction("Env(test)"));
    try testing.expect(substitution.mentionsFunction("random-item(--k, a, b)"));
    try testing.expect(!substitution.mentionsFunction("var"));
    try testing.expect(!substitution.mentionsFunction("\"var(--x)\""));
    try testing.expect(!substitution.mentionsFunction("--var(1px)"));
    try testing.expectEqual(substitution.Id.@"var", substitution.functionId("v\\61 r").?);
}

test "nesting and size limits make a value invalid, not truncated" {
    var deep: std.ArrayList(u8) = .empty;
    defer deep.deinit(testing.allocator);
    for (0..substitution.max_depth + 1) |_| try deep.appendSlice(testing.allocator, "var(--x, ");
    try expectInvalid(deep.items);
}

fn validateAll(allocator: std.mem.Allocator) !void {
    for ([_][]const u8{ "var({--x}, 10px)", "env(test 0 1, var(--y, a b))", "random-item(--k, {a, b}, var(--z))", "var(--x, var())" }) |text| {
        _ = try substitution.validate(allocator, text);
    }
}

test "allocation failure is reported, never taken for invalid syntax" {
    try testing.checkAllAllocationFailures(testing.allocator, validateAll, .{});
}
