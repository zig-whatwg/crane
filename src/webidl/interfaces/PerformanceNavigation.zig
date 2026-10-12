//! Generated from: navigation-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceNavigationImpl = @import("impls").PerformanceNavigation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const PerformanceNavigation = struct {
    pub const Meta = struct {
        pub const name = "PerformanceNavigation";
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
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "TYPE_NAVIGATE", "get_TYPE_NAVIGATE" },
            .{ "TYPE_RELOAD", "get_TYPE_RELOAD" },
            .{ "TYPE_BACK_FORWARD", "get_TYPE_BACK_FORWARD" },
            .{ "TYPE_RESERVED", "get_TYPE_RESERVED" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: u16 = undefined,
            redirectCount: u16 = undefined,
            _internal: ?*PerformanceNavigationImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short TYPE_NAVIGATE = 0;
    pub fn get_TYPE_NAVIGATE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short TYPE_RELOAD = 1;
    pub fn get_TYPE_RELOAD() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short TYPE_BACK_FORWARD = 2;
    pub fn get_TYPE_BACK_FORWARD() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TYPE_RESERVED = 255;
    pub fn get_TYPE_RESERVED() u16 {
        return 255;
    }

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceNavigation
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceNavigationToJSON = struct {
        type: u16,
        redirectCount: u16,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_TYPE_BACK_FORWARD = &get_TYPE_BACK_FORWARD,
        .get_TYPE_NAVIGATE = &get_TYPE_NAVIGATE,
        .get_TYPE_RELOAD = &get_TYPE_RELOAD,
        .get_TYPE_RESERVED = &get_TYPE_RESERVED,
        .get_redirectCount = &get_redirectCount,
        .get_type = &get_type,

        .call_toJSON = &call_toJSON,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("PerformanceNavigation has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PerformanceNavigationImpl, "init") and @hasDecl(PerformanceNavigationImpl, "initOwn")) @compileError("PerformanceNavigationImpl defines both init and initOwn");
        if (comptime @hasDecl(PerformanceNavigationImpl, "init")) return PerformanceNavigationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PerformanceNavigationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PerformanceNavigationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PerformanceNavigationImpl, "init")) return false;
        if (comptime @hasDecl(PerformanceNavigationImpl, "construction_args")) {
            inline for (PerformanceNavigationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PerformanceNavigationImpl, "deinit") and @hasDecl(PerformanceNavigationImpl, "deinitOwn")) @compileError("PerformanceNavigationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PerformanceNavigationImpl, "deinit")) return PerformanceNavigationImpl.deinit(instance);
        if (comptime @hasDecl(PerformanceNavigationImpl, "deinitOwn")) PerformanceNavigationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PerformanceNavigation")) {
            if (comptime @hasDecl(impls.PerformanceNavigation, "installHooks")) impls.PerformanceNavigation.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_type(instance);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_redirectCount(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceNavigationToJSON {
        return try PerformanceNavigationImpl.call_toJSON(instance);
    }
};
