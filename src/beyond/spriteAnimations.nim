# The format for this is based on the Aseprite animation json

import std/[json, tables, sugar, sequtils, strutils, algorithm, options]
import base

type
  Millisecond* = int
  Frame* = object
    frame*: tuple[x, y, w, h: int]
    spriteSourceSize*: tuple[x, y, w, h: int]
    sourceSize*: tuple[w, h: int]
    rotated*, trimmed*: bool
    duration*: Millisecond # ms
    
  AnimationLayerMeta* = object
    name*: string
    opacity*: int
    blendMode*: string

  AnimationMeta* = object
    app*: string # application that generated the metadata
    version*: string # version string of the genreated metadata
    image*: string # name of the source image
    format*: string # I8
    size*: tuple[w, h: int] # size of the source image
    frameTags*: seq[string]
    layers*: seq[AnimationLayerMeta]
    slices*: seq[string]

  AnimationFrames = Table[string, Frame]

  Animation* = object
    frames: AnimationFrames
    meta: AnimationMeta
    order: Table[string, int]

proc frames*(anim: Animation): seq[tuple[name: string, frame: Frame]] =
  result = anim.frames.pairs.toSeq()
  result.sort (a, b) => cmp(a[0], b[0])

proc order*(anim: Animation): auto =
  result = anim.order

proc initFromJson*(frames: var Table[string, Frame], js: JsonNode, path: var string) =
  for k, v in js.pairs:
    frames[k] = v.to(Frame)

proc initFromJson*(anim: var Animation, js: JsonNode, path: var string) =
  anim.meta = js["meta"].to(AnimationMeta)
  anim.frames = js["frames"].to(AnimationFrames)

proc refreshOrder*(anim: var Animation) =
  var fs = anim.frames()
  for i in 0 ..< fs.len:
    anim.order[fs[i].name] = i

proc load*(T: typedesc[Animation], js: JsonNode): T =
  var path = ""
  result = T.default()
  result.initFromJson(js, path)
  result.refreshOrder()

type
  AnimationState* = enum
    Playing
    Paused
    Stopped
  Animator* = object
    animations: Table[string, Animation]
    currentAnimation: string
    currentAnimationState: AnimationState
    currentFrame: string
    currentTime: int

proc init*(T: typedesc[Animator]): T =
  result = Animator()

proc add*(animator: var Animator, animation: Animation) =
  animator.animations[animation.meta.image] = animation

proc get*(animator: Animator, name: string): Option[Animation] =
  if not animator.animations.hasKey(name):
    stderr.writeLine("Animator does not have animation '" & name & "'")
    return
  result = some(animator.animations[name])

proc animation*(animator: Animator): Option[Animation] =
  if not animator.animations.hasKey(animator.currentAnimation):
    return
  result = some(animator.animations[animator.currentAnimation])

proc frameIndex*(anim: Animation, id: string): int =
  result = anim.order()[id]

proc frame*(animator: Animator): Option[Frame] =
  withIt(animator.animation(), anim):
    let 
      frames = anim.frames()
      frameIndex = anim.order()[animator.currentFrame]
    result = some(frames[frameIndex].frame)

proc currentFrame*(animator: Animator): string =
  result = animator.currentFrame

proc currentAnimation*(animator: Animator): string =
  result = animator.currentAnimation

proc nextFrameName*(animator: Animator): string =
  withIt(animator.animation(), anim):
    let frames = anim.frames()
    if frames.len == 0:
      return
    let currentIndex = anim.frameIndex(animator.currentFrame)
    if currentIndex + 1 >= frames.len:
      result = frames[0].name
    else:
      result = frames[currentIndex + 1].name

proc setFrame*(animator: var Animator, frame: string) =
  animator.currentFrame = frame
  animator.currentTime = 0

proc update*(animator: var Animator, deltaTime: float) =
  if animator.currentAnimationState == Playing:
    animator.currentTime += int(deltaTime * 1000.0)
    withIt(animator.frame(), frame):
      if animator.currentTime >= frame.duration:
        animator.setFrame(animator.nextFrameName())

proc play*(animator: var Animator, name: string) =
  withIt(animator.get(name), anim):
    animator.currentAnimation = name
    let frames = anim.frames()
    if frames.len == 0:
      return
    animator.currentFrame = frames[0].name
    animator.currentTime = 0
    animator.currentAnimationState = Playing

proc playing*(animator: Animator): bool =
  result = animator.currentAnimationState == Playing
    
proc resume*(animator: var Animator) =
  animator.currentAnimationState = Playing
proc stop*(animator: var Animator) =
  animator.currentAnimationState = Stopped
proc pause*(animator: var Animator) =
  animator.currentAnimationState = Paused
