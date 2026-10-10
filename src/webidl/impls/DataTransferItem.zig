//! Implementation for DataTransferItem interface
//!
//! Spec: HTML 6.11.3.2 The DataTransferItem interface
//! https://html.spec.whatwg.org/multipage/dnd.html#the-datatransferitem-interface
//!
//! ```idl
//! [Exposed=Window]
//! interface DataTransferItem {
//!   readonly attribute DOMString kind;
//!   readonly attribute DOMString type;
//!   undefined getAsString(FunctionStringCallback? _callback);
//!   File? getAsFile();
//! };
//! ```
//!
//! Represents one item of its DataTransfer's drag data store, named by the
//! item's id (dom.drag_data_store): while the store still holds that item
//! (and its DataTransfer is associated with the store - always, for a
//! constructed one), the item's mode is the store's; once the item is
//! removed, it is in the disabled mode. Made by the item list through the
//! hook this impl installs.
//!
//! The item keeps its DataTransfer alive - and with it the store - by an
//! edge (slot "dataTransfer"), as Blink's DataTransferItem::Trace visits
//! data_transfer_. The KeptInstance beside it is only the teardown net.

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
const DataTransferItem = interfaces.DataTransferItem;

pub const State = DataTransferItem.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    data_transfer: KeptInstance,
    store: *drag_data_store.Store,
    /// The store item this object represents.
    id: u32,
};

const data_transfer_slot: engine.TracedSlot = .{ .name = "dataTransfer" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The store and the item this object represents, unless it is in the
/// disabled mode: its DataTransfer gone (the teardown net), or the item
/// removed from the store.
fn representedItem(instance: *runtime.Instance) ?struct { store: *drag_data_store.Store, item: *drag_data_store.Item } {
    const internal = getInternal(instance) orelse return null;
    _ = internal.data_transfer.get() orelse return null;
    const item = internal.store.itemById(internal.id) orelse return null;
    return .{ .store = internal.store, .item = item };
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
/// have been torn down first. An item freed unwrapped lets the hold on its
/// DataTransfer that waited for its wrapper go.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    engine.forgetTracedChild(instance, data_transfer_slot);
    internal.allocator.destroy(internal);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The process-wide hook: how an item list makes the object for an item.
pub fn installHooks() void {
    drag_data_store.installItem(.{ .make = &make });
}

/// drag_data_store.makeItem: the object representing item `id` of `store`,
/// "associated with the same DataTransfer object as the
/// DataTransferItemList object when it is first created".
fn make(data_transfer: *runtime.Instance, store: *drag_data_store.Store, id: u32) anyerror!*runtime.Instance {
    const ctx = data_transfer.ctx;
    const instance = try interfaces.DataTransferItem.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{ .allocator = ctx.allocator, .data_transfer = KeptInstance.of(data_transfer), .store = store, .id = id };
    instance.getState(State).own._internal = internal;
    // The DataTransfer already has its wrapper: script reached this item
    // through its `items`.
    engine.traceChild(instance, data_transfer, data_transfer_slot);
    return instance;
}

/// Getter for kind: the empty string in the disabled mode; otherwise
/// "string" for a text item and "file" for a file item.
pub fn get_kind(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const found = representedItem(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(found.item.kind.name());
}

/// Getter for type: the empty string in the disabled mode; otherwise the
/// drag data item type string.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const found = representedItem(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, found.item.type_string);
}

/// Operation: getAsString
pub fn call_getAsString(instance: *runtime.Instance, _callback: ?callbacks.FunctionStringCallback) anyerror!void {
    _ = instance;
    _ = _callback;
    return error.NotImplemented;
}

/// Operation: getAsFileSystemHandle
pub fn call_getAsFileSystemHandle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: webkitGetAsEntry
pub fn call_webkitGetAsEntry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: getAsFile.
///
/// Deviation (golden rule 2): step 3 says "a new File object representing
/// the actual data"; all three browsers return the File that was added, the
/// same object each time - Blink's DataObjectItem::GetAsFile returns its
/// `file_` for an internal source, WebKit's DataTransferItem::getAsFile its
/// `m_file`, Gecko's DataTransferItem::GetAsFile the stored Blob's
/// ToFile(), which is the Blob itself when it is a File.
pub fn call_getAsFile(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // 1. If the DataTransferItem object is not in the read/write mode or the
    //    read-only mode, then return null.
    const found = representedItem(instance) orelse return null;
    if (found.store.mode == .protected) return null;
    // 2. If the drag data item kind is not File, then return null.
    // 3. Return the File.
    return drag_data_store.Store.fileOf(found.item);
}
