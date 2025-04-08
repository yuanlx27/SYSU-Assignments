

#let report(
  title: "标题",
  subtitle: "副标题",
  name: "姓名",
  stuid: "学号",
  class: "班级",
  major: "专业",
  institude: "学院",
  term: "学期",

  body
) = [
  #set document(title: title)

  #set text(
    lang: "zh",
    font: "Noto Serif CJK SC"
  )

  #align(center)[
    #image("../assets/sysu.png")

    #block(text(weight: "bold", size: 30pt, title))
    #linebreak()
    #block(text(weight: "medium", size: 24pt, subtitle))

    #v(90pt)

    #set text(size: 15pt)
    
    #grid(
      columns: (160pt, 240pt),
      row-gutter: 2em,
      rect(stroke: none, h(2fr) + "姓" + h(1fr) + "名" + h(2fr)), rect(width: 100%, stroke: (bottom: black), name),
      rect(stroke: none, h(2fr) + "学" + h(1fr) + "号" + h(2fr)), rect(width: 100%, stroke: (bottom: black), stuid),
      rect(stroke: none, h(2fr) + "班" + h(1fr) + "级" + h(2fr)), rect(width: 100%, stroke: (bottom: black), class),
      rect(stroke: none, h(2fr) + "专" + h(1fr) + "业" + h(2fr)), rect(width: 100%, stroke: (bottom: black), major),
      rect(stroke: none, h(2fr) + "学" + h(1fr) + "院" + h(2fr)), rect(width: 100%, stroke: (bottom: black), institude),
    )
  ]

  #pagebreak()

  #set text(
    lang: "zh",
    font: "Noto Sans CJK SC"
  )

  #show link: set text(fill: blue)

  #body
]