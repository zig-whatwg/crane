//! Scheme fetch "file" (Fetch 4.3): "For now, unfortunate as it is, file:
//! URLs are left as an exercise for the reader. When in doubt, return a
//! network error." Crane answers as the three browsers do, through the
//! platform's file access (capability `file_urls`; unsupported: a network
//! error, the spec's path):
//!
//! - WHO may fetch a file: URL: a request whose client is a local document
//!   (`InternalRequest.local_file_access`: a file: document, or a srcdoc
//!   document inside one) or one with no client at all. A web page's request
//!   for a file: URL is a network error - Blink's SecurityOrigin::CanDisplay
//!   lets only an origin that CanLoadLocalResources (a file: origin) display a
//!   local URL ("Not allowed to load local resource"); Gecko's
//!   nsScriptSecurityManager::CheckLoadURIWithPrincipal refuses a file: URL to
//!   a non-file principal (URI_IS_LOCAL_FILE); WebKit's
//!   SecurityOrigin::canDisplay the same through its local scheme registry.
//! - WHAT it gets: the file's bytes, status 200 "OK", and its MIME type from
//!   its extension - the only supplied type a local file has (MIME Sniffing
//!   "determine the supplied MIME type"; Chromium net::GetMimeTypeFromFile,
//!   Gecko nsMIMEService by extension). A directory, a missing file or an
//!   unreadable one is a network error, as in all three (net::ERR_FILE_NOT_FOUND).
//! - Main fetch decides the rest unchanged: a file: URL is not same origin
//!   with anything (its origin is opaque), so a no-cors request gets an
//!   opaque-filtered response - what a file: page's <script src>, <link
//!   rel=stylesheet> and <img> load in every browser - and a cors request
//!   (fetch(), XMLHttpRequest) a network error at main fetch step 12, as
//!   Chrome's "Cross origin requests are only supported for protocol schemes"
//!   without --allow-file-access-from-files.
//!
//! The navigation of a document to a file: URL reads it through the same
//! `read` (html/navigation/fetch_integration.zig handleFileUrl).

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");

/// The largest local file a subresource fetch reads (a script, a
/// stylesheet, an image): beyond it, a network error. A navigation passes
/// its own (fetch_integration.zig max_file_navigation_bytes).
pub const max_file_bytes: usize = 64 * 1024 * 1024;

/// Whether the platform reads local files at all (capability `file_urls`).
pub const supported = platform.capabilities.file_urls != .unsupported;

/// What reading a file: URL gave.
pub const Read = union(enum) {
    /// The file's bytes and its decoded path, both OWNED by the allocator
    /// `read` took, and its MIME type (static).
    file: struct { bytes: []u8, mime_type: []const u8, path: []u8 },
    /// No such file, a directory, one that could not be read or is over the
    /// limit: Fetch's network error, a navigation's 404.
    not_found,
    /// The URL names a host other than the local one (or no path): Fetch's
    /// network error, a navigation's 400.
    bad_host,
};

/// Read the file `url` (a file: URL, serialized) names, at most `limit`
/// bytes of it. OWNED results.
pub fn read(allocator: Allocator, url: []const u8, limit: usize) Allocator.Error!Read {
    if (!supported) return .not_found;
    const path = (try pathOf(allocator, url)) orelse return .bad_host;
    errdefer allocator.free(path);
    const bytes = platform.readFile(allocator, platform.Str.from(path), limit) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            allocator.free(path);
            return .not_found;
        },
    };
    return .{ .file = .{ .bytes = bytes, .mime_type = contentTypeFromPath(path), .path = path } };
}

/// The local path a file: URL names, percent-decoded, OWNED; null for a URL
/// whose host is neither empty nor "localhost" (a file on another machine,
/// which Crane does not reach). The query and fragment are no part of it.
pub fn pathOf(allocator: Allocator, url: []const u8) Allocator.Error!?[]u8 {
    if (!std.ascii.startsWithIgnoreCase(url, "file:")) return null;
    const after_scheme = url["file:".len..];
    const raw_path = if (std.mem.startsWith(u8, after_scheme, "//")) blk: {
        const authority_and_path = after_scheme[2..];
        const slash = std.mem.indexOfScalar(u8, authority_and_path, '/') orelse return null;
        const authority = authority_and_path[0..slash];
        if (authority.len != 0 and !std.ascii.eqlIgnoreCase(authority, "localhost")) return null;
        break :blk authority_and_path[slash..];
    } else after_scheme;
    const path_end = std.mem.indexOfAny(u8, raw_path, "?#") orelse raw_path.len;
    return try percentDecode(allocator, raw_path[0..path_end]);
}

