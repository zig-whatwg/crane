//! Pure-Zig V8 Heap Snapshot analyzer for Crane's MCP `--memoryDebugging` tools.
//!
//! Reproduces Chromium DevTools Frontend's `HeapSnapshot` and `JSHeapSnapshot`
//! (`front_end/entrypoints/heap_snapshot_worker/HeapSnapshot.ts`,
//! `front_end/entrypoints/heap_snapshot_worker/JSHeapSnapshot.ts`; Copyright
//! The Chromium Authors, BSD-3-Clause) and `chrome-devtools-mcp` v1.13.0's
//! `HeapSnapshotManager` (`src/processors/HeapSnapshotManager.ts`; Copyright
//! 2026 Google LLC, Apache-2.0). See THIRD_PARTY_NOTICES.md.

const std = @import("std");
const Allocator = std.mem.Allocator;
const paths_mod = @import("paths.zig");

pub const DomLinkState = enum(u8) {
    unknown = 0,
    attached = 1,
    detached = 2,
};

pub const Statistics = struct {
    total: u64,
    native: struct {
        total: u64,
        typed_arrays: u64,
    },
    v8heap: struct {
        total: u64,
        code: u64,
        js_arrays: u64,
        strings: u64,
        system: u64,
    },
};

pub const StaticData = struct {
    node_count: u32,
    root_node_index: u32,
    total_size: u64,
    max_js_object_id: u64,
};

pub const NativeContextInfo = struct {
    node_id: u64,
    node_index: u32,
    node_name: []const u8,
    attributed_size: u64,
    retained_size: u64,
    self_size: u64,
};

pub const NativeContextSizes = struct {
    native_contexts: []NativeContextInfo,
    shared_size: u64,
    no_attribution_size: u64,
};

pub const RetainedByContextSummary = struct {
    context_count: u64,
    retained_by_context_size: u64,
    retained_by_context_count: u64,
    not_retained_by_context_size: u64,
    not_retained_by_context_count: u64,
    total_size: u64,
};

pub const AggregateInfo = struct {
    id: u32,
    class_name: []const u8,
    count: u32,
    self_size: u64,
    retained_size: u64,
};

pub const AggregateData = struct {
    aggregates: []AggregateInfo,
    object_count: u64,
    total_self_size: u64,
};

pub const NodeItem = struct {
    id: u64,
    name: []const u8,
    type_name: []const u8,
    distance: i32,
    self_size: u64,
    retained_size: u64,
    node_index: u32,
};

pub const EdgeItem = struct {
    name: []const u8,
    type_name: []const u8,
    node: NodeItem,
    edge_index: u32,
};

pub const ObjectInfo = struct {
    id: u64,
    name: []const u8,
    type_name: []const u8,
    node_index: u32,
    detachedness: DomLinkState,
    self_size: u64,
    retained_size: u64,
    distance: i32,
    edge_count: u32,
    retainer_count: u32,
};

pub const DominatorItem = struct {
    node_id: u64,
    node_index: u32,
    node_name: []const u8,
    self_size: u64,
    retained_size: u64,
};

pub const EdgeSortBy = enum {
    retained_size,
    self_size,
    name,
};

pub const EdgeQueryOptions = struct {
    sort_by: EdgeSortBy = .retained_size,
    min_retained_size: ?u64 = null,
    exclude_primitives: bool = true,
};

const Location = struct {
    script_id: u32,
    line: u32,
    column: u32,
};

const BitVector = struct {
    words: []u64,

    fn init(allocator: Allocator, bit_count: usize) Allocator.Error!BitVector {
        const word_count = (bit_count + 63) / 64;
        const words = try allocator.alloc(u64, word_count);
        @memset(words, 0);
        return .{ .words = words };
    }

    fn deinit(self: *BitVector, allocator: Allocator) void {
        allocator.free(self.words);
    }

    inline fn get(self: BitVector, index: usize) bool {
        const word = index >> 6;
        if (word >= self.words.len) return false;
        return (self.words[word] & (@as(u64, 1) << @intCast(index & 63))) != 0;
    }

    inline fn set(self: *BitVector, index: usize) void {
        const word = index >> 6;
        if (word >= self.words.len) return;
        self.words[word] |= (@as(u64, 1) << @intCast(index & 63));
    }
};

const WeakMapMatch = struct {
    duplicated_part: []const u8,
    table_id: u64,
};

const bitmask_dom_link_state: u32 = 3;
const shift_class_index: u5 = 2;
const min_interface_property_count: usize = 1;
const max_interface_name_length: usize = 120;
const min_object_count_per_interface: usize = 2;
const min_object_proportion_per_interface: usize = 1000;
const no_native_context: i32 = -1;
const shared_native_context: i32 = -2;
const no_distance: i32 = -5;
const base_system_distance: i32 = 100_000_000;

const flag_can_be_queried: u8 = 1;
const flag_detached_dom_tree_node: u8 = 2;
const flag_page_object: u8 = 4;

const missing_type: u32 = std.math.maxInt(u32);

pub const Error = error{
    InvalidSnapshot,
    NodeNotFound,
    ClassNotFound,
    MissingObjectId,
    InvalidFilterName,
    InvalidExtension,
} || Allocator.Error;

