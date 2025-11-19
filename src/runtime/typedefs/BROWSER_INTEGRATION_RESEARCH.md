# Browser Integration Research: Object & Promise

This document summarizes how Chrome, Firefox, and WebKit integrate JavaScript engine types (Object and Promise) with their internal C++ implementations.

## Executive Summary

All three browsers follow a similar architectural pattern:

```
┌─────────────────────────────────────────────┐
│ JavaScript Code (user script)               │
└───────────────┬─────────────────────────────┘
                │ calls
┌───────────────▼─────────────────────────────┐
│ JS Engine (V8/SpiderMonkey/JSC)             │
│ - Manages JS objects, promises              │
│ - Executes JavaScript code                  │
└───────────────┬─────────────────────────────┘
                │ bindings
┌───────────────▼─────────────────────────────┐
│ Generated Bindings Layer                    │
│ - Type conversions (JS ↔ C++)              │
│ - Wrapper management                        │
│ - GC integration                            │
└───────────────┬─────────────────────────────┘
                │ calls
┌───────────────▼─────────────────────────────┐
│ C++ Implementation (DOM, Fetch, etc.)       │
│ - Business logic                            │
│ - Platform APIs                             │
└─────────────────────────────────────────────┘
```

---

## Chrome (V8 + Blink)

### Object Integration

#### JS Engine Layer
- **Type**: `v8::Local<v8::Object>`
- **Purpose**: GC-safe handle to JavaScript object in V8 heap
- **Creation**: `v8::Object::New(isolate)`
- **Properties**: `obj->Set(context, key, value)`

#### C++ Wrapper Layer
- **Base Class**: `ScriptWrappable`
- **Mechanism**: JS object's internal field stores C++ pointer
- **Wrapper Cache**: Prevents creating duplicate JS wrappers

```cpp
// C++ side
class Node : public ScriptWrappable {
  String nodeName_;
  // ... C++ implementation
};

// Generated binding
v8::Local<v8::Object> V8Node::Wrap(ScriptState* state, Node* impl) {
  v8::Local<v8::Object> wrapper = CreateWrapper(state);
  wrapper->SetAlignedPointerInInternalField(0, impl);
  impl->AssociateWithWrapper(wrapper);
  return wrapper;
}

// Unwrap: JS object → C++ object
Node* V8Node::ToImpl(v8::Local<v8::Object> object) {
  return static_cast<Node*>(
    object->GetAlignedPointerFromInternalField(0)
  );
}
```

#### Key Pattern
1. JS calls method → V8 intercepts
2. V8 binding extracts C++ pointer from internal field
3. Calls C++ implementation
4. Converts C++ return value to V8 value
5. Returns to JavaScript

### Promise Integration

#### JS Engine Layer
- **Type**: `v8::Local<v8::Promise>`
- **Resolver**: `v8::Promise::Resolver` (creates + controls promise)
- **Creation**: `v8::Promise::Resolver::New(context)`

#### C++ Wrapper Layer
- **Wrapper Class**: `ScriptPromiseResolver`
- **Pattern**: Create resolver, return promise, resolve later

```cpp
// C++ method returning Promise<Response>
ScriptPromise FetchInternal(ScriptState* script_state, const String& url) {
  // 1. Create promise resolver
  auto* resolver = MakeGarbageCollected<ScriptPromiseResolver>(script_state);
  
  // 2. Get the promise to return
  ScriptPromise promise = resolver->Promise();
  
  // 3. Start async operation
  StartAsyncFetch(url, [resolver](Response* response) {
    // 4. Resolve later (on different thread/microtask)
    if (response) {
      resolver->Resolve(response);  // Converts Response* to v8::Value
    } else {
      resolver->Reject(V8ThrowException::CreateError(...));
    }
  });
  
  // 5. Return promise immediately
  return promise;
}
```

#### Memory Management
- **V8 GC**: Manages JavaScript heap
- **Oilpan GC**: Manages C++ wrapper objects
- **Cross-heap tracing**: Both GCs cooperate to trace references
- **Keep alive**: ScriptPromiseResolver kept alive until resolved/rejected

---

## Firefox (SpiderMonkey + Gecko)

### Object Integration

#### JS Engine Layer
- **Type**: `JS::Handle<JSObject*>` or `JS::HandleObject`
- **Purpose**: Rooted handle (prevents GC during C++ operation)
- **Creation**: `JS_NewPlainObject(cx)`
- **Properties**: `JS_SetProperty(cx, obj, "key", value)`

