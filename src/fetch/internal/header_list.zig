//! Header List - WHATWG Fetch Standard
//!
//! A header list is a list of zero or more headers. It is essentially a
//! specialized multimap: an ordered list of key-value pairs with potentially
//! duplicate keys.
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-header-list

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A header is a tuple that consists of a name and value.
/// Spec: https://fetch.spec.whatwg.org/#concept-header
pub const Header = struct {
    /// Header name (case-preserved but case-insensitive matching)
    name: []const u8,
    /// Header value
    value: []const u8,

    /// Create a header with owned copies of name and value
    pub fn init(allocator: Allocator, name: []const u8, value: []const u8) !Header {
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_value = try allocator.dupe(u8, value);
        return .{
            .name = owned_name,
            .value = owned_value,
        };
    }

    /// Free the header's owned memory
    pub fn deinit(self: *Header, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.value);
    }

    /// Clone this header
    pub fn clone(self: Header, allocator: Allocator) !Header {
        return Header.init(allocator, self.name, self.value);
    }
};

/// A header list is a list of zero or more headers.
/// Spec: https://fetch.spec.whatwg.org/#concept-header-list
pub const HeaderList = struct {
    allocator: Allocator,
    entries: std.ArrayListUnmanaged(Header),

    /// HTTP tab or space bytes (0x09 or 0x20)
    const HTTP_TAB_OR_SPACE = [_]u8{ 0x09, 0x20 };

    /// Create a new empty header list
    pub fn init(allocator: Allocator) HeaderList {
        return .{
            .allocator = allocator,
            .entries = .{},
        };
    }

    /// Free all memory associated with this header list
    pub fn deinit(self: *HeaderList) void {
        for (self.entries.items) |*header| {
            header.deinit(self.allocator);
        }
        self.entries.deinit(self.allocator);
    }

    /// Check if list contains a header name (byte-case-insensitive match).
    ///
    /// Spec: "A header list `list` contains a header name `name` if `list`
    /// contains a header whose name is a byte-case-insensitive match for `name`."
    pub fn contains(self: *const HeaderList, name: []const u8) bool {
        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                return true;
            }
        }
        return false;
    }

    /// Get combined value of all headers with name, separated by `, `.
    ///
    /// Spec: "Return the values of all headers in `list` whose name is a
    /// byte-case-insensitive match for `name`, separated from each other
    /// by 0x2C 0x20, in order."
    ///
    /// Returns null if no header with name exists.
    /// Caller owns returned memory.
    pub fn get(self: *const HeaderList, allocator: Allocator, name: []const u8) !?[]const u8 {
        var values = std.ArrayListUnmanaged([]const u8){};
        defer values.deinit(allocator);

        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                try values.append(allocator, header.value);
            }
        }

        if (values.items.len == 0) {
            return null;
        }

        // Join with ", " (0x2C 0x20)
        return try std.mem.join(allocator, ", ", values.items);
    }

    /// Get all values for Set-Cookie headers (never combined).
    ///
    /// Set-Cookie headers are special and must not be combined per spec.
    /// Returns a list of all Set-Cookie values.
    /// Caller owns returned memory.
    pub fn getSetCookie(self: *const HeaderList, allocator: Allocator) ![]const []const u8 {
        var values = std.ArrayListUnmanaged([]const u8){};
        errdefer {
            for (values.items) |v| allocator.free(v);
            values.deinit(allocator);
        }

        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "set-cookie")) {
                try values.append(allocator, try allocator.dupe(u8, header.value));
            }
        }

        return try values.toOwnedSlice(allocator);
    }

    /// Get, decode (isomorphic), and split a header value on commas.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#concept-header-list-get-decode-split
    ///
    /// Returns null if header doesn't exist.
    /// Caller owns returned memory.
    pub fn getDecodeSplit(self: *const HeaderList, allocator: Allocator, name: []const u8) !?[]const []const u8 {
        const value = try self.get(allocator, name) orelse return null;
        defer allocator.free(value);

        return try getDecodeSplitValue(allocator, value);
    }

    /// Get, decode, and split a header value.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#concept-header-list-get-decode-split
    /// This implements the algorithm at step 3 onwards.
    pub fn getDecodeSplitValue(allocator: Allocator, value: []const u8) ![]const []const u8 {
        // Step 1: Let `input` be the result of isomorphic decoding `value`.
        // (In Zig, bytes are already the "decoded" representation)
        const input = value;

        var values = std.ArrayListUnmanaged([]const u8){};
        errdefer {
            for (values.items) |v| allocator.free(v);
            values.deinit(allocator);
        }

        // Step 2: Let `position` be a position variable for `input`
        var position: usize = 0;

        // Step 4: Let `temporaryValue` be the empty string
        var temporary_value = std.ArrayListUnmanaged(u8){};
        defer temporary_value.deinit(allocator);

        // Step 5: While true
        while (true) {
            // Step 5.1: Collect sequence of code points that are not " or ,
            while (position < input.len and input[position] != '"' and input[position] != ',') {
                try temporary_value.append(allocator, input[position]);
                position += 1;
            }

            // Step 5.2: If position is not past end and code point is "
            if (position < input.len and input[position] == '"') {
                // Collect HTTP quoted string
                const quoted = try collectHttpQuotedString(allocator, input, &position);
                defer allocator.free(quoted);
                try temporary_value.appendSlice(allocator, quoted);

                // If position is not past end, continue
                if (position < input.len) {
                    continue;
                }
            }

            // Step 5.3: Remove HTTP tab or space from start and end
            const trimmed = trimHttpWhitespace(temporary_value.items);

            // Step 5.4: Append temporaryValue to values
            try values.append(allocator, try allocator.dupe(u8, trimmed));

            // Step 5.5: Set temporaryValue to empty string
            temporary_value.clearRetainingCapacity();

            // Step 5.6: If position is past end, return values
            if (position >= input.len) {
                return try values.toOwnedSlice(allocator);
            }

            // Step 5.7: Assert code point is ,
            std.debug.assert(input[position] == ',');

            // Step 5.8: Advance position by 1
            position += 1;
        }
    }

    /// Append a header to the list.
    ///
    /// Spec: "If `list` contains `name`, then set `name` to the first such
    /// header's name. This reuses the casing of the name of the header
    /// already in `list`, if any."
    pub fn append(self: *HeaderList, name: []const u8, value: []const u8) !void {
        // Step 1: If list contains name, reuse existing casing
        var actual_name = name;
        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                actual_name = header.name;
                break;
            }
        }

        // Step 2: Append (name, value) to list
        const header = try Header.init(self.allocator, actual_name, value);
        errdefer {
            var h = header;
            h.deinit(self.allocator);
        }
        try self.entries.append(self.allocator, header);
    }

    /// Delete all headers with the given name.
    ///
    /// Spec: "Remove all headers whose name is a byte-case-insensitive match
    /// for `name` from `list`."
    pub fn delete(self: *HeaderList, name: []const u8) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            if (std.ascii.eqlIgnoreCase(self.entries.items[i].name, name)) {
                var removed = self.entries.orderedRemove(i);
                removed.deinit(self.allocator);
            } else {
                i += 1;
            }
        }
    }

    /// Set a header, replacing any existing headers with the same name.
    ///
    /// Spec: "If `list` contains `name`, then set the value of the first
    /// such header to `value` and remove the others. Otherwise, append
    /// (`name`, `value`) to `list`."
    pub fn set(self: *HeaderList, name: []const u8, value: []const u8) !void {
        var found_first = false;
        var i: usize = 0;

        while (i < self.entries.items.len) {
            if (std.ascii.eqlIgnoreCase(self.entries.items[i].name, name)) {
                if (!found_first) {
                    // Set value of first matching header
                    self.allocator.free(self.entries.items[i].value);
                    self.entries.items[i].value = try self.allocator.dupe(u8, value);
                    found_first = true;
                    i += 1;
                } else {
                    // Remove subsequent matching headers
                    var removed = self.entries.orderedRemove(i);
                    removed.deinit(self.allocator);
                }
            } else {
                i += 1;
            }
        }

        // If not found, append
        if (!found_first) {
            try self.append(name, value);
        }
    }

    /// Combine a header value with existing value using `, `.
    ///
    /// Spec: "If `list` contains `name`, then set the value of the first such
    /// header to its value, followed by 0x2C 0x20, followed by `value`.
    /// Otherwise, append (`name`, `value`) to `list`."
    pub fn combine(self: *HeaderList, name: []const u8, value: []const u8) !void {
        for (self.entries.items) |*header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                // Combine: existing value + ", " + new value
                const new_value = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}, {s}",
                    .{ header.value, value },
                );
                self.allocator.free(header.value);
                header.value = new_value;
                return;
            }
        }

        // Not found, append
        try self.append(name, value);
    }

    /// Sort and combine the header list.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#concept-header-list-sort-and-combine
    ///
    /// Special handling for Set-Cookie: values are NOT combined.
    /// Returns a new header list. Caller owns returned memory.
    pub fn sortAndCombine(self: *const HeaderList, allocator: Allocator) !HeaderList {
        // Step 1: Let headers be a new header list
        var headers = HeaderList.init(allocator);
        errdefer headers.deinit();

        // Step 2: Get sorted lowercase names
        var names_set = std.StringHashMap(void).init(allocator);
        defer names_set.deinit();

        var lowercase_names = std.ArrayListUnmanaged([]const u8){};
        defer {
            for (lowercase_names.items) |n| allocator.free(n);
            lowercase_names.deinit(allocator);
        }

        for (self.entries.items) |header| {
            const lower = try std.ascii.allocLowerString(allocator, header.name);
            if (!names_set.contains(lower)) {
                try names_set.put(lower, {});
                try lowercase_names.append(allocator, lower);
            } else {
                allocator.free(lower);
            }
        }

        // Sort names
        std.mem.sort([]const u8, lowercase_names.items, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan);

        // Step 3: For each name
        for (lowercase_names.items) |name| {
            if (std.ascii.eqlIgnoreCase(name, "set-cookie")) {
                // Step 3.1: Set-Cookie - don't combine
                for (self.entries.items) |header| {
                    if (std.ascii.eqlIgnoreCase(header.name, "set-cookie")) {
                        try headers.append(name, header.value);
                    }
                }
            } else {
                // Step 3.2: Other headers - combine
                const combined = try self.get(allocator, name) orelse continue;
                defer allocator.free(combined);
                try headers.append(name, combined);
            }
        }

        return headers;
    }

    /// Create a deep copy of this header list.
    pub fn clone(self: *const HeaderList, allocator: Allocator) !HeaderList {
        var new_list = HeaderList.init(allocator);
        errdefer new_list.deinit();

        for (self.entries.items) |header| {
            const new_header = try header.clone(allocator);
            errdefer {
                var h = new_header;
                h.deinit(allocator);
            }
            try new_list.entries.append(allocator, new_header);
        }

        return new_list;
    }

    /// Get the number of headers in the list
    pub fn len(self: *const HeaderList) usize {
        return self.entries.items.len;
    }

    /// Check if the list is empty
    pub fn isEmpty(self: *const HeaderList) bool {
        return self.entries.items.len == 0;
    }

    /// Iterator over headers
    pub fn iterator(self: *const HeaderList) []const Header {
        return self.entries.items;
    }

    // =========================================================================
    // Helper functions
    // =========================================================================

    /// Collect an HTTP quoted string from input starting at position.
    /// Spec: https://fetch.spec.whatwg.org/#collect-an-http-quoted-string
    fn collectHttpQuotedString(allocator: Allocator, input: []const u8, position: *usize) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        // Step 1: Assert position is at "
        std.debug.assert(position.* < input.len and input[position.*] == '"');

        // Step 2: Advance past opening quote
        position.* += 1;

        // Step 3: While true
        while (true) {
            // Collect code points that are not " or \
            while (position.* < input.len and input[position.*] != '"' and input[position.*] != '\\') {
                try result.append(allocator, input[position.*]);
                position.* += 1;
            }

            if (position.* >= input.len) {
                break;
            }

            const quote_or_backslash = input[position.*];
            position.* += 1;

            if (quote_or_backslash == '\\') {
                if (position.* < input.len) {
                    try result.append(allocator, input[position.*]);
                    position.* += 1;
                } else {
                    try result.append(allocator, '\\');
                    break;
                }
            } else {
                // quote_or_backslash == '"'
                break;
            }
        }

        return try result.toOwnedSlice(allocator);
    }

    /// Trim HTTP tab or space (0x09, 0x20) from start and end of value.
    fn trimHttpWhitespace(value: []const u8) []const u8 {
        var start: usize = 0;
        var end: usize = value.len;

        while (start < end and (value[start] == 0x09 or value[start] == 0x20)) {
            start += 1;
        }

        while (end > start and (value[end - 1] == 0x09 or value[end - 1] == 0x20)) {
            end -= 1;
        }

        return value[start..end];
    }
};

