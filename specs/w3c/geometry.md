## [1. ]{.secno}[Introduction]{.content}[](#intro){.self-link} {#intro .heading .settled level="1"}

*This section is non-normative.*

This specification describes several geometry interfaces for the
representation of points, rectangles, quadrilaterals and transformation
matrices with the dimension of 3x2 and 4x4.

The SVG interfaces [`SVGPoint`{.idl}](#svgpoint){#ref-for-svgpoint
link-type="idl"}, [`SVGRect`{.idl}](#svgrect){#ref-for-svgrect
link-type="idl"} and [`SVGMatrix`{.idl}](#svgmatrix){#ref-for-svgmatrix
link-type="idl"} are aliasing the here defined interfaces in favor for
common interfaces used by SVG, Canvas 2D Context and CSS Transforms.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"){link-type="biblio"}
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}
[\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

## [2. ]{.secno}[The DOMPoint interfaces]{.content}[](#DOMPoint){.self-link} {#DOMPoint .heading .settled level="2"}

A 2D or a 3D [point]{#point .dfn .dfn-paneled dfn-type="dfn"
noexport=""} can be represented by the following WebIDL interfaces:

``` {.def .highlight .idl}
[Exposed=(Window,Worker),
 Serializable]
interface DOMPointReadOnly {
    constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
            optional unrestricted double z = 0, optional unrestricted double w = 1);

    [NewObject] static DOMPointReadOnly fromPoint(optional DOMPointInit other = {});

    readonly attribute unrestricted double x;
    readonly attribute unrestricted double y;
    readonly attribute unrestricted double z;
    readonly attribute unrestricted double w;

    [NewObject] DOMPoint matrixTransform(optional DOMMatrixInit matrix = {});

    [Default] object toJSON();
};

[Exposed=(Window,Worker),
 Serializable,
 LegacyWindowAlias=SVGPoint]
interface DOMPoint : DOMPointReadOnly {
    constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
            optional unrestricted double z = 0, optional unrestricted double w = 1);

    [NewObject] static DOMPoint fromPoint(optional DOMPointInit other = {});

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
[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly②
link-type="idl"} objects have the internal member variables [x
coordinate]{#point-x-coordinate .dfn .dfn-paneled dfn-for="point"
dfn-type="dfn" noexport=""}, [y coordinate]{#point-y-coordinate .dfn
.dfn-paneled dfn-for="point" dfn-type="dfn" noexport=""}, [z
coordinate]{#point-z-coordinate .dfn .dfn-paneled dfn-for="point"
dfn-type="dfn" lt="z coordinate" noexport=""} and [w
perspective]{#point-w-perspective .dfn .dfn-paneled dfn-for="point"
dfn-type="dfn" noexport=""}.
[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly③
link-type="idl"} as well as the inheriting interface
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint② link-type="idl"} must
be able to access and set the value of these variables.

An interface returning an
[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly④
link-type="idl"} object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The
[`DOMPointReadOnly(``x`{.variable}`, ``y`{.variable}`, ``z`{.variable}`, ``w`{.variable}`)`]{#dom-dompointreadonly-dompointreadonly
.dfn .dfn-paneled .idl-code dfn-for="DOMPointReadOnly"
dfn-type="constructor" export=""
lt="DOMPointReadOnly(x, y, z, w)|constructor(x, y, z, w)|DOMPointReadOnly(x, y, z)|constructor(x, y, z)|DOMPointReadOnly(x, y)|constructor(x, y)|DOMPointReadOnly(x)|constructor(x)|DOMPointReadOnly()|constructor()"}
and
[`DOMPoint(``x`{.variable}`, ``y`{.variable}`, ``z`{.variable}`, ``w`{.variable}`)`]{#dom-dompoint-dompoint
.dfn .dfn-paneled .idl-code dfn-for="DOMPoint" dfn-type="constructor"
export=""
lt="DOMPoint(x, y, z, w)|constructor(x, y, z, w)|DOMPoint(x, y, z)|constructor(x, y, z)|DOMPoint(x, y)|constructor(x, y)|DOMPoint(x)|constructor(x)|DOMPoint()|constructor()"}
constructors, when invoked, must run the following steps:

1.  Let `point`{.variable} be a new
    [`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly⑤
    link-type="idl"} or [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint③
    link-type="idl"} object as appropriate.

2.  Set `point`{.variable}'s variables [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate
    link-type="dfn"} to `x`{.variable}, [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate
    link-type="dfn"} to `y`{.variable}, [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate
    link-type="dfn"} to `z`{.variable} and [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective
    link-type="dfn"} to `w`{.variable}.

3.  Return `point`{.variable}.

The [`fromPoint(``other`{.variable}`)`]{#dom-dompointreadonly-frompoint
.dfn .dfn-paneled .idl-code dfn-for="DOMPointReadOnly" dfn-type="method"
export="" lt="fromPoint(other)|fromPoint()"} static method on
[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly⑥
link-type="idl"} must [create a `DOMPointReadOnly` from the
dictionary](#create-a-dompointreadonly-from-the-dictionary){#ref-for-create-a-dompointreadonly-from-the-dictionary
link-type="dfn"} `other`{.variable}.

The [`fromPoint(``other`{.variable}`)`]{#dom-dompoint-frompoint .dfn
.dfn-paneled .idl-code dfn-for="DOMPoint" dfn-type="method" export=""
lt="fromPoint(other)|fromPoint()"} static method on
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint④ link-type="idl"} must
[create a `DOMPoint` from the
dictionary](#create-a-dompoint-from-the-dictionary){#ref-for-create-a-dompoint-from-the-dictionary
link-type="dfn"} `other`{.variable}.

To [create a `DOMPointReadOnly` from a
dictionary]{#create-a-dompointreadonly-from-the-dictionary .dfn
.dfn-paneled dfn-type="dfn"
lt="create a DOMPointReadOnly from the dictionary" noexport=""}
`other`{.variable}, or to [create a `DOMPoint` from a
dictionary]{#create-a-dompoint-from-the-dictionary .dfn .dfn-paneled
dfn-type="dfn" lt="create a DOMPoint from the
dictionary" noexport=""} `other`{.variable}, follow these steps:

1.  Let `point`{.variable} be a new
    [`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly⑦
    link-type="idl"} or [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint⑤
    link-type="idl"} as appropriate.

2.  Set `point`{.variable}'s variables [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate①
    link-type="dfn"} to `other`{.variable}'s
    [`x`{.idl}](#dom-dompointinit-x){#ref-for-dom-dompointinit-x
    link-type="idl"} dictionary member, [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate①
    link-type="dfn"} to `other`{.variable}'s
    [`y`{.idl}](#dom-dompointinit-y){#ref-for-dom-dompointinit-y
    link-type="idl"} dictionary member, [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate①
    link-type="dfn"} to `other`{.variable}'s
    [`z`{.idl}](#dom-dompointinit-z){#ref-for-dom-dompointinit-z
    link-type="idl"} dictionary member and [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective①
    link-type="dfn"} to `other`{.variable}'s
    [`w`{.idl}](#dom-dompointinit-w){#ref-for-dom-dompointinit-w
    link-type="idl"} dictionary member.

3.  Return `point`{.variable}.

::: {}
The [`x`]{#dom-dompointreadonly-x .dfn .dfn-paneled .idl-code
dfn-for="DOMPointReadOnly, DOMPoint" dfn-type="attribute" export=""}
attribute, on getting, must return the [x
coordinate](#point-x-coordinate){#ref-for-point-x-coordinate②
link-type="dfn"} value. For the
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint⑥ link-type="idl"}
interface, setting the
[`x`{.idl}](#dom-dompointreadonly-x){#ref-for-dom-dompointreadonly-x②
link-type="idl"} attribute must set the [x
coordinate]{#ref-for-point-x-coordinate③} to the new value.

The [`y`]{#dom-dompointreadonly-y .dfn .dfn-paneled .idl-code
dfn-for="DOMPointReadOnly, DOMPoint" dfn-type="attribute" export=""}
attribute, on getting, must return the [y
coordinate](#point-y-coordinate){#ref-for-point-y-coordinate②
link-type="dfn"} value. For the
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint⑦ link-type="idl"}
interface, setting the
[`y`{.idl}](#dom-dompointreadonly-y){#ref-for-dom-dompointreadonly-y②
link-type="idl"} attribute must set the [y
coordinate]{#ref-for-point-y-coordinate③} to the new value.

The [`z`]{#dom-dompointreadonly-z .dfn .dfn-paneled .idl-code
dfn-for="DOMPointReadOnly, DOMPoint" dfn-type="attribute" export=""}
attribute, on getting, must return the [z
coordinate](#point-z-coordinate){#ref-for-point-z-coordinate②
link-type="dfn"} value. For the
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint⑧ link-type="idl"}
interface, setting the
[`z`{.idl}](#dom-dompointreadonly-z){#ref-for-dom-dompointreadonly-z②
link-type="idl"} attribute must set the [z
coordinate]{#ref-for-point-z-coordinate③} to the new value.

The [`w`]{#dom-dompointreadonly-w .dfn .dfn-paneled .idl-code
dfn-for="DOMPointReadOnly, DOMPoint" dfn-type="attribute" export=""}
attribute, on getting, must return the [w
perspective](#point-w-perspective){#ref-for-point-w-perspective②
link-type="dfn"} value. For the
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint⑨ link-type="idl"}
interface, setting the
[`w`{.idl}](#dom-dompointreadonly-w){#ref-for-dom-dompointreadonly-w②
link-type="idl"} attribute must set the [w
perspective]{#ref-for-point-w-perspective③} to the new value.
:::

The
[`matrixTransform(``matrix`{.variable}`)`]{#dom-dompointreadonly-matrixtransform
.dfn .dfn-paneled .idl-code dfn-for="DOMPointReadOnly" dfn-type="method"
export="" lt="matrixTransform(matrix)|matrixTransform()"} method, when
invoked, must run the following steps:

1.  Let `matrixObject`{.variable} be the result of invoking [create a
    `DOMMatrix` from the
    dictionary](#create-a-dommatrix-from-the-dictionary){#ref-for-create-a-dommatrix-from-the-dictionary
    link-type="dfn"} `matrix`{.variable}.

2.  Return the result of invoking [transform a point with a
    matrix](#transform-a-point-with-a-matrix){#ref-for-transform-a-point-with-a-matrix
    link-type="dfn"}, given the current point and
    `matrixObject`{.variable}. The current point does not get modified.

::: {#example-81a83758 .example}
[](#example-81a83758){.self-link} In this example the method
[`matrixTransform()`{.idl}](#dom-dompointreadonly-matrixtransform){#ref-for-dom-dompointreadonly-matrixtransform①
link-type="idl"} on a [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint①⓪
link-type="idl"} instance is called with a
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix link-type="idl"}
instance as argument.

``` highlight
var point = new DOMPoint(5, 4);
var matrix = new DOMMatrix([2, 0, 0, 2, 10, 10]);
var transformedPoint = point.matrixTransform(matrix);
```

The `point`{.variable} variable is set to a new
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint①① link-type="idl"}
object with [x
coordinate](#point-x-coordinate){#ref-for-point-x-coordinate④
link-type="dfn"} initialized to 5 and [y
coordinate](#point-y-coordinate){#ref-for-point-y-coordinate④
link-type="dfn"} initialized to 4. This new
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint①② link-type="idl"} is
now scaled and the translated by `matrix`{.variable}. This resulting
`transformedPoint`{.variable} has the [x
coordinate]{#ref-for-point-x-coordinate⑤} 20 and [y
coordinate]{#ref-for-point-y-coordinate⑤} 18.
:::

### [2.1. ]{.secno}[Transforming a point with a matrix]{.content}[](#transforming-a-point-with-a-matrix){.self-link} {#transforming-a-point-with-a-matrix .heading .settled level="2.1"}

To [transform a [point](#point){#ref-for-point link-type="dfn"} with a
[matrix](#matrix){#ref-for-matrix
link-type="dfn"}]{#transform-a-point-with-a-matrix .dfn .dfn-paneled
dfn-type="dfn" export=""}, given `point`{.variable} and
`matrix`{.variable}:

1.  Let `x`{.variable} be `point`{.variable}'s [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate⑥
    link-type="dfn"}.

2.  Let `y`{.variable} be `point`{.variable}'s [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate⑥
    link-type="dfn"}.

3.  Let `z`{.variable} be `point`{.variable}'s [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate④
    link-type="dfn"}.

4.  Let `w`{.variable} be `point`{.variable}'s [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective④
    link-type="dfn"}.

5.  Let `pointVector`{.variable} be a new column vector with the
    elements being `x`{.variable}, `y`{.variable}, `z`{.variable}, and
    `w`{.variable}, respectively.

    $\begin{bmatrix}
    x \\
    y \\
    z \\
    w
    \end{bmatrix}$

6.  Set `pointVector`{.variable} to `pointVector`{.variable}
    [pre-multiplied](#pre-multiply){#ref-for-pre-multiply
    link-type="dfn"} by `matrix`{.variable}.

7.  Let `transformedPoint`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint①③ link-type="idl"}
    object.

8.  Set `transformedPoint`{.variable}'s [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate⑦
    link-type="dfn"} to `pointVector`{.variable}'s first element.

9.  Set `transformedPoint`{.variable}'s [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate⑦
    link-type="dfn"} to `pointVector`{.variable}'s second element.

10. Set `transformedPoint`{.variable}'s [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate⑤
    link-type="dfn"} to `pointVector`{.variable}'s third element.

11. Set `transformedPoint`{.variable}'s [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective⑤
    link-type="dfn"} to `pointVector`{.variable}'s fourth element.

12. Return `transformedPoint`{.variable}.

[Note:]{.marker} If `matrix`{.variable}'s [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d link-type="dfn"} is true,
`point`{.variable}'s [z
coordinate](#point-z-coordinate){#ref-for-point-z-coordinate⑥
link-type="dfn"} is [0]{.css} or [-0]{.css}, and `point`{.variable}'s [w
perspective](#point-w-perspective){#ref-for-point-w-perspective⑥
link-type="dfn"} is [1]{.css}, then this is a 2D transformation.
Otherwise this is a 3D transformation.

## [3. ]{.secno}[The DOMRect interfaces]{.content}[](#DOMRect){.self-link} {#DOMRect .heading .settled level="3"}

Objects implementing the
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly
link-type="idl"} interface represent a [rectangle]{#rectangle .dfn
.dfn-paneled dfn-type="dfn" noexport=""}.

[Rectangles](#rectangle){#ref-for-rectangle link-type="dfn"} have the
following properties:

[origin]{#rectangle-origin .dfn .dfn-paneled dfn-for="rectangle" dfn-type="dfn" noexport=""}

:   When the rectangle has a non-negative [width
    dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension
    link-type="dfn"}, the rectangle's horizontal origin is the left
    edge; otherwise, it is the right edge. Similarly, when the rectangle
    has a non-negative [height
    dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension
    link-type="dfn"}, the rectangle's vertical origin is the top edge;
    otherwise, it is the bottom edge.

[x coordinate]{#rectangle-x-coordinate .dfn .dfn-paneled dfn-for="rectangle" dfn-type="dfn" noexport=""}

:   The horizontal distance between the viewport's left edge and the
    rectangle's [origin](#rectangle-origin){#ref-for-rectangle-origin
    link-type="dfn"}.

[y coordinate]{#rectangle-y-coordinate .dfn .dfn-paneled dfn-for="rectangle" dfn-type="dfn" noexport=""}

:   The vertical distance between the viewport's top edge and the
    rectangle's [origin](#rectangle-origin){#ref-for-rectangle-origin①
    link-type="dfn"}.

[width dimension]{#rectangle-width-dimension .dfn .dfn-paneled dfn-for="rectangle" dfn-type="dfn" noexport=""}

:   The width of the rectangle. Can be negative.

[height dimension]{#rectangle-height-dimension .dfn .dfn-paneled dfn-for="rectangle" dfn-type="dfn" noexport=""}

:   The height of the rectangle. Can be negative.

``` {.def .highlight .idl}
[Exposed=(Window,Worker),
 Serializable]
interface DOMRectReadOnly {
    constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
            optional unrestricted double width = 0, optional unrestricted double height = 0);

    [NewObject] static DOMRectReadOnly fromRect(optional DOMRectInit other = {});

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

    [NewObject] static DOMRect fromRect(optional DOMRectInit other = {});

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
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly③
link-type="idl"} objects have the internal member variables [x
coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate
link-type="dfn"}, [y
coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate
link-type="dfn"}, [width
dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension①
link-type="dfn"} and [height
dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension①
link-type="dfn"}.
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly④
link-type="idl"} as well as the inheriting interface
[`DOMRect`{.idl}](#domrect){#ref-for-domrect① link-type="idl"} must be
able to access and set the value of these variables.

An interface returning an
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly⑤
link-type="idl"} object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The
[`DOMRectReadOnly(``x`{.variable}`, ``y`{.variable}`, ``width`{.variable}`, ``height`{.variable}`)`]{#dom-domrectreadonly-domrectreadonly
.dfn .dfn-paneled .idl-code dfn-for="DOMRectReadOnly"
dfn-type="constructor" export=""
lt="DOMRectReadOnly(x, y, width, height)|constructor(x, y, width, height)|DOMRectReadOnly(x, y, width)|constructor(x, y, width)|DOMRectReadOnly(x, y)|constructor(x, y)|DOMRectReadOnly(x)|constructor(x)|DOMRectReadOnly()|constructor()"}
and
[`DOMRect(``x`{.variable}`, ``y`{.variable}`, ``width`{.variable}`, ``height`{.variable}`)`]{#dom-domrect-domrect
.dfn .dfn-paneled .idl-code dfn-for="DOMRect" dfn-type="constructor"
export=""
lt="DOMRect(x, y, width, height)|constructor(x, y, width, height)|DOMRect(x, y, width)|constructor(x, y, width)|DOMRect(x, y)|constructor(x, y)|DOMRect(x)|constructor(x)|DOMRect()|constructor()"}
constructors, when invoked, must run the following steps:

1.  Let `rect`{.variable} be a new
    [`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly⑥
    link-type="idl"} or [`DOMRect`{.idl}](#domrect){#ref-for-domrect②
    link-type="idl"} object as appropriate.

2.  Set `rect`{.variable}'s variables [x
    coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate①
    link-type="dfn"} to `x`{.variable}, [y
    coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate①
    link-type="dfn"} to `y`{.variable}, [width
    dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension②
    link-type="dfn"} to `width`{.variable} and [height
    dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension②
    link-type="dfn"} to `height`{.variable}.

3.  Return `rect`{.variable}.

The [`fromRect(``other`{.variable}`)`]{#dom-domrectreadonly-fromrect
.dfn .dfn-paneled .idl-code dfn-for="DOMRectReadOnly" dfn-type="method"
export="" lt="fromRect(other)|fromRect()"} static method on
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly⑦
link-type="idl"} must [create a `DOMRectReadOnly` from the
dictionary](#create-a-domrectreadonly-from-the-dictionary){#ref-for-create-a-domrectreadonly-from-the-dictionary
link-type="dfn"} `other`{.variable}.

The [`fromRect(``other`{.variable}`)`]{#dom-domrect-fromrect .dfn
.dfn-paneled .idl-code dfn-for="DOMRect" dfn-type="method" export=""
lt="fromRect(other)|fromRect()"} static method on
[`DOMRect`{.idl}](#domrect){#ref-for-domrect③ link-type="idl"} must
[create a `DOMRect` from the
dictionary](#create-a-domrect-from-the-dictionary){#ref-for-create-a-domrect-from-the-dictionary
link-type="dfn"} `other`{.variable}.

To [create a `DOMRectReadOnly` from a
dictionary]{#create-a-domrectreadonly-from-the-dictionary .dfn
.dfn-paneled dfn-type="dfn"
lt="create a DOMRectReadOnly from the dictionary" noexport=""}
`other`{.variable}, or to [create a `DOMRect` from a
dictionary]{#create-a-domrect-from-the-dictionary .dfn .dfn-paneled
dfn-type="dfn" lt="create a DOMRect from the
dictionary" noexport=""} `other`{.variable}, follow these steps:

1.  Let `rect`{.variable} be a new
    [`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly⑧
    link-type="idl"} or [`DOMRect`{.idl}](#domrect){#ref-for-domrect④
    link-type="idl"} as appropriate.

