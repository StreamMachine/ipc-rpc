----
    ipc-rpc
----

RPC over `process.send`, including support for sending handles.

Both sides of the pipe can be both clients and servers.

## Usage

Set up a basic server that responds to status requests with "OK!":

```coffee
  functions =
    status: (msg,handle,cb) ->
      cb null, "OK!"

  rpc = new RPC process, functions:functions, timeout:500
```

On the client-side:

```coffee
  rpc = new RPC server, (err) =>
    if err
      # probably didn't pass in something with `.send` as server
      throw err

    # ready

  rpc.request "status", msg:"whatever", (err,result) =>
    # err should be null and result should be "OK!"
```

Requests optionally take a handle as their third argument, before the callback.

## Motivation

In [StreamMachine](https://github.com/StreamMachine/StreamMachine), this library
is used to facilitate handoffs of server and listener data during seamless restarts.

Example call ([found here in StreamMachine](https://github.com/StreamMachine/StreamMachine/blob/01b9525adaa1785ccd1229a30b45e616ce1f2d18/src/streammachine/master/index.coffee#L326-L337)):

```coffee
  for source in sg._stream.sources
      if source._shouldHandoff
          do (source) =>
              @log.info "Sending StreamGroup source #{msg.key}/#{source.uuid}"
              rpc.request "group_source",
                  group:      sg.key
                  type:       source.HANDOFF_TYPE
                  opts:       format:source.opts.format, uuid:source.uuid, source_ip:source.opts.source_ip
              , source.opts.sock
              , (err,reply) =>
                  @log.error "Error sending group source #{msg.key}/#{source.uuid}: #{err}" if err
                  af()
```

