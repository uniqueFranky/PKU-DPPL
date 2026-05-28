let x: Int = 1 + 2
let y: Int = x - 1
let lt: Bool = y < 3
let gt: Bool = y > 0
let le: Bool = y <= 2
let ge: Bool = y >= 2
let b: Bool = !(false || false) && true

if lt && gt && le && ge && b {
  y
} else {
  0
}
