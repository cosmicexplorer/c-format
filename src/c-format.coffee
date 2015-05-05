fs = require 'fs'

module.exports =

  run : ->
    CFormatStream = require "#{__dirname}/c-format-stream"

    parseIndentStr = (str) ->
      if str.charAt(0) is "s"
        spaceArr = []
        for i in [1..(parseInt(str.substr(1)))] by 1
          spaceArr.push " "
        return spaceArr.join("")
      else if str.charAt(0) is "t"
        return "\t"
      else return null

    # we were called with "node" or "coffee". we don't care
    process.argv.shift()

    # manually parsing options cause we have so few
    if process.argv.indexOf("-h") isnt -1 or
       process.argv.indexOf("--help") isnt -1
       process.argv.length is 1
      console.error '''
      Usage: c-format INFILE [OUTFILE] [-hvni]

      INFILE should be "-" for stdin. OUTFILE defaults to stdout.

      -h show this help and exit
      -v show version number and exit
      -n number of newlines to preserve
      -i type of indentation string

      For the '-i' argument, strings of type 'sN', where N is
      some nonnegative integer, or 't' are accepted. The 'sN'
      type says to use N spaces for indentation, while 't'
      says to use tabs.

      Example: c-format test.c -n4 -is3
      '''
      process.exit -1
    else if process.argv.indexOf("-v") isnt -1
      # N.B.: this pathname is tightly coupled with the source tree!
      fs.readFile "#{__dirname}/../../package.json", (err, file) ->
        throw err if err
        console.log "c-format version #{JSON.parse(file.toString()).version}"
        process.exit 0
    else
      if process.argv[1] isnt "-"
        inStream = fs.createReadStream(process.argv[1])
        inFileName = process.argv[1]
      else
        inStream = process.stdin
        inFileName = "stdin"
      inStream.on 'error', (err) ->
        console.error "Error encountered in reading #{inFileName}. Exiting." +
        console.error err
        process.exit -1
      if process.argv.length >= 3 and process.argv[2].charAt(0) isnt "-"
        outStream = fs.createWriteStream(process.argv[2])
        outFileName = process.argv[2]
      else
        outStream = process.stdout
        outFileName = "stdout"
      outStream.on 'error', (err) ->
        console.error "Error encountered in writing #{outFileName}"
        console.error err
        process.exit -1
      opts = {}
      # get numNewlines arg
      for i in [0..(process.argv.length - 1)] by 1
        if process.argv[i].match /^\-n/g
          nArg = i
          break
      if nArg
        nArgStr = process.argv[nArg]
        if nArgStr.substr("-n".length) is ""
          nIndex = parseInt process.argv[nArg + 1]
        else
          nIndex = parseInt nArgStr.substr "-n".length
        if nIndex >= 0
          opts.numNewlinesToPreserve = nIndex
        else
          console.error "Error: number of newlines should be >= 0, not #{nIndex}."
          process.exit -1
      # get indentationString arg
      for i in [0..(process.argv.length - 1)] by 1
        if process.argv[i].match /^\-i/g
          sArg = i
          break
      if sArg
        sArgStr = process.argv[sArg]
        if sArgStr is "-i"
          sStr = parseIndentStr process.argv[sArg + 1]
        else
          sStr = parseIndentStr sArgStr.substr "-i".length
        if sStr
          opts.indentationString = sStr
        else
          console.error "Error: invalid indentation string. Choose \"sN\", where " +
          "N -is some positive number (for a number of spaces), or \"t\", which " +
          "means tabs."
          process.exit -1
      formatStream = new CFormatStream opts
      formatStream.on 'error', (err) ->
        console.error "Error encountered within internal formatting stream."
        console.error err
        process.exit -1
      inStream.pipe(formatStream).pipe(outStream)
