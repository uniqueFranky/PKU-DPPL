let x: String = "outer"
if true {
    let x: String = "inner"
    x
} else {
    "fatal"
}

