//! Response WebIDL Interface - WHATWG Fetch Specification
//!
//! This module implements the Response WebIDL interface.
//!
//! Spec: https://fetch.spec.whatwg.org/#response-class

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_response = @import("../internal/response.zig");
const InternalResponse = internal_response.InternalResponse;
const ResponseType = internal_response.ResponseType;
const headers_mod = @import("headers.zig");
const Headers = headers_mod.Headers;
const guards = @import("../internal/guards.zig");
const HeadersGuard = guards.HeaderGuard;
const body_mod = @import("../internal/body.zig");
const Body = body_mod.Body;

/// Response initialization options.
/// Corresponds to WebIDL ResponseInit dictionary.
pub const ResponseInit = struct {
    status: u16 = 200,
    status_text: []const u8 = "",
    headers: ?headers_mod.HeadersInit = null,
};

/// Response class per WebIDL.
///
/// Spec: https://fetch.spec.whatwg.org/#response-class
pub const Response = struct {
    allocator: Allocator,
    /// The underlying internal response
    internal: *InternalResponse,
    /// Headers object (with response guard)
    headers_obj: *Headers,
    /// Whether body has been used
    body_used: bool,

    const Self = @This();

    /// Create a new Response object.
    ///
    /// Spec constructor: new Response(body, init)
    pub fn init(allocator: Allocator, body: ?[]const u8, options: ResponseInit) !*Self {
        const response = try allocator.create(Self);
        errdefer allocator.destroy(response);

        // Create internal response
        const internal = try InternalResponse.init(allocator);
        errdefer internal.deinit();

        // Set status
        internal.status = options.status;

        // Create headers with response guard
        const headers_obj = try Headers.initWithGuard(allocator, .response);
        errdefer headers_obj.deinit();

        // Apply headers from init
        if (options.headers) |h| {
            switch (h) {
                .sequence => |seq| {
                    for (seq) |pair| {
                        try headers_obj.append(pair[0], pair[1]);
                    }
                },
                .headers => |other| {
                    for (other.header_list.entries.items) |entry| {
                        try headers_obj.append(entry.name, entry.value);
                    }
                },
                .none => {},
            }
        }

        // Set body if provided
        if (body) |b| {
            internal.body = try Body.fromBytes(allocator, b);
        }

        response.* = .{
            .allocator = allocator,
            .internal = internal,
            .headers_obj = headers_obj,
            .body_used = false,
        };

        return response;
    }

    /// Create Response from internal response.
    pub fn fromInternal(allocator: Allocator, internal: *InternalResponse) !*Self {
        const response = try allocator.create(Self);
        errdefer allocator.destroy(response);

        // Create headers from internal header list
        const headers_obj = try Headers.initWithGuard(allocator, .response);
        errdefer headers_obj.deinit();

        for (internal.header_list.entries.items) |entry| {
            try headers_obj.append(entry.name, entry.value);
        }

        response.* = .{
            .allocator = allocator,
            .internal = internal,
            .headers_obj = headers_obj,
            .body_used = false,
        };

        return response;
    }

    /// Deinitialize the Response object.
    pub fn deinit(self: *Self) void {
        self.internal.deinit();
        self.headers_obj.deinit();
        self.allocator.destroy(self);
    }

    // === Static Methods ===

    /// Create an error Response.
    ///
    /// Spec: Response.error()
    pub fn createError(allocator: Allocator) !*Self {
        const response = try allocator.create(Self);
        errdefer allocator.destroy(response);

        const internal = try internal_response.networkError(allocator);
        errdefer internal.deinit();

        const headers_obj = try Headers.initWithGuard(allocator, .immutable);

        response.* = .{
            .allocator = allocator,
            .internal = internal,
            .headers_obj = headers_obj,
            .body_used = false,
        };

        return response;
    }

    /// Create a redirect Response.
    ///
    /// Spec: Response.redirect(url, status)
    pub fn createRedirect(allocator: Allocator, url_str: []const u8, redirect_status: u16) !*Self {
        // Validate status is a redirect status
        if (!internal_response.isRedirectStatus(redirect_status)) {
            return error.RangeError;
        }

        const response = try allocator.create(Self);
        errdefer allocator.destroy(response);

        const internal = try InternalResponse.init(allocator);
        errdefer internal.deinit();

        internal.status = redirect_status;
        try internal.header_list.append("Location", url_str);

        const headers_obj = try Headers.initWithGuard(allocator, .immutable);

        response.* = .{
            .allocator = allocator,
            .internal = internal,
            .headers_obj = headers_obj,
            .body_used = false,
        };

        return response;
    }

    /// Create a JSON Response.
    ///
    /// Spec: Response.json(data, init)
    pub fn json(allocator: Allocator, json_data: []const u8, options: ResponseInit) !*Self {
        var init_opts = options;

        // Ensure Content-Type is set
        if (init_opts.headers == null) {
            const json_headers = [_][2][]const u8{
                .{ "Content-Type", "application/json" },
            };
            init_opts.headers = .{ .sequence = &json_headers };
        }

        return try Self.init(allocator, json_data, init_opts);
    }

    // === Getters ===

    /// Get the response type.
    pub fn responseType(self: *const Self) ResponseType {
        return self.internal.response_type;
    }

    /// Get the response URL.
    pub fn url(self: *const Self) ?[]const u8 {
        return self.internal.url();
    }

    /// Check if this response was redirected.
    pub fn redirected(self: *const Self) bool {
        return self.internal.url_list.items.len > 1;
    }

    /// Get the status code.
    pub fn status(self: *const Self) u16 {
        return self.internal.status;
    }

    /// Check if status is in 200-299 range.
    pub fn ok(self: *const Self) bool {
        return internal_response.isOkStatus(self.internal.status);
    }

    /// Get the status text.
    pub fn statusText(self: *const Self) []const u8 {
        return self.internal.status_message;
    }

    /// Get the headers object.
    pub fn headers(self: *const Self) *Headers {
        return self.headers_obj;
    }

    /// Check if body has been used.
    pub fn bodyUsed(self: *const Self) bool {
        return self.body_used;
    }

    // === Methods ===

    /// Clone this Response.
    ///
    /// Spec: clone()
    pub fn clone(self: *Self) !*Self {
        if (self.body_used) {
            return error.TypeError;
        }

        const new_response = try self.allocator.create(Self);
        errdefer self.allocator.destroy(new_response);

        new_response.* = .{
            .allocator = self.allocator,
            .internal = try self.internal.clone(),
            .headers_obj = try self.headers_obj.clone(self.allocator),
            .body_used = false,
        };

        return new_response;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Response.init with defaults" {
    const allocator = std.testing.allocator;

    const response = try Response.init(allocator, null, .{});
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 200), response.status());
    try std.testing.expect(response.ok());
}

