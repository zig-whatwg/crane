//! Implementation for URL interface
//!
//! WHATWG URL Standard implementation
//! Spec: https://url.spec.whatwg.org/

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const URL = interfaces.URL;
const URLSearchParams = interfaces.URLSearchParams;

// Import V8 for internal field access
const v8_engine = @import("v8");
const v8 = v8_engine.ffi;

// Import file module for Blob URL store
const file_mod = @import("file");
const BlobURLStore = file_mod.BlobURLStore;
const BlobImpl = @import("Blob.zig");

// Import URL infrastructure from src/url/
const URLRecord = @import("url_record").URLRecord;
const api_parser = @import("api_parser");
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");
const host_serializer = @import("host_serializer");
const path_serializer = @import("path_serializer");
const origin_module = @import("origin");
const percent_encoding = @import("percent_encoding");
const EncodeSet = @import("encode_sets").EncodeSet;
const ParserState = @import("parser_state").ParserState;
const form_parser = @import("form_parser");
const infra = @import("infra");

/// URLSearchParams's InternalState structure (for type-safe casting)
/// This mirrors the structure in URLSearchParams.zig without creating a circular dependency
/// MUST use form_parser.Tuple to match the actual list type in URLSearchParams
const URLSearchParamsInternalState = struct {
    list: infra.List(form_parser.Tuple),
    url_object: ?*runtime.Instance,
    allocator: std.mem.Allocator,
};

pub const State = URL.State;

/// Internal state for URL implementation
/// This stores the parsed URL structure (like Chrome's KURL)
pub const InternalState = struct {
    url_record: URLRecord,
    query_params_instance: ?*runtime.Instance,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.url_record.deinit();
        // Clean up the URLSearchParams instance we own.
        //
        // BIDIRECTIONAL CLEANUP COORDINATION:
        // - If wrapper_cache cleaned up URLSearchParams first, it will have:
        //   1. Set self.query_params_instance = null (via URLSearchParams.deinit's back-reference)
        //   2. Freed the URLSearchParams Instance via SlabAllocator
        // - So we only clean up if query_params_instance is still set.
        //
        // - If we're cleaned up first, URLSearchParams.deinit is safe to call
        //   because it checks its own internal state before doing anything.
        if (self.query_params_instance) |params_instance| {
            URLSearchParams.deinit(params_instance);
            self.query_params_instance = null;
        }
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;
        internal.deinit(allocator);
        state.own._internal = null; // Mark as cleaned up to prevent double-free
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://url.spec.whatwg.org/#dom-url-url (lines 1794-1800)
pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) !*runtime.Instance {
    // Create instance
    const instance = try init(ctx.allocator, State, &URL.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Step 1: Parse base URL if provided
    var base_record: ?URLRecord = null;
    const base_slice = if (base.was_passed) base.value else "";
    if (base_slice.len > 0) {
        base_record = api_parser.parseURL(ctx.allocator, base_slice, null) catch {
            return error.TypeError; // Base URL parse failed
        };
    }
    defer if (base_record) |*br| br.deinit();

    // Step 1: Parse URL with optional base
    var parsed_url = api_parser.parseURL(
        ctx.allocator,
        url,
        if (base_record) |*br| br else null,
    ) catch {
        // Step 2: If parsedURL is failure, throw TypeError
        return error.TypeError;
    };
    // errdefer for parsed_url only until ownership is transferred
    var url_owned = true;
    errdefer if (url_owned) parsed_url.deinit();

    // Create InternalState
    const internal = try ctx.allocator.create(InternalState);
    errdefer if (url_owned) ctx.allocator.destroy(internal);

    internal.* = InternalState{
        .url_record = parsed_url,
        .query_params_instance = null,
        .allocator = ctx.allocator,
    };

    // Transfer ownership to instance - from here, errdefer deinit(instance) handles cleanup
    state.own._internal = internal;
    url_owned = false; // Ownership transferred - don't double-free

    // Initialize URLSearchParams instance with query from URLRecord
    const query_str = parsed_url.query() orelse "";
    const URLSearchParamsInterface = interfaces.URLSearchParams;

    // Create URLSearchParams instance - pass empty init_data for now
    const query_params_instance = try URLSearchParamsInterface.call_constructor(
        ctx,
        webidl.Opt(runtime.JSValue).notPassed(),
    );
    errdefer URLSearchParamsInterface.deinit(query_params_instance);

    // Get URLSearchParams internal state and initialize it with query string
    const URLSearchParamsState = interfaces.URLSearchParams.State;
    const params_state = query_params_instance.getState(URLSearchParamsState);
    if (params_state.own._internal) |params_internal| {
        // Parse query string into list
        if (query_str.len > 0) {
            const tuples = try form_parser.parse(ctx.allocator, query_str);
            for (tuples) |tuple| {
                try params_internal.list.append(tuple);
            }
            ctx.allocator.free(tuples);
        }

        // Set back-reference to URL
        params_internal.url_object = instance;
    }

    // Store URLSearchParams instance in URL's internal state
    internal.query_params_instance = query_params_instance;

    return instance;
}

// ========================================================================
// Getters
// ========================================================================

/// href getter
/// Spec: https://url.spec.whatwg.org/#dom-url-href (line 1855)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return url_serializer.serialize(instance.ctx.allocator, &internal.url_record, false);
}

