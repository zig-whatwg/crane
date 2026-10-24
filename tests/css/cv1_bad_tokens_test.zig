//! CSS Syntax 3 §4.3.5/6, §5.5.6 step 9 and §7.2.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "tokenization keeps bad string and bad URL distinct from empty valid tokens" {
    var bad_url = css.Tokenizer.init("url(should be quoted.ttf)");
    try testing.expectEqual(css.TokenType.bad_url, bad_url.next().token_type);
    var bad_string = css.Tokenizer.init("\"broken\n");
    try testing.expectEqual(css.TokenType.bad_string, bad_string.next().token_type);
    var empty_url = css.Tokenizer.init("url()");
    try testing.expectEqual(css.TokenType.url, empty_url.next().token_type);
    var empty_string = css.Tokenizer.init("\"\"");
    try testing.expectEqual(css.TokenType.string, empty_string.next().token_type);
}

fn hasToken(text: []const u8, kind: css.TokenType) bool {
    var tokenizer = css.Tokenizer.init(text);
    while (true) {
        const token = tokenizer.next();
        if (token.token_type == kind) return true;
        if (token.token_type == .eof) return false;
    }
}

test "declaration serialization preserves malformed resource and string tokens" {
    const declarations = try css.rules.parseDeclarationList(testing.allocator, "background-image: url(a b); --bad: image-set(url(c d) 1x); content: \"bad\n; --string: f(\"broken\n); color: red;");
    defer css.rules.freeDeclarationList(testing.allocator, declarations);
    try testing.expectEqual(@as(usize, 5), declarations.len);
    try testing.expect(hasToken(declarations[0].value, .bad_url));
    try testing.expect(hasToken(declarations[1].value, .bad_url));
    try testing.expect(hasToken(declarations[2].value, .bad_string));
    try testing.expect(hasToken(declarations[3].value, .bad_string));
    try testing.expectEqualStrings("red", declarations[4].value);
}

test "ordinary and custom properties reject bad tokens including nested image functions" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "background-image: url(a b); --bad: image-set(url(c d) 1x); content: \"bad\n; --string: f(\"broken\n); background: image-set(url(e f) 1x); color: red;");
    defer block.deinit();
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expectEqualStrings("color", block.item(0).?);
}

test "font descriptors retain invalid components so their forgiving grammar can recover" {
    var sheet = try css.rules.parseStyleSheetContents(testing.allocator, "@font-face { font-family: Demo; src: url(a b), url(foo.ttf); } div { background-image: url(\"\"); }");
    defer sheet.deinit();
    try testing.expectEqual(@as(usize, 2), sheet.items.len);
    try testing.expectEqual(@as(usize, 2), sheet.items[0].declarations.len);
    const src = sheet.items[0].declarations[1];
    try testing.expectEqualStrings("src", src.name);
    try testing.expect(hasToken(src.value, .bad_url));
    // Fonts 4 section 4.3.1 discards only the malformed first component.
    try testing.expect(std.mem.endsWith(u8, src.value, "url(\"foo.ttf\")"));
    const empty_url = sheet.items[1].declarations[0];
    try testing.expectEqualStrings("background-image", empty_url.name);
    try testing.expectEqualStrings("url(\"\")", empty_url.value);
    var block = try css.declarations.DeclarationBlock.fromDeclarations(.{ .allocator = testing.allocator }, sheet.items[1].declarations);
    defer block.deinit();
    try testing.expectEqual(@as(usize, 1), block.length());
}
