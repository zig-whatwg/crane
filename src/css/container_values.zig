//! CSS Conditional 5 sections 5.1–5.3: container names and types.
//! Query evaluation belongs to the container-query owner; these are values.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const serialize_mod = @import("serialize.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;

/// CSS Values custom-ident plus Conditional 5's four excluded names.
pub fn isName(name: []const u8) bool {
    for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer", "revert-rule", "default", "none", "and", "not", "or" }) |reserved|
        if (std.ascii.eqlIgnoreCase(name, reserved)) return false;
    return true;
}

pub fn consumeName(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const first = stream.peek();
    if (first.token_type == .ident and tokenizer.nameEql(first.value, "none")) {
        _ = stream.next();
        return Value.kw(.none);
    }
    const a = options.allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    while (stream.peek().token_type == .ident) {
        const token = stream.next();
        const decoded = try tokenizer.decode(a, token.value);
        defer a.free(decoded);
        if (!isName(decoded)) return null;
        const text = try serialize_mod.serializeIdentifier(a, decoded);
        defer a.free(text);
        if (out.items.len != 0) try out.append(a, ' ');
        try out.appendSlice(a, text);
    }
    if (out.items.len == 0) return null;
    return .{ .text = try values.SharedText.create(a, out.items) };
}

/// Conditional 5 §5.1 extended by Anchor Position 2 §2.1:
/// normal | [ [ size | inline-size ] || scroll-state || anchored ],
/// serialized in that canonical order (container-type-anchored-computed.html:
/// "anchored size" reads back as "size anchored", Chrome 3/3 - the one
/// browser shipping anchored).
pub fn consumeType(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const first = stream.peek();
    if (first.token_type == .ident and tokenizer.nameEql(first.value, "normal")) {
        _ = stream.next();
        return Value.kw(.normal);
    }
    var size: ?[]const u8 = null;
    var scroll_state = false;
    var anchored = false;
    while (stream.peek().token_type == .ident) {
        const token = stream.next();
        if (tokenizer.nameEql(token.value, "size") or tokenizer.nameEql(token.value, "inline-size")) {
            if (size != null) return null;
            size = if (tokenizer.nameEql(token.value, "size")) "size" else "inline-size";
        } else if (tokenizer.nameEql(token.value, "scroll-state")) {
            if (scroll_state) return null;
            scroll_state = true;
        } else if (tokenizer.nameEql(token.value, "anchored")) {
            if (anchored) return null;
            anchored = true;
        } else return null;
    }
    if (size == null and !scroll_state and !anchored) return null;
    // The longest: "inline-size scroll-state anchored".
    var buffer: [48]u8 = undefined;
    var text: std.ArrayList(u8) = .initBuffer(&buffer);
    for ([_]?[]const u8{ size, if (scroll_state) "scroll-state" else null, if (anchored) "anchored" else null }) |part| if (part) |word| {
        if (text.items.len != 0) text.appendAssumeCapacity(' ');
        text.appendSliceAssumeCapacity(word);
    };
    return .{ .text = try values.SharedText.create(options.allocator, text.items) };
}

/// The size container type a computed container-type names, if any.
pub const SizeType = enum { size, inline_size };

pub fn sizeType(value: Value) ?SizeType {
    if (value != .text) return null;
    const text = value.text.bytes;
    const word = text[0 .. std.mem.indexOfScalar(u8, text, ' ') orelse text.len];
    if (std.mem.eql(u8, word, "size")) return .size;
    if (std.mem.eql(u8, word, "inline-size")) return .inline_size;
    return null;
}

pub fn consume(options: properties.ParseOptions, longhand: properties.Longhand, stream: *Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .container_name => consumeName(options, stream),
        .container_type => consumeType(options, stream),
        else => unreachable,
    };
}

pub fn consumeShorthand(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    const name = try consumeName(options, stream) orelse return false;
    defer name.release();
    var kind = Value.kw(.normal);
    defer kind.release();
    const slash = stream.peek();
    if (slash.token_type == .delim and std.mem.eql(u8, slash.value, "/")) {
        _ = stream.next();
        kind = try consumeType(options, stream) orelse return false;
    }
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, 2);
    for (properties.Shorthand.container.longhands(), [_]Value{ name, kind }) |longhand, value| {
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeShorthand(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    try properties.serializeValue(.container_name, assigned[0].value, out, allocator);
    if (!assigned[1].value.isKeyword(.normal)) {
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.container_type, assigned[1].value, out, allocator);
    }
    return true;
}
