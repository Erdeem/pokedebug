    def on_map_update
      return unless allow_map_runtime_update?
      ensure_runtime_patches!
      ensure_pokedebug_device! if respond_to?(:ensure_pokedebug_device!)
      process_pokedebug_device_menu! if respond_to?(:process_pokedebug_device_menu!)
      if @walk_through_walls && $game_player
        $game_player.through = true
      end
      if defined?(@pending_map_refresh) && @pending_map_refresh
        mark_map_for_refresh!
        @pending_map_refresh = false
      end
      maybe_auto_open_menu_once!
    end

    def maybe_auto_open_menu_once!
      @auto_open_menu_once_pending = false
      @auto_open_menu_once_done = true
      false
    rescue => e
      log_error("Maybe Auto Open Menu Once", e)
      false
    end

    def runtime_patch_targets_ready?
      return true if defined?(BattleCreationHelperMethods)
      return true if defined?(pbWildBattle)
      return true if defined?(pbTrainerBattle)
      return true if defined?(WildBattle) && WildBattle.respond_to?(:start)
      return true if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
      false
    rescue
      false
    end

    def ensure_runtime_patches!(force = false)
      targets_ready = runtime_patch_targets_ready?
      if !force
        force = true if defined?(@runtime_patches_applied) && @runtime_patches_applied && targets_ready && !@runtime_patch_targets_seen
        return true if defined?(@runtime_patches_applied) && @runtime_patches_applied && (!targets_ready || @runtime_patch_targets_seen)
      end
      @runtime_patch_targets_seen = true if targets_ready
      return unless respond_to?(:apply_runtime_patches!)
      apply_runtime_patches!(force)
    rescue => e
      log_error("Ensure Runtime Patches", e)
      false
    end

    def toggle_wtw
      @walk_through_walls = !@walk_through_walls
      if $game_player
        $game_player.through = @walk_through_walls
      end
      Kernel.pbMessage(_INTL("{1}", state_hotkey_message("Walk Through Walls", @walk_through_walls, hotkey_name_for(:walk_through_walls))))
    end

    def get_player
      adapter = engine_adapter_for(:player) if respond_to?(:engine_adapter_for)
      adapted_player = adapter.player if adapter
      return adapted_player if adapted_player
      return $player if defined?($player) && $player
      return $Player if defined?($Player) && $Player
      return $Trainer.player if defined?($Trainer) && $Trainer.respond_to?(:player)
      return $Trainer
    end

    def create_pkmn(sp_sym_or_id, level)
      adapter = engine_adapter_for(:pokemon) if respond_to?(:engine_adapter_for)
      adapted_pokemon = adapter.create_pokemon(sp_sym_or_id, level) if adapter
      return adapted_pokemon if adapted_pokemon
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
      return id_or_index if id_or_index.is_a?(Symbol)
      if id_or_index.is_a?(String)
        stripped = id_or_index.strip
        return stripped.to_sym if stripped != "" && stripped !~ /^\d+$/
      end
      # Pokemon Z's legacy PBMove/PBItem APIs consume the numeric database ID
      # directly. Treating it as a position in $cache can select another entry.
      if id_or_index.is_a?(Numeric) && respond_to?(:pokemon_z_engine?) && pokemon_z_engine?
        return id_or_index.to_i
      end
      collection = cache_collection(type)
      if collection && collection.respond_to?(:keys)
        keys = collection.keys
        return keys[id_or_index - 1] if id_or_index > 0 && id_or_index <= keys.size
      elsif collection && collection.respond_to?(:each_with_index)
        collection.each_with_index do |entry, idx|
          next unless idx + 1 == id_or_index
          return entry.id if entry.respond_to?(:id)
          return entry[0] if entry.is_a?(Array) && !entry.empty?
          return entry if [Symbol, String, Integer].any? { |klass| entry.is_a?(klass) }
        end
      end

      klass = game_data_class(type)
      if klass
        idx = 0
        klass.each do |data|
          idx += 1
          return data.id if idx == id_or_index
        end
      end
      entry = legacy_entry_for_index(type, id_or_index)
      return entry[:id] if entry && entry[:id]
      return id_or_index 
    end

    def build_search_hash(type, filter_block = nil)
      hash = {}
      
      collection = cache_collection(type)
      if collection && collection.respond_to?(:each)
        idx = 0
        if collection.respond_to?(:keys)
          collection.each do |k, v|
            next if filter_block && !filter_block.call(v || k)
            idx += 1
            hash[idx] = safe_display_name(v, k)
          end
        else
          collection.each do |entry|
            probe = entry
            probe = entry[1] if entry.is_a?(Array) && entry.length > 1
            next if filter_block && !filter_block.call(probe)
            idx += 1
            hash[idx] = safe_display_name(probe, entry)
          end
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
            next unless val.is_a?(Numeric)
            next if val <= 0
            name = legacy_constant_display_name(type, c, val)
            next if filter_block && !filter_block.call(val)
            hash[val] = name
          end
        end
      end
      return hash unless hash.empty?
      legacy_entries_for_type(type).each do |entry|
        next unless entry
        next if filter_block && !filter_block.call(entry[:id])
        hash[entry[:id]] = entry[:name]
      end
      if hash.empty?
        legacy_text_table_entries(type).each do |entry|
          next if filter_block && !filter_block.call(entry[:id])
          hash[entry[:id]] = entry[:name]
        end
      end
      hash
    end

    # Some heavily customized legacy games compile their numeric move data but
    # expose names only through a CSV-like text table. Pokemon Z ships this as
    # Data/moves_en.txt and does not populate the PBMoves constants at runtime.
    def legacy_text_table_entries(type)
      filenames = case type
                  when :Move then ["moves.txt", "moves_en.txt"]
                  else []
                  end
      path = nil
      filenames.each do |filename|
        candidate = File.join("Data", filename)
        if File.file?(candidate)
          path = candidate
          break
        end
      end
      return [] unless path
      entries = []
      File.open(path, "rb") do |file|
        file.each_line do |line|
          text = line.to_s.sub(/^\xEF\xBB\xBF/, "").strip
          next if text == "" || text[0, 1] == "#"
          fields = text.split(",", 2)
          next if fields.length < 2
          id = fields[0].to_i
          name = fields[1].to_s.strip
          next if id <= 0 || name == ""
          entries << { :id => id, :symbol => nil, :name => name }
        end
      end
      entries
    rescue => e
      log_error("Legacy Text Table #{type}", e)
      []
    end

    def legacy_entry_for_index(type, id_or_index)
      entries = legacy_entries_for_type(type)
      return nil if id_or_index.to_i <= 0
      entries[id_or_index.to_i - 1]
    rescue => e
      log_error("Legacy Entry For Index #{type}", e)
      nil
    end

    def legacy_entries_for_type(type)
      entries = []
      pb_mod = legacy_pb_module(type)
      if pb_mod
        pb_mod.constants.each do |const_name|
          next if const_name.to_s.empty? || const_name == :MAX_LEVEL
          begin
            value = pb_mod.const_get(const_name)
            next unless value.is_a?(Numeric)
            next if value.to_i <= 0
            entries << { :id => value, :symbol => const_name, :name => legacy_constant_display_name(type, const_name, value) }
          rescue => e
            log_error("Legacy Entry Constant #{type}", e)
          end
        end
      end
      # Several older Essentials forks expose a numeric registry only through
      # getName plus NUM* (Uranium does this for PBMoves). Enumerate that API
      # when the module has no usable constants.
      if entries.empty? && legacy_name_getter_for(type)
        names = legacy_named_entries_from_get_name(type)
        entries.concat(names)
      end
      filtered = []
      seen_ids = {}
      entries.compact.each do |entry|
        next unless entry.is_a?(Hash)
        entry_id = entry[:id].to_i
        next if seen_ids[entry_id]
        seen_ids[entry_id] = true
        filtered << entry
      end
      filtered.sort_by { |entry| [entry[:id].to_i, entry[:name].to_s] }
    rescue => e
      log_error("Legacy Entries #{type}", e)
      []
    end

    def legacy_named_entries_from_get_name(type)
      getter = legacy_name_getter_for(type)
      max_value = legacy_max_value_for(type)
      return [] unless getter && max_value.to_i > 0
      entries = []
      1.upto(max_value.to_i) do |id|
        begin
          name = getter.call(id)
          next if name.nil?
          text = name.to_s.strip
          next if text == "" || normalized_item_key(text) == normalized_item_key(id.to_s)
          entries << { :id => id, :symbol => nil, :name => text }
        rescue
        end
      end
      entries
    rescue => e
      log_error("Legacy Named Entries #{type}", e)
      []
    end

    def legacy_name_getter_for(type)
      case type
      when :Ability
        return proc { |id| PBAbilities.getName(id) } if defined?(PBAbilities) && PBAbilities.respond_to?(:getName)
      when :Species
        return proc { |id| PBSpecies.getName(id) } if defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      when :Item
        return proc { |id| PBItems.getName(id) } if defined?(PBItems) && PBItems.respond_to?(:getName)
      when :Move
        return proc { |id| PBMoves.getName(id) } if defined?(PBMoves) && PBMoves.respond_to?(:getName)
        if defined?(MessageTypes) && MessageTypes.const_defined?(:Moves) && respond_to?(:pbGetMessage, true)
          return proc { |id| send(:pbGetMessage, MessageTypes::Moves, id) }
        end
      when :Nature
        return proc { |id| PBNatures.getName(id) } if defined?(PBNatures) && PBNatures.respond_to?(:getName)
      when :Type
        return proc { |id| PBTypes.getName(id) } if defined?(PBTypes) && PBTypes.respond_to?(:getName)
      when :TrainerType
        return proc { |id| PBTrainers.getName(id) } if defined?(PBTrainers) && PBTrainers.respond_to?(:getName)
      end
      nil
    rescue => e
      log_error("Legacy Name Getter #{type}", e)
      nil
    end

    def legacy_max_value_for(type)
      mod = legacy_pb_module(type)
      return mod.maxValue if mod && mod.respond_to?(:maxValue)
      return mod::NUMABILITIES if type == :Ability && mod && mod.const_defined?(:NUMABILITIES)
      return mod::NUMITEMS if type == :Item && mod && mod.const_defined?(:NUMITEMS)
      return mod::NUMMOVES if type == :Move && mod && mod.const_defined?(:NUMMOVES)
      return mod::NUMPOKEMON if type == :Species && mod && mod.const_defined?(:NUMPOKEMON)
      if type == :Move && defined?(MessageTypes) && MessageTypes.const_defined?(:Moves) && respond_to?(:pbGetMessageCount, true)
        count = send(:pbGetMessageCount, MessageTypes::Moves).to_i
        return count - 1 if count > 1
      end
      0
    rescue => e
      log_error("Legacy Max Value #{type}", e)
      0
    end

    def dump_ids(type, filename)
      hash = build_search_hash(type)
      File.open(filename, "w") do |f|
        hash.sort.each { |k, v| f.puts(sprintf("%03d: %s", k, v)) }
      end
      Kernel.pbMessage(_INTL("Exported {1} items to {2} in game root folder.", hash.size, filename))
    end

    def get_map_infos
      @map_infos ||= begin
        result = nil
        map_info_paths = ["Data/MapInfos.rxdata", "Data/MapInfos.rvdata2", "Data/MapInfos.rvdata"]
        map_info_paths.each do |path|
          next unless File.file?(path)
          result = safe_load_data(path)
          break if result
        end
        # RGSS1 can load files packed inside .rgssad even though File.file?
        # correctly reports false for their virtual archive paths.
        if !result && defined?(RUBY_VERSION) && RUBY_VERSION.to_s.index("1.8") == 0
          result = safe_load_data("Data/MapInfos.rxdata")
        end
        result
      end
    end

    def map_name_from_id(map_id, mapinfos = nil)
      infos = mapinfos || get_map_infos
      return sprintf("Map %03d", map_id.to_i) unless infos && infos[map_id]
      info = infos[map_id]
      name = info.respond_to?(:name) ? info.name.to_s : info.to_s
      return sprintf("Map %03d", map_id.to_i) if name.strip == ""
      name
    rescue => e
      log_error("Map Name From ID", e)
      sprintf("Map %03d", map_id.to_i)
    end

    def sanitize_map_preview_name(name)
      text = name.to_s.dup
      text = text.encode("ASCII", :invalid => :replace, :undef => :replace, :replace => "") rescue text
      text = text.gsub(/[^0-9A-Za-z]+/, "_")
      text = text.gsub(/^_+|_+$/, "")
      text
    rescue
      name.to_s.gsub(/[^0-9A-Za-z]+/, "_")
    end

    def graphic_exists?(path)
      return false if path.nil? || path.to_s.strip == ""
      return !!pbResolveBitmap(path) if defined?(pbResolveBitmap)
      exts = [".png", ".jpg", ".jpeg", ".bmp"]
      exts.any? { |ext| File.file?(path + ext) }
    rescue
      false
    end

    def resolve_graphic_path(path)
      return nil if path.nil? || path.to_s.strip == ""
      return pbResolveBitmap(path) if defined?(pbResolveBitmap)
      exts = [".png", ".jpg", ".jpeg", ".bmp"]
      exts.each do |ext|
        full = path + ext
        return full if File.file?(full)
      end
      nil
    rescue
      nil
    end

    def map_preview_candidate_paths(map_id, map_name = nil)
      safe_name = sanitize_map_preview_name(map_name)
      map_num = sprintf("%03d", map_id.to_i)
      candidates = [
        "Graphics/Pictures/mapPreview_#{map_num}",
        "Graphics/Pictures/mappreview_#{map_num}",
        "Graphics/Pictures/MapPreview_#{map_num}",
        "Graphics/Pictures/MapPreview/mapPreview_#{map_num}",
        "Graphics/Pictures/MapPreviews/mapPreview_#{map_num}",
        "Graphics/Pictures/map_#{map_num}",
        "Graphics/Pictures/Map_#{map_num}",
        "Graphics/Pictures/Map#{map_num}",
        "Graphics/Pictures/Maps/map_#{map_num}",
        "Graphics/Pictures/Maps/Map#{map_num}"
      ]
      if safe_name && safe_name != ""
        candidates.concat([
          "Graphics/Pictures/mapPreview_#{safe_name}",
          "Graphics/Pictures/MapPreview_#{safe_name}",
          "Graphics/Pictures/MapPreview/#{safe_name}",
          "Graphics/Pictures/Maps/#{safe_name}",
          "Graphics/Pictures/#{safe_name}"
        ])
      end
      candidates.uniq
    rescue => e
      log_error("Map Preview Candidate Paths", e)
      []
    end

    def resolve_map_preview_path(map_id, map_name = nil)
      map_preview_candidate_paths(map_id, map_name).each do |path|
        resolved = resolve_graphic_path(path)
        return resolved if resolved
      end
      nil
    rescue => e
      log_error("Resolve Map Preview Path", e)
      nil
    end

    def create_native_map_preview_bitmap(map_id)
      attempts = []
      attempts << proc { createMinimap(map_id) } if respond_to?(:createMinimap)
      attempts << proc { Object.send(:createMinimap, map_id) } if Object.respond_to?(:createMinimap)
      tile_helper = safe_const_get(Object, :TileDrawingHelper)
      attempts << proc { tile_helper.createMinimap(map_id) } if tile_helper && tile_helper.respond_to?(:createMinimap)
      attempts << proc { pbCreateMinimap(map_id) } if respond_to?(:pbCreateMinimap)
      attempts.each do |attempt|
        begin
          bitmap = attempt.call
          return bitmap if bitmap && bitmap.respond_to?(:width) && bitmap.respond_to?(:height)
        rescue => e
          log_error("Native Map Preview Bitmap", e)
        end
      end
      nil
    rescue => e
      log_error("Create Native Map Preview Bitmap", e)
      nil
    end

    def show_map_preview_prompt(map_id, map_name = nil)
      resolved = resolve_map_preview_path(map_id, map_name)
      preview_bitmap = nil
      preview_from_native = false
      if resolved.nil?
        preview_bitmap = create_native_map_preview_bitmap(map_id)
        preview_from_native = !preview_bitmap.nil?
      end
      return true if resolved.nil? && preview_bitmap.nil?
      sprite = nil
      begin
        sprite = Sprite.new
        sprite.bitmap = preview_bitmap || Bitmap.new(resolved)
        sprite.z = 99999
        if sprite.bitmap && sprite.bitmap.width > 0 && sprite.bitmap.height > 0 && sprite.respond_to?(:zoom_x=) && defined?(Graphics)
          max_w = [Graphics.width - 64, 160].max rescue 320
          max_h = [Graphics.height - 96, 120].max rescue 240
          scale_x = max_w.to_f / sprite.bitmap.width.to_f
          scale_y = max_h.to_f / sprite.bitmap.height.to_f
          scale = [scale_x, scale_y, 1.0].min
          sprite.zoom_x = scale
          sprite.zoom_y = scale if sprite.respond_to?(:zoom_y=)
          width = (sprite.bitmap.width * scale).to_i
          height = (sprite.bitmap.height * scale).to_i
          sprite.x = [(Graphics.width - width) / 2, 0].max rescue 0
          sprite.y = [(Graphics.height - height) / 2, 0].max rescue 0
        end
        return Kernel.pbConfirmMessage(_INTL("Previewing Map {1}: {2}. Warp here?", map_id, map_name || map_name_from_id(map_id)))
      rescue => e
        log_error("Show Map Preview Prompt", e)
        return Kernel.pbConfirmMessage(_INTL("Warp to Map {1}: {2}?", map_id, map_name || map_name_from_id(map_id)))
      ensure
        begin
          sprite.dispose if sprite
        rescue
        end
        begin
          preview_bitmap.dispose if preview_from_native && preview_bitmap && preview_bitmap.respond_to?(:dispose)
        rescue
        end
      end
    rescue => e
      log_error("Map Preview Prompt", e)
      true
    end

    def normalize_search_term(term)
      return "" if term.nil?
      str = term.to_s.downcase
      str = str.gsub(/[éèêë]/, 'e').gsub(/[áàâäã]/, 'a').gsub(/[íìîï]/, 'i')
      str = str.gsub(/[óòôöõ]/, 'o').gsub(/[úùûü]/, 'u').gsub(/[ç]/, 'c')
      str = str.gsub(/[^a-z0-9]/, '')
      str
    rescue
      ""
    end

    def lister_entry_text(entry)
      return "" if entry.nil?
      return entry.name if entry.respond_to?(:name)
      return entry.real_name if entry.respond_to?(:real_name)
      return entry.to_s if entry.is_a?(Symbol) || entry.is_a?(String)
      if entry.is_a?(Array)
        str_part = entry.find { |e| e.is_a?(String) }
        return str_part if str_part
      end
      entry.to_s
    end

    def map_lister_search_index(lister, term)
      return nil if !lister || term.nil?
      search_norm = normalize_search_term(term)
      return nil if search_norm == ""
      commands = lister.commands
      start_idx = lister.respond_to?(:startIndex) ? lister.startIndex : 0
      start_idx = 0 if start_idx < 0 || start_idx >= commands.length
      len = commands.length

      (0...len).each do |index|
        entry = commands[index]
        next if entry.nil?
        text_norm = normalize_search_term(lister_entry_text(entry))
        return index if text_norm.include?(search_norm)
        if term.to_s.strip =~ /^\d+$/ && lister.respond_to?(:value)
          value = lister.value(index) rescue nil
          return index if value.to_i == term.to_i && value.to_i > 0
        end
      end
      nil
    rescue => e
      log_error("Map Lister Search Index", e)
      nil
    end

    def select_map_with_preview(initial_map_id = nil, title = _INTL("WARP TO MAP"))
      reset_custom_input_states!
      return nil unless defined?(MapLister) && defined?(pbListWindow)
      viewport = nil
      list = nil
      title_window = nil
      help_window = nil
      search_window = nil
      lister = nil
      
      begin
        if defined?(Viewport)
          begin
            viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
            viewport.z = 99999 if viewport.respond_to?(:z=)
          rescue
            viewport = nil
          end
        end
        list = pbListWindow([])
        list.viewport = viewport if list.respond_to?(:viewport=) && viewport
        list.z = 2 if list.respond_to?(:z=)
        lister = MapLister.new(initial_map_id || (defined?(pbDefaultMap) ? pbDefaultMap : 0))
        
        title_window = Window_UnformattedTextPokemon.newWithSize(
          title, Graphics.width / 2, 0, Graphics.width / 2, 64, viewport
        )
        title_window.z = 2 if title_window.respond_to?(:z=)
        
        help_text = _INTL("USE: Select   BACK: Cancel   Shift: Search")
        help_window = Window_UnformattedTextPokemon.newWithSize(
          help_text, 0, Graphics.height - 64, Graphics.width / 2, 64, viewport
        )
        help_window.z = 2 if help_window.respond_to?(:z=)

        search_window = Window_UnformattedTextPokemon.newWithSize(
          "Search: (Press Shift)", Graphics.width / 2, 64, Graphics.width / 2, 64, viewport
        )
        search_window.z = 2 if search_window.respond_to?(:z=)

        lister.setViewport(viewport) if lister.respond_to?(:setViewport)
        commands = lister.commands
        selindex = lister.startIndex
        if commands.length == 0
          return nil
        end
        list.commands = commands if list.respond_to?(:commands=)
        list.index = selindex if list.respond_to?(:index=)
        selected_index = -1
        
        search_term = ""
        search_active = false
        skip_next_input = false

        # This engine consumes the search hotkey inconsistently inside custom
        # list loops. Offer one guaranteed native search when the selector is
        # opened; an empty answer simply keeps the full list available.
        if rejuvenation_engine?
          term = safe_free_text("Search Pokemon (name or Dex number; blank shows all):", "", false, 256, "Initial Rejuvenation Pokemon Search")
          wait_for_key_release
          Input.update if defined?(Input)
          if term && term.to_s.strip != ""
            search_term = term.to_s.strip
            search_window.setText("Search: #{search_term}") if search_window.respond_to?(:setText)
            jump_index = species_lister_search_index(lister, search_term)
            if jump_index
              list.index = jump_index if list.respond_to?(:index=)
              selected_index = jump_index
              species_value = lister.value(jump_index) rescue nil
              update_species_preview_sprite(preview_sprite, species_value)
              position_species_preview_sprite(preview_sprite)
            else
              safe_text_message("No Pokemon matched that search.", "Initial Rejuvenation Pokemon Search Empty")
            end
          end
        end
        
        loop do
          Graphics.update
          Input.update
          list.update if list.respond_to?(:update)
          current_index = list.index rescue -1
          if current_index != selected_index
            lister.refresh(current_index) if lister.respond_to?(:refresh)
            selected_index = current_index
          end
          
          if list_search_triggered?
            skip_next_input = true
            if !defined?(Keyboard) && native_get_async_key_state_proc.nil?
              term = safe_free_text("Search maps (name or ID):", search_term, false, 256, "Search Maps")
              wait_for_key_release
              Input.update if defined?(Input)
              if term
                search_term = term.to_s.strip
                search_window.setText("Search: #{search_term}") if search_window.respond_to?(:setText)
                jump_index = map_lister_search_index(lister, search_term)
                if jump_index
                  list.index = jump_index if list.respond_to?(:index=)
                  lister.refresh(jump_index) if lister.respond_to?(:refresh)
                  selected_index = jump_index
                end
              end
            else
              search_active = !search_active
              if search_active
                search_window.setText("Search: > #{search_term}") if search_window.respond_to?(:setText)
              else
                search_window.setText("Search: #{search_term} (Press Shift)") if search_window.respond_to?(:setText)
              end
            end
          end
          
          if search_active
            char = read_keyboard_input_char
            if char
              if char == :backspace
                search_term = search_term[0...-1]
              else
                search_term += char
              end
              search_window.setText("Search: > #{search_term}") if search_window.respond_to?(:setText)
              jump_index = map_lister_search_index(lister, search_term)
              if jump_index
                list.index = jump_index if list.respond_to?(:index=)
                lister.refresh(jump_index) if lister.respond_to?(:refresh)
                selected_index = jump_index
              end
            end
          end
          
          if skip_next_input
            skip_next_input = false
            next
          end
          
          if list_cancel_triggered?
            if search_active
              search_active = false
              search_window.setText("Search: #{search_term} (Press Shift)") if search_window.respond_to?(:setText)
            else
              selected_index = -1
              break
            end
          elsif list_confirm_triggered?
            break
          end
        end
        value = lister.value(selected_index)
        return (value && value.to_i > 0) ? value.to_i : nil
      rescue => e
        log_error("Select Map With Preview", e)
        nil
      ensure
        begin
          lister.dispose if lister
        rescue
        end
        begin
          title_window.dispose if title_window
        rescue
        end
        begin
          help_window.dispose if help_window
        rescue
        end
        begin
          search_window.dispose if search_window
        rescue
        end
        begin
          list.dispose if list
        rescue
        end
        begin
          viewport.dispose if viewport
        rescue
        end
        Input.clear if defined?(Input) && Input.respond_to?(:clear)
      end
    end

    def species_lister_search_index(lister, term)
      return nil if !lister || term.nil?
      search_norm = normalize_search_term(term)
      return nil if search_norm == ""
      commands = lister.commands
      len = commands.length

      (0...len).each do |index|
        entry = commands[index]
        next if entry.nil?
        text_norm = normalize_search_term(lister_entry_text(entry))
        return index if text_norm.include?(search_norm)
        if term.to_s.strip =~ /^\d+$/ && lister.respond_to?(:value)
          value = lister.value(index) rescue nil
          begin
            species_data = data_record(:Species, value)
            number = species_data.id_number if species_data && species_data.respond_to?(:id_number)
            return index if number.to_i == term.to_i && number.to_i > 0
          rescue
          end
        end
      end
      nil
    rescue => e
      log_error("Species Lister Search Index", e)
      nil
    end

    def item_lister_search_index(lister, term)
      return nil if !lister || term.nil?
      search_norm = normalize_search_term(term)
      return nil if search_norm == ""
      commands = lister.commands
      len = commands.length

      (0...len).each do |index|
        entry = commands[index]
        next if entry.nil?
        text_norm = normalize_search_term(lister_entry_text(entry))
        return index if text_norm.include?(search_norm)
        if term.to_s.strip =~ /^\d+$/ && lister.respond_to?(:value)
          value = lister.value(index) rescue nil
          begin
            item_data = data_record(:Item, value)
            number = item_data.id_number if item_data && item_data.respond_to?(:id_number)
            return index if number.to_i == term.to_i && number.to_i > 0
          rescue
          end
        end
      end
      nil
    rescue => e
      log_error("Item Lister Search Index", e)
      nil
    end

    def get_item_lister_index(item_id)
      return 0 if !item_id
      return 0 if !defined?(GameData::Item)
      cmds = []
      idx = 1
      GameData::Item.each do |item|
        cmds.push([idx, item.id, item.real_name])
        idx += 1
      end
      cmds = cmds.sort_by { |cmd| cmd[2].downcase }
      cmds.each_with_index do |cmd, i|
        return i if cmd[1] == item_id
      end
      return 0
    rescue
      return 0
    end

    def force_all_items_in_lister(lister)
      return unless lister
      return unless defined?(GameData::Item)
      all_items = []
      GameData::Item.each { |i| all_items.push(i) }
      all_items = all_items.sort_by do |item|
        (item.respond_to?(:real_name) ? item.real_name : (item.respond_to?(:name) ? item.name : item.to_s)).downcase
      end
      new_commands = []
      new_ids = []
      all_items.each do |item|
        num = item.respond_to?(:id_number) ? item.id_number : 0
        name = item.respond_to?(:real_name) ? item.real_name : (item.respond_to?(:name) ? item.name : item.to_s)
        new_commands.push(sprintf("%03d: %s", num, name))
        new_ids.push(item.id)
      end
      lister.instance_variable_set(:@commands, new_commands)
      (class << lister; self; end).send(:define_method, :commands) { new_commands }
      lister.instance_variables.each do |var|
        val = lister.instance_variable_get(var)
        if val.is_a?(Array) && val.length > 0 && !val[0].is_a?(String) && (val[0].is_a?(Symbol) || val[0].is_a?(Integer))
          lister.instance_variable_set(var, new_ids)
        end
      end
      (class << lister; self; end).send(:define_method, :value) do |index|
        (index < 0 || index >= new_ids.length) ? nil : new_ids[index]
      end
    rescue => e
      log_error("Force All Items Lister", e)
    end

    def sorted_item_selection_entries
      entries = []
      if defined?(GameData) && safe_const_get(GameData, :Item) && GameData::Item.respond_to?(:each)
        source_index = 0
        GameData::Item.each do |item|
          source_index += 1
          id = item.respond_to?(:id) ? item.id : nil
          next if id.nil?
          name = item.respond_to?(:real_name) ? item.real_name : (item.respond_to?(:name) ? item.name : id.to_s)
          number = item.respond_to?(:id_number) ? item.id_number.to_i : 0
          number = source_index if number <= 0
          entries << { :id => id, :name => name.to_s, :number => number }
        end
      end
      entries.sort_by { |entry| [normalize_search_term(entry[:name]), entry[:number], entry[:id].to_s] }
    rescue => e
      log_error("Sorted Item Selection Entries", e)
      []
    end

    def build_item_preview_sprite(item_id, viewport)
      return nil unless defined?(ItemIconSprite)
      attempts = [
        proc { ItemIconSprite.new(item_id, viewport) },
        proc { ItemIconSprite.new(0, 0, item_id, viewport) },
        proc { ItemIconSprite.new(0, 0, item_id) },
        proc { ItemIconSprite.new(item_id) }
      ]
      attempts.each do |attempt|
        begin
          sprite = attempt.call
          return sprite if sprite
        rescue ArgumentError, TypeError
        end
      end
      nil
    rescue => e
      log_error("Build Item Preview Sprite", e)
      nil
    end

    def update_item_preview_sprite(sprite, item_id)
      return false unless sprite
      if sprite.respond_to?(:item=)
        sprite.item = item_id
      elsif sprite.respond_to?(:setItem)
        sprite.setItem(item_id)
      elsif sprite.respond_to?(:set_item)
        sprite.set_item(item_id)
      end
      sprite.x = (Graphics.width * 3 / 4) if sprite.respond_to?(:x=)
      sprite.y = (Graphics.height / 2) if sprite.respond_to?(:y=)
      sprite.z = 3 if sprite.respond_to?(:z=)
      true
    rescue => e
      log_error("Update Item Preview Sprite", e)
      false
    end

    def select_item_with_preview(initial_item = nil, title = _INTL("ADD ITEM"))
      reset_custom_input_states!
      return nil unless defined?(pbListWindow)
      entries = sorted_item_selection_entries
      return nil if entries.empty?
      commands = entries.map { |entry| sprintf("%s  [ID: %03d]", entry[:name], entry[:number]) }
      selected_index = entries.index { |entry| entry[:id] == initial_item } || 0
      
      viewport = nil
      list = nil
      title_window = nil
      help_window = nil
      search_window = nil
      preview_sprite = nil
      
      begin
        if defined?(Viewport)
          begin
            viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
            viewport.z = 99999 if viewport.respond_to?(:z=)
          rescue
            viewport = nil
          end
        end
        list = pbListWindow(commands, Graphics.width / 2)
        list.viewport = viewport if list.respond_to?(:viewport=) && viewport
        list.index = selected_index if list.respond_to?(:index=)
        list.z = 2 if list.respond_to?(:z=)
        
        title_window = Window_UnformattedTextPokemon.newWithSize(title, Graphics.width / 2, 0, Graphics.width / 2, 64, viewport)
        title_window.z = 2 if title_window.respond_to?(:z=)
        
        help_window = Window_UnformattedTextPokemon.newWithSize(
          _INTL("USE: Select   BACK: Cancel   Shift: Search"), 0, Graphics.height - 64, Graphics.width / 2, 64, viewport
        )
        help_window.z = 2 if help_window.respond_to?(:z=)

        search_window = Window_UnformattedTextPokemon.newWithSize(
          "Search: (Press Shift)", Graphics.width / 2, 64, Graphics.width / 2, 64, viewport
        )
        search_window.z = 2 if search_window.respond_to?(:z=)

        preview_sprite = build_item_preview_sprite(entries[selected_index][:id], viewport)
        update_item_preview_sprite(preview_sprite, entries[selected_index][:id])
        last_index = -1
        
        search_term = ""
        search_active = false
        skip_next_input = false
        
        loop do
          Graphics.update
          Input.update
          list.update if list.respond_to?(:update)
          current_index = list.index rescue 0
          current_index = 0 if current_index < 0
          if current_index != last_index
            update_item_preview_sprite(preview_sprite, entries[current_index][:id])
            last_index = current_index
          end
          
          if list_search_triggered?
            skip_next_input = true
            if !defined?(Keyboard) && native_get_async_key_state_proc.nil?
              term = safe_free_text("Search items (name or ID):", search_term, false, 256, "Search Items")
              wait_for_key_release
              Input.update if defined?(Input)
              if term
                search_term = term.to_s.strip
                search_window.setText("Search: #{search_term}") if search_window.respond_to?(:setText)
                normalized = normalize_search_term(search_term)
                numeric = search_term =~ /^\d+$/ ? search_term.to_i : nil
                found = entries.index do |entry|
                  (numeric && entry[:number] == numeric) || normalize_search_term(entry[:name]).include?(normalized) || normalize_search_term(entry[:id]).include?(normalized)
                end
                if found
                  list.index = found if list.respond_to?(:index=)
                  update_item_preview_sprite(preview_sprite, entries[found][:id])
                  last_index = found
                end
              end
            else
              search_active = !search_active
              if search_active
                search_window.setText("Search: > #{search_term}") if search_window.respond_to?(:setText)
              else
                search_window.setText("Search: #{search_term} (Press Shift)") if search_window.respond_to?(:setText)
              end
            end
          end
          
          if search_active
            char = read_keyboard_input_char
            if char
              if char == :backspace
                search_term = search_term[0...-1]
              else
                search_term += char
              end
              search_window.setText("Search: > #{search_term}") if search_window.respond_to?(:setText)
              normalized = normalize_search_term(search_term)
              numeric = search_term =~ /^\d+$/ ? search_term.to_i : nil
              found = entries.index do |entry|
                (numeric && entry[:number] == numeric) || normalize_search_term(entry[:name]).include?(normalized) || normalize_search_term(entry[:id]).include?(normalized)
              end
              if found
                list.index = found if list.respond_to?(:index=)
                update_item_preview_sprite(preview_sprite, entries[found][:id])
                last_index = found
              end
            end
          end
          
          if skip_next_input
            skip_next_input = false
            next
          end
          
          if list_cancel_triggered?
            if search_active
              search_active = false
              search_window.setText("Search: #{search_term} (Press Shift)") if search_window.respond_to?(:setText)
            else
              return nil
            end
          elsif list_confirm_triggered?
            return entries[current_index][:id]
          end
        end
      rescue => e
        log_error("Select Item With Preview", e)
        nil
      ensure
        begin preview_sprite.dispose if preview_sprite; rescue; end
        begin title_window.dispose if title_window; rescue; end
        begin help_window.dispose if help_window; rescue; end
        begin search_window.dispose if search_window; rescue; end
        begin list.dispose if list; rescue; end
        begin viewport.dispose if viewport; rescue; end
        begin Input.clear if defined?(Input) && Input.respond_to?(:clear); rescue; end
      end
    end

    def build_species_preview_sprite(viewport = nil)
      sprite = nil
      if defined?(PokemonSpeciesIconSprite)
        begin
          sprite = PokemonSpeciesIconSprite.new(nil, viewport)
        rescue ArgumentError
          # Rejuvenation 14 signature:
          # (species, gender, form, shiny, shadow = false, viewport = nil)
          sprite = PokemonSpeciesIconSprite.new(nil, 0, 0, false, false, viewport) rescue nil
        end
      end
      if !sprite && defined?(PokemonIconSprite)
        sprite = PokemonIconSprite.new(nil, viewport) rescue nil
      end
      if !sprite && defined?(PokemonSprite)
        sprite = PokemonSprite.new(viewport) rescue nil
      end
      if !sprite && defined?(Sprite)
        sprite = Sprite.new(viewport) rescue nil
      end
      sprite
    rescue => e
      log_error("Build Species Preview Sprite", e)
      nil
    end

    def update_species_preview_sprite(sprite, species_id)
      return false unless sprite && species_id
      resolved_species = get_symbol(:Species, species_id) rescue species_id
      if sprite.respond_to?(:species=)
        sprite.species = resolved_species
      elsif sprite.respond_to?(:pokemon=)
        preview_pkmn = create_pkmn(resolved_species, 5)
        sprite.pokemon = preview_pkmn if preview_pkmn
      elsif sprite.respond_to?(:setSpeciesBitmap)
        sprite.setSpeciesBitmap(resolved_species)
      elsif sprite.respond_to?(:setBitmap)
        bitmap_path = nil
        if defined?(GameData) && safe_const_get(GameData, :Species)
          bitmap_path = GameData::Species.icon_filename(species_id) rescue nil
        else
          num = species_id
          if num.is_a?(Symbol) && defined?(PBSpecies)
            num = PBSpecies.const_get(num) rescue 0
          end
          num_str = sprintf("%03d", num.to_i)
          candidates = [
            "Graphics/Icons/icon#{num_str}.png",
            "Graphics/Icons/icon#{num_str}.gif",
            "Graphics/Pictures/icon#{num_str}.png",
            "Graphics/Icons/#{num_str}.png"
          ]
          bitmap_path = candidates.find { |path| File.file?(path) }
        end
        sprite.setBitmap(bitmap_path) if bitmap_path
      end
      true
    rescue => e
      log_error("Update Species Preview Sprite", e)
      false
    end

    def position_species_preview_sprite(sprite)
      return unless sprite
      sprite.x = (Graphics.width * 3 / 4) if sprite.respond_to?(:x=)
      sprite.y = (Graphics.height / 2) if sprite.respond_to?(:y=)
      sprite.z = 2 if sprite.respond_to?(:z=)
      if sprite.respond_to?(:ox=) && sprite.respond_to?(:bitmap) && sprite.bitmap
        sprite.ox = sprite.bitmap.width / 2
      end
      if sprite.respond_to?(:oy=) && sprite.respond_to?(:bitmap) && sprite.bitmap
        sprite.oy = sprite.bitmap.height / 2
      end
    rescue => e
      log_error("Position Species Preview Sprite", e)
    end

  end # temporarily close class << self of DeveloperMenu

  class MockSpeciesLister
    attr_reader :commands
    
    def initialize(selection_index = 0)
      @hash = ::DeveloperMenu.build_search_hash(:Species)
      @keys = @hash.keys.sort
      @commands = @keys.map { |k| @hash[k].to_s }
      @index = selection_index
    end
    
    def startIndex
      @index
    end
    
    def value(idx)
      return nil if idx < 0 || idx >= @keys.length
      @keys[idx]
    end
  end

  class << self # reopen class << self of DeveloperMenu
    def select_species_with_preview(initial_species = nil, title = _INTL("CHOOSE POKEMON"))
      reset_custom_input_states!
      return nil unless defined?(pbListWindow)
      viewport = nil
      list = nil
      title_window = nil
      help_window = nil
      search_window = nil
      preview_sprite = nil
      lister = nil
      
      begin
        if defined?(Viewport)
          begin
            viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
            viewport.z = 99999 if viewport.respond_to?(:z=)
          rescue
            viewport = nil
          end
        end
        list = pbListWindow([])
        list.viewport = viewport if list.respond_to?(:viewport=) && viewport
        list.z = 2 if list.respond_to?(:z=)
        selection_index = 0
        if initial_species && defined?(GameData) && safe_const_get(GameData, :Species) && GameData::Species.respond_to?(:each_species)
          idx = 0
          GameData::Species.each_species do |species|
            if species.id == initial_species || species.species == initial_species
              selection_index = idx
              break
            end
            idx += 1
          end
        end
        if defined?(SpeciesLister)
          lister = SpeciesLister.new(selection_index, false)
        else
          lister = MockSpeciesLister.new(selection_index)
        end
        
        title_window = Window_UnformattedTextPokemon.newWithSize(
          title, Graphics.width / 2, 0, Graphics.width / 2, 64, viewport
        )
        title_window.z = 2 if title_window.respond_to?(:z=)
        
        help_text = _INTL("USE: Select   BACK: Cancel   Shift: Search")
        help_window = Window_UnformattedTextPokemon.newWithSize(
          help_text, 0, Graphics.height - 64, Graphics.width / 2, 64, viewport
        )
        help_window.z = 2 if help_window.respond_to?(:z=)

        search_window = Window_UnformattedTextPokemon.newWithSize(
          "Search: (Press Shift)", Graphics.width / 2, 64, Graphics.width / 2, 64, viewport
        )
        search_window.z = 2 if search_window.respond_to?(:z=)

        preview_sprite = build_species_preview_sprite(viewport)
        position_species_preview_sprite(preview_sprite)
        lister.setViewport(viewport) if lister.respond_to?(:setViewport)
        commands = lister.commands
        selindex = lister.startIndex
        return nil if commands.length == 0
        list.commands = commands if list.respond_to?(:commands=)
        list.index = selindex if list.respond_to?(:index=)
        selected_index = -1
        
        search_term = ""
        search_active = false
        skip_next_input = false
        
        loop do
          Graphics.update
          Input.update
          list.update if list.respond_to?(:update)
          preview_sprite.update if preview_sprite && preview_sprite.respond_to?(:update)
          current_index = list.index rescue -1
          if current_index != selected_index
            species_value = lister.value(current_index) rescue nil
            update_species_preview_sprite(preview_sprite, species_value)
            position_species_preview_sprite(preview_sprite)
            selected_index = current_index
          end
          
          if list_search_triggered?
            skip_next_input = true
            # Rejuvenation's MKXP input loop consumes/interferes with raw
            # per-letter polling. Its native free-text box is stable and also
            # provides the JoiPlay on-screen keyboard.
            use_modal_search = rejuvenation_engine?
            use_modal_search ||= respond_to?(:pokemon_z_engine?) && pokemon_z_engine?
            if use_modal_search || (!defined?(Keyboard) && native_get_async_key_state_proc.nil?)
              term = safe_free_text("Search Pokemon (name or Dex number):", search_term, false, 256, "Search Pokemon")
              wait_for_key_release
              Input.update if defined?(Input)
              if term
                search_term = term.to_s.strip
                search_window.setText("Search: #{search_term}") if search_window.respond_to?(:setText)
                jump_index = species_lister_search_index(lister, search_term)
                if jump_index
                  list.index = jump_index if list.respond_to?(:index=)
                  species_value = lister.value(jump_index) rescue nil
                  update_species_preview_sprite(preview_sprite, species_value)
                  position_species_preview_sprite(preview_sprite)
                  selected_index = jump_index
                end
              end
            else
              search_active = !search_active
              if search_active
                search_window.setText("Search: > #{search_term}") if search_window.respond_to?(:setText)
              else
                search_window.setText("Search: #{search_term} (Press Shift)") if search_window.respond_to?(:setText)
              end
            end
          end
          
          if search_active
            char = read_keyboard_input_char
            if char
              if char == :backspace
                search_term = search_term[0...-1]
              else
                search_term += char
              end
              search_window.setText("Search: > #{search_term}") if search_window.respond_to?(:setText)
              jump_index = species_lister_search_index(lister, search_term)
              if jump_index
                list.index = jump_index if list.respond_to?(:index=)
                species_value = lister.value(jump_index) rescue nil
                update_species_preview_sprite(preview_sprite, species_value)
                position_species_preview_sprite(preview_sprite)
                selected_index = jump_index
              end
            end
          end
          
          if skip_next_input
            skip_next_input = false
            next
          end
          
          if list_cancel_triggered?
            if search_active
              search_active = false
              search_window.setText("Search: #{search_term} (Press Shift)") if search_window.respond_to?(:setText)
            else
              selected_index = -1
              break
            end
          elsif list_confirm_triggered?
            break
          end
        end
        value = lister.value(selected_index)
        value
      rescue => e
        log_error("Select Species With Preview", e)
        nil
      ensure
        begin
          preview_sprite.dispose if preview_sprite
        rescue
        end
        begin
          lister.dispose if lister
        rescue
        end
        begin
          title_window.dispose if title_window
        rescue
        end
        begin
          help_window.dispose if help_window
        rescue
        end
        begin
          search_window.dispose if search_window
        rescue
        end
        begin
          list.dispose if list
        rescue
        end
        begin
          viewport.dispose if viewport
        rescue
        end
        Input.clear if defined?(Input) && Input.respond_to?(:clear)
      end
    end

    def get_system_data
      @system_data ||= begin
        if defined?($cache) && $cache && $cache.respond_to?(:RXsystem) && $cache.RXsystem
          $cache.RXsystem
        elsif File.file?("Data/System.rxdata")
          safe_load_data("Data/System.rxdata")
        elsif File.file?("Data/System.rvdata2")
          safe_load_data("Data/System.rvdata2")
        elsif File.file?("Data/System.rvdata")
          safe_load_data("Data/System.rvdata")
        else
          nil
        end
      end
    end

    def search_list(title, hash)
      if hash.empty?
        Kernel.pbMessage(_INTL("No {1} found in game data.", title))
        return nil
      end
      # Debug log hash structure
      begin
        log_item_debug("search_list starting for #{title}. Hash size: #{hash.size}")
        first_5 = hash.to_a[0, 5].map { |pair| k, v = pair; "key=#{k.inspect}(class:#{k.class}) val=#{v.inspect}(class:#{v.class})" }.join(", ")
        log_item_debug("First 5 hash entries: #{first_5}")
      rescue => debug_e
        log_error("Search List Debug Hash", debug_e)
      end

      loop do
        term = safe_free_text(_INTL("Search {1} (blank/ID/=Exact):", title), "", false, 256, "Search #{title}")
        Input.update if defined?(Input)
        return nil if term.nil?
        
        # Debug log entered term
        begin
          log_item_debug("User searched for term: #{term.inspect} (class: #{term.class})")
        rescue => debug_e
          log_error("Search List Debug Term", debug_e)
        end

        direct_id = search_direct_id(hash, term)
        return direct_id if direct_id

        matches = []; keys = []
        ordered_pairs = hash.to_a.sort_by do |pair|
          key = pair[0]
          key.is_a?(Numeric) ? [0, key.to_i] : [1, key.to_s]
        end
        ordered_pairs.each do |pair|
          k = pair[0]
          v = pair[1]
          is_match = false
          begin
            is_match = search_matches_entry?(k, v, term.to_s.strip)
          rescue => match_e
            log_error("search_matches_entry key=#{k} val=#{v} term=#{term}", match_e)
          end
          next unless is_match
          matches.push(sprintf("%03d: %s", k, v))
          keys.push(k)
        end
        
        # Debug log match results
        begin
          log_item_debug("Matches found: #{matches.size}. Matches: #{matches.first(5).inspect}")
        rescue => debug_e
          log_error("Search List Debug Matches", debug_e)
        end
        if matches.empty?
          if Kernel.pbConfirmMessage(_INTL("No results found. Search again?"))
            next
          else
            return nil
          end
        end
        matches.push(menu_back_label)
        ch = Kernel.pbMessage(_INTL("Select:"), matches, -1)
        return keys[ch] if ch >= 0 && ch < keys.length
        return nil if ch == keys.length 
      end
    end

    def render_dynamic_menu(title, menu_array)
      entries = battle_filter_menu_entries(menu_array)
      if entries.empty?
        text = battle_scene_active? ? "No battle-safe menu options available for #{title}." : "No menu options available for #{title}."
        safe_text_message(text, "Empty Menu #{title}")
        return false
      end
      loop do
        mark_menu_activity! if respond_to?(:mark_menu_activity!)
        options = entries.map { |item| item[:label] }
        options.push(t(TR[:back]))
        
        choice = safe_menu_choice(title, options, -1, "Render Menu #{title}")
        break if choice < 0 || choice == options.length - 1
        
        selected = entries[choice]
        next unless selected
        mark_menu_activity! if respond_to?(:mark_menu_activity!)
        safe_execute(selected[:label]) do
          selected[:action].call
        end
      end
      true
    rescue => e
      log_error("Render Dynamic Menu #{title}", e)
      recover_menu_state!("Render Dynamic Menu #{title}")
      false
    end

    def show_menu
      return if @menu_open
      @menu_session_serial = @menu_session_serial.to_i + 1
      menu_session = @menu_session_serial
      @menu_open = true
      mark_menu_activity! if respond_to?(:mark_menu_activity!)
      begin
        main_menu = filtered_main_menu_entries
        if battle_scene_active? && main_menu.empty?
          safe_text_message("No menu categories are enabled for battle use.", "Battle Menu Empty")
          return false
        end
        render_dynamic_menu(t(TR[:dev_menu]) + " (Kzuran)", main_menu)
      rescue => e
        log_error("Show Menu", e)
        safe_text_message("Developer menu crashed and was safely closed.", "Show Menu Crash")
      ensure
        recover_menu_state!("Show Menu Ensure", menu_session)
      end
    end

    def open_menu_external
      return false if @menu_open
      play_decision_sound
      show_menu
      true
    rescue => e
      log_error("External Menu Open", e)
      recover_menu_state!("External Menu Open")
      false
    end
