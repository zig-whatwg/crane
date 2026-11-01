//! Fonts 4 §§9.2 and 12.3: descriptor parsing and detached CSSOM ownership.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const a = std.testing.allocator;

fn descriptors(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator,
        \\@font-palette-values --Palette {
        \\  font-family: old; font-family: foo, "serif";
        \\  font-family: serif; base-palette: light; base-palette: 2;
        \\  base-palette: -1; override-colors: 3 #123, 3 #456;
        \\  override-colors: 0 currentcolor; font-weight: 700;
        \\}
    , .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const rule = list.items[0];
    try std.testing.expectEqualStrings("font_palette_values", @tagName(rule.kind()));
    const text = try rule.serialize(allocator);
    defer allocator.free(text);
    for ([_][]const u8{ "@font-palette-values --Palette", "font-family: foo, \"serif\";", "base-palette: 2;", "override-colors: 3 rgb(17, 34, 51), 3 rgb(68, 85, 102);" }) |part|
        try std.testing.expect(std.mem.indexOf(u8, text, part) != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "font-weight") == null);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 0), compiled.rules.items.len);
}

test "palette descriptors keep the last valid declaration and ordered color entries" {
    try descriptors(a);
}

fn emptyAndInvalid(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator,
        \\@font-palette-values {}
        \\@font-palette-values plain {}
        \\@font-palette-values --one --two {}
        \\@font-palette-values --;
        \\@font-palette-values -- {}
        \\@font-palette-values --empty { font-family: ""; }
        \\@font-palette-values --\{ { base-palette: dark; }
    , .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 3), list.items.len);
    const empty = try list.items[0].serialize(allocator);
    defer allocator.free(empty);
    try std.testing.expectEqualStrings("@font-palette-values -- { }", empty);
    const family = try list.items[1].serialize(allocator);
    defer allocator.free(family);
    try std.testing.expect(std.mem.indexOf(u8, family, "font-family: \"\";") != null);
    const escaped = try list.items[2].serialize(allocator);
    defer allocator.free(escaped);
    try std.testing.expect(std.mem.indexOf(u8, escaped, "--\\{") != null);
}

test "empty palette rules survive while invalid names and missing blocks are dropped" {
    try emptyAndInvalid(a);
}

fn absoluteColors(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator,
        \\@font-palette-values --valid {
        \\  override-colors: 0 color-mix(in lch, red, blue);
        \\  override-colors: 0 color-mix(in lch, red, canvas);
        \\}
        \\@font-palette-values --invalid {
        \\  override-colors: 0 light-dark(white, black);
        \\  override-colors: 0 contrast-color(red);
        \\  override-colors: 0 color-mix(in lch, red, color-mix(in lch, currentcolor, black));
        \\  override-colors: 0 rgb(from canvas r g b);
        \\  override-colors: 0 alpha(from light-dark(red, blue) / .5);
        \\  base-palette: sibling-index();
        \\}
    , .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    const valid = try list.items[0].serialize(allocator);
    defer allocator.free(valid);
    try std.testing.expect(std.mem.indexOf(u8, valid, "override-colors: 0 color-mix(in lch, red, blue);") != null);
    const invalid = try list.items[1].serialize(allocator);
    defer allocator.free(invalid);
    try std.testing.expectEqualStrings("@font-palette-values --invalid { }", invalid);
}

test "palette override colors accept only absolute colors including nested mixes" {
    try absoluteColors(a);
}

fn detached(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "@font-palette-values --Held { font-family: Ahem; base-palette: 0; override-colors: 1 #123; }", .{});
    var owns_record = true;
    defer if (owns_record) record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const rule = list.items[0];
    rule.ref();
    defer rule.unref();
    record.unref();
    owns_record = false;
    try std.testing.expect(rule.parent_sheet == null);
    const text = try rule.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "font-family: Ahem;") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "override-colors: 1 rgb(17, 34, 51);") != null);
}

test "a detached palette rule retains its descriptor strings" {
    try detached(a);
}

