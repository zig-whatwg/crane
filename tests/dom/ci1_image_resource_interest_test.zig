//! CSSOM-parsed sheets lose raw text; typed image values retain resource interest.
//! CSS Values 4 section 4.5.4: keep URL ownership and provenance through parsing.
const std = @import("std");
const dom = @import("dom");
const css = dom.style.css;
const resources = dom.style.engine.resource_loading;

const Case = struct { text: []const u8, tag: std.meta.Tag(css.style_values.Value), urls: usize };

fn parsedInterest(a: std.mem.Allocator, input: Case) !void {
    const sheet = try dom.style.SheetRecord.create(a, input.text, .{
        .base_url = "https://sheet.example/base.css",
        .location = "https://sheet.example/base.css",
        .referrer_policy = .origin,
    });
    defer sheet.unref();
    try std.testing.expect(resources.sheetMayHaveResources(sheet));
    const rules = try sheet.rulesWith(.{ .allocator = a });
    try std.testing.expect(sheet.text == null);
    try std.testing.expectEqual(@as(usize, 1), rules.items.len);
    const value = rules.items[0].block().?.get(.background_image).?.value.value;
    try std.testing.expectEqual(input.tag, std.meta.activeTag(value));
    try std.testing.expectEqual(input.urls, value.resourceUrls().len);
    const serialized = resources.backgroundImageText(value).?;
    for (value.resourceUrls()) |url| {
        try std.testing.expect(url.range.start < url.range.end);
        try std.testing.expect(url.range.end <= serialized.len);
        try std.testing.expectEqualStrings("https://sheet.example/base.css", url.source.?.base_url);
        try std.testing.expectEqualStrings("https://sheet.example/base.css", url.source.?.referrer.?);
        try std.testing.expectEqualStrings("origin", url.source.?.referrer_policy);
    }
    // On 90714 the typed cases reach ruleMayHaveResources' else arm.
    // This is interest discovery, not candidate selection or fetching.
    try std.testing.expect(resources.sheetMayHaveResources(sheet));
}

test "parsed scalar URL retains resource interest" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parsedInterest, .{Case{
        .text = "a { background-image: url(https://img.example/a.png) }",
        .tag = .text,
        .urls = 1,
    }});
}

test "parsed typed background layers retain resource interest" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parsedInterest, .{Case{
        .text = "a { background-image: url(https://img.example/a.png), url(https://img.example/b.png) }",
        .tag = .layers,
        .urls = 2,
    }});
}

test "parsed typed image-set retains resource interest" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parsedInterest, .{Case{
        .text = "a { background-image: image-set(url(https://img.example/a.png) 1x, url(https://img.example/b.png) 2x) }",
        .tag = .image,
        .urls = 2,
    }});
}

test "parsed typed light-dark retains resource interest" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parsedInterest, .{Case{
        .text = "a { background-image: light-dark(url(https://img.example/a.png), url(https://img.example/b.png)) }",
        .tag = .image,
        .urls = 2,
    }});
}

test "parsed resource-free gradients and colors do not establish resource interest" {
    for ([_][]const u8{
        "a { background-image: linear-gradient(red, blue) }",
        "a { color: red; background-image: none }",
    }) |text| try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(a: std.mem.Allocator, input: []const u8) !void {
            const sheet = try dom.style.SheetRecord.create(a, input, .{});
            defer sheet.unref();
            _ = try sheet.rulesWith(.{ .allocator = a });
            try std.testing.expect(sheet.text == null);
            try std.testing.expect(!resources.sheetMayHaveResources(sheet));
        }
    }.exercise, .{text});
}
