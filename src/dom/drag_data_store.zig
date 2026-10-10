//! HTML 6.11.2 "The drag data store": the structure a DataTransfer owns, and
//! the hooks its item list and items are made through.
//!
//! A DataTransfer, its DataTransferItemList and each DataTransferItem all
//! read and write one drag data store item list (HTML 6.11.3.1: "the drag
//! data store with which the DataTransferItemList object's DataTransfer
//! object is associated"). The store is per-DataTransfer data: DataTransfer
//! makes it in its constructor and frees it in its teardown. Neither the item
//! list nor an item may reach into DataTransfer's impl, and DataTransfer may
//! not set their state, so the store lives here, as a shared structure, and
//! the item list and item impls install how they are made already associated
//! with it - the same shape as `live_collections.zig`.
//!
//! Lifetime, as Blink has it: a DataTransferItemList and a DataTransferItem
//! each trace their DataTransfer (DataTransferItemList::Trace,
//! DataTransferItem::Trace visit data_transfer_), so the DataTransfer - and
//! with it the store - outlives every list and item script can reach. Here
//! the binding's [SameObject] edge back from `items` to its DataTransfer
//! (interface.zig, recordSameObjectEdge) and each item's own edge to its
//! DataTransfer do that. A list or item still checks its DataTransfer's
//! generation and realm (KeptInstance) before it touches the store: only the
//! teardown net, under which it reads as the spec's disabled mode.
//!
//! The DataTransfer keeps each file item's File alive by an edge of its own
//! (slot "item.<id>"), and its `files` FileList - one object, live, as
//! Blink's DataTransfer::files_ and WebKit's m_fileList are - is rebuilt in
//! place on every change to the item list (Blink's OnItemListChanged: clear,
//! then Append each File), through FileList's hook (`file_lists.zig`).
//!
//! lint-impls: hook for DataTransferItemList, DataTransferItem

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const process_start = @import("process_start.zig");
const file_lists = @import("file_lists.zig");
const KeptInstance = @import("custom_elements.zig").KeptInstance;

/// The drag data item kind.
pub const Kind = enum {
    text,
    file,

    /// DataTransferItem.kind's table: Text "string", File "file".
    pub fn name(self: Kind) []const u8 {
        return switch (self) {
            .text => "string",
            .file => "file",
        };
    }
};

/// The drag data store mode.
pub const Mode = enum { read_write, read_only, protected };

/// One entry of the drag data store item list.
pub const Item = struct {
    /// Stable for the item's life in its store: what a DataTransferItem names
    /// it by, so that one whose item was removed reads as disabled.
    id: u32,
    kind: Kind,
    /// The drag data item type string, ASCII lowercase. Owned.
    type_string: []u8,
    data: union(enum) {
        /// Owned.
        text: []u8,
        /// Kept by the DataTransfer's edge in slot "item.<id>".
        file: KeptInstance,
    },
    /// The DataTransferItem that represents this item, once one was asked
    /// for: "the same object must be returned each time a particular item is
    /// obtained" (6.11.3.1). Kept by the item list's edge.
    represented_by: ?KeptInstance = null,

    fn deinit(self: *Item, allocator: std.mem.Allocator) void {
        allocator.free(self.type_string);
        switch (self.data) {
            .text => |text| allocator.free(text),
            .file => {},
        }
    }
};

pub const Error = error{ OutOfMemory, NotSupportedError };

