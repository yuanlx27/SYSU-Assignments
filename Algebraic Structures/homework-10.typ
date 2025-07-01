#let proof(body) = block(width: 100%, inset: 8pt)[
  *_Proof._* #h(1em) #body
  #place(bottom + right, sym.qed)
]
#let solution(body) = block(width: 100%, inset: 8pt)[
  *_Solution._* #h(1em) #body
]

== 1

#proof[
  Note that $ZZ[i]$ is a PID. Since $angle.l 1 + 2 i angle.r$ is a prime ideal, it is also a maximal ideal.
]

== 2

#proof[
  Since $ZZ_2$ is a PID, $ZZ_2[x]$ is also a PID. Hence the prime ideal $angle.l x^2 + x + 1 angle.r$ is also a maximal ideal.
]

== 3

#solution[
  We have

  $
    (ZZ_3[x])/(angle.l x^2 + 2 x + 2 angle.r) = { overline(k x + r) mid(|) k, r in ZZ_3 }.
  $

  The rest of the desired results can be obtained by enumerating these elements.
]


== 4

#solution[
  The isomorphism is $phi: a x + b |-> (a, b)$.
]
