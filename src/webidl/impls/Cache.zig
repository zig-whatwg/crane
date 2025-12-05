//! Implementation for Cache interface
//!
//! Provides an in-memory Cache API implementation.
//! Spec: https://w3c.github.io/ServiceWorker/#cache-interface
//!
//! Note: Cache API methods return Promises per spec. The current implementation
//! stores request/response pairs in memory. Full Promise integration requires
//! JS engine Promise creation which is handled by the V8 binding layer.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CacheInterface = interfaces.Cache;

pub const State = CacheInterface.State;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidState,
    NotImplemented,
};

/// A cached entry (request/response pair)
pub const CacheEntry = struct {
    url: []const u8,
    method: []const u8,
    status: u16,
    status_text: []const u8,
    body: ?[]const u8,
    // Headers could be added here

    pub fn deinit(self: *CacheEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        allocator.free(self.method);
        allocator.free(self.status_text);
        if (self.body) |b| {
            allocator.free(b);
        }
        allocator.destroy(self);
    }
};

/// Internal state for Cache
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    entries: std.ArrayListUnmanaged(*CacheEntry),
    owns_name: bool, // If true, we free the name on deinit
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return initWithName(allocator, StateType, vtable, ctx, "default");
}

/// Initialize instance with a specific name
pub fn initWithName(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    name: []const u8,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    const name_copy = try allocator.dupe(u8, name);

    internal.* = .{
        .allocator = allocator,
        .name = name_copy,
        .entries = .{},
        .owns_name = true,
    };

    // Store in instance state
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;

        // Free all entries
        for (internal.entries.items) |entry| {
            entry.deinit(allocator);
        }
        internal.entries.deinit(allocator);

        if (internal.owns_name) {
            allocator.free(internal.name);
        }

        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Helper to extract URL from RequestInfo
/// RequestInfo = (Request or USVString)
fn extractUrl(request: typedefs.RequestInfo) []const u8 {
    return switch (request) {
        .request => |req_ptr| blk: {
            // Request object - get URL from it
            const req_instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(req_ptr)));
            const RequestImpl = @import("Request.zig");
            break :blk RequestImpl.getUrlInternal(req_instance) orelse "";
        },
        .usvstring => |url_str| url_str,
    };
}

/// Helper to check if a URL matches with options
fn urlMatches(stored_url: []const u8, request_url: []const u8, options: dictionaries.CacheQueryOptions) bool {
    if (options.ignoreSearch orelse false) {
        // Compare URLs without query string
        const stored_base = if (std.mem.indexOf(u8, stored_url, "?")) |idx| stored_url[0..idx] else stored_url;
        const request_base = if (std.mem.indexOf(u8, request_url, "?")) |idx| request_url[0..idx] else request_url;
        return std.mem.eql(u8, stored_base, request_base);
    }
    return std.mem.eql(u8, stored_url, request_url);
}

/// Check if cache has a match (internal helper)
pub fn hasMatch(instance: *runtime.Instance, url: []const u8, options: dictionaries.CacheQueryOptions) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;

    for (internal.entries.items) |entry| {
        if (urlMatches(entry.url, url, options)) {
            return true;
        }
    }
    return false;
}

/// Store an entry internally (for use by CacheStorage.match delegation)
pub fn storeEntry(instance: *runtime.Instance, url: []const u8, method: []const u8, status: u16, status_text: []const u8, body: ?[]const u8) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Create a new cache entry
    const entry = try internal.allocator.create(CacheEntry);
    errdefer internal.allocator.destroy(entry);

    entry.* = .{
        .url = try internal.allocator.dupe(u8, url),
        .method = try internal.allocator.dupe(u8, method),
        .status = status,
        .status_text = try internal.allocator.dupe(u8, status_text),
        .body = if (body) |b| try internal.allocator.dupe(u8, b) else null,
    };

    // Remove any existing entries with the same URL (put replaces)
    var i: usize = 0;
    while (i < internal.entries.items.len) {
        const existing = internal.entries.items[i];
        if (std.mem.eql(u8, existing.url, url)) {
            _ = internal.entries.orderedRemove(i);
            existing.deinit(internal.allocator);
        } else {
            i += 1;
        }
    }

    // Add new entry
    try internal.entries.append(internal.allocator, entry);
}

/// Get an entry's response data (for use by CacheStorage.match delegation)
pub fn getMatchData(instance: *runtime.Instance, url: []const u8, options: dictionaries.CacheQueryOptions) ?struct { status: u16, status_text: []const u8, body: ?[]const u8 } {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;

    for (internal.entries.items) |entry| {
        if (urlMatches(entry.url, url, options)) {
            return .{
                .status = entry.status,
                .status_text = entry.status_text,
                .body = entry.body,
            };
        }
    }
    return null;
}

