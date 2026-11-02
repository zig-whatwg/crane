//! The global-state part of the digest (state.zig), made from
//! lint-global-state's own inventory, tools/global_state_baseline.txt (build.zig
//! copies it beside this file): every process-global and threadlocal variable
//! in src/ by file and qualified name, with its class
//! (tmp/plans/instances-inventory.md). Nothing is listed by hand - a variable
//! the inventory gains or loses joins or leaves the digest with it.
//!
//! A variable is read only where it can be: its file under a module root the
//! test executable imports (`suite.roots`), a pub path from that root to its
//! file, and a pub declaration - Zig gives no way to read a private one from
//! another file, and @hasDecl answers false for it. Files under
//! src/webidl/impls/ and src/runtime/engines/ are never read: only an impl's
//! own interface may name it, and only the engine adapter names V8 (the impls
//! and engine boundaries). The P-const class (built once, lazily, under a
//! once) and the D class (diagnostic counters that only rise) are not
//! compared; H and P-res are what the process start makes (`start`); the
//! rest must be unchanged by a test (`held`).
//!
//! For each hook module of the inventory - a file with a variable of class H
//! or P-res - whose pub `isInstalled()` can be read, `hook <file>` is whether
//! its slot is installed.
//!
//! Resolution is comptime: an entry that cannot be read costs nothing at run
//! time. `readable` and `unreadable` count them, for the report.

const std = @import("std");
const suite = @import("suite.zig");
const state = @import("state.zig");

const baseline = @embedFile("global_state_baseline.txt");

pub const Entry = struct {
    path: []const u8,
    name: []const u8,
    kind: []const u8,
    class: []const u8,
};

/// Every Zig entry of the inventory (C++ variables cannot be read from Zig).
pub const entries: []const Entry = parse();

fn parse() []const Entry {
    @setEvalBranchQuota(10_000_000);
    comptime {
        var list: []const Entry = &.{};
        var lines = std.mem.tokenizeScalar(u8, baseline, '\n');
        while (lines.next()) |line| {
            if (line.len == 0 or line[0] == '#') continue;
            var cols = std.mem.tokenizeScalar(u8, line, ' ');
            const path = cols.next() orelse continue;
            const name = cols.next() orelse continue;
            _ = cols.next() orelse continue; // count
            const kind = cols.next() orelse continue;
            const class = cols.next() orelse continue;
            if (!std.mem.endsWith(u8, path, ".zig")) continue;
            list = list ++ [_]Entry{.{ .path = path, .name = name, .kind = kind, .class = class }};
        }
        return list;
    }
}

/// Where an entry's file sits: the container type of its file, through a pub
/// path from one of the executable's module roots; null where none reaches it.
fn fileContainer(comptime path: []const u8) ?type {
    comptime {
        if (std.mem.startsWith(u8, path, "src/webidl/impls/")) return null;
        if (std.mem.startsWith(u8, path, "src/runtime/engines/")) return null;
        // The longest root directory holding the file.
        var best_len: usize = 0;
        var best: ?type = null;
        for (suite.roots) |root| {
            const dir: []const u8 = root[0];
            if (std.mem.startsWith(u8, path, dir) and dir.len > best_len) {
                best_len = dir.len;
                best = root[1];
            }
        }
        var container = best orelse return null;
        const rest = path[best_len .. path.len - ".zig".len];
        var segments = std.mem.tokenizeScalar(u8, rest, '/');
        while (segments.next()) |segment| {
            // A directory's root.zig is the directory itself.
            if (std.mem.eql(u8, segment, "root") and segments.peek() == null) break;
            container = member(container, segment) orelse return null;
        }
        return container;
    }
}

/// `container.name` if it is a pub declaration holding a container type.
fn member(comptime container: type, comptime name: []const u8) ?type {
    comptime {
        if (!isContainer(container) or !@hasDecl(container, name)) return null;
        const value = @field(container, name);
        if (@TypeOf(value) != type or !isContainer(value)) return null;
        return value;
    }
}

fn isContainer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => true,
        else => false,
    };
}