pub const HeapSnapshot = struct {
    allocator: Allocator,
    arena_state: std.heap.ArenaAllocator,

    // Raw V8 snapshot arrays (owned by `allocator`).
    nodes: []u32,
    edges: []u32,
    strings: std.ArrayList([]const u8),

    // Meta offsets and type codes.
    node_field_count: u32,
    node_type_offset: u32,
    node_name_offset: u32,
    node_id_offset: u32,
    node_self_size_offset: u32,
    node_edge_count_offset: u32,
    node_trace_node_id_offset: ?u32,
    node_detachedness_offset: ?u32,

    node_types: []const []const u8,
    node_array_type: u32,
    node_hidden_type: u32,
    node_object_type: u32,
    node_native_type: u32,
    node_string_type: u32,
    node_cons_string_type: u32,
    node_sliced_string_type: u32,
    node_code_type: u32,
    node_synthetic_type: u32,
    node_closure_type: u32,
    node_regexp_type: u32,
    node_number_type: u32,

    edge_fields_count: u32,
    edge_type_offset: u32,
    edge_name_offset: u32,
    edge_to_node_offset: u32,

    edge_types: []const []const u8,
    edge_element_type: u32,
    edge_hidden_type: u32,
    edge_internal_type: u32,
    edge_shortcut_type: u32,
    edge_weak_type: u32,
    edge_invisible_type: u32,
    edge_property_type: u32,

    node_count: u32,
    edge_count: u32,
    root_node_index: u32,
    extra_native_bytes: u64,

    // Computed graph structures (owned by `allocator`).
    first_edge_indexes: []u32,
    first_retainer_index: []u32,
    retaining_nodes: []u32,
    retaining_edges: []u32,
    detachedness_and_class_index: []u32,
    flags: []u8,
    dominators_tree: []u32,
    retained_sizes: []u64,
    first_dominated_node_index: []u32,
    dominated_nodes: []u32,
    node_distances: []i32,
    location_map: std.AutoHashMapUnmanaged(u32, Location) = .empty,
    node_native_context_attribution: []i32,
    native_context_ordinals: []u32,
    native_context_sizes: NativeContextSizes,
    statistics: Statistics,
    max_js_object_id: u64,

    // Deterministic 1-indexed class IDs (HeapSnapshotManager.ts constructor).
    id_to_class_key: std.ArrayList([]const u8),
    class_key_to_id: std.StringHashMapUnmanaged(u32) = .empty,

    pub fn loadFromBytes(allocator: Allocator, bytes: []const u8) Error!*HeapSnapshot {
        const self = try allocator.create(HeapSnapshot);
        errdefer allocator.destroy(self);

        var arena_state = std.heap.ArenaAllocator.init(allocator);
        errdefer arena_state.deinit();
        const arena = arena_state.allocator();

        var parsed = try parseSnapshotJson(allocator, arena, bytes);
        errdefer {
            parsed.nodes.deinit(allocator);
            parsed.edges.deinit(allocator);
            parsed.locations.deinit(allocator);
            parsed.strings.deinit(allocator);
        }

        const node_field_count = parsed.node_field_count;
        const edge_fields_count = parsed.edge_fields_count;
        if (node_field_count == 0 or edge_fields_count == 0) return error.InvalidSnapshot;
        if (parsed.nodes.items.len % node_field_count != 0) return error.InvalidSnapshot;
        if (parsed.edges.items.len % edge_fields_count != 0) return error.InvalidSnapshot;

        const node_count: u32 = @intCast(parsed.nodes.items.len / node_field_count);
        const edge_count: u32 = @intCast(parsed.edges.items.len / edge_fields_count);
        if (node_count == 0) return error.InvalidSnapshot;
        if (parsed.root_index >= parsed.nodes.items.len or parsed.root_index % node_field_count != 0) {
            return error.InvalidSnapshot;
        }

        const nodes = try parsed.nodes.toOwnedSlice(allocator);
        errdefer allocator.free(nodes);
        const edges = try parsed.edges.toOwnedSlice(allocator);
        errdefer allocator.free(edges);
        const locations = parsed.locations;
        defer {
            var loc_mut = locations;
            loc_mut.deinit(allocator);
        }

        // Validate edge target indices before indexing into node tables.
        var ei: usize = 0;
        while (ei < edges.len) : (ei += edge_fields_count) {
            const to_node = edges[ei + parsed.edge_to_node_offset];
            if (to_node >= nodes.len or to_node % node_field_count != 0) {
                return error.InvalidSnapshot;
            }
        }

        self.* = .{
            .allocator = allocator,
            .arena_state = arena_state,
            .nodes = nodes,
            .edges = edges,
            .strings = parsed.strings,
            .node_field_count = node_field_count,
            .node_type_offset = parsed.node_type_offset,
            .node_name_offset = parsed.node_name_offset,
            .node_id_offset = parsed.node_id_offset,
            .node_self_size_offset = parsed.node_self_size_offset,
            .node_edge_count_offset = parsed.node_edge_count_offset,
            .node_trace_node_id_offset = parsed.node_trace_node_id_offset,
            .node_detachedness_offset = parsed.node_detachedness_offset,
            .node_types = parsed.node_types,
            .node_array_type = findTypeIndex(parsed.node_types, "array"),
            .node_hidden_type = findTypeIndex(parsed.node_types, "hidden"),
            .node_object_type = findTypeIndex(parsed.node_types, "object"),
            .node_native_type = findTypeIndex(parsed.node_types, "native"),
            .node_string_type = findTypeIndex(parsed.node_types, "string"),
            .node_cons_string_type = findTypeIndex(parsed.node_types, "concatenated string"),
            .node_sliced_string_type = findTypeIndex(parsed.node_types, "sliced string"),
            .node_code_type = findTypeIndex(parsed.node_types, "code"),
            .node_synthetic_type = findTypeIndex(parsed.node_types, "synthetic"),
            .node_closure_type = findTypeIndex(parsed.node_types, "closure"),
            .node_regexp_type = findTypeIndex(parsed.node_types, "regexp"),
            .node_number_type = findTypeIndex(parsed.node_types, "number"),
            .edge_fields_count = edge_fields_count,
            .edge_type_offset = parsed.edge_type_offset,
            .edge_name_offset = parsed.edge_name_offset,
            .edge_to_node_offset = parsed.edge_to_node_offset,
            .edge_types = parsed.edge_types,
            .edge_element_type = findTypeIndex(parsed.edge_types, "element"),
            .edge_hidden_type = findTypeIndex(parsed.edge_types, "hidden"),
            .edge_internal_type = findTypeIndex(parsed.edge_types, "internal"),
            .edge_shortcut_type = findTypeIndex(parsed.edge_types, "shortcut"),
            .edge_weak_type = findTypeIndex(parsed.edge_types, "weak"),
            .edge_invisible_type = findTypeIndex(parsed.edge_types, "invisible"),
            .edge_property_type = findTypeIndex(parsed.edge_types, "property"),
            .node_count = node_count,
            .edge_count = edge_count,
            .root_node_index = parsed.root_index,
            .extra_native_bytes = parsed.extra_native_bytes,
            .first_edge_indexes = &.{},
            .first_retainer_index = &.{},
            .retaining_nodes = &.{},
            .retaining_edges = &.{},
            .detachedness_and_class_index = &.{},
            .flags = &.{},
            .dominators_tree = &.{},
            .retained_sizes = &.{},
            .first_dominated_node_index = &.{},
            .dominated_nodes = &.{},
            .node_distances = &.{},
            .node_native_context_attribution = &.{},
            .native_context_ordinals = &.{},
            .native_context_sizes = .{ .native_contexts = &.{}, .shared_size = 0, .no_attribution_size = 0 },
            .statistics = .{
                .total = 0,
                .native = .{ .total = 0, .typed_arrays = 0 },
                .v8heap = .{ .total = 0, .code = 0, .js_arrays = 0, .strings = 0, .system = 0 },
            },
            .max_js_object_id = 0,
            .id_to_class_key = .empty,
        };
        errdefer self.deinitPartial();

        // Exact JSHeapSnapshot.initialize order:
        try self.buildEdgeIndexes();
        try self.buildRetainers();
        try self.initDetachednessAndClassIndex();
        try self.propagateDOMState();
        try self.calculateFlags();
        var essential = try self.initEssentialEdges();
        defer essential.deinit(allocator);
        try self.calculateShallowSizes();
        try self.calculateDominatorsAndRetainedSizes(essential);
        try self.buildDominatedNodes();
        try self.calculateDistances();
        try self.calculateObjectNames();
        try self.inferAndApplyInterfaceDefinitions();
        try self.buildLocationMap(locations.items, parsed.location_field_count, parsed.location_index_offset, parsed.location_script_id_offset, parsed.location_line_offset, parsed.location_column_offset);
        try self.calculateNativeContextAttribution();
        try self.calculateNativeContextSizes();
        self.calculateStatistics();
        self.max_js_object_id = self.computeMaxJsNodeId();
        try self.initClassIds();

        return self;
    }

    pub fn deinit(self: *HeapSnapshot) void {
        self.deinitPartial();
        self.allocator.destroy(self);
    }

    fn deinitPartial(self: *HeapSnapshot) void {
        const a = self.allocator;
        if (self.first_edge_indexes.len > 0) a.free(self.first_edge_indexes);
        if (self.first_retainer_index.len > 0) a.free(self.first_retainer_index);
        if (self.retaining_nodes.len > 0) a.free(self.retaining_nodes);
        if (self.retaining_edges.len > 0) a.free(self.retaining_edges);
        if (self.detachedness_and_class_index.len > 0) a.free(self.detachedness_and_class_index);
        if (self.flags.len > 0) a.free(self.flags);
        if (self.dominators_tree.len > 0) a.free(self.dominators_tree);
        if (self.retained_sizes.len > 0) a.free(self.retained_sizes);
        if (self.first_dominated_node_index.len > 0) a.free(self.first_dominated_node_index);
        if (self.dominated_nodes.len > 0) a.free(self.dominated_nodes);
        if (self.node_distances.len > 0) a.free(self.node_distances);
        self.location_map.deinit(a);
        if (self.node_native_context_attribution.len > 0) a.free(self.node_native_context_attribution);
        if (self.native_context_ordinals.len > 0) a.free(self.native_context_ordinals);
        if (self.native_context_sizes.native_contexts.len > 0) a.free(self.native_context_sizes.native_contexts);
        self.id_to_class_key.deinit(a);
        self.class_key_to_id.deinit(a);
        self.strings.deinit(a);
        a.free(self.nodes);
        a.free(self.edges);
        self.arena_state.deinit();
    }

    // -----------------------------------------------------------------------
    // Low-level node / edge accessors
    // -----------------------------------------------------------------------

    inline fn stringAt(self: *const HeapSnapshot, idx: u32) []const u8 {
        if (idx >= self.strings.items.len) return "";
        return self.strings.items[idx];
    }

    fn addString(self: *HeapSnapshot, s: []const u8) Allocator.Error!u32 {
        const copy = try self.arena_state.allocator().dupe(u8, s);
        const idx: u32 = @intCast(self.strings.items.len);
        try self.strings.append(self.allocator, copy);
        return idx;
    }

    inline fn nodeRawType(self: *const HeapSnapshot, node_index: u32) u32 {
        return self.nodes[node_index + self.node_type_offset];
    }

    inline fn nodeTypeName(self: *const HeapSnapshot, node_index: u32) []const u8 {
        const t = self.nodeRawType(node_index);
        if (t >= self.node_types.len) return "unknown";
        return self.node_types[t];
    }

    inline fn nodeRawNameIndex(self: *const HeapSnapshot, node_index: u32) u32 {
        return self.nodes[node_index + self.node_name_offset];
    }

    inline fn nodeRawName(self: *const HeapSnapshot, node_index: u32) []const u8 {
        return self.stringAt(self.nodeRawNameIndex(node_index));
    }

    inline fn nodeId(self: *const HeapSnapshot, node_index: u32) u64 {
        return self.nodes[node_index + self.node_id_offset];
    }

    inline fn nodeSelfSize(self: *const HeapSnapshot, node_index: u32) u64 {
        return self.nodes[node_index + self.node_self_size_offset];
    }

    inline fn nodeOrdinal(self: *const HeapSnapshot, node_index: u32) u32 {
        return node_index / self.node_field_count;
    }

    inline fn nodeRetainedSize(self: *const HeapSnapshot, node_index: u32) u64 {
        return self.retained_sizes[self.nodeOrdinal(node_index)];
    }

    inline fn nodeDistance(self: *const HeapSnapshot, node_index: u32) i32 {
        return self.node_distances[self.nodeOrdinal(node_index)];
    }

    inline fn nodeDetachedness(self: *const HeapSnapshot, node_index: u32) DomLinkState {
        const raw = self.detachedness_and_class_index[self.nodeOrdinal(node_index)] & bitmask_dom_link_state;
        return switch (raw) {
            1 => .attached,
            2 => .detached,
            else => .unknown,
        };
    }

    inline fn setNodeDetachedness(self: *HeapSnapshot, node_index: u32, state: DomLinkState) void {
        const ord = self.nodeOrdinal(node_index);
        var v = self.detachedness_and_class_index[ord];
        v &= ~bitmask_dom_link_state;
        v |= @backingInt(state);
        self.detachedness_and_class_index[ord] = v;
    }

    inline fn nodeClassIndex(self: *const HeapSnapshot, node_index: u32) u32 {
        return self.detachedness_and_class_index[self.nodeOrdinal(node_index)] >> shift_class_index;
    }

    inline fn setNodeClassIndex(self: *HeapSnapshot, node_index: u32, idx: u32) void {
        const ord = self.nodeOrdinal(node_index);
        var v = self.detachedness_and_class_index[ord];
        v &= bitmask_dom_link_state;
        v |= (idx << shift_class_index);
        self.detachedness_and_class_index[ord] = v;
    }

    inline fn nodeClassName(self: *const HeapSnapshot, node_index: u32) []const u8 {
        return self.stringAt(self.nodeClassIndex(node_index));
    }

    inline fn isNodeHidden(self: *const HeapSnapshot, node_index: u32) bool {
        return self.nodeRawType(node_index) == self.node_hidden_type;
    }

    inline fn isNodeArray(self: *const HeapSnapshot, node_index: u32) bool {
        return self.nodeRawType(node_index) == self.node_array_type;
    }

    inline fn isNodeSynthetic(self: *const HeapSnapshot, node_index: u32) bool {
        return self.nodeRawType(node_index) == self.node_synthetic_type;
    }

    inline fn isNodeNative(self: *const HeapSnapshot, node_index: u32) bool {
        return self.nodeRawType(node_index) == self.node_native_type;
    }

    inline fn isNodeDocumentDomTreesRoot(self: *const HeapSnapshot, node_index: u32) bool {
        return self.isNodeSynthetic(node_index) and std.mem.eql(u8, self.nodeRawName(node_index), "(Document DOM trees)");
    }

    inline fn isNodeUserRoot(self: *const HeapSnapshot, node_index: u32) bool {
        return !self.isNodeSynthetic(node_index) or self.isNodeDocumentDomTreesRoot(node_index);
    }

    inline fn isPlainJsObject(self: *const HeapSnapshot, node_index: u32) bool {
        return self.nodeRawType(node_index) == self.node_object_type and std.mem.eql(u8, self.nodeRawName(node_index), "Object");
    }

    inline fn isContextObject(self: *const HeapSnapshot, node_index: u32) bool {
        const name = self.nodeRawName(node_index);
        return std.mem.eql(u8, name, "system / Context") or std.mem.startsWith(u8, name, "system / Context / ");
    }

    inline fn isNativeContextOrdinal(self: *const HeapSnapshot, ord: u32) bool {
        const name = self.nodeRawName(ord * self.node_field_count);
        return std.mem.eql(u8, name, "system / NativeContext") or
            std.mem.startsWith(u8, name, "system / NativeContext / ") or
            std.mem.eql(u8, name, "Detached system / NativeContext") or
            std.mem.startsWith(u8, name, "Detached system / NativeContext / ");
    }

    inline fn nodeEdgesCount(self: *const HeapSnapshot, node_index: u32) u32 {
        const ord = self.nodeOrdinal(node_index);
        return (self.first_edge_indexes[ord + 1] - self.first_edge_indexes[ord]) / self.edge_fields_count;
    }

    inline fn nodeRetainersCount(self: *const HeapSnapshot, node_index: u32) u32 {
        const ord = self.nodeOrdinal(node_index);
        return self.first_retainer_index[ord + 1] - self.first_retainer_index[ord];
    }

    inline fn edgeRawType(self: *const HeapSnapshot, edge_index: u32) u32 {
        return self.edges[edge_index + self.edge_type_offset];
    }

    inline fn edgeTypeName(self: *const HeapSnapshot, edge_index: u32) []const u8 {
        const t = self.edgeRawType(edge_index);
        if (t >= self.edge_types.len) return "unknown";
        return self.edge_types[t];
    }

    inline fn edgeNameOrIndex(self: *const HeapSnapshot, edge_index: u32) u32 {
        return self.edges[edge_index + self.edge_name_offset];
    }

    inline fn edgeToNode(self: *const HeapSnapshot, edge_index: u32) u32 {
        return self.edges[edge_index + self.edge_to_node_offset];
    }

    inline fn edgeHasRawStringName(self: *const HeapSnapshot, edge_index: u32) bool {
        const t = self.edgeRawType(edge_index);
        return t != self.edge_element_type and t != self.edge_hidden_type;
    }

    /// JSHeapSnapshotEdge.hasStringName()
    fn edgeHasStringName(self: *const HeapSnapshot, edge_index: u32) bool {
        if (self.edgeRawType(edge_index) != self.edge_shortcut_type) {
            return self.edgeHasRawStringName(edge_index);
        }
        const raw = self.stringAt(self.edgeNameOrIndex(edge_index));
        return parseJsIntPrefix(raw) == null;
    }

    /// JSHeapSnapshotEdge.name() allocated in `arena`.
    fn edgeNameAlloc(self: *const HeapSnapshot, arena: Allocator, edge_index: u32) Allocator.Error![]const u8 {
        if (!self.edgeHasRawStringName(edge_index)) {
            return std.fmt.allocPrint(arena, "{d}", .{self.edgeNameOrIndex(edge_index)});
        }
        const raw = self.stringAt(self.edgeNameOrIndex(edge_index));
        if (self.edgeRawType(edge_index) == self.edge_shortcut_type) {
            if (parseJsIntPrefix(raw)) |n| {
                return std.fmt.allocPrint(arena, "{d}", .{n});
            }
        }
        return raw;
    }

    /// JSHeapSnapshotNode.name() allocated in `arena`.
    pub fn nodeNameAlloc(self: *const HeapSnapshot, arena: Allocator, node_index: u32) Allocator.Error![]const u8 {
        const raw_type = self.nodeRawType(node_index);
        if (raw_type == self.node_cons_string_type) {
            return self.consStringName(arena, node_index);
        }
        if (raw_type == self.node_object_type and std.mem.eql(u8, self.nodeRawName(node_index), "Object")) {
            return self.plainObjectName(arena, node_index);
        }
        return self.nodeRawName(node_index);
    }

    fn consStringName(self: *const HeapSnapshot, arena: Allocator, start_node_index: u32) Allocator.Error![]const u8 {
        var stack: std.ArrayList(u32) = .empty;
        try stack.append(arena, start_node_index);
        var out: std.ArrayList(u8) = .empty;
        while (stack.items.len > 0 and out.items.len < 1024) {
            const idx = stack.pop().?;
            if (self.nodeRawType(idx) != self.node_cons_string_type) {
                try out.appendSlice(arena, self.nodeRawName(idx));
                continue;
            }
            const ord = self.nodeOrdinal(idx);
            const begin = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            var first_idx: u32 = 0;
            var second_idx: u32 = 0;
            var ei = begin;
            while (ei < end and (first_idx == 0 or second_idx == 0)) : (ei += self.edge_fields_count) {
                if (self.edgeRawType(ei) == self.edge_internal_type) {
                    const edge_name = self.stringAt(self.edgeNameOrIndex(ei));
                    if (std.mem.eql(u8, edge_name, "first")) {
                        first_idx = self.edgeToNode(ei);
                    } else if (std.mem.eql(u8, edge_name, "second")) {
                        second_idx = self.edgeToNode(ei);
                    }
                }
            }
            try stack.append(arena, second_idx);
            try stack.append(arena, first_idx);
        }
        return out.items;
    }

    fn plainObjectName(self: *const HeapSnapshot, arena: Allocator, node_index: u32) Allocator.Error![]const u8 {
        const ord = self.nodeOrdinal(node_index);
        const begin = self.first_edge_indexes[ord];
        const end = self.first_edge_indexes[ord + 1];
        var start_parts: std.ArrayList([]const u8) = .empty;
        var end_parts: std.ArrayList([]const u8) = .empty;
        var start_len: usize = 1; // "{"
        var end_len: usize = 1; // "}"

        if (begin < end) {
            var from_start: usize = begin;
            var from_end: usize = end - self.edge_fields_count;
            var next_from_end = false;
            var truncated = false;
            while (from_start <= from_end) {
                const ei: u32 = @intCast(if (next_from_end) from_end else from_start);
                const is_prop = self.edgeRawType(ei) == self.edge_property_type;
                const raw_name = if (is_prop and self.edgeHasRawStringName(ei)) self.stringAt(self.edgeNameOrIndex(ei)) else "";
                if (!is_prop or std.mem.eql(u8, raw_name, "__proto__")) {
                    if (next_from_end) {
                        if (from_end < self.edge_fields_count) break;
                        from_end -= self.edge_fields_count;
                    } else {
                        from_start += self.edge_fields_count;
                    }
                    continue;
                }
                const formatted = try formatPropertyName(arena, raw_name);
                if (start_len > 1 and start_len + end_len + formatted.len > 100) {
                    truncated = true;
                    break;
                }
                if (next_from_end) {
                    try end_parts.append(arena, formatted);
                    if (end_len > 1) end_len += 2;
                    end_len += formatted.len;
                    if (from_end < self.edge_fields_count) {
                        from_start = from_end + 1;
                        break;
                    }
                    from_end -= self.edge_fields_count;
                } else {
                    try start_parts.append(arena, formatted);
                    if (start_len > 1) start_len += 2;
                    start_len += formatted.len;
                    from_start += self.edge_fields_count;
                }
                next_from_end = !next_from_end;
            }
            var out: std.ArrayList(u8) = .empty;
            try out.append(arena, '{');
            for (start_parts.items, 0..) |part, i| {
                if (i > 0) try out.appendSlice(arena, ", ");
                try out.appendSlice(arena, part);
            }
            if (truncated) {
                try out.appendSlice(arena, ", \u{2026}");
            }
            if (end_parts.items.len > 0) {
                try out.appendSlice(arena, ", ");
                var j = end_parts.items.len;
                while (j > 0) {
                    j -= 1;
                    try out.appendSlice(arena, end_parts.items[j]);
                    if (j > 0) try out.appendSlice(arena, ", ");
                }
            }
            try out.append(arena, '}');
            return out.items;
        }
        return "{}";
    }

    // -----------------------------------------------------------------------
    // Initialization pipeline (JSHeapSnapshot.initialize)
    // -----------------------------------------------------------------------

    fn buildEdgeIndexes(self: *HeapSnapshot) Error!void {
        const indexes = try self.allocator.alloc(u32, self.node_count + 1);
        self.first_edge_indexes = indexes;
        var edge_index: u32 = 0;
        for (0..self.node_count) |ord| {
            indexes[ord] = edge_index;
            const count = self.nodes[ord * self.node_field_count + self.node_edge_count_offset];
            const delta = std.math.mul(u32, count, self.edge_fields_count) catch return error.InvalidSnapshot;
            edge_index = std.math.add(u32, edge_index, delta) catch return error.InvalidSnapshot;
            if (edge_index > self.edges.len) return error.InvalidSnapshot;
        }
        indexes[self.node_count] = @intCast(self.edges.len);
    }

    fn buildRetainers(self: *HeapSnapshot) Allocator.Error!void {
        const a = self.allocator;
        const first_retainer = try a.alloc(u32, self.node_count + 1);
        self.first_retainer_index = first_retainer;
        @memset(first_retainer, 0);

        const retaining_nodes = try a.alloc(u32, self.edge_count);
        self.retaining_nodes = retaining_nodes;
        const retaining_edges = try a.alloc(u32, self.edge_count);
        self.retaining_edges = retaining_edges;

        if (self.edge_count == 0) return;

        for (0..self.edge_count) |edge_ord| {
            const to_ord = self.edgeToNode(@intCast(edge_ord * self.edge_fields_count)) / self.node_field_count;
            first_retainer[to_ord] += 1;
        }

        const counts = try a.alloc(u32, self.node_count);
        defer a.free(counts);
        var slot: u32 = 0;
        for (0..self.node_count) |ord| {
            const c = first_retainer[ord];
            counts[ord] = c;
            first_retainer[ord] = slot;
            slot += c;
        }
        first_retainer[self.node_count] = self.edge_count;

        // Fill backwards within each target node's retainer slice (exact DevTools order).
        for (0..self.node_count) |src_ord| {
            const begin = self.first_edge_indexes[src_ord];
            const end = self.first_edge_indexes[src_ord + 1];
            const src_node_index: u32 = @intCast(src_ord * self.node_field_count);
            var ei = begin;
            while (ei < end) : (ei += self.edge_fields_count) {
                const to_ord = self.edgeToNode(ei) / self.node_field_count;
                counts[to_ord] -= 1;
                const dst = first_retainer[to_ord] + counts[to_ord];
                retaining_nodes[dst] = src_node_index;
                retaining_edges[dst] = ei;
            }
        }
    }

    fn initDetachednessAndClassIndex(self: *HeapSnapshot) Allocator.Error!void {
        const arr = try self.allocator.alloc(u32, self.node_count);
        self.detachedness_and_class_index = arr;
        @memset(arr, 0);
        if (self.node_detachedness_offset) |off| {
            for (0..self.node_count) |ord| {
                arr[ord] = self.nodes[ord * self.node_field_count + off];
            }
        } else {
            for (0..self.node_count) |ord| {
                const node_index: u32 = @intCast(ord * self.node_field_count);
                if (self.nodeRawType(node_index) == self.node_native_type) {
                    if (std.mem.startsWith(u8, self.nodeRawName(node_index), "Detached ")) {
                        self.setNodeDetachedness(node_index, .detached);
                    }
                }
            }
        }
    }

    fn propagateDOMState(self: *HeapSnapshot) Allocator.Error!void {
        if (self.node_detachedness_offset == null) return;
        const a = self.allocator;
        const visited = try a.alloc(u8, self.node_count);
        defer a.free(visited);
        @memset(visited, 0);

        var attached: std.ArrayList(u32) = .empty;
        defer attached.deinit(a);
        var detached: std.ArrayList(u32) = .empty;
        defer detached.deinit(a);
        var string_cache: std.AutoHashMapUnmanaged(u32, u32) = .empty;
        defer string_cache.deinit(a);

        const processNode = struct {
            fn call(
                snap: *HeapSnapshot,
                vis: []u8,
                att: *std.ArrayList(u32),
                det: *std.ArrayList(u32),
                cache: *std.AutoHashMapUnmanaged(u32, u32),
                ord: u32,
                state: DomLinkState,
            ) Allocator.Error!void {
                if (vis[ord] != 0) return;
                const node_index = ord * snap.node_field_count;
                if (snap.nodeRawType(node_index) != snap.node_native_type) {
                    vis[ord] = 1;
                    return;
                }
                snap.setNodeDetachedness(node_index, state);
                switch (state) {
                    .attached => try att.append(snap.allocator, ord),
                    .detached => {
                        const old_idx = snap.nodeRawNameIndex(node_index);
                        const new_idx = if (cache.get(old_idx)) |cached| cached else blk: {
                            const prefixed = try std.fmt.allocPrint(snap.arena_state.allocator(), "Detached {s}", .{snap.stringAt(old_idx)});
                            const added: u32 = @intCast(snap.strings.items.len);
                            try snap.strings.append(snap.allocator, prefixed);
                            try cache.put(snap.allocator, old_idx, added);
                            break :blk added;
                        };
                        snap.nodes[node_index + snap.node_name_offset] = new_idx;
                        try det.append(snap.allocator, ord);
                    },
                    .unknown => {},
                }
                vis[ord] = 1;
            }
        }.call;

        for (0..self.node_count) |ord_usize| {
            const ord: u32 = @intCast(ord_usize);
            const state = self.nodeDetachedness(ord * self.node_field_count);
            if (state == .unknown) continue;
            try processNode(self, visited, &attached, &detached, &string_cache, ord, state);
        }

        while (attached.items.len > 0) {
            const parent = attached.pop().?;
            const begin = self.first_edge_indexes[parent];
            const end = self.first_edge_indexes[parent + 1];
            var ei = begin;
            while (ei < end) : (ei += self.edge_fields_count) {
                const et = self.edgeRawType(ei);
                if (et == self.edge_hidden_type or et == self.edge_invisible_type or et == self.edge_weak_type) continue;
                const child_ord = self.edgeToNode(ei) / self.node_field_count;
                try processNode(self, visited, &attached, &detached, &string_cache, child_ord, .attached);
            }
        }

        while (detached.items.len > 0) {
            const parent = detached.pop().?;
            if (self.nodeDetachedness(parent * self.node_field_count) == .attached) continue;
            const begin = self.first_edge_indexes[parent];
            const end = self.first_edge_indexes[parent + 1];
            var ei = begin;
            while (ei < end) : (ei += self.edge_fields_count) {
                const et = self.edgeRawType(ei);
                if (et == self.edge_hidden_type or et == self.edge_invisible_type or et == self.edge_weak_type) continue;
                const child_ord = self.edgeToNode(ei) / self.node_field_count;
                try processNode(self, visited, &attached, &detached, &string_cache, child_ord, .detached);
            }
        }
    }

    fn calculateFlags(self: *HeapSnapshot) Allocator.Error!void {
        const a = self.allocator;
        const flags = try a.alloc(u8, self.node_count);
        self.flags = flags;
        @memset(flags, 0);

        // 1. markDetachedDOMTreeNodes
        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            if (self.nodeRawType(node_index) == self.node_native_type and self.nodeDetachedness(node_index) == .detached) {
                flags[ord] |= flag_detached_dom_tree_node;
            }
        }

        // 2. markQueriableHeapObjects
        var stack: std.ArrayList(u32) = .empty;
        defer stack.deinit(a);
        const root_ord = self.nodeOrdinal(self.root_node_index);
        {
            var ei = self.first_edge_indexes[root_ord];
            const end = self.first_edge_indexes[root_ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                const target = self.edgeToNode(ei);
                if (!self.isNodeSynthetic(target)) {
                    try stack.append(a, self.nodeOrdinal(target));
                }
            }
        }
        while (stack.items.len > 0) {
            const ord = stack.pop().?;
            if ((flags[ord] & flag_can_be_queried) != 0) continue;
            flags[ord] |= flag_can_be_queried;
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                const child_ord = self.edgeToNode(ei) / self.node_field_count;
                if ((flags[child_ord] & flag_can_be_queried) != 0) continue;
                const et = self.edgeRawType(ei);
                if (et == self.edge_hidden_type or et == self.edge_invisible_type or et == self.edge_internal_type or et == self.edge_weak_type) continue;
                try stack.append(a, child_ord);
            }
        }

        // 3. markPageOwnedNodes
        stack.clearRetainingCapacity();
        {
            var ei = self.first_edge_indexes[root_ord];
            const end = self.first_edge_indexes[root_ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                const et = self.edgeRawType(ei);
                const target = self.edgeToNode(ei);
                if (et == self.edge_element_type) {
                    if (!self.isNodeDocumentDomTreesRoot(target)) continue;
                } else if (et != self.edge_shortcut_type) {
                    continue;
                }
                const child_ord = self.nodeOrdinal(target);
                flags[child_ord] |= flag_page_object;
                try stack.append(a, child_ord);
            }
        }
        while (stack.items.len > 0) {
            const ord = stack.pop().?;
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                const child_ord = self.edgeToNode(ei) / self.node_field_count;
                if ((flags[child_ord] & flag_page_object) != 0) continue;
                if (self.edgeRawType(ei) == self.edge_weak_type) continue;
                flags[child_ord] |= flag_page_object;
                try stack.append(a, child_ord);
            }
        }
    }

    fn initEssentialEdges(self: *const HeapSnapshot) Allocator.Error!BitVector {
        var essential = try BitVector.init(self.allocator, self.edge_count);
        errdefer essential.deinit(self.allocator);
        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                if (self.computeIsEssentialEdge(node_index, ei)) {
                    essential.set(ei / self.edge_fields_count);
                }
            }
        }
        return essential;
    }

    fn computeIsEssentialEdge(self: *const HeapSnapshot, node_index: u32, edge_index: u32) bool {
        const edge_type = self.edgeRawType(edge_index);
        if (edge_type == self.edge_internal_type) {
            const edge_name = self.stringAt(self.edgeNameOrIndex(edge_index));
            if (parseWeakMapEdgeName(edge_name)) |match| {
                if (self.nodeId(node_index) == match.table_id) return false;
            }
        }
        if (edge_type == self.edge_weak_type) return false;
        const child_node_index = self.edgeToNode(edge_index);
        if (node_index == child_node_index) return false;
        if (node_index != self.root_node_index) {
            if (edge_type == self.edge_shortcut_type) return false;
            const node_ord = self.nodeOrdinal(node_index);
            const child_ord = self.nodeOrdinal(child_node_index);
            const node_is_page = (self.flags[node_ord] & flag_page_object) != 0;
            const child_is_page = (self.flags[child_ord] & flag_page_object) != 0;
            if (child_is_page and !node_is_page) return false;
        }
        return true;
    }

    fn hasUserRoots(self: *const HeapSnapshot) bool {
        const root_ord = self.nodeOrdinal(self.root_node_index);
        var ei = self.first_edge_indexes[root_ord];
        const end = self.first_edge_indexes[root_ord + 1];
        while (ei < end) : (ei += self.edge_fields_count) {
            if (self.isNodeUserRoot(self.edgeToNode(ei))) return true;
        }
        return false;
    }

    fn calculateShallowSizes(self: *HeapSnapshot) Allocator.Error!void {
        if (!self.hasUserRoots()) return;
        const a = self.allocator;
        const k_unvisited: u32 = std.math.maxInt(u32);
        const k_multi: u32 = std.math.maxInt(u32) - 1;

        const owners = try a.alloc(u32, self.node_count);
        defer a.free(owners);
        var worklist: std.ArrayList(u32) = .empty;
        defer worklist.deinit(a);

        for (0..self.node_count) |ord_usize| {
            const ord: u32 = @intCast(ord_usize);
            const node_index = ord * self.node_field_count;
            if (self.isNodeHidden(node_index) or self.isNodeArray(node_index) or (self.isNodeNative(node_index) and std.mem.eql(u8, self.nodeRawName(node_index), "system / ExternalStringData"))) {
                owners[ord] = k_unvisited;
            } else {
                owners[ord] = ord;
                try worklist.append(a, ord);
            }
        }

        while (worklist.items.len > 0) {
            const ord = worklist.pop().?;
            const owner = owners[ord];
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                if (self.edgeRawType(ei) == self.edge_weak_type) continue;
                const target_ord = self.edgeToNode(ei) / self.node_field_count;
                const cur = owners[target_ord];
                if (cur == k_unvisited) {
                    owners[target_ord] = owner;
                    try worklist.append(a, target_ord);
                } else if (cur == target_ord or cur == owner or cur == k_multi) {
                    // unchanged
                } else {
                    owners[target_ord] = k_multi;
                    try worklist.append(a, target_ord);
                }
            }
        }

        for (0..self.node_count) |ord_usize| {
            const ord: u32 = @intCast(ord_usize);
            const owner_ord = owners[ord];
            if (owner_ord == k_unvisited or owner_ord == k_multi or owner_ord == ord) continue;
            const owner_idx = owner_ord * self.node_field_count;
            if (self.isNodeSynthetic(owner_idx) or owner_idx == self.root_node_index) continue;
            const owned_idx = ord * self.node_field_count;
            const size = self.nodes[owned_idx + self.node_self_size_offset];
            self.nodes[owned_idx + self.node_self_size_offset] = 0;
            self.nodes[owner_idx + self.node_self_size_offset] +|= size;
        }
    }

    fn hasOnlyWeakRetainers(self: *const HeapSnapshot, essential: BitVector, node_ord: u32) bool {
        const begin = self.first_retainer_index[node_ord];
        const end = self.first_retainer_index[node_ord + 1];
        for (begin..end) |ri| {
            if (essential.get(self.retaining_edges[ri] / self.edge_fields_count)) return false;
        }
        return true;
    }

    /// Lengauer-Tarjan dominator tree + retained sizes (exact DevTools implementation).
    fn calculateDominatorsAndRetainedSizes(self: *HeapSnapshot, essential: BitVector) Allocator.Error!void {
        const a = self.allocator;
        const n_nodes = self.node_count;
        const arr_len = n_nodes + 1;

        const parent = try a.alloc(u32, arr_len);
        defer a.free(parent);
        @memset(parent, 0);
        const ancestor = try a.alloc(u32, arr_len);
        defer a.free(ancestor);
        @memset(ancestor, 0);
        const vertex = try a.alloc(u32, arr_len);
        defer a.free(vertex);
        @memset(vertex, 0);
        const label = try a.alloc(u32, arr_len);
        defer a.free(label);
        @memset(label, 0);
        const semi = try a.alloc(u32, arr_len);
        defer a.free(semi);
        @memset(semi, 0);
        const dom = try a.alloc(u32, arr_len);
        defer a.free(dom);
        @memset(dom, 0);
        const next_edge = try a.alloc(u32, arr_len);
        defer a.free(next_edge);
        @memset(next_edge, 0);
        const comp_stack = try a.alloc(u32, arr_len);
        defer a.free(comp_stack);
        // Intrusive singly-linked list buckets: each vertex w is inserted into at most one bucket once.
        const bucket_head = try a.alloc(u32, arr_len);
        defer a.free(bucket_head);
        @memset(bucket_head, 0);
        const bucket_next = try a.alloc(u32, arr_len);
        defer a.free(bucket_next);
        @memset(bucket_next, 0);

        var dfs_n: u32 = 0;

        const DfsCtx = struct {
            snap: *const HeapSnapshot,
            essential: BitVector,
            parent: []u32,
            vertex: []u32,
            label: []u32,
            semi: []u32,
            next_edge: []u32,
            dfs_n: *u32,

            fn run(ctx: @This(), root: u32) void {
                const root_ord = root - 1;
                ctx.next_edge[root_ord] = ctx.snap.first_edge_indexes[root_ord];
                var v = root;
                while (v != 0) {
                    if (ctx.semi[v] == 0) {
                        ctx.dfs_n.* += 1;
                        ctx.semi[v] = ctx.dfs_n.*;
                        ctx.vertex[ctx.dfs_n.*] = v;
                        ctx.label[v] = v;
                    }
                    var v_next = ctx.parent[v];
                    const v_ord = v - 1;
                    while (ctx.next_edge[v_ord] < ctx.snap.first_edge_indexes[v_ord + 1]) {
                        const ei = ctx.next_edge[v_ord];
                        ctx.next_edge[v_ord] += ctx.snap.edge_fields_count;
                        if (!ctx.essential.get(ei / ctx.snap.edge_fields_count)) continue;
                        const w_ord = ctx.snap.edgeToNode(ei) / ctx.snap.node_field_count;
                        const w = w_ord + 1;
                        if (ctx.semi[w] == 0) {
                            ctx.parent[w] = v;
                            ctx.next_edge[w_ord] = ctx.snap.first_edge_indexes[w_ord];
                            v_next = w;
                            break;
                        }
                    }
                    v = v_next;
                }
            }
        };

        const dfs_ctx: DfsCtx = .{
            .snap = self,
            .essential = essential,
            .parent = parent,
            .vertex = vertex,
            .label = label,
            .semi = semi,
            .next_edge = next_edge,
            .dfs_n = &dfs_n,
        };

        const root_ord = self.nodeOrdinal(self.root_node_index);
        const r = root_ord + 1;
        dfs_ctx.run(r);

        if (dfs_n < n_nodes) {
            var v: u32 = 1;
            while (v <= n_nodes) : (v += 1) {
                if (semi[v] == 0 and self.hasOnlyWeakRetainers(essential, v - 1)) {
                    parent[v] = r;
                    dfs_ctx.run(v);
                }
            }
        }
        if (dfs_n < n_nodes) {
            var v: u32 = 1;
            while (v <= n_nodes) : (v += 1) {
                if (semi[v] == 0) {
                    parent[v] = r;
                    dfs_n += 1;
                    semi[v] = dfs_n;
                    vertex[dfs_n] = v;
                    label[v] = v;
                }
            }
        }

        const evalFn = struct {
            fn evaluate(v_in: u32, anc: []u32, lbl: []u32, sm: []u32, stack: []u32) u32 {
                if (anc[v_in] == 0) return v_in;
                var sp: usize = 0;
                var v = v_in;
                while (anc[anc[v]] != 0) {
                    sp += 1;
                    stack[sp] = v;
                    v = anc[v];
                }
                while (sp > 0) {
                    const w = stack[sp];
                    sp -= 1;
                    if (sm[lbl[anc[w]]] < sm[lbl[w]]) {
                        lbl[w] = lbl[anc[w]];
                    }
                    anc[w] = anc[anc[w]];
                }
                return lbl[v_in];
            }
        }.evaluate;

        if (dfs_n >= 2) {
            var i: u32 = dfs_n;
            while (i >= 2) : (i -= 1) {
                const w = vertex[i];
                const w_ord = w - 1;
                var is_orphan = true;
                const r_begin = self.first_retainer_index[w_ord];
                const r_end = self.first_retainer_index[w_ord + 1];
                for (r_begin..r_end) |ri| {
                    if (!essential.get(self.retaining_edges[ri] / self.edge_fields_count)) continue;
                    is_orphan = false;
                    const v_ord = self.retaining_nodes[ri] / self.node_field_count;
                    const u = evalFn(v_ord + 1, ancestor, label, semi, comp_stack);
                    if (semi[u] < semi[w]) {
                        semi[w] = semi[u];
                    }
                }
                if (is_orphan) {
                    semi[w] = semi[r];
                }
                const target_bucket = vertex[semi[w]];
                bucket_next[w] = bucket_head[target_bucket];
                bucket_head[target_bucket] = w;
                ancestor[w] = parent[w];

                const p = parent[w];
                var v = bucket_head[p];
                bucket_head[p] = 0;
                while (v != 0) {
                    const next_v = bucket_next[v];
                    const u = evalFn(v, ancestor, label, semi, comp_stack);
                    dom[v] = if (semi[u] < semi[v]) u else p;
                    v = next_v;
                }
            }
        }

        dom[0] = r;
        dom[r] = r;
        if (dfs_n >= 2) {
            var i: u32 = 2;
            while (i <= dfs_n) : (i += 1) {
                const w = vertex[i];
                if (dom[w] != vertex[semi[w]]) {
                    dom[w] = dom[dom[w]];
                }
            }
        }

        const dominators_tree = try a.alloc(u32, n_nodes);
        self.dominators_tree = dominators_tree;
        const retained_sizes = try a.alloc(u64, n_nodes);
        self.retained_sizes = retained_sizes;

        for (0..n_nodes) |ord| {
            dominators_tree[ord] = dom[ord + 1] - 1;
            retained_sizes[ord] = self.nodes[ord * self.node_field_count + self.node_self_size_offset];
        }

        if (dfs_n >= 2) {
            var i: u32 = dfs_n;
            while (i > 1) : (i -= 1) {
                const ord = vertex[i] - 1;
                const dom_ord = dominators_tree[ord];
                retained_sizes[dom_ord] += retained_sizes[ord];
            }
        }
    }

    fn buildDominatedNodes(self: *HeapSnapshot) Error!void {
        const a = self.allocator;
        const n_nodes = self.node_count;
        const index_array = try a.alloc(u32, n_nodes + 1);
        self.first_dominated_node_index = index_array;
        @memset(index_array, 0);

        if (n_nodes <= 1) {
            self.dominated_nodes = &.{};
            return;
        }

        const dominated = try a.alloc(u32, n_nodes - 1);
        self.dominated_nodes = dominated;

        const root_ord = self.nodeOrdinal(self.root_node_index);
        for (0..n_nodes) |ord| {
            if (ord == root_ord) continue;
            index_array[self.dominators_tree[ord]] += 1;
        }

        const counts = try a.alloc(u32, n_nodes);
        defer a.free(counts);
        var pos: u32 = 0;
        for (0..n_nodes) |ord| {
            const c = index_array[ord];
            counts[ord] = c;
            index_array[ord] = pos;
            pos += c;
        }
        index_array[n_nodes] = n_nodes - 1;

        for (0..n_nodes) |ord| {
            if (ord == root_ord) continue;
            const dom_ord = self.dominators_tree[ord];
            counts[dom_ord] -= 1;
            dominated[index_array[dom_ord] + counts[dom_ord]] = @intCast(ord * self.node_field_count);
        }
    }

    fn calculateDistances(self: *HeapSnapshot) Allocator.Error!void {
        const a = self.allocator;
        const distances = try a.alloc(i32, self.node_count);
        self.node_distances = distances;
        @memset(distances, no_distance);

        const queue = try a.alloc(u32, self.node_count);
        defer a.free(queue);
        var q_len: usize = 0;

        var pending_ephemeron: std.StringHashMapUnmanaged(void) = .empty;
        defer pending_ephemeron.deinit(a);

        const root_ord = self.nodeOrdinal(self.root_node_index);
        var ei = self.first_edge_indexes[root_ord];
        const end = self.first_edge_indexes[root_ord + 1];
        while (ei < end) : (ei += self.edge_fields_count) {
            const target = self.edgeToNode(ei);
            if (self.isNodeUserRoot(target)) {
                const ord = self.nodeOrdinal(target);
                if (distances[ord] == no_distance) {
                    distances[ord] = 1;
                    queue[q_len] = target;
                    q_len += 1;
                }
            }
        }
        try self.bfsDistances(queue, q_len, distances, &pending_ephemeron);

        distances[root_ord] = if (q_len > 0) base_system_distance else 0;
        queue[0] = self.root_node_index;
        try self.bfsDistances(queue, 1, distances, &pending_ephemeron);
    }

    fn bfsDistances(
        self: *const HeapSnapshot,
        queue: []u32,
        initial_len: usize,
        distances: []i32,
        pending_ephemeron: *std.StringHashMapUnmanaged(void),
    ) Allocator.Error!void {
        var idx: usize = 0;
        var q_len = initial_len;
        while (idx < q_len) : (idx += 1) {
            const node_index = queue[idx];
            const ord = self.nodeOrdinal(node_index);
            const next_dist = distances[ord] + 1;
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                const et = self.edgeRawType(ei);
                if (et == self.edge_weak_type) continue;
                const child_idx = self.edgeToNode(ei);
                const child_ord = self.nodeOrdinal(child_idx);
                if (distances[child_ord] != no_distance) continue;

                // JSHeapSnapshot.calculateDistances edge filter:
                if (self.isNodeHidden(node_index) and std.mem.eql(u8, self.nodeRawName(node_index), "system / NativeContext") and self.edgeHasRawStringName(ei) and std.mem.eql(u8, self.stringAt(self.edgeNameOrIndex(ei)), "sloppy_function_map")) {
                    continue;
                }
                if (self.isNodeArray(node_index) and std.mem.eql(u8, self.nodeRawName(node_index), "(map descriptors)")) {
                    const edge_num: i64 = if (!self.edgeHasRawStringName(ei))
                        @intCast(self.edgeNameOrIndex(ei))
                    else
                        (parseJsIntPrefix(self.stringAt(self.edgeNameOrIndex(ei))) orelse -1);
                    if (edge_num >= 2 and @mod(edge_num, 3) == 1) continue;
                }
                if (et == self.edge_internal_type) {
                    const edge_name = self.stringAt(self.edgeNameOrIndex(ei));
                    if (parseWeakMapEdgeName(edge_name)) |match| {
                        if (!pending_ephemeron.remove(match.duplicated_part)) {
                            try pending_ephemeron.put(self.allocator, match.duplicated_part, {});
                            continue;
                        }
                    }
                }

                distances[child_ord] = next_dist;
                queue[q_len] = child_idx;
                q_len += 1;
            }
        }
    }

    fn calculateObjectNames(self: *HeapSnapshot) Allocator.Error!void {
        const a = self.allocator;
        var string_table: std.StringHashMapUnmanaged(u32) = .empty;
        defer string_table.deinit(a);

        const getOrAdd = struct {
            fn call(snap: *HeapSnapshot, table: *std.StringHashMapUnmanaged(u32), s: []const u8) Allocator.Error!u32 {
                if (table.get(s)) |idx| return idx;
                const idx = try snap.addString(s);
                try table.put(snap.allocator, snap.stringAt(idx), idx);
                return idx;
            }
        }.call;

        const hidden_cls = try getOrAdd(self, &string_table, "(system)");
        const code_cls = try getOrAdd(self, &string_table, "(compiled code)");
        const func_cls = try getOrAdd(self, &string_table, "Function");
        const regexp_cls = try getOrAdd(self, &string_table, "RegExp");

        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            const raw_type = self.nodeRawType(node_index);
            const cls_idx: u32 = if (raw_type == self.node_hidden_type)
                hidden_cls
            else if (raw_type == self.node_object_type or raw_type == self.node_native_type) blk: {
                const name = self.nodeRawName(node_index);
                if (std.mem.startsWith(u8, name, "<")) {
                    if (std.mem.indexOfScalar(u8, name, ' ')) |sp| {
                        const trimmed = try std.fmt.allocPrint(self.arena_state.allocator(), "{s}>", .{name[0..sp]});
                        break :blk try getOrAdd(self, &string_table, trimmed);
                    }
                    break :blk try getOrAdd(self, &string_table, name);
                }
                if (std.mem.startsWith(u8, name, "Detached <")) {
                    if (std.mem.indexOfScalarPos(u8, name, 10, ' ')) |sp| {
                        const trimmed = try std.fmt.allocPrint(self.arena_state.allocator(), "{s}>", .{name[0..sp]});
                        break :blk try getOrAdd(self, &string_table, trimmed);
                    }
                    break :blk try getOrAdd(self, &string_table, name);
                }
                break :blk self.nodeRawNameIndex(node_index);
            } else if (raw_type == self.node_code_type)
                code_cls
            else if (raw_type == self.node_closure_type)
                func_cls
            else if (raw_type == self.node_regexp_type)
                regexp_cls
            else blk: {
                const wrapped = try std.fmt.allocPrint(self.arena_state.allocator(), "({s})", .{self.nodeTypeName(node_index)});
                break :blk try getOrAdd(self, &string_table, wrapped);
            };
            self.setNodeClassIndex(node_index, cls_idx);
        }
    }

    fn inferAndApplyInterfaceDefinitions(self: *HeapSnapshot) Allocator.Error!void {
        var tmp_arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer tmp_arena_state.deinit();
        const tmp = tmp_arena_state.allocator();

        const Candidate = struct {
            name: []const u8,
            properties: [][]const u8,
            count: usize,
        };
        var candidates: std.StringArrayHashMapUnmanaged(Candidate) = .empty;
        var total_object_count: usize = 0;

        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            if (!self.isPlainJsObject(node_index)) continue;
            total_object_count += 1;

            var name_buf: std.ArrayList(u8) = .empty;
            try name_buf.append(tmp, '{');
            var props: std.ArrayList([]const u8) = .empty;
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                if (self.edgeRawType(ei) != self.edge_property_type) continue;
                const edge_name = try self.edgeNameAlloc(tmp, ei);
                if (std.mem.eql(u8, edge_name, "__proto__")) continue;
                const formatted = try formatPropertyName(tmp, edge_name);
                if (name_buf.items.len > min_interface_property_count and name_buf.items.len + formatted.len > max_interface_name_length) {
                    break;
                }
                if (name_buf.items.len != 1) try name_buf.appendSlice(tmp, ", ");
                try name_buf.appendSlice(tmp, formatted);
                try props.append(tmp, edge_name);
            }
            if (props.items.len == 0) continue;
            try name_buf.append(tmp, '}');

            const gop = try candidates.getOrPut(tmp, name_buf.items);
            if (gop.found_existing) {
                gop.value_ptr.count += 1;
            } else {
                gop.value_ptr.* = .{
                    .name = name_buf.items,
                    .properties = props.items,
                    .count = 1,
                };
            }
        }

        if (candidates.count() == 0) return;

        const sorted = try tmp.dupe(Candidate, candidates.values());
        std.sort.block(Candidate, sorted, {}, struct {
            fn lessThan(_: void, a: Candidate, b: Candidate) bool {
                return a.count > b.count;
            }
        }.lessThan);

        const prop_threshold = total_object_count / min_object_proportion_per_interface;
        const min_count = @max(min_object_count_per_interface, prop_threshold);

        var kept_len: usize = 0;
        for (sorted) |c| {
            if (c.count < min_count) break;
            kept_len += 1;
        }
        if (kept_len == 0) return;
        const definitions = sorted[0..kept_len];

        // Build property trie (applyInterfaceDefinitions).
        const MatchInfo = struct {
            name: []const u8,
            property_count: usize,
            index: usize,
        };
        const TrieNode = struct {
            next: std.StringHashMapUnmanaged(*@This()) = .empty,
            match_info: ?MatchInfo = null,
            greatest_next: ?[]const u8 = null,
        };
        const selectBetter = struct {
            fn call(a_m: MatchInfo, b_opt: ?MatchInfo) MatchInfo {
                const b_m = b_opt orelse return a_m;
                if (a_m.property_count > b_m.property_count) return a_m;
                if (b_m.property_count > a_m.property_count) return b_m;
                return if (a_m.index <= b_m.index) a_m else b_m;
            }
        }.call;

        const root = try tmp.create(TrieNode);
        root.* = .{};
        for (definitions, 0..) |def, def_idx| {
            const props_sorted = try tmp.dupe([]const u8, def.properties);
            std.sort.block([]const u8, props_sorted, {}, stringLessThan);
            var cur = root;
            for (props_sorted) |prop| {
                const next_node = cur.next.get(prop) orelse blk: {
                    const created = try tmp.create(TrieNode);
                    created.* = .{};
                    try cur.next.put(tmp, prop, created);
                    if (cur.greatest_next == null or std.mem.order(u8, cur.greatest_next.?, prop) == .lt) {
                        cur.greatest_next = prop;
                    }
                    break :blk created;
                };
                cur = next_node;
            }
            if (cur.match_info == null) {
                cur.match_info = .{
                    .name = def.name,
                    .property_count = props_sorted.len,
                    .index = def_idx,
                };
            }
        }

        var interface_names: std.StringHashMapUnmanaged(u32) = .empty;
        const initial_match: MatchInfo = .{ .name = "Object", .property_count = 0, .index = std.math.maxInt(usize) };

        var node_props: std.ArrayList([]const u8) = .empty;
        var states: std.AutoArrayHashMapUnmanaged(*TrieNode, void) = .empty;
        var state_snapshot: std.ArrayList(*TrieNode) = .empty;

        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            if (!self.isPlainJsObject(node_index)) continue;

            node_props.clearRetainingCapacity();
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                if (self.edgeRawType(ei) == self.edge_property_type) {
                    try node_props.append(tmp, try self.edgeNameAlloc(tmp, ei));
                }
            }
            std.sort.block([]const u8, node_props.items, {}, stringLessThan);

            states.clearRetainingCapacity();
            try states.put(tmp, root, {});
            var best = selectBetter(initial_match, root.match_info);

            for (node_props.items) |prop| {
                state_snapshot.clearRetainingCapacity();
                try state_snapshot.appendSlice(tmp, states.keys());
                for (state_snapshot.items) |st| {
                    if (st.greatest_next == null or std.mem.order(u8, prop, st.greatest_next.?) != .lt) {
                        _ = states.swapRemove(st);
                    }
                    if (st.next.get(prop)) |nxt| {
                        try states.put(tmp, nxt, {});
                        best = selectBetter(best, nxt.match_info);
                    }
                }
            }

            const cls_idx: u32 = if (best.index == std.math.maxInt(usize))
                self.nodeRawNameIndex(node_index)
            else blk: {
                if (interface_names.get(best.name)) |existing| break :blk existing;
                const added = try self.addString(best.name);
                try interface_names.put(tmp, best.name, added);
                break :blk added;
            };
            self.setNodeClassIndex(node_index, cls_idx);
        }
    }

    fn buildLocationMap(
        self: *HeapSnapshot,
        locations: []const u32,
        field_count: u32,
        index_off: ?u32,
        script_off: ?u32,
        line_off: ?u32,
        col_off: ?u32,
    ) Allocator.Error!void {
        if (field_count == 0 or locations.len == 0) return;
        const i_off = index_off orelse return;
        const s_off = script_off orelse return;
        const l_off = line_off orelse return;
        const c_off = col_off orelse return;
        var i: usize = 0;
        while (i + field_count <= locations.len) : (i += field_count) {
            try self.location_map.put(self.allocator, locations[i + i_off], .{
                .script_id = locations[i + s_off],
                .line = locations[i + l_off],
                .column = locations[i + c_off],
            });
        }
    }

    fn calculateNativeContextAttribution(self: *HeapSnapshot) Allocator.Error!void {
        const a = self.allocator;
        const attribution = try a.alloc(i32, self.node_count);
        self.node_native_context_attribution = attribution;
        @memset(attribution, no_native_context);

        var is_fixed = try BitVector.init(a, self.node_count);
        defer is_fixed.deinit(a);

        // Precompute internal "native_context" and "map" edge targets.
        const nc_targets = try a.alloc(i32, self.node_count);
        defer a.free(nc_targets);
        @memset(nc_targets, -1);
        const map_targets = try a.alloc(i32, self.node_count);
        defer a.free(map_targets);
        @memset(map_targets, -1);

        var nc_str_idx: ?u32 = null;
        var map_str_idx: ?u32 = null;
        for (self.strings.items, 0..) |s, idx| {
            if (nc_str_idx == null and std.mem.eql(u8, s, "native_context")) nc_str_idx = @intCast(idx);
            if (map_str_idx == null and std.mem.eql(u8, s, "map")) map_str_idx = @intCast(idx);
        }

        if (nc_str_idx != null or map_str_idx != null) {
            for (0..self.node_count) |ord| {
                var ei = self.first_edge_indexes[ord];
                const end = self.first_edge_indexes[ord + 1];
                while (ei < end) : (ei += self.edge_fields_count) {
                    if (self.edgeRawType(ei) != self.edge_internal_type) continue;
                    const name_idx = self.edgeNameOrIndex(ei);
                    const child_ord = self.edgeToNode(ei) / self.node_field_count;
                    if (nc_str_idx != null and name_idx == nc_str_idx.? and nc_targets[ord] == -1 and self.isNativeContextOrdinal(child_ord)) {
                        nc_targets[ord] = @intCast(child_ord);
                    } else if (map_str_idx != null and name_idx == map_str_idx.? and map_targets[ord] == -1) {
                        map_targets[ord] = @intCast(child_ord);
                    }
                }
            }
        }

        var nc_ordinals: std.ArrayList(u32) = .empty;
        errdefer nc_ordinals.deinit(a);

        for (0..self.node_count) |ord_usize| {
            const ord: u32 = @intCast(ord_usize);
            if (self.isNativeContextOrdinal(ord)) {
                try nc_ordinals.append(a, ord);
                attribution[ord] = @intCast(ord);
                is_fixed.set(ord);
            } else {
                // Object -> Map -> MetaMap -> NativeContext
                const map_ord = map_targets[ord];
                if (map_ord >= 0) {
                    const meta_map_ord = map_targets[@intCast(map_ord)];
                    if (meta_map_ord >= 0) {
                        const nc_ord = nc_targets[@intCast(meta_map_ord)];
                        if (nc_ord >= 0) {
                            attribution[ord] = nc_ord;
                            is_fixed.set(ord);
                        }
                    }
                }
            }
        }
        self.native_context_ordinals = try nc_ordinals.toOwnedSlice(a);

        // BFS propagate attribution along non-shortcut, non-weak edges.
        var queue: std.ArrayList(u32) = .empty;
        defer queue.deinit(a);
        for (0..self.node_count) |ord| {
            if (is_fixed.get(ord)) try queue.append(a, @intCast(ord));
        }

        var qi: usize = 0;
        while (qi < queue.items.len) : (qi += 1) {
            const ord = queue.items[qi];
            const current = attribution[ord];
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                const et = self.edgeRawType(ei);
                if (et == self.edge_shortcut_type or et == self.edge_weak_type) continue;
                const child_ord = self.edgeToNode(ei) / self.node_field_count;
                if (child_ord == ord or is_fixed.get(child_ord)) continue;
                const prev = attribution[child_ord];
                const merged: i32 = if (prev == shared_native_context or current == shared_native_context)
                    shared_native_context
                else if (prev == no_native_context)
                    current
                else if (prev == current)
                    prev
                else
                    shared_native_context;
                if (merged != prev) {
                    attribution[child_ord] = merged;
                    try queue.append(a, child_ord);
                }
            }
        }
    }

    fn calculateNativeContextSizes(self: *HeapSnapshot) Allocator.Error!void {
        const a = self.allocator;
        const infos = try a.alloc(NativeContextInfo, self.native_context_ordinals.len);
        var ord_to_idx: std.AutoHashMapUnmanaged(u32, usize) = .empty;
        defer ord_to_idx.deinit(a);

        for (self.native_context_ordinals, 0..) |ord, idx| {
            const node_index = ord * self.node_field_count;
            infos[idx] = .{
                .node_id = self.nodeId(node_index),
                .node_index = node_index,
                .node_name = try self.nodeNameAlloc(self.arena_state.allocator(), node_index),
                .attributed_size = 0,
                .retained_size = self.nodeRetainedSize(node_index),
                .self_size = self.nodeSelfSize(node_index),
            };
            try ord_to_idx.put(a, ord, idx);
        }

        var shared_size: u64 = 0;
        var no_attr_size: u64 = 0;
        for (0..self.node_count) |ord| {
            const owner = self.node_native_context_attribution[ord];
            const self_size: u64 = self.nodes[ord * self.node_field_count + self.node_self_size_offset];
            if (owner == shared_native_context) {
                shared_size += self_size;
            } else if (owner == no_native_context) {
                no_attr_size += self_size;
            } else if (ord_to_idx.get(@intCast(owner))) |idx| {
                infos[idx].attributed_size += self_size;
            }
        }

        self.native_context_sizes = .{
            .native_contexts = infos,
            .shared_size = shared_size,
            .no_attribution_size = no_attr_size,
        };
    }

    fn calculateStatistics(self: *HeapSnapshot) void {
        var size_native: u64 = self.extra_native_bytes;
        var size_typed_arrays: u64 = 0;
        var size_code: u64 = 0;
        var size_strings: u64 = 0;
        var size_js_arrays: u64 = 0;
        var size_system: u64 = 0;

        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            const node_size = self.nodeSelfSize(node_index);
            const node_type = self.nodeRawType(node_index);
            if (node_type == self.node_hidden_type) {
                size_system += node_size;
                continue;
            }
            if (node_type == self.node_native_type) {
                size_native += node_size;
                if (std.mem.eql(u8, self.nodeRawName(node_index), "system / JSArrayBufferData")) {
                    size_typed_arrays += node_size;
                }
            } else if (node_type == self.node_code_type) {
                size_code += node_size;
            } else if (node_type == self.node_cons_string_type or node_type == self.node_sliced_string_type or node_type == self.node_string_type) {
                size_strings += node_size;
            } else if (std.mem.eql(u8, self.nodeRawName(node_index), "Array")) {
                size_js_arrays += self.calculateArraySize(node_index);
            }
        }

        const total_size = self.nodeRetainedSize(self.root_node_index) + self.extra_native_bytes;
        self.statistics = .{
            .total = total_size,
            .native = .{
                .total = size_native,
                .typed_arrays = size_typed_arrays,
            },
            .v8heap = .{
                .total = total_size -| size_native,
                .code = size_code,
                .js_arrays = size_js_arrays,
                .strings = size_strings,
                .system = size_system,
            },
        };
    }

    fn calculateArraySize(self: *const HeapSnapshot, node_index: u32) u64 {
        var size = self.nodeSelfSize(node_index);
        const ord = self.nodeOrdinal(node_index);
        var ei = self.first_edge_indexes[ord];
        const end = self.first_edge_indexes[ord + 1];
        while (ei < end) : (ei += self.edge_fields_count) {
            if (self.edgeRawType(ei) != self.edge_internal_type) continue;
            if (!std.mem.eql(u8, self.stringAt(self.edgeNameOrIndex(ei)), "elements")) continue;
            const elements_idx = self.edgeToNode(ei);
            if (self.nodeRetainersCount(elements_idx) == 1) {
                size += self.nodeSelfSize(elements_idx);
            }
            break;
        }
        return size;
    }

    fn computeMaxJsNodeId(self: *const HeapSnapshot) u64 {
        var max_id: u64 = 0;
        for (0..self.node_count) |ord| {
            const id = self.nodeId(@intCast(ord * self.node_field_count));
            if (id % 2 == 0) continue;
            if (id > max_id) max_id = id;
        }
        return max_id;
    }

    fn initClassIds(self: *HeapSnapshot) Allocator.Error!void {
        // 1-indexed array where index 0 is unused "" (HeapSnapshotManager.ts).
        try self.id_to_class_key.append(self.allocator, "");
        var tmp_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer tmp_arena.deinit();
        const agg_map = try self.computeAggregatesMap(tmp_arena.allocator(), null);
        for (agg_map.keys()) |key| {
            const owned_key = try self.arena_state.allocator().dupe(u8, key);
            const id: u32 = @intCast(self.id_to_class_key.items.len);
            try self.id_to_class_key.append(self.allocator, owned_key);
            try self.class_key_to_id.put(self.allocator, owned_key, id);
        }
    }

    // -----------------------------------------------------------------------
    // Filters & Aggregates
    // -----------------------------------------------------------------------

    const NodeFilter = struct {
        bitmap: ?BitVector = null,
        invert_bitmap: bool = false,
        native_context_target: ?i32 = null,

        fn deinit(self: *NodeFilter, allocator: Allocator) void {
            if (self.bitmap) |*bm| bm.deinit(allocator);
        }

        fn matches(self: *const NodeFilter, snap: *const HeapSnapshot, node_index: u32) bool {
            const ord = snap.nodeOrdinal(node_index);
            if (self.native_context_target) |target| {
                return snap.node_native_context_attribution[ord] == target;
            }
            if (self.bitmap) |bm| {
                const bit = bm.get(ord);
                return if (self.invert_bitmap) !bit else bit;
            }
            return true;
        }
    };

    fn createNamedFilter(self: *const HeapSnapshot, filter_name: []const u8, object_id: ?u64) Error!NodeFilter {
        if (std.mem.eql(u8, filter_name, "sharedNativeContext")) {
            return .{ .native_context_target = shared_native_context };
        }
        if (std.mem.eql(u8, filter_name, "noNativeContext")) {
            return .{ .native_context_target = no_native_context };
        }
        if (std.mem.eql(u8, filter_name, "attributedToSpecificNativeContext")) {
            const oid = object_id orelse return error.MissingObjectId;
            const node_index = self.nodeIndexForId(oid) orelse return error.NodeNotFound;
            return .{ .native_context_target = @intCast(self.nodeOrdinal(node_index)) };
        }

        var bitmap = try BitVector.init(self.allocator, self.node_count);
        errdefer bitmap.deinit(self.allocator);

        if (std.mem.eql(u8, filter_name, "objectsRetainedByContexts")) {
            try self.bfsFilterReachable(&bitmap, .contexts, null);
        } else if (std.mem.eql(u8, filter_name, "objectsRetainedByDetachedDomNodes")) {
            try self.bfsFilterReachable(&bitmap, .detached_dom, null);
        } else if (std.mem.eql(u8, filter_name, "objectsRetainedByConsole")) {
            try self.bfsFilterReachable(&bitmap, .console, null);
        } else if (std.mem.eql(u8, filter_name, "objectsRetainedByEventHandlers")) {
            var eh_bitmap = try BitVector.init(self.allocator, self.node_count);
            defer eh_bitmap.deinit(self.allocator);
            for (0..self.node_count) |ord| {
                const node_index: u32 = @intCast(ord * self.node_field_count);
                if (!std.mem.eql(u8, self.nodeRawName(node_index), "V8EventListener")) continue;
                const cb_idx = self.findEdgeTargetByName(node_index, "1") orelse continue;
                if (self.findEdgeTargetByName(cb_idx, "code") != null) {
                    eh_bitmap.set(self.nodeOrdinal(cb_idx));
                    continue;
                }
                var found_child = false;
                const cb_ord = self.nodeOrdinal(cb_idx);
                var ei = self.first_edge_indexes[cb_ord];
                const end = self.first_edge_indexes[cb_ord + 1];
                while (ei < end) : (ei += self.edge_fields_count) {
                    const child = self.edgeToNode(ei);
                    if (self.findEdgeTargetByName(child, "code") != null) {
                        eh_bitmap.set(self.nodeOrdinal(child));
                        found_child = true;
                        break;
                    }
                }
                if (!found_child) eh_bitmap.set(self.nodeOrdinal(cb_idx));
            }
            try self.bfsFilterReachable(&bitmap, .event_handlers, &eh_bitmap);
        } else {
            return error.InvalidFilterName;
        }

        // markUnreachableNodes: nodes unreachable from root in normal distances are marked in bitmap
        // so `!bitmap.get(ord)` excludes them.
        for (0..self.node_count) |ord| {
            if (self.node_distances[ord] == no_distance) bitmap.set(ord);
        }
        return .{ .bitmap = bitmap, .invert_bitmap = true };
    }

    const ReachableStop = enum { contexts, detached_dom, console, event_handlers };

    fn bfsFilterReachable(self: *const HeapSnapshot, bitmap: *BitVector, stop: ReachableStop, eh_bitmap: ?*const BitVector) Allocator.Error!void {
        const a = self.allocator;
        const dist = try a.alloc(i32, self.node_count);
        defer a.free(dist);
        @memset(dist, no_distance);
        const queue = try a.alloc(u32, self.node_count);
        defer a.free(queue);

        const root_ord = self.nodeOrdinal(self.root_node_index);
        dist[root_ord] = 0;
        queue[0] = self.root_node_index;
        var q_len: usize = 1;
        var qi: usize = 0;
        while (qi < q_len) : (qi += 1) {
            const node_index = queue[qi];
            const ord = self.nodeOrdinal(node_index);
            const next_d = dist[ord] + 1;
            var ei = self.first_edge_indexes[ord];
            const end = self.first_edge_indexes[ord + 1];
            while (ei < end) : (ei += self.edge_fields_count) {
                if (self.edgeRawType(ei) == self.edge_weak_type) continue;
                const child_idx = self.edgeToNode(ei);
                const child_ord = self.nodeOrdinal(child_idx);
                if (dist[child_ord] != no_distance) continue;

                const allowed = switch (stop) {
                    .contexts => !self.isContextObject(child_idx),
                    .detached_dom => self.nodeDetachedness(child_idx) != .detached,
                    .console => !(self.isNodeSynthetic(node_index) and self.edgeHasStringName(ei) and std.mem.endsWith(u8, self.stringAt(self.edgeNameOrIndex(ei)), " / DevTools console")),
                    .event_handlers => !eh_bitmap.?.get(child_ord),
                };
                if (!allowed) continue;

                dist[child_ord] = next_d;
                queue[q_len] = child_idx;
                q_len += 1;
            }
        }
        for (0..self.node_count) |ord| {
            if (dist[ord] != no_distance) bitmap.set(ord);
        }
    }

    fn findEdgeTargetByName(self: *const HeapSnapshot, node_index: u32, target_name: []const u8) ?u32 {
        const ord = self.nodeOrdinal(node_index);
        var ei = self.first_edge_indexes[ord];
        const end = self.first_edge_indexes[ord + 1];
        var num_buf: [20]u8 = undefined;
        while (ei < end) : (ei += self.edge_fields_count) {
            const name: []const u8 = if (!self.edgeHasRawStringName(ei))
                std.fmt.bufPrint(&num_buf, "{d}", .{self.edgeNameOrIndex(ei)}) catch ""
            else blk: {
                const raw = self.stringAt(self.edgeNameOrIndex(ei));
                if (self.edgeRawType(ei) == self.edge_shortcut_type) {
                    if (parseJsIntPrefix(raw)) |n| {
                        break :blk std.fmt.bufPrint(&num_buf, "{d}", .{n}) catch raw;
                    }
                }
                break :blk raw;
            };
            if (std.mem.eql(u8, name, target_name)) return self.edgeToNode(ei);
        }
        return null;
    }

    const RawAggregate = struct {
        count: u32,
        distance: i32,
        self_size: u64,
        max_ret: u64,
        name: []const u8,
        idxs: std.ArrayList(u32),
    };

    const InternalKey = union(enum) {
        class_idx: u32,
        loc_str: []const u8,
    };

    fn internalClassKey(self: *const HeapSnapshot, arena: Allocator, node_index: u32) Allocator.Error!InternalKey {
        if (self.nodeRawType(node_index) == self.node_object_type) {
            if (self.location_map.get(node_index)) |loc| {
                return .{ .loc_str = try std.fmt.allocPrint(arena, "{d},{d},{d},{s}", .{ loc.script_id, loc.line, loc.column, self.nodeClassName(node_index) }) };
            }
        }
        return .{ .class_idx = self.nodeClassIndex(node_index) };
    }

    fn publicClassKey(self: *const HeapSnapshot, arena: Allocator, key: InternalKey) Allocator.Error![]const u8 {
        return switch (key) {
            .class_idx => |idx| std.fmt.allocPrint(arena, ",{s}", .{self.stringAt(idx)}),
            .loc_str => |s| s,
        };
    }

    fn computeAggregatesMap(self: *const HeapSnapshot, arena: Allocator, filter: ?*const NodeFilter) Allocator.Error!std.StringArrayHashMapUnmanaged(RawAggregate) {
        // Key by internal key string representation so distinct classIndex values are tracked accurately,
        // then project through publicClassKey (exact match to DevTools `getAggregatesByClassKey`).
        var internal_map: std.StringArrayHashMapUnmanaged(RawAggregate) = .empty;
        var internal_keys: std.ArrayList(InternalKey) = .empty;

        const keyTag = struct {
            fn format(ar: Allocator, k: InternalKey) Allocator.Error![]const u8 {
                return switch (k) {
                    .class_idx => |idx| std.fmt.allocPrint(ar, "#{d}", .{idx}),
                    .loc_str => |s| std.fmt.allocPrint(ar, "@{s}", .{s}),
                };
            }
        }.format;

        // buildAggregates
        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            if (filter) |f| if (!f.matches(self, node_index)) continue;
            const self_size = self.nodeSelfSize(node_index);
            if (self_size == 0) continue;
            const ik = try self.internalClassKey(arena, node_index);
            const tag = try keyTag(arena, ik);
            const dist = self.node_distances[ord];
            const gop = try internal_map.getOrPut(arena, tag);
            if (!gop.found_existing) {
                var idxs: std.ArrayList(u32) = .empty;
                try idxs.append(arena, node_index);
                gop.value_ptr.* = .{
                    .count = 1,
                    .distance = dist,
                    .self_size = self_size,
                    .max_ret = 0,
                    .name = self.nodeClassName(node_index),
                    .idxs = idxs,
                };
                try internal_keys.append(arena, ik);
            } else {
                if (dist < gop.value_ptr.distance) gop.value_ptr.distance = dist;
                gop.value_ptr.count += 1;
                gop.value_ptr.self_size += self_size;
                try gop.value_ptr.idxs.append(arena, node_index);
            }
        }

        // calculateClassesRetainedSize (DFS over dominator tree, skipping ancestor duplicates)
        var list: std.ArrayList(u32) = .empty;
        try list.append(arena, self.root_node_index);
        var sizes: std.ArrayList(usize) = .empty;
        try sizes.append(arena, std.math.maxInt(usize));
        var class_keys: std.ArrayList([]const u8) = .empty;
        var seen_keys: std.StringHashMapUnmanaged(bool) = .empty;

        while (list.items.len > 0) {
            const node_index = list.pop().?;
            const ik = try self.internalClassKey(arena, node_index);
            const tag = try keyTag(arena, ik);
            const seen = seen_keys.get(tag) orelse false;
            const ord = self.nodeOrdinal(node_index);
            const dom_from = self.first_dominated_node_index[ord];
            const dom_to = self.first_dominated_node_index[ord + 1];

            if (!seen and (filter == null or filter.?.matches(self, node_index)) and self.nodeSelfSize(node_index) > 0) {
                if (internal_map.getPtr(tag)) |agg| {
                    agg.max_ret += self.nodeRetainedSize(node_index);
                }
                if (dom_from != dom_to) {
                    try seen_keys.put(arena, tag, true);
                    try sizes.append(arena, list.items.len);
                    try class_keys.append(arena, tag);
                }
            }
            for (dom_from..dom_to) |di| {
                try list.append(arena, self.dominated_nodes[di]);
            }
            const cur_len = list.items.len;
            while (sizes.items.len > 0 and sizes.items[sizes.items.len - 1] == cur_len) {
                _ = sizes.pop();
                const popped = class_keys.pop().?;
                try seen_keys.put(arena, popped, false);
            }
        }

        // Project through publicClassKey preserving exact insertion order.
        var public_map: std.StringArrayHashMapUnmanaged(RawAggregate) = .empty;
        for (internal_keys.items, 0..) |ik, idx| {
            const pk = try self.publicClassKey(arena, ik);
            try public_map.put(arena, pk, internal_map.values()[idx]);
        }
        return public_map;
    }

    // -----------------------------------------------------------------------
    // Public query API (all results allocated in caller's `arena`)
    // -----------------------------------------------------------------------

    pub fn nodeIndexForId(self: *const HeapSnapshot, node_id: u64) ?u32 {
        for (0..self.node_count) |ord| {
            const idx: u32 = @intCast(ord * self.node_field_count);
            if (self.nodeId(idx) == node_id) return idx;
        }
        return null;
    }

    pub fn getStatistics(self: *const HeapSnapshot) Statistics {
        return self.statistics;
    }

    pub fn getStaticData(self: *const HeapSnapshot) StaticData {
        return .{
            .node_count = self.node_count,
            .root_node_index = self.root_node_index,
            .total_size = self.nodeRetainedSize(self.root_node_index) + self.extra_native_bytes,
            .max_js_object_id = self.max_js_object_id,
        };
    }

    pub fn getNativeContextSizes(self: *const HeapSnapshot) NativeContextSizes {
        return self.native_context_sizes;
    }

    pub fn getRetainedByContextSummary(self: *const HeapSnapshot) Error!RetainedByContextSummary {
        var filter = try self.createNamedFilter("objectsRetainedByContexts", null);
        defer filter.deinit(self.allocator);

        var context_count: u64 = 0;
        var retained_size: u64 = 0;
        var retained_count: u64 = 0;
        var not_retained_size: u64 = 0;
        var not_retained_count: u64 = 0;

        for (0..self.node_count) |ord| {
            const node_index: u32 = @intCast(ord * self.node_field_count);
            const self_size = self.nodeSelfSize(node_index);
            if (self_size == 0) continue;
            if (filter.matches(self, node_index)) {
                retained_count += 1;
                retained_size += self_size;
            } else {
                not_retained_count += 1;
                not_retained_size += self_size;
            }
            if (self.isContextObject(node_index)) {
                context_count += 1;
            }
        }

        return .{
            .context_count = context_count,
            .retained_by_context_size = retained_size,
            .retained_by_context_count = retained_count,
            .not_retained_by_context_size = not_retained_size,
            .not_retained_by_context_count = not_retained_count,
            .total_size = retained_size + not_retained_size,
        };
    }

    pub fn getAggregates(self: *const HeapSnapshot, arena: Allocator, filter_name: ?[]const u8, object_id: ?u64) Error!AggregateData {
        var filter_opt: ?NodeFilter = if (filter_name) |fnm| try self.createNamedFilter(fnm, object_id) else null;
        defer if (filter_opt) |*f| f.deinit(self.allocator);

        const raw_map = try self.computeAggregatesMap(arena, if (filter_opt) |*f| f else null);
        var out: std.ArrayList(AggregateInfo) = .empty;
        var object_count: u64 = 0;
        var total_self_size: u64 = 0;

        for (raw_map.keys(), raw_map.values()) |key, agg| {
            const id = self.class_key_to_id.get(key) orelse return error.ClassNotFound;
            object_count += agg.count;
            total_self_size += agg.self_size;
            try out.append(arena, .{
                .id = id,
                .class_name = agg.name,
                .count = agg.count,
                .self_size = agg.self_size,
                .retained_size = agg.max_ret,
            });
        }

        // Stable sort descending by retainedSize (matching JS Array.prototype.sort).
        std.sort.block(AggregateInfo, out.items, {}, struct {
            fn lessThan(_: void, a: AggregateInfo, b: AggregateInfo) bool {
                return a.retained_size > b.retained_size;
            }
        }.lessThan);

        return .{
            .aggregates = out.items,
            .object_count = object_count,
            .total_self_size = total_self_size,
        };
    }

    pub fn getClassNodes(self: *const HeapSnapshot, arena: Allocator, class_id: u32, filter_name: ?[]const u8, object_id: ?u64) Error![]NodeItem {
        if (class_id == 0 or class_id >= self.id_to_class_key.items.len) return error.ClassNotFound;
        const class_key = self.id_to_class_key.items[class_id];

        var filter_opt: ?NodeFilter = if (filter_name) |fnm| try self.createNamedFilter(fnm, object_id) else null;
        defer if (filter_opt) |*f| f.deinit(self.allocator);

        const raw_map = try self.computeAggregatesMap(arena, if (filter_opt) |*f| f else null);
        const agg = raw_map.get(class_key) orelse return &.{};

        var items: std.ArrayList(NodeItem) = .empty;
        try items.ensureTotalCapacity(arena, agg.idxs.items.len);
        for (agg.idxs.items) |node_index| {
            try items.append(arena, try self.serializeNode(arena, node_index));
        }

        // McpResponse.ts:1419 sorts NodeLike items descending by retainedSize (stable).
        std.sort.block(NodeItem, items.items, {}, struct {
            fn lessThan(_: void, a: NodeItem, b: NodeItem) bool {
                return a.retained_size > b.retained_size;
            }
        }.lessThan);

        return items.items;
    }

    pub fn getObjectInfo(self: *const HeapSnapshot, arena: Allocator, node_id: u64) Error!ObjectInfo {
        const node_index = self.nodeIndexForId(node_id) orelse return error.NodeNotFound;
        return .{
            .id = self.nodeId(node_index),
            .name = try self.nodeNameAlloc(arena, node_index),
            .type_name = self.nodeTypeName(node_index),
            .node_index = node_index,
            .detachedness = self.nodeDetachedness(node_index),
            .self_size = self.nodeSelfSize(node_index),
            .retained_size = self.nodeRetainedSize(node_index),
            .distance = self.nodeDistance(node_index),
            .edge_count = self.nodeEdgesCount(node_index),
            .retainer_count = self.nodeRetainersCount(node_index),
        };
    }

    pub fn getEdges(self: *const HeapSnapshot, arena: Allocator, node_id: u64, options: EdgeQueryOptions) Error![]EdgeItem {
        const node_index = self.nodeIndexForId(node_id) orelse return error.NodeNotFound;
        const ord = self.nodeOrdinal(node_index);

        var edge_indexes: std.ArrayList(u32) = .empty;
        var ei = self.first_edge_indexes[ord];
        const end = self.first_edge_indexes[ord + 1];
        while (ei < end) : (ei += self.edge_fields_count) {
            if (self.edgeRawType(ei) == self.edge_invisible_type) continue;
            const target = self.edgeToNode(ei);
            if (options.min_retained_size) |min_ret| {
                if (self.nodeRetainedSize(target) < min_ret) continue;
            }
            if (options.exclude_primitives) {
                const raw_type = self.nodeRawType(target);
                if (raw_type == self.node_number_type) continue;
                if (raw_type == self.node_native_type) {
                    const tn = self.nodeRawName(target);
                    if (std.mem.eql(u8, tn, "undefined") or std.mem.eql(u8, tn, "null") or std.mem.eql(u8, tn, "true") or std.mem.eql(u8, tn, "false")) {
                        continue;
                    }
                }
            }
            try edge_indexes.append(arena, ei);
        }

        const SortEntry = struct {
            edge_index: u32,
            name: []const u8,
            has_string_name: bool,
            retained_size: u64,
            self_size: u64,
        };
        var entries: std.ArrayList(SortEntry) = .empty;
        try entries.ensureTotalCapacity(arena, edge_indexes.items.len);
        for (edge_indexes.items) |edge_idx| {
            const target = self.edgeToNode(edge_idx);
            try entries.append(arena, .{
                .edge_index = edge_idx,
                .name = try self.edgeNameAlloc(arena, edge_idx),
                .has_string_name = self.edgeHasStringName(edge_idx),
                .retained_size = self.nodeRetainedSize(target),
                .self_size = self.nodeSelfSize(target),
            });
        }

        const cmpEdgeName = struct {
            fn cmp(a: SortEntry, b: SortEntry) std.math.Order {
                const a_proto = std.mem.eql(u8, a.name, "__proto__");
                const b_proto = std.mem.eql(u8, b.name, "__proto__");
                if (a_proto != b_proto) return if (a_proto) .gt else .lt;
                if (a.has_string_name != b.has_string_name) {
                    return if (a.has_string_name) .lt else .gt;
                }
                return std.mem.order(u8, a.name, b.name);
            }
        }.cmp;

        std.sort.block(SortEntry, entries.items, options.sort_by, struct {
            fn lessThan(sort_by: EdgeSortBy, a: SortEntry, b: SortEntry) bool {
                const ord1: std.math.Order = switch (sort_by) {
                    .retained_size => std.math.order(b.retained_size, a.retained_size),
                    .self_size => std.math.order(b.self_size, a.self_size),
                    .name => cmpEdgeName(a, b),
                };
                if (ord1 != .eq) return ord1 == .lt;
                const ord2: std.math.Order = switch (sort_by) {
                    .retained_size, .self_size => cmpEdgeName(a, b),
                    .name => std.math.order(b.retained_size, a.retained_size),
                };
                if (ord2 != .eq) return ord2 == .lt;
                return a.edge_index < b.edge_index;
            }
        }.lessThan);

        var items: std.ArrayList(EdgeItem) = .empty;
        try items.ensureTotalCapacity(arena, entries.items.len);
        for (entries.items) |entry| {
            const target = self.edgeToNode(entry.edge_index);
            try items.append(arena, .{
                .name = entry.name,
                .type_name = self.edgeTypeName(entry.edge_index),
                .node = try self.serializeNode(arena, target),
                .edge_index = entry.edge_index,
            });
        }
        return items.items;
    }

    pub fn getRetainers(self: *const HeapSnapshot, arena: Allocator, node_id: u64) Error![]EdgeItem {
        const node_index = self.nodeIndexForId(node_id) orelse return error.NodeNotFound;
        const ord = self.nodeOrdinal(node_index);
        const begin = self.first_retainer_index[ord];
        const end = self.first_retainer_index[ord + 1];

        var items: std.ArrayList(EdgeItem) = .empty;
        for (begin..end) |ri| {
            const global_edge_index = self.retaining_edges[ri];
            const retaining_node_index = self.retaining_nodes[ri];
            const et = self.edgeRawType(global_edge_index);
            // JSHeapSnapshot.retainingEdgesFilter: !isInvisible && !edge.node().isRoot() && !isWeak
            if (et == self.edge_invisible_type or et == self.edge_weak_type) continue;
            if (retaining_node_index == self.root_node_index) continue;
            try items.append(arena, .{
                .name = try self.edgeNameAlloc(arena, global_edge_index),
                .type_name = self.edgeTypeName(global_edge_index),
                .node = try self.serializeNode(arena, retaining_node_index),
                .edge_index = global_edge_index,
            });
        }
        return items.items;
    }

    pub fn getDominatorsOf(self: *const HeapSnapshot, arena: Allocator, node_id: u64) Error![]DominatorItem {
        const start_index = self.nodeIndexForId(node_id) orelse return error.NodeNotFound;
        var chain: std.ArrayList(DominatorItem) = .empty;
        var cur = start_index;
        while (true) {
            try chain.append(arena, .{
                .node_id = self.nodeId(cur),
                .node_index = cur,
                .node_name = try self.nodeNameAlloc(arena, cur),
                .self_size = self.nodeSelfSize(cur),
                .retained_size = self.nodeRetainedSize(cur),
            });
            if (cur == self.root_node_index) break;
            const next_idx = self.dominators_tree[self.nodeOrdinal(cur)] * self.node_field_count;
            if (next_idx == cur) break;
            cur = next_idx;
        }
        return chain.items;
    }

    fn serializeNode(self: *const HeapSnapshot, arena: Allocator, node_index: u32) Allocator.Error!NodeItem {
        return .{
            .id = self.nodeId(node_index),
            .name = try self.nodeNameAlloc(arena, node_index),
            .type_name = self.nodeTypeName(node_index),
            .distance = self.nodeDistance(node_index),
            .self_size = self.nodeSelfSize(node_index),
            .retained_size = self.nodeRetainedSize(node_index),
            .node_index = node_index,
        };
    }
};

