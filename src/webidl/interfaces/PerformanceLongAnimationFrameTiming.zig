//! Generated from: long-animation-frames.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceLongAnimationFrameTimingImpl = @import("impls").PerformanceLongAnimationFrameTiming;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("mixins").PaintTimingMixin;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PerformanceScriptTiming = @import("interfaces").PerformanceScriptTiming;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceLongAnimationFrameTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceLongAnimationFrameTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PerformanceEntry.State;
        pub const ParentInterface = PerformanceEntry;
        pub const MixinTypes = &.{
            PaintTimingMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "renderStart", "get_renderStart", null },
            .{ "styleAndLayoutStart", "get_styleAndLayoutStart", null },
            .{ "blockingDuration", "get_blockingDuration", null },
            .{ "firstUIEventTimestamp", "get_firstUIEventTimestamp", null },
            .{ "scripts", "get_scripts", null },
            .{ "paintTime", "get_paintTime", null },
            .{ "presentationTime", "get_presentationTime", null },
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
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "renderStart", "get_renderStart", null },
            .{ "styleAndLayoutStart", "get_styleAndLayoutStart", null },
            .{ "blockingDuration", "get_blockingDuration", null },
            .{ "firstUIEventTimestamp", "get_firstUIEventTimestamp", null },
            .{ "scripts", "get_scripts", null },
            .{ "paintTime", "get_paintTime", null },
            .{ "presentationTime", "get_presentationTime", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "paintTime", .{"Window"} },
            .{ "presentationTime", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            startTime: typedefs.DOMHighResTimeStamp = undefined,
            duration: typedefs.DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            renderStart: typedefs.DOMHighResTimeStamp = undefined,
            styleAndLayoutStart: typedefs.DOMHighResTimeStamp = undefined,
            blockingDuration: typedefs.DOMHighResTimeStamp = undefined,
            firstUIEventTimestamp: typedefs.DOMHighResTimeStamp = undefined,
            scripts: runtime.JSValue = undefined,
            paintTime: typedefs.DOMHighResTimeStamp = undefined,
            presentationTime: ?typedefs.DOMHighResTimeStamp = null,
            cached_scripts: ?runtime.JSValue = null,
            _internal: ?*PerformanceLongAnimationFrameTimingImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceLongAnimationFrameTiming
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceLongAnimationFrameTimingToJSON = struct {
        id: u64,
        name: runtime.DOMString,
        entryType: runtime.DOMString,
        startTime: DOMHighResTimeStamp,
        duration: DOMHighResTimeStamp,
        navigationId: u64,
        renderStart: DOMHighResTimeStamp,
        styleAndLayoutStart: DOMHighResTimeStamp,
        blockingDuration: DOMHighResTimeStamp,
        firstUIEventTimestamp: DOMHighResTimeStamp,
        scripts: runtime.JSValue,
        paintTime: DOMHighResTimeStamp,
        presentationTime: ?DOMHighResTimeStamp,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_blockingDuration = &get_blockingDuration,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_firstUIEventTimestamp = &get_firstUIEventTimestamp,
        .get_name = &get_name,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderStart = &get_renderStart,
        .get_scripts = &get_scripts,
        .get_startTime = &get_startTime,
        .get_styleAndLayoutStart = &get_styleAndLayoutStart,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PerformanceLongAnimationFrameTiming has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "init") and @hasDecl(PerformanceLongAnimationFrameTimingImpl, "initOwn")) @compileError("PerformanceLongAnimationFrameTimingImpl defines both init and initOwn");
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "init")) return PerformanceLongAnimationFrameTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PerformanceLongAnimationFrameTimingImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "init")) return false;
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "construction_args")) {
            inline for (PerformanceLongAnimationFrameTimingImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "deinit") and @hasDecl(PerformanceLongAnimationFrameTimingImpl, "deinitOwn")) @compileError("PerformanceLongAnimationFrameTimingImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "deinit")) return PerformanceLongAnimationFrameTimingImpl.deinit(instance);
        if (comptime @hasDecl(PerformanceLongAnimationFrameTimingImpl, "deinitOwn")) PerformanceLongAnimationFrameTimingImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PerformanceLongAnimationFrameTiming")) {
            if (comptime @hasDecl(impls.PerformanceLongAnimationFrameTiming, "installHooks")) impls.PerformanceLongAnimationFrameTiming.installHooks();
        }
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_entryType(instance);
    }

    pub fn get_renderStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_renderStart(instance);
    }

    pub fn get_styleAndLayoutStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_styleAndLayoutStart(instance);
    }

    pub fn get_blockingDuration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_blockingDuration(instance);
    }

    pub fn get_firstUIEventTimestamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_firstUIEventTimestamp(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_scripts(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PerformanceLongAnimationFrameTimingImpl.get_scripts(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_paintTime(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceLongAnimationFrameTimingToJSON {
        return try PerformanceLongAnimationFrameTimingImpl.call_toJSON(instance);
    }
};
