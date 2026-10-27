//! CSS.supports() and @supports with arbitrary substitution functions (lane
//! vars1): a declaration with var()/env() whose functions match their
//! argument grammars is supported for every property (Values 5 "Resolving
//! in Properties"); a custom property's var() must be valid too (CSS
//! Variables 1 §2.1). Cases from css/css-variables/variable-supports-*.
const std = @import("std");
const css = @import("css");

const testing = std.testing;

fn decl(property: []const u8, value: []const u8) bool {
    return css.supports.supportsDeclaration(testing.allocator, property, value);
}

fn condition(text: []const u8) bool {
    return css.supports.supportsCondition(testing.allocator, text, null, null);
}

test "a valid var() or env() value is supported for any property" {
    try testing.expect(decl("color", "var(--a)"));
    try testing.expect(decl("width", "calc(var(--a) + 1px)"));
    try testing.expect(decl("margin", "var(--a) var(--b)"));
    try testing.expect(decl("background-color", "env(test, blue)"));
    try testing.expect(decl("color", "var(--a,)"));
    try testing.expect(!decl("color", "var()"));
    try testing.expect(!decl("color", "var(--a,!)"));
    try testing.expect(!decl("color", "env(10px)"));
    try testing.expect(!decl("color", "var(--a) !important"));
    try testing.expect(!decl("not-a-property", "var(--a)"));
}

test "a custom property's var() must match its argument grammar" {
    try testing.expect(decl("--a", "var(--b, a)"));
    try testing.expect(decl("--a", "var(--b,(!))"));
    try testing.expect(!decl("--a", "var(--b,!)"));
    try testing.expect(!decl("--a", "a var() b"));
    try testing.expect(decl("--a", "env(x 0)"));
}

test "@supports conditions" {
    try testing.expect(condition("(color: var(--a))"));
    try testing.expect(condition("(color: var(--a)) and (not (color: var(--a,!)))"));
    try testing.expect(condition("(--a: var(--b,/**/a))"));
    try testing.expect(!condition("(color: var())"));
}
