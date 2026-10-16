//! URLPattern's components are ECMAScript regexps - RegExpCreate with "v" or
//! "vi", matched with RegExpBuiltinExec (urlpattern.md, "compile a component"
//! step 6; "match" steps 14-21) - so custom regexp groups have the full
//! regexp semantics: alternatives with backtracking, modifiers, UnicodeSets
//! set operations, ignore case, and validation at construction. Codex row
//! 26's semantic controls, red on the PCRE-named mock's handwritten matcher;
//! they run here, where there is an engine.
//!
//! And the binding end to end, in a page that poisoned its RegExp: the
//! regexps are made and run with the agent's own intrinsics, never the
//! page's (Blink's ScriptRegexp context), so nothing the page did is called
//! and its legacy RegExp statics keep its own last match.

const std = @import("std");
const up = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");

test "URLPattern regex semantics: alternatives, modifiers, sets and ignoreCase" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const cases = [_]struct { pattern: []const u8, input: []const u8, ignore_case: bool = false, expected: bool = true }{
        .{ .pattern = "/:part(foo|bar)", .input = "/bar" },
        .{ .pattern = "/{foo}?", .input = "/" },
        .{ .pattern = "/:part+", .input = "/a/b" },
        .{ .pattern = "/:part(\\d+)", .input = "/123" },
        .{ .pattern = "/([[a-z]--a])", .input = "/z" },
        .{ .pattern = "/([\\d&&[0-1]])", .input = "/1" },
        .{ .pattern = "/hello", .input = "/HELLO", .ignore_case = true },
        .{ .pattern = "/:part(foo|bar)", .input = "/other", .expected = false },
        .{ .pattern = "/:part(\\d+)", .input = "/abc", .expected = false },
        .{ .pattern = "/([[a-z]--a])", .input = "/a", .expected = false },
        .{ .pattern = "/([\\d&&[0-1]])", .input = "/2", .expected = false },
        .{ .pattern = "/hello", .input = "/HELLO", .expected = false },
    };
    var failed: usize = 0;
    for (cases, 0..) |case, i| {
        var pattern = try up.URLPattern.create(std.testing.allocator, realm, .{ .init = .{ .pathname = case.pattern } }, .{ .ignore_case = case.ignore_case });
        defer pattern.deinit(std.testing.allocator);
        if (try up.testMatchInput(std.testing.allocator, realm, &pattern, .{ .init = .{ .pathname = case.input } }, null) != case.expected) {
            std.debug.print("UPREGEX\t{d}\t{s}\n", .{ i, case.pattern });
            failed += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failed);
}

test "an invalid custom regexp fails construction; a valid one under v but not u passes" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const A = std.testing.allocator;
    for ([_][]const u8{ "/([(])", "/(\\a)", "/(a{2,1})", "/((?<x>a)\\k<y>)" }) |pathname| {
        if (up.URLPattern.create(A, realm, .{ .init = .{ .pathname = pathname } }, .{})) |made| {
            var pattern = made;
            pattern.deinit(A);
            std.debug.print("accepted: {s}\n", .{pathname});
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expectEqual(error.InvalidPattern, err);
    }
    var pattern = try up.URLPattern.create(A, realm, .{ .init = .{ .pathname = "/([\\q{ab|c}])" } }, .{});
    defer pattern.deinit(A);
    try std.testing.expect(try up.testMatch(A, realm, &pattern, "https://example.com/ab", null));
}

test "an undefined group is there, undefined; an empty one is \"\"" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const A = std.testing.allocator;
    var pattern = try up.URLPattern.create(A, realm, .{ .init = .{ .pathname = "/:a?/:b(x*)" } }, .{});
    defer pattern.deinit(A);
    var result = (try up.execInput(A, realm, &pattern, .{ .init = .{ .pathname = "/" } }, null)) orelse return error.TestExpectedMatch;
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.pathname.groups.len);
    try std.testing.expect(result.pathname.get("a").?.value == null);
    try std.testing.expectEqualStrings("", result.pathname.get("b").?.value.?);
}

test "the binding, in a page that poisoned RegExp: nothing it did is called" {
    const page = try harness.Page.open();
    defer page.close();
    try page.run("/(seen)/.exec('was seen');");
    try page.run(
        \\globalThis.calls = 0;
        \\RegExp.prototype.exec = function () { calls++; return null; };
        \\RegExp.prototype.test = function () { calls++; return false; };
        \\RegExp.prototype[Symbol.match] = function () { calls++; return null; };
        \\Object.defineProperty(RegExp.prototype, 'lastIndex', { set(v) { calls++; }, get() { calls++; return 3; } });
        \\const NativeRegExp = RegExp;
        \\globalThis.RegExp = function () { calls++; throw new Error('poisoned'); };
        \\globalThis.RegExp.prototype = NativeRegExp.prototype;
        \\globalThis.statics = () => NativeRegExp.lastMatch === 'seen' && NativeRegExp.$1 === 'seen';
    );
    try std.testing.expect(try page.holds(
        \\(() => {
        \\  const p = new URLPattern({ pathname: '/books/:id(\\d+)/:rest?' });
        \\  const r = p.exec('https://example.com/books/123');
        \\  return r !== null && r.pathname.groups.id === '123' &&
        \\    'rest' in r.pathname.groups && r.pathname.groups.rest === undefined &&
        \\    Object.keys(r.pathname.groups).join() === 'id,rest' &&
        \\    p.test('https://example.com/books/123/x') && !p.test('https://example.com/books/abc') &&
        \\    p.exec('https://example.com/books/abc') === null;
        \\})()
    ));
    try std.testing.expect(try page.holds(
        \\(() => { try { new URLPattern({ pathname: '/([(])' }); return false; } catch (e) { return e instanceof TypeError; } })()
    ));
    try std.testing.expect(try page.holds("new URLPattern({ pathname: '/foo' }, { ignoreCase: true }).test({ pathname: '/FOO' })"));
    try std.testing.expect(try page.holds("calls === 0"));
    try std.testing.expect(try page.holds("statics()"));
}
