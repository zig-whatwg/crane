//! HTML Module with Full Interface Access
//!
//! This module provides the complete HTML specification implementation with
//! access to WebIDL interfaces. It re-exports everything from html_core plus
//! provides access to interfaces and impls for script execution.
//!
//! ## Module Architecture
//!
//! ```
//! html_core_mod ← infra, dom, platform (NO interfaces)
//!      ↓
//! impls_mod ← html_core_mod, interfaces_mod, ...
//!      ↓
//! html_mod ← html_core_mod, interfaces_mod (CAN use interfaces)
//! ```
//!
//! This layering ensures no cycles:
//! - impls imports html_core (not html), so no cycle with interfaces
//! - html imports interfaces, but html is not imported by impls
//!
//! ## Usage
//!
//! For external consumers (tests, applications):
//! ```zig
//! const html = @import("html");  // Gets full HTML with interfaces
//! ```
//!
//! For impls (internal WebIDL implementations):
//! ```zig
//! const html_core = @import("html_core");  // Gets interface-free HTML core
//! ```

const std = @import("std");

// Re-export all of html_core via module import (not file import)
// This ensures Zig sees html_core as one module, not two modules owning same files
const core = @import("html_core");

// Event Loop (§8.1.7)
pub const event_loop = core.event_loop;

// Re-export commonly used types
pub const EventLoop = core.EventLoop;
pub const EventLoopType = core.EventLoopType;
pub const Task = core.Task;
pub const TaskSource = core.TaskSource;
pub const Microtask = core.Microtask;
pub const Timer = core.Timer;
pub const TimerManager = core.TimerManager;
pub const VisibilityState = core.VisibilityState;
pub const RenderingCallbacks = core.RenderingCallbacks;

// Parser (§13)
pub const parser = core.parser;

// Re-export commonly used parser types
pub const Tokenizer = core.Tokenizer;
pub const TreeBuilder = core.TreeBuilder;
pub const Token = core.Token;
pub const TagToken = core.TagToken;
pub const DoctypeToken = core.DoctypeToken;
pub const CommentToken = core.CommentToken;
pub const ParseError = core.ParseError;
pub const ParseErrorCode = core.ParseErrorCode;
pub const ParseErrorCollector = core.ParseErrorCollector;

// Fragment parsing (§13.5 - innerHTML, DOMParser, etc.)
pub const parseFragment = core.parseFragment;
pub const parseHTMLFromString = core.parseHTMLFromString;
pub const FragmentParseResult = core.FragmentParseResult;
pub const FragmentParseOptions = core.FragmentParseOptions;

// Document write support (§8.4 - document.write/writeln/open/close)
pub const DocumentWriteState = core.DocumentWriteState;
pub const DocumentWriteError = core.DocumentWriteError;
pub const documentOpen = core.documentOpen;
pub const documentWrite = core.documentWrite;
pub const documentWriteln = core.documentWriteln;
pub const documentClose = core.documentClose;

// Custom Elements
pub const custom_elements = core.custom_elements;

// Structured Clone (§2.7)
pub const structured_clone = core.structured_clone;

// Re-export commonly used structured clone types
pub const structuredClone = core.structuredClone;
pub const structuredSerialize = core.structuredSerialize;
pub const structuredDeserialize = core.structuredDeserialize;
pub const CloneError = core.CloneError;
pub const SerializedValue = core.SerializedValue;
pub const Transferable = core.Transferable;

// Window & Global Environment (§7)
pub const window = core.window;

// Re-export commonly used window types
pub const BrowsingContext = core.BrowsingContext;
pub const BrowsingContextGroup = core.BrowsingContextGroup;
pub const UIBackend = core.UIBackend;
pub const StubUIBackend = core.StubUIBackend;
pub const AnimationFrameScheduler = core.AnimationFrameScheduler;
pub const FrameTimingBackend = core.FrameTimingBackend;
pub const StubFrameTimingBackend = core.StubFrameTimingBackend;
pub const MockFrameTimingBackend = core.MockFrameTimingBackend;
pub const DOMHighResTimeStamp = core.DOMHighResTimeStamp;

// ============================================================================
// Interface Access (NOT available in html_core)
// ============================================================================

// Access to interfaces module - available for script execution files
// when they are moved back to src/html/ from src/webidl/impls/
pub const interfaces = @import("interfaces");

// Access to impls module - for script execution coordination
pub const impls = @import("impls");

// Access to runtime module - for JS execution context
pub const runtime = @import("runtime");

// ============================================================================
// Script Execution (HTML §4.12.1.1)
// ============================================================================

// These modules implement the HTML script processing model.
// They're in src/html/ because they legitimately need interfaces access.

/// Script execution algorithms (prepare/execute script element)
pub const script_execution = @import("script_execution.zig");

/// Script runner for coordinating script scheduling
pub const script_runner = @import("script_runner.zig");

/// Event utilities for firing events during script processing
pub const event_utils = @import("event_utils.zig");

test {
    std.testing.refAllDecls(@This());
}
