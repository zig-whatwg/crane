# Plan: Fix Remaining 142 Test Failures (642/790 → 790/790)

**Goal**: Achieve 100% test pass rate by systematically fixing the remaining issues.

**Current Status**: 642/790 tests passing (81.3%)

---

## Issue Categories (Priority Order)

### 🔴 **CRITICAL - Category 1: Codegen `.base` Field Removal** (3 errors)
**Impact**: Blocks attribute mutation tests
**Effort**: Low
**Priority**: P0

**Problem**: Codegen flattens inheritance and removes `.base` field, but code still references it.

**Affected Files**:
- `src/dom/attribute_algorithms.zig:164` - `attribute.base.owner_document`
- `src/dom/attribute_algorithms.zig:261` - `element.base.allocator`
- `tests/dom/range_delete_contents_test.zig:210` - `comment.base.get_data()`

**Solution**:
1. Replace `attribute.base.field` with `attribute.field` (fields are duplicated)
2. Replace `element.base.allocator` with `element.allocator`
3. Replace `comment.base.get_data()` with `comment.get_data()`

**Files to Fix**:
```bash
# Find all .base references
rg "\.base\." src/ tests/ --type zig
```

**Estimated Time**: 15 minutes

---

### 🟠 **HIGH - Category 2: Test @ptrCast Without Result Type** (24 errors)
**Impact**: Range and mutation tests fail
**Effort**: Medium
**Priority**: P1

**Problem**: Tests use `@ptrCast` without specifying result type (required in Zig 0.15.1).

**Pattern**:
```zig
// ❌ Old (broken)
const elem: *Element = @ptrCast(node);

// ✅ New (correct)
const elem: *Element = @ptrCast(@alignCast(node));
// OR just use anytype pattern:
// Don't cast at all if possible
```

**Affected Tests**:
- `tests/dom/range_*.zig` (20 errors)
- `tests/dom/element_*.zig` (4 errors)

**Solution**:
1. Add explicit type annotation: `const elem: *Element = @ptrCast(node);`
2. OR remove @ptrCast and use anytype pattern where possible
3. Add @alignCast if needed: `@ptrCast(@alignCast(node))`

**Estimated Time**: 30 minutes

---

### 🟠 **HIGH - Category 3: Console Mock Runtime VTable** (4 errors)
**Impact**: Console tests fail
**Effort**: Low
**Priority**: P1

**Problem**: VTable comparison with null fails (not optional type).

**File**: `tests/console/mock_runtime.zig:340`

**Current Code**:
```zig
try std.testing.expect(runtime.vtable != null);
```

**Solution**:
```zig
// VTable is not optional, so just remove the null check or check if it's set
try std.testing.expect(@intFromPtr(runtime.vtable) != 0);
// OR make vtable optional in the struct definition
```

**Estimated Time**: 10 minutes

---

### 🟡 **MEDIUM - Category 4: Streams API Issues** (15 errors)
**Impact**: Streams tests fail
**Effort**: High
**Priority**: P2

**Problems**:
1. **AsyncPromise method calls** - `fulfill`, `reject`, `executeCloseSteps` not found
2. **List.remove() returns error union** - Code expects direct value
3. **Function signature mismatches** - Wrong argument counts
4. **Missing struct fields** - `allocator` missing in generated code

**Affected Files**:
- `webidl/generated/streams/ReadableStream.zig`
- `webidl/generated/streams/ReadableByteStreamController.zig`
- `webidl/generated/streams/ReadableStreamDefaultController.zig`
- `webidl/generated/streams/WritableStream.zig`

**Root Cause**: Codegen issues with async patterns and List API changes

**Solution Options**:
1. **Quick Fix**: Update generated files manually to match List API
2. **Proper Fix**: Fix codegen template for streams (complex)
3. **Workaround**: Disable failing streams tests temporarily

**Estimated Time**: 2-3 hours (Quick fix) OR 1 week (Proper fix)

---

