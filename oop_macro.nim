import macros
import strutils

{.hint[XDeclaredButNotUsed]: off.}

macro new*(obj: untyped): untyped=
    ## Creates a new instance of the class
    ## and calls the init() method on it
    if obj.kind == nnkObjConstr:
        # Only if the node is an object constructor
        template init_object(obj)=
            var init_obj = obj
            when compiles(init_obj.init()):
                init_obj.init()
            init_obj
        result = getAst(init_object(obj))
    else:
        # Otherwise, just revert to system.new
        template init_object(obj)=
            var init_obj = obj
            system.new(init_obj)

        result = getAst(init_object(obj))


macro class*(head: untyped, body: untyped): untyped=
  # The macro is immediate so that it doesn't
  # resolve identifiers passed to it

  # object reference name inside methods.
  # ie: self, self
  let obj_reference = "self"
  var export_class: bool = false # whether or not to export the class to other modules

  var typeName, baseName: NimNode

  if head.kind == nnkIdent:
    # `head` is expression `typeName`
    # echo head.treeRepr
    # --------------------
    # Ident !"Animal"
    typeName = head

  elif head.kind == nnkInfix and $head[0] == "of":
    # `head` is expression `typeName of baseClass`
    # echo head.treeRepr
    # --------------------
    # Infix
    #   Ident !"of"
    #   Ident !"Animal"
    #   Ident !"RootObj"
    typeName = head[1]
    baseName = head[2]

  elif head.kind == nnkInfix and $head[0] == "*" and $head[1] == "of":
      # echo head.treeRepr
      # -----------
      # Infix
      #  Ident !"*"
      #  Ident !"Animal"
      #  Prefix
      #    Ident !"of"
      #    Ident !"RootObj"
      export_class = true
      typeName = head[1]
      baseName = head[2][1]
  elif head.kind == nnkInfix and $head[0] == "*":
      export_class = true
      typeName = head[1]
  else:
    quit "Invalid node: " & head.lispRepr

  # echo treeRepr(body)
  # --------------------
  # StmtList
  #   VarSection
  #     IdentDefs
  #       Ident !"name"
  #       Ident !"string"
  #       Empty
  #     IdentDefs
  #       Ident !"age"
  #       Ident !"int"
  #       Empty
  #   MethodDef
  #     Ident !"vocalize"
  #     Empty
  #     Empty
  #     FormalParams
  #       Ident !"string"
  #     Empty
  #     Empty
  #     StmtList
  #       StrLit ...
  #   MethodDef
  #     Ident !"age_human_yrs"
  #     Empty
  #     Empty
  #     FormalParams
  #       Ident !"int"
  #     Empty
  #     Empty
  #     StmtList
  #       DotExpr
  #         Ident !"self"
  #         Ident !"age"

  # create a new stmtList for the result
  result = newStmtList()

  # var declarations will be turned into object fields
  var recList = newNimNode(nnkRecList)

  # add a super function to simulate OOP
  # inheritance tree (Doesn't do what is expected because of dynamic binding)
  #if not isNil(`baseName`):
  #    var super = quote do:
  #        proc super(self: `typeName`): `baseName`=
  #          return `baseName`(self)
  #   result.add(super)

  # Make forward declarations so that function order
  # does not matter, just like in real OOP!
  for node in body.children:
    case node.kind:
      of nnkMethodDef, nnkProcDef:
        # inject `self: T` into the arguments
        let n = copyNimTree(node)
        n.params.insert(1, newIdentDefs(ident(obj_reference), typeName))
        # clear the body so we only get a
        # declaration
        n.body = newEmptyNode()
        result.add(n)

        # forward declare the inheritable method
        let n2 = copyNimTree(n)
        let type_name = $(typeName.toStrLit())
        var proc_name = ""

        if n2.name.kind == nnkIdent:
            proc_name = $(n2.name.toStrLit())
            n2.name = ident(proc_name & type_name)
        elif n2.name.kind == nnkPostFix:
            if n2.name[1].kind == nnkIdent:
                proc_name = $(n2.name[1].toStrLit())
                n2.name[1] = ident(proc_name & type_name)
            elif n2.name[1].kind == nnkAccQuoted:
                proc_name = $(n2.name[1][0].toStrLit())
                n2.name[1][0] = ident(proc_name & type_name)
        elif n2.name.kind == nnkAccQuoted:
            proc_name = $(n2.name[0].toStrLit())
            n2.name[0] = ident(proc_name & type_name)
        result.add(n2)
      else:
          discard

  # Iterate over the statements, adding `self: T`
  # to the parameters of functions
  for node in body.children:
    case node.kind:
      of nnkMethodDef, nnkProcDef:
        # inject `self: T` into the arguments
        let n = copyNimTree(node)
        n.params.insert(1, newIdentDefs(ident(obj_reference), typeName))

        # Copy the proc or method for inheritance
        # ie: procName_ClassName()
        let n2 = copyNimTree(node)
        n2.params.insert(1, newIdentDefs(ident(obj_reference), typeName))

        let type_name = $(typeName.toStrLit())
        var proc_name = $(n2.name.toStrLit())
        var is_assignment = proc_name.contains("=")

        if n2.name.kind == nnkIdent:
            proc_name = $(n2.name.toStrLit())
            n2.name = ident(proc_name & type_name)
        elif n2.name.kind == nnkPostFix:
            if n2.name[1].kind == nnkIdent:
                proc_name = $(n2.name[1].toStrLit())
                n2.name[1] = ident(proc_name & type_name)
            elif n2.name[1].kind == nnkAccQuoted:
                proc_name = $(n2.name[1][0].toStrLit())
                n2.name[1][0] = ident(proc_name & type_name)
        elif n2.name.kind == nnkAccQuoted:
            proc_name = $(n2.name[0].toStrLit())
            n2.name[0] = ident(proc_name & type_name)

        result.add(n2)

        # simply call the class method from here
        # proc procName=
        #    procName_ClassName()
        var p: seq[NimNode] = @[]
        for i in 1..n.params.len-1:
            p.add(n.params[i][0])
        if is_assignment:
            let dot = newDotExpr(ident(obj_reference), ident(proc_name & type_name))
            n.body = newStmtList(newAssignment(dot, p[1]))
        else:
            n.body = newStmtList(newCall(proc_name & type_name, p))

        result.add(n)

      of nnkVarSection:
        # variables get turned into fields of the type.
        for n in node.children:
          recList.add(n)
      else:
        result.add(node)

  # The following prints out the AST structure:
  #
  # import macros
  # dumptree:
  #   type X = ref object of Y
  #     z: int
  # --------------------
  # TypeSection
  #   TypeDef
  #     Ident !"X"
  #     Empty
  #     RefTy
  #       ObjectTy
  #         Empty
  #         OfInherit
  #           Ident !"Y"
  #         RecList
  #           IdentDefs
  #             Ident !"z"
  #             Ident !"int"
  #             Empty

  var type_decl: NimNode

  template declare_type_export(tname, bname)=
      type tname* = ref object of bname
  template declare_type(tname, bname)=
      type tname = ref object of bname

  if baseName == nil:
    if export_class:
        type_decl = getAst(declare_type_export(typeName, RootObj))
    else:
        type_decl = getAst(declare_type(typeName, RootObj))
  else:
      if export_class:
        type_decl = getAst(declare_type_export(typeName, baseName))
      else:
        type_decl = getAst(declare_type(typeName, baseName))

  # Inspect the tree structure:
  #
  # echo type_decl.treeRepr
  # --------------------
  #   StmtList
  #     TypeSection
  #       TypeDef
  #         Ident !"Animal"
  #         Empty
  #         RefTy
  #           ObjectTy
  #             Empty
  #             OfInherit
  #               Ident !"RootObj"
  #             Empty   <= We want to replace self
  type_decl[0][0][2][0][2] = recList
  result.insert(0, type_decl)


class Animal* of RootObj: #exports the class. Need to use RootObj for exports
  var name: string
  var age: int
  method stuff(s:string): string = s
  method vocalize: string = "..."
  method age_human_yrs: int = self.age # `self` is injected

class Dog of Animal:
  method vocalize: string = "woof"
  method age_human_yrs: int = self.age * 7

class Cat of Animal:
  method vocalize: string =
      # call the base class method
      self.vocalize_animal() & "meow"

class Tiger of Cat:
  method init()=
      echo "I am a new tiger"
  method vocalize: string =
      # no need for super.super!
      self.vocalize_animal() & "Rawr!" & self.vocalize_cat()

if isMainModule:
    var animals: seq[Animal] = @[]
    animals.add(new Dog(name: "Sparky", age: 10))
    animals.add(new Cat(name: "Mitten", age: 10))
    animals.add(new Tiger(name: "Jean", age: 2))

    for a in animals:
      echo a.name, " says ", a.vocalize()
      echo a.age_human_yrs()

    # prints:
    #   I am a new tiger
    #   Sparky says woof
    #   70
    #   Mitten says ...meow
    #   10
    #   Jean says ...Rawr!...meow
    #   2
