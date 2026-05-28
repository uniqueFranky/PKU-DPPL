let polyId: <T>(T) -> T = func <T>(_ value: T) -> T {
  value
}

let one: Int = polyId<Int>(1)
let same: Bool = polyId<Bool>(true)
one
