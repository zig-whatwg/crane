//! CSS Ruby 1 grammars that are more than one keyword: ruby-position
//! (§3.1) and ruby-overhang with its legacy value alias (§5.1). ruby-align
//! is a plain keyword longhand (properties.zig).
//!
//! Spec: https://drafts.csswg.org/css-ruby-1/#rubypos
//! Spec: https://drafts.csswg.org/css-ruby-1/#ruby-overhang
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Keyword = values.Keyword;
const Value = values.Value;
const Stream = properties.Stream;

/// The next token, when it is one of `allowed` (ASCII case-insensitively),
/// consumed.
fn keyword(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| {
        if (tokenizer.nameEql(token.value, candidate.name())) {
            _ = stream.next();
            return candidate;
        }
    }
    return null;
}

pub fn parse(longhand: properties.Longhand, stream: *Stream) ?Value {
    return switch (longhand) {
        .ruby_position => position(stream),
        .ruby_overhang => overhang(stream),
        else => unreachable,
    };
}

/// §3.1 ruby-position: [ alternate || [ over | under ] ] | inter-character.
/// "alternate, either on its own or in combination with over, behaves the
/// same as over" for a first level and alternates after it, so `alternate`
/// and `alternate over` are one value, serialized by its shortest form
/// (CSSOM §6.7.2's "shortest serialization"); `alternate under` is a pair.
/// Gecko serializes the same way (Stylo style/values/specified/text.rs
/// RubyPosition::to_css: AlternateOver is "alternate", AlternateUnder
/// "alternate under"). inter-character is the spec's and Safari's.
fn position(stream: *Stream) ?Value {
    if (keyword(stream, &.{.inter_character})) |k| return Value.kw(k);
    var alternate = false;
    var side: ?Keyword = null;
    for (0..2) |_| {
        if (!alternate) if (keyword(stream, &.{.alternate})) |_| {
            alternate = true;
            continue;
        };
        if (side == null) if (keyword(stream, &.{ .over, .under })) |k| {
            side = k;
            continue;
        };
        break;
    }
    if (!alternate) return if (side) |k| Value.kw(k) else null;
    if (side == .under) return .{ .box_keywords = .{ .first = .alternate, .second = .under } };
    return Value.kw(.alternate);
}

/// §5.1 ruby-overhang: auto | spaces. "user agents must support an
/// additional value of none for the ruby-overhang property, as a legacy
/// value alias of spaces" (Cascade 5 §3.2.2: it parses as spaces).
fn overhang(stream: *Stream) ?Value {
    const k = keyword(stream, &.{ .auto, .spaces, .none }) orelse return null;
    return Value.kw(if (k == .none) .spaces else k);
}
