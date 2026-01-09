//! Generated from: css-paint-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaintWorkletGlobalScopeImpl = @import("impls").PaintWorkletGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WorkletGlobalScope = @import("WorkletGlobalScope.zig").WorkletGlobalScope;
const VoidFunction = @import("callbacks").VoidFunction;
const DOMString = @import("typedefs").DOMString;

pub const PaintWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "PaintWorkletGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkletGlobalScope.State;
        pub const ParentInterface = WorkletGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "PaintWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "PaintWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .PaintWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "registerPaint", "call_registerPaint", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "registerPaint",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
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
            devicePixelRatio: f64 = undefined,
            _internal: ?*PaintWorkletGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_devicePixelRatio = &get_devicePixelRatio,

        .call_registerPaint = &call_registerPaint,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaintWorkletGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PaintWorkletGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaintWorkletGlobalScopeImpl.deinit(instance);
    }

    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
        return try PaintWorkletGlobalScopeImpl.get_devicePixelRatio(instance);
    }

    pub fn call_registerPaint(instance: *runtime.Instance, name: DOMString, paintCtor: VoidFunction) anyerror!void {
        
        return try PaintWorkletGlobalScopeImpl.call_registerPaint(instance, name, paintCtor);
    }

};
