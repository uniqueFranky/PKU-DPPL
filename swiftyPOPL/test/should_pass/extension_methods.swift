protocol Show {
  func show() -> String
}

struct S {
  let x: Int
}

extension S: Show {
  func show() -> String { "S" }
}
