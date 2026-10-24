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
    .{ .property = "mask-image", .input = "url(first.svg), url(second.svg)", .specified = "url(\"first.svg\"), url(\"second.svg\")", .computed = "url(\"https://old.test/css/first.svg\"), url(\"https://old.test/css/second.svg\")" },
    .{ .property = "mask-border-source", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "fill", .input = "url(picture.svg) currentcolor", .specified = "url(\"picture.svg\") currentcolor", .computed = "url(\"https://old.test/css/picture.svg\") rgb(0, 0, 0)" },
    .{ .property = "stroke", .input = "url(picture.svg) currentcolor", .specified = "url(\"picture.svg\") currentcolor", .computed = "url(\"https://old.test/css/picture.svg\") rgb(0, 0, 0)" },
    .{ .property = "marker-start", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "marker-mid", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "marker-end", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "clip-path", .input = "url(picture.svg)", .specified = "url(\"picture.svg\")", .computed = "url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "filter", .input = "drop-shadow(currentcolor 1px 2px) url(picture.svg)", .specified = "drop-shadow(currentcolor 1px 2px) url(\"picture.svg\")", .computed = "drop-shadow(rgb(0, 0, 0) 1px 2px 0px) url(\"https://old.test/css/picture.svg\")" },
    .{ .property = "background-image", .input = "image-set(url(\"a.png\") 1x, \"b.png\" 2x)", .specified = "image-set(url(\"a.png\") 1x, url(\"b.png\") 2x)", .computed = "image-set(url(\"https://old.test/css/a.png\") 1dppx, url(\"https://old.test/css/b.png\") 2dppx)" },
    .{ .property = "content", .input = "\"prefix\" image-set(url(\"a.png\") 1x, \"b.png\" 2x)", .specified = "\"prefix\" image-set(url(\"a.png\") 1x, url(\"b.png\") 2x)", .computed = "\"prefix\" image-set(url(\"https://old.test/css/a.png\") 1dppx, url(\"https://old.test/css/b.png\") 2dppx)" },
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

test "authored URL and frozen computed resolution: mask-image" {
    try checkCase(testing.allocator, cases[4]);
}

test "authored URL and frozen computed resolution: mask-border-source" {
    try checkCase(testing.allocator, cases[5]);
}

test "authored URL and frozen computed resolution: fill" {
    try checkCase(testing.allocator, cases[6]);
}

test "authored URL and frozen computed resolution: stroke" {
    try checkCase(testing.allocator, cases[7]);
}

test "authored URL and frozen computed resolution: marker-start" {
    try checkCase(testing.allocator, cases[8]);
}

test "authored URL and frozen computed resolution: marker-mid" {
    try checkCase(testing.allocator, cases[9]);
}

test "authored URL and frozen computed resolution: marker-end" {
    try checkCase(testing.allocator, cases[10]);
}

test "authored URL and frozen computed resolution: clip-path" {
    try checkCase(testing.allocator, cases[11]);
}

test "authored URL and frozen computed resolution: filter currentcolor before URL" {
    try checkCase(testing.allocator, cases[12]);
}

test "authored URL and frozen computed resolution: image-set string option" {
    try checkCase(testing.allocator, cases[13]);
}

test "content prefix offsets both the URL component and its quoted argument" {
    try checkCase(testing.allocator, cases[14]);
}

test "authored and computed URLs retain independent ownership through every allocation failure" {
    for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, checkCase, .{case});
}

