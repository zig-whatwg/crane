//! CSS UI 4 §5.1.1 and CSS Lists 3 §3.3: grammar and owned URL provenance.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Value = css.style_values.Value;

fn parse(allocator: std.mem.Allocator, property: []const u8, text: []const u8, source: ?*css.style_values.ResourceSource) !?Value {
    const p = css.properties.lookup(property) orelse return null;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer assignments.deinit(allocator);
    if (!try css.properties.parseDeclaration(.{ .allocator = allocator, .resource_source = source }, p, text, &assignments)) return null;
    try testing.expectEqual(@as(usize, 1), assignments.items.len);
    return assignments.items[0].value.value;
}

fn serialized(property: []const u8, input: []const u8, expected: []const u8) !void {
    const value = (try parse(testing.allocator, property, input, null)) orelse return error.ExpectedValidValue;
    defer value.release();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(testing.allocator);
    try css.properties.serializeValue(css.properties.lookup(property).?.longhand, value, &output, testing.allocator);
    try testing.expectEqualStrings(expected, output.items);
}

test "cursor keywords and optional ordered image hotspots serialize canonically" {
    try serialized("cursor", "PoInTeR", "pointer");
    try serialized("cursor", "contex\\74-menu", "context-menu");
    try serialized("cursor", "url(a.cur) 1.0 -2, url('b.png'), grab", "url(\"a.cur\") 1 -2, url(\"b.png\"), grab");
    try serialized("cursor", "url() 0 0, none", "url(\"\") 0 0, none");
    try serialized("cursor", "url(a.cur) calc(1) 2, pointer", "url(\"a.cur\") calc(1) 2, pointer");
    // Q3: Firefox/Safari retain fractional hotspots; Blink truncates.
    // Evidence: tmp/analysis/integrator-probes-1022c/results/cursor-*.json.
    try serialized("cursor", "url(a) 1.5 -2.9, pointer", "url(\"a\") 1.5 -2.9, pointer");
    try serialized("cursor", "url(a) 0.4 0.6, pointer", "url(\"a\") 0.4 0.6, pointer");
    try serialized("cursor", "url(a) 1e1 2, pointer", "url(\"a\") 10 2, pointer");
}

test "cursor requires a final keyword, paired numbers and comma separated images" {
    for ([_][]const u8{ "", "bogus", "url(a.cur)", "url(a.cur) pointer", "url(a.cur) 1, pointer", "url(a.cur) 1px 2px, pointer", "url(a.cur) 1 2 3, pointer", "pointer, url(a.cur)", "url(a.cur),", "url(a.cur), pointer junk", "linear-gradient(red, blue), pointer" }) |input| {
        const value = try parse(testing.allocator, "cursor", input, null);
        defer if (value) |v| v.release();
        try testing.expect(value == null);
    }
}

test "list-style-image is inherited, single-valued and exposes the image resource" {
    const prop = css.properties.lookup("list-style-image") orelse return error.MissingListStyleImage;
    try testing.expect(prop.longhand.inherited());
    try testing.expect(prop.longhand.info().initial.isKeyword(.none));
    try serialized("list-style-image", "url('marker.png')", "url(\"marker.png\")");
    for ([_][]const u8{ "auto", "url(a) none", "url(a), url(b)" }) |input| {
        const value = try parse(testing.allocator, "list-style-image", input, null);
        defer if (value) |v| v.release();
        try testing.expect(value == null);
    }
}

test "cursor retains source, order, fragment and empty resource flags" {
    const source = try css.style_values.ResourceSource.create(testing.allocator, .{ .base_url = "https://example.test/a.css", .referrer_policy = "no-referrer" });
    const value = (try parse(testing.allocator, "cursor", "url(a), url('') 1 2, url(#local), copy", source)) orelse {
        source.unref();
        return error.MissingCursor;
    };
    source.unref();
    defer value.release();
    const retained = value;
    retained.retain();
    defer retained.release();
    const urls = retained.resourceUrls();
    try testing.expectEqual(@as(usize, 3), urls.len);
    try testing.expectEqualStrings("a", urls[0].url);
    try testing.expectEqualStrings("no-referrer", urls[0].source.?.referrer_policy);
    try testing.expect(urls[0].valid);
    try testing.expect(!urls[1].valid);
    try testing.expect(urls[2].local_fragment);
    try testing.expect(urls[0].range.end < urls[1].range.start);
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/" });
    defer source.unref();
    const value = (try parse(allocator, "cursor", "url(a) 2 3, url(b), move", source)) orelse return error.MissingCursor;
    defer value.release();
    const invalid = try parse(allocator, "cursor", "url(a) 2 3, url(b), move extra", source);
    defer if (invalid) |v| v.release();
    try testing.expect(invalid == null);
}

test "cursor cleanup survives allocation failures and trailing invalid tokens" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailures, .{});
}

test "cursor value equality does not erase distinct URL provenance" {
    const one = try css.style_values.ResourceSource.create(testing.allocator, .{ .base_url = "https://example.test/one.css", .referrer_policy = "no-referrer" });
    defer one.unref();
    const two = try css.style_values.ResourceSource.create(testing.allocator, .{ .base_url = "https://example.test/two.css", .referrer_policy = "origin" });
    defer two.unref();
    const a = (try parse(testing.allocator, "cursor", "url(a), copy", one)) orelse return error.MissingCursor;
    defer a.release();
    const b = (try parse(testing.allocator, "cursor", "url(a), copy", two)) orelse return error.MissingCursor;
    defer b.release();
    try testing.expect(a.eql(b));
    try testing.expect(!a.resourcesEql(b));
}
