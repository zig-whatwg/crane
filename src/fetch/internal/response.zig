//! WHATWG Fetch Standard - Internal Response Struct
//!
//! This module implements the internal response representation per Fetch spec.
//! This is distinct from the Response WebIDL interface (which wraps this).
//!
//! Spec: https://fetch.spec.whatwg.org/#responses

const std = @import("std");
const Allocator = std.mem.Allocator;
const header_list = @import("header_list.zig");
const HeaderList = header_list.HeaderList;
const body_mod = @import("body.zig");
const Body = body_mod.Body;
const fetch_timing = @import("fetch_timing.zig");
const ResponseBodyInfo = fetch_timing.ResponseBodyInfo;
const validation = @import("validation.zig");

// =============================================================================
// Enums per WHATWG Fetch Spec
// =============================================================================

/// Response type.
/// Spec: https://fetch.spec.whatwg.org/#concept-response-type
pub const ResponseType = enum {
    basic,
    cors,
    default,
    @"error",
    @"opaque",
    opaqueredirect,
};

/// Cache state.
/// Spec: https://fetch.spec.whatwg.org/#concept-response-cache-state
pub const CacheState = enum {
    empty,
    local,
    validated,
};

/// Redirect taint.
pub const RedirectTaint = enum {
    same_origin,
    same_site,
    cross_site,
};

// =============================================================================
// Internal Response Struct
// =============================================================================

