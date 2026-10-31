//! Generated from: EXT_disjoint_timer_query_webgl2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EXT_disjoint_timer_query_webgl2Impl = @import("impls").EXT_disjoint_timer_query_webgl2;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GLenum = @import("typedefs").GLenum;
const WebGLQuery = @import("interfaces").WebGLQuery;

pub const EXT_disjoint_timer_query_webgl2 = struct {
    pub const Meta = struct {
        pub const name = "EXT_disjoint_timer_query_webgl2";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "queryCounterEXT", "call_queryCounterEXT", 2 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "QUERY_COUNTER_BITS_EXT", "get_QUERY_COUNTER_BITS_EXT" },
            .{ "TIME_ELAPSED_EXT", "get_TIME_ELAPSED_EXT" },
            .{ "TIMESTAMP_EXT", "get_TIMESTAMP_EXT" },
            .{ "GPU_DISJOINT_EXT", "get_GPU_DISJOINT_EXT" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "queryCounterEXT",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*EXT_disjoint_timer_query_webgl2Impl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum QUERY_COUNTER_BITS_EXT = 34916;
    pub fn get_QUERY_COUNTER_BITS_EXT() GLenum {
        return 34916;
    }

    /// WebIDL constant: const GLenum TIME_ELAPSED_EXT = 35007;
    pub fn get_TIME_ELAPSED_EXT() GLenum {
        return 35007;
    }

    /// WebIDL constant: const GLenum TIMESTAMP_EXT = 36392;
    pub fn get_TIMESTAMP_EXT() GLenum {
        return 36392;
    }

    /// WebIDL constant: const GLenum GPU_DISJOINT_EXT = 36795;
    pub fn get_GPU_DISJOINT_EXT() GLenum {
        return 36795;
    }

    const delegates = .{
        .get_GPU_DISJOINT_EXT = &get_GPU_DISJOINT_EXT,
        .get_QUERY_COUNTER_BITS_EXT = &get_QUERY_COUNTER_BITS_EXT,
        .get_TIMESTAMP_EXT = &get_TIMESTAMP_EXT,
        .get_TIME_ELAPSED_EXT = &get_TIME_ELAPSED_EXT,

        .call_queryCounterEXT = &call_queryCounterEXT,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("EXT_disjoint_timer_query_webgl2 has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "init") and @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "initOwn")) @compileError("EXT_disjoint_timer_query_webgl2Impl defines both init and initOwn");
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "init")) return EXT_disjoint_timer_query_webgl2Impl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try EXT_disjoint_timer_query_webgl2Impl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "init")) return false;
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "construction_args")) {
            inline for (EXT_disjoint_timer_query_webgl2Impl.construction_args) |arg| {
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
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "deinit") and @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "deinitOwn")) @compileError("EXT_disjoint_timer_query_webgl2Impl defines both deinit and deinitOwn");
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "deinit")) return EXT_disjoint_timer_query_webgl2Impl.deinit(instance);
        if (comptime @hasDecl(EXT_disjoint_timer_query_webgl2Impl, "deinitOwn")) EXT_disjoint_timer_query_webgl2Impl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "EXT_disjoint_timer_query_webgl2")) {
            if (comptime @hasDecl(impls.EXT_disjoint_timer_query_webgl2, "installHooks")) impls.EXT_disjoint_timer_query_webgl2.installHooks();
        }
    }

    pub fn call_queryCounterEXT(instance: *runtime.Instance, query: *runtime.Instance, target: GLenum) anyerror!void {
        return try EXT_disjoint_timer_query_webgl2Impl.call_queryCounterEXT(instance, query, target);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_queryCounterEXT", 0, "WebGLQuery" },
    };
};
