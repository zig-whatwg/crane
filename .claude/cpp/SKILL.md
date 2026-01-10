---
name: cpp
description: Ensures highest quality, modern, safe, and idiomatic C++ code for V8 FFI wrappers
license: MIT
---

# C++ Programming Skill

## Purpose

This skill ensures you write **highest quality, modern, safe, and idiomatic C++ code** for V8 FFI wrappers and native integrations.

---

## When to Use This Skill

Load this skill automatically when:
- Writing or refactoring C++ code
- Creating V8 C++ wrapper functions
- Implementing FFI boundaries
- Managing V8 handles and lifetimes
- Working with modern C++ features
- Interfacing between C++ and Zig

---

## Core Philosophy

**Modern C++ (C++17/C++20) emphasizes:**
1. **RAII** - Resource Acquisition Is Initialization
2. **Zero-cost abstractions** - No overhead for high-level constructs
3. **Type safety** - Strong typing, avoid void* and C-style casts
4. **Explicit ownership** - Smart pointers, clear lifetime semantics
5. **Const correctness** - Use const wherever possible

---

# Part 1: Modern C++ Fundamentals

## Naming Conventions

```cpp
// Types and Classes: PascalCase
class UrlParser { ... };
struct ViewMetadata { ... };
enum class ViewType { ... };

// Functions and variables: snake_case (for C API compatibility)
extern "C" {
    void* v8_Object_New(Isolate* isolate);
    size_t v8_ArrayBuffer_ByteLength(ArrayBuffer* buffer);
}

// Private members: snake_case with trailing underscore
class MyClass {
private:
    int count_;
    std::string name_;
};

// Constants: kPascalCase or SCREAMING_SNAKE_CASE
constexpr size_t kMaxBufferSize = 1024;
constexpr int DEFAULT_TIMEOUT = 5000;

// Namespaces: lowercase
namespace v8_wrapper {
namespace internal {
    ...
}
}
```

---

## Type Safety and Modern C++

### Use Strong Types

```cpp
// ✅ GOOD: Strong types with enum class
enum class ViewType {
    Uint8Array,
    Int8Array,
    Uint16Array,
    Int16Array,
    // ... etc
};

// ❌ BAD: C-style enum (pollutes namespace)
enum ViewType {
    VIEW_UINT8_ARRAY,
    VIEW_INT8_ARRAY,
};

// ✅ GOOD: Type-safe function
ViewType GetViewType(const v8::Local<v8::Value>& value);

// ❌ BAD: Unsafe int return
int GetViewType(v8::Local<v8::Value> value);
```

### Avoid C-Style Casts

```cpp
// ✅ GOOD: Modern C++ casts
auto* typed_array = static_cast<v8::TypedArray*>(value);
const auto* const_ptr = reinterpret_cast<const uint8_t*>(data);

// ❌ BAD: C-style cast (hides intent)
auto* typed_array = (v8::TypedArray*)value;
```

### Use auto Judiciously

```cpp
// ✅ GOOD: auto when type is obvious from RHS
auto isolate = v8::Isolate::GetCurrent();
auto buffer = v8::ArrayBuffer::New(isolate, size);

// ✅ GOOD: Explicit type when clarity matters
v8::Local<v8::String> name = v8::String::NewFromUtf8(isolate, "property");

// ❌ BAD: auto obscures important type information
auto value = GetSomeValue(); // What type is this?
```

---

## Resource Management (RAII)

### V8 Handles and Scopes

```cpp
// ✅ GOOD: Use HandleScope for local handles
void ProcessValue(v8::Isolate* isolate, v8::Local<v8::Value> value) {
    v8::HandleScope handle_scope(isolate);
    
    // All Local<T> handles are automatically cleaned up
    v8::Local<v8::String> str = value->ToString(context).ToLocalChecked();
    // ... work with str ...
    
    // handle_scope destructor cleans up all handles
}

// ✅ GOOD: Use Global<T> for cross-scope persistence
v8::Global<v8::Function>* CreatePersistentFunction(
    v8::Isolate* isolate,
    v8::Local<v8::Function> func
) {
    // Global persists beyond HandleScope
    return new v8::Global<v8::Function>(isolate, func);
}

// ✅ GOOD: Clean up Global<T> explicitly
void DisposePersistentFunction(v8::Global<v8::Function>* func) {
    func->Reset(); // Release V8 handle
    delete func;   // Free memory
}
```

