//! Cache-Control (RFC 9111 5.2): the directives of a request or a response,
//! as the HTTP cache reads them.
//!
//! ```
//! Cache-Control   = #cache-directive
//! cache-directive = token [ "=" ( token / quoted-string ) ]
//! ```
//!
//! Directive names compare case-insensitively (5.2); recipients accept both
//! argument forms for the directives that take one (5.2). Of a directive
//! given twice, the first occurrence is used (4.2.1: "either the first
//! occurrence should be used or the response should be considered stale"),
//! across every field line (`add` each line in order). delta-seconds are
//! 1*DIGIT (1.2.2); an overflow is 2^31; anything else is invalid, which
//! the freshness lifetime reads as stale (4.2.1). Unknown directives are
//! ignored (5.2.3), quoted arguments and all.
//!
//! Spec: https://www.rfc-editor.org/rfc/rfc9111#section-5.2
//! (supersedes RFC 7234 5.2, which the earlier parser here followed: it
//! split at every comma, quoted ones included, and let the last duplicate
//! win.)

const std = @import("std");

pub const Directives = struct {
    // Response directives (5.2.2) and the request ones that share a name.
    max_age: Seconds = .absent,
    s_maxage: Seconds = .absent,
    no_cache: bool = false,
    no_store: bool = false,
    no_transform: bool = false,
    must_revalidate: bool = false,
    must_understand: bool = false,
    proxy_revalidate: bool = false,
    private: bool = false,
    public: bool = false,
    // RFC 5861 and RFC 8246 extensions.
    stale_while_revalidate: Seconds = .absent,
    stale_if_error: Seconds = .absent,
    immutable: bool = false,
    // Request directives (5.2.1).
    max_stale: ?MaxStale = null,
    min_fresh: Seconds = .absent,
    only_if_cached: bool = false,

    /// A delta-seconds argument (1.2.2).
    pub const Seconds = union(enum) {
        absent,
        /// Present, but not 1*DIGIT (4.2.1: stale, for max-age).
        invalid,
        value: u32,
    };

    /// max-stale (5.2.1.2): with no argument, a stale response of any age.
    pub const MaxStale = union(enum) {
        any,
        seconds: u32,
    };

    /// RFC 9111 1.2.2: "the cache MUST consider the value to be 2147483648
    /// (2^31)" on an overflow.
    pub const delta_seconds_overflow: u32 = 2147483648;

    /// The directives of one field value (or several lines combined with
    /// ", ").
    pub fn parse(value: []const u8) Directives {
        var directives: Directives = .{};
        directives.add(value);
        return directives;
    }

    /// Add one more field line's directives; earlier occurrences win.
    pub fn add(self: *Directives, value: []const u8) void {
        var scanner: Scanner = .{ .input = value };
        while (scanner.next()) |directive| self.apply(directive);
    }

    fn apply(self: *Directives, d: Directive) void {
        const name = d.name;
        if (eql(name, "max-age")) {
            setSeconds(&self.max_age, d.argument);
        } else if (eql(name, "s-maxage")) {
            setSeconds(&self.s_maxage, d.argument);
        } else if (eql(name, "min-fresh")) {
            setSeconds(&self.min_fresh, d.argument);
        } else if (eql(name, "stale-while-revalidate")) {
            setSeconds(&self.stale_while_revalidate, d.argument);
        } else if (eql(name, "stale-if-error")) {
            setSeconds(&self.stale_if_error, d.argument);
        } else if (eql(name, "max-stale")) {
            if (self.max_stale != null) return;
            const argument = d.argument orelse {
                self.max_stale = .any;
                return;
            };
            // An argument that is no delta-seconds grants nothing: serving
            // stale needs the client's clear permission (4.2.4).
            self.max_stale = switch (deltaSeconds(argument)) {
                .value => |seconds| .{ .seconds = seconds },
                else => null,
            };
        } else if (eql(name, "no-cache")) {
            // The qualified form (a field-name list) is treated as the
            // unqualified one - "often handled by caches as if an unqualified
            // no-cache directive was received" (5.2.2.4).
            self.no_cache = true;
        } else if (eql(name, "no-store")) {
            self.no_store = true;
        } else if (eql(name, "no-transform")) {
            self.no_transform = true;
        } else if (eql(name, "must-revalidate")) {
            self.must_revalidate = true;
        } else if (eql(name, "must-understand")) {
            self.must_understand = true;
        } else if (eql(name, "proxy-revalidate")) {
            self.proxy_revalidate = true;
        } else if (eql(name, "private")) {
            // The qualified form, likewise (5.2.2.7).
            self.private = true;
        } else if (eql(name, "public")) {
            self.public = true;
        } else if (eql(name, "immutable")) {
            self.immutable = true;
        } else if (eql(name, "only-if-cached")) {
            self.only_if_cached = true;
        }
        // 5.2.3: "A cache MUST ignore unrecognized cache directives."
    }

    fn setSeconds(slot: *Seconds, argument: ?[]const u8) void {
        if (slot.* != .absent) return; // the first occurrence counts
        slot.* = if (argument) |a| deltaSeconds(a) else .invalid;
    }
};