/// Internal response representation per Fetch spec.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-response
pub const InternalResponse = struct {
    allocator: Allocator,

    /// Response type
    response_type: ResponseType = .default,

    /// Fetch has no such concept: this is the user agent's "knows that to
    /// be futile" input for HTML 9.2.2 step 15.2. Only a known transport
    /// failure permits EventSource to retry; every other path defaults safe.
    network_error_cause: enum { unspecified, transport } = .unspecified,

    /// Aborted flag
    aborted: bool = false,

    /// URL list (for redirects)
    url_list: std.ArrayListUnmanaged([]const u8),

    /// HTTP status (0-999)
    status: u16 = 200,

    /// Status message (empty for HTTP/2+).
    ///
    /// OWNED by this response whenever it is non-empty: set it with
    /// `setStatusMessage`, never by assigning the field. It used to be a bare
    /// borrowed slice that `deinit` never freed, so its lifetime was whatever
    /// the assigner's happened to be - a string literal, a cache entry, or the
    /// Response constructor's `init.statusText`, which the WebIDL layer frees
    /// the moment the constructor returns.
    status_message: []const u8,

    /// Header list
    header_list: HeaderList,

    /// Response body
    body: ?*Body = null,

    /// Cache state
    cache_state: CacheState = .empty,

    /// CORS-exposed header names
    cors_exposed_header_name_list: std.ArrayListUnmanaged([]const u8),

    /// Range requested flag
    range_requested: bool = false,

    /// Request includes credentials
    request_includes_credentials: bool = true,

    /// Timing allow passed flag
    timing_allow_passed: bool = false,

    /// Body info for Resource Timing
    body_info: ResponseBodyInfo,

    /// Its service worker timing info: set on a service worker's response
    /// (Create Fetch Event and Dispatch step 18), null otherwise.
    service_worker_timing_info: ?fetch_timing.ServiceWorkerTimingInfo = null,

    /// Redirect taint
    redirect_taint: RedirectTaint = .same_origin,

    /// An opaque or opaque-redirect filtered response's internal response
    /// (Fetch: "a filtered response ... has an associated internal
    /// response"): what the filter hides - status, status message, header
    /// list, URL list and body - moved here by `filter`. Script never reads
    /// it; the user agent does - a script element's or an image's response
    /// is the unsafe response, a service worker hands it on through
    /// respondWith(), the Cache API stores it. OWNED. Null for every other
    /// response: Crane marks a basic or CORS filter on the response itself
    /// (`applyFilter`), and main fetch's response is unfiltered until a
    /// consumer applies it.
    internal: ?*Self = null,

    const Self = @This();

    /// Initialize a new response.
    pub fn init(allocator: Allocator) !*Self {
        const response = try allocator.create(Self);
        errdefer allocator.destroy(response);

        response.* = .{
            .allocator = allocator,
            .url_list = .empty,
            .status_message = "",
            .header_list = HeaderList.init(allocator),
            .cors_exposed_header_name_list = .empty,
            .body_info = ResponseBodyInfo.init(),
        };

        return response;
    }

    /// Deinitialize the response.
    pub fn deinit(self: *Self) void {
        // Free URL list
        for (self.url_list.items) |u| {
            self.allocator.free(u);
        }
        self.url_list.deinit(self.allocator);

        // The status message is owned whenever it is non-empty - see the
        // field's doc comment.
        if (self.status_message.len > 0) self.allocator.free(self.status_message);

        self.header_list.deinit();

        // Free CORS exposed headers
        for (self.cors_exposed_header_name_list.items) |name| {
            self.allocator.free(name);
        }
        self.cors_exposed_header_name_list.deinit(self.allocator);

        // Free body
        if (self.body) |body| {
            body.deinit();
        }

        if (self.internal) |internal| internal.deinit();

        self.allocator.destroy(self);
    }

    /// Set the status message to an owned copy of `message`.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#concept-response-status-message -
    /// "a byte sequence". The caller's buffer is not retained, so a borrowed
    /// argument is safe to pass.
    pub fn setStatusMessage(self: *Self, message: []const u8) !void {
        const copy: []const u8 = if (message.len > 0) try self.allocator.dupe(u8, message) else "";
        if (self.status_message.len > 0) self.allocator.free(self.status_message);
        self.status_message = copy;
    }

    /// Apply this response's filter in place, as `applyFilter` does, but
    /// keep what an opaque or opaque-redirect filter hides as the filtered
    /// response's internal response (`internal`): a Response object's
    /// response, which script sees filtered and the user agent reads whole
    /// (a service worker's respondWith(), the Cache API). On failure - no
    /// memory for the internal response - nothing has moved and nothing is
    /// filtered: the caller drops the response.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#concept-internal-response
    pub fn filter(self: *Self) Allocator.Error!void {
        const hides_all = self.response_type == .@"opaque" or self.response_type == .opaqueredirect;
        if (hides_all and self.internal == null) self.internal = try self.splitInternal();
        self.applyFilter();
    }

    /// The internal response of this response, about to be filtered opaque:
    /// a new response holding what the filter clears, moved out of this one.
    /// Every allocation comes before the first move.
    fn splitInternal(self: *Self) Allocator.Error!*Self {
        const kept = try Self.init(self.allocator);
        errdefer kept.deinit();
        // The opaque-redirect filter keeps its URL list: the internal
        // response gets a copy. The opaque filter empties it: it moves.
        if (self.response_type == .opaqueredirect) {
            try kept.url_list.ensureTotalCapacity(self.allocator, self.url_list.items.len);
            for (self.url_list.items) |u| kept.url_list.appendAssumeCapacity(try self.allocator.dupe(u8, u));
        } else {
            std.mem.swap(std.ArrayListUnmanaged([]const u8), &kept.url_list, &self.url_list);
        }
        // From here nothing fails.
        kept.response_type = .default;
        kept.status = self.status;
        kept.status_message = self.status_message;
        self.status_message = "";
        std.mem.swap(HeaderList, &kept.header_list, &self.header_list);
        kept.body = self.body;
        self.body = null;
        kept.aborted = self.aborted;
        kept.cache_state = self.cache_state;
        kept.range_requested = self.range_requested;
        kept.request_includes_credentials = self.request_includes_credentials;
        kept.timing_allow_passed = self.timing_allow_passed;
        kept.body_info = self.body_info;
        kept.redirect_taint = self.redirect_taint;
        return kept;
    }

    /// Apply this response's filter - its type, from main fetch step 15 - in
    /// place, for a consumer that is shown only the filtered response: an
    /// XMLHttpRequest (never opaque: its mode is "cors"), or a response
    /// turned into a network error. What the filter hides is gone after,
    /// so this is only for a response nothing reads unfiltered; a Response
    /// object's response is filtered with `filter`, which keeps it.
    ///
    /// Spec: https://fetch.spec.whatwg.org/#concept-filtered-response
    pub fn applyFilter(self: *Self) void {
        switch (self.response_type) {
            // A basic filtered response's header list excludes any headers
            // whose name is a forbidden response-header name.
            .basic => self.keepHeaders(.basic),
            // A CORS filtered response's header list excludes any headers
            // whose name is not a CORS-safelisted response-header name,
            // given its CORS-exposed header-name list.
            .cors => self.keepHeaders(.cors),
            // An opaque filtered response: type "opaque", URL list empty,
            // status 0, status message the empty byte sequence, header list
            // empty, body null.
            .@"opaque" => {
                for (self.url_list.items) |u| self.allocator.free(u);
                self.url_list.clearRetainingCapacity();
                self.makeOpaque();
            },
            // An opaque-redirect filtered response: the same, but its URL
            // list stays.
            .opaqueredirect => self.makeOpaque(),
            else => {},
        }
    }

    fn keepHeaders(self: *Self, comptime kind: enum { basic, cors }) void {
        var i: usize = 0;
        while (i < self.header_list.entries.items.len) {
            const name = self.header_list.entries.items[i].name;
            const keep = switch (kind) {
                .basic => !validation.isForbiddenResponseHeaderName(name),
                .cors => validation.isCORSSafelistedResponseHeaderName(name, self.cors_exposed_header_name_list.items),
            };
            if (keep) {
                i += 1;
                continue;
            }
            var removed = self.header_list.entries.orderedRemove(i);
            removed.deinit(self.allocator);
        }
    }

    fn makeOpaque(self: *Self) void {
        self.status = 0;
        if (self.status_message.len > 0) self.allocator.free(self.status_message);
        self.status_message = "";
        self.header_list.deinit();
        self.header_list = HeaderList.init(self.allocator);
        if (self.body) |b| b.deinit();
        self.body = null;
    }

    // === URL Accessors ===

    /// Get the response URL (last in URL list, or null if empty).
    /// Spec: "A response has an associated URL."
    pub fn url(self: *const Self) ?[]const u8 {
        if (self.url_list.items.len == 0) return null;
        return self.url_list.items[self.url_list.items.len - 1];
    }

    /// Add a URL to the URL list.
    pub fn addUrl(self: *Self, new_url: []const u8) !void {
        const owned = try self.allocator.dupe(u8, new_url);
        errdefer self.allocator.free(owned);
        try self.url_list.append(self.allocator, owned);
    }

    // === Clone ===

    /// Clone a response.
    /// Spec: https://fetch.spec.whatwg.org/#concept-response-clone
    pub fn clone(self: *Self) !*Self {
        const new_response = try self.allocator.create(Self);
        // Until its fields are set, a failure frees the allocation alone;
        // after, the response with whatever it holds.
        var initialized = false;
        errdefer if (!initialized) self.allocator.destroy(new_response);

        // Each response frees its own status message, so the clone needs its
        // own copy - sharing it is a double free.
        const status_message: []const u8 = if (self.status_message.len > 0)
            try self.allocator.dupe(u8, self.status_message)
        else
            "";
        errdefer if (!initialized and status_message.len > 0) self.allocator.free(status_message);

        new_response.* = .{
            .allocator = self.allocator,
            .response_type = self.response_type,
            .aborted = self.aborted,
            .url_list = .empty,
            .status = self.status,
            .status_message = status_message,
            .header_list = try self.header_list.clone(self.allocator),
            .body = null,
            .cache_state = self.cache_state,
            .cors_exposed_header_name_list = .empty,
            .range_requested = self.range_requested,
            .request_includes_credentials = self.request_includes_credentials,
            .timing_allow_passed = self.timing_allow_passed,
            .body_info = self.body_info,
            .service_worker_timing_info = self.service_worker_timing_info,
            .redirect_taint = self.redirect_taint,
        };
        initialized = true;
        errdefer new_response.deinit();

        // Clone URL list
        for (self.url_list.items) |u| try new_response.addUrl(u);

        // Clone CORS exposed headers
        for (self.cors_exposed_header_name_list.items) |name| try new_response.addCorsExposedHeaderName(name);

        // Clone body
        if (self.body) |body| {
            new_response.body = try body.clone(self.allocator);
        }

        // A filtered response's clone is a filtered response of its internal
        // response's clone (Fetch "clone a response" step 1).
        if (self.internal) |internal| new_response.internal = try internal.clone();

        return new_response;
    }

    // === CORS Exposed Headers ===

    /// Add a CORS-exposed header name.
    pub fn addCorsExposedHeaderName(self: *Self, name: []const u8) !void {
        const owned = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned);
        try self.cors_exposed_header_name_list.append(self.allocator, owned);
    }
};

