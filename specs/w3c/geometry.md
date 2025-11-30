## 1. Introduction

*This section is non-normative.*

This specification describes several geometry interfaces for the
representation of points, rectangles, quadrilaterals and transformation
matrices with the dimension of 3x2 and 4x4.

The SVG interfaces [`SVGPoint`](#svgpoint), [`SVGRect`](#svgrect) and [`SVGMatrix`](#svgmatrix) are aliasing the here defined interfaces in favor for
common interfaces used by SVG, Canvas 2D Context and CSS Transforms.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")
[\[HTML\]](#biblio-html "HTML Standard")
[\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

## 2. The DOMPoint interfaces

A 2D or a 3D [point] can be represented by the following WebIDL interfaces:

```
[Exposed=(Window,Worker),
 Serializable]
interface DOMPointReadOnly {
 constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
 optional unrestricted double z = 0, optional unrestricted double w = 1);

 [NewObject] static DOMPointReadOnly fromPoint(optional DOMPointInit other = );

 readonly attribute unrestricted double x;
 readonly attribute unrestricted double y;
 readonly attribute unrestricted double z;
 readonly attribute unrestricted double w;

 [NewObject] DOMPoint matrixTransform(optional DOMMatrixInit matrix = );

 [Default] object toJSON();
};

[Exposed=(Window,Worker),
 Serializable,
 LegacyWindowAlias=SVGPoint]
interface DOMPoint : DOMPointReadOnly {
 constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
 optional unrestricted double z = 0, optional unrestricted double w = 1);

 [NewObject] static DOMPoint fromPoint(optional DOMPointInit other = );

 inherit attribute unrestricted double x;
 inherit attribute unrestricted double y;
 inherit attribute unrestricted double z;
 inherit attribute unrestricted double w;
};

dictionary DOMPointInit {
 unrestricted double x = 0;
 unrestricted double y = 0;
 unrestricted double z = 0;
 unrestricted double w = 1;
};
```

The following algorithms assume that
[`DOMPointReadOnly`](#dompointreadonly) objects have the internal member variables [x
coordinate], [y coordinate], [z
coordinate] and [w
perspective].
[`DOMPointReadOnly`](#dompointreadonly) as well as the inheriting interface
[`DOMPoint`](#dompoint) must
be able to access and set the value of these variables.

An interface returning an
[`DOMPointReadOnly`](#dompointreadonly) object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The
[`DOMPointReadOnly(``x``, ``y``, ``z``, ``w``)`]
and
[`DOMPoint(``x``, ``y``, ``z``, ``w``)`]
constructors, when invoked, must run the following steps:

1. Let `point` be a new
 [`DOMPointReadOnly`](#dompointreadonly) or [`DOMPoint`](#dompoint) object as appropriate.

2. Set `point`'s variables [x
 coordinate](#point-x-coordinate) to `x`, [y
 coordinate](#point-y-coordinate) to `y`, [z
 coordinate](#point-z-coordinate) to `z` and [w
 perspective](#point-w-perspective) to `w`.

3. Return `point`.

The [`fromPoint(``other``)`] static method on
[`DOMPointReadOnly`](#dompointreadonly) must [create a `DOMPointReadOnly` from the
dictionary](#create-a-dompointreadonly-from-the-dictionary) `other`.

The [`fromPoint(``other``)`] static method on
[`DOMPoint`](#dompoint) must
[create a `DOMPoint` from the
dictionary](#create-a-dompoint-from-the-dictionary) `other`.

To [create a `DOMPointReadOnly` from a
dictionary]
`other`, or to [create a `DOMPoint` from a
dictionary] `other`, follow these steps:

1. Let `point` be a new
 [`DOMPointReadOnly`](#dompointreadonly) or [`DOMPoint`](#dompoint) as appropriate.

2. Set `point`'s variables [x
 coordinate](#point-x-coordinate) to `other`'s
 [`x`](#dom-dompointinit-x) dictionary member, [y
 coordinate](#point-y-coordinate) to `other`'s
 [`y`](#dom-dompointinit-y) dictionary member, [z
 coordinate](#point-z-coordinate) to `other`'s
 [`z`](#dom-dompointinit-z) dictionary member and [w
 perspective](#point-w-perspective) to `other`'s
 [`w`](#dom-dompointinit-w) dictionary member.

3. Return `point`.

The [`x`]
attribute, on getting, must return the [x
coordinate](#point-x-coordinate) value. For the
[`DOMPoint`](#dompoint)
interface, setting the
[`x`](#dom-dompointreadonly-x) attribute must set the [x
coordinate] to the new value.

The [`y`]
attribute, on getting, must return the [y
coordinate](#point-y-coordinate) value. For the
[`DOMPoint`](#dompoint)
interface, setting the
[`y`](#dom-dompointreadonly-y) attribute must set the [y
coordinate] to the new value.

The [`z`]
attribute, on getting, must return the [z
coordinate](#point-z-coordinate) value. For the
[`DOMPoint`](#dompoint)
interface, setting the
[`z`](#dom-dompointreadonly-z) attribute must set the [z
coordinate] to the new value.

The [`w`]
attribute, on getting, must return the [w
perspective](#point-w-perspective) value. For the
[`DOMPoint`](#dompoint)
interface, setting the
[`w`](#dom-dompointreadonly-w) attribute must set the [w
perspective] to the new value.

The
[`matrixTransform(``matrix``)`] method, when
invoked, must run the following steps:

1. Let `matrixObject` be the result of invoking [create a
 `DOMMatrix` from the
 dictionary](#create-a-dommatrix-from-the-dictionary) `matrix`.

2. Return the result of invoking [transform a point with a
 matrix](#transform-a-point-with-a-matrix), given the current point and
 `matrixObject`. The current point does not get modified.

(#example-81a83758) In this example the method
[`matrixTransform()`](#dom-dompointreadonly-matrixtransform) on a [`DOMPoint`](#dompoint) instance is called with a
[`DOMMatrix`](#dommatrix)
instance as argument.

``` highlight
var point = new DOMPoint(5, 4);
var matrix = new DOMMatrix([2, 0, 0, 2, 10, 10]);
var transformedPoint = point.matrixTransform(matrix);
```

The `point` variable is set to a new
[`DOMPoint`](#dompoint)
object with [x
coordinate](#point-x-coordinate) initialized to 5 and [y
coordinate](#point-y-coordinate) initialized to 4. This new
[`DOMPoint`](#dompoint) is
now scaled and the translated by `matrix`. This resulting
`transformedPoint` has the [x
coordinate] 20 and [y
coordinate] 18.

### 2.1. Transforming a point with a matrix

To [transform a [point](#point) with a
[matrix](#matrix)], given `point` and
`matrix`:

1. Let `x` be `point`'s [x
 coordinate](#point-x-coordinate).

2. Let `y` be `point`'s [y
 coordinate](#point-y-coordinate).

3. Let `z` be `point`'s [z
 coordinate](#point-z-coordinate).

4. Let `w` be `point`'s [w
 perspective](#point-w-perspective).

5. Let `pointVector` be a new column vector with the
 elements being `x`, `y`, `z`, and
 `w`, respectively.

 $\begin{bmatrix}
 x \\
 y \\
 z \\
 w
 \end{bmatrix}$

6. Set `pointVector` to `pointVector`
 [pre-multiplied](#pre-multiply) by `matrix`.

7. Let `transformedPoint` be a new
 [`DOMPoint`](#dompoint)
 object.

8. Set `transformedPoint`'s [x
 coordinate](#point-x-coordinate) to `pointVector`'s first element.

9. Set `transformedPoint`'s [y
 coordinate](#point-y-coordinate) to `pointVector`'s second element.

10. Set `transformedPoint`'s [z
 coordinate](#point-z-coordinate) to `pointVector`'s third element.

11. Set `transformedPoint`'s [w
 perspective](#point-w-perspective) to `pointVector`'s fourth element.

12. Return `transformedPoint`.

 If `matrix`'s [is
2D](#matrix-is-2d) is true,
`point`'s [z
coordinate](#point-z-coordinate) is [0] or [-0], and `point`'s [w
perspective](#point-w-perspective) is [1], then this is a 2D transformation.
Otherwise this is a 3D transformation.

## 3. The DOMRect interfaces

Objects implementing the
[`DOMRectReadOnly`](#domrectreadonly) interface represent a [rectangle].

[Rectangles](#rectangle) have the
following properties:

[origin]

: When the rectangle has a non-negative [width
 dimension](#rectangle-width-dimension), the rectangle's horizontal origin is the left
 edge; otherwise, it is the right edge. Similarly, when the rectangle
 has a non-negative [height
 dimension](#rectangle-height-dimension), the rectangle's vertical origin is the top edge;
 otherwise, it is the bottom edge.

[x coordinate]

: The horizontal distance between the viewport's left edge and the
 rectangle's [origin](#rectangle-origin).

[y coordinate]

: The vertical distance between the viewport's top edge and the
 rectangle's [origin](#rectangle-origin).

[width dimension]

: The width of the rectangle. Can be negative.

[height dimension]

: The height of the rectangle. Can be negative.

```
[Exposed=(Window,Worker),
 Serializable]
interface DOMRectReadOnly {
 constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
 optional unrestricted double width = 0, optional unrestricted double height = 0);

 [NewObject] static DOMRectReadOnly fromRect(optional DOMRectInit other = );

 readonly attribute unrestricted double x;
 readonly attribute unrestricted double y;
 readonly attribute unrestricted double width;
 readonly attribute unrestricted double height;
 readonly attribute unrestricted double top;
 readonly attribute unrestricted double right;
 readonly attribute unrestricted double bottom;
 readonly attribute unrestricted double left;

 [Default] object toJSON();
};

[Exposed=(Window,Worker),
 Serializable,
 LegacyWindowAlias=SVGRect]
interface DOMRect : DOMRectReadOnly {
 constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
 optional unrestricted double width = 0, optional unrestricted double height = 0);

 [NewObject] static DOMRect fromRect(optional DOMRectInit other = );

 inherit attribute unrestricted double x;
 inherit attribute unrestricted double y;
 inherit attribute unrestricted double width;
 inherit attribute unrestricted double height;
};

dictionary DOMRectInit {
 unrestricted double x = 0;
 unrestricted double y = 0;
 unrestricted double width = 0;
 unrestricted double height = 0;
};
```

The following algorithms assume that
[`DOMRectReadOnly`](#domrectreadonly) objects have the internal member variables [x
coordinate](#rectangle-x-coordinate), [y
coordinate](#rectangle-y-coordinate), [width
dimension](#rectangle-width-dimension) and [height
dimension](#rectangle-height-dimension).
[`DOMRectReadOnly`](#domrectreadonly) as well as the inheriting interface
[`DOMRect`](#domrect) must be
able to access and set the value of these variables.

An interface returning an
[`DOMRectReadOnly`](#domrectreadonly) object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The
[`DOMRectReadOnly(``x``, ``y``, ``width``, ``height``)`]
and
[`DOMRect(``x``, ``y``, ``width``, ``height``)`]
constructors, when invoked, must run the following steps:

1. Let `rect` be a new
 [`DOMRectReadOnly`](#domrectreadonly) or [`DOMRect`](#domrect) object as appropriate.

2. Set `rect`'s variables [x
 coordinate](#rectangle-x-coordinate) to `x`, [y
 coordinate](#rectangle-y-coordinate) to `y`, [width
 dimension](#rectangle-width-dimension) to `width` and [height
 dimension](#rectangle-height-dimension) to `height`.

3. Return `rect`.

The [`fromRect(``other``)`] static method on
[`DOMRectReadOnly`](#domrectreadonly) must [create a `DOMRectReadOnly` from the
dictionary](#create-a-domrectreadonly-from-the-dictionary) `other`.

The [`fromRect(``other``)`] static method on
[`DOMRect`](#domrect) must
[create a `DOMRect` from the
dictionary](#create-a-domrect-from-the-dictionary) `other`.

To [create a `DOMRectReadOnly` from a
dictionary]
`other`, or to [create a `DOMRect` from a
dictionary] `other`, follow these steps:

1. Let `rect` be a new
 [`DOMRectReadOnly`](#domrectreadonly) or [`DOMRect`](#domrect) as appropriate.

2. Set `rect`'s variables [x
 coordinate](#rectangle-x-coordinate) to `other`'s
 [`x`](#dom-domrectinit-x) dictionary member, [y
 coordinate](#rectangle-y-coordinate) to `other`'s
 [`y`](#dom-domrectinit-y) dictionary member, [width
 dimension](#rectangle-width-dimension) to `other`'s
 [`width`](#dom-domrectinit-width) dictionary member and [height
 dimension](#rectangle-height-dimension) to `other`'s
 [`height`](#dom-domrectinit-height) dictionary member.

3. Return `rect`.

The [`x`]
attribute, on getting, must return the [x
coordinate](#rectangle-x-coordinate) value. For the
[`DOMRect`](#domrect)
interface, setting the
[`x`](#dom-domrect-x)
attribute must set the [x coordinate]
to the new value.

The [`y`]
attribute, on getting, it must return the [y
coordinate](#rectangle-y-coordinate) value. For the
[`DOMRect`](#domrect)
interface, setting the
[`y`](#dom-domrect-y)
attribute must set the [y coordinate]
to the new value.

The [`width`] attribute, on getting, must return the [width
dimension](#rectangle-width-dimension) value. For the
[`DOMRect`](#domrect)
interface, setting the
[`width`](#dom-domrect-width) attribute must set the [width
dimension] to the new value.

The [`height`] attribute, on getting, must return the [height
dimension](#rectangle-height-dimension) value. For the
[`DOMRect`](#domrect)
interface, setting the
[`height`](#dom-domrect-height) attribute must set the [height
dimension] value to the new value.

The [`top`]
attribute, on getting, must return the [NaN-safe
minimum](#nan-safe-minimum)
of the [y
coordinate](#rectangle-y-coordinate) and the sum of the [y
coordinate] and the [height
dimension](#rectangle-height-dimension).

The [`right`] attribute, on getting, must return the [NaN-safe
maximum](#nan-safe-maximum)
of the [x
coordinate](#rectangle-x-coordinate) and the sum of the [x
coordinate] and the [width
dimension](#rectangle-width-dimension).

The [`bottom`] attribute, on getting, must return the [NaN-safe
maximum](#nan-safe-maximum)
of the [y
coordinate](#rectangle-y-coordinate) and the sum of the [y
coordinate] and the [height
dimension](#rectangle-height-dimension).

The [`left`] attribute, on getting, must return the [NaN-safe
minimum](#nan-safe-minimum)
of the [x
coordinate](#rectangle-x-coordinate) and the sum of the [x
coordinate] and the [width
dimension](#rectangle-width-dimension).

## 4. The DOMRectList interface

```
[Exposed=Window]
interface DOMRectList {
 readonly attribute unsigned long length;
 getter DOMRect? item(unsigned long index);
};
```

The [`length`] attribute must
return the total number of
[`DOMRect`](#domrect) objects
associated with the object.

The [`item(``index``)`] method, when invoked, must return [null] when
`index` is greater than or equal to the number of
[`DOMRect`](#domrect) objects
associated with the
[`DOMRectList`](#domrectlist). Otherwise, the
[`DOMRect`](#domrect) object
at `index` must be returned. Indices are zero-based.

**[`DOMRectList`](#domrectlist) only exists for compatibility with legacy Web content.
When specifying a new API,
[`DOMRectList`](#domrectlist) must not be used. Use `sequence<DOMRect>` instead.
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard")**

## 5. The DOMQuad interface

Objects implementing the [`DOMQuad`](#domquad) interface represents a [quadrilateral].

```
[Exposed=(Window,Worker),
 Serializable]
interface DOMQuad {
 constructor(optional DOMPointInit p1 = , optional DOMPointInit p2 = ,
 optional DOMPointInit p3 = , optional DOMPointInit p4 = );

 [NewObject] static DOMQuad fromRect(optional DOMRectInit other = );
 [NewObject] static DOMQuad fromQuad(optional DOMQuadInit other = );

 [SameObject] readonly attribute DOMPoint p1;
 [SameObject] readonly attribute DOMPoint p2;
 [SameObject] readonly attribute DOMPoint p3;
 [SameObject] readonly attribute DOMPoint p4;
 [NewObject] DOMRect getBounds();

 [Default] object toJSON();
};

dictionary DOMQuadInit {
 DOMPointInit p1;
 DOMPointInit p2;
 DOMPointInit p3;
 DOMPointInit p4;
};
```

The following algorithms assume that
[`DOMQuad`](#domquad) objects
have the internal member variables [point 1], [point
2], [point 3], and [point 4], which are
[`DOMPoint`](#dompoint)
objects. [`DOMQuad`](#domquad)
must be able to access and set the value of these variables. The author
can modify these [`DOMPoint`](#dompoint) objects, which directly affects the quadrilateral.

An interface returning a [`DOMQuad`](#domquad) object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The
[`DOMQuad(``p1``, ``p2``, ``p3``, ``p4``)`]
constructor, when invoked, must run the following steps:

1. Let `point1` be a new
 [`DOMPoint`](#dompoint)
 object with its attributes set to the values of the namesake
 dictionary members in `p1`.

2. Let `point2` be a new
 [`DOMPoint`](#dompoint)
 object with its attributes set to the values of the namesake
 dictionary members in `p2`.

3. Let `point3` be a new
 [`DOMPoint`](#dompoint)
 object with its attributes set to the values of the namesake
 dictionary members in `p3`.

4. Let `point4` be a new
 [`DOMPoint`](#dompoint)
 object with its attributes set to the values of the namesake
 dictionary members in `p4`.

5. Return a new [`DOMQuad`](#domquad) with [point
 1](#quadrilateral-point-1) set to `point1`, [point
 2](#quadrilateral-point-2) set to `point2`, [point
 3](#quadrilateral-point-3) set to `point3` and [point
 4](#quadrilateral-point-4) set to `point4`.

 It is possible to pass
[`DOMPoint`](#dompoint)/[`DOMPointReadOnly`](#dompointreadonly) arguments as well. The passed arguments will be
transformed to the correct object type internally following the WebIDL
rules.
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard")

The [`fromRect(``other``)`] static method on
[`DOMQuad`](#domquad) must
[create a `DOMQuad` from the `DOMRectInit`
dictionary](#create-a-domquad-from-the-domrectinit-dictionary) `other`.

To [create a `DOMQuad` from a `DOMRectInit`
dictionary]
`other`, follow these steps:

1. Let `x`, `y`, `width` and
 `height` be the value of `other`'s
 [`x`](#dom-domrectinit-x),
 [`y`](#dom-domrectinit-y),
 [`width`](#dom-domrectinit-width) and
 [`height`](#dom-domrectinit-height) dictionary members, respectively.

2. Let `point1` be a new
 [`DOMPoint`](#dompoint)
 object with [x
 coordinate](#point-x-coordinate) set to `x`, [y
 coordinate](#point-y-coordinate) set to `y`, [z
 coordinate](#point-z-coordinate) set to [0] and [w
 perspective](#point-w-perspective) set to [1].

3. Let `point2` be a new
 [`DOMPoint`](#dompoint)
 object with [x
 coordinate](#point-x-coordinate) set to `x` + `width`, [y
 coordinate](#point-y-coordinate) set to `y`, [z
 coordinate](#point-z-coordinate) set to [0] and [w
 perspective](#point-w-perspective) set to [1].

4. Let `point3` be a new
 [`DOMPoint`](#dompoint)
 object with [x
 coordinate](#point-x-coordinate) set to `x` + `width`, [y
 coordinate](#point-y-coordinate) set to `y` + `height`, [z
 coordinate](#point-z-coordinate) set to [0] and [w
 perspective](#point-w-perspective) set to [1].

5. Let `point4` be a new
 [`DOMPoint`](#dompoint)
 object with [x
 coordinate](#point-x-coordinate) set to `x`, [y
 coordinate](#point-y-coordinate) set to `y` + `height`, [z
 coordinate](#point-z-coordinate) set to [0] and [w
 perspective](#point-w-perspective) set to [1].

6. Return a new [`DOMQuad`](#domquad) with [point
 1](#quadrilateral-point-1) set to `point1`, [point
 2](#quadrilateral-point-2) set to `point2`, [point
 3](#quadrilateral-point-3) set to `point3` and [point
 4](#quadrilateral-point-4) set to `point4`.

The [`fromQuad(``other``)`] static method on
[`DOMQuad`](#domquad) must
[create a `DOMQuad` from the `DOMQuadInit`
dictionary](#create-a-domquad-from-the-domquadinit-dictionary) `other`.

To [create a `DOMQuad` from a `DOMQuadInit`
dictionary]
`other`, follow these steps:

1. Let `point1` be the result of invoking [create a
 `DOMPoint` from the
 dictionary](#create-a-dompoint-from-the-dictionary)
 [`p1`](#dom-domquadinit-p1) dictionary member of `other`, if it
 exists.

2. Let `point2` be the result of invoking [create a
 `DOMPoint` from the
 dictionary](#create-a-dompoint-from-the-dictionary)
 [`p2`](#dom-domquadinit-p2) dictionary member of `other`, if it
 exists.

3. Let `point3` be the result of invoking [create a
 `DOMPoint` from the
 dictionary](#create-a-dompoint-from-the-dictionary)
 [`p3`](#dom-domquadinit-p3) dictionary member of `other`, if it
 exists.

4. Let `point4` be the result of invoking [create a
 `DOMPoint` from the
 dictionary](#create-a-dompoint-from-the-dictionary)
 [`p4`](#dom-domquadinit-p4) dictionary member of `other`, if it
 exists.

5. Return a new [`DOMQuad`](#domquad) with [point
 1](#quadrilateral-point-1) set to `point1`, [point
 2](#quadrilateral-point-2) set to `point2`, [point
 3](#quadrilateral-point-3) set to `point3` and [point
 4](#quadrilateral-point-4) set to `point4`.

The [`p1`] attribute must return [point
1](#quadrilateral-point-1).

The [`p2`] attribute must return [point
2](#quadrilateral-point-2).

The [`p3`] attribute must return [point
3](#quadrilateral-point-3).

The [`p4`] attribute must return [point
4](#quadrilateral-point-4).

The [`getBounds()`] method, when invoked,
must run the following algorithm:

1. Let `bounds` be a
 [`DOMRect`](#domrect)
 object.

2. Let `left` be the [NaN-safe
 minimum](#nan-safe-minimum) of [point
 1](#quadrilateral-point-1)'s [x
 coordinate](#point-x-coordinate), [point
 2](#quadrilateral-point-2)'s [x coordinate],
 [point 3](#quadrilateral-point-3)'s [x coordinate] and
 [point 4](#quadrilateral-point-4)'s [x coordinate].

3. Let `top` be the [NaN-safe
 minimum](#nan-safe-minimum) of [point
 1](#quadrilateral-point-1)'s [y
 coordinate](#point-y-coordinate), [point
 2](#quadrilateral-point-2)'s [y coordinate],
 [point 3](#quadrilateral-point-3)'s [y coordinate] and
 [point 4](#quadrilateral-point-4)'s [y coordinate].

4. Let `right` be the [NaN-safe
 maximum](#nan-safe-maximum) of [point
 1](#quadrilateral-point-1)'s [x
 coordinate](#point-x-coordinate), [point
 2](#quadrilateral-point-2)'s [x coordinate],
 [point 3](#quadrilateral-point-3)'s [x coordinate] and
 [point 4](#quadrilateral-point-4)'s [x coordinate].

5. Let `bottom` be the [NaN-safe
 maximum](#nan-safe-maximum) of [point
 1](#quadrilateral-point-1)'s [y
 coordinate](#point-y-coordinate), [point
 2](#quadrilateral-point-2)'s [y coordinate],
 [point 3](#quadrilateral-point-3)'s [y coordinate] and
 [point 4](#quadrilateral-point-4)'s [y coordinate].

6. Set [x
 coordinate](#rectangle-x-coordinate) of `bounds` to `left`, [y
 coordinate](#rectangle-y-coordinate) of `bounds` to `top`, [width
 dimension](#rectangle-width-dimension) of `bounds` to `right` -
 `left` and [height
 dimension](#rectangle-height-dimension) of `bounds` to `bottom` -
 `top`.

7. Return `bounds`.

(#example-9bbe24bd) In this example the
[`DOMQuad`](#domquad)
constructor is called with arguments of type
[`DOMPoint`](#dompoint) and
[`DOMPointInit`](#dictdef-dompointinit). Both arguments are accepted and can be used.

``` highlight
var point = new DOMPoint(2, 0);
var quad1 = new DOMQuad(point, {x: 12, y: 0}, {x: 12, y: 10}, {x: 2, y: 10});
```

The attribute values of the resulting
[`DOMQuad`](#domquad)
`quad1` above are also equivalent to the attribute values of
the following [`DOMQuad`](#domquad) `quad2`:

``` highlight
var rect = new DOMRect(2, 0, 10, 10);
var quad2 = DOMQuad.fromRect(rect);
```

(#example-b13b531b) This is an example of an irregular
quadrilateral:

``` highlight
new DOMQuad({x: 40, y: 25}, {x: 180, y: 8}, {x: 210, y: 150}, {x: 10, y: 180});
```

![An irregular quadrilateral represented by a
[`DOMQuad`](#domquad). The
four red colored circles represent the
[`DOMPoint`](#dompoint)
attributes [`p1`](#dom-domquad-p1) to
[`p4`](#dom-domquad-p4).
The dashed rectangle represents the bounding rectangle returned by the
[`getBounds()`](#dom-domquad-getbounds) method of the
[`DOMQuad`](#domquad).](data:image/svg+xml;base64,PHN2ZyBhcmlhLWxhYmVsPSJBbiBpcnJlZ3VsYXIgcXVhZHJpbGF0ZXJhbCB3aXRoIG5vbmUgb2YgdGhlCiAgICBzaWRlcyBiZWluZyB2ZXJ0aWNhbCBvciBob3Jpem9udGFsLiBJdHMgZm91ciBjb3JuZXJzIGFyZSBtYXJrZWQgd2l0aCByZWQgY2lyY2xlcy4gQXJvdW5kIHRoaXMKICAgIHF1YWRyaWxhdGVyYWwgaXMgYSBkYXNoZWQgcmVjdGFuZ2xlLiBBbGwgc2lkZXMgb2YgdGhpcyByZWN0YW5nbGUgYXJlIHZlcnRpY2FsIG9yIGhvcml6b250YWwgYW5kCiAgICB0YW5nZW50IHRoZSBxdWFkcmlsYXRlcmFsLiIgaGVpZ2h0PSIyMDAiIHJvbGU9ImltZyIgd2lkdGg9IjIzMCI+CiAgICAgIDxwb2x5Z29uIGZpbGw9InJnYig1MSwgMTUzLCAyMDQpIiBwb2ludHM9IjQwIDI1LCAxODAgOCwgMjEwIDE1MCwgMTAgMTgwIj48L3BvbHlnb24+CiAgICAgIDxyZWN0IGZpbGw9Im5vbmUiIGhlaWdodD0iMTcyIiBzdHJva2U9ImJsYWNrIiBzdHJva2UtZGFzaGFycmF5PSIzIDIiIHdpZHRoPSIyMDAiIHg9IjEwIiB5PSI4IiAvPgogICAgICA8Y2lyY2xlIGN4PSI0MCIgY3k9IjI1IiBmaWxsPSJyZ2IoMjA0LCA1MSwgNTEpIiByPSIzIj48L2NpcmNsZT4KICAgICAgPGNpcmNsZSBjeD0iMTgwIiBjeT0iOCIgZmlsbD0icmdiKDIwNCwgNTEsIDUxKSIgcj0iMyI+PC9jaXJjbGU+CiAgICAgIDxjaXJjbGUgY3g9IjIxMCIgY3k9IjE1MCIgZmlsbD0icmdiKDIwNCwgNTEsIDUxKSIgcj0iMyI+PC9jaXJjbGU+CiAgICAgIDxjaXJjbGUgY3g9IjEwIiBjeT0iMTgwIiBmaWxsPSJyZ2IoMjA0LCA1MSwgNTEpIiByPSIzIj48L2NpcmNsZT4KICAgICA8L3N2Zz4=)

## 6. The DOMMatrix interfaces

The [`DOMMatrix`](#dommatrix)
and
[`DOMMatrixReadOnly`](#dommatrixreadonly) interfaces each represent a mathematical
[matrix] with the purpose of describing transformations in a
graphical context. The following sections describe the details of the
interface.

<figure>
<span class="math display">$$\begin{bmatrix}
m_{11} &amp; m_{21} &amp; m_{31} &amp; m_{41} \\
m_{12} &amp; m_{22} &amp; m_{32} &amp; m_{42} \\
m_{13} &amp; m_{23} &amp; m_{33} &amp; m_{43} \\
m_{14} &amp; m_{24} &amp; m_{34} &amp; m_{44}
\end{bmatrix}$$</span>
<figcaption>A <dfn id="4x4-abstract-matrix" class="dfn-paneled"
data- data-no>4x4 abstract matrix</dfn> with
items <var>m</var><sub><var>11</var></sub> to
<var>m</var><sub><var>44</var></sub>.</figcaption>
</figure>

In the following sections, terms have the following meaning:

[post-multiply]

: Term `A` post-multiplied by term `B` is equal
 to `A` · `B`.

[pre-multiply]

: Term `A` pre-multiplied by term `B` is equal
 to `B` · `A`.

[multiply]

: Multiply term `A` by term `B` is equal to
 `A` · `B`.

```
[Exposed=(Window,Worker),
 Serializable]
interface DOMMatrixReadOnly {
 constructor(optional (DOMString or sequence<unrestricted double>) init);

 [NewObject] static DOMMatrixReadOnly fromMatrix(optional DOMMatrixInit other = );
 [NewObject] static DOMMatrixReadOnly fromFloat32Array(Float32Array array32);
 [NewObject] static DOMMatrixReadOnly fromFloat64Array(Float64Array array64);

 // These attributes are simple aliases for certain elements of the 4x4 matrix
 readonly attribute unrestricted double a;
 readonly attribute unrestricted double b;
 readonly attribute unrestricted double c;
 readonly attribute unrestricted double d;
 readonly attribute unrestricted double e;
 readonly attribute unrestricted double f;

 readonly attribute unrestricted double m11;
 readonly attribute unrestricted double m12;
 readonly attribute unrestricted double m13;
 readonly attribute unrestricted double m14;
 readonly attribute unrestricted double m21;
 readonly attribute unrestricted double m22;
 readonly attribute unrestricted double m23;
 readonly attribute unrestricted double m24;
 readonly attribute unrestricted double m31;
 readonly attribute unrestricted double m32;
 readonly attribute unrestricted double m33;
 readonly attribute unrestricted double m34;
 readonly attribute unrestricted double m41;
 readonly attribute unrestricted double m42;
 readonly attribute unrestricted double m43;
 readonly attribute unrestricted double m44;

 readonly attribute boolean is2D;
 readonly attribute boolean isIdentity;

 // Immutable transform methods
 [NewObject] DOMMatrix translate(optional unrestricted double tx = 0,
 optional unrestricted double ty = 0,
 optional unrestricted double tz = 0);
 [NewObject] DOMMatrix scale(optional unrestricted double scaleX = 1,
 optional unrestricted double scaleY,
 optional unrestricted double scaleZ = 1,
 optional unrestricted double originX = 0,
 optional unrestricted double originY = 0,
 optional unrestricted double originZ = 0);
 [NewObject] DOMMatrix scaleNonUniform(optional unrestricted double scaleX = 1,
 optional unrestricted double scaleY = 1);
 [NewObject] DOMMatrix scale3d(optional unrestricted double scale = 1,
 optional unrestricted double originX = 0,
 optional unrestricted double originY = 0,
 optional unrestricted double originZ = 0);
 [NewObject] DOMMatrix rotate(optional unrestricted double rotX = 0,
 optional unrestricted double rotY,
 optional unrestricted double rotZ);
 [NewObject] DOMMatrix rotateFromVector(optional unrestricted double x = 0,
 optional unrestricted double y = 0);
 [NewObject] DOMMatrix rotateAxisAngle(optional unrestricted double x = 0,
 optional unrestricted double y = 0,
 optional unrestricted double z = 0,
 optional unrestricted double angle = 0);
 [NewObject] DOMMatrix skewX(optional unrestricted double sx = 0);
 [NewObject] DOMMatrix skewY(optional unrestricted double sy = 0);
 [NewObject] DOMMatrix multiply(optional DOMMatrixInit other = );
 [NewObject] DOMMatrix flipX();
 [NewObject] DOMMatrix flipY();
 [NewObject] DOMMatrix inverse();

 [NewObject] DOMPoint transformPoint(optional DOMPointInit point = );
 [NewObject] Float32Array toFloat32Array();
 [NewObject] Float64Array toFloat64Array();

 [Exposed=Window] stringifier;
 [Default] object toJSON();
};

[Exposed=(Window,Worker),
 Serializable,
 LegacyWindowAlias=(SVGMatrix,WebKitCSSMatrix)]
interface DOMMatrix : DOMMatrixReadOnly {
 constructor(optional (DOMString or sequence<unrestricted double>) init);

 [NewObject] static DOMMatrix fromMatrix(optional DOMMatrixInit other = );
 [NewObject] static DOMMatrix fromFloat32Array(Float32Array array32);
 [NewObject] static DOMMatrix fromFloat64Array(Float64Array array64);

 // These attributes are simple aliases for certain elements of the 4x4 matrix
 inherit attribute unrestricted double a;
 inherit attribute unrestricted double b;
 inherit attribute unrestricted double c;
 inherit attribute unrestricted double d;
 inherit attribute unrestricted double e;
 inherit attribute unrestricted double f;

 inherit attribute unrestricted double m11;
 inherit attribute unrestricted double m12;
 inherit attribute unrestricted double m13;
 inherit attribute unrestricted double m14;
 inherit attribute unrestricted double m21;
 inherit attribute unrestricted double m22;
 inherit attribute unrestricted double m23;
 inherit attribute unrestricted double m24;
 inherit attribute unrestricted double m31;
 inherit attribute unrestricted double m32;
 inherit attribute unrestricted double m33;
 inherit attribute unrestricted double m34;
 inherit attribute unrestricted double m41;
 inherit attribute unrestricted double m42;
 inherit attribute unrestricted double m43;
 inherit attribute unrestricted double m44;

 // Mutable transform methods
 DOMMatrix multiplySelf(optional DOMMatrixInit other = );
 DOMMatrix preMultiplySelf(optional DOMMatrixInit other = );
 DOMMatrix translateSelf(optional unrestricted double tx = 0,
 optional unrestricted double ty = 0,
 optional unrestricted double tz = 0);
 DOMMatrix scaleSelf(optional unrestricted double scaleX = 1,
 optional unrestricted double scaleY,
 optional unrestricted double scaleZ = 1,
 optional unrestricted double originX = 0,
 optional unrestricted double originY = 0,
 optional unrestricted double originZ = 0);
 DOMMatrix scale3dSelf(optional unrestricted double scale = 1,
 optional unrestricted double originX = 0,
 optional unrestricted double originY = 0,
 optional unrestricted double originZ = 0);
 DOMMatrix rotateSelf(optional unrestricted double rotX = 0,
 optional unrestricted double rotY,
 optional unrestricted double rotZ);
 DOMMatrix rotateFromVectorSelf(optional unrestricted double x = 0,
 optional unrestricted double y = 0);
 DOMMatrix rotateAxisAngleSelf(optional unrestricted double x = 0,
 optional unrestricted double y = 0,
 optional unrestricted double z = 0,
 optional unrestricted double angle = 0);
 DOMMatrix skewXSelf(optional unrestricted double sx = 0);
 DOMMatrix skewYSelf(optional unrestricted double sy = 0);
 DOMMatrix invertSelf();

 [Exposed=Window] DOMMatrix setMatrixValue(DOMString transformList);
};

dictionary DOMMatrix2DInit {
 unrestricted double a;
 unrestricted double b;
 unrestricted double c;
 unrestricted double d;
 unrestricted double e;
 unrestricted double f;
 unrestricted double m11;
 unrestricted double m12;
 unrestricted double m21;
 unrestricted double m22;
 unrestricted double m41;
 unrestricted double m42;
};

dictionary DOMMatrixInit : DOMMatrix2DInit {
 unrestricted double m13 = 0;
 unrestricted double m14 = 0;
 unrestricted double m23 = 0;
 unrestricted double m24 = 0;
 unrestricted double m31 = 0;
 unrestricted double m32 = 0;
 unrestricted double m33 = 1;
 unrestricted double m34 = 0;
 unrestricted double m43 = 0;
 unrestricted double m44 = 1;
 boolean is2D;
};
```

The following algorithms assume that
[`DOMMatrixReadOnly`](#dommatrixreadonly) objects have the internal member variables [m11
element], [m12 element], [m13
element], [m14 element], [m21
element], [m22
element], [m23 element], [m24
element], [m31 element], [m32
element], [m33
element], [m34 element], [m41
element], [m42 element], [m43
element], [m44
element] and [is
2D](#matrix-is-2d).
[`DOMMatrixReadOnly`](#dommatrixreadonly) as well as the inheriting interface
[`DOMMatrix`](#dommatrix)
must be able to access and set the value of these variables.

An interface returning an
[`DOMMatrixReadOnly`](#dommatrixreadonly) object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The [`DOMMatrix`](#dommatrix) and
[`DOMMatrixReadOnly`](#dommatrixreadonly) interfaces replace the `SVGMatrix` interface from SVG.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")

### 6.1. DOMMatrix2DInit and DOMMatrixInit dictionaries

To [validate and fixup (2D)] a
[`DOMMatrix2DInit`](#dictdef-dommatrix2dinit) or
[`DOMMatrixInit`](#dictdef-dommatrixinit) dictionary `dict`, run the following steps:

1. If if at least one of the following conditions are true for
 `dict`, then throw a
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception and abort these steps.

 - [`a`](#dom-dommatrix2dinit-a) and
 [`m11`](#dom-dommatrix2dinit-m11) are both present and
 [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero)([`a`](#dom-dommatrix2dinit-a),
 [`m11`](#dom-dommatrix2dinit-m11)) is `false`.

 - [`b`](#dom-dommatrix2dinit-b) and
 [`m12`](#dom-dommatrix2dinit-m12) are both present and
 [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero)([`b`](#dom-dommatrix2dinit-b),
 [`m12`](#dom-dommatrix2dinit-m12)) is `false`.

 - [`c`](#dom-dommatrix2dinit-c) and
 [`m21`](#dom-dommatrix2dinit-m21) are both present and
 [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero)([`c`](#dom-dommatrix2dinit-c),
 [`m21`](#dom-dommatrix2dinit-m21)) is `false`.

 - [`d`](#dom-dommatrix2dinit-d) and
 [`m22`](#dom-dommatrix2dinit-m22) are both present and
 [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero)([`d`](#dom-dommatrix2dinit-d),
 [`m22`](#dom-dommatrix2dinit-m22)) is `false`.

 - [`e`](#dom-dommatrix2dinit-e) and
 [`m41`](#dom-dommatrix2dinit-m41) are both present and
 [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero)([`e`](#dom-dommatrix2dinit-e),
 [`m41`](#dom-dommatrix2dinit-m41)) is `false`.

 - [`f`](#dom-dommatrix2dinit-f) and
 [`m42`](#dom-dommatrix2dinit-m42) are both present and
 [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero)([`f`](#dom-dommatrix2dinit-f),
 [`m42`](#dom-dommatrix2dinit-m42)) is `false`.

2. If
 [`m11`](#dom-dommatrix2dinit-m11) is not present then set it to the value of member
 [`a`](#dom-dommatrix2dinit-a), or value [1] if
 [`a`](#dom-dommatrix2dinit-a) is also not present.

3. If
 [`m12`](#dom-dommatrix2dinit-m12) is not present then set it to the value of member
 [`b`](#dom-dommatrix2dinit-b), or value [0] if
 [`b`](#dom-dommatrix2dinit-b) is also not present.

4. If
 [`m21`](#dom-dommatrix2dinit-m21) is not present then set it to the value of member
 [`c`](#dom-dommatrix2dinit-c), or value [0] if
 [`c`](#dom-dommatrix2dinit-c) is also not present.

5. If
 [`m22`](#dom-dommatrix2dinit-m22) is not present then set it to the value of member
 [`d`](#dom-dommatrix2dinit-d), or value [1] if
 [`d`](#dom-dommatrix2dinit-d) is also not present.

6. If
 [`m41`](#dom-dommatrix2dinit-m41) is not present then set it to the value of member
 [`e`](#dom-dommatrix2dinit-e), or value [0] if
 [`e`](#dom-dommatrix2dinit-e) is also not present.

7. If
 [`m42`](#dom-dommatrix2dinit-m42) is not present then set it to the value of member
 [`f`](#dom-dommatrix2dinit-f), or value [0] if
 [`f`](#dom-dommatrix2dinit-f) is also not present.

 The
[SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero) comparison algorithm returns `true` for two
[NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan) values, and also for [0] and [-0].
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification")

To [validate and fixup] a
[`DOMMatrixInit`](#dictdef-dommatrixinit) dictionary `dict`, run the following steps:

1. [Validate and fixup
 (2D)](#matrix-validate-and-fixup-2d) `dict`.

2. If
 [`is2D`](#dom-dommatrixinit-is2d) is `true` and: at least one of
 [`m13`](#dom-dommatrixinit-m13),
 [`m14`](#dom-dommatrixinit-m14),
 [`m23`](#dom-dommatrixinit-m23),
 [`m24`](#dom-dommatrixinit-m24),
 [`m31`](#dom-dommatrixinit-m31),
 [`m32`](#dom-dommatrixinit-m32),
 [`m34`](#dom-dommatrixinit-m34),
 [`m43`](#dom-dommatrixinit-m43) are present with a value other than [0] or
 [-0], or at least one of
 [`m33`](#dom-dommatrixinit-m33),
 [`m44`](#dom-dommatrixinit-m44) are present with a value other than [1], then
 throw a
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception and abort these steps.

3. If
 [`is2D`](#dom-dommatrixinit-is2d) is not present and at least one of
 [`m13`](#dom-dommatrixinit-m13),
 [`m14`](#dom-dommatrixinit-m14),
 [`m23`](#dom-dommatrixinit-m23),
 [`m24`](#dom-dommatrixinit-m24),
 [`m31`](#dom-dommatrixinit-m31),
 [`m32`](#dom-dommatrixinit-m32),
 [`m34`](#dom-dommatrixinit-m34),
 [`m43`](#dom-dommatrixinit-m43) are present with a value other than [0] or
 [-0], or at least one of
 [`m33`](#dom-dommatrixinit-m33),
 [`m44`](#dom-dommatrixinit-m44) are present with a value other than [1], set
 [`is2D`](#dom-dommatrixinit-is2d) to `false`.

4. If
 [`is2D`](#dom-dommatrixinit-is2d) is still not present, set it to `true`.

### 6.2. Parsing a string into an abstract matrix

To [parse a string into an abstract
matrix], given a string `transformList`,
means to run the following steps. It will either return a [4x4 abstract
matrix](#4x4-abstract-matrix) and a boolean `2dTransform`, or failure.

1. If `transformList` is the empty string, set it to the
 string \"`matrix(1, 0, 0, 1, 0, 0)`\".

2. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `transformList` into
 `parsedValue` given the grammar for the CSS
 [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property. The result will be a
 [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list), the keyword [none], or
 failure. If `parsedValue` is failure, or any
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function) has
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) values without [absolute
 length](https://drafts.csswg.org/css-values-4/#absolute-length) units, or any keyword other than [none] is
 used, then return failure.
 [\[CSS3-SYNTAX\]](#biblio-css3-syntax "CSS Syntax Module Level 3")
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

3. If `parsedValue` is [none], set
 `parsedValue` to a
 [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list) containing a single identity
 matrix.

4. Let `2dTransform` track the 2D/3D dimension status of
 `parsedValue`.

 If `parsedValue` consists of any [three-dimensional transform functions](https://drafts.csswg.org/css-transforms-1/#transform-primitives)

 : Set `2dTransform` to `false`.

 Otherwise

 : Set `2dTransform` to `true`.

5. Transform all
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function)s to [4x4 abstract
 matrices](#4x4-abstract-matrix) by following the "[Mathematical Description of
 Transform
 Functions](https://drafts.csswg.org/css-transforms-1/#mathematical-description)".
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

6. Let `matrix` be a [4x4 abstract
 matrix](#4x4-abstract-matrix) as shown in the initial figure of this section.
 [Post-multiply](#post-multiply) all matrices from left to right and set
 `matrix` to this product.

7. Return `matrix` and `2dTransform`.

### 6.3. Creating DOMMatrixReadOnly and DOMMatrix objects

To [create a 2d matrix] of type `type` being either
[`DOMMatrixReadOnly`](#dommatrixreadonly) or [`DOMMatrix`](#dommatrix), with a sequence `init` of 6 elements,
follow these steps:

1. Let `matrix` be a new instance of `type`.

2. Set [m11 element](#matrix-m11-element), [m12
 element](#matrix-m12-element), [m21
 element](#matrix-m21-element), [m22
 element](#matrix-m22-element), [m41
 element](#matrix-m41-element) and [m42
 element](#matrix-m42-element) to the values of `init` in order
 starting with the first value.

3. Set [m13 element](#matrix-m13-element), [m14
 element](#matrix-m14-element), [m23
 element](#matrix-m23-element), [m24
 element](#matrix-m24-element), [m31
 element](#matrix-m31-element), [m32
 element](#matrix-m32-element), [m34
 element](#matrix-m34-element), and [m43
 element](#matrix-m43-element) to [0].

4. Set [m33 element](#matrix-m33-element) and [m44
 element](#matrix-m44-element) to [1].

5. Set [is 2D](#matrix-is-2d)
 to `true`.

6. Return `matrix`

To [create a 3d matrix] with `type` being either
[`DOMMatrixReadOnly`](#dommatrixreadonly) or [`DOMMatrix`](#dommatrix), with a sequence `init` of 16 elements,
follow these steps:

1. Let `matrix` be a new instance of `type`.

2. Set [m11 element](#matrix-m11-element) to [m44
 element](#matrix-m44-element) to the values of `init` in column-major
 order.

3. Set [is 2D](#matrix-is-2d)
 to `false`.

4. Return `matrix`

The
[`DOMMatrixReadOnly(``init``)`]
and the [`DOMMatrix(``init``)`]
constructors must follow these steps:

If `init` is omitted

: Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with the sequence \[[1],
 [0], [0], [1], [0], [0]\].

If `init` is a [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)

: 1. If [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object) is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, then throw a
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception.

 2. [Parse `init` into an abstract
 matrix](#parse-a-string-into-an-abstract-matrix), and let `matrix` and
 `2dTransform` be the result. If the result is
 failure, then throw a
 \"[`SyntaxError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-syntaxerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3.

 If `2dTransform` is `true`

 : Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers,
 the values being the elements `m11`,
 `m12`, `m21`, `m22`,
 `m41` and `m42` of
 `matrix`.

 Otherwise

 : Return the result of invoking [create a 3d
 matrix](#create-a-3d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers,
 the values being the 16 elements of `matrix`.

If `init` is a sequence with 6 elements

: Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with the sequence
 `init`.

If `init` is a sequence with 16 elements

: Return the result of invoking [create a 3d
 matrix](#create-a-3d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with the sequence
 `init`.

Otherwise

: Throw a
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception.

The
[`fromMatrix(``other``)`] static
method on
[`DOMMatrixReadOnly`](#dommatrixreadonly) must [create a `DOMMatrixReadOnly` from the
dictionary](#create-a-dommatrixreadonly-from-the-dictionary) `other`.

The [`fromMatrix(``other``)`] static method on
[`DOMMatrix`](#dommatrix)
must [create a `DOMMatrix` from the
dictionary](#create-a-dommatrix-from-the-dictionary) `other`.

To [create a `DOMMatrixReadOnly` from a 2D
dictionary]
`other` or to [create a `DOMMatrix` from a 2D
dictionary] `other`, follow these
steps:

1. [Validate and fixup
 (2D)](#matrix-validate-and-fixup-2d) `other`.

2. Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers, the
 values being the 6 elements
 [`m11`](#dom-dommatrix2dinit-m11),
 [`m12`](#dom-dommatrix2dinit-m12),
 [`m21`](#dom-dommatrix2dinit-m21),
 [`m22`](#dom-dommatrix2dinit-m22),
 [`m41`](#dom-dommatrix2dinit-m41) and
 [`m42`](#dom-dommatrix2dinit-m42) of `other` in the given order.

To [create a `DOMMatrixReadOnly` from a
dictionary] `other`
or to [create a `DOMMatrix` from a
dictionary] `other`, follow
these steps:

1. [Validate and
 fixup](#matrix-validate-and-fixup) `other`.

2.

 If the [`is2D`](#dom-dommatrixinit-is2d) dictionary member of `other` is `true`

 : Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers, the
 values being the 6 elements
 [`m11`](#dom-dommatrix2dinit-m11),
 [`m12`](#dom-dommatrix2dinit-m12),
 [`m21`](#dom-dommatrix2dinit-m21),
 [`m22`](#dom-dommatrix2dinit-m22),
 [`m41`](#dom-dommatrix2dinit-m41) and
 [`m42`](#dom-dommatrix2dinit-m42) of `other` in the given order.

 Otherwise

 : Return the result of invoking [create a 3d
 matrix](#create-a-3d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers, the
 values being the 16 elements
 [`m11`](#dom-dommatrix2dinit-m11),
 [`m12`](#dom-dommatrix2dinit-m12),
 [`m13`](#dom-dommatrixinit-m13), \...,
 [`m44`](#dom-dommatrixinit-m44) of `other` in the given order.

The
[`fromFloat32Array(``array32``)`] static method on
[`DOMMatrixReadOnly`](#dommatrixreadonly) and the
[`fromFloat32Array(``array32``)`] static method on
[`DOMMatrix`](#dommatrix)
must follow these steps:

If `array32` has 6 elements

: Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers taking
 the values from `array32` in the provided order.

If `array32` has 16 elements

: Return the result of invoking [create a 3d
 matrix](#create-a-3d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers taking
 the values from `array32` in the provided order.

Otherwise

: Throw a
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception.

The
[`fromFloat64Array(``array64``)`] static method on
[`DOMMatrixReadOnly`](#dommatrixreadonly) and the
[`fromFloat64Array(``array64``)`] static method on
[`DOMMatrix`](#dommatrix)
must follow these steps:

If `array64` has 6 elements

: Return the result of invoking [create a 2d
 matrix](#create-a-2d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers taking
 the values from `array64` in the provided order.

If `array32` has 16 elements

: Return the result of invoking [create a 3d
 matrix](#create-a-3d-matrix) of type
 [`DOMMatrixReadOnly`](#dommatrixreadonly) or
 [`DOMMatrix`](#dommatrix) as appropriate, with a sequence of numbers taking
 the values from `array64` in the provided order.

Otherwise

: Throw a
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception.

### 6.4. DOMMatrix attributes

The following attributes
[`m11`](#dom-dommatrixreadonly-m11) to
[`m44`](#dom-dommatrixreadonly-m44) correspond to the 16 items of the matrix interfaces.

The [`m11`]
and [`a`]
attributes, on getting, must return the [m11
element](#matrix-m11-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m11`](#dom-dommatrixreadonly-m11) or the
[`a`](#dom-dommatrixreadonly-a) attribute must set the [m11
element] to the new value.

The [`m12`]
and [`b`]
attributes, on getting, must return the [m12
element](#matrix-m12-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m12`](#dom-dommatrixreadonly-m12) or the
[`b`](#dom-dommatrixreadonly-b) attribute must set the [m12
element] to the new value.

The [`m13`]
attribute, on getting, must return the [m13
element](#matrix-m13-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m13`](#dom-dommatrixreadonly-m13) attribute must set the [m13
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m14`]
attribute, on getting, must return the [m14
element](#matrix-m14-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m14`](#dom-dommatrixreadonly-m14) attribute must set the [m14
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m21`]
and [`c`]
attributes, on getting, must return the [m21
element](#matrix-m21-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m21`](#dom-dommatrixreadonly-m21) or the
[`c`](#dom-dommatrixreadonly-c) attribute must set the [m21
element] to the new value.

The [`m22`]
and [`d`]
attributes, on getting, must return the [m22
element](#matrix-m22-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m22`](#dom-dommatrixreadonly-m22) or the
[`d`](#dom-dommatrixreadonly-d) attribute must set the [m22
element] to the new value.

The [`m23`]
attribute, on getting, must return the [m23
element](#matrix-m23-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m23`](#dom-dommatrixreadonly-m23) attribute must set the [m23
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m24`]
attribute, on getting, must return the [m24
element](#matrix-m24-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m24`](#dom-dommatrixreadonly-m24) attribute must set the [m24
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m31`]
attribute, on getting, must return the [m31
element](#matrix-m31-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m31`](#dom-dommatrixreadonly-m31) attribute must set the [m31
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m32`]
attribute, on getting, must return the [m32
element](#matrix-m32-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m32`](#dom-dommatrixreadonly-m32) attribute must set the [m32
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m33`]
attribute, on getting, must return the [m33
element](#matrix-m33-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m33`](#dom-dommatrixreadonly-m33) attribute must set the [m33
element] to the new value and, if the new
value is not [1], set [is
2D](#matrix-is-2d) to `false`.

The [`m34`]
attribute, on getting, must return the [m34
element](#matrix-m34-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m34`](#dom-dommatrixreadonly-m34) attribute must set the [m34
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m41`]
and [`e`]
attributes, on getting, must return the [m41
element](#matrix-m41-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m41`](#dom-dommatrixreadonly-m41) or the
[`e`](#dom-dommatrixreadonly-e) attribute must set the [m41
element] to the new value.

The [`m42`]
and [`f`]
attributes, on getting, must return the [m42
element](#matrix-m42-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m42`](#dom-dommatrixreadonly-m42) or the
[`f`](#dom-dommatrixreadonly-f) attribute must set the [m42
element] to the new value.

The [`m43`]
attribute, on getting, must return the [m43
element](#matrix-m43-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m43`](#dom-dommatrixreadonly-m43) attribute must set the [m43
element] to the new value and, if the new
value is not [0] or [-0], set [is
2D](#matrix-is-2d) to `false`.

The [`m44`]
attribute, on getting, must return the [m44
element](#matrix-m44-element) value. For the
[`DOMMatrix`](#dommatrix)
interface, setting the
[`m44`](#dom-dommatrixreadonly-m44) attribute must set the [m44
element] to the new value and, if the new
value is not [1], set [is
2D](#matrix-is-2d) to `false`.

The following attributes
[`a`](#dom-dommatrixreadonly-a) to
[`f`](#dom-dommatrixreadonly-f) correspond to the 2D components of the matrix
interfaces.

The
[`a`](#dom-dommatrixreadonly-a) attribute is an alias to the
[`m11`](#dom-dommatrixreadonly-m11) attribute.

The
[`b`](#dom-dommatrixreadonly-b) attribute is an alias to the
[`m12`](#dom-dommatrixreadonly-m12) attribute.

The
[`c`](#dom-dommatrixreadonly-c) attribute is an alias to the
[`m21`](#dom-dommatrixreadonly-m21) attribute.

The
[`d`](#dom-dommatrixreadonly-d) attribute is an alias to the
[`m22`](#dom-dommatrixreadonly-m22) attribute.

The
[`e`](#dom-dommatrixreadonly-e) attribute is an alias to the
[`m41`](#dom-dommatrixreadonly-m41) attribute.

The
[`f`](#dom-dommatrixreadonly-f) attribute is an alias to the
[`m42`](#dom-dommatrixreadonly-m42) attribute.

The following attributes provide status information about
[`DOMMatrixReadOnly`](#dommatrixreadonly).

The [`is2D`] attribute
must return the value of [is 2D](#matrix-is-2d).

The [`isIdentity`]
attribute must return `true` if [m12
element](#matrix-m12-element), [m13
element](#matrix-m13-element), [m14
element](#matrix-m14-element), [m21
element](#matrix-m21-element), [m23
element](#matrix-m23-element), [m24
element](#matrix-m24-element), [m31
element](#matrix-m31-element), [m32
element](#matrix-m32-element), [m34
element](#matrix-m34-element), [m41
element](#matrix-m41-element), [m42
element](#matrix-m42-element), [m43
element](#matrix-m43-element) are [0] or [-0] and [m11
element](#matrix-m11-element), [m22
element](#matrix-m22-element), [m33
element](#matrix-m33-element), [m44
element](#matrix-m44-element) are [1]. Otherwise it must return `false`.

Every
[`DOMMatrixReadOnly`](#dommatrixreadonly) object must be flagged with a boolean [is
2D]. This flag indicates that:

1. The current matrix was initialized as a 2D matrix. See individual
 [creators](#dommatrix-create) for more details.

2. Only 2D transformation operations were applied. Each
 [mutable](#mutable-transformation-methods) or [immutable
 transformation method](#immutable-transformation-methods) defines if
 [is 2D](#matrix-is-2d) must
 be set to `false`.

 [Is 2D](#matrix-is-2d) can never be set to `true` when it was set to `false`
before on a [`DOMMatrix`](#dommatrix) object with the exception of calling the
[`setMatrixValue()`](#dom-dommatrix-setmatrixvalue) method.

### 6.5. Immutable transformation methods

The following methods do not modify the current matrix and return a new
[`DOMMatrix`](#dommatrix)
object.

[`translate(``tx``, ``ty``, ``tz``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`translateSelf()`](#dom-dommatrix-translateself) transformation on `result` with the
 arguments `tx`, `ty`, `tz`.

 3. Return `result`.

 The current matrix is not modified.

[`scale(``scaleX``, ``scaleY``, ``scaleZ``, ``originX``, ``originY``, ``originZ``)`]

: 1. If `scaleY` is missing, set `scaleY` to
 the value of `scaleX`.

 2. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 3. Perform a
 [`scaleSelf()`](#dom-dommatrix-scaleself) transformation on `result` with the
 arguments `scaleX`, `scaleY`,
 `scaleZ`, `originX`, `originY`,
 `originZ`.

 4. Return `result`.

 The current matrix is not modified.

[`scaleNonUniform(``scaleX``, ``scaleY``)`]

: Supported for legacy reasons to be compatible with
 [`SVGMatrix`](#svgmatrix)
 as defined in SVG 1.1
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)").
 Authors are encouraged to use
 [`scale()`](#dom-dommatrixreadonly-scale) instead.

 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`scaleSelf()`](#dom-dommatrix-scaleself) transformation on `result` with the
 arguments `scaleX`, `scaleY`, *1*, *0*,
 *0*, *0*.

 3. Return `result`.

 The current matrix is not modified.

[`scale3d(``scale``, ``originX``, ``originY``, ``originZ``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`scale3dSelf()`](#dom-dommatrix-scale3dself) transformation on `result` with the
 arguments `scale`, `originX`,
 `originY`, `originZ`.

 3. Return `result`.

 The current matrix is not modified.

[`rotate(``rotX``, ``rotY``, ``rotZ``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`rotateSelf()`](#dom-dommatrix-rotateself) transformation on `result` with the
 arguments `rotX`, `rotY`,
 `rotZ`.

 3. Return `result`.

 The current matrix is not modified.

[`rotateFromVector(``x``, ``y``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`rotateFromVectorSelf()`](#dom-dommatrix-rotatefromvectorself) transformation on `result` with the
 arguments `x`, `y`.

 3. Return `result`.

 The current matrix is not modified.

[`rotateAxisAngle(``x``, ``y``, ``z``, ``angle``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`rotateAxisAngleSelf()`](#dom-dommatrix-rotateaxisangleself) transformation on `result` with the
 arguments `x`, `y`, `z`,
 `angle`.

 3. Return `result`.

 The current matrix is not modified.

[`skewX(``sx``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`skewXSelf()`](#dom-dommatrix-skewxself) transformation on `result` with the
 argument `sx`.

 3. Return `result`.

 The current matrix is not modified.

[`skewY(``sy``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`skewYSelf()`](#dom-dommatrix-skewyself) transformation on `result` with the
 argument `sy`.

 3. Return `result`.

 The current matrix is not modified.

[`multiply(``other``)`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`multiplySelf()`](#dom-dommatrix-multiplyself) transformation on `result` with the
 argument `other`.

 3. Return `result`.

 The current matrix is not modified.

[`flipX()`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. [Post-multiply](#post-multiply) `result` with
 `new DOMMatrix([-1, 0, 0, 1, 0, 0])`.

 3. Return `result`.

 The current matrix is not modified.

[`flipY()`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. [Post-multiply](#post-multiply) `result` with
 `new DOMMatrix([1, 0, 0, -1, 0, 0])`.

 3. Return `result`.

 The current matrix is not modified.

[`inverse()`]

: 1. Let `result` be the resulting matrix initialized to
 the values of the current matrix.

 2. Perform a
 [`invertSelf()`](#dom-dommatrix-invertself) transformation on `result`.

 3. Return `result`.

 The current matrix is not modified.

The following methods do not modify the current matrix.

[`transformPoint(``point``)`]

: Let `pointObject` be the result of invoking [create a
 `DOMPoint` from the
 dictionary](#create-a-dompoint-from-the-dictionary) `point`. Return the result of invoking
 [transform a point with a
 matrix](#transform-a-point-with-a-matrix), given `pointObject` and the current
 matrix. The passed argument does not get modified.

[`toFloat32Array()`]

: Returns the serialized 16 elements
 [`m11`](#dom-dommatrixreadonly-m11) to
 [`m44`](#dom-dommatrixreadonly-m44) of the current matrix in column-major order as
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array).

[`toFloat64Array()`]

: Returns the serialized 16 elements
 [`m11`](#dom-dommatrixreadonly-m11) to
 [`m44`](#dom-dommatrixreadonly-m44) of the current matrix in column-major order as
 [`Float64Array`](https://webidl.spec.whatwg.org/#idl-Float64Array).

[stringification behavior]

: 1. If one or more of [m11
 element](#matrix-m11-element) through [m44
 element](#matrix-m44-element) are a non-finite value, then throw an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 The CSS syntax cannot represent
 [NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan) or
 [Infinity](https://drafts.csswg.org/css-values-4/#valdef-calc-infinity) values.

 2. Let `string` be the empty string.

 3. If [is 2D](#matrix-is-2d) is `true`, then:

 1. Append \"`matrix(`\" to `string`.

 2. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m11
 element](#matrix-m11-element)) to `string`.

 3. Append \"`, `\" to `string`.

 4. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m12
 element](#matrix-m12-element)) to `string`.

 5. Append \"`, `\" to `string`.

 6. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m21
 element](#matrix-m21-element)) to `string`.

 7. Append \"`, `\" to `string`.

 8. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m22
 element](#matrix-m22-element)) to `string`.

 9. Append \"`, `\" to `string`.

 10. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m41
 element](#matrix-m41-element)) to `string`.

 11. Append \"`, `\" to `string`.

 12. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m42
 element](#matrix-m42-element)) to `string`.

 13. Append \"`)`\" to `string`.

 The string will be in the form of a a CSS
 Transforms
 [\<matrix()\>](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-matrix) function.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 4. Otherwise:

 1. Append \"`matrix3d(`\" to `string`.

 2. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m11
 element](#matrix-m11-element)) to `string`.

 3. Append \"`, `\" to `string`.

 4. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m12
 element](#matrix-m12-element)) to `string`.

 5. Append \"`, `\" to `string`.

 6. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m13
 element](#matrix-m13-element)) to `string`.

 7. Append \"`, `\" to `string`.

 8. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m14
 element](#matrix-m14-element)) to `string`.

 9. Append \"`, `\" to `string`.

 10. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m21
 element](#matrix-m21-element)) to `string`.

 11. Append \"`, `\" to `string`.

 12. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m22
 element](#matrix-m22-element)) to `string`.

 13. Append \"`, `\" to `string`.

 14. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m23
 element](#matrix-m23-element)) to `string`.

 15. Append \"`, `\" to `string`.

 16. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m24
 element](#matrix-m24-element)) to `string`.

 17. Append \"`, `\" to `string`.

 18. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m41
 element](#matrix-m41-element)) to `string`.

 19. Append \"`, `\" to `string`.

 20. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m42
 element](#matrix-m42-element)) to `string`.

 21. Append \"`, `\" to `string`.

 22. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m43
 element](#matrix-m43-element)) to `string`.

 23. Append \"`, `\" to `string`.

 24. Append
 [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions)
 [ToString](https://tc39.github.io/ecma262/#sec-tostring)([m44
 element](#matrix-m44-element)) to `string`.

 25. Append \"`)`\" to `string`.

 The string will be in the form of a a CSS
 Transforms
 [\<matrix3d()\>](https://drafts.csswg.org/css-transforms-2/#funcdef-matrix3d) function.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 5. Return `string`.

(#example-c07c5bc8) In this example, a matrix is created
and several 2D transformation methods are called:

``` highlight
var matrix = new DOMMatrix();
matrix.scaleSelf(2);
matrix.translateSelf(20,20);
console.assert(matrix.toString() ===
 "matrix(2, 0, 0, 2, 40, 40)");
```

(#example-92755fec) In the following example, a matrix is
created and several 3D transformation methods are called:

``` highlight
var matrix = new DOMMatrix();
matrix.scale3dSelf(2);
console.assert(matrix.toString() ===
 "matrix3d(2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1)");
```

For 3D operations, the stringifier returns a string representing a 3D
matrix.

(#example-733d794b) This example will throw an exception
because there are non-finite values in the matrix.

``` highlight
var matrix = new DOMMatrix([NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN]);
var string = matrix + " Batman!";
```

### 6.6. Mutable transformation methods

The following methods modify the current matrix, so that each method
returns the matrix where it was invoked on. The primary benefit of this
is allowing content creators to chain method calls.

(#example-15e8ec9d) The following code example:

``` highlight
var matrix = new DOMMatrix();
matrix.translateSelf(20, 20);
matrix.scaleSelf(2);
matrix.translateSelf(-20, -20);
```

is equivalent to:

``` highlight
var matrix = new DOMMatrix();
matrix.translateSelf(20, 20).scaleSelf(2).translateSelf(-20, -20);
```

 Authors who use chained method calls are advised to use
mutable transformation methods to avoid unnecessary memory allocations
due to creation of intermediate
[`DOMMatrix`](#dommatrix)
objects in user agents.

[`multiplySelf(``other``)`]

: 1. Let `otherObject` be the result of invoking [create a
 `DOMMatrix` from the
 dictionary](#create-a-dommatrix-from-the-dictionary) `other`.

 2. The `otherObject` matrix gets post-multiplied to the
 current matrix.

 3. If [is 2D](#matrix-is-2d) of `otherObject` is `false`, set [is
 2D] of the current matrix to `false`.

 4. Return the current matrix.

[`preMultiplySelf(``other``)`]

: 1. Let `otherObject` be the result of invoking [create a
 `DOMMatrix` from the
 dictionary](#create-a-dommatrix-from-the-dictionary) `other`.

 2. The `otherObject` matrix gets pre-multiplied to the
 current matrix.

 3. If [is 2D](#matrix-is-2d) of `otherObject` is `false`, set [is
 2D] of the current matrix to `false`.

 4. Return the current matrix.

[`translateSelf(``tx``, ``ty``, ``tz``)`]

: 1. [Post-multiply](#post-multiply) a translation transformation on the current
 matrix. The 3D translation matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#TranslateDefined)
 in CSS Transforms.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 2. If `tz` is specified and not [0] or [-0],
 set [is 2D](#matrix-is-2d) of the current matrix to `false`.

 3. Return the current matrix.

[`scaleSelf(``scaleX``, ``scaleY``, ``scaleZ``, ``originX``, ``originY``, ``originZ``)`]

: 1. Perform a
 [`translateSelf()`](#dom-dommatrix-translateself) transformation on the current matrix with the
 arguments `originX`, `originY`,
 `originZ`.

 2. If `scaleY` is missing, set `scaleY` to
 the value of `scaleX`.

 3. [Post-multiply](#post-multiply) a non-uniform scale transformation on the
 current matrix. The 3D scale matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#ScaleDefined)
 in CSS Transforms with `sx` = `scaleX`,
 `sy` = `scaleY` and `sz` =
 `scaleZ`.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 4. Negate `originX`, `originY` and
 `originZ`.

 5. Perform a
 [`translateSelf()`](#dom-dommatrix-translateself) transformation on the current matrix with the
 arguments `originX`, `originY`,
 `originZ`.

 6. If `scaleZ` is not [1], set [is
 2D](#matrix-is-2d) of
 the current matrix to `false`.

 7. Return the current matrix.

[`scale3dSelf(``scale``, ``originX``, ``originY``, ``originZ``)`]

: 1. Apply a
 [`translateSelf()`](#dom-dommatrix-translateself) transformation to the current matrix with the
 arguments `originX`, `originY`,
 `originZ`.

 2. [Post-multiply](#post-multiply) a uniform 3D scale transformation
 ([`m11`](#dom-dommatrixreadonly-m11) =
 [`m22`](#dom-dommatrixreadonly-m22) =
 [`m33`](#dom-dommatrixreadonly-m33) = `scale`) on the current matrix.
 The 3D scale matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#ScaleDefined)
 in CSS Transforms with `sx` = `sy` =
 `sz` = `scale`.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 3. Apply a
 [`translateSelf()`](#dom-dommatrix-translateself) transformation to the current matrix with the
 arguments -`originX`, -`originY`,
 -`originZ`.

 4. If `scale` is not [1], set [is
 2D](#matrix-is-2d) of
 the current matrix to `false`.

 5. Return the current matrix.

[`rotateSelf(``rotX``, ``rotY``, ``rotZ``)`]

: 1. If `rotY` and `rotZ` are both missing, set
 `rotZ` to the value of `rotX` and set
 `rotX` and `rotY` to [0].

 2. If `rotY` is still missing, set `rotY` to
 [0].

 3. If `rotZ` is still missing, set `rotZ` to
 [0].

 4. If `rotX` or `rotY` are not [0] or
 [-0], set [is 2D](#matrix-is-2d) of the current matrix to `false`.

 5. [Post-multiply](#post-multiply) a rotation transformation on the current matrix
 around the vector 0, 0, 1 by the specified rotation
 `rotZ` in degrees. The 3D rotation matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
 in CSS Transforms with `alpha` = `rotZ` in
 degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 6. [Post-multiply](#post-multiply) a rotation transformation on the current matrix
 around the vector 0, 1, 0 by the specified rotation
 `rotY` in degrees. The 3D rotation matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
 in CSS Transforms with `alpha` = `rotY` in
 degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 7. [Post-multiply](#post-multiply) a rotation transformation on the current matrix
 around the vector 1, 0, 0 by the specified rotation
 `rotX` in degrees. The 3D rotation matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
 in CSS Transforms with `alpha` = `rotX` in
 degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 8. Return the current matrix.

[`rotateFromVectorSelf(``x``, ``y``)`]

: 1. [Post-multiply](#post-multiply) a rotation transformation on the current
 matrix. The rotation angle is determined by the angle between
 the vector (1,0)^T^ and (`x`,`y`)^T^ in
 the clockwise direction. If `x` and `y`
 should both be [0] or [-0], the angle is specified
 as [0]. The 2D rotation matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
 in CSS Transforms where `alpha` is the angle between the vector
 (1,0)^T^ and (`x`,`y`)^T^ in degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 2. Return the current matrix.

[`rotateAxisAngleSelf(``x``, ``y``, ``z``, ``angle``)`]

: 1. [Post-multiply](#post-multiply) a rotation transformation on the current matrix
 around the specified vector `x`, `y`,
 `z` by the specified rotation `angle` in
 degrees. The 3D rotation matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
 in CSS Transforms with `alpha` = `angle`
 in degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 2. If `x` or `y` are not [0] or
 [-0], set [is 2D](#matrix-is-2d) of the current matrix to `false`.

 3. Return the current matrix.

[`skewXSelf(``sx``)`]

: 1. [Post-multiply](#post-multiply) a skewX transformation on the current matrix by
 the specified angle `sx` in degrees. The 2D skewX
 matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#SkewXDefined)
 in CSS Transforms with `alpha` = `sx` in
 degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 2. Return the current matrix.

[`skewYSelf(``sy``)`]

: 1. [Post-multiply](#post-multiply) a skewX transformation on the current matrix by
 the specified angle `sy` in degrees. The 2D skewY
 matrix is
 [described](https://drafts.csswg.org/css-transforms-1/#SkewYDefined)
 in CSS Transforms with `beta` = `sy` in
 degrees.
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1")

 2. Return the current matrix.

[`invertSelf()`]

: 1. Invert the current matrix.

 2. If the current matrix is not invertible set all attributes to
 [NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan) and set [is
 2D](#matrix-is-2d) to
 `false`.

 3. Return the current matrix.

[`setMatrixValue(``transformList``)`]

: 1. [Parse `transformList` into an abstract
 matrix](#parse-a-string-into-an-abstract-matrix), and let `matrix` and
 `2dTransform` be the result. If the result is
 failure, then throw a
 \"[`SyntaxError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-syntaxerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Set [is 2D](#matrix-is-2d) to the value of `2dTransform`.

 3. Set [m11
 element](#matrix-m11-element) through [m44
 element](#matrix-m44-element) to the element values of `matrix` in
 column-major order.

 4. Return the current matrix.

## 7. Structured serialization

[`DOMPointReadOnly`](#dompointreadonly), [`DOMPoint`](#dompoint),
[`DOMRectReadOnly`](#domrectreadonly), [`DOMRect`](#domrect), [`DOMQuad`](#domquad),
[`DOMMatrixReadOnly`](#dommatrixreadonly), and
[`DOMMatrix`](#dommatrix)
objects are [serializable
objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects).
[\[HTML\]](#biblio-html "HTML Standard")

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) for
[`DOMPointReadOnly`](#dompointreadonly) and [`DOMPoint`](#dompoint), given `value` and `serialized`,
are:

1. Set `serialized`.\[\[X\]\] to `value`'s [x
 coordinate](#point-x-coordinate).

2. Set `serialized`.\[\[Y\]\] to `value`'s [y
 coordinate](#point-y-coordinate).

3. Set `serialized`.\[\[Z\]\] to `value`'s [z
 coordinate](#point-z-coordinate).

4. Set `serialized`.\[\[W\]\] to `value`'s [w
 perspective](#point-w-perspective).

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and `value`,
are:

1. Set `value`'s [x
 coordinate](#point-x-coordinate) to `serialized`.\[\[X\]\].

2. Set `value`'s [y
 coordinate](#point-y-coordinate) to `serialized`.\[\[Y\]\].

3. Set `value`'s [z
 coordinate](#point-z-coordinate) to `serialized`.\[\[Z\]\].

4. Set `value`'s [w
 perspective](#point-w-perspective) to `serialized`.\[\[W\]\].

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) for
[`DOMRectReadOnly`](#domrectreadonly) and [`DOMRect`](#domrect), given `value` and `serialized`,
are:

1. Set `serialized`.\[\[X\]\] to `value`'s [x
 coordinate](#rectangle-x-coordinate).

2. Set `serialized`.\[\[Y\]\] to `value`'s [y
 coordinate](#rectangle-y-coordinate).

3. Set `serialized`.\[\[Width\]\] to `value`'s
 [width
 dimension](#rectangle-width-dimension).

4. Set `serialized`.\[\[Height\]\] to `value`'s
 [height
 dimension](#rectangle-height-dimension).

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and `value`,
are:

1. Set `value`'s [x
 coordinate](#rectangle-x-coordinate) to `serialized`.\[\[X\]\].

2. Set `value`'s [y
 coordinate](#rectangle-y-coordinate) to `serialized`.\[\[Y\]\].

3. Set `value`'s [width
 dimension](#rectangle-width-dimension) to `serialized`.\[\[Width\]\].

4. Set `value`'s [height
 dimension](#rectangle-height-dimension) to `serialized`.\[\[Height\]\].

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) for [`DOMQuad`](#domquad), given `value` and `serialized`,
are:

1. Set `serialized`.\[\[P1\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization) of `value`'s [point
 1](#quadrilateral-point-1).

2. Set `serialized`.\[\[P2\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization) of `value`'s [point
 2](#quadrilateral-point-2).

3. Set `serialized`.\[\[P3\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization) of `value`'s [point
 3](#quadrilateral-point-3).

4. Set `serialized`.\[\[P4\]\] to the
 [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization) of `value`'s [point
 4](#quadrilateral-point-4).

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and `value`,
are:

1. Set `value`'s [point
 1](#quadrilateral-point-1) to the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization) of `serialized`.\[\[P1\]\].

2. Set `value`'s [point
 2](#quadrilateral-point-2) to the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization) of `serialized`.\[\[P2\]\].

3. Set `value`'s [point
 3](#quadrilateral-point-3) to the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization) of `serialized`.\[\[P3\]\].

4. Set `value`'s [point
 4](#quadrilateral-point-4) to the
 [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization) of `serialized`.\[\[P4\]\].

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) for
[`DOMMatrixReadOnly`](#dommatrixreadonly) and
[`DOMMatrix`](#dommatrix),
given `value` and `serialized`, are:

1. If `value`'s [is
 2D](#matrix-is-2d) is
 `true`:

 1. Set `serialized`.\[\[M11\]\] to `value`'s
 [m11 element](#matrix-m11-element).

 2. Set `serialized`.\[\[M12\]\] to `value`'s
 [m12 element](#matrix-m12-element).

 3. Set `serialized`.\[\[M21\]\] to `value`'s
 [m21 element](#matrix-m21-element).

 4. Set `serialized`.\[\[M22\]\] to `value`'s
 [m22 element](#matrix-m22-element).

 5. Set `serialized`.\[\[M41\]\] to `value`'s
 [m41 element](#matrix-m41-element).

 6. Set `serialized`.\[\[M42\]\] to `value`'s
 [m42 element](#matrix-m42-element).

 7. Set `serialized`.\[\[Is2D\]\] to `true`.

 It is possible for a 2D
 [`DOMMatrix`](#dommatrix) or
 [`DOMMatrixReadOnly`](#dommatrixreadonly) to have [-0] for some of the other elements,
 e.g., the [m13
 element](#matrix-m13-element), which will not be roundtripped by this algorithm.

2. Otherwise:

 1. Set `serialized`.\[\[M11\]\] to `value`'s
 [m11 element](#matrix-m11-element).

 2. Set `serialized`.\[\[M12\]\] to `value`'s
 [m12 element](#matrix-m12-element).

 3. Set `serialized`.\[\[M13\]\] to `value`'s
 [m13 element](#matrix-m13-element).

 4. Set `serialized`.\[\[M14\]\] to `value`'s
 [m14 element](#matrix-m14-element).

 5. Set `serialized`.\[\[M21\]\] to `value`'s
 [m21 element](#matrix-m21-element).

 6. Set `serialized`.\[\[M22\]\] to `value`'s
 [m22 element](#matrix-m22-element).

 7. Set `serialized`.\[\[M23\]\] to `value`'s
 [m23 element](#matrix-m23-element).

 8. Set `serialized`.\[\[M24\]\] to `value`'s
 [m24 element](#matrix-m24-element).

 9. Set `serialized`.\[\[M31\]\] to `value`'s
 [m31 element](#matrix-m31-element).

 10. Set `serialized`.\[\[M32\]\] to `value`'s
 [m32 element](#matrix-m32-element).

 11. Set `serialized`.\[\[M33\]\] to `value`'s
 [m33 element](#matrix-m33-element).

 12. Set `serialized`.\[\[M34\]\] to `value`'s
 [m34 element](#matrix-m34-element).

 13. Set `serialized`.\[\[M41\]\] to `value`'s
 [m41 element](#matrix-m41-element).

 14. Set `serialized`.\[\[M42\]\] to `value`'s
 [m42 element](#matrix-m42-element).

 15. Set `serialized`.\[\[M43\]\] to `value`'s
 [m43 element](#matrix-m43-element).

 16. Set `serialized`.\[\[M44\]\] to `value`'s
 [m44 element](#matrix-m44-element).

 17. Set `serialized`.\[\[Is2D\]\] to `false`.

 Their [deserialization
 steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and
 `value`, are:

 1. If `serialized`.\[\[Is2D\]\] is `true`:

 1. Set `value`'s [m11
 element](#matrix-m11-element) to `serialized`.\[\[M11\]\].

 2. Set `value`'s [m12
 element](#matrix-m12-element) to `serialized`.\[\[M12\]\].

 3. Set `value`'s [m13
 element](#matrix-m13-element) to [0].

 4. Set `value`'s [m14
 element](#matrix-m14-element) to [0].

 5. Set `value`'s [m21
 element](#matrix-m21-element) to `serialized`.\[\[M21\]\].

 6. Set `value`'s [m22
 element](#matrix-m22-element) to `serialized`.\[\[M22\]\].

 7. Set `value`'s [m23
 element](#matrix-m23-element) to [0].

 8. Set `value`'s [m24
 element](#matrix-m24-element) to [0].

 9. Set `value`'s [m31
 element](#matrix-m31-element) to [0].

 10. Set `value`'s [m32
 element](#matrix-m32-element) to [0].

 11. Set `value`'s [m33
 element](#matrix-m33-element) to [1].

 12. Set `value`'s [m34
 element](#matrix-m34-element) to [0].

 13. Set `value`'s [m41
 element](#matrix-m41-element) to `serialized`.\[\[M41\]\].

 14. Set `value`'s [m42
 element](#matrix-m42-element) to `serialized`.\[\[M42\]\].

 15. Set `value`'s [m43
 element](#matrix-m43-element) to [0].

 16. Set `value`'s [m44
 element](#matrix-m44-element) to [1].

 17. Set `value`'s [is
 2D](#matrix-is-2d)
 to `true`.

 2. Otherwise:

 1. Set `value`'s [m11
 element](#matrix-m11-element) to `serialized`.\[\[M11\]\].

 2. Set `value`'s [m12
 element](#matrix-m12-element) to `serialized`.\[\[M12\]\].

 3. Set `value`'s [m13
 element](#matrix-m13-element) to `serialized`.\[\[M13\]\].

 4. Set `value`'s [m14
 element](#matrix-m14-element) to `serialized`.\[\[M14\]\].

 5. Set `value`'s [m21
 element](#matrix-m21-element) to `serialized`.\[\[M21\]\].

 6. Set `value`'s [m22
 element](#matrix-m22-element) to `serialized`.\[\[M22\]\].

 7. Set `value`'s [m23
 element](#matrix-m23-element) to `serialized`.\[\[M23\]\].

 8. Set `value`'s [m24
 element](#matrix-m24-element) to `serialized`.\[\[M24\]\].

 9. Set `value`'s [m31
 element](#matrix-m31-element) to `serialized`.\[\[M31\]\].

 10. Set `value`'s [m32
 element](#matrix-m32-element) to `serialized`.\[\[M32\]\].

 11. Set `value`'s [m33
 element](#matrix-m33-element) to `serialized`.\[\[M33\]\].

 12. Set `value`'s [m34
 element](#matrix-m34-element) to `serialized`.\[\[M34\]\].

 13. Set `value`'s [m41
 element](#matrix-m41-element) to `serialized`.\[\[M41\]\].

 14. Set `value`'s [m42
 element](#matrix-m42-element) to `serialized`.\[\[M42\]\].

 15. Set `value`'s [m43
 element](#matrix-m43-element) to `serialized`.\[\[M43\]\].

 16. Set `value`'s [m44
 element](#matrix-m44-element) to `serialized`.\[\[M44\]\].

 17. Set `value`'s [is
 2D](#matrix-is-2d)
 to `false`.

## 8. Security Considerations

The [`DOMMatrix`](#dommatrix) and
[`DOMMatrixReadOnly`](#dommatrixreadonly) interfaces have entry-points to parsing a string with
CSS syntax. Therefore the [security
considerations](https://drafts.csswg.org/css-syntax/#security) of the
CSS Syntax specification apply.
[\[CSS3-SYNTAX\]](#biblio-css3-syntax "CSS Syntax Module Level 3")

(#example-2f98d29f) This could potentially be used to
exploit bugs in the CSS parser in a user agent.

There are no other known security or privacy impacts of the interfaces
defined in this specification. However, other specifications that have
APIs that use the interfaces defined in this specification could
potentially introduce security or privacy issues.

## 9. Privacy Considerations

(#example-8bb3622b) For example, the
[`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect) API defined in CSSOM View returns a
[`DOMRect`](#domrect) that
could be used to measure the size of an inline element containing some
text of a particular font, which exposes information about whether the
user has that font installed. That information, if used to test many
common fonts, can then be personally-identifiable information.
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module")

## 10. Historical

*This section is non-normative.*

The interfaces in this specification are intended to replace earlier
similar interfaces found in various specifications as well as
proprietary interfaces found in some user agents. This section attempts
to enumerate these interfaces.

### 10.1. CSSOM View

Earlier revisions of CSSOM View defined a `ClientRect` interface, which
is replaced by [`DOMRect`](#domrect). Implementations conforming to this specification will
not support `ClientRect`.
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module")

### 10.2. SVG

Earlier revisions of SVG defined
[`SVGPoint`](#svgpoint),
[`SVGRect`](#svgrect),
[`SVGMatrix`](#svgmatrix),
which are defined in this specifications as aliases to
[`DOMPoint`](#dompoint),
[`DOMRect`](#domrect),
[`DOMMatrix`](#dommatrix),
respectively.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")

### 10.3. Non-standard

Some user agents supported a `WebKitPoint` interface. Implementations
conforming to this specification will not support `WebKitPoint`.

Several user agents supported a
[`WebKitCSSMatrix`](#webkitcssmatrix) interface, which is also widely used on the Web. It is
defined in this specification as an alias to
[`DOMMatrix`](#dommatrix).

Some user agents supported a `MSCSSMatrix` interface. Implementations
conforming to this specification will not support `MSCSSMatrix`.

## [Document conventions]
The [NaN-safe minimum] of a non-empty list of
[`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double) values is NaN if any member of the list is NaN, or the
minimum of the list otherwise.

Analogously, the [NaN-safe maximum] of a non-empty list of
[`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double) values is NaN if any member of the list is NaN, or the
maximum of the list otherwise.

## [Changes since last publication]
*This section is non-normative.*

The following changes were made since the [4 December 2018 Candidate
Recommendation](https://www.w3.org/TR/2018/CR-geometry-1-20181204/).

- Clarified that column vectors are pre-multiplied by matrices
 [#294](https://github.com/w3c/fxtf-drafts/issues/294),
 [#359](https://github.com/w3c/fxtf-drafts/issues/359)

- Defined minimum and maximum as preferring NaN
 [#222](https://github.com/w3c/fxtf-drafts/issues/222)

- Used new WebIDL constructor definition

- Added default dictionary value

- Added \[NewObject\] to matrixTransform, to align with prose
 description

- Removed redundant originZ check
 [#350](https://github.com/w3c/fxtf-drafts/issues/350)

- Added explicit \[Exposed\] to DOMRectList

The following changes were made since the [25 November 2014 Candidate
Recommendation](https://www.w3.org/TR/2014/CR-geometry-1-20141125/).

- Changed the interfaces to generally use specific static operations for
 construction instead of using overloaded constructors, and made the
 interfaces more consistent. However,
 [`DOMMatrix`](#dommatrix)
 still uses an overloaded constructor for compatibility with
 [`WebKitCSSMatrix`](#webkitcssmatrix).

- Introduced the
 [`DOMMatrixInit`](#dictdef-dommatrixinit) dictionary.

- Added JSON serializers for the interfaces.

- Changed
 [`DOMMatrixReadOnly`](#dommatrixreadonly) and
 [`DOMMatrix`](#dommatrix)
 to be compatible with
 [`WebKitCSSMatrix`](#webkitcssmatrix):

 - Changed
 [`rotate()`](#dom-dommatrixreadonly-rotate) and
 [`rotateSelf()`](#dom-dommatrix-rotateself) arguments from `(angle, originX, originY)` to
 `(rotX, rotY, rotZ)`.

 - Changed the
 [`scale()`](#dom-dommatrixreadonly-scale) and
 [`scaleSelf()`](#dom-dommatrix-scaleself) methods to be more like the previous
 `scaleNonUniform()`/`scaleNonUniformSelf()` methods, and dropped the
 `scaleNonUniformSelf()` method. Keep support for `scaleNonUniform()`
 for legacy reasons.

 - Made all arguments optional for
 [`DOMMatrix`](#dommatrix)/[`DOMMatrixReadOnly`](#dommatrixreadonly) methods, except for
 [`setMatrixValue()`](#dom-dommatrix-setmatrixvalue).

 - Added no-argument constructor.

 - Defined
 [`WebKitCSSMatrix`](#webkitcssmatrix) to be a legacy window alias for
 [`DOMMatrix`](#dommatrix).

- In workers, [`DOMMatrix`](#dommatrix) and
 [`DOMMatrixReadOnly`](#dommatrixreadonly) do not support parsing or stringifying with CSS
 syntax.

- Defined structured serialization of the interfaces.

- The live `bounds` attribute on
 [`DOMQuad`](#domquad) was
 replaced with a non-live
 [`getBounds()`](#dom-domquad-getbounds) method. The \"associated bounding rectangle\" concept
 was also removed.

- Changed the string parser for
 [`DOMMatrix`](#dommatrix)
 and
 [`DOMMatrixReadOnly`](#dommatrixreadonly) to use CSS rules instead of SVG rules.

- The stringifier for
 [`DOMMatrix`](#dommatrix)
 and
 [`DOMMatrixReadOnly`](#dommatrixreadonly) now throws if there are non-finite values, and
 otherwise uses the
 [ToString](https://tc39.github.io/ecma262/#sec-tostring) algorithm.
 [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification")

- Made comparisons treat [0] and [-0] as equal throughout.

- Added [§ 9 Privacy Considerations](#priv-sec) and [§ 10
 Historical](#historical) sections.

The following changes were made since the [18 September 2014 Working
Draft](https://www.w3.org/TR/2014/WD-geometry-1-20140918/).

- Exposed
 [`DOMPointReadOnly`](#dompointreadonly), [`DOMPoint`](#dompoint),
 [`DOMRectReadOnly`](#domrectreadonly), [`DOMRect`](#domrect), [`DOMQuad`](#domquad),
 [`DOMMatrixReadOnly`](#dommatrixreadonly) and
 [`DOMMatrix`](#dommatrix)
 to
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) and
 [`Worker`](https://html.spec.whatwg.org/multipage/workers.html#worker). Defined cloning of the interface.

The following changes were made since the [26 June 2014 Last Call Public
Working Draft](https://www.w3.org/TR/2014/WD-geometry-1-20140626/).

- [`DOMPointReadOnly`](#dompointreadonly) got a constructor taking 4 arguments.

- [`DOMRectReadOnly`](#domrectreadonly) got a constructor taking 4 arguments.

- [`DOMMatrixReadOnly`](#dommatrixreadonly) got a constructor taking a sequence of numbers as
 argument.

- [`DOMRectList`](#domrectlist) turned to an ArrayClass. The interfaces can just be
 used for legacy interfaces.

- Put [`DOMRectList`](#domrectlist) on at-Risk awaiting browser feedback.

- All interfaces are described in the sense of internal elements to
 describe the read-only/writable and inheriting behavior.

- Replace
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception with
 [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

The following changes were made since the [22 May 2014 First Public
Working Draft](https://www.w3.org/TR/2014/WD-geometry-1-20140522/).

- Renamed mutable transformation methods \*By to \*Self. (E.g.
 `translateBy()` got renamed to
 [`translateSelf()`](#dom-dommatrix-translateself).)

- Renamed `invert()` to
 [`invertSelf()`](#dom-dommatrix-invertself).

- Added
 [`setMatrixValue()`](#dom-dommatrix-setmatrixvalue) which takes a transformation list as
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString).

- [`is2D`](#dom-dommatrixreadonly-is2d) and
 [`isIdentity`](#dom-dommatrixreadonly-isidentity) are read-only attributes now.

- [`DOMMatrixReadOnly`](#dommatrixreadonly) gets flagged to track 3D transformation and attribute
 settings for
 [`is2D`](#dom-dommatrixreadonly-is2d).

- [`invertSelf()`](#dom-dommatrix-invertself) and
 [`inverse()`](#dom-dommatrixreadonly-inverse) do not throw exceptions anymore.

## [Acknowledgments]
The editors would like to thank Robert O'Callahan for contributing to
this specification. Many thanks to Dean Jackson for his initial proposal
of DOMMatrix. Thanks to Adenilson Cavalcanti, Benoit Jacob, Boris
Zbarsky, Brian Birtles, Cameron McCormack, Domenic Denicola, Kari
Pihkala, Max Vujovic, Mike Taylor, Peter Hall, Philip Jägenstedt, Simon
Fraser, and Timothy Loh for their careful reviews, comments, and
corrections.
