//! Per-type byte table and 4-partition Browser heap summary (`--memory-map`,
//! `[ARCH] 7.3`, Allocator Hardening Batch C Item 5).
//!
//! Walks the Browser's live slab (`BrowserScope.slab.forEachLive`) and groups
//! every live platform object by interface name (`instance.vtable.name`),
//! attributing:
//! - `state_bytes`: State block size class (`ArenaAllocator.heldBytes`)
//! - `slot_bytes`: Slab Instance slot (`SlabAllocator.slot_bytes`)
//! - `satellite_bytes`: Node rare data, event listener list, attribute entry
//!   block (amortized across shared holders), and `ElementStyle` when allocated
//!
//! Alongside the per-type table, prints the 4-partition Browser heap summary
//! (`node`, `satellite`, `objects` [state+inst and general], `bytes`, and
//! task-scoped `quarantine`) from `scope.existingHeapEngine().stats()`.

const std = @import("std");
const runtime = @import("runtime");
const dom = @import("dom");

pub const Row = struct {
    name: []const u8,
    count: usize = 0,
    state_bytes: usize = 0,
    slot_bytes: usize = 0,
    satellite_bytes: usize = 0,

    pub fn totalBytes(self: Row) usize {
        return self.state_bytes + self.slot_bytes + self.satellite_bytes;
    }
};

pub const Report = struct {
    rows: []Row,
    total_instances: usize,
    total_state_bytes: usize,
    total_slot_bytes: usize,
    total_satellite_bytes: usize,
    heap_stats: ?runtime.heap.Stats,

    pub fn deinit(self: *Report, allocator: std.mem.Allocator) void {
        allocator.free(self.rows);
        self.rows = &.{};
    }

    pub fn totalBytes(self: *const Report) usize {
        return self.total_state_bytes + self.total_slot_bytes + self.total_satellite_bytes;
    }

    pub fn rowNamed(self: *const Report, name: []const u8) ?Row {
        for (self.rows) |row| {
            if (std.mem.eql(u8, row.name, name)) return row;
        }
        return null;
    }
};

