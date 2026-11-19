//! CSS Values4 §4.5 and CSSOM serialize-a-URL: authored text, frozen resolution.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Resolver = struct {
    prefix: []const u8 = "https://old.test/css/",
    calls: usize = 0,
    oom: bool = false,
    fn resolve(context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
        const self: *Resolver = @ptrCast(@alignCast(@constCast(context)));
        self.calls += 1;
        return std.mem.concat(allocator, u8, &.{ self.prefix, raw }) catch {
            self.oom = true;
            return null;
        };
    }
};
const Case = struct { property: []const u8, input: []const u8, specified: []const u8, computed: []const u8 };
const cases = [_]Case{
    .{ .property = "background-image", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "content", .input = "url(\"picture.svg\") 'tail'", .specified = "url(\"picture.svg\") \"tail\"", .computed = "url(\"https://old.test/css/picture.svg\") \"tail\"" },
    .{ .property = "cursor", .input = "url(first.cur) 1 2, url(second.cur), pointer", .specified = "url(\"first.cur\") 1 2, url(\"second.cur\"), pointer", .computed = "url(\"https://old.test/css/first.cur\") 1 2, url(\"https://old.test/css/second.cur\"), pointer" },
    .{ .property = "list-style-image", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "background-image", .input = "image-set(url(\"a.png\") 1x, \"b.png\" 2x)", .specified = "image-set(url(\"a.png\") 1x, url(\"b.png\") 2x)", .computed = "image-set(url(\"https://old.test/css/a.png\") 1dppx, url(\"https://old.test/css/b.png\") 2dppx)" },
    .{ .property = "content", .input = "\"prefix\" image-set(url(\"a.png\") 1x, \"b.png\" 2x)", .specified = "\"prefix\" image-set(url(\"a.png\") 1x, url(\"b.png\") 2x)", .computed = "\"prefix\" image-set(url(\"https://old.test/css/a.png\") 1dppx, url(\"https://old.test/css/b.png\") 2dppx)" },
    // CSS Values 5 §4.1.1 (lane maj1, the request URL modifiers row that
    // replaced Q81's opaque fallback): request modifiers stay typed, in the
    // grammar's order, beside the frozen computed URL.
    .{ .property = "background-image", .input = "image-set(url(\"a.png\" cross-origin(anonymous)) 1x, \"b.png\" 2x)", .specified = "image-set(url(\"a.png\" cross-origin(anonymous)) 1x, url(\"b.png\") 2x)", .computed = "image-set(url(\"https://old.test/css/a.png\" cross-origin(anonymous)) 1dppx, url(\"https://old.test/css/b.png\") 2dppx)" },
    .{ .property = "content", .input = "url(\"picture.svg\" cross-origin(use-credentials)) 'tail'", .specified = "url(\"picture.svg\" cross-origin(use-credentials)) \"tail\"", .computed = "url(\"https://old.test/css/picture.svg\" cross-origin(use-credentials)) \"tail\"" },
};

fn checkCase(allocator: Allocator, case: Case) !void {
    var resolver = Resolver{};
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://old.test/css/main.css", .referrer_policy = "no-referrer" });
    var source_owned = true;
    defer if (source_owned) source.unref();
    var block = css.declarations.DeclarationBlock.init(allocator);
    var block_owned = true;
    defer if (block_owned) block.deinit();
    const ok = try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, case.property, case.input, "");
    if (resolver.oom) return error.OutOfMemory;
    try testing.expect(ok);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(case.property, &text);
    try testing.expectEqualStrings(case.specified, text.items);
    const calls_after_parse = resolver.calls;
    try testing.expect(calls_after_parse > 0);
    resolver.prefix = "https://changed.test/elsewhere/";
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const property = css.properties.lookup(case.property) orelse return error.MissingProperty;
    block.deinit();
    block_owned = false;
    source.unref();
    source_owned = false;
    text.clearRetainingCapacity();
    try style.serializeResolved(property.longhand, &text, allocator);
    try testing.expectEqualStrings(case.computed, text.items);
    try testing.expectEqual(calls_after_parse, resolver.calls);
    for (style.get(property.longhand).resourceUrls()) |url| {
        try testing.expect(std.mem.startsWith(u8, url.url, "https://old.test/css/"));
        try testing.expectEqualStrings("https://old.test/css/main.css", url.source.?.base_url);
        try testing.expectEqualStrings("no-referrer", url.source.?.referrer_policy);
    }
}

test "authored URL and frozen computed resolution: background-image" {
    try checkCase(testing.allocator, cases[0]);
}

test "authored URL and frozen computed resolution: content" {
    try checkCase(testing.allocator, cases[1]);
}

test "authored URL and frozen computed resolution: cursor" {
    try checkCase(testing.allocator, cases[2]);
}

test "authored URL and frozen computed resolution: list-style-image" {
    try checkCase(testing.allocator, cases[3]);
}

test "authored URL and frozen computed resolution: image-set string option" {
    try checkCase(testing.allocator, cases[4]);
}

test "content prefix offsets both the URL component and its quoted argument" {
    try checkCase(testing.allocator, cases[5]);
}

