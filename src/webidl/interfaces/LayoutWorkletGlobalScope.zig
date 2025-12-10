//! Generated from: css-layout-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LayoutWorkletGlobalScopeImpl = @import("impls").LayoutWorkletGlobalScope;
const mixins = @import("mixins");
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const VoidFunction = @import("callbacks").VoidFunction;
const DOMString = @import("typedefs").DOMString;

pub const LayoutWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "LayoutWorkletGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkletGlobalScope.State;
        pub const ParentInterface = WorkletGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "LayoutWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "registerLayout", "call_registerLayout", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "registerLayout",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*LayoutWorkletGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_registerLayout = &call_registerLayout,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LayoutWorkletGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return LayoutWorkletGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutWorkletGlobalScopeImpl.deinit(instance);
    }

    pub fn call_registerLayout(instance: *runtime.Instance, name: DOMString, layoutCtor: VoidFunction) anyerror!void {
        
        return try LayoutWorkletGlobalScopeImpl.call_registerLayout(instance, name, layoutCtor);
    }

};
