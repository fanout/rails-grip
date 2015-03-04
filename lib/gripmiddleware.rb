#    gripmiddleware.rb
#    ~~~~~~~~~
#    This module implements the GripMiddleware class.
#    :authors: Konstantin Bokarius.
#    :copyright: (c) 2015 by Fanout, Inc.
#    :license: MIT, see LICENSE for more details.

require 'set'
require 'gripcontrol'
require_relative 'websocketcontext.rb'
require_relative 'nonwebsocketrequesterror.rb'

class GripMiddleware
  def initialize(app)  
    @app = app  
  end

  def call(env)
    env['grip_proxied'] = false
    env['grip_wscontext'] = nil
    grip_signed = false
    grip_proxies = RailsSettings.get_grip_proxies
    if env.key?('HTTP_GRIP_SIG') and !grip_proxies.nil?
      grip_proxies.each do |entry|
        if GripControl.validate_sig(env['HTTP_GRIP_SIG'], entry['key'])         
          grip_signed = true
          break
        end
      end
    end
    content_type = nil
    if env.key?('CONTENT_TYPE')
      content_type = env['CONTENT_TYPE']
      at = content_type.index(';')
      if !at.nil?
        content_type = content_type[0..at-1]
      end
    end
    accept_types = nil
    if env.key?('HTTP_ACCEPT')
      accept_types = env['HTTP_ACCEPT']
      tmp = accept_types.split(',')
      accept_types = []
      tmp.each do |s|
        accept_types.push(s.strip)
      end
    end
    wscontext = nil
    if env['REQUEST_METHOD'] == 'POST' and ((content_type == 
        'application/websocket-events') or (!accept_types.nil? and
        accept_types.include?('application/websocket-events')))
      cid = nil
      if env.key?('HTTP_CONNECTION_ID')
        cid = env['HTTP_CONNECTION_ID']
      end
      meta = {}
      env.each do |k, v|
        if k.start_with?('HTTP_META_')
          meta[convert_header_name(k[10..-1])] = v
        end
      end
      events = nil
      begin
        events = GripControl.decode_websocket_events(env["rack.input"].read)
      rescue
        return [ 400, {}, ["Error parsing WebSocket events.\n"]]
      end
      wscontext = WebSocketContext.new(cid, meta, events)
    end
    env['grip_proxied'] = grip_signed
    env['grip_wscontext'] = wscontext
    begin
      status, headers, response = @app.call(env)
    rescue NonWebSocketRequestError => e 
      return [400, {}, [e.message + "\n"]]
    end
    if !env['grip_wscontext'].nil? and status == 200
      wscontext = env['grip_wscontext']
      meta_remove = Set.new
      wscontext.orig_meta.each do |k, v|
        found = false
        wscontext.meta.each do |nk, nv|
          if nk.downcase == k
            found = true
            break
          end
        end
        if !found
          meta_remove.add(k)
        end
      end
      meta_set = {}
      wscontext.meta.each do |k, v|
        lname = k.downcase
        need_set = true        
        wscontext.orig_meta.each do |ok, ov|
          if lname == ok and v == ov
            need_set = false
            break
          end
        end
        if need_set
          meta_set[lname] = v
        end
      end
      events = []
      if wscontext.accepted
        events.push(WebSocketEvent.new('OPEN'))
      end
      events.push(*wscontext.out_events)
      if wscontext.closed
        events.push(WebSocketEvent.new('CLOSE',
            [wscontext.out_close_code].pack('S>')))
      end
      if response.respond_to?(:content_type)
        response.body = GripControl.encode_websocket_events(events)
        response.content_type = 'application/websocket-events'
      else
        response = [GripControl.encode_websocket_events(events)]
      end
      headers['Content-Type'] = 'application/websocket-events'
      if wscontext.accepted
				headers['Sec-WebSocket-Extensions'] = 'grip'
      end
      meta_remove.each do |k, v|
		    headers['Set-Meta-' + k] = ''
      end
      meta_set.each do |k, v|
		    headers['Set-Meta-' + k] = v
      end
    elsif !env['grip_hold'].nil?
      if !env['grip_proxied'] and RailsSettings.get_grip_proxy_required
        return [ 501, {}, ["Not implemented.\n"]]
      end
      channels = env['grip_channels']
      prefix = RailsSettings.get_prefix
      if prefix != ''
        channels.each do |channel|
          channel.name = prefix + channel.name
        end
      end
      if status == 304
        iheaders = headers.clone
        if !iheaders.key?('Location') and response.respond_to?(:location) and
            !response.location.nil?
          iheaders['Location'] = response.location
        end
        if response.respond_to?(:body)
          orig_body = response.body
        else
          orig_body = response.to_s
        end
        iresponse = Response.new(status, nil, iheaders, orig_body)
        timeout = nil
        if !env['grip_timeout'].nil?
          timeout = env['grip_timeout']
        end
        if response.respond_to?(:content_type)
          response.body = GripControl.create_hold(env['grip_hold'],
              channels, iresponse, timeout)
          response.content_type = 'application/grip-instruct'
        else
          response = [GripControl.create_hold(env['grip_hold'],
              channels, iresponse, timeout)]
        end
        headers = {'Content-Type' => 'application/grip-instruct'}
      else
        headers['Grip-Hold'] = env['grip_hold']
        headers['Grip-Channel'] = GripControl.create_grip_channel_header(
            channels)
        if !env['grip_timeout'].nil?
          headers['Grip-Timeout'] = env['grip_timeout'].to_s
        end
      end
    end
    return [status, headers, response]
  end

  private

  def convert_header_name(name)
    out = ''
    name.each_char do |c|
      if c == '_'
        out += '-'
      else
        out += c.downcase
      end
    end
    return out
  end
end
