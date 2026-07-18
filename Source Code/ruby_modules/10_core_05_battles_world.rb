    def start_test_battle(pkmn, species_symbol, level)
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:battle).start_wild_battle(pkmn, species_symbol, level)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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

    def debug_max_level
      return GameData::GrowthRate.max_level if defined?(GameData) && safe_const_get(GameData, :GrowthRate) && GameData::GrowthRate.respond_to?(:max_level)
      return PBExperience::MAXLEVEL if defined?(PBExperience) && safe_const_get(Object, :PBExperience) && PBExperience.const_defined?(:MAXLEVEL)
      100
    rescue => e
      log_error("Debug Max Level", e)
      100
    end

    def choose_debug_level(prompt_text, initial_value = 5, min_value = 1, max_value = nil)
      params = ChooseNumberParams.new
      params.setRange(min_value, max_value || debug_max_level)
      params.setInitialValue(initial_value)
      params.setCancelValue(0) if params.respond_to?(:setCancelValue)
      safe_choose_number(prompt_text, params, "Choose Debug Level") || 0
    rescue => e
      log_error("Choose Debug Level", e)
      0
    end

    def choose_original_trainer_battle_data
      if defined?(TrainerBattleLister) && defined?(pbListScreen)
        trainerdata = pbListScreen(_INTL("SINGLE TRAINER"), TrainerBattleLister.new(0, false))
        return trainerdata if trainerdata
      end
      nil
    rescue => e
      log_error("Choose Original Trainer Battle Data", e)
      nil
    end

    def build_original_style_warp_destination(map_id)
      return nil if map_id.to_i <= 0
      map = Game_Map.new
      map.setup(map_id)
      success = false
      x = 0
      y = 0
      100.times do
        x = rand(map.width)
        y = rand(map.height)
        passable = if map.respond_to?(:passableStrict?)
                     map.passableStrict?(x, y, 0, $game_player)
                   elsif map.respond_to?(:passable?)
                     begin
                       map.passable?(x, y, 0)
                     rescue ArgumentError
                       map.passable?(x, y)
                     end
                   else
                     true
                   end
        next if !passable

        blocked = false
        map.events.each_value do |event|
          next unless event
          if event.at_coordinate?(x, y) && !event.through && event.character_name != ""
            blocked = true
            break
          end
        end
        next if blocked
        success = true
        break
      end
      if !success
        x = rand(map.width)
        y = rand(map.height)
      end
      [map_id, x, y]
    rescue => e
      log_error("Build Original Style Warp Destination", e)
      nil
    end

    def perform_original_style_warp(destination)
      return false if !destination || destination.length < 3
      map_id = destination[0]
      x = destination[1]
      y = destination[2]
      if defined?($scene) && $scene && $scene.is_a?(Scene_Map)
        return false unless defined?($game_temp) && $game_temp
        $game_temp.player_new_map_id = map_id if $game_temp.respond_to?(:player_new_map_id=)
        $game_temp.player_new_x = x if $game_temp.respond_to?(:player_new_x=)
        $game_temp.player_new_y = y if $game_temp.respond_to?(:player_new_y=)
        $game_temp.player_new_direction = 2 if $game_temp.respond_to?(:player_new_direction=)
        $scene.transfer_player if $scene.respond_to?(:transfer_player)
        return true
      end
      cancel_vehicles_if_possible
      if defined?($map_factory) && $map_factory && $map_factory.respond_to?(:setup)
        $map_factory.setup(map_id)
      elsif defined?($MapFactory) && $MapFactory && $MapFactory.respond_to?(:setup)
        $MapFactory.setup(map_id)
      end
      return false unless defined?($game_player) && $game_player
      $game_player.moveto(x, y) if $game_player.respond_to?(:moveto)
      $game_player.turn_down if $game_player.respond_to?(:turn_down)
      $game_map.update if defined?($game_map) && $game_map && $game_map.respond_to?(:update)
      $game_map.autoplay if defined?($game_map) && $game_map && $game_map.respond_to?(:autoplay)
      $game_map.refresh if defined?($game_map) && $game_map && $game_map.respond_to?(:refresh)
      true
    rescue => e
      log_error("Perform Original Style Warp", e)
      false
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:moves).reset_moves(pkmn)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:moves).restore_pp(pkmn)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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

      # Take a snapshot of instance variables and values for rollback on failure
      snapshot = {}
      begin
        pkmn.instance_variables.each do |ivar|
          val = pkmn.instance_variable_get(ivar)
          if ivar == :@moves && val.is_a?(Array)
            snapshot[ivar] = val.map { |m| m.respond_to?(:clone) ? m.clone : m }
          else
            snapshot[ivar] = val.respond_to?(:clone) ? val.clone : val
          end
        end
      rescue => e
        log_error("Apply Pokemon Preset Snapshot Backup", e)
      end

      # Lambda to perform rollback
      rollback_action = proc do
        unless snapshot.empty?
          begin
            snapshot.each do |ivar, val|
              pkmn.instance_variable_set(ivar, val)
            end
          rescue => err
            log_error("Apply Pokemon Preset Rollback Failure", err)
          end
        end
      end

      begin
        if preset.key?(:species) && !set_pokemon_species!(pkmn, preset[:species])
          rollback_action.call
          return false
        end
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
            unless assign_move!(pkmn, index, move_id)
              rollback_action.call
              return false
            end
          end
        end
        recalc_pokemon_stats(pkmn)
        true
      rescue => e
        log_error("Apply Pokemon Preset", e)
        rollback_action.call
        false
      end
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:moves).create_move(move_symbol)
        move_object = adapter_result[1] if adapter_result && adapter_result[0]
      end
      if defined?(PBMove)
        move_object ||= try_call("Create Legacy Move") { PBMove.new(move_symbol) }
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
      if normalized.index("=") == 0
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
      cmds.push(menu_back_label)
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
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:battle).start_trainer_battle(trainer_type, trainer_name, version)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
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

