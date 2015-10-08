import macros
import strutils

{.hint[XDeclaredButNotUsed]: off.}

macro new*(obj: untyped): untyped {.immediate.}=
  if obj.kind == nnkObjConstr or obj.kind == nnkCall:
    var args: seq[NimNode] = @[]
    var newObj = copyNimTree(obj)

    # delete the parameters from the object
    # since we are going to use init() instead
    newObj.del(1, len(newObj)-1)

    # create a symbol that we can use
    var sym = genSym(nskVar, "initObj")

    # self = initObj
    var selfEq = newNimNode(nnkExprEqExpr).add(ident"self", sym)

    args.add(selfEq)

    for ch in obj.children:
      if ch.kind == nnkExprColonExpr:
        # someArg = someVal
        args.add(newNimNode(nnkExprEqExpr).add(ch[0], ch[1]))

    # init(self=initObj, someArg=someval, ...)
    var initCall = newCall(ident"init", args)

    template newObject(symbol, objNode, initFunc)=
      var symbol = objNode
      when compiles(initFunc):
        initFunc
      symbol

    result = getAst(newObject(sym, newObj, initCall))
  else:
    # otherwise, just call system.new on the object
    # since we don't care about it
    template newObject(obj)=
      var initObj = obj
      system.new(initObj)
    result = getAst(newObject(obj))


macro class*(head: untyped, body: untyped): untyped =
  
  # object reference name inside methods.
  # ie: self, self
  let objReference = "self"
  var exportClass: bool = false

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
    # Ident !"of"
    # Ident !"Animal"
    # Ident !"RootObj"
    typeName = head[1]
    baseName = head[2]

  elif head.kind == nnkInfix and $head[0] == "*" and $head[1] == "of":
    # echo head.treeRepr
    # -----------
    # Infix
    #  Ident !"*"
    #  Ident !"Animal
    #  Prefix
    #  Ident !"of"
    #  Ident !"RootObj"
    exportClass = true
    typeName = head[1]
    baseName = head[2][1]
  elif head.kind == nnkInfix and $head[0] == "*":
    exportClass = true
    typeName = head[1]
  else:
    quit "Invalid node: " & head.lispRepr

  # echo treeRepr(body)
  # --------------------
  # StmtList
  # VarSection
  #   IdentDefs
  #     Ident !"name"
  #     Ident !"string"
  #     Empty
  #   IdentDefs
  #     Ident !"age"
  #     Ident !"int"
  #     Empty
  # MethodDef
  #   Ident !"vocalize"
  #   Empty
  #   Empty
  #   FormalParams
  #     Ident !"string"
  #   Empty
  #   Empty
  #   StmtList
  #     StrLit ...
  # MethodDef
  #   Ident !"ageHumanYrs"
  #   Empty
  #   Empty
  #   FormalParams
  #     Ident !"int"
  #   Empty
  #   Empty
  #   StmtList
  #     DotExpr
  #       Ident !"self"
  #       Ident !"age"

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

  template setNodeName(n2, procName, typeName)=
    if n2.name.kind == nnkIdent:
      procName = $(n2.name.toStrLit())
      n2.name = ident(procName & typeName)
    elif n2.name.kind == nnkPostFix:
      if n2.name[1].kind == nnkIdent:
        procName = $(n2.name[1].toStrLit())
        n2.name[1] = ident(procName & typeName)
      elif n2.name[1].kind == nnkAccQuoted:
        procName = $(n2.name[1][0].toStrLit())
        n2.name[1][0] = ident(procName & typeName)
    elif n2.name.kind == nnkAccQuoted:
      procName = $(n2.name[0].toStrLit())
      n2.name[0] = ident(procName & typeName)
    result.add(n2)

  # Make forward declarations so that function order
  # does not matter, just like in real OOP!
  for node in body.children:
    case node.kind:
      of nnkMethodDef, nnkProcDef:
        # inject `self: T` into the arguments
        let n = copyNimTree(node)
        n.params.insert(1, newIdentDefs(ident(objReference), typeName))
        # clear the body so we only get a
        # declaration
        n.body = newEmptyNode()
        result.add(n)

        # forward declare the inheritable method
        let n2 = copyNimTree(n)
        let typeName = $(typeName.toStrLit())
        var procName = ""

        setNodeName(n2, procName, typeName)
        # add the base pragma when it's a base method
        if node.kind == nnkMethodDef:
          n2[4] = newNimNode(nnkPragma).add(ident"base")
      else:
        discard

  var numRes = result.len()
  # Iterate over the statements, adding `self: T`
  # to the parameters of functions
  for node in body.children:
    case node.kind:
      of nnkMethodDef, nnkProcDef:
        # inject `self: T` into the arguments
        let n = copyNimTree(node)
        # clear pragma since we forward declared already
        n[4] = newEmptyNode()
        n.params.insert(1, newIdentDefs(ident(objReference), typeName))

        # Copy the proc or method for inheritance
        # ie: procName_ClassName()
        let n2 = copyNimTree(node)

        # clear pragma since we forward declared already
        n2[4] = newEmptyNode()
        n2.params.insert(1, newIdentDefs(ident(objReference), typeName))

        let typeName = $(typeName.toStrLit())
        var procName = $(n2.name.toStrLit())
        var isAssignment = procName.contains("=")

        setNodeName(n2, procName, typeName)

        # simply call the class method from here
        # proc procName=
        #    procName_ClassName()
        var p: seq[NimNode] = @[]
        for i in 1..n.params.len-1:
          p.add(n.params[i][0])
        if isAssignment:
          let dot = newDotExpr(ident(objReference), ident(procName & typeName))
          n.body = newStmtList(newAssignment(dot, p[1]))
        else:
          n.body = newStmtList(newCall(procName & typeName, p))

        result.add(n)

      of nnkIteratorDef, nnkConverterDef, nnkMacroDef, nnkTemplateDef:
        # inject `self: T` into the arguments
        let n = copyNimTree(node)
        echo n.treeRepr
        n[3].insert(1, newIdentDefs(ident(objReference), typeName))
        result.insert(numRes, n)
        numRes += 1

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
  # type X = ref object of Y
  #   z: int
  # --------------------
  # TypeSection
  # TypeDef
  #   Ident !"X"
  #   Empty
  #   RefTy
  #     ObjectTy
  #       Empty
  #       OfInherit
  #         Ident !"Y"
  #       RecList
  #         IdentDefs
  #           Ident !"z"
  #           Ident !"int"
  #           Empty

  var typeDecl: NimNode

  template declareTypeExport(tname, bname)=
    type tname* = ref object of bname
  template declareType(tname, bname)=
    type tname = ref object of bname

  if baseName == nil:
    if exportClass:
      typeDecl = getAst(declareTypeExport(typeName, RootObj))
    else:
      typeDecl = getAst(declareType(typeName, RootObj))
  else:
    if exportClass:
      typeDecl = getAst(declareTypeExport(typeName, baseName))
    else:
      typeDecl = getAst(declareType(typeName, baseName))

  # Inspect the tree structure:
  #
  # echo typeDecl.treeRepr
  # --------------------
  # StmtList
  #   TypeSection
  #     TypeDef
  #       Ident !"Animal"
  #       Empty
  #       RefTy
  #         ObjectTy
  #           Empty
  #           OfInherit
  #             Ident !"RootObj"
  #           Empty   <= We want to replace self
  typeDecl[0][0][2][0][2] = recList
  result.insert(0, typeDecl)
  echo result.toStrLit()

