//! Mixed Content Level 2: URL authentication, settings restrictions, and
//! request/response checks. The client restriction is captured in the
//! request; this module never consults a live realm or document.
//!
//! https://w3c.github.io/webappsec-mixed-content/
const std = @import("std");
const parser = @import("basic_parser");
const serializer = @import("url_serializer");
const origin = @import("origin");
const URLRecord = @import("url_record").URLRecord;
const trust = @import("referrer_policy").determine_referrer.isPotentiallyTrustworthyOrigin;
const urlParts = @import("algorithms/csp_check.zig").urlParts;
const Request = @import("internal/request.zig").InternalRequest;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.mixed_content);

/// Mixed Content 2's a priori authenticated URL, using Secure Contexts 3.2.
/// Invalid URLs are not authenticated; allocation failure propagates.
pub fn isAPrioriAuthenticated(allocator: Allocator, url: []const u8) error{OutOfMemory}!bool {
    var record = parser.parse(allocator, url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer record.deinit();
    // 3.2 steps 1-2: local documents never introduce a network downgrade.
    if (std.mem.eql(u8, record.scheme(), "about") and record.path == .opaque_path) {
        const path = record.path.opaque_path;
        if (std.mem.eql(u8, path, "blank") or std.mem.eql(u8, path, "srcdoc")) return true;
    }
    if (std.mem.eql(u8, record.scheme(), "data")) return true;
    // 3.2 step 3: use the URL's origin, including a blob's creator origin.
    return recordOriginIsTrustworthy(allocator, &record);
}

/// Secure Contexts 3.1 for a serialized settings origin. An opaque origin
/// is not a trustworthy origin, even when its document has a local URL.
pub fn isOriginAuthenticated(allocator: Allocator, serialized: []const u8) error{OutOfMemory}!bool {
    if (serialized.len == 0 or std.mem.eql(u8, serialized, "null")) return false;
    var record = parser.parse(allocator, serialized, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer record.deinit();
    return recordOriginIsTrustworthy(allocator, &record);
}

fn recordOriginIsTrustworthy(allocator: Allocator, record: *const URLRecord) error{OutOfMemory}!bool {
    // Secure Contexts 3.1 step 6: Crane trusts resources delivered from disk.
    if (std.mem.eql(u8, record.scheme(), "file")) return trust("file", "");
    var value = origin.getOrigin(allocator, record) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer value.deinit(allocator);
    // 3.1 steps 1-2: the tuple predicate requires a tuple origin.
    if (value == .opaque_origin) return false;
    const serialized = value.serialize(allocator) catch return error.OutOfMemory;
    defer allocator.free(serialized);
    const parts = urlParts(serialized);
    return trust(parts.scheme, parts.host orelse "");
}

/// Mixed Content 4.3 over the settings' origin and embedding documents'
/// origins, nearest first. Worker settings without a document pass no
/// ancestors. Callers supply origins, not document URLs or isSecureContext.
pub fn doesSettingsProhibitMixedSecurityContexts(allocator: Allocator, settings_origin: []const u8, ancestor_origins: []const []const u8) error{OutOfMemory}!bool {
    // 1. The settings origin itself is potentially trustworthy.
    if (try isOriginAuthenticated(allocator, settings_origin)) return true;
    // 2.2.1. Walk each ancestor navigable's active document origin.
    for (ancestor_origins) |ancestor| {
        if (try isOriginAuthenticated(allocator, ancestor)) return true;
    }
    // 3. Does not restrict mixed security contexts.
    return false;
}

/// Mixed Content 4.1, called after UIR and before request blocking.
/// Updates only the current URL; the request keeps its client snapshot.
pub fn upgradeRequest(request: *Request) error{OutOfMemory}!void {
    // 1.3-1.5. All of these conditions leave the request unchanged.
    if (!request.prohibits_mixed_security_contexts) return;
    switch (request.destination) {
        .image => if (request.initiator == .imageset) return,
        .audio, .video => {},
        else => return,
    }
    const url = request.currentUrl();
    // 1.1. Potentially trustworthy URLs need no upgrade.
    if (try isAPrioriAuthenticated(request.allocator, url)) return;
    var record = parser.parse(request.allocator, url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return,
    };
    defer record.deinit();
    // 1.2. A parsed IP-address host is not autoupgraded.
    if (record.host) |host| switch (host) {
        .ipv4, .ipv6 => return,
        else => {},
    };
    // 2. Change http to https. Parsing first makes an explicit HTTP default
    // port null. Keep every other port, including an explicit 443; this is
    // a direct scheme change, not the script-facing URL.protocol setter.
    if (!std.mem.eql(u8, record.scheme(), "http")) return;
    const normalized = serializer.serialize(request.allocator, &record, false) catch return error.OutOfMemory;
    defer request.allocator.free(normalized);
    const upgraded = try std.mem.concat(request.allocator, u8, &.{ "https", normalized[4..] });
    const last = &request.url_list.items[request.url_list.items.len - 1];
    log.warn("upgraded mixed content {s} to {s}", .{ url, upgraded });
    request.allocator.free(last.*);
    last.* = upgraded;
}

/// Mixed Content 4.4. Crane's document destination denotes a top-level
/// navigation; nested navigations use iframe/frame/object/embed.
pub fn shouldBlockRequest(request: *const Request) error{OutOfMemory}!bool {
    // 1.1, 1.4. No mixed-content override (1.3) is configured by this UA.
    if (!request.prohibits_mixed_security_contexts or request.destination == .document) return false;
    // 1.2. A priori authenticated URLs are allowed.
    if (try isAPrioriAuthenticated(request.allocator, request.currentUrl())) return false;
    // 2. Blocked.
    log.warn("blocked mixed content request {s}", .{request.currentUrl()});
    return true;
}

/// Mixed Content 4.5, using the internal response's URL. Fetch supplies the
/// current request URL when step 16 would fill an empty response URL list.
pub fn shouldBlockResponse(request: *const Request, response_url: []const u8) error{OutOfMemory}!bool {
    // 1.1, 1.4. Top-level navigation remains allowed. No override (1.3).
    if (!request.prohibits_mixed_security_contexts or request.destination == .document) return false;
    // 1.2. Authenticate the response, independently of the request's URL.
    if (try isAPrioriAuthenticated(request.allocator, response_url)) return false;
    // 2. Blocked.
    log.warn("blocked mixed content response {s}", .{response_url});
    return true;
}
