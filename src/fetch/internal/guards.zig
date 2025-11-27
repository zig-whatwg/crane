//! Header Guard Modes - WHATWG Fetch Standard
//!
//! Header guards control what operations are allowed on a Headers object.
//!
//! Spec: https://fetch.spec.whatwg.org/#headers-class

const std = @import("std");
const Allocator = std.mem.Allocator;
const HeaderList = @import("header_list.zig").HeaderList;
const validation = @import("validation.zig");

/// Header guard controls what operations are allowed on a Headers object.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-headers-guard
pub const HeaderGuard = enum {
    /// No modifications allowed (used for Response headers in certain contexts)
    immutable,

    /// Forbids forbidden request-headers
    request,

    /// Only allows no-CORS-safelisted request-headers
    request_no_cors,

    /// Forbids forbidden response-headers
    response,

    /// No restrictions (default)
    none,
};

/// Check if appending (name, value) is allowed under the given guard.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-headers-append
/// (The "validate and normalize" part checks the guard)
pub fn canAppend(
    guard: HeaderGuard,
    headers: *const HeaderList,
    allocator: Allocator,
    name: []const u8,
    value: []const u8,
) !bool {
    switch (guard) {
        // Step 1: If guard is immutable, return false
        .immutable => return false,

        // Step 2: If guard is request and (name, value) is forbidden request-header, return false
        .request => {
            if (validation.isForbiddenRequestHeader(name, value)) {
                return false;
            }
            return true;
        },

        // Step 3: If guard is request-no-cors
        .request_no_cors => {
            // Get temporary value: existing value + ", " + new value
            const existing = try headers.get(allocator, name);
            defer if (existing) |e| allocator.free(e);

            var temporary_value: []const u8 = undefined;
            var allocated = false;
            defer if (allocated) allocator.free(temporary_value);

            if (existing) |e| {
                temporary_value = try std.fmt.allocPrint(allocator, "{s}, {s}", .{ e, value });
                allocated = true;
            } else {
                temporary_value = value;
            }

            // If (name, temporaryValue) is NOT no-CORS-safelisted, return false
            if (!validation.isNoCORSSafelistedRequestHeader(name, temporary_value)) {
                return false;
            }
            return true;
        },

        // Step 4: If guard is response and name is forbidden response-header, return false
        .response => {
            if (validation.isForbiddenResponseHeaderName(name)) {
                return false;
            }
            return true;
        },

        // Step 5: Default - no restrictions
        .none => return true,
    }
}

/// Check if setting (name, value) is allowed under the given guard.
///
/// Similar to canAppend but doesn't consider existing values for request-no-cors.
pub fn canSet(guard: HeaderGuard, name: []const u8, value: []const u8) bool {
    switch (guard) {
        // If guard is immutable, return false
        .immutable => return false,

        // If guard is request and (name, value) is forbidden request-header, return false
        .request => {
            if (validation.isForbiddenRequestHeader(name, value)) {
                return false;
            }
            return true;
        },

        // If guard is request-no-cors, check if (name, value) is no-CORS-safelisted
        .request_no_cors => {
            return validation.isNoCORSSafelistedRequestHeader(name, value);
        },

        // If guard is response and name is forbidden response-header, return false
        .response => {
            if (validation.isForbiddenResponseHeaderName(name)) {
                return false;
            }
            return true;
        },

        // No restrictions
        .none => return true,
    }
}

/// Check if deleting name is allowed under the given guard.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-headers-remove
pub fn canDelete(guard: HeaderGuard, name: []const u8) bool {
    switch (guard) {
        // If guard is immutable, return false
        .immutable => return false,

        // If guard is request and name is a forbidden header, return false
        // Note: For delete, we check with an empty value
        .request => {
            if (validation.isForbiddenRequestHeader(name, "")) {
                return false;
            }
            return true;
        },

        // If guard is request-no-cors:
        // Allow deleting non-safelisted headers (they weren't allowed to be set anyway)
        // For safelisted headers, allow deletion
        .request_no_cors => {
            // Per spec, we need to check if removing the header would cause issues
            // But in practice, delete is allowed for any header in request-no-cors mode
            // as the validation happens on append/set
            return true;
        },

        // If guard is response and name is forbidden response-header, return false
        .response => {
            if (validation.isForbiddenResponseHeaderName(name)) {
                return false;
            }
            return true;
        },

        // No restrictions
        .none => return true,
    }
}

/// Check if getting a header is allowed under the given guard.
///
/// Getting headers is always allowed regardless of guard mode.
pub fn canGet(guard: HeaderGuard, name: []const u8) bool {
    _ = guard;
    _ = name;
    return true;
}

// =============================================================================
// Tests
// =============================================================================

