//! HTML 2.7 transferable objects: the transfer steps and transfer-receiving
//! steps of every transferable platform object Crane has - MessagePort (HTML
//! 9.4.3), ReadableStream, WritableStream and TransformStream (Streams
//! 4.2.6, 5.2.5, 6.2.5), ImageBitmap (HTML 8.11.2) and OffscreenCanvas (HTML
//! 4.12.5.3) - as ONE step that every carrier of a transfer list
//! runs: a MessagePort's postMessage, a Worker's and a worker global's, a
//! Window's, a service worker's and a client's, and structuredClone.
//!
//! - StructuredSerializeWithTransfer (2.7.8): the engine serializes the value
//!   and hands back the transfer list's platform objects in order
//!   (runtime.SerializedWithTransfer.platform_objects); step 5.5 is then
//!   `transferAll` - each object's transfer steps, in order, each making its
//!   data holder (dom.port_channels.TransferDataHolder), which travels in the
//!   message, to any thread.
//! - StructuredDeserializeWithTransfer (2.7.9): step 3 is `receiveAll` - each
//!   holder's transfer-receiving steps in the receiving realm, in order -
//!   whose objects the engine then puts in memory for the value's references
//!   (step 3.5); MessageEvent's ports are the MessagePorts among them (HTML
//!   9.4.4 step 7.6: "all MessagePort objects in [[TransferredValues]]") -
//!   never a stream's own port, which only its cross-realm transform holds.
//!
//! Which objects a carrier may transfer is `transferableState` (HTML 2.7.8
//! steps 2.1 and 5.2), the TransferableCheck every carrier gives the engine.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const message_ports = @import("message_ports.zig");
const port_channels = @import("port_channels.zig");
const streams_transfer = @import("streams_transfer.zig");
const image_bitmaps = @import("image_bitmaps.zig");

pub const TransferDataHolder = port_channels.TransferDataHolder;

/// Whether `instance` is a transferable platform object (StructuredSerialize-
/// WithTransfer step 2.1: it has a [[Detached]] internal slot), and a
/// MessagePort whose [[Detached]] is already true (step 5.2, which the
/// engine asks at step 2 for ports). A stream's [[Detached]] is asked by
/// `transfer`, at step 5.2's place.
pub fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    const port = message_ports.transferableState(instance);
    if (port != .not_transferable) return port;
    const bitmap = image_bitmaps.transferableState(instance);
    if (bitmap != .not_transferable) return bitmap;
    return streams_transfer.transferableState(instance);
}

/// The TransferableCheck of a carrier whose transfer list may hold any
/// transferable platform object.
pub fn check(_: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    return transferableState(instance);
}

/// StructuredSerializeWithTransfer steps 5.2-5.6 for one platform object of
/// a transfer list, in `realm` - the current realm, where a stream's
/// transfer steps make their ports, cross-realm transform and pipe. A
/// DataCloneError is error.DataCloneError (thrown by the caller's binding);
/// anything else the steps throw is pending.
pub fn transfer(realm: runtime.Context, instance: *runtime.Instance) !TransferDataHolder {
    if (message_ports.transferableState(instance) != .not_transferable) {
        // 5.2: a port detached already is refused before the steps.
        if (message_ports.transferableState(instance) == .detached) return error.DataCloneError;
        // 5.5: the MessagePort transfer steps ship its end; 5.6 its
        // [[Detached]] is set by them.
        const end = message_ports.ship(instance) orelse return error.DataCloneError;
        return .{ .message_port = @ptrCast(@alignCast(end)) };
    }
    // An ImageBitmap's or OffscreenCanvas's transfer steps (5.2's refusal
    // of a detached one included).
    if (try image_bitmaps.transfer(instance)) |holder| return switch (holder) {
        .image_bitmap => |bitmap| .{ .image_bitmap = bitmap },
        .offscreen_canvas => |canvas| .{ .offscreen_canvas = canvas },
    };
    return streams_transfer.transfer(realm, instance);
}

