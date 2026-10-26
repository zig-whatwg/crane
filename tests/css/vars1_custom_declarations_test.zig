//! Custom property declarations in a declaration block (lane vars1): CSS
//! Variables 1 §2 (the --* family), §2.1 (the value syntax and its var()
//! validity), §4 (case-sensitive names) and §4.1 (serialization), through
//! the CSSOM algorithms of CSSOM 6.6.1. Cases from
//! css/css-variables/variable-definition.html, variable-cssText.html and
//! test_variable_legal_values.html.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const DeclarationBlock = css.declarations.DeclarationBlock;

fn options(allocator: Allocator) css.properties.ParseOptions {
    return .{ .allocator = allocator };
}

fn expectValue(block: *const DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectCssText(block: *const DeclarationBlock, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

fn parsed(text: []const u8) !DeclarationBlock {
    return DeclarationBlock.parse(options(testing.allocator), text);
}

test "a custom property reads back its original text, case-sensitively (variable-definition.html)" {
    var block = try parsed("--var:value; --v: value1  value2 ; ---: x; --Var:value2; --:value; -var4:value3");
    defer block.deinit();
    try expectValue(&block, "--var", "value");
    try expectValue(&block, "--v", "value1  value2");
    try expectValue(&block, "---", "x");
    try expectValue(&block, "--Var", "value2");
    try expectValue(&block, "--VAR", "");
    // `--` is reserved (§2); `-var4` is no custom property.
    try expectValue(&block, "--", "");
    try testing.expectEqual(@as(usize, 5), block.length());
    try testing.expectEqualStrings("--var", block.item(0).?);
    try testing.expectEqualStrings("-var4", block.item(4).?);
}

test "an empty custom property serializes as one space (§4.1, integrator Q2)" {
    var block = try parsed("--a:; --b: ; --c:  ");
    defer block.deinit();
    try expectValue(&block, "--a", " ");
    try expectValue(&block, "--b", " ");
    try expectValue(&block, "--c", " ");
    // CSSOM "serialize a CSS declaration": name, ": ", the value (" ").
    try expectCssText(&block, "--a:  ; --b:  ; --c:  ;");
}

test "a later declaration replaces an earlier one unless the earlier is important" {
    var block = try parsed("--var:value1; --var:value2");
    defer block.deinit();
    try expectValue(&block, "--var", "value2");
    var important = try parsed("--var:value1 !important;--var:value2;");
    defer important.deinit();
    try expectValue(&important, "--var", "value1");
    try testing.expect(important.getPropertyPriority("--var"));
    var overwrite = try parsed("--var:value;--var:;");
    defer overwrite.deinit();
    try expectValue(&overwrite, "--var", " ");
    try testing.expectEqual(@as(usize, 1), overwrite.length());
}

test "CSS-wide keywords are the keywords, not text (variable-definition-keywords)" {
    var block = try parsed("--a: initial; --b: INHERIT; --c: unset; --d: revert; --e: revert-layer; --f: initial initial");
    defer block.deinit();
    try expectValue(&block, "--a", "initial");
    try expectValue(&block, "--b", "inherit");
    try expectValue(&block, "--c", "unset");
    try expectValue(&block, "--d", "revert");
    try expectValue(&block, "--e", "revert-layer");
    try expectValue(&block, "--f", "initial initial");
    try testing.expect(block.getCustom("--a").?.value == .css_wide);
    try testing.expect(block.getCustom("--f").?.value == .text);
}

test "custom declarations preserve arbitrary values and reject malformed substitution functions" {
    var block = try parsed("--a: 25%; --b: foo(bar()); --c: ( ); --d: { }; --e: [ ]; --f: @media {}; --g: if(x > 5) this.width = 10; --h: var(--x, a, b); --i: var(); --j: var(--x)); --k: a !b; --l: unknown(x > 5) this.width = 10");
    defer block.deinit();
    for ([_][]const u8{ "--a", "--b", "--c", "--d", "--e", "--f", "--h", "--l" }) |name| {
        if (block.getCustom(name) == null) {
            std.debug.print("missing {s}\n", .{name});
            return error.TestExpectedValid;
        }
    }
    // CSS Values 5 §8.3 makes if() a substitution function whose argument
    // grammar requires a colon. The Variables 1 §2.1 example predates that
    // grammar; --l keeps its arbitrary unknown-function coverage.
    try testing.expect(block.getCustom("--g") == null);
    try expectValue(&block, "--l", "unknown(x > 5) this.width = 10");
    try testing.expect(block.getCustom("--i") == null);
    try testing.expect(block.getCustom("--k") == null);
    try expectValue(&block, "--h", "var(--x, a, b)");
    try testing.expect(block.getCustom("--h").?.value == .pending);
    try testing.expect(block.getCustom("--a").?.value == .text);
}

test "setProperty, getPropertyPriority and removeProperty of custom properties (CSSOM 6.6.1)" {
    var block = DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    const o = options(testing.allocator);
    try testing.expect(try block.setProperty(o, "--varUnique", "green", ""));
    try testing.expect(!try block.setProperty(o, "--varUnique", "green", ""));
    try testing.expect(try block.setProperty(o, "--varUnique", "  blue  ", "important"));
    try expectValue(&block, "--varUnique", "blue");
    try testing.expect(block.getPropertyPriority("--varUnique"));
    // The setter replaces regardless of importance, in place.
    try testing.expect(try block.setProperty(o, "--a", "1", ""));
    try testing.expect(try block.setProperty(o, "--varUnique", "red", ""));
    try testing.expectEqualStrings("--varUnique", block.item(0).?);
    try testing.expect(!block.getPropertyPriority("--varUnique"));
    // A name with a space still starts with two dashes (all three browsers).
    try testing.expect(try block.setProperty(o, "--varUnique2 ", "green", ""));
    try expectValue(&block, "--varUnique2 ", "green");
    // Invalid values and the reserved name change nothing.
    try testing.expect(!try block.setProperty(o, "--b", "var()", ""));
    try testing.expect(!try block.setProperty(o, "--", "x", ""));
    try testing.expect(!try block.setProperty(o, "--b", "x", "bogus"));
    var old: std.ArrayList(u8) = .empty;
    defer old.deinit(testing.allocator);
    try testing.expect(try block.removeProperty("--varUnique", &old));
    try testing.expectEqualStrings("red", old.items);
    try testing.expect(!try block.removeProperty("--VARUNIQUE", &old));
    // "" removes (setProperty step 3).
    try testing.expect(try block.setProperty(o, "--a", "", ""));
    try expectValue(&block, "--a", "");
    try expectCssText(&block, "--varUnique2 : green;");
}

test "cssText keeps custom declarations in order with their values (variable-cssText.html target1)" {
    var block = try parsed("--var: var1; color: red; --b:  x  /* c */ y !important");
    defer block.deinit();
    try expectCssText(&block, "--var: var1; color: red; --b: x  /* c */ y !important;");
    try block.setCssText(options(testing.allocator), "--z: 1");
    try expectCssText(&block, "--z: 1;");
    try testing.expectEqual(@as(u32, 1), block.custom_count);
}

test "@position-try takes no custom properties; @keyframes takes them without !important" {
    var position_try = try DeclarationBlock.parseInContext(options(testing.allocator), "--a: 1; top: 1px", .position_try);
    defer position_try.deinit();
    try testing.expect(position_try.getCustom("--a") == null);
    var keyframe = try DeclarationBlock.parseInContext(options(testing.allocator), "--a: 1; --b: 2 !important", .keyframe);
    defer keyframe.deinit();
    try testing.expect(keyframe.getCustom("--a") != null);
    try testing.expect(keyframe.getCustom("--b") == null);
}

test "the cascade's views: typed() skips custom declarations, customs() lists them" {
    var block = try parsed("--a: 1; color: red; --b: var(--a)");
    defer block.deinit();
    var typed = block.typed();
    try testing.expectEqual(css.properties.Longhand.color, typed.next().?.longhand);
    try testing.expect(typed.next() == null);
    var customs = block.customs();
    try testing.expectEqualStrings("--a", customs.next().?.name.bytes);
    try testing.expectEqualStrings("--b", customs.next().?.name.bytes);
    try testing.expect(customs.next() == null);
    var none = try parsed("color: red");
    defer none.deinit();
    var empty = none.customs();
    try testing.expect(empty.next() == null);
}

fn buildAll(allocator: Allocator) !void {
    var block = try DeclarationBlock.parse(options(allocator), "--a: 1; --b: var(--a, x); --c: initial; color: red; --a: 2 !important");
    defer block.deinit();
    const o = options(allocator);
    _ = try block.setProperty(o, "--d", "var(--b)", "");
    _ = try block.setProperty(o, "--a", "3", "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try block.getPropertyValue("--b", &out);
    _ = try block.removeProperty("--c", &out);
    try block.setCssText(o, "--x: y; --y: var(--x)");
}

test "allocation failure leaks nothing on any custom declaration path" {
    try testing.checkAllAllocationFailures(testing.allocator, buildAll, .{});
}
