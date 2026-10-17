//! Implementation for CharacterData interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata
//! WHATWG DOM Standard §4.10
//!
//! CharacterData is an abstract interface that Text, Comment, CDATASection,
//! and ProcessingInstruction all inherit. It provides access to the textual
//! content through the `data` attribute and string manipulation methods.
//!
//! Migrated from: webidl/src/dom/CharacterData.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const CharacterData = interfaces.CharacterData;

// Import parent class impl for initialization chain

// Import DOM algorithms from src/dom/
const dom = @import("dom");

// Import mixins for shared interface methods
const mixins = @import("mixins");

pub const State = CharacterData.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
};

/// Maximum bytes that can be stored inline (without heap allocation).
/// Most text nodes in typical HTML are short (whitespace, small words); 31
/// keeps the whole state at 64 bytes beside its lengths and heap pointer.
pub const INLINE_TEXT_CAPACITY: usize = 31;

/// Internal state for CharacterData implementation: the node's data.
///
/// DOM measures and indexes data in UTF-16 code units (DOM 4.10, Infra §4.6);
/// Crane holds it as WTF-8 (a lone surrogate as its three bytes, a pair as one
/// four-byte sequence; infra/wtf8.zig). So the state keeps both lengths: the
/// bytes, and the code units - the node's length - counted when data is set
/// and kept current by every splice. When the two are equal every byte is
/// ASCII and an offset is its own byte offset; otherwise offsets are mapped
/// onto the bytes by infra.wtf8.
///
/// Small text (up to INLINE_TEXT_CAPACITY bytes) is stored inline.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The data's bytes on the heap, or null while they are inline.
    heap: ?[*]u8,

    /// The data's length in bytes (the heap block's size when on the heap).
    byte_len: u32,

    /// The data's length in UTF-16 code units: the node's length (DOM 4.2).
    units: u32,

    /// Inline storage for small text.
    inline_text: [INLINE_TEXT_CAPACITY]u8,

    pub fn init(allocator: std.mem.Allocator) !InternalState {
        return .{
            .allocator = allocator,
            .heap = null,
            .byte_len = 0,
            .units = 0,
            .inline_text = undefined,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.heap) |heap| {
            self.allocator.free(heap[0..self.byte_len]);
            self.heap = null;
        }
        self.byte_len = 0;
        self.units = 0;
    }

    /// Check if currently using inline storage
    pub fn isInline(self: *const InternalState) bool {
        return self.heap == null;
    }

    /// The data's bytes (WTF-8), borrowed until the next change.
    pub fn getData(self: *const InternalState) []const u8 {
        if (self.heap) |heap| return heap[0..self.byte_len];
        return self.inline_text[0..self.byte_len];
    }

    /// The node's length: the data's length in UTF-16 code units.
    pub fn getLength(self: *const InternalState) u32 {
        return self.units;
    }

    /// The data's length in bytes.
    pub fn byteLength(self: *const InternalState) u32 {
        return self.byte_len;
    }

    /// Where code unit `unit` (at most the length) falls in the bytes.
    pub fn position(self: *const InternalState, unit: u32) infra.wtf8.Position {
        // ASCII: every code unit is one byte.
        if (self.units == self.byte_len) return .{ .byte = unit };
        if (unit == 0) return .{ .byte = 0 };
        if (unit >= self.units) return .{ .byte = self.byte_len };
        return infra.wtf8.positionOfCodeUnit(self.getData(), unit);
    }

    /// Set data - uses inline storage for small text, heap for larger
    pub fn setData(self: *InternalState, data: []const u8) !void {
        if (data.len > std.math.maxInt(u32)) return error.OutOfMemory;
        const units: u32 = @intCast(infra.wtf8.codeUnitLength(data));
        if (data.len <= INLINE_TEXT_CAPACITY) {
            // Copied before the heap block is freed, and forwards: `data`
            // may be this state's own bytes.
            std.mem.copyForwards(u8, self.inline_text[0..data.len], data);
            if (self.heap) |heap| self.allocator.free(heap[0..self.byte_len]);
            self.heap = null;
        } else {
            const heap = try self.allocator.dupe(u8, data);
            self.deinit();
            self.heap = heap.ptr;
        }
        self.byte_len = @intCast(data.len);
        self.units = units;
    }

    /// Replace `count_param` code units at `offset` with `data` (DOM replace
    /// data steps 2-3 and 5-7) - the core of replaceData, insertData,
    /// deleteData and appendData. Offsets are code units.
    pub fn replaceData(self: *InternalState, offset: u32, count_param: u32, data: []const u8) !void {
        try self.replaceDataUnits(offset, count_param, data, @intCast(infra.wtf8.codeUnitLength(data)));
    }

    /// replaceData with `data`'s length in code units already counted.
    pub fn replaceDataUnits(self: *InternalState, offset: u32, count_param: u32, data: []const u8, data_units: u32) !void {
        const length = self.units;
        if (offset > length) return error.IndexSizeError;

        // Clamp count to available length. Compared as a difference: offset
        // plus a count near 2^32 - `deleteData(1, 0xFFFFFFFF)` - wraps.
        const count = @min(count_param, length - offset);

        // Steps 5-7 as one splice: a pair cut at either end splits into its
        // surrogates, and halves that meet join (infra.wtf8.Pieces).
        const start = self.position(offset);
        const end = if (count == 0) start else self.position(offset + count);
        var pieces: infra.wtf8.Pieces = .{};
        pieces.splice(self.getData(), start, end, data);
        const new_len = pieces.joinedLength();
        if (new_len > std.math.maxInt(u32)) return error.OutOfMemory;

        if (new_len <= INLINE_TEXT_CAPACITY) {
            // The pieces read the current data, which may be inline.
            var new_inline: [INLINE_TEXT_CAPACITY]u8 = undefined;
            pieces.writeJoined(new_inline[0..new_len]);
            self.deinit();
            @memcpy(self.inline_text[0..new_len], new_inline[0..new_len]);
        } else {
            const new_data = try self.allocator.alloc(u8, new_len);
            pieces.writeJoined(new_data);
            self.deinit();
            self.heap = new_data.ptr;
        }
        self.byte_len = @intCast(new_len);
        self.units = length - count + data_units;
    }

    /// The code units from `offset` to `offset + count` (count already
    /// clamped to the length), in a new allocation. OWNED.
    pub fn substring(self: *const InternalState, allocator: std.mem.Allocator, offset: u32, count: u32) ![]u8 {
        const start = self.position(offset);
        const end = if (count == 0) start else self.position(offset + count);
        var pieces: infra.wtf8.Pieces = .{};
        pieces.substring(self.getData(), start, end);
        return pieces.toOwned(allocator);
    }
};