// =============================================================================
// Network Error
// =============================================================================

/// Create a network error response.
///
/// Spec: "A network error is a response whose type is 'error', status is 0,
/// status message is the empty byte sequence, header list is empty, body is null,
/// and body info is a new response body info."
pub fn networkError(allocator: Allocator) !*InternalResponse {
    const response = try InternalResponse.init(allocator);
    response.response_type = .@"error";
    response.status = 0;
    return response;
}

/// Create an aborted network error.
///
/// Spec: "An aborted network error is a network error whose aborted flag is set."
pub fn abortedNetworkError(allocator: Allocator) !*InternalResponse {
    const response = try networkError(allocator);
    response.aborted = true;
    return response;
}

// =============================================================================
// Status Helpers
// =============================================================================

/// Is this a null body status?
/// Spec: "A null body status is a status that is 101, 103, 204, 205, or 304."
pub fn isNullBodyStatus(status: u16) bool {
    return status == 101 or status == 103 or status == 204 or status == 205 or status == 304;
}

/// Is this an ok status?
/// Spec: "An ok status is a status in the range 200 to 299, inclusive."
pub fn isOkStatus(status: u16) bool {
    return status >= 200 and status <= 299;
}

/// Is this a redirect status?
/// Spec: "A redirect status is a status that is 301, 302, 303, 307, or 308."
pub fn isRedirectStatus(status: u16) bool {
    return status == 301 or status == 302 or status == 303 or status == 307 or status == 308;
}

