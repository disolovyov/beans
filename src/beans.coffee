coffee   = require 'coffee-script'
fs       = require 'fs'
glob     = require 'glob'
nodeunit = require 'nodeunit'
path     = require 'path'
readline = require 'readline'
rimraf   = require 'rimraf'
stitch   = require 'stitch'
uglify   = require 'uglify-js'
which    = require 'which'
{exec}   = require 'child_process'

# Defaults for package information.
defaults =
  browser:
    enabled: true
    paths: null
    prefix: ''
    rootModule: null
  copyrightFrom: (new Date).getFullYear()
  license: ''
  hooks:
    tokenize: null
    parse: null
    compile: null
  paths: null

# Fill in missing keys in an object with default values.
# Works recursively with standard types.
fillDefaults = (obj, defaults) ->
  result = {}
  for key, value of defaults
    result[key] = if obj[key]?
      if (typeof obj[key] is 'object') and (typeof value is 'object')
        fillDefaults obj[key], value
      else
        obj[key]
    else
      value
  result

# Load package information from multiple sources.
loadInfo = ->
  # Load beans.json and add unset defaults.
  try
    json = fs.readFileSync 'beans.json'
  catch e
    json = '{}'
  overrides = JSON.parse json
  info = fillDefaults overrides, defaults

  # Load hooked event handlers, if any.
  info.hookFns = {}
  for hook, module of info.hooks when module?
    info.hooks[hook] = file = path.resolve module
    info.hookFns[hook] = require file

  # Set source and target paths.
  overrides.paths = {src: 'lib'} unless overrides.paths?
  paths = {}
  for key, value of overrides.paths
    paths[path.resolve key] = path.resolve value
  info.paths = paths
  info.browser.paths ?= (pth for _, pth of info.paths)

  # Load package.json and override existing significant values.
  package = JSON.parse(fs.readFileSync 'package.json')
  for key in ['author', 'name', 'description', 'version']
    unless package[key]?
      throw new Error "Section \"#{key}\" required in package.json."
    info[key] = package[key]
  info.browser.rootModule ?= info.name
  info.browser.name = info.browser.prefix + info.name

  # Copyright year message.
  currentYear = (new Date).getFullYear()
  if currentYear > info.copyrightFrom
    copyright = info.copyrightFrom + '-' + currentYear
  else
    copyright = currentYear

  # License message.
  if info.license != ''
    license = "Released under the #{info.license}"
  else
    license = 'Contact author for licensing information'

  # Source header comment for browser bundles.
  info.headerComment = """
  /**
   * #{info.browser.name} #{info.version} (browser bundle)
   * #{info.description}
   *
   * Copyright (c) #{copyright} #{info.author}
   * #{license}
   */

  """

  # Source header and footer for browser bundles.
  info.header = "this['#{info.name}'] = (function(){"
  info.footer = """
  var module = this.require('#{info.browser.rootModule}');
  module.version = '#{info.version}';
  return module; }).call({});
  """
  info

# Run the specified function if a given executable is installed,
# or print a notice.
ifInstalled = (executable, fn) ->
  which executable, (err) ->
    return fn() unless err
    console.log "This task needs \"#{executable}\" to be installed and in PATH."

# Try to execute a shell command or fail with an error.
tryExec = (executable, args, fn) ->
  ifInstalled executable, ->
    proc = exec executable + ' ' + args, (err) ->
      throw err if err
      fn?()
    proc.stdout.on 'data', (data) ->
      process.stdout.write data.toString()

# Try to remove a directory and its contents or fails with an error.
rmrf = (path, fn) ->
  rimraf path, (err) ->
    throw err if err
    fn?()

# Safely make a directory with default permissions.
# If its parents in path are missing, they are constructed as well.
makeDir = (dir) ->
  missing = []
  dir = path.resolve dir
  until path.existsSync dir
    missing.unshift dir
    dir = path.dirname dir
  for dir in missing
    fs.mkdirSync dir, 0755

# Find files based on a global pattern.
# Call the provided function with the result, if any files are found.
withFiles = (pattern, fn) ->
  files = glob.globSync pattern
  if files.length > 0
    fn files

# Ask user a question an run a callback when answered.
# The *answers* argument is an array of accepted answers.
ask = (question, answers, fn) ->
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
knownTarget = (command, target, targets) ->
  if targets.indexOf(target) == -1
    console.log "Unknown #{command} target \"#{target}\"."
    console.log "Try one of: #{targets.join ', '}."
    return false
  true

# Watch a list of files and run a callback when it's modified.
watchFiles = (files, fn) ->
  for file in files
    do (file) ->
      fs.watchFile file, {persistent: true, interval: 500}, (curr, prev) ->
        if curr.mtime.getTime() isnt prev.mtime.getTime()
          fn file

# Try to run given code for a given event.
# On error, format the error message as if it's related to the given file.
tryWithFile = (file, event, fn) ->
  try
    fn()
  catch err
    err.message = "When #{event} #{file}, #{err.message}"
    throw err

# Compile one CoffeeScript file.
# Existing event handlers are synchronously invoked in the process.
# Each event handler is passed a subject and a context (source file).
compile = (info, file, sourcePath, targetPath) ->
  file = fs.realpathSync file
  src = fs.readFileSync file, 'utf8'

  # Create target file name.
  source = file.substr(sourcePath.length)
  target = targetPath + source.replace(/.coffee$/, '.js')

  # Run lexer and its hook.
  tryWithFile file, 'tokenizing', -> src = coffee.tokens src
  src = info.hookFns.tokenize(target, src) if info.hookFns.tokenize?

  # Run parser and its hook.
  tryWithFile file, 'parsing', -> src = coffee.nodes src
  src = info.hookFns.parse(target, src) if info.hookFns.parse?

  # Run compiler and its hook.
  tryWithFile file, 'compiling', -> src = src.compile bare: true
  src = info.hookFns.compile(target, src) if info.hookFns.compile?

  # Write compiled source to target file.
  makeDir path.dirname(target)
  fs.writeFileSync target, src
  ts = (new Date()).toLocaleTimeString()
  source = sourcePath.substr(path.resolve('.').length + 1) + source
  console.log ts + ' - compiled ' + source