when isMainModule:
  class Animal of RootObj:
    var
      name: string
      age: int

    method init*(name: string, age: int)=
      self.name = name
      self.age = age
      echo "I am a new Animal, ", self.name

    method stuff(s:string): string = s
    method vocalize: string = "..."
    method ageHumanYrs: int = self.age # `self` is injected

  class Dog of Animal:
    method vocalize: string = "woof"
    method ageHumanYrs: int = self.age * 7

  class Cat of Animal:
    method vocalize: string =
      # call the base class method
      self.vocalizeAnimal() & "meow"

  class Tiger of Cat:
    method init(name: string="Bob", age: int)=
      self.initAnimal(name, age)
      echo "I am a new tiger"
    method vocalize: string =
      # no need for super.super!
      self.vocalizeAnimal() & "Rawr!"

  var animals: seq[Animal] = @[]
  animals.add(new Dog(name: "Sparky", age: 10))
  animals.add(new Cat(name: "Mitten", age: 10))
  animals.add(new Tiger(name: "Jean", age: 2))

  for a in animals:
    echo a.name, " says ", a.vocalize()
    echo a.ageHumanYrs()

  # prints:
  #   I am a new Animal, Sparky
  #   I am a new Animal, Mitten
  #   I am a new Animal, Jean
  #   I am a new tiger
  #   Sparky says woof
  #   70
  #   Mitten says ...meow
  #   10
  #   Jean says ...Rawr!
  #   2
