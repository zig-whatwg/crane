//! A fetched sheet retains the policy used by the resources it declares,
//! independently of its DOM owner and of a parent sheet's policy.
const std = @import("std");
const dom = @import("dom");

test "a stylesheet keeps its response referrer policy after detachment" {
    const record = try dom.style.SheetRecord.create(std.testing.allocator, "a { background-image: url(image.png) }", .{
        .location = "https://styles.example/sheet.css",
        .base_url = "https://styles.example/sheet.css",
        .referrer_policy = .origin,
    });
    defer record.unref();

    record.detach();
    try std.testing.expectEqual(.origin, record.referrer_policy);
    try std.testing.expectEqualStrings("https://styles.example/sheet.css", record.location.?);
    try std.testing.expectEqualStrings("https://styles.example/sheet.css", record.base_url);
}

test "an inline sheet defaults to its client's referrer policy" {
    const record = try dom.style.SheetRecord.create(std.testing.allocator, "", .{});
    defer record.unref();
    try std.testing.expectEqual(.empty, record.referrer_policy);
    try std.testing.expect(record.location == null);
}

test "lazy sheet parsing captures response policy and values retain it after sheet release" {
    const css = dom.style.css;
    const a = std.testing.allocator;
    const record = try dom.style.SheetRecord.create(a, "a { background-image: url(https://img.example/a.png) }", .{
        .location = "https://styles.example/sheet.css",
        .base_url = "https://styles.example/sheet.css",
        .referrer_policy = .origin,
        .origin_clean = false,
    });
    var owned = true;
    defer if (owned) record.unref();
    // Delivery can set the response policy after creating the lazy sheet.
    record.referrer_policy = .no_referrer;
    const list = try record.rulesWith(.{ .allocator = a });
    const declaration = list.items[0].block().?.get(.background_image).?;
    const value: css.style_values.Value = declaration.value.value;
    value.retain();
    defer value.release();
    const occurrences = value.resourceUrls();
    try std.testing.expectEqual(@as(usize, 1), occurrences.len);
    try std.testing.expect(occurrences[0].source != null);
    const source = occurrences[0].source.?;
    record.detach();
    record.unref();
    owned = false;
    try std.testing.expectEqualStrings("https://styles.example/sheet.css", source.base_url);
    try std.testing.expectEqualStrings("https://styles.example/sheet.css", source.referrer.?);
    try std.testing.expectEqualStrings("no-referrer", source.referrer_policy);
    try std.testing.expect(!source.origin_clean);
}

test "resource-free source factories allocate nothing" {
    const a = std.testing.allocator;
    const record = try dom.style.SheetRecord.create(a, "a { color: red }", .{});
    defer record.unref();
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    record.allocator = failing.allocator();
    defer record.allocator = a;
    try std.testing.expect((try record.resourceSource("color: red")) == null);
    try std.testing.expect(!failing.has_induced_failure);
}

test "sheet source allocation failures release partial source data" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            const record = try dom.style.SheetRecord.create(a, "a { background-image: url(x.png) }", .{
                .location = "https://styles.example/sheet.css",
                .base_url = "https://styles.example/sheet.css",
                .referrer_policy = .same_origin,
            });
            defer record.unref();
            const source = (try record.resourceSource(record.text.?)).?;
            defer source.unref();
            try std.testing.expectEqualStrings("same-origin", source.referrer_policy);
        }
    }.exercise, .{});
}

test "font sources own sheet provenance after the rule is detached and the sheet released" {
    const a = std.testing.allocator;
    const record = try dom.style.SheetRecord.create(
        a,
        "@font-face { font-family: cr1; src: local(cr1), url(https://font.example/a.woff2), url(\"\") }",
        .{ .location = "https://sheet.example/a.css", .base_url = "https://sheet.example/a.css", .referrer_policy = .origin },
    );
    var owns_sheet = true;
    defer if (owns_sheet) record.unref();
    const list = try record.rulesWith(.{ .allocator = a });
    const rule = list.items[0];
    rule.ref();
    defer rule.unref();
    record.detach();
    record.unref();
    owns_sheet = false;
    const sources = rule.data.font_face.sources.?;
    try std.testing.expectEqual(@as(usize, 3), sources.items.len);
    try std.testing.expect(sources.items[0].resource == null);
    const resource = sources.items[1].resource.?;
    try std.testing.expect(resource.valid);
    try std.testing.expectEqualStrings("https://font.example/a.woff2", resource.url);
    try std.testing.expectEqualStrings("https://sheet.example/a.css", resource.source.?.base_url);
    try std.testing.expectEqualStrings("https://sheet.example/a.css", resource.source.?.referrer.?);
    try std.testing.expectEqualStrings("origin", resource.source.?.referrer_policy);
    try std.testing.expect(!sources.items[2].resource.?.valid);
}

