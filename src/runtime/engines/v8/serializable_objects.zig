//! HTML 2.7.1 serializable objects, as V8's structured serialization reaches
//! them: the [Serializable] interfaces' serialization and deserialization
//! steps behind V8's ValueSerializer / ValueDeserializer delegates
//! (v8_wrapper.cpp, HostObjectSteps).
//!
//! V8 sees a platform object as a host object (an API wrapper) and asks the
//! delegate to write it (StructuredSerializeInternal steps 19-20, 26.3) or to
//! read one back (StructuredDeserialize steps 22-24). The steps themselves
//! are each interface's own, in its impl, published by its generated
//! interface as `serializable_steps`; the table below finds them at comptime,
//! by interface identifier, from the generated interfaces - which is where
//! the IDL's [Serializable] is recorded (Meta.extended_attributes).
//!
//! The steps fill an engine-neutral record (runtime.SerializationRecord);
//! this file copies it into V8's stream and back. In the stream a platform
//! object is: V8's host-object tag (V8 writes it), then
//!
//!   uint32  record format (1)
//!   uint32  length, bytes   the primary interface's identifier ([[Type]])
//!   uint64  length, bytes   the steps' own fields
//!   uint32  count           the sub-serializations, then each as V8 writes
//!                           any value - on the same serializer
//!
//! Everything is inline: the result is plain bytes, independent of any
//! realm, agent and thread, which is what a worker's message (read on the
//! worker's thread) and an IndexedDB record (read after the agent is gone)
//! need.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const ffi = @import("ffi.zig");
const conversions = @import("conversions.zig");
const value_operations = @import("value_operations.zig");

const log = std.log.scoped(.serializable_objects);

/// The version of the record layout above. A record of another version is
/// not read (DataCloneError): an IndexedDB record outlives the build that
/// wrote it.
const record_format: u32 = 1;

const Entry = struct { []const u8, runtime.SerializableSteps };

/// Every generated interface whose impl defines serialization steps, by
/// identifier. Codegen emits `serializable_steps` only for an interface the
/// IDL marks [Serializable], and makes it null while the impl has no steps.
const entries: []const Entry = blk: {
    @setEvalBranchQuota(1_000_000);
    var list: []const Entry = &.{};
    for (@typeInfo(interfaces).@"struct".decls) |decl| {
        const member = @field(interfaces, decl.name);
        if (@TypeOf(member) != type) continue;
        if (@typeInfo(member) != .@"struct") continue;
        if (!@hasDecl(member, "Meta") or !@hasDecl(member, "serializable_steps")) continue;
        if (member.serializable_steps) |steps| list = list ++ [_]Entry{.{ member.Meta.name, steps }};
    }
    break :blk list;
};

const table = std.StaticStringMap(runtime.SerializableSteps).initComptime(entries);

/// The serialization and deserialization steps of the [Serializable]
/// interface `identifier`, or null when it is not one, or has no steps yet.
pub fn stepsFor(identifier: []const u8) ?runtime.SerializableSteps {
    return table.get(identifier);
}

/// The identifiers of the interfaces `stepsFor` answers, in table order.
pub fn serializableInterfaces() []const []const u8 {
    return comptime blk: {
        var names: [entries.len][]const u8 = undefined;
        for (entries, 0..) |entry, i| names[i] = entry[0];
        const final = names;
        break :blk &final;
    };
}

/// One structured serialization's (or deserialization's) host state, handed
/// to V8's delegates as HostObjectSteps.data. It lives on the caller's stack
/// for the length of the call.
pub const Host = struct {
    /// For a deserialization, StructuredDeserialize's targetRealm: where new
    /// platform objects are made. For a serialization, the realm it runs in.
    realm: runtime.Context,
    /// The serialization steps' forStorage: true only for
    /// StructuredSerializeForStorage.
    for_storage: bool,
    /// For the records (released before the call returns).
    allocator: std.mem.Allocator,
    steps: ffi.HostObjectSteps = undefined,

    /// The delegates' view of this host. BORROWED: valid while `self` is.
    pub fn hostObjectSteps(self: *Host) *const ffi.HostObjectSteps {
        self.steps = .{ .write = &write, .read = &read, .data = self };
        return &self.steps;
    }
};

