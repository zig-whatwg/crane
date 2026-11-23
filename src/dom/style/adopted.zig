//! adoptedStyleSheets (CSSOM 6.2.3): a Document's or ShadowRoot's
//! ObservableArray<CSSStyleSheet>, whose backing list - in array order -
//! ends the "final CSS style sheets". The array is the engine's; its owner
//! (Document, ShadowRoot) keeps a view of its backing list as the style
//! sheets' records (`AdoptedSheets`), which the array's `changed` hook keeps
//! current and the style engine reads with no engine call at style time.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#dom-documentorshadowroot-adoptedstylesheets

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const sheet_mod = @import("sheet.zig");
const hooks = @import("hooks.zig");
const NodeBase = @import("../node_base.zig").NodeBase;
const instance_bridge = @import("../instance_bridge.zig");
const inspector_probes = @import("../inspector_probes.zig");

const SheetRecord = sheet_mod.SheetRecord;

/// The records of a DocumentOrShadowRoot's adoptedStyleSheets, in order,
/// each held. Its owner's state embeds it.
pub const AdoptedSheets = struct {
    allocator: std.mem.Allocator,
    records: std.ArrayList(*SheetRecord) = .empty,
    /// The same sheets as the objects script sees, by name (address and
    /// slab generation; never a hold): CDP's DOM agents report them by
    /// their styleSheetIds (`sheetsOf`).
    sheets: std.ArrayList(Sheet) = .empty,

    pub fn init(allocator: std.mem.Allocator) AdoptedSheets {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *AdoptedSheets) void {
        for (self.records.items) |r| r.unref();
        self.records.deinit(self.allocator);
        self.records = .empty;
        self.sheets.deinit(self.allocator);
        self.sheets = .empty;
    }

    /// The backing list is now `values` (CSSStyleSheet objects).
    fn replace(self: *AdoptedSheets, values: []const *runtime.Instance) void {
        var next: std.ArrayList(*SheetRecord) = .empty;
        next.ensureTotalCapacity(self.allocator, values.len) catch return;
        var next_sheets: std.ArrayList(Sheet) = .empty;
        next_sheets.ensureTotalCapacity(self.allocator, values.len) catch {
            next.deinit(self.allocator);
            return;
        };
        for (values) |value| {
            const record = hooks.sheetRecordOf(value) orelse continue;
            record.ref();
            next.appendAssumeCapacity(record);
            next_sheets.appendAssumeCapacity(.{ .object = value, .generation = runtime.SlabAllocator.generationOf(value) });
        }
        self.deinit();
        self.records = next;
        self.sheets = next_sheets;
    }
};

/// An adopted sheet's CSSStyleSheet object, by name.
pub const Sheet = struct {
    object: *runtime.Instance,
    generation: u64,

    /// The object, while it is the one named.
    pub fn get(self: Sheet) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.object) != self.generation) return null;
        return self.object;
    }
};

/// `owner`'s adopted sheets in array order (empty: none, or no array).
pub fn sheetsOf(owner: *runtime.Instance) []const Sheet {
    const adopted = hooks.adoptedSheetsOf(owner) orelse return &.{};
    return adopted.sheets.items;
}

/// Whether `owner`'s adoptedStyleSheets array was made (its getter or
/// setter ran): Blink's TreeScope::AdoptedStyleSheets() is non-null, and
/// CDP's DOM.Node lists the sheets, none included.
pub fn arrayExists(owner: *runtime.Instance) bool {
    const held = engine.tracedValue(owner, slot) orelse return false;
    held.release();
    return true;
}

/// The array's element type: a CSSStyleSheet (every StyleSheet object is
/// one).
pub fn isStyleSheet(instance: *runtime.Instance) bool {
    return hooks.sheetRecordOf(instance) != null;
}

/// The node document of `owner`, a Document or a ShadowRoot.
fn nodeDocumentOf(owner: *runtime.Instance) ?*runtime.Instance {
    const node = instance_bridge.getNodeBase(owner) orelse return null;
    if (node.node_type == NodeBase.DOCUMENT_NODE) return owner;
    return interfaces.Node.get_ownerDocument(owner) catch null;
}