/// origin getter
/// Spec: https://url.spec.whatwg.org/#dom-url-origin (line 1871)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;
    const url_origin = try origin_module.getOrigin(allocator, &internal.url_record);
    defer url_origin.deinit(allocator);
    return url_origin.serialize(allocator);
}

/// protocol getter
/// Spec: https://url.spec.whatwg.org/#dom-url-protocol (line 1873)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;
    const scheme = internal.url_record.scheme();
    const result = try allocator.alloc(u8, scheme.len + 1);
    @memcpy(result[0..scheme.len], scheme);
    result[scheme.len] = ':';
    return result;
}

/// username getter
/// Spec: https://url.spec.whatwg.org/#dom-url-username (line 1877)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.url_record.username());
}

/// password getter
/// Spec: https://url.spec.whatwg.org/#dom-url-password (line 1885)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.url_record.password());
}

/// host getter
/// Spec: https://url.spec.whatwg.org/#dom-url-host (lines 1893-1901)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;

    // Step 2: If url's host is null, return empty string
    const h = internal.url_record.host orelse return try allocator.dupe(u8, "");

    // Step 3: If url's port is null, return serialized host
    const p = internal.url_record.port orelse {
        return host_serializer.serializeHost(allocator, h);
    };

    // Step 4: Return host:port
    const host_str = try host_serializer.serializeHost(allocator, h);
    defer allocator.free(host_str);

    const port_str = try std.fmt.allocPrint(allocator, "{d}", .{p});
    defer allocator.free(port_str);

    return std.fmt.allocPrint(allocator, "{s}:{s}", .{ host_str, port_str });
}

/// hostname getter
/// Spec: https://url.spec.whatwg.org/#dom-url-hostname (lines 1911-1915)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;

    // Step 1: If url's host is null, return empty string
    const h = internal.url_record.host orelse return try allocator.dupe(u8, "");

    // Step 2: Return serialized host
    return host_serializer.serializeHost(allocator, h);
}

/// port getter
/// Spec: https://url.spec.whatwg.org/#dom-url-port (lines 1923-1927)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;

    // Step 1: If port is null, return empty string
    const p = internal.url_record.port orelse return try allocator.dupe(u8, "");

    // Step 2: Return port serialized
    return std.fmt.allocPrint(allocator, "{d}", .{p});
}

/// pathname getter
/// Spec: https://url.spec.whatwg.org/#dom-url-pathname (line 1937)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return path_serializer.serializePath(instance.ctx.allocator, &internal.url_record);
}

/// search getter
/// Spec: https://url.spec.whatwg.org/#dom-url-search (lines 1947-1951)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;
    const q = internal.url_record.query();

    // Step 1: If query is null or empty, return empty string
    if (q == null or q.?.len == 0) {
        return try allocator.dupe(u8, "");
    }

    // Step 2: Return "?" + query
    return std.fmt.allocPrint(allocator, "?{s}", .{q.?});
}

/// searchParams getter
/// Spec: https://url.spec.whatwg.org/#dom-url-searchparams (line 1967)
pub fn get_searchParams(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Return the URLSearchParams instance (cached)
    // The generated interface will handle caching via [SameObject] attribute
    if (internal.query_params_instance) |params_instance| {
        return params_instance;
    }

    return error.InvalidState;
}