// =============================================================================
// Filtered Response
// =============================================================================

/// Filter type for filtered responses.
pub const FilterType = enum {
    basic,
    cors,
    @"opaque",
    opaque_redirect,
};

/// A filtered response wraps an internal response with limited view.
///
/// Spec: "A filtered response is a response that offers a limited view on an
/// associated response."
pub const FilteredResponse = struct {
    /// The underlying internal response.
    internal_response: *InternalResponse,

    /// The filter type.
    filter_type: FilterType,

    allocator: Allocator,

    const Self = @This();

    /// Get the response type based on filter.
    pub fn getType(self: *const Self) ResponseType {
        return switch (self.filter_type) {
            .basic => .basic,
            .cors => .cors,
            .@"opaque" => .@"opaque",
            .opaque_redirect => .opaqueredirect,
        };
    }

    /// Get status (filtered for opaque types).
    pub fn getStatus(self: *const Self) u16 {
        return switch (self.filter_type) {
            .basic, .cors => self.internal_response.status,
            .@"opaque", .opaque_redirect => 0,
        };
    }

    /// Get status message (filtered for opaque types).
    pub fn getStatusMessage(self: *const Self) []const u8 {
        return switch (self.filter_type) {
            .basic, .cors => self.internal_response.status_message,
            .@"opaque", .opaque_redirect => "",
        };
    }

    /// Check if a header should be exposed based on filter type.
    pub fn isHeaderExposed(self: *const Self, name: []const u8) bool {
        return switch (self.filter_type) {
            .basic => !validation.isForbiddenResponseHeaderName(name),
            .cors => self.isCorsHeaderExposed(name),
            .@"opaque", .opaque_redirect => false,
        };
    }

    fn isCorsHeaderExposed(self: *const Self, name: []const u8) bool {
        // Check CORS-safelisted response headers
        if (validation.isCORSSafelistedResponseHeaderName(
            name,
            self.internal_response.cors_exposed_header_name_list.items,
        )) {
            return true;
        }
        return false;
    }

    /// Get body (null for opaque types).
    pub fn getBody(self: *const Self) ?*Body {
        return switch (self.filter_type) {
            .basic, .cors => self.internal_response.body,
            .@"opaque", .opaque_redirect => null,
        };
    }

    /// Get URL list (empty for opaque, but preserved for opaque-redirect).
    pub fn getUrlList(self: *const Self) []const []const u8 {
        return switch (self.filter_type) {
            .basic, .cors, .opaque_redirect => self.internal_response.url_list.items,
            .@"opaque" => &[_][]const u8{},
        };
    }
};