/// The container that declares an entry's variable, and the variable's own
/// name: `Context.context_id_counter` is `context_id_counter` in the file's
/// pub `Context`. Null where any step is private or not there.
fn variableOf(comptime e: Entry) ?struct { type, []const u8 } {
    comptime {
        var container = fileContainer(e.path) orelse return null;
        var parts = std.mem.tokenizeScalar(u8, e.name, '.');
        var last = parts.next() orelse return null;
        while (parts.next()) |next| {
            container = member(container, last) orelse return null;
            last = next;
        }
        if (!isContainer(container) or !@hasDecl(container, last)) return null;
        // A pub `var`: a mutable pointer to it. A const of the same name
        // (or a function) is not a variable.
        const Ptr = @TypeOf(&@field(container, last));
        const info = @typeInfo(Ptr);
        if (info != .pointer or info.pointer.attrs.@"const") return null;
        if (!hashable(info.pointer.child)) return null;
        return .{ container, last };
    }
}

fn hashable(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"opaque", .type, .comptime_int, .comptime_float, .@"fn", .noreturn, .void, .null, .undefined, .enum_literal => false,
        else => @sizeOf(T) > 0,
    };
}

fn compared(comptime e: Entry) ?state.Kind {
    if (std.mem.eql(u8, e.class, "P-const") or std.mem.eql(u8, e.class, "D")) return null;
    if (std.mem.eql(u8, e.class, "H") or std.mem.eql(u8, e.class, "P-res")) return .start;
    return .held;
}

/// The inventory's entries this executable can read, and those it cannot.
pub const readable: usize = count(true);
pub const unreadable: usize = entries.len - readable;

fn count(comptime want: bool) usize {
    @setEvalBranchQuota(10_000_000);
    comptime var n: usize = 0;
    inline for (entries) |e| {
        if ((comptime variableOf(e) != null) == want) n += 1;
    }
    return n;
}

/// The hook modules: inventory files with an H or P-res variable.
const hook_files: []const []const u8 = hookFiles();

fn hookFiles() []const []const u8 {
    @setEvalBranchQuota(10_000_000);
    comptime {
        var list: []const []const u8 = &.{};
        for (entries) |e| {
            if (!std.mem.eql(u8, e.class, "H") and !std.mem.eql(u8, e.class, "P-res")) continue;
            for (list) |seen| {
                if (std.mem.eql(u8, seen, e.path)) break;
            } else list = list ++ [_][]const u8{e.path};
        }
        return list;
    }
}

/// The hook module at `path`, if it can be read and has a pub
/// `isInstalled() bool`.
fn hookModule(comptime path: []const u8) ?type {
    comptime {
        const container = fileContainer(path) orelse return null;
        if (!@hasDecl(container, "isInstalled")) return null;
        if (@TypeOf(container.isInstalled) != fn () bool) return null;
        return container;
    }
}

/// Put every readable variable and hook slot into `d`.
pub fn take(d: *state.Digest) void {
    @setEvalBranchQuota(10_000_000);
    inline for (entries) |e| {
        if (comptime compared(e)) |kind| {
            if (comptime variableOf(e)) |v| {
                d.put("global " ++ e.path ++ " " ++ e.name, kind, valueOf(&@field(v[0], v[1])));
            }
        }
    }
    inline for (hook_files) |path| {
        if (comptime hookModule(path)) |module| {
            d.put("hook " ++ path, .start, .{ .int = @intFromBool(module.isInstalled()) });
        }
    }
}

/// A scalar by its value; anything else by a hash of its bytes - a pointer,
/// a length or a count in it that changed changes the hash.
fn valueOf(ptr: anytype) state.Value {
    const T = @TypeOf(ptr.*);
    return switch (@typeInfo(T)) {
        .bool => .{ .int = @intFromBool(ptr.*) },
        .int => |info| if (info.bits > 64)
            .{ .hash = std.hash.Wyhash.hash(0, std.mem.asBytes(ptr)) }
        else if (info.signedness == .signed)
            .{ .int = ptr.* }
        else
            .{ .int = @bitCast(@as(u64, ptr.*)) },
        .@"enum" => |info| if (info.mode == .exhaustive) .{ .text = @tagName(ptr.*) } else .{ .hash = std.hash.Wyhash.hash(0, std.mem.asBytes(ptr)) },
        else => .{ .hash = std.hash.Wyhash.hash(0, std.mem.asBytes(ptr)) },
    };
}