fn getters() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(a, .{});
    defer ctx.deinit();
    const record = try dom.style.SheetRecord.create(a, "@font-palette-values --\\{ { font-family: foo, bar; base-palette: dark; override-colors: 0 #123; }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const object = try interfaces.CSSFontPaletteValuesRule.initWith(a, &ctx, .{ .css_rule = list.items[0] });
    defer interfaces.CSSFontPaletteValuesRule.deinit(object);
    var name = try interfaces.CSSFontPaletteValuesRule.get_name(object);
    defer name.deinit(a);
    try std.testing.expectEqualStrings("--{", name.asSlice());
    var family = try interfaces.CSSFontPaletteValuesRule.get_fontFamily(object);
    defer family.deinit(a);
    try std.testing.expectEqualStrings("foo, bar", family.asSlice());
    var base = try interfaces.CSSFontPaletteValuesRule.get_basePalette(object);
    defer base.deinit(a);
    try std.testing.expectEqualStrings("dark", base.asSlice());
    var colors = try interfaces.CSSFontPaletteValuesRule.get_overrideColors(object);
    defer colors.deinit(a);
    try std.testing.expectEqualStrings("0 rgb(17, 34, 51)", colors.asSlice());
    const sheet = try interfaces.CSSStyleSheet.initWith(a, &ctx, .{ .sheet_record = record });
    defer interfaces.CSSStyleSheet.deinit(sheet);
    const text = try list.items[0].serialize(a);
    defer a.free(text);
    try interfaces.CSSStyleSheet.call_deleteRule(sheet, 0);
    try std.testing.expectEqual(@as(usize, 0), list.items.len);
    try std.testing.expect(dom.style.hooks.cssRuleOf(object).?.parent_sheet == null);
    var detached_colors = try interfaces.CSSFontPaletteValuesRule.get_overrideColors(object);
    defer detached_colors.deinit(a);
    try std.testing.expectEqualStrings("0 rgb(17, 34, 51)", detached_colors.asSlice());
    try std.testing.expectEqual(@as(u32, 0), try interfaces.CSSStyleSheet.call_insertRule(sheet, runtime.DOMString.initInterned(text), .{ .was_passed = true, .value = 0 }));
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const reparsed = try list.items[0].serialize(a);
    defer a.free(reparsed);
    try std.testing.expectEqualStrings(text, reparsed);
}

test "CSSFontPaletteValuesRule getters survive delete and serialized reinsertion" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            getters() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "palette rule parsing compilation and detachment unwind all allocation failures" {
    try std.testing.checkAllAllocationFailures(a, descriptors, .{});
    try std.testing.checkAllAllocationFailures(a, emptyAndInvalid, .{});
    try std.testing.checkAllAllocationFailures(a, absoluteColors, .{});
    try std.testing.checkAllAllocationFailures(a, detached, .{});
}

// Fonts4 descriptor priority and integer math preserve specified CSSOM.
fn paletteImportantPrecedence(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator,
        \\@font-palette-values --Important {
        \\  font-family: Before !important;
        \\  font-family: KeptFamily;
        \\  font-family: After !important;
        \\  base-palette: 7 !important;
        \\  base-palette: 2;
        \\  base-palette: 3 !important;
        \\  override-colors: 0 #fff !important;
        \\  override-colors: 1 #123;
        \\  override-colors: 2 #456 !IMPORTANT;
        \\}
        \\@font-palette-values --OnlyImportant {
        \\  font-family: Ignored !important;
        \\  base-palette: 4 !important;
        \\  override-colors: 5 red !important;
        \\}
    , .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    const retained = try list.items[0].serialize(allocator);
    defer allocator.free(retained);
    try std.testing.expectEqualStrings("@font-palette-values --Important { font-family: KeptFamily; base-palette: 2; override-colors: 1 rgb(17, 34, 51); }", retained);
    const empty = try list.items[1].serialize(allocator);
    defer allocator.free(empty);
    try std.testing.expectEqualStrings("@font-palette-values --OnlyImportant { }", empty);
}

test "palette important descriptors are ignored before and after valid declarations" {
    try paletteImportantPrecedence(a);
}

fn paletteIntegerMath(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator,
        \\@font-palette-values --Math {
        \\  font-family: Ahem;
        \\  base-palette: calc(1 + 2);
        \\  override-colors: calc(6 / 2) #123, calc(2 * 2) #456;
        \\}
    , .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 0), compiled.rules.items.len);
    const text = try list.items[0].serialize(allocator);
    defer allocator.free(text);
    // Q8 retains specified math through the existing owner; no root context
    // is invented to compute, round or range-clamp these descriptor values.
    try std.testing.expectEqualStrings("@font-palette-values --Math { font-family: Ahem; base-palette: calc(3); override-colors: calc(3) rgb(17, 34, 51), calc(4) rgb(68, 85, 102); }", text);
}

test "palette descriptor integer math keeps the existing specified serialization" {
    try paletteIntegerMath(a);
}

test "palette important and integer math descriptor paths unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, paletteImportantPrecedence, .{});
    try std.testing.checkAllAllocationFailures(a, paletteIntegerMath, .{});
}
