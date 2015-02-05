require 'gripcontrol'
require_relative 'websocketcontext.rb'

class GripMiddleware
  def initialize(app)  
    @app = app  
  end

  # TODO: Add a mechanism to set to websocket-only.
  def call(env)
    env['grip_proxied'] = false
    env['grip_wscontext'] = nil
    grip_signed = false
    if env.key?('HTTP_GRIP_SIG') and 
        Rails.application.config.respond_to?(:grip_proxies)
      Rails.application.config.grip_proxies.each do |entry|
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
    status, headers, response = @app.call(env)
    puts 'Status: ' + status.to_s
    puts 'Headers: ' + headers.to_s
    puts 'Response: ' + response.to_s

    if !env['grip_wscontext'].nil? and status == 200 and response.length == 0
      puts 'WebSocket!'
      # TODO: Complete.
    elsif !env['grip_hold'].nil?
      if status == 304
        iheaders = headers.clone
        if !iheaders.key?('Location') and !response.location.nil?
          iheaders['Location'] = response.location
        end
        iresponse = Response.new(status, nil, iheaders, response.body)
        timeout = nil
        if !env['grip_timeout'].nil?
          timeout = env['grip_timeout']
        end
        response.body = GripControl.create_hold(env['grip_hold'],
            env['grip_channels'], iresponse, timeout)
        response.content_type = 'application/grip-instruct'
        headers = {'Content-Type' => 'application/grip-instruct'}
      else
        headers['Grip-Hold'] = env['grip_hold']
        headers['Grip-Channel'] = GripControl.create_grip_channel_header(
            env['grip_channels'])
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
