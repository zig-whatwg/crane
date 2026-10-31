//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OriginImpl = @import("impls").Origin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const Origin = struct {
    pub const Meta = struct {
        pub const name = "Origin";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "opaque", "get_opaque", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "isSameOrigin", "call_isSameOrigin", 1 },
            .{ "isSameSite", "call_isSameSite", 1 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "from", "call_static_from", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "from",
            "isSameOrigin",
            "isSameSite",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "opaque", "get_opaque", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"opaque": bool = undefined,
            _internal: ?*OriginImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_opaque = &get_opaque,

        .call_isSameOrigin = &call_isSameOrigin,
        .call_isSameSite = &call_isSameSite,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Origin has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(OriginImpl, "init") and @hasDecl(OriginImpl, "initOwn")) @compileError("OriginImpl defines both init and initOwn");
        if (comptime @hasDecl(OriginImpl, "init")) return OriginImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(OriginImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try OriginImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OriginImpl, "init")) return false;
        if (comptime @hasDecl(OriginImpl, "construction_args")) {
            inline for (OriginImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(OriginImpl, "deinit") and @hasDecl(OriginImpl, "deinitOwn")) @compileError("OriginImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OriginImpl, "deinit")) return OriginImpl.deinit(instance);
        if (comptime @hasDecl(OriginImpl, "deinitOwn")) OriginImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Origin")) {
            if (comptime @hasDecl(impls.Origin, "installHooks")) impls.Origin.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OriginImpl.call_constructor(ctx);
    }

    pub fn get_opaque(instance: *runtime.Instance) anyerror!bool {
        return try OriginImpl.get_opaque(instance);
    }

    pub fn call_isSameOrigin(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
        return try OriginImpl.call_isSameOrigin(instance, other);
    }

    pub fn call_static_from(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
        return try OriginImpl.call_static_from(instance, value);
    }

    pub fn call_isSameSite(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
        return try OriginImpl.call_isSameSite(instance, other);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_isSameOrigin", 0, "Origin" },
        .{ "call_isSameSite", 0, "Origin" },
    };
};
