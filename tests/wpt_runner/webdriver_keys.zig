//! WebDriver's keyboard tables (WebDriver 15.6.2 "Keyboard actions"): the
//! normalized key value of a raw key, its code, its key location, which
//! characters are shifted - and the legacy keyCode a key reports "on a 102
//! key US keyboard, following the guidelines in [UI-EVENTS]" (step 6 of
//! "dispatch a keyDown action", left to the implementation).
//!
//! A raw key is one Unicode code point: a character, or one of WebDriver's
//! private-use key codes U+E000..U+E05D ("\uE004" is Tab).
//!
//! std-only, so `zig build test` runs its tests without the engine.
//!
//! Spec: https://w3c.github.io/webdriver/#keyboard-actions

const std = @import("std");

/// "The normalized key value for a raw key key": the table's second column
/// for a WebDriver key code, else the key itself (UTF-8, borrowed from
/// `raw` or static).
pub fn normalizedKey(raw: u21, raw_utf8: []const u8) []const u8 {
    return switch (raw) {
        0xE000 => "Unidentified",
        0xE001 => "Cancel",
        0xE002 => "Help",
        0xE003 => "Backspace",
        0xE004 => "Tab",
        0xE005 => "Clear",
        0xE006 => "Return",
        0xE007 => "Enter",
        0xE008, 0xE050 => "Shift",
        0xE009, 0xE051 => "Control",
        0xE00A, 0xE052 => "Alt",
        0xE00B => "Pause",
        0xE00C => "Escape",
        0xE00D => " ",
        0xE00E, 0xE054 => "PageUp",
        0xE00F, 0xE055 => "PageDown",
        0xE010, 0xE056 => "End",
        0xE011, 0xE057 => "Home",
        0xE012, 0xE058 => "ArrowLeft",
        0xE013, 0xE059 => "ArrowUp",
        0xE014, 0xE05A => "ArrowRight",
        0xE015, 0xE05B => "ArrowDown",
        0xE016, 0xE05C => "Insert",
        0xE017, 0xE05D => "Delete",
        0xE018 => ";",
        0xE019 => "=",
        0xE01A => "0",
        0xE01B => "1",
        0xE01C => "2",
        0xE01D => "3",
        0xE01E => "4",
        0xE01F => "5",
        0xE020 => "6",
        0xE021 => "7",
        0xE022 => "8",
        0xE023 => "9",
        0xE024 => "*",
        0xE025 => "+",
        0xE026 => ",",
        0xE027 => "-",
        0xE028 => ".",
        0xE029 => "/",
        0xE031 => "F1",
        0xE032 => "F2",
        0xE033 => "F3",
        0xE034 => "F4",
        0xE035 => "F5",
        0xE036 => "F6",
        0xE037 => "F7",
        0xE038 => "F8",
        0xE039 => "F9",
        0xE03A => "F10",
        0xE03B => "F11",
        0xE03C => "F12",
        0xE03D, 0xE053 => "Meta",
        0xE040 => "ZenkakuHankaku",
        else => raw_utf8,
    };
}

