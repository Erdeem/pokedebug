
DeveloperMenu.initialize_variables if DeveloperMenu.walk_through_walls.nil?

if !$_gm_input_patched
  if defined?(Graphics) && Graphics.respond_to?(:update)
    if DeveloperMenu.make_singleton_alias(Graphics, :_gm_original_graphics_update, :update)
      class << Graphics
        def update
          _gm_original_graphics_update
          DeveloperMenu.try_call("Graphics.update input hook") { DeveloperMenu.on_input_update }
          DeveloperMenu.try_call("Graphics.update map hook") { DeveloperMenu.on_map_update }
        end
      end
    end
    $_gm_input_patched = true
  end
end

# ===============================================================================
# ENGINE MONKEY PATCHES (For Extras Category)
# ===============================================================================

# No Battles (v15-v19)
if defined?(pbWildBattle)
  unless defined?(_gm_orig_pbWildBattle_dev)
    alias _gm_orig_pbWildBattle_dev pbWildBattle
    def pbWildBattle(*args)
      return true if DeveloperMenu.no_battles
      _gm_orig_pbWildBattle_dev(*args)
    end
  end
end

if defined?(pbTrainerBattle)
  unless defined?(_gm_orig_pbTrainerBattle_dev)
    alias _gm_orig_pbTrainerBattle_dev pbTrainerBattle
    def pbTrainerBattle(*args)
      return true if DeveloperMenu.no_battles
      _gm_orig_pbTrainerBattle_dev(*args)
    end
  end
end

# No Battles (v20+)
if defined?(WildBattle) && WildBattle.respond_to?(:start)
  if DeveloperMenu.make_singleton_alias(WildBattle, :_gm_orig_start_dev, :start)
    class << WildBattle
      def start(*args, **kwargs)
        return 1 if DeveloperMenu.no_battles
        _gm_orig_start_dev(*args, **kwargs)
      end
    end
  end
end

if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
  if DeveloperMenu.make_singleton_alias(TrainerBattle, :_gm_orig_start_dev, :start)
    class << TrainerBattle
      def start(*args, **kwargs)
        return 1 if DeveloperMenu.no_battles
        _gm_orig_start_dev(*args, **kwargs)
      end
    end
  end
end

# Overcap IV/EV compatibility:
# Some Essentials v21 builds/plugins assume EVs never exceed the classic cap and
# raise ArgumentError in post-battle EV gain. If the player intentionally set
# overcap values with God Mode, just skip that EV gain instead of breaking flow.
if defined?(Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, Battle)
  Battle.class_eval do
    def pbGainEVsOne(*args, **kwargs)
      return _gm_orig_pbGainEVsOne_dev(*args, **kwargs) if defined?(_gm_orig_pbGainEVsOne_dev)
      nil
    rescue ArgumentError => e
      DeveloperMenu.log_error("Battle EV Gain Compatibility", e)
      nil
    end
  end
end

if defined?(PokeBattle_Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, PokeBattle_Battle)
  PokeBattle_Battle.class_eval do
    def pbGainEVsOne(*args)
      return _gm_orig_pbGainEVsOne_dev(*args) if defined?(_gm_orig_pbGainEVsOne_dev)
      nil
    rescue ArgumentError => e
      DeveloperMenu.log_error("Legacy Battle EV Gain Compatibility", e)
      nil
    end
  end
end

# Infinite Mega
if defined?(PokeBattle_Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, PokeBattle_Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbCanMegaEvolve_dev, :pbCanMegaEvolve?, PokeBattle_Battle)
  PokeBattle_Battle.class_eval do
    def pbHasMegaRing?(*args)
      return true if DeveloperMenu.inf_mega
      return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
      false
    end

    def pbCanMegaEvolve?(*args)
      if DeveloperMenu.inf_mega
        DeveloperMenu.try_call("Legacy Infinite Mega") do
          @megaEvolution[args[0]][args[1]] = -1 if @megaEvolution && @megaEvolution[args[0]].is_a?(Array)
        end
      end
      return _gm_orig_pbCanMegaEvolve_dev(*args) if defined?(_gm_orig_pbCanMegaEvolve_dev)
      false
    end
  end
end

# Modern Infinite Mega (v20+)
if defined?(Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, Battle)
  Battle.class_eval do
    def pbHasMegaRing?(*args)
      return true if DeveloperMenu.inf_mega
      return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
      false
    end
  end

  if defined?(Battle::Battler)
    DeveloperMenu.make_alias(:_gm_orig_has_mega_dev, :has_mega?, Battle::Battler)
    Battle::Battler.class_eval do
      def has_mega?(*args)
        if DeveloperMenu.inf_mega
          DeveloperMenu.try_call("Modern Infinite Mega") do
            @Battle.megaEvolution[0] = [-1] * 6 if @Battle && @Battle.respond_to?(:megaEvolution) && @Battle.megaEvolution
            @Battle.megaEvolution[1] = [-1] * 6 if @Battle && @Battle.respond_to?(:megaEvolution) && @Battle.megaEvolution
          end
        end
        return _gm_orig_has_mega_dev(*args) if defined?(_gm_orig_has_mega_dev)
        false
      end
    end
  end
end

end

def pbPokeDebugMenu
  DeveloperMenu.open_menu_external
end

def pbDeveloperMenu
  DeveloperMenu.open_menu_external
end

def pbGodModeMenu
  DeveloperMenu.open_menu_external
end
