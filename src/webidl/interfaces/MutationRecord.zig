//! Generated from: dom.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MutationRecordImpl = @import("impls").MutationRecord;
const mixins = @import("mixins");
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const DOMString = @import("typedefs").DOMString;

pub const MutationRecord = struct {
    pub const Meta = struct {
        pub const name = "MutationRecord";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "target", "get_target", null },
            .{ "addedNodes", "get_addedNodes", null },
            .{ "removedNodes", "get_removedNodes", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
            .{ "attributeName", "get_attributeName", null },
            .{ "attributeNamespace", "get_attributeNamespace", null },
            .{ "oldValue", "get_oldValue", null },
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
            .{ "type", "get_type", null },
            .{ "target", "get_target", null },
            .{ "addedNodes", "get_addedNodes", null },
            .{ "removedNodes", "get_removedNodes", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
            .{ "attributeName", "get_attributeName", null },
            .{ "attributeNamespace", "get_attributeNamespace", null },
            .{ "oldValue", "get_oldValue", null },
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
            @"type": runtime.DOMString = undefined,
            target: *runtime.Instance = undefined,
            addedNodes: *runtime.Instance = undefined,
            removedNodes: *runtime.Instance = undefined,
            previousSibling: ?*runtime.Instance = null,
            nextSibling: ?*runtime.Instance = null,
            attributeName: ?runtime.DOMString = null,
            attributeNamespace: ?runtime.DOMString = null,
            oldValue: ?runtime.DOMString = null,
            cached_target: ?*runtime.Instance = null,
            cached_addedNodes: ?*runtime.Instance = null,
            cached_removedNodes: ?*runtime.Instance = null,
            _internal: ?*MutationRecordImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_addedNodes = &get_addedNodes,
        .get_attributeName = &get_attributeName,
        .get_attributeNamespace = &get_attributeNamespace,
        .get_nextSibling = &get_nextSibling,
        .get_oldValue = &get_oldValue,
        .get_previousSibling = &get_previousSibling,
        .get_removedNodes = &get_removedNodes,
        .get_target = &get_target,
        .get_type = &get_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MutationRecordImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MutationRecordImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try MutationRecordImpl.get_type(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_target) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_target(instance);
        state.own.cached_target = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_addedNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_addedNodes) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_addedNodes(instance);
        state.own.cached_addedNodes = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_removedNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_removedNodes) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_removedNodes(instance);
        state.own.cached_removedNodes = value;
        return value;
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try MutationRecordImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try MutationRecordImpl.get_nextSibling(instance);
    }

    pub fn get_attributeName(instance: *runtime.Instance) anyerror!?DOMString {
        return try MutationRecordImpl.get_attributeName(instance);
    }

    pub fn get_attributeNamespace(instance: *runtime.Instance) anyerror!?DOMString {
        return try MutationRecordImpl.get_attributeNamespace(instance);
    }

    pub fn get_oldValue(instance: *runtime.Instance) anyerror!?DOMString {
        return try MutationRecordImpl.get_oldValue(instance);
    }

};
