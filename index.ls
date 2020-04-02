#!/usr/bin/env lsc
# Parse a markdown file and check for code blocks that are marked as test
# inputs or outputs.  Run the tests and check their inputs and outputs match.

require! <[ fs os unified remark-parse yargs async chalk ]>
sax-parser = require \parse5-sax-parser
{ exec } = require \child_process

argv = do ->

  # It hurts that I have to do this, but here we are.  When run with lsc
  # (livescript interpreter), process.argv contains [node, lsc, index.ls].
  # When run with node, it's just [node, index.js].  In other words, the number
  # of things we have to slice off depends on what interpreter we're running,
  # which is a heap of crap, but at least we can detect for it at runtime with
  # process.argv.lsc, which contains just [index.ls] when run with lsc and
  # doesn't exist if we're running with node.
  argv-to-parse =
    if process.argv.lsc?
      # Slice off main file path
      that.slice 1
    else
      # Slice off interpreter path and main file path
      process.argv.slice 2

  return yargs.parse argv-to-parse

{ queue-test, run-tests } =
  switch argv.format
  | \tap => fallthrough
  | otherwise =>
    test = require \tape

    queue = []

    queue-test : -> queue.push it
    run-tests : ->
      try

        console.log chalk.dim "TAP version 13"

        if queue.length is 0
          console.log chalk.yellow "0..0"
          console.log chalk.yellow "# no tests!"
          process.exit!

        console.log chalk.dim "1..#{queue.length}"

        async-map = if argv.series then async.map-series else async.map

        e, run-results <- async-map queue, ({ name, program, input }, cb) ->
          errored-out = false
          result-callback = (e, stdout) ->
            unless e then cb null, { output: stdout.to-string!, ran-successfully: yes }
            else cb null { output: e.message, ran-successfully: no }
          exec program, result-callback
            ..stdin .on \error ->
              if it.code is \EPIPE
                void # do nothing
              else throw it

            unless errored-out
              ..stdin.end input

        if e then die e.message

        successes = 0
        failures = 0
        queue.for-each (queued-test, index) ->

          run-result = run-results[index]

          test-number = index + 1

          indent = (n, text) ->
            spaces = " " * n
            lines = text.split os.EOL .map -> if it.length then spaces + it else it
            lines.join os.EOL

          print-positions = ->
            input-position = queued-test.input-position
            output-position = queued-test.output-position
            console.log "  #{chalk.blue "input location in file"}:"
            if input-position.start is input-position.end
              console.log indent 4 "line #{input-position.start}"
            else
              console.log indent 4 "lines #{input-position.start}-#{input-position.end}"
            console.log "  #{chalk.blue "output location in file"}:"
            if output-position.start is output-position.end
              console.log indent 4 "line #{output-position.start}"
            else
              console.log indent 4 "lines #{output-position.start}-#{output-position.end}"

          if run-result.ran-successfully
            if run-result.output === queued-test.output
              ++successes
              console.log "#{chalk.green "ok"} #{chalk.dim test-number} #{queued-test.name}"
            else
              ++failures
              console.log "#{chalk.red.inverse "not ok"} #{chalk.dim "#test-number"} #{queued-test.name}#{chalk.dim ": output mismatch"}"
              console.log "  #{chalk.dim "---"}"
              console.log "  #{chalk.blue "expected"}:\n#{indent 4 queued-test.output}"
              console.log "  #{chalk.blue "actual"}:\n#{indent 4 run-result.output}"
              console.log "  #{chalk.blue "program"}:\n#{indent 4 queued-test.program}"
              print-positions!
              console.log "  #{chalk.dim "---"}"
          else
            ++failures
            console.log "#{chalk.red.inverse "not ok"} #{chalk.dim "#test-number"} #{queued-test.name}#{chalk.dim ": program exited with error"}"
            console.log "  #{chalk.dim "---"}"
            console.log "  #{chalk.blue "stderr"}:\n#{indent 4 run-result.output}"
            console.log "  #{chalk.blue "program"}:\n#{indent 4 queued-test.program}"
            print-positions!
            console.log "  #{chalk.dim "---"}"

        console.log!
        colour = if failures is 0 then chalk.green else chalk.red
        console.log colour "# #successes/#{queue.length} passed"
        if failures is 0
          console.log colour.inverse "# OK"
        else
          console.log colour.inverse "# FAILED #failures"
          process.exit 2
      catch e
        die e

