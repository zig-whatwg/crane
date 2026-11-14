//! Where a node's bytes go, field by field and owner by owner (lane nm1,
//! batch 1, step 0: the state of the node memory plan on today's main).
//!
//! A PROBE, not a pin: it prints and asserts only that its own tables add
//! up. It is lane nodedata's probe (tests/dom/nodedata_layout_probe_test.zig
//! on the unmerged branch lane/nodedata, 2026-11-10), brought to today's
//! types, plus a census BY OWNER: for nodes made the way a page makes them,
//! the bytes each allocator hands out per node - the state arena (the node's
//! one State block and its size class), the Instance slab, and every block
//! the general allocator gives (attribute blocks, name and value records,
//! rare blocks), by size.
//!
//! The static walk prints, for every type a node's storage is made of, each
//! field's offset, size and alignment with the padding between them marked,
//! flattened through every by-value struct (a generated State nests its
//! parent's through `base`, each level's InternalState through `_embedded`,
//! NodeBase through Node's `base`).
//!
//! The launcher keeps a passing test's output nowhere: run the test
//! executable directly to read it (lesson
//! testing-a-passing-cost-test-prints-nothing-under-the-launcher).
//!
//! It names generated interfaces, their States and src/dom types only; an
//! impl's InternalState is reached as its State's `_embedded` field type,
//! never through the impl (AGENTS.md "The impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");

const NodeBase = dom.NodeBase;

/// How deep the flattened walk descends into by-value structs.
const max_depth = 8;

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// ============================================================================
// The static walk
// ============================================================================

fn isWalkedStruct(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;
    const s = info.@"struct";
    if (s.layout == .@"packed" or s.is_tuple) return false;
    return s.field_names.len != 0 and @sizeOf(T) != 0;
}

fn layoutName(comptime T: type) []const u8 {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| @tagName(s.layout),
        .@"union" => |u| @tagName(u.layout),
        else => "-",
    };
}

/// The field indices of `T` in offset order (comptime fields and zero-size
/// fields kept: the caller skips them).
fn offsetOrder(comptime T: type) [@typeInfo(T).@"struct".field_names.len]usize {
    @setEvalBranchQuota(1_000_000);
    const info = @typeInfo(T).@"struct";
    var idx: [info.field_names.len]usize = undefined;
    for (&idx, 0..) |*p, i| p.* = i;
    var i: usize = 1;
    while (i < idx.len) : (i += 1) {
        var j = i;
        while (j > 0 and fieldOffset(T, idx[j - 1]) > fieldOffset(T, idx[j])) : (j -= 1) {
            const t = idx[j];
            idx[j] = idx[j - 1];
            idx[j - 1] = t;
        }
    }
    return idx;
}

fn fieldOffset(comptime T: type, comptime i: usize) usize {
    const info = @typeInfo(T).@"struct";
    if (info.field_attrs[i].@"comptime") return 0;
    if (@sizeOf(info.field_types[i]) == 0) return 0;
    return @offsetOf(T, info.field_names[i]);
}

/// Whether Zig's auto layout moved fields of `T` out of declaration order.
fn reordered(comptime T: type) bool {
    return comptime blk: {
        const info = @typeInfo(T).@"struct";
        if (info.layout != .auto) break :blk false;
        var last: usize = 0;
        var first = true;
        for (0..info.field_names.len) |i| {
            if (info.field_attrs[i].@"comptime" or @sizeOf(info.field_types[i]) == 0) continue;
            const off = @offsetOf(T, info.field_names[i]);
            if (!first and off < last) break :blk true;
            last = off;
            first = false;
        }
        break :blk false;
    };
}

/// The struct a pointer-shaped field points at (`*T`, `?*T`, `*const T`),
/// or null.
fn pointee(comptime F: type) ?type {
    const info = @typeInfo(F);
    const P = switch (info) {
        .optional => |o| o.child,
        .pointer => F,
        else => return null,
    };
    const p = @typeInfo(P);
    if (p != .pointer or p.pointer.size != .one) return null;
    const C = p.pointer.child;
    if (@typeInfo(C) != .@"struct") return null;
    if (@sizeOf(C) == 0) return null;
    return C;
}

fn kindOf(comptime F: type) []const u8 {
    return switch (@typeInfo(F)) {
        .pointer => |p| if (p.size == .slice) "slice" else "ptr",
        .optional => |o| switch (@typeInfo(o.child)) {
            .pointer => |p| if (p.size == .slice) "?slice" else "?ptr",
            else => "?value",
        },
        .@"union" => |u| if (u.tag_type != null) "union(tag)" else "union",
        .int => "int",
        .bool => "bool",
        .@"enum" => "enum",
        .array => "array",
        .@"struct" => |s| if (s.layout == .@"packed") "packed" else "struct",
        .float => "float",
        else => "other",
    };
}

const Totals = struct {
    leaves: usize = 0,
    leaf_bytes: usize = 0,
    pad_bytes: usize = 0,
    ptr_fields: usize = 0,
    ptr_bytes: usize = 0,
};

fn trimName(comptime n: []const u8) []const u8 {
    return if (n.len > 72) n[0..72] else n;
}

