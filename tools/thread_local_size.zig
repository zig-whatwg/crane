//! The thread-local block check: how many bytes of thread-local storage a
//! built binary's image carries, read from its headers (lane tls1,
//! 2026-11-11).
//!
//!   thread_local_size [--name=<build>] <binary>                    report
//!   thread_local_size --budget=<file> [--name=<build>] <binary>    check
//!   thread_local_size --budget=<file> --lower=<bytes>              record a lower budget
//!
//! A thread-local variable is paid for per THREAD, and not only by the
//! threads that use it. On macOS the first touch of ANY thread-local of an
//! image makes dyld allocate that image's WHOLE thread-local block for the
//! thread (dyld's ThreadLocalVariables::instantiateVariable), and writes its
//! initial content over all of it; on Linux glibc allocates and clears the
//! executable's whole static TLS block with every thread it creates, touched
//! or not. So one large thread-local in anything the binary links is that
//! many bytes on every such thread. Crane's binaries carried Zig std's
//! per-thread alternate signal stack this way (`std.Options.signal_stack_size`,
//! 262,144 bytes, `Thread.maybeAttachSignalStack`'s threadlocal array): one
//! 278,528-byte block per thread, and +3.6 MB per process the day V8's worker
//! threads began to touch a thread-local (the V8 15.7 port, 14 cores). The
//! roots now set `signal_stack_size = null` and the platform maps each
//! thread's alternate stack itself (platform.attachSignalStack).
//!
//! build.zig runs this on the production WPT runner, the bug-finding runner
//! and the release console as part of their own steps, beside the
//! UBSan-symbol check, against tools/thread_local_size_budget.txt: a binary
//! whose block is over the budget fails its own build and is told its largest
//! thread-local symbols. The budget only goes down: `--lower` refuses a rise.
//!
//! The block is read from the headers, never guessed from names:
//! - Mach-O: the span of the image's thread-local sections, from the first
//!   S_THREAD_LOCAL_REGULAR or S_THREAD_LOCAL_ZEROFILL section's start to the
//!   last one's end (`__thread_data`, `__thread_bss`) - what dyld copies for
//!   a thread; in an object file, not laid out yet, their sum. Symbol sizes
//!   come from consecutive symbol addresses in those sections
//!   (`<name>$tlv$init`).
//! - ELF: the PT_TLS program header's memory size; in an object file, which
//!   has no program headers, the sum of its SHF_TLS sections. Symbol sizes
//!   are the STT_TLS symbols' own.
//! 64-bit little-endian Mach-O and ELF, as tools/ubsan_symbols.zig reads.

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");
const Allocator = std.mem.Allocator;

// The readers below are tools/ubsan_symbols.zig's, repeated: importing that
// file would compile its tests into this tool's test executable (a file's
// tests belong to every module that imports it), and they need its fixtures.

