    def cached_engine_profile
      @engine_profile = nil if !defined?(@engine_profile)
      if @engine_profile && !@engine_profile[:has_modern_player] && !@engine_profile[:has_legacy_player]
        has_player = (defined?($player) && !$player.nil?) || (defined?($Player) && !$Player.nil?) || (defined?($Trainer) && !$Trainer.nil?)
        @engine_profile = nil if has_player
      end
      @engine_profile ||= detect_engine_profile
    end

    def reset_engine_profile!
      @engine_profile = nil
      reset_engine_adapters! if respond_to?(:reset_engine_adapters!)
    end

    def modern_engine?
      cached_engine_profile[:modern_engine]
    end

    def rejuvenation_engine?
      flag = safe_const_get(Object, :Rejuv)
      return true if flag == true
      folder = safe_const_get(Object, :GAMEFOLDER)
      return true if folder && folder.to_s.downcase.include?("rejuv")
      engine_title_slug.include?("rejuvenation")
    rescue
      false
    end

    def pokemon_z_engine?
      slug = engine_title_slug
      return true if slug.include?("pokemonz")
      begin
        folder = Dir.pwd.to_s.downcase.gsub(/[^a-z0-9]/, "")
        return true if folder.include?("pokemonzv213") || folder.include?("pokemonz")
      rescue
      end
      false
    rescue
      false
    end

    def current_game_title
      return System.game_title.to_s if defined?(System) && System.respond_to?(:game_title) && System.game_title
      return $data_system.game_title.to_s if defined?($data_system) && $data_system && $data_system.respond_to?(:game_title)
      return $game_system.game_title.to_s if defined?($game_system) && $game_system && $game_system.respond_to?(:game_title)
      ""
    rescue => e
      log_error("Current Game Title", e)
      ""
    end

    def engine_title_slug
      normalized_item_key(current_game_title)
    rescue => e
      log_error("Engine Title Slug", e)
      ""
    end

    def engine_profile_known_notes(slug)
      notes = []
      notes << "Prefer custom Pokemon editor over native editor." if slug != ""
      notes << "Pokemon Indigo: native editor paths can misroute to incompatible screens." if slug.include?("indigo")
      notes << "Pokemon Uranium: older script loader, keep compatibility fallbacks active." if slug.include?("uranium")
      notes << "Pokemon Rejuvenation: data lookups can use custom structures and aliases." if slug.include?("rejuvenation")
      notes << "Pokemon Insurgence: native editor hooks can return to the party menu without opening a stable editor." if slug.include?("insurgence")
      notes << "Pokemon Vanguard: native Pokemon editor appears stable." if slug.include?("vanguard")
      notes << "Pokemon Mauve: native editor looks stable, but some action confirmations may still need relaxed verification." if slug.include?("mauve")
      notes << "Infinite Fusion: battle reward/stat scripts are sensitive to extreme values." if slug.include?("infinitefusion") || slug.include?("fusion")
      notes.uniq
    rescue => e
      log_error("Engine Profile Known Notes", e)
      []
    end

    def preferred_pokemon_editor_name(slug, native_available)
      return "Custom PokeDebug" unless native_available
      return "Native Engine Editor" if native_pokemon_editor_safe_slug?(slug)
      "Custom PokeDebug"
    rescue => e
      log_error("Preferred Pokemon Editor Name", e)
      "Custom PokeDebug"
    end

    def native_pokemon_editor_safe_slug?(slug)
      return false if slug.nil? || slug == ""
      return true if slug.include?("vanguard")
      return true if slug.include?("mauve")
      return false if slug.include?("indigo")
      return false if slug.include?("insurgence")
      return false if slug.include?("rejuvenation")
      return false if slug.include?("uranium")
      return false if slug.include?("infinitefusion") || slug.include?("fusion")
      false
    rescue => e
      log_error("Native Pokemon Editor Safe Slug", e)
      false
    end

    def detect_engine_profile
      profile = {}
      slug = engine_title_slug
      notes = engine_profile_known_notes(slug)
      profile[:has_game_data] = defined?(GameData) ? true : false
      profile[:has_modern_player] = ((defined?($player) && $player) || (defined?($Player) && $Player)) ? true : false
      profile[:has_legacy_player] = defined?($Trainer) ? true : false
      profile[:has_modern_battle_api] = defined?(WildBattle) && WildBattle.respond_to?(:start)
      profile[:has_legacy_battle_api] = defined?(pbWildBattle) ? true : false
      profile[:has_modern_storage] = defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:boxes)
      profile[:has_modern_debug_menu] = defined?(DebugMenu) ? true : false
      profile[:has_legacy_debug_menu] = defined?(pbDebugMenu) ? true : false
      profile[:has_cache] = defined?($cache) && $cache ? true : false
      profile[:modern_engine] = profile[:has_game_data] || profile[:has_modern_battle_api] || profile[:has_modern_player]
      profile[:engine_family] = if profile[:modern_engine]
                                  "Modern/Hybrid"
                                elsif profile[:has_cache]
                                  "Custom Cache/Hybrid"
                                else
                                  "Legacy"
                                end
      profile[:player_api] = if defined?($player) && $player
                               "$player"
                             elsif defined?($Player) && $Player
                               "$Player"
                             elsif profile[:has_legacy_player]
                               "$Trainer"
                             else
                               "Unknown"
                             end
      profile[:battle_api] = profile[:has_modern_battle_api] ? "WildBattle.start" : (profile[:has_legacy_battle_api] ? "pbWildBattle" : "Unknown")
      profile[:debug_api] = profile[:has_legacy_debug_menu] ? "pbDebugMenu" : (profile[:has_modern_debug_menu] ? "DebugMenu" : "Unavailable")
      profile[:data_api] = profile[:has_game_data] ? "GameData" : (profile[:has_cache] ? "$cache" : "Legacy PB*")
      profile[:game_title] = current_game_title
      profile[:engine_slug] = slug
      profile[:custom_pokemon_editor] = true
      profile[:native_pokemon_editor_available] = native_pokemon_editor_available?
      profile[:native_pokemon_editor_safe] = profile[:native_pokemon_editor_available] && native_pokemon_editor_safe_slug?(slug)
      profile[:preferred_pokemon_editor] = preferred_pokemon_editor_name(slug, profile[:native_pokemon_editor_available])
      profile[:known_notes] = notes
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
        :data_api => "Unknown",
        :game_title => "",
        :engine_slug => "",
        :custom_pokemon_editor => true,
        :native_pokemon_editor_available => false,
        :native_pokemon_editor_safe => false,
        :preferred_pokemon_editor => "Custom PokeDebug",
        :known_notes => []
      }
    end

    def engine_profile_lines
      profile = cached_engine_profile
      lines = [
        "Game title: #{profile[:game_title].to_s.strip == "" ? 'Unknown' : profile[:game_title]}",
        "Engine family: #{profile[:engine_family] || (profile[:modern_engine] ? 'Modern/Hybrid' : 'Legacy')}",
        "Player API: #{profile[:player_api]}",
        "Battle API: #{profile[:battle_api]}",
        "Debug API: #{profile[:debug_api]}",
        "Data API: #{profile[:data_api]}",
        "Storage boxes API: #{profile[:has_modern_storage] ? 'Modern' : 'Legacy/Unknown'}",
        "Preferred Pokemon editor: #{profile[:preferred_pokemon_editor]}",
        "Custom editor available: #{on_off_text(profile[:custom_pokemon_editor])}",
        "Native editor available: #{on_off_text(profile[:native_pokemon_editor_available])}",
        "Native editor safe: #{on_off_text(profile[:native_pokemon_editor_safe])}"
      ]
      caps = engine_capabilities.select { |_k, v| v }.keys.map { |k| k.to_s }
      lines << "Capabilities: #{caps.empty? ? 'None detected' : caps.join(', ')}"
      adapter_lines = engine_adapter_summary if respond_to?(:engine_adapter_summary)
      lines << "Adapters: #{adapter_lines.join(', ')}" if adapter_lines && !adapter_lines.empty?
      notes = profile[:known_notes] || []
      lines << "Known notes: #{notes.empty? ? 'None' : notes.join(' | ')}"
      lines
    end

    def show_engine_report
      reset_engine_profile!
      lines = engine_profile_lines
      show_report_lines(lines, "PokeDebug_Engine_Report.txt")
    rescue => e
      log_error("Engine Report", e)
      report_failure_message("engine report")
    end