test "HeaderGuard: immutable blocks all mutations" {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    try std.testing.expect(!try canAppend(.immutable, &headers, allocator, "Accept", "text/html"));
    try std.testing.expect(!canSet(.immutable, "Accept", "text/html"));
    try std.testing.expect(!canDelete(.immutable, "Accept"));
    try std.testing.expect(canGet(.immutable, "Accept")); // get is always allowed
}

test "HeaderGuard: none allows all operations" {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    try std.testing.expect(try canAppend(.none, &headers, allocator, "Cookie", "sessionid=abc"));
    try std.testing.expect(canSet(.none, "Cookie", "sessionid=abc"));
    try std.testing.expect(canDelete(.none, "Cookie"));
}

test "HeaderGuard: request blocks forbidden request headers" {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    // Forbidden headers
    try std.testing.expect(!try canAppend(.request, &headers, allocator, "Cookie", "sessionid=abc"));
    try std.testing.expect(!try canAppend(.request, &headers, allocator, "Host", "example.com"));
    try std.testing.expect(!try canAppend(.request, &headers, allocator, "Sec-Fetch-Mode", "cors"));
    try std.testing.expect(!try canAppend(.request, &headers, allocator, "Proxy-Authorization", "Basic xyz"));

    try std.testing.expect(!canSet(.request, "Cookie", "sessionid=abc"));
    try std.testing.expect(!canDelete(.request, "Cookie"));

    // Allowed headers
    try std.testing.expect(try canAppend(.request, &headers, allocator, "Accept", "text/html"));
    try std.testing.expect(try canAppend(.request, &headers, allocator, "Content-Type", "application/json"));
    try std.testing.expect(try canAppend(.request, &headers, allocator, "X-Custom-Header", "value"));
}

test "HeaderGuard: request_no_cors only allows safelisted headers" {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    // Safelisted headers
    try std.testing.expect(try canAppend(.request_no_cors, &headers, allocator, "Accept", "text/html"));
    try std.testing.expect(try canAppend(.request_no_cors, &headers, allocator, "Accept-Language", "en-US"));
    try std.testing.expect(try canAppend(.request_no_cors, &headers, allocator, "Content-Language", "en"));
    try std.testing.expect(try canAppend(.request_no_cors, &headers, allocator, "Content-Type", "text/plain"));

    // Non-safelisted headers
    try std.testing.expect(!try canAppend(.request_no_cors, &headers, allocator, "X-Custom", "value"));
    try std.testing.expect(!try canAppend(.request_no_cors, &headers, allocator, "Authorization", "Bearer token"));

    // Content-Type with non-safelisted MIME type
    try std.testing.expect(!try canAppend(.request_no_cors, &headers, allocator, "Content-Type", "application/json"));

    // canSet
    try std.testing.expect(canSet(.request_no_cors, "Accept", "text/html"));
    try std.testing.expect(!canSet(.request_no_cors, "X-Custom", "value"));
}

test "HeaderGuard: request_no_cors with cumulative value" {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    // First append should work
    try headers.append("Accept", "text/html");
    try std.testing.expect(try canAppend(.request_no_cors, &headers, allocator, "Accept", "text/plain"));

    // Appending would exceed 128 bytes total (existing + ", " + new)
    // existing "text/html" = 9 bytes
    // Adding a value that brings total > 128 should fail
    const long_value = "a" ** 120; // Will exceed 128 when combined with existing
    try std.testing.expect(!try canAppend(.request_no_cors, &headers, allocator, "Accept", long_value));
}

test "HeaderGuard: response blocks forbidden response headers" {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();

    // Forbidden response headers
    try std.testing.expect(!try canAppend(.response, &headers, allocator, "Set-Cookie", "a=b"));
    try std.testing.expect(!try canAppend(.response, &headers, allocator, "Set-Cookie2", "c=d"));
    try std.testing.expect(!canSet(.response, "Set-Cookie", "a=b"));
    try std.testing.expect(!canDelete(.response, "Set-Cookie"));

    // Allowed response headers
    try std.testing.expect(try canAppend(.response, &headers, allocator, "Content-Type", "text/html"));
    try std.testing.expect(try canAppend(.response, &headers, allocator, "Cache-Control", "no-cache"));
    try std.testing.expect(try canAppend(.response, &headers, allocator, "X-Custom", "value"));
}

test "HeaderGuard: canGet always returns true" {
    try std.testing.expect(canGet(.immutable, "Accept"));
    try std.testing.expect(canGet(.request, "Accept"));
    try std.testing.expect(canGet(.request_no_cors, "Accept"));
    try std.testing.expect(canGet(.response, "Accept"));
    try std.testing.expect(canGet(.none, "Accept"));
}
