//! Generated from: long-animation-frames.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceLongAnimationFrameTimingImpl = @import("impls").PerformanceLongAnimationFrameTiming;
const mixins = @import("mixins");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("interfaces").PaintTimingMixin;
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
        pub const inherited_methods = .{
        };
        
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            startTime: DOMHighResTimeStamp = undefined,
            duration: DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            renderStart: DOMHighResTimeStamp = undefined,
            styleAndLayoutStart: DOMHighResTimeStamp = undefined,
            blockingDuration: DOMHighResTimeStamp = undefined,
            firstUIEventTimestamp: DOMHighResTimeStamp = undefined,
            scripts: runtime.FrozenArray(PerformanceScriptTiming) = undefined,
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
            cached_scripts: ?runtime.FrozenArray(PerformanceScriptTiming) = null,
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
        presentationTime: DOMHighResTimeStamp,
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
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceLongAnimationFrameTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceLongAnimationFrameTimingImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceLongAnimationFrameTimingImpl.deinit(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
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
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_scripts) |cached| {
            return cached;
        }
        const value = try PerformanceLongAnimationFrameTimingImpl.get_scripts(instance);
        state.own.cached_scripts = value;
        return value;
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_presentationTime(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceLongAnimationFrameTimingToJSON {
        return try PerformanceLongAnimationFrameTimingImpl.call_toJSON(instance);
    }

};