/// hash getter
/// Spec: https://url.spec.whatwg.org/#dom-url-hash (lines 1969-1973)
/// Uses instance.ctx.allocator so interface layer can clean up.
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;
    const f = internal.url_record.fragment();

    // Step 1: If fragment is null or empty, return empty string
    if (f == null or f.?.len == 0) {
        return try allocator.dupe(u8, "");
    }

    // Step 2: Return "#" + fragment
    return std.fmt.allocPrint(allocator, "#{s}", .{f.?});
}

// ========================================================================
// Setters
// ========================================================================

/// href setter
/// Spec: https://url.spec.whatwg.org/#dom-url-href (lines 1855-1870)
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Parse the new URL
    const parsed = api_parser.parseURL(internal.allocator, value, null) catch {
        return error.TypeError;
    };

    // Replace current URL record
    internal.url_record.deinit();
    internal.url_record = parsed;

    // Update query object with new URL's query
    const query_str = parsed.query() orelse "";
    try updateQueryObjectList(internal, query_str);
}

/// protocol setter
/// Spec: https://url.spec.whatwg.org/#dom-url-protocol (line 1875)
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Append ":" to value per spec
    const input = try std.fmt.allocPrint(internal.allocator, "{s}:", .{value});
    defer internal.allocator.free(input);

    // Parse with scheme start state override
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        input,
        null,
        ParserState.scheme_start,
        &internal.url_record,
    ) catch {
        // Parsing failure is silently ignored per spec behavior
        return;
    };
}

/// username setter
/// Spec: https://url.spec.whatwg.org/#dom-url-username (lines 1879-1883)
pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If cannot have username/password/port, return
    if (internal.url_record.cannotHaveUsernamePasswordPort()) return;

    // Percent-encode the new username
    const encoded_username = try percent_encoding.utf8PercentEncode(
        internal.allocator,
        value,
        EncodeSet.userinfo,
    );
    defer internal.allocator.free(encoded_username);

    // Rebuild URL with new username using string manipulation
    const old_href = try url_serializer.serialize(internal.allocator, &internal.url_record, false);
    defer internal.allocator.free(old_href);

    // Parse URL structure: scheme://[username[:password]@]host...
    const scheme_end = std.mem.indexOf(u8, old_href, "://") orelse return;
    const after_scheme = scheme_end + 3;

    // Find where authority ends
    var authority_end = old_href.len;
    for (old_href[after_scheme..], 0..) |c, i| {
        if (c == '/' or c == '?' or c == '#') {
            authority_end = after_scheme + i;
            break;
        }
    }

    const at_pos = std.mem.indexOf(u8, old_href[after_scheme..authority_end], "@");

    const new_href = if (at_pos) |at_offset| blk: {
        const at_abs = after_scheme + at_offset;
        const colon_in_creds = std.mem.indexOf(u8, old_href[after_scheme..at_abs], ":");

        if (colon_in_creds) |colon_offset| {
            const colon_abs = after_scheme + colon_offset;
            break :blk try std.fmt.allocPrint(internal.allocator, "{s}{s}{s}", .{
                old_href[0..after_scheme],
                encoded_username,
                old_href[colon_abs..],
            });
        } else {
            break :blk try std.fmt.allocPrint(internal.allocator, "{s}{s}{s}", .{
                old_href[0..after_scheme],
                encoded_username,
                old_href[at_abs..],
            });
        }
    } else blk: {
        break :blk try std.fmt.allocPrint(internal.allocator, "{s}{s}@{s}", .{
            old_href[0..after_scheme],
            encoded_username,
            old_href[after_scheme..],
        });
    };
    defer internal.allocator.free(new_href);

    // Re-parse the modified URL
    const parsed_url = api_parser.parseURL(internal.allocator, new_href, null) catch return;

    // Replace internal URLRecord
    internal.url_record.deinit();
    internal.url_record = parsed_url;
}

