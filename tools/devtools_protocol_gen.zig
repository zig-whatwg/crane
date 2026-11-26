//! The Chrome DevTools Protocol type generator.
//!
//! Usage:
//!   devtools_protocol_gen [--spec-dir <dir>] --dest <dir>            write the tree
//!   devtools_protocol_gen [--spec-dir <dir>] --dest <dir> --check    compare it
//!
//! Reads the pinned protocol definitions (specs/devtools-protocol/
//! browser_protocol.json and js_protocol.json, BSD-3, The Chromium Authors;
//! PIN.md names the version) and writes `src/devtools/protocol/`: one file per
//! domain with its types, its commands (`<command>.method`, `.Params`,
//! `.Result`) and its events (`<event>.method`, `.Params`), and `root.zig`
//! with every domain of both files and the method table (every command's
//! name and domain, sorted). Chromium generates its own bindings from the
//! same definitions (third_party/inspector_protocol); this is Crane's, for
//! Zig: types std.json parses and serializes directly.
//!
//! Generated whole: the domains in `full_domains` - the browser-side domains
//! of CDP part 1 (tmp/plans/cdp-part1-design.md 1.4) and Runtime, whose events
//! Crane builds itself. Every other domain gets only the types those
//! reference. Output is zig fmt-clean (rendered through std.zig.Ast), so
//! `zig fmt src/` leaves it alone and `--check` compares bytes.
//!
//! `zig build codegen` runs it with `--dest src/devtools/protocol`;
//! `zig build codegen-check` (part of `zig build test`) runs `--check`.

const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

/// The domains generated whole. Adding one is a regeneration, nothing else.
pub const full_domains = [_][]const u8{
    "Accessibility",
    "Audits",
    "Browser",
    "CSS",
    "DOM",
    "Emulation",
    "Fetch",
    "IO",
    "Input",
    "Inspector",
    "Log",
    "Network",
    "Page",
    "Performance",
    "Runtime",
    "Security",
    "Target",
};

/// Declarations every generated domain file makes itself; a protocol name
/// equal to one would clash, so the generator stops on it.
const reserved_file_decls = [_][]const u8{ "std", "protocol", "domain", "CommandName", "EventName" };
/// Declarations every command and event namespace makes.
const reserved_member_decls = [_][]const u8{ "method", "Params", "Result" };

pub const Origin = enum { browser_protocol, js_protocol };

const Domain = struct {
    name: []const u8,
    origin: Origin,
    value: json.ObjectMap,
};

pub const Spec = struct {
    arena: std.heap.ArenaAllocator,
    domains: []Domain,
    version_major: []const u8,
    version_minor: []const u8,
    package_version: []const u8,

    pub fn deinit(self: *Spec) void {
        self.arena.deinit();
    }

    fn domain(self: *const Spec, name: []const u8) ?*const Domain {
        for (self.domains) |*d| if (std.mem.eql(u8, d.name, name)) return d;
        return null;
    }
};

/// Parse the two protocol files (their text) into one spec.
pub fn parseSpec(gpa: Allocator, browser_text: []const u8, js_text: []const u8, package_version: []const u8) !Spec {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();
    var domains: std.ArrayList(Domain) = .empty;
    var major: []const u8 = "";
    var minor: []const u8 = "";
    for ([_]struct { text: []const u8, origin: Origin }{
        .{ .text = browser_text, .origin = .browser_protocol },
        .{ .text = js_text, .origin = .js_protocol },
    }) |file| {
        const root = try json.parseFromSliceLeaky(json.Value, a, file.text, .{});
        const object = asObject(root) orelse return error.InvalidProtocol;
        if (file.origin == .browser_protocol) {
            if (object.get("version")) |version| {
                const v = asObject(version) orelse return error.InvalidProtocol;
                major = stringField(v, "major") orelse "";
                minor = stringField(v, "minor") orelse "";
            }
        }
        const list = asArray(object.get("domains") orelse return error.InvalidProtocol) orelse return error.InvalidProtocol;
        for (list) |entry| {
            const d = asObject(entry) orelse return error.InvalidProtocol;
            try domains.append(a, .{
                .name = stringField(d, "domain") orelse return error.InvalidProtocol,
                .origin = file.origin,
                .value = d,
            });
        }
    }
    return .{
        .arena = arena,
        .domains = try domains.toOwnedSlice(a),
        .version_major = major,
        .version_minor = minor,
        .package_version = try a.dupe(u8, package_version),
    };
}

