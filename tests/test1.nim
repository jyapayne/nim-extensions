import extensions/oop_macro

import strutils

var
  output = ""

class Animal of RootObj:
  var
    name: string
    age: int


  method init*(name: string, age: int){.base.}=
    self.name = name
    self.age = age
    output &= "I am a new Animal, " & self.name & "\n"
  method stuff(s:string): string {.base.}= s
  method vocalize: string {.base.}= "..."
  method ageHumanYrs: int {.base.}= self.age # `self` is injected

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
    output &= "I am a new tiger" & "\n"
  method vocalize: string =
    # no need for super.super!
    self.vocalizeAnimal() & "Rawr!"

var animals: seq[Animal] = @[]
animals.add(new Dog(name: "Sparky", age: 10))
animals.add(new Cat(name: "Mitten", age: 10))
animals.add(new Tiger(name: "Jean", age: 2))


for a in animals:
  output &= a.name & " says " & a.vocalize()&"\n"
  output &= $a.ageHumanYrs() & "\n"

var check = """
I am a new Animal, Sparky
I am a new Animal, Mitten
I am a new Animal, Jean
I am a new tiger
Sparky says woof
70
Mitten says ...meow
10
Jean says ...Rawr!
2
"""[0 .. ^1]
echo "####"
echo check
echo "####"
echo output
echo "####"
doAssert(output==check,"""echo matches""")
