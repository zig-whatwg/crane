# URL and URLSearchParams Migration Plan

**Date:** 2025-11-23  
**Objective:** Migrate URL and URLSearchParams implementations from old webidl.interface() pattern to runtime-based impl system

## Background

The project has two WebIDL implementation systems:

1. **Old system** (`webidl/src/url/`): Uses `webidl.interface()` macro with direct business logic
2. **New system** (`src/webidl/impls/`): Runtime-based with auto-generated interfaces from WebIDL files

We are migrating URL and URLSearchParams to the new system to maintain codegen automation while preserving the browser-like architecture (parsed data structure + computed properties).

## Architecture Decision: InternalState Pattern

Following Chrome's architecture where URLs store a parsed data structure (KURL/GURL) rather than just strings, we will:

1. **Use `URLRecord` as source of truth** (matches browser implementations)
2. **Compute string properties on-demand** from URLRecord (no redundant storage)
3. **Extend codegen with InternalState support** to preserve automation

### InternalState Pattern

Each impl file can define an optional `InternalState` struct:

```zig
// In src/webidl/impls/URL.zig
pub const InternalState = struct {
    url_record: URLRecord,
    query_params_instance: ?*runtime.Instance,
    allocator: std.mem.Allocator,
};
```

The codegen will include this in the generated State:

```zig
pub const State = runtime.FlattenedState(
    Meta.BaseType,
    Meta.MixinTypes,
    struct {
        href: runtime.USVString = undefined,
        // ... other WebIDL properties from IDL
        _internal: ?*InternalState = null,  // Added by codegen
    },
);
```

## Migration Tasks

### Phase 1: Codegen Enhancement

**Task:** Update WebIDL codegen to support InternalState pattern

- [ ] Modify codegen to detect `pub const InternalState` in impl files
- [ ] Add `_internal: ?*InternalState = null` field to generated State
- [ ] Regenerate all interface files with new codegen

### Phase 2: URL Implementation

**File:** `src/webidl/impls/URL.zig`

#### 2.1 Define InternalState

```zig
pub const InternalState = struct {
    url_record: URLRecord,
    query_params_instance: ?*runtime.Instance,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *InternalState) void {
        self.url_record.deinit();
    }
};
```

#### 2.2 Implement Constructor

- [ ] `call_constructor(allocator, ctx, url, base)` - Parse URL with optional base
  - Parse base URL if provided
  - Parse main URL with base
  - Create InternalState with URLRecord
  - Initialize URLSearchParams instance
  - Set up bidirectional relationship

#### 2.3 Implement Getters

All getters compute values from `url_record`:

- [ ] `get_href()` - Serialize URLRecord
- [ ] `get_origin()` - Compute origin from URLRecord
- [ ] `get_protocol()` - Return `scheme + ":"`
- [ ] `get_username()` - Return URLRecord.username
- [ ] `get_password()` - Return URLRecord.password
- [ ] `get_host()` - Serialize host with port
- [ ] `get_hostname()` - Serialize host without port
- [ ] `get_port()` - Serialize port or empty string
- [ ] `get_pathname()` - Serialize path
- [ ] `get_search()` - Return `"?" + query` or empty
- [ ] `get_searchParams()` - Return cached URLSearchParams instance
- [ ] `get_hash()` - Return `"#" + fragment` or empty

#### 2.4 Implement Setters

All setters modify `url_record` using basic parser with state overrides:

- [ ] `set_href(value)` - Parse new URL, replace URLRecord
- [ ] `set_protocol(value)` - Parse with scheme_start state override
- [ ] `set_username(value)` - Percent-encode and update URLRecord
- [ ] `set_password(value)` - Percent-encode and update URLRecord
- [ ] `set_host(value)` - Parse with host state override
- [ ] `set_hostname(value)` - Parse with hostname state override
- [ ] `set_port(value)` - Parse with port state override
- [ ] `set_pathname(value)` - Parse with path_start state override
- [ ] `set_search(value)` - Parse with query state override, update URLSearchParams
- [ ] `set_hash(value)` - Parse with fragment state override

#### 2.5 Implement Static Methods

