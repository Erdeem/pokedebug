
begin
  # Hash rockets keep this file parseable by RGSS1/Ruby 1.8 games.
  _gm_env = {
    :rgss => defined?(RGSS_VERSION) ? RGSS_VERSION : (defined?(RUBY_VERSION) ? RUBY_VERSION : "unknown"),
    :graphics => defined?(Graphics) ? true : false,
    :input => defined?(Input) ? true : false,
    :win32 => defined?(Win32API) ? true : false,
    :fiddle => defined?(Fiddle) ? true : false
  }
  if ::DeveloperMenu.respond_to?(:write_developer_log)
    ::DeveloperMenu.write_developer_log("core", "Boot Environment", _gm_env.inspect)
  end
rescue
end

::DeveloperMenu.initialize_variables if ::DeveloperMenu.walk_through_walls.nil?


module ::DeveloperMenu
  module GMInputTriggerPatch
    def trigger?(*args, &block)
      return super(*args, &block) if $_gm_checking_trigger
      $_gm_checking_trigger = true
      begin
        current_frame = begin
          Graphics.frame_count
        rescue
          nil
        end
        if current_frame.nil? || !defined?($_gm_last_input_update_frame) || $_gm_last_input_update_frame != current_frame
          $_gm_last_input_update_frame = current_frame
          begin
            ::DeveloperMenu.on_input_update
          rescue Exception => e
            if ::DeveloperMenu.respond_to?(:throttled_log_error)
              ::DeveloperMenu.throttled_log_error("Input.trigger? hook", e, 2)
            elsif ::DeveloperMenu.respond_to?(:log_error)
              ::DeveloperMenu.log_error("Input.trigger? hook", e)
            end
          end
        end
        if current_frame.nil? || !defined?($_gm_last_map_update_frame) || $_gm_last_map_update_frame != current_frame
          $_gm_last_map_update_frame = current_frame
          if current_frame.nil? || (current_frame % 2) == 0
            begin
              ::DeveloperMenu.on_map_update
            rescue Exception => e
              if ::DeveloperMenu.respond_to?(:throttled_log_error)
                ::DeveloperMenu.throttled_log_error("Input.trigger? map hook", e, 2)
              elsif ::DeveloperMenu.respond_to?(:log_error)
                ::DeveloperMenu.log_error("Input.trigger? map hook", e)
              end
            end
          end
        end
      ensure
        $_gm_checking_trigger = false
      end
      super(*args, &block)
    end

    def press?(*args, &block)
      return super(*args, &block) if $_gm_checking_trigger
      $_gm_checking_trigger = true
      begin
        current_frame = begin
          Graphics.frame_count
        rescue
          nil
        end
        if current_frame.nil? || !defined?($_gm_last_input_update_frame) || $_gm_last_input_update_frame != current_frame
          $_gm_last_input_update_frame = current_frame
          begin
            ::DeveloperMenu.on_input_update
          rescue Exception => e
            if ::DeveloperMenu.respond_to?(:throttled_log_error)
              ::DeveloperMenu.throttled_log_error("Input.press? hook", e, 2)
            elsif ::DeveloperMenu.respond_to?(:log_error)
              ::DeveloperMenu.log_error("Input.press? hook", e)
            end
          end
        end
        if current_frame.nil? || !defined?($_gm_last_map_update_frame) || $_gm_last_map_update_frame != current_frame
          $_gm_last_map_update_frame = current_frame
          if current_frame.nil? || (current_frame % 2) == 0
            begin
              ::DeveloperMenu.on_map_update
            rescue Exception => e
              if ::DeveloperMenu.respond_to?(:throttled_log_error)
                ::DeveloperMenu.throttled_log_error("Input.press? map hook", e, 2)
              elsif ::DeveloperMenu.respond_to?(:log_error)
                ::DeveloperMenu.log_error("Input.press? map hook", e)
              end
            end
          end
        end
      ensure
        $_gm_checking_trigger = false
      end
      super(*args, &block)
    end
  end
end

class << ::DeveloperMenu
  def run_legacy_input_hooks(context_name)
    return if $_gm_checking_trigger
    $_gm_checking_trigger = true
    begin
      current_frame = begin Graphics.frame_count; rescue; nil; end
      if current_frame.nil? || !defined?($_gm_last_input_update_frame) || $_gm_last_input_update_frame != current_frame
        $_gm_last_input_update_frame = current_frame
        begin
          on_input_update
        rescue Exception => e
          throttled_log_error("#{context_name} hook", e, 2) if respond_to?(:throttled_log_error)
        end
      end
      if current_frame.nil? || !defined?($_gm_last_map_update_frame) || $_gm_last_map_update_frame != current_frame
        $_gm_last_map_update_frame = current_frame
        if current_frame.nil? || (current_frame % 2) == 0
          begin
            on_map_update
          rescue Exception => e
            throttled_log_error("#{context_name} map hook", e, 2) if respond_to?(:throttled_log_error)
          end
        end
      end
    ensure
      $_gm_checking_trigger = false
    end
  end

end

module ::DeveloperMenu
  module GMSceneMapHeartbeatPatch
    def update(*args, &block)
      begin
        ::DeveloperMenu.on_graphics_hotkey_heartbeat
      rescue Exception => e
        ::DeveloperMenu.throttled_log_error("Scene_Map heartbeat hook", e, 2) if ::DeveloperMenu.respond_to?(:throttled_log_error)
      end
      super(*args, &block)
    end
  end
end

