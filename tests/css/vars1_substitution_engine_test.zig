//! The Values 5 Appendix A substitution engine at computed-value time (lane
//! vars1), driven through a test Host: var() (name substitution, lazy
//! fallbacks), env() (the host's lookup, indices, fallback), token
//! boundaries, comments kept as written, the over-long limit, and the taint
//! provenance of §8.7.2 from a synthetic tainted value.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const substitution = css.substitution;
const Computed = substitution.Computed;

const Variable = struct { name: []const u8, value: Computed };

const TestHost = struct {
    variables: []const Variable = &.{},
    /// Every name custom_value was asked for, in order.
    asked: std.ArrayList([]const u8) = .empty,
    allocator: Allocator,

    fn deinit(self: *TestHost) void {
        for (self.asked.items) |name| self.allocator.free(name);
        self.asked.deinit(self.allocator);
    }

    fn customValue(context: *anyopaque, name: []const u8) substitution.Error!?Computed {
        const self: *TestHost = @ptrCast(@alignCast(context));
        const copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(copy);
        try self.asked.append(self.allocator, copy);
        for (self.variables) |v| if (std.mem.eql(u8, v.name, name)) return v.value;
        return null;
    }

    fn host(self: *TestHost, environment: ?substitution.Environment) substitution.Host {
        return .{ .context = self, .custom_value = customValue, .environment = environment };
    }

    fn wasAsked(self: *const TestHost, name: []const u8) bool {
        for (self.asked.items) |n| if (std.mem.eql(u8, n, name)) return true;
        return false;
    }
};

const test_environment: substitution.Environment = .{ .context = &environment_marker, .lookup = environmentLookup };
var environment_marker: u8 = 0;

fn environmentLookup(_: *const anyopaque, allocator: Allocator, name: []const u8, indices: []const u32) Allocator.Error!?[]u8 {
    if (std.mem.eql(u8, name, "test-inset") and indices.len == 0) return try allocator.dupe(u8, "3px");
    if (std.mem.eql(u8, name, "test-grid") and indices.len == 2 and indices[0] < 2 and indices[1] < 2)
        return try std.fmt.allocPrint(allocator, "{d}px", .{indices[0] * 10 + indices[1]});
    return null;
}

/// The substituted text of `text`, or null for the guaranteed-invalid value.
fn substituted(allocator: Allocator, host: substitution.Host, text: []const u8) !?[]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nodes = try substitution.parse(arena.allocator(), text);
    const output = substitution.substituteAndRender(arena.allocator(), nodes, host, "width", null) catch |err| switch (err) {
        error.Invalid => return null,
        else => |e| return e,
    };
    return try allocator.dupe(u8, output.text);
}

fn expectSubstitution(host: substitution.Host, text: []const u8, expected: ?[]const u8) !void {
    const got = try substituted(testing.allocator, host, text);
    defer if (got) |g| testing.allocator.free(g);
    if (expected) |e| {
        if (got == null) {
            std.debug.print("{s}: expected \"{s}\", got the guaranteed-invalid value\n", .{ text, e });
            return error.TestExpectedEqual;
        }
        try testing.expectEqualStrings(e, got.?);
    } else if (got) |g| {
        std.debug.print("{s}: expected the guaranteed-invalid value, got \"{s}\"\n", .{ text, g });
        return error.TestExpectedEqual;
    }
}

const variables = [_]Variable{
    .{ .name = "--a", .value = .{ .text = "10px" } },
    .{ .name = "--b", .value = .{ .text = "red, blue" } },
    .{ .name = "--name", .value = .{ .text = "--a" } },
    .{ .name = "--indirect", .value = .{ .text = "--name" } },
    .{ .name = "--spaced", .value = .{ .text = "  --a  " } },
    .{ .name = "--empty", .value = .{ .text = "" } },
    .{ .name = "--gap", .value = .{ .text = "20" } },
    .{ .name = "--one", .value = .{ .text = "1" } },
    .{ .name = "--not-name", .value = .{ .text = "not-a-custom-prop" } },
    .{ .name = "--two-tokens", .value = .{ .text = "--a --a" } },
    .{ .name = "--dimension", .value = .{ .text = "10px" } },
    .{ .name = "--string", .value = .{ .text = "\"--a\"" } },
    .{ .name = "--dashes", .value = .{ .text = "--" } },
    .{ .name = "--commented", .value = .{ .text = "/* baz */" } },
};

