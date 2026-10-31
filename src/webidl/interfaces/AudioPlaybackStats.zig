//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioPlaybackStatsImpl = @import("impls").AudioPlaybackStats;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const AudioPlaybackStats = struct {
    pub const Meta = struct {
        pub const name = "AudioPlaybackStats";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "underrunDuration", "get_underrunDuration", null },
            .{ "underrunEvents", "get_underrunEvents", null },
            .{ "totalDuration", "get_totalDuration", null },
            .{ "averageLatency", "get_averageLatency", null },
            .{ "minimumLatency", "get_minimumLatency", null },
            .{ "maximumLatency", "get_maximumLatency", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "resetLatency", "call_resetLatency", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "resetLatency",
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "underrunDuration", "get_underrunDuration", null },
            .{ "underrunEvents", "get_underrunEvents", null },
            .{ "totalDuration", "get_totalDuration", null },
            .{ "averageLatency", "get_averageLatency", null },
            .{ "minimumLatency", "get_minimumLatency", null },
            .{ "maximumLatency", "get_maximumLatency", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            underrunDuration: f64 = undefined,
            underrunEvents: u32 = undefined,
            totalDuration: f64 = undefined,
            averageLatency: f64 = undefined,
            minimumLatency: f64 = undefined,
            maximumLatency: f64 = undefined,
            _internal: ?*AudioPlaybackStatsImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for AudioPlaybackStats
    /// Generated from [Default] toJSON extended attribute
    pub const AudioPlaybackStatsToJSON = struct {
        underrunDuration: f64,
        underrunEvents: u32,
        totalDuration: f64,
        averageLatency: f64,
        minimumLatency: f64,
        maximumLatency: f64,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_averageLatency = &get_averageLatency,
        .get_maximumLatency = &get_maximumLatency,
        .get_minimumLatency = &get_minimumLatency,
        .get_totalDuration = &get_totalDuration,
        .get_underrunDuration = &get_underrunDuration,
        .get_underrunEvents = &get_underrunEvents,

        .call_resetLatency = &call_resetLatency,
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
            if (comptime !takesConstructionArg(field_name)) @compileError("AudioPlaybackStats has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "init") and @hasDecl(AudioPlaybackStatsImpl, "initOwn")) @compileError("AudioPlaybackStatsImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "init")) return AudioPlaybackStatsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AudioPlaybackStatsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "init")) return false;
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "construction_args")) {
            inline for (AudioPlaybackStatsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "deinit") and @hasDecl(AudioPlaybackStatsImpl, "deinitOwn")) @compileError("AudioPlaybackStatsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "deinit")) return AudioPlaybackStatsImpl.deinit(instance);
        if (comptime @hasDecl(AudioPlaybackStatsImpl, "deinitOwn")) AudioPlaybackStatsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioPlaybackStats")) {
            if (comptime @hasDecl(impls.AudioPlaybackStats, "installHooks")) impls.AudioPlaybackStats.installHooks();
        }
    }

    pub fn get_underrunDuration(instance: *runtime.Instance) anyerror!f64 {
        return try AudioPlaybackStatsImpl.get_underrunDuration(instance);
    }

    pub fn get_underrunEvents(instance: *runtime.Instance) anyerror!u32 {
        return try AudioPlaybackStatsImpl.get_underrunEvents(instance);
    }

    pub fn get_totalDuration(instance: *runtime.Instance) anyerror!f64 {
        return try AudioPlaybackStatsImpl.get_totalDuration(instance);
    }

    pub fn get_averageLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioPlaybackStatsImpl.get_averageLatency(instance);
    }

    pub fn get_minimumLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioPlaybackStatsImpl.get_minimumLatency(instance);
    }

    pub fn get_maximumLatency(instance: *runtime.Instance) anyerror!f64 {
        return try AudioPlaybackStatsImpl.get_maximumLatency(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!AudioPlaybackStatsToJSON {
        return try AudioPlaybackStatsImpl.call_toJSON(instance);
    }

    pub fn call_resetLatency(instance: *runtime.Instance) anyerror!void {
        return try AudioPlaybackStatsImpl.call_resetLatency(instance);
    }
};
