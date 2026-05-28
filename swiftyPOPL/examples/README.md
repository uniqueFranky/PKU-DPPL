# SwiftyPOPL examples

Each example is a complete SwiftyPOPL program that can be run with:

```bash
moon run src -- examples/<file>.swift
```

- `table_view_delegate.swift`: uses `any TableViewDelegate` to model a Table View-style delegate object.
- `table_view_height_delegate.swift`: uses an existential delegate for row-height callbacks.
- `existential_callback_delegate.swift`: uses an existential callback object returning `Bool`.
- `ios_settings_screen.swift`: models an iOS Settings screen with existential delegates, constrained generics, and a polymorphic function field.
- `first_class_polymorphic_identity.swift`: stores a polymorphic function in a top-level value.
- `first_class_polymorphic_struct_field.swift`: stores a polymorphic function in a struct field.
- `constrained_polymorphic_protocol.swift`: uses a constrained generic function and dictionary passing.

The examples avoid features outside the current formalized fragment: user-defined recursion, string concatenation, generic method calls on existential packages, and explicit existential unpack.
