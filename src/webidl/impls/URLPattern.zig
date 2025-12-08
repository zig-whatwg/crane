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

    pub fn deinit(self: *InternalState) void {
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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: URLPatternInterface.ConstructorArgs) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &URLPatternInterface.vtable, ctx);
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
                    input_init = urlpattern.parseConstructorString(allocator, s) catch {
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
                        input_init = urlpattern.parseConstructorString(allocator, s) catch {
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
    var pattern = URLPatternCore.create(allocator, .{ .init = input_init }, .{
        .ignore_case = ignore_case,
    }) catch {
        return error.TypeError;
    };
    errdefer pattern.deinit(allocator);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .pattern = pattern,
        .allocator = allocator,
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

    // Build inputs array from the original input
    // Spec: inputs is a sequence of URLPatternInput containing the original input(s)
    var inputs_array = try allocator.alloc(typedefs.URLPatternInput, 1);
    errdefer allocator.free(inputs_array);

    // Convert the input to URLPatternInput format
    if (!input.was_passed) {
        // No input was passed - use empty string
        inputs_array[0] = .{ .usvstring = "" };
    } else {
        switch (input.value) {
            .usvstring => |s| {
                inputs_array[0] = .{ .usvstring = s };
            },
            .urlpattern_init => |webidl_init| {
                inputs_array[0] = .{ .urlpattern_init = webidl_init };
            },
        }
    }

    // Convert internal URLPatternResult to WebIDL URLPatternResult dictionary
    // IMPORTANT: We must clone the strings because result.deinit() will free them
    const webidl_result = dictionaries.URLPatternResult{
        .inputs = inputs_array,
        .protocol = try convertComponentResult(allocator, result.protocol),
        .username = try convertComponentResult(allocator, result.username),
        .password = try convertComponentResult(allocator, result.password),
        .hostname = try convertComponentResult(allocator, result.hostname),
        .port = try convertComponentResult(allocator, result.port),
        .pathname = try convertComponentResult(allocator, result.pathname),
        .search = try convertComponentResult(allocator, result.search),
        .hash = try convertComponentResult(allocator, result.hash),
    };

    return webidl_result;
}

// Type alias for the groups entry to match the dictionary definition
// groups is: ?[]const struct { key: runtime.USVString, value: *const anyopaque }
// So we need to extract the inner struct type
const GroupsSliceType = @typeInfo(std.meta.fieldInfo(dictionaries.URLPatternComponentResult, .groups).type).optional.child;
const GroupsEntry = @typeInfo(GroupsSliceType).pointer.child;

/// Convert internal URLPatternComponentResult to WebIDL dictionary
/// Clones strings to ensure they remain valid after the core result is freed
fn convertComponentResult(allocator: std.mem.Allocator, component: urlpattern.URLPatternComponentResult) !dictionaries.URLPatternComponentResult {
    // Clone the input string so it survives after result.deinit()
    const input_copy = try allocator.dupe(u8, component.input);

    // Convert groups StringHashMap to WebIDL record format
    // Note: groups should ALWAYS be an object (empty {} if no named groups), never null
    const group_count = component.groups.count();
    const groups_array = try allocator.alloc(GroupsEntry, group_count);
    errdefer allocator.free(groups_array);

    var idx: usize = 0;
    var iter = component.groups.iterator();
    while (iter.next()) |entry| {
        // Clone the key
        const key_copy = try allocator.dupe(u8, entry.key_ptr.*);
        // Clone the value and wrap it as a string pointer
        const value_copy = try allocator.dupe(u8, entry.value_ptr.*);
        // Store as slice pointer cast to anyopaque
        const value_slice_ptr = try allocator.create([]const u8);
        value_slice_ptr.* = value_copy;

        groups_array[idx] = .{
            .key = key_copy,
            .value = @ptrCast(value_slice_ptr),
        };
        idx += 1;
    }

    return dictionaries.URLPatternComponentResult{
        .input = input_copy,
        .groups = groups_array,
    };
}