// ---------------------------------------------------------------------------
// Session cache (HeapSnapshotManager)
// ---------------------------------------------------------------------------

pub const Cache = struct {
    entries: std.StringArrayHashMapUnmanaged(*HeapSnapshot) = .empty,

    pub fn hasValidExtension(file_path: []const u8) bool {
        return std.mem.endsWith(u8, file_path, ".heapsnapshot") or std.mem.endsWith(u8, file_path, ".heaptimeline");
    }

    pub const LoadResult = union(enum) {
        ok: *HeapSnapshot,
        err: []const u8,
    };

    pub fn getOrLoad(self: *Cache, allocator: Allocator, paths: *paths_mod.Policy, arena: Allocator, file_path: []const u8) Allocator.Error!LoadResult {
        if (!hasValidExtension(file_path)) {
            return .{ .err = try std.fmt.allocPrint(arena, "File {s} must have a .heapsnapshot or .heaptimeline extension.", .{file_path}) };
        }
        if (self.entries.get(file_path)) |cached| {
            return .{ .ok = cached };
        }
        const bytes = paths.readFile(arena, file_path) catch |err| switch (err) {
            error.Denied => return .{ .err = paths.message },
            error.OutOfMemory => return error.OutOfMemory,
        };
        const snap = HeapSnapshot.loadFromBytes(allocator, bytes) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return .{ .err = try std.fmt.allocPrint(arena, "Failed to parse heap snapshot {s}: {t}", .{ file_path, err }) },
        };
        errdefer snap.deinit();
        const key = try allocator.dupe(u8, file_path);
        errdefer allocator.free(key);
        try self.entries.put(allocator, key, snap);
        return .{ .ok = snap };
    }

    pub fn close(self: *Cache, allocator: Allocator, file_path: []const u8) bool {
        const kv = self.entries.fetchSwapRemove(file_path) orelse return false;
        allocator.free(kv.key);
        kv.value.deinit();
        return true;
    }

    pub fn deinit(self: *Cache, allocator: Allocator) void {
        for (self.entries.keys(), self.entries.values()) |k, v| {
            allocator.free(k);
            v.deinit();
        }
        self.entries.deinit(allocator);
    }
};

