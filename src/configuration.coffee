# The `Configuration` class encapsulates various options for a Pow
# daemon (port numbers, directories, etc.). It's also responsible for
# creating `Logger` instances and mapping hostnames to application
# root paths.

fs                = require "fs"
path              = require "path"
async             = require "async"
Logger            = require "./logger"
{mkdirp}          = require "./util"
{sourceScriptEnv} = require "./util"
{getUserEnv}      = require "./util"

module.exports = class Configuration
  # Evaluates the user configuration script and calls the `callback`
  # with the environment variables if the config file exists. Any
  # script errors are passed along in the first argument. (No error
  # occurs if the file does not exist.)
  @loadUserConfigurationEnvironment: (callback) ->
    getUserEnv (err, env) =>
      if err
        callback err
      else
        callback null, env

  @getUserConfiguration: (callback) ->
    @loadUserConfigurationEnvironment (err, env) ->
      if err
        callback err
      else
        callback null, new Configuration env

  # A list of option names accessible on `Configuration` instances.
  @optionNames: ["bin", "dnsPort", "domains", "logRoot"]

  # Pass in any environment variables you'd like to override when
  # creating a `Configuration` instance.
  constructor: (env = process.env) ->
    @loggers = {}
    @initialize env

  # Valid environment variables and their defaults:
  initialize: (@env) ->
    # `POW_BIN`: the path to the `pow` binary. (This should be
    # correctly configured for you.)
    @bin        = env.POW_BIN         ? path.join __dirname, "../bin/pow"

    # `POW_DNS_PORT`: the UDP port Pow listens on for incoming DNS
    # queries. Defaults to `20560`.
    @dnsPort    = env.POW_DNS_PORT    ? 20560

    # `POW_DOMAINS`: the top-level domains for which Pow will respond
    # to DNS `A` queries with `127.0.0.1`. Defaults to `dev`. If you
    # configure this in your `~/.powconfig` you will need to re-run
    # `sudo pow --install-system` to make `/etc/resolver` aware of
    # the new TLDs.
    @domains    = env.POW_DOMAINS     ? env.POW_DOMAIN ? "dev,salar.silk"

    # Allow for comma-separated domain lists, e.g. `POW_DOMAINS=dev,test`
    @domains    = @domains.split?(",")    ? @domains

    # `POW_LOG_ROOT`: path to the directory that Pow will use to store
    # its log files. Defaults to `~/Library/Logs/Pow`.
    @logRoot    = env.POW_LOG_ROOT    ? libraryPath "Logs", "Pow"

    # ---
    # Precompile regular expressions for matching domain names to be
    # served by the DNS server and hosts to be served by the HTTP
    # server.
    @dnsDomainPattern  = compilePattern @domains

  # Gets an object of the `Configuration` instance's options that can
  # be passed to `JSON.stringify`.
  toJSON: ->
    result = {}
    result[key] = @[key] for key in @constructor.optionNames
    result

  # Retrieve a `Logger` instance with the given `name`.
  getLogger: (name) ->
    @loggers[name] ||= new Logger path.join @logRoot, name + ".log"

# Convenience wrapper for constructing paths to subdirectories of
# `~/Library`.
libraryPath = (args...) ->
  path.join process.env.HOME, "Library", args...

# Helper function for compiling a list of top-level domains into a
# regular expression for matching purposes.
compilePattern = (domains) ->
  /// ( (^|\.) (#{domains.join("|")}) ) \.? $ ///i
