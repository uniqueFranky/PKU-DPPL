fn parse_surface_file(fname : String) -> @syntax.Program raise {
  let code = @fs.read_file_to_string(fname)
  let lexer = @syntax.new_lexer(code)
  @syntax.init_lex(fname)
  let tokens = []
  while true {
    let elem = lexer.next_token()
    tokens.push(elem)
    match elem.0 {
      @syntax.EOF => break
      _ => continue
    }
  }
  @syntax.program(tokens)
}

fn main {
  let argv = @sys.get_cli_args()[1:]
  try {
    if argv.length() != 1 {
      println("you must specify exactly one SwiftyPOPL input file")
    } else {
      let fname = argv[0]
      let surface = parse_surface_file(fname)
      let resolved = @resolver.resolve(surface)
      let typed = @checker.check(resolved)
      let core = @elaborator.elaborate(typed)
      @core.run_string(core, fname=fname + ".elaborated.core")
    }
  } catch {
    @syntax.UnexpectedToken(tok, (start, _), expected) =>
      if argv.length() == 1 {
        println(@syntax.format_unexpected_token(argv[0], tok, start, expected))
      } else {
        println("SyntaxError: \{@syntax.pos_to_string(start)}: unexpected token \{tok}")
      }
    @resolver.ResolveError(msg) => println("ResolveError: \{msg}")
    @elaborator.ElabError(msg) => println("ElabError: \{msg}")
    @checker.TypeError(msg) => println("TypeError: \{msg}")
    e => println("Error: \{e}")
  }
}
