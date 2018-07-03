import macros, strutils

proc `[]=`*(node: NimNode, nodePath: string, value: NimNode) =
  ## Set a NimNode based on a string search path like "StmtList > Command > Sym"
  let nodeNames = nodePath.replace(" ", "").split(">")

  let targetIndex = len(nodeNames) - 1

  var
    index = -1
    targetParent: NimNode
    stack: seq[seq[NimNode]] = @[@[node]]
    indexList: seq[int] = newSeq[int](len(nodeNames))


  while stack.len() > 0 and index < targetIndex:
    let parentList = stack.pop()
    var newParents: seq[NimNode] = @[]

    block WhileBlock:
      for parent in parentList:
        inc index
        for chIndex, child in parent.pairs:
          let kindStr = ($child.kind)[3..^1]

          var tryParse = -1
          try:
            tryParse = nodeNames[index].parseInt
          except ValueError:
            discard

          if kindStr == nodeNames[index] or tryParse == chIndex:
            targetParent = parent
            newParents.add(child)
            indexList[index] = chIndex

            if index == targetIndex:
              break WhileBlock

    if newParents.len() > 0:
      stack.add(newParents)

  if index == targetIndex:
    let modIndex = indexList.pop()
    var curNode = node
    for i in indexList:
      curNode = curNode[i]

    curNode[modIndex] = value


proc `[]`*(node: NimNode, nodePath: string): NimNode =
  ## Get a NimNode based on a string search path like "StmtList > Command > Sym"
  let nodeNames = nodePath.replace(" ", "").split(">")

  let targetIndex = len(nodeNames) - 1

  var
    index = -1
    stack: seq[seq[NimNode]] = @[@[node]]

  while stack.len() > 0 and index < targetIndex:
    let parentList = stack.pop()
    var newParents: seq[NimNode] = @[]

    block WhileBlock:
      for parent in parentList:
        inc index
        for i, child in parent.pairs:
          let kindStr = ($child.kind)[3..^1]

          var tryParse = -1
          try:
            tryParse = nodeNames[index].parseInt
          except ValueError:
            discard

          if kindStr == nodeNames[index] or tryParse == i:
            result = child
            newParents.add(child)
            if index == targetIndex:
              break WhileBlock

    if newParents.len() > 0:
      stack.add(newParents)
