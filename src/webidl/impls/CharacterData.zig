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
const NodeImpl = @import("Node.zig");

// Import DOM algorithms from src/dom/
const dom = @import("dom");

// Import mixins for shared interface methods
const mixins = @import("mixins");
const NonDocumentTypeChildNode = mixins.NonDocumentTypeChildNode;
const ChildNode = mixins.ChildNode;

pub const State = CharacterData.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    IndexSizeError,
    OutOfMemory,
};

/// Maximum bytes that can be stored inline (without heap allocation)
/// 31 bytes chosen to fit in 32-byte cache line with 1 byte for length
/// Most text nodes in typical HTML are short (whitespace, small words)
pub const INLINE_TEXT_CAPACITY: usize = 31;

/// Internal state for CharacterData implementation
/// Stores the mutable string data associated with this node
/// Uses inline storage for small text (≤31 bytes) to avoid heap allocations
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Inline storage for small text - avoids heap allocation for ≤31 bytes
    /// First byte is length when using inline storage
    inline_text: [INLINE_TEXT_CAPACITY + 1]u8,

    /// Heap storage for larger text - only used when text > 31 bytes
    heap_text: ?[]u8,

    pub fn init(allocator: std.mem.Allocator) !InternalState {
        return .{
            .allocator = allocator,
            .inline_text = [_]u8{0} ** (INLINE_TEXT_CAPACITY + 1), // length = 0
            .heap_text = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.heap_text) |heap| {
            self.allocator.free(heap);
        }
    }

    /// Check if currently using inline storage
    pub fn isInline(self: *const InternalState) bool {
        return self.heap_text == null;
    }

    /// Get current data as a slice (works for both inline and heap)
    pub fn getData(self: *const InternalState) []const u8 {
        if (self.heap_text) |heap| {
            return heap;
        }
        // Inline storage: first byte is length
        const len = self.inline_text[0];
        return self.inline_text[1 .. 1 + len];
    }

    /// Get mutable data slice (for internal use only)
    fn getDataMut(self: *InternalState) []u8 {
        if (self.heap_text) |heap| {
            return heap;
        }
        const len = self.inline_text[0];
        return self.inline_text[1 .. 1 + len];
    }

    /// Get the length of the data
    pub fn getLength(self: *const InternalState) u32 {
        if (self.heap_text) |heap| {
            return @intCast(heap.len);
        }
        return self.inline_text[0];
    }

    /// Set data - uses inline storage for small text, heap for larger
    pub fn setData(self: *InternalState, data: []const u8) !void {
        // Free existing heap data if any
        if (self.heap_text) |heap| {
            self.allocator.free(heap);
            self.heap_text = null;
        }

        if (data.len <= INLINE_TEXT_CAPACITY) {
            // Use inline storage
            self.inline_text[0] = @intCast(data.len);
            @memcpy(self.inline_text[1 .. 1 + data.len], data);
        } else {
            // Use heap storage
            self.heap_text = try self.allocator.dupe(u8, data);
        }
    }

    /// Replace a range of data with new data
    /// This is the core operation for replaceData, insertData, deleteData, appendData
    pub fn replaceData(self: *InternalState, offset: u32, count_param: u32, data: []const u8) !void {
        const current_len = self.getLength();
        var count = count_param;

        // Clamp count to available length
        if (offset + count > current_len) {
            count = current_len - offset;
        }

        const new_len = current_len - count + @as(u32, @intCast(data.len));

        if (new_len <= INLINE_TEXT_CAPACITY) {
            // Result fits in inline storage
            var new_inline: [INLINE_TEXT_CAPACITY + 1]u8 = undefined;
            new_inline[0] = @intCast(new_len);

            const current_data = self.getData();

            // Copy before offset
            @memcpy(new_inline[1 .. 1 + offset], current_data[0..offset]);

            // Copy new data
            @memcpy(new_inline[1 + offset .. 1 + offset + data.len], data);

            // Copy after deleted region
            const after_start = offset + count;
            if (after_start < current_len) {
                @memcpy(new_inline[1 + offset + data.len .. 1 + new_len], current_data[after_start..]);
            }

            // Free heap if we were using it
            if (self.heap_text) |heap| {
                self.allocator.free(heap);
                self.heap_text = null;
            }

            self.inline_text = new_inline;
        } else {
            // Result needs heap storage
            const new_data = try self.allocator.alloc(u8, new_len);
            errdefer self.allocator.free(new_data);

            const current_data = self.getData();

            // Copy before offset
            @memcpy(new_data[0..offset], current_data[0..offset]);

            // Copy new data
            @memcpy(new_data[offset .. offset + data.len], data);

            // Copy after deleted region
            const after_start = offset + count;
            if (after_start < current_len) {
                @memcpy(new_data[offset + data.len ..], current_data[after_start..]);
            }

            // Free old heap data if any
            if (self.heap_text) |heap| {
                self.allocator.free(heap);
            }

            self.heap_text = new_data;
            // Clear inline length to indicate heap mode
            self.inline_text[0] = 0;
        }
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Initialize instance (creates the instance)
/// Chains to parent class initialization: Node -> EventTarget
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (Node) which chains to EventTarget
    const instance = try NodeImpl.init(allocator, StateType, vtable, ctx);
    errdefer NodeImpl.deinit(instance);

    // Initialize CharacterData internal state in global registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = try InternalState.init(allocator);
    try setInternalInRegistry(instance, internal);

    return instance;
}

