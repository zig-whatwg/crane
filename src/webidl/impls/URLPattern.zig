//! Implementation for URLPattern interface
//!
//! WHATWG URLPattern Standard implementation
//! Spec: https://urlpattern.spec.whatwg.org/

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const URLPatternInterface = interfaces.URLPattern;

// Import URLPattern infrastructure from src/urlpattern/
const urlpattern = @import("urlpattern");
const URLPatternCore = urlpattern.URLPattern;
const URLPatternOptions = urlpattern.URLPatternOptions;
const URLPatternInit = urlpattern.URLPatternInit;
const URLPatternResult = urlpattern.URLPatternResult;
const URLPatternComponentResult = urlpattern.URLPatternComponentResult;

pub const State = URLPatternInterface.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    InvalidState,
};

/// Internal state for URLPattern implementation
/// This stores the compiled URL pattern (like Chrome's URLPattern)
pub const InternalState = struct {
    pattern: URLPatternCore,
    allocator: std.mem.Allocator,
    /// The strings of the last exec() result. The binding converts a returned
    /// dictionary AFTER the operation returns - and after it has released the
    /// call's converted arguments - so the result may borrow neither the
    /// arguments nor anything freed on the way out. It lives here until the
    /// next exec() on this pattern resets it, or the pattern goes.
    result_arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *InternalState) void {
        self.result_arena.deinit();
        self.pattern.deinit(self.allocator);
        self.allocator.destroy(self);
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
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-urlpattern
pub fn call_constructor(ctx: runtime.Context, args: interfaces.URLPattern.ConstructorArgs) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &URLPatternInterface.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Extract input and options based on constructor overload
    var input_init: URLPatternInit = .{};
    var base_url: ?[]const u8 = null;
    var ignore_case: bool = false;

    switch (args) {
        .URLPatternInput_USVString_URLPatternOptions => |variant| {
            // constructor(input, baseURL, options)
            base_url = variant.baseURL;
            if (variant.options.was_passed) {
                if (variant.options.value.ignoreCase) |ic| {
                    ignore_case = ic;
                }
            }
            // Convert WebIDL URLPatternInput to internal URLPatternInit
            switch (variant.input) {
                .usvstring => |s| {
                    // Parse URL string pattern - treat as full URL pattern string
                    // The constructor_string_parser will handle this
                    input_init = urlpattern.parseConstructorString(ctx.allocator, s) catch {
                        return error.TypeError;
                    };
                },
                .urlpattern_init => |webidl_init| {
                    input_init = convertURLPatternInit(webidl_init, base_url);
                },
            }
        },
        .URLPatternInput_URLPatternOptions => |variant| {
            // constructor(input, options)
            if (variant.options.was_passed) {
                if (variant.options.value.ignoreCase) |ic| {
                    ignore_case = ic;
                }
            }
            if (variant.input.was_passed) {
                switch (variant.input.value) {
                    .usvstring => |s| {
                        input_init = urlpattern.parseConstructorString(ctx.allocator, s) catch {
                            return error.TypeError;
                        };
                    },
                    .urlpattern_init => |webidl_init| {
                        input_init = convertURLPatternInit(webidl_init, null);
                    },
                }
            }
            // If input was not passed, use empty init (default wildcards)
        },
    }

    // Create the core URLPattern
    var pattern = URLPatternCore.create(ctx.allocator, .{ .init = input_init }, .{
        .ignore_case = ignore_case,
    }) catch {
        return error.TypeError;
    };
    errdefer pattern.deinit(ctx.allocator);

    // Create InternalState
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    internal.* = InternalState{
        .pattern = pattern,
        .allocator = ctx.allocator,
        .result_arena = std.heap.ArenaAllocator.init(ctx.allocator),
    };

    state.own._internal = internal;

    return instance;
}

