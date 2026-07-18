  class << self
    def current_battle_object
      return $battle if defined?($battle) && !$battle.nil?
      return $game_temp.battle if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:battle) && $game_temp.battle
      nil
    rescue => e
      log_error("Current Battle Object", e)
      nil
    end

    def battle_battlers
      battle = current_battle_object
      return [] unless battle
      return battle.allBattlers if battle.respond_to?(:allBattlers)
      return battle.battlers if battle.respond_to?(:battlers)
      return battle.eachBattler.to_a if battle.respond_to?(:eachBattler)
      []
    rescue => e
      log_error("Battle Battlers", e)
      []
    end

    def battle_scene_refresh_targets
      battle = current_battle_object
      targets = []
      targets << battle.scene if battle && battle.respond_to?(:scene) && battle.scene
      targets << $scene if defined?($scene) && $scene
      targets.compact.uniq
    rescue => e
      log_error("Battle Scene Refresh Targets", e)
      []
    end

    def sync_battler_with_party_pokemon!(battler)
      return false unless battler
      pkmn = nil
      pkmn = battler.pokemon if battler.respond_to?(:pokemon)
      pkmn = battler.pkmn if pkmn.nil? && battler.respond_to?(:pkmn)
      return false unless pkmn

      battler.hp = pkmn.hp if battler.respond_to?(:hp=) && pkmn.respond_to?(:hp)
      if battler.respond_to?(:status=)
        if pkmn.respond_to?(:status) && !(pkmn.status.nil? || pkmn.status == false || pkmn.status == 0 || pkmn.status.to_s.upcase == "NONE")
          battler.status = pkmn.status
        else
          assign_cleared_status!(battler)
        end
      end
      battler.statusCount = 0 if battler.respond_to?(:statusCount=)
      battler.pbUpdate if battler.respond_to?(:pbUpdate)
      battler.refresh if battler.respond_to?(:refresh)
      true
    rescue => e
      log_error("Sync Battler With Pokemon", e)
      false
    end

    def sync_battle_party_state!
      battle_battlers.each { |battler| sync_battler_with_party_pokemon!(battler) }
      refresh_battle_scene_after_heal!
      true
    rescue => e
      log_error("Sync Battle Party State", e)
      false
    end

    def refresh_battle_scene_after_heal!
      battle_scene_refresh_targets.each do |scene|
        scene.pbRefresh if scene.respond_to?(:pbRefresh)
        scene.refresh if scene.respond_to?(:refresh)
      end
      true
    rescue => e
      log_error("Refresh Battle Scene After Heal", e)
      false
    end

    def battle_feedback(message)
      return false if @battle_feedback_active
      @battle_feedback_active = true
      play_decision_sound
      battle_scene_refresh_targets.each do |scene|
        next unless battle_feedback_scene_ready?(scene)
        if scene.respond_to?(:pbDisplayPaused)
          scene.pbDisplayPaused(message)
          return true
        end
        if scene.respond_to?(:pbDisplay)
          scene.pbDisplay(message)
          return true
        end
      end
      battle_log(message)
      true
    rescue => e
      log_error("Battle Feedback", e)
      false
    ensure
      @battle_feedback_active = false
    end

    def battle_feedback_scene_ready?(scene)
      return false unless scene
      return true unless scene.instance_variable_defined?(:@sprites)
      sprites = scene.instance_variable_get(:@sprites)
      return false unless sprites
      # Reborn/Rejuvenation pbDisplay assumes both entries exist and raises
      # while transitions are constructing or disposing the battle UI.
      if scene.class.to_s.include?("BattleScene") || scene.class.to_s.include?("PokeBattle_Scene")
        return false unless sprites.respond_to?(:[])
        return false unless sprites["messagebox"] && sprites["messagewindow"]
      end
      true
    rescue
      false
    end

    def battle_log(message)
      write_developer_log("battle", "Battle Tools", message.to_s)
    rescue
      false
    end

    def active_party_pokemon_in_battle
      battle_battlers.map do |battler|
        next nil unless battler
        pkmn = nil
        pkmn = battler.pokemon if battler.respond_to?(:pokemon)
        pkmn = battler.pkmn if pkmn.nil? && battler.respond_to?(:pkmn)
        pkmn
      end.compact.uniq
    rescue => e
      log_error("Active Party Pokemon In Battle", e)
      []
    end

    def apply_to_party_in_battle!(context_name, targets)
      changed = false
      Array(targets).each do |pkmn|
        next if !pkmn || pokemon_egg_state(pkmn)
        changed = yield(pkmn) || changed
      end
      sync_battle_party_state!
      changed
    rescue => e
      log_error(context_name, e)
      false
    end

    def cure_party_status_in_battle!
      apply_to_party_in_battle!("Cure Party Status In Battle", player_party) do |pkmn|
        clear_pokemon_status!(pkmn)
      end
    end

    def restore_party_pp_in_battle!
      apply_to_party_in_battle!("Restore Party PP In Battle", player_party) do |pkmn|
        restore_pokemon_pp!(pkmn)
      end
    end

    def revive_party_in_battle!
      apply_to_party_in_battle!("Revive Party In Battle", player_party) do |pkmn|
        next false unless pokemon_current_hp(pkmn).to_i <= 0
        heal_pokemon!(pkmn)
      end
    end

    def heal_active_battle_pokemon!
      apply_to_party_in_battle!("Heal Active Battle Pokemon", active_party_pokemon_in_battle) do |pkmn|
        heal_pokemon!(pkmn)
      end
    end

    def run_battle_tool(action_label)
      result = yield
      if result
        battle_log("#{action_label} applied")
        battle_feedback(action_result_message(action_label, true))
      else
        battle_log("#{action_label} failed")
        battle_feedback(action_result_message(action_label, false))
      end
      result
    rescue => e
      log_error("Run Battle Tool #{action_label}", e)
      false
    end

    def battle_tools_menu
      menu = []
      menu << battle_menu_entry(:battle_direct_heal, "Heal Party") { run_battle_tool("Battle Heal") { heal_party_in_battle! } } if battle_access_enabled?(:battle_direct_heal)
      menu << battle_menu_entry(:battle_heal_active, "Heal Active Pokemon") { run_battle_tool("Active Heal") { heal_active_battle_pokemon! } } if battle_access_enabled?(:battle_heal_active)
      menu << battle_menu_entry(:battle_cure_status, "Cure Party Status") { run_battle_tool("Status Cure") { cure_party_status_in_battle! } } if battle_access_enabled?(:battle_cure_status)
      menu << battle_menu_entry(:battle_restore_pp, "Restore Party PP") { run_battle_tool("PP Restore") { restore_party_pp_in_battle! } } if battle_access_enabled?(:battle_restore_pp)
      menu << battle_menu_entry(:battle_revive_party, "Revive Party") { run_battle_tool("Party Revive") { revive_party_in_battle! } } if battle_access_enabled?(:battle_revive_party)
      render_dynamic_menu(t(TR[:battle_tools_title]), menu)
    rescue => e
      log_error("Battle Tools Menu", e)
      false
    end

    def heal_party_in_battle!
      healed_any = apply_to_party_in_battle!("Heal Party In Battle", player_party) do |pkmn|
        heal_pokemon!(pkmn)
      end
      battle_log("Battle Heal applied") if healed_any
      healed_any
    rescue => e
      log_error("Heal Party In Battle", e)
      false
    end

    def heal_party
      if battle_scene_active?
        healed = heal_party_in_battle!
        battle_feedback(action_result_message("Battle Heal", true)) if healed
        return healed
      end
      player_party.each do |pkmn|
        next if !pkmn || pokemon_egg_state(pkmn)
        if pkmn.respond_to?(:heal)
          pkmn.heal
        else
          heal_pokemon!(pkmn)
        end
      end
      Kernel.pbMessage(_INTL("Your Pokemon were fully healed."))
      true
    rescue => e
      log_error("Heal Party", e)
      false
    end
  end
