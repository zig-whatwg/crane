const std = @import("std");
const webidl = @import("webidl");

// Import URL infrastructure from modules (set up in build.zig)
const URLRecord = @import("url_record").URLRecord;
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");

// Import URLSearchParams - use the module name set up in build.zig
// We'll access it through the generated interface
const URLSearchParamsImpl = @import("url_search_params_impl").URLSearchParamsImpl;

pub const URL = webidl.interface(struct {
    // ========================================================================
    // Internal State
    // ========================================================================

    /// The underlying URL record
    /// Spec: https://url.spec.whatwg.org/#concept-url-url (line 1786)
    url_record: URLRecord,

    /// The associated URLSearchParams implementation
    /// Spec: https://url.spec.whatwg.org/#url-query-object (line 1788)
    /// [SameObject] - must return same instance each time
    /// We store the implementation directly to avoid circular module dependencies
    query_impl: *URLSearchParamsImpl,

    allocator: std.mem.Allocator,

    // ========================================================================
    // Constructor
    // ========================================================================

    /// URL constructor: new URL(url, base)
    /// Spec: https://url.spec.whatwg.org/#dom-url-url (lines 1794-1800)
    ///
    /// Steps:
    /// 1. Let parsedURL be the result of running the API URL parser on url with base, if given.
    /// 2. If parsedURL is failure, then throw a TypeError.
    /// 3. Initialize this with parsedURL.
    pub fn init(allocator: std.mem.Allocator, url: []const u8, base: ?[]const u8) !URL {
        // Step 1: Parse base URL if provided
        var base_record: ?URLRecord = null;
        if (base) |base_str| {
            base_record = api_parser.parseURL(allocator, base_str, null) catch {
                return error.TypeError; // Base URL parse failed
            };
        }
        defer if (base_record) |*br| br.deinit();

        // Step 1: Parse URL with optional base
        const parsed_url = api_parser.parseURL(
            allocator,
            url,
            if (base_record) |*br| br else null,
        ) catch {
            // Step 2: If parsedURL is failure, throw TypeError
            return error.TypeError;
        };
        errdefer parsed_url.deinit();

        // Step 3: Initialize this with parsedURL
        return try initializeWithURLRecord(allocator, parsed_url);
    }

    /// Initialize a URL object with a URLRecord
    /// Spec: https://url.spec.whatwg.org/#concept-url-initialize (lines 1782-1793)
    ///
    /// Algorithm:
    /// 1. Let query be urlRecord's query, if that is non-null; otherwise the empty string.
    /// 2. Set url's URL to urlRecord.
    /// 3. Set url's query object to a new URLSearchParams object.
    /// 4. Initialize url's query object with query.
    /// 5. Set url's query object's URL object to url.
    ///
    /// This creates the bidirectional link between URL and URLSearchParams.
    fn initializeWithURLRecord(allocator: std.mem.Allocator, url_record: URLRecord) !URL {
        // Step 1: Let query be urlRecord's query, if non-null; otherwise empty string
        const query = url_record.query() orelse "";

        // Step 3: Create new URLSearchParams object
        // Step 4: Initialize it with query string
        var query_impl = try allocator.create(URLSearchParamsImpl);
        errdefer allocator.destroy(query_impl);

        query_impl.* = try URLSearchParamsImpl.initFromString(allocator, query);
        errdefer query_impl.deinit();

        // Step 2: Create URL with url_record
        var url = URL{
            .url_record = url_record,
            .query_impl = query_impl,
            .allocator = allocator,
        };

        // Step 5: Set query object's URL object to this URL
        // We set it to point back to this URL object for bidirectional sync
        query_impl.url_object = @ptrCast(&url);

        return url;
    }

    pub fn deinit(self: *URL) void {
        self.query_impl.deinit();
        self.allocator.destroy(self.query_impl);
        self.url_record.deinit();
    }

    // ========================================================================
    // Static Methods
    // ========================================================================

    /// URL.parse(url, base) static method
    /// Spec: https://url.spec.whatwg.org/#dom-url-parse (lines 1835-1845)
    ///
    /// Steps:
    /// 1. Let parsedURL be the result of running the API URL parser on url with base, if given.
    /// 2. If parsedURL is failure, then return null.
    /// 3. Return the result of creating a new URL object, with parsedURL,
    ///    in the current realm.
    ///
    /// Unlike the constructor, this returns null instead of throwing on parse failure.
    pub fn parse(allocator: std.mem.Allocator, url: []const u8, base: ?[]const u8) ?URL {
        return init(allocator, url, base) catch null;
    }

    /// URL.canParse(url, base) static method
    /// Spec: https://url.spec.whatwg.org/#dom-url-canparse (lines 1847-1853)
    ///
    /// Steps:
    /// 1. Let parsedURL be the result of running the API URL parser on url with base, if given.
    /// 2. If parsedURL is failure, then return false.
    /// 3. Return true.
    pub fn canParse(allocator: std.mem.Allocator, url: []const u8, base: ?[]const u8) bool {
        // Parse base URL if provided
        var base_record: ?URLRecord = null;
        if (base) |base_str| {
            base_record = api_parser.parseURL(allocator, base_str, null) catch return false;
        }
        defer if (base_record) |*br| br.deinit();

        // Try to parse URL
        const parsed = api_parser.parseURL(
            allocator,
            url,
            if (base_record) |*br| br else null,
        ) catch return false;

        parsed.deinit();
        return true;
    }

    // ========================================================================
    // Attributes (Getters)
    // ========================================================================

    /// href getter (also used by toJSON)
    /// Spec: https://url.spec.whatwg.org/#dom-url-href (line 1855)
    /// Returns the serialization of this's URL
    pub fn href(self: *const URL) ![]const u8 {
        return url_serializer.serialize(self.allocator, &self.url_record, false);
    }

    /// searchParams getter
    /// Spec: https://url.spec.whatwg.org/#dom-url-searchparams (line 1967)
    /// Returns this's query object (via implementation wrapper)
    /// [SameObject] - must return same instance each time
    /// Note: Returns pointer to implementation for now - will wrap in URLSearchParams type later
    pub fn searchParams(self: *const URL) *URLSearchParamsImpl {
        return self.query_impl;
    }

    // ========================================================================
    // Methods
    // ========================================================================

    /// toJSON() method
    /// Spec: https://url.spec.whatwg.org/#dom-url-tojson (line 1855)
    /// Returns the result of running the href getter on this
    pub fn toJSON(self: *const URL) ![]const u8 {
        return self.href();
    }

    // ========================================================================
    // Remaining Attributes (to be implemented in subsequent beads)
    // ========================================================================

    // Getters/setters to be implemented:
    // - whatwg-9fi: href setter
    // - whatwg-mdc: origin getter
    // - whatwg-3xx: protocol getter/setter
    // - whatwg-g49: username getter/setter
    // - whatwg-c7a: password getter/setter
    // - whatwg-ydd: host getter/setter
    // - whatwg-1px: hostname getter/setter
    // - whatwg-yig: port getter/setter
    // - whatwg-398: pathname getter/setter
    // - whatwg-sgc: search getter/setter
    // - whatwg-xwm: hash getter/setter

}, .{
    .exposed = &.{.global},
});