/// Create a basic filtered response.
///
/// Spec: "A basic filtered response is a filtered response whose type is 'basic'
/// and header list excludes any headers in internal response's header list whose
/// name is a forbidden response-header name."
pub fn createBasicFilteredResponse(allocator: Allocator, internal: *InternalResponse) FilteredResponse {
    return .{
        .internal_response = internal,
        .filter_type = .basic,
        .allocator = allocator,
    };
}

/// Create a CORS filtered response.
///
/// Spec: "A CORS filtered response is a filtered response whose type is 'cors'
/// and header list excludes any headers in internal response's header list whose
/// name is not a CORS-safelisted response-header name, given internal response's
/// CORS-exposed header-name list."
pub fn createCORSFilteredResponse(allocator: Allocator, internal: *InternalResponse) FilteredResponse {
    return .{
        .internal_response = internal,
        .filter_type = .cors,
        .allocator = allocator,
    };
}

/// Create an opaque filtered response.
///
/// Spec: "An opaque filtered response is a filtered response whose type is 'opaque',
/// URL list is empty, status is 0, status message is empty, header list is empty,
/// body is null, and body info is a new response body info."
pub fn createOpaqueFilteredResponse(allocator: Allocator, internal: *InternalResponse) FilteredResponse {
    return .{
        .internal_response = internal,
        .filter_type = .@"opaque",
        .allocator = allocator,
    };
}

/// Create an opaque-redirect filtered response.
///
/// Spec: "An opaque-redirect filtered response is a filtered response whose type is
/// 'opaqueredirect', status is 0, status message is empty, header list is empty,
/// body is null, and body info is a new response body info."
/// Note: URL list is preserved (not empty like opaque).
pub fn createOpaqueRedirectFilteredResponse(allocator: Allocator, internal: *InternalResponse) FilteredResponse {
    return .{
        .internal_response = internal,
        .filter_type = .opaque_redirect,
        .allocator = allocator,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "InternalResponse.init creates default response" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    try std.testing.expectEqual(ResponseType.default, response.response_type);
    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqual(false, response.aborted);
    try std.testing.expect(response.url() == null);
}

test "InternalResponse.url returns last in list" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    try response.addUrl("https://example.com/original");
    try response.addUrl("https://example.com/redirected");

    try std.testing.expectEqualStrings("https://example.com/redirected", response.url().?);
}

test "networkError creates error response" {
    const allocator = std.testing.allocator;

    const response = try networkError(allocator);
    defer response.deinit();

    try std.testing.expectEqual(ResponseType.@"error", response.response_type);
    try std.testing.expectEqual(@as(u16, 0), response.status);
    try std.testing.expectEqual(false, response.aborted);
}

test "abortedNetworkError sets aborted flag" {
    const allocator = std.testing.allocator;

    const response = try abortedNetworkError(allocator);
    defer response.deinit();

    try std.testing.expectEqual(ResponseType.@"error", response.response_type);
    try std.testing.expectEqual(@as(u16, 0), response.status);
    try std.testing.expectEqual(true, response.aborted);
}

test "InternalResponse.clone" {
    const allocator = std.testing.allocator;

    const original = try InternalResponse.init(allocator);
    defer original.deinit();

    original.status = 201;
    try original.addUrl("https://example.com");
    try original.header_list.append("Content-Type", "application/json");

    const cloned = try original.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(@as(u16, 201), cloned.status);
    try std.testing.expectEqualStrings("https://example.com", cloned.url().?);
    try std.testing.expect(cloned.header_list.contains("Content-Type"));
}

