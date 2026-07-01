  class << self
    attr_accessor :walk_through_walls
    attr_accessor :no_battles
    attr_accessor :inf_mega

    def initialize_variables
      @walk_through_walls = false
      @no_battles = false
      @inf_mega = false
      @processing_hotkey = false
      @menu_open = false
      @mobile_combo_hold_frames = 0
      @quick_actions = [:heal_party, :engine_report, :native_debug, :none]
    end

    def t(hash_or_string, *args)
      language_key = LANG_KEYS[LANG] || LANG
      str = hash_or_string.is_a?(Hash) ? (hash_or_string[language_key] || hash_or_string.values.first || "") : hash_or_string.to_s
      args.each_with_index { |a, i| str = str.gsub("{#{i+1}}", a.to_s) }
      str
    end

    def log_error(context_name, error)
      File.open("developer_menu_errors.log", "a") do |f|
        f.puts("[#{Time.now}] Error in #{context_name}: #{error.message}")
        f.puts(error.backtrace.join("\n")) if error.backtrace
      end
    end

    def log_item_debug(message)
      nil
    rescue
    end

    def try_call(context_name = nil)
      yield
    rescue => e
      log_error(context_name || "Operation", e)
      nil
    end

    def try_variants(context_name, variants)
      last_error = nil
      variants.each do |variant|
        begin
          return variant.call
        rescue ArgumentError => e
          last_error = e
          next
        rescue => e
          last_error = e
          log_error(context_name, e)
          next
        end
      end
      log_error(context_name, last_error) if last_error
      nil
    rescue => e
      log_error(context_name, e)
      nil
    end

    def safe_execute(context_name = "System")
      yield
    rescue => e
      log_error(context_name, e)
      Kernel.pbMessage(_INTL("API Failure: {1} (Check log)", context_name))
    end

    def trigger_hotkey?(symbol_name, constant_name)
      return false unless defined?(Input)
      return true if Input.trigger?(symbol_name)
      return false unless Input.const_defined?(constant_name)
      Input.trigger?(Input.const_get(constant_name))
    rescue => e
      log_error("Hotkey #{constant_name}", e)
      false
    end

    def input_button_value(symbol_name, constant_name = nil)
      return nil unless defined?(Input)
      return symbol_name if symbol_name.is_a?(Integer)
      return Input.const_get(constant_name) if constant_name && Input.const_defined?(constant_name)
      upper_name = symbol_name.to_s.upcase
      return Input.const_get(upper_name) if Input.const_defined?(upper_name)
      symbol_name
    rescue
      nil
    end

    def input_pressing?(symbol_name, constant_name = nil)
      value = input_button_value(symbol_name, constant_name)
      return false if value.nil?
      Input.press?(value)
    rescue
      false
    end

    def all_input_pressing?(*buttons)
      return false if buttons.empty?
      buttons.all? { |button| input_pressing?(button, button.to_s.upcase) }
    end

    def joiplay_combo_triggered?
      return false unless defined?(Input)

      # Extra overlay/gamepad buttons if the player mapped them in JoiPlay.
      return true if all_input_pressing?(:L, :R)
      return true if all_input_pressing?(:AUX1, :AUX2)
      return true if all_input_pressing?(:CTRL, :SHIFT)

      # Emergency mobile fallback: hold the 3 default RMXP buttons together.
      if all_input_pressing?(:A, :B, :C)
        @mobile_combo_hold_frames ||= 0
        @mobile_combo_hold_frames += 1
        return true if @mobile_combo_hold_frames >= 24
      else
        @mobile_combo_hold_frames = 0
      end
      false
    rescue => e
      log_error("JoiPlay Combo Trigger", e)
      false
    end

    def menu_triggered?
      trigger_hotkey?(MENU_HOTKEY.to_sym, MENU_HOTKEY) || joiplay_combo_triggered?
    end

    def plugin_message_window_busy?
      return false unless defined?($game_temp) && $game_temp
      return true if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
      return true if $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
      false
    rescue => e
      log_error("Plugin Message Busy", e)
      false
    end

    def player_party
      p = get_player
      return [] unless p && p.respond_to?(:party) && p.party
      p.party
    end

    def remove_party_member(pkmn)
      party = player_party
      return false if party.empty?
      if party.respond_to?(:index)
        idx = party.index(pkmn)
        return !!party.delete_at(idx) unless idx.nil?
      end
      return !!party.delete(pkmn) if party.respond_to?(:delete)
      return !!party.Delete(pkmn) if party.respond_to?(:Delete)
      false
    end

    def get_repel_steps
      return $PokemonGlobal.repel if $PokemonGlobal && $PokemonGlobal.respond_to?(:repel)
      return $PokemonGlobal.repelSteps if $PokemonGlobal && $PokemonGlobal.respond_to?(:repelSteps)
      return $PokemonGlobal.repea if $PokemonGlobal && $PokemonGlobal.respond_to?(:repea)
      0
    end

    def set_repel_steps(value)
      if $PokemonGlobal.respond_to?(:repel=)
        $PokemonGlobal.repel = value
      elsif $PokemonGlobal.respond_to?(:repelSteps=)
        $PokemonGlobal.repelSteps = value
      else
        $PokemonGlobal.repea = value if $PokemonGlobal.respond_to?(:repea=)
      end
    end

    def get_map_toggle(*names)
      names.each do |name|
        return $PokemonMap.send(name) if $PokemonMap && $PokemonMap.respond_to?(name)
      end
      nil
    end

    def set_map_toggle(value, *names)
      names.each do |name|
        writer = "#{name}="
        if $PokemonMap && $PokemonMap.respond_to?(writer)
          $PokemonMap.send(writer, value)
          return true
        end
      end
      false
    end

    def safe_const_get(owner, name)
      return nil unless owner && owner.respond_to?(:const_defined?) && owner.const_defined?(name)
      owner.const_get(name)
    rescue
      nil
    end

    def safe_respond_to?(object, method_name)
      object && object.respond_to?(method_name)
    rescue
      false
    end

    def set_global_toggle(value, *names)
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      names.each do |name|
        writer = "#{name}="
        next unless $PokemonGlobal.respond_to?(writer)
        $PokemonGlobal.send(writer, value)
        return true
      end
      false
    rescue => e
      log_error("Set Global Toggle", e)
      false
    end

    def get_global_value(*names)
      return nil unless defined?($PokemonGlobal) && $PokemonGlobal
      names.each do |name|
        return $PokemonGlobal.send(name) if $PokemonGlobal.respond_to?(name)
      end
      nil
    rescue => e
      log_error("Get Global Value", e)
      nil
    end

    def set_global_value(value, *names)
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      names.each do |name|
        writer = "#{name}="
        next unless $PokemonGlobal.respond_to?(writer)
        $PokemonGlobal.send(writer, value)
        return true
      end
      false
    rescue => e
      log_error("Set Global Value", e)
      false
    end

    def module_has_method?(owner, method_name)
      return false unless owner
      method_text = method_name.to_s
      [owner.instance_methods, owner.private_instance_methods, owner.protected_instance_methods].each do |list|
        next unless list
        list.each do |entry|
          return true if entry.to_s == method_text
        end
      end
      false
    rescue
      false
    end

    def safe_singleton_class(object)
      class << object
        self
      end
    rescue
      nil
    end

    def recalc_pokemon_stats(pkmn)
      pkmn.calc_stats if safe_respond_to?(pkmn, :calc_stats)
      pkmn.calcStats if safe_respond_to?(pkmn, :calcStats)
    rescue => e
      log_error("Recalculate Pokemon Stats", e)
    end

    def make_alias(alias_name, target_name, owner)
      return false unless owner
      return false unless module_has_method?(owner, target_name)
      return false if module_has_method?(owner, alias_name)
      owner.send(:alias_method, alias_name, target_name)
      true
    rescue => e
      log_error("Alias #{target_name}", e)
      false
    end

    def make_singleton_alias(object, alias_name, target_name)
      return false unless object
      eigenclass = safe_singleton_class(object)
      return false unless eigenclass
      return false unless module_has_method?(eigenclass, target_name)
      return false if module_has_method?(eigenclass, alias_name)
      eigenclass.send(:alias_method, alias_name, target_name)
      true
    rescue => e
      log_error("Singleton Alias #{target_name}", e)
      false
    end

    def cached_engine_profile
      @engine_profile = nil if !defined?(@engine_profile)
      @engine_profile ||= detect_engine_profile
    end

    def reset_engine_profile!
      @engine_profile = nil
    end

    def modern_engine?
      cached_engine_profile[:modern_engine]
    end

    def detect_engine_profile
      profile = {}
      profile[:has_game_data] = defined?(GameData) ? true : false
      profile[:has_modern_player] = defined?($Player) ? true : false
      profile[:has_legacy_player] = defined?($Trainer) ? true : false
      profile[:has_modern_battle_api] = defined?(WildBattle) && WildBattle.respond_to?(:start)
      profile[:has_legacy_battle_api] = defined?(pbWildBattle) ? true : false
      profile[:has_modern_storage] = defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:boxes)
      profile[:has_modern_debug_menu] = defined?(DebugMenu) ? true : false
      profile[:has_legacy_debug_menu] = defined?(pbDebugMenu) ? true : false
      profile[:has_cache] = defined?($cache) && $cache ? true : false
      profile[:modern_engine] = profile[:has_game_data] || profile[:has_modern_battle_api] || profile[:has_modern_player]
      profile[:player_api] = profile[:has_modern_player] ? "$Player" : (profile[:has_legacy_player] ? "$Trainer" : "Unknown")
      profile[:battle_api] = profile[:has_modern_battle_api] ? "WildBattle.start" : (profile[:has_legacy_battle_api] ? "pbWildBattle" : "Unknown")
      profile[:debug_api] = profile[:has_legacy_debug_menu] ? "pbDebugMenu" : (profile[:has_modern_debug_menu] ? "DebugMenu" : "Unavailable")
      profile[:data_api] = profile[:has_game_data] ? "GameData" : (profile[:has_cache] ? "$cache" : "Legacy PB*")
      profile
    rescue => e
      log_error("Detect Engine Profile", e)
      {
        :has_game_data => false,
        :has_modern_player => false,
        :has_legacy_player => false,
        :has_modern_battle_api => false,
        :has_legacy_battle_api => false,
        :has_modern_storage => false,
        :has_modern_debug_menu => false,
        :has_legacy_debug_menu => false,
        :has_cache => false,
        :modern_engine => false,
        :player_api => "Unknown",
        :battle_api => "Unknown",
        :debug_api => "Unavailable",
        :data_api => "Unknown"
      }
    end

    def engine_profile_lines
      profile = cached_engine_profile
      lines = [
        "Engine family: #{profile[:modern_engine] ? 'Modern/Hybrid' : 'Legacy'}",
        "Player API: #{profile[:player_api]}",
        "Battle API: #{profile[:battle_api]}",
        "Debug API: #{profile[:debug_api]}",
        "Data API: #{profile[:data_api]}",
        "Storage boxes API: #{profile[:has_modern_storage] ? 'Modern' : 'Legacy/Unknown'}"
      ]
      caps = engine_capabilities.select { |_k, v| v }.keys.map { |k| k.to_s }
      lines << "Capabilities: #{caps.empty? ? 'None detected' : caps.join(', ')}"
      lines
    end

    def show_engine_report
      reset_engine_profile!
      lines = engine_profile_lines
      File.open("PokeDebug_Engine_Report.txt", "w") { |f| f.puts(lines.join("\n")) }
      Kernel.pbMessage(_INTL("{1}", lines.join("\n")))
    rescue => e
      log_error("Engine Report", e)
      Kernel.pbMessage(_INTL("Could not build engine report."))
    end

    def on_off_text(value)
      value ? "ON" : "OFF"
    end

    def player_name_value
      p = get_player
      return p.name if p && p.respond_to?(:name) && p.name
      "Unknown"
    rescue
      "Unknown"
    end

    def player_money_value
      p = get_player
      return p.money if p && p.respond_to?(:money)
      0
    rescue
      0
    end

    def player_coin_value
      p = get_player
      return p.coins if p && p.respond_to?(:coins)
      return p.coin if p && p.respond_to?(:coin)
      0
    rescue
      0
    end

    def player_battle_points_value
      p = get_player
      return p.battle_points if p && p.respond_to?(:battle_points)
      return p.battlePoints if p && p.respond_to?(:battlePoints)
      return p.bp if p && p.respond_to?(:bp)
      0
    rescue
      0
    end

    def player_trainer_id_value
      p = get_player
      return p.id if p && p.respond_to?(:id)
      return p.trainerID if p && p.respond_to?(:trainerID)
      return p.publicID if p && p.respond_to?(:publicID)
      0
    rescue
      0
    end

    def set_player_money!(value)
      p = get_player
      return false unless p
      new_value = [value.to_i, 0].max
      if p.respond_to?(:money=)
        p.money = new_value
        return p.money.to_i == new_value if p.respond_to?(:money)
        return true
      end
      false
    rescue => e
      log_error("Set Player Money", e)
      false
    end

    def set_player_coins!(value)
      p = get_player
      return false unless p
      new_value = [value.to_i, 0].max
      if p.respond_to?(:coins=)
        p.coins = new_value
        return p.coins.to_i == new_value if p.respond_to?(:coins)
        return true
      end
      if p.respond_to?(:coin=)
        p.coin = new_value
        return p.coin.to_i == new_value if p.respond_to?(:coin)
        return true
      end
      false
    rescue => e
      log_error("Set Player Coins", e)
      false
    end

    def set_player_battle_points!(value)
      p = get_player
      return false unless p
      new_value = [value.to_i, 0].max
      if p.respond_to?(:battle_points=)
        p.battle_points = new_value
        return p.battle_points.to_i == new_value if p.respond_to?(:battle_points)
        return true
      end
      if p.respond_to?(:battlePoints=)
        p.battlePoints = new_value
        return p.battlePoints.to_i == new_value if p.respond_to?(:battlePoints)
        return true
      end
      if p.respond_to?(:bp=)
        p.bp = new_value
        return p.bp.to_i == new_value if p.respond_to?(:bp)
        return true
      end
      false
    rescue => e
      log_error("Set Player Battle Points", e)
      false
    end

    def set_player_name!(name)
      p = get_player
      return false unless p
      final_name = name.to_s.strip
      return false if final_name == ""
      if p.respond_to?(:name=)
        p.name = final_name
        return p.name.to_s == final_name if p.respond_to?(:name)
        return true
      end
      false
    rescue => e
      log_error("Set Player Name", e)
      false
    end

    def set_player_trainer_id!(value)
      p = get_player
      return false unless p
      new_value = [value.to_i, 0].max
      if p.respond_to?(:id=)
        p.id = new_value
        return p.id.to_i == new_value if p.respond_to?(:id)
        return true
      end
      if p.respond_to?(:trainerID=)
        p.trainerID = new_value
        return p.trainerID.to_i == new_value if p.respond_to?(:trainerID)
        return true
      end
      false
    rescue => e
      log_error("Set Player Trainer ID", e)
      false
    end

    def player_badge_count
      p = get_player
      return 0 unless p && p.respond_to?(:badges) && p.badges
      p.badges.count { |badge| badge }
    rescue
      0
    end

    def player_pokedex_owned_count
      p = get_player
      if p && p.respond_to?(:pokedex) && p.pokedex
        return p.pokedex.owned_count if p.pokedex.respond_to?(:owned_count)
        return p.pokedex.caught_count if p.pokedex.respond_to?(:caught_count)
      end
      return $Trainer.owned.count { |owned| owned } if defined?($Trainer) && $Trainer.respond_to?(:owned) && $Trainer.owned
      0
    rescue
      0
    end

    def player_summary_lines
      p = get_player
      lines = []
      lines << _INTL("Name: {1}", player_name_value)
      lines << _INTL("Money: {1}", player_money_value)
      lines << _INTL("Badges: {1}", player_badge_count)
      lines << _INTL("Pokedex owned: {1}", player_pokedex_owned_count)
      if p && p.respond_to?(:gender)
        gender_text = case p.gender
        when 0 then "Male"
        when 1 then "Female"
        else p.gender.to_s
        end
        lines << _INTL("Gender: {1}", gender_text)
      end
      lines << _INTL("Running Shoes: {1}", on_off_text($PokemonGlobal.runningShoes)) if $PokemonGlobal && $PokemonGlobal.respond_to?(:runningShoes)
      lines << _INTL("Pokedex Flag: {1}", on_off_text(!!($PokemonGlobal && $PokemonGlobal.respond_to?(:pokedexUnlocked) && $PokemonGlobal.pokedexUnlocked)))
      lines
    rescue => e
      log_error("Player Summary Lines", e)
      [_INTL("Could not build player summary.")]
    end

    def show_player_summary
      Kernel.pbMessage(_INTL("{1}", player_summary_lines.join("\n")))
    rescue => e
      log_error("Show Player Summary", e)
      false
    end

    def engine_status_lines
      profile = cached_engine_profile
      lines = []
      lines << _INTL("Engine family: {1}", profile[:modern_engine] ? "Modern/Hybrid" : "Legacy")
      lines << _INTL("Debug menu: {1}", on_off_text(debug_menu_available?))
      lines << _INTL("Storage: {1}", on_off_text(storage_available?))
      lines << _INTL("Day care: {1}", on_off_text(!get_day_care_data.nil?))
      lines << _INTL("Walk Through Walls: {1}", on_off_text(@walk_through_walls))
      lines << _INTL("No Battles: {1}", on_off_text(@no_battles))
      lines << _INTL("Infinite Mega: {1}", on_off_text(@inf_mega))
      lines
    rescue => e
      log_error("Engine Status Lines", e)
      [_INTL("Could not build engine status.")]
    end

    def show_engine_status
      Kernel.pbMessage(_INTL("{1}", engine_status_lines.join("\n")))
    rescue => e
      log_error("Show Engine Status", e)
      false
    end

    def pokemon_menu_status_lines
      party = player_party
      eggs = party.count { |pkmn| pokemon_egg_state(pkmn) }
      lines = []
      lines << _INTL("Party size: {1}/6", party.length)
      lines << _INTL("Eggs in party: {1}", eggs)
      lines << _INTL("PC storage: {1}", storage_available? ? "AVAILABLE" : "UNAVAILABLE")
      lines << _INTL("Native editor: {1}", native_pokemon_editor_available? ? "AVAILABLE" : "UNAVAILABLE")
      lines
    rescue => e
      log_error("Pokemon Menu Status", e)
      [_INTL("Could not build Pokemon status.")]
    end

    def show_pokemon_menu_status
      Kernel.pbMessage(_INTL("{1}", pokemon_menu_status_lines.join("\n")))
    rescue => e
      log_error("Show Pokemon Menu Status", e)
      false
    end

    def current_map_summary_lines
      lines = []
      if defined?($game_map) && $game_map
        lines << _INTL("Map ID: {1}", $game_map.map_id) if $game_map.respond_to?(:map_id)
        lines << _INTL("Events on map: {1}", current_map_events.length)
      else
        lines << _INTL("Map not available.")
      end
      if defined?($game_player) && $game_player
        x = $game_player.respond_to?(:x) ? $game_player.x : "?"
        y = $game_player.respond_to?(:y) ? $game_player.y : "?"
        lines << _INTL("Player position: ({1}, {2})", x, y)
      end
      lines
    rescue => e
      log_error("Current Map Summary", e)
      [_INTL("Could not build map summary.")]
    end

    def show_current_map_summary
      Kernel.pbMessage(_INTL("{1}", current_map_summary_lines.join("\n")))
    rescue => e
      log_error("Show Current Map Summary", e)
      false
    end

    def quick_actions
      @quick_actions ||= [:heal_party, :engine_report, :native_debug, :none]
    end

    def quick_action_definitions
      [
        { :id => :none, :label => "Empty Slot", :action => proc { } },
        { :id => :heal_party, :label => "Heal Party", :action => proc { heal_party } },
        { :id => :toggle_no_battles, :label => "Toggle No Battles", :action => proc {
          @no_battles = !@no_battles
          Kernel.pbMessage(_INTL("No Battles: {1}", @no_battles ? "ON" : "OFF"))
        }},
        { :id => :toggle_wtw, :label => "Toggle Walk Through Walls", :action => proc { toggle_wtw } },
        { :id => :engine_report, :label => "Engine Compatibility Report", :action => proc { show_engine_report } },
        { :id => :native_debug, :label => "Open Native Debug Menu", :action => proc { open_native_debug_menu } },
        { :id => :native_pokemon_editor, :label => "Open Native Pokemon Editor", :action => proc { open_native_pokemon_editor_for_party } },
        { :id => :open_pc, :label => "Open PC", :action => proc { open_pc_menu } },
        { :id => :refresh_map, :label => "Refresh Map", :action => proc { engine_refresh_map if respond_to?(:engine_refresh_map) } }
      ]
    end

    def find_quick_action(action_id)
      quick_action_definitions.find { |entry| entry[:id] == action_id }
    end

    def configure_quick_actions
      loop do
        cmds = quick_actions.each_with_index.map do |action_id, idx|
          action = find_quick_action(action_id)
          "Slot #{idx + 1}: #{action ? action[:label] : 'Unknown'}"
        end
        cmds.push("Back")
        slot = Kernel.pbMessage(_INTL("Configure Quick Actions:"), cmds, -1)
        break if slot < 0 || slot >= quick_actions.length

        action_cmds = quick_action_definitions.map { |entry| entry[:label] }
        choice = Kernel.pbMessage(_INTL("Choose action for slot {1}:", slot + 1), action_cmds, -1)
        next if choice < 0
        quick_actions[slot] = quick_action_definitions[choice][:id]
      end
    end

    def run_quick_actions_menu
      menu = quick_actions.map do |action_id|
        action = find_quick_action(action_id)
        next nil if !action || action[:id] == :none
        { :label => action[:label], :action => action[:action] }
      end.compact
      if menu.empty?
        Kernel.pbMessage(_INTL("No quick actions configured."))
        return
      end
      render_dynamic_menu("Quick Actions", menu)
    end

    def debug_menu_available?
      cached_engine_profile[:has_legacy_debug_menu] || cached_engine_profile[:has_modern_debug_menu]
    end

    def native_pokemon_editor_available?
      return true if defined?(pbPokemonDebug)
      return true if defined?(pbDebugPokemon)
      return true if defined?(PokemonDebug_Scene)
      return true if defined?(PokemonDebugScene)
      false
    end

    def engine_capabilities
      save_layout = detect_save_layout
      {
        :debug_menu => debug_menu_available?,
        :day_care => !get_day_care_data.nil?,
        :storage => storage_available?,
        :map_factory => defined?($MapFactory) && !$MapFactory.nil?,
        :game_data => cached_engine_profile[:has_game_data],
        :cache_data => cached_engine_profile[:has_cache],
        :battle_modern => cached_engine_profile[:has_modern_battle_api],
        :battle_legacy => cached_engine_profile[:has_legacy_battle_api],
        :player_name_ui => defined?(pbEnterPlayerName) ? true : false,
        :pokemon_name_ui => defined?(pbEnterPokemonName) ? true : false,
        :presets => true,
        :save_appdata => save_layout[:appdata_available],
        :save_candidates => save_layout[:save_dir_candidates]
      }
    rescue => e
      log_error("Engine Capabilities", e)
      {}
    end

    def preset_file_path
      "PokeDebug_Pokemon_Preset.dat"
    end

    def data_record(type, id)
      klass = game_data_class(type)
      return nil unless klass && klass.respond_to?(:get)
      klass.get(id)
    rescue => e
      log_error("Data Record #{type}", e)
      nil
    end

    def species_forms(species_id)
      forms = [0]
      sp_data = data_record(:Species, species_id)
      if sp_data
        if sp_data.respond_to?(:forms)
          sp_data.forms.each { |f| forms.push(f) unless forms.include?(f) }
        elsif sp_data.respond_to?(:form)
          forms.push(sp_data.form) unless forms.include?(sp_data.form)
        end
      end
      forms
    rescue => e
      log_error("Species Forms", e)
      [0]
    end

    def storage_max_boxes
      return 0 unless storage_available?
      try_call("Storage Max Boxes") { $PokemonStorage.maxBoxes } || 0
    end

    def storage_max_pokemon(box)
      return 0 unless storage_available?
      try_call("Storage Max Pokemon #{box}") { $PokemonStorage.maxPokemon(box) } || 0
    end

    def storage_store_caught(pkmn)
      return false unless storage_available?
      return $PokemonStorage.pbStoreCaught(pkmn) if $PokemonStorage.respond_to?(:pbStoreCaught)

      each_storage_index do |box, slot|
        current_box = try_call("Storage Slot Auto-Store") { $PokemonStorage[box] }
        next unless current_box
        next if current_box[slot]
        current_box[slot] = pkmn
        return true
      end
      false
    rescue => e
      log_error("Storage Store Caught", e)
      false
    end

    def storage_add_box(name)
      return false unless storage_available?
      box_size = storage_max_pokemon(0)
      return false unless defined?(PokemonBox) && box_size > 0
      return false unless $PokemonStorage.respond_to?(:boxes) && $PokemonStorage.boxes.respond_to?(:push)
      $PokemonStorage.boxes.push(PokemonBox.new(name, box_size))
      true
    rescue => e
      log_error("Storage Add Box", e)
      false
    end

    def get_day_care_data
      return nil unless defined?($PokemonGlobal) && $PokemonGlobal
      dc = try_call("Day Care Legacy") { $PokemonGlobal.day_care }
      dc = $PokemonGlobal.daycare if dc.nil? && $PokemonGlobal.respond_to?(:daycare)
      dc
    end

    def day_care_first_slot(dc = nil)
      dc ||= get_day_care_data
      return nil unless dc
      return dc[0] if dc.respond_to?(:[])
      nil
    rescue => e
      log_error("Day Care First Slot", e)
      nil
    end

    def day_care_first_pokemon(dc = nil)
      slot = day_care_first_slot(dc)
      return nil unless slot
      return slot.pokemon if slot.respond_to?(:pokemon)
      nil
    rescue => e
      log_error("Day Care First Pokemon", e)
      nil
    end

    def day_care_deposit_first(pkmn, dc = nil)
      slot = day_care_first_slot(dc)
      return false unless slot
      current = day_care_first_pokemon(dc)
      return false if current
      slot.pokemon = pkmn if slot.respond_to?(:pokemon=)
      slot.level = pkmn.level if slot.respond_to?(:level=) && pkmn.respond_to?(:level)
      day_care_first_pokemon(dc) == pkmn || !day_care_first_pokemon(dc).nil?
    rescue => e
      log_error("Day Care Deposit", e)
      false
    end

    def day_care_withdraw_first(dc = nil)
      slot = day_care_first_slot(dc)
      return nil unless slot
      pkmn = day_care_first_pokemon(dc)
      slot.pokemon = nil if slot.respond_to?(:pokemon=)
      pkmn
    rescue => e
      log_error("Day Care Withdraw", e)
      nil
    end

    def day_care_force_egg(dc = nil)
      dc ||= get_day_care_data
      return false unless dc
      dc.step_count = 255 if dc.respond_to?(:step_count=)
      dc.egg_generated = true if dc.respond_to?(:egg_generated=)
      return !!dc.egg_generated if dc.respond_to?(:egg_generated)
      true
    rescue => e
      log_error("Day Care Force Egg", e)
      false
    end

    def set_running_shoes_enabled!(value)
      set_global_toggle(!!value, :runningShoes, :running_shoes)
    end

    def running_shoes_enabled?
      current = get_global_value(:runningShoes, :running_shoes)
      !!current
    end

    def set_pokedex_enabled!(value)
      enabled = !!value
      changed = false
      p = get_player
      if p && p.respond_to?(:pokedex=)
        p.pokedex = enabled
        changed = true
      end
      changed = true if set_global_toggle(enabled, :pokedexUnlocked, :pokedex_unlocked)
      return enabled if changed
      false
    rescue => e
      log_error("Set Pokedex Enabled", e)
      false
    end

    def pokedex_enabled?
      p = get_player
      return !!p.pokedex if p && p.respond_to?(:pokedex)
      current = get_global_value(:pokedexUnlocked, :pokedex_unlocked)
      !!current
    rescue => e
      log_error("Pokedex Enabled", e)
      false
    end

    def set_pokegear_enabled!(value)
      p = get_player
      return false unless p
      enabled = !!value
      if p.respond_to?(:pokegear=)
        p.pokegear = enabled
        return !!p.pokegear == enabled if p.respond_to?(:pokegear)
        return true
      end
      false
    rescue => e
      log_error("Set Pokegear Enabled", e)
      false
    end

    def pokegear_enabled?
      p = get_player
      return !!p.pokegear if p && p.respond_to?(:pokegear)
      false
    rescue => e
      log_error("Pokegear Enabled", e)
      false
    end

    def set_play_time_hours!(hours)
      return false unless defined?(Graphics) && Graphics.respond_to?(:frame_count=)
      total_hours = [hours.to_i, 0].max
      Graphics.frame_count = total_hours * 60 * 60 * frame_rate_value
      true
    rescue => e
      log_error("Set Play Time", e)
      false
    end

    def set_region_value!(value)
      set_global_value(value.to_i, :region)
    end

    def clear_partner_data!
      return false unless defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:partner)
      return :empty if $PokemonGlobal.partner.nil?
      $PokemonGlobal.partner = nil if $PokemonGlobal.respond_to?(:partner=)
      $PokemonGlobal.partner.nil?
    rescue => e
      log_error("Clear Partner", e)
      false
    end

    def game_data_class(type)
      return nil unless cached_engine_profile[:has_game_data]
      safe_const_get(GameData, type)
    end

    def legacy_pb_module(type)
      names = ["PB#{type}", "PB#{type}s"]
      names << "PB#{type.to_s[0...-1]}ies" if type.to_s.end_with?("y")
      case type
      when :TrainerType
        names.concat(["PBTrainers", "PBTrainerTypes"])
      when :Ability
        names.concat(["PBAbilities"])
      when :Ribbon
        names.concat(["PBRibbons"])
      when :Nature
        names.concat(["PBNatures"])
      when :Status
        names.concat(["PBStatuses"])
      end
      names.each do |const_name|
        mod = safe_const_get(Object, const_name.to_sym)
        return mod if mod
      end
      nil
    end

    def cache_collection(type)
      return nil unless cached_engine_profile[:has_cache]
      mapping = {
        :Species => [:pkmn, :pokemon, :species],
        :Item => [:items, :item, :itemData],
        :Move => [:moves, :move, :moveData],
        :Nature => [:natures, :nature],
        :Type => [:types, :type],
        :Ability => [:abilities, :ability],
        :Ribbon => [:ribbons, :ribbon],
        :TrainerType => [:trainertypes, :trainer_types, :trainers, :trainerTypes],
        :Status => [:statuses, :status]
      }
      names = mapping[type] || []
      names.each do |name|
        return $cache.send(name) if $cache.respond_to?(name)
      end
      nil
    rescue => e
      log_error("Cache Collection #{type}", e)
      nil
    end

    def legacy_constant_display_name(type, const_name, value)
      return PBSpecies.getName(value) if type == :Species && defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      return PBAbilities.getName(value) if type == :Ability && defined?(PBAbilities) && PBAbilities.respond_to?(:getName)
      return PBItems.getName(value) if type == :Item && defined?(PBItems) && PBItems.respond_to?(:getName)
      return PBMoves.getName(value) if type == :Move && defined?(PBMoves) && PBMoves.respond_to?(:getName)
      return PBNatures.getName(value) if type == :Nature && defined?(PBNatures) && PBNatures.respond_to?(:getName)
      return PBTypes.getName(value) if type == :Type && defined?(PBTypes) && PBTypes.respond_to?(:getName)
      return PBTrainers.getName(value) if type == :TrainerType && defined?(PBTrainers) && PBTrainers.respond_to?(:getName)
      const_name.to_s.capitalize
    rescue => e
      log_error("Legacy Display Name #{type}", e)
      const_name.to_s.capitalize
    end

    def safe_display_name(record, fallback)
      return fallback.to_s.capitalize unless record
      return record.name if record.respond_to?(:name) && record.name
      fallback.to_s.capitalize
    rescue
      fallback.to_s.capitalize
    end

    def safe_load_data(path)
      load_data(path)
    rescue => e
      log_error("Load Data #{path}", e)
      nil
    end

    def frame_rate_value
      return Graphics.frame_rate if defined?(Graphics) && Graphics.respond_to?(:frame_rate)
      40
    rescue
      40
    end

    def choose_pokemon_with_callback(&block)
      return false unless defined?(pbChoosePokemon)
      attempts = [
        proc { pbChoosePokemon(1, 2, block) },
        proc { pbChoosePokemon(1, 2, &block) },
        proc { pbChoosePokemon(1, &block) },
        proc { pbChoosePokemon(&block) },
        proc { pbChoosePokemon(1, 2) },
        proc { pbChoosePokemon(1) },
        proc { pbChoosePokemon() }
      ]
      attempts.each do |attempt|
        begin
          result = attempt.call
          if block && !result.nil?
            if result.is_a?(Integer) && result >= 0
              party = player_party
              chosen = party[result]
              block.call(chosen) if chosen
            elsif pokemon_like_object?(result)
              block.call(result)
            end
          end
          return true
        rescue ArgumentError
          next
        end
      end
      false
    rescue => e
      log_error("Choose Pokemon", e)
      false
    end

    def mark_map_for_refresh!
      changed = false
      if defined?($game_map) && $game_map
        if $game_map.respond_to?(:need_refresh=)
          $game_map.need_refresh = true
          changed = true
        elsif $game_map.respond_to?(:refresh)
          $game_map.refresh
          changed = true
        end
      end
      if defined?($MapFactory) && $MapFactory && defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
        changed = true if safe_set_map_changed($game_map.map_id)
      end
      changed
    rescue => e
      log_error("Mark Map For Refresh", e)
      false
    end

    def set_game_switch!(id, value)
      return false unless defined?($game_switches) && $game_switches && id.to_i >= 0
      $game_switches[id] = !!value
      mark_map_for_refresh!
      return !!$game_switches[id] == !!value
    rescue => e
      log_error("Set Game Switch", e)
      false
    end

    def set_game_variable!(id, value)
      return false unless defined?($game_variables) && $game_variables && id.to_i >= 0
      $game_variables[id] = value
      mark_map_for_refresh!
      return $game_variables[id] == value
    rescue => e
      log_error("Set Game Variable", e)
      false
    end

    def set_safari_value!(writer_name, reader_name, value)
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      writer = "#{writer_name}="
      return false unless $PokemonGlobal.respond_to?(writer)
      $PokemonGlobal.send(writer, value)
      return $PokemonGlobal.send(reader_name) == value if $PokemonGlobal.respond_to?(reader_name)
      true
    rescue => e
      log_error("Set Safari Value", e)
      false
    end

    def set_flash_enabled!(value)
      set_global_toggle(!!value, :flashUsed, :flash_used)
    end

    def flash_enabled?
      !!get_global_value(:flashUsed, :flash_used)
    end

    def set_strength_enabled!(value)
      set_map_toggle(!!value, :strengthUsed, :strength_used)
    end

    def strength_enabled?
      !!get_map_toggle(:strengthUsed, :strength_used)
    end

    def warp_player_to_map!(map_id, x, y, direction = 2)
      return false unless defined?($game_temp) && $game_temp
      if $game_temp.respond_to?(:player_new_map_id=)
        $game_temp.player_new_map_id = map_id
        $game_temp.player_new_x = x if $game_temp.respond_to?(:player_new_x=)
        $game_temp.player_new_y = y if $game_temp.respond_to?(:player_new_y=)
        $game_temp.player_new_direction = direction if $game_temp.respond_to?(:player_new_direction=)
        if defined?($scene) && $scene && $scene.respond_to?(:transfer_player)
          $scene.transfer_player
          return true
        end
      end
      if defined?($game_player) && $game_player
        $game_player.moveto(x, y) if $game_player.respond_to?(:moveto)
        $game_player.center(x, y) if $game_player.respond_to?(:center)
        return true
      end
      false
    rescue => e
      log_error("Warp Player", e)
      false
    end

    def open_native_debug_menu
      result = try_variants("Native Debug Menu", [
        (proc { pbDebugMenu; true if defined?(pbDebugMenu) }),
        (proc { pbDebugMenuCommands; true if defined?(pbDebugMenuCommands) }),
        (proc { DebugMenu.new.pbStartScreen; true if defined?(DebugMenu) && DebugMenu.respond_to?(:new) }),
        (proc { DebugMenu.pbStartScreen; true if defined?(DebugMenu) && DebugMenu.respond_to?(:pbStartScreen) }),
        (proc {
          if defined?(PokemonDebugMenu_Scene) && defined?(PokemonDebugMenuScreen)
            scene = PokemonDebugMenu_Scene.new
            PokemonDebugMenuScreen.new(scene).pbStartScreen
            true
          end
        }),
        (proc {
          if defined?(PokemonDebugMenuScene) && defined?(PokemonDebugMenuScreen)
            scene = PokemonDebugMenuScene.new
            PokemonDebugMenuScreen.new(scene).pbStartScreen
            true
          end
        })
      ])
      !!result
    rescue => e
      log_error("Native Debug Menu", e)
      false
    end

    def open_native_pokemon_editor(pkmn = nil)
      result = try_variants("Native Pokemon Editor", [
        (proc { pbPokemonDebug(pkmn); true if defined?(pbPokemonDebug) }),
        (proc { pbPokemonDebug(pkmn, nil); true if defined?(pbPokemonDebug) }),
        (proc { pbPokemonDebug; true if defined?(pbPokemonDebug) }),
        (proc { pbDebugPokemon(pkmn); true if defined?(pbDebugPokemon) }),
        (proc { pbDebugPokemon(pkmn, nil); true if defined?(pbDebugPokemon) }),
        (proc { pbDebugPokemon; true if defined?(pbDebugPokemon) }),
        (proc { pbEditPokemon(pkmn); true if defined?(pbEditPokemon) }),
        (proc { pbEditPokemon(pkmn, nil); true if defined?(pbEditPokemon) }),
        (proc { pbEditPokemon; true if defined?(pbEditPokemon) }),
        (proc { pbPokemonEditor(pkmn); true if defined?(pbPokemonEditor) }),
        (proc { pbPokemonEditor(pkmn, nil); true if defined?(pbPokemonEditor) }),
        (proc { pbPokemonEditor; true if defined?(pbPokemonEditor) }),
        (proc {
          if defined?(PokemonDebug_Scene) && defined?(PokemonDebugScreen)
            scene = PokemonDebug_Scene.new
            begin
              PokemonDebugScreen.new(scene, pkmn).pbStartScreen
            rescue ArgumentError
              PokemonDebugScreen.new(scene).pbStartScreen
            end
            true
          end
        }),
        (proc {
          if defined?(PokemonDebugScene) && defined?(PokemonDebugScreen)
            scene = PokemonDebugScene.new
            begin
              PokemonDebugScreen.new(scene, pkmn).pbStartScreen
            rescue ArgumentError
              PokemonDebugScreen.new(scene).pbStartScreen
            end
            true
          end
        })
      ])
      !!result
    rescue => e
      log_error("Native Pokemon Editor", e)
      false
    end

    def open_native_pokemon_editor_for_party
      chosen = nil
      if choose_pokemon_with_callback { |pkmn| chosen = pkmn }
        if chosen
          return true if open_native_pokemon_editor(chosen)
        end
      else
        chosen = player_party.first
        return true if chosen && open_native_pokemon_editor(chosen)
      end
      Kernel.pbMessage(_INTL("Native Pokemon editor not available on this version."))
      false
    rescue => e
      log_error("Open Native Pokemon Editor For Party", e)
      false
    end

    def open_pc_menu
      result = try_variants("Open PC", [
        (proc { pbPokeCenterPC; true if defined?(pbPokeCenterPC) }),
        (proc { pbPC; true if defined?(pbPC) }),
        (proc { pbTrainerPC; true if defined?(pbTrainerPC) }),
        (proc { PokemonPCList.start; true if defined?(PokemonPCList) && PokemonPCList.respond_to?(:start) }),
        (proc {
          if defined?(PokemonPCList) && PokemonPCList.respond_to?(:new)
            list = PokemonPCList.new
            if list.respond_to?(:start)
              list.start
              true
            elsif list.respond_to?(:pbStartScreen)
              list.pbStartScreen
              true
            end
          end
        })
      ])
      return true if result
      Kernel.pbMessage(_INTL("PC not supported on this version."))
      false
    rescue => e
      log_error("Open PC", e)
      Kernel.pbMessage(_INTL("PC could not be opened on this version."))
      false
    end

    def cancel_vehicles_if_possible
      pbCancelVehicles if defined?(pbCancelVehicles)
    rescue => e
      log_error("Cancel Vehicles", e)
    end

    def safe_map_factory_map(map_id)
      return nil unless defined?($MapFactory) && $MapFactory
      $MapFactory.getMap(map_id)
    rescue => e
      log_error("Map Factory #{map_id}", e)
      nil
    end

    def safe_set_map_changed(map_id)
      return false unless defined?($MapFactory) && $MapFactory.respond_to?(:setMapChanged)
      $MapFactory.setMapChanged(map_id)
      true
    rescue => e
      log_error("Set Map Changed", e)
      false
    end

    def set_name_via_ui(default_name = "")
      return nil unless defined?(pbEnterPlayerName)
      try_variants("Enter Player Name", [
        proc { pbEnterPlayerName("Your Name?", 0, 12, default_name) },
        proc { pbEnterPlayerName("Your Name?", 0, 12) },
        proc { pbEnterPlayerName("Your Name?", default_name) },
        proc { pbEnterPlayerName(default_name) },
        proc { pbEnterPlayerName() }
      ])
    rescue => e
      log_error("Enter Player Name", e)
      nil
    end

    def set_pokemon_name_via_ui(pkmn)
      return nil unless defined?(pbEnterPokemonName)
      try_variants("Enter Pokemon Name", [
        proc { pbEnterPokemonName("Nickname?", 0, 12, "", pkmn) },
        proc { pbEnterPokemonName("Nickname?", 0, 12, pkmn) },
        proc { pbEnterPokemonName("Nickname?", pkmn) },
        proc { pbEnterPokemonName(pkmn) },
        proc { pbEnterPokemonName() }
      ])
    rescue => e
      log_error("Enter Pokemon Name", e)
      nil
    end

    def set_owner_name_via_ui(owner_name)
      return nil unless defined?(pbEnterPlayerName)
      try_variants("Enter OT Name", [
        proc { pbEnterPlayerName("OT Name?", 0, 12, owner_name) },
        proc { pbEnterPlayerName("OT Name?", 0, 12) },
        proc { pbEnterPlayerName("OT Name?", owner_name) },
        proc { pbEnterPlayerName(owner_name) },
        proc { pbEnterPlayerName() }
      ])
    rescue => e
      log_error("Enter OT Name", e)
      nil
    end

    def pokemon_legal_abilities(pkmn)
      return [] unless pkmn && pkmn.respond_to?(:getAbilityList)
      abils = try_call("Pokemon Ability List") { pkmn.getAbilityList }
      return [] unless abils.is_a?(Array)
      abils
    end

    def set_pokemon_legal_ability!(pkmn, choice_index = nil)
      abils = pokemon_legal_abilities(pkmn)
      return false if abils.empty?
      if choice_index.nil?
        cmds = abils.map { |a| a[0].to_s }
        choice_index = Kernel.pbMessage(_INTL("Choose ability:"), cmds, -1)
      end
      return false if choice_index.nil? || choice_index < 0 || choice_index >= abils.length
      ability_symbol = abils[choice_index][0]
      ability_index = abils[choice_index][1]
      set_pokemon_ability!(pkmn, ability_symbol, ability_index)
    rescue => e
      log_error("Set Legal Ability", e)
      false
    end

    def matched_ability_index_for(pkmn, ability_symbol)
      return nil unless pkmn && ability_symbol
      pokemon_legal_abilities(pkmn).each do |entry|
        next unless entry.is_a?(Array) && entry.length >= 2
        return entry[1] if entry[0] == ability_symbol
        return entry[1] if entry[0].to_s == ability_symbol.to_s
      end
      nil
    rescue => e
      log_error("Match Ability Index", e)
      nil
    end

    def set_pokemon_hidden_ability_flags!(pkmn, slot_index)
      return false unless pkmn
      hidden = (slot_index.to_i == 2)
      changed = false
      [:"hidden_ability=", :"hasHiddenAbility=", :"isHiddenAbility="].each do |writer|
        next unless pkmn.respond_to?(writer)
        pkmn.send(writer, hidden)
        changed = true
      end
      [:@hiddenAbility, :@hidden_ability, :@hasHiddenAbility, :@isHiddenAbility].each do |ivar|
        next unless pkmn.instance_variable_defined?(ivar) || hidden
        pkmn.instance_variable_set(ivar, hidden)
        changed = true
      end
      changed
    rescue => e
      log_error("Set Hidden Ability Flags", e)
      false
    end

    def set_pokemon_internal_ability_fields!(pkmn, ability_symbol)
      return false unless pkmn && ability_symbol
      changed = false
      [:@ability, :@ability_id, :@abilityID, :@forcedAbility, :@forced_ability].each do |ivar|
        next unless pkmn.instance_variable_defined?(ivar) || ivar == :@ability
        pkmn.instance_variable_set(ivar, ability_symbol)
        changed = true
      end
      changed
    rescue => e
      log_error("Set Internal Ability Fields", e)
      false
    end

    def set_pokemon_ability!(pkmn, ability_symbol, force_index = nil)
      return false unless pkmn
      matched_index = matched_ability_index_for(pkmn, ability_symbol)
      target_index = force_index.nil? ? matched_index : force_index
      pkmn.ability = ability_symbol if pkmn.respond_to?(:ability=)
      pkmn.setAbility(ability_symbol) if pkmn.respond_to?(:setAbility)
      if !target_index.nil? && pkmn.respond_to?(:ability_index=)
        pkmn.ability_index = target_index
      end
      set_pokemon_hidden_ability_flags!(pkmn, target_index) unless target_index.nil?
      set_pokemon_internal_ability_fields!(pkmn, ability_symbol)
      return pkmn.ability.to_s == ability_symbol.to_s if pkmn.respond_to?(:ability) && ability_symbol
      true
    rescue => e
      log_error("Set Ability", e)
      false
    end

    def reset_pokemon_ability!(pkmn)
      return false unless pkmn
      pkmn.ability_index = nil if pkmn.respond_to?(:ability_index=)
      pkmn.ability = nil if pkmn.respond_to?(:ability=)
      set_pokemon_hidden_ability_flags!(pkmn, 0)
      [:@ability, :@ability_id, :@abilityID, :@forcedAbility, :@forced_ability].each do |ivar|
        pkmn.instance_variable_set(ivar, nil) if pkmn.instance_variable_defined?(ivar)
      end
      true
    rescue => e
      log_error("Reset Ability", e)
      false
    end

    def set_pokemon_nature!(pkmn, nature_symbol)
      return false unless pkmn
      pkmn.nature = nature_symbol if pkmn.respond_to?(:nature=)
      pkmn.setNature(nature_symbol) if pkmn.respond_to?(:setNature)
      return pkmn.nature.to_s == nature_symbol.to_s if pkmn.respond_to?(:nature)
      true
    rescue => e
      log_error("Set Nature", e)
      false
    end

    def set_pokemon_item!(pkmn, item_symbol)
      return false unless pkmn
      pkmn.item = item_symbol if pkmn.respond_to?(:item=)
      pkmn.setItem(item_symbol) if pkmn.respond_to?(:setItem)
      try_call("Held Item Extra Sync") { pbHeldItem(pkmn, item_symbol) } if item_symbol && defined?(pbHeldItem)
      return pkmn.item == item_symbol if pkmn.respond_to?(:item)
      true
    rescue => e
      log_error("Set Held Item", e)
      false
    end

    def remove_pokemon_item!(pkmn)
      set_pokemon_item!(pkmn, nil)
    end

    def set_pokemon_nickname!(pkmn, nickname)
      return false unless pkmn
      return false if nickname.nil? || nickname == ""
      pkmn.name = nickname if pkmn.respond_to?(:name=)
      return pkmn.name.to_s == nickname.to_s if pkmn.respond_to?(:name)
      true
    rescue => e
      log_error("Set Nickname", e)
      false
    end

    def rename_pokemon_via_ui!(pkmn)
      return false unless pkmn
      nickname = set_pokemon_name_via_ui(pkmn)
      return false if nickname.nil? || nickname == ""
      set_pokemon_nickname!(pkmn, nickname)
    end

    def set_pokemon_ot_name!(pkmn, owner_name)
      return false unless pkmn
      return false if owner_name.nil? || owner_name == ""
      if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name=)
        pkmn.owner.name = owner_name
        return pkmn.owner.name.to_s == owner_name.to_s if pkmn.owner.respond_to?(:name)
        return true
      end
      pkmn.ot = owner_name if pkmn.respond_to?(:ot=)
      return pkmn.ot.to_s == owner_name.to_s if pkmn.respond_to?(:ot)
      return true if pkmn.respond_to?(:ot=)
      false
    rescue => e
      log_error("Set OT Name", e)
      false
    end

    def rename_pokemon_ot_via_ui!(pkmn)
      return false unless pkmn
      current_name = ""
      current_name = pkmn.owner.name if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name)
      current_name = pkmn.ot if current_name == "" && pkmn.respond_to?(:ot)
      new_name = set_owner_name_via_ui(current_name)
      return false if new_name.nil? || new_name == ""
      set_pokemon_ot_name!(pkmn, new_name)
    end

    def pokemon_ot_name(pkmn)
      return "" unless pkmn
      return pkmn.owner.name if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name)
      return pkmn.ot if pkmn.respond_to?(:ot)
      ""
    rescue => e
      log_error("Pokemon OT Name", e)
      ""
    end

    def pokemon_species_name(pkmn)
      return "Unknown" unless pkmn
      return pkmn.speciesName if pkmn.respond_to?(:speciesName) && pkmn.speciesName
      species_id = pkmn.species if pkmn.respond_to?(:species)
      record = data_record(:Species, species_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBSpecies.getName(species_id) if defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      species_id ? species_id.to_s : "Unknown"
    rescue => e
      log_error("Pokemon Species Name", e)
      "Unknown"
    end

    def pokemon_level_value(pkmn)
      return pkmn.level if pkmn && pkmn.respond_to?(:level)
      0
    rescue
      0
    end

    def pokemon_current_hp(pkmn)
      return pkmn.hp if pkmn && pkmn.respond_to?(:hp)
      nil
    rescue
      nil
    end

    def pokemon_total_hp_value(pkmn)
      return pkmn.totalhp if pkmn && pkmn.respond_to?(:totalhp)
      return pkmn.total_hp if pkmn && pkmn.respond_to?(:total_hp)
      return pkmn.hp if pkmn && pkmn.respond_to?(:hp)
      nil
    rescue
      nil
    end

    def pokemon_status_label(pkmn)
      return "OK" unless pkmn
      status = nil
      status = pkmn.status if pkmn.respond_to?(:status)
      return "OK" if status.nil? || status == false || status == 0 || status == :NONE
      status = status.id if status.respond_to?(:id)
      status.to_s.upcase
    rescue => e
      log_error("Pokemon Status Label", e)
      "OK"
    end

    def pokemon_item_name(pkmn)
      return "None" unless pkmn
      item = pkmn.item if pkmn.respond_to?(:item)
      return "None" if item.nil? || item == 0
      return item_display_name(item)
    rescue => e
      log_error("Pokemon Item Name", e)
      "None"
    end

    def item_display_name(item_id)
      return "None" if item_id.nil? || item_id == 0
      record = data_record(:Item, item_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBItems.getName(item_id) if defined?(PBItems) && PBItems.respond_to?(:getName)
      item_id.to_s
    rescue => e
      log_error("Item Display Name", e)
      "None"
    end

    def ability_display_name(ability_id)
      return "None" if ability_id.nil? || ability_id == 0
      record = data_record(:Ability, ability_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBAbilities.getName(ability_id) if defined?(PBAbilities) && PBAbilities.respond_to?(:getName)
      ability_id.to_s
    rescue => e
      log_error("Ability Display Name", e)
      "None"
    end

    def pokemon_shiny_state(pkmn)
      return false unless pkmn
      return pkmn.shiny? if pkmn.respond_to?(:shiny?)
      return pkmn.shiny if pkmn.respond_to?(:shiny)
      false
    rescue => e
      log_error("Pokemon Shiny State", e)
      false
    end

    def pokemon_egg_state(pkmn)
      return false unless pkmn
      return pkmn.egg? if pkmn.respond_to?(:egg?)
      return pkmn.isEgg? if pkmn.respond_to?(:isEgg?)
      false
    rescue => e
      log_error("Pokemon Egg State", e)
      false
    end

    def pokemon_form_value(pkmn)
      return pkmn.form if pkmn && pkmn.respond_to?(:form)
      0
    rescue
      0
    end

    def pokemon_party_label(pkmn)
      return "Unknown Pokemon" unless pkmn
      name = pkmn.respond_to?(:name) ? pkmn.name.to_s : pokemon_species_name(pkmn)
      level = pokemon_level_value(pkmn)
      hp = pokemon_current_hp(pkmn)
      total_hp = pokemon_total_hp_value(pkmn)
      status = pokemon_status_label(pkmn)
      shiny_tag = pokemon_shiny_state(pkmn) ? " *Shiny*" : ""
      egg_tag = pokemon_egg_state(pkmn) ? " [Egg]" : ""
      hp_text = hp.nil? || total_hp.nil? ? "" : " HP #{hp}/#{total_hp}"
      "#{name} (Lv.#{level})#{egg_tag}#{shiny_tag}#{hp_text} #{status}"
    rescue => e
      log_error("Pokemon Party Label", e)
      "Unknown Pokemon"
    end

    def pokemon_summary_lines(pkmn)
      return [_INTL("Pokemon not available.")] unless pkmn
      lines = []
      lines << _INTL("Name: {1}", pkmn.respond_to?(:name) ? pkmn.name : pokemon_species_name(pkmn))
      lines << _INTL("Species: {1}", pokemon_species_name(pkmn))
      lines << _INTL("Level: {1}", pokemon_level_value(pkmn))
      hp = pokemon_current_hp(pkmn)
      total_hp = pokemon_total_hp_value(pkmn)
      lines << _INTL("HP: {1}/{2}", hp, total_hp) if !hp.nil? && !total_hp.nil?
      lines << _INTL("Status: {1}", pokemon_status_label(pkmn))
      lines << _INTL("Item: {1}", pokemon_item_name(pkmn))
      lines << _INTL("OT: {1}", pokemon_ot_name(pkmn))
      lines << _INTL("Nature: {1}", pkmn.nature) if pkmn.respond_to?(:nature) && pkmn.nature
      lines << _INTL("Form: {1}", pokemon_form_value(pkmn)) if pokemon_form_value(pkmn).to_i > 0
      lines << _INTL("Shiny: {1}", pokemon_shiny_state(pkmn) ? "YES" : "NO")
      lines << _INTL("Egg: {1}", pokemon_egg_state(pkmn) ? "YES" : "NO")
      lines
    rescue => e
      log_error("Pokemon Summary Lines", e)
      [_INTL("Could not build summary.")]
    end

    def pokemon_move_lines(pkmn)
      lines = []
      each_move_slot(pkmn) do |move, index|
        next unless move
        move_name = move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))
        pp = move.respond_to?(:pp) ? move.pp : "?"
        total_pp = move.respond_to?(:total_pp) ? move.total_pp : (move.respond_to?(:totalPP) ? move.totalPP : "?")
        lines << _INTL("{1}. {2} ({3}/{4} PP)", index + 1, move_name, pp, total_pp)
      end
      lines = [_INTL("No moves learned.")] if lines.empty?
      lines
    rescue => e
      log_error("Pokemon Move Lines", e)
      [_INTL("Could not read moveset.")]
    end

    def show_pokemon_summary(pkmn)
      Kernel.pbMessage(_INTL("{1}", pokemon_summary_lines(pkmn).join("\n")))
    rescue => e
      log_error("Show Pokemon Summary", e)
      false
    end

    def show_pokemon_moveset(pkmn)
      Kernel.pbMessage(_INTL("{1}", pokemon_move_lines(pkmn).join("\n")))
    rescue => e
      log_error("Show Pokemon Moveset", e)
      false
    end

    def genderless_pokemon?(pkmn)
      return true if pkmn.respond_to?(:gender_ratio) && pkmn.gender_ratio == :Genderless
      false
    rescue => e
      log_error("Genderless Check", e)
      false
    end

    def set_pokemon_gender!(pkmn, target)
      return false unless pkmn
      case target
      when :male
        pkmn.makeMale if pkmn.respond_to?(:makeMale)
        pkmn.gender = 0 if pkmn.respond_to?(:gender=)
      when :female
        pkmn.makeFemale if pkmn.respond_to?(:makeFemale)
        pkmn.gender = 1 if pkmn.respond_to?(:gender=)
      when :genderless
        pkmn.makeGenderless if pkmn.respond_to?(:makeGenderless)
        pkmn.gender = 2 if pkmn.respond_to?(:gender=)
      else
        return false
      end
      true
    rescue => e
      log_error("Set Gender", e)
      false
    end

    def prompt_pokemon_gender!(pkmn)
      return false if genderless_pokemon?(pkmn)
      ch = Kernel.pbMessage(_INTL("Set Gender?"), ["Male", "Female", "Cancel"], -1)
      return false if ch < 0 || ch == 2
      set_pokemon_gender!(pkmn, ch == 0 ? :male : :female)
    end

    def set_pokemon_status!(pkmn, status_symbol, sleep_turns = 3)
      return false unless pkmn
      return false unless pkmn.respond_to?(:status=)
      pkmn.status = status_symbol
      if status_symbol == :SLEEP && pkmn.respond_to?(:statusCount=)
        pkmn.statusCount = sleep_turns
      end
      true
    rescue => e
      log_error("Set Status", e)
      false
    end

    def clear_pokemon_status!(pkmn)
      return false unless pkmn
      if pkmn.respond_to?(:status=)
        pkmn.status = nil
      elsif pkmn.respond_to?(:status)
        pkmn.status = 0 rescue nil
      end
      pkmn.statusCount = 0 if pkmn.respond_to?(:statusCount=)
      true
    rescue => e
      log_error("Clear Status", e)
      false
    end

    def set_pokemon_shiny!(pkmn, shiny = true)
      return false unless pkmn
      if shiny
        pkmn.shiny = true if pkmn.respond_to?(:shiny=)
        pkmn.makeShiny if pkmn.respond_to?(:makeShiny)
      else
        pkmn.shiny = false if pkmn.respond_to?(:shiny=)
      end
      return pokemon_shiny_state(pkmn) == !!shiny
    rescue => e
      log_error("Set Shiny", e)
      false
    end

    def set_pokemon_species!(pkmn, species_symbol)
      return false unless pkmn
      pkmn.species = species_symbol if pkmn.respond_to?(:species=)
      pkmn.setSpecies(species_symbol) if pkmn.respond_to?(:setSpecies)
      recalc_pokemon_stats(pkmn)
      return pkmn.species == species_symbol if pkmn.respond_to?(:species)
      true
    rescue => e
      log_error("Set Species", e)
      false
    end

    def set_pokemon_form!(pkmn, form)
      return false unless pkmn
      pkmn.form = form if pkmn.respond_to?(:form=)
      pkmn.setForm(form) if pkmn.respond_to?(:setForm)
      recalc_pokemon_stats(pkmn)
      return pkmn.form.to_i == form.to_i if pkmn.respond_to?(:form)
      true
    rescue => e
      log_error("Set Form", e)
      false
    end

    def clear_pokemon_form_override!(pkmn)
      return false unless pkmn
      pkmn.forced_form = nil if pkmn.respond_to?(:forced_form=)
      pkmn.form_simple = nil if pkmn.respond_to?(:form_simple=)
      true
    rescue => e
      log_error("Clear Form Override", e)
      false
    end

    def set_pokemon_ball!(pkmn, item_id)
      return false unless pkmn
      set_ball_data!(pkmn, item_id)
      return pkmn.poke_ball == get_symbol(:Item, item_id) if pkmn.respond_to?(:poke_ball) && item_id
      return pkmn.ballused.to_i == item_id.to_i if pkmn.respond_to?(:ballused) && item_id
      return pkmn.ball_used == get_symbol(:Item, item_id) if pkmn.respond_to?(:ball_used) && item_id
      true
    rescue => e
      log_error("Set Poke Ball", e)
      false
    end

    def add_pokemon_ribbon!(pkmn, ribbon_symbol)
      return false unless pkmn
      return false unless pkmn.respond_to?(:giveRibbon)
      pkmn.giveRibbon(ribbon_symbol)
      return pkmn.hasRibbon?(ribbon_symbol) if pkmn.respond_to?(:hasRibbon?)
      true
    rescue => e
      log_error("Add Ribbon", e)
      false
    end

    def clear_pokemon_ribbons!(pkmn)
      return false unless pkmn
      pkmn.clearAllRibbons if pkmn.respond_to?(:clearAllRibbons)
      if pkmn.respond_to?(:ribbons) && pkmn.ribbons.respond_to?(:Clear)
        pkmn.ribbons.Clear
      elsif pkmn.respond_to?(:ribbons) && pkmn.ribbons.respond_to?(:clear)
        pkmn.ribbons.clear
      end
      true
    rescue => e
      log_error("Clear Ribbons", e)
      false
    end

    def make_pokemon_egg!(pkmn)
      return false unless pkmn
      pkmn.name = "Egg" if pkmn.respond_to?(:name=)
      pkmn.egg_steps = 255 if pkmn.respond_to?(:egg_steps=)
      recalc_pokemon_stats(pkmn)
      return pokemon_egg_state(pkmn) if pkmn.respond_to?(:egg?) || pkmn.respond_to?(:isEgg?)
      return pkmn.egg_steps.to_i == 255 if pkmn.respond_to?(:egg_steps)
      true
    rescue => e
      log_error("Make Egg", e)
      false
    end

    def hatch_pokemon_egg!(pkmn)
      return false unless pkmn
      pkmn.name = pkmn.speciesName if pkmn.respond_to?(:name=) && pkmn.respond_to?(:speciesName)
      pkmn.egg_steps = 0 if pkmn.respond_to?(:egg_steps=)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Hatch Egg", e)
      false
    end

    def set_pokemon_hatch_steps!(pkmn, steps)
      return false unless pkmn
      return false unless pkmn.respond_to?(:egg_steps=)
      pkmn.egg_steps = steps
      true
    rescue => e
      log_error("Set Egg Steps", e)
      false
    end

    def heal_pokemon!(pkmn)
      return false unless pkmn
      healed = false
      if pkmn.respond_to?(:Heal)
        pkmn.Heal
        healed = true
      end
      if pkmn.respond_to?(:heal)
        pkmn.heal
        healed = true
      end
      max_hp = pokemon_total_hp_value(pkmn)
      if !max_hp.nil? && max_hp.to_i > 0 && pkmn.respond_to?(:hp=)
        pkmn.hp = max_hp.to_i
        healed = true
      end
      clear_pokemon_status!(pkmn)
      restore_pokemon_pp!(pkmn)
      recalc_pokemon_stats(pkmn)
      max_hp = pokemon_total_hp_value(pkmn)
      pkmn.hp = max_hp.to_i if !max_hp.nil? && max_hp.to_i > 0 && pkmn.respond_to?(:hp=)
      healed
    rescue => e
      log_error("Heal Pokemon", e)
      false
    end

    def set_pokemon_hp!(pkmn, value)
      return false unless pkmn && pkmn.respond_to?(:hp=)
      max_hp = nil
      max_hp = pkmn.totalhp if pkmn.respond_to?(:totalhp)
      max_hp = pkmn.total_hp if max_hp.nil? && pkmn.respond_to?(:total_hp)
      max_hp = pkmn.hp if max_hp.nil? && pkmn.respond_to?(:hp)
      min_value = 0
      final_value = value.to_i
      final_value = min_value if final_value < min_value
      final_value = [final_value, max_hp].min if max_hp && max_hp > 0
      pkmn.hp = final_value
      true
    rescue => e
      log_error("Set HP", e)
      false
    end

    def faint_pokemon!(pkmn)
      set_pokemon_hp!(pkmn, 0)
    end

    def set_pokemon_level!(pkmn, level)
      return false unless pkmn
      pkmn.level = level if pkmn.respond_to?(:level=)
      recalc_pokemon_stats(pkmn)
      if pkmn.respond_to?(:hp) && pkmn.respond_to?(:totalhp) && pkmn.hp > pkmn.totalhp
        pkmn.hp = pkmn.totalhp if pkmn.respond_to?(:hp=)
      end
      true
    rescue => e
      log_error("Set Level", e)
      false
    end

    def set_pokemon_exp!(pkmn, exp)
      return false unless pkmn
      pkmn.exp = exp if pkmn.respond_to?(:exp=)
      recalc_pokemon_stats(pkmn)
      if pkmn.respond_to?(:hp) && pkmn.respond_to?(:totalhp) && pkmn.hp > pkmn.totalhp
        pkmn.hp = pkmn.totalhp if pkmn.respond_to?(:hp=)
      end
      true
    rescue => e
      log_error("Set Experience", e)
      false
    end

    def set_pokemon_happiness!(pkmn, value)
      return false unless pkmn && pkmn.respond_to?(:happiness=)
      pkmn.happiness = value
      true
    rescue => e
      log_error("Set Happiness", e)
      false
    end

    def max_pokemon_ivs!(pkmn, value = 31)
      set_all_ivs!(pkmn, value)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Max IVs", e)
      false
    end

    def max_pokemon_evs!(pkmn, value = 252)
      set_all_evs!(pkmn, value)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Max EVs", e)
      false
    end

    def each_move_slot(pkmn)
      return enum_for(:each_move_slot, pkmn) unless block_given?
      return unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      pkmn.moves.each_with_index { |move, index| yield move, index }
    end

    def move_identifier(move)
      return nil unless move
      return move.id if move.respond_to?(:id)
      return move.move if move.respond_to?(:move)
      return move.id_number if move.respond_to?(:id_number)
      nil
    rescue => e
      log_error("Move Identifier", e)
      nil
    end

    def move_display_name(move_id)
      return "" if move_id.nil?
      record = data_record(:Move, move_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBMoves.getName(move_id) if defined?(PBMoves) && PBMoves.respond_to?(:getName)
      move_id.to_s
    rescue => e
      log_error("Move Display Name", e)
      move_id.to_s
    end

    def choose_move_replacement_index(pkmn, new_move_id)
      return nil unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      cmds = pkmn.moves.map do |move|
        current_name = move ? (move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))) : "---"
        _INTL("Replace {1}", current_name)
      end
      cmds.push(_INTL("Cancel"))
      choice = Kernel.pbMessage(_INTL("Choose a move to forget for {1}:", move_display_name(new_move_id)), cmds, -1)
      return nil if choice < 0 || choice >= pkmn.moves.length
      choice
    rescue => e
      log_error("Choose Move Replacement", e)
      nil
    end

    def move_already_known?(pkmn, move_id)
      return false unless pkmn && move_id
      each_move_slot(pkmn) do |move, _index|
        return true if move_identifier(move).to_s == move_id.to_s
      end
      false
    rescue => e
      log_error("Move Already Known", e)
      false
    end

    def try_native_learn_move(pkmn, move_id)
      attempts = []
      if defined?(pbLearnMove)
        attempts.concat([
          proc { pbLearnMove(pkmn, move_id) },
          proc { pbLearnMove(pkmn, move_id, true) },
          proc { pbLearnMove(pkmn, move_id, false) },
          proc { pbLearnMove(pkmn, move_id, true, false) },
          proc { pbLearnMove(pkmn, move_id, false, true) }
        ])
      end
      if pkmn
        attempts.concat([
          proc { pkmn.learn_move(move_id) if pkmn.respond_to?(:learn_move) },
          proc { pkmn.learnMove(move_id) if pkmn.respond_to?(:learnMove) },
          proc { pkmn.pbLearnMove(move_id) if pkmn.respond_to?(:pbLearnMove) }
        ])
      end
      attempts.each do |attempt|
        begin
          result = attempt.call
          return true unless result.nil? || result == false
        rescue ArgumentError
          next
        rescue => e
          log_error("Native Learn Move", e)
        end
      end
      false
    end

    def teach_move_with_prompt!(pkmn, move_id)
      return false unless pkmn && move_id
      return :already_known if move_already_known?(pkmn, move_id)
      move_count = (pkmn.respond_to?(:moves) && pkmn.moves) ? pkmn.moves.length : 0
      if move_count < 4
        return :assigned if assign_move!(pkmn, move_count, move_id) && move_already_known?(pkmn, move_id)
        return false
      end

      return :native if try_native_learn_move(pkmn, move_id) && move_already_known?(pkmn, move_id)

      replace_index = choose_move_replacement_index(pkmn, move_id)
      return false if replace_index.nil?
      return :replaced if assign_move!(pkmn, replace_index, move_id) && move_already_known?(pkmn, move_id)
      false
    rescue => e
      log_error("Teach Move With Prompt", e)
      false
    end

    def reset_pokemon_moves!(pkmn)
      return false unless pkmn
      if pkmn.respond_to?(:resetMoves)
        pkmn.resetMoves
      elsif pkmn.respond_to?(:reset_moves)
        pkmn.reset_moves
      elsif pkmn.respond_to?(:pbLearnMove) && pkmn.respond_to?(:species) && pkmn.respond_to?(:level)
        moved = false
        level_up_moves_for(pkmn).each do |entry|
          next unless entry[0].to_i <= pkmn.level.to_i
          moved ||= !!assign_next_free_move!(pkmn, entry[1])
        end
        return moved
      else
        return false
      end
      true
    rescue => e
      log_error("Reset Pokemon Moves", e)
      false
    end

    def record_pokemon_initial_moves!(pkmn)
      return false unless pkmn && pkmn.respond_to?(:moves)
      move_ids = pkmn.moves.compact.map { |move| move_identifier(move) }.compact
      return false if move_ids.empty?
      if pkmn.respond_to?(:first_moves=)
        pkmn.first_moves = move_ids
        return true
      end
      if pkmn.respond_to?(:initial_moves=)
        pkmn.initial_moves = move_ids
        return true
      end
      pkmn.instance_variable_set(:@first_moves, move_ids)
      true
    rescue => e
      log_error("Record Initial Moves", e)
      false
    end

    def restore_pokemon_pp!(pkmn)
      changed = false
      each_move_slot(pkmn) do |move, _index|
        next unless move
        total_pp = move.respond_to?(:total_pp) ? move.total_pp : (move.respond_to?(:totalPP) ? move.totalPP : nil)
        next if total_pp.nil?
        if move.respond_to?(:pp=)
          move.pp = total_pp
          changed = true
        end
      end
      changed
    rescue => e
      log_error("Restore Pokemon PP", e)
      false
    end

    def max_pokemon_ppups!(pkmn, value = 3)
      changed = false
      each_move_slot(pkmn) do |move, _index|
        next unless move
        if move.respond_to?(:ppup=)
          move.ppup = value
          changed = true
        elsif move.respond_to?(:ppup)
          move.ppup = value rescue nil
          changed = true
        end
      end
      restore_pokemon_pp!(pkmn) if changed
      changed
    rescue => e
      log_error("Max Pokemon PP Ups", e)
      false
    end

    def forget_move!(pkmn, move_index)
      return false unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      return false if move_index.nil? || move_index < 0 || move_index >= pkmn.moves.length
      if pkmn.moves.respond_to?(:delete_at)
        !!pkmn.moves.delete_at(move_index)
      else
        pkmn.moves[move_index] = nil
        true
      end
    rescue => e
      log_error("Forget Move", e)
      false
    end

    def assign_next_free_move!(pkmn, move_id)
      return false unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      free_index = pkmn.moves.index(nil)
      free_index = pkmn.moves.length if free_index.nil? && pkmn.moves.length < 4
      return false if free_index.nil?
      assign_move!(pkmn, free_index, move_id)
    rescue => e
      log_error("Assign Next Free Move", e)
      false
    end

    def level_up_moves_for(pkmn)
      return [] unless pkmn
      species = pkmn.respond_to?(:species) ? pkmn.species : nil
      record = data_record(:Species, species)
      return record.moves if record && record.respond_to?(:moves) && record.moves
      return pkmn.getMoveList if pkmn.respond_to?(:getMoveList)
      []
    rescue => e
      log_error("Level Up Moves", e)
      []
    end

    def stat_editor_definitions
      [
        { :index => 0, :label => "HP",      :aliases => [:HP, :hp, :HITPOINTS, :hitpoints],             :readers => [:totalhp, :total_hp] },
        { :index => 1, :label => "Attack",  :aliases => [:ATTACK, :ATK, :attack, :atk],                 :readers => [:attack, :atk] },
        { :index => 2, :label => "Defense", :aliases => [:DEFENSE, :DEF, :defense, :def],               :readers => [:defense, :def] },
        { :index => 3, :label => "Sp. Atk", :aliases => [:SPECIAL_ATTACK, :SPATK, :SPAT, :spatk, :spat], :readers => [:spatk, :spatk, :sp_atk, :special_attack] },
        { :index => 4, :label => "Sp. Def", :aliases => [:SPECIAL_DEFENSE, :SPDEF, :SPDEFENSE, :spdef], :readers => [:spdef, :sp_def, :special_defense] },
        { :index => 5, :label => "Speed",   :aliases => [:SPEED, :SPD, :speed, :spd],                   :readers => [:speed, :spd] }
      ]
    end

    def pokemon_live_stat_value(pkmn, stat_def)
      return nil unless pkmn && stat_def
      stat_def[:readers].each do |reader|
        return pkmn.send(reader) if pkmn.respond_to?(reader)
      end
      nil
    rescue => e
      log_error("Pokemon Live Stat #{stat_def[:label]}", e)
      nil
    end

    def stat_collection_value(pkmn, collection_name)
      return nil unless pkmn && pkmn.respond_to?(collection_name)
      pkmn.send(collection_name)
    rescue => e
      log_error("Stat Collection #{collection_name}", e)
      nil
    end

    def resolve_stat_key(collection, stat_def)
      return nil if collection.nil? || stat_def.nil?
      return stat_def[:index] if collection.is_a?(Array)
      if collection.is_a?(Hash)
        preferred = stat_def[:aliases]
        preferred.each { |key| return key if collection.key?(key) }
        preferred_strings = preferred.map { |key| key.to_s.downcase }
        collection.keys.each do |key|
          return key if preferred_strings.include?(key.to_s.downcase)
        end
        return collection.keys[stat_def[:index]] if collection.keys.length > stat_def[:index]
      end
      nil
    rescue => e
      log_error("Resolve Stat Key #{stat_def[:label]}", e)
      nil
    end

    def get_individual_stat_value(pkmn, collection_name, stat_def)
      collection = stat_collection_value(pkmn, collection_name)
      return nil if collection.nil?
      key = resolve_stat_key(collection, stat_def)
      return nil if key.nil?
      collection[key]
    rescue => e
      log_error("Get Individual Stat #{collection_name} #{stat_def[:label]}", e)
      nil
    end

    def ensure_stat_collection!(pkmn, collection_name)
      collection = stat_collection_value(pkmn, collection_name)
      return collection unless collection.nil?
      writer = "#{collection_name}="
      return nil unless pkmn && pkmn.respond_to?(writer)
      pkmn.send(writer, [0, 0, 0, 0, 0, 0])
      stat_collection_value(pkmn, collection_name)
    rescue => e
      log_error("Ensure Stat Collection #{collection_name}", e)
      nil
    end

    def set_individual_stat_value!(pkmn, collection_name, stat_def, value)
      collection = ensure_stat_collection!(pkmn, collection_name)
      return false if collection.nil?
      key = resolve_stat_key(collection, stat_def)
      return false if key.nil?
      collection[key] = value.to_i
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Set Individual Stat #{collection_name} #{stat_def[:label]}", e)
      false
    end

    def pokemon_iv_value(pkmn, stat_def)
      get_individual_stat_value(pkmn, :iv, stat_def)
    end

    def pokemon_ev_value(pkmn, stat_def)
      get_individual_stat_value(pkmn, :ev, stat_def)
    end

    def set_pokemon_iv_value!(pkmn, stat_def, value)
      set_individual_stat_value!(pkmn, :iv, stat_def, value)
    end

    def set_pokemon_ev_value!(pkmn, stat_def, value)
      set_individual_stat_value!(pkmn, :ev, stat_def, value)
    end

    def classic_iv_limit
      31
    end

    def classic_ev_limit_per_stat
      252
    end

    def classic_ev_total_limit
      510
    end

    def numeric_stat_values(collection)
      return [] if collection.nil?
      values = if collection.is_a?(Hash)
        collection.values
      elsif collection.is_a?(Array)
        collection
      else
        []
      end
      values.compact.map { |value| value.to_i }
    rescue => e
      log_error("Numeric Stat Values", e)
      []
    end

    def pokemon_has_overcap_ivs?(pkmn)
      iv_values = numeric_stat_values(stat_collection_value(pkmn, :iv))
      return false if iv_values.empty?
      iv_values.any? { |value| value > classic_iv_limit }
    rescue => e
      log_error("Overcap IV Check", e)
      false
    end

    def pokemon_has_overcap_evs?(pkmn)
      ev_values = numeric_stat_values(stat_collection_value(pkmn, :ev))
      return false if ev_values.empty?
      return true if ev_values.any? { |value| value > classic_ev_limit_per_stat }
      ev_values.inject(0) { |sum, value| sum + value } > classic_ev_total_limit
    rescue => e
      log_error("Overcap EV Check", e)
      false
    end

    def pokemon_has_overcap_stats?(pkmn)
      return false unless pkmn
      pokemon_has_overcap_ivs?(pkmn) || pokemon_has_overcap_evs?(pkmn)
    rescue => e
      log_error("Overcap Stat Check", e)
      false
    end

    def extract_pokemon_like_objects(value, found = [])
      return found if value.nil?
      if pokemon_like_object?(value)
        found << value
        return found
      end
      if value.is_a?(Array)
        value.each { |entry| extract_pokemon_like_objects(entry, found) }
      elsif value.is_a?(Hash)
        value.each_value { |entry| extract_pokemon_like_objects(entry, found) }
      end
      found
    rescue => e
      log_error("Extract Pokemon Like Objects", e)
      found
    end

    def pokemon_like_object?(value)
      return false if value.nil?
      return true if value.respond_to?(:iv) || value.respond_to?(:ev)
      return true if value.respond_to?(:personalID) || value.respond_to?(:species)
      false
    rescue
      false
    end

    def overcap_stats_in_args?(*args)
      extract_pokemon_like_objects(args).any? { |pkmn| pokemon_has_overcap_stats?(pkmn) }
    rescue => e
      log_error("Overcap Args Check", e)
      false
    end

    def advanced_stat_editor_lines(pkmn)
      stat_editor_definitions.map do |stat_def|
        iv = pokemon_iv_value(pkmn, stat_def)
        ev = pokemon_ev_value(pkmn, stat_def)
        live = pokemon_live_stat_value(pkmn, stat_def)
        _INTL("{1}: IV {2} | EV {3} | Stat {4}",
              stat_def[:label],
              iv.nil? ? "N/A" : iv,
              ev.nil? ? "N/A" : ev,
              live.nil? ? "N/A" : live)
      end
    rescue => e
      log_error("Advanced Stat Editor Lines", e)
      [_INTL("Could not read advanced stats.")]
    end

    def set_all_ivs!(pkmn, value)
      if pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Hash)
        pkmn.iv.keys.each { |k| pkmn.iv[k] = value }
      elsif pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Array)
        6.times { |i| pkmn.iv[i] = value }
      elsif pkmn.respond_to?(:iv=)
        pkmn.iv = [value, value, value, value, value, value]
      end
    rescue => e
      log_error("Set IVs", e)
    end

    def set_all_evs!(pkmn, value)
      if pkmn.respond_to?(:ev) && pkmn.ev.is_a?(Hash)
        pkmn.ev.keys.each { |k| pkmn.ev[k] = value }
      elsif pkmn.respond_to?(:ev) && pkmn.ev.is_a?(Array)
        6.times { |i| pkmn.ev[i] = value }
      elsif pkmn.respond_to?(:ev=)
        pkmn.ev = [value, value, value, value, value, value]
      end
    rescue => e
      log_error("Set EVs", e)
    end

    def bag_has_item?(item)
      return false unless defined?($PokemonBag) && $PokemonBag
      item_storage_candidates(item).each do |candidate|
        return true if $PokemonBag.respond_to?(:pbHasItem?) && $PokemonBag.pbHasItem?(candidate)
        return true if $PokemonBag.respond_to?(:hasItem?) && $PokemonBag.hasItem?(candidate)
        return true if $PokemonBag.respond_to?(:contains?) && $PokemonBag.contains?(candidate)
      end
      false
    rescue => e
      log_error("Bag Has Item", e)
      false
    end

    def item_storage_candidates(item)
      candidates = []
      candidates << item unless item.nil?
      candidates << item.to_sym if item.respond_to?(:to_sym)
      candidates << item.to_s if item.respond_to?(:to_s)

      if item.is_a?(Integer) && item > 0
        begin
          resolved_symbol = get_symbol(:Item, item)
          candidates << resolved_symbol unless resolved_symbol.nil?
        rescue => e
          log_error("Item Integer Symbol Resolve", e)
        end
      end

      if item.is_a?(Symbol)
        pb_items = safe_const_get(Object, :PBItems)
        if pb_items && pb_items.const_defined?(item)
          candidates << pb_items.const_get(item)
        end
      elsif item.is_a?(String)
        symbol_name = item.to_sym rescue nil
        pb_items = safe_const_get(Object, :PBItems)
        if symbol_name && pb_items && pb_items.const_defined?(symbol_name)
          candidates << pb_items.const_get(symbol_name)
        end
      end

      if item.is_a?(Integer) || item.is_a?(Symbol)
        begin
          record = data_record(:Item, item)
          if record
            candidates << record.id if record.respond_to?(:id)
            candidates << record.id_number if record.respond_to?(:id_number)
            candidates << record.real_name if record.respond_to?(:real_name)
            candidates << record.name if record.respond_to?(:name)
          end
        rescue => e
          log_error("Item Record Candidates", e)
        end
      end

      candidates.compact.uniq
    rescue => e
      log_error("Item Storage Candidates", e)
      [item].compact
    end

    def item_candidates_from_cache_display(display_name)
      candidates = []
      return candidates if display_name.nil? || display_name.to_s.strip == ""

      collection = cache_collection(:Item)
      if collection && collection.respond_to?(:each)
        collection.each do |key, value|
          next unless safe_display_name(value, key).to_s == display_name.to_s
          candidates.concat(item_storage_candidates(key))
          candidates << value.id if value.respond_to?(:id)
          candidates << value.id_number if value.respond_to?(:id_number)
          candidates << value.real_name if value.respond_to?(:real_name)
          candidates << value.name if value.respond_to?(:name)
        end
      end

      candidates.compact.uniq
    rescue => e
      log_error("Item Cache Display Candidates", e)
      []
    end

    def item_candidates_from_lookup(item_lookup, display_name = nil)
      candidates = []
      candidates.concat(item_storage_candidates(item_lookup))
      candidates.concat(item_candidates_from_cache_display(display_name))

      normalized_display = normalized_item_key(display_name)
      begin
        build_search_hash(:Item).each do |item_id, item_name|
          next if display_name && item_name.to_s == display_name.to_s
          next if normalized_display == "" || normalized_item_key(item_name) != normalized_display
          candidates.concat(item_storage_candidates(item_id))
          symbol = get_symbol(:Item, item_id)
          candidates.concat(item_storage_candidates(symbol))
        end
      rescue => e
        log_error("Item Candidates From Lookup", e)
      end

      candidates.compact.uniq
    rescue => e
      log_error("Item Lookup Candidates", e)
      item_storage_candidates(item_lookup)
    end

    def set_pokemon_item_from_lookup!(pkmn, item_lookup, display_name = nil)
      item_candidates_from_lookup(item_lookup, display_name).each do |candidate|
        return true if set_pokemon_item!(pkmn, candidate)
      end
      false
    rescue => e
      log_error("Set Pokemon Item From Lookup", e)
      false
    end

    def bag_store_item_from_lookup(item_lookup, qty = 1, display_name = nil)
      candidates = item_candidates_from_lookup(item_lookup, display_name)
      candidates.each do |candidate|
        return true if bag_store_item(candidate, qty)
      end
      if defined?(pbReceiveItem)
        candidates.each do |candidate|
          begin
            result = pbReceiveItem(candidate, qty)
            return true if result == true || bag_has_item?(candidate)
          rescue => e
            log_error("pbReceiveItem #{candidate}", e)
          end
        end
      end
      false
    rescue => e
      log_error("Bag Store Item From Lookup", e)
      false
    end

    def ability_candidates_from_lookup(ability_lookup, display_name = nil)
      candidates = []
      candidates << ability_lookup unless ability_lookup.nil?
      candidates << ability_lookup.to_sym if ability_lookup.respond_to?(:to_sym)
      candidates << ability_lookup.to_s if ability_lookup.respond_to?(:to_s)

      if ability_lookup.is_a?(Integer) && ability_lookup > 0
        begin
          resolved_symbol = get_symbol(:Ability, ability_lookup)
          candidates << resolved_symbol unless resolved_symbol.nil?
        rescue => e
          log_error("Ability Integer Symbol Resolve", e)
        end
      end

      if display_name && display_name.to_s.strip != ""
        normalized_display = normalized_item_key(display_name)
        begin
          build_search_hash(:Ability).each do |ability_id, ability_name|
            next unless normalized_item_key(ability_name) == normalized_display
            candidates << ability_id
            candidates << get_symbol(:Ability, ability_id)
          end
        rescue => e
          log_error("Ability Candidates From Lookup", e)
        end
      end

      candidates.compact.uniq
    rescue => e
      log_error("Ability Lookup Candidates", e)
      [ability_lookup].compact
    end

    def set_pokemon_ability_from_lookup!(pkmn, ability_lookup, display_name = nil, force_index = nil)
      ability_candidates_from_lookup(ability_lookup, display_name).each do |candidate|
        return true if set_pokemon_ability!(pkmn, candidate, force_index)
      end
      false
    rescue => e
      log_error("Set Pokemon Ability From Lookup", e)
      false
    end

    def try_bag_call(method_label)
      yield
    rescue => e
      log_error(method_label, e)
      nil
    end

    def bag_store_item(item, qty = 1)
      return false unless defined?($PokemonBag) && $PokemonBag
      item_storage_candidates(item).each do |candidate|
        before_has_item = bag_has_item?(candidate)

        if $PokemonBag.respond_to?(:pbStoreItem)
          result = try_bag_call("Bag pbStoreItem #{candidate}") do
            begin
              $PokemonBag.pbStoreItem(candidate, qty)
            rescue ArgumentError
              $PokemonBag.pbStoreItem(candidate)
            end
          end
          return true if result == true
          return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
        end

        if $PokemonBag.respond_to?(:storeItem)
          result = try_bag_call("Bag storeItem #{candidate}") do
            $PokemonBag.storeItem(candidate, qty)
          end
          return true if result == true
          return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
        end

        if $PokemonBag.respond_to?(:add)
          result = try_bag_call("Bag add #{candidate}") do
            $PokemonBag.add(candidate, qty)
          end
          return true if result == true
          return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
        end
      end
      false
    rescue => e
      log_error("Bag Store Item", e)
      false
    end

    def bag_delete_item(item, qty = 1)
      return false unless defined?($PokemonBag) && $PokemonBag
      item_storage_candidates(item).each do |candidate|
        before_has_item = bag_has_item?(candidate)

        if $PokemonBag.respond_to?(:pbDeleteItem)
          result = try_bag_call("Bag pbDeleteItem #{candidate}") do
            begin
              $PokemonBag.pbDeleteItem(candidate, qty)
            rescue ArgumentError
              $PokemonBag.pbDeleteItem(candidate)
            end
          end
          return true if result == true
          return true if before_has_item && !bag_has_item?(candidate)
        end

        if $PokemonBag.respond_to?(:deleteItem)
          result = try_bag_call("Bag deleteItem #{candidate}") do
            $PokemonBag.deleteItem(candidate, qty)
          end
          return true if result == true
          return true if before_has_item && !bag_has_item?(candidate)
        end

        if $PokemonBag.respond_to?(:remove)
          result = try_bag_call("Bag remove #{candidate}") do
            $PokemonBag.remove(candidate, qty)
          end
          return true if result == true
          return true if before_has_item && !bag_has_item?(candidate)
        end
      end
      false
    rescue => e
      log_error("Bag Delete Item", e)
      false
    end

    def normalized_item_key(text)
      text.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    rescue
      ""
    end

    def exp_all_item_aliases
      [
        "EXPALL",
        "EXPSHAREALL",
        "EXPSHARE_ALL",
        "EXPALLITEM",
        "EXPAL"
      ]
    end

    def exp_all_item_candidates
      aliases = exp_all_item_aliases.map { |name| normalized_item_key(name) }
      candidates = []
      exp_all_item_aliases.each { |name| candidates.concat(item_storage_candidates(name)) }

      begin
        build_search_hash(:Item).each do |item_id, item_name|
          normalized_name = normalized_item_key(item_name)
          next unless aliases.include?(normalized_name) || normalized_name.include?("EXPSHAREALL") || normalized_name.include?("EXPALL")
          symbol = get_symbol(:Item, item_id)
          candidates.concat(item_storage_candidates(symbol || item_id))
        end
      rescue => e
        log_error("Exp All Search Candidates", e)
      end

      candidates.compact.uniq
    rescue => e
      log_error("Exp All Item Candidates", e)
      exp_all_item_aliases
    end

    def exp_all_global_flag_names
      [:exp_all, :expAll, :experience_all, :experienceAll]
    end

    def exp_all_enabled?
      exp_all_global_flag_names.each do |reader|
        current = get_global_value(reader)
        return !!current unless current.nil?
      end
      exp_all_item_candidates.any? { |candidate| bag_has_item?(candidate) }
    rescue => e
      log_error("Exp All Enabled", e)
      false
    end

    def set_exp_all_enabled!(enabled)
      target = !!enabled
      changed = false

      exp_all_global_flag_names.each do |reader|
        changed = true if set_global_toggle(target, reader)
      end

      if target
        stored = false
        exp_all_item_candidates.each do |candidate|
          if bag_store_item(candidate, 1)
            stored = true
            changed = true
            break
          end
        end
        changed ||= stored
      else
        removed = false
        exp_all_item_candidates.each do |candidate|
          removed = true if bag_delete_item(candidate, 999)
        end
        changed ||= removed
      end

      return exp_all_enabled? == target if changed
      false
    rescue => e
      log_error("Set Exp All", e)
      false
    end

    def exp_all_status_label
      active_items = exp_all_item_candidates.select { |candidate| bag_has_item?(candidate) }
      if active_items.empty?
        exp_all_enabled? ? "ON" : "OFF"
      else
        "ON (#{active_items.first})"
      end
    rescue => e
      log_error("Exp All Status Label", e)
      exp_all_enabled? ? "ON" : "OFF"
    end

    def start_test_battle(pkmn, species_symbol, level)
      result = nil
      if cached_engine_profile[:has_modern_battle_api]
        begin
          result = WildBattle.start(pkmn, level)
          return result unless result.nil?
        rescue => e
          log_error("WildBattle.start object", e)
        end

        begin
          result = WildBattle.start(species_symbol, level)
          return result unless result.nil?
        rescue => e
          log_error("WildBattle.start species", e)
        end
      end

      if cached_engine_profile[:has_legacy_battle_api]
        begin
          result = pbWildBattle(species_symbol, level)
          return result unless result.nil?
        rescue => e
          log_error("pbWildBattle", e)
        end

        if pkmn
          begin
            result = pbWildBattle(pkmn)
            return result unless result.nil?
          rescue => e
            log_error("pbWildBattle object", e)
          end

          begin
            result = pbSingleOrDoubleWildBattle(pkmn)
            return result unless result.nil?
          rescue => e
            log_error("pbSingleOrDoubleWildBattle object", e)
          end
        end

        begin
          result = pbSingleOrDoubleWildBattle(species_symbol, level)
          return result unless result.nil?
        rescue => e
          log_error("pbSingleOrDoubleWildBattle", e)
        end
      end

      nil
    end

    def clear_moves!(pkmn)
      if pkmn.respond_to?(:moves) && pkmn.moves
        if pkmn.moves.respond_to?(:clear)
          pkmn.moves.clear
        elsif pkmn.moves.respond_to?(:Clear)
          pkmn.moves.Clear
        else
          pkmn.moves = [] if pkmn.respond_to?(:moves=)
        end
      end
    end

    def forget_move!(pkmn, index)
      return false unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      return false if index.nil? || index < 0
      if pkmn.moves.respond_to?(:delete_at)
        !!pkmn.moves.delete_at(index)
      elsif pkmn.moves.respond_to?(:DeleteAt)
        !!pkmn.moves.DeleteAt(index)
      else
        false
      end
    rescue => e
      log_error("Forget Move", e)
      false
    end

    def reset_pokemon_moves!(pkmn)
      return false unless pkmn
      pkmn.reset_moves if pkmn.respond_to?(:reset_moves)
      pkmn.resetMoves if pkmn.respond_to?(:resetMoves)
      true
    rescue => e
      log_error("Reset Moveset", e)
      false
    end

    def record_pokemon_initial_moves!(pkmn)
      return false unless pkmn
      pkmn.record_first_moves if pkmn.respond_to?(:record_first_moves)
      true
    rescue => e
      log_error("Record Initial Moves", e)
      false
    end

    def restore_pokemon_pp!(pkmn)
      return false unless pkmn
      pkmn.heal_PP if pkmn.respond_to?(:heal_PP)
      pkmn.healPP if pkmn.respond_to?(:healPP)
      true
    rescue => e
      log_error("Restore PP", e)
      false
    end

    def max_pokemon_ppups!(pkmn, value = 3)
      return false unless pkmn
      each_move_slot(pkmn) do |move, _index|
        move.ppup = value if move && move.respond_to?(:ppup=)
      end
      true
    rescue => e
      log_error("Max PP Ups", e)
      false
    end

    def duplicate_pokemon(pkmn)
      clone = try_call("Duplicate Pokemon Clone") { pkmn.clone }
      clone = try_call("Duplicate Pokemon Dup") { pkmn.dup } if clone.nil?
      clone
    rescue => e
      log_error("Duplicate Pokemon", e)
      nil
    end

    def extract_pokemon_preset(pkmn)
      return nil unless pkmn
      preset = {}
      preset[:species] = pkmn.species if pkmn.respond_to?(:species)
      preset[:level] = pkmn.level if pkmn.respond_to?(:level)
      preset[:form] = pkmn.form if pkmn.respond_to?(:form)
      preset[:nickname] = pkmn.name if pkmn.respond_to?(:name)
      preset[:item] = pkmn.item if pkmn.respond_to?(:item)
      preset[:nature] = pkmn.nature if pkmn.respond_to?(:nature)
      preset[:ability] = pkmn.ability if pkmn.respond_to?(:ability)
      preset[:ability_index] = pkmn.ability_index if pkmn.respond_to?(:ability_index)
      preset[:gender] = pkmn.gender if pkmn.respond_to?(:gender)
      preset[:shiny] = pkmn.respond_to?(:shiny?) ? pkmn.shiny? : (pkmn.respond_to?(:shiny) ? pkmn.shiny : false)
      preset[:ot_name] = pokemon_ot_name(pkmn)
      preset[:moves] = []
      each_move_slot(pkmn) do |move, _index|
        move_id = move_identifier(move)
        preset[:moves] << move_id if move_id
      end
      preset
    rescue => e
      log_error("Extract Pokemon Preset", e)
      nil
    end

    def preset_move_ids_valid?(move_ids)
      return true if move_ids.nil?
      return false unless move_ids.is_a?(Array)
      move_ids.all? do |move_id|
        next false if move_id.nil?
        !data_record(:Move, move_id).nil? || !get_symbol(:Move, move_id).nil?
      end
    rescue => e
      log_error("Preset Move Validation", e)
      false
    end

    def validate_pokemon_preset(preset)
      return false unless preset.is_a?(Hash)
      return false unless preset.key?(:species)
      return false if preset[:species].nil?
      return false if preset.key?(:level) && preset[:level].to_i <= 0
      return false if preset.key?(:form) && preset[:form].to_i < 0
      return false if preset.key?(:gender) && ![0, 1, 2, nil].include?(preset[:gender])
      return false unless preset_move_ids_valid?(preset[:moves])
      true
    rescue => e
      log_error("Validate Pokemon Preset", e)
      false
    end

    def export_pokemon_preset(pkmn, path = nil)
      path ||= preset_file_path
      preset = extract_pokemon_preset(pkmn)
      return false unless preset && validate_pokemon_preset(preset)
      File.open(path, "wb") { |f| Marshal.dump(preset, f) }
      true
    rescue => e
      log_error("Export Pokemon Preset", e)
      false
    end

    def import_pokemon_preset(path = nil)
      path ||= preset_file_path
      return nil unless File.exist?(path)
      preset = File.open(path, "rb") { |f| Marshal.load(f) }
      return preset if validate_pokemon_preset(preset)
      nil
    rescue => e
      log_error("Import Pokemon Preset", e)
      nil
    end

    def apply_pokemon_preset!(pkmn, preset)
      return false unless pkmn && validate_pokemon_preset(preset)
      return false if preset.key?(:species) && !set_pokemon_species!(pkmn, preset[:species])
      set_pokemon_level!(pkmn, preset[:level]) if preset.key?(:level)
      set_pokemon_form!(pkmn, preset[:form]) if preset.key?(:form)
      set_pokemon_nickname!(pkmn, preset[:nickname]) if preset[:nickname] && preset[:nickname] != ""
      set_pokemon_item!(pkmn, preset[:item]) if preset.key?(:item)
      set_pokemon_nature!(pkmn, preset[:nature]) if preset[:nature]
      set_pokemon_ability!(pkmn, preset[:ability], preset[:ability_index]) if preset[:ability]
      if preset.key?(:gender)
        gender_target = case preset[:gender]
        when 0 then :male
        when 1 then :female
        when 2 then :genderless
        else nil
        end
        set_pokemon_gender!(pkmn, gender_target) if gender_target
      end
      set_pokemon_shiny!(pkmn, preset[:shiny]) if preset.key?(:shiny)
      set_pokemon_ot_name!(pkmn, preset[:ot_name]) if preset[:ot_name] && preset[:ot_name] != ""
      if preset[:moves].is_a?(Array) && !preset[:moves].empty?
        clear_moves!(pkmn)
        preset[:moves].first(4).each_with_index do |move_id, index|
          return false unless assign_move!(pkmn, index, move_id)
        end
      end
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Apply Pokemon Preset", e)
      false
    end

    def create_pokemon_from_preset(preset)
      return nil unless validate_pokemon_preset(preset)
      pkmn = create_pkmn(preset[:species], preset[:level] || 1)
      return nil unless pkmn
      return nil unless apply_pokemon_preset!(pkmn, preset)
      pkmn
    rescue => e
      log_error("Create Pokemon From Preset", e)
      nil
    end

    def detect_save_layout
      layout = {}
      appdata_root = ENV["APPDATA"]
      layout[:appdata_available] = !appdata_root.nil? && appdata_root != ""
      layout[:save_dir_candidates] = []
      if layout[:appdata_available]
        Dir.glob(File.join(appdata_root, "*")).each do |path|
          next unless File.directory?(path)
          layout[:save_dir_candidates] << File.basename(path) if File.basename(path).downcase.include?("pokemon")
        end
      end
      layout
    rescue => e
      log_error("Detect Save Layout", e)
      { :appdata_available => false, :save_dir_candidates => [] }
    end

    def assign_move!(pkmn, index, move_symbol)
      return false unless pkmn.respond_to?(:moves) && pkmn.moves
      move_object = nil
      if defined?(PBMove)
        move_object = try_call("Create Legacy Move") { PBMove.new(move_symbol) }
      end
      if !move_object && defined?(Pokemon) && safe_const_get(Pokemon, :Move)
        move_object = try_call("Create Modern Move") { Pokemon::Move.new(move_symbol) }
      end
      return false unless move_object

      if pkmn.moves.respond_to?(:[]=)
        pkmn.moves[index] = move_object
      elsif pkmn.moves.respond_to?(:push)
        pkmn.moves.push(move_object)
      else
        return false
      end
      true
    end

    def storage_available?
      defined?($PokemonStorage) && $PokemonStorage
    end

    def storage_box_full?(box)
      return false unless storage_available?
      current_box = try_call("Storage Box Lookup") { $PokemonStorage[box] }
      return current_box.full? if current_box && current_box.respond_to?(:full?)
      max = storage_max_pokemon(box)
      max = 30 if max <= 0
      filled = 0
      max.times do |i|
        filled += 1 if current_box && current_box[i]
      end
      filled >= max
    end

    def set_storage_slot(box, index, pkmn)
      current_box = try_call("Storage Slot Lookup") { $PokemonStorage[box] }
      return false unless current_box
      if current_box.respond_to?(:[]=)
        current_box[index] = pkmn
        return true
      end
      if current_box.respond_to?(:set)
        current_box.set(index, pkmn)
        return true
      end
      false
    rescue => e
      log_error("Storage Write", e)
      false
    end

    def each_storage_index
      return enum_for(:each_storage_index) unless block_given?
      return unless storage_available?
      max_boxes = storage_max_boxes
      max_boxes.times do |box|
        max_slots = storage_max_pokemon(box)
        max_slots.times do |slot|
          yield box, slot
        end
      end
    end

    def set_ball_data!(pkmn, item_id)
      sym = get_symbol(:Item, item_id)
      pkmn.poke_ball = sym if pkmn.respond_to?(:poke_ball=)
      pkmn.ballused = item_id if pkmn.respond_to?(:ballused=)
      pkmn.ball_used = sym if pkmn.respond_to?(:ball_used=)
    end

    def choose_poke_ball_id
      hash = build_search_hash(:Item) do |item|
        item.is_poke_ball? rescue false
      end
      hash = build_search_hash(:Item) if hash.empty?
      search_list("Poke Balls", hash)
    end

    def search_direct_id(hash, term)
      normalized = term.to_s.strip.downcase
      match = normalized.match(/^(?:id:|#)?(\d+)$/)
      return nil unless match
      key = match[1].to_i
      hash[key] ? key : nil
    end

    def search_matches_entry?(key, value, term)
      return true if term == ""
      normalized = term.downcase
      exact = false
      if normalized.start_with?("=")
        exact = true
        normalized = normalized[1..-1].to_s.strip
      end
      haystack = "#{key} #{value}".downcase
      return value.downcase == normalized if exact
      normalized.split(/\s+/).all? { |token| haystack.include?(token) }
    end

    def current_map_events
      return [] unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      events = $game_map.events
      list = if events.respond_to?(:values)
        events.values
      elsif events.respond_to?(:to_a)
        events.to_a
      else
        events
      end
      Array(list).compact.sort_by { |event| event.id rescue 0 }
    rescue => e
      log_error("Current Map Events", e)
      []
    end

    def event_display_name(event)
      return "Unknown Event" unless event
      event_name = event.respond_to?(:name) ? event.name.to_s : ""
      event_name = "Event #{event.id}" if event_name.strip == ""
      "#{event_name} [#{event.id}]"
    rescue => e
      log_error("Event Display Name", e)
      "Unknown Event"
    end

    def choose_current_map_event
      events = current_map_events
      return nil if events.empty?
      cmds = events.map { |event| event_display_name(event) }
      cmds.push("Cancel")
      choice = Kernel.pbMessage(_INTL("Choose event:"), cmds, -1)
      return nil if choice < 0 || choice >= events.length
      events[choice]
    end

    def teleport_to_event(event)
      return false unless event && defined?($game_player) && $game_player
      x = event.respond_to?(:x) ? event.x : nil
      y = event.respond_to?(:y) ? event.y : nil
      return false if x.nil? || y.nil?
      moved = false
      if $game_player.respond_to?(:moveto)
        $game_player.moveto(x, y)
        moved = true
      elsif $game_player.respond_to?(:moveto2)
        $game_player.moveto2(x, y)
        moved = true
      elsif $game_player.respond_to?(:x=) && $game_player.respond_to?(:y=)
        $game_player.x = x
        $game_player.y = y
        moved = true
      end
      $game_player.center(x, y) if $game_player.respond_to?(:center)
      $game_player.turn_down if $game_player.respond_to?(:turn_down)
      moved
    rescue => e
      log_error("Teleport To Event", e)
      false
    end

    def refresh_event(event)
      return false unless event
      refreshed = false
      if event.respond_to?(:refresh)
        event.refresh
        refreshed = true
      end
      if event.respond_to?(:update)
        event.update
        refreshed = true
      end
      refreshed
    rescue => e
      log_error("Refresh Event", e)
      false
    end

    def export_current_map_events
      events = current_map_events
      return false if events.empty?
      File.open("PokeDebug_Current_Map_Events.txt", "w") do |f|
        events.each do |event|
          x = event.respond_to?(:x) ? event.x : "?"
          y = event.respond_to?(:y) ? event.y : "?"
          f.puts("#{event_display_name(event)} @ (#{x}, #{y})")
        end
      end
      true
    rescue => e
      log_error("Export Map Events", e)
      false
    end

    def start_test_trainer_battle(trainer_type, trainer_name, version = 0)
      if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
        begin
          return TrainerBattle.start(trainer_type, trainer_name, version)
        rescue => e
          log_error("TrainerBattle.start v1", e)
        end

        begin
          return TrainerBattle.start(trainer_type, trainer_name)
        rescue => e
          log_error("TrainerBattle.start v2", e)
        end
      end

      if defined?(pbTrainerBattle)
        attempts = [
          [trainer_type, trainer_name, nil, false, version],
          [trainer_type, trainer_name, nil, false],
          [trainer_type, trainer_name],
          [trainer_type, trainer_name, nil, false, version, false],
          [trainer_type, trainer_name, version],
          [trainer_type, trainer_name, version, false],
          [trainer_type, trainer_name, _INTL("Battle started by PokeDebug.")],
          [trainer_type, trainer_name, _INTL("Battle started by PokeDebug."), false]
        ]
        attempts.each_with_index do |args, idx|
          begin
            return pbTrainerBattle(*args)
          rescue => e
            log_error("pbTrainerBattle attempt #{idx + 1}", e)
          end
        end
      end
      nil
    end

    def on_input_update
      return if @processing_hotkey
      return if plugin_message_window_busy?
      @processing_hotkey = true
      begin
        safe_execute("Input Update") do
          ensure_runtime_patches!
          if menu_triggered?
            pbPlayDecisionSE if defined?(pbPlayDecisionSE)
            @mobile_combo_hold_frames = 0
            show_menu
          end
          if trigger_hotkey?(WTW_HOTKEY.to_sym, WTW_HOTKEY)
            toggle_wtw
          end
          if trigger_hotkey?(HEAL_HOTKEY.to_sym, HEAL_HOTKEY)
            heal_party
          end
        end
      ensure
        @processing_hotkey = false
      end
    end

    def on_map_update
      ensure_runtime_patches!
      if @walk_through_walls && $game_player
        $game_player.through = true
      end
      if defined?(@pending_map_refresh) && @pending_map_refresh
        mark_map_for_refresh!
        @pending_map_refresh = false
      end
    end

    def ensure_runtime_patches!
      return unless respond_to?(:apply_runtime_patches!)
      apply_runtime_patches!
    rescue => e
      log_error("Ensure Runtime Patches", e)
      false
    end

    def toggle_wtw
      @walk_through_walls = !@walk_through_walls
      if $game_player
        $game_player.through = @walk_through_walls
      end
      state = @walk_through_walls ? "Walk Through Walls ENABLED" : "Walk Through Walls DISABLED"
      Kernel.pbMessage(_INTL("{1}", "#{state} (#{WTW_HOTKEY})"))
    end

    def get_player
      return $Player if defined?($Player)
      return $player if defined?($player)
      return $Trainer.player if defined?($Trainer) && $Trainer.respond_to?(:player)
      return $Trainer
    end

    def heal_party
      player_party.each do |pkmn|
        next if !pkmn || (pkmn.respond_to?(:egg?) && pkmn.egg?) || (pkmn.respond_to?(:isEgg?) && pkmn.isEgg?)
        heal_pokemon!(pkmn)
      end
      Kernel.pbMessage(_INTL("{1}", "Party fully healed!"))
    end

    def create_pkmn(sp_sym_or_id, level)
      if modern_engine? && defined?(Pokemon) && Pokemon.respond_to?(:new)
        begin
          return Pokemon.new(sp_sym_or_id, level)
        rescue ArgumentError
          return Pokemon.new(sp_sym_or_id, level, get_player)
        end
      elsif defined?(PokeBattle_Pokemon)
        begin
          return PokeBattle_Pokemon.new(sp_sym_or_id, level, get_player)
        rescue ArgumentError
          return PokeBattle_Pokemon.new(sp_sym_or_id, level)
        end
      end
      nil
    rescue => e
      log_error("Create Pokemon", e)
      nil
    end

    def add_pkmn_silently(pkmn)
      party = player_party
      if party.length < 6
        party.push(pkmn)
      else
        storage_store_caught(pkmn)
      end
    end

    def get_symbol(type, id_or_index)
      collection = cache_collection(type)
      if collection && collection.respond_to?(:keys)
        keys = collection.keys
        return keys[id_or_index - 1] if id_or_index > 0 && id_or_index <= keys.size
      end

      klass = game_data_class(type)
      if klass
        idx = 0
        klass.each do |data|
          idx += 1
          return data.id if idx == id_or_index
        end
      end
      return id_or_index 
    end

    def build_search_hash(type, filter_block = nil)
      hash = {}
      
      collection = cache_collection(type)
      if collection && collection.respond_to?(:each)
        idx = 0
        collection.each do |k, v|
          next if filter_block && !filter_block.call(v || k)
          idx += 1
          hash[idx] = safe_display_name(v, k)
        end
        return hash unless hash.empty?
      end

      klass = game_data_class(type)
      if klass
        idx = 0
        klass.each do |item|
          next if filter_block && !filter_block.call(item)
          idx += 1
          hash[idx] = item.name
        end
      else
        pb_mod = legacy_pb_module(type)
        if pb_mod
          pb_mod.constants.each do |c|
            next if c.to_s.empty? || c == :MAX_LEVEL
            val = pb_mod.const_get(c)
            next if val <= 0
            name = legacy_constant_display_name(type, c, val)
            next if filter_block && !filter_block.call(val)
            hash[val] = name
          end
        end
      end
      hash
    end

    def dump_ids(type, filename)
      hash = build_search_hash(type)
      File.open(filename, "w") do |f|
        hash.sort.each { |k, v| f.puts(sprintf("%03d: %s", k, v)) }
      end
      Kernel.pbMessage(_INTL("Exported {1} items to {2} in game root folder.", hash.size, filename))
    end

    def get_map_infos
      @map_infos ||= safe_load_data("Data/MapInfos.rxdata")
    end

    def get_system_data
      @system_data ||= safe_load_data("Data/System.rxdata")
    end

    def search_list(title, hash)
      if hash.empty?
        Kernel.pbMessage(_INTL("No {1} found in game data.", title))
        return nil
      end
      loop do
        term = Kernel.pbMessageFreeText(_INTL("Search {1} (blank/ID/=Exact):", title), "", false, 256)
        direct_id = search_direct_id(hash, term)
        return direct_id if direct_id

        matches = []; keys = []
        hash.each do |k, v|
          next unless search_matches_entry?(k, v, term.to_s.strip)
          matches.push(sprintf("%03d: %s", k, v))
          keys.push(k)
        end
        if matches.empty?
          if Kernel.pbConfirmMessage(_INTL("No results found. Search again?"))
            next
          else
            return nil
          end
        end
        matches.push("Cancel")
        ch = Kernel.pbMessage(_INTL("Select:"), matches, -1)
        return keys[ch] if ch >= 0 && ch < keys.length
        return nil if ch == keys.length 
      end
    end

    def render_dynamic_menu(title, menu_array)
      loop do
        options = menu_array.map { |item| item[:label] }
        options.push(t(TR[:back]))
        
        choice = Kernel.pbMessage(_INTL(title), options, -1)
        break if choice < 0 || choice == options.length - 1
        
        safe_execute(menu_array[choice][:label]) do
          menu_array[choice][:action].call
        end
      end
    end

    def show_menu
      return if @menu_open
      @menu_open = true
      
      main_menu = [
        { :label => t(TR[:engine]).upcase, :action => proc { menu_engine } },
        { :label => t(TR[:pokemon]).upcase, :action => proc { menu_pokemon } },
        { :label => t(TR[:items]).upcase, :action => proc { menu_item } },
        { :label => t(TR[:Player]).upcase, :action => proc { menu_player } },
        { :label => t(TR[:party]).upcase, :action => proc { menu_party } },
        { :label => t(TR[:extras]).upcase, :action => proc { menu_extras } }
      ]
      
      render_dynamic_menu(t(TR[:dev_menu]) + " (Kzuran)", main_menu)
      @menu_open = false
    end

    def open_menu_external
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      show_menu
      true
    rescue => e
      log_error("External Menu Open", e)
      false
    end

    def menu_extras
      menu = [
        { :label => "Quick Actions", :action => proc {
          run_quick_actions_menu
        }},
        { :label => "Configure Quick Actions", :action => proc {
          configure_quick_actions
        }},
        { :label => t(TR[:nobattles]), :action => proc {
          @no_battles = !@no_battles
          Kernel.pbMessage(_INTL("No Battles: {1}", @no_battles ? "ON" : "OFF"))
        }},
        { :label => t(TR[:infmega]), :action => proc {
          @inf_mega = !@inf_mega
          Kernel.pbMessage(_INTL("Infinite Mega: {1}", @inf_mega ? "ON" : "OFF"))
        }},
        { :label => "Engine Compatibility Report", :action => proc {
          show_engine_report
        }},
        { :label => "Show JoiPlay/Mobile Open Help", :action => proc {
          show_joiplay_help
        }},
        { :label => "Open Native Pokemon Editor", :action => proc {
          open_native_pokemon_editor_for_party
        }},
        { :label => "Open Native Debug Menu", :action => proc {
          @menu_open = false
          unless open_native_debug_menu
            Kernel.pbMessage(_INTL("Native Debug Menu was removed by the game developer."))
          end
          @menu_open = true
        }}
      ]
      render_dynamic_menu(t(TR[:extras]).upcase, menu)
    end

    def show_joiplay_help
      Kernel.pbMessage(_INTL("{1}",
        "JoiPlay/mobile fallback:\n" \
        "- Hold A + B + C for a moment\n" \
        "- Or press L + R / AUX1 + AUX2 if mapped\n" \
        "- Event/script call: pbPokeDebugMenu"
      ))
    rescue => e
      log_error("JoiPlay Help", e)
    end