fn asObject(v: json.Value) ?json.ObjectMap {
    return switch (v) {
        .object => |o| o,
        else => null,
    };
}

fn asArray(v: json.Value) ?[]json.Value {
    return switch (v) {
        .array => |arr| arr.items,
        else => null,
    };
}

fn stringField(o: json.ObjectMap, name: []const u8) ?[]const u8 {
    const v = o.get(name) orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

fn boolField(o: json.ObjectMap, name: []const u8) bool {
    const v = o.get(name) orelse return false;
    return switch (v) {
        .bool => |b| b,
        else => false,
    };
}

fn listField(o: json.ObjectMap, name: []const u8) []json.Value {
    const v = o.get(name) orelse return &.{};
    return asArray(v) orelse &.{};
}

/// A type's qualified name, "Domain.Type".
const QualifiedName = []const u8;

fn qualify(a: Allocator, context_domain: []const u8, ref: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, ref, '.') != null) return ref;
    return std.fmt.allocPrint(a, "{s}.{s}", .{ context_domain, ref });
}

fn splitQualified(name: []const u8) struct { domain: []const u8, type_name: []const u8 } {
    const dot = std.mem.indexOfScalar(u8, name, '.').?;
    return .{ .domain = name[0..dot], .type_name = name[dot + 1 ..] };
}

/// What the generator decided: the types to write and which by-value
/// references are pointers (a type that contains itself).
const Plan = struct {
    a: Allocator,
    spec: *const Spec,
    /// The domains generated whole.
    full: []const []const u8,
    /// Qualified name -> its definition.
    types: std.StringArrayHashMapUnmanaged(json.ObjectMap) = .empty,
    /// Qualified names of the types to write.
    needed: std.StringArrayHashMapUnmanaged(void) = .empty,
    /// "From->To" for every by-value reference written as a pointer.
    pointers: std.StringHashMapUnmanaged(void) = .empty,

    fn isFull(plan: *const Plan, name: []const u8) bool {
        for (plan.full) |f| if (std.mem.eql(u8, f, name)) return true;
        return false;
    }

    fn init(a: Allocator, spec: *const Spec, full: []const []const u8) !Plan {
        var plan: Plan = .{ .a = a, .spec = spec, .full = full };
        for (spec.domains) |d| {
            for (listField(d.value, "types")) |t| {
                const o = asObject(t) orelse return error.InvalidProtocol;
                const id = stringField(o, "id") orelse return error.InvalidProtocol;
                try plan.types.put(a, try qualify(a, d.name, id), o);
            }
        }
        for (full) |name| {
            const d = spec.domain(name) orelse {
                std.debug.print("devtools_protocol_gen: full domain {s} is not in the protocol\n", .{name});
                return error.UnknownDomain;
            };
            for (listField(d.value, "types")) |t| {
                try plan.need(try qualify(a, d.name, stringField(asObject(t).?, "id").?));
            }
            for (listField(d.value, "commands")) |cmd| {
                const o = asObject(cmd).?;
                for (listField(o, "parameters")) |p| try plan.walk(d.name, asObject(p).?);
                for (listField(o, "returns")) |p| try plan.walk(d.name, asObject(p).?);
            }
            for (listField(d.value, "events")) |ev| {
                for (listField(asObject(ev).?, "parameters")) |p| try plan.walk(d.name, asObject(p).?);
            }
        }
        try plan.choosePointers();
        return plan;
    }

    fn need(plan: *Plan, name: []const u8) error{ OutOfMemory, InvalidProtocol, UnknownType }!void {
        if (plan.needed.contains(name)) return;
        const def = plan.types.get(name) orelse {
            std.debug.print("devtools_protocol_gen: reference to unknown type {s}\n", .{name});
            return error.UnknownType;
        };
        try plan.needed.put(plan.a, name, {});
        const owner = splitQualified(name).domain;
        try plan.walk(owner, def);
        for (listField(def, "properties")) |p| try plan.walk(owner, asObject(p) orelse return error.InvalidProtocol);
    }

    /// Every type a property-like definition references.
    fn walk(plan: *Plan, context: []const u8, def: json.ObjectMap) error{ OutOfMemory, InvalidProtocol, UnknownType }!void {
        if (stringField(def, "$ref")) |ref| try plan.need(try qualify(plan.a, context, ref));
        if (def.get("items")) |items| try plan.walk(context, asObject(items) orelse return error.InvalidProtocol);
    }

    /// By-value references among object types (not through an array) form
    /// a graph; an edge inside a strongly connected component would make an
    /// infinitely large struct, so each such edge is a pointer.
    fn choosePointers(plan: *Plan) !void {
        const names = plan.needed.keys();
        const n = names.len;
        const index = try plan.a.alloc(i32, n);
        const low = try plan.a.alloc(i32, n);
        const on_stack = try plan.a.alloc(bool, n);
        const component = try plan.a.alloc(i32, n);
        @memset(index, -1);
        @memset(on_stack, false);
        var stack: std.ArrayList(usize) = .empty;
        var counter: i32 = 0;
        var components: i32 = 0;
        for (0..n) |v| {
            if (index[v] == -1) try plan.strongConnect(v, index, low, on_stack, component, &stack, &counter, &components);
        }
        for (names, 0..) |name, v| {
            for (try plan.valueEdges(name)) |target| {
                const w = plan.needed.getIndex(target).?;
                if (component[v] == component[w]) {
                    try plan.pointers.put(plan.a, try std.fmt.allocPrint(plan.a, "{s}->{s}", .{ name, target }), {});
                }
            }
        }
    }

    fn strongConnect(plan: *Plan, v: usize, index: []i32, low: []i32, on_stack: []bool, component: []i32, stack: *std.ArrayList(usize), counter: *i32, components: *i32) !void {
        index[v] = counter.*;
        low[v] = counter.*;
        counter.* += 1;
        try stack.append(plan.a, v);
        on_stack[v] = true;
        for (try plan.valueEdges(plan.needed.keys()[v])) |target| {
            const w = plan.needed.getIndex(target).?;
            if (index[w] == -1) {
                try plan.strongConnect(w, index, low, on_stack, component, stack, counter, components);
                low[v] = @min(low[v], low[w]);
            } else if (on_stack[w]) {
                low[v] = @min(low[v], index[w]);
            }
        }
        if (low[v] == index[v]) {
            while (true) {
                const w = stack.pop().?;
                on_stack[w] = false;
                component[w] = components.*;
                if (w == v) break;
            }
            components.* += 1;
        }
    }

    /// The types `name`'s properties hold by value.
    fn valueEdges(plan: *Plan, name: []const u8) ![]const []const u8 {
        const def = plan.types.get(name).?;
        const owner = splitQualified(name).domain;
        var out: std.ArrayList([]const u8) = .empty;
        for (listField(def, "properties")) |p| {
            const o = asObject(p).?;
            if (stringField(o, "$ref")) |ref| try out.append(plan.a, try qualify(plan.a, owner, ref));
        }
        return out.items;
    }

    fn isPointer(plan: *const Plan, from: []const u8, to: []const u8) !bool {
        const key = try std.fmt.allocPrint(plan.a, "{s}->{s}", .{ from, to });
        return plan.pointers.contains(key);
    }

    fn domainHasTypes(plan: *const Plan, name: []const u8) bool {
        for (plan.needed.keys()) |q| if (std.mem.eql(u8, splitQualified(q).domain, name)) return true;
        return false;
    }
};

