//! Implementation for Headers interface
//!
//! Wraps Fetch internal HeaderList to provide WebIDL interface.
//! Spec: https://fetch.spec.whatwg.org/#headers-class

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");

// Import Fetch internal structures
const fetch = @import("fetch");
const webidl = @import("webidl");
const HeaderList = fetch.internal.HeaderList;
const HeaderGuard = fetch.internal.HeaderGuard;
const validation = fetch.internal.validation;
const headers_class = fetch.webidl.headers;
const engine = @import("engine");

const Headers = interfaces.Headers;
const same_object = @import("same_object.zig");

pub const State = Headers.State;

/// Entry type for pair iterable support
/// Must have .name and .value fields as []const u8 for V8 iteration
pub const IterableEntry = fetch.internal.header_list.Header;

pub const ImplError = error{
    OutOfMemory,
    TypeError,
    InvalidHeader,
};

/// Internal state wraps Fetch HeaderList
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Storage for a Headers object that owns its list - `new Headers()`.
    /// Unused for a Request's or Response's headers; see `list`.
    header_list: HeaderList,
    /// The header list this object IS, per the spec: `&header_list` when
    /// `owns_headers`, otherwise the owning Request's or Response's own list.
    ///
    /// A POINTER, not a copy. `initWithHeaderList` used to take
    /// `header_list.*` - a by-value copy of the owner's ArrayList header - so
    /// the two shared one buffer through two headers. The first append past
    /// capacity reallocated it under the owner, who then freed the old buffer's
    /// entries again at deinit (a double free, 0xAA-poisoned), and an append
    /// that did not reallocate was invisible to the owner, whose length never
    /// moved: `request.headers.append(...)` never reached `fetch(request)`.
    list: *HeaderList,
    guard: HeaderGuard,
    /// Cached sorted HeaderList for iteration (per Fetch spec, Headers iterate in sorted order)
    sorted_list: ?HeaderList = null,
    /// If true, we own the header_list and should deinit it.
    /// If false, we're wrapping another object's header_list (e.g., Response/Request)
    /// and should NOT deinit it (the owner will).
    owns_headers: bool = true,
    /// For a Request's or Response's headers: the owner, kept alive by this
    /// object, because `list` points into it.
    owner: ?Owner = null,

    /// The Request or Response whose list this object is.
    ///
    /// The dependency runs from the Headers to its owner, the reverse of
    /// `xhr.upload`: the data is the OWNER's header list, so it is the owner
    /// that must outlive the Headers - `const h = (await fetch(u)).headers`
    /// holds only the Headers. So this object's wrapper keeps the owner's (an
    /// edge: same_object.Traced), and the owner holds nothing but its
    /// generated `cached_headers` pointer, which this object clears when it
    /// goes. A Headers that script drops is collected, clears the cache, and
    /// the owner hands out a new Headers over the same list next time.
    const Owner = struct {
        link: same_object.Link,
        edge: same_object.Traced,
        /// The owner's `cached_headers`, which must not outlive this object.
        cache_slot: *?*runtime.Instance,
    };
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .header_list = HeaderList.init(allocator),
        .list = undefined,
        .guard = .none,
    };
    internal.list = &internal.header_list;

    // Store in instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Initialize with existing HeaderList and guard (for Request/Response)
/// NOTE: This creates a Headers wrapper that does NOT own the header_list.
/// The owner (Response/Request) is responsible for freeing the header strings.
///
/// `owner` is the Request or Response `header_list` lives in, and
/// `cache_slot` is its generated `cached_headers` field: this object keeps
/// `owner` alive and clears `cache_slot` when it is freed - see
/// `InternalState.Owner`.
pub fn initWithHeaderList(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    header_list: *HeaderList,
    guard: HeaderGuard,
    owner: *runtime.Instance,
    cache_slot: *?*runtime.Instance,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, State, &Headers.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state that wraps existing header list
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .header_list = HeaderList.init(allocator), // unused storage
        .list = header_list, // the owner's own list, by reference
        .guard = guard,
        .owns_headers = false, // We don't own the headers - Response/Request does
        .owner = .{
            .link = same_object.Link.to(owner),
            .edge = .{ .slot = .{ .name = "owner" } },
            .cache_slot = cache_slot,
        },
    };
    if (internal.owner) |*link| link.edge.hold(instance, owner);

    // Store in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here!
/// The GC integration layer (gc_integration.onObjectFreed) handles:
/// 1. Calling this deinit function (via vtable.deinit)
/// 2. Freeing the Instance handle back to the SlabAllocator
/// Calling Instance.deinit from here would cause infinite recursion.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const allocator = internal.allocator;
        // Free cached sorted list if any (we always own this)
        if (internal.sorted_list) |*sorted| {
            sorted.deinit();
        }
        // Only free header_list if we own it
        // When created via initWithHeaderList, we don't own the headers -
        // the Response/Request does and will free them in its deinit
        if (internal.owns_headers) {
            internal.header_list.deinit();
        }
        if (internal.owner) |*owner| {
            // The owner hands out a fresh Headers over the same list next
            // time - if it is alive: the collector may take it with this
            // object, in either order, and a context's teardown frees in no
            // particular order. The generation check is for both.
            if (owner.link.isLive() and owner.cache_slot.* == instance) {
                owner.cache_slot.* = null;
            }
            owner.edge.release(instance);
        }
        allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Constructor