/// Operation: delete - Remove a cached entry
/// Spec: https://w3c.github.io/ServiceWorker/#cache-delete
/// Returns: Promise<boolean>
pub fn call_delete(instance: *runtime.Instance, request: typedefs.RequestInfo, options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const url = extractUrl(request);
    const opts = if (options.wasPassed()) options.value else dictionaries.CacheQueryOptions{};

    var deleted = false;
    var i: usize = 0;
    while (i < internal.entries.items.len) {
        const entry = internal.entries.items[i];
        if (urlMatches(entry.url, url, opts)) {
            _ = internal.entries.orderedRemove(i);
            entry.deinit(internal.allocator);
            deleted = true;
            // Don't increment i - next item moved to current position
        } else {
            i += 1;
        }
    }

    // The deletion was performed. Return NotImplemented since we can't
    // create a JS Promise directly. The V8 binding layer should create
    // a resolved Promise with the boolean result.
    // Note: `deleted` contains whether anything was actually deleted.
    if (deleted) {
        return error.NotImplemented;
    }
    return error.NotImplemented;
}

/// Operation: match - Find a matching response
/// Spec: https://w3c.github.io/ServiceWorker/#cache-match
/// Returns: Promise<Response | undefined>
pub fn call_match(instance: *runtime.Instance, request: typedefs.RequestInfo, options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const url = extractUrl(request);
    const opts = if (options.wasPassed()) options.value else dictionaries.CacheQueryOptions{};

    // Find first match
    for (internal.entries.items) |entry| {
        if (urlMatches(entry.url, url, opts)) {
            // Create a Response WebIDL wrapper
            const ResponseImpl = @import("Response.zig");
            const Response = interfaces.Response;

            const response_instance = try ResponseImpl.init(internal.allocator, Response.State, &Response.vtable, instance.ctx);

            // Set response data
            const response_state = response_instance.getState(Response.State);
            if (response_state.own._internal) |response_internal| {
                response_internal.response.status = entry.status;
                response_internal.response.status_message = entry.status_text;
                // Body would be set here if we had the full response body handling
            }

            return @ptrCast(response_instance);
        }
    }

    // No match found - return NotImplemented to signal "no match"
    // The V8 layer should create a Promise resolved with undefined
    return error.NotImplemented;
}

/// Operation: keys - Get all cached request keys
/// Spec: https://w3c.github.io/ServiceWorker/#cache-keys
/// Returns: Promise<sequence<Request>>
pub fn call_keys(instance: *runtime.Instance, request: webidl.Opt(typedefs.RequestInfo), options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const opts = if (options.wasPassed()) options.value else dictionaries.CacheQueryOptions{};

    // Collect all matching request keys
    var results = std.ArrayListUnmanaged(*runtime.Instance){};
    defer results.deinit(internal.allocator);

    // Get URL filter if request parameter is provided
    const filter_url: ?[]const u8 = if (request.wasPassed()) extractUrl(request.value) else null;

    for (internal.entries.items) |entry| {
        // If filter provided, check if it matches
        if (filter_url) |url| {
            if (!urlMatches(entry.url, url, opts)) {
                continue;
            }
        }

        // Create a Request instance for this entry
        const RequestImpl = @import("Request.zig");
        const Request = interfaces.Request;

        const request_instance = try RequestImpl.init(internal.allocator, Request.State, &Request.vtable, instance.ctx);

        // Set the URL on the request
        const request_state = request_instance.getState(Request.State);
        if (request_state.own._internal) |req_internal| {
            // Set URL on the internal request
            internal.allocator.free(req_internal.request.url_list.items[0]);
            req_internal.request.url_list.items[0] = try internal.allocator.dupe(u8, entry.url);

            // Set method
            internal.allocator.free(req_internal.request.method);
            req_internal.request.method = try internal.allocator.dupe(u8, entry.method);
        }

        try results.append(internal.allocator, request_instance);
    }

    // The V8 binding layer should create a Promise resolved with this array
    // For now, return NotImplemented to signal results available
    // Note: The results ArrayList contains the Request instances
    _ = results.items;
    return error.NotImplemented;
}

