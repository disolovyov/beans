# Beans

Beans is a set of tools for authoring Node modules written in
[CoffeeScript](http://jashkenas.github.com/coffee-script/), and optionally
targeting the browser. It does something that your own Cakefile would do,
except that you don't need to copy the same Cakefile around all of your
CoffeeScript projects.

## Usage

Beans is installed with npm:

    $ npm install beans

This should install a `beans` binary. A list of available commands can be
obtained by typing `beans help`. In essence, Beans provides single and
continuous build routines, as well as documentation generation using
[Docco](http://jashkenas.github.com/docco/).

If you want to generate documentation from your CoffeeScript source, Beans
expects Docco to be installed globally (`npm install docco -g`).

## Configuration

When building for the browser, Beans collects some information from
`package.json` and `beans.json` files. Create a `beans.json` file to override
the following build defaults:

    {
      "browser": true,
      "browserPrefix": "",
      "copyright": <current year>,
      "license": <unspecified>
    }

A sample `beans.json` file can be found in Beans own source, since Beans is
written in CoffeeScript and authored with itself, of course. Each key-value
pair is optional. In detail:

* `browser` is a switch to turn browser bundling on or off. The bundle is
  created using [Stitch](https://github.com/sstephenson/stitch) and minified
  with [UglifyJS](http://marijnhaverbeke.nl/uglifyjs).
* `browserPrefix` is used as a prefix for browser bundle filenames.
* `copyright` is a copyright year string (e.g. 2010-2011) that defaults to the
  current year. It is used in the browser bundle header comment.
* `license` is the license you're using for the project. If a license is
  specified, it is displayes in the browser bundle header comment.
