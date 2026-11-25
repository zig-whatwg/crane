//! IntersectionObserver's root and scroll margins: "parse a margin" and the
//! `rootMargin` / `scrollMargin` attributes' serialization.
//!
//! Spec: https://w3c.github.io/IntersectionObserver/#parse-a-margin
//! (specs/w3c/IntersectionObserver.md, 2.2).
//!
//! What the browsers do where they and the text part, probed in Chrome 157,
//! Firefox 159 and Safari 27 (tmp/probes/bind1-nullmember/report-g3.txt,
//! 2026-11-24), decided question by question (golden rule 2):
//!
//! - Absolute lengths other than px ("10cm", "10pt"): the spec, Chrome and
//!   Safari accept them; Firefox throws. Accepted (and
//!   intersection-observer/root-margin-scroll-margin-units.html expects it).
//! - A pixel length that is not negative serializes as whole pixels: Chrome
//!   and Safari both answer "10px" for "10.5px" and "377px" for "10cm" (that
//!   WPT file's expectation); Firefox keeps the fraction, as the spec's "the
//!   numeric value followed by px" reads. Two of three: whole pixels.
//! - A NEGATIVE pixel fraction keeps its fraction, as the spec says: for
//!   "-10.5px" the three all differ - Chrome "-11px" (floor), Safari "-10px"
//!   (truncation), Firefox "-10.5px" - no rounding has a majority, so the
//!   rule (mechanism by mechanism) falls back on the spec's "equivalent
//!   pixel length" and "the numeric value followed by px" (confirmed by the
//!   integrator, 2026-11-24). This is Firefox's answer.
//! - A percentage keeps its fraction: Chrome and Firefox serialize "2.7%" as
//!   it is; Safari truncates.
//! - A unitless zero ("0") is a failure, as the spec says (a <number> token
//!   is neither a dimension nor a percentage): Chrome and Firefox throw;
//!   Safari accepts it.

const std = @import("std");
const css = @import("css");

/// One side's offset: a pixel length (a whole number when it is not
/// negative - the module comment), or a percentage.
pub const Margin = struct {
    value: f64 = 0,
    percent: bool = false,
};

/// The four sides, in the order CSS margins take: top, right, bottom, left.
pub const Margins = [4]Margin;

/// "0px 0px 0px 0px": the value when no margin was passed.
pub const zero: Margins = @splat(.{});

/// A CSS absolute length unit's size in pixels (CSS Values 4, 6.2); null
/// for any other unit.
fn absoluteScale(unit: []const u8) ?f64 {
    const scales = [_]struct { []const u8, f64 }{
        .{ "px", 1 },
        .{ "cm", 96.0 / 2.54 },
        .{ "mm", 96.0 / 25.4 },
        .{ "q", 96.0 / 101.6 },
        .{ "in", 96 },
        .{ "pt", 96.0 / 72.0 },
        .{ "pc", 16 },
    };
    for (scales) |entry| if (css.tokenizer.nameEql(unit, entry[0])) return entry[1];
    return null;
}

/// "Parse a margin (root or scroll) from an input string marginString,
/// returning either a list of 4 pixel lengths or percentages, or failure"
/// (null).
pub fn parse(margin_string: []const u8) ?Margins {
    // 1. "Parse a list of component values marginString, storing the result
    //    as tokens."
    // 2. "Remove all whitespace tokens from tokens."
    var tokens: [4]Margin = undefined;
    var count: usize = 0;
    var tokenizer = css.tokenizer.Tokenizer.init(margin_string);
    while (true) {
        const token = tokenizer.next();
        const parsed: Margin = switch (token.token_type) {
            .eof => break,
            .whitespace => continue,
            // 5. "If token is an absolute length dimension token, replace it
            //    with an equivalent pixel length."
            .dimension => blk: {
                const scale = absoluteScale(token.unit orelse return null) orelse return null;
                const number = token.numeric_value orelse return null;
                const pixels = number * scale;
                // Golden rule 2, mechanism by mechanism (probed 2026-11-24).
                // Whole pixels: Chrome 157 and Safari 27 ("10.5px" is
                // "10px" in both; Firefox 159 "10.5px"). How a negative
                // fraction is made whole has no majority - Chrome floors
                // ("-10.5px" is "-11px"), Safari truncates ("-10px"),
                // Firefox does neither ("-10.5px") - so the spec decides
                // that case: the "equivalent pixel length", unrounded.
                break :blk .{ .value = if (pixels >= 0) @floor(pixels) else pixels };
            },
            //    "If token is a <percentage> token, replace it with an
            //    equivalent percentage."
            .percentage => .{ .value = token.numeric_value orelse return null, .percent = true },
            //    "Otherwise, return failure." A function or a block (a
            //    component value that is no token) fails here by its first
            //    token.
            else => return null,
        };
        // 3. "If the length of tokens is greater than 4, return failure."
        if (count == tokens.len) return null;
        tokens[count] = parsed;
        count += 1;
    }
    // 4. "If there are zero elements in tokens, set tokens to ["0px"]."
    if (count == 0) {
        tokens[0] = .{};
        count = 1;
    }
    // 6. "If there is one element in tokens, append three duplicates of that
    //    element to tokens. Otherwise, if there are two elements are tokens,
    //    append a duplicate of each element to tokens. Otherwise, if there
    //    are three elements in tokens, append a duplicate of the second
    //    element to tokens."
    switch (count) {
        1 => {
            tokens[1] = tokens[0];
            tokens[2] = tokens[0];
            tokens[3] = tokens[0];
        },
        2 => {
            tokens[2] = tokens[0];
            tokens[3] = tokens[1];
        },
        3 => tokens[3] = tokens[1],
        else => {},
    }
    // 7. "Return tokens."
    return tokens;
}