// ---------------------------------------------------------------------------
// Helpers & Streaming JSON Parser
// ---------------------------------------------------------------------------

fn findTypeIndex(types: []const []const u8, needle: []const u8) u32 {
    for (types, 0..) |t, i| {
        if (std.mem.eql(u8, t, needle)) return @intCast(i);
    }
    return missing_type;
}

fn stringLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

/// JS `parseInt(str, 10)` prefix parser (returns null if no leading integer).
fn parseJsIntPrefix(s: []const u8) ?i64 {
    const trimmed = std.mem.trimStart(u8, s, " \t\r\n\x0b\x0c");
    if (trimmed.len == 0) return null;
    var i: usize = 0;
    var neg = false;
    if (trimmed[0] == '-') {
        neg = true;
        i = 1;
    } else if (trimmed[0] == '+') {
        i = 1;
    }
    const start = i;
    while (i < trimmed.len and std.ascii.isDigit(trimmed[i])) : (i += 1) {}
    if (i == start) return null;
    const mag = std.fmt.parseInt(i64, trimmed[start..i], 10) catch return null;
    return if (neg) -mag else mag;
}

/// JSHeapSnapshotNode.formatPropertyName: quotes names containing [,'"{}].
fn formatPropertyName(arena: Allocator, name: []const u8) Allocator.Error![]const u8 {
    if (std.mem.indexOfAny(u8, name, ",'\"{}") == null) return name;
    var out: std.Io.Writer.Allocating = .init(arena);
    std.json.Stringify.encodeJsonString(name, .{}, &out.writer) catch return error.OutOfMemory;
    return out.written();
}

