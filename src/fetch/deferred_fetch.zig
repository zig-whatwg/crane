//! Fetch 4.12's deferred records, request preparation and quota accounting.
//!
//! These algorithms own no realm, platform object, timer or registry. The
//! environment's fetch-group owner supplies the control-document traversal,
//! schedules activation and hands a taken request to Fetch. In particular,
//! taking a request does not depend on the originating realm remaining alive.
//!
//! Spec: https://fetch.spec.whatwg.org/#deferred-fetching
//! Design reference (not code): Chromium 33aa7cdb0fba62a372fb8102aeccdadd473cfb2c,
//! core/fetch/fetch_manager.cc DeferredLoader::Process and
//! core/fetch/fetch_later_util.cc CalculateRequestSize/UpdateDeferredBytesQuota.

const std = @import("std");
const internal = @import("internal/root.zig");
const Request = internal.InternalRequest;

/// Fetch 2.4, a deferred fetch record's invoke state.
pub const InvokeState = enum { pending, sent, aborted };

/// Native request state, owned by its environment's deferred-fetch list.
/// The result's activated boolean is separate: script may retain that result
/// after this record has ended. The list owner supplies its retention.
pub const Record = struct {
    request: ?*Request,
    total_request_length: u64,
    activate_after_ms: ?f64,
    invoke_state: InvokeState = .pending,

    /// Takes the already prepared request. No allocation and no failure.
    pub fn init(request: *Request, total_request_length: u64, activate_after_ms: ?f64) Record {
        return .{
            .request = request,
            .total_request_length = total_request_length,
            .activate_after_ms = activate_after_ms,
        };
    }

    /// Frees a request that was never transferred to Fetch.
    pub fn deinit(self: *Record) void {
        if (self.request) |request| request.deinit();
        self.request = null;
    }

    /// "Process a deferred fetch" steps 1-3. Returns the request exactly
    /// once, TAKEN by the caller, which starts Fetch and queues notification.
    pub fn takeForActivation(self: *Record) ?*Request {
        // 1. Only a pending record can be processed.
        if (self.invoke_state != .pending) return null;
        // 2. Mark sent before any fetch or notification can run.
        self.invoke_state = .sent;
        // 3. Fetch takes the request; the list no longer owns it.
        const request = self.request;
        self.request = null;
        return request;
    }

    /// fetchLater() step 16. Abort after activation does not reclaim a
    /// request already handed to Fetch or reset the result's activated bit.
    pub fn abort(self: *Record) void {
        self.invoke_state = .aborted;
    }
};

/// "Queue a deferred fetch" steps 1-3. BORROWS request and client; the
/// request owns the policies, origin and referrer copied from its client.
/// On allocation failure the caller still owns and must destroy request.
pub fn prepare(request: *Request, client: internal.RequestClient) !void {
    // 1. Populate request from client while its settings are available.
    try internal.populateRequestFromClient(request, client);
    // 2. Deferred fetches bypass service workers.
    request.service_workers_mode = .none;
    // 3. A deferred request is keepalive, independently of RequestInit.
    request.keepalive = true;
}

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

/// Fetch 4.12.1, available deferred-fetch quota step 6. The document owner
/// supplies its topology, policy answers and navigable-container reservation.
pub fn allocatedQuota(options: struct {
    is_top_level: bool,
    deferred_fetch_allowed: bool,
    minimal_allowed: bool,
    reserved: u64,
}) u64 {
    if (options.is_top_level) {
        if (!options.deferred_fetch_allowed) return 0;
        if (!options.minimal_allowed) return Quota.top_level;
        return Quota.top_level - Quota.minimal_pool;
    }
    if (options.deferred_fetch_allowed and (options.reserved == 0 or options.reserved == Quota.per_origin)) return options.reserved;
    if (options.minimal_allowed and options.reserved == Quota.minimal) return Quota.minimal;
    return 0;
}

/// Fetch 4.12.1, available deferred-fetch quota steps 7-11. The caller
/// traverses precisely the documents sharing the control document, supplying
/// its allocated quota and their reserved containers and deferred records.
pub const Quota = struct {
    total: u64,
    request_origin: u64 = per_origin,

    pub const per_origin: u64 = 64 * 1024;
    pub const minimal: u64 = 8 * 1024;
    pub const top_level: u64 = 640 * 1024;
    pub const minimal_pool: u64 = 128 * 1024;

    /// Steps 6-7: the allocation and a fresh 64 KiB request-origin budget.
    pub fn init(allocation: u64) Quota {
        return .{ .total = allocation };
    }

    /// Step 8.1: each descendant container's reservation reduces the total.
    pub fn reserveContainer(self: *Quota, bytes: u64) void {
        self.total -|= bytes;
    }

    /// Steps 8.2.1-4: only pending requests consume quota. A reporting-origin
    /// match additionally consumes that origin's separate 64 KiB budget.
    pub fn accountRequest(self: *Quota, bytes: u64, same_request_origin: bool, state: InvokeState) void {
        if (state != .pending) return;
        self.total -|= bytes;
        if (same_request_origin) self.request_origin -|= bytes;
    }

    /// Steps 9-11. Saturating decrements represent all nonpositive quotas as 0.
    pub fn available(self: Quota) u64 {
        return @min(self.total, self.request_origin);
    }
};
