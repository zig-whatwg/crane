//! crane_guard: a Claude Code PreToolUse hook that enforces the rules a
//! prompt can only request (the user, 2026-11-03: "implement all four", after
//! https://code.claude.com/docs/en/features-overview - "Put guardrails in
//! hooks. An instruction ... is a request, not a guarantee").
//!
//! Every rule here was broken at least once while it was only an instruction:
//! the Xcode project untracked (2026-07-05) and deleted (2026-09-03), the Mac's
//! disk filled by lanes' local builds (2026-10-23), the pool's shared WPT tree
//! deleted (2026-11-03), a broad pkill on chat (2026-10-28).
//!
//! Run as: `zig run .claude/hooks/crane_guard.zig -- pretooluse` with the hook
//! input on stdin. A denied call exits 2 with the reason on stderr (Claude Code
//! blocks it and shows the reason). Anything else, including input it cannot
//! parse, exits 0: the guard fails open, so a broken guard never stops work.
//!
//! Tests: `zig test .claude/hooks/crane_guard.zig`.

const std = @import("std");

/// The reason a call is refused, or null to let it through.
pub const Verdict = ?[]const u8;

// ---------------------------------------------------------------------------
// Bash commands
// ---------------------------------------------------------------------------

/// Checks one Bash command. `agent_type` is the hook input's `agent_type`:
/// null in the main conversation, the subagent's type (e.g. "lane-xhigh")
/// inside a subagent.
pub fn checkBash(raw_command: []const u8, agent_type: ?[]const u8) Verdict {
    if (std.mem.indexOf(u8, raw_command, "TYPESAFE_API_KEY") != null)
        return "never print or reference TYPESAFE_API_KEY in a command (the user's rule); jev.py loads it through `zsh -ic` without naming it";
    var buf: [64 * 1024]u8 = undefined;
    const command = blankHeredocData(raw_command, &buf);
    if (checkXcode(command)) |v| return v;
    if (checkSharedWptTree(command)) |v| return v;
    if (checkZigBuild(command, agent_type)) |v| return v;
    if (checkGitStash(command)) |v| return v;
    if (checkForcePush(command)) |v| return v;
    if (checkBroadKill(command)) |v| return v;
    if (checkProtectedWrites(command)) |v| return v;
    return null;
}

/// A heredoc that `cat` or `tee` writes to a file is data, not commands
/// (2026-11-03: a lane writing a pool script was refused as a local build):
/// a copy of the command with each such body blanked - its bytes spaces, its
/// newlines kept - so the checks see only what the shell runs. A heredoc fed
/// to anything else (`bash`, `ssh`, `sh -s`) stays: its body runs. A command
/// longer than `buf` is checked as it is.
fn blankHeredocData(command: []const u8, buf: []u8) []const u8 {
    if (command.len > buf.len or std.mem.indexOf(u8, command, "<<") == null) return command;
    const out = buf[0..command.len];
    @memcpy(out, command);
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, command, i, "<<")) |at| {
        i = at + 2;
        if (i < command.len and command[i] == '<') { // a here-string, <<<
            i += 1;
            continue;
        }
        var j = i;
        if (j < command.len and command[j] == '-') j += 1;
        while (j < command.len and command[j] == ' ') j += 1;
        if (j < command.len and isQuote(command[j])) j += 1;
        const word_start = j;
        while (j < command.len and (std.ascii.isAlphanumeric(command[j]) or command[j] == '_')) j += 1;
        const word = command[word_start..j];
        if (word.len == 0) continue;
        const first = basename(firstWordOfSegment(command, at));
        if (!(std.mem.eql(u8, first, "cat") or std.mem.eql(u8, first, "tee"))) continue;
        // The body: the lines after this one, up to the line that is the word.
        const nl = std.mem.indexOfScalarPos(u8, command, j, '\n') orelse return out;
        var line_start = nl + 1;
        while (line_start < command.len) {
            const line_end = std.mem.indexOfScalarPos(u8, command, line_start, '\n') orelse command.len;
            if (std.mem.eql(u8, std.mem.trimStart(u8, command[line_start..line_end], "\t"), word)) {
                i = line_end;
                break;
            }
            @memset(out[line_start..line_end], ' ');
            i = line_end;
            line_start = line_end + 1;
        }
    }
    return out;
}

const removal_verbs = [_][]const u8{ "rm", "rmdir", "trash", "unlink", "mv" };