test "var(): the computed value, the fallback only when invalid (css-variables-1 §3)" {
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    const host = t.host(null);
    try expectSubstitution(host, "var(--a)", "10px");
    try expectSubstitution(host, "calc(var(--a) + 1px)", "calc(10px + 1px)");
    try expectSubstitution(host, "var(--missing)", null);
    try expectSubstitution(host, "var(--missing, 5px)", "5px");
    try expectSubstitution(host, "var(--missing, red, blue)", "red, blue");
    try expectSubstitution(host, "var(--missing, {a, b})", "a, b");
    // An empty fallback is present (two arguments), not omitted.
    try expectSubstitution(host, "[var(--missing,)]", "[]");
    try expectSubstitution(host, "[var(--missing)]", null);
    // The empty value is not the guaranteed-invalid value.
    try expectSubstitution(host, "[var(--empty)]", "[]");
    try expectSubstitution(host, "[var(--empty, x)]", "[]");
    try expectSubstitution(host, "var(--missing, var(--a))", "10px");
    try expectSubstitution(host, "var(--missing, var(--also-missing))", null);
    // A guaranteed-invalid anywhere makes the whole value invalid.
    try expectSubstitution(host, "1px var(--missing) 2px", null);
}

test "var(): the fallback is substituted lazily" {
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    try expectSubstitution(t.host(null), "var(--a, var(--never))", "10px");
    try testing.expect(!t.wasAsked("--never"));
}

test "var(): the name argument is substituted, then parsed (variable-reference-name-substitution.html)" {
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    const host = t.host(null);
    try expectSubstitution(host, "var(var(--name))", "10px");
    try expectSubstitution(host, "var(var(var(--indirect)))", "10px");
    try expectSubstitution(host, "var(var(--spaced))", "10px");
    try expectSubstitution(host, "var(var(--not-name), 20px)", "20px");
    try expectSubstitution(host, "var(var(--unset), 30px)", "30px");
    try expectSubstitution(host, "var(var(--empty), 40px)", "40px");
    try expectSubstitution(host, "var(var(--two-tokens), 50px)", "50px");
    try expectSubstitution(host, "var(var(--dimension), 60px)", "60px");
    try expectSubstitution(host, "var(var(--string), 70px)", "70px");
    try expectSubstitution(host, "var(var(--dashes), 80px)", "80px");
    try expectSubstitution(host, "var({--a})", "10px");
    try expectSubstitution(host, "var({var(--name)})", "10px");
    try expectSubstitution(host, "var({ --a })", "10px");
    try expectSubstitution(host, "var({--a, --b}, 90px)", "90px");
    try expectSubstitution(host, "var(--\\61)", "10px");
    // A name that does not parse never reaches the lookup.
    try testing.expect(!t.wasAsked("not-a-custom-prop"));
}

test "env(): the host's value, indices, then the fallback (css-env-1 §3)" {
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    const host = t.host(test_environment);
    try expectSubstitution(host, "env(test-inset)", "3px");
    try expectSubstitution(host, "env(test-inset, 1px)", "3px");
    try expectSubstitution(host, "env(test-grid 1 0)", "10px");
    try expectSubstitution(host, "env(test-grid 1 +1)", "11px");
    // Wrong arity, unknown sub-value, unknown name: the fallback, else invalid.
    try expectSubstitution(host, "env(test-grid 1, 7px)", "7px");
    try expectSubstitution(host, "env(test-grid 5 5, 7px)", "7px");
    try expectSubstitution(host, "env(test-grid 99999999999 0, 7px)", "7px");
    try expectSubstitution(host, "env(test-inset 0, 7px)", "7px");
    try expectSubstitution(host, "env(unknown, 7px)", "7px");
    try expectSubstitution(host, "env(unknown)", null);
    try expectSubstitution(host, "[env(unknown,)]", "[]");
    try expectSubstitution(host, "env(unknown, env(other, 10px))", "10px");
    try expectSubstitution(host, "env(unknown, var(--a))", "10px");
    // No provider: every name is undefined.
    try expectSubstitution(t.host(null), "env(test-inset, 2px)", "2px");
    try expectSubstitution(t.host(null), "env(test-inset)", null);
}

