//! Where two executables built from one tree differ, region by region - the
//! cold check of the build migration's proof standard
//! (tmp/plans/build-protocol-design.md, section 5.1a).
//!
//!     zig build section-diff -- <a> <b>
//!
//! Two cold builds of one tree at one cache path do not give byte-identical
//! executables. Measured on two cold builds of the WPT runner on macOS (lane
//! build2, 2026-11-13): 9,055 of 89,196,856 bytes differed, all in LC_UUID,
//! the debug map (each N_OSO entry names an object by its path under the
//! cache's `o/<digest>` and carries its modification time) and the code
//! signature, while every section of __TEXT, __DATA_CONST and __DATA was
//! byte-identical. So a hash cannot say "the same program": this tool says
//! it region by region, and its verdict leaves out exactly what names one
//! link rather than the program.
//!
//! A 64-bit little-endian Mach-O or ELF file is cut into regions, and each
//! region of one file is compared with the region of the same name in the
//! other:
//!   * Mach-O: the header and load commands (LC_UUID's sixteen bytes
//!     masked); each section of each segment (a zero-fill section holds no
//!     bytes); a segment without sections; the indirect symbol table; every
//!     __LINKEDIT blob a load command names (function starts, chained
//!     fixups, the exports trie...). LEFT OUT of the verdict: LC_UUID, the
//!     code signature and the debug map's object entries.
//!   * ELF: the ELF header (e_shoff masked: the section header table
//!     follows the debug sections, so it moves with them) and the program
//!     headers; every section, by name. An allocated section - what is
//!     loaded and run - must be equal at the same address; a build id (it
//!     hashes the whole file) and every section that is not allocated
//!     (.debug_*, .comment) are LEFT OUT, as the debug map is on Mach-O.
//!   * Either: the symbol table entry by entry, names read through the
//!     string table (so a name's offset may move): every entry but a debug
//!     map object entry must be equal in name, type, section, description
//!     and value (ELF: name, info, other, section index, value and size).
//!     That is the `nm -ap` comparison of 5.1a, without its OSO lines.
//!
//! The verdict: SAME PROGRAM when both files have the same regions in the
//! same order and every compared region and symbol is equal; DIFFERS
//! otherwise, naming each region. Exit status 0 (same), 1 (differs) or 2
//! (not two files of one format, or a malformed one).
//!
//! This ports lane build2's scratch script tmp/plans/build-migration-proof/
//! macho_diff.py, which printed the regions; the port adds ELF, the masked
//! header and the verdict, so a cold check can rely on it (tools/AGENTS.md:
//! tools are Zig, tested with std.testing).

const std = @import("std");
// stdout as a stream: Zig 0.17's positional File.writer overwrites a shared log.
const stdout_stream = @import("stdout_stream.zig");

pub const Format = enum {
    macho,
    elf,

    fn label(format: Format) []const u8 {
        return switch (format) {
            .macho => "Mach-O 64-bit",
            .elf => "ELF64",
        };
    }

    /// What the identity bytes are called in this format.
    fn identityLabel(format: Format) []const u8 {
        return switch (format) {
            .macho => "LC_UUID",
            .elf => "build id",
        };
    }
};

/// What a region's bytes mean for the verdict.
pub const Role = enum {
    /// Compared byte by byte: must be equal.
    compared,
    /// Compared entry by entry instead (the symbol table and its strings):
    /// the symbols decide.
    by_entry,
    /// Names one link rather than the program (a code signature, a build
    /// id, debug information): reported, never part of the verdict.
    left_out,

    fn note(role: Role) []const u8 {
        return switch (role) {
            .compared => "",
            .by_entry => "  (by entry, below)",
            .left_out => "  (left out)",
        };
    }
};

/// Bytes of a region that are not compared, relative to the region's start.
pub const Mask = struct { at: u64, len: u64 };

pub const Region = struct {
    /// The segment a Mach-O section is in ("__TEXT"), else empty.
    segment: []const u8 = "",
    name: []const u8,
    offset: u64,
    size: u64,
    role: Role,
    mask: ?Mask = null,
    /// Where the region is loaded (a section's address), so that equal bytes
    /// at another address are a different program.
    address: u64 = 0,

    fn sameName(r: Region, other: Region) bool {
        return std.mem.eql(u8, r.segment, other.segment) and std.mem.eql(u8, r.name, other.name);
    }

    pub fn format(r: Region, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (r.segment.len != 0) try w.print("{s},", .{r.segment});
        try w.writeAll(r.name);
    }
};

/// One symbol table entry, its name read from the string table.
pub const Symbol = struct {
    name: []const u8,
    /// Mach-O n_type; ELF st_info.
    type: u8,
    /// Mach-O n_sect; ELF st_other.
    sect: u8,
    /// Mach-O n_desc; ELF st_shndx.
    desc: u16,
    value: u64,
    /// ELF st_size; 0 for Mach-O.
    size: u64,
    /// A debug map entry naming an object file (Mach-O N_OSO): its path and
    /// time are the link's, not the program's.
    debug_map_object: bool,
};

pub const Parsed = struct {
    format: Format,
    regions: []Region,
    symbols: []Symbol,
    /// LC_UUID's bytes, or the build id's.
    identity: ?[]const u8,

    pub fn deinit(parsed: *Parsed, gpa: std.mem.Allocator) void {
        gpa.free(parsed.regions);
        gpa.free(parsed.symbols);
    }
};

pub const ParseError = error{ NotAnObjectFile, Truncated, OutOfMemory };

/// Which of the two formats `bytes` is, if either.
pub fn formatOf(bytes: []const u8) ?Format {
    if (bytes.len >= 4 and std.mem.readInt(u32, bytes[0..4], .little) == macho_magic) return .macho;
    if (bytes.len >= 6 and std.mem.eql(u8, bytes[0..4], "\x7fELF") and bytes[4] == 2 and bytes[5] == 1) return .elf;
    return null;
}

/// Cut `bytes` into regions and read its symbol table. Names are slices of
/// `bytes`, so `bytes` must outlive the result.
pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) ParseError!Parsed {
    return switch (formatOf(bytes) orelse return error.NotAnObjectFile) {
        .macho => parseMachO(gpa, bytes),
        .elf => parseElf(gpa, bytes),
    };
}

fn int(comptime T: type, bytes: []const u8, at: u64) ParseError!T {
    const n = @sizeOf(T);
    if (at > bytes.len or bytes.len - at < n) return error.Truncated;
    const start: usize = @intCast(at);
    return std.mem.readInt(T, bytes[start..][0..n], .little);
}

