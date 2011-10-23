coffee   = require 'coffee-script'
fs       = require 'fs'
glob     = require 'glob'
h        = require './helpers'
loadinfo = require './loadinfo'
nodeunit = require 'nodeunit'
path     = require 'path'
readline = require 'readline'
stitch   = require 'stitch'
uglify   = require 'uglify-js'

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
  h.tryWithFile file, 'tokenizing', -> src = coffee.tokens src
  hookResult = info.hookFns.tokenize? target, src
  src = hookResult if hookResult?

  # Run parser and its hook.
  h.tryWithFile file, 'parsing', -> src = coffee.nodes src
  hookResult = info.hookFns.parse? target, src
  src = hookResult if hookResult?

  # Run compiler and its hook.
  h.tryWithFile file, 'compiling', -> src = src.compile bare: true
  hookResult = info.hookFns.compile? target, src
  src = hookResult if hookResult?

  # Write compiled source to target file and run a hook.
  h.makeDir path.dirname(target)
  fs.writeFileSync target, src
  info.hookFns.write? target, src

  ts = (new Date()).toLocaleTimeString()
  source = sourcePath.substr(path.resolve('.').length + 1) + source
  console.log ts + ' - compiled ' + source

# Compile all CoffeeScript sources for Node.
buildNode = (info, watch, fn) ->
  # Calculate path count.
  count = 0
  count++ for _ of info.paths

  # Run a hook before the build process starts.
  info.hookFns.begin?()

  # Iterate through, while counting compiled paths.
  compiled = 0
  for sourcePath, targetPath of info.paths
    do (sourcePath, targetPath) ->
      h.withFiles path.join(sourcePath, '**/*.coffee'), (files) ->
        for file in files
          compile info, file, sourcePath, targetPath

        # Set a watcher for the current path.
        if watch
          h.watchFiles files, (file) ->
            try
              compile info, file, sourcePath, targetPath
            catch err
              console.log err.stack

        # Run the end hook and callback only after everything is compiled.
        if ++compiled is count
          info.hookFns.end?()
          fn?()

# Use Stitch to create a browser bundle.
bundle = (info) ->
  paths = (fs.realpathSync path for path in info.browser.paths)
  stitch
    .createPackage
      paths: paths
    .compile (err, src) ->
      throw err if err
      h.makeDir 'build'
      h.makeDir 'build/' + info.version
      dir = fs.realpathSync 'build/' + info.version
      fname = dir + '/' + info.browser.name
      src = info.header + src + info.footer
      cleanFilename = fname + '.js'
      cleanSource = info.headerComment + src
      fs.writeFileSync cleanFilename, cleanSource
      fs.writeFileSync fname + '.min.js', info.headerComment + uglify(src)
      try fs.unlinkSync 'build/edge'
      fs.symlinkSync dir + '/', 'build/edge'

      # Run the bundle hook.
      info.hookFns.bundle? cleanFilename, cleanSource

# Compile all CoffeeScript sources for the browser.
buildBrowser = (info, watch) ->
  bundle info
  if watch
    paths = (path.join(pth, '**/*.{coffee,js}') for pth in info.browser.paths)
    h.watchFiles glob.globSync("{#{paths.join()}}"), ->
      bundle info

# Compile CoffeeScript source for Node and browsers.
build = (fn) ->
  info = loadinfo()
  buildNode info, false, ->
    buildBrowser info if info.browser.enabled
    fn?()

# Remove generated directories to allow for a clean build
# or just tidy things up.
clean = (target) ->
  target ?= 'all'
  return unless h.knownTarget 'clean', target, ['build', 'docs', 'all']
  info = loadinfo()
  paths = (pth for _, pth of info.paths)
  switch target
    when 'build' then h.rmrf dir for dir in paths.concat('build')
    when 'docs' then h.rmrf 'docs'
    when 'all' then h.rmrf dir for dir in paths.concat('build', 'docs')
  return

# Generate documentation files using Docco.
docs = ->
  info = loadinfo()
  paths = (path.join(pth, '**/*.coffee') for pth of info.paths)
  paths.push pth + '.{coffee,js}' for _, pth of info.hooks when pth
  h.withFiles "{#{paths.join()}}", (files) ->
    h.tryExec('docco', '"' + files.join('" "') + '"')

# Display command help.
help = ->
  for name, command of commands
    console.log "beans #{name}\t#{command[1]}"

# Fetch local and remote includes.
include = ->
  info = loadinfo()
  for target, sources of info.browser.include
    do (target, sources) ->
      fn = (contents) ->
        target = path.resolve target
        h.makeDir path.dirname(target)
        h.cat target, contents
      sources = [sources] unless Array.isArray sources
      h.fetch fn, sources
  return

# Build everything and run `npm publish`.
publish = ->
  build ->
    h.tryExec 'npm', 'publish'

# Register beans in package.json scripts.
scripts = ->
  h.ask 'This will modify package.json. Proceed?', ['y', 'n'], (answer) ->
    if answer == 'y'
      package = JSON.parse(fs.readFileSync 'package.json')
      deps = package.devDependencies ||= {}
      deps.beans ||= '~' + ver
      scripts = package.scripts ||= {}
      for script in ['build', 'clean', 'docs', 'include', 'test', 'watch']
        scripts[script] = 'beans ' + script
      scripts.prepublish = 'beans build'
      fs.writeFileSync 'package.json', JSON.stringify(package, null, 2) + "\n"

# Build everything and run tests using nodeunit.
test = ->
  build ->
    h.withFiles 'test/**/*.test.coffee', (files) ->
      nodeunit.reporters.default.run files

# Get version information.
packageFile = path.resolve(__dirname, '../package.json')
ver = JSON.parse(fs.readFileSync(packageFile)).version

# Display version information.
version = ->
  console.log 'Beans ' + ver

# Build everything once, then watch for changes.
watch = ->
  info = loadinfo()
  buildNode info, true, ->
    buildBrowser info, true if info.browser.enabled

# Supported commands list.
commands =
  build:   [ build   , 'Compile CoffeScript source for enabled targets.' ]
  clean:   [ clean   , 'Remove generated directories and tidy things up.' ]
  docs:    [ docs    , 'Generate documentation files using Docco.' ]
  help:    [ help    , 'Display help (this text).' ]
  include: [ include , 'Fetch local and remote includes.' ]
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
