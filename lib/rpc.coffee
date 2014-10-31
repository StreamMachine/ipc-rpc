_       = require "underscore"
UUID    = require "uuid"

module.exports = class RPC extends require("events").EventEmitter
    constructor: (@interface,opts,cb) ->
        if !@interface?.send?
            throw new Error "Invalid RPC interface. No send function."

        @_pending   = []
        @_requests  = {}

        if _.isFunction(opts)
            cb = opts
            opts = {}

        @_timeout = opts.timeout || 2000

        # -- were we given any functions? -- #

        @functions = opts.functions || {}

        # -- start listening -- #

        @interface.on "message", (msg,handle) =>
            if msg?.type == "_rpc"
                # it's for us...

                if msg.reply_id
                    # look for the sender
                    @_response msg, handle

                else
                    # incoming request
                    @_consumeRequest msg, handle

        cb? null

    #----------

    request: (key,args...,cb) ->
        msg     = args[0]
        handle  = args[1]

        # generate a UUID for this request
        id = UUID.v4()

        # push the request
        @_pending.push id:id, key:key, msg:msg, handle:handle, cb:cb
        @_runQueue()

    #----------

    _consumeRequest: (msg,handle) ->
        # -- Set up our response function -- #

        cb = _.once (err,obj,handle) =>
            # -- Send Reponse -- #
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
                        @emit msg.key, msg.msg, msg.handle, cb

                    else
                        # return error
                        cb "No listener registered for #{msg.key}."

            # TODO: Add timeout to handle case where we emit and get
            # nothing back.
            catch err
                cb err

    #----------

    _runQueue: ->
        request = @_pending.shift()

        if !request
            return false

        timeout = setTimeout =>
            # if we fail to get an response inside the timeout time,
            # consider the request failed and call the callback
            if @_requests[request.id]
                process.nextTick =>
                    @_requests[request.id].callback? "Timeout waiting for RPC response to #{request.key} command."
                    delete @_requests[request.id]
        , @_timeout

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

        # create a hash entry to map the response
        @_requests[ request.id ] = callback:request.cb, timeout:timeout

        @_runQueue()

    #----------

    _response: (msg,handle) ->
        h = @_requests[ msg.reply_id ]

        if !h
            console.error "Got unmatched response for #{ msg.properties.correlationId }"
            return false

        # stop the timeout
        clearTimeout h.timeout

        err = undefined
        if msg.err
            err = new Error msg.err
            err.stack = msg.err_stack

        h.callback? err, msg.msg, handle

        # clean up
        delete @_requests[ msg.reply_id ]


    #----------