/// Normalize a header value by removing leading/trailing HTTP whitespace.
///
/// Spec: "To normalize a byte sequence `potentialValue`, remove any leading
/// and trailing HTTP whitespace bytes from `potentialValue`."
pub fn normalize(value: []const u8) []const u8 {
    return HeaderList.trimHttpWhitespace(value);
}

// =============================================================================
// Tests
// =============================================================================

test "HeaderList: init and deinit" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try std.testing.expect(list.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), list.len());
}

test "HeaderList: append and contains" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Content-Type", "text/html");
    try std.testing.expect(list.contains("Content-Type"));
    try std.testing.expect(list.contains("content-type")); // case-insensitive
    try std.testing.expect(list.contains("CONTENT-TYPE")); // case-insensitive
    try std.testing.expect(!list.contains("Accept"));
}

test "HeaderList: append preserves existing name casing" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Content-Type", "text/html");
    try list.append("content-type", "text/plain"); // should use "Content-Type"

    try std.testing.expectEqual(@as(usize, 2), list.len());
    try std.testing.expectEqualStrings("Content-Type", list.entries.items[0].name);
    try std.testing.expectEqualStrings("Content-Type", list.entries.items[1].name);
}

test "HeaderList: get combines values with comma-space" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Accept", "text/html");
    try list.append("Accept", "application/json");

    const value = try list.get(allocator, "Accept") orelse unreachable;
    defer allocator.free(value);

    try std.testing.expectEqualStrings("text/html, application/json", value);
}