/// StructuredSerializeWithTransfer step 5's loop over the transfer list's
/// platform objects (`objects`, in transfer-list order): their data holders,
/// in the same order. OWNED slice (`allocator`); each holder is the caller's
/// to put in a message or discard. On an error the holders made so far are
/// discarded - the objects whose transfer steps ran stay detached, as the
/// spec leaves them when a later step throws.
pub fn transferAll(realm: runtime.Context, objects: []const *runtime.Instance, allocator: Allocator) ![]TransferDataHolder {
    const holders = try allocator.alloc(TransferDataHolder, objects.len);
    var made: usize = 0;
    errdefer {
        for (holders[0..made]) |holder| holder.discard();
        allocator.free(holders);
    }
    for (objects) |instance| {
        holders[made] = try transfer(realm, instance);
        made += 1;
    }
    return holders;
}

/// The transfer-receiving steps of `holder` in `realm` (StructuredDeserialize-
/// WithTransfer step 3.4.4): a new object of `realm`. The holder is taken,
/// also on failure.
pub fn receive(realm: runtime.Context, holder: TransferDataHolder) !*runtime.Instance {
    return switch (holder) {
        .message_port => |end| message_ports.receive(realm, end),
        .readable_stream => |end| streams_transfer.receiveReadable(realm, end),
        .writable_stream => |end| streams_transfer.receiveWritable(realm, end),
        .transform_stream => |sides| streams_transfer.receiveTransform(realm, sides.readable, sides.writable),
        .image_bitmap => |bitmap| image_bitmaps.receiveImageBitmap(realm, bitmap),
        .offscreen_canvas => |canvas| image_bitmaps.receiveOffscreenCanvas(realm, canvas),
    };
}

/// What `receiveAll` made of a message's data holders.
pub const Received = struct {
    allocator: Allocator,
    /// The transferred objects, as their transfer-receiving steps made them
    /// in the receiving realm, in transfer-list order: the engine's
    /// `transferred` for the value's references.
    values: []*runtime.Instance,
    /// The slab generation of each object in `values`, captured as
    /// `receiveAll` made it: `deinit` releases any object that stayed
    /// unwrapped (neither referenced by the deserialized payload nor kept in
    /// `MessageEvent.ports`, or left behind when deserialization threw), while
    /// never touching a slot that script wrapped and the collector later reused.
    generations: []u64,
    /// The MessagePorts among them, in order: MessageEvent's ports.
    ports: []*runtime.Instance,

    pub fn deinit(self: *Received) void {
        for (self.values, self.generations) |object, generation| {
            object.releaseIfUnwrapped(generation);
        }
        self.allocator.free(self.values);
        self.allocator.free(self.generations);
        self.allocator.free(self.ports);
        self.* = undefined;
    }
};

/// StructuredDeserializeWithTransfer step 3 for every data holder of a
/// message, in `realm`: each holder is taken - received, or discarded when
/// an earlier one failed. A failure (step 3.4.4 threw) is error.DataCloneError
/// once nothing made here is left behind: an object no script saw is let go
/// at once, and a stream - wrapped as it is made - is the collector's.
/// `holders` stays the caller's slice to free.
pub fn receiveAll(realm: runtime.Context, holders: []const TransferDataHolder, allocator: Allocator) !Received {
    const values = try allocator.alloc(*runtime.Instance, holders.len);
    const generations = allocator.alloc(u64, holders.len) catch |err| {
        allocator.free(values);
        return err;
    };
    var made: usize = 0;
    var port_count: usize = 0;
    var failed = false;
    for (holders) |holder| {
        if (failed) {
            holder.discard();
            continue;
        }
        const object = receive(realm, holder) catch {
            failed = true;
            continue;
        };
        values[made] = object;
        generations[made] = runtime.SlabAllocator.generationOf(object);
        made += 1;
        if (holder == .message_port) port_count += 1;
    }
    if (failed) {
        for (values[0..made], generations[0..made]) |object, generation| object.releaseIfUnwrapped(generation);
        allocator.free(generations);
        allocator.free(values);
        return error.DataCloneError;
    }
    const ports = allocator.alloc(*runtime.Instance, port_count) catch |err| {
        for (values, generations) |object, generation| object.releaseIfUnwrapped(generation);
        allocator.free(generations);
        allocator.free(values);
        return err;
    };
    var next: usize = 0;
    for (holders, values) |holder, object| {
        if (holder != .message_port) continue;
        ports[next] = object;
        next += 1;
    }
    return .{ .allocator = allocator, .values = values, .generations = generations, .ports = ports };
}
