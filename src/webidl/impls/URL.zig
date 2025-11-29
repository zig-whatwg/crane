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

pub const State = URL.State;

/// Internal state for URL implementation
/// This stores the parsed URL structure (like Chrome's KURL)
pub const InternalState = struct {
    url_record: URLRecord,
    query_params_instance: ?*runtime.Instance,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.url_record.deinit();
        // URLSearchParams instance is managed separately
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
        internal.deinit(state.own._internal.?.allocator);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// Spec: https://url.spec.whatwg.org/#dom-url-url (lines 1794-1800)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &URL.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Step 1: Parse base URL if provided
    var base_record: ?URLRecord = null;
    const base_slice = if (base.was_passed) base.value else "";
    if (base_slice.len > 0) {
        base_record = api_parser.parseURL(allocator, base_slice, null) catch {
            return error.TypeError; // Base URL parse failed
        };
    }
    defer if (base_record) |*br| br.deinit();

    // Step 1: Parse URL with optional base
    var parsed_url = api_parser.parseURL(
        allocator,
        url,
        if (base_record) |*br| br else null,
    ) catch {
        // Step 2: If parsedURL is failure, throw TypeError
        return error.TypeError;
    };
    errdefer parsed_url.deinit();

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .url_record = parsed_url,
        .query_params_instance = null,
        .allocator = allocator,
    };

    state.own._internal = internal;

    // Initialize URLSearchParams instance with query from URLRecord
    const query_str = parsed_url.query() orelse "";
    const URLSearchParamsInterface = interfaces.URLSearchParams;

    // Create URLSearchParams instance - pass empty init_data for now
    const query_params_instance = try URLSearchParamsInterface.call_constructor(
        allocator,
        ctx,
        webidl.Opt(*const anyopaque).notPassed(),
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
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return url_serializer.serialize(internal.allocator, &internal.url_record, false);
}

/// origin getter
/// Spec: https://url.spec.whatwg.org/#dom-url-origin (line 1871)
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const url_origin = try origin_module.getOrigin(internal.allocator, &internal.url_record);
    defer url_origin.deinit(internal.allocator);
    return url_origin.serialize(internal.allocator);
}

/// protocol getter
/// Spec: https://url.spec.whatwg.org/#dom-url-protocol (line 1873)
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const scheme = internal.url_record.scheme();
    const result = try internal.allocator.alloc(u8, scheme.len + 1);
    @memcpy(result[0..scheme.len], scheme);
    result[scheme.len] = ':';
    return result;
}

/// username getter
/// Spec: https://url.spec.whatwg.org/#dom-url-username (line 1877)
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try internal.allocator.dupe(u8, internal.url_record.username());
}

/// password getter
/// Spec: https://url.spec.whatwg.org/#dom-url-password (line 1885)
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try internal.allocator.dupe(u8, internal.url_record.password());
}

/// host getter
/// Spec: https://url.spec.whatwg.org/#dom-url-host (lines 1893-1901)
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 2: If url's host is null, return empty string
    const h = internal.url_record.host orelse return try internal.allocator.dupe(u8, "");

    // Step 3: If url's port is null, return serialized host
    const p = internal.url_record.port orelse {
        return host_serializer.serializeHost(internal.allocator, h);
    };

    // Step 4: Return host:port
    const host_str = try host_serializer.serializeHost(internal.allocator, h);
    defer internal.allocator.free(host_str);

    const port_str = try std.fmt.allocPrint(internal.allocator, "{d}", .{p});
    defer internal.allocator.free(port_str);

    return std.fmt.allocPrint(internal.allocator, "{s}:{s}", .{ host_str, port_str });
}

/// hostname getter
/// Spec: https://url.spec.whatwg.org/#dom-url-hostname (lines 1911-1915)
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If url's host is null, return empty string
    const h = internal.url_record.host orelse return try internal.allocator.dupe(u8, "");

    // Step 2: Return serialized host
    return host_serializer.serializeHost(internal.allocator, h);
}

/// port getter
/// Spec: https://url.spec.whatwg.org/#dom-url-port (lines 1923-1927)
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If port is null, return empty string
    const p = internal.url_record.port orelse return try internal.allocator.dupe(u8, "");

    // Step 2: Return port serialized
    return std.fmt.allocPrint(internal.allocator, "{d}", .{p});
}

/// pathname getter
/// Spec: https://url.spec.whatwg.org/#dom-url-pathname (line 1937)
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return path_serializer.serializePath(internal.allocator, &internal.url_record);
}

/// search getter
/// Spec: https://url.spec.whatwg.org/#dom-url-search (lines 1947-1951)
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const q = internal.url_record.query();

    // Step 1: If query is null or empty, return empty string
    if (q == null or q.?.len == 0) {
        return try internal.allocator.dupe(u8, "");
    }

    // Step 2: Return "?" + query
    return std.fmt.allocPrint(internal.allocator, "?{s}", .{q.?});
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
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const f = internal.url_record.fragment();

    // Step 1: If fragment is null or empty, return empty string
    if (f == null or f.?.len == 0) {
        return try internal.allocator.dupe(u8, "");
    }

    // Step 2: Return "#" + fragment
    return std.fmt.allocPrint(internal.allocator, "#{s}", .{f.?});
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

    // TODO: Update query object
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
        // TODO: Empty query object list
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

    // TODO: Update query object's list
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
pub fn call_parse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!?*runtime.Instance {
    // Static method - instance is not used
    _ = instance;
    _ = url;
    _ = base;
    return error.NotImplemented;
}

/// canParse static method
/// Spec: https://url.spec.whatwg.org/#dom-url-canparse (lines 1847-1853)
pub fn call_canParse(instance: *runtime.Instance, url: runtime.USVString, base: webidl.Opt(runtime.USVString)) anyerror!bool {
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
pub fn call_createObjectURL(instance: *runtime.Instance, obj: *const anyopaque) anyerror!runtime.DOMString {
    _ = instance;
    _ = obj;
    return error.NotImplemented;
}

/// revokeObjectURL static method (Blob URLs)
pub fn call_revokeObjectURL(instance: *runtime.Instance, url: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = url;
    return error.NotImplemented;
}
