RPC = require "../"

cp = require "child_process"
path = require "path"
net = require "net"

describe "Function Calls", ->
    server  = null
    rpc     = null

    before (done) ->
        server = cp.fork path.resolve(__dirname,"./support/serverjs")

        server.once "message", (msg) ->
            throw new Error("Expected first message of OK") if msg != "OK"
            done()

    after (done) ->
        server.kill()
        done()

    before (done) ->
        rpc = new RPC server, timeout:500, (err) ->
            throw err if err
            done()

    it "can send an object", (done) ->
        obj = {a:1,b:2,c:3}
        rpc.request "object", obj, (err,robj) ->
            throw err if err

            expect(robj).to.be.object
            expect(robj).to.eql obj
            done()

    it "can send a string", (done) ->
        str = "ABC123"
        rpc.request "string", str, (err,rstr) ->
            throw err if err

            expect(rstr).to.be.string
            expect(rstr).to.eql str
            done()

    it "can send a boolean", (done) ->
        rpc.request "boolean", true, (err,bool) ->
            throw err if err

            expect(bool).to.be.boolean
            expect(bool).to.eql true
            done()

    it "can send an empty value", (done) ->
        rpc.request "empty", null, (err,obj) ->
            throw err if err

            expect(obj).to.be.null
            done()

    it "can send a handle", (done) ->
        s = net.createServer()
        s.listen 0

        port = s.address().port

        rpc.request "handle", null, s, (err,obj) ->
            throw err if err
            expect(obj.port).to.eql port
            done()

    it "can return an error", (done) ->
        rpc.request "error", null, (err,obj) ->
            expect(err).to.not.be.undefined
            expect(err).to.be.instanceof Error
            expect(err.stack).to.include "Object.functions.error"
            done()

    it "catches a thrown error", (done) ->
        rpc.request "throw_error", null, (err,obj) ->
            expect(err).to.not.be.undefined
            expect(err).to.be.instanceof Error
            expect(err.stack).to.include "Object.functions.throw_error"

            done()