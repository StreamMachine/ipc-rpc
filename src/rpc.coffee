_       = require "underscore"
UUID    = require "uuid"
debug   = require("debug")("rpc")

module.exports = class RPC extends require("events").EventEmitter
    constructor: (@interface,opts,cb) ->
        if !@interface?.send?
            throw new Error "Invalid RPC interface. No send function."

        debug "#{process.pid}: Starting up RPC client/server"

        @_pending   = []
        @_requests  = {}

        @_listening = true

        if _.isFunction(opts)
            cb = opts
            opts = {}

        @_timeout = opts.timeout || 2000

        # -- were we given any functions? -- #

        @functions = opts.functions || {}

        # -- start listening -- #

        @_mListener = (msg,handle) =>
            if msg?.type == "_rpc"
                debug "#{process.pid}: Incoming message of type _rpc", msg, handle?
                # it's for us...

                if msg.reply_id
                    # look for the sender
                    @_response msg, handle

                else
                    # incoming request
                    @_consumeRequest msg, handle

        @interface.on "message", @_mListener

        cb? null, @

    #----------

    disconnect: ->
        return true if !@_listening
        @interface.removeListener "message", @_mListener

    #----------

    reconnect: ->
        return true if @_listening
        @interface.on "message", @_mListener

    #----------

    request: (key,args...,cb) ->
        # generate a UUID for this request
        id = UUID.v4()

        msg     = args[0]
        handle  = args[1]
        opts    = args[2]

        # push the request
        @_pending.push id:id, key:key, msg:msg, handle:handle, opts:opts, cb:cb
        @_runQueue()

    #----------

    _consumeRequest: (msg,handle) ->
        # -- Set up our response function -- #

        cb = _.once (err,obj,handle) =>
            # -- Send Reponse -- #
            debug "#{process.pid}: Sending response for #{msg.id}.", handle?
            @_pending.push reply_id:msg.id, msg:obj, err:err?.message, err_stack:err?.stack, handle:handle
            @_runQueue()

        # -- Try calling our local function -- #

        d = require("domain").create()
        d.on "error", (err) => cb err

        d.run =>
            try
                # -- Look for a function map -- #

                if @functions?[ msg.key ]
                    @functions[ msg.key ] msg.msg, handle, cb

                # -- see if we have a listener for this event -- #

                else
                    if @listeners(msg.key).length > 0
                        # emit
                        @emit msg.key, msg.msg, handle, cb

                    else
                        # return error
                        cb new Error "NO_LISTENER: No listener registered for #{msg.key}."

            # TODO: Add timeout to handle case where we emit and get
            # nothing back.
            catch err
                cb err

    #----------

    _runQueue: ->
        request = @_pending.shift()

        if !request
            return false

        if request.id
            timeout = setTimeout =>
                # if we fail to get an response inside the timeout time,
                # consider the request failed and call the callback
                if @_requests[request.id]
                    process.nextTick =>
                        @_requests[request.id].callback? new Error "TIMEOUT: Timeout waiting for RPC response to #{request.key} command."
                        delete @_requests[request.id]
            , request.opts?.timeout || @_timeout

            # create a hash entry to map the response
            @_requests[ request.id ] = callback:request.cb, timeout:timeout if request.id

        # send our request
        @interface.send
            type:       "_rpc"
            key:        request.key
            id:         request.id
            reply_id:   request.reply_id
            msg:        request.msg
            err:        request.err
            err_stack:  request.err_stack
        , request.handle

        @_runQueue()

    #----------

    _response: (msg,handle) ->
        h = @_requests[ msg.reply_id ]

        if !h
            @emit "debug", "Got unmatched response for #{ msg.reply_id }. Could be a call that timed out."
            return false

        debug "#{process.pid}: Handling message response for #{ msg.reply_id}.", msg, handle?

        # stop the timeout
        clearTimeout h.timeout

        err = undefined
        if msg.err
            err = new Error msg.err
            err.stack = msg.err_stack

        # clean up
        debug "#{process.pid}: Deleting callback for request #{ msg.reply_id }"
        delete @_requests[ msg.reply_id ]

        h.callback? err, msg.msg, handle



    #----------

