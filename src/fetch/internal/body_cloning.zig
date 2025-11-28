//! WHATWG Fetch Standard - Body Cloning Algorithms
//!
//! This module implements body cloning algorithms for Request/Response cloning.
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-body-clone

const std = @import("std");
const Allocator = std.mem.Allocator;
const body_mod = @import("body.zig");
const Body = body_mod.Body;
const request_mod = @import("request.zig");
const InternalRequest = request_mod.InternalRequest;
const response_mod = @import("response.zig");
const InternalResponse = response_mod.InternalResponse;

// =============================================================================
// Body Cloning Errors
// =============================================================================

/// Errors that can occur during body cloning.
pub const BodyCloneError = error{
    /// Body cannot be cloned because it has already been used/consumed.
    BodyAlreadyUsed,
    /// Body cannot be cloned because stream is locked.
    StreamLocked,
    /// Out of memory.
    OutOfMemory,
};

// =============================================================================
// Body Used State
// =============================================================================

/// Check if a body has been used (stream is disturbed or locked).
///
/// Per spec: "The bodyUsed attribute's getter must return true if this's body
/// is non-null and this's body's stream is disturbed; otherwise false."
///
/// For our implementation without full streams, we check the disturbed and used flags.
pub fn isBodyUsed(body: *const Body) bool {
    return body.isDisturbed() or body.isUsed();
}

/// Check if a body can be cloned.
///
/// Per spec, body cannot be cloned if its stream is locked.
/// For our implementation, we check if the body has been used.
pub fn canClone(body: *const Body) bool {
    // A body can be cloned if it hasn't been used yet.
    // In full streams implementation, this would check stream.isLocked().
    return !body.isUsed();
}

// =============================================================================
// Clone Body
// =============================================================================

/// Clone a body.
///
/// Spec Algorithm (https://fetch.spec.whatwg.org/#concept-body-clone):
/// 1. Let (out1, out2) = tee(body's stream)
/// 2. Set body's stream to out1
/// 3. Return a body whose stream is out2 and other members are copied from body
///
/// Since we don't have full ReadableStream integration yet, this clones the
/// underlying byte data directly. Both bodies share the same source reference.
pub fn cloneBody(allocator: Allocator, body: *Body) !*Body {
    return try body.clone(allocator);
}

/// Clone body, throwing error if body cannot be cloned.
///
/// This is the safe version that checks preconditions before cloning.
pub fn cloneBodyOrThrow(allocator: Allocator, body: *Body) BodyCloneError!*Body {
    if (!canClone(body)) {
        return BodyCloneError.BodyAlreadyUsed;
    }
    return body.clone(allocator) catch |err| switch (err) {
        error.OutOfMemory => return BodyCloneError.OutOfMemory,
    };
}

// =============================================================================
// Clone for Request
// =============================================================================

/// Clone a request's body for Request.clone().
///
/// Per spec: "If request's body is non-null, set clonedRequest's body to the
/// result of cloning request's body."
///
/// If body is null, returns null.
pub fn cloneRequestBody(
    allocator: Allocator,
    request: *const InternalRequest,
) !?*Body {
    const body_union = request.body orelse return null;

    switch (body_union) {
        .bytes => |bytes| {
            // Create body from raw bytes.
            return try Body.fromBytes(allocator, bytes);
        },
        .body => |body_ptr| {
            // Clone the body.
            return try cloneBody(allocator, body_ptr);
        },
    }
}

/// Clone a request's body, throwing error if body cannot be cloned.
pub fn cloneRequestBodyOrThrow(
    allocator: Allocator,
    request: *const InternalRequest,
) BodyCloneError!?*Body {
    const body_union = request.body orelse return null;

    switch (body_union) {
        .bytes => |bytes| {
            return Body.fromBytes(allocator, bytes) catch |err| switch (err) {
                error.OutOfMemory => return BodyCloneError.OutOfMemory,
            };
        },
        .body => |body_ptr| {
            return try cloneBodyOrThrow(allocator, body_ptr);
        },
    }
}

// =============================================================================
// Clone for Response
// =============================================================================

/// Clone a response's body for Response.clone().
///
/// Per spec: "If response's body is non-null, set clonedResponse's body to the
/// result of cloning response's body."
///
/// If body is null, returns null.
pub fn cloneResponseBody(
    allocator: Allocator,
    response: *const InternalResponse,
) !?*Body {
    const body = response.body orelse return null;
    return try cloneBody(allocator, body);
}

