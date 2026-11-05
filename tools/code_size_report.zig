//! The code-size report: a binary's functions grouped by generic family,
//! with count and bytes per family - what LLVM emitted, so what LLVM Emit
//! Object spent its time on (lane compiletime1, 2026-11-04; Rust's
//! cargo-llvm-lines counts LLVM IR lines per generic function the same way).
//!
//!   zig build code-size -- <binary> [--top=N] [--base=<binary>] [--tsv]
//!
//! A family is a function's name with every generic argument list emptied and
//! Zig's instance suffixes removed: every
//! `interface.V8Interface(Element.Element).MethodCallback("call_x"[0..6]).callback`
//! is `interface.V8Interface().MethodCallback().callback`, and every
//! `interface.freeArgument__func_7334` is `interface.freeArgument`. A C++
//! function counts under its top namespace (`C++ v8::`).
//!
//! Sizes come from the symbol table: an ELF symbol carries its size; a Mach-O
//! symbol's size is the distance to the next symbol of `__TEXT,__text` (the
//! last runs to the section's end), and symbols at one address count once.
//! `--base=<binary>` prints the base binary's count and bytes beside each
//! family, and the change. `--tsv` prints every family as
//! `bytes<TAB>count<TAB>family`.

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");
const Allocator = std.mem.Allocator;

/// One function: its name as the symbol table spells it and its bytes.
pub const Function = struct {
    name: []const u8,
    size: u64,
};

/// One family's totals.
pub const Family = struct {
    name: []const u8,
    count: u64 = 0,
    bytes: u64 = 0,
};

/// What a binary holds: its code section's size and its functions. Names
/// point into `strings`.
pub const Functions = struct {
    text_size: u64,
    list: []Function,
    strings: []u8,

    pub fn deinit(self: *Functions, allocator: Allocator) void {
        allocator.free(self.list);
        allocator.free(self.strings);
    }
};

pub const Error = error{ NotAnObjectFile, Truncated, NoSymbolTable, NoTextSection } || Allocator.Error;

// ============================================================================
// Names
// ============================================================================

/// Zig's suffixes for an instance of a generic function or an anonymous type:
/// `__func_7334`, `__anon_12`, `__struct_99`.
const instance_suffixes = [_][]const u8{ "__func_", "__anon_", "__struct_", "__enum_", "__union_", "__opaque_" };

/// `name`'s family, written to `out` (at least `name.len + 2` bytes).
/// `mach_o`: the name carries Mach-O's leading underscore.
pub fn familyOf(name_in: []const u8, mach_o: bool, out: []u8) []const u8 {
    var name = name_in;
    if (mach_o and name.len > 0 and name[0] == '_') name = name[1..];
    if (std.mem.startsWith(u8, name, "_Z")) return cxxFamily(name, out);

    // Empty every parenthesised list, quotes inside it included (a generic
    // argument may be a string, and a string may hold a parenthesis).
    var len: usize = 0;
    var depth: usize = 0;
    var in_quote = false;
    var i: usize = 0;
    while (i < name.len) : (i += 1) {
        const c = name[i];
        if (in_quote) {
            if (c == '\\') {
                i += 1;
            } else if (c == '"') {
                in_quote = false;
            }
            continue;
        }
        switch (c) {
            '"' => if (depth > 0) {
                in_quote = true;
            } else {
                out[len] = c;
                len += 1;
            },
            '(' => {
                if (depth == 0) {
                    out[len] = '(';
                    out[len + 1] = ')';
                    len += 2;
                }
                depth += 1;
            },
            ')' => {
                if (depth > 0) {
                    depth -= 1;
                } else {
                    out[len] = c;
                    len += 1;
                }
            },
            else => if (depth == 0) {
                out[len] = c;
                len += 1;
            },
        }
    }
    // Drop every `__func_<digits>` (and the other instance suffixes).
    var w: usize = 0;
    var r: usize = 0;
    outer: while (r < len) {
        for (instance_suffixes) |suffix| {
            if (r + suffix.len < len and std.mem.eql(u8, out[r .. r + suffix.len], suffix) and std.ascii.isDigit(out[r + suffix.len])) {
                var end = r + suffix.len;
                while (end < len and std.ascii.isDigit(out[end])) end += 1;
                r = end;
                continue :outer;
            }
        }
        out[w] = out[r];
        w += 1;
        r += 1;
    }
    return out[0..w];
}

