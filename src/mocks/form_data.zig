//! Mock FormData for Fetch body extraction
//!
//! TODO(xhr-spec): Replace this mock FormData with real implementation when
//! XMLHttpRequest specification (https://xhr.spec.whatwg.org/) is implemented.
//!
//! The real FormData implementation should:
//! 1. Support File values (Blob with name property):
//!    - append(name, blob, filename)
//!    - set(name, blob, filename)
//!    - Proper Content-Type detection for files
//!
//! 2. Support HTMLFormElement constructor:
//!    - new FormData(form) extracts all form fields
//!    - Handle various input types (text, file, checkbox, radio, select)
//!    - Respect form encoding (enctype attribute)
//!
//! 3. Support iteration:
//!    - entries() returning iterator of [name, value]
//!    - keys() returning iterator of names
//!    - values() returning iterator of values
//!    - Symbol.iterator
//!
//! 4. Support submitter element:
//!    - new FormData(form, submitter) includes submit button value
//!
//! Related interfaces to implement:
//! - File (extends Blob with name and lastModified)
//! - FileList (for <input type="file" multiple>)
//! - HTMLFormElement.elements
//!
//! Files that will need updates:
//! - src/webidl/impls/FormData.zig (wire up to real impl)
//! - src/fetch/body/extraction.zig (use real multipart encoding)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Entry value types.
pub const EntryValue = union(enum) {
    /// String value
    string: []const u8,
    // TODO(xhr-spec): Add File support when File API is implemented
    // file: *File,
};

/// A single form data entry (name/value pair).
pub const Entry = struct {
    name: []const u8,
    value: EntryValue,
};

/// Mock FormData.
///
/// Real FormData should:
/// - Support File values (Blob with filename)
/// - Support creating from HTMLFormElement
/// - Support iteration (entries, keys, values)
/// - Integrate with File API
pub const FormData = struct {
    allocator: Allocator,

    /// Stored entries (name, value pairs)
    entries: std.ArrayListUnmanaged(Entry),

    const Self = @This();

    /// Initialize an empty FormData.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .entries = .{},
        };
    }

    /// Free all entries and the FormData.
    pub fn deinit(self: *Self) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.name);
            switch (entry.value) {
                .string => |s| self.allocator.free(s),
            }
        }
        self.entries.deinit(self.allocator);
    }

    /// Append a name/value pair.
    ///
    /// Unlike set(), this adds a new entry even if one with the same name
    /// already exists.
    pub fn append(self: *Self, name: []const u8, value: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        try self.entries.append(self.allocator, .{
            .name = owned_name,
            .value = .{ .string = owned_value },
        });
    }

    /// Set a name/value pair.
    ///
    /// Removes all existing entries with the same name first, then appends
    /// the new entry.
    pub fn set(self: *Self, name: []const u8, value: []const u8) !void {
        self.delete(name);
        try self.append(name, value);
    }

    /// Get the first value for a name.
    ///
    /// Returns null if no entry with that name exists.
    pub fn get(self: *const Self, name: []const u8) ?[]const u8 {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return switch (entry.value) {
                    .string => |s| s,
                };
            }
        }
        return null;
    }

    /// Get all values for a name.
    ///
    /// Returns an owned slice of value references. Caller must free the slice
    /// (but not the values themselves).
    pub fn getAll(self: *const Self, allocator: Allocator, name: []const u8) ![]const []const u8 {
        var result: std.ArrayListUnmanaged([]const u8) = .{};
        errdefer result.deinit(allocator);

        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                try result.append(allocator, switch (entry.value) {
                    .string => |s| s,
                });
            }
        }
        return result.toOwnedSlice(allocator);
    }

    /// Check if an entry with the given name exists.
    pub fn has(self: *const Self, name: []const u8) bool {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return true;
            }
        }
        return false;
    }

    /// Delete all entries with the given name.
    pub fn delete(self: *Self, name: []const u8) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (std.mem.eql(u8, self.entries.items[i].name, name)) {
                const entry = self.entries.orderedRemove(i);
                self.allocator.free(entry.name);
                switch (entry.value) {
                    .string => |s| self.allocator.free(s),
                }
            } else {
                i += 1;
            }
        }
    }

    /// Get the number of entries.
    pub fn count(self: *const Self) usize {
        return self.entries.items.len;
    }
};