2.  Set `rect`{.variable}'s variables [x
    coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate②
    link-type="dfn"} to `other`{.variable}'s
    [`x`{.idl}](#dom-domrectinit-x){#ref-for-dom-domrectinit-x
    link-type="idl"} dictionary member, [y
    coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate②
    link-type="dfn"} to `other`{.variable}'s
    [`y`{.idl}](#dom-domrectinit-y){#ref-for-dom-domrectinit-y
    link-type="idl"} dictionary member, [width
    dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension③
    link-type="dfn"} to `other`{.variable}'s
    [`width`{.idl}](#dom-domrectinit-width){#ref-for-dom-domrectinit-width
    link-type="idl"} dictionary member and [height
    dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension③
    link-type="dfn"} to `other`{.variable}'s
    [`height`{.idl}](#dom-domrectinit-height){#ref-for-dom-domrectinit-height
    link-type="idl"} dictionary member.

3.  Return `rect`{.variable}.

::: {}
The [`x`]{#dom-domrectreadonly-domrect-x .dfn .dfn-paneled .idl-code
dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute" export=""}
attribute, on getting, must return the [x
coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate③
link-type="dfn"} value. For the
[`DOMRect`{.idl}](#domrect){#ref-for-domrect⑤ link-type="idl"}
interface, setting the
[`x`{.idl}](#dom-domrect-x){#ref-for-dom-domrect-x link-type="idl"}
attribute must set the [x coordinate]{#ref-for-rectangle-x-coordinate④}
to the new value.

The [`y`]{#dom-domrectreadonly-domrect-y .dfn .dfn-paneled .idl-code
dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute" export=""}
attribute, on getting, it must return the [y
coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate③
link-type="dfn"} value. For the
[`DOMRect`{.idl}](#domrect){#ref-for-domrect⑥ link-type="idl"}
interface, setting the
[`y`{.idl}](#dom-domrect-y){#ref-for-dom-domrect-y link-type="idl"}
attribute must set the [y coordinate]{#ref-for-rectangle-y-coordinate④}
to the new value.

The [`width`]{#dom-domrectreadonly-domrect-width .dfn .dfn-paneled
.idl-code dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute"
export=""} attribute, on getting, must return the [width
dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension④
link-type="dfn"} value. For the
[`DOMRect`{.idl}](#domrect){#ref-for-domrect⑦ link-type="idl"}
interface, setting the
[`width`{.idl}](#dom-domrect-width){#ref-for-dom-domrect-width
link-type="idl"} attribute must set the [width
dimension]{#ref-for-rectangle-width-dimension⑤} to the new value.

The [`height`]{#dom-domrectreadonly-domrect-height .dfn .dfn-paneled
.idl-code dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute"
export=""} attribute, on getting, must return the [height
dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension④
link-type="dfn"} value. For the
[`DOMRect`{.idl}](#domrect){#ref-for-domrect⑧ link-type="idl"}
interface, setting the
[`height`{.idl}](#dom-domrect-height){#ref-for-dom-domrect-height
link-type="idl"} attribute must set the [height
dimension]{#ref-for-rectangle-height-dimension⑤} value to the new value.

The [`top`]{#dom-domrectreadonly-domrect-top .dfn .dfn-paneled .idl-code
dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute" export=""}
attribute, on getting, must return the [NaN-safe
minimum](#nan-safe-minimum){#ref-for-nan-safe-minimum link-type="dfn"}
of the [y
coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate⑤
link-type="dfn"} and the sum of the [y
coordinate]{#ref-for-rectangle-y-coordinate⑥} and the [height
dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension⑥
link-type="dfn"}.

The [`right`]{#dom-domrectreadonly-domrect-right .dfn .dfn-paneled
.idl-code dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute"
export=""} attribute, on getting, must return the [NaN-safe
maximum](#nan-safe-maximum){#ref-for-nan-safe-maximum link-type="dfn"}
of the [x
coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate⑤
link-type="dfn"} and the sum of the [x
coordinate]{#ref-for-rectangle-x-coordinate⑥} and the [width
dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension⑥
link-type="dfn"}.

The [`bottom`]{#dom-domrectreadonly-domrect-bottom .dfn .dfn-paneled
.idl-code dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute"
export=""} attribute, on getting, must return the [NaN-safe
maximum](#nan-safe-maximum){#ref-for-nan-safe-maximum① link-type="dfn"}
of the [y
coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate⑦
link-type="dfn"} and the sum of the [y
coordinate]{#ref-for-rectangle-y-coordinate⑧} and the [height
dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension⑦
link-type="dfn"}.

The [`left`]{#dom-domrectreadonly-domrect-left .dfn .dfn-paneled
.idl-code dfn-for="DOMRectReadOnly DOMRect" dfn-type="attribute"
export=""} attribute, on getting, must return the [NaN-safe
minimum](#nan-safe-minimum){#ref-for-nan-safe-minimum① link-type="dfn"}
of the [x
coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate⑦
link-type="dfn"} and the sum of the [x
coordinate]{#ref-for-rectangle-x-coordinate⑧} and the [width
dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension⑦
link-type="dfn"}.
:::

## [4. ]{.secno}[The DOMRectList interface]{.content}[](#DOMRectList){.self-link} {#DOMRectList .heading .settled level="4"}

``` {.def .highlight .idl}
[Exposed=Window]
interface DOMRectList {
    readonly attribute unsigned long length;
    getter DOMRect? item(unsigned long index);
};
```

The [`length`]{#dom-domrectlist-length .dfn .dfn-paneled .idl-code
dfn-for="DOMRectList" dfn-type="attribute" export=""} attribute must
return the total number of
[`DOMRect`{.idl}](#domrect){#ref-for-domrect①⓪ link-type="idl"} objects
associated with the object.

The [`item(``index`{.variable}`)`]{#dom-domrectlist-item .dfn
.dfn-paneled .idl-code dfn-for="DOMRectList" dfn-type="method"
export=""} method, when invoked, must return [null]{.css} when
`index`{.variable} is greater than or equal to the number of
[`DOMRect`{.idl}](#domrect){#ref-for-domrect①① link-type="idl"} objects
associated with the
[`DOMRectList`{.idl}](#domrectlist){#ref-for-domrectlist
link-type="idl"}. Otherwise, the
[`DOMRect`{.idl}](#domrect){#ref-for-domrect①② link-type="idl"} object
at `index`{.variable} must be returned. Indices are zero-based.

**[`DOMRectList`{.idl}](#domrectlist){#ref-for-domrectlist①
link-type="idl"} only exists for compatibility with legacy Web content.
When specifying a new API,
[`DOMRectList`{.idl}](#domrectlist){#ref-for-domrectlist②
link-type="idl"} must not be used. Use `sequence<DOMRect>` instead.
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard"){link-type="biblio"}**

## [5. ]{.secno}[The DOMQuad interface]{.content}[](#DOMQuad){.self-link} {#DOMQuad .heading .settled level="5"}

Objects implementing the [`DOMQuad`{.idl}](#domquad){#ref-for-domquad
link-type="idl"} interface represents a [quadrilateral]{#quadrilateral
.dfn .dfn-paneled dfn-type="dfn" export=""}.

``` {.def .highlight .idl}
[Exposed=(Window,Worker),
 Serializable]
interface DOMQuad {
    constructor(optional DOMPointInit p1 = {}, optional DOMPointInit p2 = {},
            optional DOMPointInit p3 = {}, optional DOMPointInit p4 = {});

    [NewObject] static DOMQuad fromRect(optional DOMRectInit other = {});
    [NewObject] static DOMQuad fromQuad(optional DOMQuadInit other = {});

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
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad③ link-type="idl"} objects
have the internal member variables [point 1]{#quadrilateral-point-1 .dfn
.dfn-paneled dfn-for="quadrilateral" dfn-type="dfn" noexport=""}, [point
2]{#quadrilateral-point-2 .dfn .dfn-paneled dfn-for="quadrilateral"
dfn-type="dfn" noexport=""}, [point 3]{#quadrilateral-point-3 .dfn
.dfn-paneled dfn-for="quadrilateral" dfn-type="dfn" lt="point 3"
noexport=""}, and [point 4]{#quadrilateral-point-4 .dfn .dfn-paneled
dfn-for="quadrilateral" dfn-type="dfn" noexport=""}, which are
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint①⑧ link-type="idl"}
objects. [`DOMQuad`{.idl}](#domquad){#ref-for-domquad④ link-type="idl"}
must be able to access and set the value of these variables. The author
can modify these [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint①⑨
link-type="idl"} objects, which directly affects the quadrilateral.

An interface returning a [`DOMQuad`{.idl}](#domquad){#ref-for-domquad⑤
link-type="idl"} object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The
[`DOMQuad(``p1`{.variable}`, ``p2`{.variable}`, ``p3`{.variable}`, ``p4`{.variable}`)`]{#dom-domquad-domquad
.dfn .dfn-paneled .idl-code dfn-for="DOMQuad" dfn-type="constructor"
export=""
lt="DOMQuad(p1, p2, p3, p4)|constructor(p1, p2, p3, p4)|DOMQuad(p1, p2, p3)|constructor(p1, p2, p3)|DOMQuad(p1, p2)|constructor(p1, p2)|DOMQuad(p1)|constructor(p1)|DOMQuad()|constructor()"}
constructor, when invoked, must run the following steps:

1.  Let `point1`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②⓪ link-type="idl"}
    object with its attributes set to the values of the namesake
    dictionary members in `p1`{.variable}.

2.  Let `point2`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②① link-type="idl"}
    object with its attributes set to the values of the namesake
    dictionary members in `p2`{.variable}.

3.  Let `point3`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②② link-type="idl"}
    object with its attributes set to the values of the namesake
    dictionary members in `p3`{.variable}.

4.  Let `point4`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②③ link-type="idl"}
    object with its attributes set to the values of the namesake
    dictionary members in `p4`{.variable}.

5.  Return a new [`DOMQuad`{.idl}](#domquad){#ref-for-domquad⑥
    link-type="idl"} with [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1
    link-type="dfn"} set to `point1`{.variable}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2
    link-type="dfn"} set to `point2`{.variable}, [point
    3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3
    link-type="dfn"} set to `point3`{.variable} and [point
    4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4
    link-type="dfn"} set to `point4`{.variable}.

[Note:]{.marker} It is possible to pass
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②④
link-type="idl"}/[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly⑧
link-type="idl"} arguments as well. The passed arguments will be
transformed to the correct object type internally following the WebIDL
rules.
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard"){link-type="biblio"}

The [`fromRect(``other`{.variable}`)`]{#dom-domquad-fromrect .dfn
.dfn-paneled .idl-code dfn-for="DOMQuad" dfn-type="method" export=""
lt="fromRect(other)|fromRect()"} static method on
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad⑦ link-type="idl"} must
[create a `DOMQuad` from the `DOMRectInit`
dictionary](#create-a-domquad-from-the-domrectinit-dictionary){#ref-for-create-a-domquad-from-the-domrectinit-dictionary
link-type="dfn"} `other`{.variable}.

To [create a `DOMQuad` from a `DOMRectInit`
dictionary]{#create-a-domquad-from-the-domrectinit-dictionary .dfn
.dfn-paneled dfn-type="dfn"
lt="create a DOMQuad from the DOMRectInit dictionary" noexport=""}
`other`{.variable}, follow these steps:

1.  Let `x`{.variable}, `y`{.variable}, `width`{.variable} and
    `height`{.variable} be the value of `other`{.variable}'s
    [`x`{.idl}](#dom-domrectinit-x){#ref-for-dom-domrectinit-x①
    link-type="idl"},
    [`y`{.idl}](#dom-domrectinit-y){#ref-for-dom-domrectinit-y①
    link-type="idl"},
    [`width`{.idl}](#dom-domrectinit-width){#ref-for-dom-domrectinit-width①
    link-type="idl"} and
    [`height`{.idl}](#dom-domrectinit-height){#ref-for-dom-domrectinit-height①
    link-type="idl"} dictionary members, respectively.

2.  Let `point1`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②⑤ link-type="idl"}
    object with [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate⑧
    link-type="dfn"} set to `x`{.variable}, [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate⑧
    link-type="dfn"} set to `y`{.variable}, [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate⑦
    link-type="dfn"} set to [0]{.css} and [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective⑦
    link-type="dfn"} set to [1]{.css}.

3.  Let `point2`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②⑥ link-type="idl"}
    object with [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate⑨
    link-type="dfn"} set to `x`{.variable} + `width`{.variable}, [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate⑨
    link-type="dfn"} set to `y`{.variable}, [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate⑧
    link-type="dfn"} set to [0]{.css} and [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective⑧
    link-type="dfn"} set to [1]{.css}.

4.  Let `point3`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②⑦ link-type="idl"}
    object with [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate①⓪
    link-type="dfn"} set to `x`{.variable} + `width`{.variable}, [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate①⓪
    link-type="dfn"} set to `y`{.variable} + `height`{.variable}, [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate⑨
    link-type="dfn"} set to [0]{.css} and [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective⑨
    link-type="dfn"} set to [1]{.css}.

5.  Let `point4`{.variable} be a new
    [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②⑧ link-type="idl"}
    object with [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate①①
    link-type="dfn"} set to `x`{.variable}, [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate①①
    link-type="dfn"} set to `y`{.variable} + `height`{.variable}, [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate①⓪
    link-type="dfn"} set to [0]{.css} and [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective①⓪
    link-type="dfn"} set to [1]{.css}.

6.  Return a new [`DOMQuad`{.idl}](#domquad){#ref-for-domquad⑧
    link-type="idl"} with [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1①
    link-type="dfn"} set to `point1`{.variable}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2①
    link-type="dfn"} set to `point2`{.variable}, [point
    3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3①
    link-type="dfn"} set to `point3`{.variable} and [point
    4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4①
    link-type="dfn"} set to `point4`{.variable}.

The [`fromQuad(``other`{.variable}`)`]{#dom-domquad-fromquad .dfn
.dfn-paneled .idl-code dfn-for="DOMQuad" dfn-type="method" export=""
lt="fromQuad(other)|fromQuad()"} static method on
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad⑨ link-type="idl"} must
[create a `DOMQuad` from the `DOMQuadInit`
dictionary](#create-a-domquad-from-the-domquadinit-dictionary){#ref-for-create-a-domquad-from-the-domquadinit-dictionary
link-type="dfn"} `other`{.variable}.

To [create a `DOMQuad` from a `DOMQuadInit`
dictionary]{#create-a-domquad-from-the-domquadinit-dictionary .dfn
.dfn-paneled dfn-type="dfn"
lt="create a DOMQuad from the DOMQuadInit dictionary" noexport=""}
`other`{.variable}, follow these steps:

1.  Let `point1`{.variable} be the result of invoking [create a
    `DOMPoint` from the
    dictionary](#create-a-dompoint-from-the-dictionary){#ref-for-create-a-dompoint-from-the-dictionary①
    link-type="dfn"}
    [`p1`{.idl}](#dom-domquadinit-p1){#ref-for-dom-domquadinit-p1
    link-type="idl"} dictionary member of `other`{.variable}, if it
    exists.

2.  Let `point2`{.variable} be the result of invoking [create a
    `DOMPoint` from the
    dictionary](#create-a-dompoint-from-the-dictionary){#ref-for-create-a-dompoint-from-the-dictionary②
    link-type="dfn"}
    [`p2`{.idl}](#dom-domquadinit-p2){#ref-for-dom-domquadinit-p2
    link-type="idl"} dictionary member of `other`{.variable}, if it
    exists.

3.  Let `point3`{.variable} be the result of invoking [create a
    `DOMPoint` from the
    dictionary](#create-a-dompoint-from-the-dictionary){#ref-for-create-a-dompoint-from-the-dictionary③
    link-type="dfn"}
    [`p3`{.idl}](#dom-domquadinit-p3){#ref-for-dom-domquadinit-p3
    link-type="idl"} dictionary member of `other`{.variable}, if it
    exists.

4.  Let `point4`{.variable} be the result of invoking [create a
    `DOMPoint` from the
    dictionary](#create-a-dompoint-from-the-dictionary){#ref-for-create-a-dompoint-from-the-dictionary④
    link-type="dfn"}
    [`p4`{.idl}](#dom-domquadinit-p4){#ref-for-dom-domquadinit-p4
    link-type="idl"} dictionary member of `other`{.variable}, if it
    exists.

5.  Return a new [`DOMQuad`{.idl}](#domquad){#ref-for-domquad①⓪
    link-type="idl"} with [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1②
    link-type="dfn"} set to `point1`{.variable}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2②
    link-type="dfn"} set to `point2`{.variable}, [point
    3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3②
    link-type="dfn"} set to `point3`{.variable} and [point
    4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4②
    link-type="dfn"} set to `point4`{.variable}.

::: {}
The [`p1`]{#dom-domquad-p1 .dfn .dfn-paneled .idl-code dfn-for="DOMQuad"
dfn-type="attribute" export=""} attribute must return [point
1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1③
link-type="dfn"}.

The [`p2`]{#dom-domquad-p2 .dfn .dfn-paneled .idl-code dfn-for="DOMQuad"
dfn-type="attribute" export=""} attribute must return [point
2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2③
link-type="dfn"}.

The [`p3`]{#dom-domquad-p3 .dfn .dfn-paneled .idl-code dfn-for="DOMQuad"
dfn-type="attribute" export=""} attribute must return [point
3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3③
link-type="dfn"}.

The [`p4`]{#dom-domquad-p4 .dfn .dfn-paneled .idl-code dfn-for="DOMQuad"
dfn-type="attribute" export=""} attribute must return [point
4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4③
link-type="dfn"}.
:::

The [`getBounds()`]{#dom-domquad-getbounds .dfn .dfn-paneled .idl-code
dfn-for="DOMQuad" dfn-type="method" export=""} method, when invoked,
must run the following algorithm:

1.  Let `bounds`{.variable} be a
    [`DOMRect`{.idl}](#domrect){#ref-for-domrect①④ link-type="idl"}
    object.

2.  Let `left`{.variable} be the [NaN-safe
    minimum](#nan-safe-minimum){#ref-for-nan-safe-minimum②
    link-type="dfn"} of [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1④
    link-type="dfn"}'s [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate①②
    link-type="dfn"}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2④
    link-type="dfn"}'s [x coordinate]{#ref-for-point-x-coordinate①③},
    [point 3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3④
    link-type="dfn"}'s [x coordinate]{#ref-for-point-x-coordinate①④} and
    [point 4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4④
    link-type="dfn"}'s [x coordinate]{#ref-for-point-x-coordinate①⑤}.

3.  Let `top`{.variable} be the [NaN-safe
    minimum](#nan-safe-minimum){#ref-for-nan-safe-minimum③
    link-type="dfn"} of [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1⑤
    link-type="dfn"}'s [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate①②
    link-type="dfn"}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2⑤
    link-type="dfn"}'s [y coordinate]{#ref-for-point-y-coordinate①③},
    [point 3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3⑤
    link-type="dfn"}'s [y coordinate]{#ref-for-point-y-coordinate①④} and
    [point 4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4⑤
    link-type="dfn"}'s [y coordinate]{#ref-for-point-y-coordinate①⑤}.

4.  Let `right`{.variable} be the [NaN-safe
    maximum](#nan-safe-maximum){#ref-for-nan-safe-maximum②
    link-type="dfn"} of [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1⑥
    link-type="dfn"}'s [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate①⑥
    link-type="dfn"}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2⑥
    link-type="dfn"}'s [x coordinate]{#ref-for-point-x-coordinate①⑦},
    [point 3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3⑥
    link-type="dfn"}'s [x coordinate]{#ref-for-point-x-coordinate①⑧} and
    [point 4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4⑥
    link-type="dfn"}'s [x coordinate]{#ref-for-point-x-coordinate①⑨}.

5.  Let `bottom`{.variable} be the [NaN-safe
    maximum](#nan-safe-maximum){#ref-for-nan-safe-maximum③
    link-type="dfn"} of [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1⑦
    link-type="dfn"}'s [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate①⑥
    link-type="dfn"}, [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2⑦
    link-type="dfn"}'s [y coordinate]{#ref-for-point-y-coordinate①⑦},
    [point 3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3⑦
    link-type="dfn"}'s [y coordinate]{#ref-for-point-y-coordinate①⑧} and
    [point 4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4⑦
    link-type="dfn"}'s [y coordinate]{#ref-for-point-y-coordinate①⑨}.

6.  Set [x
    coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate⑨
    link-type="dfn"} of `bounds`{.variable} to `left`{.variable}, [y
    coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate⑨
    link-type="dfn"} of `bounds`{.variable} to `top`{.variable}, [width
    dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension⑧
    link-type="dfn"} of `bounds`{.variable} to `right`{.variable} -
    `left`{.variable} and [height
    dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension⑧
    link-type="dfn"} of `bounds`{.variable} to `bottom`{.variable} -
    `top`{.variable}.

7.  Return `bounds`{.variable}.

::: {#example-9bbe24bd .example}
[](#example-9bbe24bd){.self-link} In this example the
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad①① link-type="idl"}
constructor is called with arguments of type
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint②⑨ link-type="idl"} and
[`DOMPointInit`{.idl}](#dictdef-dompointinit){#ref-for-dictdef-dompointinit①⓪
link-type="idl"}. Both arguments are accepted and can be used.

``` highlight
var point = new DOMPoint(2, 0);
var quad1 = new DOMQuad(point, {x: 12, y: 0}, {x: 12, y: 10}, {x: 2, y: 10});
```

The attribute values of the resulting
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad①② link-type="idl"}
`quad1`{.variable} above are also equivalent to the attribute values of
the following [`DOMQuad`{.idl}](#domquad){#ref-for-domquad①③
link-type="idl"} `quad2`{.variable}:

``` highlight
var rect = new DOMRect(2, 0, 10, 10);
var quad2 = DOMQuad.fromRect(rect);
```
:::

::: {#example-b13b531b .example}
[](#example-b13b531b){.self-link} This is an example of an irregular
quadrilateral:

``` highlight
new DOMQuad({x: 40, y: 25}, {x: 180, y: 8}, {x: 210, y: 150}, {x: 10, y: 180});
```

![An irregular quadrilateral represented by a
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad①④ link-type="idl"}. The
four red colored circles represent the
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint③⓪ link-type="idl"}
attributes [`p1`{.idl}](#dom-domquad-p1){#ref-for-dom-domquad-p1①
link-type="idl"} to
[`p4`{.idl}](#dom-domquad-p4){#ref-for-dom-domquad-p4① link-type="idl"}.
The dashed rectangle represents the bounding rectangle returned by the
[`getBounds()`{.idl}](#dom-domquad-getbounds){#ref-for-dom-domquad-getbounds①
link-type="idl"} method of the
[`DOMQuad`{.idl}](#domquad){#ref-for-domquad①⑤
link-type="idl"}.](data:image/svg+xml;base64,PHN2ZyBhcmlhLWxhYmVsPSJBbiBpcnJlZ3VsYXIgcXVhZHJpbGF0ZXJhbCB3aXRoIG5vbmUgb2YgdGhlCiAgICBzaWRlcyBiZWluZyB2ZXJ0aWNhbCBvciBob3Jpem9udGFsLiBJdHMgZm91ciBjb3JuZXJzIGFyZSBtYXJrZWQgd2l0aCByZWQgY2lyY2xlcy4gQXJvdW5kIHRoaXMKICAgIHF1YWRyaWxhdGVyYWwgaXMgYSBkYXNoZWQgcmVjdGFuZ2xlLiBBbGwgc2lkZXMgb2YgdGhpcyByZWN0YW5nbGUgYXJlIHZlcnRpY2FsIG9yIGhvcml6b250YWwgYW5kCiAgICB0YW5nZW50IHRoZSBxdWFkcmlsYXRlcmFsLiIgaGVpZ2h0PSIyMDAiIHJvbGU9ImltZyIgd2lkdGg9IjIzMCI+CiAgICAgIDxwb2x5Z29uIGZpbGw9InJnYig1MSwgMTUzLCAyMDQpIiBwb2ludHM9IjQwIDI1LCAxODAgOCwgMjEwIDE1MCwgMTAgMTgwIj48L3BvbHlnb24+CiAgICAgIDxyZWN0IGZpbGw9Im5vbmUiIGhlaWdodD0iMTcyIiBzdHJva2U9ImJsYWNrIiBzdHJva2UtZGFzaGFycmF5PSIzIDIiIHdpZHRoPSIyMDAiIHg9IjEwIiB5PSI4IiAvPgogICAgICA8Y2lyY2xlIGN4PSI0MCIgY3k9IjI1IiBmaWxsPSJyZ2IoMjA0LCA1MSwgNTEpIiByPSIzIj48L2NpcmNsZT4KICAgICAgPGNpcmNsZSBjeD0iMTgwIiBjeT0iOCIgZmlsbD0icmdiKDIwNCwgNTEsIDUxKSIgcj0iMyI+PC9jaXJjbGU+CiAgICAgIDxjaXJjbGUgY3g9IjIxMCIgY3k9IjE1MCIgZmlsbD0icmdiKDIwNCwgNTEsIDUxKSIgcj0iMyI+PC9jaXJjbGU+CiAgICAgIDxjaXJjbGUgY3g9IjEwIiBjeT0iMTgwIiBmaWxsPSJyZ2IoMjA0LCA1MSwgNTEpIiByPSIzIj48L2NpcmNsZT4KICAgICA8L3N2Zz4=)
:::

## [6. ]{.secno}[The DOMMatrix interfaces]{.content}[](#DOMMatrix){.self-link} {#DOMMatrix .heading .settled level="6"}

The [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix① link-type="idl"}
and
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly
link-type="idl"} interfaces each represent a mathematical
[matrix]{#matrix .dfn .caniuse-paneled .dfn-paneled dfn-type="dfn"
noexport=""} with the purpose of describing transformations in a
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
data-dfn-type="dfn" data-noexport="">4x4 abstract matrix</dfn> with
items <var>m</var><sub><var>11</var></sub> to
<var>m</var><sub><var>44</var></sub>.</figcaption>
</figure>

In the following sections, terms have the following meaning:

[post-multiply]{#post-multiply .dfn .dfn-paneled dfn-type="dfn" export=""}

:   Term `A`{.variable} post-multiplied by term `B`{.variable} is equal
    to `A`{.variable} · `B`{.variable}.

[pre-multiply]{#pre-multiply .dfn .dfn-paneled dfn-type="dfn" export=""}

:   Term `A`{.variable} pre-multiplied by term `B`{.variable} is equal
    to `B`{.variable} · `A`{.variable}.

[multiply]{#multiply .dfn .dfn-paneled dfn-type="dfn" export=""}

:   Multiply term `A`{.variable} by term `B`{.variable} is equal to
    `A`{.variable} · `B`{.variable}.

``` {.def .highlight .idl}
[Exposed=(Window,Worker),
 Serializable]
interface DOMMatrixReadOnly {
    constructor(optional (DOMString or sequence<unrestricted double>) init);

    [NewObject] static DOMMatrixReadOnly fromMatrix(optional DOMMatrixInit other = {});
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
    [NewObject] DOMMatrix multiply(optional DOMMatrixInit other = {});
    [NewObject] DOMMatrix flipX();
    [NewObject] DOMMatrix flipY();
    [NewObject] DOMMatrix inverse();

    [NewObject] DOMPoint transformPoint(optional DOMPointInit point = {});
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

    [NewObject] static DOMMatrix fromMatrix(optional DOMMatrixInit other = {});
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
    DOMMatrix multiplySelf(optional DOMMatrixInit other = {});
    DOMMatrix preMultiplySelf(optional DOMMatrixInit other = {});
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
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly⑤
link-type="idl"} objects have the internal member variables [m11
element]{#matrix-m11-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""}, [m12 element]{#matrix-m12-element .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""}, [m13
element]{#matrix-m13-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""}, [m14 element]{#matrix-m14-element .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""}, [m21
element]{#matrix-m21-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" lt="m21 element" noexport=""}, [m22
element]{#matrix-m22-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""}, [m23 element]{#matrix-m23-element .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""}, [m24
element]{#matrix-m24-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""}, [m31 element]{#matrix-m31-element .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""}, [m32
element]{#matrix-m32-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" lt="m32 element" noexport=""}, [m33
element]{#matrix-m33-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""}, [m34 element]{#matrix-m34-element .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""}, [m41
element]{#matrix-m41-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""}, [m42 element]{#matrix-m42-element .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""}, [m43
element]{#matrix-m43-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" lt="m43 element" noexport=""}, [m44
element]{#matrix-m44-element .dfn .dfn-paneled dfn-for="matrix"
dfn-type="dfn" noexport=""} and [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d① link-type="dfn"}.
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly⑥
link-type="idl"} as well as the inheriting interface
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③⓪ link-type="idl"}
must be able to access and set the value of these variables.

An interface returning an
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly⑦
link-type="idl"} object by an attribute or function may be able to
modify internal member variable values. Such an interface must specify
this ability explicitly in prose.

Internal member variables must not be exposed in any way.

The [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③①
link-type="idl"} and
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly⑧
link-type="idl"} interfaces replace the `SVGMatrix` interface from SVG.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"){link-type="biblio"}

### [6.1. ]{.secno}[DOMMatrix2DInit and DOMMatrixInit dictionaries]{.content}[](#dommatrixinit-dictionary){.self-link} {#dommatrixinit-dictionary .heading .settled level="6.1"}

To [validate and fixup (2D)]{#matrix-validate-and-fixup-2d .dfn
.dfn-paneled dfn-for="matrix" dfn-type="dfn" noexport=""} a
[`DOMMatrix2DInit`{.idl}](#dictdef-dommatrix2dinit){#ref-for-dictdef-dommatrix2dinit①
link-type="idl"} or
[`DOMMatrixInit`{.idl}](#dictdef-dommatrixinit){#ref-for-dictdef-dommatrixinit⑥
link-type="idl"} dictionary `dict`{.variable}, run the following steps:

1.  If if at least one of the following conditions are true for
    `dict`{.variable}, then throw a
    [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror
    link-type="idl"} exception and abort these steps.

    - [`a`{.idl}](#dom-dommatrix2dinit-a){#ref-for-dom-dommatrix2dinit-a
      link-type="idl"} and
      [`m11`{.idl}](#dom-dommatrix2dinit-m11){#ref-for-dom-dommatrix2dinit-m11
      link-type="idl"} are both present and
      [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero
      link-type="dfn"}([`a`{.idl}](#dom-dommatrix2dinit-a){#ref-for-dom-dommatrix2dinit-a①
      link-type="idl"},
      [`m11`{.idl}](#dom-dommatrix2dinit-m11){#ref-for-dom-dommatrix2dinit-m11①
      link-type="idl"}) is `false`.

    - [`b`{.idl}](#dom-dommatrix2dinit-b){#ref-for-dom-dommatrix2dinit-b
      link-type="idl"} and
      [`m12`{.idl}](#dom-dommatrix2dinit-m12){#ref-for-dom-dommatrix2dinit-m12
      link-type="idl"} are both present and
      [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero①
      link-type="dfn"}([`b`{.idl}](#dom-dommatrix2dinit-b){#ref-for-dom-dommatrix2dinit-b①
      link-type="idl"},
      [`m12`{.idl}](#dom-dommatrix2dinit-m12){#ref-for-dom-dommatrix2dinit-m12①
      link-type="idl"}) is `false`.

    - [`c`{.idl}](#dom-dommatrix2dinit-c){#ref-for-dom-dommatrix2dinit-c
      link-type="idl"} and
      [`m21`{.idl}](#dom-dommatrix2dinit-m21){#ref-for-dom-dommatrix2dinit-m21
      link-type="idl"} are both present and
      [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero②
      link-type="dfn"}([`c`{.idl}](#dom-dommatrix2dinit-c){#ref-for-dom-dommatrix2dinit-c①
      link-type="idl"},
      [`m21`{.idl}](#dom-dommatrix2dinit-m21){#ref-for-dom-dommatrix2dinit-m21①
      link-type="idl"}) is `false`.

    - [`d`{.idl}](#dom-dommatrix2dinit-d){#ref-for-dom-dommatrix2dinit-d
      link-type="idl"} and
      [`m22`{.idl}](#dom-dommatrix2dinit-m22){#ref-for-dom-dommatrix2dinit-m22
      link-type="idl"} are both present and
      [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero③
      link-type="dfn"}([`d`{.idl}](#dom-dommatrix2dinit-d){#ref-for-dom-dommatrix2dinit-d①
      link-type="idl"},
      [`m22`{.idl}](#dom-dommatrix2dinit-m22){#ref-for-dom-dommatrix2dinit-m22①
      link-type="idl"}) is `false`.

    - [`e`{.idl}](#dom-dommatrix2dinit-e){#ref-for-dom-dommatrix2dinit-e
      link-type="idl"} and
      [`m41`{.idl}](#dom-dommatrix2dinit-m41){#ref-for-dom-dommatrix2dinit-m41
      link-type="idl"} are both present and
      [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero④
      link-type="dfn"}([`e`{.idl}](#dom-dommatrix2dinit-e){#ref-for-dom-dommatrix2dinit-e①
      link-type="idl"},
      [`m41`{.idl}](#dom-dommatrix2dinit-m41){#ref-for-dom-dommatrix2dinit-m41①
      link-type="idl"}) is `false`.

    - [`f`{.idl}](#dom-dommatrix2dinit-f){#ref-for-dom-dommatrix2dinit-f
      link-type="idl"} and
      [`m42`{.idl}](#dom-dommatrix2dinit-m42){#ref-for-dom-dommatrix2dinit-m42
      link-type="idl"} are both present and
      [SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero⑤
      link-type="dfn"}([`f`{.idl}](#dom-dommatrix2dinit-f){#ref-for-dom-dommatrix2dinit-f①
      link-type="idl"},
      [`m42`{.idl}](#dom-dommatrix2dinit-m42){#ref-for-dom-dommatrix2dinit-m42①
      link-type="idl"}) is `false`.

2.  If
    [`m11`{.idl}](#dom-dommatrix2dinit-m11){#ref-for-dom-dommatrix2dinit-m11②
    link-type="idl"} is not present then set it to the value of member
    [`a`{.idl}](#dom-dommatrix2dinit-a){#ref-for-dom-dommatrix2dinit-a②
    link-type="idl"}, or value [1]{.css} if
    [`a`{.idl}](#dom-dommatrix2dinit-a){#ref-for-dom-dommatrix2dinit-a③
    link-type="idl"} is also not present.

3.  If
    [`m12`{.idl}](#dom-dommatrix2dinit-m12){#ref-for-dom-dommatrix2dinit-m12②
    link-type="idl"} is not present then set it to the value of member
    [`b`{.idl}](#dom-dommatrix2dinit-b){#ref-for-dom-dommatrix2dinit-b②
    link-type="idl"}, or value [0]{.css} if
    [`b`{.idl}](#dom-dommatrix2dinit-b){#ref-for-dom-dommatrix2dinit-b③
    link-type="idl"} is also not present.

4.  If
    [`m21`{.idl}](#dom-dommatrix2dinit-m21){#ref-for-dom-dommatrix2dinit-m21②
    link-type="idl"} is not present then set it to the value of member
    [`c`{.idl}](#dom-dommatrix2dinit-c){#ref-for-dom-dommatrix2dinit-c②
    link-type="idl"}, or value [0]{.css} if
    [`c`{.idl}](#dom-dommatrix2dinit-c){#ref-for-dom-dommatrix2dinit-c③
    link-type="idl"} is also not present.

5.  If
    [`m22`{.idl}](#dom-dommatrix2dinit-m22){#ref-for-dom-dommatrix2dinit-m22②
    link-type="idl"} is not present then set it to the value of member
    [`d`{.idl}](#dom-dommatrix2dinit-d){#ref-for-dom-dommatrix2dinit-d②
    link-type="idl"}, or value [1]{.css} if
    [`d`{.idl}](#dom-dommatrix2dinit-d){#ref-for-dom-dommatrix2dinit-d③
    link-type="idl"} is also not present.

6.  If
    [`m41`{.idl}](#dom-dommatrix2dinit-m41){#ref-for-dom-dommatrix2dinit-m41②
    link-type="idl"} is not present then set it to the value of member
    [`e`{.idl}](#dom-dommatrix2dinit-e){#ref-for-dom-dommatrix2dinit-e②
    link-type="idl"}, or value [0]{.css} if
    [`e`{.idl}](#dom-dommatrix2dinit-e){#ref-for-dom-dommatrix2dinit-e③
    link-type="idl"} is also not present.

7.  If
    [`m42`{.idl}](#dom-dommatrix2dinit-m42){#ref-for-dom-dommatrix2dinit-m42②
    link-type="idl"} is not present then set it to the value of member
    [`f`{.idl}](#dom-dommatrix2dinit-f){#ref-for-dom-dommatrix2dinit-f②
    link-type="idl"}, or value [0]{.css} if
    [`f`{.idl}](#dom-dommatrix2dinit-f){#ref-for-dom-dommatrix2dinit-f③
    link-type="idl"} is also not present.

[Note:]{.marker} The
[SameValueZero](https://tc39.github.io/ecma262/#sec-samevaluezero){#ref-for-sec-samevaluezero⑥
link-type="dfn"} comparison algorithm returns `true` for two
[NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan){#ref-for-valdef-calc-nan
.css link-type="maybe"} values, and also for [0]{.css} and [-0]{.css}.
[\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification"){link-type="biblio"}

To [validate and fixup]{#matrix-validate-and-fixup .dfn .dfn-paneled
dfn-for="matrix" dfn-type="dfn" noexport=""} a
[`DOMMatrixInit`{.idl}](#dictdef-dommatrixinit){#ref-for-dictdef-dommatrixinit⑦
link-type="idl"} dictionary `dict`{.variable}, run the following steps:

1.  [Validate and fixup
    (2D)](#matrix-validate-and-fixup-2d){#ref-for-matrix-validate-and-fixup-2d
    link-type="dfn"} `dict`{.variable}.

2.  If
    [`is2D`{.idl}](#dom-dommatrixinit-is2d){#ref-for-dom-dommatrixinit-is2d
    link-type="idl"} is `true` and: at least one of
    [`m13`{.idl}](#dom-dommatrixinit-m13){#ref-for-dom-dommatrixinit-m13
    link-type="idl"},
    [`m14`{.idl}](#dom-dommatrixinit-m14){#ref-for-dom-dommatrixinit-m14
    link-type="idl"},
    [`m23`{.idl}](#dom-dommatrixinit-m23){#ref-for-dom-dommatrixinit-m23
    link-type="idl"},
    [`m24`{.idl}](#dom-dommatrixinit-m24){#ref-for-dom-dommatrixinit-m24
    link-type="idl"},
    [`m31`{.idl}](#dom-dommatrixinit-m31){#ref-for-dom-dommatrixinit-m31
    link-type="idl"},
    [`m32`{.idl}](#dom-dommatrixinit-m32){#ref-for-dom-dommatrixinit-m32
    link-type="idl"},
    [`m34`{.idl}](#dom-dommatrixinit-m34){#ref-for-dom-dommatrixinit-m34
    link-type="idl"},
    [`m43`{.idl}](#dom-dommatrixinit-m43){#ref-for-dom-dommatrixinit-m43
    link-type="idl"} are present with a value other than [0]{.css} or
    [-0]{.css}, or at least one of
    [`m33`{.idl}](#dom-dommatrixinit-m33){#ref-for-dom-dommatrixinit-m33
    link-type="idl"},
    [`m44`{.idl}](#dom-dommatrixinit-m44){#ref-for-dom-dommatrixinit-m44
    link-type="idl"} are present with a value other than [1]{.css}, then
    throw a
    [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror①
    link-type="idl"} exception and abort these steps.

3.  If
    [`is2D`{.idl}](#dom-dommatrixinit-is2d){#ref-for-dom-dommatrixinit-is2d①
    link-type="idl"} is not present and at least one of
    [`m13`{.idl}](#dom-dommatrixinit-m13){#ref-for-dom-dommatrixinit-m13①
    link-type="idl"},
    [`m14`{.idl}](#dom-dommatrixinit-m14){#ref-for-dom-dommatrixinit-m14①
    link-type="idl"},
    [`m23`{.idl}](#dom-dommatrixinit-m23){#ref-for-dom-dommatrixinit-m23①
    link-type="idl"},
    [`m24`{.idl}](#dom-dommatrixinit-m24){#ref-for-dom-dommatrixinit-m24①
    link-type="idl"},
    [`m31`{.idl}](#dom-dommatrixinit-m31){#ref-for-dom-dommatrixinit-m31①
    link-type="idl"},
    [`m32`{.idl}](#dom-dommatrixinit-m32){#ref-for-dom-dommatrixinit-m32①
    link-type="idl"},
    [`m34`{.idl}](#dom-dommatrixinit-m34){#ref-for-dom-dommatrixinit-m34①
    link-type="idl"},
    [`m43`{.idl}](#dom-dommatrixinit-m43){#ref-for-dom-dommatrixinit-m43①
    link-type="idl"} are present with a value other than [0]{.css} or
    [-0]{.css}, or at least one of
    [`m33`{.idl}](#dom-dommatrixinit-m33){#ref-for-dom-dommatrixinit-m33①
    link-type="idl"},
    [`m44`{.idl}](#dom-dommatrixinit-m44){#ref-for-dom-dommatrixinit-m44①
    link-type="idl"} are present with a value other than [1]{.css}, set
    [`is2D`{.idl}](#dom-dommatrixinit-is2d){#ref-for-dom-dommatrixinit-is2d②
    link-type="idl"} to `false`.

4.  If
    [`is2D`{.idl}](#dom-dommatrixinit-is2d){#ref-for-dom-dommatrixinit-is2d③
    link-type="idl"} is still not present, set it to `true`.

### [6.2. ]{.secno}[Parsing a string into an abstract matrix]{.content}[](#dommatrix-parse){.self-link} {#dommatrix-parse .algorithm .heading .settled algorithm="Parsing a string into an abstract matrix" level="6.2"}

To [parse a string into an abstract
matrix]{#parse-a-string-into-an-abstract-matrix .dfn .dfn-paneled
dfn-type="dfn" noexport=""}, given a string `transformList`{.variable},
means to run the following steps. It will either return a [4x4 abstract
matrix](#4x4-abstract-matrix){#ref-for-4x4-abstract-matrix
link-type="dfn"} and a boolean `2dTransform`{.variable}, or failure.

1.  If `transformList`{.variable} is the empty string, set it to the
    string \"`matrix(1, 0, 0, 1, 0, 0)`\".

2.  [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar){#ref-for-css-parse-something-according-to-a-css-grammar
    link-type="dfn"} `transformList`{.variable} into
    `parsedValue`{.variable} given the grammar for the CSS
    [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform){#ref-for-propdef-transform
    .css .property link-type="property"} property. The result will be a
    [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list){#ref-for-typedef-transform-list
    .css .production link-type="type"}, the keyword [none]{.css}, or
    failure. If `parsedValue`{.variable} is failure, or any
    [\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function){#ref-for-typedef-transform-function
    .css .production link-type="type"} has
    [\<length\>](https://drafts.csswg.org/css-values-4/#length-value){#ref-for-length-value
    .css .production link-type="type"} values without [absolute
    length](https://drafts.csswg.org/css-values-4/#absolute-length){#ref-for-absolute-length
    link-type="dfn"} units, or any keyword other than [none]{.css} is
    used, then return failure.
    [\[CSS3-SYNTAX\]](#biblio-css3-syntax "CSS Syntax Module Level 3"){link-type="biblio"}
    [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

3.  If `parsedValue`{.variable} is [none]{.css}, set
    `parsedValue`{.variable} to a
    [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list){#ref-for-typedef-transform-list①
    .css .production link-type="type"} containing a single identity
    matrix.

4.  Let `2dTransform`{.variable} track the 2D/3D dimension status of
    `parsedValue`{.variable}.

    If `parsedValue`{.variable} consists of any [three-dimensional transform functions](https://drafts.csswg.org/css-transforms-1/#transform-primitives)

    :   Set `2dTransform`{.variable} to `false`.

    Otherwise

    :   Set `2dTransform`{.variable} to `true`.

5.  Transform all
    [\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function){#ref-for-typedef-transform-function①
    .css .production link-type="type"}s to [4x4 abstract
    matrices](#4x4-abstract-matrix){#ref-for-4x4-abstract-matrix①
    link-type="dfn"} by following the "[Mathematical Description of
    Transform
    Functions](https://drafts.csswg.org/css-transforms-1/#mathematical-description)".
    [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

6.  Let `matrix`{.variable} be a [4x4 abstract
    matrix](#4x4-abstract-matrix){#ref-for-4x4-abstract-matrix②
    link-type="dfn"} as shown in the initial figure of this section.
    [Post-multiply](#post-multiply){#ref-for-post-multiply
    link-type="dfn"} all matrices from left to right and set
    `matrix`{.variable} to this product.

7.  Return `matrix`{.variable} and `2dTransform`{.variable}.

### [6.3. ]{.secno}[Creating DOMMatrixReadOnly and DOMMatrix objects]{.content}[](#dommatrix-create){.self-link} {#dommatrix-create .heading .settled level="6.3"}

To [create a 2d matrix]{#create-a-2d-matrix .dfn .dfn-paneled
dfn-type="dfn" noexport=""} of type `type`{.variable} being either
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly⑨
link-type="idl"} or [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③②
link-type="idl"}, with a sequence `init`{.variable} of 6 elements,
follow these steps:

1.  Let `matrix`{.variable} be a new instance of `type`{.variable}.

2.  Set [m11 element](#matrix-m11-element){#ref-for-matrix-m11-element
    link-type="dfn"}, [m12
    element](#matrix-m12-element){#ref-for-matrix-m12-element
    link-type="dfn"}, [m21
    element](#matrix-m21-element){#ref-for-matrix-m21-element
    link-type="dfn"}, [m22
    element](#matrix-m22-element){#ref-for-matrix-m22-element
    link-type="dfn"}, [m41
    element](#matrix-m41-element){#ref-for-matrix-m41-element
    link-type="dfn"} and [m42
    element](#matrix-m42-element){#ref-for-matrix-m42-element
    link-type="dfn"} to the values of `init`{.variable} in order
    starting with the first value.

3.  Set [m13 element](#matrix-m13-element){#ref-for-matrix-m13-element
    link-type="dfn"}, [m14
    element](#matrix-m14-element){#ref-for-matrix-m14-element
    link-type="dfn"}, [m23
    element](#matrix-m23-element){#ref-for-matrix-m23-element
    link-type="dfn"}, [m24
    element](#matrix-m24-element){#ref-for-matrix-m24-element
    link-type="dfn"}, [m31
    element](#matrix-m31-element){#ref-for-matrix-m31-element
    link-type="dfn"}, [m32
    element](#matrix-m32-element){#ref-for-matrix-m32-element
    link-type="dfn"}, [m34
    element](#matrix-m34-element){#ref-for-matrix-m34-element
    link-type="dfn"}, and [m43
    element](#matrix-m43-element){#ref-for-matrix-m43-element
    link-type="dfn"} to [0]{.css}.

4.  Set [m33 element](#matrix-m33-element){#ref-for-matrix-m33-element
    link-type="dfn"} and [m44
    element](#matrix-m44-element){#ref-for-matrix-m44-element
    link-type="dfn"} to [1]{.css}.

5.  Set [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d② link-type="dfn"}
    to `true`.

6.  Return `matrix`{.variable}

To [create a 3d matrix]{#create-a-3d-matrix .dfn .dfn-paneled
dfn-type="dfn" noexport=""} with `type`{.variable} being either
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①⓪
link-type="idl"} or [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③③
link-type="idl"}, with a sequence `init`{.variable} of 16 elements,
follow these steps:

1.  Let `matrix`{.variable} be a new instance of `type`{.variable}.

2.  Set [m11 element](#matrix-m11-element){#ref-for-matrix-m11-element①
    link-type="dfn"} to [m44
    element](#matrix-m44-element){#ref-for-matrix-m44-element①
    link-type="dfn"} to the values of `init`{.variable} in column-major
    order.

3.  Set [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d③ link-type="dfn"}
    to `false`.

4.  Return `matrix`{.variable}

The
[`DOMMatrixReadOnly(``init`{.variable}`)`]{#dom-dommatrixreadonly-dommatrixreadonly
.dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly"
dfn-type="constructor" export=""
lt="DOMMatrixReadOnly(init)|constructor(init)|DOMMatrixReadOnly()|constructor()"}
and the [`DOMMatrix(``init`{.variable}`)`]{#dom-dommatrix-dommatrix .dfn
.dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="constructor"
export=""
lt="DOMMatrix(init)|constructor(init)|DOMMatrix()|constructor()"}
constructors must follow these steps:

If `init`{.variable} is omitted

:   Return the result of invoking [create a 2d
    matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①①
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③④
    link-type="idl"} as appropriate, with the sequence \[[1]{.css},
    [0]{.css}, [0]{.css}, [1]{.css}, [0]{.css}, [0]{.css}\].

If `init`{.variable} is a [`DOMString`{.idl}](https://webidl.spec.whatwg.org/#idl-DOMString){#ref-for-idl-DOMString③ link-type="idl"}

:   1.  If [current global
        object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object){#ref-for-current-global-object
        link-type="dfn"} is not a
        [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window
        link-type="idl"} object, then throw a
        [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror②
        link-type="idl"} exception.

    2.  [Parse `init`{.variable} into an abstract
        matrix](#parse-a-string-into-an-abstract-matrix){#ref-for-parse-a-string-into-an-abstract-matrix
        link-type="dfn"}, and let `matrix`{.variable} and
        `2dTransform`{.variable} be the result. If the result is
        failure, then throw a
        \"[`SyntaxError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-syntaxerror){#ref-for-sec-native-error-types-used-in-this-standard-syntaxerror
        link-type="idl"}\"
        [`DOMException`{.idl}](https://webidl.spec.whatwg.org/#idl-DOMException){#ref-for-idl-DOMException
        link-type="idl"}.

    3.  

        If `2dTransform`{.variable} is `true`

        :   Return the result of invoking [create a 2d
            matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix①
            link-type="dfn"} of type
            [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①②
            link-type="idl"} or
            [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③⑤
            link-type="idl"} as appropriate, with a sequence of numbers,
            the values being the elements `m11`{.variable},
            `m12`{.variable}, `m21`{.variable}, `m22`{.variable},
            `m41`{.variable} and `m42`{.variable} of
            `matrix`{.variable}.

        Otherwise

        :   Return the result of invoking [create a 3d
            matrix](#create-a-3d-matrix){#ref-for-create-a-3d-matrix
            link-type="dfn"} of type
            [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①③
            link-type="idl"} or
            [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③⑥
            link-type="idl"} as appropriate, with a sequence of numbers,
            the values being the 16 elements of `matrix`{.variable}.

If `init`{.variable} is a sequence with 6 elements

:   Return the result of invoking [create a 2d
    matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix②
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①④
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③⑦
    link-type="idl"} as appropriate, with the sequence
    `init`{.variable}.

If `init`{.variable} is a sequence with 16 elements

:   Return the result of invoking [create a 3d
    matrix](#create-a-3d-matrix){#ref-for-create-a-3d-matrix①
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①⑤
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③⑧
    link-type="idl"} as appropriate, with the sequence
    `init`{.variable}.

Otherwise

:   Throw a
    [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror③
    link-type="idl"} exception.

The
[`fromMatrix(``other`{.variable}`)`]{#dom-dommatrixreadonly-frommatrix
.dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly"
dfn-type="method" export="" lt="fromMatrix(other)|fromMatrix()"} static
method on
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①⑥
link-type="idl"} must [create a `DOMMatrixReadOnly` from the
dictionary](#create-a-dommatrixreadonly-from-the-dictionary){#ref-for-create-a-dommatrixreadonly-from-the-dictionary
link-type="dfn"} `other`{.variable}.

The [`fromMatrix(``other`{.variable}`)`]{#dom-dommatrix-frommatrix .dfn
.dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export=""
lt="fromMatrix(other)|fromMatrix()"} static method on
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix③⑨ link-type="idl"}
must [create a `DOMMatrix` from the
dictionary](#create-a-dommatrix-from-the-dictionary){#ref-for-create-a-dommatrix-from-the-dictionary①
link-type="dfn"} `other`{.variable}.

To [create a `DOMMatrixReadOnly` from a 2D
dictionary]{#create-a-dommatrixreadonly-from-the-2d-dictionary .dfn
.dfn-paneled dfn-type="dfn" export=""
lt="create a DOMMatrixReadOnly from the 2D dictionary"}
`other`{.variable} or to [create a `DOMMatrix` from a 2D
dictionary]{#create-a-dommatrix-from-the-2d-dictionary .dfn .dfn-paneled
dfn-type="dfn" export="" lt="create a
DOMMatrix from the 2D dictionary"} `other`{.variable}, follow these
steps:

1.  [Validate and fixup
    (2D)](#matrix-validate-and-fixup-2d){#ref-for-matrix-validate-and-fixup-2d①
    link-type="dfn"} `other`{.variable}.

2.  Return the result of invoking [create a 2d
    matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix③
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①⑦
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④⓪
    link-type="idl"} as appropriate, with a sequence of numbers, the
    values being the 6 elements
    [`m11`{.idl}](#dom-dommatrix2dinit-m11){#ref-for-dom-dommatrix2dinit-m11③
    link-type="idl"},
    [`m12`{.idl}](#dom-dommatrix2dinit-m12){#ref-for-dom-dommatrix2dinit-m12③
    link-type="idl"},
    [`m21`{.idl}](#dom-dommatrix2dinit-m21){#ref-for-dom-dommatrix2dinit-m21③
    link-type="idl"},
    [`m22`{.idl}](#dom-dommatrix2dinit-m22){#ref-for-dom-dommatrix2dinit-m22③
    link-type="idl"},
    [`m41`{.idl}](#dom-dommatrix2dinit-m41){#ref-for-dom-dommatrix2dinit-m41③
    link-type="idl"} and
    [`m42`{.idl}](#dom-dommatrix2dinit-m42){#ref-for-dom-dommatrix2dinit-m42③
    link-type="idl"} of `other`{.variable} in the given order.

To [create a `DOMMatrixReadOnly` from a
dictionary]{#create-a-dommatrixreadonly-from-the-dictionary .dfn
.dfn-paneled dfn-type="dfn" export=""
lt="create a DOMMatrixReadOnly from the dictionary"} `other`{.variable}
or to [create a `DOMMatrix` from a
dictionary]{#create-a-dommatrix-from-the-dictionary .dfn .dfn-paneled
dfn-type="dfn" lt="create a
DOMMatrix from the dictionary" noexport=""} `other`{.variable}, follow
these steps:

1.  [Validate and
    fixup](#matrix-validate-and-fixup){#ref-for-matrix-validate-and-fixup
    link-type="dfn"} `other`{.variable}.

2.  

    If the [`is2D`{.idl}](#dom-dommatrixinit-is2d){#ref-for-dom-dommatrixinit-is2d④ link-type="idl"} dictionary member of `other`{.variable} is `true`

    :   Return the result of invoking [create a 2d
        matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix④
        link-type="dfn"} of type
        [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①⑧
        link-type="idl"} or
        [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④①
        link-type="idl"} as appropriate, with a sequence of numbers, the
        values being the 6 elements
        [`m11`{.idl}](#dom-dommatrix2dinit-m11){#ref-for-dom-dommatrix2dinit-m11④
        link-type="idl"},
        [`m12`{.idl}](#dom-dommatrix2dinit-m12){#ref-for-dom-dommatrix2dinit-m12④
        link-type="idl"},
        [`m21`{.idl}](#dom-dommatrix2dinit-m21){#ref-for-dom-dommatrix2dinit-m21④
        link-type="idl"},
        [`m22`{.idl}](#dom-dommatrix2dinit-m22){#ref-for-dom-dommatrix2dinit-m22④
        link-type="idl"},
        [`m41`{.idl}](#dom-dommatrix2dinit-m41){#ref-for-dom-dommatrix2dinit-m41④
        link-type="idl"} and
        [`m42`{.idl}](#dom-dommatrix2dinit-m42){#ref-for-dom-dommatrix2dinit-m42④
        link-type="idl"} of `other`{.variable} in the given order.

    Otherwise

    :   Return the result of invoking [create a 3d
        matrix](#create-a-3d-matrix){#ref-for-create-a-3d-matrix②
        link-type="dfn"} of type
        [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly①⑨
        link-type="idl"} or
        [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④②
        link-type="idl"} as appropriate, with a sequence of numbers, the
        values being the 16 elements
        [`m11`{.idl}](#dom-dommatrix2dinit-m11){#ref-for-dom-dommatrix2dinit-m11⑤
        link-type="idl"},
        [`m12`{.idl}](#dom-dommatrix2dinit-m12){#ref-for-dom-dommatrix2dinit-m12⑤
        link-type="idl"},
        [`m13`{.idl}](#dom-dommatrixinit-m13){#ref-for-dom-dommatrixinit-m13②
        link-type="idl"}, \...,
        [`m44`{.idl}](#dom-dommatrixinit-m44){#ref-for-dom-dommatrixinit-m44②
        link-type="idl"} of `other`{.variable} in the given order.

The
[`fromFloat32Array(``array32`{.variable}`)`]{#dom-dommatrixreadonly-fromfloat32array
.dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly"
dfn-type="method" export=""} static method on
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②⓪
link-type="idl"} and the
[`fromFloat32Array(``array32`{.variable}`)`]{#dom-dommatrix-fromfloat32array
.dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method"
export=""} static method on
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④③ link-type="idl"}
must follow these steps:

If `array32`{.variable} has 6 elements

:   Return the result of invoking [create a 2d
    matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix⑤
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②①
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④④
    link-type="idl"} as appropriate, with a sequence of numbers taking
    the values from `array32`{.variable} in the provided order.

If `array32`{.variable} has 16 elements

:   Return the result of invoking [create a 3d
    matrix](#create-a-3d-matrix){#ref-for-create-a-3d-matrix③
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②②
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④⑤
    link-type="idl"} as appropriate, with a sequence of numbers taking
    the values from `array32`{.variable} in the provided order.

Otherwise

:   Throw a
    [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror④
    link-type="idl"} exception.

The
[`fromFloat64Array(``array64`{.variable}`)`]{#dom-dommatrixreadonly-fromfloat64array
.dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly"
dfn-type="method" export=""} static method on
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②③
link-type="idl"} and the
[`fromFloat64Array(``array64`{.variable}`)`]{#dom-dommatrix-fromfloat64array
.dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method"
export=""} static method on
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④⑥ link-type="idl"}
must follow these steps:

If `array64`{.variable} has 6 elements

:   Return the result of invoking [create a 2d
    matrix](#create-a-2d-matrix){#ref-for-create-a-2d-matrix⑥
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②④
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④⑦
    link-type="idl"} as appropriate, with a sequence of numbers taking
    the values from `array64`{.variable} in the provided order.

If `array32`{.variable} has 16 elements

:   Return the result of invoking [create a 3d
    matrix](#create-a-3d-matrix){#ref-for-create-a-3d-matrix④
    link-type="dfn"} of type
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②⑤
    link-type="idl"} or
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④⑧
    link-type="idl"} as appropriate, with a sequence of numbers taking
    the values from `array64`{.variable} in the provided order.

Otherwise

:   Throw a
    [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror⑤
    link-type="idl"} exception.

### [6.4. ]{.secno}[DOMMatrix attributes]{.content}[](#dommatrix-attributes){.self-link} {#dommatrix-attributes .heading .settled level="6.4"}

The following attributes
[`m11`{.idl}](#dom-dommatrixreadonly-m11){#ref-for-dom-dommatrixreadonly-m11②
link-type="idl"} to
[`m44`{.idl}](#dom-dommatrixreadonly-m44){#ref-for-dom-dommatrixreadonly-m44②
link-type="idl"} correspond to the 16 items of the matrix interfaces.

::: {}
The [`m11`]{#dom-dommatrixreadonly-m11 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
and [`a`]{#dom-dommatrixreadonly-a .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attributes, on getting, must return the [m11
element](#matrix-m11-element){#ref-for-matrix-m11-element②
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix④⑨ link-type="idl"}
interface, setting the
[`m11`{.idl}](#dom-dommatrixreadonly-m11){#ref-for-dom-dommatrixreadonly-m11③
link-type="idl"} or the
[`a`{.idl}](#dom-dommatrixreadonly-a){#ref-for-dom-dommatrixreadonly-a②
link-type="idl"} attribute must set the [m11
element]{#ref-for-matrix-m11-element③} to the new value.

The [`m12`]{#dom-dommatrixreadonly-m12 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
and [`b`]{#dom-dommatrixreadonly-b .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attributes, on getting, must return the [m12
element](#matrix-m12-element){#ref-for-matrix-m12-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤⓪ link-type="idl"}
interface, setting the
[`m12`{.idl}](#dom-dommatrixreadonly-m12){#ref-for-dom-dommatrixreadonly-m12②
link-type="idl"} or the
[`b`{.idl}](#dom-dommatrixreadonly-b){#ref-for-dom-dommatrixreadonly-b②
link-type="idl"} attribute must set the [m12
element]{#ref-for-matrix-m12-element②} to the new value.

The [`m13`]{#dom-dommatrixreadonly-m13 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m13
element](#matrix-m13-element){#ref-for-matrix-m13-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤① link-type="idl"}
interface, setting the
[`m13`{.idl}](#dom-dommatrixreadonly-m13){#ref-for-dom-dommatrixreadonly-m13②
link-type="idl"} attribute must set the [m13
element]{#ref-for-matrix-m13-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d④ link-type="dfn"} to `false`.

The [`m14`]{#dom-dommatrixreadonly-m14 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m14
element](#matrix-m14-element){#ref-for-matrix-m14-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤② link-type="idl"}
interface, setting the
[`m14`{.idl}](#dom-dommatrixreadonly-m14){#ref-for-dom-dommatrixreadonly-m14②
link-type="idl"} attribute must set the [m14
element]{#ref-for-matrix-m14-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d⑤ link-type="dfn"} to `false`.

The [`m21`]{#dom-dommatrixreadonly-m21 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
and [`c`]{#dom-dommatrixreadonly-c .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attributes, on getting, must return the [m21
element](#matrix-m21-element){#ref-for-matrix-m21-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤③ link-type="idl"}
interface, setting the
[`m21`{.idl}](#dom-dommatrixreadonly-m21){#ref-for-dom-dommatrixreadonly-m21②
link-type="idl"} or the
[`c`{.idl}](#dom-dommatrixreadonly-c){#ref-for-dom-dommatrixreadonly-c②
link-type="idl"} attribute must set the [m21
element]{#ref-for-matrix-m21-element②} to the new value.

The [`m22`]{#dom-dommatrixreadonly-m22 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
and [`d`]{#dom-dommatrixreadonly-d .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attributes, on getting, must return the [m22
element](#matrix-m22-element){#ref-for-matrix-m22-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤④ link-type="idl"}
interface, setting the
[`m22`{.idl}](#dom-dommatrixreadonly-m22){#ref-for-dom-dommatrixreadonly-m22②
link-type="idl"} or the
[`d`{.idl}](#dom-dommatrixreadonly-d){#ref-for-dom-dommatrixreadonly-d②
link-type="idl"} attribute must set the [m22
element]{#ref-for-matrix-m22-element②} to the new value.

The [`m23`]{#dom-dommatrixreadonly-m23 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m23
element](#matrix-m23-element){#ref-for-matrix-m23-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤⑤ link-type="idl"}
interface, setting the
[`m23`{.idl}](#dom-dommatrixreadonly-m23){#ref-for-dom-dommatrixreadonly-m23②
link-type="idl"} attribute must set the [m23
element]{#ref-for-matrix-m23-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d⑥ link-type="dfn"} to `false`.

The [`m24`]{#dom-dommatrixreadonly-m24 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m24
element](#matrix-m24-element){#ref-for-matrix-m24-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤⑥ link-type="idl"}
interface, setting the
[`m24`{.idl}](#dom-dommatrixreadonly-m24){#ref-for-dom-dommatrixreadonly-m24②
link-type="idl"} attribute must set the [m24
element]{#ref-for-matrix-m24-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d⑦ link-type="dfn"} to `false`.

The [`m31`]{#dom-dommatrixreadonly-m31 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m31
element](#matrix-m31-element){#ref-for-matrix-m31-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤⑦ link-type="idl"}
interface, setting the
[`m31`{.idl}](#dom-dommatrixreadonly-m31){#ref-for-dom-dommatrixreadonly-m31②
link-type="idl"} attribute must set the [m31
element]{#ref-for-matrix-m31-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d⑧ link-type="dfn"} to `false`.

The [`m32`]{#dom-dommatrixreadonly-m32 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m32
element](#matrix-m32-element){#ref-for-matrix-m32-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤⑧ link-type="idl"}
interface, setting the
[`m32`{.idl}](#dom-dommatrixreadonly-m32){#ref-for-dom-dommatrixreadonly-m32②
link-type="idl"} attribute must set the [m32
element]{#ref-for-matrix-m32-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d⑨ link-type="dfn"} to `false`.

The [`m33`]{#dom-dommatrixreadonly-m33 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m33
element](#matrix-m33-element){#ref-for-matrix-m33-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑤⑨ link-type="idl"}
interface, setting the
[`m33`{.idl}](#dom-dommatrixreadonly-m33){#ref-for-dom-dommatrixreadonly-m33②
link-type="idl"} attribute must set the [m33
element]{#ref-for-matrix-m33-element②} to the new value and, if the new
value is not [1]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d①⓪ link-type="dfn"} to `false`.

The [`m34`]{#dom-dommatrixreadonly-m34 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m34
element](#matrix-m34-element){#ref-for-matrix-m34-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥⓪ link-type="idl"}
interface, setting the
[`m34`{.idl}](#dom-dommatrixreadonly-m34){#ref-for-dom-dommatrixreadonly-m34②
link-type="idl"} attribute must set the [m34
element]{#ref-for-matrix-m34-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d①① link-type="dfn"} to `false`.

The [`m41`]{#dom-dommatrixreadonly-m41 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
and [`e`]{#dom-dommatrixreadonly-e .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attributes, on getting, must return the [m41
element](#matrix-m41-element){#ref-for-matrix-m41-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥① link-type="idl"}
interface, setting the
[`m41`{.idl}](#dom-dommatrixreadonly-m41){#ref-for-dom-dommatrixreadonly-m41②
link-type="idl"} or the
[`e`{.idl}](#dom-dommatrixreadonly-e){#ref-for-dom-dommatrixreadonly-e②
link-type="idl"} attribute must set the [m41
element]{#ref-for-matrix-m41-element②} to the new value.

The [`m42`]{#dom-dommatrixreadonly-m42 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
and [`f`]{#dom-dommatrixreadonly-f .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attributes, on getting, must return the [m42
element](#matrix-m42-element){#ref-for-matrix-m42-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥② link-type="idl"}
interface, setting the
[`m42`{.idl}](#dom-dommatrixreadonly-m42){#ref-for-dom-dommatrixreadonly-m42②
link-type="idl"} or the
[`f`{.idl}](#dom-dommatrixreadonly-f){#ref-for-dom-dommatrixreadonly-f②
link-type="idl"} attribute must set the [m42
element]{#ref-for-matrix-m42-element②} to the new value.

The [`m43`]{#dom-dommatrixreadonly-m43 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m43
element](#matrix-m43-element){#ref-for-matrix-m43-element①
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥③ link-type="idl"}
interface, setting the
[`m43`{.idl}](#dom-dommatrixreadonly-m43){#ref-for-dom-dommatrixreadonly-m43②
link-type="idl"} attribute must set the [m43
element]{#ref-for-matrix-m43-element②} to the new value and, if the new
value is not [0]{.css} or [-0]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d①② link-type="dfn"} to `false`.

The [`m44`]{#dom-dommatrixreadonly-m44 .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly, DOMMatrix" dfn-type="attribute" export=""}
attribute, on getting, must return the [m44
element](#matrix-m44-element){#ref-for-matrix-m44-element②
link-type="dfn"} value. For the
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥④ link-type="idl"}
interface, setting the
[`m44`{.idl}](#dom-dommatrixreadonly-m44){#ref-for-dom-dommatrixreadonly-m44③
link-type="idl"} attribute must set the [m44
element]{#ref-for-matrix-m44-element③} to the new value and, if the new
value is not [1]{.css}, set [is
2D](#matrix-is-2d){#ref-for-matrix-is-2d①③ link-type="dfn"} to `false`.
:::

::: {.note role="note"}
The following attributes
[`a`{.idl}](#dom-dommatrixreadonly-a){#ref-for-dom-dommatrixreadonly-a③
link-type="idl"} to
[`f`{.idl}](#dom-dommatrixreadonly-f){#ref-for-dom-dommatrixreadonly-f③
link-type="idl"} correspond to the 2D components of the matrix
interfaces.

The
[`a`{.idl}](#dom-dommatrixreadonly-a){#ref-for-dom-dommatrixreadonly-a④
link-type="idl"} attribute is an alias to the
[`m11`{.idl}](#dom-dommatrixreadonly-m11){#ref-for-dom-dommatrixreadonly-m11④
link-type="idl"} attribute.

The
[`b`{.idl}](#dom-dommatrixreadonly-b){#ref-for-dom-dommatrixreadonly-b③
link-type="idl"} attribute is an alias to the
[`m12`{.idl}](#dom-dommatrixreadonly-m12){#ref-for-dom-dommatrixreadonly-m12③
link-type="idl"} attribute.

The
[`c`{.idl}](#dom-dommatrixreadonly-c){#ref-for-dom-dommatrixreadonly-c③
link-type="idl"} attribute is an alias to the
[`m21`{.idl}](#dom-dommatrixreadonly-m21){#ref-for-dom-dommatrixreadonly-m21③
link-type="idl"} attribute.

The
[`d`{.idl}](#dom-dommatrixreadonly-d){#ref-for-dom-dommatrixreadonly-d③
link-type="idl"} attribute is an alias to the
[`m22`{.idl}](#dom-dommatrixreadonly-m22){#ref-for-dom-dommatrixreadonly-m22③
link-type="idl"} attribute.

The
[`e`{.idl}](#dom-dommatrixreadonly-e){#ref-for-dom-dommatrixreadonly-e③
link-type="idl"} attribute is an alias to the
[`m41`{.idl}](#dom-dommatrixreadonly-m41){#ref-for-dom-dommatrixreadonly-m41③
link-type="idl"} attribute.

The
[`f`{.idl}](#dom-dommatrixreadonly-f){#ref-for-dom-dommatrixreadonly-f④
link-type="idl"} attribute is an alias to the
[`m42`{.idl}](#dom-dommatrixreadonly-m42){#ref-for-dom-dommatrixreadonly-m42③
link-type="idl"} attribute.
:::

The following attributes provide status information about
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②⑥
link-type="idl"}.

::: {}
The [`is2D`]{#dom-dommatrixreadonly-is2d .dfn .dfn-paneled .idl-code
dfn-for="DOMMatrixReadOnly" dfn-type="attribute" export=""} attribute
must return the value of [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d①④
link-type="dfn"}.

The [`isIdentity`]{#dom-dommatrixreadonly-isidentity .dfn .dfn-paneled
.idl-code dfn-for="DOMMatrixReadOnly" dfn-type="attribute" export=""}
attribute must return `true` if [m12
element](#matrix-m12-element){#ref-for-matrix-m12-element③
link-type="dfn"}, [m13
element](#matrix-m13-element){#ref-for-matrix-m13-element③
link-type="dfn"}, [m14
element](#matrix-m14-element){#ref-for-matrix-m14-element③
link-type="dfn"}, [m21
element](#matrix-m21-element){#ref-for-matrix-m21-element③
link-type="dfn"}, [m23
element](#matrix-m23-element){#ref-for-matrix-m23-element③
link-type="dfn"}, [m24
element](#matrix-m24-element){#ref-for-matrix-m24-element③
link-type="dfn"}, [m31
element](#matrix-m31-element){#ref-for-matrix-m31-element③
link-type="dfn"}, [m32
element](#matrix-m32-element){#ref-for-matrix-m32-element③
link-type="dfn"}, [m34
element](#matrix-m34-element){#ref-for-matrix-m34-element③
link-type="dfn"}, [m41
element](#matrix-m41-element){#ref-for-matrix-m41-element③
link-type="dfn"}, [m42
element](#matrix-m42-element){#ref-for-matrix-m42-element③
link-type="dfn"}, [m43
element](#matrix-m43-element){#ref-for-matrix-m43-element③
link-type="dfn"} are [0]{.css} or [-0]{.css} and [m11
element](#matrix-m11-element){#ref-for-matrix-m11-element④
link-type="dfn"}, [m22
element](#matrix-m22-element){#ref-for-matrix-m22-element③
link-type="dfn"}, [m33
element](#matrix-m33-element){#ref-for-matrix-m33-element③
link-type="dfn"}, [m44
element](#matrix-m44-element){#ref-for-matrix-m44-element④
link-type="dfn"} are [1]{.css}. Otherwise it must return `false`.
:::

Every
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②⑦
link-type="idl"} object must be flagged with a boolean [is
2D]{#matrix-is-2d .dfn .dfn-paneled dfn-for="matrix" dfn-type="dfn"
export=""}. This flag indicates that:

1.  The current matrix was initialized as a 2D matrix. See individual
    [creators](#dommatrix-create) for more details.

2.  Only 2D transformation operations were applied. Each
    [mutable](#mutable-transformation-methods) or [immutable
    transformation method](#immutable-transformation-methods) defines if
    [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d①⑤ link-type="dfn"} must
    be set to `false`.

[Note:]{.marker} [Is 2D](#matrix-is-2d){#ref-for-matrix-is-2d①⑥
link-type="dfn"} can never be set to `true` when it was set to `false`
before on a [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥⑤
link-type="idl"} object with the exception of calling the
[`setMatrixValue()`{.idl}](#dom-dommatrix-setmatrixvalue){#ref-for-dom-dommatrix-setmatrixvalue①
link-type="idl"} method.

### [6.5. ]{.secno}[Immutable transformation methods]{.content}[](#immutable-transformation-methods){.self-link} {#immutable-transformation-methods .heading .settled level="6.5"}

The following methods do not modify the current matrix and return a new
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥⑥ link-type="idl"}
object.

[`translate(``tx`{.variable}`, ``ty`{.variable}`, ``tz`{.variable}`)`]{#dom-dommatrixreadonly-translate .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="translate(tx, ty, tz)|translate(tx, ty)|translate(tx)|translate()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`translateSelf()`{.idl}](#dom-dommatrix-translateself){#ref-for-dom-dommatrix-translateself①
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `tx`{.variable}, `ty`{.variable}, `tz`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`scale(``scaleX`{.variable}`, ``scaleY`{.variable}`, ``scaleZ`{.variable}`, ``originX`{.variable}`, ``originY`{.variable}`, ``originZ`{.variable}`)`]{#dom-dommatrixreadonly-scale .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="scale(scaleX, scaleY, scaleZ, originX, originY, originZ)|scale(scaleX, scaleY, scaleZ, originX, originY)|scale(scaleX, scaleY, scaleZ, originX)|scale(scaleX, scaleY, scaleZ)|scale(scaleX, scaleY)|scale(scaleX)|scale()"}

:   1.  If `scaleY`{.variable} is missing, set `scaleY`{.variable} to
        the value of `scaleX`{.variable}.

    2.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    3.  Perform a
        [`scaleSelf()`{.idl}](#dom-dommatrix-scaleself){#ref-for-dom-dommatrix-scaleself①
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `scaleX`{.variable}, `scaleY`{.variable},
        `scaleZ`{.variable}, `originX`{.variable}, `originY`{.variable},
        `originZ`{.variable}.

    4.  Return `result`{.variable}.

    The current matrix is not modified.

[`scaleNonUniform(``scaleX`{.variable}`, ``scaleY`{.variable}`)`]{#dom-dommatrixreadonly-scalenonuniform .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="scaleNonUniform(scaleX, scaleY)|scaleNonUniform(scaleX)|scaleNonUniform()"}

:   [Note:]{.marker} Supported for legacy reasons to be compatible with
    [`SVGMatrix`{.idl}](#svgmatrix){#ref-for-svgmatrix① link-type="idl"}
    as defined in SVG 1.1
    [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"){link-type="biblio"}.
    Authors are encouraged to use
    [`scale()`{.idl}](#dom-dommatrixreadonly-scale){#ref-for-dom-dommatrixreadonly-scale①
    link-type="idl"} instead.

    1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`scaleSelf()`{.idl}](#dom-dommatrix-scaleself){#ref-for-dom-dommatrix-scaleself②
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `scaleX`{.variable}, `scaleY`{.variable}, *1*, *0*,
        *0*, *0*.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`scale3d(``scale`{.variable}`, ``originX`{.variable}`, ``originY`{.variable}`, ``originZ`{.variable}`)`]{#dom-dommatrixreadonly-scale3d .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="scale3d(scale, originX, originY, originZ)|scale3d(scale, originX, originY)|scale3d(scale, originX)|scale3d(scale)|scale3d()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`scale3dSelf()`{.idl}](#dom-dommatrix-scale3dself){#ref-for-dom-dommatrix-scale3dself①
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `scale`{.variable}, `originX`{.variable},
        `originY`{.variable}, `originZ`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`rotate(``rotX`{.variable}`, ``rotY`{.variable}`, ``rotZ`{.variable}`)`]{#dom-dommatrixreadonly-rotate .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="rotate(rotX, rotY, rotZ)|rotate(rotX, rotY)|rotate(rotX)|rotate()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`rotateSelf()`{.idl}](#dom-dommatrix-rotateself){#ref-for-dom-dommatrix-rotateself①
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `rotX`{.variable}, `rotY`{.variable},
        `rotZ`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`rotateFromVector(``x`{.variable}`, ``y`{.variable}`)`]{#dom-dommatrixreadonly-rotatefromvector .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="rotateFromVector(x, y)|rotateFromVector(x)|rotateFromVector()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`rotateFromVectorSelf()`{.idl}](#dom-dommatrix-rotatefromvectorself){#ref-for-dom-dommatrix-rotatefromvectorself①
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `x`{.variable}, `y`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`rotateAxisAngle(``x`{.variable}`, ``y`{.variable}`, ``z`{.variable}`, ``angle`{.variable}`)`]{#dom-dommatrixreadonly-rotateaxisangle .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="rotateAxisAngle(x, y, z, angle)|rotateAxisAngle(x, y, z)|rotateAxisAngle(x, y)|rotateAxisAngle(x)|rotateAxisAngle()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`rotateAxisAngleSelf()`{.idl}](#dom-dommatrix-rotateaxisangleself){#ref-for-dom-dommatrix-rotateaxisangleself①
        link-type="idl"} transformation on `result`{.variable} with the
        arguments `x`{.variable}, `y`{.variable}, `z`{.variable},
        `angle`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`skewX(``sx`{.variable}`)`]{#dom-dommatrixreadonly-skewx .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="skewX(sx)|skewX()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`skewXSelf()`{.idl}](#dom-dommatrix-skewxself){#ref-for-dom-dommatrix-skewxself①
        link-type="idl"} transformation on `result`{.variable} with the
        argument `sx`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`skewY(``sy`{.variable}`)`]{#dom-dommatrixreadonly-skewy .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="skewY(sy)|skewY()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`skewYSelf()`{.idl}](#dom-dommatrix-skewyself){#ref-for-dom-dommatrix-skewyself①
        link-type="idl"} transformation on `result`{.variable} with the
        argument `sy`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`multiply(``other`{.variable}`)`]{#dom-dommatrixreadonly-multiply .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="multiply(other)|multiply()"}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`multiplySelf()`{.idl}](#dom-dommatrix-multiplyself){#ref-for-dom-dommatrix-multiplyself①
        link-type="idl"} transformation on `result`{.variable} with the
        argument `other`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`flipX()`]{#dom-dommatrixreadonly-flipx .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export=""}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  [Post-multiply](#post-multiply){#ref-for-post-multiply①
        link-type="dfn"} `result`{.variable} with
        `new DOMMatrix([-1, 0, 0, 1, 0, 0])`.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`flipY()`]{#dom-dommatrixreadonly-flipy .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export=""}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  [Post-multiply](#post-multiply){#ref-for-post-multiply②
        link-type="dfn"} `result`{.variable} with
        `new DOMMatrix([1, 0, 0, -1, 0, 0])`.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

[`inverse()`]{#dom-dommatrixreadonly-inverse .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export=""}

:   1.  Let `result`{.variable} be the resulting matrix initialized to
        the values of the current matrix.

    2.  Perform a
        [`invertSelf()`{.idl}](#dom-dommatrix-invertself){#ref-for-dom-dommatrix-invertself①
        link-type="idl"} transformation on `result`{.variable}.

    3.  Return `result`{.variable}.

    The current matrix is not modified.

The following methods do not modify the current matrix.

[`transformPoint(``point`{.variable}`)`]{#dom-dommatrixreadonly-transformpoint .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export="" lt="transformPoint(point)|transformPoint()"}

:   Let `pointObject`{.variable} be the result of invoking [create a
    `DOMPoint` from the
    dictionary](#create-a-dompoint-from-the-dictionary){#ref-for-create-a-dompoint-from-the-dictionary⑤
    link-type="dfn"} `point`{.variable}. Return the result of invoking
    [transform a point with a
    matrix](#transform-a-point-with-a-matrix){#ref-for-transform-a-point-with-a-matrix①
    link-type="dfn"}, given `pointObject`{.variable} and the current
    matrix. The passed argument does not get modified.

[`toFloat32Array()`]{#dom-dommatrixreadonly-tofloat32array .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export=""}

:   Returns the serialized 16 elements
    [`m11`{.idl}](#dom-dommatrixreadonly-m11){#ref-for-dom-dommatrixreadonly-m11⑤
    link-type="idl"} to
    [`m44`{.idl}](#dom-dommatrixreadonly-m44){#ref-for-dom-dommatrixreadonly-m44④
    link-type="idl"} of the current matrix in column-major order as
    [`Float32Array`{.idl}](https://webidl.spec.whatwg.org/#idl-Float32Array){#ref-for-idl-Float32Array③
    link-type="idl"}.

[`toFloat64Array()`]{#dom-dommatrixreadonly-tofloat64array .dfn .dfn-paneled .idl-code dfn-for="DOMMatrixReadOnly" dfn-type="method" export=""}

:   Returns the serialized 16 elements
    [`m11`{.idl}](#dom-dommatrixreadonly-m11){#ref-for-dom-dommatrixreadonly-m11⑥
    link-type="idl"} to
    [`m44`{.idl}](#dom-dommatrixreadonly-m44){#ref-for-dom-dommatrixreadonly-m44⑤
    link-type="idl"} of the current matrix in column-major order as
    [`Float64Array`{.idl}](https://webidl.spec.whatwg.org/#idl-Float64Array){#ref-for-idl-Float64Array③
    link-type="idl"}.

[stringification behavior]{#dommatrixreadonly-stringification-behavior .dfn .dfn-paneled dfn-for="DOMMatrixReadOnly" dfn-type="dfn" lt="stringificationbehavior" noexport=""}

:   1.  If one or more of [m11
        element](#matrix-m11-element){#ref-for-matrix-m11-element⑤
        link-type="dfn"} through [m44
        element](#matrix-m44-element){#ref-for-matrix-m44-element⑤
        link-type="dfn"} are a non-finite value, then throw an
        \"[`InvalidStateError`{.idl}](https://webidl.spec.whatwg.org/#invalidstateerror){#ref-for-invalidstateerror
        link-type="idl"}\"
        [`DOMException`{.idl}](https://webidl.spec.whatwg.org/#idl-DOMException){#ref-for-idl-DOMException①
        link-type="idl"}.

        [Note:]{.marker} The CSS syntax cannot represent
        [NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan){#ref-for-valdef-calc-nan①
        .css link-type="maybe"} or
        [Infinity](https://drafts.csswg.org/css-values-4/#valdef-calc-infinity){#ref-for-valdef-calc-infinity
        .css link-type="maybe"} values.

    2.  Let `string`{.variable} be the empty string.

    3.  If [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d①⑦
        link-type="dfn"} is `true`, then:

        1.  Append \"`matrix(`\" to `string`{.variable}.

        2.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring
            link-type="dfn"}([m11
            element](#matrix-m11-element){#ref-for-matrix-m11-element⑥
            link-type="dfn"}) to `string`{.variable}.

        3.  Append \"`, `\" to `string`{.variable}.

        4.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①
            link-type="dfn"}([m12
            element](#matrix-m12-element){#ref-for-matrix-m12-element④
            link-type="dfn"}) to `string`{.variable}.

        5.  Append \"`, `\" to `string`{.variable}.

        6.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions②
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring②
            link-type="dfn"}([m21
            element](#matrix-m21-element){#ref-for-matrix-m21-element④
            link-type="dfn"}) to `string`{.variable}.

        7.  Append \"`, `\" to `string`{.variable}.

        8.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions③
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring③
            link-type="dfn"}([m22
            element](#matrix-m22-element){#ref-for-matrix-m22-element④
            link-type="dfn"}) to `string`{.variable}.

        9.  Append \"`, `\" to `string`{.variable}.

        10. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions④
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring④
            link-type="dfn"}([m41
            element](#matrix-m41-element){#ref-for-matrix-m41-element④
            link-type="dfn"}) to `string`{.variable}.

        11. Append \"`, `\" to `string`{.variable}.

        12. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions⑤
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring⑤
            link-type="dfn"}([m42
            element](#matrix-m42-element){#ref-for-matrix-m42-element④
            link-type="dfn"}) to `string`{.variable}.

        13. Append \"`)`\" to `string`{.variable}.

        [Note:]{.marker} The string will be in the form of a a CSS
        Transforms
        [\<matrix()\>](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-matrix){#ref-for-funcdef-transform-matrix
        .css .production link-type="function"} function.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    4.  Otherwise:

        1.  Append \"`matrix3d(`\" to `string`{.variable}.

        2.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions⑥
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring⑥
            link-type="dfn"}([m11
            element](#matrix-m11-element){#ref-for-matrix-m11-element⑦
            link-type="dfn"}) to `string`{.variable}.

        3.  Append \"`, `\" to `string`{.variable}.

        4.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions⑦
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring⑦
            link-type="dfn"}([m12
            element](#matrix-m12-element){#ref-for-matrix-m12-element⑤
            link-type="dfn"}) to `string`{.variable}.

        5.  Append \"`, `\" to `string`{.variable}.

        6.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions⑧
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring⑧
            link-type="dfn"}([m13
            element](#matrix-m13-element){#ref-for-matrix-m13-element④
            link-type="dfn"}) to `string`{.variable}.

        7.  Append \"`, `\" to `string`{.variable}.

        8.  Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions⑨
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring⑨
            link-type="dfn"}([m14
            element](#matrix-m14-element){#ref-for-matrix-m14-element④
            link-type="dfn"}) to `string`{.variable}.

        9.  Append \"`, `\" to `string`{.variable}.

        10. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①⓪
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①⓪
            link-type="dfn"}([m21
            element](#matrix-m21-element){#ref-for-matrix-m21-element⑤
            link-type="dfn"}) to `string`{.variable}.

        11. Append \"`, `\" to `string`{.variable}.

        12. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①①
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①①
            link-type="dfn"}([m22
            element](#matrix-m22-element){#ref-for-matrix-m22-element⑤
            link-type="dfn"}) to `string`{.variable}.

        13. Append \"`, `\" to `string`{.variable}.

        14. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①②
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①②
            link-type="dfn"}([m23
            element](#matrix-m23-element){#ref-for-matrix-m23-element④
            link-type="dfn"}) to `string`{.variable}.

        15. Append \"`, `\" to `string`{.variable}.

        16. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①③
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①③
            link-type="dfn"}([m24
            element](#matrix-m24-element){#ref-for-matrix-m24-element④
            link-type="dfn"}) to `string`{.variable}.

        17. Append \"`, `\" to `string`{.variable}.

        18. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①④
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①④
            link-type="dfn"}([m41
            element](#matrix-m41-element){#ref-for-matrix-m41-element⑤
            link-type="dfn"}) to `string`{.variable}.

        19. Append \"`, `\" to `string`{.variable}.

        20. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①⑤
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①⑤
            link-type="dfn"}([m42
            element](#matrix-m42-element){#ref-for-matrix-m42-element⑤
            link-type="dfn"}) to `string`{.variable}.

        21. Append \"`, `\" to `string`{.variable}.

        22. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①⑥
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①⑥
            link-type="dfn"}([m43
            element](#matrix-m43-element){#ref-for-matrix-m43-element④
            link-type="dfn"}) to `string`{.variable}.

        23. Append \"`, `\" to `string`{.variable}.

        24. Append
            [!](https://tc39.github.io/ecma262/#sec-algorithm-conventions){#ref-for-sec-algorithm-conventions①⑦
            link-type="dfn"}
            [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①⑦
            link-type="dfn"}([m44
            element](#matrix-m44-element){#ref-for-matrix-m44-element⑥
            link-type="dfn"}) to `string`{.variable}.

        25. Append \"`)`\" to `string`{.variable}.

        [Note:]{.marker} The string will be in the form of a a CSS
        Transforms
        [\<matrix3d()\>](https://drafts.csswg.org/css-transforms-2/#funcdef-matrix3d){#ref-for-funcdef-matrix3d
        .css .production link-type="function"} function.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    5.  Return `string`{.variable}.

::: {#example-c07c5bc8 .example}
[](#example-c07c5bc8){.self-link} In this example, a matrix is created
and several 2D transformation methods are called:

``` highlight
var matrix = new DOMMatrix();
matrix.scaleSelf(2);
matrix.translateSelf(20,20);
console.assert(matrix.toString() ===
                "matrix(2, 0, 0, 2, 40, 40)");
```
:::

::: {#example-92755fec .example}
[](#example-92755fec){.self-link} In the following example, a matrix is
created and several 3D transformation methods are called:

``` highlight
var matrix = new DOMMatrix();
matrix.scale3dSelf(2);
console.assert(matrix.toString() ===
                "matrix3d(2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1)");
```

For 3D operations, the stringifier returns a string representing a 3D
matrix.
:::

::: {#example-733d794b .example}
[](#example-733d794b){.self-link} This example will throw an exception
because there are non-finite values in the matrix.

``` highlight
var matrix = new DOMMatrix([NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN]);
var string = matrix + " Batman!";
```
:::

### [6.6. ]{.secno}[Mutable transformation methods]{.content}[](#mutable-transformation-methods){.self-link} {#mutable-transformation-methods .heading .settled level="6.6"}

The following methods modify the current matrix, so that each method
returns the matrix where it was invoked on. The primary benefit of this
is allowing content creators to chain method calls.

::: {#example-15e8ec9d .example}
[](#example-15e8ec9d){.self-link} The following code example:

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
:::

[Note:]{.marker} Authors who use chained method calls are advised to use
mutable transformation methods to avoid unnecessary memory allocations
due to creation of intermediate
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥⑦ link-type="idl"}
objects in user agents.

[`multiplySelf(``other`{.variable}`)`]{#dom-dommatrix-multiplyself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="multiplySelf(other)|multiplySelf()"}

:   1.  Let `otherObject`{.variable} be the result of invoking [create a
        `DOMMatrix` from the
        dictionary](#create-a-dommatrix-from-the-dictionary){#ref-for-create-a-dommatrix-from-the-dictionary②
        link-type="dfn"} `other`{.variable}.

    2.  The `otherObject`{.variable} matrix gets post-multiplied to the
        current matrix.

    3.  If [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d①⑧
        link-type="dfn"} of `otherObject`{.variable} is `false`, set [is
        2D]{#ref-for-matrix-is-2d①⑨} of the current matrix to `false`.

    4.  Return the current matrix.

[`preMultiplySelf(``other`{.variable}`)`]{#dom-dommatrix-premultiplyself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="preMultiplySelf(other)|preMultiplySelf()"}

:   1.  Let `otherObject`{.variable} be the result of invoking [create a
        `DOMMatrix` from the
        dictionary](#create-a-dommatrix-from-the-dictionary){#ref-for-create-a-dommatrix-from-the-dictionary③
        link-type="dfn"} `other`{.variable}.

    2.  The `otherObject`{.variable} matrix gets pre-multiplied to the
        current matrix.

    3.  If [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d②⓪
        link-type="dfn"} of `otherObject`{.variable} is `false`, set [is
        2D]{#ref-for-matrix-is-2d②①} of the current matrix to `false`.

    4.  Return the current matrix.

[`translateSelf(``tx`{.variable}`, ``ty`{.variable}`, ``tz`{.variable}`)`]{#dom-dommatrix-translateself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="translateSelf(tx, ty, tz)|translateSelf(tx, ty)|translateSelf(tx)|translateSelf()"}

:   1.  [Post-multiply](#post-multiply){#ref-for-post-multiply③
        link-type="dfn"} a translation transformation on the current
        matrix. The 3D translation matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#TranslateDefined)
        in CSS Transforms.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    2.  If `tz`{.variable} is specified and not [0]{.css} or [-0]{.css},
        set [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d②②
        link-type="dfn"} of the current matrix to `false`.

    3.  Return the current matrix.

[`scaleSelf(``scaleX`{.variable}`, ``scaleY`{.variable}`, ``scaleZ`{.variable}`, ``originX`{.variable}`, ``originY`{.variable}`, ``originZ`{.variable}`)`]{#dom-dommatrix-scaleself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="scaleSelf(scaleX, scaleY, scaleZ, originX, originY, originZ)|scaleSelf(scaleX, scaleY, scaleZ, originX, originY)|scaleSelf(scaleX, scaleY, scaleZ, originX)|scaleSelf(scaleX, scaleY, scaleZ)|scaleSelf(scaleX, scaleY)|scaleSelf(scaleX)|scaleSelf()"}

:   1.  Perform a
        [`translateSelf()`{.idl}](#dom-dommatrix-translateself){#ref-for-dom-dommatrix-translateself②
        link-type="idl"} transformation on the current matrix with the
        arguments `originX`{.variable}, `originY`{.variable},
        `originZ`{.variable}.

    2.  If `scaleY`{.variable} is missing, set `scaleY`{.variable} to
        the value of `scaleX`{.variable}.

    3.  [Post-multiply](#post-multiply){#ref-for-post-multiply④
        link-type="dfn"} a non-uniform scale transformation on the
        current matrix. The 3D scale matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#ScaleDefined)
        in CSS Transforms with `sx`{.variable} = `scaleX`{.variable},
        `sy`{.variable} = `scaleY`{.variable} and `sz`{.variable} =
        `scaleZ`{.variable}.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    4.  Negate `originX`{.variable}, `originY`{.variable} and
        `originZ`{.variable}.

    5.  Perform a
        [`translateSelf()`{.idl}](#dom-dommatrix-translateself){#ref-for-dom-dommatrix-translateself③
        link-type="idl"} transformation on the current matrix with the
        arguments `originX`{.variable}, `originY`{.variable},
        `originZ`{.variable}.

    6.  If `scaleZ`{.variable} is not [1]{.css}, set [is
        2D](#matrix-is-2d){#ref-for-matrix-is-2d②③ link-type="dfn"} of
        the current matrix to `false`.

    7.  Return the current matrix.

[`scale3dSelf(``scale`{.variable}`, ``originX`{.variable}`, ``originY`{.variable}`, ``originZ`{.variable}`)`]{#dom-dommatrix-scale3dself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="scale3dSelf(scale, originX, originY, originZ)|scale3dSelf(scale, originX, originY)|scale3dSelf(scale, originX)|scale3dSelf(scale)|scale3dSelf()"}

:   1.  Apply a
        [`translateSelf()`{.idl}](#dom-dommatrix-translateself){#ref-for-dom-dommatrix-translateself④
        link-type="idl"} transformation to the current matrix with the
        arguments `originX`{.variable}, `originY`{.variable},
        `originZ`{.variable}.

    2.  [Post-multiply](#post-multiply){#ref-for-post-multiply⑤
        link-type="dfn"} a uniform 3D scale transformation
        ([`m11`{.idl}](#dom-dommatrixreadonly-m11){#ref-for-dom-dommatrixreadonly-m11⑦
        link-type="idl"} =
        [`m22`{.idl}](#dom-dommatrixreadonly-m22){#ref-for-dom-dommatrixreadonly-m22④
        link-type="idl"} =
        [`m33`{.idl}](#dom-dommatrixreadonly-m33){#ref-for-dom-dommatrixreadonly-m33③
        link-type="idl"} = `scale`{.variable}) on the current matrix.
        The 3D scale matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#ScaleDefined)
        in CSS Transforms with `sx`{.variable} = `sy`{.variable} =
        `sz`{.variable} = `scale`{.variable}.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    3.  Apply a
        [`translateSelf()`{.idl}](#dom-dommatrix-translateself){#ref-for-dom-dommatrix-translateself⑤
        link-type="idl"} transformation to the current matrix with the
        arguments -`originX`{.variable}, -`originY`{.variable},
        -`originZ`{.variable}.

    4.  If `scale`{.variable} is not [1]{.css}, set [is
        2D](#matrix-is-2d){#ref-for-matrix-is-2d②④ link-type="dfn"} of
        the current matrix to `false`.

    5.  Return the current matrix.

[`rotateSelf(``rotX`{.variable}`, ``rotY`{.variable}`, ``rotZ`{.variable}`)`]{#dom-dommatrix-rotateself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="rotateSelf(rotX, rotY, rotZ)|rotateSelf(rotX, rotY)|rotateSelf(rotX)|rotateSelf()"}

:   1.  If `rotY`{.variable} and `rotZ`{.variable} are both missing, set
        `rotZ`{.variable} to the value of `rotX`{.variable} and set
        `rotX`{.variable} and `rotY`{.variable} to [0]{.css}.

    2.  If `rotY`{.variable} is still missing, set `rotY`{.variable} to
        [0]{.css}.

    3.  If `rotZ`{.variable} is still missing, set `rotZ`{.variable} to
        [0]{.css}.

    4.  If `rotX`{.variable} or `rotY`{.variable} are not [0]{.css} or
        [-0]{.css}, set [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d②⑤
        link-type="dfn"} of the current matrix to `false`.

    5.  [Post-multiply](#post-multiply){#ref-for-post-multiply⑥
        link-type="dfn"} a rotation transformation on the current matrix
        around the vector 0, 0, 1 by the specified rotation
        `rotZ`{.variable} in degrees. The 3D rotation matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
        in CSS Transforms with `alpha`{.variable} = `rotZ`{.variable} in
        degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    6.  [Post-multiply](#post-multiply){#ref-for-post-multiply⑦
        link-type="dfn"} a rotation transformation on the current matrix
        around the vector 0, 1, 0 by the specified rotation
        `rotY`{.variable} in degrees. The 3D rotation matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
        in CSS Transforms with `alpha`{.variable} = `rotY`{.variable} in
        degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    7.  [Post-multiply](#post-multiply){#ref-for-post-multiply⑧
        link-type="dfn"} a rotation transformation on the current matrix
        around the vector 1, 0, 0 by the specified rotation
        `rotX`{.variable} in degrees. The 3D rotation matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
        in CSS Transforms with `alpha`{.variable} = `rotX`{.variable} in
        degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    8.  Return the current matrix.

[`rotateFromVectorSelf(``x`{.variable}`, ``y`{.variable}`)`]{#dom-dommatrix-rotatefromvectorself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="rotateFromVectorSelf(x, y)|rotateFromVectorSelf(x)|rotateFromVectorSelf()"}

:   1.  [Post-multiply](#post-multiply){#ref-for-post-multiply⑨
        link-type="dfn"} a rotation transformation on the current
        matrix. The rotation angle is determined by the angle between
        the vector (1,0)^T^ and (`x`{.variable},`y`{.variable})^T^ in
        the clockwise direction. If `x`{.variable} and `y`{.variable}
        should both be [0]{.css} or [-0]{.css}, the angle is specified
        as [0]{.css}. The 2D rotation matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
        in CSS Transforms where `alpha` is the angle between the vector
        (1,0)^T^ and (`x`{.variable},`y`{.variable})^T^ in degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    2.  Return the current matrix.

[`rotateAxisAngleSelf(``x`{.variable}`, ``y`{.variable}`, ``z`{.variable}`, ``angle`{.variable}`)`]{#dom-dommatrix-rotateaxisangleself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="rotateAxisAngleSelf(x, y, z, angle)|rotateAxisAngleSelf(x, y, z)|rotateAxisAngleSelf(x, y)|rotateAxisAngleSelf(x)|rotateAxisAngleSelf()"}

:   1.  [Post-multiply](#post-multiply){#ref-for-post-multiply①⓪
        link-type="dfn"} a rotation transformation on the current matrix
        around the specified vector `x`{.variable}, `y`{.variable},
        `z`{.variable} by the specified rotation `angle`{.variable} in
        degrees. The 3D rotation matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#RotateDefined)
        in CSS Transforms with `alpha`{.variable} = `angle`{.variable}
        in degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    2.  If `x`{.variable} or `y`{.variable} are not [0]{.css} or
        [-0]{.css}, set [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d②⑥
        link-type="dfn"} of the current matrix to `false`.

    3.  Return the current matrix.

[`skewXSelf(``sx`{.variable}`)`]{#dom-dommatrix-skewxself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="skewXSelf(sx)|skewXSelf()"}

:   1.  [Post-multiply](#post-multiply){#ref-for-post-multiply①①
        link-type="dfn"} a skewX transformation on the current matrix by
        the specified angle `sx`{.variable} in degrees. The 2D skewX
        matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#SkewXDefined)
        in CSS Transforms with `alpha`{.variable} = `sx`{.variable} in
        degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    2.  Return the current matrix.

[`skewYSelf(``sy`{.variable}`)`]{#dom-dommatrix-skewyself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export="" lt="skewYSelf(sy)|skewYSelf()"}

:   1.  [Post-multiply](#post-multiply){#ref-for-post-multiply①②
        link-type="dfn"} a skewX transformation on the current matrix by
        the specified angle `sy`{.variable} in degrees. The 2D skewY
        matrix is
        [described](https://drafts.csswg.org/css-transforms-1/#SkewYDefined)
        in CSS Transforms with `beta`{.variable} = `sy`{.variable} in
        degrees.
        [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"){link-type="biblio"}

    2.  Return the current matrix.

[`invertSelf()`]{#dom-dommatrix-invertself .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export=""}

:   1.  Invert the current matrix.

    2.  If the current matrix is not invertible set all attributes to
        [NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan){#ref-for-valdef-calc-nan②
        .css link-type="maybe"} and set [is
        2D](#matrix-is-2d){#ref-for-matrix-is-2d②⑦ link-type="dfn"} to
        `false`.

    3.  Return the current matrix.

[`setMatrixValue(``transformList`{.variable}`)`]{#dom-dommatrix-setmatrixvalue .dfn .dfn-paneled .idl-code dfn-for="DOMMatrix" dfn-type="method" export=""}

:   1.  [Parse `transformList`{.variable} into an abstract
        matrix](#parse-a-string-into-an-abstract-matrix){#ref-for-parse-a-string-into-an-abstract-matrix①
        link-type="dfn"}, and let `matrix`{.variable} and
        `2dTransform`{.variable} be the result. If the result is
        failure, then throw a
        \"[`SyntaxError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-syntaxerror){#ref-for-sec-native-error-types-used-in-this-standard-syntaxerror①
        link-type="idl"}\"
        [`DOMException`{.idl}](https://webidl.spec.whatwg.org/#idl-DOMException){#ref-for-idl-DOMException②
        link-type="idl"}.

    2.  Set [is 2D](#matrix-is-2d){#ref-for-matrix-is-2d②⑧
        link-type="dfn"} to the value of `2dTransform`{.variable}.

    3.  Set [m11
        element](#matrix-m11-element){#ref-for-matrix-m11-element⑧
        link-type="dfn"} through [m44
        element](#matrix-m44-element){#ref-for-matrix-m44-element⑦
        link-type="dfn"} to the element values of `matrix`{.variable} in
        column-major order.

    4.  Return the current matrix.

## [7. ]{.secno}[]{#cloning .bs-old-id}[Structured serialization]{.content}[](#structured-serialization){.self-link} {#structured-serialization .heading .settled level="7"}

[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly⑨
link-type="idl"}, [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint③②
link-type="idl"},
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly⑨
link-type="idl"}, [`DOMRect`{.idl}](#domrect){#ref-for-domrect①⑤
link-type="idl"}, [`DOMQuad`{.idl}](#domquad){#ref-for-domquad①⑥
link-type="idl"},
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②⑧
link-type="idl"}, and
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥⑧ link-type="idl"}
objects are [serializable
objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects){#ref-for-serializable-objects
link-type="dfn"}.
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps){#ref-for-serialization-steps
link-type="dfn"} for
[`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly①⓪
link-type="idl"} and [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint③③
link-type="idl"}, given `value`{.variable} and `serialized`{.variable},
are:

1.  Set `serialized`{.variable}.\[\[X\]\] to `value`{.variable}'s [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate②⓪
    link-type="dfn"}.

2.  Set `serialized`{.variable}.\[\[Y\]\] to `value`{.variable}'s [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate②⓪
    link-type="dfn"}.

3.  Set `serialized`{.variable}.\[\[Z\]\] to `value`{.variable}'s [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate①①
    link-type="dfn"}.

4.  Set `serialized`{.variable}.\[\[W\]\] to `value`{.variable}'s [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective①①
    link-type="dfn"}.

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps){#ref-for-deserialization-steps
link-type="dfn"}, given `serialized`{.variable} and `value`{.variable},
are:

1.  Set `value`{.variable}'s [x
    coordinate](#point-x-coordinate){#ref-for-point-x-coordinate②①
    link-type="dfn"} to `serialized`{.variable}.\[\[X\]\].

2.  Set `value`{.variable}'s [y
    coordinate](#point-y-coordinate){#ref-for-point-y-coordinate②①
    link-type="dfn"} to `serialized`{.variable}.\[\[Y\]\].

3.  Set `value`{.variable}'s [z
    coordinate](#point-z-coordinate){#ref-for-point-z-coordinate①②
    link-type="dfn"} to `serialized`{.variable}.\[\[Z\]\].

4.  Set `value`{.variable}'s [w
    perspective](#point-w-perspective){#ref-for-point-w-perspective①②
    link-type="dfn"} to `serialized`{.variable}.\[\[W\]\].

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps){#ref-for-serialization-steps①
link-type="dfn"} for
[`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly①⓪
link-type="idl"} and [`DOMRect`{.idl}](#domrect){#ref-for-domrect①⑥
link-type="idl"}, given `value`{.variable} and `serialized`{.variable},
are:

1.  Set `serialized`{.variable}.\[\[X\]\] to `value`{.variable}'s [x
    coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate①⓪
    link-type="dfn"}.

2.  Set `serialized`{.variable}.\[\[Y\]\] to `value`{.variable}'s [y
    coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate①⓪
    link-type="dfn"}.

3.  Set `serialized`{.variable}.\[\[Width\]\] to `value`{.variable}'s
    [width
    dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension⑨
    link-type="dfn"}.

4.  Set `serialized`{.variable}.\[\[Height\]\] to `value`{.variable}'s
    [height
    dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension⑨
    link-type="dfn"}.

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps){#ref-for-deserialization-steps①
link-type="dfn"}, given `serialized`{.variable} and `value`{.variable},
are:

1.  Set `value`{.variable}'s [x
    coordinate](#rectangle-x-coordinate){#ref-for-rectangle-x-coordinate①①
    link-type="dfn"} to `serialized`{.variable}.\[\[X\]\].

2.  Set `value`{.variable}'s [y
    coordinate](#rectangle-y-coordinate){#ref-for-rectangle-y-coordinate①①
    link-type="dfn"} to `serialized`{.variable}.\[\[Y\]\].

3.  Set `value`{.variable}'s [width
    dimension](#rectangle-width-dimension){#ref-for-rectangle-width-dimension①⓪
    link-type="dfn"} to `serialized`{.variable}.\[\[Width\]\].

4.  Set `value`{.variable}'s [height
    dimension](#rectangle-height-dimension){#ref-for-rectangle-height-dimension①⓪
    link-type="dfn"} to `serialized`{.variable}.\[\[Height\]\].

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps){#ref-for-serialization-steps②
link-type="dfn"} for [`DOMQuad`{.idl}](#domquad){#ref-for-domquad①⑦
link-type="idl"}, given `value`{.variable} and `serialized`{.variable},
are:

1.  Set `serialized`{.variable}.\[\[P1\]\] to the
    [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization){#ref-for-sub-serialization
    link-type="dfn"} of `value`{.variable}'s [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1⑧
    link-type="dfn"}.

2.  Set `serialized`{.variable}.\[\[P2\]\] to the
    [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization){#ref-for-sub-serialization①
    link-type="dfn"} of `value`{.variable}'s [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2⑧
    link-type="dfn"}.

3.  Set `serialized`{.variable}.\[\[P3\]\] to the
    [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization){#ref-for-sub-serialization②
    link-type="dfn"} of `value`{.variable}'s [point
    3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3⑧
    link-type="dfn"}.

4.  Set `serialized`{.variable}.\[\[P4\]\] to the
    [sub-serialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-serialization){#ref-for-sub-serialization③
    link-type="dfn"} of `value`{.variable}'s [point
    4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4⑧
    link-type="dfn"}.

Their [deserialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps){#ref-for-deserialization-steps②
link-type="dfn"}, given `serialized`{.variable} and `value`{.variable},
are:

1.  Set `value`{.variable}'s [point
    1](#quadrilateral-point-1){#ref-for-quadrilateral-point-1⑨
    link-type="dfn"} to the
    [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization){#ref-for-sub-deserialization
    link-type="dfn"} of `serialized`{.variable}.\[\[P1\]\].

2.  Set `value`{.variable}'s [point
    2](#quadrilateral-point-2){#ref-for-quadrilateral-point-2⑨
    link-type="dfn"} to the
    [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization){#ref-for-sub-deserialization①
    link-type="dfn"} of `serialized`{.variable}.\[\[P2\]\].

3.  Set `value`{.variable}'s [point
    3](#quadrilateral-point-3){#ref-for-quadrilateral-point-3⑨
    link-type="dfn"} to the
    [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization){#ref-for-sub-deserialization②
    link-type="dfn"} of `serialized`{.variable}.\[\[P3\]\].

4.  Set `value`{.variable}'s [point
    4](#quadrilateral-point-4){#ref-for-quadrilateral-point-4⑨
    link-type="dfn"} to the
    [sub-deserialization](https://html.spec.whatwg.org/multipage/structured-data.html#sub-deserialization){#ref-for-sub-deserialization③
    link-type="dfn"} of `serialized`{.variable}.\[\[P4\]\].

The [serialization
steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps){#ref-for-serialization-steps③
link-type="dfn"} for
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly②⑨
link-type="idl"} and
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑥⑨ link-type="idl"},
given `value`{.variable} and `serialized`{.variable}, are:

1.  If `value`{.variable}'s [is
    2D](#matrix-is-2d){#ref-for-matrix-is-2d②⑨ link-type="dfn"} is
    `true`:

    1.  Set `serialized`{.variable}.\[\[M11\]\] to `value`{.variable}'s
        [m11 element](#matrix-m11-element){#ref-for-matrix-m11-element⑨
        link-type="dfn"}.

    2.  Set `serialized`{.variable}.\[\[M12\]\] to `value`{.variable}'s
        [m12 element](#matrix-m12-element){#ref-for-matrix-m12-element⑥
        link-type="dfn"}.

    3.  Set `serialized`{.variable}.\[\[M21\]\] to `value`{.variable}'s
        [m21 element](#matrix-m21-element){#ref-for-matrix-m21-element⑥
        link-type="dfn"}.

    4.  Set `serialized`{.variable}.\[\[M22\]\] to `value`{.variable}'s
        [m22 element](#matrix-m22-element){#ref-for-matrix-m22-element⑥
        link-type="dfn"}.

    5.  Set `serialized`{.variable}.\[\[M41\]\] to `value`{.variable}'s
        [m41 element](#matrix-m41-element){#ref-for-matrix-m41-element⑥
        link-type="dfn"}.

    6.  Set `serialized`{.variable}.\[\[M42\]\] to `value`{.variable}'s
        [m42 element](#matrix-m42-element){#ref-for-matrix-m42-element⑥
        link-type="dfn"}.

    7.  Set `serialized`{.variable}.\[\[Is2D\]\] to `true`.

    [Note:]{.marker} It is possible for a 2D
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦⓪
    link-type="idl"} or
    [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③⓪
    link-type="idl"} to have [-0]{.css} for some of the other elements,
    e.g., the [m13
    element](#matrix-m13-element){#ref-for-matrix-m13-element⑤
    link-type="dfn"}, which will not be roundtripped by this algorithm.

2.  Otherwise:

    1.  Set `serialized`{.variable}.\[\[M11\]\] to `value`{.variable}'s
        [m11 element](#matrix-m11-element){#ref-for-matrix-m11-element①⓪
        link-type="dfn"}.

    2.  Set `serialized`{.variable}.\[\[M12\]\] to `value`{.variable}'s
        [m12 element](#matrix-m12-element){#ref-for-matrix-m12-element⑦
        link-type="dfn"}.

    3.  Set `serialized`{.variable}.\[\[M13\]\] to `value`{.variable}'s
        [m13 element](#matrix-m13-element){#ref-for-matrix-m13-element⑥
        link-type="dfn"}.

    4.  Set `serialized`{.variable}.\[\[M14\]\] to `value`{.variable}'s
        [m14 element](#matrix-m14-element){#ref-for-matrix-m14-element⑤
        link-type="dfn"}.

    5.  Set `serialized`{.variable}.\[\[M21\]\] to `value`{.variable}'s
        [m21 element](#matrix-m21-element){#ref-for-matrix-m21-element⑦
        link-type="dfn"}.

    6.  Set `serialized`{.variable}.\[\[M22\]\] to `value`{.variable}'s
        [m22 element](#matrix-m22-element){#ref-for-matrix-m22-element⑦
        link-type="dfn"}.

    7.  Set `serialized`{.variable}.\[\[M23\]\] to `value`{.variable}'s
        [m23 element](#matrix-m23-element){#ref-for-matrix-m23-element⑤
        link-type="dfn"}.

    8.  Set `serialized`{.variable}.\[\[M24\]\] to `value`{.variable}'s
        [m24 element](#matrix-m24-element){#ref-for-matrix-m24-element⑤
        link-type="dfn"}.

    9.  Set `serialized`{.variable}.\[\[M31\]\] to `value`{.variable}'s
        [m31 element](#matrix-m31-element){#ref-for-matrix-m31-element④
        link-type="dfn"}.

    10. Set `serialized`{.variable}.\[\[M32\]\] to `value`{.variable}'s
        [m32 element](#matrix-m32-element){#ref-for-matrix-m32-element④
        link-type="dfn"}.

    11. Set `serialized`{.variable}.\[\[M33\]\] to `value`{.variable}'s
        [m33 element](#matrix-m33-element){#ref-for-matrix-m33-element④
        link-type="dfn"}.

    12. Set `serialized`{.variable}.\[\[M34\]\] to `value`{.variable}'s
        [m34 element](#matrix-m34-element){#ref-for-matrix-m34-element④
        link-type="dfn"}.

    13. Set `serialized`{.variable}.\[\[M41\]\] to `value`{.variable}'s
        [m41 element](#matrix-m41-element){#ref-for-matrix-m41-element⑦
        link-type="dfn"}.

    14. Set `serialized`{.variable}.\[\[M42\]\] to `value`{.variable}'s
        [m42 element](#matrix-m42-element){#ref-for-matrix-m42-element⑦
        link-type="dfn"}.

    15. Set `serialized`{.variable}.\[\[M43\]\] to `value`{.variable}'s
        [m43 element](#matrix-m43-element){#ref-for-matrix-m43-element⑤
        link-type="dfn"}.

    16. Set `serialized`{.variable}.\[\[M44\]\] to `value`{.variable}'s
        [m44 element](#matrix-m44-element){#ref-for-matrix-m44-element⑧
        link-type="dfn"}.

    17. Set `serialized`{.variable}.\[\[Is2D\]\] to `false`.

    Their [deserialization
    steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps){#ref-for-deserialization-steps③
    link-type="dfn"}, given `serialized`{.variable} and
    `value`{.variable}, are:

    1.  If `serialized`{.variable}.\[\[Is2D\]\] is `true`:

        1.  Set `value`{.variable}'s [m11
            element](#matrix-m11-element){#ref-for-matrix-m11-element①①
            link-type="dfn"} to `serialized`{.variable}.\[\[M11\]\].

        2.  Set `value`{.variable}'s [m12
            element](#matrix-m12-element){#ref-for-matrix-m12-element⑧
            link-type="dfn"} to `serialized`{.variable}.\[\[M12\]\].

        3.  Set `value`{.variable}'s [m13
            element](#matrix-m13-element){#ref-for-matrix-m13-element⑦
            link-type="dfn"} to [0]{.css}.

        4.  Set `value`{.variable}'s [m14
            element](#matrix-m14-element){#ref-for-matrix-m14-element⑥
            link-type="dfn"} to [0]{.css}.

        5.  Set `value`{.variable}'s [m21
            element](#matrix-m21-element){#ref-for-matrix-m21-element⑧
            link-type="dfn"} to `serialized`{.variable}.\[\[M21\]\].

        6.  Set `value`{.variable}'s [m22
            element](#matrix-m22-element){#ref-for-matrix-m22-element⑧
            link-type="dfn"} to `serialized`{.variable}.\[\[M22\]\].

        7.  Set `value`{.variable}'s [m23
            element](#matrix-m23-element){#ref-for-matrix-m23-element⑥
            link-type="dfn"} to [0]{.css}.

        8.  Set `value`{.variable}'s [m24
            element](#matrix-m24-element){#ref-for-matrix-m24-element⑥
            link-type="dfn"} to [0]{.css}.

        9.  Set `value`{.variable}'s [m31
            element](#matrix-m31-element){#ref-for-matrix-m31-element⑤
            link-type="dfn"} to [0]{.css}.

        10. Set `value`{.variable}'s [m32
            element](#matrix-m32-element){#ref-for-matrix-m32-element⑤
            link-type="dfn"} to [0]{.css}.

        11. Set `value`{.variable}'s [m33
            element](#matrix-m33-element){#ref-for-matrix-m33-element⑤
            link-type="dfn"} to [1]{.css}.

        12. Set `value`{.variable}'s [m34
            element](#matrix-m34-element){#ref-for-matrix-m34-element⑤
            link-type="dfn"} to [0]{.css}.

        13. Set `value`{.variable}'s [m41
            element](#matrix-m41-element){#ref-for-matrix-m41-element⑧
            link-type="dfn"} to `serialized`{.variable}.\[\[M41\]\].

        14. Set `value`{.variable}'s [m42
            element](#matrix-m42-element){#ref-for-matrix-m42-element⑧
            link-type="dfn"} to `serialized`{.variable}.\[\[M42\]\].

        15. Set `value`{.variable}'s [m43
            element](#matrix-m43-element){#ref-for-matrix-m43-element⑥
            link-type="dfn"} to [0]{.css}.

        16. Set `value`{.variable}'s [m44
            element](#matrix-m44-element){#ref-for-matrix-m44-element⑨
            link-type="dfn"} to [1]{.css}.

        17. Set `value`{.variable}'s [is
            2D](#matrix-is-2d){#ref-for-matrix-is-2d③⓪ link-type="dfn"}
            to `true`.

    2.  Otherwise:

        1.  Set `value`{.variable}'s [m11
            element](#matrix-m11-element){#ref-for-matrix-m11-element①②
            link-type="dfn"} to `serialized`{.variable}.\[\[M11\]\].

        2.  Set `value`{.variable}'s [m12
            element](#matrix-m12-element){#ref-for-matrix-m12-element⑨
            link-type="dfn"} to `serialized`{.variable}.\[\[M12\]\].

        3.  Set `value`{.variable}'s [m13
            element](#matrix-m13-element){#ref-for-matrix-m13-element⑧
            link-type="dfn"} to `serialized`{.variable}.\[\[M13\]\].

        4.  Set `value`{.variable}'s [m14
            element](#matrix-m14-element){#ref-for-matrix-m14-element⑦
            link-type="dfn"} to `serialized`{.variable}.\[\[M14\]\].

        5.  Set `value`{.variable}'s [m21
            element](#matrix-m21-element){#ref-for-matrix-m21-element⑨
            link-type="dfn"} to `serialized`{.variable}.\[\[M21\]\].

        6.  Set `value`{.variable}'s [m22
            element](#matrix-m22-element){#ref-for-matrix-m22-element⑨
            link-type="dfn"} to `serialized`{.variable}.\[\[M22\]\].

        7.  Set `value`{.variable}'s [m23
            element](#matrix-m23-element){#ref-for-matrix-m23-element⑦
            link-type="dfn"} to `serialized`{.variable}.\[\[M23\]\].

        8.  Set `value`{.variable}'s [m24
            element](#matrix-m24-element){#ref-for-matrix-m24-element⑦
            link-type="dfn"} to `serialized`{.variable}.\[\[M24\]\].

        9.  Set `value`{.variable}'s [m31
            element](#matrix-m31-element){#ref-for-matrix-m31-element⑥
            link-type="dfn"} to `serialized`{.variable}.\[\[M31\]\].

        10. Set `value`{.variable}'s [m32
            element](#matrix-m32-element){#ref-for-matrix-m32-element⑥
            link-type="dfn"} to `serialized`{.variable}.\[\[M32\]\].

        11. Set `value`{.variable}'s [m33
            element](#matrix-m33-element){#ref-for-matrix-m33-element⑥
            link-type="dfn"} to `serialized`{.variable}.\[\[M33\]\].

        12. Set `value`{.variable}'s [m34
            element](#matrix-m34-element){#ref-for-matrix-m34-element⑥
            link-type="dfn"} to `serialized`{.variable}.\[\[M34\]\].

        13. Set `value`{.variable}'s [m41
            element](#matrix-m41-element){#ref-for-matrix-m41-element⑨
            link-type="dfn"} to `serialized`{.variable}.\[\[M41\]\].

        14. Set `value`{.variable}'s [m42
            element](#matrix-m42-element){#ref-for-matrix-m42-element⑨
            link-type="dfn"} to `serialized`{.variable}.\[\[M42\]\].

        15. Set `value`{.variable}'s [m43
            element](#matrix-m43-element){#ref-for-matrix-m43-element⑦
            link-type="dfn"} to `serialized`{.variable}.\[\[M43\]\].

        16. Set `value`{.variable}'s [m44
            element](#matrix-m44-element){#ref-for-matrix-m44-element①⓪
            link-type="dfn"} to `serialized`{.variable}.\[\[M44\]\].

        17. Set `value`{.variable}'s [is
            2D](#matrix-is-2d){#ref-for-matrix-is-2d③① link-type="dfn"}
            to `false`.

## [8. ]{.secno}[Security Considerations]{.content}[](#security){.self-link} {#security .heading .settled level="8"}

The [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦①
link-type="idl"} and
[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③①
link-type="idl"} interfaces have entry-points to parsing a string with
CSS syntax. Therefore the [security
considerations](https://drafts.csswg.org/css-syntax/#security) of the
CSS Syntax specification apply.
[\[CSS3-SYNTAX\]](#biblio-css3-syntax "CSS Syntax Module Level 3"){link-type="biblio"}

::: {#example-2f98d29f .example}
[](#example-2f98d29f){.self-link} This could potentially be used to
exploit bugs in the CSS parser in a user agent.
:::

There are no other known security or privacy impacts of the interfaces
defined in this specification. However, other specifications that have
APIs that use the interfaces defined in this specification could
potentially introduce security or privacy issues.

## [9. ]{.secno}[Privacy Considerations]{.content}[](#priv-sec){.self-link} {#priv-sec .heading .settled level="9"}

::: {#example-8bb3622b .example}
[](#example-8bb3622b){.self-link} For example, the
[`getBoundingClientRect()`{.idl}](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect){#ref-for-dom-element-getboundingclientrect
link-type="idl"} API defined in CSSOM View returns a
[`DOMRect`{.idl}](#domrect){#ref-for-domrect①⑦ link-type="idl"} that
could be used to measure the size of an inline element containing some
text of a particular font, which exposes information about whether the
user has that font installed. That information, if used to test many
common fonts, can then be personally-identifiable information.
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module"){link-type="biblio"}
:::

## [10. ]{.secno}[Historical]{.content}[](#historical){.self-link} {#historical .heading .settled level="10"}

*This section is non-normative.*

The interfaces in this specification are intended to replace earlier
similar interfaces found in various specifications as well as
proprietary interfaces found in some user agents. This section attempts
to enumerate these interfaces.

### [10.1. ]{.secno}[CSSOM View]{.content}[](#historical-cssom-view){.self-link} {#historical-cssom-view .heading .settled level="10.1"}

Earlier revisions of CSSOM View defined a `ClientRect` interface, which
is replaced by [`DOMRect`{.idl}](#domrect){#ref-for-domrect①⑧
link-type="idl"}. Implementations conforming to this specification will
not support `ClientRect`.
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module"){link-type="biblio"}

### [10.2. ]{.secno}[SVG]{.content}[](#historical-svg){.self-link} {#historical-svg .heading .settled level="10.2"}

Earlier revisions of SVG defined
[`SVGPoint`{.idl}](#svgpoint){#ref-for-svgpoint① link-type="idl"},
[`SVGRect`{.idl}](#svgrect){#ref-for-svgrect① link-type="idl"},
[`SVGMatrix`{.idl}](#svgmatrix){#ref-for-svgmatrix② link-type="idl"},
which are defined in this specifications as aliases to
[`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint③④ link-type="idl"},
[`DOMRect`{.idl}](#domrect){#ref-for-domrect①⑨ link-type="idl"},
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦② link-type="idl"},
respectively.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"){link-type="biblio"}

### [10.3. ]{.secno}[Non-standard]{.content}[](#historical-non-standard){.self-link} {#historical-non-standard .heading .settled level="10.3"}

Some user agents supported a `WebKitPoint` interface. Implementations
conforming to this specification will not support `WebKitPoint`.

Several user agents supported a
[`WebKitCSSMatrix`{.idl}](#webkitcssmatrix){#ref-for-webkitcssmatrix
link-type="idl"} interface, which is also widely used on the Web. It is
defined in this specification as an alias to
[`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦③ link-type="idl"}.

Some user agents supported a `MSCSSMatrix` interface. Implementations
conforming to this specification will not support `MSCSSMatrix`.

## [Document conventions]{.content}[](#conventions){.self-link} {#conventions .heading .no-num .settled}

The [NaN-safe minimum]{#nan-safe-minimum .dfn .dfn-paneled
dfn-type="dfn" noexport=""} of a non-empty list of
[`unrestricted double`{.idl}](https://webidl.spec.whatwg.org/#idl-unrestricted-double){#ref-for-idl-unrestricted-double①⑥②
link-type="idl"} values is NaN if any member of the list is NaN, or the
minimum of the list otherwise.

Analogously, the [NaN-safe maximum]{#nan-safe-maximum .dfn .dfn-paneled
dfn-type="dfn" noexport=""} of a non-empty list of
[`unrestricted double`{.idl}](https://webidl.spec.whatwg.org/#idl-unrestricted-double){#ref-for-idl-unrestricted-double①⑥③
link-type="idl"} values is NaN if any member of the list is NaN, or the
maximum of the list otherwise.

## [Changes since last publication]{.content}[](#changes){.self-link} {#changes .heading .no-num .settled}

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
  [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦④ link-type="idl"}
  still uses an overloaded constructor for compatibility with
  [`WebKitCSSMatrix`{.idl}](#webkitcssmatrix){#ref-for-webkitcssmatrix①
  link-type="idl"}.

- Introduced the
  [`DOMMatrixInit`{.idl}](#dictdef-dommatrixinit){#ref-for-dictdef-dommatrixinit⑧
  link-type="idl"} dictionary.

- Added JSON serializers for the interfaces.

- Changed
  [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③②
  link-type="idl"} and
  [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦⑤ link-type="idl"}
  to be compatible with
  [`WebKitCSSMatrix`{.idl}](#webkitcssmatrix){#ref-for-webkitcssmatrix②
  link-type="idl"}:

  - Changed
    [`rotate()`{.idl}](#dom-dommatrixreadonly-rotate){#ref-for-dom-dommatrixreadonly-rotate①
    link-type="idl"} and
    [`rotateSelf()`{.idl}](#dom-dommatrix-rotateself){#ref-for-dom-dommatrix-rotateself②
    link-type="idl"} arguments from `(angle, originX, originY)` to
    `(rotX, rotY, rotZ)`.

  - Changed the
    [`scale()`{.idl}](#dom-dommatrixreadonly-scale){#ref-for-dom-dommatrixreadonly-scale②
    link-type="idl"} and
    [`scaleSelf()`{.idl}](#dom-dommatrix-scaleself){#ref-for-dom-dommatrix-scaleself③
    link-type="idl"} methods to be more like the previous
    `scaleNonUniform()`/`scaleNonUniformSelf()` methods, and dropped the
    `scaleNonUniformSelf()` method. Keep support for `scaleNonUniform()`
    for legacy reasons.

  - Made all arguments optional for
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦⑥
    link-type="idl"}/[`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③③
    link-type="idl"} methods, except for
    [`setMatrixValue()`{.idl}](#dom-dommatrix-setmatrixvalue){#ref-for-dom-dommatrix-setmatrixvalue②
    link-type="idl"}.

  - Added no-argument constructor.

  - Defined
    [`WebKitCSSMatrix`{.idl}](#webkitcssmatrix){#ref-for-webkitcssmatrix③
    link-type="idl"} to be a legacy window alias for
    [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦⑦
    link-type="idl"}.

- In workers, [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦⑧
  link-type="idl"} and
  [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③④
  link-type="idl"} do not support parsing or stringifying with CSS
  syntax.

- Defined structured serialization of the interfaces.

- The live `bounds` attribute on
  [`DOMQuad`{.idl}](#domquad){#ref-for-domquad①⑧ link-type="idl"} was
  replaced with a non-live
  [`getBounds()`{.idl}](#dom-domquad-getbounds){#ref-for-dom-domquad-getbounds②
  link-type="idl"} method. The \"associated bounding rectangle\" concept
  was also removed.

- Changed the string parser for
  [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑦⑨ link-type="idl"}
  and
  [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③⑤
  link-type="idl"} to use CSS rules instead of SVG rules.

- The stringifier for
  [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑧⓪ link-type="idl"}
  and
  [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③⑥
  link-type="idl"} now throws if there are non-finite values, and
  otherwise uses the
  [ToString](https://tc39.github.io/ecma262/#sec-tostring){#ref-for-sec-tostring①⑧
  link-type="dfn"} algorithm.
  [\[ECMA-262\]](#biblio-ecma-262 "ECMAScript Language Specification"){link-type="biblio"}

- Made comparisons treat [0]{.css} and [-0]{.css} as equal throughout.

- Added [§ 9 Privacy Considerations](#priv-sec) and [§ 10
  Historical](#historical) sections.

The following changes were made since the [18 September 2014 Working
Draft](https://www.w3.org/TR/2014/WD-geometry-1-20140918/).

- Exposed
  [`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly①①
  link-type="idl"}, [`DOMPoint`{.idl}](#dompoint){#ref-for-dompoint③⑤
  link-type="idl"},
  [`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly①①
  link-type="idl"}, [`DOMRect`{.idl}](#domrect){#ref-for-domrect②⓪
  link-type="idl"}, [`DOMQuad`{.idl}](#domquad){#ref-for-domquad①⑨
  link-type="idl"},
  [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③⑦
  link-type="idl"} and
  [`DOMMatrix`{.idl}](#dommatrix){#ref-for-dommatrix⑧① link-type="idl"}
  to
  [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window①
  link-type="idl"} and
  [`Worker`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#worker){#ref-for-worker
  link-type="idl"}. Defined cloning of the interface.

The following changes were made since the [26 June 2014 Last Call Public
Working Draft](https://www.w3.org/TR/2014/WD-geometry-1-20140626/).

- [`DOMPointReadOnly`{.idl}](#dompointreadonly){#ref-for-dompointreadonly①②
  link-type="idl"} got a constructor taking 4 arguments.

- [`DOMRectReadOnly`{.idl}](#domrectreadonly){#ref-for-domrectreadonly①②
  link-type="idl"} got a constructor taking 4 arguments.

- [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③⑧
  link-type="idl"} got a constructor taking a sequence of numbers as
  argument.

- [`DOMRectList`{.idl}](#domrectlist){#ref-for-domrectlist③
  link-type="idl"} turned to an ArrayClass. The interfaces can just be
  used for legacy interfaces.

- Put [`DOMRectList`{.idl}](#domrectlist){#ref-for-domrectlist④
  link-type="idl"} on at-Risk awaiting browser feedback.

- All interfaces are described in the sense of internal elements to
  describe the read-only/writable and inheriting behavior.

- Replace
  [`IndexSizeError`{.idl}](https://webidl.spec.whatwg.org/#indexsizeerror){#ref-for-indexsizeerror
  link-type="idl"} exception with
  [`TypeError`{.idl}](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror){#ref-for-sec-native-error-types-used-in-this-standard-typeerror⑥
  link-type="idl"}.

The following changes were made since the [22 May 2014 First Public
Working Draft](https://www.w3.org/TR/2014/WD-geometry-1-20140522/).

- Renamed mutable transformation methods \*By to \*Self. (E.g.
  `translateBy()` got renamed to
  [`translateSelf()`{.idl}](#dom-dommatrix-translateself){#ref-for-dom-dommatrix-translateself⑥
  link-type="idl"}.)

- Renamed `invert()` to
  [`invertSelf()`{.idl}](#dom-dommatrix-invertself){#ref-for-dom-dommatrix-invertself②
  link-type="idl"}.

- Added
  [`setMatrixValue()`{.idl}](#dom-dommatrix-setmatrixvalue){#ref-for-dom-dommatrix-setmatrixvalue③
  link-type="idl"} which takes a transformation list as
  [`DOMString`{.idl}](https://webidl.spec.whatwg.org/#idl-DOMString){#ref-for-idl-DOMString④
  link-type="idl"}.

- [`is2D`{.idl}](#dom-dommatrixreadonly-is2d){#ref-for-dom-dommatrixreadonly-is2d①
  link-type="idl"} and
  [`isIdentity`{.idl}](#dom-dommatrixreadonly-isidentity){#ref-for-dom-dommatrixreadonly-isidentity①
  link-type="idl"} are read-only attributes now.

- [`DOMMatrixReadOnly`{.idl}](#dommatrixreadonly){#ref-for-dommatrixreadonly③⑨
  link-type="idl"} gets flagged to track 3D transformation and attribute
  settings for
  [`is2D`{.idl}](#dom-dommatrixreadonly-is2d){#ref-for-dom-dommatrixreadonly-is2d②
  link-type="idl"}.

- [`invertSelf()`{.idl}](#dom-dommatrix-invertself){#ref-for-dom-dommatrix-invertself③
  link-type="idl"} and
  [`inverse()`{.idl}](#dom-dommatrixreadonly-inverse){#ref-for-dom-dommatrixreadonly-inverse①
  link-type="idl"} do not throw exceptions anymore.

## [Acknowledgments]{.content}[](#acknowledgments){.self-link} {#acknowledgments .heading .no-num .settled}

The editors would like to thank Robert O'Callahan for contributing to
this specification. Many thanks to Dean Jackson for his initial proposal
of DOMMatrix. Thanks to Adenilson Cavalcanti, Benoit Jacob, Boris
Zbarsky, Brian Birtles, Cameron McCormack, Domenic Denicola, Kari
Pihkala, Max Vujovic, Mike Taylor, Peter Hall, Philip Jägenstedt, Simon
Fraser, and Timothy Loh for their careful reviews, comments, and
corrections.
