type
  Message* = object of RootObj
    handled*: bool
  Messenger* = object
    messages*: seq[Message]
    

