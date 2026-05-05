struct Counter {
  let apply: <T>(T) -> T

  func inc(x: Int) -> Int { x }
}
