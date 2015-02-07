#    nonwebsocketrequesterror.rb
#    ~~~~~~~~~
#    This module implements the NonWebSocketRequestError class.
#    :authors: Konstantin Bokarius.
#    :copyright: (c) 2015 by Fanout, Inc.
#    :license: MIT, see LICENSE for more details.

class NonWebSocketRequestError < StandardError
  def message
    "This endpoint only allows WebSocket requests."
  end
end