fn slice(bytes: []const u8, at: u64, len: u64) ParseError![]const u8 {
    if (at > bytes.len or bytes.len - at < len) return error.Truncated;
    const start: usize = @intCast(at);
    return bytes[start..][0..@intCast(len)];
}

/// A NUL-padded sixteen-byte name (a Mach-O segment's or section's).
fn fixedName(bytes: []const u8, at: u64) ParseError![]const u8 {
    const raw = try slice(bytes, at, 16);
    return raw[0 .. std.mem.indexOfScalar(u8, raw, 0) orelse raw.len];
}

/// The NUL-terminated string at `at` in `table`.
fn stringAt(table: []const u8, at: u64) []const u8 {
    if (at >= table.len) return "";
    const start: usize = @intCast(at);
    const end = std.mem.indexOfScalarPos(u8, table, start, 0) orelse table.len;
    return table[start..end];
}

// ---------------------------------------------------------------------------
// Mach-O (mach-o/loader.h, mach-o/nlist.h, mach-o/stab.h)
// ---------------------------------------------------------------------------

const macho_magic: u32 = 0xFEEDFACF;
const macho_header_size = 32;
const LC_SYMTAB: u32 = 0x2;
const LC_DYSYMTAB: u32 = 0xB;
const LC_SEGMENT_64: u32 = 0x19;
const LC_UUID: u32 = 0x1B;
const LC_CODE_SIGNATURE: u32 = 0x1D;
const LC_DYLD_INFO: u32 = 0x22;
const LC_DYLD_INFO_ONLY: u32 = 0x80000022;
/// n_type bits that make a symbol a debugger entry (a stab), whose n_type is
/// then its stab kind.
const N_STAB: u8 = 0xE0;
const N_OSO: u8 = 0x66;

/// The __LINKEDIT blobs a `linkedit_data_command` names.
fn linkeditBlob(cmd: u32) ?[]const u8 {
    return switch (cmd) {
        LC_CODE_SIGNATURE => "code signature",
        0x1E => "segment split info",
        0x26 => "function starts",
        0x29 => "data in code",
        0x2B => "dylib code sign DRs",
        0x2E => "linker optimization hints",
        0x80000033 => "dyld exports trie",
        0x80000034 => "dyld chained fixups",
        else => null,
    };
}

/// A section's type is its flags' low byte; a zero-fill one has no bytes in
/// the file (S_ZEROFILL, S_GB_ZEROFILL, S_THREAD_LOCAL_ZEROFILL).
fn isZeroFill(flags: u32) bool {
    return switch (flags & 0xFF) {
        0x1, 0xC, 0x12 => true,
        else => false,
    };
}

fn stabName(n_type: u8) []const u8 {
    return switch (n_type) {
        0x20 => "N_GSYM",
        0x24 => "N_FUN",
        0x26 => "N_STSYM",
        0x2E => "N_BNSYM",
        0x4E => "N_ENSYM",
        0x64 => "N_SO",
        0x66 => "N_OSO",
        0x84 => "N_SOL",
        else => "another stab",
    };
}

fn parseMachO(gpa: std.mem.Allocator, bytes: []const u8) ParseError!Parsed {
    var regions: std.ArrayList(Region) = .empty;
    errdefer regions.deinit(gpa);
    var identity: ?[]const u8 = null;
    var symoff: u64 = 0;
    var nsyms: u64 = 0;
    var strings: []const u8 = "";

    const ncmds = try int(u32, bytes, 16);
    const sizeofcmds = try int(u32, bytes, 20);
    try regions.append(gpa, .{ .name = "header and load commands", .offset = 0, .size = macho_header_size + @as(u64, sizeofcmds), .role = .compared });

    var off: u64 = macho_header_size;
    for (0..ncmds) |_| {
        const cmd = try int(u32, bytes, off);
        const cmdsize = try int(u32, bytes, off + 4);
        if (cmdsize < 8) return error.Truncated;
        switch (cmd) {
            LC_SEGMENT_64 => {
                const segname = try fixedName(bytes, off + 8);
                const vmaddr = try int(u64, bytes, off + 24);
                const fileoff = try int(u64, bytes, off + 40);
                const filesize = try int(u64, bytes, off + 48);
                const nsects = try int(u32, bytes, off + 64);
                // __LINKEDIT has no sections: its blobs come from their own load commands.
                if (nsects == 0 and filesize != 0 and !std.mem.eql(u8, segname, "__LINKEDIT")) {
                    try regions.append(gpa, .{ .name = segname, .offset = fileoff, .size = filesize, .role = .compared, .address = vmaddr });
                }
                for (0..nsects) |s| {
                    const at = off + 72 + @as(u64, s) * 80;
                    const flags = try int(u32, bytes, at + 64);
                    const offset = try int(u32, bytes, at + 48);
                    if (isZeroFill(flags) or offset == 0) continue;
                    try regions.append(gpa, .{
                        .segment = try fixedName(bytes, at + 16),
                        .name = try fixedName(bytes, at),
                        .offset = offset,
                        .size = try int(u64, bytes, at + 40),
                        .role = .compared,
                        .address = try int(u64, bytes, at + 32),
                    });
                }
            },
            LC_SYMTAB => {
                symoff = try int(u32, bytes, off + 8);
                nsyms = try int(u32, bytes, off + 12);
                const stroff = try int(u32, bytes, off + 16);
                const strsize = try int(u32, bytes, off + 20);
                strings = try slice(bytes, stroff, strsize);
                try regions.append(gpa, .{ .name = "symbol table", .offset = symoff, .size = nsyms * 16, .role = .by_entry });
                try regions.append(gpa, .{ .name = "string table", .offset = stroff, .size = strsize, .role = .by_entry });
            },
            LC_DYSYMTAB => {
                const indirectsymoff = try int(u32, bytes, off + 8 + 12 * 4);
                const nindirectsyms = try int(u32, bytes, off + 8 + 13 * 4);
                if (nindirectsyms != 0) try regions.append(gpa, .{ .name = "indirect symbol table", .offset = indirectsymoff, .size = @as(u64, nindirectsyms) * 4, .role = .compared });
            },
            LC_UUID => {
                identity = try slice(bytes, off + 8, 16);
                // The header region starts at 0, so a file offset is its offset.
                regions.items[0].mask = .{ .at = off + 8, .len = 16 };
            },
            LC_DYLD_INFO, LC_DYLD_INFO_ONLY => {
                const names = [_][]const u8{ "dyld rebase", "dyld bind", "dyld weak bind", "dyld lazy bind", "dyld export" };
                for (names, 0..) |name, k| {
                    const o = try int(u32, bytes, off + 8 + @as(u64, k) * 8);
                    const n = try int(u32, bytes, off + 12 + @as(u64, k) * 8);
                    if (n != 0) try regions.append(gpa, .{ .name = name, .offset = o, .size = n, .role = .compared });
                }
            },
            else => if (linkeditBlob(cmd)) |name| {
                const dataoff = try int(u32, bytes, off + 8);
                const datasize = try int(u32, bytes, off + 12);
                if (datasize != 0) try regions.append(gpa, .{ .name = name, .offset = dataoff, .size = datasize, .role = if (cmd == LC_CODE_SIGNATURE) .left_out else .compared });
            },
        }
        off += cmdsize;
    }
    for (regions.items) |r| _ = try slice(bytes, r.offset, r.size);

    var symbols: std.ArrayList(Symbol) = .empty;
    errdefer symbols.deinit(gpa);
    try symbols.ensureTotalCapacityPrecise(gpa, @intCast(nsyms));
    for (0..@intCast(nsyms)) |k| {
        const at = symoff + @as(u64, k) * 16;
        const entry = try slice(bytes, at, 16);
        symbols.appendAssumeCapacity(.{
            .name = stringAt(strings, std.mem.readInt(u32, entry[0..4], .little)),
            .type = entry[4],
            .sect = entry[5],
            .desc = std.mem.readInt(u16, entry[6..8], .little),
            .value = std.mem.readInt(u64, entry[8..16], .little),
            .size = 0,
            .debug_map_object = entry[4] == N_OSO,
        });
    }
    const regions_owned = try regions.toOwnedSlice(gpa);
    errdefer gpa.free(regions_owned);
    return .{ .format = .macho, .regions = regions_owned, .symbols = try symbols.toOwnedSlice(gpa), .identity = identity };
}