test "HeaderList: get returns null for non-existent header" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    const value = try list.get(allocator, "Accept");
    try std.testing.expect(value == null);
}

test "HeaderList: delete removes all matching headers" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Accept", "text/html");
    try list.append("Content-Type", "text/plain");
    try list.append("Accept", "application/json");

    list.delete("Accept");

    try std.testing.expectEqual(@as(usize, 1), list.len());
    try std.testing.expect(!list.contains("Accept"));
    try std.testing.expect(list.contains("Content-Type"));
}

test "HeaderList: set replaces first and removes others" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Accept", "text/html");
    try list.append("Accept", "application/json");
    try list.append("Content-Type", "text/plain");

    try list.set("Accept", "application/xml");

    try std.testing.expectEqual(@as(usize, 2), list.len());

    const value = try list.get(allocator, "Accept") orelse unreachable;
    defer allocator.free(value);
    try std.testing.expectEqualStrings("application/xml", value);
}

test "HeaderList: set appends if not found" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.set("Accept", "text/html");

    try std.testing.expectEqual(@as(usize, 1), list.len());
    try std.testing.expect(list.contains("Accept"));
}

test "HeaderList: combine appends to existing value" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Accept", "text/html");
    try list.combine("Accept", "application/json");

    const value = try list.get(allocator, "Accept") orelse unreachable;
    defer allocator.free(value);
    try std.testing.expectEqualStrings("text/html, application/json", value);
}

