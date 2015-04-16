c-format-stream
===============

A Transform stream to format C and C-like code. It's intended to work like clang-format, but it's a lot more opinionated (and, you'll find, somewhat dumber, although there are some cool benefits). It's mostly intended as a cleaning tool for preprocessors such as [compp](https://github.com/cosmicexplorer/compp), but you'll find it also works well on its own if you need a standalone C formatter to plug into your other scripts. It scrubs the input with regex and then applies indentation and newlines as necessary.

# Usage

## Command-line

Install with `npm install -g c-format-stream`. The binary is named `c-format`.

```shell
$ c-format -h

  Usage: c-format INFILE [OUTFILE] [-hvni]

  INFILE should be "-" for stdin. OUTFILE defaults to stdout.

  -h show this help and exit
  -v show version number and exit
  -n number of newlines to preserve
  -i type of indentation string

  For the '-i' argument, strings of type 'sN', where N is some positive integer,
  or 't' are accepted. The 'sN' type says to use N spaces for indentation, while
  't' says to use tabs.

  Example: c-format test.c -n4 -is3
```

## Node Module

```javascript
var CFormatStream = require('c-format-stream');
var formattedStream = getReadableStreamSomehow().pipe(new CFormatStream({
  numNewlinesToPreserve: 3, // cuts off after this
                            // enter 0 to destroy all empty newlines
  indentationString: "\t"   // use tabs for indentation
}));

// fires when stream has no more data
formattedStream.on('end', function(){
  doSomethingWhenStreamIsDone();
});

// an error has occurred! >=(
formattedStream.on('error', function(err){
  doSomethingOnError(err);
});
```

As it inherits from the Transform stream interface, this stream can use both the standard readable and writable interfaces detailed in the [node documentation](https://nodejs.org/api/stream.html).

## Applications

This was written to help test [compp](https://github.com/cosmicexplorer/compp), the preprocessor part of [composter](https://github.com/cosmicexplorer/composter), a C compiler written in coffeescript. Both are in active development, so feel free to check out either of those two projects if you're interested in this one.

# LICENSE

GPL v3