// ---------------------------------------------------------------------------
// ELF (the System V gABI, elf.h)
// ---------------------------------------------------------------------------

const SHT_SYMTAB: u32 = 2;
const SHT_NOBITS: u32 = 8;
const SHF_ALLOC: u64 = 0x2;
const elf_header_size = 64;
const elf_symbol_size = 24;

const SectionHeader = struct {
    name: []const u8,
    type: u32,
    flags: u64,
    address: u64,
    offset: u64,
    size: u64,
    link: u32,
};

fn sectionHeader(bytes: []const u8, at: u64, names: []const u8) ParseError!SectionHeader {
    return .{
        .name = stringAt(names, try int(u32, bytes, at)),
        .type = try int(u32, bytes, at + 4),
        .flags = try int(u64, bytes, at + 8),
        .address = try int(u64, bytes, at + 0x10),
        .offset = try int(u64, bytes, at + 0x18),
        .size = try int(u64, bytes, at + 0x20),
        .link = try int(u32, bytes, at + 0x28),
    };
}

fn parseElf(gpa: std.mem.Allocator, bytes: []const u8) ParseError!Parsed {
    var regions: std.ArrayList(Region) = .empty;
    errdefer regions.deinit(gpa);
    var identity: ?[]const u8 = null;

    const phoff = try int(u64, bytes, 0x20);
    const shoff = try int(u64, bytes, 0x28);
    const phentsize = try int(u16, bytes, 0x36);
    const phnum = try int(u16, bytes, 0x38);
    const shentsize = try int(u16, bytes, 0x3A);
    const shnum = try int(u16, bytes, 0x3C);
    const shstrndx = try int(u16, bytes, 0x3E);
    try regions.append(gpa, .{ .name = "ELF header", .offset = 0, .size = elf_header_size, .role = .compared, .mask = .{ .at = 0x28, .len = 8 } });
    if (phnum != 0) try regions.append(gpa, .{ .name = "program headers", .offset = phoff, .size = @as(u64, phnum) * phentsize, .role = .compared });
    if (shnum != 0 and (shentsize < 0x40 or shstrndx >= shnum)) return error.Truncated;

    const names = if (shnum == 0) "" else blk: {
        const h = try sectionHeader(bytes, shoff + @as(u64, shstrndx) * shentsize, "");
        break :blk try slice(bytes, h.offset, h.size);
    };
    // The symbol table's string table is compared through the entries' names.
    var symtab: ?SectionHeader = null;
    var symbol_strings: []const u8 = "";
    var symbol_strings_index: usize = 0; // none: section 0 is never a string table
    for (1..shnum) |s| { // section 0 is the null section
        const h = try sectionHeader(bytes, shoff + @as(u64, s) * shentsize, names);
        if (h.type != SHT_SYMTAB) continue;
        if (h.link == 0 or h.link >= shnum) return error.Truncated;
        const strings = try sectionHeader(bytes, shoff + @as(u64, h.link) * shentsize, names);
        symtab = h;
        symbol_strings = try slice(bytes, strings.offset, strings.size);
        symbol_strings_index = h.link;
        break;
    }
    for (1..shnum) |s| {
        const h = try sectionHeader(bytes, shoff + @as(u64, s) * shentsize, names);
        if (h.type == SHT_NOBITS or h.size == 0) continue;
        const build_id = std.mem.eql(u8, h.name, ".note.gnu.build-id");
        if (build_id) identity = buildId(try slice(bytes, h.offset, h.size));
        const role: Role = if (h.type == SHT_SYMTAB or s == symbol_strings_index)
            .by_entry
        else if (build_id or h.flags & SHF_ALLOC == 0)
            .left_out
        else
            .compared;
        try regions.append(gpa, .{ .name = h.name, .offset = h.offset, .size = h.size, .role = role, .address = h.address });
    }
    for (regions.items) |r| _ = try slice(bytes, r.offset, r.size);

    var symbols: std.ArrayList(Symbol) = .empty;
    errdefer symbols.deinit(gpa);
    if (symtab) |t| {
        const table = try slice(bytes, t.offset, t.size);
        var at: usize = 0;
        while (at + elf_symbol_size <= table.len) : (at += elf_symbol_size) {
            const entry = table[at..][0..elf_symbol_size];
            try symbols.append(gpa, .{
                .name = stringAt(symbol_strings, std.mem.readInt(u32, entry[0..4], .little)),
                .type = entry[4],
                .sect = entry[5],
                .desc = std.mem.readInt(u16, entry[6..8], .little),
                .value = std.mem.readInt(u64, entry[8..16], .little),
                .size = std.mem.readInt(u64, entry[16..24], .little),
                .debug_map_object = false,
            });
        }
    }
    const regions_owned = try regions.toOwnedSlice(gpa);
    errdefer gpa.free(regions_owned);
    return .{ .format = .elf, .regions = regions_owned, .symbols = try symbols.toOwnedSlice(gpa), .identity = identity };
}

