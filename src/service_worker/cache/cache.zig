//! Cache Interface
//!
//! Stores Request/Response pairs for offline access.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cache-interface
//!
//! WebIDL:
//! ```idl
//! [SecureContext, Exposed=(Window,Worker)]
//! interface Cache {
//!   [NewObject] Promise<(Response or undefined)> match(RequestInfo request, optional CacheQueryOptions options = {});
//!   [NewObject] Promise<FrozenArray<Response>> matchAll(optional RequestInfo request, optional CacheQueryOptions options = {});
//!   [NewObject] Promise<undefined> add(RequestInfo request);
//!   [NewObject] Promise<undefined> addAll(sequence<RequestInfo> requests);
//!   [NewObject] Promise<undefined> put(RequestInfo request, Response response);
//!   [NewObject] Promise<boolean> delete(RequestInfo request, optional CacheQueryOptions options = {});
//!   [NewObject] Promise<FrozenArray<Request>> keys(optional RequestInfo request, optional CacheQueryOptions options = {});
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const CacheQueryOptions = types.CacheQueryOptions;
const CacheEntry = types.CacheEntry;
const StoredRequest = types.StoredRequest;
const StoredResponse = types.StoredResponse;
const HeaderEntry = types.HeaderEntry;

const vary = @import("vary.zig");

const iface_types = @import("../interfaces/types.zig");
const Promise = iface_types.Promise;
const VoidPromise = iface_types.VoidPromise;
const BoolPromise = iface_types.BoolPromise;