/// A drag data store. Owned by its DataTransfer (`owner`).
pub const Store = struct {
    allocator: std.mem.Allocator,
    /// The DataTransfer whose store this is: what keeps the Files alive.
    owner: *runtime.Instance,
    items: std.ArrayList(Item) = .empty,
    next_id: u32 = 0,
    mode: Mode,
    /// The DataTransfer's `files`, rebuilt in place on every change.
    files: ?KeptInstance = null,

    pub fn create(allocator: std.mem.Allocator, owner: *runtime.Instance, mode: Mode) error{OutOfMemory}!*Store {
        const store = try allocator.create(Store);
        store.* = .{ .allocator = allocator, .owner = owner, .mode = mode };
        return store;
    }

    /// Free the store with its DataTransfer. Its edges to Files are the
    /// owner's: ended here for an owner freed unwrapped; a collected owner's
    /// went with its wrapper.
    pub fn destroy(self: *Store) void {
        for (self.items.items) |*item| {
            if (item.data == .file) forgetFile(self.owner, item.id);
            item.deinit(self.allocator);
        }
        self.items.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn length(self: *const Store) usize {
        return self.items.items.len;
    }

    pub fn indexOf(self: *const Store, id: u32) ?usize {
        for (self.items.items, 0..) |item, index| if (item.id == id) return index;
        return null;
    }

    pub fn itemById(self: *Store, id: u32) ?*Item {
        const index = self.indexOf(id) orelse return null;
        return &self.items.items[index];
    }

    /// DataTransferItemList.add(data, type), step 2, a string: NotSupportedError
    /// when a text item of that type (ASCII lowercase) exists; otherwise a new
    /// text item at the end. The new item's id.
    pub fn addText(self: *Store, data: []const u8, type_string: []const u8) Error!u32 {
        const lowered = try std.ascii.allocLowerString(self.allocator, type_string);
        errdefer self.allocator.free(lowered);
        for (self.items.items) |item| {
            if (item.kind == .text and std.mem.eql(u8, item.type_string, lowered)) return error.NotSupportedError;
        }
        const text = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(text);
        const id = self.next_id;
        try self.items.append(self.allocator, .{ .id = id, .kind = .text, .type_string = lowered, .data = .{ .text = text } });
        self.next_id += 1;
        self.changed();
        return id;
    }

    /// DataTransferItemList.add(data), step 2, a File: a new file item whose
    /// type string is the File's type, ASCII lowercase, and whose data is the
    /// File. The new item's id.
    pub fn addFile(self: *Store, file: *runtime.Instance) Error!u32 {
        var file_type = interfaces.Blob.get_type(file) catch runtime.DOMString.initEmpty();
        defer file_type.deinit(file.ctx.allocator);
        const lowered = try std.ascii.allocLowerString(self.allocator, file_type.asSlice());
        errdefer self.allocator.free(lowered);
        const id = self.next_id;
        try self.items.append(self.allocator, .{ .id = id, .kind = .file, .type_string = lowered, .data = .{ .file = KeptInstance.of(file) } });
        self.next_id += 1;
        var buffer: [32]u8 = undefined;
        engine.traceChild(self.owner, file, itemSlot(&buffer, id));
        self.changed();
        return id;
    }

    /// Remove the item at `index` (it exists). Its DataTransferItem, if any,
    /// is now disabled; the caller ends the edge it drew to that object.
    pub fn removeAt(self: *Store, index: usize) void {
        var item = self.items.orderedRemove(index);
        if (item.data == .file) forgetFile(self.owner, item.id);
        item.deinit(self.allocator);
        self.changed();
    }

    /// The File of a file item, while it is the one kept.
    pub fn fileOf(item: *const Item) ?*runtime.Instance {
        return switch (item.data) {
            .file => |kept| kept.get(),
            .text => null,
        };
    }

    /// The DataTransfer's `files`, to rebuild on every change.
    pub fn setFiles(self: *Store, files: *runtime.Instance) void {
        self.files = KeptInstance.of(files);
        self.changed();
    }

    /// The drag data store item list changed: rebuild the DataTransfer's
    /// `files` in place - every file item's File, in order (6.11.3, the
    /// files getter's steps 1-5; Blink's DataTransfer::OnItemListChanged).
    /// The list is live and one object: script that holds it, or an input
    /// it was assigned to, sees the new contents.
    fn changed(self: *Store) void {
        const kept = self.files orelse return;
        const files = kept.get() orelse return;
        file_lists.clear(files) catch return;
        // Step 3: protected mode exposes no files.
        if (self.mode == .protected) return;
        for (self.items.items) |*item| {
            const file = fileOf(item) orelse continue;
            file_lists.append(files, file) catch return;
        }
    }
};

/// The DataTransfer's slot that keeps the File of item `id`.
fn itemSlot(buffer: []u8, id: u32) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "item.{d}", .{id}) catch unreachable };
}

fn forgetFile(owner: *runtime.Instance, id: u32) void {
    var buffer: [32]u8 = undefined;
    engine.forgetTracedChild(owner, itemSlot(&buffer, id));
}

// ============================================================================
// Hooks: the item list and items, made associated with a store
// ============================================================================

/// What DataTransferItemList supplies.
pub const ItemListSteps = struct {
    /// A new DataTransferItemList associated with `data_transfer` and its
    /// `store`, in `data_transfer`'s realm.
    make: *const fn (data_transfer: *runtime.Instance, store: *Store) anyerror!*runtime.Instance,
};

/// What DataTransferItem supplies.
pub const ItemSteps = struct {
    /// A new DataTransferItem representing item `id` of `store`, associated
    /// with `data_transfer`, in `data_transfer`'s realm.
    make: *const fn (data_transfer: *runtime.Instance, store: *Store, id: u32) anyerror!*runtime.Instance,
};

const Implementation = struct {
    item_list: ?ItemListSteps = null,
    item: ?ItemSteps = null,
};

// process-wide: hook table written once at process start by DataTransferItemList's and DataTransferItem's installHooks (B0); every store is its DataTransfer's own state
var implementation: Implementation = .{};

/// Called by DataTransferItemList's installHooks, once, at process start.
pub fn installItemList(steps: ItemListSteps) void {
    process_start.assertInstalling();
    implementation.item_list = steps;
}

/// Called by DataTransferItem's installHooks, once, at process start.
pub fn installItem(steps: ItemSteps) void {
    process_start.assertInstalling();
    implementation.item = steps;
}

pub fn makeItemList(data_transfer: *runtime.Instance, store: *Store) !*runtime.Instance {
    const steps = implementation.item_list orelse return error.NotSupported;
    return steps.make(data_transfer, store);
}

pub fn makeItem(data_transfer: *runtime.Instance, store: *Store, id: u32) !*runtime.Instance {
    const steps = implementation.item orelse return error.NotSupported;
    return steps.make(data_transfer, store, id);
}

test "with nothing installed, making an item list or an item reports NotSupported" {
    const saved = implementation;
    defer implementation = saved;
    implementation = .{};
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    var store: Store = .{ .allocator = std.testing.allocator, .owner = &object, .mode = .read_write };
    try std.testing.expectError(error.NotSupported, makeItemList(&object, &store));
    try std.testing.expectError(error.NotSupported, makeItem(&object, &store, 0));
}