class << ::DeveloperMenu
  def install_modern_input_hooks!
    return false unless defined?(Input)
    input_eigenclass = class << Input; self; end
    return false unless input_eigenclass.respond_to?(:prepend)
    unless input_eigenclass.ancestors.include?(::DeveloperMenu::GMInputTriggerPatch)
      input_eigenclass.send(:prepend, ::DeveloperMenu::GMInputTriggerPatch)
    end
    unless @modern_input_hook_logged
      write_developer_log("input", "Input Hook", "Installed trigger/press hooks") if respond_to?(:write_developer_log)
      @modern_input_hook_logged = true
    end
    true
  rescue Exception => e
    log_error("Install Modern Input Hooks", e) if respond_to?(:log_error)
    false
  end


  def install_scene_map_heartbeat_hook!
    return false unless defined?(Scene_Map)
    return false unless Scene_Map.respond_to?(:prepend, true)
    unless Scene_Map.ancestors.include?(::DeveloperMenu::GMSceneMapHeartbeatPatch)
      Scene_Map.send(:prepend, ::DeveloperMenu::GMSceneMapHeartbeatPatch)
      write_developer_log("input", "Scene Map Hook", "Installed independent heartbeat") if respond_to?(:write_developer_log)
    end
    true
  rescue Exception => e
    throttled_log_error("Install Scene_Map Heartbeat Hook", e, 2) if respond_to?(:throttled_log_error)
    false
  end
end

begin
  if defined?(TracePoint)
    $pokedebug_scene_map_boot_trace = TracePoint.new(:end) do
      if defined?(Scene_Map) && ::DeveloperMenu.install_scene_map_heartbeat_hook!
        $pokedebug_scene_map_boot_trace.disable
      end
    end
    $pokedebug_scene_map_boot_trace.enable
  end
rescue Exception => e
  ::DeveloperMenu.throttled_log_error("Scene_Map Hook Trace", e, 2) if ::DeveloperMenu.respond_to?(:throttled_log_error)
end

# RGSS games load the external PokeDebug bootstrap from Main immediately before
# PluginManager.runPlugins. Installing a prepend hook at that point is too early:
# a later plugin may alias Input.press? to the prepended method and create a
# PokeDebug -> plugin -> PokeDebug recursion. Defer until the plugin chain is
# complete, then place PokeDebug safely around it.
_gm_defer_modern_input_hooks = false
if defined?(PluginManager) && PluginManager.respond_to?(:runPlugins)
  plugin_manager_eigenclass = class << PluginManager; self; end
  unless plugin_manager_eigenclass.method_defined?(:_gm_run_plugins_before_input_hooks)
    plugin_manager_eigenclass.send(:alias_method, :_gm_run_plugins_before_input_hooks, :runPlugins)
    # Ruby 1.8.1 cannot parse an explicit &block parameter in a block passed
    # to define_method. PluginManager.runPlugins doesn't consume a caller
    # block, so keep only the splatted arguments for legacy RGSS runtimes.
    plugin_manager_eigenclass.send(:define_method, :runPlugins, proc do |*args|
      result = _gm_run_plugins_before_input_hooks(*args)
      ::DeveloperMenu.install_modern_input_hooks!
      result
    end)
  end
  _gm_defer_modern_input_hooks = true
end

if defined?(Input)
  input_eigenclass = class << Input; self; end
  if input_eigenclass.respond_to?(:prepend)
    ::DeveloperMenu.install_modern_input_hooks! unless _gm_defer_modern_input_hooks
  else
    class << Input
      unless method_defined?(:_gm_orig_trigger_legacy)
        alias_method :_gm_orig_trigger_legacy, :trigger?
        def trigger?(*args, &block)
          return _gm_orig_trigger_legacy(*args, &block) if $_gm_checking_trigger
          ::DeveloperMenu.run_legacy_input_hooks("Input.trigger?")
          _gm_orig_trigger_legacy(*args, &block)
        end
      end
      if method_defined?(:press?) && !method_defined?(:_gm_orig_press_legacy)
        alias_method :_gm_orig_press_legacy, :press?
        def press?(*args, &block)
          return _gm_orig_press_legacy(*args, &block) if $_gm_checking_trigger
          ::DeveloperMenu.run_legacy_input_hooks("Input.press?")
          _gm_orig_press_legacy(*args, &block)
        end
      end
    end
  end
end

# ===============================================================================
# ENGINE MONKEY PATCHES (For Extras Category)
# ===============================================================================