### Smart Pointers (std::unique_ptr, std::shared_ptr)

```cpp
// ✅ GOOD: Use std::unique_ptr for single ownership
std::unique_ptr<Resource> CreateResource() {
    return std::make_unique<Resource>();
}

// ✅ GOOD: Use std::shared_ptr for shared ownership
std::shared_ptr<Context> CreateSharedContext() {
    return std::make_shared<Context>();
}

// ❌ BAD: Raw new/delete (manual memory management)
Resource* CreateResource() {
    return new Resource(); // Caller must remember to delete
}

// ✅ GOOD: Custom deleter for special cleanup
auto deleter = [](v8::Global<v8::Function>* func) {
    func->Reset();
    delete func;
};
std::unique_ptr<v8::Global<v8::Function>, decltype(deleter)> func_ptr(
    persistent_func,
    deleter
);
```

### RAII Wrapper Example

```cpp
// ✅ GOOD: RAII wrapper for V8 context
class ContextScope {
public:
    explicit ContextScope(v8::Local<v8::Context> context) 
        : context_(context) {
        context_->Enter();
    }
    
    ~ContextScope() {
        context_->Exit();
    }
    
    // Delete copy operations (RAII objects shouldn't be copied)
    ContextScope(const ContextScope&) = delete;
    ContextScope& operator=(const ContextScope&) = delete;
    
private:
    v8::Local<v8::Context> context_;
};

// Usage
void DoWork(v8::Local<v8::Context> context) {
    ContextScope scope(context); // Enter on construction
    
    // Do work...
    
    // Automatically exits on scope exit
}
```

---

## Const Correctness

### Use const for Everything That Doesn't Change

```cpp
// ✅ GOOD: const parameters and const methods
size_t GetByteLength(const v8::Local<v8::ArrayBuffer>& buffer) const {
    return buffer->ByteLength();
}

// ✅ GOOD: const pointers
void ProcessData(const uint8_t* const data, size_t length) {
    // data is const, pointer is const
}

// ✅ GOOD: const member functions
class Wrapper {
public:
    size_t GetSize() const { return size_; }  // Doesn't modify state
    void SetSize(size_t s) { size_ = s; }     // Modifies state
    
private:
    size_t size_;
};

// ❌ BAD: Missing const
size_t GetByteLength(v8::Local<v8::ArrayBuffer> buffer) {
    return buffer->ByteLength();
}
```

### const References for Parameters

```cpp
// ✅ GOOD: Pass by const reference for non-trivial types
void ProcessString(const std::string& str) {
    // No copy, no modification
}

// ✅ GOOD: Pass by value for trivial types
void ProcessInt(int value) {
    // Cheap to copy
}

// ❌ BAD: Pass large objects by value
void ProcessString(std::string str) {  // Unnecessary copy!
    // ...
}
```

---

## Error Handling

### Use V8's Maybe<T> and MaybeLocal<T>

```cpp
// ✅ GOOD: Check MaybeLocal before use
v8::Local<v8::String> SafeToString(
    v8::Isolate* isolate,
    v8::Local<v8::Value> value
) {
    v8::Local<v8::Context> context = isolate->GetCurrentContext();
    v8::MaybeLocal<v8::String> maybe_str = value->ToString(context);
    
    if (maybe_str.IsEmpty()) {
        // Handle error - return empty string
        return v8::String::NewFromUtf8(isolate, "").ToLocalChecked();
    }
    
    return maybe_str.ToLocalChecked();
}

// ❌ BAD: Unchecked ToLocalChecked() (can crash!)
v8::Local<v8::String> UnsafeToString(
    v8::Isolate* isolate,
    v8::Local<v8::Value> value
) {
    return value->ToString(isolate->GetCurrentContext()).ToLocalChecked();
    // Crashes if ToString fails!
}
```

### Return nullptr for Errors in C API

```cpp
// ✅ GOOD: Return nullptr on failure
extern "C" v8::String* v8_String_NewFromUtf8(
    v8::Isolate* isolate,
    const char* data,
    int length
) {
    if (!isolate || !data || length < 0) {
        return nullptr;  // Clear error signal
    }
    
    v8::MaybeLocal<v8::String> maybe_str = 
        v8::String::NewFromUtf8(isolate, data, v8::NewStringType::kNormal, length);
    
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    
    // Return as pointer (caller must handle ownership)
    return *maybe_str.ToLocalChecked();
}
```

