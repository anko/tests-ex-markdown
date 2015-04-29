#!/usr/bin/env lsc
{ exec-sync } = require \child_process
test = require \tape

txm = (md-string) ->
  try
    return stdout : exec-sync "./index.ls" { input : md-string }
  catch e
    return e
txm-expect = (name, md-string, expected-exit, expected-stdout, expected-stderr) ->
  test name, (t) ->
    { stdout, status, stderr } = txm md-string

    if expected-exit
      status `t.equals` expected-exit
    if expected-stdout
      stdout.to-string! `t.equals` expected-stdout
    if expected-stderr
      stderr?to-string! `t.equals` expected-stderr

    t.end!

#
# These tests are so meta.
#

txm-expect do
  "simple cat passthrough"
  """
  <!-- !test program cat -->
  <!-- !test input 1 -->

      hi

  <!-- !test output 1 -->

      hi

  """
  0
  """
  TAP version 13
  # testxmd test
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """

txm-expect do
  "no program specified"
  """
  <!-- !test input 1 -->

      hi

  <!-- !test output 1 -->

      hi

  """
  1
  "" # No stdout
  "Input and output `1` matched, but no program given yet\n"

txm-expect do
  "input without matching output"
  """
  <!-- !test program cat -->
  <!-- !test input 1 -->

      hi
  """
  1
  "" # No stdout
  "No matching output for input `1`\n"

txm-expect do
  "output without matching input"
  """
  <!-- !test program cat -->
  <!-- !test output 1 -->

      hi
  """
  1
  "" # No stdout
  "No matching input for output `1`\n"

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

  <!-- !test input 1 -->
  ```ls
  console.log("yo");
  ```

  To get this:

  <!-- !test output 1 -->
  ```html
  hi
  yo
  ```
  """
  0

txm-expect do
  "output defined before input"
  """
  <!-- !test program cat -->
  <!-- !test output 1 -->

      hi

  <!-- !test input 1 -->

      hi

  """
  0
  """
  TAP version 13
  # testxmd test
  ok 1 should be equal

  1..1
  # tests 1
  # pass  1

  # ok


  """
  ""