test "Response.init with status" {
    const allocator = std.testing.allocator;

    const response = try Response.init(allocator, null, .{ .status = 404 });
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 404), response.status());
    try std.testing.expect(!response.ok());
}

test "Response.init with body" {
    const allocator = std.testing.allocator;

    const response = try Response.init(allocator, "Hello, World!", .{});
    defer response.deinit();

    try std.testing.expect(response.internal.body != null);
}

test "Response.init with headers" {
    const allocator = std.testing.allocator;

    const init_headers = [_][2][]const u8{
        .{ "Content-Type", "text/plain" },
    };

    const response = try Response.init(allocator, null, .{
        .headers = .{ .sequence = &init_headers },
    });
    defer response.deinit();

    try std.testing.expect(try response.headers().has("Content-Type"));
}

test "Response.createError" {
    const allocator = std.testing.allocator;

    const response = try Response.createError(allocator);
    defer response.deinit();

    try std.testing.expectEqual(ResponseType.@"error", response.responseType());
    try std.testing.expectEqual(@as(u16, 0), response.status());
}

test "Response.createRedirect" {
    const allocator = std.testing.allocator;

    const response = try Response.createRedirect(allocator, "https://example.com/new", 302);
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 302), response.status());
}

test "Response.createRedirect rejects non-redirect status" {
    const allocator = std.testing.allocator;

    const result = Response.createRedirect(allocator, "https://example.com", 200);
    try std.testing.expectError(error.RangeError, result);
}

test "Response.clone" {
    const allocator = std.testing.allocator;

    const original = try Response.init(allocator, "test", .{ .status = 201 });
    defer original.deinit();

    const cloned = try original.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(@as(u16, 201), cloned.status());
}

test "Response.ok for different statuses" {
    const allocator = std.testing.allocator;

    const ok_response = try Response.init(allocator, null, .{ .status = 200 });
    defer ok_response.deinit();
    try std.testing.expect(ok_response.ok());

    const not_ok = try Response.init(allocator, null, .{ .status = 404 });
    defer not_ok.deinit();
    try std.testing.expect(!not_ok.ok());
}