/// Reads `buffer.len` bytes at `offset` of a binary.
pub const Reader = struct {
    context: *const anyopaque,
    readAtFn: *const fn (context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void,
};

/// A binary held in memory (the tests' synthetic ones).
pub const MemoryReader = struct {
    bytes: []const u8,

    pub fn reader(self: *const MemoryReader) Reader {
        return .{ .context = self, .readAtFn = readAtMemory };
    }

    fn readAtMemory(context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void {
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
        return .{ .context = self, .readAtFn = readAtFile };
    }

    fn readAtFile(context: *const anyopaque, offset: u64, buffer: []u8) anyerror!void {
        const self: *const FileReader = @ptrCast(@alignCast(context));
        const n = try self.file.readPositionalAll(self.io, buffer, offset);
        if (n != buffer.len) return error.Truncated;
    }
};

const Format = enum { mach_o, elf };

/// Which object format `head` (a binary's first bytes) starts: 64-bit
/// little-endian Mach-O or ELF.
fn formatOf(head: []const u8) ?Format {
    if (head.len >= 4 and std.mem.readInt(u32, head[0..4], .little) == 0xfeedfacf) return .mach_o;
    if (head.len >= 6 and std.mem.eql(u8, head[0..4], "\x7fELF") and head[4] == 2 and head[5] == 1) return .elf;
    return null;
}

/// A thread-local symbol and the bytes of the block it takes.
pub const Symbol = struct {
    name: []const u8,
    size: u64,

    fn larger(_: void, a: Symbol, b: Symbol) bool {
        if (a.size != b.size) return a.size > b.size;
        return std.mem.lessThan(u8, a.name, b.name);
    }
};

/// How many of the largest symbols a reading keeps.
pub const largest_kept = 5;

/// An image's thread-local block.
pub const Block = struct {
    /// Bytes of thread-local storage one thread's copy of the image takes.
    size: u64 = 0,
    /// Its largest symbols, largest first (at most `largest_kept`); none
    /// when the binary has no symbol table.
    largest: []const Symbol = &.{},
};

fn readAt(reader: Reader, offset: u64, buffer: []u8) anyerror!void {
    return reader.readAtFn(reader.context, offset, buffer);
}

/// `len` bytes at `offset`, the arena's.
fn readAlloc(arena: Allocator, reader: Reader, offset: u64, len: u64) anyerror![]u8 {
    // No table of a binary this reads is 4 GiB: a length that large is a
    // header this does not understand.
    if (len > std.math.maxInt(u32)) return error.Truncated;
    const bytes = try arena.alloc(u8, @intCast(len));
    try readAt(reader, offset, bytes);
    return bytes;
}

fn keepLargest(arena: Allocator, symbols: []Symbol) Allocator.Error![]const Symbol {
    std.mem.sort(Symbol, symbols, {}, Symbol.larger);
    return arena.dupe(Symbol, symbols[0..@min(symbols.len, largest_kept)]);
}

/// The thread-local block of a 64-bit little-endian Mach-O or ELF binary or
/// object file. What it returns is the arena's.
pub fn threadLocalBlock(arena: Allocator, reader: Reader) anyerror!Block {
    var head: [16]u8 = undefined;
    try readAt(reader, 0, &head);
    return switch (formatOf(&head) orelse return error.NotAnObjectFile) {
        .mach_o => blockMachO(arena, reader),
        .elf => blockElf(arena, reader),
    };
}

fn blockMachO(arena: Allocator, reader: Reader) anyerror!Block {
    var header: [32]u8 = undefined;
    try readAt(reader, 0, &header);
    const ncmds = std.mem.readInt(u32, header[16..20], .little);
    const sizeofcmds = std.mem.readInt(u32, header[20..24], .little);
    const commands = try readAlloc(arena, reader, 32, sizeofcmds);

    // A thread-local data section: its ordinal (what a symbol's n_sect
    // names, counted from 1 across every segment) and its extent.
    const Section = struct { ordinal: u32, addr: u64, end: u64 };
    var sections: std.ArrayList(Section) = .empty;
    const Symtab = struct { symoff: u32, nsyms: u32, stroff: u32, strsize: u32 };
    var symtab: ?Symtab = null;
    var ordinal: u32 = 0;
    var at: usize = 0;
    for (0..ncmds) |_| {
        if (commands.len - at < 8) return error.Truncated;
        const cmd = std.mem.readInt(u32, commands[at..][0..4], .little);
        const cmdsize = std.mem.readInt(u32, commands[at + 4 ..][0..4], .little);
        if (cmdsize < 8 or commands.len - at < cmdsize) return error.Truncated;
        const body = commands[at .. at + cmdsize];
        at += cmdsize;
        switch (cmd) {
            // LC_SEGMENT_64: segment_command_64 (72 bytes), then its
            // section_64 entries (80 bytes each).
            0x19 => {
                if (body.len < 72) return error.Truncated;
                const nsects = std.mem.readInt(u32, body[64..68], .little);
                if ((body.len - 72) / 80 < nsects) return error.Truncated;
                for (0..nsects) |k| {
                    const section = body[72 + k * 80 ..][0..80];
                    ordinal += 1;
                    // The section's type is its flags' low byte:
                    // S_THREAD_LOCAL_REGULAR (0x11, initialized data) and
                    // S_THREAD_LOCAL_ZEROFILL (0x12). S_THREAD_LOCAL_VARIABLES
                    // (0x13) holds the descriptors, one per image, not per
                    // thread.
                    const kind = std.mem.readInt(u32, section[64..68], .little) & 0xff;
                    if (kind != 0x11 and kind != 0x12) continue;
                    const addr = std.mem.readInt(u64, section[32..40], .little);
                    const size = std.mem.readInt(u64, section[40..48], .little);
                    try sections.append(arena, .{ .ordinal = ordinal, .addr = addr, .end = addr +| size });
                }
            },
            // LC_SYMTAB
            0x2 => {
                if (body.len < 24) return error.Truncated;
                symtab = .{
                    .symoff = std.mem.readInt(u32, body[8..12], .little),
                    .nsyms = std.mem.readInt(u32, body[12..16], .little),
                    .stroff = std.mem.readInt(u32, body[16..20], .little),
                    .strsize = std.mem.readInt(u32, body[20..24], .little),
                };
            },
            else => {},
        }
    }
    if (sections.items.len == 0) return .{};
    var low: u64 = std.math.maxInt(u64);
    var high: u64 = 0;
    var sum: u64 = 0;
    for (sections.items) |section| {
        low = @min(low, section.addr);
        high = @max(high, section.end);
        sum +|= section.end - section.addr;
    }
    // A linked image's block is the span (dyld copies from the first
    // thread-local section to the end of the last, alignment between them
    // included). An object file (MH_OBJECT, filetype 1) is not laid out yet -
    // other sections sit between its thread-local ones - so its sections are
    // summed, as an ELF object's are.
    const is_object = std.mem.readInt(u32, header[12..16], .little) == 1;
    var block: Block = .{ .size = if (is_object) sum else high - low };

    const table_at = symtab orelse return block;
    const strings = try readAlloc(arena, reader, table_at.stroff, table_at.strsize);
    const table = try readAlloc(arena, reader, table_at.symoff, @as(u64, table_at.nsyms) * 16);
    // A symbol in a thread-local section: where it starts, and where its
    // section ends.
    const Placed = struct {
        addr: u64,
        section_end: u64,
        name: []const u8,

        fn before(_: void, a: @This(), b: @This()) bool {
            return a.addr < b.addr;
        }
    };
    var placed: std.ArrayList(Placed) = .empty;
    // nlist_64: n_strx u32, n_type u8, n_sect u8, n_desc u16, n_value u64.
    for (0..table_at.nsyms) |k| {
        const entry = table[k * 16 ..][0..16];
        const n_type = entry[4];
        if (n_type & 0xe0 != 0) continue; // a debugger (stab) entry, not a symbol
        if (n_type & 0x0e != 0x0e) continue; // not N_SECT: not defined in a section
        const section = for (sections.items) |section| {
            if (section.ordinal == entry[5]) break section;
        } else continue;
        const strx = std.mem.readInt(u32, entry[0..4], .little);
        if (strx >= strings.len) continue;
        const addr = std.mem.readInt(u64, entry[8..16], .little);
        if (addr < section.addr or addr >= section.end) continue;
        try placed.append(arena, .{ .addr = addr, .section_end = section.end, .name = std.mem.sliceTo(strings[strx..], 0) });
    }
    std.mem.sort(Placed, placed.items, {}, Placed.before);
    // Mach-O symbols carry no size: a symbol runs to the next one in its
    // section, the last to the section's end.
    const symbols = try arena.alloc(Symbol, placed.items.len);
    for (placed.items, symbols, 0..) |symbol, *out, k| {
        const next = if (k + 1 < placed.items.len) placed.items[k + 1].addr else symbol.section_end;
        out.* = .{ .name = symbol.name, .size = @min(next, symbol.section_end) - symbol.addr };
    }
    block.largest = try keepLargest(arena, symbols);
    return block;
}

fn blockElf(arena: Allocator, reader: Reader) anyerror!Block {
    var header: [64]u8 = undefined;
    try readAt(reader, 0, &header);
    const phoff = std.mem.readInt(u64, header[32..40], .little);
    const shoff = std.mem.readInt(u64, header[40..48], .little);
    const phentsize = std.mem.readInt(u16, header[54..56], .little);
    const phnum = std.mem.readInt(u16, header[56..58], .little);
    const shentsize = std.mem.readInt(u16, header[58..60], .little);
    const shnum = std.mem.readInt(u16, header[60..62], .little);

    var block: Block = .{};
    if (phnum != 0) {
        // A linked file: PT_TLS (7) is the static TLS block's template, and
        // its p_memsz the bytes each thread's copy takes (.tdata and .tbss).
        if (phentsize < 56) return error.Truncated;
        const headers = try readAlloc(arena, reader, phoff, @as(u64, phnum) * phentsize);
        for (0..phnum) |k| {
            const program = headers[k * phentsize ..][0..56];
            if (std.mem.readInt(u32, program[0..4], .little) != 7) continue;
            block.size +|= std.mem.readInt(u64, program[40..48], .little);
        }
    }
    if (shnum == 0) return block;
    if (shentsize < 64) return error.Truncated;
    const sections = try readAlloc(arena, reader, shoff, @as(u64, shnum) * shentsize);

    var symbols: std.ArrayList(Symbol) = .empty;
    for (0..shnum) |k| {
        const section = sections[k * shentsize ..][0..64];
        const kind = std.mem.readInt(u32, section[4..8], .little);
        // An object file has no program headers: its SHF_TLS (0x400)
        // sections are what the linker will lay out as the block.
        if (phnum == 0 and std.mem.readInt(u64, section[8..16], .little) & 0x400 != 0) {
            block.size +|= std.mem.readInt(u64, section[32..40], .little);
        }
        if (kind != 2) continue; // SHT_SYMTAB (the dynamic table repeats it)
        const link = std.mem.readInt(u32, section[40..44], .little);
        if (link >= shnum) return error.Truncated;
        const strtab = sections[link * shentsize ..][0..64];
        const strings = try readAlloc(arena, reader, std.mem.readInt(u64, strtab[24..32], .little), std.mem.readInt(u64, strtab[32..40], .little));
        const table = try readAlloc(arena, reader, std.mem.readInt(u64, section[24..32], .little), std.mem.readInt(u64, section[32..40], .little));
        // Elf64_Sym: st_name u32, st_info u8, st_other u8, st_shndx u16, st_value u64, st_size u64.
        var at: usize = 0;
        while (at + 24 <= table.len) : (at += 24) {
            const entry = table[at..][0..24];
            if (entry[4] & 0xf != 6) continue; // STT_TLS
            if (std.mem.readInt(u16, entry[6..8], .little) == 0) continue; // SHN_UNDEF: another image's
            const name_offset = std.mem.readInt(u32, entry[0..4], .little);
            if (name_offset >= strings.len) continue;
            try symbols.append(arena, .{ .name = std.mem.sliceTo(strings[name_offset..], 0), .size = std.mem.readInt(u64, entry[16..24], .little) });
        }
    }
    block.largest = try keepLargest(arena, symbols.items);
    return block;
}

pub fn blockOfFile(arena: Allocator, io: std.Io, path: []const u8) !Block {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const file_reader: FileReader = .{ .file = file, .io = io };
    return threadLocalBlock(arena, file_reader.reader());
}

// ============================================================================
// The budget
// ============================================================================

/// The budget file's one setting: the most bytes a checked build's
/// thread-local block may take.
pub const budget_key = "max_block_bytes";

const budget_header =
    \\# The thread-local block budget (tools/thread_local_size.zig, lane tls1).
    \\#
    \\# The most bytes of thread-local storage a checked build's image may carry:
    \\# the production WPT runner, the bug-finding runner and the release console,
    \\# each read back as part of its own build step. Every thread that touches a
    \\# thread-local pays the image's whole block on macOS, and every thread pays
    \\# it at creation on Linux, so this is a per-thread cost.
    \\#
    \\# It only goes down. Never edit it by hand: after removing thread-locals,
    \\#   zig build thread-local-size -- --budget=tools/thread_local_size_budget.txt --lower=<bytes>
    \\# records the lower number and refuses a higher one. A build over the budget
    \\# is fixed by taking the thread-local out (the check names the largest).
    \\
;

/// The budget a budget file's text sets, or null when it sets none.
pub fn parseBudget(text: []const u8) ?u64 {
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var words = std.mem.tokenizeAny(u8, line, " \t");
        const key = words.next() orelse continue;
        if (!std.mem.eql(u8, key, budget_key)) continue;
        return std.fmt.parseInt(u64, words.next() orelse return null, 10) catch null;
    }
    return null;
}

/// A budget file's whole text for `bytes`.
pub fn formatBudget(arena: Allocator, bytes: u64) Allocator.Error![]u8 {
    return std.fmt.allocPrint(arena, "{s}{s} {d}\n", .{ budget_header, budget_key, bytes });
}

/// The budget after a request to record `wanted` over `current` (null: no
/// budget recorded yet). The budget only goes down.
pub fn lowered(current: ?u64, wanted: u64) error{WouldRise}!u64 {
    if (current) |now| if (wanted > now) return error.WouldRise;
    return wanted;
}

/// Whether a block of `size` bytes is within `budget`.
pub fn within(size: u64, budget: u64) bool {
    return size <= budget;
}

/// "name 262144, other 40" for a message; "none named" without symbols.
fn describeLargest(arena: Allocator, largest: []const Symbol) Allocator.Error![]const u8 {
    if (largest.len == 0) return "none named (no symbol table)";
    var text: std.ArrayList(u8) = .empty;
    for (largest, 0..) |symbol, k| {
        if (k != 0) try text.appendSlice(arena, ", ");
        try text.print(arena, "{s} {d}", .{ symbol.name, symbol.size });
    }
    return text.items;
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var budget_path: ?[]const u8 = null;
    var lower: ?u64 = null;
    var name: ?[]const u8 = null;
    var path: ?[]const u8 = null;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--budget=")) {
            budget_path = arg["--budget=".len..];
        } else if (std.mem.startsWith(u8, arg, "--lower=")) {
            lower = std.fmt.parseInt(u64, arg["--lower=".len..], 10) catch usage();
        } else if (std.mem.startsWith(u8, arg, "--name=")) {
            name = arg["--name=".len..];
        } else if (path == null and !std.mem.startsWith(u8, arg, "--")) {
            path = arg;
        } else usage();
    }

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;

    const budget: ?u64 = if (budget_path) |file| blk: {
        const text = std.Io.Dir.cwd().readFileAlloc(io, file, arena, .limited(1 << 20)) catch |err| switch (err) {
            error.FileNotFound => break :blk null,
            else => {
                std.debug.print("thread_local_size: {s}: cannot read the budget: {t}\n", .{ file, err });
                std.process.exit(1);
            },
        };
        break :blk parseBudget(text) orelse {
            std.debug.print("thread_local_size: {s} sets no {s}\n", .{ file, budget_key });
            std.process.exit(1);
        };
    } else null;

    if (lower) |wanted| {
        const file = budget_path orelse usage();
        if (path != null) usage();
        const recorded = lowered(budget, wanted) catch {
            std.debug.print("thread_local_size: the budget is {d} bytes and only goes down: {d} is a rise. A build over the budget is fixed by taking the thread-local out, not by raising this.\n", .{ budget.?, wanted });
            std.process.exit(1);
        };
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file, .data = try formatBudget(arena, recorded) });
        if (budget) |was| {
            try out.print("thread_local_size: budget {d} -> {d} bytes ({s})\n", .{ was, recorded, file });
        } else {
            try out.print("thread_local_size: budget recorded: {d} bytes ({s})\n", .{ recorded, file });
        }
        try out.flush();
        return;
    }

    const binary = path orelse usage();
    const label = name orelse std.fs.path.basename(binary);
    const block = blockOfFile(arena, io, binary) catch |err| {
        std.debug.print("thread_local_size: {s}: cannot read its headers: {t}\n", .{ binary, err });
        std.process.exit(1);
    };
    const largest = try describeLargest(arena, block.largest);
    if (budget_path) |file| {
        const limit = budget orelse {
            std.debug.print("thread_local_size: {s} does not exist: record a budget with --lower first\n", .{file});
            std.process.exit(1);
        };
        if (!within(block.size, limit)) {
            std.debug.print(
                "thread_local_size: {s} carries a thread-local block of {d} bytes; the budget is {d} ({s}). Every thread that touches any thread-local of the image pays the whole block on macOS, and every thread pays it at creation on Linux. Largest: {s}. Take the large one out of thread-local storage - Zig std's signal stack is 262,144 bytes unless the root sets std_options.signal_stack_size = null (the platform maps each thread's alternate stack: platform.attachSignalStack). The budget only goes down (tools/thread_local_size.zig).\n",
                .{ label, block.size, limit, file, largest },
            );
            std.process.exit(1);
        }
        try out.print("thread_local_size: {s}: thread-local block {d} bytes, within the budget of {d}; largest: {s}\n", .{ label, block.size, limit, largest });
    } else {
        try out.print("thread_local_size: {s}: thread-local block {d} bytes; largest: {s}\n", .{ label, block.size, largest });
    }
    try out.flush();
}