/// One generated file: its name in the tree and its zig fmt-clean text.
pub const File = struct {
    name: []const u8,
    text: []const u8,
};

/// Generate the whole tree. Everything is allocated from `a` (an arena).
pub fn generate(a: Allocator, spec: *const Spec, full: []const []const u8) ![]File {
    var plan = try Plan.init(a, spec, full);
    var files: std.ArrayList(File) = .empty;
    var written_domains: std.ArrayList([]const u8) = .empty;
    for (spec.domains) |d| {
        const whole = plan.isFull(d.name);
        if (!whole and !plan.domainHasTypes(d.name)) continue;
        try written_domains.append(a, d.name);
        const raw = try emitDomain(a, &plan, &d, whole);
        try files.append(a, .{ .name = try std.fmt.allocPrint(a, "{s}.zig", .{d.name}), .text = try formatSource(a, raw) });
    }
    const root = try emitRoot(a, spec, written_domains.items);
    try files.append(a, .{ .name = "root.zig", .text = try formatSource(a, root) });
    return files.toOwnedSlice(a);
}

fn formatSource(a: Allocator, source: []const u8) ![]const u8 {
    const z = try a.dupeSentinel(u8, source, 0);
    var tree = try std.zig.Ast.parse(a, z, .{ .mode = .zig });
    if (tree.errors.len != 0) {
        std.debug.print("devtools_protocol_gen: generated Zig does not parse:\n{s}\n", .{source[0..@min(source.len, 4000)]});
        return error.InvalidGeneratedZig;
    }
    return tree.renderAlloc(a);
}

