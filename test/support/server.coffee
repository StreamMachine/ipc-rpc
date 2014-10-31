RPC = require "../../lib/rpc"
_ = require "underscore"

functions =
    object: (obj,handle,cb) ->
        if _.isObject(obj)
            cb null, obj
        else
            cb "Not an object"

    string: (string,handle,cb) ->
        if _.isString(string)
            cb null, string
        else
            cb "Not a string"

    boolean: (bool,handle,cb) ->
        if _.isBoolean(bool)
            cb null, bool
        else
            cb "Not a boolean"

    empty: (empty,handle,cb) ->
        if !empty?
            cb null, null
        else
            cb "Not empty"

    handle: (msg,handle,cb) ->
        if !handle
            return cb "No handle received"

        cb null, fd:handle._handle.fd

    error: (msg,handle,cb) ->
        return cb new Error "ERROR!"

    throw_error: (msg,handle,cb) ->
        throw new Error "ERROR!"

rpc = new RPC process, functions:functions, timeout:500

process.send "OK"