/// "The code for key": the last column of the code table on the row with
/// `raw` in its first or second column, or null (undefined). The first
/// matching row wins ("<" is both Comma's shifted key and IntlBackslash's).
pub fn code(raw: u21) ?[]const u8 {
    if (raw >= 'a' and raw <= 'z') return letter_codes[raw - 'a'];
    if (raw >= 'A' and raw <= 'Z') return letter_codes[raw - 'A'];
    return switch (raw) {
        '`', '~' => "Backquote",
        '\\', '|' => "Backslash",
        0xE003 => "Backspace",
        '[', '{' => "BracketLeft",
        ']', '}' => "BracketRight",
        ',', '<' => "Comma",
        '0', ')' => "Digit0",
        '1', '!' => "Digit1",
        '2', '@' => "Digit2",
        '3', '#' => "Digit3",
        '4', '$' => "Digit4",
        '5', '%' => "Digit5",
        '6', '^' => "Digit6",
        '7', '&' => "Digit7",
        '8', '*' => "Digit8",
        '9', '(' => "Digit9",
        '=', '+' => "Equal",
        '>' => "IntlBackslash",
        '-', '_' => "Minus",
        '.' => "Period",
        '\'', '"' => "Quote",
        ';', ':' => "Semicolon",
        '/', '?' => "Slash",
        0xE00A => "AltLeft",
        0xE052 => "AltRight",
        0xE009 => "ControlLeft",
        0xE051 => "ControlRight",
        0xE006 => "Enter",
        0xE00B => "Pause",
        0xE03D => "MetaLeft",
        0xE053 => "MetaRight",
        0xE008 => "ShiftLeft",
        0xE050 => "ShiftRight",
        ' ', 0xE00D => "Space",
        0xE004 => "Tab",
        0xE017 => "Delete",
        0xE010 => "End",
        0xE002 => "Help",
        0xE011 => "Home",
        0xE016 => "Insert",
        0xE00F => "PageDown",
        0xE00E => "PageUp",
        0xE015 => "ArrowDown",
        0xE012 => "ArrowLeft",
        0xE014 => "ArrowRight",
        0xE013 => "ArrowUp",
        0xE00C => "Escape",
        0xE031 => "F1",
        0xE032 => "F2",
        0xE033 => "F3",
        0xE034 => "F4",
        0xE035 => "F5",
        0xE036 => "F6",
        0xE037 => "F7",
        0xE038 => "F8",
        0xE039 => "F9",
        0xE03A => "F10",
        0xE03B => "F11",
        0xE03C => "F12",
        0xE019 => "NumpadEqual",
        0xE01A, 0xE05C => "Numpad0",
        0xE01B, 0xE056 => "Numpad1",
        0xE01C, 0xE05B => "Numpad2",
        0xE01D, 0xE055 => "Numpad3",
        0xE01E, 0xE058 => "Numpad4",
        0xE01F => "Numpad5",
        0xE020, 0xE05A => "Numpad6",
        0xE021, 0xE057 => "Numpad7",
        0xE022, 0xE059 => "Numpad8",
        0xE023, 0xE054 => "Numpad9",
        0xE025 => "NumpadAdd",
        0xE026 => "NumpadComma",
        0xE028, 0xE05D => "NumpadDecimal",
        0xE029 => "NumpadDivide",
        0xE007 => "NumpadEnter",
        0xE024 => "NumpadMultiply",
        0xE027 => "NumpadSubtract",
        else => null,
    };
}

const letter_codes = [_][]const u8{
    "KeyA", "KeyB", "KeyC", "KeyD", "KeyE", "KeyF", "KeyG", "KeyH", "KeyI",
    "KeyJ", "KeyK", "KeyL", "KeyM", "KeyN", "KeyO", "KeyP", "KeyQ", "KeyR",
    "KeyS", "KeyT", "KeyU", "KeyV", "KeyW", "KeyX", "KeyY", "KeyZ",
};

/// "A shifted character is one that appears in the second column of the
/// [code] table" - which includes the numpad's navigation keys (U+E054 ..
/// U+E05D are Shift with a numpad digit). Two rows are left out: "." lists
/// "." in both columns, and Space lists U+E00D as its alternate; neither is
/// typed with Shift on a US keyboard, nor by any driver.
pub fn isShifted(raw: u21) bool {
    if (raw >= 'A' and raw <= 'Z') return true;
    return switch (raw) {
        '~', '|', '{', '}', '<', ')', '!', '@', '#', '$', '%', '^', '&', '*', '(', '+', '>', '_', '"', ':', '?' => true,
        0xE054...0xE05D => true,
        else => false,
    };
}

/// "The key location for key": 1 left, 2 right, 3 numpad, else 0.
pub fn location(raw: u21) u32 {
    return switch (raw) {
        0xE007, 0xE008, 0xE009, 0xE00A, 0xE03D => 1,
        0xE050, 0xE051, 0xE052, 0xE053 => 2,
        0xE019...0xE029, 0xE054...0xE05D => 3,
        else => 0,
    };
}

