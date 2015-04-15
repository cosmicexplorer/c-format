util = require 'util'
Transform = require('stream').Transform

FormatCStream = (opts) ->
  if not @ instanceof FormatCStream
    return new FormatCStream
  else
    Transform.call @, opts

  @numNewlinesToPreserve = opts?.numNewlinesToPreserve or 2
  @prevCharArrSize = 3
  if @numNewlinesToPreserve > @prevCharArrSize
    @prevCharArrSize = @numNewlinesToPreserve
  @prevCharArr = []
  for i in [1..@prevCharArrSize] by 1
    @prevCharArr.push ""
  @indentationString = opts?.indentationString or "  "
  @delimiterStack = []

  cb = =>
    @emit 'end'
  @on 'pipe', (src) =>
    src.on 'end', cb
  @on 'unpipe', (src) =>
    src.removeListener 'end', cb

util.inherits FormatCStream, Transform

leadingWhitespaceRegex = /^\s+/g
trailingWhitespaceRegex = /\s+$/g

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

# TODO: process in blocks of top-level declarations:
# 1. preprocessor defines
# 2. function definitions and namespace declarations
# 3. class/function declarations

baseTransformFunc = (str) ->
  str
    # first replace backslash-newlines
    .replace(/\\\n/g, "")
    # first remove null chars (lol)
    .replace(/[\0\x01\x02\x03\x04]/g, "")
    # keep all multiple-newlines as \x01 chars (to be removed later)
    .replace(/\n\n/g, "\x01")
    # then keep all #defines as they are (null chars added here, removed below)
    .replace(/^(#.*)$/gm, (str, g1) -> "#{g1}\0")
    # keep // comments on same line lol, and replace with \x02
    .replace(/\/\/(.*)$/gm, (str, g1) -> "\x02#{g1}\0")
    # replace /* with \x03, and */ with \x04
    .replace(/\/\*/g, "\x03").replace(/\*\//g, "\x04")
    # no trailing whitespace
    .replace(/([^\s])\s+$/gm, (str, g1) -> "#{g1}")
    # enforce newlines after access specifiers/gotos
    .replace(/:$/gm, ":\0")
    # no more than one space in between anything
    .replace(/([^\s])\s+([^\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # newlines before and after /* and */ comments
    .replace(/([^\n])(\/\*|\*\/)/g, (str, g1, g2) -> "#{g1}\n#{g2}")
    .replace(/(\*\/|\/\*)([^\n])/g, (str, g1, g2) -> "#{g1}\n#{g2}")
    # no tabs or anything weird
    .replace(/(\s)/g, (str, g1) ->
      if g1 is "\n"
        return "\n"
      else
        return " ")
    # space after common punctuation characters
    # note that this puts a space after every asterisk, always, even if it is a
    # pointer
    .replace(/([\)=\-<>\+\/\*,\[\]])([^\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # newline before/after open brace, close brace always
    .replace(/([\{\}])([^\n\0\x01])/g, (str, g1, g2) -> "#{g1}\n#{g2}")
    # newline enforced only before close brace, not open
    # not sure why the spacing workaround here was necessary (as opposed to the
    # obvious ".replace(/([^\n])\}/g, "#{g1}\n}")"); think it's because
    # the spacing is getting fucked with later on, but not sure where
    .replace(/([^\s]+)([\s]*)\}/g, (str, g1, g2) -> "#{g1}\n}")
    # space before common punctuation characters
    .replace(/([^\s])([=\-+\[\]])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # space after single (not double!) colon
    .replace(/([^:]):([^:])/g, (str, g1, g2) -> "#{g1}: #{g2}")
    # one space before single colon, even for access specifiers and gotos
    # this is one of the drawbacks of using a regex-based parser
    .replace(/([^\s:]):([^:])/g, (str, g1, g2) -> "#{g1} :#{g2}")
    # NO space after double colon
    .replace(/::\s+([^\s])/g, (str, g1) -> "::#{g1}")
    # NO space before double colon, if preceded by token
    # (we don't want to screw with global scope resolution operator)
    .replace(/(\w)\s+::/g, (str, g1) -> "#{g1}::")
    # spaces before/after <, >
    # assume >< never appears (<> is handled separately)
    .replace(/([^<>\s])([<>]){1}/g, (str, g1, g2) -> "#{g1} #{g2}")
    .replace(/([<>])([^<>\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # NO spaces between two consecutive >>, <<
    .replace(/>\s+>/g, ">>").replace(/<\s+</g, "<<")
    # no spaces between two consecutive ++, --
    .replace(/\+\s+\+/g, "++").replace(/\-\s+\-/g, "--")
    # no spaces between word characters and -- or ++
    .replace(/([^\s])\s+\-\-/g, (str, g1) -> "#{g1}--") # postdec
    .replace(/([^\s])\s+\+\+/g, (str, g1) -> "#{g1}++") # postinc
    .replace(/\-\-\s+([^\s])/g, (str, g1) -> "--#{g1}") # predec
    .replace(/\+\+\s+([^\s])/g, (str, g1) -> "++#{g1}") # preinc
    # no spaces before parens
    .replace(/\s+\(/g, "(")
    # newlines after common stuff
    .replace(/([\{;])([^\n\0\x01])/g, (str, g1, g2) -> "#{g1}\n#{g2}")
    # .replace(/([^\n])\}/g, (str, g1) -> "#{g1}\n}")
    # no space before semicolon
    .replace(/\s+;/g, ";")
    # except NO space in between +=, -=, *=, /=
    .replace(/(.)([\+\-\*\/])\s+=/g, (str, g1, g2) ->
      if (g1 is "+" and g2 is "+") or
         (g1 is "-" and g2 is "-")
        "#{g1}#{g2} ="
      else
        "#{g1}#{g2}=")
    # template <>, not template<>
    .replace(/([^\s]+)\s+<([^\n\0\x01>]*)>/g, (str, g1, g2) ->
      if g1 isnt "template"
        "#{g1}<#{g2}>"
      else
        "#{g1} <#{g2}>")
    # keep template args cuddled within <>
    .replace(/<\s*([^\n\0\x01>]*)\s*>/g, (str, g1) ->
      res = g1.replace(leadingWhitespaceRegex, "")
        .replace(trailingWhitespaceRegex, "")
      "<#{res}>")
    # finally, put back those preprocessor defines
    .replace(/\s*\0\s*([^\s])/g, (str, g1) -> "\n#{g1}")
    # now for multiple newlines
    .replace(/\x01/g, "\n\n")
    # and for //-comments
    .replace(/\x02/g, "//")
    # and for /**/-comments
    .replace(/\x03/g, "/*").replace(/\x04/g, "*/")
    # postprocessing: remove leading whitespace before adding indentation
    .replace(/^(\s+)/gm, (str, g1) ->
      outArr = []
      for ch in g1
        if ch is "\n"
          outArr.push ch
      return outArr.join "")

FormatCStream.prototype._transform = (chunk, enc, cb) ->
  # TODO: add buffers; the removal of newlines is dependent on this since each
  # entry into the stream is a line when read from stdin
  str = baseTransformFunc chunk.toString()

  # let's do indentation!
  # out = []
  # for c in str
  #   if @prevCharArr[@prevCharArr.length - 1] is "\n"
  #     if c isnt "\n"
  #       if isCloseDelim c
  #         for i in [0..(@delimiterStack.length - 2)] by 1
  #           out.push @indentationString
  #       else
  #         for i in [0..(@delimiterStack.length - 1)] by 1
  #           # add levels of indentation
  #           out.push @indentationString
  #   if isOpenDelim c
  #     @delimiterStack.push c
  #   else if isCloseDelim c
  #     # for some reason short-circuit evaluation isn't working here...
  #     openingDelim = @delimiterStack.pop()
  #     if getClosingDelim(openingDelim) isnt c
  #       @emit 'error',
  #       "Your delimiters aren't matched correctly and this won't compile."
  #   tooManyNewlines = c is "\n"
  #   for i in [1..@numNewlinesToPreserve] by 1
  #     tooManyNewlines =
  #       @prevCharArr[@prevCharArr.length - i] is "\n" and tooManyNewlines
  #   if not tooManyNewlines
  #     out.push c
  #   @prevCharArr.shift
  #   @prevCharArr.push c

  # @push out.join("")
  @push str
  cb?()

FormatCStream.prototype._flush = (chunk, enc, cb) ->
  @push "\n"
  cb?()

module.exports = FormatCStream