### Use std::optional for Optional Values

```cpp
// ✅ GOOD: std::optional for optional returns
std::optional<size_t> FindIndex(const std::vector<int>& vec, int value) {
    auto it = std::find(vec.begin(), vec.end(), value);
    if (it == vec.end()) {
        return std::nullopt;
    }
    return std::distance(vec.begin(), it);
}

// Usage
if (auto index = FindIndex(numbers, 42)) {
    std::cout << "Found at: " << *index << std::endl;
}
```

---

## V8-Specific Best Practices

### HandleScope Discipline

```cpp
// ✅ GOOD: HandleScope per function
void ProcessArray(v8::Isolate* isolate, v8::Local<v8::Array> array) {
    v8::HandleScope handle_scope(isolate);
    
    uint32_t length = array->Length();
    for (uint32_t i = 0; i < length; ++i) {
        v8::Local<v8::Value> element = array->Get(context, i).ToLocalChecked();
        // Process element
    }
    // All Local<T> cleaned up on return
}

// ❌ BAD: No HandleScope (memory leak in loops)
void ProcessArray(v8::Isolate* isolate, v8::Local<v8::Array> array) {
    uint32_t length = array->Length();
    for (uint32_t i = 0; i < length; ++i) {
        // Leaks handles on each iteration!
        v8::Local<v8::Value> element = array->Get(context, i).ToLocalChecked();
    }
}
```

### Global vs Local Handles

```cpp
// ✅ GOOD: Use Local<T> for temporary values
void TemporaryValue(v8::Isolate* isolate) {
    v8::HandleScope scope(isolate);
    v8::Local<v8::String> str = v8::String::NewFromUtf8Literal(isolate, "hello");
    // str is valid only within this scope
}

// ✅ GOOD: Use Global<T> for persistence
class CallbackData {
public:
    CallbackData(v8::Isolate* isolate, v8::Local<v8::Function> func)
        : isolate_(isolate), callback_(isolate, func) {}
    
    void Invoke() {
        v8::HandleScope scope(isolate_);
        v8::Local<v8::Function> func = callback_.Get(isolate_);
        // Call func...
    }
    
private:
    v8::Isolate* isolate_;
    v8::Global<v8::Function> callback_;  // Persists across scopes
};
```

### Context Management

```cpp
// ✅ GOOD: Always get current context
void SafeOperation(v8::Isolate* isolate, v8::Local<v8::Object> obj) {
    v8::Local<v8::Context> context = isolate->GetCurrentContext();
    v8::Context::Scope context_scope(context);
    
    // Now safe to perform operations
    obj->Set(context, key, value);
}

// ❌ BAD: Operations without context
void UnsafeOperation(v8::Isolate* isolate, v8::Local<v8::Object> obj) {
    obj->Set(key, value);  // Crash! No context!
}
```

---

## Modern C++ Features to Use

### Range-based for Loops

```cpp
// ✅ GOOD: Range-based for
void ProcessElements(const std::vector<int>& elements) {
    for (const auto& element : elements) {
        // Process element
    }
}

// ❌ BAD: Manual indexing (when not needed)
void ProcessElements(const std::vector<int>& elements) {
    for (size_t i = 0; i < elements.size(); ++i) {
        const auto& element = elements[i];
        // Process element
    }
}
```

### Structured Bindings (C++17)

```cpp
// ✅ GOOD: Structured bindings for pairs/tuples
std::pair<bool, size_t> FindElement(const std::vector<int>& vec, int value);

// Usage
if (auto [found, index] = FindElement(numbers, 42); found) {
    std::cout << "Found at: " << index << std::endl;
}

// ✅ GOOD: Structured bindings for maps
std::map<std::string, int> map;
for (const auto& [key, value] : map) {
    // key and value are properly typed
}
```

### std::string_view for Non-owning Strings

```cpp
// ✅ GOOD: string_view avoids copies
void ProcessName(std::string_view name) {
    // No copy, just a view
    std::cout << "Name: " << name << std::endl;
}

// Can call with various string types
ProcessName("literal");
ProcessName(std::string("string"));
ProcessName(some_string);
```

### Lambda Functions