const header =
    \\//! GENERATED by tools/devtools_protocol_gen.zig from specs/devtools-protocol/
    \\//! (Chrome DevTools Protocol definitions, BSD-3-Clause, Copyright 2014 The
    \\//! Chromium Authors: specs/devtools-protocol/LICENSE). Never edit by hand:
    \\//! regenerate with `zig build codegen -- --dest-root src/webidl/`;
    \\//! `zig build codegen-check` compares this tree with a regeneration.
    \\
;

fn writeDoc(w: *std.Io.Writer, description: ?[]const u8, experimental: bool, deprecated: bool) !void {
    if (description) |text| {
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trimEnd(u8, line, " \t\r");
            if (trimmed.len == 0) try w.writeAll("///\n") else try w.print("/// {s}\n", .{trimmed});
        }
    }
    if (experimental) try w.writeAll("/// Experimental.\n");
    if (deprecated) try w.writeAll("/// Deprecated.\n");
}

fn checkReserved(domain_name: []const u8, name: []const u8, reserved: []const []const u8) !void {
    for (reserved) |r| if (std.mem.eql(u8, r, name)) {
        std.debug.print("devtools_protocol_gen: {s}.{s} clashes with a generated declaration; rename it in the generator\n", .{ domain_name, name });
        return error.NameClash;
    };
}

fn emitDomain(a: Allocator, plan: *const Plan, d: *const Domain, full: bool) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.writeAll(header);
    try w.writeAll("//!\n");
    if (full) {
        try w.print("//! The {s} domain", .{d.name});
    } else {
        try w.print("//! The types of the {s} domain that the generated domains use", .{d.name});
    }
    try w.print(" ({s}.json).\n", .{@tagName(d.origin)});
    if (stringField(d.value, "description")) |desc| {
        try w.writeAll("//!\n");
        var lines = std.mem.splitScalar(u8, desc, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trimEnd(u8, line, " \t\r");
            if (trimmed.len == 0) try w.writeAll("//!\n") else try w.print("//! {s}\n", .{trimmed});
        }
    }
    try w.writeAll("\nconst std = @import(\"std\");\nconst protocol = @import(\"root.zig\");\n\n");
    try w.print("pub const domain = \"{s}\";\n\n", .{d.name});

    // Types.
    for (listField(d.value, "types")) |t| {
        const o = asObject(t).?;
        const id = stringField(o, "id").?;
        const qualified = try qualify(a, d.name, id);
        if (!plan.needed.contains(qualified)) continue;
        try checkReserved(d.name, id, &reserved_file_decls);
        try checkReserved(d.name, id, &reserved_member_decls);
        try writeDoc(w, stringField(o, "description"), boolField(o, "experimental"), boolField(o, "deprecated"));
        try w.print("pub const {f} = ", .{std.zig.fmtId(id)});
        const kind = stringField(o, "type") orelse "any";
        if (std.mem.eql(u8, kind, "object") and o.get("properties") != null) {
            try w.writeAll("struct {\n");
            try emitFields(a, w, plan, d.name, qualified, listField(o, "properties"));
            try w.writeAll("};\n\n");
        } else {
            try emitTypeExpr(a, w, plan, d.name, null, o);
            try w.writeAll(";\n\n");
        }
    }
    if (!full) return out.toOwnedSlice();

    // Commands.
    const commands = listField(d.value, "commands");
    try w.writeAll("/// Every command of the domain, by name.\npub const CommandName = enum {\n");
    for (commands) |cmd| try w.print("    {f},\n", .{std.zig.fmtId(stringField(asObject(cmd).?, "name").?)});
    try w.writeAll("};\n\n");
    const events = listField(d.value, "events");
    try w.writeAll("/// Every event of the domain, by name.\npub const EventName = enum {\n");
    for (events) |ev| try w.print("    {f},\n", .{std.zig.fmtId(stringField(asObject(ev).?, "name").?)});
    try w.writeAll("};\n\n");

    for (commands) |cmd| {
        const o = asObject(cmd).?;
        const name = stringField(o, "name").?;
        try checkReserved(d.name, name, &reserved_file_decls);
        try writeDoc(w, stringField(o, "description"), boolField(o, "experimental"), boolField(o, "deprecated"));
        try w.print("pub const {f} = struct {{\n", .{std.zig.fmtId(name)});
        try w.print("    pub const method = \"{s}.{s}\";\n", .{ d.name, name });
        try w.writeAll("    pub const Params = struct {\n");
        try emitFields(a, w, plan, d.name, null, listField(o, "parameters"));
        try w.writeAll("    };\n    pub const Result = struct {\n");
        try emitFields(a, w, plan, d.name, null, listField(o, "returns"));
        try w.writeAll("    };\n};\n\n");
    }
    for (events) |ev| {
        const o = asObject(ev).?;
        const name = stringField(o, "name").?;
        try checkReserved(d.name, name, &reserved_file_decls);
        try writeDoc(w, stringField(o, "description"), boolField(o, "experimental"), boolField(o, "deprecated"));
        try w.print("pub const {f} = struct {{\n", .{std.zig.fmtId(name)});
        try w.print("    pub const method = \"{s}.{s}\";\n", .{ d.name, name });
        try w.writeAll("    pub const Params = struct {\n");
        try emitFields(a, w, plan, d.name, null, listField(o, "parameters"));
        try w.writeAll("    };\n};\n\n");
    }
    return out.toOwnedSlice();
}

