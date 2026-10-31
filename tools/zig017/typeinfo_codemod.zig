//! zig017trial codemod (a Zig 0.16 program; scratch branch only): Zig 0.17's @typeInfo is
//! struct-of-arrays. Rewrites the loops and lengths whose kind the text names:
//!
//!   for (X.@"struct".fields) |f| ... f.name ... f.type     (struct, union)
//!     -> for (X.@"struct".field_names, X.@"struct".field_types) |f_name, f_type| ... f_name ... f_type
//!   for (X.@"enum".fields) |f| ... f.name ... f.value
//!     -> for (X.@"enum".field_names, X.@"enum".field_values) |f_name, f_value|
//!   for (X.@"struct".decls) |d| ... d.name          -> for (X.@"struct".decl_names) |d_name| ... d_name
//!   for (X.@"fn".params) |p| ... p.type             -> for (X.@"fn".param_types) |p_type| ... p_type
//!   X.fields.len / X.decls.len / X.params.len        -> X.field_names.len / X.decl_names.len / X.param_types.len
//!   X.fields[i].name / .type / .value                -> X.field_names[i] / X.field_types[i] / X.field_values[i]
//!
//! A loop whose capture is used any other way (passed whole, `.default_value_ptr`, `.is_noalias`...)
//! or whose kind the text does not name is listed MANUAL. Overlapping rewrites are done one per pass:
//! run it until it reports `rewritten=0`.
//!
//! Usage: typeinfo_codemod [--dry-run] <file.zig>...
const std = @import("std");
const Ast = std.zig.Ast;

const Edit = struct { start: usize, end: usize, text: []const u8 };
const Kind = enum { @"struct", @"union", @"enum", decls, params };

fn tokenEnd(tree: *const Ast, token: Ast.TokenIndex) usize {
    return tree.tokenStart(token) + tree.tokenSlice(token).len;
}

fn nodeSpan(tree: *const Ast, node: Ast.Node.Index) [2]usize {
    return .{ tree.tokenStart(tree.firstToken(node)), tokenEnd(tree, tree.lastToken(node)) };
}

fn nodeText(tree: *const Ast, node: Ast.Node.Index) []const u8 {
    const s = nodeSpan(tree, node);
    return tree.source[s[0]..s[1]];
}

/// The reflection kind of `<lhs>.fields` / `.decls` / `.params` from the text of lhs.
fn kindOf(lhs_text: []const u8, member: []const u8) ?Kind {
    if (std.mem.eql(u8, member, "decls")) return .decls;
    if (std.mem.eql(u8, member, "params")) return if (std.mem.endsWith(u8, lhs_text, ".@\"fn\"")) .params else null;
    if (!std.mem.eql(u8, member, "fields")) return null;
    if (std.mem.endsWith(u8, lhs_text, ".@\"struct\"")) return .@"struct";
    if (std.mem.endsWith(u8, lhs_text, ".@\"union\"")) return .@"union";
    if (std.mem.endsWith(u8, lhs_text, ".@\"enum\"")) return .@"enum";
    return null;
}

const Pass = struct {
    arena: std.mem.Allocator,
    tree: *const Ast,
    source: []const u8,
    edits: std.ArrayList(Edit) = .empty,
    manual: std.ArrayList([]const u8) = .empty,
    path: []const u8,

    fn overlaps(p: *const Pass, start: usize, end: usize) bool {
        for (p.edits.items) |e| if (start < e.end and e.start < end) return true;
        return false;
    }

    fn line(p: *const Pass, offset: usize) usize {
        return std.mem.count(u8, p.source[0..offset], "\n") + 1;
    }

    fn note(p: *Pass, offset: usize, why: []const u8) !void {
        try p.manual.append(p.arena, try std.fmt.allocPrint(p.arena, "MANUAL {s}:{d}: {s}", .{ p.path, p.line(offset), why }));
    }
};

/// `X.fields` / `.decls` / `.params` as a field_access node: (lhs, member token) or null.
fn reflectionAccess(tree: *const Ast, node: Ast.Node.Index) ?struct { lhs: Ast.Node.Index, member: Ast.TokenIndex } {
    if (tree.nodeTag(node) != .field_access) return null;
    const lhs, const member = tree.nodeData(node).node_and_token;
    const name = tree.tokenSlice(member);
    if (!std.mem.eql(u8, name, "fields") and !std.mem.eql(u8, name, "decls") and !std.mem.eql(u8, name, "params")) return null;
    return .{ .lhs = lhs, .member = member };
}

/// `std.meta.fields(X)` (a @compileError in 0.17): the argument X, or null.
fn metaFieldsArg(tree: *const Ast, node: Ast.Node.Index) ?Ast.Node.Index {
    var buf: [1]Ast.Node.Index = undefined;
    const call = tree.fullCall(&buf, node) orelse return null;
    if (call.ast.params.len != 1) return null;
    if (!std.mem.eql(u8, nodeText(tree, call.ast.fn_expr), "std.meta.fields")) return null;
    return call.ast.params[0];
}

