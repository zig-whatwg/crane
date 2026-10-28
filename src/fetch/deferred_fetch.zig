//! Fetch 4.12, total request length for fetchLater's quota check.
//!
//! The real deferred records, request preparation, activation and quota
//! traversal are owned by dom.deferred_fetches. This module only measures
//! the constructor's request before the owner queues and populates it.
//!
//! Spec: https://fetch.spec.whatwg.org/#deferred-fetching
//! Design reference (not code): Chromium 33aa7cdb0fba62a372fb8102aeccdadd473cfb2c,
//! core/fetch/fetch_later_util.cc CalculateRequestSize.

const std = @import("std");
const internal = @import("internal/root.zig");
const Request = internal.InternalRequest;

/// Fetch 4.12, "total request length". Request URLs and the referrer must
/// already be serialized. The caller supplies the referrer's serialization
/// before population: "about:client", empty for no-referrer, or the URL.
/// Chromium FetchLaterUtil::CalculateRequestSize (revision above) counts
/// Request::referrer's serialization; liaison Q15 (2026-10-27) resolves the
/// specification's sentinel ambiguity this way. Queueing populates it later.
/// No allocations. Overflow saturates, so an unrepresentable size cannot
/// wrap into an acceptable quota. Unknown-length bodies cannot be deferred.
pub fn totalRequestLength(request: *const Request, serialized_referrer: []const u8) error{UnknownBodyLength}!u64 {
    // 1. Serialize the request's URL excluding its fragment. URLs reaching
    // Fetch are serialized already; an encoded %23 remains part of the URL.
    const url = request.getUrl();
    const end = std.mem.indexOfScalar(u8, url, '#') orelse url.len;
    var length: u64 = end;
    // 2. Add the serialized referrer's length.
    length +|= serialized_referrer.len;
    // 3. Count every header tuple, without delimiters or combining values.
    for (request.header_list.entries.items) |header| {
        length +|= header.name.len;
        length +|= header.value.len;
    }
    // 4. Add the body's known length; a null body contributes zero.
    if (request.body) |body| length +|= switch (body) {
        .bytes => |bytes| bytes.len,
        .body => |value| value.length orelse return error.UnknownBodyLength,
    };
    // 5.
    return length;
}