/// The fields of a struct: one per property; optional ones default to null.
/// `owner` is the qualified name of the type whose fields these are (for the
/// pointer decision), null for a command's or event's parameters.
fn emitFields(a: Allocator, w: *std.Io.Writer, plan: *const Plan, context: []const u8, owner: ?[]const u8, properties: []json.Value) !void {
    for (properties) |p| {
        const o = asObject(p).?;
        const name = stringField(o, "name") orelse return error.InvalidProtocol;
        try writeDoc(w, stringField(o, "description"), boolField(o, "experimental"), boolField(o, "deprecated"));
        const optional = boolField(o, "optional");
        try w.print("{f}: ", .{std.zig.fmtIdFlags(name, .{ .allow_primitive = true })});
        if (optional) try w.writeAll("?");
        try emitTypeExpr(a, w, plan, context, owner, o);
        if (optional) try w.writeAll(" = null");
        try w.writeAll(",\n");
    }
}

fn emitTypeExpr(a: Allocator, w: *std.Io.Writer, plan: *const Plan, context: []const u8, owner: ?[]const u8, def: json.ObjectMap) !void {
    if (stringField(def, "$ref")) |ref| {
        const target = try qualify(a, context, ref);
        const parts = splitQualified(target);
        if (owner) |from| {
            if (try plan.isPointer(from, target)) try w.writeAll("*const ");
        }
        if (std.mem.eql(u8, parts.domain, context)) {
            try w.print("{f}", .{std.zig.fmtId(parts.type_name)});
        } else {
            try w.print("protocol.{f}.{f}", .{ std.zig.fmtId(parts.domain), std.zig.fmtId(parts.type_name) });
        }
        return;
    }
    const kind = stringField(def, "type") orelse "any";
    if (std.mem.eql(u8, kind, "string")) {
        const values = listField(def, "enum");
        if (values.len == 0) return w.writeAll("[]const u8");
        try w.writeAll("enum {\n");
        for (values) |v| {
            const text = switch (v) {
                .string => |s| s,
                else => return error.InvalidProtocol,
            };
            try w.print("{f},\n", .{std.zig.fmtId(text)});
        }
        return w.writeAll("}");
    }
    if (std.mem.eql(u8, kind, "integer")) return w.writeAll("i64");
    if (std.mem.eql(u8, kind, "number")) return w.writeAll("f64");
    if (std.mem.eql(u8, kind, "boolean")) return w.writeAll("bool");
    if (std.mem.eql(u8, kind, "any") or std.mem.eql(u8, kind, "object")) return w.writeAll("std.json.Value");
    if (std.mem.eql(u8, kind, "array")) {
        const items = asObject(def.get("items") orelse return error.InvalidProtocol) orelse return error.InvalidProtocol;
        try w.writeAll("[]const ");
        // An array holds its items through a slice: never a pointer edge.
        return emitTypeExpr(a, w, plan, context, null, items);
    }
    std.debug.print("devtools_protocol_gen: unknown type kind '{s}' in {s}\n", .{ kind, context });
    return error.InvalidProtocol;
}

const MethodEntry = struct { name: []const u8, domain: []const u8 };

