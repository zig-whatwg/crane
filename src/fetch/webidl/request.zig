//! Request WebIDL Interface - WHATWG Fetch Specification
//!
//! This module implements the Request WebIDL interface.
//!
//! Spec: https://fetch.spec.whatwg.org/#request-class

const std = @import("std");
const Allocator = std.mem.Allocator;
const internal_request = @import("../internal/request.zig");
const InternalRequest = internal_request.InternalRequest;
const headers_mod = @import("headers.zig");
const Headers = headers_mod.Headers;
const guards = @import("../internal/guards.zig");
const HeadersGuard = guards.HeaderGuard;
const body_mod = @import("../internal/body.zig");
const Body = body_mod.Body;

/// Request initialization options.
/// Corresponds to WebIDL RequestInit dictionary.
pub const RequestInit = struct {
    method: ?[]const u8 = null,
    headers: ?headers_mod.HeadersInit = null,
    body: ?[]const u8 = null,
    referrer: ?[]const u8 = null,
    referrer_policy: ?internal_request.ReferrerPolicy = null,
    mode: ?internal_request.RequestMode = null,
    credentials: ?internal_request.CredentialsMode = null,
    cache: ?internal_request.CacheMode = null,
    redirect: ?internal_request.RedirectMode = null,
    integrity: ?[]const u8 = null,
    keepalive: ?bool = null,
    signal: ?*anyopaque = null, // AbortSignal
};

