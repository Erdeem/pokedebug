    def battle_access_config_path
      "PokeDebug_BattleAccess.cfg"
    end

    def default_battle_access_config
      config = {
        :allow_battle_menu => false,
        :allow_battle_heal_hotkey => true,
        :allow_battle_wtw_hotkey => false,
        :battle_tools_menu => true,
        :menu_engine => false,
        :menu_pokemon => false,
        :menu_items => false,
        :menu_player => false,
        :menu_party => false,
        :menu_extras => false
      }
      battle_action_seed_definitions.each do |entry|
        config[entry[:key]] = false unless config.key?(entry[:key])
      end
      config
    end

    def battle_action_seed_definitions
      [
        { :key => :battle_tools_menu, :label => "Battle > Battle Tools Menu" },
        { :key => :battle_direct_heal, :label => "Battle > Heal Party" },
        { :key => :battle_heal_active, :label => "Battle > Heal Active Pokemon" },
        { :key => :battle_cure_status, :label => "Battle > Cure Party Status" },
        { :key => :battle_restore_pp, :label => "Battle > Restore Party PP" },
        { :key => :battle_revive_party, :label => "Battle > Revive Party" },
        { :key => :engine_quick_status, :label => "Engine > Quick Status" },
        { :key => :engine_warp, :label => "Engine > Warp to Map" },
        { :key => :engine_switches, :label => "Engine > Switches" },
        { :key => :engine_variables, :label => "Engine > Variables" },
        { :key => :engine_safari, :label => "Engine > Safari / Contest" },
        { :key => :engine_field_effects, :label => "Engine > Field Effects" },
        { :key => :engine_map_events, :label => "Engine > Map / Event Tools" },
        { :key => :engine_refresh_map, :label => "Engine > Refresh Map" },
        { :key => :engine_daycare, :label => "Engine > Day Care" },
        { :key => :engine_wallpapers, :label => "Engine > Wallpapers" },
        { :key => :engine_test_battle, :label => "Engine > Test Wild Battle" },
        { :key => :engine_test_trainer_battle, :label => "Engine > Test Trainer Battle" },
        { :key => :engine_exp_all, :label => "Engine > Toggle Exp. All" },
        { :key => :engine_wtw, :label => "Engine > Walk Through Walls" },
        { :key => :engine_open_pc, :label => "Engine > Open PC" },
        { :key => :pokemon_quick_status, :label => "Pokemon > Quick Status" },
        { :key => :pokemon_fill_storage, :label => "Pokemon > Fill PC" },
        { :key => :pokemon_clear_storage, :label => "Pokemon > Clear PC" },
        { :key => :pokemon_expand_boxes, :label => "Pokemon > Add Boxes" },
        { :key => :pokemon_quick_hatch, :label => "Pokemon > Quick Hatch" },
        { :key => :pokemon_add, :label => "Pokemon > Add Pokemon" },
        { :key => :pokemon_import_preset, :label => "Pokemon > Import Preset" },
        { :key => :pokemon_heal_party, :label => "Pokemon > Heal Party" },
        { :key => :pokemon_export_ids, :label => "Pokemon > Export Species IDs" },
        { :key => :items_add, :label => "Items > Add Item" },
        { :key => :items_fill_all, :label => "Items > Fill Bag (All)" },
        { :key => :items_fill_non_key, :label => "Items > Fill Bag (Non-Key)" },
        { :key => :items_fill_key, :label => "Items > Fill Bag (Key Items)" },
        { :key => :items_empty, :label => "Items > Empty Bag" },
        { :key => :items_export_ids, :label => "Items > Export Item IDs" },
        { :key => :player_quick_summary, :label => "Player > Quick Summary" },
        { :key => :player_edit_money, :label => "Player > Edit Money" },
        { :key => :player_edit_coins, :label => "Player > Edit Coins" },
        { :key => :player_edit_bp, :label => "Player > Edit Battle Points" },
        { :key => :player_edit_ash, :label => "Player > Edit Ash" },
        { :key => :player_badges, :label => "Player > Toggle Badges" },
        { :key => :player_character, :label => "Player > Change Character" },
        { :key => :player_gender, :label => "Player > Change Gender" },
        { :key => :player_outfit, :label => "Player > Change Outfit" },
        { :key => :player_name, :label => "Player > Rename Player" },
        { :key => :player_trainer_id, :label => "Player > Trainer ID" },
        { :key => :player_running_shoes, :label => "Player > Running Shoes" },
        { :key => :player_pokedex, :label => "Player > Toggle Pokedex" },
        { :key => :player_pokegear, :label => "Player > Toggle Pokegear" },
        { :key => :player_playtime, :label => "Player > Edit Play Time" },
        { :key => :player_region, :label => "Player > Change Region" },
        { :key => :player_complete_dex, :label => "Player > Complete Pokedex" },
        { :key => :player_partner, :label => "Player > Clear Partner" },
        { :key => :party_select_pokemon, :label => "Party > Select Pokemon" },
        { :key => :party_quick_summary, :label => "Party > Quick Summary" },
        { :key => :party_hp_status, :label => "Party > HP / Status" },
        { :key => :party_level_stats, :label => "Party > Level / Stats" },
        { :key => :party_moves, :label => "Party > Moves" },
        { :key => :party_held_item, :label => "Party > Held Item" },
        { :key => :party_ability, :label => "Party > Ability" },
        { :key => :party_nature_gender, :label => "Party > Nature & Gender" },
        { :key => :party_species_form, :label => "Party > Species & Form" },
        { :key => :party_cosmetics, :label => "Party > Cosmetics & Ribbons" },
        { :key => :party_flags, :label => "Party > Discardable Flags" },
        { :key => :party_egg, :label => "Party > Egg Options" },
        { :key => :party_export_preset, :label => "Party > Export Preset" },
        { :key => :party_apply_preset, :label => "Party > Apply Preset" },
        { :key => :party_duplicate, :label => "Party > Duplicate" },
        { :key => :party_delete, :label => "Party > Delete" },
        { :key => :party_hp_heal, :label => "Party > HP / Status > Heal" },
        { :key => :party_hp_edit, :label => "Party > HP / Status > Edit HP" },
        { :key => :party_hp_faint, :label => "Party > HP / Status > Faint" },
        { :key => :party_hp_status_problem, :label => "Party > HP / Status > Status Problem" },
        { :key => :party_hp_clear_status, :label => "Party > HP / Status > Clear Status" },
        { :key => :party_hp_give_pokerus, :label => "Party > HP / Status > Give Pokerus" },
        { :key => :party_hp_cure_pokerus, :label => "Party > HP / Status > Cure Pokerus" },
        { :key => :party_stats_edit_level, :label => "Party > Level / Stats > Edit Level" },
        { :key => :party_stats_edit_exp, :label => "Party > Level / Stats > Edit Experience" },
        { :key => :party_stats_advanced, :label => "Party > Level / Stats > Advanced Stat Editor" },
        { :key => :party_stats_max_ivs, :label => "Party > Level / Stats > Max IVs" },
        { :key => :party_stats_max_evs, :label => "Party > Level / Stats > Max EVs" },
        { :key => :party_stats_happiness, :label => "Party > Level / Stats > Edit Happiness" },
        { :key => :party_stats_contest, :label => "Party > Level / Stats > Max Contest Stats" },
        { :key => :party_stats_personal_id, :label => "Party > Level / Stats > Randomize Personal ID" },
        { :key => :party_moves_view, :label => "Party > Moves > View Moveset" },
        { :key => :party_moves_learn, :label => "Party > Moves > Learn Move" },
        { :key => :party_moves_forget, :label => "Party > Moves > Forget Move" },
        { :key => :party_moves_reset, :label => "Party > Moves > Reset Moveset" },
        { :key => :party_moves_save_initial, :label => "Party > Moves > Save Current as Initial" },
        { :key => :party_moves_restore_pp, :label => "Party > Moves > Restore PP" },
        { :key => :party_moves_max_ppups, :label => "Party > Moves > Max PP Ups" },
        { :key => :party_item_view, :label => "Party > Held Item > View Current Item" },
        { :key => :party_item_set, :label => "Party > Held Item > Set Held Item" },
        { :key => :party_item_remove, :label => "Party > Held Item > Remove Held Item" },
        { :key => :party_ability_view, :label => "Party > Ability > View Current Ability" },
        { :key => :party_ability_set_legal, :label => "Party > Ability > Set Legal Ability" },
        { :key => :party_ability_search_any, :label => "Party > Ability > Search Any Ability" },
        { :key => :party_ability_reset, :label => "Party > Ability > Reset Ability" },
        { :key => :party_ability_export_ids, :label => "Party > Ability > Export Ability IDs" }
      ]
    end

    def battle_action_label_map
      @battle_action_label_map ||= begin
        map = {}
        battle_action_seed_definitions.each { |entry| map[entry[:key]] = entry[:label] }
        map
      end
    rescue => e
      log_error("Battle Action Label Map", e)
      {}
    end

    def battle_access_config
      @battle_access_config ||= default_battle_access_config.dup
    end

    def normalize_boolean_config(value)
      text = value.to_s.strip.downcase
      return true if ["1", "true", "yes", "on"].include?(text)
      return false if ["0", "false", "no", "off"].include?(text)
      nil
    rescue
      nil
    end

    def write_battle_access_config!
      lines = battle_access_config.keys.sort_by { |key| key.to_s }.map do |key|
        "#{key}=#{battle_access_enabled?(key) ? 'true' : 'false'}"
      end
      File.open(battle_access_config_path, "w") { |f| f.puts(lines.join("\n")) }
      true
    rescue => e
      log_error("Write Battle Access Config", e)
      false
    end

    def load_battle_access_config!
      @battle_access_config = default_battle_access_config.dup
      return @battle_access_config unless File.file?(battle_access_config_path)

      File.readlines(battle_access_config_path).each do |line|
        next if line.nil?
        raw = line.strip
        next if raw == ""
        next if raw.index("#") == 0
        key_text, value_text = raw.split("=", 2)
        next if value_text.nil?
        key = key_text.to_s.strip.downcase.to_sym
        next unless default_battle_access_config.key?(key)
        normalized = normalize_boolean_config(value_text)
        next if normalized.nil?
        @battle_access_config[key] = normalized
      end
      @battle_access_config
    rescue => e
      log_error("Load Battle Access Config", e)
      @battle_access_config = default_battle_access_config.dup
    end

    def reset_battle_access_to_default!
      @battle_access_config = default_battle_access_config.dup
      write_battle_access_config!
    rescue => e
      log_error("Reset Battle Access", e)
      false
    end

    def battle_access_enabled?(key)
      load_battle_access_config! if @battle_access_config.nil?
      value = battle_access_config[key]
      return default_battle_access_config[key] if value.nil?
      !!value
    rescue => e
      log_error("Battle Access Enabled #{key}", e)
      !!default_battle_access_config[key]
    end

    def set_battle_access_option!(key, value)
      return false unless default_battle_access_config.key?(key)
      battle_access_config[key] = !!value
      write_battle_access_config!
    rescue => e
      log_error("Set Battle Access #{key}", e)
      false
    end

    def battle_menu_section_entries
      [
        { :key => :menu_engine, :label => t(TR[:engine]).upcase, :action => proc { menu_engine } },
        { :key => :menu_pokemon, :label => t(TR[:pokemon]).upcase, :action => proc { menu_pokemon } },
        { :key => :menu_items, :label => t(TR[:items]).upcase, :action => proc { menu_item } },
        { :key => :menu_player, :label => t(TR[:Player]).upcase, :action => proc { menu_player } },
        { :key => :menu_party, :label => t(TR[:party]).upcase, :action => proc { menu_party } },
        { :key => :menu_extras, :label => t(TR[:extras]).upcase, :action => proc { menu_extras } }
      ]
    rescue => e
      log_error("Battle Menu Section Entries", e)
      []
    end

    def battle_menu_enabled?
      battle_access_enabled?(:allow_battle_menu)
    rescue => e
      log_error("Battle Menu Enabled", e)
      false
    end

    def battle_heal_hotkey_enabled?
      battle_access_enabled?(:allow_battle_heal_hotkey)
    rescue => e
      log_error("Battle Heal Hotkey Enabled", e)
      true
    end

    def battle_wtw_hotkey_enabled?
      battle_access_enabled?(:allow_battle_wtw_hotkey)
    rescue => e
      log_error("Battle WTW Hotkey Enabled", e)
      false
    end

    def battle_menu_sections_allowed?
      battle_menu_section_entries.any? { |entry| battle_access_enabled?(entry[:key]) }
    rescue => e
      log_error("Battle Menu Sections Allowed", e)
      false
    end

    def battle_menu_open_allowed?
      battle_menu_enabled? && battle_menu_sections_allowed?
    rescue => e
      log_error("Battle Menu Open Allowed", e)
      false
    end

    def filtered_main_menu_entries
      entries = battle_menu_section_entries
      return entries unless battle_scene_active?
      return [] unless battle_menu_open_allowed?
      filtered = []
      if battle_access_enabled?(:battle_tools_menu) && battle_tools_available?
        filtered << battle_menu_entry(:battle_tools_menu, "BATTLE TOOLS") {
          ::DeveloperMenu.battle_tools_menu if ::DeveloperMenu.respond_to?(:battle_tools_menu)
        }
      end
      filtered.concat(entries.select { |entry| battle_access_enabled?(entry[:key]) })
      filtered
    rescue => e
      log_error("Filtered Main Menu Entries", e)
      []
    end

    def battle_access_status_lines
      lines = []
      lines << _INTL("Open menu in battle: {1}", on_off_text(battle_menu_enabled?))
      lines << _INTL("Heal hotkey in battle: {1}", on_off_text(battle_heal_hotkey_enabled?))
      lines << _INTL("Walk Through Walls hotkey in battle: {1}", on_off_text(battle_wtw_hotkey_enabled?))
      lines << _INTL("Battle tools menu: {1}", on_off_text(battle_access_enabled?(:battle_tools_menu)))
      battle_menu_section_entries.each do |entry|
        lines << _INTL("{1}: {2}", entry[:label], on_off_text(battle_access_enabled?(entry[:key])))
      end
      battle_action_seed_definitions.each do |entry|
        lines << _INTL("{1}: {2}", entry[:label], on_off_text(battle_access_enabled?(entry[:key])))
      end
      lines
    rescue => e
      log_error("Battle Access Status Lines", e)
      report_failure_lines("battle access settings")
    end

    def battle_entry_label(key)
      battle_action_label_map[key] || key.to_s
    rescue
      key.to_s
    end

    def register_battle_action_key(key, label = nil)
      return nil if key.nil?
      battle_action_label_map[key] = label.to_s if label && label.to_s.strip != ""
      battle_access_config[key] = false unless battle_access_config.key?(key)
      key
    rescue => e
      log_error("Register Battle Action Key #{key}", e)
      key
    end

    def battle_menu_entry(key, label, action = nil, &block)
      final_action = action || block
      register_battle_action_key(key, label)
      { :label => label.to_s, :action => final_action, :battle_key => key }
    rescue => e
      log_error("Battle Menu Entry #{key}", e)
      { :label => label.to_s, :action => proc { }, :battle_key => key }
    end

    def battle_filter_menu_entries(menu_array)
      entries = normalize_menu_entries(menu_array)
      return entries unless battle_scene_active?
      entries.select do |entry|
        key = entry[:battle_key]
        next false if key.nil?
        battle_access_enabled?(key)
      end
    rescue => e
      log_error("Battle Filter Menu Entries", e)
      []
    end

    def configure_battle_access_menu
      load_battle_access_config!
      loop do
        menu = [
          { :label => "Core Battle Permissions", :action => proc { configure_battle_access_core_menu } },
          { :label => "Battle Menu Categories", :action => proc { configure_battle_access_category_menu } },
          { :label => "Engine Actions", :action => proc { configure_battle_access_action_group("Engine", /^engine_/) } },
          { :label => "Pokemon Actions", :action => proc { configure_battle_access_action_group("Pokemon", /^pokemon_/) } },
          { :label => "Item Actions", :action => proc { configure_battle_access_action_group("Items", /^items_/) } },
          { :label => "Player Actions", :action => proc { configure_battle_access_action_group("Player", /^player_/) } },
          { :label => "Party Actions", :action => proc { configure_battle_access_action_group("Party", /^party_/) } },
          { :label => "Show Current Battle Access", :action => proc {
            safe_text_message(battle_access_status_lines.join("\n"), "Battle Access Status")
          }},
          { :label => "Reset to Default", :action => proc {
            reset_battle_access_to_default!
            safe_text_message("Battle access reset to default. Only heal hotkey stays enabled in battle.", "Battle Access Reset")
          }}
        ]
        render_dynamic_menu("Battle Access Settings", menu)
        break
      end
    rescue => e
      log_error("Configure Battle Access", e)
      safe_text_message("Could not configure battle access.", "Configure Battle Access Failure")
      false
    end

    def configure_battle_access_core_menu
      loop do
        cmds = [
          "Open Menu in Battle: #{on_off_text(battle_menu_enabled?)}",
          "Heal Hotkey in Battle: #{on_off_text(battle_heal_hotkey_enabled?)}",
          "Walk Through Walls Hotkey in Battle: #{on_off_text(battle_wtw_hotkey_enabled?)}",
          "Battle Tools Menu in Battle: #{on_off_text(battle_access_enabled?(:battle_tools_menu))}",
          menu_back_label
        ]
        choice = safe_menu_choice("Core Battle Permissions:", cmds, -1, "Core Battle Permissions")
        break if choice < 0 || choice == cmds.length - 1
        case choice
        when 0
          set_battle_access_option!(:allow_battle_menu, !battle_menu_enabled?)
        when 1
          set_battle_access_option!(:allow_battle_heal_hotkey, !battle_heal_hotkey_enabled?)
        when 2
          set_battle_access_option!(:allow_battle_wtw_hotkey, !battle_wtw_hotkey_enabled?)
        when 3
          set_battle_access_option!(:battle_tools_menu, !battle_access_enabled?(:battle_tools_menu))
        end
      end
    rescue => e
      log_error("Configure Battle Access Core", e)
      false
    end

    def configure_battle_access_category_menu
      entries = battle_menu_section_entries
      loop do
        cmds = entries.map { |entry| "#{entry[:label]} in Battle: #{on_off_text(battle_access_enabled?(entry[:key]))}" }
        cmds << menu_back_label
        choice = safe_menu_choice("Battle Menu Categories:", cmds, -1, "Battle Menu Categories")
        break if choice < 0 || choice == cmds.length - 1
        entry = entries[choice]
        set_battle_access_option!(entry[:key], !battle_access_enabled?(entry[:key])) if entry
      end
    rescue => e
      log_error("Configure Battle Access Categories", e)
      false
    end

    def configure_battle_access_action_group(group_name, key_pattern)
      entries = battle_action_seed_definitions.select { |entry| entry[:key].to_s =~ key_pattern }
      return false if entries.empty?
      loop do
        cmds = entries.map { |entry| "#{entry[:label]}: #{on_off_text(battle_access_enabled?(entry[:key]))}" }
        cmds << menu_back_label
        choice = safe_menu_choice("#{group_name} Battle Actions:", cmds, -1, "Battle Action Group #{group_name}")
        break if choice < 0 || choice == cmds.length - 1
        entry = entries[choice]
        set_battle_access_option!(entry[:key], !battle_access_enabled?(entry[:key])) if entry
      end
    rescue => e
      log_error("Configure Battle Action Group #{group_name}", e)
      false
    end
