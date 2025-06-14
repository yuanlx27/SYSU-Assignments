#import "@preview/lilaq:0.3.0" as lq

#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #body
]

= 6.23

== (b)

#solution[
  We have

  $
    H(j omega) = cases(
      e^(j omega T)\, quad & abs(omega) <= omega_c,
      0. quad & "otherwise",
    )
  $

  Hence

  $
    h(t) = (sin(omega_c (t + T)))/(pi (t + T)),
  $

  as shown in the figure below.

  #let xs = lq.linspace(-calc.pi, calc.pi)
  #figure(
    lq.diagram(
      legend: lq.legend([$omega_c = T = 1$]),
      lq.plot(xs, xs.map(x => calc.sin(x + 1) / (calc.pi * (x + 1))), mark: none),
    ),
  )
]

== (c)

#solution[
  We have

  $
    H(j omega) = cases(
      e^(j pi/2) = j\, quad & 0 < omega <= omega_c,
      e^(-j pi/2) = -j\, quad & -omega_c <= omega < 0,
      0. quad & "otherwise",
    )
  $

  Hence by the inverse Fourier transform equation,

  $
    h(t) = 1/(2 pi) integral_0^omega_c j e^(j omega t) dif omega + 1/(2 pi) integral_(-omega_c)^0 -j e^(j omega t) dif omega = (cos omega_c t - 1)/(pi t),
  $

  as shown in the figure below.

  #let xs = lq.linspace(-calc.pi, calc.pi)
  #figure(
    lq.diagram(
      legend: lq.legend([$omega_c = 1$]),
      lq.plot(xs, xs.map(x => (calc.cos(x) - 1) / (calc.pi * x)), mark: none),
    ),
  )
]
