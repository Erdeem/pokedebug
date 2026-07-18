    def write_report_file(filename, lines)
      File.open(filename, "w") { |f| f.puts(lines.join("\n")) }
      true
    rescue => e
      log_error("Write Report File #{filename}", e)
      false
    end

    def show_report_lines(lines, filename = nil)
      write_report_file(filename, lines) if filename && filename.to_s.strip != ""
      Kernel.pbMessage(_INTL("{1}", lines.join("\n")))
      true
    rescue => e
      log_error("Show Report Lines", e)
      false
    end

    def hotkey_status_lines
      [
        _INTL("Open Menu: {1}", hotkey_name_for(:menu)),
        _INTL("Walk Through Walls: {1}", hotkey_name_for(:walk_through_walls)),
        _INTL("Heal Party: {1}", hotkey_name_for(:heal_party)),
        _INTL("JoiPlay fallback: Hold L+R, AUX1+AUX2, X+Y, L+A, R+B, or A+B+C")
      ]
    rescue => e
      log_error("Hotkey Status Lines", e)
      report_failure_lines("hotkey status")
    end

    def mobile_menu_status_lines
      combos = mobile_menu_combo_definitions.map { |combo| "#{mobile_combo_label(combo)} (hold #{combo[:hold]})" }
      [
        _INTL("Primary menu hotkey: {1}", hotkey_name_for(:menu)),
        _INTL("JoiPlay/mobile combos: {1}", combos.join(", ")),
        _INTL("Last mobile combo used: {1}", @last_mobile_combo_label || "None"),
        _INTL("Script calls: pbPokeDebugMenu / pbPokeDebugMobileMenu / pbOpenPokeDebugMenu")
      ]
    rescue => e
      log_error("Mobile Menu Status Lines", e)
      report_failure_lines("mobile menu status")
    end

    def battle_access_summary_lines
      lines = []
      lines << _INTL("In battle now: {1}", on_off_text(battle_scene_active?))
      lines << _INTL("Battle menu allowed: {1}", on_off_text(battle_menu_enabled?))
      lines << _INTL("Battle menu can open now: {1}", on_off_text(battle_menu_open_allowed?))
      lines << _INTL("Battle heal hotkey allowed: {1}", on_off_text(battle_heal_hotkey_enabled?))
      lines << _INTL("Battle WTW hotkey allowed: {1}", on_off_text(battle_wtw_hotkey_enabled?))
      lines << _INTL("Battle sections enabled: {1}", battle_menu_section_entries.select { |entry| battle_access_enabled?(entry[:key]) }.length)
      lines
    rescue => e
      log_error("Battle Access Summary Lines", e)
      report_failure_lines("battle access summary")
    end

    def compatibility_report_lines
      lines = []
      lines << "=== PokeDebug Compatibility Report ==="
      lines.concat(engine_profile_lines)
      lines << ""
      lines << "=== Battle Access ==="
      lines.concat(battle_access_summary_lines)
      lines << ""
      lines << "=== Mobile / JoiPlay ==="
      lines.concat(mobile_menu_status_lines)
      lines << ""
      lines << "=== Runtime Status ==="
      lines.concat(engine_status_lines)
      lines << ""
      lines << "=== Hotkeys ==="
      lines.concat(hotkey_status_lines)
      lines
    rescue => e
      log_error("Compatibility Report Lines", e)
      report_failure_lines("compatibility report")
    end

    def show_compatibility_report
      reset_engine_profile!
      lines = compatibility_report_lines
      show_report_lines(lines, "PokeDebug_Compatibility_Report.txt")
    rescue => e
      log_error("Compatibility Report", e)
      report_failure_message("compatibility report")
      false
    end

    def diagnostic_lines
      save_layout = detect_save_layout
      lines = []
      lines << "=== PokeDebug Diagnostics ==="
      lines.concat(engine_profile_lines)
      lines << ""
      lines << "=== Compatibility Snapshot ==="
      lines.concat(battle_access_summary_lines)
      lines.concat(mobile_menu_status_lines)
      lines << ""
      lines << "=== Runtime Status ==="
      lines.concat(engine_status_lines)
      lines << ""
      lines << "=== Player Summary ==="
      lines.concat(player_summary_lines)
      lines << ""
      lines << "=== Pokemon Menu Status ==="
      lines.concat(pokemon_menu_status_lines)
      lines << ""
      lines << "=== Map Summary ==="
      lines.concat(current_map_summary_lines)
      lines << ""
      lines << "=== Hotkeys ==="
      lines.concat(hotkey_status_lines)
      lines << ""
      lines << "=== Save Layout ==="
      lines << "AppData available: #{on_off_text(save_layout[:appdata_available])}"
      candidates = save_layout[:save_dir_candidates] || []
      lines << "Save folders detected: #{candidates.empty? ? 'None' : candidates.join(', ')}"
      lines
    rescue => e
      log_error("Diagnostic Lines", e)
      report_failure_lines("diagnostics")
    end

    def show_diagnostics
      reset_engine_profile!
      lines = diagnostic_lines
      show_report_lines(lines, "PokeDebug_Diagnostics.txt")
    rescue => e
      log_error("Show Diagnostics", e)
      report_failure_message("diagnostics")
      false
    end

    # Runs read-only compatibility probes. Menu actions are verified
    # structurally because invoking them would change the save or game state.
    def test_all_record(results, status, section, name, detail = nil)
      text = detail.nil? || detail.to_s == "" ? name.to_s : "#{name}: #{detail}"
      results << { :status => status, :section => section.to_s, :text => text }
      true
    end

    def test_all_probe(results, section, name, failure_status = :fail)
      value = yield
      ok = value
      detail = nil
      if value.is_a?(Array)
        ok = value[0]
        detail = value[1]
      end
      test_all_record(results, ok ? :pass : failure_status, section, name, detail)
    rescue => e
      test_all_record(results, :fail, section, name, "#{e.class}: #{e.message}")
    end

    def test_all_method_group(results, section, methods)
      missing = methods.reject { |method_name| respond_to?(method_name, true) }
      detail = missing.empty? ? "#{methods.length} routes available" : "missing #{missing.join(', ')}"
      test_all_record(results, missing.empty? ? :pass : :fail, section, "Menu action routes", detail)
    rescue => e
      test_all_record(results, :fail, section, "Menu action routes", "#{e.class}: #{e.message}")
    end

    def test_all_direct_data_record(type, id)
      collection = cache_collection(type)
      if collection
        if collection.respond_to?(:keys) && collection.respond_to?(:[])
          candidates = [id]
          candidates << id.to_s if id.respond_to?(:to_s)
          candidates << id.to_sym if id.respond_to?(:to_sym)
          candidates.each do |candidate|
            begin
              value = collection[candidate]
              return value unless value.nil?
            rescue
            end
          end
        elsif collection.respond_to?(:each_with_index)
          collection.each_with_index do |record, index|
            return record if id.is_a?(Numeric) && index == id.to_i && !record.nil?
            record_id = record.id if record && record.respond_to?(:id)
            record_id = record.ID if !record_id && record && record.respond_to?(:ID)
            return record if record_id == id || record_id.to_s == id.to_s
          end
        end
      end
      klass = game_data_class(type)
      if klass
        return klass.try_get(id) if klass.respond_to?(:try_get)
        return klass.get(id) if klass.respond_to?(:get)
      end
      nil
    rescue
      nil
    end

    def test_all_data_probe(results, type, label)
      values = build_search_hash(type)
      if !values || values.empty?
        test_all_record(results, :fail, "Game data", "#{label} registry", "unavailable")
        test_all_record(results, :skip, "Game data", "#{label} adapter resolution", "no registry entries to test")
        return
      end

      keys = values.keys
      sample_indexes = [keys.first, keys[keys.length / 2], keys.last].compact.uniq
      sample_ids = sample_indexes.map { |index| get_symbol(type, index) }
      object_registry = cache_collection(type) || game_data_class(type)
      numeric_registry = !object_registry && legacy_pb_module(type)
      direct_missing = []
      adapter_missing = []
      adapter_classes = []
      parity_mismatch = []
      sample_ids.each do |sample_id|
        direct = test_all_direct_data_record(type, sample_id)
        direct_missing << sample_id if object_registry && direct.nil?
        adapted = data_record(type, sample_id)
        if adapted.nil?
          adapter_missing << sample_id
        else
          adapter_classes << adapted.class.to_s unless adapter_classes.include?(adapted.class.to_s)
          parity_mismatch << sample_id if direct && !direct.equal?(adapted)
        end
      end

      registry_detail = "#{values.length} entries; samples=#{sample_ids.map { |id| id.inspect }.join(', ')}"
      if numeric_registry
        registry_detail += "; numeric PB registry (object lookup not applicable)"
      else
        registry_detail += direct_missing.empty? ? "; direct lookup OK" : "; direct lookup missing=#{direct_missing.map { |id| id.inspect }.join(', ')}"
      end
      test_all_record(results, direct_missing.empty? ? :pass : :fail, "Game data", "#{label} registry", registry_detail)

      adapter_name = begin
        adapter = engine_adapter_for(:data)
        adapter ? adapter.id.to_s : "none"
      rescue
        "unknown"
      end
      adapter_detail = "adapter=#{adapter_name}"
      if adapter_missing.empty?
        adapter_detail += "; #{sample_ids.length}/#{sample_ids.length} resolved; classes=#{adapter_classes.join(', ')}"
      else
        adapter_detail += "; unresolved=#{adapter_missing.map { |id| id.inspect }.join(', ')}"
      end
      test_all_record(results, adapter_missing.empty? ? :pass : :fail, "Game data", "#{label} adapter resolution", adapter_detail)

      if numeric_registry && adapter_missing.empty?
        test_all_record(results, :skip, "Game data", "#{label} adapter parity", "numeric PB registry has no source objects")
      elsif !direct_missing.empty? || !adapter_missing.empty?
        test_all_record(results, :skip, "Game data", "#{label} adapter parity", "resolution must pass first")
      else
        parity_detail = parity_mismatch.empty? ? "adapted records match the cache objects" : "wrapped/different objects=#{parity_mismatch.map { |id| id.inspect }.join(', ')}"
        test_all_record(results, parity_mismatch.empty? ? :pass : :warn, "Game data", "#{label} adapter parity", parity_detail)
      end
    rescue => e
      test_all_record(results, :fail, "Game data", "#{label} diagnostic", "#{e.class}: #{e.message}")
    end

    def test_all_report_lines(results, started_at)
      counts = { :pass => 0, :warn => 0, :fail => 0, :skip => 0 }
      results.each { |result| counts[result[:status]] = counts[result[:status]].to_i + 1 }
      elapsed = ((Time.now - started_at) * 1000).to_i rescue 0
      lines = []
      lines << "=== PokeDebug Test All ==="
      lines << "Generated: #{developer_timestamp_text}"
      lines << "Version: #{developer_menu_version}"
      lines << "Result: PASS=#{counts[:pass]} WARN=#{counts[:warn]} FAIL=#{counts[:fail]} SKIP=#{counts[:skip]}"
      sections = results.map { |result| result[:section] }.uniq
      lines << "Coverage: #{results.length} probes across #{sections.length} sections"
      lines << "Duration: #{elapsed} ms"
      problems = results.select { |result| result[:status] == :fail || result[:status] == :warn }
      lines << ""
      lines << "=== Problems detected ==="
      if problems.empty?
        lines << "None. All executed probes passed."
      else
        problems.each do |problem|
          lines << "[#{problem[:status].to_s.upcase}] #{problem[:section]} > #{problem[:text]}"
        end
      end
      current_section = nil
      results.each do |result|
        if current_section != result[:section]
          current_section = result[:section]
          lines << ""
          lines << "=== #{current_section} ==="
        end
        lines << "[#{result[:status].to_s.upcase}] #{result[:text]}"
      end
      lines << ""
      lines << "Note: destructive actions were validated structurally and were not executed."
      [lines, counts]
    end

    def run_test_all
      started_at = Time.now
      results = []
      write_developer_log("test_all", "Test All", "Automatic read-only diagnostic started")

      test_all_probe(results, "Core runtime", "DeveloperMenu module") { [defined?(DeveloperMenu), DeveloperMenu.to_s] }
      test_all_probe(results, "Core runtime", "Graphics API") { [defined?(Graphics) && Graphics.respond_to?(:update), defined?(Graphics) ? Graphics.to_s : "missing"] }
      test_all_probe(results, "Core runtime", "Input API") { [defined?(Input) && Input.respond_to?(:update), defined?(Input) ? Input.to_s : "missing"] }
      test_all_probe(results, "Core runtime", "Message API") { [Kernel.respond_to?(:pbMessage, true), "Kernel.pbMessage"] }
      test_all_probe(results, "Core runtime", "Number input API") { [defined?(ChooseNumberParams) && Kernel.respond_to?(:pbMessageChooseNumber, true), "ChooseNumberParams + pbMessageChooseNumber"] }
      test_all_probe(results, "Core runtime", "Runtime patches") { [ensure_runtime_patches!, "patch refresh completed"] }
      test_all_probe(results, "Core runtime", "Input trigger hook") do
        eigenclass = class << Input; self; end
        modern = defined?(GMInputTriggerPatch) && eigenclass.ancestors.include?(GMInputTriggerPatch)
        legacy = eigenclass.method_defined?(:_gm_orig_trigger_legacy)
        [modern || legacy, modern ? "modern prepend installed" : (legacy ? "legacy alias installed" : "not installed")]
      end
      test_all_probe(results, "Core runtime", "Independent map heartbeat") do
        modern = defined?(Scene_Map) && defined?(GMSceneMapHeartbeatPatch) && Scene_Map.ancestors.include?(GMSceneMapHeartbeatPatch)
        eigenclass = class << Input; self; end
        legacy = eigenclass.method_defined?(:_gm_orig_trigger_legacy) && respond_to?(:run_legacy_input_hooks, true)
        [modern || legacy, modern ? "independent Scene_Map hook installed" : (legacy ? "driven by legacy Input hook" : "not installed")]
      end
      test_all_probe(results, "Core runtime", "Hotkey configuration") do
        config = hotkey_config
        valid = config && [:menu, :walk_through_walls, :heal_party].all? { |key| config[key] && config[key].to_s != "" }
        [valid, valid ? "menu=#{config[:menu]}, wtw=#{config[:walk_through_walls]}, heal=#{config[:heal_party]}" : "incomplete"]
      end

      profile = cached_engine_profile rescue {}
      test_all_probe(results, "Engine detection", "Engine profile") do
        family = profile[:engine_family] || "unknown"
        slug = profile[:slug] || profile[:game_slug] || "unknown"
        [family.to_s != "", "family=#{family}, game=#{slug}"]
      end
      test_all_probe(results, "Engine detection", "Current scene") { [defined?($scene) && !$scene.nil?, defined?($scene) && $scene ? $scene.class.to_s : "nil"] }
      test_all_probe(results, "Engine detection", "Map object", :warn) { [defined?($game_map) && !$game_map.nil?, defined?($game_map) && $game_map ? $game_map.class.to_s : "unavailable"] }
      test_all_probe(results, "Engine detection", "Player map object", :warn) { [defined?($game_player) && !$game_player.nil?, defined?($game_player) && $game_player ? $game_player.class.to_s : "unavailable"] }
      test_all_probe(results, "Engine detection", "Map database") do
        infos = get_map_infos
        [infos && infos.respond_to?(:length) && infos.length > 0, infos ? "#{infos.length} entries" : "unavailable"]
      end
      test_all_probe(results, "Engine detection", "Current map name") do
        map_id = defined?($game_map) && $game_map && $game_map.respond_to?(:map_id) ? $game_map.map_id : nil
        map_name = map_id ? map_name_from_id(map_id, get_map_infos) : nil
        [map_id && map_name && map_name.to_s != "", map_id ? "id=#{map_id}, name=#{map_name}" : "map ID unavailable"]
      end

      adapter_summary = engine_adapter_summary rescue []
      test_all_probe(results, "Engine adapters", "Adapter selection") { [adapter_summary.length >= 10, adapter_summary.join(" | ")] }
      adapter_summary.each do |summary|
        test_all_record(results, summary.include?("=base(") ? :warn : :pass, "Engine adapters", summary, summary.include?("=base(") ? "generic fallback" : "selected")
      end

      player = get_player rescue nil
      test_all_probe(results, "Player and save", "Player object") { [!player.nil?, player ? player.class.to_s : "unavailable"] }
      test_all_probe(results, "Player and save", "Party API") { [player && player.respond_to?(:party) && player.party.respond_to?(:each), player && player.respond_to?(:party) && player.party ? "#{player.party.length} Pokemon" : "unavailable"] }
      bag = pokedebug_device_bag rescue nil
      test_all_probe(results, "Player and save", "Bag API") { [!bag.nil?, bag ? bag.class.to_s : "unavailable"] }
      test_all_probe(results, "Player and save", "Switch table") do
        entries = complete_engine_state_entries(:switches, :Switches)
        [defined?($game_switches) && $game_switches && !entries.empty?, "#{entries.length} named/used entries"]
      end
      test_all_probe(results, "Player and save", "Variable table") do
        entries = complete_engine_state_entries(:variables, :Variables)
        [defined?($game_variables) && $game_variables && !entries.empty?, "#{entries.length} named/used entries"]
      end
      test_all_probe(results, "Player and save", "Pokemon storage", :warn) { [storage_available?, storage_available? ? "available" : "not initialized"] }

      test_all_data_probe(results, :Species, "Pokemon/species")
      test_all_data_probe(results, :Item, "Item")
      test_all_data_probe(results, :Move, "Move")
      test_all_data_probe(results, :Ability, "Ability")

      test_all_probe(results, "Search and previews", "Free-text search adapter") { [respond_to?(:safe_free_text, true), "safe_free_text"] }
      test_all_probe(results, "Search and previews", "Native list search bridge") { [respond_to?(:select_from_native_lister, true), "select_from_native_lister"] }
      test_all_probe(results, "Search and previews", "Pokemon preview") { [respond_to?(:build_species_preview_sprite, true) && respond_to?(:update_species_preview_sprite, true), "sprite builder/update"] }
      test_all_probe(results, "Search and previews", "Item preview") { [respond_to?(:select_item_with_preview, true) || defined?(ItemIconSprite), "custom or native item preview"] }

      if defined?(AnimatedSpriteOverrides)
        test_all_probe(results, "Animated sprites", "Compatibility module") { [AnimatedSpriteOverrides.respond_to?(:install_runtime_patches), "loaded"] }
        test_all_probe(results, "Animated sprites", "Runtime patches", :warn) do
          ready = defined?($animated_sprites_runtime_ready) && $animated_sprites_runtime_ready
          [ready, ready ? "ready" : "loaded, but no compatible sprite target is active"]
        end
        test_all_probe(results, "Animated sprites", "Animated battler folder", :warn) do
          root = AnimatedSpriteOverrides.config[:root] rescue "Graphics/AnimatedBattlers"
          [File.directory?(root), root]
        end
      else
        test_all_record(results, :skip, "Animated sprites", "Compatibility module", "not installed for this game")
      end

      device_record = pokedebug_device_registered_record
      device_numeric = pokedebug_device_storage_id
      device_constant = begin
        pb_items = safe_const_get(Object, :PBItems)
        pb_items && pb_items.const_defined?(pokedebug_device_item_id) && pb_items.const_get(pokedebug_device_item_id).to_i == device_numeric.to_i
      rescue
        false
      end
      device_bounds = begin
        pb_items = safe_const_get(Object, :PBItems)
        !device_constant || (( !pb_items.respond_to?(:maxValue) || pb_items.maxValue.to_i >= device_numeric.to_i) &&
          (!pb_items.respond_to?(:getCount) || pb_items.getCount.to_i > device_numeric.to_i))
      rescue
        false
      end
      device_ready = !device_record.nil? || (device_constant && device_bounds)
      source = if pokedebug_device_item_record
                 "GameData::Item"
               elsif pokedebug_device_legacy_cache_items
                 "$cache.items"
               elsif pokedebug_device_legacy_array_items
                 "$ItemData"
               elsif device_constant
                 "PBItems numeric constant"
               else
                 "unavailable"
               end
      test_all_record(results, device_ready ? :pass : :fail, "PokeDebug device", "Item registration", device_ready ? "id=#{device_numeric.inspect} via #{source}" : "unavailable")
      if device_constant
        test_all_record(results, device_bounds ? :pass : :fail, "PokeDebug device", "PBItems numeric bounds", device_bounds ? "maxValue/getCount include #{device_numeric}" : "compiled limits still reject #{device_numeric}")
      end
      if device_ready
        device_name = begin
          if defined?(PBItems) && PBItems.respond_to?(:getName)
            PBItems.getName(device_numeric)
          elsif device_record && device_record.respond_to?(:name)
            device_record.name
          else
            POKEDEBUG_DEVICE_NAME
          end
        rescue
          nil
        end
        test_all_record(results, device_name.to_s == POKEDEBUG_DEVICE_NAME ? :pass : :fail, "PokeDebug device", "Item messages", device_name ? "name=#{device_name.inspect}" : "name unavailable")
        metadata = pokedebug_device_registered_record
        if metadata && metadata.respond_to?(:[])
          pocket = begin metadata[pokedebug_legacy_item_index(:ITEMPOCKET, 3)] rescue nil end
          field_use = begin metadata[pokedebug_legacy_item_index(:ITEMUSE, 6)] rescue nil end
          item_type = begin metadata[pokedebug_legacy_item_index(:ITEMTYPE, 8)] rescue nil end
          metadata_ok = pocket.to_i == 8 && field_use.to_i == 2 && item_type.to_i == 6
          test_all_record(results, metadata_ok ? :pass : :fail, "PokeDebug device", "Legacy item metadata", "pocket=#{pocket.inspect}, field_use=#{field_use.inspect}, type=#{item_type.inspect}")
        elsif device_constant && !pokedebug_device_legacy_array_items
          test_all_record(results, :warn, "PokeDebug device", "Legacy item metadata", "engine exposes no mutable item table")
        end
        test_all_probe(results, "PokeDebug device", "Use handlers", :warn) { [!!@pokedebug_device_handlers_registered, @pokedebug_device_handlers_registered ? "registered for #{device_numeric.inspect}" : "not registered yet"] }
        test_all_probe(results, "PokeDebug device", "Present in Bag", :warn) { [pokedebug_device_in_bag?(bag), device_numeric.inspect] }
      else
        test_all_record(results, :skip, "PokeDebug device", "Use handlers", "item registration failed")
        test_all_record(results, :skip, "PokeDebug device", "Present in Bag", "item registration failed")
      end

      test_all_method_group(results, "Engine menu", [:menu_engine, :engine_warp, :engine_switches, :engine_variables, :engine_safari, :engine_field_effects, :engine_map_events, :engine_refresh_map, :engine_runtime_debug_toggle, :engine_pbs_editors, :engine_skip_credits, :engine_day_care, :engine_wallpapers, :engine_test_battle, :engine_test_battle_advanced, :engine_test_trainer_battle, :engine_test_trainer_battle_advanced, :engine_encounter_version, :engine_roamers, :engine_reset_trainers, :engine_exp_all, :engine_battle_logging])
      test_all_method_group(results, "Pokemon menu", [:menu_pokemon, :pokemon_fill_storage, :pokemon_clear_storage, :pokemon_expand_boxes, :pokemon_quick_hatch, :pokemon_add, :pokemon_import_preset])
      test_all_method_group(results, "Items menu", [:menu_item, :item_add, :item_fill, :item_empty, :bag_store_item_from_lookup])
      test_all_method_group(results, "Player menu", [:menu_player, :player_money_menu, :player_character_menu, :player_phone_contacts, :player_complete_dex, :player_badges])
      test_all_method_group(results, "Party editor", [:menu_party, :party_hp, :party_stats, :party_moves, :party_item, :party_ability, :party_nature_gender, :party_species_form, :party_cosmetics, :party_flags, :party_egg, :party_duplicate, :party_export_preset, :party_apply_preset])
      test_all_method_group(results, "Battle tools", [:battle_scene_active?, :current_battle_object, :battle_battlers, :battle_tools_menu, :heal_party_in_battle!, :cure_party_status_in_battle!, :restore_party_pp_in_battle!, :revive_party_in_battle!])
      test_all_method_group(results, "Extras menu", [:menu_extras, :show_compatibility_report, :show_diagnostics, :show_engine_report, :configure_hotkeys_menu, :configure_battle_access_menu])

      if player && player.respond_to?(:party) && player.party && !player.party.empty?
        sample = player.party.compact.first
        test_all_probe(results, "Party sample", "Pokemon object") { [!sample.nil?, sample ? sample.class.to_s : "nil"] }
        test_all_probe(results, "Party sample", "Moves readable") { [sample && sample.respond_to?(:moves) && sample.moves.respond_to?(:each), sample && sample.respond_to?(:moves) && sample.moves ? "#{sample.moves.length} slots" : "unavailable"] }
        test_all_probe(results, "Party sample", "Ability readable", :warn) { [sample && (sample.respond_to?(:ability) || sample.respond_to?(:ability_id) || sample.respond_to?(:abilityIndex)), "legacy/modern getter"] }
        test_all_probe(results, "Party sample", "Summary generation") do
          lines = pokemon_summary_lines(sample)
          [lines && !lines.empty?, lines ? "#{lines.length} lines" : "unavailable"]
        end
        test_all_probe(results, "Party sample", "Moveset generation") do
          lines = pokemon_move_lines(sample)
          [lines && !lines.empty?, lines ? "#{lines.length} lines" : "unavailable"]
        end
      else
        test_all_record(results, :skip, "Party sample", "Pokemon field probes", "party is empty")
      end

      report, counts = test_all_report_lines(results, started_at)
      report_path = "PokeDebug_TestAll_Report.txt"
      report_written = write_report_file(report_path, report)
      report.each { |line| write_developer_log("test_all", "Test All Result", line) }
      write_developer_log("test_all", "Test All", "Completed PASS=#{counts[:pass]} WARN=#{counts[:warn]} FAIL=#{counts[:fail]} report=#{report_path}")
      message = "Test All completed.\nPASS: #{counts[:pass]}  WARN: #{counts[:warn]}  FAIL: #{counts[:fail]}  SKIP: #{counts[:skip]}\n"
      message += report_written ? "Detailed report: #{report_path}\nAlso appended to #{developer_log_path}." : "Could not write the dedicated report; results were appended to #{developer_log_path}."
      safe_text_message(message, "Test All Summary")
      counts[:fail] == 0
    rescue => e
      log_error("Test All", e)
      safe_text_message("Test All could not finish. Check #{developer_log_path}.", "Test All Failure")
      false
    end

    def quick_actions_config_path
      "PokeDebug_QuickActions.cfg"
    end

    def write_quick_actions_config!
      begin
        lines = quick_actions.map(&:to_s)
        File.open(quick_actions_config_path, "w") { |f| f.puts(lines.join("\n")) }
        true
      rescue => e
        log_error("Write Quick Actions Config", e)
        false
      end
    end

    def load_quick_actions_config!
      @quick_actions = [:heal_party, :engine_report, :native_debug, :none]
      return @quick_actions unless File.file?(quick_actions_config_path)
      begin
        lines = File.readlines(quick_actions_config_path).map(&:strip).reject { |l| l.empty? }
        if lines.length == 4
          @quick_actions = lines.map(&:to_sym)
        end
      rescue => e
        log_error("Load Quick Actions Config", e)
      end
      @quick_actions
    end

    def quick_actions
      if !defined?(@quick_actions) || @quick_actions.nil?
        load_quick_actions_config!
      end
      @quick_actions
    end

    def apply_no_battle_toggle_immediately!
      clear_battle_runtime_flags! if respond_to?(:clear_battle_runtime_flags!)
      ensure_runtime_patches! if respond_to?(:ensure_runtime_patches!)
      true
    rescue => e
      log_error("Apply No Battle Toggle Immediately", e)
      false
    end

    def toggle_no_wild_battles_action
      simple_menu_action(t(TR[:no_wild_battles])) do
        self.no_wild_battles = !no_wild_battles_active?
        apply_no_battle_toggle_immediately!
        Kernel.pbMessage(state_toggle_message("No Wild Battles", no_wild_battles_active?))
      end
    rescue => e
      log_error("Toggle No Wild Battles Action", e)
      simple_menu_action(t(TR[:no_wild_battles]))
    end

    def toggle_no_trainer_battles_action
      simple_menu_action(t(TR[:no_trainer_battles])) do
        self.skip_trainer_battles = !no_trainer_battles_active?
        apply_no_battle_toggle_immediately!
        Kernel.pbMessage(state_toggle_message("No Trainer Battles", no_trainer_battles_active?))
      end
    rescue => e
      log_error("Toggle No Trainer Battles Action", e)
      simple_menu_action(t(TR[:no_trainer_battles]))
    end

    def toggle_all_no_battles_action
      simple_menu_action(t(TR[:nobattles])) do
        next_state = !(no_wild_battles_active? && no_trainer_battles_active?)
        self.no_battles = next_state
        apply_no_battle_toggle_immediately!
        Kernel.pbMessage(state_toggle_message("No Battles", no_battles))
      end
    rescue => e
      log_error("Toggle All No Battles Action", e)
      simple_menu_action(t(TR[:nobattles]))
    end

    def quick_action_definitions
      actions = [
        { :id => :none, :label => t(TR[:empty_slot]), :action => proc { } },
        { :id => :heal_party, :label => t(TR[:heal_party_hotkey]), :action => proc { heal_party } },
        { :id => :toggle_no_battles, :label => t(TR[:nobattles]), :action => toggle_all_no_battles_action[:action] },
        { :id => :toggle_no_wild_battles, :label => t(TR[:no_wild_battles]), :action => toggle_no_wild_battles_action[:action] },
        { :id => :toggle_skip_trainer_battles, :label => t(TR[:no_trainer_battles]), :action => toggle_no_trainer_battles_action[:action] },
        { :id => :toggle_wtw, :label => t(TR[:wtw_hotkey]), :action => proc { toggle_wtw } },
        { :id => :compat_report, :label => t(TR[:compatibility_report]), :action => proc { show_compatibility_report } },
        { :id => :engine_report, :label => t(TR[:engine_compatibility_report]), :action => proc { show_engine_report } },
        { :id => :native_debug, :label => t(TR[:nativedebug]), :action => proc { open_native_debug_menu }, :available => proc { native_debug_menu_available? } },
        { :id => :open_pc, :label => t(TR[:openpc]), :action => proc { open_pc_menu }, :available => proc { open_pc_available? } },
        { :id => :refresh_map, :label => t(TR[:refresh_map_short]), :action => proc { engine_refresh_map if respond_to?(:engine_refresh_map) } }
      ]
      actions.select { |entry| !entry[:available] || entry[:available].call }
    end

    def find_quick_action(action_id)
      quick_action_definitions.find { |entry| entry[:id] == action_id }
    end

    def configure_quick_actions
      loop do
        cmds = quick_actions.each_with_index.map do |action_id, idx|
          action = find_quick_action(action_id)
          t(TR[:quick_action_slot], idx + 1, action ? action[:label] : "Unknown")
        end
        cmds.push(t(TR[:back]))
        slot = safe_menu_choice(t(TR[:configure_quick_actions]) + ":", cmds, -1, "Configure Quick Actions Slot")
        break if slot < 0 || slot >= quick_actions.length

        action_cmds = quick_action_definitions.map { |entry| entry[:label] }
        choice = safe_menu_choice(t(TR[:choose_action_slot], slot + 1), action_cmds, -1, "Configure Quick Actions Choice")
        next if choice < 0
        quick_actions[slot] = quick_action_definitions[choice][:id]
        write_quick_actions_config!
      end
    end

    def configure_hotkeys_menu
      load_hotkey_config!
      labels = {
        :menu => t(TR[:open_menu]),
        :walk_through_walls => t(TR[:wtw_hotkey]),
        :heal_party => t(TR[:heal_party_hotkey])
      }
      action_ids = [:menu, :walk_through_walls, :heal_party]
      loop do
        cmds = action_ids.map { |action_id| "#{labels[action_id]}: #{hotkey_name_for(action_id)}" }
        cmds << t(TR[:reset_to_default])
        cmds << t(TR[:show_current_hotkeys])
        cmds << t(TR[:back])
        choice = safe_menu_choice(t(TR[:configure_hotkeys]) + ":", cmds, -1, "Configure Hotkeys Menu")
        break if choice < 0 || choice == cmds.length - 1

        if choice == action_ids.length
          reset_hotkeys_to_default!
          safe_text_message(t(TR[:hotkeys_reset]), "Reset Hotkeys Message")
          next
        end

        if choice == action_ids.length + 1
          safe_text_message(hotkey_status_lines.join("\n"), "Hotkey Status Message")
          next
        end

        action_id = action_ids[choice]
        key_choice = safe_menu_choice(
          t(TR[:choose_hotkey_for], labels[action_id]),
          hotkey_choices,
          -1,
          "Choose Hotkey #{action_id}"
        )
        next if key_choice < 0
        hotkey_config[action_id] = hotkey_choices[key_choice]
        if write_hotkey_config!
          safe_text_message(_INTL("{1} hotkey set to {2}.", labels[action_id], hotkey_name_for(action_id)), "Hotkey Saved Message")
        else
          safe_text_message("Could not save hotkey settings.", "Hotkey Save Failure")
        end
      end
    rescue => e
      log_error("Configure Hotkeys", e)
      safe_text_message("Could not configure hotkey settings.", "Configure Hotkeys Failure")
      false
    end

    def run_quick_actions_menu
      menu = quick_actions.map do |action_id|
        action = find_quick_action(action_id)
        next nil if !action || action[:id] == :none
        { :label => action[:label], :action => action[:action] }
      end.compact
      if menu.empty?
        Kernel.pbMessage(_INTL("{1}", t(TR[:no_quick_actions])))
        return
      end
      render_dynamic_menu(t(TR[:quick_actions]), menu)
    end

    def extras_menu_entries
      entries = [
        translated_menu_action(:quick_actions) { run_quick_actions_menu },
        translated_menu_action(:configure_quick_actions) { configure_quick_actions },
        translated_menu_action(:battle_access_settings) { configure_battle_access_menu },
        translated_menu_action(:compatibility_report) { show_compatibility_report },
        translated_menu_action(:diagnostics_report) { show_diagnostics },
        translated_menu_action(:test_all) { run_test_all },
        translated_menu_action(:configure_hotkeys) { configure_hotkeys_menu },
        toggle_no_wild_battles_action,
        toggle_no_trainer_battles_action,
        toggle_runtime_flag_action(t(TR[:infmega]), :@inf_mega, "Infinite Mega"),
        translated_menu_action(:engine_compatibility_report) { show_engine_report },
        translated_menu_action(:mobile_open_help) { show_joiplay_help }
      ]
      entries << translated_menu_action(:nativedebug) {
          @menu_open = false
          unless open_native_debug_menu
            Kernel.pbMessage(_INTL("Native Debug Menu was removed by the game developer."))
          end
          @menu_open = true
        } if native_debug_menu_available?
      entries
    rescue => e
      log_error("Extras Menu Entries", e)
      []
    end

    def menu_extras
      render_dynamic_menu(t(TR[:extras]).upcase, extras_menu_entries)
    end
