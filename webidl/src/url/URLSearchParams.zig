const std = @import("std");
const webidl = @import("webidl");

// Import internal implementation
const URLSearchParamsImpl = @import("url_search_params_impl").URLSearchParamsImpl;

pub const URLSearchParams = webidl.interface(struct {
    // ========================================================================
    // Internal Implementation
    // ========================================================================

    /// The internal implementation wrapping all the logic
    impl: URLSearchParamsImpl,

    // ========================================================================
    // Constructor
    // ========================================================================

    /// Initialize URLSearchParams with empty list
    pub fn init(allocator: std.mem.Allocator) !URLSearchParams {
        return .{
            .impl = URLSearchParamsImpl.init(allocator),
        };
    }

    /// Initialize URLSearchParams from query string
    /// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new (lines 2041-2056)
    /// This implements step 3 of the initialize algorithm (init is a string)
    pub fn initWithString(allocator: std.mem.Allocator, query: []const u8) !URLSearchParams {
        return .{
            .impl = try URLSearchParamsImpl.initFromString(allocator, query),
        };
    }

    /// Initialize URLSearchParams from sequence of sequences
    /// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new (lines 2043-2047)
    /// This implements step 1 of the initialize algorithm (init is a sequence)
    /// Each inner sequence must have exactly 2 elements (name, value)
    pub fn initWithSequence(allocator: std.mem.Allocator, sequence: []const [2][]const u8) !URLSearchParams {
        return .{
            .impl = try URLSearchParamsImpl.initFromSequence(allocator, sequence),
        };
    }

    /// Initialize URLSearchParams from record (key-value pairs)
    /// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new (lines 2049)
    /// This implements step 2 of the initialize algorithm (init is a record)
    pub fn initWithRecord(allocator: std.mem.Allocator, record: []const URLSearchParamsImpl.RecordEntry) !URLSearchParams {
        return .{
            .impl = try URLSearchParamsImpl.initFromRecord(allocator, record),
        };
    }

    pub fn deinit(self: *URLSearchParams) void {
        self.impl.deinit();
    }

    // ========================================================================
    // Update Steps Algorithm
    // ========================================================================

    /// Update a URLSearchParams object
    /// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-update (lines 2057-2065)
    pub fn updateSteps(self: *URLSearchParams) !void {
        try self.impl.update();
    }

    // ========================================================================
    // Attributes
    // ========================================================================

    /// size attribute getter
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-size (line 2062)
    pub fn size(self: *const URLSearchParams) usize {
        return self.impl.list.items.len;
    }

    // ========================================================================
    // Methods (delegate to impl)
    // ========================================================================

    /// append(name, value) method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-append (lines 2064-2066)
    /// Appends name-value pair to list, runs update steps
    pub fn append(self: *URLSearchParams, name: []const u8, value: []const u8) !void {
        try self.impl.append(name, value);
    }

    /// delete(name, value?) method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-delete (lines 2068-2073)
    /// Removes tuples matching name (and optionally value), runs update steps
    pub fn delete(self: *URLSearchParams, name: []const u8, value: ?[]const u8) !void {
        try self.impl.delete(name, value);
    }

    /// get(name) method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-get (lines 2075-2080)
    /// Returns value of first tuple with given name, or null
    pub fn get(self: *const URLSearchParams, name: []const u8) ?[]const u8 {
        return self.impl.get(name);
    }

    /// getAll(name) method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-getall (lines 2082-2091)
    /// Returns sequence of all values for tuples with given name
    pub fn getAll(self: *const URLSearchParams, allocator: std.mem.Allocator, name: []const u8) ![][]const u8 {
        return self.impl.getAll(allocator, name);
    }

    /// has(name, value?) method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-has (lines 2093-2098)
    /// Returns true if list contains tuple matching name (and optionally value)
    pub fn has(self: *const URLSearchParams, name: []const u8, value: ?[]const u8) bool {
        return self.impl.has(name, value);
    }

    /// set(name, value) method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-set (lines 2100-2109)
    /// Sets value of first tuple with name, removes others, or appends if not found
    pub fn set(self: *URLSearchParams, name: []const u8, value: []const u8) !void {
        try self.impl.set(name, value);
    }

    /// sort() method
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-sort (lines 2111-2113)
    /// Sorts tuples by name (stable sort), runs update steps
    pub fn sort(self: *URLSearchParams) !void {
        try self.impl.sort();
    }

    /// toString() method (stringifier)
    /// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-stringifier (lines 2121-2123)
    /// Serializes list to application/x-www-form-urlencoded format
    pub fn toString(self: *const URLSearchParams, allocator: std.mem.Allocator) ![]u8 {
        return self.impl.toString(allocator);
    }

    // ========================================================================
    // Iteration Support
    // ========================================================================

    // TODO (whatwg-1wv): Implement iteration support
    // - Value iterator: iterates over list returning tuples
    // - Entries, keys, values iterators
    // - iterable<USVString, USVString> declaration
    // This requires understanding Zig's iterator patterns for WebIDL

}, .{
    .exposed = &.{.global},
});