fn walkStatic(comptime T: type, comptime path: []const u8, comptime base: usize, comptime depth: usize, totals: *Totals) void {
    @setEvalBranchQuota(1_000_000);
    const info = @typeInfo(T).@"struct";
    const order = comptime offsetOrder(T);
    comptime var cursor: usize = base;
    inline for (order) |fi| {
        const name = info.field_names[fi];
        const F = info.field_types[fi];
        if (comptime info.field_attrs[fi].@"comptime" or @sizeOf(F) == 0) continue;
        const off = comptime base + @offsetOf(T, name);
        if (comptime off > cursor) {
            const at: usize = cursor;
            print("  {d:>5} {d:>5}        {s}  PAD\n", .{ at, off - at, path });
            totals.pad_bytes += off - at;
        }
        const sub = if (path.len == 0) name else path ++ "." ++ name;
        if (comptime isWalkedStruct(F) and depth < max_depth) {
            print("  {d:>5} {d:>5} {d:>5}  {s}: {s} [{s}{s}]\n", .{ off, @sizeOf(F), @alignOf(F), sub, trimName(@typeName(F)), layoutName(F), if (reordered(F)) ", auto-reordered" else "" });
            walkStatic(F, sub, off, depth + 1, totals);
        } else {
            const kind = comptime kindOf(F);
            print("  {d:>5} {d:>5} {d:>5}  {s}  {s}  {s}\n", .{ off, @sizeOf(F), @alignOf(F), sub, kind, trimName(@typeName(F)) });
            totals.leaves += 1;
            totals.leaf_bytes += @sizeOf(F);
            if (comptime std.mem.eql(u8, kind, "ptr") or std.mem.eql(u8, kind, "?ptr")) {
                totals.ptr_fields += 1;
                totals.ptr_bytes += @sizeOf(F);
            }
        }
        cursor = off + @sizeOf(F);
    }
    if (comptime base + @sizeOf(T) > cursor) {
        const at: usize = cursor;
        print("  {d:>5} {d:>5}        {s}  PAD (tail)\n", .{ at, base + @sizeOf(T) - at, path });
        totals.pad_bytes += base + @sizeOf(T) - at;
    }
}

/// Prints `T` flattened; fails if fields + padding do not make @sizeOf(T).
fn dumpType(comptime label: []const u8, comptime T: type) !void {
    print("\n=== {s}: {s}\n", .{ label, @typeName(T) });
    if (comptime @sizeOf(T) == 0) {
        print("    size 0 (nothing kept)\n", .{});
        return;
    }
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(T), @alignOf(T));
    print("    size {d}, align {d}, layout {s}{s}; state-arena block {d} (+{d}); mode {s}, runtime_safety {}\n", .{
        @sizeOf(T), @alignOf(T),       layoutName(T),          if (comptime isWalkedStruct(T) and reordered(T)) ", auto-reordered" else "",
        held,       held - @sizeOf(T), @tagName(builtin.mode), std.debug.runtime_safety,
    });
    if (comptime !isWalkedStruct(T)) {
        print("  {d:>5} {d:>5} {d:>5}  (leaf)  {s}\n", .{ 0, @sizeOf(T), @alignOf(T), comptime kindOf(T) });
        return;
    }
    print("    {s:>5} {s:>5} {s:>5}  {s}\n", .{ "off", "size", "align", "field" });
    var totals: Totals = .{};
    walkStatic(T, "", 0, 0, &totals);
    print("    total: {d} leaf fields, {d} B in fields, {d} B padding, {d} pointer fields ({d} B)\n", .{ totals.leaves, totals.leaf_bytes, totals.pad_bytes, totals.ptr_fields, totals.ptr_bytes });
    if (totals.leaf_bytes + totals.pad_bytes != @sizeOf(T)) {
        print("    MISMATCH: {d} + {d} != {d}\n", .{ totals.leaf_bytes, totals.pad_bytes, @sizeOf(T) });
        return error.LayoutDoesNotAddUp;
    }
}

/// The struct types the pointer-shaped fields of `T` point at, reached
/// through its by-value structs.
fn collectPointees(comptime T: type, comptime depth: usize, comptime acc: []const type) []const type {
    @setEvalBranchQuota(1_000_000);
    comptime {
        var out = acc;
        const info = @typeInfo(T).@"struct";
        for (info.field_types, 0..) |F, i| {
            if (info.field_attrs[i].@"comptime" or @sizeOf(F) == 0) continue;
            if (isWalkedStruct(F) and depth < max_depth) {
                out = collectPointees(F, depth + 1, out);
            } else if (pointee(F)) |C| {
                if (!containsType(out, C)) out = out ++ [_]type{C};
            }
        }
        return out;
    }
}

fn containsType(comptime list: []const type, comptime T: type) bool {
    for (list) |L| if (L == T) return true;
    return false;
}

// ============================================================================
// The runtime walk: what each field of a real node holds
// ============================================================================

const Census = struct {
    leaves: usize = 0,
    ptr_fields: usize = 0,
    ptr_null: usize = 0,
    ptr_bytes_null: usize = 0,
    zero_leaf_bytes: usize = 0,
    leaf_bytes: usize = 0,
};

