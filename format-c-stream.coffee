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

# all these regexes are length-bound by a certain amount (i believe 3 is the
# maximum currently). don't forget to add _flush to flush out the buffer!
interstitialBufferLength = 12

# ' < '|'< a...'
baseTransformFunc = (str) ->
  str
    # first replace backslash-newlines
    .replace(/\\\n/g, "")
    # then keep all #defines as they are (chars added here, removed at bottom)
    .replace(/\0/g, "")         # first remove null chars (lol)
    .replace(/^(#.*)$/gm, (str, g1) -> "#{g1}\0")
    # no trailing whitespace
    .replace(/([^\s])\s+$/gm, (str, g1) -> "#{g1}")
    # no more than one space in between anything
    .replace(/([^\s])\s+([^\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # no tabs or anything weird
    .replace(/(\s)/g, (str, g1) ->
      if g1 is "\n"
        return "\n"
      else
        return " ")
    # space after common punctuation characters
    .replace(/([\)=\-<>+,\}\[\]])(\w)/g, (str, g1, g2) -> "#{g1} #{g2}")
    # newline after open brace, close brace always
    .replace(/\{\s*/g, "\{\n").replace(/\}\s*/g, "\}\n")
    # space before common punctuation characters
    .replace(/(\w)([=\-+\{\}\[\]])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # space after single (not double!) colon
    .replace(/([^:]):([^\s])/g, (str, g1, g2) -> "#{g1}:#{g2}")
    # NO space after double colon
    .replace(/::\s+([^\s])/g, (str, g1) -> "::#{g1}")
    # spaces before/after <, >
    # assume >< never appears (<> is handled separately)
    .replace(/([^<>\s])([<>]){1}/g, (str, g1, g2) -> "#{g1} #{g2}")
    .replace(/([<>])([^<>\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # NO spaces between two consecutive >>, <<
    .replace(/>\s+>/g, ">>").replace(/<\s+</g, "<<")
    # no spaces between word characters and -- or ++
    .replace(/(\w)\s+\-\-/g, (str, g1) -> "#{g1}--") # postdec
    .replace(/(\w)\s+\+\+/g, (str, g1) -> "#{g1}++") # postinc
    .replace(/\-\-\s+(\w)/g, (str, g1) -> "--#{g1}") # predec
    .replace(/\+\+\s+(\w)/g, (str, g1) -> "++#{g1}") # preinc
    # no spaces before parens
    .replace(/\s+\(/g, "(")
    # newlines after common stuff
    .replace(/([\{;])([^\n])/g, (str, g1, g2) -> "#{g1}\n#{g2}")
    .replace(/([^\n])\}/g, (str, g1) -> "\n}")
    # no space before semicolon
    .replace(/\s+;/g, ";")
    # template <>, not template<>
    .replace(/([^\s]+)\s+<([^\n>]*)>/g, (str, g1, g2) ->
      if g1 isnt "template"
        "#{g1}<#{g2}>"
      else
        "#{g1} <#{g2}>")
    # keep template args cuddled within <>
    .replace(/<\s*([^\n>]*)\s*>/g, (str, g1) ->
      res = g1.replace(leadingWhitespaceRegex, "")
        .replace(trailingWhitespaceRegex, "")
      "<#{res}>")
    # finally, put back those preprocessor defines
    .replace(/\s*\0\s*([^\s])/g, (str, g1) -> "\n#{g1}")
    # postprocessing: remove leading whitespace before adding indentation
    .replace(/^\s+/gm, "")

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

  # @push(new Buffer(out.join("")))
  @push str
  cb?()

FormatCStream.prototype._flush = (chunk, enc, cb) ->

module.exports = FormatCStream
