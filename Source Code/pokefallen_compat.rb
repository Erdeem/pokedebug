# PokeDebug compatibility bridge for PokeFallen.
# Loaded before the main menu so the game's release/online guards cannot close
# the process while a local save is being opened.
module PokeDebugFallenCompat
  VERSION = "16"
  LOG_FILE = "pokedebug_pokefallen.log"

  @installed = false
  @save_load_depth = 0
  @exit_count = 0
  @patched_classes = {}

  module_function

  def applicable?
    return true if defined?(FallenLoadGuard) || defined?(FallenOnline)
    roots = [Dir.pwd]
    begin
      roots << File.dirname($0.to_s) unless $0.to_s.empty?
    rescue StandardError
    end
    roots.compact.uniq.any? do |root|
      File.file?(File.join(root, "FallenData", "Main", "Fallen.pkg")) ||
        File.file?(File.join(root, "Fallen.ini")) ||
        File.file?(File.join(root, "Fallen.exe"))
    end
  rescue StandardError
    false
  end

  def log(message)
    File.open(LOG_FILE, "ab") { |file| file.write("[PokeFallen v#{VERSION}] #{message}\r\n") }
  rescue StandardError
  end

  def save_load_active?
    @save_load_depth.to_i > 0
  end

  def begin_save_load
    @save_load_depth = @save_load_depth.to_i + 1
    log("save load entered (depth=#{@save_load_depth})")
  end

  def end_save_load
    @save_load_depth = [@save_load_depth.to_i - 1, 0].max
    log("save load left (depth=#{@save_load_depth})")
  end

  def blocked_exit(source)
    @exit_count = @exit_count.to_i + 1
    log("blocked #{source}#{save_load_active? ? ' during save load' : ''}") if @exit_count <= 40
    false
  end

  def intercepted_soft_exit(source, stack)
    protected_call = save_load_active? || Array(stack).any? do |line|
      line.to_s =~ /pbUpdateLauncher|Safe Check|protect_archives|FallenLoadGuard|fallen_exit|archivesFix/i
    end
    return blocked_exit(source) if protected_call
    nil
  rescue StandardError
    save_load_active? ? blocked_exit(source) : nil
  end

  def force_globals
    $fallen = true
    $DEBUG = false
    $adm_mode = false
    $permissao_entrada = true
    $permissão_entrada = true
    if defined?(ARGV) && ARGV.respond_to?(:include?) && !ARGV.include?("launcher")
      ARGV << "launcher"
    end
    true
  rescue StandardError => error
    log("force_globals failed: #{error.class}: #{error.message}")
    false
  end

  module KernelExitOverride
    def exit(*args)
      blocked = PokeDebugFallenCompat.intercepted_soft_exit("Kernel.exit", caller)
      return blocked unless blocked.nil?
      super
    end

    def exit!(*args)
      PokeDebugFallenCompat.blocked_exit("Kernel.exit!")
    end

    def abort(*args)
      blocked = PokeDebugFallenCompat.intercepted_soft_exit("Kernel.abort", caller)
      return blocked unless blocked.nil?
      super
    end

    def p(*args)
      if args.length == 1 && args[0].to_s == "Deprecated Variable 85"
        PokeDebugFallenCompat.log("suppressed Deprecated Variable 85 from #{caller(1, 6).join(' | ')}")
        return nil
      end
      super
    end
  end

  module ProcessExitOverride
    def exit(*args)
      return PokeDebugFallenCompat.blocked_exit("Process.exit") if PokeDebugFallenCompat.save_load_active?
      super
    end

    def exit!(*args)
      return PokeDebugFallenCompat.blocked_exit("Process.exit!") if PokeDebugFallenCompat.save_load_active?
      super
    end
  end

  module GameLoadOverride
    def load(*args, &block)
      PokeDebugFallenCompat.begin_save_load
      begin
        super
      rescue SystemExit => error
        PokeDebugFallenCompat.log("blocked SystemExit from Game.load: #{error.status.inspect} #{error.message}")
        false
      ensure
        PokeDebugFallenCompat.end_save_load
      end
    end
  end

  module LoadGuardOverride
    def force_close(*args)
      PokeDebugFallenCompat.blocked_exit("FallenLoadGuard.force_close")
    end

    def validate(*args)
      true
    end
  end

  module LoadScreenOverride
    def validate_login_save!(*args)
      PokeDebugFallenCompat.log("bypassed PokemonLoadScreen.validate_login_save!")
      true
    end
  end

  module TopLevelArchiveOverride
    def archivesFix(*args)
      PokeDebugFallenCompat.log("bypassed top-level archivesFix")
      true
    end

    def pbUpdateLauncher_and_archives(*args)
      true
    end

    def protect_fallen(*args)
      true
    end

    def pbCheckOnline(*args)
      nil
    end

    def pointsAutenticator(*args)
      true
    end

    def bpAutenticator(*args)
      true
    end
  end

  module Win32APINewOverride
    BLOCKED = /(?:TerminateProcess|ExitProcess|FatalExit|RtlExitUserProcess|NtTerminateProcess)/i

    def new(*args, &block)
      function_name = args[1].to_s rescue ""
      return BlockedNativeCall.new(function_name) if function_name =~ BLOCKED
      super
    end
  end

  class BlockedNativeCall
    def initialize(name)
      @name = name
      PokeDebugFallenCompat.log("blocked native exit API #{@name}")
    end

    def call(*args)
      PokeDebugFallenCompat.blocked_exit("native #{@name}")
    end
  end

  def prepend_once(target, patch, key)
    return false unless target && target.respond_to?(:prepend)
    return true if @patched_classes[key]
    target.send(:prepend, patch)
    @patched_classes[key] = true
    true
  rescue StandardError => error
    log("patch #{key} failed: #{error.class}: #{error.message}")
    false
  end

  def patch_runtime_objects
    force_globals
    prepend_once(Object, TopLevelArchiveOverride, :top_level_archive)
    prepend_once(Kernel, KernelExitOverride, :kernel_instance)
    prepend_once(Kernel.singleton_class, KernelExitOverride, :kernel_singleton) if Kernel.respond_to?(:singleton_class)
    prepend_once(Process.singleton_class, ProcessExitOverride, :process_singleton) if defined?(Process) && Process.respond_to?(:singleton_class)
    prepend_once(Game.singleton_class, GameLoadOverride, :game_load) if defined?(Game) && Game.respond_to?(:singleton_class)
    prepend_once(FallenLoadGuard.singleton_class, LoadGuardOverride, :fallen_load_guard) if defined?(FallenLoadGuard) && FallenLoadGuard.respond_to?(:singleton_class)
    prepend_once(PokemonLoadScreen, LoadScreenOverride, :pokemon_load_screen) if defined?(PokemonLoadScreen)
    prepend_once(Win32API.singleton_class, Win32APINewOverride, :win32_api) if defined?(Win32API) && Win32API.respond_to?(:singleton_class)

    if defined?(FallenOnline) && FallenOnline.respond_to?(:singleton_class)
      singleton = FallenOnline.singleton_class
      [:load_date_Async, :setScripts, :update].each do |name|
        singleton.send(:define_method, name) { |*args| false } if FallenOnline.respond_to?(name)
      end
    end
    if defined?(Fallen_Utilities) && Fallen_Utilities.respond_to?(:singleton_class)
      singleton = Fallen_Utilities.singleton_class
      singleton.send(:define_method, :fallen_exit) { |*args| false }
      singleton.send(:define_method, :check_beta_permission) { |*args| true }
      singleton.send(:define_method, :archivesFix) { |*args| true }
    end
    if defined?(FRP) && FRP.respond_to?(:singleton_class)
      singleton = FRP.singleton_class
      [:force_exit, :checkup, :update].each { |name| singleton.send(:define_method, name) { |*args| false } }
    end
    if defined?(System) && System.respond_to?(:singleton_class)
      singleton = System.singleton_class
      [:exit, :exit!, :terminate, :quit, :abort].each do |name|
        singleton.send(:define_method, name) { |*args| PokeDebugFallenCompat.blocked_exit("System.#{name}") } if System.respond_to?(name)
      end
    end
    if defined?($fallensalve) && $fallensalve
      begin
        $fallensalve.block = false if $fallensalve.respond_to?(:block=)
        $fallensalve.cannot_release = false if $fallensalve.respond_to?(:cannot_release=)
      rescue StandardError
      end
    end
    true
  rescue StandardError => error
    log("patch_runtime_objects failed: #{error.class}: #{error.message}")
    false
  end

  def install_definition_guard
    return false unless defined?(TracePoint)
    @definition_guard = TracePoint.new(:end) { patch_runtime_objects }
    @definition_guard.enable
    true
  rescue StandardError => error
    log("TracePoint unavailable: #{error.class}: #{error.message}")
    false
  end

  def install
    return false unless applicable?
    return true if @installed
    @installed = true
    patch_runtime_objects
    install_definition_guard
    log("compatibility bridge installed")
    true
  end
end

PokeDebugFallenCompat.install