/// `for (std.meta.fields(X)) |f|`: by what the body reads, names (`std.meta.fieldNames(X)`), types
/// (`std.meta.fieldTypes(X)`) or enum values (`@typeInfo(X).@"enum".field_values`).
fn rewriteMetaFor(p: *Pass, node: Ast.Node.Index) !bool {
    const tree = p.tree;
    const full = tree.fullFor(node) orelse return false;
    if (full.ast.inputs.len != 1) return false;
    const arg = metaFieldsArg(tree, full.ast.inputs[0]) orelse return false;
    const x = nodeText(tree, arg);
    var cap = full.payload_token;
    if (tree.tokenTag(cap) == .asterisk) cap += 1;
    const cap_name = tree.tokenSlice(cap);
    var uses_name = false;
    var uses_type = false;
    var uses_value = false;
    var body_edits: std.ArrayList(Edit) = .empty;
    const last = tree.lastToken(node);
    var t = tree.firstToken(full.ast.then_expr);
    while (t <= last) : (t += 1) {
        if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), cap_name)) continue;
        if (t > 0 and tree.tokenTag(t - 1) == .period) continue;
        if (!(t + 2 <= last and tree.tokenTag(t + 1) == .period and tree.tokenTag(t + 2) == .identifier)) {
            try p.note(tree.tokenStart(t), try std.fmt.allocPrint(p.arena, "std.meta.fields capture `{s}` used whole", .{cap_name}));
            return true;
        }
        const m = tree.tokenSlice(t + 2);
        if (std.mem.eql(u8, m, "name")) uses_name = true else if (std.mem.eql(u8, m, "type")) uses_type = true else if (std.mem.eql(u8, m, "value")) uses_value = true else {
            try p.note(tree.tokenStart(t), try std.fmt.allocPrint(p.arena, "std.meta.fields member `{s}.{s}`", .{ cap_name, m }));
            return true;
        }
        try body_edits.append(p.arena, .{ .start = tree.tokenStart(t), .end = tokenEnd(tree, t + 2), .text = try std.fmt.allocPrint(p.arena, "{s}_{s}", .{ cap_name, m }) });
    }
    if (uses_type and uses_value) return true;
    var inputs: std.ArrayList(u8) = .empty;
    var captures: std.ArrayList(u8) = .empty;
    if (uses_name or (!uses_type and !uses_value)) {
        try inputs.print(p.arena, "std.meta.fieldNames({s})", .{x});
        try captures.print(p.arena, "{s}_name", .{cap_name});
    }
    if (uses_type) {
        try inputs.print(p.arena, "{s}std.meta.fieldTypes({s})", .{ if (inputs.items.len > 0) ", " else "", x });
        try captures.print(p.arena, "{s}{s}_type", .{ if (captures.items.len > 0) ", " else "", cap_name });
    }
    if (uses_value) {
        try inputs.print(p.arena, "{s}@typeInfo({s}).@\"enum\".field_values", .{ if (inputs.items.len > 0) ", " else "", x });
        try captures.print(p.arena, "{s}{s}_value", .{ if (captures.items.len > 0) ", " else "", cap_name });
    }
    const in_span = nodeSpan(tree, full.ast.inputs[0]);
    var local: std.ArrayList(Edit) = .empty;
    try local.append(p.arena, .{ .start = in_span[0], .end = in_span[1], .text = inputs.items });
    try local.append(p.arena, .{ .start = tree.tokenStart(cap), .end = tokenEnd(tree, cap), .text = if (std.mem.eql(u8, cap_name, "_")) "_" else captures.items });
    try local.appendSlice(p.arena, body_edits.items);
    for (local.items) |e| if (p.overlaps(e.start, e.end)) return true;
    try p.edits.appendSlice(p.arena, local.items);
    return true;
}