/// Cache interface.
///
/// Stores Request/Response pairs for offline access.
///
/// Spec: https://w3c.github.io/ServiceWorker/#cache-interface
pub const Cache = struct {
    allocator: Allocator,

    /// Cache name (for identification).
    name: []const u8,

    /// Request/Response list.
    entries: std.ArrayListUnmanaged(*CacheEntry),

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    pub fn init(allocator: Allocator, name: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const name_copy = try allocator.dupe(u8, name);

        self.* = .{
            .allocator = allocator,
            .name = name_copy,
            .entries = .{},
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.entries.items) |entry| {
            entry.deinit();
        }
        self.entries.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Find the first matching response.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-match
    pub fn match(
        self: *Self,
        request_url: []const u8,
        request_method: []const u8,
        request_headers: []const HeaderEntry,
        options: CacheQueryOptions,
    ) !Promise(?*StoredResponse) {
        var promise = Promise(?*StoredResponse).init();

        // Create a temporary stored request for matching
        const temp_request = try StoredRequest.init(
            self.allocator,
            request_url,
            request_method,
            request_headers,
        );
        defer temp_request.deinit();

        // Find first match
        for (self.entries.items) |entry| {
            if (vary.requestMatches(temp_request, entry.request, entry.response, options)) {
                promise.resolve(entry.response);
                return promise;
            }
        }

        promise.resolve(null);
        return promise;
    }

    /// Find all matching responses.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-matchall
    pub fn matchAll(
        self: *Self,
        request_url: ?[]const u8,
        request_method: ?[]const u8,
        request_headers: []const HeaderEntry,
        options: CacheQueryOptions,
    ) !Promise([]*StoredResponse) {
        var promise = Promise([]*StoredResponse).init();

        var results = std.ArrayList(*StoredResponse).init(self.allocator);
        errdefer results.deinit();

        // If no request specified, return all responses
        if (request_url == null) {
            for (self.entries.items) |entry| {
                try results.append(entry.response);
            }
            promise.resolve(try results.toOwnedSlice());
            return promise;
        }

        // Create temporary request for matching
        const temp_request = try StoredRequest.init(
            self.allocator,
            request_url.?,
            request_method orelse "GET",
            request_headers,
        );
        defer temp_request.deinit();

        // Find all matches
        for (self.entries.items) |entry| {
            if (vary.requestMatches(temp_request, entry.request, entry.response, options)) {
                try results.append(entry.response);
            }
        }

        promise.resolve(try results.toOwnedSlice());
        return promise;
    }

    /// Store a request/response pair.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-put
    pub fn put(
        self: *Self,
        request_url: []const u8,
        request_method: []const u8,
        request_headers: []const HeaderEntry,
        response_status: u16,
        response_status_text: []const u8,
        response_headers: []const HeaderEntry,
        response_body: ?[]const u8,
        response_type: types.ResponseType,
    ) !VoidPromise {
        var promise = VoidPromise.init();

        // Create stored request
        const stored_request = try StoredRequest.init(
            self.allocator,
            request_url,
            request_method,
            request_headers,
        );
        errdefer stored_request.deinit();

        // Create stored response
        const stored_response = try StoredResponse.init(
            self.allocator,
            response_status,
            response_status_text,
            response_headers,
            response_body,
            response_type,
        );
        errdefer stored_response.deinit();

        // Remove any existing entries that match
        try self.deleteMatching(stored_request, .{});

        // Create cache entry
        const entry = try CacheEntry.init(self.allocator, stored_request, stored_response);
        errdefer entry.deinit();

        try self.entries.append(self.allocator, entry);

        promise.resolve({});
        return promise;
    }

    /// Delete matching entries.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-delete
    pub fn delete(
        self: *Self,
        request_url: []const u8,
        request_method: []const u8,
        request_headers: []const HeaderEntry,
        options: CacheQueryOptions,
    ) !BoolPromise {
        var promise = BoolPromise.init();

        // Create temporary request for matching
        const temp_request = try StoredRequest.init(
            self.allocator,
            request_url,
            request_method,
            request_headers,
        );
        defer temp_request.deinit();

        const deleted = try self.deleteMatching(temp_request, options);
        promise.resolve(deleted);
        return promise;
    }

    /// Get all stored request keys.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-keys
    pub fn keys(
        self: *Self,
        request_url: ?[]const u8,
        request_method: ?[]const u8,
        request_headers: []const HeaderEntry,
        options: CacheQueryOptions,
    ) !Promise([]*StoredRequest) {
        var promise = Promise([]*StoredRequest).init();

        var results = std.ArrayList(*StoredRequest).init(self.allocator);
        errdefer results.deinit();

        // If no request specified, return all requests
        if (request_url == null) {
            for (self.entries.items) |entry| {
                try results.append(entry.request);
            }
            promise.resolve(try results.toOwnedSlice());
            return promise;
        }

        // Create temporary request for matching
        const temp_request = try StoredRequest.init(
            self.allocator,
            request_url.?,
            request_method orelse "GET",
            request_headers,
        );
        defer temp_request.deinit();

        // Find all matching requests
        for (self.entries.items) |entry| {
            if (vary.requestMatches(temp_request, entry.request, entry.response, options)) {
                try results.append(entry.request);
            }
        }

        promise.resolve(try results.toOwnedSlice());
        return promise;
    }

    // =========================================================================
    // Internal Methods
    // =========================================================================

    /// Delete all entries matching the request.
    fn deleteMatching(self: *Self, request: *const StoredRequest, options: CacheQueryOptions) !bool {
        var deleted = false;
        var i: usize = 0;

        while (i < self.entries.items.len) {
            const entry = self.entries.items[i];
            if (vary.requestMatches(request, entry.request, entry.response, options)) {
                _ = self.entries.orderedRemove(i);
                entry.deinit();
                deleted = true;
                // Don't increment i - next item moved to current position
            } else {
                i += 1;
            }
        }

        return deleted;
    }

    /// Get the number of entries.
    pub fn count(self: *const Self) usize {
        return self.entries.items.len;
    }

    /// Check if cache is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.entries.items.len == 0;
    }

    // =========================================================================
    // Add Methods (Fetch + Cache)
    // =========================================================================

    /// Fetch a request and store it in the cache.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-add
    ///
    /// Algorithm:
    /// 1. Let request be the associated request of the result of invoking the
    ///    Request constructor with requestInfo.
    /// 2. If request's scheme is not one of "http" and "https", return a promise
    ///    rejected with a TypeError.
    /// 3. Set request's response tainting to "cors".
    /// 4. Let responsePromise be the result of fetching request.
    /// 5. When responsePromise fulfills with response:
    ///    a. If response's type is "error", reject.
    ///    b. If response's status is not an ok status, reject.
    ///    c. If request's method is not GET, reject.
    ///    d. Create cache entry and store in cache.
    pub fn add(
        self: *Self,
        request_url: []const u8,
        fetch_fn: *const fn (allocator: Allocator, url: []const u8) FetchResult,
    ) !VoidPromise {
        var promise = VoidPromise.init();

        // Step 1-2: Validate URL scheme
        if (!isValidCacheScheme(request_url)) {
            promise.reject(error.TypeError);
            return promise;
        }

        // Step 4: Perform fetch
        const fetch_result = fetch_fn(self.allocator, request_url);

        // Step 5a: Check for error response
        if (fetch_result.is_error) {
            promise.reject(error.TypeError);
            return promise;
        }

        // Step 5b: Check for ok status (2xx)
        if (fetch_result.status < 200 or fetch_result.status >= 300) {
            promise.reject(error.TypeError);
            return promise;
        }

        // Step 5d: Store in cache
        const put_promise = try self.put(
            request_url,
            "GET",
            &[_]HeaderEntry{},
            fetch_result.status,
            fetch_result.status_text,
            fetch_result.headers,
            fetch_result.body,
            .basic,
        );

        if (put_promise.isFulfilled()) {
            promise.resolve({});
        } else if (put_promise.isRejected()) {
            promise.reject(put_promise.err.?);
        }

        return promise;
    }

    /// Fetch multiple requests and store them all in the cache.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#cache-addAll
    ///
    /// Algorithm:
    /// 1. For each requestInfo in requestInfos:
    ///    a. Let request be the associated request of the result of invoking the
    ///       Request constructor with requestInfo.
    ///    b. If request's scheme is not one of "http" and "https", return a promise
    ///       rejected with a TypeError.
    ///    c. If request's method is not GET, return a promise rejected with a TypeError.
    ///    d. Set request's response tainting to "cors".
    /// 2. Let responsePromises be an empty list.
    /// 3. For each request in requests, add fetch(request) to responsePromises.
    /// 4. Wait for all promises to settle.
    /// 5. For each response, if error or not ok, reject.
    /// 6. Batch store all request/response pairs.
    pub fn addAll(
        self: *Self,
        request_urls: []const []const u8,
        fetch_fn: *const fn (allocator: Allocator, url: []const u8) FetchResult,
    ) !VoidPromise {
        var promise = VoidPromise.init();

        // Step 1: Validate all URLs first
        for (request_urls) |url| {
            if (!isValidCacheScheme(url)) {
                promise.reject(error.TypeError);
                return promise;
            }
        }

        // Step 2-4: Fetch all requests
        var fetch_results = std.ArrayList(FetchResult).init(self.allocator);
        defer fetch_results.deinit();

        for (request_urls) |url| {
            const result = fetch_fn(self.allocator, url);
            try fetch_results.append(result);
        }

        // Step 5: Check all responses
        for (fetch_results.items) |result| {
            if (result.is_error) {
                promise.reject(error.TypeError);
                return promise;
            }
            if (result.status < 200 or result.status >= 300) {
                promise.reject(error.TypeError);
                return promise;
            }
        }

        // Step 6: Store all request/response pairs
        for (request_urls, 0..) |url, i| {
            const result = fetch_results.items[i];
            _ = try self.put(
                url,
                "GET",
                &[_]HeaderEntry{},
                result.status,
                result.status_text,
                result.headers,
                result.body,
                .basic,
            );
        }

        promise.resolve({});
        return promise;
    }
};

