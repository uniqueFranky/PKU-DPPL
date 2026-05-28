pub suberror ElabError {
  ElabError(String)
}

fn fail[T](msg : String) -> T raise {
  raise ElabError(msg)
}

fn join(xs : Array[String], sep : String) -> String {
  let b = StringBuilder::new()
  for i = 0; i < xs.length(); i = i + 1 {
    if i > 0 {
      b.write_string(sep)
    }
    b.write_string(xs[i])
  }
  b.to_string()
}

fn paren(s : String) -> String {
  "(\{s})"
}

fn method_name(owner : String, name : String) -> String {
  "method_\{owner}_\{name}"
}

fn dict_name(struct_name : String, protocol_name : String) -> String {
  "dict_\{struct_name}_\{protocol_name}"
}

fn dict_param_name(type_name : String, protocol_name : String) -> String {
  "dict_\{type_name}_\{protocol_name}"
}

fn method_receiver_name() -> String {
  "__swifty_method_receiver"
}

fn method_arg_name(index : Int) -> String {
  "__swifty_method_arg_\{index}"
}

fn string_lit(s : String) -> String {
  // The core lexer has a deliberately small string syntax. Surface tests only
  // use simple strings today, so keep escaping conservative here.
  "\"\{s}\""
}

fn empty_pairs() -> Array[(String, @resolver.ResolvedType)] {
  []
}

fn empty_protocol_methods() -> Array[(String, @resolver.ResolvedType)] {
  []
}

fn empty_structs() -> Array[(String, Array[(String, @resolver.ResolvedType)])] {
  []
}

fn empty_methods() -> Array[(String, String, @resolver.ResolvedType)] {
  []
}

fn empty_ext_methods() -> Array[(String, String, String, @resolver.ResolvedType)] {
  []
}

fn lookup_pair[T](xs : Array[(String, T)], key : String) -> T? {
  loop (xs) {
    [] => break None
    [(k, v), ..rest] =>
      if k == key {
        break Some(v)
      } else {
        continue ([..rest])
      }
  }
}

fn lookup_struct(
  env : ElabEnv,
  name : String,
) -> Array[(String, @resolver.ResolvedType)]? {
  lookup_pair(env.structs, name)
}

fn lookup_protocol(
  env : ElabEnv,
  name : String,
) -> Array[(String, @resolver.ResolvedType)]? {
  lookup_pair(env.protocols, name)
}

fn type_of_expr(expr : @checker.TypedExpr) -> @resolver.ResolvedType {
  match expr {
    @checker.IntLit(_, ty) => ty
    @checker.BoolLit(_, ty) => ty
    @checker.StringLit(_, ty) => ty
    @checker.Self(ty) => ty
    @checker.Ident(_, _, ty) => ty
    @checker.Unary(_, _, ty) => ty
    @checker.Binary(_, _, _, ty) => ty
    @checker.Call(_, _, _, ty) => ty
    @checker.Construct(_, _, ty) => ty
    @checker.GenericInst(_, _, ty) => ty
    @checker.As(_, _, ty) => ty
    @checker.Access(_, _, _, ty) => ty
    @checker.IfElse(_, _, _, ty) => ty
    @checker.If(_, _, ty) => ty
    @checker.Function(_, _, _, _, ty) => ty
  }
}

fn param_type(param : @resolver.ResolvedParamDecl) -> @resolver.ResolvedType {
  match param {
    @resolver.ParamDecl(_, _, ty) => ty
  }
}

fn param_name(param : @resolver.ResolvedParamDecl) -> String {
  match param {
    @resolver.ParamDecl(_, name, _) => name
  }
}

fn param_sig_type(sig : @resolver.ResolvedParamSig) -> @resolver.ResolvedType {
  match sig {
    @resolver.ParamSig(_, ty) => ty
  }
}

fn subst_self(
  ty : @resolver.ResolvedType,
  self_ty : @resolver.ResolvedType,
) -> @resolver.ResolvedType {
  // Dictionary types render protocol AbstractSelfType relative to a concrete,
  // generic, or existentially-opened receiver type.
  match ty {
    @resolver.AbstractSelfType(_) => self_ty
    @resolver.Function(tps, ps, ret) =>
      @resolver.ResolvedType::Function(
        tps,
        ps.map(fn(p) {
          match p {
            @resolver.ParamSig(label, pty) =>
              @resolver.ResolvedParamSig::ParamSig(label, subst_self(pty, self_ty))
          }
        }),
        subst_self(ret, self_ty),
      )
    _ => ty
  }
}

