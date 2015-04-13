util = require 'util'
Transform = require('stream').Transform

FormatCStream = ->
  if not @ instanceof FormatCStream
    return new FormatCStream
  else
    Transform.call @
  cb = =>
    @emit 'end'
  @on 'pipe', (src) =>
    src.on 'end', cb
  @on 'unpipe', (src) =>
    src.removeListener 'end', cb

util.inherits FormatCStream, Transform

FormatCStream.prototype._transform = (chunk, enc, cb) ->
  str = chunk.toString()
  @push(new Buffer(str
    # no trailing whitespace
    .replace(/([^\s])\s+\n/g, (str, g1) -> "#{g1}\n")
    # no more than one space in between anything
    .replace(/([^\s])\s+([^\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
    # no spaces from left
    .replace(/^\s+([^\s])/g, (str, g1) -> "#{g1}")
    # no tabs or anything weird
    .replace(/(\s)/g, (str, g1) ->
      if g1 == "\n"
        return "\n"
      else
        return " ")
    # space after common punctuation characters
    .replace(/([\);=\-<>+,\{\}\[\]])(\w)/g, (str, g1, g2) -> "#{g1} #{g2}")
    # space before common punctuation characters
    .replace(/(\w)([\(=\-+\{\}\[\]])/g, (str, g1, g2) -> "#{g1} #{g2}")
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
    # TODO: add indentation by tabs/spaces according to bracketing
    # TODO: only allow newlines after (,{,[,; (more?)
    ))
  cb?()

module.exports = FormatCStream