/// Clone a response's body, throwing error if body cannot be cloned.
pub fn cloneResponseBodyOrThrow(
    allocator: Allocator,
    response: *const InternalResponse,
) BodyCloneError!?*Body {
    const body = response.body orelse return null;
    return try cloneBodyOrThrow(allocator, body);
}

// =============================================================================
// Tests
// =============================================================================

test "cloneBody creates independent copy" {
    const allocator = std.testing.allocator;

    const original = try Body.fromBytes(allocator, "Hello, World!");
    defer original.deinit();

    const cloned = try cloneBody(allocator, original);
    defer cloned.deinit();

    // Both should have same content.
    try std.testing.expectEqualStrings("Hello, World!", original.getBytes());
    try std.testing.expectEqualStrings("Hello, World!", cloned.getBytes());

    // Clone should be independent.
    try std.testing.expect(original != cloned);
}

test "cloneBody copies source and length" {
    const allocator = std.testing.allocator;

    const original = try Body.fromBytes(allocator, "Test");
    defer original.deinit();

    const cloned = try cloneBody(allocator, original);
    defer cloned.deinit();

    // Source and length should match.
    try std.testing.expectEqual(original.source, cloned.source);
    try std.testing.expectEqual(original.length, cloned.length);

    // Used state should be reset for clone.
    try std.testing.expect(!cloned.isUsed());
    try std.testing.expect(!cloned.isDisturbed());
}

test "isBodyUsed returns true for used body" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Test");
    defer body.deinit();

    try std.testing.expect(!isBodyUsed(body));

    body.markUsed();

    try std.testing.expect(isBodyUsed(body));
}

test "isBodyUsed returns true for disturbed body" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Test");
    defer body.deinit();

    try std.testing.expect(!isBodyUsed(body));

    body.markDisturbed();

    try std.testing.expect(isBodyUsed(body));
}

test "canClone returns false for used body" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Test");
    defer body.deinit();

    try std.testing.expect(canClone(body));

    body.markUsed();

    try std.testing.expect(!canClone(body));
}

test "cloneBodyOrThrow fails for used body" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Test");
    defer body.deinit();

    body.markUsed();

    const result = cloneBodyOrThrow(allocator, body);
    try std.testing.expectError(BodyCloneError.BodyAlreadyUsed, result);
}

test "cloneBodyOrThrow succeeds for unused body" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Test");
    defer body.deinit();

    const cloned = try cloneBodyOrThrow(allocator, body);
    defer cloned.deinit();

    try std.testing.expectEqualStrings("Test", cloned.getBytes());
}

test "cloneRequestBody with null body" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    // Request body is null by default.
    const cloned_body = try cloneRequestBody(allocator, request);
    try std.testing.expect(cloned_body == null);
}

test "cloneRequestBody with bytes body" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    // Set body to bytes.
    request.body = .{ .bytes = "request body" };

    const cloned_body = try cloneRequestBody(allocator, request);
    defer if (cloned_body) |b| b.deinit();

    try std.testing.expect(cloned_body != null);
    try std.testing.expectEqualStrings("request body", cloned_body.?.getBytes());
}

test "cloneRequestBody with Body object" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    // Create and set body. Request takes ownership, so no defer here.
    const body = try Body.fromBytes(allocator, "body content");
    request.body = .{ .body = body };

    const cloned_body = try cloneRequestBody(allocator, request);
    defer if (cloned_body) |b| b.deinit();

    try std.testing.expect(cloned_body != null);
    try std.testing.expectEqualStrings("body content", cloned_body.?.getBytes());
}

test "cloneResponseBody with null body" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    // Response body is null by default.
    const cloned_body = try cloneResponseBody(allocator, response);
    try std.testing.expect(cloned_body == null);
}

test "cloneResponseBody with body" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    // Create and set body.
    const body = try Body.fromBytes(allocator, "response body");
    // Note: response takes ownership via pointer, we need to handle cleanup.
    response.body = body;

    const cloned_body = try cloneResponseBody(allocator, response);
    defer if (cloned_body) |b| b.deinit();

    try std.testing.expect(cloned_body != null);
    try std.testing.expectEqualStrings("response body", cloned_body.?.getBytes());
}

test "cloneResponseBodyOrThrow fails for used body" {
    const allocator = std.testing.allocator;

    const response = try InternalResponse.init(allocator);
    defer response.deinit();

    const body = try Body.fromBytes(allocator, "response body");
    response.body = body;
    body.markUsed();

    const result = cloneResponseBodyOrThrow(allocator, response);
    try std.testing.expectError(BodyCloneError.BodyAlreadyUsed, result);
}
