//! Generated from: ink-enhancement.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DelegatedInkTrailPresenterImpl = @import("impls").DelegatedInkTrailPresenter;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const PointerEvent = @import("interfaces").PointerEvent;
const InkTrailStyle = @import("dictionaries").InkTrailStyle;

pub const DelegatedInkTrailPresenter = struct {
    pub const Meta = struct {
        pub const name = "DelegatedInkTrailPresenter";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "presentationArea", "get_presentationArea", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "updateInkTrailStartPoint", "call_updateInkTrailStartPoint", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "updateInkTrailStartPoint",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "presentationArea", "get_presentationArea", null },
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
            presentationArea: ?*runtime.Instance = null,
            _internal: ?*DelegatedInkTrailPresenterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_presentationArea = &get_presentationArea,

        .call_updateInkTrailStartPoint = &call_updateInkTrailStartPoint,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DelegatedInkTrailPresenterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DelegatedInkTrailPresenterImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DelegatedInkTrailPresenterImpl.deinit(instance);
    }

    pub fn get_presentationArea(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DelegatedInkTrailPresenterImpl.get_presentationArea(instance);
    }

    pub fn call_updateInkTrailStartPoint(instance: *runtime.Instance, event: *runtime.Instance, style: InkTrailStyle) anyerror!void {
        
        return try DelegatedInkTrailPresenterImpl.call_updateInkTrailStartPoint(instance, event, style);
    }

};
