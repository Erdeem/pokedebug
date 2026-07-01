    def menu_pokemon
      menu = [
        { :label => "Quick Status", :action => proc { show_pokemon_menu_status } },
        { :label => t(TR[:FillPC]), :action => proc { pokemon_fill_storage } },
        { :label => t(TR[:ClearPC]), :action => proc { pokemon_clear_storage } },
        { :label => t(TR[:addboxes]), :action => proc { pokemon_expand_boxes } },
        { :label => t(TR[:quickhatch]), :action => proc { pokemon_quick_hatch } },
        { :label => t(TR[:addpkmn]), :action => proc { pokemon_add } },
        { :label => "Import Pokemon Preset", :action => proc { pokemon_import_preset } },
        { :label => "Open Native Pokemon Editor", :action => proc { open_native_pokemon_editor_for_party } },
        { :label => t(TR[:Heal]), :action => proc { heal_party } },
        { :label => t(TR[:exportids]), :action => proc { dump_ids(:Species, "Pokemon_ID_List.txt") } }
      ]
      render_dynamic_menu(_INTL("{1} | Party {2}/6", t(TR[:pokemon]).upcase, player_party.length), menu)
    end

    def pokemon_fill_storage
      return unless storage_available?
      return unless Kernel.pbConfirmMessage(_INTL("Fill ALL boxes with level 50 Pokemon (all detected forms)?"))
      box = 0; idx = 0
      added = 0
      hash = build_search_hash(:Species)
      
      Kernel.pbMessage(_INTL("Generating... This may take a while."))
      
      hash.each do |k, v|
        sp_sym = get_symbol(:Species, k)
        forms = species_forms(sp_sym)
        
        forms.each do |f|
          pkmn = create_pkmn(sp_sym, 50)
          next unless pkmn
          pkmn.form = f if pkmn.respond_to?(:form=)
          
          while storage_box_full?(box)
            box += 1
            break if box >= storage_max_boxes
          end
          break if box >= storage_max_boxes
          
          break unless set_storage_slot(box, idx, pkmn)
          added += 1
          idx += 1
          if idx >= storage_max_pokemon(box)
            idx = 0; box += 1
          end
        end
        break if box >= storage_max_boxes
      end
      if added > 0
        Kernel.pbMessage(_INTL("Added {1} Pokemon to storage.", added))
      else
        Kernel.pbMessage(_INTL("Could not add Pokemon to storage on this engine."))
      end
    end

    def pokemon_clear_storage
      return unless Kernel.pbConfirmMessage(_INTL("Delete EVERYTHING in PC?"))
      cleared = 0
      each_storage_index do |box, slot|
        cleared += 1 if set_storage_slot(box, slot, nil)
      end
      if cleared > 0
        Kernel.pbMessage(_INTL("PC Cleared!"))
      else
        Kernel.pbMessage(_INTL("Could not clear PC storage on this engine."))
      end
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
        Kernel.pbMessage(_INTL("Added {1} boxes!", qty))
      rescue => e
        log_error("Expand Boxes", e)
        Kernel.pbMessage(_INTL("API Error expanding boxes."))
      end
    end

    def pokemon_quick_hatch
      get_player.party.each do |p| 
        p.egg_steps = 1 if p && (p.respond_to?(:egg?) ? p.egg? : (p.respond_to?(:isEgg?) ? p.isEgg? : false))
      end
      Kernel.pbMessage(_INTL("Eggs will hatch in 1 step."))
    end

    def pokemon_add
      hash = build_search_hash(:Species)
      species_id = search_list("Species", hash)
      return if !species_id || species_id <= 0
      sp_sym = get_symbol(:Species, species_id)
      
      params = ChooseNumberParams.new
      params.setRange(1, 100); params.setInitialValue(50)
      level = Kernel.pbMessageChooseNumber(_INTL("Level:"), params)
      
      pkmn = create_pkmn(sp_sym, level)
      return unless pkmn
      
      params.setRange(0, 50); params.setInitialValue(0)
      form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
      set_pokemon_form!(pkmn, form) if form > 0

      if Kernel.pbMessage(_INTL("Shiny?"), ["No", "Yes"], -1) == 1
        set_pokemon_shiny!(pkmn, true)
      end
      
      # Advanced options for modern (v19+)
      if !genderless_pokemon?(pkmn)
        prompt_pokemon_gender!(pkmn) if Kernel.pbConfirmMessage(_INTL("Set Gender?"))
      end
      
      if Kernel.pbConfirmMessage(_INTL("Edit Ability?"))
        set_pokemon_legal_ability!(pkmn)
      end

      if Kernel.pbConfirmMessage(_INTL("Set Held Item?"))
        ihash = build_search_hash(:Item)
        i_id = search_list("Items", ihash)
        if i_id
          held_item = get_symbol(:Item, i_id)
          set_pokemon_item!(pkmn, held_item)
        end
      end

      n_hash = build_search_hash(:Nature)
      if !n_hash.empty? && Kernel.pbConfirmMessage(_INTL("Edit Nature?"))
        nat_id = search_list("Natures", n_hash)
        if nat_id
          sym = get_symbol(:Nature, nat_id)
          set_pokemon_nature!(pkmn, sym)
        end
      end

      if Kernel.pbConfirmMessage(_INTL("Max IVs (31)?"))
        set_all_ivs!(pkmn, 31)
      end

      if Kernel.pbConfirmMessage(_INTL("Max EVs (252)?"))
        set_all_evs!(pkmn, 252)
      end

      if Kernel.pbConfirmMessage(_INTL("Set Nickname?"))
        nickname = pbMessageFreeText(_INTL("Nickname:"), "", false, 20)
        set_pokemon_nickname!(pkmn, nickname)
      end

      if Kernel.pbConfirmMessage(_INTL("Set Poke ball?"))
        bid = choose_poke_ball_id
        if bid
          set_pokemon_ball!(pkmn, bid)
        end
      end

      if Kernel.pbConfirmMessage(_INTL("Set Original Trainer?"))
        default_ot = get_player && get_player.respond_to?(:name) ? get_player.name : ""
        ot = pbMessageFreeText(_INTL("OT Name:"), default_ot, false, 20)
        set_pokemon_ot_name!(pkmn, ot)
      end

      recalc_pokemon_stats(pkmn)
      if add_pkmn_silently(pkmn)
        Kernel.pbMessage(_INTL("Added {1} (Lv.{2})!", pkmn.name, pokemon_level_value(pkmn)))
      else
        Kernel.pbMessage(_INTL("Could not add {1} to the party on this engine.", pkmn.name))
      end
    end

    def pokemon_import_preset
      preset = import_pokemon_preset
      return Kernel.pbMessage(_INTL("Preset file not found.")) unless preset
      pkmn = create_pokemon_from_preset(preset)
      return Kernel.pbMessage(_INTL("Could not create Pokemon from preset.")) unless pkmn
      if add_pkmn_silently(pkmn)
        Kernel.pbMessage(_INTL("Pokemon imported from preset!"))
      else
        Kernel.pbMessage(_INTL("Could not add the imported Pokemon on this engine."))
      end
    end

    def menu_item
      menu = [
        { :label => t(TR[:additem]), :action => proc { item_add } },
        { :label => t(TR[:fillbag]), :action => proc { item_fill(0) } },
        { :label => t(TR[:fillbagnon]), :action => proc { item_fill(1) } },
        { :label => t(TR[:fillbagkey]), :action => proc { item_fill(2) } },
        { :label => t(TR[:emptybag]), :action => proc { item_empty } },
        { :label => t(TR[:exportids]), :action => proc { dump_ids(:Item, "Item_ID_List.txt") } }
      ]
      render_dynamic_menu(t(TR[:items]).upcase, menu)
    end

    def item_add
      hash = build_search_hash(:Item)
      item_id = search_list("Items", hash)
      return if !item_id || item_id <= 0
      itm_sym = get_symbol(:Item, item_id)
      params = ChooseNumberParams.new
      params.setRange(1, 999); params.setInitialValue(1)
      qty = Kernel.pbMessageChooseNumber(_INTL("Amount:"), params)
      if bag_store_item(itm_sym, qty)
        Kernel.pbMessage(_INTL("Added {1} x{2}.", item_display_name(itm_sym), qty))
      else
        Kernel.pbMessage(_INTL("Could not add {1} on this engine.", item_display_name(itm_sym)))
      end
    end

    def item_fill(mode)
      params = ChooseNumberParams.new
      params.setRange(1, 999); params.setInitialValue(99)
      qty = Kernel.pbMessageChooseNumber(_INTL("Quantity to add:"), params)
      return if qty <= 0
      
      Kernel.pbMessage(_INTL("Adding... This may take a while."))
      hash = build_search_hash(:Item)
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
        bag_store_item(sym, qty)
      end
      Kernel.pbMessage(_INTL("Bag Filled!"))
    end

    def item_empty
      return unless Kernel.pbConfirmMessage(_INTL("Empty Bag?"))
      if $PokemonBag.respond_to?(:clear)
        $PokemonBag.clear
      elsif $PokemonBag.respond_to?(:Clear)
        $PokemonBag.Clear
      end
    end

    def menu_player
      menu = [
        { :label => "Quick Summary", :action => proc { show_player_summary } },
        { :label => "Edit Money", :action => proc { 
          current_money = player_money_value
          params = ChooseNumberParams.new
          params.setRange(0, 9999999); params.setInitialValue(current_money)
          new_money = Kernel.pbMessageChooseNumber(_INTL("Money:"), params)
          if set_player_money!(new_money)
            Kernel.pbMessage(_INTL("Money set to {1}.", new_money))
          else
            Kernel.pbMessage(_INTL("Could not edit money on this engine."))
          end
        }},
        { :label => "Edit Coins", :action => proc { 
          current_coins = player_coin_value
          params = ChooseNumberParams.new
          params.setRange(0, 9999999); params.setInitialValue(current_coins)
          new_coins = Kernel.pbMessageChooseNumber(_INTL("Coins:"), params)
          if set_player_coins!(new_coins)
            Kernel.pbMessage(_INTL("Coins set to {1}.", new_coins))
          else
            Kernel.pbMessage(_INTL("Could not edit coins on this engine."))
          end
        }},
        { :label => "Edit Battle Points", :action => proc { 
          current_bp = player_battle_points_value
          if current_bp > 0 || (get_player && (get_player.respond_to?(:battle_points) || get_player.respond_to?(:battlePoints) || get_player.respond_to?(:bp)))
            params = ChooseNumberParams.new; params.setRange(0, 9999999); params.setInitialValue(current_bp)
            new_bp = Kernel.pbMessageChooseNumber(_INTL("Battle Points:"), params)
            if set_player_battle_points!(new_bp)
              Kernel.pbMessage(_INTL("Battle Points set to {1}.", new_bp))
            else
              Kernel.pbMessage(_INTL("Could not edit Battle Points on this engine."))
            end
          else
            Kernel.pbMessage(_INTL("BP not supported."))
          end
        }}
      ]

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:soot)
        menu.push({ :label => t(TR[:ash]), :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 999999); params.setInitialValue($PokemonGlobal.soot || 0)
          new_soot = Kernel.pbMessageChooseNumber(_INTL("Ash (Soot):"), params)
          $PokemonGlobal.soot = new_soot
          Kernel.pbMessage(_INTL("Ash set to {1}.", new_soot))
        }})
      end

      menu.push({ :label => t(TR[:badges]), :action => proc { player_badges } })
      
      menu.push({ :label => t(TR[:character]), :action => proc { 
        p = get_player
        params = ChooseNumberParams.new
        params.setRange(0, 99); params.setInitialValue(p.character_ID || 0)
        new_id = Kernel.pbMessageChooseNumber(_INTL("Character ID:"), params)
        if p.respond_to?(:character_ID=)
          p.character_ID = new_id
          $game_player.refresh if $game_player
          Kernel.pbMessage(_INTL("Character changed!"))
        end
      }})

      menu.push({ :label => t(TR[:gender]), :action => proc {
        p = get_player
        p.gender = (p.gender == 0 ? 1 : 0) if p.respond_to?(:gender=)
        Kernel.pbMessage(_INTL("Gender changed!"))
      }})

      menu.push({ :label => t(TR[:outfit]), :action => proc { 
        p = get_player
        params = ChooseNumberParams.new
        params.setRange(0, 99); params.setInitialValue(p.outfit || 0)
        new_outfit = Kernel.pbMessageChooseNumber(_INTL("Outfit ID:"), params)
        if p.respond_to?(:outfit=)
          p.outfit = new_outfit
          $game_player.refresh if $game_player
          Kernel.pbMessage(_INTL("Outfit changed!"))
        end
      }})
      
      menu.push({ :label => t(TR[:name]), :action => proc { 
        p = get_player
        new_name = set_name_via_ui(p && p.respond_to?(:name) ? p.name : "")
        if set_player_name!(new_name)
          Kernel.pbMessage(_INTL("Player name changed to {1}.", new_name))
        elsif new_name && new_name != ""
          Kernel.pbMessage(_INTL("Could not change player name on this engine."))
        end
      }})

      menu.push({ :label => t(TR[:trainerid]), :action => proc { 
        params = ChooseNumberParams.new; params.setRange(0, 999999999); params.setInitialValue(player_trainer_id_value)
        new_id = Kernel.pbMessageChooseNumber(_INTL("New ID:"), params)
        if set_player_trainer_id!(new_id)
          Kernel.pbMessage(_INTL("Trainer ID set to {1}.", new_id))
        else
          Kernel.pbMessage(_INTL("Could not change Trainer ID on this engine."))
        end
      }})

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:runningShoes)
        menu.push({ :label => t(TR[:shoes]), :action => proc {
          new_state = !running_shoes_enabled?
          if set_running_shoes_enabled!(new_state)
            Kernel.pbMessage(_INTL("Running Shoes: {1}", on_off_text(running_shoes_enabled?)))
          else
            Kernel.pbMessage(_INTL("Could not change Running Shoes on this engine."))
          end
        }})
      end

      menu.push({ :label => t(TR[:pokedex_tog]), :action => proc {
        new_state = !pokedex_enabled?
        result = set_pokedex_enabled!(new_state)
        if result == false
          Kernel.pbMessage(_INTL("Could not change the Pokedex flag on this engine."))
        else
          Kernel.pbMessage(_INTL("Pokedex: {1}", on_off_text(pokedex_enabled?)))
        end
      }})

      menu.push({ :label => t(TR[:pokegear]), :action => proc {
        new_state = !pokegear_enabled?
        if set_pokegear_enabled!(new_state)
          Kernel.pbMessage(_INTL("Pokegear: {1}", on_off_text(pokegear_enabled?)))
        else
          Kernel.pbMessage(_INTL("Could not change Pokegear on this engine."))
        end
      }})

      menu.push({ :label => t(TR[:playtime]), :action => proc {
        params = ChooseNumberParams.new; params.setRange(0, 99999)
        current_hours = Graphics.frame_count / frame_rate_value / 60 / 60 rescue 0
        params.setInitialValue(current_hours)
        hours = Kernel.pbMessageChooseNumber(_INTL("Play Time (Hours):"), params)
        if set_play_time_hours!(hours)
          Kernel.pbMessage(_INTL("Play Time set to {1} hours.", hours))
        else
          Kernel.pbMessage(_INTL("Could not change play time on this engine."))
        end
      }})

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:region)
        menu.push({ :label => t(TR[:region]), :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.region || 0)
          new_region = Kernel.pbMessageChooseNumber(_INTL("Region ID:"), params)
          if set_region_value!(new_region)
            Kernel.pbMessage(_INTL("Region set to {1}.", new_region))
          else
            Kernel.pbMessage(_INTL("Could not change region on this engine."))
          end
        }})
      end

      menu.push({ :label => t(TR[:pokedex]), :action => proc {
        player_complete_dex
      }})

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:partner)
        menu.push({ :label => t(TR[:partner]), :action => proc {
          result = clear_partner_data!
          if result == true
            Kernel.pbMessage(_INTL("Partner cleared!"))
          elsif result == :empty
            Kernel.pbMessage(_INTL("You don't have a partner right now."))
          else
            Kernel.pbMessage(_INTL("Could not clear partner data on this engine."))
          end
        }})
      end

      render_dynamic_menu(_INTL("{1} | {2} | ${3}", t(TR[:Player]).upcase, player_name_value, player_money_value), menu)
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
            $Trainer.seen[k] = true if $Trainer.respond_to?(:seen)
            $Trainer.owned[k] = true if $Trainer.respond_to?(:owned)
          rescue => e
            log_error("Legacy Pokedex", e)
          end
        end
      end
      Kernel.pbMessage(_INTL("Pokedex Completed!"))
    end

    def player_badges
      loop do
        cmds = []
        24.times do |i|
          cmds.push("Badge #{i+1}: #{get_player.badges[i] ? 'ON' : 'OFF'}")
        end
        cmds.push("Back")
        ch = Kernel.pbMessage(_INTL("Toggle Badges:"), cmds, -1)
        break if ch < 0 || ch == 24
        get_player.badges[ch] = !get_player.badges[ch]
      end
    end