priv struct ElabEnv {
  structs : Array[(String, Array[(String, @resolver.ResolvedType)])]
  protocols : Array[(String, Array[(String, @resolver.ResolvedType)])]
  methods : Array[(String, String, @resolver.ResolvedType)]
  ext_methods : Array[(String, String, String, @resolver.ResolvedType)]
  constraints : Array[(String, String, String)]
}

fn env_add_constraints(
  env : ElabEnv,
  tparams : Array[@resolver.ResolvedTypeParam],
) -> ElabEnv {
  let added = []
  for tp in tparams {
    match tp {
      @resolver.Generic(_) => ()
      @resolver.Constrained(tname, cs) =>
        for c in cs {
          match c {
            @resolver.ProtocolType(pname) =>
              added.push((tname, pname, dict_param_name(tname, pname)))
            _ => ()
          }
        }
    }
  }
  {
    structs: env.structs,
    protocols: env.protocols,
    methods: env.methods,
    ext_methods: env.ext_methods,
    constraints: added.add(env.constraints),
  }
}

fn lookup_constraint_dict(env : ElabEnv, tname : String, pname : String) -> String? {
  loop (env.constraints) {
    [] => break None
    [(t, p, d), ..rest] =>
      if t == tname && p == pname {
        break Some(d)
      } else {
        continue ([..rest])
      }
  }
}

fn lookup_ext_protocol(env : ElabEnv, sname : String, mname : String) -> String? {
  loop (env.ext_methods) {
    [] => break None
    [(s, p, m, _), ..rest] =>
      if s == sname && m == mname {
        break Some(p)
      } else {
        continue ([..rest])
      }
  }
}

fn collect_env(program : @checker.TypedProgram) -> ElabEnv {
  let structs = empty_structs()
  let protocols : Array[(String, Array[(String, @resolver.ResolvedType)])] = []
  let methods = empty_methods()
  let ext_methods = empty_ext_methods()
  // Rendering uses a global signature: records for structs, requirement records
  // for protocols, and dictionary fields for extension-provided methods.
  for stmt in program.stmts {
    match stmt {
      @checker.Expr(_) => ()
      @checker.Decl(decl) =>
        match decl {
          @checker.StructDef(name, members) => {
            let fields = empty_pairs()
            for m in members {
              match m {
                @checker.Field(fname, fty) => fields.push((fname, fty))
                @checker.MethodDef(mname, tps, params, ret, _) =>
                  methods.push((
                    name,
                    mname,
                    @resolver.ResolvedType::Function(
                      tps,
                      params.map(fn(p) {
                        match p {
                          @resolver.ParamDecl(label, _, pty) =>
                            @resolver.ResolvedParamSig::ParamSig(label, pty)
                        }
                      }),
                      ret,
                    ),
                  ))
                @checker.MethodDecl(@resolver.Sig(mname, tps, ps, ret)) =>
                  methods.push((name, mname, @resolver.ResolvedType::Function(tps, ps, ret)))
                _ => ()
              }
            }
            structs.push((name, fields))
          }
          @checker.StructDecl(name) => structs.push((name, []))
          @checker.Protocol(name, members) => {
            let reqs = empty_protocol_methods()
            for m in members {
              match m {
                @checker.MethodDef(mname, tps, params, ret, _) =>
                  reqs.push((
                    mname,
                    @resolver.ResolvedType::Function(
                      tps,
                      params.map(fn(p) {
                        match p {
                          @resolver.ParamDecl(label, _, pty) =>
                            @resolver.ResolvedParamSig::ParamSig(label, pty)
                        }
                      }),
                      ret,
                    ),
                  ))
                @checker.MethodDecl(@resolver.Sig(mname, tps, ps, ret)) =>
                  reqs.push((mname, @resolver.ResolvedType::Function(tps, ps, ret)))
                _ => ()
              }
            }
            protocols.push((name, reqs))
          }
          @checker.Extension(sname, pname, members) => {
            for m in members {
              match m {
                @checker.MethodDef(mname, tps, params, ret, _) => {
                  let mty = @resolver.ResolvedType::Function(
                    tps,
                    params.map(fn(p) {
                      match p {
                        @resolver.ParamDecl(label, _, pty) =>
                          @resolver.ResolvedParamSig::ParamSig(label, pty)
                      }
                    }),
                    ret,
                  )
                  methods.push((sname, mname, mty))
                  ext_methods.push((sname, pname, mname, mty))
                }
                @checker.MethodDecl(@resolver.Sig(mname, tps, ps, ret)) => {
                  let mty = @resolver.ResolvedType::Function(tps, ps, ret)
                  methods.push((sname, mname, mty))
                  ext_methods.push((sname, pname, mname, mty))
                }
                _ => ()
              }
            }
          }
          _ => ()
        }
    }
  }
  { structs, protocols, methods, ext_methods, constraints: [] }
}