/// Result of multipart encoding.
pub const MultipartResult = struct {
    /// The encoded body
    body: []const u8,

    /// The boundary string (for Content-Type header)
    boundary: []const u8,

    /// Free the result.
    pub fn deinit(self: *MultipartResult, allocator: Allocator) void {
        allocator.free(self.body);
        allocator.free(self.boundary);
    }
};

/// Encode FormData as multipart/form-data.
///
/// TODO(xhr-spec): Real implementation should:
/// - Handle File entries with Content-Type and filename
/// - Properly escape field names per RFC 2047
/// - Support binary data in values
pub fn encodeMultipart(allocator: Allocator, form_data: *const FormData) !MultipartResult {
    // Generate boundary
    const boundary = try generateBoundary(allocator);
    errdefer allocator.free(boundary);

    var body: std.ArrayListUnmanaged(u8) = .{};
    errdefer body.deinit(allocator);

    for (form_data.entries.items) |entry| {
        // Part boundary
        try body.appendSlice(allocator, "--");
        try body.appendSlice(allocator, boundary);
        try body.appendSlice(allocator, "\r\n");

        // Content-Disposition header
        try body.appendSlice(allocator, "Content-Disposition: form-data; name=\"");
        // TODO: Escape special characters in name
        try body.appendSlice(allocator, entry.name);
        try body.appendSlice(allocator, "\"\r\n");

        // Blank line between headers and body
        try body.appendSlice(allocator, "\r\n");

        // Value
        switch (entry.value) {
            .string => |s| try body.appendSlice(allocator, s),
        }
        try body.appendSlice(allocator, "\r\n");
    }

    // Final boundary
    try body.appendSlice(allocator, "--");
    try body.appendSlice(allocator, boundary);
    try body.appendSlice(allocator, "--\r\n");

    return .{
        .body = try body.toOwnedSlice(allocator),
        .boundary = boundary,
    };
}

/// Generate a random boundary string for multipart encoding.
fn generateBoundary(allocator: Allocator) ![]const u8 {
    var buf: [16]u8 = undefined;
    std.crypto.random.bytes(&buf);
    return std.fmt.allocPrint(allocator, "----FormBoundary{s}", .{std.fmt.fmtSliceHexLower(&buf)});
}

/// Parse a URL-encoded form body into FormData.
///
/// Format: name1=value1&name2=value2
pub fn parseUrlEncoded(allocator: Allocator, body: []const u8) !FormData {
    var form_data = FormData.init(allocator);
    errdefer form_data.deinit();

    var pairs = std.mem.splitScalar(u8, body, '&');
    while (pairs.next()) |pair| {
        if (pair.len == 0) continue;

        const eq_pos = std.mem.indexOf(u8, pair, "=");
        if (eq_pos) |pos| {
            const name = try urlDecode(allocator, pair[0..pos]);
            defer allocator.free(name);
            const value = try urlDecode(allocator, pair[pos + 1 ..]);
            defer allocator.free(value);
            try form_data.append(name, value);
        } else {
            // Name without value
            const name = try urlDecode(allocator, pair);
            defer allocator.free(name);
            try form_data.append(name, "");
        }
    }

    return form_data;
}

/// URL-decode a string (convert %XX sequences and + to space).
fn urlDecode(allocator: Allocator, input: []const u8) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex = input[i + 1 .. i + 3];
            if (std.fmt.parseInt(u8, hex, 16)) |byte| {
                try result.append(allocator, byte);
                i += 3;
                continue;
            } else |_| {}
        }

        if (input[i] == '+') {
            try result.append(allocator, ' ');
        } else {
            try result.append(allocator, input[i]);
        }
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

// =============================================================================
// Tests
// =============================================================================

test "FormData.init and deinit" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try std.testing.expectEqual(@as(usize, 0), form_data.count());
}

