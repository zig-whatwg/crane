//! The UBSan-symbol check: how many `__ubsan_handle_*` symbols a built
//! binary carries, read from its symbol tables (lane buildfix1, 2026-11-10).
//!
//!   ubsan_symbols --expect=none|some [--name=<build>] <binary>
//!
//! Code compiled with Zig's FULL C sanitizer calls `__ubsan_handle_*` when a
//! check fails, and a binary that links Zig's UBSan runtime defines them;
//! code compiled at `.trap` traps in place and names none. So a binary built
//! at `.trap` or `off` throughout - the production WPT runner and the release
//! console, Crane as it ships - has no such symbol at all, and one with any C
//! at `.full` - the bug-finding runner - has them. build.zig runs this on
//! each of the three as part of its own step (`zig build wpt-runner`,
//! `wpt-runner-bug-finding`, `repl-exe -Dwpt-runner-release`), with the
//! expectation the configure-time check derives from the build's modes
//! (build_mode.zig `needsUbsanRuntime`), so a build that silently carries the
//! other configuration's C fails its own step: generation 214's production
//! runner had 34 defined and 1,333 functions calling them (mbedTLS and zlib
//! at `.full`, from a dependency artifact the bug-finding graph shared).
//!
//! Only symbol-table entries count - ELF `SHT_SYMTAB` and `SHT_DYNSYM` with
//! their string tables, the Mach-O `LC_SYMTAB` without its debugger (stab)
//! entries - never a byte run elsewhere in the file, so a string literal or a
//! log message that happens to spell the name cannot match. Reads only the
//! headers and those tables. 64-bit little-endian ELF and Mach-O.

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");
const Allocator = std.mem.Allocator;

/// The `__ubsan_handle_*` symbols of a binary.
pub const Count = struct {
    defined: usize = 0,
    undefined: usize = 0,

    pub fn total(self: Count) usize {
        return self.defined + self.undefined;
    }
};

pub const Error = error{ NotAnObjectFile, Truncated, NoSymbolTable } || Allocator.Error;

/// Whether `name`, as a symbol table spells it, is a UBSan handler. Mach-O
/// prefixes every C name with `_` (`___ubsan_handle_add_overflow`); ELF does
/// not (`__ubsan_handle_add_overflow`).
pub fn isUbsanHandler(name: []const u8, mach_o: bool) bool {
    const c_name = if (mach_o and name.len > 0 and name[0] == '_') name[1..] else name;
    return std.mem.startsWith(u8, c_name, "__ubsan_handle_");
}

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