{ each, map, fold, unwords, keys, first } = require \prelude-ls
concat = require \concat-stream

die = (message) ->
  console.error message
  process.exit 1

extract-html-comments = (input) ->
  comments = []
  p = new sax-parser!
    ..on \comment ->
      # TODO use it.sourceCodeLocation for better error reporting?
      comments.push it.text
    ..end input
  return comments

# Consecutive dashes are illegal inside HTML comments, so let's allow them to
# be escaped in the "program" command.
unescape = (script) -> script.replace /\\(.)/g -> &1

test-this = (contents) ->

  state =
    program     : null
    input-name  : null
    output-name : null
    inputs      : {}
    outputs     : {}
    input-positions  : {}
    output-positions : {}

  die-if-have-input-or-output = ->
    if state.input-name? or state.output-name?
      die "Consecutive in or out commands"

  visit = (node) ->
    if node.type is \html

      extract-html-comments node.value .for-each (comment) ->

        re = //
             (?:\s+)?      # optional whitespace
             !test         # test command marker
             \s+           # whitespace
             ([\s\S]*)     # interesting commands
             //m

        [ _, command ] = (comment .trim! .match re) || []

        if command

          actions =
            program : -> state.program := it
            in      : -> die-if-have-input-or-output! ; state.input-name   := it
            out     : -> die-if-have-input-or-output! ; state.output-name := it

          command-words = command .split /\s+/
          first-word    = first command-words

          if actions[first-word]
            rest = command |> (.slice first-word.length)
                           |> (.trim!)
                           |> unescape
            that rest

      return []

    else if node.type is \code

      # Add a newline, because it's typical for the console output of any
      # command to end with a newline.
      #
      # In the rare cases that the test command output *doesn't* terminate with
      # a newline, it's trivial for users to put an "echo" command after it.
      # It is less trivial to trim the trailing newline from the output of
      # every normal command!
      text-content = node.value + os.EOL

      if state.input-name

        name = state.input-name
        state.input-name := null

        if state.inputs[name]
          die "Multiple inputs with name `#name`"

        state.inputs[name] = text-content
        state.input-positions[name] =
          start: node.position.start.line
          end: node.position.end.line


        if state.outputs[name] # corresponding output has been found
          if not state.program
            die "Input and output `#name` matched, but no program given yet"
          return [
            {
              name    : name
              program : state.program
              input   : state.inputs[name]
              output  : state.outputs[name]
              input-position  : state.input-positions[name]
              output-position : state.output-positions[name]
            }
          ]


      else if state.output-name

        name = state.output-name
        state.output-name := null

        if state.outputs[name]
          die "Multiple outputs with name `#name`"

        state.outputs[name] = text-content
        state.output-positions[name] =
          start: node.position.start.line
          end: node.position.end.line

        if state.inputs[name] # corresponding input has been found
          if not state.program
            die "Input and output `#name` matched, but no program given yet"
          return [
            {
              name    : name
              program : state.program
              input   : state.inputs[name]
              output  : state.outputs[name]
              input-position  : state.input-positions[name]
              output-position : state.output-positions[name]
            }
          ]

      return []

    else if \children of node
      node.children |> map visit |> fold (++), []
    else []

  mdast-syntax-tree = unified!
    .use remark-parse
    .parse contents
  tests = visit mdast-syntax-tree

  # Inspect state as it was left, to check for inputs and outputs that weren't
  # matched.
  state.inputs |> keys |> each (k) ->
    if not state.outputs[k]
      die "No matching output for input `#k`"
  state.outputs |> keys |> each (k) ->
    if not state.inputs[k]
      die "No matching input for output `#k`"


  tests |> each queue-test

  run-tests!

files = argv._

if files.length is 0
  # Read from stdin
  process.stdin
    ..on \error (e) -> die e.message
    ..pipe concat (data) ->
      test-this data
else
  files |> each (file) ->
    e, data <- fs.read-file file
    throw e if e
    test-this data