test "InternalResponse owns its status message - a borrowed argument is copied, not kept" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    // The Response constructor's `init.statusText` is a WebIDL argument the
    // binding layer frees the moment the constructor returns. Keeping the slice
    // was a dangling pointer; the response has to hold its own copy.
    const argument = try allocator.dupe(u8, "Not Found");
    try response.setStatusMessage(argument);
    allocator.free(argument);
    try std.testing.expectEqualStrings("Not Found", response.status_message);

    // Replacing it frees the previous copy - the testing allocator reports a
    // leak otherwise - and the empty string needs no allocation at all.
    try response.setStatusMessage("Gone");
    try std.testing.expectEqualStrings("Gone", response.status_message);
}

test "InternalResponse.clone copies the status message rather than sharing it" {
    const allocator = std.testing.allocator;

    const original = try InternalResponse.init(allocator);
    defer original.deinit();
    try original.setStatusMessage("Created");

    const cloned = try original.clone();
    defer cloned.deinit();

    // Two responses each free their own status message; shared storage would
    // be a double free when the second one goes.
    try std.testing.expectEqualStrings("Created", cloned.status_message);
    try std.testing.expect(cloned.status_message.ptr != original.status_message.ptr);

    try original.setStatusMessage("");
    try std.testing.expectEqualStrings("", original.status_message);
    try std.testing.expectEqualStrings("Created", cloned.status_message);
}

test "isNullBodyStatus" {
    try std.testing.expect(isNullBodyStatus(101));
    try std.testing.expect(isNullBodyStatus(103));
    try std.testing.expect(isNullBodyStatus(204));
    try std.testing.expect(isNullBodyStatus(205));
    try std.testing.expect(isNullBodyStatus(304));
    try std.testing.expect(!isNullBodyStatus(200));
    try std.testing.expect(!isNullBodyStatus(404));
}

test "isOkStatus" {
    try std.testing.expect(isOkStatus(200));
    try std.testing.expect(isOkStatus(201));
    try std.testing.expect(isOkStatus(299));
    try std.testing.expect(!isOkStatus(199));
    try std.testing.expect(!isOkStatus(300));
    try std.testing.expect(!isOkStatus(404));
}

test "isRedirectStatus" {
    try std.testing.expect(isRedirectStatus(301));
    try std.testing.expect(isRedirectStatus(302));
    try std.testing.expect(isRedirectStatus(303));
    try std.testing.expect(isRedirectStatus(307));
    try std.testing.expect(isRedirectStatus(308));
    try std.testing.expect(!isRedirectStatus(200));
    try std.testing.expect(!isRedirectStatus(304));
    try std.testing.expect(!isRedirectStatus(404));
}

test "FilteredResponse.basic type" {
    const allocator = std.testing.allocator;

    const internal = try InternalResponse.init(allocator);
    defer internal.deinit();
    internal.status = 200;

    const filtered = createBasicFilteredResponse(allocator, internal);

    try std.testing.expectEqual(ResponseType.basic, filtered.getType());
    try std.testing.expectEqual(@as(u16, 200), filtered.getStatus());
}

test "FilteredResponse.cors type" {
    const allocator = std.testing.allocator;

    const internal = try InternalResponse.init(allocator);
    defer internal.deinit();
    internal.status = 200;

    const filtered = createCORSFilteredResponse(allocator, internal);

    try std.testing.expectEqual(ResponseType.cors, filtered.getType());
    try std.testing.expectEqual(@as(u16, 200), filtered.getStatus());
}

test "FilteredResponse.opaque hides everything" {
    const allocator = std.testing.allocator;

    const internal = try InternalResponse.init(allocator);
    defer internal.deinit();
    internal.status = 200;
    try internal.addUrl("https://example.com");

    const filtered = createOpaqueFilteredResponse(allocator, internal);

    try std.testing.expectEqual(ResponseType.@"opaque", filtered.getType());
    try std.testing.expectEqual(@as(u16, 0), filtered.getStatus());
    try std.testing.expectEqualStrings("", filtered.getStatusMessage());
    try std.testing.expect(filtered.getBody() == null);
    try std.testing.expectEqual(@as(usize, 0), filtered.getUrlList().len);
}