fn walkValues(comptime T: type, v: *const T, comptime path: []const u8, comptime base: usize, comptime depth: usize, c: *Census) void {
    @setEvalBranchQuota(1_000_000);
    const info = @typeInfo(T).@"struct";
    const order = comptime offsetOrder(T);
    inline for (order) |fi| {
        const name = info.field_names[fi];
        const F = info.field_types[fi];
        if (comptime info.field_attrs[fi].@"comptime" or @sizeOf(F) == 0) continue;
        const off = comptime base + @offsetOf(T, name);
        const sub = if (path.len == 0) name else path ++ "." ++ name;
        const fv: *const F = &@field(v.*, name);
        if (comptime isWalkedStruct(F) and depth < max_depth) {
            walkValues(F, fv, sub, off, depth + 1, c);
        } else {
            describe(F, fv, sub, off, c);
        }
    }
}

fn describe(comptime F: type, p: *const F, comptime path: []const u8, comptime off: usize, c: *Census) void {
    const bytes = std.mem.asBytes(p);
    const zero = std.mem.allEqual(u8, bytes, 0);
    c.leaves += 1;
    c.leaf_bytes += @sizeOf(F);
    if (zero) c.zero_leaf_bytes += @sizeOf(F);
    const kind = comptime kindOf(F);
    const is_ptr = comptime std.mem.eql(u8, kind, "ptr") or std.mem.eql(u8, kind, "?ptr");
    if (is_ptr) {
        c.ptr_fields += 1;
        if (zero) {
            c.ptr_null += 1;
            c.ptr_bytes_null += @sizeOf(F);
        }
    }
    var buf: [96]u8 = undefined;
    const what: []const u8 = switch (@typeInfo(F)) {
        .optional => |o| blk: {
            if (p.* == null) break :blk "null";
            switch (@typeInfo(o.child)) {
                .pointer => |pp| {
                    if (pp.size == .slice) break :blk std.fmt.bufPrint(&buf, "set, len {d}", .{p.*.?.len}) catch "set";
                    break :blk "set";
                },
                .@"union" => |u| {
                    if (u.tag_type != null) break :blk std.fmt.bufPrint(&buf, "set, tag {s}", .{@tagName(std.meta.activeTag(p.*.?))}) catch "set";
                    break :blk "set";
                },
                else => break :blk "set",
            }
        },
        .pointer => |pp| blk: {
            if (pp.size == .slice) break :blk std.fmt.bufPrint(&buf, "len {d}", .{p.*.len}) catch "slice";
            break :blk if (zero) "0 (null)" else "set";
        },
        .@"union" => |u| blk: {
            if (u.tag_type != null) {
                const tag = std.meta.activeTag(p.*);
                break :blk std.fmt.bufPrint(&buf, "tag {s}{s}", .{ @tagName(tag), unionPayloadLen(F, p) }) catch "tag";
            }
            break :blk if (zero) "all zero" else "nonzero";
        },
        .int => std.fmt.bufPrint(&buf, "{d}", .{p.*}) catch "int",
        .bool => if (p.*) "true" else "false",
        .@"enum" => std.fmt.bufPrint(&buf, "{d}", .{@backingInt(p.*)}) catch "enum",
        else => if (zero) "all zero" else "nonzero",
    };
    print("  {d:>5} {d:>5}  {s:<56} {s}\n", .{ off, @sizeOf(F), path, what });
}

/// ", len N" for a tagged union whose active payload is a slice (DOMString).
fn unionPayloadLen(comptime U: type, p: *const U) []const u8 {
    const info = @typeInfo(U).@"union";
    inline for (info.field_names, info.field_types) |name, T| {
        if (std.mem.eql(u8, @tagName(std.meta.activeTag(p.*)), name)) {
            const ti = @typeInfo(T);
            if (ti == .pointer and ti.pointer.size == .slice) {
                const len = @field(p.*, name).len;
                return if (len == 0) ", len 0" else if (len <= 8) ", len 1-8" else if (len <= 32) ", len 9-32" else ", len 33+";
            }
        }
    }
    return "";
}

fn dumpValues(comptime State: type, comptime label: []const u8, instance: *runtime.Instance) !void {
    print("\n=== VALUES {s}: {s} (vtable {s}, state at 0x{x}, instance at 0x{x})\n", .{ label, @typeName(State), instance.vtable.name, @intFromPtr(instance.state), @intFromPtr(instance) });
    const s: *const State = @ptrCast(@alignCast(instance.state));
    var c: Census = .{};
    walkValues(State, s, "", 0, 0, &c);
    print("    census: {d} leaf fields ({d} B), {d} B all-zero; pointer fields {d}, null {d} ({d} B)\n", .{ c.leaves, c.leaf_bytes, c.zero_leaf_bytes, c.ptr_fields, c.ptr_null, c.ptr_bytes_null });
}

