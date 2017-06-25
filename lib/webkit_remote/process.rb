require 'fileutils'
require 'net/http'
require 'tmpdir'

module WebkitRemote

# Tracks a Webkit process.
class Process
  # Tracker for a yet-unlaunched process.
  #
  # @param [Hash] opts tweak the options below
  # @option opts [Integer] port the port used by the remote debugging server;
  #     the default port is 9292
  # @option opts [Number] timeout number of seconds to wait for the browser
  #     to start; the default timeout is 10 seconds
  # @option opts [Hash<Symbol, Number>] window set the :left, :top, :width and
  #     :height of the browser window; by default, the browser window is
  #     256x256 starting at 0,0.
  # @option opts [Boolean] allow_popups when true, the popup blocker is
  #     disabled; this is sometimes necessary when driving a Web UI via
  #     JavaScript
  # @option opts [Boolean] headless if true, Chrome runs without any dependency
  #     on a display server
  # @option opts [String] chrome_binary path to the Chrome binary to be used;
  #     by default, the path is automatically detected
  def initialize(opts = {})
    @port = opts[:port] || 9292
    @timeout = opts[:timeout] || 10
    @running = false
    @data_dir = Dir.mktmpdir 'webkit-remote'
    @pid = nil
    if opts[:window]
      @window = opts[:window]
    else
      @window = { }
    end
    @window[:top] ||= 0
    @window[:left] ||= 0
    @window[:width] ||= 256
    @window[:height] ||= 256
    @cli = chrome_cli opts
  end

  # Starts the browser process.
  #
  # @return [WebkitRemote::Browser] master session to the started Browser
  #     process; the session's auto_close is set to false so that it can be
  #     safely discarded; nil if the launch fails
  def start
    return self if running?

    unless @pid = ::Process.spawn(*@cli)
      # The launch failed.
      stop
      return nil
    end

    (@timeout * 20).times do
      # Check if the browser exited.
      begin
        break if ::Process.wait(@pid, ::Process::WNOHANG)
      rescue SystemCallError  # no children
        break
      end

      # Check if the browser finished starting up.
      begin
        browser = WebkitRemote::Browser.new process: self
        @running = true
        return browser
      rescue SystemCallError  # most likely ECONNREFUSED
        Kernel.sleep 0.05
      end
    end
    # The browser failed, or was too slow to start.
    stop
    nil
  end

  # @return [Boolean] true if the Webkit process is running
  attr_reader :running
  alias_method :running?, :running

  # Stops the browser process.
  #
  # Only call this after you're done with the process.
  #
  # @return [WebkitRemote::Process] self
  def stop
    return self unless running?
    if @pid
      begin
        ::Process.kill 'TERM', @pid
        ::Process.wait @pid
      rescue SystemCallError
        # Process died on its own.
      ensure
        @pid = nil
      end
    end

    FileUtils.rm_rf @data_dir if File.exist?(@data_dir)
    @running = false
    self
  end

  # @return [Integer] port that the process' remote debugging server listens to
  attr_reader :port

  # Remove temporary directory if it's still there at garbage collection time.
  def finalize
    PathUtils.rm_rf @data_dir if File.exist?(@data_dir)
  end

  # Command-line that launches Google Chrome / Chromium
  #
  # @param [Hash] opts options passed to the WebkitRemote::Process constructor
  # @return [Array<String>] command line for launching Chrome
  def chrome_cli(opts)
    # The Chromium wiki recommends this page for available flags:
    #     http://peter.sh/experiments/chromium-command-line-switches/
    [
      opts[:chrome_binary] || self.class.chrome_binary,
    ] + chrome_cli_flags(opts) + [
      "--remote-debugging-port=#{@port}",  # Webkit remote debugging
      "--user-data-dir=#{@data_dir}",  # really ensure a clean slate
      "--window-position=#{@window[:left]},#{@window[:top]}",
      "--window-size=#{@window[:width]},#{@window[:height]}",

      'about:blank',  # don't load the homepage
      {
        chdir: @data_dir,
        in: '/dev/null',
        out: File.join(@data_dir, '.stdout'),
        err: File.join(@data_dir, '.stderr'),
        close_others: true,
      },
    ]
  end

  # Flags used on the command-line that launches Google Chrome / Chromium.
  #
  # @param [Hash] opts options passed to the WebkitRemote::Process constructor
  # @return [Array<String>] flags used on the command line for launching Chrome
  def chrome_cli_flags(opts)
    # TODO - look at --data-path --homedir --profile-directory
    flags = [
      '--bwsi',  # disable extensions, sync, bookmarks
      '--disable-cloud-import',  # no talking with the Google servers
      '--disable-default-apps',  # no bundled apps
      '--disable-extensions',  # no extensions
      '--disable-logging',  # don't trash stdout / stderr
      '--disable-plugins',  # no native content
      '--disable-prompt-on-repost',   # no confirmation dialog on POST refresh
      '--disable-sync',  # no talking with the Google servers
      '--disable-translate',  # no Google Translate calls
      '--incognito',  # don't use old state, don't preserve state
      '--homepage=about:blank',  # don't go to Google in new tabs
      '--keep-alive-for-test',  # don't kill process if the last window dies
      '--lang=en-US',  # set a default language
      '--log-level=3',  # FATAL, because there's no setting for "none"
      '--mute-audio',  # don't let the computer make noise
      '--no-default-browser-check',  # don't hang when Chrome isn't default
      '--no-experiments',  # not sure this is useful
      '--no-first-run',  # don't show the help UI
      '--no-service-autorun',  # don't mess with autorun settings
      '--noerrdialogs',  # don't hang on error dialogs
    ]
    flags << '--disable-popup-blocking' if opts[:allow_popups]
    if opts[:headless]
      flags << '--headless'  # don't create a UI
      flags << '--disable-gpu'  # needed for --headless to work at the moment
    end
    flags
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
end  # class WebkitRemote::Browser

end  # namespace WebkitRemote