fn emitRoot(a: Allocator, spec: *const Spec, written: []const []const u8) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.writeAll(header);
    try w.writeAll(
        \\//!
        \\//! The protocol's domains (`protocol.Page`, ...), every domain of both files
        \\//! (`Domain`), and the method table: every command's name and domain,
        \\//! sorted, for the router to tell a method of V8's inspector from an unknown
        \\//! one (`findMethod`).
        \\
        \\const std = @import("std");
        \\
        \\
    );
    try w.print("/// The protocol version both files declare (Browser.getVersion's protocolVersion).\npub const protocol_version = \"{s}.{s}\";\n", .{ spec.version_major, spec.version_minor });
    try w.print("/// The devtools-protocol package the definitions are pinned at (specs/devtools-protocol/PIN.md).\npub const package_version = \"{s}\";\n\n", .{spec.package_version});
    for (written) |name| try w.print("pub const {f} = @import(\"{s}.zig\");\n", .{ std.zig.fmtId(name), name });
    try w.writeAll("\n/// Which file defines a domain: V8's inspector implements js_protocol's.\npub const Origin = enum { browser_protocol, js_protocol };\n\n");
    try w.writeAll("/// Every domain of both files.\npub const Domain = enum {\n");
    for (spec.domains) |d| try w.print("    {f},\n", .{std.zig.fmtId(d.name)});
    try w.writeAll("\n    pub fn origin(self: Domain) Origin {\n        return switch (self) {\n");
    var js_count: usize = 0;
    for (spec.domains) |d| if (d.origin == .js_protocol) {
        try w.print("            .{f},\n", .{std.zig.fmtId(d.name)});
        js_count += 1;
    };
    if (js_count > 0) try w.writeAll("            => .js_protocol,\n");
    try w.writeAll("            else => .browser_protocol,\n        };\n    }\n};\n\n");

    var methods: std.ArrayList(MethodEntry) = .empty;
    for (spec.domains) |d| {
        for (listField(d.value, "commands")) |cmd| {
            try methods.append(a, .{ .name = try std.fmt.allocPrint(a, "{s}.{s}", .{ d.name, stringField(asObject(cmd).?, "name").? }), .domain = d.name });
        }
    }
    std.mem.sort(MethodEntry, methods.items, {}, struct {
        fn lessThan(_: void, x: MethodEntry, y: MethodEntry) bool {
            return std.mem.lessThan(u8, x.name, y.name);
        }
    }.lessThan);
    try w.writeAll(
        \\/// A command of the protocol: its name ("Domain.command") and domain.
        \\pub const Method = struct {
        \\    name: []const u8,
        \\    domain: Domain,
        \\};
        \\
        \\/// Every command of both files, sorted by name.
        \\pub const methods = [_]Method{
        \\
    );
    for (methods.items) |m| try w.print("    .{{ .name = \"{s}\", .domain = .{f} }},\n", .{ m.name, std.zig.fmtId(m.domain) });
    try w.writeAll(
        \\};
        \\
        \\/// The command named `name`, if the protocol has one.
        \\pub fn findMethod(name: []const u8) ?Method {
        \\    var low: usize = 0;
        \\    var high: usize = methods.len;
        \\    while (low < high) {
        \\        const mid = low + (high - low) / 2;
        \\        switch (std.mem.order(u8, methods[mid].name, name)) {
        \\            .eq => return methods[mid],
        \\            .lt => low = mid + 1,
        \\            .gt => high = mid,
        \\        }
        \\    }
        \\    return null;
        \\}
        \\
    );
    return out.toOwnedSlice();
}

// ============================================================================
// The command line
// ============================================================================

