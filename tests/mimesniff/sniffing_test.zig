//! Tests migrated from src/mimesniff/sniffing.zig
//! Per WHATWG specifications

const std = @import("std");
const infra = @import("infra");

const mimesniff = @import("mimesniff");

test "identifyUnknownMimeType - HTML detection" {
    const allocator = std.testing.allocator;

    const resource_header = "<!DOCTYPE HTML >"; // Space before > is tag-terminating
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - PNG detection" {
    const allocator = std.testing.allocator;

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("image/png", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - text/plain for no binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "Hello, World!";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        const essence = try mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/plain", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - application/octet-stream for binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "\x00\x01\x02\x03\x04";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        const essence = try mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("application/octet-stream", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - UTF-16BE BOM" {
    const allocator = std.testing.allocator;

    const resource_header = "\xFE\xFF\x00\x48"; // UTF-16BE BOM + "H"
    const computed = try mimesniff.distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/plain", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - UTF-8 BOM" {
    const allocator = std.testing.allocator;

    const resource_header = "\xEF\xBB\xBFHello";
    const computed = try mimesniff.distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/plain", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - no binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "Plain text content";
    const computed = try mimesniff.distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/plain", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - with binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "\x00\x01\x02Binary";
    const computed = try mimesniff.distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("application/octet-stream", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInPluginContext - undefined returns octet-stream" {
    const allocator = std.testing.allocator;

    const computed = try mimesniff.sniffInPluginContext(allocator, null);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("application/octet-stream", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInTextTrackContext - returns text/vtt" {
    const allocator = std.testing.allocator;

    const computed = try mimesniff.sniffInTextTrackContext(allocator);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/vtt", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInCacheManifestContext - returns text/cache-manifest" {
    const allocator = std.testing.allocator;

    const computed = try mimesniff.sniffInCacheManifestContext(allocator);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/cache-manifest", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <H1> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<h1 >Header";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <DIV> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<div >Content";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <FONT> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<font >Text";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <TABLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<table >";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <A> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<a >Link";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <STYLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<style >";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <TITLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<title >";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <B> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<b >Bold";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <BODY> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<body >";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <BR> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<br >";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <P> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<p >Paragraph";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML comment" {
    const allocator = std.testing.allocator;

    const resource_header = "<!-- Comment";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML with leading whitespace" {
    const allocator = std.testing.allocator;

    const resource_header = "  \t\n<html >";
    const computed = try mimesniff.identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try mutable_mt.essence(allocator);
        defer allocator.free(essence);
        const essence_utf8 = try infra.bytes.isomorphicEncode(allocator, essence);
        defer allocator.free(essence_utf8);

        try std.testing.expectEqualStrings("text/html", essence_utf8);
    } else {
        try std.testing.expect(false);
    }
}