// ============================================================================
// An engine-less page (the fixture of tests/dom/perf3e1_element_registry_test.zig)
// ============================================================================

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Page = struct {
    allocator: std.mem.Allocator,
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    host: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .allocator = allocator, .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(self.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        _ = try dom.custom_elements.ensureGlobalRegistry(self.document);
        self.host = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.host);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    /// The first child of a new container the parser filled from `markup`.
    fn parsed(self: *Page, markup: []const u8) !*runtime.Instance {
        const box = try interfaces.Document.call_createElement(self.document, str("section"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.host, box);
        try interfaces.Element.set_innerHTML(box, .{ .domstring = str(markup) });
        return (try interfaces.Node.get_firstChild(box)) orelse error.NothingParsed;
    }
};

// ============================================================================
// The probe
// ============================================================================

const div_state = interfaces.HTMLDivElement.State;

fn Embedded(comptime State: type) type {
    return @FieldType(State, "_embedded");
}

test "nm1 probe: the static layout of a node's storage" {
    print("\n##### NM1 STATIC LAYOUT (mode {s}, runtime_safety {}, target {s}-{s})\n", .{ @tagName(builtin.mode), std.debug.runtime_safety, @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) });

    // The generated States, whole: one State block per node (perf2 b5 Z7).
    const states = .{
        .{ "HTMLDivElement.State", interfaces.HTMLDivElement.State },
        .{ "HTMLSpanElement.State", interfaces.HTMLSpanElement.State },
        .{ "HTMLAnchorElement.State", interfaces.HTMLAnchorElement.State },
        .{ "SVGSVGElement.State", interfaces.SVGSVGElement.State },
        .{ "SVGPathElement.State", interfaces.SVGPathElement.State },
        .{ "Text.State", interfaces.Text.State },
        .{ "Comment.State", interfaces.Comment.State },
        .{ "Document.State", interfaces.Document.State },
    };
    inline for (states) |e| try dumpType(e[0], e[1]);

    // Each level's InternalState, as its State keeps it (`_embedded`).
    const levels = .{
        .{ "EventTarget InternalState", Embedded(interfaces.EventTarget.State) },
        .{ "Node InternalState", Embedded(interfaces.Node.State) },
        .{ "Element InternalState", Embedded(interfaces.Element.State) },
        .{ "HTMLElement InternalState", Embedded(interfaces.HTMLElement.State) },
        .{ "CharacterData InternalState", Embedded(interfaces.CharacterData.State) },
        .{ "Text InternalState", Embedded(interfaces.Text.State) },
        .{ "Comment InternalState", Embedded(interfaces.Comment.State) },
        .{ "SVGElement InternalState", Embedded(interfaces.SVGElement.State) },
    };
    inline for (levels) |e| try dumpType(e[0], e[1]);

    // Document keeps its InternalState in a block of its own.
    const DocInternal = @typeInfo(@typeInfo(@FieldType(@FieldType(interfaces.Document.State, "own"), "_internal")).optional.child).pointer.child;
    print("\n=== Document InternalState (its own block): {s}: size {d}, align {d}, state-arena block {d}\n", .{ @typeName(DocInternal), @sizeOf(DocInternal), @alignOf(DocInternal), runtime.ArenaAllocator.heldBytes(@sizeOf(DocInternal), @alignOf(DocInternal)) });

    // The parts, and what the element's fields point at.
    const parts = .{
        .{ "NodeBase", NodeBase },
        .{ "NodeBase.RcFlags", NodeBase.RcFlags },
        .{ "NodeRareData", dom.node_base.NodeRareData },
        .{ "ObserverRegistration", dom.node_base.ObserverRegistration },
        .{ "ElementData", dom.element_data.ElementData },
        .{ "element_data.AttributeList", dom.element_data.AttributeList },
        .{ "element_data.Entry (one attribute)", dom.element_data.Entry },
        .{ "element_data.AttrNodeList", dom.element_data.AttrNodeList },
        .{ "attribute_names.QualifiedName", dom.attribute_names.QualifiedName },
        .{ "attribute_values.Value", dom.attribute_values.Value },
        .{ "element_name.ElementName", dom.element_name.ElementName },
        .{ "element_rare_data.Holder", dom.element_rare_data.Holder },
        .{ "element_rare_data.Block (header; its slots trail it)", dom.element_rare_data.Block },
        .{ "event_listener_list.List", dom.event_listener_list.List },
        .{ "event_listener_list.Listener", dom.event_listener_list.Listener },
        .{ "ElementStyle", dom.style.ElementStyle },
        .{ "custom_elements.State (custom element state)", dom.custom_elements.State },
        .{ "custom_elements.RegistryPlace", dom.custom_elements.RegistryPlace },
        .{ "character_data.Data", dom.character_data.Data },
        .{ "DOMString", runtime.DOMString },
        .{ "Instance (the slab slot's payload)", runtime.Instance },
        .{ "engine.NodeWrapperSlot", engine.NodeWrapperSlot },
    };
    inline for (parts) |e| try dumpType(e[0], e[1]);
    print("\n=== Slab slot: {d} B (Instance {d} + stamp 8), {d} slots per {d}-B slab\n", .{ runtime.SlabAllocator.slot_bytes, @sizeOf(runtime.Instance), runtime.SlabAllocator.SLOTS_PER_SLAB, runtime.SlabAllocator.slab_bytes });

    // Everything the element, text and comment States point at, one level.
    const roots = [_]type{ interfaces.HTMLDivElement.State, interfaces.HTMLAnchorElement.State, interfaces.SVGPathElement.State, interfaces.Text.State, interfaces.Comment.State, dom.element_data.ElementData, dom.node_base.NodeRareData };
    const pointees = comptime blk: {
        var acc: []const type = &.{};
        for (roots) |R| acc = collectPointees(R, 0, acc);
        break :blk acc;
    };
    print("\n##### POINTEES of the node States (one level), {d} types\n", .{pointees.len});
    inline for (pointees) |P| {
        if (comptime containsType(&.{ runtime.Instance, NodeBase, dom.node_base.NodeRareData, dom.element_data.AttributeList, dom.style.ElementStyle }, P)) {
            print("\n=== pointee {s}: size {d} (dumped above)\n", .{ @typeName(P), @sizeOf(P) });
        } else if (comptime @sizeOf(P) > 512) {
            print("\n=== pointee {s}: size {d}, align {d} (not expanded)\n", .{ @typeName(P), @sizeOf(P), @alignOf(P) });
        } else {
            try dumpType("pointee", P);
        }
    }
}

