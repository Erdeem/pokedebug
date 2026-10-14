# PSDK-native menu surface. The generic PokeDebug implementation deliberately
# supports many Essentials generations; PSDK has different save objects and
# database records, so only actions backed by a real PSDK operation are exposed.
if defined?(DeveloperMenu::PSDKCompat) && DeveloperMenu::PSDKCompat.active?
  module DeveloperMenu
    class << self
      def psdk_state
        DeveloperMenu::PSDKCompat.game_state
      end

      def psdk_trainer
        state = psdk_state
        state && state.respond_to?(:trainer) ? state.trainer : nil
      end

      def psdk_bag
        state = psdk_state
        state && state.respond_to?(:bag) ? state.bag : nil
      end

      def psdk_data_entries(type)
        adapter = engine_adapter_for(:data)
        result = adapter ? adapter.data_entries(type) : nil
        result && result[0] ? result[1] : []
      rescue StandardError => error
        log_error("PSDK Data Entries #{type}", error)
        []
      end

      def psdk_item_key?(item)
        return true if item.respond_to?(:socket) && item.socket.to_i == 5
        return !!item.is_limited if item.respond_to?(:is_limited)
        return !!item.is_limited? if item.respond_to?(:is_limited?)
        false
      rescue StandardError
        false
      end

      def psdk_item_symbol(item)
        return item.db_symbol if item.respond_to?(:db_symbol)
        return item.id if item.respond_to?(:id)
        nil
      end

      def psdk_bag_quantity(symbol)
        bag = psdk_bag
        return 0 unless bag && symbol
        return bag.item_quantity(symbol).to_i if bag.respond_to?(:item_quantity)
        return bag.quantity(symbol).to_i if bag.respond_to?(:quantity)
        0
      rescue StandardError
        0
      end

      def menu_engine
        menu = [
          battle_menu_entry(:engine_quick_status, "Quick Status") { show_engine_status },
          battle_menu_entry(:engine_native_debug_only, "Enable Native Debug Only") { psdk_enable_native_debug_only },
          battle_menu_entry(:engine_field_effects, "Field Effects") { engine_field_effects },
          battle_menu_entry(:engine_refresh_map, "Refresh Map") { engine_refresh_map },
          battle_menu_entry(:engine_wtw, "Walk Through Walls") { toggle_wtw },
          battle_menu_entry(:engine_open_pc, "Open PC") { open_pc_menu }
        ]
        render_dynamic_menu("ENGINE | PSDK", menu)
      end

      def psdk_enable_native_debug_only
        prompt = "Enable the game's native Debug Mode and disable the PokeDebug Device? Save once afterwards before uninstalling or copying the save."
        return false unless Kernel.pbConfirmMessage(prompt)
        path = DeveloperMenu::PSDKCompat.native_debug_only_flag_path
        File.open(path, "w") { |file| file.puts("native_debug_only=true") }
        $DEBUG = true
        remove_pokedebug_device!
        @close_menu_stack_requested = true
        Kernel.pbMessage("Native Debug Mode is ON. The PokeDebug Device was removed. Save the game once to permanently clean this save.")
        true
      rescue StandardError => error
        log_error("Enable PSDK Native Debug Only", error)
        Kernel.pbMessage(engine_failure_message("enable native Debug Mode"))
        false
      end

      def engine_field_effects
        loop do
          enabled = defined?(@walk_through_walls) && @walk_through_walls
          commands = [(enabled ? "[Y] Walk Through Walls" : "[  ] Walk Through Walls"), menu_back_label]
          choice = Kernel.pbMessage("FIELD EFFECTS | PSDK", commands, -1)
          break if choice < 0 || choice == commands.length - 1
          @walk_through_walls = !enabled
          if defined?($game_player) && $game_player && $game_player.respond_to?(:through=)
            $game_player.through = @walk_through_walls
          end
        end
      end

      def menu_pokemon
        menu = [
          battle_menu_entry(:pokemon_quick_status, "Quick Status") { show_pokemon_menu_status },
          battle_menu_entry(:pokemon_add, "Add Pokemon") { pokemon_add },
          battle_menu_entry(:pokemon_heal_party, "Heal Party") { heal_party },
          battle_menu_entry(:engine_open_pc, "Open PC") { open_pc_menu },
          battle_menu_entry(:pokemon_export_ids, "Export Species IDs") { dump_ids(:Species, "Pokemon_ID_List.txt") }
        ]
        render_dynamic_menu(_INTL("POKEMON | Party {1}/6", player_party.length), menu)
      end

      def menu_item
        menu = [
          battle_menu_entry(:items_add, "Add Item") { item_add },
          battle_menu_entry(:items_fill_all, "Fill Bag (All)") { item_fill(0) },
          battle_menu_entry(:items_fill_non_key, "Fill Bag (Non-Key)") { item_fill(1) },
          battle_menu_entry(:items_fill_key, "Fill Bag (Key Items)") { item_fill(2) },
          battle_menu_entry(:items_empty, "Empty Bag") { item_empty },
          battle_menu_entry(:items_export_ids, "Export Item IDs") { dump_ids(:Item, "Item_ID_List.txt") }
        ]
        render_dynamic_menu("ITEMS | PSDK", menu)
      end

      def item_fill(mode)
        bag = psdk_bag
        return Kernel.pbMessage(engine_failure_message("access the PSDK bag")) unless bag && bag.respond_to?(:add_item)
        params = ChooseNumberParams.new
        params.setRange(1, 999)
        params.setInitialValue(1)
        quantity = Kernel.pbMessageChooseNumber(_INTL("Choose the number of items."), params).to_i
        return if quantity <= 0
        added = 0
        failed = 0
        psdk_data_entries(:Item).each_with_index do |item, index|
          symbol = psdk_item_symbol(item)
          next unless symbol && symbol != :__undef__ && symbol != DeveloperMenu::PSDKCompat::DEVICE_ITEM_ID
          key_item = psdk_item_key?(item)
          next if mode == 1 && key_item
          next if mode == 2 && !key_item
          amount = key_item ? 1 : quantity
          begin
            bag.add_item(symbol, amount)
            added += 1
          rescue StandardError
            failed += 1
          end
          Graphics.update if defined?(Graphics) && (index % 50) == 0
        end
        Kernel.pbMessage(_INTL("Bag updated. Added: {1}. Failed: {2}.", added, failed))
      rescue StandardError => error
        log_error("PSDK Fill Bag", error)
        Kernel.pbMessage(engine_failure_message("fill the PSDK bag"))
      end

      def item_empty
        return unless Kernel.pbConfirmMessage(_INTL("Empty Bag? The PokeDebug Device will be preserved."))
        bag = psdk_bag
        return Kernel.pbMessage(engine_failure_message("access the PSDK bag")) unless bag && bag.respond_to?(:remove_item)
        removed = 0
        psdk_data_entries(:Item).each_with_index do |item, index|
          symbol = psdk_item_symbol(item)
          next unless symbol && symbol != :__undef__ && symbol != DeveloperMenu::PSDKCompat::DEVICE_ITEM_ID
          quantity = psdk_bag_quantity(symbol)
          next if quantity <= 0
          bag.remove_item(symbol, quantity)
          removed += 1
          Graphics.update if defined?(Graphics) && (index % 50) == 0
        end
        Kernel.pbMessage(_INTL("The Bag was cleared ({1} item types removed).", removed))
      rescue StandardError => error
        log_error("PSDK Empty Bag", error)
        Kernel.pbMessage(engine_failure_message("empty the PSDK bag"))
      end

      def menu_player
        menu = [
          battle_menu_entry(:player_quick_summary, "Quick Status") { show_player_summary },
          battle_menu_entry(:player_edit_money, "Edit Money") { psdk_edit_money },
          battle_menu_entry(:player_badges, "Edit Badges") { player_badges },
          battle_menu_entry(:player_gender, "Change Gender") { psdk_toggle_gender },
          battle_menu_entry(:player_name, "Rename Player") { psdk_rename_player },
          battle_menu_entry(:player_trainer_id, "Change Trainer ID") { psdk_edit_trainer_id },
          battle_menu_entry(:player_play_time, "Edit Play Time") { psdk_edit_play_time }
        ]
        render_dynamic_menu(_INTL("PLAYER | {1} | ${2}", player_name_value, player_money_value), menu)
      end

      def menu_extras
        menu = [
          battle_menu_entry(:remove_device_from_save, "Remove Device From Save") { psdk_remove_device_from_save },
          battle_menu_entry(:compatibility_report, "Compatibility Report") { show_compatibility_report },
          battle_menu_entry(:diagnostics_report, "Diagnostics Report") { show_diagnostics },
          battle_menu_entry(:test_all, "Test PSDK Integration") { run_test_all },
          battle_menu_entry(:engine_compatibility_report, "Engine Report") { show_engine_report },
          battle_menu_entry(:mobile_open_help, "PokeDebug Device Help") { show_joiplay_help }
        ]
        render_dynamic_menu("EXTRAS | PSDK", menu)
      end

      def psdk_remove_device_from_save
        removed = remove_pokedebug_device!
        if removed
          Kernel.pbMessage("The runtime item is no longer in the Bag. Save the game once before uninstalling PokeDebug or moving this save.")
        else
          Kernel.pbMessage(engine_failure_message("remove the PokeDebug Device"))
        end
        removed
      end

      def psdk_edit_money
        state = psdk_state
        return Kernel.pbMessage(engine_failure_message("access player money")) unless state && state.respond_to?(:money=)
        params = ChooseNumberParams.new
        params.setRange(0, 9_999_999)
        params.setInitialValue(state.respond_to?(:money) ? state.money.to_i : 0)
        value = Kernel.pbMessageChooseNumber(_INTL("Set the player's money."), params)
        state.money = value.to_i
        Kernel.pbMessage(_INTL("Money was set to ${1}.", state.money))
      end

      def psdk_badge?(trainer, index)
        return !!trainer.badge_obtained?(index) if trainer.respond_to?(:badge_obtained?)
        badges = trainer.respond_to?(:badges) ? trainer.badges : nil
        return !!badges[index] if badges.respond_to?(:[])
        false
      end

      def psdk_set_badge(trainer, index, value)
        if trainer.respond_to?(:set_badge)
          trainer.set_badge(index, value)
        elsif trainer.respond_to?(:badges) && trainer.badges.respond_to?(:[]=)
          trainer.badges[index] = value
        else
          return false
        end
        true
      rescue ArgumentError
        trainer.set_badge(index) if value && trainer.respond_to?(:set_badge)
        true
      end

      def player_badges
        trainer = psdk_trainer
        return Kernel.pbMessage(engine_failure_message("access PSDK badges")) unless trainer
        choice = 0
        loop do
          commands = ["Give all", "Remove all"]
          24.times { |index| commands << ((psdk_badge?(trainer, index) ? "[Y] " : "[  ] ") + _INTL("Badge {1}", index + 1)) }
          commands << menu_back_label
          choice = Kernel.pbMessage("BADGES", commands, choice)
          break if choice < 0 || choice == commands.length - 1
          if choice == 0 || choice == 1
            24.times { |index| psdk_set_badge(trainer, index, choice == 0) }
          else
            index = choice - 2
            psdk_set_badge(trainer, index, !psdk_badge?(trainer, index))
          end
        end
      end

      def psdk_toggle_gender
        trainer = psdk_trainer
        return Kernel.pbMessage(engine_failure_message("access the PSDK trainer")) unless trainer
        current = trainer.respond_to?(:playing_girl) ? !!trainer.playing_girl : false
        if trainer.respond_to?(:define_gender)
          trainer.define_gender(!current)
        elsif trainer.respond_to?(:playing_girl=)
          trainer.playing_girl = !current
        else
          return Kernel.pbMessage(unsupported_feature_message("PSDK trainer gender"))
        end
        $game_player.refresh if defined?($game_player) && $game_player && $game_player.respond_to?(:refresh)
        Kernel.pbMessage(_INTL("Player gender changed."))
      end

      def psdk_rename_player
        trainer = psdk_trainer
        return Kernel.pbMessage(engine_failure_message("access the PSDK trainer")) unless trainer && trainer.respond_to?(:name=)
        name = set_name_via_ui(trainer.respond_to?(:name) ? trainer.name.to_s : "")
        return if !name || name.to_s.strip == ""
        trainer.name = name.to_s.strip
        Kernel.pbMessage(_INTL("The player's name was changed to {1}.", trainer.name))
      end

      def psdk_edit_trainer_id
        trainer = psdk_trainer
        return Kernel.pbMessage(engine_failure_message("access the PSDK trainer")) unless trainer
        params = ChooseNumberParams.new
        params.setRange(0, 999_999_999)
        params.setInitialValue(trainer.respond_to?(:id) ? trainer.id.to_i : 0)
        value = Kernel.pbMessageChooseNumber(_INTL("New ID:"), params).to_i
        if trainer.respond_to?(:playing_girl) && trainer.playing_girl && trainer.respond_to?(:id_girl=)
          trainer.id_girl = value
        elsif trainer.respond_to?(:id_boy=)
          trainer.id_boy = value
        elsif trainer.respond_to?(:id=)
          trainer.id = value
        else
          return Kernel.pbMessage(unsupported_feature_message("PSDK trainer ID"))
        end
        Kernel.pbMessage(_INTL("Trainer ID was changed to {1}.", value))
      end

      def psdk_edit_play_time
        trainer = psdk_trainer
        return Kernel.pbMessage(engine_failure_message("access play time")) unless trainer && trainer.respond_to?(:play_time=)
        params = ChooseNumberParams.new
        params.setRange(0, 9_999_999)
        params.setInitialValue(trainer.respond_to?(:play_time) ? trainer.play_time.to_i : 0)
        seconds = Kernel.pbMessageChooseNumber(_INTL("Play time in seconds:"), params).to_i
        trainer.play_time = seconds
        Kernel.pbMessage(_INTL("Play time was updated."))
      end

      def menu_party
        party = player_party
        return Kernel.pbMessage(_INTL("Party is empty! Add a Pokemon first.")) if party.empty?
        loop do
          commands = party.map { |pokemon| pokemon_party_label(pokemon) }
          commands << menu_back_label
          choice = Kernel.pbMessage("PARTY", commands, -1)
          break if choice < 0 || choice >= party.length
          psdk_party_pokemon_menu(party[choice], choice)
        end
      end

      def psdk_party_pokemon_menu(pokemon, index)
        loop do
          commands = ["Quick Status", "Heal / Restore PP", "Edit Level", "Rename", "Duplicate", "Delete", menu_back_label]
          choice = Kernel.pbMessage(_INTL("{1} | Lv.{2}", pokemon.name, pokemon_level_value(pokemon)), commands, -1)
          break if choice < 0 || choice == commands.length - 1
          case choice
          when 0
            show_pokemon_summary(pokemon)
          when 1
            heal_pokemon!(pokemon)
            restore_pokemon_pp!(pokemon)
            Kernel.pbMessage(_INTL("{1} was healed.", pokemon.name))
          when 2
            params = ChooseNumberParams.new
            params.setRange(1, 100)
            params.setInitialValue(pokemon_level_value(pokemon))
            level = Kernel.pbMessageChooseNumber(_INTL("Level:"), params)
            if set_pokemon_level!(pokemon, level)
              Kernel.pbMessage(_INTL("Level was set to {1}.", level))
            else
              Kernel.pbMessage(engine_failure_message("edit this Pokemon's level"))
            end
          when 3
            if pokemon.respond_to?(:name=)
              name = set_name_via_ui(pokemon.name.to_s)
              pokemon.name = name.to_s.strip if name && name.to_s.strip != ""
            else
              Kernel.pbMessage(unsupported_feature_message("Pokemon nickname"))
            end
          when 4
            copy = begin Marshal.load(Marshal.dump(pokemon)); rescue StandardError; pokemon.clone; end
            if add_pkmn_silently(copy)
              Kernel.pbMessage(_INTL("{1} was duplicated.", pokemon.name))
            else
              Kernel.pbMessage(engine_failure_message("duplicate this Pokemon"))
            end
          when 5
            if Kernel.pbConfirmMessage(_INTL("Delete {1}?", pokemon.name))
              player_party.delete_at(index)
              Kernel.pbMessage(_INTL("Pokemon deleted."))
              break
            end
          end
        end
      rescue StandardError => error
        log_error("PSDK Party Pokemon Menu", error)
        Kernel.pbMessage(engine_failure_message("edit this Pokemon"))
      end
    end
  end
end

# Apply the persistent native-debug-only choice as soon as the PSDK adapter is
# loaded. The flag lives with the plugin, never inside the player's save.
if DeveloperMenu::PSDKCompat.native_debug_only?
  $DEBUG = true
  DeveloperMenu.remove_pokedebug_device! if DeveloperMenu.respond_to?(:remove_pokedebug_device!)
end