/// Never delete, move or untrack an Xcode project or workspace (global
/// CLAUDE.md). Copies inside disposable trees (worktrees, pool mirrors) may go
/// with their tree.
fn checkXcode(command: []const u8) Verdict {
    if (!hasRemovalVerb(command) and std.mem.indexOf(u8, command, "git rm") == null and
        std.mem.indexOf(u8, command, "git mv") == null) return null;
    var i: usize = 0;
    while (i < command.len) : (i += 1) {
        const rest = command[i..];
        if (!(std.mem.startsWith(u8, rest, ".xcodeproj") or std.mem.startsWith(u8, rest, ".xcworkspace"))) continue;
        const path = pathAround(command, i);
        // Only an argument of the removal or move itself counts.
        const first = basename(firstWordOfSegment(command, i));
        const segment_moves = isRemovalCommand(command, i) or std.mem.eql(u8, first, "mv") or
            std.mem.eql(u8, first, "unlink") or
            (std.mem.eql(u8, first, "git") and hasWordAny(segmentAround(command, i), &.{ "rm", "mv" }));
        if (!segment_moves) continue;
        if (std.mem.indexOf(u8, path, ".claude/worktrees/") != null) continue;
        if (std.mem.indexOf(u8, path, "crane-work/") != null) continue;
        return "never delete, move or untrack an Xcode project or workspace (*.xcodeproj, *.xcworkspace) unless the user asks for it in that message (global CLAUDE.md)";
    }
    return null;
}

/// `~/crane-work/main` holds the pool's SHARED WPT tree on every host: every
/// mirror's tests/wpt links to it and wpt serve runs in it (2026-11-03).
fn checkSharedWptTree(command: []const u8) Verdict {
    if (!hasWordAny(command, &.{ "rm", "rmdir", "trash" })) return null;
    const needle = "crane-work";
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, command, start, needle)) |at| : (start = at + needle.len) {
        const after = command[at + needle.len ..];
        const end = pathEnd(after);
        const suffix = after[0..end];
        const forbidden = [_][]const u8{
            "",                "/",                "/*",
            "/main",           "/main/",           "/main/*",
            "/main/tests",     "/main/tests/",     "/main/tests/*",
            "/main/tests/wpt", "/main/tests/wpt/", "/main/tests/wpt/*",
        };
        // Only an argument of an rm in its own command segment removes it: a
        // WPT root named elsewhere in a command that also runs rm does not.
        if (!isRemovalCommand(command, at)) continue;
        for (forbidden) |f| {
            if (std.mem.eql(u8, suffix, f))
                return "never remove ~/crane-work/main (or ~/crane-work itself) on any host: its tests/wpt is the SHARED WPT tree every mirror links to and wpt serve runs in (2026-11-03). Remove a lane's mirror by its own name";
        }
    }
    return null;
}

/// `zig build` rules (AGENTS.md "Before every commit"; the user, 2026-10-23
/// and 2026-10-29): never bare, always -j<N>, never a cache in /tmp, and no
/// local builds from a lane (Claude lanes compile in the pool).
fn checkZigBuild(command: []const u8, agent_type: ?[]const u8) Verdict {
    const needle = "zig build";
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, command, start, needle)) |at| : (start = at + needle.len) {
        const after_at = at + needle.len;
        if (after_at < command.len and !isSpace(command[after_at]) and !isSegmentEnd(command[after_at])) continue;
        const start_kind = commandStart(command, at);
        if (start_kind == .none) continue;

        var args = ArgIter{ .text = command[after_at..] };
        var step: ?[]const u8 = null;
        var has_jobs = false;
        var tmp_cache = false;
        var help = false;
        var flags = false;
        var ended_by_quote = false;
        while (args.next()) |tok| {
            if (std.mem.eql(u8, tok, "--")) break;
            if (std.mem.eql(u8, tok, "--help") or std.mem.eql(u8, tok, "-h") or
                std.mem.eql(u8, tok, "-l") or std.mem.eql(u8, tok, "--list-steps")) help = true;
            if (tok.len > 2 and std.mem.startsWith(u8, tok, "-j") and allDigits(tok[2..])) has_jobs = true;
            if (std.mem.startsWith(u8, tok, "--cache-dir=")) {
                if (isTmpPath(tok["--cache-dir=".len..])) tmp_cache = true;
            } else if (std.mem.eql(u8, tok, "--cache-dir")) {
                if (args.next()) |v| {
                    if (isTmpPath(v)) tmp_cache = true;
                }
                flags = true;
                continue;
            }
            if (tok[0] == '-') {
                flags = true;
                if (flagTakesValue(tok)) _ = args.next();
                continue;
            }
            if (step == null) step = tok;
        }
        ended_by_quote = args.ended_by_quote;
        if (help) continue;
        if (step == null) {
            // `grep 'zig build' f` and `pgrep -fl 'zig build|x'` are mentions,
            // not builds: inside quotes, a `zig build` with no step is a
            // pattern or a phrase. A real bare build has flags or ends the
            // command.
            if (start_kind == .quote and !flags) continue;
            if (ended_by_quote and !flags) continue;
            return "never run a bare `zig build` (no step builds all ~19 artifacts at ~6 GB each): name the step, e.g. `zig build wpt-runner -j2 --cache-dir ~/Library/Caches/crane-z16-cache`";
        }
        if (!has_jobs) return "always pass -j2 to `zig build` (AGENTS.md: each root compile is ~6 GB; in a pool job the host's shim adjusts it)";
        if (tmp_cache) return "never put a zig cache in /tmp: macOS prunes it and Zig trusts the half-pruned entries (AGENTS.md). Use ~/Library/Caches/crane-z16-cache";
        // A `zig build` inside quotes is an argument (to ssh, crane-remote.sh, a lane's own wrapper
        // around them), not a command this shell runs (2026-11-03: console1's `remote.sh` wrapper).
        if (isLane(agent_type) and start_kind == .plain and !isRemote(command[0..at]))
            return "lanes compile nothing on this Mac (the user, 2026-10-29): run builds and tests through tmp/remote/crane-remote.sh <mirror> '<cmd>'";
    }
    return null;
}

