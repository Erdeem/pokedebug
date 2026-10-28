module DeveloperMenu
  class << self
    def menu_party
      p = get_player
      return Kernel.pbMessage(_INTL("Party is empty!")) unless p && p.respond_to?(:party) && p.party && !p.party.empty?
      if battle_scene_active? && !battle_access_enabled?(:party_select_pokemon)
        return safe_text_message("Party selection is disabled in battle.", "Party Select Disabled In Battle")
      end
      
      loop do
        cmds = p.party.map { |pkmn| pokemon_party_label(pkmn) }
        cmds.push(t(TR[:back]))
        choice = Kernel.pbMessage(_INTL("{1}", t(TR[:select_pokemon])), cmds, -1)
        break if choice < 0 || choice == cmds.length - 1
        party_pokemon_menu(p.party[choice], choice)
      end
    end

    def open_custom_pokemon_editor_for_party
      p = get_player
      return false unless p && p.respond_to?(:party) && p.party && !p.party.empty?
      loop do
        cmds = p.party.map { |pkmn| pokemon_party_label(pkmn) }
        cmds.push(menu_back_label)
        choice = Kernel.pbMessage(_INTL("Select Pokemon for the custom editor:"), cmds, -1)
        return false if choice < 0 || choice >= p.party.length
        result = party_pokemon_menu(p.party[choice], choice)
        return true if result != :deleted
      end
    rescue => e
      log_error("Open Custom Pokemon Editor", e)
      false
    end

    def party_pokemon_menu(pkmn, index)
      loop do
        menu = [
          battle_menu_entry(:party_quick_summary, t(TR[:quick_status])) { show_pokemon_summary(pkmn) },
          battle_menu_entry(:party_hp_status, t(TR[:hp_status])) { party_hp(pkmn) },
          battle_menu_entry(:party_level_stats, t(TR[:level_stats])) { party_stats(pkmn) },
          battle_menu_entry(:party_moves, t(TR[:moves_title])) { party_moves(pkmn) },
          battle_menu_entry(:party_held_item, t(TR[:held_item])) { party_item(pkmn) },
          battle_menu_entry(:party_ability, t(TR[:ability_title])) { party_ability(pkmn) },
          battle_menu_entry(:party_nature_gender, t(TR[:nature_gender])) { party_nature_gender(pkmn) },
          battle_menu_entry(:party_species_form, t(TR[:species_form])) { party_species_form(pkmn) },
          battle_menu_entry(:party_cosmetics, t(TR[:cosmetics_ribbons])) { party_cosmetics(pkmn) },
          battle_menu_entry(:party_flags, t(TR[:discardable_flags])) { party_flags(pkmn) },
          battle_menu_entry(:party_egg, t(TR[:egg_options])) { party_egg(pkmn) },
          battle_menu_entry(:party_export_preset, t(TR[:export_preset])) { party_export_preset(pkmn) },
          battle_menu_entry(:party_apply_preset, t(TR[:apply_preset])) { party_apply_preset(pkmn) },
          battle_menu_entry(:party_duplicate, t(TR[:duplicate])) { party_duplicate(pkmn) },
          battle_menu_entry(:party_delete, t(TR[:delete_label])) { party_delete(index); return :deleted }
        ]
        
        menu = battle_filter_menu_entries(menu)
        if menu.empty?
          safe_text_message("No party actions are enabled for battle use.", "Party Battle Menu Empty")
          break
        end

        options = menu.map { |item| item[:label] }
        options.push(t(TR[:back]))
        
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
        battle_menu_entry(:party_hp_heal, t(TR[:Heal])) {
          if heal_pokemon!(pkmn)
            notify_action_result(pkmn.name, true, "healed.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("heal #{pkmn.name}"))
          end
        },
        battle_menu_entry(:party_hp_edit, t(TR[:edit_hp])) {
          params = ChooseNumberParams.new; params.setRange(0, 999999); params.setInitialValue(pkmn.hp)
          new_hp = Kernel.pbMessageChooseNumber(_INTL("HP:"), params)
          if set_pokemon_hp!(pkmn, new_hp)
            notify_action_result("#{pkmn.name} HP", true, "set to #{pkmn.hp}.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("edit HP"))
          end
        },
        battle_menu_entry(:party_hp_faint, t(TR[:faint])) {
          if faint_pokemon!(pkmn)
            notify_action_result(pkmn.name, true, "fainted.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("faint #{pkmn.name}"))
          end
        },
        battle_menu_entry(:party_hp_status_problem, t(TR[:status_problem])) {
          status_hash = build_search_hash(:Status)
          status_id = search_list("Status", status_hash)
          if status_id
            sym = get_symbol(:Status, status_id)
            if set_pokemon_status!(pkmn, sym)
              notify_action_result("#{pkmn.name} Status", true, "changed to #{sym}.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("change status"))
            end
          end
        },
        battle_menu_entry(:party_hp_clear_status, t(TR[:clear_status])) {
          if clear_pokemon_status!(pkmn)
            notify_action_result("#{pkmn.name} Status", true, "cleared.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("clear status"))
          end
        },
        battle_menu_entry(:party_hp_give_pokerus, t(TR[:give_pokerus])) {
          if pkmn.respond_to?(:givePokerus)
            pkmn.givePokerus
            Kernel.pbMessage(_INTL("Infected with Pokerus!"))
          else
            Kernel.pbMessage(unsupported_feature_message("Pokerus"))
          end
        },
        battle_menu_entry(:party_hp_cure_pokerus, t(TR[:cure_pokerus])) {
          if pkmn.respond_to?(:pokerus=)
            pkmn.pokerus = 0
            notify_action_result("#{pkmn.name} Pokerus", true, "cured.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("cure Pokerus"))
          end
        }
      ]
      render_dynamic_menu(t(TR[:hp_status]), menu)
    end

    def party_stats(pkmn)
      menu = [
        battle_menu_entry(:party_stats_edit_level, t(TR[:edit_level])) { 
          params = ChooseNumberParams.new; params.setRange(1, 100); params.setInitialValue(pkmn.level)
          new_level = Kernel.pbMessageChooseNumber(_INTL("Level:"), params)
          if set_pokemon_level!(pkmn, new_level)
            notify_action_result("#{pkmn.name} Level", true, "set to #{new_level}.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("edit level"))
          end
        },
        battle_menu_entry(:party_stats_edit_exp, t(TR[:edit_experience])) { 
          params = ChooseNumberParams.new; params.setRange(0, 9999999); params.setInitialValue(pkmn.exp)
          new_exp = Kernel.pbMessageChooseNumber(_INTL("Exp:"), params)
          if set_pokemon_exp!(pkmn, new_exp)
            notify_action_result("#{pkmn.name} Experience", true, "set to #{new_exp}.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("edit experience"))
          end
        },
        battle_menu_entry(:party_stats_advanced, t(TR[:advanced_stat_editor])) {
          party_advanced_stat_editor(pkmn)
        },
        battle_menu_entry(:party_stats_max_ivs, t(TR[:max_ivs])) { 
          if max_pokemon_ivs!(pkmn, 31)
            notify_action_result("#{pkmn.name} IVs", true, "maxed!", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("max IVs"))
          end
        },
        battle_menu_entry(:party_stats_max_evs, t(TR[:max_evs])) { 
          if max_pokemon_evs!(pkmn, 252)
            notify_action_result("#{pkmn.name} EVs", true, "maxed!", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("max EVs"))
          end
        },
        battle_menu_entry(:party_stats_happiness, t(TR[:edit_happiness])) { 
          params = ChooseNumberParams.new; params.setRange(0, 255); params.setInitialValue(pkmn.happiness)
          new_happiness = Kernel.pbMessageChooseNumber(_INTL("Happiness:"), params)
          if set_pokemon_happiness!(pkmn, new_happiness)
            notify_action_result("#{pkmn.name} Happiness", true, "set to #{new_happiness}.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("edit happiness"))
          end
        },
        battle_menu_entry(:party_stats_contest, t(TR[:max_contest_stats])) {
          %w[beauty cool cute smart tough sheen].each { |s| pkmn.send("#{s}=", 255) if pkmn.respond_to?("#{s}=") }
          notify_action_result("#{pkmn.name} Contest Stats", true, "maxed!", "failed.")
        },
        battle_menu_entry(:party_stats_personal_id, t(TR[:randomize_personal_id])) {
          pkmn.personalID = rand(256) | (rand(256) << 8) | (rand(256) << 16) | (rand(256) << 24) if pkmn.respond_to?(:personalID=)
          notify_action_result("#{pkmn.name} Personal ID", true, "randomized.", "failed.")
        }
      ]
      render_dynamic_menu(t(TR[:level_stats]), menu)
    end

    def party_advanced_stat_editor(pkmn)
      loop do
        stat_defs = stat_editor_definitions
        bulk_action_count = 2
        cmds = [t(TR[:set_all_ivs]), t(TR[:set_all_evs])]
        cmds.concat(advanced_stat_editor_lines(pkmn))
        cmds.push(t(TR[:back]))
        choice = Kernel.pbMessage(_INTL("Advanced Stat Editor"), cmds, -1)
        break if choice < 0 || choice >= bulk_action_count + stat_defs.length

        if choice < bulk_action_count
          collection_label = choice == 0 ? "IV" : "EV"
          params = ChooseNumberParams.new
          params.setRange(0, 9999)
          params.setInitialValue(choice == 0 ? classic_iv_limit : classic_ev_limit_per_stat)
          new_value = Kernel.pbMessageChooseNumber(_INTL("All {1}s:", collection_label), params)
          ok = choice == 0 ? set_all_ivs!(pkmn, new_value) : set_all_evs!(pkmn, new_value)
          if ok
            notify_action_result("#{pkmn.name} #{collection_label}s", true, "all set to #{new_value}.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("set all #{collection_label}s"))
          end
          next
        end

        stat_def = stat_defs[choice - bulk_action_count]
        action = Kernel.pbMessage(_INTL("Edit {1}:", stat_def[:label]), ["IV", "EV", menu_back_label], -1)
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
          notify_action_result("#{stat_def[:label]} #{action == 0 ? 'IV' : 'EV'}", true, "set to #{new_value}.", "failed.")
        else
          Kernel.pbMessage(engine_failure_message("edit #{stat_def[:label]} #{action == 0 ? 'IV' : 'EV'}"))
        end
      end
    end

    def party_moves(pkmn)
      menu = [
        battle_menu_entry(:party_moves_view, t(TR[:view_moveset])) {
          show_pokemon_moveset(pkmn)
        },
        battle_menu_entry(:party_moves_learn, t(TR[:learn_move])) {
          hash = build_search_hash(:Move)
          move_id = search_list("Moves", hash)
          if move_id
            sym = get_symbol(:Move, move_id)
            result = teach_move_with_prompt!(pkmn, sym)
            if result && result != :native
              notify_action_result(pkmn.name, true, "learned #{move_display_name(sym)}.", "failed.")
            elsif result == :native
              notify_action_result(pkmn.name, true, "learned #{move_display_name(sym)}.", "failed.")
            elsif result == :already_known
              Kernel.pbMessage(_INTL("{1} already knows {2}.", pkmn.name, move_display_name(sym)))
            else
              Kernel.pbMessage(engine_failure_message("teach #{move_display_name(sym)}"))
            end
          end
        },
        battle_menu_entry(:party_moves_forget, t(TR[:forget_move])) {
          if !pkmn.respond_to?(:moves) || !pkmn.moves || pkmn.moves.empty?
            Kernel.pbMessage(_INTL("This Pokemon has no moves to forget."))
          else
            cmds = pkmn.moves.map { |m| m.name }
            cmds.push(menu_back_label)
            ch = Kernel.pbMessage(_INTL("Forget which move?"), cmds, -1)
            if ch >= 0 && ch < pkmn.moves.length
              forgotten_name = pkmn.moves[ch].name rescue _INTL("that move")
              if forget_move!(pkmn, ch)
                notify_action_result(pkmn.name, true, "forgot #{forgotten_name}.", "failed.")
              else
                Kernel.pbMessage(engine_failure_message("forget that move"))
              end
            end
          end
        },
        battle_menu_entry(:party_moves_reset, t(TR[:reset_moveset])) {
          if reset_pokemon_moves!(pkmn)
            notify_action_result("#{pkmn.name} Moveset", true, "reset!", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("reset moveset"))
          end
        },
        battle_menu_entry(:party_moves_save_initial, t(TR[:save_initial_moveset])) {
          if record_pokemon_initial_moves!(pkmn)
            notify_action_result("#{pkmn.name} Moveset", true, "saved as initial.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("record initial moves"))
          end
        },
        battle_menu_entry(:party_moves_custom_pp, t(TR[:edit_custom_pp])) {
          move_entries = []
          each_move_slot(pkmn) { |move, index| move_entries << [move, index] if move }
          if move_entries.empty?
            Kernel.pbMessage(_INTL("This Pokemon has no moves to edit."))
          else
            action_commands = [
              t(TR[:edit_one_pp_limit]),
              t(TR[:set_all_pp_limits]),
              t(TR[:clear_custom_pp_limits]),
              menu_back_label
            ]
            action = Kernel.pbMessage(_INTL("Custom PP limits are preserved after healing."), action_commands, -1)
            if action == 0
              commands = move_entries.map do |entry|
                move = entry[0]
                current_pp = pokemon_move_pp_value(move)
                total_pp = pokemon_move_total_pp_value(move)
                custom_pp = pokemon_move_custom_pp_limit(move)
                pp_text = total_pp.nil? ? current_pp.to_s : "#{current_pp}/#{total_pp}"
                pp_text += " (Custom)" if custom_pp
                move_name = move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))
                _INTL("{1} - PP {2}", move_name, pp_text)
              end
              commands.push(menu_back_label)
              choice = Kernel.pbMessage(_INTL("Edit the PP limit of which move?"), commands, -1)
              if choice >= 0 && choice < move_entries.length
                move = move_entries[choice][0]
                move_index = move_entries[choice][1]
                move_name = move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))
                current_limit = pokemon_move_total_pp_value(move)
                params = ChooseNumberParams.new
                params.setRange(1, 9999)
                params.setInitialValue([[current_limit.to_i, 1].max, 9999].min)
                new_pp = Kernel.pbMessageChooseNumber(_INTL("New PP limit for {1}:", move_name), params)
                if set_pokemon_move_pp_limit!(pkmn, move, move_index, new_pp)
                  notify_action_result(move_name, true, "PP limit set to #{new_pp}.", "failed.")
                else
                  Kernel.pbMessage(engine_failure_message("edit move PP limit"))
                end
              end
            elsif action == 1
              params = ChooseNumberParams.new
              params.setRange(1, 9999)
              first_limit = pokemon_move_total_pp_value(move_entries[0][0])
              params.setInitialValue([[first_limit.to_i, 1].max, 9999].min)
              new_pp = Kernel.pbMessageChooseNumber(_INTL("New PP limit for all moves:"), params)
              if set_all_pokemon_move_pp_limits!(pkmn, new_pp)
                notify_action_result(pkmn.name, true, "all move PP limits set to #{new_pp}.", "failed.")
              else
                Kernel.pbMessage(engine_failure_message("edit all move PP limits"))
              end
            elsif action == 2
              if clear_pokemon_move_pp_limits!(pkmn)
                notify_action_result(pkmn.name, true, "custom PP limits removed.", "failed.")
              else
                Kernel.pbMessage(_INTL("This Pokemon has no custom PP limits."))
              end
            end
          end
        },
        battle_menu_entry(:party_moves_restore_pp, t(TR[:restore_pp])) {
          if restore_pokemon_pp!(pkmn)
            notify_action_result("#{pkmn.name} PP", true, "restored.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("restore PP"))
          end
        },
        battle_menu_entry(:party_moves_max_ppups, t(TR[:max_pp_ups])) {
          if max_pokemon_ppups!(pkmn, 3)
            notify_action_result("#{pkmn.name} PP Ups", true, "maxed!", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("edit PP Ups"))
          end
        }
      ]
      render_dynamic_menu(t(TR[:moves_title]), menu)
    end

    def party_item(pkmn)
      menu = [
        battle_menu_entry(:party_item_view, t(TR[:view_current_item])) {
          Kernel.pbMessage(_INTL("Current held item: {1}", pokemon_item_name(pkmn)))
        },
        battle_menu_entry(:party_item_set, t(TR[:set_held_item])) {
          hash = build_search_hash(:Item)
          item_id = search_list("Items", hash)
          if item_id
            sym = get_symbol(:Item, item_id)
            item_name = hash[item_id]
            if set_pokemon_item_from_lookup!(pkmn, sym || item_id, item_name)
              notify_action_result("#{pkmn.name} Item", true, "set to #{item_display_name(sym)}.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("set held item"))
            end
          end
        },
        battle_menu_entry(:party_item_remove, t(TR[:remove_held_item])) {
          if remove_pokemon_item!(pkmn)
            notify_action_result("#{pkmn.name} Item", true, "removed.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("remove held item"))
          end
        }
      ]
      render_dynamic_menu(t(TR[:held_item]), menu)
    end

    def party_ability(pkmn)
      menu = [
        battle_menu_entry(:party_ability_view, t(TR[:view_current_ability])) {
          current_ability = pkmn.respond_to?(:ability) ? pkmn.ability : nil
          Kernel.pbMessage(_INTL("Current ability: {1}", ability_display_name(current_ability)))
        },
        battle_menu_entry(:party_ability_set_legal, t(TR[:set_legal_ability])) {
          if set_pokemon_legal_ability!(pkmn)
            notify_action_result("#{pkmn.name} Ability", true, "updated.", "failed.")
          else
            Kernel.pbMessage(_INTL("No legal abilities found."))
          end
        },
        battle_menu_entry(:party_ability_slot, t(TR[:set_ability_slot])) {
          slot_cmds = ["Slot 1 (Ability 1)", "Slot 2 (Ability 2)", "Slot 3 / Hidden (Ability Oculta)"]
          slot_choice = Kernel.pbMessage(_INTL("Select Ability Slot:"), slot_cmds, -1)
          if slot_choice >= 0
            if set_pokemon_ability_slot!(pkmn, slot_choice)
              curr_ab = pkmn.respond_to?(:ability) ? pkmn.ability : nil
              notify_action_result("#{pkmn.name} Ability Slot", true, "set to #{slot_choice} (#{ability_display_name(curr_ab)}).", "failed.")
            else
              Kernel.pbMessage(unsupported_feature_message("Ability Slot setting"))
            end
          end
        },
        battle_menu_entry(:party_ability_search_any, t(TR[:search_any_ability])) {
          hash = build_search_hash(:Ability)
          id = search_list("Abilities", hash)
          if id
            sym = get_symbol(:Ability, id)
            ability_name = hash[id]
            if set_pokemon_ability_from_lookup!(pkmn, sym || id, ability_name, nil)
              notify_action_result("#{pkmn.name} Ability", true, "set to #{ability_display_name(sym || id)}.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("set ability"))
            end
          end
        },
        battle_menu_entry(:party_ability_reset, t(TR[:reset_ability])) {
          if reset_pokemon_ability!(pkmn)
            notify_action_result("#{pkmn.name} Ability", true, "reset.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("reset ability"))
          end
        },
        battle_menu_entry(:party_ability_export_ids, t(TR[:export_ability_ids])) {
          dump_ids(:Ability, "Ability_ID_List.txt")
        }
      ]
      render_dynamic_menu(t(TR[:ability_title]), menu)
    end

    def party_nature_gender(pkmn)
      menu = [
        simple_menu_action(t(TR[:set_nature])) do
          hash = build_search_hash(:Nature)
          id = search_list("Natures", hash)
          if id
            sym = get_symbol(:Nature, id)
            if set_pokemon_nature!(pkmn, sym)
              notify_action_result("#{pkmn.name} Nature", true, "set to #{sym}.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("change nature"))
            end
          end
        end,
        simple_menu_action(t(TR[:set_legal_gender])) do
          if !genderless_pokemon?(pkmn)
            prompt_pokemon_gender!(pkmn)
          else
            Kernel.pbMessage(_INTL("Pokemon is genderless or not supported."))
          end
        end,
        simple_menu_action(t(TR[:force_gender_male])) do
          if set_pokemon_gender!(pkmn, :male)
            notify_action_result("#{pkmn.name} Gender", true, "forced to male.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("force gender"))
          end
        end,
        simple_menu_action(t(TR[:force_gender_female])) do
          if set_pokemon_gender!(pkmn, :female)
            notify_action_result("#{pkmn.name} Gender", true, "forced to female.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("force gender"))
          end
        end,
        simple_menu_action(t(TR[:force_gender_genderless])) do
          if set_pokemon_gender!(pkmn, :genderless)
            notify_action_result("#{pkmn.name} Gender", true, "forced to genderless.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("force gender"))
          end
        end
      ]
      render_dynamic_menu(t(TR[:nature_gender]), menu)
    end

    def party_species_form(pkmn)
      menu = [
        simple_menu_action(t(TR[:change_species])) do
          hash = build_search_hash(:Species)
          id = search_list("Species", hash)
          if id
            sym = get_symbol(:Species, id)
            if set_pokemon_species!(pkmn, sym)
              notify_action_result(pkmn.name, true, "species changed to #{pokemon_species_name(pkmn)}.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("change species"))
            end
          end
        end,
        simple_menu_action(t(TR[:change_form])) do
          params = ChooseNumberParams.new; params.setRange(0, 50); params.setInitialValue(pkmn.form || 0)
          new_form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
          if set_pokemon_form!(pkmn, new_form)
            notify_action_result("#{pkmn.name} Form", true, "set to #{new_form}.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("change form"))
          end
        end,
        simple_menu_action(t(TR[:set_form_override])) do
          current_ov = respond_to?(:pokemon_form_override_value) ? pokemon_form_override_value(pkmn) : nil
          default_v = current_ov.nil? ? (pkmn.form || 0) : current_ov
          params = ChooseNumberParams.new; params.setRange(0, 50); params.setInitialValue(default_v)
          form_id = Kernel.pbMessageChooseNumber(_INTL("Lock Pokemon to Form ID:"), params)
          if set_pokemon_form_override!(pkmn, form_id)
            notify_action_result("#{pkmn.name} Form Lock", true, "locked to form #{form_id} permanently.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("set form override"))
          end
        end,
        simple_menu_action(t(TR[:remove_form_override])) do
          if clear_pokemon_form_override!(pkmn)
            notify_action_result("#{pkmn.name} Form Override", true, "removed.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("remove form override"))
          end
        end
      ]
      render_dynamic_menu(t(TR[:species_form]), menu)
    end

    def party_cosmetics(pkmn)
      menu = [
        simple_menu_action(t(TR[:set_nickname])) do
          rename_pokemon_via_ui!(pkmn)
        end,
        simple_menu_action(t(TR[:toggle_shiny])) do
          current = pokemon_shiny_state(pkmn)
          if set_pokemon_shiny!(pkmn, !current)
            Kernel.pbMessage(state_toggle_message("#{pkmn.name} Shiny", !current))
          else
            Kernel.pbMessage(engine_failure_message("change shiny state"))
          end
        end,
        simple_menu_action(t(TR[:set_poke_ball])) do
          id = choose_poke_ball_id
          if id
            if set_pokemon_ball!(pkmn, id)
              notify_action_result("#{pkmn.name} Poke Ball", true, "updated.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("change Poke Ball"))
            end
          end
        end,
        simple_menu_action(t(TR[:add_ribbon])) do
          hash = build_search_hash(:Ribbon)
          id = search_list("Ribbons", hash)
          if id
            sym = get_symbol(:Ribbon, id)
            if add_pokemon_ribbon!(pkmn, sym)
              notify_action_result("#{pkmn.name} Ribbon", true, "added.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("add ribbon"))
            end
          end
        end,
        simple_menu_action(t(TR[:clear_all_ribbons])) do
          if clear_pokemon_ribbons!(pkmn)
            notify_action_result("#{pkmn.name} Ribbons", true, "cleared!", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("clear ribbons"))
          end
        end,
        simple_menu_action(t(TR[:change_ot_name])) do
          rename_pokemon_ot_via_ui!(pkmn)
        end
      ]
      render_dynamic_menu(t(TR[:cosmetics_ribbons]), menu)
    end

    def party_flags(pkmn)
      menu = [
        simple_menu_action(t(TR[:set_tera_type])) do
          if pkmn.respond_to?(:tera_type=) || pkmn.respond_to?(:forced_tera_type=)
            current_tera = pokemon_tera_type(pkmn)
            type_hash = build_search_hash(:Type)
            type_id = search_list("Tera Types", type_hash)
            if type_id
              sym = get_symbol(:Type, type_id)
              if set_pokemon_tera_type!(pkmn, sym)
                notify_action_result("#{pkmn.name} Tera Type", true, "set to #{sym}.", "failed.")
              else
                Kernel.pbMessage(engine_failure_message("set Tera Type"))
              end
            end
          else
            Kernel.pbMessage(unsupported_feature_message("Tera Type (Gen 9)"))
          end
        end,
        simple_menu_action(t(TR[:toggle_gmax])) do
          if pkmn.respond_to?(:gmax_factor=) || pkmn.respond_to?(:giveGmaxFactor)
            current_gmax = pokemon_gmax_factor?(pkmn)
            if set_pokemon_gmax_factor!(pkmn, !current_gmax)
              Kernel.pbMessage(state_toggle_message("#{pkmn.name} Gigantamax Factor", !current_gmax))
            else
              Kernel.pbMessage(engine_failure_message("toggle Gigantamax Factor"))
            end
          else
            Kernel.pbMessage(unsupported_feature_message("Gigantamax Factor (Gen 8)"))
          end
        end,
        simple_menu_action(t(TR[:toggle_shadow])) do
          if pkmn.respond_to?(:shadowPokemon?) || pkmn.respond_to?(:makeShadow) || pkmn.respond_to?(:shadow=)
            current_shadow = pokemon_shadow?(pkmn)
            if set_pokemon_shadow!(pkmn, !current_shadow)
              Kernel.pbMessage(state_toggle_message("#{pkmn.name} Shadow State", !current_shadow))
            else
              Kernel.pbMessage(engine_failure_message("toggle Shadow State"))
            end
          else
            Kernel.pbMessage(unsupported_feature_message("Shadow Pokemon"))
          end
        end,
        simple_menu_action(t(TR[:edit_heart_gauge])) do
          if pkmn.respond_to?(:heartgauge) || pkmn.respond_to?(:heart_gauge)
            params = ChooseNumberParams.new; params.setRange(0, 30000); params.setInitialValue(pokemon_heart_gauge(pkmn) || 0)
            new_heart = Kernel.pbMessageChooseNumber(_INTL("Heart Gauge:"), params)
            if set_pokemon_heart_gauge!(pkmn, new_heart)
              notify_action_result("#{pkmn.name} Heart Gauge", true, "set to #{new_heart}.", "failed.")
            else
              Kernel.pbMessage(engine_failure_message("edit Heart Gauge"))
            end
          else
            Kernel.pbMessage(unsupported_feature_message("Heart Gauge"))
          end
        end,
        simple_menu_action(t(TR[:toggle_fateful])) do
          current_fateful = pokemon_fateful_encounter?(pkmn)
          if set_pokemon_fateful_encounter!(pkmn, !current_fateful)
            Kernel.pbMessage(state_toggle_message("#{pkmn.name} Fateful Encounter", !current_fateful))
          else
            Kernel.pbMessage(engine_failure_message("toggle Fateful Encounter"))
          end
        end,
        simple_menu_action(t(TR[:fix_obedience])) do
          if make_pokemon_obedient!(pkmn)
            notify_action_result("#{pkmn.name} Obedience", true, "now treats you as original trainer!", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("adjust obedience"))
          end
        end,
        simple_menu_action(t(TR[:toggle_cannot_store])) do
          if pkmn.respond_to?(:cannot_store=)
            pkmn.cannot_store = !pkmn.cannot_store
            Kernel.pbMessage(state_toggle_message("Cannot Store", pkmn.respond_to?(:cannot_store) ? !!pkmn.cannot_store : false))
          else
            Kernel.pbMessage(unsupported_feature_message("Cannot Store flag"))
          end
        end,
        simple_menu_action(t(TR[:toggle_cannot_release])) do
          if pkmn.respond_to?(:cannot_release=)
            pkmn.cannot_release = !pkmn.cannot_release
            Kernel.pbMessage(state_toggle_message("Cannot Release", pkmn.respond_to?(:cannot_release) ? !!pkmn.cannot_release : false))
          else
            Kernel.pbMessage(unsupported_feature_message("Cannot Release flag"))
          end
        end,
        simple_menu_action(t(TR[:toggle_cannot_trade])) do
          if pkmn.respond_to?(:cannot_trade=)
            pkmn.cannot_trade = !pkmn.cannot_trade
            Kernel.pbMessage(state_toggle_message("Cannot Trade", pkmn.respond_to?(:cannot_trade) ? !!pkmn.cannot_trade : false))
          else
            Kernel.pbMessage(unsupported_feature_message("Cannot Trade flag"))
          end
        end
      ]
      render_dynamic_menu(t(TR[:discardable_flags]), menu)
    end

    def party_egg(pkmn)
      menu = [
        simple_menu_action(t(TR[:make_egg])) do
          if make_pokemon_egg!(pkmn)
            notify_action_result(pkmn.name, true, "turned into an Egg.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("turn #{pkmn.name} into an Egg"))
          end
        end,
        simple_menu_action(t(TR[:hatch_egg])) do
          if hatch_pokemon_egg!(pkmn)
            notify_action_result(pkmn.name, true, "hatched successfully.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("hatch #{pkmn.name}"))
          end
        end,
        simple_menu_action(t(TR[:one_step_hatch])) do
          if set_pokemon_hatch_steps!(pkmn, 1)
            notify_action_result(pkmn.name, true, "will hatch in 1 step.", "failed.")
          else
            Kernel.pbMessage(engine_failure_message("edit hatch steps"))
          end
        end
      ]
      render_dynamic_menu(t(TR[:egg_options]), menu)
    end

    def party_duplicate(pkmn)
      return unless Kernel.pbConfirmMessage(_INTL("Duplicate {1}?", pkmn.name))
      clone = duplicate_pokemon(pkmn)
      return Kernel.pbMessage(engine_failure_message("duplicate this Pokemon")) unless clone
      if add_pkmn_silently(clone)
        notify_action_result(pkmn.name, true, "duplicated!", "failed.")
      else
        Kernel.pbMessage(engine_failure_message("add the duplicate"))
      end
    end

    def party_export_preset(pkmn)
      if export_pokemon_preset(pkmn)
        notify_action_result("Preset Export", true, "saved to #{preset_file_path}.", "failed.")
      else
        Kernel.pbMessage(engine_failure_message("export preset"))
      end
    end

    def party_apply_preset(pkmn)
      preset = import_pokemon_preset
      return Kernel.pbMessage(_INTL("Preset file not found.")) unless preset
      if apply_pokemon_preset!(pkmn, preset)
        notify_action_result("Preset Apply", true, "completed!", "failed.")
      else
        Kernel.pbMessage(engine_failure_message("apply preset"))
      end
    end

    def party_delete(index)
      return unless Kernel.pbConfirmMessage(_INTL("Permanently delete this Pokemon?"))
      get_player.party.delete_at(index)
      notify_action_result("Party Pokemon", true, "deleted.", "failed.")
    end

    def party_trigger_evolution(pkmn)
      return Kernel.pbMessage(_INTL("Eggs cannot evolve.")) if pokemon_egg_state(pkmn)
      target_species = nil
      # 1. Modern GameData::Species evolutions lookup
      if defined?(GameData) && safe_const_get(GameData, :Species) && GameData::Species.respond_to?(:get)
        spec_data = GameData::Species.get(pkmn.species) rescue nil
        if spec_data && spec_data.respond_to?(:evolutions) && spec_data.evolutions && !spec_data.evolutions.empty?
          cmds = spec_data.evolutions.map do |evo|
            evo_spec = evo[0]
            name = (GameData::Species.get(evo_spec).name rescue evo_spec.to_s)
            _INTL("Evolve into {1}", name)
          end
          cmds.push(menu_back_label)
          ch = Kernel.pbMessage(_INTL("Choose Evolution:"), cmds, -1)
          if ch >= 0 && ch < spec_data.evolutions.length
            target_species = spec_data.evolutions[ch][0]
          end
        end
      end
      # 2. Legacy check
      if !target_species && defined?(pbCheckEvolution)
        check_evo = pbCheckEvolution(pkmn) rescue nil
        target_species = check_evo if check_evo && check_evo.to_i > 0
      end
      # 3. If no branches detected or manual pick requested
      if !target_species
        if Kernel.pbConfirmMessage(_INTL("No automatic evolution found. Search and select target species?"))
          spec_hash = build_search_hash(:Species)
          sel_id = search_list("Evolve To", spec_hash)
          target_species = get_symbol(:Species, sel_id) if sel_id
        end
      end
      return unless target_species

      evolved = false
      if defined?(pbEvolution)
        begin
          if defined?(pbFadeOutInWithUpdate)
            pbFadeOutInWithUpdate { pbEvolution(pkmn, target_species) }
          elsif defined?(pbFadeOutIn)
            pbFadeOutIn { pbEvolution(pkmn, target_species) }
          else
            pbEvolution(pkmn, target_species)
          end
          evolved = true
        rescue StandardError => e
          log_error("pbEvolution", e)
        end
      end
      if !evolved
        if set_pokemon_species!(pkmn, target_species)
          pkmn.reset_moves if pkmn.respond_to?(:reset_moves)
          evolved = true
        end
      end
      if evolved
        notify_action_result("#{pkmn.name} Evolution", true, "evolved successfully!", "failed.")
      else
        Kernel.pbMessage(engine_failure_message("trigger evolution"))
      end
    rescue StandardError => e
      log_error("Party Trigger Evolution", e)
      Kernel.pbMessage(engine_failure_message("evolve Pokemon"))
    end
  end
end
