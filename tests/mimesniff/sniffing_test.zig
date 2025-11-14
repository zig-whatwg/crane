//! Tests migrated from src/mimesniff/sniffing.zig
//! Per WHATWG specifications

const std = @import("std");

const mimesniff = @import("mimesniff");
const source = @import("../../src/mimesniff/sniffing.zig");

test "sniffMimeType - XML MIME type returns supplied" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "application/xml")).?;

    const resource_header = "<xml>";
    const computed = try sniffMimeType(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/xml", essence);
    } else {
        try std.testing.expect(false); // Should not be null
    }
}
test "sniffMimeType - HTML MIME type returns supplied" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "text/html")).?;

    const resource_header = "<html>";
    const computed = try sniffMimeType(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffMimeType - no-sniff flag returns supplied" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "text/plain")).?;
    res.no_sniff = true;

    // Resource header is PNG, but no-sniff should prevent sniffing
    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A";
    const computed = try sniffMimeType(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML detection" {
    const allocator = std.testing.allocator;

    const resource_header = "<!DOCTYPE HTML >"; // Space before > is tag-terminating
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - PNG detection" {
    const allocator = std.testing.allocator;

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A";
    const computed = try identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("image/png", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - text/plain for no binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "Hello, World!";
    const computed = try identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        const essence = try getEssence(allocator, &mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - application/octet-stream for binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "\x00\x01\x02\x03\x04";
    const computed = try identifyUnknownMimeType(allocator, resource_header, false);

    if (computed) |mt| {
        const essence = try getEssence(allocator, &mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/octet-stream", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - UTF-16BE BOM" {
    const allocator = std.testing.allocator;

    const resource_header = "\xFE\xFF\x00\x48"; // UTF-16BE BOM + "H"
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - UTF-8 BOM" {
    const allocator = std.testing.allocator;

    const resource_header = "\xEF\xBB\xBFHello";
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - no binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "Plain text content";
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/plain", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "distinguishTextOrBinary - with binary data" {
    const allocator = std.testing.allocator;

    const resource_header = "\x00\x01\x02Binary";
    const computed = try distinguishTextOrBinary(allocator, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/octet-stream", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "containsBinaryDataBytes - true for binary data" {
    try std.testing.expect(containsBinaryDataBytes("\x00\x01\x02"));
    try std.testing.expect(containsBinaryDataBytes("\x0B")); // VT
    try std.testing.expect(containsBinaryDataBytes("Hello\x00World"));
}
test "containsBinaryDataBytes - false for text data" {
    try std.testing.expect(!containsBinaryDataBytes("Hello, World!"));
    try std.testing.expect(!containsBinaryDataBytes("Text\x0A")); // LF is not binary data byte
    try std.testing.expect(!containsBinaryDataBytes(""));
}
test "sniffInImageContext - XML MIME type returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "image/svg+xml")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A"; // PNG signature
    const computed = try sniffInImageContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        // Should return supplied (SVG+XML), not sniffed (PNG)
        try std.testing.expectEqualStrings("image/svg+xml", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInImageContext - pattern matching" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "image/unknown")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "\x89PNG\x0D\x0A\x1A\x0A"; // PNG signature
    const computed = try sniffInImageContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("image/png", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInAudioOrVideoContext - pattern matching" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "audio/unknown")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "ID3"; // MP3 with ID3
    const computed = try sniffInAudioOrVideoContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("audio/mpeg", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInFontContext - pattern matching" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "font/unknown")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const resource_header = "wOFF"; // WOFF signature
    const computed = try sniffInFontContext(allocator, supplied, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("font/woff", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInPluginContext - undefined returns octet-stream" {
    const allocator = std.testing.allocator;

    const computed = try sniffInPluginContext(allocator, null);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/octet-stream", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInPluginContext - supplied returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "application/x-custom")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const computed = try sniffInPluginContext(allocator, supplied);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("application/x-custom", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInStyleContext - returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "text/css")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const computed = try sniffInStyleContext(allocator, supplied);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/css", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInScriptContext - returns supplied" {
    const allocator = std.testing.allocator;

    const supplied = (try mime_type.parseMimeType(allocator, "text/javascript")).?;
    defer {
        var mt = supplied;
        mt.deinit();
    }

    const computed = try sniffInScriptContext(allocator, supplied);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/javascript", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInTextTrackContext - returns text/vtt" {
    const allocator = std.testing.allocator;

    const computed = try sniffInTextTrackContext(allocator);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/vtt", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInCacheManifestContext - returns text/cache-manifest" {
    const allocator = std.testing.allocator;

    const computed = try sniffInCacheManifestContext(allocator);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/cache-manifest", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <H1> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<h1 >Header";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <DIV> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<div >Content";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <FONT> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<font >Text";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <TABLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<table >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <A> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<a >Link";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <STYLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<style >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <TITLE> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<title >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <B> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<b >Bold";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <BODY> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<body >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <BR> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<br >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML <P> tag" {
    const allocator = std.testing.allocator;

    const resource_header = "<p >Paragraph";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML comment" {
    const allocator = std.testing.allocator;

    const resource_header = "<!-- Comment";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "identifyUnknownMimeType - HTML with leading whitespace" {
    const allocator = std.testing.allocator;

    const resource_header = "  \t\n<html >";
    const computed = try identifyUnknownMimeType(allocator, resource_header, true);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}
test "sniffInBrowsingContext - delegates to sniffMimeType" {
    const allocator = std.testing.allocator;

    var res = Resource.init(allocator);
    defer res.deinit();

    res.supplied_mime_type = (try mime_type.parseMimeType(allocator, "text/html")).?;

    const resource_header = "<html>";
    const computed = try sniffInBrowsingContext(allocator, &res, resource_header);

    if (computed) |mt| {
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const essence = try getEssence(allocator, &mutable_mt);
        defer allocator.free(essence);

        try std.testing.expectEqualStrings("text/html", essence);
    } else {
        try std.testing.expect(false);
    }
}