## Safe logging that never raises exceptions
## Can be used in {.raises: [].} functions

import std/logging
import std/strutils

{.push raises: [].}

var logger: ConsoleLogger

proc initLogging*() =
  try:
    logger = newConsoleLogger()
    addHandler(logger)
  except:
    discard

proc info*(args: varargs[string, `$`]) =
  try:
    logging.info(args.join(""))
  except:
    discard

proc warn*(args: varargs[string, `$`]) =
  try:
    logging.warn(args.join(""))
  except:
    discard

proc error*(args: varargs[string, `$`]) =
  try:
    logging.error(args.join(""))
  except:
    discard

proc debug*(args: varargs[string, `$`]) =
  try:
    logging.debug(args.join(""))
  except:
    discard

{.pop.}