#### C++ Wrapper Layer
- **Base Class**: `nsWrapperCache`
- **Mechanism**: JS object's reserved slot stores C++ pointer
- **Wrapper Cache**: C++ object caches its JS wrapper

```cpp
// C++ side
class nsINode : public nsWrapperCache {
protected:
  // Inherited from nsWrapperCache:
  // JSObject* GetWrapper() const;
  // void SetWrapper(JSObject*);
  
  nsString mNodeName;
  // ... C++ implementation
};

// Generated binding
bool nsINode::WrapObject(JSContext* cx, JS::Handle<JSObject*> scope,
                         JS::MutableHandle<JSObject*> wrapper) {
  // Check cache first
  wrapper.set(GetWrapper());
  if (wrapper) {
    return true;
  }
  
  // Create new wrapper
  JSObject* obj = JS_NewObjectWithGivenProto(cx, &NodeClass, proto);
  
  // Store C++ pointer in reserved slot
  JS::SetReservedSlot(obj, DOM_OBJECT_SLOT, JS::PrivateValue(this));
  
  // Cache wrapper
  SetWrapper(obj);
  wrapper.set(obj);
  
  return true;
}

// Unwrap: JS object → C++ object
nsINode* UnwrapNode(JSObject* obj) {
  JS::Value v = JS::GetReservedSlot(obj, DOM_OBJECT_SLOT);
  return static_cast<nsINode*>(v.toPrivate());
}
```

#### Key Pattern
1. JS calls method → SpiderMonkey intercepts
2. SM binding extracts C++ pointer from reserved slot
3. Calls C++ implementation
4. Converts C++ return value to JS::Value
5. Returns to JavaScript

### Promise Integration

#### JS Engine Layer
- **Type**: `JS::Handle<JSObject*>` (where object is a Promise)
- **Creation**: SpiderMonkey creates promise internally
- **Resolution**: `JS::ResolvePromise(cx, promise, value)`

#### C++ Wrapper Layer
- **Wrapper Class**: `dom::Promise`
- **Pattern**: Wraps JS promise, provides C++ API

```cpp
// C++ method returning Promise<Response>
already_AddRefed<Promise> FetchInternal(const GlobalObject& global, const nsAString& url) {
  nsCOMPtr<nsIGlobalObject> globalObj = do_QueryInterface(global.GetAsSupports());
  ErrorResult rv;
  
  // 1. Create promise wrapper
  RefPtr<Promise> promise = Promise::Create(globalObj, rv);
  if (rv.Failed()) {
    return nullptr;
  }
  
  // 2. Start async operation
  StartAsyncFetch(url, [promise](Response* response) {
    // 3. Resolve later
    if (response) {
      promise->MaybeResolve(response);  // Converts Response* to JS::Value
    } else {
      promise->MaybeReject(NS_ERROR_FAILURE);
    }
  });
  
  // 4. Return promise (ref-counted)
  return promise.forget();
}
```

#### Memory Management
- **SpiderMonkey GC**: Manages JavaScript heap
- **Gecko refcounting**: C++ objects use `nsCOMPtr<T>` / `RefPtr<T>`
- **Cycle Collection**: Breaks cycles between JS and C++
- **Preserved wrappers**: Wrappers preserved when C++ object is alive

---

## WebKit (JavaScriptCore + WebCore)

### Object Integration

#### JS Engine Layer
- **Type**: `JSC::JSValue` (NaN-boxed 64-bit value)
- **Object Type**: `JSC::JSObject*`
- **Creation**: `JSObject::create(vm, structure)`
- **Properties**: `obj->putDirect(vm, propertyName, value)`

#### C++ Wrapper Layer
- **Base Template**: `JSDOMWrapper<T>`
- **Mechanism**: Template stores C++ `Ref<T>` pointer
- **Wrapper Cache**: Global wrapper map