/// No `git stash` (AGENTS.md: the stash stack is shared by every worktree).
fn checkGitStash(command: []const u8) Verdict {
    var toks = Tokens.init(command);
    while (toks.next()) |t| {
        if (!std.mem.eql(u8, t.text, "git")) continue;
        // Skip git's own options (`-C <dir>`, `-c <k=v>`, `--git-dir=..`),
        // always peeking past the last token consumed.
        var last = t;
        var sub = toks.peekSameSegment(last);
        while (sub) |s| {
            if (std.mem.eql(u8, s.text, "-C") or std.mem.eql(u8, s.text, "-c")) {
                last = toks.next() orelse break;
                last = toks.next() orelse break;
                sub = toks.peekSameSegment(last);
                continue;
            }
            if (std.mem.startsWith(u8, s.text, "--")) {
                last = toks.next() orelse break;
                sub = toks.peekSameSegment(last);
                continue;
            }
            break;
        }
        const s = sub orelse continue;
        if (!std.mem.eql(u8, s.text, "stash")) continue;
        _ = toks.next();
        if (toks.peekSameSegment(s)) |action| {
            if (std.mem.eql(u8, action.text, "list") or std.mem.eql(u8, action.text, "show")) continue;
        }
        return "no `git stash` (AGENTS.md: the stash stack is shared by every worktree): save `git diff -- <files> > tmp/<name>.patch` or make a WIP commit";
    }
    return null;
}

/// Never force-push.
fn checkForcePush(command: []const u8) Verdict {
    var toks = Tokens.init(command);
    while (toks.next()) |t| {
        if (!std.mem.eql(u8, t.text, "push")) continue;
        if (!precededBy(command, t.start, "git")) continue;
        var cur = t;
        while (toks.peekSameSegment(cur)) |a| {
            _ = toks.next();
            cur = a;
            if (std.mem.eql(u8, a.text, "-f") or std.mem.eql(u8, a.text, "--force") or
                std.mem.startsWith(u8, a.text, "--force-with-lease") or
                std.mem.startsWith(u8, a.text, "--force-if-includes") or
                (a.text.len > 1 and a.text[0] == '+'))
                return "never force-push (the user's rule): push a fast-forward, or ask the user";
        }
    }
    return null;
}

/// Kill exact pids only (2026-10-28: a broad pkill on chat may have killed
/// other jobs' compiles).
fn checkBroadKill(command: []const u8) Verdict {
    var toks = Tokens.init(command);
    while (toks.next()) |t| {
        const base = basename(t.text);
        if (!(std.mem.eql(u8, base, "pkill") or std.mem.eql(u8, base, "killall"))) continue;
        if (!isCommandStart(command, t.start)) continue;
        return "kill exact pids only (2026-10-28): find them with `pgrep -fl <pattern>`, check each is yours, then `kill <pid>`";
    }
    return null;
}

/// Never edit upstream WPT (only tests/wpt/crane/ is Crane's) and never patch
/// V8 (jsengines/v8/) - through the shell either.
fn checkProtectedWrites(command: []const u8) Verdict {
    const in_place = std.mem.indexOf(u8, command, "sed -i") != null or
        std.mem.indexOf(u8, command, "perl -pi") != null or
        std.mem.indexOf(u8, command, "perl -i") != null;
    const writes = in_place or hasWordAny(command, &.{ "tee", "cp", "mv", "rm", "truncate" }) or
        std.mem.indexOfScalar(u8, command, '>') != null;
    if (writes) {
        var toks = Tokens.init(command);
        while (toks.next()) |t| {
            const path = std.mem.trimStart(u8, t.text, ">");
            if (isRemovalCommand(command, t.start) and isWptTreeRoot(path))
                return "never remove a tests/wpt tree's contents: a mirror's tests/wpt links to the pool's SHARED tree (2026-11-03). Remove the mirror by its own name";
            if (isUpstreamWptPath(path) and (in_place or isWriteTarget(command, t)) and
                !std.mem.startsWith(u8, basename(firstWordOfSegment(command, t.start)), "rsync"))
                return "never edit upstream WPT: only tests/wpt/crane/ is Crane's (the user's rule). Record Crane tests under tests/wpt/crane/";
            if (std.mem.indexOf(u8, path, "jsengines/v8/") != null and (in_place or isWriteTarget(command, t)))
                return "never patch V8 (jsengines/v8/): read the linked 13.1 with `git -C jsengines/v8/v8 show 13.1.99:<path>`";
        }
    }
    if (std.mem.indexOf(u8, command, "jsengines/v8") != null) {
        for ([_][]const u8{ " apply", " am ", " am\n", " cherry-pick", " commit", " reset --hard", " checkout -- " }) |op| {
            if (std.mem.indexOf(u8, command, op) != null and std.mem.indexOf(u8, command, "git") != null)
                return "never patch V8 (jsengines/v8/): read it, never apply, commit or reset in it";
        }
    }
    return null;
}

