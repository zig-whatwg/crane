//! CSS Contain 2 §2: typed containment flags, without layout execution.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const Stream = @import("properties.zig").Stream;

pub const Value = struct {
    size: enum { none, size, inline_size } = .none,
    layout: bool = false,
    style: bool = false,
    paint: bool = false,
    spelling: enum { components, strict, content } = .components,

    pub fn consume(stream: *Stream) ?Value {
        const first = stream.peek();
        if (first.token_type != .ident) return null;
        if (tokenizer.nameEql(first.value, "none")) {
            _ = stream.next();
            return .{};
        }
        const strict = tokenizer.nameEql(first.value, "strict");
        if (strict or tokenizer.nameEql(first.value, "content")) {
            _ = stream.next();
            return .{ .size = if (strict) .size else .none, .layout = true, .style = true, .paint = true, .spelling = if (strict) .strict else .content };
        }
        var result: Value = .{};
        var any = false;
        while (stream.peek().token_type == .ident) {
            const name = stream.next().value;
            const size = tokenizer.nameEql(name, "size");
            if (size or tokenizer.nameEql(name, "inline-size")) {
                if (result.size != .none) return null;
                result.size = if (size) .size else .inline_size;
            } else {
                const field = if (tokenizer.nameEql(name, "layout"))
                    &result.layout
                else if (tokenizer.nameEql(name, "style"))
                    &result.style
                else if (tokenizer.nameEql(name, "paint"))
                    &result.paint
                else
                    return null;
                if (field.*) return null;
                field.* = true;
            }
            any = true;
        }
        return if (any) result else null;
    }

    /// Contain 2 §2 computes aliases to their flag sets. CSSOM's shortest
    /// serialization uses strict/content for the corresponding full sets.
    pub fn computed(self: Value) Value {
        var result = self;
        result.spelling = if (self.layout and self.style and self.paint)
            switch (self.size) {
                .size => .strict,
                .none => .content,
                .inline_size => .components,
            }
        else
            .components;
        return result;
    }

    pub fn serialize(self: Value, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        switch (self.spelling) {
            .strict => return out.appendSlice(allocator, "strict"),
            .content => return out.appendSlice(allocator, "content"),
            .components => {},
        }
        if (self.size == .none and !self.layout and !self.style and !self.paint)
            return out.appendSlice(allocator, "none");
        var separator = false;
        if (self.size != .none) {
            try out.appendSlice(allocator, if (self.size == .size) "size" else "inline-size");
            separator = true;
        }
        inline for (.{ "layout", "style", "paint" }) |field| {
            if (@field(self, field)) {
                if (separator) try out.append(allocator, ' ');
                try out.appendSlice(allocator, field);
                separator = true;
            }
        }
    }
};