test "FilteredResponse.opaque_redirect preserves URL list" {
    const allocator = std.testing.allocator;

    const internal = try InternalResponse.init(allocator);
    defer internal.deinit();
    internal.status = 302;
    try internal.addUrl("https://example.com");

    const filtered = createOpaqueRedirectFilteredResponse(allocator, internal);

    try std.testing.expectEqual(ResponseType.opaqueredirect, filtered.getType());
    try std.testing.expectEqual(@as(u16, 0), filtered.getStatus());
    // URL list is preserved for opaque-redirect
    try std.testing.expectEqual(@as(usize, 1), filtered.getUrlList().len);
}

test "applyFilter: basic drops Set-Cookie, cors keeps the safelisted and exposed, opaque keeps nothing" {
    const allocator = std.testing.allocator;

    const basic = try InternalResponse.init(allocator);
    defer basic.deinit();
    basic.response_type = .basic;
    try basic.header_list.append("Content-Type", "text/plain");
    try basic.header_list.append("Set-Cookie", "a=b");
    basic.applyFilter();
    try std.testing.expect(basic.header_list.contains("Content-Type"));
    try std.testing.expect(!basic.header_list.contains("Set-Cookie"));

    const cors = try InternalResponse.init(allocator);
    defer cors.deinit();
    cors.response_type = .cors;
    try cors.header_list.append("Content-Type", "text/plain");
    try cors.header_list.append("X-Secret", "1");
    try cors.header_list.append("X-Exposed", "2");
    try cors.cors_exposed_header_name_list.append(allocator, try allocator.dupe(u8, "x-exposed"));
    cors.applyFilter();
    try std.testing.expect(cors.header_list.contains("Content-Type"));
    try std.testing.expect(!cors.header_list.contains("X-Secret"));
    try std.testing.expect(cors.header_list.contains("X-Exposed"));

    const opaque_response = try InternalResponse.init(allocator);
    defer opaque_response.deinit();
    opaque_response.response_type = .@"opaque";
    try opaque_response.addUrl("http://b.test/x");
    try opaque_response.setStatusMessage("OK");
    try opaque_response.header_list.append("Content-Type", "text/plain");
    opaque_response.applyFilter();
    try std.testing.expectEqual(@as(u16, 0), opaque_response.status);
    try std.testing.expectEqualStrings("", opaque_response.status_message);
    try std.testing.expectEqual(@as(usize, 0), opaque_response.header_list.len());
    try std.testing.expect(opaque_response.url() == null);
    try std.testing.expect(opaque_response.body == null);
}

test "filter keeps an opaque response's internal response: script's view is filtered, the internal one whole" {
    const allocator = std.testing.allocator;
    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    response.response_type = .@"opaque";
    try response.addUrl("https://b.test/x.js");
    try response.setStatusMessage("OK");
    try response.header_list.append("Content-Type", "text/javascript");
    response.body = try Body.fromBytes(allocator, "f()");
    try response.filter();
    // What a Response object reads: an opaque filtered response.
    try std.testing.expectEqual(ResponseType.@"opaque", response.response_type);
    try std.testing.expectEqual(@as(u16, 0), response.status);
    try std.testing.expectEqualStrings("", response.status_message);
    try std.testing.expectEqual(@as(usize, 0), response.header_list.len());
    try std.testing.expect(response.url() == null);
    try std.testing.expect(response.body == null);
    // Its internal response: the network's, moved, not copied.
    const internal = response.internal orelse return error.TestExpectedInternal;
    try std.testing.expectEqual(ResponseType.default, internal.response_type);
    try std.testing.expectEqual(@as(u16, 200), internal.status);
    try std.testing.expectEqualStrings("OK", internal.status_message);
    try std.testing.expect(internal.header_list.contains("Content-Type"));
    try std.testing.expectEqualStrings("https://b.test/x.js", internal.url().?);
    try std.testing.expectEqualStrings("f()", internal.body.?.getBytes());
    // Filtering again changes nothing.
    try response.filter();
    try std.testing.expect(response.internal == internal);
}