/// A mangled C++ name's family: its top namespace (`_ZN2v88internal...` is
/// `C++ v8::`), or `C++` for a name with none (`_Z3foov`, a global function).
fn cxxFamily(name: []const u8, out: []u8) []const u8 {
    const prefix = "C++ ";
    @memcpy(out[0..prefix.len], prefix);
    var i: usize = 2;
    if (i >= name.len or name[i] != 'N') return out[0 .. prefix.len - 1];
    i += 1;
    while (i < name.len and (name[i] == 'K' or name[i] == 'V' or name[i] == 'r')) i += 1;
    var n: usize = 0;
    const digits_start = i;
    while (i < name.len and std.ascii.isDigit(name[i])) : (i += 1) n = n * 10 + (name[i] - '0');
    if (i == digits_start or n == 0 or i + n > name.len) return out[0 .. prefix.len - 1];
    @memcpy(out[prefix.len .. prefix.len + n], name[i .. i + n]);
    @memcpy(out[prefix.len + n .. prefix.len + n + 2], "::");
    return out[0 .. prefix.len + n + 2];
}

// ============================================================================
// Grouping
// ============================================================================

/// Every family of `functions`, largest first (then by name). Family names
/// are allocated; free them with `freeFamilies`.
pub fn group(allocator: Allocator, functions: []const Function, mach_o: bool) Allocator.Error![]Family {
    var map: std.StringHashMapUnmanaged(Family) = .empty;
    defer map.deinit(allocator);
    errdefer {
        var it = map.valueIterator();
        while (it.next()) |f| allocator.free(f.name);
    }
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    for (functions) |function| {
        try buf.resize(allocator, function.name.len + 8);
        const name = familyOf(function.name, mach_o, buf.items);
        const gop = try map.getOrPut(allocator, name);
        if (!gop.found_existing) {
            const owned = try allocator.dupe(u8, name);
            gop.key_ptr.* = owned;
            gop.value_ptr.* = .{ .name = owned };
        }
        gop.value_ptr.count += 1;
        gop.value_ptr.bytes += function.size;
    }
    const families = try allocator.alloc(Family, map.count());
    var it = map.valueIterator();
    var k: usize = 0;
    while (it.next()) |f| : (k += 1) families[k] = f.*;
    std.mem.sort(Family, families, {}, largerFirst);
    return families;
}

fn largerFirst(_: void, a: Family, b: Family) bool {
    if (a.bytes != b.bytes) return a.bytes > b.bytes;
    return std.mem.lessThan(u8, a.name, b.name);
}

pub fn freeFamilies(allocator: Allocator, families: []Family) void {
    for (families) |f| allocator.free(f.name);
    allocator.free(families);
}

// ============================================================================
// Object files
// ============================================================================