/// Throw a "DataCloneError" DOMException with a message naming `what`;
/// false/null for the delegate's "exception pending".
fn throwDataCloneError(comptime format: []const u8, args: anytype) void {
    var buffer: [256]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, format, args) catch "A value could not be cloned.";
    ffi.v8_ThrowDataCloneError(message.ptr, message.len);
}

/// A step's failure, thrown: an exception a step left pending stays; any
/// other is a DataCloneError naming the interface.
fn throwStepFailure(err: anyerror, comptime verb: []const u8, identifier: []const u8) void {
    switch (err) {
        error.ExceptionPending => {},
        else => throwDataCloneError("{s} object could not be " ++ verb ++ " ({s}).", .{ identifier, @errorName(err) }),
    }
}

/// HostObjectSteps.write: HTML StructuredSerializeInternal for a platform
/// object, from step 19 on (V8 has done steps 1-2 - memory - and 25).
fn write(data: ?*anyopaque, object: *ffi.Value, serializer: *ffi.ValueSerializer) callconv(.c) bool {
    const host: *Host = @ptrCast(@alignCast(data orelse return false));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return false;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return false;
    defer ffi.v8_Context_Dispose(context);

    const instance = conversions.fromV8Value(*runtime.Instance, host.allocator, isolate, context, object) catch {
        // Step 20 for an API object that is no platform object of ours.
        throwDataCloneError("An object could not be cloned.", .{});
        return false;
    };
    // Step 19.2: typeString is the identifier of value's PRIMARY interface -
    // the instance's own, not an ancestor's: a script subclass of File is
    // still a File, and a platform object whose primary interface is not
    // [Serializable] is not serializable even when an ancestor is.
    const type_string = instance.vtable.name;
    // Step 20: a platform object that is not a serializable object.
    const steps = stepsFor(type_string) orelse {
        throwDataCloneError("{s} object could not be cloned.", .{type_string});
        return false;
    };
    // Step 19.1 ([[Detached]]) concerns transferable platform objects; no
    // interface with steps here is [Transferable] yet.

    // Step 26.3: the serialization steps, given value, serialized and
    // forStorage.
    var serialized = runtime.SerializationRecord.init(host.allocator, host.for_storage);
    defer serialized.deinit();
    steps.serialize(instance, &serialized) catch |err| {
        throwStepFailure(err, "cloned", type_string);
        return false;
    };

    // Step 19.3: serialized.[[Type]] = typeString; then the steps' fields.
    ffi.v8_ValueSerializer_WriteUint32(serializer, record_format);
    ffi.v8_ValueSerializer_WriteUint32(serializer, @intCast(type_string.len));
    ffi.v8_ValueSerializer_WriteRawBytes(serializer, type_string.ptr, type_string.len);
    ffi.v8_ValueSerializer_WriteUint64(serializer, serialized.bytes.items.len);
    ffi.v8_ValueSerializer_WriteRawBytes(serializer, serialized.bytes.items.ptr, serialized.bytes.items.len);
    // The sub-serializations the steps asked for (BORROWED until now), each
    // StructuredSerializeInternal(subValue, forStorage, memory) on this same
    // serializer - so with the same memory as the rest of the graph.
    ffi.v8_ValueSerializer_WriteUint32(serializer, @intCast(serialized.sub_values.items.len));
    for (serialized.sub_values.items) |sub_value| {
        const handle = value_operations.ownHandle(isolate, context, sub_value) catch {
            throwDataCloneError("{s} object could not be cloned.", .{type_string});
            return false;
        };
        defer ffi.v8_Global_Dispose(handle);
        if (!ffi.v8_ValueSerializer_WriteValue(serializer, handle)) return false;
    }
    return true;
}

fn readUint32(deserializer: *ffi.ValueDeserializer) ?u32 {
    var value: u32 = 0;
    return if (ffi.v8_ValueDeserializer_ReadUint32(deserializer, &value)) value else null;
}

fn readUint64(deserializer: *ffi.ValueDeserializer) ?u64 {
    var value: u64 = 0;
    return if (ffi.v8_ValueDeserializer_ReadUint64(deserializer, &value)) value else null;
}