test "nm1 probe: what each field of a real node holds" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    print("\n##### NM1 VALUES (mode {s})\n", .{@tagName(builtin.mode)});

    // Parser-created (the fragment parser, innerHTML): what a page's nodes are.
    const pdiv = try page.parsed("<div></div>");
    try dumpValues(div_state, "parsed <div>", pdiv);
    const pdiv2 = try page.parsed("<div title=\"t\" data-k=\"v\"></div>");
    try dumpValues(div_state, "parsed <div title data-k> (2 attributes)", pdiv2);
    const pdiv3 = try page.parsed("<div id=\"main\" class=\"a b\"></div>");
    try dumpValues(div_state, "parsed <div id class>", pdiv3);
    const pspan = try page.parsed("<span>x</span>");
    try dumpValues(interfaces.HTMLSpanElement.State, "parsed <span>", pspan);
    const pa = try page.parsed("<a href=\"/x\">t</a>");
    try dumpValues(interfaces.HTMLAnchorElement.State, "parsed <a href>", pa);
    const psvg = try page.parsed("<svg viewBox=\"0 0 1 1\"><path d=\"M0 0\"/></svg>");
    try dumpValues(interfaces.SVGSVGElement.State, "parsed <svg viewBox>", psvg);
    const ppath = (try interfaces.Node.get_firstChild(psvg)) orelse return error.NoPath;
    try dumpValues(interfaces.SVGPathElement.State, "parsed <path d>", ppath);
    const ptext = try page.parsed("x");
    try dumpValues(interfaces.Text.State, "parsed Text 'x'", ptext);
    const ptext_long = try page.parsed("A text node longer than thirty-one bytes, on the heap.");
    try dumpValues(interfaces.Text.State, "parsed Text (54 bytes)", ptext_long);
    const pcomment = try page.parsed("<!--c-->");
    try dumpValues(interfaces.Comment.State, "parsed Comment", pcomment);

    // Made by script's paths (no wrapper here: an engine-less page).
    const cdiv = try interfaces.Document.call_createElement(page.document, str("div"), .{ .was_passed = false, .value = undefined });
    try dumpValues(div_state, "createElement('div'), detached", cdiv);
    _ = try interfaces.Node.call_appendChild(page.host, cdiv);
    try dumpValues(div_state, "createElement('div'), appended", cdiv);
    const ctext = try interfaces.Document.call_createTextNode(page.document, str("x"));
    try dumpValues(interfaces.Text.State, "createTextNode('x'), detached", ctext);

    // What the block computes with, checked on the parsed div: the NodeBase
    // at one offset, the owner word naming the Instance, the Instance's state
    // pointer naming the block. (Node's own copies of the NodeBase pointer
    // and the node type went in lane nm1's layout batch.)
    const s: *const div_state = @ptrCast(@alignCast(pdiv.state));
    const node_state = pdiv.getState(interfaces.Node.State);
    const node_internal = &node_state._embedded;
    const nb = &node_internal.base;
    print("\n##### LINKS on the parsed div\n", .{});
    const node_doc: usize = if (nb.documentInstance()) |d| @intFromPtr(d) else 0;
    print("  NodeBase.document_word 0x{x} names the Instance 0x{x}; the document's Instance 0x{x}\n", .{ nb.document_word, node_doc, @intFromPtr(page.document) });
    print("  NodeBase.owner 0x{x} == the div's Instance 0x{x}: {}\n", .{ nb.owner, @intFromPtr(pdiv), nb.owner == @intFromPtr(pdiv) });
    print("  Instance.state 0x{x} == the State block 0x{x}: {}\n", .{ @intFromPtr(pdiv.state), @intFromPtr(s), @intFromPtr(pdiv.state) == @intFromPtr(s) });
    print("  each level's state, offset from the block (stateAs reads the vtable's ancestry table):\n", .{});
    inline for (.{
        .{ "EventTarget.State", interfaces.EventTarget.State },
        .{ "Node.State", interfaces.Node.State },
        .{ "Element.State", interfaces.Element.State },
        .{ "HTMLElement.State", interfaces.HTMLElement.State },
        .{ "HTMLDivElement.State", interfaces.HTMLDivElement.State },
    }) |e| {
        const at = pdiv.getState(e[1]);
        print("    {s:<22} +{d}\n", .{ e[0], @intFromPtr(at) - @intFromPtr(s) });
    }
    print("  NodeBase at +{d} of the block\n", .{@intFromPtr(nb) - @intFromPtr(s)});
    print("  the vtable's ancestry table: {d} entries\n", .{pdiv.vtable.ancestors.len});
}

