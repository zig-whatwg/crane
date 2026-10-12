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

/// Parse Content-Disposition parameters into owned name/filename strings.
/// The caller frees each present string with allocator.
///
/// Examples:
///   "form-data; name=\"username\""
///   "form-data; name=\"avatar\"; filename=\"photo.jpg\""
///
/// RFC 7578 Section 4.2: Each part MUST contain a Content-Disposition header field
fn parseContentDisposition(allocator: Allocator, line: []const u8) !struct { name: ?[]const u8, filename: ?[]const u8 } {
    var name: ?[]const u8 = null;
    var filename: ?[]const u8 = null;
    errdefer if (name) |value| allocator.free(value);
    errdefer if (filename) |value| allocator.free(value);

    // Browser-backed deviations from RFC 2183 section 2 / RFC 2045:
    // WebKit parseParameters and Gecko FormDataParser::ParseHeader match
    // lowercase names exactly and retain ordinary backslashes. Blink and
    // Gecko take the last duplicate and allow whitespace before a quoted
    // value; Blink and WebKit preserve semicolons inside quotes.
    // WebKit: Source/WebCore/Modules/fetch/FetchBodyConsumer.cpp, parseParameters
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/fetch/FetchBodyConsumer.cpp
    // Gecko: dom/base/BodyUtil.cpp, FormDataParser::ParseHeader
    // https://searchfox.org/mozilla-central/source/dom/base/BodyUtil.cpp
    // Blink: ParsedContentDisposition, ParsedContentHeaderFieldParameters::Parse,
    // ParameterValueForName and HeaderFieldTokenizer::ConsumeQuotedString
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/network/parsed_content_disposition.cc
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/network/parsed_content_header_field_parameters.cc
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/network/header_field_tokenizer.cc
    // The unquoted multipart Blob-to-formData case passes in Chrome,
    // Firefox and Safari at wpt.fyi cc74d2669f (file totals 40/40, 39/40, 40/40).
    // https://wpt.fyi/results/fetch/api/response/response-consume.html?sha=cc74d2669f
    var position: usize = 0;
    while (position < line.len) {
        while (position < line.len and (line[position] == ';' or line[position] == ' ' or line[position] == '\t')) : (position += 1) {}
        const key_start = position;
        while (position < line.len and line[position] != '=' and line[position] != ';') : (position += 1) {}
        if (position == line.len) break;
        if (line[position] == ';') {
            position += 1;
            continue;
        }
        // Do not trim whitespace before '=': WebKit and Gecko do not match it.
        const key = line[key_start..position];
        position += 1;
        // WebKit and Blink omit an absent terminal value; Gecko alone accepts it.
        if (position == line.len) break;
        while (position < line.len and (line[position] == ' ' or line[position] == '\t')) : (position += 1) {}
        var escaped_quotes: usize = 0;
        const quoted = position < line.len and line[position] == '"';
        if (quoted) position += 1;
        const value_start = position;
        var value_end = position;
        if (quoted) {
            while (position < line.len and line[position] != '"') {
                if (line[position] == '\\' and position + 1 < line.len) {
                    if (line[position + 1] == '"') {
                        var after_quote = position + 2;
                        while (after_quote < line.len and (line[after_quote] == ' ' or line[after_quote] == '\t')) : (after_quote += 1) {}
                        // WebKit parseParameters and Gecko ParseHeader (above)
                        // retain a backslash before the closing quote. Only
                        // Blink unescapes it, breaking a FormData round trip.
                        if (after_quote == line.len or line[after_quote] == ';') {
                            position += 1;
                            break;
                        }
                        escaped_quotes += 1;
                    }
                    // An internal escaped quote still splits all three engines.
                    // RFC 2183 refers to RFC 822 sections 3.3/3.4: a quoted-pair
                    // yields the quoted character. RFC 5322 section 3.2.1 agrees.
                    // Other quoted-pairs keep BOTH bytes (WebKit + Gecko),
                    // but must be consumed together so a following quote closes.
                    // https://www.rfc-editor.org/rfc/rfc822#section-3.3
                    // https://www.rfc-editor.org/rfc/rfc5322#section-3.2.1
                    position += 2;
                } else {
                    position += 1;
                }
            }
            value_end = position;
            // WebKit and Gecko accept an unterminated quote through EOF.
            if (position < line.len) position += 1;
            while (position < line.len and (line[position] == ' ' or line[position] == '\t')) : (position += 1) {}
            // With no separator, WebKit reads a second parameter, Gecko
            // keeps trailing text in the first value, and Blink rejects.
            // The three-way split follows RFC 2183 section 2: ';' is required.
            if (position < line.len and line[position] != ';') return error.InvalidHeaders;
        } else {
            while (position < line.len and line[position] != ';') : (position += 1) {}
            value_end = position;
        }
        const value = if (quoted) line[value_start..value_end] else std.mem.trim(u8, line[value_start..value_end], " \t\r\n");
        // An empty value explicitly followed by ';' is present (WebKit + Gecko).
        const target = if (std.mem.eql(u8, key, "name")) &name else if (std.mem.eql(u8, key, "filename")) &filename else continue;
        const owned = try allocator.alloc(u8, value.len - escaped_quotes);
        var read: usize = 0;
        var write: usize = 0;
        while (read < value.len) {
            if (quoted and value[read] == '\\' and read + 1 < value.len) {
                if (value[read + 1] != '"') {
                    owned[write] = value[read];
                    write += 1;
                }
                read += 1;
            }
            owned[write] = value[read];
            write += 1;
            read += 1;
        }
        if (target.*) |previous| allocator.free(previous);
        target.* = owned;
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
    errdefer if (name) |value| allocator.free(value);
    errdefer if (filename) |value| allocator.free(value);
    errdefer if (content_type) |value| allocator.free(value);

    // Split headers by CRLF
    var lines = std.mem.splitSequence(u8, headers, "\r\n");

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // RFC 7578 part-header names are ASCII case-insensitive; values keep
        // their case. Chrome/Firefox/Safari pass body/formdata 3/3, including
        // lowercase headers (wpt.fyi cc74d2669f).
        // https://wpt.fyi/results/fetch/api/body/formdata.any.html?sha=cc74d2669f
        if (std.ascii.startsWithIgnoreCase(line, "Content-Disposition:")) {
            const header_value = std.mem.trim(u8, line[20..], " ");
            // The parser owns the decoded strings; transfer them directly.
            const parsed = try parseContentDisposition(allocator, header_value);
            if (parsed.name) |n| {
                if (name) |previous| allocator.free(previous);
                name = n;
            }
            if (parsed.filename) |f| {
                if (filename) |previous| allocator.free(previous);
                filename = f;
            }
        }
        // Parse Content-Type header
        else if (std.ascii.startsWithIgnoreCase(line, "Content-Type:")) {
            const header_value = std.mem.trim(u8, line[13..], " ");
            const owned = try allocator.dupe(u8, header_value);
            if (content_type) |previous| allocator.free(previous);
            content_type = owned;
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
    var entries: std.ArrayListUnmanaged(FormDataEntry) = .empty;
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

    // A zero-part body starts with the close-delimiter itself, before any
    // CRLF (RFC 2046 section 5.1.1). Blink's FormData encoder appends it
    // unconditionally; Chrome/Firefox/Safari pass body/formdata 3/3 at
    // wpt.fyi cc74d2669f, including empty FormData round trips.
    // https://wpt.fyi/results/fetch/api/body/formdata.any.html?sha=cc74d2669f
    var remaining = body[first_boundary.len..];
    if (std.mem.startsWith(u8, remaining, "--")) return entries.toOwnedSlice(allocator);

    // An opening delimiter must be followed by a part, not just EOF/CRLF.
    if (std.mem.startsWith(u8, remaining, "\r\n")) {
        remaining = remaining[2..];
    }
    if (remaining.len == 0) return error.InvalidMultipartBody;

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

        var entry = blk: {
            const info = try parsePartHeaders(allocator, headers);
            errdefer allocator.free(info.name);
            errdefer if (info.filename) |value| allocator.free(value);
            defer if (info.content_type) |value| allocator.free(value);

            // Fetch formData(), step 2 multipart branch, step 1: keep the
            // file's bytes and Content-Type until its owner constructs File.
            const value: FormDataEntryValue = if (info.filename != null)
                .{ .file = try form_data.File.init(allocator, part_body, info.content_type) }
            else
                .{ .string = try allocator.dupe(u8, part_body) };
            break :blk FormDataEntry{ .name = info.name, .value = value, .filename = info.filename };
        };
        errdefer entry.deinit(allocator);
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
    const allocator = std.testing.allocator;
    const parsed = try parseContentDisposition(allocator, line);
    defer if (parsed.name) |value| allocator.free(value);
    defer if (parsed.filename) |value| allocator.free(value);

    try std.testing.expect(parsed.name != null);
    try std.testing.expectEqualStrings("username", parsed.name.?);
    try std.testing.expect(parsed.filename == null);
}

test "parseContentDisposition - name and filename" {
    const line = "form-data; name=\"avatar\"; filename=\"photo.jpg\"";
    const allocator = std.testing.allocator;
    const parsed = try parseContentDisposition(allocator, line);
    defer if (parsed.name) |value| allocator.free(value);
    defer if (parsed.filename) |value| allocator.free(value);

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
