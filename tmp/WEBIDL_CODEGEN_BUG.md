# WebIDL Codegen Critical Bug

## Issue
The webidl codegen incorrectly parses local variable declarations inside function bodies as struct fields.

## Impact
- Prevents implementation of complex interfaces like NodeIterator and enhanced Range methods
- Blocks Phase 7 completion

## Root Cause
The codegen parser in `src/webidl/codegen/` doesn't respect function scope boundaries when parsing `webidl.interface(struct { ... })` definitions.

## Examples

### Example 1: Local variable with explicit type
```zig
pub const Range = webidl.interface(struct {
    fn someHelper(self: *Range) void {
        var child: *Node = undefined;  // ← Incorrectly treated as struct field
        // ... function body
    }
});
```

**Generated (WRONG)**:
```zig
pub const Range = struct {
    var child: *Node = undefined;,  // ← Added as struct field with syntax error
    // ... rest of struct
};
```

### Example 2: Const with block expression
```zig
fn helper() void {
    const result = blk: {  // ← Also incorrectly parsed
        break :blk someValue;
    };
}
```

**Generated (WRONG)**:
```zig
const result = blk: {,
break: blk someValue;,
```

## Attempted Workarounds
1. ✗ Using block expressions - Still parsed as fields
2. ✗ Type inference - Still picked up
3. ✗ Inline expressions - Partially works but limits implementation

## Solution Needed
The codegen parser needs to:
1. Only parse top-level struct field declarations
2. Skip function bodies entirely OR properly track scope depth
3. Not treat any code inside functions as struct fields

## Files Affected
- `webidl/src/dom/Range.zig` - Cannot use complex helper functions
- `webidl/src/dom/NodeIterator.zig` - Cannot implement properly
- Any future complex interface implementations

## Temporary Workaround
For simple interfaces: Don't use local variables with explicit types in helper functions
For complex interfaces: Don't use `webidl.interface()` - implement as plain structs

## Priority
**CRITICAL** - Blocks Phase 7 DOM implementation completion
