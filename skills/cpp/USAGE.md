# C++ Skill - Usage Guide

## When to Load This Skill

The C++ skill should be loaded automatically when:

### File Context Detection
- Working in `src/runtime/engines/v8/*.cpp` files
- Working in `src/runtime/engines/v8/*.h` files
- Creating or modifying V8 FFI wrapper functions
- Implementing C/C++ foreign function interfaces

### Task Context Detection
- User asks to "implement V8 wrapper"
- User asks to "add FFI binding"
- User asks to "create C++ wrapper"
- User mentions "TypedArray API" or "V8 API"
- Working on native code integration

### Explicit Loading
User says:
- "Load the C++ skill"
- "Use C++ best practices"
- "Write modern C++ code"

## What This Skill Provides

- Modern C++ (C++17/C++20) idioms and patterns
- V8 API best practices (HandleScope, Global<T>, Local<T>)
- RAII resource management
- FFI boundary design patterns
- Type safety and const correctness
- Memory safety with smart pointers
- Error handling for V8 operations

## Skill Scope

**In Scope:**
- V8 C++ wrapper implementations
- FFI boundary code (extern "C" functions)
- V8 handle management
- Modern C++ features for native code
- Resource lifetime and ownership
- Type-safe C++ APIs

**Out of Scope:**
- General C++ application development (not FFI/V8)
- C++98/C++03 legacy patterns (use modern C++)
- Platform-specific code (keep portable)
- Performance micro-optimizations (prioritize correctness)

## Integration with Other Skills

**Combine With:**
- `zig` skill: When working on Zig FFI consumers of C++ APIs
- `whatwg` skill: When implementing spec algorithms in C++
- `webidl_codegen` skill: When generating C++ bindings

**Example Combined Usage:**
```
Context: Implementing V8 TypedArray introspection
Load: cpp + zig + whatwg

Workflow:
1. Use cpp skill: Write V8 C++ wrappers (v8_wrapper.cpp)
2. Use cpp skill: Add FFI declarations (ffi.zig)
3. Use zig skill: Create Zig API layer (runtime/arraybuffer_view.zig)
4. Use whatwg skill: Implement spec algorithms using the APIs
```

## Quick Reference

### Common Patterns to Apply

1. **HandleScope for Local Handles**
   ```cpp
   void Function(v8::Isolate* isolate) {
       v8::HandleScope scope(isolate);
       // All Local<T> handles cleaned up on exit
   }
   ```

2. **Global for Persistent Handles**
   ```cpp
   v8::Global<v8::Function>* persistent = 
       new v8::Global<v8::Function>(isolate, local_func);
   ```

3. **Const Correctness**
   ```cpp
   void Process(const v8::Local<v8::Value>& value) const;
   ```

4. **Null Checks in C API**
   ```cpp
   extern "C" Type* Function(Args...) {
       if (!valid_input) return nullptr;
       // ... implementation
   }
   ```

5. **Modern Casts**
   ```cpp
   auto* ptr = static_cast<TargetType*>(source);
   auto* ptr = reinterpret_cast<OpaqueType*>(handle);
   ```

### Anti-Patterns to Avoid

- ❌ C-style casts: `(Type*)ptr`
- ❌ Raw new/delete: Use RAII
- ❌ Ignoring Maybe<T> returns
- ❌ Missing HandleScope
- ❌ using namespace std/v8
- ❌ Non-const parameters when possible

## Decision Tree

```
Need to write code?
  ├─ Is it C++ code?
  │   ├─ YES → Load cpp skill
  │   └─ NO → Continue
  │
  ├─ Is it V8 FFI boundary?
  │   ├─ YES → Load cpp skill
  │   └─ NO → Continue
  │
  └─ Is it for src/runtime/engines/v8/*.cpp?
      ├─ YES → Load cpp skill
      └─ NO → Don't load (Zig code uses zig skill)
```

## Context Examples

**Load cpp skill:**
- "Implement v8_TypedArray_ByteLength wrapper"
- "Add V8 API for ArrayBuffer introspection"
- "Create FFI function in v8_wrapper.cpp"
- "Fix memory leak in V8 handle management"

**Don't load cpp skill:**
- "Implement URL parser" (Zig code → use zig skill)
- "Add tests for streams" (Zig tests → use zig skill)
- "Update WHATWG spec algorithm" (Zig impl → use zig + whatwg)
