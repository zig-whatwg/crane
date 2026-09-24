//! The two Fetch steps with no IDL surface that `fetch()` takes on objects
//! it did not make: "requestObject's request" and "creating a Response
//! object given response and guard".
//!
//! A Request's request and a Response's response are those types' own state,
//! and `fetch()` lives in the WindowOrWorkerGlobalScope mixin, which may not
//! reach into either impl - so Request and Response install their steps here,
//! the shape of `range_boundaries.zig`. Fetch's internal types are opaque at
//! this seam: the dom module does not depend on fetch.
//!
//! Spec: https://fetch.spec.whatwg.org/#dom-global-fetch
//!
//! lint-impls: hook for Request, Response

const std = @import("std");
const runtime = @import("runtime");

/// A Headers object's guard - fetch.internal.HeaderGuard, restated here
/// for the same reason the request and response are opaque.
pub const Guard = enum { immutable, request, request_no_cors, response, none };

pub const RequestSteps = struct {
    /// `request_object`'s request (a `*fetch.internal.InternalRequest`),
    /// borrowed: it lives as long as the Request object.
    request_of: *const fn (request_object: *runtime.Instance) ?*anyopaque,
};

pub const ResponseSteps = struct {
    /// Make `response_object` - a new Response object - hold `response` (a
    /// `*fetch.internal.InternalResponse`, whose ownership passes to it) with
    /// a headers guard of `guard`.
    adopt: *const fn (response_object: *runtime.Instance, response: *anyopaque, guard: Guard) void,
};

threadlocal var request_steps: ?RequestSteps = null;
threadlocal var response_steps: ?ResponseSteps = null;

/// Called by Request. Idempotent.
pub fn installRequest(steps: RequestSteps) void {
    request_steps = steps;
}

/// Called by Response. Idempotent.
pub fn installResponse(steps: ResponseSteps) void {
    response_steps = steps;
}

/// `request_object`'s request, or null when Request has installed nothing -
/// which cannot happen for an object Request's impl made.
pub fn requestOf(request_object: *runtime.Instance) ?*anyopaque {
    const steps = request_steps orelse return null;
    return steps.request_of(request_object);
}

/// Hand `response` to `response_object`. False when Response has installed
/// nothing, and then `response` is still the caller's.
pub fn adoptResponse(response_object: *runtime.Instance, response: *anyopaque, guard: Guard) bool {
    const steps = response_steps orelse return false;
    steps.adopt(response_object, response, guard);
    return true;
}

test "without installed steps nothing is asked of an object" {
    const saved_request = request_steps;
    const saved_response = response_steps;
    defer request_steps = saved_request;
    defer response_steps = saved_response;
    request_steps = null;
    response_steps = null;
    // Never dereferenced: with no steps nothing reads them.
    var object: runtime.Instance = undefined;
    var response: u8 = 0;
    try std.testing.expect(requestOf(&object) == null);
    try std.testing.expect(!adoptResponse(&object, &response, .immutable));
}