/// A GNU build id note's descriptor: namesz, descsz and type, then the name
/// padded to four bytes, then the id.
fn buildId(note: []const u8) ?[]const u8 {
    if (note.len < 12) return null;
    const namesz = std.mem.readInt(u32, note[0..4], .little);
    const descsz = std.mem.readInt(u32, note[4..8], .little);
    const at = 12 + std.mem.alignForward(u64, namesz, 4);
    if (at > note.len or note.len - at < descsz) return null;
    return note[@intCast(at)..][0..descsz];
}

// ---------------------------------------------------------------------------
// The comparison
// ---------------------------------------------------------------------------

/// How many byte positions differ between `x` and `y`, the length
/// difference included; positions inside `mask` (relative) are skipped.
pub fn differing(x: []const u8, y: []const u8, mask: ?Mask) u64 {
    const n = @min(x.len, y.len);
    var count: u64 = @max(x.len, y.len) - n;
    var i: usize = 0;
    const chunk = 1 << 16;
    while (i < n) : (i += chunk) {
        const end = @min(i + chunk, n);
        if (std.mem.eql(u8, x[i..end], y[i..end])) continue;
        for (x[i..end], y[i..end], i..) |p, q, at| {
            if (p == q) continue;
            if (mask) |m| if (at >= m.at and at < m.at + m.len) continue;
            count += 1;
        }
    }
    return count;
}

pub const RegionResult = struct {
    region: Region,
    /// Differing bytes (the mask skipped), 0 when equal.
    differing: u64,
    /// The same size, address and (masked) bytes.
    equal: bool,
};

pub const SymbolKind = struct { kind: []const u8, fields: []const u8, count: u64 };

pub const Comparison = struct {
    format: Format,
    /// Differing byte positions over the whole files.
    total_differing: u64,
    /// Both files have the same regions, by name, in the same order.
    same_regions: bool,
    /// When `same_regions` is false: what one file has and the other not.
    only_in_a: []Region,
    only_in_b: []Region,
    results: []RegionResult,
    identity_a: ?[]const u8,
    identity_b: ?[]const u8,
    symbols_a: usize,
    symbols_b: usize,
    /// Differing entries outside the debug map, by kind and fields.
    symbol_kinds: []SymbolKind,
    symbols_differing: u64,
    debug_map_objects: u64,
    debug_map_differing: u64,

    /// Every compared region and every symbol outside the debug map equal,
    /// in files with the same regions.
    pub fn same(c: Comparison) bool {
        if (!c.same_regions or c.symbols_a != c.symbols_b or c.symbols_differing != 0) return false;
        for (c.results) |r| if (r.region.role == .compared and !r.equal) return false;
        return true;
    }

    pub fn deinit(c: *Comparison, gpa: std.mem.Allocator) void {
        gpa.free(c.only_in_a);
        gpa.free(c.only_in_b);
        gpa.free(c.results);
        for (c.symbol_kinds) |k| gpa.free(k.fields);
        gpa.free(c.symbol_kinds);
    }
};

pub const CompareError = ParseError || error{FormatsDiffer};

/// Compare two files' regions and symbols. The result's names are slices of
/// `a` and `b`, which must outlive it.
pub fn compare(gpa: std.mem.Allocator, a: []const u8, b: []const u8) CompareError!Comparison {
    var pa = try parse(gpa, a);
    defer pa.deinit(gpa);
    var pb = try parse(gpa, b);
    defer pb.deinit(gpa);
    if (pa.format != pb.format) return error.FormatsDiffer;

    var results: std.ArrayList(RegionResult) = .empty;
    errdefer results.deinit(gpa);
    var only_a: std.ArrayList(Region) = .empty;
    errdefer only_a.deinit(gpa);
    var only_b: std.ArrayList(Region) = .empty;
    errdefer only_b.deinit(gpa);

    var same_regions = pa.regions.len == pb.regions.len;
    if (same_regions) for (pa.regions, pb.regions) |x, y| {
        if (!x.sameName(y)) same_regions = false;
    };
    for (pa.regions) |x| {
        const y = for (pb.regions) |candidate| {
            if (x.sameName(candidate)) break candidate;
        } else {
            try only_a.append(gpa, x);
            continue;
        };
        const bx = a[@intCast(x.offset)..][0..@intCast(x.size)];
        const by = b[@intCast(y.offset)..][0..@intCast(y.size)];
        // A mask applies only where it sits at the same place in both.
        const mask: ?Mask = if (x.mask != null and y.mask != null and x.mask.?.at == y.mask.?.at and x.mask.?.len == y.mask.?.len) x.mask else null;
        const d = differing(bx, by, mask);
        try results.append(gpa, .{ .region = x, .differing = d, .equal = d == 0 and x.size == y.size and x.address == y.address });
    }
    for (pb.regions) |y| {
        for (pa.regions) |x| {
            if (x.sameName(y)) break;
        } else try only_b.append(gpa, y);
    }
    if (only_a.items.len != 0 or only_b.items.len != 0) same_regions = false;

    // The symbols, entry by entry.
    var kinds: std.ArrayList(SymbolKind) = .empty;
    errdefer {
        for (kinds.items) |k| gpa.free(k.fields);
        kinds.deinit(gpa);
    }
    var symbols_differing: u64 = 0;
    var debug_map_objects: u64 = 0;
    var debug_map_differing: u64 = 0;
    for (pa.symbols, 0..) |x, k| {
        if (x.debug_map_object) debug_map_objects += 1;
        if (k >= pb.symbols.len) break;
        const y = pb.symbols[k];
        if (x.debug_map_object and y.debug_map_object) {
            if (!std.mem.eql(u8, x.name, y.name) or x.value != y.value) debug_map_differing += 1;
            continue;
        }
        var fields: std.ArrayList(u8) = .empty;
        defer fields.deinit(gpa);
        const checks = [_]struct { []const u8, bool }{
            .{ "name", !std.mem.eql(u8, x.name, y.name) },
            .{ "type", x.type != y.type },
            .{ "sect", x.sect != y.sect },
            .{ "desc", x.desc != y.desc },
            .{ "value", x.value != y.value },
            .{ "size", x.size != y.size },
        };
        for (checks) |check| if (check[1]) {
            if (fields.items.len != 0) try fields.append(gpa, '+');
            try fields.appendSlice(gpa, check[0]);
        };
        if (fields.items.len == 0) continue;
        symbols_differing += 1;
        const kind = if (pa.format == .macho and x.type & N_STAB != 0) stabName(x.type) else "symbol";
        for (kinds.items) |*known| {
            if (std.mem.eql(u8, known.kind, kind) and std.mem.eql(u8, known.fields, fields.items)) {
                known.count += 1;
                break;
            }
        } else try kinds.append(gpa, .{ .kind = kind, .fields = try fields.toOwnedSlice(gpa), .count = 1 });
    }

    const owned_results = try results.toOwnedSlice(gpa);
    errdefer gpa.free(owned_results);
    const owned_a = try only_a.toOwnedSlice(gpa);
    errdefer gpa.free(owned_a);
    const owned_b = try only_b.toOwnedSlice(gpa);
    errdefer gpa.free(owned_b);
    return .{
        .format = pa.format,
        .total_differing = differing(a, b, null),
        .same_regions = same_regions,
        .only_in_a = owned_a,
        .only_in_b = owned_b,
        .results = owned_results,
        .identity_a = pa.identity,
        .identity_b = pb.identity,
        .symbols_a = pa.symbols.len,
        .symbols_b = pb.symbols.len,
        .symbol_kinds = try kinds.toOwnedSlice(gpa),
        .symbols_differing = symbols_differing,
        .debug_map_objects = debug_map_objects,
        .debug_map_differing = debug_map_differing,
    };
}