/// Result of a fetch operation for add/addAll.
pub const FetchResult = struct {
    status: u16,
    status_text: []const u8,
    headers: []const HeaderEntry,
    body: ?[]const u8,
    is_error: bool,
};

/// Check if URL has a valid scheme for caching (http or https).
fn isValidCacheScheme(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or
        std.mem.startsWith(u8, url, "https://");
}

// =============================================================================
// Tests
// =============================================================================

test "Cache.init and deinit" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    try std.testing.expectEqualStrings("v1", cache.name);
    try std.testing.expect(cache.isEmpty());
}

test "Cache.put and match" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Put an entry
    const put_promise = try cache.put(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{.{ .name = "Content-Type", .value = "application/json" }},
        "{\"data\": 1}",
        .basic,
    );
    try std.testing.expect(put_promise.isFulfilled());
    try std.testing.expectEqual(@as(usize, 1), cache.count());

    // Match the entry
    const match_promise = try cache.match(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try std.testing.expect(match_promise.isFulfilled());
    try std.testing.expect(match_promise.value.? != null);

    const response = match_promise.value.?.?;
    try std.testing.expectEqual(@as(u16, 200), response.status);
}

test "Cache.match not found" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    const promise = try cache.match(
        "https://example.com/not-found",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(promise.value.? == null);
}