/// Matches DevTools `ephemeronNameRegex`:
/// `/^\d+(?<duplicatedPart> \/ part of key \(.*? @\d+\) -> value \(.*? @\d+\) pair in WeakMap \(table @(?<tableId>\d+)\))$/`
fn parseWeakMapEdgeName(edge_name: []const u8) ?WeakMapMatch {
    var i: usize = 0;
    while (i < edge_name.len and std.ascii.isDigit(edge_name[i])) : (i += 1) {}
    if (i == 0) return null;
    const rest = edge_name[i..];
    const prefix = " / part of key (";
    if (!std.mem.startsWith(u8, rest, prefix)) return null;
    const mid = ") -> value (";
    const mid_idx = std.mem.indexOfPos(u8, rest, prefix.len, mid) orelse return null;
    if (!endsWithAtNumber(rest[prefix.len..mid_idx])) return null;
    const wm_marker = ") pair in WeakMap (table @";
    const wm_idx = std.mem.indexOfPos(u8, rest, mid_idx + mid.len, wm_marker) orelse return null;
    if (!endsWithAtNumber(rest[mid_idx + mid.len .. wm_idx])) return null;
    const id_start = wm_idx + wm_marker.len;
    if (!std.mem.endsWith(u8, rest, ")")) return null;
    const id_str = rest[id_start .. rest.len - 1];
    if (id_str.len == 0) return null;
    for (id_str) |c| if (!std.ascii.isDigit(c)) return null;
    const table_id = std.fmt.parseInt(u64, id_str, 10) catch return null;
    return .{ .duplicated_part = rest, .table_id = table_id };
}

