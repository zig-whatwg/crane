# V8 Context Management Pattern

## Overview

This document describes how we manage V8 JavaScript contexts to ensure proper global scope sharing between scripts. The approach follows the "enter once, stay entered" pattern used by LightPanda and Chromium.

## The Problem

When running Web Platform Tests (WPT), `testharness.js` defines global functions like `setup()`, `test()`, and `assert_true()`. These must be accessible to inline scripts in the test HTML. If scripts don't share the same global scope, you get "ReferenceError: setup is not defined" errors.

The root cause is improper V8 context management:
- **Wrong**: Enter context for script A, exit, enter for script B (separate globals)
- **Right**: Enter context once, stay entered for all scripts (shared global)

## The "Enter Once, Stay Entered" Pattern

### How It Works

1. **Context Entry at Creation**: When a browsing context (page/iframe) is created, we enter the V8 context immediately and keep it entered.

2. **Persistent Entry**: The context stays entered throughout the page's lifetime. All script executions use this already-entered context.

3. **Exit Only at Destruction**: The context is only exited when the browsing context is destroyed (page navigated away, iframe removed, etc.).

### Why This Pattern?

This pattern is used by:
- **LightPanda**: Their `ExecutionWorld.zig` enters context once at creation
- **Chromium/Blink**: V8 bindings follow the same model

Benefits:
- All scripts share the same global object
- No accidental global scope isolation
- Simpler mental model (context entry = page lifetime)
- Matches how browsers actually work

## Key Invariants

1. **Context is entered immediately after creation**
   - `Browser.Context.init()` calls `ensureContextEntered()` after creating the V8 context

2. **Context stays entered until page destruction**
   - `is_entered` flag tracks state
   - `ensureContextEntered()` is idempotent (safe to call multiple times)

3. **All scripts execute in the entered context**
   - Script execution doesn't need to enter/exit
   - HTML parser, event handlers, setTimeout callbacks all use the same entered context

4. **HandleScopes are per-operation, context entry is persistent**
   - HandleScopes manage V8 handle lifetimes (temporary, per-operation)
   - Context entry manages global scope (persistent, per-page)
   - Don't confuse these two concepts

## Implementation Details

### Context Manager Functions

```zig
// src/runtime/engines/v8/context_manager.zig

/// Enter context if not already entered (idempotent)
pub fn ensureContextEntered(v8_ctx: *v8.Context) void

/// Mark context as exited (called during destruction)
pub fn markContextExited(v8_ctx: *v8.Context) void

/// Check if context is currently entered
pub fn isContextEntered(v8_ctx: *v8.Context) bool

/// Assert context is entered (debug only, panics if not)
pub fn assertContextEntered(v8_ctx: *v8.Context) void
```

### Browser.Context Integration

```zig
// src/browser/Context.zig

pub fn init(allocator: Allocator, ...) !*Context {
    // Create V8 context
    const v8_ctx = v8.createContext(...);
    
    // Immediately enter and stay entered
    context_manager.ensureContextEntered(v8_ctx);
    
    return context;
}

pub fn deinit(self: *Context) void {
    // Exit context during destruction
    context_manager.markContextExited(self.v8_ctx);
    
    // ... cleanup ...
}
```

### ContextEntry State

```zig
pub const ContextEntry = struct {
    v8_ctx: *v8.Context,
    runtime_ctx: runtime.ContextData,
    
    /// Whether this V8 context is currently entered.
    /// Tracks the "enter once, stay entered" pattern.
    is_entered: bool = false,
    
    // ... other fields ...
};
```

## Debug Tools

### Enable Debug Output

```bash
# Enable all v8 debug output
zig build test -Ddebug=true -Ddebug-scope=v8

# Run specific test with debug
zig build test -Ddebug=true -Ddebug-scope=v8 -- "test name"
```

### Debug Functions

- `ensureContextEntered()` - Logs when context is entered
- `markContextExited()` - Logs when context is exited
- `assertContextEntered()` - Panics if context not entered (debug only)
- `assertContextNotEntered()` - Panics if context is entered (debug only)

### Example Debug Output

```
[v8] ensureContextEntered: ctx=0x7f8b4c000000, already_entered=false
[v8] ensureContextEntered: context now entered
[v8] ensureContextEntered: ctx=0x7f8b4c000000, already_entered=true
[v8] markContextExited: ctx=0x7f8b4c000000, is_entered=true
[v8] markContextExited: context now exited
```

## Common Pitfalls

### 1. Creating New Context Instead of Using Existing

**Wrong:**
```zig
fn executeScript(script: []const u8) void {
    const ctx = v8.createNewContext();  // Creates isolated global!
    v8.runScript(ctx, script);
}
```

**Right:**
```zig
fn executeScript(self: *Context, script: []const u8) void {
    // Use existing, already-entered context
    v8.runScript(self.v8_ctx, script);
}
```

### 2. Exiting Context Between Script Executions

**Wrong:**
```zig
fn runTestHarness(self: *Context) void {
    v8.enterContext(self.v8_ctx);
    v8.runScript("testharness.js");
    v8.exitContext(self.v8_ctx);  // DON'T DO THIS!
    
    v8.enterContext(self.v8_ctx);  // Re-entering creates issues
    v8.runScript("inline-test.js");
    v8.exitContext(self.v8_ctx);
}
```

**Right:**
```zig
fn runTestHarness(self: *Context) void {
    // Context already entered at creation, just run scripts
    v8.runScript("testharness.js");
    v8.runScript("inline-test.js");
    // Context stays entered until page destruction
}
```

### 3. Using JsScope When Persistent Context is Needed

**Wrong:**
```zig
fn loadDocument(self: *Context) void {
    // JsScope implies temporary context entry/exit
    var scope = JsScope.init(self.isolate, self.v8_ctx);
    defer scope.deinit();  // This might exit context!
    
    self.parseHTML(html);
}
```

**Right:**
```zig
fn loadDocument(self: *Context) void {
    // Use HandleScope for handle management, not context entry
    var handle_scope = v8.HandleScope.init(self.isolate);
    defer handle_scope.deinit();
    
    // Context already entered, just do the work
    self.parseHTML(html);
}
```

### 4. Forgetting to Enter Context at Creation

**Wrong:**
```zig
pub fn init() !*Context {
    const v8_ctx = createV8Context();
    // Forgot to enter! Scripts will fail silently or crash
    return context;
}
```

**Right:**
```zig
pub fn init() !*Context {
    const v8_ctx = createV8Context();
    context_manager.ensureContextEntered(v8_ctx);  // Enter immediately
    return context;
}
```

## Testing Context State

Use `assertContextEntered()` during development to catch violations:

```zig
pub fn executeScript(self: *Context, script: []const u8) !void {
    // Debug-only assertion - zero cost when debug disabled
    context_manager.assertContextEntered(self.v8_ctx);
    
    // Now we know context is properly entered
    try v8.runScript(self.v8_ctx, script);
}
```

## References

- [LightPanda Source](https://github.com/nicochannnn/nicochannnn.github.io/blob/main/src/browser/js) - `ExecutionWorld.zig`, `Context.zig`
- [Chromium V8 Bindings](https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/bindings/core/v8/) - Similar pattern in C++
- [V8 Embedder's Guide](https://v8.dev/docs/embed) - Context and Isolate concepts

## Summary

The "enter once, stay entered" pattern ensures all scripts on a page share the same global scope:

1. Enter context at browsing context creation
2. Keep it entered for all script executions
3. Exit only during destruction
4. Use `assertContextEntered()` to catch bugs during development

This matches browser behavior and prevents global scope isolation bugs.
