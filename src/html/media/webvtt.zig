//! WebVTT file parsing (WebVTT, W3C Editor's Draft, specs/w3c/webvtt.md):
//! 6.1 the WebVTT parser algorithm, 6.2 region settings, 6.3 cue timings and
//! settings - what HTML's out-of-band text track processing passes a <track>
//! element's resource to (HTML 4.8.11.11.3 step 10: "the resource's data
//! must be passed to the appropriate parser (e.g., the WebVTT parser)").
//!
//! The parser runs over the whole resource once it has arrived, not
//! incrementally (6.1: an incremental parser is what one "typically" runs):
//! the result is the same; only when a cue becomes visible during the
//! download differs, which nothing observes without a renderer.
//!
//! The output is plain data - the WebVTT cues (their identifier, times,
//! settings and raw cue text), the regions, and each STYLE block's CSS text.
//! Cue text stays text: the WebVTT cue text parsing rules (6.4,
//! `parseCueText`) run when a cue's DOM fragment is asked for, not here.

const std = @import("std");
const Allocator = std.mem.Allocator;
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const sniffing = @import("html_core").parser.encoding_sniffing;
const entities = @import("html_core").parser.entities;

/// WebVTT cue writing direction.
pub const WritingDirection = enum { horizontal, vertical_growing_left, vertical_growing_right };
/// WebVTT cue line alignment.
pub const LineAlignment = enum { start, center, end };
/// WebVTT cue position alignment.
pub const PositionAlignment = enum { line_left, center, line_right, auto };
/// WebVTT cue text alignment.
pub const TextAlignment = enum { start, center, end, left, right };
/// WebVTT cue line: auto, or a number (a line number when the cue's
/// snap-to-lines flag is set, a percentage otherwise).
pub const Line = union(enum) { auto, number: f64 };
/// WebVTT cue position: auto, or a percentage.
pub const Position = union(enum) { auto, number: f64 };

/// A WebVTT cue, as cue creation (6.1, "collect a WebVTT block" step 11.4.1.3)
/// initializes it and its timings and settings set it. Strings are the
/// result's.
pub const Cue = struct {
    /// Text track cue identifier.
    identifier: []const u8 = "",
    /// Text track cue start and end times, in seconds.
    start_time: f64 = 0,
    end_time: f64 = 0,
    /// Text track cue pause-on-exit flag.
    pause_on_exit: bool = false,
    /// WebVTT cue region: an index into the result's regions, or null.
    region: ?usize = null,
    writing_direction: WritingDirection = .horizontal,
    snap_to_lines: bool = true,
    line: Line = .auto,
    line_alignment: LineAlignment = .start,
    position: Position = .auto,
    position_alignment: PositionAlignment = .auto,
    size: f64 = 100,
    text_alignment: TextAlignment = .center,
    /// The cue text, unparsed.
    text: []const u8 = "",
};

/// WebVTT region scroll value.
pub const Scroll = enum { none, up };

/// A WebVTT region (6.1 "region creation", then 6.2's settings).
pub const Region = struct {
    identifier: []const u8 = "",
    /// A percentage.
    width: f64 = 100,
    /// VTTRegion's `lines` is an unsigned long: a larger number saturates.
    lines: u32 = 3,
    /// Percentages (x, y).
    anchor: [2]f64 = .{ 0, 100 },
    viewport_anchor: [2]f64 = .{ 0, 100 },
    scroll: Scroll = .none,
};