// ============================================================================
// Every node interface's State: one block per node, sized by its interface
// ============================================================================

fn isNodeState(comptime S: type) bool {
    comptime {
        var Cur = S;
        while (true) {
            if (Cur == interfaces.Node.State) return true;
            if (@typeInfo(Cur) != .@"struct" or !@hasField(Cur, "base")) return false;
            const B = @FieldType(Cur, "base");
            if (B == void) return false;
            Cur = B;
        }
    }
}

fn nodeInterfaceState(comptime D: type) ?type {
    comptime {
        if (@typeInfo(D) != .@"struct") return null;
        if (!@hasDecl(D, "State")) return null;
        if (@TypeOf(D.State) != type) return null;
        if (!isNodeState(D.State)) return null;
        return D.State;
    }
}

/// Where NodeBase sits in a node interface's State: down the `base` chain to
/// Node's State, then its embedded state's `base`.
fn nodeBaseOffset(comptime S: type) usize {
    comptime {
        var off: usize = 0;
        var Cur = S;
        while (Cur != interfaces.Node.State) {
            off += @offsetOf(Cur, "base");
            Cur = @FieldType(Cur, "base");
        }
        const E = @FieldType(Cur, "_embedded");
        return off + @offsetOf(Cur, "_embedded") + @offsetOf(E, "base");
    }
}

/// The bytes each level above `Upto` adds to `S` (its own cached pointers and
/// embedded state), and the levels that keep their state in a block of
/// their own (`own._internal`), with that block's size.
fn printLevels(comptime S: type) void {
    comptime var Cur = S;
    inline while (true) {
        if (comptime @hasField(Cur, "own")) {
            const Own = @FieldType(Cur, "own");
            if (comptime @hasField(Own, "_internal")) {
                const T = @typeInfo(@typeInfo(@FieldType(Own, "_internal")).optional.child).pointer.child;
                print(" separate:{s}={d}", .{ @typeName(T), @sizeOf(T) });
            }
        }
        if (comptime !@hasField(Cur, "base") or @FieldType(Cur, "base") == void) break;
        Cur = @FieldType(Cur, "base");
    }
}

test "nm1 probe: every node interface's State size" {
    @setEvalBranchQuota(100_000_000);
    print("\n##### STATESIZE (mode {s}): interface, @sizeOf(State), state-arena block, levels kept in blocks of their own\n", .{@tagName(builtin.mode)});
    const decls = comptime @typeInfo(interfaces).@"struct".decl_names;
    var count: usize = 0;
    inline for (decls) |name| {
        const D = @field(interfaces, name);
        if (comptime @TypeOf(D) == type) {
            if (comptime nodeInterfaceState(D)) |S| {
                print("STATESIZE {s} {d} {d} nodebase@{d}", .{ name, @sizeOf(S), runtime.ArenaAllocator.heldBytes(@sizeOf(S), @alignOf(S)), comptime nodeBaseOffset(S) });
                printLevels(S);
                print("\n", .{});
                count += 1;
            }
        }
    }
    print("STATESIZE count {d}\n", .{count});
    try testing.expect(count > 100);
}

// ============================================================================
// Which levels' blocks of their own a parsed element makes
// ============================================================================

/// Each `own._internal` down `S`'s chain on `instance`: set or null, and the
/// block's size - the bytes a parsed element of that interface holds outside
/// its State block.
fn printSeparate(comptime S: type, label: []const u8, instance: *runtime.Instance) void {
    const s: *const S = @ptrCast(@alignCast(instance.state));
    print("SEPARATE {s} ({s}):", .{ label, instance.vtable.name });
    const rare_set = blk: {
        const node_state = instance.getState(interfaces.Node.State);
        break :blk node_state._embedded.base.rare != null;
    };
    walkSeparate(S, s);
    print(" noderare={}\n", .{rare_set});
}

fn walkSeparate(comptime S: type, s: *const S) void {
    if (comptime @hasField(S, "own")) {
        const Own = @FieldType(S, "own");
        if (comptime @hasField(Own, "_internal")) {
            const T = @typeInfo(@typeInfo(@FieldType(Own, "_internal")).optional.child).pointer.child;
            print(" {s}={s}/{d}", .{ @typeName(T), if (s.own._internal != null) "set" else "null", @sizeOf(T) });
        }
    }
    if (comptime @hasField(S, "base") and @FieldType(S, "base") != void) walkSeparate(@FieldType(S, "base"), &s.base);
}