test "font src edits resolve once and invalid edits preserve the old source list" {
    const fonts = dom.style.engine.resource_loading.font_loading;
    const css = dom.style.css;
    const a = std.testing.allocator;
    const Resolver = struct {
        calls: usize = 0,
        fn resolve(raw_context: *const anyopaque, allocator: std.mem.Allocator, raw: []const u8) ?[]u8 {
            const self: *@This() = @ptrCast(@alignCast(@constCast(raw_context)));
            self.calls += 1;
            if (std.mem.eql(u8, raw, "bad")) return null;
            return std.fmt.allocPrint(allocator, "https://font.example/{s}", .{raw}) catch null;
        }
    };
    var resolver: Resolver = .{};
    const source = try css.style_values.ResourceSource.create(a, .{ .base_url = "https://font.example/" });
    defer source.unref();
    const options: css.properties.ParseOptions = .{
        .allocator = a,
        .resource_source = source,
        .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve },
    };
    var rule = try fonts.FontRule.fromText(options, "font-family: cr1; src: local(cr1), url(a.woff2), url(bad)");
    defer rule.deinit();
    try std.testing.expectEqual(@as(usize, 2), resolver.calls);
    try std.testing.expectEqualStrings("https://font.example/a.woff2", rule.sources.?.items[1].resource.?.url);
    try std.testing.expect(!rule.sources.?.items[2].resource.?.valid);
    try std.testing.expect(!(try rule.setProperty(options, "src", "not-a-source", "")));
    try std.testing.expectEqual(@as(usize, 2), resolver.calls);
    try std.testing.expect(try rule.setProperty(options, "font-weight", "700", ""));
    try std.testing.expectEqual(@as(usize, 2), resolver.calls);
    try std.testing.expect(try rule.setProperty(options, "src", "url(b.woff2)", ""));
    try std.testing.expectEqual(@as(usize, 3), resolver.calls);
    try std.testing.expectEqualStrings("https://font.example/b.woff2", rule.sources.?.items[0].resource.?.url);
    try std.testing.expect(try rule.setProperty(options, "src", "", "invalid-priority"));
    try std.testing.expect(rule.sources == null);
    try std.testing.expectEqualStrings("", fonts.descriptorValue(&rule.block, "src"));
}

test "detached font rule keeps prior provenance and new src uses detached parse context" {
    const fonts = dom.style.engine.resource_loading.font_loading;
    const css = dom.style.css;
    const a = std.testing.allocator;
    const source = try css.style_values.ResourceSource.create(a, .{ .base_url = "https://old.example/", .referrer = "https://old.example/a.css" });
    defer source.unref();
    var rule = try fonts.FontRule.fromText(.{ .allocator = a, .resource_source = source }, "font-family: cr1; src: url(a.woff2)");
    defer rule.deinit();
    const detached: css.properties.ParseOptions = .{ .allocator = a };
    try std.testing.expect(try rule.setProperty(detached, "font-weight", "700", ""));
    try std.testing.expect(rule.sources.?.items[0].resource.?.source == source);
    try std.testing.expect(try rule.setProperty(detached, "src", "url(b.woff2)", ""));
    try std.testing.expectEqualStrings("b.woff2", rule.sources.?.items[0].resource.?.url);
    try std.testing.expect(rule.sources.?.items[0].resource.?.source == null);
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(a);
    try rule.block.serialize(&serialized);
    try rule.setCssText(detached, serialized.items);
    try std.testing.expectEqualStrings("700", fonts.descriptorValue(&rule.block, "font-weight"));
    try std.testing.expectEqualStrings("b.woff2", rule.sources.?.items[0].resource.?.url);
    try rule.setCssText(detached, "font-family: replacement");
    try std.testing.expect(rule.sources == null);
}

test "font rule source mutations roll back every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            const fonts = dom.style.engine.resource_loading.font_loading;
            const css = dom.style.css;
            const source = try css.style_values.ResourceSource.create(a, .{ .base_url = "https://font.example/" });
            defer source.unref();
            const options: css.properties.ParseOptions = .{ .allocator = a, .resource_source = source };
            var rule = try fonts.FontRule.fromText(options, "font-family: cr1; src: url(old.woff2)");
            defer rule.deinit();
            _ = rule.setProperty(options, "src", "local(cr1), url(new.woff2)", "") catch |err| {
                try std.testing.expectEqualStrings("old.woff2", rule.sources.?.items[0].resource.?.url);
                try std.testing.expectEqualStrings("url(\"old.woff2\")", fonts.descriptorValue(&rule.block, "src"));
                return err;
            };
            rule.setCssText(options, "font-family: replacement; src: url(last.woff2)") catch |err| {
                try std.testing.expectEqualStrings("new.woff2", rule.sources.?.items[1].resource.?.url);
                try std.testing.expectEqualStrings("cr1", fonts.descriptorValue(&rule.block, "font-family"));
                return err;
            };
        }
    }.exercise, .{});
}