# Compile all CoffeeScript sources for Node.
buildNode = (info, watch, fn) ->
  # Calculate path count.
  count = 0
  count++ for _ of info.paths

  # Iterate through, while counting compiled paths.
  compiled = 0
  for sourcePath, targetPath of info.paths
    do (sourcePath, targetPath) ->
      withFiles path.join(sourcePath, '**/*.coffee'), (files) ->
        for file in files
          compile info, file, sourcePath, targetPath

        # Set a watcher for the current path.
        if watch
          watchFiles files, (file) ->
            try
              compile info, file, sourcePath, targetPath
            catch err
              console.log err.stack

        # Run the callback only after everything is compiled.
        if ++compiled is count
          fn?()

# Use Stitch to create a browser bundle.
bundle = (info) ->
  paths = (fs.realpathSync path for path in info.browser.paths)
  stitch
    .createPackage
      paths: paths
    .compile (err, src) ->
      throw err if err
      makeDir 'build'
      makeDir 'build/' + info.version
      dir = fs.realpathSync 'build/' + info.version
      fname = dir + '/' + info.browser.name
      src = info.header + src + info.footer
      fs.writeFileSync fname + '.js', info.headerComment + src
      fs.writeFileSync fname + '.min.js', info.headerComment + uglify(src)
      try fs.unlinkSync 'build/edge'
      fs.symlinkSync dir + '/', 'build/edge'

# Compile all CoffeeScript sources for the browser.
buildBrowser = (info, watch) ->
  bundle info
  if watch
    paths = (path.join(pth, '**/*.{coffee,js}') for pth in info.browser.paths)
    watchFiles glob.globSync("{#{paths.join()}}"), ->
      bundle info

# Compile CoffeeScript source for Node and browsers.
build = (fn) ->
  info = loadInfo()
  buildNode info, false, ->
    buildBrowser info if info.browser.enabled
    fn?()

# Remove generated directories to allow for a clean build
# or just tidy things up.
clean = (target) ->
  target ?= 'all'
  return unless knownTarget 'clean', target, ['build', 'docs', 'all']
  info = loadInfo()
  paths = (pth for _, pth of info.paths)
  switch target
    when 'build' then rmrf dir for dir in paths.concat('build')
    when 'docs' then rmrf 'docs'
    when 'all' then rmrf dir for dir in paths.concat('build', 'docs')
  return

# Generate documentation files using Docco.
docs = ->
  info = loadInfo()
  paths = (path.join(pth, '**/*.coffee') for pth of info.paths)
  paths.push pth + '.{coffee,js}' for _, pth of info.hooks when pth
  console.log paths
  withFiles "{#{paths.join()}}", (files) ->
    tryExec('docco', '"' + files.join('" "') + '"')

# Display command help.
help = ->
  for name, command of commands
    console.log "beans #{name}\t#{command[1]}"

# Build everything and run `npm publish`.
publish = ->
  build ->
    tryExec 'npm', 'publish'

# Register beans in package.json scripts.
scripts = ->
  ask 'This will modify package.json. Proceed?', ['y', 'n'], (answer) ->
    if answer == 'y'
      package = JSON.parse(fs.readFileSync 'package.json')
      deps = package.devDependencies ||= {}
      deps.beans ||= '~' + ver
      scripts = package.scripts ||= {}
      for script in ['build', 'clean', 'docs', 'test', 'watch']
        scripts[script] = 'beans ' + script
      scripts.prepublish = 'beans build'
      fs.writeFileSync 'package.json', JSON.stringify(package, null, 2) + "\n"

# Build everything and run tests using nodeunit.
test = ->
  build ->
    withFiles 'test/**/*.test.coffee', (files) ->
      nodeunit.reporters.default.run files

# Get version information.
packageFile = path.resolve(__dirname, '../package.json')
ver = JSON.parse(fs.readFileSync(packageFile)).version

# Display version information.
version = ->
  console.log 'Beans ' + ver

# Build everything once, then watch for changes.
watch = ->
  info = loadInfo()
  buildNode info, true, ->
    buildBrowser info, true if info.browser.enabled

# Supported commands list.
commands =
  build:   [ build   , 'Compile CoffeScript source for enabled targets.' ]
  clean:   [ clean   , 'Remove generated directories and tidy things up.' ]
  docs:    [ docs    , 'Generate documentation files using Docco.' ]
  help:    [ help    , 'Display help (this text).' ]
  publish: [ publish , 'Build everything and run npm publish.' ]
  scripts: [ scripts , 'Register beans in package.json scripts.' ]
  test:    [ test    , 'Build everything and run tests using nodeunit.' ]
  version: [ version , 'Display current Beans version.' ]
  watch:   [ watch   , 'Build everything once, then watch for changes.' ]

# Run the console command.
run = ->
  args = process.argv.slice(2)
  if args.length == 0
    version()
    help()
  else if commands[args[0]]?
    commands[args[0]][0](args.slice(1)...)
  else
    console.log "Don't know how to \"#{args[0]}\"."

# Exports commands for in-Node use and command entry point.
module.exports =
  commands: commands
  run: run
  version: ver