test "nm1 probe: the blocks of their own a parsed element makes" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    print("\n##### SEPARATE (mode {s}): each level's own block on a parsed element, and its NodeRareData\n", .{@tagName(builtin.mode)});
    const cases = .{
        .{ "<script>x</script>", interfaces.HTMLScriptElement.State },
        .{ "<img src=\"a.png\">", interfaces.HTMLImageElement.State },
        .{ "<link rel=\"stylesheet\" href=\"a.css\">", interfaces.HTMLLinkElement.State },
        .{ "<style>p{}</style>", interfaces.HTMLStyleElement.State },
        .{ "<input name=\"q\">", interfaces.HTMLInputElement.State },
        .{ "<button>b</button>", interfaces.HTMLButtonElement.State },
        .{ "<form></form>", interfaces.HTMLFormElement.State },
        .{ "<select><option>o</option></select>", interfaces.HTMLSelectElement.State },
        .{ "<textarea>t</textarea>", interfaces.HTMLTextAreaElement.State },
        .{ "<iframe></iframe>", interfaces.HTMLIFrameElement.State },
        .{ "<a href=\"/x\">a</a>", interfaces.HTMLAnchorElement.State },
        .{ "<meta name=\"k\" content=\"v\">", interfaces.HTMLMetaElement.State },
        .{ "<source src=\"a.webm\">", interfaces.HTMLSourceElement.State },
        .{ "<table><tbody><tr><td>c</td></tr></tbody></table>", interfaces.HTMLTableElement.State },
        .{ "<svg><path d=\"M0 0\"/></svg>", interfaces.SVGSVGElement.State },
        .{ "<template><p>t</p></template>", interfaces.HTMLTemplateElement.State },
    };
    inline for (cases) |c| {
        const el = try page.parsed(c[0]);
        printSeparate(c[1], c[0], el);
    }
    // The table's row and the select's option: their own blocks too.
    const table = try page.parsed("<table><tbody><tr><td>c</td></tr></tbody></table>");
    const tbody = (try interfaces.Node.get_firstChild(table)).?;
    printSeparate(interfaces.HTMLTableSectionElement.State, "tbody", tbody);
    const tr = (try interfaces.Node.get_firstChild(tbody)).?;
    printSeparate(interfaces.HTMLTableRowElement.State, "tr", tr);
    const select = try page.parsed("<select><option>o</option></select>");
    printSeparate(interfaces.HTMLOptionElement.State, "option", (try interfaces.Node.get_firstChild(select)).?);
    const svg = try page.parsed("<svg><path d=\"M0 0\"/></svg>");
    printSeparate(interfaces.SVGPathElement.State, "path", (try interfaces.Node.get_firstChild(svg)).?);
}

// ============================================================================
// The census by owner: what each allocator hands out per node (lane nm1)
// ============================================================================

/// Counts what the page's general allocator holds, by block size: every
/// block of up to `small_limit` bytes in a histogram of its exact requested
/// length, larger ones (the state arena's chunks, the Instance slab's slabs,
/// tables) as a count and a byte total.
const OwnerCount = struct {
    child: std.mem.Allocator,
    small: [small_limit + 1]i64 = @splat(0),
    large_blocks: i64 = 0,
    large_bytes: i64 = 0,

    const small_limit = 2048;

    fn note(self: *OwnerCount, len: usize, sign: i64) void {
        if (len <= small_limit) {
            self.small[len] += sign;
        } else {
            self.large_blocks += sign;
            self.large_bytes += sign * @as(i64, @intCast(len));
        }
    }

    fn allocator(self: *OwnerCount) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *OwnerCount = @ptrCast(@alignCast(ctx));
        const p = self.child.rawAlloc(len, alignment, ra) orelse return null;
        self.note(len, 1);
        return p;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *OwnerCount = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(buf, alignment, new_len, ra)) return false;
        self.note(buf.len, -1);
        self.note(new_len, 1);
        return true;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *OwnerCount = @ptrCast(@alignCast(ctx));
        const p = self.child.rawRemap(buf, alignment, new_len, ra) orelse return null;
        self.note(buf.len, -1);
        self.note(new_len, 1);
        return p;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *OwnerCount = @ptrCast(@alignCast(ctx));
        self.child.rawFree(buf, alignment, ra);
        self.note(buf.len, -1);
    }
};

const Reading = struct {
    arena_in_use: usize,
    arena_allocations: usize,
    slab_live: usize,
    small: [OwnerCount.small_limit + 1]i64,
    large_blocks: i64,
    large_bytes: i64,

    fn take(page: *Page, count: *const OwnerCount) Reading {
        return .{
            .arena_in_use = page.scope.arena.stats().bytes_in_use,
            .arena_allocations = page.scope.arena.stats().total_allocations,
            .slab_live = page.scope.slab.stats().currently_allocated,
            .small = count.small,
            .large_blocks = count.large_blocks,
            .large_bytes = count.large_bytes,
        };
    }
};

/// How many nodes each case makes between its two readings, after a warm-up
/// of `warm` made the same way (so the names, the tables and the first
/// chunks are not charged to the nodes).
const census_n = 2048;
const census_warm = 64;

