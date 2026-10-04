//! Incremental server-sent event parsing, HTML 9.2.5–9.2.6.
//! https://html.spec.whatwg.org/multipage/server-sent-events.html
//!
//! Line endings are ASCII bytes, which cannot be UTF-8 continuation bytes.
//! Keep an incomplete line across chunks and decode each complete line with
//! replacement, as Blink's EventSourceParser does. No engine or script runs
//! here; each output message owns its bytes before another line is parsed.
const std = @import("std");
const infra = @import("infra");
const encoding = @import("encoding");

/// One dispatch's strings, owned by the caller and allocated by the parser.
pub const Message = struct {
    data: []const u8,
    event_type: []const u8,
    last_event_id: []const u8,

    /// Release every string after the event has taken its own copy.
    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        allocator.free(self.event_type);
        allocator.free(self.last_event_id);
    }
};

/// A connection's persistent ID/retry state and its current stream buffers.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    reconnection_time: u64 = 3000,
    line: infra.List(u8),
    data: infra.List(u8),
    event_type: []const u8 = "",
    id_buffer: []const u8 = "",
    last_id: []const u8 = "",
    first_line: bool = true,
    skip_lf: bool = false,

    /// HTML 9.2.2: initially empty ID and implementation-defined 3s retry.
    pub fn init(allocator: std.mem.Allocator) Parser {
        return .{
            .allocator = allocator,
            .line = infra.List(u8).init(allocator),
            .data = infra.List(u8).init(allocator),
        };
    }

    /// Free partial input and every parser-owned string.
    pub fn deinit(self: *Parser) void {
        self.line.deinit();
        self.data.deinit();
        self.allocator.free(self.event_type);
        self.allocator.free(self.id_buffer);
        self.allocator.free(self.last_id);
    }

    /// HTML 9.2.5–9.2.6: consume bytes, appending owned dispatches to output.
    /// Output already appended before an allocation failure remains the
    /// caller's; the parser can always be deinitialized after failure.
    pub fn feed(self: *Parser, bytes: []const u8, output: *infra.List(Message)) !void {
        for (bytes) |byte| {
            if (self.skip_lf) {
                self.skip_lf = false;
                if (byte == '\n') continue;
            }
            if (byte == '\r' or byte == '\n') {
                try self.processLine(output);
                self.line.clear();
                self.skip_lf = byte == '\r';
            } else try self.line.append(byte);
        }
    }

    /// Borrow the last ID committed by a blank line, including one with no data.
    pub fn lastEventId(self: *const Parser) []const u8 {
        return self.last_id;
    }

    /// HTML 9.2.6 EOF: discard incomplete data, type and uncommitted ID.
    pub fn finish(self: *Parser) void {
        self.line.clear();
        self.data.clear();
        self.allocator.free(self.event_type);
        self.event_type = "";
        self.allocator.free(self.id_buffer);
        self.id_buffer = "";
    }

    /// Start the next stream with fresh BOM/line/data/type state.
    /// Stated deviation from 9.2.6's initially empty ID buffer: seed it from
    /// the last COMMITTED ID, as Blink's event_source_parser.cc constructor
    /// does and eventsource/format-field-id{,-2}.any.js require. An ID in an
    /// unfinished event never reaches last_id and cannot cross a reconnect.
    pub fn reset(self: *Parser) !void {
        self.finish();
        self.id_buffer = try self.allocator.dupe(u8, self.last_id);
        self.first_line = true;
        self.skip_lf = false;
    }

    fn processLine(self: *Parser, output: *infra.List(Message)) !void {
        // 9.2.6: UTF-8 decode strips exactly one leading BOM, per stream.
        const raw = self.line.toSlice();
        const units = if (self.first_line)
            try encoding.utf8Decode(self.allocator, raw)
        else
            try encoding.utf8DecodeWithoutBom(self.allocator, raw);
        defer self.allocator.free(units);
        const line = try encoding.utf8Encode(self.allocator, units);
        defer self.allocator.free(line);
        self.first_line = false;

        // "Lines must be processed": blank, comment, colon, no colon.
        if (line.len == 0) return self.dispatch(output);
        if (line[0] == ':') return;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse line.len;
        const field = line[0..colon];
        var value = if (colon == line.len) "" else line[colon + 1 ..];
        if (value.len > 0 and value[0] == ' ') value = value[1..];

        // 9.2.6 "process the field": names compare literally.
        if (std.mem.eql(u8, field, "event")) {
            try self.replace(&self.event_type, value);
        } else if (std.mem.eql(u8, field, "data")) {
            try self.data.appendSlice(value);
            try self.data.append('\n');
        } else if (std.mem.eql(u8, field, "id")) {
            if (std.mem.indexOfScalar(u8, value, 0) == null) try self.replace(&self.id_buffer, value);
        } else if (std.mem.eql(u8, field, "retry")) {
            if (value.len == 0) return;
            var delay: u64 = 0;
            for (value) |digit| {
                if (digit < '0' or digit > '9') return;
                // The mathematical integer has no limit. Saturation preserves
                // a very long wait rather than wrapping it to a short one.
                delay = delay *| 10 +| (digit - '0');
            }
            self.reconnection_time = delay;
        }
    }

    fn dispatch(self: *Parser, output: *infra.List(Message)) !void {
        // "Dispatch the event" step 1: commit ID even with an empty data buffer.
        try self.replace(&self.last_id, self.id_buffer);
        // Steps 2 and 7: reset data/type before output is handed to script.
        defer self.data.clear();
        defer {
            self.allocator.free(self.event_type);
            self.event_type = "";
        }
        if (self.data.len == 0) return;
        // Step 3: the final LF was appended by processing a data field.
        const data = try self.allocator.dupe(u8, self.data.toSlice()[0 .. self.data.len - 1]);
        errdefer self.allocator.free(data);
        // Steps 4–6: the caller creates MessageEvent in the source's realm.
        const name = try self.allocator.dupe(u8, if (self.event_type.len == 0) "message" else self.event_type);
        errdefer self.allocator.free(name);
        const id = try self.allocator.dupe(u8, self.last_id);
        errdefer self.allocator.free(id);
        // Step 8 is the caller's queued remote-event task.
        try output.append(.{ .data = data, .event_type = name, .last_event_id = id });
    }

    fn replace(self: *Parser, slot: *[]const u8, value: []const u8) !void {
        const copy = try self.allocator.dupe(u8, value);
        self.allocator.free(slot.*);
        slot.* = copy;
    }
};
