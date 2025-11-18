//! Generated from: xhr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FormDataImpl = @import("impls").FormData;
const Blob = @import("interfaces").Blob;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const FormDataEntryValue = @import("typedefs").FormDataEntryValue;

pub const FormData = struct {
    pub const Meta = struct {
        pub const name = "FormData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FormData, .{
        .deinit_fn = &deinit_wrapper,

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FormDataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FormDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, form: HTMLFormElement, submitter: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try FormDataImpl.constructor(instance, form, submitter);
        
        return instance;
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!void {
        
        return try FormDataImpl.call_delete(instance, name);
    }

    /// Arguments for append (WebIDL overloading)
    pub const AppendArgs = union(enum) {
        /// append(name, value)
        USVString_USVString: struct {
            name: runtime.USVString,
            value: runtime.USVString,
        },
        /// append(name, blobValue, filename)
        USVString_Blob_USVString: struct {
            name: runtime.USVString,
            blobValue: Blob,
            filename: runtime.USVString,
        },
    };

    pub fn call_append(instance: *runtime.Instance, args: AppendArgs) anyerror!void {
        switch (args) {
            .USVString_USVString => |a| return try FormDataImpl.USVString_USVString(instance, a.name, a.value),
            .USVString_Blob_USVString => |a| return try FormDataImpl.USVString_Blob_USVString(instance, a.name, a.blobValue, a.filename),
        }
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try FormDataImpl.call_getAll(instance, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString) anyerror!bool {
        
        return try FormDataImpl.call_has(instance, name);
    }

    /// Arguments for set (WebIDL overloading)
    pub const SetArgs = union(enum) {
        /// set(name, value)
        USVString_USVString: struct {
            name: runtime.USVString,
            value: runtime.USVString,
        },
        /// set(name, blobValue, filename)
        USVString_Blob_USVString: struct {
            name: runtime.USVString,
            blobValue: Blob,
            filename: runtime.USVString,
        },
    };

    pub fn call_set(instance: *runtime.Instance, args: SetArgs) anyerror!void {
        switch (args) {
            .USVString_USVString => |a| return try FormDataImpl.USVString_USVString(instance, a.name, a.value),
            .USVString_Blob_USVString => |a| return try FormDataImpl.USVString_Blob_USVString(instance, a.name, a.blobValue, a.filename),
        }
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try FormDataImpl.call_get(instance, name);
    }

};