test "Cache.delete" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Put an entry
    _ = try cache.put(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{},
        null,
        .basic,
    );
    try std.testing.expectEqual(@as(usize, 1), cache.count());

    // Delete it
    const delete_promise = try cache.delete(
        "https://example.com/api",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );
    try std.testing.expect(delete_promise.isFulfilled());
    try std.testing.expect(delete_promise.value.?);
    try std.testing.expect(cache.isEmpty());
}

test "Cache.matchAll" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Put multiple entries
    _ = try cache.put("https://example.com/a", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, null, .basic);
    _ = try cache.put("https://example.com/b", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, null, .basic);

    // Match all (no filter)
    const promise = try cache.matchAll(null, null, &[_]HeaderEntry{}, .{});
    try std.testing.expect(promise.isFulfilled());

    const results = promise.value.?;
    defer allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);
}

test "Cache.keys" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    _ = try cache.put("https://example.com/a", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, null, .basic);
    _ = try cache.put("https://example.com/b", "POST", &[_]HeaderEntry{}, 201, "Created", &[_]HeaderEntry{}, null, .basic);

    const promise = try cache.keys(null, null, &[_]HeaderEntry{}, .{});
    try std.testing.expect(promise.isFulfilled());

    const requests = promise.value.?;
    defer allocator.free(requests);

    try std.testing.expectEqual(@as(usize, 2), requests.len);
}

test "Cache.put replaces existing" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Put initial entry
    _ = try cache.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "v1", .basic);

    // Put same URL again
    _ = try cache.put("https://example.com/api", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "v2", .basic);

    // Should still have only one entry
    try std.testing.expectEqual(@as(usize, 1), cache.count());

    // Should have the new body
    const promise = try cache.match("https://example.com/api", "GET", &[_]HeaderEntry{}, .{});
    const response = promise.value.?.?;
    try std.testing.expectEqualStrings("v2", response.body.?);
}

test "Cache.add - successful fetch" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Mock fetch function that returns a successful response
    const mockFetch = struct {
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            return .{
                .status = 200,
                .status_text = "OK",
                .headers = &[_]HeaderEntry{},
                .body = "test body",
                .is_error = false,
            };
        }
    }.fetch;

    const promise = try cache.add("https://example.com/api", mockFetch);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expectEqual(@as(usize, 1), cache.count());

    // Verify the entry was stored
    const match_promise = try cache.match("https://example.com/api", "GET", &[_]HeaderEntry{}, .{});
    try std.testing.expect(match_promise.value.? != null);
}

