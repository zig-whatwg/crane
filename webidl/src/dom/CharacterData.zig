//! CharacterData interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const dom = @import("dom");
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const dom_types = @import("dom_types");

const Allocator = std.mem.Allocator;
const Node = @import("node").Node;
const Document = @import("document").Document;

/// DOM Spec: interface CharacterData : Node
pub const CharacterData = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode };

    allocator: Allocator,
    /// The mutable string data associated with this node
    data: []u8,

    pub fn init(allocator: Allocator) !CharacterData {
        // NOTE: Parent Node/EventTarget fields must be initialized here
        return .{
            .event_listener_list = null, // From EventTarget
            .node_type = 3, // TEXT_NODE (default, subclasses override)
            .node_name = "#text", // Default, subclasses may override
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            .allocator = allocator,
            .data = try allocator.dupe(u8, ""),
        };
    }

    pub fn deinit(self: *CharacterData) void {
        self.allocator.free(self.data);
        // NOTE: Parent Node cleanup is handled by codegen
    }

    /// DOM §4.11 - data getter
    /// Returns this's data.
    pub fn get_data(self: *const CharacterData) []const u8 {
        return self.data;
    }

    /// DOM §4.11 - data setter
    /// Replace data with node this, offset 0, count this's length, and data new value.
    pub fn set_data(self: *CharacterData, new_value: []const u8) !void {
        try self.replaceData(0, @intCast(self.data.len), new_value);
    }

    /// DOM §4.11 - length getter
    /// Returns this's length (number of code units).
    pub fn get_length(self: *const CharacterData) u32 {
        return @intCast(self.data.len);
    }

    /// DOM §4.11 - substringData(offset, count)
    /// Returns a substring of this's data.
    ///
    /// Steps:
    /// 1. Let length be node's length.
    /// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
    /// 3. If offset plus count is greater than length, return code units from offset to end.
    /// 4. Return code units from offset to offset+count.
    pub fn call_substringData(self: *const CharacterData, offset: u32, count: u32) ![]const u8 {
        const length: u32 = @intCast(self.data.len);

        // Step 2: Check bounds
        if (offset > length) {
            return error.IndexSizeError;
        }

        // Step 3: Handle overflow
        if (offset + count > length) {
            return self.data[offset..];
        }

        // Step 4: Return substring
        return self.data[offset .. offset + count];
    }

    /// DOM §4.11 - appendData(data)
    /// Appends data to this's data.
    ///
    /// Steps: Replace data with node this, offset this's length, count 0, and data.
    pub fn call_appendData(self: *CharacterData, data: []const u8) !void {
        try self.replaceData(@intCast(self.data.len), 0, data);
    }

    /// DOM §4.11 - insertData(offset, data)
    /// Inserts data at the given offset.
    ///
    /// Steps: Replace data with node this, offset, count 0, and data.
    pub fn call_insertData(self: *CharacterData, offset: u32, data: []const u8) !void {
        try self.replaceData(offset, 0, data);
    }

    /// DOM §4.11 - deleteData(offset, count)
    /// Deletes count code units starting at offset.
    ///
    /// Steps: Replace data with node this, offset, count, and empty string.
    pub fn call_deleteData(self: *CharacterData, offset: u32, count: u32) !void {
        try self.replaceData(offset, count, "");
    }

    /// DOM §4.11 - replaceData(offset, count, data)
    /// Replaces count code units at offset with data.
    ///
    /// Steps (simplified - full spec includes range and mutation handling):
    /// 1. Let length be node's length.
    /// 2. If offset is greater than length, throw "IndexSizeError".
    /// 3. If offset + count > length, set count to length - offset.
    /// 4-12. [Mutation records, ranges, and parent notification skipped for now]
    /// 5. Insert data into node's data after offset code units.
    /// 6-7. Remove count code units starting from offset + data's length.
    pub fn call_replaceData(self: *CharacterData, offset: u32, count: u32, data: []const u8) !void {
        try self.replaceData(offset, count, data);
    }

    /// Internal replace data implementation
    fn replaceData(self: *CharacterData, offset: u32, count_param: u32, data: []const u8) !void {
        const length: u32 = @intCast(self.data.len);
        var count = count_param;

        // Step 2: Check bounds
        if (offset > length) {
            return error.IndexSizeError;
        }

        // Step 3: Clamp count
        if (offset + count > length) {
            count = length - offset;
        }

        // Step 4: Queue mutation record
        const mutation = dom.mutation;
        const empty_nodes: []const *Node = &[_]*Node{};
        try mutation.queueMutationRecord(
            "characterData",
            &self.base,
            null,
            null,
            self.data, // oldValue
            empty_nodes,
            empty_nodes,
            null,
            null,
        );

        // Steps 5-7: Build new data string
        const new_len = length - count + @as(u32, @intCast(data.len));
        const new_data = try self.allocator.alloc(u8, new_len);

        // Copy before offset
        @memcpy(new_data[0..offset], self.data[0..offset]);

        // Copy new data
        @memcpy(new_data[offset .. offset + data.len], data);

        // Copy after deleted region
        const after_start = offset + count;
        if (after_start < length) {
            @memcpy(new_data[offset + data.len ..], self.data[after_start..]);
        }

        // Replace old data
        self.allocator.free(self.data);
        self.data = new_data;

        // Steps 8-11 - Update ranges
        if (self.base.owner_document) |doc| {
            // owner_document is already *Document, no conversion needed
            const range_tracking = @import("range_tracking");
            const new_length = @as(u32, @intCast(data.len));
            range_tracking.updateRangesAfterReplace(doc, &self.base, offset, count, new_length);
        }

        // Step 12 - Run children changed steps for parent
        // Per spec: "If node's parent is non-null, then run the children changed steps for node's parent"
        // Spec: https://dom.spec.whatwg.org/#concept-node-replace
        //
        // Children changed steps are extension points for other specifications (e.g., HTML)
        // to define custom behavior when children change. Examples:
        // - Shadow DOM slot assignment algorithm
        // - Form-associated element connections
        // - Custom element reactions
        if (self.base.parent_node) |parent| {
            // Call the mutation module's children changed callback system
            // This will invoke any registered callbacks from other specifications
            @import("mutation").runChildrenChangedSteps(parent);
        }
    }
}, .{
    .exposed = &.{.Window},
});