fn printHex(w: *std.Io.Writer, bytes: ?[]const u8) !void {
    const b = bytes orelse return w.writeAll("(none)");
    for (b) |byte| try w.print("{x:0>2}", .{byte});
}

/// The report: the regions with their verdicts, the symbols, the verdict.
pub fn report(w: *std.Io.Writer, c: Comparison) !void {
    try w.print("format: {s}\ndiffering bytes in all: {d}\n", .{ c.format.label(), c.total_differing });
    try w.print("{s}: ", .{c.format.identityLabel()});
    try printHex(w, c.identity_a);
    try w.writeAll(" and ");
    try printHex(w, c.identity_b);
    const same_identity = if (c.identity_a) |x| (if (c.identity_b) |y| std.mem.eql(u8, x, y) else false) else c.identity_b == null;
    try w.print(" ({s}, left out)\n", .{if (same_identity) "equal" else "differ"});
    if (!c.same_regions) {
        try w.writeAll("REGIONS DIFFER: the two files do not have the same regions in the same order\n");
        for (c.only_in_a) |r| try w.print("  only in the first:  {f} ({d} bytes)\n", .{ r, r.size });
        for (c.only_in_b) |r| try w.print("  only in the second: {f} ({d} bytes)\n", .{ r, r.size });
    }
    try w.writeAll("regions (verdict, name, bytes):\n");
    var equal: usize = 0;
    var left_out_differing: u64 = 0;
    for (c.results) |r| {
        if (r.equal) equal += 1;
        if (r.region.role == .left_out) left_out_differing += r.differing;
        if (r.equal) {
            try w.print("  equal    {f}  {d}{s}\n", .{ r.region, r.region.size, r.region.role.note() });
        } else if (r.differing == 0) {
            try w.print("  DIFFERS  {f}  {d}: same bytes, another size or address{s}\n", .{ r.region, r.region.size, r.region.role.note() });
        } else {
            try w.print("  DIFFERS  {f}  {d}: {d} bytes differ{s}\n", .{ r.region, r.region.size, r.differing, r.region.role.note() });
        }
    }
    try w.print("regions: {d}, equal: {d}\n", .{ c.results.len, equal });
    try w.print("symbols: {d} and {d} entries; {d} differ outside the debug map\n", .{ c.symbols_a, c.symbols_b, c.symbols_differing });
    for (c.symbol_kinds) |k| try w.print("  {d} entries differ - {s}: {s}\n", .{ k.count, k.kind, k.fields });
    if (c.format == .macho) try w.print("debug map: {d} object entries (N_OSO), {d} with another path or time (left out)\n", .{ c.debug_map_objects, c.debug_map_differing });

    if (c.same()) {
        try w.print("verdict: SAME PROGRAM - every compared region and symbol is equal (left out: the {s}, {d} differing bytes of left-out regions{s})\n", .{
            c.format.identityLabel(),
            left_out_differing,
            if (c.format == .macho) ", the debug map's object entries" else "",
        });
        return;
    }
    try w.writeAll("verdict: DIFFERS -");
    if (!c.same_regions) try w.writeAll(" the regions;");
    for (c.results) |r| if (r.region.role == .compared and !r.equal) try w.print(" {f};", .{r.region});
    if (c.symbols_a != c.symbols_b or c.symbols_differing != 0) try w.print(" {d} symbols;", .{c.symbols_differing + @as(u64, @max(c.symbols_a, c.symbols_b) - @min(c.symbols_a, c.symbols_b))});
    try w.writeAll("\n");
}

fn usage() noreturn {
    std.debug.print("usage: section_diff <a> <b>   (two 64-bit little-endian Mach-O or ELF files)\n", .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var paths: [2][]const u8 = undefined;
    var count: usize = 0;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (count == paths.len) usage();
        paths[count] = try arena.dupe(u8, arg);
        count += 1;
    }
    if (count != paths.len) usage();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;

    var files: [2][]const u8 = undefined;
    for (paths, &files) |path, *file| {
        file.* = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited) catch |err| {
            try out.print("section_diff: cannot read {s}: {t}\n", .{ path, err });
            try out.flush();
            std.process.exit(2);
        };
        var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(file.*, &digest, .{});
        try out.print("{s}: {d} bytes, sha256 ", .{ path, file.len });
        try printHex(out, digest[0..8]);
        try out.writeAll("\n");
    }
    var comparison = compare(arena, files[0], files[1]) catch |err| {
        try out.print("section_diff: {t}\n", .{err});
        try out.flush();
        std.process.exit(2);
    };
    defer comparison.deinit(arena);
    try report(out, comparison);
    try out.flush();
    if (!comparison.same()) std.process.exit(1);
}

// ---------------------------------------------------------------------------
// Tests: synthetic files of each format, built here to the layouts above
// ---------------------------------------------------------------------------

const testing = std.testing;

fn put(comptime T: type, buffer: []u8, at: usize, value: T) void {
    std.mem.writeInt(T, buffer[at..][0..@sizeOf(T)], value, .little);
}

fn putName(buffer: []u8, at: usize, name: []const u8) void {
    @memset(buffer[at..][0..16], 0);
    @memcpy(buffer[at..][0..name.len], name);
}

const TestSymbol = struct { name: []const u8, type: u8 = 0x0F, sect: u8 = 1, desc: u16 = 0, value: u64, size: u64 = 0 };

const TestMachO = struct {
    text: []const u8 = "\x1f\x20\x03\xd5\xc0\x03\x5f\xd6",
    data: []const u8 = "data",
    data_address: u64 = 0x100008000,
    uuid: [16]u8 = @splat(0x11),
    symbols: []const TestSymbol = &.{},
    signature: []const u8 = "signature",
};

