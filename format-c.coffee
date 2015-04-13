FormatCStream = require "#{__dirname}/format-c-stream"

process.stdin.pipe(new FormatCStream).pipe(process.stdout)