fn usage() noreturn {
    std.debug.print(
        \\usage: thread_local_size [--name=<build>] <binary>
        \\       thread_local_size --budget=<file> [--name=<build>] <binary>
        \\       thread_local_size --budget=<file> --lower=<bytes>
        \\
    , .{});
    std.process.exit(2);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A section of a synthetic binary: its Mach-O type (or, for ELF, whether it
/// is SHF_TLS: any non-zero type), address and size.
const TestSection = struct { kind: u32, addr: u64, size: u64 };
/// A symbol of a synthetic binary: its section (index into the sections),
/// address, and - ELF only - size.
const TestSymbol = struct { name: []const u8, section: u8, addr: u64, size: u64 = 0, thread_local: bool = true };

/// A minimal 64-bit Mach-O: one LC_SEGMENT_64 holding `sections` and one
/// LC_SYMTAB naming `symbols`, each defined in its section, plus a debugger
/// (stab) entry per symbol, which never counts.
fn buildMachO(allocator: Allocator, sections: []const TestSection, symbols: []const TestSymbol) ![]u8 {
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    var table: std.ArrayList(u8) = .empty;
    defer table.deinit(allocator);
    for (symbols) |symbol| {
        const strx: u32 = @intCast(strings.items.len);
        try strings.appendSlice(allocator, symbol.name);
        try strings.append(allocator, 0);
        var entry: [16]u8 = @splat(0);
        std.mem.writeInt(u32, entry[0..4], strx, .little);
        entry[4] = 0x0f; // N_SECT | N_EXT
        entry[5] = symbol.section + 1;
        std.mem.writeInt(u64, entry[8..16], symbol.addr, .little);
        try table.appendSlice(allocator, &entry);
        var stab: [16]u8 = entry;
        stab[4] = 0x26; // N_STSYM
        try table.appendSlice(allocator, &stab);
    }
    const segment_size: u32 = @intCast(72 + 80 * sections.len);
    const symtab_size: u32 = 24;
    const symbols_at: u32 = 32 + segment_size + symtab_size;
    const strings_at: u32 = symbols_at + @as(u32, @intCast(table.items.len));

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var header: [32]u8 = @splat(0);
    std.mem.writeInt(u32, header[0..4], 0xfeedfacf, .little);
    std.mem.writeInt(u32, header[16..20], 2, .little); // ncmds
    std.mem.writeInt(u32, header[20..24], segment_size + symtab_size, .little);
    try bytes.appendSlice(allocator, &header);
    var segment: [72]u8 = @splat(0);
    std.mem.writeInt(u32, segment[0..4], 0x19, .little); // LC_SEGMENT_64
    std.mem.writeInt(u32, segment[4..8], segment_size, .little);
    std.mem.writeInt(u32, segment[64..68], @intCast(sections.len), .little);
    try bytes.appendSlice(allocator, &segment);
    for (sections) |section| {
        var entry: [80]u8 = @splat(0);
        std.mem.writeInt(u64, entry[32..40], section.addr, .little);
        std.mem.writeInt(u64, entry[40..48], section.size, .little);
        std.mem.writeInt(u32, entry[64..68], section.kind, .little);
        try bytes.appendSlice(allocator, &entry);
    }
    var symtab: [symtab_size]u8 = @splat(0);
    std.mem.writeInt(u32, symtab[0..4], 0x2, .little); // LC_SYMTAB
    std.mem.writeInt(u32, symtab[4..8], symtab_size, .little);
    std.mem.writeInt(u32, symtab[8..12], symbols_at, .little);
    std.mem.writeInt(u32, symtab[12..16], @intCast(symbols.len * 2), .little);
    std.mem.writeInt(u32, symtab[16..20], strings_at, .little);
    std.mem.writeInt(u32, symtab[20..24], @intCast(strings.items.len), .little);
    try bytes.appendSlice(allocator, &symtab);
    try bytes.appendSlice(allocator, table.items);
    try bytes.appendSlice(allocator, strings.items);
    return bytes.toOwnedSlice(allocator);
}

/// A minimal 64-bit ELF: a PT_TLS program header of `tls_memsz` bytes when
/// that is not null (a linked file; an object has none), and section headers
/// for a null section, `sections` (SHF_TLS when their kind is not 0), a
/// string table and a symbol table naming `symbols`.
fn buildElf(allocator: Allocator, tls_memsz: ?u64, sections: []const TestSection, symbols: []const TestSymbol) ![]u8 {
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    var table: std.ArrayList(u8) = .empty;
    defer table.deinit(allocator);
    try table.appendNTimes(allocator, 0, 24); // the null symbol
    for (symbols) |symbol| {
        var entry: [24]u8 = @splat(0);
        std.mem.writeInt(u32, entry[0..4], @intCast(strings.items.len), .little);
        entry[4] = if (symbol.thread_local) 0x16 else 0x11; // STB_GLOBAL | STT_TLS, or STT_OBJECT
        std.mem.writeInt(u16, entry[6..8], @as(u16, symbol.section) + 1, .little);
        std.mem.writeInt(u64, entry[8..16], symbol.addr, .little);
        std.mem.writeInt(u64, entry[16..24], symbol.size, .little);
        try table.appendSlice(allocator, &entry);
        try strings.appendSlice(allocator, symbol.name);
        try strings.append(allocator, 0);
    }
    // Layout: header (64), the program headers, strings, symbols, sections.
    const program_headers: u16 = if (tls_memsz != null) 2 else 0;
    const strings_at: u64 = 64 + @as(u64, program_headers) * 56;
    const symbols_at: u64 = strings_at + strings.items.len;
    const sections_at: u64 = symbols_at + table.items.len;
    const strtab_index: u32 = @intCast(1 + sections.len);

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var header: [64]u8 = @splat(0);
    @memcpy(header[0..4], "\x7fELF");
    header[4] = 2; // ELFCLASS64
    header[5] = 1; // little-endian
    std.mem.writeInt(u64, header[32..40], 64, .little);
    std.mem.writeInt(u64, header[40..48], sections_at, .little);
    std.mem.writeInt(u16, header[54..56], 56, .little);
    std.mem.writeInt(u16, header[56..58], program_headers, .little);
    std.mem.writeInt(u16, header[58..60], 64, .little);
    std.mem.writeInt(u16, header[60..62], @intCast(sections.len + 3), .little);
    try bytes.appendSlice(allocator, &header);
    if (tls_memsz) |memsz| {
        var load: [56]u8 = @splat(0);
        std.mem.writeInt(u32, load[0..4], 1, .little); // PT_LOAD: its memsz is not the block
        std.mem.writeInt(u64, load[40..48], 1 << 20, .little);
        try bytes.appendSlice(allocator, &load);
        var tls: [56]u8 = @splat(0);
        std.mem.writeInt(u32, tls[0..4], 7, .little); // PT_TLS
        std.mem.writeInt(u64, tls[40..48], memsz, .little);
        try bytes.appendSlice(allocator, &tls);
    }
    try bytes.appendSlice(allocator, strings.items);
    try bytes.appendSlice(allocator, table.items);
    try bytes.appendNTimes(allocator, 0, 64); // the null section
    for (sections) |section| {
        var entry: [64]u8 = @splat(0);
        std.mem.writeInt(u32, entry[4..8], 8, .little); // SHT_NOBITS
        std.mem.writeInt(u64, entry[8..16], if (section.kind != 0) 0x403 else 0x3, .little); // SHF_WRITE|SHF_ALLOC(|SHF_TLS)
        std.mem.writeInt(u64, entry[16..24], section.addr, .little);
        std.mem.writeInt(u64, entry[32..40], section.size, .little);
        try bytes.appendSlice(allocator, &entry);
    }
    var strtab: [64]u8 = @splat(0);
    std.mem.writeInt(u32, strtab[4..8], 3, .little); // SHT_STRTAB
    std.mem.writeInt(u64, strtab[24..32], strings_at, .little);
    std.mem.writeInt(u64, strtab[32..40], strings.items.len, .little);
    try bytes.appendSlice(allocator, &strtab);
    var symtab: [64]u8 = @splat(0);
    std.mem.writeInt(u32, symtab[4..8], 2, .little); // SHT_SYMTAB
    std.mem.writeInt(u64, symtab[24..32], symbols_at, .little);
    std.mem.writeInt(u64, symtab[32..40], table.items.len, .little);
    std.mem.writeInt(u32, symtab[40..44], strtab_index, .little);
    try bytes.appendSlice(allocator, &symtab);
    return bytes.toOwnedSlice(allocator);
}

fn blockOfBytes(arena: Allocator, bytes: []const u8) !Block {
    const memory: MemoryReader = .{ .bytes = bytes };
    return threadLocalBlock(arena, memory.reader());
}

test "a Mach-O image's block is the span of its thread-local sections, and its symbols run to the next one" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    // What main's console carries: 4 bytes of initialized thread-locals,
    // then the zero-filled ones - the signal stack among them.
    const bytes = try buildMachO(testing.allocator, &.{
        .{ .kind = 0x0, .addr = 0x1000, .size = 0x800000 }, // __text: not thread-local
        .{ .kind = 0x13, .addr = 0x900000, .size = 0x258 }, // __thread_vars: descriptors, not the block
        .{ .kind = 0x11, .addr = 0x900400, .size = 4 }, // __thread_data
        .{ .kind = 0x12, .addr = 0x900408, .size = 262144 + 48 }, // __thread_bss
    }, &.{
        .{ .name = "_main", .section = 0, .addr = 0x1000 },
        .{ .name = "_small$tlv$init", .section = 2, .addr = 0x900400 },
        .{ .name = "_Thread.maybeAttachSignalStack.global.signal_stack$tlv$init", .section = 3, .addr = 0x900408 },
        .{ .name = "_map$tlv$init", .section = 3, .addr = 0x900408 + 262144 },
        .{ .name = "_index$tlv$init", .section = 3, .addr = 0x900408 + 262144 + 40 },
    });
    defer testing.allocator.free(bytes);
    const block = try blockOfBytes(arena.allocator(), bytes);
    try testing.expectEqual(@as(u64, 8 + 262144 + 48), block.size);
    try testing.expectEqual(@as(usize, 4), block.largest.len);
    try testing.expectEqualStrings("_Thread.maybeAttachSignalStack.global.signal_stack$tlv$init", block.largest[0].name);
    try testing.expectEqual(@as(u64, 262144), block.largest[0].size);
    try testing.expectEqualStrings("_map$tlv$init", block.largest[1].name);
    try testing.expectEqual(@as(u64, 40), block.largest[1].size);
    // The last symbol of a section runs to the section's end.
    try testing.expectEqualStrings("_index$tlv$init", block.largest[2].name);
    try testing.expectEqual(@as(u64, 8), block.largest[2].size);
    try testing.expectEqual(@as(u64, 4), block.largest[3].size);
}

test "a linked ELF's block is its PT_TLS memory size, and its STT_TLS symbols carry their own sizes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const bytes = try buildElf(testing.allocator, 262144 + 64, &.{
        .{ .kind = 1, .addr = 0, .size = 262144 + 64 },
        .{ .kind = 0, .addr = 0x4000, .size = 1 << 20 },
    }, &.{
        .{ .name = "Thread.maybeAttachSignalStack.global.signal_stack", .section = 0, .addr = 0, .size = 262144 },
        .{ .name = "thread_index", .section = 0, .addr = 262144, .size = 8 },
        .{ .name = "a_plain_global", .section = 1, .addr = 0x4000, .size = 1 << 20, .thread_local = false },
    });
    defer testing.allocator.free(bytes);
    const block = try blockOfBytes(arena.allocator(), bytes);
    // The program header decides: the sections of a linked file are not
    // added to it, and a PT_LOAD's size is not thread-local.
    try testing.expectEqual(@as(u64, 262144 + 64), block.size);
    try testing.expectEqual(@as(usize, 2), block.largest.len);
    try testing.expectEqualStrings("Thread.maybeAttachSignalStack.global.signal_stack", block.largest[0].name);
    try testing.expectEqual(@as(u64, 262144), block.largest[0].size);
    try testing.expectEqualStrings("thread_index", block.largest[1].name);
}

