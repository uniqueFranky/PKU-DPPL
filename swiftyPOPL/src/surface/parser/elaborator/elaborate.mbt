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
    @checker.Call(_, _, _, ty) => ty
    @checker.Construct(_, _, ty) => ty
    @checker.GenericInst(_, _, ty) => ty
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
    @resolver.TypeVariable(name) => name
    @resolver.AbstractSelfType(name) => name
    @resolver.Function(tparams, params, ret) => {
      let base = arrow_type(
        params.map(fn(p) { param_sig_type(p) }),
        ret,
        env,
      )
      wrap_foralls(tparams, base)
    }
  }
}

fn arrow_type(
  params : Array[@resolver.ResolvedType],
  ret : @resolver.ResolvedType,
  env : ElabEnv,
) -> String raise {
  let ret_s = type_to_core(env, ret)
  loop (params.rev(), ret_s) {
    ([], acc) => break acc
    ([p, ..rest], acc) => continue ([..rest], "\{type_to_core(env, p)} -> \{acc}")
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

fn dict_type(env : ElabEnv, protocol_name : String, self_ty : @resolver.ResolvedType) -> String raise {
  let methods = match lookup_protocol(env, protocol_name) {
    None => fail("unknown protocol \{protocol_name}")
    Some(ms) => ms
  }
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
  loop (params.rev(), body) {
    ([], acc) => break acc
    ([p, ..rest], acc) =>
      continue (
        [..rest],
        "lambda \{param_name(p)}:\{type_to_core(env, param_type(p))}. \{acc}",
      )
  }
}

fn lambda_type_params(
  tparams : Array[@resolver.ResolvedTypeParam],
  body : String,
  env : ElabEnv,
) -> String raise {
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

fn expr_to_core(env : ElabEnv, expr : @checker.TypedExpr) -> String raise {
  match expr {
    @checker.IntLit(i, _) => i.to_string()
    @checker.BoolLit(b, _) => if b { "true" } else { "false" }
    @checker.StringLit(s, _) => string_lit(s)
    @checker.Self(_) => "self"
    @checker.Ident(name, _, _) => name
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
    @checker.Access(base, mname, @checker.Method(owner, _), _) =>
      method_access_to_core(env, base, owner, mname)
    @checker.GenericInst(base, tys, _) => {
      let (base_s, receiver_arg) = match base {
        @checker.Access(recv, mname, @checker.Method(owner, _), _) =>
          (method_function_to_core(env, owner, mname), Some(expr_to_core(env, recv)))
        _ => (expr_to_core(env, base), None)
      }
      let applied_types = loop (tys, base_s) {
        ([], acc) => break acc
        ([ty, ..rest], acc) => continue ([..rest], "\{paren(acc)} [\{type_to_core(env, ty)}]")
      }
      match type_of_expr(base) {
        @resolver.Function(tparams, _, _) => {
          let dicts = generic_evidence_args(env, tparams, tys)
          let with_dicts = apply_args(applied_types, dicts)
          match receiver_arg {
            None => with_dicts
            Some(recv) => apply_args(with_dicts, [recv])
          }
        }
        _ =>
          match receiver_arg {
            None => applied_types
            Some(recv) => apply_args(applied_types, [recv])
          }
      }
    }
    @checker.Call(callee, args, @checker.MethodCall(owner, mname), _) => {
      match callee {
        @checker.Access(base, _, _, _) => {
          let fn_s = method_access_to_core(env, base, owner, mname)
          apply_args(fn_s, typed_args_to_core(env, args))
        }
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
) -> String raise {
  let base_s = expr_to_core(env, base)
  apply_args(method_function_to_core(env, owner, mname), [base_s])
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