/// Collect the live per-interface byte table and heap partition statistics for
/// `scope` using `allocator` (which should be the caller's reporting allocator,
/// not the scope's slab).
pub fn collect(scope: *runtime.BrowserScope, allocator: std.mem.Allocator) !Report {
    const Map = std.StringHashMapUnmanaged(Row);
    const Walk = struct {
        map: Map = .empty,
        allocator: std.mem.Allocator,
        failed: bool = false,
        total_instances: usize = 0,
        total_state_bytes: usize = 0,
        total_slot_bytes: usize = 0,
        total_satellite_bytes: usize = 0,

        fn visit(self: *@This(), instance: *runtime.Instance) void {
            const name = instance.vtable.name;
            const gop = self.map.getOrPut(self.allocator, name) catch {
                self.failed = true;
                return;
            };
            if (!gop.found_existing) {
                gop.value_ptr.* = .{ .name = name };
            }
            const state_b = runtime.ArenaAllocator.heldBytes(instance.vtable.state_size, instance.vtable.state_align);
            const slot_b = runtime.SlabAllocator.slot_bytes;
            const sat_b = satelliteBytesOf(instance);

            gop.value_ptr.count += 1;
            gop.value_ptr.state_bytes += state_b;
            gop.value_ptr.slot_bytes += slot_b;
            gop.value_ptr.satellite_bytes += sat_b;

            self.total_instances += 1;
            self.total_state_bytes += state_b;
            self.total_slot_bytes += slot_b;
            self.total_satellite_bytes += sat_b;
        }
    };

    var walk: Walk = .{ .allocator = allocator };
    defer walk.map.deinit(allocator);
    scope.slab.forEachLive(&walk, Walk.visit);
    if (walk.failed) return error.OutOfMemory;

    var rows: std.ArrayListUnmanaged(Row) = .empty;
    errdefer rows.deinit(allocator);
    try rows.ensureTotalCapacity(allocator, walk.map.count());
    var it = walk.map.valueIterator();
    while (it.next()) |row| rows.appendAssumeCapacity(row.*);

    std.mem.sort(Row, rows.items, {}, struct {
        fn more(_: void, a: Row, b: Row) bool {
            const ta = a.totalBytes();
            const tb = b.totalBytes();
            if (ta != tb) return ta > tb;
            if (a.count != b.count) return a.count > b.count;
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.more);

    const heap_stats = if (scope.existingHeapEngine()) |eng| eng.stats() else null;
    return .{
        .rows = try rows.toOwnedSlice(allocator),
        .total_instances = walk.total_instances,
        .total_state_bytes = walk.total_state_bytes,
        .total_slot_bytes = walk.total_slot_bytes,
        .total_satellite_bytes = walk.total_satellite_bytes,
        .heap_stats = heap_stats,
    };
}

fn satelliteBytesOf(instance: *runtime.Instance) usize {
    const node = dom.instance_bridge.getNodeBase(instance) orelse return 0;
    var total: usize = node.rare.blockBytes() + node.eventListeners().allocatedBytes();
    if (node.node_type == dom.NodeBase.ELEMENT_NODE) {
        if (dom.element_data.of(instance)) |view| {
            if (view.data.attrs) |attrs| {
                const raw = @sizeOf(dom.element_data.AttributeList) + attrs.capacity() * @sizeOf(dom.element_data.Entry);
                const holders: usize = @max(@as(usize, attrs.holders), 1);
                total += raw / holders;
            }
        }
        if (dom.style.element_style.existingOf(instance) != null) {
            total += @sizeOf(dom.style.ElementStyle);
        }
    }
    return total;
}

/// Format `scope`'s per-type byte table and 4-partition heap summary to `out`.
pub fn write(scope: *runtime.BrowserScope, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    var report = try collect(scope, allocator);
    defer report.deinit(allocator);
    try writeReport(&report, out);
}

/// Format an already-collected `Report` to `out`.
pub fn writeReport(report: *const Report, out: *std.Io.Writer) !void {
    try out.print("\n=== Crane Memory Map ({d} live instances across {d} interfaces) ===\n\n", .{
        report.total_instances,
        report.rows.len,
    });
    try out.print("{s:<32}  {s:>8}  {s:>10}  {s:>10}  {s:>10}  {s:>10}  {s:>8}\n", .{
        "interface", "count", "state B", "slot B", "sat B", "total B", "B/obj",
    });
    for (report.rows) |row| {
        const total = row.totalBytes();
        const per = if (row.count > 0) total / row.count else 0;
        try out.print("{s:<32}  {d:>8}  {d:>10}  {d:>10}  {d:>10}  {d:>10}  {d:>8}\n", .{
            row.name,
            row.count,
            row.state_bytes,
            row.slot_bytes,
            row.satellite_bytes,
            total,
            per,
        });
    }
    const grand_total = report.totalBytes();
    const grand_per = if (report.total_instances > 0) grand_total / report.total_instances else 0;
    try out.print("{s:<32}  {d:>8}  {d:>10}  {d:>10}  {d:>10}  {d:>10}  {d:>8}\n", .{
        "TOTAL",
        report.total_instances,
        report.total_state_bytes,
        report.total_slot_bytes,
        report.total_satellite_bytes,
        grand_total,
        grand_per,
    });

    if (report.heap_stats) |st| {
        try out.writeAll("\nBrowser Heap Partitions:\n");
        try out.print("{s:<22}  {s:>10}  {s:>12}  {s:>12}  {s:>10}  {s:>10}  {s:>10}\n", .{
            "partition", "live blks", "live B", "committed B", "act spans", "emp spans", "dec spans",
        });
        try writePartitionRow(out, "node", st.node);
        try writePartitionRow(out, "satellite", st.satellite);
        try writePartitionRow(out, "objects (state+inst)", st.objects);
        try writePartitionRow(out, "objects (general)", st.general_objects);
        try writePartitionRow(out, "bytes", st.bytes);
        const total_committed = st.node.committed_span_bytes +
            st.satellite.committed_span_bytes +
            st.objects.committed_span_bytes +
            st.bytes.committed_span_bytes;
        try out.print(
            "  committed total: {d} B ({d:.2} MiB); quarantine: {d} blks / {d} B (held {d}, evicted {d})\n",
            .{
                total_committed,
                @as(f64, @floatFromInt(total_committed)) / (1024.0 * 1024.0),
                st.quarantine_blocks,
                st.quarantine_bytes,
                st.quarantine_total_held,
                st.quarantine_total_evicted,
            },
        );
    } else {
        try out.writeAll("\nBrowser Heap Partitions: (no heap engine attached)\n");
    }
}

fn writePartitionRow(out: *std.Io.Writer, name: []const u8, p: runtime.heap.PartitionStats) !void {
    try out.print("{s:<22}  {d:>10}  {d:>12}  {d:>12}  {d:>10}  {d:>10}  {d:>10}\n", .{
        name,
        p.live_blocks,
        p.live_bytes,
        p.committed_span_bytes,
        p.spans_active,
        p.spans_empty,
        p.spans_decommitted,
    });
}