/// Whether `raw` is a modifier key: Shift, Control, Alt or Meta.
pub fn isModifier(raw: u21) bool {
    return switch (raw) {
        0xE008, 0xE009, 0xE00A, 0xE03D, 0xE050, 0xE051, 0xE052, 0xE053 => true,
        else => false,
    };
}

/// A key's legacy keyCode (UI Events Legacy Key Models' "fixed virtual key
/// codes" and US-keyboard virtual key codes), given its normalized key and
/// code; 0 when there is none.
pub fn keyCode(key: []const u8, key_code: ?[]const u8) u32 {
    const named = [_]struct { []const u8, u32 }{
        .{ "Cancel", 3 },    .{ "Backspace", 8 },   .{ "Tab", 9 },        .{ "Clear", 12 },
        .{ "Enter", 13 },    .{ "Return", 13 },     .{ "Shift", 16 },     .{ "Control", 17 },
        .{ "Alt", 18 },      .{ "Pause", 19 },      .{ "Escape", 27 },    .{ "PageUp", 33 },
        .{ "PageDown", 34 }, .{ "End", 35 },        .{ "Home", 36 },      .{ "ArrowLeft", 37 },
        .{ "ArrowUp", 38 },  .{ "ArrowRight", 39 }, .{ "ArrowDown", 40 }, .{ "Insert", 45 },
        .{ "Delete", 46 },   .{ "Help", 47 },       .{ "Meta", 91 },      .{ "ZenkakuHankaku", 244 },
    };
    for (named) |entry| if (std.mem.eql(u8, key, entry[0])) return entry[1];
    if (key.len > 1 and key[0] == 'F') {
        const n = std.fmt.parseInt(u32, key[1..], 10) catch 0;
        if (n >= 1 and n <= 12) return 111 + n;
    }
    const c = key_code orelse return 0;
    if (std.mem.startsWith(u8, c, "Key") and c.len == 4) return c[3];
    if (std.mem.startsWith(u8, c, "Digit") and c.len == 6) return c[5];
    if (std.mem.startsWith(u8, c, "Numpad") and c.len == 7 and std.ascii.isDigit(c[6])) return 96 + @as(u32, c[6] - '0');
    const by_code = [_]struct { []const u8, u32 }{
        .{ "Space", 32 },           .{ "Backquote", 192 },      .{ "Backslash", 220 },    .{ "BracketLeft", 219 },
        .{ "BracketRight", 221 },   .{ "Comma", 188 },          .{ "Equal", 187 },        .{ "IntlBackslash", 226 },
        .{ "Minus", 189 },          .{ "Period", 190 },         .{ "Quote", 222 },        .{ "Semicolon", 186 },
        .{ "Slash", 191 },          .{ "NumpadMultiply", 106 }, .{ "NumpadAdd", 107 },    .{ "NumpadComma", 194 },
        .{ "NumpadSubtract", 109 }, .{ "NumpadDecimal", 110 },  .{ "NumpadDivide", 111 }, .{ "NumpadEqual", 187 },
    };
    for (by_code) |entry| if (std.mem.eql(u8, c, entry[0])) return entry[1];
    return 0;
}

test "normalized key values" {
    try std.testing.expectEqualStrings("Tab", normalizedKey(0xE004, "\u{E004}"));
    try std.testing.expectEqualStrings("Backspace", normalizedKey(0xE003, "\u{E003}"));
    try std.testing.expectEqualStrings("Shift", normalizedKey(0xE050, "\u{E050}"));
    try std.testing.expectEqualStrings(" ", normalizedKey(0xE00D, "\u{E00D}"));
    try std.testing.expectEqualStrings("a", normalizedKey('a', "a"));
    try std.testing.expectEqualStrings("\u{E0FF}", normalizedKey(0xE0FF, "\u{E0FF}"));
}

