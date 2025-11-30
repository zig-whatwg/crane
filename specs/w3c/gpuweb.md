## 1. Introduction

*This section is non-normative.*

[Graphics Processing
Units](https://en.wikipedia.org/wiki/Graphics_processing_unit), or GPUs
for short, have been essential in enabling rich rendering and
computational applications in personal computing. WebGPU is an API that
exposes the capabilities of GPU hardware for the Web. The API is
designed from the ground up to efficiently map to (post-2014) native GPU
APIs. WebGPU is not related to [WebGL](https://www.khronos.org/webgl/)
and does not explicitly target OpenGL ES.

WebGPU sees physical GPU hardware as
[`GPUAdapter`](#gpuadapter)s.
It provides a connection to an adapter via
[`GPUDevice`](#gpudevice),
which manages resources, and the device's
[`GPUQueue`](#gpuqueue)s, which
execute commands. [`GPUDevice`](#gpudevice) may have its own memory with high-speed access to the
processing units. [`GPUBuffer`](#gpubuffer) and
[`GPUTexture`](#gputexture)
are the [physical resources] backed by GPU memory.
[`GPUCommandBuffer`](#gpucommandbuffer) and
[`GPURenderBundle`](#gpurenderbundle) are containers for user-recorded commands.
[`GPUShaderModule`](#gpushadermodule) contains [shader](#shaders) code. The other resources, such as
[`GPUSampler`](#gpusampler)
or [`GPUBindGroup`](#gpubindgroup), configure the way [physical
resources](#physical-resources) are used by the GPU.

GPUs execute commands encoded in
[`GPUCommandBuffer`](#gpucommandbuffer)s by feeding data through a
[pipeline](#pipeline), which is a mix
of fixed-function and programmable stages. Programmable stages execute
[shaders], which
are special programs designed to run on GPU hardware. Most of the state
of a [pipeline](#pipeline) is
defined by a
[`GPURenderPipeline`](#gpurenderpipeline) or a
[`GPUComputePipeline`](#gpucomputepipeline) object. The state not included in these
[pipeline](#pipeline) objects is set
during encoding with commands, such as
[`beginRenderPass()`](#dom-gpucommandencoder-beginrenderpass) or
[`setBlendConstant()`](#dom-gpurenderpassencoder-setblendconstant).

## 2. Malicious use considerations

*This section is non-normative.* It describes the risks associated with
exposing this API on the Web.

### 2.1. Security Considerations

The security requirements for WebGPU are the same as ever for the web,
and are likewise non-negotiable. The general approach is strictly
validating all the commands before they reach GPU, ensuring that a page
can only work with its own data.

#### 2.1.1. CPU-based undefined behavior

A WebGPU implementation translates the workloads issued by the user into
API commands specific to the target platform. Native APIs specify the
valid usage for the commands (for example, see
[vkCreateDescriptorSetLayout](https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/vkCreateDescriptorSetLayout.html))
and generally don't guarantee any outcome if the valid usage rules are
not followed. This is called \"undefined behavior\", and it can be
exploited by an attacker to access memory they don't own, or force the
driver to execute arbitrary code.

In order to disallow insecure usage, the range of allowed WebGPU
behaviors is defined for any input. An implementation has to validate
all the input from the user and only reach the driver with the valid
workloads. This document specifies all the error conditions and handling
semantics. For example, specifying the same buffer with intersecting
ranges in both \"source\" and \"destination\" of
[copyBufferToBuffer()](#gpucommandencoder-copybuffertobuffer) results in
[`GPUCommandEncoder`](#gpucommandencoder) generating an error, and no other operation occurring.

See [§ 22 Errors & Debugging](#errors-and-debugging) for more
information about error handling.

#### 2.1.2. GPU-based undefined behavior

WebGPU [shader](#shaders)s are
executed by the compute units inside GPU hardware. In native APIs, some
of the shader instructions may result in undefined behavior on the GPU.
In order to address that, the shader instruction set and its defined
behaviors are strictly defined by WebGPU. When a shader is provided to
[`createShaderModule()`](#dom-gpudevice-createshadermodule), the WebGPU implementation has to validate it before
doing any translation (to platform-specific shaders) or transformation
passes.

#### 2.1.3. Uninitialized data

Generally, allocating new memory may expose the leftover data of other
applications running on the system. In order to address that, WebGPU
conceptually initializes all the resources to zero, although in practice
an implementation may skip this step if it sees the developer
initializing the contents manually. This includes variables and shared
workgroup memory inside shaders.

The precise mechanism of clearing the workgroup memory can differ
between platforms. If the native API does not provide facilities to
clear it, the WebGPU implementation transforms the compute shader to
first do a clear across all invocations, synchronize them, and continue
executing developer's code.

NOTE:

The initialization status of a resource used in a queue operation can
only be known when the operation is enqueued (not when it is encoded
into a command buffer, for example). Therefore, some implementations
will require an unoptimized late-clear at enqueue time (e.g. clearing a
texture, rather than changing
[`GPULoadOp`](#enumdef-gpuloadop)
[`"load"`](#dom-gpuloadop-load) to
[`"clear"`](#dom-gpuloadop-clear)).

As a result, all implementations **should** issue a developer console
warning about this potential performance penalty, even if there is no
penalty in that implementation.

#### 2.1.4. Out-of-bounds access in shaders

[Shader](#shaders)s can access
[physical resource](#physical-resources)s either directly (for example, as a
[`"uniform"`](#dom-gpubufferbindingtype-uniform)
[`GPUBufferBinding`](#dictdef-gpubufferbinding)), or via [texture unit]s, which are fixed-function hardware blocks
that handle texture coordinate conversions. Validation in the WebGPU API
can only guarantee that all the inputs to the shader are provided and
they have the correct usage and types. The WebGPU API can not guarantee
that the data is accessed within bounds if the [texture
unit](#texture-unit)s are not
involved.

In order to prevent the shaders from accessing GPU memory an application
doesn't own, the WebGPU implementation may enable a special mode (called
\"robust buffer access\") in the driver that guarantees that the access
is limited to buffer bounds.

Alternatively, an implementation may transform the shader code by
inserting manual bounds checks. When this path is taken, the
out-of-bound checks only apply to array indexing. They aren't needed for
plain field access of shader structures due to the
[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) validation on the host side.

If the shader attempts to load data outside of [physical
resource](#physical-resources) bounds, the implementation is allowed to:

1. return a value at a different location within the resource bounds

2. return a value vector of \"(0, 0, 0, X)\" with any \"X\"

3. partially discard the draw or dispatch call

If the shader attempts to write data outside of [physical
resource](#physical-resources) bounds, the implementation is allowed to:

1. write the value to a different location within the resource bounds

2. discard the write operation

3. partially discard the draw or dispatch call

#### 2.1.5. Invalid data

When uploading [floating-point](https://en.wikipedia.org/wiki/IEEE_754)
data from CPU to GPU, or generating it on the GPU, we may end up with a
binary representation that doesn't correspond to a valid number, such as
infinity or NaN (not-a-number). The GPU behavior in this case is subject
to the accuracy of the GPU hardware implementation of the IEEE-754
standard. WebGPU guarantees that introducing invalid floating-point
numbers would only affect the results of arithmetic computations and
will not have other side effects.

#### 2.1.6. Driver bugs

GPU drivers are subject to bugs like any other software. If a bug
occurs, an attacker could possibly exploit the incorrect behavior of the
driver to get access to unprivileged data. In order to reduce the risk,
the WebGPU working group will coordinate with GPU vendors to integrate
the WebGPU Conformance Test Suite (CTS) as part of their driver testing
process, like it was done for WebGL. WebGPU implementations are expected
to have workarounds for some of the discovered bugs, and disable WebGPU
on drivers with known bugs that can't be worked around.

#### 2.1.7. Timing attacks

##### 2.1.7.1. Content-timeline timing

WebGPU does not expose new states to JavaScript (the [content
timeline](#content-timeline))
which are shared between
[agents](https://tc39.es/ecma262/#agent)
in an [agent
cluster](https://tc39.es/ecma262/#sec-agent-clusters). [Content
timeline](#content-timeline)
states such as
[`[[mapping]]`](#dom-gpubuffer-mapping-slot) only change during explicit [content
timeline](#content-timeline)
tasks, like in plain JavaScript.

##### 2.1.7.2. Device/queue-timeline timing

Writable storage buffers and other cross-invocation communication may be
usable to construct high-precision timers on the [queue
timeline](#queue-timeline).

The optional
[`"timestamp-query"`](#timestamp-query) feature also provides high precision timing of GPU
operations. To mitigate security and privacy concerns, the timing query
values are aligned to a lower precision: see [current queue
timestamp](#abstract-opdef-current-queue-timestamp). Note in particular:

- The [device timeline](#device-timeline) typically runs in a process that is shared by
 multiple origins, so cross-origin isolation (provided by COOP/COEP)
 does not provide isolation of device/queue-timeline timers.

- [Queue timeline](#queue-timeline) work is issued from the device timeline, and may
 execute on GPU hardware that does not provide the isolation expected
 of CPU processes (such as Meltdown mitigations).

- GPU hardware is not typically susceptible to Spectre-style attacks,
 **but** WebGPU may be implemented in software, and software
 implementations may run in a shared process, preventing
 isolation-based mitigations.

#### 2.1.8. Row hammer attacks

[Row hammer](https://en.wikipedia.org/wiki/Row_hammer) is a class of
attacks that exploit the leaking of states in DRAM cells. It could be
used [on GPU](https://www.vusec.net/projects/glitch/). WebGPU does not
have any specific mitigations in place, and relies on platform-level
solutions, such as reduced memory refresh intervals.

#### 2.1.9. Denial of service

WebGPU applications have access to GPU memory and compute units. A
WebGPU implementation may limit the available GPU memory to an
application, in order to keep other applications responsive. For GPU
processing time, a WebGPU implementation may set up \"watchdog\" timer
that makes sure an application doesn't cause GPU unresponsiveness for
more than a few seconds. These measures are similar to those used in
WebGL.

#### 2.1.10. Workload identification

WebGPU provides access to constrained global resources shared between
different programs (and web pages) running on the same machine. An
application can try to indirectly probe how constrained these global
resources are, in order to reason about workloads performed by other
open web pages, based on the patterns of usage of these shared
resources. These issues are generally analogous to issues with
Javascript, such as system memory and CPU execution throughput. WebGPU
does not provide any additional mitigations for this.

#### 2.1.11. Memory resources

WebGPU exposes fallible allocations from machine-global memory heaps,
such as VRAM. This allows for probing the size of the system's remaining
available memory (for a given heap type) by attempting to allocate and
watching for allocation failures.

GPUs internally have one or more (typically only two) heaps of memory
shared by all running applications. When a heap is depleted, WebGPU
would fail to create a resource. This is observable, which may allow a
malicious application to guess what heaps are used by other
applications, and how much they allocate from them.

#### 2.1.12. Computation resources

If one site uses WebGPU at the same time as another, it may observe the
increase in time it takes to process some work. For example, if a site
constantly submits compute workloads and tracks completion of work on
the queue, it may observe that something else also started using the
GPU.

A GPU has many parts that can be tested independently, such as the
arithmetic units, texture sampling units, atomic units, etc. A malicious
application may sense when some of these units are stressed, and attempt
to guess the workload of another application by analyzing the stress
patterns. This is analogous to the realities of CPU execution of
Javascript.

#### 2.1.13. Abuse of capabilities

Malicious sites could abuse the capabilities exposed by WebGPU to run
computations that don't benefit the user or their experience and instead
only benefit the site. Examples would be hidden crypto-mining, password
cracking or rainbow tables computations.

It is not possible to guard against these types of uses of the API
because the browser is not able to distinguish between valid workloads
and abusive workloads. This is a general problem with all
general-purpose computation capabilities on the Web: JavaScript,
WebAssembly or WebGL. WebGPU only makes some workloads easier to
implement, or slightly more efficient to run than using WebGL.

To mitigate this form of abuse, browsers can throttle operations on
background tabs, could warn that a tab is using a lot of resource, and
restrict which contexts are allowed to use WebGPU.

User agents can heuristically issue warnings to users about high power
use, especially due to potentially malicious usage. If a user agent
implements such a warning, it should include WebGPU usage in its
heuristics, in addition to JavaScript, WebAssembly, WebGL, and so on.

### 2.2. Privacy Considerations

[!(data:image/svg+xml;base64,PHN2ZyBhcmlhLWxhYmVsPSIoVGhpcyBpcyBhIHRyYWNraW5nIHZlY3Rvci4pIiBjbGFzcz0iZGFya21vZGUtYXdhcmUiIGhlaWdodD0iNjQiIHJvbGU9ImltZyIgd2lkdGg9IjQ2Ij48dGl0bGU+VGhlcmUgaXMgYSB0cmFja2luZyB2ZWN0b3IgaGVyZS48L3RpdGxlPjx1c2UgaHJlZj0iI2I3MzJiM2ZlIiAvPjwvc3ZnPg==)](https://infra.spec.whatwg.org/#tracking-vector) The privacy considerations for WebGPU are
similar to those of WebGL. GPU APIs are complex and must expose various
aspects of a device's capabilities out of necessity in order to enable
developers to take advantage of those capabilities effectively. The
general mitigation approach involves normalizing or binning potentially
identifying information and enforcing uniform behavior where possible.

A user agent must not reveal more than 32 distinguishable configurations
or buckets.

#### 2.2.1. Machine-specific features and limits

WebGPU can expose a lot of detail on the underlying GPU architecture and
the device geometry. This includes available physical adapters, many
limits on the GPU and CPU resources that could be used (such as the
maximum texture size), and any optional hardware-specific capabilities
that are available.

User agents are not obligated to expose the real hardware limits, they
are in full control of how much the machine specifics are exposed. One
strategy to reduce fingerprinting is binning all the target platforms
into a few number of bins. In general, the privacy impact of exposing
the hardware limits matches the one of WebGL.

The [default](#limit-default)
limits are also deliberately high enough to allow most applications to
work without requesting higher limits. All the usage of the API is
validated according to the requested limits, so the actual hardware
capabilities are not exposed to the users by accident.

#### 2.2.2. Machine-specific artifacts

There are some machine-specific rasterization/precision artifacts and
performance differences that can be observed roughly in the same way as
in WebGL. This applies to rasterization coverage and patterns,
interpolation precision of the varyings between shader stages, compute
unit scheduling, and more aspects of execution.

Generally, rasterization and precision fingerprints are identical across
most or all of the devices of each vendor. Performance differences are
relatively intractable, but also relatively low-signal (as with JS
execution performance).

Privacy-critical applications and user agents should utilize software
implementations to eliminate such artifacts.

#### 2.2.3. Machine-specific performance

Another factor for differentiating users is measuring the performance of
specific operations on the GPU. Even with low precision timing, repeated
execution of an operation can show if the user's machine is fast at
specific workloads. This is a fairly common vector (present in both
WebGL and Javascript), but it's also low-signal and relatively
intractable to truly normalize.

WebGPU compute pipelines expose access to GPU unobstructed by the
fixed-function hardware. This poses an additional risk for unique device
fingerprinting. User agents can take steps to dissociate logical GPU
invocations with actual compute units to reduce this risk.

#### 2.2.4. User Agent State

This specification doesn't define any additional user-agent state for an
origin. However it is expected that user agents will have compilation
caches for the result of expensive compilation like
[`GPUShaderModule`](#gpushadermodule),
[`GPURenderPipeline`](#gpurenderpipeline) and
[`GPUComputePipeline`](#gpucomputepipeline). These caches are important to improve the loading time
of WebGPU applications after the first visit.

For the specification, these caches are indifferentiable from incredibly
fast compilation, but for applications it would be easy to measure how
long
[`createComputePipelineAsync()`](#dom-gpudevice-createcomputepipelineasync) takes to resolve. This can leak information across
origins (like \"did the user access a site with this specific shader\")
so user agents should follow the best practices in [storage
partitioning](https://github.com/privacycg/storage-partitioning).

The system's GPU driver may also have its own cache of compiled shaders
and pipelines. User agents may want to disable these when at all
possible, or add per-partition data to shaders in ways that will make
the GPU driver consider them different.

#### 2.2.5. Driver bugs

In addition to the concerns outlined in [Security
Considerations](#security-driver-bugs), driver bugs may introduce
differences in behavior that can be observed as a method of
differentiating users. The mitigations mentioned in Security
Considerations apply here as well, including coordinating with GPU
vendors and implementing workarounds for known issues in the user agent.

#### 2.2.6. Adapter Identifiers

Past experience with WebGL has demonstrated that developers have a
legitimate need to be able to identify the GPU their code is running on
in order to create and maintain robust GPU-based content. For example,
to identify adapters with known driver bugs in order to work around them
or to avoid features that perform more poorly than expected on a given
class of hardware.

But exposing adapter identifiers also naturally expands the amount of
fingerprinting information available, so there's a desire to limit the
precision with which we identify the adapter.

There are several mitigations that can be applied to strike a balance
between enabling robust content and preserving privacy. First is that
user agents can reduce the burden on developers by identifying and
working around known driver issues, as they have since browsers began
making use of GPUs.

When adapter identifiers are exposed by default they should be as broad
as possible while still being useful. Possibly identifying, for example,
the adapter's vendor and general architecture without identifying the
specific adapter in use. Similarly, in some cases identifiers for an
adapter that is considered a reasonable proxy for the actual adapter may
be reported.

In cases where full and detailed information about the adapter is useful
(for example: when filing bug reports) the user can be asked for consent
to reveal additional information about their hardware to the page.

Finally, the user agent will always have the discretion to not report
adapter identifiers at all if it considers it appropriate, such as in
enhanced privacy modes.

## 3. Fundamentals

### 3.1. Conventions

#### 3.1.1. Syntactic Shorthands

In this specification, the following syntactic shorthands are used:

The `.` (\"dot\") syntax, common in programming languages.

: The phrasing \"`Foo.Bar`\" means \"the `Bar` member of the value (or
 interface) `Foo`.\" If `Foo` is an [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) and `Bar` does not
 [exist](https://infra.spec.whatwg.org/#map-exists) in `Foo`, returns `undefined`.

 The phrasing \"`Foo.Bar` is
 [provided](https://infra.spec.whatwg.org/#map-exists)\" means \"the `Bar` member
 [exists](https://infra.spec.whatwg.org/#map-exists) in the
 [map](https://infra.spec.whatwg.org/#ordered-map) value `Foo`\"

The `?.` (\"optional chaining\") syntax, adopted from JavaScript.

: The phrasing \"`Foo?.Bar`\" means \"if `Foo` is `null` or
 `undefined` or `Bar` does not
 [exist](https://infra.spec.whatwg.org/#map-exists) in `Foo`, `undefined`; otherwise, `Foo.Bar`\".

 For example, where `buffer` is a
 [`GPUBuffer`](#gpubuffer), `buffer?.\[[device]].\[[adapter]]` means \"if
 `buffer` is `null` or `undefined`, then `undefined`; otherwise, the
 `\[[adapter]]` internal slot of the `\[[device]]` internal slot of
 `buffer`.

The `??` (\"nullish coalescing\") syntax, adopted from JavaScript.

: The phrasing \"`x` ?? `y`\" means \"`x`, if `x` is not null or
 undefined, and `y` otherwise\".

[slot-backed attribute]

: A WebIDL attribute which is backed by an internal slot of the same
 name. It may or may not be mutable.

#### 3.1.2. WebGPU Objects

A [WebGPU object] consists of a [WebGPU
Interface](#webgpu-interface)
and an [internal object](#internal-object).

The [WebGPU interface] defines the public interface and state of
the [WebGPU object](#webgpu-object). It can be used on the [content
timeline](#content-timeline)
where it was created, where it is a JavaScript-exposed WebIDL interface.

Any interface which includes [`GPUObjectBase`] is a [WebGPU
interface](#webgpu-interface).

The [internal object] tracks the state of the [WebGPU
object](#webgpu-object) on the
[device timeline](#device-timeline). All reads/writes to the mutable state of an [internal
object](#internal-object)
occur from steps executing on a single well-ordered [device
timeline](#device-timeline).

The following special property types can be defined on [WebGPU
objects](#webgpu-object):

[immutable property]

: A read-only slot set during initialization of the object. It can be
 accessed from any timeline.

 Since the slot is immutable, implementations may
 have a copy on multiple timelines, as needed. [Immutable
 properties](#immutable-property) are defined in this way to avoid describing
 multiple copies in this spec.

 If named `[[with brackets]]`, it is an internal slot.\
 If named `withoutBrackets`, it is a `readonly` [slot-backed
 attribute](#slot-backed-attribute) of the [WebGPU
 interface](#webgpu-interface).

[content timeline property]

: A property which is only accessible from the [content
 timeline](#content-timeline) where the object was created.

 If named `[[with brackets]]`, it is an internal slot.\
 If named `withoutBrackets`, it is a [slot-backed
 attribute](#slot-backed-attribute) of the [WebGPU
 interface](#webgpu-interface).

[device timeline property]

: A property which tracks state of the [internal
 object](#internal-object)
 and is only accessible from the [device
 timeline](#device-timeline) where the object was created. [device timeline
 properties](#device-timeline-property) may be mutable.

 [Device timeline
 properties](#device-timeline-property) are named `[[with brackets]]`, and are internal
 slots.

[queue timeline property]

: A property which tracks state of the [internal
 object](#internal-object)
 and is only accessible from the [queue
 timeline](#queue-timeline)
 where the object was created. [queue timeline
 properties](#queue-timeline-property) may be mutable.

 [Queue timeline
 properties](#queue-timeline-property) are named `[[with brackets]]`, and are internal
 slots.

```
interface mixin GPUObjectBase {
 attribute USVString label;
};
```

To [create a new WebGPU
object]([`GPUObjectBase`](#gpuobjectbase) `parent`, interface `T`,
[`GPUObjectDescriptorBase`](#dictdef-gpuobjectdescriptorbase) `descriptor`) (where `T` extends
[`GPUObjectBase`](#gpuobjectbase)), run the following [content
timeline](#content-timeline)
steps:

1. Let `device` be
 `parent`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

2. Let `object` be a new instance of `T`.

3. Set
 `object`.[`[[device]]`](#dom-gpuobjectbase-device-slot) to `device`.

4. Set
 `object`.[`label`](#dom-gpuobjectbase-label) to
 `descriptor`.[`label`](#dom-gpuobjectdescriptorbase-label).

5. Return `object`.

[`GPUObjectBase`](#gpuobjectbase) has the following [immutable
properties](#immutable-property):

[`[[device]]`], of type [device](#device), readonly

: The [device](#device) that owns
 the [internal object](#internal-object).

 Operations on the contents of this object
 [assert](https://infra.spec.whatwg.org/#assert) they are running on the [device
 timeline](#device-timeline), and that the device is
 [valid](#abstract-opdef-valid).

[`GPUObjectBase`](#gpuobjectbase) has the following [content timeline
properties](#content-timeline-property):

[`label`], of type [USVString](https://webidl.spec.whatwg.org/#idl-USVString)

: A developer-provided label which is used in an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) way. It can be used by the browser, OS, or other
 tools to help identify the underlying [internal
 object](#internal-object)
 to the developer. Examples include displaying the label in
 [`GPUError`](#gpuerror)
 messages, console warnings, browser developer tools, and platform
 debugging utilities.

 ::::
 ::: marker
 NOTE:
 :::

 Implementations **should** use labels to enhance error messages by
 using them to identify WebGPU objects.
 However, this need not be the only way of identifying objects:
 implementations **should** also use other available information,
 especially when no label is available. For example:

 - The label of the parent
 [`GPUTexture`](#gputexture) when printing a
 [`GPUTextureView`](#gputextureview).

 - The label of the parent
 [`GPUCommandEncoder`](#gpucommandencoder) when printing a
 [`GPURenderPassEncoder`](#gpurenderpassencoder) or
 [`GPUComputePassEncoder`](#gpucomputepassencoder).

 - The label of the source
 [`GPUCommandEncoder`](#gpucommandencoder) when printing a
 [`GPUCommandBuffer`](#gpucommandbuffer).

 - The label of the source
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder) when printing a
 [`GPURenderBundle`](#gpurenderbundle).
 ::::

 ::::
 ::: marker
 NOTE:
 :::

 The
 [`label`](#dom-gpuobjectbase-label) is a property of the
 [`GPUObjectBase`](#gpuobjectbase). Two
 [`GPUObjectBase`](#gpuobjectbase) \"wrapper\" objects have completely separate label
 states, even if they refer to the same underlying object (for
 example returned by
 [`getBindGroupLayout()`](#dom-gpupipelinebase-getbindgrouplayout)). The
 [`label`](#dom-gpuobjectbase-label) property will not change except by being set from
 JavaScript.
 This means one underlying object could be associated with multiple
 labels. This specification does not define how the label is
 propagated to the [device
 timeline](#device-timeline). How labels are used is completely
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined): error messages could show the most recently set
 label, all known labels, or no labels at all.

 It is defined as a
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString) because some user agents may supply it to the debug
 facilities of the underlying native APIs.
 ::::

[`GPUObjectBase`](#gpuobjectbase) has the following [device timeline
properties](#device-timeline-property):

[`[[valid]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), initially `true`.

: If `true`, indicates that the [internal
 object](#internal-object)
 is valid to use.

NOTE:

Ideally [WebGPU
interfaces](#webgpu-interface) should not prevent their parent objects, such as the
[`[[device]]`](#dom-gpuobjectbase-device-slot) that owns them, from being garbage collected. This
cannot be guaranteed, however, as holding a strong reference to a parent
object may be required in some implementations.

As a result, developers should assume that a [WebGPU
interface](#webgpu-interface) may remain live until all child objects of that
interface have also been garbage collected, causing some resources to
remain allocated longer than anticipated.

Calling the `destroy` method on a [WebGPU
interface](#webgpu-interface) (such as
[`GPUDevice`](#gpudevice).[`destroy()`](#dom-gpudevice-destroy) or [`GPUBuffer`](#gpubuffer).[`destroy()`](#dom-gpubuffer-destroy)) should be favored over relying on garbage collection
if predictable release of allocated resources is needed.

#### 3.1.3. Object Descriptors

An [object descriptor] holds the information needed to create an
object, which is typically done via one of the `create*` methods of
[`GPUDevice`](#gpudevice).

```
dictionary GPUObjectDescriptorBase {
 USVString label = "";
};
```

[`GPUObjectDescriptorBase`](#dictdef-gpuobjectdescriptorbase) has the following members:

[`label`], of type [USVString](https://webidl.spec.whatwg.org/#idl-USVString), defaulting to `""`

: The initial value of
 [`GPUObjectBase.label`](#dom-gpuobjectbase-label).

### 3.2. Asynchrony

#### 3.2.1. Invalid Internal Objects & Contagious Invalidity

Object creation operations in WebGPU don't return promises, but
nonetheless are internally asynchronous. Returned objects refer to
[internal objects](#internal-object) which are manipulated on a [device
timeline](#device-timeline).
Rather than fail with exceptions or rejections, most errors that occur
on a [device timeline](#device-timeline) are communicated through
[`GPUError`](#gpuerror)s
generated on the associated [device](#device).

[Internal objects](#internal-object) are either
[valid](#abstract-opdef-valid) or
[invalid](#abstract-opdef-invalid). An
[invalid](#abstract-opdef-invalid) object will never become
[valid](#abstract-opdef-valid) at a later time, but some
[valid](#abstract-opdef-valid) objects may be
[invalidated](#abstract-opdef-invalidate).

Objects are
[invalid](#abstract-opdef-invalid) from creation if it wasn't possible to create
them. This can happen, for example, if the [object
descriptor](#object-descriptor) doesn't describe a valid object, or if there is not
enough memory to allocate a resource. It can also happen if an object is
created with or from another invalid object (for example calling
[`createView()`](#dom-gputexture-createview) on an invalid
[`GPUTexture`](#gputexture))
(for example the [`GPUTexture`](#gputexture) of a
[`createView()`](#dom-gputexture-createview) call): this case is referred to as [contagious
invalidity].

[Internal objects](#internal-object) of *most* types cannot become
[invalid](#abstract-opdef-invalid) after they are created, but still may become
unusable, e.g. if the owning device is
[lost](#lose-the-device) or
[`destroyed`](#dom-gpudevice-destroy), or the object has a special internal state, like
buffer state
\"[destroyed](#gpubuffer-internal-state-destroyed)\".

[Internal objects](#internal-object) of some types *can* become
[invalid](#abstract-opdef-invalid) after they are created; specifically,
[devices](#device),
[adapters](#adapter),
[`GPUCommandBuffer`](#gpucommandbuffer)s, and command/pass/bundle encoders.

A given [`GPUObjectBase`](#gpuobjectbase) `object` is [valid] if
`object`.[`[[valid]]`](#dom-gpuobjectbase-valid-slot) is `true`.

A given [`GPUObjectBase`](#gpuobjectbase) `object` is
[invalid] if
`object`.[`[[valid]]`](#dom-gpuobjectbase-valid-slot) is `false`.

A given [`GPUObjectBase`](#gpuobjectbase) `object` is [valid to use
with] a `targetObject` if the all
of the requirements in the following [device
timeline](#device-timeline)
steps are met:

- `object`.[`[[valid]]`](#dom-gpuobjectbase-valid-slot) must be `true`.

- `object`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[valid]]`](#dom-gpuobjectbase-valid-slot) must be `true`.

- `object`.[`[[device]]`](#dom-gpuobjectbase-device-slot) must equal
 `targetObject`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

To [invalidate] a
[`GPUObjectBase`](#gpuobjectbase) `object`, run the following [device
timeline](#device-timeline)
steps:

1. `object`.[`[[valid]]`](#dom-gpuobjectbase-valid-slot) to `false`.

#### 3.2.2. Promise Ordering

Several operations in WebGPU return promises.

- [`GPU`](#gpu).[`requestAdapter()`](#dom-gpu-requestadapter)

- [`GPUAdapter`](#gpuadapter).[`requestDevice()`](#dom-gpuadapter-requestdevice)

- [`GPUDevice`](#gpudevice).[`createComputePipelineAsync()`](#dom-gpudevice-createcomputepipelineasync)

- [`GPUDevice`](#gpudevice).[`createRenderPipelineAsync()`](#dom-gpudevice-createrenderpipelineasync)

- [`GPUShaderModule`](#gpushadermodule).[`getCompilationInfo()`](#dom-gpushadermodule-getcompilationinfo)

- [`GPUQueue`](#gpuqueue).[`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone)

- [`GPUBuffer`](#gpubuffer).[`mapAsync()`](#dom-gpubuffer-mapasync)

- [`GPUDevice`](#gpudevice).[`lost`](#dom-gpudevice-lost)

- [`GPUDevice`](#gpudevice).[`popErrorScope()`](#dom-gpudevice-poperrorscope)

WebGPU does not make any guarantees about the order in which these
promises settle (resolve or reject), except for the following:

- :::
 For some [`GPUQueue`](#gpuqueue) `q`, if `p1` =
 `q`.[`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone) is called before `p2` =
 `q`.[`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone), then `p1` must settle before
 `p2`.
 :::

- :::
 For some [`GPUQueue`](#gpuqueue) `q` and
 [`GPUBuffer`](#gpubuffer)
 `b` on the same
 [`GPUDevice`](#gpudevice),
 if `p1` =
 `b`.[`mapAsync()`](#dom-gpubuffer-mapasync) is called before `p2` =
 `q`.[`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone), then `p1` must settle before
 `p2`.
 :::

Applications must not rely on any other promise settlement ordering.

### 3.3. Coordinate Systems

Rendering operations use the following coordinate systems:

- [Normalized device coordinates] (or NDC) have three dimensions, where:

 - -1.0 ≤ x ≤ 1.0

 - -1.0 ≤ y ≤ 1.0

 - 0.0 ≤ z ≤ 1.0

 - The bottom-left corner is at (-1.0, -1.0, z).

 <figure>

 <figcaption>Normalized device coordinates.</figcaption>
 </figure>

 Whether `z = 0` or `z = 1` is treated as the near
 plane is application specific. The above diagram presents `z = 0` as
 the near plane but the observed behavior is determined by a
 combination of the projection matrices used by shaders, the
 [`depthClearValue`](#dom-gpurenderpassdepthstencilattachment-depthclearvalue), and the
 [`depthCompare`](#dom-gpudepthstencilstate-depthcompare) function.

- [Clip space coordinates] have four dimensions: (x, y, z, w)

 - Clip space coordinates are used for the the [clip
 position](#clip-position) of
 a vertex (i.e. the
 [position](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-position) output of a vertex shader), and for the [clip
 volume](#clip-volume).

 - [Normalized device coordinates](#ndc)
 and clip space coordinates are related as follows: If point *p =
 (p.x, p.y, p.z, p.w)* is in the [clip
 volume](#clip-volume), then
 its normalized device coordinates are (*p.x* ÷ *p.w*, *p.y* ÷ *p.w*,
 *p.z* ÷ *p.w*).

- [Framebuffer coordinates] address the pixels in the
 [framebuffer](#framebuffer)

 - They have two dimensions.

 - Each pixel extends 1 unit in x and y dimensions.

 - The top-left corner is at (0.0, 0.0).

 - x increases to the right.

 - y increases down.

 - See [§ 17 Render Passes](#render-passes) and [§ 23.2.5
 Rasterization](#rasterization).

 <figure>

 <figcaption>Framebuffer coordinates.</figcaption>
 </figure>

- [Viewport coordinates] combine [framebuffer
 coordinates](#framebuffer-coordinates) in x and y dimensions, with depth in z.

 - Normally 0.0 ≤ z ≤ 1.0, but this can be modified by setting
 [`[[viewport]]`](#dom-renderstate-viewport-slot).`minDepth` and `maxDepth` via
 [`setViewport()`](#dom-gpurenderpassencoder-setviewport)

- [Fragment coordinates] match [viewport
 coordinates](#viewport-coordinates).

- [Texture coordinates], sometimes called \"UV coordinates\" in
 2D, are used to sample textures and have a number of components
 matching the
 [`texture dimension`](#enumdef-gputexturedimension).

 - 0 ≤ u ≤ 1.0

 - 0 ≤ v ≤ 1.0

 - 0 ≤ w ≤ 1.0

 - (0.0, 0.0, 0.0) is in the first texel in texture memory address
 order.

 - (1.0, 1.0, 1.0) is in the last texel texture memory address order.

 <figure>

 <figcaption>2D Texture coordinates.</figcaption>
 </figure>

- [Window coordinates], or [present
 coordinates], match [framebuffer
 coordinates](#framebuffer-coordinates), and are used when interacting with an external
 display or conceptually similar interface.

 WebGPU's coordinate systems match DirectX's coordinate
systems in a graphics pipeline.

### 3.4. Programming Model

#### 3.4.1. Timelines

WebGPU's behavior is described in terms of \"timelines\". Each operation
(defined as algorithms) occurs on a timeline. Timelines clearly define
both the order of operations, and which state is available to which
operations.

 This \"timeline\" model describes the constraints of
the multi-process models of browser engines (typically with a \"content
process\" and \"GPU process\"), as well as the GPU itself as a separate
execution unit in many implementations. Implementing WebGPU does not
require timelines to execute in parallel, so does not require multiple
processes, or even multiple threads. (It does require concurrency for
cases like [get a copy of the image contents of a
context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context) which synchronously blocks on another timeline
to complete.)

[Content timeline]

: Associated with the execution of the Web script. It includes calling
 all methods described by this specification.

 To issue steps to the content timeline from an operation on
 [`GPUDevice`](#gpudevice)
 `device`, [queue a global task for
 GPUDevice](#abstract-opdef-queue-a-global-task-for-gpudevice) `device` with those steps.

[Device timeline]

: Associated with the GPU device operations that are issued by the
 user agent. It includes creation of adapters, devices, and GPU
 resources and state objects, which are typically synchronous
 operations from the point of view of the user agent part that
 controls the GPU, but can live in a separate OS process.

[Queue timeline]

: Associated with the execution of operations on the compute units of
 the GPU. It includes actual draw, copy, and compute jobs that run on
 the GPU.

[Timeline-agnostic]

: Associated with any of the above timelines

 Steps may be issued to any timeline if they only operate on
 [immutable
 properties](#immutable-property) or arguments passed from the calling steps.

The following show the styling of
steps and values associated with each timeline. This styling is
non-normative; the specification text always describes the association.

[Immutable value example term] definition

: Can be used on any timeline.

<!-- -->

[Content-timeline example term] definition

: Can only be used on the [content
 timeline](#content-timeline).

<!-- -->

[Device-timeline example term] definition

: Can only be used on the [device
 timeline](#device-timeline).

<!-- -->

[Queue-timeline example term] definition

: Can only be used on the [queue
 timeline](#queue-timeline).

::: {timeline="const"}
Steps which are
[timeline-agnostic](#timeline-agnostic) look like this.

[Immutable value example
term](#immutable-value-example-term) usage.

::: {timeline="content"}
Steps executed on the [content
timeline](#content-timeline)
look like this.

[Immutable value example
term](#immutable-value-example-term) usage. [Content-timeline example
term](#content-timeline-example-term) usage.

::: {timeline="device"}
Steps executed on the [device
timeline](#device-timeline)
look like this.

[Immutable value example
term](#immutable-value-example-term) usage. [Device-timeline example
term](#device-timeline-example-term) usage.

::: {timeline="queue"}
Steps executed on the [queue
timeline](#queue-timeline)
look like this.

[Immutable value example
term](#immutable-value-example-term) usage. [Queue-timeline example
term](#queue-timeline-example-term) usage.

In this specification, asynchronous operations are used when the return
value depends on work that happens on any timeline other than the
[Content timeline](#content-timeline). They are represented by promises and events in API.

[`GPUComputePassEncoder.dispatchWorkgroups()`](#dom-gpucomputepassencoder-dispatchworkgroups):

1. User encodes a `dispatchWorkgroups` command by calling a method of
 the
 [`GPUComputePassEncoder`](#gpucomputepassencoder) which happens on the [Content
 timeline](#content-timeline).

2. User issues
 [`GPUQueue.submit()`](#dom-gpuqueue-submit) that hands over the
 [`GPUCommandBuffer`](#gpucommandbuffer) to the user agent, which processes it on the
 [Device timeline](#device-timeline) by calling the OS driver to do a low-level
 submission.

3. The submit gets dispatched by the GPU invocation scheduler onto the
 actual compute units for execution, which happens on the [Queue
 timeline](#queue-timeline).

[`GPUDevice.createBuffer()`](#dom-gpudevice-createbuffer):

1. User fills out a
 [`GPUBufferDescriptor`](#gpubufferdescriptor) and creates a
 [`GPUBuffer`](#gpubuffer)
 with it, which happens on the [Content
 timeline](#content-timeline).

2. User agent creates a low-level buffer on the [Device
 timeline](#device-timeline).

[`GPUBuffer.mapAsync()`](#dom-gpubuffer-mapasync):

1. User requests to map a
 [`GPUBuffer`](#gpubuffer)
 on the [Content
 timeline](#content-timeline) and gets a promise in return.

2. User agent checks if the buffer is currently used by the GPU and
 makes a reminder to itself to check back when this usage is over.

3. After the GPU operating on [Queue
 timeline](#queue-timeline)
 is done using the buffer, the user agent maps it to memory and
 [resolves](https://webidl.spec.whatwg.org/#resolve) the promise.

#### 3.4.2. Memory Model

*This section is non-normative.*

Once a [`GPUDevice`](#gpudevice) has been obtained during an application initialization
routine, we can describe the [WebGPU platform] as consisting of the following
layers:

1. User agent implementing the specification.

2. Operating system with low-level native API drivers for this device.

3. Actual CPU and GPU hardware.

Each layer of the [WebGPU
platform](#webgpu-platform)
may have different memory types that the user agent needs to consider
when implementing the specification:

- The script-owned memory, such as an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) created by the script, is generally not accessible by
 a GPU driver.

- A user agent may have different processes responsible for running the
 content and communication to the GPU driver. In this case, it uses
 inter-process shared memory to transfer data.

- Dedicated GPUs have their own memory with high bandwidth, while
 integrated GPUs typically share memory with the system.

Most [physical
resources](#physical-resources) are allocated in the memory of type that is efficient
for computation or rendering by the GPU. When the user needs to provide
new data to the GPU, the data may first need to cross the process
boundary in order to reach the user agent part that communicates with
the GPU driver. Then it may need to be made visible to the driver, which
sometimes requires a copy into driver-allocated staging memory. Finally,
it may need to be transferred to the dedicated GPU memory, potentially
changing the internal layout into one that is most efficient for GPUs to
operate on.

All of these transitions are done by the WebGPU implementation of the
user agent.

 This example describes the worst case, while in
practice the implementation might not need to cross the process
boundary, or may be able to expose the driver-managed memory directly to
the user behind an `ArrayBuffer`, thus avoiding any data copies.

#### 3.4.3. Resource Usages

A [physical resource](#physical-resources) can be used with an [internal usage] by a [GPU
command](#gpu-command):

[input]

: Buffer with input data for draw or dispatch calls. Preserves the
 contents. Allowed by buffer
 [`INDEX`](#dom-gpubufferusage-index), buffer
 [`VERTEX`](#dom-gpubufferusage-vertex), or buffer
 [`INDIRECT`](#dom-gpubufferusage-indirect).

[constant]

: Resource bindings that are constant from the shader point of view.
 Preserves the contents. Allowed by buffer
 [`UNIFORM`](#dom-gpubufferusage-uniform) or texture
 [`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding).

[storage]

: Read/write storage resource binding. Allowed by buffer
 [`STORAGE`](#dom-gpubufferusage-storage) or texture
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding).

[storage-read]

: Read-only storage resource bindings. Preserves the contents. Allowed
 by buffer
 [`STORAGE`](#dom-gpubufferusage-storage) or texture
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding).

[attachment]

: Texture used as a read/write output attachment or write-only resolve
 target in a render pass. Allowed by texture
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment).

[attachment-read]

: Texture used as a read-only attachment in a render pass. Preserves
 the contents. Allowed by texture
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment).

We define [subresource] to be either a whole buffer, or a [texture
subresource](#texture-subresources).

Some [internal usages](#internal-usage) are compatible with others. A
[subresource](#subresource) can be
in a state that combines multiple usages together. We consider a list
`U` to be a [compatible usage list] if (and only if) it
satisfies any of the following rules:

- Each usage in `U` is
 [input](#internal-usage-input),
 [constant](#internal-usage-constant),
 [storage-read](#internal-usage-storage-read), or
 [attachment-read](#internal-usage-attachment-read).

- Each usage in `U` is
 [storage](#internal-usage-storage).

 Multiple such usages are allowed even though they are writable. This
 is the [usage scope storage
 exception](#usage-scope-storage-exception).

- Each usage in `U` is
 [attachment](#internal-usage-attachment).

 Multiple such usages are allowed even though they are writable. This
 is the [usage scope attachment
 exception](#usage-scope-attachment-exception).

Enforcing that the usages are only combined into a [compatible usage
list](#compatible-usage-list) allows the API to limit when data races can occur in
working with memory. That property makes applications written against
WebGPU more likely to run without modification on different platforms.

EXAMPLE:

Binding the same buffer for
[storage](#internal-usage-storage) as well as for
[input](#internal-usage-input) within the same
[`GPURenderPassEncoder`](#gpurenderpassencoder) results in a non-[compatible usage
list](#compatible-usage-list) for that buffer.

EXAMPLE:

These rules allow for [read-only depth-stencil]: a single depth/stencil
texture can be used as two different read-only usages in a render pass
simultaneously:

- [attachment-read](#internal-usage-attachment-read)

 As a depth/stencil attachment with all aspects marked read-only (using
 [`depthReadOnly`](#dom-gpurenderpassdepthstencilattachment-depthreadonly) and/or
 [`stencilReadOnly`](#dom-gpurenderpassdepthstencilattachment-stencilreadonly) as necessary).

- [constant](#internal-usage-constant)

 As a texture binding to a draw call.

EXAMPLE:

The [usage scope storage exception] allows two cases that would not
be allowed otherwise:

- A buffer or texture may be bound as
 [storage](#internal-usage-storage) to two different draw calls in a render pass.

- Disjoint ranges of a single buffer may be bound to two different
 binding points as
 [storage](#internal-usage-storage).

 Overlapping ranges must not be bound to a single dispatch/draw call;
 this is checked by \"[Encoder bind groups alias a writable
 resource](#abstract-opdef-encoder-bind-groups-alias-a-writable-resource)\".

EXAMPLE:

The [usage scope attachment exception] allows a texture
subresource to be used as
[attachment](#internal-usage-attachment) more than once. This is necessary to allow disjoint
slices of 3D textures to be bound as different attachments to a single
render pass.

One slice must not be bound twice for two different attachments; this is
checked by
[`beginRenderPass()`](#dom-gpucommandencoder-beginrenderpass).

#### 3.4.4. Synchronization

A [usage scope] is a
[map](https://infra.spec.whatwg.org/#ordered-map) from [subresource](#subresource) to
[list](https://infra.spec.whatwg.org/#list)\<[internal
usage](#internal-usage)\>\>.
Each usage scope covers a range of operations which may execute in a
concurrent fashion with each other, and therefore may only use
[subresources](#subresource) in
consistent [compatible usage
lists](#compatible-usage-list) within the scope.

A [usage scope](#usage-scope)
`scope` passes [usage scope
validation] if, for each \[`subresource`, `usageList`\] in
`scope`, `usageList` is a [compatible usage
list](#compatible-usage-list).

To [add] a
[subresource](#subresource)
`subresource` to [usage
scope](#usage-scope)
`usageScope` with usage ([internal
usage](#internal-usage) or set
of [internal usages](#internal-usage)) `usage`:

1. If `usageScope`\[`subresource`\] does not
 [exist](https://infra.spec.whatwg.org/#map-exists), set it to ``.

2. [Append](https://infra.spec.whatwg.org/#list-append) `usage` to
 `usageScope`\[`subresource`\].

To [merge]
[usage scope](#usage-scope)
`A` into [usage scope](#usage-scope) `B`:

1. For each \[`subresource`, `usage`\] in
 `A`:

 1. [Add](#abstract-opdef-usage-scope-add) `subresource` to
 `B` with usage `usage`.

[Usage scopes](#usage-scope) are
constructed and validated during encoding:

- in
 [`dispatchWorkgroups()`](#dom-gpucomputepassencoder-dispatchworkgroups)

- in
 [`dispatchWorkgroupsIndirect()`](#dom-gpucomputepassencoder-dispatchworkgroupsindirect)

- at
 [`GPURenderPassEncoder.end()`](#dom-gpurenderpassencoder-end)

- at
 [`GPURenderBundleEncoder.finish()`](#dom-gpurenderbundleencoder-finish)

The [usage scopes](#usage-scope)
are as follows:

- In a compute pass, each dispatch command
 ([`dispatchWorkgroups()`](#dom-gpucomputepassencoder-dispatchworkgroups) or
 [`dispatchWorkgroupsIndirect()`](#dom-gpucomputepassencoder-dispatchworkgroupsindirect)) is one usage scope.

 A subresource is used in the usage scope if it is potentially
 accessible by the dispatched invocations, including:

 - All [subresources](#subresource) referenced by bind groups in slots used by the
 current
 [`GPUComputePipeline`](#gpucomputepipeline)'s
 [`[[layout]]`](#dom-gpupipelinebase-layout-slot)

 - Buffers used directly by dispatch calls (such as indirect buffers)

 State-setting compute pass commands, like
 [setBindGroup()](#gpubindingcommandsmixin-setbindgroup), do not contribute their bound resources directly to
 a usage scope: they only change the state that is checked in dispatch
 commands.

- One render pass is one usage scope.

 A subresource is used in the usage scope if it's referenced by any
 command, including state-setting commands (unlike in compute passes),
 including:

 - Buffers set by
 [`setVertexBuffer()`](#dom-gpurendercommandsmixin-setvertexbuffer)

 - Buffers set by
 [`setIndexBuffer()`](#dom-gpurendercommandsmixin-setindexbuffer)

 - All [subresources](#subresource) referenced by bind groups set by
 [setBindGroup()](#gpubindingcommandsmixin-setbindgroup)

 - Buffers used directly by draw calls (such as indirect buffers)

 Copy commands are standalone operations and don't use
[usage scopes](#usage-scope) for
validation. They implement their own validation to prevent self-races.

EXAMPLE:

The following example resource usages *are* included in [usage
scopes](#usage-scope):

- In a render pass, subresources used in any
 [setBindGroup()](#gpubindingcommandsmixin-setbindgroup) call, regardless of whether the currently bound
 pipeline's shader or layout actually depends on these bindings, or the
 bind group is shadowed by another \'set\' call.

- A buffer used in any
 [`setVertexBuffer()`](#dom-gpurendercommandsmixin-setvertexbuffer) call, regardless of whether any draw call depends on
 this buffer, or whether this buffer is shadowed by another \'set\'
 call.

- A buffer used in any
 [`setIndexBuffer()`](#dom-gpurendercommandsmixin-setindexbuffer) call, regardless of whether any draw call depends on
 this buffer, or whether this buffer is shadowed by another \'set\'
 call.

- A texture subresource used as a color attachment, resolve attachment,
 or depth/stencil attachment in
 [`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor) by
 [`beginRenderPass()`](#dom-gpucommandencoder-beginrenderpass), regardless of whether the shader actually depends on
 these attachments.

- Resources used in bind group entries with visibility 0, or visible
 only to the compute stage but used in a render pass (or vice versa).

### 3.5. Core Internal Objects

#### 3.5.1. Adapters

An [adapter]
identifies an implementation of WebGPU on the system: both an instance
of compute/rendering functionality on the platform underlying a browser,
and an instance of a browser's implementation of WebGPU on top of that
functionality.

[Adapters](#adapter) are exposed via
[`GPUAdapter`](#gpuadapter).

[Adapters](#adapter) do not uniquely
represent underlying implementations: calling
[`requestAdapter()`](#dom-gpu-requestadapter) multiple times returns a different
[adapter](#adapter) object each time.

Each [adapter](#adapter) object can
only be used to create one [device](#device): upon a successful
[`requestDevice()`](#dom-gpuadapter-requestdevice) call, the adapter's
[`[[state]]`](#dom-adapter-state-slot) changes to
[`"consumed"`](#dom-adapter-state-consumed). Additionally, [adapter](#adapter) objects may
[expire](#abstract-opdef-expire) at any time.

 This ensures applications use the latest system state
for adapter selection when creating a device. It also encourages
robustness to more scenarios by making them look similar: first
initialization, reinitialization due to an unplugged adapter,
reinitialization due to a test
[`GPUDevice.destroy()`](#dom-gpudevice-destroy) call, etc.

An [adapter](#adapter) may be
considered a [fallback adapter] if it has significant performance caveats in
exchange for some combination of wider compatibility, more predictable
behavior, or improved privacy. It is not required that a [fallback
adapter](#fallback-adapter)
is available on every system.

[adapter](#adapter) has the following
[immutable properties](#immutable-property):

[`[[features]]`], of type [ordered set](https://infra.spec.whatwg.org/#ordered-set)\<[`GPUFeatureName`](#gpufeaturename)\>, readonly

: The [features](#feature) which can
 be used to create devices on this adapter.

[`[[limits]]`], of type [supported limits](#supported-limits), readonly

: The [best](#limit-better)
 limits which can be used to create devices on this adapter.

 Each adapter limit must be the same or
 [better](#limit-better) than
 its default value in [supported
 limits](#supported-limits).

[`[[fallback]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: If set to `true` indicates that the adapter is a [fallback
 adapter](#fallback-adapter).

[`[[xrCompatible]]`], of type boolean

: If set to `true` indicates that the adapter was requested with
 compatibility with [WebXR
 sessions](https://www.w3.org/TR/webxr/#session).

[`[[default feature level]]`], of type [feature level string](#feature-level-string), readonly

: Indicates the default feature level of devices created from this
 adapter.

[adapter](#adapter) has the following
[device timeline
properties](#device-timeline-property):

[`[[state]]`], initially [`"valid"`](#dom-adapter-state-valid)

:

 [`"valid"`]

 : The adapter can be used to create a device.

 [`"consumed"`]

 : The adapter has already been used to create a device, and cannot
 be used again.

 [`"expired"`]

 : The adapter has expired for some other reason.

To [expire] a
[`GPUAdapter`](#gpuadapter)
`adapter`, run the following [device
timeline](#device-timeline)
steps:

1. Set
 `adapter`.[`[[adapter]]`](#dom-gpuadapter-adapter-slot).[`[[state]]`](#dom-adapter-state-slot) to
 [`"expired"`](#dom-adapter-state-expired).

#### 3.5.2. Devices

A [device] is the
logical instantiation of an [adapter](#adapter), through which [internal
objects](#internal-object)
are created.

[Devices](#device) are exposed via
[`GPUDevice`](#gpudevice).

A [device](#device) is the exclusive
owner of all [internal
objects](#internal-object)
created from it: when the [device](#device) becomes
[invalid](#abstract-opdef-invalid) (is
[lost](#lose-the-device) or
[`destroyed`](#dom-gpudevice-destroy)), it and all objects created on it (directly, e.g.
[`createTexture()`](#dom-gpudevice-createtexture), or indirectly, e.g.
[`createView()`](#dom-gputexture-createview)) become implicitly
[unusable](#abstract-opdef-valid-to-use-with).

[device](#device) has the following
[immutable properties](#immutable-property):

[`[[adapter]]`], of type [adapter](#adapter), readonly

: The [adapter](#adapter) from
 which this device was created.

[`[[features]]`], of type [ordered set](https://infra.spec.whatwg.org/#ordered-set)\<[`GPUFeatureName`](#gpufeaturename)\>, readonly

: The [features](#feature) which
 can be used on this device, as computed [at
 creation](#a-new-device). No
 additional features can be used, even if the underlying
 [adapter](#adapter) can support
 them.

[`[[limits]]`], of type [supported limits](#supported-limits), readonly

: The limits which can be used on this device, as computed [at
 creation](#a-new-device). No
 [better](#limit-better)
 limits can be used, even if the underlying
 [adapter](#adapter) can support
 them.

[device](#device) has the following
[content timeline
properties](#content-timeline-property):

[`[[content device]]`], of type [`GPUDevice`](#gpudevice), readonly

: The [Content
 timeline](#content-timeline)
 [`GPUDevice`](#gpudevice) interface which this device is associated with.

To create [a new device] from [adapter](#adapter) `adapter` with
[`GPUDeviceDescriptor`](#gpudevicedescriptor) `descriptor`, run the following [device
timeline](#device-timeline)
steps:

1. Let `features` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of values in
 `descriptor`.[`requiredFeatures`](#dom-gpudevicedescriptor-requiredfeatures).

2. If `features` contains
 [`"texture-formats-tier2"`](#texture-formats-tier2):

 1. [Append](https://infra.spec.whatwg.org/#set-append)
 [`"texture-formats-tier1"`](#texture-formats-tier1) to `features`.

3. If `features` contains
 [`"texture-formats-tier1"`](#texture-formats-tier1):

 1. [Append](https://infra.spec.whatwg.org/#set-append)
 [`"rg11b10ufloat-renderable"`](#rg11b10ufloat-renderable) to `features`.

4. Append any default
 [`GPUFeatureName`](#gpufeaturename)s to `features` as defined by the
 `adapter`.[`[[default feature level]]`](#dom-adapter-default-feature-level-slot).

5. Let `limits` be a new [supported
 limits](#supported-limits) object with the default limits as defined by the
 `adapter`.[`[[default feature level]]`](#dom-adapter-default-feature-level-slot).

6. For each (`key`, `value`) pair in
 `descriptor`.[`requiredLimits`](#dom-gpudevicedescriptor-requiredlimits):

 1. If `value` is not `undefined` and `value`
 is [better](#limit-better) than `limits`\[`key`\]:

 1. Set `limits`\[`key`\] to
 `value`.

7. Set
 `limits`.[`maxStorageBuffersPerShaderStage`](#dom-supported-limits-maxstoragebufferspershaderstage) to
 max(`limits`.[`maxStorageBuffersPerShaderStage`](#dom-supported-limits-maxstoragebufferspershaderstage),
 `limits`.[`maxStorageBuffersInVertexStage`](#dom-supported-limits-maxstoragebuffersinvertexstage),
 `limits`.[`maxStorageBuffersInFragmentStage`](#dom-supported-limits-maxstoragebuffersinfragmentstage)).

8. Set
 `limits`.[`maxStorageTexturesPerShaderStage`](#dom-supported-limits-maxstoragetexturespershaderstage) to
 max(`limits`.[`maxStorageTexturesPerShaderStage`](#dom-supported-limits-maxstoragetexturespershaderstage),
 `limits`.[`maxStorageTexturesInVertexStage`](#dom-supported-limits-maxstoragetexturesinvertexstage),
 `limits`.[`maxStorageTexturesInFragmentStage`](#dom-supported-limits-maxstoragetexturesinfragmentstage)).

9. If `features`
 [contains](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):

 1. Set
 `limits`.[`maxStorageBuffersInVertexStage`](#dom-supported-limits-maxstoragebuffersinvertexstage) and
 `limits`.[`maxStorageBuffersInFragmentStage`](#dom-supported-limits-maxstoragebuffersinfragmentstage) to
 `limits`.[`maxStorageBuffersPerShaderStage`](#dom-supported-limits-maxstoragebufferspershaderstage).

 2. Set
 `limits`.[`maxStorageTexturesInVertexStage`](#dom-supported-limits-maxstoragetexturesinvertexstage) and
 `limits`.[`maxStorageTexturesInFragmentStage`](#dom-supported-limits-maxstoragetexturesinfragmentstage) to
 `limits`.[`maxStorageTexturesPerShaderStage`](#dom-supported-limits-maxstoragetexturespershaderstage).

10. Let `device` be a [device](#device) object.

11. Set
 `device`.[`[[adapter]]`](#dom-device-adapter-slot) to `adapter`.

12. Set
 `device`.[`[[features]]`](#dom-device-features-slot) to `features`.

13. Set
 `device`.[`[[limits]]`](#dom-device-limits-slot) to `limits`.

14. Return `device`.

Any time the user agent needs to revoke access to a device, it calls
[lose the device](#lose-the-device)(`device`,
[`"unknown"`](#dom-gpudevicelostreason-unknown)) on the device's [device
timeline](#device-timeline),
potentially ahead of other operations currently queued on that timeline.

If an operation fails with side effects that would observably change the
state of objects on the device or potentially corrupt internal
implementation/driver state, the device **should** be lost to prevent
these changes from being observable.

 For all device losses not initiated by the application
(via
[`destroy()`](#dom-gpudevice-destroy)), user agents should consider issuing developer-visible
warnings *unconditionally*, even if the
[`lost`](#dom-gpudevice-lost) promise is handled. These scenarios should be rare, and
the signal is vital to developers because most of the WebGPU API tries
to behave like nothing is wrong to avoid interrupting the runtime flow
of the application: no validation errors are raised, most promises
resolve normally, etc.

To [lose the device](`device`, `reason`) run the following
[device timeline](#device-timeline) steps:

1. [Invalidate](#abstract-opdef-invalidate) `device`.

2. Issue the following steps on the [content
 timeline](#content-timeline) of
 `device`.[`[[content device]]`](#dom-device-content-device-slot):

 ::: {timeline="content"}
 1. Resolve
 `device`.[`lost`](#dom-gpudevice-lost) with a new
 [`GPUDeviceLostInfo`](#gpudevicelostinfo) with
 [`reason`](#dom-gpudevicelostinfo-reason) set to `reason` and
 [`message`](#dom-gpudevicelostinfo-message) set to an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) value.

 [`message`](#dom-gpudevicelostinfo-message) should not disclose unnecessary user/system
 information and should never be parsed by applications.
 :::

3. Complete any outstanding steps that are waiting until
 `device` [becomes lost].

 No errors are generated from a device which is lost.
See [§ 22 Errors & Debugging](#errors-and-debugging).

To [listen for timeline event] `event` on
[device](#device)
`device`, handled by `steps` on timeline
`timeline`:

- If or when the [device
 timeline](#device-timeline) has been informed of the completion of
 `event`, or

- If `device` is
 [lost](#abstract-opdef-invalid) already, or when it [becomes
 lost](#becomes-lost):

Then issue `steps` on `timeline`.

### 3.6. Optional Capabilities

WebGPU [adapters](#adapter) and
[devices](#device) have
[capabilities], which describe WebGPU functionality that differs between
different implementations, typically due to hardware or system software
constraints. A [capability](#capabilities) is either a [feature](#feature) or a [limit](#limit).

A user agent must not reveal more than 32 distinguishable configurations
or buckets.

The capabilities of an [adapter](#adapter) must conform to [§ 4.2.1 Adapter Capability
Guarantees](#adapter-capability-guarantees).

Only supported capabilities may be requested in
[`requestDevice()`](#dom-gpuadapter-requestdevice); requesting unsupported capabilities results in
failure.

The capabilities of a [device](#device) are determined in \"[a new
device](#a-new-device)\" by
starting with the adapter's defaults (no features and the default
[supported limits](#supported-limits)) and adding capabilities as requested in
[`requestDevice()`](#dom-gpuadapter-requestdevice). These capabilities are enforced regardless of the
capabilities of the [adapter](#adapter).

[!(data:image/svg+xml;base64,PHN2ZyBhcmlhLWxhYmVsPSIoVGhpcyBpcyBhIHRyYWNraW5nIHZlY3Rvci4pIiBjbGFzcz0iZGFya21vZGUtYXdhcmUiIGhlaWdodD0iNjQiIHJvbGU9ImltZyIgd2lkdGg9IjQ2Ij48dGl0bGU+VGhlcmUgaXMgYSB0cmFja2luZyB2ZWN0b3IgaGVyZS48L3RpdGxlPjx1c2UgaHJlZj0iI2I3MzJiM2ZlIiAvPjwvc3ZnPg==)](https://infra.spec.whatwg.org/#tracking-vector) For privacy considerations, see [§ 2.2.1
Machine-specific features and limits](#privacy-machine-limits).

#### 3.6.1. Features

A [feature] is a
set of optional WebGPU functionality that is not supported on all
implementations, typically due to hardware or system software
constraints.

All [features](#feature) are
optional, but [adapters](#adapter)
make some guarantees about their availability (see [§ 4.2.1 Adapter
Capability Guarantees](#adapter-capability-guarantees)).

A [device](#device) supports the
exact set of features determined at creation (see [§ 3.6 Optional
Capabilities](#optional-capabilities)). API calls perform validation
according to these features (not the
[adapter](#adapter)'s features):

- Using existing API surfaces in a new way **typically** results in a
 [validation
 error](#abstract-opdef-generate-a-validation-error).

- There are several types of [optional API
 surface]:

 - Using a new method or enum value always throws a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 - Using a new dictionary member with a (correctly-typed) non-default
 value **typically** results in a [validation
 error](#abstract-opdef-generate-a-validation-error).

 - Using a new WGSL `enable` directive always results in a
 [`createShaderModule()`](#dom-gpudevice-createshadermodule) [validation
 error](#abstract-opdef-generate-a-validation-error).

A [`GPUFeatureName`](#gpufeaturename) `feature` is [enabled for] a
[`GPUObjectBase`](#gpuobjectbase) `object` if and only if
`object`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot)
[contains](https://infra.spec.whatwg.org/#list-contain) `feature`.

See the [Feature Index](#feature-index) for a description of the
functionality each feature enables.

 Even where supported, enabling features is not
necessarily desirable, as doing so may have a performance impact.
Because of this, and to improve portability across devices and
implementations, applications should generally only request features
that they may actually require.

#### 3.6.2. Limits

Each [limit] is a
numeric limit on the usage of WebGPU on a device.

 Even where supported, setting \"better\" limits is not
necessarily desirable, as doing so may have a performance impact.
Because of this, and to improve portability across devices and
implementations, applications should generally only request limits
better than the defaults if they may actually require them.

Each limit has a [default] value and a [compatibility
mode default].

[Adapters](#adapter) are always
guaranteed to support the defaults or
[better](#limit-better) (see
[§ 4.2.1 Adapter Capability
Guarantees](#adapter-capability-guarantees)).

A [device](#device) supports the
exact set of limits determined at creation (see [§ 3.6 Optional
Capabilities](#optional-capabilities)). API calls perform validation
according to these limits (not the
[adapter](#adapter)'s limits), no
[better](#limit-better) or
worse.

For any given limit, some values are [better] than others. A
[better](#limit-better) limit
value always relaxes validation, enabling strictly more programs to be
valid. For each [limit class](#limit-class), \"better\" is defined.

Different limits have different [limit classes]:

[maximum]

: The limit enforces a maximum on some value passed into the API.

 Higher values are [better](#limit-better).

 May only be set to values ≥ the
 [default](#limit-default).
 Lower values are clamped to the
 [default](#limit-default).

[alignment]

: The limit enforces a minimum alignment on some value passed into the
 API; that is, the value must be a multiple of the limit.

 Lower values are [better](#limit-better).

 May only be set to powers of 2 which are ≤ the
 [default](#limit-default).
 Values which are not powers of 2 are invalid. Higher powers of 2 are
 clamped to the [default](#limit-default).

A [supported limits] object has a value for every limit defined by WebGPU:

Limit name

Type

[Limit class](#limit-class)

[Default](#limit-default)

[Compatibility Mode
Default](#limit-compatibility-mode-default)

[`maxTextureDimension1D`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8192

4096

The maximum allowed value for the
[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) of a [texture](#texture) created with
[`dimension`](#dom-gputexturedescriptor-dimension)
[`"1d"`](#dom-gputexturedimension-1d).

[`maxTextureDimension2D`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8192

4096

The maximum allowed value for the
[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) and
[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) of a [texture](#texture) created with
[`dimension`](#dom-gputexturedescriptor-dimension)
[`"2d"`](#dom-gputexturedimension-2d).

[`maxTextureDimension3D`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

2048

The maximum allowed value for the
[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width),
[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) and
[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) of a [texture](#texture) created with
[`dimension`](#dom-gputexturedescriptor-dimension)
[`"3d"`](#dom-gputexturedimension-3d).

[`maxTextureArrayLayers`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

256

The maximum allowed value for the
[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) of a [texture](#texture) created with
[`dimension`](#dom-gputexturedescriptor-dimension)
[`"2d"`](#dom-gputexturedimension-2d).

[`maxBindGroups`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

4

The maximum number of
[`GPUBindGroupLayouts`](#gpubindgrouplayout) allowed in
[`bindGroupLayouts`](#dom-gpupipelinelayoutdescriptor-bindgrouplayouts) when creating a
[`GPUPipelineLayout`](#gpupipelinelayout).

[`maxBindGroupsPlusVertexBuffers`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

24

The maximum number of bind group and vertex buffer slots used
simultaneously, counting any empty slots below the highest index.
Validated in
[`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline) and [in draw
calls](#abstract-opdef-valid-to-draw).

[`maxBindingsPerBindGroup`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

1000

The number of binding indices available when creating a
[`GPUBindGroupLayout`](#gpubindgrouplayout).

 This limit is normative, but arbitrary. With the
default [binding slot
limits](#exceeds-the-binding-slot-limits), it is impossible to use 1000 bindings in one bind
group, but this allows
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry).[`binding`](#dom-gpubindgrouplayoutentry-binding) values up to 999. This limit allows implementations to
treat binding space as an array, within reasonable memory space, rather
than a sparse map structure.

[`maxDynamicUniformBuffersPerPipelineLayout`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

The maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are uniform buffers with dynamic offsets. See
[Exceeds the binding slot
limits](#exceeds-the-binding-slot-limits).

[`maxDynamicStorageBuffersPerPipelineLayout`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

4

The maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage buffers with dynamic offsets. See
[Exceeds the binding slot
limits](#exceeds-the-binding-slot-limits).

[`maxSampledTexturesPerShaderStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

16

For each possible
[`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are sampled textures. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

[`maxSamplersPerShaderStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

16

For each possible
[`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are samplers. See [Exceeds the binding slot
limits](#exceeds-the-binding-slot-limits).

[`maxStorageBuffersPerShaderStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

For each possible
[`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage buffers. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

 This limit applies to all stages. At [device
initialization](#a-new-device),
it is normalized with
[`maxStorageBuffersInVertexStage`](#dom-supported-limits-maxstoragebuffersinvertexstage) and
[`maxStorageBuffersInFragmentStage`](#dom-supported-limits-maxstoragebuffersinfragmentstage) so that in the validation algorithm, each stage can be
checked against just one of the three limits.

[`maxStorageBuffersInVertexStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

0

For the vertex stage, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage buffers. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

[`maxStorageBuffersInFragmentStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

4

For the fragment stage, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage buffers. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

[`maxStorageTexturesPerShaderStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

4

For each possible
[`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage textures. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

 This limit applies to all stages. At [device
initialization](#a-new-device),
it is normalized with
[`maxStorageTexturesInVertexStage`](#dom-supported-limits-maxstoragetexturesinvertexstage) and
[`maxStorageTexturesInFragmentStage`](#dom-supported-limits-maxstoragetexturesinfragmentstage) so that in the validation algorithm, each stage can be
checked against just one of the three limits.

[`maxStorageTexturesInVertexStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

0

For the vertex stage, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage textures. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

[`maxStorageTexturesInFragmentStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

4

For the fragment stage, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are storage textures. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

[`maxUniformBuffersPerShaderStage`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

12

For each possible
[`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`, the maximum number of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) entries across a
[`GPUPipelineLayout`](#gpupipelinelayout) which are uniform buffers. See [Exceeds the binding
slot
limits](#exceeds-the-binding-slot-limits).

[`maxUniformBufferBindingSize`]

[`GPUSize64`](#typedefdef-gpusize64)

[maximum](#limit-class-maximum)

65536 bytes

16384 bytes

The maximum
[`GPUBufferBinding`](#dictdef-gpubufferbinding).[`size`](#dom-gpubufferbinding-size) for bindings with a
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` for which
`entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is
[`"uniform"`](#dom-gpubufferbindingtype-uniform).

[`maxStorageBufferBindingSize`]

[`GPUSize64`](#typedefdef-gpusize64)

[maximum](#limit-class-maximum)

134217728 bytes (128 MiB)

The maximum
[`GPUBufferBinding`](#dictdef-gpubufferbinding).[`size`](#dom-gpubufferbinding-size) for bindings with a
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` for which
`entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is
[`"storage"`](#dom-gpubufferbindingtype-storage) or
[`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage).

[`minUniformBufferOffsetAlignment`]

[`GPUSize32`](#typedefdef-gpusize32)

[alignment](#limit-class-alignment)

256 bytes

The required alignment for
[`GPUBufferBinding`](#dictdef-gpubufferbinding).[`offset`](#dom-gpubufferbinding-offset) and the dynamic offsets provided in
[setBindGroup()](#gpubindingcommandsmixin-setbindgroup), for bindings with a
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` for which
`entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is
[`"uniform"`](#dom-gpubufferbindingtype-uniform).

[`minStorageBufferOffsetAlignment`]

[`GPUSize32`](#typedefdef-gpusize32)

[alignment](#limit-class-alignment)

256 bytes

The required alignment for
[`GPUBufferBinding`](#dictdef-gpubufferbinding).[`offset`](#dom-gpubufferbinding-offset) and the dynamic offsets provided in
[setBindGroup()](#gpubindingcommandsmixin-setbindgroup), for bindings with a
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` for which
`entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is
[`"storage"`](#dom-gpubufferbindingtype-storage) or
[`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage).

[`maxVertexBuffers`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

The maximum number of
[`buffers`](#dom-gpuvertexstate-buffers) when creating a
[`GPURenderPipeline`](#gpurenderpipeline).

[`maxBufferSize`]

[`GPUSize64`](#typedefdef-gpusize64)

[maximum](#limit-class-maximum)

268435456 bytes (256 MiB)

The maximum size of
[`size`](#dom-gpubufferdescriptor-size) when creating a
[`GPUBuffer`](#gpubuffer).

[`maxVertexAttributes`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

16

The maximum number of
[`attributes`](#dom-gpuvertexbufferlayout-attributes) in total across
[`buffers`](#dom-gpuvertexstate-buffers) when creating a
[`GPURenderPipeline`](#gpurenderpipeline).

[`maxVertexBufferArrayStride`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

2048 bytes

The maximum allowed
[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) when creating a
[`GPURenderPipeline`](#gpurenderpipeline).

[`maxInterStageShaderVariables`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

16

15

The maximum allowed number of input or output variables for inter-stage
communication (like vertex outputs or fragment inputs).

[`maxColorAttachments`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

8

4

The maximum allowed number of color attachments in
[`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor).[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets),
[`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor).[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments), and
[`GPURenderPassLayout`](#dictdef-gpurenderpasslayout).[`colorFormats`](#dom-gpurenderpasslayout-colorformats).

[`maxColorAttachmentBytesPerSample`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

32

The maximum number of bytes necessary to hold one sample (pixel or
subpixel) of render pipeline output data, across all color attachments.

[`maxComputeWorkgroupStorageSize`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

16384 bytes

The maximum number of bytes of
[workgroup](https://gpuweb.github.io/gpuweb/wgsl/#address-spaces-workgroup) storage used for a compute stage
[`GPUShaderModule`](#gpushadermodule) entry-point.

[`maxComputeInvocationsPerWorkgroup`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

256

128

The maximum value of the product of the `workgroup_size` dimensions for
a compute stage
[`GPUShaderModule`](#gpushadermodule) entry-point.

[`maxComputeWorkgroupSizeX`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

256

128

The maximum value of the `workgroup_size` X dimension for a compute
stage
[`GPUShaderModule`](#gpushadermodule) entry-point.

[`maxComputeWorkgroupSizeY`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

256

128

The maximum value of the `workgroup_size` Y dimensions for a compute
stage
[`GPUShaderModule`](#gpushadermodule) entry-point.

[`maxComputeWorkgroupSizeZ`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

64

The maximum value of the `workgroup_size` Z dimensions for a compute
stage
[`GPUShaderModule`](#gpushadermodule) entry-point.

[`maxComputeWorkgroupsPerDimension`]

[`GPUSize32`](#typedefdef-gpusize32)

[maximum](#limit-class-maximum)

65535

The maximum value for the arguments of
[`dispatchWorkgroups(workgroupCountX, workgroupCountY, workgroupCountZ)`](#dom-gpucomputepassencoder-dispatchworkgroups).

##### 3.6.2.1. `GPUSupportedLimits`

[`GPUSupportedLimits`](#gpusupportedlimits) exposes an adapter or device's [supported
limits](#supported-limits).
See
[`GPUAdapter.limits`](#dom-gpuadapter-limits) and
[`GPUDevice.limits`](#dom-gpudevice-limits).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUSupportedLimits {
 readonly attribute unsigned long maxTextureDimension1D;
 readonly attribute unsigned long maxTextureDimension2D;
 readonly attribute unsigned long maxTextureDimension3D;
 readonly attribute unsigned long maxTextureArrayLayers;
 readonly attribute unsigned long maxBindGroups;
 readonly attribute unsigned long maxBindGroupsPlusVertexBuffers;
 readonly attribute unsigned long maxBindingsPerBindGroup;
 readonly attribute unsigned long maxDynamicUniformBuffersPerPipelineLayout;
 readonly attribute unsigned long maxDynamicStorageBuffersPerPipelineLayout;
 readonly attribute unsigned long maxSampledTexturesPerShaderStage;
 readonly attribute unsigned long maxSamplersPerShaderStage;
 readonly attribute unsigned long maxStorageBuffersPerShaderStage;
 readonly attribute unsigned long maxStorageBuffersInVertexStage;
 readonly attribute unsigned long maxStorageBuffersInFragmentStage;
 readonly attribute unsigned long maxStorageTexturesPerShaderStage;
 readonly attribute unsigned long maxStorageTexturesInVertexStage;
 readonly attribute unsigned long maxStorageTexturesInFragmentStage;
 readonly attribute unsigned long maxUniformBuffersPerShaderStage;
 readonly attribute unsigned long long maxUniformBufferBindingSize;
 readonly attribute unsigned long long maxStorageBufferBindingSize;
 readonly attribute unsigned long minUniformBufferOffsetAlignment;
 readonly attribute unsigned long minStorageBufferOffsetAlignment;
 readonly attribute unsigned long maxVertexBuffers;
 readonly attribute unsigned long long maxBufferSize;
 readonly attribute unsigned long maxVertexAttributes;
 readonly attribute unsigned long maxVertexBufferArrayStride;
 readonly attribute unsigned long maxInterStageShaderVariables;
 readonly attribute unsigned long maxColorAttachments;
 readonly attribute unsigned long maxColorAttachmentBytesPerSample;
 readonly attribute unsigned long maxComputeWorkgroupStorageSize;
 readonly attribute unsigned long maxComputeInvocationsPerWorkgroup;
 readonly attribute unsigned long maxComputeWorkgroupSizeX;
 readonly attribute unsigned long maxComputeWorkgroupSizeY;
 readonly attribute unsigned long maxComputeWorkgroupSizeZ;
 readonly attribute unsigned long maxComputeWorkgroupsPerDimension;
};
```

##### 3.6.2.2. `GPUSupportedFeatures`

[`GPUSupportedFeatures`](#gpusupportedfeatures) is a
[setlike](https://webidl.spec.whatwg.org/#dfn-setlike) interface. Its [set
entries](https://webidl.spec.whatwg.org/#dfn-set-entries) are the
[`GPUFeatureName`](#gpufeaturename) values of the [features](#feature) supported by an adapter or device. It must only contain
strings from the
[`GPUFeatureName`](#gpufeaturename) enum.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUSupportedFeatures {
 readonly setlike<DOMString>;
};
```

NOTE:

The type of the
[`GPUSupportedFeatures`](#gpusupportedfeatures) [set
entries](https://webidl.spec.whatwg.org/#dfn-set-entries) is
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) to allow user agents to gracefully handle valid
[`GPUFeatureName`](#gpufeaturename)s which are added in later revisions of the spec but
which the user agent has not been updated to recognize yet. If the [set
entries](https://webidl.spec.whatwg.org/#dfn-set-entries) type was
[`GPUFeatureName`](#gpufeaturename) the following code would throw an
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) rather than reporting `false`:

Check for support of an unrecognized
feature:

``` highlight
if (adapter.features.has('unknown-feature')) {
 // Use unknown-feature
} else {
 console.warn('unknown-feature is not supported by this adapter.');
}
```

##### 3.6.2.3. `WGSLLanguageFeatures`

[`WGSLLanguageFeatures`](#gpuwgsllanguagefeatures) is the
[setlike](https://webidl.spec.whatwg.org/#dfn-setlike) interface of
`navigator.gpu.`[`wgslLanguageFeatures`](#dom-gpu-wgsllanguagefeatures). Its [set
entries](https://webidl.spec.whatwg.org/#dfn-set-entries) are the string names of the WGSL [language
extensions](https://gpuweb.github.io/gpuweb/wgsl/#language-extension) supported by the implementation (regardless of the
adapter or device).

```
[Exposed=(Window, Worker), SecureContext]
interface WGSLLanguageFeatures {
 readonly setlike<DOMString>;
};
```

##### 3.6.2.4. `GPUAdapterInfo`

[`GPUAdapterInfo`](#gpuadapterinfo) exposes various identifying information about an
adapter.

None of the members in
[`GPUAdapterInfo`](#gpuadapterinfo) are guaranteed to be populated with any particular
value; if no value is provided, the attribute will return the empty
string `""`. It is at the user agent's discretion which values to
reveal, and it is likely that on some devices none of the values will be
populated. As such, applications **must** be able to handle any possible
[`GPUAdapterInfo`](#gpuadapterinfo) values, including the absence of those values.

The [`GPUAdapterInfo`](#gpuadapterinfo) for an adapter is exposed via
[`GPUAdapter.info`](#dom-gpuadapter-info) and
[`GPUDevice.adapterInfo`](#dom-gpudevice-adapterinfo)). This info is immutable: for a given adapter, each
[`GPUAdapterInfo`](#gpuadapterinfo) attribute will return the same value every time it's
accessed.

 Though the
[`GPUAdapterInfo`](#gpuadapterinfo) attributes are immutable *once accessed*, an
implementation may delay the decision on what to expose for each
attribute until the first time it is accessed.

 Other
[`GPUAdapter`](#gpuadapter)
instances, even if they represent the same physical adapter, may expose
different values in
[`GPUAdapterInfo`](#gpuadapterinfo). However, they **should** expose the same values unless
a specific event has increased the amount of identifying information the
page is allowed to access. (No such events are defined by this
specification.)

[!(data:image/svg+xml;base64,PHN2ZyBhcmlhLWxhYmVsPSIoVGhpcyBpcyBhIHRyYWNraW5nIHZlY3Rvci4pIiBjbGFzcz0iZGFya21vZGUtYXdhcmUiIGhlaWdodD0iNjQiIHJvbGU9ImltZyIgd2lkdGg9IjQ2Ij48dGl0bGU+VGhlcmUgaXMgYSB0cmFja2luZyB2ZWN0b3IgaGVyZS48L3RpdGxlPjx1c2UgaHJlZj0iI2I3MzJiM2ZlIiAvPjwvc3ZnPg==)](https://infra.spec.whatwg.org/#tracking-vector) For privacy considerations, see [§ 2.2.6
Adapter Identifiers](#privacy-adapter-identifiers).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUAdapterInfo {
 readonly attribute DOMString vendor;
 readonly attribute DOMString architecture;
 readonly attribute DOMString device;
 readonly attribute DOMString description;
 readonly attribute unsigned long subgroupMinSize;
 readonly attribute unsigned long subgroupMaxSize;
 readonly attribute boolean isFallbackAdapter;
};
```

[`GPUAdapterInfo`](#gpuadapterinfo) has the following attributes:

[`vendor`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: The name of the vendor of the [adapter](#adapter), if available. Empty string otherwise.

[`architecture`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: The name of the family or class of GPUs the
 [adapter](#adapter) belongs to,
 if available. Empty string otherwise.

[`device`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: A vendor-specific identifier for the
 [adapter](#adapter), if
 available. Empty string otherwise.

 This is a value that represents the type of
 adapter. For example, it may be a [PCI device
 ID](https://pcisig.com/). It does not uniquely identify a given
 piece of hardware like a serial number.

[`description`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: A human readable string describing the
 [adapter](#adapter) as reported
 by the driver, if available. Empty string otherwise.

 Because no formatting is applied to
 [`description`](#dom-gpuadapterinfo-description) attempting to parse this value is not recommended.
 Applications which change their behavior based on the
 [`GPUAdapterInfo`](#gpuadapterinfo), such as applying workarounds for known driver
 issues, should rely on the other fields when possible.

[`subgroupMinSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: If the [`"subgroups"`](#subgroups) feature is supported, the minimum supported
 [subgroup
 size](https://gpuweb.github.io/gpuweb/wgsl/#subgroup-size) for the [adapter](#adapter).

[`subgroupMaxSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: If the [`"subgroups"`](#subgroups) feature is supported, the maximum supported
 [subgroup
 size](https://gpuweb.github.io/gpuweb/wgsl/#subgroup-size) for the [adapter](#adapter).

[`isFallbackAdapter`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Whether the [adapter](#adapter)
 is a [fallback
 adapter](#fallback-adapter).

To create a [new adapter info] for a given
[adapter](#adapter)
`adapter`, run the following [content
timeline](#content-timeline) steps:

1. Let `adapterInfo` be a new
 [`GPUAdapterInfo`](#gpuadapterinfo).

2. If the vendor is known, set
 `adapterInfo`.[`vendor`](#dom-gpuadapterinfo-vendor) to the name of `adapter`'s vendor as a
 [normalized identifier
 string](#normalized-identifier-string). To preserve privacy, the user agent may instead
 set
 `adapterInfo`.[`vendor`](#dom-gpuadapterinfo-vendor) to the empty string or a reasonable approximation
 of the vendor as a [normalized identifier
 string](#normalized-identifier-string).

3. If \|the architecture is known, set
 `adapterInfo`.[`architecture`](#dom-gpuadapterinfo-architecture) to a [normalized identifier
 string](#normalized-identifier-string) representing the family or class of adapters to
 which `adapter` belongs. To preserve privacy, the user
 agent may instead set
 `adapterInfo`.[`architecture`](#dom-gpuadapterinfo-architecture) to the empty string or a reasonable approximation
 of the architecture as a [normalized identifier
 string](#normalized-identifier-string).

4. If the device is known, set
 `adapterInfo`.[`device`](#dom-gpuadapterinfo-device) to a [normalized identifier
 string](#normalized-identifier-string) representing a vendor-specific identifier for
 `adapter`. To preserve privacy, the user agent may
 instead set
 `adapterInfo`.[`device`](#dom-gpuadapterinfo-device) to to the empty string or a reasonable
 approximation of a vendor-specific identifier as a [normalized
 identifier
 string](#normalized-identifier-string).

5. If a description is known, set
 `adapterInfo`.[`description`](#dom-gpuadapterinfo-description) to a description of the `adapter` as
 reported by the driver. To preserve privacy, the user agent may
 instead set
 `adapterInfo`.[`description`](#dom-gpuadapterinfo-description) to the empty string or a reasonable approximation
 of a description.

6. If [`"subgroups"`](#subgroups) is supported, set
 [`subgroupMinSize`](#dom-gpuadapterinfo-subgroupminsize) to the smallest supported subgroup size. Otherwise,
 set this value to 4.

 To preserve privacy, the user agent may choose to
 not support some features or provide values for the property which
 do not distinguish different devices, but are still usable (e.g. use
 the default value of 4 for all devices).

7. If [`"subgroups"`](#subgroups) is supported, set
 [`subgroupMaxSize`](#dom-gpuadapterinfo-subgroupmaxsize) to the largest supported subgroup size. Otherwise,
 set this value to 128.

 To preserve privacy, the user agent may choose to
 not support some features or provide values for the property which
 do not distinguish different devices, but are still usable (e.g. use
 the default value of 128 for all devices).

8. Set
 `adapterInfo`.[`isFallbackAdapter`](#dom-gpuadapterinfo-isfallbackadapter) to
 `adapter`.[`[[fallback]]`](#dom-adapter-fallback-slot).

9. Return `adapterInfo`.

A [normalized identifier string] is one that follows the
following pattern:

`[a-z0-9]+(-[a-z0-9]+)*`

!(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMDEiIHZpZXdib3g9IjAgMCAyMTkuNSAxMDEiIHdpZHRoPSIyMTkuNSI+CiAgICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKC41IC41KSI+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICA8L2c+CiAgICAgICA8cGF0aCBkPSJNNDAgMzFoMTAiIC8+CiAgICAgICA8Zz4KICAgICAgICA8cGF0aCBkPSJNNTAgMzFoMC4wIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0xNjkuNSAzMWgwLjAiIC8+CiAgICAgICAgPHBhdGggZD0iTTUwLjAgMzFoMTAiIC8+CiAgICAgICAgPGc+CiAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE1OS41IDMxaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTYwLjAgMzFoMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCAiPgogICAgICAgICAgPHBhdGggZD0iTTcwLjAgMzFoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTE0OS41IDMxaDAuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iNzkuNSIgeD0iNzAiIHk9IjIwIiAvPgogICAgICAgICAgPHRleHQgeD0iMTA5Ljc1IiB5PSIzNSI+YS16IDAtOTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTQ5LjUgMzFoMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDMxYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDUxaDc5LjUiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTE0OS41IDUxYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0xNTkuNSAzMWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNNjAuMCAzMWExMCAxMCAwIDAgMCAtMTAgMTB2MTlhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsICI+CiAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDcwaDM1LjUiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMjQuMCA3MGgzNS41IiAvPgogICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9Ijk1LjUiIHk9IjU5IiAvPgogICAgICAgICA8dGV4dCB4PSIxMDkuNzUiIHk9Ijc0Ij4tPC90ZXh0PgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNMTU5LjUgNzBhMTAgMTAgMCAwIDAgMTAgLTEwdi0xOWExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgPC9nPgogICAgICAgPHBhdGggZD0iTTE2OS41IDMxaDEwIiAvPgogICAgICAgPHBhdGggZD0iTSAxNzkuNSAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgIDwvZz4KICAgICA8L3N2Zz4=)

Examples of valid normalized
identifier strings include:

- `gpu`

- `3d`

- `0x3b2f`

- `next-gen`

- `series-x20-ultra`

### 3.7. Feature Detection

*This section is non-normative.*

Fully implementing this specification requires implementation of
everything it specifies, except where otherwise stated (like [§ 3.6
Optional Capabilities](#optional-capabilities)).

However, since new \"core\" additions are added to this specification
before being exposed by implementations, many features are designed to
be feature-detectable by applications:

- Interface support can be detected with
 `typeof InterfaceName !== 'undefined'`.

- Method and attribute support can be detected with
 `'itemName' in InterfaceName.prototype`.

- New dictionary members, if they need to be detectable, generally
 document a specific mechanism for feature detection. For example:

 - [`unclippedDepth`](#dom-gpuprimitivestate-unclippeddepth) support is part of a device feature,
 [`"depth-clip-control"`](#depth-clip-control).

 - Canvas support for
 [`toneMapping`](#dom-gpucanvasconfiguration-tonemapping) is detected using
 [`getConfiguration()`](#dom-gpucanvascontext-getconfiguration).

### 3.8. Extension Documents

\"Extension Documents\" are additional documents which describe new
functionality which is non-normative and **not part of the WebGPU/WGSL
specifications**. They describe functionality that builds upon these
specifications, often including one or more new API
[feature](#feature) flags and/or WGSL
`enable` directives, or interactions with other draft web
specifications.

WebGPU implementations **must not** expose extension functionality;
doing so is a spec violation. New functionality does not become part of
the WebGPU standard until it is integrated into the WebGPU specification
(this document) and/or WGSL specification.

### 3.9. Origin Restrictions

WebGPU allows accessing image data stored in images, videos, and
canvases. Restrictions are imposed on the use of cross-domain media,
because shaders can be used to indirectly deduce the contents of
textures which have been uploaded to the GPU.

WebGPU disallows uploading an image source if it [is not
origin-clean](https://html.spec.whatwg.org/multipage/canvas.html#the-image-argument-is-not-origin-clean).

This also implies that the
[origin-clean](https://html.spec.whatwg.org/multipage/canvas.html#concept-canvas-origin-clean) flag for a canvas rendered using WebGPU will never be
set to `false`.

For more information on issuing CORS requests for image and video
elements, consult:

- [HTML § 2.5.4 CORS settings
 attributes](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-settings-attributes)

- [HTML § 4.8.3 The img
 element](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element)
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element)

- [HTML § 4.8.11 Media
 elements](https://html.spec.whatwg.org/multipage/media.html#media-elements)
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)

### 3.10. Task Sources

#### 3.10.1. WebGPU Task Source

WebGPU defines a new [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) called the [WebGPU task source]. It is used for the
[`uncapturederror`](#eventdef-gpudevice-uncapturederror) event and
[`GPUDevice`](#gpudevice).[`lost`](#dom-gpudevice-lost).

To [queue a global task for
[`GPUDevice`](#gpudevice)] `device`, with
a series of steps `steps` on the [content
timeline](#content-timeline):

1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [WebGPU task
 source](#webgpu-task-source), with the global object that was used to create
 `device`, and the steps `steps`.

#### 3.10.2. Automatic Expiry Task Source

WebGPU defines a new [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) called the [automatic expiry task
source](#automatic-expiry-task-source). It is used for the automatic, timed expiry
(destruction) of certain objects:

- [`GPUTexture`](#gputexture)s returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture)

- [`GPUExternalTexture`](#gpuexternaltexture)s created from
 [`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement)s

To [queue an automatic expiry
task] with
[`GPUDevice`](#gpudevice)
`device` and a series of steps `steps` on the
[content timeline](#content-timeline):

1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [automatic expiry task
 source](#automatic-expiry-task-source), with the global object that was used to create
 `device`, and the steps `steps`.

Tasks from the [automatic expiry task
source](#automatic-expiry-task-source) **should** be processed with high priority; in
particular, once queued, they **should** run before user-defined
(JavaScript) tasks.

NOTE:

This behavior is more predictable, and the strictness helps developers
write more portable applications by eagerly detecting incorrect
assumptions about implicit lifetimes that may be hard to detect.
Developers are still strongly encouraged to test in multiple
implementations.

Implementation note: It is valid to implement a high-priority expiry
\"task\" by instead inserting additional steps at a fixed point inside
the [event loop processing
model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model) rather than running an actual task.

### 3.11. Color Spaces and Encoding

WebGPU does not provide color management. All values within WebGPU (such
as texture elements) are raw numeric values, not color-managed color
values.

WebGPU *does* interface with color-managed outputs (via
[`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration)) and inputs (via
[`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture) and
[`importExternalTexture()`](#dom-gpudevice-importexternaltexture)). Thus, color conversion must be performed between the
WebGPU numeric values and the external color values. Each such interface
point locally defines an encoding (color space, transfer function, and
alpha premultiplication) in which the WebGPU numeric values are to be
interpreted.

WebGPU allows all of the color spaces in the
[`PredefinedColorSpace`](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace) enum. Note, each color space is defined over an
extended range, as defined by the referenced CSS definitions, to
represent color values outside of its space (in both chrominance and
luminance).

NOTE:

As described above,
[`GPUTexture`](#gputexture)s
are not color managed. This includes `-srgb` formats, which despite
their are not *tagged* with an sRGB color space (like those described by
[`PredefinedColorSpace`](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace) and the CSS color spaces
[srgb](https://drafts.csswg.org/css-color-4/#valdef-color-srgb) and
[srgb-linear](https://drafts.csswg.org/css-color-4/#valdef-color-srgb-linear)).

However, `-srgb` texture formats *do* have gamma-encoding/decoding
properties which are algorithmically close to those used for gamma
encoding in
[`"srgb"`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-srgb) and
[`"display-p3"`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-display-p3). For example, a fragment shader can output an
\"sRGB-linear\"-encoded (physically linear) color value into an `-srgb`
format texture, which will gamma-encode the value when it is written.
Then, the value in the texture will be correctly encoded for use on a
[`"srgb"`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-srgb)-tagged (approximately perceptually-linear) canvas.

It is similarly possible to take advantage of these properties using
[`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture); see its description for additional information.

An [out-of-gamut premultiplied RGBA
value] is one where any of the R/G/B channel values
exceeds the alpha channel value. For example, the premultiplied sRGB
RGBA value \[1.0, 0, 0, 0.5\] represents the (unpremultiplied) color
\[2, 0, 0\] with 50% alpha, written `rgb(srgb 2 0 0 / 50%)` in CSS. Just
like any color value outside the sRGB color gamut, this is a well
defined point in the extended color space (except when alpha is 0, in
which case there is no color). However, when such values are output to a
visible canvas, the result is undefined (see
[`GPUCanvasAlphaMode`](#gpucanvasalphamode)
[`"premultiplied"`](#dom-gpucanvasalphamode-premultiplied)).

#### 3.11.1. Color Space Conversions

A color is converted between spaces by translating its representation in
one space to a representation in another according to the definitions
above.

If the source value has fewer than 4 RGBA channels, the missing
green/blue/alpha channels are set to `0, 0, 1`, respectively, before
converting for color space/encoding and alpha premultiplication. After
conversion, if the destination needs fewer than 4 channels, the
additional channels are ignored.

 Grayscale images generally represent RGB values
`(V, V, V)`, or RGBA values `(V, V, V, A)` in their color space.

Colors are not lossily clamped during conversion: converting from one
color space to another will result in values outside the range \[0, 1\]
if the source color values were outside the range of the destination
color space's gamut. For an sRGB destination, for example, this can
occur if the source is rgba16float, in a wider color space like
Display-P3, or is premultiplied and contains [out-of-gamut
values](#out-of-gamut-premultiplied-rgba-value).

Similarly, if the source value has a high bit depth (e.g. PNG with 16
bits per component) or extended range (e.g. canvas with `float16`
storage), these colors are preserved through color space conversion,
with intermediate computations having at least the precision of the
source.

#### 3.11.2. Color Space Conversion Elision

If the source and destination of a color space/encoding conversion are
the same, then conversion is not necessary. In general, if any given
step of the conversion is an identity function (no-op), implementations
**should** elide it, for performance.

For optimal performance, applications **should** set their color space
and encoding options so that the number of necessary conversions is
minimized throughout the process. For various image sources of
[`GPUCopyExternalImageSourceInfo`](#gpucopyexternalimagesourceinfo):

- [`ImageBitmap`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap):

 - Premultiplication is controlled via
 [`premultiplyAlpha`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmapoptions-premultiplyalpha).

 - Color space is controlled via
 [`colorSpaceConversion`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmapoptions-colorspaceconversion).

- 2d canvas:

 - [Always
 premultiplied](https://html.spec.whatwg.org/multipage/canvas.html#premultiplied-alpha-and-the-2d-rendering-context).

 - Color space is controlled via the
 [`colorSpace`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvasrenderingcontext2dsettings-colorspace) context creation attribute.

- WebGL canvas:

 - Premultiplication is controlled via the `premultipliedAlpha` option
 in
 [`WebGLContextAttributes`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#WEBGLCONTEXTATTRIBUTES).

 - Color space is controlled via the
 [`WebGLRenderingContextBase`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#WEBGLRENDERINGCONTEXTBASE)'s
 [`drawingBufferColorSpace`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#DOM-WebGLRenderingContext-drawingBufferColorSpace) state.

 Check browser implementation support for these features
before relying on them.

### 3.12. Numeric conversions from JavaScript to WGSL

Several parts of the WebGPU API
([pipeline-overridable](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable)
[`constants`](#dom-gpuprogrammablestage-constants) and render pass clear values) take numeric values from
WebIDL
([`double`](https://webidl.spec.whatwg.org/#idl-double) or
[`float`](https://webidl.spec.whatwg.org/#idl-float)) and convert them to WGSL values (`bool`, `i32`, `u32`,
`f32`, `f16`).

To convert an IDL value `idlValue` of type
[`double`](https://webidl.spec.whatwg.org/#idl-double) or
[`float`](https://webidl.spec.whatwg.org/#idl-float) [to WGSL type] `T`, possibly
throwing a
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror), run the following [device
timeline](#device-timeline)
steps:

 This
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) is generated in the [device
timeline](#device-timeline)
and never surfaced to JavaScript.

1. [Assert](https://infra.spec.whatwg.org/#assert) `idlValue` is a finite value, since it
 is not
 [`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double) or
 [`unrestricted float`](https://webidl.spec.whatwg.org/#idl-unrestricted-float).

2. Let `v` be the ECMAScript Number resulting from
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting `idlValue` to [an ECMAScript
 value](https://webidl.spec.whatwg.org/#dfn-convert-idl-to-javascript-value).

3.

 If `T` is `bool`

 : Return the WGSL `bool` value corresponding to the result of
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting `v` to [an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) of type
 [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean).

 This algorithm is called after the conversion
 from an ECMAScript value to an IDL
 [`double`](https://webidl.spec.whatwg.org/#idl-double) or
 [`float`](https://webidl.spec.whatwg.org/#idl-float) value. If the original ECMAScript value was a
 non-numeric, non-boolean value like `` or ``, then the WGSL
 `bool` result may be different than if the ECMAScript value had
 been converted to IDL
 [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean) directly.

 If `T` is `i32`

 : Return the WGSL `i32` value corresponding to the result of
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting
 `v` to [an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) of type
 \[[`EnforceRange`](https://webidl.spec.whatwg.org/#EnforceRange)\]
 [`long`](https://webidl.spec.whatwg.org/#idl-long).

 If `T` is `u32`

 : Return the WGSL `u32` value corresponding to the result of
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting
 `v` to [an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) of type
 \[[`EnforceRange`](https://webidl.spec.whatwg.org/#EnforceRange)\]
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long).

 If `T` is `f32`

 : Return the WGSL `f32` value corresponding to the result of
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting
 `v` to [an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) of type
 [`float`](https://webidl.spec.whatwg.org/#idl-float).

 If `T` is `f16`

 : 1. Let `wgslF32` be the WGSL `f32` value
 corresponding to the result of
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting
 `v` to [an IDL
 value](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) of type
 [`float`](https://webidl.spec.whatwg.org/#idl-float).

 2. Return `f16(``wgslF32``)`, the result of
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converting the WGSL `f32` value to `f16` as
 defined in [WGSL floating point
 conversion](https://gpuweb.github.io/gpuweb/wgsl/#floating-point-conversion).

 As long as the value is in-range of `f32`, no
 error is thrown, even if the value is out-of-range of `f16`.

To convert a
[`GPUColor`](#typedefdef-gpucolor) `color` [to a texel value of texture
format] `format`,
possibly throwing a
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror), run the following [device
timeline](#device-timeline)
steps:

 This
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) is generated in the [device
timeline](#device-timeline)
and never surfaced to JavaScript.

1. If the components of `format`
 ([assert](https://infra.spec.whatwg.org/#assert) they all have the same type) are:

 floating-point types or normalized types

 : Let `T` be `f32`.

 signed integer types

 : Let `T` be `i32`.

 unsigned integer types

 : Let `T` be `u32`.

2. Let `wgslColor` be a WGSL value of type
 `vec4<``T``>`, where the 4 components are the RGBA
 channels of `color`, each
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) converted [to WGSL
 type](#abstract-opdef-to-wgsl-type) `T`.

3. Convert `wgslColor` to `format` using the same
 conversion rules as the [§ 23.2.7 Output Merging](#output-merging)
 step, and return the result.

 For non-integer types, the exact choice of value is
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). For normalized types, the value is clamped to the
 range of the type.

 In other words, the value written will be as if it was
written by a WGSL shader that outputs the value represented as a `vec4`
of `f32`, `i32`, or `u32`.

## 4. Initialization

### 4.1. navigator.gpu

A [`GPU`](#gpu) object is available
in the
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) and
[`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) contexts through the
[`Navigator`](https://html.spec.whatwg.org/multipage/system-state.html#navigator) and
[`WorkerNavigator`](https://html.spec.whatwg.org/multipage/workers.html#workernavigator) interfaces respectively and is exposed via
`navigator.gpu`:

```
interface mixin NavigatorGPU {
 [SameObject, SecureContext] readonly attribute GPU gpu;
};
Navigator includes NavigatorGPU;
WorkerNavigator includes NavigatorGPU;
```

[`NavigatorGPU`](#navigatorgpu) has the following attributes:

[`gpu`], of type [GPU](#gpu), readonly

: A global singleton providing top-level entry points like
 [`requestAdapter()`](#dom-gpu-requestadapter).

### 4.2. GPU

[`GPU`]
is the entry point to WebGPU.

```
[Exposed=(Window, Worker), SecureContext]
interface GPU {
 Promise<GPUAdapter?> requestAdapter(optional GPURequestAdapterOptions options = );
 GPUTextureFormat getPreferredCanvasFormat();
 [SameObject] readonly attribute WGSLLanguageFeatures wgslLanguageFeatures;
};
```

[`GPU`](#gpu) has the following
methods:

[`requestAdapter(options)`]

: Requests an [adapter](#adapter)
 from the user agent. The user agent chooses whether to return an
 adapter, and, if so, chooses according to the provided options.

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPU`](#gpu)
 `this`.
 **Arguments:**

 Arguments for the
 [GPU.requestAdapter(options)](#dom-gpu-requestadapter) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`options`]
 [`GPURequestAdapterOptions`](#dictdef-gpurequestadapteroptions)
 [✘]
 [✔]
 Criteria used to select the adapter.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`GPUAdapter`](#gpuadapter)?\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. All of the requirements in the following steps `must`
 be met.

 ::: validusage
 1. `options`.[`featureLevel`](#dom-gpurequestadapteroptions-featurelevel) `must` be a [feature level
 string](#feature-level-string).
 :::

 If any are unmet:

 1. Let `adapter` be `null`, issue the
 `resolution steps` on `contentTimeline`, and return.

 2. If
 `options`.[`featureLevel`](#dom-gpurequestadapteroptions-featurelevel) is
 [\"compatibility\"](#feature-level-string-compatibility):

 1. Set
 `options`.[`featureLevel`](#dom-gpurequestadapteroptions-featurelevel) to
 [\"compatibility\"](#feature-level-string-compatibility) if the user agent chooses to support it, or
 [\"core\"](#feature-level-string-core) if not.

 This doesn't modify the JavaScript object
 passed by the application.

 3. Set `adapter` to either:

 - A new [adapter](#adapter)
 object chosen according to the rules in [§ 4.2.2 Adapter
 Selection](#adapter-selection) and the criteria in
 `options`, adhering to [§ 4.2.1 Adapter Capability
 Guarantees](#adapter-capability-guarantees), with the
 capabilities determined in an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) way by the user agent.

 - `null`, if the user agent is unable to return an adapter, or
 makes an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) choice not to return an adapter.

 If an `adapter` is returned, initialize its
 properties according to their definitions.

 1. Set
 `adapter`.[`[[limits]]`](#dom-adapter-limits-slot) and
 `adapter`.[`[[features]]`](#dom-adapter-features-slot) according to the supported capabilities of
 the adapter.

 2. If `adapter` meets the criteria of a [fallback
 adapter](#fallback-adapter) set
 `adapter`.[`[[fallback]]`](#dom-adapter-fallback-slot) to `true`. Otherwise, set it to `false`.

 3. Set
 `adapter`.[`[[xrCompatible]]`](#dom-adapter-xrcompatible-slot) to
 `options`.[`xrCompatible`](#dom-gpurequestadapteroptions-xrcompatible).

 4. Set
 `adapter`.[`[[default feature level]]`](#dom-adapter-default-feature-level-slot) to
 `options`.[`featureLevel`](#dom-gpurequestadapteroptions-featurelevel).

 4. Issue the `resolution steps` on
 `contentTimeline`.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) `resolution steps`:
 1. If `adapter` is not `null`:

 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with a new
 [`GPUAdapter`](#gpuadapter) encapsulating `adapter`.

 Otherwise:

 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with `null`.
 :::
 ::::::

[`getPreferredCanvasFormat()`]

: Returns an optimal
 [`GPUTextureFormat`](#enumdef-gputextureformat) for displaying 8-bit depth, standard dynamic range
 content on this system. Must only return
 [`"rgba8unorm"`](#dom-gputextureformat-rgba8unorm) or
 [`"bgra8unorm"`](#dom-gputextureformat-bgra8unorm).

 The returned value can be passed as the
 [`format`](#dom-gpucanvasconfiguration-format) to
 [`configure()`](#dom-gpucanvascontext-configure) calls on a
 [`GPUCanvasContext`](#gpucanvascontext) to ensure the associated canvas is able to display
 its contents efficiently.

 Canvases which are not displayed to the screen may
 or may not benefit from using this format.

 ::::
 ::: {timeline="content"}
 **Called on:** [`GPU`](#gpu)
 this.
 **Returns:**
 [`GPUTextureFormat`](#enumdef-gputextureformat)

 [Content timeline](#content-timeline) steps:

 1. Return either
 [`"rgba8unorm"`](#dom-gputextureformat-rgba8unorm) or
 [`"bgra8unorm"`](#dom-gputextureformat-bgra8unorm), depending on which format is optimal for
 displaying WebGPU canvases on this system.
 :::
 ::::

[`GPU`](#gpu) has the following
attributes:

[`wgslLanguageFeatures`], of type [WGSLLanguageFeatures](#gpuwgsllanguagefeatures), readonly

: The names of supported WGSL [language
 extensions](https://gpuweb.github.io/gpuweb/wgsl/#language-extension). Supported language extensions are automatically
 enabled.

[Adapters](#adapter) **may**
[expire](#abstract-opdef-expire) at any time. Upon any change in the system's
state that could affect the result of any
[`requestAdapter()`](#dom-gpu-requestadapter) call, the user agent **should**
[expire](#abstract-opdef-expire) all previously-returned
[adapters](#adapter). For example:

- A physical adapter is added/removed (via plug/unplug, driver update,
 hang recovery, etc.)

- The system's power configuration has changed (laptop unplugged, power
 settings changed, etc.)

 User agents may choose to
[expire](#abstract-opdef-expire) [adapters](#adapter) often, even when there has been no system state change
(e.g. seconds or minutes after the adapter was created). This can help
obfuscate real system state changes, and make developers more aware that
calling
[`requestAdapter()`](#dom-gpu-requestadapter) again is always necessary before calling
[`requestDevice()`](#dom-gpuadapter-requestdevice). If an application does encounter this situation,
standard device-loss recovery handling should allow it to recover.

Requesting a
[`GPUAdapter`](#gpuadapter)
with no hints:

``` highlight
const gpuAdapter = await navigator.gpu.requestAdapter();
```

#### 4.2.1. Adapter Capability Guarantees

Any [`GPUAdapter`](#gpuadapter) returned by
[`requestAdapter()`](#dom-gpu-requestadapter) must provide the following guarantees:

- At least one of the following must be true:

 - [`"texture-compression-bc"`](#texture-compression-bc) is supported.

 - Both
 [`"texture-compression-etc2"`](#texture-compression-etc2) and
 [`"texture-compression-astc"`](#texture-compression-astc) are supported.

- If
 [`"texture-compression-bc-sliced-3d"`](#texture-compression-bc-sliced-3d) is supported, then
 [`"texture-compression-bc"`](#texture-compression-bc) must be supported.

- If
 [`"texture-compression-astc-sliced-3d"`](#texture-compression-astc-sliced-3d) is supported, then
 [`"texture-compression-astc"`](#texture-compression-astc) must be supported.

- All supported limits must be either the
 [default](#limit-default)
 value or [better](#limit-better).

- All
 [alignment-class](#limit-class-alignment) limits must be powers of 2.

- [`maxBindingsPerBindGroup`](#dom-supported-limits-maxbindingsperbindgroup) must be must be ≥ ([max bindings per shader
 stage](#max-bindings-per-shader-stage) × [max shader stages per
 pipeline](#max-shader-stages-per-pipeline)), where:

 - [max bindings per shader stage] is
 ([`maxSampledTexturesPerShaderStage`](#dom-supported-limits-maxsampledtexturespershaderstage) +
 [`maxSamplersPerShaderStage`](#dom-supported-limits-maxsamplerspershaderstage) +
 [`maxStorageBuffersPerShaderStage`](#dom-supported-limits-maxstoragebufferspershaderstage) +
 [`maxStorageTexturesPerShaderStage`](#dom-supported-limits-maxstoragetexturespershaderstage) +
 [`maxUniformBuffersPerShaderStage`](#dom-supported-limits-maxuniformbufferspershaderstage)).

 - [max shader stages per pipeline] is `2`,
 because a
 [`GPURenderPipeline`](#gpurenderpipeline) supports both a vertex and fragment shader.

 [`maxBindingsPerBindGroup`](#dom-supported-limits-maxbindingsperbindgroup) does not reflect a fundamental limit; implementations
 should raise it to conform to this requirement, rather than lowering
 the other limits.

- [`maxBindGroups`](#dom-supported-limits-maxbindgroups) must be ≤
 [`maxBindGroupsPlusVertexBuffers`](#dom-supported-limits-maxbindgroupsplusvertexbuffers).

- [`maxVertexBuffers`](#dom-supported-limits-maxvertexbuffers) must be ≤
 [`maxBindGroupsPlusVertexBuffers`](#dom-supported-limits-maxbindgroupsplusvertexbuffers).

- [`minUniformBufferOffsetAlignment`](#dom-supported-limits-minuniformbufferoffsetalignment) and
 [`minStorageBufferOffsetAlignment`](#dom-supported-limits-minstoragebufferoffsetalignment) must both be ≥ 32 bytes.

 32 bytes would be the alignment of `vec4<f64>`. See
 [WebGPU Shading Language § 14.4.1 Alignment and
 Size](https://gpuweb.github.io/gpuweb/wgsl/#alignment-and-size).

- [`maxUniformBufferBindingSize`](#dom-supported-limits-maxuniformbufferbindingsize) must be ≤
 [`maxBufferSize`](#dom-supported-limits-maxbuffersize).

- [`maxStorageBufferBindingSize`](#dom-supported-limits-maxstoragebufferbindingsize) must be ≤
 [`maxBufferSize`](#dom-supported-limits-maxbuffersize).

- [`maxStorageBufferBindingSize`](#dom-supported-limits-maxstoragebufferbindingsize) must be a multiple of 4 bytes.

- [`maxVertexBufferArrayStride`](#dom-supported-limits-maxvertexbufferarraystride) must be a multiple of 4 bytes.

- [`maxComputeWorkgroupSizeX`](#dom-supported-limits-maxcomputeworkgroupsizex) must be ≤
 [`maxComputeInvocationsPerWorkgroup`](#dom-supported-limits-maxcomputeinvocationsperworkgroup).

- [`maxComputeWorkgroupSizeY`](#dom-supported-limits-maxcomputeworkgroupsizey) must be ≤
 [`maxComputeInvocationsPerWorkgroup`](#dom-supported-limits-maxcomputeinvocationsperworkgroup).

- [`maxComputeWorkgroupSizeZ`](#dom-supported-limits-maxcomputeworkgroupsizez) must be ≤
 [`maxComputeInvocationsPerWorkgroup`](#dom-supported-limits-maxcomputeinvocationsperworkgroup).

- [`maxComputeInvocationsPerWorkgroup`](#dom-supported-limits-maxcomputeinvocationsperworkgroup) must be ≤
 [`maxComputeWorkgroupSizeX`](#dom-supported-limits-maxcomputeworkgroupsizex) ×
 [`maxComputeWorkgroupSizeY`](#dom-supported-limits-maxcomputeworkgroupsizey) ×
 [`maxComputeWorkgroupSizeZ`](#dom-supported-limits-maxcomputeworkgroupsizez).

#### 4.2.2. Adapter Selection

[`GPURequestAdapterOptions`] provides hints
to the user agent indicating what configuration is suitable for the
application.

```
dictionary GPURequestAdapterOptions {
 DOMString featureLevel = "core";
 GPUPowerPreference powerPreference;
 boolean forceFallbackAdapter = false;
 boolean xrCompatible = false;
};
```

```
enum GPUPowerPreference {
 "low-power",
 "high-performance",
};
```

[`GPURequestAdapterOptions`](#dictdef-gpurequestadapteroptions) has the following members:

[`featureLevel`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `"core"`

: Requests an adapter that supports at least a particular set of
 [capabilities](#capabilities). This influences the
 [`[[default feature level]]`](#dom-adapter-default-feature-level-slot) of devices created from this adapter. The
 capabilities for each level are defined below, and the exact steps
 are defined in
 [`requestAdapter()`](#dom-gpu-requestadapter) and \"[a new
 device](#a-new-device)\".

 If the implementation or system does not support all of the
 capabilities in the requested feature level,
 [`requestAdapter()`](#dom-gpu-requestadapter) will return `null`.

 Applications should typically make a single
 [`requestAdapter()`](#dom-gpu-requestadapter) call with the lowest feature level they support,
 then inspect the adapter for additional capabilities they can use
 optionally, and request those in
 [`requestDevice()`](#dom-gpuadapter-requestdevice).

 The allowed [feature level string] values are:

 [\"core\"]

 : The following set of capabilities:

 - The [Default](#limit-default) limits.

 - [`"core-features-and-limits"`](#core-features-and-limits).

 Adapters with this
 [`[[default feature level]]`](#dom-adapter-default-feature-level-slot) may conventionally be referred to as
 \"Core-defaulting\".

 [\"compatibility\"]

 : The following set of capabilities:

 - The [Compatibility Mode
 Default](#limit-compatibility-mode-default) limits.

 - No features. (It excludes the
 [`"core-features-and-limits"`](#core-features-and-limits) feature.)

 If the implementation cannot enforce the stricter
 \"Compatibility Mode\" validation rules,
 [`requestAdapter()`](#dom-gpu-requestadapter) will ignore this request and treat it as a
 request for
 [\"core\"](#feature-level-string-core).

 Adapters with this
 [`[[default feature level]]`](#dom-adapter-default-feature-level-slot) may conventionally be referred to as
 \"Compatibility-defaulting\".

[`powerPreference`], of type [GPUPowerPreference](#enumdef-gpupowerpreference)

: Optionally provides a hint indicating what class of
 [adapter](#adapter) should be
 selected from the system's available adapters.

 The value of this hint may influence which adapter is chosen, but it
 must not influence whether an adapter is returned or not.

 The primary utility of this hint is to influence
 which GPU is used in a multi-GPU system. For instance, some laptops
 have a low-power integrated GPU and a high-performance discrete GPU.
 This hint may also affect the power configuration of the selected
 GPU to match the requested power preference.

 Depending on the exact hardware configuration, such
 as battery status and attached displays or removable GPUs, the user
 agent may select different [adapters](#adapter) given the same power preference. Typically, given
 the same hardware configuration and state and `powerPreference`, the
 user agent is likely to select the same adapter.

 It must be one of the following values:

 `undefined` (or not present)

 : Provides no hint to the user agent.

 [`"low-power"`]

 : Indicates a request to prioritize power savings over
 performance.

 Generally, content should use this if it is
 unlikely to be constrained by drawing performance; for example,
 if it renders only one frame per second, draws only relatively
 simple geometry with simple shaders, or uses a small HTML canvas
 element. Developers are encouraged to use this value if their
 content allows, since it may significantly improve battery life
 on portable devices.

 [`"high-performance"`]

 : Indicates a request to prioritize performance over power
 consumption.

 By choosing this value, developers should be
 aware that, for [devices](#device) created on the resulting adapter, user agents
 are more likely to force device loss, in order to save power by
 switching to a lower-power adapter. Developers are encouraged to
 only specify this value if they believe it is absolutely
 necessary, since it may significantly decrease battery life on
 portable devices.

[`forceFallbackAdapter`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: When set to `true` indicates that only a [fallback
 adapter](#fallback-adapter) may be returned. If the user agent does not support
 a [fallback adapter](#fallback-adapter), will cause
 [`requestAdapter()`](#dom-gpu-requestadapter) to resolve to `null`.

 [`requestAdapter()`](#dom-gpu-requestadapter) may still return a [fallback
 adapter](#fallback-adapter) if
 [`forceFallbackAdapter`](#dom-gpurequestadapteroptions-forcefallbackadapter) is set to `false` and either no other appropriate
 [adapter](#adapter) is available
 or the user agent chooses to return a [fallback
 adapter](#fallback-adapter). Developers that wish to prevent their applications
 from running on [fallback
 adapters](#fallback-adapter) should check the
 [`info`](#dom-gpuadapter-info).[`isFallbackAdapter`](#dom-gpuadapterinfo-isfallbackadapter) attribute prior to requesting a
 [`GPUDevice`](#gpudevice).

[`xrCompatible`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: When set to `true` indicates that the best
 [adapter](#adapter) for
 rendering to a [WebXR
 session](https://www.w3.org/TR/webxr/#session) must be returned. If the user agent or system does
 not support [WebXR
 sessions](https://www.w3.org/TR/webxr/#session) then adapter selection may ignore this value.

 If
 [`xrCompatible`](#dom-gpurequestadapteroptions-xrcompatible) is not set to `true` when the adapter is requested,
 [`GPUDevice`](#gpudevice)s created from the adapter cannot be used to render
 for [WebXR
 sessions](https://www.w3.org/TR/webxr/#session).

Requesting a
[`"high-performance"`](#dom-gpupowerpreference-high-performance) [`GPUAdapter`](#gpuadapter):

``` highlight
const gpuAdapter = await navigator.gpu.requestAdapter({
 powerPreference: 'high-performance'
});
```

### 4.3. `GPUAdapter`

A [`GPUAdapter`](#gpuadapter) encapsulates an [adapter](#adapter), and describes its capabilities
([features](#feature) and
[limits](#limit)).

To get a [`GPUAdapter`](#gpuadapter), use
[`requestAdapter()`](#dom-gpu-requestadapter).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUAdapter {
 [SameObject] readonly attribute GPUSupportedFeatures features;
 [SameObject] readonly attribute GPUSupportedLimits limits;
 [SameObject] readonly attribute GPUAdapterInfo info;

 Promise<GPUDevice> requestDevice(optional GPUDeviceDescriptor descriptor = );
};
```

[`GPUAdapter`](#gpuadapter)
has the following [immutable
properties](#immutable-property)

[`features`], of type [GPUSupportedFeatures](#gpusupportedfeatures), readonly

: The set of values in
 `this`.[`[[adapter]]`](#dom-gpuadapter-adapter-slot).[`[[features]]`](#dom-adapter-features-slot).

[`limits`], of type [GPUSupportedLimits](#gpusupportedlimits), readonly

: The limits in
 `this`.[`[[adapter]]`](#dom-gpuadapter-adapter-slot).[`[[limits]]`](#dom-adapter-limits-slot).

[`info`], of type [GPUAdapterInfo](#gpuadapterinfo), readonly

: Information about the physical adapter underlying this
 [`GPUAdapter`](#gpuadapter).

 For a given [`GPUAdapter`](#gpuadapter), the
 [`GPUAdapterInfo`](#gpuadapterinfo) values exposed are constant over time.

 The same object is returned each time. To create that object for the
 first time:

 ::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUAdapter`](#gpuadapter) `this`.
 **Returns:**
 [`GPUAdapterInfo`](#gpuadapterinfo)

 [Content timeline](#content-timeline) steps:

 1. Return a [new adapter
 info](#abstract-opdef-new-adapter-info) for
 `this`.[`[[adapter]]`](#dom-gpuadapter-adapter-slot).
 :::
 ::::

[`[[adapter]]`], of type [adapter](#adapter), readonly

: The [adapter](#adapter) to which
 this [`GPUAdapter`](#gpuadapter) refers.

[`GPUAdapter`](#gpuadapter)
has the following methods:

[`requestDevice(descriptor)`]

: Requests a [device](#device) from
 the [adapter](#adapter).

 This is a one-time action: if a device is returned successfully, the
 adapter becomes
 [`"consumed"`](#dom-adapter-state-consumed).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUAdapter`](#gpuadapter) `this`.
 **Arguments:**

 Arguments for the
 [GPUAdapter.requestDevice(descriptor)](#dom-gpuadapter-requestdevice) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUDeviceDescriptor`](#gpudevicedescriptor)
 [✘]
 [✔]
 Description of the
 [`GPUDevice`](#gpudevice) to request.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`GPUDevice`](#gpudevice)\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Let `adapter` be
 `this`.[`[[adapter]]`](#dom-gpuadapter-adapter-slot).

 4. Issue the `initialization steps` to the [Device
 timeline](#device-timeline) of `this`.

 5. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following requirements are unmet:

 ::: validusage
 - The set of values in
 `descriptor`.[`requiredFeatures`](#dom-gpudevicedescriptor-requiredfeatures) must be a subset of those in
 `adapter`.[`[[features]]`](#dom-adapter-features-slot).
 :::

 Then issue the following steps on `contentTimeline` and return:

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
 :::

 This is the same error that is produced if a
 feature name isn't known by the browser at all (in its
 [`GPUFeatureName`](#gpufeaturename) definition). This converges the behavior when
 the browser doesn't support a feature with the behavior when a
 particular adapter doesn't support a feature.

 2. All of the requirements in the following steps `must`
 be met.

 ::: validusage
 1. `adapter`.[`[[state]]`](#dom-adapter-state-slot) must not be
 [`"consumed"`](#dom-adapter-state-consumed).

 2. For each \[`key`, `value`\] in
 `descriptor`.[`requiredLimits`](#dom-gpudevicedescriptor-requiredlimits) for which `value` is not
 `undefined`:

 1. `key` `must` be the name of a
 member of [supported
 limits](#supported-limits).

 2. `value` `must` be no
 [better](#limit-better) than
 `adapter`.[`[[limits]]`](#dom-adapter-limits-slot)\[`key`\].

 3. If `key`'s
 [class](#limit-class) is
 [alignment](#limit-class-alignment), `value` `must`
 be a power of 2 less than 2^32^.

 User agents should consider issuing
 developer-visible warnings when `key` is not
 recognized, even when `value` is `undefined`.
 :::

 If any are unmet, issue the following steps on
 `contentTimeline` and return:

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).
 :::

 3. If
 `adapter`.[`[[state]]`](#dom-adapter-state-slot) is
 [`"expired"`](#dom-adapter-state-expired) or the user agent otherwise cannot fulfill the
 request:

 1. Let `device` be a new
 [device](#device).

 2. [Lose the
 device](#lose-the-device)(`device`,
 [`"unknown"`](#dom-gpudevicelostreason-unknown)).

 3. [Assert](https://infra.spec.whatwg.org/#assert)
 `adapter`.[`[[state]]`](#dom-adapter-state-slot) is
 [`"expired"`](#dom-adapter-state-expired).

 User agents should consider issuing
 developer-visible warnings in most or all cases when this
 occurs. Applications should perform reinitialization logic
 starting with
 [`requestAdapter()`](#dom-gpu-requestadapter).

 Otherwise:

 1. Let `device` be the result of creating [a new
 device](#a-new-device) from `adapter` with
 `descriptor`.

 2. [Expire](#abstract-opdef-expire) `adapter`.

 4. Issue the subsequent steps on `contentTimeline`.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) steps:
 1. Let `gpuDevice` be a new
 [`GPUDevice`](#gpudevice) instance.

 2. Set
 `gpuDevice`.[`[[device]]`](#dom-gpuobjectbase-device-slot) to `device`.

 3. Set
 `device`.[`[[content device]]`](#dom-device-content-device-slot) to `gpuDevice`.

 4. Set
 `gpuDevice`.[`label`](#dom-gpuobjectbase-label) to
 `descriptor`.[`label`](#dom-gpuobjectdescriptorbase-label).

 5. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `gpuDevice`.

 If the device is already lost because the
 adapter could not fulfill the request,
 `device`.[`lost`](#dom-gpudevice-lost) has already resolved before
 `promise` resolves.
 :::
 ::::::

Requesting a
[`GPUDevice`](#gpudevice)
with default features and limits:

``` highlight
const gpuAdapter = await navigator.gpu.requestAdapter();
const gpuDevice = await gpuAdapter.requestDevice();
```

#### 4.3.1. `GPUDeviceDescriptor`

[`GPUDeviceDescriptor`](#gpudevicedescriptor) describes a device request.

```
dictionary GPUDeviceDescriptor
 : GPUObjectDescriptorBase {
 sequence<GPUFeatureName> requiredFeatures = ;
 record<DOMString, (GPUSize64 or undefined)> requiredLimits = ;
 GPUQueueDescriptor defaultQueue = ;
};
```

[`GPUDeviceDescriptor`](#gpudevicedescriptor) has the following members:

[`requiredFeatures`], of type sequence\<[GPUFeatureName](#gpufeaturename)\>, defaulting to ``

: Specifies the [features](#feature) that are required by the device request. The
 request will fail if the adapter cannot provide these features.

 Exactly the specified set of features, and no more or less, will be
 allowed in validation of API calls on the resulting device.

[`requiredLimits`], of type `record<DOMString, (GPUSize64 or undefined)>`, defaulting to ``

: Specifies the [limits](#limit) that
 are required by the device request. The request will fail if the
 adapter cannot provide these limits.

 Each key with a non-`undefined` value must be the name of a member
 of [supported limits](#supported-limits).

 API calls on the resulting device perform validation according to
 the exact limits of the device (not the adapter; see [§ 3.6.2
 Limits](#limits)).

[`defaultQueue`], of type [GPUQueueDescriptor](#gpuqueuedescriptor), defaulting to ``

: The descriptor for the default
 [`GPUQueue`](#gpuqueue).

Requesting a
[`GPUDevice`](#gpudevice)
with the
[`"texture-compression-astc"`](#texture-compression-astc) feature if supported:

``` highlight
const gpuAdapter = await navigator.gpu.requestAdapter();

const requiredFeatures = ;
if (gpuAdapter.features.has('texture-compression-astc')) {
 requiredFeatures.push('texture-compression-astc')
}

const gpuDevice = await gpuAdapter.requestDevice({
 requiredFeatures
});
```

Requesting a
[`GPUDevice`](#gpudevice)
with a higher
[`maxColorAttachmentBytesPerSample`](#dom-supported-limits-maxcolorattachmentbytespersample) limit:

``` highlight
const gpuAdapter = await navigator.gpu.requestAdapter();

if (gpuAdapter.limits.maxColorAttachmentBytesPerSample < 64) {
 // When the desired limit isn’t supported, take action to either fall back to a code
 // path that does not require the higher limit or notify the user that their device
 // does not meet minimum requirements.
}

// Request higher limit of max color attachments bytes per sample.
const gpuDevice = await gpuAdapter.requestDevice({
 requiredLimits: { maxColorAttachmentBytesPerSample: 64 },
});
```

##### 4.3.1.1. `GPUFeatureName`

Each [`GPUFeatureName`](#gpufeaturename) identifies a set of functionality which, if available,
allows additional usages of WebGPU that would have otherwise been
invalid.

```
enum GPUFeatureName {
 "core-features-and-limits",
 "depth-clip-control",
 "depth32float-stencil8",
 "texture-compression-bc",
 "texture-compression-bc-sliced-3d",
 "texture-compression-etc2",
 "texture-compression-astc",
 "texture-compression-astc-sliced-3d",
 "timestamp-query",
 "indirect-first-instance",
 "shader-f16",
 "rg11b10ufloat-renderable",
 "bgra8unorm-storage",
 "float32-filterable",
 "float32-blendable",
 "clip-distances",
 "dual-source-blending",
 "subgroups",
 "texture-formats-tier1",
 "texture-formats-tier2",
 "primitive-index",
 "texture-component-swizzle",
};
```

### 4.4. `GPUDevice`

A [`GPUDevice`](#gpudevice)
encapsulates a [device](#device) and
exposes the functionality of that device.

[`GPUDevice`](#gpudevice) is
the top-level interface through which [WebGPU
interfaces](#webgpu-interface) are created.

To get a [`GPUDevice`](#gpudevice), use
[`requestDevice()`](#dom-gpuadapter-requestdevice).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUDevice : EventTarget {
 [SameObject] readonly attribute GPUSupportedFeatures features;
 [SameObject] readonly attribute GPUSupportedLimits limits;
 [SameObject] readonly attribute GPUAdapterInfo adapterInfo;

 [SameObject] readonly attribute GPUQueue queue;

 undefined destroy();

 GPUBuffer createBuffer(GPUBufferDescriptor descriptor);
 GPUTexture createTexture(GPUTextureDescriptor descriptor);
 GPUSampler createSampler(optional GPUSamplerDescriptor descriptor = );
 GPUExternalTexture importExternalTexture(GPUExternalTextureDescriptor descriptor);

 GPUBindGroupLayout createBindGroupLayout(GPUBindGroupLayoutDescriptor descriptor);
 GPUPipelineLayout createPipelineLayout(GPUPipelineLayoutDescriptor descriptor);
 GPUBindGroup createBindGroup(GPUBindGroupDescriptor descriptor);

 GPUShaderModule createShaderModule(GPUShaderModuleDescriptor descriptor);
 GPUComputePipeline createComputePipeline(GPUComputePipelineDescriptor descriptor);
 GPURenderPipeline createRenderPipeline(GPURenderPipelineDescriptor descriptor);
 Promise<GPUComputePipeline> createComputePipelineAsync(GPUComputePipelineDescriptor descriptor);
 Promise<GPURenderPipeline> createRenderPipelineAsync(GPURenderPipelineDescriptor descriptor);

 GPUCommandEncoder createCommandEncoder(optional GPUCommandEncoderDescriptor descriptor = );
 GPURenderBundleEncoder createRenderBundleEncoder(GPURenderBundleEncoderDescriptor descriptor);

 GPUQuerySet createQuerySet(GPUQuerySetDescriptor descriptor);
};
GPUDevice includes GPUObjectBase;
```

[`GPUDevice`](#gpudevice)
has the following [immutable
properties](#immutable-property):

[`features`], of type [GPUSupportedFeatures](#gpusupportedfeatures), readonly

: A set containing the
 [`GPUFeatureName`](#gpufeaturename) values of the features supported by the device
 ([`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot)).

[`limits`], of type [GPUSupportedLimits](#gpusupportedlimits), readonly

: The limits supported by the device
 ([`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot)).

[`queue`], of type [GPUQueue](#gpuqueue), readonly

: The primary [`GPUQueue`](#gpuqueue) for this device.

[`adapterInfo`], of type [GPUAdapterInfo](#gpuadapterinfo), readonly

: Information about the physical adapter which created the
 [device](#device) that this
 [`GPUDevice`](#gpudevice) refers to.

 For a given [`GPUDevice`](#gpudevice), the
 [`GPUAdapterInfo`](#gpuadapterinfo) values exposed are constant over time.

 The same object is returned each time. To create that object for the
 first time:

 ::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Returns:**
 [`GPUAdapterInfo`](#gpuadapterinfo)

 [Content timeline](#content-timeline) steps:

 1. Return a [new adapter
 info](#abstract-opdef-new-adapter-info) for
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[adapter]]`](#dom-device-adapter-slot).
 :::
 ::::

The
[`[[device]]`](#dom-gpuobjectbase-device-slot) for a
[`GPUDevice`](#gpudevice) is
the [device](#device) that the
[`GPUDevice`](#gpudevice)
refers to.

[`GPUDevice`](#gpudevice)
has the following methods:

[`destroy()`]

: Destroys the [device](#device),
 preventing further operations on it. Outstanding asynchronous
 operations will fail.

 It is valid to destroy a device multiple times.

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 [Content timeline](#content-timeline) steps:

 1. [`unmap()`](#dom-gpubuffer-unmap) all
 [`GPUBuffer`](#gpubuffer)s from this device.

 2. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 1. [Lose the device](#lose-the-device)(`this`.[`[[device]]`](#dom-gpuobjectbase-device-slot),
 [`"destroyed"`](#dom-gpudevicelostreason-destroyed)).
 :::
 :::::

 Since no further operations can be enqueued on this
 device, implementations can abort outstanding asynchronous
 operations immediately and free resource allocations, including
 mapped memory that was just unmapped.

A [`GPUDevice`](#gpudevice)'s [allowed buffer usages] are:

- Always allowed:
 [`MAP_READ`](#dom-gpubufferusage-map_read),
 [`MAP_WRITE`](#dom-gpubufferusage-map_write),
 [`COPY_SRC`](#dom-gpubufferusage-copy_src),
 [`COPY_DST`](#dom-gpubufferusage-copy_dst),
 [`INDEX`](#dom-gpubufferusage-index),
 [`VERTEX`](#dom-gpubufferusage-vertex),
 [`UNIFORM`](#dom-gpubufferusage-uniform),
 [`STORAGE`](#dom-gpubufferusage-storage),
 [`INDIRECT`](#dom-gpubufferusage-indirect),
 [`QUERY_RESOLVE`](#dom-gpubufferusage-query_resolve)

A [`GPUDevice`](#gpudevice)'s [allowed texture usages] are:

- Always allowed:
 [`COPY_SRC`](#dom-gputextureusage-copy_src),
 [`COPY_DST`](#dom-gputextureusage-copy_dst),
 [`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding),
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding),
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment)

### 4.5. Example

A more robust example of requesting a
[`GPUAdapter`](#gpuadapter)
and [`GPUDevice`](#gpudevice) with error handling:

``` highlight
let gpuDevice = null;

async function initializeWebGPU() {
 // Check to ensure the user agent supports WebGPU.
 if (!('gpu' in navigator)) {
 console.error("User agent doesn’t support WebGPU.");
 return false;
 }

 // Request an adapter.
 const gpuAdapter = await navigator.gpu.requestAdapter();

 // requestAdapter may resolve with null if no suitable adapters are found.
 if (!gpuAdapter) {
 console.error('No WebGPU adapters found.');
 return false;
 }

 // Request a device.
 // Note that the promise will reject if invalid options are passed to the optional
 // dictionary. To avoid the promise rejecting always check any features and limits
 // against the adapters features and limits prior to calling requestDevice().
 gpuDevice = await gpuAdapter.requestDevice();

 // requestDevice will never return null, but if a valid device request can’t be
 // fulfilled for some reason it may resolve to a device which has already been lost.
 // Additionally, devices can be lost at any time after creation for a variety of reasons
 // (ie: browser resource management, driver updates), so it’s a good idea to always
 // handle lost devices gracefully.
 gpuDevice.lost.then((info) => {
 console.error(`WebGPU device was lost: ${info.message}`);

 gpuDevice = null;

 // Many causes for lost devices are transient, so applications should try getting a
 // new device once a previous one has been lost unless the loss was caused by the
 // application intentionally destroying the device. Note that any WebGPU resources
 // created with the previous device (buffers, textures, etc) will need to be
 // re-created with the new one.
 if (info.reason != 'destroyed') {
 initializeWebGPU();
 }
 });

 onWebGPUInitialized();

 return true;
}

function onWebGPUInitialized() {
 // Begin creating WebGPU resources here...
}

initializeWebGPU();
```

## 5. Buffers

### 5.1. `GPUBuffer`

A [`GPUBuffer`](#gpubuffer)
represents a block of memory that can be used in GPU operations. Data is
stored in linear layout, meaning that each byte of the allocation can be
addressed by its offset from the start of the
[`GPUBuffer`](#gpubuffer),
subject to alignment restrictions depending on the operation. Some
[`GPUBuffers`](#gpubuffer)
can be mapped which makes the block of memory accessible via an
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) called its mapping.

[`GPUBuffer`](#gpubuffer)s
are created via
[`createBuffer()`](#dom-gpudevice-createbuffer). Buffers may be
[`mappedAtCreation`](#dom-gpubufferdescriptor-mappedatcreation).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUBuffer {
 readonly attribute GPUSize64Out size;
 readonly attribute GPUFlagsConstant usage;

 readonly attribute GPUBufferMapState mapState;

 Promise<undefined> mapAsync(GPUMapModeFlags mode, optional GPUSize64 offset = 0, optional GPUSize64 size);
 ArrayBuffer getMappedRange(optional GPUSize64 offset = 0, optional GPUSize64 size);
 undefined unmap();

 undefined destroy();
};
GPUBuffer includes GPUObjectBase;

enum GPUBufferMapState {
 "unmapped",
 "pending",
 "mapped",
};
```

[`GPUBuffer`](#gpubuffer)
has the following [immutable
properties](#immutable-property):

[`size`], of type [GPUSize64Out](#typedefdef-gpusize64out), readonly

: The length of the
 [`GPUBuffer`](#gpubuffer) allocation in bytes.

[`usage`], of type [GPUFlagsConstant](#typedefdef-gpuflagsconstant), readonly

: The allowed usages for this
 [`GPUBuffer`](#gpubuffer).

[`GPUBuffer`](#gpubuffer)
has the following [content timeline
properties](#content-timeline-property):

[`mapState`], of type [GPUBufferMapState](#enumdef-gpubuffermapstate), readonly

: The current [`GPUBufferMapState`] of the
 buffer:

 [`"unmapped"`]

 : The buffer is not mapped for use by
 `this`.[`getMappedRange()`](#dom-gpubuffer-getmappedrange).

 [`"pending"`]

 : A mapping of the buffer has been requested, but is pending. It
 may succeed, or fail validation in
 [`mapAsync()`](#dom-gpubuffer-mapasync).

 [`"mapped"`]

 : The buffer is mapped and
 `this`.[`getMappedRange()`](#dom-gpubuffer-getmappedrange) may be used.

 The [getter
 steps](https://webidl.spec.whatwg.org/#getter-steps) are:

 ::::
 ::: {timeline="content"}
 [Content timeline](#content-timeline) steps:
 1. If
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot) is not `null`, return
 [`"mapped"`](#dom-gpubuffermapstate-mapped).

 2. If
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) is not `null`, return
 [`"pending"`](#dom-gpubuffermapstate-pending).

 3. Return
 [`"unmapped"`](#dom-gpubuffermapstate-unmapped).
 :::
 ::::

[`[[pending_map]]`], of type [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<void\> or `null`, initially `null`

: The
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned by the currently-pending
 [`mapAsync()`](#dom-gpubuffer-mapasync) call.

 There is never more than one pending map, because
 [`mapAsync()`](#dom-gpubuffer-mapasync) will refuse immediately if a request is already in
 flight.

[`[[mapping]]`], of type [active buffer mapping](#active-buffer-mapping) or `null`, initially `null`

: Set if and only if the buffer is currently mapped for use by
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange). Null otherwise (even if there is a
 [`[[pending_map]]`](#dom-gpubuffer-pending_map-slot)).

 An [active buffer mapping] is a structure with the
 following fields:

 [data], of type [Data Block](https://tc39.es/ecma262/#sec-data-blocks)

 : The mapping for this
 [`GPUBuffer`](#gpubuffer). This data is accessed through
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s which are views onto this data, returned by
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange) and stored in
 [views](#active-buffer-mapping-views).

 [mode], of type [`GPUMapModeFlags`](#typedefdef-gpumapmodeflags)

 : The
 [`GPUMapModeFlags`](#typedefdef-gpumapmodeflags) of the map, as specified in the corresponding
 call to
 [`mapAsync()`](#dom-gpubuffer-mapasync) or
 [`createBuffer()`](#dom-gpudevice-createbuffer).

 [range], of type tuple \[[`unsigned long long`](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), [`unsigned long long`](https://webidl.spec.whatwg.org/#idl-unsigned-long-long)\]

 : The range of this
 [`GPUBuffer`](#gpubuffer) that is mapped.

 [views], of type [list](https://infra.spec.whatwg.org/#list)\<[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)\>

 : The
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s returned via
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange) to the application. They are tracked so they
 can be detached when
 [`unmap()`](#dom-gpubuffer-unmap) is called.

 :::
 To [initialize an active buffer
 mapping] with mode
 `mode` and range `range`, run the following
 [content timeline](#content-timeline) steps:
 1. Let `size` be `range`\[1\] -
 `range`\[0\].

 2. Let `data` be
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands)
 [CreateByteDataBlock](https://tc39.es/ecma262/#sec-createbytedatablock)(`size`).

 ::::
 ::: marker
 NOTE:
 :::

 This may result in a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) being thrown. For consistency and
 predictability:
 - For any size at which `new ArrayBuffer()` would succeed at a
 given moment, this allocation **should** succeed at that
 moment.

 - For any size at which `new ArrayBuffer()` *deterministically*
 throws a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror), this allocation **should** as well.
 ::::

 3. Return an [active buffer
 mapping](#active-buffer-mapping) with:

 - [data](#active-buffer-mapping-data) set to `data`.

 - [mode](#active-buffer-mapping-mode) set to `mode`.

 - [range](#active-buffer-mapping-range) set to `range`.

 - [views](#active-buffer-mapping-views) set to ``.
 :::

<figure>

<figcaption>Mapping and unmapping a buffer.</figcaption>
</figure>

<figure>

<figcaption>Failing to map a buffer.</figcaption>
</figure>

[`GPUBuffer`](#gpubuffer)
has the following [device timeline
properties](#device-timeline-property):

[`[[internal state]]`]

: The current internal state of the buffer:

 \"[available]\"

 : The buffer can be used in queue operations (unless it is
 [invalid](#abstract-opdef-invalid)).

 \"[unavailable]\"

 : The buffer cannot be used in queue operations due to being
 mapped.

 \"[destroyed]\"

 : The buffer cannot be used in any operations due to being
 [`destroy()`](#dom-gpubuffer-destroy)ed.

#### 5.1.1. `GPUBufferDescriptor`

```
dictionary GPUBufferDescriptor
 : GPUObjectDescriptorBase {
 required GPUSize64 size;
 required GPUBufferUsageFlags usage;
 boolean mappedAtCreation = false;
};
```

[`GPUBufferDescriptor`](#gpubufferdescriptor) has the following members:

[`size`], of type [GPUSize64](#typedefdef-gpusize64)

: The size of the buffer in bytes.

[`usage`], of type [GPUBufferUsageFlags](#typedefdef-gpubufferusageflags)

: The allowed usages for the buffer.

[`mappedAtCreation`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: If `true` creates the buffer in an already mapped state, allowing
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange) to be called immediately. It is valid to set
 [`mappedAtCreation`](#dom-gpubufferdescriptor-mappedatcreation) to `true` even if
 [`usage`](#dom-gpubufferdescriptor-usage) does not contain
 [`MAP_READ`](#dom-gpubufferusage-map_read) or
 [`MAP_WRITE`](#dom-gpubufferusage-map_write). This can be used to set the buffer's initial data.

 Guarantees that even if the buffer creation eventually fails, it
 will still appear as if the mapped range can be written/read to
 until it is unmapped.

#### 5.1.2. Buffer Usages

```
typedef [EnforceRange] unsigned long GPUBufferUsageFlags;
[Exposed=(Window, Worker), SecureContext]
namespace GPUBufferUsage {
 const GPUFlagsConstant MAP_READ = 0x0001;
 const GPUFlagsConstant MAP_WRITE = 0x0002;
 const GPUFlagsConstant COPY_SRC = 0x0004;
 const GPUFlagsConstant COPY_DST = 0x0008;
 const GPUFlagsConstant INDEX = 0x0010;
 const GPUFlagsConstant VERTEX = 0x0020;
 const GPUFlagsConstant UNIFORM = 0x0040;
 const GPUFlagsConstant STORAGE = 0x0080;
 const GPUFlagsConstant INDIRECT = 0x0100;
 const GPUFlagsConstant QUERY_RESOLVE = 0x0200;
};
```

The
[`GPUBufferUsage`](#namespacedef-gpubufferusage) flags determine how a
[`GPUBuffer`](#gpubuffer)
may be used after its creation:

[`MAP_READ`]

: The buffer can be mapped for reading. (Example: calling
 [`mapAsync()`](#dom-gpubuffer-mapasync) with
 [`GPUMapMode.READ`](#dom-gpumapmode-read))

 May only be combined with
 [`COPY_DST`](#dom-gpubufferusage-copy_dst).

[`MAP_WRITE`]

: The buffer can be mapped for writing. (Example: calling
 [`mapAsync()`](#dom-gpubuffer-mapasync) with
 [`GPUMapMode.WRITE`](#dom-gpumapmode-write))

 May only be combined with
 [`COPY_SRC`](#dom-gpubufferusage-copy_src).

[`COPY_SRC`]

: The buffer can be used as the source of a copy operation. (Examples:
 as the `source` argument of a
 [copyBufferToBuffer()](#gpucommandencoder-copybuffertobuffer) or
 [`copyBufferToTexture()`](#dom-gpucommandencoder-copybuffertotexture) call.)

[`COPY_DST`]

: The buffer can be used as the destination of a copy or write
 operation. (Examples: as the `destination` argument of a
 [copyBufferToBuffer()](#gpucommandencoder-copybuffertobuffer) or
 [`copyTextureToBuffer()`](#dom-gpucommandencoder-copytexturetobuffer) call, or as the target of a
 [`writeBuffer()`](#dom-gpuqueue-writebuffer) call.)

[`INDEX`]

: The buffer can be used as an index buffer. (Example: passed to
 [`setIndexBuffer()`](#dom-gpurendercommandsmixin-setindexbuffer).)

[`VERTEX`]

: The buffer can be used as a vertex buffer. (Example: passed to
 [`setVertexBuffer()`](#dom-gpurendercommandsmixin-setvertexbuffer).)

[`UNIFORM`]

: The buffer can be used as a uniform buffer. (Example: as a bind
 group entry for a
 [`GPUBufferBindingLayout`](#dictdef-gpubufferbindinglayout) with a
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`type`](#dom-gpubufferbindinglayout-type) of
 [`"uniform"`](#dom-gpubufferbindingtype-uniform).)

[`STORAGE`]

: The buffer can be used as a storage buffer. (Example: as a bind
 group entry for a
 [`GPUBufferBindingLayout`](#dictdef-gpubufferbindinglayout) with a
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`type`](#dom-gpubufferbindinglayout-type) of
 [`"storage"`](#dom-gpubufferbindingtype-storage) or
 [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage).)

[`INDIRECT`]

: The buffer can be used as to store indirect command arguments.
 (Examples: as the `indirectBuffer` argument of a
 [`drawIndirect()`](#dom-gpurendercommandsmixin-drawindirect) or
 [`dispatchWorkgroupsIndirect()`](#dom-gpucomputepassencoder-dispatchworkgroupsindirect) call.)

[`QUERY_RESOLVE`]

: The buffer can be used to capture query results. (Example: as the
 `destination` argument of a
 [`resolveQuerySet()`](#dom-gpucommandencoder-resolvequeryset) call.)

#### 5.1.3. Buffer Creation

[`createBuffer(descriptor)`]

: Creates a [`GPUBuffer`](#gpubuffer).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createBuffer(descriptor)](#dom-gpudevice-createbuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUBufferDescriptor`](#gpubufferdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUBuffer`](#gpubuffer) to create.
 **Returns:** [`GPUBuffer`](#gpubuffer)

 [Content timeline](#content-timeline) steps:

 1. Let `b` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUBuffer`](#gpubuffer), `descriptor`).

 2. Set
 `b`.[`size`](#dom-gpubuffer-size) to
 `descriptor`.[`size`](#dom-gpubufferdescriptor-size).

 3. Set
 `b`.[`usage`](#dom-gpubuffer-usage) to
 `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage).

 4. If
 `descriptor`.[`mappedAtCreation`](#dom-gpubufferdescriptor-mappedatcreation) is `true`:

 1. If
 `descriptor`.[`size`](#dom-gpubufferdescriptor-size) is not a multiple of 4, throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 2. Set
 `b`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot) to
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [initialize an
 active buffer
 mapping](#abstract-opdef-initialize-an-active-buffer-mapping) with mode
 [`WRITE`](#dom-gpumapmode-write) and range
 `[0, ``descriptor``.`[`size`](#dom-gpubufferdescriptor-size)`]`.

 5. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 6. Return `b`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `b` and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage) must not be 0.

 - `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage) must be a subset of the [allowed buffer
 usages](#allowed-buffer-usages) for `this`.

 - If
 `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage) contains
 [`MAP_READ`](#dom-gpubufferusage-map_read):

 - `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage) must contain no other flags except
 [`COPY_DST`](#dom-gpubufferusage-copy_dst).

 - If
 `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage) contains
 [`MAP_WRITE`](#dom-gpubufferusage-map_write):

 - `descriptor`.[`usage`](#dom-gpubufferdescriptor-usage) must contain no other flags except
 [`COPY_SRC`](#dom-gpubufferusage-copy_src).

 - If
 `descriptor`.[`size`](#dom-gpubufferdescriptor-size) must be ≤
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxBufferSize`](#dom-supported-limits-maxbuffersize).
 :::

 If buffer creation fails, and
 `descriptor`.[`mappedAtCreation`](#dom-gpubufferdescriptor-mappedatcreation) is `false`, any calls to
 [`mapAsync()`](#dom-gpubuffer-mapasync) will reject, so any resources allocated to enable
 mapping can and may be discarded or recycled.

 1. If
 `descriptor`.[`mappedAtCreation`](#dom-gpubufferdescriptor-mappedatcreation) is `true`:

 1. Set
 `b`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) to
 \"[unavailable](#gpubuffer-internal-state-unavailable)\".

 Otherwise:

 1. Set
 `b`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) to
 \"[available](#gpubuffer-internal-state-available)\".

 2. Create a device allocation for `b` where each byte is
 zero.

 If the allocation fails without side-effects, [generate an
 out-of-memory
 error](#abstract-opdef-generate-an-out-of-memory-error),
 [invalidate](#abstract-opdef-invalidate) `b`, and return.
 :::
 :::::

Creating a 128 byte uniform buffer
that can be written into:

``` highlight
const buffer = gpuDevice.createBuffer({
 size: 128,
 usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
});
```

#### 5.1.4. Buffer Destruction

An application that no longer requires a
[`GPUBuffer`](#gpubuffer)
can choose to lose access to it before garbage collection by calling
[`destroy()`](#dom-gpubuffer-destroy). Destroying a buffer also unmaps it, freeing any memory
allocated for the mapping.

 This allows the user agent to reclaim the GPU memory
associated with the [`GPUBuffer`](#gpubuffer) once all previously submitted operations using it are
complete.

[`GPUBuffer`](#gpubuffer)
has the following methods:

[`destroy()`]

: Destroys the [`GPUBuffer`](#gpubuffer).

 It is valid to destroy a buffer multiple times.

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUBuffer`](#gpubuffer) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Call
 `this`.[`unmap()`](#dom-gpubuffer-unmap).

 2. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Set
 `this`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) to
 \"[destroyed](#gpubuffer-internal-state-destroyed)\".
 :::
 :::::

 Since no further operations can be enqueued using
 this buffer, implementations can free resource allocations,
 including mapped memory that was just unmapped.

### 5.2. Buffer Mapping

An application can request to map a
[`GPUBuffer`](#gpubuffer) so
that they can access its content via
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s that represent part of the
[`GPUBuffer`](#gpubuffer)'s
allocations. Mapping a
[`GPUBuffer`](#gpubuffer) is
requested asynchronously with
[`mapAsync()`](#dom-gpubuffer-mapasync) so that the user agent can ensure the GPU finished
using the [`GPUBuffer`](#gpubuffer) before the application can access its content. A mapped
[`GPUBuffer`](#gpubuffer)
cannot be used by the GPU and must be unmapped using
[`unmap()`](#dom-gpubuffer-unmap) before work using it can be submitted to the [Queue
timeline](#queue-timeline).

Once the [`GPUBuffer`](#gpubuffer) is mapped, the application can synchronously ask for
access to ranges of its content with
[`getMappedRange()`](#dom-gpubuffer-getmappedrange). The returned
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) can only be
[detached](https://webidl.spec.whatwg.org/#dfn-detach) by
[`unmap()`](#dom-gpubuffer-unmap) (directly, or via
[`GPUBuffer`](#gpubuffer).[`destroy()`](#dom-gpubuffer-destroy) or [`GPUDevice`](#gpudevice).[`destroy()`](#dom-gpudevice-destroy)), and cannot be
[transferred](https://webidl.spec.whatwg.org/#arraybuffer-transfer). A
[`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) is thrown by any other operation that attempts to do
so.

```
typedef [EnforceRange] unsigned long GPUMapModeFlags;
[Exposed=(Window, Worker), SecureContext]
namespace GPUMapMode {
 const GPUFlagsConstant READ = 0x0001;
 const GPUFlagsConstant WRITE = 0x0002;
};
```

The
[`GPUMapMode`](#namespacedef-gpumapmode) flags determine how a
[`GPUBuffer`](#gpubuffer) is
mapped when calling
[`mapAsync()`](#dom-gpubuffer-mapasync):

[`READ`]

: Only valid with buffers created with the
 [`MAP_READ`](#dom-gpubufferusage-map_read) usage.

 Once the buffer is mapped, calls to
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange) will return an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) containing the buffer's current values. Changes to
 the returned
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) will be discarded after
 [`unmap()`](#dom-gpubuffer-unmap) is called.

[`WRITE`]

: Only valid with buffers created with the
 [`MAP_WRITE`](#dom-gpubufferusage-map_write) usage.

 Once the buffer is mapped, calls to
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange) will return an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) containing the buffer's current values. Changes to
 the returned
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) will be stored in the
 [`GPUBuffer`](#gpubuffer) after
 [`unmap()`](#dom-gpubuffer-unmap) is called.

 Since the
 [`MAP_WRITE`](#dom-gpubufferusage-map_write) buffer usage may only be combined with the
 [`COPY_SRC`](#dom-gpubufferusage-copy_src) buffer usage, mapping for writing can never return
 values produced by the GPU, and the returned
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) will only ever contain the default initialized data
 (zeros) or data written by the webpage during a previous mapping.

[`GPUBuffer`](#gpubuffer)
has the following methods:

[`mapAsync(mode, offset, size)`]

: Maps the given range of the
 [`GPUBuffer`](#gpubuffer) and resolves the returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) when the
 [`GPUBuffer`](#gpubuffer)'s content is ready to be accessed with
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange).

 The resolution of the returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) **only** indicates that the buffer has been mapped.
 It does not guarantee the completion of any other operations visible
 to the [content
 timeline](#content-timeline), and in particular does not imply that any other
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from
 [`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone) or
 [`mapAsync()`](#dom-gpubuffer-mapasync) on other
 [`GPUBuffer`](#gpubuffer)s have resolved.

 The resolution of the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from
 [`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone) **does** imply the completion of
 [`mapAsync()`](#dom-gpubuffer-mapasync) calls made prior to that call, on
 [`GPUBuffer`](#gpubuffer)s last used exclusively on that queue.

 :::::::::
 ::: {timeline="content"}
 **Called on:** [`GPUBuffer`](#gpubuffer) `this`.
 **Arguments:**

 Arguments for the [GPUBuffer.mapAsync(mode, offset,
 size)](#dom-gpubuffer-mapasync) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`mode`]
 [`GPUMapModeFlags`](#typedefdef-gpumapmodeflags)
 [✘]
 [✘]
 Whether the buffer should be mapped for reading or writing.
 [`offset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Offset in bytes into the buffer to the start of the range to map.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Size in bytes of the range to map.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. If
 `this`.[`mapState`](#dom-gpubuffer-mapstate) is not
 [`"unmapped"`](#dom-gpubuffermapstate-unmapped):

 1. Issue the `early-reject steps` on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 2. Return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).

 3. Let `p` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

 4. Set
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) to `p`.

 5. Issue the `validation steps` on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 6. Return `p`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `early-reject steps`:
 1. [Generate a validation
 error](#abstract-opdef-generate-a-validation-error).

 2. Return.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `validation steps`:
 1. If `size` is `undefined`:

 1. Let `rangeSize` be max(0,
 `this`.[`size`](#dom-gpubuffer-size) - `offset`).

 Otherwise:

 1. Let `rangeSize` be `size`.

 2. If any of the following conditions are unsatisfied:

 ::: validusage
 - `this` must be
 [valid](#abstract-opdef-valid).
 :::

 1. Set `deviceLost` to `true`.

 2. Issue the `map failure steps`
 on `contentTimeline`.

 3. Return.

 3. If any of the following conditions are unsatisfied:

 ::: validusage
 - `this`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) is
 \"[available](#gpubuffer-internal-state-available)\".

 - `offset` is a multiple of 8.

 - `rangeSize` is a multiple of 4.

 - `offset` + `rangeSize` ≤
 `this`.[`size`](#dom-gpubuffer-size)

 - `mode` contains only bits defined in
 [`GPUMapMode`](#namespacedef-gpumapmode).

 - `mode` contains exactly one of
 [`READ`](#dom-gpumapmode-read) or
 [`WRITE`](#dom-gpumapmode-write).

 - If `mode` contains
 [`READ`](#dom-gpumapmode-read) then
 `this`.[`usage`](#dom-gpubuffer-usage) must contain
 [`MAP_READ`](#dom-gpubufferusage-map_read).

 - If `mode` contains
 [`WRITE`](#dom-gpumapmode-write) then
 `this`.[`usage`](#dom-gpubuffer-usage) must contain
 [`MAP_WRITE`](#dom-gpubufferusage-map_write).
 :::

 Then:

 1. Set `deviceLost` to `false`.

 2. Issue the `map failure steps`
 on `contentTimeline`.

 3. [Generate a validation
 error](#abstract-opdef-generate-a-validation-error).

 4. Return.

 4. Set
 `this`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) to
 \"[unavailable](#gpubuffer-internal-state-unavailable)\".

 Since the buffer is mapped, its contents cannot
 change between this step and
 [`unmap()`](#dom-gpubuffer-unmap).

 5. When either of the following events occur (whichever comes
 first), or if either has already occurred:

 - The [device
 timeline](#device-timeline) becomes informed of the completion of an
 unspecified [queue
 timeline](#queue-timeline) point:

 - after the completion of [currently-enqueued operations that
 use `this`]{timeline="queue"}

 - and no later than the completion of [all currently-enqueued
 operations]{timeline="queue"} (regardless of whether they
 use `this`).

 - `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot) [becomes
 lost](#becomes-lost).

 Then issue the subsequent steps on the [device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Set `deviceLost` to `true` if
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot) is
 [lost](#abstract-opdef-invalid), and `false` otherwise.

 The device could have been lost between the
 previous block of steps and this one.

 2. If `deviceLost`:

 1. Issue the `map failure steps`
 on `contentTimeline`.

 Otherwise:

 1. Let `internalStateAtCompletion` be
 `this`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot).

 If, and only if, at this point the buffer
 has become
 \"[available](#gpubuffer-internal-state-available)\" again due to an
 [`unmap()`](#dom-gpubuffer-unmap) call, then
 [`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) != `p` below, so mapping will
 not succeed in the steps below.

 2. Let `dataForMappedRegion` be the contents of
 `this` starting at offset `offset`,
 for `rangeSize` bytes.

 3. Issue the `map success steps`
 on the `contentTimeline`.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) `map success steps`:
 1. If
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) != `p`:

 The map has been cancelled by
 [`unmap()`](#dom-gpubuffer-unmap).

 1. [Assert](https://infra.spec.whatwg.org/#assert) `p` is rejected.

 2. Return.

 2. [Assert](https://infra.spec.whatwg.org/#assert) `p` is pending.

 3. [Assert](https://infra.spec.whatwg.org/#assert) `internalStateAtCompletion` is
 \"[unavailable](#gpubuffer-internal-state-unavailable)\".

 4. Let `mapping` be [initialize an active buffer
 mapping](#abstract-opdef-initialize-an-active-buffer-mapping) with mode `mode` and range
 `[``offset``, ``offset`` + ``rangeSize``]`.

 If this allocation fails:

 1. Set
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) to `null`, and
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 2. Return.

 5. Set the content of
 `mapping`.[data](#active-buffer-mapping-data) to `dataForMappedRegion`.

 6. Set
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot) to `mapping`.

 7. Set
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) to `null`, and
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p`.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) `map failure steps`:
 1. If
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) != `p`:

 The map has been cancelled by
 [`unmap()`](#dom-gpubuffer-unmap).

 1. [Assert](https://infra.spec.whatwg.org/#assert) `p` is already rejected.

 2. Return.

 2. [Assert](https://infra.spec.whatwg.org/#assert) `p` is still pending.

 3. Set
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) to `null`.

 4. If `deviceLost`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror).

 This is the same error type produced by
 cancelling the map using
 [`unmap()`](#dom-gpubuffer-unmap).

 Otherwise:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `p` with an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).
 :::
 :::::::::

[`getMappedRange(offset, size)`]

: Returns an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) with the contents of the
 [`GPUBuffer`](#gpubuffer) in the given mapped range.

 ::::
 ::: {timeline="content"}
 **Called on:** [`GPUBuffer`](#gpubuffer) `this`.
 **Arguments:**

 Arguments for the [GPUBuffer.getMappedRange(offset,
 size)](#dom-gpubuffer-getmappedrange) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`offset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Offset in bytes into the buffer to return buffer contents from.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Size in bytes of the
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) to return.
 **Returns:**
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)

 [Content timeline](#content-timeline) steps:

 1. If `size` is missing:

 1. Let `rangeSize` be max(0,
 `this`.[`size`](#dom-gpubuffer-size) - `offset`).

 Otherwise, let `rangeSize` be `size`.

 2. If any of the following conditions are unsatisfied, throw an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror) and return.

 ::: validusage
 - `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot) is not `null`.

 - `offset` is a multiple of 8.

 - `rangeSize` is a multiple of 4.

 - `offset` ≥
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[range](#active-buffer-mapping-range)\[0\].

 - `offset` + `rangeSize` ≤
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[range](#active-buffer-mapping-range)\[1\].

 - \[`offset`, `offset` +
 `rangeSize`) does not overlap another range in
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[views](#active-buffer-mapping-views).

 It is always valid to get mapped ranges of a
 [`GPUBuffer`](#gpubuffer) that is
 [`mappedAtCreation`](#dom-gpubufferdescriptor-mappedatcreation), even if it is
 [invalid](#abstract-opdef-invalid), because the [Content
 timeline](#content-timeline) might not know it is invalid.
 :::

 3. Let `data` be
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[data](#active-buffer-mapping-data).

 4. Let `view` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create an
 ArrayBuffer](https://webidl.spec.whatwg.org/#arraybuffer-create) of size `rangeSize`, but with its
 pointer mutably referencing the content of `data` at
 offset (`offset` -
 [`[[mapping]]`](#dom-gpubuffer-mapping-slot).[range](#active-buffer-mapping-range)\[0\]).

 A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) cannot be thrown here, because the
 `data` has already been allocated during
 [`mapAsync()`](#dom-gpubuffer-mapasync) or
 [`createBuffer()`](#dom-gpudevice-createbuffer).

 5. Set
 `view`.[`[[ArrayBufferDetachKey]]`](https://tc39.es/ecma262/#sec-properties-of-the-arraybuffer-instances) to \"WebGPUBufferMapping\".

 This causes a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) to be thrown if an attempt is made to
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer), except by
 [`unmap()`](#dom-gpubuffer-unmap).

 6. [Append](https://infra.spec.whatwg.org/#list-append) `view` to
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[views](#active-buffer-mapping-views).

 7. Return `view`.

 User agents should consider issuing a
 developer-visible warning if
 [`getMappedRange()`](#dom-gpubuffer-getmappedrange) succeeds without having checked the status of the
 map, by waiting for
 [`mapAsync()`](#dom-gpubuffer-mapasync) to succeed, querying a
 [`mapState`](#dom-gpubuffer-mapstate) of
 [`"mapped"`](#dom-gpubuffermapstate-mapped), or waiting for a later
 [`onSubmittedWorkDone()`](#dom-gpuqueue-onsubmittedworkdone) call to succeed.
 :::
 ::::

[`unmap()`]

: Unmaps the mapped range of the
 [`GPUBuffer`](#gpubuffer) and makes its contents available for use by the GPU
 again.

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUBuffer`](#gpubuffer) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. If
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) is not `null`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject)
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror).

 2. Set
 `this`.[`[[pending_map]]`](#dom-gpubuffer-pending_map-slot) to `null`.

 2. If
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot) is `null`:

 1. Return.

 3. For each
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) `ab` in
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[views](#active-buffer-mapping-views):

 1. Perform
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer)(`ab`,
 \"WebGPUBufferMapping\").

 4. Let `bufferUpdate` be `null`.

 5. If
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[mode](#active-buffer-mapping-mode) contains
 [`WRITE`](#dom-gpumapmode-write):

 1. Set `bufferUpdate` to { `data`:
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[data](#active-buffer-mapping-data), `offset`:
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot).[range](#active-buffer-mapping-range)\[0\] }.

 When a buffer is mapped without the
 [`WRITE`](#dom-gpumapmode-write) mode, then unmapped, any local modifications
 done by the application to the mapped ranges
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) are discarded and will not affect the content
 of later mappings.

 6. Set
 `this`.[`[[mapping]]`](#dom-gpubuffer-mapping-slot) to `null`.

 7. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. If any of the following conditions are unsatisfied, return.

 ::: validusage
 - `this` is [valid to use
 with](#abstract-opdef-valid-to-use-with)
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 2. [Assert](https://infra.spec.whatwg.org/#assert)
 `this`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) is
 \"[unavailable](#gpubuffer-internal-state-unavailable)\".

 3. If `bufferUpdate` is not `null`:

 1. Issue the following steps on the [Queue
 timeline](#queue-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`queue`](#dom-gpudevice-queue):

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Update the contents of `this` at offset
 `bufferUpdate`.`offset` with the data
 `bufferUpdate`.`data`.
 :::

 4. Set
 `this`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) to
 \"[available](#gpubuffer-internal-state-available)\".
 :::
 :::::

## 6. Textures and Texture Views

### 6.1. `GPUTexture`

A [texture] is
made up of
[`1d`](#dom-gputexturedimension-1d),
[`2d`](#dom-gputexturedimension-2d), or
[`3d`](#dom-gputexturedimension-3d) arrays of data which can contain multiple values
per-element to represent things like colors. Textures can be read and
written in many ways, depending on the
[`GPUTextureUsage`](#namespacedef-gputextureusage) they are created with. For example, textures can be
sampled, read, and written from render and compute pipeline shaders, and
they can be written by render pass outputs. Internally, textures are
often stored in GPU memory with a layout optimized for multidimensional
access rather than linear access.

One [texture](#texture) consists of
one or more [texture subresources], each uniquely identified by a
[mipmap level](#mipmap-level)
and, for
[`2d`](#dom-gputexturedimension-2d) textures only, [array
layer](#array-layer) and
[aspect](#aspect).

A [texture
subresource](#texture-subresources) is a [subresource](#subresource): each can be used in different [internal
usages](#internal-usage)
within a single [usage scope](#usage-scope).

Each subresource in a [mipmap level] is approximately half the size, in each
spatial dimension, of the corresponding resource in the lesser level
(see [logical miplevel-specific texture
extent](#logical-miplevel-specific-texture-extent)). The subresource in level 0 has the dimensions of the
texture itself. Smaller levels are typically used to store lower
resolution versions of the same image.
[`GPUSampler`](#gpusampler)
and WGSL provide facilities for selecting and interpolating between
[levels of detail](#levels-of-detail), explicitly or automatically.

A
[`"2d"`](#dom-gputexturedimension-2d) texture may be an array of [array layer]s. Each subresource in a
layer is the same size as the corresponding resources in other layers.
For non-2d textures, all subresources have an array layer index of 0.

Each subresource has an [aspect]. Color textures have just one aspect:
[color]. [Depth-or-stencil
format](#depth-or-stencil-format) textures may have multiple aspects: a
[depth] aspect, a [stencil] aspect, or both, and may be
used in special ways, such as in
[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) and in
[`"depth"`](#dom-gputexturesampletype-depth) bindings.

A
[`"3d"`](#dom-gputexturedimension-3d) texture may have multiple [slice]s, each being the
two-dimensional image at a particular `z` value in the texture. Slices
are not separate subresources.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUTexture {
 GPUTextureView createView(optional GPUTextureViewDescriptor descriptor = );

 undefined destroy();

 readonly attribute GPUIntegerCoordinateOut width;
 readonly attribute GPUIntegerCoordinateOut height;
 readonly attribute GPUIntegerCoordinateOut depthOrArrayLayers;
 readonly attribute GPUIntegerCoordinateOut mipLevelCount;
 readonly attribute GPUSize32Out sampleCount;
 readonly attribute GPUTextureDimension dimension;
 readonly attribute GPUTextureFormat format;
 readonly attribute GPUFlagsConstant usage;
 readonly attribute (GPUTextureViewDimension or undefined) textureBindingViewDimension;
};
GPUTexture includes GPUObjectBase;
```

[`GPUTexture`](#gputexture)
has the following [immutable
properties](#immutable-property):

[`width`], of type [GPUIntegerCoordinateOut](#typedefdef-gpuintegercoordinateout), readonly

: The width of this
 [`GPUTexture`](#gputexture).

[`height`], of type [GPUIntegerCoordinateOut](#typedefdef-gpuintegercoordinateout), readonly

: The height of this
 [`GPUTexture`](#gputexture).

[`depthOrArrayLayers`], of type [GPUIntegerCoordinateOut](#typedefdef-gpuintegercoordinateout), readonly

: The depth or layer count of this
 [`GPUTexture`](#gputexture).

[`mipLevelCount`], of type [GPUIntegerCoordinateOut](#typedefdef-gpuintegercoordinateout), readonly

: The number of mip levels of this
 [`GPUTexture`](#gputexture).

[`sampleCount`], of type [GPUSize32Out](#typedefdef-gpusize32out), readonly

: The number of sample count of this
 [`GPUTexture`](#gputexture).

[`dimension`], of type [GPUTextureDimension](#enumdef-gputexturedimension), readonly

: The dimension of the set of texel for each of this
 [`GPUTexture`](#gputexture)'s subresources.

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat), readonly

: The format of this
 [`GPUTexture`](#gputexture).

[`usage`], of type [GPUFlagsConstant](#typedefdef-gpuflagsconstant), readonly

: The allowed usages for this
 [`GPUTexture`](#gputexture).

[`[[viewFormats]]`], of type [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPUTextureFormat`](#enumdef-gputextureformat)\>

: The set of
 [`GPUTextureFormat`](#enumdef-gputextureformat)s that can be used as the
 [`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor).[`format`](#dom-gputextureviewdescriptor-format) when creating views on this
 [`GPUTexture`](#gputexture).

[`textureBindingViewDimension`], of type `(GPUTextureViewDimension or undefined)`, readonly

: ::: compatmode
 On devices without
 [`"core-features-and-limits"`](#core-features-and-limits), views created from this texture must have this as
 their
 [`dimension`](#dom-gputextureviewdescriptor-dimension).
 :::

 On devices with
 [`"core-features-and-limits"`](#core-features-and-limits), this is `undefined`, and there is no such
 restriction.

[`GPUTexture`](#gputexture)
has the following [device timeline
properties](#device-timeline-property):

[`[[destroyed]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), initially `false`

: If the texture is destroyed, it can no longer be used in any
 operation, and its underlying memory can be freed.

[compute render extent](baseSize, mipLevel)

**Arguments:**

- [`GPUExtent3D`](#typedefdef-gpuextent3d) `baseSize`

- [`GPUSize32`](#typedefdef-gpusize32) `mipLevel`

**Returns:**
[`GPUExtent3DDict`](#dictdef-gpuextent3ddict)

[Device timeline](#device-timeline) steps:

1. Let `extent` be a new
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict) object.

2. Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to max(1,
 `baseSize`.[width](#gpuextent3d-width) ≫ `mipLevel`).

3. Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to max(1,
 `baseSize`.[height](#gpuextent3d-height) ≫ `mipLevel`).

4. Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to 1.

5. Return `extent`.

The [logical miplevel-specific texture
extent] of a [texture](#texture) is the size of the
[texture](#texture) in texels at a
specific miplevel. It is calculated by this procedure:

[Logical miplevel-specific texture
extent](descriptor, mipLevel)

**Arguments:**

- [`GPUTextureDescriptor`](#gputexturedescriptor) `descriptor`

- [`GPUSize32`](#typedefdef-gpusize32) `mipLevel`

**Returns:**
[`GPUExtent3DDict`](#dictdef-gpuextent3ddict)

1. Let `extent` be a new
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict) object.

2. If
 `descriptor`.[`dimension`](#dom-gputexturedescriptor-dimension) is:

 [`"1d"`](#dom-gputexturedimension-1d)

 : - Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to max(1,
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) ≫ `mipLevel`).

 - Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to 1.

 - Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to 1.

 [`"2d"`](#dom-gputexturedimension-2d)

 : - Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to max(1,
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) ≫ `mipLevel`).

 - Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to max(1,
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) ≫ `mipLevel`).

 - Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers).

 [`"3d"`](#dom-gputexturedimension-3d)

 : - Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to max(1,
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) ≫ `mipLevel`).

 - Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to max(1,
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) ≫ `mipLevel`).

 - Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to max(1,
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) ≫ `mipLevel`).

3. Return `extent`.

The [physical miplevel-specific texture
extent] of a [texture](#texture) is the size of the
[texture](#texture) in texels at a
specific miplevel that includes the possible extra padding to form
complete [texel blocks](#texel-block) in the [texture](#texture). It is calculated by this procedure:

[Physical miplevel-specific texture
extent](descriptor, mipLevel)

**Arguments:**

- [`GPUTextureDescriptor`](#gputexturedescriptor) `descriptor`

- [`GPUSize32`](#typedefdef-gpusize32) `mipLevel`

**Returns:**
[`GPUExtent3DDict`](#dictdef-gpuextent3ddict)

1. Let `extent` be a new
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict) object.

2. Let `logicalExtent` be [logical miplevel-specific texture
 extent](#logical-miplevel-specific-texture-extent)(`descriptor`, `mipLevel`).

3. If
 `descriptor`.[`dimension`](#dom-gputexturedescriptor-dimension) is:

 [`"1d"`](#dom-gputexturedimension-1d)

 : - Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to
 `logicalExtent`.[width](#gpuextent3d-width) rounded up to the nearest multiple of
 `descriptor`'s [texel block
 width](#texel-block-width).

 - Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to 1.

 - Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to 1.

 [`"2d"`](#dom-gputexturedimension-2d)

 : - Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to
 `logicalExtent`.[width](#gpuextent3d-width) rounded up to the nearest multiple of
 `descriptor`'s [texel block
 width](#texel-block-width).

 - Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to
 `logicalExtent`.[height](#gpuextent3d-height) rounded up to the nearest multiple of
 `descriptor`'s [texel block
 height](#texel-block-height).

 - Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to
 `logicalExtent`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers).

 [`"3d"`](#dom-gputexturedimension-3d)

 : - Set
 `extent`.[`width`](#dom-gpuextent3ddict-width) to
 `logicalExtent`.[width](#gpuextent3d-width) rounded up to the nearest multiple of
 `descriptor`'s [texel block
 width](#texel-block-width).

 - Set
 `extent`.[`height`](#dom-gpuextent3ddict-height) to
 `logicalExtent`.[height](#gpuextent3d-height) rounded up to the nearest multiple of
 `descriptor`'s [texel block
 height](#texel-block-height).

 - Set
 `extent`.[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) to
 `logicalExtent`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers).

4. Return `extent`.

#### 6.1.1. `GPUTextureDescriptor`

```
dictionary GPUTextureDescriptor
 : GPUObjectDescriptorBase {
 required GPUExtent3D size;
 GPUIntegerCoordinate mipLevelCount = 1;
 GPUSize32 sampleCount = 1;
 GPUTextureDimension dimension = "2d";
 required GPUTextureFormat format;
 required GPUTextureUsageFlags usage;
 sequence<GPUTextureFormat> viewFormats = ;
 GPUTextureViewDimension textureBindingViewDimension;
};
```

[`GPUTextureDescriptor`](#gputexturedescriptor) has the following members:

[`size`], of type [GPUExtent3D](#typedefdef-gpuextent3d)

: The width, height, and depth or layer count of the texture.

[`mipLevelCount`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate), defaulting to `1`

: The number of mip levels the texture will contain.

[`sampleCount`], of type [GPUSize32](#typedefdef-gpusize32), defaulting to `1`

: The sample count of the texture. A
 [`sampleCount`](#dom-gputexturedescriptor-samplecount) \> `1` indicates a multisampled texture.

[`dimension`], of type [GPUTextureDimension](#enumdef-gputexturedimension), defaulting to `"2d"`

: Whether the texture is one-dimensional, an array of two-dimensional
 layers, or three-dimensional.

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The format of the texture.

[`usage`], of type [GPUTextureUsageFlags](#typedefdef-gputextureusageflags)

: The allowed usages for the texture.

[`viewFormats`], of type sequence\<[GPUTextureFormat](#enumdef-gputextureformat)\>, defaulting to ``

: Specifies what view
 [`format`](#dom-gputextureviewdescriptor-format) values will be allowed when calling
 [`createView()`](#dom-gputexture-createview) on this texture (in addition to the texture's
 actual
 [`format`](#dom-gputexturedescriptor-format)).

 ::::
 ::: marker
 NOTE:
 :::

 Adding a format to this list may have a significant performance
 impact, so it is best to avoid adding formats unnecessarily.
 The actual performance impact is highly dependent on the target
 system; developers must test various systems to find out the impact
 on their particular application. For example, on some systems any
 texture with a
 [`format`](#dom-gputexturedescriptor-format) or
 [`viewFormats`](#dom-gputexturedescriptor-viewformats) entry including
 [`"rgba8unorm-srgb"`](#dom-gputextureformat-rgba8unorm-srgb) will perform less optimally than a
 [`"rgba8unorm"`](#dom-gputextureformat-rgba8unorm) texture which does not. Similar caveats exist for
 other formats and pairs of formats on other systems.
 ::::

 Formats in this list must be [texture view format
 compatible](#texture-view-format-compatible) with the texture format.

 :::
 Two
 [`GPUTextureFormat`](#enumdef-gputextureformat)s `format` and `viewFormat`
 are [texture view format compatible] on a given
 `device` if:
 - `format` equals `viewFormat`, or

 - `format` and `viewFormat` differ only in
 whether they are `srgb` formats (have the `-srgb` suffix) and
 `device`.[`[[features]]`](#dom-device-features-slot)
 [contains](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits).
 :::

[`textureBindingViewDimension`], of type [GPUTextureViewDimension](#enumdef-gputextureviewdimension)

: ::: compatmode
 On devices without
 [`"core-features-and-limits"`](#core-features-and-limits), views created from this texture must have this as
 their
 [`dimension`](#dom-gputextureviewdescriptor-dimension). If not specified, a default is chosen.
 :::

 On devices with
 [`"core-features-and-limits"`](#core-features-and-limits), this is ignored, and there is no such restriction.

```
enum GPUTextureDimension {
 "1d",
 "2d",
 "3d",
};
```

[`"1d"`]

: Specifies a texture that has one dimension, width.
 [`"1d"`](#dom-gputexturedimension-1d) textures cannot have mipmaps, be multisampled, use
 compressed or depth/stencil formats, or be used as a render target.

[`"2d"`]

: Specifies a texture that has a width and height, and may have
 layers.

[`"3d"`]

: Specifies a texture that has a width, height, and depth.
 [`"3d"`](#dom-gputexturedimension-3d) textures cannot be multisampled, and their format
 must support 3d textures (all [plain color
 formats](#plain-color-formats) and some [packed/compressed
 formats](#packed-formats)).

#### 6.1.2. Texture Usages

```
typedef [EnforceRange] unsigned long GPUTextureUsageFlags;
[Exposed=(Window, Worker), SecureContext]
namespace GPUTextureUsage {
 const GPUFlagsConstant COPY_SRC = 0x01;
 const GPUFlagsConstant COPY_DST = 0x02;
 const GPUFlagsConstant TEXTURE_BINDING = 0x04;
 const GPUFlagsConstant STORAGE_BINDING = 0x08;
 const GPUFlagsConstant RENDER_ATTACHMENT = 0x10;
};
```

The
[`GPUTextureUsage`](#namespacedef-gputextureusage) flags determine how a
[`GPUTexture`](#gputexture)
may be used after its creation:

[`COPY_SRC`]

: The texture can be used as the source of a copy operation.
 (Examples: as the `source` argument of a
 [`copyTextureToTexture()`](#dom-gpucommandencoder-copytexturetotexture) or
 [`copyTextureToBuffer()`](#dom-gpucommandencoder-copytexturetobuffer) call.)

[`COPY_DST`]

: The texture can be used as the destination of a copy or write
 operation. (Examples: as the `destination` argument of a
 [`copyTextureToTexture()`](#dom-gpucommandencoder-copytexturetotexture) or
 [`copyBufferToTexture()`](#dom-gpucommandencoder-copybuffertotexture) call, or as the target of a
 [`writeTexture()`](#dom-gpuqueue-writetexture) call.)

[`TEXTURE_BINDING`]

: The texture can be bound for use as a sampled texture in a shader
 (Example: as a bind group entry for a
 [`GPUTextureBindingLayout`](#dictdef-gputexturebindinglayout).)

[`STORAGE_BINDING`]

: The texture can be bound for use as a storage texture in a shader
 (Example: as a bind group entry for a
 [`GPUStorageTextureBindingLayout`](#dictdef-gpustoragetexturebindinglayout).)

[`RENDER_ATTACHMENT`]

: The texture can be used as a color or depth/stencil attachment in a
 render pass. (Example: as a
 [`GPURenderPassColorAttachment`](#dictdef-gpurenderpasscolorattachment).[`view`](#dom-gpurenderpasscolorattachment-view) or
 [`GPURenderPassDepthStencilAttachment`](#dictdef-gpurenderpassdepthstencilattachment).[`view`](#dom-gpurenderpassdepthstencilattachment-view).)

[maximum mipLevel count](`dimension`,
`size`)

**Arguments:**

- [`GPUTextureDimension`](#enumdef-gputexturedimension) `dimension`

- [`GPUTextureDimension`](#enumdef-gputexturedimension) `size`

1. Calculate the max dimension value `m`:

 - If `dimension` is:

 [`"1d"`](#dom-gputexturedimension-1d)

 : Return 1.

 [`"2d"`](#dom-gputexturedimension-2d)

 : Let `m` =
 max(`size`.[width](#gpuextent3d-width),
 `size`.[height](#gpuextent3d-height)).

 [`"3d"`](#dom-gputexturedimension-3d)

 : Let `m` =
 max(max(`size`.[width](#gpuextent3d-width),
 `size`.[height](#gpuextent3d-height)),
 `size`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers)).

2. Return floor(log~2~(`m`)) + 1.

#### 6.1.3. Texture Creation

[`createTexture(descriptor)`]

: Creates a [`GPUTexture`](#gputexture).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) this.
 **Arguments:**

 Arguments for the
 [GPUDevice.createTexture(descriptor)](#dom-gpudevice-createtexture) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUTextureDescriptor`](#gputexturedescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUTexture`](#gputexture) to create.
 **Returns:** [`GPUTexture`](#gputexture)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUExtent3D
 shape](#abstract-opdef-validate-gpuextent3d-shape)(`descriptor`.[`size`](#dom-gputexturedescriptor-size)).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture format
 required
 features](#abstract-opdef-validate-texture-format-required-features) of
 `descriptor`.[`format`](#dom-gputexturedescriptor-format) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 3. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture format
 required
 features](#abstract-opdef-validate-texture-format-required-features) of each element of
 `descriptor`.[`viewFormats`](#dom-gputexturedescriptor-viewformats) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 4. Let `t` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUTexture`](#gputexture), `descriptor`).

 5. Set
 `t`.[`width`](#dom-gputexture-width) to
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width).

 6. Set
 `t`.[`height`](#dom-gputexture-height) to
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height).

 7. Set
 `t`.[`depthOrArrayLayers`](#dom-gputexture-depthorarraylayers) to
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers).

 8. Set
 `t`.[`mipLevelCount`](#dom-gputexture-miplevelcount) to
 `descriptor`.[`mipLevelCount`](#dom-gputexturedescriptor-miplevelcount).

 9. Set
 `t`.[`sampleCount`](#dom-gputexture-samplecount) to
 `descriptor`.[`sampleCount`](#dom-gputexturedescriptor-samplecount).

 10. Set
 `t`.[`dimension`](#dom-gputexture-dimension) to
 `descriptor`.[`dimension`](#dom-gputexturedescriptor-dimension).

 11. Set
 `t`.[`format`](#dom-gputexture-format) to
 `descriptor`.[`format`](#dom-gputexturedescriptor-format).

 12. Set
 `t`.[`usage`](#dom-gputexture-usage) to
 `descriptor`.[`usage`](#dom-gputexturedescriptor-usage).

 13. ::: compatmode
 If
 `t`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 1. If
 `descriptor`.[`textureBindingViewDimension`](#dom-gputexturedescriptor-texturebindingviewdimension) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Set
 `t`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) to
 `descriptor`.[`textureBindingViewDimension`](#dom-gputexturedescriptor-texturebindingviewdimension).

 Otherwise, if
 `descriptor`.[`dimension`](#dom-gputexture-dimension) is:

 [`"1d"`](#dom-gputexturedimension-1d)

 : Set
 `t`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) to
 [`"1d"`](#dom-gputextureviewdimension-1d).

 [`"2d"`](#dom-gputexturedimension-2d)

 : If the [array layer
 count](#abstract-opdef-array-layer-count) of `t` is 1:

 - Set
 `t`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) to
 [`"2d"`](#dom-gputextureviewdimension-2d).

 Otherwise:

 - Set
 `t`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) to
 [`"2d-array"`](#dom-gputextureviewdimension-2d-array).

 [`"3d"`](#dom-gputexturedimension-3d)

 : Set
 `t`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) to
 [`"3d"`](#dom-gputextureviewdimension-3d).
 :::

 14. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 15. Return `t`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `t` and return.

 ::: validusage
 - [validating
 GPUTextureDescriptor](#abstract-opdef-validating-gputexturedescriptor)(`this`,
 `descriptor`) returns `true`.
 :::

 2. Set
 `t`.[`[[viewFormats]]`](#dom-gputexture-viewformats-slot) to
 `descriptor`.[`viewFormats`](#dom-gputexturedescriptor-viewformats).

 3. Create a device allocation for `t` where each block
 has an [equivalent texel
 representation](#equivalent-texel-representation) to a block with a bit representation of zero.

 If the allocation fails without side-effects, [generate an
 out-of-memory
 error](#abstract-opdef-generate-an-out-of-memory-error),
 [invalidate](#abstract-opdef-invalidate) `t`, and return.
 :::
 :::::

[validating
GPUTextureDescriptor](`this`,
`descriptor`):

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `this`

- [`GPUTextureDescriptor`](#gputexturedescriptor) `descriptor`

[Device timeline](#device-timeline) steps:

1. Let `limits` be
 `this`.[`[[limits]]`](#dom-device-limits-slot).

2. Return `true` if all of the following requirements are met, and
 `false` otherwise:

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - `descriptor`.[`usage`](#dom-gputexturedescriptor-usage) must not be 0.

 - `descriptor`.[`usage`](#dom-gputexturedescriptor-usage) must contain only bits present in
 `this`'s [allowed texture
 usages](#allowed-texture-usages).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width),
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height), and
 `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be \> zero.

 - `descriptor`.[`mipLevelCount`](#dom-gputexturedescriptor-miplevelcount) must be \> zero.

 - `descriptor`.[`sampleCount`](#dom-gputexturedescriptor-samplecount) must be either 1 or 4.

 - If
 `descriptor`.[`dimension`](#dom-gputexturedescriptor-dimension) is:

 [`"1d"`](#dom-gputexturedimension-1d)

 : - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) must be ≤
 `limits`.[`maxTextureDimension1D`](#dom-supported-limits-maxtexturedimension1d).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) must be 1.

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be 1.

 - `descriptor`.[`sampleCount`](#dom-gputexturedescriptor-samplecount) must be 1.

 - `descriptor`.[`format`](#dom-gputexturedescriptor-format) must not be a [compressed
 format](#compressed-format) or [depth-or-stencil
 format](#depth-or-stencil-format).

 [`"2d"`](#dom-gputexturedimension-2d)

 : - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) must be ≤
 `limits`.[`maxTextureDimension2D`](#dom-supported-limits-maxtexturedimension2d).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) must be ≤
 `limits`.[`maxTextureDimension2D`](#dom-supported-limits-maxtexturedimension2d).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be ≤
 `limits`.[`maxTextureArrayLayers`](#dom-supported-limits-maxtexturearraylayers).

 [`"3d"`](#dom-gputexturedimension-3d)

 : - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) must be ≤
 `limits`.[`maxTextureDimension3D`](#dom-supported-limits-maxtexturedimension3d).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) must be ≤
 `limits`.[`maxTextureDimension3D`](#dom-supported-limits-maxtexturedimension3d).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be ≤
 `limits`.[`maxTextureDimension3D`](#dom-supported-limits-maxtexturedimension3d).

 - `descriptor`.[`sampleCount`](#dom-gputexturedescriptor-samplecount) must be 1.

 - `descriptor`.[`format`](#dom-gputexturedescriptor-format) must support
 [`"3d"`](#dom-gputexturedimension-3d) textures according to [§ 26.1 Texture
 Format Capabilities](#texture-format-caps).

 - ::: compatmode
 If
 `this`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 1. If
 `descriptor`.[`textureBindingViewDimension`](#dom-gputexturedescriptor-texturebindingviewdimension) is
 [`"2d"`](#dom-gputextureviewdimension-2d),
 `this`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be 1.

 2. if
 `descriptor`.[`textureBindingViewDimension`](#dom-gputexturedescriptor-texturebindingviewdimension) is
 [`"cube"`](#dom-gputextureviewdimension-cube),
 `this`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be 6.

 this validation only applies to a user-specified
 textureBindingViewDimension. If no value is provided, the
 texture's textureBindingViewDimension is set as described in
 [`createTexture()`](#dom-gpudevice-createtexture). That algorithm cannot produce invalid values, so
 the above validation is not required.
 :::

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[width](#gpuextent3d-width) must be multiple of [texel block
 width](#texel-block-width).

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[height](#gpuextent3d-height) must be multiple of [texel block
 height](#texel-block-height).

 - If
 `descriptor`.[`sampleCount`](#dom-gputexturedescriptor-samplecount) \> 1:

 - `descriptor`.[`mipLevelCount`](#dom-gputexturedescriptor-miplevelcount) must be 1.

 - `descriptor`.[`size`](#dom-gputexturedescriptor-size).[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be 1.

 - `descriptor`.[`usage`](#dom-gputexturedescriptor-usage) must not include the
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) bit.

 - `descriptor`.[`usage`](#dom-gputexturedescriptor-usage) must include the
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) bit.

 - `descriptor`.[`format`](#dom-gputexturedescriptor-format) must support multisampling according to [§ 26.1
 Texture Format Capabilities](#texture-format-caps).

 - `descriptor`.[`mipLevelCount`](#dom-gputexturedescriptor-miplevelcount) must be ≤ [maximum mipLevel
 count](#abstract-opdef-maximum-miplevel-count)(`descriptor`.[`dimension`](#dom-gputexturedescriptor-dimension),
 `descriptor`.[`size`](#dom-gputexturedescriptor-size)).

 - If
 `descriptor`.[`usage`](#dom-gputexturedescriptor-usage) includes the
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) bit:

 - `descriptor`.[`format`](#dom-gputexturedescriptor-format) must be a [renderable
 format](#renderable).

 - `descriptor`.[`dimension`](#dom-gputexturedescriptor-dimension) must be either
 [`"2d"`](#dom-gputexturedimension-2d) or
 [`"3d"`](#dom-gputexturedimension-3d).

 - If
 `descriptor`.[`usage`](#dom-gputexturedescriptor-usage) includes the
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) bit:

 - `descriptor`.[`format`](#dom-gputexturedescriptor-format) must be listed in [§ 26.1.1 Plain color
 formats](#plain-color-formats) table with
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) capability for at least one access mode.

 - For each `viewFormat` in
 `descriptor`.[`viewFormats`](#dom-gputexturedescriptor-viewformats),
 `descriptor`.[`format`](#dom-gputexturedescriptor-format) and `viewFormat` must be [texture view
 format
 compatible](#texture-view-format-compatible) on device `this`.

 ::::
 ::: marker
 NOTE:
 :::

 Implementations may consider issuing a developer-visible warning
 if `viewFormat` is not compatible with any of the given
 [`usage`](#dom-gputexturedescriptor-usage) bits, as that `viewFormat` will be
 unusable.
 ::::
 :::

Creating a 16x16, RGBA, 2D texture
with one array layer and one mip level:

``` highlight
const texture = gpuDevice.createTexture({
 size: { width: 16, height: 16 },
 format: 'rgba8unorm',
 usage: GPUTextureUsage.TEXTURE_BINDING,
});
```

#### 6.1.4. Texture Destruction

An application that no longer requires a
[`GPUTexture`](#gputexture)
can choose to lose access to it before garbage collection by calling
[`destroy()`](#dom-gputexture-destroy).

 This allows the user agent to reclaim the GPU memory
associated with the
[`GPUTexture`](#gputexture)
once all previously submitted operations using it are complete.

[`GPUTexture`](#gputexture)
has the following methods:

[`destroy()`]

: Destroys the [`GPUTexture`](#gputexture).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUTexture`](#gputexture) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [device
 timeline](#device-timeline).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Set
 `this`.[`[[destroyed]]`](#dom-gputexture-destroyed-slot) to true.
 :::
 :::::

### 6.2. `GPUTextureView`

A [`GPUTextureView`](#gputextureview) is a view onto some subset of the [texture
subresources](#texture-subresources) defined by a particular
[`GPUTexture`](#gputexture).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUTextureView ;
GPUTextureView includes GPUObjectBase;
```

[`GPUTextureView`](#gputextureview) has the following [immutable
properties](#immutable-property):

[`[[texture]]`], readonly

: The [`GPUTexture`](#gputexture) into which this is a view.

[`[[descriptor]]`], readonly

: The
 [`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor) describing this texture view.

 All optional fields of
 [`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor) are defined.

[`[[renderExtent]]`], readonly

: For renderable views, this is the effective
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict) for rendering.

 this extent depends on the
 [`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel).

The set of [subresources] of a texture view
`view`, with
[`[[descriptor]]`](#dom-gputextureview-descriptor-slot) `desc`, is the subset of the subresources of
`view`.[`[[texture]]`](#dom-gputextureview-texture-slot) for which each subresource `s` satisfies the
following:

- The [mipmap level](#mipmap-level) of `s` is ≥
 `desc`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel) and \<
 `desc`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel) +
 `desc`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount).

- The [array layer](#array-layer)
 of `s` is ≥
 `desc`.[`baseArrayLayer`](#dom-gputextureviewdescriptor-basearraylayer) and \<
 `desc`.[`baseArrayLayer`](#dom-gputextureviewdescriptor-basearraylayer) +
 `desc`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount).

- The [aspect](#aspect) of
 `s` is in the [set of
 aspects](#gputextureaspect-set-of-aspects) of
 `desc`.[`aspect`](#dom-gputextureviewdescriptor-aspect).

Two [`GPUTextureView`](#gputextureview) objects are
[texture-view-aliasing] if and only if their sets of subresources
intersect.

#### 6.2.1. Texture View Creation

```
dictionary GPUTextureViewDescriptor
 : GPUObjectDescriptorBase {
 GPUTextureFormat format;
 GPUTextureViewDimension dimension;
 GPUTextureUsageFlags usage = 0;
 GPUTextureAspect aspect = "all";
 GPUIntegerCoordinate baseMipLevel = 0;
 GPUIntegerCoordinate mipLevelCount;
 GPUIntegerCoordinate baseArrayLayer = 0;
 GPUIntegerCoordinate arrayLayerCount;

 // Requires "texture-component-swizzle" feature.
 DOMString swizzle = "rgba";
};
```

[`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor) has the following members:

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The format of the texture view. Must be either the
 [`format`](#dom-gputexturedescriptor-format) of the texture or one of the
 [`viewFormats`](#dom-gputexturedescriptor-viewformats) specified during its creation.

[`dimension`], of type [GPUTextureViewDimension](#enumdef-gputextureviewdimension)

: The dimension to view the texture as.

[`usage`], of type [GPUTextureUsageFlags](#typedefdef-gputextureusageflags), defaulting to `0`

: The allowed
 [`usage(s)`](#namespacedef-gputextureusage) for the texture view. Must be a subset of the
 [`usage`](#dom-gputexture-usage) flags of the texture. If 0, defaults to the full
 set of
 [`usage`](#dom-gputexture-usage) flags of the texture.

 If the view's
 [`format`](#dom-gputextureviewdescriptor-format) doesn't support all of the texture's
 [`usage`](#dom-gputexturedescriptor-usage)s, the default will fail, and the view's
 [`usage`](#dom-gputextureviewdescriptor-usage) must be specified explicitly.

[`aspect`], of type [GPUTextureAspect](#enumdef-gputextureaspect), defaulting to `"all"`

: Which
 [`aspect(s)`](#enumdef-gputextureaspect) of the texture are accessible to the texture view.

[`baseMipLevel`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate), defaulting to `0`

: The first (most detailed) mipmap level accessible to the texture
 view.

[`mipLevelCount`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate)

: How many mipmap levels, starting with
 [`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel), are accessible to the texture view.

[`baseArrayLayer`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate), defaulting to `0`

: The index of the first array layer accessible to the texture view.

[`arrayLayerCount`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate)

: How many array layers, starting with
 [`baseArrayLayer`](#dom-gputextureviewdescriptor-basearraylayer), are accessible to the texture view.

[`swizzle`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `"rgba"`

: A string of length four, with each character mapping to the texture
 view's red/green/blue/alpha channels, respectively.

 When accessed by a shader, the red/green/blue/alpha channels are
 replaced by the value corresponding to the component specified in
 `swizzle[0]`, `swizzle[1]`, `swizzle[2]`, and `swizzle[3]`,
 respectively:

 - `"r"`: Take its value from the red channel of the texture.

 - `"g"`: Take its value from the green channel of the texture.

 - `"b"`: Take its value from the blue channel of the texture.

 - `"a"`: Take its value from the alpha channel of the texture.

 - `"0"`: Force its value to 0.

 - `"1"`: Force its value to 1.

 Requires the
 [`"texture-component-swizzle"`](#dom-gpufeaturename-texture-component-swizzle) feature to be enabled.

```
enum GPUTextureViewDimension {
 "1d",
 "2d",
 "2d-array",
 "cube",
 "cube-array",
 "3d",
};
```

[`"1d"`]

: The texture is viewed as a 1-dimensional image.

 Corresponding WGSL types:

 - `texture_1d`

 - `texture_storage_1d`

[`"2d"`]

: The texture is viewed as a single 2-dimensional image.

 Corresponding WGSL types:

 - `texture_2d`

 - `texture_storage_2d`

 - `texture_multisampled_2d`

 - `texture_depth_2d`

 - `texture_depth_multisampled_2d`

[`"2d-array"`]

: The texture view is viewed as an array of 2-dimensional images.

 Corresponding WGSL types:

 - `texture_2d_array`

 - `texture_storage_2d_array`

 - `texture_depth_2d_array`

[`"cube"`]

: The texture is viewed as a cubemap.

 The view has 6 array layers, each corresponding to a face of the
 cube in the order `[+X, -X, +Y, -Y, +Z, -Z]` and the following
 orientations:

 <figure>

 <figcaption>Cubemap faces. The +U/+V axes indicate the individual faces'
 texture coordinates, and thus the <a href="#texel-copy"
 id="ref-for-texel-copy" data->texel copy</a> memory
 layout of each face.</figcaption>
 </figure>

 When viewed from the inside, this results in a
 left-handed coordinate system where +X is right, +Y is up, and +Z is
 forward.

 Sampling is done seamlessly across the faces of the cubemap.

 Corresponding WGSL types:

 - `texture_cube`

 - `texture_depth_cube`

[`"cube-array"`]

: The texture is viewed as a packed array of `n` cubemaps,
 each with 6 array layers behaving like one
 [`"cube"`](#dom-gputextureviewdimension-cube) view, for 6`n` array layers in total.

 Corresponding WGSL types:

 - `texture_cube_array`

 - `texture_depth_cube_array`

[`"3d"`]

: The texture is viewed as a 3-dimensional image.

 Corresponding WGSL types:

 - `texture_3d`

 - `texture_storage_3d`

Each [`GPUTextureAspect`] value corresponds to a set of
[aspects](#aspect). The [set of
aspects] are defined for
each value below.

```
enum GPUTextureAspect {
 "all",
 "stencil-only",
 "depth-only",
};
```

[`"all"`]

: All available aspects of the texture format will be accessible to
 the texture view. For color formats the color aspect will be
 accessible. For [combined depth-stencil
 format](#combined-depth-stencil-format)s both the depth and stencil aspects will be
 accessible. [Depth-or-stencil
 format](#depth-or-stencil-format)s with a single aspect will only make that aspect
 accessible.

 The [set of
 aspects](#gputextureaspect-set-of-aspects) is \[[color](#aspect-color), [depth](#aspect-depth), [stencil](#aspect-stencil)\].

[`"stencil-only"`]

: Only the stencil aspect of a [depth-or-stencil
 format](#depth-or-stencil-format) format will be accessible to the texture view.

 The [set of
 aspects](#gputextureaspect-set-of-aspects) is
 \[[stencil](#aspect-stencil)\].

[`"depth-only"`]

: Only the depth aspect of a [depth-or-stencil
 format](#depth-or-stencil-format) format will be accessible to the texture view.

 The [set of
 aspects](#gputextureaspect-set-of-aspects) is \[[depth](#aspect-depth)\].

<!-- -->

[`createView(descriptor)`]

: Creates a
 [`GPUTextureView`](#gputextureview).

 ::::
 ::: marker
 NOTE:
 :::

 By default
 [`createView()`](#dom-gputexture-createview) will create a view with a dimension that can
 represent the entire texture. For example, calling
 [`createView()`](#dom-gputexture-createview) without specifying a
 [`dimension`](#dom-gputextureviewdescriptor-dimension) on a
 [`"2d"`](#dom-gputexturedimension-2d) texture with more than one layer will create a
 [`"2d-array"`](#dom-gputextureviewdimension-2d-array)
 [`GPUTextureView`](#gputextureview), even if an
 [`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) of 1 is specified.
 For textures created from sources where the layer count is unknown
 at the time of development it is recommended that calls to
 [`createView()`](#dom-gputexture-createview) are provided with an explicit
 [`dimension`](#dom-gputextureviewdescriptor-dimension) to ensure shader compatibility.
 ::::

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUTexture`](#gputexture) `this`.
 **Arguments:**

 Arguments for the
 [GPUTexture.createView(descriptor)](#dom-gputexture-createview) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor)
 [✘]
 [✔]
 Description of the
 [`GPUTextureView`](#gputextureview) to create.
 **Returns:** `view`, of type
 [`GPUTextureView`](#gputextureview).

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture format
 required
 features](#abstract-opdef-validate-texture-format-required-features) of
 `descriptor`.[`format`](#dom-gputextureviewdescriptor-format) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate swizzle
 string](#abstract-opdef-validate-swizzle-string) of
 `descriptor`.[`swizzle`](#dom-gputextureviewdescriptor-swizzle).

 3. Let `view` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUTextureView`](#gputextureview), `descriptor`).

 4. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 5. Return `view`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Set `descriptor` to the result of [resolving
 GPUTextureViewDescriptor
 defaults](#abstract-opdef-resolving-gputextureviewdescriptor-defaults) for `this` with
 `descriptor`.

 2. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `view` and return.

 ::: validusage
 - `this` is [valid to use
 with](#abstract-opdef-valid-to-use-with)
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 - `descriptor`.[`aspect`](#dom-gputextureviewdescriptor-aspect) must be present in
 `this`.[`format`](#dom-gputexture-format).

 - If the
 `descriptor`.[`aspect`](#dom-gputextureviewdescriptor-aspect) is
 [`"all"`](#dom-gputextureaspect-all):

 - `descriptor`.[`format`](#dom-gputextureviewdescriptor-format) must equal either
 `this`.[`format`](#dom-gputexture-format) or one of the formats in
 `this`.[`[[viewFormats]]`](#dom-gputexture-viewformats-slot).

 Otherwise:

 - `descriptor`.[`format`](#dom-gputextureviewdescriptor-format) must equal the result of [resolving
 GPUTextureAspect](#abstract-opdef-resolving-gputextureaspect)(
 `this`.[`format`](#dom-gputexture-format),
 `descriptor`.[`aspect`](#dom-gputextureviewdescriptor-aspect)).

 - If
 `descriptor`.[`swizzle`](#dom-gputextureviewdescriptor-swizzle) is not `"rgba"`,
 [`"texture-component-swizzle"`](#dom-gpufeaturename-texture-component-swizzle) must be [enabled
 for](#enabled-for)
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 - `descriptor`.[`usage`](#dom-gputextureviewdescriptor-usage) must be a subset of
 `this`.[`usage`](#dom-gputexture-usage).

 - If
 `descriptor`.[`usage`](#dom-gputextureviewdescriptor-usage) includes the
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) bit:

 - `descriptor`.[`format`](#dom-gputextureviewdescriptor-format) must be a [renderable
 format](#renderable).

 - If
 `descriptor`.[`usage`](#dom-gputextureviewdescriptor-usage) includes the
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) bit:

 - `descriptor`.[`format`](#dom-gputextureviewdescriptor-format) must be listed in [§ 26.1.1 Plain color
 formats](#plain-color-formats) table with
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) capability for at least one access mode.

 - `descriptor`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) must be \> 0.

 - `descriptor`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel) +
 `descriptor`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) must be ≤
 `this`.[`mipLevelCount`](#dom-gputexture-miplevelcount).

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be \> 0.

 - `descriptor`.[`baseArrayLayer`](#dom-gputextureviewdescriptor-basearraylayer) +
 `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be ≤ the [array layer
 count](#abstract-opdef-array-layer-count) of `this`.

 - If
 `this`.[`sampleCount`](#dom-gputexture-samplecount) \> 1,
 `descriptor`.[`dimension`](#dom-gputextureviewdescriptor-dimension) must be
 [`"2d"`](#dom-gputextureviewdimension-2d).

 - If
 `descriptor`.[`dimension`](#dom-gputextureviewdescriptor-dimension) is:

 [`"1d"`](#dom-gputextureviewdimension-1d)

 : - `this`.[`dimension`](#dom-gputexture-dimension) must be
 [`"1d"`](#dom-gputexturedimension-1d).

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be `1`.

 [`"2d"`](#dom-gputextureviewdimension-2d)

 : - `this`.[`dimension`](#dom-gputexture-dimension) must be
 [`"2d"`](#dom-gputexturedimension-2d).

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be `1`.

 [`"2d-array"`](#dom-gputextureviewdimension-2d-array)

 : - `this`.[`dimension`](#dom-gputexture-dimension) must be
 [`"2d"`](#dom-gputexturedimension-2d).

 [`"cube"`](#dom-gputextureviewdimension-cube)

 : - `this`.[`dimension`](#dom-gputexture-dimension) must be
 [`"2d"`](#dom-gputexturedimension-2d).

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be `6`.

 - `this`.[`width`](#dom-gputexture-width) must equal
 `this`.[`height`](#dom-gputexture-height).

 [`"cube-array"`](#dom-gputextureviewdimension-cube-array)

 : - `this`.[`dimension`](#dom-gputexture-dimension) must be
 [`"2d"`](#dom-gputexturedimension-2d).

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be a multiple of `6`.

 - `this`.[`width`](#dom-gputexture-width) must equal
 `this`.[`height`](#dom-gputexture-height).

 - ::: compatmode
 [`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot) must
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits).
 :::

 [`"3d"`](#dom-gputextureviewdimension-3d)

 : - `this`.[`dimension`](#dom-gputexture-dimension) must be
 [`"3d"`](#dom-gputexturedimension-3d).

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be `1`.
 :::

 3. Let `view` be a new
 [`GPUTextureView`](#gputextureview) object.

 4. Set
 `view`.[`[[texture]]`](#dom-gputextureview-texture-slot) to `this`.

 5. Set
 `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot) to `descriptor`.

 6. If
 `descriptor`.[`usage`](#dom-gputextureviewdescriptor-usage) contains
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment):

 1. Let `renderExtent` be [compute render
 extent](#abstract-opdef-compute-render-extent)(\[`this`.[`width`](#dom-gputexture-width),
 `this`.[`height`](#dom-gputexture-height),
 `this`.[`depthOrArrayLayers`](#dom-gputexture-depthorarraylayers)\],
 `descriptor`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel)).

 2. Set
 `view`.[`[[renderExtent]]`](#dom-gputextureview-renderextent-slot) to `renderExtent`.
 :::
 :::::

When [resolving GPUTextureViewDescriptor
defaults] for
[`GPUTextureView`](#gputextureview) `texture` with a
[`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor) `descriptor`, run the following [device
timeline](#device-timeline)
steps:

1. Let `resolved` be a copy of `descriptor`.

2. If
 `resolved`.[`format`](#dom-gputextureviewdescriptor-format) is not
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Let `format` be the result of [resolving
 GPUTextureAspect](#abstract-opdef-resolving-gputextureaspect)(
 [`format`](#dom-gputexture-format),
 `descriptor`.[`aspect`](#dom-gputextureviewdescriptor-aspect)).

 2. If `format` is `null`:

 - Set
 `resolved`.[`format`](#dom-gputextureviewdescriptor-format) to
 `texture`.[`format`](#dom-gputexture-format).

 Otherwise:

 - Set
 `resolved`.[`format`](#dom-gputextureviewdescriptor-format) to `format`.

3. If
 `resolved`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) is not
 [provided](https://infra.spec.whatwg.org/#map-exists): set
 `resolved`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) to
 `texture`.[`mipLevelCount`](#dom-gputexture-miplevelcount) −
 `resolved`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel).

4. If
 `resolved`.[`dimension`](#dom-gputextureviewdescriptor-dimension) is not
 [provided](https://infra.spec.whatwg.org/#map-exists) and
 `texture`.[`dimension`](#dom-gputexture-dimension) is:

 [`"1d"`](#dom-gputexturedimension-1d)

 : Set
 `resolved`.[`dimension`](#dom-gputextureviewdescriptor-dimension) to
 [`"1d"`](#dom-gputextureviewdimension-1d).

 [`"2d"`](#dom-gputexturedimension-2d)

 : If the [array layer
 count](#abstract-opdef-array-layer-count) of `texture` is 1:

 - Set
 `resolved`.[`dimension`](#dom-gputextureviewdescriptor-dimension) to
 [`"2d"`](#dom-gputextureviewdimension-2d).

 Otherwise:

 - Set
 `resolved`.[`dimension`](#dom-gputextureviewdescriptor-dimension) to
 [`"2d-array"`](#dom-gputextureviewdimension-2d-array).

 [`"3d"`](#dom-gputexturedimension-3d)

 : Set
 `resolved`.[`dimension`](#dom-gputextureviewdescriptor-dimension) to
 [`"3d"`](#dom-gputextureviewdimension-3d).

5. If
 `resolved`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) is not
 [provided](https://infra.spec.whatwg.org/#map-exists) and
 `resolved`.[`dimension`](#dom-gputextureviewdescriptor-dimension) is:

 [`"1d"`](#dom-gputextureviewdimension-1d), [`"2d"`](#dom-gputextureviewdimension-2d), or [`"3d"`](#dom-gputextureviewdimension-3d)

 : Set
 `resolved`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) to `1`.

 [`"cube"`](#dom-gputextureviewdimension-cube)

 : Set
 `resolved`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) to `6`.

 [`"2d-array"`](#dom-gputextureviewdimension-2d-array) or [`"cube-array"`](#dom-gputextureviewdimension-cube-array)

 : Set
 `resolved`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) to the [array layer
 count](#abstract-opdef-array-layer-count) of `texture` −
 `resolved`.[`baseArrayLayer`](#dom-gputextureviewdescriptor-basearraylayer).

6. If
 `resolved`.[`usage`](#dom-gputextureviewdescriptor-usage) is `0`: set
 `resolved`.[`usage`](#dom-gputextureviewdescriptor-usage) to
 `texture`.[`usage`](#dom-gputexture-usage).

7. Return `resolved`.

To determine the [array layer count] of
[`GPUTexture`](#gputexture)
`texture`, run the following steps:

1. If
 `texture`.[`dimension`](#dom-gputexture-dimension) is:

 [`"1d"`](#dom-gputexturedimension-1d) or [`"3d"`](#dom-gputexturedimension-3d)

 : Return `1`.

 [`"2d"`](#dom-gputexturedimension-2d)

 : Return
 `texture`.[`depthOrArrayLayers`](#dom-gputexture-depthorarraylayers).

To [Validate swizzle string] of a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) `swizzle`, run the following [content
timeline](#content-timeline) steps:

1. If `swizzle` does not match the
 [\[ECMAScript\]](#biblio-ecmascript "ECMAScript Language Specification")
 regexp `^[rgba01]{4}$`:

 1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

### 6.3. Texture Formats

The name of the format specifies the order of components, bits per
component, and data type for the component.

- `r`, `g`, `b`, `a` = red, green, blue, alpha

- `unorm` = unsigned normalized

- `snorm` = signed normalized

- `uint` = unsigned int

- `sint` = signed int

- `float` = floating point

If the format has the `-srgb` suffix, then sRGB conversions from gamma
to linear and vice versa are applied during the reading and writing of
color values in the shader. Compressed texture formats are provided by
[features](#feature). Their naming
should follow the convention here, with the texture name as a prefix.
e.g. `etc2-rgba8unorm`.

The [texel block] is a single addressable element of the textures in
pixel-based
[`GPUTextureFormat`](#enumdef-gputextureformat)s, and a single compressed block of the textures in
block-based compressed
[`GPUTextureFormat`](#enumdef-gputextureformat)s.

The [texel block width] and [texel block height] specifies the dimension of
one [texel block](#texel-block).

- For pixel-based
 [`GPUTextureFormat`](#enumdef-gputextureformat)s, the [texel block
 width](#texel-block-width) and [texel block
 height](#texel-block-height) are always 1.

- For block-based compressed
 [`GPUTextureFormat`](#enumdef-gputextureformat)s, the [texel block
 width](#texel-block-width) is the number of texels in each row of one [texel
 block](#texel-block), and the
 [texel block height](#texel-block-height) is the number of texel rows in one [texel
 block](#texel-block). See
 [§ 26.1 Texture Format Capabilities](#texture-format-caps) for an
 exhaustive list of values for every texture format.

The [texel block copy footprint] of an
[aspect](#aspect) of a
[`GPUTextureFormat`](#enumdef-gputextureformat) is the number of bytes one texel block occupies during
a [texel copy](#texel-copy), if
applicable.

 The [texel block memory cost] of a
[`GPUTextureFormat`](#enumdef-gputextureformat) is the number of bytes needed to store one [texel
block](#texel-block). It is not
fully defined for all formats. **This value is informative and
non-normative.**

```
enum GPUTextureFormat {
 // 8-bit formats
 "r8unorm",
 "r8snorm",
 "r8uint",
 "r8sint",

 // 16-bit formats
 "r16unorm",
 "r16snorm",
 "r16uint",
 "r16sint",
 "r16float",
 "rg8unorm",
 "rg8snorm",
 "rg8uint",
 "rg8sint",

 // 32-bit formats
 "r32uint",
 "r32sint",
 "r32float",
 "rg16unorm",
 "rg16snorm",
 "rg16uint",
 "rg16sint",
 "rg16float",
 "rgba8unorm",
 "rgba8unorm-srgb",
 "rgba8snorm",
 "rgba8uint",
 "rgba8sint",
 "bgra8unorm",
 "bgra8unorm-srgb",
 // Packed 32-bit formats
 "rgb9e5ufloat",
 "rgb10a2uint",
 "rgb10a2unorm",
 "rg11b10ufloat",

 // 64-bit formats
 "rg32uint",
 "rg32sint",
 "rg32float",
 "rgba16unorm",
 "rgba16snorm",
 "rgba16uint",
 "rgba16sint",
 "rgba16float",

 // 128-bit formats
 "rgba32uint",
 "rgba32sint",
 "rgba32float",

 // Depth/stencil formats
 "stencil8",
 "depth16unorm",
 "depth24plus",
 "depth24plus-stencil8",
 "depth32float",

 // "depth32float-stencil8" feature
 "depth32float-stencil8",

 // BC compressed formats usable if "texture-compression-bc" is both
 // supported by the device/user agent and enabled in requestDevice.
 "bc1-rgba-unorm",
 "bc1-rgba-unorm-srgb",
 "bc2-rgba-unorm",
 "bc2-rgba-unorm-srgb",
 "bc3-rgba-unorm",
 "bc3-rgba-unorm-srgb",
 "bc4-r-unorm",
 "bc4-r-snorm",
 "bc5-rg-unorm",
 "bc5-rg-snorm",
 "bc6h-rgb-ufloat",
 "bc6h-rgb-float",
 "bc7-rgba-unorm",
 "bc7-rgba-unorm-srgb",

 // ETC2 compressed formats usable if "texture-compression-etc2" is both
 // supported by the device/user agent and enabled in requestDevice.
 "etc2-rgb8unorm",
 "etc2-rgb8unorm-srgb",
 "etc2-rgb8a1unorm",
 "etc2-rgb8a1unorm-srgb",
 "etc2-rgba8unorm",
 "etc2-rgba8unorm-srgb",
 "eac-r11unorm",
 "eac-r11snorm",
 "eac-rg11unorm",
 "eac-rg11snorm",

 // ASTC compressed formats usable if "texture-compression-astc" is both
 // supported by the device/user agent and enabled in requestDevice.
 "astc-4x4-unorm",
 "astc-4x4-unorm-srgb",
 "astc-5x4-unorm",
 "astc-5x4-unorm-srgb",
 "astc-5x5-unorm",
 "astc-5x5-unorm-srgb",
 "astc-6x5-unorm",
 "astc-6x5-unorm-srgb",
 "astc-6x6-unorm",
 "astc-6x6-unorm-srgb",
 "astc-8x5-unorm",
 "astc-8x5-unorm-srgb",
 "astc-8x6-unorm",
 "astc-8x6-unorm-srgb",
 "astc-8x8-unorm",
 "astc-8x8-unorm-srgb",
 "astc-10x5-unorm",
 "astc-10x5-unorm-srgb",
 "astc-10x6-unorm",
 "astc-10x6-unorm-srgb",
 "astc-10x8-unorm",
 "astc-10x8-unorm-srgb",
 "astc-10x10-unorm",
 "astc-10x10-unorm-srgb",
 "astc-12x10-unorm",
 "astc-12x10-unorm-srgb",
 "astc-12x12-unorm",
 "astc-12x12-unorm-srgb",
};
```

The depth component of the
[`"depth24plus"`](#dom-gputextureformat-depth24plus) and
[`"depth24plus-stencil8"`](#dom-gputextureformat-depth24plus-stencil8) formats may be implemented as either a [24-bit
depth](#24-bit-depth) value or a
[`"depth32float"`](#dom-gputextureformat-depth32float) value.

The
[`stencil8`](#dom-gputextureformat-stencil8) format may be implemented as either a real
\"stencil8\", or \"depth24stencil8\", where the depth aspect is hidden
and inaccessible.

NOTE:

While the precision of depth32float channels is strictly higher than the
precision of [24-bit depth](#24-bit-depth) channels for all values in the representable range (0.0
to 1.0), note that the set of representable values is not an exact
superset.

- For [24-bit depth](#24-bit-depth), 1 ULP has a constant value of 1 / (2^24^ − 1).

- For depth32float, 1 ULP has a variable value no greater than 1 /
 (2^24^).

A format is [renderable] if it is either a [color
renderable format], or a [depth-or-stencil
format](#depth-or-stencil-format). If a format is listed in [§ 26.1.1 Plain color
formats](#plain-color-formats) with
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) capability, it is a color renderable format. Any other
format is not a color renderable format. All [depth-or-stencil
formats](#depth-or-stencil-format) are renderable.

A [renderable format](#renderable)
is also [blendable] if it can be used with
render pipeline blending. See [§ 26.1 Texture Format
Capabilities](#texture-format-caps).

A format is [filterable] if it supports the
[`GPUTextureSampleType`](#enumdef-gputexturesampletype)
[`"float"`](#dom-gputexturesampletype-float) (not just
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)); that is, it can be used with
[`"filtering"`](#dom-gpusamplerbindingtype-filtering) [`GPUSampler`](#gpusampler)s. See [§ 26.1 Texture Format
Capabilities](#texture-format-caps).

[resolving GPUTextureAspect](format, aspect)

**Arguments:**

- [`GPUTextureFormat`](#enumdef-gputextureformat) `format`

- [`GPUTextureAspect`](#enumdef-gputextureaspect) `aspect`

**Returns:**
[`GPUTextureFormat`](#enumdef-gputextureformat) or `null`

1. If `aspect` is:

 [`"all"`](#dom-gputextureaspect-all)

 : Return `format`.

 [`"depth-only"`](#dom-gputextureaspect-depth-only)\
 [`"stencil-only"`](#dom-gputextureaspect-stencil-only)

 : If `format` is a depth-stencil-format: Return the
 [aspect-specific
 format](#aspect-specific-format) of `format` according to [§ 26.1.2
 Depth-stencil formats](#depth-formats) or `null` if the aspect
 is not present in `format`.

2. Return `null`.

Use of some texture formats require a feature to be enabled on the
[`GPUDevice`](#gpudevice).
Because new formats can be added to the specification, those enum values
might not be known by the implementation. In order to normalize behavior
across implementations, attempting to use a format that requires a
feature will throw an exception if the associated feature is not enabled
on the device. This makes the behavior the same as when the format is
unknown to the implementation.

See [§ 26.1 Texture Format Capabilities](#texture-format-caps) for
information about which
[`GPUTextureFormat`](#enumdef-gputextureformat)s require features.

To [Validate texture format required
features] of a
[`GPUTextureFormat`](#enumdef-gputextureformat) `format`\
with logical [device](#device)
`device`, run the following [content
timeline](#content-timeline) steps:

1. If `format` requires a feature and
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain) the feature:

 1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

### 6.4. `GPUExternalTexture`

A
[`GPUExternalTexture`](#gpuexternaltexture) is a sampleable 2D texture wrapping an external video
frame. It is an immutable snapshot; its contents cannot change over
time, either from inside WebGPU (it is only sampleable) or from outside
WebGPU (e.g. due to video frame advancement).

[`GPUExternalTexture`](#gpuexternaltexture)s can be bound into bind groups via the
[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture) bind group layout entry member. Note that member uses
several binding slots, as defined there.

NOTE:

[`GPUExternalTexture`](#gpuexternaltexture) *can* be implemented without creating a copy of the
imported source, but this depends
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) factors. Ownership of the underlying representation may
either be exclusive or shared with other owners (such as a video
decoder), but this is not visible to the application.

The underlying representation of an external texture is unobservable
(except for precise sampling behavior), but typically may include:

- Up to three 2D planes of data (e.g. RGBA, Y+UV, Y+U+V).

- Metadata for converting coordinates before reading from those planes
 (crop and rotation).

- Metadata for converting values into the specified output color space
 (matrices, gammas, 3D LUT).

The configuration used internally by an implementation may be
inconsistent across time, systems, user agents, media sources, or even
frames within a single video source. In order to account for many
possible representations, the binding conservatively uses the following,
for *each* external texture:

- three sampled texture bindings (for up to 3 planes),

- one sampled texture binding for a 3D LUT,

- one sampler binding to sample the 3D LUT, and

- one uniform buffer binding for metadata.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUExternalTexture ;
GPUExternalTexture includes GPUObjectBase;
```

[`GPUExternalTexture`](#gpuexternaltexture) has the following [immutable
properties](#immutable-property):

[`[[descriptor]]`], of type [`GPUExternalTextureDescriptor`](#dictdef-gpuexternaltexturedescriptor), readonly

: The descriptor with which the texture was created.

[`GPUExternalTexture`](#gpuexternaltexture) has the following [immutable
properties](#immutable-property):

[`[[expired]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), initially `false`

: Indicates whether the object has expired (can no longer be used).

 Unlike `[[destroyed]]` slots, which are similar,
 this can change from `true` back to `false`.

#### 6.4.1. Importing External Textures

An external texture is created from an external video object using
[`importExternalTexture()`](#dom-gpudevice-importexternaltexture).

An external texture created from an
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) expires (is destroyed) automatically in a task after it
is imported, instead of manually or upon garbage collection like other
resources. When an external texture expires, its
[`[[expired]]`](#dom-gpuexternaltexture-expired-slot) slot changes to `true`.

An external texture created from a
[`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe) expires (is destroyed) when, and only when, the source
[`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe) is
[closed](https://www.w3.org/TR/webcodecs/#close-videoframe), either explicitly by
[`close()`](https://w3c.github.io/webcodecs/#dom-videoframe-close), or by other means.

 As noted in
[`decode()`](https://w3c.github.io/webcodecs/#dom-videodecoder-decode), authors **should** call
[`close()`](https://w3c.github.io/webcodecs/#dom-videoframe-close) on output
[`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe)s to avoid decoder stalls. If an imported
[`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe) is dropped without being closed, the imported
[`GPUExternalTexture`](#gpuexternaltexture) object will keep it alive until it is also dropped. The
[`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe) cannot be garbage collected until both objects are
dropped. Garbage collection is unpredictable, so this may still stall
the video decoder.

Once the
[`GPUExternalTexture`](#gpuexternaltexture) expires,
[`importExternalTexture()`](#dom-gpudevice-importexternaltexture) must be called again. However, the user agent may
un-expire and return the same
[`GPUExternalTexture`](#gpuexternaltexture) again, instead of creating a new one. This will
commonly happen unless the execution of the application is scheduled to
match the video's frame rate (e.g. using `requestVideoFrameCallback()`).
If the same object is returned again, it will compare equal, and
[`GPUBindGroup`](#gpubindgroup)s,
[`GPURenderBundle`](#gpurenderbundle)s, etc. referencing the previous object can still be
used.

```
dictionary GPUExternalTextureDescriptor
 : GPUObjectDescriptorBase {
 required (HTMLVideoElement or VideoFrame) source;
 PredefinedColorSpace colorSpace = "srgb";
};
```

[`GPUExternalTextureDescriptor`](#dictdef-gpuexternaltexturedescriptor) dictionaries have the following members:

[`source`], of type `(HTMLVideoElement or VideoFrame)`

: The video source to import the external texture from. Source size is
 determined as described by the [external source
 dimensions](#external-source-dimensions) table.

[`colorSpace`], of type [PredefinedColorSpace](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace), defaulting to `"srgb"`

: The color space the image contents of
 [`source`](#dom-gpuexternaltexturedescriptor-source) will be converted into when reading.

<!-- -->

[`importExternalTexture(descriptor)`]

: Creates a
 [`GPUExternalTexture`](#gpuexternaltexture) wrapping the provided image source.

 ::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.importExternalTexture(descriptor)](#dom-gpudevice-importexternaltexture) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUExternalTextureDescriptor`](#dictdef-gpuexternaltexturedescriptor)
 [✘]
 [✘]
 Provides the external image source object (and any creation
 options).
 **Returns:**
 [`GPUExternalTexture`](#gpuexternaltexture)

 [Content timeline](#content-timeline) steps:

 1. Let `source` be
 `descriptor`.[`source`](#dom-gpuexternaltexturedescriptor-source).

 2. If the current image contents of `source` are the
 same as the most recent
 [`importExternalTexture()`](#dom-gpudevice-importexternaltexture) call with the same `descriptor`
 (ignoring
 [`label`](#dom-gpuobjectdescriptorbase-label)), and the user agent chooses to reuse it:

 1. Let `previousResult` be the
 [`GPUExternalTexture`](#gpuexternaltexture) returned previously.

 2. Set
 `previousResult`.[`[[expired]]`](#dom-gpuexternaltexture-expired-slot) to `false`, renewing ownership of the
 underlying resource.

 3. Let `result` be `previousResult`.

 This allows the application to detect duplicate
 imports and avoid re-creating dependent objects (such as
 [`GPUBindGroup`](#gpubindgroup)s). Implementations still need to be able to
 handle a single frame being wrapped by multiple
 [`GPUExternalTexture`](#gpuexternaltexture), since import metadata like
 [`colorSpace`](#dom-gpuexternaltexturedescriptor-colorspace) can change even for the same frame.

 Otherwise:

 1. If `source` [is not
 origin-clean](https://html.spec.whatwg.org/multipage/canvas.html#the-image-argument-is-not-origin-clean), throw a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) and return.

 2. Let `usability` be
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [check the usability
 of the image
 argument](https://html.spec.whatwg.org/multipage/canvas.html#check-the-usability-of-the-image-argument)(`source`).

 3. If `usability` is not `good`:

 1. [Generate a validation
 error](#abstract-opdef-generate-a-validation-error).

 2. Return an
 [invalidated](#abstract-opdef-invalidate)
 [`GPUExternalTexture`](#gpuexternaltexture).

 4. Let `data` be the result of converting the
 current image contents of `source` into the color
 space
 `descriptor`.[`colorSpace`](#dom-gpuexternaltexturedescriptor-colorspace) with unpremultiplied alpha.

 This [may result](#color-space-conversions) in values
 outside of the range \[0, 1\]. If clamping is desired, it
 may be performed after sampling.

 This is described like a copy, but may be
 implemented as a reference to read-only underlying data plus
 appropriate metadata to perform conversion later.

 5. Let `result` be a new
 [`GPUExternalTexture`](#gpuexternaltexture) object wrapping `data`.

 3. If `source` is an
 [`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement), [queue an automatic expiry
 task](#abstract-opdef-queue-an-automatic-expiry-task) with device `this` and the
 following steps:

 ::: {timeline="content"}
 1. Set
 `result`.[`[[expired]]`](#dom-gpuexternaltexture-expired-slot) to `true`, releasing ownership of the
 underlying resource.
 :::

 An
 [`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) should be imported in the same task that
 samples the texture (which should generally be scheduled using
 `requestVideoFrameCallback` or
 [`requestAnimationFrame()`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-animationframeprovider-requestanimationframe) depending on the application). Otherwise, a
 texture could get destroyed by these steps before the
 application is finished using it.

 4. If `source` is a
 [`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe), then when `source` is
 [closed](https://www.w3.org/TR/webcodecs/#close-videoframe), run the following steps:

 ::: {timeline="content"}
 1. Set
 `result`.[`[[expired]]`](#dom-gpuexternaltexture-expired-slot) to `true`.
 :::

 5. Set
 `result`.[`label`](#dom-gpuobjectbase-label) to
 `descriptor`.[`label`](#dom-gpuobjectdescriptorbase-label).

 6. Return `result`.
 :::
 ::::

Rendering using an video element
external texture at the page animation frame rate:

``` highlight
const videoElement = document.createElement('video');
// ... set up videoElement, wait for it to be ready...

function frame() {
 requestAnimationFrame(frame);

 // Always re-import the video on every animation frame, because the
 // import is likely to have expired.
 // The browser may cache and reuse a past frame, and if it does it
 // may return the same GPUExternalTexture object again.
 // In this case, old bind groups are still valid.
 const externalTexture = gpuDevice.importExternalTexture({
 source: videoElement
 });

 // ... render using externalTexture...
}
requestAnimationFrame(frame);
```

Rendering using an video element
external texture at the video's frame rate, if
`requestVideoFrameCallback` is available:

``` highlight
const videoElement = document.createElement('video');
// ... set up videoElement...

function frame() {
 videoElement.requestVideoFrameCallback(frame);

 // Always re-import, because we know the video frame has advanced
 const externalTexture = gpuDevice.importExternalTexture({
 source: videoElement
 });

 // ... render using externalTexture...
}
videoElement.requestVideoFrameCallback(frame);
```

### 6.5. Sampling External Texture Bindings

The
[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture) binding point allows binding
[`GPUExternalTexture`](#gpuexternaltexture) objects (from dynamic image sources like videos). It
also supports [`GPUTexture`](#gputexture) and
[`GPUTextureView`](#gputextureview).

 When a
[`GPUTexture`](#gputexture)
or a [`GPUTextureView`](#gputextureview) is bound to an
[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture) binding, it is like a
[`GPUExternalTexture`](#gpuexternaltexture) with a single RGBA plane and no crop, rotation, or
color conversion.

External textures are represented in WGSL with `texture_external` and
may be read using `textureLoad` and `textureSampleBaseClampToEdge`.

The `sampler` provided to `textureSampleBaseClampToEdge` is used to
sample the underlying textures.

When the [binding resource
type](#binding-resource-type) is a
[`GPUExternalTexture`](#gpuexternaltexture), the result is in the color space set by
[`colorSpace`](#dom-gpuexternaltexturedescriptor-colorspace). It is implementation-dependent whether, for any given
external texture, the sampler (and filtering) is applied before or after
conversion from underlying values into the specified color space.

 If the internal representation is an RGBA plane,
sampling behaves as on a regular 2D texture. If there are several
underlying planes (e.g. Y+UV), the sampler is used to sample each
underlying texture separately, prior to conversion from YUV to the
specified color space.

## 7. Samplers

### 7.1. `GPUSampler`

A [`GPUSampler`](#gpusampler) encodes transformations and filtering information that
can be used in a shader to interpret texture resource data.

[`GPUSampler`](#gpusampler)s
are created via
[`createSampler()`](#dom-gpudevice-createsampler).

```
[Exposed=(Window, Worker), SecureContext]
interface GPUSampler ;
GPUSampler includes GPUObjectBase;
```

[`GPUSampler`](#gpusampler)
has the following [immutable
properties](#immutable-property):

[`[[descriptor]]`], of type [`GPUSamplerDescriptor`](#dictdef-gpusamplerdescriptor), readonly

: The
 [`GPUSamplerDescriptor`](#dictdef-gpusamplerdescriptor) with which the
 [`GPUSampler`](#gpusampler) was created.

[`[[isComparison]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Whether the [`GPUSampler`](#gpusampler) is used as a comparison sampler.

[`[[isFiltering]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Whether the [`GPUSampler`](#gpusampler) weights multiple samples of a texture.

#### 7.1.1. [`GPUSamplerDescriptor`]
A
[`GPUSamplerDescriptor`](#dictdef-gpusamplerdescriptor) specifies the options to use to create a
[`GPUSampler`](#gpusampler).

```
dictionary GPUSamplerDescriptor
 : GPUObjectDescriptorBase {
 GPUAddressMode addressModeU = "clamp-to-edge";
 GPUAddressMode addressModeV = "clamp-to-edge";
 GPUAddressMode addressModeW = "clamp-to-edge";
 GPUFilterMode magFilter = "nearest";
 GPUFilterMode minFilter = "nearest";
 GPUMipmapFilterMode mipmapFilter = "nearest";
 float lodMinClamp = 0;
 float lodMaxClamp = 32;
 GPUCompareFunction compare;
 [Clamp] unsigned short maxAnisotropy = 1;
};
```

[`addressModeU`], of type [GPUAddressMode](#enumdef-gpuaddressmode), defaulting to `"clamp-to-edge"`\
[`addressModeV`], of type [GPUAddressMode](#enumdef-gpuaddressmode), defaulting to `"clamp-to-edge"`\
[`addressModeW`], of type [GPUAddressMode](#enumdef-gpuaddressmode), defaulting to `"clamp-to-edge"`

: Specifies the
 [`address modes`](#enumdef-gpuaddressmode) for the texture width, height, and depth
 coordinates, respectively.

[`magFilter`], of type [GPUFilterMode](#enumdef-gpufiltermode), defaulting to `"nearest"`

: Specifies the sampling behavior when the sampled area is smaller
 than or equal to one texel.

[`minFilter`], of type [GPUFilterMode](#enumdef-gpufiltermode), defaulting to `"nearest"`

: Specifies the sampling behavior when the sampled area is larger than
 one texel.

[`mipmapFilter`], of type [GPUMipmapFilterMode](#enumdef-gpumipmapfiltermode), defaulting to `"nearest"`

: Specifies behavior for sampling between mipmap levels.

[`lodMinClamp`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`\
[`lodMaxClamp`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `32`

: Specifies the minimum and maximum [levels of
 detail](#levels-of-detail), respectively, used internally when sampling a
 texture.

[`compare`], of type [GPUCompareFunction](#enumdef-gpucomparefunction)

: When provided the sampler will be a comparison sampler with the
 specified
 [`GPUCompareFunction`](#enumdef-gpucomparefunction).

 Comparison samplers may use filtering, but the
 sampling results will be implementation-dependent and may differ
 from the normal filtering rules.

[`maxAnisotropy`], of type [unsigned short](https://webidl.spec.whatwg.org/#idl-unsigned-short), defaulting to `1`

: Specifies the maximum anisotropy value clamp used by the sampler.
 Anisotropic filtering is enabled when
 [`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) is \> 1 and the implementation supports it.

 Anisotropic filtering improves the image quality of textures sampled
 at oblique viewing angles. Higher
 [`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) values indicate the maximum ratio of anisotropy
 supported when filtering.

 ::::
 ::: marker
 NOTE:
 :::

 Most implementations support
 [`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) values in range between 1 and 16, inclusive. The
 used value of
 [`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) will be clamped to the maximum value that the
 platform supports.
 The precise filtering behavior is implementation-dependent.
 ::::

[Level of detail] (LOD) describes which mip
level(s) are selected when sampling a texture. It may be specified
explicitly through shader methods like
[textureSampleLevel](https://gpuweb.github.io/gpuweb/wgsl/#texturesamplelevel) or implicitly determined from the [texture
coordinate](#texture-coordinates) derivatives.

 See [Scale Factor Operation, LOD Operation and Image
Level
Selection](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html#textures-lod-and-scale-factor)
in the [Vulkan
1.3](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html){biblio-display="inline"
} spec for an example of how implicit LODs may be
calculated.

[`GPUAddressMode`](#enumdef-gpuaddressmode) describes the behavior of the sampler if the sampled
texels extend beyond the bounds of the sampled texture.

```
enum GPUAddressMode {
 "clamp-to-edge",
 "repeat",
 "mirror-repeat",
};
```

[`"clamp-to-edge"`]

: Texture coordinates are clamped between 0.0 and 1.0, inclusive.

[`"repeat"`]

: Texture coordinates wrap to the other side of the texture.

[`"mirror-repeat"`]

: Texture coordinates wrap to the other side of the texture, but the
 texture is flipped when the integer part of the coordinate is odd.

[`GPUFilterMode`](#enumdef-gpufiltermode) and
[`GPUMipmapFilterMode`](#enumdef-gpumipmapfiltermode) describe the behavior of the sampler if the sampled
area does not cover exactly one texel.

 See [Texel
Filtering](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html#textures-texel-filtering)
in the [Vulkan
1.3](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html){biblio-display="inline"
} spec for an example of how samplers may determine
which texels are sampled from for the various filtering modes.

```
enum GPUFilterMode {
 "nearest",
 "linear",
};

enum GPUMipmapFilterMode {
 "nearest",
 "linear",
};
```

[`"nearest"`]

: Return the value of the texel nearest to the texture coordinates.

[`"linear"`]

: Select two texels in each dimension and return a linear
 interpolation between their values.

[`GPUCompareFunction`](#enumdef-gpucomparefunction) specifies the behavior of a comparison sampler. If a
comparison sampler is used in a shader, the `depth_ref` is compared to
the fetched texel value, and the result of this comparison test is
generated (`1.0f` for pass, or `0.0f` for fail).

After comparison, if texture filtering is enabled, the filtering step
occurs, so that comparison results are mixed together resulting in
values in the range `[0, 1]`. Filtering **should** behave as usual,
however it **may** be computed with lower precision or not mix results
at all.

```
enum GPUCompareFunction {
 "never",
 "less",
 "equal",
 "less-equal",
 "greater",
 "not-equal",
 "greater-equal",
 "always",
};
```

[`"never"`]

: Comparison tests never pass.

[`"less"`]

: A provided value passes the comparison test if it is less than the
 sampled value.

[`"equal"`]

: A provided value passes the comparison test if it is equal to the
 sampled value.

[`"less-equal"`]

: A provided value passes the comparison test if it is less than or
 equal to the sampled value.

[`"greater"`]

: A provided value passes the comparison test if it is greater than
 the sampled value.

[`"not-equal"`]

: A provided value passes the comparison test if it is not equal to
 the sampled value.

[`"greater-equal"`]

: A provided value passes the comparison test if it is greater than or
 equal to the sampled value.

[`"always"`]

: Comparison tests always pass.

#### 7.1.2. Sampler Creation

[`createSampler(descriptor)`]

: Creates a [`GPUSampler`](#gpusampler).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) this.
 **Arguments:**

 Arguments for the
 [GPUDevice.createSampler(descriptor)](#dom-gpudevice-createsampler) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUSamplerDescriptor`](#dictdef-gpusamplerdescriptor)
 [✘]
 [✔]
 Description of the
 [`GPUSampler`](#gpusampler) to create.
 **Returns:** [`GPUSampler`](#gpusampler)

 [Content timeline](#content-timeline) steps:

 1. Let `s` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUSampler`](#gpusampler), `descriptor`).

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `s`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `s` and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - `descriptor`.[`lodMinClamp`](#dom-gpusamplerdescriptor-lodminclamp) ≥ 0.

 - `descriptor`.[`lodMaxClamp`](#dom-gpusamplerdescriptor-lodmaxclamp) ≥
 `descriptor`.[`lodMinClamp`](#dom-gpusamplerdescriptor-lodminclamp).

 - `descriptor`.[`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) ≥ 1.

 Most implementations support
 [`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) values in range between 1 and 16, inclusive.
 The provided
 [`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) value will be clamped to the maximum value
 that the platform supports.

 - If
 `descriptor`.[`maxAnisotropy`](#dom-gpusamplerdescriptor-maxanisotropy) \> 1:

 - `descriptor`.[`magFilter`](#dom-gpusamplerdescriptor-magfilter),
 `descriptor`.[`minFilter`](#dom-gpusamplerdescriptor-minfilter), and
 `descriptor`.[`mipmapFilter`](#dom-gpusamplerdescriptor-mipmapfilter) must be
 [`"linear"`](#dom-gpumipmapfiltermode-linear).
 :::

 2. Set
 `s`.[`[[descriptor]]`](#dom-gpusampler-descriptor-slot) to `descriptor`.

 3. Set
 `s`.[`[[isComparison]]`](#dom-gpusampler-iscomparison-slot) to `false` if the
 [`compare`](#dom-gpusamplerdescriptor-compare) attribute of
 `s`.[`[[descriptor]]`](#dom-gpusampler-descriptor-slot) is `null` or undefined. Otherwise, set it to
 `true`.

 4. Set
 `s`.[`[[isFiltering]]`](#dom-gpusampler-isfiltering-slot) to `false` if none of
 [`minFilter`](#dom-gpusamplerdescriptor-minfilter),
 [`magFilter`](#dom-gpusamplerdescriptor-magfilter), or
 [`mipmapFilter`](#dom-gpusamplerdescriptor-mipmapfilter) has the value of
 [`"linear"`](#dom-gpufiltermode-linear). Otherwise, set it to `true`.
 :::
 :::::

Creating a
[`GPUSampler`](#gpusampler)
that does trilinear filtering and repeats texture coordinates:

``` highlight
const sampler = gpuDevice.createSampler({
 addressModeU: 'repeat',
 addressModeV: 'repeat',
 magFilter: 'linear',
 minFilter: 'linear',
 mipmapFilter: 'linear',
});
```

## 8. Resource Binding

### 8.1. `GPUBindGroupLayout`

A
[`GPUBindGroupLayout`](#gpubindgrouplayout) defines the interface between a set of resources bound
in a [`GPUBindGroup`](#gpubindgroup) and their accessibility in shader stages.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUBindGroupLayout ;
GPUBindGroupLayout includes GPUObjectBase;
```

[`GPUBindGroupLayout`](#gpubindgrouplayout) has the following [immutable
properties](#immutable-property):

[`[[descriptor]]`], of type [`GPUBindGroupLayoutDescriptor`](#dictdef-gpubindgrouplayoutdescriptor), readonly

:

#### 8.1.1. Bind Group Layout Creation

A
[`GPUBindGroupLayout`](#gpubindgrouplayout) is created via
[`GPUDevice.createBindGroupLayout()`](#dom-gpudevice-createbindgrouplayout).

```
dictionary GPUBindGroupLayoutDescriptor
 : GPUObjectDescriptorBase {
 required sequence<GPUBindGroupLayoutEntry> entries;
};
```

[`GPUBindGroupLayoutDescriptor`](#dictdef-gpubindgrouplayoutdescriptor) dictionaries have the following members:

[`entries`], of type sequence\<[GPUBindGroupLayoutEntry](#dictdef-gpubindgrouplayoutentry)\>

: A list of entries describing the shader resource bindings for a bind
 group.

A
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) describes a single shader resource binding to be
included in a
[`GPUBindGroupLayout`](#gpubindgrouplayout).

```
dictionary GPUBindGroupLayoutEntry {
 required GPUIndex32 binding;
 required GPUShaderStageFlags visibility;

 GPUBufferBindingLayout buffer;
 GPUSamplerBindingLayout sampler;
 GPUTextureBindingLayout texture;
 GPUStorageTextureBindingLayout storageTexture;
 GPUExternalTextureBindingLayout externalTexture;
};
```

[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) dictionaries have the following members:

[`binding`], of type [GPUIndex32](#typedefdef-gpuindex32)

: A unique identifier for a resource binding within the
 [`GPUBindGroupLayout`](#gpubindgrouplayout), corresponding to a
 [`GPUBindGroupEntry.binding`](#dom-gpubindgroupentry-binding) and a
 [\@binding](https://gpuweb.github.io/gpuweb/wgsl/#attribute-binding) attribute in the
 [`GPUShaderModule`](#gpushadermodule).

[`visibility`], of type [GPUShaderStageFlags](#typedefdef-gpushaderstageflags)

: A bitset of the members of
 [`GPUShaderStage`](#namespacedef-gpushaderstage). Each set bit indicates that a
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry)'s resource will be accessible from the associated
 shader stage.

[`buffer`], of type [GPUBufferBindingLayout](#dictdef-gpubufferbindinglayout)\
[`sampler`], of type [GPUSamplerBindingLayout](#dictdef-gpusamplerbindinglayout)\
[`texture`], of type [GPUTextureBindingLayout](#dictdef-gputexturebindinglayout)\
[`storageTexture`], of type [GPUStorageTextureBindingLayout](#dictdef-gpustoragetexturebindinglayout)\
[`externalTexture`], of type [GPUExternalTextureBindingLayout](#dictdef-gpuexternaltexturebindinglayout)

: Exactly one of these members must be set, indicating the binding
 type. The contents of the member specify options specific to that
 type.

 The corresponding resource in
 [`createBindGroup()`](#dom-gpudevice-createbindgroup) requires the corresponding [binding resource
 type](#binding-resource-type) for this binding.

```
typedef [EnforceRange] unsigned long GPUShaderStageFlags;
[Exposed=(Window, Worker), SecureContext]
namespace GPUShaderStage {
 const GPUFlagsConstant VERTEX = 0x1;
 const GPUFlagsConstant FRAGMENT = 0x2;
 const GPUFlagsConstant COMPUTE = 0x4;
};
```

[`GPUShaderStage`](#namespacedef-gpushaderstage) contains the following flags, which describe which
shader stages a corresponding
[`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) for this
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) will be visible to:

[`VERTEX`]

: The bind group entry will be accessible to vertex shaders.

[`FRAGMENT`]

: The bind group entry will be accessible to fragment shaders.

[`COMPUTE`]

: The bind group entry will be accessible to compute shaders.

The [binding member](#binding-member) of a
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) is determined by which member of the
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) is defined:
[`buffer`](#dom-gpubindgrouplayoutentry-buffer),
[`sampler`](#dom-gpubindgrouplayoutentry-sampler),
[`texture`](#dom-gpubindgrouplayoutentry-texture),
[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture), or
[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture). Only one may be defined for any given
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry). Each member has an associated
[`GPUBindingResource`](#typedefdef-gpubindingresource) type and each [binding
type](#binding-type) has an
associated [internal usage](#internal-usage), given by this table:

[Binding member]

[Resource type]

[Binding type]\

[Binding usage]

[`buffer`](#dom-gpubindgrouplayoutentry-buffer)

[`GPUBufferBinding`](#dictdef-gpubufferbinding)\
(or [`GPUBuffer`](#gpubuffer) as
[shorthand](#abstract-opdef-get-as-buffer-binding))

[`"uniform"`](#dom-gpubufferbindingtype-uniform)

[constant](#internal-usage-constant)

[`"storage"`](#dom-gpubufferbindingtype-storage)

[storage](#internal-usage-storage)

[`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage)

[storage-read](#internal-usage-storage-read)

[`sampler`](#dom-gpubindgrouplayoutentry-sampler)

[`GPUSampler`](#gpusampler)

[`"filtering"`](#dom-gpusamplerbindingtype-filtering)

[constant](#internal-usage-constant)

[`"non-filtering"`](#dom-gpusamplerbindingtype-non-filtering)

[`"comparison"`](#dom-gpusamplerbindingtype-comparison)

[`texture`](#dom-gpubindgrouplayoutentry-texture)

[`GPUTextureView`](#gputextureview)\
(or [`GPUTexture`](#gputexture) as
[shorthand](#abstract-opdef-get-as-texture-view))

[`"float"`](#dom-gputexturesampletype-float)

[constant](#internal-usage-constant)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

[`"depth"`](#dom-gputexturesampletype-depth)

[`"sint"`](#dom-gputexturesampletype-sint)

[`"uint"`](#dom-gputexturesampletype-uint)

[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture)

[`GPUTextureView`](#gputextureview)\
(or [`GPUTexture`](#gputexture) as
[shorthand](#abstract-opdef-get-as-texture-view))

[`"write-only"`](#dom-gpustoragetextureaccess-write-only)

[storage](#internal-usage-storage)

[`"read-write"`](#dom-gpustoragetextureaccess-read-write)

[`"read-only"`](#dom-gpustoragetextureaccess-read-only)

[storage-read](#internal-usage-storage-read)

[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture)

[`GPUExternalTexture`](#gpuexternaltexture)\
or [`GPUTextureView`](#gputextureview)\
(or [`GPUTexture`](#gputexture) as
[shorthand](#abstract-opdef-get-as-texture-view))

[constant](#internal-usage-constant)

The [list](https://infra.spec.whatwg.org/#list) of
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) values `entries` [exceeds the binding slot
limits] of [supported
limits](#supported-limits)
`limits` if the number of slots used toward a limit exceeds
the supported value in `limits`. Each entry may use multiple
slots toward multiple limits.

[Device timeline](#device-timeline) steps:

1. For each `entry` in `entries`, if:

 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is [`"uniform"`](#dom-gpubufferbindingtype-uniform) and `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset) is `true`

 : Consider 1
 [`maxDynamicUniformBuffersPerPipelineLayout`](#dom-supported-limits-maxdynamicuniformbuffersperpipelinelayout) slot to be used.

 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is [`"storage"`](#dom-gpubufferbindingtype-storage) and `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset) is `true`

 : Consider 1
 [`maxDynamicStorageBuffersPerPipelineLayout`](#dom-supported-limits-maxdynamicstoragebuffersperpipelinelayout) slot to be used.

2. For each shader stage `stage` in «
 [`VERTEX`](#dom-gpushaderstage-vertex),
 [`FRAGMENT`](#dom-gpushaderstage-fragment),
 [`COMPUTE`](#dom-gpushaderstage-compute) »:

 1. For each `entry` in `entries` for which
 `entry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) contains `stage`, if:

 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is [`"uniform"`](#dom-gpubufferbindingtype-uniform)

 : Consider 1
 [`maxUniformBuffersPerShaderStage`](#dom-supported-limits-maxuniformbufferspershaderstage) slot to be used.

 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`type`](#dom-gpubufferbindinglayout-type) is [`"storage"`](#dom-gpubufferbindingtype-storage) or [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage)

 : If `stage` is:

 [`VERTEX`](#dom-gpushaderstage-vertex)

 : Consider 1
 [`maxStorageBuffersInVertexStage`](#dom-supported-limits-maxstoragebuffersinvertexstage) slot to be used.

 [`FRAGMENT`](#dom-gpushaderstage-fragment)

 : Consider 1
 [`maxStorageBuffersInFragmentStage`](#dom-supported-limits-maxstoragebuffersinfragmentstage) slot to be used.

 [`COMPUTE`](#dom-gpushaderstage-compute)

 : Consider 1
 [`maxStorageBuffersPerShaderStage`](#dom-supported-limits-maxstoragebufferspershaderstage) slot to be used.

 `entry`.[`sampler`](#dom-gpubindgrouplayoutentry-sampler) is [provided](https://infra.spec.whatwg.org/#map-exists)

 : Consider 1
 [`maxSamplersPerShaderStage`](#dom-supported-limits-maxsamplerspershaderstage) slot to be used.

 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture) is [provided](https://infra.spec.whatwg.org/#map-exists)

 : Consider 1
 [`maxSampledTexturesPerShaderStage`](#dom-supported-limits-maxsampledtexturespershaderstage) slot to be used.

 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) is [provided](https://infra.spec.whatwg.org/#map-exists)

 : If `stage` is:

 [`VERTEX`](#dom-gpushaderstage-vertex)

 : Consider 1
 [`maxStorageTexturesInVertexStage`](#dom-supported-limits-maxstoragetexturesinvertexstage) slot to be used.

 [`FRAGMENT`](#dom-gpushaderstage-fragment)

 : Consider 1
 [`maxStorageTexturesInFragmentStage`](#dom-supported-limits-maxstoragetexturesinfragmentstage) slot to be used.

 [`COMPUTE`](#dom-gpushaderstage-compute)

 : Consider 1
 [`maxStorageTexturesPerShaderStage`](#dom-supported-limits-maxstoragetexturespershaderstage) slot to be used.

 `entry`.[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture) is [provided](https://infra.spec.whatwg.org/#map-exists)

 : Consider 4
 [`maxSampledTexturesPerShaderStage`](#dom-supported-limits-maxsampledtexturespershaderstage) slot, 1
 [`maxSamplersPerShaderStage`](#dom-supported-limits-maxsamplerspershaderstage) slot, and 1
 [`maxUniformBuffersPerShaderStage`](#dom-supported-limits-maxuniformbufferspershaderstage) slot to be used.

 See
 [`GPUExternalTexture`](#gpuexternaltexture) for an explanation of this behavior.

```
enum GPUBufferBindingType {
 "uniform",
 "storage",
 "read-only-storage",
};

dictionary GPUBufferBindingLayout {
 GPUBufferBindingType type = "uniform";
 boolean hasDynamicOffset = false;
 GPUSize64 minBindingSize = 0;
};
```

[`GPUBufferBindingLayout`](#dictdef-gpubufferbindinglayout) dictionaries have the following members:

[`type`], of type [GPUBufferBindingType](#enumdef-gpubufferbindingtype), defaulting to `"uniform"`

: Indicates the type required for buffers bound to this binding.

[`hasDynamicOffset`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Indicates whether this binding requires a dynamic offset.

[`minBindingSize`], of type [GPUSize64](#typedefdef-gpusize64), defaulting to `0`

: Indicates the minimum
 [`size`](#dom-gpubufferbinding-size) of a buffer binding used with this bind point.

 Bindings are always validated against this size in
 [`createBindGroup()`](#dom-gpudevice-createbindgroup).

 If this *is not* `0`, pipeline creation additionally
 [validates](#abstract-opdef-validating-shader-binding) that this value ≥ the [minimum buffer
 binding
 size](#minimum-buffer-binding-size) of the variable.

 If this *is* `0`, it is ignored by pipeline creation, and instead
 draw/dispatch commands
 [validate](#abstract-opdef-validate-encoder-bind-groups) that each binding in the
 [`GPUBindGroup`](#gpubindgroup) satisfies the [minimum buffer binding
 size](#minimum-buffer-binding-size) of the variable.

 Similar execution-time validation is theoretically
 possible for other binding-related fields specified for early
 validation, like
 [`sampleType`](#dom-gputexturebindinglayout-sampletype) and
 [`format`](#dom-gpustoragetexturebindinglayout-format), which currently can only be validated in pipeline
 creation. However, such execution-time validation could be costly or
 unnecessarily complex, so it is available only for
 [`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) which is expected to have the most ergonomic
 impact.

```
enum GPUSamplerBindingType {
 "filtering",
 "non-filtering",
 "comparison",
};

dictionary GPUSamplerBindingLayout {
 GPUSamplerBindingType type = "filtering";
};
```

[`GPUSamplerBindingLayout`](#dictdef-gpusamplerbindinglayout) dictionaries have the following members:

[`type`], of type [GPUSamplerBindingType](#enumdef-gpusamplerbindingtype), defaulting to `"filtering"`

: Indicates the required type of a sampler bound to this binding.

```
enum GPUTextureSampleType {
 "float",
 "unfilterable-float",
 "depth",
 "sint",
 "uint",
};

dictionary GPUTextureBindingLayout {
 GPUTextureSampleType sampleType = "float";
 GPUTextureViewDimension viewDimension = "2d";
 boolean multisampled = false;
};
```

[`GPUTextureBindingLayout`](#dictdef-gputexturebindinglayout) dictionaries have the following members:

[`sampleType`], of type [GPUTextureSampleType](#enumdef-gputexturesampletype), defaulting to `"float"`

: Indicates the type required for texture views bound to this binding.

[`viewDimension`], of type [GPUTextureViewDimension](#enumdef-gputextureviewdimension), defaulting to `"2d"`

: Indicates the required
 [`dimension`](#dom-gputextureviewdescriptor-dimension) for texture views bound to this binding.

[`multisampled`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Indicates whether or not texture views bound to this binding must be
 multisampled.

```
enum GPUStorageTextureAccess {
 "write-only",
 "read-only",
 "read-write",
};

dictionary GPUStorageTextureBindingLayout {
 GPUStorageTextureAccess access = "write-only";
 required GPUTextureFormat format;
 GPUTextureViewDimension viewDimension = "2d";
};
```

[`GPUStorageTextureBindingLayout`](#dictdef-gpustoragetexturebindinglayout) dictionaries have the following members:

[`access`], of type [GPUStorageTextureAccess](#enumdef-gpustoragetextureaccess), defaulting to `"write-only"`

: The access mode for this binding, indicating readability and
 writability.

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The required
 [`format`](#dom-gputextureviewdescriptor-format) of texture views bound to this binding.

[`viewDimension`], of type [GPUTextureViewDimension](#enumdef-gputextureviewdimension), defaulting to `"2d"`

: Indicates the required
 [`dimension`](#dom-gputextureviewdescriptor-dimension) for texture views bound to this binding.

```
dictionary GPUExternalTextureBindingLayout ;
```

A
[`GPUBindGroupLayout`](#gpubindgrouplayout) object has the following [device timeline
properties](#device-timeline-property):

[`[[entryMap]]`], of type [ordered map](https://infra.spec.whatwg.org/#ordered-map)\<[`GPUSize32`](#typedefdef-gpusize32), [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry)\>, readonly

: The map of binding indices pointing to the
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry)s, which this
 [`GPUBindGroupLayout`](#gpubindgrouplayout) describes.

[`[[dynamicOffsetCount]]`], of type [`GPUSize32`](#typedefdef-gpusize32), readonly

: The number of buffer bindings with dynamic offsets in this
 [`GPUBindGroupLayout`](#gpubindgrouplayout).

[`[[exclusivePipeline]]`], of type [`GPUPipelineBase`](#gpupipelinebase)?, readonly

: The pipeline that created this
 [`GPUBindGroupLayout`](#gpubindgrouplayout), if it was created as part of a [default pipeline
 layout](#default-pipeline-layout). If not `null`,
 [`GPUBindGroup`](#gpubindgroup)s created with this
 [`GPUBindGroupLayout`](#gpubindgrouplayout) can only be used with the specified
 [`GPUPipelineBase`](#gpupipelinebase).

<!-- -->

[`createBindGroupLayout(descriptor)`]

: Creates a
 [`GPUBindGroupLayout`](#gpubindgrouplayout).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createBindGroupLayout(descriptor)](#dom-gpudevice-createbindgrouplayout) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUBindGroupLayoutDescriptor`](#dictdef-gpubindgrouplayoutdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUBindGroupLayout`](#gpubindgrouplayout) to create.
 **Returns:**
 [`GPUBindGroupLayout`](#gpubindgrouplayout)

 [Content timeline](#content-timeline) steps:

 1. For each
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` in
 `descriptor`.[`entries`](#dom-gpubindgrouplayoutdescriptor-entries):

 1. If
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate
 texture format required
 features](#abstract-opdef-validate-texture-format-required-features) for
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`format`](#dom-gpustoragetexturebindinglayout-format) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 2. Let `layout` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUBindGroupLayout`](#gpubindgrouplayout), `descriptor`).

 3. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `layout`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `layout` and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - Let `limits` be
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).

 - The
 [`binding`](#dom-gpubindgrouplayoutentry-binding) of each entry in `descriptor` is
 unique.

 - The
 [`binding`](#dom-gpubindgrouplayoutentry-binding) of each entry in `descriptor` must
 be \<
 `limits`.[`maxBindingsPerBindGroup`](#dom-supported-limits-maxbindingsperbindgroup).

 - `descriptor`.[`entries`](#dom-gpubindgrouplayoutdescriptor-entries) must not [exceed the binding slot
 limits](#exceeds-the-binding-slot-limits) of `limits`.

 - For each
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` in
 `descriptor`.[`entries`](#dom-gpubindgrouplayoutdescriptor-entries):

 - Exactly one of
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer),
 `entry`.[`sampler`](#dom-gpubindgrouplayoutentry-sampler),
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture),
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture), and
 `entry`.[`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture) is
 [provided](https://infra.spec.whatwg.org/#map-exists).

 - `entry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) contains only bits defined in
 [`GPUShaderStage`](#namespacedef-gpushaderstage).

 - If
 `entry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) includes
 [`VERTEX`](#dom-gpushaderstage-vertex):

 - If
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer) is
 [provided](https://infra.spec.whatwg.org/#map-exists),
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`type`](#dom-gpubufferbindinglayout-type) must be
 [`"uniform"`](#dom-gpubufferbindingtype-uniform) or
 [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage).

 - If
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) is
 [provided](https://infra.spec.whatwg.org/#map-exists),
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`access`](#dom-gpustoragetexturebindinglayout-access) must be
 [`"read-only"`](#dom-gpustoragetextureaccess-read-only).

 - If
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture)?.[`multisampled`](#dom-gputexturebindinglayout-multisampled) is `true`:

 - `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`viewDimension`](#dom-gputexturebindinglayout-viewdimension) is
 [`"2d"`](#dom-gputextureviewdimension-2d).

 - `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) is not
 [`"float"`](#dom-gputexturesampletype-float).

 - If
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`viewDimension`](#dom-gpustoragetexturebindinglayout-viewdimension) is not
 [`"cube"`](#dom-gputextureviewdimension-cube) or
 [`"cube-array"`](#dom-gputextureviewdimension-cube-array).

 - `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`format`](#dom-gpustoragetexturebindinglayout-format) must be a format which can support
 storage usage for the given
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`access`](#dom-gpustoragetexturebindinglayout-access) according to the [§ 26.1.1 Plain color
 formats](#plain-color-formats) table.
 :::

 2. Set
 `layout`.[`[[descriptor]]`](#dom-gpubindgrouplayout-descriptor-slot) to `descriptor`.

 3. Set
 `layout`.[`[[dynamicOffsetCount]]`](#dom-gpubindgrouplayout-dynamicoffsetcount-slot) to the number of entries in
 `descriptor` where
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer) is
 [provided](https://infra.spec.whatwg.org/#map-exists) and
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset) is `true`.

 4. Set
 `layout`.[`[[exclusivePipeline]]`](#dom-gpubindgrouplayout-exclusivepipeline-slot) to `null`.

 5. For each
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` in
 `descriptor`.[`entries`](#dom-gpubindgrouplayoutdescriptor-entries):

 1. Insert `entry` into
 `layout`.[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot) with the key of
 `entry`.[`binding`](#dom-gpubindgrouplayoutentry-binding).
 :::
 :::::

#### 8.1.2. Compatibility

[`GPUBindGroupLayout`](#gpubindgrouplayout) objects `a` and `b` are
considered [group-equivalent] if and only if all of the following
conditions are satisfied:

- `a`.[`[[exclusivePipeline]]`](#dom-gpubindgrouplayout-exclusivepipeline-slot) ==
 `b`.[`[[exclusivePipeline]]`](#dom-gpubindgrouplayout-exclusivepipeline-slot).

- for any binding number `binding`, one of the following
 conditions is satisfied:

 - it's missing from both
 `a`.[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot) and
 `b`.[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot).

 - `a`.[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot)\[`binding`\] ==
 `b`.[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot)\[`binding`\]

If bind groups layouts are
[group-equivalent](#group-equivalent) they can be interchangeably used in all contents.

### 8.2. `GPUBindGroup`

A [`GPUBindGroup`](#gpubindgroup) defines a set of resources to be bound together in a
group and how the resources are used in shader stages.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUBindGroup ;
GPUBindGroup includes GPUObjectBase;
```

[`GPUBindGroup`](#gpubindgroup) has the following [device timeline
properties](#device-timeline-property):

[`[[layout]]`], of type [`GPUBindGroupLayout`](#gpubindgrouplayout), readonly

: The
 [`GPUBindGroupLayout`](#gpubindgrouplayout) associated with this
 [`GPUBindGroup`](#gpubindgroup).

[`[[entries]]`], of type [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPUBindGroupEntry`](#dictdef-gpubindgroupentry)\>, readonly

: The set of
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry)s this
 [`GPUBindGroup`](#gpubindgroup) describes.

[`[[usedResources]]`], of type [usage scope](#usage-scope), readonly

: The set of buffer and texture
 [subresource](#subresource)s
 used by this bind group, associated with lists of the [internal
 usage](#internal-usage)
 flags.

The [bound buffer ranges] of a
[`GPUBindGroup`](#gpubindgroup) `bindGroup`, given
[list](https://infra.spec.whatwg.org/#list)\<GPUBufferDynamicOffset\> `dynamicOffsets`,
are computed as follows:

1. Let `result` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set)\<([`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry),
 [`GPUBufferBinding`](#dictdef-gpubufferbinding))\>.

2. Let `dynamicOffsetIndex` be 0.

3. For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindGroupEntry` in
 `bindGroup`.[`[[entries]]`](#dom-gpubindgroup-entries-slot), sorted by
 `bindGroupEntry`.[`binding`](#dom-gpubindgroupentry-binding):

 1. Let `bindGroupLayoutEntry` be
 `bindGroup`.[`[[layout]]`](#dom-gpubindgroup-layout-slot).[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot)\[`bindGroupEntry`.[`binding`](#dom-gpubindgroupentry-binding)\].

 2. If
 `bindGroupLayoutEntry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer) is not
 [provided](https://infra.spec.whatwg.org/#map-exists), **continue**.

 3. Let `bound` be [get as buffer
 binding](#abstract-opdef-get-as-buffer-binding)(`bindGroupEntry`.[`resource`](#dom-gpubindgroupentry-resource)).

 4. If
 `bindGroupLayoutEntry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset):

 1. Increment
 `bound`.[`offset`](#dom-gpubufferbinding-offset) by
 `dynamicOffsets`\[`dynamicOffsetIndex`\].

 2. Increment `dynamicOffsetIndex` by 1.

 5. [Append](https://infra.spec.whatwg.org/#set-append) (`bindGroupLayoutEntry`,
 `bound`) to `result`.

4. Return `result`.

#### 8.2.1. Bind Group Creation

A [`GPUBindGroup`](#gpubindgroup) is created via
[`GPUDevice.createBindGroup()`](#dom-gpudevice-createbindgroup).

```
dictionary GPUBindGroupDescriptor
 : GPUObjectDescriptorBase {
 required GPUBindGroupLayout layout;
 required sequence<GPUBindGroupEntry> entries;
};
```

[`GPUBindGroupDescriptor`](#dictdef-gpubindgroupdescriptor) dictionaries have the following members:

[`layout`], of type [GPUBindGroupLayout](#gpubindgrouplayout)

: The
 [`GPUBindGroupLayout`](#gpubindgrouplayout) the entries of this bind group will conform to.

[`entries`], of type sequence\<[GPUBindGroupEntry](#dictdef-gpubindgroupentry)\>

: A list of entries describing the resources to expose to the shader
 for each binding described by the
 [`layout`](#dom-gpubindgroupdescriptor-layout).

```
typedef (GPUSampler or
 GPUTexture or
 GPUTextureView or
 GPUBuffer or
 GPUBufferBinding or
 GPUExternalTexture) GPUBindingResource;

dictionary GPUBindGroupEntry {
 required GPUIndex32 binding;
 required GPUBindingResource resource;
};
```

A
[`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) describes a single resource to be bound in a
[`GPUBindGroup`](#gpubindgroup), and has the following members:

[`binding`], of type [GPUIndex32](#typedefdef-gpuindex32)

: A unique identifier for a resource binding within the
 [`GPUBindGroup`](#gpubindgroup), corresponding to a
 [`GPUBindGroupLayoutEntry.binding`](#dom-gpubindgrouplayoutentry-binding) and a
 [\@binding](https://gpuweb.github.io/gpuweb/wgsl/#attribute-binding) attribute in the
 [`GPUShaderModule`](#gpushadermodule).

[`resource`], of type [GPUBindingResource](#typedefdef-gpubindingresource)

: The resource to bind, which may be a
 [`GPUSampler`](#gpusampler),
 [`GPUTexture`](#gputexture),
 [`GPUTextureView`](#gputextureview),
 [`GPUBuffer`](#gpubuffer),
 [`GPUBufferBinding`](#dictdef-gpubufferbinding), or
 [`GPUExternalTexture`](#gpuexternaltexture).

[`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) has the following [device timeline
properties](#device-timeline-property):

[`[[prevalidatedSize]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

: Whether or not this binding entry had its buffer size validated at
 time of creation.

```
dictionary GPUBufferBinding {
 required GPUBuffer buffer;
 GPUSize64 offset = 0;
 GPUSize64 size;
};
```

A
[`GPUBufferBinding`](#dictdef-gpubufferbinding) describes a buffer and optional range to bind as a
resource, and has the following members:

[`buffer`], of type [GPUBuffer](#gpubuffer)

: The [`GPUBuffer`](#gpubuffer) to bind.

[`offset`], of type [GPUSize64](#typedefdef-gpusize64), defaulting to `0`

: The offset, in bytes, from the beginning of
 [`buffer`](#dom-gpubufferbinding-buffer) to the beginning of the range exposed to the shader
 by the buffer binding.

[`size`], of type [GPUSize64](#typedefdef-gpusize64)

: The size, in bytes, of the buffer binding. If not
 [provided](https://infra.spec.whatwg.org/#map-exists), specifies the range starting at
 [`offset`](#dom-gpubufferbinding-offset) and ending at the end of
 [`buffer`](#dom-gpubufferbinding-buffer).

<!-- -->

[`createBindGroup(descriptor)`]

: Creates a
 [`GPUBindGroup`](#gpubindgroup).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createBindGroup(descriptor)](#dom-gpudevice-createbindgroup) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUBindGroupDescriptor`](#dictdef-gpubindgroupdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUBindGroup`](#gpubindgroup) to create.
 **Returns:**
 [`GPUBindGroup`](#gpubindgroup)

 [Content timeline](#content-timeline) steps:

 1. Let `bindGroup` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUBindGroup`](#gpubindgroup), `descriptor`).

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `bindGroup`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `limits` be
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).

 2. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `bindGroup` and return.

 ::: validusage
 - `descriptor`.[`layout`](#dom-gpubindgroupdescriptor-layout) is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - The number of
 [`entries`](#dom-gpubindgrouplayoutdescriptor-entries) of
 `descriptor`.[`layout`](#dom-gpubindgroupdescriptor-layout) is exactly equal to the number of
 `descriptor`.[`entries`](#dom-gpubindgroupdescriptor-entries).

 For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindingDescriptor` in
 `descriptor`.[`entries`](#dom-gpubindgroupdescriptor-entries):

 - Let `resource` be
 `bindingDescriptor`.[`resource`](#dom-gpubindgroupentry-resource).

 - There is exactly one
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `layoutBinding` in
 `descriptor`.[`layout`](#dom-gpubindgroupdescriptor-layout).[`entries`](#dom-gpubindgrouplayoutdescriptor-entries) such that
 `layoutBinding`.[`binding`](#dom-gpubindgrouplayoutentry-binding) equals to
 `bindingDescriptor`.[`binding`](#dom-gpubindgroupentry-binding).

 - If the defined [binding
 member](#binding-member) for `layoutBinding` is:

 [`sampler`](#dom-gpubindgrouplayoutentry-sampler)

 : - `resource` is a
 [`GPUSampler`](#gpusampler).

 - `resource` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - If
 `layoutBinding`.[`sampler`](#dom-gpubindgrouplayoutentry-sampler).[`type`](#dom-gpusamplerbindinglayout-type) is:

 [`"filtering"`](#dom-gpusamplerbindingtype-filtering)

 : `resource`.[`[[isComparison]]`](#dom-gpusampler-iscomparison-slot) is `false`.

 [`"non-filtering"`](#dom-gpusamplerbindingtype-non-filtering)

 : `resource`.[`[[isFiltering]]`](#dom-gpusampler-isfiltering-slot) is `false`.
 `resource`.[`[[isComparison]]`](#dom-gpusampler-iscomparison-slot) is `false`.

 [`"comparison"`](#dom-gpusamplerbindingtype-comparison)

 : `resource`.[`[[isComparison]]`](#dom-gpusampler-iscomparison-slot) is `true`.

 [`texture`](#dom-gpubindgrouplayoutentry-texture)

 : - `resource` is either a
 [`GPUTexture`](#gputexture) or a
 [`GPUTextureView`](#gputextureview).

 - `resource` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - Let `textureView` be [get as texture
 view](#abstract-opdef-get-as-texture-view)(`resource`).

 - Let `texture` be
 `textureView`.[`[[texture]]`](#dom-gputextureview-texture-slot).

 - `layoutBinding`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`viewDimension`](#dom-gputexturebindinglayout-viewdimension) is equal to `textureView`'s
 [`dimension`](#dom-gputextureviewdescriptor-dimension).

 - `layoutBinding`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) is [compatible](#texture-format-caps)
 with `textureView`'s
 [`format`](#dom-gputextureviewdescriptor-format).

 - `textureView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`usage`](#dom-gputextureviewdescriptor-usage) includes
 [`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding).

 - If
 `layoutBinding`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`multisampled`](#dom-gputexturebindinglayout-multisampled) is `true`, `texture`'s
 [`sampleCount`](#dom-gputexturedescriptor-samplecount) \> `1`, Otherwise
 `texture`'s
 [`sampleCount`](#dom-gputexturedescriptor-samplecount) is `1`.

 - ::: compatmode
 If
 `texture`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) is not `undefined`:
 - [Assert](https://infra.spec.whatwg.org/#assert)
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits).

 - `texture`.[`textureBindingViewDimension`](#dom-gputexture-texturebindingviewdimension) must be equal to
 `textureView`.[`dimension`](#dom-gputextureviewdescriptor-dimension).
 :::

 [`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture)

 : - `resource` is either a
 [`GPUTexture`](#gputexture) or a
 [`GPUTextureView`](#gputextureview).

 - `resource` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - Let `storageTextureView` be [get as texture
 view](#abstract-opdef-get-as-texture-view)(`resource`).

 - Let `texture` be
 `storageTextureView`.[`[[texture]]`](#dom-gputextureview-texture-slot).

 - `layoutBinding`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`viewDimension`](#dom-gpustoragetexturebindinglayout-viewdimension) is equal to
 `storageTextureView`'s
 [`dimension`](#dom-gputextureviewdescriptor-dimension).

 - `layoutBinding`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`format`](#dom-gpustoragetexturebindinglayout-format) is equal to
 `storageTextureView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`format`](#dom-gputextureviewdescriptor-format).

 - `storageTextureView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`usage`](#dom-gputextureviewdescriptor-usage) includes
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding).

 - `storageTextureView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) must be 1.

 - `storageTextureView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`swizzle`](#dom-gputextureviewdescriptor-swizzle) must be `"rgba"`.

 [`buffer`](#dom-gpubindgrouplayoutentry-buffer)

 : - `resource` is either a
 [`GPUBuffer`](#gpubuffer) or a
 [`GPUBufferBinding`](#dictdef-gpubufferbinding).

 - Let `bufferBinding` be [get as buffer
 binding](#abstract-opdef-get-as-buffer-binding)(`resource`).

 - `bufferBinding`.[`buffer`](#dom-gpubufferbinding-buffer) is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - The bound part designated by
 `bufferBinding`.[`offset`](#dom-gpubufferbinding-offset) and
 `bufferBinding`.[`size`](#dom-gpubufferbinding-size) resides inside the buffer and has
 non-zero size.

 - [effective buffer binding
 size](#abstract-opdef-effective-buffer-binding-size)(`bufferBinding`) ≥
 `layoutBinding`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize).

 - If
 `layoutBinding`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`type`](#dom-gpubufferbindinglayout-type) is

 [`"uniform"`](#dom-gpubufferbindingtype-uniform)

 : - `bufferBinding`.[`buffer`](#dom-gpubufferbinding-buffer).[`usage`](#dom-gpubufferdescriptor-usage) includes
 [`UNIFORM`](#dom-gpubufferusage-uniform).

 - [effective buffer binding
 size](#abstract-opdef-effective-buffer-binding-size)(`bufferBinding`)
 ≤
 `limits`.[`maxUniformBufferBindingSize`](#dom-supported-limits-maxuniformbufferbindingsize).

 - `bufferBinding`.[`offset`](#dom-gpubufferbinding-offset) is a multiple of
 `limits`.[`minUniformBufferOffsetAlignment`](#dom-supported-limits-minuniformbufferoffsetalignment).

 [`"storage"`](#dom-gpubufferbindingtype-storage) or [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage)

 : - `bufferBinding`.[`buffer`](#dom-gpubufferbinding-buffer).[`usage`](#dom-gpubufferdescriptor-usage) includes
 [`STORAGE`](#dom-gpubufferusage-storage).

 - [effective buffer binding
 size](#abstract-opdef-effective-buffer-binding-size)(`bufferBinding`)
 ≤
 `limits`.[`maxStorageBufferBindingSize`](#dom-supported-limits-maxstoragebufferbindingsize).

 - [effective buffer binding
 size](#abstract-opdef-effective-buffer-binding-size)(`bufferBinding`)
 is a multiple of 4.

 - `bufferBinding`.[`offset`](#dom-gpubufferbinding-offset) is a multiple of
 `limits`.[`minStorageBufferOffsetAlignment`](#dom-supported-limits-minstoragebufferoffsetalignment).

 [`externalTexture`](#dom-gpubindgrouplayoutentry-externaltexture)

 : - `resource` is either a
 [`GPUExternalTexture`](#gpuexternaltexture), a
 [`GPUTexture`](#gputexture), or a
 [`GPUTextureView`](#gputextureview).

 - `resource` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - If `resource` is a:

 [`GPUTexture`](#gputexture) or [`GPUTextureView`](#gputextureview)

 : - Let `view` be [get as texture
 view](#abstract-opdef-get-as-texture-view)(`resource`).

 - `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`usage`](#dom-gputextureviewdescriptor-usage) must include
 [`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding).

 - `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`dimension`](#dom-gputextureviewdescriptor-dimension) must be
 [`"2d"`](#dom-gputextureviewdimension-2d).

 - `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) must be 1.

 - `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`format`](#dom-gputextureviewdescriptor-format) must be
 [`"rgba8unorm"`](#dom-gputextureformat-rgba8unorm),
 [`"bgra8unorm"`](#dom-gputextureformat-bgra8unorm), or
 [`"rgba16float"`](#dom-gputextureformat-rgba16float).

 - `view`.[`[[texture]]`](#dom-gputextureview-texture-slot).[`sampleCount`](#dom-gputexture-samplecount) must be 1.

 - ::: compatmode
 If
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindGroupEntry` in
 `descriptor`.[`entries`](#dom-gpubindgroupdescriptor-entries):

 - If
 `bindGroupEntry`.[`resource`](#dom-gpubindgroupentry-resource) is a
 [`GPUTextureView`](#gputextureview):

 - Let `textureView` be
 `bindGroupEntry`.[`resource`](#dom-gpubindgroupentry-resource).

 - Let `descriptor` be
 `textureView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).

 - `descriptor`.[`baseArrayLayer`](#dom-gputextureviewdescriptor-basearraylayer) must be `0`.

 - `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be equal to
 `textureView`.[`[[texture]]`](#dom-gputextureview-texture-slot).[`depthOrArrayLayers`](#dom-gputexture-depthorarraylayers).
 :::
 :::

 3. Let
 `bindGroup`.[`[[layout]]`](#dom-gpubindgroup-layout-slot) =
 `descriptor`.[`layout`](#dom-gpubindgroupdescriptor-layout).

 4. Let
 `bindGroup`.[`[[entries]]`](#dom-gpubindgroup-entries-slot) =
 `descriptor`.[`entries`](#dom-gpubindgroupdescriptor-entries).

 5. Let
 `bindGroup`.[`[[usedResources]]`](#dom-gpubindgroup-usedresources-slot) = .

 6. For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindingDescriptor` in
 `descriptor`.[`entries`](#dom-gpubindgroupdescriptor-entries):

 1. Let `internalUsage` be the [binding
 usage](#binding-usage) for `layoutBinding`.

 2. Each [subresource](#subresource) seen by `resource` is added to
 [`[[usedResources]]`](#dom-gpubindgroup-usedresources-slot) as `internalUsage`.

 3. Let
 `bindingDescriptor`.[`[[prevalidatedSize]]`](#dom-gpubindgroupentry-prevalidatedsize-slot) be `false` if the defined [binding
 member](#binding-member) for `layoutBinding` is
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer) and
 `layoutBinding`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) is `0`, and `true` otherwise.
 :::
 :::::

[get as texture view](`resource`)

**Arguments:**

- [`GPUBindingResource`](#typedefdef-gpubindingresource) `resource`

**Returns:**
[`GPUTextureView`](#gputextureview)

1. [Assert](https://infra.spec.whatwg.org/#assert) `resource` is either a
 [`GPUTexture`](#gputexture) or a
 [`GPUTextureView`](#gputextureview).

2. If `resource` is a:

 [`GPUTexture`](#gputexture)

 : 1. Return
 `resource`.[`createView()`](#dom-gputexture-createview).

 [`GPUTextureView`](#gputextureview)

 : 1. Return `resource`.

[get as buffer binding](`resource`)

**Arguments:**

- [`GPUBindingResource`](#typedefdef-gpubindingresource) `resource`

**Returns:**
[`GPUBufferBinding`](#dictdef-gpubufferbinding)

1. [Assert](https://infra.spec.whatwg.org/#assert) `resource` is either a
 [`GPUBuffer`](#gpubuffer) or a
 [`GPUBufferBinding`](#dictdef-gpubufferbinding).

2. If `resource` is a:

 [`GPUBuffer`](#gpubuffer)

 : 1. Let `bufferBinding` a new
 [`GPUBufferBinding`](#dictdef-gpubufferbinding).

 2. Set
 `bufferBinding`.[`buffer`](#dom-gpubufferbinding-buffer) to `resource`.

 3. Return `bufferBinding`.

 [`GPUBufferBinding`](#dictdef-gpubufferbinding)

 : 1. Return `resource`.

[effective buffer binding
size](`binding`)

**Arguments:**

- [`GPUBufferBinding`](#dictdef-gpubufferbinding) `binding`

**Returns:**
[`GPUSize64`](#typedefdef-gpusize64)

1. If
 `binding`.[`size`](#dom-gpubufferbinding-size) is not
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Return max(0,
 `binding`.[`buffer`](#dom-gpubufferbinding-buffer).[`size`](#dom-gpubuffer-size) -
 `binding`.[`offset`](#dom-gpubufferbinding-offset));

2. Return
 `binding`.[`size`](#dom-gpubufferbinding-size).

[`GPUBufferBinding`](#dictdef-gpubufferbinding) objects `a` and `b` are
considered [buffer-binding-aliasing] if and only if all of the
following are true:

- `a`.[`buffer`](#dom-gpubufferbinding-buffer) ==
 `b`.[`buffer`](#dom-gpubufferbinding-buffer)

- The range formed by
 `a`.[`offset`](#dom-gpubufferbinding-offset) and
 `a`.[`size`](#dom-gpubufferbinding-size) intersects the range formed by
 `b`.[`offset`](#dom-gpubufferbinding-offset) and
 `b`.[`size`](#dom-gpubufferbinding-size), where if a
 [`size`](#dom-gpubufferbinding-size) is
 [unspecified](https://infra.spec.whatwg.org/#map-exists), the range goes to the end of the buffer.

 When doing this calculation, any dynamic offsets have
already been applied to the ranges.

### 8.3. `GPUPipelineLayout`

A
[`GPUPipelineLayout`](#gpupipelinelayout) defines the mapping between resources of all
[`GPUBindGroup`](#gpubindgroup) objects set up during command encoding in
[setBindGroup()](#gpubindingcommandsmixin-setbindgroup), and the shaders of the pipeline set by
[`GPURenderCommandsMixin.setPipeline`](#dom-gpurendercommandsmixin-setpipeline) or
[`GPUComputePassEncoder.setPipeline`](#dom-gpucomputepassencoder-setpipeline).

The full binding address of a resource can be defined as a trio of:

1. shader stage mask, to which the resource is visible

2. bind group index

3. binding number

The components of this address can also be seen as the binding space of
a pipeline. A
[`GPUBindGroup`](#gpubindgroup) (with the corresponding
[`GPUBindGroupLayout`](#gpubindgrouplayout)) covers that space for a fixed bind group index. The
contained bindings need to be a superset of the resources used by the
shader at this bind group index.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUPipelineLayout ;
GPUPipelineLayout includes GPUObjectBase;
```

[`GPUPipelineLayout`](#gpupipelinelayout) has the following [device timeline
properties](#device-timeline-property):

[`[[bindGroupLayouts]]`], of type [list](https://infra.spec.whatwg.org/#list)\<[`GPUBindGroupLayout`](#gpubindgrouplayout)\>, readonly

: The
 [`GPUBindGroupLayout`](#gpubindgrouplayout) objects provided at creation in
 [`GPUPipelineLayoutDescriptor.bindGroupLayouts`](#dom-gpupipelinelayoutdescriptor-bindgrouplayouts).

 using the same
[`GPUPipelineLayout`](#gpupipelinelayout) for many
[`GPURenderPipeline`](#gpurenderpipeline) or
[`GPUComputePipeline`](#gpucomputepipeline) pipelines guarantees that the user agent doesn't need
to rebind any resources internally when there is a switch between these
pipelines.

[`GPUComputePipeline`](#gpucomputepipeline) object X was created with
[`GPUPipelineLayout.bindGroupLayouts`](#dom-gpupipelinelayout-bindgrouplayouts-slot) A, B, C.
[`GPUComputePipeline`](#gpucomputepipeline) object Y was created with
[`GPUPipelineLayout.bindGroupLayouts`](#dom-gpupipelinelayout-bindgrouplayouts-slot) A, D, C. Supposing the command encoding sequence has
two dispatches:

1. [setBindGroup](#gpubindingcommandsmixin-setbindgroup)(0, \...)

2. [setBindGroup](#gpubindingcommandsmixin-setbindgroup)(1, \...)

3. [setBindGroup](#gpubindingcommandsmixin-setbindgroup)(2, \...)

4. [`setPipeline`](#dom-gpucomputepassencoder-setpipeline)(X)

5. [`dispatchWorkgroups`](#dom-gpucomputepassencoder-dispatchworkgroups)()

6. [setBindGroup](#gpubindingcommandsmixin-setbindgroup)(1, \...)

7. [`setPipeline`](#dom-gpucomputepassencoder-setpipeline)(Y)

8. [`dispatchWorkgroups`](#dom-gpucomputepassencoder-dispatchworkgroups)()

In this scenario, the user agent would have to re-bind the group slot 2
for the second dispatch, even though neither the
[`GPUBindGroupLayout`](#gpubindgrouplayout) at index 2 of
[`GPUPipelineLayout.bindGroupLayouts`](#dom-gpupipelinelayout-bindgrouplayouts-slot), or the
[`GPUBindGroup`](#gpubindgroup) at slot 2, change.

 the expected usage of the
[`GPUPipelineLayout`](#gpupipelinelayout) is placing the most common and the least frequently
changing bind groups at the \"bottom\" of the layout, meaning lower bind
group slot numbers, like 0 or 1. The more frequently a bind group needs
to change between draw calls, the higher its index should be. This
general guideline allows the user agent to minimize state changes
between draw calls, and consequently lower the CPU overhead.

#### 8.3.1. Pipeline Layout Creation

A
[`GPUPipelineLayout`](#gpupipelinelayout) is created via
[`GPUDevice.createPipelineLayout()`](#dom-gpudevice-createpipelinelayout).

```
dictionary GPUPipelineLayoutDescriptor
 : GPUObjectDescriptorBase {
 required sequence<GPUBindGroupLayout?> bindGroupLayouts;
};
```

[`GPUPipelineLayoutDescriptor`](#dictdef-gpupipelinelayoutdescriptor) dictionaries define all the
[`GPUBindGroupLayout`](#gpubindgrouplayout)s used by a pipeline, and have the following members:

[`bindGroupLayouts`], of type `sequence<GPUBindGroupLayout?>`

: A list of optional
 [`GPUBindGroupLayout`](#gpubindgrouplayout)s the pipeline will use. Each element corresponds to
 a
 [\@group](https://gpuweb.github.io/gpuweb/wgsl/#attribute-group) attribute in the
 [`GPUShaderModule`](#gpushadermodule), with the `N`th element corresponding with
 `@group(N)`.

<!-- -->

[`createPipelineLayout(descriptor)`]

: Creates a
 [`GPUPipelineLayout`](#gpupipelinelayout).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createPipelineLayout(descriptor)](#dom-gpudevice-createpipelinelayout) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUPipelineLayoutDescriptor`](#dictdef-gpupipelinelayoutdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUPipelineLayout`](#gpupipelinelayout) to create.
 **Returns:**
 [`GPUPipelineLayout`](#gpupipelinelayout)

 [Content timeline](#content-timeline) steps:

 1. Let `pl` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUPipelineLayout`](#gpupipelinelayout), `descriptor`).

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `pl`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `limits` be
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).

 2. Let `bindGroupLayouts` be a
 [list](https://infra.spec.whatwg.org/#list) of `null`
 [`GPUBindGroupLayout`](#gpubindgrouplayout)s with
 [size](https://infra.spec.whatwg.org/#list-size) equal to
 `limits`.[`maxBindGroups`](#dom-supported-limits-maxbindgroups).

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `bindGroupLayout` at index
 `i` in
 `descriptor`.[`bindGroupLayouts`](#dom-gpupipelinelayoutdescriptor-bindgrouplayouts):

 1. If `bindGroupLayout` is not `null` and
 `bindGroupLayout`.[`[[descriptor]]`](#dom-gpubindgrouplayout-descriptor-slot).[`entries`](#dom-gpubindgrouplayoutdescriptor-entries) is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. Set `bindGroupLayouts`\[`i`\] to
 `bindGroupLayout`.

 4. Let `allEntries` be the result of concatenating
 `bgl`.[`[[descriptor]]`](#dom-gpubindgrouplayout-descriptor-slot).[`entries`](#dom-gpubindgrouplayoutdescriptor-entries) for all non-`null` `bgl` in
 `bindGroupLayouts`.

 5. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `pl` and return.

 ::: validusage
 - Every non-`null`
 [`GPUBindGroupLayout`](#gpubindgrouplayout) in `bindGroupLayouts` must be
 [valid to use
 with](#abstract-opdef-valid-to-use-with) `this` and have a
 [`[[exclusivePipeline]]`](#dom-gpubindgrouplayout-exclusivepipeline-slot) of `null`.

 - The
 [size](https://infra.spec.whatwg.org/#list-size) of
 `descriptor`.[`bindGroupLayouts`](#dom-gpupipelinelayoutdescriptor-bindgrouplayouts) must be ≤
 `limits`.[`maxBindGroups`](#dom-supported-limits-maxbindgroups).

 - `allEntries` must not [exceed the binding slot
 limits](#exceeds-the-binding-slot-limits) of `limits`.
 :::

 6. Set the
 `pl`.[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot) to `bindGroupLayouts`.
 :::
 :::::

 two
[`GPUPipelineLayout`](#gpupipelinelayout) objects are considered equivalent for any usage if
their internal
[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot) sequences contain
[`GPUBindGroupLayout`](#gpubindgrouplayout) objects that are
[group-equivalent](#group-equivalent).

### 8.4. Example

Create a
[`GPUBindGroupLayout`](#gpubindgrouplayout) that describes a binding with a uniform buffer, a
texture, and a sampler. Then create a
[`GPUBindGroup`](#gpubindgroup) and a
[`GPUPipelineLayout`](#gpupipelinelayout) using the
[`GPUBindGroupLayout`](#gpubindgrouplayout).

``` highlight
const bindGroupLayout = gpuDevice.createBindGroupLayout({
 entries: [{
 binding: 0,
 visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
 buffer:
 }, {
 binding: 1,
 visibility: GPUShaderStage.FRAGMENT,
 texture:
 }, {
 binding: 2,
 visibility: GPUShaderStage.FRAGMENT,
 sampler:
 }]
});

const bindGroup = gpuDevice.createBindGroup({
 layout: bindGroupLayout,
 entries: [{
 binding: 0,
 resource: { buffer: buffer },
 }, {
 binding: 1,
 resource: texture
 }, {
 binding: 2,
 resource: sampler
 }]
});

const pipelineLayout = gpuDevice.createPipelineLayout({
 bindGroupLayouts: [bindGroupLayout]
});
```

## 9. Shader Modules

### 9.1. `GPUShaderModule`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUShaderModule {
 Promise<GPUCompilationInfo> getCompilationInfo();
};
GPUShaderModule includes GPUObjectBase;
```

[`GPUShaderModule`](#gpushadermodule) is a reference to an internal shader module object.

#### 9.1.1. Shader Module Creation

```
dictionary GPUShaderModuleDescriptor
 : GPUObjectDescriptorBase {
 required USVString code;
 sequence<GPUShaderModuleCompilationHint> compilationHints = ;
};
```

[`code`], of type [USVString](https://webidl.spec.whatwg.org/#idl-USVString)

: The [WGSL](https://gpuweb.github.io/gpuweb/wgsl/) source code for
 the shader module.

[`compilationHints`], of type sequence\<[GPUShaderModuleCompilationHint](#dictdef-gpushadermodulecompilationhint)\>, defaulting to ``

: A list of
 [`GPUShaderModuleCompilationHint`](#dictdef-gpushadermodulecompilationhint)s.

 Any hint provided by an application **should** contain information
 about one entry point of a pipeline that will eventually be created
 from the entry point.

 Implementations **should** use any information present in the
 [`GPUShaderModuleCompilationHint`](#dictdef-gpushadermodulecompilationhint) to perform as much compilation as is possible
 within
 [`createShaderModule()`](#dom-gpudevice-createshadermodule).

 Aside from type-checking, these hints are not validated in any way.

 ::::
 ::: marker
 NOTE:
 :::

 Supplying information in
 [`compilationHints`](#dom-gpushadermoduledescriptor-compilationhints) does not have any observable effect, other than
 performance. It may be detrimental to performance to provide hints
 for pipelines that never end up being created.
 Because a single shader module can hold multiple entry points, and
 multiple pipelines can be created from a single shader module, it
 can be more performant for an implementation to do as much
 compilation as possible once in
 [`createShaderModule()`](#dom-gpudevice-createshadermodule) rather than multiple times in the multiple calls to
 [`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) or
 [`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline).

 Hints are only applied to the entry points they explicitly name.
 Unlike
 [`GPUProgrammableStage.entryPoint`](#dom-gpuprogrammablestage-entrypoint), there is no default, even if only one entry point
 is present in the module.
 ::::

 Hints are not validated in an observable way, but
 user agents **may** surface identifiable errors (like unknown entry
 point names or incompatible pipeline layouts) to developers, for
 example in the browser developer console.

<!-- -->

[`createShaderModule(descriptor)`]

: Creates a
 [`GPUShaderModule`](#gpushadermodule).

 :::::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) this.
 **Arguments:**

 Arguments for the
 [GPUDevice.createShaderModule(descriptor)](#dom-gpudevice-createshadermodule) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUShaderModuleDescriptor`](#dictdef-gpushadermoduledescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUShaderModule`](#gpushadermodule) to create.
 **Returns:**
 [`GPUShaderModule`](#gpushadermodule)

 [Content timeline](#content-timeline) steps:

 1. Let `sm` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUShaderModule`](#gpushadermodule), `descriptor`).

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `sm`.
 :::

 ::::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `error` be any error that results from [shader
 module
 creation](https://gpuweb.github.io/gpuweb/wgsl/#shader-module-creation) with the WGSL source
 `descriptor`.[`code`](#dom-gpushadermoduledescriptor-code), or `null` if no errors occured.

 2. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `sm`, and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - `error` must not be a
 [shader-creation](https://gpuweb.github.io/gpuweb/wgsl/#shader-creation-error) [program
 error](https://gpuweb.github.io/gpuweb/wgsl/#program-error).

 - For each `enable` extension in
 `descriptor`.[`code`](#dom-gpushadermoduledescriptor-code), the corresponding
 [`GPUFeatureName`](#gpufeaturename) must be enabled (see the [Feature
 Index](#feature-index)).
 :::

 [Uncategorized
 errors](https://gpuweb.github.io/gpuweb/wgsl/#uncategorized-error) cannot arise from shader module creation.
 Implementations which detect such errors during shader module
 creation must behave as if the shader module is valid, and defer
 surfacing the error until pipeline creation.

 ::::
 ::: marker
 NOTE:
 :::

 User agents **should not** include detailed compiler error messages
 or shader text in the
 [`message`](#dom-gpuerror-message) text of validation errors arising here: these
 details are accessible via
 [`getCompilationInfo()`](#dom-gpushadermodule-getcompilationinfo). User agents **should** surface human-readable,
 formatted error details *to developers* for easier debugging (for
 example as a warning in the browser developer console, expandable to
 show full shader source).
 As shader compilation errors should be rare in production
 applications, user agents could choose to surface them *to
 developers* regardless of error handling ([GPU error
 scopes](#gpu-error-scope)
 or
 [`uncapturederror`](#eventdef-gpudevice-uncapturederror) event handlers), e.g. as an expandable warning. If
 not, they should provide and document another way for developers to
 access human-readable error details, for example by adding a
 checkbox to show errors unconditionally, or by showing
 human-readable details when logging a
 [`GPUCompilationInfo`](#gpucompilationinfo) object to the console.
 ::::
 :::::
 :::::::

Create a
[`GPUShaderModule`](#gpushadermodule) from WGSL code:

``` highlight
// A simple vertex and fragment shader pair that will fill the viewport with red.
const shaderSource = `
 var<private> pos : array<vec2<f32>, 3> = array<vec2<f32>, 3>(
 vec2(-1.0, -1.0), vec2(-1.0, 3.0), vec2(3.0, -1.0));

 @vertex
 fn vertexMain(@builtin(vertex_index) vertexIndex : u32) -> @builtin(position) vec4<f32> {
 return vec4(pos[vertexIndex], 1.0, 1.0);
 }

 @fragment
 fn fragmentMain() -> @location(0) vec4<f32> {
 return vec4(1.0, 0.0, 0.0, 1.0);
 }
`;

const shaderModule = gpuDevice.createShaderModule({
 code: shaderSource,
});
```

##### 9.1.1.1. Shader Module Compilation Hints

Shader module compilation hints are optional, additional information
indicating how a given
[`GPUShaderModule`](#gpushadermodule) entry point is intended to be used in the future. For
some implementations this information may aid in compiling the shader
module earlier, potentially increasing performance.

```
dictionary GPUShaderModuleCompilationHint {
 required USVString entryPoint;
 (GPUPipelineLayout or GPUAutoLayoutMode) layout;
};
```

[`layout`], of type `(GPUPipelineLayout or GPUAutoLayoutMode)`

: A
 [`GPUPipelineLayout`](#gpupipelinelayout) that the
 [`GPUShaderModule`](#gpushadermodule) may be used with in a future
 [`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) or
 [`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline) call. If set to
 [`"auto"`](#dom-gpuautolayoutmode-auto) the layout will be the [default pipeline
 layout](#abstract-opdef-default-pipeline-layout) for the entry point associated with this
 hint will be used.

NOTE:

If possible, authors should be supplying the same information to
[`createShaderModule()`](#dom-gpudevice-createshadermodule) and
[`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) /
[`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline).

If an application is unable to provide hint information at the time of
calling
[`createShaderModule()`](#dom-gpudevice-createshadermodule), it should usually not delay calling
[`createShaderModule()`](#dom-gpudevice-createshadermodule), but instead just omit the unknown information from the
[`compilationHints`](#dom-gpushadermoduledescriptor-compilationhints) sequence or the individual members of
[`GPUShaderModuleCompilationHint`](#dictdef-gpushadermodulecompilationhint). Omitting this information may cause compilation to be
deferred to
[`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) /
[`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline).

If an author is not confident that the hint information passed to
[`createShaderModule()`](#dom-gpudevice-createshadermodule) will match the information later passed to
[`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) /
[`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline) with that same module, they should avoid passing that
information to
[`createShaderModule()`](#dom-gpudevice-createshadermodule), as passing mismatched information to
[`createShaderModule()`](#dom-gpudevice-createshadermodule) may cause unnecessary compilations to occur.

#### 9.1.2. Shader Module Compilation Information

```
enum GPUCompilationMessageType {
 "error",
 "warning",
 "info",
};

[Exposed=(Window, Worker), Serializable, SecureContext]
interface GPUCompilationMessage {
 readonly attribute DOMString message;
 readonly attribute GPUCompilationMessageType type;
 readonly attribute unsigned long long lineNum;
 readonly attribute unsigned long long linePos;
 readonly attribute unsigned long long offset;
 readonly attribute unsigned long long length;
};

[Exposed=(Window, Worker), Serializable, SecureContext]
interface GPUCompilationInfo {
 readonly attribute FrozenArray<GPUCompilationMessage> messages;
};
```

A
[`GPUCompilationMessage`](#gpucompilationmessage) is an informational, warning, or error message
generated by the
[`GPUShaderModule`](#gpushadermodule) compiler. The messages are intended to be human
readable to help developers diagnose issues with their shader
[`code`](#dom-gpushadermoduledescriptor-code). Each message may correspond to a single point or range
of the shader source, or may be unassociated with any specific part of
the code.

[`GPUCompilationMessage`](#gpucompilationmessage) has the following attributes:

[`message`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: The human-readable, [localizable
 text](https://www.w3.org/TR/i18n-glossary/#dfn-localizable-text) for this compilation message.

 The
 [`message`](#dom-gpucompilationmessage-message) should follow the [best practices for language and
 direction
 information](https://w3c.github.io/string-meta/#bp_and-reco). This includes making use of any future standards
 which may emerge regarding the reporting of string language and
 direction metadata.

 [Editorial note:] At the time of this writing, no
 language/direction recommendation is available that provides
 compatibility and consistency with legacy APIs, but when there is,
 adopt it formally.

[`type`], of type [GPUCompilationMessageType](#enumdef-gpucompilationmessagetype), readonly

: The severity level of the message.

 If the
 [`type`](#dom-gpucompilationmessage-type) is
 [`"error"`](#dom-gpucompilationmessagetype-error), it corresponds to a [shader-creation
 error](https://gpuweb.github.io/gpuweb/wgsl/#shader-creation-error).

[`lineNum`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly

: The line number in the shader
 [`code`](#dom-gpushadermoduledescriptor-code) the
 [`message`](#dom-gpucompilationmessage-message) corresponds to. Value is one-based, such that a
 lineNum of `1` indicates the first line of the shader
 [`code`](#dom-gpushadermoduledescriptor-code). Lines are delimited by [line
 breaks](https://gpuweb.github.io/gpuweb/wgsl/#line-break).

 If the
 [`message`](#dom-gpucompilationmessage-message) corresponds to a substring this points to the line
 on which the substring begins. Must be `0` if the
 [`message`](#dom-gpucompilationmessage-message) does not correspond to any specific point in the
 shader
 [`code`](#dom-gpushadermoduledescriptor-code).

[`linePos`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly

: The offset, in UTF-16 code units, from the beginning of line
 [`lineNum`](#dom-gpucompilationmessage-linenum) of the shader
 [`code`](#dom-gpushadermoduledescriptor-code) to the point or beginning of the substring that the
 [`message`](#dom-gpucompilationmessage-message) corresponds to. Value is one-based, such that a
 [`linePos`](#dom-gpucompilationmessage-linepos) of `1` indicates the first code unit of the line.

 If
 [`message`](#dom-gpucompilationmessage-message) corresponds to a substring this points to the first
 UTF-16 code unit of the substring. Must be `0` if the
 [`message`](#dom-gpucompilationmessage-message) does not correspond to any specific point in the
 shader
 [`code`](#dom-gpushadermoduledescriptor-code).

[`offset`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly

: The offset from the beginning of the shader
 [`code`](#dom-gpushadermoduledescriptor-code) in UTF-16 code units to the point or beginning of
 the substring that
 [`message`](#dom-gpucompilationmessage-message) corresponds to. Must reference the same position as
 [`lineNum`](#dom-gpucompilationmessage-linenum) and
 [`linePos`](#dom-gpucompilationmessage-linepos). Must be `0` if the
 [`message`](#dom-gpucompilationmessage-message) does not correspond to any specific point in the
 shader
 [`code`](#dom-gpushadermoduledescriptor-code).

[`length`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly

: The number of UTF-16 code units in the substring that
 [`message`](#dom-gpucompilationmessage-message) corresponds to. If the message does not correspond
 with a substring then
 [`length`](#dom-gpucompilationmessage-length) must be 0.

[`GPUCompilationMessage`](#gpucompilationmessage).[`lineNum`](#dom-gpucompilationmessage-linenum) and
[`GPUCompilationMessage`](#gpucompilationmessage).[`linePos`](#dom-gpucompilationmessage-linepos) are one-based since the most common use for them is
expected to be printing human readable messages that can be correlated
with the line and column numbers shown in many text editors.

[`GPUCompilationMessage`](#gpucompilationmessage).[`offset`](#dom-gpucompilationmessage-offset) and
[`GPUCompilationMessage`](#gpucompilationmessage).[`length`](#dom-gpucompilationmessage-length) are appropriate to pass to `substr()` in order to
retrieve the substring of the shader
[`code`](#dom-gpushadermoduledescriptor-code) the
[`message`](#dom-gpucompilationmessage-message) corresponds to.

[`getCompilationInfo()`]

: Returns any messages generated during the
 [`GPUShaderModule`](#gpushadermodule)'s compilation.

 The locations, order, and contents of messages are
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). In particular, messages aren't necessarily ordered
 by
 [`lineNum`](#dom-gpucompilationmessage-linenum).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUShaderModule`](#gpushadermodule) this
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`GPUCompilationInfo`](#gpucompilationinfo)\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Issue the `synchronization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `synchronization steps`:
 1. Let `event` occur upon the (successful or
 unsuccessful) completion of [shader module
 creation](https://gpuweb.github.io/gpuweb/wgsl/#shader-module-creation) for `this`.

 2. [Listen for timeline
 event](#abstract-opdef-listen-for-timeline-event) `event` on
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot), handled by the subsequent steps on
 `contentTimeline`.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) steps:
 1. Let `info` be a new
 [`GPUCompilationInfo`](#gpucompilationinfo).

 2. Let `messages` be a list of any errors, warnings, or
 informational messages generated during [shader module
 creation](https://gpuweb.github.io/gpuweb/wgsl/#shader-module-creation) for `this`, or the empty list ``
 if the device was lost.

 3. For each `message` in `messages`:

 1. Let `m` be a new
 [`GPUCompilationMessage`](#gpucompilationmessage).

 2. Set
 `m`.[`message`](#dom-gpucompilationmessage-message) to be the text of `message`.

 3.

 If `message` is a [shader-creation error](https://gpuweb.github.io/gpuweb/wgsl/#shader-creation-error):

 : Set
 `m`.[`type`](#dom-gpucompilationmessage-type) to
 [`"error"`](#dom-gpucompilationmessagetype-error)

 If `message` is a warning:

 : Set
 `m`.[`type`](#dom-gpucompilationmessage-type) to
 [`"warning"`](#dom-gpucompilationmessagetype-warning)

 Otherwise:

 : Set
 `m`.[`type`](#dom-gpucompilationmessage-type) to
 [`"info"`](#dom-gpucompilationmessagetype-info)

 4.

 If `message` is associated with a specific substring or position within the shader [`code`](#dom-gpushadermoduledescriptor-code):

 : 1. Set
 `m`.[`lineNum`](#dom-gpucompilationmessage-linenum) to the one-based number of the
 first line that the message refers to.

 2. Set
 `m`.[`linePos`](#dom-gpucompilationmessage-linepos) to the one-based number of the
 first UTF-16 code units on
 `m`.[`lineNum`](#dom-gpucompilationmessage-linenum) that the message refers to, or `1`
 if the `message` refers to the entire
 line.

 3. Set
 `m`.[`offset`](#dom-gpucompilationmessage-offset) to the number of UTF-16 code units
 from the beginning of the shader to beginning of the
 substring or position that `message`
 refers to.

 4. Set
 `m`.[`length`](#dom-gpucompilationmessage-length) the length of the substring in
 UTF-16 code units that `message` refers
 to, or 0 if `message` refers to a
 position

 Otherwise:

 : 1. Set
 `m`.[`lineNum`](#dom-gpucompilationmessage-linenum) to `0`.

 2. Set
 `m`.[`linePos`](#dom-gpucompilationmessage-linepos) to `0`.

 3. Set
 `m`.[`offset`](#dom-gpucompilationmessage-offset) to `0`.

 4. Set
 `m`.[`length`](#dom-gpucompilationmessage-length) to `0`.

 5. [Append](https://infra.spec.whatwg.org/#list-append) `m` to
 `info`.[`messages`](#dom-gpucompilationinfo-messages).

 4. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with `info`.
 :::
 ::::::

## 10. Pipelines

A [pipeline], be
it
[`GPUComputePipeline`](#gpucomputepipeline) or
[`GPURenderPipeline`](#gpurenderpipeline), represents the complete function done by a combination
of the GPU hardware, the driver, and the user agent, that process the
input data in the shape of bindings and vertex buffers, and produces
some output, like the colors in the output render targets.

Structurally, the [pipeline](#pipeline) consists of a sequence of programmable stages (shaders)
and fixed-function states, such as the blending modes.

 Internally, depending on the target platform, the
driver may convert some of the fixed-function states into shader code,
and link it together with the shaders provided by the user. This linking
is one of the reason the object is created as a whole.

This combination state is created as a single object (a
[`GPUComputePipeline`](#gpucomputepipeline) or
[`GPURenderPipeline`](#gpurenderpipeline)) and switched using one command
([`GPUComputePassEncoder`](#gpucomputepassencoder).[`setPipeline()`](#dom-gpucomputepassencoder-setpipeline) or
[`GPURenderCommandsMixin`](#gpurendercommandsmixin).[`setPipeline()`](#dom-gpurendercommandsmixin-setpipeline) respectively).

There are two ways to create pipelines:

[immediate pipeline creation]

: [`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) and
 [`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline) return a pipeline object which can be used
 immediately in a pass encoder.

 When this fails, the pipeline object will be invalid and the call
 will generate either a [validation
 error](#abstract-opdef-generate-a-validation-error) or an [internal
 error](#abstract-opdef-generate-an-internal-error).

 A handle object is returned immediately, but actual
 pipeline creation is not synchronous. If pipeline creation takes a
 long time, this can incur a stall in the [device
 timeline](#device-timeline) at some point between the creation call and
 execution of the
 [`submit()`](#dom-gpuqueue-submit) in which it is first used. The point is
 unspecified, but most likely to be one of: at creation, at the first
 usage of the pipeline in `setPipeline()`, at the corresponding
 `finish()` of that
 [`GPUCommandEncoder`](#gpucommandencoder) or
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder), or at
 [`submit()`](#dom-gpuqueue-submit) of that
 [`GPUCommandBuffer`](#gpucommandbuffer).

[async pipeline creation]

: [`createComputePipelineAsync()`](#dom-gpudevice-createcomputepipelineasync) and
 [`createRenderPipelineAsync()`](#dom-gpudevice-createrenderpipelineasync) return a `Promise` which resolves to a pipeline
 object when creation of the pipeline has completed.

 When this fails, the `Promise` rejects with a
 [`GPUPipelineError`](#gpupipelineerror).

[`GPUPipelineError`] describes a pipeline creation failure.

```
[Exposed=(Window, Worker), SecureContext, Serializable]
interface GPUPipelineError : DOMException {
 constructor(optional DOMString message = "", GPUPipelineErrorInit options);
 readonly attribute GPUPipelineErrorReason reason;
};

dictionary GPUPipelineErrorInit {
 required GPUPipelineErrorReason reason;
};

enum GPUPipelineErrorReason {
 "validation",
 "internal",
};
```

[`GPUPipelineError`](#gpupipelineerror) constructor:

[`constructor()`]

: :::
 **Arguments:**
 Arguments for the
 [GPUPipelineError.constructor()](#dom-gpupipelineerror-constructor) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`message`]
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)
 [✘]
 [✔]
 Error message of the base
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
 [`options`]
 [`GPUPipelineErrorInit`](#dictdef-gpupipelineerrorinit)
 [✘]
 [✘]
 Options specific to
 [`GPUPipelineError`](#gpupipelineerror).
 [Content timeline](#content-timeline) steps:

 1. Set [this](https://webidl.spec.whatwg.org/#this).[name](https://webidl.spec.whatwg.org/#domexception-name) to `"GPUPipelineError"`.

 2. Set [this](https://webidl.spec.whatwg.org/#this).[message](https://webidl.spec.whatwg.org/#domexception-message) to `message`.

 3. Set [this](https://webidl.spec.whatwg.org/#this).[`reason`](#dom-gpupipelineerror-reason) to
 `options`.[`reason`](#dom-gpupipelineerrorinit-reason).
 :::

[`GPUPipelineError`](#gpupipelineerror) has the following attributes:

[`reason`], of type [GPUPipelineErrorReason](#enumdef-gpupipelineerrorreason), readonly

: A read-only [slot-backed
 attribute](#slot-backed-attribute) exposing the type of error encountered in pipeline
 creation as a
 [`GPUPipelineErrorReason`]:

 - [`"validation"`]: A [validation
 error](#abstract-opdef-generate-a-validation-error).

 - [`"internal"`]: An [internal
 error](#abstract-opdef-generate-an-internal-error).

[`GPUPipelineError`](#gpupipelineerror) objects are [serializable
objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects).

Their [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps), given `value` and `serialized`,
are:

1. Run the
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) [serialization
 steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) given `value` and
 `serialized`.

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `value` and `serialized`,
are:

1. Run the
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) [deserialization
 steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) given `value` and
 `serialized`.

### 10.1. Base pipelines

```
enum GPUAutoLayoutMode {
 "auto",
};

dictionary GPUPipelineDescriptorBase
 : GPUObjectDescriptorBase {
 required (GPUPipelineLayout or GPUAutoLayoutMode) layout;
};
```

[`layout`], of type `(GPUPipelineLayout or GPUAutoLayoutMode)`

: The
 [`GPUPipelineLayout`](#gpupipelinelayout) for this pipeline, or
 [`"auto"`](#dom-gpuautolayoutmode-auto) to generate the pipeline layout automatically.

 If
 [`"auto"`](#dom-gpuautolayoutmode-auto) is used the pipeline cannot share
 [`GPUBindGroup`](#gpubindgroup)s with any other pipelines.

```
interface mixin GPUPipelineBase {
 [NewObject] GPUBindGroupLayout getBindGroupLayout(unsigned long index);
};
```

[`GPUPipelineBase`](#gpupipelinebase) has the following [device timeline
properties](#device-timeline-property):

[`[[layout]]`], of type `GPUPipelineLayout`

: The definition of the layout of resources which can be used with
 `this`.

[`GPUPipelineBase`](#gpupipelinebase) has the following methods:

[`getBindGroupLayout(index)`]

: Gets a
 [`GPUBindGroupLayout`](#gpubindgrouplayout) that is compatible with the
 [`GPUPipelineBase`](#gpupipelinebase)'s
 [`GPUBindGroupLayout`](#gpubindgrouplayout) at `index`.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUPipelineBase`](#gpupipelinebase) `this`
 **Arguments:**

 Arguments for the
 [GPUPipelineBase.getBindGroupLayout(index)](#dom-gpupipelinebase-getbindgrouplayout) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`index`]
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)
 [✘]
 [✘]
 Index into the pipeline layout's
 [`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot) sequence.
 **Returns:**
 [`GPUBindGroupLayout`](#gpubindgrouplayout)

 [Content timeline](#content-timeline) steps:

 1. Let `layout` be a new
 [`GPUBindGroupLayout`](#gpubindgrouplayout) object.

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `layout`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `limits` be
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).

 2. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `layout` and return.

 ::: validusage
 - `this` must be
 [valid](#abstract-opdef-valid).

 - `index` \<
 `limits`.[`maxBindGroups`](#dom-supported-limits-maxbindgroups).
 :::

 3. Initialize `layout` so it is a copy of
 `this`.[`[[layout]]`](#dom-gpupipelinebase-layout-slot).[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot)\[`index`\].

 [`GPUBindGroupLayout`](#gpubindgrouplayout) is only ever used by-value, not by-reference,
 so this is equivalent to returning the same [internal
 object](#internal-object) with a new [WebGPU
 interface](#webgpu-interface). A new
 [`GPUBindGroupLayout`](#gpubindgrouplayout) [WebGPU
 interface](#webgpu-interface) is returned each time to avoid a round-trip
 between the [Content
 timeline](#content-timeline) and the [Device
 timeline](#device-timeline).
 :::
 :::::

#### 10.1.1. Default pipeline layout

A [`GPUPipelineBase`](#gpupipelinebase) object that was created with a
[`layout`](#dom-gpupipelinedescriptorbase-layout) set to
[`"auto"`](#dom-gpuautolayoutmode-auto) has a default layout created and used instead.

 Default layouts are provided as a convenience for
simple pipelines, but use of explicit layouts is recommended in most
cases. Bind groups created from default layouts cannot be used with
other pipelines, and the structure of the default layout may change when
altering shaders, causing unexpected bind group creation errors.

To create a [default pipeline
layout] for
[`GPUPipelineBase`](#gpupipelinebase) `pipeline`, run the following [device
timeline](#device-timeline)
steps:

1. Let `groupCount` be 0.

2. Let `groupDescs` be a sequence of
 `device`.[`[[limits]]`](#dom-device-limits-slot).[`maxBindGroups`](#dom-supported-limits-maxbindgroups) new
 [`GPUBindGroupLayoutDescriptor`](#dictdef-gpubindgrouplayoutdescriptor) objects.

3. For each `groupDesc` in `groupDescs`:

 1. Set
 `groupDesc`.[`entries`](#dom-gpubindgrouplayoutdescriptor-entries) to an empty
 [sequence](https://webidl.spec.whatwg.org/#idl-sequence).

4. For each
 [`GPUProgrammableStage`](#gpuprogrammablestage) `stageDesc` in the descriptor used to
 create `pipeline`:

 1. Let `shaderStage` be the
 [`GPUShaderStageFlags`](#typedefdef-gpushaderstageflags) for the shader stage at which
 `stageDesc` is used in `pipeline`.

 2. Let `entryPoint` be [get the entry
 point](#abstract-opdef-get-the-entry-point)(`shaderStage`,
 `stageDesc`).
 [Assert](https://infra.spec.whatwg.org/#assert) `entryPoint` is not `null`.

 3. For each resource `resource` [statically
 used](#statically-used) by `entryPoint`:

 1. Let `group` be `resource`'s \"group\"
 decoration.

 2. Let `binding` be `resource`'s
 \"binding\" decoration.

 3. Let `entry` be a new
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry).

 4. Set
 `entry`.[`binding`](#dom-gpubindgrouplayoutentry-binding) to `binding`.

 5. Set
 `entry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) to `shaderStage`.

 6. If `resource` is for a sampler binding:

 1. Let `samplerLayout` be a new
 [`GPUSamplerBindingLayout`](#dictdef-gpusamplerbindinglayout).

 2. Set
 `entry`.[`sampler`](#dom-gpubindgrouplayoutentry-sampler) to `samplerLayout`.

 7. If `resource` is for a comparison sampler
 binding:

 1. Let `samplerLayout` be a new
 [`GPUSamplerBindingLayout`](#dictdef-gpusamplerbindinglayout).

 2. Set
 `samplerLayout`.[`type`](#dom-gpusamplerbindinglayout-type) to
 [`"comparison"`](#dom-gpusamplerbindingtype-comparison).

 3. Set
 `entry`.[`sampler`](#dom-gpubindgrouplayoutentry-sampler) to `samplerLayout`.

 8. If `resource` is for a buffer binding:

 1. Let `bufferLayout` be a new
 [`GPUBufferBindingLayout`](#dictdef-gpubufferbindinglayout).

 2. Set
 `bufferLayout`.[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) to `resource`'s [minimum
 buffer binding
 size](#minimum-buffer-binding-size).

 3. If `resource` is for a read-only storage
 buffer:

 1. Set
 `bufferLayout`.[`type`](#dom-gpubufferbindinglayout-type) to
 [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage).

 4. If `resource` is for a storage buffer:

 1. Set
 `bufferLayout`.[`type`](#dom-gpubufferbindinglayout-type) to
 [`"storage"`](#dom-gpubufferbindingtype-storage).

 5. Set
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer) to `bufferLayout`.

 9. If `resource` is for a sampled texture binding:

 1. Let `textureLayout` be a new
 [`GPUTextureBindingLayout`](#dictdef-gputexturebindinglayout).

 2. If `resource` is a depth texture binding:

 - Set
 `textureLayout`.[`sampleType`](#dom-gputexturebindinglayout-sampletype) to
 [`"depth"`](#dom-gputexturesampletype-depth)

 Otherwise, if the sampled type of `resource`
 is:

 `f32` and there exists a [static use](#statically-used) of `resource` by `stageDesc` in a texture builtin function call that also uses a sampler

 : Set
 `textureLayout`.[`sampleType`](#dom-gputexturebindinglayout-sampletype) to
 [`"float"`](#dom-gputexturesampletype-float)

 `f32` otherwise

 : Set
 `textureLayout`.[`sampleType`](#dom-gputexturebindinglayout-sampletype) to
 [`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

 `i32`

 : Set
 `textureLayout`.[`sampleType`](#dom-gputexturebindinglayout-sampletype) to
 [`"sint"`](#dom-gputexturesampletype-sint)

 `u32`

 : Set
 `textureLayout`.[`sampleType`](#dom-gputexturebindinglayout-sampletype) to
 [`"uint"`](#dom-gputexturesampletype-uint)

 3. Set
 `textureLayout`.[`viewDimension`](#dom-gputexturebindinglayout-viewdimension) to `resource`'s dimension.

 4. If `resource` is for a multisampled texture:

 1. Set
 `textureLayout`.[`multisampled`](#dom-gputexturebindinglayout-multisampled) to `true`.

 5. Set
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture) to `textureLayout`.

 10. If `resource` is for a storage texture binding:

 1. Let `storageTextureLayout` be a new
 [`GPUStorageTextureBindingLayout`](#dictdef-gpustoragetexturebindinglayout).

 2. Set
 `storageTextureLayout`.[`format`](#dom-gpustoragetexturebindinglayout-format) to `resource`'s format.

 3. Set
 `storageTextureLayout`.[`viewDimension`](#dom-gpustoragetexturebindinglayout-viewdimension) to `resource`'s dimension.

 4. If the access mode is:

 `read`

 : Set
 `textureLayout`.[`access`](#dom-gpustoragetexturebindinglayout-access) to
 [`"read-only"`](#dom-gpustoragetextureaccess-read-only).

 `write`

 : Set
 `textureLayout`.[`access`](#dom-gpustoragetexturebindinglayout-access) to
 [`"write-only"`](#dom-gpustoragetextureaccess-write-only).

 `read_write`

 : Set
 `textureLayout`.[`access`](#dom-gpustoragetexturebindinglayout-access) to
 [`"read-write"`](#dom-gpustoragetextureaccess-read-write).

 5. Set
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) to `storageTextureLayout`.

 11. Set `groupCount` to max(`groupCount`,
 `group` + 1).

 12. If `groupDescs`\[`group`\] has an
 entry `previousEntry` with
 [`binding`](#dom-gpubindgrouplayoutentry-binding) equal to `binding`:

 1. If `entry` has different
 [`visibility`](#dom-gpubindgrouplayoutentry-visibility) than `previousEntry`:

 1. Add the bits set in
 `entry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) into
 `previousEntry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility)

 2. If `resource` is for a buffer binding and
 `entry` has greater
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) than `previousEntry`:

 1. Set
 `previousEntry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) to
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize).

 3. If `resource` is a sampled texture binding
 and `entry` has different
 [`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) than `previousEntry` and
 both `entry` and `previousEntry`
 have
 [`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) of either
 [`"float"`](#dom-gputexturesampletype-float) or
 [`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float):

 1. Set
 `previousEntry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) to
 [`"float"`](#dom-gputexturesampletype-float).

 4. If any other property is unequal between
 `entry` and `previousEntry`:

 1. Return `null` (which will cause the creation of the
 pipeline to fail).

 5. If `resource` is a storage texture binding,
 `entry`.`storageTexture`.[`access`](#dom-gpustoragetexturebindinglayout-access) is
 [`"read-write"`](#dom-gpustoragetextureaccess-read-write),
 `previousEntry`.`storageTexture`.[`access`](#dom-gpustoragetexturebindinglayout-access) is
 [`"write-only"`](#dom-gpustoragetextureaccess-write-only), and
 `previousEntry`.`storageTexture`.[`format`](#dom-gpustoragetexturebindinglayout-format) is compatible with
 [`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) and
 [`"read-write"`](#dom-gpustoragetextureaccess-read-write) according to the [§ 26.1.1 Plain color
 formats](#plain-color-formats) table:

 1. Set
 `previousEntry`.`storageTexture`.[`access`](#dom-gpustoragetexturebindinglayout-access) to
 [`"read-write"`](#dom-gpustoragetextureaccess-read-write).

 Otherwise:

 1. Append `entry` to
 `groupDescs`\[`group`\].

5. Let `groupLayouts` be a new
 [list](https://infra.spec.whatwg.org/#list).

6. For each `i` from 0 to `groupCount` - 1,
 inclusive:

 1. Let `groupDesc` be
 `groupDescs`\[`i`\].

 2. Let `bindGroupLayout` be the result of calling
 `device`.[`createBindGroupLayout()`](#dom-gpudevice-createbindgrouplayout)(`groupDesc`).

 3. Set
 `bindGroupLayout`.[`[[exclusivePipeline]]`](#dom-gpubindgrouplayout-exclusivepipeline-slot) to `pipeline`.

 4. Append `bindGroupLayout` to
 `groupLayouts`.

7. Let `desc` be a new
 [`GPUPipelineLayoutDescriptor`](#dictdef-gpupipelinelayoutdescriptor).

8. Set
 `desc`.[`bindGroupLayouts`](#dom-gpupipelinelayoutdescriptor-bindgrouplayouts) to `groupLayouts`.

9. Return
 `device`.[`createPipelineLayout()`](#dom-gpudevice-createpipelinelayout)(`desc`).

#### 10.1.2. `GPUProgrammableStage`

A
[`GPUProgrammableStage`](#gpuprogrammablestage) describes the entry point in the user-provided
[`GPUShaderModule`](#gpushadermodule) that controls one of the programmable stages of a
[pipeline](#pipeline). Entry point
names follow the rules defined in [WGSL identifier
comparison](https://gpuweb.github.io/gpuweb/wgsl/#identifier-comparison).

```
dictionary GPUProgrammableStage {
 required GPUShaderModule module;
 USVString entryPoint;
 record<USVString, GPUPipelineConstantValue> constants = ;
};

typedef double GPUPipelineConstantValue; // May represent WGSL's bool, f32, i32, u32, and f16 if enabled.
```

[`GPUProgrammableStage`](#gpuprogrammablestage) has the following members:

[`module`], of type [GPUShaderModule](#gpushadermodule)

: The
 [`GPUShaderModule`](#gpushadermodule) containing the code that this programmable stage
 will execute.

[`entryPoint`], of type [USVString](https://webidl.spec.whatwg.org/#idl-USVString)

: The name of the function in
 [`module`](#dom-gpuprogrammablestage-module) that this stage will use to perform its work.

 [NOTE:] Since the
 [`entryPoint`](#dom-gpuprogrammablestage-entrypoint) dictionary member is not required, methods which
 consume a
 [`GPUProgrammableStage`](#gpuprogrammablestage) must use the \"[get the entry
 point](#abstract-opdef-get-the-entry-point)\" algorithm to determine which entry point
 it refers to.

[`constants`], of type record\<[USVString](https://webidl.spec.whatwg.org/#idl-USVString), [GPUPipelineConstantValue](#typedefdef-gpupipelineconstantvalue)\>, defaulting to ``

: Specifies the values of
 [pipeline-overridable](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable) constants in the shader module
 [`module`](#dom-gpuprogrammablestage-module).

 Each such
 [pipeline-overridable](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable) constant is uniquely identified by a single
 [pipeline-overridable constant identifier
 string](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable-constant-identifier-string), representing the [pipeline constant
 ID](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-constant-id) of the constant if its declaration specifies one,
 and otherwise the constant's identifier name.

 The key of each key-value pair must equal the [identifier
 string](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable-constant-identifier-string) of one such constant, with the comparison performed
 according to the rules for [WGSL identifier
 comparison](https://gpuweb.github.io/gpuweb/wgsl/#identifier-comparison). When the pipeline is executed, that constant will
 have the specified value.

 Values are specified as
 [`GPUPipelineConstantValue`], which is a
 [`double`](https://webidl.spec.whatwg.org/#idl-double). They are converted [to WGSL
 type](#abstract-opdef-to-wgsl-type) of the pipeline-overridable constant
 (`bool`/`i32`/`u32`/`f32`/`f16`). If conversion fails, a validation
 error is generated.

 :::
 (#example-fd463ccc) Pipeline-overridable constants
 defined in WGSL:
 ``` highlight
 @id(0) override has_point_light: bool = true; // Algorithmic control.
 @id(1200) override specular_param: f32 = 2.3; // Numeric control.
 @id(1300) override gain: f32; // Must be overridden.
 override width: f32 = 0.0; // Specifed at the API level
 // using the name "width".
 override depth: f32; // Specifed at the API level
 // using the name "depth".
 // Must be overridden.
 override height = 2 * depth; // The default value
 // (if not set at the API level),
 // depends on another
 // overridable constant.
 ```

 Corresponding JavaScript code, providing only the overrides which
 are required (have no defaults):

 ``` highlight
 {
 // ...
 constants: {
 1300: 2.0, // "gain"
 depth: -1, // "depth"
 }
 }
 ```

 Corresponding JavaScript code, overriding all constants:

 ``` highlight
 {
 // ...
 constants: {
 0: false, // "has_point_light"
 1200: 3.0, // "specular_param"
 1300: 2.0, // "gain"
 width: 20, // "width"
 depth: -1, // "depth"
 height: 15, // "height"
 }
 }
 ```
 :::

To [get the entry point]([`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`,
[`GPUProgrammableStage`](#gpuprogrammablestage) `descriptor`), run the following [device
timeline](#device-timeline)
steps:

1. If
 `descriptor`.[`entryPoint`](#dom-gpuprogrammablestage-entrypoint) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. If
 `descriptor`.[`module`](#dom-gpuprogrammablestage-module) contains an entry point whose name equals
 `descriptor`.[`entryPoint`](#dom-gpuprogrammablestage-entrypoint), and whose shader stage equals
 `stage`, return that entry point.

 Otherwise, return `null`.

 Otherwise:

 1. If there is exactly one entry point in
 `descriptor`.[`module`](#dom-gpuprogrammablestage-module) whose shader stage equals `stage`,
 return that entry point.

 Otherwise, return `null`.

[validating
GPUProgrammableStage](`stage`,
`descriptor`, `layout`, `device`)

**Arguments:**

- [`GPUShaderStage`](#namespacedef-gpushaderstage) `stage`

- [`GPUProgrammableStage`](#gpuprogrammablestage) `descriptor`

- [`GPUPipelineLayout`](#gpupipelinelayout) `layout`

- [`GPUDevice`](#gpudevice)
 `device`

All of the requirements in the following steps `must` be met.
If any are unmet, return `false`; otherwise, return `true`.

1. `descriptor`.[`module`](#dom-gpuprogrammablestage-module) `must` be [valid to use
 with](#abstract-opdef-valid-to-use-with) `device`.

2. Let `entryPoint` be [get the entry
 point](#abstract-opdef-get-the-entry-point)(`stage`,
 `descriptor`).

3. `entryPoint` `must` not be `null`.

4. For each `binding` that is [statically
 used](#statically-used)
 by `entryPoint`:

 - [validating shader
 binding](#abstract-opdef-validating-shader-binding)(`binding`,
 `layout`) `must` return `true`.

5. For each call `call` to a texture builtin function in any
 of the [functions in the shader
 stage](https://gpuweb.github.io/gpuweb/wgsl/#functions-in-a-shader-stage) rooted at `entryPoint`:

 1. Let `textureBinding` be the texture binding used in
 `call`.

 2. If `textureBinding` is of type [sampled
 texture](https://gpuweb.github.io/gpuweb/wgsl/#type-sampled-texture) or [depth
 texture](https://gpuweb.github.io/gpuweb/wgsl/#type-depth-texture) and `call` uses a sampler binding
 `samplerBinding` of type `sampler` (excluding
 `sampler_comparison`):

 1. Let `texture` be the
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) corresponding to
 `textureBinding`.

 2. Let `sampler` be the
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) corresponding to
 `samplerBinding`.

 3. If
 `sampler`.[`type`](#dom-gpusamplerbindinglayout-type) is
 [`"filtering"`](#dom-gpusamplerbindingtype-filtering), then
 `texture`.[`sampleType`](#dom-gputexturebindinglayout-sampletype) `must` be
 [`"float"`](#dom-gputexturesampletype-float).

 [`"comparison"`](#dom-gpusamplerbindingtype-comparison) samplers can also only be used with
 [`"depth"`](#dom-gputexturesampletype-depth) textures, because they are the only texture
 type that can be bound to WGSL `texture_depth_*` bindings.

 3. ::: compatmode
 If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 1. If `call` is a call to `textureLoad`,
 `textureBinding` must not be of type [depth
 texture](https://gpuweb.github.io/gpuweb/wgsl/#type-depth-texture).

 2. If `call` uses a sampler binding
 `samplerBinding` and `textureBinding`
 is of type [depth
 texture](https://gpuweb.github.io/gpuweb/wgsl/#type-depth-texture), `samplerBinding` must be of
 `sampler_comparison` type.
 :::

6. For each `key` → `value` in
 `descriptor`.[`constants`](#dom-gpuprogrammablestage-constants):

 1. `key` `must` equal the
 [pipeline-overridable constant identifier
 string](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable-constant-identifier-string) of some
 [pipeline-overridable](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable) constant defined in the shader module
 `descriptor`.[`module`](#dom-gpuprogrammablestage-module) by the rules defined in [WGSL identifier
 comparison](https://gpuweb.github.io/gpuweb/wgsl/#identifier-comparison). The pipeline-overridable constant is *not*
 required to be [statically
 used](#statically-used) by `entryPoint`. Let the type of
 that constant be `T`.

 2. Converting the IDL value `value` [to WGSL
 type](#abstract-opdef-to-wgsl-type) `T` `must` not
 throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

7. For each [pipeline-overridable constant identifier
 string](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable-constant-identifier-string) `key` which is [statically
 used](#statically-used)
 by `entryPoint`:

 - If the pipeline-overridable constant identified by
 `key` [does not have a default
 value](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable-constant-default-value),
 `descriptor`.[`constants`](#dom-gpuprogrammablestage-constants) `must`
 [contain](https://infra.spec.whatwg.org/#map-exists) `key`.

8. [Pipeline-creation](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-creation-error) [program
 errors](https://gpuweb.github.io/gpuweb/wgsl/#program-error) `must` not result from the rules of the
 [\[WGSL\]](#biblio-wgsl "WebGPU Shading Language")
 specification.

9. ::: compatmode
 If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 1. Let `sum` be 0.

 2. For each unique texture or external texture binding
 `textureBinding` that is used in any call to a
 texture builtin in any of the [functions in the shader
 stage](https://gpuweb.github.io/gpuweb/wgsl/#functions-in-a-shader-stage) rooted at `entryPoint`:

 1. Let `samplerBindings` be the set of sampler
 bindings used together with `textureBinding` in
 any call to a texture builtin in any of the [functions in
 the shader
 stage](https://gpuweb.github.io/gpuweb/wgsl/#functions-in-a-shader-stage) rooted at `entryPoint`.

 2. Let `numPairs` be
 `max(1, number of elements of ``samplerBindings``)`.

 3. If `textureBinding` is an external texture
 binding:

 1. Let `numPairs` be
 `1 + 3 * ``numPairs`.

 4. Let `sum` be
 `sum`` + ``numPairs`.

 3. `sum` `must` be ≤
 `device`.limits.[`maxSampledTexturesPerShaderStage`](#dom-supported-limits-maxsampledtexturespershaderstage).

 4. `sum` `must` be ≤
 `device`.limits.[`maxSamplersPerShaderStage`](#dom-supported-limits-maxsamplerspershaderstage).
 :::

[validating shader binding](`variable`, `layout`)

**Arguments:**

- shader binding declaration `variable`, a module-scope
 variable declaration reflected from a shader module

- [`GPUPipelineLayout`](#gpupipelinelayout) `layout`

Let `bindGroup` be the bind group index, and
`bindIndex` be the binding index, of the shader binding
declaration `variable`.

Return `true` if all of the following conditions are satisfied:

- `layout`.[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot)\[`bindGroup`\] contains a
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `entry` whose
 `entry`.[`binding`](#dom-gpubindgrouplayoutentry-binding) == `bindIndex`.

- If the defined [binding
 member](#binding-member) for
 `entry` is:

 [`buffer`](#dom-gpubindgrouplayoutentry-buffer)

 : If
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`type`](#dom-gpubufferbindinglayout-type) is:

 [`"uniform"`](#dom-gpubufferbindingtype-uniform)

 : `variable` is declared with address space
 `uniform`.

 [`"storage"`](#dom-gpubufferbindingtype-storage)

 : `variable` is declared with address space `storage`
 and access mode `read_write`.

 [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage)

 : `variable` is declared with address space `storage`
 and access mode `read`.

 : If
 `entry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) is not `0`, then it must be at least the [minimum
 buffer binding
 size](#minimum-buffer-binding-size) for the associated buffer binding variable in the
 shader.

 [`sampler`](#dom-gpubindgrouplayoutentry-sampler)

 : If
 `entry`.[`sampler`](#dom-gpubindgrouplayoutentry-sampler).[`type`](#dom-gpusamplerbindinglayout-type) is:

 [`"filtering"`](#dom-gpusamplerbindingtype-filtering) or [`"non-filtering"`](#dom-gpusamplerbindingtype-non-filtering)

 : `variable` has type `sampler`.

 [`"comparison"`](#dom-gpusamplerbindingtype-comparison)

 : `variable` has type `sampler_comparison`.

 [`texture`](#dom-gpubindgrouplayoutentry-texture)

 : If, and only if,
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`multisampled`](#dom-gputexturebindinglayout-multisampled) is `true`, `variable` has type
 `texture_multisampled_2d<T>` or
 `texture_depth_multisampled_2d<T>`.

 : If
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) is:

 [`"float"`](#dom-gputexturesampletype-float), [`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float), [`"sint"`](#dom-gputexturesampletype-sint) or [`"uint"`](#dom-gputexturesampletype-uint)

 : `variable` has one of the types:

 - `texture_1d<T>`

 - `texture_2d<T>`

 - `texture_2d_array<T>`

 - `texture_cube<T>`

 - `texture_cube_array<T>`

 - `texture_3d<T>`

 - `texture_multisampled_2d<T>`

 : If
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`sampleType`](#dom-gputexturebindinglayout-sampletype) is:

 [`"float"`](#dom-gputexturesampletype-float) or [`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

 : The sampled type `T` is `f32`.

 [`"sint"`](#dom-gputexturesampletype-sint)

 : The sampled type `T` is `i32`.

 [`"uint"`](#dom-gputexturesampletype-uint)

 : The sampled type `T` is `u32`.

 [`"depth"`](#dom-gputexturesampletype-depth)

 : `variable` has one of the types:

 - `texture_2d<T>`

 - `texture_2d_array<T>`

 - `texture_cube<T>`

 - `texture_cube_array<T>`

 - `texture_multisampled_2d<T>`

 - `texture_depth_2d`

 - `texture_depth_2d_array`

 - `texture_depth_cube`

 - `texture_depth_cube_array`

 - `texture_depth_multisampled_2d`

 where the sampled type `T` is `f32`.

 : If
 `entry`.[`texture`](#dom-gpubindgrouplayoutentry-texture).[`viewDimension`](#dom-gputexturebindinglayout-viewdimension) is:

 [`"1d"`](#dom-gputextureviewdimension-1d)

 : `variable` has type `texture_1d<T>`.

 [`"2d"`](#dom-gputextureviewdimension-2d)

 : `variable` has type `texture_2d<T>` or
 `texture_multisampled_2d<T>`.

 [`"2d-array"`](#dom-gputextureviewdimension-2d-array)

 : `variable` has type `texture_2d_array<T>`.

 [`"cube"`](#dom-gputextureviewdimension-cube)

 : `variable` has type `texture_cube<T>`.

 [`"cube-array"`](#dom-gputextureviewdimension-cube-array)

 : `variable` has type `texture_cube_array<T>`.

 [`"3d"`](#dom-gputextureviewdimension-3d)

 : `variable` has type `texture_3d<T>`.

 [`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture)

 : If
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`viewDimension`](#dom-gpustoragetexturebindinglayout-viewdimension) is:

 [`"1d"`](#dom-gputextureviewdimension-1d)

 : `variable` has type `texture_storage_1d<T, A>`.

 [`"2d"`](#dom-gputextureviewdimension-2d)

 : `variable` has type `texture_storage_2d<T, A>`.

 [`"2d-array"`](#dom-gputextureviewdimension-2d-array)

 : `variable` has type
 `texture_storage_2d_array<T, A>`.

 [`"3d"`](#dom-gputextureviewdimension-3d)

 : `variable` has type `texture_storage_3d<T, A>`.

 : If
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`access`](#dom-gpustoragetexturebindinglayout-access) is:

 [`"write-only"`](#dom-gpustoragetextureaccess-write-only)

 : The access mode `A` is `write`.

 [`"read-only"`](#dom-gpustoragetextureaccess-read-only)

 : The access mode `A` is `read`.

 [`"read-write"`](#dom-gpustoragetextureaccess-read-write)

 : The access mode `A` is `read_write` or `write`.

 : The texel format `T` equals
 `entry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`format`](#dom-gpustoragetexturebindinglayout-format).

The [minimum buffer binding size] for a buffer binding variable
`var` is computed as follows:

1. Let `T` be the [store
 type](https://gpuweb.github.io/gpuweb/wgsl/#store-type) of `var`.

2. If `T` is a
 [runtime-sized](https://gpuweb.github.io/gpuweb/wgsl/#runtime-sized) array, or contains a runtime-sized array, replace
 that `array<E>` with `array<E, 1>`.

 This ensures there's always enough memory for one
 element, which allows array indices to be clamped to the length of
 the array resulting in an in-memory access.

3. Return
 [SizeOf](https://gpuweb.github.io/gpuweb/wgsl/#sizeof)(`T`).

 Enforcing this lower bound ensures reads and writes via
the buffer variable only access memory locations within the bound region
of the buffer.

A resource binding,
[pipeline-overridable](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-overridable) constant, shader stage input, or shader stage output is
considered to be [statically used] by an entry
point if it is present in the [interface of the shader
stage](https://gpuweb.github.io/gpuweb/wgsl/#interface-of-a-shader) for that entry point.

### 10.2. `GPUComputePipeline`

A
[`GPUComputePipeline`](#gpucomputepipeline) is a kind of [pipeline](#pipeline) that controls the compute shader stage, and can be used
in
[`GPUComputePassEncoder`](#gpucomputepassencoder).

Compute inputs and outputs are all contained in the bindings, according
to the given
[`GPUPipelineLayout`](#gpupipelinelayout). The outputs correspond to
[`buffer`](#dom-gpubindgrouplayoutentry-buffer) bindings with a type of
[`"storage"`](#dom-gpubufferbindingtype-storage) and
[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) bindings with a type of
[`"write-only"`](#dom-gpustoragetextureaccess-write-only) or
[`"read-write"`](#dom-gpustoragetextureaccess-read-write).

Stages of a compute [pipeline](#pipeline):

1. Compute shader

```
[Exposed=(Window, Worker), SecureContext]
interface GPUComputePipeline ;
GPUComputePipeline includes GPUObjectBase;
GPUComputePipeline includes GPUPipelineBase;
```

#### 10.2.1. Compute Pipeline Creation

A
[`GPUComputePipelineDescriptor`](#dictdef-gpucomputepipelinedescriptor) describes a compute
[pipeline](#pipeline). See [§ 23.1
Computing](#computing-operations) for additional details.

```
dictionary GPUComputePipelineDescriptor
 : GPUPipelineDescriptorBase {
 required GPUProgrammableStage compute;
};
```

[`GPUComputePipelineDescriptor`](#dictdef-gpucomputepipelinedescriptor) has the following members:

[`compute`], of type [GPUProgrammableStage](#gpuprogrammablestage)

: Describes the compute shader entry point of the
 [pipeline](#pipeline).

<!-- -->

[`createComputePipeline(descriptor)`]

: Creates a
 [`GPUComputePipeline`](#gpucomputepipeline) using [immediate pipeline
 creation](#immediate-pipeline-creation).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createComputePipeline(descriptor)](#dom-gpudevice-createcomputepipeline) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUComputePipelineDescriptor`](#dictdef-gpucomputepipelinedescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUComputePipeline`](#gpucomputepipeline) to create.
 **Returns:**
 [`GPUComputePipeline`](#gpucomputepipeline)

 [Content timeline](#content-timeline) steps:

 1. Let `pipeline` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUComputePipeline`](#gpucomputepipeline), `descriptor`).

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `pipeline`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `layout` be a new [default pipeline
 layout](#abstract-opdef-default-pipeline-layout) for `pipeline` if
 `descriptor`.[`layout`](#dom-gpupipelinedescriptorbase-layout) is
 [`"auto"`](#dom-gpuautolayoutmode-auto), and
 `descriptor`.[`layout`](#dom-gpupipelinedescriptorbase-layout) otherwise.

 2. All of the requirements in the following steps `must`
 be met. If any are unmet, [generate a validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `pipeline` and return.

 ::: validusage
 1. `layout` `must` be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 2. [validating
 GPUProgrammableStage](#abstract-opdef-validating-gpuprogrammablestage)([`COMPUTE`](#dom-gpushaderstage-compute),
 `descriptor`.[`compute`](#dom-gpucomputepipelinedescriptor-compute), `layout`, `this`)
 `must` succeed.

 3. Let `entryPoint` be [get the entry
 point](#abstract-opdef-get-the-entry-point)([`COMPUTE`](#dom-gpushaderstage-compute),
 `descriptor`.[`compute`](#dom-gpucomputepipelinedescriptor-compute)).

 [Assert](https://infra.spec.whatwg.org/#assert) `entryPoint` is not `null`.

 4. Let `workgroupStorageUsed` be the sum of
 [roundUp](https://gpuweb.github.io/gpuweb/wgsl/#roundup)(16,
 [SizeOf](https://gpuweb.github.io/gpuweb/wgsl/#sizeof)(`T`)) over each type
 `T` of all variables with address space
 \"[workgroup](https://gpuweb.github.io/gpuweb/wgsl/#address-spaces-workgroup)\" [statically
 used](#statically-used) by `entryPoint`.

 `workgroupStorageUsed` `must` be ≤
 `device`.limits.[`maxComputeWorkgroupStorageSize`](#dom-supported-limits-maxcomputeworkgroupstoragesize).

 5. `entryPoint` `must` use ≤
 `device`.limits.[`maxComputeInvocationsPerWorkgroup`](#dom-supported-limits-maxcomputeinvocationsperworkgroup) per workgroup.

 6. Each component of `entryPoint`'s `workgroup_size`
 attribute `must` be ≤ the corresponding component
 in
 \[`device`.limits.[`maxComputeWorkgroupSizeX`](#dom-supported-limits-maxcomputeworkgroupsizex),
 `device`.limits.[`maxComputeWorkgroupSizeY`](#dom-supported-limits-maxcomputeworkgroupsizey),
 `device`.limits.[`maxComputeWorkgroupSizeZ`](#dom-supported-limits-maxcomputeworkgroupsizez)\].
 :::

 3. If any
 [pipeline-creation](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-creation-error) [uncategorized
 errors](https://gpuweb.github.io/gpuweb/wgsl/#uncategorized-error) result from the implementation of pipeline
 creation, [generate an internal
 error](#abstract-opdef-generate-an-internal-error),
 [invalidate](#abstract-opdef-invalidate) `pipeline` and return.

 Even if the implementation detected
 [uncategorized
 errors](https://gpuweb.github.io/gpuweb/wgsl/#uncategorized-error) in shader module creation, the error is
 surfaced here.

 4. Set
 `pipeline`.[`[[layout]]`](#dom-gpupipelinebase-layout-slot) to `layout`.
 :::
 :::::

[`createComputePipelineAsync(descriptor)`]

: Creates a
 [`GPUComputePipeline`](#gpucomputepipeline) using [async pipeline
 creation](#async-pipeline-creation). The returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) resolves when the created pipeline is ready to be
 used without additional delay.

 If pipeline creation fails, the returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) rejects with an
 [`GPUPipelineError`](#gpupipelineerror). (A
 [`GPUError`](#gpuerror) is
 not dispatched to the device.)

 Use of this method is preferred whenever possible,
 as it prevents blocking the [queue
 timeline](#queue-timeline) work on pipeline compilation.

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createComputePipelineAsync(descriptor)](#dom-gpudevice-createcomputepipelineasync) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUComputePipelineDescriptor`](#dictdef-gpucomputepipelinedescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUComputePipeline`](#gpucomputepipeline) to create.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`GPUComputePipeline`](#gpucomputepipeline)\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `pipeline` be a new
 [`GPUComputePipeline`](#gpucomputepipeline) created as if
 `this`.[`createComputePipeline()`](#dom-gpudevice-createcomputepipeline) was called with `descriptor`, except
 capturing any errors as `error`, rather than
 dispatching them to the device.

 2. Let `event` occur upon the (successful or
 unsuccessful) completion of [pipeline
 creation](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-creation) for `pipeline`.

 3. [Listen for timeline
 event](#abstract-opdef-listen-for-timeline-event) `event` on
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot), handled by the subsequent steps on the [device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. If `pipeline` is
 [valid](#abstract-opdef-valid) or `this` is
 [lost](#abstract-opdef-invalid):

 1. Issue the following steps on `contentTimeline`:

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `pipeline`.
 :::

 2. Return.

 No errors are generated from a device which is
 lost. See [§ 22 Errors & Debugging](#errors-and-debugging).

 2. If `pipeline` is
 [invalid](#abstract-opdef-invalid) and `error` is an [internal
 error](#abstract-opdef-generate-an-internal-error), issue the following steps on
 `contentTimeline`, and return.

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with a
 [`GPUPipelineError`](#gpupipelineerror) with
 [`reason`](#dom-gpupipelineerrorinit-reason)
 [`"internal"`](#dom-gpupipelineerrorreason-internal).
 :::

 3. If `pipeline` is
 [invalid](#abstract-opdef-invalid) and `error` is a [validation
 error](#abstract-opdef-generate-a-validation-error), issue the following steps on
 `contentTimeline`, and return.

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with a
 [`GPUPipelineError`](#gpupipelineerror) with
 [`reason`](#dom-gpupipelineerrorinit-reason)
 [`"validation"`](#dom-gpupipelineerrorreason-validation).
 :::
 :::
 ::::::

Creating a simple
[`GPUComputePipeline`](#gpucomputepipeline):

``` highlight
const computePipeline = gpuDevice.createComputePipeline({
 layout: pipelineLayout,
 compute: {
 module: computeShaderModule,
 entryPoint: 'computeMain',
 }
});
```

### 10.3. `GPURenderPipeline`

A
[`GPURenderPipeline`](#gpurenderpipeline) is a kind of [pipeline](#pipeline) that controls the vertex and fragment shader stages,
and can be used in
[`GPURenderPassEncoder`](#gpurenderpassencoder) as well as
[`GPURenderBundleEncoder`](#gpurenderbundleencoder).

Render [pipeline](#pipeline) inputs
are:

- bindings, according to the given
 [`GPUPipelineLayout`](#gpupipelinelayout)

- vertex and index buffers, described by
 [`GPUVertexState`](#dictdef-gpuvertexstate)

- the color attachments, described by
 [`GPUColorTargetState`](#dictdef-gpucolortargetstate)

- optionally, the depth-stencil attachment, described by
 [`GPUDepthStencilState`](#dictdef-gpudepthstencilstate)

Render [pipeline](#pipeline)
outputs are:

- [`buffer`](#dom-gpubindgrouplayoutentry-buffer) bindings with a
 [`type`](#dom-gpubufferbindinglayout-type) of
 [`"storage"`](#dom-gpubufferbindingtype-storage)

- [`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) bindings with a
 [`access`](#dom-gpustoragetexturebindinglayout-access) of
 [`"write-only"`](#dom-gpustoragetextureaccess-write-only) or
 [`"read-write"`](#dom-gpustoragetextureaccess-read-write)

- the color attachments, described by
 [`GPUColorTargetState`](#dictdef-gpucolortargetstate)

- optionally, depth-stencil attachment, described by
 [`GPUDepthStencilState`](#dictdef-gpudepthstencilstate)

A render [pipeline](#pipeline) is
comprised of the following [render stages]:

1. Vertex fetch, controlled by
 [`GPUVertexState.buffers`](#dom-gpuvertexstate-buffers)

2. Vertex shader, controlled by
 [`GPUVertexState`](#dictdef-gpuvertexstate)

3. Primitive assembly, controlled by
 [`GPUPrimitiveState`](#dictdef-gpuprimitivestate)

4. Rasterization, controlled by
 [`GPUPrimitiveState`](#dictdef-gpuprimitivestate),
 [`GPUDepthStencilState`](#dictdef-gpudepthstencilstate), and
 [`GPUMultisampleState`](#dictdef-gpumultisamplestate)

5. Fragment shader, controlled by
 [`GPUFragmentState`](#dictdef-gpufragmentstate)

6. Stencil test and operation, controlled by
 [`GPUDepthStencilState`](#dictdef-gpudepthstencilstate)

7. Depth test and write, controlled by
 [`GPUDepthStencilState`](#dictdef-gpudepthstencilstate)

8. Output merging, controlled by
 [`GPUFragmentState.targets`](#dom-gpufragmentstate-targets)

```
[Exposed=(Window, Worker), SecureContext]
interface GPURenderPipeline ;
GPURenderPipeline includes GPUObjectBase;
GPURenderPipeline includes GPUPipelineBase;
```

[`GPURenderPipeline`](#gpurenderpipeline) has the following [device timeline
properties](#device-timeline-property):

[`[[descriptor]]`], of type [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor), readonly

: The
 [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) describing this pipeline.

 All optional fields of
 [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) are defined.

[`[[writesDepth]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: True if the pipeline writes to the depth component of the
 depth/stencil attachment

[`[[writesStencil]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: True if the pipeline writes to the stencil component of the
 depth/stencil attachment

#### 10.3.1. Render Pipeline Creation

A
[`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) describes a render
[pipeline](#pipeline) by
configuring each of the [render
stages](#render-stages). See
[§ 23.2 Rendering](#rendering-operations) for additional details.

```
dictionary GPURenderPipelineDescriptor
 : GPUPipelineDescriptorBase {
 required GPUVertexState vertex;
 GPUPrimitiveState primitive = ;
 GPUDepthStencilState depthStencil;
 GPUMultisampleState multisample = ;
 GPUFragmentState fragment;
};
```

[`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) has the following members:

[`vertex`], of type [GPUVertexState](#dictdef-gpuvertexstate)

: Describes the vertex shader entry point of the
 [pipeline](#pipeline) and its
 input buffer layouts.

[`primitive`], of type [GPUPrimitiveState](#dictdef-gpuprimitivestate), defaulting to ``

: Describes the primitive-related properties of the
 [pipeline](#pipeline).

[`depthStencil`], of type [GPUDepthStencilState](#dictdef-gpudepthstencilstate)

: Describes the optional depth-stencil properties, including the
 testing, operations, and bias.

[`multisample`], of type [GPUMultisampleState](#dictdef-gpumultisamplestate), defaulting to ``

: Describes the multi-sampling properties of the
 [pipeline](#pipeline).

[`fragment`], of type [GPUFragmentState](#dictdef-gpufragmentstate)

: Describes the fragment shader entry point of the
 [pipeline](#pipeline) and its
 output colors. If not
 [provided](https://infra.spec.whatwg.org/#map-exists), the [§ 23.2.8 No Color Output](#no-color-output)
 mode is enabled.

<!-- -->

[`createRenderPipeline(descriptor)`]

: Creates a
 [`GPURenderPipeline`](#gpurenderpipeline) using [immediate pipeline
 creation](#immediate-pipeline-creation).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createRenderPipeline(descriptor)](#dom-gpudevice-createrenderpipeline) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor)
 [✘]
 [✘]
 Description of the
 [`GPURenderPipeline`](#gpurenderpipeline) to create.
 **Returns:**
 [`GPURenderPipeline`](#gpurenderpipeline)

 [Content timeline](#content-timeline) steps:

 1. If
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) non-`null` `colorState` of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets):

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate
 texture format required
 features](#abstract-opdef-validate-texture-format-required-features) of
 `colorState`.[`format`](#dom-gpucolortargetstate-format) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 2. If
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture
 format required
 features](#abstract-opdef-validate-texture-format-required-features) of
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).[`format`](#dom-gpudepthstencilstate-format) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 3. Let `pipeline` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPURenderPipeline`](#gpurenderpipeline), `descriptor`).

 4. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 5. Return `pipeline`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `layout` be a new [default pipeline
 layout](#abstract-opdef-default-pipeline-layout) for `pipeline` if
 `descriptor`.[`layout`](#dom-gpupipelinedescriptorbase-layout) is
 [`"auto"`](#dom-gpuautolayoutmode-auto), and
 `descriptor`.[`layout`](#dom-gpupipelinedescriptorbase-layout) otherwise.

 2. All of the requirements in the following steps `must`
 be met. If any are unmet, [generate a validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `pipeline`, and return.

 ::: validusage
 1. `layout` `must` be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 2. [validating
 GPURenderPipelineDescriptor](#abstract-opdef-validating-gpurenderpipelinedescriptor)(`descriptor`,
 `layout`, `this`) must succeed.

 3. Let `vertexBufferCount` be the index of the last
 non-null entry in
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex).[`buffers`](#dom-gpuvertexstate-buffers), plus 1; or 0 if there are none.

 4. `layout`.[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot).[size](https://infra.spec.whatwg.org/#list-size) + `vertexBufferCount` must be ≤
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxBindGroupsPlusVertexBuffers`](#dom-supported-limits-maxbindgroupsplusvertexbuffers).
 :::

 3. If any
 [pipeline-creation](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-creation-error) [uncategorized
 errors](https://gpuweb.github.io/gpuweb/wgsl/#uncategorized-error) result from the implementation of pipeline
 creation, [generate an internal
 error](#abstract-opdef-generate-an-internal-error),
 [invalidate](#abstract-opdef-invalidate) `pipeline` and return.

 Even if the implementation detected
 [uncategorized
 errors](https://gpuweb.github.io/gpuweb/wgsl/#uncategorized-error) in shader module creation, the error is
 surfaced here.

 4. Set
 `pipeline`.[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot) to `descriptor`.

 5. Set
 `pipeline`.[`[[writesDepth]]`](#dom-gpurenderpipeline-writesdepth-slot) to false.

 6. Set
 `pipeline`.[`[[writesStencil]]`](#dom-gpurenderpipeline-writesstencil-slot) to false.

 7. Let `depthStencil` be
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).

 8. If `depthStencil` is not null:

 1. If
 `depthStencil`.[`depthWriteEnabled`](#dom-gpudepthstencilstate-depthwriteenabled) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Set
 `pipeline`.[`[[writesDepth]]`](#dom-gpurenderpipeline-writesdepth-slot) to
 `depthStencil`.[`depthWriteEnabled`](#dom-gpudepthstencilstate-depthwriteenabled).

 2. If
 `depthStencil`.[`stencilWriteMask`](#dom-gpudepthstencilstate-stencilwritemask) is not 0:

 1. Let `stencilFront` be
 `depthStencil`.[`stencilFront`](#dom-gpudepthstencilstate-stencilfront).

 2. Let `stencilBack` be
 `depthStencil`.[`stencilBack`](#dom-gpudepthstencilstate-stencilback).

 3. Let `cullMode` be
 `descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`cullMode`](#dom-gpuprimitivestate-cullmode).

 4. If `cullMode` is not
 [`"front"`](#dom-gpucullmode-front), and any of
 `stencilFront`.[`passOp`](#dom-gpustencilfacestate-passop),
 `stencilFront`.[`depthFailOp`](#dom-gpustencilfacestate-depthfailop), or
 `stencilFront`.[`failOp`](#dom-gpustencilfacestate-failop) is not
 [`"keep"`](#dom-gpustenciloperation-keep):

 1. Set
 `pipeline`.[`[[writesStencil]]`](#dom-gpurenderpipeline-writesstencil-slot) to true.

 5. If `cullMode` is not
 [`"back"`](#dom-gpucullmode-back), and any of
 `stencilBack`.[`passOp`](#dom-gpustencilfacestate-passop),
 `stencilBack`.[`depthFailOp`](#dom-gpustencilfacestate-depthfailop), or
 `stencilBack`.[`failOp`](#dom-gpustencilfacestate-failop) is not
 [`"keep"`](#dom-gpustenciloperation-keep):

 1. Set
 `pipeline`.[`[[writesStencil]]`](#dom-gpurenderpipeline-writesstencil-slot) to true.

 9. Set
 `pipeline`.[`[[layout]]`](#dom-gpupipelinebase-layout-slot) to `layout`.
 :::
 :::::

[`createRenderPipelineAsync(descriptor)`]

: Creates a
 [`GPURenderPipeline`](#gpurenderpipeline) using [async pipeline
 creation](#async-pipeline-creation). The returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) resolves when the created pipeline is ready to be
 used without additional delay.

 If pipeline creation fails, the returned
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) rejects with an
 [`GPUPipelineError`](#gpupipelineerror). (A
 [`GPUError`](#gpuerror) is
 not dispatched to the device.)

 Use of this method is preferred whenever possible,
 as it prevents blocking the [queue
 timeline](#queue-timeline) work on pipeline compilation.

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createRenderPipelineAsync(descriptor)](#dom-gpudevice-createrenderpipelineasync) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor)
 [✘]
 [✘]
 Description of the
 [`GPURenderPipeline`](#gpurenderpipeline) to create.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`GPURenderPipeline`](#gpurenderpipeline)\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. Let `pipeline` be a new
 [`GPURenderPipeline`](#gpurenderpipeline) created as if
 `this`.[`createRenderPipeline()`](#dom-gpudevice-createrenderpipeline) was called with `descriptor`, except
 capturing any errors as `error`, rather than
 dispatching them to the device.

 2. Let `event` occur upon the (successful or
 unsuccessful) completion of [pipeline
 creation](https://gpuweb.github.io/gpuweb/wgsl/#pipeline-creation) for `pipeline`.

 3. [Listen for timeline
 event](#abstract-opdef-listen-for-timeline-event) `event` on
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot), handled by the subsequent steps on the [device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. If `pipeline` is
 [valid](#abstract-opdef-valid) or `this` is
 [lost](#abstract-opdef-invalid):

 1. Issue the following steps on `contentTimeline`:

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with
 `pipeline`.
 :::

 2. Return.

 No errors are generated from a device which is
 lost. See [§ 22 Errors & Debugging](#errors-and-debugging).

 2. If `pipeline` is
 [invalid](#abstract-opdef-invalid) and `error` is an [internal
 error](#abstract-opdef-generate-an-internal-error), issue the following steps on
 `contentTimeline`, and return.

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with a
 [`GPUPipelineError`](#gpupipelineerror) with
 [`reason`](#dom-gpupipelineerrorinit-reason)
 [`"internal"`](#dom-gpupipelineerrorreason-internal).
 :::

 3. If `pipeline` is
 [invalid](#abstract-opdef-invalid) and `error` is a [validation
 error](#abstract-opdef-generate-a-validation-error), issue the following steps on
 `contentTimeline`, and return.

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with a
 [`GPUPipelineError`](#gpupipelineerror) with
 [`reason`](#dom-gpupipelineerrorinit-reason)
 [`"validation"`](#dom-gpupipelineerrorreason-validation).
 :::
 :::
 ::::::

[validating
GPURenderPipelineDescriptor](descriptor, layout,
device)

**Arguments:**

- [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) `descriptor`

- [`GPUPipelineLayout`](#gpupipelinelayout) `layout`

- [`GPUDevice`](#gpudevice)
 `device`

[Device timeline](#device-timeline) steps:

1. Return `true` if all of the following conditions are satisfied:

 ::: validusage
 - [validating
 GPUVertexState](#abstract-opdef-validating-gpuvertexstate)(`device`,
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex), `layout`) succeeds.

 - If
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - [validating
 GPUFragmentState](#abstract-opdef-validating-gpufragmentstate)(`device`,
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment), `layout`) succeeds.

 - If the
 [sample_mask](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-sample_mask) builtin is a [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment):

 - `descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`alphaToCoverageEnabled`](#dom-gpumultisamplestate-alphatocoverageenabled) is `false`.

 - If the
 [frag_depth](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-frag_depth) builtin is a [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment):

 - `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil) must be
 [provided](https://infra.spec.whatwg.org/#map-exists), and
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).[`format`](#dom-gpudepthstencilstate-format) must have a
 [depth](#aspect-depth)
 aspect.

 - ::: compatmode
 If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - The
 [sample_mask](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-sample_mask) builtin must not be a [shader stage
 input](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-input) or [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).

 - The
 [sample_index](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-sample_index) builtin must not be a [shader stage
 input](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-input) of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).
 :::

 - [validating
 GPUPrimitiveState](#abstract-opdef-validating-gpuprimitivestate)(`descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive), `device`) succeeds.

 - If
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - [validating
 GPUDepthStencilState](#abstract-opdef-validating-gpudepthstencilstate)(`device`,
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil),
 `descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`topology`](#dom-gpuprimitivestate-topology)) succeeds.

 - [validating
 GPUMultisampleState](#abstract-opdef-validating-gpumultisamplestate)(`descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample)) succeeds.

 - If
 `descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`alphaToCoverageEnabled`](#dom-gpumultisamplestate-alphatocoverageenabled) is true:

 1. `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) must be
 [provided](https://infra.spec.whatwg.org/#map-exists).

 2. `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets)\[0\] must
 [exist](https://infra.spec.whatwg.org/#list-contain) and be non-null.

 3. `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets)\[0\].[`format`](#dom-gpucolortargetstate-format) must be a
 [`GPUTextureFormat`](#enumdef-gputextureformat) which is
 [blendable](#blendable)
 and has an alpha channel.

 - There must exist at least one attachment, either:

 - A non-`null` value in
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets), or

 - A
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).

 - [validating inter-stage
 interfaces](#abstract-opdef-validating-inter-stage-interfaces)(`device`,
 `descriptor`) returns `true`.
 :::

[validating Compatibility Mode shader
binding](`variable`)

**Arguments:**

- shader binding declaration `variable`, a module-scope
 variable declaration reflected from a shader module

**Returns:**
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

[Device timeline](#device-timeline) steps:

1. If the
 [interpolation](https://gpuweb.github.io/gpuweb/wgsl/#interpolation) of the `variable` is
 [linear](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-type-linear), return `false`.

2. If the
 [interpolation](https://gpuweb.github.io/gpuweb/wgsl/#interpolation) of the `variable` is
 [flat](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-type-flat) and the [interpolation
 sampling](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-sampling) is not
 [either](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-sampling-either), return `false`.

3. If the [interpolation
 sampling](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-sampling) of the `variable` is
 [sample](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-sampling-sample), return `false`.

4. Return \'true\'

[validating inter-stage
interfaces](`device`,
`descriptor`)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) `descriptor`

**Returns:**
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

[Device timeline](#device-timeline) steps:

1. Let `maxVertexShaderOutputVariables` be
 `device`.limits.[`maxInterStageShaderVariables`](#dom-supported-limits-maxinterstageshadervariables).

2. Let `maxVertexShaderOutputLocation` be
 `device`.limits.[`maxInterStageShaderVariables`](#dom-supported-limits-maxinterstageshadervariables) - 1.

3. If
 `descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`topology`](#dom-gpuprimitivestate-topology) is
 [`"point-list"`](#dom-gpuprimitivetopology-point-list):

 1. Decrement `maxVertexShaderOutputVariables` by 1.

4. If
 [clip_distances](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-clip_distances) is declared in the output of
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex):

 1. Let `clipDistancesSize` be the array size of
 [clip_distances](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-clip_distances).

 2. Decrement `maxVertexShaderOutputVariables` by
 ceil(`clipDistancesSize` / 4).

 3. Decrement `maxVertexShaderOutputLocation` by
 ceil(`clipDistancesSize` / 4).

5. Return `false` if any of the following requirements are unmet:

 - There must be no more than
 `maxVertexShaderOutputVariables` user-defined outputs
 for
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex).

 - The
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) of each user-defined output of
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex) must be ≤
 `maxVertexShaderOutputLocation`.

6. If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):

 ::: compatmode
 1. For each user-defined `output` of
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex):

 1. If [validating Compatibility Mode shader
 binding](#abstract-opdef-validating-compatibility-mode-shader-binding)(`output`) fails, return
 `false`.
 :::

7. If
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) [is
 provided](https://infra.spec.whatwg.org/#map-exists):

 1. Let `maxFragmentShaderInputVariables` be
 `device`.limits.[`maxInterStageShaderVariables`](#dom-supported-limits-maxinterstageshadervariables).

 2. For each of the [Inter-Stage
 Builtins](#inter-stage-builtins) that are an input of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment):

 1. Decrement `maxFragmentShaderInputVariables` by 1.

 3. Return `false` if any of the following requirements are unmet:

 - For each user-defined input of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) there must be a user-defined output of
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex) that
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations), type, and
 [interpolation](https://gpuweb.github.io/gpuweb/wgsl/#interpolation) of the input.

 Vertex-only pipelines **can** have
 user-defined outputs in the vertex stage; their values will be
 discarded.

 - There must be no more than
 `maxFragmentShaderInputVariables` user-defined
 inputs for
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).

 4. [Assert](https://infra.spec.whatwg.org/#assert) that the
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) of each user-defined input of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) is less than
 `device`.limits.[`maxInterStageShaderVariables`](#dom-supported-limits-maxinterstageshadervariables). (This follows from the above rules.)

 5. If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):

 ::: compatmode
 1. For each user-defined `input` of
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment):

 1. If [validating Compatibility Mode shader
 binding](#abstract-opdef-validating-compatibility-mode-shader-binding)(`input`) fails,
 return `false`.
 :::

8. Return `true`.

The following
[builtins](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) are [Inter-Stage Builtins], and count towards the
[`maxInterStageShaderVariables`](#dom-supported-limits-maxinterstageshadervariables) limit when used in a fragment shader:

- `front_facing`

- `sample_index`

- `sample_mask`

- `primitive_index`

- `subgroup_invocation_id`

- `subgroup_size`

Creating a simple
[`GPURenderPipeline`](#gpurenderpipeline):

``` highlight
const renderPipeline = gpuDevice.createRenderPipeline({
 layout: pipelineLayout,
 vertex: {
 module: shaderModule,
 entryPoint: 'vertexMain'
 },
 fragment: {
 module: shaderModule,
 entryPoint: 'fragmentMain',
 targets: [{
 format: 'bgra8unorm',
 }],
 }
});
```

#### 10.3.2. Primitive State

```
dictionary GPUPrimitiveState {
 GPUPrimitiveTopology topology = "triangle-list";
 GPUIndexFormat stripIndexFormat;
 GPUFrontFace frontFace = "ccw";
 GPUCullMode cullMode = "none";

 // Requires "depth-clip-control" feature.
 boolean unclippedDepth = false;
};
```

[`GPUPrimitiveState`](#dictdef-gpuprimitivestate) has the following members, which describe how a
[`GPURenderPipeline`](#gpurenderpipeline) constructs and rasterizes primitives from its vertex
inputs:

[`topology`], of type [GPUPrimitiveTopology](#enumdef-gpuprimitivetopology), defaulting to `"triangle-list"`

: The type of primitive to be constructed from the vertex inputs.

[`stripIndexFormat`], of type [GPUIndexFormat](#enumdef-gpuindexformat)

: For pipelines with strip topologies
 ([`"line-strip"`](#dom-gpuprimitivetopology-line-strip) or
 [`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip)), this determines the index buffer format and
 primitive restart value
 ([`"uint16"`](#dom-gpuindexformat-uint16)/`0xFFFF` or
 [`"uint32"`](#dom-gpuindexformat-uint32)/`0xFFFFFFFF`). It is not allowed on pipelines with
 non-strip topologies.

 Some implementations require knowledge of the
 primitive restart value to compile pipeline state objects.

 To use a strip-topology pipeline with an indexed draw call
 ([`drawIndexed()`](#dom-gpurendercommandsmixin-drawindexed) or
 [`drawIndexedIndirect()`](#dom-gpurendercommandsmixin-drawindexedindirect)), this must be set, and it must match the index
 buffer format used with the draw call (set in
 [`setIndexBuffer()`](#dom-gpurendercommandsmixin-setindexbuffer)).

 See [§ 23.2.3 Primitive Assembly](#primitive-assembly) for
 additional details.

[`frontFace`], of type [GPUFrontFace](#enumdef-gpufrontface), defaulting to `"ccw"`

: Defines which polygons are considered
 [front-facing](#front-facing).

[`cullMode`], of type [GPUCullMode](#enumdef-gpucullmode), defaulting to `"none"`

: Defines which polygon orientation will be culled, if any.

[`unclippedDepth`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: If true, indicates that [depth
 clipping](#depth-clipping)
 is disabled.

 Requires the
 [`"depth-clip-control"`](#depth-clip-control) feature to be enabled.

[validating
GPUPrimitiveState](`descriptor`,
`device`) **Arguments:**

- [`GPUPrimitiveState`](#dictdef-gpuprimitivestate) `descriptor`

- [`GPUDevice`](#gpudevice)
 `device`

[Device timeline](#device-timeline) steps:

1. Return `true` if all of the following conditions are satisfied:

 ::: validusage
 - If
 `descriptor`.[`topology`](#dom-gpuprimitivestate-topology) is not
 [`"line-strip"`](#dom-gpuprimitivetopology-line-strip) or
 [`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip):

 - `descriptor`.[`stripIndexFormat`](#dom-gpuprimitivestate-stripindexformat) must not be
 [provided](https://infra.spec.whatwg.org/#map-exists).

 - If
 `descriptor`.[`unclippedDepth`](#dom-gpuprimitivestate-unclippeddepth) is `true`:

 - [`"depth-clip-control"`](#depth-clip-control) must be [enabled
 for](#enabled-for)
 `device`.
 :::

```
enum GPUPrimitiveTopology {
 "point-list",
 "line-list",
 "line-strip",
 "triangle-list",
 "triangle-strip",
};
```

[`GPUPrimitiveTopology`](#enumdef-gpuprimitivetopology) defines the primitive type draw calls made with a
[`GPURenderPipeline`](#gpurenderpipeline) will use. See [§ 23.2.5 Rasterization](#rasterization)
for additional details:

[`"point-list"`]

: Each vertex defines a point primitive.

[`"line-list"`]

: Each consecutive pair of two vertices defines a line primitive.

[`"line-strip"`]

: Each vertex after the first defines a line primitive between it and
 the previous vertex.

[`"triangle-list"`]

: Each consecutive triplet of three vertices defines a triangle
 primitive.

[`"triangle-strip"`]

: Each vertex after the first two defines a triangle primitive between
 it and the previous two vertices.

```
enum GPUFrontFace {
 "ccw",
 "cw",
};
```

[`GPUFrontFace`](#enumdef-gpufrontface) defines which polygons are considered
[front-facing](#front-facing) by
a
[`GPURenderPipeline`](#gpurenderpipeline). See [§ 23.2.5.4 Polygon
Rasterization](#polygon-rasterization) for additional details:

[`"ccw"`]

: Polygons with vertices whose framebuffer coordinates are given in
 counter-clockwise order are considered
 [front-facing](#front-facing).

[`"cw"`]

: Polygons with vertices whose framebuffer coordinates are given in
 clockwise order are considered
 [front-facing](#front-facing).

```
enum GPUCullMode {
 "none",
 "front",
 "back",
};
```

[`GPUPrimitiveTopology`](#enumdef-gpuprimitivetopology) defines which polygons will be culled by draw calls
made with a
[`GPURenderPipeline`](#gpurenderpipeline). See [§ 23.2.5.4 Polygon
Rasterization](#polygon-rasterization) for additional details:

[`"none"`]

: No polygons are discarded.

[`"front"`]

: [Front-facing](#front-facing) polygons are discarded.

[`"back"`]

: [Back-facing](#back-facing)
 polygons are discarded.

[`GPUFrontFace`](#enumdef-gpufrontface) and
[`GPUCullMode`](#enumdef-gpucullmode) have no effect on
[`"point-list"`](#dom-gpuprimitivetopology-point-list),
[`"line-list"`](#dom-gpuprimitivetopology-line-list), or
[`"line-strip"`](#dom-gpuprimitivetopology-line-strip) topologies.

#### 10.3.3. Multisample State

```
dictionary GPUMultisampleState {
 GPUSize32 count = 1;
 GPUSampleMask mask = 0xFFFFFFFF;
 boolean alphaToCoverageEnabled = false;
};
```

[`GPUMultisampleState`](#dictdef-gpumultisamplestate) has the following members, which describe how a
[`GPURenderPipeline`](#gpurenderpipeline) interacts with a render pass's multisampled
attachments.

[`count`], of type [GPUSize32](#typedefdef-gpusize32), defaulting to `1`

: Number of samples per pixel. This
 [`GPURenderPipeline`](#gpurenderpipeline) will be compatible only with attachment textures
 ([`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments) and
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment)) with matching
 [`sampleCount`](#dom-gputexturedescriptor-samplecount)s.

[`mask`], of type [GPUSampleMask](#typedefdef-gpusamplemask), defaulting to `0xFFFFFFFF`

: Mask determining which samples are written to.

[`alphaToCoverageEnabled`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: When `true` indicates that a fragment's alpha channel should be used
 to generate a sample coverage mask.

[validating
GPUMultisampleState](`descriptor`)
**Arguments:**

- [`GPUMultisampleState`](#dictdef-gpumultisamplestate) `descriptor`

[Device timeline](#device-timeline) steps:

1. Return `true` if all of the following conditions are satisfied:

 ::: validusage
 - `descriptor`.[`count`](#dom-gpumultisamplestate-count) must be either 1 or 4.

 - If
 `descriptor`.[`alphaToCoverageEnabled`](#dom-gpumultisamplestate-alphatocoverageenabled) is `true`:

 - `descriptor`.[`count`](#dom-gpumultisamplestate-count) \> 1.
 :::

#### 10.3.4. Fragment State

```
dictionary GPUFragmentState
 : GPUProgrammableStage {
 required sequence<GPUColorTargetState?> targets;
};
```

[`targets`], of type `sequence<GPUColorTargetState?>`

: A list of
 [`GPUColorTargetState`](#dictdef-gpucolortargetstate) defining the formats and behaviors of the color
 targets this pipeline writes to.

[validating
GPUFragmentState](`device`,
`descriptor`, `layout`)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [`GPUFragmentState`](#dictdef-gpufragmentstate) `descriptor`

- [`GPUPipelineLayout`](#gpupipelinelayout) `layout`

[Device timeline](#device-timeline) steps:

1. Return `true` if all of the following requirements are met:

 ::: validusage
 - [validating
 GPUProgrammableStage](#abstract-opdef-validating-gpuprogrammablestage)([`FRAGMENT`](#dom-gpushaderstage-fragment), `descriptor`, `layout`,
 `device`) succeeds.

 - `descriptor`.[`targets`](#dom-gpufragmentstate-targets).[size](https://infra.spec.whatwg.org/#list-size) must be ≤
 `device`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachments`](#dom-supported-limits-maxcolorattachments).

 - For each [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) `output`:

 - `output`'s
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) must be \<
 `device`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachments`](#dom-supported-limits-maxcolorattachments).

 - Let `entryPoint` be [get the entry
 point](#abstract-opdef-get-the-entry-point)([`FRAGMENT`](#dom-gpushaderstage-fragment), `descriptor`).

 - Let `usesDualSourceBlending` be `false`.

 - [For
 each](https://infra.spec.whatwg.org/#list-iterate) `index` of the
 [indices](https://infra.spec.whatwg.org/#list-get-the-indices) of
 `descriptor`.[`targets`](#dom-gpufragmentstate-targets) containing a non-`null` value
 `colorState`:

 - `colorState`.[`format`](#dom-gpucolortargetstate-format) must be listed in [§ 26.1.1 Plain color
 formats](#plain-color-formats) with
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) capability.

 - `colorState`.[`writeMask`](#dom-gpucolortargetstate-writemask) must be \< 16.

 - If
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - The
 `colorState`.[`format`](#dom-gpucolortargetstate-format) must be
 [blendable](#blendable).

 - `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`color`](#dom-gpublendstate-color) must be a [valid
 GPUBlendComponent](#valid-gpublendcomponent).

 - `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`alpha`](#dom-gpublendstate-alpha) must be a [valid
 GPUBlendComponent](#valid-gpublendcomponent).

 - If
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`color`](#dom-gpublendstate-color).[`srcFactor`](#dom-gpublendcomponent-srcfactor) or
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`color`](#dom-gpublendstate-color).[`dstFactor`](#dom-gpublendcomponent-dstfactor) or
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`alpha`](#dom-gpublendstate-alpha).[`srcFactor`](#dom-gpublendcomponent-srcfactor) or
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`alpha`](#dom-gpublendstate-alpha).[`dstFactor`](#dom-gpublendcomponent-dstfactor) uses the second input of the corresponding
 blending unit (is any of
 [`"src1"`](#dom-gpublendfactor-src1),
 [`"one-minus-src1"`](#dom-gpublendfactor-one-minus-src1),
 [`"src1-alpha"`](#dom-gpublendfactor-src1-alpha),
 [`"one-minus-src1-alpha"`](#dom-gpublendfactor-one-minus-src1-alpha)), then:

 - Set `usesDualSourceBlending` to `true`.

 - For each [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) value `output` with
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) attribute equal to `index` in
 `entryPoint`:

 - For each component in
 `colorState`.[`format`](#dom-gpucolortargetstate-format), there must be a corresponding component in
 `output`. (That is, RGBA requires vec4, RGB
 requires vec3 or vec4, RG requires vec2 or vec3 or vec4.)

 - If the
 [`GPUTextureSampleType`](#enumdef-gputexturesampletype)s for
 `colorState`.[`format`](#dom-gpucolortargetstate-format) (defined in [§ 26.1 Texture Format
 Capabilities](#texture-format-caps)) are:

 [`"float"`](#dom-gputexturesampletype-float) and/or [`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

 : `output` must have a floating-point scalar
 type.

 [`"sint"`](#dom-gputexturesampletype-sint)

 : `output` must have a signed integer scalar
 type.

 [`"uint"`](#dom-gputexturesampletype-uint)

 : `output` must have an unsigned integer scalar
 type.

 - If
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend) is
 [provided](https://infra.spec.whatwg.org/#map-exists) and
 `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`color`](#dom-gpublendstate-color).[`srcFactor`](#dom-gpublendcomponent-srcfactor) or
 .[`dstFactor`](#dom-gpublendcomponent-dstfactor) uses the source alpha (is any of
 [`"src-alpha"`](#dom-gpublendfactor-src-alpha),
 [`"one-minus-src-alpha"`](#dom-gpublendfactor-one-minus-src-alpha),
 [`"src-alpha-saturated"`](#dom-gpublendfactor-src-alpha-saturated),
 [`"src1-alpha"`](#dom-gpublendfactor-src1-alpha) or
 [`"one-minus-src1-alpha"`](#dom-gpublendfactor-one-minus-src1-alpha)), then:

 - `output` must have an alpha channel (that is, it
 must be a vec4).

 - If
 `colorState`.[`writeMask`](#dom-gpucolortargetstate-writemask) is not 0:

 - `entryPoint` must have a [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) with
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) equal to `index` and
 [blend_src](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) omitted or equal to 0.

 - If `usesDualSourceBlending` is `true`:

 - `descriptor`.[`targets`](#dom-gpufragmentstate-targets).[size](https://infra.spec.whatwg.org/#list-size) must be 1.

 - All the [shader stage
 outputs](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) with
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) in `entryPoint` must be in one
 struct and [use dual source
 blending](https://gpuweb.github.io/gpuweb/wgsl/#use-dual-source-blending).

 - [Validating GPUFragmentState's color attachment bytes per
 sample](#abstract-opdef-validating-gpufragmentstates-color-attachment-bytes-per-sample)(`device`,
 `descriptor`.[`targets`](#dom-gpufragmentstate-targets)) succeeds.

 - ::: compatmode
 If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - All non-null
 [`GPUColorTargetState`](#dictdef-gpucolortargetstate)s `colorState` in
 `descriptor`.[`targets`](#dom-gpufragmentstate-targets) must have equal values for each of the
 following members:

 - `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`color`](#dom-gpublendstate-color)

 - `colorState`.[`blend`](#dom-gpucolortargetstate-blend).[`alpha`](#dom-gpublendstate-alpha)

 - `colorState`.[`writeMask`](#dom-gpucolortargetstate-writemask)

 - For each `function` in the [functions in the shader
 stage](https://gpuweb.github.io/gpuweb/wgsl/#functions-in-a-shader-stage) rooted at `entryPoint`:

 - `function` must not be
 [dpdxFine](https://gpuweb.github.io/gpuweb/wgsl/#dpdxFine-builtin),
 [dpdyFine](https://gpuweb.github.io/gpuweb/wgsl/#dpdyFine-builtin),
 or
 [fwidthFine](https://gpuweb.github.io/gpuweb/wgsl/#fwidthFine-builtin).
 :::
 :::

[Validating GPUFragmentState's color attachment bytes per
sample](`device`,
`targets`)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPUColorTargetState`](#dictdef-gpucolortargetstate)?\> `targets`

[Device timeline](#device-timeline) steps:

1. Let `formats` be an empty
 [list](https://infra.spec.whatwg.org/#list)\<[`GPUTextureFormat`](#enumdef-gputextureformat)?\>

2. For each `target` in `targets`:

 1. If `target` is `undefined`, continue.

 2. [Append](https://infra.spec.whatwg.org/#list-append)
 `target`.[`format`](#dom-gpucolortargetstate-format) to `formats`.

3. [Calculating color attachment bytes per
 sample](#abstract-opdef-calculating-color-attachment-bytes-per-sample)(`formats`) must be ≤
 `device`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachmentBytesPerSample`](#dom-supported-limits-maxcolorattachmentbytespersample).

 The fragment shader may output more values than what
the pipeline uses. If that is the case the values are ignored.

[`GPUBlendComponent`](#dictdef-gpublendcomponent) `component` is a [valid
GPUBlendComponent] with logical
[device](#device) `device`
if it meets\
the following requirements:

- If
 `component`.[`operation`](#dom-gpublendcomponent-operation) is
 [`"min"`](#dom-gpublendoperation-min) or
 [`"max"`](#dom-gpublendoperation-max):

 - `component`.[`srcFactor`](#dom-gpublendcomponent-srcfactor) and
 `component`.[`dstFactor`](#dom-gpublendcomponent-dstfactor) must both be
 [`"one"`](#dom-gpublendfactor-one).

- If
 `component`.[`srcFactor`](#dom-gpublendcomponent-srcfactor) or
 `component`.[`dstFactor`](#dom-gpublendcomponent-dstfactor) requires a feature according to the
 [`GPUBlendFactor`](#enumdef-gpublendfactor) table and
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain) the feature:

 - Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

#### 10.3.5. Color Target State

```
dictionary GPUColorTargetState {
 required GPUTextureFormat format;

 GPUBlendState blend;
 GPUColorWriteFlags writeMask = 0xF; // GPUColorWrite.ALL
};
```

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The
 [`GPUTextureFormat`](#enumdef-gputextureformat) of this color target. The pipeline will only be
 compatible with
 [`GPURenderPassEncoder`](#gpurenderpassencoder)s which use a
 [`GPUTextureView`](#gputextureview) of this format in the corresponding color
 attachment.

[`blend`], of type [GPUBlendState](#dictdef-gpublendstate)

: The blending behavior for this color target. If left undefined,
 disables blending for this color target.

[`writeMask`], of type [GPUColorWriteFlags](#typedefdef-gpucolorwriteflags), defaulting to `0xF`

: Bitmask controlling which channels are are written to when drawing
 to this color target.

```
dictionary GPUBlendState {
 required GPUBlendComponent color;
 required GPUBlendComponent alpha;
};
```

[`color`], of type [GPUBlendComponent](#dictdef-gpublendcomponent)

: Defines the blending behavior of the corresponding render target for
 color channels.

[`alpha`], of type [GPUBlendComponent](#dictdef-gpublendcomponent)

: Defines the blending behavior of the corresponding render target for
 the alpha channel.

```
typedef [EnforceRange] unsigned long GPUColorWriteFlags;
[Exposed=(Window, Worker), SecureContext]
namespace GPUColorWrite {
 const GPUFlagsConstant RED = 0x1;
 const GPUFlagsConstant GREEN = 0x2;
 const GPUFlagsConstant BLUE = 0x4;
 const GPUFlagsConstant ALPHA = 0x8;
 const GPUFlagsConstant ALL = 0xF;
};
```

##### 10.3.5.1. Blend State

```
dictionary GPUBlendComponent {
 GPUBlendOperation operation = "add";
 GPUBlendFactor srcFactor = "one";
 GPUBlendFactor dstFactor = "zero";
};
```

[`GPUBlendComponent`](#dictdef-gpublendcomponent) has the following members, which describe how the color
or alpha components of a fragment are blended:

[`operation`], of type [GPUBlendOperation](#enumdef-gpublendoperation), defaulting to `"add"`

: Defines the
 [`GPUBlendOperation`](#enumdef-gpublendoperation) used to calculate the values written to the target
 attachment components.

[`srcFactor`], of type [GPUBlendFactor](#enumdef-gpublendfactor), defaulting to `"one"`

: Defines the
 [`GPUBlendFactor`](#enumdef-gpublendfactor) operation to be performed on values from the
 fragment shader.

[`dstFactor`], of type [GPUBlendFactor](#enumdef-gpublendfactor), defaulting to `"zero"`

: Defines the
 [`GPUBlendFactor`](#enumdef-gpublendfactor) operation to be performed on values from the target
 attachment.

The following tables use this notation to describe color components for
a given fragment location:

**`RGBA`~`src`~**

Color output by the fragment shader for the color attachment. If the
shader doesn't return an alpha channel, src-alpha blend factors cannot
be used.

**`RGBA`~`src1`~**

Color output by the fragment shader for the color attachment with
[\"@blend_src\"
attribute](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations)
equal to `1`. If the shader doesn't return an alpha channel, src1-alpha
blend factors cannot be used.

**`RGBA`~`dst`~**

Color currently in the color attachment. Missing green/blue/alpha
channels default to `0, 0, 1`, respectively.

**`RGBA`~`const`~**

The current
[`[[blendConstant]]`](#dom-renderstate-blendconstant-slot).

**`RGBA`~`srcFactor`~**

The source blend factor components, as defined by
[`srcFactor`](#dom-gpublendcomponent-srcfactor).

**`RGBA`~`dstFactor`~**

The destination blend factor components, as defined by
[`dstFactor`](#dom-gpublendcomponent-dstfactor).

```
enum GPUBlendFactor {
 "zero",
 "one",
 "src",
 "one-minus-src",
 "src-alpha",
 "one-minus-src-alpha",
 "dst",
 "one-minus-dst",
 "dst-alpha",
 "one-minus-dst-alpha",
 "src-alpha-saturated",
 "constant",
 "one-minus-constant",
 "src1",
 "one-minus-src1",
 "src1-alpha",
 "one-minus-src1-alpha",
};
```

[`GPUBlendFactor`](#enumdef-gpublendfactor) defines how either a source or destination blend
factors is calculated:

GPUBlendFactor

Blend factor RGBA components

[Feature](#feature)

[`"zero"`]

`(0, 0, 0, 0)`

[`"one"`]

`(1, 1, 1, 1)`

[`"src"`]

`(R`~`src`~`, G`~`src`~`, B`~`src`~`, A`~`src`~`)`

[`"one-minus-src"`]

`(1 - R`~`src`~`, 1 - G`~`src`~`, 1 - B`~`src`~`, 1 - A`~`src`~`)`

[`"src-alpha"`]

`(A`~`src`~`, A`~`src`~`, A`~`src`~`, A`~`src`~`)`

[`"one-minus-src-alpha"`]

`(1 - A`~`src`~`, 1 - A`~`src`~`, 1 - A`~`src`~`, 1 - A`~`src`~`)`

[`"dst"`]

`(R`~`dst`~`, G`~`dst`~`, B`~`dst`~`, A`~`dst`~`)`

[`"one-minus-dst"`]

`(1 - R`~`dst`~`, 1 - G`~`dst`~`, 1 - B`~`dst`~`, 1 - A`~`dst`~`)`

[`"dst-alpha"`]

`(A`~`dst`~`, A`~`dst`~`, A`~`dst`~`, A`~`dst`~`)`

[`"one-minus-dst-alpha"`]

`(1 - A`~`dst`~`, 1 - A`~`dst`~`, 1 - A`~`dst`~`, 1 - A`~`dst`~`)`

[`"src-alpha-saturated"`]

`(min(A`~`src`~`, 1 - A`~`dst`~`), min(A`~`src`~`, 1 - A`~`dst`~`), min(A`~`src`~`, 1 - A`~`dst`~`), 1)`

[`"constant"`]

`(R`~`const`~`, G`~`const`~`, B`~`const`~`, A`~`const`~`)`

[`"one-minus-constant"`]

`(1 - R`~`const`~`, 1 - G`~`const`~`, 1 - B`~`const`~`, 1 - A`~`const`~`)`

[`"src1"`]

`(R`~`src1`~`, G`~`src1`~`, B`~`src1`~`, A`~`src1`~`)`

[`dual-source-blending`](#dom-gpufeaturename-dual-source-blending)

[`"one-minus-src1"`]

`(1 - R`~`src1`~`, 1 - G`~`src1`~`, 1 - B`~`src1`~`, 1 - A`~`src1`~`)`

[`"src1-alpha"`]

`(A`~`src1`~`, A`~`src1`~`, A`~`src1`~`, A`~`src1`~`)`

[`"one-minus-src1-alpha"`]

`(1 - A`~`src1`~`, 1 - A`~`src1`~`, 1 - A`~`src1`~`, 1 - A`~`src1`~`)`

```
enum GPUBlendOperation {
 "add",
 "subtract",
 "reverse-subtract",
 "min",
 "max",
};
```

[`GPUBlendOperation`](#enumdef-gpublendoperation) defines the algorithm used to combine source and
destination blend factors:

GPUBlendOperation

RGBA Components

[`"add"`]

`RGBA`~`src`~` × RGBA`~`srcFactor`~` + RGBA`~`dst`~` × RGBA`~`dstFactor`~

[`"subtract"`]

`RGBA`~`src`~` × RGBA`~`srcFactor`~` - RGBA`~`dst`~` × RGBA`~`dstFactor`~

[`"reverse-subtract"`]

`RGBA`~`dst`~` × RGBA`~`dstFactor`~` - RGBA`~`src`~` × RGBA`~`srcFactor`~

[`"min"`]

`min(RGBA`~`src`~`, RGBA`~`dst`~`)`

[`"max"`]

`max(RGBA`~`src`~`, RGBA`~`dst`~`)`

#### 10.3.6. Depth/Stencil State

```
dictionary GPUDepthStencilState {
 required GPUTextureFormat format;

 boolean depthWriteEnabled;
 GPUCompareFunction depthCompare;

 GPUStencilFaceState stencilFront = ;
 GPUStencilFaceState stencilBack = ;

 GPUStencilValue stencilReadMask = 0xFFFFFFFF;
 GPUStencilValue stencilWriteMask = 0xFFFFFFFF;

 GPUDepthBias depthBias = 0;
 float depthBiasSlopeScale = 0;
 float depthBiasClamp = 0;
};
```

[`GPUDepthStencilState`](#dictdef-gpudepthstencilstate) has the following members, which describe how a
[`GPURenderPipeline`](#gpurenderpipeline) will affect a render pass's
[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment):

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The
 [`format`](#dom-gputextureviewdescriptor-format) of
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) this
 [`GPURenderPipeline`](#gpurenderpipeline) will be compatible with.

[`depthWriteEnabled`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: Indicates if this
 [`GPURenderPipeline`](#gpurenderpipeline) can modify
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) depth values.

[`depthCompare`], of type [GPUCompareFunction](#enumdef-gpucomparefunction)

: The comparison operation used to test fragment depths against
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) depth values.

[`stencilFront`], of type [GPUStencilFaceState](#dictdef-gpustencilfacestate), defaulting to ``

: Defines how stencil comparisons and operations are performed for
 front-facing primitives.

[`stencilBack`], of type [GPUStencilFaceState](#dictdef-gpustencilfacestate), defaulting to ``

: Defines how stencil comparisons and operations are performed for
 back-facing primitives.

[`stencilReadMask`], of type [GPUStencilValue](#typedefdef-gpustencilvalue), defaulting to `0xFFFFFFFF`

: Bitmask controlling which
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) stencil value bits are read when performing stencil
 comparison tests.

[`stencilWriteMask`], of type [GPUStencilValue](#typedefdef-gpustencilvalue), defaulting to `0xFFFFFFFF`

: Bitmask controlling which
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) stencil value bits are written to when performing
 stencil operations.

[`depthBias`], of type [GPUDepthBias](#typedefdef-gpudepthbias), defaulting to `0`

: Constant depth bias added to each triangle fragment. See [biased
 fragment
 depth](#abstract-opdef-biased-fragment-depth) for details.

[`depthBiasSlopeScale`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: Depth bias that scales with the triangle fragment's slope. See
 [biased fragment
 depth](#abstract-opdef-biased-fragment-depth) for details.

[`depthBiasClamp`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The maximum depth bias of a triangle fragment. See [biased fragment
 depth](#abstract-opdef-biased-fragment-depth) for details.

[`depthBias`](#dom-gpudepthstencilstate-depthbias),
[`depthBiasSlopeScale`](#dom-gpudepthstencilstate-depthbiasslopescale), and
[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp) have no effect on
[`"point-list"`](#dom-gpuprimitivetopology-point-list),
[`"line-list"`](#dom-gpuprimitivetopology-line-list), and
[`"line-strip"`](#dom-gpuprimitivetopology-line-strip) primitives, and must be 0.

The [biased fragment depth] for a fragment being
written to
[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) `attachment` when drawing using
[`GPUDepthStencilState`](#dictdef-gpudepthstencilstate) `state` is calculated by running the
following [queue timeline](#queue-timeline) steps:

1. Let `format` be
 `attachment`.[`view`](#dom-gpurenderpassdepthstencilattachment-view).[`format`](#dom-gputextureviewdescriptor-format).

2. Let `r` be the minimum positive representable value \>
 `0` in the `format` converted to a 32-bit float.

3. Let `maxDepthSlope` be the maximum of the horizontal and
 vertical slopes of the fragment's depth value.

4. If `format` is a **unorm** format:

 1. Let `bias` be
 `(float)``state``.`[`depthBias`](#dom-gpudepthstencilstate-depthbias)` * ``r`` + ``state``.`[`depthBiasSlopeScale`](#dom-gpudepthstencilstate-depthbiasslopescale)` * ``maxDepthSlope`.

 Otherwise, if `format` is a **float** format:

 1. Let `bias` be
 `(float)``state``.`[`depthBias`](#dom-gpudepthstencilstate-depthbias)` * 2^(exp(max depth in primitive) - ``r``) + ``state``.`[`depthBiasSlopeScale`](#dom-gpudepthstencilstate-depthbiasslopescale)` * ``maxDepthSlope`.

5. If
 `state`.[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp) \> `0`:

 1. Set `bias` to
 `min(``state``.`[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp)`, ``bias``)`.

 Otherwise, if
 `state`.[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp) \< `0`:

 1. Set `bias` to
 `max(``state``.`[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp)`, ``bias``)`.

6. If
 `state`.[`depthBias`](#dom-gpudepthstencilstate-depthbias) ≠ `0` or
 `state`.[`depthBiasSlopeScale`](#dom-gpudepthstencilstate-depthbiasslopescale) ≠ `0`:

 1. Set the fragment depth value to
 `fragment depth value + ``bias`

[validating
GPUDepthStencilState](`device`,
`descriptor`, `topology`)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [`GPUDepthStencilState`](#dictdef-gpudepthstencilstate) `descriptor`

- [`GPUPrimitiveTopology`](#enumdef-gpuprimitivetopology) `topology`

[Device timeline](#device-timeline) steps:

1. Return `true` if, and only if, all of the following conditions are
 satisfied:

 ::: validusage
 - `descriptor`.[`format`](#dom-gpudepthstencilstate-format) is a [depth-or-stencil
 format](#depth-or-stencil-format).

 - If
 `descriptor`.[`depthWriteEnabled`](#dom-gpudepthstencilstate-depthwriteenabled) is `true` or
 `descriptor`.[`depthCompare`](#dom-gpudepthstencilstate-depthcompare) is
 [provided](https://infra.spec.whatwg.org/#map-exists) and not
 [`"always"`](#dom-gpucomparefunction-always):

 - `descriptor`.[`format`](#dom-gpudepthstencilstate-format) must have a depth component.

 - If
 `descriptor`.[`stencilFront`](#dom-gpudepthstencilstate-stencilfront) or
 `descriptor`.[`stencilBack`](#dom-gpudepthstencilstate-stencilback) are not the default values:

 - `descriptor`.[`format`](#dom-gpudepthstencilstate-format) must have a stencil component.

 - If
 `descriptor`.[`format`](#dom-gpudepthstencilstate-format) has a depth component:

 - `descriptor`.[`depthWriteEnabled`](#dom-gpudepthstencilstate-depthwriteenabled) must be
 [provided](https://infra.spec.whatwg.org/#map-exists).

 - `descriptor`.[`depthCompare`](#dom-gpudepthstencilstate-depthcompare) must be
 [provided](https://infra.spec.whatwg.org/#map-exists) if:

 - `descriptor`.[`depthWriteEnabled`](#dom-gpudepthstencilstate-depthwriteenabled) is `true`, or

 - `descriptor`.[`stencilFront`](#dom-gpudepthstencilstate-stencilfront).[`depthFailOp`](#dom-gpustencilfacestate-depthfailop) is not
 [`"keep"`](#dom-gpustenciloperation-keep), or

 - `descriptor`.[`stencilBack`](#dom-gpudepthstencilstate-stencilback).[`depthFailOp`](#dom-gpustencilfacestate-depthfailop) is not
 [`"keep"`](#dom-gpustenciloperation-keep).

 - If `topology` is
 [`"point-list"`](#dom-gpuprimitivetopology-point-list),
 [`"line-list"`](#dom-gpuprimitivetopology-line-list), or
 [`"line-strip"`](#dom-gpuprimitivetopology-line-strip):

 - `descriptor`.[`depthBias`](#dom-gpudepthstencilstate-depthbias) must be 0.

 - `descriptor`.[`depthBiasSlopeScale`](#dom-gpudepthstencilstate-depthbiasslopescale) must be 0.

 - `descriptor`.[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp) must be 0.

 - ::: compatmode
 If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - `descriptor`.[`depthBiasClamp`](#dom-gpudepthstencilstate-depthbiasclamp) must be 0.
 :::
 :::

```
dictionary GPUStencilFaceState {
 GPUCompareFunction compare = "always";
 GPUStencilOperation failOp = "keep";
 GPUStencilOperation depthFailOp = "keep";
 GPUStencilOperation passOp = "keep";
};
```

[`GPUStencilFaceState`](#dictdef-gpustencilfacestate) has the following members, which describe how stencil
comparisons and operations are performed:

[`compare`], of type [GPUCompareFunction](#enumdef-gpucomparefunction), defaulting to `"always"`

: The
 [`GPUCompareFunction`](#enumdef-gpucomparefunction) used when testing the
 [`[[stencilReference]]`](#dom-renderstate-stencilreference-slot) value against the fragment's
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) stencil values.

[`failOp`], of type [GPUStencilOperation](#enumdef-gpustenciloperation), defaulting to `"keep"`

: The
 [`GPUStencilOperation`](#enumdef-gpustenciloperation) performed if the fragment stencil comparison test
 described by
 [`compare`](#dom-gpustencilfacestate-compare) fails.

[`depthFailOp`], of type [GPUStencilOperation](#enumdef-gpustenciloperation), defaulting to `"keep"`

: The
 [`GPUStencilOperation`](#enumdef-gpustenciloperation) performed if the fragment depth comparison
 described by
 [`depthCompare`](#dom-gpudepthstencilstate-depthcompare) fails.

[`passOp`], of type [GPUStencilOperation](#enumdef-gpustenciloperation), defaulting to `"keep"`

: The
 [`GPUStencilOperation`](#enumdef-gpustenciloperation) performed if the fragment stencil comparison test
 described by
 [`compare`](#dom-gpustencilfacestate-compare) passes.

```
enum GPUStencilOperation {
 "keep",
 "zero",
 "replace",
 "invert",
 "increment-clamp",
 "decrement-clamp",
 "increment-wrap",
 "decrement-wrap",
};
```

[`GPUStencilOperation`](#enumdef-gpustenciloperation) defines the following operations:

[`"keep"`]

: Keep the current stencil value.

[`"zero"`]

: Set the stencil value to `0`.

[`"replace"`]

: Set the stencil value to
 [`[[stencilReference]]`](#dom-renderstate-stencilreference-slot).

[`"invert"`]

: Bitwise-invert the current stencil value.

[`"increment-clamp"`]

: Increments the current stencil value, clamping to the maximum
 representable value of the
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment)'s stencil aspect.

[`"decrement-clamp"`]

: Decrement the current stencil value, clamping to `0`.

[`"increment-wrap"`]

: Increments the current stencil value, wrapping to zero if the value
 exceeds the maximum representable value of the
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment)'s stencil aspect.

[`"decrement-wrap"`]

: Decrement the current stencil value, wrapping to the maximum
 representable value of the
 [`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment)'s stencil aspect if the value goes below `0`.

#### 10.3.7. Vertex State

```
enum GPUIndexFormat {
 "uint16",
 "uint32",
};
```

The index format determines both the data type of index values in a
buffer and, when used with strip primitive topologies
([`"line-strip"`](#dom-gpuprimitivetopology-line-strip) or
[`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip)) also specifies the primitive restart value. The
[primitive restart value] indicates which index value indicates that a
new primitive should be started rather than continuing to construct the
triangle strip with the prior indexed vertices.

[`GPUPrimitiveState`](#dictdef-gpuprimitivestate)s that specify a strip primitive topology must specify a
[`stripIndexFormat`](#dom-gpuprimitivestate-stripindexformat) if they are used for indexed draws so that the
[primitive restart
value](#primitive-restart-value) that will be used is known at pipeline creation time.
[`GPUPrimitiveState`](#dictdef-gpuprimitivestate)s that specify a list primitive topology will use the
index format passed to
[`setIndexBuffer()`](#dom-gpurendercommandsmixin-setindexbuffer) when doing indexed rendering.

Index format

Byte size

Primitive restart value

[`"uint16"`]

2

0xFFFF

[`"uint32"`]

4

0xFFFFFFFF

##### 10.3.7.1. Vertex Formats

The
[`GPUVertexFormat`](#enumdef-gpuvertexformat) of a vertex attribute indicates how data from a vertex
buffer will be interpreted and exposed to the shader. The name of the
format specifies the order of components, bits per component, and
[vertex data type](#vertex-data-type) for the component.

Each [vertex data type] can map to any [WGSL scalar
type](https://gpuweb.github.io/gpuweb/wgsl/#scalar-types) of the same base type, regardless of the bits per
component:

Vertex format prefix

Vertex data type

Compatible WGSL types

`uint`

unsigned int

`u32`

`sint`

signed int

`i32`

`unorm`

unsigned normalized

`f16`, `f32`

`snorm`

signed normalized

`float`

floating point

The multi-component formats specify the number of components after
\"x\". Mismatches in the number of components between the vertex format
and shader type are allowed, with components being either dropped or
filled with default values to compensate.

A vertex attribute with a format of
[`"unorm8x2"`](#dom-gpuvertexformat-unorm8x2) and byte values `[0x7F, 0xFF]` can be accessed in the
shader with the following types:

Shader type

Shader value

`f16`

`0.5h`

`f32`

`0.5f`

`vec2<f16>`

`vec2(0.5h, 1.0h)`

`vec2<f32>`

`vec2(0.5f, 1.0f)`

`vec3<f16>`

`vec2(0.5h, 1.0h, 0.0h)`

`vec3<f32>`

`vec2(0.5f, 1.0f, 0.0f)`

`vec4<f16>`

`vec2(0.5h, 1.0h, 0.0h, 1.0h)`

`vec4<f32>`

`vec2(0.5f, 1.0f, 0.0f, 1.0f)`

See [§ 23.2.2 Vertex Processing](#vertex-processing) for additional
information about how vertex formats are exposed in the shader.

```
enum GPUVertexFormat {
 "uint8",
 "uint8x2",
 "uint8x4",
 "sint8",
 "sint8x2",
 "sint8x4",
 "unorm8",
 "unorm8x2",
 "unorm8x4",
 "snorm8",
 "snorm8x2",
 "snorm8x4",
 "uint16",
 "uint16x2",
 "uint16x4",
 "sint16",
 "sint16x2",
 "sint16x4",
 "unorm16",
 "unorm16x2",
 "unorm16x4",
 "snorm16",
 "snorm16x2",
 "snorm16x4",
 "float16",
 "float16x2",
 "float16x4",
 "float32",
 "float32x2",
 "float32x3",
 "float32x4",
 "uint32",
 "uint32x2",
 "uint32x3",
 "uint32x4",
 "sint32",
 "sint32x2",
 "sint32x3",
 "sint32x4",
 "unorm10-10-10-2",
 "unorm8x4-bgra",
};
```

Vertex format

Data type

Components

[byteSize]

Example WGSL type

[`"uint8"`]

unsigned int

1

1

`u32`

[`"uint8x2"`]

unsigned int

2

2

`vec2<u32>`

[`"uint8x4"`]

unsigned int

4

4

`vec4<u32>`

[`"sint8"`]

signed int

1

1

`i32`

[`"sint8x2"`]

signed int

2

2

`vec2<i32>`

[`"sint8x4"`]

signed int

4

4

`vec4<i32>`

[`"unorm8"`]

unsigned normalized

1

1

`f32`

[`"unorm8x2"`]

unsigned normalized

2

2

`vec2<f32>`

[`"unorm8x4"`]

unsigned normalized

4

4

`vec4<f32>`

[`"snorm8"`]

signed normalized

1

1

`f32`

[`"snorm8x2"`]

signed normalized

2

2

`vec2<f32>`

[`"snorm8x4"`]

signed normalized

4

4

`vec4<f32>`

[`"uint16"`]

unsigned int

1

2

`u32`

[`"uint16x2"`]

unsigned int

2

4

`vec2<u32>`

[`"uint16x4"`]

unsigned int

4

8

`vec4<u32>`

[`"sint16"`]

signed int

1

2

`i32`

[`"sint16x2"`]

signed int

2

4

`vec2<i32>`

[`"sint16x4"`]

signed int

4

8

`vec4<i32>`

[`"unorm16"`]

unsigned normalized

1

2

`f32`

[`"unorm16x2"`]

unsigned normalized

2

4

`vec2<f32>`

[`"unorm16x4"`]

unsigned normalized

4

8

`vec4<f32>`

[`"snorm16"`]

signed normalized

1

2

`f32`

[`"snorm16x2"`]

signed normalized

2

4

`vec2<f32>`

[`"snorm16x4"`]

signed normalized

4

8

`vec4<f32>`

[`"float16"`]

float

1

2

`f32`

[`"float16x2"`]

float

2

4

`vec2<f16>`

[`"float16x4"`]

float

4

8

`vec4<f16>`

[`"float32"`]

float

1

4

`f32`

[`"float32x2"`]

float

2

8

`vec2<f32>`

[`"float32x3"`]

float

3

12

`vec3<f32>`

[`"float32x4"`]

float

4

16

`vec4<f32>`

[`"uint32"`]

unsigned int

1

4

`u32`

[`"uint32x2"`]

unsigned int

2

8

`vec2<u32>`

[`"uint32x3"`]

unsigned int

3

12

`vec3<u32>`

[`"uint32x4"`]

unsigned int

4

16

`vec4<u32>`

[`"sint32"`]

signed int

1

4

`i32`

[`"sint32x2"`]

signed int

2

8

`vec2<i32>`

[`"sint32x3"`]

signed int

3

12

`vec3<i32>`

[`"sint32x4"`]

signed int

4

16

`vec4<i32>`

[`"unorm10-10-10-2"`]

unsigned normalized

4

4

`vec4<f32>`

[`"unorm8x4-bgra"`]

unsigned normalized

4

4

`vec4<f32>`

```
enum GPUVertexStepMode {
 "vertex",
 "instance",
};
```

The step mode configures how an address for vertex buffer data is
computed, based on the current vertex or instance index:

[`"vertex"`]

: The address is advanced by
 [`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) for each vertex, and reset between instances.

[`"instance"`]

: The address is advanced by
 [`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) for each instance.

```
dictionary GPUVertexState
 : GPUProgrammableStage {
 sequence<GPUVertexBufferLayout?> buffers = ;
};
```

[`buffers`], of type `sequence<GPUVertexBufferLayout?>`, defaulting to ``

: A list of
 [`GPUVertexBufferLayout`](#dictdef-gpuvertexbufferlayout)s, each defining the layout of vertex attribute data
 in a vertex buffer used by this pipeline.

A [vertex buffer] is, conceptually, a view into buffer memory as an *array of
structures*.
[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) is the stride, in bytes, between *elements* of that
array. Each element of a vertex buffer is like a *structure* with a
memory layout defined by its
[`attributes`](#dom-gpuvertexbufferlayout-attributes), which describe the *members* of the structure.

Each
[`GPUVertexAttribute`](#dictdef-gpuvertexattribute) describes its
[`format`](#dom-gpuvertexattribute-format) and its
[`offset`](#dom-gpuvertexattribute-offset), in bytes, within the structure.

Each attribute appears as a separate input in a vertex shader, each
bound by a numeric *location*, which is specified by
[`shaderLocation`](#dom-gpuvertexattribute-shaderlocation). Every location must be unique within the
[`GPUVertexState`](#dictdef-gpuvertexstate).

```
dictionary GPUVertexBufferLayout {
 required GPUSize64 arrayStride;
 GPUVertexStepMode stepMode = "vertex";
 required sequence<GPUVertexAttribute> attributes;
};
```

[`arrayStride`], of type [GPUSize64](#typedefdef-gpusize64)

: The stride, in bytes, between elements of this array.

[`stepMode`], of type [GPUVertexStepMode](#enumdef-gpuvertexstepmode), defaulting to `"vertex"`

: Whether each element of this array represents per-vertex data or
 per-instance data

[`attributes`], of type sequence\<[GPUVertexAttribute](#dictdef-gpuvertexattribute)\>

: An array defining the layout of the vertex attributes within each
 element.

```
dictionary GPUVertexAttribute {
 required GPUVertexFormat format;
 required GPUSize64 offset;

 required GPUIndex32 shaderLocation;
};
```

[`format`], of type [GPUVertexFormat](#enumdef-gpuvertexformat)

: The
 [`GPUVertexFormat`](#enumdef-gpuvertexformat) of the attribute.

[`offset`], of type [GPUSize64](#typedefdef-gpusize64)

: The offset, in bytes, from the beginning of the element to the data
 for the attribute.

[`shaderLocation`], of type [GPUIndex32](#typedefdef-gpuindex32)

: The numeric location associated with this attribute, which will
 correspond with a [\"@location\"
 attribute](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations)
 declared in the
 [`vertex`](#dom-gpurenderpipelinedescriptor-vertex).[`module`](#dom-gpuprogrammablestage-module).

[validating
GPUVertexBufferLayout](device, descriptor)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [`GPUVertexBufferLayout`](#dictdef-gpuvertexbufferlayout) `descriptor`

[Device timeline](#device-timeline) steps:

1. Return `true`, if and only if, all of the following conditions are
 satisfied:

 ::: validusage
 - `descriptor`.[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) ≤
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxVertexBufferArrayStride`](#dom-supported-limits-maxvertexbufferarraystride).

 - `descriptor`.[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) is a multiple of 4.

 - For each attribute `attrib` in the list
 `descriptor`.[`attributes`](#dom-gpuvertexbufferlayout-attributes):

 - If
 `descriptor`.[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) is zero:

 - `attrib`.[`offset`](#dom-gpuvertexattribute-offset) +
 [byteSize](#abstract-opdef-gpuvertexformat-bytesize)(`attrib`.[`format`](#dom-gpuvertexattribute-format)) ≤
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxVertexBufferArrayStride`](#dom-supported-limits-maxvertexbufferarraystride).

 Otherwise:

 - `attrib`.[`offset`](#dom-gpuvertexattribute-offset) +
 [byteSize](#abstract-opdef-gpuvertexformat-bytesize)(`attrib`.[`format`](#dom-gpuvertexattribute-format)) ≤
 `descriptor`.[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride).

 - `attrib`.[`offset`](#dom-gpuvertexattribute-offset) is a multiple of the minimum of 4 and
 [byteSize](#abstract-opdef-gpuvertexformat-bytesize)(`attrib`.[`format`](#dom-gpuvertexattribute-format)).

 - `attrib`.[`shaderLocation`](#dom-gpuvertexattribute-shaderlocation) is \<
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxVertexAttributes`](#dom-supported-limits-maxvertexattributes).
 :::

[validating GPUVertexState](device, descriptor,
layout)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [`GPUVertexState`](#dictdef-gpuvertexstate) `descriptor`

- [`GPUPipelineLayout`](#gpupipelinelayout) `layout`

[Device timeline](#device-timeline) steps:

1. Let `entryPoint` be [get the entry
 point](#abstract-opdef-get-the-entry-point)([`VERTEX`](#dom-gpushaderstage-vertex), `descriptor`).

2. [Assert](https://infra.spec.whatwg.org/#assert) `entryPoint` is not `null`.

3. All of the requirements in the following steps `must` be
 met.

 ::: validusage
 1. [validating
 GPUProgrammableStage](#abstract-opdef-validating-gpuprogrammablestage)([`VERTEX`](#dom-gpushaderstage-vertex), `descriptor`, `layout`,
 `device`) `must` succeed.

 2. `descriptor`.[`buffers`](#dom-gpuvertexstate-buffers).[size](https://infra.spec.whatwg.org/#list-size) `must` be ≤
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxVertexBuffers`](#dom-supported-limits-maxvertexbuffers).

 3. Each `vertexBuffer` layout descriptor in the list
 `descriptor`.[`buffers`](#dom-gpuvertexstate-buffers) `must` pass [validating
 GPUVertexBufferLayout](#abstract-opdef-validating-gpuvertexbufferlayout)(`device`,
 `vertexBuffer`).

 4. Let `totalEffectiveVertexAttributes` be the sum of
 `vertexBuffer`.[`attributes`](#dom-gpuvertexbufferlayout-attributes).[size](https://infra.spec.whatwg.org/#list-size), over every `vertexBuffer` in
 `descriptor`.[`buffers`](#dom-gpuvertexstate-buffers).

 5. ::: compatmode
 If
 `device`.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 1. If the
 [vertex_index](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-vertex_index) builtin is a [shader stage
 input](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-input) of
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex):

 - Add 1 to `totalEffectiveVertexAttributes`

 2. If the
 [instance_index](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-instance_index) builtin is a [shader stage
 input](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-input) of
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex):

 - Add 1 to `totalEffectiveVertexAttributes`
 :::

 6. `totalEffectiveVertexAttributes` `must` be
 ≤
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxVertexAttributes`](#dom-supported-limits-maxvertexattributes).

 7. For every vertex attribute declaration (at location
 `location` with type `T`) that is
 [statically used](#statically-used) by `entryPoint`, there
 `must` be exactly one pair (`i`,
 `j`) for which
 `descriptor`.[`buffers`](#dom-gpuvertexstate-buffers)\[`i`\]?.[`attributes`](#dom-gpuvertexbufferlayout-attributes)\[`j`\].[`shaderLocation`](#dom-gpuvertexattribute-shaderlocation) == `location`.

 Let `attrib` be that
 [`GPUVertexAttribute`](#dictdef-gpuvertexattribute).

 8. `T` `must` be compatible with
 `attrib`.[`format`](#dom-gpuvertexattribute-format)'s [vertex data
 type](#vertex-data-type):

 \"unorm\", \"snorm\", or \"float\"

 : `T` must be `f32` or `vecN<f32>`.

 \"uint\"

 : `T` must be `u32` or `vecN<u32>`.

 \"sint\"

 : `T` must be `i32` or `vecN<i32>`.
 :::

## 11. Copies

### 11.1. Buffer Copies

Buffer copy operations operate on raw bytes.

WebGPU provides \"buffered\"
[`GPUCommandEncoder`](#gpucommandencoder) commands:

- [copyBufferToBuffer()](#gpucommandencoder-copybuffertobuffer)

- [`clearBuffer()`](#dom-gpucommandencoder-clearbuffer)

and \"immediate\" [`GPUQueue`](#gpuqueue) operations:

- [`writeBuffer()`](#dom-gpuqueue-writebuffer), for
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)-to-[`GPUBuffer`](#gpubuffer) writes

### 11.2. Texel Copies

[Texel copy]
operations operate on texture/\"image\" data, rather than bytes.

WebGPU provides \"buffered\"
[`GPUCommandEncoder`](#gpucommandencoder) commands:

- [`copyTextureToTexture()`](#dom-gpucommandencoder-copytexturetotexture)

- [`copyBufferToTexture()`](#dom-gpucommandencoder-copybuffertotexture)

- [`copyTextureToBuffer()`](#dom-gpucommandencoder-copytexturetobuffer)

and \"immediate\" [`GPUQueue`](#gpuqueue) operations:

- [`writeTexture()`](#dom-gpuqueue-writetexture), for
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)-to-[`GPUTexture`](#gputexture) writes

- [`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture), for copies from Web Platform image sources to
 textures

In a texel copy, the bytes written to the destination texel blocks will
have an [equivalent texel
representation] to the source value.

Texel copies only guarantee that valid, finite, non-subnormal numeric
values in the source have the same numeric value in the destination.
Specifically, the texel block may be decoded and re-encoded in a way
that preserves only those values. Where multiple byte representations
are possible, the choice of representation is implementation-defined.

- Any floating-point zero value may be represented as either -0.0 or
 +0.0.

- Any floating-point subnormal value may be either preserved or replaced
 by -0.0 or +0.0.

- Any floating-point `NaN` or `Infinity` value may be replaced by an
 [indeterminate
 value](https://gpuweb.github.io/gpuweb/wgsl/#indeterminate-values).

- Packed formats and `snorm` formats may change bit-representation as
 long as the represented values follow the rules above, for example:

 - `snorm` formats may represent -1.0 as either -127 or -128.

 - Formats like
 [`"rgb9e5ufloat"`](#dom-gputextureformat-rgb9e5ufloat) have multiple bit-representations of some values.

 For formats supporting
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) or
[`STORAGE_BINDING`](#dom-gputextureusage-storage_binding), this can be thought of as similar to, and may be
implemented as, writing the texture using a WGSL shader. In general, any
[WGSL floating point
behaviors](https://gpuweb.github.io/gpuweb/wgsl/#differences-from-ieee754) may be observed.

The following definitions are used by these methods:

#### 11.2.1. `GPUTexelCopyBufferLayout`

\"[`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout)\" describes the \"**layout**\" of texels in a
\"**buffer**\" of bytes
([`GPUBuffer`](#gpubuffer)
or
[`AllowSharedBufferSource`](https://webidl.spec.whatwg.org/#AllowSharedBufferSource)) in a \"**[texel
copy](#texel-copy)**\" operation.

```
dictionary GPUTexelCopyBufferLayout {
 GPUSize64 offset = 0;
 GPUSize32 bytesPerRow;
 GPUSize32 rowsPerImage;
};
```

A [texel image] is comprised of one or more rows of [texel
blocks](#texel-block), referred
to here as [texel block row]s. Each [texel block
row](#texel-block-row) of a
[texel image](#texel-image) must
contain the same number of [texel
blocks](#texel-block), and all
[texel blocks](#texel-block) in a
[texel image](#texel-image) are
of the same
[`GPUTextureFormat`](#enumdef-gputextureformat).

A
[`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout) is a layout of [texel
images](#texel-image) within some
linear memory. It's used when copying data between a
[texture](#texture) and a
[`GPUBuffer`](#gpubuffer),
or when scheduling a write into a [texture](#texture) from the
[`GPUQueue`](#gpuqueue).

- For
 [`2d`](#dom-gputexturedimension-2d) textures, data is copied between one or multiple
 contiguous [texel images](#texel-image) and [array
 layers](#array-layer).

- For
 [`3d`](#dom-gputexturedimension-3d) textures, data is copied between one or multiple
 contiguous [texel images](#texel-image) and depth [slices](#slice).

Operations that copy between byte arrays and textures always operate on
whole [texel block](#texel-block). It's not possible to update only a part of a [texel
block](#texel-block).

[Texel blocks](#texel-block) are
tightly packed within each [texel block
row](#texel-block-row) in the
linear memory layout of a [texel copy](#texel-copy), with each subsequent [texel
block](#texel-block) immediately
following the previous [texel
block](#texel-block), with no
padding. This includes [copies](#copying-depth-stencil) to/from specific
aspects of [depth-or-stencil
format](#depth-or-stencil-format) textures: stencil values are tightly packed in an array
of bytes; depth values are tightly packed in an array of the appropriate
type (\"depth16unorm\" or \"depth32float\").

[`offset`], of type [GPUSize64](#typedefdef-gpusize64), defaulting to `0`

: The offset, in bytes, from the beginning of the texel data source
 (such as a
 [`GPUTexelCopyBufferInfo.buffer`](#dom-gputexelcopybufferinfo-buffer)) to the start of the texel data within that source.

[`bytesPerRow`], of type [GPUSize32](#typedefdef-gpusize32)

: The stride, in bytes, between the beginning of each [texel block
 row](#texel-block-row)
 and the subsequent [texel block
 row](#texel-block-row).

 Required if there are multiple [texel block
 rows](#texel-block-row)
 (i.e. the copy height or depth is more than one block).

[`rowsPerImage`], of type [GPUSize32](#typedefdef-gpusize32)

: Number of [texel block
 rows](#texel-block-row)
 per single [texel image](#texel-image) of the [texture](#texture).
 [`rowsPerImage`](#dom-gputexelcopybufferlayout-rowsperimage) ×
 [`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) is the stride, in bytes, between the beginning of
 each [texel image](#texel-image) of data and the subsequent [texel
 image](#texel-image).

 Required if there are multiple [texel
 images](#texel-image) (i.e.
 the copy depth is more than one).

#### 11.2.2. `GPUTexelCopyBufferInfo`

\"[`GPUTexelCopyBufferInfo`](#gputexelcopybufferinfo)\" describes the \"**info**\"
([`GPUBuffer`](#gpubuffer)
and
[`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout)) about a \"**buffer**\" source or destination of a
\"**[texel copy](#texel-copy)**\"
operation. Together with the `copySize`, it describes the footprint of a
region of texels in a
[`GPUBuffer`](#gpubuffer).

```
dictionary GPUTexelCopyBufferInfo
 : GPUTexelCopyBufferLayout {
 required GPUBuffer buffer;
};
```

[`buffer`], of type [GPUBuffer](#gpubuffer)

: A buffer which either contains texel data to be copied or will store
 the texel data being copied, depending on the method it is being
 passed to.

[validating
GPUTexelCopyBufferInfo]

**Arguments:**

- [`GPUTexelCopyBufferInfo`](#gputexelcopybufferinfo) `imageCopyBuffer`

**Returns:**
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

[Device timeline](#device-timeline) steps:

1. Return `true` if and only if all of the following conditions are
 satisfied:

 ::: validusage
 - `imageCopyBuffer`.[`buffer`](#dom-gputexelcopybufferinfo-buffer) must be a
 [valid](https://w3c.github.io/i18n-glossary/#dfn-valid)
 [`GPUBuffer`](#gpubuffer).

 - `imageCopyBuffer`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) must be a multiple of 256.
 :::

#### 11.2.3. `GPUTexelCopyTextureInfo`

\"[`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo)\" describes the \"**info**\"
([`GPUTexture`](#gputexture), etc.) about a \"**texture**\" source or destination of
a \"**[texel copy](#texel-copy)**\" operation. Together with the `copySize`, it
describes a sub-region of a texture (spanning one or more contiguous
[texture
subresources](#texture-subresources) at the same mip-map level).

```
dictionary GPUTexelCopyTextureInfo {
 required GPUTexture texture;
 GPUIntegerCoordinate mipLevel = 0;
 GPUOrigin3D origin = ;
 GPUTextureAspect aspect = "all";
};
```

[`texture`], of type [GPUTexture](#gputexture)

: Texture to copy to/from.

[`mipLevel`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate), defaulting to `0`

: Mip-map level of the
 [`texture`](#dom-gputexelcopytextureinfo-texture) to copy to/from.

[`origin`], of type [GPUOrigin3D](#typedefdef-gpuorigin3d), defaulting to ``

: Defines the origin of the copy - the minimum corner of the texture
 sub-region to copy to/from. Together with `copySize`, defines the
 full copy sub-region.

[`aspect`], of type [GPUTextureAspect](#enumdef-gputextureaspect), defaulting to `"all"`

: Defines which aspects of the
 [`texture`](#dom-gputexelcopytextureinfo-texture) to copy to/from.

The [texture copy sub-region] for depth slice or
array layer `index` of
[`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo) `copyTexture` is determined by running the
following steps:

1. Let `texture` be
 `copyTexture`.[`texture`](#dom-gputexelcopytextureinfo-texture).

2. If
 `texture`.[`dimension`](#dom-gputexture-dimension) is:

 [`1d`](#dom-gputexturedimension-1d)

 : 1. [Assert](https://infra.spec.whatwg.org/#assert) `index` is `0`

 2. Let `depthSliceOrLayer` be `texture`

 [`2d`](#dom-gputexturedimension-2d)

 : Let `depthSliceOrLayer` be array layer
 `index` of `texture`

 [`3d`](#dom-gputexturedimension-3d)

 : Let `depthSliceOrLayer` be depth slice
 `index` of `texture`

3. Let `textureMip` be mip level
 `copyTexture`.[`mipLevel`](#dom-gputexelcopytextureinfo-miplevel) of `depthSliceOrLayer`.

4. Return aspect
 `copyTexture`.[`aspect`](#dom-gputexelcopytextureinfo-aspect) of `textureMip`.

The [texel block byte offset] of data described by
[`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout) `bufferLayout` corresponding to [texel
block](#texel-block)
`x`, `y` of depth slice or array layer
`z` of a
[`GPUTexture`](#gputexture)
`texture` is determined by running the following steps:

1. Let `blockBytes` be the [texel block copy
 footprint](#texel-block-copy-footprint) of
 `texture`.[`format`](#dom-gputexture-format).

2. Let `imageOffset` be (`z` ×
 `bufferLayout`.[`rowsPerImage`](#dom-gputexelcopybufferlayout-rowsperimage) ×
 `bufferLayout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow)) +
 `bufferLayout`.[`offset`](#dom-gputexelcopybufferlayout-offset).

3. Let `rowOffset` be (`y` ×
 `bufferLayout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow)) + `imageOffset`.

4. Let `blockOffset` be (`x` ×
 `blockBytes`) + `rowOffset`.

5. Return `blockOffset`.

[validating
GPUTexelCopyTextureInfo](`texelCopyTextureInfo`, `copySize`)

**Arguments:**

- [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo) `texelCopyTextureInfo`

- [`GPUExtent3D`](#typedefdef-gpuextent3d) `copySize`

**Returns:**
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

[Device timeline](#device-timeline) steps:

1. Let `blockWidth` be the [texel block
 width](#texel-block-width) of
 `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format).

2. Let `blockHeight` be the [texel block
 height](#texel-block-height) of
 `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format).

3. Return `true` if and only if all of the following conditions apply:

 ::: validusage
 - [validating texture copy
 range](#abstract-opdef-validating-texture-copy-range)(`texelCopyTextureInfo`,
 `copySize`) returns `true`.

 - `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture) must be a
 [valid](https://w3c.github.io/i18n-glossary/#dfn-valid)
 [`GPUTexture`](#gputexture).

 - `texelCopyTextureInfo`.[`mipLevel`](#dom-gputexelcopytextureinfo-miplevel) must be \<
 `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`mipLevelCount`](#dom-gputexture-miplevelcount).

 - `texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[x](#gpuorigin3d-x) must be a multiple of `blockWidth`.

 - `texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[y](#gpuorigin3d-y) must be a multiple of `blockHeight`.

 - The [GPUTexelCopyTextureInfo physical subresource
 size](#gputexelcopytextureinfo-physical-subresource-size) of `texelCopyTextureInfo` is equal to
 `copySize` if either of the following conditions is
 true:

 - `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format) is a depth-stencil format.

 - `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`sampleCount`](#dom-gputexture-samplecount) \> 1.
 :::

[validating texture buffer
copy](`texelCopyTextureInfo`,
`bufferLayout`, `dataLength`,
`copySize`, `textureUsage`, `aligned`)

**Arguments:**

- [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo) `texelCopyTextureInfo`

- [`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout) `bufferLayout`

- [`GPUSize64Out`](#typedefdef-gpusize64out) `dataLength`

- [`GPUExtent3D`](#typedefdef-gpuextent3d) `copySize`

- [`GPUTextureUsage`](#namespacedef-gputextureusage) `textureUsage`

- [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean) `aligned`

**Returns:**
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

[Device timeline](#device-timeline) steps:

1. Let `texture` be
 `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture)

2. Let `aspectSpecificFormat` =
 `texture`.[`format`](#dom-gputexture-format).

3. Let `offsetAlignment` = [texel block copy
 footprint](#texel-block-copy-footprint) of
 `texture`.[`format`](#dom-gputexture-format).

4. Return `true` if and only if all of the following conditions apply:

 ::: validusage
 1. [validating
 GPUTexelCopyTextureInfo](#abstract-opdef-validating-gputexelcopytextureinfo)(`texelCopyTextureInfo`,
 `copySize`) returns `true`.

 2. `texture`.[`sampleCount`](#dom-gputexture-samplecount) is 1.

 3. `texture`.[`usage`](#dom-gputexture-usage) contains `textureUsage`.

 4. If
 `texture`.[`format`](#dom-gputexture-format) is a [depth-or-stencil
 format](#depth-or-stencil-format) format:

 1. `texelCopyTextureInfo`.[`aspect`](#dom-gputexelcopytextureinfo-aspect) must refer to a single aspect of
 `texture`.[`format`](#dom-gputexture-format).

 2. If `textureUsage` is:

 [`COPY_SRC`](#dom-gputextureusage-copy_src)

 : That aspect must be a valid [texel
 copy](#texel-copy)
 source according to [§ 26.1.2 Depth-stencil
 formats](#depth-formats).

 [`COPY_DST`](#dom-gputextureusage-copy_dst)

 : That aspect must be a valid [texel
 copy](#texel-copy)
 destination according to [§ 26.1.2 Depth-stencil
 formats](#depth-formats).

 3. Set `aspectSpecificFormat` to the
 [aspect-specific
 format](#aspect-specific-format) according to [§ 26.1.2 Depth-stencil
 formats](#depth-formats).

 4. Set `offsetAlignment` to 4.

 5. If `aligned` is `true`:

 1. `bufferLayout`.[`offset`](#dom-gputexelcopybufferlayout-offset) is a multiple of
 `offsetAlignment`.

 6. [validating linear texture
 data](#abstract-opdef-validating-linear-texture-data)(`bufferLayout`,
 `dataLength`, `aspectSpecificFormat`,
 `copySize`) succeeds.
 :::

#### 11.2.4. `GPUCopyExternalImageDestInfo`

WebGPU textures hold raw numeric data, and are not tagged with semantic
metadata describing colors. However,
[`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture) copies from sources that describe colors.

\"[`GPUCopyExternalImageDestInfo`](#gpucopyexternalimagedestinfo)\" describes the \"**info**\" about the
\"**dest**ination\" of a
\"[**`copyExternalImage`**`ToTexture()`](#dom-gpuqueue-copyexternalimagetotexture)\" operation. It is a
[`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo) which is additionally tagged with color space/encoding
and alpha-premultiplication metadata, so that semantic color data may be
preserved during copies. This metadata affects only the semantics of the
copy operation operation, not the state or semantics of the destination
texture object.

```
dictionary GPUCopyExternalImageDestInfo
 : GPUTexelCopyTextureInfo {
 PredefinedColorSpace colorSpace = "srgb";
 boolean premultipliedAlpha = false;
};
```

[`colorSpace`], of type [PredefinedColorSpace](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace), defaulting to `"srgb"`

: Describes the color space and encoding used to encode data into the
 destination texture.

 This [may result](#color-space-conversions) in values outside of the
 range \[0, 1\] being written to the target texture, if its format
 can represent them. Otherwise, the results are clamped to the target
 texture format's range.

 If
 [`colorSpace`](#dom-gpucopyexternalimagedestinfo-colorspace) matches the source image, conversion might not be
 necessary. See [§ 3.11.2 Color Space Conversion
 Elision](#color-space-conversion-elision).

[`premultipliedAlpha`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Describes whether the data written into the texture should have its
 RGB channels premultiplied by the alpha channel, or not.

 If this option is set to `true` and the
 [`source`](#dom-gpucopyexternalimagesourceinfo-source) is also premultiplied, the source RGB values must
 be preserved even if they exceed their corresponding alpha values.

 If
 [`premultipliedAlpha`](#dom-gpucopyexternalimagedestinfo-premultipliedalpha) matches the source image, conversion might not be
 necessary. See [§ 3.11.2 Color Space Conversion
 Elision](#color-space-conversion-elision).

#### 11.2.5. `GPUCopyExternalImageSourceInfo`

\"[`GPUCopyExternalImageSourceInfo`](#gpucopyexternalimagesourceinfo)\" describes the \"**info**\" about the \"**source**\"
of a
\"[**`copyExternalImage`**`ToTexture()`](#dom-gpuqueue-copyexternalimagetotexture)\" operation.

```
typedef (ImageBitmap or
 ImageData or
 HTMLImageElement or
 HTMLVideoElement or
 VideoFrame or
 HTMLCanvasElement or
 OffscreenCanvas) GPUCopyExternalImageSource;

dictionary GPUCopyExternalImageSourceInfo {
 required GPUCopyExternalImageSource source;
 GPUOrigin2D origin = ;
 boolean flipY = false;
};
```

[`GPUCopyExternalImageSourceInfo`](#gpucopyexternalimagesourceinfo) has the following members:

[`source`], of type [GPUCopyExternalImageSource](#typedefdef-gpucopyexternalimagesource)

: The source of the [texel copy](#texel-copy). The copy source data is captured at the moment
 that
 [`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture) is issued. Source size is determined as described
 by the [external source
 dimensions](#external-source-dimensions) table.

[`origin`], of type [GPUOrigin2D](#typedefdef-gpuorigin2d), defaulting to ``

: Defines the origin of the copy - the minimum (top-left) corner of
 the source sub-region to copy from. Together with `copySize`,
 defines the full copy sub-region.

[`flipY`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Describes whether the source image is vertically flipped, or not.

 If this option is set to `true`, the copy is flipped vertically: the
 bottom row of the source region is copied into the first row of the
 destination region, and so on. The
 [`origin`](#dom-gpucopyexternalimagesourceinfo-origin) option is still relative to the top-left corner of
 the source image, increasing downward.

When external sources are used when creating or copying to textures, the
[external source dimensions] are defined by the source type,
given by this table:

External Source type

Dimensions

[`ImageBitmap`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap)

[`ImageBitmap.width`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmap-width),
[`ImageBitmap.height`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmap-height)

[`HTMLImageElement`](https://html.spec.whatwg.org/multipage/embedded-content.html#htmlimageelement)

[`HTMLImageElement.naturalWidth`](https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-naturalwidth),
[`HTMLImageElement.naturalHeight`](https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-naturalheight)

[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement)

[intrinsic width of the
frame](https://html.spec.whatwg.org/multipage/media.html#concept-video-intrinsic-width), [intrinsic height of the
frame](https://html.spec.whatwg.org/multipage/media.html#concept-video-intrinsic-height)

[`VideoFrame`](https://w3c.github.io/webcodecs/#videoframe)

[`VideoFrame.displayWidth`](https://w3c.github.io/webcodecs/#dom-videoframe-displaywidth),
[`VideoFrame.displayHeight`](https://w3c.github.io/webcodecs/#dom-videoframe-displayheight)

[`ImageData`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagedata)

[`ImageData.width`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagedata-width),
[`ImageData.height`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagedata-height)

[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas) with
[`CanvasRenderingContext2D`](https://html.spec.whatwg.org/multipage/canvas.html#canvasrenderingcontext2d) or
[`GPUCanvasContext`](#gpucanvascontext)

[`HTMLCanvasElement.width`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-width),
[`HTMLCanvasElement.height`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-height)

[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas) with
[`WebGLRenderingContextBase`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#WEBGLRENDERINGCONTEXTBASE)

[`WebGLRenderingContextBase.drawingBufferWidth`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#DOM-WebGLRenderingContext-drawingBufferWidth),
[`WebGLRenderingContextBase.drawingBufferHeight`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#DOM-WebGLRenderingContext-drawingBufferHeight)

[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas) with
[`ImageBitmapRenderingContext`](https://html.spec.whatwg.org/multipage/canvas.html#imagebitmaprenderingcontext)

[`ImageBitmapRenderingContext`](https://html.spec.whatwg.org/multipage/canvas.html#imagebitmaprenderingcontext)'s internal output bitmap
[`ImageBitmap.width`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmap-width),
[`ImageBitmap.height`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmap-height)

#### 11.2.6. Subroutines

[GPUTexelCopyTextureInfo physical subresource
size]

**Arguments:**

- [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo) `texelCopyTextureInfo`

**Returns:**
[`GPUExtent3D`](#typedefdef-gpuextent3d)

The [GPUTexelCopyTextureInfo physical subresource
size](#gputexelcopytextureinfo-physical-subresource-size) of `texelCopyTextureInfo` is calculated as
follows:

Its [width](#gpuextent3d-width),
[height](#gpuextent3d-height) and
[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) are the width, height, and depth, respectively, of the
[physical miplevel-specific texture
extent](#physical-miplevel-specific-texture-extent) of
`texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture) [subresource](#subresource) at [mipmap level](#mipmap-level)
`texelCopyTextureInfo`.[`mipLevel`](#dom-gputexelcopytextureinfo-miplevel).

[validating linear texture
data](layout, byteSize, format, copyExtent)

**Arguments:**

[`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout) `layout`

: Layout of the linear texture data.

[`GPUSize64`](#typedefdef-gpusize64) `byteSize`

: Total size of the linear data, in bytes.

[`GPUTextureFormat`](#enumdef-gputextureformat) `format`

: Format of the texture.

[`GPUExtent3D`](#typedefdef-gpuextent3d) `copyExtent`

: Extent of the texture to copy.

[Device timeline](#device-timeline) steps:

1. Let:

 - `widthInBlocks` be
 `copyExtent`.[width](#gpuextent3d-width) ÷ the [texel block
 width](#texel-block-width) of `format`.
 [Assert](https://infra.spec.whatwg.org/#assert) this is an integer.

 - `heightInBlocks` be
 `copyExtent`.[height](#gpuextent3d-height) ÷ the [texel block
 height](#texel-block-height) of `format`.
 [Assert](https://infra.spec.whatwg.org/#assert) this is an integer.

 - `bytesInLastRow` be `widthInBlocks` × the
 [texel block copy
 footprint](#texel-block-copy-footprint) of `format`.

2. Fail if the following input validation requirements are not met:

 ::: validusage
 - If `heightInBlocks` \> 1,
 `layout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) must be specified.

 - If
 `copyExtent`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) \> 1,
 `layout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) and
 `layout`.[`rowsPerImage`](#dom-gputexelcopybufferlayout-rowsperimage) must be specified.

 - If specified,
 `layout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) must be ≥ `bytesInLastRow`.

 - If specified,
 `layout`.[`rowsPerImage`](#dom-gputexelcopybufferlayout-rowsperimage) must be ≥ `heightInBlocks`.
 :::

3. Let:

 - `bytesPerRow` be
 `layout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) ?? 0.

 - `rowsPerImage` be
 `layout`.[`rowsPerImage`](#dom-gputexelcopybufferlayout-rowsperimage) ?? 0.

 These default values have no effect, as they're
 always multiplied by 0.

4. Let `requiredBytesInCopy` be 0.

5. If
 `copyExtent`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) \> 0:

 1. Increment `requiredBytesInCopy` by
 `bytesPerRow` × `rowsPerImage` ×
 (`copyExtent`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) − 1).

 2. If `heightInBlocks` \> 0:

 1. Increment `requiredBytesInCopy` by
 `bytesPerRow` × (`heightInBlocks`
 − 1) + `bytesInLastRow`.

6. Fail if the following condition is not satisfied:

 ::: validusage
 - The layout fits inside the linear data:
 `layout`.[`offset`](#dom-gputexelcopybufferlayout-offset) + `requiredBytesInCopy` ≤
 `byteSize`.
 :::

[validating texture copy
range]

**Arguments:**

[`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo) `texelCopyTextureInfo`

: The texture subresource being copied into and copy origin.

[`GPUExtent3D`](#typedefdef-gpuextent3d) `copySize`

: The size of the texture.

[Device timeline](#device-timeline) steps:

1. Let `blockWidth` be the [texel block
 width](#texel-block-width) of
 `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format).

2. Let `blockHeight` be the [texel block
 height](#texel-block-height) of
 `texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format).

3. Let `subresourceSize` be the [GPUTexelCopyTextureInfo
 physical subresource
 size](#gputexelcopytextureinfo-physical-subresource-size) of `texelCopyTextureInfo`.

4. Return whether all the conditions below are satisfied:

 ::: validusage
 - (`texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[x](#gpuorigin3d-x) +
 `copySize`.[width](#gpuextent3d-width)) ≤
 `subresourceSize`.[width](#gpuextent3d-width)

 - (`texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[y](#gpuorigin3d-y) +
 `copySize`.[height](#gpuextent3d-height)) ≤
 `subresourceSize`.[height](#gpuextent3d-height)

 - (`texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[z](#gpuorigin3d-z) +
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers)) ≤
 `subresourceSize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers)

 - `copySize`.[width](#gpuextent3d-width) must be a multiple of `blockWidth`.

 - `copySize`.[height](#gpuextent3d-height) must be a multiple of `blockHeight`.

 The texture copy range is validated against the
 *physical* (rounded-up) size for [compressed
 formats](#compressed-format), allowing copies to access texture blocks which are
 not fully inside the texture.
 :::

[`GPUTextureFormat`](#enumdef-gputextureformat)s `format1` and `format2` are
[copy-compatible] if:

- `format1` equals `format2`, or

- `format1` and `format2` differ only in whether
 they are `srgb` formats (have the `-srgb` suffix).

The [set of subresources for texture
copy](`texelCopyTextureInfo`, `copySize`) is
the subset of subresources of `texture` =
`texelCopyTextureInfo`.[`texture`](#dom-gputexelcopytextureinfo-texture) for which each subresource `s` satisfies the
following:

- The [mipmap level](#mipmap-level) of `s` equals
 `texelCopyTextureInfo`.[`mipLevel`](#dom-gputexelcopytextureinfo-miplevel).

- The [aspect](#aspect) of
 `s` is in the [set of
 aspects](#gputextureaspect-set-of-aspects) of
 `texelCopyTextureInfo`.[`aspect`](#dom-gputexelcopytextureinfo-aspect).

- If
 `texture`.[`dimension`](#dom-gputexture-dimension) is
 [`"2d"`](#dom-gputexturedimension-2d):

 - The [array layer](#array-layer) of `s` is ≥
 `texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[z](#gpuorigin3d-z) and \<
 `texelCopyTextureInfo`.[`origin`](#dom-gputexelcopytextureinfo-origin).[z](#gpuorigin3d-z) +
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers).

## 12. Command Buffers

Command buffers are pre-recorded lists of [GPU
commands](#gpu-command) (blocks
of [queue timeline](#queue-timeline) steps) that can be submitted to a
[`GPUQueue`](#gpuqueue) for
execution. Each [GPU command] represents a task to be performed on the
[queue timeline](#queue-timeline), such as setting state, drawing, copying resources,
etc.

A
[`GPUCommandBuffer`](#gpucommandbuffer) can only be submitted once, at which point it becomes
[invalidated](#abstract-opdef-invalidate). To reuse rendering commands across multiple
submissions, use
[`GPURenderBundle`](#gpurenderbundle).

### 12.1. `GPUCommandBuffer`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUCommandBuffer ;
GPUCommandBuffer includes GPUObjectBase;
```

[`GPUCommandBuffer`](#gpucommandbuffer) has the following [device timeline
properties](#device-timeline-property):

[`[[command_list]]`], of type [list](https://infra.spec.whatwg.org/#list)\<[GPU command](#gpu-command)\>, readonly

: A [list](https://infra.spec.whatwg.org/#list) of [GPU
 commands](#gpu-command) to be
 executed on the [Queue
 timeline](#queue-timeline) when this command buffer is submitted.

[`[[renderState]]`], of type [RenderState](#renderstate), initially `null`

: The current state used by any render pass commands being executed.

[`[[used_bind_groups]]`], of type [set](https://infra.spec.whatwg.org/#ordered-set)\<[`GPUBindGroup`](#gpubindgroup)\>, readonly

: A
 [set](https://infra.spec.whatwg.org/#ordered-set) of all
 [`GPUBindGroup`](#gpubindgroup)s used by this command buffer.

#### 12.1.1. Command Buffer Creation

```
dictionary GPUCommandBufferDescriptor
 : GPUObjectDescriptorBase ;
```

## 13. Command Encoding

### 13.1. `GPUCommandsMixin`

[`GPUCommandsMixin`](#gpucommandsmixin) defines state common to all interfaces which encode
commands. It has no methods.

```
interface mixin GPUCommandsMixin ;
```

[`GPUCommandsMixin`](#gpucommandsmixin) has the following [device timeline
properties](#device-timeline-property):

[`[[state]]`], of type [encoder state](#encoder-state), initially \"[open](#encoder-state-open)\"

: The current state of the encoder.

[`[[commands]]`], of type [list](https://infra.spec.whatwg.org/#list)\<[GPU command](#gpu-command)\>, initially ``

: A [list](https://infra.spec.whatwg.org/#list) of [GPU
 commands](#gpu-command) to be
 executed on the [Queue
 timeline](#queue-timeline) when a
 [`GPUCommandBuffer`](#gpucommandbuffer) containing these commands is submitted.

[`[[used_bind_groups]]`], of type [set](https://infra.spec.whatwg.org/#ordered-set)\<[`GPUBindGroup`](#gpubindgroup)\>, initially empty;

: A
 [set](https://infra.spec.whatwg.org/#ordered-set) of all
 [`GPUBindGroup`](#gpubindgroup)s set with
 [setBindGroup()](#gpubindingcommandsmixin-setbindgroup) during command encoding.

The [encoder state] may be one of the following:

\"[open]\"

: The encoder is available to encode new commands.

\"[locked]\"

: The encoder cannot be used, because it is locked by a child encoder:
 it is a
 [`GPUCommandEncoder`](#gpucommandencoder), and a
 [`GPURenderPassEncoder`](#gpurenderpassencoder) or
 [`GPUComputePassEncoder`](#gpucomputepassencoder) is active. The encoder becomes
 \"[open](#encoder-state-open)\" again when the pass is ended.

 Any command issued in this state
 [invalidates](#abstract-opdef-invalidate) the encoder.

\"[ended]\"

: The encoder has been ended and new commands can no longer be
 encoded.

 Any command issued in this state will [generate a validation
 error](#abstract-opdef-generate-a-validation-error).

To [Validate the encoder
state] of
[`GPUCommandsMixin`](#gpucommandsmixin) `encoder` run the\
following [device timeline](#device-timeline) steps:

1. If
 `encoder`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) is:

 \"[open](#encoder-state-open)\"

 : Return `true`.

 \"[locked](#encoder-state-locked)\"

 : [Invalidate](#abstract-opdef-invalidate) `encoder` and return
 `false`.

 \"[ended](#encoder-state-ended)\"

 : [Generate a validation
 error](#abstract-opdef-generate-a-validation-error), and return `false`.

To [Enqueue a command] on
[`GPUCommandsMixin`](#gpucommandsmixin) `encoder` which issues the steps of a [GPU
Command](#gpu-command)
`command`, run the following [device
timeline](#device-timeline)
steps:

1. [Append](https://infra.spec.whatwg.org/#list-append) `command` to
 `encoder`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot).

2. When `command` is executed as part of a
 [`GPUCommandBuffer`](#gpucommandbuffer):

 1. Issue the steps of `command`.

### 13.2. `GPUCommandEncoder`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUCommandEncoder {
 GPURenderPassEncoder beginRenderPass(GPURenderPassDescriptor descriptor);
 GPUComputePassEncoder beginComputePass(optional GPUComputePassDescriptor descriptor = );

 undefined copyBufferToBuffer(
 GPUBuffer source,
 GPUBuffer destination,
 optional GPUSize64 size);
 undefined copyBufferToBuffer(
 GPUBuffer source,
 GPUSize64 sourceOffset,
 GPUBuffer destination,
 GPUSize64 destinationOffset,
 optional GPUSize64 size);

 undefined copyBufferToTexture(
 GPUTexelCopyBufferInfo source,
 GPUTexelCopyTextureInfo destination,
 GPUExtent3D copySize);

 undefined copyTextureToBuffer(
 GPUTexelCopyTextureInfo source,
 GPUTexelCopyBufferInfo destination,
 GPUExtent3D copySize);

 undefined copyTextureToTexture(
 GPUTexelCopyTextureInfo source,
 GPUTexelCopyTextureInfo destination,
 GPUExtent3D copySize);

 undefined clearBuffer(
 GPUBuffer buffer,
 optional GPUSize64 offset = 0,
 optional GPUSize64 size);

 undefined resolveQuerySet(
 GPUQuerySet querySet,
 GPUSize32 firstQuery,
 GPUSize32 queryCount,
 GPUBuffer destination,
 GPUSize64 destinationOffset);

 GPUCommandBuffer finish(optional GPUCommandBufferDescriptor descriptor = );
};
GPUCommandEncoder includes GPUObjectBase;
GPUCommandEncoder includes GPUCommandsMixin;
GPUCommandEncoder includes GPUDebugCommandsMixin;
```

#### 13.2.1. Command Encoder Creation

```
dictionary GPUCommandEncoderDescriptor
 : GPUObjectDescriptorBase ;
```

[`createCommandEncoder(descriptor)`]

: Creates a
 [`GPUCommandEncoder`](#gpucommandencoder).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) this.
 **Arguments:**

 Arguments for the
 [GPUDevice.createCommandEncoder(descriptor)](#dom-gpudevice-createcommandencoder) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUCommandEncoderDescriptor`](#dictdef-gpucommandencoderdescriptor)
 [✘]
 [✔]
 Description of the
 [`GPUCommandEncoder`](#gpucommandencoder) to create.
 **Returns:**
 [`GPUCommandEncoder`](#gpucommandencoder)

 [Content timeline](#content-timeline) steps:

 1. Let `e` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUCommandEncoder`](#gpucommandencoder), `descriptor`).

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `e`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `e` and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).
 :::
 :::
 :::::

Creating a
[`GPUCommandEncoder`](#gpucommandencoder), encoding a command to clear a buffer, finishing the
encoder to get a
[`GPUCommandBuffer`](#gpucommandbuffer), then submitting it to the
[`GPUQueue`](#gpuqueue).

``` highlight
const commandEncoder = gpuDevice.createCommandEncoder();
commandEncoder.clearBuffer(buffer);
const commandBuffer = commandEncoder.finish();
gpuDevice.queue.submit([commandBuffer]);
```

### 13.3. Pass Encoding

[`beginRenderPass(descriptor)`]

: Begins encoding a render pass described by `descriptor`.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the
 [GPUCommandEncoder.beginRenderPass(descriptor)](#dom-gpucommandencoder-beginrenderpass) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPURenderPassEncoder`](#gpurenderpassencoder) to create.
 **Returns:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder)

 [Content timeline](#content-timeline) steps:

 1. For each non-`null` `colorAttachment` in
 `descriptor`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments):

 1. If
 `colorAttachment`.[`clearValue`](#dom-gpurenderpasscolorattachment-clearvalue) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate
 GPUColor
 shape](#abstract-opdef-validate-gpucolor-shape)(`colorAttachment`.[`clearValue`](#dom-gpurenderpasscolorattachment-clearvalue)).

 2. Let `pass` be a new
 [`GPURenderPassEncoder`](#gpurenderpassencoder) object.

 3. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `pass`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false,
 [invalidate](#abstract-opdef-invalidate) `pass` and return.

 2. Set
 `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[locked](#encoder-state-locked)\".

 3. Let `attachmentRegions` be a
 [list](https://infra.spec.whatwg.org/#list) of \[[texture
 subresource](#texture-subresources),
 [`depthSlice`](#dom-gpurenderpasscolorattachment-depthslice)?\] pairs, initially empty. Each pair describes
 the region of the texture to be rendered to, which includes a
 single depth slice for
 [`"3d"`](#dom-gputextureviewdimension-3d) textures only.

 4. For each non-`null` `colorAttachment` in
 `descriptor`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments):

 1. Add
 \[`colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view),
 `colorAttachment`.[`depthSlice`](#dom-gpurenderpasscolorattachment-depthslice) ?? `null`\] to
 `attachmentRegions`.

 2. If
 `colorAttachment`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget) is not `null`:

 1. Add
 \[`colorAttachment`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget), `undefined`\] to
 `attachmentRegions`.

 5. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `pass` and return.

 ::: validusage
 - `descriptor` must meet the [Valid
 Usage](#abstract-opdef-gpurenderpassdescriptor-valid-usage) rules given device
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 - The set of texture regions in `attachmentRegions`
 must be pairwise disjoint. That is, no two texture regions may
 overlap.
 :::

 6. [Add](#abstract-opdef-usage-scope-add) each [texture
 subresource](#texture-subresources) in `attachmentRegions` to
 `pass`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [attachment](#internal-usage-attachment).

 7. Let `depthStencilAttachment` be
 `descriptor`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).

 8. If `depthStencilAttachment` is not `null`:

 1. Let `depthStencilView` be
 `depthStencilAttachment`.[`view`](#dom-gpurenderpassdepthstencilattachment-view).

 2. [Add](#abstract-opdef-usage-scope-add) the
 [depth](#aspect-depth)
 [subresource](#subresource) of `depthStencilView`, if any,
 to
 `pass`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [attachment-read](#internal-usage-attachment-read) if
 `depthStencilAttachment`.[`depthReadOnly`](#dom-gpurenderpassdepthstencilattachment-depthreadonly) is true, or
 [attachment](#internal-usage-attachment) otherwise.

 3. [Add](#abstract-opdef-usage-scope-add) the
 [stencil](#aspect-stencil)
 [subresource](#subresource) of `depthStencilView`, if any,
 to
 `pass`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [attachment-read](#internal-usage-attachment-read) if
 `depthStencilAttachment`.[`stencilReadOnly`](#dom-gpurenderpassdepthstencilattachment-stencilreadonly) is true, or
 [attachment](#internal-usage-attachment) otherwise.

 4. Set
 `pass`.[`[[depthReadOnly]]`](#dom-gpurendercommandsmixin-depthreadonly-slot) to
 `depthStencilAttachment`.[`depthReadOnly`](#dom-gpurenderpassdepthstencilattachment-depthreadonly).

 5. Set
 `pass`.[`[[stencilReadOnly]]`](#dom-gpurendercommandsmixin-stencilreadonly-slot) to
 `depthStencilAttachment`.[`stencilReadOnly`](#dom-gpurenderpassdepthstencilattachment-stencilreadonly).

 9. Set
 `pass`.[`[[layout]]`](#dom-gpurendercommandsmixin-layout-slot) to [derive render targets layout from
 pass](#abstract-opdef-derive-render-targets-layout-from-pass)(`descriptor`).

 10. If
 `descriptor`.[`timestampWrites`](#dom-gpurenderpassdescriptor-timestampwrites) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Let `timestampWrites` be
 `descriptor`.[`timestampWrites`](#dom-gpurenderpassdescriptor-timestampwrites).

 2. If
 `timestampWrites`.[`beginningOfPassWriteIndex`](#dom-gpurenderpasstimestampwrites-beginningofpasswriteindex) is
 [provided](https://infra.spec.whatwg.org/#map-exists),
 [append](https://infra.spec.whatwg.org/#list-append) a [GPU
 command](#gpu-command) to
 `this`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot) with the following steps:

 ::: {timeline="queue"}
 1. Before the pass commands begin executing, write the
 [current queue
 timestamp](#abstract-opdef-current-queue-timestamp) into index
 `timestampWrites`.[`beginningOfPassWriteIndex`](#dom-gpurenderpasstimestampwrites-beginningofpasswriteindex) of
 `timestampWrites`.[`querySet`](#dom-gpurenderpasstimestampwrites-queryset).
 :::

 3. If
 `timestampWrites`.[`endOfPassWriteIndex`](#dom-gpurenderpasstimestampwrites-endofpasswriteindex) is
 [provided](https://infra.spec.whatwg.org/#map-exists), set
 `pass`.[`[[endTimestampWrite]]`](#dom-gpurenderpassencoder-endtimestampwrite-slot) to a [GPU
 command](#gpu-command) with the following steps:

 ::: {timeline="queue"}
 1. After the pass commands finish executing, write the
 [current queue
 timestamp](#abstract-opdef-current-queue-timestamp) into index
 `timestampWrites`.[`endOfPassWriteIndex`](#dom-gpurenderpasstimestampwrites-endofpasswriteindex) of
 `timestampWrites`.[`querySet`](#dom-gpurenderpasstimestampwrites-queryset).
 :::

 11. Set
 `pass`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) to 0.

 12. Set
 `pass`.[`[[maxDrawCount]]`](#dom-gpurenderpassencoder-maxdrawcount-slot) to
 `descriptor`.[`maxDrawCount`](#dom-gpurenderpassdescriptor-maxdrawcount).

 13. Set
 `pass`.[`[[maxDrawCount]]`](#dom-gpurenderpassencoder-maxdrawcount-slot) to
 `descriptor`.[`maxDrawCount`](#dom-gpurenderpassdescriptor-maxdrawcount).

 14. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let the
 [`[[renderState]]`](#dom-gpucommandbuffer-renderstate-slot) of the currently executing
 [`GPUCommandBuffer`](#gpucommandbuffer) be a new
 [RenderState](#renderstate).

 2. Set
 [`[[renderState]]`](#dom-gpucommandbuffer-renderstate-slot).[`[[colorAttachments]]`](#dom-renderstate-colorattachments-slot) to
 `descriptor`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments).

 3. Set
 [`[[renderState]]`](#dom-gpucommandbuffer-renderstate-slot).[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot) to
 `descriptor`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).

 4. For each non-`null` `colorAttachment` in
 `descriptor`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments):

 1. Let `colorView` be
 `colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view).

 2. If
 `colorView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`dimension`](#dom-gputextureviewdescriptor-dimension) is:

 [`"3d"`](#dom-gputextureviewdimension-3d)

 : Let `colorSubregion` be
 `colorAttachment`.[`depthSlice`](#dom-gpurenderpasscolorattachment-depthslice) of `colorView`.

 Otherwise

 : Let `colorSubregion` be
 `colorView`.

 3. If
 `colorAttachment`.[`loadOp`](#dom-gpurenderpasscolorattachment-loadop) is:

 [`"load"`](#dom-gpuloadop-load)

 : Ensure the contents of `colorSubregion` are
 loaded into the [framebuffer
 memory](#framebuffer-memory) associated with
 `colorSubregion`.

 [`"clear"`](#dom-gpuloadop-clear)

 : Set every [texel](#texel-block) of the [framebuffer
 memory](#framebuffer-memory) associated with
 `colorSubregion` to
 `colorAttachment`.[`clearValue`](#dom-gpurenderpasscolorattachment-clearvalue).

 5. If `depthStencilAttachment` is not `null`:

 1. If
 `depthStencilAttachment`.[`depthLoadOp`](#dom-gpurenderpassdepthstencilattachment-depthloadop) is:

 Not [provided](https://infra.spec.whatwg.org/#map-exists)

 : [Assert](https://infra.spec.whatwg.org/#assert) that
 `depthStencilAttachment`.[`depthReadOnly`](#dom-gpurenderpassdepthstencilattachment-depthreadonly) is `true` and ensure the contents of
 the [depth](#aspect-depth)
 [subresource](#gputextureview-subresources) of `depthStencilView` are
 loaded into the [framebuffer
 memory](#framebuffer-memory) associated with
 `depthStencilView`.

 [`"load"`](#dom-gpuloadop-load)

 : Ensure the contents of the
 [depth](#aspect-depth)
 [subresource](#gputextureview-subresources) of `depthStencilView` are
 loaded into the [framebuffer
 memory](#framebuffer-memory) associated with
 `depthStencilView`.

 [`"clear"`](#dom-gpuloadop-clear)

 : Set every [texel](#texel-block) of the [framebuffer
 memory](#framebuffer-memory) associated with the
 [depth](#aspect-depth)
 [subresource](#gputextureview-subresources) of `depthStencilView` to
 `depthStencilAttachment`.[`depthClearValue`](#dom-gpurenderpassdepthstencilattachment-depthclearvalue).

 2. If
 `depthStencilAttachment`.[`stencilLoadOp`](#dom-gpurenderpassdepthstencilattachment-stencilloadop) is:

 Not [provided](https://infra.spec.whatwg.org/#map-exists)

 : [Assert](https://infra.spec.whatwg.org/#assert) that
 `depthStencilAttachment`.[`stencilReadOnly`](#dom-gpurenderpassdepthstencilattachment-stencilreadonly) is `true` and ensure the contents of
 the [stencil](#aspect-stencil)
 [subresource](#gputextureview-subresources) of `depthStencilView` are
 loaded into the [framebuffer
 memory](#framebuffer-memory) associated with
 `depthStencilView`.

 [`"load"`](#dom-gpuloadop-load)

 : Ensure the contents of the
 [stencil](#aspect-stencil)
 [subresource](#gputextureview-subresources) of `depthStencilView` are
 loaded into the [framebuffer
 memory](#framebuffer-memory) associated with
 `depthStencilView`.

 [`"clear"`](#dom-gpuloadop-clear)

 : Set every [texel](#texel-block) of the [framebuffer
 memory](#framebuffer-memory) associated with the
 [stencil](#aspect-stencil)
 [subresource](#gputextureview-subresources) `depthStencilView` to
 `depthStencilAttachment`.[`stencilClearValue`](#dom-gpurenderpassdepthstencilattachment-stencilclearvalue).

 [Read-only
 depth-stencil](#read-only-depth-stencil) attachments are implicitly treated as though the
 [`"load"`](#dom-gpuloadop-load) operation was used. Validation that requires the
 load op to not be provided for read-only attachments is done in
 [GPURenderPassDepthStencilAttachment Valid
 Usage](#abstract-opdef-gpurenderpassdepthstencilattachment-gpurenderpassdepthstencilattachment-valid-usage).
 :::
 ::::::

[`beginComputePass(descriptor)`]

: Begins encoding a compute pass described by `descriptor`.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the
 [GPUCommandEncoder.beginComputePass(descriptor)](#dom-gpucommandencoder-begincomputepass) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUComputePassDescriptor`](#dictdef-gpucomputepassdescriptor)
 [✘]
 [✔]
 **Returns:**
 [`GPUComputePassEncoder`](#gpucomputepassencoder)

 [Content timeline](#content-timeline) steps:

 1. Let `pass` be a new
 [`GPUComputePassEncoder`](#gpucomputepassencoder) object.

 2. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 3. Return `pass`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false,
 [invalidate](#abstract-opdef-invalidate) `pass` and return.

 2. Set
 `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[locked](#encoder-state-locked)\".

 3. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `pass` and return.

 ::: validusage
 - If
 `descriptor`.[`timestampWrites`](#dom-gpucomputepassdescriptor-timestampwrites) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - [Validate
 timestampWrites](#abstract-opdef-validate-timestampwrites)(`this`.[`[[device]]`](#dom-gpuobjectbase-device-slot),
 `descriptor`.[`timestampWrites`](#dom-gpucomputepassdescriptor-timestampwrites)) must return true.
 :::

 4. If
 `descriptor`.[`timestampWrites`](#dom-gpucomputepassdescriptor-timestampwrites) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Let `timestampWrites` be
 `descriptor`.[`timestampWrites`](#dom-gpucomputepassdescriptor-timestampwrites).

 2. If
 `timestampWrites`.[`beginningOfPassWriteIndex`](#dom-gpucomputepasstimestampwrites-beginningofpasswriteindex) is
 [provided](https://infra.spec.whatwg.org/#map-exists),
 [append](https://infra.spec.whatwg.org/#list-append) a [GPU
 command](#gpu-command) to
 `this`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot) with the following steps:

 ::: {timeline="queue"}
 1. Before the pass commands begin executing, write the
 [current queue
 timestamp](#abstract-opdef-current-queue-timestamp) into index
 `timestampWrites`.[`beginningOfPassWriteIndex`](#dom-gpucomputepasstimestampwrites-beginningofpasswriteindex) of
 `timestampWrites`.[`querySet`](#dom-gpucomputepasstimestampwrites-queryset).
 :::

 3. If
 `timestampWrites`.[`endOfPassWriteIndex`](#dom-gpucomputepasstimestampwrites-endofpasswriteindex) is
 [provided](https://infra.spec.whatwg.org/#map-exists), set
 `pass`.[`[[endTimestampWrite]]`](#dom-gpucomputepassencoder-endtimestampwrite-slot) to a [GPU
 command](#gpu-command) with the following steps:

 ::: {timeline="queue"}
 1. After the pass commands finish executing, write the
 [current queue
 timestamp](#abstract-opdef-current-queue-timestamp) into index
 `timestampWrites`.[`endOfPassWriteIndex`](#dom-gpucomputepasstimestampwrites-endofpasswriteindex) of
 `timestampWrites`.[`querySet`](#dom-gpucomputepasstimestampwrites-queryset).
 :::
 :::
 :::::

### 13.4. Buffer Copy Commands

[copyBufferToBuffer()] has
two overloads:

[`copyBufferToBuffer(source, destination, size)`]

: Shorthand, equivalent to
 [`copyBufferToBuffer(source, 0, destination, 0, size)`](#dom-gpucommandencoder-copybuffertobuffer-source-sourceoffset-destination-destinationoffset-size).

[`copyBufferToBuffer(source, sourceOffset, destination, destinationOffset, size)`]

: Encode a command into the
 [`GPUCommandEncoder`](#gpucommandencoder) that copies data from a sub-region of a
 [`GPUBuffer`](#gpubuffer) to a sub-region of another
 [`GPUBuffer`](#gpubuffer).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the [GPUCommandEncoder.copyBufferToBuffer(source,
 sourceOffset, destination, destinationOffset,
 size)](#dom-gpucommandencoder-copybuffertobuffer-source-sourceoffset-destination-destinationoffset-size) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`source`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 The [`GPUBuffer`](#gpubuffer) to copy from.
 [`sourceOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in bytes into `source` to begin copying from.
 [`destination`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 The [`GPUBuffer`](#gpubuffer) to copy to.
 [`destinationOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in bytes into `destination` to place the copied
 data.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Bytes to copy.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If `size` is `undefined`, set it to
 `source`.[`size`](#dom-gpubuffer-size) − `sourceOffset`.

 3. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `source` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `destination` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `source`.[`usage`](#dom-gpubuffer-usage) contains
 [`COPY_SRC`](#dom-gpubufferusage-copy_src).

 - `destination`.[`usage`](#dom-gpubuffer-usage) contains
 [`COPY_DST`](#dom-gpubufferusage-copy_dst).

 - `size` is a multiple of 4.

 - `sourceOffset` is a multiple of 4.

 - `destinationOffset` is a multiple of 4.

 - `source`.[`size`](#dom-gpubuffer-size) ≥ (`sourceOffset` +
 `size`).

 - `destination`.[`size`](#dom-gpubuffer-size) ≥ (`destinationOffset` +
 `size`).

 - `source` and `destination` are not the
 same [`GPUBuffer`](#gpubuffer).
 :::

 4. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Copy `size` bytes of `source`, beginning
 at `sourceOffset`, into `destination`,
 beginning at `destinationOffset`.
 :::
 ::::::

<!-- -->

[`clearBuffer(buffer, offset, size)`]

: Encode a command into the
 [`GPUCommandEncoder`](#gpucommandencoder) that fills a sub-region of a
 [`GPUBuffer`](#gpubuffer) with zeros.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the [GPUCommandEncoder.clearBuffer(buffer, offset,
 size)](#dom-gpucommandencoder-clearbuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`buffer`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 The [`GPUBuffer`](#gpubuffer) to clear.
 [`offset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Offset in bytes into `buffer` where the sub-region to
 clear begins.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Size in bytes of the sub-region to clear. Defaults to the size of
 the buffer minus `offset`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If `size` is missing, set `size` to
 `max(0, ``buffer``.`[`size`](#dom-gpubuffer-size)` - ``offset``)`.

 3. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `buffer` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `buffer`.[`usage`](#dom-gpubuffer-usage) contains
 [`COPY_DST`](#dom-gpubufferusage-copy_dst).

 - `size` is a multiple of 4.

 - `offset` is a multiple of 4.

 - `buffer`.[`size`](#dom-gpubuffer-size) ≥ (`offset` + `size`).
 :::

 4. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Set `size` bytes of `buffer` to `0`
 starting at `offset`.
 :::
 ::::::

### 13.5. Texel Copy Commands

[`copyBufferToTexture(source, destination, copySize)`]

: Encode a command into the
 [`GPUCommandEncoder`](#gpucommandencoder) that copies data from a sub-region of a
 [`GPUBuffer`](#gpubuffer) to a sub-region of one or multiple continuous
 [texture
 subresources](#texture-subresources).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the [GPUCommandEncoder.copyBufferToTexture(source,
 destination,
 copySize)](#dom-gpucommandencoder-copybuffertotexture) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`source`]
 [`GPUTexelCopyBufferInfo`](#gputexelcopybufferinfo)
 [✘]
 [✘]
 Combined with `copySize`, defines the region of the
 source buffer.
 [`destination`]
 [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo)
 [✘]
 [✘]
 Combined with `copySize`, defines the region of the
 destination [texture
 subresource](#texture-subresources).
 [`copySize`]
 [`GPUExtent3D`](#typedefdef-gpuextent3d)
 [✘]
 [✘]
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin3D
 shape](#abstract-opdef-validate-gpuorigin3d-shape)(`destination`.[`origin`](#dom-gputexelcopytextureinfo-origin)).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUExtent3D
 shape](#abstract-opdef-validate-gpuextent3d-shape)(`copySize`).

 3. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot):
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `aligned` be `true`.

 3. Let `dataLength` be
 `source`.[`buffer`](#dom-gputexelcopybufferinfo-buffer).[`size`](#dom-gpubuffer-size).

 4. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - [validating
 GPUTexelCopyBufferInfo](#abstract-opdef-validating-gputexelcopybufferinfo)(`source`) returns `true`.

 - `source`.[`buffer`](#dom-gputexelcopybufferinfo-buffer).[`usage`](#dom-gpubuffer-usage) contains
 [`COPY_SRC`](#dom-gpubufferusage-copy_src).

 - [validating texture buffer
 copy](#abstract-opdef-validating-texture-buffer-copy)(`destination`,
 `source`, `dataLength`,
 `copySize`,
 [`COPY_DST`](#dom-gputextureusage-copy_dst), `aligned`) returns `true`.
 :::

 5. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `blockWidth` be the [texel block
 width](#texel-block-width) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Let `blockHeight` be the [texel block
 height](#texel-block-height) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 3. Let `dstOrigin` be
 `destination`.[`origin`](#dom-gputexelcopytextureinfo-origin).

 4. Let `dstBlockOriginX` be
 (`dstOrigin`.[x](#gpuorigin3d-x) ÷ `blockWidth`).

 5. Let `dstBlockOriginY` be
 (`dstOrigin`.[y](#gpuorigin3d-y) ÷ `blockHeight`).

 6. Let `blockColumns` be
 (`copySize`.[width](#gpuextent3d-width) ÷ `blockWidth`).

 7. Let `blockRows` be
 (`copySize`.[height](#gpuextent3d-height) ÷ `blockHeight`).

 8. [Assert](https://infra.spec.whatwg.org/#assert) that `dstBlockOriginX`,
 `dstBlockOriginY`, `blockColumns`, and
 `blockRows` are integers.

 9. For each `z` in the range \[0,
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) − 1\]:

 1. Let `dstSubregion` be [texture copy
 sub-region](#abstract-opdef-texture-copy-sub-region) (`z` +
 `dstOrigin`.[z](#gpuorigin3d-z)) of `destination`.

 2. For each `y` in the range \[0,
 `blockRows` − 1\]:

 1. For each `x` in the range \[0,
 `blockColumns` − 1\]:

 1. Let `blockOffset` be the [texel block
 byte
 offset](#abstract-opdef-texel-block-byte-offset) of `source` for
 (`x`, `y`, `z`) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Set [texel
 block](#texel-block) (`dstBlockOriginX` +
 `x`, `dstBlockOriginY` +
 `y`) of `dstSubregion` to be
 an [equivalent texel
 representation](#equivalent-texel-representation) to the [texel
 block](#texel-block) described by
 `source`.[`buffer`](#dom-gputexelcopybufferinfo-buffer) at offset `blockOffset`.
 :::
 ::::::

[`copyTextureToBuffer(source, destination, copySize)`]

: Encode a command into the
 [`GPUCommandEncoder`](#gpucommandencoder) that copies data from a sub-region of one or
 multiple continuous [texture
 subresources](#texture-subresources) to a sub-region of a
 [`GPUBuffer`](#gpubuffer).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the [GPUCommandEncoder.copyTextureToBuffer(source,
 destination,
 copySize)](#dom-gpucommandencoder-copytexturetobuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`source`]
 [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo)
 [✘]
 [✘]
 Combined with `copySize`, defines the region of the
 source [texture
 subresources](#texture-subresources).
 [`destination`]
 [`GPUTexelCopyBufferInfo`](#gputexelcopybufferinfo)
 [✘]
 [✘]
 Combined with `copySize`, defines the region of the
 destination buffer.
 [`copySize`]
 [`GPUExtent3D`](#typedefdef-gpuextent3d)
 [✘]
 [✘]
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin3D
 shape](#abstract-opdef-validate-gpuorigin3d-shape)(`source`.[`origin`](#dom-gputexelcopytextureinfo-origin)).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUExtent3D
 shape](#abstract-opdef-validate-gpuextent3d-shape)(`copySize`).

 3. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot):
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `aligned` be `true`.

 3. Let `dataLength` be
 `destination`.[`buffer`](#dom-gputexelcopybufferinfo-buffer).[`size`](#dom-gpubuffer-size).

 4. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - [validating
 GPUTexelCopyBufferInfo](#abstract-opdef-validating-gputexelcopybufferinfo)(`destination`) returns
 `true`.

 - `destination`.[`buffer`](#dom-gputexelcopybufferinfo-buffer).[`usage`](#dom-gpubuffer-usage) contains
 [`COPY_DST`](#dom-gpubufferusage-copy_dst).

 - [validating texture buffer
 copy](#abstract-opdef-validating-texture-buffer-copy)(`source`,
 `destination`, `dataLength`,
 `copySize`,
 [`COPY_SRC`](#dom-gputextureusage-copy_src), `aligned`) returns `true`.

 - ::: compatmode
 If
 device.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format) must not be a [compressed
 format](#compressed-format).
 :::
 :::

 5. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `blockWidth` be the [texel block
 width](#texel-block-width) of
 `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Let `blockHeight` be the [texel block
 height](#texel-block-height) of
 `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 3. Let `srcOrigin` be
 `source`.[`origin`](#dom-gputexelcopytextureinfo-origin).

 4. Let `srcBlockOriginX` be
 (`srcOrigin`.[x](#gpuorigin3d-x) ÷ `blockWidth`).

 5. Let `srcBlockOriginY` be
 (`srcOrigin`.[y](#gpuorigin3d-y) ÷ `blockHeight`).

 6. Let `blockColumns` be
 (`copySize`.[width](#gpuextent3d-width) ÷ `blockWidth`).

 7. Let `blockRows` be
 (`copySize`.[height](#gpuextent3d-height) ÷ `blockHeight`).

 8. [Assert](https://infra.spec.whatwg.org/#assert) that `srcBlockOriginX`,
 `srcBlockOriginY`, `blockColumns`, and
 `blockRows` are integers.

 9. For each `z` in the range \[0,
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) − 1\]:

 1. Let `srcSubregion` be [texture copy
 sub-region](#abstract-opdef-texture-copy-sub-region) (`z` +
 `srcOrigin`.[z](#gpuorigin3d-z)) of `source`.

 2. For each `y` in the range \[0,
 `blockRows` − 1\]:

 1. For each `x` in the range \[0,
 `blockColumns` − 1\]:

 1. Let `blockOffset` be the [texel block
 byte
 offset](#abstract-opdef-texel-block-byte-offset) of `destination`
 for (`x`, `y`, `z`)
 of
 `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Set
 `destination`.[`buffer`](#dom-gputexelcopybufferinfo-buffer) at offset `blockOffset`
 to be an [equivalent texel
 representation](#equivalent-texel-representation) to [texel
 block](#texel-block) (`srcBlockOriginX` +
 `x`, `srcBlockOriginY` +
 `y`) of `srcSubregion`.
 :::
 ::::::

[`copyTextureToTexture(source, destination, copySize)`]

: Encode a command into the
 [`GPUCommandEncoder`](#gpucommandencoder) that copies data from a sub-region of one or
 multiple contiguous [texture
 subresources](#texture-subresources) to another sub-region of one or multiple continuous
 [texture
 subresources](#texture-subresources).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the [GPUCommandEncoder.copyTextureToTexture(source,
 destination,
 copySize)](#dom-gpucommandencoder-copytexturetotexture) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`source`]
 [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo)
 [✘]
 [✘]
 Combined with `copySize`, defines the region of the
 source [texture
 subresources](#texture-subresources).
 [`destination`]
 [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo)
 [✘]
 [✘]
 Combined with `copySize`, defines the region of the
 destination [texture
 subresources](#texture-subresources).
 [`copySize`]
 [`GPUExtent3D`](#typedefdef-gpuextent3d)
 [✘]
 [✘]
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin3D
 shape](#abstract-opdef-validate-gpuorigin3d-shape)(`source`.[`origin`](#dom-gputexelcopytextureinfo-origin)).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin3D
 shape](#abstract-opdef-validate-gpuorigin3d-shape)(`destination`.[`origin`](#dom-gputexelcopytextureinfo-origin)).

 3. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUExtent3D
 shape](#abstract-opdef-validate-gpuextent3d-shape)(`copySize`).

 4. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot):
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - Let `srcTexture` be
 `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 - Let `dstTexture` be
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 - [validating
 GPUTexelCopyTextureInfo](#abstract-opdef-validating-gputexelcopytextureinfo)(`source`,
 `copySize`) returns `true`.

 - `srcTexture`.[`usage`](#dom-gputexture-usage) contains
 [`COPY_SRC`](#dom-gputextureusage-copy_src).

 - [validating
 GPUTexelCopyTextureInfo](#abstract-opdef-validating-gputexelcopytextureinfo)(`destination`,
 `copySize`) returns `true`.

 - `dstTexture`.[`usage`](#dom-gputexture-usage) contains
 [`COPY_DST`](#dom-gputextureusage-copy_dst).

 - `srcTexture`.[`sampleCount`](#dom-gputexture-samplecount) is equal to
 `dstTexture`.[`sampleCount`](#dom-gputexture-samplecount).

 - `srcTexture`.[`format`](#dom-gputexture-format) and
 `dstTexture`.[`format`](#dom-gputexture-format) must be
 [copy-compatible](#copy-compatible).

 - If
 `srcTexture`.[`format`](#dom-gputexture-format) is a depth-stencil format:

 - `source`.[`aspect`](#dom-gputexelcopytextureinfo-aspect) and
 `destination`.[`aspect`](#dom-gputexelcopytextureinfo-aspect) must both refer to all aspects of
 `srcTexture`.[`format`](#dom-gputexture-format) and
 `dstTexture`.[`format`](#dom-gputexture-format), respectively.

 - The [set of subresources for texture
 copy](#abstract-opdef-set-of-subresources-for-texture-copy)(`source`,
 `copySize`) and the [set of subresources for
 texture
 copy](#abstract-opdef-set-of-subresources-for-texture-copy)(`destination`,
 `copySize`) are disjoint.

 - ::: compatmode
 If
 device.[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format) must not be a [compressed
 format](#compressed-format).

 - `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`format`](#dom-gputexture-format) must not be a [compressed
 format](#compressed-format).

 - `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`sampleCount`](#dom-gputexture-samplecount) and
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`sampleCount`](#dom-gputexture-samplecount) must be 1.
 :::
 :::

 3. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `blockWidth` be the [texel block
 width](#texel-block-width) of
 `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Let `blockHeight` be the [texel block
 height](#texel-block-height) of
 `source`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 3. Let `srcOrigin` be
 `source`.[`origin`](#dom-gputexelcopytextureinfo-origin).

 4. Let `srcBlockOriginX` be
 (`srcOrigin`.[x](#gpuorigin3d-x) ÷ `blockWidth`).

 5. Let `srcBlockOriginY` be
 (`srcOrigin`.[y](#gpuorigin3d-y) ÷ `blockHeight`).

 6. Let `dstOrigin` be
 `destination`.[`origin`](#dom-gputexelcopytextureinfo-origin).

 7. Let `dstBlockOriginX` be
 (`dstOrigin`.[x](#gpuorigin3d-x) ÷ `blockWidth`).

 8. Let `dstBlockOriginY` be
 (`dstOrigin`.[y](#gpuorigin3d-y) ÷ `blockHeight`).

 9. Let `blockColumns` be
 (`copySize`.[width](#gpuextent3d-width) ÷ `blockWidth`).

 10. Let `blockRows` be
 (`copySize`.[height](#gpuextent3d-height) ÷ `blockHeight`).

 11. [Assert](https://infra.spec.whatwg.org/#assert) that `srcBlockOriginX`,
 `srcBlockOriginY`, `dstBlockOriginX`,
 `dstBlockOriginY`, `blockColumns`, and
 `blockRows` are integers.

 12. For each `z` in the range \[0,
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) − 1\]:

 1. Let `srcSubregion` be [texture copy
 sub-region](#abstract-opdef-texture-copy-sub-region) (`z` +
 `srcOrigin`.[z](#gpuorigin3d-z)) of `source`.

 2. Let `dstSubregion` be [texture copy
 sub-region](#abstract-opdef-texture-copy-sub-region) (`z` +
 `dstOrigin`.[z](#gpuorigin3d-z)) of `destination`.

 3. For each `y` in the range \[0,
 `blockRows` − 1\]:

 1. For each `x` in the range \[0,
 `blockColumns` − 1\]:

 1. Set [texel
 block](#texel-block) (`dstBlockOriginX` +
 `x`, `dstBlockOriginY` +
 `y`) of `dstSubregion` to be
 an [equivalent texel
 representation](#equivalent-texel-representation) to [texel
 block](#texel-block) (`srcBlockOriginX` +
 `x`, `srcBlockOriginY` +
 `y`) of `srcSubregion`.
 :::
 ::::::

### 13.6. Queries

[`resolveQuerySet(querySet, firstQuery, queryCount, destination, destinationOffset)`]

: Resolves query results from a
 [`GPUQuerySet`](#gpuqueryset) out into a range of a
 [`GPUBuffer`](#gpubuffer).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) this.
 **Arguments:**

 Arguments for the [GPUCommandEncoder.resolveQuerySet(querySet,
 firstQuery, queryCount, destination,
 destinationOffset)](#dom-gpucommandencoder-resolvequeryset) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`querySet`]
 [`GPUQuerySet`](#gpuqueryset)
 [✘]
 [✘]
 [`firstQuery`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 [`queryCount`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 [`destination`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 [`destinationOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `querySet` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `destination` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `destination`.[`usage`](#dom-gpubuffer-usage) contains
 [`QUERY_RESOLVE`](#dom-gpubufferusage-query_resolve).

 - `firstQuery` \< the number of queries in
 `querySet`.

 - (`firstQuery` + `queryCount`) ≤ the
 number of queries in `querySet`.

 - `destinationOffset` is a multiple of 256.

 - `destinationOffset` + 8 × `queryCount` ≤
 `destination`.[`size`](#dom-gpubuffer-size).
 :::

 3. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `queryIndex` be `firstQuery`.

 2. Let `offset` be `destinationOffset`.

 3. While `queryIndex` \< `firstQuery` +
 `queryCount`:

 1. Set 8 bytes of `destination`, beginning at
 `offset`, to be the value of
 `querySet` at `queryIndex`.

 2. Set `queryIndex` to be `queryIndex` +
 1.

 3. Set `offset` to be `offset` + 8.
 :::
 ::::::

### 13.7. Finalization

A
[`GPUCommandBuffer`](#gpucommandbuffer) containing the commands recorded by the
[`GPUCommandEncoder`](#gpucommandencoder) can be created by calling
[`finish()`](#dom-gpucommandencoder-finish). Once
[`finish()`](#dom-gpucommandencoder-finish) has been called the command encoder can no longer be
used.

[`finish(descriptor)`]

: Completes recording of the commands sequence and returns a
 corresponding
 [`GPUCommandBuffer`](#gpucommandbuffer).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCommandEncoder`](#gpucommandencoder) `this`.
 **Arguments:**

 Arguments for the
 [GPUCommandEncoder.finish(descriptor)](#dom-gpucommandencoder-finish) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUCommandBufferDescriptor`](#dictdef-gpucommandbufferdescriptor)
 [✘]
 [✔]
 **Returns:**
 [`GPUCommandBuffer`](#gpucommandbuffer)

 [Content timeline](#content-timeline) steps:

 1. Let `commandBuffer` be a new
 [`GPUCommandBuffer`](#gpucommandbuffer).

 2. Issue the `finish steps` on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 3. Return `commandBuffer`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `finish steps`:
 1. Let `validationSucceeded` be `true` if all of the
 following requirements are met, and `false` otherwise.

 ::: validusage
 - `this` must be
 [valid](#abstract-opdef-valid).

 - `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) must be
 \"[open](#encoder-state-open)\".

 - `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot) must [be
 empty](https://infra.spec.whatwg.org/#list-is-empty).
 :::

 2. Set
 `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[ended](#encoder-state-ended)\".

 3. If `validationSucceeded` is `false`, then:

 1. [Generate a validation
 error](#abstract-opdef-generate-a-validation-error).

 2. Return an
 [invalidated](#abstract-opdef-invalidate)
 [`GPUCommandBuffer`](#gpucommandbuffer).

 4. Set
 `commandBuffer`.[`[[command_list]]`](#dom-gpucommandbuffer-command_list-slot) to
 `this`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot).

 5. Set
 `commandBuffer`.[`[[used_bind_groups]]`](#dom-gpucommandbuffer-used_bind_groups-slot) to
 `this`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot).
 :::
 :::::

## 14. Programmable Passes

```
interface mixin GPUBindingCommandsMixin {
 undefined setBindGroup(GPUIndex32 index, GPUBindGroup? bindGroup,
 optional sequence<GPUBufferDynamicOffset> dynamicOffsets = );

 undefined setBindGroup(GPUIndex32 index, GPUBindGroup? bindGroup,
 [AllowShared] Uint32Array dynamicOffsetsData,
 GPUSize64 dynamicOffsetsDataStart,
 GPUSize32 dynamicOffsetsDataLength);
};
```

[`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) assumes the presence of
[`GPUObjectBase`](#gpuobjectbase) and
[`GPUCommandsMixin`](#gpucommandsmixin) members on the same object. It must only be included by
interfaces which also include those mixins.

[`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) has the following [device timeline
properties](#device-timeline-property):

[`[[bind_groups]]`], of type [ordered map](https://infra.spec.whatwg.org/#ordered-map)\<[`GPUIndex32`](#typedefdef-gpuindex32), [`GPUBindGroup`](#gpubindgroup)\>, initially empty

: The current
 [`GPUBindGroup`](#gpubindgroup) for each index.

[`[[dynamic_offsets]]`], of type [ordered map](https://infra.spec.whatwg.org/#ordered-map)\<[`GPUIndex32`](#typedefdef-gpuindex32), [list](https://infra.spec.whatwg.org/#list)\<[`GPUBufferDynamicOffset`](#typedefdef-gpubufferdynamicoffset)\>\>, initally empty

: The current dynamic offsets for each
 [`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot) entry.

### 14.1. Bind Groups

[setBindGroup()] has two
overloads:

[`setBindGroup(index, bindGroup, dynamicOffsets)`]

: Sets the current
 [`GPUBindGroup`](#gpubindgroup) for the given index.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) this.
 **Arguments:**

 [`index`], of type [`GPUIndex32`](#typedefdef-gpuindex32), non-nullable, required

 : The index to set the bind group at.

 [`bindGroup`], of type [`GPUBindGroup`](#gpubindgroup), nullable, required

 : Bind group to use for subsequent render or compute commands.

 [`dynamicOffsets`], of type [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPUBufferDynamicOffset`](#typedefdef-gpubufferdynamicoffset)\>, non-nullable, defaulting to ``

 : Array containing buffer offsets in bytes for each entry in
 `bindGroup` marked as
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset), ordered by
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry).[`binding`](#dom-gpubindgrouplayoutentry-binding). See [note](#dynamicOffsetOrder) for additional
 details.

 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `dynamicOffsetCount` be 0 if `bindGroup` is
 `null`, or
 `bindGroup`.[`[[layout]]`](#dom-gpubindgroup-layout-slot).[`[[dynamicOffsetCount]]`](#dom-gpubindgrouplayout-dynamicoffsetcount-slot) if not.

 3. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `index` must be \<
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxBindGroups`](#dom-supported-limits-maxbindgroups).

 - `dynamicOffsets`.[size](https://infra.spec.whatwg.org/#list-size) must equal `dynamicOffsetCount`.
 :::

 4. If `bindGroup` is `null`:

 1. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `this`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)\[`index`\].

 2. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `this`.[`[[dynamic_offsets]]`](#dom-gpubindingcommandsmixin-dynamic_offsets-slot)\[`index`\].

 Otherwise:

 1. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `bindGroup` must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - [For each dynamic
 binding](#abstract-opdef-iterate-over-each-dynamic-binding-offset) (`bufferBinding`,
 `bufferLayout`,
 `dynamicOffsetIndex`) in
 `bindGroup`:

 - `bufferBinding`.[`offset`](#dom-gpubufferbinding-offset) +
 `dynamicOffsets`\[`dynamicOffsetIndex`\] +
 `bufferLayout`.[`minBindingSize`](#dom-gpubufferbindinglayout-minbindingsize) must be ≤
 `bufferBinding`.[`buffer`](#dom-gpubufferbinding-buffer).[`size`](#dom-gpubuffer-size).

 - If
 `bufferLayout`.[`type`](#dom-gpubufferbindinglayout-type) is
 [`"uniform"`](#dom-gpubufferbindingtype-uniform):

 - `dynamicOffset` must be a multiple of
 [`minUniformBufferOffsetAlignment`](#dom-supported-limits-minuniformbufferoffsetalignment).

 - If
 `bufferLayout`.[`type`](#dom-gpubufferbindinglayout-type) is
 [`"storage"`](#dom-gpubufferbindingtype-storage) or
 [`"read-only-storage"`](#dom-gpubufferbindingtype-read-only-storage):

 - `dynamicOffset` must be a multiple of
 [`minStorageBufferOffsetAlignment`](#dom-supported-limits-minstoragebufferoffsetalignment).
 :::

 2. Set
 `this`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)\[`index`\] to be
 `bindGroup`.

 3. Set
 `this`.[`[[dynamic_offsets]]`](#dom-gpubindingcommandsmixin-dynamic_offsets-slot)\[`index`\] to be a copy of
 `dynamicOffsets`.

 4. [Append](https://infra.spec.whatwg.org/#set-append) `bindGroup` to
 `this`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot).

 5. If `this` is a
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin):

 1. For each `bindGroup` in
 `this`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot),
 [merge](#abstract-opdef-usage-scope-merge)
 `bindGroup`.[`[[usedResources]]`](#dom-gpubindgroup-usedresources-slot) into
 `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot)
 :::
 :::::

[`setBindGroup(index, bindGroup, dynamicOffsetsData, dynamicOffsetsDataStart, dynamicOffsetsDataLength)`]

: Sets the current
 [`GPUBindGroup`](#gpubindgroup) for the given index, specifying dynamic offsets as
 a subset of a
 [`Uint32Array`](https://webidl.spec.whatwg.org/#idl-Uint32Array).

 ::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) `this`.
 **Arguments:**

 Arguments for the [GPUBindingCommandsMixin.setBindGroup(index,
 bindGroup, dynamicOffsetsData, dynamicOffsetsDataStart,
 dynamicOffsetsDataLength)](#dom-gpubindingcommandsmixin-setbindgroup-index-bindgroup-dynamicoffsetsdata-dynamicoffsetsdatastart-dynamicoffsetsdatalength) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`index`]
 [`GPUIndex32`](#typedefdef-gpuindex32)
 [✘]
 [✘]
 The index to set the bind group at.
 [`bindGroup`]
 [`GPUBindGroup`](#gpubindgroup)`?`
 [✔]
 [✘]
 Bind group to use for subsequent render or compute commands.
 [`dynamicOffsetsData`]
 [`Uint32Array`](https://webidl.spec.whatwg.org/#idl-Uint32Array)
 [✘]
 [✘]
 Array containing buffer offsets in bytes for each entry in
 `bindGroup` marked as
 [`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset), ordered by
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry).[`binding`](#dom-gpubindgrouplayoutentry-binding). See [note](#dynamicOffsetOrder) for additional
 details.
 [`dynamicOffsetsDataStart`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in elements into `dynamicOffsetsData` where the
 buffer offset data begins.
 [`dynamicOffsetsDataLength`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 Number of buffer offsets to read from
 `dynamicOffsetsData`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. If any of the following requirements are unmet, throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) and return.

 ::: validusage
 - `dynamicOffsetsDataStart` must be ≥ 0.

 - `dynamicOffsetsDataStart` +
 `dynamicOffsetsDataLength` must be ≤
 `dynamicOffsetsData`.`length`.
 :::

 2. Let `dynamicOffsets` be a
 [list](https://infra.spec.whatwg.org/#list) containing the range, starting at index
 `dynamicOffsetsDataStart`, of
 `dynamicOffsetsDataLength` elements of [a copy
 of](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `dynamicOffsetsData`.

 3. Call
 `this`.[`setBindGroup`](#dom-gpubindingcommandsmixin-setbindgroup)(`index`, `bindGroup`,
 `dynamicOffsets`).
 :::
 ::::

NOTE:

Dynamic offset are applied in
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry).[`binding`](#dom-gpubindgrouplayoutentry-binding) order.

This means that if `dynamic bindings` is the list of each
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) in the
[`GPUBindGroupLayout`](#gpubindgrouplayout) with
[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset) set to `true`, sorted by
[`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry).[`binding`](#dom-gpubindgrouplayoutentry-binding), then `dynamic offset[i]`, as supplied to
[setBindGroup()](#gpubindingcommandsmixin-setbindgroup), will correspond to `dynamic bindings[i]`.

For a
[`GPUBindGroupLayout`](#gpubindgrouplayout) created with the following call:

``` highlight
// Note the bindings are listed out-of-order in this array, but it
// doesn’t matter because they will be sorted by binding index.
let layout = gpuDevice.createBindGroupLayout({
 entries: [{
 binding: 1,
 buffer: ,
 }, {
 binding: 2,
 buffer: { dynamicOffset: true },
 }, {
 binding: 0,
 buffer: { dynamicOffset: true },
 }]
});
```

Used by a [`GPUBindGroup`](#gpubindgroup) created with the following call:

``` highlight
// Like above, the array order doesn’t matter here.
// It doesn’t even need to match the order used in the layout.
let bindGroup = gpuDevice.createBindGroup({
 layout: layout,
 entries: [{
 binding: 1,
 resource: { buffer: bufferA, offset: 256 },
 }, {
 binding: 2,
 resource: { buffer: bufferB, offset: 512 },
 }, {
 binding: 0,
 resource: { buffer: bufferC },
 }]
});
```

And bound with the following call:

``` highlight
pass.setBindGroup(0, bindGroup, [1024, 2048]);
```

The following buffer offsets will be applied:

Binding

Buffer

Offset

0

bufferC

1024 (Dynamic)

1

bufferA

256 (Static)

2

bufferB

2560 (Static + Dynamic)

To [Iterate over each dynamic binding
offset] in a given
[`GPUBindGroup`](#gpubindgroup) `bindGroup` with a given list of
`steps` to be executed for each dynamic offset, run the
following [device
timeline](#device-timeline)
steps:

1. Let `dynamicOffsetIndex` be `0`.

2. Let `layout` be
 `bindGroup`.[`[[layout]]`](#dom-gpubindgroup-layout-slot).

3. For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `entry` in
 `bindGroup`.[`[[entries]]`](#dom-gpubindgroup-entries-slot) ordered in increasing values of
 `entry`.[`binding`](#dom-gpubindgroupentry-binding):

 1. Let `bindingDescriptor` be the
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) at
 `layout`.[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot)\[`entry`.[`binding`](#dom-gpubindgroupentry-binding)\]:

 2. If
 `bindingDescriptor`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer)?.[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset) is `true`:

 1. Let `bufferBinding` be [get as buffer
 binding](#abstract-opdef-get-as-buffer-binding)(`entry`.[`resource`](#dom-gpubindgroupentry-resource)).

 2. Let `bufferLayout` be
 `bindingDescriptor`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).

 3. Call `steps` with `bufferBinding`,
 `bufferLayout`, and
 `dynamicOffsetIndex`.

 4. Let `dynamicOffsetIndex` be
 `dynamicOffsetIndex` + `1`

[Validate encoder bind
groups](encoder, pipeline)

**Arguments:**

[`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) `encoder`

: Encoder whose bind groups are being validated.

[`GPUPipelineBase`](#gpupipelinebase) `pipeline`

: Pipeline to validate `encoder`s bind groups are
 compatible with.

[Device timeline](#device-timeline) steps:

1. If any of the following conditions are unsatisfied, return `false`:

 ::: validusage
 - Let `bindGroupLayouts` be
 `pipeline`.[`[[layout]]`](#dom-gpupipelinebase-layout-slot).[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot).

 - `pipeline` must not be `null`.

 - All bind groups used by the pipeline must be set and compatible
 with the pipeline layout, determined as follows:

 For each pair of
 ([`GPUIndex32`](#typedefdef-gpuindex32) `index`,
 [`GPUBindGroupLayout`](#gpubindgrouplayout) `bindGroupLayout`) in
 `bindGroupLayouts`:

 - If `bindGroupLayout` is `null`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - Let `bindGroup` be
 `encoder`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)\[`index`\].

 - Let `dynamicOffsets` be
 `encoder`.[`[[dynamic_offsets]]`](#dom-gpubindingcommandsmixin-dynamic_offsets-slot)\[`index`\].

 - `bindGroup` must not be `null`.

 - `bindGroup`.[`[[layout]]`](#dom-gpubindgroup-layout-slot) must be
 [group-equivalent](#group-equivalent) with `bindGroupLayout`.

 - Let `dynamicOffsetIndex` be 0.

 - For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindGroupEntry` in
 `bindGroup`.[`[[entries]]`](#dom-gpubindgroup-entries-slot), sorted by
 `bindGroupEntry`.[`binding`](#dom-gpubindgroupentry-binding):

 - Let `bindGroupLayoutEntry` be
 `bindGroup`.[`[[layout]]`](#dom-gpubindgroup-layout-slot).[`[[entryMap]]`](#dom-gpubindgrouplayout-entrymap-slot)\[`bindGroupEntry`.[`binding`](#dom-gpubindgroupentry-binding)\].

 - If
 `bindGroupLayoutEntry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer) is not
 [provided](https://infra.spec.whatwg.org/#map-exists), **continue**.

 - Let `bound` be [get as buffer
 binding](#abstract-opdef-get-as-buffer-binding)(`bindGroupEntry`.[`resource`](#dom-gpubindgroupentry-resource)).

 - If
 `bindGroupLayoutEntry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`hasDynamicOffset`](#dom-gpubufferbindinglayout-hasdynamicoffset):

 - Increment
 `bound`.[`offset`](#dom-gpubufferbinding-offset) by
 `dynamicOffsets`\[`dynamicOffsetIndex`\].

 - Increment `dynamicOffsetIndex` by 1.

 - If
 `bindGroupEntry`.[`[[prevalidatedSize]]`](#dom-gpubindgroupentry-prevalidatedsize-slot) is `false`:

 - [effective buffer binding
 size](#abstract-opdef-effective-buffer-binding-size)(`bound`) must be ≥
 [minimum buffer binding
 size](#minimum-buffer-binding-size) of the binding variable in
 `pipeline`'s shader that corresponds to
 `bindGroupEntry`.

 - [Encoder bind groups alias a writable
 resource](#abstract-opdef-encoder-bind-groups-alias-a-writable-resource)(`encoder`,
 `pipeline`) must be `false`.

 - ::: compatmode
 If
 `encoder`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[features]]`](#dom-device-features-slot) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 [`"core-features-and-limits"`](#core-features-and-limits):
 - All bindings referring to the same
 [`GPUTexture`](#gputexture) must have compatible
 [`GPUTextureView`](#gputextureview)s, determined as follows:

 For each pair of
 ([`GPUIndex32`](#typedefdef-gpuindex32) `index1`,
 [`GPUBindGroupLayout`](#gpubindgrouplayout) `bindGroupLayout1`) in
 `bindGroupLayouts`:

 - If `bindGroupLayout1` is `null`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - Let `bindGroup1` be
 `encoder`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)\[`index1`\].

 - For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindGroupEntry1` in
 `bindGroup1`.[`[[entries]]`](#dom-gpubindgroup-entries-slot):

 - If
 `bindGroupEntry1`.[`resource`](#dom-gpubindgroupentry-resource) is not a
 [`GPUTextureView`](#gputextureview),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - Let `descriptor1` be
 `bindGroupEntry1`.[`resource`](#dom-gpubindgroupentry-resource).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).

 - For each pair of
 ([`GPUIndex32`](#typedefdef-gpuindex32) `index2`,
 [`GPUBindGroupLayout`](#gpubindgrouplayout) `bindGroupLayout2`) in
 `bindGroupLayouts`:

 - If `bindGroupLayout2` is `null`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - Let `bindGroup2` be
 `encoder`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)\[`index2`\].

 - For each
 [`GPUBindGroupEntry`](#dictdef-gpubindgroupentry) `bindGroupEntry2` in
 `bindGroup2`.[`[[entries]]`](#dom-gpubindgroup-entries-slot):

 - If
 `bindGroupEntry2`.[`resource`](#dom-gpubindgroupentry-resource) is not a
 [`GPUTextureView`](#gputextureview),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - If
 `bindGroupEntry1`.[`resource`](#dom-gpubindgroupentry-resource).[`[[texture]]`](#dom-gputextureview-texture-slot) is not equal to
 `bindGroupEntry2`.[`resource`](#dom-gpubindgroupentry-resource).[`[[texture]]`](#dom-gputextureview-texture-slot),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - Let `descriptor2` be
 `bindGroupEntry2`.[`resource`](#dom-gpubindgroupentry-resource).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).

 - `descriptor2`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel) must be equal to
 `descriptor1`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel).

 - `descriptor2`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) must be equal to
 `descriptor1`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount).

 - `descriptor2`.[`aspect`](#dom-gputextureviewdescriptor-aspect) must be equal to
 `descriptor1`.[`aspect`](#dom-gputextureviewdescriptor-aspect).

 - `descriptor2`.[`swizzle`](#dom-gputextureviewdescriptor-swizzle) must be equal to
 `descriptor1`.[`swizzle`](#dom-gputextureviewdescriptor-swizzle).
 :::
 :::

Otherwise return `true`.

[Encoder bind groups alias a writable
resource](`encoder`, `pipeline`) if any writable
buffer binding range overlaps with any other binding range of the same
buffer, or any writable texture binding overlaps in [texture
subresources](#texture-subresources) with any other texture binding (which may use the same
or a different
[`GPUTextureView`](#gputextureview) object).

 This algorithm limits the use of the [usage scope
storage
exception](#usage-scope-storage-exception).

**Arguments:**

[`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) `encoder`

: Encoder whose bind groups are being validated.

[`GPUPipelineBase`](#gpupipelinebase) `pipeline`

: Pipeline to validate `encoder`s bind groups are
 compatible with.

[Device timeline](#device-timeline) steps:

1. For each `stage` in
 \[[`VERTEX`](#dom-gpushaderstage-vertex),
 [`FRAGMENT`](#dom-gpushaderstage-fragment),
 [`COMPUTE`](#dom-gpushaderstage-compute)\]:

 1. Let `bufferBindings` be a
 [list](https://infra.spec.whatwg.org/#list) of
 ([`GPUBufferBinding`](#dictdef-gpubufferbinding),
 [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)) pairs, where the latter indicates whether the
 resource was used as writable.

 2. Let `textureViews` be a
 [list](https://infra.spec.whatwg.org/#list) of
 ([`GPUTextureView`](#gputextureview),
 [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)) pairs, where the latter indicates whether the
 resource was used as writable.

 3. For each pair of
 ([`GPUIndex32`](#typedefdef-gpuindex32) `bindGroupIndex`,
 [`GPUBindGroupLayout`](#gpubindgrouplayout) `bindGroupLayout`) in
 `pipeline`.[`[[layout]]`](#dom-gpupipelinebase-layout-slot).[`[[bindGroupLayouts]]`](#dom-gpupipelinelayout-bindgrouplayouts-slot):

 1. Let `bindGroup` be
 `encoder`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)\[`bindGroupIndex`\].

 2. Let `bindGroupLayoutEntries` be
 `bindGroupLayout`.[`[[descriptor]]`](#dom-gpubindgrouplayout-descriptor-slot).[`entries`](#dom-gpubindgrouplayoutdescriptor-entries).

 3. Let `bufferRanges` be the [bound buffer
 ranges](#gpubindgroup-bound-buffer-ranges) of `bindGroup`, given dynamic
 offsets
 `encoder`.[`[[dynamic_offsets]]`](#dom-gpubindingcommandsmixin-dynamic_offsets-slot)\[`bindGroupIndex`\]

 4. For each
 ([`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `bindGroupLayoutEntry`,
 [`GPUBufferBinding`](#dictdef-gpubufferbinding) `resource`) in
 `bufferRanges`, in which
 `bindGroupLayoutEntry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) contains `stage`:

 1. Let `resourceWritable` be
 (`bindGroupLayoutEntry`.[`buffer`](#dom-gpubindgrouplayoutentry-buffer).[`type`](#dom-gpubufferbindinglayout-type) ==
 [`"storage"`](#dom-gpubufferbindingtype-storage)).

 2. For each pair
 ([`GPUBufferBinding`](#dictdef-gpubufferbinding) `pastResource`,
 [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean) `pastResourceWritable`) in
 `bufferBindings`:

 1. If (`resourceWritable` or
 `pastResourceWritable`) is true, and
 `pastResource` and `resource`
 are
 [buffer-binding-aliasing](#buffer-binding-aliasing), return `true`.

 3. [Append](https://infra.spec.whatwg.org/#list-append) (`resource`,
 `resourceWritable`) to
 `bufferBindings`.

 5. For each
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) `bindGroupLayoutEntry` in
 `bindGroupLayoutEntries`, and corresponding
 [`GPUTextureView`](#gputextureview) `resource` in
 `bindGroup`, in which
 `bindGroupLayoutEntry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) contains `stage`:

 1. If
 `bindGroupLayoutEntry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture) is not
 [provided](https://infra.spec.whatwg.org/#map-exists), **continue**.

 2. Let `resourceWritable` be whether
 `bindGroupLayoutEntry`.[`storageTexture`](#dom-gpubindgrouplayoutentry-storagetexture).[`access`](#dom-gpustoragetexturebindinglayout-access) is a writable access mode.

 3. For each pair
 ([`GPUTextureView`](#gputextureview) `pastResource`,
 [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean) `pastResourceWritable`) in
 `textureViews`,

 1. If (`resourceWritable` or
 `pastResourceWritable`) is true, and
 `pastResource` and `resource`
 is
 [texture-view-aliasing](#texture-view-aliasing), return `true`.

 4. [Append](https://infra.spec.whatwg.org/#list-append) (`resource`,
 `resourceWritable`) to
 `textureViews`.

2. Return `false`.

 Implementations are strongly encouraged to optimize
this algorithm.

## 15. Debug Markers

[`GPUDebugCommandsMixin`] provides methods to apply
debug labels to groups of commands or insert a single label into the
command sequence.

Debug groups can be nested to create a hierarchy of labeled commands,
and must be well-balanced.

Like
[`object labels`](#dom-gpuobjectbase-label), these labels have no required behavior, but may be
shown in error messages and browser developer tools, and may be passed
to native API backends.

```
interface mixin GPUDebugCommandsMixin {
 undefined pushDebugGroup(USVString groupLabel);
 undefined popDebugGroup();
 undefined insertDebugMarker(USVString markerLabel);
};
```

[`GPUDebugCommandsMixin`](#gpudebugcommandsmixin) assumes the presence of
[`GPUObjectBase`](#gpuobjectbase) and
[`GPUCommandsMixin`](#gpucommandsmixin) members on the same object. It must only be included by
interfaces which also include those mixins.

[`GPUDebugCommandsMixin`](#gpudebugcommandsmixin) has the following [device timeline
properties](#device-timeline-property):

[`[[debug_group_stack]]`], of type [stack](https://infra.spec.whatwg.org/#stack)\<[`USVString`](https://webidl.spec.whatwg.org/#idl-USVString)\>

: A stack of active debug group labels.

[`GPUDebugCommandsMixin`](#gpudebugcommandsmixin) has the following methods:

[`pushDebugGroup(groupLabel)`]

: Begins a labeled debug group containing subsequent commands.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUDebugCommandsMixin`](#gpudebugcommandsmixin) `this`.
 **Arguments:**

 Arguments for the
 [GPUDebugCommandsMixin.pushDebugGroup(groupLabel)](#dom-gpudebugcommandsmixin-pushdebuggroup) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`groupLabel`]
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString)
 [✘]
 [✘]
 The label for the command group.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. [Push](https://infra.spec.whatwg.org/#stack-push) `groupLabel` onto
 `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot).
 :::
 :::::

[`popDebugGroup()`]

: Ends the labeled debug group most recently started by
 [`pushDebugGroup()`](#dom-gpudebugcommandsmixin-pushdebuggroup).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUDebugCommandsMixin`](#gpudebugcommandsmixin) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot) must not [be
 empty](https://infra.spec.whatwg.org/#list-is-empty).
 :::

 3. [Pop](https://infra.spec.whatwg.org/#stack-pop) an entry off of
 `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot).
 :::
 :::::

[`insertDebugMarker(markerLabel)`]

: Marks a point in a stream of commands with a label.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUDebugCommandsMixin`](#gpudebugcommandsmixin) this.
 **Arguments:**

 Arguments for the
 [GPUDebugCommandsMixin.insertDebugMarker(markerLabel)](#dom-gpudebugcommandsmixin-insertdebugmarker) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`markerLabel`]
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString)
 [✘]
 [✘]
 The label to insert.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.
 :::
 :::::

## 16. Compute Passes

### 16.1. `GPUComputePassEncoder`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUComputePassEncoder {
 undefined setPipeline(GPUComputePipeline pipeline);
 undefined dispatchWorkgroups(GPUSize32 workgroupCountX, optional GPUSize32 workgroupCountY = 1, optional GPUSize32 workgroupCountZ = 1);
 undefined dispatchWorkgroupsIndirect(GPUBuffer indirectBuffer, GPUSize64 indirectOffset);

 undefined end();
};
GPUComputePassEncoder includes GPUObjectBase;
GPUComputePassEncoder includes GPUCommandsMixin;
GPUComputePassEncoder includes GPUDebugCommandsMixin;
GPUComputePassEncoder includes GPUBindingCommandsMixin;
```

[`GPUComputePassEncoder`](#gpucomputepassencoder) has the following [device timeline
properties](#device-timeline-property):

[`[[command_encoder]]`], of type [`GPUCommandEncoder`](#gpucommandencoder), readonly

: The
 [`GPUCommandEncoder`](#gpucommandencoder) that created this compute pass encoder.

[`[[endTimestampWrite]]`], of type [GPU command](#gpu-command)?, readonly, defaulting to `null`

: [GPU command](#gpu-command),
 if any, writing a timestamp when the pass ends.

[`[[pipeline]]`], of type [`GPUComputePipeline`](#gpucomputepipeline), initially `null`

: The current
 [`GPUComputePipeline`](#gpucomputepipeline).

#### 16.1.1. Compute Pass Encoder Creation

```
dictionary GPUComputePassTimestampWrites {
 required GPUQuerySet querySet;
 GPUSize32 beginningOfPassWriteIndex;
 GPUSize32 endOfPassWriteIndex;
};
```

[`querySet`], of type [GPUQuerySet](#gpuqueryset)

: The [`GPUQuerySet`](#gpuqueryset), of type
 [`"timestamp"`](#dom-gpuquerytype-timestamp), that the query results will be written to.

[`beginningOfPassWriteIndex`], of type [GPUSize32](#typedefdef-gpusize32)

: If defined, indicates the query index in
 [`querySet`](#dom-gpurenderpasstimestampwrites-queryset) into which the timestamp at the beginning of the
 compute pass will be written.

[`endOfPassWriteIndex`], of type [GPUSize32](#typedefdef-gpusize32)

: If defined, indicates the query index in
 [`querySet`](#dom-gpurenderpasstimestampwrites-queryset) into which the timestamp at the end of the compute
 pass will be written.

 Timestamp query values are written in nanoseconds, but
how the value is determined is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). See [§ 20.4 Timestamp Query](#timestamp) for details.

```
dictionary GPUComputePassDescriptor
 : GPUObjectDescriptorBase {
 GPUComputePassTimestampWrites timestampWrites;
};
```

[`timestampWrites`], of type [GPUComputePassTimestampWrites](#dictdef-gpucomputepasstimestampwrites)

: Defines which timestamp values will be written for this pass, and
 where to write them to.

#### 16.1.2. Dispatch

[`setPipeline(pipeline)`]

: Sets the current
 [`GPUComputePipeline`](#gpucomputepipeline).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUComputePassEncoder`](#gpucomputepassencoder) this.
 **Arguments:**

 Arguments for the
 [GPUComputePassEncoder.setPipeline(pipeline)](#dom-gpucomputepassencoder-setpipeline) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`pipeline`]
 [`GPUComputePipeline`](#gpucomputepipeline)
 [✘]
 [✘]
 The compute pipeline to use for subsequent dispatch commands.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `pipeline` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.
 :::

 3. Set
 `this`.[`[[pipeline]]`](#dom-gpucomputepassencoder-pipeline-slot) to be `pipeline`.
 :::
 :::::

[`dispatchWorkgroups(workgroupCountX, workgroupCountY, workgroupCountZ)`]

: Dispatch work to be performed with the current
 [`GPUComputePipeline`](#gpucomputepipeline). See [§ 23.1 Computing](#computing-operations) for
 the detailed specification.

 ::::::::
 ::::: {timeline="content"}
 **Called on:**
 [`GPUComputePassEncoder`](#gpucomputepassencoder) this.
 **Arguments:**

 Arguments for the
 [GPUComputePassEncoder.dispatchWorkgroups(workgroupCountX,
 workgroupCountY,
 workgroupCountZ)](#dom-gpucomputepassencoder-dispatchworkgroups) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`workgroupCountX`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 X dimension of the grid of workgroups to dispatch.
 [`workgroupCountY`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 Y dimension of the grid of workgroups to dispatch.
 [`workgroupCountZ`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 Z dimension of the grid of workgroups to dispatch.

 ::::
 ::: marker
 NOTE:
 :::

 The `x`, `y`, and `z` values passed to
 [`dispatchWorkgroups()`](#dom-gpucomputepassencoder-dispatchworkgroups) and
 [`dispatchWorkgroupsIndirect()`](#dom-gpucomputepassencoder-dispatchworkgroupsindirect) are the number of *workgroups* to dispatch for each
 dimension, *not* the number of shader invocations to perform across
 each dimension. This matches the behavior of modern native GPU APIs,
 but differs from the behavior of OpenCL.
 This means that if a
 [`GPUShaderModule`](#gpushadermodule) defines an entry point with
 `@workgroup_size(4, 4)`, and work is dispatched to it with the call
 `computePass.dispatchWorkgroups(8, 8);` the entry point will be
 invoked 1024 times total: Dispatching a 4x4 workgroup 8 times along
 both the X and Y axes. (`4*4*8*8=1024`)
 ::::

 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `usageScope` be an empty [usage
 scope](#usage-scope).

 3. For each `bindGroup` in
 `this`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot),
 [merge](#abstract-opdef-usage-scope-merge)
 `bindGroup`.[`[[usedResources]]`](#dom-gpubindgroup-usedresources-slot) into
 `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot)

 4. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `usageScope` must satisfy [usage scope
 validation](#usage-scope-validation).

 - [Validate encoder bind
 groups](#abstract-opdef-validate-encoder-bind-groups)(`this`,
 `this`.[`[[pipeline]]`](#dom-gpucomputepassencoder-pipeline-slot)) is `true`.

 - all of `workgroupCountX`,
 `workgroupCountY` and `workgroupCountZ`
 are ≤
 `this`.device.limits.[`maxComputeWorkgroupsPerDimension`](#dom-supported-limits-maxcomputeworkgroupsperdimension).
 :::

 5. Let `bindingState` be a snapshot of
 `this`'s current state.

 6. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline).
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Execute a grid of workgroups with dimensions
 \[`workgroupCountX`, `workgroupCountY`,
 `workgroupCountZ`\] with
 `bindingState`.[`[[pipeline]]`](#dom-gpucomputepassencoder-pipeline-slot) using
 `bindingState`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot).
 :::
 ::::::::

[`dispatchWorkgroupsIndirect(indirectBuffer, indirectOffset)`]

: Dispatch work to be performed with the current
 [`GPUComputePipeline`](#gpucomputepipeline) using parameters read from a
 [`GPUBuffer`](#gpubuffer). See [§ 23.1 Computing](#computing-operations) for
 the detailed specification.

 The [indirect dispatch parameters] encoded in
 the buffer must be a tightly packed block of **three 32-bit unsigned
 integer values (12 bytes total)**, given in the same order as the
 arguments for
 [`dispatchWorkgroups()`](#dom-gpucomputepassencoder-dispatchworkgroups). For example:

 ``` highlight
 let dispatchIndirectParameters = new Uint32Array(3);
 dispatchIndirectParameters[0] = workgroupCountX;
 dispatchIndirectParameters[1] = workgroupCountY;
 dispatchIndirectParameters[2] = workgroupCountZ;
 ```

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUComputePassEncoder`](#gpucomputepassencoder) this.
 **Arguments:**

 Arguments for the
 [GPUComputePassEncoder.dispatchWorkgroupsIndirect(indirectBuffer,
 indirectOffset)](#dom-gpucomputepassencoder-dispatchworkgroupsindirect) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`indirectBuffer`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 Buffer containing the [indirect dispatch
 parameters](#indirect-dispatch-parameters).
 [`indirectOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in bytes into `indirectBuffer` where the dispatch
 data begins.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `usageScope` be an empty [usage
 scope](#usage-scope).

 3. For each `bindGroup` in
 `this`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot),
 [merge](#abstract-opdef-usage-scope-merge)
 `bindGroup`.[`[[usedResources]]`](#dom-gpubindgroup-usedresources-slot) into
 `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot)

 4. [Add](#abstract-opdef-usage-scope-add) `indirectBuffer` to
 `usageScope` with usage
 [input](#internal-usage-input).

 5. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `usageScope` must satisfy [usage scope
 validation](#usage-scope-validation).

 - [Validate encoder bind
 groups](#abstract-opdef-validate-encoder-bind-groups)(`this`,
 `this`.[`[[pipeline]]`](#dom-gpucomputepassencoder-pipeline-slot)) is `true`.

 - `indirectBuffer` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `indirectBuffer`.[`usage`](#dom-gpubuffer-usage) contains
 [`INDIRECT`](#dom-gpubufferusage-indirect).

 - `indirectOffset` + sizeof([indirect dispatch
 parameters](#indirect-dispatch-parameters)) ≤
 `indirectBuffer`.[`size`](#dom-gpubuffer-size).

 - `indirectOffset` is a multiple of 4.
 :::

 6. Let `bindingState` be a snapshot of
 `this`'s current state.

 7. [Enqueue a
 command](#abstract-opdef-enqueue-a-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline).
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `workgroupCountX` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 `indirectOffset` bytes.

 2. Let `workgroupCountY` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 (`indirectOffset` + 4) bytes.

 3. Let `workgroupCountZ` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 (`indirectOffset` + 8) bytes.

 4. If `workgroupCountX`, `workgroupCountY`,
 or `workgroupCountZ` is greater than
 `this`.device.limits.[`maxComputeWorkgroupsPerDimension`](#dom-supported-limits-maxcomputeworkgroupsperdimension), return.

 5. Execute a grid of workgroups with dimensions
 \[`workgroupCountX`, `workgroupCountY`,
 `workgroupCountZ`\] with
 `bindingState`.[`[[pipeline]]`](#dom-gpucomputepassencoder-pipeline-slot) using
 `bindingState`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot).
 :::
 ::::::

#### 16.1.3. Finalization

The compute pass encoder can be ended by calling
[`end()`](#dom-gpucomputepassencoder-end) once the user has finished recording commands for the
pass. Once
[`end()`](#dom-gpucomputepassencoder-end) has been called the compute pass encoder can no longer
be used.

[`end()`]

: Completes recording of the compute pass commands sequence.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUComputePassEncoder`](#gpucomputepassencoder) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Let `parentEncoder` be
 `this`.[`[[command_encoder]]`](#dom-gpurenderpassencoder-command_encoder-slot).

 2. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error) and return.

 ::: validusage
 - `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) must be
 \"[open](#encoder-state-open)\".

 - `parentEncoder`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) must be
 \"[locked](#encoder-state-locked)\".
 :::

 3. Set
 `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[ended](#encoder-state-ended)\".

 4. Set
 `parentEncoder`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[open](#encoder-state-open)\".

 5. [Extend](https://infra.spec.whatwg.org/#set-extend)
 `parentEncoder`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot) with
 `this`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot).

 6. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `parentEncoder` and return.

 ::: validusage
 - `this` must be
 [valid](#abstract-opdef-valid).

 - `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot) must [be
 empty](https://infra.spec.whatwg.org/#list-is-empty).
 :::

 7. [Extend](https://infra.spec.whatwg.org/#list-extend)
 `parentEncoder`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot) with
 `this`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot).

 8. If
 `this`.[`[[endTimestampWrite]]`](#dom-gpucomputepassencoder-endtimestampwrite-slot) is not `null`:

 1. [Extend](https://infra.spec.whatwg.org/#list-extend)
 `parentEncoder`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot) with
 `this`.[`[[endTimestampWrite]]`](#dom-gpucomputepassencoder-endtimestampwrite-slot).
 :::
 :::::

## 17. Render Passes

### 17.1. `GPURenderPassEncoder`

```
[Exposed=(Window, Worker), SecureContext]
interface GPURenderPassEncoder {
 undefined setViewport(float x, float y,
 float width, float height,
 float minDepth, float maxDepth);

 undefined setScissorRect(GPUIntegerCoordinate x, GPUIntegerCoordinate y,
 GPUIntegerCoordinate width, GPUIntegerCoordinate height);

 undefined setBlendConstant(GPUColor color);
 undefined setStencilReference(GPUStencilValue reference);

 undefined beginOcclusionQuery(GPUSize32 queryIndex);
 undefined endOcclusionQuery();

 undefined executeBundles(sequence<GPURenderBundle> bundles);
 undefined end();
};
GPURenderPassEncoder includes GPUObjectBase;
GPURenderPassEncoder includes GPUCommandsMixin;
GPURenderPassEncoder includes GPUDebugCommandsMixin;
GPURenderPassEncoder includes GPUBindingCommandsMixin;
GPURenderPassEncoder includes GPURenderCommandsMixin;
```

[`GPURenderPassEncoder`](#gpurenderpassencoder) has the following [device timeline
properties](#device-timeline-property):

[`[[command_encoder]]`], of type [`GPUCommandEncoder`](#gpucommandencoder), readonly

: The
 [`GPUCommandEncoder`](#gpucommandencoder) that created this render pass encoder.

[`[[attachment_size]]`], readonly

: Set to the following extents:

 - `width, height` = the dimensions of the pass's render attachments

[`[[occlusion_query_set]]`], of type [`GPUQuerySet`](#gpuqueryset), readonly

: The [`GPUQuerySet`](#gpuqueryset) to store occlusion query results for the pass,
 which is initialized with
 [`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor).[`occlusionQuerySet`](#dom-gpurenderpassdescriptor-occlusionqueryset) at pass creation time.

[`[[endTimestampWrite]]`], of type [GPU command](#gpu-command)?, readonly, defaulting to `null`

: [GPU command](#gpu-command),
 if any, writing a timestamp when the pass ends.

[`[[maxDrawCount]]`] of type [`GPUSize64`](#typedefdef-gpusize64), readonly

: The maximum number of draws allowed in this pass.

[`[[occlusion_query_active]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

: Whether the pass's
 [`[[occlusion_query_set]]`](#dom-gpurenderpassencoder-occlusion_query_set-slot) is being written.

When executing encoded render pass commands as part of a
[`GPUCommandBuffer`](#gpucommandbuffer), an internal [RenderState] object is used to track the
current state required for rendering.

[RenderState](#renderstate) has
the following [queue timeline
properties](#queue-timeline-property):

[`[[occlusionQueryIndex]]`], of type [`GPUSize32`](#typedefdef-gpusize32)

: The index into
 [`[[occlusion_query_set]]`](#dom-gpurenderpassencoder-occlusion_query_set-slot) at which to store the occlusion query results.

[`[[viewport]]`]

: Current viewport rectangle and depth range. Initially set to the
 following values:

 - `x, y` = `0.0, 0.0`

 - `width, height` = the dimensions of the pass's render targets

 - `minDepth, maxDepth` = `0.0, 1.0`

[`[[scissorRect]]`]

: Current scissor rectangle. Initially set to the following values:

 - `x, y` = `0, 0`

 - `width, height` = the dimensions of the pass's render targets

[`[[blendConstant]]`], of type [`GPUColor`](#typedefdef-gpucolor)

: Current blend constant value, initially `[0, 0, 0, 0]`.

[`[[stencilReference]]`], of type [`GPUStencilValue`](#typedefdef-gpustencilvalue)

: Current stencil reference value, initially `0`.

[`[[colorAttachments]]`], of type [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPURenderPassColorAttachment`](#dictdef-gpurenderpasscolorattachment)?\>

: The color attachments and state for this render pass.

[`[[depthStencilAttachment]]`], of type [`GPURenderPassDepthStencilAttachment`](#dictdef-gpurenderpassdepthstencilattachment)?

: The depth/stencil attachment and state for this render pass.

Render passes also have [framebuffer memory], which contains the
[texel](#texel-block) data
associated with each attachment that is written into by draw commands
and read from for blending and depth/stencil testing.

 Depending on the GPU hardware, [framebuffer
memory](#framebuffer-memory) may be the memory allocated by the attachment textures
or may be a separate area of memory that the texture data is copied to
and from, such as with tile-based architectures.

#### 17.1.1. Render Pass Encoder Creation

```
dictionary GPURenderPassTimestampWrites {
 required GPUQuerySet querySet;
 GPUSize32 beginningOfPassWriteIndex;
 GPUSize32 endOfPassWriteIndex;
};
```

[`querySet`], of type [GPUQuerySet](#gpuqueryset)

: The [`GPUQuerySet`](#gpuqueryset), of type
 [`"timestamp"`](#dom-gpuquerytype-timestamp), that the query results will be written to.

[`beginningOfPassWriteIndex`], of type [GPUSize32](#typedefdef-gpusize32)

: If defined, indicates the query index in
 [`querySet`](#dom-gpurenderpasstimestampwrites-queryset) into which the timestamp at the beginning of the
 render pass will be written.

[`endOfPassWriteIndex`], of type [GPUSize32](#typedefdef-gpusize32)

: If defined, indicates the query index in
 [`querySet`](#dom-gpurenderpasstimestampwrites-queryset) into which the timestamp at the end of the render
 pass will be written.

 Timestamp query values are written in nanoseconds, but
how the value is determined is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). See [§ 20.4 Timestamp Query](#timestamp) for details.

```
dictionary GPURenderPassDescriptor
 : GPUObjectDescriptorBase {
 required sequence<GPURenderPassColorAttachment?> colorAttachments;
 GPURenderPassDepthStencilAttachment depthStencilAttachment;
 GPUQuerySet occlusionQuerySet;
 GPURenderPassTimestampWrites timestampWrites;
 GPUSize64 maxDrawCount = 50000000;
};
```

[`colorAttachments`], of type `sequence<GPURenderPassColorAttachment?>`

: The set of
 [`GPURenderPassColorAttachment`](#dictdef-gpurenderpasscolorattachment) values in this sequence defines which color
 attachments will be output to when executing this render pass.

 Due to [usage
 compatibility](#compatible-usage-list), no color attachment may alias another attachment
 or any resource used inside the render pass.

[`depthStencilAttachment`], of type [GPURenderPassDepthStencilAttachment](#dictdef-gpurenderpassdepthstencilattachment)

: The
 [`GPURenderPassDepthStencilAttachment`](#dictdef-gpurenderpassdepthstencilattachment) value that defines the depth/stencil attachment
 that will be output to and tested against when executing this render
 pass.

 Due to [usage
 compatibility](#compatible-usage-list), no writable depth/stencil attachment may alias
 another attachment or any resource used inside the render pass.

[`occlusionQuerySet`], of type [GPUQuerySet](#gpuqueryset)

: The [`GPUQuerySet`](#gpuqueryset) value defines where the occlusion query results
 will be stored for this pass.

[`timestampWrites`], of type [GPURenderPassTimestampWrites](#dictdef-gpurenderpasstimestampwrites)

: Defines which timestamp values will be written for this pass, and
 where to write them to.

[`maxDrawCount`], of type [GPUSize64](#typedefdef-gpusize64), defaulting to `50000000`

: The maximum number of draw calls that will be done in the render
 pass. Used by some implementations to size work injected before the
 render pass. Keeping the default value is a good default, unless it
 is known that more draw calls will be done.

[Valid Usage]

Given a [`GPUDevice`](#gpudevice) `device` and
[`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor) `this`, the following validation rules
apply:

1. `this`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments).[size](https://infra.spec.whatwg.org/#list-size) must be ≤
 `device`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachments`](#dom-supported-limits-maxcolorattachments).

2. For each non-`null` `colorAttachment` in
 `this`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments):

 1. `colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view) must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `device`.

 2. If
 `colorAttachment`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. `colorAttachment`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget) must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `device`.

 3. `colorAttachment` must meet the
 [GPURenderPassColorAttachment Valid
 Usage](#abstract-opdef-gpurenderpasscolorattachment-gpurenderpasscolorattachment-valid-usage) rules.

3. If
 `this`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. `this`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).[`view`](#dom-gpurenderpassdepthstencilattachment-view) must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `device`.

 2. `this`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment) must meet the
 [GPURenderPassDepthStencilAttachment Valid
 Usage](#abstract-opdef-gpurenderpassdepthstencilattachment-gpurenderpassdepthstencilattachment-valid-usage) rules.

4. There must exist at least one attachment, either:

 - A non-`null` value in
 `this`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments), or

 - A
 `this`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).

5. [Validating GPURenderPassDescriptor's color attachment bytes per
 sample](#abstract-opdef-validating-gpurenderpassdescriptors-color-attachment-bytes-per-sample)(`device`,
 `this`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments)) succeeds.

6. All
 [`view`](#dom-gpurenderpasscolorattachment-view)s in non-`null` members of
 `this`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments), and
 `this`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).[`view`](#dom-gpurenderpassdepthstencilattachment-view) if present, must have equal
 [`sampleCount`](#dom-gputexture-samplecount)s.

7. For each
 [`view`](#dom-gpurenderpasscolorattachment-view) in non-`null` members of
 `this`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments) and
 `this`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).[`view`](#dom-gpurenderpassdepthstencilattachment-view), if present, the
 [`[[renderExtent]]`](#dom-gputextureview-renderextent-slot) must match.

8. If
 `this`.[`occlusionQuerySet`](#dom-gpurenderpassdescriptor-occlusionqueryset) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. `this`.[`occlusionQuerySet`](#dom-gpurenderpassdescriptor-occlusionqueryset) must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `device`.

 2. `this`.[`occlusionQuerySet`](#dom-gpurenderpassdescriptor-occlusionqueryset).[`type`](#dom-gpuqueryset-type) must be
 [`occlusion`](#dom-gpuquerytype-occlusion).

9. If
 `this`.[`timestampWrites`](#dom-gpurenderpassdescriptor-timestampwrites) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - [Validate
 timestampWrites](#abstract-opdef-validate-timestampwrites)(`device`,
 `this`.[`timestampWrites`](#dom-gpurenderpassdescriptor-timestampwrites)) must return true.

[Validating GPURenderPassDescriptor's color attachment bytes per
sample](`device`,
`colorAttachments`)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPURenderPassColorAttachment`](#dictdef-gpurenderpasscolorattachment)?\> `colorAttachments`

[Device timeline](#device-timeline) steps:

1. Let `formats` be an empty
 [list](https://infra.spec.whatwg.org/#list)\<[`GPUTextureFormat`](#enumdef-gputextureformat)?\>

2. For each `colorAttachment` in
 `colorAttachments`:

 1. If `colorAttachment` is `undefined`, continue.

 2. [Append](https://infra.spec.whatwg.org/#list-append)
 `colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`format`](#dom-gputextureviewdescriptor-format) to `formats`.

3. [Calculating color attachment bytes per
 sample](#abstract-opdef-calculating-color-attachment-bytes-per-sample)(`formats`) must be ≤
 `device`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachmentBytesPerSample`](#dom-supported-limits-maxcolorattachmentbytespersample).

##### 17.1.1.1. Color Attachments

```
dictionary GPURenderPassColorAttachment {
 required (GPUTexture or GPUTextureView) view;
 GPUIntegerCoordinate depthSlice;
 (GPUTexture or GPUTextureView) resolveTarget;

 GPUColor clearValue;
 required GPULoadOp loadOp;
 required GPUStoreOp storeOp;
};
```

[`view`], of type `(GPUTexture or GPUTextureView)`

: Describes the texture
 [subresource](#subresource)
 that will be output to for this color attachment. The
 [subresource](#subresource)
 is determined by calling [get as texture
 view](#abstract-opdef-get-as-texture-view)([`view`](#dom-gpurenderpasscolorattachment-view)).

[`depthSlice`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate)

: Indicates the depth slice index of
 [`"3d"`](#dom-gputextureviewdimension-3d)
 [`view`](#dom-gpurenderpasscolorattachment-view) that will be output to for this color attachment.

[`resolveTarget`], of type `(GPUTexture or GPUTextureView)`

: Describes the texture
 [subresource](#subresource)
 that will receive the resolved output for this color attachment if
 [`view`](#dom-gpurenderpasscolorattachment-view) is multisampled. The
 [subresource](#subresource)
 is determined by calling [get as texture
 view](#abstract-opdef-get-as-texture-view)([`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget)).

[`clearValue`], of type [GPUColor](#typedefdef-gpucolor)

: Indicates the value to clear
 [`view`](#dom-gpurenderpasscolorattachment-view) to prior to executing the render pass. If not
 [provided](https://infra.spec.whatwg.org/#map-exists), defaults to `{r: 0, g: 0, b: 0, a: 0}`. Ignored if
 [`loadOp`](#dom-gpurenderpasscolorattachment-loadop) is not
 [`"clear"`](#dom-gpuloadop-clear).

 The components of
 [`clearValue`](#dom-gpurenderpasscolorattachment-clearvalue) are all double values. They are converted [to a
 texel value of texture
 format](#abstract-opdef-to-a-texel-value-of-texture-format) matching the render attachment. If
 conversion fails, a validation error is generated.

[`loadOp`], of type [GPULoadOp](#enumdef-gpuloadop)

: Indicates the load operation to perform on
 [`view`](#dom-gpurenderpasscolorattachment-view) prior to executing the render pass.

 It is recommended to prefer clearing; see
 [`"clear"`](#dom-gpuloadop-clear) for details.

[`storeOp`], of type [GPUStoreOp](#enumdef-gpustoreop)

: The store operation to perform on
 [`view`](#dom-gpurenderpasscolorattachment-view) after executing the render pass.

[GPURenderPassColorAttachment Valid
Usage]

Given a
[`GPURenderPassColorAttachment`](#dictdef-gpurenderpasscolorattachment) `this`:

1. Let `renderViewDescriptor` be
 `this`.[`view`](#dom-gpurenderpasscolorattachment-view).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).

2. Let `renderTexture` be
 `this`.[`view`](#dom-gpurenderpasscolorattachment-view).[`[[texture]]`](#dom-gputextureview-texture-slot).

3. All of the requirements in the following steps `must` be
 met.

 ::: validusage
 1. `renderViewDescriptor`.[`format`](#dom-gputextureviewdescriptor-format) `must` be a [color renderable
 format](#color-renderable-format).

 2. `this`.[`view`](#dom-gpurenderpasscolorattachment-view) `must` be a [renderable texture
 view](#abstract-opdef-renderable-texture-view).

 3. If
 `renderViewDescriptor`.[`dimension`](#dom-gputextureviewdescriptor-dimension) is
 [`"3d"`](#dom-gputextureviewdimension-3d):

 1. `this`.[`depthSlice`](#dom-gpurenderpasscolorattachment-depthslice) `must` [be
 provided](https://infra.spec.whatwg.org/#map-exists) and `must` be \< the
 [depthOrArrayLayers](#gpuextent3d-depthorarraylayers) of the [logical miplevel-specific texture
 extent](#logical-miplevel-specific-texture-extent) of the `renderTexture`
 [subresource](#subresource) at [mipmap
 level](#mipmap-level)
 `renderViewDescriptor`.[`baseMipLevel`](#dom-gputextureviewdescriptor-basemiplevel).

 Otherwise:

 1. `this`.[`depthSlice`](#dom-gpurenderpasscolorattachment-depthslice) `must` not [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 4. If
 `this`.[`loadOp`](#dom-gpurenderpasscolorattachment-loadop) is
 [`"clear"`](#dom-gpuloadop-clear):

 1. Converting the IDL value
 `this`.[`clearValue`](#dom-gpurenderpasscolorattachment-clearvalue) [to a texel value of texture
 format](#abstract-opdef-to-a-texel-value-of-texture-format)
 `renderViewDescriptor`.[`format`](#dom-gputextureviewdescriptor-format) `must` not throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 An error is not thrown if the value is
 out-of-range for the format but in-range for the
 corresponding WGSL primitive type (`f32`, `i32`, or `u32`).

 5. If
 `this`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Let `resolveViewDescriptor` be
 `this`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).

 2. Let `resolveTexture` be
 `this`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget).[`[[texture]]`](#dom-gputextureview-texture-slot).

 3. `renderTexture`.[`sampleCount`](#dom-gputexture-samplecount) `must` be \> 1.

 4. `resolveTexture`.[`sampleCount`](#dom-gputexture-samplecount) `must` be 1.

 5. `this`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget) `must` be a non-3d [renderable
 texture
 view](#abstract-opdef-renderable-texture-view).

 6. `this`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget).[`[[renderExtent]]`](#dom-gputextureview-renderextent-slot) and
 `this`.[`view`](#dom-gpurenderpasscolorattachment-view).[`[[renderExtent]]`](#dom-gputextureview-renderextent-slot) `must` match.

 7. `resolveViewDescriptor`.[`format`](#dom-gputextureviewdescriptor-format) `must` equal
 `renderViewDescriptor`.[`format`](#dom-gputextureviewdescriptor-format).

 8. `resolveTexture`.[`format`](#dom-gputexturedescriptor-format) `must` equal
 `renderTexture`.[`format`](#dom-gputexturedescriptor-format).

 9. `resolveViewDescriptor`.[`format`](#dom-gputextureviewdescriptor-format) `must` support resolve according
 to [§ 26.1.1 Plain color formats](#plain-color-formats).
 :::

A [`GPUTextureView`](#gputextureview) `view` is a [renderable texture
view] if the all of the requirements in the
following [device
timeline](#device-timeline)
steps are met:

1. Let `descriptor` be
 `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).

2. `descriptor`.[`usage`](#dom-gputextureviewdescriptor-usage) must contain
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment).

3. `descriptor`.[`dimension`](#dom-gputextureviewdescriptor-dimension) must be
 [`"2d"`](#dom-gputextureviewdimension-2d) or
 [`"2d-array"`](#dom-gputextureviewdimension-2d-array) or
 [`"3d"`](#dom-gputextureviewdimension-3d).

4. `descriptor`.[`mipLevelCount`](#dom-gputextureviewdescriptor-miplevelcount) must be 1.

5. `descriptor`.[`arrayLayerCount`](#dom-gputextureviewdescriptor-arraylayercount) must be 1.

6. `descriptor`.[`aspect`](#dom-gputextureviewdescriptor-aspect) must refer to all
 [aspects](#aspect) of
 `view`.[`[[texture]]`](#dom-gputextureview-texture-slot).

7. `descriptor`.[`swizzle`](#dom-gputextureviewdescriptor-swizzle) must be `"rgba"`.

[Calculating color attachment bytes per
sample](`formats`)

**Arguments:**

- [sequence](https://webidl.spec.whatwg.org/#idl-sequence)\<[`GPUTextureFormat`](#enumdef-gputextureformat)?\> `formats`

**Returns:**
[`GPUSize32`](#typedefdef-gpusize32)

1. Let `total` be 0.

2. For each non-null `format` in `formats`

 1. [Assert](https://infra.spec.whatwg.org/#assert): `format` is a [color renderable
 format](#color-renderable-format).

 2. Let `renderTargetPixelByteCost` be the [render target
 pixel byte
 cost](#render-target-pixel-byte-cost) of `format`.

 3. Let `renderTargetComponentAlignment` be the [render
 target component
 alignment](#render-target-component-alignment) of `format`.

 4. Round `total` up to the smallest multiple of
 `renderTargetComponentAlignment` greater than or
 equal to `total`.

 5. Add `renderTargetPixelByteCost` to
 `total`.

3. Return `total`.

##### 17.1.1.2. Depth/Stencil Attachments

```
dictionary GPURenderPassDepthStencilAttachment {
 required (GPUTexture or GPUTextureView) view;

 float depthClearValue;
 GPULoadOp depthLoadOp;
 GPUStoreOp depthStoreOp;
 boolean depthReadOnly = false;

 GPUStencilValue stencilClearValue = 0;
 GPULoadOp stencilLoadOp;
 GPUStoreOp stencilStoreOp;
 boolean stencilReadOnly = false;
};
```

[`view`], of type `(GPUTexture or GPUTextureView)`

: Describes the texture
 [subresource](#subresource)
 that will be output to and read from for this depth/stencil
 attachment. The [subresource](#subresource) is determined by calling [get as texture
 view](#abstract-opdef-get-as-texture-view)([`view`](#dom-gpurenderpassdepthstencilattachment-view)).

[`depthClearValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float)

: Indicates the value to clear
 [`view`](#dom-gpurenderpassdepthstencilattachment-view)'s depth component to prior to executing the render
 pass. Ignored if
 [`depthLoadOp`](#dom-gpurenderpassdepthstencilattachment-depthloadop) is not
 [`"clear"`](#dom-gpuloadop-clear). Must be between 0.0 and 1.0, inclusive.

[`depthLoadOp`], of type [GPULoadOp](#enumdef-gpuloadop)

: Indicates the load operation to perform on
 [`view`](#dom-gpurenderpassdepthstencilattachment-view)'s depth component prior to executing the render
 pass.

 It is recommended to prefer clearing; see
 [`"clear"`](#dom-gpuloadop-clear) for details.

[`depthStoreOp`], of type [GPUStoreOp](#enumdef-gpustoreop)

: The store operation to perform on
 [`view`](#dom-gpurenderpassdepthstencilattachment-view)'s depth component after executing the render pass.

[`depthReadOnly`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Indicates that the depth component of
 [`view`](#dom-gpurenderpassdepthstencilattachment-view) is read only.

[`stencilClearValue`], of type [GPUStencilValue](#typedefdef-gpustencilvalue), defaulting to `0`

: Indicates the value to clear
 [`view`](#dom-gpurenderpassdepthstencilattachment-view)'s stencil component to prior to executing the
 render pass. Ignored if
 [`stencilLoadOp`](#dom-gpurenderpassdepthstencilattachment-stencilloadop) is not
 [`"clear"`](#dom-gpuloadop-clear).

 The value will be converted to the type of the stencil aspect of
 `view` by taking the same number of LSBs as the number of
 bits in the stencil aspect of one
 [texel](#texel-block) of
 `view`.

[`stencilLoadOp`], of type [GPULoadOp](#enumdef-gpuloadop)

: Indicates the load operation to perform on
 [`view`](#dom-gpurenderpassdepthstencilattachment-view)'s stencil component prior to executing the render
 pass.

 It is recommended to prefer clearing; see
 [`"clear"`](#dom-gpuloadop-clear) for details.

[`stencilStoreOp`], of type [GPUStoreOp](#enumdef-gpustoreop)

: The store operation to perform on
 [`view`](#dom-gpurenderpassdepthstencilattachment-view)'s stencil component after executing the render
 pass.

[`stencilReadOnly`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Indicates that the stencil component of
 [`view`](#dom-gpurenderpassdepthstencilattachment-view) is read only.

[GPURenderPassDepthStencilAttachment Valid
Usage]

Given a
[`GPURenderPassDepthStencilAttachment`](#dictdef-gpurenderpassdepthstencilattachment) `this`, the following validation rules
apply:

- `this`.[`view`](#dom-gpurenderpassdepthstencilattachment-view) must have a [depth-or-stencil
 format](#depth-or-stencil-format).

- `this`.[`view`](#dom-gpurenderpassdepthstencilattachment-view) must be a [renderable texture
 view](#abstract-opdef-renderable-texture-view).

- Let `format` be
 `this`.[`view`](#dom-gpurenderpassdepthstencilattachment-view).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`format`](#dom-gputextureviewdescriptor-format).

- If
 `this`.[`depthLoadOp`](#dom-gpurenderpassdepthstencilattachment-depthloadop) is
 [`"clear"`](#dom-gpuloadop-clear),
 `this`.[`depthClearValue`](#dom-gpurenderpassdepthstencilattachment-depthclearvalue) must [be
 provided](https://infra.spec.whatwg.org/#map-exists) and must be between 0.0 and 1.0, inclusive.

- If `format` has a depth aspect and
 `this`.[`depthReadOnly`](#dom-gpurenderpassdepthstencilattachment-depthreadonly) is `false`:

 - `this`.[`depthLoadOp`](#dom-gpurenderpassdepthstencilattachment-depthloadop) must [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 - `this`.[`depthStoreOp`](#dom-gpurenderpassdepthstencilattachment-depthstoreop) must [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 Otherwise:

 - `this`.[`depthLoadOp`](#dom-gpurenderpassdepthstencilattachment-depthloadop) must not [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 - `this`.[`depthStoreOp`](#dom-gpurenderpassdepthstencilattachment-depthstoreop) must not [be
 provided](https://infra.spec.whatwg.org/#map-exists).

- If `format` has a stencil aspect and
 `this`.[`stencilReadOnly`](#dom-gpurenderpassdepthstencilattachment-stencilreadonly) is `false`:

 - `this`.[`stencilLoadOp`](#dom-gpurenderpassdepthstencilattachment-stencilloadop) must [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 - `this`.[`stencilStoreOp`](#dom-gpurenderpassdepthstencilattachment-stencilstoreop) must [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 Otherwise:

 - `this`.[`stencilLoadOp`](#dom-gpurenderpassdepthstencilattachment-stencilloadop) must not [be
 provided](https://infra.spec.whatwg.org/#map-exists).

 - `this`.[`stencilStoreOp`](#dom-gpurenderpassdepthstencilattachment-stencilstoreop) must not [be
 provided](https://infra.spec.whatwg.org/#map-exists).

##### 17.1.1.3. Load & Store Operations

```
enum GPULoadOp {
 "load",
 "clear",
};
```

[`"load"`]

: Loads the existing value for this attachment into the render pass.

[`"clear"`]

: Loads a clear value for this attachment into the render pass.

 On some GPU hardware (primarily mobile),
 [`"clear"`](#dom-gpuloadop-clear) is significantly cheaper because it avoids loading
 data from main memory into tile-local memory. On other GPU hardware,
 there isn't a significant difference. As a result, it is recommended
 to use
 [`"clear"`](#dom-gpuloadop-clear) rather than
 [`"load"`](#dom-gpuloadop-load) in cases where the initial value doesn't matter
 (e.g. the render target will be cleared using a skybox).

```
enum GPUStoreOp {
 "store",
 "discard",
};
```

[`"store"`]

: Stores the resulting value of the render pass for this attachment.

[`"discard"`]

: Discards the resulting value of the render pass for this attachment.

 Discarded attachments behave as if they are cleared
 to zero, but implementations are not required to perform a clear at
 the end of the render pass. Implementations which do not explicitly
 clear discarded attachments at the end of a pass must lazily clear
 them prior to the reading the attachment contents, which occurs via
 sampling, copies, attaching to a later render pass with
 [`"load"`](#dom-gpuloadop-load), displaying or reading back the canvas ([get a copy
 of the image contents of a
 context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context)), etc.

##### 17.1.1.4. Render Pass Layout

[`GPURenderPassLayout`](#dictdef-gpurenderpasslayout) declares the layout of the render targets of a
[`GPURenderBundle`](#gpurenderbundle). It is also used internally to describe
[`GPURenderPassEncoder`](#gpurenderpassencoder)
[layouts](#abstract-opdef-derive-render-targets-layout-from-pass) and
[`GPURenderPipeline`](#gpurenderpipeline)
[layouts](#abstract-opdef-derive-render-targets-layout-from-pipeline). It determines compatibility between render
passes, render bundles, and render pipelines.

```
dictionary GPURenderPassLayout
 : GPUObjectDescriptorBase {
 required sequence<GPUTextureFormat?> colorFormats;
 GPUTextureFormat depthStencilFormat;
 GPUSize32 sampleCount = 1;
};
```

[`colorFormats`], of type `sequence<GPUTextureFormat?>`

: A list of the
 [`GPUTextureFormat`](#enumdef-gputextureformat)s of the color attachments for this pass or bundle.

[`depthStencilFormat`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The
 [`GPUTextureFormat`](#enumdef-gputextureformat) of the depth/stencil attachment for this pass or
 bundle.

[`sampleCount`], of type [GPUSize32](#typedefdef-gpusize32), defaulting to `1`

: Number of samples per pixel in the attachments for this pass or
 bundle.

[`GPURenderPassLayout`](#dictdef-gpurenderpasslayout) values are [equal] if:

- Their
 [`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) and
 [`sampleCount`](#dom-gpurenderpasslayout-samplecount) are equal, and

- Their
 [`colorFormats`](#dom-gpurenderpasslayout-colorformats) are equal ignoring any trailing `null`s.

[derive render targets layout from
pass]

**Arguments:**

- [`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor) `descriptor`

**Returns:**
[`GPURenderPassLayout`](#dictdef-gpurenderpasslayout)

[Device timeline](#device-timeline) steps:

1. Let `layout` be a new
 [`GPURenderPassLayout`](#dictdef-gpurenderpasslayout) object.

2. For each `colorAttachment` in
 `descriptor`.[`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments):

 1. If `colorAttachment` is not `null`:

 1. Set
 `layout`.[`sampleCount`](#dom-gpurenderpasslayout-samplecount) to
 `colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view).[`[[texture]]`](#dom-gputextureview-texture-slot).[`sampleCount`](#dom-gputexture-samplecount).

 2. Append
 `colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view).[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`format`](#dom-gputextureviewdescriptor-format) to
 `layout`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats).

 Otherwise:

 1. Append `null` to
 `layout`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats).

3. Let `depthStencilAttachment` be
 `descriptor`.[`depthStencilAttachment`](#dom-gpurenderpassdescriptor-depthstencilattachment).

4. If `depthStencilAttachment` is not `null`:

 1. Let `view` be
 `depthStencilAttachment`.[`view`](#dom-gpurenderpassdepthstencilattachment-view).

 2. Set
 `layout`.[`sampleCount`](#dom-gpurenderpasslayout-samplecount) to
 `view`.[`[[texture]]`](#dom-gputextureview-texture-slot).[`sampleCount`](#dom-gputexture-samplecount).

 3. Set
 `layout`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) to
 `view`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`format`](#dom-gputextureviewdescriptor-format).

5. Return `layout`.

[derive render targets layout from
pipeline]

**Arguments:**

- [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor) `descriptor`

**Returns:**
[`GPURenderPassLayout`](#dictdef-gpurenderpasslayout)

[Device timeline](#device-timeline) steps:

1. Let `layout` be a new
 [`GPURenderPassLayout`](#dictdef-gpurenderpasslayout) object.

2. Set
 `layout`.[`sampleCount`](#dom-gpurenderpasslayout-samplecount) to
 `descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`count`](#dom-gpumultisamplestate-count).

3. If
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Set
 `layout`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) to
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).[`format`](#dom-gpudepthstencilstate-format).

4. If
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. For each `colorTarget` in
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets):

 1. Append
 `colorTarget`.[`format`](#dom-gpucolortargetstate-format) to
 `layout`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats) if `colorTarget` is not `null`,
 or append `null` otherwise.

5. Return `layout`.

#### 17.1.2. Finalization

The render pass encoder can be ended by calling
[`end()`](#dom-gpurenderpassencoder-end) once the user has finished recording commands for the
pass. Once
[`end()`](#dom-gpurenderpassencoder-end) has been called the render pass encoder can no longer
be used.

[`end()`]

: Completes recording of the render pass commands sequence.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Let `parentEncoder` be
 `this`.[`[[command_encoder]]`](#dom-gpurenderpassencoder-command_encoder-slot).

 2. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error) and return.

 ::: validusage
 - `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) must be
 \"[open](#encoder-state-open)\".

 - `parentEncoder`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) must be
 \"[locked](#encoder-state-locked)\".
 :::

 3. Set
 `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[ended](#encoder-state-ended)\".

 4. Set
 `parentEncoder`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[open](#encoder-state-open)\".

 5. [Extend](https://infra.spec.whatwg.org/#set-extend)
 `parentEncoder`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot) with
 `this`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot).

 6. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `parentEncoder` and return.

 ::: validusage
 - `this` must be
 [valid](#abstract-opdef-valid).

 - `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) must satisfy [usage scope
 validation](#usage-scope-validation).

 - `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot) must [be
 empty](https://infra.spec.whatwg.org/#list-is-empty).

 - `this`.[`[[occlusion_query_active]]`](#dom-gpurenderpassencoder-occlusion_query_active-slot) must be `false`.

 - `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) must be ≤
 `this`.[`[[maxDrawCount]]`](#dom-gpurenderpassencoder-maxdrawcount-slot).
 :::

 7. [Extend](https://infra.spec.whatwg.org/#list-extend)
 `parentEncoder`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot) with
 `this`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot).

 8. If
 `this`.[`[[endTimestampWrite]]`](#dom-gpurenderpassencoder-endtimestampwrite-slot) is not `null`:

 1. [Extend](https://infra.spec.whatwg.org/#list-extend)
 `parentEncoder`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot) with
 `this`.[`[[endTimestampWrite]]`](#dom-gpurenderpassencoder-endtimestampwrite-slot).

 9. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. For each non-`null` `colorAttachment` in
 `renderState`.[`[[colorAttachments]]`](#dom-renderstate-colorattachments-slot):

 1. Let `colorView` be
 `colorAttachment`.[`view`](#dom-gpurenderpasscolorattachment-view).

 2. If
 `colorView`.[`[[descriptor]]`](#dom-gputextureview-descriptor-slot).[`dimension`](#dom-gputextureviewdescriptor-dimension) is:

 [`"3d"`](#dom-gputextureviewdimension-3d)

 : Let `colorSubregion` be
 `colorAttachment`.[`depthSlice`](#dom-gpurenderpasscolorattachment-depthslice) of `colorView`.

 Otherwise

 : Let `colorSubregion` be
 `colorView`.

 3. If
 `colorAttachment`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget) is not `null`:

 1. Resolve the multiple samples of every
 [texel](#texel-block) of `colorSubregion` to a
 single sample and copy to
 `colorAttachment`.[`resolveTarget`](#dom-gpurenderpasscolorattachment-resolvetarget).

 4. If
 `colorAttachment`.[`storeOp`](#dom-gpurenderpasscolorattachment-storeop) is:

 [`"store"`](#dom-gpustoreop-store)

 : Ensure the contents of the [framebuffer
 memory](#framebuffer-memory) associated with
 `colorSubregion` are stored in
 `colorSubregion`.

 [`"discard"`](#dom-gpustoreop-discard)

 : Set every [texel](#texel-block) of `colorSubregion` to zero.

 2. Let `depthStencilAttachment` be
 `renderState`.[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot).

 3. If `depthStencilAttachment` is not `null`:

 1. If
 `depthStencilAttachment`.[`depthStoreOp`](#dom-gpurenderpassdepthstencilattachment-depthstoreop) is:

 Not [provided](https://infra.spec.whatwg.org/#map-exists)

 : [Assert](https://infra.spec.whatwg.org/#assert) that
 `depthStencilAttachment`.[`depthReadOnly`](#dom-gpurenderpassdepthstencilattachment-depthreadonly) is `true` and leave the
 [depth](#aspect-depth)
 [subresource](#gputextureview-subresources) of `depthStencilView`
 unchanged.

 [`"store"`](#dom-gpustoreop-store)

 : Ensure the contents of the [framebuffer
 memory](#framebuffer-memory) associated with the
 [depth](#aspect-depth)
 [subresource](#gputextureview-subresources) of `depthStencilView` are
 stored in `depthStencilView`.

 [`"discard"`](#dom-gpustoreop-discard)

 : Set every [texel](#texel-block) in the
 [depth](#aspect-depth)
 [subresource](#gputextureview-subresources) of `depthStencilView` to
 zero.

 2. If
 `depthStencilAttachment`.[`stencilStoreOp`](#dom-gpurenderpassdepthstencilattachment-stencilstoreop) is:

 Not [provided](https://infra.spec.whatwg.org/#map-exists)

 : [Assert](https://infra.spec.whatwg.org/#assert) that
 `depthStencilAttachment`.[`stencilReadOnly`](#dom-gpurenderpassdepthstencilattachment-stencilreadonly) is `true` and leave the
 [stencil](#aspect-stencil)
 [subresource](#gputextureview-subresources) of `depthStencilView`
 unchanged.

 [`"store"`](#dom-gpustoreop-store)

 : Ensure the contents of the [framebuffer
 memory](#framebuffer-memory) associated with the
 [stencil](#aspect-stencil)
 [subresource](#gputextureview-subresources) of `depthStencilView` are
 stored in `depthStencilView`.

 [`"discard"`](#dom-gpustoreop-discard)

 : Set every [texel](#texel-block) in the
 [stencil](#aspect-stencil)
 [subresource](#gputextureview-subresources) `depthStencilView` to zero.

 4. Let `renderState` be `null`.

 Discarded attachments behave as if they are cleared
 to zero, but implementations are not required to perform a clear at
 the end of the render pass. See the note on
 [`"discard"`](#dom-gpustoreop-discard) for additional details.

 [Read-only
 depth-stencil](#read-only-depth-stencil) attachments can be thought of as implicitly using
 the
 [`"store"`](#dom-gpustoreop-store) operation, but since their content is unchanged
 during the render pass implementations don't need to update the
 attachment. Validation that requires the store op to not be provided
 for read-only attachments is done in
 [GPURenderPassDepthStencilAttachment Valid
 Usage](#abstract-opdef-gpurenderpassdepthstencilattachment-gpurenderpassdepthstencilattachment-valid-usage).
 :::
 ::::::

### 17.2. `GPURenderCommandsMixin`

[`GPURenderCommandsMixin`](#gpurendercommandsmixin) defines rendering commands common to
[`GPURenderPassEncoder`](#gpurenderpassencoder) and
[`GPURenderBundleEncoder`](#gpurenderbundleencoder).

```
interface mixin GPURenderCommandsMixin {
 undefined setPipeline(GPURenderPipeline pipeline);

 undefined setIndexBuffer(GPUBuffer buffer, GPUIndexFormat indexFormat, optional GPUSize64 offset = 0, optional GPUSize64 size);
 undefined setVertexBuffer(GPUIndex32 slot, GPUBuffer? buffer, optional GPUSize64 offset = 0, optional GPUSize64 size);

 undefined draw(GPUSize32 vertexCount, optional GPUSize32 instanceCount = 1,
 optional GPUSize32 firstVertex = 0, optional GPUSize32 firstInstance = 0);
 undefined drawIndexed(GPUSize32 indexCount, optional GPUSize32 instanceCount = 1,
 optional GPUSize32 firstIndex = 0,
 optional GPUSignedOffset32 baseVertex = 0,
 optional GPUSize32 firstInstance = 0);

 undefined drawIndirect(GPUBuffer indirectBuffer, GPUSize64 indirectOffset);
 undefined drawIndexedIndirect(GPUBuffer indirectBuffer, GPUSize64 indirectOffset);
};
```

[`GPURenderCommandsMixin`](#gpurendercommandsmixin) assumes the presence of
[`GPUObjectBase`](#gpuobjectbase),
[`GPUCommandsMixin`](#gpucommandsmixin), and
[`GPUBindingCommandsMixin`](#gpubindingcommandsmixin) members on the same object. It must only be included by
interfaces which also include those mixins.

[`GPURenderCommandsMixin`](#gpurendercommandsmixin) has the following [device timeline
properties](#device-timeline-property):

[`[[layout]]`], of type [`GPURenderPassLayout`](#dictdef-gpurenderpasslayout), readonly

: The layout of the render pass.

[`[[depthReadOnly]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: If `true`, indicates that the depth component is not modified.

[`[[stencilReadOnly]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: If `true`, indicates that the stencil component is not modified.

[`[[usage scope]]`], of type [usage scope](#usage-scope), initially empty

: The [usage scope](#usage-scope) for this render pass or bundle.

[`[[pipeline]]`], of type [`GPURenderPipeline`](#gpurenderpipeline), initially `null`

: The current
 [`GPURenderPipeline`](#gpurenderpipeline).

[`[[index_buffer]]`], of type [`GPUBuffer`](#gpubuffer), initially `null`

: The current buffer to read index data from.

[`[[index_format]]`], of type [`GPUIndexFormat`](#enumdef-gpuindexformat)

: The format of the index data in
 [`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot).

[`[[index_buffer_offset]]`], of type [`GPUSize64`](#typedefdef-gpusize64)

: The offset in bytes of the section of
 [`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot) currently set.

[`[[index_buffer_size]]`], of type [`GPUSize64`](#typedefdef-gpusize64)

: The size in bytes of the section of
 [`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot) currently set, initially `0`.

[`[[vertex_buffers]]`], of type [ordered map](https://infra.spec.whatwg.org/#ordered-map)\<slot, [`GPUBuffer`](#gpubuffer)\>, initially empty

: The current [`GPUBuffer`](#gpubuffer)s to read vertex data from for each slot.

[`[[vertex_buffer_sizes]]`], of type [ordered map](https://infra.spec.whatwg.org/#ordered-map)\<slot, [`GPUSize64`](#typedefdef-gpusize64)\>, initially empty

: The size in bytes of the section of
 [`GPUBuffer`](#gpubuffer) currently set for each slot.

[`[[drawCount]]`], of type [`GPUSize64`](#typedefdef-gpusize64)

: The number of draw commands recorded in this encoder.

To [Enqueue a render command] on
[`GPURenderCommandsMixin`](#gpurendercommandsmixin) `encoder` which issues the steps of a [GPU
Command](#gpu-command)
`command` with
[RenderState](#renderstate)
`renderState`, run the following [device
timeline](#device-timeline)
steps:

1. [Append](https://infra.spec.whatwg.org/#list-append) `command` to
 `encoder`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot).

2. When `command` is executed as part of a
 [`GPUCommandBuffer`](#gpucommandbuffer) `commandBuffer`:

 1. Issue the steps of `command` with
 `commandBuffer`.[`[[renderState]]`](#dom-gpucommandbuffer-renderstate-slot) as `renderState`.

#### 17.2.1. Drawing

[`setPipeline(pipeline)`]

: Sets the current
 [`GPURenderPipeline`](#gpurenderpipeline).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the
 [GPURenderCommandsMixin.setPipeline(pipeline)](#dom-gpurendercommandsmixin-setpipeline) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`pipeline`]
 [`GPURenderPipeline`](#gpurenderpipeline)
 [✘]
 [✘]
 The render pipeline to use for subsequent drawing commands.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `pipelineTargetsLayout` be [derive render targets
 layout from
 pipeline](#abstract-opdef-derive-render-targets-layout-from-pipeline)(`pipeline`.[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot)).

 3. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `pipeline` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `this`.[`[[layout]]`](#dom-gpurendercommandsmixin-layout-slot)
 [equals](#render-pass-layout-equals) `pipelineTargetsLayout`.

 - If
 `pipeline`.[`[[writesDepth]]`](#dom-gpurenderpipeline-writesdepth-slot):
 `this`.[`[[depthReadOnly]]`](#dom-gpurendercommandsmixin-depthreadonly-slot) must be `false`.

 - If
 `pipeline`.[`[[writesStencil]]`](#dom-gpurenderpipeline-writesstencil-slot):
 `this`.[`[[stencilReadOnly]]`](#dom-gpurendercommandsmixin-stencilreadonly-slot) must be `false`.
 :::

 4. Set
 `this`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot) to be `pipeline`.
 :::
 :::::

[`setIndexBuffer(buffer, indexFormat, offset, size)`]

: Sets the current index buffer.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the [GPURenderCommandsMixin.setIndexBuffer(buffer,
 indexFormat, offset,
 size)](#dom-gpurendercommandsmixin-setindexbuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`buffer`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 Buffer containing index data to use for subsequent drawing commands.
 [`indexFormat`]
 [`GPUIndexFormat`](#enumdef-gpuindexformat)
 [✘]
 [✘]
 Format of the index data contained in `buffer`.
 [`offset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Offset in bytes into `buffer` where the index data
 begins. Defaults to `0`.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Size in bytes of the index data in `buffer`. Defaults to
 the size of the buffer minus the offset.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If `size` is missing, set `size` to max(0,
 `buffer`.[`size`](#dom-gpubuffer-size) - `offset`).

 3. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `buffer` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `buffer`.[`usage`](#dom-gpubuffer-usage) contains
 [`INDEX`](#dom-gpubufferusage-index).

 - `offset` is a multiple of
 `indexFormat`'s byte size.

 - `offset` + `size` ≤
 `buffer`.[`size`](#dom-gpubuffer-size).
 :::

 4. [Add](#abstract-opdef-usage-scope-add) `buffer` to
 [`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [input](#internal-usage-input).

 5. Set
 `this`.[`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot) to be `buffer`.

 6. Set
 `this`.[`[[index_format]]`](#dom-gpurendercommandsmixin-index_format-slot) to be `indexFormat`.

 7. Set
 `this`.[`[[index_buffer_offset]]`](#dom-gpurendercommandsmixin-index_buffer_offset-slot) to be `offset`.

 8. Set
 `this`.[`[[index_buffer_size]]`](#dom-gpurendercommandsmixin-index_buffer_size-slot) to be `size`.
 :::
 :::::

[`setVertexBuffer(slot, buffer, offset, size)`]

: Sets the current vertex buffer for the given slot.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the [GPURenderCommandsMixin.setVertexBuffer(slot,
 buffer, offset,
 size)](#dom-gpurendercommandsmixin-setvertexbuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`slot`]
 [`GPUIndex32`](#typedefdef-gpuindex32)
 [✘]
 [✘]
 The vertex buffer slot to set the vertex buffer for.
 [`buffer`]
 [`GPUBuffer`](#gpubuffer)`?`
 [✔]
 [✘]
 Buffer containing vertex data to use for subsequent drawing
 commands.
 [`offset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Offset in bytes into `buffer` where the vertex data
 begins. Defaults to `0`.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Size in bytes of the vertex data in `buffer`. Defaults to
 the size of the buffer minus the offset.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `bufferSize` be 0 if `buffer` is
 `null`, or
 `buffer`.[`size`](#dom-gpubuffer-size) if not.

 3. If `size` is missing, set `size` to max(0,
 `bufferSize` - `offset`).

 4. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `slot` must be \<
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxVertexBuffers`](#dom-supported-limits-maxvertexbuffers).

 - `offset` must be a multiple of 4.

 - `offset` + `size` must be ≤
 `bufferSize`.
 :::

 5. If `buffer` is `null`:

 1. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `this`.[`[[vertex_buffers]]`](#dom-gpurendercommandsmixin-vertex_buffers-slot)\[`slot`\].

 2. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `this`.[`[[vertex_buffer_sizes]]`](#dom-gpurendercommandsmixin-vertex_buffer_sizes-slot)\[`slot`\].

 Otherwise:

 1. If any of the following requirements are unmet,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `buffer` must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `buffer`.[`usage`](#dom-gpubuffer-usage) must contain
 [`VERTEX`](#dom-gpubufferusage-vertex).
 :::

 2. [Add](#abstract-opdef-usage-scope-add) `buffer` to
 [`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [input](#internal-usage-input).

 3. Set
 `this`.[`[[vertex_buffers]]`](#dom-gpurendercommandsmixin-vertex_buffers-slot)\[`slot`\] to be
 `buffer`.

 4. Set
 `this`.[`[[vertex_buffer_sizes]]`](#dom-gpurendercommandsmixin-vertex_buffer_sizes-slot)\[`slot`\] to be
 `size`.
 :::
 :::::

[`draw(vertexCount, instanceCount, firstVertex, firstInstance)`]

: Draws primitives. See [§ 23.2 Rendering](#rendering-operations) for
 the detailed specification.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the [GPURenderCommandsMixin.draw(vertexCount,
 instanceCount, firstVertex,
 firstInstance)](#dom-gpurendercommandsmixin-draw) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`vertexCount`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 The number of vertices to draw.
 [`instanceCount`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 The number of instances to draw.
 [`firstVertex`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 Offset into the vertex buffers, in vertices, to begin drawing from.
 [`firstInstance`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 First instance to draw.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. All of the requirements in the following steps `must`
 be met. If any are unmet,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 1. It `must` be [valid to
 draw](#abstract-opdef-valid-to-draw) with `this`.

 2. Let `buffers` be
 `this`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot).[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).[`vertex`](#dom-gpurenderpipelinedescriptor-vertex).[`buffers`](#dom-gpuvertexstate-buffers).

 3. For each
 [`GPUIndex32`](#typedefdef-gpuindex32) `slot` from `0` to
 `buffers`.[size](https://infra.spec.whatwg.org/#list-size) (non-inclusive):

 1. If `buffers`\[`slot`\] is `null`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `bufferSize` be
 `this`.[`[[vertex_buffer_sizes]]`](#dom-gpurendercommandsmixin-vertex_buffer_sizes-slot)\[`slot`\].

 3. Let `stride` be
 `buffers`\[`slot`\].[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride).

 4. Let `attributes` be
 `buffers`\[`slot`\].[`attributes`](#dom-gpuvertexbufferlayout-attributes)

 5. Let `lastStride` be the maximum value of
 (`attribute`.[`offset`](#dom-gpuvertexattribute-offset) +
 [byteSize](#abstract-opdef-gpuvertexformat-bytesize)(`attribute`.[`format`](#dom-gpuvertexattribute-format))) over each `attribute` in
 `attributes`, or 0 if `attributes`
 is
 [empty](https://infra.spec.whatwg.org/#list-empty).

 6. Let `strideCount` be computed based on
 `buffers`\[`slot`\].[`stepMode`](#dom-gpuvertexbufferlayout-stepmode):

 [`"vertex"`](#dom-gpuvertexstepmode-vertex)

 : `firstVertex` + `vertexCount`

 [`"instance"`](#dom-gpuvertexstepmode-instance)

 : `firstInstance` +
 `instanceCount`

 7. If `strideCount` ≠ `0`:

 1. (`strideCount` − `1`) ×
 `stride` + `lastStride`
 `must` be ≤ `bufferSize`.
 :::

 3. Increment
 `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) by 1.

 4. Let `bindingState` be a snapshot of
 `this`'s current state.

 5. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Draw `instanceCount` instances, starting with
 instance `firstInstance`, of primitives consisting of
 `vertexCount` vertices, starting with vertex
 `firstVertex`, with the states from
 `bindingState` and `renderState`.
 :::
 ::::::

[`drawIndexed(indexCount, instanceCount, firstIndex, baseVertex, firstInstance)`]

: Draws indexed primitives. See [§ 23.2
 Rendering](#rendering-operations) for the detailed specification.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the [GPURenderCommandsMixin.drawIndexed(indexCount,
 instanceCount, firstIndex, baseVertex,
 firstInstance)](#dom-gpurendercommandsmixin-drawindexed) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`indexCount`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 The number of indices to draw.
 [`instanceCount`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 The number of instances to draw.
 [`firstIndex`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 Offset into the index buffer, in indices, begin drawing from.
 [`baseVertex`]
 [`GPUSignedOffset32`](#typedefdef-gpusignedoffset32)
 [✘]
 [✔]
 Added to each index value before indexing into the vertex buffers.
 [`firstInstance`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✔]
 First instance to draw.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - It is [valid to draw
 indexed](#abstract-opdef-valid-to-draw-indexed) with `this`.

 - `firstIndex` + `indexCount` ≤
 `this`.[`[[index_buffer_size]]`](#dom-gpurendercommandsmixin-index_buffer_size-slot) ÷
 `this`.[`[[index_format]]`](#dom-gpurendercommandsmixin-index_format-slot)'s byte size;

 - Let `buffers` be
 `this`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot).[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).[`vertex`](#dom-gpurenderpipelinedescriptor-vertex).[`buffers`](#dom-gpuvertexstate-buffers).

 - For each
 [`GPUIndex32`](#typedefdef-gpuindex32) `slot` from `0` to
 `buffers`.[size](https://infra.spec.whatwg.org/#list-size) (non-inclusive):

 - If `buffers`\[`slot`\] is `null`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 - Let `bufferSize` be
 `this`.[`[[vertex_buffer_sizes]]`](#dom-gpurendercommandsmixin-vertex_buffer_sizes-slot)\[`slot`\].

 - Let `stride` be
 `buffers`\[`slot`\].[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride).

 - Let `lastStride` be
 max(`attribute`.[`offset`](#dom-gpuvertexattribute-offset) +
 [byteSize](#abstract-opdef-gpuvertexformat-bytesize)(`attribute`.[`format`](#dom-gpuvertexattribute-format))) for each `attribute` in
 `buffers`\[`slot`\].[`attributes`](#dom-gpuvertexbufferlayout-attributes).

 - Let `strideCount` be `firstInstance` +
 `instanceCount`.

 - If
 `buffers`\[`slot`\].[`stepMode`](#dom-gpuvertexbufferlayout-stepmode) is
 [`"instance"`](#dom-gpuvertexstepmode-instance) and `strideCount` ≠ `0`:

 - Ensure (`strideCount` − `1`) ×
 `stride` + `lastStride` ≤
 `bufferSize`.
 :::

 3. Increment
 `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) by 1.

 4. Let `bindingState` be a snapshot of
 `this`'s current state.

 5. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Draw `instanceCount` instances, starting with
 instance `firstInstance`, of primitives consisting of
 `indexCount` indexed vertices, starting with index
 `firstIndex` from vertex `baseVertex`,
 with the states from `bindingState` and
 `renderState`.
 :::

 WebGPU applications should never use index data
 with indices out of bounds of any bound vertex buffer that has
 [`GPUVertexStepMode`](#enumdef-gpuvertexstepmode)
 [`"vertex"`](#dom-gpuvertexstepmode-vertex). WebGPU implementations have different ways of
 handling this, and therefore a range of behaviors is allowed. Either
 the whole draw call is discarded, or the access to those attributes
 out of bounds is described by WGSL's [invalid memory
 reference](https://gpuweb.github.io/gpuweb/wgsl/#invalid-memory-reference).
 ::::::

[`drawIndirect(indirectBuffer, indirectOffset)`]

: Draws primitives using parameters read from a
 [`GPUBuffer`](#gpubuffer). See [§ 23.2 Rendering](#rendering-operations) for
 the detailed specification.

 The [indirect draw parameters] encoded in the
 buffer must be a tightly packed block of **four 32-bit unsigned
 integer values (16 bytes total)**, given in the same order as the
 arguments for
 [`draw()`](#dom-gpurendercommandsmixin-draw). For example:

 ``` highlight
 let drawIndirectParameters = new Uint32Array(4);
 drawIndirectParameters[0] = vertexCount;
 drawIndirectParameters[1] = instanceCount;
 drawIndirectParameters[2] = firstVertex;
 drawIndirectParameters[3] = firstInstance;
 ```

 The value corresponding to `firstInstance` must be 0, unless the
 [`"indirect-first-instance"`](#indirect-first-instance) [feature](#feature) is enabled. If the
 [`"indirect-first-instance"`](#indirect-first-instance) [feature](#feature) is not enabled and `firstInstance` is not zero the
 [`drawIndirect()`](#dom-gpurendercommandsmixin-drawindirect) call will be treated as a no-op.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the
 [GPURenderCommandsMixin.drawIndirect(indirectBuffer,
 indirectOffset)](#dom-gpurendercommandsmixin-drawindirect) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`indirectBuffer`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 Buffer containing the [indirect draw
 parameters](#indirect-draw-parameters).
 [`indirectOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in bytes into `indirectBuffer` where the drawing
 data begins.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - It is [valid to
 draw](#abstract-opdef-valid-to-draw) with `this`.

 - `indirectBuffer` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `indirectBuffer`.[`usage`](#dom-gpubuffer-usage) contains
 [`INDIRECT`](#dom-gpubufferusage-indirect).

 - `indirectOffset` + sizeof([indirect draw
 parameters](#indirect-draw-parameters)) ≤
 `indirectBuffer`.[`size`](#dom-gpubuffer-size).

 - `indirectOffset` is a multiple of 4.
 :::

 3. [Add](#abstract-opdef-usage-scope-add) `indirectBuffer` to
 [`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [input](#internal-usage-input).

 4. Increment
 `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) by 1.

 5. Let `bindingState` be a snapshot of
 `this`'s current state.

 6. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `vertexCount` be an unsigned 32-bit integer read
 from `indirectBuffer` at `indirectOffset`
 bytes.

 2. Let `instanceCount` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 (`indirectOffset` + 4) bytes.

 3. Let `firstVertex` be an unsigned 32-bit integer read
 from `indirectBuffer` at
 (`indirectOffset` + 8) bytes.

 4. Let `firstInstance` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 (`indirectOffset` + 12) bytes.

 5. Draw `instanceCount` instances, starting with
 instance `firstInstance`, of primitives consisting of
 `vertexCount` vertices, starting with vertex
 `firstVertex`, with the states from
 `bindingState` and `renderState`.
 :::
 ::::::

[`drawIndexedIndirect(indirectBuffer, indirectOffset)`]

: Draws indexed primitives using parameters read from a
 [`GPUBuffer`](#gpubuffer). See [§ 23.2 Rendering](#rendering-operations) for
 the detailed specification.

 The [indirect drawIndexed
 parameters] encoded in the buffer must be
 a tightly packed block of **five 32-bit values (20 bytes total)**,
 given in the same order as the arguments for
 [`drawIndexed()`](#dom-gpurendercommandsmixin-drawindexed). The value corresponding to `baseVertex` is a
 signed 32-bit integer, and all others are unsigned 32-bit integers.
 For example:

 ``` highlight
 let drawIndexedIndirectParameters = new Uint32Array(5);
 let drawIndexedIndirectParametersSigned = new Int32Array(drawIndexedIndirectParameters.buffer);
 drawIndexedIndirectParameters[0] = indexCount;
 drawIndexedIndirectParameters[1] = instanceCount;
 drawIndexedIndirectParameters[2] = firstIndex;
 // baseVertex is a signed value.
 drawIndexedIndirectParametersSigned[3] = baseVertex;
 drawIndexedIndirectParameters[4] = firstInstance;
 ```

 The value corresponding to `firstInstance` must be 0, unless the
 [`"indirect-first-instance"`](#indirect-first-instance) [feature](#feature) is enabled. If the
 [`"indirect-first-instance"`](#indirect-first-instance) [feature](#feature) is not enabled and `firstInstance` is not zero the
 [`drawIndexedIndirect()`](#dom-gpurendercommandsmixin-drawindexedindirect) call will be treated as a no-op.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) this.
 **Arguments:**

 Arguments for the
 [GPURenderCommandsMixin.drawIndexedIndirect(indirectBuffer,
 indirectOffset)](#dom-gpurendercommandsmixin-drawindexedindirect) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`indirectBuffer`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 Buffer containing the [indirect drawIndexed
 parameters](#indirect-drawindexed-parameters).
 [`indirectOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in bytes into `indirectBuffer` where the drawing
 data begins.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - It is [valid to draw
 indexed](#abstract-opdef-valid-to-draw-indexed) with `this`.

 - `indirectBuffer` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `indirectBuffer`.[`usage`](#dom-gpubuffer-usage) contains
 [`INDIRECT`](#dom-gpubufferusage-indirect).

 - `indirectOffset` + sizeof([indirect drawIndexed
 parameters](#indirect-drawindexed-parameters)) ≤
 `indirectBuffer`.[`size`](#dom-gpubuffer-size).

 - `indirectOffset` is a multiple of 4.
 :::

 3. [Add](#abstract-opdef-usage-scope-add) `indirectBuffer` to
 [`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) with usage
 [input](#internal-usage-input).

 4. Increment
 `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) by 1.

 5. Let `bindingState` be a snapshot of
 `this`'s current state.

 6. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `indexCount` be an unsigned 32-bit integer read
 from `indirectBuffer` at `indirectOffset`
 bytes.

 2. Let `instanceCount` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 (`indirectOffset` + 4) bytes.

 3. Let `firstIndex` be an unsigned 32-bit integer read
 from `indirectBuffer` at
 (`indirectOffset` + 8) bytes.

 4. Let `baseVertex` be a signed 32-bit integer read from
 `indirectBuffer` at
 (`indirectOffset` + 12) bytes.

 5. Let `firstInstance` be an unsigned 32-bit integer
 read from `indirectBuffer` at
 (`indirectOffset` + 16) bytes.

 6. Draw `instanceCount` instances, starting with
 instance `firstInstance`, of primitives consisting of
 `indexCount` indexed vertices, starting with index
 `firstIndex` from vertex `baseVertex`,
 with the states from `bindingState` and
 `renderState`.
 :::
 ::::::

To determine if it's [valid to draw] with
[`GPURenderCommandsMixin`](#gpurendercommandsmixin) `encoder`, run the following [device
timeline](#device-timeline)
steps:

1. If any of the following conditions are unsatisfied, return `false`:

 ::: validusage
 - [Validate encoder bind
 groups](#abstract-opdef-validate-encoder-bind-groups)(`encoder`,
 `encoder`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot)) must be `true`.

 - Let `pipelineDescriptor` be
 `encoder`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot).[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).

 - For each
 [`GPUIndex32`](#typedefdef-gpuindex32) `slot` `0` to
 `pipelineDescriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex).[`buffers`](#dom-gpuvertexstate-buffers).[size](https://infra.spec.whatwg.org/#list-size):

 - If
 `pipelineDescriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex).[`buffers`](#dom-gpuvertexstate-buffers)\[`slot`\] is not `null`,
 `encoder`.[`[[vertex_buffers]]`](#dom-gpurendercommandsmixin-vertex_buffers-slot) must
 [contain](https://infra.spec.whatwg.org/#map-exists) `slot`.

 - Validate
 [`maxBindGroupsPlusVertexBuffers`](#dom-supported-limits-maxbindgroupsplusvertexbuffers):

 1. Let `bindGroupSpaceUsed` be (the maximum key in
 `encoder`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot)) + 1.

 2. Let `vertexBufferSpaceUsed` be (the maximum key in
 `encoder`.[`[[vertex_buffers]]`](#dom-gpurendercommandsmixin-vertex_buffers-slot)) + 1.

 3. `bindGroupSpaceUsed` +
 `vertexBufferSpaceUsed` must be ≤
 `encoder`.[`[[device]]`](#dom-gpuobjectbase-device-slot).[`[[limits]]`](#dom-device-limits-slot).[`maxBindGroupsPlusVertexBuffers`](#dom-supported-limits-maxbindgroupsplusvertexbuffers).
 :::

 Otherwise, return `true`.

To determine if it's [valid to draw
indexed] with
[`GPURenderCommandsMixin`](#gpurendercommandsmixin) `encoder`, run the following [device
timeline](#device-timeline)
steps:

1. If any of the following conditions are unsatisfied, return `false`:

 ::: validusage
 - It must be [valid to
 draw](#abstract-opdef-valid-to-draw) with `encoder`.

 - `encoder`.[`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot) must not be `null`.

 - Let `topology` be
 `encoder`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot).[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`topology`](#dom-gpuprimitivestate-topology).

 - If `topology` is
 [`"line-strip"`](#dom-gpuprimitivetopology-line-strip) or
 [`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip):

 - `encoder`.[`[[index_format]]`](#dom-gpurendercommandsmixin-index_format-slot) must equal
 `encoder`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot).[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`stripIndexFormat`](#dom-gpuprimitivestate-stripindexformat).
 :::

 Otherwise, return `true`.

#### 17.2.2. Rasterization state

The
[`GPURenderPassEncoder`](#gpurenderpassencoder) has several methods which affect how draw commands are
rasterized to attachments used by this encoder.

[`setViewport(x, y, width, height, minDepth, maxDepth)`]

: Sets the viewport used during the rasterization stage to linearly
 map from [normalized device coordinates](#ndc) to [viewport
 coordinates](#viewport-coordinates).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) `this`.
 **Arguments:**

 Arguments for the [GPURenderPassEncoder.setViewport(x, y, width,
 height, minDepth,
 maxDepth)](#dom-gpurenderpassencoder-setviewport) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`x`]
 [`float`](https://webidl.spec.whatwg.org/#idl-float)
 [✘]
 [✘]
 Minimum X value of the viewport in pixels.
 [`y`]
 [`float`](https://webidl.spec.whatwg.org/#idl-float)
 [✘]
 [✘]
 Minimum Y value of the viewport in pixels.
 [`width`]
 [`float`](https://webidl.spec.whatwg.org/#idl-float)
 [✘]
 [✘]
 Width of the viewport in pixels.
 [`height`]
 [`float`](https://webidl.spec.whatwg.org/#idl-float)
 [✘]
 [✘]
 Height of the viewport in pixels.
 [`minDepth`]
 [`float`](https://webidl.spec.whatwg.org/#idl-float)
 [✘]
 [✘]
 Minimum depth value of the viewport.
 [`maxDepth`]
 [`float`](https://webidl.spec.whatwg.org/#idl-float)
 [✘]
 [✘]
 Maximum depth value of the viewport.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. Let `maxViewportRange` be
 `this`.[`limits`](#dom-gpudevice-limits).[`maxTextureDimension2D`](#dom-gpusupportedlimits-maxtexturedimension2d) × `2`.

 3. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `x` ≥ -`maxViewportRange`

 - `y` ≥ -`maxViewportRange`

 - `0` ≤ `width` ≤
 `this`.[`limits`](#dom-gpudevice-limits).[`maxTextureDimension2D`](#dom-gpusupportedlimits-maxtexturedimension2d)

 - `0` ≤ `height` ≤
 `this`.[`limits`](#dom-gpudevice-limits).[`maxTextureDimension2D`](#dom-gpusupportedlimits-maxtexturedimension2d)

 - `x` + `width` ≤
 `maxViewportRange` − `1`

 - `y` + `height` ≤
 `maxViewportRange` − `1`

 - `0.0` ≤ `minDepth` ≤ `1.0`

 - `0.0` ≤ `maxDepth` ≤ `1.0`

 - `minDepth` ≤ `maxDepth`
 :::

 4. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Round `x`, `y`, `width`, and
 `height` to some uniform precision, no less precise
 than integer rounding.

 2. Set
 `renderState`.[`[[viewport]]`](#dom-renderstate-viewport-slot) to the extents `x`, `y`,
 `width`, `height`, `minDepth`,
 and `maxDepth`.
 :::
 ::::::

[`setScissorRect(x, y, width, height)`]

: Sets the scissor rectangle used during the rasterization stage.
 After transformation into [viewport
 coordinates](#viewport-coordinates) any fragments which fall outside the scissor
 rectangle will be discarded.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) `this`.
 **Arguments:**

 Arguments for the [GPURenderPassEncoder.setScissorRect(x, y, width,
 height)](#dom-gpurenderpassencoder-setscissorrect) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`x`]
 [`GPUIntegerCoordinate`](#typedefdef-gpuintegercoordinate)
 [✘]
 [✘]
 Minimum X value of the scissor rectangle in pixels.
 [`y`]
 [`GPUIntegerCoordinate`](#typedefdef-gpuintegercoordinate)
 [✘]
 [✘]
 Minimum Y value of the scissor rectangle in pixels.
 [`width`]
 [`GPUIntegerCoordinate`](#typedefdef-gpuintegercoordinate)
 [✘]
 [✘]
 Width of the scissor rectangle in pixels.
 [`height`]
 [`GPUIntegerCoordinate`](#typedefdef-gpuintegercoordinate)
 [✘]
 [✘]
 Height of the scissor rectangle in pixels.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `x`+`width` ≤
 `this`.[`[[attachment_size]]`](#dom-gpurenderpassencoder-attachment_size-slot).width.

 - `y`+`height` ≤
 `this`.[`[[attachment_size]]`](#dom-gpurenderpassencoder-attachment_size-slot).height.
 :::

 3. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Set
 `renderState`.[`[[scissorRect]]`](#dom-renderstate-scissorrect-slot) to the extents `x`, `y`,
 `width`, and `height`.
 :::
 ::::::

[`setBlendConstant(color)`]

: Sets the constant blend color and alpha values used with
 [`"constant"`](#dom-gpublendfactor-constant) and
 [`"one-minus-constant"`](#dom-gpublendfactor-one-minus-constant)
 [`GPUBlendFactor`](#enumdef-gpublendfactor)s.

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) this.
 **Arguments:**

 Arguments for the
 [GPURenderPassEncoder.setBlendConstant(color)](#dom-gpurenderpassencoder-setblendconstant) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`color`]
 [`GPUColor`](#typedefdef-gpucolor)
 [✘]
 [✘]
 The color to use when blending.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUColor
 shape](#abstract-opdef-validate-gpucolor-shape)(`color`).

 2. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Set
 `renderState`.[`[[blendConstant]]`](#dom-renderstate-blendconstant-slot) to `color`.
 :::
 ::::::

[`setStencilReference(reference)`]

: Sets the
 [`[[stencilReference]]`](#dom-renderstate-stencilreference-slot) value used during stencil tests with the
 [`"replace"`](#dom-gpustenciloperation-replace)
 [`GPUStencilOperation`](#enumdef-gpustenciloperation).

 ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) this.
 **Arguments:**

 Arguments for the
 [GPURenderPassEncoder.setStencilReference(reference)](#dom-gpurenderpassencoder-setstencilreference) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`reference`]
 [`GPUStencilValue`](#typedefdef-gpustencilvalue)
 [✘]
 [✘]
 The new stencil reference value.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Set
 `renderState`.[`[[stencilReference]]`](#dom-renderstate-stencilreference-slot) to `reference`.
 :::
 ::::::

#### 17.2.3. Queries

[`beginOcclusionQuery(queryIndex)`]

: ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) `this`.
 **Arguments:**

 Arguments for the
 [GPURenderPassEncoder.beginOcclusionQuery(queryIndex)](#dom-gpurenderpassencoder-beginocclusionquery) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`queryIndex`]
 [`GPUSize32`](#typedefdef-gpusize32)
 [✘]
 [✘]
 The index of the query in the query set.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `this`.[`[[occlusion_query_set]]`](#dom-gpurenderpassencoder-occlusion_query_set-slot) is not `null`.

 - `queryIndex` \<
 `this`.[`[[occlusion_query_set]]`](#dom-gpurenderpassencoder-occlusion_query_set-slot).[`count`](#dom-gpuqueryset-count).

 - The query at same `queryIndex` must not have been
 previously written to in this pass.

 - `this`.[`[[occlusion_query_active]]`](#dom-gpurenderpassencoder-occlusion_query_active-slot) is `false`.
 :::

 3. Set
 `this`.[`[[occlusion_query_active]]`](#dom-gpurenderpassencoder-occlusion_query_active-slot) to `true`.

 4. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Set
 `renderState`.[`[[occlusionQueryIndex]]`](#dom-renderstate-occlusionqueryindex-slot) to `queryIndex`.
 :::
 ::::::

[`endOcclusionQuery()`]

: ::::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) this.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - `this`.[`[[occlusion_query_active]]`](#dom-gpurenderpassencoder-occlusion_query_active-slot) is `true`.
 :::

 3. Set
 `this`.[`[[occlusion_query_active]]`](#dom-gpurenderpassencoder-occlusion_query_active-slot) to `false`.

 4. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues the
 subsequent steps on the [Queue
 timeline](#queue-timeline) with `renderState` when executed.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `passingFragments` be non-zero if any fragment
 samples passed all per-fragment tests since the corresponding
 [`beginOcclusionQuery()`](#dom-gpurenderpassencoder-beginocclusionquery) command was executed, and zero otherwise.

 If no draw calls occurred,
 `passingFragments` is zero.

 2. Write `passingFragments` into
 `this`.[`[[occlusion_query_set]]`](#dom-gpurenderpassencoder-occlusion_query_set-slot) at index
 `renderState`.[`[[occlusionQueryIndex]]`](#dom-renderstate-occlusionqueryindex-slot).
 :::
 ::::::

#### 17.2.4. Bundles

[`executeBundles(bundles)`]

: Executes the commands previously recorded into the given
 [`GPURenderBundle`](#gpurenderbundle)s as part of this render pass.

 When a
 [`GPURenderBundle`](#gpurenderbundle) is executed, it does not inherit the render pass's
 pipeline, bind groups, or vertex and index buffers. After a
 [`GPURenderBundle`](#gpurenderbundle) has executed, the render pass's pipeline, bind
 group, and vertex/index buffer state is cleared (to the initial,
 empty values).

 The state is cleared, not restored to the previous
 state. This occurs even if zero
 [`GPURenderBundles`](#gpurenderbundle) are executed.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderPassEncoder`](#gpurenderpassencoder) this.
 **Arguments:**

 Arguments for the
 [GPURenderPassEncoder.executeBundles(bundles)](#dom-gpurenderpassencoder-executebundles) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`bundles`]
 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`GPURenderBundle`](#gpurenderbundle)`>`
 [✘]
 [✘]
 List of render bundles to execute.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. [Validate the encoder
 state](#abstract-opdef-validate-the-encoder-state) of `this`. If it returns
 false, return.

 2. If any of the following conditions are unsatisfied,
 [invalidate](#abstract-opdef-invalidate) `this` and return.

 ::: validusage
 - For each `bundle` in `bundles`:

 - `bundle` must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `this`.[`[[layout]]`](#dom-gpurendercommandsmixin-layout-slot) must equal
 `bundle`.[`[[layout]]`](#dom-gpurenderbundle-layout-slot).

 - If
 `this`.[`[[depthReadOnly]]`](#dom-gpurendercommandsmixin-depthreadonly-slot) is true,
 `bundle`.[`[[depthReadOnly]]`](#dom-gpurenderbundle-depthreadonly-slot) must be true.

 - If
 `this`.[`[[stencilReadOnly]]`](#dom-gpurendercommandsmixin-stencilreadonly-slot) is true,
 `bundle`.[`[[stencilReadOnly]]`](#dom-gpurenderbundle-stencilreadonly-slot) must be true.
 :::

 3. For each `bundle` in `bundles`:

 1. Increment
 `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) by
 `bundle`.[`[[drawCount]]`](#dom-gpurenderbundle-drawcount-slot).

 2. [Merge](#abstract-opdef-usage-scope-merge)
 `bundle`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) into
 `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot).

 3. [Extend](https://infra.spec.whatwg.org/#set-extend)
 `this`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot) with
 `bundle`.[`[[used_bind_groups]]`](#dom-gpurenderbundle-used_bind_groups-slot)

 4. [Enqueue a render
 command](#abstract-opdef-enqueue-a-render-command) on `this` which issues
 the following steps on the [Queue
 timeline](#queue-timeline) with `renderState` when
 executed:

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Execute each command in
 `bundle`.[`[[command_list]]`](#dom-gpurenderbundle-command_list-slot) with `renderState`.

 `renderState` cannot be
 changed by executing render bundles. Binding state was
 already captured at bundle encoding time, and so isn't
 used when executing bundles.
 :::

 4. [Reset the render pass binding
 state](#abstract-opdef-reset-the-render-pass-binding-state) of `this`.
 :::
 :::::

To [Reset the render pass binding
state] of
[`GPURenderPassEncoder`](#gpurenderpassencoder) `encoder` run the following [device
timeline](#device-timeline)
steps:

1. [Clear](https://infra.spec.whatwg.org/#map-clear)
 `encoder`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot).

2. Set
 `encoder`.[`[[pipeline]]`](#dom-gpurendercommandsmixin-pipeline-slot) to `null`.

3. Set
 `encoder`.[`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot) to `null`.

4. [Clear](https://infra.spec.whatwg.org/#map-clear)
 `encoder`.[`[[vertex_buffers]]`](#dom-gpurendercommandsmixin-vertex_buffers-slot).

## 18. Bundles

A bundle is a partial, limited pass that is encoded once and can then be
executed multiple times as part of future pass encoders without expiring
after use like typical command buffers. This can reduce the overhead of
encoding and submission of commands which are issued repeatedly without
changing.

### 18.1. `GPURenderBundle`

```
[Exposed=(Window, Worker), SecureContext]
interface GPURenderBundle ;
GPURenderBundle includes GPUObjectBase;
```

[`[[command_list]]`], of type [list](https://infra.spec.whatwg.org/#list)\<[GPU command](#gpu-command)\>

: A [list](https://infra.spec.whatwg.org/#list) of [GPU
 commands](#gpu-command) to
 be submitted to the
 [`GPURenderPassEncoder`](#gpurenderpassencoder) when the
 [`GPURenderBundle`](#gpurenderbundle) is executed.

[`[[used_bind_groups]]`], of type [set](https://infra.spec.whatwg.org/#ordered-set)\<[`GPUBindGroup`](#gpubindgroup)\>, readonly

: A
 [set](https://infra.spec.whatwg.org/#ordered-set) of all
 [`GPUBindGroup`](#gpubindgroup)s used by this render bundle.

[`[[usage scope]]`], of type [usage scope](#usage-scope), initially empty

: The [usage scope](#usage-scope) for this render bundle, stored for later merging
 into the
 [`GPURenderPassEncoder`](#gpurenderpassencoder)'s
 [`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) in
 [`executeBundles()`](#dom-gpurenderpassencoder-executebundles).

[`[[layout]]`], of type [`GPURenderPassLayout`](#dictdef-gpurenderpasslayout)

: The layout of the render bundle.

[`[[depthReadOnly]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

: If `true`, indicates that the depth component is not modified by
 executing this render bundle.

[`[[stencilReadOnly]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean)

: If `true`, indicates that the stencil component is not modified by
 executing this render bundle.

[`[[drawCount]]`], of type [`GPUSize64`](#typedefdef-gpusize64)

: The number of draw commands in this
 [`GPURenderBundle`](#gpurenderbundle).

#### 18.1.1. Render Bundle Creation

```
dictionary GPURenderBundleDescriptor
 : GPUObjectDescriptorBase ;
```

```
[Exposed=(Window, Worker), SecureContext]
interface GPURenderBundleEncoder {
 GPURenderBundle finish(optional GPURenderBundleDescriptor descriptor = );
};
GPURenderBundleEncoder includes GPUObjectBase;
GPURenderBundleEncoder includes GPUCommandsMixin;
GPURenderBundleEncoder includes GPUDebugCommandsMixin;
GPURenderBundleEncoder includes GPUBindingCommandsMixin;
GPURenderBundleEncoder includes GPURenderCommandsMixin;
```

[`createRenderBundleEncoder(descriptor)`]

: Creates a
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.createRenderBundleEncoder(descriptor)](#dom-gpudevice-createrenderbundleencoder) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPURenderBundleEncoderDescriptor`](#dictdef-gpurenderbundleencoderdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder) to create.
 **Returns:**
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture format
 required
 features](#abstract-opdef-validate-texture-format-required-features) of each non-`null` element of
 `descriptor`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 2. If
 `descriptor`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture
 format required
 features](#abstract-opdef-validate-texture-format-required-features) of
 `descriptor`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) with
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 3. Let `e` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder), `descriptor`).

 4. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 5. Return `e`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following conditions are unsatisfied [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `e` and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - `descriptor`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats).[size](https://infra.spec.whatwg.org/#list-size) must be ≤
 `this`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachments`](#dom-supported-limits-maxcolorattachments).

 - For each non-`null` `colorFormat` in
 `descriptor`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats):

 - `colorFormat` must be a [color renderable
 format](#color-renderable-format).

 - [Calculating color attachment bytes per
 sample](#abstract-opdef-calculating-color-attachment-bytes-per-sample)(`descriptor`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats)) must be ≤
 `this`.[`[[limits]]`](#dom-device-limits-slot).[`maxColorAttachmentBytesPerSample`](#dom-supported-limits-maxcolorattachmentbytespersample).

 - If
 `descriptor`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - `descriptor`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat) must be a [depth-or-stencil
 format](#depth-or-stencil-format).

 - There must exist at least one attachment, either:

 - A non-`null` value in
 `descriptor`.[`colorFormats`](#dom-gpurenderpasslayout-colorformats), or

 - A
 `descriptor`.[`depthStencilFormat`](#dom-gpurenderpasslayout-depthstencilformat).
 :::

 2. Set
 `e`.[`[[layout]]`](#dom-gpurendercommandsmixin-layout-slot) to a copy of `descriptor`'s included
 [`GPURenderPassLayout`](#dictdef-gpurenderpasslayout) interface.

 3. Set
 `e`.[`[[depthReadOnly]]`](#dom-gpurendercommandsmixin-depthreadonly-slot) to
 `descriptor`.[`depthReadOnly`](#dom-gpurenderbundleencoderdescriptor-depthreadonly).

 4. Set
 `e`.[`[[stencilReadOnly]]`](#dom-gpurendercommandsmixin-stencilreadonly-slot) to
 `descriptor`.[`stencilReadOnly`](#dom-gpurenderbundleencoderdescriptor-stencilreadonly).

 5. Set
 `e`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[open](#encoder-state-open)\".

 6. Set
 `e`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot) to 0.
 :::
 :::::

#### 18.1.2. Encoding

```
dictionary GPURenderBundleEncoderDescriptor
 : GPURenderPassLayout {
 boolean depthReadOnly = false;
 boolean stencilReadOnly = false;
};
```

[`depthReadOnly`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: If `true`, indicates that the render bundle does not modify the
 depth component of the
 [`GPURenderPassDepthStencilAttachment`](#dictdef-gpurenderpassdepthstencilattachment) of any render pass the render bundle is executed
 in.

 See [read-only
 depth-stencil](#read-only-depth-stencil).

[`stencilReadOnly`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: If `true`, indicates that the render bundle does not modify the
 stencil component of the
 [`GPURenderPassDepthStencilAttachment`](#dictdef-gpurenderpassdepthstencilattachment) of any render pass the render bundle is executed
 in.

 See [read-only
 depth-stencil](#read-only-depth-stencil).

#### 18.1.3. Finalization

[`finish(descriptor)`]

: Completes recording of the render bundle commands sequence.

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPURenderBundleEncoder`](#gpurenderbundleencoder) this.
 **Arguments:**

 Arguments for the
 [GPURenderBundleEncoder.finish(descriptor)](#dom-gpurenderbundleencoder-finish) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPURenderBundleDescriptor`](#dictdef-gpurenderbundledescriptor)
 [✘]
 [✔]
 **Returns:**
 [`GPURenderBundle`](#gpurenderbundle)

 [Content timeline](#content-timeline) steps:

 1. Let `renderBundle` be a new
 [`GPURenderBundle`](#gpurenderbundle).

 2. Issue the `finish steps` on the [Device
 timeline](#device-timeline) of
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 3. Return `renderBundle`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `finish steps`:
 1. Let `validationSucceeded` be `true` if all of the
 following requirements are met, and `false` otherwise.

 ::: validusage
 - `this` must be
 [valid](#abstract-opdef-valid).

 - `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot) must satisfy [usage scope
 validation](#usage-scope-validation).

 - `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) must be
 \"[open](#encoder-state-open)\".

 - `this`.[`[[debug_group_stack]]`](#dom-gpudebugcommandsmixin-debug_group_stack-slot) must [be
 empty](https://infra.spec.whatwg.org/#list-is-empty).
 :::

 2. Set
 `this`.[`[[state]]`](#dom-gpucommandsmixin-state-slot) to
 \"[ended](#encoder-state-ended)\".

 3. If `validationSucceeded` is `false`, then:

 1. [Generate a validation
 error](#abstract-opdef-generate-a-validation-error).

 2. Return an
 [invalidated](#abstract-opdef-invalidate)
 [`GPURenderBundle`](#gpurenderbundle).

 4. Set
 `renderBundle`.[`[[command_list]]`](#dom-gpurenderbundle-command_list-slot) to
 `this`.[`[[commands]]`](#dom-gpucommandsmixin-commands-slot).

 5. Set
 `renderBundle`.[`[[used_bind_groups]]`](#dom-gpurenderbundle-used_bind_groups-slot) to
 `this`.[`[[used_bind_groups]]`](#dom-gpucommandsmixin-used_bind_groups-slot).

 6. Set
 `renderBundle`.[`[[usage scope]]`](#dom-gpurenderbundle-usage-scope-slot) to
 `this`.[`[[usage scope]]`](#dom-gpurendercommandsmixin-usage-scope-slot).

 7. Set
 `renderBundle`.[`[[drawCount]]`](#dom-gpurenderbundle-drawcount-slot) to
 `this`.[`[[drawCount]]`](#dom-gpurendercommandsmixin-drawcount-slot).
 :::
 :::::

## 19. Queues

### 19.1. `GPUQueueDescriptor`

[`GPUQueueDescriptor`](#gpuqueuedescriptor) describes a queue request.

```
dictionary GPUQueueDescriptor
 : GPUObjectDescriptorBase ;
```

### 19.2. `GPUQueue`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUQueue {
 undefined submit(sequence<GPUCommandBuffer> commandBuffers);

 Promise<undefined> onSubmittedWorkDone();

 undefined writeBuffer(
 GPUBuffer buffer,
 GPUSize64 bufferOffset,
 AllowSharedBufferSource data,
 optional GPUSize64 dataOffset = 0,
 optional GPUSize64 size);

 undefined writeTexture(
 GPUTexelCopyTextureInfo destination,
 AllowSharedBufferSource data,
 GPUTexelCopyBufferLayout dataLayout,
 GPUExtent3D size);

 undefined copyExternalImageToTexture(
 GPUCopyExternalImageSourceInfo source,
 GPUCopyExternalImageDestInfo destination,
 GPUExtent3D copySize);
};
GPUQueue includes GPUObjectBase;
```

[`GPUQueue`](#gpuqueue) has
the following methods:

[`writeBuffer(buffer, bufferOffset, data, dataOffset, size)`]

: Issues a write operation of the provided data into a
 [`GPUBuffer`](#gpubuffer).

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUQueue`](#gpuqueue) `this`.
 **Arguments:**

 Arguments for the [GPUQueue.writeBuffer(buffer, bufferOffset, data,
 dataOffset,
 size)](#dom-gpuqueue-writebuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`buffer`]
 [`GPUBuffer`](#gpubuffer)
 [✘]
 [✘]
 The buffer to write to.
 [`bufferOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✘]
 Offset in bytes into `buffer` to begin writing at.
 [`data`]
 [`AllowSharedBufferSource`](https://webidl.spec.whatwg.org/#AllowSharedBufferSource)
 [✘]
 [✘]
 Data to write into `buffer`.
 [`dataOffset`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Offset in into `data` to begin writing from. Given in
 elements if `data` is a `TypedArray` and bytes otherwise.
 [`size`]
 [`GPUSize64`](#typedefdef-gpusize64)
 [✘]
 [✔]
 Size of content to write from `data` to
 `buffer`. Given in elements if `data` is a
 `TypedArray` and bytes otherwise.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. If `data` is an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) or
 [`DataView`](https://webidl.spec.whatwg.org/#idl-DataView), let the element type be \"byte\". Otherwise,
 `data` is a TypedArray; let the element type be the
 type of the TypedArray.

 2. Let `dataSize` be the size of `data`, in
 elements.

 3. If `size` is missing, let `contentsSize`
 be `dataSize` − `dataOffset`. Otherwise,
 let `contentsSize` be `size`.

 4. If any of the following conditions are unsatisfied, throw an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror) and return.

 ::: validusage
 - `contentsSize` ≥ 0.

 - `dataOffset` + `contentsSize` ≤
 `dataSize`.

 - `contentsSize`, converted to bytes, is a multiple
 of 4 bytes.
 :::

 5. Let `dataContents` be [a copy of the bytes held by
 the buffer
 source](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `data`.

 6. Let `contents` be the `contentsSize`
 elements of `dataContents` starting at an offset of
 `dataOffset` elements.

 7. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. If any of the following conditions are unsatisfied, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error) and return.

 ::: validusage
 - `buffer` is [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - `buffer`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) is
 \"[available](#gpubuffer-internal-state-available)\".

 - `buffer`.[`usage`](#dom-gpubuffer-usage) includes
 [`COPY_DST`](#dom-gpubufferusage-copy_dst).

 - `bufferOffset`, converted to bytes, is a multiple
 of 4 bytes.

 - `bufferOffset` + `contentsSize`,
 converted to bytes, ≤
 `buffer`.[`size`](#dom-gpubuffer-size) bytes.
 :::

 2. Issue the subsequent steps on the [Queue
 timeline](#queue-timeline) of `this`.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Write `contents` into `buffer` starting at
 `bufferOffset`.
 :::
 ::::::

[`writeTexture(destination, data, dataLayout, size)`]

: Issues a write operation of the provided data into a
 [`GPUTexture`](#gputexture).

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUQueue`](#gpuqueue) `this`.
 **Arguments:**

 Arguments for the [GPUQueue.writeTexture(destination, data,
 dataLayout,
 size)](#dom-gpuqueue-writetexture) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`destination`]
 [`GPUTexelCopyTextureInfo`](#gputexelcopytextureinfo)
 [✘]
 [✘]
 The [texture
 subresource](#texture-subresources) and origin to write to.
 [`data`]
 [`AllowSharedBufferSource`](https://webidl.spec.whatwg.org/#AllowSharedBufferSource)
 [✘]
 [✘]
 Data to write into `destination`.
 [`dataLayout`]
 [`GPUTexelCopyBufferLayout`](#gputexelcopybufferlayout)
 [✘]
 [✘]
 Layout of the content in `data`.
 [`size`]
 [`GPUExtent3D`](#typedefdef-gpuextent3d)
 [✘]
 [✘]
 Extents of the content to write from `data` to
 `destination`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin3D
 shape](#abstract-opdef-validate-gpuorigin3d-shape)(`destination`.[`origin`](#dom-gputexelcopytextureinfo-origin)).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUExtent3D
 shape](#abstract-opdef-validate-gpuextent3d-shape)(`size`).

 3. Let `dataBytes` be [a copy of the bytes held by the
 buffer
 source](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) `data`.

 This is described as copying all of
 `data` to the device timeline, but in practice
 `data` could be much larger than necessary.
 Implementations should optimize by copying only the necessary
 bytes.

 4. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Let `aligned` be `false`.

 2. Let `dataLength` be
 `dataBytes`.[length](https://infra.spec.whatwg.org/#byte-sequence-length).

 3. If any of the following conditions are unsatisfied, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error) and return.

 ::: validusage
 - `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).[`[[destroyed]]`](#dom-gputexture-destroyed-slot) is `false`.

 - [validating texture buffer
 copy](#abstract-opdef-validating-texture-buffer-copy)(`destination`,
 `dataLayout`, `dataLength`,
 `size`,
 [`COPY_DST`](#dom-gputextureusage-copy_dst), `aligned`) returns `true`.

 unlike
 [`GPUCommandEncoder`](#gpucommandencoder).[`copyBufferToTexture()`](#dom-gpucommandencoder-copybuffertotexture), there is no alignment requirement on either
 `dataLayout`.[`bytesPerRow`](#dom-gputexelcopybufferlayout-bytesperrow) or
 `dataLayout`.[`offset`](#dom-gputexelcopybufferlayout-offset).
 :::

 4. Issue the subsequent steps on the [Queue
 timeline](#queue-timeline) of `this`.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. Let `blockWidth` be the [texel block
 width](#texel-block-width) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Let `blockHeight` be the [texel block
 height](#texel-block-height) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 3. Let `dstOrigin` be
 `destination`.[`origin`](#dom-gputexelcopytextureinfo-origin);

 4. Let `dstBlockOriginX` be
 (`dstOrigin`.[x](#gpuorigin3d-x) ÷ `blockWidth`).

 5. Let `dstBlockOriginY` be
 (`dstOrigin`.[y](#gpuorigin3d-y) ÷ `blockHeight`).

 6. Let `blockColumns` be
 (`copySize`.[width](#gpuextent3d-width) ÷ `blockWidth`).

 7. Let `blockRows` be
 (`copySize`.[height](#gpuextent3d-height) ÷ `blockHeight`).

 8. [Assert](https://infra.spec.whatwg.org/#assert) that `dstBlockOriginX`,
 `dstBlockOriginY`, `blockColumns`, and
 `blockRows` are integers.

 9. For each `z` in the range \[0,
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) − 1\]:

 1. Let `dstSubregion` be [texture copy
 sub-region](#abstract-opdef-texture-copy-sub-region) (`z` +
 `dstOrigin`.[z](#gpuorigin3d-z)) of `destination`.

 2. For each `y` in the range \[0,
 `blockRows` − 1\]:

 1. For each `x` in the range \[0,
 `blockColumns` − 1\]:

 1. Let `blockOffset` be the [texel block
 byte
 offset](#abstract-opdef-texel-block-byte-offset) of `dataLayout`
 for (`x`, `y`, `z`)
 of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. Set [texel
 block](#texel-block) (`dstBlockOriginX` +
 `x`, `dstBlockOriginY` +
 `y`) of `dstSubregion` to be
 an [equivalent texel
 representation](#equivalent-texel-representation) to the [texel
 block](#texel-block) described by `dataBytes`
 at offset `blockOffset`.
 :::
 ::::::

[`copyExternalImageToTexture(source, destination, copySize)`]

: Issues a copy operation of the contents of a platform image/canvas
 into the destination texture.

 This operation performs [color encoding](#color-space-conversions)
 into the destination encoding according to the parameters of
 [`GPUCopyExternalImageDestInfo`](#gpucopyexternalimagedestinfo).

 Copying into a `-srgb` texture results in the same texture bytes,
 not the same decoded values, as copying into the corresponding
 non-`-srgb` format. Thus, after a copy operation, sampling the
 destination texture has different results depending on whether its
 format is `-srgb`, all else unchanged.

 ::::
 ::: marker
 NOTE:
 :::

 When copying from a `"webgl"`/`"webgl2"` context canvas, the [WebGL
 Drawing
 Buffer](https://www.khronos.org/registry/webgl/specs/latest/1.0/#THE_DRAWING_BUFFER) may be not exist during certain points in the frame
 presentation cycle (after the image has been moved to the compositor
 for display). To avoid this, either:
 - Issue
 [`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture) in the same
 [task](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task) with WebGL rendering operation, to ensure the
 copy occurs before the WebGL canvas is presented.

 - If not possible, set the `preserveDrawingBuffer` option in
 [`WebGLContextAttributes`](https://www.khronos.org/registry/webgl/specs/latest/1.0/#WEBGLCONTEXTATTRIBUTES) to `true`, so that the drawing buffer will still
 contain a copy of the frame contents after they've been presented.
 Note, this extra copy may have a performance cost.
 ::::

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUQueue`](#gpuqueue) `this`.
 **Arguments:**

 Arguments for the [GPUQueue.copyExternalImageToTexture(source,
 destination,
 copySize)](#dom-gpuqueue-copyexternalimagetotexture) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`source`]
 [`GPUCopyExternalImageSourceInfo`](#gpucopyexternalimagesourceinfo)
 [✘]
 [✘]
 source image and origin to copy to `destination`.
 [`destination`]
 [`GPUCopyExternalImageDestInfo`](#gpucopyexternalimagedestinfo)
 [✘]
 [✘]
 The [texture
 subresource](#texture-subresources) and origin to write to, and its encoding metadata.
 [`copySize`]
 [`GPUExtent3D`](#typedefdef-gpuextent3d)
 [✘]
 [✘]
 Extents of the content to write from `source` to
 `destination`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin2D
 shape](#abstract-opdef-validate-gpuorigin2d-shape)(`source`.[`origin`](#dom-gpucopyexternalimagesourceinfo-origin)).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUOrigin3D
 shape](#abstract-opdef-validate-gpuorigin3d-shape)(`destination`.[`origin`](#dom-gputexelcopytextureinfo-origin)).

 3. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [validate GPUExtent3D
 shape](#abstract-opdef-validate-gpuextent3d-shape)(`copySize`).

 4. Let `sourceImage` be
 `source`.[`source`](#dom-gpucopyexternalimagesourceinfo-source)

 5. If `sourceImage` [is not
 origin-clean](https://html.spec.whatwg.org/multipage/canvas.html#the-image-argument-is-not-origin-clean), throw a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) and return.

 6. If any of the following requirements are unmet, throw an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror) and return.

 ::: validusage
 - `source`.`origin`.[x](#gpuorigin2d-x) +
 `copySize`.[width](#gpuextent3d-width) must be ≤ the width of
 `sourceImage`.

 - `source`.`origin`.[y](#gpuorigin2d-y) +
 `copySize`.[height](#gpuextent3d-height) must be ≤ the height of
 `sourceImage`.

 - `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) must be ≤ 1.
 :::

 7. Let `usability` be
 [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [check the usability of
 the image
 argument](https://html.spec.whatwg.org/multipage/canvas.html#check-the-usability-of-the-image-argument)(`source`).

 8. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Let `texture` be
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture).

 2. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error) and return.

 ::: validusage
 - `usability` must be `good`.

 - `texture`.[`[[destroyed]]`](#dom-gputexture-destroyed-slot) must be `false`.

 - `texture` must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`.

 - [validating
 GPUTexelCopyTextureInfo](#abstract-opdef-validating-gputexelcopytextureinfo)(destination, copySize) must return
 `true`.

 - `texture`.[`usage`](#dom-gputexture-usage) must include both
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) and
 [`COPY_DST`](#dom-gputextureusage-copy_dst).

 - `texture`.[`dimension`](#dom-gputexture-dimension) must be
 [`"2d"`](#dom-gputexturedimension-2d).

 - `texture`.[`sampleCount`](#dom-gputexture-samplecount) must be 1.

 - `texture`.[`format`](#dom-gputexture-format) must be a [plain color
 format](#plain-color-formats) supporting
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) and be a `unorm`/`unorm-srgb` or
 `float`/`ufloat` format (not `snorm`, `uint`, or `sint`).
 :::

 3. If
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) is \> 0, issue the subsequent steps on the
 [Queue timeline](#queue-timeline) of `this`.
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. [Assert](https://infra.spec.whatwg.org/#assert) that the [texel block
 width](#texel-block-width) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture) is 1, the [texel block
 height](#texel-block-height) of
 `destination`.[`texture`](#dom-gputexelcopytextureinfo-texture) is 1, and that
 `copySize`.[depthOrArrayLayers](#gpuextent3d-depthorarraylayers) is 1.

 2. Let `srcOrigin` be
 `source`.[`origin`](#dom-gpucopyexternalimagesourceinfo-origin).

 3. Let `dstOrigin` be
 `destination`.[`origin`](#dom-gputexelcopytextureinfo-origin).

 4. Let `dstSubregion` be [texture copy
 sub-region](#abstract-opdef-texture-copy-sub-region)
 (`dstOrigin`.[z](#gpuorigin3d-z)) of `destination`.

 5. For each `y` in the range \[0,
 `copySize`.[height](#gpuextent3d-height) − 1\]:

 1. Let `srcY` be `y` if
 `source`.[`flipY`](#dom-gpucopyexternalimagesourceinfo-flipy) is `false` and
 (`copySize`.[height](#gpuextent3d-height) − 1 − `y`) otherwise.

 2. For each `x` in the range \[0,
 `copySize`.[width](#gpuextent3d-width) − 1\]:

 1. Let `srcColor` be the [color-managed color
 value](#color-spaces) of the pixel at
 (`srcOrigin`.[x](#gpuorigin2d-x) + `x`,
 `srcOrigin`.[y](#gpuorigin2d-y) + `srcY`) of
 `source`.[`source`](#dom-gpucopyexternalimagesourceinfo-source).

 2. Let `dstColor` be the numeric RGBA value
 resulting from applying any [color
 encoding](#color-space-conversions) required by
 `destination`.[`colorSpace`](#dom-gpucopyexternalimagedestinfo-colorspace) and
 `destination`.[`premultipliedAlpha`](#dom-gpucopyexternalimagedestinfo-premultipliedalpha) to `srcColor`.

 3. If
 `texture`.[`format`](#dom-gputexture-format) is an `-srgb` format:

 1. Set `dstColor` to the result of applying
 the sRGB non-linear-to-linear conversion to it.

 This cancels out the sRGB
 linear-to-non-linear conversion that occurs when writing
 an `-srgb` format in the next step, so that precision
 from an sRGB-like input image is not lost and the
 *linear* color values of the original image can be read
 from the texture (as is generally the purpose of using
 `-srgb` formats).

 4. Set [texel block](#texel-block)
 (`dstOrigin`.[x](#gpuorigin3d-x) + `x`,
 `dstOrigin`.[y](#gpuorigin3d-y) + `y`) of
 `dstSubregion` to an [equivalent texel
 representation](#equivalent-texel-representation) of `dstColor`.
 :::
 ::::::

[`submit(commandBuffers)`]

: Schedules the execution of the command buffers by the GPU on this
 queue.

 Submitted command buffers cannot be used again.

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUQueue`](#gpuqueue) this.
 **Arguments:**

 Arguments for the
 [GPUQueue.submit(commandBuffers)](#dom-gpuqueue-submit) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`commandBuffers`]
 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`GPUCommandBuffer`](#gpucommandbuffer)`>`
 [✘]
 [✘]
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `this`:
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) each
 [`GPUCommandBuffer`](#gpucommandbuffer) in `commandBuffers` and return.

 ::: validusage
 - Every
 [`GPUCommandBuffer`](#gpucommandbuffer) in `commandBuffers` must be
 unique.

 - For each `commandBuffer` in
 `commandBuffers`:

 - `commandBuffer` must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `this`

 - For each `bindGroup` in
 `commandBuffer`.[`[[used_bind_groups]]`](#dom-gpucommandbuffer-used_bind_groups-slot):

 - For each
 [`GPUBindingResource`](#typedefdef-gpubindingresource) in `bindGroup`, if the
 resource type is:

 [`GPUBuffer`](#gpubuffer) `b`

 : `b`.[`[[internal state]]`](#dom-gpubuffer-internal-state-slot) must be
 \"[available](#gpubuffer-internal-state-available)\".

 [`GPUTexture`](#gputexture) `t`

 : `t`.[`[[destroyed]]`](#dom-gputexture-destroyed-slot) must be `false`.

 [`GPUExternalTexture`](#gpuexternaltexture) `et`

 : `et`.[`[[expired]]`](#dom-gpuexternaltexture-expired-slot) must be `false`.

 [`GPUQuerySet`](#gpuqueryset) `qs`

 : `qs`.[`[[destroyed]]`](#dom-gpuqueryset-destroyed-slot) must be `false`.

 For occlusion queries, the
 [`occlusionQuerySet`](#dom-gpurenderpassdescriptor-occlusionqueryset) in
 [`beginRenderPass()`](#dom-gpucommandencoder-beginrenderpass) is not \"used\" unless it is also used by
 [`beginOcclusionQuery()`](#dom-gpurenderpassencoder-beginocclusionquery).
 :::

 2. For each `commandBuffer` in
 `commandBuffers`:

 1. [Invalidate](#abstract-opdef-invalidate) `commandBuffer`.

 3. Issue the subsequent steps on the [Queue
 timeline](#queue-timeline) of `this`:
 :::

 ::: {timeline="queue"}
 [Queue timeline](#queue-timeline) steps:
 1. For each `commandBuffer` in
 `commandBuffers`:

 1. Execute each command in
 `commandBuffer`.[`[[command_list]]`](#dom-gpucommandbuffer-command_list-slot).
 :::
 ::::::

[`onSubmittedWorkDone()`]

: Returns a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) that resolves once this queue finishes processing
 all the work submitted up to this moment.

 Resolution of this
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) implies the completion of
 [`mapAsync()`](#dom-gpubuffer-mapasync) calls made prior to that call, on
 [`GPUBuffer`](#gpubuffer)s last used exclusively on that queue.

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUQueue`](#gpuqueue) `this`.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Issue the `synchronization steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `synchronization steps`:
 1. Let `event` occur upon the completion of [all
 currently-enqueued operations]{timeline="queue"}.

 2. [Listen for timeline
 event](#abstract-opdef-listen-for-timeline-event) `event` on
 `this`.[`[[device]]`](#dom-gpuobjectbase-device-slot), handled by the subsequent steps on
 `contentTimeline`.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) steps:
 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise`.
 :::
 ::::::

## 20. Queries

### 20.1. `GPUQuerySet`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUQuerySet {
 undefined destroy();

 readonly attribute GPUQueryType type;
 readonly attribute GPUSize32Out count;
};
GPUQuerySet includes GPUObjectBase;
```

[`GPUQuerySet`](#gpuqueryset) has the following [immutable
properties](#immutable-property):

[`type`], of type [GPUQueryType](#enumdef-gpuquerytype), readonly

: The type of the queries managed by this
 [`GPUQuerySet`](#gpuqueryset).

[`count`], of type [GPUSize32Out](#typedefdef-gpusize32out), readonly

: The number of queries managed by this
 [`GPUQuerySet`](#gpuqueryset).

[`GPUQuerySet`](#gpuqueryset) has the following [device timeline
properties](#device-timeline-property):

[`[[destroyed]]`], of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), initially `false`

: If the query set is destroyed, it can no longer be used in any
 operation, and its underlying memory can be freed.

#### 20.1.1. QuerySet Creation

A
[`GPUQuerySetDescriptor`](#dictdef-gpuquerysetdescriptor) specifies the options to use in creating a
[`GPUQuerySet`](#gpuqueryset).

```
dictionary GPUQuerySetDescriptor
 : GPUObjectDescriptorBase {
 required GPUQueryType type;
 required GPUSize32 count;
};
```

[`type`], of type [GPUQueryType](#enumdef-gpuquerytype)

: The type of queries managed by
 [`GPUQuerySet`](#gpuqueryset).

[`count`], of type [GPUSize32](#typedefdef-gpusize32)

: The number of queries managed by
 [`GPUQuerySet`](#gpuqueryset).

<!-- -->

[`createQuerySet(descriptor)`]

: Creates a [`GPUQuerySet`](#gpuqueryset).

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) this.
 **Arguments:**

 Arguments for the
 [GPUDevice.createQuerySet(descriptor)](#dom-gpudevice-createqueryset) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`descriptor`]
 [`GPUQuerySetDescriptor`](#dictdef-gpuquerysetdescriptor)
 [✘]
 [✘]
 Description of the
 [`GPUQuerySet`](#gpuqueryset) to create.
 **Returns:**
 [`GPUQuerySet`](#gpuqueryset)

 [Content timeline](#content-timeline) steps:

 1. If
 `descriptor`.[`type`](#dom-gpuquerysetdescriptor-type) is
 [`"timestamp"`](#dom-gpuquerytype-timestamp), but
 [`"timestamp-query"`](#timestamp-query) is not [enabled
 for](#enabled-for)
 `this`:

 1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `q` be
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [create a new WebGPU
 object](#abstract-opdef-create-a-new-webgpu-object)(`this`,
 [`GPUQuerySet`](#gpuqueryset), `descriptor`).

 3. Set
 `q`.[`type`](#dom-gpuqueryset-type) to
 `descriptor`.[`type`](#dom-gpuquerysetdescriptor-type).

 4. Set
 `q`.[`count`](#dom-gpuqueryset-count) to
 `descriptor`.[`count`](#dom-gpuquerysetdescriptor-count).

 5. Issue the `initialization steps` on the [Device
 timeline](#device-timeline) of `this`.

 6. Return `q`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `initialization steps`:
 1. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error),
 [invalidate](#abstract-opdef-invalidate) `q` and return.

 ::: validusage
 - `this` must not be
 [lost](#abstract-opdef-invalid).

 - `descriptor`.[`count`](#dom-gpuquerysetdescriptor-count) must be ≤ 4096.
 :::

 2. Create a device allocation for `q` where each entry
 in the query set is zero.

 If the allocation fails without side-effects, [generate an
 out-of-memory
 error](#abstract-opdef-generate-an-out-of-memory-error),
 [invalidate](#abstract-opdef-invalidate) `q`, and return.
 :::
 :::::

Creating a
[`GPUQuerySet`](#gpuqueryset) which holds 32 occlusion query results.

``` highlight
const querySet = gpuDevice.createQuerySet({
 type: 'occlusion',
 count: 32
});
```

#### 20.1.2. Query Set Destruction

An application that no longer requires a
[`GPUQuerySet`](#gpuqueryset) can choose to lose access to it before garbage
collection by calling
[`destroy()`](#dom-gpuqueryset-destroy).

[`GPUQuerySet`](#gpuqueryset) has the following methods:

[`destroy()`]

: Destroys the
 [`GPUQuerySet`](#gpuqueryset).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUQuerySet`](#gpuqueryset) `this`.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [device
 timeline](#device-timeline).
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Set
 `this`.[`[[destroyed]]`](#dom-gpuqueryset-destroyed-slot) to `true`.
 :::
 :::::

### 20.2. QueryType

```
enum GPUQueryType {
 "occlusion",
 "timestamp",
};
```

### 20.3. Occlusion Query

Occlusion query is only available on render passes, to query the number
of fragment samples that pass all the per-fragment tests for a set of
drawing commands, including scissor, sample mask, alpha to coverage,
stencil, and depth tests. Any non-zero result value for the query
indicates that at least one sample passed the tests and reached the
output merging stage of the render pipeline, 0 indicates that no samples
passed the tests.

When beginning a render pass,
[`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor).[`occlusionQuerySet`](#dom-gpurenderpassdescriptor-occlusionqueryset) must be set to be able to use occlusion queries during
the pass. An occlusion query is begun and ended by calling
[`beginOcclusionQuery()`](#dom-gpurenderpassencoder-beginocclusionquery) and
[`endOcclusionQuery()`](#dom-gpurenderpassencoder-endocclusionquery) in pairs that cannot be nested, and resolved into a
[`GPUBuffer`](#gpubuffer)
as a [64-bit unsigned
integer](https://gpuweb.github.io/gpuweb/wgsl/#64-bit-integer) by
[`GPUCommandEncoder`](#gpucommandencoder).[`resolveQuerySet()`](#dom-gpucommandencoder-resolvequeryset).

### 20.4. Timestamp Query

Timestamp queries allow applications to write timestamps to a
[`GPUQuerySet`](#gpuqueryset), using:

- [`GPUComputePassDescriptor`](#dictdef-gpucomputepassdescriptor).[`timestampWrites`](#dom-gpucomputepassdescriptor-timestampwrites)

- [`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor).[`timestampWrites`](#dom-gpurenderpassdescriptor-timestampwrites)

and then resolve timestamp values (in nanoseconds as a [64-bit unsigned
integer](https://gpuweb.github.io/gpuweb/wgsl/#64-bit-integer)) into a
[`GPUBuffer`](#gpubuffer),
using
[`GPUCommandEncoder`](#gpucommandencoder).[`resolveQuerySet()`](#dom-gpucommandencoder-resolvequeryset).

Timestamp values are
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). Applications must handle arbitrary timestamp results,
and should not be written in such a way that unexpected timestamps cause
an application failure.

 The physical device may reset the timestamp counter
occasionally, which can result in unexpected values such as negative
deltas from one timestamp to the next. These instances should be rare,
and these data points can safely be discarded.

[!(data:image/svg+xml;base64,PHN2ZyBhcmlhLWxhYmVsPSIoVGhpcyBpcyBhIHRyYWNraW5nIHZlY3Rvci4pIiBjbGFzcz0iZGFya21vZGUtYXdhcmUiIGhlaWdodD0iNjQiIHJvbGU9ImltZyIgd2lkdGg9IjQ2Ij48dGl0bGU+VGhlcmUgaXMgYSB0cmFja2luZyB2ZWN0b3IgaGVyZS48L3RpdGxlPjx1c2UgaHJlZj0iI2I3MzJiM2ZlIiAvPjwvc3ZnPg==)](https://infra.spec.whatwg.org/#tracking-vector) Timestamp queries are implemented using
high-resolution timers (see [§ 2.1.7.2 Device/queue-timeline
timing](#security-timing-device)). To mitigate security and privacy
concerns, their precision must be reduced:

To get the [current queue
timestamp], run the following [queue
timeline](#queue-timeline)
steps:

- Let `fineTimestamp` be the current timestamp value of the
 current [queue timeline](#queue-timeline), in nanoseconds, relative to an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) point in the past.

- Return the result of calling [coarsen
 time](https://w3c.github.io/hr-time/#dfn-coarsen-time) on `fineTimestamp` with
 `crossOriginIsolatedCapability` set to `false`.

 Cross-origin isolation never applies to the [device
timeline](#device-timeline)
or [queue timeline](#queue-timeline), so `crossOriginIsolatedCapability` is never set to
`true`.

[Validate timestampWrites](`device`,
`timestampWrites`)

**Arguments:**

- [`GPUDevice`](#gpudevice)
 `device`

- `(`[`GPUComputePassTimestampWrites`](#dictdef-gpucomputepasstimestampwrites)` or `[`GPURenderPassTimestampWrites`](#dictdef-gpurenderpasstimestampwrites)`)` `timestampWrites`

[Device timeline](#device-timeline) steps:

1. Return `true` if the following requirements are met, and `false` if
 not:

 ::: validusage
 - [`"timestamp-query"`](#timestamp-query) must be [enabled
 for](#enabled-for)
 `device`.

 - `timestampWrites`.`querySet` must be [valid to use
 with](#abstract-opdef-valid-to-use-with) `device`.

 - `timestampWrites`.`querySet`.[`type`](#dom-gpuqueryset-type) must be
 [`"timestamp"`](#dom-gpuquerytype-timestamp).

 - Of the write index members in `timestampWrites`
 (`beginningOfPassWriteIndex`, `endOfPassWriteIndex`):

 - At least one must be
 [provided](https://infra.spec.whatwg.org/#map-exists).

 - Of those which are
 [provided](https://infra.spec.whatwg.org/#map-exists):

 - No two may be equal.

 - Each must be \<
 `timestampWrites`.`querySet`.[`count`](#dom-gpuqueryset-count).
 :::

## 21. Canvas Rendering

### [21.1. ][[`HTMLCanvasElement.getContext()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-getcontext)]
A
[`GPUCanvasContext`](#gpucanvascontext) object is
[created](#abstract-opdef-create-a-webgpu-context-on-a-canvas) via the
[`getContext()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-getcontext) method of an
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) instance by passing the string literal `'webgpu'` as
its `contextType` argument.

Get a
[`GPUCanvasContext`](#gpucanvascontext) from an offscreen
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement):

``` highlight
const canvas = document.createElement('canvas');
const context = canvas.getContext('webgpu');
```

Unlike WebGL or 2D context creation, the second argument of
[`HTMLCanvasElement.getContext()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-getcontext) or
[`OffscreenCanvas.getContext()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-getcontext), the context creation attribute dictionary `options`,
is ignored. Instead, use
[`GPUCanvasContext.configure()`](#dom-gpucanvascontext-configure), which allows changing the canvas configuration without
replacing the canvas.

To [create a \'webgpu\' context on a
canvas]
([`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas)) `canvas`, run the following [content
timeline](#content-timeline) steps:

1. Let `context` be a new
 [`GPUCanvasContext`](#gpucanvascontext).

2. Set
 `context`.[`canvas`](#dom-gpucanvascontext-canvas) to `canvas`.

3. [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer) of `context`.

4. Return `context`.

 User agents should consider issuing developer-visible
warnings when an ignored `options` argument is provided when calling
`getContext()` to get a WebGPU canvas context.

### 21.2. GPUCanvasContext

```
[Exposed=(Window, Worker), SecureContext]
interface GPUCanvasContext {
 readonly attribute (HTMLCanvasElement or OffscreenCanvas) canvas;

 undefined configure(GPUCanvasConfiguration configuration);
 undefined unconfigure();

 GPUCanvasConfiguration? getConfiguration();
 GPUTexture getCurrentTexture();
};
```

[`GPUCanvasContext`](#gpucanvascontext) has the following [content timeline
properties](#content-timeline-property):

[`canvas`], of type `(HTMLCanvasElement or OffscreenCanvas)`, readonly

: The canvas this context was created from.

[`[[configuration]]`], of type [`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration)?, initially `null`

: The options this context is currently configured with.

 `null` if the context has not been configured or has been
 [`unconfigured`](#dom-gpucanvascontext-unconfigure).

[`[[textureDescriptor]]`], of type [`GPUTextureDescriptor`](#gputexturedescriptor)?, initially `null`

: The currently configured texture descriptor, derived from the
 [`[[configuration]]`](#dom-gpucanvascontext-configuration-slot) and canvas.

 `null` if the context has not been configured or has been
 [`unconfigured`](#dom-gpucanvascontext-unconfigure).

[`[[drawingBuffer]]`], an image, initially a transparent black image with the same size as the canvas

: The drawing buffer is the working-copy image data of the canvas. It
 is exposed as writable by
 [`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) (returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture)).

 The drawing buffer is used to [get a copy of the image contents of a
 context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context), which occurs when the canvas is displayed
 or otherwise read. It may be transparent, even if
 [`[[configuration]]`](#dom-gpucanvascontext-configuration-slot).[`alphaMode`](#dom-gpucanvasconfiguration-alphamode) is
 [`"opaque"`](#dom-gpucanvasalphamode-opaque). The
 [`alphaMode`](#dom-gpucanvasconfiguration-alphamode) only affects the result of the \"[get a copy of the
 image contents of a
 context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context)\" algorithm.

 The drawing buffer outlives the
 [`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) and contains the previously-rendered contents even
 after the canvas has been presented. It is only cleared in [Replace
 the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer).

 Any time the drawing buffer is read, implementations must ensure
 that all previously submitted work (e.g. queue submissions) have
 completed writing to it via
 [`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot).

[`[[currentTexture]]`], of type [`GPUTexture`](#gputexture)?, initially `null`

: The [`GPUTexture`](#gputexture) to draw into for the current frame. It exposes a
 writable view onto the underlying
 [`[[drawingBuffer]]`](#dom-gpucanvascontext-drawingbuffer-slot).
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) populates this slot if `null`, then returns it.

 In the steady-state of a visible canvas, any changes to the drawing
 buffer made through the currentTexture get presented when [updating
 the rendering of a WebGPU
 canvas](#abstract-opdef-updating-the-rendering-of-a-webgpu-canvas). At or before that point, the texture is
 also destroyed and
 [`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) is set to to `null`, signalling that a new one is
 to be created by the next call to
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture).

 [`Destroying`](#dom-gputexture-destroy) the currentTexture has no effect on the drawing
 buffer contents; it only terminates write-access to the drawing
 buffer early. During the same frame,
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) continues returning the same destroyed texture.

 [Expire the current
 texture](#abstract-opdef-expire-the-current-texture) sets the currentTexture to `null`. It is
 called by
 [`configure()`](#dom-gpucanvascontext-configure), resizing the canvas, presentation,
 [`transferToImageBitmap()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-transfertoimagebitmap), and others.

[`[[lastPresentedImage]]`], of type `(readonly image)?`, initially `null`

: The image most recently presented for this canvas in \"[updating the
 rendering of a WebGPU
 canvas](#abstract-opdef-updating-the-rendering-of-a-webgpu-canvas)\". If the device is lost or destroyed, this
 image **may** be used as a fallback in \"[get a copy of the image
 contents of a
 context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context)\" in order to prevent the canvas from going
 blank.

 This property only needs to exist in
 implementations which implement the fallback, which is optional.

[`GPUCanvasContext`](#gpucanvascontext) has the following methods:

[`configure(configuration)`]

: Configures the context for this canvas. This clears the drawing
 buffer to transparent black (in [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer)).

 See
 [`getConfiguration()`](#dom-gpucanvascontext-getconfiguration) for information on [feature
 detection](#feature-detection).

 :::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCanvasContext`](#gpucanvascontext) `this`.
 **Arguments:**

 Arguments for the
 [GPUCanvasContext.configure(configuration)](#dom-gpucanvascontext-configure) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`configuration`]
 [`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration)
 [✘]
 [✘]
 Desired configuration for the context.
 **Returns:** undefined

 [Content timeline](#content-timeline) steps:

 1. Let `device` be
 `configuration`.[`device`](#dom-gpucanvasconfiguration-device).

 2. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture format
 required
 features](#abstract-opdef-validate-texture-format-required-features) of
 `configuration`.[`format`](#dom-gpucanvasconfiguration-format) with
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 3. [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Validate texture format
 required
 features](#abstract-opdef-validate-texture-format-required-features) of each element of
 `configuration`.[`viewFormats`](#dom-gpucanvasconfiguration-viewformats) with
 `device`.[`[[device]]`](#dom-gpuobjectbase-device-slot).

 4. If [Supported context
 formats](#supported-context-formats) does not
 [contain](https://infra.spec.whatwg.org/#list-contain)
 `configuration`.[`format`](#dom-gpucanvasconfiguration-format), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 5. Let `descriptor` be the [GPUTextureDescriptor for the
 canvas and
 configuration](#abstract-opdef-gputexturedescriptor-for-the-canvas-and-configuration)(`this`.[`canvas`](#dom-gpucanvascontext-canvas), `configuration`).

 6. Set
 `this`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot) to `configuration`.

 This exposes only the members defined in an
 implementation's definition of
 [`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration). See the specifications of those members for
 notes about [feature
 detection](#feature-detection).

 7. Set
 `this`.[`[[textureDescriptor]]`](#dom-gpucanvascontext-texturedescriptor-slot) to `descriptor`.

 8. [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer) of `this`.

 9. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `device`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. If any of the following requirements are unmet, [generate a
 validation
 error](#abstract-opdef-generate-a-validation-error) and return.

 ::: validusage
 - [validating
 GPUTextureDescriptor](#abstract-opdef-validating-gputexturedescriptor)(`device`,
 `descriptor`) must return true.
 :::

 This early validation remains valid until the
 next
 [`configure()`](#dom-gpucanvascontext-configure) call, **except** for validation of the
 [`size`](#dom-gputexturedescriptor-size), which changes when the canvas is resized.
 :::
 :::::

[`unconfigure()`]

: Removes the context configuration. Destroys any textures produced
 while configured.

 ::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCanvasContext`](#gpucanvascontext) `this`.
 **Returns:** undefined

 [Content timeline](#content-timeline) steps:

 1. Set
 `this`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot) to `null`.

 2. Set
 `this`.[`[[textureDescriptor]]`](#dom-gpucanvascontext-texturedescriptor-slot) to `null`.

 3. [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer) of `this`.
 :::
 ::::

[`getConfiguration()`]

: Returns the context configuration, or `null` if the context is not
 configured.

 This method exists primarily for [feature
 detection](#feature-detection) of members (and sub-members) of
 [`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration); see those members for details. For supported
 members, it returns the originally-supplied values.

 ::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCanvasContext`](#gpucanvascontext) `this`.
 **Returns:**
 [`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration) or `null`

 [Content timeline](#content-timeline) steps:

 1. Let `configuration` be a copy of
 `this`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot).

 2. Return `configuration`.
 :::
 ::::

[`getCurrentTexture()`]

: Get the [`GPUTexture`](#gputexture) that will be composited to the document by the
 [`GPUCanvasContext`](#gpucanvascontext) next.

 ::::
 ::: marker
 NOTE:
 :::

 An application **should** call
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) in the same task that renders to the canvas
 texture. Otherwise, the texture could get destroyed by these steps
 before the application is finished rendering to it.
 The expiry task (defined below) is optional to implement. Even if
 implemented, task source priority is not normatively defined, so may
 happen as early as the next task, or as late as after all other task
 sources are empty (see [automatic expiry task
 source](#automatic-expiry-task-source)). Expiry is only guaranteed when a visible canvas
 is displayed ([updating the rendering of a WebGPU
 canvas](#abstract-opdef-updating-the-rendering-of-a-webgpu-canvas)) and in other callers of \"[Expire the
 current
 texture](#abstract-opdef-expire-the-current-texture)\".
 ::::

 ::::
 ::: {timeline="content"}
 **Called on:**
 [`GPUCanvasContext`](#gpucanvascontext) `this`.
 **Returns:** [`GPUTexture`](#gputexture)

 [Content timeline](#content-timeline) steps:

 1. If
 `this`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot) is `null`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and return.

 2. [Assert](https://infra.spec.whatwg.org/#assert)
 `this`.[`[[textureDescriptor]]`](#dom-gpucanvascontext-texturedescriptor-slot) is not `null`.

 3. Let `device` be
 `this`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot).[`device`](#dom-gpucanvasconfiguration-device).

 4. If
 `this`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) is `null`:

 1. [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer) of `this`.

 2. Set
 `this`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) to the result of calling
 `device`.[`createTexture()`](#dom-gpudevice-createtexture) with
 `this`.[`[[textureDescriptor]]`](#dom-gpucanvascontext-texturedescriptor-slot), except with the
 [`GPUTexture`](#gputexture)'s underlying storage pointing to
 `this`.[`[[drawingBuffer]]`](#dom-gpucanvascontext-drawingbuffer-slot).

 If the texture can't be created (e.g. due
 to validation failure or out-of-memory), this generates and
 error and returns an
 [invalidated](#abstract-opdef-invalidate)
 [`GPUTexture`](#gputexture). Some validation here is redundant with
 that done in
 [`configure()`](#dom-gpucanvascontext-configure). Implementations **must not** skip this
 redundant validation.

 5. **Optionally**, [queue an automatic expiry
 task](#abstract-opdef-queue-an-automatic-expiry-task) with device `device` and the
 following steps:

 ::: {timeline="content"}
 1. [Expire the current
 texture](#abstract-opdef-expire-the-current-texture) of `this`.

 If this already happened when [updating the
 rendering of a WebGPU
 canvas](#abstract-opdef-updating-the-rendering-of-a-webgpu-canvas), it has no effect.
 :::

 6. Return
 `this`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot).
 :::
 ::::

 The same
 [`GPUTexture`](#gputexture) object will be returned by every call to
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) until \"[Expire the current
 texture](#abstract-opdef-expire-the-current-texture)\" runs, even if that
 [`GPUTexture`](#gputexture) is destroyed, failed validation, or failed to
 allocate.

To [get a copy of the image contents of a
context]:

**Arguments:**

- `context`: the
 [`GPUCanvasContext`](#gpucanvascontext)

**Returns:** image contents

[Content timeline](#content-timeline) steps:

1. Let `snapshot` be a transparent black image of the same
 size as
 `context`.[`canvas`](#dom-gpucanvascontext-canvas).

2. Let `configuration` be
 `context`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot).

3. If `configuration` is `null`:

 1. Return `snapshot`.

 The configuration will be `null` if the context has
 not been configured or has been
 [`unconfigured`](#dom-gpucanvascontext-unconfigure). This is identical to the behavior when the canvas
 has no context.

4. Ensure that all submitted work items (e.g. queue submissions) have
 completed writing to the image (via
 `context`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot)).

5. If
 `configuration`.[`device`](#dom-gpucanvasconfiguration-device) is found to be
 [valid](https://w3c.github.io/i18n-glossary/#dfn-valid):

 1. Set `snapshot` to a copy of the
 `context`.[`[[drawingBuffer]]`](#dom-gpucanvascontext-drawingbuffer-slot).

 Otherwise, if
 `context`.[`[[lastPresentedImage]]`](#dom-gpucanvascontext-lastpresentedimage-slot) is not `null`:

 1. **Optionally**, set `snapshot` to a copy of
 `context`.[`[[lastPresentedImage]]`](#dom-gpucanvascontext-lastpresentedimage-slot).

 This is optional because the
 [`[[lastPresentedImage]]`](#dom-gpucanvascontext-lastpresentedimage-slot) may no longer exist, depending on what caused
 device loss. Implementations may choose to skip it even if do
 they still have access to that image.

6. Let `alphaMode` be
 `configuration`.[`alphaMode`](#dom-gpucanvasconfiguration-alphamode).

7. If `alphaMode` is
 [`"opaque"`](#dom-gpucanvasalphamode-opaque):

 1. Clear the alpha channel of `snapshot` to 1.0.

 If the
 [`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot), if any, has been destroyed (for example in
 \"[Expire the current
 texture](#abstract-opdef-expire-the-current-texture)\"), the alpha channel is unobservable,
 and implementations may clear the alpha channel in-place.

 2. Tag `snapshot` as being opaque.

 Otherwise:

 1. Tag `snapshot` with `alphaMode`.

8. Tag `snapshot` with the
 [`colorSpace`](#dom-gpucanvasconfiguration-colorspace) and
 [`toneMapping`](#dom-gpucanvasconfiguration-tonemapping) of `configuration`.

9. Return `snapshot`.

To [Replace the drawing
buffer] of a
[`GPUCanvasContext`](#gpucanvascontext) `context`, run the following [content
timeline](#content-timeline) steps:

1. [Expire the current
 texture](#abstract-opdef-expire-the-current-texture) of `context`.

2. Let `configuration` be
 `context`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot).

3. Set
 `context`.[`[[drawingBuffer]]`](#dom-gpucanvascontext-drawingbuffer-slot) to a transparent black image of the same size as
 `context`.[`canvas`](#dom-gpucanvascontext-canvas).

 - If `configuration` is null, the drawing buffer is
 tagged with the color space
 [`"srgb"`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-srgb). In this case, the drawing buffer will remain
 blank until the context is configured.

 - If not, the drawing buffer has the specified
 `configuration`.[`format`](#dom-gpucanvasconfiguration-format) and is tagged with the specified
 `configuration`.[`colorSpace`](#dom-gpucanvasconfiguration-colorspace) and
 `configuration`.[`toneMapping`](#dom-gpucanvasconfiguration-tonemapping).

 `configuration`.[`alphaMode`](#dom-gpucanvasconfiguration-alphamode) is ignored until \"[get a copy of the image
 contents of a
 context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context)\".

 ::::
 ::: marker
 NOTE:
 :::

 A newly replaced drawing buffer image behaves as if it is cleared to
 transparent black, but, like after
 [`"discard"`](#dom-gpustoreop-discard), an implementation can clear it lazily only if it
 becomes necessary.
 ::::

 This will often be a no-op, if the drawing buffer
 is already cleared and has the correct configuration.

To [Expire the current
texture] of a
[`GPUCanvasContext`](#gpucanvascontext) `context`, run the following [content
timeline](#content-timeline) steps:

1. If
 `context`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) is not `null`:

 1. Call
 `context`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot).[`destroy()`](#dom-gputexture-destroy) (without destroying
 `context`.[`[[drawingBuffer]]`](#dom-gpucanvascontext-drawingbuffer-slot)) to terminate write access to the image.

 2. Set
 `context`.[`[[currentTexture]]`](#dom-gpucanvascontext-currenttexture-slot) to `null`.

### 21.3. HTML Specification Hooks

The following algorithms \"hook\" into algorithms in the HTML
specification, and must run at the specified points.

When the \"bitmap\" is read from an
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas) with a
[`GPUCanvasContext`](#gpucanvascontext) `context`, run the following [content
timeline](#content-timeline) steps:

1. Return [a copy of the image
 contents](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context) of `context`.

NOTE:

This occurs in many places, including:

- When an
 [`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) has its rendering updated.

 - Including when the canvas is the [placeholder canvas
 element](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas-placeholder) of an
 [`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas).

- When
 [`transferToImageBitmap()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-transfertoimagebitmap) creates an
 [`ImageBitmap`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap) from the bitmap. (See also [transferToImageBitmap
 from
 WebGPU](#abstract-opdef-transfertoimagebitmap-from-webgpu).)

- When WebGPU canvas contents are read using other Web APIs, like
 [`drawImage()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-drawimage), `texImage2D()`, `texSubImage2D()`,
 [`toDataURL()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-todataurl),
 [`toBlob()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-toblob), and so on.

If
[`alphaMode`](#dom-gpucanvasconfiguration-alphamode) is
[`"opaque"`](#dom-gpucanvasalphamode-opaque), this incurs a clear of the alpha channel.
Implementations may skip this step when they are able to read or display
images in a way that ignores the alpha channel.

If an application needs a canvas only for interop (not presentation),
avoid
[`"opaque"`](#dom-gpucanvasalphamode-opaque) if it is not needed.

When [updating the rendering of a WebGPU
canvas] (an
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or an
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas) with a [placeholder canvas
element](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas-placeholder)) with a
[`GPUCanvasContext`](#gpucanvascontext) `context`, which occurs before getting the
canvas's image contents, in the following sub-steps of the [event loop
processing
model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model):

- \"update the rendering or user interface of that `Document`\"

- \"update the rendering of that dedicated worker\"

 Service and Shared workers do not have \"update the
rendering\" steps because they cannot render to user-visible canvases.
[`requestAnimationFrame()`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-animationframeprovider-requestanimationframe) is not exposed in
[`ServiceWorkerGlobalScope`](https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope) and
[`SharedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#sharedworkerglobalscope), and
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas)es from
[`transferControlToOffscreen()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-transfercontroltooffscreen) [cannot be sent to these
workers](https://github.com/whatwg/html/issues/10112).

Run the following [content
timeline](#content-timeline) steps:

1. [Expire the current
 texture](#abstract-opdef-expire-the-current-texture) of `context`.

 If this already happened in the task queued by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture), it has no effect.

2. Set
 `context`.[`[[lastPresentedImage]]`](#dom-gpucanvascontext-lastpresentedimage-slot) to
 `context`.[`[[drawingBuffer]]`](#dom-gpucanvascontext-drawingbuffer-slot).

 This is just a reference, not a copy; the drawing
 buffer's contents can't change in-place after the current texture
 has expired.

 This does not happen for standalone
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas)es (created by `new OffscreenCanvas()`).

[transferToImageBitmap from
WebGPU]:

When
[`transferToImageBitmap()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-transfertoimagebitmap) is called on a canvas with
[`GPUCanvasContext`](#gpucanvascontext) `context`, after creating an
[`ImageBitmap`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap) from the canvas's bitmap, run the following [content
timeline](#content-timeline) steps:

1. [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer) of `context`.

 This makes
[`transferToImageBitmap()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-transfertoimagebitmap) equivalent to \"moving\" (and possibly alpha-clearing)
the image contents into the ImageBitmap, without a copy.

- The [update the canvas
 size](#abstract-opdef-update-the-canvas-size) algorithm.

### 21.4. GPUCanvasConfiguration

The [supported context formats] are the
[set](https://infra.spec.whatwg.org/#ordered-set) of
[`GPUTextureFormat`](#enumdef-gputextureformat)s:
«[`"bgra8unorm"`](#dom-gputextureformat-bgra8unorm),
[`"rgba8unorm"`](#dom-gputextureformat-rgba8unorm),
[`"rgba16float"`](#dom-gputextureformat-rgba16float)». These formats must be supported when specified as a
[`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration).[`format`](#dom-gpucanvasconfiguration-format) regardless of the given
[`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration).[`device`](#dom-gpucanvasconfiguration-device).

 Canvas configuration cannot use `srgb` formats like
[`"bgra8unorm-srgb"`](#dom-gputextureformat-bgra8unorm-srgb). Instead, use the non-`srgb` equivalent
([`"bgra8unorm"`](#dom-gputextureformat-bgra8unorm)), specify the `srgb` format in the
[`viewFormats`](#dom-gpucanvasconfiguration-viewformats), and use
[`createView()`](#dom-gputexture-createview) to create a view with an `srgb` format.

```
enum GPUCanvasAlphaMode {
 "opaque",
 "premultiplied",
};

enum GPUCanvasToneMappingMode {
 "standard",
 "extended",
};

dictionary GPUCanvasToneMapping {
 GPUCanvasToneMappingMode mode = "standard";
};

dictionary GPUCanvasConfiguration {
 required GPUDevice device;
 required GPUTextureFormat format;
 GPUTextureUsageFlags usage = 0x10; // GPUTextureUsage.RENDER_ATTACHMENT
 sequence<GPUTextureFormat> viewFormats = ;
 PredefinedColorSpace colorSpace = "srgb";
 GPUCanvasToneMapping toneMapping = ;
 GPUCanvasAlphaMode alphaMode = "opaque";
};
```

[`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration) has the following members:

[`device`], of type [GPUDevice](#gpudevice)

: The [`GPUDevice`](#gpudevice) that textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) will be compatible with.

[`format`], of type [GPUTextureFormat](#enumdef-gputextureformat)

: The format that textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) will have. Must be one of the [Supported context
 formats](#supported-context-formats).

[`usage`], of type [GPUTextureUsageFlags](#typedefdef-gputextureusageflags), defaulting to `0x10`

: The usage that textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) will have.
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) is the default, but is not automatically included
 if the usage is explicitly set. Be sure to include
 [`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) when setting a custom usage if you wish to use
 textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) as color targets for a render pass.

[`viewFormats`], of type sequence\<[GPUTextureFormat](#enumdef-gputextureformat)\>, defaulting to ``

: The formats that views created from textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) may use.

[`colorSpace`], of type [PredefinedColorSpace](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace), defaulting to `"srgb"`

: The color space that values written into textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) should be displayed with.

[`toneMapping`], of type [GPUCanvasToneMapping](#dictdef-gpucanvastonemapping), defaulting to ``

: The tone mapping determines how the content of textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) are to be displayed.

 ::::
 ::: marker
 NOTE:
 :::

 This is a required feature, but user agents might not yet implement
 it, effectively supporting only the default
 [`GPUCanvasToneMapping`](#dictdef-gpucanvastonemapping). In such implementations, this member **should
 not** exist in its implementation of
 [`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration), to make [feature
 detection](#feature-detection) possible using
 [`getConfiguration()`](#dom-gpucanvascontext-getconfiguration).
 This is especially important in implementations which otherwise have
 HDR capabilities (where a
 [dynamic-range](https://drafts.csswg.org/mediaqueries-5/#descdef-media-dynamic-range) of
 [high](https://drafts.csswg.org/mediaqueries-5/#valdef-media-dynamic-range-high) would be exposed).

 If an implementation exposes this member and a `high` dynamic range,
 it **should** render the canvas as an HDR element, not clamp values
 to the SDR range of the HDR display.
 ::::

[`alphaMode`], of type [GPUCanvasAlphaMode](#gpucanvasalphamode), defaulting to `"opaque"`

: Determines the effect that alpha values will have on the content of
 textures returned by
 [`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture) when read, displayed, or used as an image source.

Configure a
[`GPUCanvasContext`](#gpucanvascontext) to be used with a specific
[`GPUDevice`](#gpudevice),
using the preferred format for this context:

``` highlight
const canvas = document.createElement('canvas');
const context = canvas.getContext('webgpu');

context.configure({
 device: gpuDevice,
 format: navigator.gpu.getPreferredCanvasFormat(),
});
```

The [GPUTextureDescriptor for the canvas and
configuration](
([`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas)) `canvas`,
[`GPUCanvasConfiguration`](#dictdef-gpucanvasconfiguration) `configuration`) is a
[`GPUTextureDescriptor`](#gputexturedescriptor) with the following members:

- [`size`](#dom-gputexturedescriptor-size): \[`canvas`.width,
 `canvas`.height, 1\].

- [`format`](#dom-gputexturedescriptor-format):
 `configuration`.[`format`](#dom-gpucanvasconfiguration-format).

- [`usage`](#dom-gputexturedescriptor-usage):
 `configuration`.[`usage`](#dom-gpucanvasconfiguration-usage).

- [`viewFormats`](#dom-gputexturedescriptor-viewformats):
 `configuration`.[`viewFormats`](#dom-gpucanvasconfiguration-viewformats).

and other members set to their defaults.

`canvas`.width refers to
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement).[`width`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-width) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas).[`width`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-width). `canvas`.height refers to
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement).[`height`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-height) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas).[`height`](https://html.spec.whatwg.org/multipage/canvas.html#dom-offscreencanvas-height).

#### 21.4.1. Canvas Color Space

During presentation, the color values in the canvas are converted to the
color space of the screen.

The
[`toneMapping`](#dom-gpucanvasconfiguration-tonemapping) determines the handling of values outside of the
`[0, 1]` interval in the color space of the screen.

#### 21.4.2. Canvas Context sizing

All canvas configuration is set in
[`configure()`](#dom-gpucanvascontext-configure) except for the resolution of the canvas, which is set
by the canvas's `width` and `height`.

 Like WebGL and 2d canvas, resizing a WebGPU canvas
loses the current contents of the drawing buffer. In WebGPU, it does so
by [replacing the drawing
buffer](#abstract-opdef-replace-the-drawing-buffer).

When an
[`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) or
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas) `canvas` with a
[`GPUCanvasContext`](#gpucanvascontext) `context` has its `width` or `height`
attributes set, [update the canvas
size] by running the following [content
timeline](#content-timeline) steps:

1. [Replace the drawing
 buffer](#abstract-opdef-replace-the-drawing-buffer) of `context`.

2. Let `configuration` be
 `context`.[`[[configuration]]`](#dom-gpucanvascontext-configuration-slot)

3. If `configuration` is not `null`:

 1. Set
 `context`.[`[[textureDescriptor]]`](#dom-gpucanvascontext-texturedescriptor-slot) to the [GPUTextureDescriptor for the canvas and
 configuration](#abstract-opdef-gputexturedescriptor-for-the-canvas-and-configuration)(`canvas`,
 `configuration`).

 This may result in a
[`GPUTextureDescriptor`](#gputexturedescriptor) which exceeds the
[`maxTextureDimension2D`](#dom-supported-limits-maxtexturedimension2d) of the device. In this case, validation will fail
inside
[`getCurrentTexture()`](#dom-gpucanvascontext-getcurrenttexture).

 This algorithm is run any time the `canvas`
`width` or `height` attributes are set, even if their value is not
changed.

### 21.5. `GPUCanvasToneMappingMode`

This enum specifies how color values are displayed to the screen.

[`"standard"`]

: Color values within the standard dynamic range of the screen are
 unchanged, and all other color values are projected to the standard
 dynamic range of the screen.

 This projection is often accomplished by clamping
 color values in the color space of the screen to the `[0, 1]`
 interval.

 :::
 (#example-cf13296c) For example, suppose that the
 value `(1.035, -0.175, -0.140)` is written to an `'srgb'` canvas.
 If this is presented to an sRGB screen, then this will be converted
 to sRGB (which is a no-op, because the canvas is sRGB), then
 projected into the display's space. Using component-wise clamping,
 this results in the sRGB value `(1.0, 0.0, 0.0)`.

 If this is presented to a Display P3 screen, then this will be
 converted to the value `(0.948, 0.106, 0.01)` in the Display P3
 color space, and no clamping will be needed.
 :::

[`"extended"`]

: Color values in the extended dynamic range of the screen are
 unchanged, and all other color values are projected to the extended
 dynamic range of the screen.

 This projection is often accomplished by clamping
 color values in the color space of the screen to the interval of
 values that the screen is capable of displaying, which may include
 values greater than `1`.

 :::
 (#example-8397ef45) For example, suppose that the
 value `(2.5, -0.15, -0.15)` is written to an `'srgb'` canvas.
 If this is presented to an sRGB screen that is capable of displaying
 values in the `[0, 4]` interval in sRGB space, then this will be
 converted to sRGB (which is a no-op, because the canvas is sRGB),
 then projected into the display's space. If using component-wise
 clamping, this results in the sRGB value `(2.5, 0.0, 0.0)`.

 If this is presented to a Display P3 screen that is capable of
 displaying values in the `[0, 2]` interval in Display P3 space, then
 this will be converted to the value `(2.3, 0.545, 0.386)` in the
 Display P3 color space, then projected into the display's space. If
 using component-wise clamping, this results in the Display P3 value
 `(2.0, 0.545, 0.386)`.
 :::

### 21.6. `GPUCanvasAlphaMode`

This enum selects how the contents of the canvas will be interpreted
when read, when [displayed to the screen or used as an image
source](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context) (in drawImage, toDataURL, etc.)

Below, `src` is a value in the canvas texture, and `dst` is an image
that the canvas is being composited into (e.g. an HTML page rendering,
or a 2D canvas).

[`"opaque"`]

: Read RGB as opaque and ignore alpha values. If the content is not
 already opaque, the alpha channel is cleared to 1.0 in \"[get a copy
 of the image contents of a
 context](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context)\".

[`"premultiplied"`]

: Read RGBA as premultiplied: color values are premultiplied by their
 alpha value. 100% red at 50% alpha is `[0.5, 0, 0, 0.5]`.

 If the canvas texture contains [out-of-gamut premultiplied RGBA
 values](#out-of-gamut-premultiplied-rgba-value) at the time the canvas contents are read, the
 behavior depends on whether the canvas is:

 [used as an image source](#abstract-opdef-get-a-copy-of-the-image-contents-of-a-context)

 : Values are preserved, as described in [color space
 conversion](#color-space-conversions).

 displayed to the screen

 : Compositing results are undefined.

 This is true even if color space conversion
 would produce in-gamut values before compositing, because the
 intermediate format for compositing is not specified.

## 22. Errors & Debugging

During the normal course of operation of WebGPU, errors are raised via
[dispatch
error](#abstract-opdef-dispatch-error).

After a device is [lost](#lose-the-device), errors are no longer surfaced, where possible. After
this point, implementations do not need to run validation or error
tracking:

- The validity of objects on the device becomes unobservable.

- [`popErrorScope()`](#dom-gpudevice-poperrorscope) and
 [`uncapturederror`](#eventdef-gpudevice-uncapturederror) stop reporting errors. (No errors are generated by
 the device loss itself. Instead, the
 [`GPUDevice`](#gpudevice).[`lost`](#dom-gpudevice-lost) promise resolves to indicate the device is lost.)

- All operations which send a message back to the [content
 timeline](#content-timeline) will skip their usual steps. Most will appear to
 succeed, except for
 [`mapAsync()`](#dom-gpubuffer-mapasync), which produces an error because it is impossible to
 provide the correct mapped data after the device has been lost.

 This makes it unobservable whether other types of operations (that
 don't send messages back) actually execute or not.

### 22.1. Fatal Errors

```
enum GPUDeviceLostReason {
 "unknown",
 "destroyed",
};

[Exposed=(Window, Worker), SecureContext]
interface GPUDeviceLostInfo {
 readonly attribute GPUDeviceLostReason reason;
 readonly attribute DOMString message;
};

partial interface GPUDevice {
 readonly attribute Promise<GPUDeviceLostInfo> lost;
};
```

[`GPUDevice`](#gpudevice)
has the following additional attributes:

[`lost`], of type Promise\<[GPUDeviceLostInfo](#gpudevicelostinfo)\>, readonly

: A [slot-backed
 attribute](#slot-backed-attribute) holding a promise which is created with the device,
 remains pending for the lifetime of the device, then resolves when
 the device is lost.

 Upon initialization, it is set to [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

### 22.2. `GPUError`

```
[Exposed=(Window, Worker), SecureContext]
interface GPUError {
 readonly attribute DOMString message;
};
```

[`GPUError`](#gpuerror) is the
base interface for all errors surfaced from
[`popErrorScope()`](#dom-gpudevice-poperrorscope) and the
[`uncapturederror`](#eventdef-gpudevice-uncapturederror) event.

Errors must only be generated for operations that explicitly state the
conditions one may be generated under in their respective algorithms,
and the subtype of error that is generated.

No errors are generated from a device which is lost. See [§ 22 Errors &
Debugging](#errors-and-debugging).

 [`GPUError`](#gpuerror) may gain new subtypes in future versions of this spec.
Applications should handle this possibility, using only the error's
[`message`](#dom-gpuerror-message) when possible, and specializing using `instanceof`. Use
`error.constructor.name` when it's necessary to serialize an error (e.g.
into JSON, for a debug report).

[`GPUError`](#gpuerror) has
the following [immutable
properties](#immutable-property):

[`message`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: A human-readable, [localizable
 text](https://www.w3.org/TR/i18n-glossary/#dfn-localizable-text) message providing information about the error that
 occurred.

 This message is generally intended for application
 developers to debug their applications and capture information for
 debug reports, not to be surfaced to end-users.

 User agents should not include potentially
 machine-parsable details in this message, such as free system memory
 on
 [`"out-of-memory"`](#dom-gpuerrorfilter-out-of-memory) or other details about the conditions under which
 memory was exhausted.

 The
 [`message`](#dom-gpuerror-message) should follow the [best practices for language and
 direction
 information](https://w3c.github.io/string-meta/#bp_and-reco). This includes making use of any future standards
 which may emerge regarding the reporting of string language and
 direction metadata.

 [Editorial note:] At the time of this writing, no
 language/direction recommendation is available that provides
 compatibility and consistency with legacy APIs, but when there is,
 adopt it formally.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUValidationError
 : GPUError {
 constructor(DOMString message);
};
```

[`GPUValidationError`](#gpuvalidationerror) is a subtype of
[`GPUError`](#gpuerror) which
indicates that an operation did not satisfy all validation requirements.
Validation errors are always indicative of an application error, and is
expected to fail the same way across all devices assuming the same
[`[[features]]`](#dom-device-features-slot) and
[`[[limits]]`](#dom-device-limits-slot) are in use.

To [generate a validation
error]
for [`GPUDevice`](#gpudevice) `device`, run the following steps:

[Device timeline](#device-timeline) steps:

1. Let `error` be a new
 [`GPUValidationError`](#gpuvalidationerror) with an appropriate error message.

2. [Dispatch
 error](#abstract-opdef-dispatch-error) `error` to `device`.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUOutOfMemoryError
 : GPUError {
 constructor(DOMString message);
};
```

[`GPUOutOfMemoryError`](#gpuoutofmemoryerror) is a subtype of
[`GPUError`](#gpuerror) which
indicates that there was not enough free memory to complete the
requested operation. The operation may succeed if attempted again with a
lower memory requirement (like using smaller texture dimensions), or if
memory used by other resources is released first.

To [ generate an out-of-memory
error]
for [`GPUDevice`](#gpudevice) `device`, run the following steps:

[Device timeline](#device-timeline) steps:

1. Let `error` be a new
 [`GPUOutOfMemoryError`](#gpuoutofmemoryerror) with an appropriate error message.

2. [Dispatch
 error](#abstract-opdef-dispatch-error) `error` to `device`.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUInternalError
 : GPUError {
 constructor(DOMString message);
};
```

[`GPUInternalError`](#gpuinternalerror) is a subtype of
[`GPUError`](#gpuerror) which
indicates than an operation failed for a system or
implementation-specific reason even when all validation requirements
have been satisfied. For example, the operation may exceed the
capabilities of the implementation in a way not easily captured by the
[supported limits](#supported-limits). The same operation may succeed on other devices or
under difference circumstances.

To [generate an internal
error]
for [`GPUDevice`](#gpudevice) `device`, run the following steps:

[Device timeline](#device-timeline) steps:

1. Let `error` be a new
 [`GPUInternalError`](#gpuinternalerror) with an appropriate error message.

2. [Dispatch
 error](#abstract-opdef-dispatch-error) `error` to `device`.

### 22.3. Error Scopes

A [GPU error scope] captures [`GPUError`](#gpuerror)s that were generated while the [GPU error
scope](#gpu-error-scope) was
current. Error scopes are used to isolate errors that occur within a set
of WebGPU calls, typically for debugging purposes or to make an
operation more fault tolerant.

[GPU error scope](#gpu-error-scope) has the following [device timeline
properties](#device-timeline-property):

[`[[errors]]`], of type [list](https://infra.spec.whatwg.org/#list)\<[`GPUError`](#gpuerror)\>, initially \[\]

: The [`GPUError`](#gpuerror)s, if any, observed while the [GPU error
 scope](#gpu-error-scope)
 was current.

[`[[filter]]`], of type [`GPUErrorFilter`](#enumdef-gpuerrorfilter)

: Determines what type of
 [`GPUError`](#gpuerror)
 this [GPU error scope](#gpu-error-scope) observes.

```
enum GPUErrorFilter {
 "validation",
 "out-of-memory",
 "internal",
};

partial interface GPUDevice {
 undefined pushErrorScope(GPUErrorFilter filter);
 Promise<GPUError?> popErrorScope();
};
```

[`GPUErrorFilter`](#enumdef-gpuerrorfilter) defines the type of errors that should be caught when
calling
[`pushErrorScope()`](#dom-gpudevice-pusherrorscope):

[`"validation"`]

: Indicates that the error scope will catch a
 [`GPUValidationError`](#gpuvalidationerror).

[`"out-of-memory"`]

: Indicates that the error scope will catch a
 [`GPUOutOfMemoryError`](#gpuoutofmemoryerror).

[`"internal"`]

: Indicates that the error scope will catch a
 [`GPUInternalError`](#gpuinternalerror).

[`GPUDevice`](#gpudevice)
has the following [device timeline
properties](#device-timeline-property):

[`[[errorScopeStack]]`], of type [stack](https://infra.spec.whatwg.org/#stack)\<[GPU error scope](#gpu-error-scope)\>

: A [stack](https://infra.spec.whatwg.org/#stack) of [GPU error
 scopes](#gpu-error-scope)
 that have been pushed to the
 [`GPUDevice`](#gpudevice).

The [current error scope] for a
[`GPUError`](#gpuerror)
`error` and
[`GPUDevice`](#gpudevice)
`device` is determined by issuing the following steps to the
[device timeline](#device-timeline) of `device`:

[Device timeline](#device-timeline) steps:

1. If `error` is an instance of:

 [`GPUValidationError`](#gpuvalidationerror)

 : Let `type` be \"validation\".

 [`GPUOutOfMemoryError`](#gpuoutofmemoryerror)

 : Let `type` be \"out-of-memory\".

 [`GPUInternalError`](#gpuinternalerror)

 : Let `type` be \"internal\".

2. Let `scope` be the last
 [item](https://infra.spec.whatwg.org/#list-item) of
 `device`.[`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot).

3. While `scope` is not `undefined`:

 1. If
 `scope`.[`[[filter]]`](#dom-gpu-error-scope-filter-slot) is `type`, return
 `scope`.

 2. Set `scope` to the previous
 [item](https://infra.spec.whatwg.org/#list-item) of
 `device`.[`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot).

4. Return `undefined`.

To [dispatch an error]
[`GPUError`](#gpuerror)
`error` on
[`GPUDevice`](#gpudevice)
`device`, run the following [device
timeline](#device-timeline)
steps:

::: {timeline="device"}
[Device timeline](#device-timeline) steps:

 No errors are generated from a device which is lost. If
this algorithm is called while `device` is
[lost](#abstract-opdef-invalid), it will not be observable to the application.
See [§ 22 Errors & Debugging](#errors-and-debugging).

1. Let `scope` be the [current error
 scope](#abstract-opdef-current-error-scope) for `error` and
 `device`.

2. If `scope` is not `undefined`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `error` to
 `scope`.[`[[errors]]`](#dom-gpu-error-scope-errors-slot).

 2. Return.

 Otherwise, issue the following steps to the [content
 timeline](#content-timeline):

::: {timeline="content"}
[Content timeline](#content-timeline) steps:

1. If the user agent chooses, [queue a global task for
 GPUDevice](#abstract-opdef-queue-a-global-task-for-gpudevice) `device` with the following
 steps:

 ::: {timeline="content"}
 1. Fire a
 [`GPUUncapturedErrorEvent`](#gpuuncapturederrorevent) named
 \"[`uncapturederror`](#eventdef-gpudevice-uncapturederror)\" on `device`, with an
 [`error`](#dom-gpuuncapturederrorevent-error) of `error`.
 :::

 After dispatching the event, user agents **should**
surface uncaptured errors to developers, for example as warnings in the
browser's developer console, unless the event's
[`defaultPrevented`](https://dom.spec.whatwg.org/#dom-event-defaultprevented) is true. In other words, calling
[`preventDefault()`](https://dom.spec.whatwg.org/#dom-event-preventdefault) on the event should silence the console warning.

 The user agent may choose to throttle or limit the
number of
[`GPUUncapturedErrorEvent`](#gpuuncapturederrorevent)s that a
[`GPUDevice`](#gpudevice)
can raise to prevent an excessive amount of error handling or logging
from impacting performance.

[`pushErrorScope(filter)`]

: Pushes a new [GPU error
 scope](#gpu-error-scope)
 onto the
 [`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot) for `this`.

 :::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Arguments:**

 Arguments for the
 [GPUDevice.pushErrorScope(filter)](#dom-gpudevice-pusherrorscope) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`filter`]
 [`GPUErrorFilter`](#enumdef-gpuerrorfilter)
 [✘]
 [✘]
 Which class of errors this error scope observes.
 **Returns:**
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

 [Content timeline](#content-timeline) steps:

 1. Issue the subsequent steps on the [Device
 timeline](#device-timeline) of `this`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) steps:
 1. Let `scope` be a new [GPU error
 scope](#gpu-error-scope).

 2. Set
 `scope`.[`[[filter]]`](#dom-gpu-error-scope-filter-slot) to `filter`.

 3. [Push](https://infra.spec.whatwg.org/#stack-push) `scope` onto
 `this`.[`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot).
 :::
 :::::

[`popErrorScope()`]

: Pops a [GPU error scope](#gpu-error-scope) off the
 [`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot) for `this` and resolves to **any**
 [`GPUError`](#gpuerror)
 observed by the error scope, or `null` if none.

 There is no guarantee of the ordering of promise resolution.

 ::::::
 ::: {timeline="content"}
 **Called on:** [`GPUDevice`](#gpudevice) `this`.
 **Returns:**
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`GPUError`](#gpuerror)?\>

 [Content timeline](#content-timeline) steps:

 1. Let `contentTimeline` be the
 current [Content
 timeline](#content-timeline).

 2. Let `promise` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise).

 3. Issue the `check steps` on the [Device
 timeline](#device-timeline) of `this`.

 4. Return `promise`.
 :::

 ::: {timeline="device"}
 [Device timeline](#device-timeline) `check steps`:
 1. If `this` is
 [lost](#abstract-opdef-invalid):

 1. Issue the following steps on `contentTimeline`:

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with `null`.
 :::

 2. Return.

 No errors are generated from a device which is
 lost. See [§ 22 Errors & Debugging](#errors-and-debugging).

 2. If any of the following requirements are unmet:

 ::: validusage
 - `this`.[`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot).[size](https://infra.spec.whatwg.org/#list-size) must be \> 0.
 :::

 Then issue the following steps on `contentTimeline` and return:

 ::: {timeline="content"}
 [Content
 timeline](#content-timeline) steps:
 1. [Reject](https://webidl.spec.whatwg.org/#reject) `promise` with an
 [`OperationError`](https://webidl.spec.whatwg.org/#operationerror).
 :::

 3. Let `scope` be the result of
 [popping](https://infra.spec.whatwg.org/#stack-pop) an
 [item](https://infra.spec.whatwg.org/#list-item) off of
 `this`.[`[[errorScopeStack]]`](#dom-gpudevice-errorscopestack-slot).

 4. Let `error` be **any** one of the items in
 `scope`.[`[[errors]]`](#dom-gpu-error-scope-errors-slot), or `null` if there are none.

 For any two errors E1 and E2 in the list, if E2 was caused by
 E1, E2 **should not** be the one selected.

 For example, if E1 comes from `t` =
 [`createTexture()`](#dom-gpudevice-createtexture), and E2 comes from
 `t`.[`createView()`](#dom-gputexture-createview) because `t` was
 [invalid](#abstract-opdef-invalid), E1 should be be preferred since it
 will be easier for a developer to understand what went wrong.
 Since both of these are
 [`GPUValidationError`](#gpuvalidationerror)s, the only difference will be in the
 [`message`](#dom-gpuerror-message) field, which is meant only to be read by humans
 anyway.

 5. At an **unspecified point now or in the future**, issue the
 subsequent steps on `contentTimeline`.

 By allowing
 [`popErrorScope()`](#dom-gpudevice-poperrorscope) calls to resolve in any order, with any of the
 errors observed by the scope, this spec allows validation to
 complete out of order, as long as any state observations are
 made at the appropriate point in adherence to this spec. For
 example, this allows implementations to perform shader
 compilation, which depends only on non-stateful inputs, to be
 completed on a background thread in parallel with other
 device-timeline work, and report any resulting errors later.
 :::

 ::: {timeline="content"}
 [Content timeline](#content-timeline) steps:
 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise` with `error`.
 :::
 ::::::

Using error scopes to capture
validation errors from a
[`GPUDevice`](#gpudevice)
operation that may fail:

``` highlight
gpuDevice.pushErrorScope('validation');

let sampler = gpuDevice.createSampler({
 maxAnisotropy: 0, // Invalid, maxAnisotropy must be at least 1.
});

gpuDevice.popErrorScope().then((error) => {
 if (error) {
 // There was an error creating the sampler, so discard it.
 sampler = null;
 console.error(`An error occured while creating sampler: ${error.message}`);
 }
});
```

NOTE:

Error scopes can encompass as many commands as needed. The number of
commands an error scope covers will generally be correlated to what sort
of action the application intends to take in response to an error
occuring.

For example: An error scope that only contains the creation of a single
resource, such as a texture or buffer, can be used to detect failures
such as out of memory conditions, in which case the application may try
freeing some resources and trying the allocation again.

Error scopes do not identify which command failed, however. So, for
instance, wrapping all the commands executed while loading a model in a
single error scope will not offer enough granularity to determine if the
issue was due to memory constraints. As a result freeing resources would
usually not be a productive response to a failure of that scope. A more
appropriate response would be to allow the application to fall back to a
different model or produce a warning that the model could not be loaded.
If responding to memory constraints is desired, the operations
allocating memory can always be wrapped in a smaller nested error scope.

### 22.4. Telemetry

When a [`GPUError`](#gpuerror) is generated that is not observed by any [GPU error
scope](#gpu-error-scope),
the user agent **may** [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire) named
[`uncapturederror`]
at a [`GPUDevice`](#gpudevice) using
[`GPUUncapturedErrorEvent`](#gpuuncapturederrorevent).

[`uncapturederror`](#eventdef-gpudevice-uncapturederror) events are intended to be used for telemetry and
reporting unexpected errors. They won't necessarily be dispatched for
all uncaptured errors (for example, there may be a limit on the number
of errors surfaced), so they should not be used for handling known error
cases that may occur during normal operation of an application. Prefer
using
[`pushErrorScope()`](#dom-gpudevice-pusherrorscope) and
[`popErrorScope()`](#dom-gpudevice-poperrorscope) in those cases.

```
[Exposed=(Window, Worker), SecureContext]
interface GPUUncapturedErrorEvent : Event {
 constructor(
 DOMString type,
 GPUUncapturedErrorEventInit gpuUncapturedErrorEventInitDict
 );
 [SameObject] readonly attribute GPUError error;
};

dictionary GPUUncapturedErrorEventInit : EventInit {
 required GPUError error;
};
```

[`GPUUncapturedErrorEvent`](#gpuuncapturederrorevent) has the following attributes:

[`error`], of type [GPUError](#gpuerror), readonly

: A [slot-backed
 attribute](#slot-backed-attribute) holding an object representing the error that was
 uncaptured. This has the same type as errors returned by
 [`popErrorScope()`](#dom-gpudevice-poperrorscope).

```
partial interface GPUDevice {
 attribute EventHandler onuncapturederror;
};
```

[`GPUDevice`](#gpudevice)
has the following [content timeline
properties](#content-timeline-property):

[`onuncapturederror`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for the
 [`uncapturederror`](#eventdef-gpudevice-uncapturederror) event type.

Listening for uncaptured errors from a
[`GPUDevice`](#gpudevice):

``` highlight
gpuDevice.addEventListener('uncapturederror', (event) => {
 // Re-surface the error, because adding an event listener may silence console logs.
 console.error('A WebGPU error was not captured:', event.error);

 myEngineDebugReport.uncapturedErrors.push({
 type: event.error.constructor.name,
 message: event.error.message,
 });
});
```

## 23. Detailed Operations

This section describes the details of various GPU operations.

### 23.1. Computing

Computing operations provide direct access to GPU's programmable
hardware. Compute shaders do not have shader stage inputs or outputs;
their results are side effects from writing data into storage bindings
bound either as
[`GPUBufferBindingLayout`](#dictdef-gpubufferbindinglayout) with
[`GPUBufferBindingType`](#enumdef-gpubufferbindingtype)
[`"storage"`](#dom-gpubufferbindingtype-storage) or as
[`GPUStorageTextureBindingLayout`](#dictdef-gpustoragetexturebindinglayout). These operations are encoded within
[`GPUComputePassEncoder`](#gpucomputepassencoder) as:

- [`dispatchWorkgroups()`](#dom-gpucomputepassencoder-dispatchworkgroups)

- [`dispatchWorkgroupsIndirect()`](#dom-gpucomputepassencoder-dispatchworkgroupsindirect)

The main compute algorithm:

[compute](`descriptor`,
`dispatchCall`)

**Arguments:**

- `descriptor`: Description of the current
 [`GPUComputePipeline`](#gpucomputepipeline).

- `dispatchCall`: The dispatch call parameters. May come from
 function arguments or an
 [`INDIRECT`](#dom-gpubufferusage-indirect) buffer.

1. Let `computeInvocations` be an
 [empty](https://infra.spec.whatwg.org/#list-empty)
 [list](https://infra.spec.whatwg.org/#list).

2. Let `computeStage` be
 `descriptor`.[`compute`](#dom-gpucomputepipelinedescriptor-compute).

3. Let `workgroupSize` be the computed workgroup size for
 `computeStage`.[`entryPoint`](#dom-gpuprogrammablestage-entrypoint) after applying
 `computeStage`.[`constants`](#dom-gpuprogrammablestage-constants) to
 `computeStage`.[`module`](#dom-gpuprogrammablestage-module).

4. For `workgroupX` in range
 `[0, ``dispatchCall``.``workgroupCountX``]`:

 1. For `workgroupY` in range
 `[0, ``dispatchCall``.``workgroupCountY``]`:

 1. For `workgroupZ` in range
 `[0, ``dispatchCall``.``workgroupCountZ``]`:

 1. For `localX` in range
 `[0, ``workgroupSize``.``x``]`:

 1. For `localY` in range
 `[0, ``workgroupSize``.``y``]`:

 1. For `localZ` in range
 `[0, ``workgroupSize``.``y``]`:

 1. Let `invocation` be
 `{ ``computeStage``, ``workgroupX``, ``workgroupY``, ``workgroupZ``, ``localX``, ``localY``, ``localZ`` }`

 2. [Append](https://infra.spec.whatwg.org/#list-append) `invocation` to
 `computeInvocations`.

5. For every `invocation` in
 `computeInvocations`, in any order the
 [device](#device) chooses,
 including in parallel:

 1. Set the shader
 [builtins](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values):

 - Set the
 [num_workgroups](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-num_workgroups) builtin, if any, to `(`\
 `dispatchCall``.``workgroupCountX``,`\
 `dispatchCall``.``workgroupCountY``,`\
 `dispatchCall``.``workgroupCountZ`\
 `)`

 - Set the
 [workgroup_id](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-workgroup_id) builtin, if any, to `(`\
 `invocation``.``workgroupX``,`\
 `invocation``.``workgroupY``,`\
 `invocation``.``workgroupZ`\
 `)`

 - Set the
 [local_invocation_id](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-local_invocation_id) builtin, if any, to `(`\
 `invocation``.``localX``,`\
 `invocation``.``localY``,`\
 `invocation``.``localZ`\
 `)`

 - Set the
 [global_invocation_id](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-global_invocation_id) builtin, if any, to `(`\
 `invocation``.``workgroupX`` * ``workgroupSize``.``x`` + ``invocation``.``localX``,`\
 `invocation``.``workgroupY`` * ``workgroupSize``.``y`` + ``invocation``.``localY``,`\
 `invocation``.``workgroupZ`` * ``workgroupSize``.``z`` + ``invocation``.``localZ`\
 `)`.

 - Set the
 [local_invocation_index](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-local_invocation_index) builtin, if any, to
 ` ``invocation``.``localX`` + (``invocation``.``localY`` * ``workgroupSize``.``x``) + (``invocation``.``localZ`` * ``workgroupSize``.``x`` * ``workgroupSize``.``y``) `

 2. Invoke the compute shader entry point described by
 `invocation`.`computeStage`.

 Shader invocations have no guaranteed order, and will
generally run in parallel according to device capabilities. Developers
should not assume that any given invocation or workgroup will complete
before any other one is started. Some devices may appear to execute in a
consistent order, but this behavior should not be relied on as it will
not perform identically across all devices. Shaders that require
synchronization across invocations must use [Synchronization Built-in
Functions](https://gpuweb.github.io/gpuweb/wgsl/#sync-builtin-functions) to coordinate execution.

The [device](#device) may become
[lost](#lose-the-device) if
[shader execution does not
end](https://gpuweb.github.io/gpuweb/wgsl/#shader-execution-end) in a reasonable amount of time, as determined by the
user agent.

### 23.2. Rendering

Rendering is done by a set of GPU operations that are executed within
[`GPURenderPassEncoder`](#gpurenderpassencoder), and result in modifications of the texture data,
viewed by the render pass attachments. These operations are encoded
with:

- [`draw()`](#dom-gpurendercommandsmixin-draw)

- [`drawIndexed()`](#dom-gpurendercommandsmixin-drawindexed),

- [`drawIndirect()`](#dom-gpurendercommandsmixin-drawindirect)

- [`drawIndexedIndirect()`](#dom-gpurendercommandsmixin-drawindexedindirect).

 rendering is the traditional use of GPUs, and is
supported by multiple fixed-function blocks in hardware.

The main rendering algorithm:

[render](pipeline, drawCall, state)

**Arguments:**

- `pipeline`: The current
 [`GPURenderPipeline`](#gpurenderpipeline).

- `drawCall`: The draw call parameters. May come from
 function arguments or an
 [`INDIRECT`](#dom-gpubufferusage-indirect) buffer.

- `state`: [RenderState](#renderstate) of the
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) where the draw call is issued.

1. Let `descriptor` be
 `pipeline`.[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).

2. **Resolve indices**. See [§ 23.2.1 Index
 Resolution](#index-resolution).

 Let `vertexList` be the result of [resolve
 indices](#abstract-opdef-resolve-indices)(`drawCall`, `state`).

3. **Process vertices**. See [§ 23.2.2 Vertex
 Processing](#vertex-processing).

 Execute [process
 vertices](#abstract-opdef-process-vertices)(`vertexList`,
 `drawCall`,
 `descriptor`.[`vertex`](#dom-gpurenderpipelinedescriptor-vertex), `state`).

4. **Assemble primitives**. See [§ 23.2.3 Primitive
 Assembly](#primitive-assembly).

 Execute [assemble
 primitives](#abstract-opdef-assemble-primitives)(`vertexList`,
 `drawCall`,
 `descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive)).

5. **Clip primitives**. See [§ 23.2.4 Primitive
 Clipping](#primitive-clipping).

 Let `primitiveList` be the result of this stage.

6. **Rasterize**. See [§ 23.2.5 Rasterization](#rasterization).

 Let `rasterizationList` be the result of
 [rasterize](#abstract-opdef-rasterize)(`primitiveList`,
 `state`).

7. **Process fragments**. See [§ 23.2.6 Fragment
 Processing](#fragment-processing).

 Gather a list of `fragments`, resulting from executing
 [process
 fragment](#abstract-opdef-process-fragment)(`rasterPoint`,
 `descriptor`, `state`) for each
 `rasterPoint` in `rasterizationList`.

8. **Write pixels**. See [§ 23.2.7 Output Merging](#output-merging).

 For each non-null `fragment` of `fragments`:

 - Execute [process depth
 stencil](#abstract-opdef-process-depth-stencil)(`fragment`,
 `pipeline`, `state`).

 - Execute [process color
 attachments](#abstract-opdef-process-color-attachments)(`fragment`,
 `pipeline`, `state`).

#### 23.2.1. Index Resolution

At the first stage of rendering, the pipeline builds a list of vertices
to process for each instance.

[resolve indices](drawCall, state)

**Arguments:**

- `drawCall`: The draw call parameters. May come from
 function arguments or an
 [`INDIRECT`](#dom-gpubufferusage-indirect) buffer.

- `state`: The snapshot of the
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) state at the time of the draw call.

**Returns:** list of integer indices.

1. Let `vertexIndexList` be an empty list of indices.

2. If `drawCall` is an indexed draw call:

 1. Initialize the `vertexIndexList` with
 `drawCall`.indexCount integers.

 2. For `i` in range 0 ..
 `drawCall`.indexCount (non-inclusive):

 1. Let `relativeVertexIndex` be [fetch
 index](#abstract-opdef-fetch-index)(`i` +
 `drawCall`.`firstIndex`,
 `state`.[`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot)).

 2. If `relativeVertexIndex` has the special value
 `"out of bounds"`, return the empty list.

 Implementations may choose to display a
 warning when this occurs, especially when it is easy to
 detect (like in non-indirect indexed draw calls).

 3. Append `drawCall`.`baseVertex` +
 `relativeVertexIndex` to the
 `vertexIndexList`.

 Otherwise:

 1. Initialize the `vertexIndexList` with
 `drawCall`.vertexCount integers.

 2. Set each `vertexIndexList` item `i` to the
 value `drawCall`.firstVertex + `i`.

3. Return `vertexIndexList`.

 in the case of indirect draw calls, the `indexCount`,
`vertexCount`, and other properties of `drawCall` are read
from the indirect buffer instead of the draw command itself.

[fetch index](i, buffer, offset, format)

**Arguments:**

- `i`: Index of a vertex index to fetch.

- `state`: The snapshot of the
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) state at the time of the draw call.

**Returns:** unsigned integer or `"out of bounds"`

1. Let `indexSize` be defined by the
 `state`.[`[[index_format]]`](#dom-gpurendercommandsmixin-index_format-slot):

 [`"uint16"`](#dom-gpuindexformat-uint16)

 : 2

 [`"uint32"`](#dom-gpuindexformat-uint32)

 : 4

2. If
 `state`.[`[[index_buffer_offset]]`](#dom-gpurendercommandsmixin-index_buffer_offset-slot) + \|i + 1\| × `indexSize` \>
 `state`.[`[[index_buffer_size]]`](#dom-gpurendercommandsmixin-index_buffer_size-slot), return the special value `"out of bounds"`.

3. Interpret the data in
 `state`.[`[[index_buffer]]`](#dom-gpurendercommandsmixin-index_buffer-slot), starting at offset
 `state`.[`[[index_buffer_offset]]`](#dom-gpurendercommandsmixin-index_buffer_offset-slot) + `i` × `indexSize`, of size
 `indexSize` bytes, as an unsigned integer and return it.

#### 23.2.2. Vertex Processing

Vertex processing stage is a programmable stage of the render
[pipeline](#pipeline) that
processes the vertex attribute data, and produces clip space positions
for [§ 23.2.4 Primitive Clipping](#primitive-clipping), as well as other
data for the [§ 23.2.6 Fragment Processing](#fragment-processing).

[process vertices](vertexIndexList, drawCall, desc,
state)

**Arguments:**

- `vertexIndexList`: List of vertex indices to process
 (mutable, passed by reference).

- `drawCall`: The draw call parameters. May come from
 function arguments or an
 [`INDIRECT`](#dom-gpubufferusage-indirect) buffer.

- `desc`: The descriptor of type
 [`GPUVertexState`](#dictdef-gpuvertexstate).

- `state`: The snapshot of the
 [`GPURenderCommandsMixin`](#gpurendercommandsmixin) state at the time of the draw call.

Each vertex `vertexIndex` in the
`vertexIndexList`, in each instance of index
`rawInstanceIndex`, is processed independently. The
`rawInstanceIndex` is in range from 0 to
`drawCall`.instanceCount - 1, inclusive. This processing
happens in parallel, and any side effects, such as writes into
[`GPUBufferBindingType`](#enumdef-gpubufferbindingtype)
[`"storage"`](#dom-gpubufferbindingtype-storage) bindings, may happen in any order.

1. Let `instanceIndex` be `rawInstanceIndex` +
 `drawCall`.firstInstance.

2. For each non-`null` `vertexBufferLayout` in the list of
 `desc`.[`buffers`](#dom-gpuvertexstate-buffers):

 1. Let `i` be the index of the buffer layout in this
 list.

 2. Let `vertexBuffer`, `vertexBufferOffset`,
 and `vertexBufferBindingSize` be the buffer, offset,
 and size at slot `i` of
 `state`.[`[[vertex_buffers]]`](#dom-gpurendercommandsmixin-vertex_buffers-slot).

 3. Let `vertexElementIndex` be dependent on
 `vertexBufferLayout`.[`stepMode`](#dom-gpuvertexbufferlayout-stepmode):

 [`"vertex"`](#dom-gpuvertexstepmode-vertex)

 : `vertexIndex`

 [`"instance"`](#dom-gpuvertexstepmode-instance)

 : `instanceIndex`

 4. Let `drawCallOutOfBounds` be `false`.

 5. For each `attributeDesc` in
 `vertexBufferLayout`.[`attributes`](#dom-gpuvertexbufferlayout-attributes):

 1. Let `attributeOffset` be
 `vertexBufferOffset` +
 `vertexElementIndex` \*
 `vertexBufferLayout`.[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) +
 `attributeDesc`.[`offset`](#dom-gpuvertexattribute-offset).

 2. If `attributeOffset` +
 [byteSize](#abstract-opdef-gpuvertexformat-bytesize)(`attributeDesc`.[`format`](#dom-gpuvertexattribute-format)) \> `vertexBufferOffset` +
 `vertexBufferBindingSize`:

 1. Set `drawCallOutOfBounds` to `true`.

 2. **Optionally
 ([implementation-defined](https://infra.spec.whatwg.org/#implementation-defined))**,
 [empty](https://infra.spec.whatwg.org/#list-empty) `vertexIndexList` and
 return, cancelling the draw call.

 This allows implementations to detect
 out-of-bounds values in the index buffer before issuing
 a draw call, instead of using [invalid memory
 reference](https://gpuweb.github.io/gpuweb/wgsl/#invalid-memory-reference) behavior.

 6. For each `attributeDesc` in
 `vertexBufferLayout`.[`attributes`](#dom-gpuvertexbufferlayout-attributes):

 1. If `drawCallOutOfBounds` is `true`:

 1. Load the attribute `data` according to WGSL's
 [invalid memory
 reference](https://gpuweb.github.io/gpuweb/wgsl/#invalid-memory-reference) behavior, from
 `vertexBuffer`.

 [Invalid memory
 reference](https://gpuweb.github.io/gpuweb/wgsl/#invalid-memory-reference) allows several behaviors, including
 actually loading the \"correct\" result for an attribute
 that is in-bounds, even when the draw-call-wide
 `drawCallOutOfBounds` is `true`.

 Otherwise:

 1. Let `attributeOffset` be
 `vertexBufferOffset` +
 `vertexElementIndex` \*
 `vertexBufferLayout`.[`arrayStride`](#dom-gpuvertexbufferlayout-arraystride) +
 `attributeDesc`.[`offset`](#dom-gpuvertexattribute-offset).

 2. Load the attribute `data` of format
 `attributeDesc`.[`format`](#dom-gpuvertexattribute-format) from `vertexBuffer` starting
 at offset `attributeOffset`. The components
 are loaded in the order `x`, `y`, `z`, `w` from buffer
 memory.

 2. Convert the `data` into a shader-visible format,
 according to [channel
 formats](https://gpuweb.github.io/gpuweb/wgsl/#channel-formats) rules.

 :::
 (#example-efaa9763) An attribute of type
 [`"snorm8x2"`](#dom-gpuvertexformat-snorm8x2) and byte values of `[0x70, 0xD0]` will be
 converted to `vec2<f32>(0.88, -0.38)` in WGSL.
 :::

 3. Adjust the `data` size to the shader type:

 - if both are scalar, or both are vectors of the same
 dimensionality, no adjustment is needed.

 - if `data` is vector but the shader type is
 scalar, then only the first component is extracted.

 - if both are vectors, and `data` has a higher
 dimension, the extra components are dropped.

 :::
 (#example-b889e1a6) An attribute of type
 [`"float32x3"`](#dom-gpuvertexformat-float32x3) and value `vec3<f32>(1.0, 2.0, 3.0)` will
 exposed to the shader as `vec2<f32>(1.0, 2.0)` if a
 2-component vector is expected.
 :::

 - if the shader type is a vector of higher dimensionality,
 or the `data` is a scalar, then the missing
 components are filled from `vec4<*>(0, 0, 0, 1)` value.

 :::
 (#example-ada0b71a) An attribute of type
 [`"sint32"`](#dom-gpuvertexformat-sint32) and value `5` will be exposed to the
 shader as `vec4<i32>(5, 0, 0, 1)` if a 4-component vector
 is expected.
 :::

 4. Bind the `data` to vertex shader input location
 `attributeDesc`.[`shaderLocation`](#dom-gpuvertexattribute-shaderlocation).

3. For each
 [`GPUBindGroup`](#gpubindgroup) group at `index` in
 `state`.[`[[bind_groups]]`](#dom-gpubindingcommandsmixin-bind_groups-slot):

 1. For each resource
 [`GPUBindingResource`](#typedefdef-gpubindingresource) in the bind group:

 1. Let `entry` be the corresponding
 [`GPUBindGroupLayoutEntry`](#dictdef-gpubindgrouplayoutentry) for this resource.

 2. If
 `entry`.[`visibility`](#dom-gpubindgrouplayoutentry-visibility) includes
 [`VERTEX`](#dom-gpushaderstage-vertex):

 - Bind the resource to the shader under group
 `index` and binding
 [`GPUBindGroupLayoutEntry.binding`](#dom-gpubindgrouplayoutentry-binding).

4. Set the shader
 [builtins](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values):

 - Set the `vertex_index` builtin, if any, to
 `vertexIndex`.

 - Set the `instance_index` builtin, if any, to
 `instanceIndex`.

5. Invoke the vertex shader entry point described by `desc`.

 The target platform caches the results of vertex
 shader invocations. There is no guarantee that any
 `vertexIndex` that repeats more than once will result in
 multiple invocations. Similarly, there is no guarantee that a single
 `vertexIndex` will only be processed once.

 The [device](#device) may become
 [lost](#lose-the-device)
 if [shader execution does not
 end](https://gpuweb.github.io/gpuweb/wgsl/#shader-execution-end) in a reasonable amount of time, as determined by
 the user agent.

#### 23.2.3. Primitive Assembly

Primitives are assembled by a fixed-function stage of GPUs.

[assemble primitives](vertexIndexList,
drawCall, desc)

**Arguments:**

- `vertexIndexList`: List of vertex indices to process.

- `drawCall`: The draw call parameters. May come from
 function arguments or an
 [`INDIRECT`](#dom-gpubufferusage-indirect) buffer.

- `desc`: The descriptor of type
 [`GPUPrimitiveState`](#dictdef-gpuprimitivestate).

For each instance, the primitives get assembled from the vertices that
have been processed by the shaders, based on the
`vertexIndexList`.

1. First, if the primitive topology is a strip, (which means that
 `desc`.[`stripIndexFormat`](#dom-gpuprimitivestate-stripindexformat) is not undefined) and the `drawCall` is
 indexed, the `vertexIndexList` is split into sub-lists
 using the maximum value of
 `desc`.[`stripIndexFormat`](#dom-gpuprimitivestate-stripindexformat) as a separator.

 Example: a `vertexIndexList` with values
 `[1, 2, 65535, 4, 5, 6]` of type
 [`"uint16"`](#dom-gpuindexformat-uint16) will be split in sub-lists `[1, 2]` and
 `[4, 5, 6]`.

2. For each of the sub-lists `vl`, primitive generation is
 done according to the
 `desc`.[`topology`](#dom-gpuprimitivestate-topology):

 [`"line-list"`](#dom-gpuprimitivetopology-line-list)

 : Line primitives are composed from (`vl`.0,
 `vl`.1), then (`vl`.2, `vl`.3),
 then (`vl`.4 to `vl`.5), etc. Each
 subsequent primitive takes 2 vertices.

 [`"line-strip"`](#dom-gpuprimitivetopology-line-strip)

 : Line primitives are composed from (`vl`.0,
 `vl`.1), then (`vl`.1, `vl`.2),
 then (`vl`.2, `vl`.3), etc. Each
 subsequent primitive takes 1 vertex.

 [`"triangle-list"`](#dom-gpuprimitivetopology-triangle-list)

 : Triangle primitives are composed from (`vl`.0,
 `vl`.1, `vl`.2), then (`vl`.3,
 `vl`.4, `vl`.5), then (`vl`.6,
 `vl`.7, `vl`.8), etc. Each subsequent
 primitive takes 3 vertices.

 [`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip)

 : Triangle primitives are composed from (`vl`.0,
 `vl`.1, `vl`.2), then (`vl`.2,
 `vl`.1, `vl`.3), then (`vl`.2,
 `vl`.3, `vl`.4), then (`vl`.4,
 `vl`.3, `vl`.5), etc. Each subsequent
 primitive takes 1 vertices.

 Any incomplete primitives are dropped.

#### 23.2.4. Primitive Clipping

Vertex shaders have to produce a built-in
[position](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-position) (of type `vec4<f32>`), which denotes the [clip
position]
of a vertex in [clip space
coordinates](#clip-space-coordinates).

Primitives are clipped to the [clip volume], which, for any [clip
position](#clip-position)
`p` inside a primitive, is defined by the following
inequalities:

- −`p`.w ≤ `p`.x ≤ `p`.w

- −`p`.w ≤ `p`.y ≤ `p`.w

- 0 ≤ `p`.z ≤ `p`.w ([depth
 clipping])

When the
[`"clip-distances"`](#dom-gpufeaturename-clip-distances) feature is enabled, this [clip
volume](#clip-volume) can be
further restricted by user-defined half-spaces by declaring
[clip_distances](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-clip_distances) in the output of vertex stage. Each value in the
[clip_distances](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-clip_distances) array will be linearly interpolated across the
primitive, and the portion of the primitive with interpolated distances
less than 0 will be clipped.

If
`descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`unclippedDepth`](#dom-gpuprimitivestate-unclippeddepth) is `true`, [depth
clipping](#depth-clipping) is
not applied: the [clip volume](#clip-volume) is not bounded in the z dimension.

A primitive passes through this stage unchanged if every one of its
edges lie entirely inside the [clip
volume](#clip-volume). If the
edges of a primitives intersect the boundary of the [clip
volume](#clip-volume), the
intersecting edges are reconnected by new edges that lie along the
boundary of the [clip volume](#clip-volume). For triangular primitives
(`descriptor`.[`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`topology`](#dom-gpuprimitivestate-topology) is
[`"triangle-list"`](#dom-gpuprimitivetopology-triangle-list) or
[`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip)), this reconnection may result in introduction of new
vertices into the polygon, internally.

If a primitive intersects an edge of the [clip
volume](#clip-volume)'s boundary,
the clipped polygon must include a point on this boundary edge.

If the vertex shader outputs other floating-point values (scalars and
vectors), qualified with \"perspective\" interpolation, they also get
clipped. The output values associated with a vertex that lies within the
clip volume are unaffected by clipping. If a primitive is clipped,
however, the output values assigned to vertices produced by clipping are
clipped.

Considering an edge between vertices `a` and `b`
that got clipped, resulting in the vertex `c`, let's define
`t` to be the ratio between the edge vertices:
`c`.p = `t` × `a`.p + (1 −
`t`) × `b`.p, where `x`.p is the output
[clip position](#clip-position)
of a vertex `x`.

For each vertex output value \"v\" with a corresponding fragment input,
`a`.v and `b`.v would be the outputs for
`a` and `b` vertices respectively. The clipped
shader output `c`.v is produced based on the interpolation
qualifier:

[flat](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-type-flat)

: Flat interpolation is unaffected, and is based on the [provoking
 vertex], which is determined by the [interpolation
 sampling](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-sampling) mode declared in the shader. The output value is
 the same for the whole primitive, and matches the vertex output of
 the [provoking vertex](#provoking-vertex).

[linear](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-type-linear)

: The interpolation ratio gets adjusted against the perspective
 coordinates of the [clip
 position](#clip-position)s,
 so that the result of interpolation is linear in screen space.

[perspective](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-type-perspective)

: The value is linearly interpolated in clip space, producing
 perspective-correct values.

The result of primitive clipping is a new set of primitives, which are
contained within the [clip volume](#clip-volume).

#### 23.2.5. Rasterization

Rasterization is the hardware processing stage that maps the generated
primitives to the 2-dimensional rendering area of the
[framebuffer] - the set of render attachments in the current
[`GPURenderPassEncoder`](#gpurenderpassencoder). This rendering area is split into an even grid of
pixels.

The [framebuffer](#framebuffer)
coordinates start from the top-left corner of the render targets. Each
unit corresponds exactly to one pixel. See [§ 3.3 Coordinate
Systems](#coordinate-systems) for more information.

Rasterization determines the set of pixels affected by a primitive. In
case of multi-sampling, each pixel is further split into
`descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`count`](#dom-gpumultisamplestate-count) samples. The [standard sample
patterns] are as follows, with positions in framebuffer coordinates
relative to the top-left corner of the pixel, such that the pixel ranges
from (0, 0) to (1, 1):

[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`count`](#dom-gpumultisamplestate-count)

Sample positions

1

Sample 0: (0.5, 0.5)

4

Sample 0: (0.375, 0.125)\
Sample 1: (0.875, 0.375)\
Sample 2: (0.125, 0.625)\
Sample 3: (0.625, 0.875)

Implementations must use the [standard sample
pattern](#standard-sample-patterns) for the given
[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`count`](#dom-gpumultisamplestate-count) when performing rasterization.

Let's define a [FragmentDestination] to contain:

[position]

: the 2D pixel position using [framebuffer
 coordinates](#framebuffer-coordinates)

[sampleIndex]

: an integer in case [§ 23.2.10 Per-Sample
 Shading](#per-sample-shading) is active, or `null` otherwise

We'll also use a notion of [normalized device
coordinates](#ndc), or NDC. In this
coordinate system, the viewport bounds range in X and Y from -1 to 1,
and in Z from 0 to 1.

Rasterization produces a list of
[RasterizationPoint]s, each containing the following data:

[destination]

: refers to
 [FragmentDestination](#fragmentdestination)

[coverageMask]

: refers to multisample coverage mask (see [§ 23.2.11 Sample
 Masking](#sample-masking))

[frontFacing]

: is true if it's a point on the front face of a primitive

[perspectiveDivisor]

: refers to interpolated 1.0 ÷ W across the primitive

[depth]

: refers to the depth in [viewport
 coordinates](#viewport-coordinates), i.e. between the
 [`[[viewport]]`](#dom-renderstate-viewport-slot) `minDepth` and `maxDepth`.

[primitiveVertices]

: refers to the list of vertex outputs forming the primitive

[barycentricCoordinates]

: refers to [§ 23.2.5.3 Barycentric
 coordinates](#barycentric-coordinates)

[rasterize](primitiveList, state)

**Arguments:**

- `primitiveList`: List of primitives to rasterize.

- `state`: The active
 [RenderState](#renderstate).

**Returns:** list of
[RasterizationPoint](#rasterizationpoint).

Each primitive in `primitiveList` is processed independently.
However, the order of primitives affects later stages, such as
depth/stencil operations and pixel writes.

1. First, the clipped vertices are transformed into
 [NDC](#ndc) - normalized device
 coordinates. Given the output position `p`, the
 [NDC](#ndc) position and perspective
 divisor are:

 ndc(`p`) = vector(`p`.x ÷ `p`.w,
 `p`.y ÷ `p`.w, `p`.z ÷
 `p`.w)

 divisor(`p`) = 1.0 ÷ `p`.w

2. Let `vp` be
 `state`.[`[[viewport]]`](#dom-renderstate-viewport-slot). Map the [NDC](#ndc)
 position `n` into [viewport
 coordinates](#viewport-coordinates):

 - Compute [framebuffer](#framebuffer) coordinates from the render target offset and
 size:

 framebufferCoords(`n`) = vector(`vp`.`x` +
 0.5 × (`n`.x + 1) × `vp`.`width`,
 `vp`.`y` + 0.5 × (−`n`.y + 1) ×
 `vp`.`height`)

 - Compute depth by linearly mapping \[0,1\] to the viewport depth
 range:

 depth(`n`) = `vp`.`minDepth` +
 `n`.`z` × ( `vp`.`maxDepth` -
 `vp`.`minDepth` )

3. Let `rasterizationPoints` be the list of points, each
 having its attributes (`divisor(p)`, `framebufferCoords(n)`,
 `depth(n)`, etc.) interpolated according to its position on the
 primitive, using the same interpolation as [§ 23.2.4 Primitive
 Clipping](#primitive-clipping). If the attribute is user-defined
 (not a [built-in output
 value](https://gpuweb.github.io/gpuweb/wgsl/#built-in-output-value)) then the [interpolation
 type](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-type) specified by the
 [\@interpolate](https://gpuweb.github.io/gpuweb/wgsl/#interpolate-attr) WGSL attribute is used.

4. Proceed with a specific rasterization algorithm, depending on
 [`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`topology`](#dom-gpuprimitivestate-topology):

 [`"point-list"`](#dom-gpuprimitivetopology-point-list)

 : The point, if not filtered by [§ 23.2.4 Primitive
 Clipping](#primitive-clipping), goes into [§ 23.2.5.1 Point
 Rasterization](#point-rasterization).

 [`"line-list"`](#dom-gpuprimitivetopology-line-list) or [`"line-strip"`](#dom-gpuprimitivetopology-line-strip)

 : The line cut by [§ 23.2.4 Primitive
 Clipping](#primitive-clipping) goes into [§ 23.2.5.2 Line
 Rasterization](#line-rasterization).

 [`"triangle-list"`](#dom-gpuprimitivetopology-triangle-list) or [`"triangle-strip"`](#dom-gpuprimitivetopology-triangle-strip)

 : The polygon produced in [§ 23.2.4 Primitive
 Clipping](#primitive-clipping) goes into [§ 23.2.5.4 Polygon
 Rasterization](#polygon-rasterization).

5. Remove all the points `rp` from
 `rasterizationPoints` that have
 `rp`.[destination](#rasterizationpoint-destination).[position](#fragmentdestination-position) outside of
 `state`.[`[[scissorRect]]`](#dom-renderstate-scissorrect-slot).

6. Return `rasterizationPoints`.

##### 23.2.5.1. Point Rasterization

A single
[FragmentDestination](#fragmentdestination) is selected within the pixel containing the
[framebuffer](#framebuffer)
coordinates of the point.

The coverage mask depends on multi-sampling mode:

sample-frequency

: coverageMask = 1 ≪ `sampleIndex`

pixel-frequency multi-sampling

: coverageMask = 1 ≪
 `descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`count`](#dom-gpumultisamplestate-count) − 1

no multi-sampling

: coverageMask = 1

##### 23.2.5.2. Line Rasterization

The exact algorithm used for line rasterization is not defined, and may
differ between implementations. For example, the line may be drawn using
[§ 23.2.5.4 Polygon Rasterization](#polygon-rasterization) of a
1px-width rectangle around the line segment, or using Bresenham's line
algorithm to select the
[FragmentDestination](#fragmentdestination)s.

 See [Basic Line Segment
Rasterization](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html#primsrast-lines-basic)
and [Bresenham Line Segment
Rasterization](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html#primsrast-lines-bresenham)
in the [Vulkan
1.3](https://registry.khronos.org/vulkan/specs/1.3/html/vkspec.html){biblio-display="inline"
} spec for more details of how line these line
rasterization algorithms may be implemented.

##### 23.2.5.3. Barycentric coordinates

Barycentric coordinates is a list of `n` numbers
`b`~`i`~, defined for a point `p`
inside a convex polygon with `n` vertices
`v`~`i`~ in
[framebuffer](#framebuffer)
space. Each `b`~`i`~ is in range 0 to 1,
inclusive, and represents the proximity to vertex
`v`~`i`~. Their sum is always constant:

∑ (`b`~`i`~) = 1

These coordinates uniquely specify any point `p` within the
polygon (or on its boundary) as:

`p` = ∑ (`b`~`i`~ ×
`p`~`i`~)

For a polygon with 3 vertices - a triangle, barycentric coordinates of
any point `p` can be computed as follows:

`A`~polygon~ = A(`v`~`1`~,
`v`~`2`~, `v`~`3`~)
`b`~`1`~ = A(`p`,
`b`~`2`~, `b`~`3`~) ÷
`A`~polygon~ `b`~`2`~ =
A(`b`~`1`~, `p`,
`b`~`3`~) ÷ `A`~polygon~
`b`~`3`~ = A(`b`~`1`~,
`b`~`2`~, `p`) ÷
`A`~polygon~

Where A(list of points) is the area of the polygon with the given set of
vertices.

For polygons with more than 3 vertices, the exact algorithm is
implementation-dependent. One of the possible implementations is to
triangulate the polygon and compute the barycentrics of a point based on
the triangle it falls into.

##### 23.2.5.4. Polygon Rasterization

A polygon is [front-facing] if it's oriented towards the projection.
Otherwise, the polygon is [back-facing].

[rasterize polygon]()

**Arguments:**

**Returns:** list of
[RasterizationPoint](#rasterizationpoint).

1. Let `rasterizationPoints` be an empty list.

2. Let `v`(`i`) be the
 [framebuffer](#framebuffer)
 coordinates for the clipped vertex number `i` (starting
 with 1) in a rasterized polygon of `n` vertices.

 this section uses the term \"polygon\" instead of a
 \"triangle\", since [§ 23.2.4 Primitive
 Clipping](#primitive-clipping) stage may have introduced additional
 vertices. This is non-observable by the application.

3. Determine if the polygon is front-facing, which depends on the sign
 of the `area` occupied by the polygon in
 [framebuffer](#framebuffer)
 coordinates:

 `area` = 0.5 × ((`v`~1~.x ×
 `v`~`n`~.y − `v`~`n`~.x
 × `v`~1~.y) + ∑ (`v`~`i`+1~.x ×
 `v`~`i`~.y − `v`~`i`~.x
 × `v`~`i`+1~.y))

 The sign of `area` is interpreted based on the
 [`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`frontFace`](#dom-gpuprimitivestate-frontface):

 [`"ccw"`](#dom-gpufrontface-ccw)

 : `area` \> 0 is considered
 [front-facing](#front-facing), otherwise
 [back-facing](#back-facing)

 [`"cw"`](#dom-gpufrontface-cw)

 : `area` \< 0 is considered
 [front-facing](#front-facing), otherwise
 [back-facing](#back-facing)

4. Cull based on
 [`primitive`](#dom-gpurenderpipelinedescriptor-primitive).[`cullMode`](#dom-gpuprimitivestate-cullmode):

 [`"none"`](#dom-gpucullmode-none)

 : All polygons pass this test.

 [`"front"`](#dom-gpucullmode-front)

 : The [front-facing](#front-facing) polygons are discarded, and do not process in
 later stages of the render pipeline.

 [`"back"`](#dom-gpucullmode-back)

 : The [back-facing](#back-facing) polygons are discarded.

5. Determine a set of [fragments](#fragment) inside the polygon in
 [framebuffer](#framebuffer)
 space - these are locations scheduled for the per-fragment
 operations. This operation is known as \"point sampling\". The logic
 is based on
 `descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample):

 disabled

 : [Fragment](#fragment)s are
 associated with pixel centers. That is, all the points with
 coordinates `C`, where fract(`C`) =
 vector2(0.5, 0.5) in the
 [framebuffer](#framebuffer) space, enclosed into the polygon, are included.
 If a pixel center is on the edge of the polygon, whether or not
 it's included is not defined.

 this becomes a subject of precision for the
 rasterizer.

 enabled

 : Each pixel is associated with
 `descriptor`.[`multisample`](#dom-gpurenderpipelinedescriptor-multisample).[`count`](#dom-gpumultisamplestate-count) locations, which are
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). The locations are ordered, and the list is the
 same for each pixel of the
 [framebuffer](#framebuffer). Each location corresponds to one fragment in
 the multisampled
 [framebuffer](#framebuffer).

 The rasterizer builds a mask of locations being hit inside each
 pixel and provides is as \"sample-mask\" built-in to the
 fragment shader.

6. For each produced fragment of type
 [FragmentDestination](#fragmentdestination):

 1. Let `rp` be a new
 [RasterizationPoint](#rasterizationpoint) object

 2. Compute the list `b` as [§ 23.2.5.3 Barycentric
 coordinates](#barycentric-coordinates) of that fragment. Set
 `rp`.[barycentricCoordinates](#rasterizationpoint-barycentriccoordinates) to `b`.

 3. Let `d`~`i`~ be the depth value of
 `v`~`i`~.

 4. Set
 `rp`.[depth](#rasterizationpoint-depth) to ∑ (`b`~`i`~ ×
 `d`~`i`~)

 5. Append `rp` to `rasterizationPoints`.

7. Return `rasterizationPoints`.

#### 23.2.6. Fragment Processing

The fragment processing stage is a programmable stage of the render
[pipeline](#pipeline) that computes
the fragment data (often a color) to be written into render targets.

This stage produces a [Fragment] for each
[RasterizationPoint](#rasterizationpoint):

- [destination] refers to
 [FragmentDestination](#fragmentdestination).

- [frontFacing] is true if it's a
 fragment on the front face of a primitive.

- [coverageMask] refers to multisample
 coverage mask (see [§ 23.2.11 Sample Masking](#sample-masking)).

- [depth] refers to the depth in [viewport
 coordinates](#viewport-coordinates), i.e. between the
 [`[[viewport]]`](#dom-renderstate-viewport-slot) `minDepth` and `maxDepth`.

- [colors] refers to the list of color values, one
 for each target in
 [`colorAttachments`](#dom-gpurenderpassdescriptor-colorattachments).

- [depthPassed] is `true` if the
 fragment passed the
 [`depthCompare`](#dom-gpudepthstencilstate-depthcompare) operation.

- [stencilPassed] is `true` if the
 fragment passed the stencil
 [`compare`](#dom-gpustencilfacestate-compare) operation.

[process fragment](rp, descriptor, state)

**Arguments:**

- `rp`: The
 [RasterizationPoint](#rasterizationpoint), produced by [§ 23.2.5
 Rasterization](#rasterization).

- `descriptor`: The descriptor of type
 [`GPURenderPipelineDescriptor`](#dictdef-gpurenderpipelinedescriptor).

- `state`: The active
 [RenderState](#renderstate).

**Returns:** [Fragment](#fragment)
or `null`.

1. Let `fragmentDesc` be
 `descriptor`.[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).

2. Let `depthStencilDesc` be
 `descriptor`.[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).

3. Let `fragment` be a new
 [Fragment](#fragment) object.

4. Set
 `fragment`.[destination](#fragment-destination) to
 `rp`.[destination](#rasterizationpoint-destination).

5. Set
 `fragment`.[frontFacing](#fragment-frontfacing) to
 `rp`.[frontFacing](#rasterizationpoint-frontfacing).

6. Set
 `fragment`.[coverageMask](#fragment-coveragemask) to
 `rp`.[coverageMask](#rasterizationpoint-coveragemask).

7. Set
 `fragment`.[depth](#fragment-depth) to
 `rp`.[depth](#rasterizationpoint-depth).

8. If `frag_depth`
 [builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) is not produced by the shader:

 1. Set
 `fragment`.[depthPassed](#fragment-depthpassed) to the result of [compare
 fragment](#abstract-opdef-compare-fragment)(`fragment`.[destination](#fragment-destination),
 `fragment`.[depth](#fragment-depth),
 \"[depth](#aspect-depth)\",
 `state`.[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot),
 `depthStencilDesc`?.[`depthCompare`](#dom-gpudepthstencilstate-depthcompare)).

9. Set `stencilState` to
 `depthStencilDesc`?.[`stencilFront`](#dom-gpudepthstencilstate-stencilfront) if
 `rp`.[frontFacing](#rasterizationpoint-frontfacing) is `true` and
 `depthStencilDesc`?.[`stencilBack`](#dom-gpudepthstencilstate-stencilback) otherwise.

10. Set
 `fragment`.[stencilPassed](#fragment-stencilpassed) to the result of [compare
 fragment](#abstract-opdef-compare-fragment)(`fragment`.[destination](#fragment-destination),
 `state`.[`[[stencilReference]]`](#dom-renderstate-stencilreference-slot),
 \"[stencil](#aspect-stencil)\",
 `state`.[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot),
 `stencilState`?.[`compare`](#dom-gpustencilfacestate-compare)).

11. If `fragmentDesc` is not `null`:

 1. If
 `fragment`.[depthPassed](#fragment-depthpassed) is `false`, the `frag_depth`
 [builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) is not produced by the shader entry point, and
 the shader entry point does not write to any
 [storage](#internal-usage-storage) bindings, the following steps may be skipped.

 2. Set the shader input
 [builtins](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values). For each non-composite argument of the entry
 point, annotated as a
 [builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values), set its value based on the annotation:

 `position`

 : `vec4<f32>`(`rp`.[destination](#rasterizationpoint-destination).[position](#fragmentdestination-position),
 `rp`.[depth](#rasterizationpoint-depth),
 `rp`.[perspectiveDivisor](#rasterizationpoint-perspectivedivisor))

 `front_facing`

 : `rp`.[frontFacing](#rasterizationpoint-frontfacing)

 `sample_index`

 : `rp`.[destination](#rasterizationpoint-destination).[sampleIndex](#fragmentdestination-sampleindex)

 `sample_mask`

 : `rp`.[coverageMask](#rasterizationpoint-coveragemask)

 3. For each user-specified [shader stage
 input](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-input) of the fragment stage:

 1. Let `value` be the interpolated fragment input,
 based on
 `rp`.[barycentricCoordinates](#rasterizationpoint-barycentriccoordinates),
 `rp`.[primitiveVertices](#rasterizationpoint-primitivevertices), and the
 [interpolation](https://gpuweb.github.io/gpuweb/wgsl/#interpolation) qualifier on the input.

 2. Set the corresponding fragment shader
 [location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) input to `value`.

 4. Invoke the fragment shader entry point described by
 `fragmentDesc`.

 The [device](#device) may
 become [lost](#lose-the-device) if [shader execution does not
 end](https://gpuweb.github.io/gpuweb/wgsl/#shader-execution-end) in a reasonable amount of time, as determined
 by the user agent.

 5. If the fragment issued `discard`, return `null`.

 6. Set
 `fragment`.[colors](#fragment-colors) to the user-specified [shader stage
 output](https://gpuweb.github.io/gpuweb/wgsl/#shader-stage-output) values from the shader.

 7. Take the shader output
 [builtins](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values):

 1. If `frag_depth`
 [builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) is produced by the shader as
 `value`:

 1. Let `vp` be
 `state`.[`[[viewport]]`](#dom-renderstate-viewport-slot).

 2. Set
 `fragment`.[depth](#fragment-depth) to clamp(`value`,
 `vp`.`minDepth`, `vp`.`maxDepth`).

 3. Set
 `fragment`.[depthPassed](#fragment-depthpassed) to the result of [compare
 fragment](#abstract-opdef-compare-fragment)(`fragment`.[destination](#fragment-destination),
 `fragment`.[depth](#fragment-depth),
 \"[depth](#aspect-depth)\",
 `state`.[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot),
 `depthStencilDesc`?.[`depthCompare`](#dom-gpudepthstencilstate-depthcompare)).

 8. If `sample_mask`
 [builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) is produced by the shader as
 `value`:

 1. Set
 `fragment`.[coverageMask](#fragment-coveragemask) to
 `fragment`.[coverageMask](#fragment-coveragemask) ∧ `value`.

 Otherwise we are in [§ 23.2.8 No Color Output](#no-color-output)
 mode, and
 `fragment`.[colors](#fragment-colors) is empty.

12. Return `fragment`.

[compare fragment](destination, value, aspect,
attachment, compareFunc)

**Arguments:**

- `destination`: The
 [FragmentDestination](#fragmentdestination).

- `value`: The value to be compared.

- `aspect`: The [aspect](#aspect) of `attachment` to sample values from.

- `attachment`: The attachment to be compared against.

- `compareFunc`: The
 [`GPUCompareFunction`](#enumdef-gpucomparefunction) to use, or `undefined`.

**Returns:** `true` if the comparison passes, or `false` otherwise

- If `attachment` is `undefined` or does not have
 `aspect`, return `true`.

- If `compareFunc` is `undefined` or
 [`"always"`](#dom-gpucomparefunction-always), return `true`.

- Let `attachmentValue` be the value of `aspect`
 of `attachment` at `destination`.

- Return `true` if comparing `value` with
 `attachmentValue` using `compareFunc` succeeds,
 and `false` otherwise.

Processing of fragments happens in parallel, while any side effects,
such as writes into
[`GPUBufferBindingType`](#enumdef-gpubufferbindingtype)
[`"storage"`](#dom-gpubufferbindingtype-storage) bindings, may happen in any order.

#### 23.2.7. Output Merging

Output merging is a fixed-function stage of the render
[pipeline](#pipeline) that outputs
the fragment color, depth and stencil data to be written into the render
pass attachments.

[process depth stencil](fragment, pipeline,
state)

**Arguments:**

- `fragment`: The [Fragment](#fragment), produced by [§ 23.2.6 Fragment
 Processing](#fragment-processing).

- `pipeline`: The current
 [`GPURenderPipeline`](#gpurenderpipeline).

- `state`: The active
 [RenderState](#renderstate).

1. Let `depthStencilDesc` be
 `pipeline`.[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).[`depthStencil`](#dom-gpurenderpipelinedescriptor-depthstencil).

2. If
 `pipeline`.[`[[writesDepth]]`](#dom-gpurenderpipeline-writesdepth-slot) is `true` and
 `fragment`.[depthPassed](#fragment-depthpassed) is `true`:

 1. Set the value of the depth aspect of
 `state`.[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot) at
 `fragment`.[destination](#fragment-destination) to
 `fragment`.[depth](#fragment-depth).

3. If
 `pipeline`.[`[[writesStencil]]`](#dom-gpurenderpipeline-writesstencil-slot) is true:

 1. Set `stencilState` to
 `depthStencilDesc`.[`stencilFront`](#dom-gpudepthstencilstate-stencilfront) if
 `fragment`.[frontFacing](#fragment-frontfacing) is `true` and
 `depthStencilDesc`.[`stencilBack`](#dom-gpudepthstencilstate-stencilback) otherwise.

 2. If
 `fragment`.[stencilPassed](#fragment-stencilpassed) is `false`:

 - Let `stencilOp` be
 `stencilState`.[`failOp`](#dom-gpustencilfacestate-failop).

 Otherwise, if
 `fragment`.[depthPassed](#fragment-depthpassed) is `false`:

 - Let `stencilOp` be
 `stencilState`.[`depthFailOp`](#dom-gpustencilfacestate-depthfailop).

 Otherwise:

 - Let `stencilOp` be
 `stencilState`.[`passOp`](#dom-gpustencilfacestate-passop).

 3. Update the value of the stencil aspect of
 `state`.[`[[depthStencilAttachment]]`](#dom-renderstate-depthstencilattachment-slot) at
 `fragment`.[destination](#fragment-destination) by performing the operation described by
 `stencilOp`.

The depth input to this stage, if any, is clamped to the current
[`[[viewport]]`](#dom-renderstate-viewport-slot) depth range (regardless of whether the fragment shader
stage writes the `frag_depth` builtin).

[process color attachments](fragment, pipeline,
state)

**Arguments:**

- `fragment`: The [Fragment](#fragment), produced by [§ 23.2.6 Fragment
 Processing](#fragment-processing).

- `pipeline`: The current
 [`GPURenderPipeline`](#gpurenderpipeline).

- `state`: The active
 [RenderState](#renderstate).

1. If
 `fragment`.[depthPassed](#fragment-depthpassed) is `false` or
 `fragment`.[stencilPassed](#fragment-stencilpassed) is `false`, return.

2. Let `targets` be
 `pipeline`.[`[[descriptor]]`](#dom-gpurenderpipeline-descriptor-slot).[`fragment`](#dom-gpurenderpipelinedescriptor-fragment).[`targets`](#dom-gpufragmentstate-targets).

3. For each `attachment` of
 `state`.[`[[colorAttachments]]`](#dom-renderstate-colorattachments-slot):

 1. Let `color` be the value from
 `fragment`.[colors](#fragment-colors) that corresponds with `attachment`.

 2. Let `targetDesc` be the `targets` entry
 that corresponds with `attachment`.

 3. If
 `targetDesc`.[`blend`](#dom-gpucolortargetstate-blend) is
 [provided](https://infra.spec.whatwg.org/#map-exists):

 1. Let `colorBlend` be
 `targetDesc`.[`blend`](#dom-gpucolortargetstate-blend).[`color`](#dom-gpublendstate-color).

 2. Let `alphaBlend` be
 `targetDesc`.[`blend`](#dom-gpucolortargetstate-blend).[`alpha`](#dom-gpublendstate-alpha).

 3. Set the RGB components of `color` to the value
 computed by performing the operation described by
 `colorBlend`.[`operation`](#dom-gpublendcomponent-operation) with the values described by
 `colorBlend`.[`srcFactor`](#dom-gpublendcomponent-srcfactor) and
 `colorBlend`.[`dstFactor`](#dom-gpublendcomponent-dstfactor).

 4. Set the alpha component of `color` to the value
 computed by performing the operation described by
 `alphaBlend`.[`operation`](#dom-gpublendcomponent-operation) with the values described by
 `alphaBlend`.[`srcFactor`](#dom-gpublendcomponent-srcfactor) and
 `alphaBlend`.[`dstFactor`](#dom-gpublendcomponent-dstfactor).

 4. Set the value of `attachment` at
 `fragment`.[destination](#fragment-destination) to `color`.

#### 23.2.8. No Color Output

In no-color-output mode, [pipeline](#pipeline) does not produce any color attachment outputs.

The [pipeline](#pipeline) still
performs rasterization and produces depth values based on the vertex
position output. The depth testing and stencil operations can still be
used.

#### 23.2.9. Alpha to Coverage

In alpha-to-coverage mode, an additional [alpha-to-coverage
mask] of MSAA samples is generated based on the
`alpha` component of the fragment shader output value at
`@location(0)`.

The algorithm of producing the extra mask is platform-dependent and can
vary for different pixels. It guarantees that:

- if `alpha` ≤ 0.0, the result is 0x0

- if `alpha` ≥ 1.0, the result is 0xFFFFFFFF

- intermediate `alpha` values should result in a
 proportionate number of bits set to 1 in the mask. Not all platforms
 guarantee that the number of bits set to 1 in the mask monotonically
 increases as alpha increases for a given pixel.

#### 23.2.10. Per-Sample Shading

When rendering into multisampled render attachments, fragment shaders
can be run once per-pixel or once per-sample. Fragment shaders **must**
run once per-sample if either the `sample_index`
[builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) or `sample` [interpolation
sampling](https://gpuweb.github.io/gpuweb/wgsl/#interpolation-sampling) is used and contributes to the shader output. Otherwise
fragment shaders **may** run once per-pixel with the result broadcast
out to each of the samples included in the [final sample
mask](#final-sample-mask).

When using per-sample shading, the color output for sample
`N` is produced by the fragment shader execution with
`sample_index` == `N` for the current pixel.

#### 23.2.11. Sample Masking

The [final sample mask] for a pixel is computed as: [rasterization
mask](#rasterization-mask)
&
[`mask`](#dom-gpumultisamplestate-mask) & [shader-output
mask](#shader-output-mask).

Only the lower
[`count`](#dom-gpumultisamplestate-count) bits of the mask are considered.

If the least-significant bit at position `N` of the [final
sample mask](#final-sample-mask) has value of \"0\", the sample color outputs
(corresponding to sample `N`) to all attachments of the
fragment shader are discarded. Also, no depth test or stencil operations
are executed on the relevant samples of the depth-stencil attachment.

The [rasterization mask] is produced by the rasterization stage,
based on the shape of the rasterized polygon. The samples included in
the shape get the relevant bits 1 in the mask.

The [shader-output mask] takes the output value of \"sample_mask\"
[builtin](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values) in the fragment shader. If the builtin is not output
from the fragment shader, and
[`alphaToCoverageEnabled`](#dom-gpumultisamplestate-alphatocoverageenabled) is enabled, the [shader-output
mask](#shader-output-mask)
becomes the [alpha-to-coverage
mask](#alpha-to-coverage-mask). Otherwise, it defaults to 0xFFFFFFFF.

## 24. Type Definitions

```
typedef [EnforceRange] unsigned long GPUBufferDynamicOffset;
typedef [EnforceRange] unsigned long GPUStencilValue;
typedef [EnforceRange] unsigned long GPUSampleMask;
typedef [EnforceRange] long GPUDepthBias;

typedef [EnforceRange] unsigned long long GPUSize64;
typedef [EnforceRange] unsigned long GPUIntegerCoordinate;
typedef [EnforceRange] unsigned long GPUIndex32;
typedef [EnforceRange] unsigned long GPUSize32;
typedef [EnforceRange] long GPUSignedOffset32;

typedef unsigned long long GPUSize64Out;
typedef unsigned long GPUIntegerCoordinateOut;
typedef unsigned long GPUSize32Out;

typedef unsigned long GPUFlagsConstant;
```

### 24.1. Colors & Vectors

```
dictionary GPUColorDict {
 required double r;
 required double g;
 required double b;
 required double a;
};
typedef (sequence<double> or GPUColorDict) GPUColor;
```

 `double` is large enough to precisely hold 32-bit
signed/unsigned integers and single-precision floats.

[`r`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: The red channel value.

[`g`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: The green channel value.

[`b`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: The blue channel value.

[`a`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: The alpha channel value.

For a given
[`GPUColor`](#typedefdef-gpucolor) value `color`, depending on its type, the
syntax:

- `color`.[r] refers to either
 [`GPUColorDict`](#dictdef-gpucolordict).[`r`](#dom-gpucolordict-r) or the first item of the sequence
 ([asserting](https://infra.spec.whatwg.org/#assert) there is such an item).

- `color`.[g] refers to either
 [`GPUColorDict`](#dictdef-gpucolordict).[`g`](#dom-gpucolordict-g) or the second item of the sequence
 ([asserting](https://infra.spec.whatwg.org/#assert) there is such an item).

- `color`.[b] refers to either
 [`GPUColorDict`](#dictdef-gpucolordict).[`b`](#dom-gpucolordict-b) or the third item of the sequence
 ([asserting](https://infra.spec.whatwg.org/#assert) there is such an item).

- `color`.[a] refers to either
 [`GPUColorDict`](#dictdef-gpucolordict).[`a`](#dom-gpucolordict-a) or the fourth item of the sequence
 ([asserting](https://infra.spec.whatwg.org/#assert) there is such an item).

[validate GPUColor shape](color)

**Arguments:**

- `color`: The
 [`GPUColor`](#typedefdef-gpucolor) to validate.

**Returns:**
[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

[Content timeline](#content-timeline) steps:

1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) if `color` is a sequence and
 `color`.[size](https://infra.spec.whatwg.org/#list-size) ≠ 4.

```
dictionary GPUOrigin2DDict {
 GPUIntegerCoordinate x = 0;
 GPUIntegerCoordinate y = 0;
};
typedef (sequence<GPUIntegerCoordinate> or GPUOrigin2DDict) GPUOrigin2D;
```

For a given
[`GPUOrigin2D`](#typedefdef-gpuorigin2d) value `origin`, depending on its type, the
syntax:

- `origin`.[x] refers to either
 [`GPUOrigin2DDict`](#dictdef-gpuorigin2ddict).[`x`](#dom-gpuorigin2ddict-x) or the first item of the sequence (0 if not present).

- `origin`.[y] refers to either
 [`GPUOrigin2DDict`](#dictdef-gpuorigin2ddict).[`y`](#dom-gpuorigin2ddict-y) or the second item of the sequence (0 if not
 present).

[validate GPUOrigin2D shape](origin)

**Arguments:**

- `origin`: The
 [`GPUOrigin2D`](#typedefdef-gpuorigin2d) to validate.

**Returns:**
[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

[Content timeline](#content-timeline) steps:

1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) if `origin` is a sequence and
 `origin`.[size](https://infra.spec.whatwg.org/#list-size) \> 2.

```
dictionary GPUOrigin3DDict {
 GPUIntegerCoordinate x = 0;
 GPUIntegerCoordinate y = 0;
 GPUIntegerCoordinate z = 0;
};
typedef (sequence<GPUIntegerCoordinate> or GPUOrigin3DDict) GPUOrigin3D;
```

For a given
[`GPUOrigin3D`](#typedefdef-gpuorigin3d) value `origin`, depending on its type, the
syntax:

- `origin`.[x] refers to either
 [`GPUOrigin3DDict`](#dictdef-gpuorigin3ddict).[`x`](#dom-gpuorigin3ddict-x) or the first item of the sequence (0 if not present).

- `origin`.[y] refers to either
 [`GPUOrigin3DDict`](#dictdef-gpuorigin3ddict).[`y`](#dom-gpuorigin3ddict-y) or the second item of the sequence (0 if not
 present).

- `origin`.[z] refers to either
 [`GPUOrigin3DDict`](#dictdef-gpuorigin3ddict).[`z`](#dom-gpuorigin3ddict-z) or the third item of the sequence (0 if not present).

[validate GPUOrigin3D shape](origin)

**Arguments:**

- `origin`: The
 [`GPUOrigin3D`](#typedefdef-gpuorigin3d) to validate.

**Returns:**
[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

[Content timeline](#content-timeline) steps:

1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) if `origin` is a sequence and
 `origin`.[size](https://infra.spec.whatwg.org/#list-size) \> 3.

```
dictionary GPUExtent3DDict {
 required GPUIntegerCoordinate width;
 GPUIntegerCoordinate height = 1;
 GPUIntegerCoordinate depthOrArrayLayers = 1;
};
typedef (sequence<GPUIntegerCoordinate> or GPUExtent3DDict) GPUExtent3D;
```

[`width`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate)

: The width of the extent.

[`height`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate), defaulting to `1`

: The height of the extent.

[`depthOrArrayLayers`], of type [GPUIntegerCoordinate](#typedefdef-gpuintegercoordinate), defaulting to `1`

: The depth of the extent or the number of array layers it contains.
 If used with a
 [`GPUTexture`](#gputexture) with a
 [`GPUTextureDimension`](#enumdef-gputexturedimension) of
 [`"3d"`](#dom-gputexturedimension-3d) defines the depth of the texture. If used with a
 [`GPUTexture`](#gputexture) with a
 [`GPUTextureDimension`](#enumdef-gputexturedimension) of
 [`"2d"`](#dom-gputexturedimension-2d) defines the number of array layers in the texture.

For a given
[`GPUExtent3D`](#typedefdef-gpuextent3d) value `extent`, depending on its type, the
syntax:

- `extent`.[width] refers to either
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict).[`width`](#dom-gpuextent3ddict-width) or the first item of the sequence
 ([asserting](https://infra.spec.whatwg.org/#assert) there is such an item).

- `extent`.[height] refers to either
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict).[`height`](#dom-gpuextent3ddict-height) or the second item of the sequence (1 if not
 present).

- `extent`.[depthOrArrayLayers]
 refers to either
 [`GPUExtent3DDict`](#dictdef-gpuextent3ddict).[`depthOrArrayLayers`](#dom-gpuextent3ddict-depthorarraylayers) or the third item of the sequence (1 if not present).

[validate GPUExtent3D shape](extent)

**Arguments:**

- `extent`: The
 [`GPUExtent3D`](#typedefdef-gpuextent3d) to validate.

**Returns:**
[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)

[Content timeline](#content-timeline) steps:

1. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) if:

- `extent` is a sequence, and

- `extent`.[size](https://infra.spec.whatwg.org/#list-size) \< 1 or
 `extent`.[size](https://infra.spec.whatwg.org/#list-size) \> 3.

## 25. Feature Index

### 25.1. `"core-features-and-limits"`

Allows all Core WebGPU features and limits to be used.

This is always available unless
[`featureLevel`](#dom-gpurequestadapteroptions-featurelevel) is set to
[\"compatibility\"](#feature-level-string-compatibility), in which case it may or may not be available (see
those definitions for information).

### 25.2. `"depth-clip-control"`

Allows [depth clipping](#depth-clipping) to be disabled.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUPrimitiveState`](#dictdef-gpuprimitivestate) dictionary members:

 - [`unclippedDepth`](#dom-gpuprimitivestate-unclippeddepth)

### 25.3. `"depth32float-stencil8"`

Allows for explicit creation of textures of format
[`"depth32float-stencil8"`](#dom-gputextureformat-depth32float-stencil8).

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUTextureFormat`](#enumdef-gputextureformat) enum values:

 - [`"depth32float-stencil8"`](#dom-gputextureformat-depth32float-stencil8)

### 25.4. `"texture-compression-bc"`

Allows for explicit creation of textures of [BC compressed
formats](https://registry.khronos.org/DataFormat/specs/1.3/dataformat.1.3.html#_compressed_texture_image_formats) which include the \"S3TC\", \"RGTC\", and \"BPTC\"
formats. Only supports 2D textures.

 Adapters which support
[`"texture-compression-bc"`](#texture-compression-bc) do not always support
[`"texture-compression-bc-sliced-3d"`](#texture-compression-bc-sliced-3d). To use
[`"texture-compression-bc-sliced-3d"`](#texture-compression-bc-sliced-3d),
[`"texture-compression-bc"`](#texture-compression-bc) must be enabled explicitly as this feature does not
enable the BC formats.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUTextureFormat`](#enumdef-gputextureformat) enum values:

 - [`"bc1-rgba-unorm"`](#dom-gputextureformat-bc1-rgba-unorm)

 - [`"bc1-rgba-unorm-srgb"`](#dom-gputextureformat-bc1-rgba-unorm-srgb)

 - [`"bc2-rgba-unorm"`](#dom-gputextureformat-bc2-rgba-unorm)

 - [`"bc2-rgba-unorm-srgb"`](#dom-gputextureformat-bc2-rgba-unorm-srgb)

 - [`"bc3-rgba-unorm"`](#dom-gputextureformat-bc3-rgba-unorm)

 - [`"bc3-rgba-unorm-srgb"`](#dom-gputextureformat-bc3-rgba-unorm-srgb)

 - [`"bc4-r-unorm"`](#dom-gputextureformat-bc4-r-unorm)

 - [`"bc4-r-snorm"`](#dom-gputextureformat-bc4-r-snorm)

 - [`"bc5-rg-unorm"`](#dom-gputextureformat-bc5-rg-unorm)

 - [`"bc5-rg-snorm"`](#dom-gputextureformat-bc5-rg-snorm)

 - [`"bc6h-rgb-ufloat"`](#dom-gputextureformat-bc6h-rgb-ufloat)

 - [`"bc6h-rgb-float"`](#dom-gputextureformat-bc6h-rgb-float)

 - [`"bc7-rgba-unorm"`](#dom-gputextureformat-bc7-rgba-unorm)

 - [`"bc7-rgba-unorm-srgb"`](#dom-gputextureformat-bc7-rgba-unorm-srgb)

### 25.5. `"texture-compression-bc-sliced-3d"`

Allows the
[`3d`](#dom-gputexturedimension-3d) dimension for textures with [BC compressed
formats](https://registry.khronos.org/DataFormat/specs/1.3/dataformat.1.3.html#_compressed_texture_image_formats).

 Adapters which support
[`"texture-compression-bc"`](#texture-compression-bc) do not always support
[`"texture-compression-bc-sliced-3d"`](#texture-compression-bc-sliced-3d). To use
[`"texture-compression-bc-sliced-3d"`](#texture-compression-bc-sliced-3d),
[`"texture-compression-bc"`](#texture-compression-bc) must be enabled explicitly as this feature does not
enable the BC formats.

This feature adds no [optional API
surfaces](#optional-api-surface).

### 25.6. `"texture-compression-etc2"`

Allows for explicit creation of textures of [ETC2 compressed
formats](https://registry.khronos.org/DataFormat/specs/1.3/dataformat.1.3.html#ETC2). Only supports 2D textures.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUTextureFormat`](#enumdef-gputextureformat) enum values:

 - [`"etc2-rgb8unorm"`](#dom-gputextureformat-etc2-rgb8unorm)

 - [`"etc2-rgb8unorm-srgb"`](#dom-gputextureformat-etc2-rgb8unorm-srgb)

 - [`"etc2-rgb8a1unorm"`](#dom-gputextureformat-etc2-rgb8a1unorm)

 - [`"etc2-rgb8a1unorm-srgb"`](#dom-gputextureformat-etc2-rgb8a1unorm-srgb)

 - [`"etc2-rgba8unorm"`](#dom-gputextureformat-etc2-rgba8unorm)

 - [`"etc2-rgba8unorm-srgb"`](#dom-gputextureformat-etc2-rgba8unorm-srgb)

 - [`"eac-r11unorm"`](#dom-gputextureformat-eac-r11unorm)

 - [`"eac-r11snorm"`](#dom-gputextureformat-eac-r11snorm)

 - [`"eac-rg11unorm"`](#dom-gputextureformat-eac-rg11unorm)

 - [`"eac-rg11snorm"`](#dom-gputextureformat-eac-rg11snorm)

### 25.7. `"texture-compression-astc"`

Allows for explicit creation of textures of [ASTC compressed
formats](https://registry.khronos.org/DataFormat/specs/1.3/dataformat.1.3.html#ASTC). Only supports 2D textures.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUTextureFormat`](#enumdef-gputextureformat) enum values:

 - [`"astc-4x4-unorm"`](#dom-gputextureformat-astc-4x4-unorm)

 - [`"astc-4x4-unorm-srgb"`](#dom-gputextureformat-astc-4x4-unorm-srgb)

 - [`"astc-5x4-unorm"`](#dom-gputextureformat-astc-5x4-unorm)

 - [`"astc-5x4-unorm-srgb"`](#dom-gputextureformat-astc-5x4-unorm-srgb)

 - [`"astc-5x5-unorm"`](#dom-gputextureformat-astc-5x5-unorm)

 - [`"astc-5x5-unorm-srgb"`](#dom-gputextureformat-astc-5x5-unorm-srgb)

 - [`"astc-6x5-unorm"`](#dom-gputextureformat-astc-6x5-unorm)

 - [`"astc-6x5-unorm-srgb"`](#dom-gputextureformat-astc-6x5-unorm-srgb)

 - [`"astc-6x6-unorm"`](#dom-gputextureformat-astc-6x6-unorm)

 - [`"astc-6x6-unorm-srgb"`](#dom-gputextureformat-astc-6x6-unorm-srgb)

 - [`"astc-8x5-unorm"`](#dom-gputextureformat-astc-8x5-unorm)

 - [`"astc-8x5-unorm-srgb"`](#dom-gputextureformat-astc-8x5-unorm-srgb)

 - [`"astc-8x6-unorm"`](#dom-gputextureformat-astc-8x6-unorm)

 - [`"astc-8x6-unorm-srgb"`](#dom-gputextureformat-astc-8x6-unorm-srgb)

 - [`"astc-8x8-unorm"`](#dom-gputextureformat-astc-8x8-unorm)

 - [`"astc-8x8-unorm-srgb"`](#dom-gputextureformat-astc-8x8-unorm-srgb)

 - [`"astc-10x5-unorm"`](#dom-gputextureformat-astc-10x5-unorm)

 - [`"astc-10x5-unorm-srgb"`](#dom-gputextureformat-astc-10x5-unorm-srgb)

 - [`"astc-10x6-unorm"`](#dom-gputextureformat-astc-10x6-unorm)

 - [`"astc-10x6-unorm-srgb"`](#dom-gputextureformat-astc-10x6-unorm-srgb)

 - [`"astc-10x8-unorm"`](#dom-gputextureformat-astc-10x8-unorm)

 - [`"astc-10x8-unorm-srgb"`](#dom-gputextureformat-astc-10x8-unorm-srgb)

 - [`"astc-10x10-unorm"`](#dom-gputextureformat-astc-10x10-unorm)

 - [`"astc-10x10-unorm-srgb"`](#dom-gputextureformat-astc-10x10-unorm-srgb)

 - [`"astc-12x10-unorm"`](#dom-gputextureformat-astc-12x10-unorm)

 - [`"astc-12x10-unorm-srgb"`](#dom-gputextureformat-astc-12x10-unorm-srgb)

 - [`"astc-12x12-unorm"`](#dom-gputextureformat-astc-12x12-unorm)

 - [`"astc-12x12-unorm-srgb"`](#dom-gputextureformat-astc-12x12-unorm-srgb)

### 25.8. `"texture-compression-astc-sliced-3d"`

Allows the
[`3d`](#dom-gputexturedimension-3d) dimension for textures with [ASTC compressed
formats](https://registry.khronos.org/DataFormat/specs/1.3/dataformat.1.3.html#ASTC).

 Adapters which support
[`"texture-compression-astc"`](#texture-compression-astc) do not always support
[`"texture-compression-astc-sliced-3d"`](#texture-compression-astc-sliced-3d). To use
[`"texture-compression-astc-sliced-3d"`](#texture-compression-astc-sliced-3d),
[`"texture-compression-astc"`](#texture-compression-astc) must be enabled explicitly as this feature does not
enable the ASTC formats.

This feature adds no [optional API
surfaces](#optional-api-surface).

### 25.9. `"timestamp-query"`

Adds the ability to query timestamps from GPU command buffers. See
[§ 20.4 Timestamp Query](#timestamp).

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUQueryType`](#enumdef-gpuquerytype) values:

 - [`"timestamp"`](#dom-gpuquerytype-timestamp)

- New
 [`GPUComputePassDescriptor`](#dictdef-gpucomputepassdescriptor) members:

 - [`timestampWrites`](#dom-gpucomputepassdescriptor-timestampwrites)

- New
 [`GPURenderPassDescriptor`](#dictdef-gpurenderpassdescriptor) members:

 - [`timestampWrites`](#dom-gpurenderpassdescriptor-timestampwrites)

### 25.10. `"indirect-first-instance"`

Allows the use of non-zero `firstInstance` values in [indirect draw
parameters](#indirect-draw-parameters) and [indirect drawIndexed
parameters](#indirect-drawindexed-parameters).

This feature adds no [optional API
surfaces](#optional-api-surface).

### 25.11. `"shader-f16"`

Allows the use of the half-precision floating-point type
[f16](https://gpuweb.github.io/gpuweb/wgsl/#f16) in WGSL.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New WGSL extensions:

 - [f16](https://gpuweb.github.io/gpuweb/wgsl/#extension-f16)

### 25.12. `"rg11b10ufloat-renderable"`

Allows the
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) usage on textures with format
[`"rg11b10ufloat"`](#dom-gputextureformat-rg11b10ufloat), and also allows textures of that format to be blended,
multisampled, and resolved.

Implicitly allows
[`"rg11b10ufloat"`](#dom-gputextureformat-rg11b10ufloat) as a destination format in
[`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture).

This feature adds no [optional API
surfaces](#optional-api-surface).

 This feature is automatically enabled by
[`"texture-formats-tier1"`](#texture-formats-tier1), which is automatically enabled by
[`"texture-formats-tier2"`](#texture-formats-tier2).

### 25.13. `"bgra8unorm-storage"`

Allows the
[`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) usage on textures with format
[`"bgra8unorm"`](#dom-gputextureformat-bgra8unorm).

This feature adds no [optional API
surfaces](#optional-api-surface).

### 25.14. `"float32-filterable"`

Makes textures with formats
[`"r32float"`](#dom-gputextureformat-r32float),
[`"rg32float"`](#dom-gputextureformat-rg32float), and
[`"rgba32float"`](#dom-gputextureformat-rgba32float) [filterable](#filterable).

### 25.15. `"float32-blendable"`

Makes textures with formats
[`"r32float"`](#dom-gputextureformat-r32float),
[`"rg32float"`](#dom-gputextureformat-rg32float), and
[`"rgba32float"`](#dom-gputextureformat-rgba32float) [blendable](#blendable).

### 25.16. `"clip-distances"`

Allows the use of
[clip_distances](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-clip_distances) in WGSL.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New WGSL extensions:

 - [clip_distances](https://gpuweb.github.io/gpuweb/wgsl/#extension-clip_distances)

### 25.17. `"dual-source-blending"`

Allows the use of
[blend_src](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) in WGSL and simultaneously using
both pixel shader outputs (`@blend_src(0)` and `@blend_src(1)`) as
inputs to a blending operation with the single color attachment at
[location](https://gpuweb.github.io/gpuweb/wgsl/#input-output-locations) `0`.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- Allows the use of the below
 [`GPUBlendFactor`](#enumdef-gpublendfactor)s:

 - [`"src1"`](#dom-gpublendfactor-src1)

 - [`"one-minus-src1"`](#dom-gpublendfactor-one-minus-src1)

 - [`"src1-alpha"`](#dom-gpublendfactor-src1-alpha)

 - [`"one-minus-src1-alpha"`](#dom-gpublendfactor-one-minus-src1-alpha)

- New WGSL extensions:

 - [dual_source_blending](https://gpuweb.github.io/gpuweb/wgsl/#extension-dual_source_blending)

### 25.18. `"subgroups"`

Allows the use of the subgroup and quad operations in WGSL.

This feature adds no [optional API
surfaces](#optional-api-surface), but the following entries of
[`GPUAdapterInfo`](#gpuadapterinfo) expose real values whenever the feature is available on
the adapter:

- [`subgroupMinSize`](#dom-gpuadapterinfo-subgroupminsize)

- [`subgroupMaxSize`](#dom-gpuadapterinfo-subgroupmaxsize)

- New WGSL extensions:

 - [subgroups](https://gpuweb.github.io/gpuweb/wgsl/#extension-subgroups)

### 25.19. `"texture-formats-tier1"`

Enabling
[`"texture-formats-tier1"`](#texture-formats-tier1) at device creation will enable
[`"rg11b10ufloat-renderable"`](#rg11b10ufloat-renderable). The following items are in addition to that.

Supports the below new
[`GPUTextureFormat`](#enumdef-gputextureformat)s with the
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment), [blendable](#blendable), `multisampling` capabilities and the
[`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) capability with the
[`"read-only"`](#dom-gpustoragetextureaccess-read-only) and
[`"write-only"`](#dom-gpustoragetextureaccess-write-only)
[`GPUStorageTextureAccess`](#enumdef-gpustoragetextureaccess)es:

- [`"r16unorm"`](#dom-gputextureformat-r16unorm)

- [`"r16snorm"`](#dom-gputextureformat-r16snorm)

- [`"rg16unorm"`](#dom-gputextureformat-rg16unorm)

- [`"rg16snorm"`](#dom-gputextureformat-rg16snorm)

- [`"rgba16unorm"`](#dom-gputextureformat-rgba16unorm)

- [`"rgba16snorm"`](#dom-gputextureformat-rgba16snorm)

Allows the
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment), [blendable](#blendable), `multisampling` and `resolve` capabilities on below
[`GPUTextureFormat`](#enumdef-gputextureformat)s:

- [`"r8snorm"`](#dom-gputextureformat-r8snorm)

- [`"rg8snorm"`](#dom-gputextureformat-rg8snorm)

- [`"rgba8snorm"`](#dom-gputextureformat-rgba8snorm)

Allows the
[`"read-only"`](#dom-gpustoragetextureaccess-read-only) or
[`"write-only"`](#dom-gpustoragetextureaccess-write-only)
[`GPUStorageTextureAccess`](#enumdef-gpustoragetextureaccess) on below
[`GPUTextureFormat`](#enumdef-gputextureformat)s:

- [`"r8unorm"`](#dom-gputextureformat-r8unorm)

- [`"r8snorm"`](#dom-gputextureformat-r8snorm)

- [`"r8uint"`](#dom-gputextureformat-r8uint)

- [`"r8sint"`](#dom-gputextureformat-r8sint)

- [`"rg8unorm"`](#dom-gputextureformat-rg8unorm)

- [`"rg8snorm"`](#dom-gputextureformat-rg8snorm)

- [`"rg8uint"`](#dom-gputextureformat-rg8uint)

- [`"rg8sint"`](#dom-gputextureformat-rg8sint)

- [`"r16uint"`](#dom-gputextureformat-r16uint)

- [`"r16sint"`](#dom-gputextureformat-r16sint)

- [`"r16float"`](#dom-gputextureformat-r16float)

- [`"rg16uint"`](#dom-gputextureformat-rg16uint)

- [`"rg16sint"`](#dom-gputextureformat-rg16sint)

- [`"rg16float"`](#dom-gputextureformat-rg16float)

- [`"rgb10a2uint"`](#dom-gputextureformat-rgb10a2uint)

- [`"rgb10a2unorm"`](#dom-gputextureformat-rgb10a2unorm)

- [`"rg11b10ufloat"`](#dom-gputextureformat-rg11b10ufloat)

Implicitly allows the following new destination formats in
[`copyExternalImageToTexture()`](#dom-gpuqueue-copyexternalimagetotexture):

- [`"r16unorm"`](#dom-gputextureformat-r16unorm)

- [`"rg16unorm"`](#dom-gputextureformat-rg16unorm)

- [`"rgba16unorm"`](#dom-gputextureformat-rgba16unorm)

 This feature is automatically enabled by
[`"texture-formats-tier2"`](#texture-formats-tier2).

### 25.20. `"texture-formats-tier2"`

Enabling
[`"texture-formats-tier2"`](#texture-formats-tier2) at device creation will enable
[`"texture-formats-tier1"`](#texture-formats-tier1). The following items are in addition to that.

Allows the
[`"read-write"`](#dom-gpustoragetextureaccess-read-write)
[`GPUStorageTextureAccess`](#enumdef-gpustoragetextureaccess) on below
[`GPUTextureFormat`](#enumdef-gputextureformat)s:

- [`"r8unorm"`](#dom-gputextureformat-r8unorm)

- [`"r8uint"`](#dom-gputextureformat-r8uint)

- [`"r8sint"`](#dom-gputextureformat-r8sint)

- [`"rgba8unorm"`](#dom-gputextureformat-rgba8unorm)

- [`"rgba8uint"`](#dom-gputextureformat-rgba8uint)

- [`"rgba8sint"`](#dom-gputextureformat-rgba8sint)

- [`"r16uint"`](#dom-gputextureformat-r16uint)

- [`"r16sint"`](#dom-gputextureformat-r16sint)

- [`"r16float"`](#dom-gputextureformat-r16float)

- [`"rgba16uint"`](#dom-gputextureformat-rgba16uint)

- [`"rgba16sint"`](#dom-gputextureformat-rgba16sint)

- [`"rgba16float"`](#dom-gputextureformat-rgba16float)

- [`"rgba32uint"`](#dom-gputextureformat-rgba32uint)

- [`"rgba32sint"`](#dom-gputextureformat-rgba32sint)

- [`"rgba32float"`](#dom-gputextureformat-rgba32float)

### 25.21. `"primitive-index"`

Allows the use of
[primitive_index](https://gpuweb.github.io/gpuweb/wgsl/#built-in-values-primitive_index) in WGSL.

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New WGSL extensions:

 - [primitive_index](https://gpuweb.github.io/gpuweb/wgsl/#extension-primitive_index)

### 25.22. `"texture-component-swizzle"`

Allows
[`GPUTextureView`](#gputextureview)s to rearrange or replace the color components from
texture's red/green/blue/alpha channels when used as a
[`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding).

Also defines previously-implementation-defined behavior when [§ 26.1.2.1
Reading and Sampling Depth/Stencil Textures](#reading-depth-stencil).

This feature adds the following [optional API
surfaces](#optional-api-surface):

- New
 [`GPUTextureViewDescriptor`](#dictdef-gputextureviewdescriptor) dictionary members:

 - [`swizzle`](#dom-gputextureviewdescriptor-swizzle)

## 26. Appendices

### 26.1. Texture Format Capabilities

#### 26.1.1. Plain color formats

All
[supported](#abstract-opdef-validate-texture-format-required-features) plain color formats support usages
[`COPY_SRC`](#dom-gputextureusage-copy_src),
[`COPY_DST`](#dom-gputextureusage-copy_dst), and
[`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding), and dimension
[`"3d"`](#dom-gputexturedimension-3d).

The
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) and
[`STORAGE_BINDING`](#dom-gputextureusage-storage_binding) columns specify support for
[`GPUTextureUsage.RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) and
[`GPUTextureUsage.STORAGE_BINDING`](#dom-gputextureusage-storage_binding) usage respectively.

The [render target pixel byte cost] and [render target component
alignment] are used to validate the
[`maxColorAttachmentBytesPerSample`](#dom-supported-limits-maxcolorattachmentbytespersample) limit.

 The [texel block memory
cost](#texel-block-memory-cost) of each of these formats is the same as its [texel
block copy
footprint](#texel-block-copy-footprint).

Format

Required [Feature](#feature)

[`GPUTextureSampleType`](#enumdef-gputexturesampletype)

[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment)

[blendable](#blendable)

multisampling

resolve

[`STORAGE_BINDING`](#dom-gputextureusage-storage_binding)

[Texel block copy
footprint](#texel-block-copy-footprint) (Bytes)

[Render target pixel byte
cost](#render-target-pixel-byte-cost) (Bytes)

[`"write-only"`](#dom-gpustoragetextureaccess-write-only)

[`"read-only"`](#dom-gpustoragetextureaccess-read-only)

[`"read-write"`](#dom-gpustoragetextureaccess-read-write)

8 bits per component (1-byte [render target component
alignment](#render-target-component-alignment))

[`r8unorm`](#dom-gputextureformat-r8unorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

1

[`r8snorm`](#dom-gputextureformat-r8snorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

1

[`r8uint`](#dom-gputextureformat-r8uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

1

[`r8sint`](#dom-gputextureformat-r8sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

1

[`rg8unorm`](#dom-gputextureformat-rg8unorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

2

[`rg8snorm`](#dom-gputextureformat-rg8snorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

2

[`rg8uint`](#dom-gputextureformat-rg8uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

2

[`rg8sint`](#dom-gputextureformat-rg8sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

2

[`rgba8unorm`](#dom-gputextureformat-rgba8unorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

4

8

[`rgba8unorm-srgb`](#dom-gputextureformat-rgba8unorm-srgb)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

4

8

[`rgba8snorm`](#dom-gputextureformat-rgba8snorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

✓

✓

4

8

[`rgba8uint`](#dom-gputextureformat-rgba8uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

4

[`rgba8sint`](#dom-gputextureformat-rgba8sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

4

[`bgra8unorm`](#dom-gputextureformat-bgra8unorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

If
[`"bgra8unorm-storage"`](#bgra8unorm-storage) is enabled

4

8

[`bgra8unorm-srgb`](#dom-gputextureformat-bgra8unorm-srgb)

[`"core-features-and-limits"`](#core-features-and-limits)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

4

8

16 bits per component (2-byte [render target component
alignment](#render-target-component-alignment))

[`r16unorm`](#dom-gputextureformat-r16unorm)

[`"texture-formats-tier1"`](#texture-formats-tier1)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

2

[`r16snorm`](#dom-gputextureformat-r16snorm)

[`"texture-formats-tier1"`](#texture-formats-tier1)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

2

[`r16uint`](#dom-gputextureformat-r16uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

2

[`r16sint`](#dom-gputextureformat-r16sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

2

[`r16float`](#dom-gputextureformat-r16float)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

2

[`rg16unorm`](#dom-gputextureformat-rg16unorm)

[`"texture-formats-tier1"`](#texture-formats-tier1)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

4

[`rg16snorm`](#dom-gputextureformat-rg16snorm)

[`"texture-formats-tier1"`](#texture-formats-tier1)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

4

[`rg16uint`](#dom-gputextureformat-rg16uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

4

[`rg16sint`](#dom-gputextureformat-rg16sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

4

[`rg16float`](#dom-gputextureformat-rg16float)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

4

[`rgba16unorm`](#dom-gputextureformat-rgba16unorm)

[`"texture-formats-tier1"`](#texture-formats-tier1)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

8

[`rgba16snorm`](#dom-gputextureformat-rgba16snorm)

[`"texture-formats-tier1"`](#texture-formats-tier1)

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

✓

8

[`rgba16uint`](#dom-gputextureformat-rgba16uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

8

[`rgba16sint`](#dom-gputextureformat-rgba16sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

8

[`rgba16float`](#dom-gputextureformat-rgba16float)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

8

32 bits per component (4-byte [render target component
alignment](#render-target-component-alignment))

[`r32uint`](#dom-gputextureformat-r32uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

✓

✓

✓

4

[`r32sint`](#dom-gputextureformat-r32sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

✓

✓

✓

4

[`r32float`](#dom-gputextureformat-r32float)

[`"float"`](#dom-gputexturesampletype-float) if
[`"float32-filterable"`](#float32-filterable) is enabled

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

If
[`"float32-blendable"`](#float32-blendable) is enabled

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

✓

✓

✓

4

[`rg32uint`](#dom-gputextureformat-rg32uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

8

[`rg32sint`](#dom-gputextureformat-rg32sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

8

[`rg32float`](#dom-gputextureformat-rg32float)

[`"float"`](#dom-gputexturesampletype-float) if
[`"float32-filterable"`](#float32-filterable) is enabled

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

If
[`"float32-blendable"`](#float32-blendable) is enabled

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

8

[`rgba32uint`](#dom-gputextureformat-rgba32uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

16

[`rgba32sint`](#dom-gputextureformat-rgba32sint)

[`"sint"`](#dom-gputexturesampletype-sint)

✓

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

16

[`rgba32float`](#dom-gputextureformat-rgba32float)

[`"float"`](#dom-gputexturesampletype-float) if
[`"float32-filterable"`](#float32-filterable) is enabled

[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

If
[`"float32-blendable"`](#float32-blendable) is enabled

✓

✓

If
[`"texture-formats-tier2"`](#texture-formats-tier2) is enabled

16

mixed component width, 32 bits per texel (4-byte [render target
component
alignment](#render-target-component-alignment))

[`rgb10a2uint`](#dom-gputextureformat-rgb10a2uint)

[`"uint"`](#dom-gputexturesampletype-uint)

✓

If
[`"core-features-and-limits"`](#core-features-and-limits) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

4

8

[`rgb10a2unorm`](#dom-gputextureformat-rgb10a2unorm)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✓

✓

✓

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

4

8

[`rg11b10ufloat`](#dom-gputextureformat-rg11b10ufloat)

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

If
[`"rg11b10ufloat-renderable"`](#rg11b10ufloat-renderable) is enabled

If
[`"texture-formats-tier1"`](#texture-formats-tier1) is enabled

4

8

#### 26.1.2. Depth-stencil formats

A [depth-or-stencil format] is any format with depth and/or stencil
aspects. A [combined depth-stencil
format] is a [depth-or-stencil
format](#depth-or-stencil-format) that has both depth and stencil aspects.

All [depth-or-stencil
formats](#depth-or-stencil-format) support the
[`COPY_SRC`](#dom-gputextureusage-copy_src),
[`COPY_DST`](#dom-gputextureusage-copy_dst),
[`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding), and
[`RENDER_ATTACHMENT`](#dom-gputextureusage-render_attachment) usages. All of these formats support multisampling.
However, certain copy operations also restrict the source and
destination formats, and none of these formats support textures with
[`"3d"`](#dom-gputexturedimension-3d) dimension.

Depth textures cannot be used with
[`"filtering"`](#dom-gpusamplerbindingtype-filtering) samplers, but can always be used with
[`"comparison"`](#dom-gpusamplerbindingtype-comparison) samplers even if they use filtering.

Format

NOTE:

[Texel block memory
cost](#texel-block-memory-cost) (Bytes)

Aspect

[`GPUTextureSampleType`](#enumdef-gputexturesampletype)

Valid [texel copy](#texel-copy)
source

Valid [texel copy](#texel-copy)
destination

[Texel block copy
footprint](#texel-block-copy-footprint) (Bytes)

[Aspect-specific format]

[`stencil8`](#dom-gputextureformat-stencil8)

1 − 4

stencil

[`"uint"`](#dom-gputexturesampletype-uint)

✓

1

[`stencil8`](#dom-gputextureformat-stencil8)

[`depth16unorm`](#dom-gputextureformat-depth16unorm)

2

depth

[`"depth"`](#dom-gputexturesampletype-depth),
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

2

[`depth16unorm`](#dom-gputextureformat-depth16unorm)

[`depth24plus`](#dom-gputextureformat-depth24plus)

4

depth

[`"depth"`](#dom-gputexturesampletype-depth),
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✗

--

[`depth24plus`](#dom-gputextureformat-depth24plus)

[`depth24plus-stencil8`](#dom-gputextureformat-depth24plus-stencil8)

4 − 8

depth

[`"depth"`](#dom-gputexturesampletype-depth),
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✗

--

[`depth24plus`](#dom-gputextureformat-depth24plus)

stencil

[`"uint"`](#dom-gputexturesampletype-uint)

✓

1

[`stencil8`](#dom-gputextureformat-stencil8)

[`depth32float`](#dom-gputextureformat-depth32float)

4

depth

[`"depth"`](#dom-gputexturesampletype-depth),
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✗

4

[`depth32float`](#dom-gputextureformat-depth32float)

[`depth32float-stencil8`](#dom-gputextureformat-depth32float-stencil8)

5 − 8

depth

[`"depth"`](#dom-gputexturesampletype-depth),
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

✓

✗

4

[`depth32float`](#dom-gputextureformat-depth32float)

stencil

[`"uint"`](#dom-gputexturesampletype-uint)

✓

1

[`stencil8`](#dom-gputextureformat-stencil8)

[24-bit depth] refers to a 24-bit unsigned normalized depth format with a
range from 0.0 to 1.0, which would be spelled \"depth24unorm\" if
exposed.

##### 26.1.2.1. Reading and Sampling Depth/Stencil Textures

It is
[possible](#abstract-opdef-validating-shader-binding) to bind a depth-aspect
[`GPUTextureView`](#gputextureview) to either a `texture_depth_*` binding or a binding with
other non-depth 2d/cube texture types.

A stencil-aspect
[`GPUTextureView`](#gputextureview) must be bound to a normal texture binding type. The
[`sampleType`](#dom-gputexturebindinglayout-sampletype) in the
[`GPUBindGroupLayout`](#gpubindgrouplayout) must be
[`"uint"`](#dom-gputexturesampletype-uint).

If the
[`"texture-component-swizzle"`](#dom-gpufeaturename-texture-component-swizzle) feature is enabled, reading or sampling the depth or
stencil aspect of a texture behaves as if the texture contains the
values `(V, 0, 0, 1)` where V is the actual depth or stencil value.
Otherwise, the values are `(V, X, X, X)` where each X is an
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) unspecified value.

To reduce compatibility issues in practice, implementations **should**
provide `(V, 0, 0, 1)` wherever possible, even if the
[`"texture-component-swizzle"`](#dom-gpufeaturename-texture-component-swizzle) feature is not enabled.

For depth-aspect bindings, the unspecified values are not visible
through bindings with `texture_depth_*` types.

If a depth texture is bound to `tex`
with type `texture_2d<f32>`:

- `textureSample(tex, ...)` will return `vec4<f32>(D, X, X, X)`.

- `textureGather(0, tex, ...)` will return `vec4<f32>(D1, D2, D3, D4)`.

- `textureGather(2, tex, ...)` will return `vec4<f32>(X1, X2, X3, X4)`
 (a completely unspecified value).

 Short of adding a new more constrained stencil sampler
type (like depth), it's infeasible for implementations to efficiently
paper over the driver differences for depth/stencil reads. As this was
not a portability pain point for WebGL, it's not expected to be
problematic in WebGPU. In practice, expect either `(V, V, V, V)` or
`(V, 0, 0, 1)` (where `V` is the depth or stencil value), depending on
hardware.

##### 26.1.2.2. Copying Depth/Stencil Textures

The depth aspects of depth32float formats
([`"depth32float"`](#dom-gputextureformat-depth32float) and
[`"depth32float-stencil8"`](#dom-gputextureformat-depth32float-stencil8) have a limited range. As a result, copies into such
textures are only valid from other textures of the same format.

The depth aspects of depth24plus formats
([`"depth24plus"`](#dom-gputextureformat-depth24plus) and
[`"depth24plus-stencil8"`](#dom-gputextureformat-depth24plus-stencil8)) have opaque representations (implemented as either
[24-bit depth](#24-bit-depth) or
[`"depth32float"`](#dom-gputextureformat-depth32float)). As a result, depth-aspect [texel
copies](#texel-copy) are not
allowed with these formats.

NOTE:

It is possible to imitate these disallowed copies:

- All of these formats can be written in a render pass using a fragment
 shader that outputs depth values via the `frag_depth` output.

- Textures with \"depth24plus\" formats can be read as shader textures,
 and written to a texture (as a render pass attachment) or buffer (via
 a storage buffer binding in a compute shader).

#### 26.1.3. Packed formats

All packed texture formats support
[`COPY_SRC`](#dom-gputextureusage-copy_src),
[`COPY_DST`](#dom-gputextureusage-copy_dst), and
[`TEXTURE_BINDING`](#dom-gputextureusage-texture_binding) usages. All of these formats are
[filterable](#filterable). None of
these formats are [renderable](#renderable) or support multisampling.

A [compressed format] is any format with a block size greater than
1×1.

 The [texel block memory
cost](#texel-block-memory-cost) of each of these formats is the same as its [texel
block copy
footprint](#texel-block-copy-footprint).

Format

[Texel block copy
footprint](#texel-block-copy-footprint) (Bytes)

[`GPUTextureSampleType`](#enumdef-gputexturesampletype)

Texel block [width](#texel-block-width)/[height](#texel-block-height)

[`"3d"`](#dom-gputexturedimension-3d)

[Feature](#feature)

[`rgb9e5ufloat`](#dom-gputextureformat-rgb9e5ufloat)

4

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

1 × 1

✓

[`bc1-rgba-unorm`](#dom-gputextureformat-bc1-rgba-unorm)

8

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

4 × 4

If
[`"texture-compression-bc-sliced-3d"`](#texture-compression-bc-sliced-3d) is enabled

[`texture-compression-bc`](#texture-compression-bc)

[`bc1-rgba-unorm-srgb`](#dom-gputextureformat-bc1-rgba-unorm-srgb)

[`bc2-rgba-unorm`](#dom-gputextureformat-bc2-rgba-unorm)

16

[`bc2-rgba-unorm-srgb`](#dom-gputextureformat-bc2-rgba-unorm-srgb)

[`bc3-rgba-unorm`](#dom-gputextureformat-bc3-rgba-unorm)

16

[`bc3-rgba-unorm-srgb`](#dom-gputextureformat-bc3-rgba-unorm-srgb)

[`bc4-r-unorm`](#dom-gputextureformat-bc4-r-unorm)

8

[`bc4-r-snorm`](#dom-gputextureformat-bc4-r-snorm)

[`bc5-rg-unorm`](#dom-gputextureformat-bc5-rg-unorm)

16

[`bc5-rg-snorm`](#dom-gputextureformat-bc5-rg-snorm)

[`bc6h-rgb-ufloat`](#dom-gputextureformat-bc6h-rgb-ufloat)

16

[`bc6h-rgb-float`](#dom-gputextureformat-bc6h-rgb-float)

[`bc7-rgba-unorm`](#dom-gputextureformat-bc7-rgba-unorm)

16

[`bc7-rgba-unorm-srgb`](#dom-gputextureformat-bc7-rgba-unorm-srgb)

[`etc2-rgb8unorm`](#dom-gputextureformat-etc2-rgb8unorm)

8

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

4 × 4

[`texture-compression-etc2`](#texture-compression-etc2)

[`etc2-rgb8unorm-srgb`](#dom-gputextureformat-etc2-rgb8unorm-srgb)

[`etc2-rgb8a1unorm`](#dom-gputextureformat-etc2-rgb8a1unorm)

8

[`etc2-rgb8a1unorm-srgb`](#dom-gputextureformat-etc2-rgb8a1unorm-srgb)

[`etc2-rgba8unorm`](#dom-gputextureformat-etc2-rgba8unorm)

16

[`etc2-rgba8unorm-srgb`](#dom-gputextureformat-etc2-rgba8unorm-srgb)

[`eac-r11unorm`](#dom-gputextureformat-eac-r11unorm)

8

[`eac-r11snorm`](#dom-gputextureformat-eac-r11snorm)

[`eac-rg11unorm`](#dom-gputextureformat-eac-rg11unorm)

16

[`eac-rg11snorm`](#dom-gputextureformat-eac-rg11snorm)

[`astc-4x4-unorm`](#dom-gputextureformat-astc-4x4-unorm)

16

[`"float"`](#dom-gputexturesampletype-float),\
[`"unfilterable-float"`](#dom-gputexturesampletype-unfilterable-float)

4 × 4

If
[`"texture-compression-astc-sliced-3d"`](#texture-compression-astc-sliced-3d) is enabled

[`texture-compression-astc`](#texture-compression-astc)

[`astc-4x4-unorm-srgb`](#dom-gputextureformat-astc-4x4-unorm-srgb)

[`astc-5x4-unorm`](#dom-gputextureformat-astc-5x4-unorm)

16

5 × 4

[`astc-5x4-unorm-srgb`](#dom-gputextureformat-astc-5x4-unorm-srgb)

[`astc-5x5-unorm`](#dom-gputextureformat-astc-5x5-unorm)

16

5 × 5

[`astc-5x5-unorm-srgb`](#dom-gputextureformat-astc-5x5-unorm-srgb)

[`astc-6x5-unorm`](#dom-gputextureformat-astc-6x5-unorm)

16

6 × 5

[`astc-6x5-unorm-srgb`](#dom-gputextureformat-astc-6x5-unorm-srgb)

[`astc-6x6-unorm`](#dom-gputextureformat-astc-6x6-unorm)

16

6 × 6

[`astc-6x6-unorm-srgb`](#dom-gputextureformat-astc-6x6-unorm-srgb)

[`astc-8x5-unorm`](#dom-gputextureformat-astc-8x5-unorm)

16

8 × 5

[`astc-8x5-unorm-srgb`](#dom-gputextureformat-astc-8x5-unorm-srgb)

[`astc-8x6-unorm`](#dom-gputextureformat-astc-8x6-unorm)

16

8 × 6

[`astc-8x6-unorm-srgb`](#dom-gputextureformat-astc-8x6-unorm-srgb)

[`astc-8x8-unorm`](#dom-gputextureformat-astc-8x8-unorm)

16

8 × 8

[`astc-8x8-unorm-srgb`](#dom-gputextureformat-astc-8x8-unorm-srgb)

[`astc-10x5-unorm`](#dom-gputextureformat-astc-10x5-unorm)

16

10 × 5

[`astc-10x5-unorm-srgb`](#dom-gputextureformat-astc-10x5-unorm-srgb)

[`astc-10x6-unorm`](#dom-gputextureformat-astc-10x6-unorm)

16

10 × 6

[`astc-10x6-unorm-srgb`](#dom-gputextureformat-astc-10x6-unorm-srgb)

[`astc-10x8-unorm`](#dom-gputextureformat-astc-10x8-unorm)

16

10 × 8

[`astc-10x8-unorm-srgb`](#dom-gputextureformat-astc-10x8-unorm-srgb)

[`astc-10x10-unorm`](#dom-gputextureformat-astc-10x10-unorm)

16

10 × 10

[`astc-10x10-unorm-srgb`](#dom-gputextureformat-astc-10x10-unorm-srgb)

[`astc-12x10-unorm`](#dom-gputextureformat-astc-12x10-unorm)

16

12 × 10

[`astc-12x10-unorm-srgb`](#dom-gputextureformat-astc-12x10-unorm-srgb)

[`astc-12x12-unorm`](#dom-gputextureformat-astc-12x12-unorm)

16

12 × 12

[`astc-12x12-unorm-srgb`](#dom-gputextureformat-astc-12x12-unorm-srgb)