// One per CharacterData node: the code-unit count was fitted in beside the
// byte length without growing the state past 64 bytes.
comptime {
    std.debug.assert(@sizeOf(InternalState) <= 64);
}

// Use shared InstanceRegistry utility for internal state management
const webidl = @import("webidl");
const Registry = runtime.InstanceRegistry(.character_data, InternalState);

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// What a CharacterData node is given at construction (`initWith`): its
/// data. Text(data), Comment(data), document.createTextNode and
/// createProcessingInstruction make a node with its data, as WebKit's
/// `Text::create(document, data)` passes it to CharacterData's constructor;
/// none runs "replace data" on a node no one can observe yet. Made with no
/// arguments, a node's data is the empty string.
pub const construction_args = .{"data"};

/// CharacterData's own construction steps: the generated chain runs Node's first.
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    // Initialize CharacterData internal state in global registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = try InternalState.init(allocator);
    if (@hasField(@TypeOf(args), "data")) {
        errdefer deinitOwn(instance);
        try internal.setData(args.data);
    }
}

/// Get CharacterData's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// CharacterData's own teardown: the generated chain runs Node's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
}

// =============================================================================
// Getters - DOM §4.11
// =============================================================================

/// Getter for data
/// DOM §4.11 - Returns this's data.
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone data to transfer ownership to caller (interface layer will free)
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.getData());
}

/// Getter for length
/// DOM §4.11 - Returns this's length (number of code units).
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.getLength();
}

// =============================================================================
// Setters - DOM §4.11
// =============================================================================

/// Setter for data
/// DOM §4.11 - Replace data with node this, offset 0, count this's length, and data new value.
pub fn set_data(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const new_value = value.asSlice();
    try replaceDataInternal(instance, internal, 0, internal.getLength(), new_value);
}

// =============================================================================
// Operations - DOM §4.11
// =============================================================================

/// Operation: substringData(offset, count)
/// DOM §4.11 - Returns a substring of this's data.
///
/// Steps:
/// 1. Let length be node's length.
/// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
/// 3. If offset plus count is greater than length, return code units from offset to end.
/// 4. Return code units from offset to offset+count.
pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let length be node's length" - code units.
    const length = internal.getLength();

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
    // The V8 callback will free returned strings using instance.ctx.allocator
    const allocator = instance.ctx.allocator;

    // Step 3: "If offset plus count is greater than length, return a string
    // whose value is the code units from the offsetth code unit to the end."
    // Compared as a difference: offset plus a count near 2^32 wraps.
    // Step 4: otherwise the code units from offset to offset + count. A pair
    // cut at either end leaves its surrogate (infra.wtf8).
    const clamped = @min(count, length - offset);
    if (clamped == 0) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initOwned(try internal.substring(allocator, offset, clamped));
}

