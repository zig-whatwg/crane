//! WHATWG Resource Handling
//!
//! Spec: https://mimesniff.spec.whatwg.org/#handling-a-resource
//!
//! This module implements resource metadata tracking and the supplied MIME type
//! detection algorithm as defined in the WHATWG MIME Sniffing Standard §5.

const std = @import("std");
const mime_type = @import("mime_type.zig");
const MimeType = mime_type.MimeType;

/// Resource metadata (WHATWG MIME Sniffing §5)
///
/// For each resource it handles, the user agent must keep track of
/// the following associated metadata:
/// - supplied MIME type
/// - check-for-apache-bug flag
/// - no-sniff flag
/// - computed MIME type
///
/// Spec: https://mimesniff.spec.whatwg.org/#handling-a-resource
pub const Resource = struct {
    /// Supplied MIME type (may be undefined/null)
    supplied_mime_type: ?MimeType,

    /// Check-for-apache-bug flag (defaults to unset/false)
    check_for_apache_bug: bool,

    /// No-sniff flag (defaults to set/true if no sniffing desired)
    no_sniff: bool,

    /// Computed MIME type (determined by sniffing algorithm)
    computed_mime_type: ?MimeType,

    /// Allocator for memory management
    allocator: std.mem.Allocator,

    /// Initialize a new resource with default flags
    pub fn init(allocator: std.mem.Allocator) Resource {
        return .{
            .supplied_mime_type = null,
            .check_for_apache_bug = false,
            .no_sniff = false, // Default to allow sniffing
            .computed_mime_type = null,
            .allocator = allocator,
        };
    }

    /// Free all allocated memory
    pub fn deinit(self: *Resource) void {
        if (self.supplied_mime_type) |*mt| {
            var mutable_mt = mt.*;
            mutable_mt.deinit();
        }
        if (self.computed_mime_type) |*mt| {
            var mutable_mt = mt.*;
            mutable_mt.deinit();
        }
    }
};

/// Apache bug MIME types that trigger check-for-apache-bug flag
///
/// These exact byte sequences are checked because some older installations
/// of Apache contain a bug that causes them to supply these Content-Type
/// headers when serving files with unrecognized MIME types.
///
/// Spec: https://mimesniff.spec.whatwg.org/#supplied-mime-type-detection-algorithm
const APACHE_BUG_TYPES = [_][]const u8{
    "text/plain",
    "text/plain; charset=ISO-8859-1",
    "text/plain; charset=iso-8859-1",
    "text/plain; charset=UTF-8",
};

/// Determine the supplied MIME type of a resource (WHATWG MIME Sniffing §5.1)
///
/// The supplied MIME type of a resource is provided to the user agent by
/// an external source associated with that resource. For HTTP resources,
/// this is the Content-Type header.
///
/// This function implements the "supplied MIME type detection algorithm".
///
/// Parameters:
///   - allocator: Memory allocator
///   - content_type: Content-Type header value (for HTTP) or null
///
/// Returns: A Resource with supplied_mime_type and check_for_apache_bug flag set
///
/// Spec: https://mimesniff.spec.whatwg.org/#supplied-mime-type-detection-algorithm
pub fn determineSuppliedMimeType(
    allocator: std.mem.Allocator,
    content_type: ?[]const u8,
) !Resource {
    var resource = Resource.init(allocator);

    // 1. Let supplied-type be null
    // (Already initialized as null)

    // 2. If the resource is retrieved via HTTP
    if (content_type) |ct| {
        // 2.1. If one or more Content-Type headers are associated with the resource
        // (We assume the last Content-Type header is provided)

        // 2.1.1. Set supplied-type to the value of the last Content-Type header
        const supplied_type = ct;

        // 2.1.2. Set the check-for-apache-bug flag if supplied-type matches
        for (APACHE_BUG_TYPES) |apache_type| {
            if (std.mem.eql(u8, supplied_type, apache_type)) {
                resource.check_for_apache_bug = true;
                break;
            }
        }

        // Parse the MIME type
        const parsed = try mime_type.parseMimeType(allocator, supplied_type);
        resource.supplied_mime_type = parsed;
    }

    // 3. If the resource is retrieved directly from the file system
    // This is handled by determineSuppliedMimeTypeFromPath (see below)

    // 4. If the resource is retrieved via another protocol (FTP, etc.)
    // This is handled by the protocol-specific implementation

    // 5. If supplied-type is not a MIME type, the supplied MIME type is undefined
    // (Handled by parseMimeType returning null on failure)

    // 6. The supplied MIME type is supplied-type
    return resource;
}