- [ ] `call_parse(url, base)` - Returns URL or null (doesn't throw)
- [ ] `call_canParse(url, base)` - Returns boolean
- [ ] `call_toJSON()` - Returns href

#### 2.6 Implement Lifecycle

- [ ] `init()` - Create runtime.Instance with State
- [ ] `deinit()` - Clean up InternalState, URLRecord, URLSearchParams

#### 2.7 Required Imports

```zig
const URLRecord = @import("url_record").URLRecord;
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const basic_parser = @import("basic_parser");
const host_serializer = @import("host_serializer");
const path_serializer = @import("path_serializer");
const origin = @import("origin");
const percent_encoding = @import("percent_encoding");
const EncodeSet = @import("encode_sets").EncodeSet;
const ParserState = @import("parser_state").ParserState;
```

**CRITICAL:** Do NOT import anything from `webidl/src/*`

### Phase 3: URLSearchParams Implementation

**File:** `src/webidl/impls/URLSearchParams.zig`

#### 3.1 Define InternalState

```zig
const Tuple = @import("form_parser").Tuple;

pub const InternalState = struct {
    list: infra.List(Tuple),
    url_object: ?*runtime.Instance,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *InternalState) void {
        for (0..self.list.len) |i| {
            self.list.get(i).?.deinit(self.allocator);
        }
        self.list.deinit();
    }
};
```

#### 3.2 Implement Constructor

- [ ] `call_constructor(allocator, ctx, init_data)` - Handle USVString/sequence/record init
  - Parse init_data type (string, sequence, or record)
  - Initialize list accordingly
  - Create InternalState

#### 3.3 Implement Getters

- [ ] `get_size()` - Return list.len

#### 3.4 Implement Methods

- [ ] `call_append(name, value)` - Add tuple, run update steps
- [ ] `call_delete(name, value)` - Remove matching tuples, run update steps
- [ ] `call_get(name)` - Return first matching value or null
- [ ] `call_getAll(name)` - Return all matching values
- [ ] `call_has(name, value)` - Check if tuple exists
- [ ] `call_set(name, value)` - Replace first, remove others, run update steps
- [ ] `call_sort()` - Sort tuples by name, run update steps
- [ ] `call_forEach(callback)` - Iterate with callback

#### 3.5 Implement Update Steps

```zig
fn updateSteps(internal: *InternalState) !void {
    if (internal.url_object) |url_instance| {
        // Serialize list to query string
        // Update URL's query component
    }
}
```

#### 3.6 Required Imports

```zig
const infra = @import("infra");
const form_parser = @import("form_parser");
const form_serializer = @import("form_serializer");
const Tuple = form_parser.Tuple;
```

### Phase 4: Integration & Testing

- [ ] Update build.zig if needed for module dependencies
- [ ] Run `zig build test` - ensure existing tests pass
- [ ] Add integration tests for URL ↔ URLSearchParams sync
- [ ] Test memory management (no leaks with std.testing.allocator)
- [ ] Verify spec compliance with WPT tests

## Key Constraints

1. **Do NOT modify generated interface files** (`src/webidl/interfaces/*.zig`)
2. **Do NOT import from `webidl/src/*`** - only import from `src/url/*` and `src/`
3. **URLRecord is source of truth** - all string properties computed on-demand
4. **Maintain bidirectional sync** - URL and URLSearchParams must stay in sync
5. **Memory safety** - zero leaks, proper cleanup with defer/errdefer

## Success Criteria

- [ ] All URL getters/setters implemented and working
- [ ] All URLSearchParams methods implemented and working
- [ ] URL ↔ URLSearchParams bidirectional sync working
- [ ] No memory leaks (verified with std.testing.allocator)
- [ ] All existing tests pass
- [ ] Code follows WHATWG URL spec precisely
- [ ] No imports from webidl/src/*
- [ ] Codegen can regenerate interfaces without manual edits

## References

- **WHATWG URL Spec:** https://url.spec.whatwg.org/
- **Old implementation:** `webidl/src/url/URL.zig`, `webidl/src/url/URLSearchParams.zig`
- **Generated interfaces:** `src/webidl/interfaces/URL.zig`, `src/webidl/interfaces/URLSearchParams.zig`
- **Impl stubs:** `src/webidl/impls/URL.zig`, `src/webidl/impls/URLSearchParams.zig`
- **URL infrastructure:** `src/url/` (URLRecord, parsers, serializers)
