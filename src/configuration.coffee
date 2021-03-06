# The `Configuration` class encapsulates various options for a Pow
# daemon (port numbers, directories, etc.).

fs                = require "fs"
path              = require "path"
async             = require "async"
{mkdirp}          = require "./util"
{sourceScriptEnv} = require "./util"
{getUserEnv}      = require "./util"

module.exports = class Configuration
  @getUserConfiguration: (callback) ->
    callback new Configuration

  # A list of option names accessible on `Configuration` instances.
  @optionNames: ["bin", "dnsPort", "domains"]

  # Pass in any environment variables you'd like to override when
  # creating a `Configuration` instance.
  constructor: (env = process.env) ->
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

# Helper function for compiling a list of top-level domains into a
# regular expression for matching purposes.
compilePattern = (domains) ->
  /// ( (^|\.) (#{domains.join("|")}) ) \.? $ ///i
