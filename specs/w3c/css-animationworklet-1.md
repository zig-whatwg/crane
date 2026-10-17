## 1. Introduction

*This section is not normative.*

This document introduces a new primitive that provides extensibility in
web animations and enables high performance interactive procedural
animations on the web. For details on the rationale and motivation see
both
[\[explainer\]](#biblio-explainer "Animation Worklet Explainer")
and
[\[principles\]](#biblio-principles "Animation Worklet Design Principles and Goals").

The [Animation Worklet](#animation-worklet) API provides a method to create scripted animations
that control a set of [animation
effects](https://drafts.csswg.org/web-animations#animation-effect). The API is designed to make it possible for user
agents to run such animations in their own dedicated thread to provide a
degree of performance isolation from main thread.

### 1.1. Relationship to the Web Animations API

*This section is not normative.*

Animations running inside an [Animation
Worklet](#animation-worklet) execution context expose the
[`Animation`](https://drafts.csswg.org/web-animations-1/#animation) interface from the Web Animations specification on the
main javascript execution context. This means they can be controlled and
inspected from main thread using the same Web Animation APIs.

## 2. Animation Worklet

[Animation Worklet] is a
[`Worklet`](https://html.spec.whatwg.org/multipage/worklets.html#worklet) responsible for all classes related to custom
animations. The worklet can be accessed via
[`animationWorklet`](#dom-css-animationworklet) attribute.

```
[Exposed=Window]
partial namespace CSS {
 [SameObject] readonly attribute Worklet animationWorklet;
};
```

The
[`animationWorklet`](#dom-css-animationworklet)'s [worklet global scope
type](https://html.spec.whatwg.org/multipage/worklets.html#worklet-global-scope-type) is
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope).

[`AnimationWorkletGlobalScope`](#animationworkletglobalscope) represents the global execution context of
[`animationWorklet`](#dom-css-animationworklet).

```
[ Global=(Worklet,AnimationWorklet), Exposed=AnimationWorklet ]
interface AnimationWorkletGlobalScope : WorkletGlobalScope {
 undefined registerAnimator(DOMString name, AnimatorInstanceConstructor animatorCtor);
};

callback AnimatorInstanceConstructor = any (any options, optional any state);
```

## 3. Animator

An [Animator]
represents a custom animation that is running inside
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope). Each Animator is associated with an
[animation](https://drafts.csswg.org/web-animations#concept-animation) instance (of type
[`WorkletAnimation`](#workletanimation)) in the document and determines how that animation
progresses its [animation
effect](https://drafts.csswg.org/web-animations#animation-effect). The `animate` function contains the logic responsible
for translating the animation current time into appropriate progress of
the animation effect. An animator can only be instantiated by
construction of a
[`WorkletAnimation`](#workletanimation) in the document.

Two animators types are supported: [Stateless
Animator](#stateless-animator) and [Stateful
Animator](#stateful-animator) each providing a different state management strategy.

### 3.1. Stateless Animator

A [Stateless Animator] is a type of animator does not depend on any
local state either stored on the instance or global scope. Effectively,
the animate function of an [Stateless
Animator](#stateless-animator) can be treated as a pure function with the expectation
that given the same input, it produces the same output.

This is how an stateless animator class should look.

```
class FooAnimator {
 constructor(options) {
 // Called when a new animator is instantiated.
 }
 animate(currentTime, effect) {
 // Animation frame logic goes here.
 }
}
```

 The statelessness allows animation worklet to perform
optimization such as producing multiple animation frames in parallel,
sharing a single animator instance for multiple animations, and
performing very cheap teardown and setup. Using [Stateless
Animator](#stateless-animator) is highly recommended to enable such optimizations.

### 3.2. Stateful Animator

A [Stateful Animator] is a type of animator that can have local
state and animation worklet guarantees that it maintains this state as
long as the stateful animator fulfills the contract required by its
interface and as described following.

[Animation worklet](#animation-worklet) maintains a set of
[`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope)s which may exist across different threads or processes.
Animation worklet may temporarily terminate a global scope (e.g., to
preserve resources) or move a running [animator
instance](#animator-instance) across different global scopes (e.g., if its effect is
mutable only in a certain thread). Animation worklet guarantees that a
stateful animator instance's state is maintained even if the instance is
respawned in a different global scope.

The basic mechanism for maintaining the state is that the animation
worklet snapshots the local state that is exposed via the [state
function](#state-function) and
then reifies it so that it can be passed into the constructor when the
animator instance is respawned at a later time in a potentially
different global scope. The [migrate an animator
instance](#migrate-an-animator-instance) algorithm specifies this process in details.

A user-defined stateful animator is expected to fulfill the required
contract which is that its state function returns an object representing
its state that can be serialized using structured serialized algorithm
and that it can also recreate its state given that same object passed to
its constructor.

This is how a stateful animator class should look.

```
class BarAnimator {
 constructor(options, state) {
 // Called when a new animator is instantiated (either first time or after being respawned).
 this.currentVelocity = state ? state.velocity : 0;
 }
 animate(currentTime, effect) {
 // Animation frame logic goes here and can rely on this.currentVelocity.
 this.currentVelocity += 0.1;
 }
 state() {
 // The returned object should be serializable using structured clonable algorithm.
 return {
 velocity: this.currentVelocity;
 }
 }
}
```

### 3.3. Animator Definition

An [animator definition] is a
[struct](https://infra.spec.whatwg.org/#struct) which describes the author defined custom animation
logic. It consists of:

-

 [animator name]

 : A
 [\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident)#.

-

 [class constructor]

 : A
 [`AnimatorInstanceConstructor`](#callbackdef-animatorinstanceconstructor) [callback
 function](https://webidl.spec.whatwg.org/#dfn-callback-function) type.

-

 [animate function]

 : A
 [Function](https://heycam.github.io/webidl/#Function) [callback
 function](https://webidl.spec.whatwg.org/#dfn-callback-function) type.

-

 [state function]

 : A
 [Function](https://heycam.github.io/webidl/#Function) [callback
 function](https://webidl.spec.whatwg.org/#dfn-callback-function) type.

-

 [stateful flag]

 : A boolean flag

A [stateful animator definition] is an [animator
definition](#animator-definition) whose [stateful
flag](#animator-definition-stateful-flag) is **true**.

A [document animator definition] is a
[struct](https://infra.spec.whatwg.org/#struct) which describes the information needed by the
[document](https://dom.spec.whatwg.org/#concept-document) about the author defined custom animation. It consists
of:

-

 [stateful flag]

 : A boolean flag

### 3.4. Registering an Animator Definition

The
[document](https://dom.spec.whatwg.org/#concept-document) has a
[map](https://infra.spec.whatwg.org/#ordered-map) of [document animator
definitions]. The map gets populated when
[`registerAnimator(name, animatorCtor)`](#dom-animationworkletglobalscope-registeranimator) is called.

An
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope) has a
[map](https://infra.spec.whatwg.org/#ordered-map) of [animator definitions]. The map gets populated when
[`registerAnimator(name, animatorCtor)`](#dom-animationworkletglobalscope-registeranimator) is called.

Note that to register a [stateful animator
definition](#stateful-animator-definition) it is simply enough for the registered class to have a
`state` function.

When the
[`registerAnimator(``name``, ``animatorCtor``)`] method is called in a
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope), the user agent *must* run the following steps:

1. If `name` is not a valid
 [\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident),
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [TypeError](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort all these steps.

2. Let `animatorDefinitions` be the
 [`AnimationWorkletGlobalScope`](#animationworkletglobalscope)'s [animator
 definitions](#animator-definitions)
 [map](https://infra.spec.whatwg.org/#ordered-map).

3. If `animatorDefinitions`\[`name`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [NotSupportedError](https://heycam.github.io/webidl/#notsupportederror) and abort all these steps.

4. If the result of
 [IsConstructor](https://tc39.github.io/ecma262/#sec-isconstructor)(`animatorCtor`) is **false**,
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [TypeError](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort all these steps.

5. Let `prototype` be the result of
 [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`animatorCtor`, \"prototype\").

6. Let `animateFuncValue` be the result of
 [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`prototype`, \"animate\").

7. Let `animateFunc` be the result of
 [converting](https://heycam.github.io/webidl/#es-type-mapping) `animateFuncValue` to the
 [Function](https://heycam.github.io/webidl/#Function) [callback
 function](https://webidl.spec.whatwg.org/#dfn-callback-function) type. If an exception is thrown, rethrow the
 exception and abort all these steps.

8. Let `stateFuncValue` be the result of
 [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`prototype`, \"state\").

9. Let `stateFunc` be the result of
 [converting](https://heycam.github.io/webidl/#es-type-mapping) `stateFuncValue` to the
 [Function](https://heycam.github.io/webidl/#Function) [callback
 function](https://webidl.spec.whatwg.org/#dfn-callback-function) type, If an exception is thrown, set
 `stateful` to be **false**, otherwise set
 `stateful` to be **true** and `stateFunc` to
 be undefined.

10. Let `definition` be a new [animator
 definition](#animator-definition) with:

 - [animator name](#animator-name) being `name`

 - [class constructor](#class-constructor) being `animatorCtor`

 - [animate function](#animate-function) being `animateFunc`

 - [state function](#state-function) being `stateFunc`

 - [stateful
 flag](#animator-definition-stateful-flag) being `stateful`

11. [set](https://infra.spec.whatwg.org/#map-set) the
 `animatorDefinitions`\[`name`\] to
 `definition`.

12. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Let `documentAnimatorDefinitions` be the associated
 [document's](https://dom.spec.whatwg.org/#concept-document) [document animator
 definitions](#document-animator-definitions)
 [map](https://infra.spec.whatwg.org/#ordered-map).

 2. Let `documentDefinition` be a new [document animator
 definition](#document-animator-definition) with:

 - [stateful
 flag](#animator-definition-stateful-flag) being `stateful`

 3. If `documentAnimatorDefinitions`\[`name`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), run the following steps:

 1. Let `existingDocumentDefinition` be the result of
 [get](https://infra.spec.whatwg.org/#map-get)
 `documentAnimatorDefinitions`\[`name`\].

 2. If `existingDocumentDefinition` is `"invalid"`,
 abort all these steps.

 3. If `existingDocumentDefinition` and
 `documentDefinition` are not equivalent, (that is
 their [stateful
 flag](#document-animator-definition-stateful-flag)s are different), then:

 [set](https://infra.spec.whatwg.org/#map-set)
 `documentAnimatorDefinitions`\[`name`\]
 to `"invalid"`.

 Log an error to the debugging console stating that the same
 class was registered with different `stateful flag`.

 4. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set)
 `documentAnimatorDefinitions`\[`name`\] to
 `documentDefinition`.

### 3.5. Animator Effect

A [Animator Effect] represents the underlying [animation
effect](https://drafts.csswg.org/web-animations#animation-effect) inside animation worklet.

It has a [corresponding effect] property which is a reference to the
underlying [animation
effect](https://drafts.csswg.org/web-animations#animation-effect). It also has corresponding properties for the following
[animation
effect](https://drafts.csswg.org/web-animations#animation-effect)'s properties:

- [local
 time](https://drafts.csswg.org/web-animations#local-time),

- [start
 delay](https://drafts.csswg.org/web-animations#start-delay),

- [end
 delay](https://drafts.csswg.org/web-animations#end-delay),

- [fill
 mode](https://drafts.csswg.org/web-animations#fill-mode),

- [iteration
 start](https://drafts.csswg.org/web-animations#iteration-start),

- [iteration
 count](https://drafts.csswg.org/web-animations#iteration-count),

- [iteration
 duration](https://drafts.csswg.org/web-animations#iteration-duration),

- [playback
 direction](https://drafts.csswg.org/web-animations#playback-direction), and

- [timing
 function](https://drafts.csswg.org/web-animations#timing-function).

[Animator Effect](#animator-effect) is represented by the
[`WorkletAnimationEffect`](#workletanimationeffect) interface inside
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope).

```
[ Exposed=AnimationWorklet ]
interface WorkletAnimationEffect {
 EffectTiming getTiming();
 ComputedEffectTiming getComputedTiming();
 attribute double? localTime;
};
```

[`WorkletAnimationEffect`](#workletanimationeffect) is basically a restricted version of
[`AnimationEffect`](https://drafts.csswg.org/web-animations-1/#animationeffect) interface which does not have
[`updateTiming`](https://drafts.csswg.org/web-animations-1/#dom-animationeffect-updatetiming) but additionally allows local time to be set.

[`getTiming()`]

: Returns the specified timing properties using the corresponding
 properties.

[`getComputedTiming()`]

: Returns the calculated timing properties using the corresponding
 properties.

[`localTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), nullable

: Getting the attribute returns the corresponding [local
 time](https://drafts.csswg.org/web-animations#local-time). Setting the attribute updates the local time given
 this effect as `effect` and the attribute value as
 `time`:

 1. If the `time` is the same as `effect`'s
 [local
 time](https://drafts.csswg.org/web-animations#local-time) then skip following steps.

 2. Set the `effect`'s [local
 time](https://drafts.csswg.org/web-animations#local-time) to `time`.

 3. Set the `effect`'s animator instance's [sync
 requested
 flag](#sync-requested-flag) to **true**.

## 4. Animator Instance

An [animator instance] is a
[struct](https://infra.spec.whatwg.org/#struct) which describes a fully realized custom
[animator](#animator) in an
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope). It has a reference to an [animator
definition](#animator-definition) and owns the instance specific state such as animation
effect and timeline. It consists of:

-

 [animator name](#animator-name)

 : A string used to identify the animator definition.

-

 [frame requested flag](#frame-requested-flag)

 : A boolean flag that indicates if the animator needs to animate.

-

 [sync requested flag]

 : A flag that indicates if the animator needs to sync its output.

-

 [effect]

 : An [Animator Effect](#animator-effect).

-

 [animator current time]

 : A time value equivalent to the corresponding [worklet
 animation](#worklet-animation)'s current time.

-

 [animator timeline]

 : The
 [timeline](https://drafts.csswg.org/web-animations#timeline) of the corresponding [worklet
 animation](#worklet-animation).

-

 [animator serialized options]

 : The serializable object representing the options to be used when
 constructing the animator instance.

A [stateful animator instance] is an [animator
instance](#animator-instance) whose corresponding definition is a [stateful animator
definition](#stateful-animator-definition).

### 4.1. Creating an Animator Instance

Each [animator instance](#animator-instance) lives in an
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope).

Each
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope) has an [animator instance set]. The set is populated when
the user agent constructs a new [animator
instance](#animator-instance) in the
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope) scope. Each [animator
instance](#animator-instance) corresponds to a worklet animation in the document
scope.

To [create a new animator instance] given a `name`,
`timeline`, `effect`,
`serializedOptions`, `serializedState`, and
`workletGlobalScope`, the user agent *must* run the following
steps:

1. Let the `definition` be the result of looking up
 `name` on the `workletGlobalScope`'s [animator
 definitions](#animator-definitions).

 If `definition` does not exist abort the following steps.

2. Let `animatorCtor` be the [class
 constructor](#class-constructor) of `definition`.

3. Let `options` be
 [StructuredDeserialize](http://w3c.github.io/html/infrastructure.html#structureddeserialize)(`serializedOptions`).

4. Let `state` be
 [StructuredDeserialize](http://w3c.github.io/html/infrastructure.html#structureddeserialize)(`serializedState`).

5. Let `animatorInstance` be the result of
 [constructing](https://heycam.github.io/webidl/#construct-a-callback-function) `animatorCtor` with
 «`options`, `state`» as arguments. If an
 exception is thrown, rethrow the exception and abort all these
 steps.

6. Let `animatorEffect` be the result of
 [constructing](https://heycam.github.io/webidl/#construct-a-callback-function) a
 [`WorkletAnimationEffect`](#workletanimationeffect) with its [corresponding
 effect](#corresponding-effect) being `effect`.

7. Set the following on `animatorInstance` with:

 - [animator name](#animator-name) being `name`

 - [frame requested
 flag](#frame-requested-flag) being **false**

 - [sync requested
 flag](#sync-requested-flag) being **false**

 - [animator current
 time](#animator-current-time) being unresolved

 - [effect](#effect) being
 `animatorEffect`

 - [animator timeline](#animator-timeline) being `timeline`

 - [animator serialized
 options](#animator-serialized-options) being `options`

8. Add `animatorInstance` to
 `workletGlobalScope`'s [animator instance
 set](#animator-instance-set).

### 4.2. Running Animators

When the user agent wants to produce a new animation frame, if for any
[animator instance](#animator-instance) the associated [frame requested
flag](#frame-requested-flag) is **true** then the the user agent *must* [run
animators](#run-animators) for
the current frame in all its associated global scopes.

 The user agent is not required to run animations on
every visual frame. It is legal to defer generating an animation frame
until a later frame. This allow the user agent to provide a different
service level according to their policy.

When the user agent wants to [run animators] in a given
`workletGlobalScope`, it *must* run the following steps:

1. Iterate over all [animator
 instance](#animator-instance)s in the `workletGlobalScope`'s [animator
 instance
 set](#animator-instance-set). For each such `animator` the user agent
 *must* perform the following steps:

 1. Let `animatorName` be `animator`'s
 [animator name](#animator-name)

 2. Let the `definition` be the result of looking up
 `animatorName` on the
 `workletGlobalScope`'s [animator
 definitions](#animator-definitions).

 If `definition` does not exist then abort the following
 steps.

 3. If the [frame requested
 flag](#frame-requested-flag) for `animator` is **false** or the
 effect belonging to the `animator` will not be
 visible within the visual viewport of the current frame the user
 agent *may* abort all the following steps.

 (#issue-68dc788e) Consider giving user agents
 permission to skip running individual animator instances to
 throttle slow animators.

 4. Let `animateFunction` be `definition`'s
 [animate function](#animate-function).

 5. Let `currentTime` be [animator current
 time](#animator-current-time) of `animator`.

 6. Let `effect` be [effect](#effect) of `animator`.

 7. [Invoke](https://heycam.github.io/webidl/#invoke-a-callback-function) `animateFunction` with arguments
 «`currentTime`, `effect`», and with
 `animator` as the [callback this
 value](https://heycam.github.io/webidl/#dfn-callback-this-value).

2. If any [animator
 instance](#animator-instance)s in the `workletGlobalScope`'s [animator
 instance
 set](#animator-instance-set) has its [sync requested
 flag](#sync-requested-flag) set to **true** then [sync local times to
 document](#sync-local-times-to-document) given `workletGlobalScope`.

 Although inefficient, it is legal for the user agent to
[run animators](#run-animators)
multiple times in the same frame.

should be explicit as to what happens if
the animateFunction throws an exception. At least we should have wording
that the localTime values of the effects are ignored to avoid incorrect
partial updates.

### 4.3. Removing an Animator Instance

To [remove an animator instance] given `animator` and
`workletGlobalScope` the user agent *must* run the following
steps:

1. Remove `animator` from `workletGlobalScope`'s
 [animator instance
 set](#animator-instance-set).

### 4.4. Migrating an Animator Instance

The migration process allows [stateful animator
instance](#stateful-animator-instance) to be migrated to a different
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope) without losing their local state.

To [migrate an animator instance] from one
[`AnimationWorkletGlobalScope`](#animationworkletglobalscope) to another, given `animator`,
`sourceWorkletGlobalScope`,
`destinationWorkletGlobalScope`, the user agent *must* run
the following steps :

1. Let `serializedState` be undefined.

2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on `sourceWorkletGlobalScope` to run the
 following steps:

 1. Let `animatorName` be `animator`'s
 [animator name](#animator-name)

 2. Let `definition` be the result of looking up
 `animatorName` on
 `sourceWorkletGlobalScope`'s [animator
 definitions](#animator-definitions).

 If `definition` does not exist then abort the
 following steps.

 3. Let `stateful` be the [stateful
 flag](#animator-definition-stateful-flag) of `definition`.

 4. If `stateful` is **false** then abort the following
 steps.

 5. Let `stateFunction` be `definition`'s
 [state function](#state-function).

 6. Let `state` be the result of
 [Invoke](https://heycam.github.io/webidl/#invoke-a-callback-function) `stateFunction` with
 `animator` as the [callback this
 value](https://heycam.github.io/webidl/#dfn-callback-this-value). If any exception is thrown, rethrow the
 exception and abort the following steps.

 7. Set `serializedState` to be the result of
 [StructuredSerialize](http://w3c.github.io/html/infrastructure.html#structuredserialize)(`state`). If any exception is
 thrown, then abort the following steps.

 8. Run the procedure to [remove an animator
 instance](#remove-an-animator-instance) given `animator`, and
 `sourceWorkletGlobalScope`.

3. Wait for the above task to complete. If the task is aborted, abort
 the following steps.

4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on `destinationWorkletGlobalScope` to
 run the following steps:

 1. Run the procedure to [create a new animator
 instance](#create-a-new-animator-instance) given:

 - The `animator`'s [animator
 name](#animator-name)
 as name.

 - The `animator`'s [animator
 timeline](#animator-timeline) as timeline.

 - The `animator`'s [effect](#effect) as effect.

 - The `animator`'s [animator serialized
 options](#animator-serialized-options) as options.

 - The `serializedState` as state.

 - The `destinationWorkletGlobalScope` as
 workletGlobalScope.

If an animator state getter throws the user agent will remove the
animator but does not recreate it. This effectively removes the animator
instance.

### 4.5. Requesting Animation Frames

Each [animator instance](#animator-instance) has an associated [frame requested
flag]. It is initially set to **false**. Different circumstances
can cause the [frame requested
flag](#frame-requested-flag) to be set to **true**. These include the following:

- Changes in the [current
 time](https://drafts.csswg.org/web-animations#current-time) of the animator's
 [timeline](https://drafts.csswg.org/web-animations#timeline)

- Changes in the [current
 time](https://drafts.csswg.org/web-animations#current-time) of the animator's corresponding [worklet
 animation](#worklet-animation)

Performing [run animators](#run-animators) resets the [frame requested
flag](#frame-requested-flag) on animators to **false**.

## 5. Web Animations Integration

### 5.1. Worklet Animation

[Worklet animation] is a kind of
[animation](https://drafts.csswg.org/web-animations#concept-animation) that delegates animating its animation effect to an
[animator instance](#animator-instance). It controls the lifetime and playback state of its
[corresponding animator
instance](#corresponding-animator-instance).

Being an
[animation](https://drafts.csswg.org/web-animations#concept-animation), [worklet
animation](#worklet-animation) has an [animation
effect](https://drafts.csswg.org/web-animations#animation-effect) and a
[timeline](https://drafts.csswg.org/web-animations#timeline). However unlike other animations the worklet
animation's [current
time](https://drafts.csswg.org/web-animations#current-time) does not directly determine the animation effect's
[local
time](https://drafts.csswg.org/web-animations#local-time) (via its [inherited
time](https://drafts.csswg.org/web-animations#inherited-time)). Instead the associated [animator
instance](#animator-instance) controls the animation effect's [local
time](https://drafts.csswg.org/web-animations#local-time) directly. Note that this means that the
[timeline's](https://drafts.csswg.org/web-animations#timeline) current time does not fully determine the animation's
output.

[Worklet animation](#worklet-animation) has the following properties in addition to the
[`Animation`](https://drafts.csswg.org/web-animations-1/#animation) interface:

-

 [animation animator name]

 : A string that identifies its [animator
 definition](#animator-definition).

-

 [serialized options]

 : A serializable options object that is used whe constructing a new
 animator instance.

-

 [corresponding animator instance]

 : A [Animator
 Instance](#animator-instance).

The existence of [corresponding animator
instance](#corresponding-animator-instance) for a [worklet
animation](#worklet-animation) depends on the animation [play
state](https://drafts.csswg.org/web-animations#play-state). See [§ 5.4 Web Animations
Overrides](#web-animation-overrides) for details on when and this
correspondence changes.

```
[Exposed=Window]
interface WorkletAnimation : Animation {
 constructor(DOMString animatorName,
 optional (AnimationEffect or sequence<AnimationEffect>)? effects = null,
 optional AnimationTimeline? timeline,
 optional any options);
 readonly attribute DOMString animatorName;
};
```

![Overview of the worklet animation timing model.\
The animation current time is input to the animator instance, which
produces a local time value for the animation effect. If the animator
instance is running in a parallel global scope the implementation may
also choose to use the local time value to produce the animation output
and update the visuals in
parallel.](images/WorkletAnimation-timing-model.svg){a
width="600"}

### 5.2. Creating a Worklet Animation

[`WorkletAnimation(``animatorName``, ``effects``, ``timeline``, ``options``)`]

Creates a new
[`WorkletAnimation`](#workletanimation) object using the following procedure:

1. Let `documentAnimatorDefinitions` be the associated
 [document's](https://dom.spec.whatwg.org/#concept-document) [document animator
 definitions](#document-animator-definitions)
 [map](https://infra.spec.whatwg.org/#ordered-map).

2. If
 `documentAnimatorDefinitions`\[`animatorName`\]
 does not
 [exists](https://infra.spec.whatwg.org/#map-exists),
 [throw](https://heycam.github.io/webidl/#dfn-throw) an
 [TypeError](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort the following steps.

3. If
 `documentAnimatorDefinitions`\[`animatorName`\]
 is `"invalid"`,
 [throw](https://heycam.github.io/webidl/#dfn-throw) an
 [TypeError](https://tc39.github.io/ecma262/#sec-native-error-types-used-in-this-standard-typeerror) and abort the following steps.

4. Let `workletAnimation` be a new
 [`WorkletAnimation`](#workletanimation) object.

5. Run the procedure to [set the timeline of an
 animation](https://drafts.csswg.org/web-animations#set-the-timeline-of-an-animation) on `workletAnimation` passing
 `timeline` as the new timeline or, if a
 `timeline` argument is not provided, passing the [default
 document
 timeline](https://drafts.csswg.org/web-animations#the-documents-default-timeline) of the
 [`Document`](https://dom.spec.whatwg.org/#document) associated with the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) that is the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).

6. Let `effect` be the result corresponding to the first
 matching condition from below.

 If `effects` is a [`AnimationEffect`](https://drafts.csswg.org/web-animations-1/#animationeffect) object,

 : Let effect be `effects`.

 If `effects` is a [list](https://infra.spec.whatwg.org/#list) of [`AnimationEffect`](https://drafts.csswg.org/web-animations-1/#animationeffect) objects,

 : Let `effect` be a new
 [`WorkletGroupEffect`](#workletgroupeffect) with its children set to `effects`.

 Otherwise,

 : Let `effect` be undefined.

7. Let `serializedOptions` be the result of
 [StructuredSerialize](http://w3c.github.io/html/infrastructure.html#structuredserialize)(`options`). Rethrow any exceptions.

8. Set the [serialized
 options](#serialized-options) of `workletAnimation` to
 `serializedOptions`.

9. Set the [animation animator
 name](#animation-animator-name) of `workletAnimation` to
 `animatorName`.

10. Run the procedure to [set the target effect of an
 animation](https://drafts.csswg.org/web-animations#set-the-target-effect-of-an-animation) on `workletAnimation` passing
 `effect` as the new effect. Note that this may trigger
 action to [set animator instance of worklet
 animation](#set-animator-instance-of-worklet-animation). See [§ 5.4 Web Animations
 Overrides](#web-animation-overrides) for more details.

### 5.3. Worklet Animation Timing and Sync Model

This section describes how [worklet
animation's](#worklet-animation) timing model differs from other
[animations](https://drafts.csswg.org/web-animations#concept-animation).

As described in [§ 5.1 Worklet Animation](#worklet-animation-desc), the
[worklet animation's](#worklet-animation) [current
time](https://drafts.csswg.org/web-animations#current-time) does not determine its [animation
effect's](https://drafts.csswg.org/web-animations#animation-effect) [local
time](https://drafts.csswg.org/web-animations#local-time). Instead the associated [animator
instance](#animator-instance) controls the animation effect's [local
time](https://drafts.csswg.org/web-animations#local-time) directly. This means that the animation effect's local
time is controlled from a
[`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope) which may be in a parallel execution context.

Here are a few implications of the above semantics:

- Setting the [current
 time](https://drafts.csswg.org/web-animations#current-time) or [start
 time](https://drafts.csswg.org/web-animations-1/#animation-start-time) of a [worklet
 animation](#worklet-animation) does not necessarily change its output, but may
 change the animation [play
 state](https://drafts.csswg.org/web-animations#play-state).

- Similarly, invoking
 [`finish()`](https://drafts.csswg.org/web-animations-1/#dom-animation-finish) or updating a [worklet
 animation's](#worklet-animation) [playback
 rate](https://drafts.csswg.org/web-animations#playback-rate) does not necessarily change its output, but may
 change the animation [play
 state](https://drafts.csswg.org/web-animations#play-state)

- Querying the animation effect's local time using
 [`getComputedTiming()`](https://drafts.csswg.org/web-animations-2/#dom-animationeffect-getcomputedtiming) may return stale information, in the case where the
 [animator instance](#animator-instance) is running in a parallel execution context.

If a Worklet Animation animation is executing in a parallel worklet
execution context, the last known state of its Animator Effects should
be periodically synced back to the main javascript execution context.
The synchronization of [effect
values](https://drafts.csswg.org/web-animations#effect-value) from the parallel worklet execution context to the main
javascript execution context *must* occur before [running the animation
frame
callbacks](https://html.spec.whatwg.org/#run-the-animation-frame-callbacks) as part of the document lifecycle.

Note that due to the asynchronous nature of this animation model a
script running in the main javascript execution context may see a stale
value when reading a [target
property](https://drafts.csswg.org/web-animations#target-property) that is being animated by a Worklet Animation, compared
to the value currently being used to produce the visual frame that is
visible to the user. This is similar to the effect of asynchronous
scrolling when reading scroll offsets in the main javascript execution
context.

To [sync local times to document] for a given
`workletGlobalScope` the user agent *must* perform the action
that corresponds to the first matching condition from the following:

If the `workletGlobalScope` is not running in a parallel execution context

: perform the following steps immediately:

If the `workletGlobalScope` is running in a parallel execution context

: [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps before [running the
 animation frame
 callbacks](https://html.spec.whatwg.org/#run-the-animation-frame-callbacks) as part of the document lifecycle:

1. Iterate over all [animator
 instance](#animator-instance)s in the animation worklet's global scope [animator
 instance
 set](#animator-instance-set). For each such `animator` perform the
 following steps:

 1. If `animator`'s [sync requested
 flag](#sync-requested-flag) is **false** skip the rest of the steps.

 2. Let `animatorEffect` be `animator`'s
 [effect](#effect).

 3. Let `effect` be `animatorEffect`'s
 [corresponding
 effect](#corresponding-effect).

 4. Set `effect`'s local time to
 `animatorEffect`'s local time.

 5. Set `animator`'s [sync requested
 flag](#sync-requested-flag) to **false**.

To [sync animation timings to
worklet] for a given `workletAnimation`
the user agent *must* perform the following steps:

1. If `workletAnimation` does not have a [corresponding
 animator
 instance](#corresponding-animator-instance), abort the following steps.

2. Let `animator` be `workletAnimation`'s
 [corresponding animator
 instance](#corresponding-animator-instance).

3. Let `workletGlobalScope` be the
 [`AnimationWorkletGlobalScope`](#animationworkletglobalscope) associated with `workletAnimation`.

4.

 If the `workletGlobalScope` is not running in a parallel execution context

 : perform the following steps immediately.

 If the `workletGlobalScope` is running in a parallel execution context

 : [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Set `animator`'s [animator current
 time](#animator-current-time) to `workletAnimation`'s [current
 time](https://drafts.csswg.org/web-animations#current-time)

 2. Let `animatorEffect` be `animator`'s
 [effect](#effect).

 3. Let `effect` be `animatorEffect`'s
 [corresponding
 effect](#corresponding-effect).

 4. Set the following properties on `animatorEffect`
 to be the same as `effect`:

 - [start
 delay](https://drafts.csswg.org/web-animations#start-delay),

 - [end
 delay](https://drafts.csswg.org/web-animations#end-delay),

 - [fill
 mode](https://drafts.csswg.org/web-animations#fill-mode),

 - [iteration
 start](https://drafts.csswg.org/web-animations#iteration-start),

 - [iteration
 count](https://drafts.csswg.org/web-animations#iteration-count),

 - [iteration
 duration](https://drafts.csswg.org/web-animations#iteration-duration),

 - [playback
 direction](https://drafts.csswg.org/web-animations#playback-direction), and

 - [timing
 function](https://drafts.csswg.org/web-animations#timing-function).

 Notice that the local time is **not** synced from the
document to animation worklet.

Come with appropriate mechanism's for
[animator instance](#animator-instance) to get notified when its animation currentTime is
changing e.g., via reverse(), finish() or playbackRate change. So that
it can react appropriately. [\[Issue
#811\]](https://github.com/w3c/css-houdini-drafts/issues/811)

### 5.4. Web Animations Overrides

In addition to the existing conditions on when the
[animation](https://drafts.csswg.org/web-animations#concept-animation) is considered
[ready](https://drafts.csswg.org/web-animations#ready), a [worklet
animation](#worklet-animation) is only considered
[ready](https://drafts.csswg.org/web-animations#ready) when the following condition is also true:

- the user agent has completed any setup required to create the [worklet
 animation's](#worklet-animation) [corresponding animator
 instance](#corresponding-animator-instance).

When a given worklet animation's [play
state](https://drafts.csswg.org/web-animations#play-state) changes from
[idle](https://drafts.csswg.org/web-animations#idle) to
[finished](https://drafts.csswg.org/web-animations#finished),
[running](https://drafts.csswg.org/web-animations#running), or
[paused](https://drafts.csswg.org/web-animations#paused), run the procedure to [associate animator instance of
worklet
animation](#associate-animator-instance-of-worklet-animation) given the worket animation as
`workletAnimation`.

When a given worklet animation's [play
state](https://drafts.csswg.org/web-animations#play-state) changes from
[finished](https://drafts.csswg.org/web-animations#finished),
[running](https://drafts.csswg.org/web-animations#running) or
[paused](https://drafts.csswg.org/web-animations#paused) to
[idle](https://drafts.csswg.org/web-animations#idle), run the procedure to [disassociate animator instance
of worklet
animation](#disassociate-animator-instance-of-worklet-animation)given the worklet animation as
`workletAnimation`.

When a given worklet animation's [replace
state](https://drafts.csswg.org/web-animations#replace-state) changes from
[active](https://drafts.csswg.org/web-animations#active) to either
[persisted](https://drafts.csswg.org/web-animations#persisted) or
[removed](https://drafts.csswg.org/web-animations#removed) run the procedure to [disassociate animator instance of
worklet
animation](#disassociate-animator-instance-of-worklet-animation) given the worklet animation as
`workletAnimation`.

In web-animation play state is updated
before the actual change in particular some operations such as play()
are asynchronous. We should really invoke these Animator related
operation after the appropriate animation operation is complete instead
of when play state has changed. This will require either finding (or
introducing) q new hook in web animation or having override for each
such async operation.

When the procedure to [set the target effect of an
animation](https://drafts.csswg.org/web-animations#set-the-target-effect-of-an-animation) for a given worklet animation is called, then [set
animator instance of worklet
animation](#set-animator-instance-of-worklet-animation) given the worklet animation as
`workletAnimation`.

When the procedure to [set the timeline of an
animation](https://drafts.csswg.org/web-animations#set-the-timeline-of-an-animation) for a given `workletAnimation` is called,
then [set animator instance of worklet
animation](#set-animator-instance-of-worklet-animation) given the worklet animation as
`workletAnimation`.

When the procedure to [set the current
time](https://drafts.csswg.org/web-animations#set-the-current-time) or [set the start
time](https://drafts.csswg.org/web-animations#set-the-start-time) for a given worklet animation is called, then [sync
animation timings to
worklet](#sync-animation-timings-to-worklet) given the worklet animation as
`workletAnimation`.

When the procedure to [update the timing properties of an animation
effect](https://drafts.csswg.org/web-animations#update-the-timing-properties-of-an-animation-effect) for a given effect is called and that effect is owned
be a worklet animation, then [sync animation timings to
worklet](#sync-animation-timings-to-worklet) given that worklet animation as
`workletAnimation`.

To [associate animator instance of worklet
animation] given
`workletAnimation`, the user agent *must* run the following
steps:

1. If `workletAnimation` has a [corresponding animator
 instance](#corresponding-animator-instance), abort the following steps.

2. Let `workletGlobalScope` be the
 [`AnimationWorkletGlobalScope`](#animationworkletglobalscope) associated with `workletAnimation`.

3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on `workletGlobalScope` to run the
 procedure to [create a new animator
 instance](#create-a-new-animator-instance), passing:

 - The `workletAnimation`'s [animation animator
 name](#animation-animator-name) as name.

 - The `workletAnimation`'s
 [timeline](https://drafts.csswg.org/web-animations#timeline) as timeline.

 - The `workletAnimation`'s [animation
 effect](https://drafts.csswg.org/web-animations#animation-effect) as effect.

 - The `workletAnimation`'s [serialized
 options](#serialized-options) as options.

 - The `workletGlobalScope` as workletGlobalScope.

4. If the procedure was successful, set the resulting [animator
 instance](#animator-instance) to be the [corresponding animator
 instance](#corresponding-animator-instance) of `workletAnimation`.

To [disassociate animator instance of worklet
animation] given
`workletAnimation`, the user age *must* run the following
steps:

1. If `workletAnimation` does not have a [corresponding
 animator
 instance](#corresponding-animator-instance), abort the following steps.

2. Let `workletGlobalScope` be the
 [`AnimationWorkletGlobalScope`](#animationworkletglobalscope) associated with `workletAnimation`.

3. Let `animatorInstance` be `workletAnimation`'s
 [corresponding animator
 instance](#corresponding-animator-instance).

4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the `workletGlobalScope` to run the
 procedure to [remove an animator
 instance](#remove-an-animator-instance), passing `animatorInstance` as instance
 and `workletGlobalScope` as workletGlobalScope.

5. Set `workletAnimation`'s [corresponding animator
 instance](#corresponding-animator-instance) as undefined.

To [set animator instance of worklet
animation] given `workletAnimation`, the
user agent *must* run the following steps:

1. [disassociate animator instance of worklet
 animation](#disassociate-animator-instance-of-worklet-animation) given `workletAnimation`.

2. [associate animator instance of worklet
 animation](#associate-animator-instance-of-worklet-animation) given `workletAnimation`.

### 5.5. Effect Stack and Composite Order

As with other animations, [worklet
animations](#worklet-animation) participate in the [effect
stack](https://drafts.csswg.org/web-animations#effect-stack). A worklet animation does not have a specific
[animation
class](https://drafts.csswg.org/web-animations#animation-class) which means it has the same composite order as other
Javascript created web animations.

## 6. Additional Related Concepts

### 6.1. Worklet Group Effect

*This section is not normative.*

[Group
effect](https://w3c.github.io/web-animations/level-2/#group-effect) is a type of [animation
effect](https://drafts.csswg.org/web-animations#animation-effect) that enbales multiple child animation effects to be
animated together as a group.

[`WorkletGroupEffect`](#workletgroupeffect) is a type of [group
effect](https://w3c.github.io/web-animations/level-2/#group-effect) that allows its [child
effect's](https://w3c.github.io/web-animations/level-2/#child-effect) [local
times](https://drafts.csswg.org/web-animations#local-time) to be mutated individually.

When a
[`WorkletGroupEffect`](#workletgroupeffect) is set as the [animation
effect](https://drafts.csswg.org/web-animations#animation-effect) of a [worklet
animation](#worklet-animation), its [corresponding animator
instance](#corresponding-animator-instance) can directly control the [child
effects](https://w3c.github.io/web-animations/level-2/#child-effect)\' [local
times](https://drafts.csswg.org/web-animations#local-time). This allows a single worklet animation to coordinate
multiple effects - see [§ 9.2 Example 2: Twitter header.](#example-2)
for an example of such a use-case.

```
[Exposed=AnimationWorklet]
interface WorkletGroupEffect {
 sequence<WorkletAnimationEffect> getChildren();
};
```

The above interface exposes a
conservative subset of GroupEffect proposed as part of web-animation-2.
We should instead move this into a delta spec against the web-animation.
[\[w3c/csswg-drafts Issue
#2071\]](https://github.com/w3c/csswg-drafts/issues/2071)

 Group Effect is currently an experimental feature and
not well specified in web animations. So the concept of
[`WorkletGroupEffect`](#workletgroupeffect) may change dramatically as [Group
Effect](https://w3c.github.io/web-animations/level-2/#group-effect) get specified. See
https://github.com/yi-gu/group_effect/blob/master/README.md for more
details.

### 6.2. ScrollTimeline

*This section is not normative.*

[`ScrollTimeline`](https://wicg.github.io/scroll-animations/#scrolltimeline) is a new concept being proposed for addition to web
animation API. It defines an animation timeline whose time value depends
on the scroll position of a scroll container. [Worklet
animations](#worklet-animation) can have a scroll timeline and thus drive their
scripted effects based on a scroll offset.

 **Access to input**: We are interested on exposing
additional user input beside scrolling (e.g., touch/pointer input) to
these animations so that authors can create jank-free input driven
animations which are not really possible today. We are still trying to
figure out the right abstractions and mechanisms to do this.

## 7. Security Considerations

There are no known security issues introduced by these features.

## 8. Privacy Considerations

There are no known privacy issues introduced by these features.

## 9. Examples

### 9.1. Example 1: Spring timing.

Here we use Animation Worklet to create animation with a custom spring
timing.

```
<div id='target'></div>

<script>
await CSS.animationWorklet.addModule('spring-animator.js');
targetEl = document.getElementById('target');

const effect = new KeyframeEffect(
 targetEl,
 {transform: ['translateX(0)', 'translateX(50vw)']},
 {duration: 1000}
);
const animation = new WorkletAnimation('spring', effect, document.timeline, {k: 2, ratio: 0.7});
animation.play();
</script>
```

```
registerAnimator('spring', class SpringAnimator {
 constructor(options = {k: 1, ratio: 0.5}) {
 this.timing = createSpring(options.k, options.ratio);
 }

 animate(currentTime, effect) {
 let delta = this.timing(currentTime);
 // scale this by target duration
 delta = delta * (effect.getTimings().duration / 2);
 effect.localTime = delta;
 // TODO: Provide a method for animate to mark animation as finished once
 // spring simulation is complete, e.g., this.finish()
 // See issue https://github.com/w3c/css-houdini-drafts/issues/808
 }
});

function createSpring(springConstant, ratio) {
 // Normalize mass and distance to 1 and assume a reasonable init velocit
 // but these can also become options to this animator.
 const velocity = 0.2;
 const mass = 1;
 const distance = 1;

 // Keep ratio < 1 to ensure it is under-damped.
 ratio = Math.min(ratio, 1 - 1e-5);

 const damping = ratio * 2.0 * Math.sqrt(springConstant);
 const w = Math.sqrt(4.0 * springConstant - damping * damping) / (2.0 * mass);
 const r = -(damping / 2.0);
 const c1 = distance;
 const c2 = (velocity - r * distance) / w;

 // return a value in [0..distance]
 return function springTiming(timeMs) {
 const time = timeMs / 1000; // in seconds
 const result = Math.pow(Math.E, r * time) *
 (c1 * Math.cos(w * time) + c2 * Math.sin(w * time));
 return distance - result;
 }
}
```

### 9.2. Example 2: Twitter header.

An example of twitter profile header effect where two elements (avatar,
and header) are updated in sync with scroll offset with an additional
feature where avatar can have additional physic based movement based on
the velocity and acceleration of the scrolling.

```
<div id='scrollingContainer'>
 <div id='header' style='height: 150px'></div>
 <div id='avatar'><img></div>
</div>

// In document scope.
<script>
const headerEl = document.getElementById('header');
const avatarEl = document.getElementById('avatar');
const scrollingContainerEl = document.getElementById('scrollingContainer');

const scrollTimeline = new ScrollTimeline({
 scrollSource: scrollingContainerEl,
 orientation: 'block',
 timeRange: 1000,
 startScrollOffset: 0,
 endScrollOffset: headerEl.clientHeight
});

const effects = [
 /* avatar scales down as we scroll up */
 new KeyframeEffect(avatarEl,
 {transform: ['scale(1)', 'scale(0.5)']},
 {duration: scrollTimeline.timeRange}),
 /* header loses transparency as we scroll up */
 new KeyframeEffect(headerEl,
 {opacity: [0, 0.8]},
 {duration: scrollTimeline.timeRange})
];

await CSS.animationWorklet.addModule('twitter-header-animator.js');
const animation = new WorkletAnimation('twitter-header', effects, scrollTimeline);

animation.play();
</script>
```

```
// Inside AnimationWorkletGlobalScope.
registerAnimator('twitter-header', class HeaderAnimator {
 constructor(options, state = {velocity: 0, acceleration: 0}) {
 // `state` is either undefined (first time) or it is the previous state (after an animator
 // is migrated between global scopes).
 this.velocity = state.velocity;
 this.acceleration = state.acceleration;
 }

 animate(currentTime, effect) {
 const scroll = currentTime; // scroll is in [0, 1000] range

 if (this.prevScroll) {
 this.velocity = scroll - this.prevScroll;
 this.acceleration = this.velocity - this.prevVelocity;
 }
 this.prevScroll = scroll;
 this.prevVelocity = velocity;

 // Drive the output group effect by setting its children local times individually.
 effect.children[0].localTime = scroll;

 effect.children[1].localTime = curve(velocity, acceleration, scroll);
 }

 state() {
 // Invoked before any migration attempts. The returned object must be structure clonable
 // and will be passed to constructor to help animator restore its state after migration to the
 // new scope.
 return {
 this.velocity,
 this.acceleration
 }
 }

});

curve(scroll, velocity, acceleration) {

 return /* compute an return a physical movement curve based on scroll position, and per frame
 velocity and acceleration. */ ;
}
```

### 9.3. Example 3: Parallax backgrounds.

A simple parallax background example.

```
<style>
.parallax {
 position: fixed;
 top: 0;
 left: 0;
 opacity: 0.5;
}
</style>
<div id='scrollingContainer'>
 <div id="slow" class="parallax"></div>
 <div id="fast" class="parallax"></div>
</div>

<script>
await CSS.animationWorklet.addModule('parallax-animator.js');

const parallaxSlowEl = document.getElementById('slow');
const parallaxFastEl = document.getElementById('fast');
const scrollingContainerEl = document.getElementById('scrollingContainer');

const scrollTimeline = new ScrollTimeline({
 scrollSource: scrollingContainerEl,
 orientation: 'block',
 timeRange: 1000
});
const scrollRange = scrollingContainerEl.scrollHeight - scrollingContainerEl.clientHeight;

const slowParallax = new WorkletAnimation(
 'parallax',
 new KeyframeEffect(parallaxSlowEl,
 {'transform': ['translateY(0)', 'translateY(' + -scrollRange + 'px)']},
 {duration: scrollTimeline.timeRange}),
 scrollTimeline,
 {rate : 0.4}
);
slowParallax.play();

const fastParallax = new WorkletAnimation(
 'parallax',
 new KeyframeEffect(parallaxFastEl,
 {'transform': ['translateY(0)', 'translateY(' + -scrollRange + 'px)']},
 {duration: scrollTimeline.timeRange}),
 scrollTimeline,
 {rate : 0.8}
);
fastParallax.play();
</script>
```

```
// Inside AnimationWorkletGlobalScope.
registerAnimator('parallax', class ParallaxAnimator {
 constructor(options) {
 this.rate_ = options.rate;
 }

 animate(currentTime, effect) {
 effect.localTime = currentTime * this.rate_;
 }
});
```