```cpp
// ✅ GOOD: Lambdas for callbacks
void ProcessWithCallback(std::function<void(int)> callback) {
    callback(42);
}

// Usage
ProcessWithCallback([](int value) {
    std::cout << "Value: " << value << std::endl;
});

// ✅ GOOD: Capture by reference or value explicitly
int multiplier = 10;
auto lambda_by_value = [multiplier](int x) { return x * multiplier; };
auto lambda_by_ref = [&multiplier](int x) { return x * multiplier; };
```

---

## Common Patterns for V8 Wrappers

### Pattern 1: Type Checking

```cpp
// ✅ GOOD: Type checking with proper error handling
extern "C" bool v8_Value_IsUint8Array(v8::Value* value) {
    if (!value) {
        return false;
    }
    
    v8::Local<v8::Value> local_value = *reinterpret_cast<v8::Local<v8::Value>*>(value);
    return local_value->IsUint8Array();
}
```

### Pattern 2: Property Access

```cpp
// ✅ GOOD: Safe property access
extern "C" size_t v8_TypedArray_ByteLength(v8::TypedArray* typed_array) {
    if (!typed_array) {
        return 0;
    }
    
    v8::Local<v8::TypedArray> local = *reinterpret_cast<v8::Local<v8::TypedArray>*>(typed_array);
    return local->ByteLength();
}
```

### Pattern 3: Handle Conversion

```cpp
// ✅ GOOD: Convert between Local and Global
extern "C" v8::Global<v8::Function>* v8_Function_MakePersistent(
    v8::Isolate* isolate,
    v8::Function* function
) {
    if (!isolate || !function) {
        return nullptr;
    }
    
    v8::Local<v8::Function> local = *reinterpret_cast<v8::Local<v8::Function>*>(function);
    return new v8::Global<v8::Function>(isolate, local);
}
```

### Pattern 4: Callback Wrapping

```cpp
// ✅ GOOD: Wrap Zig callbacks for V8
struct ZigCallbackData {
    void (*callback)(void* user_data, int value);
    void* user_data;
};

void V8CallbackWrapper(const v8::FunctionCallbackInfo<v8::Value>& info) {
    v8::Isolate* isolate = info.GetIsolate();
    v8::HandleScope scope(isolate);
    
    // Extract Zig callback from data
    v8::Local<v8::External> external = info.Data().As<v8::External>();
    auto* data = static_cast<ZigCallbackData*>(external->Value());
    
    // Call Zig callback
    if (data && data->callback) {
        int value = info[0]->Int32Value(isolate->GetCurrentContext()).ToChecked();
        data->callback(data->user_data, value);
    }
}
```

---

## Testing and Debugging

### Use static_assert for Compile-Time Checks

```cpp
// ✅ GOOD: Compile-time size checks
static_assert(sizeof(void*) == 8, "Requires 64-bit platform");
static_assert(alignof(MyStruct) == 8, "Alignment requirement not met");
```

### Add Debug Checks

```cpp
// ✅ GOOD: Debug assertions
void ProcessBuffer(const uint8_t* data, size_t length) {
    assert(data != nullptr && "Data pointer must not be null");
    assert(length > 0 && "Length must be positive");
    
    // Process data...
}
```

### Use Sanitizers During Development

```cpp
// Compile with:
// -fsanitize=address     (memory errors)
// -fsanitize=undefined   (undefined behavior)
// -fsanitize=thread      (data races)
```

---

## Documentation

### Document FFI Functions Clearly

```cpp
/// Create a new ArrayBuffer with the specified byte length.
///
/// @param isolate - The V8 isolate
/// @param byte_length - Size of the buffer in bytes
/// @return New ArrayBuffer, or nullptr if allocation failed
///
/// Example:
///   v8::ArrayBuffer* buffer = v8_ArrayBuffer_New(isolate, 1024);
///   if (buffer) {
///       // Use buffer...
///       v8_ArrayBuffer_Dispose(buffer);
///   }
extern "C" v8::ArrayBuffer* v8_ArrayBuffer_New(
    v8::Isolate* isolate,
    size_t byte_length
);
```

### Document Ownership and Lifetime

```cpp
/// Get the raw data pointer from an ArrayBuffer.
///
/// @param buffer - The ArrayBuffer
/// @return Pointer to backing store, or nullptr if detached
///
/// Lifetime: The pointer is valid only while the ArrayBuffer is alive
/// and not detached. Do not store this pointer beyond the current scope.
/// Do not free this pointer (managed by V8).
extern "C" void* v8_ArrayBuffer_Data(v8::ArrayBuffer* buffer);
```