/// password setter
/// Spec: https://url.spec.whatwg.org/#dom-url-password (lines 1887-1891)
pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If cannot have username/password/port, return
    if (internal.url_record.cannotHaveUsernamePasswordPort()) return;

    // Percent-encode the new password
    const encoded_password = try percent_encoding.utf8PercentEncode(
        internal.allocator,
        value,
        EncodeSet.userinfo,
    );
    defer internal.allocator.free(encoded_password);

    // Rebuild URL with new password
    const old_href = try url_serializer.serialize(internal.allocator, &internal.url_record, false);
    defer internal.allocator.free(old_href);

    const scheme_end = std.mem.indexOf(u8, old_href, "://") orelse return;
    const after_scheme = scheme_end + 3;

    var authority_end = old_href.len;
    for (old_href[after_scheme..], 0..) |c, i| {
        if (c == '/' or c == '?' or c == '#') {
            authority_end = after_scheme + i;
            break;
        }
    }

    const at_pos = std.mem.indexOf(u8, old_href[after_scheme..authority_end], "@");

    const new_href = if (at_pos) |at_offset| blk: {
        const at_abs = after_scheme + at_offset;
        const username_part = internal.url_record.username();

        break :blk try std.fmt.allocPrint(internal.allocator, "{s}{s}:{s}{s}", .{
            old_href[0..after_scheme],
            username_part,
            encoded_password,
            old_href[at_abs..],
        });
    } else blk: {
        break :blk try std.fmt.allocPrint(internal.allocator, "{s}:{s}@{s}", .{
            old_href[0..after_scheme],
            encoded_password,
            old_href[after_scheme..],
        });
    };
    defer internal.allocator.free(new_href);

    // Re-parse the modified URL
    const parsed_url = api_parser.parseURL(internal.allocator, new_href, null) catch return;

    // Replace internal URLRecord
    internal.url_record.deinit();
    internal.url_record = parsed_url;
}

/// host setter
/// Spec: https://url.spec.whatwg.org/#dom-url-host (lines 1903-1907)
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If has opaque path, return
    if (internal.url_record.hasOpaquePath()) return;

    // Step 2: Basic URL parse with host state override
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        value,
        null,
        ParserState.host,
        &internal.url_record,
    ) catch {
        return;
    };
}

/// hostname setter
/// Spec: https://url.spec.whatwg.org/#dom-url-hostname (lines 1917-1921)
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If has opaque path, return
    if (internal.url_record.hasOpaquePath()) return;

    // Step 2: Basic URL parse with hostname state override
    // NOTE: Uses .hostname which rejects port (unlike .host which accepts port)
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        value,
        null,
        ParserState.hostname,
        &internal.url_record,
    ) catch {
        return;
    };
}

/// port setter
/// Spec: https://url.spec.whatwg.org/#dom-url-port (lines 1929-1935)
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If cannot have username/password/port, return
    if (internal.url_record.cannotHaveUsernamePasswordPort()) return;

    // Step 2: If empty string, set port to null
    if (value.len == 0) {
        internal.url_record.port = null;
        return;
    }

    // Step 3: Parse with port state override
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        value,
        null,
        ParserState.port,
        &internal.url_record,
    ) catch {
        return;
    };
}

/// pathname setter
/// Spec: https://url.spec.whatwg.org/#dom-url-pathname (lines 1939-1945)
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If has opaque path, return
    if (internal.url_record.hasOpaquePath()) return;

    // Step 2: Empty this's URL's path
    switch (internal.url_record.path) {
        .segments => |*segments| {
            // Free each existing segment
            for (segments.toSlice()) |segment| {
                internal.allocator.free(segment);
            }
            segments.clear();
        },
        .opaque_path => {}, // Opaque paths handled by step 1 check above
    }

    // Step 3: Parse with path start state override
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        value,
        null,
        ParserState.path_start,
        &internal.url_record,
    ) catch {
        return;
    };
}

/// search setter
/// Spec: https://url.spec.whatwg.org/#dom-url-search (lines 1953-1965)
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 2: If empty, set query to null
    if (value.len == 0) {
        internal.url_record.query_len = 0;
        // Step 2.2: Empty this's query object's list
        try updateQueryObjectList(internal, "");
        return;
    }

    // Step 3: Remove leading "?" if any
    const input = if (std.mem.startsWith(u8, value, "?"))
        value[1..]
    else
        value;

    // Step 4-5: Parse with query state override
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        input,
        null,
        ParserState.query,
        &internal.url_record,
    ) catch {
        return;
    };

    // Step 6: Set this's query object's list to the result of parsing input
    try updateQueryObjectList(internal, input);
}