/// What the parser made of a resource. Everything in it is the arena's.
pub const Result = struct {
    arena: std.heap.ArenaAllocator,
    /// Whether the file was successfully processed (6.1: it starts with the
    /// WebVTT file signature). A file that was not is HTML's "failed to load".
    processed: bool,
    /// The text track list of cues the parser added to, in file order.
    cues: []const Cue,
    /// The text track list of regions.
    regions: []const Region,
    /// Each STYLE block's CSS text, in file order (6.1 step 13: "Parse a
    /// stylesheet from buffer" - kept as text for whoever builds the style
    /// sheets).
    stylesheets: []const []const u8,

    pub fn deinit(self: *Result) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

/// The WebVTT parser (6.1), given the resource's bytes.
pub fn parse(allocator: Allocator, bytes: []const u8) !Result {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser: Parser = .{ .allocator = a, .input = try preprocess(a, bytes) };
    const processed = try parser.run();
    return .{
        .arena = arena,
        .processed = processed,
        .cues = parser.cues.items,
        .regions = parser.regions.items,
        .stylesheets = parser.stylesheets.items,
    };
}

/// 6.1: "decode the byte stream using the UTF-8 decode algorithm", then step
/// 1's transformations: U+0000 becomes U+FFFD, CRLF and every remaining CR
/// become LF.
fn preprocess(allocator: Allocator, bytes: []const u8) ![]const u8 {
    const decoded = try sniffing.utf8Decode(allocator, bytes);
    var out: std.ArrayListUnmanaged(u8) = .empty;
    try out.ensureTotalCapacity(allocator, decoded.len);
    var i: usize = 0;
    while (i < decoded.len) : (i += 1) {
        switch (decoded[i]) {
            0 => try out.appendSlice(allocator, "\u{FFFD}"),
            '\r' => {
                try out.append(allocator, '\n');
                if (i + 1 < decoded.len and decoded[i + 1] == '\n') i += 1;
            },
            else => |c| try out.append(allocator, c),
        }
    }
    return out.items;
}

const Parser = struct {
    allocator: Allocator,
    /// The preprocessed input, UTF-8. Every character the algorithms look at
    /// is ASCII, so they walk bytes.
    input: []const u8,
    position: usize = 0,
    /// 6.1 step 3.
    seen_cue: bool = false,
    cues: std.ArrayListUnmanaged(Cue) = .empty,
    /// 6.1 step 13's text track list of regions.
    regions: std.ArrayListUnmanaged(Region) = .empty,
    stylesheets: std.ArrayListUnmanaged([]const u8) = .empty,

    fn atEnd(self: *const Parser) bool {
        return self.position >= self.input.len;
    }

    /// Infra "collect a sequence of code points" that are not LF.
    fn collectLine(self: *Parser) []const u8 {
        const start = self.position;
        while (self.position < self.input.len and self.input[self.position] != '\n') self.position += 1;
        return self.input[start..self.position];
    }

    /// Infra "collect a sequence of code points" that are LF.
    fn skipLineFeeds(self: *Parser) void {
        while (self.position < self.input.len and self.input[self.position] == '\n') self.position += 1;
    }

    /// The WebVTT parser algorithm (6.1). True when the file was
    /// successfully processed.
    fn run(self: *Parser) Allocator.Error!bool {
        const input = self.input;
        // 4. Fewer than six characters: no WebVTT file signature.
        if (input.len < 6) return false;
        // 5. Exactly six, not "WEBVTT".
        if (input.len == 6 and !std.mem.eql(u8, input, "WEBVTT")) return false;
        // 6. More than six: "WEBVTT" followed by a space, a tab or an LF.
        if (input.len > 6) {
            if (!std.mem.eql(u8, input[0..6], "WEBVTT")) return false;
            switch (input[6]) {
                ' ', '\t', '\n' => {},
                else => return false,
            }
        }
        // 7. The rest of the signature line.
        _ = self.collectLine();
        // 8. Past the end: processed, with no cues.
        if (self.atEnd()) return true;
        // 9. An LF: advance past it.
        self.position += 1;
        // 10. Past the end: processed, with no cues.
        if (self.atEnd()) return true;
        // 11. Header: a block with the "in header" flag set, unless the line
        // is empty.
        if (input[self.position] != '\n') {
            _ = try self.collectBlock(true);
        } else {
            self.position += 1;
        }
        // 12.
        self.skipLineFeeds();
        // 13. regions: the parser's list, empty so far.
        // 14. Block loop.
        while (!self.atEnd()) {
            // 14.1.
            const block = try self.collectBlock(false);
            switch (block) {
                // 14.2.
                .cue => |cue| try self.cues.append(self.allocator, cue),
                // 14.3.
                .stylesheet => |css| try self.stylesheets.append(self.allocator, css),
                // 14.4.
                .region => |region| try self.regions.append(self.allocator, region),
                .none => {},
            }
            // 14.5.
            self.skipLineFeeds();
        }
        // 15. End: processed.
        return true;
    }

    const Block = union(enum) { none, cue: Cue, stylesheet: []const u8, region: Region };

    /// "Collect a WebVTT block", optionally with the "in header" flag set.
    fn collectBlock(self: *Parser, in_header: bool) Allocator.Error!Block {
        // 2-10.
        var line_count: usize = 0;
        var previous_position = self.position;
        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        var seen_eof = false;
        var seen_arrow = false;
        var cue: ?Cue = null;
        var stylesheet = false;
        var region: ?Region = null;
        // 11. Loop.
        while (true) {
            // 11.1.
            const line = self.collectLine();
            // 11.2.
            line_count += 1;
            // 11.3.
            if (self.atEnd()) {
                seen_eof = true;
            } else {
                self.position += 1;
            }
            if (std.mem.indexOf(u8, line, "-->") != null) {
                // 11.4.1: a timing line opens a cue only outside the header,
                // as its first line or as its second after an identifier.
                if (!in_header and (line_count == 1 or (line_count == 2 and !seen_arrow))) {
                    // 11.4.1.1-2.
                    seen_arrow = true;
                    previous_position = self.position;
                    // 11.4.1.3. Cue creation: the identifier is the buffer;
                    // every other member takes its initial value (Cue's
                    // defaults).
                    var made: Cue = .{ .identifier = try self.allocator.dupe(u8, buffer.items) };
                    // 11.4.1.4.
                    if (try self.collectTimingsAndSettings(line, &made)) {
                        cue = made;
                        buffer.clearRetainingCapacity();
                        self.seen_cue = true;
                    } else {
                        cue = null;
                    }
                } else {
                    // Otherwise: the line belongs to the next block.
                    self.position = previous_position;
                    break;
                }
            } else if (line.len == 0) {
                // 11.5.
                break;
            } else {
                // 11.6.1: a STYLE or REGION block, recognized on its second
                // line, before any cue.
                if (!in_header and line_count == 2) {
                    if (!self.seen_cue and startsWithKeyword(buffer.items, "STYLE")) {
                        // 11.6.1.1: a CSS style sheet with no location, no
                        // parent, owner node or owner rule, empty media and
                        // title, unset alternate flag, set origin-clean flag
                        // - here, its text (step 13).
                        stylesheet = true;
                        // 11.6.1.2.
                        buffer.clearRetainingCapacity();
                    } else if (!self.seen_cue and startsWithKeyword(buffer.items, "REGION")) {
                        // 11.6.1.2.1-7: region creation, Region's defaults.
                        region = .{};
                        // 11.6.1.2.8.
                        buffer.clearRetainingCapacity();
                    }
                }
                // 11.6.2.
                if (buffer.items.len != 0) try buffer.append(self.allocator, '\n');
                // 11.6.3.
                try buffer.appendSlice(self.allocator, line);
                // 11.6.4.
                previous_position = self.position;
            }
            // 11.7.
            if (seen_eof) break;
        }
        // 12. A cue: its cue text is the buffer.
        if (cue) |*made| {
            made.text = try buffer.toOwnedSlice(self.allocator);
            return .{ .cue = made.* };
        }
        // 13. A style sheet: the buffer is its CSS.
        if (stylesheet) return .{ .stylesheet = try buffer.toOwnedSlice(self.allocator) };
        // 14. A region: its settings from the buffer.
        if (region) |*r| {
            try self.collectRegionSettings(buffer.items, r);
            return .{ .region = r.* };
        }
        // 15.
        return .none;
    }

    /// 6.2 "collect WebVTT region settings" from `input` into `region`.
    fn collectRegionSettings(self: *Parser, input: []const u8, region: *Region) Allocator.Error!void {
        // 1. Split on ASCII whitespace.
        var settings = std.mem.tokenizeAny(u8, input, ascii_whitespace);
        // 2.
        while (settings.next()) |setting| {
            // 2.1-2.3.
            const split = nameValue(setting) orelse continue;
            const name = split[0];
            const value = split[1];
            // 2.4.
            if (std.mem.eql(u8, name, "id")) {
                region.identifier = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, name, "width")) {
                if (parsePercentage(value)) |percentage| region.width = percentage;
            } else if (std.mem.eql(u8, name, "lines")) {
                if (!allDigits(value)) continue;
                region.lines = std.fmt.parseInt(u32, value, 10) catch std.math.maxInt(u32);
            } else if (std.mem.eql(u8, name, "regionanchor")) {
                region.anchor = parseAnchor(value) orelse continue;
            } else if (std.mem.eql(u8, name, "viewportanchor")) {
                region.viewport_anchor = parseAnchor(value) orelse continue;
            } else if (std.mem.eql(u8, name, "scroll")) {
                if (std.mem.eql(u8, value, "up")) region.scroll = .up;
            }
            // 2.5. Next setting.
        }
    }

    /// 6.3 "collect WebVTT cue timings and settings" from `input` for
    /// `cue`. False is failure.
    fn collectTimingsAndSettings(self: *const Parser, input: []const u8, cue: *Cue) Allocator.Error!bool {
        // 2.
        var position: usize = 0;
        // 3.
        skipWhitespace(input, &position);
        // 4.
        cue.start_time = collectTimestamp(input, &position) orelse return false;
        // 5.
        skipWhitespace(input, &position);
        // 6-8. "-->".
        if (!std.mem.startsWith(u8, input[position..], "-->")) return false;
        position += 3;
        // 9.
        skipWhitespace(input, &position);
        // 10.
        cue.end_time = collectTimestamp(input, &position) orelse return false;
        // 11-12.
        self.parseCueSettings(input[position..], cue);
        return true;
    }

    /// 6.3 "parse the WebVTT cue settings" from `input` for `cue`.
    fn parseCueSettings(self: *const Parser, input: []const u8, cue: *Cue) void {
        // 1.
        var settings = std.mem.tokenizeAny(u8, input, ascii_whitespace);
        // 2.
        while (settings.next()) |setting| {
            // 2.1-2.3.
            const split = nameValue(setting) orelse continue;
            const name = split[0];
            const value = split[1];
            // 2.4.
            if (std.mem.eql(u8, name, "region")) {
                // The last region whose identifier is value, or null.
                cue.region = null;
                var i = self.regions.items.len;
                while (i > 0) {
                    i -= 1;
                    if (std.mem.eql(u8, self.regions.items[i].identifier, value)) {
                        cue.region = i;
                        break;
                    }
                }
            } else if (std.mem.eql(u8, name, "vertical")) {
                if (std.mem.eql(u8, value, "rl")) {
                    cue.writing_direction = .vertical_growing_left;
                } else if (std.mem.eql(u8, value, "lr")) {
                    cue.writing_direction = .vertical_growing_right;
                }
                // 3. No vertical regions.
                if (cue.writing_direction != .horizontal) cue.region = null;
            } else if (std.mem.eql(u8, name, "line")) {
                // 1-2.
                const comma = std.mem.indexOfScalar(u8, value, ',');
                const linepos = if (comma) |c| value[0..c] else value;
                const linealign: ?[]const u8 = if (comma) |c| value[c + 1 ..] else null;
                // 3.
                if (std.mem.indexOfAny(u8, linepos, "0123456789") == null) continue;
                // 4.
                const percent = linepos[linepos.len - 1] == '%';
                const number: f64 = if (percent)
                    parsePercentage(linepos) orelse continue
                else
                    parseLineNumber(linepos) orelse continue;
                // 5-8.
                var alignment = cue.line_alignment;
                if (linealign) |la| {
                    if (std.mem.eql(u8, la, "start")) {
                        alignment = .start;
                    } else if (std.mem.eql(u8, la, "center")) {
                        alignment = .center;
                    } else if (std.mem.eql(u8, la, "end")) {
                        alignment = .end;
                    } else continue;
                }
                cue.line_alignment = alignment;
                // 9.
                cue.line = .{ .number = number };
                // 10.
                cue.snap_to_lines = !percent;
                // 11. An explicit line drops the cue out of its region.
                cue.region = null;
            } else if (std.mem.eql(u8, name, "position")) {
                // 1-2.
                const comma = std.mem.indexOfScalar(u8, value, ',');
                const colpos = if (comma) |c| value[0..c] else value;
                const colalign: ?[]const u8 = if (comma) |c| value[c + 1 ..] else null;
                // 3.
                const number = parsePercentage(colpos) orelse continue;
                // 4-7.
                var alignment = cue.position_alignment;
                if (colalign) |ca| {
                    if (std.mem.eql(u8, ca, "line-left")) {
                        alignment = .line_left;
                    } else if (std.mem.eql(u8, ca, "center")) {
                        alignment = .center;
                    } else if (std.mem.eql(u8, ca, "line-right")) {
                        alignment = .line_right;
                    } else continue;
                }
                cue.position_alignment = alignment;
                // 8.
                cue.position = .{ .number = number };
            } else if (std.mem.eql(u8, name, "size")) {
                // 1.
                const number = parsePercentage(value) orelse continue;
                // 2.
                cue.size = number;
                // 3. An explicit size drops the cue out of its region.
                if (number != 100) cue.region = null;
            } else if (std.mem.eql(u8, name, "align")) {
                if (std.mem.eql(u8, value, "start")) {
                    cue.text_alignment = .start;
                } else if (std.mem.eql(u8, value, "center")) {
                    cue.text_alignment = .center;
                } else if (std.mem.eql(u8, value, "end")) {
                    cue.text_alignment = .end;
                } else if (std.mem.eql(u8, value, "left")) {
                    cue.text_alignment = .left;
                } else if (std.mem.eql(u8, value, "right")) {
                    cue.text_alignment = .right;
                }
            }
            // 2.5. Next setting.
        }
    }
};

