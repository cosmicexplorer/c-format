util = require 'util'
Transform = require('stream').Transform

FormatCStream = ->
  if not @ instanceof FormatCStream
    return new FormatCStream
  else
    Transform.call @

  @delimiterStack = []
  @prevChar = ""
  @indentationString = "\t"

  cb = =>
    @emit 'end'
  @on 'pipe', (src) =>
    src.on 'end', cb
  @on 'unpipe', (src) =>
    src.removeListener 'end', cb

util.inherits FormatCStream, Transform

isOpenDelim = (c) ->
  switch c
    when "(" then true
    when "[" then true
    when "{" then true
    else false

isCloseDelim = (c) ->
  switch c
    when "}" then true
    when "]" then true
    when ")" then true
    else false

getClosingDelim = (openDelim) ->
  switch openDelim
    when "(" then ")"
    when "[" then "]"
    when "{" then "}"

# all these regexes are length-bound by a certain amount (i believe 3 is the
# maximum currently). don't forget to add _flush to flush out the buffer!
interstitialBufferLength = 12

# ' < '|'< a...'
FormatCStream.prototype._transform = (chunk, enc, cb) ->
  str = chunk.toString()
    # no trailing whitespace
    .replace(/([^\s])\s+\n/g, (str, g1) -> "#{g1}\n")
    # no more than one space in between anything
    .replace(/([^\s])\s+([^\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # no spaces from left
    .replace(/^\s+([^\s])/g, (str, g1) -> "#{g1}")
    # no tabs or anything weird
    .replace(/(\s)/g, (str, g1) ->
      if g1 is "\n"
        return "\n"
      else
        return " ")
    # remove multiple newlines
    .replace(/\n+/g, "\n")
    # space after common punctuation characters
    .replace(/([\);=\-<>+,\{\}\[\]])(\w)/g, (str, g1, g2) -> "#{g1} #{g2}")
    # space before common punctuation characters
    .replace(/(\w)([=\-+\{\}\[\]])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # space after single (not double!) colon
    .replace(/([^:]):([^\s])/g, (str, g1, g2) -> "#{g1}:#{g2}")
    # NO space after double colon
    .replace(/::\s+([^\s])/g, (str, g1) -> "::#{g1}")
    # spaces before/after <, >
    # assume <> or >< never appears
    .replace(/([^<>\s])([<>]){1}/g, (str, g1, g2) -> "#{g1} #{g2}")
    .replace(/([<>])([^<>\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # NO spaces between two consecutive >>, <<
    .replace(/>\s+>/g, ">>").replace(/<\s+</g, "<<")
    # no spaces between word characters and (, --, or ++
    .replace(/(\w)\s+\(/g, (str, g1) -> "#{g1} (")
    .replace(/(\w)\s+\-\-/g, (str, g1) -> "#{g1}--") # postdec
    .replace(/(\w)\s+\+\+/g, (str, g1) -> "#{g1}++") # postinc
    .replace(/\-\-\s+(\w)/g, (str, g1) -> "--#{g1}") # predec
    .replace(/\+\+\s+(\w)/g, (str, g1) -> "++#{g1}") # preinc
    # no spaces before parens
    .replace(/\s+\(/g, "(")
    # will always have space after
    .replace(/([\{;])[^\n]/g, (str, g1, g2) -> "#{g1}\n")
    .replace(/([^\n])\}/g, (str, g1) -> "\n}")

  # TODO: add buffers; the removal of newlines is dependent on this since each
  # entry into the stream is a line when read from stdin

  out = []
  for c in str
    if @prevChar is "\n"
      if isCloseDelim c
        for i in [0..(@delimiterStack.length - 2)] by 1
          out.push @indentationString
      else
        for i in [0..(@delimiterStack.length - 1)] by 1
          # add levels of indentation
          out.push @indentationString
    if isOpenDelim c
      @delimiterStack.push c
    else if isCloseDelim c
      if getClosingDelim(@delimiterStack.pop()) isnt c
        @emit 'error',
        "Your delimiters aren't matched correctly and this won't compile."
    out.push c
    @prevChar = c

  @push(new Buffer(out.join("")))
  cb?()

module.exports = FormatCStream
