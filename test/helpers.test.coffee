# Load Beans in a sandbox to access private functions.
beans = require('nodeunit').utils.sandbox 'lib/beans.js',
  __dirname: __dirname
  module: module
  require: require

module.exports =
  'fillDefaults': (test) ->
    obj = b: 4
    defaults = a: 1, b: 2, c: 3
    expected = a: 1, b: 4, c: 3
    result = beans.fillDefaults obj, defaults
    test.deepEqual result, expected, 'flat'
    test.notDeepEqual obj, result, 'immutable obj'
    test.notDeepEqual obj, result, 'immutable defaults'
    obj.c = d: 5
    defaults.c = d: 6, e: 7
    expected.c = d: 5, e: 7
    test.deepEqual beans.fillDefaults(obj, defaults), expected, 'nested'
    obj = b: false
    defaults = a: true, b: true
    expected = a: true, b: false
    test.deepEqual beans.fillDefaults(obj, defaults), expected, 'boolean'
    test.done()