/// HTML's ASCII whitespace.
const ascii_whitespace = " \t\n\x0c\r";

/// Whether `buffer` is `keyword` followed only by ASCII whitespace (6.1,
/// "collect a WebVTT block" 11.6.1.1 and 11.6.1.2).
fn startsWithKeyword(buffer: []const u8, keyword: []const u8) bool {
    if (!std.mem.startsWith(u8, buffer, keyword)) return false;
    for (buffer[keyword.len..]) |c| {
        if (std.mem.indexOfScalar(u8, ascii_whitespace, c) == null) return false;
    }
    return true;
}

/// 6.2 / 6.3 settings steps 2.1-2.3: a setting's name and value, split at its
/// first colon - or null when it has none, or the colon is its first or last
/// character.
fn nameValue(setting: []const u8) ?[2][]const u8 {
    const colon = std.mem.indexOfScalar(u8, setting, ':') orelse return null;
    if (colon == 0 or colon == setting.len - 1) return null;
    return .{ setting[0..colon], setting[colon + 1 ..] };
}

fn allDigits(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

/// HTML "skip ASCII whitespace".
fn skipWhitespace(input: []const u8, position: *usize) void {
    while (position.* < input.len and std.mem.indexOfScalar(u8, ascii_whitespace, input[position.*]) != null) position.* += 1;
}

/// Infra "collect a sequence of code points" that are ASCII digits.
fn collectDigits(input: []const u8, position: *usize) []const u8 {
    const start = position.*;
    while (position.* < input.len and std.ascii.isDigit(input[position.*])) position.* += 1;
    return input[start..position.*];
}

/// "The rules to parse a percentage string" (6.2): a number in 0..100, or
/// null.
pub fn parsePercentage(input: []const u8) ?f64 {
    // 2. The WebVTT percentage syntax: digits, optionally "." and digits,
    // then "%".
    var i: usize = 0;
    while (i < input.len and std.ascii.isDigit(input[i])) i += 1;
    if (i == 0) return null;
    if (i < input.len and input[i] == '.') {
        i += 1;
        const fraction_start = i;
        while (i < input.len and std.ascii.isDigit(input[i])) i += 1;
        if (i == fraction_start) return null;
    }
    if (i + 1 != input.len or input[i] != '%') return null;
    // 3-4. Without the "%", by HTML's rules for parsing floating-point
    // number values.
    const percentage = dom.reflection.parseFloatingPoint(input[0..i]) orelse return null;
    // 5.
    if (percentage < 0 or percentage > 100) return null;
    // 6.
    return percentage;
}

/// 6.3 "line" setting, a linepos with no "%" (steps 4.Otherwise.1-6): a
/// number, or null.
fn parseLineNumber(linepos: []const u8) ?f64 {
    // 1. Only "-", ASCII digits and ".".
    for (linepos) |c| {
        if (c != '-' and c != '.' and !std.ascii.isDigit(c)) return null;
    }
    // 2. A "-" only first.
    if (std.mem.indexOfScalar(u8, linepos[1..], '-') != null) return null;
    // 3. At most one ".".
    if (std.mem.count(u8, linepos, ".") > 1) return null;
    // 4. A "." between two digits.
    if (std.mem.indexOfScalar(u8, linepos, '.')) |dot| {
        if (dot == 0 or dot == linepos.len - 1) return null;
        if (!std.ascii.isDigit(linepos[dot - 1]) or !std.ascii.isDigit(linepos[dot + 1])) return null;
    }
    // 5-6.
    return dom.reflection.parseFloatingPoint(linepos);
}

/// 6.2 regionanchor / viewportanchor: "X%,Y%", each a percentage.
fn parseAnchor(value: []const u8) ?[2]f64 {
    // 1-3.
    const comma = std.mem.indexOfScalar(u8, value, ',') orelse return null;
    // 4.
    const x = parsePercentage(value[0..comma]) orelse return null;
    const y = parsePercentage(value[comma + 1 ..]) orelse return null;
    // 5.
    return .{ x, y };
}

/// 6.3 "collect a WebVTT timestamp" at `position` in `input`: seconds, or
/// null for an error.
pub fn collectTimestamp(input: []const u8, position: *usize) ?f64 {
    // 2.
    var hours_significant = false;
    // 3-4.
    if (position.* >= input.len or !std.ascii.isDigit(input[position.*])) return null;
    // 5-6.
    const first = collectDigits(input, position);
    var value1 = std.fmt.parseInt(u64, first, 10) catch std.math.maxInt(u64);
    // 7.
    if (first.len != 2 or value1 > 59) hours_significant = true;
    // 8.
    if (position.* >= input.len or input[position.*] != ':') return null;
    position.* += 1;
    // 9-11.
    const second = collectDigits(input, position);
    if (second.len != 2) return null;
    var value2 = std.fmt.parseInt(u64, second, 10) catch return null;
    // 12.
    var value3: u64 = undefined;
    if (hours_significant or (position.* < input.len and input[position.*] == ':')) {
        // 12.1.
        if (position.* >= input.len or input[position.*] != ':') return null;
        position.* += 1;
        // 12.2-4.
        const third = collectDigits(input, position);
        if (third.len != 2) return null;
        value3 = std.fmt.parseInt(u64, third, 10) catch return null;
    } else {
        value3 = value2;
        value2 = value1;
        value1 = 0;
    }
    // 13.
    if (position.* >= input.len or input[position.*] != '.') return null;
    position.* += 1;
    // 14-16.
    const fourth = collectDigits(input, position);
    if (fourth.len != 3) return null;
    const value4 = std.fmt.parseInt(u64, fourth, 10) catch return null;
    // 17.
    if (value2 > 59 or value3 > 59) return null;
    // 18-19.
    return @as(f64, @floatFromInt(value1)) * 60 * 60 + @as(f64, @floatFromInt(value2)) * 60 + @as(f64, @floatFromInt(value3)) + @as(f64, @floatFromInt(value4)) / 1000;
}

// ---------------------------------------------------------------------------
// 6.4 The WebVTT cue text parsing rules
// ---------------------------------------------------------------------------

/// A WebVTT Node Object (6.4): an internal node (a list of WebVTT Node
/// Objects, a class, italic, bold, underline, ruby, ruby text, voice or
/// language object) or a leaf (a text or timestamp object).
pub const CueNode = struct {
    kind: Kind,
    /// The internal node this node was appended to; null for the root.
    parent: ?*CueNode = null,
    /// An internal node's ordered list of children.
    children: std.ArrayListUnmanaged(*CueNode) = .empty,
    /// An internal node's applicable classes, none of them empty.
    classes: []const []const u8 = &.{},
    /// An internal node's applicable language, when the language stack had
    /// one (or, for the root, the fallback language).
    language: ?[]const u8 = null,
    /// A text object's text; a voice object's value (the voice's name).
    value: []const u8 = "",
    /// A timestamp object's time, in seconds.
    time: f64 = 0,

    pub const Kind = enum {
        list,
        class,
        italic,
        bold,
        underline,
        ruby,
        ruby_text,
        voice,
        language,
        text,
        timestamp,

        /// The local name of the HTML element the WebVTT cue text DOM
        /// construction rules (6.5) map an internal node of this kind to.
        pub fn localName(kind: Kind) []const u8 {
            return switch (kind) {
                .class, .voice, .language => "span",
                .italic => "i",
                .bold => "b",
                .underline => "u",
                .ruby => "ruby",
                .ruby_text => "rt",
                .list, .text, .timestamp => unreachable,
            };
        }
    };
};

/// What the WebVTT cue text parsing rules returned: a list of WebVTT Node
/// Objects (`root`). Everything in it is the arena's.
pub const CueText = struct {
    arena: std.heap.ArenaAllocator,
    root: *CueNode,

    pub fn deinit(self: *CueText) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

/// The WebVTT cue text parsing rules (6.4), given `input` - supposedly
/// WebVTT caption or subtitle cue text - and optionally a fallback
/// `language`.
pub fn parseCueText(allocator: Allocator, input: []const u8, language: ?[]const u8) Allocator.Error!CueText {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    // 1-2. `input`, and a pointer into it.
    var tokenizer: CueTextTokenizer = .{ .allocator = a, .input = input };
    // 3. result: a list of WebVTT Node Objects.
    const result = try a.create(CueNode);
    result.* = .{ .kind = .list };
    // 4. current.
    var current = result;
    // 5. The language stack.
    var language_stack: std.ArrayListUnmanaged([]const u8) = .empty;
    // 6.
    if (language) |fallback| {
        const owned = try a.dupe(u8, fallback);
        result.language = owned;
        try language_stack.append(a, owned);
    }
    // 7. Loop: past the end, return result.
    while (tokenizer.position < input.len) {
        // 8.
        const token = try tokenizer.next();
        // 9.
        switch (token) {
            .string => |text| {
                // 9.string.1-2: a WebVTT Text Object, appended to current.
                const node = try a.create(CueNode);
                node.* = .{ .kind = .text, .parent = current, .value = text };
                try current.children.append(a, node);
            },
            .start_tag => |tag| {
                const kind: ?CueNode.Kind = if (std.mem.eql(u8, tag.name, "c"))
                    .class
                else if (std.mem.eql(u8, tag.name, "i"))
                    .italic
                else if (std.mem.eql(u8, tag.name, "b"))
                    .bold
                else if (std.mem.eql(u8, tag.name, "u"))
                    .underline
                else if (std.mem.eql(u8, tag.name, "ruby"))
                    .ruby
                else if (std.mem.eql(u8, tag.name, "rt"))
                    // Only inside a ruby object.
                    (if (current.kind == .ruby) .ruby_text else null)
                else if (std.mem.eql(u8, tag.name, "v"))
                    .voice
                else if (std.mem.eql(u8, tag.name, "lang"))
                    .language
                else
                    // Otherwise: ignore the token.
                    null;
                if (kind) |made| {
                    // "lang": push the annotation onto the language stack
                    // first.
                    if (made == .language) try language_stack.append(a, tag.annotation orelse "");
                    // Attach a WebVTT Internal Node Object: 1. create it.
                    const node = try a.create(CueNode);
                    node.* = .{ .kind = made, .parent = current };
                    // 2. Its applicable classes: the token's, minus empty ones.
                    node.classes = try nonEmpty(a, tag.classes);
                    // 3. Its applicable language: the top of the stack.
                    if (language_stack.items.len != 0) node.language = language_stack.items[language_stack.items.len - 1];
                    // "v": its value is the annotation string.
                    if (made == .voice) node.value = tag.annotation orelse "";
                    // 4. Append it to current; 5. it is current.
                    try current.children.append(a, node);
                    current = node;
                }
            },
            .end_tag => |name| {
                const closes: ?CueNode.Kind = if (std.mem.eql(u8, name, "c"))
                    .class
                else if (std.mem.eql(u8, name, "i"))
                    .italic
                else if (std.mem.eql(u8, name, "b"))
                    .bold
                else if (std.mem.eql(u8, name, "u"))
                    .underline
                else if (std.mem.eql(u8, name, "ruby"))
                    .ruby
                else if (std.mem.eql(u8, name, "rt"))
                    .ruby_text
                else if (std.mem.eql(u8, name, "v"))
                    .voice
                else
                    null;
                if (closes != null and current.kind == closes.?) {
                    // The end tag closes current: its parent is current.
                    current = current.parent.?;
                } else if (std.mem.eql(u8, name, "lang") and current.kind == .language) {
                    // "lang": also pop the language stack.
                    current = current.parent.?;
                    _ = language_stack.pop();
                } else if (std.mem.eql(u8, name, "ruby") and current.kind == .ruby_text) {
                    // "ruby" closing a ruby text object: past its ruby.
                    current = current.parent.?.parent.?;
                }
                // Otherwise, ignore the token.
            },
            .timestamp => |value| {
                // 9.timestamp.1-3: collect a WebVTT timestamp from the tag
                // value.
                var position: usize = 0;
                // 4. A timestamp object only when it parsed and nothing
                // trails it.
                if (collectTimestamp(value, &position)) |time| if (position == value.len) {
                    const node = try a.create(CueNode);
                    node.* = .{ .kind = .timestamp, .parent = current, .time = time };
                    try current.children.append(a, node);
                };
            },
        }
        // 10. Jump to loop.
    }
    return .{ .arena = arena, .root = result };
}

fn nonEmpty(allocator: Allocator, classes: []const []const u8) Allocator.Error![]const []const u8 {
    var kept: std.ArrayListUnmanaged([]const u8) = .empty;
    for (classes) |class| if (class.len != 0) try kept.append(allocator, class);
    return kept.items;
}

/// A token of the WebVTT cue text tokenizer (6.4).
const CueToken = union(enum) {
    string: []const u8,
    start_tag: struct { name: []const u8, classes: []const []const u8 = &.{}, annotation: ?[]const u8 = null },
    end_tag: []const u8,
    timestamp: []const u8,
};

/// The WebVTT cue text tokenizer (6.4). `position` is the parsing rules'
/// pointer into `input`, shared across tokens.
const CueTextTokenizer = struct {
    allocator: Allocator,
    input: []const u8,
    position: usize = 0,

    const State = enum { data, tag, start_tag, start_tag_class, start_tag_annotation, end_tag, timestamp_tag };

    fn next(self: *CueTextTokenizer) Allocator.Error!CueToken {
        const a = self.allocator;
        const input = self.input;
        // 2-4.
        var state: State = .data;
        var result: std.ArrayListUnmanaged(u8) = .empty;
        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        var classes: std.ArrayListUnmanaged([]const u8) = .empty;
        // 5. Loop.
        while (true) {
            // `c`: null is the end-of-file marker.
            const c: ?u8 = if (self.position < input.len) input[self.position] else null;
            // 6.
            switch (state) {
                .data => {
                    const char = c orelse return .{ .string = result.items };
                    switch (char) {
                        '&' => {
                            // The HTML character reference in data state:
                            // consume one after the "&", with no additional
                            // allowed character; nothing returned is a "&".
                            // Then the data state at the first character not
                            // consumed - none is skipped (Blink's
                            // VTTTokenizer: ProcessEntity, then
                            // WEBVTT_SWITCH_TO(kDataState); the .dat cases
                            // "&<c" and "&1;" keep every character).
                            self.position += 1;
                            if (!try consumeCharacterReference(a, input, &self.position, null, &result)) try result.append(a, '&');
                            continue;
                        },
                        '<' => {
                            if (result.items.len == 0) {
                                state = .tag;
                            } else return .{ .string = result.items };
                        },
                        else => try result.append(a, char),
                    }
                },
                .tag => {
                    const char = c orelse return .{ .start_tag = .{ .name = "" } };
                    switch (char) {
                        '\t', '\n', 0x0c, ' ' => state = .start_tag_annotation,
                        '.' => state = .start_tag_class,
                        '/' => state = .end_tag,
                        '0'...'9' => {
                            try result.append(a, char);
                            state = .timestamp_tag;
                        },
                        '>' => {
                            self.position += 1;
                            return .{ .start_tag = .{ .name = "" } };
                        },
                        else => {
                            try result.append(a, char);
                            state = .start_tag;
                        },
                    }
                },
                .start_tag => {
                    const char = c orelse return .{ .start_tag = .{ .name = result.items } };
                    switch (char) {
                        '\t', 0x0c, ' ' => state = .start_tag_annotation,
                        '\n' => {
                            try buffer.append(a, char);
                            state = .start_tag_annotation;
                        },
                        '.' => state = .start_tag_class,
                        '>' => {
                            self.position += 1;
                            return .{ .start_tag = .{ .name = result.items } };
                        },
                        else => try result.append(a, char),
                    }
                },
                .start_tag_class => {
                    const char = c orelse {
                        try classes.append(a, buffer.items);
                        return .{ .start_tag = .{ .name = result.items, .classes = classes.items } };
                    };
                    switch (char) {
                        '\t', 0x0c, ' ' => {
                            try classes.append(a, try buffer.toOwnedSlice(a));
                            state = .start_tag_annotation;
                        },
                        '\n' => {
                            try classes.append(a, try buffer.toOwnedSlice(a));
                            try buffer.append(a, char);
                            state = .start_tag_annotation;
                        },
                        '.' => try classes.append(a, try buffer.toOwnedSlice(a)),
                        '>' => {
                            self.position += 1;
                            try classes.append(a, buffer.items);
                            return .{ .start_tag = .{ .name = result.items, .classes = classes.items } };
                        },
                        else => try buffer.append(a, char),
                    }
                },
                .start_tag_annotation => {
                    const char = c orelse return .{ .start_tag = .{ .name = result.items, .classes = classes.items, .annotation = try collapseWhitespace(a, buffer.items) } };
                    switch (char) {
                        '&' => {
                            // The HTML character reference in annotation
                            // state: ">" is the additional allowed character
                            // - with HTML's states, ">" starts no reference
                            // anyway.
                            self.position += 1;
                            if (!try consumeCharacterReference(a, input, &self.position, '>', &buffer)) try buffer.append(a, '&');
                            continue;
                        },
                        '>' => {
                            self.position += 1;
                            return .{ .start_tag = .{ .name = result.items, .classes = classes.items, .annotation = try collapseWhitespace(a, buffer.items) } };
                        },
                        else => try buffer.append(a, char),
                    }
                },
                .end_tag => {
                    const char = c orelse return .{ .end_tag = result.items };
                    if (char == '>') {
                        self.position += 1;
                        return .{ .end_tag = result.items };
                    }
                    try result.append(a, char);
                },
                .timestamp_tag => {
                    const char = c orelse return .{ .timestamp = result.items };
                    if (char == '>') {
                        self.position += 1;
                        return .{ .timestamp = result.items };
                    }
                    try result.append(a, char);
                },
            }
            // 7. Next.
            self.position += 1;
        }
    }
};

/// The start tag annotation state's end: leading and trailing ASCII
/// whitespace removed, and each run of it replaced by one space.
fn collapseWhitespace(allocator: Allocator, text: []const u8) Allocator.Error![]const u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var pending_space = false;
    for (text) |c| {
        if (std.mem.indexOfScalar(u8, ascii_whitespace, c) != null) {
            pending_space = out.items.len != 0;
            continue;
        }
        if (pending_space) try out.append(allocator, ' ');
        pending_space = false;
        try out.append(allocator, c);
    }
    return out.items;
}

/// "Consume a character reference" (6.4's note: HTML's, not as part of an
/// attribute), starting at `position.*` - the character after the "&". When
/// one is returned its characters are appended to `out` and `position`
/// moves past what it consumed; otherwise nothing is consumed and the result
/// is false. HTML 13.2.5.77-84 (character reference, named, ambiguous
/// ampersand, numeric and numeric end states); `additional` is the
/// additional allowed character, which starts no reference.
fn consumeCharacterReference(allocator: Allocator, input: []const u8, position: *usize, additional: ?u8, out: *std.ArrayListUnmanaged(u8)) Allocator.Error!bool {
    const start = position.*;
    if (start >= input.len) return false;
    const c = input[start];
    if (additional != null and c == additional.?) return false;
    if (std.ascii.isAlphanumeric(c)) {
        // 13.2.5.78: the longest name in the named character references
        // table. With none, the ambiguous ampersand state leaves the
        // characters as they are.
        const entity = entities.findLongestMatch(input[start..]) orelse return false;
        for (entity.codepoints) |code| try appendCodePoint(allocator, out, code);
        position.* = start + entity.name.len;
        return true;
    }
    if (c != '#') return false;
    // 13.2.5.80-83: a numeric reference.
    var i = start + 1;
    const hex = i < input.len and (input[i] == 'x' or input[i] == 'X');
    if (hex) i += 1;
    const digits_start = i;
    var code: u32 = 0;
    while (i < input.len) : (i += 1) {
        const digit: u32 = if (hex)
            (std.fmt.charToDigit(input[i], 16) catch break)
        else
            (std.fmt.charToDigit(input[i], 10) catch break);
        // Saturate past the Unicode range; the end state replaces it.
        code = if (code > 0x10FFFF) code else code * @as(u32, if (hex) 16 else 10) + digit;
    }
    // No digits: the absence-of-digits error flushes "&#" (or "&#x") as
    // text - nothing consumed.
    if (i == digits_start) return false;
    // A missing semicolon is a parse error only.
    if (i < input.len and input[i] == ';') i += 1;
    try appendCodePoint(allocator, out, numericReplacement(code));
    position.* = i;
    return true;
}

/// HTML 13.2.5.84, the numeric character reference end state's
/// replacements.
fn numericReplacement(code: u32) u21 {
    if (code == 0 or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF)) return 0xFFFD;
    return switch (code) {
        0x80 => 0x20AC,
        0x82 => 0x201A,
        0x83 => 0x0192,
        0x84 => 0x201E,
        0x85 => 0x2026,
        0x86 => 0x2020,
        0x87 => 0x2021,
        0x88 => 0x02C6,
        0x89 => 0x2030,
        0x8A => 0x0160,
        0x8B => 0x2039,
        0x8C => 0x0152,
        0x8E => 0x017D,
        0x91 => 0x2018,
        0x92 => 0x2019,
        0x93 => 0x201C,
        0x94 => 0x201D,
        0x95 => 0x2022,
        0x96 => 0x2013,
        0x97 => 0x2014,
        0x98 => 0x02DC,
        0x99 => 0x2122,
        0x9A => 0x0161,
        0x9B => 0x203A,
        0x9C => 0x0153,
        0x9E => 0x017E,
        0x9F => 0x0178,
        else => @intCast(code),
    };
}

