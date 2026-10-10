//! Implementation for DataTransferItemList interface
//!
//! Spec: HTML 6.11.3.1 The DataTransferItemList interface
//! https://html.spec.whatwg.org/multipage/dnd.html#the-datatransferitemlist-interface
//!
//! ```idl
//! [Exposed=Window]
//! interface DataTransferItemList {
//!   readonly attribute unsigned long length;
//!   getter DataTransferItem (unsigned long index);
//!   DataTransferItem? add(DOMString data, DOMString type);
//!   DataTransferItem? add(File data);
//!   undefined remove(unsigned long index);
//!   undefined clear();
//! };
//! ```
//!
//! Made by its DataTransfer, associated with that object's drag data store
//! (dom.drag_data_store), through the hook this impl installs. Its mode is
//! the store's while its DataTransfer is associated with it - always, for a
//! constructed DataTransfer - and the disabled mode otherwise; here that is
//! also what a list reads as past its DataTransfer's teardown (the
//! KeptInstance net: the binding's [SameObject] edge back from `items` keeps
//! the DataTransfer alive while script holds the list).
//!
//! "The same object must be returned each time a particular item is
//! obtained": the list keeps each DataTransferItem it hands out by an edge
//! (slot "item.<id>") and the store records which object represents which
//! item. Gecko (DataTransferItemList::mItems) and WebKit
//! (DataTransferItemList::m_items) return the same object; Blink makes a new
//! DataTransferItem on every index (DataTransferItemList::item) - the
//! majority and the spec text agree.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const engine = @import("engine");
const dom = @import("dom");
const drag_data_store = dom.drag_data_store;
const KeptInstance = dom.custom_elements.KeptInstance;
const DataTransferItemList = interfaces.DataTransferItemList;

pub const State = DataTransferItemList.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The DataTransfer whose store this list reads: checked before `store`
    /// is touched (the teardown net).
    data_transfer: KeptInstance,
    store: *drag_data_store.Store,
    /// Whether the edges to the DataTransferItems it made are drawn (an
    /// engine): then their wrappers own them. Engine-free, this list frees
    /// the ones it made (`made`).
    traced: bool,
    made: std.ArrayList(*runtime.Instance) = .empty,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The store, unless the list is in the disabled mode.
fn storeOf(instance: *runtime.Instance) ?*drag_data_store.Store {
    const internal = getInternal(instance) orelse return null;
    _ = internal.data_transfer.get() orelse return null;
    return internal.store;
}

fn itemSlot(buffer: []u8, id: u32) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "item.{d}", .{id}) catch unreachable };
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance. Never touches the store: its DataTransfer may
/// have been torn down first.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    if (!internal.traced) {
        for (internal.made.items) |item| runtime.Instance.deinit(item);
    }
    internal.made.deinit(internal.allocator);
    internal.allocator.destroy(internal);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The process-wide hook: how a DataTransfer makes its item list.
pub fn installHooks() void {
    drag_data_store.installItemList(.{ .make = &make });
}

/// drag_data_store.makeItemList: a list associated with `data_transfer` and
/// its store, in its realm.
fn make(data_transfer: *runtime.Instance, store: *drag_data_store.Store) anyerror!*runtime.Instance {
    const ctx = data_transfer.ctx;
    const instance = try interfaces.DataTransferItemList.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{
        .allocator = ctx.allocator,
        .data_transfer = KeptInstance.of(data_transfer),
        .store = store,
        .traced = ctx.hasEngine(),
    };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// "Determine the value of an indexed property" `index`: the
/// DataTransferItem representing that item - the same object every time.
fn itemObject(instance: *runtime.Instance, store: *drag_data_store.Store, index: usize) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const item = &store.items.items[index];
    if (item.represented_by) |kept| if (kept.get()) |object| return object;
    const data_transfer = internal.data_transfer.get() orelse return error.InvalidStateError;
    const object = try drag_data_store.makeItem(data_transfer, store, item.id);
    if (internal.traced) {
        var buffer: [32]u8 = undefined;
        engine.traceChild(instance, object, itemSlot(&buffer, item.id));
    } else {
        internal.made.append(internal.allocator, object) catch |err| {
            runtime.Instance.deinit(object);
            return err;
        };
    }
    // `item` is still the store's entry: nothing above changes the list.
    item.represented_by = KeptInstance.of(object);
    return object;
}

