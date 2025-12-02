//! HTML Specification Implementation
//!
//! Spec: https://html.spec.whatwg.org/
//! HTML Living Standard
//!
//! This module provides implementations of various parts of the HTML specification:
//!
//! - **Event Loop** (§8.1.7) - Core event loop for coordinating events, scripts,
//!   rendering, and more
//! - **Timers** (§8.6) - setTimeout() and setInterval()
//! - **Parser** (§13) - HTML parsing algorithm with tokenizer and tree builder
//! - **Custom Elements** - Custom element registry and lifecycle
//!
//! ## Architecture
//!
//! The HTML module is organized around the key concepts from the spec:
//!
//! ```
//! src/html/
//! ├── event_loop/          # Event loop, task queues, microtasks, timers
//! │   ├── event_loop.zig   # Main EventLoop struct
//! │   ├── task.zig         # Task and TaskSource definitions
//! │   ├── task_queue.zig   # TaskQueue and TaskQueueSet
//! │   ├── microtask.zig    # Microtask queue and checkpoint
//! │   ├── timers.zig       # setTimeout/setInterval
//! │   └── root.zig         # Module exports
//! ├── parser/              # HTML parser (§13)
//! │   ├── tokenizer.zig    # Tokenization state machine (80 states)
//! │   ├── tokens.zig       # Token types (DOCTYPE, Tag, Comment, etc.)
//! │   ├── tokenizer_states.zig  # State enum and helpers
//! │   ├── parse_errors.zig # Parse error codes and handling
//! │   ├── input_stream.zig # Input preprocessing
//! │   └── root.zig         # Module exports
//! ├── custom_elements.zig  # Custom element definitions
//! └── root.zig             # This file
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const html = @import("html/root.zig");
//! const timer_backend = @import("platform/timer_backend.zig");
//!
//! // Create event loop
//! const platform = try timer_backend.RealTimerBackend.init(allocator);
//! var event_loop = try html.EventLoop.init(allocator, .window, platform.backend());
//! defer event_loop.deinit();
//!
//! // Queue tasks
//! _ = try event_loop.queueTask(.dom_manipulation, callback, context, null);
//!
//! // Set timers
//! _ = try event_loop.setTimeout(timerCallback, 1000, null);
//!
//! // Run
//! try event_loop.run();
//! ```

const std = @import("std");

// Event Loop (§8.1.7)
pub const event_loop = @import("event_loop/root.zig");

// Re-export commonly used types
pub const EventLoop = event_loop.EventLoop;
pub const EventLoopType = event_loop.EventLoopType;
pub const Task = event_loop.Task;
pub const TaskSource = event_loop.TaskSource;
pub const Microtask = event_loop.Microtask;
pub const Timer = event_loop.Timer;
pub const TimerManager = event_loop.TimerManager;
pub const VisibilityState = event_loop.VisibilityState;
pub const RenderingCallbacks = event_loop.RenderingCallbacks;

// Parser (§13)
pub const parser = @import("parser/root.zig");

// Re-export commonly used parser types
pub const Tokenizer = parser.Tokenizer;
pub const TreeBuilder = parser.TreeBuilder;
pub const Token = parser.Token;
pub const TagToken = parser.TagToken;
pub const DoctypeToken = parser.DoctypeToken;
pub const CommentToken = parser.CommentToken;
pub const ParseError = parser.ParseError;
pub const ParseErrorCode = parser.ParseErrorCode;
pub const ParseErrorCollector = parser.ParseErrorCollector;

// Fragment parsing (§13.5 - innerHTML, DOMParser, etc.)
pub const parseFragment = parser.parseFragment;
pub const parseHTMLFromString = parser.parseHTMLFromString;
pub const FragmentParseResult = parser.FragmentParseResult;
pub const FragmentParseOptions = parser.FragmentParseOptions;

// Document write support (§8.4 - document.write/writeln/open/close)
pub const DocumentWriteState = parser.DocumentWriteState;
pub const DocumentWriteError = parser.DocumentWriteError;
pub const documentOpen = parser.documentOpen;
pub const documentWrite = parser.documentWrite;
pub const documentWriteln = parser.documentWriteln;
pub const documentClose = parser.documentClose;

// Custom Elements
pub const custom_elements = @import("custom_elements.zig");

// Script Execution (§4.12.1)
pub const script_execution = @import("script_execution.zig");

// Re-export script execution types
pub const prepareScriptElement = script_execution.prepareScriptElement;
pub const executeScriptElement = script_execution.executeScriptElement;
pub const ScriptExecutionError = script_execution.ScriptExecutionError;

test {
    std.testing.refAllDecls(@This());
}
