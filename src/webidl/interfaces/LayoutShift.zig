//! Generated from: layout-instability.idl
//! Generated at: 2025-12-07T19:33:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const LayoutShiftImpl = @import("impls").LayoutShift;
const mixins = @import("mixins");
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const LayoutShiftAttribution = @import("interfaces").LayoutShiftAttribution;
const DOMString = @import("typedefs").DOMString;

pub const LayoutShift = struct {
    pub const Meta = struct {
        pub const name = "LayoutShift";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PerformanceEntry.State;
        pub const ParentInterface = PerformanceEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", null },
            .{ "hadRecentInput", "get_hadRecentInput", null },
            .{ "lastInputTime", "get_lastInputTime", null },
            .{ "sources", "get_sources", null },
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
            .{ "value", "get_value", null },
            .{ "hadRecentInput", "get_hadRecentInput", null },
            .{ "lastInputTime", "get_lastInputTime", null },
            .{ "sources", "get_sources", null },
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
            value: f64 = undefined,
            hadRecentInput: bool = undefined,
            lastInputTime: DOMHighResTimeStamp = undefined,
            sources: runtime.FrozenArray(LayoutShiftAttribution) = undefined,
            _internal: ?*LayoutShiftImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hadRecentInput = &get_hadRecentInput,
        .get_lastInputTime = &get_lastInputTime,
        .get_sources = &get_sources,
        .get_value = &get_value,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutShiftImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutShiftImpl.deinit(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutShiftImpl.get_value(instance);
    }

    pub fn get_hadRecentInput(instance: *runtime.Instance) anyerror!bool {
        return try LayoutShiftImpl.get_hadRecentInput(instance);
    }

    pub fn get_lastInputTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LayoutShiftImpl.get_lastInputTime(instance);
    }

    pub fn get_sources(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try LayoutShiftImpl.get_sources(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!v8.JSValue {
        return try LayoutShiftImpl.call_toJSON(instance);
    }

};