test "codes, locations and shifted characters" {
    try std.testing.expectEqualStrings("KeyA", code('a').?);
    try std.testing.expectEqualStrings("KeyA", code('A').?);
    try std.testing.expectEqualStrings("Digit1", code('!').?);
    try std.testing.expectEqualStrings("Comma", code('<').?);
    try std.testing.expectEqualStrings("NumpadEnter", code(0xE007).?);
    try std.testing.expectEqualStrings("Enter", code(0xE006).?);
    try std.testing.expectEqualStrings("Space", code(' ').?);
    try std.testing.expect(code(0x00E9) == null);
    try std.testing.expectEqual(@as(u32, 1), location(0xE008));
    try std.testing.expectEqual(@as(u32, 2), location(0xE050));
    try std.testing.expectEqual(@as(u32, 3), location(0xE01A));
    try std.testing.expectEqual(@as(u32, 0), location('a'));
    try std.testing.expect(isShifted('A'));
    try std.testing.expect(isShifted('?'));
    try std.testing.expect(!isShifted('a'));
    try std.testing.expect(!isShifted('.'));
    try std.testing.expect(isModifier(0xE008));
    try std.testing.expect(!isModifier(0xE004));
}

test "US keyboard keyCodes" {
    try std.testing.expectEqual(@as(u32, 65), keyCode("a", "KeyA"));
    try std.testing.expectEqual(@as(u32, 65), keyCode("A", "KeyA"));
    try std.testing.expectEqual(@as(u32, 49), keyCode("!", "Digit1"));
    try std.testing.expectEqual(@as(u32, 32), keyCode(" ", "Space"));
    try std.testing.expectEqual(@as(u32, 13), keyCode("Enter", "NumpadEnter"));
    try std.testing.expectEqual(@as(u32, 9), keyCode("Tab", "Tab"));
    try std.testing.expectEqual(@as(u32, 40), keyCode("ArrowDown", "ArrowDown"));
    try std.testing.expectEqual(@as(u32, 45), keyCode("Insert", "Numpad0"));
    try std.testing.expectEqual(@as(u32, 96), keyCode("0", "Numpad0"));
    try std.testing.expectEqual(@as(u32, 112), keyCode("F1", "F1"));
    try std.testing.expectEqual(@as(u32, 190), keyCode(".", "Period"));
    try std.testing.expectEqual(@as(u32, 0), keyCode("\u{E9}", null));
}

// ============================================================================
// The tables above, pinned against WebDriver's own (specs/w3c/webdriver2.md)
// ============================================================================

/// The code spans of a markdown table row, in order: `x` and `` x ``.
fn codeSpans(line: []const u8, out: [][]const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < line.len and count < out.len) {
        if (line[i] != '`') {
            i += 1;
            continue;
        }
        const double = i + 1 < line.len and line[i + 1] == '`';
        const delimiter: []const u8 = if (double) "``" else "`";
        const start = i + delimiter.len;
        const end = std.mem.indexOfPos(u8, line, start, delimiter) orelse break;
        out[count] = std.mem.trim(u8, line[start..end], " ");
        count += 1;
        i = end + delimiter.len;
    }
    return count;
}

/// A table cell's key: `\uE004`, `"\uE004"`, `"a"`, `"\"` or `"""`, as its
/// code point.
fn cellCodePoint(cell_in: []const u8) ?u21 {
    var cell = cell_in;
    if (cell.len >= 2 and cell[0] == '"' and cell[cell.len - 1] == '"') cell = cell[1 .. cell.len - 1];
    if (cell.len == 6 and cell[0] == '\\' and cell[1] == 'u') return std.fmt.parseInt(u21, cell[2..], 16) catch null;
    const len = std.unicode.utf8ByteSequenceLength(cell[0]) catch return null;
    if (len != cell.len) return null;
    return std.unicode.utf8Decode(cell) catch null;
}

fn unquote(cell: []const u8) []const u8 {
    if (cell.len >= 2 and cell[0] == '"' and cell[cell.len - 1] == '"') return cell[1 .. cell.len - 1];
    return cell;
}