fn printCensus(label: []const u8, before: *const Reading, after: *const Reading, n: usize) void {
    const per = struct {
        fn of(total: i64, count: usize) f64 {
            return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(count));
        }
    }.of;
    const arena = @as(i64, @intCast(after.arena_in_use)) - @as(i64, @intCast(before.arena_in_use));
    const arena_blocks = @as(i64, @intCast(after.arena_allocations)) - @as(i64, @intCast(before.arena_allocations));
    const slab = @as(i64, @intCast(after.slab_live)) - @as(i64, @intCast(before.slab_live));
    print("\nCENSUS {s}: {d} nodes\n", .{ label, n });
    print("  state arena: {d:.2} B requested per node in {d:.2} blocks per node\n", .{ per(arena, n), per(arena_blocks, n) });
    print("  Instance slab: {d:.2} slots per node = {d:.2} B per node (slot {d} B)\n", .{ per(slab, n), per(slab * @as(i64, @intCast(runtime.SlabAllocator.slot_bytes)), n), runtime.SlabAllocator.slot_bytes });
    var small_bytes: i64 = 0;
    for (after.small, before.small, 0..) |a, b, len| {
        const d = a - b;
        if (d == 0) continue;
        small_bytes += d * @as(i64, @intCast(len));
        print("  general allocator: blocks of {d:>5} B: {d:>7} ({d:.3} per node, {d:.2} B per node requested)\n", .{ len, d, per(d, n), per(d * @as(i64, @intCast(len)), n) });
    }
    print("  general allocator, blocks of up to {d} B: {d:.2} B per node requested\n", .{ OwnerCount.small_limit, per(small_bytes, n) });
    print("  general allocator, larger blocks (arena chunks, slabs, tables): {d} blocks, {d} B = {d:.2} B per node\n", .{ after.large_blocks - before.large_blocks, after.large_bytes - before.large_bytes, per(after.large_bytes - before.large_bytes, n) });
}

const CensusCase = enum { div_detached, div_in_document, div_two_attributes, text_detached, parsed_span, parsed_div_two_attributes, parsed_span_with_text };

fn makeNodes(page: *Page, case: CensusCase, n: usize) !void {
    const no_options: @import("webidl").Opt(runtime.JSValue) = .{ .was_passed = false, .value = undefined };
    switch (case) {
        .div_detached => for (0..n) |_| {
            _ = try interfaces.Document.call_createElement(page.document, str("div"), no_options);
        },
        .div_in_document => for (0..n) |_| {
            const div = try interfaces.Document.call_createElement(page.document, str("div"), no_options);
            _ = try interfaces.Node.call_appendChild(page.host, div);
        },
        .div_two_attributes => for (0..n) |_| {
            const div = try interfaces.Document.call_createElement(page.document, str("div"), no_options);
            try interfaces.Element.call_setAttribute(div, str("title"), .{ .domstring = str("t") });
            try interfaces.Element.call_setAttribute(div, str("data-k"), .{ .domstring = str("v") });
        },
        .text_detached => for (0..n) |_| {
            _ = try interfaces.Document.call_createTextNode(page.document, str("x"));
        },
        .parsed_span, .parsed_div_two_attributes, .parsed_span_with_text => {
            const one: []const u8 = switch (case) {
                .parsed_span => "<span></span>",
                .parsed_div_two_attributes => "<div title=\"t\" data-k=\"v\"></div>",
                else => "<span>x</span>",
            };
            const markup = try page.allocator.alloc(u8, one.len * n);
            defer page.allocator.free(markup);
            for (0..n) |i| @memcpy(markup[i * one.len ..][0..one.len], one);
            const box = try interfaces.Document.call_createElement(page.document, str("section"), no_options);
            _ = try interfaces.Node.call_appendChild(page.host, box);
            try interfaces.Element.set_innerHTML(box, .{ .domstring = str(markup) });
        },
    }
}

test "nm1 probe: the bytes each allocator hands out per node, by owner" {
    print("\n##### NM1 CENSUS BY OWNER (engine-less page: no wrapper; mode {s}, target {s}-{s}); {d} nodes a case after {d} made the same way\n", .{ @tagName(builtin.mode), @tagName(builtin.cpu.arch), @tagName(builtin.os.tag), census_n, census_warm });
    print("  the state arena's classes: a div's State {d} B -> block {d} B; a Text's {d} -> {d}\n", .{
        @sizeOf(div_state),             runtime.ArenaAllocator.heldBytes(@sizeOf(div_state), @alignOf(div_state)),
        @sizeOf(interfaces.Text.State), runtime.ArenaAllocator.heldBytes(@sizeOf(interfaces.Text.State), @alignOf(interfaces.Text.State)),
    });
    inline for (comptime std.enums.values(CensusCase)) |case| {
        var count: OwnerCount = .{ .child = testing.allocator };
        var page: Page = undefined;
        try page.open(count.allocator());
        defer page.close();
        try makeNodes(&page, case, census_warm);
        const before = Reading.take(&page, &count);
        try makeNodes(&page, case, census_n);
        const after = Reading.take(&page, &count);
        // A parsed case makes one container beside its nodes: say so.
        const label = switch (case) {
            .div_detached => "createElement('div'), detached",
            .div_in_document => "createElement('div') appended to a connected element",
            .div_two_attributes => "createElement('div') + setAttribute('title','t') + setAttribute('data-k','v'), detached",
            .text_detached => "createTextNode('x'), detached",
            .parsed_span => "parsed <span></span>, one innerHTML (+1 container section in the count)",
            .parsed_div_two_attributes => "parsed <div title=\"t\" data-k=\"v\"></div>, one innerHTML (+1 container section)",
            .parsed_span_with_text => "parsed <span>x</span>, one innerHTML: a span AND its Text per count (+1 container section)",
        };
        printCensus(label, &before, &after, census_n);
    }
}