fn endsWithAtNumber(slice: []const u8) bool {
    const at = std.mem.lastIndexOf(u8, slice, " @") orelse return false;
    const digits = slice[at + 2 ..];
    if (digits.len == 0) return false;
    for (digits) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

const ParsedSnapshot = struct {
    nodes: std.ArrayList(u32) = .empty,
    edges: std.ArrayList(u32) = .empty,
    locations: std.ArrayList(u32) = .empty,
    strings: std.ArrayList([]const u8) = .empty,

    node_field_count: u32 = 0,
    node_type_offset: u32 = 0,
    node_name_offset: u32 = 0,
    node_id_offset: u32 = 0,
    node_self_size_offset: u32 = 0,
    node_edge_count_offset: u32 = 0,
    node_trace_node_id_offset: ?u32 = null,
    node_detachedness_offset: ?u32 = null,
    node_types: []const []const u8 = &.{},

    edge_fields_count: u32 = 0,
    edge_type_offset: u32 = 0,
    edge_name_offset: u32 = 0,
    edge_to_node_offset: u32 = 0,
    edge_types: []const []const u8 = &.{},

    location_field_count: u32 = 0,
    location_index_offset: ?u32 = null,
    location_script_id_offset: ?u32 = null,
    location_line_offset: ?u32 = null,
    location_column_offset: ?u32 = null,

    root_index: u32 = 0,
    extra_native_bytes: u64 = 0,
};

fn parseSnapshotJson(allocator: Allocator, arena: Allocator, bytes: []const u8) Error!ParsedSnapshot {
    var result: ParsedSnapshot = .{};
    errdefer {
        result.nodes.deinit(allocator);
        result.edges.deinit(allocator);
        result.locations.deinit(allocator);
        result.strings.deinit(allocator);
    }

    var scanner = std.json.Scanner.initCompleteInput(allocator, bytes);
    defer scanner.deinit();

    const first = scanner.next() catch return error.InvalidSnapshot;
    if (first != .object_begin) return error.InvalidSnapshot;

    var saw_snapshot = false;
    var node_count_hint: usize = 0;
    var edge_count_hint: usize = 0;

    while (true) {
        const key_tok = scanner.nextAlloc(arena, .alloc_if_needed) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidSnapshot,
        };
        switch (key_tok) {
            .object_end => break,
            .string, .allocated_string => |key| {
                if (std.mem.eql(u8, key, "snapshot")) {
                    saw_snapshot = true;
                    try parseSnapshotHeader(&scanner, arena, &result, &node_count_hint, &edge_count_hint);
                } else if (std.mem.eql(u8, key, "nodes")) {
                    if (node_count_hint > 0 and result.node_field_count > 0) {
                        try result.nodes.ensureTotalCapacity(allocator, node_count_hint * result.node_field_count);
                    }
                    try parseU32Array(&scanner, allocator, arena, &result.nodes);
                } else if (std.mem.eql(u8, key, "edges")) {
                    if (edge_count_hint > 0 and result.edge_fields_count > 0) {
                        try result.edges.ensureTotalCapacity(allocator, edge_count_hint * result.edge_fields_count);
                    }
                    try parseU32Array(&scanner, allocator, arena, &result.edges);
                } else if (std.mem.eql(u8, key, "locations")) {
                    try parseU32Array(&scanner, allocator, arena, &result.locations);
                } else if (std.mem.eql(u8, key, "strings")) {
                    try parseStringArray(&scanner, allocator, arena, &result.strings);
                } else {
                    scanner.skipValue() catch |err| switch (err) {
                        error.OutOfMemory => return error.OutOfMemory,
                        else => return error.InvalidSnapshot,
                    };
                }
            },
            else => return error.InvalidSnapshot,
        }
    }

    if (!saw_snapshot) return error.InvalidSnapshot;
    return result;
}

