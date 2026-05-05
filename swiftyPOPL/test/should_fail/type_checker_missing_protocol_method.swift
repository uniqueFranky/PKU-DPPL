protocol Show {
  func show() -> String
}

struct Box {
  let x: Int
}

extension Box: Show {
  func not_show() -> String { "not show" }
}
