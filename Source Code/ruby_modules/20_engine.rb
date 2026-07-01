    def menu_engine
      menu = [
        { :label => "Quick Status", :action => proc { show_engine_status } },
        { :label => t(TR[:warp]), :action => proc { engine_warp } },
        { :label => t(TR[:switches]), :action => proc { engine_switches } },
        { :label => t(TR[:vars]), :action => proc { engine_variables } }
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
        menu.push({ :label => t(TR[:safari]), :action => proc { engine_safari } })
      end

      menu.concat([
        { :label => t(TR[:Field]), :action => proc { engine_field_effects } },
        { :label => "Map / Event Tools", :action => proc { engine_map_events } },
        { :label => t(TR[:refresh]), :action => proc { engine_refresh_map } },
        { :label => t(TR[:daycare]), :action => proc { engine_day_care } },
        { :label => t(TR[:Wallpapers]), :action => proc { engine_wallpapers } },
        { :label => t(TR[:Battle]), :action => proc { engine_test_battle } },
        { :label => "Test Trainer Battle", :action => proc { engine_test_trainer_battle } },
        { :label => t(TR[:expall]), :action => proc { engine_exp_all } },
        { :label => t(TR[:wtw]), :action => proc { toggle_wtw } },
        { :label => t(TR[:openpc]), :action => proc { open_pc_menu } }
      ])
      render_dynamic_menu(_INTL("{1} | {2}", t(TR[:engine]).upcase, cached_engine_profile[:modern_engine] ? "Modern/Hybrid" : "Legacy"), menu)
    end

    def engine_warp
      mapinfos = get_map_infos
      return Kernel.pbMessage(_INTL("MapInfos.rxdata not found!")) unless mapinfos
      
      hash = {}
      mapinfos.keys.sort.each { |id| hash[id] = mapinfos[id].name }
      map_id = search_list("Maps", hash)
      return if !map_id || map_id <= 0

      # Show Preview if modern
      preview = nil
      if defined?(GameData)
        begin
          path = sprintf("Graphics/Pictures/mapPreview_%03d", map_id)
          if pbResolveBitmap(path)
            preview = Sprite.new
            preview.bitmap = Bitmap.new(path)
            preview.z = 99999
            Kernel.pbMessage(_INTL("Previewing Map {1}. Proceed?", map_id))
            preview.dispose
          end
        rescue => e
          log_error("Map Preview", e)
          preview.dispose if preview
        end
      end

      map_data = safe_load_data(sprintf("Data/Map%03d.rxdata", map_id))
      x = 10; y = 10
      if map_data
        found = false
        if defined?($MapFactory)
          temp_map = safe_map_factory_map(map_id)
          if temp_map
            200.times do
              rx = rand(map_data.width)
              ry = rand(map_data.height)
              if temp_map.passable?(rx, ry, 2)
                x = rx; y = ry; found = true
                break
              end
            end
          end
        end
        if !found
          x = map_data.width / 2; y = map_data.height / 2 
        end
      end
      cancel_vehicles_if_possible
      warped = false
      if defined?(pbFadeOutIn)
        pbFadeOutIn(99999) {
          warped = warp_player_to_map!(map_id, x, y, 2)
        }
      else
        warped = warp_player_to_map!(map_id, x, y, 2)
      end
      if warped
        Kernel.pbMessage(_INTL("Warped to map {1} at ({2}, {3}).", map_id, x, y))
      else
        Kernel.pbMessage(_INTL("Could not warp on this engine."))
      end
    end

    def engine_switches
      sys = get_system_data
      return unless sys
      hash = {}
      sys.switches.each_with_index { |name, i| hash[i] = name if name && name != "" }
      id = search_list("Switches", hash)
      return if !id || id <= 0
      current = $game_switches[id]
      ch = Kernel.pbMessage(_INTL("Switch {1} ({2}): {3}", id, hash[id], current ? "ON" : "OFF"), ["ON", "OFF", "Cancel"], -1)
      if ch >= 0 && ch < 2
        if set_game_switch!(id, ch == 0)
          Kernel.pbMessage(_INTL("Switch {1} set to {2}.", id, ch == 0 ? "ON" : "OFF"))
        else
          Kernel.pbMessage(_INTL("Could not edit that switch on this engine."))
        end
      end
    end

    def engine_variables
      sys = get_system_data
      return unless sys
      hash = {}
      sys.variables.each_with_index { |name, i| hash[i] = name if name && name != "" }
      id = search_list("Variables", hash)
      return if !id || id <= 0
      current = $game_variables[id] || 0
      params = ChooseNumberParams.new
      params.setRange(-999999, 999999); params.setInitialValue(current)
      new_value = Kernel.pbMessageChooseNumber(_INTL("Var {1} ({2}) = {3}. New:", id, hash[id], current), params)
      if set_game_variable!(id, new_value)
        Kernel.pbMessage(_INTL("Variable {1} set to {2}.", id, new_value))
      else
        Kernel.pbMessage(_INTL("Could not edit that variable on this engine."))
      end
    end

    def engine_safari
      menu = [
        { :label => "Edit Steps", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 9999); params.setInitialValue($PokemonGlobal.safariSteps || 0)
          new_value = Kernel.pbMessageChooseNumber(_INTL("Steps:"), params)
          if set_safari_value!(:safariSteps, :safariSteps, new_value)
            Kernel.pbMessage(_INTL("Safari steps set to {1}.", new_value))
          else
            Kernel.pbMessage(_INTL("Safari steps not supported on this engine."))
          end
        }},
        { :label => "Edit Safari Balls", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.safariBalls || 0)
          new_value = Kernel.pbMessageChooseNumber(_INTL("Safari Balls:"), params)
          if set_safari_value!(:safariBalls, :safariBalls, new_value)
            Kernel.pbMessage(_INTL("Safari Balls set to {1}.", new_value))
          else
            Kernel.pbMessage(_INTL("Safari Balls not supported on this engine."))
          end
        }},
        { :label => "Edit Contest Balls", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.bugContestBalls || 0)
          new_value = Kernel.pbMessageChooseNumber(_INTL("Contest Balls:"), params)
          if set_safari_value!(:bugContestBalls, :bugContestBalls, new_value)
            Kernel.pbMessage(_INTL("Contest Balls set to {1}.", new_value))
          else
            Kernel.pbMessage(_INTL("Contest Balls not supported on this engine."))
          end
        }}
      ]
      render_dynamic_menu("Edit Safari/Contest", menu)
    end

    def engine_field_effects
      menu = [
        { :label => "Repel Steps", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99999); params.setInitialValue(get_repel_steps || 0)
          new_value = Kernel.pbMessageChooseNumber(_INTL("Repel Steps:"), params)
          set_repel_steps(new_value)
          if get_repel_steps.to_i == new_value.to_i
            Kernel.pbMessage(_INTL("Repel steps set to {1}.", new_value))
          else
            Kernel.pbMessage(_INTL("Could not change repel steps on this engine."))
          end
        }},
        { :label => "Toggle flash", :action => proc {
          new_state = !flash_enabled?
          if set_flash_enabled!(new_state)
            Kernel.pbMessage(_INTL("Flash: {1}", on_off_text(flash_enabled?)))
          else
            Kernel.pbMessage(_INTL("Flash not supported on this version."))
          end
        }},
        { :label => "Toggle Strength", :action => proc {
          new_state = !strength_enabled?
          if set_strength_enabled!(new_state)
            Kernel.pbMessage(_INTL("Strength: {1}", on_off_text(strength_enabled?)))
          else
            Kernel.pbMessage(_INTL("Strength not supported on this version."))
          end
        }},
        { :label => "Toggle Black Flute", :action => proc {
          current = get_map_toggle(:blackFluteUsed, :blackFauteUsed)
          if !current.nil? && set_map_toggle(!current, :blackFluteUsed, :blackFauteUsed)
            Kernel.pbMessage(_INTL("Black Flute: {1}", get_map_toggle(:blackFluteUsed, :blackFauteUsed) ? "ON" : "OFF"))
          else
            Kernel.pbMessage(_INTL("Black Flute not supported on this version."))
          end
        }},
        { :label => "Toggle White Flute", :action => proc {
          current = get_map_toggle(:whiteFluteUsed, :whiteFauteUsed)
          if !current.nil? && set_map_toggle(!current, :whiteFluteUsed, :whiteFauteUsed)
            Kernel.pbMessage(_INTL("White Flute: {1}", get_map_toggle(:whiteFluteUsed, :whiteFauteUsed) ? "ON" : "OFF"))
          else
            Kernel.pbMessage(_INTL("White Flute not supported on this version."))
          end
        }}
      ]
      render_dynamic_menu("Field Effects", menu)
    end

    def engine_refresh_map
      if defined?($game_map) && $game_map && $game_map.events
        $game_map.events.values.each do |e|
          e.refresh if e.respond_to?(:refresh)
        end
      end
      if mark_map_for_refresh!
        Kernel.pbMessage(_INTL("Map refreshed and events re-evaluated!"))
      else
        Kernel.pbMessage(_INTL("Could not refresh the map on this engine."))
      end
    end

    def engine_map_events
      menu = [
        { :label => "Map Summary", :action => proc {
          show_current_map_summary
        }},
        { :label => "List Current Map Events", :action => proc {
          if export_current_map_events
            Kernel.pbMessage(_INTL("Exported event list to PokeDebug_Current_Map_Events.txt"))
          else
            Kernel.pbMessage(_INTL("No events found on the current map."))
          end
        }},
        { :label => "Teleport To Event", :action => proc {
          event = choose_current_map_event
          if event && teleport_to_event(event)
            Kernel.pbMessage(_INTL("Teleported to {1}.", event_display_name(event)))
          elsif event
            Kernel.pbMessage(_INTL("Could not teleport to that event."))
          end
        }},
        { :label => "Refresh Event", :action => proc {
          event = choose_current_map_event
          if event && refresh_event(event)
            Kernel.pbMessage(_INTL("Event refreshed: {1}.", event_display_name(event)))
          elsif event
            Kernel.pbMessage(_INTL("Could not refresh that event."))
          end
        }}
      ]
      render_dynamic_menu("Map / Event Tools", menu)
    end

    def engine_day_care
      dc = get_day_care_data
      
      status = "Day Care: "
      if dc
        first_pokemon = day_care_first_pokemon(dc)
        if first_pokemon
          status += "#{pokemon_species_name(first_pokemon)} (Lv#{pokemon_level_value(first_pokemon)})"
        else
          status += "Empty"
        end
      else
        status = "Day Care (N/A)"
      end

      menu = [
        { :label => "Deposit Pokemon", :action => proc {
          if day_care_first_pokemon(dc)
            Kernel.pbMessage(_INTL("The first day care slot is already occupied. Withdraw it first."))
          else
            choose_pokemon_with_callback do |pkmn|
              if day_care_deposit_first(pkmn, dc)
                remove_party_member(pkmn)
                Kernel.pbMessage(_INTL("Deposited {1}.", pkmn.name))
              else
                Kernel.pbMessage(_INTL("Could not deposit this Pokemon on this engine."))
              end
            end
          end
        }},
        { :label => "Force Egg", :action => proc {
          if day_care_force_egg(dc)
            Kernel.pbMessage(_INTL("Day care egg forced successfully."))
          else
            Kernel.pbMessage(_INTL("Could not force a day care egg on this engine."))
          end
        }},
        { :label => "Withdraw First Deposited", :action => proc {
          pkmn = day_care_withdraw_first(dc)
          if pkmn
            if add_pkmn_silently(pkmn)
              Kernel.pbMessage(_INTL("Withdrew {1}.", pkmn.name))
            else
              day_care_deposit_first(pkmn, dc)
              Kernel.pbMessage(_INTL("Could not withdraw because the party is full or unsupported on this engine."))
            end
          else
            Kernel.pbMessage(_INTL("No Pokemon in first slot."))
          end
        }}
      ]
      render_dynamic_menu(status, menu)
    end

    def engine_wallpapers
      menu = [
        { :label => "Unlock All", :action => proc {
          $PokemonStorage.allWallpapersUnlocked = true if $PokemonStorage && $PokemonStorage.respond_to?(:allWallpapersUnlocked=)
          Kernel.pbMessage(_INTL("All PC wallpapers unlocked."))
        }},
        { :label => "Lock All", :action => proc {
          $PokemonStorage.allWallpapersUnlocked = false if $PokemonStorage && $PokemonStorage.respond_to?(:allWallpapersUnlocked=)
          Kernel.pbMessage(_INTL("All PC wallpapers locked."))
        }}
      ]
      render_dynamic_menu("Wallpapers", menu)
    end

    def engine_test_battle
      hash = build_search_hash(:Species)
      species_id = search_list("Species", hash)
      return if !species_id || species_id <= 0
      sp_sym = get_symbol(:Species, species_id)
      
      params = ChooseNumberParams.new
      params.setRange(1, 100); params.setInitialValue(50)
      level = Kernel.pbMessageChooseNumber(_INTL("Level:"), params)
      
      params.setRange(0, 50); params.setInitialValue(0)
      form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
      
      pkmn = create_pkmn(sp_sym, level)
      return Kernel.pbMessage(_INTL("Could not create Pokemon for this engine.")) unless pkmn
      if form > 0 && !set_pokemon_form!(pkmn, form)
        Kernel.pbMessage(_INTL("Could not set the selected form on this engine."))
      end
      recalc_pokemon_stats(pkmn) if pkmn
      
      if Kernel.pbMessage("Make Shiny?", ["Yes", "No"], -1) == 0
        Kernel.pbMessage(_INTL("Could not make this test Pokemon shiny on this engine.")) unless set_pokemon_shiny!(pkmn, true)
      end
      
      if Kernel.pbMessage("Custom Moveset?", ["Yes", "No"], -1) == 0
        clear_moves!(pkmn)
        4.times do |i|
          break if Kernel.pbMessage("Add a move for slot #{i+1}?", ["Yes", "No"], -1) != 0
          mhash = build_search_hash(:Move)
          mid = search_list("Moves", mhash)
          if mid
            msym = get_symbol(:Move, mid)
            unless assign_move!(pkmn, i, msym)
              Kernel.pbMessage(_INTL("Could not assign move to slot {1} on this engine.", i + 1))
            end
          end
        end
      end
      
      result = start_test_battle(pkmn, sp_sym, level)
      if result.nil?
        Kernel.pbMessage(_INTL("Battle failed. API mismatch."))
      else
        Kernel.pbMessage(_INTL("Battle started successfully."))
      end
    end

    def engine_test_trainer_battle
      hash = build_search_hash(:TrainerType)
      return Kernel.pbMessage(_INTL("Trainer battle API not supported on this version.")) if hash.empty?
      trainer_type_id = search_list("Trainer Types", hash)
      return if !trainer_type_id || trainer_type_id <= 0
      trainer_type = get_symbol(:TrainerType, trainer_type_id)
      trainer_name = Kernel.pbMessageFreeText(_INTL("Trainer name:"), "TRAINER", false, 32)
      return if trainer_name.nil? || trainer_name == ""

      params = ChooseNumberParams.new
      params.setRange(0, 99)
      params.setInitialValue(0)
      version = Kernel.pbMessageChooseNumber(_INTL("Trainer party/version ID:"), params)

      result = start_test_trainer_battle(trainer_type, trainer_name, version)
      if result.nil?
        Kernel.pbMessage(_INTL("Trainer battle failed. API mismatch."))
      else
        Kernel.pbMessage(_INTL("Trainer battle started successfully."))
      end
    end

    def engine_exp_all
      was_enabled = exp_all_enabled?
      if set_exp_all_enabled!(!was_enabled)
        Kernel.pbMessage(_INTL("Exp All: {1}", exp_all_status_label))
      else
        Kernel.pbMessage(_INTL("Could not toggle Exp All on this engine."))
      end
    end
