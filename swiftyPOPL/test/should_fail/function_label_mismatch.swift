let f: <T>(outer_label: T) -> T = func <T>(inner_label: T) -> T { inner_label }
/* 
    The correct form should be: 
    let f: <T>(outer_label: T) -> T = func <T>(outer_label inner_label: T) -> T { inner_label }
*/
