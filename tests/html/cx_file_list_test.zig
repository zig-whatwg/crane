//! FileList's contents and DataTransfer's file list (HTML 6.11.3, File API
//! 5.2), natively.
//!
//! - A FileList is filled and emptied only through FileList's hook
//!   (dom.file_lists), in place: it keeps its identity, as Blink's and
//!   WebKit's file inputs keep `files` on value = "" and reset.
//! - A FileList never frees a File: its Files are its wrapper's edges' to
//!   keep, and their own wrappers' to free. (It used to deinit every File it
//!   held, whoever owned it.)
//! - `new DataTransfer()`, `items.add(file)` and `files`: one live FileList,
//!   rebuilt in place on every change to the item list; the same
//!   DataTransferItem for an item every time; a removed item's object reads
//!   as disabled.
//!
//! Engine-free tests here; tests that need the collector are Crane tests
//! (tests/wpt/crane/cx-*), and the one that needs a native step script
//! cannot take runs on a Browser of its own thread.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const browser_mod = @import("browser");
const testing = std.testing;

const World = struct {
    ctx_data: runtime.ContextData,

    fn ctx(self: *World) runtime.Context {
        return &self.ctx_data;
    }
};

fn openWorld() !*World {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    const world = try testing.allocator.create(World);
    world.* = .{ .ctx_data = try runtime.ContextData.init(testing.allocator, .{}) };
    return world;
}

fn closeWorld(world: *World) void {
    world.ctx_data.deinit();
    testing.allocator.destroy(world);
    runtime.deinitializeRuntime();
}

fn isLive(instance: *runtime.Instance, generation: u64) bool {
    return runtime.SlabAllocator.generationOf(instance) == generation and !runtime.instance_lifecycle.isCleanedUp(instance);
}

test "a FileList appends and empties in place, and never frees its Files" {
    const world = try openWorld();
    defer closeWorld(world);
    const ctx = world.ctx();
    const a = try interfaces.File.init(testing.allocator, ctx);
    defer runtime.Instance.deinit(a);
    const b = try interfaces.File.init(testing.allocator, ctx);
    defer runtime.Instance.deinit(b);
    const a_generation = runtime.SlabAllocator.generationOf(a);
    const b_generation = runtime.SlabAllocator.generationOf(b);

    const list = try interfaces.FileList.init(testing.allocator, ctx);
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(list));
    try testing.expect((try interfaces.FileList.call_item(list, 0)) == null);
    // Emptying a list nothing was ever appended to (an input's empty
    // selection) does nothing.
    try dom.file_lists.clear(list);
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(list));

    try dom.file_lists.append(list, a);
    try dom.file_lists.append(list, b);
    try testing.expectEqual(@as(u32, 2), try interfaces.FileList.get_length(list));
    try testing.expectEqual(a, (try interfaces.FileList.call_item(list, 0)).?);
    try testing.expectEqual(b, (try interfaces.FileList.call_item(list, 1)).?);
    try testing.expect((try interfaces.FileList.call_item(list, 2)) == null);

    try dom.file_lists.clear(list);
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(list));
    try testing.expect((try interfaces.FileList.call_item(list, 0)) == null);
    try dom.file_lists.append(list, b);
    try testing.expectEqual(b, (try interfaces.FileList.call_item(list, 0)).?);

    runtime.Instance.deinit(list);
    try testing.expect(isLive(a, a_generation));
    try testing.expect(isLive(b, b_generation));
}

