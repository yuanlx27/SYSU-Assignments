#import "@preview/lilaq:0.3.0" as lq

#show math.equation: set text(font: "Libertinus Math")

= 1.21

== (f)

*_Solution._* See figure below.

#figure(
  lq.diagram(
    lq.stem((-1.5, 1.5), (-0.5, -0.5), mark: "v")
  ),
)

= 1.22

== (e)

*_Solution._* See figure below.

#figure(
  lq.diagram(
    lq.stem((-4, -3, -2, -1, 0, 1, 2, 3), (-1, -0.5, 0.5, 1, 1, 1, 1, 0.5), base-stroke: black)
  ),
)

= 1.24

== (b)

*_Solution._* See figure below.

#let xs = lq.linspace(-7, 7, num: 15)
#let fn(x) = {
  if x == -2 {
    1
  } else if x == -1 {
    2
  } else if x == 0 {
    3
  } else if x == 7 {
    1
  } else {
    0
  }
}

#figure(
  lq.diagram(
    lq.stem(
      xs,
      xs.map(x => 0.5 * (fn(x) + fn(-x))),
      base-stroke: black,
    )
  ),
)
#figure(
  lq.diagram(
    lq.stem(
      xs,
      xs.map(x => 0.5 * (fn(x) - fn(-x))),
      base-stroke: black,
    )
  ),
)

= 1.25

== (b)

*_Solution._* Periodic. Period $T = 2pi/pi = 2$.

= 1.26

== (c)

*_Solution._* If $x[n]$ is periodic, then the period $N$ must be the smallest positive integer such that

$
  pi/8 (n + N)^2 - pi/8 n^2 = pi/8 (2 n N + N^2) = 2 k pi. quad (k in ZZ)
$

This implies that $16 | (2 n N + N^2)$ for all $n$, which further implies that $N = 8$. Hence $x[n]$ is periodic with period $N = 8$.

== (e)

*_Solution._* Periodic. Period $N = lcm(8, 16, 4) = 16$.

= 1.27

== (b)

*_Solution._* Memoryless, and hence causal. Time-variant, because if $x_1(t) equiv 1$, then $y_2(pi) != y_1(0)$. Linear, because

$
  y_3(t) = cos(3 t) (a x_1(t) + b x_2(t)) = a cos(3 t) x_1(t) + b cos(3 t) x_2(t) = a y_1(t) + b y_2(t).
$

Stable, because if $|x(t)| < M$, then $|y(t)| = |cos(3 t) x(t)| <= |x(t)| < M$.

= 1.28

== (b)

*_Solution._* Time-invariant. Linear. Causal. Stable.

= 1.46

== (a)

*_Solution._* See figure below.

#let xs = lq.linspace(0, 9, num: 10)
#figure(lq.diagram(lq.stem(xs, xs.map(x => calc.pow(-1, x)), base-stroke: black)))

== (b)

*_Solution._* See figure below.

#let xs = lq.linspace(0, 9, num: 10)
#figure(lq.diagram(lq.stem(xs, xs.map(x => (1 - calc.pow(-1, x)) / 2))))