### 🟡 **MEDIUM - Category 5: Missing Modules/Imports** (6 errors)
**Impact**: Specific feature tests fail
**Effort**: Medium
**Priority**: P2

**Missing Modules**:
1. `slot_helpers` - Shadow DOM slot assignment
2. `slottable` - Slottable mixin
3. `url_record` - URL internal record type
4. `form_urlencoded` - URL form encoding

**Affected Tests**:
- `tests/dom/slot_helpers_test.zig`
- `tests/dom/slottable_mixin_test.zig`
- `tests/url/url_*.zig`

**Solution**:
1. Check if modules exist but aren't exported
2. Create stub implementations if needed
3. Update module exports in root files

**Estimated Time**: 1 hour

---

### 🟡 **MEDIUM - Category 6: WebIDL Codegen Issues** (8 errors)
**Impact**: Various API tests fail
**Effort**: High
**Priority**: P2

**Issues**:
1. **MutationObserver dependency loop** - Circular import
2. **Type incompatibilities** - `*anyopaque` vs concrete types
3. **Missing methods** - `call_getAll`, `call_toJSON`
4. **Missing fields** - `document_type` in Document
5. **TextDecoder buffer methods** - `getOrAllocUtf16Buffer` missing

**Root Cause**: Codegen template issues

**Solution**: Fix codegen templates for each specific issue

**Estimated Time**: 3-4 hours

---

### 🟢 **LOW - Category 7: Test-Specific Issues** (10 errors)
**Impact**: Individual test failures
**Effort**: Low-Medium
**Priority**: P3

**Issues**:
- Type mismatches in test expectations
- Error union vs optional confusion
- Import path issues

**Solution**: Fix each test individually

**Estimated Time**: 1 hour

---

## Execution Plan

### Phase 1: Quick Wins (P0 + P1) - **55 minutes**
**Target**: Fix 31 errors → 673/790 tests passing (85%)

1. ✅ **Fix .base field references** (15 min) - Category 1
2. ✅ **Fix test @ptrCast calls** (30 min) - Category 2
3. ✅ **Fix console VTable checks** (10 min) - Category 3

**Expected Result**: ~30 additional tests passing

---

### Phase 2: Module Resolution (P2) - **1 hour**
**Target**: Fix 6 errors → 685/790 tests passing (87%)

4. ✅ **Fix missing module imports** (1 hour) - Category 5

**Expected Result**: ~12 additional tests passing

---

### Phase 3: Codegen Fixes (P2) - **3-4 hours**
**Target**: Fix 8 errors → 710/790 tests passing (90%)

5. ✅ **Fix WebIDL codegen issues** (3-4 hours) - Category 6

**Expected Result**: ~25 additional tests passing

---

### Phase 4: Test Cleanup (P3) - **1 hour**
**Target**: Fix 10 errors → 735/790 tests passing (93%)

6. ✅ **Fix individual test issues** (1 hour) - Category 7

**Expected Result**: ~25 additional tests passing

---

### Phase 5: Streams Decision (P2) - **2-3 hours OR defer**
**Target**: Fix 15 errors → 790/790 tests passing (100%)

7. ⚠️ **Fix Streams issues** (2-3 hours quick fix, 1 week proper fix) - Category 4

**Options**:
- **Option A**: Quick manual fix to generated files (temporary)
- **Option B**: Fix codegen templates (permanent, complex)
- **Option C**: Defer streams fixes, mark tests as skip

**Expected Result**: ~55 additional tests passing (if fixed)

---

## Detailed Task List

### Phase 1 Tasks (Quick Wins)

#### Task 1.1: Fix .base References
```bash
# Find all occurrences
rg "\.base\." src/ tests/ --type zig

# Fix pattern:
# OLD: obj.base.field
# NEW: obj.field
# OLD: obj.base.method()
# NEW: obj.method()
```