fn appendCodePoint(allocator: Allocator, out: *std.ArrayListUnmanaged(u8), code: u21) Allocator.Error!void {
    var bytes: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(code, &bytes) catch std.unicode.utf8Encode(0xFFFD, &bytes) catch unreachable;
    try out.appendSlice(allocator, bytes[0..len]);
}

/// A WebVTT timestamp representing `seconds` "with all optional components
/// included, with one leading zero if the hours component is less than ten,
/// and with no leading zeros otherwise" (6.5, a timestamp object's
/// processing instruction data): hh:mm:ss.ttt.
pub fn formatTimestamp(buffer: []u8, seconds: f64) []const u8 {
    // The parser makes timestamps from whole milliseconds (6.3 step 19); an
    // hours field of any length parses, so a time past u64 milliseconds
    // saturates rather than overflow the conversion.
    const millis = @round(seconds * 1000);
    const total: u64 = if (!(millis > 0)) 0 else if (millis >= 0x1p64) std.math.maxInt(u64) else @intFromFloat(millis);
    const ms = total % 1000;
    const s = (total / 1000) % 60;
    const m = (total / 60_000) % 60;
    const h = total / 3_600_000;
    return std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{ h, m, s, ms }) catch buffer[0..0];
}

// ---------------------------------------------------------------------------
// 6.5 The WebVTT cue text DOM construction rules
// ---------------------------------------------------------------------------

