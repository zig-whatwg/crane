//! multipart/form-data Parser
//!
//! HTML Standard: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#multipart/form-data-encoding-algorithm
//! RFC 7578: https://www.rfc-editor.org/rfc/rfc7578
//!
//! Parses multipart/form-data request bodies into FormData entries.

const std = @import("std");
const Allocator = std.mem.Allocator;
const form_data = @import("form_data.zig");
const FormDataEntry = form_data.FormDataEntry;
const FormDataEntryValue = form_data.FormDataEntryValue;

/// Parse error types
pub const ParseError = error{
    InvalidContentType,
    MissingBoundary,
    InvalidMultipartBody,
    InvalidHeaders,
    OutOfMemory,
};

/// Part information extracted from headers
const PartInfo = struct {
    name: []const u8,
    filename: ?[]const u8,
    content_type: ?[]const u8,
};

/// Extract boundary from Content-Type header
///
/// Input: "multipart/form-data; boundary=----WebKitFormBoundary123"
/// Output: "----WebKitFormBoundary123"
///
/// RFC 7578 Section 4.1: The boundary delimiter MUST NOT appear inside any of the encapsulated parts
pub fn extractBoundary(allocator: Allocator, content_type: []const u8) ![]const u8 {
    // Find "boundary=" parameter
    const boundary_prefix = "boundary=";
    const start = std.mem.indexOf(u8, content_type, boundary_prefix) orelse return error.MissingBoundary;

    var boundary_start = start + boundary_prefix.len;

    // Skip leading whitespace
    while (boundary_start < content_type.len and content_type[boundary_start] == ' ') {
        boundary_start += 1;
    }

    if (boundary_start >= content_type.len) return error.MissingBoundary;

    // Check if boundary is quoted
    var boundary_value: []const u8 = undefined;
    if (content_type[boundary_start] == '"') {
        // Quoted boundary - find closing quote
        boundary_start += 1;
        const end = std.mem.indexOfScalarPos(u8, content_type, boundary_start, '"') orelse return error.MissingBoundary;
        boundary_value = content_type[boundary_start..end];
    } else {
        // Unquoted boundary - goes until semicolon, space, or end
        var end = boundary_start;
        while (end < content_type.len and content_type[end] != ';' and content_type[end] != ' ') {
            end += 1;
        }
        boundary_value = content_type[boundary_start..end];
    }

    if (boundary_value.len == 0) return error.MissingBoundary;

    return try allocator.dupe(u8, boundary_value);
}

/// Parse Content-Disposition header to extract name and optional filename
///
/// Examples:
///   "form-data; name=\"username\""
///   "form-data; name=\"avatar\"; filename=\"photo.jpg\""
///
/// RFC 7578 Section 4.2: Each part MUST contain a Content-Disposition header field
fn parseContentDisposition(line: []const u8) !struct { name: ?[]const u8, filename: ?[]const u8 } {
    var name: ?[]const u8 = null;
    var filename: ?[]const u8 = null;

    // Find "name=" parameter
    if (std.mem.indexOf(u8, line, "name=")) |name_start| {
        const value_start = name_start + 5; // Skip "name="
        if (value_start < line.len) {
            if (line[value_start] == '"') {
                // Quoted value
                const quote_start = value_start + 1;
                if (std.mem.indexOfScalarPos(u8, line, quote_start, '"')) |quote_end| {
                    name = line[quote_start..quote_end];
                }
            }
        }
    }

    // Find "filename=" parameter
    if (std.mem.indexOf(u8, line, "filename=")) |filename_start| {
        const value_start = filename_start + 9; // Skip "filename="
        if (value_start < line.len) {
            if (line[value_start] == '"') {
                // Quoted value
                const quote_start = value_start + 1;
                if (std.mem.indexOfScalarPos(u8, line, quote_start, '"')) |quote_end| {
                    filename = line[quote_start..quote_end];
                }
            }
        }
    }

    return .{ .name = name, .filename = filename };
}

/// Parse headers section of a multipart part
///
/// Input: "Content-Disposition: form-data; name=\"file\"\r\nContent-Type: image/jpeg\r\n"
/// Output: PartInfo with name, filename, content_type
fn parsePartHeaders(allocator: Allocator, headers: []const u8) !PartInfo {
    var name: ?[]const u8 = null;
    var filename: ?[]const u8 = null;
    var content_type: ?[]const u8 = null;

    // Split headers by CRLF
    var lines = std.mem.splitSequence(u8, headers, "\r\n");

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Parse Content-Disposition header
        if (std.mem.startsWith(u8, line, "Content-Disposition:")) {
            const header_value = std.mem.trim(u8, line[20..], " ");
            const parsed = try parseContentDisposition(header_value);
            if (parsed.name) |n| {
                name = try allocator.dupe(u8, n);
            }
            if (parsed.filename) |f| {
                filename = try allocator.dupe(u8, f);
            }
        }
        // Parse Content-Type header
        else if (std.mem.startsWith(u8, line, "Content-Type:")) {
            const header_value = std.mem.trim(u8, line[13..], " ");
            content_type = try allocator.dupe(u8, header_value);
        }
    }

    if (name == null) return error.InvalidHeaders;

    return PartInfo{
        .name = name.?,
        .filename = filename,
        .content_type = content_type,
    };
}