/// Reads `buffer.len` bytes at `offset` of a binary.
pub const Reader = struct {
    context: *const anyopaque,
    readAtFn: *const fn (context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void,

    fn readAt(self: Reader, offset: u64, buffer: []u8) anyerror!void {
        return self.readAtFn(self.context, offset, buffer);
    }

    fn alloc(self: Reader, allocator: Allocator, offset: u64, len: u64) anyerror![]u8 {
        const bytes = try allocator.alloc(u8, @intCast(len));
        errdefer allocator.free(bytes);
        try self.readAt(offset, bytes);
        return bytes;
    }
};

/// A binary held in memory (the tests' synthetic ones).
pub const MemoryReader = struct {
    bytes: []const u8,

    pub fn reader(self: *const MemoryReader) Reader {
        return .{ .context = self, .readAtFn = readAt };
    }

    fn readAt(context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void {
        const self: *const MemoryReader = @ptrCast(@alignCast(context));
        if (offset > self.bytes.len or self.bytes.len - offset < buffer.len) return error.Truncated;
        const start: usize = @intCast(offset);
        @memcpy(buffer, self.bytes[start .. start + buffer.len]);
    }
};

/// A binary on disk: only its headers and symbol table are read.
const FileReader = struct {
    file: std.Io.File,
    io: std.Io,

    fn reader(self: *const FileReader) Reader {
        return .{ .context = self, .readAtFn = readAt };
    }

    fn readAt(context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void {
        const self: *const FileReader = @ptrCast(@alignCast(context));
        const n = try self.file.readPositionalAll(self.io, buffer, offset);
        if (n != buffer.len) return error.Truncated;
    }
};

pub const Format = enum { mach_o, elf };

/// Which object format `head` (a binary's first 16 bytes) starts.
pub fn formatOf(head: []const u8) ?Format {
    if (head.len >= 4 and std.mem.readInt(u32, head[0..4], .little) == 0xfeedfacf) return .mach_o;
    if (head.len >= 6 and std.mem.eql(u8, head[0..4], "\x7fELF") and head[4] == 2 and head[5] == 1) return .elf;
    return null;
}

/// The functions of a 64-bit little-endian Mach-O or ELF binary.
pub fn readFunctions(allocator: Allocator, reader: Reader) anyerror!struct { Functions, Format } {
    var head: [16]u8 = undefined;
    try reader.readAt(0, &head);
    const format = formatOf(&head) orelse return error.NotAnObjectFile;
    return .{ switch (format) {
        .mach_o => try readMachO(allocator, reader),
        .elf => try readElf(allocator, reader),
    }, format };
}

const Symbol = struct { address: u64, name_offset: u32 };

fn byAddress(_: void, a: Symbol, b: Symbol) bool {
    return a.address < b.address;
}

fn readMachO(allocator: Allocator, reader: Reader) anyerror!Functions {
    var header: [32]u8 = undefined;
    try reader.readAt(0, &header);
    const ncmds = std.mem.readInt(u32, header[16..20], .little);
    const sizeofcmds = std.mem.readInt(u32, header[20..24], .little);
    const commands = try reader.alloc(allocator, 32, sizeofcmds);
    defer allocator.free(commands);

    // The load commands: LC_SYMTAB and each LC_SEGMENT_64's sections, whose
    // 1-based ordinal is a symbol's n_sect.
    var symoff: u32 = 0;
    var nsyms: u32 = 0;
    var stroff: u32 = 0;
    var strsize: u32 = 0;
    var have_symtab = false;
    var section_ordinal: u32 = 0;
    var text_ordinal: ?u32 = null;
    var text_start: u64 = 0;
    var text_size: u64 = 0;
    var at: usize = 0;
    for (0..ncmds) |_| {
        if (commands.len - at < 8) return error.Truncated;
        const cmd = std.mem.readInt(u32, commands[at..][0..4], .little);
        const cmdsize = std.mem.readInt(u32, commands[at + 4 ..][0..4], .little);
        if (cmdsize < 8 or commands.len - at < cmdsize) return error.Truncated;
        const body = commands[at .. at + cmdsize];
        switch (cmd) {
            0x2 => { // LC_SYMTAB
                if (body.len < 24) return error.Truncated;
                symoff = std.mem.readInt(u32, body[8..12], .little);
                nsyms = std.mem.readInt(u32, body[12..16], .little);
                stroff = std.mem.readInt(u32, body[16..20], .little);
                strsize = std.mem.readInt(u32, body[20..24], .little);
                have_symtab = true;
            },
            0x19 => { // LC_SEGMENT_64
                if (body.len < 72) return error.Truncated;
                const nsects = std.mem.readInt(u32, body[64..68], .little);
                if (body.len < 72 + @as(usize, nsects) * 80) return error.Truncated;
                for (0..nsects) |s| {
                    section_ordinal += 1;
                    const sect = body[72 + s * 80 ..][0..80];
                    if (std.mem.eql(u8, fixedName(sect[0..16]), "__text") and std.mem.eql(u8, fixedName(sect[16..32]), "__TEXT")) {
                        text_ordinal = section_ordinal;
                        text_start = std.mem.readInt(u64, sect[32..40], .little);
                        text_size = std.mem.readInt(u64, sect[40..48], .little);
                    }
                }
            },
            else => {},
        }
        at += cmdsize;
    }
    if (!have_symtab) return error.NoSymbolTable;
    const text = text_ordinal orelse return error.NoTextSection;

    const strings = try reader.alloc(allocator, stroff, strsize);
    errdefer allocator.free(strings);
    const table = try reader.alloc(allocator, symoff, @as(u64, nsyms) * 16);
    defer allocator.free(table);

    // nlist_64: n_strx u32, n_type u8, n_sect u8, n_desc u16, n_value u64.
    var symbols: std.ArrayList(Symbol) = .empty;
    defer symbols.deinit(allocator);
    for (0..nsyms) |k| {
        const entry = table[k * 16 ..][0..16];
        const n_type = entry[4];
        if (n_type & 0xe0 != 0) continue; // a debugger (stab) entry
        if (n_type & 0x0e != 0xe) continue; // not N_SECT
        if (entry[5] != text) continue;
        const strx = std.mem.readInt(u32, entry[0..4], .little);
        if (strx >= strings.len) continue;
        const name = std.mem.sliceTo(strings[strx..], 0);
        if (name.len == 0 or std.mem.startsWith(u8, name, "ltmp")) continue;
        try symbols.append(allocator, .{ .address = std.mem.readInt(u64, entry[8..16], .little), .name_offset = strx });
    }
    std.mem.sort(Symbol, symbols.items, {}, byAddress);

    var list: std.ArrayList(Function) = .empty;
    errdefer list.deinit(allocator);
    var k: usize = 0;
    while (k < symbols.items.len) {
        const address = symbols.items[k].address;
        var next = k + 1;
        while (next < symbols.items.len and symbols.items[next].address == address) next += 1;
        const end = if (next < symbols.items.len) symbols.items[next].address else text_start + text_size;
        try list.append(allocator, .{
            .name = std.mem.sliceTo(strings[symbols.items[k].name_offset..], 0),
            .size = end -| address,
        });
        k = next;
    }
    return .{ .text_size = text_size, .list = try list.toOwnedSlice(allocator), .strings = strings };
}

fn fixedName(bytes: []const u8) []const u8 {
    return std.mem.sliceTo(bytes, 0);
}

fn readElf(allocator: Allocator, reader: Reader) anyerror!Functions {
    var header: [64]u8 = undefined;
    try reader.readAt(0, &header);
    const shoff = std.mem.readInt(u64, header[40..48], .little);
    const shentsize = std.mem.readInt(u16, header[58..60], .little);
    const shnum = std.mem.readInt(u16, header[60..62], .little);
    const shstrndx = std.mem.readInt(u16, header[62..64], .little);
    if (shentsize < 64) return error.Truncated;
    const sections = try reader.alloc(allocator, shoff, @as(u64, shnum) * shentsize);
    defer allocator.free(sections);

    const Section = struct { name: u32, type: u32, offset: u64, size: u64, link: u32 };
    const sectionAt = struct {
        fn at(all: []const u8, entsize: u16, index: usize) Section {
            const s = all[index * entsize ..][0..64];
            return .{
                .name = std.mem.readInt(u32, s[0..4], .little),
                .type = std.mem.readInt(u32, s[4..8], .little),
                .offset = std.mem.readInt(u64, s[24..32], .little),
                .size = std.mem.readInt(u64, s[32..40], .little),
                .link = std.mem.readInt(u32, s[40..44], .little),
            };
        }
    }.at;

    if (shstrndx >= shnum) return error.Truncated;
    const shstr = sectionAt(sections, shentsize, shstrndx);
    const section_names = try reader.alloc(allocator, shstr.offset, shstr.size);
    defer allocator.free(section_names);

    var text_size: u64 = 0;
    var symtab: ?Section = null;
    for (0..shnum) |k| {
        const s = sectionAt(sections, shentsize, k);
        if (s.name < section_names.len and std.mem.eql(u8, std.mem.sliceTo(section_names[s.name..], 0), ".text")) text_size = s.size;
        if (s.type == 2) symtab = s; // SHT_SYMTAB
    }
    const table_section = symtab orelse return error.NoSymbolTable;
    if (table_section.link >= shnum) return error.Truncated;
    const strtab = sectionAt(sections, shentsize, table_section.link);
    const strings = try reader.alloc(allocator, strtab.offset, strtab.size);
    errdefer allocator.free(strings);
    const table = try reader.alloc(allocator, table_section.offset, table_section.size);
    defer allocator.free(table);

    // Elf64_Sym: st_name u32, st_info u8, st_other u8, st_shndx u16, st_value u64, st_size u64.
    var list: std.ArrayList(Function) = .empty;
    errdefer list.deinit(allocator);
    var k: usize = 0;
    while (k + 24 <= table.len) : (k += 24) {
        const entry = table[k..][0..24];
        if (entry[4] & 0xf != 2) continue; // not STT_FUNC
        const size = std.mem.readInt(u64, entry[16..24], .little);
        if (size == 0) continue;
        const name_offset = std.mem.readInt(u32, entry[0..4], .little);
        if (name_offset >= strings.len) continue;
        try list.append(allocator, .{ .name = std.mem.sliceTo(strings[name_offset..], 0), .size = size });
    }
    return .{ .text_size = text_size, .list = try list.toOwnedSlice(allocator), .strings = strings };
}

// ============================================================================
// The report
// ============================================================================

/// `n` with thousands separators.
fn grouped(buf: []u8, n: u64) []const u8 {
    var digits: [32]u8 = undefined;
    const plain = std.fmt.bufPrint(&digits, "{d}", .{n}) catch unreachable;
    var len: usize = 0;
    for (plain, 0..) |c, i| {
        if (i > 0 and (plain.len - i) % 3 == 0) {
            buf[len] = ',';
            len += 1;
        }
        buf[len] = c;
        len += 1;
    }
    return buf[0..len];
}

/// `now - base` with its sign: "+40", "-600", "0".
fn signed(buf: []u8, base: u64, now: u64) []const u8 {
    if (now > base) return std.fmt.bufPrint(buf, "+{d}", .{now - base}) catch unreachable;
    if (now < base) return std.fmt.bufPrint(buf, "-{d}", .{base - now}) catch unreachable;
    return "0";
}

fn sumBytes(functions: []const Function) u64 {
    var total: u64 = 0;
    for (functions) |f| total += f.size;
    return total;
}

/// The report of one binary: a totals line, then the `top` largest families.
pub fn writeReport(out: *std.Io.Writer, path: []const u8, functions: Functions, families: []const Family, top: usize) !void {
    var a: [40]u8 = undefined;
    var b: [40]u8 = undefined;
    try out.print("code size of {s}: text {s} bytes, {d} functions in {d} families (functions sum to {s} bytes)\n", .{
        path, grouped(&a, functions.text_size), functions.list.len, families.len, grouped(&b, sumBytes(functions.list)),
    });
    try out.print("{s:>5} {s:>13} {s:>6} {s:>8} {s:>9}  {s}\n", .{ "rank", "bytes", "%text", "count", "mean", "family" });
    for (families[0..@min(top, families.len)], 1..) |f, rank| {
        const pct = if (functions.text_size == 0) 0.0 else 100.0 * @as(f64, @floatFromInt(f.bytes)) / @as(f64, @floatFromInt(functions.text_size));
        try out.print("{d:>5} {s:>13} {d:>5.1}% {d:>8} {d:>9}  {s}\n", .{ rank, grouped(&a, f.bytes), pct, f.count, f.bytes / @max(f.count, 1), f.name });
    }
}

/// The report of a binary against a base binary: the `top` families by the
/// larger of their two sizes, each with both counts and sizes and the change.
pub fn writeComparison(
    allocator: Allocator,
    out: *std.Io.Writer,
    base_path: []const u8,
    base: Functions,
    base_families: []const Family,
    path: []const u8,
    current: Functions,
    families: []const Family,
    top: usize,
) !void {
    var a: [40]u8 = undefined;
    var b: [40]u8 = undefined;
    try out.print("base {s}: text {s} bytes, {d} functions in {d} families\n", .{ base_path, grouped(&a, base.text_size), base.list.len, base_families.len });
    try out.print("this {s}: text {s} bytes, {d} functions in {d} families\n", .{ path, grouped(&a, current.text_size), current.list.len, families.len });
    const delta: f64 = @as(f64, @floatFromInt(current.text_size)) - @as(f64, @floatFromInt(base.text_size));
    var c: [40]u8 = undefined;
    try out.print("text change: {s} bytes ({d:.1}%)\n", .{ signed(&c, base.text_size, current.text_size), if (base.text_size == 0) 0.0 else 100.0 * delta / @as(f64, @floatFromInt(base.text_size)) });

    const Row = struct { name: []const u8, base: Family, now: Family };
    var rows: std.StringArrayHashMapUnmanaged(Row) = .empty;
    defer rows.deinit(allocator);
    for (base_families) |f| try rows.put(allocator, f.name, .{ .name = f.name, .base = f, .now = .{ .name = f.name } });
    for (families) |f| {
        const gop = try rows.getOrPut(allocator, f.name);
        if (!gop.found_existing) gop.value_ptr.* = .{ .name = f.name, .base = .{ .name = f.name }, .now = .{ .name = f.name } };
        gop.value_ptr.now = f;
    }
    const sorted = try allocator.dupe(Row, rows.values());
    defer allocator.free(sorted);
    std.mem.sort(Row, sorted, {}, struct {
        fn lt(_: void, x: Row, y: Row) bool {
            const mx = @max(x.base.bytes, x.now.bytes);
            const my = @max(y.base.bytes, y.now.bytes);
            if (mx != my) return mx > my;
            return std.mem.lessThan(u8, x.name, y.name);
        }
    }.lt);
    try out.print("{s:>5} {s:>13} {s:>8} {s:>13} {s:>8} {s:>13}  {s}\n", .{ "rank", "base bytes", "count", "bytes", "count", "change", "family" });
    for (sorted[0..@min(top, sorted.len)], 1..) |row, rank| {
        var change: [40]u8 = undefined;
        try out.print("{d:>5} {s:>13} {d:>8} {s:>13} {d:>8} {s:>13}  {s}\n", .{ rank, grouped(&a, row.base.bytes), row.base.count, grouped(&b, row.now.bytes), row.now.count, signed(&change, row.base.bytes, row.now.bytes), row.name });
    }
}

pub fn writeTsv(out: *std.Io.Writer, families: []const Family) !void {
    for (families) |f| try out.print("{d}\t{d}\t{s}\n", .{ f.bytes, f.count, f.name });
}

fn loadBinary(allocator: Allocator, io: std.Io, path: []const u8) !struct { Functions, Format } {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const file_reader: FileReader = .{ .file = file, .io = io };
    return readFunctions(allocator, file_reader.reader());
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var path: ?[]const u8 = null;
    var base_path: ?[]const u8 = null;
    var top: usize = 40;
    var tsv = false;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--top=")) {
            top = std.fmt.parseInt(usize, arg["--top=".len..], 10) catch usage();
        } else if (std.mem.startsWith(u8, arg, "--base=")) {
            base_path = arg["--base=".len..];
        } else if (std.mem.eql(u8, arg, "--tsv")) {
            tsv = true;
        } else if (path == null and !std.mem.startsWith(u8, arg, "--")) {
            path = arg;
        } else usage();
    }
    const binary = path orelse usage();

    var stdout_buf: [8192]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const current, const format = try loadBinary(arena, io, binary);
    const families = try group(arena, current.list, format == .mach_o);
    if (tsv) return writeTsv(out, families);
    if (base_path) |bp| {
        const base, const base_format = try loadBinary(arena, io, bp);
        const base_families = try group(arena, base.list, base_format == .mach_o);
        return writeComparison(arena, out, bp, base, base_families, binary, current, families, top);
    }
    try writeReport(out, binary, current, families, top);
}

fn usage() noreturn {
    std.debug.print("usage: code_size_report <binary> [--top=N] [--base=<binary>] [--tsv]\n", .{});
    std.process.exit(2);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn expectFamily(expected: []const u8, name: []const u8, mach_o: bool) !void {
    var buf: [512]u8 = undefined;
    try testing.expectEqualStrings(expected, familyOf(name, mach_o, &buf));
}

test "a generic instance's family empties its argument lists and drops Zig's instance suffixes" {
    try expectFamily(
        "interface.V8Interface().MethodCallback().callback",
        "_interface.V8Interface(XSLTProcessor.XSLTProcessor).MethodCallback(\"call_reset\"[0..10]).callback",
        true,
    );
    try expectFamily(
        "interface.V8Interface().PropertyGetterCallback().callback.ErrorRealm.get",
        "_interface.V8Interface(XRWebGLSubImage.XRWebGLSubImage).PropertyGetterCallback(\"XRWebGLSubImage\"[0..15],\"get_colorTexture\"[0..16]).callback.ErrorRealm.get",
        true,
    );
    try expectFamily("interface.freeArgument", "_interface.freeArgument__func_7334", true);
    try expectFamily("interface.inBindingCatchScope.Thunk.run", "_interface.inBindingCatchScope__func_7378.Thunk.run", true);
    // A plain function is its own family; ELF names carry no underscore.
    try expectFamily("interface_bindings.installForScope", "interface_bindings.installForScope", false);
    try expectFamily("_leading", "_leading", false);
}

test "a parenthesis inside a quoted generic argument does not end the list" {
    try expectFamily("a.F().g", "_a.F(\"x)y\\\"(z\"[0..6]).g", true);
    // Nested lists empty as one.
    try expectFamily("hash_map.HashMap().put", "_hash_map.HashMap([]const u8,fn(u8) bool,hash_map.Ctx(u8)).put", true);
}

test "a C++ function counts under its top namespace" {
    try expectFamily("C++ v8::", "__ZN2v88internal8compiler16BytecodeAnalysis7AnalyzeEv", true);
    try expectFamily("C++ v8::", "_ZNK2v85Value8IsObjectEv", false);
    try expectFamily("C++", "__Z3foov", true);
}

test "families sum their functions' counts and bytes, largest first" {
    const functions = [_]Function{
        .{ .name = "_interface.V8Interface(A.A).constructorCallback", .size = 100 },
        .{ .name = "_interface.V8Interface(B.B).constructorCallback", .size = 300 },
        .{ .name = "_interface.freeArgument__func_1", .size = 50 },
        .{ .name = "_interface.freeArgument__func_2", .size = 70 },
        .{ .name = "_main", .size = 500 },
    };
    const families = try group(testing.allocator, &functions, true);
    defer freeFamilies(testing.allocator, families);
    try testing.expectEqual(@as(usize, 3), families.len);
    try testing.expectEqualStrings("main", families[0].name);
    try testing.expectEqualStrings("interface.V8Interface().constructorCallback", families[1].name);
    try testing.expectEqual(@as(u64, 2), families[1].count);
    try testing.expectEqual(@as(u64, 400), families[1].bytes);
    try testing.expectEqualStrings("interface.freeArgument", families[2].name);
    try testing.expectEqual(@as(u64, 120), families[2].bytes);
}

/// A minimal 64-bit Mach-O: one segment __TEXT with __text at 0x1000 (0x100
/// bytes), and `symbols` (name, n_type, n_sect, address).
fn buildMachO(allocator: Allocator, symbols: []const struct { []const u8, u8, u8, u64 }) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    const seg_size: u32 = 72 + 80;
    const symtab_size: u32 = 24;
    const cmds_size = seg_size + symtab_size;
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    const symoff: u32 = 32 + cmds_size;
    const stroff: u32 = symoff + @as(u32, @intCast(symbols.len * 16));
    var name_offsets: std.ArrayList(u32) = .empty;
    defer name_offsets.deinit(allocator);
    for (symbols) |s| {
        try name_offsets.append(allocator, @intCast(strings.items.len));
        try strings.appendSlice(allocator, s[0]);
        try strings.append(allocator, 0);
    }
    const w = struct {
        fn int(list: *std.ArrayList(u8), a: Allocator, comptime T: type, v: T) !void {
            var b: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &b, v, .little);
            try list.appendSlice(a, &b);
        }
        fn name16(list: *std.ArrayList(u8), a: Allocator, s: []const u8) !void {
            var b: [16]u8 = @splat(0);
            @memcpy(b[0..s.len], s);
            try list.appendSlice(a, &b);
        }
    };
    // mach_header_64
    try w.int(&bytes, allocator, u32, 0xfeedfacf);
    try w.int(&bytes, allocator, u32, 0x0100000c);
    try w.int(&bytes, allocator, u32, 0);
    try w.int(&bytes, allocator, u32, 2);
    try w.int(&bytes, allocator, u32, 2);
    try w.int(&bytes, allocator, u32, cmds_size);
    try w.int(&bytes, allocator, u32, 0);
    try w.int(&bytes, allocator, u32, 0);
    // LC_SEGMENT_64 __TEXT with one section
    try w.int(&bytes, allocator, u32, 0x19);
    try w.int(&bytes, allocator, u32, seg_size);
    try w.name16(&bytes, allocator, "__TEXT");
    for (0..4) |_| try w.int(&bytes, allocator, u64, 0);
    try w.int(&bytes, allocator, u32, 5);
    try w.int(&bytes, allocator, u32, 5);
    try w.int(&bytes, allocator, u32, 1);
    try w.int(&bytes, allocator, u32, 0);
    try w.name16(&bytes, allocator, "__text");
    try w.name16(&bytes, allocator, "__TEXT");
    try w.int(&bytes, allocator, u64, 0x1000);
    try w.int(&bytes, allocator, u64, 0x100);
    for (0..8) |_| try w.int(&bytes, allocator, u32, 0);
    // LC_SYMTAB
    try w.int(&bytes, allocator, u32, 0x2);
    try w.int(&bytes, allocator, u32, symtab_size);
    try w.int(&bytes, allocator, u32, symoff);
    try w.int(&bytes, allocator, u32, @intCast(symbols.len));
    try w.int(&bytes, allocator, u32, stroff);
    try w.int(&bytes, allocator, u32, @intCast(strings.items.len));
    // nlist_64 entries, then the strings
    for (symbols, name_offsets.items) |s, off| {
        try w.int(&bytes, allocator, u32, off);
        try bytes.append(allocator, s[1]);
        try bytes.append(allocator, s[2]);
        try w.int(&bytes, allocator, u16, 0);
        try w.int(&bytes, allocator, u64, s[3]);
    }
    try bytes.appendSlice(allocator, strings.items);
    return bytes.toOwnedSlice(allocator);
}