test "substitution splices at token boundaries (Values 5 Appendix A)" {
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    const host = t.host(null);
    // `20` then `px` is a number and an ident, never one dimension.
    try expectSubstitution(host, "var(--gap)px", "20/**/px");
    try expectSubstitution(host, "var(--one)var(--one)", "1/**/1");
    // (`-var(` would be one function token, `-var`.)
    try expectSubstitution(host, "+var(--one)", "+/**/1");
    try expectSubstitution(host, "var(--gap) px", "20 px");
    try expectSubstitution(host, "(var(--gap))px", "(20)px");
    try expectSubstitution(host, "var(--b)", "red, blue");
}

test "comments between tokens are kept as written (css-variables-1 §4.1)" {
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    const host = t.host(null);
    try expectSubstitution(host, "a /* foo */ var(--commented) /* bar */ b", "a /* foo */ /* baz */ /* bar */ b");
    try expectSubstitution(host, "a/**/b var(--a)", "a/**/b 10px");
    try expectSubstitution(host, "foo(a /* c */) var(--a)", "foo(a /* c */) 10px");
}

test "an over-long substitution is the guaranteed-invalid value" {
    const big = try testing.allocator.alloc(u8, substitution.max_substituted_bytes / 2 + 1);
    defer testing.allocator.free(big);
    @memset(big, 'a');
    const vars = [_]Variable{.{ .name = "--big", .value = .{ .text = big } }};
    var t: TestHost = .{ .variables = &vars, .allocator = testing.allocator };
    defer t.deinit();
    try expectSubstitution(t.host(null), "var(--big)", big);
    try expectSubstitution(t.host(null), "var(--big) var(--big)", null);
}

fn rendered(allocator: Allocator, host: substitution.Host, text: []const u8) !substitution.Rendered {
    const nodes = try substitution.parse(allocator, text);
    return substitution.substituteAndRender(allocator, nodes, host, "background-image", null);
}

fn overlaps(range: substitution.TaintRange, start: usize, end: usize) bool {
    return range.start < end and start < range.end;
}

/// Whether the bytes of `needle` in `text` fall in a tainted range of `kind`.
fn taintedAs(r: substitution.Rendered, needle: []const u8, kind: substitution.Taint) bool {
    const at = std.mem.indexOf(u8, r.text, needle) orelse return false;
    for (r.taint) |range| if (range.kind == kind and overlaps(range, at, at + needle.len)) return true;
    return false;
}

fn tainted(r: substitution.Rendered, needle: []const u8) bool {
    return taintedAs(r, needle, .own) or taintedAs(r, needle, .container);
}

test "taint provenance (Values 5 §8.7.2) from a synthetic tainted value" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const vars = [_]Variable{
        .{ .name = "--t-url", .value = .{ .text = "url(foo.jpg)", .taint = &.{.{ .start = 0, .end = 12, .kind = .own }} } },
        .{ .name = "--t-color", .value = .{ .text = "red", .taint = &.{.{ .start = 0, .end = 3, .kind = .own }} } },
        .{ .name = "--t-empty", .value = .{ .text = "", .taint = &.{.{ .start = 0, .end = 0, .kind = .own }} } },
        .{ .name = "--clean", .value = .{ .text = "url(bar.jpg)" } },
    };
    var t: TestHost = .{ .variables = &vars, .allocator = testing.allocator };
    defer t.deinit();
    const host = t.host(null);
    // image("foo.jpg", <tainted color>): image( is a container; the string is clean.
    const passes = try rendered(a, host, "image(\"foo.jpg\", var(--t-color))");
    try testing.expect(taintedAs(passes, "image(", .container));
    try testing.expect(!tainted(passes, "\"foo.jpg\""));
    try testing.expect(taintedAs(passes, "red", .own));
    // image(<tainted url>): the url token itself is tainted.
    const fails = try rendered(a, host, "image(var(--t-url))");
    try testing.expect(taintedAs(fails, "url(foo.jpg)", .own));
    try testing.expect(taintedAs(fails, "image(", .container));
    // src(<empty tainted output>) still marks src( as a container.
    const empty = try rendered(a, host, "src(var(--t-empty))");
    try testing.expect(taintedAs(empty, "src(", .container));
    // A var() whose value carried a tainted url, one level deeper.
    const deep = try rendered(a, host, "image(calc(1), f(var(--t-url)))");
    try testing.expect(taintedAs(deep, "url(foo.jpg)", .own));
    try testing.expect(taintedAs(deep, "f(", .container));
    try testing.expect(taintedAs(deep, "image(", .container));
    try testing.expect(!tainted(deep, "calc(1)"));
    // An untainted value taints nothing.
    const clean = try rendered(a, host, "image(var(--clean))");
    try testing.expectEqual(@as(usize, 0), clean.taint.len);
}