/// Determine the supplied MIME type from a file path (WHATWG MIME Sniffing §5.1)
///
/// For resources retrieved directly from the file system, this determines
/// the MIME type based on the file extension. This is a platform-specific
/// operation, but we provide a common implementation based on standard
/// file extensions.
///
/// Parameters:
///   - allocator: Memory allocator
///   - file_path: Path to the file
///
/// Returns: A Resource with supplied_mime_type set based on file extension
///
/// Spec: https://mimesniff.spec.whatwg.org/#supplied-mime-type-detection-algorithm
pub fn determineSuppliedMimeTypeFromPath(
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !Resource {
    var resource = Resource.init(allocator);

    // Extract file extension
    const extension = std.fs.path.extension(file_path);
    if (extension.len == 0) {
        return resource; // No extension, no MIME type
    }

    // Map common file extensions to MIME types
    const mime_type_str = getMimeTypeForExtension(extension);
    if (mime_type_str) |type_str| {
        const parsed = try mime_type.parseMimeType(allocator, type_str);
        resource.supplied_mime_type = parsed;
    }

    return resource;
}

/// Get MIME type for a file extension
///
/// This maps common file extensions to their corresponding MIME types.
/// Based on common file type associations used by operating systems.
fn getMimeTypeForExtension(extension: []const u8) ?[]const u8 {
    // Common text formats
    if (std.ascii.eqlIgnoreCase(extension, ".txt")) return "text/plain";
    if (std.ascii.eqlIgnoreCase(extension, ".html")) return "text/html";
    if (std.ascii.eqlIgnoreCase(extension, ".htm")) return "text/html";
    if (std.ascii.eqlIgnoreCase(extension, ".css")) return "text/css";
    if (std.ascii.eqlIgnoreCase(extension, ".csv")) return "text/csv";
    if (std.ascii.eqlIgnoreCase(extension, ".xml")) return "text/xml";

    // JavaScript
    if (std.ascii.eqlIgnoreCase(extension, ".js")) return "text/javascript";
    if (std.ascii.eqlIgnoreCase(extension, ".mjs")) return "text/javascript";

    // JSON
    if (std.ascii.eqlIgnoreCase(extension, ".json")) return "application/json";

    // Images
    if (std.ascii.eqlIgnoreCase(extension, ".png")) return "image/png";
    if (std.ascii.eqlIgnoreCase(extension, ".jpg")) return "image/jpeg";
    if (std.ascii.eqlIgnoreCase(extension, ".jpeg")) return "image/jpeg";
    if (std.ascii.eqlIgnoreCase(extension, ".gif")) return "image/gif";
    if (std.ascii.eqlIgnoreCase(extension, ".webp")) return "image/webp";
    if (std.ascii.eqlIgnoreCase(extension, ".svg")) return "image/svg+xml";
    if (std.ascii.eqlIgnoreCase(extension, ".ico")) return "image/x-icon";
    if (std.ascii.eqlIgnoreCase(extension, ".bmp")) return "image/bmp";

    // Audio
    if (std.ascii.eqlIgnoreCase(extension, ".mp3")) return "audio/mpeg";
    if (std.ascii.eqlIgnoreCase(extension, ".wav")) return "audio/wave";
    if (std.ascii.eqlIgnoreCase(extension, ".ogg")) return "application/ogg";
    if (std.ascii.eqlIgnoreCase(extension, ".aiff")) return "audio/aiff";
    if (std.ascii.eqlIgnoreCase(extension, ".midi")) return "audio/midi";
    if (std.ascii.eqlIgnoreCase(extension, ".mid")) return "audio/midi";

    // Video
    if (std.ascii.eqlIgnoreCase(extension, ".mp4")) return "video/mp4";
    if (std.ascii.eqlIgnoreCase(extension, ".webm")) return "video/webm";
    if (std.ascii.eqlIgnoreCase(extension, ".avi")) return "video/avi";

    // Fonts
    if (std.ascii.eqlIgnoreCase(extension, ".woff")) return "font/woff";
    if (std.ascii.eqlIgnoreCase(extension, ".woff2")) return "font/woff2";
    if (std.ascii.eqlIgnoreCase(extension, ".ttf")) return "font/ttf";
    if (std.ascii.eqlIgnoreCase(extension, ".otf")) return "font/otf";
    if (std.ascii.eqlIgnoreCase(extension, ".eot")) return "application/vnd.ms-fontobject";

    // Archives
    if (std.ascii.eqlIgnoreCase(extension, ".zip")) return "application/zip";
    if (std.ascii.eqlIgnoreCase(extension, ".gz")) return "application/x-gzip";
    if (std.ascii.eqlIgnoreCase(extension, ".rar")) return "application/x-rar-compressed";

    // Documents
    if (std.ascii.eqlIgnoreCase(extension, ".pdf")) return "application/pdf";
    if (std.ascii.eqlIgnoreCase(extension, ".ps")) return "application/postscript";

    // Binary
    if (std.ascii.eqlIgnoreCase(extension, ".bin")) return "application/octet-stream";
    if (std.ascii.eqlIgnoreCase(extension, ".exe")) return "application/octet-stream";
    if (std.ascii.eqlIgnoreCase(extension, ".dll")) return "application/octet-stream";

    // WebVTT (text tracks)
    if (std.ascii.eqlIgnoreCase(extension, ".vtt")) return "text/vtt";

    // Cache manifest
    if (std.ascii.eqlIgnoreCase(extension, ".appcache")) return "text/cache-manifest";
    if (std.ascii.eqlIgnoreCase(extension, ".manifest")) return "text/cache-manifest";

    // Unknown extension
    return null;
}

/// Read the resource header (WHATWG MIME Sniffing §5.2)
///
/// A resource header is the byte sequence at the beginning of a resource.
/// The algorithm reads up to 1445 bytes to enable deterministic sniffing
/// for the majority of cases.
///
/// Parameters:
///   - allocator: Memory allocator
///   - data: Full resource data
///
/// Returns: Resource header (up to 1445 bytes)
///
/// Spec: https://mimesniff.spec.whatwg.org/#read-the-resource-header
pub fn readResourceHeader(
    allocator: std.mem.Allocator,
    data: []const u8,
) ![]const u8 {
    // 1. Let buffer be a byte sequence
    // 2. Read bytes of the resource into buffer until:
    //    - the end of the resource is reached, OR
    //    - the number of bytes is >= 1445, OR
    //    - a reasonable amount of time has elapsed

    // For our implementation, we read synchronously up to 1445 bytes
    const max_header_size = 1445;
    const header_size = @min(data.len, max_header_size);

    // 3. The resource header is buffer
    const header = try allocator.alloc(u8, header_size);
    @memcpy(header, data[0..header_size]);

    return header;
}

// ============================================================================
// Tests
// ============================================================================

test "Resource.init - default values" {
    const allocator = std.testing.allocator;
    var resource = Resource.init(allocator);
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type == null);
    try std.testing.expect(resource.check_for_apache_bug == false);
    try std.testing.expect(resource.no_sniff == false);
    try std.testing.expect(resource.computed_mime_type == null);
}