/// The package version PIN.md records: its "- Version: `<v>`" line.
pub fn pinnedVersion(pin_text: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, pin_text, '\n');
    while (lines.next()) |line| {
        const prefix = "- Version: `";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const rest = line[prefix.len..];
        const end = std.mem.indexOfScalar(u8, rest, '`') orelse return null;
        return rest[0..end];
    }
    return null;
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next();
    var spec_dir: []const u8 = "specs/devtools-protocol";
    var dest: ?[]const u8 = null;
    var check = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--check")) {
            check = true;
        } else if (std.mem.eql(u8, arg, "--spec-dir")) {
            spec_dir = args.next() orelse return usage();
        } else if (std.mem.eql(u8, arg, "--dest")) {
            dest = args.next() orelse return usage();
        } else return usage();
    }
    const dest_dir = dest orelse return usage();

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const cwd = std.Io.Dir.cwd();
    const limit: std.Io.Limit = .limited(64 * 1024 * 1024);
    const browser_text = try cwd.readFileAlloc(io, try std.fs.path.join(a, &.{ spec_dir, "browser_protocol.json" }), a, limit);
    const js_text = try cwd.readFileAlloc(io, try std.fs.path.join(a, &.{ spec_dir, "js_protocol.json" }), a, limit);
    const pin_text = try cwd.readFileAlloc(io, try std.fs.path.join(a, &.{ spec_dir, "PIN.md" }), a, limit);
    const version = pinnedVersion(pin_text) orelse {
        std.debug.print("devtools_protocol_gen: {s}/PIN.md has no \"- Version: `...`\" line\n", .{spec_dir});
        return error.NoPinnedVersion;
    };

    var spec = try parseSpec(gpa, browser_text, js_text, version);
    defer spec.deinit();
    const files = try generate(a, &spec, &full_domains);

    if (check) {
        var differences: usize = 0;
        for (files) |file| {
            const path = try std.fs.path.join(a, &.{ dest_dir, file.name });
            const committed = cwd.readFileAlloc(io, path, a, limit) catch |err| switch (err) {
                error.FileNotFound => {
                    std.debug.print("  {s} is generated but not committed\n", .{path});
                    differences += 1;
                    continue;
                },
                else => return err,
            };
            if (!std.mem.eql(u8, committed, file.text)) {
                std.debug.print("  {s} differs from the generator's output\n", .{path});
                differences += 1;
            }
        }
        // A committed file the generator no longer writes.
        var maybe_dir: ?std.Io.Dir = cwd.openDir(io, dest_dir, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => null,
            else => return err,
        };
        if (maybe_dir) |*opened| {
            defer opened.close(io);
            var it = opened.iterate();
            while (try it.next(io)) |entry| {
                if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
                for (files) |file| {
                    if (std.mem.eql(u8, file.name, entry.name)) break;
                } else {
                    std.debug.print("  {s}/{s} is committed but the generator no longer writes it\n", .{ dest_dir, entry.name });
                    differences += 1;
                }
            }
        }
        if (differences != 0) {
            std.debug.print(
                \\devtools_protocol_gen --check: {d} file(s) of {s} do not match a regeneration.
                \\Generated files are never edited by hand: change tools/devtools_protocol_gen.zig or the
                \\pinned definitions, then regenerate: zig build codegen -- --dest-root src/webidl/
                \\
            , .{ differences, dest_dir });
            std.process.exit(1);
        }
        std.debug.print("devtools_protocol_gen --check: {s} matches a regeneration ({d} files)\n", .{ dest_dir, files.len });
        return;
    }

    try cwd.createDirPath(io, dest_dir);
    var dir = try cwd.openDir(io, dest_dir, .{ .iterate = true });
    defer dir.close(io);
    // Remove what the generator no longer writes, so the tree is exactly its output.
    var stale: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
        for (files) |file| {
            if (std.mem.eql(u8, file.name, entry.name)) break;
        } else try stale.append(a, try a.dupe(u8, entry.name));
    }
    for (stale.items) |name| try dir.deleteFile(io, name);
    for (files) |file| try dir.writeFile(io, .{ .sub_path = file.name, .data = file.text });
    std.debug.print("devtools_protocol_gen: wrote {d} files to {s}\n", .{ files.len, dest_dir });
}

fn usage() error{Usage} {
    std.debug.print("usage: devtools_protocol_gen [--spec-dir <dir>] --dest <dir> [--check]\n", .{});
    return error.Usage;
}

// ============================================================================
// Tests
// ============================================================================

const test_browser =
    \\{"version": {"major": "1", "minor": "3"}, "domains": [
    \\ {"domain": "Page", "description": "Page things.", "types": [
    \\   {"id": "FrameId", "type": "string"},
    \\   {"id": "Frame", "type": "object", "properties": [
    \\     {"name": "id", "$ref": "FrameId"},
    \\     {"name": "parent", "optional": true, "$ref": "Frame"},
    \\     {"name": "children", "optional": true, "type": "array", "items": {"$ref": "Frame"}},
    \\     {"name": "type", "type": "string", "enum": ["main", "sub-frame"]}
    \\   ]},
    \\   {"id": "Headers", "type": "object"}
    \\ ], "commands": [
    \\   {"name": "navigate", "parameters": [{"name": "url", "type": "string"}, {"name": "loader", "optional": true, "$ref": "Net.LoaderId"}],
    \\    "returns": [{"name": "frameId", "$ref": "FrameId"}]},
    \\   {"name": "resume"}
    \\ ], "events": [
    \\   {"name": "frameNavigated", "parameters": [{"name": "frame", "$ref": "Frame"}]}
    \\ ]},
    \\ {"domain": "Net", "types": [
    \\   {"id": "LoaderId", "type": "string"},
    \\   {"id": "Unused", "type": "integer"}
    \\ ], "commands": [{"name": "enable"}]}
    \\]}
