# PokeDebug delayed loader for Yuri RGSS Game Player.
#
# This file is evaluated before Yuri hands control to the encrypted game
# scripts.  Loading the full menu at that point is too early, so the loader
# waits for the first Graphics.update after the Essentials runtime exists.

module PokeDebugYuriBootstrap
  VERSION = "1".freeze unless const_defined?(:VERSION)
  MAX_FAILURES = 8 unless const_defined?(:MAX_FAILURES)

  @loaded = false
  @loading = false
  @failures = 0
  @update_frames = 0

  module_function

  def log(message)
    File.open("developer_menu_errors.log", "a") do |file|
      file.puts("[PokeDebug Yuri #{VERSION}] #{message}")
    end
  rescue Exception
  end

  def engine_ready?
    scene_ready = Object.const_defined?(:Scene_Map) rescue false
    system_ready = Object.const_defined?(:PokemonSystem) rescue false
    temp_ready = Object.const_defined?(:PokemonTemp) rescue false
    message_ready = Object.private_method_defined?(:pbMessage) rescue false
    scene_ready || system_ready || temp_ready || message_ready || @update_frames.to_i >= 45
  rescue Exception
    false
  end

  def runtime_loaded?
    return true if defined?(POKEDEBUG_BOOTSTRAP_STATUS) && POKEDEBUG_BOOTSTRAP_STATUS == :loaded
    return true if defined?(POKEDEBUG_RUNTIME_LOADED) && POKEDEBUG_RUNTIME_LOADED
    return true if Object.const_defined?(:DeveloperMenu) &&
                   Object.const_get(:DeveloperMenu).respond_to?(:open_menu_external)
    false
  rescue Exception
    false
  end

  def plugin_path
    candidates = []
    candidates << File.expand_path("Plugins/PokeDebug/pokedebug_menu.rb", Dir.pwd)
    begin
      candidates << File.expand_path("Plugins/PokeDebug/pokedebug_menu.rb", File.dirname($0)) if $0
    rescue Exception
    end
    candidates.find { |path| path && File.file?(path) }
  rescue Exception
    nil
  end

  def plugin_chunks
    root = File.expand_path("Plugins/PokeDebug/yuri_chunks", Dir.pwd)
    return [] unless File.directory?(root)
    Dir[File.join(root, "*.rb")].sort
  rescue Exception
    []
  end

  def try_load
    return true if @loaded || runtime_loaded?
    return false if @loading
    return false if @preload_started
    @update_frames = @update_frames.to_i + 1
    return false unless engine_ready?
    return false if @failures.to_i >= MAX_FAILURES

    load_plugin_now
  end

  def load_plugin_now
    return true if @loaded || runtime_loaded?
    return false if @loading || @preload_started
    chunks = plugin_chunks
    path = plugin_path
    return false if chunks.empty? && !path
    @loading = true
    @preload_started = true
    begin
      if chunks.empty?
        load(path)
      else
        log("Loading #{chunks.length} balanced menu chunks.")
        chunks.each do |chunk_path|
          chunk_name = File.basename(chunk_path)
          log("Chunk BEGIN #{chunk_name}")
          load(chunk_path)
          log("Chunk END #{chunk_name}")
        end
      end
      @loaded = runtime_loaded?
      log(@loaded ? "Runtime loaded successfully." : "Plugin returned without a ready runtime.")
      @loaded
    rescue Exception => error
      @failures = @failures.to_i + 1
      log("Attempt #{@failures}/#{MAX_FAILURES} failed: #{error.class}: #{error.message}")
      false
    ensure
      @loading = false
    end
  end

  def install_graphics_hook
    return true if @graphics_hook_installed
    return false unless Object.const_defined?(:Graphics)
    graphics = Object.const_get(:Graphics)
    return false unless graphics && graphics.respond_to?(:update)

    eigenclass = class << graphics; self; end
    unless eigenclass.method_defined?(:pokedebug_yuri_original_update)
      eigenclass.send(:alias_method, :pokedebug_yuri_original_update, :update)
      eigenclass.send(:define_method, :update) do |*args|
        PokeDebugYuriBootstrap.try_load
        pokedebug_yuri_original_update(*args)
      end
    end
    @graphics_hook_installed = true
    log("Bootstrap hook installed; waiting for the game runtime.")
    true
  rescue Exception => error
    log("Could not install Graphics.update hook: #{error.class}: #{error.message}")
    false
  end

  def install_deferred_hook
    return false unless Kernel.respond_to?(:set_trace_func) || Object.respond_to?(:set_trace_func, true)
    return true if @trace_installed

    @trace_installed = true
    @trace_guard = false
    @trace_events = 0
    set_trace_func proc { |event, _file, _line, method_id, _binding, _klass|
      next if PokeDebugYuriBootstrap.instance_variable_get(:@trace_guard)
      PokeDebugYuriBootstrap.instance_variable_set(:@trace_guard, true)
      begin
        events = PokeDebugYuriBootstrap.instance_variable_get(:@trace_events).to_i + 1
        PokeDebugYuriBootstrap.instance_variable_set(:@trace_events, events)
        scene_ready = Object.const_defined?(:Scene_Map) rescue false
        system_ready = Object.const_defined?(:PokemonSystem) rescue false
        message_ready = Object.private_method_defined?(:pbMessage) rescue false
        scripts_ready = scene_ready || system_ready || message_ready || events >= 50000
        active_scene = (defined?($scene) && !$scene.nil?) rescue false
        main_entry = event.to_s == "call" &&
                     (["mainFunction", "mainFunctionDebug", "main"].include?(method_id.to_s) || active_scene)
        if scripts_ready && main_entry
          set_trace_func nil
          PokeDebugYuriBootstrap.instance_variable_set(:@trace_installed, false)
          PokeDebugYuriBootstrap.log("Main entry #{method_id} intercepted; arming frame loader.")
          PokeDebugYuriBootstrap.install_graphics_hook
        elsif events >= 5000000 && PokeDebugYuriBootstrap.install_graphics_hook
          set_trace_func nil
          PokeDebugYuriBootstrap.instance_variable_set(:@trace_installed, false)
        end
      ensure
        PokeDebugYuriBootstrap.instance_variable_set(:@trace_guard, false)
      end
    }
    log("Deferred trace hook installed; waiting for the encrypted game scripts.")
    true
  rescue Exception => error
    @trace_installed = false
    log("Could not install deferred hook: #{error.class}: #{error.message}")
    false
  end
end

PokeDebugYuriBootstrap.install_deferred_hook