test "filter keeps an opaque-redirect response's URL list on both" {
    const allocator = std.testing.allocator;
    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    response.response_type = .opaqueredirect;
    response.status = 302;
    try response.addUrl("https://a.test/from");
    try response.header_list.append("Location", "/to");
    try response.filter();
    try std.testing.expectEqual(@as(u16, 0), response.status);
    try std.testing.expectEqualStrings("https://a.test/from", response.url().?);
    try std.testing.expectEqual(@as(usize, 0), response.header_list.len());
    const internal = response.internal orelse return error.TestExpectedInternal;
    try std.testing.expectEqual(@as(u16, 302), internal.status);
    try std.testing.expectEqualStrings("https://a.test/from", internal.url().?);
    try std.testing.expectEqualStrings("/to", internal.header_list.getFirstValue("Location").?);
}

test "filter keeps no internal response for basic, cors and default responses" {
    const allocator = std.testing.allocator;
    for ([_]ResponseType{ .basic, .cors, .default }) |kind| {
        const response = try InternalResponse.init(allocator);
        defer response.deinit();
        response.response_type = kind;
        response.body = try Body.fromBytes(allocator, "x");
        try response.filter();
        try std.testing.expect(response.internal == null);
        try std.testing.expectEqualStrings("x", response.body.?.getBytes());
    }
}

test "clone copies an opaque response's internal response, each freed on its own" {
    const allocator = std.testing.allocator;
    const response = try InternalResponse.init(allocator);
    response.response_type = .@"opaque";
    try response.addUrl("https://b.test/x");
    response.body = try Body.fromBytes(allocator, "bytes");
    try response.filter();
    const copy = try response.clone();
    defer copy.deinit();
    response.deinit();
    try std.testing.expectEqual(@as(u16, 0), copy.status);
    try std.testing.expect(copy.body == null);
    const internal = copy.internal orelse return error.TestExpectedInternal;
    try std.testing.expectEqual(@as(u16, 200), internal.status);
    try std.testing.expectEqualStrings("https://b.test/x", internal.url().?);
    try std.testing.expectEqualStrings("bytes", internal.body.?.getBytes());
}

fn filterUnderAllocationFailure(allocator: Allocator, kind: ResponseType) !void {
    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    response.response_type = kind;
    response.status = 302;
    try response.addUrl("https://a.test/1");
    try response.addUrl("https://a.test/2");
    try response.setStatusMessage("Found");
    try response.header_list.append("Location", "/2");
    response.body = try Body.fromBytes(allocator, "b");
    response.filter() catch |err| {
        // No memory for the internal response: nothing moved, nothing
        // filtered - the caller drops the response whole.
        try std.testing.expect(response.internal == null);
        try std.testing.expectEqual(@as(u16, 302), response.status);
        try std.testing.expectEqualStrings("Found", response.status_message);
        try std.testing.expect(response.header_list.contains("Location"));
        try std.testing.expectEqual(@as(usize, 2), response.url_list.items.len);
        try std.testing.expectEqualStrings("b", response.body.?.getBytes());
        return err;
    };
    try std.testing.expect(response.internal != null);
}

test "filter with no memory for the internal response moves nothing and leaks nothing" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, filterUnderAllocationFailure, .{ResponseType.@"opaque"});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, filterUnderAllocationFailure, .{ResponseType.opaqueredirect});
}

fn cloneUnderAllocationFailure(allocator: Allocator) !void {
    const response = try InternalResponse.init(allocator);
    defer response.deinit();
    response.response_type = .@"opaque";
    try response.addUrl("https://b.test/x");
    try response.addCorsExposedHeaderName("x-a");
    response.body = try Body.fromBytes(allocator, "bytes");
    try response.filter();
    const copy = try response.clone();
    copy.deinit();
}

test "clone with no memory leaks nothing" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cloneUnderAllocationFailure, .{});
}