**Files**:
- [ ] `src/dom/attribute_algorithms.zig:164`
- [ ] `src/dom/attribute_algorithms.zig:261`
- [ ] `tests/dom/range_delete_contents_test.zig:210`

#### Task 1.2: Fix @ptrCast Calls
```bash
# Find all broken @ptrCast
rg "@ptrCast\(" tests/dom/range_*.zig

# Fix pattern:
# OLD: @ptrCast(value)
# NEW: @ptrCast(@alignCast(value))
# OR specify type: const x: *Type = @ptrCast(value);
```

**Files**:
- [ ] `tests/dom/range_removal_edge_cases_test.zig` (4 locations)
- [ ] `tests/dom/range_insertion_edge_cases_test.zig` (many locations)
- [ ] `tests/dom/range_setstart_setend_test.zig` (2 locations)
- [ ] `tests/dom/range_surroundcontents_test.zig` (2 locations)
- [ ] `tests/dom/element_*.zig` (4 locations)

#### Task 1.3: Fix Console VTable
**File**: `tests/console/mock_runtime.zig:340`

```zig
// Change from:
try std.testing.expect(runtime.vtable != null);

// To:
try std.testing.expect(@intFromPtr(runtime.vtable) != 0);
```

---

### Phase 2 Tasks (Module Resolution)

#### Task 2.1: Check Module Exports
```bash
# Check if modules exist but aren't exported
rg "pub const slot_helpers" src/dom/
rg "pub const slottable" webidl/
rg "pub const url_record" src/url/
rg "pub const form_urlencoded" src/url/
```

#### Task 2.2: Add Missing Exports
Update `src/dom/root.zig` and `src/url/root.zig` to export missing modules.

---

### Phase 3 Tasks (Codegen Fixes)

#### Task 3.1: MutationObserver Dependency Loop
**File**: `webidl/generated/dom/MutationObserver.zig:26`

Investigate circular import and fix codegen template.

#### Task 3.2: Missing Method Generation
Fix codegen to generate:
- `call_getAll` for URLSearchParams
- `call_toJSON` for URL
- `getOrAllocUtf16Buffer` for TextDecoder

---

## Success Metrics

**Phase 1 Complete**: 673/790 (85%) ✅  
**Phase 2 Complete**: 685/790 (87%) ✅  
**Phase 3 Complete**: 710/790 (90%) ✅  
**Phase 4 Complete**: 735/790 (93%) ✅  
**Phase 5 Complete**: 790/790 (100%) 🎯  

---

## Risk Assessment

| Phase | Risk Level | Mitigation |
|-------|-----------|------------|
| Phase 1 | 🟢 Low | Mechanical fixes, well-understood |
| Phase 2 | 🟡 Medium | Modules might not exist yet |
| Phase 3 | 🟠 High | Codegen changes could break other things |
| Phase 4 | 🟢 Low | Isolated test fixes |
| Phase 5 | 🔴 High | Complex async patterns, major time investment |

---

## Recommendation

**Immediate Action**: Execute Phases 1-2 (1h 55m total)
- Achieves ~87% pass rate with low risk
- Fixes all mechanical/obvious issues
- Provides clear foundation for harder work

**Next Steps**: Evaluate Phase 3-4 vs Phase 5
- If time-constrained: Do Phase 3-4, defer/skip Streams (93% pass rate)
- If comprehensive: Do all phases (100% pass rate)

**Estimated Total Time**:
- **Minimum** (Phases 1-4, skip Streams): ~6 hours → 93% pass rate
- **Maximum** (All phases, proper fix): ~13 hours → 100% pass rate
- **Pragmatic** (All phases, quick Streams fix): ~8 hours → 100% pass rate

---

## Next Commands

```bash
# Start Phase 1, Task 1.1
rg "\.base\." src/ tests/ --type zig -l

# Start Phase 1, Task 1.2  
rg "@ptrCast\(" tests/dom/range_*.zig -A2 -B2

# Start Phase 1, Task 1.3
vim tests/console/mock_runtime.zig +340
```
