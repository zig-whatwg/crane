//! HTML 4.9: table collections and the internal table mutation algorithms.
//! HTMLTableRowsCollection in WebKit uses the same three traversal phases:
//! https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLTableRowsCollection.cpp
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const Filter = dom.live_collections.TableFilter;

/// An owner's SameObject child, with the same traced edge and generation
/// check as form.elements/select.options. The collection traces its root too.
pub const Collection = struct {
    child: ?*runtime.Instance = null,
    generation: u64 = 0,
    traced: bool = false,

    pub fn get(self: *Collection, owner: *runtime.Instance, filter: Filter, comptime slot: []const u8) !*runtime.Instance {
        if (@import("forms/root.zig").liveChild(self.child, self.generation)) |child| return child;
        const child = try interfaces.HTMLCollection.init(owner.ctx.allocator, owner.ctx);
        errdefer runtime.Instance.deinit(child);
        try dom.live_collections.table(child, owner, filter);
        if (owner.ctx.hasEngine()) {
            engine.traceChild(owner, child, .{ .name = slot });
            self.traced = true;
        }
        self.child = child;
        self.generation = runtime.SlabAllocator.generationOf(child);
        return child;
    }

    pub fn deinit(self: *Collection, owner: *runtime.Instance, comptime slot: []const u8) void {
        if (self.traced) {
            engine.forgetTracedChild(owner, .{ .name = slot });
        } else if (@import("forms/root.zig").liveChild(self.child, self.generation)) |child| {
            runtime.Instance.deinit(child);
        }
        self.* = .{};
    }
};

pub fn isNamed(node: *runtime.Instance, comptime name: []const u8) bool {
    if (node.stateAs(interfaces.HTMLElement.State) == null) return false;
    var local = interfaces.Element.get_localName(node) catch return false;
    defer local.deinit(node.ctx.allocator);
    return std.mem.eql(u8, local.asSlice(), name);
}

pub fn firstChildNamed(parent: *runtime.Instance, comptime name: []const u8) !?*runtime.Instance {
    var child = try interfaces.Node.get_firstChild(parent);
    while (child) |current| : (child = try interfaces.Node.get_nextSibling(current)) {
        if (isNamed(current, name)) return current;
    }
    return null;
}

/// Visit only the immediate HTML children named by the collection's filter.
/// table.rows: all thead rows, then direct rows and tbody rows, then tfoot rows.
/// A section inside another table/section is never descended into.
pub fn forEach(root: *runtime.Instance, filter: Filter, context: anytype, comptime visit: fn (@TypeOf(context), *runtime.Instance) anyerror!void) anyerror!void {
    if (filter == .table_rows) {
        for (0..3) |phase| {
            var child = try interfaces.Node.get_firstChild(root);
            while (child) |current| : (child = try interfaces.Node.get_nextSibling(current)) {
                if ((phase == 0 and isNamed(current, "thead")) or
                    (phase == 1 and isNamed(current, "tbody")) or
                    (phase == 2 and isNamed(current, "tfoot")))
                {
                    try forEach(current, .section_rows, context, visit);
                } else if (phase == 1 and current.stateAs(interfaces.HTMLTableRowElement.State) != null) {
                    try visit(context, current);
                }
            }
        }
        return;
    }
    var child = try interfaces.Node.get_firstChild(root);
    while (child) |current| : (child = try interfaces.Node.get_nextSibling(current)) {
        const matches = switch (filter) {
            .bodies => isNamed(current, "tbody"),
            .section_rows => current.stateAs(interfaces.HTMLTableRowElement.State) != null,
            .row_cells => current.stateAs(interfaces.HTMLTableCellElement.State) != null,
            .table_rows => unreachable,
        };
        if (matches) try visit(context, current);
    }
}

const Scan = struct {
    length: usize = 0,
    wanted: i32,
    at: ?*runtime.Instance = null,
    last: ?*runtime.Instance = null,

    fn visit(self: *Scan, node: *runtime.Instance) anyerror!void {
        if (self.wanted >= 0 and self.length == @as(usize, @intCast(self.wanted))) self.at = node;
        self.length += 1;
        self.last = node;
    }
};

