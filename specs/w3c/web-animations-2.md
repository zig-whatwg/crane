## 1. Delta specification

This is a delta specification, meaning that it currently contains only
the differences from Web Animations Level 1
[\[WEB-ANIMATIONS-1\]](#biblio-web-animations-1 "Web Animations").
Once the Level 1 specification is closer to complete, it will be merged
with the additions here into a complete level 2 specification.

## 2. Timing model

This section describes and defines the behavior of the Web Animations
timing model.

### 2.1. Timing model overview

::: informative-bg
*This section is non-normative*

#### 2.1.1. Hierarchical

This level of the specification includes an updated timing hierarchy
diagram.

![A hierarchy of timing nodes. Each node in the tree derives its time
from its parent
node.](images/time-hierarchy.svg){a
width="600"}

Along with the following updated description:

> A consequence of this hierarchical arrangement is that complex
> animation arrangements can be reversed, scheduled, accelerated and so
> on as a whole unit since the manipulations applied to the parent,
> cascade down to its [descendants](#descendant). Furthermore, since time has a common source, it is
> easy to synchronize animations.

### 2.2. Timelines

Add:

> The [duration] of a timeline gives the maximum
> value a timeline may generate for its current time. This value is used
> to calculate the [intrinsic iteration
> duration](#intrinsic-iteration-duration) for the target effect of an animation that is
> associated with the timeline when the effect's [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) is \"auto\". The value is computed such that the
> effect fills the available time. For a monotonic timeline, there is no
> upper bound on current time, and [timeline
> duration](#timeline-duration) is unresolved. For a non-monotonic (e.g. scroll)
> timeline, the duration has a fixed upper bound. In this case, the
> timeline is a [progress-based timeline],
> and its [timeline duration] is 100%.
>
> [minimum timeline time]
>
> For a [progress-based
> timeline](#progress-based-timeline), the minimum timeline time is the minimum value that
> can be produced for the timeline. For a [monotonically increasing
> timeline](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline), minimum timeline time is -infinity.
>
> [maximum timeline time]
>
> For a [progress-based
> timeline](#progress-based-timeline), the maximum timeline time is the maximum possible
> value producible for timeline time, and matches the [timeline
> duration](#timeline-duration). For a [monotonically increasing
> timeline](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline). it is +infinity.
>
> The minimum and maximum values will be the values
> associated with the minimum and maximum scroll offsets, respectively,
> when using a scroll timeline.

### 2.3. Animations

Append:

> Animation effects associated with a [progress-based
> timeline](#progress-based-timeline) require their timing properties to be converted to
> proportions. The procedure for converting a
> is as follows:
>
> 1. If the [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) is auto, then perform the following steps.
>
> - Set [start delay](#start-delay) and [end
> delay](https://drafts.csswg.org/web-animations-1/#end-delay) to 0, as it is not possible to mix time and
> proportions.
>
> Future versions may allow these properties to
> be assigned percentages, at which point the delays are only to
> be ignored if their values are expressed as times and not as
> percentages.
>
> Otherwise:
>
> 1. Let `total time` be equal to [end
> time](#end-time)
>
> 2. Set [start delay](#start-delay) to be the result of evaluating
> `specified start delay`` / ``total time`` * ``timeline duration`.
>
> 3. Set [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) to be the result of evaluating
> `specified iteration duration`` / ``total time`` * ``timeline duration`.
>
> 4. Set [end
> delay](https://drafts.csswg.org/web-animations-1/#end-delay) to be the result of evaluating
> `specified end delay`` / ``total time`` * ``timeline duration`.
>
> The procedure to [normalize specified
> timing] is as follows:
>
> If [timeline duration](#timeline-duration) is resolved:
>
> - Follow the procedure to convert a [time-based animation to a
> proportional
> animation](#time-based-animation-to-a-proportional-animation)
>
> Otherwise:
>
> 1. Set [start delay](#start-delay) = `specified start delay`
>
> 2. Set [end
> delay](https://drafts.csswg.org/web-animations-1/#end-delay) = `specified end delay`
>
> 3. If [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) is auto:
>
> - Set [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) = [intrinsic iteration
> duration](#intrinsic-iteration-duration)
>
> Otherwise:
>
> - Set [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) = `specified iteration duration`

#### 2.3.1. Setting the timeline of an animation

The procedure to [set the timeline of an
animation], `animation`,
to `new timeline` which may be null, is as follows:

1. Let `old timeline` be the current
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) of `animation`, if any.

2. If `new timeline` is the same object as
 `old timeline`, abort this procedure.

3. Let `previous play state` be `animation`'s
 [play
 state](https://www.w3.org/TR/web-animations-1/#animation-play-state).

4. Let `previous current time` be the
 `animation`'s [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time).

5. Set `previous progress` based in the first condition that
 applies:

 If `previous current time` is unresolved:

 : Set `previous progress` to unresolved.

 If [end time](#end-time) is zero:

 : Set `previous progress` to zero.

 Otherwise

 : Set `previous progress` =
 `previous current time`` / `[`end time`](#end-time)

6. Let `from finite timeline` be true if
 `old timeline` is not null and not [monotonically
 increasing](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline).

7. Let `to finite timeline` be true if `timeline`
 is not null and not [monotonically
 increasing](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline).

8. Let the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) of `animation` be
 `new timeline`.

9. Perform the steps corresponding to the *first* matching condition
 from the following, if any:

 If `to finite timeline`,

 : 1. [Apply any pending playback
 rate](https://drafts.csswg.org/web-animations-1/#apply-any-pending-playback-rate) on `animation`

 2. set `auto align start time` to true.

 3. Set [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) to unresolved.

 4. Set [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to unresolved.

 5. If `previous play state` is \"finished\" or
 \"running\"

 1. Schedule a [pending play
 task](#pending-play-task)

 6. If `previous play state` is \"paused\" and
 `previous progress` is resolved:

 1. Set [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `previous progress` \*
 [end time](#end-time).

 This step ensures that `previous progress` is
 preserved even in the case of a pause-pending animation with a
 resolved [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time).

 If `from finite timeline` and `previous progress` is resolved,

 : Run the procedure to [set the current
 time](#set-the-current-time) to `previous progress` \* [end
 time](#end-time).

10. If the [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) of `animation` is
 [resolved](https://drafts.csswg.org/web-animations-1/#unresolved), make `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) [unresolved].

 This step ensures that the [finished play
 state](https://www.w3.org/TR/web-animations-1/#play-state-finished) of `animation` is not "sticky" but is
 re-evaluated based on its updated [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time).

11. Run the procedure to [update an animation's finished
 state](https://drafts.csswg.org/web-animations-1/#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

[Issue: If `new timeline` is null, we should ensure that
[custom effects](#custom-effect)
get called with an
[unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [iteration
progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) (unless a subsequent change in the same script
execution context makes this redundant).]

#### 2.3.2. Setting the target effect of an animation

After the step to reschedule a [pending play
task](#pending-play-task)
add the following step:

> 1. If `new effect` is not `null` and if
> `new effect` has a [parent
> group](#parent-group),
> [remove](#remove-an-animation-effect) `new effect` from its [parent
> group].

After the step to assign `new effect` as
`animation`'s [associated
effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) include the following step:

> 1. If `old effect` is not `null`, queue a task to call any
> [custom effects](#custom-effect) associated with [inclusive
> descendants](#inclusive-descendant) of `old effect` with an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [iteration
> progress](https://drafts.csswg.org/web-animations-1/#iteration-progress).
>
> :::
> (#issue-ddad0532) This is not quite right. If
> `old effect` is attached to another animation in the
> same task then we should probably not do an extra callback with
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).
> The definition of when [custom
> effects](#custom-effect)
> gets called needs to be audited and probably rewritten.
> :::

#### 2.3.3. Waiting for the associated effect

Replace:

> An animation is ready at the first moment where *both* of the
> following conditions are true:
>
> - the user agent has completed any setup required to begin the
> playback of the animation's [associated
> effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect), including rendering the first frame of any
> [keyframe
> effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect).
>
> - the animation is associated with a
> [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that is not
> [inactive](https://www.w3.org/TR/web-animations-1/#inactive-timeline).

With:

> An animation is [ready] at the first moment where *all* of the following
> conditions are true:
>
> - the user agent has completed any setup required to begin the
> playback of each [inclusive
> descendant](#inclusive-descendant) of the animation's [associated
> effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) including rendering the first frame of any
> [keyframe
> effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect) [or executing any [custom
> effects](#custom-effect)
> associated with an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect)] .
>
> - the animation is associated with a
> [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that is not
> [inactive](https://www.w3.org/TR/web-animations-1/#inactive-timeline).
>
> - the animation's [hold
> time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) or [start
> time](https://www.w3.org/TR/web-animations-1/#animation-start-time) is resolved.

 an animation is not [ready](#ready) while it has no [start
time](https://www.w3.org/TR/web-animations-1/#animation-start-time) or [hold
time](https://www.w3.org/TR/web-animations-1/#animation-hold-time). For a [scroll-driven
animation](https://www.w3.org/TR/scroll-animations-1/#scroll-driven-animations), the start-time is determined when [updating the
timeline](https://drafts.csswg.org/scroll-animations-1/#event-loop) if `auto align start time` is true.

#### 2.3.4. Validating a CSSNumberish time

The procedure to [validate a CSSNumberish
time] for an input value of `time` is based on the
first condition that matches:

If *all* of the following conditions are true:

- The animation is associated with a [progress-based
 timeline](#progress-based-timeline), and

- `time` is not a
 [`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue) with percent units:

[throw](https://webidl.spec.whatwg.org/#dfn-throw) a [TypeError].

return false;

If *all* of the following conditions are true:

- The animation is not associated with a [progress-based
 timeline](#progress-based-timeline), and

- `time` is a CSSNumericValue, and

- the units of time are not [duration
 units](https://www.w3.org/TR/css-values-4/#time-value):

[throw](https://webidl.spec.whatwg.org/#dfn-throw) a [TypeError].

return false.

Otherwise

return true.

#### 2.3.5. Setting the current time of an Animation

The [current
time](https://www.w3.org/TR/web-animations-1/#animation-current-time) of an animation can be set to a new value to *seek* the
animation. The procedure for setting the current time is defined in two
parts.

The procedure to [silently set the current
time] of an animation, `animation`, to
`seek time` is as follows:

1. If `seek time` is an
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) time value, then perform the following steps.

 1. If the [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is
 [resolved](https://drafts.csswg.org/web-animations-1/#unresolved), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [TypeError].

 2. Abort these steps.

2. Let `valid seek time` be the result of running the
 [validate a CSSNumberish
 time](#validate-a-cssnumberish-time) procedure with `seek time` as the input.

3. If `valid seek time` is false, abort this procedure.

4. Set `auto align start time` to false.

5. Update either `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) or [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) as follows:

 If *any* of the following conditions are true:

 - `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) is
 [resolved](https://drafts.csswg.org/web-animations-1/#unresolved), or

 - `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), or

 - `animation` has no associated
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) or the associated [timeline]
 is
 [inactive](https://www.w3.org/TR/web-animations-1/#inactive-timeline), or

 - `animation`'s [playback
 rate](#animation-effect-playback-rate) is 0,

 1. Set `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `seek time`.

 Otherwise,

 Set `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) to the result of evaluating
 `timeline time`` - (``seek time`` / `[`playback rate`](#animation-effect-playback-rate)`)` where `timeline time` is the current
 [time
 value](https://drafts.csswg.org/web-animations-1/#time-value) of
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) associated with `animation`.

6. If `animation` has no associated
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) or the associated [timeline] is
 [inactive](https://www.w3.org/TR/web-animations-1/#inactive-timeline), make `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time)
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

 This preserves the invariant that when we don't have an active
 timeline it is only possible to set *either* the [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) *or* the animation's [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time).

7. Make
 [animation](https://drafts.csswg.org/web-animations-1/#animation)'s `previous current time`
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

The procedure to [set the current time] of an animation,
`animation`, to `seek time` is as follows:

1. Run the steps to [silently set the current
 time](#silently-set-the-current-time) of `animation` to
 `seek time`.

2. If `animation` has a [pending pause
 task](https://drafts.csswg.org/web-animations-1/#pending-pause-task), synchronously complete the pause operation by
 performing the following steps:

 1. Set `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `seek time`.

 2. [Apply any pending playback
 rate](https://drafts.csswg.org/web-animations-1/#apply-any-pending-playback-rate) to `animation`.

 3. Make `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time)
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

 4. Cancel the [pending pause
 task](https://drafts.csswg.org/web-animations-1/#pending-pause-task).

 5. [Resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s [current ready
 promise](https://drafts.csswg.org/web-animations-1/#current-ready-promise) with `animation`.

3. Run the procedure to [update an animation's finished
 state](https://drafts.csswg.org/web-animations-1/#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to true, and the
 `synchronously notify` flag set to false.

#### 2.3.6. Setting the start time of an Animation

The procedure to [set the start time] of
[animation](https://drafts.csswg.org/web-animations-1/#animation), `animation`, to
`new start time`, is as follows:

1. Let `valid start time` be the result of running the
 [validate a CSSNumberish
 time](#validate-a-cssnumberish-time) procedure with `new start time` as the
 input.

2. If `valid start time` is false, abort this procedure.

3. Set `auto align start time` to false.

4. Let `timeline time` be the current [time
 value](https://drafts.csswg.org/web-animations-1/#time-value) of the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that `animation` is associated with. If
 there is no [timeline] associated with
 `animation` or the associated timeline is
 [inactive](https://www.w3.org/TR/web-animations-1/#inactive-timeline), let the `timeline time` be
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

5. If `timeline time` is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) and `new start time` is
 [resolved], make `animation`'s
 [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) [unresolved].

 This preserves the invariant that when we don't have an active
 timeline it is only possible to set *either* the [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) *or* the animation's [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time).

6. Let `previous current time` be `animation`'s
 [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time).

 This is the [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time) after applying the changes from the previous step
 which may cause the [current time]
 to become
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

7. [Apply any pending playback
 rate](https://drafts.csswg.org/web-animations-1/#apply-any-pending-playback-rate) on `animation`.

8. Set `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) to `new start time`.

9. Update `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) based on the first matching condition from the
 following,

 If `new start time` is [resolved](https://drafts.csswg.org/web-animations-1/#unresolved),

 : If `animation`'s [playback
 rate](#animation-effect-playback-rate) is not zero, make `animation`'s
 [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time)
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

 Otherwise (`new start time` is [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved)),

 : 1. Set `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `previous current time` even
 if `previous current time` is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

10. If `animation` has a [pending play
 task](#pending-play-task) or a [pending pause
 task](https://drafts.csswg.org/web-animations-1/#pending-pause-task), cancel that task and
 [resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s [current ready
 promise](https://drafts.csswg.org/web-animations-1/#current-ready-promise) with `animation`.

11. Run the procedure to [update an animation's finished
 state](https://drafts.csswg.org/web-animations-1/#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to true, and the
 `synchronously notify` flag set to false.

#### 2.3.7. Playing an animation

The procedure to [play an animation], `animation`, given
a flag `auto-rewind`, is as follows:

 The `auto-rewind` flag is provided for other
specifications that build on this model but do not require the rewinding
behavior, such as CSS Animations
[\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1").

1. Let `aborted pause` be a boolean flag that is true if
 `animation` has a [pending pause
 task](https://drafts.csswg.org/web-animations-1/#pending-pause-task), and false otherwise.

2. Let `has pending ready promise` be a boolean flag that is
 initially false.

3. Let `has finite timeline` be true if
 `animation` has an associated
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that is not [monotonically
 increasing](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline).

4. Let `previous current time` be the
 `animation`'s [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time)

5. Let `enable seek` be true if the `auto-rewind`
 flag is true and `has finite timeline` is false.
 Otherwise, initialize to false.

6. Perform the steps corresponding to the *first* matching condition
 from the following, if any:

 If `animation`'s [effective playback
 rate](https://drafts.csswg.org/web-animations-1/#effective-playback-rate) \> 0, `enable seek` is true and *either*
 `animation`'s:

 - `previous current time` is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), or

 - `previous current time` \< zero, or

 - `previous current time` ≥ [associated effect
 end](https://drafts.csswg.org/web-animations-1/#associated-effect-end),

 Set the `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to zero.

 If `animation`'s [effective playback
 rate](https://drafts.csswg.org/web-animations-1/#effective-playback-rate) \< 0, `enable seek` is true and *either*
 `animation`'s:

 - `previous current time` is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), or

 - `previous current time` ≤ zero, or

 - `previous current time` \> [associated effect
 end](https://drafts.csswg.org/web-animations-1/#associated-effect-end),

 If [associated effect end](https://drafts.csswg.org/web-animations-1/#associated-effect-end) is positive infinity,

 : [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 Otherwise,

 : Set the `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to the `animation`'s [associated
 effect
 end](https://drafts.csswg.org/web-animations-1/#associated-effect-end).

 If `animation`'s [effective playback
 rate](https://drafts.csswg.org/web-animations-1/#effective-playback-rate) = 0 and `animation`'s [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved),

 Set the `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to zero.

7. If `has finite timeline` and `auto-rewind` is
 true:

 1. Set the flag `auto align start time` to true.

 2. Set the `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `previous current time`.

 If play is called for a CSS animation during style
 update, the `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) cannot be reliably calculated until post layout
 since the start time is to align with the start or end of the
 animation range (depending on the [playback
 rate](#animation-effect-playback-rate)). In this case, the animation is said to have an
 [auto-aligned start time], whereby the start time is
 automatically adjusted as needed to align the animation's progress
 to the animation range.

8. If `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) is
 [resolved](https://drafts.csswg.org/web-animations-1/#unresolved), let its [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) be [unresolved].

9. If `animation` has a [pending play
 task](#pending-play-task) or a [pending pause
 task](https://drafts.csswg.org/web-animations-1/#pending-pause-task),

 1. Cancel that task.

 2. Set `has pending ready promise` to true.

10. If the following three conditions are *all* satisfied:

 - `animation`'s [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), and

 - `aborted pause` is false, and

 - `animation` does *not* have a [pending playback
 rate](https://drafts.csswg.org/web-animations-1/#pending-playback-rate),

 abort this procedure.

11. If `has pending ready promise` is false, let
 `animation`'s [current ready
 promise](https://drafts.csswg.org/web-animations-1/#current-ready-promise) be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in the [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) of `animation`.

12. Schedule a task to run as soon as `animation` is
 [ready](#ready). The task shall
 perform the following steps:

 1. Assert that at least one of `animation`'s [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) or [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) is
 [resolved](https://drafts.csswg.org/web-animations-1/#unresolved).

 2. Let `ready time` be the [time
 value](https://drafts.csswg.org/web-animations-1/#time-value) of the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) associated with `animation` at the
 moment when `animation` became
 [ready](#ready).

 3. Perform the steps corresponding to the first matching condition
 below, if any:

 If `animation`'s [hold time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) is [resolved](https://drafts.csswg.org/web-animations-1/#unresolved),

 : 1. [Apply any pending playback
 rate](https://drafts.csswg.org/web-animations-1/#apply-any-pending-playback-rate) on `animation`.

 2. Let `new start time` be the result of
 evaluating
 `ready time`` - `[`hold time`](https://www.w3.org/TR/web-animations-1/#animation-hold-time)` / `[`playback rate`](#animation-effect-playback-rate) for `animation`. If the
 [playback
 rate](#animation-effect-playback-rate) is zero, let
 `new start time` be simply
 `ready time`.

 3. Set the [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) of `animation` to
 `new start time`.

 4. If `animation`'s [playback
 rate](#animation-effect-playback-rate) is not 0, make `animation`'s
 [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time)
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

 If `animation`'s [start time](https://www.w3.org/TR/web-animations-1/#animation-start-time) is resolved and `animation` has a [pending playback rate](https://drafts.csswg.org/web-animations-1/#pending-playback-rate),

 : 1. Let `current time to match` be the result of
 evaluating
 `(``ready time`` - `[`start time`](https://www.w3.org/TR/web-animations-1/#animation-start-time)`) × `[`playback rate`](#animation-effect-playback-rate) for `animation`.

 2. [Apply any pending playback
 rate](https://drafts.csswg.org/web-animations-1/#apply-any-pending-playback-rate) on `animation`.

 3. If `animation`'s [playback
 rate](#animation-effect-playback-rate) is zero, let `animation`'s
 [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) be `current time to match`.

 4. Let `new start time` be the result of
 evaluating
 `ready time`` - ``current time to match`` / `[`playback rate`](#animation-effect-playback-rate) for `animation`. If the
 [playback
 rate](#animation-effect-playback-rate) is zero, let
 `new start time` be simply
 `ready time`.

 5. Set the [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) of `animation` to
 `new start time`.

 4. [Resolve](https://webidl.spec.whatwg.org/#resolve) `animation`'s [current ready
 promise](https://drafts.csswg.org/web-animations-1/#current-ready-promise) with `animation`.

 5. Run the procedure to [update an animation's finished
 state](https://drafts.csswg.org/web-animations-1/#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

 :::
 Note that the order of the above two steps is important since it
 means that an animation with zero-length [associated
 effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) will resolve its [current ready
 promise](https://drafts.csswg.org/web-animations-1/#current-ready-promise) before its [current finished
 promise](https://drafts.csswg.org/web-animations-1/#current-finished-promise).
 :::

 So long as the above task is scheduled but has yet to run,
 `animation` is described as having a [pending play
 task]. While the task is running, however,
 `animation` does *not* have a [pending play
 task](#pending-play-task).

 If a user agent determines that `animation` is
 immediately [ready](#ready), it may
 schedule the above task as a microtask such that it runs at the next
 [microtask
 checkpoint](https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint), but it must *not* perform the task synchronously.

 ::::
 The above requirement to run the [pending play
 task](#pending-play-task) asynchronously ensures that code such as the
 following behaves consistently between implementations:

 :::
 (#example-b6f05729)
 ```
 animation.play();
 animation.ready.then(
 () => { console.log('Playback commenced'); },
 () => { console.log('Playback was canceled'); }
 );
 // Suppose some condition requires playback to be canceled...
 animation.cancel();
 // "Playback was canceled" will be printed to the console.
 ```
 :::

 In the above code, were the [pending play
 task](#pending-play-task) run synchronously, the [current ready
 promise](https://drafts.csswg.org/web-animations-1/#current-ready-promise) would not be rejected.
 ::::

13. Run the procedure to [update an animation's finished
 state](https://drafts.csswg.org/web-animations-1/#update-an-animations-finished-state) for `animation` with the
 `did seek` flag set to false, and the
 `synchronously notify` flag set to false.

The procedure to [play an
animation](#play-an-animation) needs to include scheduling a task for updating [custom
effects](#custom-effect).

##### 2.3.7.1. Auto-aligning the start time

When attached to a non-monotonic timeline, the start time of the
animation may be layout dependent. In this case, we defer calculation of
the start time until the timeline has been updated post layout. When
updating timeline current time, the [start
time](https://www.w3.org/TR/web-animations-1/#animation-start-time) of any attached animation is conditionally updated. The
procedure for [calculating an auto-aligned start
time] is as
follows:

1. If the `auto-align start time` flag is false, abort this
 procedure.

2. If the timeline is inactive, abort this procedure.

3. If [play
 state](https://www.w3.org/TR/web-animations-1/#animation-play-state) is idle, abort this procedure.

4. If [play
 state](https://www.w3.org/TR/web-animations-1/#animation-play-state) is paused, and [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) is resolved, abort this procedure.

5. Let `start offset` be the resolved timeline time
 corresponding to the start of the [animation attachment
 range](https://www.w3.org/TR/scroll-animations-1/#animation-attachment-range). In the case of view timelines, it requires a
 calculation based on the proportion of the cover range.

6. Let `end offset` be the resolved timeline time
 corresponding to the end of the [animation attachment
 range](https://www.w3.org/TR/scroll-animations-1/#animation-attachment-range). In the case of view timelines, it requires a
 calculation based on the proportion of the cover range.

7. Set [start
 time](https://www.w3.org/TR/web-animations-1/#animation-start-time) to `start offset` if [effective playback
 rate](https://drafts.csswg.org/web-animations-1/#effective-playback-rate) ≥ 0, and `end offset` otherwise.

8. [Apply any pending playback
 rate](https://drafts.csswg.org/web-animations-1/#apply-any-pending-playback-rate) on `animation`.

9. Clear [hold
 time](https://www.w3.org/TR/web-animations-1/#animation-hold-time).

#### 2.3.8. Pausing an animation

The procedure to [pause an
animation](https://drafts.csswg.org/web-animations-1/#pause-an-animation) needs to refer not only to the [associated
effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) but also any descendants of the [associated
effect].

[Likewise, the procedure to [pause an
animation](https://drafts.csswg.org/web-animations-1/#pause-an-animation) needs to include scheduling a task for updating [custom
effects](#custom-effect).]

Update the constraints for setting the seek time to only apply when
using a monotonic timeline. A [scroll-driven
animation](https://www.w3.org/TR/scroll-animations-1/#scroll-driven-animations) needs to defer setting the hold time until the
animation range has been computed.

Replace:

> 1. Let `seek time` be a [time
> value](https://drafts.csswg.org/web-animations-1/#time-value) that is initially
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).
>
> 2. Let `has finite timeline` be true if
> `animation` has an associated
> [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that is not [monotonically
> increasing](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline).
>
> 3. If the `animation`'s [current
> time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), perform the steps according to the first
> matching condition below:
>
> If `animation`'s [playback rate](#animation-effect-playback-rate) is ≥ 0,
>
> : Set `seek time` to zero.
>
> Otherwise,
>
> :
>
> If [associated effect end](https://drafts.csswg.org/web-animations-1/#associated-effect-end) for `animation` is positive infinity,
>
> : [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
> \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
> [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.
>
> Otherwise,
>
> : Set `seek time` to `animation`'s
> [associated effect
> end](https://drafts.csswg.org/web-animations-1/#associated-effect-end).
>
> 4. If `seek time` is
> [resolved](https://drafts.csswg.org/web-animations-1/#unresolved),
>
> ::: switch
>
> If `has finite timeline` is true,
>
> : Set `animation`'s [start
> time](https://www.w3.org/TR/web-animations-1/#animation-start-time) to `seek time`.
>
> Otherwise,
>
> : Set `animation`'s [hold
> time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `seek time`.
> :::

with:

> 1. Let `has finite timeline` be true if
> `animation` has an associated
> [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that is not [monotonically
> increasing](https://drafts.csswg.org/web-animations-1/#monotonically-increasing-timeline).
>
> 2. If the `animation`'s [current
> time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) and `has finite timeline` is false,
> perform the steps according to the first matching condition below:
>
> If `animation`'s [playback rate](#animation-effect-playback-rate) is ≥ 0,
>
> : Set [hold
> time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to zero.
>
> Otherwise,
>
> :
>
> If [associated effect end](https://drafts.csswg.org/web-animations-1/#associated-effect-end) for `animation` is positive infinity,
>
> : [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
> \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
> [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.
>
> Otherwise,
>
> : Set [hold
> time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) to `animation`'s [associated
> effect
> end](https://drafts.csswg.org/web-animations-1/#associated-effect-end).
>
> 3. If `has finite timeline` is true, and the
> `animation`'s [current
> time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved)
>
> - Set the `auto align start time` flag to true.

Replace:

> Schedule a task to be executed at the first possible moment where both
> of the following conditions are true:
>
> - the user agent has performed any processing necessary to suspend the
> playback of animation's associated effect, if any.
>
> - the animation is associated with a timeline that is not inactive.

With:

> Schedule a task to be executed at the first possible moment where all
> of the following conditions are true:
>
> - the user agent has performed any processing necessary to suspend the
> playback of animation's associated effect, if any.
>
> - the animation is associated with a timeline that is not inactive.
>
> - the animation has a resolved [hold
> time](https://www.w3.org/TR/web-animations-1/#animation-hold-time) or [start
> time](https://www.w3.org/TR/web-animations-1/#animation-start-time).

 A [start
time](https://www.w3.org/TR/web-animations-1/#animation-start-time) is still required for a pause-pending animation if the
`auto-align start time` flag is true to properly align to the
animation range. The [start time] is
set following the procedure for [calculating an auto-aligned start
time](#animation-calculating-an-auto-aligned-start-time).

#### 2.3.9. Canceling an animation

Append the final step:

> 1. Queue a task to call any [custom
> effects](#custom-effect)
> associated with [inclusive
> descendants](#inclusive-descendant) of `animation`'s [associated
> effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) with an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) iteration progress.
>
> (#issue-5b6104df) The procedures for calling custom
> effects need to be reworked. Currently they probably involve
> calling too often for changes that could be coalesced.

#### 2.3.10. Speed control

::: informative-bg
Add the following sentence:

> Note that [animation
> effects](https://drafts.csswg.org/web-animations-1/#animation-effect) also have a [playback
> rate](#animation-effect-playback-rate) associated with them that behaves differently to that
> defined here.

#### 2.3.11. Calculating the overall progress of an animation

An animation's [overallProgress] is the ratio
of its [current
time](https://www.w3.org/TR/web-animations-1/#animation-current-time) to its [associated effect
end](https://drafts.csswg.org/web-animations-1/#associated-effect-end).

[overallProgress](#animation-overallprogress) of an
[animation](https://drafts.csswg.org/web-animations-1/#animation), `animation`, is calculated as follows:

If *any* of the following are true:

- `animation` does not have an [associated
 effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect), or

- `animation`'s [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is an
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) time value,

`animation`'s
[overallProgress](#animation-overallprogress) is null.

If `animation`'s [associated effect
end](https://drafts.csswg.org/web-animations-1/#associated-effect-end) is zero,

If `animation`'s [current time](https://www.w3.org/TR/web-animations-1/#animation-current-time) is negative,

: `animation`'s
 [overallProgress](#animation-overallprogress) is zero.

Otherwise,

: `animation`'s
 [overallProgress](#animation-overallprogress) is one.

If `animation`'s [associated effect
end](https://drafts.csswg.org/web-animations-1/#associated-effect-end) is infinite,

`animation`'s
[overallProgress](#animation-overallprogress) is zero.

Otherwise,

> [`overallProgress`](#animation-overallprogress)` = min(max(`[`current time`](https://www.w3.org/TR/web-animations-1/#animation-current-time)` / ``animation``’s `[`associated effect end`](https://drafts.csswg.org/web-animations-1/#associated-effect-end)`, 0), 1) `

### 2.4. Animation effects

Adds the following text:

> The [associated
> effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) of an
> [animation](https://drafts.csswg.org/web-animations-1/#animation) is said to be [directly
> associated]
> with that animation.
>
> [Animation
> effects](https://drafts.csswg.org/web-animations-1/#animation-effect) can be combined together into a hierarchy using
> [group effects](#group-effect)
> (see [§ 2.9 Grouping and
> synchronization](#grouping-and-synchronization)). Only the
> [root](#root) [animation
> effect] of such a hierarchy can be
> [directly associated with an
> animation](#directly-associated-with-an-animation). If an [animation effect]
> that has a [parent group](#parent-group) is designated as the [associated
> effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) of an
> [animation](https://drafts.csswg.org/web-animations-1/#animation), the [animation effect]
> is removed from its [parent group] before
> being associated with the [animation].
>
> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is [associated with an
> animation] if it is [directly associated with an
> animation](#directly-associated-with-an-animation) or if it has an
> [ancestor](#ancestor) [group
> effect](#group-effect) that is
> [directly associated with an
> animation].

#### 2.4.1. Types of animation effects

This specification defines two types of [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect):

- [keyframe
 effects](https://drafts.csswg.org/web-animations-1/#keyframe-effect), and

- [group effects](#group-effect).

#### 2.4.2. The active interval

In this level of the specification the lower bound of the active
interval is defined as:

> The lower bound of the [active
> interval](https://drafts.csswg.org/web-animations-1/#active-interval) is determined by the [start
> time](#animation-effect-start-time) of the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) but may be shifted by a [start
> delay](#start-delay) on the
> [animation effect].

The subsequent diagram should also refer to the *animation effect start
time* as opposed to the *animation start time*.

Finally, the description of the [end
delay](https://drafts.csswg.org/web-animations-1/#end-delay) is updated to:

> An [end
> delay](https://drafts.csswg.org/web-animations-1/#end-delay) may also be specified but is primarily only of use
> when sequencing animations such as by using a [sequence
> effect](#sequence-effect).

The normative description is updated as follows:

> The lower bound of the [active
> interval](https://drafts.csswg.org/web-animations-1/#active-interval) is defined by the combination of the animation
> effect's [start
> time](#animation-effect-start-time) and [start delay](#start-delay).
>
> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [start time] is the moment at which the [parent
> group](#parent-group), if any,
> has scheduled the [animation effect] to
> begin. It is expressed in [inherited
> time](#inherited-time).
>
> In most cases, including the case when the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) has no [parent
> group](#parent-group), the
> [start
> time](#animation-effect-start-time) is zero. The singular exception is [sequence
> effects](#sequence-effect)
> which set the [start times] of
> their children as described in [§ 2.9.4.1 The start time of children
> of a sequence
> effect](#the-start-time-of-children-of-a-sequence-effect).
>
> In addition to the [start
> time](#animation-effect-start-time), an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) also has a [start delay] which is an offset from the
> [start time].
>
> Unlike the [start
> time](#animation-effect-start-time) which is determined by the [parent
> group](#parent-group), the
> [start delay](#start-delay) is
> a property of the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) itself.
>
> The lower bound of the [active
> interval](https://drafts.csswg.org/web-animations-1/#active-interval) of an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect), expressed in [inherited time
> space](#inherited-time), is
> the sum of the [start
> time](#animation-effect-start-time) and the [start
> delay](#start-delay).
>
> These definitions are incorporated in the calculation of the [local
> time](#local-time) (see [§ 2.4.3
> Local time and inherited time](#local-time-and-inherited-time)) and
> [active
> time](https://drafts.csswg.org/web-animations-1/#active-time).

And finally regarding the definition of the [end
time](#end-time):

> The [end time]
> of an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is the result of evaluating
> `max(`[`start time`](#animation-effect-start-time)` + `[`start delay`](#start-delay)` + `[`active duration`](#active-duration)` + `[`end delay`](https://drafts.csswg.org/web-animations-1/#end-delay)`, 0)`.

#### 2.4.3. Local time and inherited time

This section is added.

::: informative-bg
In Web Animations all times are relative to some point of reference.
These different points of reference produce different *time spaces*.

This can be compared to coordinate spaces as used in computer graphics.
The zero time of a time space is analogous to the origin of a coordinate
space.

Just as with coordinate spaces, time spaces can also be nested. [Group
effects](#group-effect)
typically perform some transformations on the [time
values](https://drafts.csswg.org/web-animations-1/#time-value) they receive from their
[parent](#parent-group) or
[animation](https://drafts.csswg.org/web-animations-1/#animation) before passing on the transformed [time
values] to their children. Child [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) then operate *within* that transformed time space.

Children take the transformed time values from their parent---called the
[inherited time](#inherited-time)---and add their [start
time](#animation-effect-start-time) to establish their own [local time
space](#local-time) as illustrated
below.

![Inherited time and local time.\
At time `t`, the [inherited
time](#inherited-time) is
2.5.\
For [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) (a) which has a [start
time](#animation-effect-start-time) of 1, the [local
time](#local-time) is 1.5.\
For [animation effect] (b) which has a
[start time] of 1 and a [start
delay](#start-delay) of 1, the
[local time] is also 1.5 since [local
time] is based on an [animation
effect]'s [start
time] only, and not on its
[start
delay].](images/local-time.svg){a
width="600"}

For an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect), the [inherited time] at a given moment is based on the first
matching condition from the following:

If the [animation effect](https://drafts.csswg.org/web-animations-1/#animation-effect) has a [parent group](#parent-group),

: the inherited time is the [parent
 group](#parent-group)'s
 current [transformed
 time](#transformed-time).

If the [animation effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is [directly associated with an animation](#directly-associated-with-an-animation),

: the inherited time is the [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time) of the
 [animation](https://drafts.csswg.org/web-animations-1/#animation).

Otherwise,

: the inherited time is
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved).

The [local time] of an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is the [animation
effect]'s [inherited
time](#inherited-time) minus
its [start
time](#animation-effect-start-time). If the [inherited time] is
[unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) then the local time is also
[unresolved].

#### 2.4.4. Animation effect phases and states

::: informative-bg
*This section is non-normative*

The non-normative description of the [in
play](#in-play) state includes the
following description;

> This occurs when the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) *and all its ancestors* are in the [active
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-active-phase). [Animation effects]
> only "move" when they are [in play](#in-play).
>
> It is possible for an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) to be in the [active
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-active-phase) but not [in play](#in-play). For example, if an [animation
> effect] has a [parent
> group](#parent-group) that
> causes the animation effect's [active
> interval](https://drafts.csswg.org/web-animations-1/#active-interval) to be clipped and both parent and child apply the
> same [fill
> mode](https://drafts.csswg.org/web-animations-1/#fill-mode), the child [animation
> effect] may be effectively be snapshotted
> within the [active phase]
> despite no longer being [in play].

Likewise for [current](#current)

> This will be the case if the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is [in play](#in-play) or in its [before
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-before-phase), *or* it has an ancestor for which this is true
> thereby opening up the possibility that this [animation
> effect] might play again (e.g. due to
> repeating).

The normative definition of [in play] includes the following condition:

> 2. the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) has a [parent
> group](#parent-group)
> that is [in play](#in-play) or
> else the [animation effect] is
> [directly associated with an
> animation](#directly-associated-with-an-animation) that is not
> [finished](https://www.w3.org/TR/web-animations-1/#play-state-finished).

In place of:

> 2. the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is [associated with an
> animation](#associated-with-an-animation) that is not
> [finished](https://www.w3.org/TR/web-animations-1/#play-state-finished).

The normative definition of [current] adds the following condition:

> - the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) has a [parent
> group](#parent-group) and
> the [parent group] is
> [current](#current).

Add the following definitions to the list used in determining the phase
of an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

[at timeline boundary]

: Determined based on the first matching condition:

 If the [minimum timeline time](#minimum-timeline-time) matches the [timeline current time]:

 : Return true

 If the [maximum timeline time](#maximum-timeline-time) matches the [timeline current time]:

 : Return true

 Otherwise

 : Return false

 The intent of this procedure for use in phase
 determination is to avoid the need for fill-mode when using a
 scroll-timeline where the active timeline range spans the full
 scroll range, or a view-timeline where the subject is aligned with
 the start or end of the source scroll container. This algorithm is
 not intended to handle the general case, but rather avoids
 complications, such as when a view timeline subject that is not
 aligned with either bound of the scroll container being a candidate
 when the magnitude of the playbackRate \> 1. The algorithm also
 doesn't handle paused animations. A more general solution is
 potentially feasible.

Replace:

> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is in the before phase if the animation effect's
> [local time](#local-time) is not
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) and *either* of the following conditions are met:
>
> 1. the [local time](#local-time) is less than the [before-active boundary
> time](https://drafts.csswg.org/web-animations-1/#before-active-boundary-time), *or*
>
> 2. the [animation
> direction](https://drafts.csswg.org/web-animations-1/#animation-direction) is \"backwards\" and the [local
> time](#local-time) is equal
> to the [before-active boundary
> time](https://drafts.csswg.org/web-animations-1/#before-active-boundary-time).

with:

> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is in the before phase if the animation effect's
> [local time](#local-time) is not
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) and *either* of the following conditions are met:
>
> 1. the [local time](#local-time) is less than the [before-active boundary
> time](https://drafts.csswg.org/web-animations-1/#before-active-boundary-time), *or*
>
> 2. the [animation
> direction](https://drafts.csswg.org/web-animations-1/#animation-direction) is \"backwards\" and the [local
> time](#local-time) is equal
> to the [before-active boundary
> time](https://drafts.csswg.org/web-animations-1/#before-active-boundary-time) and not [at timeline
> boundary](#at-timeline-boundary).

Replace:

> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is in the after phase if the animation effect's
> [local time](#local-time) is
> not
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) and *either* of the following conditions are met:
>
> 1. the [local time](#local-time) is greater than the [active-after boundary
> time](https://drafts.csswg.org/web-animations-1/#active-after-boundary-time), *or*
>
> 2. the [animation
> direction](https://drafts.csswg.org/web-animations-1/#animation-direction) is \"forwards\" and the [local
> time](#local-time) is equal
> to the [active-after boundary
> time](https://drafts.csswg.org/web-animations-1/#active-after-boundary-time).

with:

> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is in the after phase if the animation effect's
> [local time](#local-time) is
> not
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) and *either* of the following conditions are met:
>
> 1. the [local time](#local-time) is greater than the [active-after boundary
> time](https://drafts.csswg.org/web-animations-1/#active-after-boundary-time), *or*
>
> 2. the [animation
> direction](https://drafts.csswg.org/web-animations-1/#animation-direction) is \"forwards\" and the [local
> time](#local-time) is equal
> to the [active-after boundary
> time](https://drafts.csswg.org/web-animations-1/#active-after-boundary-time) and not [at timeline
> boundary](#at-timeline-boundary).

#### 2.4.5. Fill modes

:::: informative-bg
*This section is non-normative*

The description of the forwards fill mode is updated from:

> When the animation effect is in the [after
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-after-phase), ...

to:

> When the animation effect is in the [after
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-after-phase), or when the animation effect is in the [active
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-active-phase) but an [ancestor](#ancestor) is in its [after
> phase], ...

The description of the backwards fill mode is updated from:

> When the animation effect is in the [before
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-before-phase), ...

to:

> When the animation effect is in the [before
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-before-phase), or when the animation effect is in the [active
> phase](https://www.w3.org/TR/web-animations-1/#animation-effect-active-phase) but an [ancestor](#ancestor) is in its [before
> phase], ...

The description of the both fill mode is updated from:

> When the animation effect ...

to:

> When the animation effect or an
> [ancestor](#ancestor) ...

(twice).

Currently [timing
functions](https://www.w3.org/TR/css-easing-2/#easing-function) that generate results outside the range \[0, 1\] will
behave unexpectedly when applied to group effects, as children will
increase iterations or enter into fill mode rather than continuing to
extrapolate along their defined behavior (which is what they would do if
the timing function applied to them directly).

To fix this it is possible we will wish to introduce 'overflow' fill
modes that respond to time values larger than or smaller than the active
time range by extrapolating rather than filling.

See [section 15 (Overflowing fill) of minuted discussion from Tokyo 2013
F2F](https://lists.w3.org/Archives/Public/public-fx/2013AprJun/0184.html).

### 2.5. Repeating

#### 2.5.1. Iteration intervals

After:

> The length of a single iteration is called the iteration duration.

Add:

> The initial [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of an animation effect is simply its [intrinsic
> iteration
> duration](#intrinsic-iteration-duration). The [intrinsic iteration
> duration] is calculated from the first matching
> condition from below:
>
> If the animation effect is a [group effect](#group-effect),
>
> : Follow the procedure in [§ 2.9.3 The intrinsic iteration duration
> of a group
> effect](#the-intrinsic-iteration-duration-of-a-group-effect)
>
> If the animation effect is a [sequence effect](#sequence-effect),
>
> : Follow the procedure in [§ 2.9.4.2 The intrinsic iteration
> duration of a sequence
> effect](#the-intrinsic-iteration-duration-of-a-sequence-effect)
>
> If [timeline duration](#timeline-duration) is unresolved or [iteration count](https://drafts.csswg.org/web-animations-1/#iteration-count) is zero,
>
> : Return 0
>
> Otherwise
>
> : Return
> `(100% - `[`start delay`](#start-delay)` - `[`end delay`](https://drafts.csswg.org/web-animations-1/#end-delay)`) / `[`iteration count`](https://drafts.csswg.org/web-animations-1/#iteration-count)
>
> Presently start and end delays are zero until
> such time as percentage based delays are supported.
>
> The [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) may be set by the author to represent a value other
> than the [intrinsic iteration
> duration](#intrinsic-iteration-duration).

#### 2.5.2. Iteration time space

::: informative-bg
*This section is non-normative*

The first few paragraphs of this section are replaced with:

> We have already encountered different time spaces in describing [local
> time](#local-time) and
> [inherited time](#inherited-time) (see [§ 2.4.3 Local time and inherited
> time](#local-time-and-inherited-time)). Repetition introduces yet
> another time space: the iteration time space.

#### 2.5.3. Interval timing

::: informative-bg
*This section is non-normative*

The description is updated as follows:

> In the examples below, for the repeated effect, at local time 1s, the
> iteration time is 0. For the sequenced effects, at inherited time 1s,
> only effect B will be [in play](#in-play); there is no overlap.

And likewise the figure is updated as follows:

![Illustration of end-point exclusive timing. For both repeated and
sequenced animation effects there is no overlap at the boundaries
between
intervals.](images/endpoint-exclusive-timing.svg){a
width="600"}

### 2.6. Animation effect speed control

(This section is added.)

Like
[animations](https://drafts.csswg.org/web-animations-1/#animation), [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) also have a [playback
rate] parameter. The
[playback
rate](#animation-effect-playback-rate) of an [animation effect]
is a finite real number that acts as a multiplier when calculating the
[animation effect]'s [transformed
time](#transformed-time)
from its [local time](#local-time).

The effect of setting the [playback
rate](#animation-effect-playback-rate) of an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) differs from the setting the [playback
rate] on an animation. Its
behavior is defined in the timing calculations given in [§ 2.7 Core
animation effect calculations](#core-animation-effect-calculations).

::: informative-bg
*This section is non-normative*

In summary, the behavior of the [playback
rate](#animation-effect-playback-rate) of an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is as follows:

- The [playback
 rate](#animation-effect-playback-rate) is applied only to the [active
 interval](https://drafts.csswg.org/web-animations-1/#active-interval) of an [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) and not to the time while it is
 [delayed](#start-delay) or
 [filling](https://drafts.csswg.org/web-animations-1/#fill-mode).

- Setting a negative [playback
 rate](#animation-effect-playback-rate) on an [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) causes the [animation
 effect] to begin at the end of its
 [active
 interval](https://drafts.csswg.org/web-animations-1/#active-interval). This differs from the [playback
 rate] on an
 [animation](https://drafts.csswg.org/web-animations-1/#animation). Setting a [playback
 rate] on an
 [animation] to a negative value at a moment
 before the [animation]'s [associated
 effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) has begun, will result in the [associated
 effect] never playing.

- Setting the [playback
 rate](#animation-effect-playback-rate) of an [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) affects the calculated value of the [active
 duration](#active-duration)
 (see [§ 2.7.2 Calculating the active
 duration](#calculating-the-active-duration)).

- Changing the [playback
 rate](#animation-effect-playback-rate) of an [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) whose [local time](#local-time) is within its [active
 interval](https://drafts.csswg.org/web-animations-1/#active-interval) will cause it to jump. This is because the [active
 duration](#active-duration)
 will be updated but the [local time] will not.

 Furthermore, if other [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) depend on the [animation
 effect]'s [active
 duration](#active-duration), such as sibling [animation
 effect] in a [sequence
 effect](#sequence-effect),
 they too may jump as a result of setting the [animation
 effect]'s [playback
 rate](#animation-effect-playback-rate).

 For runtime speed control the [playback
 rate](#animation-effect-playback-rate) of the
 [animation](https://drafts.csswg.org/web-animations-1/#animation) should be used.

### 2.7. Core animation effect calculations

#### 2.7.1. Overview

::: informative-bg
*This section is non-normative*

Update description from:

> At the core of the Web Animations timing model is the process that
> takes a [local time](#local-time) value and converts it to an [iteration
> progress](https://drafts.csswg.org/web-animations-1/#iteration-progress).

to:

> At the core of the Web Animations timing model is the process that
> takes an [inherited time](#inherited-time) value and converts it to an [iteration
> progress](https://drafts.csswg.org/web-animations-1/#iteration-progress).

Update diagram to show animation effect playback rate:

![Calculation of the [active
duration](#active-duration)
is based on multiplying the [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) by the [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count) and then dividing by the [playback
rate](#animation-effect-playback-rate).](images/active-duration-calculation.svg){a
width="650"}

Update:

> Having established the [active
> duration](#active-duration), the process for transforming an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [local time](#local-time) into its [transformed
> progress](https://drafts.csswg.org/web-animations-1/#transformed-progress) ([iteration
> progress](https://drafts.csswg.org/web-animations-1/#iteration-progress)) is illustrated below.

to:

> Having established the [active
> duration](#active-duration), the process for transforming an [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [inherited
> time](#inherited-time) into
> its [transformed
> progress](https://drafts.csswg.org/web-animations-1/#transformed-progress) ([iteration
> progress](https://drafts.csswg.org/web-animations-1/#iteration-progress)) is illustrated below.

Update the time calculations diagram as follows:

![An overview of timing model calculations.\
(1) The [inherited time](#inherited-time) is converted into a [local
time](#local-time) by
incorporating the [start
time](#animation-effect-start-time).\
(2) The [local time] is converted into an [active
time](https://drafts.csswg.org/web-animations-1/#active-time) by incorporating the [start
delay](#start-delay).\
(3) The [active time] is divided by the
[iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) incorporating also the [iteration
start](https://drafts.csswg.org/web-animations-1/#iteration-start) property and the [playback
rate](#animation-effect-playback-rate) property to produce the [overall
progress](https://drafts.csswg.org/web-animations-1/#overall-progress).\
(4) The [overall progress] time is then
converted to an offset within a single iteration: the [simple iteration
progress](https://drafts.csswg.org/web-animations-1/#simple-iteration-progress).\
(5) The [simple iteration progress]
is converted into a [directed
progress](https://drafts.csswg.org/web-animations-1/#directed-progress) by incorporating the [playback
direction](https://drafts.csswg.org/web-animations-1/#playback-direction).\
(6) Finally, a timing function is applied to the [directed
progress] to produce the [transformed
progress](https://drafts.csswg.org/web-animations-1/#transformed-progress).](images/time-calculations.svg){a
width="650"}

Update:

> The first step, calculating the [local
> time](#local-time) is described
> in Local time.

to:

> The first step, calculating the [local
> time](#local-time) is described
> in [§ 2.4.3 Local time and inherited
> time](#local-time-and-inherited-time).

#### 2.7.2. Calculating the active duration

Updated to:

> In order to calculate the [active
> duration](#active-duration)
> we first define the [repeated
> duration](#repeated-duration) as follows:
>
> > [repeated duration] =
> > [`iteration duration`](https://drafts.csswg.org/web-animations-1/#iteration-duration)` × `[`iteration count`](https://drafts.csswg.org/web-animations-1/#iteration-count)
> >
> > If either the [iteration
> > duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) or [iteration
> > count](https://drafts.csswg.org/web-animations-1/#iteration-count) are zero, the [repeated
> > duration](#repeated-duration) is zero.
> >
> > This clarification is needed since the result of infinity multiplied
> > by zero is undefined according to IEEE 754-2008.
>
> The [active duration] is calculated according to the following
> steps:
>
> 1. If the [playback
> rate](#animation-effect-playback-rate) is zero, return `Infinity`.
>
> 2. Otherwise, return
> [`repeated duration`](#repeated-duration)` / abs(`[`playback rate`](#animation-effect-playback-rate)`)`.

#### 2.7.3. Transforming the local time

##### 2.7.3.1. Calculating the active time

Update the qualification on the definition of the [active
time](https://drafts.csswg.org/web-animations-1/#active-time) to include reference to the [parent
group](#parent-group):

> However, it is only defined when the [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) should produce an output and hence depends on its
> [fill
> mode](https://drafts.csswg.org/web-animations-1/#fill-mode) and phase as well as the phase of its [parent
> group](#parent-group), if
> any, as follows,

Update the definition to include the additional steps to for each phase:

>
>
> If the animation effect is in the [before phase](https://www.w3.org/TR/web-animations-1/#animation-effect-before-phase),
>
> : The result depends on the first matching condition from the
> following,
>
> If the animation effect has a [parent group](#parent-group) and that parent group is in the [after phase](https://www.w3.org/TR/web-animations-1/#animation-effect-after-phase),
>
> : Return an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [time
> value](https://drafts.csswg.org/web-animations-1/#time-value).
>
> ...
>
> If the animation effect is in the [active phase](https://www.w3.org/TR/web-animations-1/#animation-effect-active-phase),
>
> : The result depends on the first matching condition from the
> following,
>
> If the animation effect has a [parent group](#parent-group) and that parent group is in the [before phase](https://www.w3.org/TR/web-animations-1/#animation-effect-before-phase), and the [fill mode](https://drafts.csswg.org/web-animations-1/#fill-mode) of this animation effect is [none] or [forwards],
>
> : Return an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [time
> value](https://drafts.csswg.org/web-animations-1/#time-value).
>
> If the animation effect has a [parent group](#parent-group) and that parent group is in the [after phase](https://www.w3.org/TR/web-animations-1/#animation-effect-after-phase), and the [fill mode](https://drafts.csswg.org/web-animations-1/#fill-mode) of this animation effect is [none] or [backwards],
>
> : Return an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [time
> value](https://drafts.csswg.org/web-animations-1/#time-value).
>
> Otherwise,
>
> : Return the result of evaluating
> [`local time`](#local-time)` - `[`start delay`](#start-delay).
>
> If the animation effect is in the [after phase](https://www.w3.org/TR/web-animations-1/#animation-effect-after-phase),
>
> : The result depends on the first matching condition from the
> following,
>
> If the animation effect has a [parent group](#parent-group) and that parent group is in the [before phase](https://www.w3.org/TR/web-animations-1/#animation-effect-before-phase),
>
> : Return an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [time
> value](https://drafts.csswg.org/web-animations-1/#time-value).
>
> ...
>
> Otherwise (the [local time](#local-time) is [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved)),
>
> : Return an
> [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [time
> value](https://drafts.csswg.org/web-animations-1/#time-value).

##### 2.7.3.2. Calculating the overall progress

In the definition of the [overall
progress](https://drafts.csswg.org/web-animations-1/#overall-progress) update the "Otherwise" branch of the definition of the
`initial progress` as:

>
>
> Otherwise,
>
> : Calculate the `overall progress` following the first
> matching condition from below:
>
> If the [playback rate](#animation-effect-playback-rate) is less than zero,
>
> : Let `overall progress` be
> `(`[`active time`](https://drafts.csswg.org/web-animations-1/#active-time)` - `[`active duration`](#active-duration)`) × `[`playback rate`](#animation-effect-playback-rate)` / `[`iteration duration`](https://drafts.csswg.org/web-animations-1/#iteration-duration).
>
> If the [playback rate](#animation-effect-playback-rate) is zero,
>
> : Let `overall progress` be zero.
>
> Otherwise,
>
> : Let `overall progress` be
> `(`[`active time`](https://drafts.csswg.org/web-animations-1/#active-time)` × `[`playback rate`](#animation-effect-playback-rate)`) / `[`iteration duration`](https://drafts.csswg.org/web-animations-1/#iteration-duration).

### 2.8. Time transformations

Currently, the set of [timing
functions](https://www.w3.org/TR/css-easing-2/#easing-function) allowed on a [group
effect](#group-effect) is not
restricted. This has raised concern about complexity of implementation
and also complexity of behavior with regards to fill modes. As a result,
allowing the full set of timing functions on group effects is considered
**at risk**.

Alternatives are to either restrict timing functions on group effects to
the [linear timing
function](https://www.w3.org/TR/css-easing-1/#linear-easing-function) or to a set of "simple" timing functions that have
properties that alleviate some of the concerns with the more complex
timing functions.

See [section 2 of the discussion from August
2013](https://lists.w3.org/Archives/Public/public-fx/2013JulSep/0076.html).

#### 2.8.1. Calculating the transformed progress

Replace the second step as the calculation of the [before
flag](https://www.w3.org/TR/css-easing-2/#before-flag) (to accommodate the effect playback rate):

> 1. If *either* the `current direction` is
> [forwards] or the [playback
> rate](#animation-effect-playback-rate) ≥ 0 (but *not* when both conditions are true),
> let `going forwards` be true, otherwise it is false.

#### 2.8.2. Calculating the transformed time

(This section is added.)

The [transformed time] of an animation effect is simply the
[transformed
progress](https://drafts.csswg.org/web-animations-1/#transformed-progress) multiplied by the [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration).

If the [transformed
progress](https://drafts.csswg.org/web-animations-1/#transformed-progress) is
[unresolved](https://drafts.csswg.org/web-animations-1/#unresolved), then the [transformed
time](#transformed-time) is
also [unresolved].

If the [transformed
progress](https://drafts.csswg.org/web-animations-1/#transformed-progress) is zero and the [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) is infinity, then the [transformed
time](#transformed-time) is
zero.

### 2.9. Grouping and synchronization

::: informative-bg
*This section is non-normative*

While it is possible to set the timing properties of [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) individually, it is often useful to synchronize
[animation effects] so that they share
common timing properties and maintain their temporal relationship. This
is achieved using an [group
effect](#group-effect).

A simple example is illustrated below.

![Using groups to share common timing properties.\
(a) Shows setting a delay of 5 seconds on individual animations.\
(b) Produces the same effect by setting the delay on the
group.](images/grouping-delay.svg){a
width="800"}

When a [group effect](#group-effect) is [directly associated with an
animation](#directly-associated-with-an-animation), the [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) associated with the [group
effect] can be seeked, paused, and stopped as a
unit.

A [group effect] is a type of [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) that contains an ordered sequence of zero or more
[animation effects] known as [child
effects].

At a given moment, an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) may be a [child
effect](#child-effect) of at most
one [group effect](#group-effect) known as the [parent group]. The [parent
group](#parent-group) cannot be
the same [animation effect] as the [child
effect] itself.

By nesting [group effects](#group-effect) it is possible to create hierarchical tree structures.
The following terms are used to describe the parts and properties of
such structures and are defined in
[\[DOM\]](#biblio-dom "DOM Standard"):

- [ [tree
 order](https://www.w3.org/TR/dom/#concept-tree-order)]

- [ [root](https://www.w3.org/TR/dom/#concept-tree-root)]

- [
 [ancestor](https://www.w3.org/TR/dom/#concept-tree-ancestor)]

- [
 [descendant](https://www.w3.org/TR/dom/#concept-tree-descendant)]

- [ [inclusive
 ancestor](https://www.w3.org/TR/dom/#concept-tree-inclusive-ancestor)]

- [ [inclusive
 descendant](https://www.w3.org/TR/dom/#concept-tree-inclusive-descendant)]

- [ [next
 sibling](https://www.w3.org/TR/dom/#concept-tree-next-sibling)]

- [ [previous
 sibling](https://www.w3.org/TR/dom/#concept-tree-previous-sibling)]

- [ [first
 child](https://www.w3.org/TR/dom/#concept-tree-first-child)]

- [ [last
 child](https://www.w3.org/TR/dom/#concept-tree-last-child)]

 in applying these definitions to [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect), the term *parent* refers exclusively to a [parent
group](#parent-group) and does
*not* include the
[animation](https://drafts.csswg.org/web-animations-1/#animation) which with an [animation
effect] may be [directly
associated](#directly-associated-with-an-animation) despite the fact that conceptually the
[animation] acts as a parent time source.

The temporal relationship between a [child
effect](#child-effect) and its
[parent group](#parent-group)
is incorporated in the definition of [inherited
time](#inherited-time) (see
[§ 2.4.3 Local time and inherited
time](#local-time-and-inherited-time)).

#### 2.9.1. Relationship of group time to child time

::: informative-bg
*This section is non-normative*

The timing of the children of a [group
effect](#group-effect) is based
on the timing of the group. Specifically, times for the children are
based on the parent's [transformed
time](#transformed-time).
With regards to repetition, this means the children operate *inside* an
iteration of the parent.

For example, if a [group effect](#group-effect) has an [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count) of 2, then the children of the group will all play
twice since they effectively play *inside* the group's iterations.

![Since children of a [group
effect](#group-effect) base
their timing on the group's [transformed
time](#transformed-time),
when the group repeats, the children play
again.](images/grouping-repetition.svg){a
width="600"}

Note that even in this case, the child [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) still have only *one* [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval). However, as a result of the parent's timing, the
[active interval] is played twice.

If an [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count) is specified for the children of a group as well as for
the group itself, the effect is as if the [iteration
count] of the group was multiplied with the
[iteration count] of the children.

![Specifying an [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count) of 2 on a [group
effect](#group-effect) and an
[iteration count] of 3 on one of its
children results in that child playing 6
times.](images/grouping-repetition-and-animation-repetition.svg){a
width="600"}

A further result of the children of a [group
effect](#group-effect) basing
their timing on the group's [transformed
time](#transformed-time) is
that they cannot animate outside of the group's [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval). This is because the [transformed
time] of a group will not change outside its
[active interval]. This allows groups to
*clip* the playback of their children.

![In the first instance, an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) has a negative delay and an infinite [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count).\
However, when a similar [animation effect]
is placed inside a [group effect](#group-effect) with a specified [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) it has the effect of clipping the child [animation
effect]'s [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval).](images/grouping-clipping.svg){a
width="600"}

Some further consequences of [group
effect](#group-effect) children
basing their timing on their parent group's [transformed
time](#transformed-time)
are:

- Setting the [playback
 rate](#animation-effect-playback-rate) of a [group
 effect](#group-effect) will
 speed up or slow down all children.

- Changing the [playback
 direction](https://drafts.csswg.org/web-animations-1/#playback-direction) of a [group
 effect](#group-effect) will
 change the direction of all children.

- Applying a [timing
 function](https://www.w3.org/TR/css-easing-2/#easing-function) to a [group
 effect](#group-effect) will
 affect the progress of all children.

#### 2.9.2. The start time of children of a group effect

The [start
time](#animation-effect-start-time) of a [child
effect](#child-effect) of a
[group effect](#group-effect)
is zero.

Note that specific types of [group
effects](#group-effect) may
override this definition to provide other kinds of synchronization
behavior.

#### 2.9.3. The intrinsic iteration duration of a group effect

The [intrinsic iteration
duration](#intrinsic-iteration-duration) of a [group
effect](#group-effect) is based
on the time when the last [child
effect](#child-effect) completes
its [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) and depends on the number of [child
effects] as follows.

If the group has no [child effects](#child-effect),

: the [intrinsic iteration
 duration](#intrinsic-iteration-duration) is zero.

Otherwise,

: 1. Let `maximum end time` be the maximum value after
 calculating the [end time](#end-time) of each [child
 effect](#child-effect)
 in the group. The [end time] may be
 expressed as a time or a percentage (in the case of a
 [progress-based
 timeline](#progress-based-timeline)). In the event of mixed time and percentage
 [end time]s, the largest time based value
 equates to 100% for the purpose of time scaling.

 2. The [intrinsic iteration
 duration](#intrinsic-iteration-duration) is the result of evaluating
 `max(0, ``maximum end time``)`.

This definition of the [intrinsic iteration
duration](#intrinsic-iteration-duration) may be overridden by specific types of [group
effects](#group-effect).

#### 2.9.4. Sequence effects

::: informative-bg
*This section is non-normative*

Specific types of [group effects](#group-effect) can be used to provide different kinds of
synchronization behavior for their children. This specification defines
one additional type of [group effect]: a
[sequence effect](#sequence-effect). [Sequence effects] arrange
the start times of their children so that they run one at a time, in
turn.

Compare the two arrangements illustrated below:

![Group effects and sequence effects.\
(a) is a regular [group effect](#group-effect) where all the children run simultaneously.\
(b) is a [sequence effect](#sequence-effect) where the children run in
turn.](images/grouping-types.svg){a
width="600"}

Since [group effects](#group-effect) can also contain other [group
effects], complex synchronization is possible
by combining different types of groups as illustrated below.

![A [sequence effect](#sequence-effect) that contains a regular [group
effect](#group-effect) as a
child.\
The [group effect] waits for the previous child
of the [sequence effect] to finish, and then
the children of the [group effect] play
simultaneously. After they have finished the next child of the [sequence
effect]
plays.](images/grouping-nesting.svg){a
width="600"}

A [sequence effect] is a type of [group
effect](#group-effect) that
schedules its [child effects](#child-effect) such that they play in turn following their order in
the group. This sequencing is achieved by adjusting the [start
time](#animation-effect-start-time) of each [child effect] in the
group.

##### 2.9.4.1. The start time of children of a sequence effect

The [start
time](#animation-effect-start-time) of a [child
effect](#child-effect) of a
[sequence effect](#sequence-effect) is the [end time](#end-time) of the child's [previous
sibling](#previous-sibling).
If the child has no [previous sibling] the
start time is zero.

When the [active duration](#active-duration) is positive infinity the behavior for calculating the
[end time](#end-time) of an
[animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) and the [start
time](#animation-effect-start-time) of subsequent children follows the usual behavior
defined by IEEE 754-2008. As a result, if any of the children of a
[sequence effect](#sequence-effect) has an infinite [active
duration], any children that occur later in
the sequence will not play.

Similarly, the above definition does not restrict [start
times](#animation-effect-start-time) to positive values and hence some children may not play
due to a negative [start delay](#start-delay) on children that occur earlier in the group since their
[active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) may end before the group's [start
time].

::: informative-bg
*This section is non-normative*

Because the start of the [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) is based on the sum of an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [start
time](#animation-effect-start-time) *and* [start
delay](#start-delay), the
[active intervals] of children of a
[sequence effect](#sequence-effect) need not run in strict sequence but can be shifted back
and forth by using the [start delay] as shown in
the following diagram.

![Example of using the [start
delay](#start-delay) on children
of a [sequence effect](#sequence-effect) to shift their timing so that they overlap (a negative
delay) or are spaced apart (a positive
delay).](images/sequence-groups-and-start-delays.svg){a
width="600"}

A negative [start delay](#start-delay) can be used to cause the [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) of two children to overlap. Note that the [start
delay] affects the [start
time](#animation-effect-start-time) of subsequent children in the group.

##### 2.9.4.2. The intrinsic iteration duration of a sequence effect

The [intrinsic iteration
duration](#intrinsic-iteration-duration) of a [sequence
effect](#sequence-effect) is
equivalent to the [start
time](#animation-effect-start-time) of a hypothetical [child
effect](#child-effect) appended
to the group's children calculated according to the definition in
[§ 2.9.4.1 The start time of children of a sequence
effect](#the-start-time-of-children-of-a-sequence-effect) unless that
produces a negative value, in which case the [intrinsic iteration
duration] is zero.

As a result, if the [sequence
effect](#sequence-effect)
has no [child effects](#child-effect) the [intrinsic iteration
duration](#intrinsic-iteration-duration) will be zero.

## 3. Animation model

### 3.1. Animation types

#### 3.1.1. Not animatable

Update the description of an effect that targets a non-animated property
as:

> An [animation
> effect](https://drafts.csswg.org/web-animations-1/#animation-effect) that targets a property that is [not
> animatable](https://drafts.csswg.org/web-animations-1/#not-animatable) will still exhibit the usual behavior for an
> [animation effect] such as occupying time
> in a [sequence effect](#sequence-effect) and delaying the fulfillment of an
> [animation](https://drafts.csswg.org/web-animations-1/#animation)'s [current finished
> promise](https://drafts.csswg.org/web-animations-1/#current-finished-promise).

### 3.2. Keyframe Effects

#### 3.2.1. The effect value of a keyframe effect

The implicit keyframe generation steps
in Web Animations Level 1 need to be reconciled with the behavior
defined for [named timeline range keyframe
selectors](https://www.w3.org/TR/scroll-animations-1/#named-range-keyframes)
in Scroll Animations. Scroll Animations currently overrides those steps
but that overridden behavior should be incorporated directly in this
algorithm. See [issue
14309](https://github.com/w3c/csswg-drafts/issues/14309).

The procedure for computing the [effect
value](https://drafts.csswg.org/web-animations-1/#effect-value) of a single property referenced by a [keyframe
effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect) as one of its [target
properties](https://drafts.csswg.org/web-animations-1/#target-property), for a given `iteration progress`,
`current iteration` and `underlying value` is
amended by inserting the following step after the step to apply the
keyframe effect composite mode.

12. For each `keyframe` in `interval endpoints`:

 1. (As in web-animations-1).

 2. If this [keyframe
 effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect) has an [iteration composite
 operation](#iteration-composite-operation) of
 [accumulate](#iteration-composite-operation-accumulate), apply the following step
 `current iteration` times:

 - replace the property value of `target property` on
 `keyframe` with the result of combining the
 property value on the final keyframe in
 `property-specific keyframes` (`V`~a~)
 with the property value on `keyframe`
 (`V`~b~) using the [accumulation
 procedure](https://www.w3.org/TR/css-values-4/#accumulation) defined for `target property`.

 The order of arguments here is important. In
 the case where the animation type of the target property does
 not define a procedure for accumulation or addition, the default
 definition for these procedures result in `V`~b~
 being returned. When performing iteration composition on
 properties that do not support accumulation, the result should
 be the initial property value of `target property` on
 `keyframe`, hence we make this `V`~b~ in
 the above step.

### 3.3. Combining effects

#### 3.3.1. The effect stack

The procedure for sorting effects appends the following step:

> 1. Sort `A` and `B` in [tree
> order](#tree-order). (By this
> point, `A` and `B` must have the same
> [animation](https://drafts.csswg.org/web-animations-1/#animation) since otherwise the order would have been
> resolved in the previous step.)

The \"associated animation of an
animation effect\" definition used when sorting animation effects needs
to be revised to use the [associated with an
animation](#associated-with-an-animation) definition introduced in this level of the
specification so that it correctly handles group effects.

### 3.4. Effect accumulation

Similar to the compositing performed between [effect
values](https://drafts.csswg.org/web-animations-1/#effect-value) (see [Web Animations § 5.4.4 Effect
composition](https://www.w3.org/TR/web-animations-1/#effect-composition)),
the [iteration composite operation] determines how values are
combined between successive iterations of the same [keyframe
effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect).

This specification defines two [iteration composite
operations](#iteration-composite-operation) as follows:

[replace]

: Each successive iteration is calculated independently of previous
 iterations.

[accumulate]

: Successive iterations of the animation are
 [accumulated](https://www.w3.org/TR/css-values-4/#accumulation) with the final value of the previous iteration.

 The application of the [iteration composite
 operation](#iteration-composite-operation) is incorporated in the calculation of the [effect
 value](https://drafts.csswg.org/web-animations-1/#effect-value) in [§ 3.2.1 The effect value of a keyframe
 effect](#the-effect-value-of-a-keyframe-animation-effect).

### 3.5. Custom effects

(This section is added.)

This whole feature needs to be
revisited. The current thinking is that rather than having custom
effects, we should simply have an `onupdate` callback on each [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect). That would allow, for example, augmenting an existing
effect with a function that performs logging or triggers additional
actions at certain times. With the current arrangement, doing this would
require adding a parent group just to achieve this.

::: informative-bg
*This section is non-normative*

In some situations the [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) provided by Web Animations may be insufficient. For
example, the [animation effects] defined
here are only able to target certain CSS properties. They are unable,
therefore, to modify the
[`currentScale`](https://www.w3.org/TR/SVG11/struct.html#__svg__SVGSVGElement__currentScale)
property of an SVG element to smoothly zoom the viewport without
affecting the document content.

In such cases, where the provided [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) do not provide needed functionality, an effect defined
by script may be used. Such [custom
effects](#custom-effect)
receive an [iteration
progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) and [current
iteration](https://drafts.csswg.org/web-animations-1/#current-iteration-index) from the timing model and are responsible for producing
an effect corresponding to the specified time.

Using an effect defined in script it is possible to animate not only
otherwise un-animatable attributes and properties, but potentially
anything that is accessible via script, including even producing audio
or creating vibrations.

For example, using a [custom
effect](#custom-effect) that
draws to a
[`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) element, it is possible to produce a complex
animated effect featuring patterns that may be difficult to create using
CSS or SVG. Compared to using [Timing control for script-based
animations](https://www.w3.org/TR/animation-timing/), this approach
ensures the animation is frame-rate independent and can be paused,
reversed, eased with timing effects, accelerated, synchronized with
other animations, and be controlled in the same manner as any other Web
Animations animation without any additional programming.

A [custom effect] is an author-defined programming callback that is passed
timing information as part of the [update animations and send
events](https://drafts.csswg.org/web-animations-1/#update-animations-and-send-events) procedure.

It needs to be called whenever timing
properties are updated too, right?

#### 3.5.1. Sampling custom effects

[Custom effects](#custom-effect) are called for each referencing [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) when the [update animations and send
events](https://drafts.csswg.org/web-animations-1/#update-animations-and-send-events) procedure is performed (henceforth referred to simple
as an *update*) based on the following criteria.

1. If, on the previous update, the [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) referencing the [custom
 effect](#custom-effect):

 - was [in
 effect](https://drafts.csswg.org/web-animations-1/#in-effect), and

 - referenced this same [custom
 effect](#custom-effect),
 and

 - had a different [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element)

 Call the callback passing an
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [iteration
 progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) and the [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) from the previous update as parameters to the
 callback.

2. Call the callback for the current [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) based on the first matching condition from the
 following:

 If the [animation effect](https://drafts.csswg.org/web-animations-1/#animation-effect) referencing the custom effect is not [in effect](https://drafts.csswg.org/web-animations-1/#in-effect) but was [in effect] in the previous update,

 : Call the callback passing an
 [unresolved](https://drafts.csswg.org/web-animations-1/#unresolved) [iteration
 progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) and the current [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) as parameters to the callback.

 Otherwise, if the [animation effect](https://drafts.csswg.org/web-animations-1/#animation-effect) referencing the custom effect:

 : - **is [in
 effect](https://drafts.csswg.org/web-animations-1/#in-effect), and**

 - **was not [in
 effect](https://drafts.csswg.org/web-animations-1/#in-effect) in the previous update, or was [in
 effect] but with a different [iteration
 progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) or [current
 iteration](https://drafts.csswg.org/web-animations-1/#current-iteration-index),**

 : Call the callback passing with the referencing [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s current [iteration
 progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) and [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) as parameters to the callback.

There may be use cases where an action
needs to be triggered at a specific point in an animation tree. In many
cases this can be achieved by inserting a custom effect with a
step-start easing that spans the period during which the action should
be triggered. However, this can impose additional layout requirements on
the content which might be cumbersome to accommodate.

Some alternatives under consideration:

- Additional calling conditions could be defined to accommodate
 zero-width custom effects. For example, it could be required that the
 callback be called if (given infinite precision) there was a time
 between the previous and current update times that aligned with the
 custom effect.

- Instead of adding special calling conditions to custom effects, a new
 type of animation effect, Trigger, could be introduced. The trigger
 would only ever act as a zero-width custom effect as described above,
 its constructor would take a callback function, but not require a
 target or timing. It could also specify other calling conventions, for
 example whether it should only trigger in a specific playback
 direction.

#### 3.5.2. Execution order of custom effects

Since [custom effects](#custom-effect), unlike [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect), are not limited to a single [target
property](https://drafts.csswg.org/web-animations-1/#target-property), the steps for assessing their order of execution
differs from [animation effects].f

[Custom effects](#custom-effect) are executed after all [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) have completed and applied their result to their
targets (see Applying the composited result).

Need to define this more precisely. Are
styles flushed? Presumably they are. Can we suspend reflow for the
duration of executing the script-based animation effects and just do it
once afterwards?

Within the set of [custom
effects](#custom-effect), the
order of execution is the same as that defined for [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in [§ 3.3.1 The effect stack](#the-effect-stack). Items
sorted earlier are executed before those sorted later.

## 4. Programming interface

### 4.1. The `AnimationTimeline` interface

```
[Exposed=Window]
partial interface AnimationTimeline {
 readonly attribute CSSNumberish? currentTime;
 readonly attribute CSSNumberish? duration;
 Animation play (optional AnimationEffect? effect = null);
};
```

Update the attribute type for currentTime.

[`currentTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), readonly, nullable

: Returns the [current
 time](https://www.w3.org/TR/web-animations-1/#timeline-current-time) for this timeline or `null` if this timeline is
 [inactive](https://www.w3.org/TR/web-animations-1/#inactive-timeline). The value is expressed as a percentage for a
 [progress-based
 timeline](#progress-based-timeline), or as a double in milliseconds otherwise.

[`duration`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), readonly, nullable

: Returns the
 [duration](#timeline-duration) for this timeline.

[` Animation play(optional AnimationEffect? effect = null)`]

: Creates a new
 [`Animation`](https://www.w3.org/TR/web-animations-1/#animation) object associated with this
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) that begins playback as soon as it is
 [ready](#ready).

 If `effect` is specified, it will be used as the
 animation's [associated
 effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect).

 (#issue-6fb09aae) It has been suggested this method be
 renamed, or even removed (see [TAG
 feedback](https://github.com/w3ctag/spec-reviews/blob/master/2013/10/Web%20Animations.md#issue-play-method)).

 (#issue-befeaed2) Need to define the start behavior
 when `effect` is null.

 The new
 [`Animation`](https://www.w3.org/TR/web-animations-1/#animation) object is created using the
 [`Animation()`](https://www.w3.org/TR/web-animations-1/#dom-animation-animation) constructor passing this
 [`AnimationTimeline`](https://www.w3.org/TR/web-animations-1/#animationtimeline) object as the `timeline` parameter and
 `effect` as the `effect` parameter.

 Following construction of the
 [`Animation`](https://www.w3.org/TR/web-animations-1/#animation) object, the procedure to [play an
 animation](#play-an-animation) is performed on the newly constructed object with
 the `auto-rewind` flag set to true.

 ::: parameters

 [`effect`]

 : the [associated
 effect](https://www.w3.org/TR/web-animations-1/#animation-associated-effect) to assign to the newly-created
 [`Animation`](https://www.w3.org/TR/web-animations-1/#animation) object.
 :::

### 4.2. The `Animation` interface

Update the startTime and currentTime of the Animation interface, and add
rangeStart, rangeEnd, and overallProgress as follows:

```
[Exposed=Window]
partial interface Animation {
 attribute CSSNumberish? startTime;
 attribute CSSNumberish? currentTime;
 attribute AnimationTrigger? trigger;
 attribute (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) rangeStart;
 attribute (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) rangeEnd;
 readonly attribute double? overallProgress;
};
```

Add or update attribute descriptions as follows:

[`startTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), nullable

: Update the description as:

 > The [start
 > time](https://www.w3.org/TR/web-animations-1/#animation-start-time) of this animation. When associated with a
 > [progress-based
 > timeline](#progress-based-timeline), [start time]
 > must be returned as a
 > [`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue) with percent units. Otherwise [start
 > time] must be returned as a
 > double value, representing the time in units of milliseconds.
 > Setting this attribute updates the [start
 > time] using the procedure to [set
 > the start time](#set-the-start-time) of this object to the new value.

[`currentTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), nullable

: update the description as:

 > The [current
 > time](https://www.w3.org/TR/web-animations-1/#animation-current-time) of this animation. When associated with a
 > [progress-based
 > timeline](#progress-based-timeline), [current
 > time] must be returned as a
 > [`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue). with percent units. Otherwise [current
 > time] must be returned as a
 > double value, representing the time in units of milliseconds.
 > Setting this attribute follows the procedure to [set the current
 > time](#set-the-current-time) of this object to the new value.

Add:

>
>
> [`rangeStart`], of type `(TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString)`
>
> : Specifies the start of the
> [animation](https://drafts.csswg.org/web-animations-1/#animation)'s [animation attachment
> range](https://www.w3.org/TR/scroll-animations-1/#animation-attachment-range). Setting the attribute follows the same rules as
> the KeyframeAnimationOption
> [rangeStart](#dom-keyframeanimationoptions-rangestart).
> When reading the attribute, the returned value is either a
> [`TimelineRangeOffset`](#dictdef-timelinerangeoffset) or the
> [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) \"normal\".
>
> [`rangeEnd`], of type `(TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString)`
>
> : Specifies the end of the
> [animation](https://drafts.csswg.org/web-animations-1/#animation)'s [animation attachment
> range](https://www.w3.org/TR/scroll-animations-1/#animation-attachment-range). Setting the attribute follows the same rules as
> the KeyframeAnimationOption
> [rangeEnd](#dom-keyframeanimationoptions-rangeend).
> When reading the attribute, the returned value is either a
> [`TimelineRangeOffset`](#dictdef-timelinerangeoffset) or the
> [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) \"normal\".
>
> [`overallProgress`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly, nullable
>
> : Specifies the
> [overallProgress](#animation-overallprogress) of the
> [animation](https://drafts.csswg.org/web-animations-1/#animation) as a proportion of its [associated effect
> end](https://drafts.csswg.org/web-animations-1/#associated-effect-end).
>
> [`trigger`], of type [AnimationTrigger](https://drafts.csswg.org/animation-triggers-1/#animationtrigger), nullable
>
> : Specifies the
> [animation](https://drafts.csswg.org/web-animations-1/#animation)'s associated [animation
> trigger](https://www.w3.org/TR/web-animations-2/#animation-trigger). Setting the attribute follows the same rules as
> the KeyframeAnimationOption
> [trigger](#dom-keyframeanimationoptions-trigger).

### 4.3. The `AnimationEffect` interface

```
[Exposed=Window]
partial interface AnimationEffect {
 // Timing hierarchy
 readonly attribute GroupEffect? parent;
 readonly attribute AnimationEffect? previousSibling;
 readonly attribute AnimationEffect? nextSibling;

 undefined before (AnimationEffect... effects);
 undefined after (AnimationEffect... effects);
 undefined replace (AnimationEffect... effects);
 undefined remove ();
};
```

[`getComputedTiming()`]

: The description of the `duration` attribute of the object needs to
 indicate that if `timing.duration` is the string `auto`, this
 attribute will return the current calculated value of the [intrinsic
 iteration
 duration](#intrinsic-iteration-duration), which may be a expressed as a double representing
 the duration in milliseconds or a percentage when the effect is
 associated with a [progress-based
 timeline](#progress-based-timeline).

[`parent`], of type [GroupEffect](#groupeffect), readonly, nullable

: The [parent group](#parent-group) of this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) or `null` if this [animation
 effect] does not have a [parent
 group].

 (#issue-40288bfc) Should this be `parentGroup`?

[`previousSibling`], of type [AnimationEffect](https://www.w3.org/TR/web-animations-1/#animationeffect), readonly, nullable

: The [previous sibling](#previous-sibling) of this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

[`nextSibling`], of type [AnimationEffect](https://www.w3.org/TR/web-animations-1/#animationeffect), readonly, nullable

: The [next sibling](#next-sibling) of this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

[` undefined before (AnimationEffect... effects)`]

: Inserts `effects` before this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

 1. If there is no [parent
 group](#parent-group),
 abort these steps.

 2. If any of the [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in `effects` is an [inclusive
 ancestor](#inclusive-ancestor) of this [animation
 effect],
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [HierarchyRequestError]
 exception and abort these steps.

 3. [Insert](#insert-children) `effects` before this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

 :::
 Note that this definition precludes the following usage since
 `effect` is an [inclusive
 ancestor](#inclusive-ancestor) of itself:
 ```
 effect.before(effect); // throws HierarchyRequestError
 ```
 :::

[` undefined after(AnimationEffect... effects)`]

: Inserts `effects` after this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect).

 1. If there is no [parent
 group](#parent-group),
 abort these steps.

 2. If any of the [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in `effects` is an [inclusive
 ancestor](#inclusive-ancestor) of this [animation
 effect],
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [HierarchyRequestError]
 exception and abort these steps.

 3. Let `reference child` be the [next sibling of this
 animation effect not in
 `effects`](#next-sibling-not-included).

 4. [Insert](#insert-children) `effects` before
 `reference child`.

[` undefined replace(AnimationEffect... effects)`]

: Replaces this
 [`AnimationEffect`](https://www.w3.org/TR/web-animations-1/#animationeffect) with the passed in `effects`.

 1. If there is no [parent
 group](#parent-group),
 abort these steps.

 2. If any of the [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in `effects` is an [inclusive
 ancestor](#inclusive-ancestor) of the [parent
 group](#parent-group)
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [HierarchyRequestError]
 exception and abort these steps.

 3. Let `reference child` be the [next sibling of this
 animation effect not in
 `effects`](#next-sibling-not-included).

 4. [Remove](#remove-an-animation-effect) this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) from its [parent
 group](#parent-group).

 5. [Insert](#insert-children) `effects` before
 `reference child`.

[`undefined remove()`]

: [Removes](#remove-an-animation-effect) this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) from its [parent
 group](#parent-group) or
 [animation](https://drafts.csswg.org/web-animations-1/#animation).

The `remove()` method can be used to
remove an effect from either its parent group or animation. Should we
keep it in level 1 and define it simply as removing the animation from
its animation?

### 4.4. The `EffectTiming` and `OptionalEffectTiming` dictionaries

```
partial dictionary EffectTiming {
 double delay;
 double endDelay;
 double playbackRate = 1.0;
 (unrestricted double or CSSNumericValue or DOMString) duration = "auto";
};

partial dictionary OptionalEffectTiming {
 double playbackRate;
};
```

 In this version of the spec, duration is not settable
as a CSSNumericValue; however, duration may be returned as a
CSSNumericValue when resolving the duration in
[`getComputedTiming()`](#dom-animationeffect-getcomputedtiming). Future versions of the spec may enable setting the
duration as a
[`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue), where the unit is a valid time unit or percent.

[`delay`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: Update the description as:

 > The [specified start delay] which represents the
 > number of milliseconds from an [animation
 > effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [start
 > time](#animation-effect-start-time) to the start of the [active
 > interval](https://drafts.csswg.org/web-animations-1/#active-interval). The `specified start delay` is
 > converted to a [start delay](#start-delay) following the [normalize specified
 > timing](#normalize-specified-timing) procedure.

[`endDelay`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: Update the description as:

 > The [specified end delay] which represents the number of
 > milliseconds from the end of an [animation
 > effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [active
 > interval](https://drafts.csswg.org/web-animations-1/#active-interval) until the [start
 > time](#animation-effect-start-time) of any [animation
 > effect] that may follow, for
 > example, in a [sequence
 > effect](#sequence-effect). The `specified end delay` is
 > converted to an [end
 > delay](https://drafts.csswg.org/web-animations-1/#end-delay) following the [normalize specified
 > timing](#normalize-specified-timing) procedure.

The [`fill`](https://drafts.csswg.org/web-animations-1/#dom-effecttiming-fill) and [`fill`](https://drafts.csswg.org/web-animations-1/#dom-optionaleffecttiming-fill) members

: Replace:

 > When performing timing calculations the special string value
 > `auto` is expanded to
 > [none](https://drafts.csswg.org/web-animations-1/#fill-mode-none).

 with:

 > When performing timing calculations the special string value
 > `auto` is expanded to one of the [fill
 > modes](https://drafts.csswg.org/web-animations-1/#fill-mode) recognized by the timing model as follows:
 >
 > If the [animation effect](https://drafts.csswg.org/web-animations-1/#animation-effect) to which the fill mode is being applied is a [keyframe effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect),
 >
 > : Use
 > [none](https://drafts.csswg.org/web-animations-1/#fill-mode-none) as the [fill
 > mode](https://drafts.csswg.org/web-animations-1/#fill-mode).
 >
 > Otherwise,
 >
 > : Use
 > [both](https://drafts.csswg.org/web-animations-1/#fill-mode-both) as the [fill
 > mode](https://drafts.csswg.org/web-animations-1/#fill-mode).

[`duration`], of type `(unrestricted double or CSSNumericValue or DOMString)`, defaulting to `"auto"`

: Update the description as:

 > The [specified iteration duration] which is a real
 > number greater than or equal to zero (including positive infinity)
 > representing the time taken in milliseconds to complete a single
 > iteration of the [animation
 > effect](https://drafts.csswg.org/web-animations-1/#animation-effect), or the string value `auto` to indicate that the
 > [iteration
 > duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) reflects the animation effect's [intrinsic
 > iteration
 > duration](#intrinsic-iteration-duration). The `specified iteration duration` is
 > converted to an [iteration
 > duration] following the [normalize
 > specified
 > timing](#normalize-specified-timing) procedure.

[`playbackRate`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `1.0`

: The [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [playback
 rate](#animation-effect-playback-rate) property which is a multiplier applied to the
 [local time](#local-time)
 potentially causing the effect to run at a different rate to its
 natural speed.

### 4.5. Updating the timing of an AnimationEffect

Replace:

> Assign each member that
> [exists](https://infra.spec.whatwg.org/#map-exists) in `input` to the corresponding timing
> property of `effect` as follows:
>
> - [`delay`](#dom-effecttiming-delay) → [start
> delay](#start-delay)
>
> - [`endDelay`](#dom-effecttiming-enddelay) → [end
> delay](https://drafts.csswg.org/web-animations-1/#end-delay)
>
> - [`fill`](https://drafts.csswg.org/web-animations-1/#dom-effecttiming-fill) → [fill
> mode](https://drafts.csswg.org/web-animations-1/#fill-mode)
>
> - [`iterationStart`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-iterationstart) → [iteration
> start](https://drafts.csswg.org/web-animations-1/#iteration-start)
>
> - [`iterations`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-iterations) → [iteration
> count](https://drafts.csswg.org/web-animations-1/#iteration-count)
>
> - [`duration`](#dom-effecttiming-duration) → [iteration
> duration](https://drafts.csswg.org/web-animations-1/#iteration-duration)
>
> - [`direction`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-direction) → [playback
> direction](https://drafts.csswg.org/web-animations-1/#playback-direction)
>
> - [`easing`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-easing) → [timing
> function](https://www.w3.org/TR/css-easing-2/#easing-function)

with:

> Assign each member that
> [exists](https://infra.spec.whatwg.org/#map-exists) in `input` to the corresponding timing
> property of `effect` as follows:
>
> - [`delay`](#dom-effecttiming-delay) → [specified start
> delay](#specified-start-delay)
>
> - [`endDelay`](#dom-effecttiming-enddelay) → [specified end
> delay](#specified-end-delay)
>
> - [`fill`](https://drafts.csswg.org/web-animations-1/#dom-effecttiming-fill) → [fill
> mode](https://drafts.csswg.org/web-animations-1/#fill-mode)
>
> - [`iterationStart`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-iterationstart) → [iteration
> start](https://drafts.csswg.org/web-animations-1/#iteration-start)
>
> - [`iterations`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-iterations) → [iteration
> count](https://drafts.csswg.org/web-animations-1/#iteration-count)
>
> - [`duration`](#dom-effecttiming-duration) → [specified iteration
> duration](#specified-iteration-duration)
>
> - [`direction`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-direction) → [playback
> direction](https://drafts.csswg.org/web-animations-1/#playback-direction)
>
> - [`easing`](https://www.w3.org/TR/web-animations-1/#dom-effecttiming-easing) → [timing
> function](https://www.w3.org/TR/css-easing-2/#easing-function)

Add:

> Follow the procedure to [normalize specified
> timing](#normalize-specified-timing).
>
> Timing properties may also be updated due to a style change. Any
> change to a CSS animation property that affects timing requires
> rerunning the procedure to [normalize specified
> timing](#normalize-specified-timing).

### 4.6. The `ComputedEffectTiming` dictionary

```
partial dictionary ComputedEffectTiming {
 CSSNumberish startTime;
 CSSNumberish endTime;
 CSSNumberish activeDuration;
 CSSNumberish? localTime;
};
```

[`startTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish)

: The [start
 time](#animation-effect-start-time) of this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) expressed as a percentage if associated with a
 [progress-based
 timeline](#progress-based-timeline), or as a double in milliseconds otherwise.

 This is the time at which the [parent
 group](#parent-group), if
 any, has scheduled this child to run within its [transformed time
 space](#transformed-time), that is, the [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [inherited time
 space](#inherited-time).

 The start of the [active
 interval](https://drafts.csswg.org/web-animations-1/#active-interval) is based on the sum of the [start
 time](#animation-effect-start-time) and [start
 delay](#start-delay).

[`endTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish)

: Update the description as:

 > The [end time](#end-time) of
 > the [animation
 > effect](https://drafts.csswg.org/web-animations-1/#animation-effect) in [inherited
 > timespace](#inherited-time). The value is expressed as a percentage if
 > associated with a [progress-based
 > timeline](#progress-based-timeline), or as a double in milliseconds otherwise. This
 > corresponds to the end of the [animation
 > effect]'s active interval plus any
 > [end
 > delay](https://drafts.csswg.org/web-animations-1/#end-delay).

[`activeDuration`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish)

: Update the description as:

 > The [active duration](#active-duration) of this [animation
 > effect](https://drafts.csswg.org/web-animations-1/#animation-effect) expressed as a percentage if associated with a
 > [progress-based
 > timeline](#progress-based-timeline), or as a double in milliseconds otherwise.

[`localTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), nullable

: Update the second paragraph as:

 > This will be `null` if this [animation
 > effect](https://drafts.csswg.org/web-animations-1/#animation-effect) is not [associated with an
 > animation](#associated-with-an-animation) or if it has a [parent
 > group](#parent-group)
 > that is not [in
 > effect](https://drafts.csswg.org/web-animations-1/#in-effect).

 Append:

 > The value is expressed as a percentage if associated with a
 > [progress-based
 > timeline](#progress-based-timeline), or as a double in milliseconds otherwise.

#### 4.6.1. The `FillMode` enumeration

```
enum FillMode { "none", "forwards", "backwards", "both", "auto" };
```

`auto`

: Update the description as:

 > Fill backwards and forwards when applied to a
 > [`GroupEffect`](#groupeffect) and no fill when applied to a
 > [`KeyframeEffect`](https://www.w3.org/TR/web-animations-1/#keyframeeffect).

### 4.7. The `GroupEffect` interface

(This section is added.)

[Group effects](#group-effect)
are represented by the
[`GroupEffect`](#groupeffect) interface.

```
[Exposed=Window]
interface GroupEffect {
 constructor(sequence<AnimationEffect>? children,
 optional (unrestricted double or EffectTiming) timing = );

 readonly attribute AnimationNodeList children;
 readonly attribute AnimationEffect? firstChild;
 readonly attribute AnimationEffect? lastChild;
 GroupEffect clone ();

 undefined prepend (AnimationEffect... effects);
 undefined append (AnimationEffect... effects);
};
```

[`GroupEffect ()`]

: Creates a new
 [`GroupEffect`](#groupeffect) object using the following procedure:

 1. Create a new
 [`GroupEffect`](#groupeffect) object, `group`.

 2. Let `timing input` be the result of applying the
 procedure to [process a timing
 argument](#process-a-timing-argument) to
 [`timing`](#dom-groupeffect-groupeffect-children-timing-timing).

 3. Let `timing input` be the result corresponding to the
 first matching condition from below.

 If `options` is an [`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object,

 : Let `timing input` be `options`.

 Otherwise (if `options` is a `double`),

 : Let `timing input` be a new
 [`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object with all members set to their
 default values and
 [`duration`](#dom-effecttiming-duration) set to `options`.

 4. Call the procedure to [update the timing properties of an
 animation
 effect](https://drafts.csswg.org/web-animations-1/#update-the-timing-properties-of-an-animation-effect) of `group` from
 `timing input`.

 If that procedure causes an exception to be thrown, propagate
 the exception and abort this procedure.

 5. [Insert](#insert-children)
 [`children`](#dom-groupeffect-groupeffect-children-timing-children) before `null`.

 ::: parameters

 [`children`]

 : A sequence of animation effects to add as children of this
 group.

 These children are appended in sequence using the same semantics
 as the
 [`append()`](#dom-groupeffect-append) method of the
 [`GroupEffect`](#groupeffect) interface.

 [`timing`]

 : The timing properties or [iteration
 duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) of the new group effect.
 :::

[`children`], of type [AnimationNodeList](#animationnodelist), readonly

: The list of [child effects](#child-effect) in the group.

[`firstChild`], of type [AnimationEffect](https://www.w3.org/TR/web-animations-1/#animationeffect), readonly, nullable

: The [first child](#first-child) of this [group
 effect](#group-effect).

[`lastChild`], of type [AnimationEffect](https://www.w3.org/TR/web-animations-1/#animationeffect), readonly, nullable

: The [last child](#last-child)
 of this [group effect](#group-effect).

\
undefined prepend (AnimationEffect\... effects)

: 1. If any of the [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in `effects` is an [inclusive
 ancestor](#inclusive-ancestor) of this [animation
 effect],
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [HierarchyRequestError]
 exception and abort these steps.

 2. [Insert](#insert-children) `effects` before the [first
 child](#first-child).

[` undefined append (AnimationEffect... effects)`]

: 1. If any of the [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in `effects` is an [inclusive
 ancestor](#inclusive-ancestor) of this [animation
 effect],
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a [HierarchyRequestError]
 exception and abort these steps.

 2. [Insert](#insert-children) `effects` before `null`.

[` GroupEffect clone ()`]

: Creates a deep copy of this
 [`GroupEffect`](#groupeffect) object using the following procedure.

 1. Let `source` be this
 [`GroupEffect`](#groupeffect) object, the object to be cloned.

 2. Let `cloned timing` be a new
 [`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object whose members are assigned the value of
 the attribute with the same name on
 `source``.getTiming()`.

 3. Let `cloned children` be an empty sequence of
 [`AnimationEffect`](https://www.w3.org/TR/web-animations-1/#animationeffect) objects.

 4. For each `child` in `source``.children`,
 append the result of calling `child``.clone()` to
 `cloned children`.

 5. Return a new
 [`GroupEffect`](#groupeffect) object created by calling the
 [`GroupEffect()`](#dom-groupeffect-groupeffect) constructor with parameters
 `GroupEffect(``cloned children``, ``cloned timing``)`.

#### 4.7.1. Processing a `timing` argument

The `timing` parameter passed to the
[`GroupEffect()`](#dom-groupeffect-groupeffect) or
[`SequenceEffect()`](#dom-sequenceeffect-sequenceeffect) constructor may be an
[`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object, a double representing the duration of the
[animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect) in milliseconds, or undefined.

The following procedure to [process a timing
argument], `timing`, normalizes the above inputs into a
[`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object.

If `timing` is an [`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object,

: Return `timing`.

If `timing` is a `double`,

: Return a new
 [`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object with all members set to their default values
 and
 [`duration`](#dom-effecttiming-duration) set to `timing`.

Otherwise (`timing` is undefined),

: Return a new
 [`EffectTiming`](https://www.w3.org/TR/web-animations-1/#dictdef-effecttiming) object with all members set to their default
 values.

#### 4.7.2. Definitions for manipulating hierarchies

The [next sibling of `effect` not
included] in a set of [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect), `effects` is determined using the following
steps:

1. Let `context effect` be `effect`.

2. While the [next sibling](#next-sibling) of `context effect` is not `null`
 perform the following steps:

 1. Let `context effect` be the [next
 sibling](#next-sibling)
 of `context effect`.

 2. If `context effect` is not in `effects`
 return `context effect` and abort these steps.

3. Return `null`.

To [remove] a `effect` from
its [parent group](#parent-group) or
[animation](https://drafts.csswg.org/web-animations-1/#animation), perform the steps corresponding to the first matching
condition from below, if any:

If `effect` has a [parent group](#parent-group),

: Remove `effect` from the [parent
 group](#parent-group)'s
 list of [child effects](#child-effect).

If `effect` is [directly associated with an animation](#directly-associated-with-an-animation),

: Disassociate `effect` from the
 [animation](https://drafts.csswg.org/web-animations-1/#animation).

To [insert] a series of zero or more [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect), `effects`, to `parent`'s list of
[child effects](#child-effect)
before `reference child` perform the following steps for each
`effect` in `effects`:

1. [Remove](#remove-an-animation-effect) `effect` from its parent.

2. Insert `effect` to `parent`'s list of [child
 effects](#child-effect)
 before `reference child`

### 4.8. The `AnimationNodeList` interface

A list of [animation
effects](https://drafts.csswg.org/web-animations-1/#animation-effect) may be represented by an
[`AnimationNodeList`](#animationnodelist).

The `AnimationNodeList` interface supports indexed properties with
indices in the range 0 ≤ `index` \< `length`.

The only reason this interface exists is to provide a familiar
experience for authors familiar with DOM interfaces where child nodes
are accessed via a `children` member.

```
[Exposed=Window]
interface AnimationNodeList {
 readonly attribute unsigned long length;
 getter AnimationEffect? item (unsigned long index);
};
```

[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The number of [animation
 effects](https://drafts.csswg.org/web-animations-1/#animation-effect) in the list.

[` getter AnimationEffect? item(unsigned long index)`]

: Returns the [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) at `index`. If `index` is greater than or equal to
 `length` returns `null`.

### 4.9. The `SequenceEffect` interfaces

[Sequence effects](#sequence-effect) are represented by the
[`SequenceEffect`](#sequenceeffect) interface.

```
[Exposed=Window]
interface SequenceEffect : GroupEffect {
 constructor(sequence<AnimationEffect>? children,
 optional (unrestricted double or EffectTiming) timing = );

 SequenceEffect clone ();
};
```

[`constructor (sequence<AnimationEffect>? children, optional (unrestricted double or EffectTiming) timing)`]

: The meaning and handling of each of the parameters in this
 constructor is identical to the
 [`GroupEffect()`](#dom-groupeffect-groupeffect) constructor.

[` SequenceEffect clone ()`]

: Creates a deep copy of this
 [`SequenceEffect`](#sequenceeffect) object using the same procedure as defined for the
 [`clone()`](#dom-groupeffect-clone) method of the
 [`GroupEffect`](#groupeffect) interface except that a new
 [`SequenceEffect`](#sequenceeffect) object is created.

### 4.10. The `KeyframeEffect` interfaces

The
[`KeyframeEffect`](https://www.w3.org/TR/web-animations-1/#keyframeeffect) interface is modified to add the
following:

```
partial interface KeyframeEffect {
 attribute IterationCompositeOperation iterationComposite;
};
```

[` KeyframeEffect (target, keyframes, options)`]

: Amend step 5 of the procedure to create a new
 [`KeyframeEffect`](https://www.w3.org/TR/web-animations-1/#keyframeeffect) object as follows:

 5. If `options` is a
 [`KeyframeEffectOptions`](https://www.w3.org/TR/web-animations-1/#dictdef-keyframeeffectoptions) object, assign the
 [`iterationComposite`](#dom-keyframeeffect-iterationcomposite), and
 [`composite`](https://www.w3.org/TR/web-animations-1/#dom-keyframeeffect-composite), properties of `effect` to the
 corresponding value from `options`.

 When assigning these properties, the error-handling defined for
 the corresponding setters on the
 [`KeyframeEffect`](https://www.w3.org/TR/web-animations-1/#keyframeeffect) interface is applied. If any of
 those setters require an exception to be thrown for the values
 specified by `options`, this procedure must
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) the same exception and abort all further steps.

[`KeyframeEffect (source)`]

: Amend the procedure to create a new
 [`KeyframeEffect`](https://www.w3.org/TR/web-animations-1/#keyframeeffect) object with the same properties as
 [`source`](https://www.w3.org/TR/web-animations-1/#dom-keyframeeffect-keyframeeffect-source-source) to include setting the [iteration composite
 operation](#iteration-composite-operation) from `source` on `effect`.

[`iterationComposite`], of type [IterationCompositeOperation](#enumdef-iterationcompositeoperation)

: The [iteration composite
 operation](#iteration-composite-operation) property of this [keyframe
 effect](https://drafts.csswg.org/web-animations-1/#keyframe-effect) as specified by one of the
 [IterationCompositeOperation](#iterationcompositeoperation) enumeration values.

 On setting, sets the [iteration composite
 operation](#iteration-composite-operation) property of this [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) to the provided value.

#### 4.10.1. Creating a new `KeyframeEffect` object

:::: informative-bg
*This section is non-normative*

Replace:

> If the duration is not specified, a value of zero is used.

with:

> If the duration is not specified, the [intrinsic iteration
> duration](#intrinsic-iteration-duration) is used.

Add:

> This is particularly useful in combination with other [animation
> effects](https://drafts.csswg.org/web-animations-1/#animation-effect). For example, fading an element before switching
> [visibility](https://www.w3.org/TR/css-display-4/#propdef-visibility) to 'hidden' can be achieved as
> follows,

```
new SequenceEffect(
 [
 new KeyframeEffect(elem, { opacity: 0 }, 1000),
 new KeyframeEffect(elem, { visibility: 'hidden' }, { fill: 'forwards' })
 ]
);
```

#### 4.10.2. Modification to the `*Keyframe` dictionaries

The `double?` type of the `offset` key in `ComputedKeyframe`,
`BaseComputedKeyframe`, `BaseKeyframe`, `BasePropertyIndexedKeyframe`,
etc. is replaced by
`(CSSNumberish? or TimelineRangeOffset or DOMString)`, where `double`
continues to be interpreted as a percentage, a
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) is parsed into a
[`TimelineRangeOffset`](#dictdef-timelinerangeoffset) according to the syntax of
[\<keyframe-selector\>](https://www.w3.org/TR/css-animations-1/#typedef-keyframe-selector), and the resulting
[`TimelineRangeOffset`](#dictdef-timelinerangeoffset) or
[`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue) is interpreted as defined for
[\@keyframes](https://www.w3.org/TR/css-animations-1/#at-ruledef-keyframes).

If the
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) fails to parse as a valid
[\<keyframe-selector\>](https://www.w3.org/TR/css-animations-1/#typedef-keyframe-selector), then the keyframe is invalid, and
will throw a [TypeError] when
[processed](https://www.w3.org/TR/web-animations-1/#processing-a-keyframes-argument)
(same as if the `double` value was outside the \[0,1\] range).

#### 4.10.3. The KeyframeEffectOptions dictionary

The
[`KeyframeEffectOptions`](https://www.w3.org/TR/web-animations-1/#dictdef-keyframeeffectoptions) dictionary interface is modified to add the following
member:

```
partial dictionary KeyframeEffectOptions {
 IterationCompositeOperation iterationComposite = "replace";
};
```

[`iterationComposite`], of type [IterationCompositeOperation](#enumdef-iterationcompositeoperation), defaulting to `"replace"`

: The [iteration composite
 operation](#iteration-composite-operation) used to define the way animation values build from
 iteration to iteration.

### 4.11. The IterationCompositeOperation enumeration

The possible values of an [animation
effect](https://drafts.csswg.org/web-animations-1/#animation-effect)'s [iteration composite
operation](#iteration-composite-operation) are represented by the
[IterationCompositeOperation] enumeration.

```
enum IterationCompositeOperation { "replace", "accumulate" };
```

`replace`

: Corresponds to the
 [replace](#iteration-composite-operation-replace) [iteration composite
 operation](#iteration-composite-operation) value such that the [effect
 value](https://drafts.csswg.org/web-animations-1/#effect-value) produced is independent of the [current
 iteration](https://drafts.csswg.org/web-animations-1/#current-iteration-index).

`accumulate`

: Corresponds to the
 [accumulate](#iteration-composite-operation-accumulate) iteration composite operation value such that
 subsequent iterations of an [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect) build on the final value of the previous iteration.

### 4.12. The `EffectCallback` callback function

[Custom effects](#custom-effect) can be defined in script by providing an
[`EffectCallback`](#callbackdef-effectcallback) callback function.

```
callback EffectCallback = undefined (double? progress,
 (Element or CSSPseudoElement) currentTarget,
 Animation animation);
```

An
[`EffectCallback`](#callbackdef-effectcallback) is called each time an
[`KeyframeEffect`](https://www.w3.org/TR/web-animations-1/#keyframeeffect) object with which it is associated is
updated.

double? progress

: The [iteration
 progress](https://drafts.csswg.org/web-animations-1/#iteration-progress) value for which to produce an effect. When this is
 `null`, the function SHOULD remove the effect.

(Element or CSSPseudoElement) currentTarget

: The [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) on which this callback is expected to operate.

 :::
 Note that `currentTarget` may differ from
 `animation``.target`.

 If the [target
 element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) of `animation` is changed between
 updates, this method will be called once with a null
 `progress` and the previous [target
 element] as the
 `currentTarget`, then again with the current
 `progress` and the updated [target
 element] as the
 `currentTarget`. This allows the animation effect to be
 removed from the old [target
 element].
 :::

Animation animation

: The
 [`Animation`](https://www.w3.org/TR/web-animations-1/#animation) object that is being updated.

### 4.13. The `Animatable` interface

[`sequence<Animation> getAnimations(``options``)`]

: Add:

 > If this object is the [target
 > element](https://www.w3.org/TR/web-animations-1/#effect-target-target-element) of two or more [animation
 > effects](https://drafts.csswg.org/web-animations-1/#animation-effect) which are associated with the same
 > [animation](https://drafts.csswg.org/web-animations-1/#animation), the corresponding
 > [`Animation`](https://www.w3.org/TR/web-animations-1/#animation) object will still only appear in the returned
 > list once.

### 4.14. The `Animatable` interface mixin

The
[`KeyframeAnimationOptions`](https://www.w3.org/TR/web-animations-1/#dictdef-keyframeanimationoptions) dictionary interface is modified to add the following
members:

```
dictionary TimelineRangeOffset {
 CSSOMString? rangeName;
 CSSNumericValue offset;
};

partial dictionary KeyframeAnimationOptions {
 (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) rangeStart = "normal";
 (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) rangeEnd = "normal";
 AnimationTrigger? trigger;
};
```

[`rangeStart`], of type `(TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString)`, defaulting to `"normal"`

: If present and not \"normal\", specifies the start of the
 [animation](https://drafts.csswg.org/web-animations-1/#animation)'s [animation attachment
 range](https://www.w3.org/TR/scroll-animations-1/#animation-attachment-range). A
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) value is parsed as an
 [animation-range-end](https://www.w3.org/TR/scroll-animations-1/#propdef-animation-range-end) value to yield a
 [`TimelineRangeOffset`](#dictdef-timelinerangeoffset)
 [`rangeName`](#dom-timelinerangeoffset-rangename) and
 [`offset`](#dom-timelinerangeoffset-offset) or alternatively a
 [`CSSKeywordValue`](https://www.w3.org/TR/css-typed-om-1/#csskeywordvalue) with the
 [`value`](https://www.w3.org/TR/css-typed-om-1/#dom-csskeywordvalue-value) of \"normal\"; a
 [`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue) is interpreted as a
 [`TimelineRangeOffset`](#dictdef-timelinerangeoffset) with that
 [`offset`](#dom-timelinerangeoffset-offset) and a null
 [`rangeName`](#dom-timelinerangeoffset-rangename).

[`rangeEnd`], of type `(TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString)`, defaulting to `"normal"`

: If present and not \"normal\", specifies the end of the
 [animation](https://drafts.csswg.org/web-animations-1/#animation)'s [animation attachment
 range](https://www.w3.org/TR/scroll-animations-1/#animation-attachment-range). A
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) value is parsed as an
 [animation-range-end](https://www.w3.org/TR/scroll-animations-1/#propdef-animation-range-end) value to yield a
 [`TimelineRangeOffset`](#dictdef-timelinerangeoffset)
 [`rangeName`](#dom-timelinerangeoffset-rangename) and
 [`offset`](#dom-timelinerangeoffset-offset); a
 [`CSSNumericValue`](https://www.w3.org/TR/css-typed-om-1/#cssnumericvalue) is interpreted as a
 [`TimelineRangeOffset`](#dictdef-timelinerangeoffset) with that
 [`offset`](#dom-timelinerangeoffset-offset) and a null
 [`rangeName`](#dom-timelinerangeoffset-rangename).

Passing a
[`CSSKeywordValue`](https://www.w3.org/TR/css-typed-om-1/#csskeywordvalue) with a
[`value`](https://www.w3.org/TR/css-typed-om-1/#dom-csskeywordvalue-value) other than \"normal\" as the
[`rangeStart`](#dom-keyframeanimationoptions-rangestart) or
[`rangeEnd`](#dom-keyframeanimationoptions-rangeend) value to any API defined to accept
[`KeyframeAnimationOptions`](https://www.w3.org/TR/web-animations-1/#dictdef-keyframeanimationoptions)
[throws](https://webidl.spec.whatwg.org/#dfn-throw) a [TypeError].

 The
[`rangeName`](#dom-timelinerangeoffset-rangename) and
[`offset`](#dom-timelinerangeoffset-offset) values of
[`rangeStart`](#dom-keyframeanimationoptions-rangestart) and
[`rangeEnd`](#dom-keyframeanimationoptions-rangeend) are interpreted as defined for
[animation-range-start](https://www.w3.org/TR/scroll-animations-1/#propdef-animation-range-start)/[animation-range-end](https://www.w3.org/TR/scroll-animations-1/#propdef-animation-range-end), and affect the animation
accordingly.

See [Web Animations § 6.8 The Animatable interface
mixin](https://www.w3.org/TR/web-animations-1/#the-animatable-interface-mixin)
for further description.

### 4.15. The `AnimationPlaybackEvent` interface

Replace double with CSSNumberish as the type for currentTime and
timelineTime.

```
[Exposed=Window]
interface AnimationPlaybackEvent : Event {
 constructor(DOMString type, optional AnimationPlaybackEventInit
 eventInitDict = );
 readonly attribute CSSNumberish? currentTime;
 readonly attribute CSSNumberish? timelineTime;
};
dictionary AnimationPlaybackEventInit : EventInit {
 CSSNumberish? currentTime = null;
 CSSNumberish? timelineTime = null;
};
```

Update the type for the AnimationPlaybackEvent attributes.

[`currentTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), readonly, nullable

: The [current
 time](https://www.w3.org/TR/web-animations-1/#animation-current-time) of the
 [animation](https://drafts.csswg.org/web-animations-1/#animation) that generated the event at the moment the event as
 queued. This will be `null` if the
 [animation] was
 [idle](https://www.w3.org/TR/web-animations-1/#play-state-idle) at the time the event was generated.

[`timelineTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), readonly, nullable

: The [time
 value](https://drafts.csswg.org/web-animations-1/#time-value) of the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) with which the
 [animation](https://drafts.csswg.org/web-animations-1/#animation) that generated the event is associated at the
 moment the event was queued. This will be `null` if the
 [animation] was not associated with an [active
 timeline](https://www.w3.org/TR/web-animations-1/#inactive-timeline) at the time the event was queued.

Update the type for the AnimationPlaybackEventInit members.

[`currentTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), nullable, defaulting to `null`

: See the description of the
 [`currentTime`](#dom-animationplaybackevent-currenttime) attribute.

[`timelineTime`], of type [CSSNumberish](https://www.w3.org/TR/css-typed-om-1/#typedefdef-cssnumberish), nullable, defaulting to `null`

: See the description of the
 [`timelineTime`](#dom-animationplaybackevent-timelinetime) attribute.

### 4.16. Model liveness

::: informative-bg
*This section is non-normative*

Regarding the section on, " Changes made to the Web Animations model
take effect immediately", add:

> The same concept applies to more complex modifications of the Web
> Animations model such as adding and removing children from an
> [`GroupEffect`](#groupeffect).

Add:

>
>
> Changes made to the model using the programming interface do *not* cause any [`EffectCallback`](#callbackdef-effectcallback) functions to be called
>
> : For example, in the following code, the callback function will not
> be called until *after* the script block has completed during
> regular updating.
>
> :::
> (#example-e18684ee)
> ```
> var timesCalled = 0;
> elem.animate(function() {
> timesCalled++;
> }, 10000);
> alert(timesCalled); // Displays ‘0’
> ```
> :::
>
> Need to spec this properly somewhere.

## 5. Changes

### 5.1. Changes since level 1

This specification introduces the following changes compared to the
previous level of this specification:

- [group effects](#group-effect) and [sequence
 effects](#sequence-effect),

- an [animation
 effect](https://drafts.csswg.org/web-animations-1/#animation-effect)-specific [playback
 rate](#animation-effect-playback-rate),

- Support for non-monotonic (scroll) timelines.

This module also includes some exploratory proposals for [§ 3.5 Custom
effects](#custom-effects), however there are some concerns about the
design of this feature and it may be replaced in a future revision. See
[discussion](https://github.com/w3c/csswg-drafts/issues/6861).

### [5.2. ][ Changes since the [First Public Working Draft](https://www.w3.org/TR/2023/WD-web-animations-2-20230221/) of 21 February 2023 ]
- Renamed animation-trigger-type to animation-trigger-behavior
- Corrected mention of start time to current time
- Corrected syntax of rangeStart, rangeEnd, exitRangeStart and
 exitRangeEnd attributes on AnimationTrigger interface ([Issue
 11624](https://github.com/w3c/csswg-drafts/issues/11624))
- Specified the animation-trigger property, added the AnimationTrigger
 interface (https://github.com/w3c/csswg-drafts/pull/10128)
- Changed progress to overallProgress ([Issue
 8799](https://github.com/w3c/csswg-drafts/issues/8799#issuecomment-2461097047))
- Specified Animation progress API ([Issue
 9937](https://github.com/w3c/csswg-drafts/pull/9937))
- Clarified that start time of the animation is auto-aligned with the
 animation range boundary when it has not been explicitly set ([Issue
 9181](https://github.com/w3c/csswg-drafts/pull/9181))
- Fixed IDL definition of KeyframeAnimationOptions
- Expanded offset syntax for keyframes ([Issue
 7637](https://github.com/w3c/csswg-drafts/issues/7637))
- Added rangeStart/rangeEnd to Animatable interface ([Issue
 7589](https://github.com/w3c/csswg-drafts/issues/7589))
- Tidied up effect stack definitions ([Issue
 8497](https://github.com/w3c/csswg-drafts/issues/8497))

## 6. Privacy Considerations

No privacy considerations have been reported on this module.

## 7. Security Considerations

No security considerations have been reported on this module.
