//! A URL pattern component's regular expression (URLPattern 1.5, "compile a
//! component" step 6) and the RegExpBuiltinExec calls made on it ("match"
//! steps 14-21, "protocol component matches a special scheme" step 2.1):
//! ECMAScript RegExpCreate with flags "v" or "vi", and RegExpBuiltinExec,
//! done by the JavaScript engine through the protocol
//! (engine.regExpCreateCheck, engine.regExpBuiltinExecCaptures; integrator
//! ruling Q2, tmp/plans/codex-urlpattern-questions.md).
//!
//! Not a regular expression engine of its own: a Regexp keeps the generated
//! regular expression string and the ignore-case flag, and nothing of the
//! engine's - no realm, handle or engine value. The engine compiles the
//! string once per agent and keeps it (V8: the agent's utility context and
//! bounded cache, as Blink's URLPattern keeps a ScriptRegexp per component),
//! and every call names the realm to work in.
//!
//! The spec's note (urlpattern.md, after "compile a component" step 6) lets
//! an implementation match against the part list directly when there are no
//! custom regexp groups; Crane does not (ruling Q2: correctness first), so
//! every component is a regexp, and an engine without the operations
//! (error.NotSupported) cannot construct a URLPattern.

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");

/// The realm a component is compiled and matched in: the URLPattern
/// operation's. BORROWED for each call; never kept.
pub const Realm = engine.Context;

pub const Error = error{
    /// RegExpCreate threw: URLPattern turns it into a TypeError.
    InvalidPattern,
    /// The engine has no regular expressions to offer (a declared
    /// capability gap: JavaScriptCore with no engine linked, QuickJS, the
    /// engine-less test adapter).
    NotSupported,
    OutOfMemory,
};

/// A component's regular expression: RegExpCreate(`source`, "v" or "vi")
/// succeeded for it once, in some realm of the agent.
pub const Regexp = struct {
    /// The regular expression string "generate a regular expression and name
    /// list" made. BORROWED: the component owns it.
    source: []const u8,
    ignore_case: bool,

    /// "Compile a component" steps 3-6: RegExpCreate(`source`, "vi" when
    /// `ignore_case`, else "v"). A throw is error.InvalidPattern.
    pub fn create(realm: Realm, source: []const u8, ignore_case: bool) Error!Regexp {
        try engine.regExpCreateCheck(realm, source, ignore_case);
        return .{ .source = source, .ignore_case = ignore_case };
    }

    /// RegExpBuiltinExec(this regexp, `input`): null when it returns null,
    /// otherwise the result's elements, OWNED (`allocator`). `create`
    /// compiled the same string with the same flags, so it compiles again
    /// if the engine has let its copy go; InvalidPattern cannot come back.
    pub fn exec(self: Regexp, realm: Realm, input: []const u8, allocator: Allocator) Error!?Captures {
        const values = try engine.regExpBuiltinExecCaptures(realm, self.source, self.ignore_case, input, allocator) orelse return null;
        return .{ .values = values, .allocator = allocator };
    }

    /// Whether RegExpBuiltinExec(this regexp, `input`) is not null.
    pub fn matches(self: Regexp, realm: Realm, input: []const u8, allocator: Allocator) Error!bool {
        var captures = try self.exec(realm, input, allocator) orelse return false;
        captures.deinit();
        return true;
    }
};

/// What RegExpBuiltinExec returned for a match: element 0 is the matched
/// substring, element i (1..n) the i-th capture group's - null when the
/// group did not participate (undefined), apart from "". OWNED.
pub const Captures = struct {
    values: []?[]u8,
    allocator: Allocator,

    pub fn deinit(self: *Captures) void {
        for (self.values) |value| if (value) |bytes| self.allocator.free(bytes);
        self.allocator.free(self.values);
        self.* = undefined;
    }

    /// Get(execResult, ToString(`index`)) ("create a component match result"
    /// step 5.2): null for undefined, and for an index past the result.
    pub fn get(self: Captures, index: usize) ?[]const u8 {
        if (index >= self.values.len) return null;
        return self.values[index];
    }
};
