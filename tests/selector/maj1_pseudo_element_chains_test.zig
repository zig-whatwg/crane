//! Lane maj1: what may follow ::slotted(), ::picker() and the highlight
//! pseudo-elements, and what a logical combination after a pseudo-element
//! may hold. ::slotted() takes the tree-abiding pseudo-elements and the
//! element-backed ones, not ::first-line, ::first-letter or a highlight
//! pseudo-element, and no pseudo-class but a logical combination; the
//! highlight pseudo-elements take no user action pseudo-class; ::picker()
//! takes only `select`, and ::before, ::after, ::marker, ::placeholder or
//! ::picker() after it. A logical combination after a pseudo-element holds
//! only pseudo-classes that may follow it - forgivingly in :is() and
//! :where(), so CSS.supports(selector()) rejects them. Chrome, Firefox and
//! Safari agree (wpt.fyi 2358bd4835: css/css-shadow/slotted-parsing.html,
//! css/css-forms/parsing/picker-select-pseudo-element.html,
//! css/css-pseudo/parsing/highlight-pseudos.html,
//! css/selectors/parsing/parse-part.html).
const std = @import("std");
const selector = @import("selector");
const testing = std.testing;

fn valid(input: []const u8) bool {
    var list = selector.parse(testing.allocator, input) catch return false;
    list.deinit();
    return true;
}

fn supported(input: []const u8) bool {
    return selector.isSupported(testing.allocator, input, .{}) catch false;
}

fn expect(expected: bool, input: []const u8) !void {
    const got = valid(input);
    if (got != expected) std.debug.print("expected {s}: \"{s}\"\n", .{ if (expected) "valid" else "invalid", input });
    try testing.expectEqual(expected, got);
}

test "::slotted() takes element-backed and tree-abiding pseudo-elements, no pseudo-class but :is() and :where()" {
    for ([_][]const u8{ "::slotted(*)", "::slotted(*)::before", "::slotted(*)::after", "::slotted(*)::placeholder", "::slotted(*)::marker", "::slotted(*)::file-selector-button", "::slotted(*)::details-content", "::slotted(select)::picker(select)", "::slotted(*)::picker-icon" }) |s| try expect(true, s);
    for ([_][]const u8{ "::slotted(*)::first-line", "::slotted(*)::first-letter", "::slotted(*)::selection", "::slotted(*):hover", "::slotted(*):read-only", "::slotted(*)::slotted(*)" }) |s| try expect(false, s);
    // Forgiving: valid, the invalid items dropped - but not supported.
    for ([_][]const u8{ "::slotted(*):is(:hover)", "::slotted(*):is(#id)", "::slotted(*):where(:hover)", "::slotted(*):where(#id)" }) |s| {
        try expect(true, s);
        try testing.expect(!supported(s));
    }
}

test "::part() takes ::first-line, ::first-letter and the highlight pseudo-elements after it" {
    // Only ::slotted() refuses them (css/selectors/parsing/parse-part.html,
    // css/css-pseudo/parsing/highlight-pseudos.html,
    // css/css-highlight-api/highlight-pseudo-parsing.html: valid in all three).
    for ([_][]const u8{ "::part(foo)::first-line", "::part(foo)::first-letter", "::part(my-part)::selection", "::part(my-part)::target-text", "::part(my-part)::spelling-error", "::part(my-part)::grammar-error", "::part(my-part)::highlight(foo)" }) |s| try expect(true, s);
    try expect(false, "::part(foo)::part(bar)");
    try expect(false, "::part(foo)::slotted(*)");
}

test "the highlight pseudo-elements take no user action pseudo-class" {
    for ([_][]const u8{ "::selection:hover", "::target-text:hover", "::spelling-error:hover", "::grammar-error:hover" }) |s| try expect(false, s);
    try expect(true, "::selection");
}

test "::picker() takes select, and ::before, ::after, ::marker, ::placeholder or ::picker() after it" {
    for ([_][]const u8{ "::picker(select)", "::picker(SELECT)", "::picker(select)::before", "::picker(select)::after", "::picker(select)::marker", "::picker(select)::placeholder", "::picker(select)::picker(select)", "::slotted(*)::picker(select)", "::part(foo)::picker(select)" }) |s| try expect(true, s);
    for ([_][]const u8{ "::picker(foo)", "::picker()", "::before::picker(select)", "::slotted(*)::picker(select)::slotted(*)" }) |s| try expect(false, s);
}

test "a logical combination after ::part() holds only what may follow ::part()" {
    try expect(true, "::part(foo):is(:focus)");
    try testing.expect(supported("::part(foo):is(:focus)"));
    // Forgiving: a type selector or a structural pseudo-class is dropped.
    try expect(true, "::part(foo):is(ul)");
    try testing.expect(!supported("::part(foo):is(ul)"));
    try expect(false, "::part(mypart):not(:first-child)");
    try expect(false, "::part(foo):has(li)");
}

test "CSSOM serializes ::picker()'s argument lowercase" {
    const a = testing.allocator;
    var result = try selector.parseCssomOwned(a, try a.dupe(u8, "::picker(SELECT)"), .{});
    defer a.free(result.text);
    defer result.selectors.deinit();
    try testing.expectEqualStrings("::picker(select)", result.text);
}
