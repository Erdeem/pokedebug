GM_TRY_ENABLE_NATIVE_DEBUG = false unless defined?(GM_TRY_ENABLE_NATIVE_DEBUG)
GM_TRY_DISABLE_COMPILER = false unless defined?(GM_TRY_DISABLE_COMPILER)

module PokeDebugBootstrap
  module_function

  def module_has_method?(owner, method_name)
    return false unless owner
    public_methods = owner.instance_methods rescue []
    private_methods = owner.private_instance_methods rescue []
    protected_methods = owner.protected_instance_methods rescue []
    method_text = method_name.to_s
    [public_methods, private_methods, protected_methods].each do |list|
      list.each do |entry|
        return true if entry.to_s == method_text
      end
    end
    false
  rescue Exception
    false
  end

  def singleton_class_for(object)
    class << object
      self
    end
  rescue Exception
    nil
  end

  def read_text_file(path)
    File.open(path, "rb") { |file| file.read }
  rescue Exception => e
    log_message("Bootstrap", "Failed to read #{path}: #{e.message}")
    nil
  end

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
    eigenclass = singleton_class_for(receiver)
    return unless eigenclass
    eigenclass.send(:alias_method, aliased_name, method_name)
    eigenclass.send(:define_method, method_name) do |*args, &block|
      PokeDebugBootstrap.log_message("Compiler Patch", "Skipped #{receiver}.#{method_name}")
      false
    end
  rescue Exception => e
    log_message("Compiler Patch", "#{receiver}.#{method_name} failed: #{e.message}")
  end

  def patch_object_compile_methods!
    methods = [:pbCompileAllData, :pbCompileAllDataIfNecessary, :mainFunctionDebug]
    methods.each do |method_name|
      next unless module_has_method?(Object, method_name)
      aliased_name = :"_gm_original_#{method_name}"
      next if module_has_method?(Object, aliased_name)
      Object.class_eval do
        alias_method aliased_name, method_name
        define_method(method_name) do |*args, &block|
          PokeDebugBootstrap.log_message("Compiler Patch", "Skipped Object##{method_name}")
          false
        end
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
  begin
    require "zlib" unless defined?(Zlib)
  rescue Exception => e
    PokeDebugBootstrap.log_message("Bootstrap", "Zlib require failed: #{e.message}")
  end
  PokeDebugBootstrap.activate_native_debug!
  PokeDebugBootstrap.defer_compiler_patch!
  plugin_path = File.expand_path("Plugins/God Mode/god_mode.rb", Dir.pwd)
  plugin_code = PokeDebugBootstrap.read_text_file(plugin_path)
  eval(plugin_code, binding, plugin_path) if plugin_code
rescue Exception => e
  File.open("developer_menu_errors.log", "a") do |f|
    f.puts("[#{Time.now}] Startup Error:")
    f.puts(e.message)
    f.puts(e.backtrace.join("\n"))
  end
end
