//! CSS Anchor Position 1 §6.6: the specified/computed visibility conditions.
//! This is value storage only; evaluating conditions belongs to layout.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const Stream = @import("properties.zig").Stream;

pub const Value = struct {
    anchor_valid: bool = false,
    anchor_visible: bool = false,
    no_overflow: bool = false,

    pub fn consume(stream: *Stream) ?Value {
        const first = stream.peek();
        if (first.token_type != .ident) return null;
        if (tokenizer.nameEql(first.value, "always")) {
            _ = stream.next();
            return .{};
        }
        var result: Value = .{};
        var any = false;
        while (stream.peek().token_type == .ident) {
            const name = stream.next().value;
            // Q30: the renamed singular keywords are canonical; preserve
            // acceptance of their plural spellings as legacy aliases.
            const field = if (tokenizer.nameEql(name, "anchor-valid") or tokenizer.nameEql(name, "anchors-valid"))
                &result.anchor_valid
            else if (tokenizer.nameEql(name, "anchor-visible") or tokenizer.nameEql(name, "anchors-visible"))
                &result.anchor_visible
            else if (tokenizer.nameEql(name, "no-overflow"))
                &result.no_overflow
            else
                return null;
            if (field.*) return null;
            field.* = true;
            any = true;
        }
        return if (any) result else null;
    }

    pub fn serialize(self: Value, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        if (!self.anchor_valid and !self.anchor_visible and !self.no_overflow)
            return out.appendSlice(allocator, "always");
        var separator = false;
        inline for (.{ "anchor_valid", "anchor_visible", "no_overflow" }, .{ "anchor-valid", "anchor-visible", "no-overflow" }) |field, name| {
            if (@field(self, field)) {
                if (separator) try out.append(allocator, ' ');
                try out.appendSlice(allocator, name);
                separator = true;
            }
        }
    }
};