```cpp
// C++ side
class Node : public RefCounted<Node> {
  String m_nodeName;
  // ... C++ implementation
};

// Generated binding
class JSNode : public JSDOMWrapper<Node> {
public:
  using Base = JSDOMWrapper<Node>;
  
  static JSNode* create(Structure* structure, JSDOMGlobalObject* globalObject, Ref<Node>&& impl) {
    JSNode* ptr = new (allocateCell<JSNode>(vm)) JSNode(structure, *globalObject, WTFMove(impl));
    ptr->finishCreation(vm);
    return ptr;
  }
  
  Node& wrapped() const { return *impl(); }  // impl() from JSDOMWrapper
  
private:
  JSNode(Structure*, JSDOMGlobalObject&, Ref<Node>&&);
};

// Wrap: C++ object → JS object
JSC::JSValue toJS(JSC::JSGlobalObject* globalObject, Node* node) {
  if (!node)
    return jsNull();
  
  // Check wrapper cache
  if (JSValue cachedWrapper = getCachedWrapper(globalObject->vm(), *node))
    return cachedWrapper;
  
  // Create new wrapper
  auto* wrapper = JSNode::create(
    JSNode::createStructure(globalObject->vm(), globalObject),
    jsCast<JSDOMGlobalObject*>(globalObject),
    makeRef(*node)
  );
  
  // Cache wrapper
  cacheWrapper(globalObject->vm(), *node, wrapper);
  
  return wrapper;
}

// Unwrap: JS object → C++ object
Node* JSNode::toWrapped(JSC::VM& vm, JSC::JSValue value) {
  if (auto* wrapper = jsDynamicCast<JSNode*>(value))
    return &wrapper->wrapped();
  return nullptr;
}
```

#### Key Pattern
1. JS calls method → JSC intercepts
2. JSC binding casts JSValue to JSNode*, extracts Ref<Node>
3. Calls C++ implementation
4. Converts C++ return value to JSC::JSValue
5. Returns to JavaScript

### Promise Integration

#### JS Engine Layer
- **Type**: `JSC::JSPromise*` (subclass of JSObject)
- **Creation**: `JSPromise::create(vm, structure)`
- **Resolution**: `promise->resolve(globalObject, value)`

#### C++ Wrapper Layer
- **Wrapper Class**: `DOMPromiseDeferred<T>` or `DOMPromise`
- **Pattern**: Deferred object passed by move, holds promise

```cpp
// C++ method returning Promise<Response>
void fetchInternal(DOMPromiseDeferred<IDLInterface<Response>>&& promise, const String& url) {
  // 1. Promise already created by binding generator
  // 2. Start async operation, move promise into lambda
  startAsyncFetch(url, [promise = WTFMove(promise)](RefPtr<Response> response) mutable {
    // 3. Resolve later
    if (response) {
      promise.resolve(*response);  // Converts Response to JSValue
    } else {
      promise.reject(Exception{TypeError, "Fetch failed"_s});
    }
  });
  // 4. Promise returned by binding layer
}

// Alternative: returning wrapped promise
Ref<DOMPromise> fetchAlternative(JSDOMGlobalObject& globalObject, const String& url) {
  // 1. Create promise
  auto promise = DOMPromise::create(globalObject);
  
  // 2. Start async operation
  startAsyncFetch(url, [promise](RefPtr<Response> response) {
    if (response)
      promise->resolve<IDLInterface<Response>>(*response);
    else
      promise->reject();
  });
  
  return promise;
}
```

#### Memory Management
- **JSC GC**: Conservative garbage collector
- **WebCore refcounting**: C++ objects use `Ref<T>` / `RefPtr<T>`
- **GC visitation**: JSDOMWrapper visits C++ object during marking
- **Weak references**: `WeakPtr<T>` for optional references

---

## Common Patterns Across All Browsers

### 1. Object Wrapping Pattern

**All browsers use the same fundamental approach:**

```
┌─────────────────────────────┐
│ JavaScript Object (JS heap) │
│ ┌─────────────────────────┐ │
│ │ Properties              │ │
│ │ Methods (bound funcs)   │ │
│ │ Internal Slot/Field     │──┼──→ Points to C++ object
│ └─────────────────────────┘ │
└─────────────────────────────┘
          ↑
          │ cached in
          │
┌─────────┴───────────────────┐
│ C++ Implementation Object   │
│ ┌─────────────────────────┐ │
│ │ Data members            │ │
│ │ Methods                 │ │
│ │ Wrapper cache pointer   │──┼──→ Points back to JS object
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

- **Bidirectional link**: JS object ↔ C++ object
- **Hidden storage**: C++ pointer stored in JS object's internal field/slot
- **Wrapper cache**: C++ object caches JS wrapper to avoid duplication
- **GC cooperation**: Both heaps must cooperate to prevent premature collection

### 2. Promise Integration Pattern

**All browsers follow this flow:**

```
1. JS calls async method:
   myObject.fetch("https://example.com")
   
2. Binding layer creates Promise + Resolver:
   [Chrome]  ScriptPromiseResolver
   [Firefox] dom::Promise  
   [WebKit]  DOMPromiseDeferred<T>
   