// ---------------------------------------------------------------------------
// File tools (Edit, Write, MultiEdit, NotebookEdit)
// ---------------------------------------------------------------------------

/// Checks a file tool's target. `new_text` is what the tool writes (Write's
/// content, Edit's new_string), when the hook input has it.
pub fn checkPath(file_path: []const u8, new_text: ?[]const u8) Verdict {
    if (isUpstreamWptPath(file_path))
        return "never edit upstream WPT: only tests/wpt/crane/ is Crane's (the user's rule). Record Crane tests under tests/wpt/crane/";
    if (std.mem.indexOf(u8, file_path, "jsengines/v8/") != null)
        return "never patch V8 (jsengines/v8/): read the linked 13.1 with `git -C jsengines/v8/v8 show 13.1.99:<path>`";
    if (std.mem.eql(u8, basename(file_path), ".gitignore")) {
        if (new_text) |t| {
            if (std.mem.indexOf(u8, t, "xcodeproj") != null or std.mem.indexOf(u8, t, "xcworkspace") != null)
                return "never add an Xcode project or workspace to .gitignore (global CLAUDE.md)";
        }
    }
    return null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

fn isSegmentEnd(c: u8) bool {
    return c == ';' or c == '&' or c == '|' or c == ')' or c == '\n' or c == '`';
}

fn isQuote(c: u8) bool {
    return c == '\'' or c == '"';
}

fn isPathDelim(c: u8) bool {
    return isSpace(c) or isQuote(c) or isSegmentEnd(c) or c == '(' or c == '>' or c == '<' or c == '=';
}

fn allDigits(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (c < '0' or c > '9') return false;
    return true;
}

fn basename(path: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, path, "'\"");
    const slash = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return trimmed;
    return trimmed[slash + 1 ..];
}

fn isTmpPath(p: []const u8) bool {
    const v = std.mem.trim(u8, p, "'\"");
    return std.mem.startsWith(u8, v, "/tmp") or std.mem.startsWith(u8, v, "/private/tmp");
}

fn flagTakesValue(tok: []const u8) bool {
    const with_value = [_][]const u8{
        "--summary",     "--prefix",         "-p",              "--build-file",
        "--zig-lib-dir", "--global-cache-dir", "--sysroot",     "--search-prefix",
        "--libc",        "--maxrss",         "--prefix-lib-dir", "--prefix-exe-dir",
        "--prefix-include-dir", "--seed",    "--color",         "--build-runner",
    };
    for (with_value) |w| if (std.mem.eql(u8, tok, w)) return true;
    return false;
}

fn isLane(agent_type: ?[]const u8) bool {
    const a = agent_type orelse return false;
    return std.mem.eql(u8, a, "lane") or std.mem.startsWith(u8, a, "lane-");
}

/// Whether the text before a `zig build` sends it to a pool host.
fn isRemote(before: []const u8) bool {
    return std.mem.indexOf(u8, before, "crane-remote.sh") != null or
        std.mem.indexOf(u8, before, "crane-pool.sh") != null or
        std.mem.indexOf(u8, before, "ssh ") != null;
}

/// The path-like word containing byte `i`.
fn pathAround(text: []const u8, i: usize) []const u8 {
    var s = i;
    while (s > 0 and !isPathDelim(text[s - 1])) s -= 1;
    var e = i;
    while (e < text.len and !isPathDelim(text[e])) e += 1;
    return text[s..e];
}

fn pathEnd(text: []const u8) usize {
    var e: usize = 0;
    while (e < text.len and !isPathDelim(text[e])) e += 1;
    return e;
}

/// `tests/wpt/` or `tests/wpt/*`: the tree's contents, which `rm -rf` follows
/// through a mirror's link to the shared tree.
fn isWptTreeRoot(path_in: []const u8) bool {
    const path = std.mem.trim(u8, path_in, "'\"");
    return std.mem.endsWith(u8, path, "tests/wpt/") or std.mem.endsWith(u8, path, "tests/wpt/*");
}

fn isUpstreamWptPath(path_in: []const u8) bool {
    const path = std.mem.trim(u8, path_in, "'\"");
    const at = if (std.mem.startsWith(u8, path, "tests/wpt/"))
        0
    else if (std.mem.indexOf(u8, path, "/tests/wpt/")) |p| p + 1 else return false;
    const rest = path[at + "tests/wpt/".len ..];
    if (rest.len == 0) return false;
    return !std.mem.startsWith(u8, rest, "crane/");
}

/// Whether the command has `word` as a whole word (a command or argument).
fn hasWord(command: []const u8, word: []const u8) bool {
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, command, start, word)) |at| : (start = at + 1) {
        const before_ok = at == 0 or isPathDelim(command[at - 1]) or command[at - 1] == '/';
        const end = at + word.len;
        const after_ok = end == command.len or isSpace(command[end]) or isSegmentEnd(command[end]) or isQuote(command[end]);
        if (before_ok and after_ok) return true;
    }
    return false;
}