/// Request class per WebIDL.
///
/// Spec: https://fetch.spec.whatwg.org/#request-class
pub const Request = struct {
    allocator: Allocator,
    /// The underlying internal request
    internal: *InternalRequest,
    /// Headers object (with request guard)
    headers_obj: *Headers,
    /// Whether body has been used
    body_used: bool,
    /// Signal for abort
    signal: ?*anyopaque,

    const Self = @This();

    /// Create a new Request object.
    ///
    /// Spec constructor: new Request(input, init)
    pub fn init(allocator: Allocator, input: RequestInput, options: RequestInit) !*Self {
        const request = try allocator.create(Self);
        errdefer allocator.destroy(request);

        // Create internal request based on input
        const internal = switch (input) {
            .url => |url_str| try InternalRequest.init(allocator, url_str),
            .request => |other| try other.internal.clone(),
        };
        errdefer internal.deinit();

        // Apply init options
        if (options.method) |m| {
            try internal.setMethod(m);
        }

        if (options.mode) |m| {
            internal.mode = m;
        }

        if (options.credentials) |c| {
            internal.credentials_mode = c;
        }

        if (options.cache) |c| {
            internal.cache_mode = c;
        }

        if (options.redirect) |r| {
            internal.redirect_mode = r;
        }

        if (options.referrer_policy) |p| {
            internal.referrer_policy = p;
        }

        if (options.keepalive) |k| {
            internal.keepalive = k;
        }

        if (options.integrity) |i| {
            internal.integrity_metadata = i;
        }

        // Create headers with request guard
        const headers_obj = try Headers.initWithGuard(allocator, .request);
        errdefer headers_obj.deinit();

        // Copy headers from init or input
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
        } else if (input == .request) {
            // Copy from input request
            for (input.request.headers_obj.header_list.entries.items) |entry| {
                try headers_obj.append(entry.name, entry.value);
            }
        }

        // Handle body
        if (options.body) |body_bytes| {
            internal.body = .{ .bytes = body_bytes };
        }

        request.* = .{
            .allocator = allocator,
            .internal = internal,
            .headers_obj = headers_obj,
            .body_used = false,
            .signal = options.signal,
        };

        return request;
    }

    /// Deinitialize the Request object.
    pub fn deinit(self: *Self) void {
        self.internal.deinit();
        self.headers_obj.deinit();
        self.allocator.destroy(self);
    }

    // === Getters ===

    /// Get the request method.
    pub fn method(self: *const Self) []const u8 {
        return self.internal.method;
    }

    /// Get the request URL.
    pub fn url(self: *const Self) []const u8 {
        return self.internal.getUrl();
    }

    /// Get the headers object.
    pub fn headers(self: *const Self) *Headers {
        return self.headers_obj;
    }

    /// Get the destination.
    pub fn destination(self: *const Self) internal_request.Destination {
        return self.internal.destination;
    }

    /// Get the referrer.
    pub fn referrer(self: *const Self) []const u8 {
        return switch (self.internal.referrer) {
            .no_referrer => "",
            .client => "about:client",
            .url => |u| u,
        };
    }

    /// Get the referrer policy.
    pub fn referrerPolicy(self: *const Self) internal_request.ReferrerPolicy {
        return self.internal.referrer_policy;
    }

    /// Get the mode.
    pub fn mode(self: *const Self) internal_request.RequestMode {
        return self.internal.mode;
    }

    /// Get the credentials mode.
    pub fn credentials(self: *const Self) internal_request.CredentialsMode {
        return self.internal.credentials_mode;
    }

    /// Get the cache mode.
    pub fn cache(self: *const Self) internal_request.CacheMode {
        return self.internal.cache_mode;
    }

    /// Get the redirect mode.
    pub fn redirect(self: *const Self) internal_request.RedirectMode {
        return self.internal.redirect_mode;
    }

    /// Get the integrity metadata.
    pub fn integrity(self: *const Self) []const u8 {
        return self.internal.integrity_metadata;
    }

    /// Get keepalive flag.
    pub fn keepalive(self: *const Self) bool {
        return self.internal.keepalive;
    }

    /// Check if this is a reload navigation.
    pub fn isReloadNavigation(self: *const Self) bool {
        return self.internal.reload_navigation;
    }

    /// Check if this is a history navigation.
    pub fn isHistoryNavigation(self: *const Self) bool {
        return self.internal.history_navigation;
    }

    /// Check if body has been used.
    pub fn bodyUsed(self: *const Self) bool {
        return self.body_used;
    }

    // === Methods ===

    /// Clone this Request.
    ///
    /// Spec: clone()
    pub fn clone(self: *Self) !*Self {
        if (self.body_used) {
            return error.TypeError; // Body already used
        }

        const new_request = try self.allocator.create(Self);
        errdefer self.allocator.destroy(new_request);

        new_request.* = .{
            .allocator = self.allocator,
            .internal = try self.internal.clone(),
            .headers_obj = try self.headers_obj.clone(self.allocator),
            .body_used = false,
            .signal = self.signal,
        };

        return new_request;
    }
};

/// Request input type.
pub const RequestInput = union(enum) {
    url: []const u8,
    request: *Request,
};

// =============================================================================
// Tests
// =============================================================================

test "Request.init with URL" {
    const allocator = std.testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{});
    defer request.deinit();

    try std.testing.expectEqualStrings("GET", request.method());
    try std.testing.expectEqualStrings("https://example.com", request.url());
}

test "Request.init with method" {
    const allocator = std.testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .method = "POST",
    });
    defer request.deinit();

    try std.testing.expectEqualStrings("POST", request.method());
}

test "Request.init with headers" {
    const allocator = std.testing.allocator;

    const init_headers = [_][2][]const u8{
        .{ "Content-Type", "application/json" },
    };

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .headers = .{ .sequence = &init_headers },
    });
    defer request.deinit();

    try std.testing.expect(try request.headers().has("Content-Type"));
}

test "Request.init with mode" {
    const allocator = std.testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .mode = .cors,
    });
    defer request.deinit();

    try std.testing.expectEqual(internal_request.RequestMode.cors, request.mode());
}

test "Request.clone" {
    const allocator = std.testing.allocator;

    const original = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .method = "POST",
    });
    defer original.deinit();

    const cloned = try original.clone();
    defer cloned.deinit();

    try std.testing.expectEqualStrings("POST", cloned.method());
    try std.testing.expectEqualStrings("https://example.com", cloned.url());
}
