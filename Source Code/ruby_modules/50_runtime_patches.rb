
::DeveloperMenu.initialize_variables if ::DeveloperMenu.walk_through_walls.nil?

if !$_gm_input_patched
  if defined?(Graphics) && Graphics.respond_to?(:update)
    if ::DeveloperMenu.make_singleton_alias(Graphics, :_gm_original_graphics_update, :update)
      class << Graphics
        def update
          _gm_original_graphics_update
          begin
            ::DeveloperMenu.on_input_update
          rescue Exception => e
            ::DeveloperMenu.log_error("Graphics.update input hook", e) if ::DeveloperMenu.respond_to?(:log_error)
          end
          begin
            ::DeveloperMenu.on_map_update
          rescue Exception => e
            ::DeveloperMenu.log_error("Graphics.update map hook", e) if ::DeveloperMenu.respond_to?(:log_error)
          end
        end
      end
    end
    $_gm_input_patched = true
  end
end

# ===============================================================================
# ENGINE MONKEY PATCHES (For Extras Category)
# ===============================================================================

class << ::DeveloperMenu
  def apply_runtime_patches!
    apply_no_battles_patches!
    apply_ev_gain_patches!
    apply_infinite_mega_patches!
    true
  rescue => e
    log_error("Apply Runtime Patches", e)
    false
  end

  def apply_no_battles_patches!
    if defined?(pbWildBattle) && !defined?(_gm_orig_pbWildBattle_dev)
      Object.send(:alias_method, :_gm_orig_pbWildBattle_dev, :pbWildBattle)
      Object.send(:define_method, :pbWildBattle) do |*args|
        return true if ::DeveloperMenu.no_battles
        _gm_orig_pbWildBattle_dev(*args)
      end
    end

    if defined?(pbTrainerBattle) && !defined?(_gm_orig_pbTrainerBattle_dev)
      Object.send(:alias_method, :_gm_orig_pbTrainerBattle_dev, :pbTrainerBattle)
      Object.send(:define_method, :pbTrainerBattle) do |*args|
        return true if ::DeveloperMenu.no_battles
        _gm_orig_pbTrainerBattle_dev(*args)
      end
    end

    if defined?(WildBattle) && WildBattle.respond_to?(:start)
      if ::DeveloperMenu.make_singleton_alias(WildBattle, :_gm_orig_start_dev, :start)
        class << WildBattle
          def start(*args)
            return 1 if ::DeveloperMenu.no_battles
            _gm_orig_start_dev(*args)
          end

          ruby2_keywords(:start) if respond_to?(:ruby2_keywords, true)
        end
      end
    end

    if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
      if ::DeveloperMenu.make_singleton_alias(TrainerBattle, :_gm_orig_start_dev, :start)
        class << TrainerBattle
          def start(*args)
            return 1 if ::DeveloperMenu.no_battles
            _gm_orig_start_dev(*args)
          end

          ruby2_keywords(:start) if respond_to?(:ruby2_keywords, true)
        end
      end
    end
  end

  def apply_ev_gain_patches!
    if defined?(Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainExp_dev, :pbGainExp, Battle)
      Battle.class_eval do
        def pbGainEVsOne(*args)
          if ::DeveloperMenu.overcap_stats_in_args?(*args)
            ::DeveloperMenu.log_error("Battle EV Gain Overcap Skip", RuntimeError.new("Skipped native EV gain for overcap Pokemon."))
            return nil
          end
          return _gm_orig_pbGainEVsOne_dev(*args) if defined?(_gm_orig_pbGainEVsOne_dev)
          nil
        rescue ArgumentError => e
          ::DeveloperMenu.log_error("Battle EV Gain Compatibility", e)
          nil
        end

        def pbGainExp(*args)
          return _gm_orig_pbGainExp_dev(*args) if defined?(_gm_orig_pbGainExp_dev)
          nil
        rescue ArgumentError => e
          ::DeveloperMenu.log_error("Battle Exp Gain Compatibility", e)
          nil
        end

        ruby2_keywords(:pbGainEVsOne) if respond_to?(:ruby2_keywords, true)
        ruby2_keywords(:pbGainExp) if respond_to?(:ruby2_keywords, true)
      end
    end

    if defined?(PokeBattle_Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, PokeBattle_Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbGainExp_dev, :pbGainExp, PokeBattle_Battle)
      PokeBattle_Battle.class_eval do
        def pbGainEVsOne(*args)
          if ::DeveloperMenu.overcap_stats_in_args?(*args)
            ::DeveloperMenu.log_error("Legacy Battle EV Gain Overcap Skip", RuntimeError.new("Skipped native EV gain for overcap Pokemon."))
            return nil
          end
          return _gm_orig_pbGainEVsOne_dev(*args) if defined?(_gm_orig_pbGainEVsOne_dev)
          nil
        rescue ArgumentError => e
          ::DeveloperMenu.log_error("Legacy Battle EV Gain Compatibility", e)
          nil
        end

        def pbGainExp(*args)
          return _gm_orig_pbGainExp_dev(*args) if defined?(_gm_orig_pbGainExp_dev)
          nil
        rescue ArgumentError => e
          ::DeveloperMenu.log_error("Legacy Battle Exp Compatibility", e)
          nil
        end
      end
    end
  end

  def apply_infinite_mega_patches!
    if defined?(PokeBattle_Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, PokeBattle_Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbCanMegaEvolve_dev, :pbCanMegaEvolve?, PokeBattle_Battle)
      PokeBattle_Battle.class_eval do
        def pbHasMegaRing?(*args)
          return true if ::DeveloperMenu.inf_mega
          return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
          false
        end

        def pbCanMegaEvolve?(*args)
          if ::DeveloperMenu.inf_mega
            begin
              @megaEvolution[args[0]][args[1]] = -1 if @megaEvolution && @megaEvolution[args[0]].is_a?(Array)
            rescue Exception => e
              ::DeveloperMenu.log_error("Legacy Infinite Mega", e) if ::DeveloperMenu.respond_to?(:log_error)
            end
          end
          return _gm_orig_pbCanMegaEvolve_dev(*args) if defined?(_gm_orig_pbCanMegaEvolve_dev)
          false
        end
      end
    end

    if defined?(Battle)
      ::DeveloperMenu.make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, Battle)
      Battle.class_eval do
        def pbHasMegaRing?(*args)
          return true if ::DeveloperMenu.inf_mega
          return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
          false
        end
      end

      if defined?(Battle::Battler)
        ::DeveloperMenu.make_alias(:_gm_orig_has_mega_dev, :has_mega?, Battle::Battler)
        Battle::Battler.class_eval do
          def has_mega?(*args)
            if ::DeveloperMenu.inf_mega
              begin
                @Battle.megaEvolution[0] = [-1] * 6 if @Battle && @Battle.respond_to?(:megaEvolution) && @Battle.megaEvolution
                @Battle.megaEvolution[1] = [-1] * 6 if @Battle && @Battle.respond_to?(:megaEvolution) && @Battle.megaEvolution
              rescue Exception => e
                ::DeveloperMenu.log_error("Modern Infinite Mega", e) if ::DeveloperMenu.respond_to?(:log_error)
              end
            end
            return _gm_orig_has_mega_dev(*args) if defined?(_gm_orig_has_mega_dev)
            false
          end
        end
      end
    end
  end
end
::DeveloperMenu.apply_runtime_patches!

end

def pbPokeDebugMenu
  ::DeveloperMenu.open_menu_external
end

def pbDeveloperMenu
  ::DeveloperMenu.open_menu_external
end

def pbGodModeMenu
  ::DeveloperMenu.open_menu_external
end
