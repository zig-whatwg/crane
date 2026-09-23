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
    /// holds only the Headers. So this object pins the owner's wrapper, and
    /// the owner holds nothing but its generated `cached_headers` pointer,
    /// which this object clears when it goes. No strong cycle: a Headers that
    /// script drops is collected, clears the cache and unpins the owner, and
    /// the owner hands out a new Headers over the same list next time.
    const Owner = struct {
        link: same_object.Link,
        pin: same_object.Pin,
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
            .pin = .{},
            .cache_slot = cache_slot,
        },
    };
    if (internal.owner) |*link| link.pin.hold(owner);

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
            // time. It is alive - this object pinned it - unless the whole
            // context is being torn down in no particular order, which the
            // generation check is for.
            if (owner.link.isLive() and owner.cache_slot.* == instance) {
                owner.cache_slot.* = null;
            }
            owner.pin.release();
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
        switch (headers_init) {
            .sequence_byte_string_sequence => |outer_seq| {
                // Array of [name, value] pairs: sequence<sequence<ByteString>>
                for (outer_seq) |inner_seq| {
                    if (inner_seq.len >= 2) {
                        try call_append(instance, inner_seq[0], inner_seq[1]);
                    }
                }
            },
            .byte_string_byte_string_record => |entries| {
                // Object with header entries: record<ByteString, ByteString>
                for (entries) |entry| {
                    try call_append(instance, entry.key, entry.value);
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

/// append(name, value)
pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name and value
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }
    if (!validation.isValidHeaderValue(value)) {
        return error.TypeError;
    }

    // Check guard
    if (!canMutate(internal, name)) {
        return; // Silently fail per spec
    }

    // Delegate to HeaderList
    try internal.list.append(name, value);
}

/// delete(name)
pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    // Check guard
    if (!canMutate(internal, name)) {
        return; // Silently fail per spec
    }

    // Delegate to HeaderList
    internal.list.delete(name);
}

/// get(name) -> ByteString?
pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) anyerror!?runtime.ByteString {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }

    // Delegate to HeaderList
    return internal.list.get(internal.allocator, name) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    };
}

/// getSetCookie() -> sequence<ByteString>
pub fn call_getSetCookie(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Get all Set-Cookie headers
    const values = internal.list.getSetCookie(internal.allocator) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    };

    // TODO: Return proper V8 Array of strings - need V8 array creation utility
    _ = values;
    return runtime.JSValue.jsUndefined;
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
pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Validate name and value
    if (!validation.isValidHeaderName(name)) {
        return error.TypeError;
    }
    if (!validation.isValidHeaderValue(value)) {
        return error.TypeError;
    }

    // Check guard
    if (!canMutate(internal, name)) {
        return; // Silently fail per spec
    }

    // Delegate to HeaderList
    try internal.list.set(name, value);
}

/// forEach(callback)
/// Iterator support - called by V8 for Symbol.iterator
pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Iterate over headers
    for (internal.list.entries.items) |entry| {
        // Call the callback with (value, name, headers)
        // V8 runtime will handle the actual callback invocation
        _ = callback;
        _ = entry;
        // TODO: Integrate with V8 callback system
    }
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

// === Helper Functions ===

/// Check if mutation is allowed for this header name
fn canMutate(internal: *const InternalState, name: []const u8) bool {
    return switch (internal.guard) {
        .immutable => false,
        .request => !validation.isForbiddenRequestHeader(name, ""),
        .request_no_cors => !validation.isForbiddenRequestHeader(name, "") and
            validation.isNoCORSSafelistedRequestHeaderName(name),
        .response => !validation.isForbiddenResponseHeaderName(name),
        .none => true,
    };
}
