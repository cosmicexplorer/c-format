c-format-stream
===============

A Transform stream to format C and C-like code.

# Usage

## Command-line

```bash
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
  numNewlinesToPreserve: 3, // cuts off after this. enter 0 to destroy all newlines
  indentationString: "\t"   // use tabs for indentation
}));

// fires when stream has no more data
formattedStream.on('end', function(){
  doSomethingWhenStreamIsDone();
});

// an error has occurred
formattedStream.on('error', function(err){
  console.error(err);
});
```

# LICENSE

GPL v3
