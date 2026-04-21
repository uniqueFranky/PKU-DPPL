fn parse_file(fname : String) -> Array[(Token, Pos, Pos)] raise {
  try {
    let code = @fs.read_file_to_string(fname)
    let lexer = new_lexer(code)
    reset_lex(fname)
    let tokens = []
    while true {
      let elem = lexer.next_token()
      tokens.push(elem)
      match elem.0 {
        EOF => break
        _ => continue
      }
    }
    return tokens
  } catch {
    e => raise e
  }
}

fn parse_program(tokens : Array[(Token, Pos, Pos)]) -> Program raise {
  program(tokens)

}


fn main {
  let argv = @sys.get_cli_args()[1:]
  try {
    if argv.length() != 1 {
      error_info("you must specify exactly one input file")
    } else {
      let fname = argv[0]
      let tokens = parse_file(fname)
      let prog = parse_program(tokens)
      println("Parsed program: \{prog[0]}")
    }
  } catch {
    ErrorWithInfo((msg, info)) =>
      if not(msg.is_empty()) {
        println("Error:\{info} \{msg}")
      }
    _ => panic()
  }
}

