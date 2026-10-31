//! Generated from: server-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceServerTimingImpl = @import("impls").PerformanceServerTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceServerTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceServerTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "duration", "get_duration", null },
            .{ "description", "get_description", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "duration", "get_duration", null },
            .{ "description", "get_description", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: runtime.DOMString = undefined,
            duration: typedefs.DOMHighResTimeStamp = undefined,
            description: runtime.DOMString = undefined,
            _internal: ?*PerformanceServerTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceServerTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceServerTimingToJSON = struct {
        name: runtime.DOMString,
        duration: DOMHighResTimeStamp,
        description: runtime.DOMString,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_description = &get_description,
        .get_duration = &get_duration,
        .get_name = &get_name,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("PerformanceServerTiming has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PerformanceServerTimingImpl, "init") and @hasDecl(PerformanceServerTimingImpl, "initOwn")) @compileError("PerformanceServerTimingImpl defines both init and initOwn");
        if (comptime @hasDecl(PerformanceServerTimingImpl, "init")) return PerformanceServerTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PerformanceServerTimingImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PerformanceServerTimingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PerformanceServerTimingImpl, "init")) return false;
        if (comptime @hasDecl(PerformanceServerTimingImpl, "construction_args")) {
            inline for (PerformanceServerTimingImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PerformanceServerTimingImpl, "deinit") and @hasDecl(PerformanceServerTimingImpl, "deinitOwn")) @compileError("PerformanceServerTimingImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PerformanceServerTimingImpl, "deinit")) return PerformanceServerTimingImpl.deinit(instance);
        if (comptime @hasDecl(PerformanceServerTimingImpl, "deinitOwn")) PerformanceServerTimingImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PerformanceServerTiming")) {
            if (comptime @hasDecl(impls.PerformanceServerTiming, "installHooks")) impls.PerformanceServerTiming.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PerformanceServerTimingImpl.get_name(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceServerTimingImpl.get_duration(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PerformanceServerTimingImpl.get_description(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceServerTimingToJSON {
        return try PerformanceServerTimingImpl.call_toJSON(instance);
    }
};
