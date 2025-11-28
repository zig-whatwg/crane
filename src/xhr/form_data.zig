//! FormData Implementation
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/#interface-formdata
//!
//! FormData represents an ordered list of entries (name-value pairs).
//! Each entry can be a string or a File/Blob.

const std = @import("std");
const Allocator = std.mem.Allocator;

// File/Blob types - will be properly imported when integrated
// For now, use placeholder types
const File = struct {
    data: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *File, allocator: Allocator) void {
        allocator.free(self.data);
        allocator.destroy(self);
    }

    pub fn clone(self: *File, allocator: Allocator) !*File {
        const file = try allocator.create(File);
        file.* = .{
            .data = try allocator.dupe(u8, self.data),
            .allocator = allocator,
        };
        return file;
    }

    pub fn fromBlob(allocator: Allocator, blob: *Blob, filename: []const u8) !*File {
        _ = filename;
        const file = try allocator.create(File);
        file.* = .{
            .data = try allocator.dupe(u8, blob.data),
            .allocator = allocator,
        };
        return file;
    }
};

const Blob = struct {
    data: []const u8,
};

/// FormData entry value (string or file)
pub const FormDataEntryValue = union(enum) {
    string: []const u8,
    file: *File,

    pub fn deinit(self: *FormDataEntryValue, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .file => |f| f.deinit(allocator),
        }
    }

    pub fn clone(self: FormDataEntryValue, allocator: Allocator) !FormDataEntryValue {
        return switch (self) {
            .string => |s| .{ .string = try allocator.dupe(u8, s) },
            .file => |f| .{ .file = try f.clone(allocator) },
        };
    }
};

/// FormData entry (name + value + optional filename)
pub const FormDataEntry = struct {
    /// Entry name
    name: []const u8,

    /// Entry value (string or file)
    value: FormDataEntryValue,

    /// Filename (only for file entries)
    filename: ?[]const u8,

    pub fn deinit(self: *FormDataEntry, allocator: Allocator) void {
        allocator.free(self.name);
        self.value.deinit(allocator);
        if (self.filename) |f| allocator.free(f);
    }
};