test "an ELF object's block is the sum of its SHF_TLS sections" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const bytes = try buildElf(testing.allocator, null, &.{
        .{ .kind = 1, .addr = 0, .size = 4096 },
        .{ .kind = 0, .addr = 0, .size = 9999 },
        .{ .kind = 1, .addr = 0, .size = 16 },
    }, &.{});
    defer testing.allocator.free(bytes);
    const block = try blockOfBytes(arena.allocator(), bytes);
    try testing.expectEqual(@as(u64, 4096 + 16), block.size);
    try testing.expectEqual(@as(usize, 0), block.largest.len);
}

test "a binary with no thread-local has a block of 0 bytes, in both formats" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const mach_o = try buildMachO(testing.allocator, &.{.{ .kind = 0, .addr = 0x1000, .size = 64 }}, &.{.{ .name = "_main", .section = 0, .addr = 0x1000 }});
    defer testing.allocator.free(mach_o);
    try testing.expectEqual(@as(u64, 0), (try blockOfBytes(arena.allocator(), mach_o)).size);
    const elf = try buildElf(testing.allocator, null, &.{.{ .kind = 0, .addr = 0, .size = 64 }}, &.{.{ .name = "main", .section = 0, .addr = 0, .size = 64, .thread_local = false }});
    defer testing.allocator.free(elf);
    const block = try blockOfBytes(arena.allocator(), elf);
    try testing.expectEqual(@as(u64, 0), block.size);
    try testing.expectEqual(@as(usize, 0), block.largest.len);
}

