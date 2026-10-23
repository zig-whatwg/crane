## 1. Introduction

*This section is not normative.*

It is often desirable to control the rate at which some value changes.
For example, gradually increasing the speed at which an element moves
can give the element a sense of weight as it appears to gather momentum.
This can be used to produce intuitive user interface elements or
convincing cartoon props that behave like their physical counterparts.
Alternatively, it is sometimes desirable for animation to move forwards
in distinct steps such as a segmented wheel that rotates such that the
segments always appear in the same position.

Similarly, controlling the rate of change of gradient interpolation can
be used to produce different visual effects such as suggesting a concave
or convex surface, or producing a striped effect.

[Easing functions](#easing-function) provide a means to transform such values by taking an
input progress value and producing a corresponding transformed output
progress value.

![Example of an easing function that produces an ease-in effect.\
Given an input progress of 0.7, the easing function scales the value to
produce an output progress of 0.52.\
Applying this easing function to an animation would cause it to progress
more slowly at first but then gradually progress more
quickly.](images/easing-function-example.svg)

### 1.1. Value Definitions

This specification uses the [value definition
syntax](https://www.w3.org/TR/css-values-3/#value-defs) from
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Value types not defined in this specification are defined in CSS Values
& Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Combination with other CSS modules may expand the definitions of these
value types.

## 2. Easing functions

An [easing function] takes an [input progress
value](#easing-function-input-progress-value) and produces an [output progress
value](#easing-function-output-progress-value).

An [easing function](#easing-function) must be a pure function meaning that for a given set of
inputs, it always produces the same [output progress
value](#easing-function-output-progress-value).

The [input progress value] is a
real number in the range \[-∞, ∞\]. Typically, the [input progress
value](#easing-function-input-progress-value) is in the range \[0, 1\] but this may not be the case
when [easing functions](#easing-function) are chained together.

An example of when easing functions are chained together occurs in Web
Animations
[\[WEB-ANIMATIONS\]](#biblio-web-animations "Web Animations")
where the output of the easing function specified on an animation effect
may become the input to an easing function specified on one of the
keyframes of a keyframe effect. In this scenario, the input to the
easing function on the keyframe effect may be outside the range \[0,
1\].

The [output progress value] is a
real number in the range \[-∞, ∞\].

 While CSS numbers have a theoretically infinite range
(see [CSS Values 4 § 5.1 Range Restrictions and Range Definition
Notation](https://drafts.csswg.org/css-values-4/#numeric-ranges)) UAs
will automatically clamp enormous numbers to a reasonable range. If
easing functions are used outside of the CSS context, care must be taken
to either correctly handle potential infinities (including those
produced by merely *very large* values stored in a floating point
number), or clamp the [output progress
value](#easing-function-output-progress-value).

Some types of easing functions also take an additional boolean [before
flag], which indicates the
easing has not yet started, or is going in reverse and is past the
finish. (Some easing functions can have multiple possible [output
progress
values](#easing-function-output-progress-value) for a given [input progress
value](#easing-function-input-progress-value), and generally favor the last one specified; this flag
instead causes those [easing
functions](#easing-function)
to favor the first specified value before the animation has started.)

This specification defines several types of easing functions:

``` prod
<easing-function> = <linear-easing-function>
 | <cubic-bezier-easing-function>
 | <step-easing-function>
```

Tests

- [timing-functions-syntax-computed.html](https://wpt.fyi/results/css/css-easing/timing-functions-syntax-computed.html "css/css-easing/timing-functions-syntax-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/timing-functions-syntax-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/timing-functions-syntax-computed.html)
- [timing-functions-syntax-invalid.html](https://wpt.fyi/results/css/css-easing/timing-functions-syntax-invalid.html "css/css-easing/timing-functions-syntax-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/timing-functions-syntax-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/timing-functions-syntax-invalid.html)
- [timing-functions-syntax-valid.html](https://wpt.fyi/results/css/css-easing/timing-functions-syntax-valid.html "css/css-easing/timing-functions-syntax-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/timing-functions-syntax-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/timing-functions-syntax-valid.html)

### [2.1. ][ Linear Easing Functions: [linear](https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear), [linear()](#funcdef-linear)]
A [linear easing function] is an [easing
function](#easing-function)
that interpolates linearly between its [control
points](#linear-control-point). Each [control point] is a pair of
numbers, associating an [input progress
value](#easing-function-input-progress-value) to an [output progress
value](#easing-function-output-progress-value).

![[linear(0, .1 25%, .75 50%, 1)]\
The shape of the curve follows the [control
points](#linear-control-point).\
Input progress values serve as `x` values of the curve,
whilst the `y` values are the output progress
values.](images/linear-easing-curve.svg)

A [linear easing
function](#linear-easing-function) has the following syntax:

``` prod
<linear-easing-function> = linear | <linear()>
linear() = linear( [ <number> && <percentage>{0,2} ]# )
```

Tests

- [linear-timing-functions-syntax.html](https://wpt.fyi/results/css/css-easing/linear-timing-functions-syntax.html "css/css-easing/linear-timing-functions-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/linear-timing-functions-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/linear-timing-functions-syntax.html)

[linear](https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear)

: Equivalent to [linear(0, 1)]

[linear()](#funcdef-linear)

: Specifies a [linear easing
 function](#linear-easing-function).

 Each comma-separated argument specifies one or two [control
 points](#linear-control-point), with an [input progress
 value](#easing-function-input-progress-value) equal to the specified
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) (converted to a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) between 0 and 1), and an [output
 progress
 value](#easing-function-output-progress-value) equal to the specified
 [\<number\>]. When the argument
 has two [\<percentage\>]s,
 it defines two [control points] in
 the specified order, one per
 [\<percentage\>].

 If an argument lacks a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), its [input progress
 value](#easing-function-input-progress-value) is initially empty. This is corrected at [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) time by [linear()
 canonicalization](#linear-canonicalization).

To [canonicalize a linear()] function's
[control points](#linear-control-point), perform the following:

1. If the first [control
 point](#linear-control-point) lacks an [input progress
 value](#easing-function-input-progress-value), set its [input progress
 value] to 0.

2. If the last [control
 point](#linear-control-point) lacks an [input progress
 value](#easing-function-input-progress-value), set its [input progress
 value] to 1.

3. If any [control
 point](#linear-control-point) has an [input progress
 value](#easing-function-input-progress-value) that is less than the [input progress
 value] of any
 preceding [control point], set its
 [input progress
 value] to the
 largest [input progress
 value] of any
 preceding [control point].

4. If any [control
 point](#linear-control-point) still lacks an [input progress
 value](#easing-function-input-progress-value), then for each contiguous run of such [control
 points], set their [input progress
 values] so that
 they are evenly spaced between the preceding and following [control
 points] with [input progress
 values].

After canonicalization, every [control
point](#linear-control-point) has an [input progress
value](#easing-function-input-progress-value), and the [input progress
values] are
monotonically non-decreasing along the list.

 Serialization relies on whether or not an [input
progress
value](#easing-function-input-progress-value) was originally supplied, so that information should be
retained in the [internal
representation](https://drafts.css-houdini.org/css-typed-om-1/#css-internal-representation). It does not rely on whether a pair of [control
points](#linear-control-point) were specified as two percentages on a single argument
or as separate arguments.

- [linear-timing-functions-chrome-406926307-crash.html](https://wpt.fyi/results/css/css-easing/linear-timing-functions-chrome-406926307-crash.html "css/css-easing/linear-timing-functions-chrome-406926307-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/linear-timing-functions-chrome-406926307-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/linear-timing-functions-chrome-406926307-crash.html)

#### 2.1.1. Serializing

The
[linear](https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear) keyword is serialized as itself.

To [serialize a linear() function]:

1. Let `s` be the string \"linear(\".

2. [Serialize each control
 point](#serialize-a-linear-control-point) of the function,
 [concatenate](https://infra.spec.whatwg.org/#string-concatenate) the results using the separator \", \", and append
 the result to `s`.

3. Append \")\" to `s`, and return it.

To [serialize a linear() control
point]:

1. Let `s` be the serialization, as a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), of the [control
 point's](#linear-control-point) [output progress
 value](#easing-function-output-progress-value).

2. If the [control
 point](#linear-control-point) originally lacked an [input progress
 value](#easing-function-input-progress-value), return `s`.

3. Otherwise, append \" \" (U+0020 SPACE) to `s`, then
 serialize the [control
 point's](#linear-control-point) [input progress
 value](#easing-function-input-progress-value) as a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) and append it to `s`.

4. Return `s`.

When serialized, [control
points](#linear-control-point) originally specified with two [input progress
values](#easing-function-input-progress-value) are turned into two separate [control
points], and the [input progress
values] are in strictly
ascending order. For example:

- [linear(0, 0.25, 1)] serializes as [linear(0, 0.25, 1)]

- [linear(0 20%, 0.5 10%, 1)] serializes as [linear(0 20%, 0.5
 20%, 1)]

- [linear(0, 0.25 25% 75%, 1)] serializes as [linear(0, 0.25 25%,
 0.25 75%, 1)]

#### 2.1.2. Output

To [calculate linear easing output
progress] for a given [linear easing
function](#linear-easing-function) `func`, an [input progress
value](#easing-function-input-progress-value) `inputProgress`, and an optional [before
flag](#easing-function-before-flag) (defaulting to false), perform the following. It
returns an [output progress
value](#easing-function-output-progress-value).

1. Let `points` be `func`'s [control
 points](#linear-control-point).

2. If `points` holds only a single item, return the [output
 progress
 value](#easing-function-output-progress-value) of that item.

3. If `inputProgress` matches the [input progress
 value](#easing-function-input-progress-value) of the first point in `points`, and the
 [before
 flag](#easing-function-before-flag) is true, return the first point's [output progress
 value](#easing-function-output-progress-value).

4. If `inputProgress` matches the [input progress
 value](#easing-function-input-progress-value) of at least one point in `points`,
 return the [output progress
 value](#easing-function-output-progress-value) of the last such point.

5. Otherwise, find two [control
 points](#linear-control-point) in `points`, `A` and
 `B`, which will be used for interpolation:

 1. If `inputProgress` is smaller than any [input
 progress
 value](#easing-function-input-progress-value) in `points`, let `A` and
 `B` be the first two items in `points`. If
 `A` and `B` have the same [input progress
 value], return
 `A`'s [output progress
 value](#easing-function-output-progress-value).

 2. Otherwise, if `inputProgress` is larger than any
 [input progress
 value](#easing-function-input-progress-value) in `points`, let `A` and
 `B` be the last two items in `points`. If
 `A` and `B` have the same [input progress
 value], return
 `B`'s [output progress
 value](#easing-function-output-progress-value).

 3. Otherwise, let `A` be the last [control
 point](#linear-control-point) whose [input progress
 value](#easing-function-input-progress-value) is smaller than `inputProgress`, and
 let `B` be the first [control
 point] whose [input progress
 value] is
 larger than `inputProgress`.

6. Linearly interpolate (or extrapolate) `inputProgress`
 along the line defined by `A` and `B`, and
 return the result.

Tests

- [linear-timing-functions-output.html](https://wpt.fyi/results/css/css-easing/linear-timing-functions-output.html "css/css-easing/linear-timing-functions-output.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/linear-timing-functions-output.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/linear-timing-functions-output.html)

#### 2.1.3. Examples

[linear()](#funcdef-linear) allows the definition of easing functions that
interpolate linearly between a set of points.

For example, [linear(0, 0.25, 1)] produces an easing function that
moves linearly from 0, to 0.25, then to 1:

!(images/simple-linear-example.svg)

<figure>
Easing
Example
<a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear③" class="css"
data->linear</a>
<div class="easing-track" style="--easing:linear">

</div>
<span class="css">linear(0, .25, 1)</span>
<div class="easing-track" style="--easing:linear(0, .25, 1)">

</div>
<figcaption>An example of the above, with a plain <a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear④" class="css"
data->linear</a> for contrast.</figcaption>
</figure>

By default, values are spread evenly
between entries that don't have an explicit \"input\". Input values can
be provided using a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value).

For example, [linear(0, 0.25 75%, 1)] produces the following
easing function, which spends 75% of the time transitioning from
[0] to [.25], then the last 25% transitioning from
[.25] to [1]:

!(images/linear-with-input-example.svg)

<figure>
Easing
Example
<a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear⑤" class="css"
data->linear</a>
<div class="easing-track" style="--easing:linear">

</div>
<span class="css">linear(0, .25 75%, 1)</span>
<div class="easing-track" style="--easing:linear(0, .25 75%, 1)">

</div>
<figcaption>An example of the above, with a plain <a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear⑥" class="css"
data->linear</a> for contrast.</figcaption>
</figure>

If two input values are provided for a
single output, it results in two points with the same output, causing
the easing to \"pause\" between the two inputs.

For example, [linear(0, 0.25 25% 75%, 1)] is equivalent to
[linear(0, 0.25 25%, 0.25 75%, 1)], producing the following easing
function:

!(images/linear-with-double-input-example.svg)

<figure>
Easing
Example
<a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear⑦" class="css"
data->linear</a>
<div class="easing-track" style="--easing:linear">

</div>
<span class="css">linear(0, 0.25 25% 75%, 1)</span>
<div class="easing-track" style="--easing:linear(0, 0.25 25% 75%, 1)">

</div>
<figcaption>An example of the above, with a plain <a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear⑧" class="css"
data->linear</a> for contrast.</figcaption>
</figure>

If the input is outside the range
provided, the trajectory of the nearest two points is continued.

For example, here are the implicit values from the previous function:

!(images/linear-with-double-input-example-continued.svg)

A typical use of
[linear()](#funcdef-linear) is to provide many points to create the illusion of a
curve.

For example, here's how
[linear()](#funcdef-linear) could be used to create a reusable \"bounce\" easing
function:

```
:root {
 --bounce: linear(
 /* Start to 1st bounce */
 0, 0.063, 0.25, 0.563, 1 36.4%,
 /* 1st to 2nd bounce */
 0.812, 0.75, 0.813, 1 72.7%,
 /* 2nd to 3rd bounce */
 0.953, 0.938, 0.953, 1 90.9%,
 /* 3rd bounce to end */
 0.984, 1 100% 100%
 );
}

.example {
 animation-timing-function: var(--bounce);
}
```

The definition ends `1 100% 100%` to create two final points, so inputs
greater than 1 always output 1.

!(images/linear-bounce-example.svg)

<figure>
Easing
Example
<a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear⑨" class="css"
data->linear</a>
<div class="easing-track" style="--easing:linear">

</div>
<span class="css">linear(...)</span>
<div class="easing-track"
style="--easing:linear(0, 0.063, 0.25, 0.563, 1 36.4%, 0.812, 0.75, 0.813, 1 72.7%, 0.953, 0.938, 0.953, 1 90.9%, 0.984, 1 100% 100% )">

</div>
<figcaption>An example of the above, with a plain <a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear①⓪" class="css"
data->linear</a> for contrast.</figcaption>
</figure>

More points could be used to create a smoother result, which may be
needed for slower animations.

### 2.2. Cubic Bézier Easing Functions: [ease, [ease-in](#valdef-cubic-bezier-easing-function-ease-in), [ease-out](#valdef-cubic-bezier-easing-function-ease-out), [ease-in-out](#valdef-cubic-bezier-easing-function-ease-in-out), [cubic-bezier()](#funcdef-cubic-bezier)]
A [cubic Bézier easing function] is an [easing
function](#easing-function)
that interpolates smoothly from 0 to 1 using a cubic polynomial,
influenced by two control points that the curve will approach but
(usually) not actually reach. (The \"endpoints\" of the cubic Bézier are
fixed at (0,0) and (1,1), respectively.)

![A cubic Bézier curve used as an easing function.\
The shape of the curve is determined by the location of the control
points `P1` and `P2`.\
Input progress values serve as `x` values of the curve,
whilst the `y` values are the output progress
values.](images/cubic-bezier-easing-curve.svg)

A [cubic Bézier easing
function](#cubic-bzier-easing-function) has the following syntax:

``` prod
<cubic-bezier-easing-function> =
 ease | ease-in | ease-out | ease-in-out | <cubic-bezier()>

cubic-bezier() = cubic-bezier( [ <number [0,1]>, <number> ]#{2} )
```

The meaning of each value is as follows:

[ease-in]

: A function that starts slowly and smoothly, then quickly approaches
 the endpoint with an almost linear curve. Equivalent to
 [cubic-bezier(0.42, 0, 1, 1)].

[ease-out]

: A function that starts quickly with an almost linear curve, then
 slowly and smoothly approaches the endpoint. Equivalent to
 [cubic-bezier(0, 0, 0.58, 1)].

[ease-in-out]

: A function that starts and ends slowly and smoothly, quickly
 traversing the middle part. Equivalent to [cubic-bezier(0.42, 0,
 0.58, 1)].

[ease]

: Similar to
 [ease-in-out](#valdef-cubic-bezier-easing-function-ease-in-out), but with a quicker start and a slower
 finish. Equivalent to [cubic-bezier(0.25, 0.1, 0.25, 1)].

[cubic-bezier( x1, y1, x2, y2 )]

: Specifies a [cubic Bézier easing
 function](#cubic-bzier-easing-function). The `x1` and `y1` arguments
 specify the first control point, and `x2` and
 `y2` arguments specify the second control point.

 Both `x` values must be in the range \[0, 1\] or the
 definition is invalid.

 Details on cubic Bézier curves

 Note that this does *not* use the [input progress
 value](#easing-function-input-progress-value) as the \"t\" value commonly used to parametrize
 cubic Bézier curves (producing a 2d point as the output), but rather
 uses it as the \"x\" value on the graph (producing a y value as the
 output). This means that only the *shape* of the curve matters, not
 the velocity along that curve. For example, [cubic-bezier(0, 0, 0,
 0)] and [cubic-bezier(1, 1, 1, 1)] produce exactly the
 same (linear) easing, despite the first's *velocity* following a
 `t`^`3`^ curve, while the second follows a `t`^`1/3`^ curve.

 *In general*, cubic Bézier curves can have loops: places where a
 single x value is associated with multiple y values. The restriction
 placed on the control points (that their x values be in the \[0,1\]
 range) prevent this, so the resulting easing function is
 well-defined.

The keyword values listed above are illustrated below.

![The easing functions produced by each of the cubic Bézier easing
function keyword values.](images/curve-keywords.svg)

<figure>
Easing
Example
<a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear①①" class="css"
data->linear</a>
<div class="easing-track" style="--easing:linear">

</div>
<a href="#valdef-cubic-bezier-easing-function-ease-in"
id="ref-for-valdef-cubic-bezier-easing-function-ease-in②" class="css"
data->ease-in</a>
<div class="easing-track" style="--easing:ease-in">

</div>
<a href="#valdef-cubic-bezier-easing-function-ease-out"
id="ref-for-valdef-cubic-bezier-easing-function-ease-out②" class="css"
data->ease-out</a>
<div class="easing-track" style="--easing:ease-out">

</div>
<a href="#valdef-cubic-bezier-easing-function-ease-in-out"
id="ref-for-valdef-cubic-bezier-easing-function-ease-in-out③"
class="css" data->ease-in-out</a>
<div class="easing-track" style="--easing:ease-in-out">

</div>
<a href="#valdef-cubic-bezier-easing-function-ease"
id="ref-for-valdef-cubic-bezier-easing-function-ease②" class="css"
data->ease</a>
<div class="easing-track" style="--easing:ease">

</div>
<figcaption>The above easing functions in action, each applied to a 3s
animation of the circles' <a
href="https://drafts.csswg.org/css-position-3/#propdef-left"
id="ref-for-propdef-left" class="css property"
data->left</a> property. A <a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear①②" class="css"
data->linear</a> easing is provided for
contrast.</figcaption>
</figure>

#### 2.2.1. Serializing

The
[ease-in](#valdef-cubic-bezier-easing-function-ease-in),
[ease-out](#valdef-cubic-bezier-easing-function-ease-out),
[ease-in-out](#valdef-cubic-bezier-easing-function-ease-in-out), and
[ease](#valdef-cubic-bezier-easing-function-ease) keywords serialize as themselves.

To [serialize a cubic-bezier()
function]:

1. Let `s` be the string \"cubic-bezier(\".

2. Serialize the function's four arguments as
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)s,
 [concatenate](https://infra.spec.whatwg.org/#string-concatenate) the results using the separator \", \", and append
 the result to `s`.

3. Append \")\" to `s`, and return it.

#### 2.2.2. Output

To [calculate cubic Bézier easing output
progress]
for a given [cubic Bézier easing
function](#cubic-bzier-easing-function) `func` and an [input progress
value](#easing-function-input-progress-value) `inputProgress`, perform the following. It
returns an [output progress
value](#easing-function-output-progress-value).

1. Let `p0` be the point (0,0), `p1` be the point
 given by `func`'s first two arguments, `p2` be
 the point given by `func`'s second two arguments, and
 `p3` be the point (1,1).

2. If `inputProgress` is within the range \[0,1\]
 (inclusive), return the y value corresponding to
 `inputProgress` as an x value for the cubic Bézier curve
 defined as having `p0` and `p3` as endpoints,
 and `p1` and `p2` as control points.

 The evaluation of this curve is covered in many sources, such as
 [\[FUND-COMP-GRAPHICS\]](#biblio-fund-comp-graphics "Fundamentals of Computer Graphics").

3. Otherwise, the curve is extended infinitely, using the tangent of
 the curve at the endpoints. This tangent is defined as the line
 between two points, `t1` and `t2`.

 - If `inputProgress` is less than 0, let `t1`
 be `p0`.

 1. If the x value of `p1` is greater than 0, let
 `t2` be `p1`.

 2. Otherwise, if the x value of `p2` is greater than
 0, let `t2` be `p2`.

 3. Otherwise, return 0.

 - If `inputProgress` is greater than 1, let
 `t2` be `p3`.

 1. If the x value of `p2` is less than 1, let
 `t1` be `p2`.

 2. Otherwise, if the x value of `p1` is less than 1,
 let `t1` be `p1`.

 3. Otherwise, return 1.

 Return the y value corresponding to `inputProgress` as an
 x value for the line passing through `t1` and
 `t2`.

Tests

- [cubic-bezier-timing-functions-output.html](https://wpt.fyi/results/css/css-easing/cubic-bezier-timing-functions-output.html "css/css-easing/cubic-bezier-timing-functions-output.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/cubic-bezier-timing-functions-output.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/cubic-bezier-timing-functions-output.html)

### 2.3. Step Easing Functions: [step-start, [step-end](#valdef-step-easing-function-step-end), [steps()](#funcdef-steps)]
A [step easing function] is an [easing
function](#easing-function)
that divides the input time into a specified number of intervals that
are equal in length, and holds the output steady within each of those
intervals. It is defined by a number of [steps], and a [step
position]. It has the following syntax:

``` prod
<step-easing-function> = step-start | step-end | <steps()>

steps() = steps( <integer>, <step-position>?)
<step-position> = jump-start | jump-end | jump-none | jump-both
 | start | end
```

Tests

- [step-timing-functions-syntax.html](https://wpt.fyi/results/css/css-easing/step-timing-functions-syntax.html "css/css-easing/step-timing-functions-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/step-timing-functions-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/step-timing-functions-syntax.html)

The meaning of each value is as follows:

[step-start]

: Jumps from the starting to the ending value at the start of the
 easing interval.

 Computes to [steps(1, start)]

[step-end]

: Jumps from the starting to the ending value at the end of the easing
 interval.

 Computes to [steps(1, end)]

 ![Example step easing function keyword
 values.](images/step-easing-keyword-examples.svg)

[steps( \<integer\>, \<step-position\>? )]

: Divides the input interval into a number of equal steps specified by
 the
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value). Within each interval, the
 [output progress
 value](#easing-function-output-progress-value) is constant, and is determined according to the
 [\<step-position\>](#typedef-step-position) keyword. If omitted, the
 [\<step-position\>]
 keyword defaults to
 [end](#valdef-step-position-end).

 If the
 [\<step-position\>](#typedef-step-position) is
 [jump-none](#valdef-step-position-jump-none), the
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) must be at least 2, or the
 function is invalid. Otherwise, the
 [\<integer\>] must be at least
 1, or the function is invalid.

 The
 [\<step-position\>](#typedef-step-position) keywords are:

 [jump-start]

 : The first interval has an [output progress
 value](#easing-function-output-progress-value) of `1/steps`, and subsequent intervals rise by
 `1/steps`.

 (It \"jumps at the start\", with no step returning 0.)

 [jump-end]

 : The first interval has an [output progress
 value](#easing-function-output-progress-value) of `0`, and subsequent intervals rise by
 `1/steps`.

 (It \"jumps at the end\", with no step returning 1.)

 [jump-none]

 : The first interval has an [output progress
 value](#easing-function-output-progress-value) of `0`, and subsequent intervals rise by
 `1/(steps-1)`.

 (It \"never jumps\", with steps returning both 0 and 1.)

 [jump-both]

 : The first interval has an [output progress
 value](#easing-function-output-progress-value) of `1/(steps+1)`, and subsequent intervals rise
 by `1/(steps+1)`.

 (It \"jumps at both ends\", with no steps returning 0 or 1.)

 [start]

 : Behaves as
 [jump-start](#valdef-step-position-jump-start).

 [end]

 : Behaves as
 [jump-end](#valdef-step-position-jump-end).

The [jump-\*] keywords values are illustrated below:

![Example step easing
functions.](images/step-easing-func-examples.svg)

<figure>
Easing
Example
<a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear①③" class="css"
data->linear</a>
<div class="easing-track" style="--easing:linear">

</div>
<span class="css">steps(3, jump-start)</span>
<div class="easing-track" style="--easing:steps(3, jump-start)">

</div>
<span class="css">steps(3, jump-end)</span>
<div class="easing-track" style="--easing:steps(3, jump-end)">

</div>
<span class="css">steps(3, jump-none)</span>
<div class="easing-track" style="--easing:steps(3, jump-none)">

</div>
<span class="css">steps(3, jump-both)</span>
<div class="easing-track" style="--easing:steps(3, jump-both)">

</div>
<figcaption>The above easing functions in action, with a <a
href="https://drafts.csswg.org/css-easing-1/#valdef-easing-function-linear"
id="ref-for-valdef-easing-function-linear①④" class="css"
data->linear</a> provided for comparison. Each <span
class="css">steps(3, ...)</span> function divides the animation into
three constant periods; they differ only on what the value is within
each period.</figcaption>
</figure>

#### 2.3.1. Serializing

Unlike the other [easing
function](#easing-function)
keywords,
[step-start](#valdef-step-easing-function-step-start) and
[step-end](#valdef-step-easing-function-step-end) *do not* serialize as themselves. Instead, they
serialize as \"steps(1, start)\" and \"steps(1)\", respectively.

To [serialize a steps() functions]:

1. Let `s` be the string \"steps(\".

2. Serialize the function's [steps](#steps-steps), and append it to `s`.

3. If the function's [step
 position](#steps-step-position) is
 [end](#valdef-step-position-end) or
 [jump-end](#valdef-step-position-jump-end), append \")\" to `s` and return
 `s`.

4. Otherwise, append \", \" to `s`. Serialize the [step
 position](#steps-step-position) as a keyword, and append the result to
 `s`. Append \")\" to `s`. Return
 `s`.

Tests

- [timing-functions-syntax-computed.html](https://wpt.fyi/results/css/css-easing/timing-functions-syntax-computed.html "css/css-easing/timing-functions-syntax-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/timing-functions-syntax-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/timing-functions-syntax-computed.html)

#### 2.3.2. Output

To [calculate step easing output
progress] for a given [step easing
function](#step-easing-function) `func`, an [input progress
value](#easing-function-input-progress-value) `inputProgress`, and an optional [before
flag](#easing-function-before-flag) (defaulting to false), perform the following. It
returns an [output progress
value](#easing-function-output-progress-value).

1. If the [before
 flag](#easing-function-before-flag) is true, return 0.

2. Let `steps` be `func`'s
 [steps](#steps-steps), and
 `position` be `func`'s [step
 position](#steps-step-position).

3. Divide the interval \[-∞, ∞\] into several segments, each with an
 associated value, as follows:

 1. \[-∞, 0) has the value 0.

 2. \[1, ∞\] has the value 1.

 3. \[0, 1) is divided into `steps` half-open intervals,
 \[0, \...) to \[\..., 1) with their values assigned as defined
 for the `position` (see
 [\<step-position\>](#typedef-step-position)).

 In other words, at the boundary between intervals,
 the associated value is the higher value.

4. Return the associated value for the interval that
 `inputProgress` is in.

Tests

- [step-timing-functions-output.html](https://wpt.fyi/results/css/css-easing/step-timing-functions-output.html "css/css-easing/step-timing-functions-output.html")
 [[(live
 test)]](http://wpt.live/css/css-easing/step-timing-functions-output.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-easing/step-timing-functions-output.html)

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

This specification does not directly introduce any new capabilities to
the Web platform but rather provides common definitions that may be
referenced by other specifications.

## [Security Considerations]
Specifications referencing the features defined in this specification
should consider that while easing functions most commonly take an [input
progress
value](#easing-function-input-progress-value) in the range \[0,1\] and produce an [output progress
value](#easing-function-output-progress-value) in the range \[0, 1\], this is not always the case.
Applications of easing functions should define the behavior for inputs
and outputs outside this range to ensure they do not introduce new
security considerations.

## 3. Changes

### [3.1. ][ Changes since the FPWD of [28 August 2024](https://www.w3.org/TR/2024/WD-css-easing-2-20240828/) ]
-

### 3.2. Additions Since Level 1

- Added [linear()](#funcdef-linear) function.

## 4. Acknowledgements

This specification is based on the [CSS
Transitions](https://www.w3.org/TR/css3-transitions/) specification
edited by L. David Baron, Dean Jackson, David Hyatt, and Chris Marrin.
The editors would also like to thank Douglas Stockwell, Steve Block, Tab
Atkins, Rachel Nabors, Martin Pitt, and the [Animation at
Work](https://damp-lake-50659.herokuapp.com/) slack community for their
feedback and contributions.
