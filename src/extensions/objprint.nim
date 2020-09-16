import strutils
import typetraits

proc typeToStr[T](some: typedesc[T]): string = name(T)

template tupleObjToStr(obj): string =
  mixin typeToStr
  var res = typeToStr(type(obj))
  template helper(n) {.gensym.} =
    res.add("(")
    var firstElement = true
    for name, value in n.fieldPairs():
      when compiles(value):
        if not firstElement:
          res.add(", ")
        res.add(name)
        res.add(": ")
        when (value is object or value is tuple):
          when (value is tuple):
            res.add("tuple " & typeToStr(type(value)))
          else:
            res.add(typeToStr(type(value)))
          helper(value)
        elif (value is string):
          res.add("\"" & $value & "\"")
        else:
          res.add($value)
        firstElement = false
    res.add(")")
  helper(obj)
  res

proc `$`*(s: object): string =
  result = tupleObjToStr(s).replace(":ObjectType", "")

proc `$`*(s: ref object): string =
  result = "ref " & $s[]

proc `$`*(s: tuple): string =
  result = tupleObjToStr(s)