test "only the largest symbols are kept, largest first" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var symbols: [largest_kept + 3]TestSymbol = undefined;
    const names = [_][]const u8{ "a", "b", "c", "d", "e", "f", "g", "h" };
    for (&symbols, names, 0..) |*symbol, name, k| symbol.* = .{ .name = name, .section = 0, .addr = 0, .size = (k + 1) * 8 };
    const bytes = try buildElf(testing.allocator, 4096, &.{.{ .kind = 1, .addr = 0, .size = 4096 }}, &symbols);
    defer testing.allocator.free(bytes);
    const block = try blockOfBytes(arena.allocator(), bytes);
    try testing.expectEqual(@as(usize, largest_kept), block.largest.len);
    try testing.expectEqualStrings("h", block.largest[0].name);
    try testing.expectEqual(@as(u64, 64), block.largest[0].size);
    try testing.expectEqualStrings("d", block.largest[largest_kept - 1].name);
}

test "a file that is neither format is refused" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.NotAnObjectFile, blockOfBytes(arena.allocator(), "not an object file at all"));
}

test "the budget: read from its file, kept by a block at or under it, and it only goes down" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const text = try formatBudget(arena.allocator(), 1024);
    try testing.expectEqual(@as(?u64, 1024), parseBudget(text));
    try testing.expectEqual(@as(?u64, null), parseBudget("# only a comment\n"));
    try testing.expectEqual(@as(?u64, null), parseBudget("max_block_bytes many\n"));

    try testing.expect(within(1024, 1024));
    try testing.expect(within(0, 1024));
    try testing.expect(!within(1025, 1024));
    // Zig std's signal stack alone is 256 times the budget.
    try testing.expect(!within(262144, 1024));

    try testing.expectEqual(@as(u64, 512), try lowered(1024, 512));
    try testing.expectEqual(@as(u64, 1024), try lowered(1024, 1024));
    try testing.expectError(error.WouldRise, lowered(1024, 1025));
    // The first record has nothing to rise above.
    try testing.expectEqual(@as(u64, 1024), try lowered(null, 1024));
}