/// CSSOM 6.2.3, "the set an indexed value algorithm for adoptedStyleSheets,
/// given value and index": "If value's constructed flag is not set, or its
/// constructor document is not equal to this DocumentOrShadowRoot's node
/// document, throw a "NotAllowedError" DOMException."
fn setIndexedValue(owner: *runtime.Instance, index: usize, value: *runtime.Instance) anyerror!void {
    _ = index;
    const record = hooks.sheetRecordOf(value) orelse return error.TypeError;
    const document = nodeDocumentOf(owner);
    if (!record.constructed or record.constructorDocument() == null or record.constructorDocument() != document) return error.NotAllowedError;
}

/// The backing list changed: the owner's view follows, and its document's
/// sheets change.
fn changed(owner: *runtime.Instance, values: []const *runtime.Instance) void {
    const adopted = hooks.adoptedSheetsOf(owner) orelse return;
    @import("font_loading.zig").adoptedSheetsChanged(owner, adopted.records.items, values);
    adopted.replace(values);
    // CDP's DOM agents (dom.inspector_probes; one load while none is
    // enabled): Blink's TreeScope::StyleSheetWasAdded / Removed ->
    // probe::DidModifyAdoptedStyleSheets.
    if (inspector_probes.active()) inspector_probes.didModifyAdoptedStyleSheets(owner);
    const document = nodeDocumentOf(owner) orelse return;
    const e = hooks.engineOf(document) orelse return;
    if (owner != document) e.addAdoptingRoot(owner) catch {};
    e.sheetsChanged();
}

pub const array_hooks: engine.ObservableArrayHooks = .{
    .set_indexed_value = &setIndexedValue,
    .changed = &changed,
};

/// The options a DocumentOrShadowRoot `owner` makes its adoptedStyleSheets
/// array with.
pub fn arrayOptions(owner: *runtime.Instance) engine.ObservableArrayOptions {
    return .{ .element = .{ .platform_object = &isStyleSheet }, .hooks = &array_hooks, .owner = owner };
}

/// The traced slot the owner keeps its array in ([SameObject]).
pub const slot: engine.TracedSlot = .{ .name = "adoptedStyleSheets" };

/// adoptedStyleSheets' getter for `owner`: its array, made on first read
/// and kept as long as the owner's wrapper (engine.traceValue). OWNED: a
/// hold of the caller's own.
pub fn array(owner: *runtime.Instance) !engine.Owned {
    if (engine.tracedValue(owner, slot)) |held| return held;
    const made = try engine.createObservableArray(owner.ctx, arrayOptions(owner));
    engine.traceValue(owner, made, slot);
    return engine.retainValue(owner.ctx, made);
}

/// The getter's answer, for the binding.
pub fn get(owner: *runtime.Instance) !runtime.JSValue {
    return (try array(owner)).take();
}

/// adoptedStyleSheets' setter for `owner` (WebIDL's for an observable array
/// attribute): `value` converted to a sequence, then the backing list
/// replaced.
pub fn set(owner: *runtime.Instance, value: runtime.JSValue) !void {
    const realm = engine.currentRealm() orelse owner.ctx;
    const allocator = owner.ctx.allocator;
    const values = try engine.convertToSequenceOfObjects(realm, value, allocator);
    defer {
        for (values) |v| v.release();
        allocator.free(values);
    }
    const plain = try allocator.alloc(runtime.JSValue, values.len);
    defer allocator.free(plain);
    for (values, 0..) |v, i| plain[i] = v.value;
    const held = try array(owner);
    defer held.release();
    try engine.replaceObservableArrayItems(held.value, plain);
}

/// Clear an already-created adoptedStyleSheets array at cross-document
/// adoption. Its identity and changed hook remain the existing ones; this
/// never runs the getter and cannot manufacture an array.
pub fn clearExisting(owner: *runtime.Instance) void {
    const held = engine.tracedValue(owner, slot) orelse return;
    defer held.release();
    engine.replaceObservableArrayItems(held.value, &.{}) catch {};
}
