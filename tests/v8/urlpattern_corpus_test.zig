//! The upstream URLPattern vectors (tests/wpt/urlpattern/resources/
//! urlpatterntestdata.json, the data urlpatterntests.js runs) against Crane's
//! URLPattern in a realm: construction compiles each component's regexp and
//! matching runs it, through engine.regExpCreateCheck and
//! engine.regExpBuiltinExecCaptures. Written by Codex row 26 against the
//! native algorithms (286 of 369 passed on the PCRE-named mock, whose
//! handwritten matcher had no backtracking, ignore case, Unicode sets or
//! validation); moved here, where there is an engine, by lane regexop.
//!
//! What it checks per vector, as urlpatterntests.js does: a TypeError
//! ("error") from the constructor, each compiled pattern string, test() and
//! exec() agreeing, and each component result's input and groups - an
//! undefined group (JSON null) apart from "". WPT stays the end-to-end check
//! (the binding's `inputs` and the JS values).
const std = @import("std");
const up = @import("urlpattern");
const url = @import("url");
const harness = @import("urlpattern_realm.zig");
const A = std.testing.allocator;
const Value = std.json.Value;
const names = .{ "protocol", "username", "password", "hostname", "port", "pathname", "search", "hash" };

fn get(value: Value, key: []const u8) ?Value {
    return if (value == .object) value.object.get(key) else null;
}
fn string(value: ?Value) ?[]const u8 {
    const v = value orelse return null;
    return if (v == .string) v.string else null;
}
fn isError(value: ?Value) bool {
    return if (string(value)) |s| std.mem.eql(u8, s, "error") else false;
}
fn initFrom(value: Value) up.URLPatternInit {
    var result: up.URLPatternInit = .{};
    inline for (names) |name| @field(result, name) = string(get(value, name));
    result.base_url = string(get(value, "baseURL"));
    return result;
}
fn construct(realm: up.Realm, args: []const Value) !up.URLPattern {
    const input: up.Input = if (args.len == 0) .{ .init = .{} } else if (args[0] == .string)
        .{ .string = args[0].string }
    else
        .{ .init = initFrom(args[0]) };
    var options: up.URLPatternOptions = .{};
    var base: ?[]const u8 = null;
    if (args.len > 2 and args[2] != .object and args[2] != .null) return error.InvalidPattern;
    for (args[if (args.len > 0) @as(usize, 1) else 0..]) |arg| {
        if (arg == .string) base = arg.string;
        if (get(arg, "ignoreCase")) |v| options.ignore_case = v.bool;
    }
    return up.URLPattern.createWithBase(A, realm, input, base, options);
}
fn exactlyEmpty(entry: Value, name: []const u8) bool {
    if (get(entry, "exactly_empty_components")) |v| {
        for (v.array.items) |item| if (std.mem.eql(u8, item.string, name)) return true;
    }
    return false;
}
fn expectedPattern(entry: Value, comptime name: []const u8) ![]const u8 {
    if (string(get(get(entry, "expected_obj") orelse .null, name))) |s| return A.dupe(u8, s);
    if (exactlyEmpty(entry, name)) return A.dupe(u8, "");
    const args = get(entry, "pattern").?.array.items;
    const first: Value = if (args.len > 0) args[0] else .null;
    if (string(get(first, name))) |s| if (s.len > 0) return A.dupe(u8, s);
    const earlier = if (comptime std.mem.eql(u8, name, "hostname")) .{"protocol"} else if (comptime std.mem.eql(u8, name, "port")) .{ "protocol", "hostname" } else if (comptime std.mem.eql(u8, name, "pathname")) .{ "protocol", "hostname", "port" } else if (comptime std.mem.eql(u8, name, "search")) .{ "protocol", "hostname", "port", "pathname" } else if (comptime std.mem.eql(u8, name, "hash")) .{ "protocol", "hostname", "port", "pathname", "search" } else .{};
    inline for (earlier) |previous| if (get(first, previous) != null) return A.dupe(u8, "*");
    const base = string(get(first, "baseURL")) orelse if (args.len > 1) string(args[1]) else null;
    if (base) |b| {
        if (comptime !std.mem.eql(u8, name, "username") and !std.mem.eql(u8, name, "password")) {
            var record = try url.parser.basic_url_parser.parse(A, b, null);
            defer record.deinit();
            if (comptime std.mem.eql(u8, name, "protocol")) return A.dupe(u8, record.scheme());
            if (comptime std.mem.eql(u8, name, "hostname")) return if (record.host) |h| url.host_serializer.serializeHost(A, h) else A.dupe(u8, "");
            if (comptime std.mem.eql(u8, name, "port")) return if (record.port) |p| std.fmt.allocPrint(A, "{d}", .{p}) else A.dupe(u8, "");
            if (comptime std.mem.eql(u8, name, "search")) return A.dupe(u8, record.query() orelse "");
            if (comptime std.mem.eql(u8, name, "hash")) return A.dupe(u8, record.fragment() orelse "");
            if (comptime std.mem.eql(u8, name, "pathname")) {
                switch (record.path) {
                    .opaque_path => |p| return A.dupe(u8, p),
                    .segments => |segments| {
                        var list: std.ArrayList(u8) = .empty;
                        errdefer list.deinit(A);
                        for (segments.toSlice()) |s| {
                            try list.append(A, '/');
                            try list.appendSlice(A, s);
                        }
                        return list.toOwnedSlice(A);
                    },
                }
            }
        }
    }
    return A.dupe(u8, "*");
}
fn matchingInput(value: Value) up.URLPatternInput {
    if (value == .string) return .{ .string = value.string };
    var input: up.URLPatternInput = .{ .init = .{} };
    inline for (names) |name| @field(input.init, name) = string(get(value, name));
    input.init.baseURL = string(get(value, "baseURL"));
    return input;
}
fn compare(realm: up.Realm, entry: Value, index: usize) !bool {
    const args = get(entry, "pattern").?.array.items;
    var pattern = construct(realm, args) catch |err| {
        if (isError(get(entry, "expected_obj"))) return true;
        std.debug.print("UPCASE\t{d}\tconstructor\t{s}\n", .{ index, @errorName(err) });
        return false;
    };
    defer pattern.deinit(A);
    if (isError(get(entry, "expected_obj"))) {
        std.debug.print("UPCASE\t{d}\tconstructor-accepted\n", .{index});
        return false;
    }
    var passed = true;
    inline for (names) |name| {
        const expected = try expectedPattern(entry, name);
        defer A.free(expected);
        if (!std.mem.eql(u8, expected, @field(pattern, name).pattern_string)) {
            std.debug.print("UPCASE\t{d}\tpattern-{s}\texpected={s}\tactual={s}\n", .{ index, name, expected, @field(pattern, name).pattern_string });
            passed = false;
        }
    }
    const inputs = if (get(entry, "inputs")) |v| v.array.items else &.{};
    const expected_match = get(entry, "expected_match") orelse .null;
    const input = matchingInput(if (inputs.len > 0) inputs[0] else .null);
    const base = if (inputs.len > 1) string(inputs[1]) else null;
    // test() is "match" is not null: the same answer as exec().
    const tested: ?bool = up.testMatchInput(A, realm, &pattern, input, base) catch |err| switch (err) {
        error.InvalidInput => null,
        else => return err,
    };
    var result = up.execInput(A, realm, &pattern, input, base) catch |err| {
        if (!isError(expected_match) and expected_match != .null) {
            std.debug.print("UPCASE\t{d}\texec-error\t{s}\n", .{ index, @errorName(err) });
            return false;
        }
        return passed;
    };
    defer if (result) |*r| r.deinit();
    if (isError(expected_match)) {
        std.debug.print("UPCASE\t{d}\texec-accepted\n", .{index});
        return false;
    }
    if ((result != null) != (expected_match == .object)) {
        std.debug.print("UPCASE\t{d}\tmatch\texpected={}\tactual={}\n", .{ index, expected_match == .object, result != null });
        return false;
    }
    if (tested == null or tested.? != (result != null)) {
        std.debug.print("UPCASE\t{d}\ttest-disagrees-with-exec\n", .{index});
        return false;
    }
    if (result) |r| inline for (names) |name| {
        const expected = get(expected_match, name);
        const component = @field(r, name);
        const expected_input = if (expected) |v| string(get(v, "input")) orelse "" else "";
        if (!std.mem.eql(u8, expected_input, component.input)) {
            std.debug.print("UPCASE\t{d}\tinput-{s}\texpected={s}\tactual={s}\n", .{ index, name, expected_input, component.input });
            passed = false;
        }
        const groups = if (expected) |v| get(v, "groups") else null;
        if (groups) |g| {
            if (component.groups.len != g.object.count()) {
                std.debug.print("UPCASE\t{d}\tgroups-{s}\tcount {d}/{d}\n", .{ index, name, component.groups.len, g.object.count() });
                passed = false;
            }
            var iter = g.object.iterator();
            while (iter.next()) |pair| {
                // JSON null is the harness's undefined: the group is there,
                // undefined - not absent, and not "".
                const actual = component.get(pair.key_ptr.*) orelse {
                    std.debug.print("UPCASE\t{d}\tgroup-{s}\t{s} missing\n", .{ index, name, pair.key_ptr.* });
                    passed = false;
                    continue;
                };
                if (pair.value_ptr.* == .null) {
                    if (actual.value != null) {
                        std.debug.print("UPCASE\t{d}\tgroup-{s}\t{s} not undefined\n", .{ index, name, pair.key_ptr.* });
                        passed = false;
                    }
                } else if (actual.value == null or !std.mem.eql(u8, actual.value.?, pair.value_ptr.string)) {
                    std.debug.print("UPCASE\t{d}\tgroup-{s}\t{s}\n", .{ index, name, pair.key_ptr.* });
                    passed = false;
                }
            }
        } else {
            const count: usize = if (exactlyEmpty(entry, name)) 0 else 1;
            const zero = component.get("0");
            if (component.groups.len != count or (count == 1 and (zero == null or zero.?.value == null or zero.?.value.?.len != 0))) {
                std.debug.print("UPCASE\t{d}\tgroups-{s}\tdefault\n", .{ index, name });
                passed = false;
            }
        }
    };
    return passed;
}