test "authored and computed URLs retain independent ownership through every allocation failure" {
    for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, checkCase, .{case});
}

test "request URL modifiers stay typed beside the frozen computed URL" {
    // Q81's interim opaque path for a quoted url() with a tail is gone: the
    // modifiers parse, and every browser rejects an unknown one
    // (css/css-values/urls/url-request-modifiers-invalid.sub.html).
    try checkCase(testing.allocator, cases[6]);
    try checkCase(testing.allocator, cases[7]);
}

test "font-face src descriptor retains authored text without calling the property resolver" {
    const allocator = testing.allocator;
    var resolver = Resolver{};
    var parsed = (try css.rules.parseRule(allocator, "@font-face { font-family: Ci1Face; src: url(font.woff2); }")) orelse return error.ExpectedRule;
    defer parsed.deinitOwned(allocator);
    var block = try css.declarations.DeclarationBlock.fromDeclarations(.{ .allocator = allocator, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, parsed.declarations);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("src", &out);
    try testing.expectEqualStrings("url(\"font.woff2\")", out.items);
    try testing.expectEqual(@as(usize, 0), resolver.calls);
}

fn localOrNonlocal(allocator: Allocator, name: []const u8, local: bool) !void {
    const raw = if (local) "#icon" else "a.b#icon";
    const suffix = if (std.mem.eql(u8, name, "cursor")) ", pointer" else "";
    const specified = try std.fmt.allocPrint(allocator, "url(\"{s}\"){s}", .{ raw, suffix });
    defer allocator.free(specified);
    const expected = if (local) try allocator.dupe(u8, specified) else try std.fmt.allocPrint(allocator, "url(\"https://old.test/css/{s}\"){s}", .{ raw, suffix });
    defer allocator.free(expected);
    try checkCase(allocator, .{ .property = name, .input = specified, .specified = specified, .computed = expected });
}

test "local fragments stay local in computed CSS while nonlocal fragments resolve" {
    for ([_][]const u8{ "background-image", "cursor", "content" }) |name| {
        try testing.checkAllAllocationFailures(testing.allocator, localOrNonlocal, .{ name, true });
        try testing.checkAllAllocationFailures(testing.allocator, localOrNonlocal, .{ name, false });
    }
}

const InvalidResolver = struct {
    fn resolve(_: *const anyopaque, _: Allocator, _: []const u8) ?[]u8 {
        return null;
    }
};

fn invalidUrl(allocator: Allocator, name: []const u8, empty: bool) !void {
    var resolver = Resolver{};
    const raw = if (empty) "" else "bad[";
    const suffix = if (std.mem.eql(u8, name, "cursor")) ", pointer" else "";
    const expected = try std.fmt.allocPrint(allocator, "url(\"{s}\"){s}", .{ raw, suffix });
    defer allocator.free(expected);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const ok = try block.setProperty(.{ .allocator = allocator, .url_resolver = .{
        .context = &resolver,
        .resolve = if (empty) Resolver.resolve else InvalidResolver.resolve,
    } }, name, expected, "");
    if (resolver.oom) return error.OutOfMemory;
    try testing.expect(ok);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings(expected, text.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const longhand = css.properties.lookup(name).?.longhand;
    const urls = style.get(longhand).resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expect(!urls[0].valid);
    try testing.expectEqualStrings(raw, urls[0].url);
    text.clearRetainingCapacity();
    try style.serializeResolved(longhand, &text, allocator);
    try testing.expectEqualStrings(expected, text.items);
}

test "empty and failed URL resolutions preserve authored text and cannot request the base" {
    for ([_][]const u8{ "background-image", "cursor", "content" }) |name| {
        try testing.checkAllAllocationFailures(testing.allocator, invalidUrl, .{ name, true });
        try testing.checkAllAllocationFailures(testing.allocator, invalidUrl, .{ name, false });
    }
}

fn shorthand(allocator: Allocator, name: []const u8) !void {
    var resolver = Resolver{};
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const ok = try block.setProperty(.{ .allocator = allocator, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, name, "url(picture.svg)", "");
    if (resolver.oom) return error.OutOfMemory;
    try testing.expect(ok);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try testing.expect(std.mem.indexOf(u8, text.items, "url(\"picture.svg\")") != null);
    try testing.expect(std.mem.indexOf(u8, text.items, "https:") == null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const property = css.properties.lookup(name).?.shorthand;
    var assigned: [css.properties.max_assignments]css.properties.Assigned = undefined;
    for (property.longhands(), 0..) |longhand, index| assigned[index] = .{ .value = style.get(longhand) };
    text.clearRetainingCapacity();
    try testing.expect(try css.properties.serializeShorthand(property, assigned[0..property.longhands().len], .computed, &text, allocator));
    try testing.expect(std.mem.indexOf(u8, text.items, "url(\"https://old.test/css/picture.svg\")") != null);
    try testing.expect(std.mem.indexOf(u8, text.items, "url(\"picture.svg\")") == null);
}

test "computed background shorthand resolves its URL leaf" {
    for ([_][]const u8{"background"}) |name| {
        try testing.checkAllAllocationFailures(testing.allocator, shorthand, .{name});
    }
}
