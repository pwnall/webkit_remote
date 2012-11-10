module WebkitRemote

class Client

# API for the Console domain.
module Console
  # Enables or disables the generation of events in the Console domain.
  #
  # @param [Boolean] new_console_events if true, the browser debugger will
  #     generate Console.* events
  def console_events=(new_console_events)
    new_console_events = !!new_console_events
    if new_console_events != console_events
      @rpc.call(new_console_events ? 'Console.enable' : 'Console.disable')
      @console_events = new_console_events
    end
    new_console_events
  end

  # Removes all the messages in the console.
  #
  # @return [WebkitRemote::Client] self
  def clear_console
    @rpc.call 'Console.clearMessages'
    console_cleared
    self
  end

  # @return [Boolean] true if the debugger generates Console.* events
  attr_reader :console_events

  # @return [Array<WebkitRemote::Client::ConsoleMessage>]
  attr_reader :console_messages

  # @private Called by the ConsoleMessage event constructor
  def console_add_message(message)
    @console_messages << message
  end

  # @private Called by the ConsoleCleared event constructor.
  def console_cleared
    @console_messages.each(&:release_params)
    @console_messages.clear
  end

  # @private Called by the Client constructor to set up Console data.
  def initialize_console
    @console_events = false
    @console_messages = []
  end
end  # module WebkitRemote::Client::Console

initializer :initialize_console
clearer :clear_console
include WebkitRemote::Client::Console

# Data about an entry in the debugger console.
class ConsoleMessage
  # @return [String] the message text
  attr_reader :text

  # @return [Array<WebkitRemote::Client::RemoteObject>] extra arguments given
  #     to the message
  attr_reader :params

  # @return [Symbol] message severity
  #
  # The documented values are :debug, :error, :log, :tip, and :warning.
  attr_reader :level

  # @return [Integer] how many times this message was repeated
  attr_accessor :count

  # @return [Symbol] the component that produced this message
  #
  # The documented values are :console_api, :html, :javascript, :network,
  #     :other, :wml, and :xml.
  attr_reader :reason

  # @return [WebkitRemote::Client::NetworkResource] resource associated with
  #     this message
  #
  # This is set for console messages that indicate network errors.
  attr_reader :network_resource

  # @return [Symbol] the behavior that produced this message
  #
  # The documented values are :assert, :dir, :dirxml, :endGroup, :log,
  #     :startGroup, :startGroupCollapsed, and :trace.
  attr_reader :type

  # @return [String] the URL of the file that caused this message
  attr_reader :source_url

  # @return [Integer] the line number of the statement that caused this message
  attr_reader :source_line

  # @return [Array<Hash<Symbol, Object>>] JavaScript stack trace to the
  #     statement that caused this message
  attr_reader :stack_trace

  # @private Use Event#for instead of calling this constructor directly.
  #
  # @param [Hash<String, Object>] the raw JSON for a Message object in the
  #     Console domain, returned by a RPC call to a Webkit debugging server
  # @
  def initialize(raw_message, client)
    @level = (raw_message['level'] || 'error').to_sym
    @source_line = raw_message['line'] ? raw_message['line'].to_i : nil
    if raw_message['networkRequestId']
      @network_resource =
        client.network_resource raw_message['networkRequestId']
    else
      @network_resource = nil
    end
    if raw_message['parameters']
      @params = raw_message['parameters'].map do |raw_object|
        WebkitRemote::Client::RemoteObject.for raw_object, client, nil
      end
    else
      @params = []
    end
    @params.freeze
    @count = raw_message['repeatCount'] ? raw_message['repeatCount'].to_i : 1
    if raw_message['source']
      @reason = raw_message['source'].gsub('-', '_').to_sym
    else
      @reason = :other
    end
    @stack_trace = self.class.parse_stack_trace raw_message['stackTrace']
    @text = raw_message['text']
    @type = raw_message['type'] ? raw_message['type'].to_sym : nil
    @source_url = raw_message['url']
  end

  # Releases the JavaScript objects referenced by this message's parameters.
  def release_params
    @params.each do |param|
      if param.kind_of?(WebkitRemote::Client::RemoteObject)
        param.release
      end
    end
  end

  # Parses a StackTrace object returned by a RPC request.
  #
  # @param [Array<String, Object>] raw_stack_trace the raw StackTrace object
  #     in the Console domain returned by a RPC request
  # @return [Array<Symbol, Object>] Ruby-friendly stack trace
  def self.parse_stack_trace(raw_stack_trace)
    return nil unless raw_stack_trace

    raw_stack_trace.map do |raw_frame|
      frame = {}
      if raw_frame['columnNumber']
        frame[:column] = raw_frame['columnNumber'].to_i
      end
      if raw_frame['lineNumber']
        frame[:line] = raw_frame['lineNumber'].to_i
      end
      if raw_frame['functionName']
        frame[:function] = raw_frame['functionName']
      end
      if raw_frame['url']
        frame[:url] = raw_frame['url']
      end
      frame
    end
  end
end  # class WebkitRemote::Client::ConsoleMessage

end  # namespace WebkitRemote::Client

end  # namespace WebkitRemote
