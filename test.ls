#!/usr/bin/env lsc
{ spawn-sync } = require \child_process
test = require \tape

txm-expect = (name, md-string, expected={}) ->

  txm = (md-string) ->
    try
      # If everything goes as planned, return just an object with the stdout
      # property.
      return spawn-sync do
        "lsc"
        <[ index.ls -- --format=tap ]>
        input : md-string, stdio: [ null, null, null ]
    catch e
      throw e

  test name, (t) ->
    { stdout, status, stderr } = txm md-string

    if not status? then status := 0
    if not stderr? then stderr := ''

    if expected.exit?
      t.equals do
        status
        expected.exit
        "exit code is #{expected.exit}"
    if expected.stdout?
      t.equals do
        stdout.to-string!
        expected.stdout
        "stdout matches"
    if expected.stderr?
      t.equals do
        stderr.to-string!
        expected.stderr
        "stderr matches"

    t.end!

txm-expect do
  "simple cat passthrough"
  """
  <!-- !test program cat -->
  <!-- !test in 1 -->

      hi

  <!-- !test out 1 -->

      hi

  """
  exit: 0
  stdout: """
  TAP version 13
  # 1
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "same line comments, some irrelevant"
  """
  <!-- !test program cat --><!-- !test in 1 --><!-- something else -->

      hi

  <!-- !test out 1 --><!-- hello! -->

      hi

  """
  exit: 0
  stdout: """
  TAP version 13
  # 1
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "no program specified"
  """
  <!-- !test in 1 -->

      hi

  <!-- !test out 1 -->

      hi

  """
  exit: 1
  stdout: ""
  stderr: "Input and output `1` matched, but no program given yet\n"

txm-expect do
  "input without matching output"
  """
  <!-- !test program cat -->
  <!-- !test in 1 -->

      hi
  """
  exit: 1
  stdout: ""
  stderr: "No matching output for input `1`\n"

txm-expect do
  "output without matching input"
  """
  <!-- !test program cat -->
  <!-- !test out 1 -->

      hi
  """
  exit: 1
  stdout: ""
  stderr: "No matching input for output `1`\n"

txm-expect do
  "redirection in program"
  """
  # whatxml

  XML/HTML templating with [LiveScript][1]'s [cascade][2] syntax.

  <!-- !test program
  sed '1s/^/console.log("hi");/' \\
  | node \\
  | head -c -1
  -->

  <!-- !test in 1 -->

  ```ls
  console.log("yo");
  ```

  To get this:

  <!-- !test out 1 -->

  ```html
  hi
  yo
  ```
  """
  exit: 0

txm-expect do
  "output defined before input"
  """
  <!-- !test program cat -->
  <!-- !test out 1 -->

      hi

  <!-- !test in 1 -->

      hi

  """
  exit: 0
  stdout: """
  TAP version 13
  # 1
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """
  stderr: ""

txm-expect do
  "interleaved tests"
  """
  <!-- !test program cat -->
  <!-- !test in 1 -->

      one

  <!-- !test in 2 -->

      two

  <!-- !test out 1 -->

      one

  <!-- !test out 2 -->

      two

  """
  exit: 0
  stdout: """
  TAP version 13
  # 1
  ok 1 should be equal
  # 2
  ok 2 should be equal

  1..2
  # tests 2
  # pass  2

  # ok


  """
  stderr: ""

txm-expect do
  "Multiple inputs with conflicting id"
  """
  <!-- !test program cat -->
  <!-- !test in 1 -->

      one

  <!-- !test in 1 -->

      two

  <!-- !test out 1 -->

      one

  <!-- !test in 1 -->

      two

  """
  exit: 1
  stdout: ""
  stderr: "Multiple inputs with name `1`\n"

txm-expect do
  "Multiple outputs with conflicting id"
  """
  <!-- !test program cat -->
  <!-- !test out 1 -->

      one

  <!-- !test out 1 -->

      two

  <!-- !test in 1 -->

      one

  <!-- !test out 1 -->

      two

  """
  exit: 1
  stdout: ""
  stderr: "Multiple outputs with name `1`\n"

txm-expect do
  "Long test name"
  """
  <!-- !test program cat -->
  <!-- !test in something fairly long going in here -->

      hi

  <!-- !test out something fairly long going in here -->

      hi
  """
  exit: 0
  """
  TAP version 13
  # something fairly long going in here
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "Test name in Unicode"
  """
  <!-- !test program cat -->
  <!-- !test in 本当にいいんですか -->

      hi

  <!-- !test out 本当にいいんですか -->

      hi
  """
  exit: 0
  stdout: """
  TAP version 13
  # 本当にいいんですか
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "Whitespace at ends is ignored when matching inputs and outputs"
  """
  <!-- !test program cat -->
  <!-- !test in           spacing         -->

      hi

  <!-- !test out spacing-->

      hi
  """
  exit: 0
  stdout: """
  TAP version 13
  # spacing
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "Whitespace inside input/output name is significant"
  """
  <!-- !test program cat -->
  <!-- !test in big cat -->

      hi

  <!-- !test out big               cat -->

      hi
  """
  exit: 1
  stdout: ""
  "No matching output for input `big cat`\n"


txm-expect do
  "Escaping dashes works in all commands"
  """
  <!-- !test program echo -\\-version > /dev/null ; cat -->
  <!-- !test in \\-\\- -->

      hi

  <!-- !test out -\\- -->

      hi
  """
  exit: 0
  stdout: """
  TAP version 13
  # --
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "failures' stderr is displayed"
  """
  <!-- !test program >&2 echo "error goes here"; exit 1 -->
  <!-- !test in x -->

      hi

  <!-- !test out x -->

      hi
  """
  exit: 1
  stdout: ''
  stderr: """
  Command failed: >&2 echo "error goes here"; exit 1
  error goes here


  """
