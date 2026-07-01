    def menu_party
      p = get_player
      return Kernel.pbMessage(_INTL("Party is empty!")) unless p && p.respond_to?(:party) && p.party && !p.party.empty?
      
      loop do
        cmds = p.party.map { |pkmn| pokemon_party_label(pkmn) }
        cmds.push("Back")
        choice = Kernel.pbMessage(_INTL("Select Pokemon:"), cmds, -1)
        break if choice < 0 || choice == cmds.length - 1
        party_pokemon_menu(p.party[choice], choice)
      end
    end

    def party_pokemon_menu(pkmn, index)
      loop do
        menu = [
          { :label => "Quick Summary", :action => proc { show_pokemon_summary(pkmn) } },
          { :label => "HP / Status", :action => proc { party_hp(pkmn) } },
          { :label => "Level / Stats", :action => proc { party_stats(pkmn) } },
          { :label => "Moves", :action => proc { party_moves(pkmn) } },
          { :label => "Held Item", :action => proc { party_item(pkmn) } },
          { :label => "Ability", :action => proc { party_ability(pkmn) } },
          { :label => "Nature & Gender", :action => proc { party_nature_gender(pkmn) } },
          { :label => "Species & Form", :action => proc { party_species_form(pkmn) } },
          { :label => "Cosmetics & Ribbons", :action => proc { party_cosmetics(pkmn) } },
          { :label => "Discardable Flags", :action => proc { party_flags(pkmn) } },
          { :label => "Egg Options", :action => proc { party_egg(pkmn) } },
          { :label => "Export Preset", :action => proc { party_export_preset(pkmn) } },
          { :label => "Apply Preset", :action => proc { party_apply_preset(pkmn) } },
          { :label => "Duplicate", :action => proc { party_duplicate(pkmn) } },
          { :label => "Delete", :action => proc { party_delete(index); return :deleted } }
        ]
        
        options = menu.map { |item| item[:label] }
        options.push("Back")
        
        title = _INTL("{1} | Lv.{2} | {3}", pkmn.name, pokemon_level_value(pkmn), pokemon_status_label(pkmn))
        choice = Kernel.pbMessage(title, options, -1)
        break if choice < 0 || choice == options.length - 1
        
        res = nil
        safe_execute(menu[choice][:label]) do
          res = menu[choice][:action].call
        end
        break if res == :deleted
      end
    end

    def party_hp(pkmn)
      menu = [
        { :label => "Heal", :action => proc { heal_pokemon!(pkmn); Kernel.pbMessage(_INTL("{1} was healed.", pkmn.name)) } },
        { :label => "Edit HP", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 999999); params.setInitialValue(pkmn.hp)
          set_pokemon_hp!(pkmn, Kernel.pbMessageChooseNumber(_INTL("HP:"), params))
        }},
        { :label => "Faint", :action => proc { faint_pokemon!(pkmn) } },
        { :label => "Status Problem", :action => proc {
          status_hash = build_search_hash(:Status)
          status_id = search_list("Status", status_hash)
          if status_id
            sym = get_symbol(:Status, status_id)
            set_pokemon_status!(pkmn, sym)
          end
        }},
        { :label => "Clear Status", :action => proc {
          clear_pokemon_status!(pkmn)
          Kernel.pbMessage(_INTL("Status cleared for {1}.", pkmn.name))
        }},
        { :label => "Give Pokerus", :action => proc { pkmn.givePokerus if pkmn.respond_to?(:givePokerus); Kernel.pbMessage(_INTL("Infected with Pokerus!")) } },
        { :label => "Cure Pokerus", :action => proc { pkmn.pokerus = 0 if pkmn.respond_to?(:pokerus=); Kernel.pbMessage(_INTL("Pokerus cured for {1}.", pkmn.name)) } }
      ]
      render_dynamic_menu("HP / Status", menu)
    end

    def party_stats(pkmn)
      menu = [
        { :label => "Edit Level", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(1, 100); params.setInitialValue(pkmn.level)
          set_pokemon_level!(pkmn, Kernel.pbMessageChooseNumber(_INTL("Level:"), params))
        }},
        { :label => "Edit Experience", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 9999999); params.setInitialValue(pkmn.exp)
          set_pokemon_exp!(pkmn, Kernel.pbMessageChooseNumber(_INTL("Exp:"), params))
        }},
        { :label => "Advanced Stat Editor", :action => proc {
          party_advanced_stat_editor(pkmn)
        }},
        { :label => "Max IVs", :action => proc { 
          max_pokemon_ivs!(pkmn, 31)
          Kernel.pbMessage(_INTL("IVs Maxed!"))
        }},
        { :label => "Max EVs", :action => proc { 
          max_pokemon_evs!(pkmn, 252)
          Kernel.pbMessage(_INTL("EVs Maxed!"))
        }},
        { :label => "Edit Happiness", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 255); params.setInitialValue(pkmn.happiness)
          set_pokemon_happiness!(pkmn, Kernel.pbMessageChooseNumber(_INTL("Happiness:"), params))
        }},
        { :label => "Max Contest Stats", :action => proc {
          %w[beauty cool cute smart tough sheen].each { |s| pkmn.send("#{s}=", 255) if pkmn.respond_to?("#{s}=") }
          Kernel.pbMessage(_INTL("Contest stats maxed!"))
        }},
        { :label => "Randomize Personal ID", :action => proc {
          pkmn.personalID = rand(256) | (rand(256) << 8) | (rand(256) << 16) | (rand(256) << 24) if pkmn.respond_to?(:personalID=)
          Kernel.pbMessage(_INTL("New Personal ID generated!"))
        }}
      ]
      render_dynamic_menu("Level / Stats", menu)
    end

    def party_advanced_stat_editor(pkmn)
      loop do
        stat_defs = stat_editor_definitions
        cmds = advanced_stat_editor_lines(pkmn)
        cmds.push("Back")
        choice = Kernel.pbMessage(_INTL("Advanced Stat Editor"), cmds, -1)
        break if choice < 0 || choice >= stat_defs.length

        stat_def = stat_defs[choice]
        action = Kernel.pbMessage(_INTL("Edit {1}:", stat_def[:label]), ["IV", "EV", "Cancel"], -1)
        next if action < 0 || action >= 2

        current_value = (action == 0) ? pokemon_iv_value(pkmn, stat_def) : pokemon_ev_value(pkmn, stat_def)
        params = ChooseNumberParams.new
        params.setRange(0, 9999)
        params.setInitialValue(current_value || 0)
        new_value = Kernel.pbMessageChooseNumber(_INTL("{1} {2}:", stat_def[:label], action == 0 ? "IV" : "EV"), params)

        ok = if action == 0
          set_pokemon_iv_value!(pkmn, stat_def, new_value)
        else
          set_pokemon_ev_value!(pkmn, stat_def, new_value)
        end

        if ok
          Kernel.pbMessage(_INTL("{1} {2} set to {3}.", stat_def[:label], action == 0 ? "IV" : "EV", new_value))
        else
          Kernel.pbMessage(_INTL("Could not edit {1} {2} on this engine.", stat_def[:label], action == 0 ? "IV" : "EV"))
        end
      end
    end

    def party_moves(pkmn)
      menu = [
        { :label => "View Moveset", :action => proc {
          show_pokemon_moveset(pkmn)
        }},
        { :label => "Learn Move", :action => proc {
          hash = build_search_hash(:Move)
          move_id = search_list("Moves", hash)
          if move_id
            sym = get_symbol(:Move, move_id)
            result = teach_move_with_prompt!(pkmn, sym)
            if result && result != :native
              Kernel.pbMessage(_INTL("{1} learned {2}!", pkmn.name, move_display_name(sym)))
            end
          end
        }},
        { :label => "Forget Move", :action => proc {
          if !pkmn.respond_to?(:moves) || !pkmn.moves || pkmn.moves.empty?
            Kernel.pbMessage(_INTL("This Pokemon has no moves to forget."))
          else
            cmds = pkmn.moves.map { |m| m.name }
            cmds.push("Cancel")
            ch = Kernel.pbMessage(_INTL("Forget which move?"), cmds, -1)
            if ch >= 0 && ch < pkmn.moves.length
              forgotten_name = pkmn.moves[ch].name rescue _INTL("that move")
              if forget_move!(pkmn, ch)
                Kernel.pbMessage(_INTL("{1} forgot {2}!", pkmn.name, forgotten_name))
              end
            end
          end
        }},
        { :label => "Reset Moveset", :action => proc {
          reset_pokemon_moves!(pkmn)
          Kernel.pbMessage(_INTL("Moveset reset!"))
        }},
        { :label => "Save Current as Initial Moveset", :action => proc {
          record_pokemon_initial_moves!(pkmn)
          Kernel.pbMessage(_INTL("Moveset recorded as Initial!"))
        }},
        { :label => "Restore PP", :action => proc {
          restore_pokemon_pp!(pkmn)
          Kernel.pbMessage(_INTL("PP Restored!"))
        }},
        { :label => "Max PP Ups", :action => proc {
          max_pokemon_ppups!(pkmn, 3)
          Kernel.pbMessage(_INTL("PP Ups maxed!"))
        }}
      ]
      render_dynamic_menu("Moves", menu)
    end

    def party_item(pkmn)
      menu = [
        { :label => "View Current Item", :action => proc {
          Kernel.pbMessage(_INTL("Current held item: {1}", pokemon_item_name(pkmn)))
        }},
        { :label => "Set Held Item", :action => proc {
          hash = build_search_hash(:Item)
          item_id = search_list("Items", hash)
          if item_id
            sym = get_symbol(:Item, item_id)
            set_pokemon_item!(pkmn, sym)
          end
        }},
        { :label => "Remove Held Item", :action => proc {
          remove_pokemon_item!(pkmn)
        }}
      ]
      render_dynamic_menu("Held Item", menu)
    end

    def party_ability(pkmn)
      menu = [
        { :label => "View Current Ability", :action => proc {
          current_ability = pkmn.respond_to?(:ability) ? pkmn.ability : nil
          Kernel.pbMessage(_INTL("Current ability: {1}", ability_display_name(current_ability)))
        }},
        { :label => "Set Legal Ability", :action => proc {
          if set_pokemon_legal_ability!(pkmn)
            Kernel.pbMessage(_INTL("Ability set!"))
          else
            Kernel.pbMessage(_INTL("No legal abilities found."))
          end
        }},
        { :label => "Search Any Ability", :action => proc {
          hash = build_search_hash(:Ability)
          id = search_list("Abilities", hash)
          if id
            sym = get_symbol(:Ability, id)
            set_pokemon_ability!(pkmn, sym, 2)
          end
        }},
        { :label => "Reset Ability", :action => proc {
          reset_pokemon_ability!(pkmn)
          Kernel.pbMessage(_INTL("Ability reset!"))
        }},
        { :label => "Export Ability IDs", :action => proc {
          dump_ids(:Ability, "Ability_ID_List.txt")
        }}
      ]
      render_dynamic_menu("Ability", menu)
    end

    def party_nature_gender(pkmn)
      menu = [
        { :label => "Set Nature", :action => proc {
          hash = build_search_hash(:Nature)
          id = search_list("Natures", hash)
          if id
            sym = get_symbol(:Nature, id)
            set_pokemon_nature!(pkmn, sym)
          end
        }},
        { :label => "Set Legal Gender", :action => proc {
          if !genderless_pokemon?(pkmn)
            prompt_pokemon_gender!(pkmn)
          else
            Kernel.pbMessage(_INTL("Pokemon is genderless or not supported."))
          end
        }},
        { :label => "Force Gender (Male)", :action => proc { set_pokemon_gender!(pkmn, :male) } },
        { :label => "Force Gender (Female)", :action => proc { set_pokemon_gender!(pkmn, :female) } },
        { :label => "Force Gender (Genderless)", :action => proc { set_pokemon_gender!(pkmn, :genderless) } }
      ]
      render_dynamic_menu("Nature & Gender", menu)
    end

    def party_species_form(pkmn)
      menu = [
        { :label => "Change Species", :action => proc {
          hash = build_search_hash(:Species)
          id = search_list("Species", hash)
          if id
            sym = get_symbol(:Species, id)
            set_pokemon_species!(pkmn, sym)
          end
        }},
        { :label => "Change Form", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 50); params.setInitialValue(pkmn.form || 0)
          new_form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
          set_pokemon_form!(pkmn, new_form)
        }},
        { :label => "Remove Form Override", :action => proc {
          clear_pokemon_form_override!(pkmn)
          Kernel.pbMessage(_INTL("Override removed!"))
        }}
      ]
      render_dynamic_menu("Species & Form", menu)
    end

    def party_cosmetics(pkmn)
      menu = [
        { :label => "Set Nickname", :action => proc {
          rename_pokemon_via_ui!(pkmn)
        }},
        { :label => "Toggle Shiny", :action => proc {
          current = pkmn.respond_to?(:shiny?) ? pkmn.shiny? : (pkmn.respond_to?(:shiny) ? pkmn.shiny : false)
          set_pokemon_shiny!(pkmn, !current)
          Kernel.pbMessage(_INTL("Shiny: {1}", !current ? "ON" : "OFF"))
        }},
        { :label => "Set Poke ball", :action => proc {
          id = choose_poke_ball_id
          if id
            set_pokemon_ball!(pkmn, id)
          end
        }},
        { :label => "Add Ribbon", :action => proc {
          hash = build_search_hash(:Ribbon)
          id = search_list("Ribbons", hash)
          if id
            sym = get_symbol(:Ribbon, id)
            add_pokemon_ribbon!(pkmn, sym)
          end
        }},
        { :label => "Clear All Ribbons", :action => proc {
          clear_pokemon_ribbons!(pkmn)
          Kernel.pbMessage(_INTL("Ribbons cleared!"))
        }},
        { :label => "Change OT Name", :action => proc {
          rename_pokemon_ot_via_ui!(pkmn)
        }}
      ]
      render_dynamic_menu("Cosmetics & Ribbons", menu)
    end

    def party_flags(pkmn)
      menu = [
        { :label => "Toggle Cannot Store", :action => proc { pkmn.cannot_store = !pkmn.cannot_store if pkmn.respond_to?(:cannot_store=); Kernel.pbMessage(_INTL("Cannot Store: {1}", pkmn.respond_to?(:cannot_store) ? on_off_text(!!pkmn.cannot_store) : "N/A")) } },
        { :label => "Toggle Cannot Release", :action => proc { pkmn.cannot_release = !pkmn.cannot_release if pkmn.respond_to?(:cannot_release=); Kernel.pbMessage(_INTL("Cannot Release: {1}", pkmn.respond_to?(:cannot_release) ? on_off_text(!!pkmn.cannot_release) : "N/A")) } },
        { :label => "Toggle Cannot Trade", :action => proc { pkmn.cannot_trade = !pkmn.cannot_trade if pkmn.respond_to?(:cannot_trade=); Kernel.pbMessage(_INTL("Cannot Trade: {1}", pkmn.respond_to?(:cannot_trade) ? on_off_text(!!pkmn.cannot_trade) : "N/A")) } }
      ]
      render_dynamic_menu("Discardable Flags", menu)
    end

    def party_egg(pkmn)
      menu = [
        { :label => "Make Egg", :action => proc { 
          make_pokemon_egg!(pkmn)
          Kernel.pbMessage(_INTL("{1} was turned into an Egg.", pkmn.name))
        }},
        { :label => "Hatch Egg", :action => proc { 
          hatch_pokemon_egg!(pkmn)
          Kernel.pbMessage(_INTL("{1} hatched successfully.", pkmn.name))
        }},
        { :label => "1 Step to Hatch", :action => proc { 
          set_pokemon_hatch_steps!(pkmn, 1)
          Kernel.pbMessage(_INTL("{1} will hatch in 1 step.", pkmn.name))
        }}
      ]
      render_dynamic_menu("Egg Options", menu)
    end

    def party_duplicate(pkmn)
      return unless Kernel.pbConfirmMessage(_INTL("Duplicate {1}?", pkmn.name))
      clone = duplicate_pokemon(pkmn)
      return Kernel.pbMessage(_INTL("Could not duplicate this Pokemon.")) unless clone
      add_pkmn_silently(clone)
      Kernel.pbMessage(_INTL("Duplicated!"))
    end

    def party_export_preset(pkmn)
      if export_pokemon_preset(pkmn)
        Kernel.pbMessage(_INTL("Preset exported to {1}.", preset_file_path))
      else
        Kernel.pbMessage(_INTL("Could not export preset."))
      end
    end

    def party_apply_preset(pkmn)
      preset = import_pokemon_preset
      return Kernel.pbMessage(_INTL("Preset file not found.")) unless preset
      if apply_pokemon_preset!(pkmn, preset)
        Kernel.pbMessage(_INTL("Preset applied!"))
      else
        Kernel.pbMessage(_INTL("Could not apply preset."))
      end
    end

    def party_delete(index)
      return unless Kernel.pbConfirmMessage(_INTL("Permanently delete this Pokemon?"))
      get_player.party.delete_at(index)
      Kernel.pbMessage(_INTL("Pokemon deleted from party."))
    end
  end