test "a Mach-O function's size runs to the next symbol of __text, and the last to the section's end" {
    const image = try buildMachO(testing.allocator, &.{
        .{ "_b", 0x0e, 1, 0x1040 },
        .{ "_a", 0x0f, 1, 0x1000 },
        .{ "_alias_of_a", 0x0e, 1, 0x1000 }, // same address: counted once
        .{ "_c", 0x0e, 1, 0x10c0 },
        .{ "_data", 0x0e, 2, 0x2000 }, // another section
        .{ "_undefined", 0x01, 0, 0 }, // not N_SECT
        .{ "_stab", 0x24, 1, 0x1000 }, // a debugger entry
        .{ "ltmp0", 0x0e, 1, 0x1080 }, // an assembler temporary
    });
    defer testing.allocator.free(image);
    const memory: MemoryReader = .{ .bytes = image };
    var functions, const format = try readFunctions(testing.allocator, memory.reader());
    defer functions.deinit(testing.allocator);
    try testing.expectEqual(Format.mach_o, format);
    try testing.expectEqual(@as(u64, 0x100), functions.text_size);
    try testing.expectEqual(@as(usize, 3), functions.list.len);
    try testing.expectEqual(@as(u64, 0x40), functions.list[0].size);
    try testing.expectEqual(@as(u64, 0x80), functions.list[1].size);
    try testing.expectEqualStrings("_b", functions.list[1].name);
    try testing.expectEqual(@as(u64, 0x40), functions.list[2].size);
    try testing.expectEqualStrings("_c", functions.list[2].name);
}

