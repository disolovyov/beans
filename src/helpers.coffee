fs      = require 'fs'
glob    = require 'glob'
path    = require 'path'
request = require 'request'
rimraf  = require 'rimraf'
which   = require 'which'
{exec}  = require 'child_process'

# Prepare export object.
module.exports = exports = {}

# Run the specified function if a given executable is installed,
# or print a notice.
ifInstalled = (executable, fn) ->
  which executable, (err) ->
    return fn() unless err
    console.log "This task needs \"#{executable}\" to be installed and in PATH."

# Try to execute a shell command or fail with an error.
exports.tryExec = (executable, args, fn) ->
  ifInstalled executable, ->
    proc = exec executable + ' ' + args, (err) ->
      throw err if err
      fn?()
    proc.stdout.on 'data', (data) ->
      process.stdout.write data.toString()

# Try to remove a directory and its contents or fails with an error.
exports.rmrf = (path, fn) ->
  rimraf path, (err) ->
    throw err if err
    fn?()

# Safely make a directory with default permissions.
# If its parents in path are missing, they are constructed as well.
exports.makeDir = (dir) ->
  missing = []
  dir = path.resolve dir
  until path.existsSync dir
    missing.unshift dir
    dir = path.dirname dir
  for dir in missing
    fs.mkdirSync dir, 0755

# Concatenates one or more strings to target file.
exports.cat = (target, strings) ->
  fd = fs.openSync target, 'w'
  for s in strings
    fs.writeSync fd, s, null
    fs.writeSync fd, "\n", null if s.substr(-1) isnt "\n"
  fs.closeSync fd

# Fetches the contents of local or remote paths.
# Preserves order.
exports.fetch = (fn, paths) ->
  contents = []
  current = 0
  total = paths.length
  step = ->
    if ++current is total
      # Flatten the contents array
      flat = []
      for item in contents
        if typeof item is 'object'
          flat.push subitem for subitem in item
        else
          flat.push item
      # Return fetched contents.
      fn flat

  # Fetch everything.
  for path, index in paths
    do (path, index) ->
      contents[index] = ''
      if /^[a-z]+:\/\//.test path
        console.log "fetch: #{path}"
        request path, (err, response, body) ->
          throw err if err
          contents[index] = body
          step()
      else
        files = glob.globSync path
        if files.length
          contents[index] = []
          for file in files
            console.log "copy: #{file}"
            contents[index].push fs.readFileSync(file, 'utf8')
          step()

# Find files based on a global pattern.
# Call the provided function with the result, if any files are found.
exports.withFiles = (pattern, fn) ->
  files = glob.globSync pattern
  if files.length > 0
    fn files

# Ask user a question an run a callback when answered.
# The *answers* argument is an array of accepted answers.
exports.ask = (question, answers, fn) ->
  {stdin, stdout} = process
  stdout.write question + ' (' + answers.join('/') + ') '
  stdin.resume()
  stdin.on 'data', (answer) ->
    answer = answer.toString().trim()
    if answers.indexOf(answer) != -1
      stdin.pause()
      fn answer
    else
      stdout.write 'Please answer with one of: (' + answers.join('/') + ') '

# Check command argument.
exports.knownTarget = (command, target, targets) ->
  if targets.indexOf(target) == -1
    console.log "Unknown #{command} target \"#{target}\"."
    console.log "Try one of: #{targets.join ', '}."
    return false
  true

# Watch a list of files and run a callback when it's modified.
exports.watchFiles = (files, fn) ->
  for file in files
    do (file) ->
      fs.watchFile file, {persistent: true, interval: 500}, (curr, prev) ->
        if curr.mtime.getTime() isnt prev.mtime.getTime()
          fn file

# Try to run given code for a given event.
# On error, format the error message as if it's related to the given file.
exports.tryWithFile = (file, event, fn) ->
  try
    fn()
  catch err
    err.message = "When #{event} #{file}, #{err.message}"
    throw err