fn type_to_core(env : ElabEnv, ty : @resolver.ResolvedType) -> String raise {
  match ty {
    @resolver.Int => "Nat"
    @resolver.Bool => "Bool"
    @resolver.String => "String"
    @resolver.Unit => "Unit"
    @resolver.StructType(name) =>
      match lookup_struct(env, name) {
        None => fail("unknown struct type \{name}")
        Some(fields) => {
          let rendered = fields.map(fn(f) {
            let fty = type_to_core(env, f.1)
            "\{f.0}:\{fty}"
          })
          let body = join(rendered, ", ")
          "{\{body}}"
        }
      }
    @resolver.ProtocolType(name) => fail("protocol type \{name} cannot be used directly in core")
    @resolver.ExistentialProtocol(name) => existential_type(env, name)
    @resolver.TypeVariable(name) => name
    @resolver.AbstractSelfType(name) => name
    @resolver.Function(tparams, params, ret) => function_type_to_core(env, tparams, params, ret)
  }
}

fn function_type_to_core(
  env : ElabEnv,
  tparams : Array[@resolver.ResolvedTypeParam],
  params : Array[@resolver.ResolvedParamSig],
  ret : @resolver.ResolvedType,
) -> String raise {
  let rendered_params = []
  for tp in tparams {
    match tp {
      @resolver.Generic(_) => ()
      @resolver.Constrained(tname, cs) =>
        for c in cs {
          match c {
            @resolver.ProtocolType(pname) =>
              rendered_params.push(dict_type(env, pname, @resolver.ResolvedType::TypeVariable(tname)))
            _ => ()
          }
        }
    }
  }
  for p in params {
    rendered_params.push(type_to_core(env, param_sig_type(p)))
  }
  wrap_foralls(tparams, arrow_type_strings(rendered_params, type_to_core(env, ret)))
}

fn existential_type(env : ElabEnv, protocol_name : String) -> String raise {
  let self_ty = @resolver.ResolvedType::TypeVariable("X")
  "{Some X, {value:X, dict:\{dict_type(env, protocol_name, self_ty)}}}"
}

fn arrow_type_strings(params : Array[String], ret_s : String) -> String {
  if params.length() == 0 {
    "Unit -> \{ret_s}"
  } else {
    loop (params.rev(), ret_s) {
      ([], acc) => break acc
      ([p, ..rest], acc) => continue ([..rest], "\{p} -> \{acc}")
    }
  }
}

fn wrap_foralls(
  tparams : Array[@resolver.ResolvedTypeParam],
  body : String,
) -> String {
  loop (tparams.rev(), body) {
    ([], acc) => break acc
    ([tp, ..rest], acc) => {
      let name = match tp {
        @resolver.Generic(n) => n
        @resolver.Constrained(n, _) => n
      }
      continue ([..rest], "All \{name}. \{acc}")
    }
  }
}

fn apply_type_params(base : String, tparams : Array[@resolver.ResolvedTypeParam]) -> String {
  loop (tparams, base) {
    ([], acc) => break acc
    ([tp, ..rest], acc) => {
      let tname = match tp {
        @resolver.Generic(n) => n
        @resolver.Constrained(n, _) => n
      }
      continue ([..rest], "\{paren(acc)} [\{tname}]")
    }
  }
}