test "an ELF function's size is its symbol's, and only functions count" {
    // ELF64: header, then section headers at 64: [0] null, [1] .text, [2] .symtab
    // (link 3), [3] .strtab, [4] .shstrtab.
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(testing.allocator);
    const a = testing.allocator;
    const strtab = "\x00f1\x00obj\x00f2\x00";
    const shstrtab = "\x00.text\x00.symtab\x00.strtab\x00.shstrtab\x00";
    const shoff: u64 = 64;
    const sym_off: u64 = shoff + 5 * 64;
    const str_off: u64 = sym_off + 3 * 24;
    const shstr_off: u64 = str_off + strtab.len;
    var header: [64]u8 = @splat(0);
    @memcpy(header[0..4], "\x7fELF");
    header[4] = 2;
    header[5] = 1;
    std.mem.writeInt(u64, header[40..48], shoff, .little);
    std.mem.writeInt(u16, header[58..60], 64, .little);
    std.mem.writeInt(u16, header[60..62], 5, .little);
    std.mem.writeInt(u16, header[62..64], 4, .little);
    try bytes.appendSlice(a, &header);
    const sh = struct {
        fn add(list: *std.ArrayList(u8), al: Allocator, name: u32, kind: u32, offset: u64, size: u64, link: u32) !void {
            var s: [64]u8 = @splat(0);
            std.mem.writeInt(u32, s[0..4], name, .little);
            std.mem.writeInt(u32, s[4..8], kind, .little);
            std.mem.writeInt(u64, s[24..32], offset, .little);
            std.mem.writeInt(u64, s[32..40], size, .little);
            std.mem.writeInt(u32, s[40..44], link, .little);
            try list.appendSlice(al, &s);
        }
    };
    try sh.add(&bytes, a, 0, 0, 0, 0, 0);
    try sh.add(&bytes, a, 1, 1, 0, 0x500, 0); // .text
    try sh.add(&bytes, a, 7, 2, sym_off, 3 * 24, 3); // .symtab
    try sh.add(&bytes, a, 15, 3, str_off, strtab.len, 0); // .strtab
    try sh.add(&bytes, a, 23, 3, shstr_off, shstrtab.len, 0); // .shstrtab
    const sym = struct {
        fn add(list: *std.ArrayList(u8), al: Allocator, name: u32, info: u8, size: u64) !void {
            var s: [24]u8 = @splat(0);
            std.mem.writeInt(u32, s[0..4], name, .little);
            s[4] = info;
            std.mem.writeInt(u64, s[16..24], size, .little);
            try list.appendSlice(al, &s);
        }
    };
    try sym.add(&bytes, a, 1, 0x12, 0x30); // f1: global function
    try sym.add(&bytes, a, 4, 0x11, 0x99); // obj: an object
    try sym.add(&bytes, a, 8, 0x02, 0x20); // f2: local function
    try bytes.appendSlice(a, strtab);
    try bytes.appendSlice(a, shstrtab);

    const memory: MemoryReader = .{ .bytes = bytes.items };
    var functions, const format = try readFunctions(testing.allocator, memory.reader());
    defer functions.deinit(testing.allocator);
    try testing.expectEqual(Format.elf, format);
    try testing.expectEqual(@as(u64, 0x500), functions.text_size);
    try testing.expectEqual(@as(usize, 2), functions.list.len);
    try testing.expectEqualStrings("f1", functions.list[0].name);
    try testing.expectEqual(@as(u64, 0x30), functions.list[0].size);
    try testing.expectEqualStrings("f2", functions.list[1].name);
}

