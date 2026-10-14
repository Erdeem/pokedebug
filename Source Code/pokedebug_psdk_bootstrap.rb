# PokeDebug delayed loader for compiled Pokemon SDK games.
module PokeDebugPSDKBootstrap
  VERSION = "2"
  LOG_FILE = File.expand_path("pokedebug_psdk_bootstrap.log", File.dirname(__FILE__))
  MAX_FAILURES = 8

  @loaded = false
  @loading = false
  @failures = 0
  @events = 0

  class << self
    def log(message)
      File.open(LOG_FILE, "a") { |file| file.puts("[#{Time.now}] #{message}") }
    rescue StandardError
    end

    def runtime_ready?
      defined?(PFM) && PFM.respond_to?(:game_state) && PFM.game_state &&
        defined?(Input) && defined?(Graphics) && defined?($scene) && $scene
    rescue StandardError
      false
    end

    def menu_path
      File.expand_path(File.join("PokeDebug", "pokedebug_menu.rb"), File.dirname(__FILE__))
    end

    def load_menu
      return true if @loaded
      return false if @loading || !runtime_ready?
      @loading = true
      begin
        path = menu_path
        raise "PokeDebug menu not found: #{path}" unless File.file?(path)
        load path
        raise "DeveloperMenu was not defined" unless defined?(DeveloperMenu)
        DeveloperMenu.reset_engine_adapters! if DeveloperMenu.respond_to?(:reset_engine_adapters!)
        DeveloperMenu.initialize_variables if DeveloperMenu.respond_to?(:initialize_variables)
        DeveloperMenu.register_pokedebug_device_item! if DeveloperMenu.respond_to?(:register_pokedebug_device_item!)
        @loaded = true
        log("PokeDebug loaded; scene=#{$scene.class} psdk=#{File.read('psdk/version.txt').strip rescue 'unknown'}")
        true
      rescue => error
        @failures += 1
        log("Load failure #{@failures}: #{error.class}: #{error.message}\n#{Array(error.backtrace).first(20).join("\n")}")
        false
      ensure
        @loading = false
      end
    end

    def install
      return true if @trace
      log("Bootstrap #{VERSION} installed; waiting for PSDK runtime")
      @trace = TracePoint.new(:call) do |trace|
        next if @loaded || @loading
        @events += 1
        next unless trace.method_id == :update || (@events % 500) == 0
        if runtime_ready?
          @trace.disable
          loaded = load_menu
          @trace.enable if !loaded && @failures < MAX_FAILURES
        end
      end
      @trace.enable
      true
    rescue => error
      log("Bootstrap installation failed: #{error.class}: #{error.message}")
      false
    end
  end
end

PokeDebugPSDKBootstrap.install