test "font rule construction releases metadata on every sheet allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            const sheet = try dom.style.SheetRecord.create(a, "@font-face {font-family: cr1; src: url(font.woff2)}", .{
                .location = "https://sheet.example/a.css",
                .base_url = "https://sheet.example/",
            });
            defer sheet.unref();
            const rules = try sheet.rulesWith(.{ .allocator = a });
            try std.testing.expect(rules.items[0].data.font_face.sources.?.items[0].resource.?.source != null);
        }
    }.exercise, .{});
}

test "compiled font rules retain nested conditions and skip false supports" {
    const contents = try dom.style.sheet.Contents.parse(std.testing.allocator,
        \\@font-face {font-family: first; src: local(first)}
        \\@media screen { @media (min-width: 700px) {
        \\  @supports (display: block) { @layer fonts {
        \\    @font-face {font-family: wide; src: local(wide)}
        \\  }}
        \\}}
        \\@supports (cr1-unknown: impossible) {
        \\  @font-face {font-family: unsupported; src: local(unsupported)}
        \\}
        \\@media print { @font-face {font-family: print; src: local(print)} }
    , .{});
    defer contents.destroy();
    try std.testing.expectEqual(@as(usize, 3), contents.font_rules.items.len);
    const fonts = dom.style.engine.resource_loading.font_loading;
    const first = contents.font_rules.items[0];
    const wide = contents.font_rules.items[1];
    const print = contents.font_rules.items[2];
    try std.testing.expectEqualStrings("first", fonts.descriptorValue(first.rule.block().?, "font-family"));
    try std.testing.expectEqualStrings("wide", fonts.descriptorValue(wide.rule.block().?, "font-family"));
    try std.testing.expectEqualStrings("print", fonts.descriptorValue(print.rule.block().?, "font-family"));
    try std.testing.expect(first.condition == null);
    try std.testing.expect(contents.conditionHolds(wide.condition, &.{ .width = 800 }));
    try std.testing.expect(!contents.conditionHolds(wide.condition, &.{ .width = 600 }));
    try std.testing.expect(!contents.conditionHolds(wide.condition, &.{ .width = 800, .media_type = .print }));
    try std.testing.expect(contents.conditionHolds(print.condition, &.{ .media_type = .print }));
}

test "font index is allocation-free when absent and releases partial compilations" {
    const ordinary = try dom.style.sheet.Contents.parse(std.testing.allocator, "div { color: red }", .{});
    defer ordinary.destroy();
    try std.testing.expectEqual(@as(usize, 0), ordinary.font_rules.capacity);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            const contents = try dom.style.sheet.Contents.parse(a, "@media screen { @layer fonts { @font-face {font-family: cr1; src: local(cr1)} } }", .{});
            defer contents.destroy();
            try std.testing.expectEqual(@as(usize, 1), contents.font_rules.items.len);
        }
    }.exercise, .{});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            const contents = try dom.style.sheet.Contents.parse(a, "@layer fonts { @font-face {font-family: cr1; src: local(cr1)} }", .{});
            defer contents.destroy();
            try std.testing.expectEqual(@as(usize, 1), contents.font_rules.items.len);
        }
    }.exercise, .{});
}

test "font snapshots retain ordered source provenance through every allocation failure" {
    const fonts = dom.style.engine.resource_loading.font_loading;
    if (comptime !@hasDecl(fonts.FontRule, "clone")) return error.MissingFontSnapshotClone;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator) !void {
            var font = try fonts.FontRule.fromText(.{ .allocator = a }, "font-family: Snapshot; src: local(first), url(second.woff2); font-weight: 300 700");
            defer font.deinit();
            var copy = try font.clone(a);
            defer copy.deinit();
            try std.testing.expectEqualStrings("Snapshot", fonts.descriptorValue(&copy.block, "font-family"));
            try std.testing.expectEqualStrings("300 700", fonts.descriptorValue(&copy.block, "font-weight"));
            try std.testing.expectEqual(@as(usize, 2), copy.sources.?.items.len);
            try std.testing.expectEqualStrings(font.sources.?.serialized, copy.sources.?.serialized);
            try std.testing.expect(copy.sources.?.items.ptr != font.sources.?.items.ptr);
        }
    }.exercise, .{});
}
