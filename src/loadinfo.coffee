fs   = require 'fs'
path = require 'path'

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
    begin: null
    tokenize: null
    parse: null
    compile: null
    write: null
    end: null
    bundle: null
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
module.exports = ->
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