fn dict_param_args(tparams : Array[@resolver.ResolvedTypeParam]) -> Array[String] {
  let args = []
  for tp in tparams {
    match tp {
      @resolver.Generic(_) => ()
      @resolver.Constrained(tname, cs) =>
        for c in cs {
          match c {
            @resolver.ProtocolType(pname) => args.push(dict_param_name(tname, pname))
            _ => ()
          }
        }
    }
  }
  args
}

fn dict_type(env : ElabEnv, protocol_name : String, self_ty : @resolver.ResolvedType) -> String raise {
  let methods = match lookup_protocol(env, protocol_name) {
    None => fail("unknown protocol \{protocol_name}")
    Some(ms) => ms
  }
  // This mirrors checker subst_protocol_self, but self_ty may also be a type
  // variable such as a generic parameter or the hidden existential witness X.
  let fields = methods.map(fn(m) {
    let mty = match m.1 {
      @resolver.Function(tps, ps, ret) =>
        @resolver.ResolvedType::Function(
          tps,
          ps.map(fn(p) {
            match p {
              @resolver.ParamSig(label, pty) =>
                @resolver.ResolvedParamSig::ParamSig(label, subst_self(pty, self_ty))
            }
          }),
          subst_self(ret, self_ty),
        )
      _ => m.1
    }
    "\{m.0}:\{type_to_core(env, mty)}"
  })
  let body = join(fields, ", ")
  "{\{body}}"
}

fn evidence_for(env : ElabEnv, ty : @resolver.ResolvedType, protocol_name : String) -> String raise {
  match ty {
    @resolver.StructType(sname) => dict_name(sname, protocol_name)
    @resolver.TypeVariable(tname) =>
      match lookup_constraint_dict(env, tname, protocol_name) {
        Some(d) => d
        None => fail("missing dictionary evidence for \{tname}: \{protocol_name}")
      }
    _ => fail("cannot build protocol evidence")
  }
}

fn lambda_params(
  params : Array[@resolver.ResolvedParamDecl],
  body : String,
  env : ElabEnv,
) -> String raise {
  if params.length() == 0 {
    "lambda _:Unit. \{body}"
  } else {
    loop (params.rev(), body) {
      ([], acc) => break acc
      ([p, ..rest], acc) =>
        continue (
          [..rest],
          "lambda \{param_name(p)}:\{type_to_core(env, param_type(p))}. \{acc}",
        )
    }
  }
}

fn lambda_type_params(
  tparams : Array[@resolver.ResolvedTypeParam],
  body : String,
  env : ElabEnv,
) -> String raise {
  // Constrained generics become explicit dictionary parameters before ordinary
  // value parameters, while every type parameter still becomes a core type lambda.
  let with_dicts = loop (tparams.rev(), body) {
    ([], acc) => break acc
    ([tp, ..rest], acc) =>
      match tp {
        @resolver.Generic(_) => continue ([..rest], acc)
        @resolver.Constrained(tname, cs) => {
          let dicts = loop (cs.rev(), acc) {
            ([], a) => break a
            ([c, ..crest], a) =>
              match c {
                @resolver.ProtocolType(pname) =>
                  continue (
                    [..crest],
                    "lambda \{dict_param_name(tname, pname)}:\{dict_type(env, pname, @resolver.ResolvedType::TypeVariable(tname))}. \{a}",
                  )
                _ => continue ([..crest], a)
              }
          }
          continue ([..rest], dicts)
        }
      }
  }
  loop (tparams.rev(), with_dicts) {
    ([], acc) => break acc
    ([tp, ..rest], acc) => {
      let tname = match tp {
        @resolver.Generic(n) => n
        @resolver.Constrained(n, _) => n
      }
      continue ([..rest], "lambda \{tname}. \{acc}")
    }
  }
}

