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
      "browser": true,
      "browserPaths": ['src'],
      "browserPrefix": "",
      "browserRootModule": <same as package name>,
      "copyrightFrom": <current year>,
      "license": <unspecified>,
      "sourcePath": 'src'
    }

A sample `beans.json` file can be found in Beans own source, since Beans is
written in CoffeeScript and authored with itself, of course. Each key-value
pair is optional. In detail:

* `browser` is a switch to turn browser bundling on or off. The bundle is
  created using [Stitch](https://github.com/sstephenson/stitch) and minified
  with [UglifyJS](http://marijnhaverbeke.nl/uglifyjs).
* `browserPaths` is an array of source paths for Stitch. Relative paths are
  resolved to the current working directory.
* `browserPrefix` is used as a prefix for browser bundle filenames.
* `browserRootModule` is a package module that is required automatically in
  the browser and attached to the global object. Beans makes Stitch's `require`
  run in a closure, so this function won't be available. The only exposed
  module is the specified root module. Make sure it exports everything you
  need.
* `copyrightFrom` is a starting copyright year (e.g. 2010) that defaults to the
  current year. The browser bundle header comment will have a copyright notice
  featuring a span from the configured to year to current one (e.g. 2010-2011).
* `license` is the license you're using for the project. If a license is
  specified, it is displayes in the browser bundle header comment.
* `sourcePath` is the CoffeeScript source path. All of its contents are going
  to be compiled to JavaScript and placed in `lib`. The folder hierarchy is
  kept intact.
