#import "@preview/cetz:0.4.0"
#import "@preview/cetz-plot:0.1.2"

#import "@preview/fletcher:0.5.8" as fl

#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #body
]

= 7.3

== (a)

#solution[
  We have

  $
    X(j omega) = 2 pi delta(omega) + pi(delta(omega - 2000 pi) + delta(omega + 2000 pi)) + pi/j (delta(omega - 4000 pi) - delta(omega + 4000 pi)).
  $

  Hence $omega_N = 8000 pi$.
]

== (b)

#solution[
  We have

  $
    X(j omega) = cases(
      1\, quad & abs(omega) < 4000 pi,
      0. quad & "otherwise",
    )
  $

  Hence $omega_N = 8000 pi$.
]

== (c)

#solution[
  Let $x_1(t) = (sin 4000 pi t)/(pi t)$ as in (b). We have

  $
    X(j omega) = X_1(j omega) * X_1(j omega).
  $

  Hence $omega_N = 16000 pi$.
]

= 7.6

#solution[
  Since $w(t) = x_1(t) x_2(t)$, we have $W(j omega) = X_1(j omega) * X_2(j omega)$. This implies that $W(j omega) = 0$ for $abs(omega) >= omega_1 + omega_2$. Hence $T = (2 pi)/(2 (omega_1 + omega_2)) = pi/(omega_1 + omega_2)$.
]

= 7.23

== (a)

#solution[
  Let $p_1(t) = sum_(k = -oo)^oo delta(t - 2 k Delta)$. Then $p(t) = p_1(t) - p_1(t - Delta)$. Since

  $
    P_1(j omega) = pi/Delta sum_(k = -oo)^oo delta(omega - (k pi)/Delta),
  $

  we have

  $
    P(j omega) = P_1(j omega) - e^(-j omega Delta) P_1(j omega) = (2 pi)/Delta sum_(k = -oo)^oo delta(omega - ((2 k + 1) pi)/Delta).
  $

  Hence

  $
    X_p (j omega) = 1/(2 pi) (X(j omega) * P(j omega)) = 1/(Delta) sum_(k = -oo)^oo X(j omega - j ((2 k + 1) pi)/Delta), quad Y(j omega) = X_p (j omega) H(j omega)
  $

  as shown in the figures below.

  #figure(
    cetz.canvas({
      import cetz.draw: *
      import cetz-plot: *

      plot.plot(
        name: "plot",
        size: (12, 1),
        axis-style: "school-book",
        x-label: $omega$, x-min: -10, x-max: 10, x-tick-step: none,
        y-label: $X_p (j omega)$, y-min: 0, y-max: 2, y-tick-step: none,
        {
          for x in (-6, -2, 2, 6) {
            plot.add(style: (stroke: black), domain: (x - 1, x + 1), t => (t, calc.cos(calc.pi * (t - x))/2 + 1))
            plot.add(style: (stroke: black), ((x - 1, 0), (x - 1, 1/2 + 0.02)))
            plot.add(style: (stroke: black), ((x + 1, 0), (x + 1, 1/2 + 0.02)))
          }
          plot.add(((-2, 0), (-2, 0.1)), style: (stroke: black))
          plot.add-anchor("l", (-2, 0))
          plot.add(((2, 0), (2, 0.1)), style: (stroke: black))
          plot.add-anchor("r", (2, 0))
          plot.add(((-0.1, 1.5), (0.1, 1.5)), style: (stroke: black))
          plot.add-anchor("u", (0, 1.5))
          plot.add-anchor("ll", (-9, 1))
          plot.add-anchor("rr", (9, 1))
        },
      )
      content("plot.l", $-Delta/pi$, padding: 0.2, anchor: "north")
      content("plot.r", $Delta/pi$, padding: 0.2, anchor: "north")
      content("plot.u", $1/Delta$, padding: 0.1, anchor: "east")
      content("plot.ll", [...])
      content("plot.rr", [...])
    })
  )

  #figure(
    cetz.canvas({
      import cetz.draw: *
      import cetz-plot: *

      plot.plot(
        name: "plot",
        size: (12, 1),
        axis-style: "school-book",
        x-label: $omega$, x-min: -10, x-max: 10, x-tick-step: none,
        y-label: $Y(j omega)$, y-min: 0, y-max: 2, y-tick-step: none,
        {
          for x in (-6, 2) {
            plot.add(style: (stroke: black), domain: (x, x + 1), t => (t, calc.cos(calc.pi * (t - x))/2 + 1))
            plot.add(style: (stroke: black), ((x + 1, 0), (x + 1, 1/2 + 0.03)))
            plot.add(style: (stroke: black), ((x, 0), (x, 3/2 + 0.03)))
          }
          for x in (-2, 6) {
            plot.add(style: (stroke: black), domain: (x - 1, x), t => (t, calc.cos(calc.pi * (t - x))/2 + 1))
            plot.add(style: (stroke: black), ((x - 1, 0), (x - 1, 1/2 + 0.03)))
            plot.add(style: (stroke: black), ((x, 0), (x, 3/2 + 0.03)))
          }
          plot.add-anchor("l", (-2, 0))
          plot.add-anchor("r", (2, 0))
          plot.add(((-0.1, 1.5), (0.1, 1.5)), style: (stroke: black))
          plot.add-anchor("u", (0, 1.5))
        },
      )
      content("plot.l", $-Delta/pi$, padding: 0.2, anchor: "north")
      content("plot.r", $Delta/pi$, padding: 0.2, anchor: "north")
      content("plot.u", $1/Delta$, padding: 0.2, anchor: "east")
    })
  )
]

== (b)

#solution[
  The system that can be used to recover $x(t)$ from $x_p (t)$ is as shown in the figure below,

  #figure(
    fl.diagram({
      let (A, B, C, D, E) = ((0, 0), (1, 0), (1, 1), (2, 0), (3, 0))

      fl.node(A, $x_p (t)$)
      fl.node(B, $times$, stroke: 1pt, shape: circle)
      fl.node(C, $e^(-j pi/Delta t)$)
      fl.node(D, $H_b (j omega)$, stroke: 1pt)
      fl.node(E, $x(t)$)

      fl.edge(A, B, "->")
      fl.edge(C, B, "->")
      fl.edge(B, D, "->")
      fl.edge(D, E, "->")
    }),
  )

  where

  $
    H_b (j omega) = cases(
      Delta\, quad & abs(omega) <= omega_M,
      0. quad & "otherwise",
    )
  $
]

== (c)

#solution[
  The system that can be used to recover $x(t)$ from $y(t)$ is as shown in the figure below,

  #figure(
    fl.diagram({
      let (A, B, C, D, E) = ((0, 0), (1, 0), (1, 1), (2, 0), (3, 0))

      fl.node(A, $y(t)$)
      fl.node(B, $times$, stroke: 1pt, shape: circle)
      fl.node(C, $cos(pi/Delta t)$)
      fl.node(D, $H_c (j omega)$, stroke: 1pt)
      fl.node(E, $x(t)$)

      fl.edge(A, B, "->")
      fl.edge(C, B, "->")
      fl.edge(B, D, "->")
      fl.edge(D, E, "->")
    }),
  )

  where

  $
    H_b (j omega) = cases(
      Delta\, quad & abs(omega) <= omega_M,
      0. quad & "otherwise",
    )
  $
]

== (d)

#solution[
  We can see from the figures in (a) that to avoid aliasing, there should be $omega_M <= pi/Delta$. Hence $Delta_max = pi/omega_M$.
]
