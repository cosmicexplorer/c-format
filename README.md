format-c
========

A Transform stream to format C and C-like code.

# Usage

## Command-line

```bash
format-c FILE
```

## Node Module

```javascript
var SimpleCStream = require('c-format-stream');
var formattedStream = getReadableStreamSomehow().pipe(new SimpleCStream({
  stuff: "yeah",
  other_stuff: "that too",
  even_this: "hell yeah"
}));

// fires when stream has no more data
objectStream.on('end', function(){
  doSomethingWhenStreamIsDone();
});

// lots of other stream-related nonsense
```

# LICENSE

GPLv3
