//! CSS Values 4 4.5: resource provenance belongs to the retained value.
const std = @import("std");
const css = @import("css");
const values = css.style_values;
const testing = std.testing;

test "resource values keep distinct source metadata without changing CSS text equality" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.sources();
    return error.ResourceProvenanceNotImplemented;
}

test "resource URLs retain relative resolution, fragment flags and serialization ranges" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.urlResolution();
    return error.ResourceProvenanceNotImplemented;
}

test "empty and failed URL resolution are invalid resources with unchanged serialization" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.invalidUrls();
    return error.ResourceProvenanceNotImplemented;
}

test "nested images and background shorthand retain every occurrence in order" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.multiple();
    return error.ResourceProvenanceNotImplemented;
}

test "computed values own provenance after sheets and parents are released" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.lifetime();
    return error.ResourceProvenanceNotImplemented;
}

test "content attr substitution preserves URL provenance and updates ranges" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.content();
    return error.ResourceProvenanceNotImplemented;
}

test "CSSOM replacement preserves the new resource source even for identical text" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.replacement();
    return error.ResourceProvenanceNotImplemented;
}

test "non-resource values and unsupported variable substitution keep their existing behavior" {
    if (comptime @hasDecl(values, "ResourceSource")) return Checks.nonResources();
    return error.ResourceProvenanceNotImplemented;
}

test "resource ownership unwinds on allocation failure and malformed content" {
    if (comptime @hasDecl(values, "ResourceSource")) return testing.checkAllAllocationFailures(testing.allocator, Checks.allocationFailures, .{});
    return error.ResourceProvenanceNotImplemented;
}