fn stmts_to_expr(env : ElabEnv, stmts : Array[@checker.TypedStmt]) -> String raise {
  match stmts {
    [] => "unit"
    [stmt, ..rest] =>
      match stmt {
        @checker.Expr(e) =>
          if rest.length() == 0 {
            expr_to_core(env, e)
          } else {
            paren("lambda _:Unit. \{stmts_to_expr(env, [..rest])}") + " " + paren(expr_to_core(env, e))
          }
        @checker.Decl(d) =>
          match d {
            @checker.Variable(name, ty, init) =>
              paren("lambda \{name}:\{type_to_core(env, ty)}. \{stmts_to_expr(env, [..rest])}") +
              " " +
              paren(expr_to_core(env, init))
            @checker.FunctionDef(name, tps, params, ret, body) => {
              let fty = @resolver.ResolvedType::Function(
                tps,
                params.map(fn(p) {
                  match p {
                    @resolver.ParamDecl(label, _, pty) =>
                      @resolver.ResolvedParamSig::ParamSig(label, pty)
                  }
                }),
                ret,
              )
              let fexpr = function_to_core(env, tps, params, body)
              paren("lambda \{name}:\{type_to_core(env, fty)}. \{stmts_to_expr(env, [..rest])}") +
              " " +
              paren(fexpr)
            }
            _ => stmts_to_expr(env, [..rest])
          }
      }
  }
}

fn function_to_core(
  env : ElabEnv,
  tparams : Array[@resolver.ResolvedTypeParam],
  params : Array[@resolver.ResolvedParamDecl],
  body : Array[@checker.TypedStmt],
) -> String raise {
  let env2 = env_add_constraints(env, tparams)
  lambda_type_params(tparams, lambda_params(params, stmts_to_expr(env2, body), env2), env)
}

fn typed_args_to_core(env : ElabEnv, args : Array[@checker.TypedArgExpr]) -> Array[String] raise {
  args.map(fn(a) {
    match a {
      @checker.Positional(e) => expr_to_core(env, e)
      @checker.Named(_, e) => expr_to_core(env, e)
    }
  })
}

fn apply_args(base : String, args : Array[String]) -> String {
  loop (args, base) {
    ([], acc) => break acc
    ([arg, ..rest], acc) => continue ([..rest], "\{paren(acc)} \{paren(arg)}")
  }
}

fn nat_add_core() -> String {
  "fix (lambda add:Nat -> Nat -> Nat. lambda x:Nat. lambda y:Nat. if iszero x then y else succ ((add (pred x)) y))"
}

fn nat_sub_core() -> String {
  "fix (lambda sub:Nat -> Nat -> Nat. lambda x:Nat. lambda y:Nat. if iszero y then x else ((sub (pred x)) (pred y)))"
}

fn nat_lt_core() -> String {
  "fix (lambda lt:Nat -> Nat -> Bool. lambda x:Nat. lambda y:Nat. if iszero y then false else if iszero x then true else ((lt (pred x)) (pred y)))"
}