/// A Mach-O file: __TEXT,__text and __DATA,__data, LC_UUID, a symbol table
/// and a code signature, in that order.
fn testMachO(gpa: std.mem.Allocator, spec: TestMachO) ![]u8 {
    const segment_size = 72 + 80;
    const sizeofcmds = 2 * segment_size + 24 + 24 + 16;
    const text_at = macho_header_size + sizeofcmds;
    const data_at = text_at + spec.text.len;
    const symbols_at = data_at + spec.data.len;
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(gpa);
    try strings.append(gpa, 0);
    var name_at: std.ArrayList(u32) = .empty;
    defer name_at.deinit(gpa);
    for (spec.symbols) |s| {
        try name_at.append(gpa, @intCast(strings.items.len));
        try strings.appendSlice(gpa, s.name);
        try strings.append(gpa, 0);
    }
    const strings_at = symbols_at + 16 * spec.symbols.len;
    const signature_at = strings_at + strings.items.len;
    const buffer = try gpa.alloc(u8, signature_at + spec.signature.len);
    @memset(buffer, 0);

    put(u32, buffer, 0, macho_magic);
    put(u32, buffer, 12, 2); // MH_EXECUTE
    put(u32, buffer, 16, 5);
    put(u32, buffer, 20, sizeofcmds);
    var off: usize = macho_header_size;
    const sections = [_]struct { seg: []const u8, sect: []const u8, at: usize, bytes: []const u8, address: u64 }{
        .{ .seg = "__TEXT", .sect = "__text", .at = text_at, .bytes = spec.text, .address = 0x100000000 + text_at },
        .{ .seg = "__DATA", .sect = "__data", .at = data_at, .bytes = spec.data, .address = spec.data_address },
    };
    for (sections) |s| {
        put(u32, buffer, off, LC_SEGMENT_64);
        put(u32, buffer, off + 4, segment_size);
        putName(buffer, off + 8, s.seg);
        put(u64, buffer, off + 24, s.address);
        put(u64, buffer, off + 40, s.at);
        put(u64, buffer, off + 48, s.bytes.len);
        put(u32, buffer, off + 64, 1);
        putName(buffer, off + 72, s.sect);
        putName(buffer, off + 72 + 16, s.seg);
        put(u64, buffer, off + 72 + 32, s.address);
        put(u64, buffer, off + 72 + 40, s.bytes.len);
        put(u32, buffer, off + 72 + 48, @intCast(s.at));
        @memcpy(buffer[s.at..][0..s.bytes.len], s.bytes);
        off += segment_size;
    }
    put(u32, buffer, off, LC_UUID);
    put(u32, buffer, off + 4, 24);
    @memcpy(buffer[off + 8 ..][0..16], &spec.uuid);
    off += 24;
    put(u32, buffer, off, LC_SYMTAB);
    put(u32, buffer, off + 4, 24);
    put(u32, buffer, off + 8, @intCast(symbols_at));
    put(u32, buffer, off + 12, @intCast(spec.symbols.len));
    put(u32, buffer, off + 16, @intCast(strings_at));
    put(u32, buffer, off + 20, @intCast(strings.items.len));
    off += 24;
    put(u32, buffer, off, LC_CODE_SIGNATURE);
    put(u32, buffer, off + 4, 16);
    put(u32, buffer, off + 8, @intCast(signature_at));
    put(u32, buffer, off + 12, @intCast(spec.signature.len));
    for (spec.symbols, name_at.items, 0..) |s, at, k| {
        const e = symbols_at + 16 * k;
        put(u32, buffer, e, at);
        buffer[e + 4] = s.type;
        buffer[e + 5] = s.sect;
        put(u16, buffer, e + 6, s.desc);
        put(u64, buffer, e + 8, s.value);
    }
    @memcpy(buffer[strings_at..][0..strings.items.len], strings.items);
    @memcpy(buffer[signature_at..][0..spec.signature.len], spec.signature);
    return buffer;
}

const TestElf = struct {
    text: []const u8 = "\x55\x48\x89\xe5\xc3",
    text_address: u64 = 0x201000,
    debug_info: []const u8 = "debug information",
    build_id: [8]u8 = @splat(0x22),
    symbols: []const TestSymbol = &.{},
    /// Lay the symbol names out in the string table in reverse order: the
    /// same names at other offsets.
    reverse_strings: bool = false,
};

/// `testElf`'s section names.
const test_shstrtab = "\x00.note.gnu.build-id\x00.text\x00.debug_info\x00.symtab\x00.strtab\x00.shstrtab\x00";

