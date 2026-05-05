protocol Show {
  func show() -> String
}

struct Box {
  let x: Int
}

extension Box: Show {
  func show() -> String { "box" }
}

let b: Box = Box(x: 1)
let s: any Show = b as any Show
s.show()