fn expr_to_core(env : ElabEnv, expr : @checker.TypedExpr) -> String raise {
  match expr {
    @checker.IntLit(i, _) => i.to_string()
    @checker.BoolLit(b, _) => if b { "true" } else { "false" }
    @checker.StringLit(s, _) => string_lit(s)
    @checker.Self(_) => "self"
    @checker.Ident(name, _, _) => name
    @checker.Unary(@resolver.Not, e, _) =>
      "if \{expr_to_core(env, e)} then false else true"
    @checker.Binary(op, lhs, rhs, _) => {
      let lhs_s = expr_to_core(env, lhs)
      let rhs_s = expr_to_core(env, rhs)
      match op {
        @resolver.Add => apply_args(nat_add_core(), [lhs_s, rhs_s])
        @resolver.Sub => apply_args(nat_sub_core(), [lhs_s, rhs_s])
        @resolver.Less => apply_args(nat_lt_core(), [lhs_s, rhs_s])
        @resolver.LessEq => "if \{apply_args(nat_lt_core(), [rhs_s, lhs_s])} then false else true"
        @resolver.Greater => apply_args(nat_lt_core(), [rhs_s, lhs_s])
        @resolver.GreaterEq => "if \{apply_args(nat_lt_core(), [lhs_s, rhs_s])} then false else true"
        @resolver.And => "if \{lhs_s} then \{rhs_s} else false"
        @resolver.Or => "if \{lhs_s} then true else \{rhs_s}"
      }
    }
    @checker.Construct(_, args, @resolver.StructType(sname)) => {
      let fields = match lookup_struct(env, sname) {
        None => fail("unknown struct \{sname}")
        Some(fs) => fs
      }
      let rendered = fields.map(fn(f) {
        let found = loop (args) {
          [] => break None
          [a, ..rest] =>
            match a {
              @checker.Named(label, e) =>
                if label == f.0 { break Some(e) } else { continue ([..rest]) }
              @checker.Positional(_) => continue ([..rest])
            }
        }
        match found {
          None => fail("missing constructor field \{f.0}")
          Some(e) => "\{f.0}=\{expr_to_core(env, e)}"
        }
      })
      let body = join(rendered, ", ")
      "{\{body}}"
    }
    @checker.Construct(name, _, _) => fail("constructor \{name} did not have a struct type")
    @checker.Access(base, field, @checker.Field(_, _), _) =>
      "\{paren(expr_to_core(env, base))}.\{field}"
    @checker.Access(base, mname, @checker.Method(owner, _), ty) =>
      method_access_to_core(env, base, owner, mname, ty)
    @checker.Access(base, mname, @checker.ExistentialMethod(pname, _), ty) =>
      existential_method_access_to_core(env, base, pname, mname, ty)
    @checker.GenericInst(base, tys, inst_ty) =>
      match base {
        @checker.Access(recv, mname, @checker.ExistentialMethod(pname, _), original_ty) =>
          existential_generic_method_access_to_core(
            env,
            recv,
            pname,
            mname,
            original_ty,
            tys,
            inst_ty,
          )
        _ => {
          let base_s = expr_to_core(env, base)
          let applied_types = loop (tys, base_s) {
            ([], acc) => break acc
            ([ty, ..rest], acc) => continue ([..rest], "\{paren(acc)} [\{type_to_core(env, ty)}]")
          }
          match type_of_expr(base) {
            @resolver.Function(tparams, _, _) => {
              let dicts = generic_evidence_args(env, tparams, tys)
              apply_args(applied_types, dicts)
            }
            _ => applied_types
          }
        }
      }
    @checker.As(base, @resolver.ExistentialProtocol(pname), _) => {
      let base_ty = type_of_expr(base)
      let ty_s = type_to_core(env, base_ty)
      let value_s = expr_to_core(env, base)
      let dict_s = evidence_for(env, base_ty, pname)
      "{*\{ty_s}, {value=\{value_s}, dict=\{dict_s}}} as \{existential_type(env, pname)}"
    }
    @checker.As(_, _, _) => fail("only casts to any protocol are supported")
    @checker.Call(callee, args, @checker.MethodCall(_, mname), _) => {
      match callee {
        @checker.Access(base, _, @checker.ExistentialMethod(pname, _), _) =>
          existential_method_call_to_core(env, base, pname, mname, args)
        @checker.Access(_, _, _, _) =>
          apply_args(expr_to_core(env, callee), call_args_to_core(env, args))
        _ => apply_args(expr_to_core(env, callee), typed_args_to_core(env, args))
      }
    }
    @checker.Call(callee, args, _, _) => {
      let rendered_args = typed_args_to_core(env, args)
      if rendered_args.length() == 0 {
        apply_args(expr_to_core(env, callee), ["unit"])
      } else {
        apply_args(expr_to_core(env, callee), rendered_args)
      }
    }
    @checker.IfElse(cond, tbranch, ebranch, _) =>
      "if \{expr_to_core(env, cond)} then \{stmts_to_expr(env, tbranch)} else \{stmts_to_expr(env, ebranch)}"
    @checker.If(cond, tbranch, _) =>
      "if \{expr_to_core(env, cond)} then \{stmts_to_expr(env, tbranch)} else unit"
    @checker.Function(tps, params, _, body, _) => function_to_core(env, tps, params, body)
  }
}

fn call_args_to_core(env : ElabEnv, args : Array[@checker.TypedArgExpr]) -> Array[String] raise {
  let rendered_args = typed_args_to_core(env, args)
  if rendered_args.length() == 0 {
    ["unit"]
  } else {
    rendered_args
  }
}

fn existential_method_call_to_core(
  env : ElabEnv,
  base : @checker.TypedExpr,
  protocol_name : String,
  method_name : String,
  args : Array[@checker.TypedArgExpr],
) -> String raise {
  existential_method_call_with_arg_strings(
    env,
    base,
    protocol_name,
    method_name,
    typed_args_to_core(env, args),
  )
}

