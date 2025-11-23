//! Generated from: html.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VisibilityStateEntryImpl = @import("impls").VisibilityStateEntry;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const VisibilityStateEntry = struct {
    pub const Meta = struct {
        pub const name = "VisibilityStateEntry";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "toJSON",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "entryType", "get_entryType", null },
            .{ "startTime", "get_startTime", null },
            .{ "duration", "get_duration", null },
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
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            startTime: DOMHighResTimeStamp = undefined,
            duration: u32 = undefined,
        },
    );

    const delegates = .{

        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_name = &get_name,
        .get_startTime = &get_startTime,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VisibilityStateEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VisibilityStateEntryImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try VisibilityStateEntryImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try VisibilityStateEntryImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try VisibilityStateEntryImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!u32 {
        return try VisibilityStateEntryImpl.get_duration(instance);
    }

};
