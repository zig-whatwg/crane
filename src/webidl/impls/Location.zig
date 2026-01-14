//! Implementation for Location interface
//!
//! Implements the Location interface per HTML Standard §7.1.3.
//! Spec: https://html.spec.whatwg.org/multipage/history.html#the-location-interface
//!
//! ## Overview
//!
//! The Location interface represents the URL of the document and provides
//! methods to manipulate it. Setting URL components triggers navigation.
//!
//! ## Security Model
//!
//! The Location interface has special security requirements:
//! - Cross-origin access is restricted (throws SecurityError)
//! - Only certain properties are accessible cross-origin (href setter, replace)
//!
//! ## Navigation
//!
//! Setting URL components or calling navigation methods triggers:
//! - assign(): Normal navigation (adds to session history)
//! - replace(): Replace navigation (replaces current entry)
//! - reload(): Reloads the current document

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");

// URL modules
const url_record = @import("url_record");
const url_serializer = @import("url_serializer");
const host_serializer = @import("host_serializer");
const origin = @import("origin");
const basic_parser = @import("basic_parser");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

/// Special schemes default ports
/// Per WHATWG URL spec: https://url.spec.whatwg.org/#special-scheme
fn getDefaultPort(scheme: []const u8) ?u16 {
    if (std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "ws")) {
        return 80;
    } else if (std.mem.eql(u8, scheme, "https") or std.mem.eql(u8, scheme, "wss")) {
        return 443;
    } else if (std.mem.eql(u8, scheme, "ftp")) {
        return 21;
    }
    return null;
}

const Location = interfaces.Location;

pub const State = Location.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
};

/// Internal state for Location implementation
/// Contains private data not exposed via WebIDL attributes.
pub const InternalState = struct {
    /// Allocator for this location's resources
    allocator: Allocator,

    /// The associated window (owner)
    window: ?*runtime.Instance = null,

    /// The document's URL as a parsed URLRecord
    /// This is owned by the Document, Location just references it
    url: ?*url_record.URLRecord = null,

    /// Cached ancestor origins (lazily created DOMStringList)
    ancestor_origins: ?*runtime.Instance = null,

    /// Cached href for comparison
    cached_href: ?[]const u8 = null,

    pub fn deinit(self: *InternalState) void {
        if (self.cached_href) |href| {
            self.allocator.free(href);
        }
        // Free the URL if we own it (allocated in init)
        if (self.url) |url| {
            url.deinit();
            self.allocator.destroy(url);
        }
    }
};

/// Helper to get internal state from instance
/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Helper to get URL from internal state
fn getURL(instance: *runtime.Instance) ?*url_record.URLRecord {
    const internal = getInternal(instance) orelse return null;
    return internal.url;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
    };

    // Initialize with default URL (about:blank)
    // Per spec, Location's URL should be the document's URL
    // For WPT tests, we initialize to a default URL that can be updated later
    const parsed_url = try allocator.create(url_record.URLRecord);
    parsed_url.* = try basic_parser.parse(allocator, "about:blank", null);
    internal.url = parsed_url;

    // Store internal state in the instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Update the Location's URL from a URL string
/// Called when navigating or when setting document URL
pub fn setURLFromString(instance: *runtime.Instance, url_string: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;

    // Free old URL if exists
    if (internal.url) |old_url| {
        old_url.deinit();
        allocator.destroy(old_url);
    }

    // Parse new URL
    const parsed_url = try allocator.create(url_record.URLRecord);
    errdefer allocator.destroy(parsed_url);
    parsed_url.* = try basic_parser.parse(allocator, url_string, null);
    internal.url = parsed_url;
}

/// Get internal state (exposed for Window impl to set URL)
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternal(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
}

// =============================================================================
// URL Component Getters
// =============================================================================

/// Getter for href
/// Per spec §7.1.3: Returns the URL serialization of this Location's URL.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Serialize the URL (exclude fragment = false)
    const serialized = try url_serializer.serialize(allocator, url, false);

    return serialized;
}

/// Getter for origin
/// Per spec §7.1.3: Returns the serialization of this Location's origin.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Get origin from URL
    const url_origin = try origin.getOrigin(allocator, url);
    defer url_origin.deinit(allocator);

    // Serialize the origin
    const serialized = try url_origin.serialize(allocator);

    return serialized;
}

/// Getter for protocol
/// Per spec §7.1.3: Returns the scheme of this Location's URL, followed by ":".
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    const scheme = url.scheme();

    // Allocate scheme + ":"
    const result = try allocator.alloc(u8, scheme.len + 1);
    @memcpy(result[0..scheme.len], scheme);
    result[scheme.len] = ':';

    return result;
}

/// Getter for host
/// Per spec §7.1.3: Returns this Location's URL host and port (if different from default).
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no host, return empty string
    if (url.host == null) {
        return "";
    }

    // Serialize host
    const host_str = try host_serializer.serializeHost(allocator, url.host.?);
    defer allocator.free(host_str);

    // If no port or default port, return just host
    if (url.port == null) {
        const buffer = try allocator.dupe(u8, host_str);
        return buffer;
    }

    // Check if port is default for scheme
    const scheme = url.scheme();
    const default_port = getDefaultPort(scheme);
    if (default_port != null and url.port.? == default_port.?) {
        const buffer = try allocator.dupe(u8, host_str);
        return buffer;
    }

    // Return host:port
    const result = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ host_str, url.port.? });

    return result;
}

/// Getter for hostname
/// Per spec §7.1.3: Returns this Location's URL host, serialized.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no host, return empty string
    if (url.host == null) {
        return "";
    }

    // Serialize host
    const host_str = try host_serializer.serializeHost(allocator, url.host.?);

    return host_str;
}

