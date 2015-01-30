var RPC, UUID, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

_ = require("underscore");

UUID = require("uuid");

module.exports = RPC = (function(_super) {
  __extends(RPC, _super);

  function RPC(_interface, opts, cb) {
    var _ref;
    this["interface"] = _interface;
    if (((_ref = this["interface"]) != null ? _ref.send : void 0) == null) {
      throw new Error("Invalid RPC interface. No send function.");
    }
    this._pending = [];
    this._requests = {};
    this._listening = true;
    if (_.isFunction(opts)) {
      cb = opts;
      opts = {};
    }
    this._timeout = opts.timeout || 2000;
    this.functions = opts.functions || {};
    this._mListener = (function(_this) {
      return function(msg, handle) {
        if ((msg != null ? msg.type : void 0) === "_rpc") {
          if (msg.reply_id) {
            return _this._response(msg, handle);
          } else {
            return _this._consumeRequest(msg, handle);
          }
        }
      };
    })(this);
    this["interface"].on("message", this._mListener);
    if (typeof cb === "function") {
      cb(null, this);
    }
  }

  RPC.prototype.disconnect = function() {
    if (!this._listening) {
      return true;
    }
    return this["interface"].removeListener("message", this._mListener);
  };

  RPC.prototype.reconnect = function() {
    if (this._listening) {
      return true;
    }
    return this["interface"].on("message", this._mListener);
  };

  RPC.prototype.request = function() {
    var args, cb, handle, id, key, msg, opts, _i;
    key = arguments[0], args = 3 <= arguments.length ? __slice.call(arguments, 1, _i = arguments.length - 1) : (_i = 1, []), cb = arguments[_i++];
    id = UUID.v4();
    msg = args[0];
    handle = args[1];
    opts = args[2];
    this._pending.push({
      id: id,
      key: key,
      msg: msg,
      handle: handle,
      opts: opts,
      cb: cb
    });
    return this._runQueue();
  };

  RPC.prototype._consumeRequest = function(msg, handle) {
    var cb, d;
    cb = _.once((function(_this) {
      return function(err, obj, handle) {
        _this._pending.push({
          reply_id: msg.id,
          msg: obj,
          err: err != null ? err.message : void 0,
          err_stack: err != null ? err.stack : void 0,
          handle: handle
        });
        return _this._runQueue();
      };
    })(this));
    d = require("domain").create();
    d.on("error", (function(_this) {
      return function(err) {
        return cb(err);
      };
    })(this));
    return d.run((function(_this) {
      return function() {
        var err, _ref;
        try {
          if ((_ref = _this.functions) != null ? _ref[msg.key] : void 0) {
            return _this.functions[msg.key](msg.msg, handle, cb);
          } else {
            if (_this.listeners(msg.key).length > 0) {
              return _this.emit(msg.key, msg.msg, handle, cb);
            } else {
              return cb(new Error("NO_LISTENER: No listener registered for " + msg.key + "."));
            }
          }
        } catch (_error) {
          err = _error;
          return cb(err);
        }
      };
    })(this));
  };

  RPC.prototype._runQueue = function() {
    var request, timeout, _ref;
    request = this._pending.shift();
    if (!request) {
      return false;
    }
    if (request.id) {
      timeout = setTimeout((function(_this) {
        return function() {
          if (_this._requests[request.id]) {
            return process.nextTick(function() {
              var _base;
              if (typeof (_base = _this._requests[request.id]).callback === "function") {
                _base.callback(new Error("TIMEOUT: Timeout waiting for RPC response to " + request.key + " command."));
              }
              return delete _this._requests[request.id];
            });
          }
        };
      })(this), ((_ref = request.opts) != null ? _ref.timeout : void 0) || this._timeout);
      if (request.id) {
        this._requests[request.id] = {
          callback: request.cb,
          timeout: timeout
        };
      }
    }
    this["interface"].send({
      type: "_rpc",
      key: request.key,
      id: request.id,
      reply_id: request.reply_id,
      msg: request.msg,
      err: request.err,
      err_stack: request.err_stack
    }, request.handle);
    return this._runQueue();
  };

  RPC.prototype._response = function(msg, handle) {
    var err, h;
    h = this._requests[msg.reply_id];
    if (!h) {
      this.emit("debug", "Got unmatched response for " + msg.reply_id + ". Could be a call that timed out.");
      return false;
    }
    clearTimeout(h.timeout);
    err = void 0;
    if (msg.err) {
      err = new Error(msg.err);
      err.stack = msg.err_stack;
    }
    if (typeof h.callback === "function") {
      h.callback(err, msg.msg, handle);
    }
    return delete this._requests[msg.reply_id];
  };

  return RPC;

})(require("events").EventEmitter);

//# sourceMappingURL=rpc.js.map