class << ::DeveloperMenu
  def player_pokemon_count
    return $player.pokemon_count if defined?($player) && $player && $player.respond_to?(:pokemon_count)
    party = player_party
    return party.length if party
    0
  rescue
    0
  end

  def player_able_pokemon_count
    return $player.able_pokemon_count if defined?($player) && $player && $player.respond_to?(:able_pokemon_count)
    party = player_party
    return 0 unless party
    party.count do |pkmn|
      next false if pkmn.nil?
      if pkmn.respond_to?(:able?)
        pkmn.able?
      else
        hp = pkmn.respond_to?(:hp) ? pkmn.hp.to_i : 0
        hp > 0
      end
    end
  rescue
    0
  end

  def no_battles_active?
    no_wild_battles_active? || no_trainer_battles_active?
  rescue
    false
  end

  def no_battle_result_value(trainer_battle = false)
    able_count = player_able_pokemon_count
    return 0 if trainer_battle && able_count <= 0
    1
  rescue
    1
  end

  def no_battle_result(*args)
    trainer_battle = !!args.last if args.length > 0 && (args.last == true || args.last == false)
    no_battle_result_value(trainer_battle)
  rescue
    1
  end

  def no_battle_skip_messages!(trainer_battle = false, debug_style = true)
    current_frame = begin
      Graphics.frame_count
    rescue
      nil
    end
    return false if !current_frame.nil? && defined?(@last_no_battle_message_frame) && @last_no_battle_message_frame == current_frame
    @last_no_battle_message_frame = current_frame
    if !trainer_battle && player_pokemon_count > 0
      safe_text_message("SKIPPING BATTLE...", "Wild Battle Skip Message")
    elsif trainer_battle && debug_style
      safe_text_message("SKIPPING BATTLE...", "Trainer Battle Skip Message")
    end
    safe_text_message("AFTER WINNING...", "Trainer Battle Victory Message") if trainer_battle && player_able_pokemon_count > 0
    true
  rescue => e
    log_error("No Battle Skip Messages", e)
    false
  end

  def clear_battle_runtime_flags!
    begin
      $PokemonGlobal.nextBattleBGM = nil if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:nextBattleBGM=)
    rescue
    end
    begin
      $PokemonGlobal.nextBattleVictoryBGM = nil if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:nextBattleVictoryBGM=)
    rescue
    end
    begin
      $PokemonGlobal.nextBattleCaptureME = nil if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:nextBattleCaptureME=)
    rescue
    end
    begin
      $PokemonGlobal.nextBattleBack = nil if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:nextBattleBack=)
    rescue
    end
    begin
      $PokemonTemp.waitingTrainer = nil if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:waitingTrainer=)
    rescue
    end
    begin
      $game_temp.in_battle = false if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_battle=)
    rescue
    end
    begin
      $PokemonGlobal.battling = false if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:battling=)
    rescue
    end
    begin
      $game_temp.clear_battle_rules if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:clear_battle_rules)
    rescue
    end
    begin
      if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:memorized_bgm) && $game_temp.memorized_bgm && defined?($game_system) && $game_system
        $game_system.bgm_pause if $game_system.respond_to?(:bgm_pause)
        if $game_system.respond_to?(:bgm_position=) && $game_temp.respond_to?(:memorized_bgm_position)
          $game_system.bgm_position = $game_temp.memorized_bgm_position
        end
        $game_system.bgm_resume($game_temp.memorized_bgm) if $game_system.respond_to?(:bgm_resume)
      end
    rescue
    end
    begin
      $game_temp.memorized_bgm = nil if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:memorized_bgm=)
      $game_temp.memorized_bgm_position = 0 if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:memorized_bgm_position=)
    rescue
    end
    begin
      $PokemonEncounters.reset_step_count if defined?($PokemonEncounters) && $PokemonEncounters && $PokemonEncounters.respond_to?(:reset_step_count)
    rescue
    end
    true
  rescue
    true
  end

  def no_wild_battle_skip!(*args)
    outcome = no_battle_result_value(false)
    no_battle_skip_messages!(false, true)
    clear_battle_runtime_flags!
    begin
      pbSet(1, outcome) if defined?(pbSet)
    rescue
    end
    outcome
  rescue
    1
  end

  def no_trainer_battle_skip!(*args)
    outcome = no_battle_result_value(true)
    no_battle_skip_messages!(true, true)
    clear_battle_runtime_flags!
    begin
      pbSet(1, outcome) if defined?(pbSet)
    rescue
    end
    outcome
  rescue
    1
  end

  def core_style_skip_battle!(trainer_battle = false)
    if defined?(BattleCreationHelperMethods)
      helper = BattleCreationHelperMethods
      if helper.respond_to?(:skip_battle)
        outcome_var = begin
          if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:battle_rules)
            $game_temp.battle_rules["outcomeVar"] || 1
          else
            1
          end
        rescue
          1
        end
        return helper.skip_battle(outcome_var, trainer_battle)
      end
    end
    trainer_battle ? no_trainer_battle_skip! : no_wild_battle_skip!
  rescue => e
    log_error("Core Style Skip Battle", e)
    trainer_battle ? no_trainer_battle_skip! : no_wild_battle_skip!
  end

  def patch_no_battle_global_method!(method_name, alias_name, mode = :wild, &result_block)
    return false unless ::DeveloperMenu.module_has_method?(Object, method_name) || ::DeveloperMenu.module_has_method?(Kernel, method_name)
    return false if ::DeveloperMenu.module_has_method?(Object, alias_name) || ::DeveloperMenu.module_has_method?(Kernel, alias_name)
    Object.send(:alias_method, alias_name, method_name)
    Object.send(:define_method, method_name) do |*args|
      active = (mode == :trainer) ? ::DeveloperMenu.no_trainer_battles_active? : ::DeveloperMenu.no_wild_battles_active?
      if active
        return result_block.call(*args) if result_block
        fallback = (mode == :trainer) ? ::DeveloperMenu.no_trainer_battle_skip!(*args) : ::DeveloperMenu.no_wild_battle_skip!(*args)
        return fallback
      end
      send(alias_name, *args)
    end
    true
  rescue => e
    ::DeveloperMenu.log_error("Patch Global No Battle #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
    false
  end

  def patch_no_battle_owner_method!(owner, method_name, alias_name, mode = :wild, &result_block)
    return false unless owner
    return false unless ::DeveloperMenu.make_alias(alias_name, method_name, owner)
    owner.module_eval do
      define_method(method_name) do |*args|
        active = (mode == :trainer) ? ::DeveloperMenu.no_trainer_battles_active? : ::DeveloperMenu.no_wild_battles_active?
        if active
          return result_block.call(*args) if result_block
          fallback = (mode == :trainer) ? ::DeveloperMenu.no_trainer_battle_skip!(*args) : ::DeveloperMenu.no_wild_battle_skip!(*args)
          return fallback
        end
        send(alias_name, *args)
      end
      ruby2_keywords(method_name) if respond_to?(:ruby2_keywords, true)
    end
    true
  rescue => e
    ::DeveloperMenu.log_error("Patch Owner No Battle #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
    false
  end

  def patch_no_battle_owner_method_dynamic!(owner, method_name, mode = :wild, &result_block)
    return false unless owner
    alias_name = "_gm_orig_#{method_name}_dev_#{owner.object_id}".to_sym
    patch_no_battle_owner_method!(owner, method_name, alias_name, mode, &result_block)
  rescue => e
    ::DeveloperMenu.log_error("Patch Dynamic Owner No Battle #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
    false
  end

  def patch_no_battle_singleton_method_dynamic!(object, method_name, mode = :wild, &result_block)
    return false unless object
    eigenclass = ::DeveloperMenu.safe_singleton_class(object)
    return false unless eigenclass
    return false unless ::DeveloperMenu.module_has_method?(eigenclass, method_name)
    alias_name = "_gm_orig_#{method_name}_singleton_dev_#{object.object_id}".to_sym
    return false unless ::DeveloperMenu.make_singleton_alias(object, alias_name, method_name)
    eigenclass.class_eval do
      define_method(method_name) do |*args|
        active = (mode == :trainer) ? ::DeveloperMenu.no_trainer_battles_active? : ::DeveloperMenu.no_wild_battles_active?
        if active
          return result_block.call(*args) if result_block
          fallback = (mode == :trainer) ? ::DeveloperMenu.no_trainer_battle_skip!(*args) : ::DeveloperMenu.no_wild_battle_skip!(*args)
          return fallback
        end
        send(alias_name, *args)
      end
      ruby2_keywords(method_name) if respond_to?(:ruby2_keywords, true)
    end
    true
  rescue => e
    ::DeveloperMenu.log_error("Patch Singleton No Battle #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
    false
  end

  def all_module_owners_with_method(method_name)
    owners = []
    # ObjectSpace + full method-table inspection stalls the render thread on
    # Ruby 1.8.1 (Pokemon Uranium). Legacy Essentials exposes the battle entry
    # points through Object/Kernel and the explicit classes patched below, so
    # the global discovery pass is unnecessary there.
    if defined?(RUBY_VERSION) && RUBY_VERSION.to_s.index("1.8") == 0
      return owners
    end
    ObjectSpace.each_object(Module) do |owner|
      next unless owner
      next if owner == ::DeveloperMenu
      next unless ::DeveloperMenu.module_has_method?(owner, method_name)
      owners << owner
    end
    owners.uniq
  rescue => e
    ::DeveloperMenu.log_error("All Module Owners With Method #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
    []
  end

  def all_named_modules_matching(*patterns)
    owners = []
    ObjectSpace.each_object(Module) do |owner|
      name = begin
        owner.name.to_s
      rescue
        ""
      end
      next if name.empty?
      next unless patterns.any? { |pattern| name =~ pattern }
      owners << owner
    end
    owners.uniq
  rescue => e
    ::DeveloperMenu.log_error("All Named Modules Matching", e) if ::DeveloperMenu.respond_to?(:log_error)
    []
  end

  def infinite_mega_active?
    !!inf_mega
  rescue
    false
  end

  def clamp_argument_error?(error)
    return false if error.nil?
    error.is_a?(ArgumentError) && error.message.to_s.downcase.include?("min argument must be smaller than max argument")
  rescue
    false
  end

  def apply_runtime_patches!(force = false)
    legacy_rgss1 = defined?(RUBY_VERSION) && RUBY_VERSION.to_s.index("1.8") == 0
    apply_patch_step!("Clamp Compatibility") { apply_clamp_compatibility_patch! }
    apply_patch_step!("Ability Override Persistence") { apply_ability_override_patches! }
    if legacy_rgss1
      # Replacing Uranium's old global battle entry points while scripts are
      # still loading terminates RGSS1 without raising a Ruby exception.
      apply_patch_step!("No Battles") { true }
    else
      apply_patch_step!("No Battles") { apply_no_battles_patches! }
    end
    apply_patch_step!("EV Gain") { apply_ev_gain_patches! }
    apply_patch_step!("Infinite Mega") { apply_infinite_mega_patches! }
    @runtime_patches_applied = true
    true
  rescue => e
    log_error("Apply Runtime Patches", e)
    false
  end

  def apply_patch_step!(label)
    return true if runtime_patch_step_applied?(label)
    result = yield
    return false if result == false
    register_runtime_patch_step(label)
    true
  rescue => e
    log_error("Apply Runtime Patch Step #{label}", e)
    false
  end

  def apply_clamp_compatibility_patch!
    return true if defined?($_gm_clamp_patch_applied) && $_gm_clamp_patch_applied
    own_methods = Comparable.instance_methods(false) rescue Comparable.instance_methods
    unless own_methods.map { |entry| entry.to_s }.include?("clamp")
      $_gm_clamp_patch_applied = true
      return true
    end
    begin
      Comparable.instance_method(:clamp)
    rescue
      $_gm_clamp_patch_applied = true
      return true
    end
    Comparable.module_eval do
      unless method_defined?(:_gm_orig_clamp_dev)
        alias_method :_gm_orig_clamp_dev, :clamp
      end

      def clamp(*args)
        _gm_orig_clamp_dev(*args)
      rescue ArgumentError => e
        if args.length == 2
          min_value = args[0]
          max_value = args[1]
          if !min_value.nil? && !max_value.nil? && min_value.respond_to?(:>) && min_value > max_value
            return _gm_orig_clamp_dev(max_value, min_value)
          end
        elsif args.length == 1 && args[0].is_a?(Range)
          range = args[0]
          min_value = range.begin
          max_value = range.end
          if !min_value.nil? && !max_value.nil? && min_value.respond_to?(:>) && min_value > max_value
            swapped = range.exclude_end? ? (max_value...min_value) : (max_value..min_value)
            return _gm_orig_clamp_dev(swapped)
          end
        end
        raise e
      end

      ruby2_keywords(:clamp) if respond_to?(:ruby2_keywords, true)
    end
    $_gm_clamp_patch_applied = true
    true
  rescue => e
    log_error("Apply Clamp Compatibility Patch", e)
    false
  end

  def apply_ability_override_patches!
    return true if defined?($_gm_ability_override_patch_applied) && $_gm_ability_override_patch_applied
    [safe_const_get(Object, :Pokemon), safe_const_get(Object, :PokeBattle_Pokemon)].compact.each do |klass|
      patch_pokemon_ability_override_class!(klass)
    end
    battle_module = safe_const_get(Object, :Battle)
    [
      safe_const_get(Object, :PokeBattle_Battler),
      safe_const_get(battle_module, :Battler)
    ].compact.each do |klass|
      patch_battler_ability_override_class!(klass)
    end
    $_gm_ability_override_patch_applied = true
    true
  rescue => e
    log_error("Apply Ability Override Patches", e)
    false
  end

  def patch_pokemon_ability_override_class!(klass)
    return false unless klass
    make_alias(:_gm_orig_ability_dev, :ability, klass)
    make_alias(:_gm_orig_ability_writer_dev, :ability=, klass)
    make_alias(:_gm_orig_setAbility_dev, :setAbility, klass)
    make_alias(:_gm_orig_calc_stats_dev, :calc_stats, klass)
    make_alias(:_gm_orig_calcStats_dev, :calcStats, klass)
    make_alias(:_gm_orig_setForm_dev, :setForm, klass)
    make_alias(:_gm_orig_form_writer_dev, :form=, klass)
    make_alias(:_gm_orig_species_writer_dev, :species=, klass)

    klass.class_eval do
      if ::DeveloperMenu.module_has_method?(self, :ability)
        def ability(*args)
          override = ::DeveloperMenu.pokemon_ability_override_symbol(self)
          if override && !::DeveloperMenu.applying_pokemon_ability_override?(self)
            ::DeveloperMenu.apply_pokemon_ability_override!(self)
            return override
          end
          return _gm_orig_ability_dev(*args) if defined?(_gm_orig_ability_dev)
          override
        rescue Exception => e
          ::DeveloperMenu.log_error("Ability Override Getter", e) if ::DeveloperMenu.respond_to?(:log_error)
          return _gm_orig_ability_dev(*args) if defined?(_gm_orig_ability_dev)
          nil
        end
      end

      if ::DeveloperMenu.module_has_method?(self, :ability=)
        define_method(:ability=) do |value|
          begin
            result = defined?(_gm_orig_ability_writer_dev) ? _gm_orig_ability_writer_dev(value) : value
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override ability=", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
      end

      if ::DeveloperMenu.module_has_method?(self, :setAbility)
        define_method(:setAbility) do |*args|
          begin
            result = defined?(_gm_orig_setAbility_dev) ? _gm_orig_setAbility_dev(*args) : nil
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override setAbility", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
        ruby2_keywords(:setAbility) if respond_to?(:ruby2_keywords, true)
      end

      if ::DeveloperMenu.module_has_method?(self, :calc_stats)
        define_method(:calc_stats) do |*args|
          begin
            result = defined?(_gm_orig_calc_stats_dev) ? _gm_orig_calc_stats_dev(*args) : nil
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override calc_stats", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
        ruby2_keywords(:calc_stats) if respond_to?(:ruby2_keywords, true)
      end

      if ::DeveloperMenu.module_has_method?(self, :calcStats)
        define_method(:calcStats) do |*args|
          begin
            result = defined?(_gm_orig_calcStats_dev) ? _gm_orig_calcStats_dev(*args) : nil
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override calcStats", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
        ruby2_keywords(:calcStats) if respond_to?(:ruby2_keywords, true)
      end

      if ::DeveloperMenu.module_has_method?(self, :setForm)
        define_method(:setForm) do |*args|
          begin
            result = defined?(_gm_orig_setForm_dev) ? _gm_orig_setForm_dev(*args) : nil
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override setForm", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
        ruby2_keywords(:setForm) if respond_to?(:ruby2_keywords, true)
      end

      if ::DeveloperMenu.module_has_method?(self, :form=)
        define_method(:form=) do |value|
          begin
            result = defined?(_gm_orig_form_writer_dev) ? _gm_orig_form_writer_dev(value) : value
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override form=", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
      end

      if ::DeveloperMenu.module_has_method?(self, :species=)
        define_method(:species=) do |value|
          begin
            result = defined?(_gm_orig_species_writer_dev) ? _gm_orig_species_writer_dev(value) : value
            if ::DeveloperMenu.pokemon_ability_override_active?(self) && !::DeveloperMenu.applying_pokemon_ability_override?(self)
              ::DeveloperMenu.apply_pokemon_ability_override!(self)
            end
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Ability Override species=", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
      end
    end
    true
  rescue => e
    log_error("Patch Ability Override Class #{klass}", e)
    false
  end

  def patch_battler_ability_override_class!(klass)
    return false unless klass
    {
      :pbMegaEvolve => :_gm_orig_battler_pbMegaEvolve_dev,
      :megaEvolve => :_gm_orig_battler_megaEvolve_dev,
      :mega_evolve => :_gm_orig_battler_mega_evolve_dev,
      :makeMega => :_gm_orig_battler_makeMega_dev,
      :make_mega => :_gm_orig_battler_make_mega_dev,
      :setForm => :_gm_orig_battler_setForm_dev,
      :form= => :_gm_orig_battler_form_writer_dev
    }.each do |method_name, alias_name|
      make_alias(alias_name, method_name, klass)
    end

    klass.class_eval do
      {
        :pbMegaEvolve => :_gm_orig_battler_pbMegaEvolve_dev,
        :megaEvolve => :_gm_orig_battler_megaEvolve_dev,
        :mega_evolve => :_gm_orig_battler_mega_evolve_dev,
        :makeMega => :_gm_orig_battler_makeMega_dev,
        :make_mega => :_gm_orig_battler_make_mega_dev,
        :setForm => :_gm_orig_battler_setForm_dev
      }.each do |method_name, alias_name|
        next unless ::DeveloperMenu.module_has_method?(self, method_name)
        define_method(method_name) do |*args|
          begin
            result = respond_to?(alias_name, true) ? send(alias_name, *args) : nil
            ::DeveloperMenu.reapply_runtime_ability_override!(self)
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Battler Ability Override #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords, true)
      end

      if ::DeveloperMenu.module_has_method?(self, :form=)
        define_method(:form=) do |value|
          begin
            result = defined?(_gm_orig_battler_form_writer_dev) ? _gm_orig_battler_form_writer_dev(value) : value
            ::DeveloperMenu.reapply_runtime_ability_override!(self)
            result
          rescue Exception => e
            ::DeveloperMenu.log_error("Battler Ability Override form=", e) if ::DeveloperMenu.respond_to?(:log_error)
            raise e
          end
        end
      end
    end
    true
  rescue => e
    log_error("Patch Battler Ability Override Class #{klass}", e)
    false
  end

  def apply_no_battles_patches!
    if defined?(BattleCreationHelperMethods)
      helper = BattleCreationHelperMethods
      patch_no_battle_singleton_method_dynamic!(helper, :skip_battle?, :wild) do
        original_method = "_gm_orig_skip_battle?_singleton_dev_#{helper.object_id}".to_sym
        ::DeveloperMenu.no_wild_battles_active? || ::DeveloperMenu.no_trainer_battles_active? || send(original_method)
      end
      patch_no_battle_singleton_method_dynamic!(helper, :skip_battle, :wild) do |*skip_args|
        outcome_variable = skip_args.length > 0 ? skip_args[0] : 1
        trainer_battle = skip_args.length > 1 ? skip_args[1] : false
        if trainer_battle
          if ::DeveloperMenu.no_trainer_battles_active?
            ::DeveloperMenu.no_battle_skip_messages!(true, true)
            ::DeveloperMenu.clear_battle_runtime_flags!
            outcome = ::DeveloperMenu.no_battle_result_value(true)
            begin
              pbSet(outcome_variable, outcome) if defined?(pbSet)
            rescue
            end
            outcome
          else
            send(:"_gm_orig_skip_battle_singleton_dev_#{helper.object_id}", outcome_variable, trainer_battle)
          end
        else
          if ::DeveloperMenu.no_wild_battles_active?
            ::DeveloperMenu.no_battle_skip_messages!(false, true)
            ::DeveloperMenu.clear_battle_runtime_flags!
            outcome = ::DeveloperMenu.no_battle_result_value(false)
            begin
              pbSet(outcome_variable, outcome) if defined?(pbSet)
            rescue
            end
            outcome
          else
            send(:"_gm_orig_skip_battle_singleton_dev_#{helper.object_id}", outcome_variable, trainer_battle)
          end
        end
      end
    end

    if defined?(pbWildBattle) && !defined?(_gm_orig_pbWildBattle_dev)
      Object.send(:alias_method, :_gm_orig_pbWildBattle_dev, :pbWildBattle)
      Object.send(:define_method, :pbWildBattle) do |*args|
        return ::DeveloperMenu.core_style_skip_battle!(false) if ::DeveloperMenu.no_wild_battles_active?
        _gm_orig_pbWildBattle_dev(*args)
      end
    end

    if defined?(pbTrainerBattle) && !defined?(_gm_orig_pbTrainerBattle_dev)
      Object.send(:alias_method, :_gm_orig_pbTrainerBattle_dev, :pbTrainerBattle)
      Object.send(:define_method, :pbTrainerBattle) do |*args|
        return ::DeveloperMenu.core_style_skip_battle!(true) if ::DeveloperMenu.no_trainer_battles_active?
        _gm_orig_pbTrainerBattle_dev(*args)
      end
    end

    {
      :pbSingleOrDoubleWildBattle => :_gm_orig_pbSingleOrDoubleWildBattle_dev,
      :pbDoubleWildBattle => :_gm_orig_pbDoubleWildBattle_dev,
      :pbTripleWildBattle => :_gm_orig_pbTripleWildBattle_dev,
      :pbDoubleTrainerBattle => :_gm_orig_pbDoubleTrainerBattle_dev,
      :pbTripleTrainerBattle => :_gm_orig_pbTripleTrainerBattle_dev
    }.each do |method_name, alias_name|
      next unless ::DeveloperMenu.module_has_method?(Object, method_name) || ::DeveloperMenu.module_has_method?(Kernel, method_name)
      next if ::DeveloperMenu.module_has_method?(Object, alias_name) || ::DeveloperMenu.module_has_method?(Kernel, alias_name)
      begin
        Object.send(:alias_method, alias_name, method_name)
        Object.send(:define_method, method_name) do |*args|
          trainer_method = [:pbDoubleTrainerBattle, :pbTripleTrainerBattle].include?(method_name)
          if trainer_method
            return ::DeveloperMenu.core_style_skip_battle!(true) if ::DeveloperMenu.no_trainer_battles_active?
          else
            return ::DeveloperMenu.core_style_skip_battle!(false) if ::DeveloperMenu.no_wild_battles_active?
          end
          send(alias_name, *args)
        end
      rescue Exception => e
        ::DeveloperMenu.log_error("Patch #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
      end
    end

    [
      :pbTrainerBattle,
      :pbDoubleTrainerBattle,
      :pbTripleTrainerBattle,
      :pbSingleTrainerBattle,
      :pbTrainerBattle100
    ].each do |method_name|
      all_module_owners_with_method(method_name).each do |owner|
        patch_no_battle_owner_method_dynamic!(owner, method_name, :trainer)
      end
    end

    [
      :pbWildBattle,
      :pbSingleOrDoubleWildBattle,
      :pbDoubleWildBattle,
      :pbTripleWildBattle
    ].each do |method_name|
      all_module_owners_with_method(method_name).each do |owner|
        patch_no_battle_owner_method_dynamic!(owner, method_name, :wild)
      end
    end

    patch_no_battle_global_method!(:pbBattleOnStepTaken, :_gm_orig_pbBattleOnStepTaken_dev, :wild) { false }
    patch_no_battle_global_method!(:pbEncounter, :_gm_orig_pbEncounter_dev, :wild) { false }
    patch_no_battle_global_method!(:pbEncounteredPokemon, :_gm_orig_pbEncounteredPokemon_dev, :wild) { nil }
    patch_no_battle_global_method!(:pbGenerateWildPokemon, :_gm_orig_pbGenerateWildPokemon_dev, :wild) { nil }
    patch_no_battle_global_method!(:pbRoamingEncounter, :_gm_orig_pbRoamingEncounter_dev, :wild) { false }

    [safe_const_get(Object, :PokemonEncounters), safe_const_get(Object, :EncounterModifier), safe_const_get(Object, :Game_Player)].compact.each do |owner|
      patch_no_battle_owner_method!(owner, :hasEncounter?, :_gm_orig_hasEncounter_dev, :wild) { false }
      patch_no_battle_owner_method!(owner, :has_encounter?, :_gm_orig_has_encounter_dev, :wild) { false }
      patch_no_battle_owner_method!(owner, :encounter_possible_here?, :_gm_orig_encounter_possible_here_dev, :wild) { false }
      patch_no_battle_owner_method!(owner, :encounter_triggered?, :_gm_orig_encounter_triggered_dev, :wild) { false }
      patch_no_battle_owner_method!(owner, :encounterTriggered?, :_gm_orig_encounterTriggered_dev, :wild) { false }
      patch_no_battle_owner_method!(owner, :generateEncounter, :_gm_orig_generateEncounter_dev, :wild) { nil }
      patch_no_battle_owner_method!(owner, :generate_encounter, :_gm_orig_generate_encounter_dev, :wild) { nil }
    end

    if defined?(WildBattle) && WildBattle.respond_to?(:start)
      if ::DeveloperMenu.make_singleton_alias(WildBattle, :_gm_orig_start_dev, :start)
        class << WildBattle
          def start(*args)
            return ::DeveloperMenu.core_style_skip_battle!(false) if ::DeveloperMenu.no_wild_battles_active?
            _gm_orig_start_dev(*args)
          end

          ruby2_keywords(:start) if respond_to?(:ruby2_keywords, true)
        end
      end
    end

    if defined?(WildBattle) && WildBattle.respond_to?(:start_core)
      if ::DeveloperMenu.make_singleton_alias(WildBattle, :_gm_orig_start_core_dev, :start_core)
        class << WildBattle
          def start_core(*args)
            return ::DeveloperMenu.core_style_skip_battle!(false) if ::DeveloperMenu.no_wild_battles_active?
            _gm_orig_start_core_dev(*args)
          end

          ruby2_keywords(:start_core) if respond_to?(:ruby2_keywords, true)
        end
      end
    end

    if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
      if ::DeveloperMenu.make_singleton_alias(TrainerBattle, :_gm_orig_start_dev, :start)
        class << TrainerBattle
          def start(*args)
            return ::DeveloperMenu.core_style_skip_battle!(true) if ::DeveloperMenu.no_trainer_battles_active?
            _gm_orig_start_dev(*args)
          end

          ruby2_keywords(:start) if respond_to?(:ruby2_keywords, true)
        end
      end
    end

    if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start_core)
      if ::DeveloperMenu.make_singleton_alias(TrainerBattle, :_gm_orig_start_core_dev, :start_core)
        class << TrainerBattle
          def start_core(*args)
            return ::DeveloperMenu.core_style_skip_battle!(true) if ::DeveloperMenu.no_trainer_battles_active?
            _gm_orig_start_core_dev(*args)
          end

          ruby2_keywords(:start_core) if respond_to?(:ruby2_keywords, true)
        end
      end
    end

    all_named_modules_matching(/TrainerBattle/i, /BattleCreationHelperMethods/i, /Overworld.*Battle/i).each do |owner|
      patch_no_battle_singleton_method_dynamic!(owner, :start, :trainer)
      patch_no_battle_owner_method_dynamic!(owner, :start, :trainer)
      patch_no_battle_owner_method_dynamic!(owner, :pbTrainerBattle, :trainer)
      patch_no_battle_owner_method_dynamic!(owner, :pbDoubleTrainerBattle, :trainer)
      patch_no_battle_owner_method_dynamic!(owner, :pbTripleTrainerBattle, :trainer)
    end

    true
  end

  def apply_ev_gain_patches!
    if defined?(Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainExp_dev, :pbGainExp, Battle)
      Battle.class_eval do
        def pbGainEVsOne(*args)
          if ::DeveloperMenu.overcap_stats_in_args?(*args)
            return nil
          end
          return _gm_orig_pbGainEVsOne_dev(*args) if defined?(_gm_orig_pbGainEVsOne_dev)
          nil
        rescue ArgumentError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          ::DeveloperMenu.log_error("Battle EV Gain Compatibility", e)
          nil
        rescue StandardError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          raise e
        end

        def pbGainExp(*args)
          return _gm_orig_pbGainExp_dev(*args) if defined?(_gm_orig_pbGainExp_dev)
          nil
        rescue ArgumentError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          ::DeveloperMenu.log_error("Battle Exp Gain Compatibility", e)
          nil
        rescue StandardError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          raise e
        end

        ruby2_keywords(:pbGainEVsOne) if respond_to?(:ruby2_keywords, true)
        ruby2_keywords(:pbGainExp) if respond_to?(:ruby2_keywords, true)
      end
    end

    if defined?(PokeBattle_Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, PokeBattle_Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainExp_dev, :pbGainExp, PokeBattle_Battle)
      PokeBattle_Battle.class_eval do
        def pbGainEVsOne(*args)
          if ::DeveloperMenu.overcap_stats_in_args?(*args)
            return nil
          end
          return _gm_orig_pbGainEVsOne_dev(*args) if defined?(_gm_orig_pbGainEVsOne_dev)
          nil
        rescue ArgumentError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          ::DeveloperMenu.log_error("Legacy Battle EV Gain Compatibility", e)
          nil
        rescue StandardError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          raise e
        end

        def pbGainExp(*args)
          return _gm_orig_pbGainExp_dev(*args) if defined?(_gm_orig_pbGainExp_dev)
          nil
        rescue ArgumentError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          ::DeveloperMenu.log_error("Legacy Battle Exp Compatibility", e)
          nil
        rescue StandardError => e
          return nil if ::DeveloperMenu.clamp_argument_error?(e)
          raise e
        end
      end
    end
  end

  def apply_infinite_mega_patches!
    patch_infinite_mega_battle_class!(safe_const_get(Object, :PokeBattle_Battle), "Legacy")
    patch_infinite_mega_battle_class!(safe_const_get(Object, :Battle), "Modern")
    patch_infinite_mega_battler_class!(safe_const_get(Battle, :Battler), "Modern Battler") if defined?(Battle)
    patch_infinite_mega_pokemon_class!(safe_const_get(Object, :Pokemon), "Pokemon")
    patch_infinite_mega_pokemon_class!(safe_const_get(Object, :PokeBattle_Pokemon), "Legacy Pokemon")
    true
  rescue => e
    log_error("Apply Infinite Mega Patches", e)
    false
  end

  def force_infinite_mega_state!(battle, battler_index = nil)
    return false unless battle && battle.respond_to?(:megaEvolution)
    slots = battle.megaEvolution
    return false if slots.nil?
    changed = false
    if slots.is_a?(Array)
      slots.each_with_index do |side, side_index|
        next unless side.is_a?(Array)
        side.each_index do |i|
          next if !battler_index.nil? && battler_index != i && battler_index != [side_index, i]
          side[i] = -1
          changed = true
        end
      end
    elsif slots.is_a?(Hash)
      slots.keys.each do |key|
        slots[key] = -1
        changed = true
      end
    end
    changed
  rescue => e
    log_error("Force Infinite Mega State", e)
    false
  end

  def force_infinite_mega_on_pokemon!(pkmn)
    false
  rescue => e
    log_error("Force Infinite Mega On Pokemon", e)
    false
  end

  def patch_infinite_mega_battle_class!(klass, label)
    return false unless klass
    if make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, klass)
      klass.class_eval do
        def pbHasMegaRing?(*args)
          return true if ::DeveloperMenu.inf_mega
          return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
          false
        end
        ruby2_keywords(:pbHasMegaRing?) if respond_to?(:ruby2_keywords, true)
      end
    end

    if make_alias(:_gm_orig_pbCanMegaEvolve_dev, :pbCanMegaEvolve?, klass)
      klass.class_eval do
        def pbCanMegaEvolve?(*args)
          if ::DeveloperMenu.inf_mega
            begin
              battler_index = args.length > 1 ? args[1] : (args.length > 0 ? args[0] : nil)
              original_result = defined?(_gm_orig_pbCanMegaEvolve_dev) ? _gm_orig_pbCanMegaEvolve_dev(*args) : false
              return true if original_result
              ::DeveloperMenu.force_infinite_mega_state!(self, battler_index)
              return _gm_orig_pbCanMegaEvolve_dev(*args) if defined?(_gm_orig_pbCanMegaEvolve_dev)
            rescue Exception => e
              ::DeveloperMenu.log_error("Infinite Mega pbCanMegaEvolve?", e) if ::DeveloperMenu.respond_to?(:log_error)
            end
            return false
          end
          return _gm_orig_pbCanMegaEvolve_dev(*args) if defined?(_gm_orig_pbCanMegaEvolve_dev)
          false
        end
        ruby2_keywords(:pbCanMegaEvolve?) if respond_to?(:ruby2_keywords, true)
      end
    end

    if make_alias(:_gm_orig_pbRegisterMegaEvolution_dev, :pbRegisterMegaEvolution, klass)
      klass.class_eval do
        def pbRegisterMegaEvolution(*args)
          if ::DeveloperMenu.inf_mega
            begin
              battler_index = args.length > 1 ? args[1] : (args.length > 0 ? args[0] : nil)
              ::DeveloperMenu.force_infinite_mega_state!(self, battler_index)
            rescue Exception => e
              ::DeveloperMenu.log_error("Infinite Mega pbRegisterMegaEvolution", e) if ::DeveloperMenu.respond_to?(:log_error)
            end
          end
          return _gm_orig_pbRegisterMegaEvolution_dev(*args) if defined?(_gm_orig_pbRegisterMegaEvolution_dev)
          nil
        end
        ruby2_keywords(:pbRegisterMegaEvolution) if respond_to?(:ruby2_keywords, true)
      end
    end

    {
      :pbMegaEvolve => :_gm_orig_pbMegaEvolve_dev,
      :megaEvolve => :_gm_orig_megaEvolve_dev,
      :mega_evolve => :_gm_orig_mega_evolve_dev
    }.each do |method_name, alias_name|
      next unless make_alias(alias_name, method_name, klass)
      klass.class_eval do
        define_method(method_name) do |*args|
          if ::DeveloperMenu.inf_mega
            begin
              battler_index = args.length > 1 ? args[1] : (args.length > 0 ? args[0] : nil)
              ::DeveloperMenu.force_infinite_mega_state!(self, battler_index)
            rescue Exception => e
              ::DeveloperMenu.log_error("Infinite Mega #{method_name}", e) if ::DeveloperMenu.respond_to?(:log_error)
            end
          end
          send(alias_name, *args)
        end
        ruby2_keywords(method_name) if respond_to?(:ruby2_keywords, true)
      end
    end
    true
  rescue => e
    log_error("Patch Infinite Mega Battle #{label}", e)
    false
  end

  def patch_infinite_mega_battler_class!(klass, label)
    true
  rescue => e
    log_error("Patch Infinite Mega Battler #{label}", e)
    false
  end

  def patch_infinite_mega_pokemon_class!(klass, label)
    true
  rescue => e
    log_error("Patch Infinite Mega Pokemon #{label}", e)
    false
  end
end
::DeveloperMenu.apply_runtime_patches!

end

def pbPokeDebugMenu
  ::DeveloperMenu.open_menu_external
end

def pbPokeDebugMobileMenu
  ::DeveloperMenu.open_menu_external
end

def pbOpenPokeDebugMenu
  ::DeveloperMenu.open_menu_external
end

def pbDeveloperMenu
  ::DeveloperMenu.open_menu_external
end

def pbGodModeMenu
  ::DeveloperMenu.open_menu_external
end
