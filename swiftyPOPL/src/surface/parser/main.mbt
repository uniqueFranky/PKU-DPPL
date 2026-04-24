fn parse_file(fname : String) -> Array[(@syntax.Token, @syntax.Pos, @syntax.Pos)] raise {
  try {
    let code = @fs.read_file_to_string(fname)
    let lexer = @syntax.new_lexer(code)
    let tokens = []
    while true {
      let elem = lexer.next_token()
      tokens.push(elem)
      match elem.0 {
        @syntax.EOF => break
        _ => continue
      }
    }
    return tokens
  } catch {
    e => raise e
  }
}

fn parse_program(tokens : Array[(@syntax.Token, @syntax.Pos, @syntax.Pos)]) -> @syntax.Program raise {
  @syntax.program(tokens)
}


fn main {
  let argv = @sys.get_cli_args()[1:]
  try {
    if argv.length() != 1 {
      println("you must specify exactly one input file")
    } else {
      let fname = argv[0]
      let tokens = parse_file(fname)
      let prog = parse_program(tokens)
      println("Parsed program: \{prog}")
    }
  } catch {
    _ => panic()
  }
}