/// FormData object
///
/// Spec: https://xhr.spec.whatwg.org/#interface-formdata
pub const FormData = struct {
    /// Ordered list of entries
    entries: std.ArrayListUnmanaged(FormDataEntry),

    /// Allocator
    allocator: Allocator,

    /// Create empty FormData
    pub fn init(allocator: Allocator) !*FormData {
        const self = try allocator.create(FormData);
        self.* = .{
            .entries = .{},
            .allocator = allocator,
        };
        return self;
    }

    /// Create FormData from HTML form element
    ///
    /// TODO: Requires HTML Standard's form element and entry list construction
    /// Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#constructing-the-form-data-set
    pub fn initFromForm(
        allocator: Allocator,
        form: anytype,
        submitter: anytype,
    ) !*FormData {
        _ = form;
        _ = submitter;
        _ = allocator;
        @panic("TODO: FormData.initFromForm requires HTML Standard form implementation");
    }

    pub fn deinit(self: *FormData) void {
        for (self.entries.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.entries.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Append a string entry
    ///
    /// Spec step 1-3: Create entry and append to list
    pub fn appendString(self: *FormData, name: []const u8, value: []const u8) !void {
        const entry = FormDataEntry{
            .name = try self.allocator.dupe(u8, name),
            .value = .{ .string = try self.allocator.dupe(u8, value) },
            .filename = null,
        };
        try self.entries.append(self.allocator, entry);
    }

    /// Append a file/blob entry
    ///
    /// Spec step 1-3: Create entry with filename and append to list
    pub fn appendFile(
        self: *FormData,
        name: []const u8,
        file: *File,
        filename: ?[]const u8,
    ) !void {
        const entry = FormDataEntry{
            .name = try self.allocator.dupe(u8, name),
            .value = .{ .file = try file.clone(self.allocator) },
            .filename = if (filename) |f| try self.allocator.dupe(u8, f) else null,
        };
        try self.entries.append(self.allocator, entry);
    }

    /// Append a blob entry (converts to file)
    pub fn appendBlob(
        self: *FormData,
        name: []const u8,
        blob: *Blob,
        filename: ?[]const u8,
    ) !void {
        // Convert Blob to File
        const file = try File.fromBlob(self.allocator, blob, filename orelse "blob");
        errdefer file.deinit(self.allocator);

        try self.appendFile(name, file, filename);
    }

    /// Delete all entries with given name
    ///
    /// Spec: Remove all entries whose name is `name`
    pub fn delete(self: *FormData, name: []const u8) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (std.mem.eql(u8, self.entries.items[i].name, name)) {
                var entry = self.entries.orderedRemove(i);
                entry.deinit(self.allocator);
            } else {
                i += 1;
            }
        }
    }

    /// Get first entry value with given name
    ///
    /// Spec: Return first entry's value or null
    pub fn get(self: *FormData, name: []const u8) ?FormDataEntryValue {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.value;
            }
        }
        return null;
    }

    /// Get all entry values with given name
    ///
    /// Spec: Return list of all matching entry values
    pub fn getAll(self: *FormData, allocator: Allocator, name: []const u8) ![]FormDataEntryValue {
        var results: std.ArrayListUnmanaged(FormDataEntryValue) = .{};
        errdefer results.deinit(allocator);

        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                try results.append(allocator, entry.value);
            }
        }

        return results.toOwnedSlice(allocator);
    }

    /// Check if entry with given name exists
    ///
    /// Spec: Return true if any entry has name `name`
    pub fn has(self: *FormData, name: []const u8) bool {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return true;
            }
        }
        return false;
    }

    /// Set entry value (replaces all existing entries with same name)
    ///
    /// Spec: Replace first entry with `name`, delete rest
    pub fn setString(self: *FormData, name: []const u8, value: []const u8) !void {
        var found_first = false;
        var i: usize = 0;

        while (i < self.entries.items.len) {
            if (std.mem.eql(u8, self.entries.items[i].name, name)) {
                if (!found_first) {
                    // Replace first occurrence
                    var entry = &self.entries.items[i];
                    entry.value.deinit(self.allocator);
                    entry.value = .{ .string = try self.allocator.dupe(u8, value) };
                    if (entry.filename) |f| {
                        self.allocator.free(f);
                        entry.filename = null;
                    }
                    found_first = true;
                    i += 1;
                } else {
                    // Remove subsequent occurrences
                    var entry = self.entries.orderedRemove(i);
                    entry.deinit(self.allocator);
                }
            } else {
                i += 1;
            }
        }

        // If no entry found, append new one
        if (!found_first) {
            try self.appendString(name, value);
        }
    }

    /// Set file entry value (replaces all existing entries with same name)
    pub fn setFile(
        self: *FormData,
        name: []const u8,
        file: *File,
        filename: ?[]const u8,
    ) !void {
        var found_first = false;
        var i: usize = 0;

        const cloned_file = try file.clone(self.allocator);
        errdefer cloned_file.deinit(self.allocator);

        while (i < self.entries.items.len) {
            if (std.mem.eql(u8, self.entries.items[i].name, name)) {
                if (!found_first) {
                    // Replace first occurrence
                    var entry = &self.entries.items[i];
                    entry.value.deinit(self.allocator);
                    entry.value = .{ .file = cloned_file };
                    if (entry.filename) |f| self.allocator.free(f);
                    entry.filename = if (filename) |f| try self.allocator.dupe(u8, f) else null;
                    found_first = true;
                    i += 1;
                } else {
                    // Remove subsequent occurrences
                    var entry = self.entries.orderedRemove(i);
                    entry.deinit(self.allocator);
                }
            } else {
                i += 1;
            }
        }

        // If no entry found, append new one
        if (!found_first) {
            try self.appendFile(name, cloned_file, filename);
        }
    }

    /// Iterator for WebIDL iterable support
    pub const Iterator = struct {
        form_data: *const FormData,
        index: usize,

        pub fn next(self: *Iterator) ?struct { []const u8, FormDataEntryValue } {
            if (self.index >= self.form_data.entries.items.len) {
                return null;
            }

            const entry = &self.form_data.entries.items[self.index];
            self.index += 1;

            return .{ entry.name, entry.value };
        }
    };

    /// Create iterator
    pub fn iterator(self: *const FormData) Iterator {
        return .{
            .form_data = self,
            .index = 0,
        };
    }

    /// Serialize FormData as multipart/form-data
    ///
    /// TODO: Implement HTML Standard's multipart/form-data encoding algorithm
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#multipart/form-data-encoding-algorithm
    /// RFC: https://www.rfc-editor.org/rfc/rfc7578
    ///
    /// Algorithm:
    /// 1. For each entry:
    ///    - Normalize line endings (CR not followed by LF → CRLF, LF not preceded by CR → CRLF)
    ///    - For non-file entries: normalize value line endings
    /// 2. Encode using RFC 7578 rules:
    ///    - Each entry is a field (name = field name, value = field value)
    ///    - Order of parts = order of entries
    ///    - Multiple entries with same name = distinct fields
    ///    - Field names/values encoded with specified encoding
    ///    - Filenames for file fields: escape 0x0A → %0A, 0x0D → %0D, 0x22 → %22
    ///    - Non-file fields: no Content-Type header
    ///    - Generate boundary string
    ///
    /// Returns: byte sequence + boundary string
    pub fn serializeMultipart(
        self: *const FormData,
        allocator: Allocator,
        encoding: []const u8,
    ) !struct { []const u8, []const u8 } {
        _ = self;
        _ = allocator;
        _ = encoding;

        // TODO: Implement multipart/form-data encoding
        // This requires:
        // 1. Boundary generation (random string that doesn't appear in data)
        // 2. CRLF normalization
        // 3. Encoding with specified charset
        // 4. RFC 7578 field encoding
        // 5. Content-Disposition headers for each field
        // 6. Content-Type headers for file fields

        @panic("TODO: multipart/form-data serialization requires HTML Standard algorithm implementation");
    }
};

