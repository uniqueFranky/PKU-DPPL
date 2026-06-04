struct Point {
  let x: Int
  let y: Int
  func sum() -> Int {
    self.x + self.y
  }
}

let origin: Point = Point(x: 1, y: 0)
origin.sum()