fn rewriteFor(p: *Pass, node: Ast.Node.Index) !void {
    if (try rewriteMetaFor(p, node)) return;
    const tree = p.tree;
    const full = tree.fullFor(node) orelse return;
    const span = nodeSpan(tree, node);
    // Inputs that are reflection arrays, and their captures.
    var any = false;
    for (full.ast.inputs) |input| if (reflectionAccess(tree, input) != null) {
        any = true;
    };
    if (!any) return;
    var local: std.ArrayList(Edit) = .empty;
    // Capture tokens: payload_token is the first capture name (after `|`, maybe `*`).
    var capture_token = full.payload_token;
    for (full.ast.inputs, 0..) |input, i| {
        if (tree.tokenTag(capture_token) == .asterisk) capture_token += 1;
        const cap = capture_token;
        const cap_name = tree.tokenSlice(cap);
        // next capture: skip `,` after this one
        defer {
            if (i + 1 < full.ast.inputs.len) capture_token = cap + 2;
        }
        const access = reflectionAccess(tree, input) orelse continue;
        const lhs_text = nodeText(tree, access.lhs);
        const member = tree.tokenSlice(access.member);
        const kind = kindOf(lhs_text, member) orelse {
            try p.note(span[0], try std.fmt.allocPrint(p.arena, "kind unknown: {s}", .{nodeText(tree, input)}));
            return;
        };
        if (tree.tokenTag(cap) != .identifier) return;
        const is_discard = std.mem.eql(u8, cap_name, "_");
        // Which members of the capture the body uses.
        var uses_name = false;
        var uses_second = false;
        var body_edits: std.ArrayList(Edit) = .empty;
        const second: []const u8 = switch (kind) {
            .@"struct", .@"union" => "type",
            .@"enum" => "value",
            .decls, .params => if (kind == .params) "type" else "",
        };
        if (!is_discard) {
            const body_first = tree.firstToken(full.ast.then_expr);
            const last = tree.lastToken(node);
            var t = body_first;
            while (t <= last) : (t += 1) {
                if (tree.tokenTag(t) != .identifier or !std.mem.eql(u8, tree.tokenSlice(t), cap_name)) continue;
                if (t > 0 and tree.tokenTag(t - 1) == .period) continue; // a field named like the capture
                const ok_member = t + 2 <= last and tree.tokenTag(t + 1) == .period and tree.tokenTag(t + 2) == .identifier;
                if (!ok_member) {
                    try p.note(tree.tokenStart(t), try std.fmt.allocPrint(p.arena, "capture `{s}` used whole", .{cap_name}));
                    return;
                }
                const m = tree.tokenSlice(t + 2);
                const replacement: []const u8 = if (std.mem.eql(u8, m, "name") and kind != .params) blk: {
                    uses_name = true;
                    break :blk try std.fmt.allocPrint(p.arena, "{s}_name", .{cap_name});
                } else if (second.len > 0 and std.mem.eql(u8, m, second)) blk: {
                    uses_second = true;
                    break :blk try std.fmt.allocPrint(p.arena, "{s}_{s}", .{ cap_name, second });
                } else {
                    try p.note(tree.tokenStart(t), try std.fmt.allocPrint(p.arena, "capture member `{s}.{s}`", .{ cap_name, m }));
                    return;
                };
                try body_edits.append(p.arena, .{ .start = tree.tokenStart(t), .end = tokenEnd(tree, t + 2), .text = replacement });
            }
        }
        // The new inputs and captures.
        const in_span = nodeSpan(tree, input);
        var new_input: []const u8 = undefined;
        var new_capture: []const u8 = undefined;
        switch (kind) {
            .@"struct", .@"union", .@"enum" => {
                const second_array = if (kind == .@"enum") "field_values" else "field_types";
                if (uses_second and uses_name) {
                    new_input = try std.fmt.allocPrint(p.arena, "{s}.field_names, {s}.{s}", .{ lhs_text, lhs_text, second_array });
                    new_capture = try std.fmt.allocPrint(p.arena, "{s}_name, {s}_{s}", .{ cap_name, cap_name, second });
                } else if (uses_second) {
                    new_input = try std.fmt.allocPrint(p.arena, "{s}.{s}", .{ lhs_text, second_array });
                    new_capture = try std.fmt.allocPrint(p.arena, "{s}_{s}", .{ cap_name, second });
                } else {
                    new_input = try std.fmt.allocPrint(p.arena, "{s}.field_names", .{lhs_text});
                    new_capture = if (is_discard) "_" else try std.fmt.allocPrint(p.arena, "{s}_name", .{cap_name});
                }
            },
            .decls => {
                new_input = try std.fmt.allocPrint(p.arena, "{s}.decl_names", .{lhs_text});
                new_capture = if (is_discard) "_" else try std.fmt.allocPrint(p.arena, "{s}_name", .{cap_name});
            },
            .params => {
                new_input = try std.fmt.allocPrint(p.arena, "{s}.param_types", .{lhs_text});
                new_capture = if (is_discard) "_" else try std.fmt.allocPrint(p.arena, "{s}_type", .{cap_name});
            },
        }
        try local.append(p.arena, .{ .start = in_span[0], .end = in_span[1], .text = new_input });
        try local.append(p.arena, .{ .start = tree.tokenStart(cap), .end = tokenEnd(tree, cap), .text = new_capture });
        try local.appendSlice(p.arena, body_edits.items);
    }
    for (local.items) |e| if (p.overlaps(e.start, e.end)) return; // next pass
    try p.edits.appendSlice(p.arena, local.items);
}

