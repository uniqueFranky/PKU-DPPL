pub suberror TypeError {
  TypeError(String)
}

fn fail[T](msg : String) -> T raise {
  raise TypeError(msg)
}

fn as_param_sig(param : @resolver.ResolvedParamDecl) -> @resolver.ResolvedParamSig {
  match param {
    @resolver.ParamDecl(label, _, ty) => @resolver.ResolvedParamSig::ParamSig(label, ty)
  }
}

fn get_expr_type(expr : TypedExpr) -> @resolver.ResolvedType {
  match expr {
    IntLit(_, ty) => ty
    BoolLit(_, ty) => ty
    StringLit(_, ty) => ty
    Self(ty) => ty
    Ident(_, _, ty) => ty
    Call(_, _, _, ty) => ty
    Construct(_, _, ty) => ty
    GenericInst(_, _, ty) => ty
    Access(_, _, _, ty) => ty
    IfElse(_, _, _, ty) => ty
    If(_, _, ty) => ty
    Function(_, _, _, _, ty) => ty
  }
}

fn lookup_in_pairs[T](xs : Array[(String, T)], key : String) -> T? {
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

fn contains(xs : Array[String], x : String) -> Bool {
  xs.any(fn(v) { v == x })
}

fn empty_resolved_types() -> Array[@resolver.ResolvedType] {
  []
}

fn empty_typed_decls() -> Array[TypedDecl] {
  []
}

fn empty_typed_stmts() -> Array[TypedStmt] {
  []
}

fn empty_param_sigs() -> Array[@resolver.ResolvedParamSig] {
  []
}

fn drop_first_param(params : Array[@resolver.ResolvedParamSig]) -> Array[@resolver.ResolvedParamSig] {
  loop (params, true, empty_param_sigs()) {
    ([], _, acc) => break acc
    ([p, ..rest], true, acc) => continue ([..rest], false, acc)
    ([p, ..rest], false, acc) => continue ([..rest], false, acc.add([p]))
  }
}

fn param_sigs_eq(
  ps1 : Array[@resolver.ResolvedParamSig],
  ps2 : Array[@resolver.ResolvedParamSig],
) -> Bool {
  if ps1.length() != ps2.length() {
    false
  } else {
    loop (ps1, ps2) {
      ([], []) => true
      ([p1, ..r1], [p2, ..r2]) => {
        let ok = match (p1, p2) {
          (@resolver.ParamSig(l1, t1), @resolver.ParamSig(l2, t2)) => l1 == l2 && type_eq(t1, t2)
        }
        if ok {
          continue ([..r1], [..r2])
        } else {
          false
        }
      }
      _ => false
    }
  }
}

fn type_params_eq(
  tps1 : Array[@resolver.ResolvedTypeParam],
  tps2 : Array[@resolver.ResolvedTypeParam],
) -> Bool {
  if tps1.length() != tps2.length() {
    false
  } else {
    loop (tps1, tps2) {
      ([], []) => true
      ([tp1, ..r1], [tp2, ..r2]) => {
        let ok = match (tp1, tp2) {
          (@resolver.Generic(_), @resolver.Generic(_)) => true
          (@resolver.Constrained(_, cs1), @resolver.Constrained(_, cs2)) =>
            if cs1.length() != cs2.length() {
              false
            } else {
              loop (cs1, cs2) {
                ([], []) => true
                ([c1, ..cr1], [c2, ..cr2]) =>
                  if type_eq(c1, c2) {
                    continue ([..cr1], [..cr2])
                  } else {
                    false
                  }
                _ => false
              }
            }
          _ => false
        }
        if ok {
          continue ([..r1], [..r2])
        } else {
          false
        }
      }
      _ => false
    }
  }
}

fn lookup_value(
  locals : Array[(String, @resolver.ResolvedType, SymbolBinding)],
  tops : Array[(String, @resolver.ResolvedType)],
  name : String,
) -> (SymbolBinding, @resolver.ResolvedType)? {
  let local_found = loop (locals) {
    [] => break None
    [(n, ty, bind), ..rest] =>
      if n == name {
        break Some((bind, ty))
      } else {
        continue ([..rest])
      }
  }
  match local_found {
    Some(_) => local_found
    None =>
      match lookup_in_pairs(tops, name) {
        Some(ty) => Some((TopLevelValue(name), ty))
        None => None
      }
  }
}

fn type_eq(a : @resolver.ResolvedType, b : @resolver.ResolvedType) -> Bool {
  match (a, b) {
    (@resolver.ResolvedType::Int, @resolver.ResolvedType::Int) => true
    (@resolver.ResolvedType::Bool, @resolver.ResolvedType::Bool) => true
    (@resolver.ResolvedType::String, @resolver.ResolvedType::String) => true
    (@resolver.ResolvedType::Unit, @resolver.ResolvedType::Unit) => true
    (@resolver.ResolvedType::StructType(x), @resolver.ResolvedType::StructType(y)) => x == y
    (@resolver.ResolvedType::ProtocolType(x), @resolver.ResolvedType::ProtocolType(y)) => x == y
    (@resolver.ResolvedType::TypeVariable(x), @resolver.ResolvedType::TypeVariable(y)) => x == y
    (@resolver.ResolvedType::AbstractSelfType(x), @resolver.ResolvedType::AbstractSelfType(y)) => x == y
    (@resolver.ResolvedType::Function(tps1, ps1, r1), @resolver.ResolvedType::Function(tps2, ps2, r2)) =>
      type_params_eq(tps1, tps2) && param_sigs_eq(ps1, ps2) && type_eq(r1, r2)
    _ => false
  }
}

fn substitute(ty : @resolver.ResolvedType, mapping : Array[(String, @resolver.ResolvedType)]) -> @resolver.ResolvedType {
  match ty {
    @resolver.ResolvedType::TypeVariable(name) =>
      match lookup_in_pairs(mapping, name) {
        Some(t) => t
        None => ty
      }
    @resolver.ResolvedType::Function(tparams, params, ret) =>
      @resolver.ResolvedType::Function(
        tparams,
        params.map(fn(p) {
          match p {
            @resolver.ParamSig(label, pty) =>
              @resolver.ResolvedParamSig::ParamSig(label, substitute(pty, mapping))
          }
        }),
        substitute(ret, mapping),
      )
    _ => ty
  }
}

priv struct StructInfo {
  fields : Array[(String, @resolver.ResolvedType)]
  methods : Array[(String, @resolver.ResolvedType)]
}

priv struct ProtocolInfo {
  methods : Array[(String, @resolver.ResolvedType)]
}

priv struct Env {
  top_values : Array[(String, @resolver.ResolvedType)]
  locals : Array[(String, @resolver.ResolvedType, SymbolBinding)]
  type_constraints : Array[(String, Array[@resolver.ResolvedType])]
  structs : Array[(String, StructInfo)]
  protocols : Array[(String, ProtocolInfo)]
  conformance : Array[(String, Array[String])]
  ext_methods : Array[(String, String, Array[(String, @resolver.ResolvedType)])]
}

fn env_add_local(env : Env, name : String, ty : @resolver.ResolvedType) -> Env {
  {
    top_values: env.top_values,
    locals: [(name, ty, LocalValue(name))].add(env.locals),
    type_constraints: env.type_constraints,
    structs: env.structs,
    protocols: env.protocols,
    conformance: env.conformance,
    ext_methods: env.ext_methods,
  }
}

fn env_add_type_params(env : Env, tparams : Array[@resolver.ResolvedTypeParam]) -> Env {
  let to_add = tparams.map(fn(tp) {
    match tp {
      @resolver.Generic(name) => (name, empty_resolved_types())
      @resolver.Constrained(name, cs) => (name, cs)
    }
  })
  {
    top_values: env.top_values,
    locals: env.locals,
    type_constraints: to_add.add(env.type_constraints),
    structs: env.structs,
    protocols: env.protocols,
    conformance: env.conformance,
    ext_methods: env.ext_methods,
  }
}

fn lookup_struct(env : Env, name : String) -> StructInfo? {
  lookup_in_pairs(env.structs, name)
}

fn lookup_protocol(env : Env, name : String) -> ProtocolInfo? {
  lookup_in_pairs(env.protocols, name)
}

fn lookup_method(methods : Array[(String, @resolver.ResolvedType)], name : String) -> @resolver.ResolvedType? {
  lookup_in_pairs(methods, name)
}

fn lookup_type_constraints(env : Env, name : String) -> Array[@resolver.ResolvedType] {
  match lookup_in_pairs(env.type_constraints, name) {
    Some(cs) => cs
    None => []
  }
}

fn has_conformance(env : Env, struct_name : String, protocol_name : String) -> Bool {
  match lookup_in_pairs(env.conformance, struct_name) {
    Some(ps) => contains(ps, protocol_name)
    None => false
  }
}

fn satisfies(env : Env, ty : @resolver.ResolvedType, req : @resolver.ResolvedType) -> Bool {
  if type_eq(ty, req) {
    true
  } else {
    match (ty, req) {
      (@resolver.StructType(s), @resolver.ProtocolType(p)) => has_conformance(env, s, p)
      (@resolver.TypeVariable(t), @resolver.ProtocolType(p)) =>
        lookup_type_constraints(env, t).any(fn(c) { type_eq(c, @resolver.ResolvedType::ProtocolType(p)) })
      _ => false
    }
  }
}

fn subst_protocol_self(
  ty : @resolver.ResolvedType,
  protocol_name : String,
  struct_name : String,
) -> @resolver.ResolvedType {
  match ty {
    @resolver.ResolvedType::AbstractSelfType(p) =>
      if p == protocol_name {
        @resolver.ResolvedType::StructType(struct_name)
      } else {
        ty
      }
    @resolver.ResolvedType::Function(tparams, params, ret) =>
      @resolver.ResolvedType::Function(
        tparams,
        params.map(fn(p) {
          match p {
            @resolver.ParamSig(label, pty) =>
              @resolver.ResolvedParamSig::ParamSig(
                label,
                subst_protocol_self(pty, protocol_name, struct_name),
              )
          }
        }),
        subst_protocol_self(ret, protocol_name, struct_name),
      )
    _ => ty
  }
}

fn build_env(program : @resolver.ResolvedProgram) -> Env {
  let structs = []
  let protocols = []
  let conformance = []
  let ext_methods = []
  let built = loop (program.stmts, structs, protocols, conformance, ext_methods) {
    ([], sacc, pacc, cacc, eacc) => break (sacc, pacc, cacc, eacc)
    ([stmt, ..rest], sacc, pacc, cacc, eacc) =>
      match stmt {
        @resolver.Decl(decl) =>
          match decl {
            @resolver.StructDef(name, members) => {
              let fields = members.filter_map(fn(m) {
                match m {
                  @resolver.Field(fname, fty) => Some((fname, fty))
                  _ => None
                }
              })
              let methods = members.filter_map(fn(m) {
                match m {
                  @resolver.MethodDef(mname, tps, ps, ret, _) =>
                    Some((mname, @resolver.ResolvedType::Function(tps, ps.map(fn(p) { as_param_sig(p) }), ret)))
                  @resolver.MethodDecl(@resolver.Sig(mname, tps, ps, ret)) =>
                    Some((mname, @resolver.ResolvedType::Function(tps, ps, ret)))
                  _ => None
                }
              })
              continue ([..rest], sacc.add([(name, { fields, methods })]), pacc, cacc, eacc)
            }
            @resolver.StructDecl(name) =>
              continue ([..rest], sacc.add([(name, { fields: [], methods: [] })]), pacc, cacc, eacc)
            @resolver.Protocol(name, members) => {
              let methods = members.filter_map(fn(m) {
                match m {
                  @resolver.MethodDef(mname, tps, ps, ret, _) =>
                    Some((mname, @resolver.ResolvedType::Function(tps, ps.map(fn(p) { as_param_sig(p) }), ret)))
                  @resolver.MethodDecl(@resolver.Sig(mname, tps, ps, ret)) =>
                    Some((mname, @resolver.ResolvedType::Function(tps, ps, ret)))
                  _ => None
                }
              })
              continue ([..rest], sacc, pacc.add([(name, { methods })]), cacc, eacc)
            }
            @resolver.Extension(sname, pname, members) => {
              let methods = members.filter_map(fn(m) {
                match m {
                  @resolver.MethodDef(mname, tps, ps, ret, _) =>
                    Some((mname, @resolver.ResolvedType::Function(tps, ps.map(fn(p) { as_param_sig(p) }), ret)))
                  @resolver.MethodDecl(@resolver.Sig(mname, tps, ps, ret)) =>
                    Some((mname, @resolver.ResolvedType::Function(tps, ps, ret)))
                  _ => None
                }
              })
              let old = match lookup_in_pairs(cacc, sname) {
                Some(ps) => ps
                None => []
              }
              let cacc2 = cacc.filter(fn(p) { p.0 != sname }).add([(sname, old.add([pname]))])
              continue ([..rest], sacc, pacc, cacc2, eacc.add([(sname, pname, methods)]))
            }
            _ => continue ([..rest], sacc, pacc, cacc, eacc)
          }
        _ => continue ([..rest], sacc, pacc, cacc, eacc)
      }
  }
  {
    top_values: program.top_types,
    locals: [],
    type_constraints: [],
    structs: built.0,
    protocols: built.1,
    conformance: built.2,
    ext_methods: built.3,
  }
}

fn check_protocol_conformance(env : Env) -> Unit raise {
  for ext in env.ext_methods {
    let (sname, pname, methods) = ext
    let pinfo = match lookup_protocol(env, pname) {
      Some(p) => p
      None => fail("undefined protocol in extension")
    }
    for req in pinfo.methods {
      match lookup_method(methods, req.0) {
        None => fail("type \"\{sname}\" does not implement protocol \"\{pname}\"")
        Some(sig) =>
          if not(
            type_eq(
              sig,
              subst_protocol_self(req.1, pname, sname),
            )
          ) {
            fail("extension method signature mismatch")
          }
      }
    }
  }
}

fn match_args(
  env : Env,
  args : Array[@resolver.ResolvedArgExpr],
  params : Array[@resolver.ResolvedParamSig],
) -> Array[TypedArgExpr] raise {
  let mut seen_named = false
  let mut pos_count = 0
  let used_names : Array[String] = []
  let typed = []
  for arg in args {
    match arg {
      @resolver.Positional(e) => {
        if seen_named {
          fail("positional arguments must come before labeled arguments")
        }
        if pos_count >= params.length() {
          fail("too many positional arguments")
        }
        let expected = match params[pos_count] {
          @resolver.ParamSig(label, ty) =>
            match label {
              Some(_) => fail("labeled parameter is missing explicit label")
              None => ty
            }
        }
        let te = check_expr(env, e)
        if not(type_eq(get_expr_type(te), expected)) {
          fail("argument type mismatch")
        }
        typed.push(TypedArgExpr::Positional(te))
        pos_count = pos_count + 1
      }
      @resolver.Named(label, e) => {
        seen_named = true
        if contains(used_names, label) {
          fail("duplicate labeled argument")
        }
        let expected = loop (params) {
          [] => break None
          [p, ..rest] =>
            match p {
              @resolver.ParamSig(Some(l), ty) if l == label => break Some(ty)
              _ => continue ([..rest])
            }
        }
        match expected {
          None => fail("unknown labeled argument")
          Some(ety) => {
            let te = check_expr(env, e)
            if not(type_eq(get_expr_type(te), ety)) {
              fail("argument type mismatch")
            }
            typed.push(TypedArgExpr::Named(label, te))
            used_names.push(label)
          }
        }
      }
    }
  }

  loop (params, 0) {
    ([], _) => ()
    ([p, ..rest], i) =>
      match p {
        @resolver.ParamSig(None, _) =>
          if i >= pos_count {
            fail("missing positional argument")
          } else {
            continue ([..rest], i + 1)
          }
        @resolver.ParamSig(Some(label), _) =>
          if contains(used_names, label) {
            continue ([..rest], i + 1)
          } else {
            fail("missing labeled argument")
          }
      }
  }
  typed
}

fn resolve_member(
  env : Env,
  base_ty : @resolver.ResolvedType,
  name : String,
) -> (@resolver.ResolvedType, MemberResolution)? raise {
  match base_ty {
    @resolver.StructType(sname) =>
      match lookup_struct(env, sname) {
        None => None
        Some(info) =>
          match lookup_in_pairs(info.fields, name) {
            Some(ty) => Some((ty, MemberResolution::Field(sname, name)))
            None =>
              match lookup_method(info.methods, name) {
                Some(mty) => Some((mty, MemberResolution::Method(sname, name)))
                None => {
                  let from_ext = loop (env.ext_methods) {
                    [] => break None
                    [(sn, _, methods), ..rest] =>
                      if sn == sname {
                        match lookup_method(methods, name) {
                          Some(mt) => break Some(mt)
                          None => continue ([..rest])
                        }
                      } else {
                        continue ([..rest])
                      }
                  }
                  match from_ext {
                    Some(mt) => Some((mt, MemberResolution::Method(sname, name)))
                    None => None
                  }
                }
              }
          }
      }
    @resolver.TypeVariable(tv) => {
      let constraints = lookup_type_constraints(env, tv)
      let candidates = constraints.filter_map(fn(c) {
        match c {
          @resolver.ProtocolType(pname) =>
            match lookup_protocol(env, pname) {
              None => None
              Some(pinfo) =>
                match lookup_method(pinfo.methods, name) {
                  Some(mt) => Some((mt, MemberResolution::Method(pname, name)))
                  None => None
                }
            }
          _ => None
        }
      })
      match candidates {
        [] => None
        [only] => Some(only)
        _ => {
          // If same method name appears in multiple constraints:
          // - duplicate full signatures are rejected
          // - different signatures are ambiguous and rejected
          for i = 0; i < candidates.length(); i = i + 1 {
            let ci = candidates[i]
            for j = i + 1; j < candidates.length(); j = j + 1 {
              let cj = candidates[j]
              if type_eq(ci.0, cj.0) {
                fail("duplicate constrained method \"\{name}\" with identical signature")
              }
            }
          }
          fail("ambiguous constrained method \"\{name}\" with multiple signatures")
        }
      }
    }
    _ => None
  }
}

fn check_expr(env : Env, expr : @resolver.ResolvedExpr) -> TypedExpr raise {
  match expr {
    @resolver.IntLit(i) => TypedExpr::IntLit(i, @resolver.ResolvedType::Int)
    @resolver.BoolLit(b) => TypedExpr::BoolLit(b, @resolver.ResolvedType::Bool)
    @resolver.StringLit(s) => TypedExpr::StringLit(s, @resolver.ResolvedType::String)
    @resolver.Self =>
      match lookup_value(env.locals, env.top_values, "self") {
        Some((_, ty)) => TypedExpr::Self(ty)
        None => fail("self is only valid inside methods")
      }
    @resolver.Ident(name) =>
      match lookup_value(env.locals, env.top_values, name) {
        Some((bind, ty)) => TypedExpr::Ident(name, bind, ty)
        None => fail("unbound identifier \"\{name}\"")
      }
    @resolver.GenericInst(base, tys) => {
      let tb = check_expr(env, base)
      match get_expr_type(tb) {
        @resolver.Function(tparams, params, ret) =>
          if tparams.length() != tys.length() {
            fail("generic argument count mismatch")
          } else {
            let mapping = tparams.zip(tys).map(fn(p) {
              match p.0 {
                @resolver.Generic(n) => (n, p.1)
                @resolver.Constrained(n, cs) => {
                  for c in cs {
                    if not(satisfies(env, p.1, substitute(c, tparams.zip(tys).map(fn(q) {
                      match q.0 {
                        @resolver.Generic(nn) => (nn, q.1)
                        @resolver.Constrained(nn, _) => (nn, q.1)
                      }
                    })))) {
                      fail("generic constraint not satisfied")
                    }
                  }
                  (n, p.1)
                }
              }
            })
            let iparams = params.map(fn(ps) {
              match ps {
                @resolver.ParamSig(label, pty) =>
                  @resolver.ResolvedParamSig::ParamSig(label, substitute(pty, mapping))
              }
            })
            let iret = substitute(ret, mapping)
            TypedExpr::GenericInst(tb, tys, @resolver.ResolvedType::Function([], iparams, iret))
          }
        _ => fail("generic instantiation target must be a function")
      }
    }
    @resolver.Call(callee, args) => {
      let tc = check_expr(env, callee)
      match get_expr_type(tc) {
        @resolver.Function(tps, params, ret) =>
          if tps.length() > 0 {
            fail("must explicitly instantiate generic function before call")
          } else {
            let typed_args = match_args(env, args, params)
            let cres = match tc {
              Access(_, _, MemberResolution::Method(owner, mname), _) =>
                CallResolution::MethodCall(owner, mname)
              Ident(name, _, _) => CallResolution::FunctionCall(name)
              _ => CallResolution::FunctionValueCall
            }
            TypedExpr::Call(tc, typed_args, cres, ret)
          }
        _ => fail("callee is not callable")
      }
    }
    @resolver.Construct(name, args) =>
      match lookup_struct(env, name) {
        None => fail("unknown struct")
        Some(info) => {
          let params = info.fields.map(fn(p) { @resolver.ResolvedParamSig::ParamSig(Some(p.0), p.1) })
          let typed_args = match_args(env, args, params)
          TypedExpr::Construct(name, typed_args, @resolver.ResolvedType::StructType(name))
        }
      }
    @resolver.Access(base, field_name) => {
      let tb = check_expr(env, base)
      match resolve_member(env, get_expr_type(tb), field_name) {
        None => fail("unknown member")
        Some((mty, mres)) =>
          match mres {
            MemberResolution::Field(_, _) => TypedExpr::Access(tb, field_name, mres, mty)
            MemberResolution::Method(_, _) =>
              match mty {
                @resolver.Function(tps, ps, ret) =>
                  if ps.length() == 0 {
                    fail("method signature missing self")
                  } else {
                    TypedExpr::Access(
                      tb,
                      field_name,
                      mres,
                      @resolver.ResolvedType::Function(
                        tps,
                        drop_first_param(ps),
                        ret,
                      ),
                    )
                  }
                _ => fail("invalid method type")
              }
          }
      }
    }
    @resolver.IfElse(cond, then_body, else_body) => {
      let tc = check_expr(env, cond)
      if not(type_eq(get_expr_type(tc), @resolver.ResolvedType::Bool)) {
        fail("if condition must be bool")
      }
      let (tthen, ty_then, _) = check_stmt_array(env, then_body)
      let (telse, ty_else, _) = check_stmt_array(env, else_body)
      if not(type_eq(ty_then, ty_else)) {
        fail("if branch type mismatch")
      }
      TypedExpr::IfElse(tc, tthen, telse, ty_then)
    }
    @resolver.If(cond, then_body) => {
      let tc = check_expr(env, cond)
      if not(type_eq(get_expr_type(tc), @resolver.ResolvedType::Bool)) {
        fail("if condition must be bool")
      }
      let (tthen, _, _) = check_stmt_array(env, then_body)
      TypedExpr::If(tc, tthen, @resolver.ResolvedType::Unit)
    }
    @resolver.Function(tparams, params, ret, body) => {
      let e1 = env_add_type_params(env, tparams)
      let e2 = loop (params, e1) {
        ([], cur) => break cur
        ([p, ..rest], cur) =>
          match p {
            @resolver.ParamDecl(_, pname, pty) =>
              continue ([..rest], env_add_local(cur, pname, pty))
          }
      }
      let (tbody, bty, _) = check_stmt_array(e2, body)
      if not(type_eq(bty, ret)) {
        fail("function body type mismatch")
      }
      TypedExpr::Function(
        tparams,
        params,
        ret,
        tbody,
        @resolver.ResolvedType::Function(tparams, params.map(fn(p) { as_param_sig(p) }), ret),
      )
    }
  }
}

fn check_decl(env : Env, decl : @resolver.ResolvedDecl) -> (TypedDecl, Env) raise {
  match decl {
    @resolver.Variable(name, ty, expr) => {
      let te = check_expr(env, expr)
      if not(type_eq(get_expr_type(te), ty)) {
        fail("variable type mismatch")
      }
      (TypedDecl::Variable(name, ty, te), env_add_local(env, name, ty))
    }
    @resolver.Field(name, ty) => (TypedDecl::Field(name, ty), env)
    @resolver.FunctionDef(name, tparams, params, ret, body) => {
      let e1 = env_add_type_params(env, tparams)
      let e2 = loop (params, e1) {
        ([], cur) => break cur
        ([p, ..rest], cur) =>
          match p {
            @resolver.ParamDecl(_, pname, pty) =>
              continue ([..rest], env_add_local(cur, pname, pty))
          }
      }
      let (tbody, bty, _) = check_stmt_array(e2, body)
      if not(type_eq(bty, ret)) {
        fail("function body type mismatch")
      }
      let fn_ty = @resolver.ResolvedType::Function(tparams, params.map(fn(p) { as_param_sig(p) }), ret)
      (TypedDecl::FunctionDef(name, tparams, params, ret, tbody), env_add_local(env, name, fn_ty))
    }
    @resolver.FunctionDecl(sig) => {
      let (name, tparams, params, ret) = match sig {
        @resolver.Sig(n, tps, ps, r) => (n, tps, ps, r)
      }
      let fn_ty = @resolver.ResolvedType::Function(tparams, params, ret)
      (TypedDecl::FunctionDecl(sig), env_add_local(env, name, fn_ty))
    }
    @resolver.MethodDef(name, tparams, params, ret, body) => {
      let e1 = env_add_type_params(env, tparams)
      let e2 = loop (params, e1) {
        ([], cur) => break cur
        ([p, ..rest], cur) =>
          match p {
            @resolver.ParamDecl(_, pname, pty) =>
              continue ([..rest], env_add_local(cur, pname, pty))
          }
      }
      let (tbody, bty, _) = check_stmt_array(e2, body)
      if not(type_eq(bty, ret)) {
        fail("method body type mismatch")
      }
      (TypedDecl::MethodDef(name, tparams, params, ret, tbody), env)
    }
    @resolver.MethodDecl(sig) => (TypedDecl::MethodDecl(sig), env)
    @resolver.StructDef(name, members) => {
      let (typed, _) = check_decl_array(env, members)
      (TypedDecl::StructDef(name, typed), env)
    }
    @resolver.StructDecl(name) => (TypedDecl::StructDecl(name), env)
    @resolver.Protocol(name, members) => {
      let (typed, _) = check_decl_array(env, members)
      (TypedDecl::Protocol(name, typed), env)
    }
    @resolver.Extension(sname, pname, members) => {
      let (typed, _) = check_decl_array(env, members)
      (TypedDecl::Extension(sname, pname, typed), env)
    }
  }
}

fn check_decl_array(env : Env, decls : Array[@resolver.ResolvedDecl]) -> (Array[TypedDecl], Env) raise {
  loop (decls, empty_typed_decls(), env) {
    ([], acc, cur) => break (acc, cur)
    ([d, ..rest], acc, cur) => {
      let (td, next) = check_decl(cur, d)
      continue ([..rest], acc.add([td]), next)
    }
  }
}

fn check_stmt_array(
  env : Env,
  stmts : Array[@resolver.ResolvedStmt],
) -> (Array[TypedStmt], @resolver.ResolvedType, Env) raise {
  loop (stmts, empty_typed_stmts(), env, @resolver.ResolvedType::Unit, false) {
    ([], acc, cur, ty, has_expr) =>
      if has_expr {
        break (acc, ty, cur)
      } else {
        break (acc, @resolver.ResolvedType::Unit, cur)
      }
    ([stmt, ..rest], acc, cur, ty, has_expr) =>
      match stmt {
        @resolver.Expr(e) => {
          let te = check_expr(cur, e)
          continue ([..rest], acc.add([TypedStmt::Expr(te)]), cur, get_expr_type(te), true)
        }
        @resolver.Decl(d) => {
          let (td, next) = check_decl(cur, d)
          continue ([..rest], acc.add([TypedStmt::Decl(td)]), next, ty, has_expr)
        }
      }
  }
}

pub fn check(program : @resolver.ResolvedProgram) -> TypedProgram raise {
  let env = build_env(program)
  check_protocol_conformance(env)
  let (typed, _, _) = check_stmt_array(env, program.stmts)
  { stmts: typed, top_types: program.top_types }
}