/// Getter for port
/// Per spec §7.1.3: Returns this Location's URL port, serialized.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no port, return empty string
    if (url.port == null) {
        return "";
    }

    // Serialize port
    const result = try std.fmt.allocPrint(allocator, "{d}", .{url.port.?});

    return result;
}

/// Getter for pathname
/// Per spec §7.1.3: Returns the URL path serialized.
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // Use the path component from URL
    switch (url.path) {
        .opaque_path => |op| {
            const buffer = try allocator.dupe(u8, op);
            return buffer;
        },
        .segments => |segs| {
            // Build path string with "/" separators
            var result = std.ArrayListUnmanaged(u8){};
            errdefer result.deinit(allocator);

            var i: usize = 0;
            while (i < segs.len) : (i += 1) {
                try result.append(allocator, '/');
                if (segs.get(i)) |segment| {
                    try result.appendSlice(allocator, segment);
                }
            }

            // If empty segments, return "/"
            if (result.items.len == 0) {
                try result.append(allocator, '/');
            }

            const buffer = try result.toOwnedSlice(allocator);
            return buffer;
        },
    }
}

/// Getter for search
/// Per spec §7.1.3: Returns this Location's URL query (includes "?").
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no query, return empty string
    const query = url.query() orelse {
        return "";
    };

    // Return "?" + query
    const result = try allocator.alloc(u8, query.len + 1);
    result[0] = '?';
    @memcpy(result[1..], query);

    return result;
}

/// Getter for hash
/// Per spec §7.1.3: Returns this Location's URL fragment (includes "#").
/// Returns DOMString with owned memory that caller must free.
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const url = getURL(instance) orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // If no fragment, return empty string
    const fragment = url.fragment() orelse {
        return "";
    };

    // Return "#" + fragment
    const result = try allocator.alloc(u8, fragment.len + 1);
    result[0] = '#';
    @memcpy(result[1..], fragment);

    return result;
}

/// Getter for ancestorOrigins
/// Per spec §7.1.3: Returns a DOMStringList of ancestor browsing context origins.
pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // TODO: Implement DOMStringList creation
    // This requires:
    // 1. Walking up the browsing context tree
    // 2. Collecting origins from each ancestor
    // 3. Creating a DOMStringList with those origins
    return error.NotImplemented;
}

// =============================================================================
// URL Component Setters
// =============================================================================

/// Setter for href
/// Per spec §7.1.3: Navigate to the given URL.
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // Navigate to the URL
    return call_assign(instance, value);
}

/// Setter for protocol
/// Per spec §7.1.3: Update URL scheme if valid, then navigate.
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement protocol setter
    // This requires parsing the value and updating the URL's scheme
    // Then triggering navigation
    return error.NotImplemented;
}

/// Setter for host
/// Per spec §7.1.3: Update URL host and port, then navigate.
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement host setter
    return error.NotImplemented;
}

/// Setter for hostname
/// Per spec §7.1.3: Update URL hostname, then navigate.
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement hostname setter
    return error.NotImplemented;
}

/// Setter for port
/// Per spec §7.1.3: Update URL port, then navigate.
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement port setter
    return error.NotImplemented;
}

/// Setter for pathname
/// Per spec §7.1.3: Update URL pathname, then navigate.
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement pathname setter
    return error.NotImplemented;
}

/// Setter for search
/// Per spec §7.1.3: Update URL query, then navigate.
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement search setter
    return error.NotImplemented;
}

/// Setter for hash
/// Per spec §7.1.3: Update URL fragment, then navigate (fragment navigation).
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    // TODO: Implement hash setter
    // This may trigger fragment-only navigation (hashchange event)
    return error.NotImplemented;
}

// =============================================================================
// Navigation Methods
// =============================================================================

/// Operation: assign
/// Per spec §7.1.3: Navigate to url, adding entry to session history.
pub fn call_assign(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;

    // Step 1: Get base URL (document's URL) for relative URL resolution
    const base_url = internal.url;

    // Step 2: Parse the URL
    // Per spec: If url cannot be parsed, throw a "SyntaxError" DOMException
    var parsed_url = basic_parser.parse(allocator, url, base_url) catch {
        // URL parsing failed - throw SyntaxError
        // Per HTML spec §7.1.3.2, invalid URLs throw "SyntaxError" DOMException
        return error.SyntaxError;
    };
    defer parsed_url.deinit();

    // URL is valid - proceed with navigation
    // TODO: Implement actual navigation
    // 1. Check security (same-origin or appropriate permissions)
    // 2. Navigate the browsing context with history handling = "push"

    // For now, we just validated the URL
    // Full navigation requires Phase 6: Navigation & History
    return error.NotImplemented;
}

/// Operation: replace
/// Per spec §7.1.3: Navigate to url, replacing current session history entry.
pub fn call_replace(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;

    // Step 1: Get base URL (document's URL) for relative URL resolution
    const base_url = internal.url;

    // Step 2: Parse the URL
    // Per spec: If url cannot be parsed, throw a "SyntaxError" DOMException
    var parsed_url = basic_parser.parse(allocator, url, base_url) catch {
        // URL parsing failed - throw SyntaxError
        return error.SyntaxError;
    };
    defer parsed_url.deinit();

    // URL is valid - proceed with navigation
    // TODO: Implement actual replace navigation
    // Same as assign but with history handling = "replace"
    return error.NotImplemented;
}

/// Operation: reload
/// Per spec §7.1.3: Reload the document.
pub fn call_reload(instance: *runtime.Instance) anyerror!void {
    _ = instance;

    // TODO: Implement reload
    // This triggers a reload of the current document
    return error.NotImplemented;
}
