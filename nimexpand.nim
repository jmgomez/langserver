import std/[strutils]
import regex
import chronos, chronos/asyncproc
import stew/[byteutils]
import chronicles
import protocol/types
import utils
import suggestapi
import std/[strscans, strformat]


proc extractMacroExpansion*(output: string, targetLine: int): string =
  var start = false
  # Split on both \n and \r\n
  for line in output.split({'\n', '\r'}):
    if line.len == 0: continue
    debug "extractMacroExpansion", line = line, condMet = &".nim({targetLine}," in line
    if &".nim({targetLine}," in line:
      start = true
    elif &".nim" in line and start:
      break
    if start:
      result.add line & "\n"
    
  # Clean up the result
  if result.len > 0:
    let macroStart = result.find("macro: ")
    if macroStart != -1:
      result = result.substr(macroStart + "macro: ".len)
      result = result.replace("[ExpandMacro]", "")

proc nimExpandMacro*(nimPath: string, suggest: Suggest, filePath: string): Future[string] {.async.} =
  let 
    macroName = suggest.qualifiedPath[suggest.qualifiedPath.len - 1]
    line = suggest.line
  debug "nimExpandMacro", macroName = macroName, line = line, filePath = filePath
  
  let process = await startProcess(
    nimPath,
    arguments = @["c", "--expandMacro:" & macroName] & @[filePath],
    options = {UsePath},
    stderrHandle = AsyncProcess.Pipe,
    stdoutHandle = AsyncProcess.Pipe,
  )
  
  let res = await process.waitForExit(InfiniteDuration)
  let output = string.fromBytes(process.stderrStream.read().await)  
  # Extract just the expanded macro code for our specific line
  extractMacroExpansion(output, line)