test "FormData - append string entries" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("name", "value");
    try form.appendString("foo", "bar");

    try std.testing.expectEqual(@as(usize, 2), form.entries.items.len);
    try std.testing.expectEqualStrings("name", form.entries.items[0].name);
    try std.testing.expectEqualStrings("value", form.entries.items[0].value.string);
}

test "FormData - append multiple entries with same name" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("key", "value1");
    try form.appendString("key", "value2");
    try form.appendString("key", "value3");

    try std.testing.expectEqual(@as(usize, 3), form.entries.items.len);
}

test "FormData - delete entries" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("a", "1");
    try form.appendString("b", "2");
    try form.appendString("a", "3");

    form.delete("a");

    try std.testing.expectEqual(@as(usize, 1), form.entries.items.len);
    try std.testing.expectEqualStrings("b", form.entries.items[0].name);
}

test "FormData - get first entry" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("key", "first");
    try form.appendString("key", "second");

    const value = form.get("key");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("first", value.?.string);
}

test "FormData - get returns null for missing entry" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    const value = form.get("missing");
    try std.testing.expect(value == null);
}

test "FormData - getAll returns all matching entries" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("key", "value1");
    try form.appendString("other", "x");
    try form.appendString("key", "value2");
    try form.appendString("key", "value3");

    const values = try form.getAll(allocator, "key");
    defer allocator.free(values);

    try std.testing.expectEqual(@as(usize, 3), values.len);
    try std.testing.expectEqualStrings("value1", values[0].string);
    try std.testing.expectEqualStrings("value2", values[1].string);
    try std.testing.expectEqualStrings("value3", values[2].string);
}

test "FormData - has checks existence" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("exists", "yes");

    try std.testing.expect(form.has("exists"));
    try std.testing.expect(!form.has("missing"));
}

test "FormData - set replaces all entries with same name" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("key", "value1");
    try form.appendString("key", "value2");
    try form.appendString("key", "value3");

    try form.setString("key", "replaced");

    try std.testing.expectEqual(@as(usize, 1), form.entries.items.len);
    try std.testing.expectEqualStrings("replaced", form.entries.items[0].value.string);
}

test "FormData - set appends if name doesn't exist" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.setString("new", "value");

    try std.testing.expectEqual(@as(usize, 1), form.entries.items.len);
    try std.testing.expectEqualStrings("new", form.entries.items[0].name);
}

test "FormData - iterator" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    try form.appendString("a", "1");
    try form.appendString("b", "2");
    try form.appendString("c", "3");

    var iter = form.iterator();
    var count: usize = 0;

    while (iter.next()) |entry| {
        count += 1;
        _ = entry;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "FormData - memory safety with many operations" {
    const allocator = std.testing.allocator;

    const form = try FormData.init(allocator);
    defer form.deinit();

    // Add many entries
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "key{d}", .{i});
        defer allocator.free(name);

        const value = try std.fmt.allocPrint(allocator, "value{d}", .{i});
        defer allocator.free(value);

        try form.appendString(name, value);
    }

    // Delete half
    i = 0;
    while (i < 50) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "key{d}", .{i});
        defer allocator.free(name);
        form.delete(name);
    }

    try std.testing.expectEqual(@as(usize, 50), form.entries.items.len);
}
