import macros

macro ImportExport*(names: expr): stmt {.immediate.} =
  proc importStmt(fullName: NimNode, lastName: NimNode): NimNode =
    result = newNimNode(nnkImportStmt)
    var infix = newNimNode(nnkInfix)
    infix.add(ident("as"))
    infix.add(fullName)
    infix.add(lastName)
    result.add(infix)
  proc exportStmt(name: NimNode): NimNode =
    result = newNimNode(nnkExportStmt)
    result.add(name)
  result = newStmtList()
  for name in names.children:
    var ident = name[1]
    result.add(importStmt(name, ident))
    result.add(exportStmt(ident))
