//! Generated from: streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ByteLengthQueuingStrategyImpl = @import("impls").ByteLengthQueuingStrategy;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Function = @import("callbacks").Function;
const QueuingStrategyInit = @import("dictionaries").QueuingStrategyInit;

pub const ByteLengthQueuingStrategy = struct {
    pub const Meta = struct {
        pub const name = "ByteLengthQueuingStrategy";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            highWaterMark: f64 = undefined,
            size: runtime.JSValue = undefined,
            _internal: ?*ByteLengthQueuingStrategyImpl.InternalState = null,
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
        return ByteLengthQueuingStrategyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ByteLengthQueuingStrategyImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ByteLengthQueuingStrategyImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: QueuingStrategyInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ByteLengthQueuingStrategyImpl.call_constructor(ctx, init_data);
    }

    pub fn get_highWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try ByteLengthQueuingStrategyImpl.get_highWaterMark(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!Function {
        return try ByteLengthQueuingStrategyImpl.get_size(instance);
    }

};