test "determineSuppliedMimeType - HTTP with Content-Type" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeType(allocator, "text/html; charset=utf-8");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type != null);
    try std.testing.expect(resource.check_for_apache_bug == false);
}

test "determineSuppliedMimeType - Apache bug detection" {
    const allocator = std.testing.allocator;

    const apache_types = [_][]const u8{
        "text/plain",
        "text/plain; charset=ISO-8859-1",
        "text/plain; charset=iso-8859-1",
        "text/plain; charset=UTF-8",
    };

    for (apache_types) |apache_type| {
        var resource = try determineSuppliedMimeType(allocator, apache_type);
        defer resource.deinit();

        try std.testing.expect(resource.check_for_apache_bug == true);
    }
}

test "determineSuppliedMimeType - no Content-Type" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeType(allocator, null);
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type == null);
    try std.testing.expect(resource.check_for_apache_bug == false);
}

test "readResourceHeader - full data less than 1445 bytes" {
    const allocator = std.testing.allocator;

    const data = "Hello, World!";
    const header = try readResourceHeader(allocator, data);
    defer allocator.free(header);

    try std.testing.expectEqual(@as(usize, 13), header.len);
    try std.testing.expectEqualStrings("Hello, World!", header);
}

test "readResourceHeader - data exactly 1445 bytes" {
    const allocator = std.testing.allocator;

    const data = [_]u8{0x42} ** 1445;
    const header = try readResourceHeader(allocator, &data);
    defer allocator.free(header);

    try std.testing.expectEqual(@as(usize, 1445), header.len);
    try std.testing.expectEqual(@as(u8, 0x42), header[0]);
    try std.testing.expectEqual(@as(u8, 0x42), header[1444]);
}

