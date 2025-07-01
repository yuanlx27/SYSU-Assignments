#let proof(body) = block(width: 100%, inset: 8pt)[
  *_Proof._* #h(1em) #body
  #place(bottom + right, sym.qed)
]
#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #h(1em) #body
]

== 1

#proof[
  Let $X$ be a subfield of $F$ that contains $R$. Then for any $a, b in X$, we have $b^(-1) in X$ and then $a b^(-1) in X$. Hence $S subset.eq X$.
]

== 2

#solution[
  We have:

  - $overline(1)^2 = overline(1)$,

  - $overline(4)^2 = overline(16) = overline(1)$,

  - $overline(11)^2 = overline(121) = overline(1)$,

  - $overline(14)^2 = overline(196) = overline(1)$.
]

== 3

#proof[
  Let $a = 4 m, b = 4 n$. Then $a, b in D$, and $a + b = 4(m + n) in D$. Also, for any $r in R$, we have $a r = 4(m r) in D$. Hence $D$ is an ideal of $R$.
]

The quotient ring $R slash D$ is ${ D, 2 + D }$.

== 4

#solution[
  The ideals and corresponding quotient rings are

  $
    k ZZ slash 12 ZZ, wide "and" { n + k ZZ slash 12 ZZ | n in ZZ slash k ZZ },
  $

  where $k = 1, 2, ..., 11$.
]

== 5

#proof[
  Note that $phi: p |-> p(i)$ is an isomorphism from $RR[x] slash angle.l x^2 + 1 angle.r$ to $CC$.
]
