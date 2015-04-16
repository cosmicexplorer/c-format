Transform = require('stream').Transform

module.exports =
class FormatCStream extends Transform
  constructor: (opts) ->
    if not @ instanceof FormatCStream
      return new FormatCStream
    else
      Transform.call @, opts

    if opts?.numNewlinesToPreserve is 0
      @noNewlines = true
      @numNewlinesToPreserve = 0
    else
      @noNewlines = false
      @numNewlinesToPreserve = opts?.numNewlinesToPreserve + 1 or 2
    @prevCharArrSize = 3
    if @numNewlinesToPreserve > @prevCharArrSize
      @prevCharArrSize = @numNewlinesToPreserve
    @prevCharArr = []
    for i in [1..@prevCharArrSize] by 1
      @prevCharArr.push "\n"
    @indentationString = opts?.indentationString or "  "
    @delimiterStack = []

    # process in blocks of top-level declarations:
    # 1. preprocessor defines at top level
    # 2. function definitions and namespace declarations
    # 3. class/function declarations

    # this is set so _transform knows when to break off each chunk and feed it
    # into @baseTransformFunc and indentAndNewline
    @blockStatus = null
    # this contains the status of the stream saved from previous inputs
    @interstitialBuffer = []

    # emit 'end' on end of input
    cbEnd = =>
      @emit 'end'
    # same for 'error'
    cbError = (err) =>
      @emit 'error'
    @on 'pipe', (src) =>
      src.on 'end', cbEnd
      src.on 'error', cbError
    @on 'unpipe', (src) =>
      src.removeListener 'end', cbEnd
      src.removeListener 'error', cbError

  @leadingWhitespaceRegex: /^\s+/gm
  @trailingWhitespaceRegex: /\s+$/gm

  @isOpenDelim : (c) ->
    switch c
      when "(" then true
      when "[" then true
      when "{" then true
      else false

  @isCloseDelim : (c) ->
    switch c
      when "}" then true
      when "]" then true
      when ")" then true
      else false

  @getClosingDelim : (openDelim) ->
    switch openDelim
      when "(" then ")"
      when "[" then "]"
      when "{" then "}"
      else null

  baseTransformFunc : (str) ->
    str
      # preprocessing: remove all leading whitespace (this looks complex but
      # simpler methods weren't working for some reason)
      .replace(/^(\s+)/gm, (str, g1) ->
        outArr = []
        for ch in g1
          if ch is "\n"
            outArr.push ch
        outArr.join "")
      # first replace backslash-newlines
      .replace(/\\\n/g, "")
      # first remove null chars (lol)
      .replace(/[\0\x01\x02\x03\x04]/g, "")
      # then keep all #defines as is (null chars added here, removed later)
      .replace(/^(#.*)$/gm, (str, g1) -> "#{g1}\0")
      # keep // comments on same line lol, and replace with \x02
      .replace(/\/\/(.*)$/gm, (str, g1) -> "\x02#{g1}\0")
      # replace /* with \x03, and */ with \x04
      .replace(/\/\*/g, "\x03").replace(/\*\//g, "\x04")
      # enforce newlines after access specifiers/gotos
      .replace(/^\n\s*(\w+):\s*$/gm, (str, g1) -> "\n#{g1}:\0")
      # keep all multiple-newlines as \x01 chars (to be removed later)
      .replace(/\n\n/g, =>
        if @noNewlines
          " "
        else
          "\x01")
      # kill newlines
      .replace(/\n/g, " ")
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
      # note that this puts a space after every asterisk, always, even if it is
      # a pointer; this is one of the issues with a regex-based approach
      .replace(/([\)=\-<>\+\/\*,\[\]])([^\s])/g, (str, g1, g2) -> "#{g1} #{g2}")
      # NO space inside paren
      .replace(/\s+\)/g, ")").replace(/\(\s+/g, "(")
      # NO space before comma
      .replace(/\s+,/g, ",")
      # newline enforced only before close brace, not open
      # not sure why the spacing workaround here was necessary (as opposed to
      # the obvious ".replace(/([^\n])\}/g, "#{g1}\n}")"); think it's because
      # the spacing is getting fucked with later on, but not sure where
      .replace(/([^\s]+)([\s]*)\}/g, (str, g1, g2) -> "#{g1}\n}")
      # space before common punctuation characters
      .replace(/([^\s])([=\-+\[\]])/g, (str, g1, g2) -> "#{g1} #{g2}")
      # space after single (not double!) colon
      .replace(/([^:]):([^:\s])/g, (str, g1, g2) -> "#{g1}: #{g2}")
      # one space before single colon, except for access specifiers and gotos
      .replace(/([^\s:]):([^:])/g, (str, g1, g2) -> "#{g1} :#{g2}")
      .replace(/([\n\0\x01])\s*(\w+)\s*:\s*([\n\0\x01])/g, (str, g1, g2, g3) ->
        "#{g1}#{g2}:#{g3}")
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
      # no spaces before parens except for built-in stuff
      .replace(/(\w+)\s*\(/g, (str, g1) ->
        if g1 is "for" or
           g1 is "while" or
           g1 is "switch"
          "#{g1} ("
        else
          "#{g1}(")
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
        res = g1.replace(FormatCStream.leadingWhitespaceRegex, "")
          .replace(FormatCStream.trailingWhitespaceRegex, "")
        "<#{res}>")
      # newline after open brace, close brace, semicolon
      .replace(/([\{\};])([^\n\0\x01])/g, (str, g1, g2) -> "#{g1}\n#{g2}")
      # finally, put back those preprocessor defines
      .replace(/\s*\0\s*([^\s]*)/g, (str, g1) -> "\n#{g1}")
      # now for multiple newlines
      .replace(/\x01/g, "\n\n")
      # and for //-comments
      .replace(/\x02/g, "//")
      # midprocessing: remove leading whitespace that has crept in from earlier
      .replace(/^(\s+)/gm, (str, g1) ->
        outArr = []
        for ch in g1
          if ch is "\n"
            outArr.push ch
        outArr.join "")
      # and for /**/-comments
      .replace(/\x03(.)/g, (str, g1) ->
        next = ""
        if g1 is "\n"
          next = "\n"
        else
          next = "\n#{g1}"
        return "/*#{next}")
      .replace(/(.)\x04(.)/g, (str, g1, g2) ->
        prev = ""
        next = ""
        if g1 is "\n"
          prev = "\n"
        else
          prev = "#{g1}\n"
        if g2 is "\n"
          next = "\n"
        else
          next = "\n#{g2}"
        "#{prev}*/#{next}")
      # make opening brackets on next line (do this after null char replacement)
      .replace(/([^\s])\s*\{/g, (str, g1) -> "#{g1}\n{")
      # postprocessing: remove leading whitespace before adding indentation
      .replace(/^(\s+)/gm, (str, g1) ->
        outArr = []
        for ch in g1
          if ch is "\n"
            outArr.push ch
        outArr.join "")

  # this one can't be static since it manipulates the stream state
  indentAndNewline: (str) ->
    # let's do indentation!
    out = []
    for c in str
      # we have verified in ctor that @prevCharArr.length > 0
      if @prevCharArr[@prevCharArr.length - 1] is "\n"
        if c isnt "\n"
          if FormatCStream.isCloseDelim c
            for i in [0..(@delimiterStack.length - 2)] by 1
              out.push @indentationString
          else
            for i in [0..(@delimiterStack.length - 1)] by 1
              # add levels of indentation
              out.push @indentationString
      if FormatCStream.isOpenDelim c
        @delimiterStack.push c
      else if FormatCStream.isCloseDelim c
        # for some reason short-circuit evaluation isn't working here...
        openingDelim = @delimiterStack.pop()
        if FormatCStream.getClosingDelim(openingDelim) isnt c
          @emit 'error',
          "Your delimiters aren't matched correctly and this won't compile."
      if not @noNewlines
        tooManyNewlines = c is "\n"
        for i in [1..@numNewlinesToPreserve] by 1
          tooManyNewlines =
            @prevCharArr[@prevCharArr.length - i] is "\n" and tooManyNewlines
        if not tooManyNewlines
          out.push c
      else
        out.push c
      @prevCharArr.shift
      @prevCharArr.push c
    out.join("")

  _transform : (chunk, enc, cb) ->
    str = chunk.toString()
    c = ""
    for i in [0..(str.length - 1)]
      c = str.charAt(i)
      @interstitialBuffer.push c
      if @blockStatus is null
        if c is "{"
          @blockStatus =
            type: "{"
            num: 1
        if c is "#"
          @blockStatus =
            type: "#"
        if c is ";"
          @push "\n" if @prevCharArr[@prevCharArr.length - 1] isnt "\n"
          # @push "^__^"
          @push(@indentAndNewline(@baseTransformFunc(
            @interstitialBuffer.join(""))))
          @blockStatus = null
          @interstitialBuffer = []
      else
        if @blockStatus.type is "{"
          if c is "}"
            --@blockStatus.num
          else if c is "{"
            ++@blockStatus.num
          if @blockStatus.num is 0
            @push "\n" if @prevCharArr[@prevCharArr.length - 1] isnt "\n"
            # @push "^__^"
            @push(@indentAndNewline(@baseTransformFunc(
              @interstitialBuffer.join(""))))
            @blockStatus = null
            @interstitialBuffer = []
        else if @blockStatus.type is "#" and c is "\n"
          @push "\n" if @prevCharArr[@prevCharArr.length - 1] isnt "\n"
          # @push "^__^"
          @push(@indentAndNewline(@baseTransformFunc(
            @interstitialBuffer.join(""))))
          @blockStatus = null
          @interstitialBuffer = []
    cb?()

  _flush : (cb) ->
    @push(@indentAndNewline(@baseTransformFunc(
      @interstitialBuffer.join(""))))
    if @prevCharArr[@prevCharArr.length - 1] isnt "\n"
      @push "\n"                  # file ends in newline!
    cb?()