/// Global registry for CharacterData internal state
var char_data_registry: std.AutoHashMap(usize, *InternalState) = undefined;
var char_registry_initialized: bool = false;

fn ensureCharRegistry() void {
    if (!char_registry_initialized) {
        char_data_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        char_registry_initialized = true;
    }
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureCharRegistry();
    try char_data_registry.put(@intFromPtr(instance), internal);
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    ensureCharRegistry();
    return char_data_registry.get(@intFromPtr(instance));
}

/// Get CharacterData's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    ensureCharRegistry();
    if (char_data_registry.get(@intFromPtr(instance))) |internal| {
        internal.deinit();
    }
    _ = char_data_registry.remove(@intFromPtr(instance));
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
}

// =============================================================================
// Getters - DOM §4.11
// =============================================================================

/// Getter for data
/// DOM §4.11 - Returns this's data.
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initInterned(internal.getData());
}

/// Getter for length
/// DOM §4.11 - Returns this's length (number of code units).
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.getLength();
}

/// Getter for previousElementSibling (from NonDocumentTypeChildNode mixin)
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return NonDocumentTypeChildNode.previousElementSibling(instance);
}

/// Getter for nextElementSibling (from NonDocumentTypeChildNode mixin)
/// Spec: https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return NonDocumentTypeChildNode.nextElementSibling(instance);
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
    const length = internal.getLength();
    const data = internal.getData();

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 3: Handle overflow - return from offset to end
    if (offset + count > length) {
        return runtime.DOMString.initDupe(internal.allocator, data[offset..]);
    }

    // Step 4: Return substring
    return runtime.DOMString.initDupe(internal.allocator, data[offset .. offset + count]);
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

/// Operation: remove (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-remove
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    // Delegate to ChildNode mixin
    ChildNode.remove(instance) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            else => error.NotImplemented,
        };
    };
}

/// Operation: before (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-before
pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = instance;
    _ = nodes;
    // TODO: Insert nodes before this node
    return error.NotImplemented;
}

/// Operation: after (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-after
pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = instance;
    _ = nodes;
    // TODO: Insert nodes after this node
    return error.NotImplemented;
}

/// Operation: replaceWith (from ChildNode mixin)
/// https://dom.spec.whatwg.org/#dom-childnode-replacewith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = instance;
    _ = nodes;
    // TODO: Replace this node with nodes
    return error.NotImplemented;
}

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
/// 12. If node's parent is non-null, then run the children changed steps for node's parent.
fn replaceDataInternal(instance: *runtime.Instance, internal: *InternalState, offset: u32, count_param: u32, data: []const u8) !void {
    const length = internal.getLength();

    // Step 2: Check bounds
    if (offset > length) {
        return error.IndexSizeError;
    }

    // Step 4: Queue mutation record
    // TODO: Call dom.mutation_observer_algorithms.queueMutationRecord
    // This requires converting runtime.Instance to the Node type expected by the algorithm
    // For now, skip mutation observer notification until type bridge is established

    // Steps 3, 5-7: Replace data using InternalState's optimized method
    // This handles inline vs heap storage automatically
    try internal.replaceData(offset, count_param, data);

    // Steps 8-11: Update live ranges
    // TODO: Call dom.range_tracking.updateRangesAfterReplace
    // This requires access to owner_document from Node's inherited state
    _ = instance;

    // Step 12: Run children changed steps for parent
    // TODO: Call dom.mutation.runChildrenChangedSteps
    // This requires access to parent_node from Node's inherited state
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Set the data directly (used by Text, Comment constructors)
pub fn setData(instance: *runtime.Instance, data: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.setData(data);
}

/// Get the data directly as a slice
/// Returns null if instance has no internal state
pub fn getData(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
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
