module WebkitRemote

class Event

# Emitted when a console message is produced.
class ConsoleMessage < WebkitRemote::Event
  register 'Console.messageAdded'

  # @return [WebkitRemote::Client::ConsoleMessage] the new message
  attr_reader :message

  # @return [String] the message text
  def text
    @message.text
  end

  # @return [Symbol] message severity
  #
  # The documented values are :debug, :error, :log, :tip, and :warning.
  def level
    @message.level
  end

  # @return [Symbol] the component that produced this message
  #
  # The documented values are :console_api, :html, :javascript, :network,
  #     :other, :wml, and :xml.
  def reason
    @message.reason
  end

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super

    if raw_message = raw_data['message']
      @message = WebkitRemote::Client::ConsoleMessage.new raw_data['message'],
                                                          client
      client.console_add_message @message
    else
      @message = nil
    end
  end

  # @private Use Event#can_receive instead of calling this directly.
  def self.can_reach?(client)
    client.console_events
  end
end  # class WebkitRemote::Event::ConsoleMessage

# Emitted when the console is cleared.
class ConsoleCleared < WebkitRemote::Event
  register 'Console.messagesCleared'

  # @private Use Event#for instead of calling this constructor directly.
  def initialize(rpc_event, client)
    super
    client.console_cleared
  end

  # @private Use Event#can_receive instead of calling this directly.
  def self.can_reach?(client)
    client.console_events
  end
end  # class WebkitRemote::Event::ConsoleCleared

end  # namespace WebkitRemote::Event

end  # namepspace WebkitRemote
