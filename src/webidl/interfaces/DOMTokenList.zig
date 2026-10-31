//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMTokenListImpl = @import("impls").DOMTokenList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const DOMTokenList = struct {
    pub const Meta = struct {
        pub const name = "DOMTokenList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "value", "get_value", "set_value" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "contains", "call_contains", 1 },
            .{ "add", "call_add", 0 },
            .{ "remove", "call_remove", 0 },
            .{ "toggle", "call_toggle", 1 },
            .{ "replace", "call_replace", 2 },
            .{ "supports", "call_supports", 1 },
            .{ "toString", "get_value", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "contains",
            "add",
            "remove",
            "toggle",
            "replace",
            "supports",
            "toString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "value", "get_value", "set_value" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
        };

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.DOMString",
            .key_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            value: runtime.DOMString = undefined,
            _internal: ?*DOMTokenListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_value = &get_value,

        .set_value = &set_value,

        .call_add = &call_add,
        .call_contains = &call_contains,
        .call_item = &call_item,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_supports = &call_supports,
        .call_toggle = &call_toggle,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("DOMTokenList has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(DOMTokenListImpl, "init") and @hasDecl(DOMTokenListImpl, "initOwn")) @compileError("DOMTokenListImpl defines both init and initOwn");
        if (comptime @hasDecl(DOMTokenListImpl, "init")) return DOMTokenListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(DOMTokenListImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try DOMTokenListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DOMTokenListImpl, "init")) return false;
        if (comptime @hasDecl(DOMTokenListImpl, "construction_args")) {
            inline for (DOMTokenListImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(DOMTokenListImpl, "deinit") and @hasDecl(DOMTokenListImpl, "deinitOwn")) @compileError("DOMTokenListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DOMTokenListImpl, "deinit")) return DOMTokenListImpl.deinit(instance);
        if (comptime @hasDecl(DOMTokenListImpl, "deinitOwn")) DOMTokenListImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DOMTokenList")) {
            if (comptime @hasDecl(impls.DOMTokenList, "installHooks")) impls.DOMTokenList.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try DOMTokenListImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions], [Stringifier]
    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try DOMTokenListImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions], [Stringifier]
    pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try DOMTokenListImpl.set_value(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?runtime.DOMString {
        return try DOMTokenListImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggle(instance: *runtime.Instance, token: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try DOMTokenListImpl.call_toggle(instance, token, force);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replace(instance: *runtime.Instance, token: runtime.DOMString, newToken: runtime.DOMString) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try DOMTokenListImpl.call_replace(instance, token, newToken);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try DOMTokenListImpl.call_remove(instance, tokens);
    }

    pub fn call_contains(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
        return try DOMTokenListImpl.call_contains(instance, token);
    }

    pub fn call_supports(instance: *runtime.Instance, token: runtime.DOMString) anyerror!bool {
        return try DOMTokenListImpl.call_supports(instance, token);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, tokens: []const runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try DOMTokenListImpl.call_add(instance, tokens);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_value",
        "call_toggle",
        "call_replace",
        "call_remove",
        "call_add",
    };
};
