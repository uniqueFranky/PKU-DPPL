let f: (Int, Int) -> Bool = func (_: Int, val: Int) -> Bool {
    false
}

struct S {
    let x: Int
    let y: Bool
    func foo(_ x: Int) -> Bool {
        let z: Bool = false
        self.y
    }
}

protocol P {
    let x: Int
    func foo(_ x: Int) -> Bool
}


