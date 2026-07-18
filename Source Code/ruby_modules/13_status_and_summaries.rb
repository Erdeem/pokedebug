    def player_badge_count
      p = get_player
      return 0 unless p && p.respond_to?(:badges) && p.badges
      p.badges.select { |badge| badge }.length
    rescue
      0
    end

    def player_pokedex_owned_count
      p = get_player
      if p && p.respond_to?(:pokedex) && p.pokedex
        return p.pokedex.owned_count if p.pokedex.respond_to?(:owned_count)
        return p.pokedex.caught_count if p.pokedex.respond_to?(:caught_count)
      end
      return $Trainer.owned.select { |owned| owned }.length if defined?($Trainer) && $Trainer.respond_to?(:owned) && $Trainer.owned
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
      report_failure_lines("player summary")
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
      lines << _INTL("Engine family: {1}", profile[:engine_family] || (profile[:modern_engine] ? "Modern/Hybrid" : "Legacy"))
      lines << _INTL("Debug menu: {1}", on_off_text(debug_menu_available?))
      lines << _INTL("Storage: {1}", on_off_text(storage_available?))
      lines << _INTL("Day care: {1}", on_off_text(!get_day_care_data.nil?))
      lines << _INTL("Walk Through Walls: {1}", on_off_text(@walk_through_walls))
      lines << _INTL("No Wild Battles: {1}", on_off_text(no_wild_battles_active?))
      lines << _INTL("No Trainer Battles: {1}", on_off_text(no_trainer_battles_active?))
      lines << _INTL("Infinite Mega: {1}", on_off_text(@inf_mega))
      lines
    rescue => e
      log_error("Engine Status Lines", e)
      report_failure_lines("engine status")
    end

    def show_engine_status
      Kernel.pbMessage(_INTL("{1}", engine_status_lines.join("\n")))
    rescue => e
      log_error("Show Engine Status", e)
      false
    end

    def pokemon_menu_status_lines
      party = player_party
      eggs = party.select { |pkmn| pokemon_egg_state(pkmn) }.length
      lines = []
      lines << _INTL("Party size: {1}/6", party.length)
      lines << _INTL("Eggs in party: {1}", eggs)
      lines << _INTL("PC storage: {1}", storage_available? ? "AVAILABLE" : "UNAVAILABLE")
      lines << _INTL("Native editor: {1}", native_pokemon_editor_available? ? "AVAILABLE" : "UNAVAILABLE")
      lines
    rescue => e
      log_error("Pokemon Menu Status", e)
      report_failure_lines("Pokemon status")
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
      report_failure_lines("map summary")
    end

    def show_current_map_summary
      Kernel.pbMessage(_INTL("{1}", current_map_summary_lines.join("\n")))
    rescue => e
      log_error("Show Current Map Summary", e)
      false
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
      report_failure_lines("summary")
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