test "Cache.add - rejects non-http schemes" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    const mockFetch = struct {
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            return .{
                .status = 200,
                .status_text = "OK",
                .headers = &[_]HeaderEntry{},
                .body = null,
                .is_error = false,
            };
        }
    }.fetch;

    // File URL should be rejected
    const promise = try cache.add("file:///local/file.txt", mockFetch);
    try std.testing.expect(promise.isRejected());
    try std.testing.expect(cache.isEmpty());
}

test "Cache.add - rejects error responses" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    const mockFetch = struct {
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            return .{
                .status = 0,
                .status_text = "",
                .headers = &[_]HeaderEntry{},
                .body = null,
                .is_error = true,
            };
        }
    }.fetch;

    const promise = try cache.add("https://example.com/api", mockFetch);
    try std.testing.expect(promise.isRejected());
    try std.testing.expect(cache.isEmpty());
}

test "Cache.add - rejects non-ok status" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    const mockFetch = struct {
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            return .{
                .status = 404,
                .status_text = "Not Found",
                .headers = &[_]HeaderEntry{},
                .body = null,
                .is_error = false,
            };
        }
    }.fetch;

    const promise = try cache.add("https://example.com/api", mockFetch);
    try std.testing.expect(promise.isRejected());
    try std.testing.expect(cache.isEmpty());
}

test "Cache.addAll - multiple successful fetches" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    const mockFetch = struct {
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            return .{
                .status = 200,
                .status_text = "OK",
                .headers = &[_]HeaderEntry{},
                .body = "cached",
                .is_error = false,
            };
        }
    }.fetch;

    const urls = [_][]const u8{
        "https://example.com/a",
        "https://example.com/b",
        "https://example.com/c",
    };

    const promise = try cache.addAll(&urls, mockFetch);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expectEqual(@as(usize, 3), cache.count());
}

test "Cache.addAll - rejects if any URL invalid" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    const mockFetch = struct {
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            return .{
                .status = 200,
                .status_text = "OK",
                .headers = &[_]HeaderEntry{},
                .body = null,
                .is_error = false,
            };
        }
    }.fetch;

    const urls = [_][]const u8{
        "https://example.com/a",
        "ftp://invalid.com/b", // Invalid scheme
        "https://example.com/c",
    };

    const promise = try cache.addAll(&urls, mockFetch);
    try std.testing.expect(promise.isRejected());
    try std.testing.expect(cache.isEmpty());
}

test "Cache.addAll - rejects if any fetch fails" {
    const allocator = std.testing.allocator;

    const cache = try Cache.init(allocator, "v1");
    defer cache.deinit();

    // Return error for the second URL
    var call_count: usize = 0;
    const mockFetch = struct {
        var count: *usize = undefined;
        fn init(c: *usize) void {
            count = c;
        }
        fn fetch(_: Allocator, _: []const u8) FetchResult {
            count.* += 1;
            if (count.* == 2) {
                return .{
                    .status = 500,
                    .status_text = "Error",
                    .headers = &[_]HeaderEntry{},
                    .body = null,
                    .is_error = false,
                };
            }
            return .{
                .status = 200,
                .status_text = "OK",
                .headers = &[_]HeaderEntry{},
                .body = null,
                .is_error = false,
            };
        }
    };
    mockFetch.init(&call_count);

    const urls = [_][]const u8{
        "https://example.com/a",
        "https://example.com/b",
        "https://example.com/c",
    };

    const promise = try cache.addAll(&urls, mockFetch.fetch);
    try std.testing.expect(promise.isRejected());
}

test "isValidCacheScheme" {
    try std.testing.expect(isValidCacheScheme("https://example.com"));
    try std.testing.expect(isValidCacheScheme("http://example.com"));
    try std.testing.expect(!isValidCacheScheme("ftp://example.com"));
    try std.testing.expect(!isValidCacheScheme("file:///local"));
    try std.testing.expect(!isValidCacheScheme("data:text/plain,hello"));
}
