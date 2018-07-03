import macros
import extensions/nimnode

proc argsMatch(impl, args: NimNode): bool =
  var implArgs = impl["FormalParams"]
  result = true
  for i, arg in args.pairs:
    let implIndex = i + 1 # skip the return type
    let symType = arg.getType()
    let implType = implArgs[implIndex][1]
    result = result and ($symType == $implType)

macro enumerate*(iter: typed, args: varargs[typed]): untyped =
  ## Takes in an i
  var iterDef: NimNode

  if len(iter) > 1:
    # If there are multiple syms to choose from,
    # choose the one with matching args
    for c in iter:
      let impl = c.getImpl().copy()
      if argsMatch(impl, args):
        iterDef = impl
  else:
    iterDef = iter.getImpl().copy()

  # set the symbol to empty because
  # we don't need it
  iterDef["Sym"] = newEmptyNode()

  # remove all stmts, we only want the def
  # for now
  iterDef["StmtList"] = newEmptyNode()

  # remove pragma
  iterDef["Pragma"] = newEmptyNode()

  var
    returnType = iterDef["FormalParams > 0"]
    iterCall = newNimNode(nnkCall).add(iter.copy())

  for child in iterDef[3].children:
    if child.kind == nnkIdentDefs:
      iterCall.add(child[0].copy())

  # mod the return type to return both int and original type
  iterDef["FormalParams > 0"] = newNimNode(nnkPar).add(ident"int", returnType)
  #iterDef[3][0] = newNimNode(nnkPar).add(ident"int", returnType)

  template iterBody(iterCall) =
    var i = 0
    for tup in iterCall:
      # Since Nim's checker won't allow a yield statement here,
      # we need to get creative
      replace(i, tup)
      inc i

  var stmtList = getAst(iterBody(iterCall))

  var replaceCall = stmtList["ForStmt > StmtList > Call"]

  var yieldStmt = nnkYieldStmt.newTree(
    nnkPar.newTree(
      replaceCall[1],
      replaceCall[2]
    )
  )

  stmtList["ForStmt > StmtList > Call"] = yieldStmt
  iterDef[^1] = stmtList

  # Call the iterator surrounded by parens
  result = nnkCall.newTree(nnkPar.newTree(iterDef))
  for arg in args:
    result.add(arg)