test "HeaderList: combine appends if not found" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.combine("Accept", "text/html");

    try std.testing.expectEqual(@as(usize, 1), list.len());
    const value = try list.get(allocator, "Accept") orelse unreachable;
    defer allocator.free(value);
    try std.testing.expectEqualStrings("text/html", value);
}

test "HeaderList: getSetCookie returns separate values" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Set-Cookie", "a=1");
    try list.append("Set-Cookie", "b=2");
    try list.append("Content-Type", "text/html");

    const cookies = try list.getSetCookie(allocator);
    defer {
        for (cookies) |c| allocator.free(c);
        allocator.free(cookies);
    }

    try std.testing.expectEqual(@as(usize, 2), cookies.len);
    try std.testing.expectEqualStrings("a=1", cookies[0]);
    try std.testing.expectEqualStrings("b=2", cookies[1]);
}

test "HeaderList: sortAndCombine sorts and combines (except Set-Cookie)" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Content-Type", "text/html");
    try list.append("Accept", "text/html");
    try list.append("Set-Cookie", "a=1");
    try list.append("Accept", "application/json");
    try list.append("Set-Cookie", "b=2");

    var sorted = try list.sortAndCombine(allocator);
    defer sorted.deinit();

    // Should be sorted: accept, content-type, set-cookie, set-cookie
    try std.testing.expectEqual(@as(usize, 4), sorted.len());

    try std.testing.expectEqualStrings("accept", sorted.entries.items[0].name);
    try std.testing.expectEqualStrings("text/html, application/json", sorted.entries.items[0].value);

    try std.testing.expectEqualStrings("content-type", sorted.entries.items[1].name);
    try std.testing.expectEqualStrings("text/html", sorted.entries.items[1].value);

    try std.testing.expectEqualStrings("set-cookie", sorted.entries.items[2].name);
    try std.testing.expectEqualStrings("a=1", sorted.entries.items[2].value);

    try std.testing.expectEqualStrings("set-cookie", sorted.entries.items[3].name);
    try std.testing.expectEqualStrings("b=2", sorted.entries.items[3].value);
}