pub fn call_constructor(ctx: runtime.Context, init_data: webidl.Opt(typedefs.HeadersInit)) !*runtime.Instance {
    const instance = try initHeaders(ctx.allocator, State, &Headers.vtable, ctx);
    errdefer deinit(instance);

    // Handle init_data based on its variant
    if (init_data.wasPassed()) {
        const headers_init = init_data.getValue();
        // 2. Fill this with init: every sequence item a pair, then Headers'
        //    "append" - under this object's guard, "none".
        const internal = instance.getState(State).own._internal.?;
        switch (headers_init) {
            .sequence_byte_string_sequence => |outer_seq| {
                try headers_class.fillFromSequence(internal.allocator, internal.list, internal.guard, outer_seq);
            },
            .byte_string_byte_string_record => |entries| {
                for (entries) |entry| {
                    try headers_class.append(internal.allocator, internal.list, internal.guard, entry.key, entry.value);
                }
            },
        }
    }

    return instance;
}

/// Internal init function (renamed to avoid shadowing)
fn initHeaders(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return init(allocator, StateType, vtable, ctx);
}

/// append(name, value): Fetch "append" under this object's guard.
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-append
pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
    const internal = instance.getState(State).own._internal.?;
    try headers_class.append(internal.allocator, internal.list, internal.guard, name, value);
}

/// delete(name)
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-delete
pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) anyerror!void {
    const internal = instance.getState(State).own._internal.?;
    try headers_class.delete(internal.list, internal.guard, name);
}

/// get(name) -> ByteString?
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-get
pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) anyerror!?runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // 1. If name is not a header name, then throw a TypeError.
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    // 2. Return the result of getting name from this's header list.
    return internal.list.get(internal.allocator, name) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    };
}

/// getSetCookie() -> sequence<ByteString>: the values of every `Set-Cookie`
/// header, in order - not combined, and an empty list when there is none.
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-getsetcookie
pub fn call_getSetCookie(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = instance.getState(State).own._internal.?;
    const allocator = internal.allocator;

    // The return value IS the JavaScript value (AGENTS.md), so the Array is
    // made here. A ByteString is isomorphic-decoded: each byte one code
    // point.
    var decoded: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (decoded.items) |d| allocator.free(d);
        decoded.deinit(allocator);
    }
    var values: std.ArrayListUnmanaged(runtime.JSValue) = .empty;
    defer values.deinit(allocator);
    // 1. If this's header list does not contain `Set-Cookie`, then return «».
    // 2. Return the values of all headers in this's header list whose name
    //    is a byte-case-insensitive match for `Set-Cookie`, in order.
    for (internal.list.entries.items) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "set-cookie")) continue;
        const text = try isomorphicDecode(allocator, header.value);
        decoded.append(allocator, text) catch |err| {
            allocator.free(text);
            return err;
        };
        try values.append(allocator, runtime.JSValue.fromStringRef(text));
    }
    const array = try engine.createSequenceOfValues(engine.currentRealm() orelse instance.ctx, values.items);
    return array.take();
}

/// Infra "isomorphic decode", as UTF-8: each byte the code point of its
/// value. Owned.
fn isomorphicDecode(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    for (bytes) |byte| {
        if (byte < 0x80) {
            try out.append(allocator, byte);
        } else {
            try out.appendSlice(allocator, &.{ 0xC0 | (byte >> 6), 0x80 | (byte & 0x3F) });
        }
    }
    return out.toOwnedSlice(allocator);
}

/// has(name) -> boolean
pub fn call_has(instance: *runtime.Instance, name: runtime.ByteString) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    return internal.list.contains(name);
}

/// set(name, value)
///
/// Spec: https://fetch.spec.whatwg.org/#dom-headers-set
pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
    const internal = instance.getState(State).own._internal.?;
    try headers_class.set(internal.list, internal.guard, name, value);
}

/// Internal method to get all entries for pair iterable support
/// Per Fetch spec, Headers iteration returns entries sorted alphabetically by name
/// This is used by V8Interface for entries(), keys(), values() iteration
pub fn getEntriesInternal(instance: *runtime.Instance) ?[]const IterableEntry {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return null;

    // Free previous cached sorted list if any
    if (internal.sorted_list) |*old_list| {
        old_list.deinit();
        internal.sorted_list = null;
    }

    // Get sorted entries (per Fetch spec, Headers iterate in sorted order)
    const sorted_list = internal.list.sortAndCombine(internal.allocator) catch return null;

    // Cache the sorted list (it owns the strings)
    internal.sorted_list = sorted_list;

    return internal.sorted_list.?.entries.items;
}