/// RFC 9111 1.2.2 delta-seconds: 1*DIGIT, an overflow 2^31.
pub fn deltaSeconds(text: []const u8) Directives.Seconds {
    if (text.len == 0) return .invalid;
    var value: u64 = 0;
    for (text) |c| {
        if (!std.ascii.isDigit(c)) return .invalid;
        if (value < Directives.delta_seconds_overflow) value = value * 10 + (c - '0');
    }
    if (value >= Directives.delta_seconds_overflow) return .{ .value = Directives.delta_seconds_overflow };
    return .{ .value = @intCast(value) };
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

const Directive = struct {
    name: []const u8,
    /// The argument, unquoted - a quoted-string's escapes left in place, which
    /// no directive read here can contain.
    argument: ?[]const u8,
};

/// Walks `#cache-directive` (RFC 9110 5.6.1 lists: empty members and OWS
/// around commas allowed). A member that does not parse is skipped up to the
/// next comma outside a quoted string.
const Scanner = struct {
    input: []const u8,
    pos: usize = 0,

    fn next(self: *Scanner) ?Directive {
        while (self.pos < self.input.len) {
            self.skipSeparators();
            if (self.pos >= self.input.len) return null;
            const name = self.token();
            if (name.len == 0) {
                self.skipMember();
                continue;
            }
            self.skipOws();
            var argument: ?[]const u8 = null;
            if (self.peek() == '=') {
                self.pos += 1;
                self.skipOws();
                if (self.peek() == '"') {
                    argument = self.quotedString() orelse {
                        self.skipMember();
                        continue;
                    };
                } else {
                    argument = self.token();
                }
                self.skipOws();
            }
            if (self.pos < self.input.len and self.input[self.pos] != ',') {
                // Trailing garbage: the member is not a cache-directive.
                self.skipMember();
                continue;
            }
            return .{ .name = name, .argument = argument };
        }
        return null;
    }

    fn peek(self: *const Scanner) u8 {
        return if (self.pos < self.input.len) self.input[self.pos] else 0;
    }

    fn skipOws(self: *Scanner) void {
        while (self.pos < self.input.len and (self.input[self.pos] == ' ' or self.input[self.pos] == '\t')) self.pos += 1;
    }

    fn skipSeparators(self: *Scanner) void {
        while (self.pos < self.input.len) : (self.pos += 1) {
            switch (self.input[self.pos]) {
                ' ', '\t', ',' => {},
                else => return,
            }
        }
    }

    fn token(self: *Scanner) []const u8 {
        const start = self.pos;
        while (self.pos < self.input.len and isTchar(self.input[self.pos])) self.pos += 1;
        return self.input[start..self.pos];
    }

    /// RFC 9110 5.6.4 quoted-string, the quotes stripped. Null when it does
    /// not close.
    fn quotedString(self: *Scanner) ?[]const u8 {
        std.debug.assert(self.input[self.pos] == '"');
        self.pos += 1;
        const start = self.pos;
        while (self.pos < self.input.len) : (self.pos += 1) {
            switch (self.input[self.pos]) {
                '\\' => self.pos += 1,
                '"' => {
                    const text = self.input[start..self.pos];
                    self.pos += 1;
                    return text;
                },
                else => {},
            }
        }
        return null;
    }

    /// Past the rest of this member: to the next comma not inside quotes.
    fn skipMember(self: *Scanner) void {
        var quoted = false;
        while (self.pos < self.input.len) : (self.pos += 1) {
            const c = self.input[self.pos];
            if (quoted) {
                if (c == '\\') {
                    self.pos += 1;
                } else if (c == '"') {
                    quoted = false;
                }
            } else if (c == '"') {
                quoted = true;
            } else if (c == ',') {
                return;
            }
        }
    }
};

/// RFC 9110 5.6.2 tchar.
fn isTchar(c: u8) bool {
    return switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        else => std.ascii.isAlphanumeric(c),
    };
}

test "Directives.parse: the empty value has no directives" {
    const d = Directives.parse("");
    try std.testing.expectEqual(Directives.Seconds.absent, d.max_age);
    try std.testing.expect(!d.no_store and !d.no_cache);
}
