# Stripped-down OAuth 2 implementation that works with the Dropbox API server.
class Dropbox.Util.Oauth
  # Creates an Oauth instance that manages an application's key and token data.
  #
  # @param {Object} options the following properties
  # @option options {String} key the Dropbox application's key (client
  #   identifier, in OAuth2 vocabulary)
  # @option options {String} secret the Dropbox application's secret (client
  #   secret, in OAuth vocabulary); browser-side applications should not pass
  #   in a client secret
  constructor: (options) ->
    @_id = null
    @_secret = null
    @_stateParam = null
    @_authCode = null
    @_token = null
    @_tokenKey = null
    @_tokenKid = null
    @_appHash = null
    @_loaded = null
    @setCredentials options

  # Resets the credentials used by this Oauth instance.
  #
  # @see Dropbox.Util.Oauth#constructor for options
  setCredentials: (options) ->
    if options.key
      @_id = options.key
    else
      unless options.token
        throw new Error 'No API key supplied'
      @_id = null
    @_secret = options.secret or null
    @_appHash = null
    @_loaded = true

    @reset()
    if options.token
      @_token = options.token
      if options.tokenKey
        @_tokenKey = options.tokenKey
        @_tokenKid = options.tokenKid
    else if options.oauthCode
      @_authCode = options.oauthCode
    else if options.oauthStateParam
      @_stateParam = options.oauthStateParam

  # The credentials used by this Oauth instance.
  #
  # @return {Object<String, String>} an object that can be passed into
  #   Dropbox.Util.Oauth#constructor or into Dropbox.Util.Oauth#reset to obtain
  #   a new instance that uses the same credentials
  credentials: ->
    returnValue = {}
    returnValue.key = @_id if @_id
    returnValue.secret = @_secret if @_secret
    if @_token isnt null
      returnValue.token = @_token
      if @_tokenKey
        returnValue.tokenKey = @_tokenKey
        returnValue.tokenKid = @_tokenKid
    else if @_authCode isnt null
      returnValue.oauthCode = @_authCode
    else if @_stateParam isnt null
      returnValue.oauthStateParam = @_stateParam
    returnValue

  # The authentication process step that this instance's credentials are for
  #
  # @return {Number} one of the constants defined in Dropbox.Client, such as
  #    Dropbox.Client.DONE
  step: ->
    if @_token isnt null
      Dropbox.Client.DONE
    else if @_authCode isnt null
      Dropbox.Client.AUTHORIZED
    else if @_stateParam isnt null
      if @_loaded
        Dropbox.Client.PARAM_LOADED
      else
        Dropbox.Client.PARAM_SET
    else
      Dropbox.Client.RESET

  # Sets the "state" parameter value for the following /authorize request.
  #
  # @param {String} stateParam the value of the "state" parameter
  setAuthStateParam: (stateParam) ->
    if @_id is null
      throw new Error('No API key supplied, cannot do authorization')
    @reset()
    @_loaded = false
    @_stateParam = stateParam
    @

  # Verifies the "state" query parameter in an /authorize redirect.
  #
  # If this method returns false, the /authorize redirect should be ignored.
  #
  # @param {String} stateParam the value of the "state" query parameter in the
  #   request caused by an /authorize HTTP redirect
  # @return {Boolean} true if the given value matches the "state" parameter
  #   sent to /authorize; false if no /authorize redirect was expected, or if
  #   the value doesn't match
  checkAuthStateParam: (stateParam) ->
    (@_stateParam is stateParam) and (@_stateParam isnt null)

  # @private
  # This should only be called by Dropbox.Client#authenticate. All other code
  # should use Dropbox.Util.Oauth#checkAuthStateParam.
  #
  # @return {String} the "state" query parameter set by setAuthStateParam
  authStateParam: ->
    @_stateParam

  # Assimilates the information in an /authorize redirect's query parameters.
  #
  # The parameters may contain an access code, which will bring the Oauth
  # instance in the AUTHORIZED state, or may contain an access token, which
  # will bring the Oauth instance in the DONE state.
  #
  # @param {Object<String, String>} queryParams the query parameters that
  #   contain an authorization code or access token; these should be query
  #   parameters received from an /authorize redirect
  # @return {Boolean} true if the query parameters contained information about
  #   an OAuth 2 authorization code or access token; false if no useful
  #   information was found and this instance's state was not changed
  #
  # @see RFC 6749 for authorization codes
  # @see RFC 6750 for OAuth 2.0 Bearer Tokens
  # @see draft-ietf-oauth-v2-http-mac for OAuth 2.0 MAC Tokens
  processRedirectParams: (queryParams) ->
    if queryParams.code
      if @_id is null
        throw new Error('No API key supplied, cannot do Authorization Codes')
      @reset()
      @_loaded = false
      @_authCode = queryParams.code
      return true

    tokenType = queryParams.token_type
    if tokenType
      if tokenType isnt 'bearer' and tokenType isnt 'mac'
        throw new Error("Unimplemented token type #{tokenType}")

      @reset()
      @_loaded = false
      if tokenType is 'mac'
        if queryParams.mac_algorithm isnt 'hmac-sha-1'
          throw new Error(
              "Unimplemented MAC algorithms #{queryParams.mac_algorithm}")
        @_tokenKey = queryParams.mac_key
        @_tokenKid = queryParams.kid
      @_token = queryParams.access_token
      return true

    false

  # Computes the value of the OAuth 2-specified Authorization HTTP header.
  #
  # OAuth 2 supports two methods of passing authorization information. The
  # Authorization header (implemented by this method) is the recommended
  # method, and form parameters (implemented by addAuthParams) is the fallback
  # method. The fallback method is useful for avoiding CORS preflight requests.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #   'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #   that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #   request parameters
  # @return {String} the value to be used for the Authorization HTTP header
  authHeader: (method, url, params) ->
    if @_token is null
      # RFC 6749: OAuth 2.0 (Client Authentication, Protocol Endpoints)
      userPassword = if @_secret is null
        Dropbox.Util.btoa("#{@_id}:")
      else
        Dropbox.Util.btoa("#{@_id}:#{@_secret}")
      "Basic #{userPassword}"
    else
      if @_tokenKey is null
        # RFC 6750: Bearer Tokens.
        "Bearer #{@_token}"
      else
        # IETF draft-ietf-oauth-v2-http-mac
        macParams = @macParams method, url, params
        "MAC kid=#{macParams.kid} ts=#{macParams.ts} " +
              "access_token=#{@_token} mac=#{macParams.mac}"

  # Generates OAuth-required form parameters.
  #
  # OAuth 2 supports two methods of passing authorization information. The
  # Authorization header (implemented by authHeader) is the recommended method,
  # and form parameters (implemented by this method) is the fallback method.
  # The fallback method is useful for avoiding CORS preflight requests.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #   'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #   that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #   request parameters; this parameter will be mutated
  # @return {Object} the value of the params argument
  addAuthParams: (method, url, params) ->
    if @_token is null
      # RFC 6749: OAuth 2.0 (Client Authentication, Protocol Endpoints)
      params.client_id = @_id
      if @_secret isnt null
        params.client_secret = @_secret
    else
      if @_tokenKey isnt null
        # IETF draft-ietf-oauth-v2-http-mac
        macParams = @macParams method, url, params
        params.kid = macParams.kid
        params.ts = macParams.ts
        params.mac = macParams.mac
      # RFC 6750: Bearer Tokens and IETF draft-ietf-oauth-v2-http-mac
      params.access_token = @_token
    params

  # The query parameters to be used in an /oauth2/authorize URL.
  #
  # @param {String} responseType one of the /authorize response types
  #   implemented by dropbox.js
  # @param {?String} redirectUrl the URL that the user's browser should be
  #   redirected to in order to perform an /oauth2/authorize request
  # @return {Object<String, String>} the query parameters for the
  #   /oauth2/authorize URL
  #
  # @see Dropbox.AuthDriver#authType
  # @see RFC 6749 for the authorization process in OAuth 2.0
  authorizeUrlParams: (responseType, redirectUrl) ->
    if responseType isnt 'token' and responseType isnt 'code'
      throw new Error("Unimplemented /authorize response type #{responseType}")
    # NOTE: these parameters will never contain the client secret
    params =
        client_id: @_id, state: @_stateParam, response_type: responseType
    params.redirect_uri = redirectUrl if redirectUrl
    params

  # The query parameters to be used in an /oauth2/token URL.
  #
  # @param {?String} redirectUrl the URL that the user's browser was redirected
  #   to after performing the /oauth2/authorize request; this must be the same
  #   as the redirectUrl parameter passed to authorizeUrlParams
  # @return {Object<String, String>} the query parameters for the /oauth2/token
  #   URL
  accessTokenParams: (redirectUrl) ->
    params = { grant_type: 'authorization_code', code: @_authCode }
    params.redirect_uri = redirectUrl if redirectUrl
    params

  # Extracts the query parameters in an /authorize redirect URL.
  #
  # This is provided as a helper for dropbox.js OAuth drivers. It is not a
  # general-purpose URL parser, but it will handle the URLs generated by the
  # Dropbox API server.
  @queryParamsFromUrl: (url) ->
    match = /^[^?#]+(\?([^\#]*))?(\#(.*))?$/.exec url
    return {} unless match
    query = match[2] or ''
    fragment = match[4] or ''
    fragmentOffset = fragment.indexOf '?'
    if fragmentOffset isnt -1
      fragment = fragment.substring fragmentOffset + 1
    params = {}
    for kvp in query.split('&').concat fragment.split('&')
      offset = kvp.indexOf '='
      continue if offset is -1
      params[decodeURIComponent(kvp.substring(0, offset))] =
          decodeURIComponent kvp.substring(offset + 1)
    params

  # The parameters of an OAuth 2 MAC authenticator.
  #
  # @private
  # This is called internally by addHeader and addAuthParams when OAuth 2 MAC
  # tokens are in use.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #   'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #   that receives the request
  # @param {Object} queryParams an associative array (hash) containing the
  #   query parameters in the HTTP request URL
  # @return {Object<String, String>} the MAC authenticator attributes
  macParams: (method, url, params) ->
    macParams = { kid: @_tokenKid, ts: Dropbox.Util.Oauth.timestamp() }

    # TODO(pwnall): upgrade to the OAuth 2 MAC tokens algorithm
    string = method.toUpperCase() + '&' +
      Dropbox.Util.Xhr.urlEncodeValue(url) + '&' +
      Dropbox.Util.Xhr.urlEncodeValue(Dropbox.Util.Xhr.urlEncode(params))
    macParams.mac = Dropbox.Util.hmac string, @_tokenKey

    macParams

  # @private
  # Used by Dropbox.Client#appHash
  #
  # @return {String} a string that uniquely identifies the OAuth application
  appHash: ->
    return @_appHash if @_appHash
    @_appHash = Dropbox.Util.sha1(@_id).replace(/\=/g, '')

  # Drops all user-specific OAuth information.
  #
  # This method gets this instance in the RESET auth step.
  #
  # @return this, for easy call chaining
  reset: ->
    @_stateParam = null
    @_authCode = null
    @_token = null
    @_tokenKey = null
    @_tokenKid = null
    @

  # The timestamp used for an OAuth 2 request.
  #
  # @private
  # This method is separated out for testing purposes.
  #
  # @return {Number} a timestamp suitable for use in computing OAuth 2 MAC
  #   authenticators
  @timestamp: ->
    Math.floor(Date.now() / 1000)

  # Generates a random OAuth 2 authentication state parameter value.
  #
  # This is used for authentication drivers that do not implement
  # Dropbox.AuthDriver#getStateParam.
  #
  # @return {String} a randomly generated parameter
  @randomAuthStateParam: ->
    ['oas', Date.now().toString(36), Math.random().toString(36)].join '_'

# Date.now() workaround for Internet Explorer 8.
unless Date.now?
  Dropbox.Util.Oauth.timestamp = ->
    Math.floor((new Date()).getTime() / 1000)