/// Convert WebIDL URLPatternInit to internal URLPatternInit
fn convertURLPatternInit(webidl_init: dictionaries.URLPatternInit, base_url: ?[]const u8) URLPatternInit {
    return URLPatternInit{
        .protocol = webidl_init.protocol,
        .username = webidl_init.username,
        .password = webidl_init.password,
        .hostname = webidl_init.hostname,
        .port = webidl_init.port,
        .pathname = webidl_init.pathname,
        .search = webidl_init.search,
        .hash = webidl_init.hash,
        .base_url = webidl_init.baseURL orelse base_url,
    };
}

/// Getter for protocol
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-protocol
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.protocol.pattern_string);
}

/// Getter for username
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-username
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.username.pattern_string);
}

/// Getter for password
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-password
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.password.pattern_string);
}

/// Getter for hostname
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-hostname
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.hostname.pattern_string);
}

/// Getter for port
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-port
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.port.pattern_string);
}

/// Getter for pathname
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-pathname
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.pathname.pattern_string);
}

/// Getter for search
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-search
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.search.pattern_string);
}

/// Getter for hash
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-hash
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try instance.ctx.allocator.dupe(u8, internal.pattern.hash.pattern_string);
}

/// Getter for hasRegExpGroups
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-hasregexpgroups
pub fn get_hasRegExpGroups(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.pattern.hasRegexpGroups();
}

/// Operation: test
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-test
pub fn call_test(instance: *runtime.Instance, input: webidl.Opt(typedefs.URLPatternInput), baseURL: webidl.Opt(runtime.USVString)) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;

    // Convert WebIDL input to internal input format
    const base_url_str: ?[]const u8 = if (baseURL.was_passed) baseURL.value else null;

    if (!input.was_passed) {
        // No input - use empty string
        return urlpattern.testMatch(allocator, &internal.pattern, "", base_url_str);
    }

    switch (input.value) {
        .usvstring => |s| {
            return urlpattern.testMatch(allocator, &internal.pattern, s, base_url_str);
        },
        .urlpattern_init => |webidl_init| {
            // Convert to internal URLPatternInput format
            const internal_input = urlpattern.URLPatternInput{
                .init = .{
                    .protocol = webidl_init.protocol,
                    .username = webidl_init.username,
                    .password = webidl_init.password,
                    .hostname = webidl_init.hostname,
                    .port = webidl_init.port,
                    .pathname = webidl_init.pathname,
                    .search = webidl_init.search,
                    .hash = webidl_init.hash,
                    .baseURL = webidl_init.baseURL,
                },
            };
            return urlpattern.testMatchInput(allocator, &internal.pattern, internal_input, base_url_str);
        },
    }
}

