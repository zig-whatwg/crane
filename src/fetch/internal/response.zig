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

    /// Aborted flag
    aborted: bool = false,

    /// URL list (for redirects)
    url_list: std.ArrayListUnmanaged([]const u8),

    /// HTTP status (0-999)
    status: u16 = 200,

    /// Status message (empty for HTTP/2+)
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

    /// Service worker timing info (opaque for now)
    service_worker_timing_info: ?*anyopaque = null,

    /// Redirect taint
    redirect_taint: RedirectTaint = .same_origin,

    const Self = @This();

    /// Initialize a new response.
    pub fn init(allocator: Allocator) !*Self {
        const response = try allocator.create(Self);
        errdefer allocator.destroy(response);

        response.* = .{
            .allocator = allocator,
            .url_list = .{},
            .status_message = "",
            .header_list = HeaderList.init(allocator),
            .cors_exposed_header_name_list = .{},
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

        // Free status message if we own it
        if (self.status_message.len > 0) {
            // Check if it's an owned allocation (not a static string)
            // For safety, we track this via a flag or always own
        }

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

        self.allocator.destroy(self);
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
        try self.url_list.append(self.allocator, owned);
    }

    // === Clone ===

    /// Clone a response.
    /// Spec: https://fetch.spec.whatwg.org/#concept-response-clone
    pub fn clone(self: *Self) !*Self {
        const new_response = try self.allocator.create(Self);
        errdefer self.allocator.destroy(new_response);

        new_response.* = .{
            .allocator = self.allocator,
            .response_type = self.response_type,
            .aborted = self.aborted,
            .url_list = .{},
            .status = self.status,
            .status_message = self.status_message,
            .header_list = try self.header_list.clone(self.allocator),
            .body = null,
            .cache_state = self.cache_state,
            .cors_exposed_header_name_list = .{},
            .range_requested = self.range_requested,
            .request_includes_credentials = self.request_includes_credentials,
            .timing_allow_passed = self.timing_allow_passed,
            .body_info = self.body_info,
            .service_worker_timing_info = self.service_worker_timing_info,
            .redirect_taint = self.redirect_taint,
        };

        // Clone URL list
        for (self.url_list.items) |u| {
            const owned = try self.allocator.dupe(u8, u);
            try new_response.url_list.append(self.allocator, owned);
        }

        // Clone CORS exposed headers
        for (self.cors_exposed_header_name_list.items) |name| {
            const owned = try self.allocator.dupe(u8, name);
            try new_response.cors_exposed_header_name_list.append(self.allocator, owned);
        }

        // Clone body
        if (self.body) |body| {
            new_response.body = try body.clone(self.allocator);
        }

        return new_response;
    }

    // === CORS Exposed Headers ===

    /// Add a CORS-exposed header name.
    pub fn addCorsExposedHeaderName(self: *Self, name: []const u8) !void {
        const owned = try self.allocator.dupe(u8, name);
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