/// The supplied MIME type of a local file, from its extension. Unknown
/// extensions get "application/octet-stream", which routes to external
/// software rather than being guessed at.
pub fn contentTypeFromPath(path: []const u8) []const u8 {
    const table = [_]struct { ext: []const u8, mime: []const u8 }{
        .{ .ext = ".html", .mime = "text/html" },
        .{ .ext = ".htm", .mime = "text/html" },
        .{ .ext = ".xhtml", .mime = "application/xhtml+xml" },
        .{ .ext = ".xml", .mime = "text/xml" },
        .{ .ext = ".svg", .mime = "image/svg+xml" },
        .{ .ext = ".css", .mime = "text/css" },
        .{ .ext = ".js", .mime = "text/javascript" },
        .{ .ext = ".mjs", .mime = "text/javascript" },
        .{ .ext = ".json", .mime = "application/json" },
        .{ .ext = ".txt", .mime = "text/plain" },
        .{ .ext = ".vtt", .mime = "text/vtt" },
        .{ .ext = ".png", .mime = "image/png" },
        .{ .ext = ".gif", .mime = "image/gif" },
        .{ .ext = ".jpg", .mime = "image/jpeg" },
        .{ .ext = ".jpeg", .mime = "image/jpeg" },
        .{ .ext = ".bmp", .mime = "image/bmp" },
        .{ .ext = ".webp", .mime = "image/webp" },
        .{ .ext = ".ico", .mime = "image/vnd.microsoft.icon" },
        .{ .ext = ".wasm", .mime = "application/wasm" },
        .{ .ext = ".mp4", .mime = "video/mp4" },
        .{ .ext = ".webm", .mime = "video/webm" },
        .{ .ext = ".ogg", .mime = "audio/ogg" },
        .{ .ext = ".mp3", .mime = "audio/mpeg" },
        .{ .ext = ".wav", .mime = "audio/wav" },
    };
    for (table) |row| {
        if (std.ascii.endsWithIgnoreCase(path, row.ext)) return row.mime;
    }
    return "application/octet-stream";
}

/// URL "percent-decode" (URL Standard 1.3): "%" and two hex digits is that
/// byte; every other byte stays. OWNED.
fn percentDecode(allocator: Allocator, input: []const u8) Allocator.Error![]u8 {
    var out = try allocator.alloc(u8, input.len);
    var n: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |byte| {
                out[n] = byte;
                n += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        out[n] = input[i];
        n += 1;
        i += 1;
    }
    return allocator.realloc(out, n) catch out[0..n];
}

test "pathOf: an empty or localhost host, percent-decoded, without query or fragment" {
    const a = std.testing.allocator;
    const p1 = (try pathOf(a, "file:///tmp/a%20b.js?x=1#y")).?;
    defer a.free(p1);
    try std.testing.expectEqualStrings("/tmp/a b.js", p1);
    const p2 = (try pathOf(a, "file://localhost/etc/hosts")).?;
    defer a.free(p2);
    try std.testing.expectEqualStrings("/etc/hosts", p2);
    try std.testing.expectEqual(@as(?[]u8, null), try pathOf(a, "file://server/share/x"));
    try std.testing.expectEqual(@as(?[]u8, null), try pathOf(a, "https://example.com/x"));
}

test "contentTypeFromPath: by extension, octet-stream otherwise" {
    try std.testing.expectEqualStrings("text/javascript", contentTypeFromPath("/a/vue.global.js"));
    try std.testing.expectEqualStrings("text/css", contentTypeFromPath("/a/INDEX.CSS"));
    try std.testing.expectEqualStrings("application/octet-stream", contentTypeFromPath("/a/b"));
}