;
const test_js =
    \\{"version": {"major": "1", "minor": "3"}, "domains": [
    \\ {"domain": "Runtime", "types": [{"id": "ExecutionContextId", "type": "integer"}], "commands": [{"name": "evaluate"}]}
    \\]}
;

test "a domain's types, commands and events; a self-containing type is a pointer; keywords are escaped" {
    var spec = try parseSpec(std.testing.allocator, test_browser, test_js, "0.0.1");
    defer spec.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var plan = try Plan.init(arena.allocator(), &spec, &.{"Page"});
    // Frame.parent is Frame by value: a pointer. Its children are a slice.
    try std.testing.expect(try plan.isPointer("Page.Frame", "Page.Frame"));
    try std.testing.expect(!try plan.isPointer("Page.Frame", "Page.FrameId"));
    // Net is not generated whole: only the type Page uses.
    try std.testing.expect(plan.needed.contains("Net.LoaderId"));
    try std.testing.expect(!plan.needed.contains("Net.Unused"));
}

test "generate writes one file per domain it needs and root.zig" {
    var spec = try parseSpec(std.testing.allocator, test_browser, test_js, "0.0.1");
    defer spec.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const files = try generate(arena.allocator(), &spec, &.{"Page"});
    // Page whole, Net for LoaderId, root; Runtime is referenced by nothing.
    try std.testing.expectEqual(@as(usize, 3), files.len);
    try std.testing.expectEqualStrings("Page.zig", files[0].name);
    try std.testing.expectEqualStrings("Net.zig", files[1].name);
    try std.testing.expectEqualStrings("root.zig", files[2].name);
    try std.testing.expect(std.mem.indexOf(u8, files[1].text, "Unused") == null);
}

test "emitDomain and emitRoot write zig fmt-clean files with the expected declarations" {
    var spec = try parseSpec(std.testing.allocator, test_browser, test_js, "0.0.1");
    defer spec.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var plan: Plan = .{ .a = a, .spec = &spec, .full = &.{"Page"} };
    for (spec.domains) |d| for (listField(d.value, "types")) |t| {
        const o = asObject(t).?;
        try plan.types.put(a, try qualify(a, d.name, stringField(o, "id").?), o);
    };
    for ([_][]const u8{ "Page.FrameId", "Page.Frame", "Page.Headers", "Net.LoaderId" }) |n| try plan.need(n);
    try plan.choosePointers();
    const page = try formatSource(a, try emitDomain(a, &plan, &spec.domains[0], true));
    try std.testing.expect(std.mem.indexOf(u8, page, "pub const FrameId = []const u8;") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "parent: ?*const Frame = null,") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "children: ?[]const Frame = null,") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "@\"sub-frame\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "pub const Headers = std.json.Value;") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "pub const method = \"Page.navigate\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "loader: ?protocol.Net.LoaderId = null,") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "pub const @\"resume\" = struct {") != null);
    try std.testing.expect(std.mem.indexOf(u8, page, "pub const frameNavigated = struct {") != null);
    // What the formatter makes of it is a fixed point.
    try std.testing.expectEqualStrings(page, try formatSource(a, page));

    const root = try formatSource(a, try emitRoot(a, &spec, &.{ "Page", "Net" }));
    try std.testing.expect(std.mem.indexOf(u8, root, "pub const package_version = \"0.0.1\";") != null);
    // Sorted method table across both files.
    const navigate = std.mem.indexOf(u8, root, "\"Page.navigate\"").?;
    const evaluate = std.mem.indexOf(u8, root, "\"Runtime.evaluate\"").?;
    const enable = std.mem.indexOf(u8, root, "\"Net.enable\"").?;
    try std.testing.expect(enable < navigate and navigate < evaluate);
    try std.testing.expect(std.mem.indexOf(u8, root, ".Runtime,\n            => .js_protocol,") != null);
}

test "a protocol name equal to a generated declaration stops the generator" {
    try std.testing.expectError(error.NameClash, checkReserved("Page", "Params", &reserved_member_decls));
    try checkReserved("Page", "Frame", &reserved_member_decls);
}

test "pinnedVersion reads PIN.md's version line" {
    try std.testing.expectEqualStrings("0.0.1717327", pinnedVersion("# x\n\n- Version: `0.0.1717327` (published ...)\n").?);
    try std.testing.expect(pinnedVersion("nothing here") == null);
}
