# nim-extensions
Extensions for the nim programming language.

These extensions aim to improve the usability of nim in practical applications.

Extensions so far include:

## OOP macro
  usage: 
  
  ```nim
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