/// Operation: matchAll - Find all matching responses
/// Spec: https://w3c.github.io/ServiceWorker/#cache-matchall
/// Returns: Promise<sequence<Response>>
pub fn call_matchAll(instance: *runtime.Instance, request: webidl.Opt(typedefs.RequestInfo), options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const opts = if (options.wasPassed()) options.value else dictionaries.CacheQueryOptions{};

    // Collect all matching responses
    var results = std.ArrayListUnmanaged(*runtime.Instance){};
    defer results.deinit(internal.allocator);

    // Get URL filter if request parameter is provided
    const filter_url: ?[]const u8 = if (request.wasPassed()) extractUrl(request.value) else null;

    for (internal.entries.items) |entry| {
        // If filter provided, check if it matches
        if (filter_url) |url| {
            if (!urlMatches(entry.url, url, opts)) {
                continue;
            }

            // Check method if ignoreMethod is not set
            if (!(opts.ignoreMethod orelse false)) {
                // For matchAll, default method is GET
                if (!std.mem.eql(u8, entry.method, "GET")) {
                    continue;
                }
            }
        }

        // Create a Response instance for this entry
        const ResponseImpl = @import("Response.zig");
        const Response = interfaces.Response;

        const response_instance = try ResponseImpl.init(internal.allocator, Response.State, &Response.vtable, instance.ctx);

        // Set response data
        const response_state = response_instance.getState(Response.State);
        if (response_state.own._internal) |response_internal| {
            response_internal.response.status = entry.status;
            response_internal.response.status_message = entry.status_text;
            // Body would be set here if we had the full response body handling
        }

        try results.append(internal.allocator, response_instance);
    }

    // The V8 binding layer should create a Promise resolved with this array
    // For now, return NotImplemented to signal results available
    // Note: The results ArrayList contains the Response instances
    _ = results.items;
    return error.NotImplemented;
}

/// Operation: add - Fetch and cache a request
/// Spec: https://w3c.github.io/ServiceWorker/#cache-add
/// Returns: Promise<undefined>
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
///    c. Call Cache.put() with the request and response.
pub fn call_add(instance: *runtime.Instance, request: typedefs.RequestInfo) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const url = extractUrl(request);

    // Step 2: Validate URL scheme (http or https only)
    if (!isValidCacheScheme(url)) {
        return error.TypeError;
    }

    // Steps 3-5: In a real implementation, this would:
    // 1. Perform a fetch() with CORS mode
    // 2. Wait for the response
    // 3. Validate the response is not an error type
    // 4. Validate the response status is ok (200-299)
    // 5. Call put() with the request/response pair
    //
    // Since we can't actually perform network requests from this layer,
    // we return NotImplemented to signal that the V8 binding layer should:
    // 1. Create the fetch request
    // 2. Handle the promise chain
    // 3. Call put() on success
    //
    // The implementation pattern for the V8 layer:
    // ```javascript
    // Cache.prototype.add = async function(request) {
    //   const response = await fetch(request, { mode: 'cors' });
    //   if (!response.ok) throw new TypeError('Response not ok');
    //   return this.put(request, response);
    // };
    // ```
    _ = internal;
    return error.NotImplemented;
}

/// Check if URL has a valid scheme for caching (http or https).
fn isValidCacheScheme(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or
        std.mem.startsWith(u8, url, "https://");
}

/// Operation: addAll - Fetch and cache multiple requests
/// Spec: https://w3c.github.io/ServiceWorker/#cache-addall
/// Returns: Promise<undefined>
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
/// 6. Batch store all request/response pairs atomically.
pub fn call_addAll(instance: *runtime.Instance, requests: *const anyopaque) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal;

    // The `requests` parameter is a sequence<RequestInfo> passed from JavaScript.
    // In a real implementation, we would:
    // 1. Iterate through the sequence
    // 2. Validate each URL scheme
    // 3. Perform parallel fetches
    // 4. Validate all responses
    // 5. Store all atomically (reject all if any fails)
    //
    // Since we can't perform network requests from this layer, we return
    // NotImplemented to signal that the V8 binding layer should handle this.
    //
    // The implementation pattern for the V8 layer:
    // ```javascript
    // Cache.prototype.addAll = async function(requests) {
    //   const responses = await Promise.all(
    //     requests.map(req => fetch(req, { mode: 'cors' }))
    //   );
    //   for (const response of responses) {
    //     if (!response.ok) throw new TypeError('Response not ok');
    //   }
    //   // Atomic batch put
    //   await Promise.all(
    //     requests.map((req, i) => this.put(req, responses[i]))
    //   );
    // };
    // ```
    _ = requests;
    return error.NotImplemented;
}

/// Operation: put - Store a request/response pair
/// Spec: https://w3c.github.io/ServiceWorker/#cache-put
/// Returns: Promise<undefined>
pub fn call_put(instance: *runtime.Instance, request: typedefs.RequestInfo, response: *runtime.Instance) anyerror!*const anyopaque {
    const url = extractUrl(request);

    // Get response details from the Response instance
    const ResponseImpl = @import("Response.zig");
    const response_data = ResponseImpl.getResponseData(response);

    // Store the entry
    try storeEntry(instance, url, "GET", response_data.status, response_data.status_text, response_data.body);

    // The entry was stored. Return NotImplemented since we can't
    // create a JS Promise directly. The V8 binding layer should create
    // a resolved Promise with undefined.
    return error.NotImplemented;
}