test "new DataTransfer(): items.add(File) puts the File in files, one live FileList" {
    const world = try openWorld();
    defer closeWorld(world);
    const ctx = world.ctx();
    const file = try interfaces.File.init(testing.allocator, ctx);
    defer runtime.Instance.deinit(file);
    const file_generation = runtime.SlabAllocator.generationOf(file);

    const dt = try interfaces.DataTransfer.call_constructor(ctx);
    {
        var drop = try interfaces.DataTransfer.get_dropEffect(dt);
        defer drop.deinit(testing.allocator);
        try testing.expectEqualStrings("none", drop.asSlice());
        var allowed = try interfaces.DataTransfer.get_effectAllowed(dt);
        defer allowed.deinit(testing.allocator);
        try testing.expectEqualStrings("none", allowed.asSlice());
    }
    const items = try interfaces.DataTransfer.get_items(dt);
    try testing.expectEqual(items, try interfaces.DataTransfer.get_items(dt));
    const files = try interfaces.DataTransfer.get_files(dt);
    try testing.expectEqual(files, try interfaces.DataTransfer.get_files(dt));
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(files));

    const item = (try interfaces.DataTransferItemList.call_add__1(items, file)).?;
    try testing.expectEqual(@as(u32, 1), try interfaces.DataTransferItemList.get_length(items));
    try testing.expectEqual(@as(u32, 1), try interfaces.FileList.get_length(files));
    try testing.expectEqual(file, (try interfaces.FileList.call_item(files, 0)).?);
    try testing.expectEqual(files, try interfaces.DataTransfer.get_files(dt));
    {
        var kind = try interfaces.DataTransferItem.get_kind(item);
        defer kind.deinit(testing.allocator);
        try testing.expectEqualStrings("file", kind.asSlice());
    }
    try testing.expectEqual(file, (try interfaces.DataTransferItem.call_getAsFile(item)).?);
    // The same object for the same item.
    try testing.expectEqual(item, try interfaces.DataTransferItemList.call_getter(items, 0));

    // A text item: not in files.
    const text = (try interfaces.DataTransferItemList.call_add(items, runtime.DOMString.initInterned("hello"), runtime.DOMString.initInterned("Text/Plain"))).?;
    try testing.expectEqual(@as(u32, 2), try interfaces.DataTransferItemList.get_length(items));
    try testing.expectEqual(@as(u32, 1), try interfaces.FileList.get_length(files));
    {
        var kind = try interfaces.DataTransferItem.get_kind(text);
        defer kind.deinit(testing.allocator);
        try testing.expectEqualStrings("string", kind.asSlice());
        var item_type = try interfaces.DataTransferItem.get_type(text);
        defer item_type.deinit(testing.allocator);
        try testing.expectEqualStrings("text/plain", item_type.asSlice());
    }
    try testing.expect((try interfaces.DataTransferItem.call_getAsFile(text)) == null);
    try testing.expectError(error.NotSupportedError, interfaces.DataTransferItemList.call_add(items, runtime.DOMString.initInterned("again"), runtime.DOMString.initInterned("text/plain")));

    // Removing the file item empties files in place, and disables its object.
    try interfaces.DataTransferItemList.call_remove(items, 0);
    try testing.expectEqual(@as(u32, 1), try interfaces.DataTransferItemList.get_length(items));
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(files));
    try testing.expectEqual(files, try interfaces.DataTransfer.get_files(dt));
    {
        var kind = try interfaces.DataTransferItem.get_kind(item);
        defer kind.deinit(testing.allocator);
        try testing.expectEqualStrings("", kind.asSlice());
    }
    try testing.expect((try interfaces.DataTransferItem.call_getAsFile(item)) == null);
    // Out of range: nothing happens.
    try interfaces.DataTransferItemList.call_remove(items, 5);

    // The same File twice is two items, and two entries in files.
    _ = try interfaces.DataTransferItemList.call_add__1(items, file);
    _ = try interfaces.DataTransferItemList.call_add__1(items, file);
    try testing.expectEqual(@as(u32, 2), try interfaces.FileList.get_length(files));
    try interfaces.DataTransferItemList.call_clear(items);
    try testing.expectEqual(@as(u32, 0), try interfaces.DataTransferItemList.get_length(items));
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(files));

    // The DataTransfer frees its store, its list and its items (engine-free:
    // no wrapper owns them), and never the File.
    runtime.Instance.deinit(dt);
    try testing.expect(isLive(file, file_generation));
}

// The store links no engine here: its text items draw no edge.
test "a drag data store's text items: lowercase types, one per type, ids stable across removal" {
    var object: runtime.Instance = undefined;
    const store = try dom.drag_data_store.Store.create(testing.allocator, &object, .read_write);
    defer store.destroy();
    const a = try store.addText("one", "Text/Plain");
    const b = try store.addText("two", "text/html");
    try testing.expectError(error.NotSupportedError, store.addText("again", "TEXT/PLAIN"));
    try testing.expectEqual(@as(usize, 2), store.length());
    try testing.expectEqualStrings("text/plain", store.itemById(a).?.type_string);
    store.removeAt(store.indexOf(a).?);
    try testing.expect(store.itemById(a) == null);
    try testing.expectEqual(@as(usize, 0), store.indexOf(b).?);
    // A removed item's type is free again, and gets a new id.
    const c = try store.addText("three", "text/plain");
    try testing.expect(c != a);
}