const html_namespace = "http://www.w3.org/1999/xhtml";

/// Convert `list` - a list of WebVTT Node Objects - to a DOM tree for
/// `owner` (6.5): a DocumentFragment whose tree is isomorphous to the list's,
/// every node's node document `owner`. A class object is a span, italic i,
/// bold b, underline u, ruby ruby, ruby text rt, a voice a span with a title
/// attribute (its value), a language a span with a lang attribute (its
/// applicable language); an internal node with applicable classes has a
/// class attribute of them, space-separated. A text object is a Text node, a
/// timestamp a ProcessingInstruction "timestamp" whose data is the WebVTT
/// timestamp (`formatTimestamp`).
pub fn cueTextFragment(owner: *runtime.Instance, list: *const CueNode) !*runtime.Instance {
    const fragment = try interfaces.Document.call_createDocumentFragment(owner);
    errdefer dom.node_creation.destroyUninserted(fragment);
    try appendCueNodes(owner, fragment, list);
    return fragment;
}

/// The fragment Chrome, Firefox and Safari answer for empty cue text: one
/// empty Text node (VTTCue.getCueAsHTML says why).
pub fn emptyCueTextFragment(owner: *runtime.Instance) !*runtime.Instance {
    const fragment = try interfaces.Document.call_createDocumentFragment(owner);
    errdefer dom.node_creation.destroyUninserted(fragment);
    const parent = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    const text = try interfaces.Document.call_createTextNode(owner, runtime.DOMString.initEmpty());
    const base = dom.instance_bridge.getNodeBase(text) orelse return error.InvalidStateError;
    errdefer if (base.parent_node == null) dom.node_creation.destroyUninserted(text);
    _ = try dom.mutation.append(base, parent);
    return fragment;
}

