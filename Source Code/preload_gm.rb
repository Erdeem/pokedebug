GM_TRY_ENABLE_NATIVE_DEBUG = false unless defined?(GM_TRY_ENABLE_NATIVE_DEBUG)
GM_TRY_DISABLE_COMPILER = false unless defined?(GM_TRY_DISABLE_COMPILER)

module PokeDebugBootstrap
  module_function

  def log_message(label, message)
    File.open("developer_menu_errors.log", "a") do |f|
      f.puts("[#{Time.now}] #{label}: #{message}")
    end
  rescue Exception
  end

  def debug_boot_enabled?
    GM_TRY_ENABLE_NATIVE_DEBUG == true
  rescue Exception
    false
  end

  def compiler_patch_enabled?
    GM_TRY_DISABLE_COMPILER == true
  rescue Exception
    false
  end

  def activate_native_debug!
    return unless debug_boot_enabled?
    begin
      $DEBUG = true
    rescue Exception
    end
    begin
      $TEST = true
    rescue Exception
    end
    begin
      ENV["DEBUG"] = "1"
      ENV["TEST"] = "1"
    rescue Exception
    end
    begin
      Object.const_set(:DEBUG, true) unless Object.const_defined?(:DEBUG)
    rescue Exception
    end
    begin
      Object.const_set(:TEST, true) unless Object.const_defined?(:TEST)
    rescue Exception
    end
    [
      [:System, [[:set_debug_mode, true], [:"debug_mode=", true], [:"debug=", true], [:"test_mode=", true]]],
      [:Essentials, [[:"debug_mode=", true], [:"debug=", true], [:"test_mode=", true]]],
      [:Settings, [[:"debug_mode=", true], [:"debug=", true]]]
    ].each do |receiver_name, attempts|
      begin
        next unless Object.const_defined?(receiver_name)
        receiver = Object.const_get(receiver_name)
        attempts.each do |method_name, value|
          receiver.send(method_name, value) if receiver.respond_to?(method_name)
        end
      rescue Exception
      end
    end
    log_message("Bootstrap", "Native debug activation attempt applied.")
  end

  def patch_compiler_method!(receiver, method_name)
    return unless receiver.respond_to?(method_name)
    aliased_name = :"_gm_original_#{method_name}"
    return if receiver.respond_to?(aliased_name)
    receiver.singleton_class.send(:alias_method, aliased_name, method_name)
    receiver.singleton_class.send(:define_method, method_name) do |*args, &block|
      PokeDebugBootstrap.log_message("Compiler Patch", "Skipped #{receiver}.#{method_name}")
      false
    end
  rescue Exception => e
    log_message("Compiler Patch", "#{receiver}.#{method_name} failed: #{e.message}")
  end

  def patch_object_compile_methods!
    methods = [:pbCompileAllData, :pbCompileAllDataIfNecessary, :mainFunctionDebug]
    methods.each do |method_name|
      next unless Object.private_method_defined?(method_name) || Object.method_defined?(method_name)
      aliased_name = :"_gm_original_#{method_name}"
      next if Object.private_method_defined?(aliased_name) || Object.method_defined?(aliased_name)
      Object.class_eval do
        alias_method aliased_name, method_name
        define_method(method_name) do |*args, &block|
          PokeDebugBootstrap.log_message("Compiler Patch", "Skipped Object##{method_name}")
          false
        end
        private method_name if private_method_defined?(aliased_name)
      end
    end
  rescue Exception => e
    log_message("Compiler Patch", "Object patch failed: #{e.message}")
  end

  def patch_compiler_module!
    return unless compiler_patch_enabled?
    patch_object_compile_methods!
    return unless Object.const_defined?(:Compiler)
    compiler = Object.const_get(:Compiler)
    [
      :main, :compile_all, :compile_pbs_files, :compile_pbs_file,
      :compile_pbs, :compile_all_data, :compile_all_files,
      :compile_trainer_lists, :compile_trainer_events
    ].each do |method_name|
      patch_compiler_method!(compiler, method_name)
    end
    log_message("Bootstrap", "Compiler disable patch applied.")
  rescue Exception => e
    log_message("Compiler Patch", "Compiler patch failed: #{e.message}")
  end

  def defer_compiler_patch!
    return unless compiler_patch_enabled?
    if Object.const_defined?(:Compiler)
      patch_compiler_module!
      return
    end
    return unless defined?(TracePoint)
    trace = TracePoint.new(:end) do
      next unless Object.const_defined?(:Compiler)
      patch_compiler_module!
      trace.disable
    end
    trace.enable
  rescue Exception => e
    log_message("Compiler Patch", "TracePoint setup failed: #{e.message}")
  end
end

begin
  PokeDebugBootstrap.activate_native_debug!
  PokeDebugBootstrap.defer_compiler_patch!
  plugin_path = File.expand_path("Plugins/God Mode/god_mode.rb", Dir.pwd)
  eval(File.binread(plugin_path), binding, plugin_path)
rescue Exception => e
  File.open("developer_menu_errors.log", "a") do |f|
    f.puts("[#{Time.now}] Startup Error:")
    f.puts(e.message)
    f.puts(e.backtrace.join("\n"))
  end
end