test "dropEffect and effectAllowed take only their values" {
    const world = try openWorld();
    defer closeWorld(world);
    const dt = try interfaces.DataTransfer.call_constructor(world.ctx());
    defer runtime.Instance.deinit(dt);
    const cases = .{
        .{ "copy", "copy" }, .{ "bogus", "copy" }, .{ "COPY", "copy" }, .{ "move", "move" }, .{ "link", "link" }, .{ "none", "none" },
    };
    inline for (cases) |case| {
        try interfaces.DataTransfer.set_dropEffect(dt, runtime.DOMString.initInterned(case[0]));
        var value = try interfaces.DataTransfer.get_dropEffect(dt);
        defer value.deinit(testing.allocator);
        try testing.expectEqualStrings(case[1], value.asSlice());
    }
    const allowed = .{
        .{ "copyMove", "copyMove" }, .{ "all", "all" }, .{ "nope", "all" }, .{ "uninitialized", "uninitialized" }, .{ "linkMove", "linkMove" },
    };
    inline for (allowed) |case| {
        try interfaces.DataTransfer.set_effectAllowed(dt, runtime.DOMString.initInterned(case[0]));
        var value = try interfaces.DataTransfer.get_effectAllowed(dt);
        defer value.deinit(testing.allocator);
        try testing.expectEqualStrings(case[1], value.asSlice());
    }
}

// ----------------------------------------------------------------------------
// With an engine: the edges
// ----------------------------------------------------------------------------

fn counter(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    return error.NoSuchCounter;
}

fn platformObject(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const held = try browser.evaluateScript(source);
    defer held.release();
    return engine.convertToPlatformObject(realm, held.value) orelse error.NotAPlatformObject;
}

fn holds(browser: *browser_mod.Browser, source: []const u8) !bool {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const held = try browser.evaluateScript(source);
    defer held.release();
    return engine.toBoolean(realm, held.value);
}

fn collect(browser: *browser_mod.Browser) !void {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    for (0..3) |_| try engine.runInRealm(realm, Collect.steps, agent);
}

fn unwrappedListLetsItsHoldsGo() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    // Files script made and still holds: wrapped before the list exists.
    const a = try platformObject(browser, "globalThis.fa = new File(['a'], 'a.txt'); fa");
    const b = try platformObject(browser, "globalThis.fb = new File(['b'], 'b.txt'); fb");
    const before = try counter("live_object_globals");
    for (0..8) |_| {
        const list = try interfaces.FileList.init(testing.allocator, realm);
        try dom.file_lists.append(list, a);
        try dom.file_lists.append(list, b);
        try dom.file_lists.clear(list);
        try dom.file_lists.append(list, a);
        try testing.expect(!engine.hasWrapper(list));
        list.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(list));
    }
    const after = try counter("live_object_globals");
    if (after != before) std.debug.print("live object globals {d} -> {d} after 8 unwrapped lists\n", .{ before, after });
    try testing.expectEqual(before, after);
    try testing.expect(try holds(browser, "fa.name === 'a.txt' && fb.name === 'b.txt'"));
}

fn storeKeepsFilesTheListNoLongerHolds() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    // Only the DataTransfer is kept; its files list is emptied in place, as
    // an input sharing it does on value = "" (Blink's
    // FileInputType::SetValue clears that same object).
    const files = try platformObject(browser,
        \\globalThis.dt = new DataTransfer();
        \\(() => { const f = new File(['body'], 'kept.txt'); f.cx = 'kept'; globalThis.item = dt.items.add(f); })();
        \\dt.files
    );
    try testing.expectEqual(@as(u32, 1), try interfaces.FileList.get_length(files));
    try dom.file_lists.clear(files);
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(files));
    try collect(browser);
    // The store still holds the File, by the DataTransfer's own edge.
    try testing.expect(try holds(browser, "dt.items.length === 1 && item.getAsFile() !== null && item.getAsFile().cx === 'kept' && dt.files.length === 0"));
    // The next change to the item list rebuilds files with it.
    try testing.expect(try holds(browser, "dt.items.add('x', 'text/plain'); dt.files.length === 1 && dt.files[0].cx === 'kept'"));
}

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                std.debug.print("fixture failed: {s}\n", .{@errorName(err)});
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "an unwrapped FileList lets the holds on its Files go" {
    try onThread(unwrappedListLetsItsHoldsGo);
}

test "a DataTransfer keeps a File its emptied files list no longer holds" {
    try onThread(storeKeepsFilesTheListNoLongerHolds);
}