fn appendCueNodes(owner: *runtime.Instance, parent: *runtime.Instance, node: *const CueNode) !void {
    const parent_base = dom.instance_bridge.getNodeBase(parent) orelse return error.InvalidStateError;
    for (node.children.items) |child| {
        const made = try cueDomNode(owner, child);
        {
            const base = dom.instance_bridge.getNodeBase(made) orelse return error.InvalidStateError;
            errdefer if (base.parent_node == null) dom.node_creation.destroyUninserted(made);
            _ = try dom.mutation.append(base, parent_base);
        }
        // The child is in the tree now: a failure below goes with the
        // fragment.
        if (child.children.items.len != 0) try appendCueNodes(owner, made, child);
    }
}

/// The DOM node `node` maps to, its attributes set, not yet inserted.
fn cueDomNode(owner: *runtime.Instance, node: *const CueNode) !*runtime.Instance {
    switch (node.kind) {
        .text => return interfaces.Document.call_createTextNode(owner, runtime.DOMString.initInterned(node.value)),
        .timestamp => {
            var buffer: [32]u8 = undefined;
            return interfaces.Document.call_createProcessingInstruction(owner, runtime.DOMString.initInterned("timestamp"), runtime.DOMString.initInterned(formatTimestamp(&buffer, node.time)));
        },
        .list => unreachable,
        else => {},
    }
    const element = try interfaces.Document.call_createElementNS(owner, runtime.DOMString.initInterned(html_namespace), runtime.DOMString.initInterned(node.kind.localName()), .notPassed());
    errdefer dom.node_creation.destroyUninserted(element);
    if (node.classes.len != 0) {
        const allocator = owner.ctx.allocator;
        const joined = try std.mem.join(allocator, " ", node.classes);
        defer allocator.free(joined);
        try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("class"), .{ .domstring = runtime.DOMString.initInterned(joined) });
    }
    switch (node.kind) {
        .voice => try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("title"), .{ .domstring = runtime.DOMString.initInterned(node.value) }),
        .language => try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("lang"), .{ .domstring = runtime.DOMString.initInterned(node.language orelse "") }),
        else => {},
    }
    return element;
}