// Real objects: build.zig compiles one C source for both formats (ELF
// x86_64-linux, Mach-O aarch64-macos) with a 65,536-byte zero-filled
// thread-local and a 4-byte initialized one (`thread_local_fixtures`), so the
// reading is checked against what Zig's compiler really emits, on every host.
const fixtures = @import("thread_local_fixtures");

test "a real object's thread-local array is its block's largest symbol, at its declared size, in both formats" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    for ([_][]const u8{ fixtures.elf, fixtures.mach_o }) |path| {
        const block = try blockOfFile(arena.allocator(), testing.io, path);
        // The array and the int, and whatever alignment puts between them.
        try testing.expect(block.size >= 65536 + 4);
        try testing.expect(block.size < 65536 + 64);
        try testing.expect(block.largest.len >= 2);
        try testing.expect(std.mem.indexOf(u8, block.largest[0].name, "crane_fixture_big") != null);
        try testing.expectEqual(@as(u64, 65536), block.largest[0].size);
        try testing.expect(std.mem.indexOf(u8, block.largest[1].name, "crane_fixture_small") != null);
        try testing.expectEqual(@as(u64, 4), block.largest[1].size);
        try testing.expect(!within(block.size, 1024));
    }
}

test "the same source without its thread-locals has no block, in both formats" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    for ([_][]const u8{ fixtures.elf_plain, fixtures.mach_o_plain }) |path| {
        const block = try blockOfFile(arena.allocator(), testing.io, path);
        try testing.expectEqual(@as(u64, 0), block.size);
        try testing.expectEqual(@as(usize, 0), block.largest.len);
    }
}