/// A binary on disk: only its headers and symbol tables are read.
pub const FileReader = struct {
    file: std.Io.File,
    io: std.Io,

    pub fn reader(self: *const FileReader) Reader {
        return .{ .context = self, .readAtFn = readAt };
    }

    fn readAt(context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void {
        const self: *const FileReader = @ptrCast(@alignCast(context));
        const n = try self.file.readPositionalAll(self.io, buffer, offset);
        if (n != buffer.len) return error.Truncated;
    }
};

pub const Format = enum { mach_o, elf };

/// Which object format `head` (a binary's first bytes) starts.
pub fn formatOf(head: []const u8) ?Format {
    if (head.len >= 4 and std.mem.readInt(u32, head[0..4], .little) == 0xfeedfacf) return .mach_o;
    if (head.len >= 6 and std.mem.eql(u8, head[0..4], "\x7fELF") and head[4] == 2 and head[5] == 1) return .elf;
    return null;
}

/// The `__ubsan_handle_*` symbols of a 64-bit little-endian Mach-O or ELF
/// binary or object file.
pub fn countUbsanHandlers(allocator: Allocator, reader: Reader) anyerror!Count {
    var head: [16]u8 = undefined;
    try reader.readAt(0, &head);
    return switch (formatOf(&head) orelse return error.NotAnObjectFile) {
        .mach_o => countMachO(allocator, reader),
        .elf => countElf(allocator, reader),
    };
}

fn countMachO(allocator: Allocator, reader: Reader) anyerror!Count {
    var header: [32]u8 = undefined;
    try reader.readAt(0, &header);
    const ncmds = std.mem.readInt(u32, header[16..20], .little);
    const sizeofcmds = std.mem.readInt(u32, header[20..24], .little);
    const commands = try reader.alloc(allocator, 32, sizeofcmds);
    defer allocator.free(commands);

    var count: Count = .{};
    var have_symtab = false;
    var at: usize = 0;
    for (0..ncmds) |_| {
        if (commands.len - at < 8) return error.Truncated;
        const cmd = std.mem.readInt(u32, commands[at..][0..4], .little);
        const cmdsize = std.mem.readInt(u32, commands[at + 4 ..][0..4], .little);
        if (cmdsize < 8 or commands.len - at < cmdsize) return error.Truncated;
        const body = commands[at .. at + cmdsize];
        at += cmdsize;
        if (cmd != 0x2) continue; // LC_SYMTAB
        if (body.len < 24) return error.Truncated;
        have_symtab = true;
        const symoff = std.mem.readInt(u32, body[8..12], .little);
        const nsyms = std.mem.readInt(u32, body[12..16], .little);
        const stroff = std.mem.readInt(u32, body[16..20], .little);
        const strsize = std.mem.readInt(u32, body[20..24], .little);
        const strings = try reader.alloc(allocator, stroff, strsize);
        defer allocator.free(strings);
        const table = try reader.alloc(allocator, symoff, @as(u64, nsyms) * 16);
        defer allocator.free(table);
        // nlist_64: n_strx u32, n_type u8, n_sect u8, n_desc u16, n_value u64.
        for (0..nsyms) |k| {
            const entry = table[k * 16 ..][0..16];
            const n_type = entry[4];
            if (n_type & 0xe0 != 0) continue; // a debugger (stab) entry, not a symbol
            const strx = std.mem.readInt(u32, entry[0..4], .little);
            if (strx >= strings.len) continue;
            if (!isUbsanHandler(std.mem.sliceTo(strings[strx..], 0), true)) continue;
            // N_TYPE 0 is N_UNDF: a reference to a symbol defined elsewhere.
            if (n_type & 0x0e == 0) count.undefined += 1 else count.defined += 1;
        }
    }
    if (!have_symtab) return error.NoSymbolTable;
    return count;
}

fn countElf(allocator: Allocator, reader: Reader) anyerror!Count {
    var header: [64]u8 = undefined;
    try reader.readAt(0, &header);
    const shoff = std.mem.readInt(u64, header[40..48], .little);
    const shentsize = std.mem.readInt(u16, header[58..60], .little);
    const shnum = std.mem.readInt(u16, header[60..62], .little);
    if (shentsize < 64) return error.Truncated;
    const sections = try reader.alloc(allocator, shoff, @as(u64, shnum) * shentsize);
    defer allocator.free(sections);

    const Section = struct { type: u32, offset: u64, size: u64, link: u32 };
    const sectionAt = struct {
        fn at(all: []const u8, entsize: u16, index: usize) Section {
            const s = all[index * entsize ..][0..64];
            return .{
                .type = std.mem.readInt(u32, s[4..8], .little),
                .offset = std.mem.readInt(u64, s[24..32], .little),
                .size = std.mem.readInt(u64, s[32..40], .little),
                .link = std.mem.readInt(u32, s[40..44], .little),
            };
        }
    }.at;

    var count: Count = .{};
    var have_symtab = false;
    for (0..shnum) |k| {
        const table_section = sectionAt(sections, shentsize, k);
        // SHT_SYMTAB (2) and SHT_DYNSYM (11), each naming its string table.
        if (table_section.type != 2 and table_section.type != 11) continue;
        have_symtab = true;
        if (table_section.link >= shnum) return error.Truncated;
        const strtab = sectionAt(sections, shentsize, table_section.link);
        const strings = try reader.alloc(allocator, strtab.offset, strtab.size);
        defer allocator.free(strings);
        const table = try reader.alloc(allocator, table_section.offset, table_section.size);
        defer allocator.free(table);
        // Elf64_Sym: st_name u32, st_info u8, st_other u8, st_shndx u16, st_value u64, st_size u64.
        var at: usize = 0;
        while (at + 24 <= table.len) : (at += 24) {
            const entry = table[at..][0..24];
            const name_offset = std.mem.readInt(u32, entry[0..4], .little);
            if (name_offset >= strings.len) continue;
            if (!isUbsanHandler(std.mem.sliceTo(strings[name_offset..], 0), false)) continue;
            // st_shndx SHN_UNDEF (0): a reference to a symbol defined elsewhere.
            if (std.mem.readInt(u16, entry[6..8], .little) == 0) count.undefined += 1 else count.defined += 1;
        }
    }
    if (!have_symtab) return error.NoSymbolTable;
    return count;
}

pub fn countFile(allocator: Allocator, io: std.Io, path: []const u8) !Count {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const file_reader: FileReader = .{ .file = file, .io = io };
    return countUbsanHandlers(allocator, file_reader.reader());
}

pub const Expect = enum { none, some };

/// Whether `count` is what `expect` says: no handler symbol at all, or at
/// least one.
pub fn meets(count: Count, expect: Expect) bool {
    return switch (expect) {
        .none => count.total() == 0,
        .some => count.total() > 0,
    };
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var expect: ?Expect = null;
    var name: ?[]const u8 = null;
    var path: ?[]const u8 = null;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--expect=")) {
            expect = std.meta.stringToEnum(Expect, arg["--expect=".len..]) orelse usage();
        } else if (std.mem.startsWith(u8, arg, "--name=")) {
            name = arg["--name=".len..];
        } else if (path == null and !std.mem.startsWith(u8, arg, "--")) {
            path = arg;
        } else usage();
    }
    const binary = path orelse usage();
    const wanted = expect orelse usage();
    const label = name orelse std.fs.path.basename(binary);

    const count = countFile(arena, io, binary) catch |err| {
        std.debug.print("ubsan_symbols: {s}: cannot read its symbol tables: {t}\n", .{ binary, err });
        std.process.exit(1);
    };
    if (!meets(count, wanted)) {
        switch (wanted) {
            .none => std.debug.print(
                "ubsan_symbols: {s} has {d} __ubsan_handle_ symbol(s) ({d} defined, {d} undefined), but its modes compile nothing with the full C sanitizer and link no UBSan runtime: some C in it is another build's (build.zig checkLinkedC, tests/wpt_runner/build_mode.zig)\n",
                .{ label, count.total(), count.defined, count.undefined },
            ),
            .some => std.debug.print(
                "ubsan_symbols: {s} has no __ubsan_handle_ symbol, but its modes compile C with the full sanitizer, whose checks call one: its C is not what its modes say (build.zig checkLinkedC, tests/wpt_runner/build_mode.zig)\n",
                .{label},
            ),
        }
        std.process.exit(1);
    }
    var stdout_buf: [512]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    try out.print("ubsan_symbols: {s}: {d} __ubsan_handle_ symbol(s) ({d} defined, {d} undefined), as its modes say ({t})\n", .{ label, count.total(), count.defined, count.undefined, wanted });
    try out.flush();
}

