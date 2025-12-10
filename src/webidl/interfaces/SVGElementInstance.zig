//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGElementInstanceImpl = @import("impls").SVGElementInstance;
const mixins = @import("mixins");
const SVGUseElement = @import("interfaces").SVGUseElement;
const SVGElement = @import("interfaces").SVGElement;

pub const SVGElementInstance = struct {
    pub const Meta = struct {
        pub const name = "SVGElementInstance";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "correspondingElement", "get_correspondingElement", null },
            .{ "correspondingUseElement", "get_correspondingUseElement", null },
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
            .{ "correspondingElement", "get_correspondingElement", null },
            .{ "correspondingUseElement", "get_correspondingUseElement", null },
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
            correspondingElement: ?*runtime.Instance = null,
            correspondingUseElement: ?*runtime.Instance = null,
            cached_correspondingElement: ?*runtime.Instance = null,
            cached_correspondingUseElement: ?*runtime.Instance = null,
            _internal: ?*SVGElementInstanceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_correspondingElement = &get_correspondingElement,
        .get_correspondingUseElement = &get_correspondingUseElement,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGElementInstanceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGElementInstanceImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGElementInstanceImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_correspondingElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_correspondingElement) |cached| {
            return cached;
        }
        const value = try SVGElementInstanceImpl.get_correspondingElement(instance);
        state.own.cached_correspondingElement = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_correspondingUseElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_correspondingUseElement) |cached| {
            return cached;
        }
        const value = try SVGElementInstanceImpl.get_correspondingUseElement(instance);
        state.own.cached_correspondingUseElement = value;
        return value;
    }

};
