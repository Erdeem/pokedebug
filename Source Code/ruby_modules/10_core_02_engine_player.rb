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

    def debug_menu_available?
      cached_engine_profile[:has_legacy_debug_menu] || cached_engine_profile[:has_modern_debug_menu]
    end

    def native_debug_menu_available?
      debug_menu_available?
    rescue
      false
    end

    def native_pokemon_editor_available?
      return true if defined?(pbPokemonDebug)
      return true if defined?(pbDebugPokemon)
      return true if defined?(PokemonDebug_Scene) && defined?(PokemonDebugScreen)
      return true if defined?(PokemonDebugScene) && defined?(PokemonDebugScreen)
      false
    end

    def custom_pokemon_editor_available?
      player_party.length > 0
    rescue
      false
    end

    def native_pokemon_editor_safe?
      cached_engine_profile[:native_pokemon_editor_safe]
    rescue
      false
    end

    def open_pc_available?
      return true if defined?(pbPokeCenterPC)
      return true if defined?(PokemonPCList)
      return true if defined?(pbPCMainMenu)
      return true if defined?($PokemonStorage) && $PokemonStorage
      false
    rescue
      false
    end

    def day_care_available?
      !get_day_care_data.nil?
    rescue
      false
    end

    def wallpapers_available?
      defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:allWallpapersUnlocked=)
    rescue
      false
    end

    def battle_tools_available?
      respond_to?(:battle_tools_menu)
    rescue
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
        :custom_pokemon_editor => custom_pokemon_editor_available?,
        :native_pokemon_editor => native_pokemon_editor_available?,
        :native_pokemon_editor_safe => native_pokemon_editor_safe?,
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:data).data_record(type, id)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:storage).storage_max_boxes
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      try_call("Storage Max Boxes") { $PokemonStorage.maxBoxes } || 0
    end

    def storage_max_pokemon(box)
      return 0 unless storage_available?
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:storage).storage_max_pokemon(box)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      try_call("Storage Max Pokemon #{box}") { $PokemonStorage.maxPokemon(box) } || 0
    end

    def storage_store_caught(pkmn)
      return false unless storage_available?
      adapter = engine_adapter_for(:storage) if respond_to?(:engine_adapter_for)
      return true if adapter && adapter.store_pokemon(pkmn)
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
      dc = $PokemonGlobal.day_care if $PokemonGlobal.respond_to?(:day_care)
      dc = $PokemonGlobal.daycare if dc.nil? && $PokemonGlobal.respond_to?(:daycare)
      dc
    rescue => e
      throttled_log_error("Day Care Legacy", e) if respond_to?(:throttled_log_error)
      nil
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
      names << "PB#{type.to_s[0...-1]}ies" if type.to_s[-"y".length, "y".length] == "y"
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
        :Ability => [:abilities, :ability, :abil],
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:map).warp_player(map_id, x, y, direction)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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
      unless native_pokemon_editor_safe?
        return open_custom_pokemon_editor_for_party if respond_to?(:open_custom_pokemon_editor_for_party)
      end
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:pc).open_pc
        return true if adapter_result && adapter_result[0] && adapter_result[1]
      end
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:text).enter_player_name("Your Name?", default_name, 12)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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