/// An ELF file: a build id note, .text, .debug_info, .symtab, .strtab and
/// .shstrtab, then the section header table.
fn testElf(gpa: std.mem.Allocator, spec: TestElf) ![]u8 {
    const shstrtab = test_shstrtab;
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(gpa);
    try strings.append(gpa, 0);
    const name_at = try gpa.alloc(u32, spec.symbols.len);
    defer gpa.free(name_at);
    for (0..spec.symbols.len) |n| {
        const k = if (spec.reverse_strings) spec.symbols.len - 1 - n else n;
        name_at[k] = @intCast(strings.items.len);
        try strings.appendSlice(gpa, spec.symbols[k].name);
        try strings.append(gpa, 0);
    }
    const note_size = 12 + 4 + spec.build_id.len;
    const note_at = elf_header_size;
    const text_at = note_at + note_size;
    const debug_at = text_at + spec.text.len;
    const symtab_at = debug_at + spec.debug_info.len;
    const symtab_size = elf_symbol_size * (1 + spec.symbols.len);
    const strtab_at = symtab_at + symtab_size;
    const shstrtab_at = strtab_at + strings.items.len;
    const shoff = std.mem.alignForward(usize, shstrtab_at + shstrtab.len, 8);
    const shnum = 7;
    const buffer = try gpa.alloc(u8, shoff + shnum * 64);
    @memset(buffer, 0);

    @memcpy(buffer[0..4], "\x7fELF");
    buffer[4] = 2;
    buffer[5] = 1;
    buffer[6] = 1;
    put(u16, buffer, 0x10, 2); // ET_EXEC
    put(u16, buffer, 0x12, 62); // x86-64
    put(u64, buffer, 0x28, shoff);
    put(u16, buffer, 0x34, elf_header_size);
    put(u16, buffer, 0x3A, 64);
    put(u16, buffer, 0x3C, shnum);
    put(u16, buffer, 0x3E, 6);

    put(u32, buffer, note_at, 4);
    put(u32, buffer, note_at + 4, spec.build_id.len);
    put(u32, buffer, note_at + 8, 3); // NT_GNU_BUILD_ID
    @memcpy(buffer[note_at + 12 ..][0..4], "GNU\x00");
    @memcpy(buffer[note_at + 16 ..][0..spec.build_id.len], &spec.build_id);
    @memcpy(buffer[text_at..][0..spec.text.len], spec.text);
    @memcpy(buffer[debug_at..][0..spec.debug_info.len], spec.debug_info);
    for (spec.symbols, name_at, 1..) |s, at, k| {
        const e = symtab_at + elf_symbol_size * k;
        put(u32, buffer, e, at);
        buffer[e + 4] = s.type;
        buffer[e + 5] = s.sect;
        put(u16, buffer, e + 6, s.desc);
        put(u64, buffer, e + 8, s.value);
        put(u64, buffer, e + 16, s.size);
    }
    @memcpy(buffer[strtab_at..][0..strings.items.len], strings.items);
    @memcpy(buffer[shstrtab_at..][0..shstrtab.len], shstrtab);

    const headers = [_]struct { name: []const u8, type: u32, flags: u64, address: u64, at: usize, size: usize, link: u32 = 0 }{
        .{ .name = ".note.gnu.build-id", .type = 7, .flags = SHF_ALLOC, .address = 0x200200, .at = note_at, .size = note_size },
        .{ .name = ".text", .type = 1, .flags = SHF_ALLOC | 0x4, .address = spec.text_address, .at = text_at, .size = spec.text.len },
        .{ .name = ".debug_info", .type = 1, .flags = 0, .address = 0, .at = debug_at, .size = spec.debug_info.len },
        .{ .name = ".symtab", .type = SHT_SYMTAB, .flags = 0, .address = 0, .at = symtab_at, .size = symtab_size, .link = 5 },
        .{ .name = ".strtab", .type = 3, .flags = 0, .address = 0, .at = strtab_at, .size = strings.items.len },
        .{ .name = ".shstrtab", .type = 3, .flags = 0, .address = 0, .at = shstrtab_at, .size = shstrtab.len },
    };
    for (headers, 1..) |h, s| {
        const at = shoff + 64 * s;
        put(u32, buffer, at, @intCast(std.mem.indexOf(u8, shstrtab, h.name).?));
        put(u32, buffer, at + 4, h.type);
        put(u64, buffer, at + 8, h.flags);
        put(u64, buffer, at + 0x10, h.address);
        put(u64, buffer, at + 0x18, h.at);
        put(u64, buffer, at + 0x20, h.size);
        put(u32, buffer, at + 0x28, h.link);
    }
    return buffer;
}

/// The names of the compared regions that differ, as the verdict lists them.
fn differingNames(c: Comparison, buffer: []u8) ![]const u8 {
    var w: std.Io.Writer = .fixed(buffer);
    for (c.results) |r| if (r.region.role == .compared and !r.equal) try w.print("{f};", .{r.region});
    return w.buffered();
}

const oso_a: TestSymbol = .{ .name = "/cache/o/0123456789abcdef/libcurl.o", .type = N_OSO, .sect = 0, .desc = 1, .value = 1_763_000_000 };
const oso_b: TestSymbol = .{ .name = "/cache/o/fedcba9876543210/libcurl.o", .type = N_OSO, .sect = 0, .desc = 1, .value = 1_763_000_999 };
const main_symbol: TestSymbol = .{ .name = "_main", .value = 0x100000400 };
const function_stab: TestSymbol = .{ .name = "_crane_run", .type = 0x24, .value = 0x100000410 };

test "the format is read from the magic: Mach-O 64, ELF64, or neither" {
    const macho = try testMachO(testing.allocator, .{});
    defer testing.allocator.free(macho);
    const elf = try testElf(testing.allocator, .{});
    defer testing.allocator.free(elf);
    try testing.expectEqual(Format.macho, formatOf(macho).?);
    try testing.expectEqual(Format.elf, formatOf(elf).?);
    try testing.expectEqual(@as(?Format, null), formatOf("#!/bin/sh\necho\n"));
    // A 32-bit ELF (class 1) is neither.
    try testing.expectEqual(@as(?Format, null), formatOf("\x7fELF\x01\x01\x01"));
    try testing.expectError(error.NotAnObjectFile, parse(testing.allocator, "not an executable"));
}

test "Mach-O: the regions are the header, each section, the symbol and string tables and the signature" {
    const bytes = try testMachO(testing.allocator, .{ .symbols = &.{ oso_a, main_symbol } });
    defer testing.allocator.free(bytes);
    var parsed = try parse(testing.allocator, bytes);
    defer parsed.deinit(testing.allocator);
    var names: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&names);
    for (parsed.regions) |r| try w.print("{f}:{t} ", .{ r, r.role });
    try testing.expectEqualStrings("header and load commands:compared __TEXT,__text:compared __DATA,__data:compared symbol table:by_entry string table:by_entry code signature:left_out ", w.buffered());
    // LC_UUID's sixteen bytes are masked in the header.
    try testing.expectEqual(@as(u64, 16), parsed.regions[0].mask.?.len);
    try testing.expectEqualSlices(u8, &@as([16]u8, @splat(0x11)), parsed.identity.?);
    try testing.expectEqual(@as(usize, 2), parsed.symbols.len);
    try testing.expect(parsed.symbols[0].debug_map_object);
    try testing.expectEqualStrings("_main", parsed.symbols[1].name);
}

test "Mach-O: two links of one program - another UUID, debug map and signature - are the same program" {
    const a = try testMachO(testing.allocator, .{ .uuid = @splat(0x11), .symbols = &.{ oso_a, main_symbol, function_stab }, .signature = "signature-one" });
    defer testing.allocator.free(a);
    const b = try testMachO(testing.allocator, .{ .uuid = @splat(0x99), .symbols = &.{ oso_b, main_symbol, function_stab }, .signature = "signature-two" });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(c.same());
    try testing.expect(c.total_differing > 0);
    try testing.expectEqual(@as(u64, 1), c.debug_map_objects);
    try testing.expectEqual(@as(u64, 1), c.debug_map_differing);
    try testing.expectEqual(@as(u64, 0), c.symbols_differing);

    var out: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&out);
    try report(&w, c);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "verdict: SAME PROGRAM") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "LC_UUID: 11111111111111111111111111111111 and 99999999999999999999999999999999 (differ, left out)") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "DIFFERS  code signature") != null);
}