pub fn indexOf(root: *runtime.Instance, filter: Filter, target: *runtime.Instance) !i32 {
    const Index = struct {
        target: *runtime.Instance,
        length: i32 = 0,
        found: i32 = -1,
        fn visit(self: *@This(), node: *runtime.Instance) anyerror!void {
            if (node == self.target) self.found = self.length;
            self.length += 1;
        }
    };
    var index = Index{ .target = target };
    try forEach(root, filter, &index, Index.visit);
    return index.found;
}

/// HTML section.insertRow and row.insertCell, steps 1–6.
pub fn insertChild(root: *runtime.Instance, filter: Filter, comptime name: []const u8, index: i32) !*runtime.Instance {
    var scan = Scan{ .wanted = index };
    try forEach(root, filter, &scan, Scan.visit);
    if (index < -1 or (index >= 0 and @as(usize, @intCast(index)) > scan.length)) return error.IndexSizeError;
    const child = try createElement(root, name);
    errdefer dom.node_creation.destroyUninserted(child);
    try insert(root, child, scan.at);
    return child;
}

/// HTML table.insertRow: its collection order can differ from tree order.
pub fn insertRow(table: *runtime.Instance, index: i32) !*runtime.Instance {
    var scan = Scan{ .wanted = index };
    try forEach(table, .table_rows, &scan, Scan.visit);
    if (index < -1 or (index >= 0 and @as(usize, @intCast(index)) > scan.length)) return error.IndexSizeError;
    const row = try createElement(table, "tr");
    var owned_by_body = false;
    errdefer if (!owned_by_body) dom.node_creation.destroyUninserted(row);
    if (scan.length == 0) {
        var bodies = Scan{ .wanted = -1 };
        try forEach(table, .bodies, &bodies, Scan.visit);
        if (bodies.last) |body| {
            try insert(body, row, null);
        } else {
            // Steps 4.1–4.3: put the row in the new body BEFORE inserting
            // the body into the table (also observable to mutation observers).
            const body = try createElement(table, "tbody");
            errdefer dom.node_creation.destroyUninserted(body);
            try insert(body, row, null);
            owned_by_body = true;
            try insert(table, body, null);
        }
    } else {
        const reference = scan.at orelse scan.last.?;
        const parent = (try interfaces.Node.get_parentNode(reference)) orelse return error.InvalidStateError;
        try insert(parent, row, scan.at);
    }
    return row;
}

/// HTML deleteRow/deleteCell: -1 on an empty collection is a no-op.
pub fn deleteChild(root: *runtime.Instance, filter: Filter, index: i32) !void {
    var scan = Scan{ .wanted = index };
    try forEach(root, filter, &scan, Scan.visit);
    if (index < -1 or (index >= 0 and @as(usize, @intCast(index)) >= scan.length)) return error.IndexSizeError;
    if (if (index == -1) scan.last else scan.at) |child| try remove(child);
}

fn nodeBase(node: *runtime.Instance) !*dom.NodeBase {
    return dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse error.InvalidStateError;
}

/// Internal mutations stay inside the calling IDL member's CEReactions scope.
pub fn insert(parent: *runtime.Instance, child: *runtime.Instance, before: ?*runtime.Instance) !void {
    _ = try dom.mutation.preInsert(try nodeBase(child), try nodeBase(parent), if (before) |node| try nodeBase(node) else null);
}

pub fn remove(child: *runtime.Instance) !void {
    try dom.mutation.remove(try nodeBase(child), false);
}

pub fn removeFirst(parent: *runtime.Instance, comptime name: []const u8) !void {
    if (try firstChildNamed(parent, name)) |child| try remove(child);
}

pub fn headInsertionPoint(table: *runtime.Instance) !?*runtime.Instance {
    var child = try interfaces.Node.get_firstChild(table);
    while (child) |current| : (child = try interfaces.Node.get_nextSibling(current)) {
        if (current.stateAs(interfaces.Element.State) != null and !isNamed(current, "caption") and !isNamed(current, "colgroup")) return current;
    }
    return null;
}

pub fn createElement(owner: *runtime.Instance, comptime name: []const u8) !*runtime.Instance {
    const document = (try interfaces.Node.get_ownerDocument(owner)) orelse return error.InvalidStateError;
    // HTML "create an element": always HTML, including in XML documents.
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}
