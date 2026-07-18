    def menu_pokemon
      menu = [
        battle_menu_entry(:pokemon_quick_status, t(TR[:quick_status])) { show_pokemon_menu_status },
        battle_menu_entry(:pokemon_fill_storage, t(TR[:FillPC])) { pokemon_fill_storage },
        battle_menu_entry(:pokemon_clear_storage, t(TR[:ClearPC])) { pokemon_clear_storage },
        battle_menu_entry(:pokemon_expand_boxes, t(TR[:addboxes])) { pokemon_expand_boxes },
        battle_menu_entry(:pokemon_quick_hatch, t(TR[:quickhatch])) { pokemon_quick_hatch },
        battle_menu_entry(:pokemon_add, t(TR[:addpkmn])) { pokemon_add },
        battle_menu_entry(:pokemon_import_preset, t(TR[:import_preset])) { pokemon_import_preset },
        battle_menu_entry(:pokemon_heal_party, t(TR[:Heal])) { heal_party },
        battle_menu_entry(:pokemon_export_ids, t(TR[:exportids])) { dump_ids(:Species, "Pokemon_ID_List.txt") }
      ]
      render_dynamic_menu(_INTL("{1} | Party {2}/6", t(TR[:pokemon]).upcase, player_party.length), menu)
    end

    def pokemon_fill_storage
      return unless storage_available?
      return unless Kernel.pbConfirmMessage(_INTL("Fill storage boxes with one Pokemon of each species?"))
      added = 0
      box_qty = storage_max_pokemon(0)
      completed = true
      if defined?(GameData) && safe_const_get(GameData, :Species) && GameData::Species.respond_to?(:each)
        GameData::Species.each do |species_data|
          sp = species_data.species
          f = species_data.form
          if f == 0 && get_player && get_player.respond_to?(:pokedex) && get_player.pokedex
            begin
              if species_data.respond_to?(:single_gendered?) && species_data.single_gendered?
                g = (species_data.respond_to?(:gender_ratio) && species_data.gender_ratio == :AlwaysFemale) ? 1 : 0
                get_player.pokedex.register(sp, g, f, 0, false) if get_player.pokedex.respond_to?(:register)
                get_player.pokedex.register(sp, g, f, 1, false) if get_player.pokedex.respond_to?(:register)
              else
                get_player.pokedex.register(sp, 0, f, 0, false) if get_player.pokedex.respond_to?(:register)
                get_player.pokedex.register(sp, 0, f, 1, false) if get_player.pokedex.respond_to?(:register)
                get_player.pokedex.register(sp, 1, f, 0, false) if get_player.pokedex.respond_to?(:register)
                get_player.pokedex.register(sp, 1, f, 1, false) if get_player.pokedex.respond_to?(:register)
              end
              get_player.pokedex.set_owned(sp, false) if get_player.pokedex.respond_to?(:set_owned)
            rescue => e
              log_error("Fill Storage Pokedex Register", e)
            end
          elsif f != 0 && species_data.respond_to?(:real_form_name) && species_data.real_form_name && species_data.real_form_name != "" && get_player && get_player.respond_to?(:pokedex) && get_player.pokedex
            begin
              g = (species_data.respond_to?(:gender_ratio) && species_data.gender_ratio == :AlwaysFemale) ? 1 : 0
              get_player.pokedex.register(sp, g, f, 0, false) if get_player.pokedex.respond_to?(:register)
              get_player.pokedex.register(sp, g, f, 1, false) if get_player.pokedex.respond_to?(:register)
            rescue => e
              log_error("Fill Storage Form Register", e)
            end
          end
          next if f != 0
          if added >= storage_max_boxes * box_qty
            completed = false
            next
          end
          pkmn = create_pkmn(sp, 50)
          next unless pkmn
          recalc_pokemon_stats(pkmn) rescue nil
          box = added / box_qty
          slot = added % box_qty
          next unless set_storage_slot(box, slot, pkmn)
          added += 1
        end
        if get_player && get_player.respond_to?(:pokedex) && get_player.pokedex.respond_to?(:refresh_accessible_dexes)
          get_player.pokedex.refresh_accessible_dexes
        end
      end
      Kernel.pbMessage(_INTL("Storage boxes were filled with one Pokemon of each species."))
      if !completed
        Kernel.pbMessage(_INTL("Note: The number of storage spaces is less than the number of species."))
      end
    end

    def pokemon_clear_storage
      return unless Kernel.pbConfirmMessage(_INTL("Clear storage boxes?"))
      storage_max_boxes.times do |box|
        storage_max_pokemon(box).times do |slot|
          set_storage_slot(box, slot, nil)
        end
      end
      Kernel.pbMessage(_INTL("The storage boxes were cleared."))
    end

    def pokemon_expand_boxes
      params = ChooseNumberParams.new
      params.setRange(1, 100); params.setInitialValue(5)
      qty = Kernel.pbMessageChooseNumber(_INTL("Add how many boxes?"), params)
      
      return if qty <= 0
      begin
        old_max = storage_max_boxes
        if $PokemonStorage.respond_to?(:maxBoxes=)
          $PokemonStorage.maxBoxes += qty
          # In some modern versions, setting maxBoxes auto-creates the boxes. Let's check:
          if !$PokemonStorage[old_max]
            qty.times do |i|
              storage_add_box(_INTL("Box {1}", old_max + i + 1))
            end
          end
        else
          # Older versions (v15-v18)
          qty.times do |i|
            storage_add_box(_INTL("Box {1}", old_max + i + 1))
          end
        end
        Kernel.pbMessage(_INTL("Added {1} storage boxes.", qty))
      rescue => e
        log_error("Expand Boxes", e)
        Kernel.pbMessage(_INTL("API Error expanding boxes."))
      end
    end

    def pokemon_quick_hatch
      player = get_player
      return false unless player && player.respond_to?(:party) && player.party
      player.party.each do |p|
        next unless p
        is_egg = false
        if p.respond_to?(:egg?)
          is_egg = p.egg?
        elsif p.respond_to?(:isEgg?)
          is_egg = p.isEgg?
        end
        next unless is_egg
        if p.respond_to?(:egg_steps=)
          p.egg_steps = 1
        elsif p.respond_to?(:eggsteps=)
          p.eggsteps = 1
        end
      end
      Kernel.pbMessage(_INTL("All eggs will hatch after one more step."))
      true
    rescue => e
      log_error("Quick Hatch Eggs", e)
      false
    end

    def pokemon_add
      species_id = nil
      if defined?(SpeciesLister) && respond_to?(:select_from_native_lister)
        lister = (SpeciesLister.new(0, false) rescue SpeciesLister.new(0))
        species_id = select_from_native_lister(_INTL("CHOOSE POKEMON"), lister)
        return unless species_id
        hash = build_search_hash(:Species)
      elsif defined?(select_species_with_preview)
        species_id = select_species_with_preview(nil, _INTL("CHOOSE POKEMON"))
        return unless species_id
        hash = build_search_hash(:Species)
      else
        hash = build_search_hash(:Species)
        species_id = search_list("Species", hash)
      end
      return if !species_id || (species_id.is_a?(Numeric) && species_id <= 0) || (species_id.is_a?(String) && species_id.to_s.strip.empty?)
      sp_sym = get_symbol(:Species, species_id)
      level = choose_debug_level(_INTL("Set the Pokemon's level."), 5)
      return if level <= 0
      goes_to_party = !(get_player && get_player.respond_to?(:party_full?) && get_player.party_full?)
      if defined?(pbAddPokemonSilent)
        if pbAddPokemonSilent(sp_sym, level)
          species_name = begin
            if defined?(GameData) && safe_const_get(GameData, :Species)
              GameData::Species.get(sp_sym).name
            else
              hash[species_id]
            end
          rescue
            hash[species_id]
          end
          if goes_to_party
            Kernel.pbMessage(_INTL("Added {1} to party.", species_name))
          else
            Kernel.pbMessage(_INTL("Added {1} to Pokemon storage.", species_name))
          end
        else
          Kernel.pbMessage(_INTL("Couldn't add Pokemon because party and storage are full."))
        end
        return
      end
      pkmn = create_pkmn(sp_sym, level)
      return unless pkmn
      recalc_pokemon_stats(pkmn)
      if add_pkmn_silently(pkmn)
        species_name = pokemon_species_name(pkmn)
        if goes_to_party
          Kernel.pbMessage(_INTL("Added {1} to party.", species_name))
        else
          Kernel.pbMessage(_INTL("Added {1} to Pokemon storage.", species_name))
        end
      else
        Kernel.pbMessage(_INTL("Couldn't add Pokemon because party and storage are full."))
      end
    end

    def pokemon_import_preset
      preset = import_pokemon_preset
      return Kernel.pbMessage(_INTL("Preset file not found.")) unless preset
      pkmn = create_pokemon_from_preset(preset)
      return Kernel.pbMessage(engine_failure_message("create Pokemon from preset")) unless pkmn
      if add_pkmn_silently(pkmn)
        Kernel.pbMessage(_INTL("The preset Pokemon was added."))
      else
        Kernel.pbMessage(engine_failure_message("add the imported Pokemon"))
      end
    end

    def menu_item
      menu = [
        battle_menu_entry(:items_add, t(TR[:additem])) { item_add },
        battle_menu_entry(:items_fill_all, t(TR[:fillbag])) { item_fill(0) },
        battle_menu_entry(:items_fill_non_key, t(TR[:fillbagnon])) { item_fill(1) },
        battle_menu_entry(:items_fill_key, t(TR[:fillbagkey])) { item_fill(2) },
        battle_menu_entry(:items_empty, t(TR[:emptybag])) { item_empty },
        battle_menu_entry(:items_export_ids, t(TR[:exportids])) { dump_ids(:Item, "Item_ID_List.txt") }
      ]
      render_dynamic_menu(t(TR[:items]).upcase, menu)
    end

    def item_add
      # Keep the engine's native ItemLister, including its original layout,
      # alphabetical ordering, numeric IDs and ItemIconSprite preview.
      if defined?(ItemLister) && defined?(pbListWindow) && defined?(Viewport)
        lister_instance = (ItemLister.new(0, false) rescue ItemLister.new(0))
        ::DeveloperMenu.dev_pbListScreenBlock(_INTL("ADD ITEM"), lister_instance) do |button, item|
          next unless list_confirm_button?(button) && item
          params = ChooseNumberParams.new
          max_slot = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:BAG_MAX_PER_SLOT) ? Settings::BAG_MAX_PER_SLOT : 999
          params.setRange(1, max_slot)
          params.setInitialValue(1)
          params.setCancelValue(0) if params.respond_to?(:setCancelValue)
          item_data = data_record(:Item, item)
          item_name = item_data && item_data.respond_to?(:name) ? item_data.name : item.to_s
          plural_name = item_data && item_data.respond_to?(:name_plural) ? item_data.name_plural : item_name
          qty = safe_choose_number(_INTL("Add how many {1}?", plural_name), params, "Add Item Quantity")
          next unless qty && qty > 0
          if bag_store_item_from_lookup(item, qty, item_name)
            safe_text_message(_INTL("Gave {1}x {2}.", qty, item_name), "Add Item Success")
          else
            safe_text_message(engine_failure_message("add #{item_name}"), "Add Item Failure")
          end
        end
        return
      end
      if respond_to?(:select_item_with_preview)
        current_item = nil
        loop do
          item = select_item_with_preview(current_item, _INTL("ADD ITEM"))
          break unless item
          current_item = item
          params = ChooseNumberParams.new
          max_slot = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:BAG_MAX_PER_SLOT) ? Settings::BAG_MAX_PER_SLOT : 999
          params.setRange(1, max_slot)
          params.setInitialValue(1)
          params.setCancelValue(0) if params.respond_to?(:setCancelValue)
          item_data = data_record(:Item, item)
          item_name = item_data && item_data.respond_to?(:name) ? item_data.name : item.to_s
          plural_name = item_data && item_data.respond_to?(:name_plural) ? item_data.name_plural : item_name
          qty = safe_choose_number(_INTL("Add how many {1}?", plural_name), params, "Add Item Quantity")
          next unless qty && qty > 0
          if bag_store_item_from_lookup(item, qty, item_name)
            safe_text_message(_INTL("Gave {1}x {2}.", qty, item_name), "Add Item Success")
          else
            safe_text_message(engine_failure_message("add #{item_name}"), "Add Item Failure")
          end
        end
        return
      end
      if defined?(pbListScreenBlock) && defined?(ItemLister)
        start_item = nil
        loop do
          search_term = nil
          reopen_with_search = false
          start_index = ::DeveloperMenu.get_item_lister_index(start_item) rescue 0
          lister_instance = (ItemLister.new(start_index, true) rescue ItemLister.new(start_index))
          ::DeveloperMenu.force_all_items_in_lister(lister_instance)
          ::DeveloperMenu.dev_pbListScreenBlock(_INTL("ADD ITEM"), lister_instance) do |button, item|
            if button == :SEARCH || ::DeveloperMenu.list_search_button?(button)
              start_item = item if item
              reopen_with_search = true
              break
            end
            next unless list_confirm_button?(button) && item
            params = ChooseNumberParams.new
            max_slot = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:BAG_MAX_PER_SLOT) ? Settings::BAG_MAX_PER_SLOT : 999
            params.setRange(1, max_slot)
            params.setInitialValue(1)
            params.setCancelValue(0) if params.respond_to?(:setCancelValue)
            item_name = begin
              GameData::Item.get(item).name_plural
            rescue
              "items"
            end
            qty = pbMessageChooseNumber(_INTL("Add how many {1}?", item_name), params)
            if qty > 0
              if defined?($bag) && $bag && $bag.respond_to?(:add)
                $bag.add(item, qty)
              else
                bag_store_item_from_lookup(item, qty, item_name)
              end
              name = begin
                GameData::Item.get(item).name
              rescue
                item.to_s
              end
              pbMessage(_INTL("Gave {1}x {2}.", qty, name))
            end
          end
          break unless reopen_with_search
          search_term = safe_free_text("Search items (name or ID):", "", false, 256, "Search Items")
          next if search_term.nil? || search_term.to_s.strip == ""
          new_idx = ::DeveloperMenu.get_item_lister_index(start_item) rescue 0
          lister = (ItemLister.new(new_idx, true) rescue ItemLister.new(new_idx)) rescue nil
          ::DeveloperMenu.force_all_items_in_lister(lister) if lister
          if lister
            jump_index = ::DeveloperMenu.item_lister_search_index(lister, search_term)
            if jump_index
              found_item = lister.value(jump_index) rescue nil
              start_item = found_item if found_item
            else
              Kernel.pbMessage(_INTL("No items matched that search."))
            end
          end
        end
        return
      end
      hash = build_search_hash(:Item)
      item_id = search_list("Items", hash)
      return if !item_id || (item_id.is_a?(Numeric) && item_id <= 0) || (item_id.is_a?(String) && item_id.to_s.strip.empty?)
      itm_sym = get_symbol(:Item, item_id)
      item_name = hash[item_id]
      params = ChooseNumberParams.new
      params.setRange(1, 999); params.setInitialValue(1)
      qty = Kernel.pbMessageChooseNumber(_INTL("Amount:"), params)
      if bag_store_item_from_lookup(itm_sym || item_id, qty, item_name)
        Kernel.pbMessage(_INTL("Gave {1}x {2}.", qty, item_display_name(itm_sym)))
      else
        fallback_name = item_name && item_name != "" ? item_name : item_display_name(itm_sym)
        log_item_debug("item_add_failed item_id=#{item_id.inspect} itm_sym=#{itm_sym.inspect} item_name=#{item_name.inspect} qty=#{qty}")
        Kernel.pbMessage(engine_failure_message("add #{fallback_name}"))
      end
    end

    def item_fill(mode)
      params = ChooseNumberParams.new
      max_slot = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:BAG_MAX_PER_SLOT) ? Settings::BAG_MAX_PER_SLOT : 999
      params.setRange(1, max_slot); params.setInitialValue(1)
      qty = Kernel.pbMessageChooseNumber(_INTL("Choose the number of items."), params)
      return if qty <= 0

      # Backup pockets to recover from failures
      backup_pockets = nil
      bag_obj = nil
      if defined?($bag) && $bag
        bag_obj = $bag
      elsif defined?($PokemonBag) && $PokemonBag
        bag_obj = $PokemonBag
      end
      if bag_obj
        begin
          backup_pockets = Marshal.load(Marshal.dump(bag_obj.instance_variable_get(:@pockets)))
        rescue
          # Fallback clone if Marshal fails
          pockets = bag_obj.instance_variable_get(:@pockets)
          if pockets.is_a?(Array)
            backup_pockets = pockets.map { |pocket| pocket.is_a?(Array) ? pocket.map(&:dup) : pocket }
          end
        end
      end

      # Rollback action
      rollback_action = proc do
        if bag_obj && backup_pockets
          begin
            bag_obj.instance_variable_set(:@pockets, backup_pockets)
          rescue => err
            log_error("Rollback Bag Pockets", err)
          end
        end
      end

      begin
        if mode == 0 && defined?($bag) && $bag && $bag.respond_to?(:pockets) &&
           defined?(GameData) && safe_const_get(GameData, :Item) && GameData::Item.respond_to?(:each) &&
           defined?(Settings) && Settings.const_defined?(:BAG_MAX_POCKET_SIZE)
          begin
            $bag.clear if $bag.respond_to?(:clear)
            pocket_sizes = Settings::BAG_MAX_POCKET_SIZE
            pockets = $bag.pockets
            added_count = 0
            GameData::Item.each do |item|
              pocket_index = item.respond_to?(:pocket) ? item.pocket.to_i : 0
              next if pocket_index <= 0
              max_size = pocket_sizes[pocket_index - 1]
              next if max_size.nil? || max_size == 0
              pocket = pockets[pocket_index]
              next unless pocket && pocket.respond_to?(:push)
              next if max_size > 0 && pocket.length >= max_size
              item_qty = item.respond_to?(:is_important?) && item.is_important? ? 1 : qty
              pocket.push([item.id, item_qty])
              added_count += 1
              Graphics.update if defined?(Graphics) && (added_count % 100) == 0
            end
            safe_text_message(_INTL("The Bag was filled with {1} of each item.", qty), "Fill Bag Complete")
            return true
          rescue => e
            log_error("Fast Fill Modern Bag", e)
            rollback_action.call
            safe_text_message("Fast fill failed; no slow fallback was attempted to avoid freezing the game.", "Fill Bag Failure")
            return false
          end
        end
        
        if mode == 0 && defined?($bag) && $bag && $bag.respond_to?(:clear)
          $bag.clear
        elsif mode == 0 && defined?($PokemonBag) && $PokemonBag && $PokemonBag.respond_to?(:clear)
          $PokemonBag.clear
        end
        hash = build_search_hash(:Item)
        added_count = 0
        failed_count = 0
        hash.each do |k, v|
          sym = get_symbol(:Item, k)
          is_key = false
          itm = data_record(:Item, sym)
          if itm
            if itm
              is_key = itm.is_key_item? if itm.respond_to?(:is_key_item?)
              is_key = itm.is_important? if itm.respond_to?(:is_important?) && !is_key
            end
          else
            if defined?(pbIsKeyItem?)
              begin
                is_key = pbIsKeyItem?(k)
                is_key = pbIsKeyItem?(sym) if !is_key
              rescue => e
                log_error("Legacy Key Item Check", e)
              end
            end
            begin
              is_key = ($ItemData[k][3] == 8) if !is_key && defined?($ItemData) && $ItemData
            rescue => e
              log_error("Legacy ItemData Check", e)
            end
          end
          
          next if mode == 1 && is_key
          next if mode == 2 && !is_key
          if bag_store_item_from_lookup(sym || k, qty, v)
            added_count += 1
          else
            failed_count += 1
          end
        end
        if added_count > 0
          if mode == 0
            Kernel.pbMessage(_INTL("The Bag was filled with {1} of each item.", qty))
          else
            Kernel.pbMessage(_INTL("Added items to the Bag. Success: {1}. Failed: {2}.", added_count, failed_count))
          end
        else
          Kernel.pbMessage(engine_failure_message("fill the bag"))
        end
      rescue => e
        log_error("Item Fill Failure", e)
        rollback_action.call
        safe_text_message("Item fill failed. The bag was restored to its original state.", "Item Fill Restored")
        false
      end
    end

    def item_empty
      return unless Kernel.pbConfirmMessage(_INTL("Empty Bag?"))
      cleared = false
      if defined?($bag) && $bag && $bag.respond_to?(:clear)
        $bag.clear
        cleared = true
      elsif defined?($PokemonBag) && $PokemonBag && $PokemonBag.respond_to?(:clear)
        $PokemonBag.clear
        cleared = true
      elsif defined?($PokemonBag) && $PokemonBag && $PokemonBag.respond_to?(:Clear)
        $PokemonBag.Clear
        cleared = true
      end
      if cleared
        Kernel.pbMessage(_INTL("The Bag was cleared."))
      else
        Kernel.pbMessage(engine_failure_message("empty the bag"))
      end
    end

    def menu_player
      menu = [
        battle_menu_entry(:player_quick_summary, t(TR[:quick_status])) { show_player_summary },
        battle_menu_entry(:player_edit_money, t(TR[:money])) { player_money_menu }
      ]

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:soot)
        menu.push(battle_menu_entry(:player_edit_ash, t(TR[:ash])) {
          params = ChooseNumberParams.new; params.setRange(0, 999999); params.setInitialValue($PokemonGlobal.soot || 0)
          new_soot = Kernel.pbMessageChooseNumber(_INTL("Ash (Soot):"), params)
          $PokemonGlobal.soot = new_soot
          Kernel.pbMessage(_INTL("Ash was set to {1}.", new_soot))
        })
      end

      menu.push(battle_menu_entry(:player_badges, t(TR[:badges])) { player_badges })
      
      menu.push(battle_menu_entry(:player_character, t(TR[:character])) { player_character_menu })

      menu.push(battle_menu_entry(:player_gender, t(TR[:gender])) {
        p = get_player
          p.gender = (p.gender == 0 ? 1 : 0) if p.respond_to?(:gender=)
        Kernel.pbMessage(_INTL("The player's gender was changed."))
      })

      menu.push(battle_menu_entry(:player_outfit, t(TR[:outfit])) { 
        p = get_player
        params = ChooseNumberParams.new
        params.setRange(0, 99); params.setInitialValue(p.outfit || 0)
        new_outfit = Kernel.pbMessageChooseNumber(_INTL("Outfit ID:"), params)
        if p.respond_to?(:outfit=)
          p.outfit = new_outfit
          $game_player.refresh if $game_player
          Kernel.pbMessage(_INTL("The player's outfit was changed."))
        end
      })
      
      menu.push(battle_menu_entry(:player_name, t(TR[:name])) { 
        p = get_player
        new_name = set_name_via_ui(p && p.respond_to?(:name) ? p.name : "")
        if set_player_name!(new_name)
          Kernel.pbMessage(_INTL("The player's name was changed to {1}.", new_name))
        elsif new_name && new_name != ""
          Kernel.pbMessage(engine_failure_message("change player name"))
        end
      })

      menu.push(battle_menu_entry(:player_trainer_id, t(TR[:trainerid])) { 
        params = ChooseNumberParams.new; params.setRange(0, 999999999); params.setInitialValue(player_trainer_id_value)
        new_id = Kernel.pbMessageChooseNumber(_INTL("New ID:"), params)
        if set_player_trainer_id!(new_id)
          Kernel.pbMessage(_INTL("The player's Trainer ID was changed to {1}.", new_id))
        else
          Kernel.pbMessage(engine_failure_message("change Trainer ID"))
        end
      })

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:runningShoes)
        menu.push(battle_menu_entry(:player_running_shoes, t(TR[:shoes])) {
          new_state = !running_shoes_enabled?
          if set_running_shoes_enabled!(new_state)
            if running_shoes_enabled?
              Kernel.pbMessage(_INTL("Gave Running Shoes."))
            else
              Kernel.pbMessage(_INTL("Lost Running Shoes."))
            end
          else
            Kernel.pbMessage(engine_failure_message("change Running Shoes"))
          end
        })
      end

      menu.push(battle_menu_entry(:player_pokedex, t(TR[:pokedex_tog])) {
        p = get_player
        if p && p.respond_to?(:pokedex) && p.pokedex && defined?(Settings) && safe_const_get(Object, :Settings) && Settings.respond_to?(:pokedex_names)
          dexescmd = 0
          loop do
            dexescmds = []
            dexescmds.push(_INTL("Have Pokedex: {1}", pokedex_enabled? ? "[YES]" : "[NO]"))
            dex_names = Settings.pokedex_names
            dex_names.length.times do |i|
              name = dex_names[i].is_a?(Array) ? dex_names[i][0] : dex_names[i]
              unlocked = p.pokedex.respond_to?(:unlocked?) ? p.pokedex.unlocked?(i) : false
              dexescmds.push((unlocked ? "[Y]" : "[  ]") + " " + name.to_s)
            end
            dexescmd = pbShowCommands(nil, dexescmds, -1, dexescmd)
            break if dexescmd < 0
            dexindex = dexescmd - 1
            if dexindex < 0
              set_pokedex_enabled!(!pokedex_enabled?)
            elsif p.pokedex.respond_to?(:unlocked?) && p.pokedex.unlocked?(dexindex)
              p.pokedex.lock(dexindex) if p.pokedex.respond_to?(:lock)
            else
              p.pokedex.unlock(dexindex) if p.pokedex.respond_to?(:unlock)
            end
          end
        else
          new_state = !pokedex_enabled?
          result = set_pokedex_enabled!(new_state)
          if result == false
            Kernel.pbMessage(engine_failure_message("change the Pokedex flag"))
          else
            Kernel.pbMessage(state_toggle_message("Pokedex", pokedex_enabled?))
          end
        end
      })

      menu.push(battle_menu_entry(:player_pokegear, t(TR[:pokegear])) {
        new_state = !pokegear_enabled?
        if set_pokegear_enabled!(new_state)
          if pokegear_enabled?
            Kernel.pbMessage(_INTL("Gave Pokegear."))
          else
            Kernel.pbMessage(_INTL("Lost Pokegear."))
          end
        else
          Kernel.pbMessage(engine_failure_message("change Pokegear"))
        end
      })

      menu.push(battle_menu_entry(:player_playtime, t(TR[:playtime])) {
        params = ChooseNumberParams.new; params.setRange(0, 99999)
        current_hours = Graphics.frame_count / frame_rate_value / 60 / 60 rescue 0
        params.setInitialValue(current_hours)
        hours = Kernel.pbMessageChooseNumber(_INTL("Play Time (Hours):"), params)
        if set_play_time_hours!(hours)
          Kernel.pbMessage(_INTL("The play time was set to {1} hours.", hours))
        else
          Kernel.pbMessage(engine_failure_message("change play time"))
        end
      })

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:region)
        menu.push(battle_menu_entry(:player_region, t(TR[:region])) {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.region || 0)
          new_region = Kernel.pbMessageChooseNumber(_INTL("Region ID:"), params)
          if set_region_value!(new_region)
            Kernel.pbMessage(_INTL("The region was changed to {1}.", new_region))
          else
            Kernel.pbMessage(engine_failure_message("change region"))
          end
        })
      end

      menu.push(battle_menu_entry(:player_complete_dex, t(TR[:pokedex])) {
        player_complete_dex
      })

      menu.push(battle_menu_entry(:player_phone_contacts, t(TR[:phone_contacts])) {
        player_phone_contacts
      })

      menu.push(battle_menu_entry(:player_box_link, t(TR[:box_link])) {
        p = get_player
        unless p && p.respond_to?(:has_box_link) && p.respond_to?(:has_box_link=)
          Kernel.pbMessage(engine_failure_message("toggle Box Link"))
          next
        end
        p.has_box_link = !p.has_box_link
        if p.has_box_link
          Kernel.pbMessage(_INTL("Enabled access to storage from the party screen."))
        else
          Kernel.pbMessage(_INTL("Disabled access to storage from the party screen."))
        end
      })

      menu.push(battle_menu_entry(:player_random_id, t(TR[:randomize_player_id])) {
        p = get_player
        unless p && p.respond_to?(:id=)
          Kernel.pbMessage(engine_failure_message("randomize player ID"))
          next
        end
        p.id = rand(2**16) | (rand(2**16) << 16)
        public_id = p.respond_to?(:public_ID) ? p.public_ID : p.id
        Kernel.pbMessage(_INTL("The player's ID was changed to {1} (full ID: {2}).", public_id, p.id))
      })

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:partner)
        menu.push(battle_menu_entry(:player_partner, t(TR[:partner])) {
          result = clear_partner_data!
          if result == true
            Kernel.pbMessage(_INTL("The partner was cleared."))
          elsif result == :empty
            Kernel.pbMessage(_INTL("You don't have a partner right now."))
          else
            Kernel.pbMessage(engine_failure_message("clear partner data"))
          end
        })
      end

      render_dynamic_menu(_INTL("{1} | {2} | ${3}", t(TR[:Player]).upcase, player_name_value, player_money_value), menu)
    end

    def player_money_menu
      p = get_player
      return Kernel.pbMessage(engine_failure_message("open money editor")) unless p
      cmd = 0
      loop do
        money_text = player_money_value.to_s
        money_text = player_money_value.to_s_formatted if player_money_value.respond_to?(:to_s_formatted)
        coins_text = player_coin_value.to_s
        coins_text = player_coin_value.to_s_formatted if player_coin_value.respond_to?(:to_s_formatted)
        bp_text = player_battle_points_value.to_s
        bp_text = player_battle_points_value.to_s_formatted if player_battle_points_value.respond_to?(:to_s_formatted)
        cmds = [
          _INTL("Money: ${1}", money_text),
          _INTL("Coins: {1}", coins_text),
          _INTL("Battle Points: {1}", bp_text)
        ]
        cmd = pbShowCommands(nil, cmds, -1, cmd)
        break if cmd < 0
        case cmd
        when 0
          params = ChooseNumberParams.new
          max_money = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:MAX_MONEY) ? Settings::MAX_MONEY : 9_999_999
          params.setRange(0, max_money)
          params.setDefaultValue(player_money_value) if params.respond_to?(:setDefaultValue)
          params.setInitialValue(player_money_value) if params.respond_to?(:setInitialValue)
          set_player_money!(pbMessageChooseNumber("\\ts[]" + _INTL("Set the player's money."), params))
        when 1
          params = ChooseNumberParams.new
          max_coins = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:MAX_COINS) ? Settings::MAX_COINS : 9_999_999
          params.setRange(0, max_coins)
          params.setDefaultValue(player_coin_value) if params.respond_to?(:setDefaultValue)
          params.setInitialValue(player_coin_value) if params.respond_to?(:setInitialValue)
          set_player_coins!(pbMessageChooseNumber("\\ts[]" + _INTL("Set the player's Coin amount."), params))
        when 2
          if p.respond_to?(:battle_points) || p.respond_to?(:battlePoints) || p.respond_to?(:bp)
            params = ChooseNumberParams.new
            max_bp = defined?(Settings) && safe_const_get(Object, :Settings) && Settings.const_defined?(:MAX_BATTLE_POINTS) ? Settings::MAX_BATTLE_POINTS : 9_999_999
            params.setRange(0, max_bp)
            params.setDefaultValue(player_battle_points_value) if params.respond_to?(:setDefaultValue)
            params.setInitialValue(player_battle_points_value) if params.respond_to?(:setInitialValue)
            set_player_battle_points!(pbMessageChooseNumber("\\ts[]" + _INTL("Set the player's BP amount."), params))
          else
            Kernel.pbMessage(_INTL("BP not supported."))
          end
        end
      end
    end

    def legacy_player_metadata_entries
      return [] unless defined?($cache) && $cache && $cache.respond_to?(:metadata)
      metadata = $cache.metadata
      return [] unless metadata.respond_to?(:[])
      players = metadata[:Players]
      return [] unless players.respond_to?(:each_with_index)
      entries = []
      players.each_with_index do |player, id|
        next unless player
        name = player.respond_to?(:[]) ? player[:name] : nil
        next if name.nil? || name.to_s == ""
        entries << [id, name.to_s]
      end
      entries
    rescue => e
      throttled_log_error("Legacy Player Metadata", e)
      []
    end

    def current_player_character_id(player = nil)
      player ||= get_player
      return player.character_ID if player && player.respond_to?(:character_ID)
      if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:playerID)
        return $PokemonGlobal.playerID
      end
      return player.metaID if player && player.respond_to?(:metaID)
      nil
    rescue
      nil
    end

    def apply_player_character_id!(new_id, player = nil)
      player ||= get_player
      if defined?(pbChangePlayer)
        result = pbChangePlayer(new_id)
        return false if result == false
      elsif player && player.respond_to?(:character_ID=)
        player.character_ID = new_id
      elsif player && player.respond_to?(:metaID=)
        player.metaID = new_id
        $PokemonGlobal.playerID = new_id if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:playerID=)
      else
        return false
      end
      $game_player.refresh if defined?($game_player) && $game_player && $game_player.respond_to?(:refresh)
      true
    rescue => e
      log_error("Apply Player Character", e)
      false
    end

    def player_character_menu
      player = get_player
      return Kernel.pbMessage(engine_failure_message("change the player character")) unless player
      entries = []

      if defined?(GameData) && safe_const_get(GameData, :PlayerMetadata) && GameData::PlayerMetadata.respond_to?(:each)
        GameData::PlayerMetadata.each do |record|
          next unless record && record.respond_to?(:id)
          label = record.respond_to?(:name) ? record.name.to_s : record.id.to_s
          label = record.id.to_s if label == ""
          entries << [record.id, label]
        end
      end
      entries = legacy_player_metadata_entries if entries.empty?

      if entries.empty?
        return Kernel.pbMessage(unsupported_feature_message("Player character metadata"))
      end
      if entries.length <= 1
        return Kernel.pbMessage(_INTL("There is only one player character defined."))
      end

      current_id = current_player_character_id(player)
      current_index = entries.index { |entry| entry[0] == current_id } || 0
      commands = entries.map { |entry| _INTL("{1}: {2}", entry[0], entry[1]) }
      choice = pbShowCommands(_INTL("Choose the new player character."), commands, -1, current_index)
      return false if choice < 0
      selected_id = entries[choice][0]
      return true if selected_id == current_id

      if apply_player_character_id!(selected_id, player)
        Kernel.pbMessage(_INTL("The player character was changed to {1}.", entries[choice][1]))
        true
      else
        Kernel.pbMessage(engine_failure_message("change the player character"))
        false
      end
    rescue => e
      log_error("Player Character", e)
      false
    end

    def player_phone_contacts
      return Kernel.pbMessage(_INTL("The phone is not defined.")) unless $PokemonGlobal && $PokemonGlobal.respond_to?(:phone) && $PokemonGlobal.phone
      return Kernel.pbMessage(unsupported_feature_message("Phone contacts")) unless defined?(Phone)
      cmd = 0
      loop do
        cmds = []
        time = $PokemonGlobal.phone.respond_to?(:time_to_next_call) ? $PokemonGlobal.phone.time_to_next_call.to_i : 0
        min = time / 60
        sec = time % 60
        cmds.push(_INTL("Time until next call: {1}m {2}s", min, sec))
        rematches_enabled = Phone.respond_to?(:rematches_enabled) ? Phone.rematches_enabled : false
        cmds.push((rematches_enabled ? "[Y]" : "[  ]") + " " + _INTL("Rematches possible"))
        rematch_variant = Phone.respond_to?(:rematch_variant) ? Phone.rematch_variant : 0
        cmds.push(_INTL("Maximum rematch version : {1}", rematch_variant))
        contacts = $PokemonGlobal.phone.respond_to?(:contacts) ? $PokemonGlobal.phone.contacts : []
        if contacts.length > 0
          cmds.push(_INTL("Make all contacts ready for a rematch"))
          cmds.push(_INTL("Edit individual contacts: {1}", contacts.length))
        end
        cmd = pbShowCommands(nil, cmds, -1, cmd)
        break if cmd < 0
        case cmd
        when 0
          params = ChooseNumberParams.new
          params.setRange(0, 99999)
          params.setDefaultValue(min) if params.respond_to?(:setDefaultValue)
          params.setInitialValue(min) if params.respond_to?(:setInitialValue)
          params.setCancelValue(-1) if params.respond_to?(:setCancelValue)
          new_time = pbMessageChooseNumber(_INTL("Set the time (in minutes) until the next phone call."), params)
          $PokemonGlobal.phone.time_to_next_call = new_time * 60 if new_time >= 0 && $PokemonGlobal.phone.respond_to?(:time_to_next_call=)
        when 1
          Phone.rematches_enabled = !rematches_enabled if Phone.respond_to?(:rematches_enabled=)
        when 2
          params = ChooseNumberParams.new
          params.setRange(0, 99)
          params.setDefaultValue(rematch_variant) if params.respond_to?(:setDefaultValue)
          params.setInitialValue(rematch_variant) if params.respond_to?(:setInitialValue)
          new_version = pbMessageChooseNumber(_INTL("Set the maximum version number a trainer contact can reach."), params)
          Phone.rematch_variant = new_version if Phone.respond_to?(:rematch_variant=)
        when 3
          contacts.each do |contact|
            next unless contact.respond_to?(:trainer?) && contact.trainer?
            contact.rematch_flag = 1 if contact.respond_to?(:rematch_flag=)
            contact.set_trainer_event_ready_for_rematch if contact.respond_to?(:set_trainer_event_ready_for_rematch)
          end
          pbMessage(_INTL("All trainers in the phone are now ready to rebattle."))
        when 4
          player_phone_contact_details(contacts)
        end
      end
    rescue => e
      log_error("Player Phone Contacts", e)
      Kernel.pbMessage(engine_failure_message("edit phone contacts"))
    end

    def player_phone_contact_details(contacts)
      contact_cmd = 0
      loop do
        contact_cmds = []
        contacts.each do |contact|
          visible_string = (contact.respond_to?(:visible?) && contact.visible?) ? "[Y]" : "[  ]"
          if contact.respond_to?(:trainer?) && contact.trainer?
            battle_string = (contact.respond_to?(:can_rematch?) && contact.can_rematch?) ? "(can battle)" : ""
            display_name = contact.respond_to?(:display_name) ? contact.display_name : "Contact"
            variant = contact.respond_to?(:variant) ? contact.variant : 0
            contact_cmds.push(sprintf("%s %s (%i) %s", visible_string, display_name, variant, battle_string))
          else
            display_name = contact.respond_to?(:display_name) ? contact.display_name : "Contact"
            contact_cmds.push(sprintf("%s %s", visible_string, display_name))
          end
        end
        contact_cmd = pbShowCommands(nil, contact_cmds, -1, contact_cmd)
        break if contact_cmd < 0
        contact = contacts[contact_cmd]
        edit_cmd = 0
        loop do
          edit_cmds = []
          edit_cmds.push((contact.respond_to?(:visible?) && contact.visible? ? "[Y]" : "[  ]") + " " + _INTL("Contact visible"))
          if contact.respond_to?(:trainer?) && contact.trainer?
            edit_cmds.push((contact.respond_to?(:can_rematch?) && contact.can_rematch? ? "[Y]" : "[  ]") + " " + _INTL("Can battle"))
            ready_time = contact.respond_to?(:time_to_ready) ? contact.time_to_ready.to_i : 0
            ready_min = ready_time / 60
            ready_sec = ready_time % 60
            edit_cmds.push(_INTL("Time until ready to battle: {1}m {2}s", ready_min, ready_sec))
            edit_cmds.push(_INTL("Last defeated version: {1}", contact.respond_to?(:variant) ? contact.variant : 0))
          end
          break if edit_cmds.length == 0
          edit_cmd = pbShowCommands(nil, edit_cmds, -1, edit_cmd)
          break if edit_cmd < 0
          case edit_cmd
          when 0
            if contact.respond_to?(:can_hide?) && contact.can_hide? && contact.respond_to?(:visible=)
              current = contact.respond_to?(:visible?) ? contact.visible? : false
              contact.visible = !current
            end
          when 1
            if contact.respond_to?(:rematch_flag=)
              current = contact.respond_to?(:can_rematch?) && contact.can_rematch?
              contact.rematch_flag = current ? 0 : 1
              contact.time_to_ready = 0 if !current && contact.respond_to?(:time_to_ready=)
            end
          when 2
            params = ChooseNumberParams.new
            params.setRange(0, 99999)
            ready_time = contact.respond_to?(:time_to_ready) ? contact.time_to_ready.to_i : 0
            ready_min = ready_time / 60
            params.setDefaultValue(ready_min) if params.respond_to?(:setDefaultValue)
            params.setInitialValue(ready_min) if params.respond_to?(:setInitialValue)
            params.setCancelValue(-1) if params.respond_to?(:setCancelValue)
            new_time = pbMessageChooseNumber(_INTL("Set the time (in minutes) until this trainer is ready to battle."), params)
            contact.time_to_ready = new_time * 60 if new_time >= 0 && contact.respond_to?(:time_to_ready=)
          when 3
            params = ChooseNumberParams.new
            params.setRange(0, 99)
            variant = contact.respond_to?(:variant) ? contact.variant : 0
            params.setDefaultValue(variant) if params.respond_to?(:setDefaultValue)
            params.setInitialValue(variant) if params.respond_to?(:setInitialValue)
            new_version = pbMessageChooseNumber(_INTL("Set the last defeated version number of this trainer."), params)
            if contact.respond_to?(:version=) && contact.respond_to?(:start_version)
              contact.version = contact.start_version + new_version
            end
          end
        end
      end
    end

    def player_complete_dex
      return unless Kernel.pbConfirmMessage(_INTL("Mark every Pokemon as Caught and Seen?"))
      Kernel.pbMessage(_INTL("Working..."))
      hash = build_search_hash(:Species)
      p = get_player
      hash.each do |k, v|
        sym = get_symbol(:Species, k)
        if p.respond_to?(:pokedex) && p.pokedex.respond_to?(:register)
          begin
            p.pokedex.register(sym)
            p.pokedex.register_caught(sym) if p.pokedex.respond_to?(:register_caught)
          rescue => e
            log_error("Register Pokedex", e)
          end
        else
          begin
            species_id = k
            if species_id.is_a?(Symbol) && defined?(PBSpecies)
              species_id = PBSpecies.const_get(species_id) rescue k
            end
            if species_id.is_a?(Integer) || (species_id.respond_to?(:to_i) && species_id.to_i > 0)
              $Trainer.seen[species_id.to_i] = true if $Trainer.respond_to?(:seen) && $Trainer.seen
              $Trainer.owned[species_id.to_i] = true if $Trainer.respond_to?(:owned) && $Trainer.owned
            end
          rescue => e
            log_error("Legacy Pokedex", e)
          end
        end
      end
      Kernel.pbMessage(_INTL("The Pokedex was completed."))
    end

    def player_badges
      badgecmd = 0
      loop do
        badgecmds = []
        badgecmds.push(_INTL("Give all"))
        badgecmds.push(_INTL("Remove all"))
        24.times do |i|
          badgecmds.push((get_player.badges[i] ? "[Y]" : "[  ]") + " " + _INTL("Badge {1}", i + 1))
        end
        badgecmd = pbShowCommands(nil, badgecmds, -1, badgecmd)
        break if badgecmd < 0
        case badgecmd
        when 0
          24.times { |i| get_player.badges[i] = true }
        when 1
          24.times { |i| get_player.badges[i] = false }
        else
          get_player.badges[badgecmd - 2] = !get_player.badges[badgecmd - 2]
        end
      end
    end