/// The rootMargin / scrollMargin getter: "the result of serializing the
/// elements of [[rootMargin]] space-separated, where pixel lengths serialize
/// as the numeric value followed by "px", and percentages serialize as the
/// numeric value followed by "%"". OWNED.
///
/// The numeric value is the one `parse` kept (golden rule 2, mechanism by
/// mechanism): whole pixels for a length that is not negative, the fraction
/// for a negative one ("-10.5px": Chrome "-11px", Safari "-10px", Firefox
/// "-10.5px" - no majority, the spec's value) and for a percentage.
pub fn serialize(allocator: std.mem.Allocator, margins: Margins) ![]u8 {
    var values: [4]f64 = undefined;
    var units: [4][]const u8 = undefined;
    for (margins, &values, &units) |margin, *value, *unit| {
        // -0 is 0: "-0px" serializes as "0px".
        value.* = if (margin.value == 0) 0 else margin.value;
        unit.* = if (margin.percent) "%" else "px";
    }
    return std.fmt.allocPrint(allocator, "{d}{s} {d}{s} {d}{s} {d}{s}", .{
        values[0], units[0], values[1], units[1], values[2], units[2], values[3], units[3],
    });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn expectSerialized(input: []const u8, expected: []const u8) !void {
    const margins = parse(input) orelse {
        std.debug.print("parse a margin failed for \"{s}\"\n", .{input});
        return error.TestUnexpectedResult;
    };
    const text = try serialize(testing.allocator, margins);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}

test "parse a margin: one to four values fill the four sides as CSS margins do" {
    try expectSerialized("10px", "10px 10px 10px 10px");
    try expectSerialized("10% 20px", "10% 20px 10% 20px");
    try expectSerialized("1px 2px 3px", "1px 2px 3px 2px");
    try expectSerialized("1px 2px 3px 4px", "1px 2px 3px 4px");
    try expectSerialized("1px\t2px\n3px", "1px 2px 3px 2px");
}

test "parse a margin: no value at all is 0px" {
    try expectSerialized("", "0px 0px 0px 0px");
    try expectSerialized(" ", "0px 0px 0px 0px");
    try expectSerialized("0px", "0px 0px 0px 0px");
}

test "parse a margin: every absolute length is its whole pixels" {
    // intersection-observer/root-margin-scroll-margin-units.html.
    try expectSerialized("10cm", "377px 377px 377px 377px");
    try expectSerialized("10mm", "37px 37px 37px 37px");
    try expectSerialized("10q", "9px 9px 9px 9px");
    try expectSerialized("10Q", "9px 9px 9px 9px");
    try expectSerialized("10in", "960px 960px 960px 960px");
    try expectSerialized("10pt", "13px 13px 13px 13px");
    try expectSerialized("10pc", "160px 160px 160px 160px");
    try expectSerialized("5PX", "5px 5px 5px 5px");
    try expectSerialized("1e1px", "10px 10px 10px 10px");
    try expectSerialized("+5px", "5px 5px 5px 5px");
    try expectSerialized("1000000px", "1000000px 1000000px 1000000px 1000000px");
}

test "parse a margin: a pixel fraction is whole pixels unless negative; a percentage keeps its fraction" {
    try expectSerialized("10.5px", "10px 10px 10px 10px");
    try expectSerialized(".5px", "0px 0px 0px 0px");
    try expectSerialized("-5px", "-5px -5px -5px -5px");
    // All three browsers differ here (-11px, -10px, -10.5px): the spec.
    try expectSerialized("-10.5px", "-10.5px -10.5px -10.5px -10.5px");
    try expectSerialized("-0.5px", "-0.5px -0.5px -0.5px -0.5px");
    try expectSerialized("1.5px 2.7%", "1px 2.7% 1px 2.7%");
    try expectSerialized("10.6%", "10.6% 10.6% 10.6% 10.6%");
    try expectSerialized("1e3%", "1000% 1000% 1000% 1000%");
}

test "parse a margin: anything but an absolute length or a percentage is failure" {
    // intersection-observer/observer-exceptions.html, and the probe.
    for ([_][]const u8{ "1", "0", "2em", "1rem", "1vh", "auto", "calc(1px + 2px)", "1px !important", "1px 1px 1px 1px 1px", "1px,2px", "1px/2px", "5 px", "null", "junk" }) |input| {
        if (parse(input) != null) {
            std.debug.print("parse a margin accepted \"{s}\"\n", .{input});
            return error.TestUnexpectedResult;
        }
    }
}
