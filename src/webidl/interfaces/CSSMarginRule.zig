//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMarginRuleImpl = @import("impls").CSSMarginRule;
const mixins = @import("mixins");
const CSSRule = @import("interfaces").CSSRule;
const CSSMarginDescriptors = @import("interfaces").CSSMarginDescriptors;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSMarginRule = struct {
    pub const Meta = struct {
        pub const name = "CSSMarginRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSRule.State;
        pub const ParentInterface = CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "style", "get_style", "set_style" },
        };
        
        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "style", "cssText" },
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
            .{ "name", "get_name", null },
            .{ "style", "get_style", "set_style" },
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
            name: CSSOMString = undefined,
            style: CSSMarginDescriptors = undefined,
            cached_style: ?CSSMarginDescriptors = null,
            _internal: ?*CSSMarginRuleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_style = &get_style,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSMarginRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CSSMarginRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSMarginRuleImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSMarginRuleImpl.get_name(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!runtime.JSValue {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try CSSMarginRuleImpl.get_style(instance);
        state.own.cached_style = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn set_style(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'style' forwards to 'cssText' on the attribute's value
        const target = try get_style(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "cssText", value);
    }

};
