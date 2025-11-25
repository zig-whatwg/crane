//! Generated from: user-timing.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceMarkImpl = @import("impls").PerformanceMark;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PerformanceMarkOptions = @import("dictionaries").PerformanceMarkOptions;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceMark = struct {
    pub const Meta = struct {
        pub const name = "PerformanceMark";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
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
            .{ "detail", "get_detail", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "detail", "get_detail", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            detail: *const anyopaque = undefined,
            _internal: ?*PerformanceMarkImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_detail = &get_detail,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceMarkImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceMarkImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, markName: DOMString, markOptions: PerformanceMarkOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PerformanceMarkImpl.call_constructor(allocator, ctx, markName, markOptions);
    }

    pub fn get_detail(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceMarkImpl.get_detail(instance);
    }

};
