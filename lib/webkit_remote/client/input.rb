module WebkitRemote

class Client

# API for the Input domain.
module Input
  # Dispatches a mouse event.
  #
  # @param [Symbol] type the event type (:move, :down, :up)
  # @param [Integer] x the X coordinate, relative to the main frame's viewport
  # @param [Integer] y the Y coordinate, relative to the main frame's viewport
  # @param [Hash] opts optional information
  # @option opts [Symbol] button :left, :right, :middle, or nil (none); nil by
  #     default
  # @option opts [Array<Symbol>] modifiers combination of :alt, :ctrl, :shift,
  #     and :command / :meta (empty by default)
  # @option opts [Number] time the event's time, as a JavaScript timestamp
  # @option opts [Number] clicks number of times the mouse button was clicked
  #    (0 by default)
  # @return [WebkitRemote::Client] self
  def mouse_event(type, x, y, opts = {})
    options = { x: x, y: y }
    options[:type] = case type
    when :move
      'mouseMoved'
    when :down
      'mousePressed'
    when :up
      'mouseReleased'
    else
      raise RuntimeError, "Unsupported mouse event type #{type}"
    end

    options[:timestamp] = opts[:time] if opts[:time]
    options[:clickCount] = opts[:clicks] if opts[:clicks]
    if opts[:modifiers]
      flags = 0
      opts[:modifiers].each do |modifier|
        flags |= case modifier
        when :alt
          1
        when :ctrl
          2
        when :command, :meta
          4
        when :shift
          8
        end
      end
      options[:modifiers] = flags
    end

    @rpc.call 'Input.dispatchMouseEvent', options
    self
  end
end  # module WebkitRemote::Client::Input

include WebkitRemote::Client::Input

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote

