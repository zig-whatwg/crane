## 1. Introduction

By design, the
[scope](https://webassembly.github.io/spec/core/intro/introduction.html#scope) of the WebAssembly core specification
[\[WEBASSEMBLY\]](#biblio-webassembly "WebAssembly Core Specification")
does not include a description of how WebAssembly programs interact with
their surrounding execution environment. Instead it defines an abstract
[embedding
interface](https://webassembly.github.io/spec/core/#appending/embedding.html) between WebAssembly and its environment, (called the
*embedder*). It is only through this interface that an embedder
interacts with the semantics of WebAssembly, and the embedder implements
the connection between its host environment and the embedding API. This
document describes the embedding of WebAssembly into JavaScript
[\[ECMASCRIPT\]](#biblio-ecmascript "ECMAScript Language Specification")
environments, including how WebAssembly modules can be constructed and
instantiated, how imported and exported functions are called, how data
is exchanged, and how errors are handled. When the JavaScript
environment is itself embedded in a Web browser, the Web API spec
[\[WASMWEB\]](#biblio-wasmweb "WebAssembly Web API Specification")
describes additional behavior relevant to the Web environment.

## 2. Sample API Usage

*This section is non-normative.*

Given `demo.wat` (encoded to `demo.wasm`):

```
(module
 (import "js" "import1" (func $i1))
 (import "js" "import2" (func $i2))
 (func $main (call $i1))
 (start $main)
 (func (export "f") (call $i2))
)
```

and the following JavaScript, run in a browser:

```
var importObj = {js: {
 import1: () => console.log("hello,"),
 import2: () => console.log("world!")
}};
fetch('demo.wasm').then(response =>
 response.arrayBuffer()
).then(buffer =>
 WebAssembly.instantiate(buffer, importObj)
).then(({module, instance}) =>
 instance.exports.f()
);
```

## 3. Notation

This specification depends on the Infra Standard.
[\[INFRA\]](#biblio-infra "Infra Standard")

The WebAssembly
[sequence](https://webassembly.github.io/spec/core/syntax/conventions.html#grammar-notation) type is equivalent to the
[list](https://infra.spec.whatwg.org/#list) type defined there; values of one are treated as values
of the other transparently.

## 4. Internal storage

### 4.1. Interaction of the WebAssembly Store with JavaScript

 WebAssembly semantics are defined in terms of an
abstract
[store](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-store), representing the state of the WebAssembly abstract
machine. WebAssembly operations take a store and return an updated
store.

Each
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent) has an [associated store]. When a new agent is created,
its associated store is set to the result of
[store_init](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-store-init)().

 In this specification, no WebAssembly-related objects,
memory or addresses can be shared among agents in an [agent
cluster](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters). In a future version of WebAssembly, this may change.

Elements of the WebAssembly store may be [identified
with]
JavaScript values. In particular, each WebAssembly [memory
instance](https://webassembly.github.io/spec/core/exec/runtime.html#memory-instances) with a corresponding
[`Memory`](#memory) object is
identified with a JavaScript [Data
Block](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-data-blocks); modifications to this Data Block are identified to
updating the agent's store to a store which reflects those changes, and
vice versa.

### 4.2. WebAssembly JS Object Caches

 There are several WebAssembly objects that may have a
corresponding JavaScript object. The correspondence is stored in a
per-agent mapping from WebAssembly
[address](https://webassembly.github.io/spec/core/exec/runtime.html#addresses)es to JavaScript objects. This mapping is used to ensure
that, for a given
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent), there exists at most one JavaScript object for a
particular WebAssembly address. However, this property does not hold for
shared objects.

Each
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent) is associated with the following [ordered
map](https://infra.spec.whatwg.org/#ordered-map)s:

- The [Memory object cache], mapping [memory
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr)es to [`Memory`](#memory) objects.

- The [Table object cache], mapping [table
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tableaddr)es to [`Table`](#table) objects.

- The [Exported Function cache], mapping [function
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-funcaddr)es to [Exported
 Function](#exported-function) objects.

- The [Exported GC Object cache], mapping [struct
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-structaddr)es and [array
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-arrayaddr)es to [Exported GC
 Object](#exported-gc-object) objects.

- The [Global object cache], mapping [global
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-globaladdr)es to [`Global`](#global) objects.

- The [Tag object cache], mapping [tag
 addresses](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tagaddr) to [`Tag`](#tag)
 objects.

- The [Exception object cache], mapping [exception
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-exnaddr)es to
 [`Exception`](#exception)
 objects.

- The [Host value cache], mapping [host
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-hostaddr)es to values.

### 4.3. Execution Context Status Map

 The Execution Context Status Map is used to enforce
certain correspondences between JavaScript execution and WebAssembly
execution; particularly in relation to the JavaScript Promise
Integration API.

Each
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent) is associated with the following [ordered
map](https://infra.spec.whatwg.org/#ordered-map):

- The [Execution Context Status map] is used to map [execution
 contexts](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-execution-contexts) to [stack
 status](#stack-status) values.

## 5. The WebAssembly Namespace

```
dictionary WebAssemblyInstantiatedSource {
 required Module module;
 required Instance instance;
};

[Exposed=*]
namespace WebAssembly {
 boolean validate(BufferSource bytes);
 Promise<Module> compile(BufferSource bytes);

 Promise<WebAssemblyInstantiatedSource> instantiate(
 BufferSource bytes, optional object importObject);

 Promise<Instance> instantiate(
 Module moduleObject, optional object importObject);

 readonly attribute Tag JSTag;
};
```

To [compile a WebAssembly module] from source bytes
`bytes`, perform the following steps:

1. Let `module` be
 [module_decode](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-decode)(`bytes`). If `module` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), return
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error).

2. If
 [module_validate](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-validate)(`module`) is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), return
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error).

3. Return `module`.

The [`validate(``bytes``)`] method, when invoked, performs the following steps:

1. Let `stableBytes` be a [copy of the bytes held by the
 buffer](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `bytes`.

2. [Compile](#compile-a-webassembly-module) `stableBytes` as a WebAssembly module
 and store the results as `module`.

3. If `module` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), return false.

4. Return true.

A [`Module`](#module) object
represents a single WebAssembly module. Each
[`Module`](#module) object has
the following internal slots:

- \[\[Module\]\] : a WebAssembly
 [module](https://webassembly.github.io/spec/core/syntax/modules.html#syntax-module)

- \[\[Bytes\]\] : the source bytes of \[\[Module\]\].

To [construct a WebAssembly module
object] from a module `module` and source
bytes `bytes`, perform the following steps:

1. Let `moduleObject` be a new
 [`Module`](#module) object.

2. Set `moduleObject`.\[\[Module\]\] to `module`.

3. Set `moduleObject`.\[\[Bytes\]\] to `bytes`.

4. Return `moduleObject`.

To [asynchronously compile a WebAssembly
module] from source bytes `bytes`, using
optional [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) `taskSource`, perform the following steps:

1. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. [Compile the WebAssembly
 module](#compile-a-webassembly-module) `bytes` and store the result as
 `module`.

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps. If
 `taskSource` was provided, queue the task on that
 task source.

 1. If `module` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), reject `promise` with a
 [`CompileError`](#exceptiondef-compileerror) exception.

 2. Otherwise,

 1. [Construct a WebAssembly module
 object](#construct-a-webassembly-module-object) from `module` and
 `bytes`, and let `moduleObject` be
 the result.

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `moduleObject`.

3. Return `promise`.

The [`compile(``bytes``)`] method, when invoked, performs the following steps:

1. Let `stableBytes` be a [copy of the bytes held by the
 buffer](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `bytes`.

2. [Asynchronously compile a WebAssembly
 module](#asynchronously-compile-a-webassembly-module) from `stableBytes` and return the
 result.

To [read the imports] from a WebAssembly module `module` from imports
object `importObject`, perform the following steps:

1. If
 `module`.[imports](https://webassembly.github.io/spec/core/syntax/modules.html#syntax-module) [is not
 empty](https://infra.spec.whatwg.org/#list-is-empty), and `importObject` is undefined, throw
 a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

2. Let `imports` be « ».

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) (`moduleName`,
 `componentName`, `externtype`) of
 [module_imports](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-imports)(`module`),

 1. Let `o` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`importObject`,
 `moduleName`).

 2. If
 [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`o`) is not Object, throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

 3. Let `v` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`o`,
 `componentName`).

 4. If `externtype` is of the form
 [func](https://webassembly.github.io/spec/core/syntax/types.html#heap-types) `functype`,

 1. If
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`v`) is true,

 1. If `v` has a \[\[FunctionAddress\]\] internal
 slot, and therefore is an [Exported
 Function](#exported-function),

 1. Let `funcaddr` be the value of
 `v`'s \[\[FunctionAddress\]\] internal
 slot.

 2. Otherwise,

 1. [Create a host
 function](#create-a-host-function) from `v` and
 `functype`, and let `funcaddr`
 be the result.

 2. Otherwise, if `v` has a \[\[WrappedFunction\]\]
 internal slot,

 1. Let `func` be the value of `v`'s
 \[\[WrappedFunction\]\] internal slot.

 2. Assert:
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`func`) is true.

 3. [create a suspending
 function](#create-a-suspending-function) from `func` and
 `functype`, and let `funcaddr` be
 the result.

 3. Otherwise, throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 4. Let `index` be the number of external functions
 in `imports`. This value `index` is
 known as the [index of the host
 function] `funcaddr`.

 5. Let `externfunc` be the [external
 value](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval)
 [func](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `funcaddr`.

 6. [Append](https://infra.spec.whatwg.org/#list-append) `externfunc` to
 `imports`.

 5. If `externtype` is of the form
 [global](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `mut` `valtype`,

 1. If `v`
 [implements](https://webidl.spec.whatwg.org/#implements) [`Global`](#global),

 1. Let `globaladdr` be
 `v`.\[\[Global\]\].

 2. Otherwise,

 1. If `valtype` is
 [i64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype) and
 [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`v`) is not BigInt,

 1. Throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 2. If `valtype` is one of
 [i32](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype),
 [f32](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype) or
 [f64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype) and
 [Type](https://tc39.github.io/ecma262/#sec-ecmascript-data-types-and-values)(`v`) is not Number,

 1. Throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 3. If `valtype` is
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types),

 1. Throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 4. Let `value` be
 [ToWebAssemblyValue](#towebassemblyvalue)(`v`, `valtype`).
 If this operation throws a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror), catch it, and throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 5. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

 6. Let (`store`, `globaladdr`) be
 [global_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-global-alloc)(`store`,
 [const](https://webassembly.github.io/spec/core/syntax/types.html#syntax-mut) `valtype`,
 `value`).

 7. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

 3. Let `externglobal` be
 [global](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `globaladdr`.

 4. [Append](https://infra.spec.whatwg.org/#list-append) `externglobal` to
 `imports`.

 6. If `externtype` is of the form
 [mem](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `memtype`,

 1. If `v` does not
 [implement](https://webidl.spec.whatwg.org/#implements) [`Memory`](#memory), throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 2. Let `externmem` be the [external
 value](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval)
 [mem](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `v`.\[\[Memory\]\].

 3. [Append](https://infra.spec.whatwg.org/#list-append) `externmem` to
 `imports`.

 7. If `externtype` is of the form
 [table](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `tabletype`,

 1. If `v` does not
 [implement](https://webidl.spec.whatwg.org/#implements) [`Table`](#table), throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 2. Let `tableaddr` be `v`.\[\[Table\]\].

 3. Let `externtable` be the [external
 value](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval)
 [table](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `tableaddr`.

 4. [Append](https://infra.spec.whatwg.org/#list-append) `externtable` to
 `imports`.

 8. If `externtype` is of the form
 [tag](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `attribute`
 `functype`,

 1. Assert: `attribute` is
 [exception](https://webassembly.github.io/spec/core/syntax/types.html#syntax-tagtype).

 2. If `v` does not
 [implement](https://webidl.spec.whatwg.org/#implements) [`Tag`](#tag), throw a
 [`LinkError`](#exceptiondef-linkerror) exception.

 3. Let `tagaddr` be `v`.\[\[Address\]\].

 4. Let `externtag` be the [external
 value](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval)
 [tag](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval)
 `tagaddr`.

 5. [Append](https://infra.spec.whatwg.org/#list-append) `externtag` to
 `imports`.

4. Return `imports`.

 This algorithm only verifies the right kind of
JavaScript values are passed. The verification of WebAssembly type
requirements is deferred to the \"[instantiate the core of a WebAssembly
module](#instantiate-the-core-of-a-webassembly-module)\" algorithm.

To [create an exports object] from a WebAssembly module
`module` and instance `instance`, perform the
following steps:

1. Let `exportsObject` be
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(null).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) (`name`, `externtype`) of
 [module_exports](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-exports)(`module`),

 1. Let `externval` be
 [instance_export](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-instance-export)(`instance`, `name`).

 2. Assert: `externval` is not
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error).

 3. If `externtype` is of the form
 [func](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `functype`,

 1. Assert: `externval` is of the form
 [func](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `funcaddr`.

 2. Let
 [func](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `funcaddr` be
 `externval`.

 3. Let `func` be the result of creating [a new
 Exported
 Function](#a-new-exported-function) from `funcaddr`.

 4. Let `value` be `func`.

 4. If `externtype` is of the form
 [global](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `mut` `globaltype`,

 1. Assert: `externval` is of the form
 [global](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `globaladdr`.

 2. Let
 [global](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `globaladdr` be
 `externval`.

 3. Let `global` be [a new Global
 object](#create-a-global-object) created from `globaladdr`.

 4. Let `value` be `global`.

 5. If `externtype` is of the form
 [mem](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `memtype`,

 1. Assert: `externval` is of the form
 [mem](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `memaddr`.

 2. Let
 [mem](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `memaddr` be
 `externval`.

 3. Let `memory` be [a new Memory
 object](#create-a-memory-object) created from `memaddr`.

 4. Let `value` be `memory`.

 6. If `externtype` is of the form
 [table](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `tabletype`,

 1. Assert: `externval` is of the form
 [table](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `tableaddr`.

 2. Let
 [table](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `tableaddr` be
 `externval`.

 3. Let `table` be [a new Table
 object](#create-a-table-object) created from `tableaddr`.

 4. Let `value` be `table`.

 7. If `externtype` is of the form
 [tag](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `attribute`
 `functype`,

 1. Assert: `attribute` is
 [exception](https://webassembly.github.io/spec/core/syntax/types.html#syntax-tagtype).

 2. Assert: `externval` is of the form
 [tag](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval)
 `tagaddr`.

 3. Let
 [tag](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-externval) `tagaddr`
 be `externval`.

 4. Let `tag` be [a new Tag
 object](#create-a-tag-object) created from `tagaddr`.

 5. Let `value` be `tag`.

 8. Let `status` be
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [CreateDataProperty](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdataproperty)(`exportsObject`,
 `name`, `value`).

 9. Assert: `status` is true.

 the validity and uniqueness checks performed during
 [WebAssembly module
 validation](https://webassembly.github.io/spec/core/valid/modules.html#valid-module) ensure that each property name is valid and no
 properties are defined twice.

3. Perform
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [SetIntegrityLevel](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-setintegritylevel)(`exportsObject`, `"frozen"`).

4. Return `exportsObject`.

To [initialize an instance object] `instanceObject`
from a WebAssembly module `module` and instance
`instance`, perform the following steps:

1. [Create an exports
 object](#create-an-exports-object) from `module` and `instance`
 and let `exportsObject` be the result.

2. Set `instanceObject`.\[\[Instance\]\] to
 `instance`.

3. Set `instanceObject`.\[\[Exports\]\] to
 `exportsObject`.

To [instantiate the core of a WebAssembly
module] from a module `module` and
imports `imports`, perform the following steps:

1. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

2. Let `result` be
 [module_instantiate](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-instantiate)(`store`, `module`,
 `imports`).

3. If `result` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw an appropriate exception type:

 - A
 [`LinkError`](#exceptiondef-linkerror) exception for most cases which occur during
 linking.

 - If the error came when running the start function, throw a
 [`RuntimeError`](#exceptiondef-runtimeerror) for most errors which occur from WebAssembly, or
 the error object propagated from inner ECMAScript code.

 - Another error type if appropriate, for example an out-of-memory
 exception, as documented in [the WebAssembly error
 mapping](#errors).

4. Let (`store`, `instance`) be
 `result`.

5. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

6. Return `instance`.

To [asynchronously instantiate a WebAssembly
module] from a
[`Module`](#module)
`moduleObject` and imports `importObject`, perform
the following steps:

1. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. Let `module` be `moduleObject`.\[\[Module\]\].

3. [Read the imports](#read-the-imports) of `module` with imports
 `importObject`, and let `imports` be the
 result. If this operation throws an exception, catch it,
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with the exception, and return
 `promise`.

4. Run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps: Note:
 Implementation-specific work may be performed here.

 1. [Instantiate the core of a WebAssembly
 module](#instantiate-the-core-of-a-webassembly-module) `module` with
 `imports`, and let `instance` be the
 result. If this throws an exception, catch it,
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with the exception,
 and terminate these substeps.

 2. Let `instanceObject` be a
 [new](https://webidl.spec.whatwg.org/#new)
 [`Instance`](#instance).

 3. [Initialize](#initialize-an-instance-object) `instanceObject` from
 `module` and `instance`. If this
 throws an exception, catch it,
 [reject](https://webidl.spec.whatwg.org/#reject) `promise` with the exception,
 and terminate these substeps.

 4. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `instanceObject`.

5. Return `promise`.

To [instantiate a promise of a
module] `promiseOfModule` with imports
`importObject`, perform the following steps:

1. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

2. [Upon
 fulfillment](https://webidl.spec.whatwg.org/#upon-fulfillment) of `promiseOfModule` with value
 `module`:

 1. [Instantiate the WebAssembly
 module](#asynchronously-instantiate-a-webassembly-module) `module` importing
 `importObject`, and let `innerPromise` be
 the result.

 2. [Upon
 fulfillment](https://webidl.spec.whatwg.org/#upon-fulfillment) of `innerPromise` with value
 `instance`.

 1. Let `result` be the
 [`WebAssemblyInstantiatedSource`](#dictdef-webassemblyinstantiatedsource) value «\[
 \"[`module`](#dom-webassemblyinstantiatedsource-module)\" → `module`,
 \"[`instance`](#dom-webassemblyinstantiatedsource-instance)\" → `instance` \]».

 2. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `result`.

 3. [Upon
 rejection](https://webidl.spec.whatwg.org/#upon-rejection) of `innerPromise` with reason
 `reason`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with
 `reason`.

3. [Upon
 rejection](https://webidl.spec.whatwg.org/#upon-rejection) of `promiseOfModule` with reason
 `reason`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with `reason`.

4. Return `promise`.

[`instantiate(``bytes``, ``importObject``)`]
method, when invoked, performs the following steps:

1. Let `stableBytes` be a [copy of the bytes held by the
 buffer](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `bytes`.

2. [Asynchronously compile a WebAssembly
 module](#asynchronously-compile-a-webassembly-module) from `stableBytes` and let
 `promiseOfModule` be the result.

3. [Instantiate](#instantiate-a-promise-of-a-module) `promiseOfModule` with imports
 `importObject` and return the result.

[`instantiate(``moduleObject``, ``importObject``)`]
method, when invoked, performs the following steps:

1. [Asynchronously instantiate the WebAssembly
 module](#asynchronously-instantiate-a-webassembly-module) `moduleObject` importing
 `importObject`, and return the result.

 A follow-on streaming API is documented in the
[WebAssembly Web
API](https://webassembly.github.io/spec/web-api/index.html).

The getter of the [`JSTag`]
attribute of the
[`WebAssembly`](#namespacedef-webassembly) Namespace, when invoked, performs the following steps:

1. Let `JSTagAddr` be the result of [getting the JavaScript
 exception
 tag](#get-the-javascript-exception-tag).

2. Let `JSTagObject` be the result of [creating a Tag
 object](#create-a-tag-object) from `JSTagAddr`.

3. Return `JSTagObject`.

### 5.1. Modules

```
enum ImportExportKind {
 "function",
 "table",
 "memory",
 "global",
 "tag"
};

dictionary ModuleExportDescriptor {
 required USVString name;
 required ImportExportKind kind;
 // Note: Other fields such as signature may be added in the future.
};

dictionary ModuleImportDescriptor {
 required USVString module;
 required USVString name;
 required ImportExportKind kind;
};

[LegacyNamespace=WebAssembly, Exposed=*]
interface Module {
 constructor(BufferSource bytes);
 static sequence<ModuleExportDescriptor> exports(Module moduleObject);
 static sequence<ModuleImportDescriptor> imports(Module moduleObject);
 static sequence<ArrayBuffer> customSections(Module moduleObject, DOMString sectionName);
};
```

The [string value of the extern type] `type` is

- \"function\" if `type` is of the form
 [func](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `functype`

- \"table\" if `type` is of the form
 [table](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `tabletype`

- \"memory\" if `type` is of the form
 [mem](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `memtype`

- \"global\" if `type` is of the form
 [global](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `globaltype`

- \"tag\" if `type` is of the form
 [tag](https://webassembly.github.io/spec/core/syntax/types.html#external-types) `tag`

The [`exports(``moduleObject``)`]
method, when invoked, performs the following steps:

1. Let `module` be `moduleObject`.\[\[Module\]\].

2. Let `exports` be « ».

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) (`name`, `type`) of
 [module_exports](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-exports)(`module`),

 1. Let `kind` be the [string value of the extern
 type](#string-value-of-the-extern-type) `type`.

 2. Let `obj` be «\[
 \"[`name`](#dom-moduleexportdescriptor-name)\" → `name`,
 \"[`kind`](#dom-moduleexportdescriptor-kind)\" → `kind` \]».

 3. [Append](https://infra.spec.whatwg.org/#list-append) `obj` to `exports`.

4. Return `exports`.

The [`imports(``moduleObject``)`]
method, when invoked, performs the following steps:

1. Let `module` be `moduleObject`.\[\[Module\]\].

2. Let `imports` be « ».

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) (`moduleName`, `name`,
 `type`) of
 [module_imports](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-module-imports)(`module`),

 1. Let `kind` be the [string value of the extern
 type](#string-value-of-the-extern-type) `type`.

 2. Let `obj` be «\[
 \"[`module`](#dom-moduleimportdescriptor-module)\" → `moduleName`,
 \"[`name`](#dom-moduleimportdescriptor-name)\" → `name`,
 \"[`kind`](#dom-moduleimportdescriptor-kind)\" → `kind` \]».

 3. [Append](https://infra.spec.whatwg.org/#list-append) `obj` to `imports`.

4. Return `imports`.

[`customSections(``moduleObject``, ``sectionName``)`] method, when invoked, performs the following steps:

1. Let `bytes` be `moduleObject`.\[\[Bytes\]\].

2. Let `customSections` be « ».

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) [custom
 section](https://webassembly.github.io/spec/core/binary/modules.html#custom-section) `customSection` of `bytes`,
 interpreted according to the [module
 grammar](https://webassembly.github.io/spec/core/binary/modules.html#binary-module),

 1. Let `name` be the `name` of
 `customSection`, [decoded as
 UTF-8](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom-or-fail).

 2. Assert: `name` is not failure
 (`moduleObject`.\[\[Module\]\] is
 [valid](https://webassembly.github.io/spec/core/valid/modules.html#valid-module)).

 3. If `name` equals `sectionName` as string
 values,

 1. [Append](https://infra.spec.whatwg.org/#list-append) a new
 [`ArrayBuffer`](https://tc39.github.io/ecma262/#sec-arraybuffer-objects) containing a copy of the bytes in
 `bytes` for the range matched by this
 [customsec](https://webassembly.github.io/spec/core/binary/modules.html#binary-customsec) production to `customSections`.

4. Return `customSections`.

The [`Module(``bytes``)`] constructor, when invoked,
performs the following steps:

1. Let `stableBytes` be a [copy of the bytes held by the
 buffer](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `bytes`.

2. [Compile the WebAssembly
 module](#compile-a-webassembly-module) `stableBytes` and store the result as
 `module`.

3. If `module` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`CompileError`](#exceptiondef-compileerror) exception.

4. Set **this**.\[\[Module\]\] to `module`.

5. Set **this**.\[\[Bytes\]\] to `stableBytes`.

 Some implementations enforce a size limitation on
`bytes`. Use of this API is discouraged, in favor of
asynchronous APIs.

### 5.2. Instances

```
[LegacyNamespace=WebAssembly, Exposed=*]
interface Instance {
 constructor(Module module, optional object importObject);
 readonly attribute object exports;
};
```

[`Instance(``module``, ``importObject``)`]
constructor, when invoked, runs the following steps:

1. Let `module` be `module`.\[\[Module\]\].

2. [Read the imports](#read-the-imports) of `module` with imports
 `importObject`, and let `imports` be the
 result.

3. [Instantiate the core of a WebAssembly
 module](#instantiate-the-core-of-a-webassembly-module) `module` with `imports`, and
 let `instance` be the result.

4. [Initialize](#initialize-an-instance-object) **this** from `module` and
 `instance`.

 The use of this synchronous API is discouraged, as some
implementations sometimes do long-running compilation work when
instantiating.

The getter of the [`exports`] attribute
of [`Instance`](#instance)
returns **this**.\[\[Exports\]\].

### 5.3. Memories

```
dictionary MemoryDescriptor {
 required [EnforceRange] unsigned long initial;
 [EnforceRange] unsigned long maximum;
};

[LegacyNamespace=WebAssembly, Exposed=*]
interface Memory {
 constructor(MemoryDescriptor descriptor);
 unsigned long grow([EnforceRange] unsigned long delta);
 ArrayBuffer toFixedLengthBuffer();
 ArrayBuffer toResizableBuffer();
 readonly attribute ArrayBuffer buffer;
};
```

A [`Memory`](#memory) object
represents a single [memory
instance](https://webassembly.github.io/spec/core/exec/runtime.html#memory-instances) which can be simultaneously referenced by multiple
[`Instance`](#instance)
objects. Each [`Memory`](#memory) object has the following internal slots:

- \[\[Memory\]\] : a [memory
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr)

- \[\[BufferObject\]\] : an
 [`ArrayBuffer`](https://tc39.github.io/ecma262/#sec-arraybuffer-objects) whose [Data
 Block](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-data-blocks) is [identified
 with](#identified-with) the
 above memory address

To [create a fixed length memory
buffer] from a [memory
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr) `memaddr`, perform the following steps:

1. Let `block` be a [Data
 Block](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-data-blocks) which is [identified
 with](#identified-with)
 the underlying memory of `memaddr`.

2. Let `buffer` be a new
 [`ArrayBuffer`](https://tc39.github.io/ecma262/#sec-arraybuffer-objects) with the internal slots \[\[ArrayBufferData\]\],
 \[\[ArrayBufferByteLength\]\], and \[\[ArrayBufferDetachKey\]\].

3. Set `buffer`.\[\[ArrayBufferData\]\] to
 `block`.

4. Set `buffer`.\[\[ArrayBufferByteLength\]\] to the length
 of `block`.

5. Set `buffer`.\[\[ArrayBufferDetachKey\]\] to
 \"WebAssembly.Memory\".

6. Return `buffer`.

To [create a resizable memory buffer] from a [memory
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr) `memaddr` and a `maxsize`,
perform the following steps:

1. Let `block` be a [Data
 Block](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-data-blocks) which is [identified
 with](#identified-with)
 the underlying memory of `memaddr`.

2. Let `length` be the length of `block`.

3. If `maxsize` \> (65536 × 65536),

 1. Throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

4. Let `buffer` be a new
 [`ArrayBuffer`](https://tc39.github.io/ecma262/#sec-arraybuffer-objects) with the internal slots \[\[ArrayBufferData\]\],
 \[\[ArrayBufferByteLength\]\], \[\[ArrayBufferMaxByteLength\]\], and
 \[\[ArrayBufferDetachKey\]\].

5. Set `buffer`.\[\[ArrayBufferData\]\] to
 `block`.

6. Set `buffer`.\[\[ArrayBufferByteLength\]\] to
 `length`.

7. Set `buffer`.\[\[ArrayBufferMaxByteLength\]\] is
 `maxsize`.

8. Set `buffer`.\[\[ArrayBufferDetachKey\]\] to
 \"WebAssembly.Memory\".

9. Return `buffer`.

To [initialize a memory object] `memory` from a
[memory
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr) `memaddr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Memory object
 cache](#memory-object-cache).

2. Assert: `map`\[`memaddr`\] doesn't
 [exist](https://infra.spec.whatwg.org/#map-exists).

3. Let `buffer` be the result of [creating a fixed length
 memory
 buffer](#create-a-fixed-length-memory-buffer) from `memaddr`.

4. Set `memory`.\[\[Memory\]\] to `memaddr`.

5. Set `memory`.\[\[BufferObject\]\] to `buffer`.

6. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`memaddr`\] to
 `memory`.

To [create a memory object] from a [memory
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr) `memaddr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Memory object
 cache](#memory-object-cache).

2. If `map`\[`memaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`memaddr`\].

3. Let `memory` be a
 [new](https://webidl.spec.whatwg.org/#new) [`Memory`](#memory).

4. [Initialize](#initialize-a-memory-object) `memory` from `memaddr`.

5. Return `memory`.

The [`Memory(``descriptor``)`] constructor, when
invoked, performs the following steps:

1. Let `initial` be `descriptor`\[\"initial\"\].

2. If `descriptor`\[\"maximum\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists), let `maximum` be
 `descriptor`\[\"maximum\"\]; otherwise, let
 `maximum` be empty.

3. If `maximum` is not empty and `maximum` \<
 `initial`, throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

4. Let `memtype` be { min `initial`, max
 `maximum` }.

5. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

6. Let (`store`, `memaddr`) be
 [mem_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-mem-alloc)(`store`, `memtype`). If
 allocation fails, throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

7. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

8. [Initialize](#initialize-a-memory-object) **this** from `memaddr`.

To [refresh the Memory buffer] of `memaddr`,
perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Memory object
 cache](#memory-object-cache).

2. Assert: `map`\[`memaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists).

3. Let `memory` be `map`\[`memaddr`\].

4. Let `buffer` be `memory`.\[\[BufferObject\]\].

5. If
 [IsFixedLengthArrayBuffer](https://tc39.es/proposal-resizablearraybuffer/#sec-isfixedarraybuffer)(`buffer`) is true,

 1. Perform
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [DetachArrayBuffer](https://tc39.es/ecma262/multipage/structured-data.html#sec-detacharraybuffer)(`buffer`,
 \"WebAssembly.Memory\").

 2. Let `buffer` be the result of [creating a fixed
 length memory
 buffer](#create-a-fixed-length-memory-buffer) from `memaddr`.

 3. Set `memory`.\[\[BufferObject\]\] to
 `buffer`.

6. Otherwise,

 1. Let `block` be a [Data
 Block](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-data-blocks) which is [identified
 with](#identified-with) the underlying memory of `memaddr`.

 2. Set `buffer`.\[\[ArrayBufferData\]\] to
 `block`.

 3. Set `buffer`.\[\[ArrayBufferByteLength\]\] to the
 length of `block`.

To [grow the memory buffer] associated with a [memory
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-memaddr) `memaddr` by `delta`, perform the
following steps:

1. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

2. Let `ret` be the
 [mem_size](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-mem-size)(`store`, `memaddr`).

3. Let `store` be
 [mem_grow](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-mem-grow)(`store`, `memaddr`,
 `delta`).

4. If `store` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

5. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

6. [Refresh the memory
 buffer](#refresh-the-memory-buffer) of `memaddr`.

7. Return `ret`.

The [`grow(``delta``)`] method, when
invoked, performs the following steps:

1. Let `memaddr` be **this**.\[\[Memory\]\].

2. Return the result of [growing the memory
 buffer](#grow-the-memory-buffer) associated with `memaddr` by
 `delta`.

Immediately after a WebAssembly
[memory.grow](https://webassembly.github.io/spec/core/exec/instructions.html#exec-memory-grow) instruction executes, perform the following steps:

1. If the top of the stack is not
 [i32.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) (−1),

 1. Let `frame` be the [current
 frame](https://webassembly.github.io/spec/core/exec/conventions.html#exec-notation-textual).

 2. Assert: Due to validation,
 `frame`.[module](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-frame).[memaddrs](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-moduleinst)\[0\] exists.

 3. Let `memaddr` be the memory address
 `frame`.[module](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-frame).[memaddrs](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-moduleinst)\[0\].

 4. [Refresh the memory
 buffer](#refresh-the-memory-buffer) of `memaddr`.

The [`toFixedLengthBuffer()`]
method, when invoked, performs the following steps:

1. Let `buffer` be **this**.\[\[BufferObject\]\].

2. If
 [IsFixedLengthArrayBuffer](https://tc39.es/proposal-resizablearraybuffer/#sec-isfixedarraybuffer)(`buffer`) is true, return
 `buffer`.

3. Let `memaddr` be **this**.\[\[Memory\]\].

4. Let `fixedBuffer` be the result of [creating a fixed
 length memory
 buffer](#create-a-fixed-length-memory-buffer) from `memaddr`.

5. Perform
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [DetachArrayBuffer](https://tc39.es/ecma262/multipage/structured-data.html#sec-detacharraybuffer)(`buffer`,
 \"WebAssembly.Memory\").

6. Set **this**.\[\[BufferObject\]\] to `fixedBuffer`.

7. Return `fixedBuffer`.

The [`toResizableBuffer()`]
method, when invoked, performs the following steps:

1. Let `buffer` be **this**.\[\[BufferObject\]\].

2. If
 [IsFixedLengthArrayBuffer](https://tc39.es/proposal-resizablearraybuffer/#sec-isfixedarraybuffer)(`buffer`) is false, return
 `buffer`.

3. Let `memaddr` be **this**.\[\[Memory\]\].

4. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

5. Let `memtype` be
 [mem_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-mem-type)(`store`, `memaddr`).

6. If `memtype` has a max,

 1. Let `maxsize` be the max value in
 `memtype`.

7. Otherwise,

 1. Let `maxsize` be 65536 × 65536.

8. Let `resizableBuffer` be the result of [creating a
 resizable memory
 buffer](#create-a-resizable-memory-buffer) from `memaddr` and `maxsize`.

9. Perform
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [DetachArrayBuffer](https://tc39.es/ecma262/multipage/structured-data.html#sec-detacharraybuffer)(`buffer`,
 \"WebAssembly.Memory\").

10. Set **this**.\[\[BufferObject\]\] to `resizableBuffer`.

11. Return `resizableBuffer`.

[`ArrayBuffer`](https://tc39.github.io/ecma262/#sec-arraybuffer-objects) objects returned by a
[`Memory`](#memory) object must
have a size that is a multiple of a WebAssembly [page
size](https://webassembly.github.io/spec/core/exec/runtime.html#page-size) (the constant 65536). For this reason
[HostResizeArrayBuffer](https://tc39.es/proposal-resizablearraybuffer/#sec-hostresizearraybuffer) is redefined as follows.

The [abstract operation
[HostResizeArrayBuffer](https://tc39.es/proposal-resizablearraybuffer/#sec-hostresizearraybuffer)] takes arguments `buffer` (an
[`ArrayBuffer`](https://tc39.github.io/ecma262/#sec-arraybuffer-objects)) and `newLength`. It performs the following
steps when called.

1. If `buffer`.\[\[ArrayBufferDetachKey\]\] is
 \"WebAssembly.Memory\",

 1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Memory object
 cache](#memory-object-cache).

 2. Assert: `buffer` is the \[\[BufferObject\]\] of
 exactly one value in `map`.

 3. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `memaddr` → `mem` in
 `map`,

 1. If
 [SameValue](https://tc39.github.io/ecma262/#sec-samevalue)(`mem`.\[\[BufferObject\]\],
 `buffer`) is true,

 1. Assert:
 `buffer`.\[\[ArrayBufferByteLength\]\] modulo
 65536 is 0.

 2. Let `lengthDelta` be `newLength` -
 `buffer`.\[\[ArrayBufferByteLength\]\].

 3. If `lengthDelta` \< 0 or
 `lengthDelta` modulo 65536 is not 0,

 1. Throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

 4. Let `delta` be `lengthDelta` ÷
 65536.

 5. [Grow the memory
 buffer](#grow-the-memory-buffer) associated with `memaddr` by
 `delta`.

 4. Return handled.

2. Otherwise, return unhandled.

The getter of the [`buffer`] attribute of
[`Memory`](#memory) returns
**this**.\[\[BufferObject\]\].

### 5.4. Tables

```
enum TableKind {
 "externref",
 "anyfunc",
 // Note: More values may be added in future iterations,
 // e.g., typed function references, typed GC references
};

dictionary TableDescriptor {
 required TableKind element;
 required [EnforceRange] unsigned long initial;
 [EnforceRange] unsigned long maximum;
};

[LegacyNamespace=WebAssembly, Exposed=*]
interface Table {
 constructor(TableDescriptor descriptor, optional any value);
 unsigned long grow([EnforceRange] unsigned long delta, optional any value);
 any get([EnforceRange] unsigned long index);
 undefined set([EnforceRange] unsigned long index, optional any value);
 readonly attribute unsigned long length;
};
```

A [`Table`](#table) object
represents a single [table
instance](https://webassembly.github.io/spec/core/exec/runtime.html#table-instances) which can be simultaneously referenced by multiple
[`Instance`](#instance)
objects. Each [`Table`](#table)
object has a \[\[Table\]\] internal slot, which is a [table
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tableaddr).

To [initialize a table object] `table` from a
[table
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tableaddr) `tableaddr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Table object
 cache](#table-object-cache).

2. Assert: `map`\[`tableaddr`\] doesn't
 [exist](https://infra.spec.whatwg.org/#map-exists).

3. Set `table`.\[\[Table\]\] to `tableaddr`.

4. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`tableaddr`\] to
 `table`.

To [create a table object] from a [table
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tableaddr) `tableaddr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Table object
 cache](#table-object-cache).

2. If `map`\[`tableaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`tableaddr`\].

3. Let `table` be a
 [new](https://webidl.spec.whatwg.org/#new) [`Table`](#table).

4. [Initialize](#initialize-a-table-object) `table` from `tableaddr`.

5. Return `table`.

[`Table(``descriptor``, ``value``)`]
constructor, when invoked, performs the following steps:

1. Let `elementType` be
 [ToValueType](#tovaluetype)(`descriptor`\[\"element\"\]).

2. If `elementType` is not a
 [reftype](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

3. Let `initial` be `descriptor`\[\"initial\"\].

4. If `descriptor`\[\"maximum\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists), let `maximum` be
 `descriptor`\[\"maximum\"\]; otherwise, let
 `maximum` be empty.

5. If `maximum` is not empty and `maximum` \<
 `initial`, throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

6. If `value` is missing,

 1. Let `ref` be
 [DefaultValue](#defaultvalue)(`elementType`).

 2. Assert: `ref` is not
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error).

7. Otherwise,

 1. Let `ref` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToWebAssemblyValue](#towebassemblyvalue)(`value`, `elementType`).

8. Let `type` be the [table
 type](https://webassembly.github.io/spec/core/syntax/types.html#syntax-tabletype)
 {[min](https://webassembly.github.io/spec/core/syntax/types.html#syntax-tabletype) `initial`,
 [max](https://webassembly.github.io/spec/core/syntax/types.html#syntax-tabletype) `maximum`} `elementType`.

9. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

10. Let (`store`, `tableaddr`) be
 [table_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-alloc)(`store`, `type`,
 `ref`).

11. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

12. [Initialize](#initialize-a-table-object) **this** from `tableaddr`.

The [`grow(``delta``, ``value``)`] method, when invoked, performs the
following steps:

1. Let `tableaddr` be **this**.\[\[Table\]\].

2. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

3. Let `initialSize` be
 [table_size](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-size)(`store`, `tableaddr`).

4. Let (`limits`, `elementType`) be
 [table_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-type)(`tableaddr`).

5. If `value` is missing,

 1. Let `ref` be
 [DefaultValue](#defaultvalue)(`elementType`).

 2. If `ref` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

6. Otherwise,

 1. Let `ref` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToWebAssemblyValue](#towebassemblyvalue)(`value`, `elementType`).

7. Let `result` be
 [table_grow](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-grow)(`store`, `tableaddr`,
 `delta`, `ref`).

8. If `result` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

 The above exception can happen due to either
 insufficient memory or an invalid size parameter.

9. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `result`.

10. Return `initialSize`.

The getter of the [`length`] attribute of
[`Table`](#table), when invoked,
performs the following steps:

1. Let `tableaddr` be **this**.\[\[Table\]\].

2. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

3. Return
 [table_size](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-size)(`store`, `tableaddr`).

The [`get(``index``)`] method, when
invoked, performs the following steps:

1. Let `tableaddr` be **this**.\[\[Table\]\].

2. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

3. Let (`limits`, `elementType`) be
 [table_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-type)(`store`, `tableaddr`).

4. If `elementType` is
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

5. Let `result` be
 [table_read](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-read)(`store`, `tableaddr`,
 `index`).

6. If `result` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

7. Return [ToJSValue](#tojsvalue)(`result`).

The [`set(``index``, ``value``)`] method, when invoked, performs the
following steps:

1. Let `tableaddr` be **this**.\[\[Table\]\].

2. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

3. Let (`limits`, `elementType`) be
 [table_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-type)(`store`, `tableaddr`).

4. If `elementType` is
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

5. If `value` is missing,

 1. Let `ref` be
 [DefaultValue](#defaultvalue)(`elementType`).

 2. If `ref` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

6. Otherwise,

 1. Let `ref` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToWebAssemblyValue](#towebassemblyvalue)(`value`, `elementType`).

7. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

8. Let `store` be
 [table_write](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-table-write)(`store`, `tableaddr`,
 `index`, `ref`).

9. If `store` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

10. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

### 5.5. Globals

```
enum ValueType {
 "i32",
 "i64",
 "f32",
 "f64",
 "v128",
 "externref",
 "anyfunc",
};
```

 this type may be extended with additional cases in
future versions of WebAssembly.

```
dictionary GlobalDescriptor {
 required ValueType value;
 boolean mutable = false;
};

[LegacyNamespace=WebAssembly, Exposed=*]
interface Global {
 constructor(GlobalDescriptor descriptor, optional any v);
 any valueOf();
 attribute any value;
};
```

A [`Global`](#global) object
represents a single [global
instance](https://webassembly.github.io/spec/core/exec/runtime.html#global-instances) which can be simultaneously referenced by multiple
[`Instance`](#instance)
objects. Each [`Global`](#global) object has one internal slot:

- \[\[Global\]\] : a [global
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-globaladdr)

To [initialize a global object] `global` from a
[global
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-globaladdr) `globaladdr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Global object
 cache](#global-object-cache).

2. Assert: `map`\[`globaladdr`\] doesn't
 [exist](https://infra.spec.whatwg.org/#map-exists).

3. Set `global`.\[\[Global\]\] to `globaladdr`.

4. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`globaladdr`\] to
 `global`.

To [create a global object] from a [global
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-globaladdr) `globaladdr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Global object
 cache](#global-object-cache).

2. If `map`\[`globaladdr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`globaladdr`\].

3. Let `global` be a
 [new](https://webidl.spec.whatwg.org/#new) [`Global`](#global).

4. [Initialize](#initialize-a-global-object) `global` from `globaladdr`.

5. Return `global`.

The algorithm [ToValueType](`s`) performs the following
steps:

1. If `s` equals \"i32\", return
 [i32](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype).

2. If `s` equals \"i64\", return
 [i64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype).

3. If `s` equals \"f32\", return
 [f32](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype).

4. If `s` equals \"f64\", return
 [f64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype).

5. If `s` equals \"v128\", return
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types).

6. If `s` equals \"anyfunc\", return
 [funcref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype).

7. If `s` equals \"externref\", return
 [externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype).

8. Assert: This step is not reached.

The algorithm [DefaultValue](`valuetype`) performs the
following steps:

1. If `valuetype` equals
 [externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype), return
 [ToWebAssemblyValue](#towebassemblyvalue)(undefined, `valuetype`).

2. Return
 [val_default](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-val-default)(`valuetype`).

[`Global(``descriptor``, ``v``)`]
constructor, when invoked, performs the following steps:

1. Let `mutable` be `descriptor`\[\"mutable\"\].

2. Let `valuetype` be
 [ToValueType](#tovaluetype)(`descriptor`\[\"value\"\]).

3. If `valuetype` is
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types) or
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

4. If `v` is missing,

 1. Let `value` be
 [DefaultValue](#defaultvalue)(`valuetype`).

 2. Assert: `value` is not
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error).

5. Otherwise,

 1. Let `value` be
 [ToWebAssemblyValue](#towebassemblyvalue)(`v`, `valuetype`).

6. If `mutable` is true, let `globaltype` be
 [var](https://webassembly.github.io/spec/core/syntax/types.html#syntax-mut) `valuetype`;
 otherwise, let `globaltype` be
 [const](https://webassembly.github.io/spec/core/syntax/types.html#syntax-mut) `valuetype`.

7. Let `store` be the current agent's [associated
 store](#associated-store).

8. Let (`store`, `globaladdr`) be
 [global_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-global-alloc)(`store`, `globaltype`,
 `value`).

9. Set the current agent's [associated
 store](#associated-store) to `store`.

10. [Initialize](#initialize-a-global-object) **this** from `globaladdr`.

The algorithm [GetGlobalValue]([`Global`](#global) `global`) performs the following steps:

1. Let `store` be the current agent's [associated
 store](#associated-store).

2. Let `globaladdr` be `global`.\[\[Global\]\].

3. Let `globaltype` be
 [global_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-global-type)(`store`, `globaladdr`).

4. If `globaltype` is of the form `mut`
 `valuetype` where `valuetype` is
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types) or
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

5. Let `value` be
 [global_read](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-global-read)(`store`, `globaladdr`).

6. Return [ToJSValue](#tojsvalue)(`value`).

The getter of the [`value`] attribute of
[`Global`](#global), when
invoked, performs the following steps:

1. Return [GetGlobalValue](#getglobalvalue)(**this**).

The setter of the value attribute of
[`Global`](#global), when
invoked, performs the following steps:

1. Let `store` be the current agent's [associated
 store](#associated-store).

2. Let `globaladdr` be **this**.\[\[Global\]\].

3. Let `mut` `valuetype` be
 [global_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-global-type)(`store`, `globaladdr`).

4. If `valuetype` is
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types) or
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

5. If `mut` is
 [const](https://webassembly.github.io/spec/core/syntax/types.html#syntax-mut), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

6. Let `value` be
 [ToWebAssemblyValue](#towebassemblyvalue)(**the given value**, `valuetype`).

7. Let `store` be
 [global_write](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-global-write)(`store`, `globaladdr`,
 `value`).

8. If `store` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror) exception.

9. Set the current agent's [associated
 store](#associated-store) to `store`.

The [`valueOf()`] method, when invoked,
performs the following steps:

1. Return [GetGlobalValue](#getglobalvalue)(**this**).

### 5.6. Exported Functions

A WebAssembly function is made available in JavaScript as an [Exported
Function]. Exported Functions are [Built-in Function
Objects](https://tc39.github.io/ecma262/#sec-built-in-function-objects) which are not constructors, and which have a
\[\[FunctionAddress\]\] internal slot. This slot holds a [function
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-funcaddr) relative to the [surrounding
agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
store](#associated-store).

The [name of the WebAssembly function] `funcaddr` is
found by performing the following steps:

1. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

2. Let `funcinst` be
 `store`.funcs\[`funcaddr`\].

3. If `funcinst` is of the form {type `functype`,
 hostcode `hostfunc`},

 1. Assert: `hostfunc` is a JavaScript object and
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`hostfunc`) is true.

 2. Let `index` be the [index of the host
 function](#index-of-the-host-function) `funcaddr`.

4. Otherwise,

 1. Let `moduleinst` be `funcinst`.module.

 2. Assert: `funcaddr` is contained in
 `moduleinst`.funcaddrs.

 3. Let `index` be the index of
 `moduleinst`.funcaddrs where `funcaddr` is
 found.

5. Return
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring)(`index`).

To create [a new Exported Function] from a WebAssembly [function
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-funcaddr) `funcaddr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Exported Function
 cache](#exported-function-cache).

2. If `map`\[`funcaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`funcaddr`\].

3. Let `steps` be \"[call the Exported
 Function](#call-an-exported-function) `funcaddr` with arguments.\".

4. Let `realm` be the [current
 Realm](https://tc39.github.io/ecma262/#current-realm).

5. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

6. Let `functype` be
 [func_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-type)(`store`, `funcaddr`).

7. Let \[`paramTypes`\] → \[`resultTypes`\] be
 `functype`.

8. Let `arity` be `paramTypes`'s
 [size](https://infra.spec.whatwg.org/#list-size).

9. Let `name` be the [name of the WebAssembly
 function](#name-of-the-webassembly-function) `funcaddr`.

10. Let `function` be
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, `arity`,
 `name`, « \[\[FunctionAddress\]\] », `realm`).

11. Set `function`.\[\[FunctionAddress\]\] to
 `funcaddr`.

12. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`funcaddr`\] to
 `function`.

13. Return `function`.

To [coerce JavaScript arguments] from a `functype`
and a [list](https://infra.spec.whatwg.org/#list) of JavaScript arguments `argValues`, perform
the following steps

1. Let \[`parameters`\] → \[`results`\] be
 `functype`.

2. If `parameters` or `results` contain
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types) or
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror). Note: the above error is thrown each time the
 \[\[Call\]\] method is invoked.

3. Let `args` be « ».

4. Let `i` be 0.

5. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `t` of `parameters`,

 1. If `argValues`'s
 [size](https://infra.spec.whatwg.org/#list-size) \> `i`, let `arg` be
 `argValues`\[`i`\].

 2. Otherwise, let `arg` be undefined.

 3. [Append](https://infra.spec.whatwg.org/#list-append)
 [ToWebAssemblyValue](#towebassemblyvalue)(`arg`, `t`) to
 `args`.

 4. Set `i` to `i` + 1.

6. return `args`.

To [call an Exported Function] with [function
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-funcaddr) `funcaddr` and a
[list](https://infra.spec.whatwg.org/#list) of JavaScript arguments `argValues`, perform
the following steps:

1. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

2. Let `functype` be
 [func_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-type)(`store`, `funcaddr`).

3. Let `args` be the result of [coercing
 arguments](#coerce-javascript-arguments) (`functype`,`argValues`).

4. Let (`store`, `ret`) be the result of
 [func_invoke](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-invoke)(`store`, `funcaddr`,
 `args`).

5. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

6. If `ret` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw an exception. This exception must be a
 WebAssembly
 [`RuntimeError`](#exceptiondef-runtimeerror) exception, unless otherwise indicated by [the
 WebAssembly error mapping](#errors).

7. If `ret` is
 [THROW](https://webidl.spec.whatwg.org/#dfn-throw)
 [ref.exn](https://webassembly.github.io/spec/core/exec/runtime.html#values) `exnaddr`, then:

 1. Let `tagaddr` be
 [exn_tag](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-tag)(`store`, `exnaddr`).

 2. Let `payload` be
 [exn_read](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-read)(`store`, `exnaddr`).

 3. Let `jsTagAddr` be the result of [getting the
 JavaScript exception
 tag](#get-the-javascript-exception-tag).

 4. If `tagaddr` is equal to `jsTagAddr`,

 1. Throw the result of [retrieving a host
 value](#retrieving-a-host-value) from `payload`\[0\].

 5. Otherwise,

 1. Let `exception` be [a new
 Exception](#create-an-exception-object) created from `exnaddr`.

 2. Throw `exception`.

8. Let `outArity` be the
 [size](https://infra.spec.whatwg.org/#list-size) of `ret`.

9. If `outArity` is 0, return undefined.

10. Otherwise, if `outArity` is 1, return
 [ToJSValue](#tojsvalue)(`ret`\[0\]).

11. Otherwise,

 1. Let `values` be « ».

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `r` of `ret`,

 1. [Append](https://infra.spec.whatwg.org/#list-append) [ToJSValue](#tojsvalue)(`r`) to `values`.

 3. Return
 [CreateArrayFromList](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createarrayfromlist)(`values`).

 [Calling an Exported
Function](#call-an-exported-function) executes in the \[\[Realm\]\] of the callee Exported
Function, as per the definition of [built-in function
objects](https://tc39.github.io/ecma262/#sec-built-in-function-objects).

 Exported Functions do not have a \[\[Construct\]\]
method and thus it is not possible to call one with the `new` operator.

To [coerce WebAssembly arguments] from a
[list](https://infra.spec.whatwg.org/#list) of `parameterTypes` and a
[list](https://infra.spec.whatwg.org/#list) of JavaScript arguments `arguments`, perform
the following steps

1. If `parameterTypes` contain
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types), throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

2. Let `jsArguments` be « ».

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `arg` of `arguments`,

 1. [Append](https://infra.spec.whatwg.org/#list-append)
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToJSValue](#tojsvalue)(`arg`) to `jsArguments`.

4. Return `jsArguments`.

To [coerce a JavaScript return] from a JavaScript
`ret` and a list of `results` types, perform the
following steps:

1. Let `resultsSize` be `results`'s
 [size](https://infra.spec.whatwg.org/#list-size).

2. If `resultsSize` is 0, return « ».

3. Otherwise, if `resultsSize` is 1, return «
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToWebAssemblyValue](#towebassemblyvalue)(`ret`, `results`\[0\]) ».

4. Otherwise,

 1. Let `method` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [GetMethod](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-getmethod)(`ret`,
 [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols)).

 2. If `method` is undefined,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

 3. Let `values` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [IteratorToList](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iteratortolist)([?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [GetIteratorFromMethod](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-getiteratorfrommethod)(`ret`,
 `method`)).

 4. Let `wasmValues` be a new, empty
 [list](https://infra.spec.whatwg.org/#list).

 5. If `values`'s
 [size](https://infra.spec.whatwg.org/#list-size) is not `resultsSize`, throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) exception.

 6. For each `value` and `resultType` in
 `values` and `results`, paired linearly,

 1. [Append](https://infra.spec.whatwg.org/#list-append)
 [ToWebAssemblyValue](#towebassemblyvalue)(`value`,
 `resultType`) to `wasmValues`.

 7. Return `wasmValues`.

To [coerce a JavaScript exception] from a JavaScript exception
`v`, perform the following steps:

1. If `v`
 [implements](https://webidl.spec.whatwg.org/#implements) [`Exception`](#exception),

 1. Let `type` be `v`.\[\[Type\]\].

 2. Let `payload` be `v`.\[\[Payload\]\].

2. Otherwise,

 1. Let `type` be the [JavaScript exception
 tag](#javascript-exception-tag).

 2. Let `payload` be « ».

3. Let `opaqueData` be
 [ToWebAssemblyValue](#towebassemblyvalue)(`v`,
 [externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype)).

4. Return the triple `type`, `payload` and
 `opaqueData`.

To [create a host function] from the JavaScript object `func`
and type `functype`, perform the following steps:

1. Assert:
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`func`).

2. Let `stored settings` be the [incumbent settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#incumbent-settings-object).

3. Let `hostfunc` be a [host
 function](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-hostfunc) which performs the following steps when called with
 arguments `arguments`:

 1. Let `realm` be `func`'s [associated
 Realm](https://webidl.spec.whatwg.org/#dfn-associated-realm).

 2. Let `relevant settings` be `realm`'s
 [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-settings-object).

 3. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `relevant settings`.

 4. [Prepare to run a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback) with `stored settings`.

 5. Let \[`parameters`\] → \[`resultTypes`\]
 be `functype`.

 6. Let `jsArguments` be the result of [coerce
 WebAssembly
 arguments](#coerce-webassembly-arguments)(`parameters`,`arguments`).

 7. Let `result` be the result of
 Completion([Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`func`, undefined,
 `jsArguments`)).

 8. [Clean up after running a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback) with `stored settings`.

 9. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `relevant settings`.

 10. Assert: `result`.\[\[Type\]\] is throw or normal.

 11. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

 12. If `result`.\[\[Type\]\] is normal, then:

 1. Return the result of performing [coerce a JavaScript
 return](#coerce-a-javascript-return) on `resultTypes` and
 `ret`.

 13. If `result`.\[\[Type\]\] is throw, then:

 1. Perform [throw the JavaScript
 exception](#throw-a-javascript-exception) on `result`.\[\[Value\]\].

4. Let (`store`, `funcaddr`) be
 [func_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-alloc)(`store`, `functype`,
 `hostfunc`).

5. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

6. Return `funcaddr`.

To [throw a JavaScript exception] from the JavaScript object
`v`, perform the following steps:

1. If `v`
 [implements](https://webidl.spec.whatwg.org/#implements) [`Exception`](#exception),

 1. Let `address` be `v`.\[\[Address\]\].

2. Otherwise,

 1. Let `type` be the result of [getting the JavaScript
 exception
 tag](#get-the-javascript-exception-tag).

 2. Let `payload` be
 [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToWebAssemblyValue](#towebassemblyvalue)(`v`,
 [externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype)).

 3. Let (`store`, `address`) be
 [exn_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-alloc)(`store`, `type`, «
 `payload` »).

 4. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

3. Execute the WebAssembly instructions
 ([ref.exn](https://webassembly.github.io/spec/core/exec/runtime.html#values) `address`)
 ([throw_ref](https://webassembly.github.io/spec/core/exec/instructions.html#exec-throw-ref)).

The algorithm [ToJSValue](`w`) coerces a [WebAssembly
value](https://webassembly.github.io/spec/core/exec/runtime.html#values) to a JavaScript value by
performing the following steps:

1. Assert: `w` is not of the form
 [v128.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `v128`.

2. Assert: `w` is not of the form
 [ref.exn](https://webassembly.github.io/spec/core/exec/runtime.html#values) `exnaddr`.

3. If `w` is of the form
 [i64.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `u64`,

 1. Let `i64` be
 [signed_64](https://webassembly.github.io/spec/core/exec/numerics.html#aux-signed)(`u64`).

 2. Return [ℤ](https://tc39.github.io/ecma262/#ℤ)(`i64` interpreted as a mathematical
 value).

4. If `w` is of the form
 [i32.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `i32`,

 1. Let `i32` be
 [signed_32](https://webassembly.github.io/spec/core/exec/numerics.html#aux-signed)(`i32`).

 2. Return [𝔽](https://tc39.github.io/ecma262/#𝔽)(`i32` interpreted as a mathematical
 value).

5. If `w` is of the form
 [f32.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `f32`,

 1. If `f32` is
 [+∞](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float) or
 [−∞](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float), return **+∞**~𝔽~ or
 **-∞**~𝔽~, respectively.

 2. If `f32` is
 [nan](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float), return **NaN**.

 3. Return [𝔽](https://tc39.github.io/ecma262/#𝔽)(`f32` interpreted as a mathematical
 value).

6. If `w` is of the form
 [f64.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `f64`,

 1. If `f64` is
 [+∞](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float) or
 [−∞](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float), return **+∞**~𝔽~ or
 **-∞**~𝔽~, respectively.

 2. If `f64` is
 [nan](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float), return **NaN**.

 3. Return [𝔽](https://tc39.github.io/ecma262/#𝔽)(`f64` interpreted as a mathematical
 value).

7. If `w` is of the form
 [ref.null](https://webassembly.github.io/spec/core/exec/runtime.html#values) `t`, return null.

8. If `w` is of the form
 [ref.i31](https://webassembly.github.io/spec/core/exec/runtime.html#values) `u31`,

 1. Let `i31` be
 [signed_31](https://webassembly.github.io/spec/core/exec/numerics.html#aux-signed)(`u31`).

 2. Let return [𝔽](https://tc39.github.io/ecma262/#𝔽)(`i31`).

9. If `w` is of the form
 [ref.struct](https://webassembly.github.io/spec/core/exec/runtime.html#values) `structaddr`,
 return the result of creating [a new Exported GC
 Object](#a-new-exported-gc-object) from `structaddr` and \"struct\".

10. If `w` is of the form
 [ref.array](https://webassembly.github.io/spec/core/exec/runtime.html#values) `arrayaddr`,
 return the result of creating [a new Exported GC
 Object](#a-new-exported-gc-object) from `arrayaddr` and \"array\".

11. If `w` is of the form
 [ref.func](https://webassembly.github.io/spec/core/exec/runtime.html#values) `funcaddr`,
 return the result of creating [a new Exported
 Function](#a-new-exported-function) from `funcaddr`.

12. If `w` is of the form
 [ref.host](https://webassembly.github.io/spec/core/exec/runtime.html#values) `hostaddr`,
 return the result of [retrieving a host
 value](#retrieving-a-host-value) from `hostaddr`.

13. If `w` is of the form
 [ref.extern](https://webassembly.github.io/spec/core/exec/runtime.html#values) `ref`, return
 [ToJSValue](#tojsvalue)(`ref`).

 Number values which are equal to NaN may have various
observable NaN payloads; see
[NumericToRawBytes](https://tc39.es/ecma262/multipage/structured-data.html#sec-numerictorawbytes) for details.

For [retrieving a host value] from an [host
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-hostaddr) `hostaddr`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [host value
 cache](#host-value-cache).

2. Assert: `map`\[`hostaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists).

3. Return `map`\[`hostaddr`\].

The algorithm [ToWebAssemblyValue](`v`, `type`) coerces a
JavaScript value to a [WebAssembly
value](https://webassembly.github.io/spec/core/exec/runtime.html#values) by performing the following
steps:

1. Assert: `type` is not
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types).

2. Assert: `type` is not
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype).

3. If `type` is
 [i64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype),

 1. Let `i64` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToBigInt64](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tobigint64)(`v`).

 2. Let `u64` be the unsigned integer such that
 `i64` is
 [signed_64](https://webassembly.github.io/spec/core/exec/numerics.html#aux-signed)(`u64`).

 3. Return
 [i64.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `u64`.

4. If `type` is
 [i32](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype),

 1. Let `i32` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToInt32](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toint32)(`v`).

 2. Let `u32` be the unsigned integer such that
 `i32` is
 [signed_32](https://webassembly.github.io/spec/core/exec/numerics.html#aux-signed)(`u32`).

 3. Return
 [i32.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `u32`.

5. If `type` is
 [f32](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype),

 1. Let `number` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToNumber](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tonumber)(`v`).

 2. If `number` is **NaN**,

 1. Let `n` be an implementation-defined integer such
 that
 [canon](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float)~32~ ≤ `n`
 \<
 2^[signif](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float)(32)^.

 2. Let `f32` be
 [nan](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float)(n).

 3. Otherwise, \\1.

 4. Return
 [f32.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `f32`.

6. If `type` is
 [f64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype),

 1. Let `number` be
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToNumber](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tonumber)(`v`).

 2. If `number` is **NaN**,

 1. Let `n` be an implementation-defined integer such
 that
 [canon](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float)~64~ ≤ `n`
 \<
 2^[signif](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float)(64)^.

 2. Let `f64` be
 [nan](https://webassembly.github.io/spec/core/syntax/values.html#syntax-float)(n).

 3. Otherwise,

 1. Let `f64` be `number`.

 4. Return
 [f64.const](https://webassembly.github.io/spec/core/exec/runtime.html#values) `f64`.

7. If `type` is of the form
 [ref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype) `null`
 `heaptype`,

 1. If `v` is null,

 1. Let `r` be
 [ref.null](https://webassembly.github.io/spec/core/exec/runtime.html#values)
 `heaptype`.

 2. Else if
 [match_valtype](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-match-valtype)(`type`,
 [ref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype) `null`
 [extern](https://webassembly.github.io/spec/core/syntax/types.html#heap-types)),

 1. Let `ref` be
 [ToWebAssemblyValue](#towebassemblyvalue)(`v`,
 [ref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype)
 [any](https://webassembly.github.io/spec/core/syntax/types.html#heap-types)).

 2. Let `r` be
 [ref.extern](https://webassembly.github.io/spec/core/exec/runtime.html#values) `ref`.

 3. Else if `v` is an [Exported
 Function](#exported-function) and
 [match_valtype](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-match-valtype)(`type`,
 [ref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype) `null`
 [func](https://webassembly.github.io/spec/core/syntax/types.html#heap-types)),

 1. Let `funcaddr` be the value of `v`'s
 \[\[FunctionAddress\]\] internal slot.

 2. Let `r` be
 [ref.func](https://webassembly.github.io/spec/core/exec/runtime.html#values)
 `funcaddr`.

 4. Else if `v` [is a
 Number](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-number-type) and `v` is equal to
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToInt32](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toint32)(`v`) and
 [ℝ](https://tc39.github.io/ecma262/#ℝ)(`v`) \< 2^30^ and
 [ℝ](https://tc39.github.io/ecma262/#ℝ)(`v`) ⩾ -2^30^,

 1. Let `i31`
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToInt32](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toint32)(`v`).

 2. Let `u31` be the unsigned integer such that
 `i31` is
 [signed_31](https://webassembly.github.io/spec/core/exec/numerics.html#aux-signed)(`i31`).

 3. Let `r` be
 [ref.i31](https://webassembly.github.io/spec/core/exec/runtime.html#values) `u31`.

 5. Else if `v` is an [Exported GC
 Object](#exported-gc-object),

 1. Let `objectaddr` be the value of `v`'s
 \[\[ObjectAddress\]\] internal slot.

 2. Let `objectkind` be the value of `v`'s
 \[\[ObjectKind\]\] internal slot.

 3. If `objectkind` is \"array\",

 1. Let `r` be
 [ref.array](https://webassembly.github.io/spec/core/exec/runtime.html#values)
 `objectaddr`.

 4. If `objectkind` is \"struct\",

 1. Let `r` be
 [ref.struct](https://webassembly.github.io/spec/core/exec/runtime.html#values)
 `objectaddr`.

 6. Else,

 1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [host value
 cache](#host-value-cache).

 2. If a [host
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-hostaddr) `hostaddr` exists such that
 `map`\[`hostaddr`\] is the same as
 `v`,

 1. Return
 [ref.host](https://webassembly.github.io/spec/core/exec/runtime.html#values)
 `hostaddr`.

 3. Let [host
 address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-hostaddr) `hostaddr` be the smallest
 address such that `map`\[`hostaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists) is false.

 4. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`hostaddr`\]
 to `v`.

 5. Let `r` be
 [ref.host](https://webassembly.github.io/spec/core/exec/runtime.html#values)
 `hostaddr`.

 7. Let `store` be the current agent's [associated
 store](#associated-store).

 8. Let `actualtype` be
 [ref_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-ref-type)(`store`, `r`).

 9. If
 [match_valtype](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-match-valtype)(`actualtype`, `type`) is
 false,

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

 10. Return `r`.

8. Assert: This step is not reached.

### 5.7. JavaScript Promise Integration

 The JavaScript Promise Integration API (JSPI) allows
WebAssembly functions to suspend and resume their execution \-- based on
the behavior of JavaScript functions that return Promise objects.

A [`Suspending`](#suspending)
marker object represents a JavaScript function whose calls via
WebAssembly imports should be *suspended* when they return a Promise
object. Each [`Suspending`](#suspending) marker object has a \[\[WrappedFunction\]\] internal
slot which holds a JavaScript function.

In addition, the
[`promising`](#dom-webassembly-promising) function takes as argument a WebAssembly function and
returns a JavaScript function that returns a Promise that is resolved
when the WebAssembly function completes.

Each
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent) maintains a [Execution Context Status
map](#execution-context-status-map), mapping from [execution
contexts](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-execution-contexts) to a status symbol. The purpose of this map is to
ensure that applications do not try to suspend JavaScript frames and
also to ensure that calls to imports marked with a
[`Suspending`](#suspending)
marker object are properly balanced by corresponding uses of
[`WebAssembly.promising`].

If present, a status can be one of two [stack status] values:

- [active]. This
 signals that the associated execution context is actively executing
 and has the potential to be [paused](#paused).

- [paused]. This
 signals that the associated execution is not currently involved in
 computation and has been paused.

If an execution context is not present in the status mapping, then it
may not be [paused](#paused) or
[reentered].

When a new agent is created, its status mapping is set to the empty map.

```
[Exposed=*]
partial namespace WebAssembly {
 Function promising(Function wasmFunc);
};

[LegacyNamespace=WebAssembly, Exposed=*]
interface Suspending {
 constructor(Function jsFun);
};
```

The [`promising(``wasmFunc``)`] function, when invoked, performs the following steps:

1. If
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`wasmFunc`) is false, throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

2. If `wasmFunc` does not have a \[\[FunctionAddress\]\]
 internal slot, throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

3. Let `builder` be a new
 [AbstractClosure](https://tc39.github.io/ecma262/#sec-abstract-closure) with no parameters that captures
 `wasmFunc` and performs [run a Promising
 function](#run-a-promising-function) when called.

4. Returns the result of
 [CreateBuiltinFunction](https://tc39.github.io/ecma262/#sec-createbuiltinfunction)(`builder`,1,\"\", « »).

The algorithm to [run a Promising function] from the JavaScript object
`wasmFunc` and a
[list](https://infra.spec.whatwg.org/#list) of [WebAssembly
values](https://webassembly.github.io/spec/core/exec/runtime.html#values) `arguments` consists
of the following steps:

1. Let `promise` be a new
 [PromiseCapabilityRecord](https://tc39.github.io/ecma262/#sec-promisecapability-records).

2. Let `funcaddr` be the value of `wasmFunc`'s
 \[\[FunctionAddress\]\] internal slot.

3. Let `runner` be a new
 [AbstractClosure](https://tc39.github.io/ecma262/#sec-abstract-closure) with no parameters that captures
 `promise`, `funcaddr`, and
 `arguments` and performs the following steps when called:

 1. Perform [evaluate a Promising
 function](#evaluate-a-promising-function)(`promise`,`funcaddr`,`arguments`).

4. Perform
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)[AsyncFunctionStart](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-async-functions-abstract-operations-async-function-start)(`promise`,`runner`).

5. Return `promise`.

The algorithm to [evaluate a Promising
function](`promise`, `funcaddr`,
`arguments`) consists of the following steps:

1. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

2. Let `functype` be
 [func_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-type)(`store`, `funcaddr`).

3. Let `args` be the result of [coercing
 arguments](#coerce-javascript-arguments) (`functype`,`arguments`).

4. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Execution Context Status
 map](#execution-context-status-map).

5. Let `ec` be the currently executing [execution
 context](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-execution-contexts), i.e., the [execution
 context](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-execution-contexts) that is at the top of the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s current [execution context
 stack](https://tc39.github.io/ecma262/#execution-context-stack).

6. Assert: `map` does not contain any entry for
 `ec`.

7. Add an entry mapping `ec` to
 [active](#active) in
 `map`.

8. Let (`store`, `result`) be the result of
 [func_invoke](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-invoke)(`store`, `funcaddr`,
 `args`).

9. Assert: If control reaches here, we have done waiting for suspended
 imports.

10. If the entry for `ec` in `map` is not
 [active](#active) then throw a
 WebAssembly
 [`SuspendError`](#exceptiondef-suspenderror) exception. Otherwise, remove the entry for
 `ec` from
 [map](https://infra.spec.whatwg.org/#ordered-map).

11. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

12. If `result` is
 [error](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-error), throw a WebAssembly
 [`RuntimeError`](#exceptiondef-runtimeerror) exception, unless otherwise indicated by [the
 WebAssembly error mapping](#errors).

13. Otherwise, if `result` is of the form
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) exnaddr,

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with `result`.

14. Otherwise,

 1. Assert: `result` is a
 [list](https://infra.spec.whatwg.org/#list) of WebAssembly values.

 2. Let `outArity` be the
 [size](https://infra.spec.whatwg.org/#list-size) of `result`.

 3. If `outArity` is 0, return undefined.

 4. Otherwise, if `outArity` is 1, let
 `jsReturnValue` be
 [ToJSValue](#tojsvalue)(`result`\[0\]).

 5. Otherwise,

 1. Let `values` be « ».

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `r` of `result`,

 3. [Append](https://infra.spec.whatwg.org/#list-append) [ToJSValue](#tojsvalue)(`r`) to `values`.

 4. Let `jsReturnValue` be
 [CreateArrayFromList](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createarrayfromlist)(`values`).

 6. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `jsReturnValue`.

15. Return UNUSED.

The [`Suspending(``jsFun``)`] constructor, when
invoked, performs the following steps:

1. If
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`jsFun`) is false, throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

2. Let `suspendingProto` be
 \[\[%WebAssembly.Suspending.prototype%\]\].

3. Let `susp` be the result of
 [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(`suspendingProto`,«\[\[WrappedFunction\]\]»).

4. Set `susp`.\[\[WrappedFunction\]\] to `jsFun`.

5. Return `susp`.

To [create a suspending function] from a JavaScript function
`func`, with type `functype` perform the following
steps:

1. Assert:
 [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`func`).

2. Let `stored settings` be the [incumbent settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#incumbent-settings-object).

3. Let `hostfunc` be a [host
 function](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-hostfunc) which performs the following steps when called with
 arguments `arguments`:

 1. Let `realm` be `func`'s [associated
 Realm](https://webidl.spec.whatwg.org/#dfn-associated-realm).

 2. Let `relevant settings` be `realm`'s
 [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-settings-object).

 3. Let `async_context` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [running execution
 context](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#running-execution-context).

 4. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Execution Context Status
 map](#execution-context-status-map).

 5. If the entry for `async_context` in `map`
 is not [active](#active),
 then:

 1. Perform [throw a JavaScript
 exception](#throw-a-javascript-exception) with a
 [`SuspendError`](#exceptiondef-suspenderror) exception.

 6. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `relevant settings`.

 7. [Prepare to run a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback) with `stored settings`.

 8. Let \[`parameters`\] → \[`resultTypes`\]
 be `functype`.

 9. Let `jsArguments` be the result of [coerce
 WebAssembly
 arguments](#coerce-webassembly-arguments)(`parameters`,`arguments`).

 10. Let `ret` be
 [Completion]([Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`func`, undefined,
 `jsArguments`)).

 11. [Clean up after running a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback) with `stored settings`.

 12. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `relevant settings`.

 13. Assert: `ret`.\[\[Type\]\] is throw or normal.

 14. If `ret`.\[\[Type\]\] is throw, then:

 1. Let `type`, `payload` and
 `opaqueData` be the result of [coercing the
 JavaScript
 exception](#coerce-a-javascript-exception) `ret`.\[\[Value\]\].

 2. [Throw] with `type`,
 `payload` and `opaqueData`.

 15. Otherwise,

 1. Let `prRet` be the result of
 [PromiseResolve](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-resolve)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor),`ret`.\[\[Value\]\]).

 2. Assert: `prRet`.\[\[Type\]\] is throw or normal.

 3. If `prRet`.\[\[Type\]\] is throw, then:

 1. Let `type`, `payload` and
 `opaqueData` be the result of [coercing the
 JavaScript
 exception](#coerce-a-javascript-exception) `ret`.\[\[Value\]\].

 2. [Throw] with `type`,
 `payload` and `opaqueData`.

 4. Otherwise,

 1. Let `promise` be
 `prRet`.\[\[Value\]\].

 2. Set the entry for `async_context` in
 `map` to [paused](#paused).

 3. Let `awaitResult` be the result of performing
 [Completion]([Await](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#await)(`promise`)).

 4. This will suspend both this algorithm,
 and the WebAssembly function being invoked by the
 [evaluate a Promising
 function](#evaluate-a-promising-function) algorithm. On return, `ret`
 will be either a normal completion or a throw
 completion.

 5. If the entry for `async_context` in
 `map` is not
 [paused](#paused)
 then:

 1. Perform [throw a JavaScript
 exception](#throw-a-javascript-exception) with a
 [`SuspendError`](#exceptiondef-suspenderror).

 6. Otherwise, set the entry to
 [active](#active).

 7. If `awaitResult`.\[\[Type\]\] is throw, then:

 8. Let `type`, `payload` and
 `opaqueData` be the result of [coercing the
 JavaScript
 exception](#coerce-a-javascript-exception) `ret`.\[\[Value\]\].

 9. [Throw] with `type`,
 `payload` and `opaqueData`.

 10. Otherwise, return the result of performing [coerce a
 JavaScript
 return](#coerce-a-javascript-return) on `resultTypes` and
 `awaitResult`.

4. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

5. Let (`store`, `funcaddr`) be
 [func_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-func-alloc)(`store`, `functype`,
 `hostfunc`).

6. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

7. Return `funcaddr`.

### 5.8. Tags

The [tag_alloc](`store`, `parameters`) algorithm
creates a new [tag
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tagaddr) for `parameters` in `store` and
returns the updated store and the [tag
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tagaddr).

#### 5.8.1. Tag types

```
dictionary TagType {
 required sequence<ValueType> parameters;
};

[LegacyNamespace=WebAssembly, Exposed=(Window,Worker,Worklet)]
interface Tag {
 constructor(TagType type);
};
```

A [`Tag`](#tag) value represents an
exception tag.

To [initialize a Tag object] `tag` from a [tag
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tagaddr) `tagAddress`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Tag object
 cache](#tag-object-cache).

2. Assert: `map`\[`tagAddress`\] doesn't
 [exist](https://infra.spec.whatwg.org/#map-exists).

3. Set `tag`.\[\[Address\]\] to `tagAddress`.

4. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`tagAddress`\] to
 `tag`.

To [create a Tag object] from a [tag
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tagaddr) `tagAddress`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Tag object
 cache](#tag-object-cache).

2. If `map`\[`tagAddress`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`tagAddress`\].

3. Let `tag` be a
 [new](https://webidl.spec.whatwg.org/#new) [`Tag`](#tag).

4. [Initialize](#initialize-a-tag-object) `tag` from `tagAddress`.

5. Return `tag`.

The [`new Tag(``type``)`] constructor steps are:

1. Let `parameters` be `type`\[\"parameters\"\].

2. Let `wasmParameters` be «».

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `type` of `parameters`,

 1. [Append](https://infra.spec.whatwg.org/#list-append)
 [ToValueType](#tovaluetype)(`type`) to
 `wasmParameters`.

4. Let `store` be the current agent's [associated
 store](#associated-store).

5. Let (`store`, `tagAddress`) be
 [tag_alloc](#tag_alloc)(`store`, `wasmParameters`).

6. Set the current agent's [associated
 store](#associated-store) to `store`.

7. [Initialize](#initialize-a-tag-object) **this** from `tagAddress`.

### 5.9. Garbage Collected Objects

A WebAssembly struct or array is made available in JavaScript as an
[Exported GC Object]. An [Exported GC
Object](#exported-gc-object) is an exotic object that wraps a garbage collected
WebAssembly reference value. Most JavaScript operations on an [Exported
GC Object](#exported-gc-object) will throw an exception or return undefined.

 These operations may be refined in the future to allow
richer interactions in JavaScript with WebAssembly structs and arrays.

An [Exported GC
Object](#exported-gc-object) contains an \[\[ObjectAddress\]\] internal slot, which
holds a [object address] relative to the [surrounding
agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
store](#associated-store),
and an \[\[ObjectKind\]\] internal slot, which holds the string value
\"struct\" or \"array\".

The internal methods of an [Exported GC
Object](#exported-gc-object) use the following implementations.

The [\[\[GetPrototypeOf\]\] internal method of an Exported GC
Object] `O` takes no
arguments and returns null. It performs the following steps when called:

1. Return null.

The [\[\[SetPrototypeOf\]\] internal method of an Exported GC
Object] `O` takes argument
`V` (an Object or null) and returns a boolean. It performs
the following steps when called:

1. Return false.

The [\[\[IsExtensible\]\] internal method of an Exported GC
Object] `O` takes no
arguments and returns a boolean. It performs the following steps when
called:

1. Return false.

The [\[\[PreventExtensions\]\] internal method of an Exported GC
Object] `O` takes no
arguments and returns a boolean. It performs the following steps when
called:

1. Return false.

The [\[\[GetOwnProperty\]\] internal method of an Exported GC
Object] `O` takes argument
`P` (a property key) and returns undefined. It performs the
following steps when called:

1. Return undefined.

The [\[\[DefineOwnProperty\]\] internal method of an Exported GC
Object] `O` takes arguments
`P` (a property key) and `Desc` (a property
descriptor) and returns a boolean. It performs the following steps when
called:

1. Return false.

The [\[\[HasProperty\]\] internal method of an Exported GC
Object] `O` takes argument
`P` (a property key) and returns a boolean. It performs the
following steps when called:

1. Return false.

The [\[\[Get\]\] internal method of an Exported GC
Object] `O` takes arguments
`P` (a property key) and `Receiver` (an ECMAScript
language value) and returns undefined. It performs the following steps
when called:

1. Return undefined.

The [\[\[Set\]\] internal method of an Exported GC
Object] `O` takes arguments
`P` (a property key), `V` (an ECMAScript language
value), and `Receiver` (an ECMAScript language value) and
throws an exception. It performs the following steps when called:

1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

The [\[\[Delete\]\] internal method of an Exported GC
Object] `O` takes argument
`P` (a property key) and throws an exception. It performs the
following steps when called:

1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

The [\[\[OwnPropertyKeys\]\] internal method of an Exported GC
Object] `O` takes no
arguments and returns a list. It performs the following steps when
called:

1. Let keys be a new empty list.

2. Return keys.

To create [a new Exported GC Object] from a WebAssembly [object
address] `objectaddr` and a string
`objectkind`, perform the following steps:

1. Assert: `objectkind` is either \"array\" or \"struct\".

2. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [exported GC object
 cache](#exported-gc-object-cache).

3. If `map`\[`objectaddr`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`objectaddr`\].

4. Let `object` be
 [MakeBasicObject](https://tc39.github.io/ecma262/#sec-makebasicobject)(« \[\[ObjectAddress\]\] »).

5. Set `object`.\[\[ObjectAddress\]\] to
 `objectaddr`.

6. Set `object`.\[\[ObjectKind\]\] to
 `objectkind`.

7. Set `object`.\[\[GetPrototypeOf\]\] as specified in
 [\[\[GetPrototypeOf\]\] internal method of an Exported GC
 Object](#getprototypeof-internal-method-of-an-exported-gc-object).

8. Set `object`.\[\[SetPrototypeOf\]\] as specified in
 [\[\[SetPrototypeOf\]\] internal method of an Exported GC
 Object](#setprototypeof-internal-method-of-an-exported-gc-object).

9. Set `object`.\[\[IsExtensible\]\] as specified in
 [\[\[IsExtensible\]\] internal method of an Exported GC
 Object](#isextensible-internal-method-of-an-exported-gc-object).

10. Set `object`.\[\[PreventExtensions\]\] as specified in
 [\[\[PreventExtensions\]\] internal method of an Exported GC
 Object](#preventextensions-internal-method-of-an-exported-gc-object).

11. Set `object`.\[\[GetOwnProperty\]\] as specified in
 [\[\[GetOwnProperty\]\] internal method of an Exported GC
 Object](#getownproperty-internal-method-of-an-exported-gc-object).

12. Set `object`.\[\[DefineOwnProperty\]\] as specified in
 [\[\[DefineOwnProperty\]\] internal method of an Exported GC
 Object](#defineownproperty-internal-method-of-an-exported-gc-object).

13. Set `object`.\[\[HasProperty\]\] as specified in
 [\[\[HasProperty\]\] internal method of an Exported GC
 Object](#hasproperty-internal-method-of-an-exported-gc-object).

14. Set `object`.\[\[Get\]\] as specified in [\[\[Get\]\]
 internal method of an Exported GC
 Object](#get-internal-method-of-an-exported-gc-object).

15. Set `object`.\[\[Set\]\] as specified in [\[\[Set\]\]
 internal method of an Exported GC
 Object](#set-internal-method-of-an-exported-gc-object).

16. Set `object`.\[\[Delete\]\] as specified in
 [\[\[Delete\]\] internal method of an Exported GC
 Object](#delete-internal-method-of-an-exported-gc-object).

17. Set `object`.\[\[OwnPropertyKeys\]\] as specified in
 [\[\[OwnPropertyKeys\]\] internal method of an Exported GC
 Object](#ownpropertykeys-internal-method-of-an-exported-gc-object).

18. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`objectaddr`\] to
 `object`.

19. Return `object`.

### 5.10. Exceptions

```
dictionary ExceptionOptions {
 boolean traceStack = false;
};

[LegacyNamespace=WebAssembly, Exposed=(Window,Worker,Worklet)]
interface Exception {
 constructor(Tag exceptionTag, sequence<any> payload, optional ExceptionOptions options = );
 any getArg([EnforceRange] unsigned long index);
 boolean is(Tag exceptionTag);
 readonly attribute (DOMString or undefined) stack;
};
```

An [`Exception`](#exception)
value represents an exception.

To [initialize an Exception object] `exn` from an
[Exception
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-exnaddr) `exnAddress`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Exception object
 cache](#exception-object-cache).

2. Assert: `map`\[`exnAddress`\] doesn't
 [exist](https://infra.spec.whatwg.org/#map-exists).

3. Set `exn`.\[\[Address\]\] to `exnAddress`.

4. [Set](https://infra.spec.whatwg.org/#map-set) `map`\[`exnAddress`\] to
 `exn`.

5. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

6. Let `tagaddr` be
 [exn_tag](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-tag)(`store`, `exnAddress`).

7. Let `payload` be
 [exn_read](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-read)(`store`, `exnAddress`).

8. Set `exn`.\[\[Type\]\] to `tagaddr`.

9. Set `exn`.\[\[Payload\]\] to `payload`.

10. Set `exn`.\[\[Stack\]\] to undefined.

To [create an Exception object] from a [exception
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-exnaddr) `exnAddress`, perform the following steps:

1. Let `map` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [Exception object
 cache](#exception-object-cache).

2. If `map`\[`exnAddress`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. Return `map`\[`exnAddress`\].

3. Let `exn` be a
 [new](https://webidl.spec.whatwg.org/#new) [`Exception`](#exception).

4. [Initialize](#initialize-an-exception-object) `exn` from `exnAddress`.

5. Return `exn`.

[`new Exception(``exceptionTag``, ``payload``, ``options``)`]
constructor steps are:

1. Let `JSTagAddr` be the result of [getting the JavaScript
 exception
 tag](#get-the-javascript-exception-tag).

2. If `exceptionTag`.\[\[Address\]\] is equal to
 `JSTagAddr`,

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

3. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

4. Let \[`types`\] → \[\] be
 [tag_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-tag-type)(`store`,
 `exceptionTag`.\[\[Address\]\]).

5. If `types`'s
 [size](https://infra.spec.whatwg.org/#list-size) is not `payload`'s
 [size](https://infra.spec.whatwg.org/#list-size),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

6. Let `wasmPayload` be « ».

7. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `value` and `resultType` of
 `payload` and `types`, paired linearly,

 1. If `resultType` is
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types) or
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

 2. [Append](https://infra.spec.whatwg.org/#list-append)
 [?](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [ToWebAssemblyValue](#towebassemblyvalue)(`value`, `resultType`) to
 `wasmPayload`.

8. Let (`store`, `exceptionAddr`) be
 [exn_alloc](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-alloc)(`store`,
 `exceptionTag`.\[\[Address\]\],
 `wasmPayload`).

9. Set the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store) to `store`.

10. [Initialize](#initialize-an-exception-object) **this** from `exceptionAddr`.

11. If `options`\[\"traceStack\"\] is true,

 1. Set **this**.\[\[Stack\]\] to either a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) representation of the current call stack or
 undefined.

The [`getArg(``index``)`]
method steps are:

1. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

2. Let `tagaddr` be
 [exn_tag](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-tag)(`store`, **this**.\[\[Address\]\]).

3. Let `payload` be
 [exn_read](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-exn-read)(`store`, **this**.\[\[Address\]\]).

4. Assert: `tagaddr` is equal to **this**.\[\[Type\]\].

5. If `index` ≥ `payload`'s
 [size](https://infra.spec.whatwg.org/#list-size),

 1. Throw a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror).

6. Let \[`types`\] → \[\] be
 [tag_type](https://webassembly.github.io/spec/core/appendix/embedding.html#embed-tag-type)(`store`, `tagaddr`).

7. If `types`\[`index`\] is
 [v128](https://webassembly.github.io/spec/core/syntax/types.html#vector-types) or
 [exnref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype),

 1. Throw a
 [`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror).

8. Return [ToJSValue](#tojsvalue)(`payload`\[`index`\]).

The [`is(``exceptionTag``)`]
method steps are:

1. If **this**.\[\[Type\]\] is not equal to
 `exceptionTag`.\[\[Address\]\],

 1. Return false.

2. Return true.

The [`stack`] getter steps are:

1. Return **this**.\[\[Stack\]\].

#### 5.10.1. JavaScript exceptions

The [JavaScript exception tag] is a [tag
address](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-tagaddr) associated with the surrounding agent. It is allocated
in the agent's [associated
store](#associated-store)
on first use and cached. It always has the [tag
type](https://webassembly.github.io/spec/core/syntax/types.html#syntax-tagtype) «
[externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype) » → « ».

To [get the JavaScript exception tag], perform the following
steps:

1. If the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [JavaScript exception
 tag](#javascript-exception-tag) has been initialized,

 1. return the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s associated [JavaScript exception
 tag](#javascript-exception-tag).

2. Let `store` be the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [associated
 store](#associated-store).

3. Let (`store`, `tagAddress`) be
 [tag_alloc](#tag_alloc)(`store`, «
 [externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype) » → « »).

4. Set the current agent's [associated
 store](#associated-store) to `store`.

5. Set the current agent's associated [JavaScript exception
 tag](#javascript-exception-tag) to `tagAddress`.

6. return `tagAddress`.

### 5.11. Error Objects

WebAssembly defines the following Error classes:
[`CompileError`], [`LinkError`],
[`RuntimeError`], and
[`SuspendError`].

When the [namespace
object](https://webidl.spec.whatwg.org/#dfn-namespace-object) for the
[`WebAssembly`](#namespacedef-webassembly) namespace is
[created](https://heycam.github.io/webidl/#create-a-namespace-object), the following steps must be run:

1. Let `namespaceObject` be the [namespace
 object](https://webidl.spec.whatwg.org/#dfn-namespace-object).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `error` of « \"CompileError\",
 \"LinkError\", \"RuntimeError\", \"SuspendError\" »,

 1. Let `constructor` be a new object, implementing the
 [NativeError Object
 Structure](https://tc39.github.io/ecma262/#sec-nativeerror-object-structure), with `NativeError` set to
 `error`.

 2. [!](https://tc39.github.io/ecma262/#sec-returnifabrupt-shorthands)
 [DefineMethodProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-definemethodproperty)(`namespaceObject`,
 `error`, `constructor`, false).

 This defines
[`CompileError`](#exceptiondef-compileerror),
[`LinkError`](#exceptiondef-linkerror),
[`RuntimeError`](#exceptiondef-runtimeerror), and
[`SuspendError`](#exceptiondef-suspenderror) classes on the
[`WebAssembly`](#namespacedef-webassembly) namespace, which are produced by the APIs defined in
this specification. They expose the same interface as native JavaScript
errors like
[`TypeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and
[`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror).

 It is not currently possible to define this behavior
using Web IDL.

## 6. Error Condition Mappings to JavaScript

Running WebAssembly programs encounter certain events which halt
execution of the WebAssembly code. WebAssembly code (currently) has no
way to catch these conditions and thus an exception will necessarily
propagate to the enclosing non-WebAssembly caller (whether it is a
browser, JavaScript or another runtime system) where it is handled like
a normal JavaScript exception.

If WebAssembly calls JavaScript via import and the JavaScript throws an
exception, the exception is propagated through the WebAssembly
activation to the enclosing caller.

Because JavaScript exceptions can be handled, and JavaScript can
continue to call WebAssembly exports after a trap has been handled,
traps do not, in general, prevent future execution.

### 6.1. Stack Overflow

Whenever a stack overflow occurs in WebAssembly code, the same class of
exception is thrown as for a stack overflow in JavaScript. The
particular exception here is implementation-defined in both cases.

 ECMAScript doesn't specify any sort of behavior on
stack overflow; implementations have been observed to throw
[`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror), InternalError or Error. Any is valid here.

### 6.2. Out of Memory

Whenever validation, compilation or instantiation run out of memory, the
same class of exception is thrown as for out of memory conditions in
JavaScript. The particular exception here is implementation-defined in
both cases.

 ECMAScript doesn't specify any sort of behavior on
out-of-memory conditions; implementations have been observed to throw
OOMError and to crash. Either is valid here.

A failed allocation of a large table or
memory may either result in

- a
 [`RangeError`](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-rangeerror), as specified in the
 [`Memory`](#memory)
 [`grow()`](#dom-memory-grow) and [`Table`](#table)
 [`grow()`](#dom-table-grow) operations

- returning -1 as the
 [memory.grow](https://webassembly.github.io/spec/core/exec/instructions.html#exec-memory-grow) instruction

- UA-specific OOM behavior as described in this section.

In a future revision, we may reconsider more reliable and recoverable
errors for allocations of large amounts of memory.

See [Issue 879](https://github.com/WebAssembly/spec/issues/879) for
further discussion.

## 7. Implementation-defined Limits

The WebAssembly core specification allows an implementation to define
limits on the syntactic structure of the module. While each embedding of
WebAssembly may choose to define its own limits, for predictability the
standard WebAssembly JavaScript Interface described in this document
defines the following exact limits. An implementation must reject a
module that exceeds one of the following limits with a
[`CompileError`](#exceptiondef-compileerror). In practice, an implementation may run out of
resources for valid modules below these limits.

- The maximum size of a module is 1,073,741,824 bytes (1 GiB).
- The maximum number of types defined in the types section is 1,000,000.
- The maximum number of recursion groups defined in the types sections
 is 1,000,000.
- The maximum number of types defined in a recursion group is 1,000,000.
- The maximum depth of a defined subtype hierarchy is 63 (where a type
 defined with no supertype has depth 0).
- The maximum number of functions defined in a module is 1,000,000.
- The maximum number of imports declared in a module is 100,000.
- The maximum number of exports declared in a module is 100,000.
- The maximum number of globals defined in a module is 1,000,000.
- The maximum number of tags defined in a module is 1,000,000.
- The maximum number of data segments defined in a module is 100,000.
- The maximum number of tables, including declared or imported tables,
 is 100,000.
- The maximum size of a table is 10,000,000.
- The maximum number of table entries in any table initialization is
 10,000,000.
- The maximum number of memories, including defined and imported
 memories, is 100.
- The maximum number of parameters to any function or block is 1,000.
- The maximum number of return values for any function or block is
 1,000.
- The maximum size of a function body, including locals declarations, is
 7,654,321 bytes.
- The maximum number of locals declared in a function, including
 implicitly declared as parameters, is 50,000.
- The maximum number of fields in a struct is 10,000.
- The maximum number of operands to `array.new_fixed` is 10,000.

An implementation must throw a
[`RuntimeError`](#exceptiondef-runtimeerror) if one of the following limits is exceeded during
runtime: In practice, an implementation may run out of resources for
valid modules below these limits.

- The maximum size of a table is 10,000,000.
- The maximum number of pages of a memory is 65,536.

## 8. Security and Privacy Considerations

*This section is non-normative.*

This document defines a host environment for WebAssembly. It enables a
WebAssembly instance to
[import](https://webassembly.github.io/spec/core/syntax/modules.html#syntax-import) JavaScript objects and functions from an [import
object](#read-the-imports),
but otherwise provides no access to the embedding environment. Thus a
WebAssembly instance is bound to the same constraints as JavaScript.

## 9. Change History

*This section is non-normative.*

Since the original release 1.0 of the WebAssembly specification, a
number of proposals for extensions have been integrated. The following
sections provide an overview of what has changed.

### 9.1. Release 2.0

#### Multiple Values(#)

Multiple values can be returned from WebAssembly functions into
JavaScript as an
[Array](https://tc39.github.io/ecma262/#sec-array-exotic-objects) object.

#### BigInt Integration(#)

WebAssembly
[i64](https://webassembly.github.io/spec/core/syntax/types.html#syntax-numtype) values can be passed to and from JavaScript (via
imported or exported globals, table get or set operations, function
return values or arguments) as
[BigInt](https://tc39.github.io/ecma262/#sec-ecmascript-language-types-bigint-type) objects.

#### Reference types(#)

JavaScript values can be passed to and from WebAssembly (via imported or
exported globals, table set or get operations, and function arguments or
return values) as
[externref](https://webassembly.github.io/spec/core/syntax/types.html#syntax-reftype) values. Multiple tables can be
exported and imported to and from JavaScript.