/// The item `id` is gone: the list stops keeping its DataTransferItem
/// (which reads as disabled from now on).
fn forgetItem(instance: *runtime.Instance, id: u32) void {
    const internal = getInternal(instance) orelse return;
    if (!internal.traced) return;
    var buffer: [32]u8 = undefined;
    engine.forgetTracedChild(instance, itemSlot(&buffer, id));
}

/// Getter for length: "must return zero if the object is in the disabled
/// mode; otherwise it must return the number of items in the drag data store
/// item list."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const store = storeOf(instance) orelse return 0;
    return @intCast(store.length());
}

/// Indexed getter: the supported property indices are the store's item
/// indices when not disabled.
pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    const store = storeOf(instance) orelse return error.IndexSizeError;
    if (index >= store.length()) return error.IndexSizeError;
    return itemObject(instance, store, index);
}

/// Operation: add(data, type), a string.
pub fn call_add(instance: *runtime.Instance, data: runtime.DOMString, @"type": runtime.DOMString) anyerror!?*runtime.Instance {
    // 1. If the DataTransferItemList object is not in the read/write mode,
    //    return null.
    const store = storeOf(instance) orelse return null;
    if (store.mode != .read_write) return null;
    // 2. If there is already a text item of that type (ASCII lowercase),
    //    throw a "NotSupportedError" DOMException; otherwise add one.
    const id = try store.addText(data.asSlice(), @"type".asSlice());
    // 3. Determine the value of the indexed property for the new item.
    return try itemObject(instance, store, store.indexOf(id).?);
}

/// Operation: add(data), a File.
pub fn call_add__1(instance: *runtime.Instance, data: *runtime.Instance) anyerror!?*runtime.Instance {
    // WebIDL: the argument converts to a File, and a Blob that is not one is
    // a TypeError. The binding's overload resolution let a Blob through to
    // this overload; refuse it here (the defence Codex's input files setter
    // takes for its FileList, CE2-M1).
    if (data.stateAs(interfaces.File.State) == null) return error.TypeError;
    // 1. If the DataTransferItemList object is not in the read/write mode,
    //    return null.
    const store = storeOf(instance) orelse return null;
    if (store.mode != .read_write) return null;
    // 2. Add a file item whose type string is the File's type, ASCII
    //    lowercase, and whose data is the File's.
    const id = try store.addFile(data);
    // 3. Determine the value of the indexed property for the new item.
    return try itemObject(instance, store, store.indexOf(id).?);
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance, index: u32) anyerror!void {
    // 1. If the DataTransferItemList object is not in the read/write mode,
    //    throw an "InvalidStateError" DOMException.
    const store = storeOf(instance) orelse return error.InvalidStateError;
    if (store.mode != .read_write) return error.InvalidStateError;
    // 2. If the drag data store does not contain an indexth item, then return.
    if (index >= store.length()) return;
    // 3. Remove the indexth item from the drag data store.
    const id = store.items.items[index].id;
    store.removeAt(index);
    forgetItem(instance, id);
}

/// Operation: clear: "if the DataTransferItemList object is in the
/// read/write mode, must remove all the items from the drag data store.
/// Otherwise, it must do nothing."
pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    const store = storeOf(instance) orelse return;
    if (store.mode != .read_write) return;
    while (store.length() > 0) {
        const index = store.length() - 1;
        const id = store.items.items[index].id;
        store.removeAt(index);
        forgetItem(instance, id);
    }
}