---

## Anti-Patterns to Avoid

### ❌ Manual Memory Management

```cpp
// ❌ BAD: Raw new/delete
char* buffer = new char[1024];
// ... use buffer ...
delete[] buffer;

// ✅ GOOD: Use RAII containers
std::vector<char> buffer(1024);
// Automatically cleaned up
```

### ❌ C-Style Casts

```cpp
// ❌ BAD: C-style cast
void* ptr = (void*)object;

// ✅ GOOD: Modern C++ cast
void* ptr = static_cast<void*>(object);
```

### ❌ Ignoring Return Values

```cpp
// ❌ BAD: Ignoring Maybe<T>
value->ToString(context);  // Result ignored!

// ✅ GOOD: Check result
v8::MaybeLocal<v8::String> maybe_str = value->ToString(context);
if (!maybe_str.IsEmpty()) {
    v8::Local<v8::String> str = maybe_str.ToLocalChecked();
    // Use str...
}
```

### ❌ Using namespace std

```cpp
// ❌ BAD: Pollutes namespace
using namespace std;
using namespace v8;

// ✅ GOOD: Explicit namespace or specific using
std::string name;
v8::Local<v8::Value> value;

// OR: Specific using declarations
using std::string;
using v8::Local;
```

---

## Summary Checklist

When writing C++ code for V8 FFI:

- [ ] Use modern C++ features (C++17/C++20)
- [ ] Apply RAII for all resource management
- [ ] Use const everywhere possible
- [ ] Check all Maybe<T> and MaybeLocal<T> returns
- [ ] Use HandleScope for all Local<T> handles
- [ ] Use Global<T> for persistent handles
- [ ] Document ownership and lifetime semantics
- [ ] Return nullptr on errors in C API functions
- [ ] Prefer smart pointers over raw new/delete
- [ ] Use enum class over C-style enums
- [ ] Apply modern casts (static_cast, reinterpret_cast)
- [ ] Test with sanitizers (AddressSanitizer, UBSan)
- [ ] Follow naming conventions (snake_case for C API)
- [ ] Add debug assertions for preconditions

---

## Example: Complete V8 Wrapper Function

```cpp
/// Get the byte length of a TypedArray view.
///
/// This function safely extracts the byte length from a V8 TypedArray,
/// returning 0 if the view is invalid or detached.
///
/// @param typed_array - Pointer to V8 TypedArray (must be non-null)
/// @return Byte length of the view, or 0 if invalid/detached
///
/// Spec: https://tc39.es/ecma262/#sec-get-typedarray-bytelength
///
/// Example:
///   v8::TypedArray* view = GetTypedArrayFromSomewhere();
///   size_t length = v8_TypedArray_ByteLength(view);
///   if (length > 0) {
///       // View is valid and has data
///   }
extern "C" size_t v8_TypedArray_ByteLength(v8::TypedArray* typed_array) {
    // Validate input
    if (!typed_array) {
        return 0;
    }
    
    // Convert opaque pointer to V8 Local handle
    // Note: This assumes typed_array is actually a Local<TypedArray>*
    v8::Local<v8::TypedArray> local = 
        *reinterpret_cast<v8::Local<v8::TypedArray>*>(typed_array);
    
    // Check if view is detached
    v8::Local<v8::ArrayBuffer> buffer = local->Buffer();
    if (buffer->IsDetached()) {
        return 0;
    }
    
    // Return byte length
    return local->ByteLength();
}
```

---

## Key Differences from Zig

| Aspect | Zig | C++ |
|--------|-----|-----|
| Memory Management | Explicit allocators | RAII + smart pointers |
| Error Handling | Error unions (`!Type`) | Exceptions + Maybe<T> |
| Ownership | Explicit via allocator | Smart pointers + references |
| Const | `const` in type | `const` everywhere |
| Null Safety | Optional types (`?T`) | nullptr + std::optional |
| Generics | `comptime` + `anytype` | Templates |

---

## Resources

- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- [V8 Embedder's Guide](https://v8.dev/docs/embed)
- [Modern C++ Features](https://github.com/AnthonyCalandra/modern-cpp-features)