fn existential_method_call_with_arg_strings(
  env : ElabEnv,
  base : @checker.TypedExpr,
  protocol_name : String,
  method_name : String,
  args : Array[String],
) -> String raise {
  // The checker has ensured the visible signature is Self-free, so the hidden
  // witness type can be opened and used only inside this immediate call.
  let base_s = expr_to_core(env, base)
  let method_s = "opened_\{protocol_name}.dict.\{method_name}"
  let receiver_s = "opened_\{protocol_name}.value"
  let call_s = apply_args(apply_args(method_s, [receiver_s]), args)
  "let {X, opened_\{protocol_name}} = \{base_s} in \{call_s}"
}

fn lambda_param_sigs(
  params : Array[@resolver.ResolvedParamSig],
  body : String,
  env : ElabEnv,
) -> String raise {
  if params.length() == 0 {
    "lambda _:Unit. \{body}"
  } else {
    loop (params.rev(), body, params.length() - 1) {
      ([], acc, _) => break acc
      ([p, ..rest], acc, i) => {
        let pty = param_sig_type(p)
        continue (
          [..rest],
          "lambda \{method_arg_name(i)}:\{type_to_core(env, pty)}. \{acc}",
          i - 1,
        )
      }
    }
  }
}

fn method_arg_names(params : Array[@resolver.ResolvedParamSig]) -> Array[String] {
  let arg_names = []
  for i = 0; i < params.length(); i = i + 1 {
    arg_names.push(method_arg_name(i))
  }
  arg_names
}

fn existential_method_access_to_core(
  env : ElabEnv,
  base : @checker.TypedExpr,
  protocol_name : String,
  method_name : String,
  access_ty : @resolver.ResolvedType,
) -> String raise {
  match access_ty {
    @resolver.Function(tparams, params, _) => {
      let arg_names = method_arg_names(params)
      let with_types = "opened_\{protocol_name}.dict.\{method_name}"
      let applied_types = apply_type_params(with_types, tparams)
      let with_dicts = apply_args(applied_types, dict_param_args(tparams))
      let with_receiver = apply_args(with_dicts, ["opened_\{protocol_name}.value"])
      let call_s = apply_args(with_receiver, arg_names)
      let unpacked = "let {X, opened_\{protocol_name}} = \{expr_to_core(env, base)} in \{call_s}"
      let with_value_lambdas = lambda_param_sigs(params, unpacked, env)
      lambda_type_params(tparams, with_value_lambdas, env)
    }
    _ => existential_method_call_to_core(env, base, protocol_name, method_name, [])
  }
}

fn existential_generic_method_access_to_core(
  env : ElabEnv,
  base : @checker.TypedExpr,
  protocol_name : String,
  method_name : String,
  original_ty : @resolver.ResolvedType,
  tys : Array[@resolver.ResolvedType],
  inst_ty : @resolver.ResolvedType,
) -> String raise {
  match (original_ty, inst_ty) {
    (@resolver.Function(tparams, _, _), @resolver.Function(_, params, _)) => {
      let method_s = "opened_\{protocol_name}.dict.\{method_name}"
      let applied_types = loop (tys, method_s) {
        ([], acc) => break acc
        ([ty, ..rest], acc) => continue ([..rest], "\{paren(acc)} [\{type_to_core(env, ty)}]")
      }
      let with_dicts = apply_args(applied_types, generic_evidence_args(env, tparams, tys))
      let with_receiver = apply_args(with_dicts, ["opened_\{protocol_name}.value"])
      let arg_names = method_arg_names(params)
      let call_s = apply_args(with_receiver, arg_names)
      let unpacked = "let {X, opened_\{protocol_name}} = \{expr_to_core(env, base)} in \{call_s}"
      lambda_param_sigs(params, unpacked, env)
    }
    _ => fail("invalid generic existential method type")
  }
}

fn generic_evidence_args(
  env : ElabEnv,
  tparams : Array[@resolver.ResolvedTypeParam],
  tys : Array[@resolver.ResolvedType],
) -> Array[String] raise {
  let args = []
  for i = 0; i < tparams.length(); i = i + 1 {
    let tp = tparams[i]
    let actual = tys[i]
    match tp {
      @resolver.Generic(_) => ()
      @resolver.Constrained(_, cs) =>
        for c in cs {
          match c {
            @resolver.ProtocolType(pname) => args.push(evidence_for(env, actual, pname))
            _ => ()
          }
        }
    }
  }
  args
}