test "FormData.append" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try form_data.append("name", "value");
    try std.testing.expectEqual(@as(usize, 1), form_data.count());

    // Can append multiple with same name
    try form_data.append("name", "value2");
    try std.testing.expectEqual(@as(usize, 2), form_data.count());
}

test "FormData.get" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try form_data.append("name", "value1");
    try form_data.append("name", "value2");

    // get() returns first value
    try std.testing.expectEqualStrings("value1", form_data.get("name").?);
    try std.testing.expect(form_data.get("nonexistent") == null);
}

test "FormData.getAll" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try form_data.append("name", "value1");
    try form_data.append("name", "value2");
    try form_data.append("other", "other_value");

    const values = try form_data.getAll(allocator, "name");
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqualStrings("value1", values[0]);
    try std.testing.expectEqualStrings("value2", values[1]);
}

test "FormData.set" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try form_data.append("name", "value1");
    try form_data.append("name", "value2");
    try std.testing.expectEqual(@as(usize, 2), form_data.count());

    // set() removes existing and adds new
    try form_data.set("name", "new_value");
    try std.testing.expectEqual(@as(usize, 1), form_data.count());
    try std.testing.expectEqualStrings("new_value", form_data.get("name").?);
}

test "FormData.has" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try std.testing.expect(!form_data.has("name"));

    try form_data.append("name", "value");
    try std.testing.expect(form_data.has("name"));
    try std.testing.expect(!form_data.has("other"));
}

test "FormData.delete" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try form_data.append("name", "value1");
    try form_data.append("name", "value2");
    try form_data.append("other", "other_value");

    form_data.delete("name");

    try std.testing.expect(!form_data.has("name"));
    try std.testing.expect(form_data.has("other"));
    try std.testing.expectEqual(@as(usize, 1), form_data.count());
}

test "encodeMultipart" {
    const allocator = std.testing.allocator;

    var form_data = FormData.init(allocator);
    defer form_data.deinit();

    try form_data.append("field1", "value1");
    try form_data.append("field2", "value2");

    var result = try encodeMultipart(allocator, &form_data);
    defer result.deinit(allocator);

    // Check boundary is in body
    try std.testing.expect(std.mem.indexOf(u8, result.body, result.boundary) != null);

    // Check fields are present
    try std.testing.expect(std.mem.indexOf(u8, result.body, "field1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.body, "value1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.body, "field2") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.body, "value2") != null);

    // Check ends with final boundary
    const final = try std.fmt.allocPrint(allocator, "--{s}--\r\n", .{result.boundary});
    defer allocator.free(final);
    try std.testing.expect(std.mem.endsWith(u8, result.body, final));
}

test "parseUrlEncoded" {
    const allocator = std.testing.allocator;

    var form_data = try parseUrlEncoded(allocator, "name=value&foo=bar");
    defer form_data.deinit();

    try std.testing.expectEqual(@as(usize, 2), form_data.count());
    try std.testing.expectEqualStrings("value", form_data.get("name").?);
    try std.testing.expectEqualStrings("bar", form_data.get("foo").?);
}

test "parseUrlEncoded with encoding" {
    const allocator = std.testing.allocator;

    var form_data = try parseUrlEncoded(allocator, "name=hello%20world&plus=a+b");
    defer form_data.deinit();

    try std.testing.expectEqualStrings("hello world", form_data.get("name").?);
    try std.testing.expectEqualStrings("a b", form_data.get("plus").?);
}

test "parseUrlEncoded empty value" {
    const allocator = std.testing.allocator;

    var form_data = try parseUrlEncoded(allocator, "name=&empty");
    defer form_data.deinit();

    try std.testing.expectEqual(@as(usize, 2), form_data.count());
    try std.testing.expectEqualStrings("", form_data.get("name").?);
    try std.testing.expectEqualStrings("", form_data.get("empty").?);
}

test "urlDecode" {
    const allocator = std.testing.allocator;

    const result1 = try urlDecode(allocator, "hello%20world");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello world", result1);

    const result2 = try urlDecode(allocator, "a+b");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("a b", result2);

    const result3 = try urlDecode(allocator, "%C3%A9");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("é", result3);
}
