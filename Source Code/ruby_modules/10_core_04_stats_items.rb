    def set_pokemon_level!(pkmn, level)
      return false unless pkmn
      pkmn.level = level if pkmn.respond_to?(:level=)
      recalc_pokemon_stats(pkmn)
      if pkmn.respond_to?(:hp) && pkmn.respond_to?(:totalhp) && pkmn.hp > pkmn.totalhp
        pkmn.hp = pkmn.totalhp if pkmn.respond_to?(:hp=)
      end
      verify_pokemon_value(pkmn, level, [:level])
    rescue => e
      log_error("Set Level", e)
      false
    end

    def set_pokemon_exp!(pkmn, exp)
      return false unless pkmn
      pkmn.exp = exp if pkmn.respond_to?(:exp=)
      recalc_pokemon_stats(pkmn)
      if pkmn.respond_to?(:hp) && pkmn.respond_to?(:totalhp) && pkmn.hp > pkmn.totalhp
        pkmn.hp = pkmn.totalhp if pkmn.respond_to?(:hp=)
      end
      verify_pokemon_value(pkmn, exp, [:exp])
    rescue => e
      log_error("Set Experience", e)
      false
    end

    def set_pokemon_happiness!(pkmn, value)
      return false unless pkmn && pkmn.respond_to?(:happiness=)
      pkmn.happiness = value
      verify_pokemon_value(pkmn, value, [:happiness])
    rescue => e
      log_error("Set Happiness", e)
      false
    end

    def max_pokemon_ivs!(pkmn, value = 31)
      set_all_ivs!(pkmn, value)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Max IVs", e)
      false
    end

    def max_pokemon_evs!(pkmn, value = 252)
      set_all_evs!(pkmn, value)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Max EVs", e)
      false
    end

    def each_move_slot(pkmn)
      return enum_for(:each_move_slot, pkmn) unless block_given?
      return unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      pkmn.moves.each_with_index { |move, index| yield move, index }
    end

    def move_identifier(move)
      return nil unless move
      return move.id if move.respond_to?(:id)
      return move.move if move.respond_to?(:move)
      return move.id_number if move.respond_to?(:id_number)
      nil
    rescue => e
      log_error("Move Identifier", e)
      nil
    end

    def move_display_name(move_id)
      return "" if move_id.nil?
      record = data_record(:Move, move_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBMoves.getName(move_id) if defined?(PBMoves) && PBMoves.respond_to?(:getName)
      move_id.to_s
    rescue => e
      log_error("Move Display Name", e)
      move_id.to_s
    end

    def choose_move_replacement_index(pkmn, new_move_id)
      return nil unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      cmds = pkmn.moves.map do |move|
        current_name = move ? (move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))) : "---"
        _INTL("Replace {1}", current_name)
      end
      cmds.push(menu_back_label)
      choice = Kernel.pbMessage(_INTL("Choose a move to forget for {1}:", move_display_name(new_move_id)), cmds, -1)
      return nil if choice < 0 || choice >= pkmn.moves.length
      choice
    rescue => e
      log_error("Choose Move Replacement", e)
      nil
    end

    def move_already_known?(pkmn, move_id)
      return false unless pkmn && move_id
      each_move_slot(pkmn) do |move, _index|
        return true if move_identifier(move).to_s == move_id.to_s
      end
      false
    rescue => e
      log_error("Move Already Known", e)
      false
    end

    def try_native_learn_move(pkmn, move_id)
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:moves).learn_move(pkmn, move_id)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      attempts = []
      if defined?(pbLearnMove)
        attempts.concat([
          proc { pbLearnMove(pkmn, move_id) },
          proc { pbLearnMove(pkmn, move_id, true) },
          proc { pbLearnMove(pkmn, move_id, false) },
          proc { pbLearnMove(pkmn, move_id, true, false) },
          proc { pbLearnMove(pkmn, move_id, false, true) }
        ])
      end
      if pkmn
        attempts.concat([
          proc { pkmn.learn_move(move_id) if pkmn.respond_to?(:learn_move) },
          proc { pkmn.learnMove(move_id) if pkmn.respond_to?(:learnMove) },
          proc { pkmn.pbLearnMove(move_id) if pkmn.respond_to?(:pbLearnMove) }
        ])
      end
      attempts.each do |attempt|
        begin
          result = attempt.call
          return true unless result.nil? || result == false
        rescue ArgumentError
          next
        rescue => e
          log_error("Native Learn Move", e)
        end
      end
      false
    end

    def teach_move_with_prompt!(pkmn, move_id)
      return false unless pkmn && move_id
      return :already_known if move_already_known?(pkmn, move_id)
      move_count = (pkmn.respond_to?(:moves) && pkmn.moves) ? pkmn.moves.length : 0
      if move_count < 4
        return :assigned if assign_move!(pkmn, move_count, move_id) && move_already_known?(pkmn, move_id)
        return false
      end

      return :native if try_native_learn_move(pkmn, move_id) && move_already_known?(pkmn, move_id)

      replace_index = choose_move_replacement_index(pkmn, move_id)
      return false if replace_index.nil?
      return :replaced if assign_move!(pkmn, replace_index, move_id) && move_already_known?(pkmn, move_id)
      false
    rescue => e
      log_error("Teach Move With Prompt", e)
      false
    end

    def reset_pokemon_moves!(pkmn)
      return false unless pkmn
      if pkmn.respond_to?(:resetMoves)
        pkmn.resetMoves
      elsif pkmn.respond_to?(:reset_moves)
        pkmn.reset_moves
      elsif pkmn.respond_to?(:pbLearnMove) && pkmn.respond_to?(:species) && pkmn.respond_to?(:level)
        moved = false
        level_up_moves_for(pkmn).each do |entry|
          next unless entry[0].to_i <= pkmn.level.to_i
          moved ||= !!assign_next_free_move!(pkmn, entry[1])
        end
        return moved
      else
        return false
      end
      true
    rescue => e
      log_error("Reset Pokemon Moves", e)
      false
    end

    def record_pokemon_initial_moves!(pkmn)
      return false unless pkmn && pkmn.respond_to?(:moves)
      move_ids = pkmn.moves.compact.map { |move| move_identifier(move) }.compact
      return false if move_ids.empty?
      if pkmn.respond_to?(:first_moves=)
        pkmn.first_moves = move_ids
        return true
      end
      if pkmn.respond_to?(:initial_moves=)
        pkmn.initial_moves = move_ids
        return true
      end
      pkmn.instance_variable_set(:@first_moves, move_ids)
      true
    rescue => e
      log_error("Record Initial Moves", e)
      false
    end

    def restore_pokemon_pp!(pkmn)
      changed = false
      each_move_slot(pkmn) do |move, _index|
        next unless move
        total_pp = move.respond_to?(:total_pp) ? move.total_pp : (move.respond_to?(:totalPP) ? move.totalPP : nil)
        next if total_pp.nil?
        if move.respond_to?(:pp=)
          move.pp = total_pp
          changed = true
        end
      end
      changed
    rescue => e
      log_error("Restore Pokemon PP", e)
      false
    end

    def max_pokemon_ppups!(pkmn, value = 3)
      changed = false
      each_move_slot(pkmn) do |move, _index|
        next unless move
        if move.respond_to?(:ppup=)
          move.ppup = value
          changed = true
        elsif move.respond_to?(:ppup)
          move.ppup = value rescue nil
          changed = true
        end
      end
      restore_pokemon_pp!(pkmn) if changed
      changed
    rescue => e
      log_error("Max Pokemon PP Ups", e)
      false
    end

    def forget_move!(pkmn, move_index)
      return false unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      return false if move_index.nil? || move_index < 0 || move_index >= pkmn.moves.length
      if pkmn.moves.respond_to?(:delete_at)
        !!pkmn.moves.delete_at(move_index)
      else
        pkmn.moves[move_index] = nil
        true
      end
    rescue => e
      log_error("Forget Move", e)
      false
    end

    def assign_next_free_move!(pkmn, move_id)
      return false unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      free_index = pkmn.moves.index(nil)
      free_index = pkmn.moves.length if free_index.nil? && pkmn.moves.length < 4
      return false if free_index.nil?
      assign_move!(pkmn, free_index, move_id)
    rescue => e
      log_error("Assign Next Free Move", e)
      false
    end

    def level_up_moves_for(pkmn)
      return [] unless pkmn
      species = pkmn.respond_to?(:species) ? pkmn.species : nil
      record = data_record(:Species, species)
      return record.moves if record && record.respond_to?(:moves) && record.moves
      return pkmn.getMoveList if pkmn.respond_to?(:getMoveList)
      []
    rescue => e
      log_error("Level Up Moves", e)
      []
    end

    def stat_editor_definitions
      [
        { :index => 0, :label => "HP",      :aliases => [:HP, :hp, :HITPOINTS, :hitpoints],             :readers => [:totalhp, :total_hp] },
        { :index => 1, :label => "Attack",  :aliases => [:ATTACK, :ATK, :attack, :atk],                 :readers => [:attack, :atk] },
        { :index => 2, :label => "Defense", :aliases => [:DEFENSE, :DEF, :defense, :def],               :readers => [:defense, :def] },
        { :index => 3, :label => "Sp. Atk", :aliases => [:SPECIAL_ATTACK, :SPATK, :SPAT, :spatk, :spat], :readers => [:spatk, :spatk, :sp_atk, :special_attack] },
        { :index => 4, :label => "Sp. Def", :aliases => [:SPECIAL_DEFENSE, :SPDEF, :SPDEFENSE, :spdef], :readers => [:spdef, :sp_def, :special_defense] },
        { :index => 5, :label => "Speed",   :aliases => [:SPEED, :SPD, :speed, :spd],                   :readers => [:speed, :spd] }
      ]
    end

    def pokemon_live_stat_value(pkmn, stat_def)
      return nil unless pkmn && stat_def
      stat_def[:readers].each do |reader|
        return pkmn.send(reader) if pkmn.respond_to?(reader)
      end
      nil
    rescue => e
      log_error("Pokemon Live Stat #{stat_def[:label]}", e)
      nil
    end

    def stat_collection_value(pkmn, collection_name)
      return nil unless pkmn && pkmn.respond_to?(collection_name)
      pkmn.send(collection_name)
    rescue => e
      log_error("Stat Collection #{collection_name}", e)
      nil
    end

    def resolve_stat_key(collection, stat_def)
      return nil if collection.nil? || stat_def.nil?
      return stat_def[:index] if collection.is_a?(Array)
      if collection.is_a?(Hash)
        preferred = stat_def[:aliases]
        preferred.each { |key| return key if collection.key?(key) }
        preferred_strings = preferred.map { |key| key.to_s.downcase }
        collection.keys.each do |key|
          return key if preferred_strings.include?(key.to_s.downcase)
        end
        return collection.keys[stat_def[:index]] if collection.keys.length > stat_def[:index]
      end
      nil
    rescue => e
      log_error("Resolve Stat Key #{stat_def[:label]}", e)
      nil
    end

    def get_individual_stat_value(pkmn, collection_name, stat_def)
      collection = stat_collection_value(pkmn, collection_name)
      return nil if collection.nil?
      key = resolve_stat_key(collection, stat_def)
      return nil if key.nil?
      collection[key]
    rescue => e
      log_error("Get Individual Stat #{collection_name} #{stat_def[:label]}", e)
      nil
    end

    def ensure_stat_collection!(pkmn, collection_name)
      collection = stat_collection_value(pkmn, collection_name)
      return collection unless collection.nil?
      writer = "#{collection_name}="
      return nil unless pkmn && pkmn.respond_to?(writer)
      pkmn.send(writer, [0, 0, 0, 0, 0, 0])
      stat_collection_value(pkmn, collection_name)
    rescue => e
      log_error("Ensure Stat Collection #{collection_name}", e)
      nil
    end

    def set_individual_stat_value!(pkmn, collection_name, stat_def, value)
      collection = ensure_stat_collection!(pkmn, collection_name)
      return false if collection.nil?
      key = resolve_stat_key(collection, stat_def)
      return false if key.nil?
      collection[key] = value.to_i
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Set Individual Stat #{collection_name} #{stat_def[:label]}", e)
      false
    end

    def pokemon_iv_value(pkmn, stat_def)
      get_individual_stat_value(pkmn, :iv, stat_def)
    end

    def pokemon_ev_value(pkmn, stat_def)
      get_individual_stat_value(pkmn, :ev, stat_def)
    end

    def set_pokemon_iv_value!(pkmn, stat_def, value)
      set_individual_stat_value!(pkmn, :iv, stat_def, value)
    end

    def set_pokemon_ev_value!(pkmn, stat_def, value)
      set_individual_stat_value!(pkmn, :ev, stat_def, value)
    end

    def classic_iv_limit
      31
    end

    def classic_ev_limit_per_stat
      252
    end

    def classic_ev_total_limit
      510
    end

    def numeric_stat_values(collection)
      return [] if collection.nil?
      values = if collection.is_a?(Hash)
        collection.values
      elsif collection.is_a?(Array)
        collection
      else
        []
      end
      values.compact.map { |value| value.to_i }
    rescue => e
      log_error("Numeric Stat Values", e)
      []
    end

    def pokemon_has_overcap_ivs?(pkmn)
      iv_values = numeric_stat_values(stat_collection_value(pkmn, :iv))
      return false if iv_values.empty?
      iv_values.any? { |value| value > classic_iv_limit }
    rescue => e
      log_error("Overcap IV Check", e)
      false
    end

    def pokemon_has_overcap_evs?(pkmn)
      ev_values = numeric_stat_values(stat_collection_value(pkmn, :ev))
      return false if ev_values.empty?
      return true if ev_values.any? { |value| value > classic_ev_limit_per_stat }
      ev_values.inject(0) { |sum, value| sum + value } > classic_ev_total_limit
    rescue => e
      log_error("Overcap EV Check", e)
      false
    end

    def pokemon_has_overcap_stats?(pkmn)
      return false unless pkmn
      pokemon_has_overcap_ivs?(pkmn) || pokemon_has_overcap_evs?(pkmn)
    rescue => e
      log_error("Overcap Stat Check", e)
      false
    end

    def extract_pokemon_like_objects(value, found = [])
      return found if value.nil?
      if pokemon_like_object?(value)
        found << value
        return found
      end
      if value.is_a?(Array)
        value.each { |entry| extract_pokemon_like_objects(entry, found) }
      elsif value.is_a?(Hash)
        value.each_value { |entry| extract_pokemon_like_objects(entry, found) }
      end
      found
    rescue => e
      log_error("Extract Pokemon Like Objects", e)
      found
    end

    def pokemon_like_object?(value)
      return false if value.nil?
      return true if value.respond_to?(:iv) || value.respond_to?(:ev)
      return true if value.respond_to?(:personalID) || value.respond_to?(:species)
      false
    rescue
      false
    end

    def overcap_stats_in_args?(*args)
      extract_pokemon_like_objects(args).any? { |pkmn| pokemon_has_overcap_stats?(pkmn) }
    rescue => e
      log_error("Overcap Args Check", e)
      false
    end

    def advanced_stat_editor_lines(pkmn)
      stat_editor_definitions.map do |stat_def|
        iv = pokemon_iv_value(pkmn, stat_def)
        ev = pokemon_ev_value(pkmn, stat_def)
        live = pokemon_live_stat_value(pkmn, stat_def)
        _INTL("{1}: IV {2} | EV {3} | Stat {4}",
              stat_def[:label],
              iv.nil? ? "N/A" : iv,
              ev.nil? ? "N/A" : ev,
              live.nil? ? "N/A" : live)
      end
    rescue => e
      log_error("Advanced Stat Editor Lines", e)
      [_INTL("Could not read advanced stats.")]
    end

    def set_all_ivs!(pkmn, value)
      if pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Hash)
        pkmn.iv.keys.each { |k| pkmn.iv[k] = value }
      elsif pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Array)
        6.times { |i| pkmn.iv[i] = value }
      elsif pkmn.respond_to?(:iv=)
        pkmn.iv = [value, value, value, value, value, value]
      end
    rescue => e
      log_error("Set IVs", e)
    end

    def set_all_evs!(pkmn, value)
      if pkmn.respond_to?(:ev) && pkmn.ev.is_a?(Hash)
        pkmn.ev.keys.each { |k| pkmn.ev[k] = value }
      elsif pkmn.respond_to?(:ev) && pkmn.ev.is_a?(Array)
        6.times { |i| pkmn.ev[i] = value }
      elsif pkmn.respond_to?(:ev=)
        pkmn.ev = [value, value, value, value, value, value]
      end
    rescue => e
      log_error("Set EVs", e)
    end

    def bag_has_item?(item)
      return false unless defined?($PokemonBag) && $PokemonBag
      item_storage_candidates(item).each do |candidate|
        return true if $PokemonBag.respond_to?(:pbHasItem?) && $PokemonBag.pbHasItem?(candidate)
        return true if $PokemonBag.respond_to?(:hasItem?) && $PokemonBag.hasItem?(candidate)
        return true if $PokemonBag.respond_to?(:contains?) && $PokemonBag.contains?(candidate)
      end
      false
    rescue => e
      log_error("Bag Has Item", e)
      false
    end

    def item_storage_candidates(item)
      candidates = []
      candidates << item unless item.nil?
      candidates << item.to_sym if item.respond_to?(:to_sym)
      candidates << item.to_s if item.respond_to?(:to_s)

      if item.is_a?(Integer) && item > 0
        begin
          resolved_symbol = get_symbol(:Item, item)
          candidates << resolved_symbol unless resolved_symbol.nil?
        rescue => e
          log_error("Item Integer Symbol Resolve", e)
        end
      end

      if item.is_a?(Symbol)
        pb_items = safe_const_get(Object, :PBItems)
        if pb_items && pb_items.const_defined?(item)
          candidates << pb_items.const_get(item)
        end
      elsif item.is_a?(String)
        symbol_name = item.to_sym rescue nil
        pb_items = safe_const_get(Object, :PBItems)
        if symbol_name && pb_items && pb_items.const_defined?(symbol_name)
          candidates << pb_items.const_get(symbol_name)
        end
      end

      if item.is_a?(Integer) || item.is_a?(Symbol)
        begin
          record = data_record(:Item, item)
          if record
            candidates << record.id if record.respond_to?(:id)
            candidates << record.id_number if record.respond_to?(:id_number)
            candidates << record.real_name if record.respond_to?(:real_name)
            candidates << record.name if record.respond_to?(:name)
          end
        rescue => e
          log_error("Item Record Candidates", e)
        end
      end

      candidates.compact.uniq
    rescue => e
      log_error("Item Storage Candidates", e)
      [item].compact
    end

    def item_candidates_from_cache_display(display_name)
      candidates = []
      return candidates if display_name.nil? || display_name.to_s.strip == ""

      collection = cache_collection(:Item)
      if collection && collection.respond_to?(:each)
        collection.each do |key, value|
          next unless safe_display_name(value, key).to_s == display_name.to_s
          candidates.concat(item_storage_candidates(key))
          candidates << value.id if value.respond_to?(:id)
          candidates << value.id_number if value.respond_to?(:id_number)
          candidates << value.real_name if value.respond_to?(:real_name)
          candidates << value.name if value.respond_to?(:name)
        end
      end

      candidates.compact.uniq
    rescue => e
      log_error("Item Cache Display Candidates", e)
      []
    end

    def item_candidates_from_lookup(item_lookup, display_name = nil)
      candidates = []
      candidates.concat(item_storage_candidates(item_lookup))
      candidates.concat(item_candidates_from_cache_display(display_name))

      normalized_display = normalized_item_key(display_name)
      begin
        build_search_hash(:Item).each do |item_id, item_name|
          next if display_name && item_name.to_s == display_name.to_s
          next if normalized_display == "" || normalized_item_key(item_name) != normalized_display
          candidates.concat(item_storage_candidates(item_id))
          symbol = get_symbol(:Item, item_id)
          candidates.concat(item_storage_candidates(symbol))
        end
      rescue => e
        log_error("Item Candidates From Lookup", e)
      end

      candidates.compact.uniq
    rescue => e
      log_error("Item Lookup Candidates", e)
      item_storage_candidates(item_lookup)
    end

    def set_pokemon_item_from_lookup!(pkmn, item_lookup, display_name = nil)
      item_candidates_from_lookup(item_lookup, display_name).each do |candidate|
        return true if set_pokemon_item!(pkmn, candidate)
      end
      false
    rescue => e
      log_error("Set Pokemon Item From Lookup", e)
      false
    end

    def bag_store_item_from_lookup(item_lookup, qty = 1, display_name = nil)
      candidates = item_candidates_from_lookup(item_lookup, display_name)
      candidates.each do |candidate|
        return true if bag_store_item(candidate, qty)
      end
      if defined?(pbReceiveItem)
        candidates.each do |candidate|
          begin
            result = pbReceiveItem(candidate, qty)
            return true if result == true || bag_has_item?(candidate)
          rescue => e
            log_error("pbReceiveItem #{candidate}", e)
          end
        end
      end
      false
    rescue => e
      log_error("Bag Store Item From Lookup", e)
      false
    end

    def ability_candidates_from_lookup(ability_lookup, display_name = nil)
      candidates = []
      candidates << ability_lookup unless ability_lookup.nil?
      candidates << ability_lookup.to_sym if ability_lookup.respond_to?(:to_sym)
      candidates << ability_lookup.to_s if ability_lookup.respond_to?(:to_s)

      if ability_lookup.is_a?(Integer) && ability_lookup > 0
        begin
          resolved_symbol = get_symbol(:Ability, ability_lookup)
          candidates << resolved_symbol unless resolved_symbol.nil?
        rescue => e
          log_error("Ability Integer Symbol Resolve", e)
        end
      end

      if display_name && display_name.to_s.strip != ""
        normalized_display = normalized_item_key(display_name)
        begin
          build_search_hash(:Ability).each do |ability_id, ability_name|
            next unless normalized_item_key(ability_name) == normalized_display
            candidates << ability_id
            candidates << get_symbol(:Ability, ability_id)
          end
        rescue => e
          log_error("Ability Candidates From Lookup", e)
        end
      end

      candidates.compact.uniq
    rescue => e
      log_error("Ability Lookup Candidates", e)
      [ability_lookup].compact
    end

    def set_pokemon_ability_from_lookup!(pkmn, ability_lookup, display_name = nil, force_index = nil)
      ability_candidates_from_lookup(ability_lookup, display_name).each do |candidate|
        return true if set_pokemon_ability!(pkmn, candidate, force_index)
      end
      false
    rescue => e
      log_error("Set Pokemon Ability From Lookup", e)
      false
    end

    def try_bag_call(method_label)
      yield
    rescue => e
      log_error(method_label, e)
      nil
    end

    def bag_store_item(item, qty = 1)
      if respond_to?(:engine_adapter_for)
        adapter = engine_adapter_for(:bag)
        if adapter && adapter.score(:bag) > 0
          item_storage_candidates(item).each do |candidate|
            before_has_item = bag_has_item?(candidate)
            adapter_result = adapter.add_item(candidate, qty)
            next unless adapter_result && adapter_result[0]
            return true if adapter_result[1]
            return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
          end
          return false
        end
      end
      if defined?($bag) && $bag
        item_storage_candidates(item).each do |candidate|
          before_has_item = bag_has_item?(candidate)
          if $bag.respond_to?(:add)
            result = try_bag_call("Bag add #{candidate}") do
              $bag.add(candidate, qty)
            end
            return true if result == true
            return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
          end
        end
      end
      return false unless defined?($PokemonBag) && $PokemonBag
      item_storage_candidates(item).each do |candidate|
        before_has_item = bag_has_item?(candidate)

        if $PokemonBag.respond_to?(:pbStoreItem)
          result = try_bag_call("Bag pbStoreItem #{candidate}") do
            begin
              $PokemonBag.pbStoreItem(candidate, qty)
            rescue ArgumentError
              $PokemonBag.pbStoreItem(candidate)
            end
          end
          return true if result == true
          return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
        end

        if $PokemonBag.respond_to?(:storeItem)
          result = try_bag_call("Bag storeItem #{candidate}") do
            $PokemonBag.storeItem(candidate, qty)
          end
          return true if result == true
          return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
        end

        if $PokemonBag.respond_to?(:add)
          result = try_bag_call("Bag add #{candidate}") do
            $PokemonBag.add(candidate, qty)
          end
          return true if result == true
          return true if bag_has_item?(candidate) && (!before_has_item || qty.to_i > 0)
        end
      end
      false
    rescue => e
      log_error("Bag Store Item", e)
      false
    end

    def bag_delete_item(item, qty = 1)
      if respond_to?(:engine_adapter_for)
        adapter = engine_adapter_for(:bag)
        if adapter && adapter.score(:bag) > 0
          item_storage_candidates(item).each do |candidate|
            before_has_item = bag_has_item?(candidate)
            adapter_result = adapter.remove_item(candidate, qty)
            next unless adapter_result && adapter_result[0]
            return true if adapter_result[1]
            return true if before_has_item && !bag_has_item?(candidate)
          end
          return false
        end
      end
      if defined?($bag) && $bag
        item_storage_candidates(item).each do |candidate|
          before_has_item = bag_has_item?(candidate)
          if $bag.respond_to?(:remove)
            result = try_bag_call("Bag remove #{candidate}") do
              $bag.remove(candidate, qty)
            end
            return true if result == true
            return true if before_has_item && !bag_has_item?(candidate)
          end
        end
      end
      return false unless defined?($PokemonBag) && $PokemonBag
      item_storage_candidates(item).each do |candidate|
        before_has_item = bag_has_item?(candidate)

        if $PokemonBag.respond_to?(:pbDeleteItem)
          result = try_bag_call("Bag pbDeleteItem #{candidate}") do
            begin
              $PokemonBag.pbDeleteItem(candidate, qty)
            rescue ArgumentError
              $PokemonBag.pbDeleteItem(candidate)
            end
          end
          return true if result == true
          return true if before_has_item && !bag_has_item?(candidate)
        end

        if $PokemonBag.respond_to?(:deleteItem)
          result = try_bag_call("Bag deleteItem #{candidate}") do
            $PokemonBag.deleteItem(candidate, qty)
          end
          return true if result == true
          return true if before_has_item && !bag_has_item?(candidate)
        end

        if $PokemonBag.respond_to?(:remove)
          result = try_bag_call("Bag remove #{candidate}") do
            $PokemonBag.remove(candidate, qty)
          end
          return true if result == true
          return true if before_has_item && !bag_has_item?(candidate)
        end
      end
      false
    rescue => e
      log_error("Bag Delete Item", e)
      false
    end

    def normalized_item_key(text)
      text.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    rescue
      ""
    end

    def exp_all_item_aliases
      [
        "EXPALL",
        "EXPSHAREALL",
        "EXPSHARE_ALL",
        "EXPALLITEM",
        "EXPAL"
      ]
    end

    def exp_all_item_candidates
      aliases = exp_all_item_aliases.map { |name| normalized_item_key(name) }
      candidates = []
      exp_all_item_aliases.each { |name| candidates.concat(item_storage_candidates(name)) }

      begin
        build_search_hash(:Item).each do |item_id, item_name|
          normalized_name = normalized_item_key(item_name)
          next unless aliases.include?(normalized_name) || normalized_name.include?("EXPSHAREALL") || normalized_name.include?("EXPALL")
          symbol = get_symbol(:Item, item_id)
          candidates.concat(item_storage_candidates(symbol || item_id))
        end
      rescue => e
        log_error("Exp All Search Candidates", e)
      end

      candidates.compact.uniq
    rescue => e
      log_error("Exp All Item Candidates", e)
      exp_all_item_aliases
    end

    def exp_all_global_flag_names
      [:exp_all, :expAll, :experience_all, :experienceAll]
    end

    def exp_all_enabled?
      exp_all_global_flag_names.each do |reader|
        current = get_global_value(reader)
        return !!current unless current.nil?
      end
      exp_all_item_candidates.any? { |candidate| bag_has_item?(candidate) }
    rescue => e
      log_error("Exp All Enabled", e)
      false
    end

    def set_exp_all_enabled!(enabled)
      target = !!enabled
      changed = false

      exp_all_global_flag_names.each do |reader|
        changed = true if set_global_toggle(target, reader)
      end

      if target
        stored = false
        exp_all_item_candidates.each do |candidate|
          if bag_store_item(candidate, 1)
            stored = true
            changed = true
            break
          end
        end
        changed ||= stored
      else
        removed = false
        exp_all_item_candidates.each do |candidate|
          removed = true if bag_delete_item(candidate, 999)
        end
        changed ||= removed
      end

      return exp_all_enabled? == target if changed
      false
    rescue => e
      log_error("Set Exp All", e)
      false
    end

    def exp_all_status_label
      active_items = exp_all_item_candidates.select { |candidate| bag_has_item?(candidate) }
      if active_items.empty?
        exp_all_enabled? ? "ON" : "OFF"
      else
        "ON (#{active_items.first})"
      end
    rescue => e
      log_error("Exp All Status Label", e)
      exp_all_enabled? ? "ON" : "OFF"
    end

