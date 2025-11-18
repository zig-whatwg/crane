//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MutationRecordImpl = @import("impls").MutationRecord;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const DOMString = @import("typedefs").DOMString;

pub const MutationRecord = struct {
    pub const Meta = struct {
        pub const name = "MutationRecord";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: runtime.DOMString = undefined,
            target: Node = undefined,
            addedNodes: NodeList = undefined,
            removedNodes: NodeList = undefined,
            previousSibling: ?Node = null,
            nextSibling: ?Node = null,
            attributeName: ?runtime.DOMString = null,
            attributeNamespace: ?runtime.DOMString = null,
            oldValue: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MutationRecord, .{
        .deinit_fn = &deinit_wrapper,

        .get_addedNodes = &get_addedNodes,
        .get_attributeName = &get_attributeName,
        .get_attributeNamespace = &get_attributeNamespace,
        .get_nextSibling = &get_nextSibling,
        .get_oldValue = &get_oldValue,
        .get_previousSibling = &get_previousSibling,
        .get_removedNodes = &get_removedNodes,
        .get_target = &get_target,
        .get_type = &get_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        MutationRecordImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MutationRecordImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try MutationRecordImpl.get_type(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_target(instance: *runtime.Instance) anyerror!Node {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_target) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_target(instance);
        state.cached_target = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_addedNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_addedNodes) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_addedNodes(instance);
        state.cached_addedNodes = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_removedNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_removedNodes) |cached| {
            return cached;
        }
        const value = try MutationRecordImpl.get_removedNodes(instance);
        state.cached_removedNodes = value;
        return value;
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try MutationRecordImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try MutationRecordImpl.get_nextSibling(instance);
    }

    pub fn get_attributeName(instance: *runtime.Instance) anyerror!anyopaque {
        return try MutationRecordImpl.get_attributeName(instance);
    }

    pub fn get_attributeNamespace(instance: *runtime.Instance) anyerror!anyopaque {
        return try MutationRecordImpl.get_attributeNamespace(instance);
    }

    pub fn get_oldValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try MutationRecordImpl.get_oldValue(instance);
    }

};
