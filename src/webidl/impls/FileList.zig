//! Implementation for FileList interface
//!
//! W3C File API: https://w3c.github.io/FileAPI/#filelist-section
//!
//! ```idl
//! [Exposed=(Window,Worker), Serializable]
//! interface FileList {
//!   getter File? item(unsigned long index);
//!   readonly attribute unsigned long length;
//! };
//! ```
//!
//! A FileList is read-only to script, and its contents are set natively: an
//! input's selected files (HTML 4.10.5.1.18), a DataTransfer's files (HTML
//! 6.11.3). Both browsers that share a list between owners empty it IN PLACE
//! rather than replacing it - Blink's FileInputType::SetValue does
//! `file_list_->clear()`, WebKit's FileInputType::setValue `files()->clear()`
//! - and Blink's DataTransfer rebuilds its one `files_` in place on every
//! item-list change (OnItemListChanged: clear, then Append each File). Those
//! steps have no IDL member, so FileList installs them as a hook
//! (dom.file_lists) for the input and DataTransfer impls to call.
//!
//! Lifetime. A FileList keeps its Files alive the browsers' way: Blink's
//! FileList holds `HeapVector<Member<File>> files_`, traced (FileList::Trace).
//! Here each File is held by an edge from the list's wrapper
//! (engine.traceChild, one slot per index: "file.<i>"), drawn when the File
//! is appended and ended when the list is emptied. The list never frees a
//! File: a File's lifetime is its wrapper's, and a File made natively in an
//! engine-free test is its maker's to free. The pointer kept beside each edge
//! carries the File's slab generation and realm (KeptInstance): only the
//! teardown net, so a File a realm's teardown freed reads as absent, never
//! as a freed or reissued object.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const KeptInstance = dom.custom_elements.KeptInstance;
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const FileList = interfaces.FileList;

pub const State = FileList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// The list's Files, in order. Made on the first append: a list nothing was
/// ever appended to (an input's empty selection) has none, and reads as
/// empty.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Each File, kept by the edge in slot "file.<index>".
    files: std.ArrayList(KeptInstance) = .empty,
};

/// The slot that keeps the File at `index`: Blink's `files_[index]`.
fn fileSlot(buffer: []u8, index: usize) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "file.{d}", .{index}) catch unreachable };
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

/// Deinitialize instance: the list's own storage, never its Files. A list
/// freed without ever being wrapped lets the holds waiting for its wrapper
/// go; a collected one's edges went with the wrapper.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    forgetEdges(instance, 0, internal.files.items.len);
    internal.files.deinit(internal.allocator);
    internal.allocator.destroy(internal);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// The process-wide hook: FileList's steps with no IDL member.
pub fn installHooks() void {
    dom.file_lists.install(.{ .clear = &clear, .append = &append });
}

const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

fn ensureInternal(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidState;
    if (state.own._internal) |internal| return internal;
    const allocator = instance.ctx.allocator;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return internal;
}

/// End the edges in slots [from, to).
fn forgetEdges(instance: *runtime.Instance, from: usize, to: usize) void {
    for (from..to) |index| {
        var buffer: [32]u8 = undefined;
        engine.forgetTracedChild(instance, fileSlot(&buffer, index));
    }
}

/// dom.file_lists.clear: empty `list` in place. It keeps its identity - an
/// input's `files` and a DataTransfer's `files` stay the same object - and
/// lets go of the edges to the Files it held.
fn clear(list: *runtime.Instance) void {
    const internal = getInternal(list) orelse return;
    const count = internal.files.items.len;
    internal.files.clearRetainingCapacity();
    forgetEdges(list, 0, count);
}

/// dom.file_lists.append: add `file` at the end of `list`, and keep it.
fn append(list: *runtime.Instance, file: *runtime.Instance) error{ OutOfMemory, InvalidState }!void {
    const internal = try ensureInternal(list);
    const index = internal.files.items.len;
    try internal.files.append(internal.allocator, KeptInstance.of(file));
    var buffer: [32]u8 = undefined;
    engine.traceChild(list, file, fileSlot(&buffer, index));
}

/// Getter for length
///
/// Spec: https://w3c.github.io/FileAPI/#dfn-length
/// "must return the number of files in the FileList object. If there are no
/// files, this attribute must return 0."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.files.items.len);
}

/// Operation: item
///
/// Spec: https://w3c.github.io/FileAPI/#dfn-item
/// "must return the indexth File object in the FileList. If there is no
/// indexth File object in the FileList, then this method must return null."
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    if (index >= internal.files.items.len) return null;
    return internal.files.items[index].get();
}
