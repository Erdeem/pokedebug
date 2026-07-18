    def set_pokemon_name_via_ui(pkmn)
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:text).enter_pokemon_name("Nickname?", pkmn, "", 12)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      return nil unless defined?(pbEnterPokemonName)
      try_variants("Enter Pokemon Name", [
        proc { pbEnterPokemonName("Nickname?", 0, 12, "", pkmn) },
        proc { pbEnterPokemonName("Nickname?", 0, 12, pkmn) },
        proc { pbEnterPokemonName("Nickname?", pkmn) },
        proc { pbEnterPokemonName(pkmn) },
        proc { pbEnterPokemonName() }
      ])
    rescue => e
      log_error("Enter Pokemon Name", e)
      nil
    end

    def set_owner_name_via_ui(owner_name)
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:text).enter_player_name("OT Name?", owner_name, 12)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      return nil unless defined?(pbEnterPlayerName)
      try_variants("Enter OT Name", [
        proc { pbEnterPlayerName("OT Name?", 0, 12, owner_name) },
        proc { pbEnterPlayerName("OT Name?", 0, 12) },
        proc { pbEnterPlayerName("OT Name?", owner_name) },
        proc { pbEnterPlayerName(owner_name) },
        proc { pbEnterPlayerName() }
      ])
    rescue => e
      log_error("Enter OT Name", e)
      nil
    end

    def pokemon_legal_abilities(pkmn)
      return [] unless pkmn && pkmn.respond_to?(:getAbilityList)
      abils = try_call("Pokemon Ability List") { pkmn.getAbilityList }
      return [] unless abils.is_a?(Array)
      abils
    end

    def set_pokemon_legal_ability!(pkmn, choice_index = nil)
      abils = pokemon_legal_abilities(pkmn)
      return false if abils.empty?
      if choice_index.nil?
        cmds = abils.map { |a| a[0].to_s }
        choice_index = Kernel.pbMessage(_INTL("Choose ability:"), cmds, -1)
      end
      return false if choice_index.nil? || choice_index < 0 || choice_index >= abils.length
      ability_symbol = abils[choice_index][0]
      ability_index = abils[choice_index][1]
      set_pokemon_ability!(pkmn, ability_symbol, ability_index)
    rescue => e
      log_error("Set Legal Ability", e)
      false
    end

    def matched_ability_index_for(pkmn, ability_symbol)
      return nil unless pkmn && ability_symbol
      pokemon_legal_abilities(pkmn).each do |entry|
        next unless entry.is_a?(Array) && entry.length >= 2
        return entry[1] if entry[0] == ability_symbol
        return entry[1] if entry[0].to_s == ability_symbol.to_s
      end
      nil
    rescue => e
      log_error("Match Ability Index", e)
      nil
    end

    def set_pokemon_hidden_ability_flags!(pkmn, slot_index)
      return false unless pkmn
      hidden = (slot_index.to_i == 2)
      changed = false
      [:"hidden_ability=", :"hasHiddenAbility=", :"isHiddenAbility="].each do |writer|
        next unless pkmn.respond_to?(writer)
        pkmn.send(writer, hidden)
        changed = true
      end
      [:@hiddenAbility, :@hidden_ability, :@hasHiddenAbility, :@isHiddenAbility].each do |ivar|
        next unless pkmn.instance_variables.any? { |__v| __v.to_s == (ivar).to_s } || hidden
        pkmn.instance_variable_set(ivar, hidden)
        changed = true
      end
      changed
    rescue => e
      log_error("Set Hidden Ability Flags", e)
      false
    end

    def set_pokemon_internal_ability_fields!(pkmn, ability_symbol)
      return false unless pkmn && ability_symbol
      changed = false
      [:@ability, :@ability_id, :@abilityID, :@forcedAbility, :@forced_ability].each do |ivar|
        next unless pkmn.instance_variables.any? { |__v| __v.to_s == (ivar).to_s } || ivar == :@ability
        pkmn.instance_variable_set(ivar, ability_symbol)
        changed = true
      end
      changed
    rescue => e
      log_error("Set Internal Ability Fields", e)
      false
    end

    def remember_pokemon_ability_override!(pkmn, ability_symbol, ability_index = nil)
      return false unless pkmn && ability_symbol
      pkmn.instance_variable_set(:@__gm_ability_override_symbol, ability_symbol)
      pkmn.instance_variable_set(:@__gm_ability_override_index, ability_index)
      true
    rescue => e
      log_error("Remember Ability Override", e)
      false
    end

    def clear_pokemon_ability_override!(pkmn)
      return false unless pkmn
      pkmn.instance_variable_set(:@__gm_ability_override_symbol, nil) if pkmn.instance_variables.any? { |__v| __v.to_s == (:@__gm_ability_override_symbol).to_s }
      pkmn.instance_variable_set(:@__gm_ability_override_index, nil) if pkmn.instance_variables.any? { |__v| __v.to_s == (:@__gm_ability_override_index).to_s }
      true
    rescue => e
      log_error("Clear Ability Override", e)
      false
    end

    def pokemon_ability_override_symbol(pkmn)
      return nil unless pkmn && pkmn.instance_variables.any? { |__v| __v.to_s == (:@__gm_ability_override_symbol).to_s }
      pkmn.instance_variable_get(:@__gm_ability_override_symbol)
    rescue => e
      log_error("Ability Override Symbol", e)
      nil
    end

    def pokemon_ability_override_index(pkmn)
      return nil unless pkmn && pkmn.instance_variables.any? { |__v| __v.to_s == (:@__gm_ability_override_index).to_s }
      pkmn.instance_variable_get(:@__gm_ability_override_index)
    rescue => e
      log_error("Ability Override Index", e)
      nil
    end

    def pokemon_ability_override_active?(pkmn)
      !pokemon_ability_override_symbol(pkmn).nil?
    rescue => e
      log_error("Ability Override Active", e)
      false
    end

    def applying_pokemon_ability_override?(pkmn)
      return false unless pkmn
      !!pkmn.instance_variable_get(:@__gm_applying_ability_override)
    rescue => e
      log_error("Ability Override Guard Read", e)
      false
    end

    def with_pokemon_ability_override_guard(pkmn)
      return false unless pkmn
      previous = applying_pokemon_ability_override?(pkmn)
      pkmn.instance_variable_set(:@__gm_applying_ability_override, true)
      yield
    ensure
      pkmn.instance_variable_set(:@__gm_applying_ability_override, previous) if pkmn
    end

    def apply_pokemon_ability_state!(pkmn, ability_symbol, force_index = nil)
      return false unless pkmn
      matched_index = matched_ability_index_for(pkmn, ability_symbol)
      target_index = force_index.nil? ? matched_index : force_index
      changed = false
      if pkmn.respond_to?(:ability=)
        pkmn.ability = ability_symbol
        changed = true
      end
      if pkmn.respond_to?(:setAbility)
        pkmn.setAbility(ability_symbol)
        changed = true
      end
      if !target_index.nil? && pkmn.respond_to?(:ability_index=)
        pkmn.ability_index = target_index
        changed = true
      end
      if !target_index.nil?
        changed = true if set_pokemon_hidden_ability_flags!(pkmn, target_index)
      elsif pkmn.respond_to?(:ability_index=)
        pkmn.ability_index = nil
      end
      changed = true if set_pokemon_internal_ability_fields!(pkmn, ability_symbol)
      recalc_pokemon_stats(pkmn)
      return true if pokemon_has_ability_value?(pkmn, ability_symbol)
      changed
    rescue => e
      log_error("Apply Ability State", e)
      false
    end

    def apply_pokemon_ability_override!(pkmn)
      return false unless pkmn
      ability_symbol = pokemon_ability_override_symbol(pkmn)
      return false if ability_symbol.nil?
      ability_index = pokemon_ability_override_index(pkmn)
      with_pokemon_ability_override_guard(pkmn) do
        apply_pokemon_ability_state!(pkmn, ability_symbol, ability_index)
      end
    rescue => e
      log_error("Apply Ability Override", e)
      false
    end

    def runtime_pokemon_from_target(target)
      return nil if target.nil?
      return target if target.instance_variables.any? { |__v| __v.to_s == (:@__gm_ability_override_symbol).to_s }
      return target.pokemon if target.respond_to?(:pokemon) && target.pokemon
      return target.pkmn if target.respond_to?(:pkmn) && target.pkmn
      [:@pokemon, :@pkmn].each do |ivar|
        next unless target.instance_variables.any? { |__v| __v.to_s == (ivar).to_s }
        value = target.instance_variable_get(ivar)
        return value unless value.nil?
      end
      nil
    rescue => e
      log_error("Runtime Pokemon From Target", e)
      nil
    end

    def sync_runtime_battler_ability!(battler, pkmn = nil)
      return false unless battler
      pkmn ||= runtime_pokemon_from_target(battler)
      return false unless pkmn
      changed = false
      ability_symbol = pkmn.ability if pkmn.respond_to?(:ability)
      if battler.respond_to?(:ability=)
        battler.ability = ability_symbol
        changed = true
      end
      if battler.respond_to?(:setAbility)
        battler.setAbility(ability_symbol)
        changed = true
      end
      if pkmn.respond_to?(:ability_index)
        ability_index = pkmn.ability_index
        if battler.respond_to?(:ability_index=)
          battler.ability_index = ability_index
          changed = true
        end
      end
      [:@ability, :@ability_id, :@abilityID, :@baseAbility, :@base_ability, :@forcedAbility, :@forced_ability].each do |ivar|
        next unless battler.instance_variables.any? { |__v| __v.to_s == (ivar).to_s } || ivar == :@ability
        battler.instance_variable_set(ivar, ability_symbol)
        changed = true
      end
      battler.pbUpdate if battler.respond_to?(:pbUpdate)
      battler.refresh if battler.respond_to?(:refresh)
      changed
    rescue => e
      log_error("Sync Runtime Battler Ability", e)
      false
    end

    def reapply_runtime_ability_override!(target)
      pkmn = runtime_pokemon_from_target(target)
      return false unless pkmn
      changed = false
      changed = apply_pokemon_ability_override!(pkmn) || changed if pokemon_ability_override_active?(pkmn)
      changed = sync_runtime_battler_ability!(target, pkmn) || changed if !target.equal?(pkmn)
      changed
    rescue => e
      log_error("Reapply Runtime Ability Override", e)
      false
    end

    def ability_value_matches?(actual_value, expected_value)
      return false if actual_value.nil? || expected_value.nil?
      return true if actual_value == expected_value
      return true if actual_value.to_s == expected_value.to_s
      begin
        actual_name = ability_display_name(actual_value)
        expected_name = ability_display_name(expected_value)
        return true if normalized_item_key(actual_name) == normalized_item_key(expected_name)
      rescue
      end
      false
    rescue => e
      log_error("Ability Value Matches", e)
      false
    end

    def pokemon_has_ability_value?(pkmn, ability_symbol)
      return false unless pkmn && ability_symbol
      values = []
      values << pkmn.ability if pkmn.respond_to?(:ability)
      [:@ability, :@ability_id, :@abilityID, :@forcedAbility, :@forced_ability].each do |ivar|
        values << pkmn.instance_variable_get(ivar) if pkmn.instance_variables.any? { |__v| __v.to_s == (ivar).to_s }
      end
      values.compact.each do |value|
        return true if ability_value_matches?(value, ability_symbol)
      end
      false
    rescue => e
      log_error("Pokemon Has Ability Value", e)
      false
    end

    def set_pokemon_ability!(pkmn, ability_symbol, force_index = nil)
      return false unless pkmn
      matched_index = matched_ability_index_for(pkmn, ability_symbol)
      target_index = force_index.nil? ? matched_index : force_index
      changed = apply_pokemon_ability_state!(pkmn, ability_symbol, target_index)
      remember_pokemon_ability_override!(pkmn, ability_symbol, target_index)
      return true if pokemon_has_ability_value?(pkmn, ability_symbol)
      changed
    rescue => e
      log_error("Set Ability", e)
      false
    end

    def reset_pokemon_ability!(pkmn)
      return false unless pkmn
      clear_pokemon_ability_override!(pkmn)
      pkmn.ability_index = nil if pkmn.respond_to?(:ability_index=)
      pkmn.ability = nil if pkmn.respond_to?(:ability=)
      set_pokemon_hidden_ability_flags!(pkmn, 0)
      [:@ability, :@ability_id, :@abilityID, :@forcedAbility, :@forced_ability].each do |ivar|
        pkmn.instance_variable_set(ivar, nil) if pkmn.instance_variables.any? { |__v| __v.to_s == (ivar).to_s }
      end
      true
    rescue => e
      log_error("Reset Ability", e)
      false
    end

    def set_pokemon_nature!(pkmn, nature_symbol)
      return false unless pkmn
      pkmn.nature = nature_symbol if pkmn.respond_to?(:nature=)
      pkmn.setNature(nature_symbol) if pkmn.respond_to?(:setNature)
      verify_pokemon_value(pkmn, nature_symbol, [:nature])
    rescue => e
      log_error("Set Nature", e)
      false
    end

    def set_pokemon_item!(pkmn, item_symbol)
      return false unless pkmn
      pkmn.item = item_symbol if pkmn.respond_to?(:item=)
      pkmn.setItem(item_symbol) if pkmn.respond_to?(:setItem)
      try_call("Held Item Extra Sync") { pbHeldItem(pkmn, item_symbol) } if item_symbol && defined?(pbHeldItem)
      verify_pokemon_value(pkmn, item_symbol, [:item], proc { |value| item_display_name(value) })
    rescue => e
      log_error("Set Held Item", e)
      false
    end

    def remove_pokemon_item!(pkmn)
      set_pokemon_item!(pkmn, nil)
    end

    def set_pokemon_nickname!(pkmn, nickname)
      return false unless pkmn
      return false if nickname.nil? || nickname == ""
      pkmn.name = nickname if pkmn.respond_to?(:name=)
      verify_pokemon_value(pkmn, nickname, [:name])
    rescue => e
      log_error("Set Nickname", e)
      false
    end

    def rename_pokemon_via_ui!(pkmn)
      return false unless pkmn
      nickname = set_pokemon_name_via_ui(pkmn)
      return false if nickname.nil? || nickname == ""
      set_pokemon_nickname!(pkmn, nickname)
    end

    def set_pokemon_ot_name!(pkmn, owner_name)
      return false unless pkmn
      return false if owner_name.nil? || owner_name == ""
      if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name=)
        pkmn.owner.name = owner_name
        return verify_pokemon_value(pkmn, owner_name, [proc { |obj| obj.owner.name if obj.respond_to?(:owner) && obj.owner && obj.owner.respond_to?(:name) }])
      end
      pkmn.ot = owner_name if pkmn.respond_to?(:ot=)
      return verify_pokemon_value(pkmn, owner_name, [:ot, proc { |obj| obj.owner.name if obj.respond_to?(:owner) && obj.owner && obj.owner.respond_to?(:name) }]) if pkmn.respond_to?(:ot=)
      false
    rescue => e
      log_error("Set OT Name", e)
      false
    end

    def rename_pokemon_ot_via_ui!(pkmn)
      return false unless pkmn
      current_name = ""
      current_name = pkmn.owner.name if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name)
      current_name = pkmn.ot if current_name == "" && pkmn.respond_to?(:ot)
      new_name = set_owner_name_via_ui(current_name)
      return false if new_name.nil? || new_name == ""
      set_pokemon_ot_name!(pkmn, new_name)
    end

    def pokemon_ot_name(pkmn)
      return "" unless pkmn
      return pkmn.owner.name if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name)
      return pkmn.ot if pkmn.respond_to?(:ot)
      ""
    rescue => e
      log_error("Pokemon OT Name", e)
      ""
    end

    def pokemon_species_name(pkmn)
      return "Unknown" unless pkmn
      return pkmn.speciesName if pkmn.respond_to?(:speciesName) && pkmn.speciesName
      species_id = pkmn.species if pkmn.respond_to?(:species)
      record = data_record(:Species, species_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBSpecies.getName(species_id) if defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      species_id ? species_id.to_s : "Unknown"
    rescue => e
      log_error("Pokemon Species Name", e)
      "Unknown"
    end

    def species_display_name(species_value)
      return "Unknown" if species_value.nil?
      record = data_record(:Species, species_value)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBSpecies.getName(species_value) if defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      species_value.to_s
    rescue => e
      log_error("Species Display Name", e)
      species_value.to_s
    end

    def pokemon_level_value(pkmn)
      return pkmn.level if pkmn && pkmn.respond_to?(:level)
      0
    rescue
      0
    end

    def pokemon_current_hp(pkmn)
      return pkmn.hp if pkmn && pkmn.respond_to?(:hp)
      nil
    rescue
      nil
    end

    def pokemon_total_hp_value(pkmn)
      return pkmn.totalhp if pkmn && pkmn.respond_to?(:totalhp)
      return pkmn.total_hp if pkmn && pkmn.respond_to?(:total_hp)
      return pkmn.hp if pkmn && pkmn.respond_to?(:hp)
      nil
    rescue
      nil
    end

    def pokemon_status_label(pkmn)
      return "OK" unless pkmn
      status = nil
      status = pkmn.status if pkmn.respond_to?(:status)
      return "OK" if status.nil? || status == false || status == 0 || status == :NONE
      status = status.id if status.respond_to?(:id)
      status.to_s.upcase
    rescue => e
      log_error("Pokemon Status Label", e)
      "OK"
    end

    def pokemon_item_name(pkmn)
      return "None" unless pkmn
      item = pkmn.item if pkmn.respond_to?(:item)
      return "None" if item.nil? || item == 0
      return item_display_name(item)
    rescue => e
      log_error("Pokemon Item Name", e)
      "None"
    end

    def item_display_name(item_id)
      return "None" if item_id.nil? || item_id == 0
      record = data_record(:Item, item_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBItems.getName(item_id) if defined?(PBItems) && PBItems.respond_to?(:getName)
      item_id.to_s
    rescue => e
      log_error("Item Display Name", e)
      "None"
    end

    def ability_display_name(ability_id)
      return "None" if ability_id.nil? || ability_id == 0
      record = data_record(:Ability, ability_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBAbilities.getName(ability_id) if defined?(PBAbilities) && PBAbilities.respond_to?(:getName)
      ability_id.to_s
    rescue => e
      log_error("Ability Display Name", e)
      "None"
    end

    def pokemon_shiny_state(pkmn)
      return false unless pkmn
      return pkmn.shiny? if pkmn.respond_to?(:shiny?)
      return pkmn.shiny if pkmn.respond_to?(:shiny)
      false
    rescue => e
      log_error("Pokemon Shiny State", e)
      false
    end

    def pokemon_egg_state(pkmn)
      return false unless pkmn
      return pkmn.egg? if pkmn.respond_to?(:egg?)
      return pkmn.isEgg? if pkmn.respond_to?(:isEgg?)
      false
    rescue => e
      log_error("Pokemon Egg State", e)
      false
    end

    def pokemon_form_value(pkmn)
      return pkmn.form if pkmn && pkmn.respond_to?(:form)
      0
    rescue
      0
    end

    def pokemon_party_label(pkmn)
      return "Unknown Pokemon" unless pkmn
      name = pkmn.respond_to?(:name) ? pkmn.name.to_s : pokemon_species_name(pkmn)
      level = pokemon_level_value(pkmn)
      hp = pokemon_current_hp(pkmn)
      total_hp = pokemon_total_hp_value(pkmn)
      status = pokemon_status_label(pkmn)
      shiny_tag = pokemon_shiny_state(pkmn) ? " *Shiny*" : ""
      egg_tag = pokemon_egg_state(pkmn) ? " [Egg]" : ""
      hp_text = hp.nil? || total_hp.nil? ? "" : " HP #{hp}/#{total_hp}"
      "#{name} (Lv.#{level})#{egg_tag}#{shiny_tag}#{hp_text} #{status}"
    rescue => e
      log_error("Pokemon Party Label", e)
      "Unknown Pokemon"
    end

    def genderless_pokemon?(pkmn)
      return true if pkmn.respond_to?(:gender_ratio) && pkmn.gender_ratio == :Genderless
      false
    rescue => e
      log_error("Genderless Check", e)
      false
    end

    def set_pokemon_gender!(pkmn, target)
      return false unless pkmn
      expected = nil
      case target
      when :male
        pkmn.makeMale if pkmn.respond_to?(:makeMale)
        pkmn.gender = 0 if pkmn.respond_to?(:gender=)
        expected = 0
      when :female
        pkmn.makeFemale if pkmn.respond_to?(:makeFemale)
        pkmn.gender = 1 if pkmn.respond_to?(:gender=)
        expected = 1
      when :genderless
        pkmn.makeGenderless if pkmn.respond_to?(:makeGenderless)
        pkmn.gender = 2 if pkmn.respond_to?(:gender=)
        expected = 2
      else
        return false
      end
      verify_pokemon_value(pkmn, expected, [:gender])
    rescue => e
      log_error("Set Gender", e)
      false
    end

    def prompt_pokemon_gender!(pkmn)
      return false if genderless_pokemon?(pkmn)
      ch = Kernel.pbMessage(_INTL("Set Gender?"), ["Male", "Female", menu_back_label], -1)
      return false if ch < 0 || ch == 2
      set_pokemon_gender!(pkmn, ch == 0 ? :male : :female)
    end

    def set_pokemon_status!(pkmn, status_symbol, sleep_turns = 3)
      return false unless pkmn
      return false unless pkmn.respond_to?(:status=)
      pkmn.status = status_symbol
      if status_symbol == :SLEEP && pkmn.respond_to?(:statusCount=)
        pkmn.statusCount = sleep_turns
      end
      true
    rescue => e
      log_error("Set Status", e)
      false
    end

    def clear_status_candidates
      values = []
      values << 0
      values << :NONE
      values << :None
      values << nil
      if defined?(PBStatuses)
        values << PBStatuses::NONE if PBStatuses.const_defined?(:NONE)
      end
      values.compact.uniq + [nil]
    rescue => e
      log_error("Clear Status Candidates", e)
      [0, :NONE, nil]
    end

    def assign_cleared_status!(target)
      return false unless target && target.respond_to?(:status=)
      clear_status_candidates.each do |value|
        begin
          target.status = value
          current = target.status if target.respond_to?(:status)
          return true if current.nil? || current == false || current == 0 || current.to_s.upcase == "NONE"
          return true if value.nil?
          return true if current == value
        rescue
        end
      end
      false
    rescue => e
      log_error("Assign Cleared Status", e)
      false
    end

    def clear_pokemon_status!(pkmn)
      return false unless pkmn
      assign_cleared_status!(pkmn)
      pkmn.statusCount = 0 if pkmn.respond_to?(:statusCount=)
      true
    rescue => e
      log_error("Clear Status", e)
      false
    end

    def set_pokemon_shiny!(pkmn, shiny = true)
      return false unless pkmn
      if shiny
        pkmn.shiny = true if pkmn.respond_to?(:shiny=)
        pkmn.makeShiny if pkmn.respond_to?(:makeShiny)
      else
        pkmn.shiny = false if pkmn.respond_to?(:shiny=)
      end
      pokemon_shiny_state(pkmn) == !!shiny
    rescue => e
      log_error("Set Shiny", e)
      false
    end

    def set_pokemon_species!(pkmn, species_symbol)
      return false unless pkmn
      pkmn.species = species_symbol if pkmn.respond_to?(:species=)
      pkmn.setSpecies(species_symbol) if pkmn.respond_to?(:setSpecies)
      recalc_pokemon_stats(pkmn)
      verify_pokemon_value(pkmn, species_symbol, [:species, proc { |obj| pokemon_species_name(obj) }], proc { |value| species_display_name(value) })
    rescue => e
      log_error("Set Species", e)
      false
    end

    def set_pokemon_form!(pkmn, form)
      return false unless pkmn
      pkmn.form = form if pkmn.respond_to?(:form=)
      pkmn.setForm(form) if pkmn.respond_to?(:setForm)
      recalc_pokemon_stats(pkmn)
      verify_pokemon_value(pkmn, form, [:form])
    rescue => e
      log_error("Set Form", e)
      false
    end

    def clear_pokemon_form_override!(pkmn)
      return false unless pkmn
      pkmn.forced_form = nil if pkmn.respond_to?(:forced_form=)
      pkmn.form_simple = nil if pkmn.respond_to?(:form_simple=)
      true
    rescue => e
      log_error("Clear Form Override", e)
      false
    end

    def set_pokemon_ball!(pkmn, item_id)
      return false unless pkmn
      set_ball_data!(pkmn, item_id)
      return pkmn.poke_ball == get_symbol(:Item, item_id) if pkmn.respond_to?(:poke_ball) && item_id
      return pkmn.ballused.to_i == item_id.to_i if pkmn.respond_to?(:ballused) && item_id
      return pkmn.ball_used == get_symbol(:Item, item_id) if pkmn.respond_to?(:ball_used) && item_id
      true
    rescue => e
      log_error("Set Poke Ball", e)
      false
    end

    def add_pokemon_ribbon!(pkmn, ribbon_symbol)
      return false unless pkmn
      return false unless pkmn.respond_to?(:giveRibbon)
      pkmn.giveRibbon(ribbon_symbol)
      return pkmn.hasRibbon?(ribbon_symbol) if pkmn.respond_to?(:hasRibbon?)
      true
    rescue => e
      log_error("Add Ribbon", e)
      false
    end

    def clear_pokemon_ribbons!(pkmn)
      return false unless pkmn
      pkmn.clearAllRibbons if pkmn.respond_to?(:clearAllRibbons)
      if pkmn.respond_to?(:ribbons) && pkmn.ribbons.respond_to?(:Clear)
        pkmn.ribbons.Clear
      elsif pkmn.respond_to?(:ribbons) && pkmn.ribbons.respond_to?(:clear)
        pkmn.ribbons.clear
      end
      true
    rescue => e
      log_error("Clear Ribbons", e)
      false
    end

    def make_pokemon_egg!(pkmn)
      return false unless pkmn
      pkmn.name = "Egg" if pkmn.respond_to?(:name=)
      pkmn.egg_steps = 255 if pkmn.respond_to?(:egg_steps=)
      recalc_pokemon_stats(pkmn)
      return pokemon_egg_state(pkmn) if pkmn.respond_to?(:egg?) || pkmn.respond_to?(:isEgg?)
      return pkmn.egg_steps.to_i == 255 if pkmn.respond_to?(:egg_steps)
      true
    rescue => e
      log_error("Make Egg", e)
      false
    end

    def hatch_pokemon_egg!(pkmn)
      return false unless pkmn
      pkmn.name = pkmn.speciesName if pkmn.respond_to?(:name=) && pkmn.respond_to?(:speciesName)
      pkmn.egg_steps = 0 if pkmn.respond_to?(:egg_steps=)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Hatch Egg", e)
      false
    end

    def set_pokemon_hatch_steps!(pkmn, steps)
      return false unless pkmn
      return false unless pkmn.respond_to?(:egg_steps=)
      pkmn.egg_steps = steps
      true
    rescue => e
      log_error("Set Egg Steps", e)
      false
    end

    def heal_pokemon!(pkmn)
      return false unless pkmn
      healed = false
      if pkmn.respond_to?(:Heal)
        pkmn.Heal
        healed = true
      end
      if pkmn.respond_to?(:heal)
        pkmn.heal
        healed = true
      end
      max_hp = pokemon_total_hp_value(pkmn)
      if !max_hp.nil? && max_hp.to_i > 0 && pkmn.respond_to?(:hp=)
        pkmn.hp = max_hp.to_i
        healed = true
      end
      clear_pokemon_status!(pkmn)
      restore_pokemon_pp!(pkmn)
      recalc_pokemon_stats(pkmn)
      max_hp = pokemon_total_hp_value(pkmn)
      pkmn.hp = max_hp.to_i if !max_hp.nil? && max_hp.to_i > 0 && pkmn.respond_to?(:hp=)
      healed
    rescue => e
      log_error("Heal Pokemon", e)
      false
    end

    def set_pokemon_hp!(pkmn, value)
      return false unless pkmn && pkmn.respond_to?(:hp=)
      max_hp = nil
      max_hp = pkmn.totalhp if pkmn.respond_to?(:totalhp)
      max_hp = pkmn.total_hp if max_hp.nil? && pkmn.respond_to?(:total_hp)
      max_hp = pkmn.hp if max_hp.nil? && pkmn.respond_to?(:hp)
      min_value = 0
      final_value = value.to_i
      final_value = min_value if final_value < min_value
      final_value = [final_value, max_hp].min if max_hp && max_hp > 0
      pkmn.hp = final_value
      verify_pokemon_value(pkmn, final_value, [:hp])
    rescue => e
      log_error("Set HP", e)
      false
    end

    def faint_pokemon!(pkmn)
      set_pokemon_hp!(pkmn, 0)
    end

