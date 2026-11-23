//! A Browser's user prompts as its host sees them: WebDriver BiDi's "user
//! prompt opened" and "user prompt closed" (webdriver-bidi.md), which HTML's
//! simple dialogs invoke (8.9.1 alert, confirm, prompt; "prompt to unload"
//! for beforeunload), told to the Browser's one hook slot
//! (`Navigables.user_prompts`), which the Browser sets to its own dispatcher
//! and fans out from (lane cdph; the shape agreed with lane cdpt through the
//! integrator, 8:06 PM ET 2026-11-21). Generic: CDP's Page dialogs, WebDriver
//! classic's user prompt commands and an embedder's UI all answer through
//! the same `DialogAnswer`.
//!
//! The steps themselves - the checks, the pause, the platform's default
//! answer - are src/html/simple_dialogs.zig's.
const std = @import("std");
const browsing_context = @import("../window/browsing_context.zig");

const Navigables = browsing_context.Navigables;

/// The kind of a user prompt (WebDriver BiDi's session.UserPromptType, less
/// "file": a file chooser is no simple dialog).
pub const Kind = enum { alert, confirm, prompt, beforeunload };

/// How a host answers an open prompt: from ANY thread, at most once.
/// `answer(context, accept, prompt_text)` completes the answer the paused
/// Browser thread waits for and copies `prompt_text`; it returns false when
/// the prompt was already answered or has closed. Its context is the
/// Browser's pending-prompt record, which outlives every prompt.
pub const DialogAnswer = struct {
    context: *anyopaque,
    answer: *const fn (context: *anyopaque, accept: bool, prompt_text: []const u8) bool,

    pub fn call(self: DialogAnswer, accept: bool, prompt_text: []const u8) bool {
        return self.answer(self.context, accept, prompt_text);
    }
};

/// A prompt opening, before the Browser thread pauses for it. Every slice
/// BORROWED for the call.
pub const Opening = struct {
    /// The prompt's top-level traversable (its tab) and its own navigable.
    tab: u64,
    navigable: u64,
    kind: Kind,
    message: []const u8,
    /// prompt()'s default; empty otherwise.
    default_prompt: []const u8,
    /// The URL of the document that opened it.
    url: []const u8,
    answer: DialogAnswer,
    /// A host that will answer the prompt itself through `answer` - a CDP
    /// session with the Page domain enabled (Chrome waits for
    /// Page.handleJavaScriptDialog), a WebDriver session - sets this. Left
    /// false by everyone, the platform's own dialog answers.
    claim: *bool,
};

/// A prompt closed: after its answer, whoever gave it.
pub const Closed = struct {
    tab: u64,
    navigable: u64,
    kind: Kind,
    accepted: bool,
    /// What a prompt was answered with; empty otherwise. BORROWED.
    user_input: []const u8,
};

/// The Browser's hook (`Navigables.user_prompts`).
pub const Hook = struct {
    context: *anyopaque,
    opening: *const fn (context: *anyopaque, opening: *const Opening) void,
    closed: *const fn (context: *anyopaque, closed: *const Closed) void,
};

/// Tell `navigables`' hook that a prompt opens.
pub fn opened(navigables: ?*const Navigables, opening: *const Opening) void {
    const list = navigables orelse return;
    const hook = list.user_prompts orelse return;
    hook.opening(hook.context, opening);
}

/// Tell it the prompt closed.
pub fn closed(navigables: ?*const Navigables, closing: *const Closed) void {
    const list = navigables orelse return;
    const hook = list.user_prompts orelse return;
    hook.closed(hook.context, closing);
}