// JSON permits lone surrogate escapes; Zig's Unicode-scalar JSON reader does
// not. These vectors enter URLPattern as WebIDL USVStrings, which replace lone
// surrogates with U+FFFD. Preserve pairs and escaped backslashes verbatim.
fn jsonUSVStrings(bytes: []const u8) ![]u8 {
    const result = try A.dupe(u8, bytes);
    var i: usize = 0;
    while (i + 1 < bytes.len) {
        if (bytes[i] != '\\') {
            i += 1;
            continue;
        }
        if (bytes[i + 1] != 'u' or i + 6 > bytes.len) {
            i += 2;
            continue;
        }
        const unit = std.fmt.parseInt(u16, bytes[i + 2 ..][0..4], 16) catch {
            i += 6;
            continue;
        };
        if (unit >= 0xd800 and unit <= 0xdbff and i + 12 <= bytes.len and std.mem.eql(u8, bytes[i + 6 ..][0..2], "\\u")) {
            const low = std.fmt.parseInt(u16, bytes[i + 8 ..][0..4], 16) catch 0;
            if (low >= 0xdc00 and low <= 0xdfff) {
                i += 12;
                continue;
            }
        }
        if (unit >= 0xd800 and unit <= 0xdfff) @memcpy(result[i + 2 ..][0..4], "fffd");
        i += 6;
    }
    return result;
}

test "URLPattern upstream JSON corpus" {
    const page = try harness.Page.open();
    defer page.close();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "tests/wpt/urlpattern/resources/urlpatterntestdata.json", A, .limited(2 << 20));
    defer A.free(bytes);
    const scalar_json = try jsonUSVStrings(bytes);
    defer A.free(scalar_json);
    const parsed = try std.json.parseFromSlice(Value, A, scalar_json, .{});
    defer parsed.deinit();
    var failed: usize = 0;
    for (parsed.value.array.items, 0..) |entry, i| {
        if (!try compare(page.realm, entry, i)) failed += 1;
    }
    std.debug.print("URLPattern native corpus: {d}/{d} passed\n", .{ parsed.value.array.items.len - failed, parsed.value.array.items.len });
    try std.testing.expectEqual(@as(usize, 0), failed);
}