fn method_access_to_core(
  env : ElabEnv,
  base : @checker.TypedExpr,
  owner : String,
  mname : String,
  access_ty : @resolver.ResolvedType,
) -> String raise {
  // Member access returns a receiver-capturing function value; the actual method
  // remains an ordinary function whose first argument is the explicit receiver.
  let base_s = expr_to_core(env, base)
  let receiver = method_receiver_name()
  let method_s = method_function_to_core_for_receiver(env, base, owner, mname)
  let receiver_ty = type_to_core(env, type_of_expr(base))
  let wrapped = match access_ty {
    @resolver.Function(tparams, params, _) => {
      let arg_names = method_arg_names(params)
      let with_types = apply_type_params(method_s, tparams)
      let with_dicts = apply_args(with_types, dict_param_args(tparams))
      let with_receiver = apply_args(with_dicts, [receiver])
      let body = apply_args(with_receiver, arg_names)
      let with_value_lambdas = lambda_param_sigs(params, body, env)
      lambda_type_params(tparams, with_value_lambdas, env)
    }
    _ => apply_args(method_s, [receiver])
  }
  apply_args("lambda \{receiver}:\{receiver_ty}. \{wrapped}", [base_s])
}

fn method_function_to_core_for_receiver(
  env : ElabEnv,
  base : @checker.TypedExpr,
  owner : String,
  mname : String,
) -> String {
  match type_of_expr(base) {
    @resolver.TypeVariable(tname) =>
      match lookup_constraint_dict(env, tname, owner) {
        Some(dname) => "\{dname}.\{mname}"
        None => method_function_to_core(env, owner, mname)
      }
    _ => method_function_to_core(env, owner, mname)
  }
}

fn method_function_to_core(
  env : ElabEnv,
  owner : String,
  mname : String,
) -> String {
  match lookup_ext_protocol(env, owner, mname) {
    Some(pname) => "\{dict_name(owner, pname)}.\{mname}"
    None => method_name(owner, mname)
  }
}

fn method_binding(
  env : ElabEnv,
  owner : String,
  name : String,
  tparams : Array[@resolver.ResolvedTypeParam],
  params : Array[@resolver.ResolvedParamDecl],
  body : Array[@checker.TypedStmt],
) -> String raise {
  "\{method_name(owner, name)} = \{function_to_core(env, tparams, params, body)};"
}

fn extension_dict_binding(
  env : ElabEnv,
  sname : String,
  pname : String,
  members : Array[@checker.TypedDecl],
) -> String raise {
  let fields = []
  for m in members {
    match m {
      @checker.MethodDef(mname, tps, params, _, body) =>
        fields.push("\{mname}=\{function_to_core(env, tps, params, body)}")
      _ => ()
    }
  }
  let dname = dict_name(sname, pname)
  let body = join(fields, ", ")
  "\{dname} = {\{body}};"
}

fn decl_to_commands(env : ElabEnv, decl : @checker.TypedDecl) -> Array[String] raise {
  let cmds = []
  match decl {
    @checker.Variable(name, _, init) => cmds.push("\{name} = \{expr_to_core(env, init)};")
    @checker.FunctionDef(name, tps, params, _, body) =>
      cmds.push("\{name} = \{function_to_core(env, tps, params, body)};")
    @checker.StructDef(sname, members) =>
      for m in members {
        match m {
          @checker.MethodDef(mname, tps, params, _, body) =>
            cmds.push(method_binding(env, sname, mname, tps, params, body))
          _ => ()
        }
      }
    @checker.Extension(sname, pname, members) =>
      cmds.push(extension_dict_binding(env, sname, pname, members))
    _ => ()
  }
  cmds
}

pub fn elaborate(program : @checker.TypedProgram) -> String raise {
  let env = collect_env(program)
  let cmds = []
  for stmt in program.stmts {
    match stmt {
      @checker.Expr(e) => cmds.push("\{expr_to_core(env, e)};")
      @checker.Decl(d) => {
        let decl_cmds = decl_to_commands(env, d)
        for cmd in decl_cmds {
          cmds.push(cmd)
        }
      }
    }
  }
  join(cmds, "\n")
}