/// The rows of the table whose header line contains `header`: the lines up
/// to the table's closing rule.
fn tableRows(spec: []const u8, header: []const u8) ?[]const u8 {
    const at = std.mem.indexOf(u8, spec, header) orelse return null;
    const body_start = (std.mem.indexOfScalarPos(u8, spec, at, '\n') orelse return null) + 1;
    var lines = std.mem.splitScalar(u8, spec[body_start..], '\n');
    var end = body_start;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " ");
        if (trimmed.len > 0 and trimmed[0] == '-') break;
        end += line.len + 1;
    }
    return spec[body_start..end];
}

fn readSpec(allocator: std.mem.Allocator) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, "specs/w3c/webdriver2.md", allocator, .limited(8 << 20)) catch return error.SkipZigTest;
}

test "normalizedKey matches WebDriver's normalized key value table" {
    const spec = try readSpec(std.testing.allocator);
    defer std.testing.allocator.free(spec);
    const rows = tableRows(spec, "codepoint Normalized key value") orelse return error.TestExpectedTable;
    var lines = std.mem.splitScalar(u8, rows, '\n');
    var checked: usize = 0;
    while (lines.next()) |line| {
        var spans: [4][]const u8 = undefined;
        if (codeSpans(line, &spans) != 2) continue;
        const raw = cellCodePoint(spans[0]) orelse return error.TestUnexpectedCell;
        try std.testing.expectEqualStrings(unquote(spans[1]), normalizedKey(raw, ""));
        checked += 1;
    }
    try std.testing.expect(checked > 60);
}

test "code and isShifted match WebDriver's code table" {
    const spec = try readSpec(std.testing.allocator);
    defer std.testing.allocator.free(spec);
    const rows = tableRows(spec, "Key Alternate Key code") orelse return error.TestExpectedTable;
    var lines = std.mem.splitScalar(u8, rows, '\n');
    var checked: usize = 0;
    while (lines.next()) |line| {
        var spans: [4][]const u8 = undefined;
        const count = codeSpans(line, &spans);
        if (count < 2) continue;
        const expected = unquote(spans[count - 1]);
        const key = cellCodePoint(spans[0]) orelse return error.TestUnexpectedCell;
        // "The first matching row": "<" is Comma's alternate before it is
        // IntlBackslash's key.
        if (key != '<') {
            try std.testing.expectEqualStrings(expected, code(key).?);
            // A first-column key is unshifted.
            try std.testing.expect(!isShifted(key));
        }
        if (count == 3) {
            const alternate = cellCodePoint(spans[1]) orelse return error.TestUnexpectedCell;
            try std.testing.expectEqualStrings(expected, code(alternate).?);
            // The two rows isShifted leaves out, and why, are on its doc comment.
            if (alternate != '.' and alternate != 0xE00D) try std.testing.expect(isShifted(alternate));
        }
        checked += 1;
    }
    try std.testing.expect(checked > 90);
}

test "location matches WebDriver's key location table" {
    const spec = try readSpec(std.testing.allocator);
    defer std.testing.allocator.free(spec);
    const rows = tableRows(spec, "codepoint Description Location") orelse return error.TestExpectedTable;
    var lines = std.mem.splitScalar(u8, rows, '\n');
    var listed: [64]u21 = undefined;
    var count: usize = 0;
    while (lines.next()) |line| {
        var spans: [4][]const u8 = undefined;
        const n = codeSpans(line, &spans);
        if (n < 2) continue;
        const raw = cellCodePoint(spans[0]) orelse return error.TestUnexpectedCell;
        const expected = try std.fmt.parseInt(u32, spans[n - 1], 10);
        try std.testing.expectEqual(expected, location(raw));
        listed[count] = raw;
        count += 1;
    }
    try std.testing.expect(count > 30);
    // Every other key is at location 0.
    var raw: u21 = 0xE000;
    while (raw <= 0xE05D) : (raw += 1) {
        if (std.mem.indexOfScalar(u21, listed[0..count], raw) != null) continue;
        try std.testing.expectEqual(@as(u32, 0), location(raw));
    }
}