/// `length` raw bytes, BORROWED from the serialized data.
fn readRaw(deserializer: *ffi.ValueDeserializer, length: u64) ?[]const u8 {
    if (length == 0) return &.{};
    const n = std.math.cast(usize, length) orelse return null;
    var data: ?*const anyopaque = null;
    if (!ffi.v8_ValueDeserializer_ReadRawBytes(deserializer, n, &data)) return null;
    const bytes: [*]const u8 = @ptrCast(data orelse return null);
    return bytes[0..n];
}

/// HostObjectSteps.read: HTML StructuredDeserialize for a platform object,
/// from step 22 on (V8 does steps 1-2 and 23 - memory).
fn read(data: ?*anyopaque, deserializer: *ffi.ValueDeserializer) callconv(.c) ?*ffi.Value {
    const host: *Host = @ptrCast(@alignCast(data orelse return null));
    const malformed = "A platform object's serialized record is malformed.";
    if ((readUint32(deserializer) orelse 0) != record_format) {
        throwDataCloneError(malformed, .{});
        return null;
    }
    // Step 22.1: interfaceName = serialized.[[Type]].
    const name_length = readUint32(deserializer) orelse {
        throwDataCloneError(malformed, .{});
        return null;
    };
    const interface_name = readRaw(deserializer, name_length) orelse {
        throwDataCloneError(malformed, .{});
        return null;
    };
    // Step 22.2, for an interface this build cannot make.
    const steps = stepsFor(interface_name) orelse {
        throwDataCloneError("{s} object could not be deserialized.", .{interface_name});
        return null;
    };
    const fields_length = readUint64(deserializer) orelse {
        throwDataCloneError(malformed, .{});
        return null;
    };
    const fields = readRaw(deserializer, fields_length) orelse {
        throwDataCloneError(malformed, .{});
        return null;
    };
    const count = readUint32(deserializer) orelse {
        throwDataCloneError(malformed, .{});
        return null;
    };

    // The sub-deserializations, each StructuredDeserialize(subSerialized,
    // targetRealm, memory) on this same deserializer. OWNED here, BORROWED by
    // the steps.
    const sub_values = host.allocator.alloc(runtime.JSValue, count) catch {
        throwDataCloneError("{s} object could not be deserialized (out of memory).", .{interface_name});
        return null;
    };
    defer host.allocator.free(sub_values);
    var made: usize = 0;
    defer for (sub_values[0..made]) |sub_value| ffi.v8_Global_Dispose(value_operations.handleOf(sub_value));
    while (made < count) : (made += 1) {
        const value = ffi.v8_ValueDeserializer_ReadValue(deserializer) orelse return null;
        sub_values[made] = .{ .handle = .{ .ptr = @ptrCast(value) } };
    }

    // Steps 22.3 and 24.4: a new instance of the interface, created in
    // targetRealm, set up by its deserialization steps.
    var serialized: runtime.DeserializationRecord = .{ .bytes = fields, .sub_values = sub_values };
    const instance = steps.deserialize(&serialized, host.realm) catch |err| {
        throwStepFailure(err, "deserialized", interface_name);
        return null;
    };
    const generation = runtime.SlabAllocator.generationOf(instance);

    // Its wrapper, made in its relevant realm - targetRealm.
    const isolate = ffi.v8_Isolate_GetCurrent() orelse {
        instance.releaseIfUnwrapped(generation);
        return null;
    };
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        instance.releaseIfUnwrapped(generation);
        return null;
    };
    defer ffi.v8_Context_Dispose(context);
    const wrapper = value_operations.ownHandle(isolate, context, .{ .instance = instance }) catch {
        instance.releaseIfUnwrapped(generation);
        throwDataCloneError("{s} object could not be deserialized.", .{interface_name});
        return null;
    };
    if (!ffi.v8_Value_IsObject(wrapper)) {
        // Step 22.2: the interface has no interface object in targetRealm to
        // make an instance of - it is not exposed there.
        ffi.v8_Global_Dispose(wrapper);
        instance.releaseIfUnwrapped(generation);
        throwDataCloneError("{s} is not exposed in the target realm.", .{interface_name});
        return null;
    }
    log.debug("deserialized a {s}", .{interface_name});
    return wrapper;
}