const Checks = struct {
    const Source = values.ResourceSource;
    const Block = css.declarations.DeclarationBlock;

    fn source(policy: []const u8) !*Source {
        return Source.create(testing.allocator, .{
            .base_url = "https://example.test/css/main.css",
            .referrer = "https://example.test/css/main.css",
            .referrer_policy = policy,
            .origin_clean = true,
        });
    }

    // The parser's pre-existing resolver seam still owns URL parsing. This
    // deterministic resolver tests that provenance never re-resolves a value.
    const Resolver = struct {
        fn resolve(_: *const anyopaque, allocator: std.mem.Allocator, raw: []const u8) ?[]u8 {
            if (std.mem.eql(u8, raw, "bad[")) return null;
            if (raw.len == 0) return allocator.dupe(u8, "https://example.test/css/main.css") catch null;
            if (std.mem.startsWith(u8, raw, "https:")) return allocator.dupe(u8, raw) catch null;
            const prefix = if (std.mem.startsWith(u8, raw, "#")) "https://example.test/css/main.css" else "https://example.test/css/";
            return std.mem.concat(allocator, u8, &.{ prefix, raw }) catch null;
        }
    };

    fn options(s: *Source) css.properties.ParseOptions {
        return .{ .allocator = testing.allocator, .resource_source = s, .url_resolver = .{ .context = s, .resolve = Resolver.resolve } };
    }

    fn value(opts: css.properties.ParseOptions, name: []const u8, text: []const u8) !values.Value {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer assignments.deinit(opts.allocator);
        errdefer for (assignments.items) |assignment| assignment.value.release();
        try testing.expect(try css.properties.parseDeclaration(opts, css.properties.lookup(name).?, text, &assignments));
        const kept = assignments.items[0].value.value;
        for (assignments.items[1..]) |assignment| assignment.value.release();
        return kept;
    }

    fn sources() !void {
        const a = try source("no-referrer");
        defer a.unref();
        const b = try source("strict-origin");
        defer b.unref();
        const first = try value(options(a), "background-image", "url(https://images.test/p.png)");
        defer first.release();
        const second = try value(options(b), "background-image", "url(https://images.test/p.png)");
        defer second.release();
        try testing.expect(first.eql(second));
        try testing.expect(!first.resourcesEql(second));
        try testing.expectEqualStrings("no-referrer", first.resourceUrls()[0].source.?.referrer_policy);
        try testing.expectEqualStrings("strict-origin", second.resourceUrls()[0].source.?.referrer_policy);
        try testing.expectEqualStrings("url(\"https://images.test/p.png\")", first.text.bytes);
        const clone = first;
        clone.retain();
        defer clone.release();
        try testing.expect(first.resourcesEql(clone));
        var base_input = "https://example.test/owned.css".*;
        var referrer_input = "https://example.test/referrer.css".*;
        var policy_input = "no-referrer".*;
        const owned = try Source.create(testing.allocator, .{ .base_url = &base_input, .referrer = &referrer_input, .referrer_policy = &policy_input, .origin_clean = false });
        defer owned.unref();
        @memset(&base_input, 'x');
        @memset(&referrer_input, 'x');
        @memset(&policy_input, 'x');
        try testing.expectEqualStrings("https://example.test/owned.css", owned.base_url);
        try testing.expectEqualStrings("https://example.test/referrer.css", owned.referrer.?);
        try testing.expectEqualStrings("no-referrer", owned.referrer_policy);
        try testing.expect(!owned.origin_clean);
    }

    fn urlResolution() !void {
        const s = try source("");
        defer s.unref();
        const relative = try value(options(s), "background-image", "url(p\\69 c.png)");
        defer relative.release();
        try testing.expectEqual(@as(usize, 1), relative.resourceUrls().len);
        const r = relative.resourceUrls()[0];
        try testing.expectEqualStrings("https://example.test/css/pic.png", r.url);
        try testing.expect(!r.local_fragment);
        try testing.expect(r.valid);
        try testing.expectEqualStrings(relative.text.bytes, relative.text.bytes[r.range.start..r.range.end]);
        const fragment = try value(options(s), "background-image", "url(\\23 icon)");
        defer fragment.release();
        try testing.expect(fragment.resourceUrls()[0].local_fragment);
        // The existing resolver and serialization are unchanged. The local
        // flag, not a comparison with the sheet URL, decides fetch eligibility.
        // Re-parsing BASE's absolute serialization cannot recover this flag;
        // that pre-existing literal-string round-trip limit is separate (Q9).
        try testing.expectEqualStrings("url(\"https://example.test/css/main.css#icon\")", fragment.text.bytes);
        const bare = try value(.{ .allocator = testing.allocator }, "background-image", "src('relative.svg')");
        defer bare.release();
        try testing.expect(bare.resourceUrls()[0].source == null);
        try testing.expectEqualStrings("relative.svg", bare.resourceUrls()[0].url);
    }

    fn invalidUrls() !void {
        const s = try source("");
        defer s.unref();
        const empty = try value(options(s), "background-image", "url('')");
        defer empty.release();
        const missing = empty.resourceUrls()[0];
        try testing.expect(!missing.valid);
        try testing.expect(!missing.local_fragment);
        try testing.expectEqualStrings("", missing.url);
        try testing.expectEqualStrings("url(\"https://example.test/css/main.css\")", empty.text.bytes);
        const failure = try value(options(s), "background-image", "url('bad[')");
        defer failure.release();
        try testing.expect(!failure.resourceUrls()[0].valid);
        try testing.expectEqualStrings("bad[", failure.resourceUrls()[0].url);
        try testing.expectEqualStrings("url(\"bad[\")", failure.text.bytes);
    }

    fn multiple() !void {
        const s = try source("same-origin");
        defer s.unref();
        const spelling = "image-set(url('one.png') 1x, \"two.png\" 2x, linear-gradient(red, blue) 3x)";
        const nested = try value(options(s), "background-image", spelling);
        defer nested.release();
        try testing.expectEqualStrings(spelling, nested.text.bytes);
        const urls = nested.resourceUrls();
        try testing.expectEqual(@as(usize, 2), urls.len);
        try testing.expectEqualStrings("https://example.test/css/one.png", urls[0].url);
        try testing.expectEqualStrings("https://example.test/css/two.png", urls[1].url);
        try testing.expectEqualStrings("url('one.png')", spelling[urls[0].range.start..urls[0].range.end]);
        try testing.expectEqualStrings("\"two.png\"", spelling[urls[1].range.start..urls[1].range.end]);
        var block = try Block.parse(options(s), "background: url(a.png), image-set(url(#local) 1x, url(b.png) 2x) red;");
        defer block.deinit();
        const image = block.get(.background_image).?.value.value;
        try testing.expectEqual(@as(usize, 3), image.resourceUrls().len);
        try testing.expect(image.resourceUrls()[1].local_fragment);
        // The declaration-list serializer already quotes unquoted URL tokens.
        try testing.expectEqualStrings("url(\"#local\")", image.text.bytes[image.resourceUrls()[1].range.start..image.resourceUrls()[1].range.end]);
        // A value can combine occurrences produced under different policies.
        const other = try source("origin");
        defer other.unref();
        const second = try value(options(other), "background-image", "url(c.png)");
        defer second.release();
        const combined = try std.mem.concat(testing.allocator, u8, &.{ image.text.bytes, ", ", second.text.bytes });
        defer testing.allocator.free(combined);
        var last = second.resourceUrls()[0];
        last.range.start += image.text.bytes.len + 2;
        last.range.end += image.text.bytes.len + 2;
        const joined = try values.SharedText.createWithResources(testing.allocator, combined, &.{ image.resourceUrls()[0], last });
        defer joined.unref();
        try testing.expect(joined.resource_urls[0].source == s);
        try testing.expect(joined.resource_urls[1].source == other);
    }

    fn inheritedAfterRelease(wide: []const u8) !values.Value {
        const s = try source("origin");
        defer s.unref();
        var parent_block = try Block.parse(options(s), "background-image: url(p.png)");
        defer parent_block.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var block = try Block.parse(.{ .allocator = testing.allocator }, "background-image: inherit");
        defer block.deinit();
        var author = Block.init(testing.allocator);
        defer author.deinit();
        _ = try author.setProperty(.{ .allocator = testing.allocator }, "background-image", wide, "");
        const computed = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{
            .{ .block = &block, .source = .{ .origin = .user } },
            .{ .block = &author, .source = .{ .origin = .author } },
        });
        defer computed.destroy();
        const retained = computed.get(.background_image);
        retained.retain();
        return retained;
    }

    fn lifetime() !void {
        for ([_][]const u8{ "inherit", "revert" }) |wide| {
            const retained = try inheritedAfterRelease(wide);
            defer retained.release();
            try testing.expectEqualStrings("origin", retained.resourceUrls()[0].source.?.referrer_policy);
            try testing.expectEqualStrings("https://example.test/css/p.png", retained.resourceUrls()[0].url);
        }
        const initial = try inheritedAfterRelease("unset");
        defer initial.release();
        try testing.expectEqual(@as(usize, 0), initial.resourceUrls().len);
    }

    fn content() !void {
        const s = try source("no-referrer");
        defer s.unref();
        const specified = try value(options(s), "content", "attr(data-label, 'a long label') url(#icon) image-set(url(a.png) 1x, 'b.png' 2x)");
        defer specified.release();
        const computed_content = (try specified.content.compute(testing.allocator, null)).?;
        const computed: values.Value = .{ .content = computed_content };
        defer computed.release();
        const urls = computed.resourceUrls();
        try testing.expectEqual(@as(usize, 3), urls.len);
        try testing.expect(urls[0].local_fragment);
        try testing.expectEqualStrings("url(\"https://example.test/css/main.css#icon\")", computed_content.serialization[urls[0].range.start..urls[0].range.end]);
        try testing.expectEqualStrings("no-referrer", urls[2].source.?.referrer_policy);
        const counter = try value(options(s), "content", "counter(item, symbols(url(#marker) 'x'))");
        defer counter.release();
        try testing.expectEqual(@as(usize, 1), counter.resourceUrls().len);
        try testing.expect(counter.resourceUrls()[0].local_fragment);
    }

    fn replacement() !void {
        const a = try source("no-referrer");
        defer a.unref();
        const b = try source("origin");
        defer b.unref();
        var block = try Block.parse(options(a), "background-image: url(https://images.test/p.png)");
        defer block.deinit();
        const old = block.get(.background_image).?.value.value;
        old.retain();
        defer old.release();
        try testing.expect(try block.setProperty(options(b), "background-image", "url(https://images.test/p.png)", ""));
        const new = block.get(.background_image).?.value.value;
        try testing.expect(new.resourceUrls()[0].source == b);
        try testing.expect(!old.resourcesEql(new));
        var serialized: std.ArrayList(u8) = .empty;
        defer serialized.deinit(testing.allocator);
        try block.getPropertyValue("background-image", &serialized);
        var round_trip = Block.init(testing.allocator);
        defer round_trip.deinit();
        _ = try round_trip.setProperty(options(b), "background-image", serialized.items, "");
        try testing.expect(new.resourcesEql(round_trip.get(.background_image).?.value.value));
    }

    fn nonResources() !void {
        const s = try source("");
        defer s.unref();
        const color = try value(options(s), "color", "red");
        defer color.release();
        try testing.expectEqual(@as(usize, 0), color.resourceUrls().len);
        var block = try Block.parse(options(s), "--image: url(a.png); background-image: var(--image); width: calc(2px + 1px); padding-top: env(safe-area-inset-top)");
        defer block.deinit();
        try testing.expect(block.get(.background_image) == null);
        try testing.expect(block.get(.width) == null);
        try testing.expect(block.get(.padding_top) == null);
        try testing.expectEqual(@as(usize, 1), block.length());
        const literal = try value(options(s), "content", "'url(fake.png)' attr(label, 'url(also-fake.png)')");
        defer literal.release();
        try testing.expectEqual(@as(usize, 0), literal.resourceUrls().len);
        const typed = try value(options(s), "background-image", "image-set(/*url(fake)*/ url(real.png) type('image/png') 1x)");
        defer typed.release();
        try testing.expectEqual(@as(usize, 1), typed.resourceUrls().len);
        try testing.expectEqualStrings("https://example.test/css/real.png", typed.resourceUrls()[0].url);
    }

    fn allocationFailures(allocator: std.mem.Allocator) !void {
        const s = try Source.create(allocator, .{ .base_url = "https://example.test/a.css", .referrer = "https://example.test/a.css", .referrer_policy = "no-referrer", .origin_clean = false });
        defer s.unref();
        const opts: css.properties.ParseOptions = .{ .allocator = allocator, .resource_source = s };
        for ([_][]const u8{ "url(a.png)", "image-set(url(a.png) 1x, 'b.png' 2x)", "attr(label, 'longer') url(#a)", "counter(x, symbols(url(#a) 'b'))", "url(a.png) invalid" }) |spelling| {
            var assignments: std.ArrayList(css.properties.Assignment) = .empty;
            defer {
                for (assignments.items) |assignment| assignment.value.release();
                assignments.deinit(allocator);
            }
            _ = try css.properties.parseDeclaration(opts, css.properties.lookup("content").?, spelling, &assignments);
            if (assignments.items.len != 0) {
                const computed = try assignments.items[0].value.value.content.compute(allocator, null);
                if (computed) |c| c.unref();
            }
        }
        for ([_][]const u8{ "url(a.png), image-set(url(#a) 1x, 'b.png' 2x)", "url(a.png)," }) |spelling| {
            var assignments: std.ArrayList(css.properties.Assignment) = .empty;
            defer {
                for (assignments.items) |assignment| assignment.value.release();
                assignments.deinit(allocator);
            }
            _ = try css.properties.parseDeclaration(opts, css.properties.lookup("background").?, spelling, &assignments);
        }
    }
};
