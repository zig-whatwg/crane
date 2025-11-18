//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MutationRecordImpl = @import("../impls/MutationRecord.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        MutationRecordImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MutationRecordImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MutationRecordImpl.get_type(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_target) |cached| {
            return cached;
        }
        const value = MutationRecordImpl.get_target(state);
        state.cached_target = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_addedNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_addedNodes) |cached| {
            return cached;
        }
        const value = MutationRecordImpl.get_addedNodes(state);
        state.cached_addedNodes = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_removedNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_removedNodes) |cached| {
            return cached;
        }
        const value = MutationRecordImpl.get_removedNodes(state);
        state.cached_removedNodes = value;
        return value;
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationRecordImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationRecordImpl.get_nextSibling(state);
    }

    pub fn get_attributeName(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationRecordImpl.get_attributeName(state);
    }

    pub fn get_attributeNamespace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationRecordImpl.get_attributeNamespace(state);
    }

    pub fn get_oldValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationRecordImpl.get_oldValue(state);
    }

};