fn parseSnapshotHeader(
    scanner: *std.json.Scanner,
    arena: Allocator,
    result: *ParsedSnapshot,
    node_count_hint: *usize,
    edge_count_hint: *usize,
) Error!void {
    const begin = scanner.next() catch return error.InvalidSnapshot;
    if (begin != .object_begin) return error.InvalidSnapshot;

    while (true) {
        const tok = scanner.nextAlloc(arena, .alloc_if_needed) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidSnapshot,
        };
        switch (tok) {
            .object_end => break,
            .string, .allocated_string => |key| {
                if (std.mem.eql(u8, key, "meta")) {
                    try parseMeta(scanner, arena, result);
                } else if (std.mem.eql(u8, key, "node_count")) {
                    node_count_hint.* = @intCast(try nextU64(scanner, arena));
                } else if (std.mem.eql(u8, key, "edge_count")) {
                    edge_count_hint.* = @intCast(try nextU64(scanner, arena));
                } else if (std.mem.eql(u8, key, "root_index")) {
                    result.root_index = @intCast(try nextU64(scanner, arena));
                } else if (std.mem.eql(u8, key, "extra_native_bytes")) {
                    result.extra_native_bytes = try nextU64(scanner, arena);
                } else {
                    scanner.skipValue() catch |err| switch (err) {
                        error.OutOfMemory => return error.OutOfMemory,
                        else => return error.InvalidSnapshot,
                    };
                }
            },
            else => return error.InvalidSnapshot,
        }
    }
}

