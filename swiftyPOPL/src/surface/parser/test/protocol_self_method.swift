protocol Show {
  func show() -> String
  func combine(_ other: Self) -> Self
}
