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
      pbFadeOutIn(99999) {
        $game_temp.player_new_map_id = map_id
        $game_temp.player_new_x = x
        $game_temp.player_new_y = y
        $game_temp.player_new_direction = 2
        $scene.transfer_player if $scene.respond_to?(:transfer_player)
      }
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
      $game_switches[id] = (ch == 0) if ch >= 0 && ch < 2
      $game_map.need_refresh = true if $game_map
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
      $game_variables[id] = Kernel.pbMessageChooseNumber(_INTL("Var {1} ({2}) = {3}. New:", id, hash[id], current), params)
      $game_map.need_refresh = true if $game_map
    end

    def engine_safari
      menu = [
        { :label => "Edit Steps", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 9999); params.setInitialValue($PokemonGlobal.safariSteps || 0)
          $PokemonGlobal.safariSteps = Kernel.pbMessageChooseNumber(_INTL("Steps:"), params) if $PokemonGlobal.respond_to?(:safariSteps=)
        }},
        { :label => "Edit Safari Balls", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.safariBalls || 0)
          $PokemonGlobal.safariBalls = Kernel.pbMessageChooseNumber(_INTL("Safari Balls:"), params) if $PokemonGlobal.respond_to?(:safariBalls=)
        }},
        { :label => "Edit Contest Balls", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.bugContestBalls || 0)
          $PokemonGlobal.bugContestBalls = Kernel.pbMessageChooseNumber(_INTL("Contest Balls:"), params) if $PokemonGlobal.respond_to?(:bugContestBalls=)
        }}
      ]
      render_dynamic_menu("Edit Safari/Contest", menu)
    end

    def engine_field_effects
      menu = [
        { :label => "Repel Steps", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99999); params.setInitialValue(get_repel_steps || 0)
          set_repel_steps(Kernel.pbMessageChooseNumber(_INTL("Repel Steps:"), params))
        }},
        { :label => "Toggle flash", :action => proc {
          $PokemonGlobal.flashUsed = !$PokemonGlobal.flashUsed if $PokemonGlobal.respond_to?(:flashUsed=)
          Kernel.pbMessage(_INTL("Flash: {1}", on_off_text($PokemonGlobal.flashUsed)))
        }},
        { :label => "Toggle Strength", :action => proc {
          if $PokemonMap.respond_to?(:strengthUsed=)
            $PokemonMap.strengthUsed = !$PokemonMap.strengthUsed
            Kernel.pbMessage(_INTL("Strength: {1}", $PokemonMap.strengthUsed ? "ON" : "OFF"))
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
      $game_map.need_refresh = true
      if $game_map.events
        $game_map.events.values.each do |e|
          e.refresh if e.respond_to?(:refresh)
        end
      end
      safe_set_map_changed($game_map.map_id) if $game_map
      Kernel.pbMessage(_INTL("Map refreshed and events re-evaluated!"))
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
          choose_pokemon_with_callback do |pkmn|
            if day_care_deposit_first(pkmn, dc)
              remove_party_member(pkmn)
              Kernel.pbMessage(_INTL("Deposited {1}.", pkmn.name))
            else
              Kernel.pbMessage(_INTL("Day care data not found!"))
            end
          end
        }},
        { :label => "Force Egg", :action => proc {
          if day_care_force_egg(dc)
            Kernel.pbMessage(_INTL("Day care egg forced successfully."))
          else
            Kernel.pbMessage(_INTL("Day care data not found!"))
          end
        }},
        { :label => "Withdraw First Deposited", :action => proc {
          pkmn = day_care_withdraw_first(dc)
          if pkmn
            add_pkmn_silently(pkmn)
            Kernel.pbMessage(_INTL("Withdrew {1}.", pkmn.name))
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
      pkmn.form = form if pkmn.respond_to?(:form=) && form > 0
      recalc_pokemon_stats(pkmn) if pkmn
      
      if Kernel.pbMessage("Make Shiny?", ["Yes", "No"], -1) == 0
        pkmn.shiny = true if pkmn.respond_to?(:shiny=)
        pkmn.makeShiny if pkmn.respond_to?(:makeShiny)
      end
      
      if Kernel.pbMessage("Custom Moveset?", ["Yes", "No"], -1) == 0
        clear_moves!(pkmn)
        4.times do |i|
          break if Kernel.pbMessage("Add a move for slot #{i+1}?", ["Yes", "No"], -1) != 0
          mhash = build_search_hash(:Move)
          mid = search_list("Moves", mhash)
          if mid
            msym = get_symbol(:Move, mid)
            assign_move!(pkmn, i, msym)
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
      if $PokemonGlobal.respond_to?(:exp_all)
        $PokemonGlobal.exp_all = !$PokemonGlobal.exp_all
        Kernel.pbMessage(_INTL("Global Exp All flag: {1}", $PokemonGlobal.exp_all ? "ON" : "OFF"))
        return
      end
      
      has_item = bag_has_item?(:EXPALL)
      if has_item
        bag_delete_item(:EXPALL)
      else
        stored = bag_store_item(:EXPALL)
        unless stored
          expall_id = build_search_hash(:Item).key("EXPALL")
          bag_store_item(get_symbol(:Item, expall_id)) if expall_id
        end
      end
      Kernel.pbMessage(_INTL("Exp All Item: {1}", has_item ? "REMOVED" : "ADDED"))
    end