fn parseMeta(scanner: *std.json.Scanner, arena: Allocator, result: *ParsedSnapshot) Error!void {
    const begin = scanner.next() catch return error.InvalidSnapshot;
    if (begin != .object_begin) return error.InvalidSnapshot;

    var node_types_raw: std.ArrayList([]const []const u8) = .empty;
    var edge_types_raw: std.ArrayList([]const []const u8) = .empty;

    while (true) {
        const tok = scanner.nextAlloc(arena, .alloc_if_needed) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidSnapshot,
        };
        switch (tok) {
            .object_end => break,
            .string, .allocated_string => |key| {
                if (std.mem.eql(u8, key, "node_fields")) {
                    const fields = try parseMetaStringList(scanner, arena);
                    result.node_field_count = @intCast(fields.len);
                    result.node_type_offset = findFieldOffset(fields, "type") orelse return error.InvalidSnapshot;
                    result.node_name_offset = findFieldOffset(fields, "name") orelse return error.InvalidSnapshot;
                    result.node_id_offset = findFieldOffset(fields, "id") orelse return error.InvalidSnapshot;
                    result.node_self_size_offset = findFieldOffset(fields, "self_size") orelse return error.InvalidSnapshot;
                    result.node_edge_count_offset = findFieldOffset(fields, "edge_count") orelse return error.InvalidSnapshot;
                    result.node_trace_node_id_offset = findFieldOffset(fields, "trace_node_id");
                    result.node_detachedness_offset = findFieldOffset(fields, "detachedness");
                } else if (std.mem.eql(u8, key, "node_types")) {
                    try parseTypesArray(scanner, arena, &node_types_raw);
                } else if (std.mem.eql(u8, key, "edge_fields")) {
                    const fields = try parseMetaStringList(scanner, arena);
                    result.edge_fields_count = @intCast(fields.len);
                    result.edge_type_offset = findFieldOffset(fields, "type") orelse return error.InvalidSnapshot;
                    result.edge_name_offset = findFieldOffset(fields, "name_or_index") orelse return error.InvalidSnapshot;
                    result.edge_to_node_offset = findFieldOffset(fields, "to_node") orelse return error.InvalidSnapshot;
                } else if (std.mem.eql(u8, key, "edge_types")) {
                    try parseTypesArray(scanner, arena, &edge_types_raw);
                } else if (std.mem.eql(u8, key, "location_fields")) {
                    const fields = try parseMetaStringList(scanner, arena);
                    result.location_field_count = @intCast(fields.len);
                    result.location_index_offset = findFieldOffset(fields, "object_index");
                    result.location_script_id_offset = findFieldOffset(fields, "script_id");
                    result.location_line_offset = findFieldOffset(fields, "line");
                    result.location_column_offset = findFieldOffset(fields, "column");
                } else {
                    scanner.skipValue() catch |err| switch (err) {
                        error.OutOfMemory => return error.OutOfMemory,
                        else => return error.InvalidSnapshot,
                    };
                }
            },
            else => return error.InvalidSnapshot,
        }
    }

    if (result.node_type_offset >= node_types_raw.items.len) return error.InvalidSnapshot;
    result.node_types = node_types_raw.items[result.node_type_offset];

    if (result.edge_type_offset >= edge_types_raw.items.len) return error.InvalidSnapshot;
    const base_edge_types = edge_types_raw.items[result.edge_type_offset];
    var edge_types_list = try arena.alloc([]const u8, base_edge_types.len + 1);
    @memcpy(edge_types_list[0..base_edge_types.len], base_edge_types);
    edge_types_list[base_edge_types.len] = "invisible";
    result.edge_types = edge_types_list;
}

fn findFieldOffset(fields: []const []const u8, needle: []const u8) ?u32 {
    for (fields, 0..) |f, i| {
        if (std.mem.eql(u8, f, needle)) return @intCast(i);
    }
    return null;
}

fn parseMetaStringList(scanner: *std.json.Scanner, arena: Allocator) Error![]const []const u8 {
    const begin = scanner.next() catch return error.InvalidSnapshot;
    if (begin != .array_begin) return error.InvalidSnapshot;
    var list: std.ArrayList([]const u8) = .empty;
    while (true) {
        const tok = scanner.nextAlloc(arena, .alloc_always) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidSnapshot,
        };
        switch (tok) {
            .array_end => break,
            .allocated_string => |s| try list.append(arena, s),
            else => return error.InvalidSnapshot,
        }
    }
    return list.items;
}

fn parseTypesArray(scanner: *std.json.Scanner, arena: Allocator, out: *std.ArrayList([]const []const u8)) Error!void {
    const begin = scanner.next() catch return error.InvalidSnapshot;
    if (begin != .array_begin) return error.InvalidSnapshot;
    while (true) {
        const peek = scanner.peekNextTokenType() catch return error.InvalidSnapshot;
        if (peek == .array_end) {
            _ = scanner.next() catch return error.InvalidSnapshot;
            break;
        }
        if (peek == .array_begin) {
            try out.append(arena, try parseMetaStringList(scanner, arena));
        } else {
            scanner.skipValue() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.InvalidSnapshot,
            };
            try out.append(arena, &.{});
        }
    }
}

fn nextU64(scanner: *std.json.Scanner, arena: Allocator) Error!u64 {
    const tok = scanner.nextAlloc(arena, .alloc_if_needed) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidSnapshot,
    };
    return switch (tok) {
        .number, .allocated_number => |s| std.fmt.parseInt(u64, s, 10) catch return error.InvalidSnapshot,
        else => return error.InvalidSnapshot,
    };
}

fn parseU32Array(scanner: *std.json.Scanner, allocator: Allocator, arena: Allocator, out: *std.ArrayList(u32)) Error!void {
    const begin = scanner.next() catch return error.InvalidSnapshot;
    if (begin != .array_begin) return error.InvalidSnapshot;
    while (true) {
        const tok = scanner.nextAlloc(arena, .alloc_if_needed) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidSnapshot,
        };
        switch (tok) {
            .array_end => break,
            .number, .allocated_number => |s| {
                const v = std.fmt.parseInt(u64, s, 10) catch return error.InvalidSnapshot;
                try out.append(allocator, if (v > std.math.maxInt(u32)) std.math.maxInt(u32) else @intCast(v));
            },
            else => return error.InvalidSnapshot,
        }
    }
}

fn parseStringArray(scanner: *std.json.Scanner, allocator: Allocator, arena: Allocator, out: *std.ArrayList([]const u8)) Error!void {
    const begin = scanner.next() catch return error.InvalidSnapshot;
    if (begin != .array_begin) return error.InvalidSnapshot;
    while (true) {
        const tok = scanner.nextAlloc(arena, .alloc_always) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidSnapshot,
        };
        switch (tok) {
            .array_end => break,
            .allocated_string => |s| try out.append(allocator, s),
            else => return error.InvalidSnapshot,
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "parseWeakMapEdgeName matches DevTools ephemeron edge format" {
    const ok = parseWeakMapEdgeName("12 / part of key (Foo @101) -> value (Bar @202) pair in WeakMap (table @999)");
    try testing.expect(ok != null);
    try testing.expectEqual(@as(u64, 999), ok.?.table_id);
    try testing.expectEqualStrings(" / part of key (Foo @101) -> value (Bar @202) pair in WeakMap (table @999)", ok.?.duplicated_part);
    try testing.expect(parseWeakMapEdgeName("ordinary_prop") == null);
    try testing.expect(parseWeakMapEdgeName("12 / part of key (no_id) -> value (Bar @2) pair in WeakMap (table @9)") == null);
}

test "HeapSnapshot core analysis on minimal snapshot: shallow sizes, dominators, detachedness, attribution, stats" {
    const sample =
        \\{
        \\  "snapshot": {
        \\    "meta": {
        \\      "node_fields": ["type","name","id","self_size","edge_count","trace_node_id","detachedness"],
        \\      "node_types": [["hidden","array","string","object","code","closure","regexp","number","native","synthetic","concatenated string","sliced string","symbol","bigint","object shape"],"string","number","number","number","number","number"],
        \\      "edge_fields": ["type","name_or_index","to_node"],
        \\      "edge_types": [["context","element","property","internal","hidden","shortcut","weak"],"string_or_number","node"],
        \\      "location_fields": ["object_index","script_id","line","column"]
        \\    },
        \\    "node_count": 6,
        \\    "edge_count": 5,
        \\    "extra_native_bytes": 100
        \\  },
        \\  "nodes": [
        \\    9, 0, 1, 0, 2, 0, 0,
        \\    3, 1, 3, 40, 2, 0, 0,
        \\    1, 2, 5, 60, 0, 0, 0,
        \\    8, 3, 7, 120, 1, 0, 2,
        \\    8, 4, 9, 80, 0, 0, 0,
        \\    2, 5, 11, 20, 0, 0, 0
        \\  ],
        \\  "edges": [
        \\    5, 6, 7,
        \\    1, 0, 21,
        \\    3, 7, 14,
        \\    2, 8, 35,
        \\    3, 9, 28
        \\  ],
        \\  "strings": ["","Array","(elements)","HTMLSpanElement","Text","hello","arr","elements","label","child"]
        \\}
    ;

    const snap = try HeapSnapshot.loadFromBytes(testing.allocator, sample);
    defer snap.deinit();

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Array (@3) exclusively owns (elements) (@5): self_size becomes 40 + 60 = 100, elements becomes 0.
    const arr_info = try snap.getObjectInfo(arena, 3);
    try testing.expectEqual(@as(u64, 100), arr_info.self_size);
    try testing.expectEqual(@as(u64, 120), arr_info.retained_size); // 100 + 20 (string)
    try testing.expectEqual(@as(i32, 1), arr_info.distance);

    // Detached HTMLSpanElement (@7) propagates detachedness to child Text (@9).
    const span_info = try snap.getObjectInfo(arena, 7);
    try testing.expectEqual(DomLinkState.detached, span_info.detachedness);
    try testing.expectEqualStrings("Detached HTMLSpanElement", span_info.name);
    const text_info = try snap.getObjectInfo(arena, 9);
    try testing.expectEqual(DomLinkState.detached, text_info.detachedness);
    try testing.expectEqualStrings("Detached Text", text_info.name);

    // Statistics: total = root.retained (100+20+120+80=320) + extra_native_bytes (100) = 420.
    const stats = snap.getStatistics();
    try testing.expectEqual(@as(u64, 420), stats.total);
    try testing.expectEqual(@as(u64, 300), stats.native.total); // 100 + 120 + 80
    try testing.expectEqual(@as(u64, 120), stats.v8heap.total);
    try testing.expectEqual(@as(u64, 100), stats.v8heap.js_arrays);
    try testing.expectEqual(@as(u64, 20), stats.v8heap.strings);

    // Dominators of Text (@9): @9 -> @7 -> @1 (root).
    const doms = try snap.getDominatorsOf(arena, 9);
    try testing.expectEqual(@as(usize, 3), doms.len);
    try testing.expectEqual(@as(u64, 9), doms[0].node_id);
    try testing.expectEqual(@as(u64, 7), doms[1].node_id);
    try testing.expectEqual(@as(u64, 1), doms[2].node_id);

    // Retainers of Text (@9): child from Detached HTMLSpanElement (@7).
    const retainers = try snap.getRetainers(arena, 9);
    try testing.expectEqual(@as(usize, 1), retainers.len);
    try testing.expectEqualStrings("child", retainers[0].name);
    try testing.expectEqual(@as(u64, 7), retainers[0].node.id);
}