fn hasWordAny(command: []const u8, words: []const []const u8) bool {
    for (words) |w| if (hasWord(command, w)) return true;
    return false;
}

fn hasRemovalVerb(command: []const u8) bool {
    return hasWordAny(command, &removal_verbs);
}

/// Words that may stand before a command without being the command.
fn isWrapperWord(w: []const u8) bool {
    const wrappers = [_][]const u8{
        "time", "/usr/bin/time", "-l", "-p", "nice", "-n", "exec", "command", "env",
        "then", "do", "else", "timeout", "sudo", "nohup", "!",
    };
    for (wrappers) |x| if (std.mem.eql(u8, w, x)) return true;
    if (allDigits(w)) return true;
    // VAR=value assignments
    if (std.mem.indexOfScalar(u8, w, '=')) |eq| {
        if (eq > 0) {
            for (w[0..eq]) |c| if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;
            return true;
        }
    }
    return false;
}

/// Whether the word at `pos` starts a command: everything between the start
/// of its segment (the command's start, `;`, `&`, `|`, `(`, a quote, a
/// newline) and it is wrapper words such as `time`, `timeout 300`, `VAR=x`.
fn isCommandStart(command: []const u8, pos: usize) bool {
    return commandStart(command, pos) != .none;
}

const StartKind = enum { none, plain, quote };

/// How the word at `pos` starts a command: after the start of the command or
/// a `;` `&` `|` `(` newline (`.plain`), right after a quote (`.quote`: inside
/// a quoted string, where it may be a remote command or only a phrase), or
/// not at all.
fn commandStart(command: []const u8, pos: usize) StartKind {
    var i = pos;
    while (i > 0) {
        const c = command[i - 1];
        if (isSegmentEnd(c) or c == '(') return .plain;
        if (isQuote(c)) return .quote;
        if (isSpace(c)) {
            i -= 1;
            continue;
        }
        // a word: find its start and check it
        var s = i;
        while (s > 0 and !isSpace(command[s - 1]) and !isSegmentEnd(command[s - 1]) and command[s - 1] != '(' and !isQuote(command[s - 1])) s -= 1;
        if (!isWrapperWord(command[s..i])) return .none;
        i = s;
    }
    return .plain;
}

fn precededBy(command: []const u8, pos: usize, word: []const u8) bool {
    var i = pos;
    while (i > 0 and isSpace(command[i - 1])) i -= 1;
    // skip `git -C <dir>` style options between git and the subcommand
    var guard: usize = 0;
    while (guard < 8) : (guard += 1) {
        var s = i;
        while (s > 0 and !isSpace(command[s - 1]) and !isSegmentEnd(command[s - 1]) and !isQuote(command[s - 1])) s -= 1;
        const w = command[s..i];
        if (std.mem.eql(u8, w, word)) return true;
        if (w.len == 0) return false;
        i = s;
        while (i > 0 and isSpace(command[i - 1])) i -= 1;
        if (i == 0 or isSegmentEnd(command[i - 1])) {
            const s2 = s;
            _ = s2;
            return false;
        }
    }
    return false;
}

/// The command segment containing `pos`: from the last `;` `&` `|` `(`
/// newline or quote before it to the next segment end after it.
fn segmentAround(command: []const u8, pos: usize) []const u8 {
    var s = pos;
    while (s > 0 and !isSegmentEnd(command[s - 1]) and !isQuote(command[s - 1]) and command[s - 1] != '(') s -= 1;
    var e = pos;
    while (e < command.len and !isSegmentEnd(command[e])) e += 1;
    return command[s..e];
}

/// Whether the command segment containing `pos` is an rm, rmdir or trash.
fn isRemovalCommand(command: []const u8, pos: usize) bool {
    const first = basename(firstWordOfSegment(command, pos));
    return std.mem.eql(u8, first, "rm") or std.mem.eql(u8, first, "rmdir") or std.mem.eql(u8, first, "trash");
}

fn firstWordOfSegment(command: []const u8, pos: usize) []const u8 {
    var s = pos;
    while (s > 0 and !isSegmentEnd(command[s - 1]) and !isQuote(command[s - 1])) s -= 1;
    while (s < command.len and isSpace(command[s])) s += 1;
    var e = s;
    while (e < command.len and !isSpace(command[e])) e += 1;
    return command[s..e];
}

fn isWriteTarget(command: []const u8, t: Token) bool {
    // the token follows a redirect or is an argument of tee/cp/mv/rm
    var i = t.start;
    while (i > 0 and isSpace(command[i - 1])) i -= 1;
    if (i > 0 and command[i - 1] == '>') return true;
    if (t.text.len > 0 and t.text[0] == '>') return true;
    const first = basename(firstWordOfSegment(command, t.start));
    for ([_][]const u8{ "tee", "rm", "truncate" }) |v| if (std.mem.eql(u8, first, v)) return true;
    // cp and mv write only their last argument
    if (std.mem.eql(u8, first, "cp") or std.mem.eql(u8, first, "mv")) {
        var e = t.end;
        while (e < command.len and isSpace(command[e]) and command[e] != '\n') e += 1;
        return e >= command.len or isSegmentEnd(command[e]) or isQuote(command[e]);
    }
    return false;
}

