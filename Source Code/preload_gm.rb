#script that preloads the PokeDebug plugin and its dependencies, including the animated sprites compatibility layer.
#loaded in mkxp-z.json or rgssad file
GM_TRY_ENABLE_NATIVE_DEBUG = false unless defined?(GM_TRY_ENABLE_NATIVE_DEBUG)
GM_TRY_DISABLE_COMPILER = false unless defined?(GM_TRY_DISABLE_COMPILER)
GM_BOOT_FLAGS = {
  :runtime_debug    => GM_TRY_ENABLE_NATIVE_DEBUG == true,
  :disable_compiler => GM_TRY_DISABLE_COMPILER == true,
  :diagnostic       => false
} unless defined?(GM_BOOT_FLAGS)
POKEDEBUG_BOOTSTRAP_STATUS = :idle unless defined?(POKEDEBUG_BOOTSTRAP_STATUS)

module PokeDebugBootstrap
  VERSION = "3.1.0".freeze unless const_defined?(:VERSION)
  LOG_FILE_NAME = "developer_menu_errors.log".freeze unless const_defined?(:LOG_FILE_NAME)
  STATE_FILE_NAME = "developer_menu_boot_state.dat".freeze unless const_defined?(:STATE_FILE_NAME)
  PATCH_REGISTRY = {} unless const_defined?(:PATCH_REGISTRY)
  MAX_BOOT_FAILURES = 3 unless const_defined?(:MAX_BOOT_FAILURES)
  MAX_TRACE_EVENTS = 500 unless const_defined?(:MAX_TRACE_EVENTS)
  MIN_PLUGIN_BYTES = 64 unless const_defined?(:MIN_PLUGIN_BYTES)
  EXPECTED_PLUGIN_SHA256 = "" unless const_defined?(:EXPECTED_PLUGIN_SHA256)
  EXPECTED_PLUGIN_VERSION = "" unless const_defined?(:EXPECTED_PLUGIN_VERSION)

  module_function

  def fetch_flag(name, default_value = false)
    return default_value unless defined?(GM_BOOT_FLAGS)
    return default_value unless GM_BOOT_FLAGS.respond_to?(:[])
    value = GM_BOOT_FLAGS[name]
    value == true
  rescue StandardError
    default_value
  end

  def runtime_debug_enabled?
    fetch_flag(:runtime_debug, false)
  end

  def compiler_patch_enabled?
    fetch_flag(:disable_compiler, false)
  end

  def diagnostic_enabled?
    fetch_flag(:diagnostic, false)
  end

  def compiler_patch_required?
    compiler_patch_enabled?
  rescue StandardError
    false
  end

  def bootstrap_root
    return @bootstrap_root if defined?(@bootstrap_root) && @bootstrap_root
    root = nil
    begin
      root = File.expand_path(File.dirname(__FILE__))
    rescue StandardError
      root = nil
    end
    root = File.expand_path(".", Dir.pwd) if root.nil? || root.empty?
    @bootstrap_root = root
  rescue StandardError
    @bootstrap_root = Dir.pwd
  end

  def tracepoint_supported?
    return @tracepoint_supported unless @tracepoint_supported.nil?
    @tracepoint_supported = defined?(TracePoint) ? true : false
  rescue StandardError
    @tracepoint_supported = false
  end

  def compiler_defined?
    return @compiler_defined_cache if defined?(@compiler_defined_cache) && !@compiler_defined_cache.nil?
    @compiler_defined_cache = safe_const_defined?(Object, :Compiler)
  rescue StandardError
    @compiler_defined_cache = false
  end

  def refresh_compiler_defined!
    @compiler_defined_cache = safe_const_defined?(Object, :Compiler)
  rescue StandardError
    @compiler_defined_cache = false
  end

  def plugin_manager_defined?
    return @plugin_manager_defined_cache if defined?(@plugin_manager_defined_cache) && !@plugin_manager_defined_cache.nil?
    @plugin_manager_defined_cache = safe_const_defined?(Object, :PluginManager)
  rescue StandardError
    @plugin_manager_defined_cache = false
  end

  def reset_environment_cache!
    @compiler_defined_cache = nil
    @plugin_manager_defined_cache = nil
    @resolved_plugin_path = nil
    true
  rescue StandardError
    false
  end

  def safe_const_defined?(owner, constant_name)
    return false unless owner && constant_name
    owner.const_defined?(constant_name)
  rescue StandardError
    false
  end

  def safe_const_get(owner, constant_name)
    return nil unless safe_const_defined?(owner, constant_name)
    owner.const_get(constant_name)
  rescue StandardError
    nil
  end

  def safe_respond_to?(owner, method_name)
    return false unless owner && method_name
    owner.respond_to?(method_name)
  rescue StandardError
    false
  end

  def safe_require(library_name)
    return true unless library_name
    require library_name
    true
  rescue LoadError, StandardError => e
    log_exception("Require #{library_name}", e)
    false
  end

  def log_file_paths
    return @log_file_paths if defined?(@log_file_paths) && @log_file_paths
    paths = []
    begin
      paths << File.join(bootstrap_root, LOG_FILE_NAME) if bootstrap_root
    rescue StandardError
    end
    begin
      paths << File.join(Dir.pwd, LOG_FILE_NAME)
    rescue StandardError
    end
    begin
      paths << LOG_FILE_NAME
    rescue StandardError
    end
    @log_file_paths = paths.compact.uniq
  rescue StandardError
    @log_file_paths = [LOG_FILE_NAME]
  end

  def state_file_paths
    return @state_file_paths if defined?(@state_file_paths) && @state_file_paths
    paths = []
    begin
      paths << File.join(bootstrap_root, STATE_FILE_NAME) if bootstrap_root
    rescue StandardError
    end
    begin
      paths << File.join(Dir.pwd, STATE_FILE_NAME)
    rescue StandardError
    end
    begin
      paths << STATE_FILE_NAME
    rescue StandardError
    end
    @state_file_paths = paths.compact.uniq
  rescue StandardError
    @state_file_paths = [STATE_FILE_NAME]
  end

  def preferred_state_file_path
    state_file_paths.first
  rescue StandardError
    STATE_FILE_NAME
  end

  def write_log_line(text)
    log_file_paths.each do |path|
      begin
        File.open(path, "a") { |file| file.puts(text) }
        return true
      rescue StandardError
      end
    end
    false
  rescue StandardError
    false
  end

  def now_text
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
  rescue StandardError
    Time.now.to_s
  end

  def process_id_text
    Process.pid.to_s
  rescue StandardError
    "unknown"
  end

  def log_message(label, message, level = "INFO")
    write_log_line("[#{now_text}] [#{level}] [PokeDebugBootstrap #{VERSION}] [PID #{process_id_text}] #{label}: #{message}")
  rescue StandardError
  end

  def log_debug(label, message)
    return false unless diagnostic_enabled?
    log_message(label, message, "DEBUG")
  rescue StandardError
    false
  end

  def log_exception(label, error)
    message = begin
      error.message
    rescue StandardError
      error.to_s
    end
    log_message(label, message, "ERROR")
    backtrace = begin
      error.backtrace
    rescue StandardError
      nil
    end
    if backtrace && backtrace.respond_to?(:each)
      backtrace.each { |line| write_log_line("  #{line}") }
    end
  rescue StandardError
  end

  def run_phase(label)
    log_message("Phase", "BEGIN #{label}")
    result = yield
    log_message("Phase", "END #{label}")
    result
  rescue StandardError => e
    log_exception("Phase #{label}", e)
    false
  end

  def read_text_file(path)
    File.open(path, "rb") { |file| file.read }
  rescue StandardError => e
    log_exception("Read #{path}", e)
    nil
  end

  def read_state
    state_file_paths.each do |path|
      begin
        next unless File.file?(path)
        raw = File.open(path, "rb") { |file| file.read }
        return parse_state_text(raw)
      rescue StandardError
      end
    end
    default_state
  rescue StandardError
    default_state
  end

  def parse_state_text(raw)
    state = default_state
    return state if raw.nil? || raw.empty?
    raw.to_s.split(/\r?\n/).each do |line|
      next unless line.include?("=")
      key, value = line.split("=", 2)
      next if key.nil?
      state[key.to_s.strip] = value.to_s.strip
    end
    state
  rescue StandardError
    default_state
  end

  def default_state
    {
      "boot_failures" => "0",
      "last_error"    => "",
      "safe_mode"     => "false"
    }
  rescue StandardError
    {}
  end

  def write_state(state)
    text = state.keys.sort_by { |key| key.to_s }.map { |key| "#{key}=#{state[key]}" }.join("\n")
    state_file_paths.each do |path|
      begin
        temporary_path = path + ".tmp"
        File.open(temporary_path, "wb") do |file|
          file.write(text)
          begin file.flush rescue StandardError end
          begin file.fsync rescue StandardError end
        end
        begin File.delete(path) if File.file?(path) rescue StandardError end
        File.rename(temporary_path, path)
        return true
      rescue StandardError
        begin File.delete(temporary_path) if temporary_path && File.file?(temporary_path) rescue StandardError end
      end
    end
    false
  rescue StandardError
    false
  end

  def boot_failure_count
    read_state["boot_failures"].to_i
  rescue StandardError
    0
  end

  def safe_mode_active?
    return true if @safe_mode_active == true
    state = read_state
    state["safe_mode"].to_s == "true" || state["boot_failures"].to_i >= MAX_BOOT_FAILURES
  rescue StandardError
    false
  end

  def note_boot_success!
    state = read_state
    state["boot_failures"] = "0"
    state["last_error"] = ""
    state["safe_mode"] = "false"
    write_state(state)
    @safe_mode_active = false
    true
  rescue StandardError => e
    log_exception("Boot Success State", e)
    false
  end

  def note_boot_failure!(error)
    state = read_state
    state["boot_failures"] = (state["boot_failures"].to_i + 1).to_s
    state["last_error"] = begin
      error.message.to_s
    rescue StandardError
      error.to_s
    end
    state["safe_mode"] = state["boot_failures"].to_i >= MAX_BOOT_FAILURES ? "true" : "false"
    write_state(state)
    @safe_mode_active = (state["safe_mode"] == "true")
    true
  rescue StandardError => e
    log_exception("Boot Failure State", e)
    false
  end

  def module_has_method?(owner, method_name)
    return false unless owner && method_name
    method_text = method_name.to_s
    [owner.instance_methods, owner.private_instance_methods, owner.protected_instance_methods].each do |list|
      next unless list
      list.each { |entry| return true if entry.to_s == method_text }
    end
    false
  rescue StandardError
    false
  end

  def singleton_class_for(object)
    class << object
      self
    end
  rescue StandardError
    nil
  end

  def environment_signature
    {
      :ruby_version        => begin RUBY_VERSION rescue "unknown" end,
      :ruby_platform       => begin RUBY_PLATFORM rescue "unknown" end,
      :working_directory   => begin Dir.pwd rescue "unknown" end,
      :bootstrap_root      => bootstrap_root,
      :mkxp_json           => file_exists_any?("mkxp.json"),
      :game_ini            => file_exists_any?("Game.ini"),
      :plugin_manager      => plugin_manager_defined?,
      :compiler_defined    => compiler_defined?,
      :tracepoint          => tracepoint_supported?,
      :runtime_debug       => runtime_debug_enabled?,
      :disable_compiler    => compiler_patch_enabled?,
      :safe_mode           => safe_mode_active?,
      :boot_failures       => boot_failure_count,
      :essentials_version  => detect_essentials_version
    }
  rescue StandardError => e
    log_exception("Environment Signature", e)
    {}
  end

  def log_environment_signature
    signature = environment_signature
    signature.keys.sort_by { |key| key.to_s }.each do |key|
      log_message("Environment", "#{key}=#{signature[key].inspect}")
    end
    true
  rescue StandardError => e
    log_exception("Environment Signature", e)
    false
  end

  def file_exists_any?(relative_path)
    [bootstrap_root, begin Dir.pwd rescue nil end].compact.uniq.each do |root|
      begin
        return true if File.file?(File.join(root, relative_path))
      rescue StandardError
      end
    end
    false
  rescue StandardError
    false
  end

  def detect_essentials_version
    value = safe_const_get(Object, :ESSENTIALS_VERSION)
    return value if value
    if safe_const_defined?(Object, :Essentials)
      essentials_module = safe_const_get(Object, :Essentials)
      return essentials_module::VERSION if essentials_module && essentials_module.const_defined?(:VERSION)
    end
    if safe_const_defined?(Object, :Settings)
      settings_module = safe_const_get(Object, :Settings)
      return settings_module::ESSENTIALS_VERSION if settings_module && settings_module.const_defined?(:ESSENTIALS_VERSION)
    end
    "unknown"
  rescue StandardError
    "unknown"
  end

  def plugin_search_roots
    [bootstrap_root, begin Dir.pwd rescue nil end].compact.uniq
  rescue StandardError
    []
  end

  def plugin_search_paths
    roots = plugin_search_roots
    paths = []
    roots.each do |root|
      paths << File.join(root, "Plugins", "God Mode", "god_mode.rb")
      paths << File.join(root, "Data", "Plugins", "God Mode", "god_mode.rb")
      paths << File.join(root, "Plugins", "PokeDebug", "god_mode.rb")
      paths << File.join(root, "god_mode.rb")
    end
    paths.compact.uniq
  rescue StandardError
    []
  end

  def auxiliary_script_paths(file_name)
    roots = plugin_search_roots
    paths = []
    roots.each do |root|
      paths << File.join(root, "Plugins", "Animated Sprites", file_name)
      paths << File.join(root, "Plugins", "God Mode", file_name)
      paths << File.join(root, "Plugins", "PokeDebug", file_name)
      paths << File.join(root, file_name)
    end
    paths.compact.uniq
  rescue StandardError
    []
  end

  def plugin_file_plausible?(path, plugin_code)
    return false unless path && plugin_code
    return false if plugin_code.empty?
    return false if plugin_code.size < MIN_PLUGIN_BYTES
    header = plugin_code[0, 512].to_s
    return true if header.include?("module")
    return true if header.include?("class")
    return true if header.include?("PokeDebug")
    return true if header.include?("DeveloperMenu")
    false
  rescue StandardError
    false
  end

  # Pure Ruby SHA-256 fallback for old RGSS/Ruby 1.8 distributions that do
  # not ship digest/sha2 (Pokemon Z is one example). Integrity verification
  # remains active instead of preventing the game from booting.
  def fallback_sha256_hex(data)
    mask = 0xffffffff
    constants = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
      0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
      0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
      0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
      0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
    hash = [
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    bytes = data.to_s.unpack("C*")
    bit_length = bytes.length * 8
    bytes << 0x80
    bytes << 0 while (bytes.length % 64) != 56
    bytes.concat([(bit_length >> 32) & mask, bit_length & mask].pack("N2").unpack("C*"))
    offset = 0
    while offset < bytes.length
      words = bytes[offset, 64].pack("C*").unpack("N16")
      index = 16
      while index < 64
        x = words[index - 15]
        y = words[index - 2]
        s0 = (((x >> 7) | (x << 25)) ^ ((x >> 18) | (x << 14)) ^ (x >> 3)) & mask
        s1 = (((y >> 17) | (y << 15)) ^ ((y >> 19) | (y << 13)) ^ (y >> 10)) & mask
        words[index] = (words[index - 16] + s0 + words[index - 7] + s1) & mask
        index += 1
      end
      a, b, c, d, e, f, g, h = hash
      index = 0
      while index < 64
        sum1 = (((e >> 6) | (e << 26)) ^ ((e >> 11) | (e << 21)) ^ ((e >> 25) | (e << 7))) & mask
        choice = ((e & f) ^ ((~e) & g)) & mask
        temp1 = (h + sum1 + choice + constants[index] + words[index]) & mask
        sum0 = (((a >> 2) | (a << 30)) ^ ((a >> 13) | (a << 19)) ^ ((a >> 22) | (a << 10))) & mask
        majority = ((a & b) ^ (a & c) ^ (b & c)) & mask
        temp2 = (sum0 + majority) & mask
        h = g
        g = f
        f = e
        e = (d + temp1) & mask
        d = c
        c = b
        b = a
        a = (temp1 + temp2) & mask
        index += 1
      end
      work = [a, b, c, d, e, f, g, h]
      hash.each_index { |i| hash[i] = (hash[i] + work[i]) & mask }
      offset += 64
    end
    hash.map { |value| sprintf("%08x", value) }.join
  rescue StandardError => e
    log_exception("Fallback SHA-256", e)
    nil
  end

  def sha256_hex(data)
    unless defined?(Digest) && defined?(Digest::SHA256)
      begin
        require "digest/sha2"
      rescue LoadError
        begin
          require "digest"
        rescue LoadError
        end
      end
    end
    return Digest::SHA256.hexdigest(data) if defined?(Digest) && defined?(Digest::SHA256)
    unless @fallback_sha256_logged
      log_message("Plugin Integrity", "digest/sha2 unavailable; using compatible internal SHA-256.")
      @fallback_sha256_logged = true
    end
    fallback_sha256_hex(data)
  rescue LoadError, StandardError => e
    log_exception("SHA-256", e)
    fallback_sha256_hex(data)
  end

  def plugin_digest_valid?(plugin_code)
    expected = EXPECTED_PLUGIN_SHA256.to_s.strip.downcase
    return true if expected.empty?
    actual = sha256_hex(plugin_code).to_s.downcase
    return false if actual.empty?
    if actual != expected
      log_message("Plugin Integrity", "SHA-256 mismatch. expected=#{expected} actual=#{actual}", "WARN")
      return false
    end
    true
  rescue StandardError => e
    log_exception("Plugin Integrity", e)
    false
  end

  def plugin_runtime_ready?
    return false unless safe_const_defined?(Object, :DeveloperMenu)
    menu = safe_const_get(Object, :DeveloperMenu)
    return false unless menu
    return false unless safe_const_defined?(menu, :VERSION)
    actual_version = safe_const_get(menu, :VERSION).to_s
    return false if actual_version.empty?
    expected_version = EXPECTED_PLUGIN_VERSION.to_s
    return false if !expected_version.empty? && actual_version != expected_version
    true
  rescue StandardError
    false
  end

  def resolve_plugin_path
    return @resolved_plugin_path if defined?(@resolved_plugin_path) && @resolved_plugin_path
    plugin_search_paths.each do |path|
      next unless File.file?(path)
      code = read_text_file(path)
      if plugin_file_plausible?(path, code)
        @resolved_plugin_path = path
        return @resolved_plugin_path
      end
      log_message("Plugin Loader", "Rejected implausible plugin candidate: #{path}", "WARN")
    end
    nil
  rescue StandardError => e
    log_exception("Resolve Plugin Path", e)
    nil
  end

  def load_plugin_file(path)
    unless path && File.file?(path)
      log_message("Plugin Loader", "Plugin file not found: #{path.inspect}", "WARN")
      return false
    end

    plugin_code = read_text_file(path)
    if plugin_code.nil? || plugin_code.empty?
      log_message("Plugin Loader", "Plugin file was empty or unreadable: #{path}", "WARN")
      return false
    end

    unless plugin_file_plausible?(path, plugin_code)
      log_message("Plugin Loader", "Plugin file failed integrity checks: #{path}", "WARN")
      return false
    end
    unless plugin_digest_valid?(plugin_code)
      log_message("Plugin Loader", "Plugin file failed SHA-256 verification: #{path}", "WARN")
      return false
    end

    log_message("Plugin Loader", "Loading plugin from #{path} (#{plugin_code.size} bytes).")
    return false unless load_trusted_script(path, "Plugin Loader")
    unless plugin_runtime_ready?
      log_message("Plugin Loader", "File executed, but DeveloperMenu::VERSION was not initialized.", "WARN")
      return false
    end
    log_message("Plugin Loader", "Plugin load completed and runtime marker was confirmed.")
    true
  rescue StandardError => e
    log_exception("Plugin Loader", e)
    false
  end

  def load_plugin_with_fallbacks!
    candidates = plugin_search_paths
    log_debug("Plugin Loader", "Candidates=#{candidates.inspect}")
    candidates.each do |path|
      next unless File.file?(path)
      if load_plugin_file(path)
        load_auxiliary_script("animated_sprites_compat.rb")
        return true
      end
      log_message("Plugin Loader", "Trying next plugin fallback after failure: #{path}", "WARN")
    end
    log_message("Plugin Loader", "No working plugin file found in known locations.", "WARN")
    false
  rescue StandardError => e
    log_exception("Plugin Loader", e)
    false
  end

  def load_auxiliary_script(file_name)
    auxiliary_script_paths(file_name).each do |path|
      next unless File.file?(path)
      code = read_text_file(path)
      next if code.nil? || code.empty?
      log_message("Auxiliary Loader", "Loading #{file_name} from #{path} (#{code.size} bytes).")
      next unless load_trusted_script(path, "Auxiliary Loader")
      return true
    end
    false
  rescue StandardError => e
    log_exception("Auxiliary Loader #{file_name}", e)
    false
  end

  def trusted_script_path?(path)
    expanded = normalized_trusted_path(path)
    plugin_search_roots.any? do |root|
      trusted_root = normalized_trusted_path(root)
      expanded == trusted_root || expanded.index(trusted_root + "/") == 0
    end
  rescue StandardError
    false
  end

  def normalized_trusted_path(path)
    normalized = File.expand_path(path.to_s).tr("\\", "/").sub(/\/+\z/, "")
    if defined?(RUBY_PLATFORM) && RUBY_PLATFORM.to_s =~ /mswin|mingw|windows/i
      normalized.downcase
    else
      normalized
    end
  rescue StandardError
    path.to_s.tr("\\", "/").sub(/\/+\z/, "")
  end

  def load_trusted_script(path, context_name = "Script Loader")
    unless trusted_script_path?(path)
      log_message(context_name, "Rejected script outside trusted game roots: #{path.inspect}", "WARN")
      return false
    end
    Kernel.load(File.expand_path(path.to_s))
    true
  rescue StandardError => e
    log_exception(context_name, e)
    false
  end

  def set_runtime_debug_flag!(value)
    old_value = begin
      $DEBUG
    rescue StandardError
      nil
    end
    $DEBUG = value ? true : false
    log_message("Runtime Debug", "Runtime debug flag changed from #{old_value.inspect} to #{$DEBUG.inspect}.")
    true
  rescue StandardError => e
    log_exception("Runtime Debug", e)
    false
  end

  def activate_native_debug!
    return false unless runtime_debug_enabled?
    log_message("Runtime Debug", "Boot-time runtime debug requested. Applying safe runtime debug flag only.")
    set_runtime_debug_flag!(true)
  rescue StandardError => e
    log_exception("Runtime Debug", e)
    false
  end

  def patch_registry_key(receiver, method_name)
    receiver.object_id.to_s + ":" + method_name.to_s
  rescue StandardError
    method_name.to_s
  end

  def patch_applied?(receiver, method_name)
    PATCH_REGISTRY.has_key?(patch_registry_key(receiver, method_name))
  rescue StandardError
    false
  end

  def register_patch(receiver, method_name, data)
    PATCH_REGISTRY[patch_registry_key(receiver, method_name)] = data
  rescue StandardError
  end

  def unregister_patch(receiver, method_name)
    PATCH_REGISTRY.delete(patch_registry_key(receiver, method_name))
  rescue StandardError
  end

  def method_list_includes?(owner, method_name)
    return false unless owner && method_name
    owner.instance_methods.map { |entry| entry.to_s }.include?(method_name.to_s)
  rescue StandardError
    false
  end

  def safe_method_patch(receiver, method_name, replacement_proc, options = nil)
    options ||= {}
    return false unless receiver && method_name && replacement_proc
    return false if patch_applied?(receiver, method_name)
    return false unless safe_respond_to?(receiver, method_name)

    eigenclass = singleton_class_for(receiver)
    return false unless eigenclass
    aliased_name = options[:alias_name] || :"_gm_original_#{method_name}"

    unless method_list_includes?(eigenclass, aliased_name)
      eigenclass.send(:alias_method, aliased_name, method_name)
    end
    eigenclass.send(:define_method, method_name, &replacement_proc)
    register_patch(receiver, method_name, {
      :receiver     => receiver,
      :method_name  => method_name,
      :aliased_name => aliased_name,
      :singleton    => true
    })
    true
  rescue StandardError => e
    log_exception("Safe Method Patch", e)
    false
  end

  def patch_compiler_method!(receiver, method_name)
    safe_method_patch(receiver, method_name, proc do |*args|
      PokeDebugBootstrap.log_message("Compiler Patch", "Skipped #{receiver}.#{method_name}")
      false
    end)
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def patch_object_compile_methods!
    patched = false
    [:pbCompileAllData, :pbCompileAllDataIfNecessary].each do |method_name|
      next unless module_has_method?(Object, method_name)
      next if patch_applied?(Object, method_name)
      aliased_name = :"_gm_original_#{method_name}"
      Object.class_eval do
        alias_method aliased_name, method_name unless instance_methods.map { |entry| entry.to_s }.include?(aliased_name.to_s)
        define_method(method_name) do |*args|
          PokeDebugBootstrap.log_message("Compiler Patch", "Skipped Object##{method_name}")
          false
        end
      end
      register_patch(Object, method_name, {
        :receiver     => Object,
        :method_name  => method_name,
        :aliased_name => aliased_name,
        :singleton    => false
      })
      patched = true
    end
    patched
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def unpatch_compiler_method!(receiver, method_name)
    patch_info = PATCH_REGISTRY[patch_registry_key(receiver, method_name)]
    return false unless patch_info
    aliased_name = patch_info[:aliased_name]
    if patch_info[:singleton]
      eigenclass = singleton_class_for(receiver)
      return false unless eigenclass
      eigenclass.send(:alias_method, method_name, aliased_name) if method_list_includes?(eigenclass, aliased_name)
    else
      Object.class_eval do
        alias_method method_name, aliased_name if instance_methods.map { |entry| entry.to_s }.include?(aliased_name.to_s)
      end
    end
    unregister_patch(receiver, method_name)
    log_message("Compiler Patch", "Restored #{receiver}.#{method_name}")
    true
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def unpatch_all_compiler_methods!
    PATCH_REGISTRY.values.dup.each do |patch_info|
      unpatch_compiler_method!(patch_info[:receiver], patch_info[:method_name])
    end
    true
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def patch_compiler_module!
    return false unless compiler_patch_required?
    patched_any = false
    patched_any = patch_object_compile_methods! || patched_any

    refresh_compiler_defined!
    unless compiler_defined?
      log_message("Compiler Patch", "Compiler constant not defined yet.", "WARN")
      return patched_any
    end

    compiler = safe_const_get(Object, :Compiler)
    return patched_any unless compiler

    [
      :main, :compile_all, :compile_pbs_files, :compile_pbs_file,
      :compile_pbs, :compile_all_data, :compile_all_files,
      :compile_trainer_lists, :compile_trainer_events
    ].each do |method_name|
      patched_any = patch_compiler_method!(compiler, method_name) || patched_any
    end

    log_message("Compiler Patch", patched_any ? "Compiler disable patch applied." : "Compiler disable patch was requested but no target methods were patched.", patched_any ? "INFO" : "WARN")
    patched_any
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def trace_active?
    @compiler_trace_active == true
  rescue StandardError
    false
  end

  def stop_compiler_trace!
    return false unless @compiler_trace
    @compiler_trace.disable
    @compiler_trace = nil
    @compiler_trace_active = false
    @compiler_trace_events = 0
    log_message("Compiler Patch", "Compiler TracePoint disabled.")
    true
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def defer_compiler_patch!
    return false unless compiler_patch_required?

    refresh_compiler_defined!
    return patch_compiler_module! if compiler_defined?

    unless tracepoint_supported?
      log_message("Compiler Patch", "TracePoint unavailable. Deferred compiler patch skipped.", "WARN")
      return false
    end

    return true if trace_active?

    @compiler_trace_events = 0
    @compiler_trace = TracePoint.new(:end) do
      @compiler_trace_events = @compiler_trace_events.to_i + 1
      if @compiler_trace_events >= MAX_TRACE_EVENTS
        PokeDebugBootstrap.log_message("Compiler Patch", "TracePoint circuit breaker reached #{MAX_TRACE_EVENTS} events without finding Compiler.", "WARN")
        PokeDebugBootstrap.stop_compiler_trace!
        next
      end

      PokeDebugBootstrap.refresh_compiler_defined!
      next unless PokeDebugBootstrap.compiler_defined?
      PokeDebugBootstrap.patch_compiler_module!
      PokeDebugBootstrap.stop_compiler_trace!
    end
    @compiler_trace.enable
    @compiler_trace_active = true
    log_message("Compiler Patch", "Compiler TracePoint enabled while waiting for Compiler constant.")
    true
  rescue StandardError => e
    log_exception("Compiler Patch", e)
    false
  end

  def bootstrap_already_loaded?
    defined?(POKEDEBUG_BOOTSTRAP_STATUS) && POKEDEBUG_BOOTSTRAP_STATUS == :loaded
  rescue StandardError
    false
  end

  def set_bootstrap_status!(status)
    Object.send(:remove_const, :POKEDEBUG_BOOTSTRAP_STATUS) if defined?(POKEDEBUG_BOOTSTRAP_STATUS)
    Object.const_set(:POKEDEBUG_BOOTSTRAP_STATUS, status)
    true
  rescue StandardError => e
    log_exception("Bootstrap Loaded Flag", e)
    false
  end

  def run_bootstrap_core!
    run_phase("Setup") do
      reset_environment_cache!
      safe_require("zlib") unless defined?(Zlib)
      true
    end

    run_phase("Environment Signature") do
      log_environment_signature
    end

    run_phase("Runtime Debug") do
      if safe_mode_active?
        log_message("Runtime Debug", "Safe mode is active. Runtime debug boot flag will be ignored.", "WARN")
        true
      else
        activate_native_debug!
      end
    end

    run_phase("Compiler Patch") do
      if safe_mode_active?
        log_message("Compiler Patch", "Safe mode is active. Compiler patch phase skipped.", "WARN")
        true
      else
        defer_compiler_patch!
      end
    end

    plugin_loaded = run_phase("Plugin Loader") do
      load_plugin_with_fallbacks!
    end
    return false unless plugin_loaded && plugin_runtime_ready?

    run_phase("Post Load Checks") do
      log_message("Bootstrap", "Post-load checks complete. patches=#{PATCH_REGISTRY.size} safe_mode=#{safe_mode_active?.inspect}")
      true
    end
    true
  end

  def bootstrap!
    if bootstrap_already_loaded?
      log_message("Bootstrap", "Duplicate preload attempt ignored.", "WARN")
      return false
    end

    log_message("Bootstrap", "Starting preload. runtime_debug=#{runtime_debug_enabled?.inspect} disable_compiler=#{compiler_patch_enabled?.inspect} diagnostic=#{diagnostic_enabled?.inspect}")

    begin
      set_bootstrap_status!(:loading)
      result = run_bootstrap_core!
      if result && plugin_runtime_ready?
        set_bootstrap_status!(:loaded)
        note_boot_success!
      else
        set_bootstrap_status!(:failed)
        note_boot_failure!(RuntimeError.new("PokeDebug plugin did not initialize"))
        result = false
      end
      result
    rescue StandardError => e
      set_bootstrap_status!(:failed)
      note_boot_failure!(e)
      log_exception("Startup Error", e)
      false
    end
  end
end

PokeDebugBootstrap.bootstrap!