test "readResourceHeader - data larger than 1445 bytes" {
    const allocator = std.testing.allocator;

    const data = [_]u8{0x42} ** 2000;
    const header = try readResourceHeader(allocator, &data);
    defer allocator.free(header);

    try std.testing.expectEqual(@as(usize, 1445), header.len);
}

test "readResourceHeader - empty data" {
    const allocator = std.testing.allocator;

    const data = "";
    const header = try readResourceHeader(allocator, data);
    defer allocator.free(header);

    try std.testing.expectEqual(@as(usize, 0), header.len);
}

test "determineSuppliedMimeTypeFromPath - HTML file" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "index.html");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type != null);
    if (resource.supplied_mime_type) |mt| {
        const infra = @import("infra");
        const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.type);
        defer allocator.free(type_utf8);
        try std.testing.expectEqualStrings("text", type_utf8);

        const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.subtype);
        defer allocator.free(subtype_utf8);
        try std.testing.expectEqualStrings("html", subtype_utf8);
    }
}

test "determineSuppliedMimeTypeFromPath - JSON file" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "data.json");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type != null);
    if (resource.supplied_mime_type) |mt| {
        const infra = @import("infra");
        const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.type);
        defer allocator.free(type_utf8);
        try std.testing.expectEqualStrings("application", type_utf8);

        const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.subtype);
        defer allocator.free(subtype_utf8);
        try std.testing.expectEqualStrings("json", subtype_utf8);
    }
}

test "determineSuppliedMimeTypeFromPath - PNG image" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "photo.png");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type != null);
    if (resource.supplied_mime_type) |mt| {
        const infra = @import("infra");
        const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.type);
        defer allocator.free(type_utf8);
        try std.testing.expectEqualStrings("image", type_utf8);

        const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mt.subtype);
        defer allocator.free(subtype_utf8);
        try std.testing.expectEqualStrings("png", subtype_utf8);
    }
}

test "determineSuppliedMimeTypeFromPath - case insensitive" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "file.HTML");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type != null);
}

test "determineSuppliedMimeTypeFromPath - no extension" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "README");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type == null);
}

test "determineSuppliedMimeTypeFromPath - unknown extension" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "file.xyz");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type == null);
}

test "determineSuppliedMimeTypeFromPath - path with directory" {
    const allocator = std.testing.allocator;

    var resource = try determineSuppliedMimeTypeFromPath(allocator, "/var/www/index.html");
    defer resource.deinit();

    try std.testing.expect(resource.supplied_mime_type != null);
}

test "getMimeTypeForExtension - all text formats" {
    try std.testing.expect(getMimeTypeForExtension(".txt") != null);
    try std.testing.expect(getMimeTypeForExtension(".html") != null);
    try std.testing.expect(getMimeTypeForExtension(".css") != null);
    try std.testing.expect(getMimeTypeForExtension(".js") != null);
    try std.testing.expect(getMimeTypeForExtension(".json") != null);
}

test "getMimeTypeForExtension - all image formats" {
    try std.testing.expect(getMimeTypeForExtension(".png") != null);
    try std.testing.expect(getMimeTypeForExtension(".jpg") != null);
    try std.testing.expect(getMimeTypeForExtension(".gif") != null);
    try std.testing.expect(getMimeTypeForExtension(".svg") != null);
}

test "getMimeTypeForExtension - all audio formats" {
    try std.testing.expect(getMimeTypeForExtension(".mp3") != null);
    try std.testing.expect(getMimeTypeForExtension(".wav") != null);
    try std.testing.expect(getMimeTypeForExtension(".ogg") != null);
}

test "getMimeTypeForExtension - all font formats" {
    try std.testing.expect(getMimeTypeForExtension(".woff") != null);
    try std.testing.expect(getMimeTypeForExtension(".woff2") != null);
    try std.testing.expect(getMimeTypeForExtension(".ttf") != null);
}