3. C++ receives resolver, starts async work:
   - Network request
   - File I/O
   - IPC to another process
   
4. Promise returned to JS immediately:
   let promise = myObject.fetch(...)
   
5. Later, async work completes:
   - Success: resolver.resolve(result)
   - Failure: resolver.reject(error)
   
6. JS promise callbacks execute:
   promise.then(result => ...)
```

**Key insight**: Promise is created synchronously, resolved asynchronously.

### 3. Type Conversion Pattern

**Boundary crossing always involves type conversion:**

```
JavaScript → C++:
  JS Value → Extract → Validate → Convert → C++ Type
  
  Example:
  JSValue "hello" → extract string → validate UTF-16 → convert → WTF::String

C++ → JavaScript:
  C++ Type → Convert → Wrap → Create → JS Value
  
  Example:
  Node* → convert → create wrapper → cache → v8::Local<v8::Object>
```

---

## Implications for Zig Runtime

Based on this research, here's what a Zig runtime needs for Object and Promise:

### For Object Type

```zig
// Runtime needs to provide opaque handles that can be passed to/from JS engine
pub const Object = struct {
    // Opaque pointer to JS engine's object
    // In real impl: *v8::Object, *JSObject, or *JSC::JSObject
    handle: *anyopaque,
    
    // Runtime context (V8::Isolate, JSContext, or JSC::VM)
    context: *anyopaque,
    
    // VTable for operations (set property, get property, etc.)
    vtable: *const ObjectVTable,
};

pub const ObjectVTable = struct {
    // Set property: obj["key"] = value
    setProperty: *const fn(*anyopaque, *anyopaque, []const u8, *anyopaque) anyerror!void,
    
    // Get property: value = obj["key"]
    getProperty: *const fn(*anyopaque, *anyopaque, []const u8) anyerror!*anyopaque,
    
    // Create new object
    create: *const fn(*anyopaque) anyerror!*anyopaque,
};
```

### For Promise Type

```zig
pub fn Promise(comptime T: type) type {
    return struct {
        // Opaque handle to JS promise
        handle: *anyopaque,
        
        // Opaque handle to resolver (for resolving the promise)
        resolver: *anyopaque,
        
        // Runtime context
        context: *anyopaque,
        
        // VTable for promise operations
        vtable: *const PromiseVTable(T),
        
        const Self = @This();
        
        // Create new promise (returns promise + ability to resolve it later)
        pub fn create(context: *anyopaque, vtable: *const PromiseVTable(T)) !Self {
            const handles = try vtable.create(context);
            return .{
                .handle = handles.promise,
                .resolver = handles.resolver,
                .context = context,
                .vtable = vtable,
            };
        }
        
        // Resolve the promise with a value
        pub fn resolve(self: *Self, value: T) !void {
            try self.vtable.resolve(self.context, self.resolver, value);
        }
        
        // Reject the promise with an error
        pub fn reject(self: *Self, err: anyerror) !void {
            try self.vtable.reject(self.context, self.resolver, err);
        }
    };
}

pub fn PromiseVTable(comptime T: type) type {
    return struct {
        create: *const fn(*anyopaque) anyerror!struct { promise: *anyopaque, resolver: *anyopaque },
        resolve: *const fn(*anyopaque, *anyopaque, T) anyerror!void,
        reject: *const fn(*anyopaque, *anyopaque, anyerror) anyerror!void,
    };
}
```

### Key Requirements

1. **Opaque Handles**: Runtime types must be opaque pointers (actual JS engine objects)
2. **VTable Pattern**: Operations dispatched through function pointers (JS engine provides impl)
3. **Context Passing**: All operations need runtime context (Isolate/Context/VM)
4. **No Direct Implementation**: Zig runtime doesn't implement Object/Promise, just provides types
5. **JS Engine Provides Implementation**: Actual object/promise operations delegated to JS engine

---

## Conclusion

All three browsers follow remarkably similar patterns:

1. **Object wrapping**: Bidirectional link between JS and C++ objects
2. **Promise deferred resolution**: Create promise, return immediately, resolve later
3. **Type conversion**: Explicit conversion at JS/C++ boundary
4. **GC cooperation**: Both heaps cooperate to manage lifetimes
5. **Opaque handles**: C++ code works with handles to JS objects, not raw pointers

**For Zig runtime**: The key insight is that `Object` and `Promise` should be **opaque handles with vtables**, not concrete implementations. The actual implementation is provided by the linked JavaScript engine (V8, SpiderMonkey, or JSC).
