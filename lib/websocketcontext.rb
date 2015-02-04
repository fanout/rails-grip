using 'gripcontrol'

class WebSocketContext
  def initialize(id, meta, in_events)
    @id = id
    @in_events = in_events
    @read_index = 0
    @accepted = false
    @close_code = nil
    @closed = false
    @out_close_code = nil
    @out_events = []
    @orig_meta = meta
    @meta = Marshal.load(Marshal.dump(meta))
  end

  def is_opening
    return @in_events and @in_events.length > 0 and 
        @in_events[0].type == 'OPEN'
  end

  def accept
    @accepted = true
  end

  def close(code=nil)
    @closed = true
    if !code.nil?
      @out_close_code = code
    else
      @out_close_code = 0
    end
  end

  def can_recv
    for n in @read_index..@in_events.length do
      if ['TEXT', 'BINARY', 'CLOSE', 'DISCONNECT'].include?(
          @in_events[n].type)
        return true
      end
    end
    return false
  end

  def recv
    e = nil
    while e.nil? and @read_index < @in_events.length:
      if ['TEXT', 'BINARY', 'CLOSE', 'DISCONNECT'].include?(
          @in_events[@read_index].type)
        e = @in_events[@read_index]
      elsif @in_events[@read_index].type == 'PING'
        @out_events.push(WebSocketEvent.new('PONG'))
      end
      @read_index += 1
    end
    if e.nil?
      raise 'read from empty buffer'
    end
    if e.type == 'TEXT' or e.type == 'BINARY'
      return e.content
    elsif e.type == 'CLOSE'
      if !e.content.nil? and e.content.length == 2
        @close_code = e.content.unpack('H')[0]
      end
      return nil
    else
      raise 'client disconnected unexpectedly'
    end
  end

  def send(message)
    @out_events.push(WebSocketEvent.new('TEXT', 'm:' + message))
  end

  def send_control(message)
    @out_events.push(WebSocketEvent.new('TEXT', 'c:' + message))
  end

  def subscribe(channel)
    send_control(GripControl.websocket_control_message(
        'subscribe', {'channel' => channel}))
  end

  def unsubscribe(channel)
    send_control(GripControl.websocket_control_message(
        'unsubscribe', {'channel' => channel}))
  end

  def detach(channel)
    send_control(GripControl.websocket_control_message('detach'))
  end
end