/// Parse multipart/form-data body
///
/// Algorithm:
/// 1. Split body on boundary markers (--{boundary})
/// 2. For each part:
///    - Split into headers and body at first \r\n\r\n
///    - Parse headers to get name, filename, content-type
///    - Create FormDataEntry
/// 3. Return array of entries
///
/// RFC 7578 Format:
/// --{boundary}\r\n
/// Content-Disposition: form-data; name="field1"\r\n
/// \r\n
/// value1\r\n
/// --{boundary}\r\n
/// Content-Disposition: form-data; name="field2"; filename="file.txt"\r\n
/// Content-Type: text/plain\r\n
/// \r\n
/// file contents\r\n
/// --{boundary}--
pub fn parseMultipartFormData(
    allocator: Allocator,
    body: []const u8,
    boundary: []const u8,
) ![]FormDataEntry {
    var entries = std.ArrayListUnmanaged(FormDataEntry){};
    errdefer {
        for (entries.items) |*entry| {
            entry.deinit(allocator);
        }
        entries.deinit(allocator);
    }

    // Build boundary delimiters
    // Part boundary: \r\n--{boundary}
    // First boundary: --{boundary}
    // Final boundary: --{boundary}--
    const part_boundary = try std.fmt.allocPrint(allocator, "\r\n--{s}", .{boundary});
    defer allocator.free(part_boundary);

    const first_boundary = try std.fmt.allocPrint(allocator, "--{s}", .{boundary});
    defer allocator.free(first_boundary);

    const final_boundary = try std.fmt.allocPrint(allocator, "--{s}--", .{boundary});
    defer allocator.free(final_boundary);

    // Check if body starts with first boundary
    if (!std.mem.startsWith(u8, body, first_boundary)) {
        return error.InvalidMultipartBody;
    }

    // Skip first boundary (including CRLF after it)
    var remaining = body[first_boundary.len..];
    if (std.mem.startsWith(u8, remaining, "\r\n")) {
        remaining = remaining[2..];
    }

    // Process parts until we hit final boundary
    while (remaining.len > 0) {
        // Check if we've hit the final boundary (can appear without \r\n prefix at end)
        if (std.mem.startsWith(u8, remaining, final_boundary) or
            std.mem.startsWith(u8, remaining, final_boundary[2..]))
        { // --{boundary}-- without leading \r\n
            // Found final boundary, we're done
            break;
        }

        // Find next boundary
        const next_boundary_pos = std.mem.indexOf(u8, remaining, part_boundary);

        if (next_boundary_pos == null) {
            // No more part boundaries and no final boundary - malformed
            return error.InvalidMultipartBody;
        }

        // Extract this part
        const part = remaining[0..next_boundary_pos.?];

        // Split part into headers and body at \r\n\r\n
        const headers_end = std.mem.indexOf(u8, part, "\r\n\r\n") orelse return error.InvalidHeaders;
        const headers = part[0..headers_end];
        const part_body = part[headers_end + 4 ..]; // Skip \r\n\r\n

        // Parse headers
        const info = try parsePartHeaders(allocator, headers);

        // Create entry based on whether it's a file or string
        const entry = if (info.filename != null) blk: {
            // File entry - create File from bytes
            const file = try allocator.create(form_data.File);
            file.* = .{
                .data = try allocator.dupe(u8, part_body),
                .allocator = allocator,
            };

            // Free content_type (we don't store it in the File struct)
            if (info.content_type) |ct| allocator.free(ct);

            break :blk FormDataEntry{
                .name = info.name,
                .value = .{ .file = file },
                .filename = info.filename,
            };
        } else blk: {
            // String entry
            // Free content_type since we don't use it for strings
            if (info.content_type) |ct| allocator.free(ct);

            break :blk FormDataEntry{
                .name = info.name,
                .value = .{ .string = try allocator.dupe(u8, part_body) },
                .filename = null,
            };
        };

        try entries.append(allocator, entry);

        // Move to next part (skip the boundary we found)
        remaining = remaining[next_boundary_pos.? + part_boundary.len ..];

        // Check if this is the final boundary (ends with --)
        if (std.mem.startsWith(u8, remaining, "--")) {
            // This was the final boundary, we're done
            break;
        }

        // Skip CRLF after boundary if present
        if (std.mem.startsWith(u8, remaining, "\r\n")) {
            remaining = remaining[2..];
        }
    }

    return entries.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "extractBoundary - unquoted" {
    const allocator = std.testing.allocator;

    const content_type = "multipart/form-data; boundary=----WebKitFormBoundary123";
    const boundary = try extractBoundary(allocator, content_type);
    defer allocator.free(boundary);

    try std.testing.expectEqualStrings("----WebKitFormBoundary123", boundary);
}

test "extractBoundary - quoted" {
    const allocator = std.testing.allocator;

    const content_type = "multipart/form-data; boundary=\"----WebKitFormBoundary456\"";
    const boundary = try extractBoundary(allocator, content_type);
    defer allocator.free(boundary);

    try std.testing.expectEqualStrings("----WebKitFormBoundary456", boundary);
}

test "extractBoundary - missing" {
    const allocator = std.testing.allocator;

    const content_type = "multipart/form-data";
    const result = extractBoundary(allocator, content_type);

    try std.testing.expectError(error.MissingBoundary, result);
}

test "parseContentDisposition - name only" {
    const line = "form-data; name=\"username\"";
    const parsed = try parseContentDisposition(line);

    try std.testing.expect(parsed.name != null);
    try std.testing.expectEqualStrings("username", parsed.name.?);
    try std.testing.expect(parsed.filename == null);
}

test "parseContentDisposition - name and filename" {
    const line = "form-data; name=\"avatar\"; filename=\"photo.jpg\"";
    const parsed = try parseContentDisposition(line);

    try std.testing.expect(parsed.name != null);
    try std.testing.expectEqualStrings("avatar", parsed.name.?);
    try std.testing.expect(parsed.filename != null);
    try std.testing.expectEqualStrings("photo.jpg", parsed.filename.?);
}

test "parseMultipartFormData - single text field" {
    const allocator = std.testing.allocator;

    const body = "--boundary123\r\n" ++
        "Content-Disposition: form-data; name=\"username\"\r\n" ++
        "\r\n" ++
        "john_doe\r\n" ++
        "--boundary123--";

    const entries = try parseMultipartFormData(allocator, body, "boundary123");
    defer {
        for (entries) |*entry| {
            entry.deinit(allocator);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqualStrings("username", entries[0].name);
    try std.testing.expectEqualStrings("john_doe", entries[0].value.string);
    try std.testing.expect(entries[0].filename == null);
}

test "parseMultipartFormData - multiple text fields" {
    const allocator = std.testing.allocator;

    const body = "--boundary123\r\n" ++
        "Content-Disposition: form-data; name=\"field1\"\r\n" ++
        "\r\n" ++
        "value1\r\n" ++
        "--boundary123\r\n" ++
        "Content-Disposition: form-data; name=\"field2\"\r\n" ++
        "\r\n" ++
        "value2\r\n" ++
        "--boundary123--";

    const entries = try parseMultipartFormData(allocator, body, "boundary123");
    defer {
        for (entries) |*entry| {
            entry.deinit(allocator);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("field1", entries[0].name);
    try std.testing.expectEqualStrings("value1", entries[0].value.string);
    try std.testing.expectEqualStrings("field2", entries[1].name);
    try std.testing.expectEqualStrings("value2", entries[1].value.string);
}

test "parseMultipartFormData - text and file" {
    const allocator = std.testing.allocator;

    const body = "--boundary123\r\n" ++
        "Content-Disposition: form-data; name=\"username\"\r\n" ++
        "\r\n" ++
        "john\r\n" ++
        "--boundary123\r\n" ++
        "Content-Disposition: form-data; name=\"avatar\"; filename=\"photo.jpg\"\r\n" ++
        "Content-Type: image/jpeg\r\n" ++
        "\r\n" ++
        "fake binary data here\r\n" ++
        "--boundary123--";

    const entries = try parseMultipartFormData(allocator, body, "boundary123");
    defer {
        for (entries) |*entry| {
            entry.deinit(allocator);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 2), entries.len);

    // First entry: text field
    try std.testing.expectEqualStrings("username", entries[0].name);
    try std.testing.expectEqualStrings("john", entries[0].value.string);

    // Second entry: file field
    try std.testing.expectEqualStrings("avatar", entries[1].name);
    try std.testing.expect(entries[1].filename != null);
    try std.testing.expectEqualStrings("photo.jpg", entries[1].filename.?);
    try std.testing.expectEqualStrings("fake binary data here", entries[1].value.file.data);
}