test "a sole CSS-wide keyword after substitution is recognized" {
    try testing.expectEqualStrings("initial", substitution.soleKeyword("  initial ").?);
    try testing.expectEqualStrings("revert-layer", substitution.soleKeyword("/* c */ REVERT-LAYER").?);
    try testing.expect(substitution.soleKeyword("initial initial") == null);
    try testing.expect(substitution.soleKeyword("auto") == null);
    try testing.expect(substitution.soleKeyword("") == null);
}

test "<custom-property-name> parses a dashed ident other than --" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try testing.expectEqualStrings("--x", (try substitution.customPropertyName(a, " --x ")).?);
    try testing.expectEqualStrings("--Ab", (try substitution.customPropertyName(a, "--\\41 b")).?);
    try testing.expect((try substitution.customPropertyName(a, "--")) == null);
    try testing.expect((try substitution.customPropertyName(a, "-x")) == null);
    try testing.expect((try substitution.customPropertyName(a, "--x --y")) == null);
    try testing.expect((try substitution.customPropertyName(a, "\"--x\"")) == null);
}

fn substituteAll(allocator: Allocator) !void {
    var t: TestHost = .{ .variables = &variables, .allocator = allocator };
    defer t.deinit();
    for ([_][]const u8{ "var(var(--name), 1px) var(--gap)px", "env(test-grid 1 1, var(--b))", "env(unknown, var(--missing, {a, b}))" }) |text| {
        const got = try substituted(allocator, t.host(test_environment), text);
        if (got) |g| allocator.free(g);
    }
}

test "allocation failure propagates from every substitution path" {
    try testing.checkAllAllocationFailures(testing.allocator, substituteAll, .{});
}

test "a pending value keeps its property's absence for a custom property" {
    const pending = (try css.pending_values.Pending.create(.{ .allocator = testing.allocator }, null, "  a var(--x)  ")).?;
    defer pending.unref();
    try testing.expect(pending.property == null);
    try testing.expectEqualStrings("a var(--x)", pending.text);
    const vars = [_]Variable{.{ .name = "--x", .value = .{ .text = "b" } }};
    var t: TestHost = .{ .variables = &vars, .allocator = testing.allocator };
    defer t.deinit();
    const outcome = try pending.substituteCustom(testing.allocator, t.host(null), "--y");
    switch (outcome) {
        .substituted => |s| {
            defer testing.allocator.free(s.text);
            defer testing.allocator.free(s.taint);
            try testing.expectEqualStrings("a b", s.text);
        },
        else => return error.TestUnexpectedResult,
    }
    try testing.expect((try css.pending_values.Pending.create(.{ .allocator = testing.allocator }, null, "var()")) == null);
}

test "a replacement may substitute any span, catch the guaranteed-invalid value and go on (row 123 Q9)" {
    // A synthetic function's evaluation, as if()'s style() test would be:
    // substitute a span DURING evaluation, catch error.Invalid locally,
    // continue with another span; a span never evaluated is never looked up.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var t: TestHost = .{ .variables = &variables, .allocator = testing.allocator };
    defer t.deinit();
    const nodes = try substitution.parse(arena.allocator(), "var(--missing) | var(--a) | var(--never)");
    var resolver: substitution.Resolver = .{ .allocator = arena.allocator(), .host = t.host(null), .property = "width" };
    // The first span fails; the failure is caught and is no one else's.
    const failed = resolver.substitute(nodes[0..1], false);
    try testing.expectError(error.Invalid, failed);
    // The same resolver goes on with the next span.
    const next = try resolver.substitute(nodes[4..5], false);
    try testing.expectEqualStrings("10px", (try substitution.render(arena.allocator(), next)).text);
    // The short-circuited span was never evaluated: no dependency on it.
    try testing.expect(t.wasAsked("--missing"));
    try testing.expect(t.wasAsked("--a"));
    try testing.expect(!t.wasAsked("--never"));
}
