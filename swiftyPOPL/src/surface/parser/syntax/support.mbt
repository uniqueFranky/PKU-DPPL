///|
struct Pos {
  fname : String
  lnum : Int
  bol : Int
  cnum : Int
}

///|
impl Show for Pos with output(self, logger) {
  logger.write_string("\{self.fname}:\{self.lnum}:\{self.cnum - self.bol + 1}")
}

pub fn pos_line(pos : Pos) -> Int {
  pos.lnum
}

pub fn pos_column(pos : Pos) -> Int {
  pos.cnum - pos.bol + 1
}

pub fn pos_to_string(pos : Pos) -> String {
  "\{pos.fname}:\{pos.lnum}:\{pos.cnum - pos.bol + 1}"
}

fn join_strings(xs : Array[String], sep : String) -> String {
  let b = StringBuilder::new()
  for i = 0; i < xs.length(); i = i + 1 {
    if i > 0 {
      b.write_string(sep)
    }
    b.write_string(xs[i])
  }
  b.to_string()
}

fn repeat_space(n : Int) -> String {
  let b = StringBuilder::new()
  for i = 0; i < n; i = i + 1 {
    b.write_string(" ")
  }
  b.to_string()
}

fn source_line(fname : String, line_no : Int) -> String? {
  try {
    let code = @fs.read_file_to_string(fname)
    let lines = code.split("\n").to_array()
    if line_no > 0 && line_no <= lines.length() {
      Some(lines[line_no - 1].to_owned())
    } else {
      None
    }
  } catch {
    _ => None
  }
}

pub fn format_unexpected_token(
  fname : String,
  token : Token,
  start : Pos,
  expected : Array[TokenKind],
) -> String {
  let col = pos_column(start)
  let line_no = pos_line(start)
  let b = StringBuilder::new()
  b.write_string("SyntaxError: \{pos_to_string(start)}\n")
  b.write_string("  unexpected token: \{token}\n")
  if expected.length() > 0 {
    let expected_strings = []
    for x in expected {
      expected_strings.push("`\{x}`")
    }
    let expected_msg = join_strings(expected_strings, ", ")
    b.write_string("  expected one of: \{expected_msg}\n")
  }
  match source_line(fname, line_no) {
    None => ()
    Some(line) => {
      b.write_string("\n")
      b.write_string("\{line_no} | \{line}\n")
      b.write_string(
        "\{repeat_space(line_no.to_string().length())} | \{repeat_space(col - 1)}^\n",
      )
    }
  }
  b.to_string()
}

///|
enum Info {
  FI(Pos, Pos)
  UNKNOWN
}

///|
impl Show for Info with output(self, logger) {
  match self {
    FI(start, end) => logger.write_string(" [\{start}--\{end}]")
    UNKNOWN => ()
  }
}

///|
suberror ErrorWithInfo {
  ErrorWithInfo((String, Info))
}

///|
fn[T] error_info(msg : String, info? : Info = UNKNOWN) -> T raise {
  raise ErrorWithInfo((msg, info))
}

fn to_param_sigs(params: Array[ParamDecl]) -> Array[ParamSig] {
  match params {
    [] => []
    [ParamDecl::ParamDecl(label, _, ty), ..rest] =>
      [ParamSig::ParamSig(label, ty)].add(to_param_sigs([..rest]))
  }
}