const Token = struct { text: []const u8, start: usize, end: usize };

/// Whitespace tokens with their offsets; quote characters at either end are
/// stripped from `text`.
const Tokens = struct {
    command: []const u8,
    pos: usize = 0,

    fn init(command: []const u8) Tokens {
        return .{ .command = command };
    }

    fn scan(self: *const Tokens, from: usize) ?Token {
        var i = from;
        while (i < self.command.len and (isSpace(self.command[i]) or isQuote(self.command[i]) or self.command[i] == '(')) i += 1;
        if (i >= self.command.len) return null;
        var e = i;
        while (e < self.command.len and !isSpace(self.command[e]) and !isQuote(self.command[e])) e += 1;
        var text = self.command[i..e];
        text = std.mem.trimEnd(u8, text, ";&|)`");
        return .{ .text = text, .start = i, .end = e };
    }

    fn next(self: *Tokens) ?Token {
        const t = self.scan(self.pos) orelse return null;
        self.pos = t.end;
        return t;
    }

    /// The next token, when nothing between `after` and it ends the segment.
    fn peekSameSegment(self: *const Tokens, after: Token) ?Token {
        const t = self.scan(after.end) orelse return null;
        for (self.command[after.end..t.start]) |c| if (isSegmentEnd(c)) return null;
        for (self.command[after.start..after.end]) |c| if (isSegmentEnd(c)) return null;
        return t;
    }
};

/// Arguments after `zig build`, up to the end of its command segment.
const ArgIter = struct {
    text: []const u8,
    pos: usize = 0,
    ended_by_quote: bool = false,
    done: bool = false,

    fn next(self: *ArgIter) ?[]const u8 {
        if (self.done) return null;
        while (self.pos < self.text.len and (self.text[self.pos] == ' ' or self.text[self.pos] == '\t')) self.pos += 1;
        if (self.pos >= self.text.len) {
            self.done = true;
            return null;
        }
        const c = self.text[self.pos];
        if (isSegmentEnd(c)) {
            self.done = true;
            return null;
        }
        if (isQuote(c)) {
            self.ended_by_quote = true;
            self.done = true;
            return null;
        }
        var e = self.pos;
        while (e < self.text.len and !isSpace(self.text[e]) and !isSegmentEnd(self.text[e]) and !isQuote(self.text[e])) e += 1;
        const tok = self.text[self.pos..e];
        self.pos = e;
        if (e < self.text.len and isQuote(self.text[e])) {
            self.ended_by_quote = true;
            self.done = true;
        }
        return tok;
    }
};

// ---------------------------------------------------------------------------
// The hook
// ---------------------------------------------------------------------------

pub fn main(init: std.process.Init) void {
    run(init) catch {};
    std.process.exit(0);
}

fn run(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    var reader = std.Io.File.stdin().reader(io, &.{});
    const input = try reader.interface.allocRemaining(allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(input);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, input, .{});
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |o| o,
        else => return,
    };
    const tool = stringField(root, "tool_name") orelse return;
    const tool_input = switch (root.get("tool_input") orelse return) {
        .object => |o| o,
        else => return,
    };
    const agent_type = stringField(root, "agent_type");

    var verdict: Verdict = null;
    if (std.mem.eql(u8, tool, "Bash")) {
        if (stringField(tool_input, "command")) |cmd| verdict = checkBash(cmd, agent_type);
    } else if (std.mem.eql(u8, tool, "Edit") or std.mem.eql(u8, tool, "Write") or
        std.mem.eql(u8, tool, "MultiEdit") or std.mem.eql(u8, tool, "NotebookEdit"))
    {
        const path = stringField(tool_input, "file_path") orelse stringField(tool_input, "notebook_path") orelse return;
        const text = stringField(tool_input, "content") orelse stringField(tool_input, "new_string");
        verdict = checkPath(path, text);
    }
    if (verdict) |reason| {
        const stderr = std.Io.File.stderr();
        stderr.writeStreamingAll(io, "crane_guard: ") catch {};
        stderr.writeStreamingAll(io, reason) catch {};
        stderr.writeStreamingAll(io, "\n") catch {};
        std.process.exit(2);
    }
}