/// Operation: exec
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-exec
pub fn call_exec(instance: *runtime.Instance, input: webidl.Opt(typedefs.URLPatternInput), baseURL: webidl.Opt(runtime.USVString)) anyerror!?dictionaries.URLPatternResult {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = instance.ctx.allocator;

    // Convert WebIDL input to internal input format
    const base_url_str: ?[]const u8 = if (baseURL.was_passed) baseURL.value else null;

    var core_result: ?urlpattern.URLPatternResult = null;

    if (!input.was_passed) {
        // No input - use empty string
        core_result = urlpattern.exec(allocator, &internal.pattern, "", base_url_str) catch return null;
    } else {
        switch (input.value) {
            .usvstring => |s| {
                core_result = urlpattern.exec(allocator, &internal.pattern, s, base_url_str) catch return null;
            },
            .urlpattern_init => |webidl_init| {
                // Convert to internal URLPatternInput format
                const internal_input = urlpattern.URLPatternInput{
                    .init = .{
                        .protocol = webidl_init.protocol,
                        .username = webidl_init.username,
                        .password = webidl_init.password,
                        .hostname = webidl_init.hostname,
                        .port = webidl_init.port,
                        .pathname = webidl_init.pathname,
                        .search = webidl_init.search,
                        .hash = webidl_init.hash,
                        .baseURL = webidl_init.baseURL,
                    },
                };
                core_result = urlpattern.execInput(allocator, &internal.pattern, internal_input, base_url_str) catch return null;
            },
        }
    }

    // If no match, return null
    if (core_result == null) {
        return null;
    }

    var result = core_result.?;
    defer result.deinit();

    // Everything the returned dictionary points at is copied into this
    // pattern's result arena (see InternalState.result_arena): the previous
    // result's strings, converted long ago, go now.
    _ = internal.result_arena.reset(.retain_capacity);
    const scratch = internal.result_arena.allocator();

    // Steps 9-11: "Let inputs be an empty list", then append input - a copy:
    // the argument is released before this result is converted.
    var inputs: std.ArrayListUnmanaged(typedefs.URLPatternInput) = .empty;
    if (!input.was_passed) {
        try inputs.append(scratch, .{ .usvstring = "" });
    } else switch (input.value) {
        .usvstring => |s| {
            try inputs.append(scratch, .{ .usvstring = try scratch.dupe(u8, s) });
            // Step 13.2.2.3: a string input's baseURLString, when given (it
            // parsed: the pattern matched), is appended to inputs too.
            if (base_url_str) |b| try inputs.append(scratch, .{ .usvstring = try scratch.dupe(u8, b) });
        },
        .urlpattern_init => |webidl_init| {
            try inputs.append(scratch, .{ .urlpattern_init = try copyInit(scratch, webidl_init) });
        },
    }

    // Convert internal URLPatternResult to WebIDL URLPatternResult dictionary,
    // copying its strings: result.deinit() frees them on the way out.
    const webidl_result = dictionaries.URLPatternResult{
        .inputs = inputs.items,
        .protocol = try convertComponentResult(scratch, result.protocol),
        .username = try convertComponentResult(scratch, result.username),
        .password = try convertComponentResult(scratch, result.password),
        .hostname = try convertComponentResult(scratch, result.hostname),
        .port = try convertComponentResult(scratch, result.port),
        .pathname = try convertComponentResult(scratch, result.pathname),
        .search = try convertComponentResult(scratch, result.search),
        .hash = try convertComponentResult(scratch, result.hash),
    };

    return webidl_result;
}

/// A URLPatternInit whose strings are copies in `scratch`.
fn copyInit(scratch: std.mem.Allocator, given: dictionaries.URLPatternInit) !dictionaries.URLPatternInit {
    var copy = given;
    inline for (std.meta.fields(dictionaries.URLPatternInit)) |field| {
        if (@field(given, field.name)) |value| {
            @field(copy, field.name) = try scratch.dupe(u8, value);
        }
    }
    return copy;
}

// Type alias for the groups entry to match the dictionary definition
// groups is: ?[]const struct { key: runtime.USVString, value: *const anyopaque }
// So we need to extract the inner struct type
const GroupsSliceType = @typeInfo(std.meta.fieldInfo(dictionaries.URLPatternComponentResult, .groups).type).optional.child;
const GroupsEntry = @typeInfo(GroupsSliceType).pointer.child;

/// Convert internal URLPatternComponentResult to WebIDL dictionary, its
/// strings copied into `scratch` so they outlive the core result.
fn convertComponentResult(
    scratch: std.mem.Allocator,
    component: urlpattern.URLPatternComponentResult,
) !dictionaries.URLPatternComponentResult {
    const input_copy = try scratch.dupe(u8, component.input);

    // Convert groups StringHashMap to WebIDL record format
    // Note: groups should ALWAYS be an object (empty {} if no named groups), never null
    const groups_array = try scratch.alloc(GroupsEntry, component.groups.count());

    var idx: usize = 0;
    var iter = component.groups.iterator();
    while (iter.next()) |entry| {
        groups_array[idx] = .{
            .key = try scratch.dupe(u8, entry.key_ptr.*),
            .value = runtime.JSValue.fromStringRef(try scratch.dupe(u8, entry.value_ptr.*)),
        };
        idx += 1;
    }

    return dictionaries.URLPatternComponentResult{
        .input = input_copy,
        .groups = groups_array,
    };
}
