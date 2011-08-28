# Beans

Beans is a set of tools for authoring Node modules written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/), and optionally
targeting the browser. It does something that your own Cakefile would do,
except that you don't need to copy the same Cakefile around all of your
CoffeeScript projects.

## Usage

Beans is installed with npm. To have a global up-to-date `beans` binary in
your PATH, install globally:

    $ npm install beans -g

A less convenient, but more stable solution is to have a local version of
Beans, specific for each of your authored packages. To do this, first install
Beans globally, then run `beans scripts`. This will add Beans to your
`devDependencies` and register commands like `build` and `docs` in
package.json. These commands can then be run like so:

    $ npm run-script build

A list of available commands can be obtained by typing `beans help`. In
essence, Beans provides single and continuous build routines, a test runner
using [nodeunit](https://github.com/caolan/nodeunit), and documentation
generation using [Docco](http://jashkenas.github.com/docco/).

Principal command details:

* `beans build` issues a single build according to the project configuration
  (see below). If building for the browser is required, source is concatenated
  to a single file and a minified copy is created.
* `beans watch` starts a continuous build process, rebuilding when any
  CoffeeScript file is modified.
* `beans test` tries to do a successful build and runs nodeunit tests
  afterwards. Tests should be placed in the `test` folder (or its subfolders)
  and should have the `.test.coffee` extension, in order for Beans to locate
  them.
* `beans docs` generates documentation form source. This command expects Docco
  to be installed globally (`npm install docco -g`).
* `beans publish` rebuilds everything once and runs `npm publish`.

## Configuration

Beans collects some information from `package.json` and `beans.json` files.
Most of it is used when building for the browser. Create a `beans.json` file
to override the following build defaults:

    {
      "browser": {
        "enabled": true,
        "paths": [<values of paths object>],
        "prefix": "",
        "rootModule": <same as package name>
      },
      "copyrightFrom": <current year>,
      "license": <unspecified>,
      "paths": {
        "src": "lib"
      }
    }

A sample `beans.json` file can be found in Beans own source, since Beans is
written in CoffeeScript and authored with itself, of course. Each key-value
pair is optional. In detail:

* `browser.enabled` is a switch to turn browser bundling on or off. The bundle
  is created using [Stitch](https://github.com/sstephenson/stitch) and minified
  with [UglifyJS](http://marijnhaverbeke.nl/uglifyjs).
* `browser.paths` is an array of source paths for Stitch. Relative paths are
  resolved to the current working directory. Default path is the compilation
  target paths array: this is okay, since bundling happens only after
  everything is compiled.
* `browser.prefix` is used as a prefix for browser bundle filenames.
* `browser.rootModule` is a package module that is required automatically in
  the browser and attached to the global object. Beans makes Stitch's `require`
  run in a closure, so this function won't be available. The only exposed
  module is the specified root module. Make sure it exports everything you
  need.
* `copyrightFrom` is a starting copyright year (e.g. 2010) that defaults to the
  current year. The browser bundle header comment will have a copyright notice
  featuring a span from the configured to year to current one (e.g. 2010-2011).
* `license` is the license you're using for the project. If a license is
  specified, it is displayes in the browser bundle header comment.
* `paths` is an object with source paths as keys and target paths as values.
  CoffeeScript files in source paths are going to be compiled to JavaScript and
  placed in the corresponding target paths. The folder hierarchy is kept
  intact.

## Hooks

When building CoffeeScript files, Beans allows to preprocess tokenize, parse,
and compile steps of source processing. This could be used to mangle the token
stream, AST, or resulting JavaScript source of each file, before writing to
disk.

To preprocess any step, a hook file must be created in any convenient location.
A hook file is a Node module written in CoffeeScript or JavaScript. It should
export a single function like this:

```coffeescript
module.exports = (filename, data) ->
  console.log filename  # this is the currently compiled file (target)
  data                  # this function should always return data
```

The value of `data` argument depends on the type of hook:

* The **tokenize** hook receives a token stream.
* The **parse** hook receives an AST object.
* The **compile** hook receives a JavaScript source string.

All of these values come straight from CoffeeScript's lexer, parser, and
compiler. Consequently, their format is the same as the format expected from
CoffeeScript's `tokens`, `nodes`, and `compile` methods.

To register a hook file, a `hooks` section should be added to `package.json`.
For example, to register `scripts/parse.coffee` and `scripts/compile.coffee`:

    {
      "hooks": {
        "parse": "scripts/parse",
        "compile": "scripts/compile"
      }
    }
