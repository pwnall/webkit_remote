require 'fileutils'
require 'posix/spawn'
require 'tmpdir'

module WebkitRemote

# Tracks a Webkit process.
class Process
  # Tracker for a yet-unlaunched process.
  #
  # @param [Hash] opts
  # @option opts [Integer] port the port used by the remote debugging server
  def initialize(opts = {})
    @port = opts[:port] || 9292
    @running = false
    @data_dir = Dir.mktmpdir 'webkit-remote'
    @pid = nil
    @cli = chrome_cli opts
  end

  # Starts the browser process.
  #
  # @return [WebkitRemote::Process] self
  def start
    return self if running?
    @pid = POSIX::Spawn.spawn(*@cli)
    100.times do
      begin
        Net::HTTP.get(URI.parse('http://localhost:9669/json'))
        @running = true
        return self
      rescue Errno::ECONNREFUSED
        Kernel.sleep 0.05
      end
    end
    # The browser failed, or was too slow to start.
    self
  end

  # @return [Boolean] true if the Webkit process is running
  def running?
    @running
  end

  # Stops the browser process.
  #
  # Only call this after you're done with the process.
  #
  # @return [WebkitRemote::Process] self
  def stop
    FileUtils.rm_r @data_dir if File.exists?(@data_dir)
    return self unless running?
    begin
      ::Process.kill 'TERM', @pid
      ::Process.wait @pid
    end
    @running = false
    self
  end

  # Remove temporary directory if it's still there at garbage collection time.
  def finalize
    PathUtils.rm_r @data_dir if File.exists?(@data_dir)
  end

  # Command-line that launches Google Chrome / Chromium
  #
  # @param [Hash] opts options passed to the WebkitRemote::Process constructor
  # @return [Array<String>] command line for launching Chrome
  def chrome_cli(opts)
    [
      self.class.chrome_binary,
      '--bwsi',  # don't sign into a google account
      '--disable-logging',  # don't trash stdout / stderr
      '--disable-plugins',  # no native content
      '--disable-prompt-on-repost',   # no confirmation dialog on POST refresh
      '--incognito',  # don't use old state, don't preserve state
      '--homepage=about:blank',  # don't go to Google in new tabs
      '--keep-alive-for-test',  # don't kill process if the last window dies
      '--lang=en-US',  # set a default language
      '--log-level=3',  # FATAL, because there's no setting for "none"
      '--no-default-browser-check',  # don't hang when Chrome isn't default
      '--no-js-randomness',  # consistent Date.now() and Math.random()
      '--no-service-autorun',  # don't mess with autorun settings
      '--noerrdialogs',  # don't hang on error dialogs
      "--remote-debugging-port=#{@port}",
      "--user-data-dir=#{@datadir}",  # really ensure a clean slate
      'about:blank'  # don't load the homepage
    ]
  end

  # Path to a Google Chrome / Chromium binary.
  #
  # @return [String] full-qualified path to a binary that launches Chrome
  def self.chrome_binary
    return @chrome_binary unless @chrome_binary == false

    case RUBY_PLATFORM
    when /linux/
      [
        'google-chrome',
        'google-chromium',
      ].each do |binary|
        path = `which #{binary}`
        unless path.empty?
          @chrome_binary = path.strip
          break
        end
      end
    when /darwin/
      [
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
      ].each do |path|
        if File.exist? path
          @chrome_binary = path
          break
        end
      end
    else
      raise "Unsupported platform #{RUBY_PLATFORM}"
    end
    @chrome_binary ||= nil
  end
  @chrome_binary = false
end

end  # namespace WebkitRemote
