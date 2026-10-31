//! Generated from: mediacapture-extensions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaStreamTrackAudioStatsImpl = @import("impls").MediaStreamTrackAudioStats;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;

pub const MediaStreamTrackAudioStats = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamTrackAudioStats";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "latency", "get_latency", null },
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
            .{ "latency", "get_latency", null },
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
            latency: typedefs.DOMHighResTimeStamp = undefined,
            averageLatency: typedefs.DOMHighResTimeStamp = undefined,
            minimumLatency: typedefs.DOMHighResTimeStamp = undefined,
            maximumLatency: typedefs.DOMHighResTimeStamp = undefined,
            _internal: ?*MediaStreamTrackAudioStatsImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for MediaStreamTrackAudioStats
    /// Generated from [Default] toJSON extended attribute
    pub const MediaStreamTrackAudioStatsToJSON = struct {
        latency: DOMHighResTimeStamp,
        averageLatency: DOMHighResTimeStamp,
        minimumLatency: DOMHighResTimeStamp,
        maximumLatency: DOMHighResTimeStamp,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_averageLatency = &get_averageLatency,
        .get_latency = &get_latency,
        .get_maximumLatency = &get_maximumLatency,
        .get_minimumLatency = &get_minimumLatency,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("MediaStreamTrackAudioStats has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "init") and @hasDecl(MediaStreamTrackAudioStatsImpl, "initOwn")) @compileError("MediaStreamTrackAudioStatsImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "init")) return MediaStreamTrackAudioStatsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaStreamTrackAudioStatsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "init")) return false;
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "construction_args")) {
            inline for (MediaStreamTrackAudioStatsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "deinit") and @hasDecl(MediaStreamTrackAudioStatsImpl, "deinitOwn")) @compileError("MediaStreamTrackAudioStatsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "deinit")) return MediaStreamTrackAudioStatsImpl.deinit(instance);
        if (comptime @hasDecl(MediaStreamTrackAudioStatsImpl, "deinitOwn")) MediaStreamTrackAudioStatsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaStreamTrackAudioStats")) {
            if (comptime @hasDecl(impls.MediaStreamTrackAudioStats, "installHooks")) impls.MediaStreamTrackAudioStats.installHooks();
        }
    }

    pub fn get_latency(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try MediaStreamTrackAudioStatsImpl.get_latency(instance);
    }

    pub fn get_averageLatency(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try MediaStreamTrackAudioStatsImpl.get_averageLatency(instance);
    }

    pub fn get_minimumLatency(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try MediaStreamTrackAudioStatsImpl.get_minimumLatency(instance);
    }

    pub fn get_maximumLatency(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try MediaStreamTrackAudioStatsImpl.get_maximumLatency(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!MediaStreamTrackAudioStatsToJSON {
        return try MediaStreamTrackAudioStatsImpl.call_toJSON(instance);
    }

    pub fn call_resetLatency(instance: *runtime.Instance) anyerror!void {
        return try MediaStreamTrackAudioStatsImpl.call_resetLatency(instance);
    }
};