fn stringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    return switch (obj.get(key) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

// ---------------------------------------------------------------------------
// Tests: every rule's denials AND the look-alikes it must let through.
// ---------------------------------------------------------------------------

fn expectDenied(cmd: []const u8, agent: ?[]const u8) !void {
    if (checkBash(cmd, agent) == null) {
        std.debug.print("expected DENY: {s}\n", .{cmd});
        return error.TestExpectedDeny;
    }
}

fn expectAllowed(cmd: []const u8, agent: ?[]const u8) !void {
    if (checkBash(cmd, agent)) |why| {
        std.debug.print("expected ALLOW: {s}\n  denied: {s}\n", .{ cmd, why });
        return error.TestExpectedAllow;
    }
}

test "xcode projects: deleting, moving or untracking one is refused; a disposable tree's copy may go" {
    try expectDenied("rm -rf bindings/swift/.swiftpm/xcode/package.xcworkspace", null);
    try expectDenied("git rm -r --cached ios/Dine.xcodeproj", null);
    try expectDenied("mv ios/App.xcodeproj /tmp/", null);
    try expectAllowed("rm -rf .claude/worktrees/lane/ios/App.xcodeproj", null);
    try expectAllowed("ssh chat.local 'rm -rf ~/crane-work/lane/bindings/swift/.swiftpm/xcode/package.xcworkspace'", null);
    try expectAllowed("git worktree remove .claude/worktrees/x", null);
    try expectAllowed("ls bindings/swift/.swiftpm/xcode/package.xcworkspace", null);
    try expectAllowed("xcodegen generate && open ios/App.xcodeproj", null);
    try expectAllowed("rm -f /tmp/x.log && open ios/App.xcodeproj", null);
    try expectAllowed("git log -- ios/App.xcodeproj && rm -rf tmp/scratch", null);
}

test "the pool's shared WPT tree: removing crane-work/main is refused; a lane's mirror or main's cache may go" {
    try expectDenied("ssh chat2.local 'rm -rf ~/crane-work/main'", null);
    try expectDenied("rm -rf ~/crane-work/main/", null);
    try expectDenied("rm -rf ~/crane-work/main/tests/wpt", null);
    try expectDenied("ssh chat.local 'rm -rf ~/crane-work/*'", null);
    try expectDenied("ssh chat2.local \"rm -rf ~/crane-work/main ~/crane-caches/main\"", null);
    try expectAllowed("ssh chat.local 'rm -rf ~/crane-work/main/tmp/f-build.log'", null);
    try expectAllowed("ssh chat2.local 'rm -rf ~/crane-caches/main'", null);
    try expectAllowed("ssh chat.local 'rm -rf ~/crane-work/crashes7 ~/crane-work/crashes7-bins'", null);
    try expectAllowed("rsync -a --delete tests/wpt/ host:crane-work/main/tests/wpt/", null);
    try expectAllowed("ls ~/crane-work/main/tests/wpt", null);
    // 2026-11-03 (streamslife1): the shared tree named as a WPT root in a
    // heredoc, with an unrelated rm elsewhere in the command, is not a removal.
    try expectAllowed("cat > prof.sh <<'EOF'\nW=$HOME/crane-work/main/tests/wpt\n./wpt_runner --wpt-root=$W x.html\nEOF\ntmp/remote/crane-pool.sh wpt sl1 --pair p \"bash prof.sh; rm -f /tmp/sl1-prof.sh\"", null);
    try expectAllowed("rm -f /tmp/x.log && ./zig-out/bin/wpt_runner --wpt-root=$HOME/crane-work/main/tests/wpt a.html", null);
    try expectDenied("cd ~ && rm -rf crane-work/main", null);
}

test "zig build: bare, without -j, or with a /tmp cache is refused" {
    try expectDenied("zig build", null);
    try expectDenied("zig build -j2", null);
    try expectDenied("zig build test", null);
    try expectDenied("cd .claude/worktrees/x && zig build test --summary all", null);
    try expectDenied("zig build test -j2 --cache-dir /tmp/zc", null);
    try expectDenied("timeout 600 zig build test --cache-dir=/private/tmp/z", null);
    try expectAllowed("zig build test -j2 --cache-dir ~/Library/Caches/crane-z16-cache", null);
    try expectAllowed("zig build wpt-runner -j2 -Doptimize=ReleaseSafe", null);
    try expectAllowed("ZIG_GLOBAL_CACHE_DIR=x zig build repl-exe -j2", null);
}

test "zig build: mentions in text, help and other zig commands are not builds" {
    try expectAllowed("grep -n 'zig build' AGENTS.md", null);
    try expectAllowed("git commit -m \"merge: gates: zig build test 479/479\"", null);
    try expectAllowed("echo Gates: zig build test passed", null);
    try expectAllowed("zig build --help", null);
    try expectAllowed("zig build -l", null);
    try expectAllowed("zig fmt src/ tests/ tools/", null);
    try expectAllowed("zig test .claude/hooks/crane_guard.zig", null);
    try expectAllowed("tmp/remote/crane-remote.sh main 'zig build test -j2'", null);
}

test "zig build: a lane builds in the pool, never on the Mac; the main conversation may build locally" {
    try expectDenied("zig build test -Dspec=dom -j2", "lane-xhigh");
    try expectDenied("cd /x && zig build wpt-runner -j2", "lane");
    try expectAllowed("tmp/remote/crane-remote.sh console1 'zig build test -Dspec=repl -j2'", "lane-xhigh");
    try expectAllowed("ssh chat.local 'cd ~/crane-work/m && zig build test -j2'", "lane-xhigh");
    try expectAllowed("zig build test -Dspec=dom -j2", null);
    try expectAllowed("zig build test -Dspec=dom -j2", "Explore");
    try expectAllowed("zig fmt src/", "lane-xhigh");
    // 2026-11-03 (console1): a lane's wrapper around crane-remote.sh takes the build as an argument.
    try expectAllowed("/Users/x/crane/tmp/console1/remote.sh summary 'zig build test -j2 --summary line'", "lane-xhigh");
}

test "a heredoc that cat or tee writes to a file is data, not commands; one fed to a shell is commands" {
    // 2026-11-03 (streamslife1): a lane writing a pool script with a heredoc
    // was refused as a local build.
    try expectAllowed("cat > tmp/x.sh <<'EOF'\ncd ~/m && zig build test -Dspec=dom -j2\nEOF\ntmp/remote/crane-remote.sh m 'bash tmp/x.sh'", "lane-xhigh");
    try expectAllowed("cat <<EOF > notes.txt\nrm -rf ~/crane-work/main\nEOF", null);
    try expectAllowed("tee tmp/y.sh <<-'END' >/dev/null\n\tzig build\n\tEND", null);
    try expectDenied("bash <<'EOF'\nzig build test -j2\nEOF", "lane-xhigh");
    try expectDenied("cat <<EOF > f\nhi\nEOF\nrm -rf ~/crane-work/main", null);
}

test "git stash is refused, except list and show" {
    try expectDenied("git stash", null);
    try expectDenied("git stash pop", null);
    try expectDenied("git -C .claude/worktrees/x stash push -u -m wip", null);
    try expectDenied("cd x && git stash && make", null);
    try expectAllowed("git stash list", null);
    try expectAllowed("git stash show -p stash@{0}", null);
    try expectAllowed("git status --short", null);
}

test "force-push is refused; a normal push is not" {
    try expectDenied("git push --force origin main", null);
    try expectDenied("git push -f origin lane/x", null);
    try expectDenied("git push origin +main", null);
    try expectDenied("git -C tests/wpt push --force-with-lease origin main", null);
    try expectAllowed("git push origin main gh-pages", null);
    try expectAllowed("git push origin main && git log -1", null);
}

test "pkill and killall are refused; exact pids are not" {
    try expectDenied("ssh chat.local 'pkill -f wpt_runner'", null);
    try expectDenied("killall zig", null);
    try expectDenied("sleep 1; pkill -f gc_bench", null);
    try expectAllowed("kill 1234 5678", null);
    try expectAllowed("pgrep -fl 'zig build|wpt_runner'", null);
    try expectAllowed("grep -n pkill docs/lessons/README.md", null);
}

test "the TypeSafe key is never named in a command" {
    try expectDenied("echo $TYPESAFE_API_KEY", null);
    try expectDenied("printenv TYPESAFE_API_KEY", null);
    try expectAllowed("zsh -ic \"cd tmp/orchestration && python3 jev.py lessons briefs/x.md --top 12\"", null);
}

test "upstream WPT and V8 are never written from the shell" {
    try expectDenied("sed -i '' 's/a/b/' tests/wpt/dom/x.html", null);
    try expectDenied("echo hi > tests/wpt/html/x.js", null);
    try expectDenied("cp tmp/x.html /Users/me/crane/tests/wpt/dom/nodes/x.html", null);
    try expectDenied("ssh chat.local 'rm -rf ~/crane-work/lane/tests/wpt/'", null);
    try expectDenied("perl -pi -e 's/a/b/' jsengines/v8/include/v8.h", null);
    try expectDenied("git -C jsengines/v8/v8 apply fix.patch", null);
    try expectAllowed("sed -n 1,5p tests/wpt/dom/x.html", null);
    try expectAllowed("sed -i '' 's/a/b/' tests/wpt/crane/x.html", null);
    try expectAllowed("cp tmp/x.html tests/wpt/crane/x.html", null);
    try expectAllowed("cp tests/wpt/dom/x.html tmp/x.html", null);
    try expectDenied("cp tmp/x.html tests/wpt/dom/x.html && ls", null);
    try expectAllowed("git -C jsengines/v8/v8 show 13.1.99:src/api/api.cc | head", null);
    try expectAllowed("ls tests/wpt_runner/ > tmp/list.txt", null);
    try expectAllowed("cat tests/wpt/dom/x.html > tmp/x.html", null);
}

test "file tools: upstream WPT, V8 and an Xcode .gitignore entry are refused" {
    try std.testing.expect(checkPath("/Users/me/projects/crane/tests/wpt/dom/foo.html", null) != null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/.claude/worktrees/l/tests/wpt/html/x.js", null) != null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/jsengines/v8/include/v8.h", null) != null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/.gitignore", "*.xcodeproj\n") != null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/tests/wpt/crane/foo.html", null) == null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/tests/wpt_runner/main.zig", null) == null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/src/dom/hook.zig", null) == null);
    try std.testing.expect(checkPath("/Users/me/projects/crane/.gitignore", "zig-out/\n") == null);
}
