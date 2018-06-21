# nim-extensions
Extensions for the Nim programming language.

These extensions aim to improve the usability of Nim in practical applications.

Extensions so far include:

## OOP macro

  This module was modified from the OOP section on the excellent website http://nim-by-example.github.io/

  usage: 
  
  ```nim
  import extensions/oop
  class BaseObject: # inherits from RootObj
    # attributes/properties
    var
      x: int
      y: float
      
    method override_me(argx: float): int=
      result = int(argx) + self.x
      
  class ClassName of BaseObject:
      method method_name(arg1: int, arg2: float=0.3): float=
        ## do stuff here
        result = arg2
        
      method override_me(argx: float): int=
        result = int(self.y) + int(argx) + self.x
  ```

  There's also an example in the code that demonstrates the inheritance that can be run by executing:
  ```bash
  nim c -r tests/test1.nim
  ```