test "a file that is neither Mach-O nor ELF is refused" {
    const memory: MemoryReader = .{ .bytes = "#!/bin/sh\necho hello\n" };
    try testing.expectError(error.NotAnObjectFile, readFunctions(testing.allocator, memory.reader()));
}

test "the report prints totals and the largest families with thousands separators" {
    var functions_list = [_]Function{
        .{ .name = "_x.F(A).g", .size = 1_500_000 },
        .{ .name = "_x.F(B).g", .size = 500_000 },
        .{ .name = "_y", .size = 10 },
    };
    const functions: Functions = .{ .text_size = 4_000_000, .list = &functions_list, .strings = &.{} };
    const families = try group(testing.allocator, functions.list, true);
    defer freeFamilies(testing.allocator, families);
    var buf: [2048]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try writeReport(&w, "bin", functions, families, 1);
    const text = w.buffered();
    try testing.expect(std.mem.indexOf(u8, text, "text 4,000,000 bytes, 3 functions in 2 families (functions sum to 2,000,010 bytes)") != null);
    try testing.expect(std.mem.indexOf(u8, text, "2,000,000  50.0%        2 ") != null);
    try testing.expect(std.mem.indexOf(u8, text, "x.F().g") != null);
    // --top=1: the second family is not listed.
    try testing.expect(std.mem.indexOf(u8, text, "  y\n") == null);
}

test "the comparison lists a family that only one side has, with its change" {
    var base_list = [_]Function{ .{ .name = "_old", .size = 100 }, .{ .name = "_x.F(A).g", .size = 900 } };
    var now_list = [_]Function{ .{ .name = "_new", .size = 40 }, .{ .name = "_x.F(A).g", .size = 300 } };
    const base: Functions = .{ .text_size = 1000, .list = &base_list, .strings = &.{} };
    const now: Functions = .{ .text_size = 340, .list = &now_list, .strings = &.{} };
    const base_families = try group(testing.allocator, base.list, true);
    defer freeFamilies(testing.allocator, base_families);
    const families = try group(testing.allocator, now.list, true);
    defer freeFamilies(testing.allocator, families);
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try writeComparison(testing.allocator, &w, "a", base, base_families, "b", now, families, 10);
    const text = w.buffered();
    try testing.expect(std.mem.indexOf(u8, text, "text change: -660 bytes (-66.0%)") != null);
    try testing.expect(std.mem.indexOf(u8, text, "         -600  x.F().g") != null);
    try testing.expect(std.mem.indexOf(u8, text, "         -100  old") != null);
    try testing.expect(std.mem.indexOf(u8, text, "          +40  new") != null);
}