/// Operation: appendData(data)
/// DOM §4.11 - Appends data to this's data.
///
/// Steps: Replace data with node this, offset this's length, count 0, and data.
pub fn call_appendData(instance: *runtime.Instance, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, internal.getLength(), 0, data.asSlice());
}

/// Operation: insertData(offset, data)
/// DOM §4.11 - Inserts data at the given offset.
///
/// Steps: Replace data with node this, offset, count 0, and data.
pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, 0, data.asSlice());
}

/// Operation: deleteData(offset, count)
/// DOM §4.11 - Deletes count code units starting at offset.
///
/// Steps: Replace data with node this, offset, count, and empty string.
pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, "");
}

/// Operation: replaceData(offset, count, data)
/// DOM §4.11 - Replaces count code units at offset with data.
pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, data.asSlice());
}

// =============================================================================
// ChildNode Mixin Operations
// =============================================================================

// =============================================================================
// Internal Implementation - DOM §4.11 Replace Data Algorithm
// =============================================================================

/// Internal replace data implementation
/// DOM §4.11 - To replace data of node with offset, count, and data:
///
/// 1. Let length be node's length.
/// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
/// 3. If offset plus count is greater than length, set count to length − offset.
/// 4. Queue a mutation record of "characterData" for node with null, null, node's data, « », « », null, and null.
/// 5. Insert data into node's data after offset code units.
/// 6. Let delete offset be offset + data's length.
/// 7. Remove count code units from node's data, starting at delete offset.
/// 8-11. For each live range whose start/end node is node, update start/end offset.
/// 12. Update a ProcessingInstruction's attributes unless already updated.
/// 13. If node's parent is non-null, run its parent's children changed steps.
fn replaceDataInternal(instance: *runtime.Instance, internal: *InternalState, offset: u32, count_param: u32, data: []const u8) !void {
    const length = internal.getLength();

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: "If offset + count is greater than length, then set count to
    // length - offset." Compared as a difference: offset plus a count near
    // 2^32 wraps.
    const count = @min(count_param, length - offset);

    // Step 4: "Queue a mutation record of "characterData" for node with
    // null, null, node's data, « », « », null, and null." Before step 5
    // changes the data: the record copies it.
    try dom.mutation_observer_algorithms.queueCharacterDataMutationRecord(instance, internal.getData());

    // Steps 5-7: insert data after offset code units, then remove count
    // code units from offset + data's length - one splice, which handles
    // inline vs heap storage, and a pair cut or completed at either seam.
    if (data.len > std.math.maxInt(u32)) return error.OutOfMemory;
    const data_units: u32 = @intCast(infra.wtf8.codeUnitLength(data));
    try internal.replaceDataUnits(offset, count, data, data_units);
    // The node document's DOM tree version moves with the data, parent or
    // none (Blink CharacterData::SetDataAndUpdate, WebKit
    // CharacterData::notifyParentAfterChange): an XPath iterator over the
    // document is invalid from here on, as DOM Level 3 XPath says of any
    // mutation of the document.
    dom.refcount.characterDataChanged(instance);

    // Steps 8-11: the live ranges whose boundary points are in node, moved
    // by data's length in code units.
    dom.mutation.runLiveRangeReplaceDataSteps(instance, offset, count, data_units);

    // Step 12: only a PI updates attributes from data. A brand check leaves
    // ordinary Text/Comment mutation without parsing or map allocation.
    if (instance.stateAs(interfaces.ProcessingInstruction.State) != null)
        dom.character_data.processingInstructionDataChanged(instance);

    // Step 13: "If node's parent is non-null, then run the children changed
    // steps for node's parent."
    if (interfaces.Node.get_parentNode(instance) catch null) |parent| {
        if (dom.instance_bridge.getNodeBase(@ptrCast(parent))) |parent_base| {
            dom.mutation.runChildrenChangedSteps(parent_base);
        }
    }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// dom.character_data: `node`'s data, borrowed until it next changes, or
/// null when `node` has no CharacterData state.
fn dataOf(node: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(node) orelse return null;
    return internal.getData();
}

/// Get the length of the data (number of code units)
pub fn getDataLength(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.getLength();
}

/// Delete a range of data (used by Range.deleteContents)
pub fn deleteDataRange(instance: *runtime.Instance, offset: u32, count: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try replaceDataInternal(instance, internal, offset, count, "");
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.character_data, &sweepRemaining);
    // Its data, read in place by the tree's own algorithms (textContent,
    // nodeValue, isEqualNode, an option's text).
    @import("dom").character_data.install(.{ .data_of = &dataOf });
}

/// dom.teardown_sweeps: at its Browser's end, every CharacterData state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}
