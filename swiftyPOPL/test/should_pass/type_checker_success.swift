protocol Show {
  func show() -> String
}

struct Box {
  let x: Int
  func id<T>(x: T) -> T { x }
}

extension Box: Show {
  func show() -> String { "box" }
}

let b: Box = Box(x: 1)
let x: Int = b.x
let y: Int = b.id<Int>(1)
b.show()