test "HeaderList: clone creates independent copy" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Accept", "text/html");

    var cloned = try list.clone(allocator);
    defer cloned.deinit();

    // Modify original
    list.delete("Accept");

    // Cloned should be unaffected
    try std.testing.expect(cloned.contains("Accept"));
    try std.testing.expect(!list.contains("Accept"));
}

test "HeaderList: getDecodeSplit basic" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("A", "nosniff,");

    const values = try list.getDecodeSplit(allocator, "A") orelse unreachable;
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }

    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqualStrings("nosniff", values[0]);
    try std.testing.expectEqualStrings("", values[1]);
}

test "HeaderList: getDecodeSplit with quotes" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("A", "\"1,2\", 3");

    const values = try list.getDecodeSplit(allocator, "A") orelse unreachable;
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }

    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqualStrings("1,2", values[0]);
    try std.testing.expectEqualStrings("3", values[1]);
}

test "HeaderList: getDecodeSplit returns null for missing header" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    const values = try list.getDecodeSplit(allocator, "B");
    try std.testing.expect(values == null);
}

test "normalize: removes HTTP whitespace" {
    try std.testing.expectEqualStrings("value", normalize("  value  "));
    try std.testing.expectEqualStrings("value", normalize("\tvalue\t"));
    try std.testing.expectEqualStrings("value", normalize(" \t value \t "));
    try std.testing.expectEqualStrings("", normalize("   "));
    try std.testing.expectEqualStrings("a b c", normalize("  a b c  "));
}

test "HeaderList: empty value handling" {
    const allocator = std.testing.allocator;
    var list = HeaderList.init(allocator);
    defer list.deinit();

    try list.append("Accept", "");

    const value = try list.get(allocator, "Accept") orelse unreachable;
    defer allocator.free(value);
    try std.testing.expectEqualStrings("", value);
}
