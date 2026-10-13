//! URLPattern §2.3: generate and escape a pattern string.
const std = @import("std");
const parser = @import("parser.zig");
const regex_generator = @import("regex_generator.zig");
const identifiers = @import("url").infra.unicode_identifiers;
const Allocator = std.mem.Allocator;

fn appendEscaped(allocator: Allocator, result: *std.ArrayList(u8), input: []const u8) !void {
    // Escape a pattern string, step 4.3. These escapes belong to the pattern
    // grammar, independently of regular-expression escaping.
    for (input) |c| {
        if (std.mem.indexOfScalar(u8, "+*?:{}()\\", c) != null) try result.append(allocator, '\\');
        try result.append(allocator, c);
    }
}

pub fn escape(allocator: Allocator, input: []const u8) Allocator.Error![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try appendEscaped(allocator, &result, input);
    return result.toOwnedSlice(allocator);
}

fn beginsNameContinuation(input: []const u8) bool {
    if (input.len == 0) return false;
    const len = std.unicode.utf8ByteSequenceLength(input[0]) catch return false;
    if (len > input.len) return false;
    const cp = std.unicode.utf8Decode(input[0..len]) catch return false;
    return identifiers.isIdentifierPart(cp);
}

fn hasCustomName(part: parser.Part) bool {
    return part.name.len > 0 and !std.ascii.isDigit(part.name[0]);
}

pub fn generate(allocator: Allocator, parts: []const parser.Part, options: parser.Options) Allocator.Error![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    for (parts, 0..) |part, index| {
        const previous: ?parser.Part = if (index > 0) parts[index - 1] else null;
        const next: ?parser.Part = if (index + 1 < parts.len) parts[index + 1] else null;

        // Step 3.4: a modifier on fixed text needs a braced group.
        if (part.type == .fixed_text) {
            if (part.modifier != .none) try result.append(allocator, '{');
            try appendEscaped(allocator, &result, part.value);
            if (part.modifier != .none) try result.append(allocator, '}');
            try result.appendSlice(allocator, part.modifier.toString());
            continue;
        }

        // Steps 3.5-3.8: preserve both the part's affixes and its boundaries
        // with adjacent names, regexps and automatic prefixes.
        const custom_name = hasCustomName(part);
        var grouping = part.suffix.len > 0 or
            (part.prefix.len > 0 and !std.mem.eql(u8, part.prefix, options.prefix_code_point));
        if (!grouping and custom_name and part.type == .segment_wildcard and part.modifier == .none) {
            if (next) |n| {
                if (n.prefix.len == 0 and n.suffix.len == 0) grouping = if (n.type == .fixed_text)
                    beginsNameContinuation(n.value)
                else
                    !hasCustomName(n);
            }
        }
        if (!grouping and part.prefix.len == 0 and options.prefix_code_point.len > 0) {
            if (previous) |p| {
                if (p.type == .fixed_text and std.mem.endsWith(u8, p.value, options.prefix_code_point)) grouping = true;
            }
        }
        if (grouping) try result.append(allocator, '{');
        try appendEscaped(allocator, &result, part.prefix);
        if (custom_name) {
            try result.append(allocator, ':');
            try result.appendSlice(allocator, part.name);
        }

        // Steps 3.13-3.15: an unnamed wildcard cannot become a modifier on
        // the preceding part; unnamed segment wildcards use their regexp.
        switch (part.type) {
            .fixed_text => unreachable,
            .regexp => {
                try result.append(allocator, '(');
                try result.appendSlice(allocator, part.value);
                try result.append(allocator, ')');
            },
            .segment_wildcard => if (!custom_name) {
                const regexp = try regex_generator.generateSegmentWildcardRegexp(allocator, options);
                defer allocator.free(regexp);
                try result.append(allocator, '(');
                try result.appendSlice(allocator, regexp);
                try result.append(allocator, ')');
            },
            .full_wildcard => {
                const bare = !custom_name and (previous == null or previous.?.type == .fixed_text or
                    previous.?.modifier != .none or grouping or part.prefix.len > 0);
                try result.appendSlice(allocator, if (bare) "*" else "(.*)");
            },
        }

        // Steps 3.16-3.19: keep an identifier-like suffix out of the name.
        if (part.type == .segment_wildcard and custom_name and beginsNameContinuation(part.suffix))
            try result.append(allocator, '\\');
        try appendEscaped(allocator, &result, part.suffix);
        if (grouping) try result.append(allocator, '}');
        try result.appendSlice(allocator, part.modifier.toString());
    }
    return result.toOwnedSlice(allocator);
}
