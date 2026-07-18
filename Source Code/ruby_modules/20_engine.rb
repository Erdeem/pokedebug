    def menu_engine
      menu = [
        battle_menu_entry(:engine_quick_status, t(TR[:quick_status])) { show_engine_status },
        battle_menu_entry(:engine_warp, t(TR[:warp])) { engine_warp },
        battle_menu_entry(:engine_switches, t(TR[:switches])) { engine_switches },
        battle_menu_entry(:engine_variables, t(TR[:vars])) { engine_variables }
      ]
      
      in_safari = false
      if defined?(pbInSafari?)
        in_safari = pbInSafari?
      elsif $PokemonGlobal && $PokemonGlobal.respond_to?(:safariState) && $PokemonGlobal.safariState
        begin
          in_safari = $PokemonGlobal.safariState.inProgress?
        rescue => e
          log_error("Safari State", e)
          in_safari = false
        end
      end
      
      in_bug = false
      if defined?(pbInBugContest?)
        in_bug = pbInBugContest?
      end
      
      if in_safari || in_bug
        menu.push(battle_menu_entry(:engine_safari, t(TR[:safari])) { engine_safari })
      end

      menu.concat([
        battle_menu_entry(:engine_field_effects, t(TR[:Field])) { engine_field_effects },
        battle_menu_entry(:engine_map_events, t(TR[:map_event_tools])) { engine_map_events },
        battle_menu_entry(:engine_refresh_map, t(TR[:refresh])) { engine_refresh_map },
        battle_menu_entry(:engine_pbs_editors, t(TR[:pbs_editors])) { engine_pbs_editors },
        battle_menu_entry(:engine_skip_credits, t(TR[:skip_credits])) { engine_skip_credits },
        battle_menu_entry(:engine_runtime_debug, t(TR[:runtime_debug_toggle])) { engine_runtime_debug_toggle }
      ])
      menu << battle_menu_entry(:engine_daycare, t(TR[:daycare])) { engine_day_care } if day_care_available?
      menu << battle_menu_entry(:engine_wallpapers, t(TR[:Wallpapers])) { engine_wallpapers } if wallpapers_available?
      menu.concat([
        battle_menu_entry(:engine_test_battle, t(TR[:Battle])) { engine_test_battle },
        battle_menu_entry(:engine_test_battle_advanced, t(TR[:battle_advanced])) { engine_test_battle_advanced },
        battle_menu_entry(:engine_test_trainer_battle, t(TR[:test_trainer_battle])) { engine_test_trainer_battle },
        battle_menu_entry(:engine_test_trainer_battle_advanced, t(TR[:test_trainer_battle_advanced])) { engine_test_trainer_battle_advanced },
        battle_menu_entry(:engine_encounter_version, t(TR[:encounter_version])) { engine_encounter_version },
        battle_menu_entry(:engine_roamers, t(TR[:roaming_pokemon])) { engine_roamers },
        battle_menu_entry(:engine_reset_trainers, t(TR[:reset_map_trainers])) { engine_reset_trainers },
        battle_menu_entry(:engine_exp_all, t(TR[:expall])) { engine_exp_all },
        battle_menu_entry(:engine_battle_logging, t(TR[:battle_logging])) { engine_battle_logging },
        battle_menu_entry(:engine_wtw, t(TR[:wtw])) { toggle_wtw }
      ])
      menu << battle_menu_entry(:engine_open_pc, t(TR[:openpc])) { open_pc_menu } if open_pc_available?
      profile = cached_engine_profile
      render_dynamic_menu(_INTL("{1} | {2}", t(TR[:engine]).upcase, profile[:engine_family] || (profile[:modern_engine] ? "Modern/Hybrid" : "Legacy")), menu)
    end

    def engine_warp
      mapinfos = get_map_infos
      return Kernel.pbMessage(_INTL("MapInfos.rxdata not found!")) unless mapinfos

      destination = nil
      map_id = nil
      map_name = nil

      if defined?(MapLister) && respond_to?(:select_from_native_lister)
        lister = MapLister.new(defined?(pbDefaultMap) ? pbDefaultMap : 0)
        map_id = select_from_native_lister(_INTL("WARP TO MAP"), lister)
        return if !map_id || map_id.to_i <= 0
        map_id = map_id.to_i
        map_name = map_name_from_id(map_id, mapinfos)
        destination = build_original_style_warp_destination(map_id)
      elsif defined?(select_map_with_preview) && defined?(MapLister)
        map_id = select_map_with_preview(defined?(pbDefaultMap) ? pbDefaultMap : 0, _INTL("WARP TO MAP"))
        return if !map_id || map_id.to_i <= 0
        map_id = map_id.to_i
        map_name = map_name_from_id(map_id, mapinfos)
        destination = build_original_style_warp_destination(map_id)
      elsif defined?(pbWarpToMap)
        destination = pbWarpToMap
        return if !destination || !destination.is_a?(Array) || destination.length < 3
        map_id = destination[0].to_i
        map_name = map_name_from_id(map_id, mapinfos)
      elsif defined?(pbListScreen) && defined?(MapLister)
        map_id = pbListScreen(_INTL("WARP TO MAP"), MapLister.new(defined?(pbDefaultMap) ? pbDefaultMap : 0))
        return if !map_id || map_id.to_i <= 0
        map_id = map_id.to_i
        map_name = map_name_from_id(map_id, mapinfos)
        destination = build_original_style_warp_destination(map_id)
      else
        hash = {}
        mapinfos.keys.sort.each { |id| hash[id] = mapinfos[id].name }
        map_id = search_list("Maps", hash)
        return if !map_id || (map_id.is_a?(Numeric) && map_id <= 0) || (map_id.is_a?(String) && map_id.to_s.strip.empty?)
        map_name = map_name_from_id(map_id, mapinfos)
        return unless show_map_preview_prompt(map_id, map_name)
        destination = build_original_style_warp_destination(map_id)
      end

      return Kernel.pbMessage(engine_failure_message("build a valid warp destination")) unless destination

      warped = false
      if defined?(pbFadeOutAndHide) && defined?(pbDisposeMessageWindow) && defined?(pbDisposeSpriteHash)
        warped = perform_original_style_warp(destination)
      elsif defined?(pbFadeOutIn)
        pbFadeOutIn(99999) { warped = perform_original_style_warp(destination) }
      else
        warped = perform_original_style_warp(destination)
      end
      if warped
        Kernel.pbMessage(_INTL("Warped to {1} ({2}).", map_name, map_id))
      else
        Kernel.pbMessage(engine_failure_message("warp"))
      end
    end

    def engine_switches
      hash = complete_engine_state_entries(:switches, :Switches)
      return if hash.empty?
      id = select_engine_state_entry("SWITCHES", hash)
      return if !id || (id.is_a?(Numeric) && id <= 0) || (id.is_a?(String) && id.to_s.strip.empty?)
      current = $game_switches[id]
      ch = Kernel.pbMessage(_INTL("Switch {1} ({2}): {3}", id, hash[id], current ? "ON" : "OFF"), ["ON", "OFF", menu_back_label], -1)
      if ch >= 0 && ch < 2
        if set_game_switch!(id, ch == 0)
          Kernel.pbMessage(state_toggle_message("Switch #{id}", ch == 0))
        else
          Kernel.pbMessage(engine_failure_message("edit that switch"))
        end
      end
    end

    def engine_variables
      hash = complete_engine_state_entries(:variables, :Variables)
      return if hash.empty?
      id = select_engine_state_entry("VARIABLES", hash)
      return if !id || (id.is_a?(Numeric) && id <= 0) || (id.is_a?(String) && id.to_s.strip.empty?)
      current = $game_variables[id] || 0
      params = ChooseNumberParams.new
      params.setRange(-999999, 999999); params.setInitialValue(current)
      new_value = Kernel.pbMessageChooseNumber(_INTL("Var {1} ({2}) = {3}. New:", id, hash[id], current), params)
      if set_game_variable!(id, new_value)
        Kernel.pbMessage(_INTL("Variable {1} was set to {2}.", id, new_value))
      else
        Kernel.pbMessage(engine_failure_message("edit that variable"))
      end
    end

    # Build a union of the RPG system names, symbolic aliases used by custom
    # engines and already-used save slots. Rejuvenation, for example, defines
    # Switches/Variables entries beyond the last name exposed by its native
    # debug editor.
    def complete_engine_state_entries(system_reader, aliases_constant)
      entries = {}
      sys = get_system_data
      if sys && sys.respond_to?(system_reader)
        values = sys.send(system_reader)
        values.each_with_index do |name, id|
          entries[id] = name.to_s if id > 0 && name && name.to_s != ""
        end
      end

      aliases = safe_const_get(Object, aliases_constant)
      if aliases && aliases.respond_to?(:each)
        aliases_by_id = {}
        aliases.each do |name, id|
          next unless id.is_a?(Numeric) && id > 0
          aliases_by_id[id] ||= []
          aliases_by_id[id] << name.to_s unless aliases_by_id[id].include?(name.to_s)
        end
        aliases_by_id.each do |id, names|
          # RXsystem names are the labels players see in events and remain
          # authoritative. Symbolic aliases only fill otherwise missing IDs,
          # avoiding long duplicated labels such as "Name [Alias1, Alias2]".
          entries[id] = names.first if (!entries[id] || entries[id] == "") && !names.empty?
        end
      end

      state = system_reader == :switches ? (defined?($game_switches) ? $game_switches : nil) : (defined?($game_variables) ? $game_variables : nil)
      if state
        data = state.instance_variable_get(:@data) rescue nil
        if data && data.respond_to?(:each_with_index)
          data.each_with_index do |value, id|
            next if id <= 0 || value.nil?
            entries[id] ||= _INTL("(unnamed, used in save)")
          end
        end
      end
      entries
    rescue => e
      log_error("Complete Engine State Entries #{system_reader}", e)
      {}
    end

    def select_engine_state_entry(title, entries)
      # Rejuvenation uses the modal search path. Pokemon Z has a stable native
      # list, but its pbListScreen accepts two arguments rather than three.
      return search_list(title, entries) if rejuvenation_engine?
      pokemon_z_list = respond_to?(:pokemon_z_engine?) && pokemon_z_engine?
      return search_list(title, entries) unless defined?(pbListScreen)
      lister_class = Class.new do
        def initialize(values)
          @values = values
          @ids = values.keys.sort
          width = [4, @ids.empty? ? 1 : @ids[-1].to_i.to_s.length].max
          @commands = @ids.map { |id| sprintf("%0#{width}d: %s", id, @values[id].to_s) }
        end

        def commands
          @commands
        end

        def startIndex
          0
        end

        def value(index)
          return nil if index.nil? || index < 0 || index >= @ids.length
          @ids[index]
        end

        def setViewport(_viewport)
        end

        def refresh(_index)
        end

        def dispose
        end
      end
      lister = lister_class.new(entries)
      return pbListScreen(title, lister) if pokemon_z_list
      pbListScreen(title, lister, Graphics.width * 2 / 3)
    rescue => e
      log_error("Select Engine State Entry #{title}", e)
      search_list(title, entries)
    end

    def engine_safari
      if defined?(pbInSafari?) && pbInSafari? && defined?(pbSafariState)
        safari = pbSafariState
        cmd = 0
        loop do
          cmds = [
            _INTL("Steps remaining: {1}", (defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:SAFARI_STEPS) && Settings::SAFARI_STEPS > 0) ? safari.steps : _INTL("infinite")),
            safe_item_name(:SAFARIBALL, true) + ": " + safari.ballcount.to_s
          ]
          cmd = pbShowCommands(nil, cmds, -1, cmd)
          break if cmd < 0
          case cmd
          when 0
            if defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:SAFARI_STEPS) && Settings::SAFARI_STEPS > 0
              params = ChooseNumberParams.new
              params.setRange(0, 99999)
              params.setDefaultValue(safari.steps) if params.respond_to?(:setDefaultValue)
              params.setInitialValue(safari.steps) if params.respond_to?(:setInitialValue)
              safari.steps = pbMessageChooseNumber(_INTL("Set the steps remaining in this Safari game."), params)
            end
          when 1
            params = ChooseNumberParams.new
            params.setRange(0, 99999)
            params.setDefaultValue(safari.ballcount) if params.respond_to?(:setDefaultValue)
            params.setInitialValue(safari.ballcount) if params.respond_to?(:setInitialValue)
            safari.ballcount = pbMessageChooseNumber(_INTL("Set the quantity of {1}.", safe_item_name(:SAFARIBALL, true)), params)
          end
        end
        return
      end

      if defined?(pbInBugContest?) && pbInBugContest? && defined?(pbBugContestState)
        contest = pbBugContestState
        cmd = 0
        loop do
          cmds = []
          if defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:BUG_CONTEST_TIME) && Settings::BUG_CONTEST_TIME > 0
            time_left = Settings::BUG_CONTEST_TIME - (System.uptime - contest.timer_start).to_i
            time_left = 0 if time_left < 0
            min = time_left / 60
            sec = time_left % 60
            time_string = _ISPRINTF("{1:02d}m {2:02d}s", min, sec)
          else
            min = 0
            time_string = _INTL("infinite")
          end
          cmds.push(_INTL("Time remaining: {1}", time_string))
          cmds.push(safe_item_name(:SPORTBALL, true) + ": " + contest.ballcount.to_s)
          cmd = pbShowCommands(nil, cmds, -1, cmd)
          break if cmd < 0
          case cmd
          when 0
            if defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:BUG_CONTEST_TIME) && Settings::BUG_CONTEST_TIME > 0
              params = ChooseNumberParams.new
              params.setRange(0, 99999)
              params.setDefaultValue(min) if params.respond_to?(:setDefaultValue)
              params.setInitialValue(min) if params.respond_to?(:setInitialValue)
              new_time = pbMessageChooseNumber(_INTL("Set the time remaining (in minutes) in this Bug-Catching Contest."), params)
              contest.timer_start += (new_time - min) * 60
            end
          when 1
            params = ChooseNumberParams.new
            params.setRange(0, 99999)
            params.setDefaultValue(contest.ballcount) if params.respond_to?(:setDefaultValue)
            params.setInitialValue(contest.ballcount) if params.respond_to?(:setInitialValue)
            contest.ballcount = pbMessageChooseNumber(_INTL("Set the quantity of {1}.", safe_item_name(:SPORTBALL, true)), params)
          end
        end
        return
      end

      Kernel.pbMessage(_INTL("You aren't in the Safari Zone or a Bug-Catching Contest!"))
    end

    def engine_field_effects
      cmd = 0
      loop do
        lower_rate = !!get_map_toggle(:lower_encounter_rate)
        higher_rate = !!get_map_toggle(:higher_encounter_rate)
        lower_level = !!get_map_toggle(:lower_level_wild_pokemon)
        higher_level = !!get_map_toggle(:higher_level_wild_pokemon)
        cmds = []
        cmds.push(_INTL("Repel steps: {1}", get_repel_steps || 0))
        cmds.push((strength_enabled? ? "[Y]" : "[  ]") + " " + _INTL("Strength used"))
        cmds.push((flash_enabled? ? "[Y]" : "[  ]") + " " + _INTL("Flash used"))
        cmds.push((lower_rate ? "[Y]" : "[  ]") + " " + _INTL("Lower encounter rate"))
        cmds.push((higher_rate ? "[Y]" : "[  ]") + " " + _INTL("Higher encounter rate"))
        cmds.push((lower_level ? "[Y]" : "[  ]") + " " + _INTL("Lower level wild Pokemon"))
        cmds.push((higher_level ? "[Y]" : "[  ]") + " " + _INTL("Higher level wild Pokemon"))
        cmd = pbShowCommands(nil, cmds, -1, cmd)
        break if cmd < 0
        case cmd
        when 0
          params = ChooseNumberParams.new
          params.setRange(0, 99999)
          current = get_repel_steps || 0
          params.setDefaultValue(current) if params.respond_to?(:setDefaultValue)
          params.setInitialValue(current) if params.respond_to?(:setInitialValue)
          set_repel_steps(pbMessageChooseNumber(_INTL("Set the Pokemon's level."), params))
        when 1
          set_strength_enabled!(!strength_enabled?)
        when 2
          if defined?($game_map) && $game_map && $game_map.respond_to?(:metadata) && $game_map.metadata && $game_map.metadata.respond_to?(:dark_map) && $game_map.metadata.dark_map && defined?($scene) && $scene && $scene.is_a?(Scene_Map)
            set_flash_enabled!(!flash_enabled?)
          else
            pbMessage(_INTL("You're not in a dark map!"))
          end
        when 3
          current = get_map_toggle(:lower_encounter_rate)
          set_map_toggle(!current, :lower_encounter_rate)
        when 4
          current = get_map_toggle(:higher_encounter_rate)
          set_map_toggle(!current, :higher_encounter_rate)
        when 5
          current = get_map_toggle(:lower_level_wild_pokemon)
          set_map_toggle(!current, :lower_level_wild_pokemon)
        when 6
          current = get_map_toggle(:higher_level_wild_pokemon)
          set_map_toggle(!current, :higher_level_wild_pokemon)
        end
      end
    end

    def engine_refresh_map
      if defined?($game_map) && $game_map && $game_map.events
        $game_map.events.values.each do |e|
          e.refresh if e.respond_to?(:refresh)
        end
      end
      if mark_map_for_refresh!
        Kernel.pbMessage(_INTL("The map was refreshed."))
      else
        Kernel.pbMessage(engine_failure_message("refresh the map"))
      end
    end

    def engine_runtime_debug_toggle
      current = false
      begin
        current = !!$DEBUG
      rescue
        current = false
      end
      begin
        $DEBUG = !current
        Kernel.pbMessage(state_toggle_message("Debug Mode", !!$DEBUG))
      rescue => e
        log_error("Runtime Debug Toggle", e)
        Kernel.pbMessage(engine_failure_message("toggle runtime debug"))
      end
    end

    def run_pbs_editor(label)
      result = yield
      return true if result != false
      Kernel.pbMessage(engine_failure_message(label))
      false
    rescue => e
      log_error("PBS Editor #{label}", e)
      Kernel.pbMessage(engine_failure_message(label))
      false
    end

    def engine_pbs_editors
      menu = []
      menu << battle_menu_entry(:pbs_map_connections, t(TR[:pbs_map_connections])) {
        run_pbs_editor("open map connections editor") do
          if defined?(pbFadeOutIn) && defined?(pbConnectionsEditor)
            pbFadeOutIn { pbConnectionsEditor }
          elsif defined?(pbConnectionsEditor)
            pbConnectionsEditor
          else
            false
          end
        end
      } if defined?(pbConnectionsEditor)
      menu << battle_menu_entry(:pbs_encounters, t(TR[:pbs_encounters])) {
        run_pbs_editor("open encounters editor") do
          if defined?(pbFadeOutIn) && defined?(pbEncountersEditor)
            pbFadeOutIn { pbEncountersEditor }
          elsif defined?(pbEncountersEditor)
            pbEncountersEditor
          else
            false
          end
        end
      } if defined?(pbEncountersEditor)
      menu << battle_menu_entry(:pbs_trainers, t(TR[:pbs_trainers])) {
        run_pbs_editor("open trainers editor") do
          if defined?(pbFadeOutIn) && defined?(pbTrainerBattleEditor)
            pbFadeOutIn { pbTrainerBattleEditor }
          elsif defined?(pbTrainerBattleEditor)
            pbTrainerBattleEditor
          else
            false
          end
        end
      } if defined?(pbTrainerBattleEditor)
      menu << battle_menu_entry(:pbs_trainer_types, t(TR[:pbs_trainer_types])) {
        run_pbs_editor("open trainer types editor") do
          if defined?(pbFadeOutIn) && defined?(pbTrainerTypeEditor)
            pbFadeOutIn { pbTrainerTypeEditor }
          elsif defined?(pbTrainerTypeEditor)
            pbTrainerTypeEditor
          else
            false
          end
        end
      } if defined?(pbTrainerTypeEditor)
      menu << battle_menu_entry(:pbs_map_metadata, t(TR[:pbs_map_metadata])) {
        run_pbs_editor("open map metadata editor") do
          if defined?(pbMapMetadataScreen)
            pbMapMetadataScreen(defined?(pbDefaultMap) ? pbDefaultMap : 0)
          else
            false
          end
        end
      } if defined?(pbMapMetadataScreen)
      menu << battle_menu_entry(:pbs_metadata, t(TR[:pbs_metadata])) {
        run_pbs_editor("open metadata editor") do
          defined?(pbMetadataScreen) ? pbMetadataScreen : false
        end
      } if defined?(pbMetadataScreen)
      menu << battle_menu_entry(:pbs_items, t(TR[:pbs_items])) {
        run_pbs_editor("open item editor") do
          if defined?(pbFadeOutIn) && defined?(pbItemEditor)
            pbFadeOutIn { pbItemEditor }
          elsif defined?(pbItemEditor)
            pbItemEditor
          else
            false
          end
        end
      } if defined?(pbItemEditor)
      menu << battle_menu_entry(:pbs_species, t(TR[:pbs_species])) {
        run_pbs_editor("open species editor") do
          if defined?(pbFadeOutIn) && defined?(pbPokemonEditor)
            pbFadeOutIn { pbPokemonEditor }
          elsif defined?(pbPokemonEditor)
            pbPokemonEditor
          else
            false
          end
        end
      } if defined?(pbPokemonEditor)
      menu << battle_menu_entry(:pbs_regional_dexes, t(TR[:pbs_regional_dexes])) {
        run_pbs_editor("open regional dex editor") do
          if defined?(pbFadeOutIn) && defined?(pbRegionalDexEditorMain)
            pbFadeOutIn { pbRegionalDexEditorMain }
          elsif defined?(pbRegionalDexEditorMain)
            pbRegionalDexEditorMain
          else
            false
          end
        end
      } if defined?(pbRegionalDexEditorMain)
      return Kernel.pbMessage(_INTL("No PBS editors are available on this version.")) if menu.empty?
      render_dynamic_menu(t(TR[:pbs_editors]), menu)
    end

    def engine_skip_credits
      return Kernel.pbMessage(unsupported_feature_message("Skip credits")) unless defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:creditsPlayed) && $PokemonGlobal.respond_to?(:creditsPlayed=)
      $PokemonGlobal.creditsPlayed = !$PokemonGlobal.creditsPlayed
      if $PokemonGlobal.creditsPlayed
        pbMessage(_INTL("Credits can be skipped when played in future."))
      else
        pbMessage(_INTL("Credits cannot be skipped when next played."))
      end
    rescue => e
      log_error("Engine Skip Credits", e)
      Kernel.pbMessage(engine_failure_message("toggle credits skip"))
    end

    def engine_map_events
      menu = [
        { :label => _INTL("Current map summary"), :action => proc {
          show_current_map_summary
        }},
        { :label => _INTL("Export current map events"), :action => proc {
          if export_current_map_events
            Kernel.pbMessage(_INTL("Saved the current map event list to PokeDebug_Current_Map_Events.txt."))
          else
            Kernel.pbMessage(_INTL("No events found on the current map."))
          end
        }},
        { :label => _INTL("Warp to event"), :action => proc {
          event = choose_current_map_event
          if event && teleport_to_event(event)
            Kernel.pbMessage(_INTL("Warped to {1}.", event_display_name(event)))
          elsif event
            Kernel.pbMessage(engine_failure_message("teleport to that event"))
          end
        }},
        { :label => _INTL("Refresh event"), :action => proc {
          event = choose_current_map_event
          if event && refresh_event(event)
            Kernel.pbMessage(_INTL("Refreshed {1}.", event_display_name(event)))
          elsif event
            Kernel.pbMessage(engine_failure_message("refresh that event"))
          end
        }}
      ]
      render_dynamic_menu(t(TR[:map_event_tools]), menu)
    end

    def engine_day_care
      if defined?(pbDebugDayCare)
        return pbDebugDayCare
      end
      dc = get_day_care_data
      
      status = _INTL("Day Care")
      if dc
        first_pokemon = day_care_first_pokemon(dc)
        if first_pokemon
          status = _INTL("Day Care: {1} (Lv.{2})", pokemon_species_name(first_pokemon), pokemon_level_value(first_pokemon))
        else
          status = _INTL("Day Care: Empty")
        end
      else
        status = _INTL("Day Care: Unavailable")
      end

      menu = [
        { :label => _INTL("Deposit Pokemon"), :action => proc {
          if day_care_first_pokemon(dc)
            Kernel.pbMessage(_INTL("The first day care slot is already occupied. Withdraw it first."))
          else
            choose_pokemon_with_callback do |pkmn|
              if day_care_deposit_first(pkmn, dc)
                remove_party_member(pkmn)
                Kernel.pbMessage(_INTL("{1} was deposited in the Day Care.", pkmn.name))
              else
                Kernel.pbMessage(engine_failure_message("deposit this Pokemon"))
              end
            end
          end
        }},
        { :label => _INTL("Force Egg"), :action => proc {
          if day_care_force_egg(dc)
            Kernel.pbMessage(_INTL("An egg was generated in the Day Care."))
          else
            Kernel.pbMessage(engine_failure_message("force a day care egg"))
          end
        }},
        { :label => _INTL("Withdraw first deposited Pokemon"), :action => proc {
          pkmn = day_care_withdraw_first(dc)
          if pkmn
            if add_pkmn_silently(pkmn)
              Kernel.pbMessage(_INTL("{1} was withdrawn from the Day Care.", pkmn.name))
            else
              day_care_deposit_first(pkmn, dc)
              Kernel.pbMessage(_INTL("Could not withdraw because the party is full or this engine does not support it."))
            end
          else
            Kernel.pbMessage(_INTL("No Pokemon in first slot."))
          end
        }}
      ]
      render_dynamic_menu(status, menu)
    end

    def engine_wallpapers
      return Kernel.pbMessage(unsupported_feature_message("PC Wallpapers")) unless defined?($PokemonStorage) && $PokemonStorage
      wallpapers = $PokemonStorage.respond_to?(:allWallpapers) ? $PokemonStorage.allWallpapers : nil
      basic_qty = (defined?(PokemonStorage) && PokemonStorage.const_defined?(:BASICWALLPAPERQTY)) ? PokemonStorage::BASICWALLPAPERQTY : 0
      if !wallpapers || wallpapers.length <= basic_qty
        return Kernel.pbMessage(_INTL("There are no special wallpapers defined."))
      end
      paperscmd = 0
      unlockarray = $PokemonStorage.respond_to?(:unlockedWallpapers) ? $PokemonStorage.unlockedWallpapers : nil
      return Kernel.pbMessage(unsupported_feature_message("PC Wallpapers")) unless unlockarray
      loop do
        paperscmds = []
        paperscmds.push(_INTL("Unlock all"))
        paperscmds.push(_INTL("Lock all"))
        (basic_qty...wallpapers.length).each do |i|
          paperscmds.push((unlockarray[i] ? "[Y]" : "[  ]") + " " + wallpapers[i].to_s)
        end
        paperscmd = pbShowCommands(nil, paperscmds, -1, paperscmd)
        break if paperscmd < 0
        case paperscmd
        when 0
          (basic_qty...wallpapers.length).each { |i| unlockarray[i] = true }
        when 1
          (basic_qty...wallpapers.length).each { |i| unlockarray[i] = false }
        else
          paperindex = paperscmd - 2 + basic_qty
          unlockarray[paperindex] = !unlockarray[paperindex]
        end
      end
    end

    def engine_test_battle
      hash = build_search_hash(:Species)
      species_id = search_list("Species", hash)
      return if !species_id || (species_id.is_a?(Numeric) && species_id <= 0) || (species_id.is_a?(String) && species_id.to_s.strip.empty?)
      sp_sym = get_symbol(:Species, species_id)
      species_name = hash[species_id] || safe_display_name(sp_sym, sp_sym)
      level = choose_debug_level(_INTL("Set the wild {1}'s level.", species_name), 5)
      return if level.to_i <= 0

      pkmn = create_pkmn(sp_sym, level)
      recalc_pokemon_stats(pkmn) if pkmn
      $game_temp.encounter_type = nil if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:encounter_type=)
      setBattleRule("canLose") if defined?(setBattleRule)
      result = start_test_battle(pkmn, sp_sym, level)
      if result.nil?
        Kernel.pbMessage(_INTL("Battle failed. API mismatch."))
      else
        Kernel.pbMessage(_INTL("Started the test battle."))
      end
    end

    def engine_test_trainer_battle
      trainerdata = choose_original_trainer_battle_data
      trainer_type = nil
      trainer_name = nil
      version = 0
      if trainerdata
        trainer_type = trainerdata[0]
        trainer_name = trainerdata[1]
        version = trainerdata[2] || 0
      else
        hash = build_search_hash(:TrainerType)
        return Kernel.pbMessage(_INTL("Trainer battle API not supported on this version.")) if hash.empty?
        trainer_type_id = search_list("Trainer Types", hash)
        return if !trainer_type_id || (trainer_type_id.is_a?(Numeric) && trainer_type_id <= 0) || (trainer_type_id.is_a?(String) && trainer_type_id.to_s.strip.empty?)
        trainer_type = get_symbol(:TrainerType, trainer_type_id)
        trainer_name = safe_free_text("Trainer name:", "TRAINER", false, 32, "Trainer Name")
        return if trainer_name.nil? || trainer_name == ""
        params = ChooseNumberParams.new
        params.setRange(0, 99)
        params.setInitialValue(0)
        version = Kernel.pbMessageChooseNumber(_INTL("Trainer party/version ID:"), params)
      end

      setBattleRule("canLose") if defined?(setBattleRule)
      result = start_test_trainer_battle(trainer_type, trainer_name, version)
      if result.nil?
        Kernel.pbMessage(_INTL("Trainer battle failed. API mismatch."))
      else
        Kernel.pbMessage(_INTL("Started the trainer battle."))
      end
    end

    def engine_test_battle_advanced
      pkmn = []
      size0 = 1
      pkmn_cmd = 0
      loop do
        pkmn_cmds = []
        pkmn.each { |entry| pkmn_cmds.push(sprintf("%s Lv.%d", entry.name, entry.level)) }
        pkmn_cmds.push(_INTL("[Add Pokemon]"))
        pkmn_cmds.push(_INTL("[Set player side size]"))
        pkmn_cmds.push(_INTL("[Start {1}v{2} battle]", size0, pkmn.length))
        pkmn_cmd = pbShowCommands(nil, pkmn_cmds, -1, pkmn_cmd)
        break if pkmn_cmd < 0
        if pkmn_cmd == pkmn_cmds.length - 1
          if pkmn.length == 0
            pbMessage(_INTL("No Pokemon were chosen, cannot start battle."))
            next
          end
          setBattleRule(sprintf("%dv%d", size0, pkmn.length)) if defined?(setBattleRule)
          setBattleRule("canLose") if defined?(setBattleRule)
          $game_temp.encounter_type = nil if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:encounter_type=)
          WildBattle.start(*pkmn)
          break
        elsif pkmn_cmd == pkmn_cmds.length - 2
          if defined?(pbCanDoubleBattle?) && !pbCanDoubleBattle?
            pbMessage(_INTL("You only have one Pokemon."))
            next
          end
          max_val = (defined?(pbCanTripleBattle?) && pbCanTripleBattle?) ? 3 : 2
          params = ChooseNumberParams.new
          params.setRange(1, max_val)
          params.setInitialValue(size0)
          params.setCancelValue(0) if params.respond_to?(:setCancelValue)
          new_size = pbMessageChooseNumber(_INTL("Choose the number of battlers on the player's side (max. {1}).", max_val), params)
          size0 = new_size if new_size > 0
        elsif pkmn_cmd == pkmn_cmds.length - 3
          hash = build_search_hash(:Species)
          species_id = search_list("Species", hash)
          next if !species_id || (species_id.is_a?(Numeric) && species_id <= 0) || (species_id.is_a?(String) && species_id.to_s.strip.empty?)
          sp_sym = get_symbol(:Species, species_id)
          species_name = hash[species_id] || safe_display_name(sp_sym, sp_sym)
          level = choose_debug_level(_INTL("Set the wild {1}'s level.", species_name), 5)
          next if level <= 0
          new_pkmn = create_pkmn(sp_sym, level)
          next unless new_pkmn
          recalc_pokemon_stats(new_pkmn)
          pkmn.push(new_pkmn)
          size0 = pkmn.length
        else
          if pbConfirmMessage(_INTL("Delete this Pokemon?"))
            pkmn.delete_at(pkmn_cmd)
            size0 = [pkmn.length, 1].max
          end
        end
      end
    rescue => e
      log_error("Engine Test Battle Advanced", e)
      Kernel.pbMessage(engine_failure_message("start advanced wild battle"))
    end

    def engine_test_trainer_battle_advanced
      trainers = []
      size0 = 1
      size1 = 1
      trainer_cmd = 0
      loop do
        trainer_cmds = []
        trainers.each { |entry| trainer_cmds.push(sprintf("%s x%d", entry[1].respond_to?(:full_name) ? entry[1].full_name : entry[1].name, entry[1].respond_to?(:party_count) ? entry[1].party_count : Array(entry[1].party).length)) }
        trainer_cmds.push(_INTL("[Add trainer]"))
        trainer_cmds.push(_INTL("[Set player side size]"))
        trainer_cmds.push(_INTL("[Set opponent side size]"))
        trainer_cmds.push(_INTL("[Start {1}v{2} battle]", size0, size1))
        trainer_cmd = pbShowCommands(nil, trainer_cmds, -1, trainer_cmd)
        break if trainer_cmd < 0
        if trainer_cmd == trainer_cmds.length - 1
          if trainers.length == 0
            pbMessage(_INTL("No trainers were chosen, cannot start battle."))
            next
          elsif size1 < trainers.length
            pbMessage(_INTL("Opposing side size is invalid. It should be at least {1}.", trainers.length))
            next
          end
          setBattleRule(sprintf("%dv%d", size0, size1)) if defined?(setBattleRule)
          setBattleRule("canLose") if defined?(setBattleRule)
          battle_args = []
          trainers.each { |entry| battle_args.push(entry[1]) }
          TrainerBattle.start(*battle_args)
          break
        elsif trainer_cmd == trainer_cmds.length - 2
          if trainers.length == 0
            pbMessage(_INTL("No trainers were chosen or trainer only has one Pokemon."))
            next
          end
          max_val = 2
          max_val = 3 if trainers.length >= 3
          params = ChooseNumberParams.new
          params.setRange(1, max_val)
          params.setInitialValue(size1)
          params.setCancelValue(0) if params.respond_to?(:setCancelValue)
          new_size = pbMessageChooseNumber(_INTL("Choose the number of battlers on the opponent's side (max. {1}).", max_val), params)
          size1 = new_size if new_size > 0
        elsif trainer_cmd == trainer_cmds.length - 3
          if defined?(pbCanDoubleBattle?) && !pbCanDoubleBattle?
            pbMessage(_INTL("You only have one Pokemon."))
            next
          end
          max_val = (defined?(pbCanTripleBattle?) && pbCanTripleBattle?) ? 3 : 2
          params = ChooseNumberParams.new
          params.setRange(1, max_val)
          params.setInitialValue(size0)
          params.setCancelValue(0) if params.respond_to?(:setCancelValue)
          new_size = pbMessageChooseNumber(_INTL("Choose the number of battlers on the player's side (max. {1}).", max_val), params)
          size0 = new_size if new_size > 0
        elsif trainer_cmd == trainer_cmds.length - 4
          trainerdata = choose_original_trainer_battle_data
          if trainerdata && defined?(pbLoadTrainer)
            tr = pbLoadTrainer(trainerdata[0], trainerdata[1], trainerdata[2])
            EventHandlers.trigger(:on_trainer_load, tr) if defined?(EventHandlers)
            trainers.push([0, tr]) if tr
            size0 = trainers.length
            size1 = trainers.length
          end
        else
          if pbConfirmMessage(_INTL("Delete this trainer?"))
            trainers.delete_at(trainer_cmd)
            size0 = [trainers.length, 1].max
            size1 = [trainers.length, 1].max
          end
        end
      end
    rescue => e
      log_error("Engine Test Trainer Battle Advanced", e)
      Kernel.pbMessage(engine_failure_message("start advanced trainer battle"))
    end

    def engine_exp_all
      target_state = !exp_all_enabled?
      if set_exp_all_enabled!(target_state)
        if exp_all_enabled?
          Kernel.pbMessage(_INTL("Enabled Exp. All's effect."))
        else
          Kernel.pbMessage(_INTL("Disabled Exp. All's effect."))
        end
      else
        Kernel.pbMessage(engine_failure_message("toggle Exp All"))
      end
    end

    def engine_encounter_version
      return Kernel.pbMessage(unsupported_feature_message("Wild encounters version")) unless defined?($PokemonGlobal) && $PokemonGlobal
      params = ChooseNumberParams.new
      params.setRange(0, 99)
      current_value = $PokemonGlobal.respond_to?(:encounter_version) ? $PokemonGlobal.encounter_version.to_i : 0
      params.setInitialValue(current_value)
      params.setCancelValue(-1) if params.respond_to?(:setCancelValue)
      value = pbMessageChooseNumber(_INTL("Set encounters version to which value?"), params)
      if value >= 0
        if $PokemonGlobal.respond_to?(:encounter_version=)
          $PokemonGlobal.encounter_version = value
          Kernel.pbMessage(_INTL("Encounter version set to {1}.", value))
        else
          Kernel.pbMessage(unsupported_feature_message("Wild encounters version"))
        end
      end
    rescue => e
      log_error("Engine Encounter Version", e)
      Kernel.pbMessage(engine_failure_message("change encounter version"))
    end

    def engine_roamers
      if defined?(pbDebugRoamers)
        pbDebugRoamers
      else
        Kernel.pbMessage(unsupported_feature_message("Roaming Pokemon"))
      end
    rescue => e
      log_error("Engine Roamers", e)
      Kernel.pbMessage(engine_failure_message("open roaming Pokemon editor"))
    end

    def engine_reset_trainers
      if defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
        $game_map.events.each_value do |event|
          next unless event && event.respond_to?(:name)
          if event.name[/trainer/i]
            $game_self_switches[[$game_map.map_id, event.id, "A"]] = false if defined?($game_self_switches)
            $game_self_switches[[$game_map.map_id, event.id, "B"]] = false if defined?($game_self_switches)
          end
        end
        $game_map.need_refresh = true if $game_map.respond_to?(:need_refresh=)
        Kernel.pbMessage(_INTL("All Trainers on this map were reset."))
      else
        Kernel.pbMessage(_INTL("This command can't be used here."))
      end
    rescue => e
      log_error("Engine Reset Trainers", e)
      Kernel.pbMessage(engine_failure_message("reset trainers on this map"))
    end

    def engine_battle_logging
      begin
        $INTERNAL = !$INTERNAL
        if $INTERNAL
          Kernel.pbMessage(_INTL("Debug logs for battles will be made in the Data folder."))
        else
          Kernel.pbMessage(_INTL("Debug logs for battles will not be made."))
        end
      rescue => e
        log_error("Engine Battle Logging", e)
        Kernel.pbMessage(engine_failure_message("toggle battle logging"))
      end
    end
