#import "@preview/lilaq:0.3.0" as lq

#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #body
]

= 5.19

== (a)

#solution[
  Applying the Fourier transform to both sides of the equation, we obtain

  $
    (1 - 1/6 e^(-j omega) - 1/6 e^(-2 j omega)) Y(e^(j omega)) = X(e^(j omega)).
  $

  Hence

  $
    H(e^(j omega)) = Y(e^(j omega))/X(e^(j omega)) = 6/(6 - e^(-j omega) - e^(-2 j omega)).
  $
]

== (b)

#solution[
  Since

  $
    H(e^(j omega)) = 6/(6 - e^(-j omega) - e^(-2 j omega)) = 6/5 (1/(2 - e^(-j omega)) + 1/(3 + e^(-j omega))),
  $

  we have

  $
    h[n] = 3/5 (1/2)^n u[n] + 2/5 (-1/3)^n u[n].
  $
]

= 5.21

== (e)

#solution[
  Let $x_1[n] = (1/2)^abs(n), x_2[n] = cos(pi/8(n - 1))$. Then

  $
    X_1(e^(j omega)) = sum_(n = -oo)^oo (1/2)^abs(n) e^(-j omega n) = sum_(n = 0)^oo (e^(j omega)/2)^n + sum_(n = 0)^oo (e^(-j omega)/2)^n - 1 = 3/(5 - 4 cos omega),
  $

  $
    X_2(e^(j omega)) = e^(-j omega) pi sum_(l = -oo)^oo (delta(omega - pi/8 - 2 pi l) + delta(omega + pi/8 - 2 pi l)).
  $

  Since $x[n] = x_1[n] x_2[n]$, we have

  $
    X(e^(j omega)) &= 1/(2 pi) integral_(-pi)^pi X_1(e^(j theta)) X_2(e^(j(omega - theta))) dif theta \
                   &= e^(-j pi/8)/2 X_1(e^(j(omega - pi/8))) + e^(-j pi/8)/2 X_1(e^(j(omega + pi/8))) \
                   &= (3/2 e^(-j pi/8))/(5 - 4 cos(omega - pi/8)) + (3/2 e^(j pi/8))/(5 - 4 cos(omega + pi/8)).
  $
]

== (j)

#solution[
  With some simple calculations, we can obtain

  $
    (1/3)^abs(n) quad <-->^cal(F) quad 4/(5 - 3 cos omega).
  $

  By the differentiation in frequency property, we have

  $
    n (1/3)^abs(n) quad <-->^cal(F) quad j d/(d omega) (4/(5 - 3 cos omega)) = -j (12 sin omega)/(5 - 3 cos omega)^2.
  $

  Hence

  $
    X(e^(j omega)) = -j (12 sin omega)/(5 - 3 cos omega)^2 - 4/(5 - 3 cos omega).
  $

]

= 5.22

== (a)

#solution[
  $
    x[n] &= 1/(2 pi) integral_(-pi)^pi X(e^(j omega)) e^(j omega n) dif omega \
         &= 1/(2 pi) integral_(-(3 pi)/4)^(-pi/4) e^(j omega n) dif omega + 1/(2 pi) integral_(pi/4)^((3 pi)/4) e^(j omega n) dif omega \
         &= 1/(pi n) (sin (3 pi)/4 n - sin pi/4 n).
  $
]

= 5.26

== (a)

#solution[
  Note that

  $
    X_2(e^(j omega)) = cal(R e){X_1(e^(j omega))} + cal(R e){X_1(e^(j(omega - (2 pi)/3)))} + cal(R e){X_1(e^(j(omega + (2 pi)/3)))}.
  $

  Hence

  $
    x_2[n] = cal(E v){x_1[n]} (1 + e^(-j (2 pi)/3 n) + e^(j (2 pi)/3 n)) = cal(E v){x_1[n]} (1 + 2 cos (2 pi)/3 n).
  $
]

== (d)

#solution[
  From $h[n] = (sin pi/6 n)/(pi n)$ we induce that
  
  $
    H(e^(j omega)) = cases(
      1\, quad & abs(omega) <= pi/6,
      0\. quad & pi/6 < abs(omega) <= pi,
    )
  $

  Hence

  $
    X_4(e^(j omega)) = cases(
      X_1(e^(j omega))\, quad & abs(omega) <= pi/6,
      0\. quad & pi/6 < abs(omega) <= pi,
    )
  $

  #figure(
    grid(
      columns: 2,
      gutter: 2mm,
      lq.diagram(
        legend: lq.legend([$cal(R e){X_4(e^(j omega))}$]),
        lq.line((-calc.pi / 6, 0), (-calc.pi / 6, 1)),
        lq.line((-calc.pi / 6, 1), (calc.pi / 6, 1)),
        lq.line((calc.pi / 6, 1), (calc.pi / 6, 0)),
      ),
      lq.diagram(
        legend: lq.legend([$cal(I m){X_4(e^(j omega))}$]),
        lq.line((-calc.pi / 6, 0), (-calc.pi / 6, 1)),
        lq.line((-calc.pi / 6, 1), (calc.pi / 6, -1)),
        lq.line((calc.pi / 6, 0), (calc.pi / 6, -1)),
      ),
    )
  )
]

= 5.33

== (a)

#solution[
  Applying the Fourier transform to both sides of the equation, we obtain

  $
    (1 + 1/2 e^(-j omega)) Y(e^(j omega)) = X(e^(j omega)).
  $

  Hence

  $
    H(e^(j omega)) = Y(e^(j omega))/X(e^(j omega)) = 1/(1 + 1/2 e^(-j omega)).
  $
]

== (b)

=== (i)

#solution[
  When $x[n] = (1/2)^n u[n]$, we have

  $
    X(e^(j omega)) = 1/(1 - 1/2 e^(-j omega)).
  $

  Hence

  $
    Y(e^(j omega)) = 1/(1 - 1/2 e^(-j omega)) dot 1/(1 + 1/2 e^(-j omega)) = (1\/2)/(1 - 1/2 e^(-j omega)) + (1\/2)/(1 + 1/2 e^(-j omega)).
  $

  By applying the inverse Fourier transform, we obtain

  $
    y[n] = (1/2)^(n + 1) u[n] - (-1/2)^(n + 1) u[n].
  $
]

=== (iv)

#solution[
  When $x[n] = delta[n] - 1/2 delta[n - 1]$, we have

  $
    X(e^(j omega)) = 1 - 1/2 e^(-j omega).
  $

  Hence

  $
    Y(e^(j omega)) = (1 - 1/2 e^(-j omega))/(1 + 1/2 e^(-j omega)) = 2/(1 + 1/2 e^(-j omega)) - 1.
  $

  By applying the inverse Fourier transform, we obtain

  $
    y[n] = 2 (-1/2)^n u[n] - delta[n].
  $
]

== (c)

=== (i)

#solution[
  We have

  $
    Y(e^(j omega)) = (1 - 1/4 e^(-j omega))/(1 + 1/2 e^(-j omega)) dot 1/(1 + 1/2 e^(-j omega)) = (3\/2)/(1 + 1/2 e^(-j omega))^2 - (1\/2)/(1 + 1/2 e^(-j omega)).
  $

  Hence

  $
    y[n] = 3/2 (n + 1) (-1/2)^n u[n] - 1/2 (-1/2)^(n) u[n].
  $
]