fn usage() noreturn {
    std.debug.print("usage: ubsan_symbols --expect=none|some [--name=<build>] <binary>\n", .{});
    std.process.exit(2);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "a handler's name as each format spells it" {
    try testing.expect(isUbsanHandler("__ubsan_handle_add_overflow", false));
    try testing.expect(isUbsanHandler("___ubsan_handle_add_overflow", true));
    try testing.expect(isUbsanHandler("__ubsan_handle_type_mismatch_v1_abort", false));
    // Mach-O's own underscore is not part of the C name.
    try testing.expect(!isUbsanHandler("__ubsan_handle_add_overflow", true));
    try testing.expect(!isUbsanHandler("ubsan_handle_add_overflow", false));
    try testing.expect(!isUbsanHandler("__ubsan_default_options", false));
    try testing.expect(!isUbsanHandler("crane_fixture_add", false));
}

/// A minimal 64-bit ELF object: a section header table with a null section,
/// a string table and a symbol table naming `names`, each defined (st_shndx
/// 1) or undefined (0).
fn buildElf(allocator: Allocator, names: []const struct { []const u8, bool }) ![]u8 {
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    var symbols: std.ArrayList(u8) = .empty;
    defer symbols.deinit(allocator);
    try symbols.appendNTimes(allocator, 0, 24); // the null symbol
    for (names) |entry| {
        var sym: [24]u8 = @splat(0);
        std.mem.writeInt(u32, sym[0..4], @intCast(strings.items.len), .little);
        sym[4] = 0x12; // STB_GLOBAL, STT_FUNC
        std.mem.writeInt(u16, sym[6..8], if (entry[1]) 1 else 0, .little);
        try symbols.appendSlice(allocator, &sym);
        try strings.appendSlice(allocator, entry[0]);
        try strings.append(allocator, 0);
    }
    // Layout: header (64), strings, symbols, then three section headers.
    const strings_at: u64 = 64;
    const symbols_at: u64 = strings_at + strings.items.len;
    const sections_at: u64 = symbols_at + symbols.items.len;
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var header: [64]u8 = @splat(0);
    @memcpy(header[0..4], "\x7fELF");
    header[4] = 2; // ELFCLASS64
    header[5] = 1; // little-endian
    std.mem.writeInt(u64, header[40..48], sections_at, .little);
    std.mem.writeInt(u16, header[58..60], 64, .little);
    std.mem.writeInt(u16, header[60..62], 3, .little);
    try bytes.appendSlice(allocator, &header);
    try bytes.appendSlice(allocator, strings.items);
    try bytes.appendSlice(allocator, symbols.items);
    try bytes.appendNTimes(allocator, 0, 64); // the null section
    var strtab: [64]u8 = @splat(0);
    std.mem.writeInt(u32, strtab[4..8], 3, .little); // SHT_STRTAB
    std.mem.writeInt(u64, strtab[24..32], strings_at, .little);
    std.mem.writeInt(u64, strtab[32..40], strings.items.len, .little);
    try bytes.appendSlice(allocator, &strtab);
    var symtab: [64]u8 = @splat(0);
    std.mem.writeInt(u32, symtab[4..8], 2, .little); // SHT_SYMTAB
    std.mem.writeInt(u64, symtab[24..32], symbols_at, .little);
    std.mem.writeInt(u64, symtab[32..40], symbols.items.len, .little);
    std.mem.writeInt(u32, symtab[40..44], 1, .little); // its strings: section 1
    try bytes.appendSlice(allocator, &symtab);
    return bytes.toOwnedSlice(allocator);
}

/// A minimal 64-bit Mach-O: one LC_SYMTAB naming `names`, each defined
/// (N_SECT) or undefined (N_UNDF), plus a debugger (stab) entry for each
/// name, which never counts.
fn buildMachO(allocator: Allocator, names: []const struct { []const u8, bool }) ![]u8 {
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    var symbols: std.ArrayList(u8) = .empty;
    defer symbols.deinit(allocator);
    var nsyms: u32 = 0;
    for (names) |entry| {
        const strx: u32 = @intCast(strings.items.len);
        try strings.appendSlice(allocator, entry[0]);
        try strings.append(allocator, 0);
        var sym: [16]u8 = @splat(0);
        std.mem.writeInt(u32, sym[0..4], strx, .little);
        sym[4] = if (entry[1]) 0x0f else 0x01; // N_SECT|N_EXT, or N_UNDF|N_EXT
        sym[5] = if (entry[1]) 1 else 0;
        try symbols.appendSlice(allocator, &sym);
        var stab: [16]u8 = @splat(0);
        std.mem.writeInt(u32, stab[0..4], strx, .little);
        stab[4] = 0x24; // N_FUN
        try symbols.appendSlice(allocator, &stab);
        nsyms += 2;
    }
    const symtab_size = 24;
    const symbols_at: u32 = 32 + symtab_size;
    const strings_at: u32 = symbols_at + @as(u32, @intCast(symbols.items.len));
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var header: [32]u8 = @splat(0);
    std.mem.writeInt(u32, header[0..4], 0xfeedfacf, .little);
    std.mem.writeInt(u32, header[16..20], 1, .little); // ncmds
    std.mem.writeInt(u32, header[20..24], symtab_size, .little);
    try bytes.appendSlice(allocator, &header);
    var symtab: [symtab_size]u8 = @splat(0);
    std.mem.writeInt(u32, symtab[0..4], 0x2, .little); // LC_SYMTAB
    std.mem.writeInt(u32, symtab[4..8], symtab_size, .little);
    std.mem.writeInt(u32, symtab[8..12], symbols_at, .little);
    std.mem.writeInt(u32, symtab[12..16], nsyms, .little);
    std.mem.writeInt(u32, symtab[16..20], strings_at, .little);
    std.mem.writeInt(u32, symtab[20..24], @intCast(strings.items.len), .little);
    try bytes.appendSlice(allocator, &symtab);
    try bytes.appendSlice(allocator, symbols.items);
    try bytes.appendSlice(allocator, strings.items);
    return bytes.toOwnedSlice(allocator);
}

fn countBytes(bytes: []const u8) !Count {
    const memory: MemoryReader = .{ .bytes = bytes };
    return countUbsanHandlers(testing.allocator, memory.reader());
}

test "an ELF symbol table's handlers count, defined and undefined apart, and nothing else does" {
    const bytes = try buildElf(testing.allocator, &.{
        .{ "__ubsan_handle_add_overflow", false },
        .{ "__ubsan_handle_shift_out_of_bounds", false },
        .{ "__ubsan_handle_add_overflow_abort", true },
        .{ "crane_fixture_add", true },
        .{ "__ubsan_default_options", true },
    });
    defer testing.allocator.free(bytes);
    const count = try countBytes(bytes);
    try testing.expectEqual(@as(usize, 2), count.undefined);
    try testing.expectEqual(@as(usize, 1), count.defined);
}

test "a Mach-O symbol table's handlers count, and its debugger entries do not" {
    const bytes = try buildMachO(testing.allocator, &.{
        .{ "___ubsan_handle_add_overflow", false },
        .{ "___ubsan_handle_type_mismatch_v1", true },
        .{ "_crane_fixture_add", true },
    });
    defer testing.allocator.free(bytes);
    const count = try countBytes(bytes);
    try testing.expectEqual(@as(usize, 1), count.undefined);
    try testing.expectEqual(@as(usize, 1), count.defined);
}

test "a binary whose symbols name no handler counts none, though its bytes spell one elsewhere" {
    // The name spelled past the tables, as a string literal or a log message
    // would be: not a symbol.
    var bytes = try buildElf(testing.allocator, &.{.{ "crane_fixture_add", true }});
    defer testing.allocator.free(bytes);
    const spelled = "__ubsan_handle_add_overflow";
    bytes = try testing.allocator.realloc(bytes, bytes.len + spelled.len);
    @memcpy(bytes[bytes.len - spelled.len ..], spelled);
    const count = try countBytes(bytes);
    try testing.expectEqual(@as(usize, 0), count.total());
    try testing.expect(meets(count, .none));
    try testing.expect(!meets(count, .some));
}

test "a file that is neither format is refused, and a format without a symbol table says so" {
    try testing.expectError(error.NotAnObjectFile, countBytes("not an object file at all"));
    var header: [64]u8 = @splat(0);
    @memcpy(header[0..4], "\x7fELF");
    header[4] = 2;
    header[5] = 1;
    std.mem.writeInt(u64, header[40..48], 64, .little);
    std.mem.writeInt(u16, header[58..60], 64, .little);
    std.mem.writeInt(u16, header[60..62], 0, .little);
    try testing.expectError(error.NoSymbolTable, countBytes(&header));
}

// Real objects: build.zig compiles one C source for both formats (ELF
// x86_64-linux, Mach-O aarch64-macos) with the full sanitizer and with
// `.trap` (`ubsan_fixtures`), so the counts above are checked against what
// Zig's compiler really emits, on every host.
const fixtures = @import("ubsan_fixtures");

test "a C object compiled with the full sanitizer names the handlers it calls, in both formats" {
    for ([_][]const u8{ fixtures.elf_full, fixtures.mach_o_full }) |path| {
        const count = try countFile(testing.allocator, testing.io, path);
        try testing.expect(count.undefined > 0);
        try testing.expect(meets(count, .some));
    }
}

test "the same C object compiled at .trap names none, in both formats" {
    for ([_][]const u8{ fixtures.elf_trap, fixtures.mach_o_trap }) |path| {
        const count = try countFile(testing.allocator, testing.io, path);
        try testing.expectEqual(@as(usize, 0), count.total());
        try testing.expect(meets(count, .none));
    }
}
