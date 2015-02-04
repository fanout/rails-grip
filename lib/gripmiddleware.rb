require 'gripcontrol'

class GripMiddleware
  def initialize(app)  
    @app = app  
  end

  # TODO: Add a mechanism to set to websocket-only.
  def call(env)
    status, headers, response = @app.call(env)
    if !env['grip_hold'].nil?
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
end
