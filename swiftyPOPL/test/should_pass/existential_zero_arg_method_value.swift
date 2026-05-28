protocol Show {
  func show() -> String
}

struct Box {
  let value: Int
}

extension Box: Show {
  func show() -> String { "box" }
}

let box: Box = Box(value: 1)
let erased: any Show = box as any Show
let f: () -> String = erased.show
f()
let ff: () -> String = box.show
ff()