const ModifierChecks = if (@hasDecl(css, "resolved_urls")) struct {
    fn check(allocator: Allocator) !void {
        const text = "image-set(url(\"a.png\" cross-origin(anonymous)) 1x, \"b.png\" 2x)";
        var resolver = Resolver{};
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        const ok = try block.setProperty(.{ .allocator = allocator, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, "background-image", text, "");
        if (resolver.oom) return error.OutOfMemory;
        try testing.expect(ok);
        const urls = block.get(.background_image).?.value.value.resourceUrls();
        try testing.expectEqual(@as(usize, 2), urls.len);
        const first = urls[0].argument_range orelse return error.ExpectedArgumentRange;
        const second = urls[1].argument_range orelse return error.ExpectedArgumentRange;
        try testing.expectEqualStrings("\"a.png\"", text[first.start..first.end]);
        try testing.expectEqualStrings("\"b.png\"", text[second.start..second.end]);
        try testing.expectEqualStrings("url(\"a.png\" cross-origin(anonymous))", text[urls[0].range.start..urls[0].range.end]);
        const offset: usize = "prefix ".len;
        var copies: std.ArrayList(css.style_values.ResourceUrl) = .empty;
        defer {
            for (copies.items) |url| url.deinit(allocator);
            copies.deinit(allocator);
        }
        try copies.ensureTotalCapacity(allocator, urls.len);
        for (urls) |url| copies.appendAssumeCapacity(try url.clone(allocator, offset));
        const cloned = copies.items;
        try testing.expectEqual(first.start + offset, cloned[0].argument_range.?.start);
        try testing.expectEqual(first.end + offset, cloned[0].argument_range.?.end);
        try testing.expectEqual(second.start + offset, cloned[1].argument_range.?.start);
        var different = urls[0];
        different.argument_range.?.end -= 1;
        try testing.expect(!urls[0].eql(different));
        const prefixed = try std.mem.concat(allocator, u8, &.{ "prefix ", text });
        defer allocator.free(prefixed);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        const calls = resolver.calls;
        resolver.prefix = "https://changed.test/";
        try css.resolved_urls.append(prefixed, cloned, &out, allocator);
        try testing.expectEqualStrings("prefix image-set(url(\"https://old.test/css/a.png\" cross-origin(anonymous)) 1x, \"https://old.test/css/b.png\" 2x)", out.items);
        try testing.expectEqual(calls, resolver.calls);
    }
} else struct {};

test "computed URL replacement preserves modifiers string options and cloned argument ranges" {
    if (comptime !@hasDecl(css, "resolved_urls")) return error.ComputedUrlSerializerNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, ModifierChecks.check, .{});
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
    for ([_][]const u8{ "background-image", "cursor", "fill", "marker-start", "clip-path", "filter", "content" }) |name| {
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
    for ([_][]const u8{ "background-image", "cursor", "content", "fill", "filter" }) |name| {
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

test "computed background marker mask and mask-border shorthands resolve their URL leaves" {
    for ([_][]const u8{ "background", "marker", "mask", "mask-border" }) |name| {
        try testing.checkAllAllocationFailures(testing.allocator, shorthand, .{name});
    }
}

fn markerIdentity(allocator: Allocator, same_resolved: bool) !void {
    var resolver = Resolver{};
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    for ([_][]const u8{ "marker-start", "marker-mid", "marker-end" }, 0..) |name, index| {
        resolver.prefix = if (index == 0) "https://old.test/css/" else if (same_resolved) "https://old.test/" else "https://changed.test/";
        const input = if (index != 0 and same_resolved) "url(css/picture.svg)" else "url(picture.svg)";
        const ok = try block.setProperty(.{ .allocator = allocator, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, name, input, "");
        if (resolver.oom) return error.OutOfMemory;
        try testing.expect(ok);
    }
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("marker", &text);
    try testing.expectEqualStrings(if (same_resolved) "" else "url(\"picture.svg\")", text.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var assigned: [3]css.properties.Assigned = undefined;
    for (css.properties.Shorthand.marker.longhands(), 0..) |longhand, index| assigned[index] = .{ .value = style.get(longhand) };
    text.clearRetainingCapacity();
    const serialized = try css.properties.serializeShorthand(.marker, &assigned, .computed, &text, allocator);
    try testing.expectEqual(same_resolved, serialized);
    if (serialized) try testing.expectEqualStrings("url(\"https://old.test/css/picture.svg\")", text.items);
}

test "computed marker compression compares resolved references while specified compares authored ones" {
    try testing.checkAllAllocationFailures(testing.allocator, markerIdentity, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, markerIdentity, .{true});
}

// Q66: the later-supported property joins the same URL checks; keep all
// existing paths and their assertions unchanged.
test "authored URL and frozen computed resolution: border-image-source" {
    try testing.checkAllAllocationFailures(testing.allocator, checkCase, .{Case{
        .property = "border-image-source",
        .input = "url(picture.svg)",
        .specified = "url(\"picture.svg\")",
        .computed = "url(\"https://old.test/css/picture.svg\")",
    }});
    try testing.checkAllAllocationFailures(testing.allocator, localOrNonlocal, .{ "border-image-source", true });
    try testing.checkAllAllocationFailures(testing.allocator, localOrNonlocal, .{ "border-image-source", false });
    try testing.checkAllAllocationFailures(testing.allocator, invalidUrl, .{ "border-image-source", true });
    try testing.checkAllAllocationFailures(testing.allocator, invalidUrl, .{ "border-image-source", false });
}