test "Mach-O: one byte of code differs - the verdict names __TEXT,__text" {
    const a = try testMachO(testing.allocator, .{ .text = "\x1f\x20\x03\xd5\xc0\x03\x5f\xd6", .symbols = &.{main_symbol} });
    defer testing.allocator.free(a);
    const b = try testMachO(testing.allocator, .{ .text = "\x1f\x20\x03\xd5\xc0\x03\x5f\xd7", .symbols = &.{main_symbol} });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(!c.same());
    var names: [256]u8 = undefined;
    try testing.expectEqualStrings("__TEXT,__text;", try differingNames(c, &names));
    var out: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&out);
    try report(&w, c);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "verdict: DIFFERS - __TEXT,__text;\n") != null);
}

test "Mach-O: equal bytes at another address are another program" {
    const a = try testMachO(testing.allocator, .{ .data_address = 0x100008000 });
    defer testing.allocator.free(a);
    const b = try testMachO(testing.allocator, .{ .data_address = 0x10000c000 });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(!c.same());
    var names: [256]u8 = undefined;
    // The load command that holds the address differs too.
    try testing.expectEqualStrings("header and load commands;__DATA,__data;", try differingNames(c, &names));
}

test "Mach-O: a symbol outside the debug map with another value differs, by kind" {
    const moved: TestSymbol = .{ .name = "_crane_run", .type = 0x24, .value = 0x100000414 };
    const a = try testMachO(testing.allocator, .{ .symbols = &.{ oso_a, main_symbol, function_stab } });
    defer testing.allocator.free(a);
    const b = try testMachO(testing.allocator, .{ .symbols = &.{ oso_a, main_symbol, moved } });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(!c.same());
    try testing.expectEqual(@as(u64, 1), c.symbols_differing);
    try testing.expectEqualStrings("N_FUN", c.symbol_kinds[0].kind);
    try testing.expectEqualStrings("value", c.symbol_kinds[0].fields);
}

test "ELF: the allocated sections are compared, the build id and debug sections left out, the symbol table by entry" {
    const bytes = try testElf(testing.allocator, .{ .symbols = &.{main_symbol} });
    defer testing.allocator.free(bytes);
    var parsed = try parse(testing.allocator, bytes);
    defer parsed.deinit(testing.allocator);
    var names: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&names);
    for (parsed.regions) |r| try w.print("{f}:{t} ", .{ r, r.role });
    try testing.expectEqualStrings("ELF header:compared .note.gnu.build-id:left_out .text:compared .debug_info:left_out .symtab:by_entry .strtab:by_entry .shstrtab:left_out ", w.buffered());
    try testing.expectEqualSlices(u8, &@as([8]u8, @splat(0x22)), parsed.identity.?);
    // The null symbol, then _main.
    try testing.expectEqual(@as(usize, 2), parsed.symbols.len);
    try testing.expectEqualStrings("_main", parsed.symbols[1].name);
}

test "ELF: another build id and other debug information - longer, so the section headers move - are the same program" {
    const a = try testElf(testing.allocator, .{ .build_id = @splat(0x22), .debug_info = "debug information", .symbols = &.{main_symbol} });
    defer testing.allocator.free(a);
    const b = try testElf(testing.allocator, .{ .build_id = @splat(0x33), .debug_info = "other debug information, longer", .symbols = &.{main_symbol} });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(c.same());
    var out: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&out);
    try report(&w, c);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "build id: 2222222222222222 and 3333333333333333 (differ, left out)") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "verdict: SAME PROGRAM") != null);
}

test "ELF: the same symbols at other string table offsets are the same symbols" {
    const second: TestSymbol = .{ .name = "crane_run", .value = 0x201010, .size = 16 };
    const a = try testElf(testing.allocator, .{ .symbols = &.{ main_symbol, second } });
    defer testing.allocator.free(a);
    const b = try testElf(testing.allocator, .{ .symbols = &.{ main_symbol, second }, .reverse_strings = true });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(c.total_differing > 0);
    try testing.expectEqual(@as(u64, 0), c.symbols_differing);
    try testing.expect(c.same());
}

test "ELF: a byte of .text or a symbol's size differs - each is named" {
    const a = try testElf(testing.allocator, .{ .text = "\x55\x48\x89\xe5\xc3", .symbols = &.{main_symbol} });
    defer testing.allocator.free(a);
    const b = try testElf(testing.allocator, .{ .text = "\x55\x48\x89\xe5\xc2", .symbols = &.{main_symbol} });
    defer testing.allocator.free(b);
    var c = try compare(testing.allocator, a, b);
    defer c.deinit(testing.allocator);
    try testing.expect(!c.same());
    var names: [256]u8 = undefined;
    try testing.expectEqualStrings(".text;", try differingNames(c, &names));

    const bigger: TestSymbol = .{ .name = "_main", .value = 0x100000400, .size = 32 };
    const d = try testElf(testing.allocator, .{ .symbols = &.{bigger} });
    defer testing.allocator.free(d);
    var e = try compare(testing.allocator, a, d);
    defer e.deinit(testing.allocator);
    try testing.expect(!e.same());
    try testing.expectEqualStrings("size", e.symbol_kinds[0].fields);
}

test "a truncated file, and two files of different formats, are refused" {
    const macho = try testMachO(testing.allocator, .{ .symbols = &.{main_symbol} });
    defer testing.allocator.free(macho);
    const elf = try testElf(testing.allocator, .{});
    defer testing.allocator.free(elf);
    try testing.expectError(error.Truncated, parse(testing.allocator, macho[0 .. macho.len - 4]));
    try testing.expectError(error.Truncated, parse(testing.allocator, elf[0 .. elf.len - 64]));
    try testing.expectError(error.FormatsDiffer, compare(testing.allocator, macho, elf));
}

test "differing counts each differing position, the length difference and nothing in the mask" {
    try testing.expectEqual(@as(u64, 0), differing("abc", "abc", null));
    try testing.expectEqual(@as(u64, 1), differing("abc", "abd", null));
    try testing.expectEqual(@as(u64, 2), differing("abc", "abcde", null));
    try testing.expectEqual(@as(u64, 0), differing("abXYe", "abZWe", .{ .at = 2, .len = 2 }));
    try testing.expectEqual(@as(u64, 1), differing("abXYe", "abZWf", .{ .at = 2, .len = 2 }));
    // Past one chunk of the scan.
    const big_a = try testing.allocator.alloc(u8, 200_000);
    defer testing.allocator.free(big_a);
    const big_b = try testing.allocator.dupe(u8, big_a);
    defer testing.allocator.free(big_b);
    @memset(big_a, 7);
    @memset(big_b, 7);
    big_b[150_000] = 8;
    try testing.expectEqual(@as(u64, 1), differing(big_a, big_b, null));
}
