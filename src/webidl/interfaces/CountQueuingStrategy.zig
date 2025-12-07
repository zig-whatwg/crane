//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CountQueuingStrategyImpl = @import("impls").CountQueuingStrategy;
const mixins = @import("mixins");
const Function = @import("callbacks").Function;
const QueuingStrategyInit = @import("dictionaries").QueuingStrategyInit;

pub const CountQueuingStrategy = struct {
    pub const Meta = struct {
        pub const name = "CountQueuingStrategy";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "highWaterMark", "get_highWaterMark", null },
            .{ "size", "get_size", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "highWaterMark", "get_highWaterMark", null },
            .{ "size", "get_size", null },
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
            highWaterMark: f64 = undefined,
            size: Function = undefined,
            _internal: ?*CountQueuingStrategyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_highWaterMark = &get_highWaterMark,
        .get_size = &get_size,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CountQueuingStrategyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CountQueuingStrategyImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: QueuingStrategyInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CountQueuingStrategyImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_highWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try CountQueuingStrategyImpl.get_highWaterMark(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!Function {
        return try CountQueuingStrategyImpl.get_size(instance);
    }

};