/// Helper to update the query object's list when URL.search is set
/// Spec: https://url.spec.whatwg.org/#dom-url-search steps 2.2 and 6
fn updateQueryObjectList(internal: *InternalState, query: []const u8) !void {
    const params_instance = internal.query_params_instance orelse return;
    const params_state = params_instance.getState(URLSearchParams.State);
    const params_internal: *URLSearchParamsInternalState = @ptrCast(@alignCast(params_state.own._internal orelse return));

    // Clear existing list entries (free memory)
    for (0..params_internal.list.len) |i| {
        if (params_internal.list.get(i)) |tuple| {
            params_internal.allocator.free(tuple.name);
            params_internal.allocator.free(tuple.value);
        }
    }
    params_internal.list.clear();

    // If query is empty, we're done
    if (query.len == 0) return;

    // Parse the new query string and add entries
    const tuples = try form_parser.parse(params_internal.allocator, query);
    defer params_internal.allocator.free(tuples);

    for (tuples) |tuple| {
        try params_internal.list.append(tuple);
    }
}

/// hash setter
/// Spec: https://url.spec.whatwg.org/#dom-url-hash (lines 1975-1983)
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If empty, set fragment to null
    if (value.len == 0) {
        internal.url_record.fragment_len = 0;
        return;
    }

    // Step 2: Remove leading "#" if any
    const input = if (std.mem.startsWith(u8, value, "#"))
        value[1..]
    else
        value;

    // Step 3-4: Parse with fragment state override
    _ = basic_parser.parseWithStateOverride(
        internal.allocator,
        input,
        null,
        ParserState.fragment,
        &internal.url_record,
    ) catch {
        return;
    };
}

// ========================================================================
// Static Methods
// ========================================================================

/// parse static method
/// Spec: https://url.spec.whatwg.org/#dom-url-parse (lines 1835-1845)
/// Returns a URL instance on success, null on failure (does not throw)
pub fn call_static_parse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!?*runtime.Instance {
    const ctx = instance.ctx;
    const allocator = ctx.allocator;

    // Step 1: Parse base URL if provided
    var base_record: ?URLRecord = null;
    const base_slice = if (base.was_passed) base.value else "";
    if (base_slice.len > 0) {
        base_record = api_parser.parseURL(allocator, base_slice, null) catch {
            // Base URL parse failed - return null
            return null;
        };
    }
    defer if (base_record) |*br| br.deinit();

    // Step 2: Parse URL with optional base
    var parsed_url = api_parser.parseURL(
        allocator,
        url,
        if (base_record) |*br| br else null,
    ) catch {
        // URL parse failed - return null (not throw)
        return null;
    };
    // errdefer for parsed_url only until ownership is transferred
    var url_owned = true;
    errdefer if (url_owned) parsed_url.deinit();

    // Step 3: Create URL instance
    const new_instance = try init(allocator, State, &URL.vtable, ctx);
    errdefer deinit(new_instance);

    const state = new_instance.getState(State);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer if (url_owned) allocator.destroy(internal);

    internal.* = InternalState{
        .url_record = parsed_url,
        .query_params_instance = null,
        .allocator = allocator,
    };

    // Transfer ownership to instance
    state.own._internal = internal;
    url_owned = false;

    // Initialize URLSearchParams instance with query from URLRecord
    const query_str = parsed_url.query() orelse "";
    const URLSearchParamsInterface = interfaces.URLSearchParams;

    // Create URLSearchParams instance
    const query_params_instance = try URLSearchParamsInterface.call_constructor(
        ctx,
        webidl.Opt(runtime.JSValue).notPassed(),
    );
    errdefer URLSearchParamsInterface.deinit(query_params_instance);

    // Get URLSearchParams internal state and initialize it with query string
    const URLSearchParamsState = interfaces.URLSearchParams.State;
    const params_state = query_params_instance.getState(URLSearchParamsState);
    if (params_state.own._internal) |params_internal| {
        // Parse query string into list
        if (query_str.len > 0) {
            const tuples = try form_parser.parse(allocator, query_str);
            for (tuples) |tuple| {
                try params_internal.list.append(tuple);
            }
            allocator.free(tuples);
        }

        // Set back-reference to URL
        params_internal.url_object = new_instance;
    }

    // Store URLSearchParams instance in URL's internal state
    internal.query_params_instance = query_params_instance;

    return new_instance;
}

/// canParse static method
/// Spec: https://url.spec.whatwg.org/#dom-url-canparse (lines 1847-1853)
pub fn call_static_canParse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!bool {
    // Static method - instance is not used
    _ = instance;

    const allocator = std.heap.page_allocator; // TODO: Get from context

    // Parse base URL if provided
    var base_record: ?URLRecord = null;
    const base_slice = if (base.was_passed) base.value else "";
    if (base_slice.len > 0) {
        base_record = api_parser.parseURL(allocator, base_slice, null) catch return false;
    }
    defer if (base_record) |*br| br.deinit();

    // Try to parse URL
    var parsed = api_parser.parseURL(
        allocator,
        url,
        if (base_record) |*br| br else null,
    ) catch return false;

    parsed.deinit();
    return true;
}

