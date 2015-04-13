FormatCStream = require './format-c-stream'

process.stdin.pipe(new SimpleCStream).pipe(process.stdout)