/// `X.fields.len` and `X.fields[i].member`.
fn rewriteAccess(p: *Pass, node: Ast.Node.Index) !void {
    const tree = p.tree;
    if (metaFieldsArg(tree, node)) |arg| {
        const last_tok = tree.lastToken(node);
        const span = nodeSpan(tree, node);
        if (tree.tokenTag(last_tok + 1) == .period and std.mem.eql(u8, tree.tokenSlice(last_tok + 2), "len")) {
            if (p.overlaps(span[0], span[1])) return;
            try p.edits.append(p.arena, .{ .start = span[0], .end = span[1], .text = try std.fmt.allocPrint(p.arena, "std.meta.fieldNames({s})", .{nodeText(tree, arg)}) });
        }
        return;
    }
    const access = reflectionAccess(tree, node) orelse return;
    const lhs_text = nodeText(tree, access.lhs);
    const member = tree.tokenSlice(access.member);
    const kind = kindOf(lhs_text, member) orelse return;
    const last = tree.lastToken(node);
    const names = switch (kind) {
        .decls => "decl_names",
        .params => "param_types",
        else => "field_names",
    };
    // .len
    if (tree.tokenTag(last + 1) == .period and std.mem.eql(u8, tree.tokenSlice(last + 2), "len")) {
        const s = tree.tokenStart(access.member);
        if (p.overlaps(s, tokenEnd(tree, access.member))) return;
        try p.edits.append(p.arena, .{ .start = s, .end = tokenEnd(tree, access.member), .text = names });
        return;
    }
    // [i].member
    if (tree.tokenTag(last + 1) == .l_bracket) {
        var t = last + 2;
        var depth: usize = 1;
        while (depth > 0) : (t += 1) switch (tree.tokenTag(t)) {
            .l_bracket => depth += 1,
            .r_bracket => depth -= 1,
            .eof => return,
            else => {},
        };
        // t is past `]`
        if (tree.tokenTag(t) != .period or tree.tokenTag(t + 1) != .identifier) return;
        const m = tree.tokenSlice(t + 1);
        const array: []const u8 = if (std.mem.eql(u8, m, "name")) names else if (std.mem.eql(u8, m, "type")) (if (kind == .params) "param_types" else "field_types") else if (std.mem.eql(u8, m, "value")) "field_values" else return;
        const index_text = p.source[tree.tokenStart(last + 1)..tokenEnd(p.tree, t - 1)];
        const s = tree.tokenStart(access.member);
        const e = tokenEnd(tree, t + 1);
        if (p.overlaps(s, e)) return;
        try p.edits.append(p.arena, .{ .start = s, .end = e, .text = try std.fmt.allocPrint(p.arena, "{s}{s}", .{ array, index_text }) });
    }
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;
    var args = try init.minimal.args.iterateAllocator(arena);
    _ = args.next();
    var dry_run = false;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};
    var total_edits: usize = 0;
    var total_manual: usize = 0;
    while (args.next()) |path| {
        if (std.mem.eql(u8, path, "--dry-run")) {
            dry_run = true;
            continue;
        }
        const source = try std.Io.Dir.cwd().readFileAllocOptions(io, path, arena, .limited(64 << 20), .of(u8), 0);
        var tree = try Ast.parse(arena, source, .zig);
        if (tree.errors.len > 0) continue;
        var pass: Pass = .{ .arena = arena, .tree = &tree, .source = source, .path = path };
        // Innermost loops first: nodes are numbered children before parents.
        for (0..tree.nodes.len) |i| {
            const node: Ast.Node.Index = @fromBackingInt(@intCast(i));
            switch (tree.nodeTag(node)) {
                .for_simple, .@"for" => try rewriteFor(&pass, node),
                else => {},
            }
        }
        for (0..tree.nodes.len) |i| try rewriteAccess(&pass, @fromBackingInt(@intCast(i)));
        for (pass.manual.items) |m| try out.print("{s}\n", .{m});
        total_manual += pass.manual.items.len;
        if (pass.edits.items.len == 0) continue;
        total_edits += pass.edits.items.len;
        try out.print("EDIT {s}: {d}\n", .{ path, pass.edits.items.len });
        if (dry_run) continue;
        std.mem.sort(Edit, pass.edits.items, {}, struct {
            fn lt(_: void, a: Edit, b: Edit) bool {
                return a.start < b.start;
            }
        }.lt);
        var result: std.ArrayList(u8) = .empty;
        var at: usize = 0;
        for (pass.edits.items) |e| {
            try result.appendSlice(arena, source[at..e.start]);
            try result.appendSlice(arena, e.text);
            at = e.end;
        }
        try result.appendSlice(arena, source[at..]);
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = result.items });
    }
    try out.print("TOTAL rewritten={d} manual={d}\n", .{ total_edits, total_manual });
}
