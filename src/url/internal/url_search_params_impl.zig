//! URLSearchParams Implementation
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#interface-urlsearchparams
//! Spec Reference: Lines 1986-2133
//!
//! URLSearchParams provides methods to work with query strings using the
//! application/x-www-form-urlencoded format.
//!
//! This is the INTERNAL implementation (not the WebIDL-generated WebIDL interface).

const std = @import("std");
const infra = @import("infra");
const Tuple = @import("form_parser").Tuple;
const form_parser = @import("form_parser");
const form_serializer = @import("form_serializer");

/// Record entry type for URLSearchParams initialization (UTF-8)
/// Used by initFromRecord to accept record-style initialization
pub const RecordEntry = struct {
    name: []const u8,
    value: []const u8,
};

/// URLSearchParams internal implementation
///
/// A URLSearchParams object has an associated (spec lines 2036-2039):
/// - list: a list of tuples (name, value)
/// - URL object: null or a URL object
pub const URLSearchParamsImpl = struct {
    allocator: std.mem.Allocator,

    /// List of name-value tuples (spec line 2038)
    list: infra.List(Tuple),

    /// Associated URL object (spec line 2039)
    /// This is a pointer to avoid circular dependencies
    /// When non-null, updating this URLSearchParams will update the URL's query
    url_object: ?*anyopaque,

    /// Initialize with empty list
    pub fn init(allocator: std.mem.Allocator) URLSearchParamsImpl {
        return .{
            .allocator = allocator,
            .list = infra.List(Tuple).init(allocator),
            .url_object = null,
        };
    }

    /// Free resources
    pub fn deinit(self: *URLSearchParamsImpl) void {
        for (0..self.list.len) |i| {
            self.list.get(i).?.deinit(self.allocator);
        }
        self.list.deinit();
    }

    /// Initialize from string (spec lines 2041-2056)
    pub fn initFromString(allocator: std.mem.Allocator, query_init: []const u8) !URLSearchParamsImpl {
        var self = URLSearchParamsImpl.init(allocator);
        errdefer self.deinit();

        // Remove leading ? if present (constructor step 1, line 2069)
        const query_string = if (std.mem.startsWith(u8, query_init, "?"))
            query_init[1..]
        else
            query_init;

        // Parse the query string
        const tuples = try form_parser.parse(allocator, query_string);
        errdefer {
            for (tuples) |tuple| tuple.deinit(allocator);
            allocator.free(tuples);
        }

        // Add to list
        for (tuples) |tuple| {
            try self.list.append(tuple);
        }

        allocator.free(tuples); // Free the array but not the tuples (now owned by list)

        return self;
    }

    /// Initialize from sequence of sequences (spec lines 2043-2047)
    pub fn initFromSequence(allocator: std.mem.Allocator, seq_init: []const [2][]const u8) !URLSearchParamsImpl {
        var self = URLSearchParamsImpl.init(allocator);
        errdefer self.deinit();

        for (seq_init) |pair| {
            const name = try allocator.dupe(u8, pair[0]);
            errdefer allocator.free(name);

            const value = try allocator.dupe(u8, pair[1]);
            errdefer allocator.free(value);

            try self.list.append(.{ .name = name, .value = value });
        }

        return self;
    }

    /// Initialize from record (dictionary/map) (spec lines 2049)
    /// Note: In Zig, we use a slice of key-value pairs to represent a record
    pub fn initFromRecord(allocator: std.mem.Allocator, record_init: []const RecordEntry) !URLSearchParamsImpl {
        var self = URLSearchParamsImpl.init(allocator);
        errdefer self.deinit();

        for (record_init) |entry| {
            const name = try allocator.dupe(u8, entry.name);
            errdefer allocator.free(name);

            const value = try allocator.dupe(u8, entry.value);
            errdefer allocator.free(value);

            try self.list.append(.{ .name = name, .value = value });
        }

        return self;
    }

    /// Update associated URL (spec lines 2057-2065)
    ///
    /// When URLSearchParams is modified, this updates the associated URL's query.
    /// This implements the "live binding" between URLSearchParams and URL.
    fn update(self: *URLSearchParamsImpl) !void {
        // Step 1: If URL object is null, return
        if (self.url_object == null) return;

        // Step 2: Serialize list
        const serialized = try form_serializer.serialize(self.allocator, self.list.items());
        defer self.allocator.free(serialized);

        // Step 3-4: Set URL's query (empty string becomes null)
        // This would be implemented by the URL class
        // For now, we just note that the URL object pointer would be used here

        // TODO: When integrated with URL class:
        // if (serialized.len == 0) {
        //     url_object.internal.query = null;
        // } else {
        //     url_object.internal.query = serialized;
        // }
    }

    /// Get size (spec line 2073)
    pub fn size(self: *const URLSearchParamsImpl) usize {
        return self.list.len;
    }

    /// Append name-value pair (spec lines 2075-2079)
    pub fn append(self: *URLSearchParamsImpl, name: []const u8, value: []const u8) !void {
        // Step 1: Append to list
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        try self.list.append(.{ .name = name_copy, .value = value_copy });

        // Step 2: Update
        try self.update();
    }

    /// Delete name-value pairs (spec lines 2081-2087)
    pub fn delete(self: *URLSearchParamsImpl, name: []const u8, opt_value: ?[]const u8) !void {
        var i: usize = 0;
        while (i < self.list.len) {
            const tuple = self.list.get(i).?;

            const should_remove = if (opt_value) |value|
                // Step 1: Remove if both name and value match
                std.mem.eql(u8, tuple.name, name) and std.mem.eql(u8, tuple.value, value)
            else
                // Step 2: Remove if name matches
                std.mem.eql(u8, tuple.name, name);

            if (should_remove) {
                const removed = self.list.orderedRemove(i);
                removed.deinit(self.allocator);
                // Don't increment i, check same index again
            } else {
                i += 1;
            }
        }

        // Step 3: Update
        try self.update();
    }

    /// Get first value for name (spec line 2089)
    pub fn get(self: *const URLSearchParamsImpl, name: []const u8) ?[]const u8 {
        for (0..self.list.len) |i| {
            const tuple = self.list.get(i).?;
            if (std.mem.eql(u8, tuple.name, name)) {
                return tuple.value;
            }
        }
        return null;
    }

    /// Get all values for name (spec line 2091)
    pub fn getAll(self: *const URLSearchParamsImpl, allocator: std.mem.Allocator, name: []const u8) ![][]const u8 {
        var result = infra.List([]const u8).init(allocator);
        errdefer result.deinit();

        for (0..self.list.len) |i| {
            const tuple = self.list.get(i).?;
            if (std.mem.eql(u8, tuple.name, name)) {
                try result.append(tuple.value);
            }
        }

        return try result.toOwnedSlice();
    }

    /// Check if name exists (spec lines 2093-2099)
    pub fn has(self: *const URLSearchParamsImpl, name: []const u8, opt_value: ?[]const u8) bool {
        if (opt_value) |value| {
            // Step 1: Check if name and value exist
            for (0..self.list.len) |i| {
                const tuple = self.list.get(i).?;
                if (std.mem.eql(u8, tuple.name, name) and std.mem.eql(u8, tuple.value, value)) {
                    return true;
                }
            }
        } else {
            // Step 2: Check if name exists
            for (0..self.list.len) |i| {
                const tuple = self.list.get(i).?;
                if (std.mem.eql(u8, tuple.name, name)) {
                    return true;
                }
            }
        }

        // Step 3: Return false
        return false;
    }

    /// Set name to value (spec lines 2101-2107)
    pub fn set(self: *URLSearchParamsImpl, name: []const u8, value: []const u8) !void {
        var found_first = false;
        var i: usize = 0;

        while (i < self.list.len) {
            const tuple = &self.list.toSliceMut()[i];

            if (std.mem.eql(u8, tuple.name, name)) {
                if (!found_first) {
                    // Step 1: Set value of first matching tuple
                    self.allocator.free(tuple.value);
                    tuple.value = try self.allocator.dupe(u8, value);
                    found_first = true;
                    i += 1;
                } else {
                    // Remove subsequent matching tuples
                    const removed = self.list.orderedRemove(i);
                    removed.deinit(self.allocator);
                    // Don't increment i
                }
            } else {
                i += 1;
            }
        }

        // Step 2: If not found, append
        if (!found_first) {
            const name_copy = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(name_copy);

            const value_copy = try self.allocator.dupe(u8, value);
            errdefer self.allocator.free(value_copy);

            try self.list.append(.{ .name = name_copy, .value = value_copy });
        }

        // Step 3: Update
        try self.update();
    }

    /// Sort list by name (spec lines 2124-2128)
    pub fn sort(self: *URLSearchParamsImpl) !void {
        // Step 1: Sort in ascending order by name (code unit less than)
        const Context = struct {
            fn lessThan(_: void, a: Tuple, b: Tuple) bool {
                return std.mem.order(u8, a.name, b.name) == .lt;
            }
        };

        std.mem.sort(Tuple, self.list.items(), {}, Context.lessThan);

        // Step 2: Update
        try self.update();
    }

    /// Serialize to string (spec line 2132)
    pub fn toString(self: *const URLSearchParamsImpl, allocator: std.mem.Allocator) ![]u8 {
        return form_serializer.serialize(allocator, self.list.items());
    }
};

// ============================================================================
// Tests
// ============================================================================