/// toJSON method
/// Spec: https://url.spec.whatwg.org/#dom-url-tojson (line 1855)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.USVString {
    return get_href(instance);
}

/// createObjectURL static method (Blob URLs)
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-createObjectURL
///
/// Creates a blob URL for the given Blob object.
/// The URL can be used to reference the Blob in contexts like img.src, a.href, etc.
pub fn call_static_createObjectURL(instance: *runtime.Instance, obj: runtime.JSValue) anyerror!runtime.DOMString {
    const allocator = instance.ctx.allocator;

    // Get the global blob URL store
    const store = file_mod.getGlobalBlobURLStore() orelse {
        // If no store exists, create one and set it as global
        const new_store = try allocator.create(BlobURLStore);
        new_store.* = BlobURLStore.init(allocator);
        file_mod.setGlobalBlobURLStore(new_store);
        return call_static_createObjectURL(instance, obj);
    };

    // Extract the Blob's internal data from the JSValue
    // The JSValue contains a V8 object wrapping a runtime.Instance
    const v8_value = obj.asEngineHandle();
    const value: *v8.Value = @ptrCast(v8_value);

    if (!v8.v8_Value_IsObject(value)) {
        return error.TypeError;
    }

    const v8_obj: *v8.Object = @ptrCast(value);
    const field_count = v8.v8_Object_InternalFieldCount(v8_obj);
    if (field_count < 1) {
        return error.TypeError;
    }

    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(v8_obj, 0) orelse {
        return error.TypeError;
    };

    // The internal field should point to a runtime.Instance
    const blob_instance: *runtime.Instance = @ptrCast(@alignCast(ptr));

    // Get the Blob's internal state
    const blob_internal = BlobImpl.getInternal(blob_instance) orelse {
        return error.TypeError;
    };

    // Get origin from context (use "null" origin for file:// or opaque origins)
    // Per spec, the origin is the serialization of the entry settings object's origin
    const origin = file_mod.getDocumentOrigin() orelse "null";

    // Create the blob URL
    const blob_url = try store.createObjectURL(blob_internal.blob_data, origin);

    // Return as DOMString (take ownership of the allocated URL string)
    return runtime.DOMString.initOwned(blob_url);
}

/// revokeObjectURL static method (Blob URLs)
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-revokeObjectURL
///
/// Revokes a previously created blob URL, making it no longer usable.
pub fn call_static_revokeObjectURL(instance: *runtime.Instance, url: runtime.DOMString) anyerror!void {
    _ = instance;

    // Get the global blob URL store
    const store = file_mod.getGlobalBlobURLStore() orelse {
        // No store means no URLs to revoke
        return;
    };

    // Revoke the URL
    store.revokeObjectURL(url.asSlice());
}

/// createObjectURL instance method (delegates to static)
pub fn call_createObjectURL(instance: *runtime.Instance, obj: runtime.JSValue) anyerror!runtime.DOMString {
    return call_static_createObjectURL(instance, obj);
}

/// canParse static method
/// Spec: https://url.spec.whatwg.org/#dom-url-canparse
pub fn call_canParse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!bool {
    _ = instance;

    // Try to parse the URL with the given base
    const base_slice = if (base.was_passed) base.value else "";
    var base_record: ?URLRecord = null;

    if (base_slice.len > 0) {
        base_record = api_parser.parseURL(std.heap.c_allocator, base_slice, null) catch {
            return false;
        };
    }
    defer if (base_record) |*br| br.deinit();

    // Try to parse the URL
    var url_record = api_parser.parseURL(std.heap.c_allocator, url, base_record) catch {
        return false;
    };
    url_record.deinit();

    return true;
}

/// revokeObjectURL instance method (delegates to static)
pub fn call_revokeObjectURL(instance: *runtime.Instance, url: runtime.DOMString) anyerror!void {
    return call_static_revokeObjectURL(instance, url);
}

pub fn call_parse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!?*runtime.Instance {
    _ = instance;
    _ = url;
    _ = base;
    return null;
}
