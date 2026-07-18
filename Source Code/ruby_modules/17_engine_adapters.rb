  end

  module EngineAdapters
    class Base
      def id
        :base
      end

      def score(_subsystem)
        0
      end

      def player
        nil
      end

      def create_pokemon(_species, _level)
        nil
      end

      def recalculate_stats(_pokemon)
        false
      end

      def store_pokemon(_pokemon)
        false
      end

      def data_record(_type, _id)
        [false, nil]
      end

      def add_item(_item, _quantity)
        [false, false]
      end

      def remove_item(_item, _quantity)
        [false, false]
      end

      def input_pressing(_value)
        [false, false]
      end

      def storage_max_boxes
        [false, 0]
      end

      def storage_max_pokemon(_box)
        [false, 0]
      end

      def show_message(_text)
        [false, nil]
      end

      def show_choice(_prompt, _commands, _default)
        [false, -1]
      end

      def confirm(_prompt)
        [false, false]
      end

      def choose_number(_prompt, _params)
        [false, nil]
      end

      def play_decision_sound
        false
      end

      def enter_player_name(prompt, default_name, max_length)
        return [false, nil] unless defined?(pbEnterPlayerName)
        try_signatures([
          proc { pbEnterPlayerName(prompt, 0, max_length, default_name) },
          proc { pbEnterPlayerName(prompt, 0, max_length) },
          proc { pbEnterPlayerName(prompt, default_name) },
          proc { pbEnterPlayerName(default_name) },
          proc { pbEnterPlayerName }
        ])
      end

      def enter_pokemon_name(prompt, pokemon, default_name, max_length)
        return [false, nil] unless defined?(pbEnterPokemonName)
        try_signatures([
          proc { pbEnterPokemonName(prompt, 0, max_length, default_name, pokemon) },
          proc { pbEnterPokemonName(prompt, 0, max_length, pokemon) },
          proc { pbEnterPokemonName(prompt, pokemon) },
          proc { pbEnterPokemonName(pokemon) },
          proc { pbEnterPokemonName }
        ])
      end

      def free_text(prompt, default_text, password, max_length)
        if Kernel.respond_to?(:pbMessageFreeText)
          res = try_signatures([
            proc { Kernel.pbMessageFreeText(prompt, default_text, password, max_length) },
            proc { Kernel.pbMessageFreeText(prompt, default_text, max_length) },
            proc { Kernel.pbMessageFreeText(prompt, default_text) },
            proc { Kernel.pbMessageFreeText(prompt) }
          ])
          return res if res && res[0]
        end
        # Fallback to pbEnterPokemonName if free text is missing in this engine (safe from renaming character!)
        if defined?(pbEnterPokemonName)
          res = try_signatures([
            proc { pbEnterPokemonName(prompt, 0, max_length, default_text) },
            proc { pbEnterPokemonName(prompt, 0, max_length) }
          ])
          return res if res && res[0]
        end
        [false, nil]
      end

      def open_pc
        [false, false]
      end

      def warp_player(_map_id, _x, _y, _direction)
        [false, false]
      end

      def create_move(_move_id)
        [false, nil]
      end

      def learn_move(_pokemon, _move_id)
        [false, false]
      end

      def reset_moves(_pokemon)
        [false, false]
      end

      def restore_pp(_pokemon)
        [false, false]
      end

      def try_signatures(signatures)
        signatures.each do |signature|
          begin
            return [true, signature.call]
          rescue ArgumentError, TypeError
          end
        end
        [false, nil]
      rescue
        [false, nil]
      end


      def open_pc
        signatures = []
        signatures << proc { pbPokeCenterPC } if defined?(pbPokeCenterPC)
        signatures << proc { pbPC } if defined?(pbPC)
        signatures << proc { pbTrainerPC } if defined?(pbTrainerPC)
        if defined?(PokemonPCList) && PokemonPCList.respond_to?(:start)
          signatures << proc { PokemonPCList.start }
        end
        result = try_signatures(signatures)
        [result[0], result[0]]
      rescue
        [false, false]
      end

      def warp_player(map_id, x, y, direction)
        if defined?($game_player) && $game_player && $game_player.respond_to?(:reserve_transfer)
          $game_player.reserve_transfer(map_id, x, y, direction)
          return [true, true]
        end
        if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:player_new_map_id=)
          $game_temp.player_new_map_id = map_id
          $game_temp.player_new_x = x if $game_temp.respond_to?(:player_new_x=)
          $game_temp.player_new_y = y if $game_temp.respond_to?(:player_new_y=)
          $game_temp.player_new_direction = direction if $game_temp.respond_to?(:player_new_direction=)
          $scene.transfer_player if defined?($scene) && $scene && $scene.respond_to?(:transfer_player)
          return [true, true]
        end
        [false, false]
      rescue
        [false, false]
      end

      def start_wild_battle(_pokemon, _species, _level)
        [false, nil]
      end

      def start_trainer_battle(_trainer_type, _trainer_name, _version)
        [false, nil]
      end

      def capabilities
        []
      end
    end

    class Modern < Base
      def id
        :essentials_modern
      end

      def score(subsystem)
        case subsystem
        when :player
          return 100 if defined?($player) && $player
          return 90 if defined?($Player) && $Player
        when :pokemon
          return 100 if defined?(Pokemon) && Pokemon.respond_to?(:new)
        when :storage
          return 100 if defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:pbStoreCaught)
          return 75 if defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:boxes)
        when :battle
          return 100 if defined?(WildBattle) && WildBattle.respond_to?(:start)
          return 95 if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
        when :data
          return 100 if defined?(GameData)
        when :bag
          return 100 if defined?($bag) && $bag
        when :input
          return 90 if defined?(Input) && Input.respond_to?(:press?)
        when :ui
          return 100 if Kernel.respond_to?(:pbMessage)
        when :audio
          return 100 if defined?(pbPlayDecisionSE)
        when :text
          return 100 if defined?(pbEnterPlayerName) || defined?(pbEnterPokemonName) || Kernel.respond_to?(:pbMessageFreeText)
        when :pc
          return 100 if defined?(PokemonPCList) || defined?(pbPokeCenterPC)
        when :map
          return 100 if defined?($game_player) && $game_player && $game_player.respond_to?(:reserve_transfer)
          return 90 if defined?($game_temp) && $game_temp
        when :moves
          return 100 if defined?(Pokemon) && Pokemon.respond_to?(:const_defined?) && Pokemon.const_defined?(:Move)
          return 90 if defined?(pbLearnMove)
        end
        0
      rescue
        0
      end

      def player
        return $player if defined?($player) && $player
        return $Player if defined?($Player) && $Player
        nil
      end

      def create_pokemon(species, level)
        return nil unless defined?(Pokemon) && Pokemon.respond_to?(:new)
        begin
          Pokemon.new(species, level)
        rescue ArgumentError
          Pokemon.new(species, level, player)
        end
      end

      def recalculate_stats(pokemon)
        return false unless pokemon
        if pokemon.respond_to?(:calc_stats)
          pokemon.calc_stats
          return true
        end
        if pokemon.respond_to?(:calcStats)
          pokemon.calcStats
          return true
        end
        false
      end

      def store_pokemon(pokemon)
        return false unless defined?($PokemonStorage) && $PokemonStorage
        return $PokemonStorage.pbStoreCaught(pokemon) if $PokemonStorage.respond_to?(:pbStoreCaught)
        false
      end

      def data_record(type, id)
        return [false, nil] unless defined?(GameData) && GameData.respond_to?(:const_defined?)
        return [false, nil] unless GameData.const_defined?(type)
        data_class = GameData.const_get(type)
        return [false, nil] unless data_class.respond_to?(:get)
        [true, data_class.get(id)]
      rescue
        [false, nil]
      end

      def add_item(item, quantity)
        return [false, false] unless defined?($bag) && $bag && $bag.respond_to?(:add)
        [true, !!$bag.add(item, quantity)]
      rescue
        [false, false]
      end

      def remove_item(item, quantity)
        return [false, false] unless defined?($bag) && $bag && $bag.respond_to?(:remove)
        [true, !!$bag.remove(item, quantity)]
      rescue
        [false, false]
      end

      def input_pressing(value)
        return [false, false] unless defined?(Input) && Input.respond_to?(:press?)
        [true, !!Input.press?(value)]
      rescue
        [false, false]
      end

      def storage_max_boxes
        return [false, 0] unless defined?($PokemonStorage) && $PokemonStorage
        return [true, $PokemonStorage.maxBoxes.to_i] if $PokemonStorage.respond_to?(:maxBoxes)
        return [true, $PokemonStorage.max_boxes.to_i] if $PokemonStorage.respond_to?(:max_boxes)
        return [true, $PokemonStorage.boxes.length.to_i] if $PokemonStorage.respond_to?(:boxes) && $PokemonStorage.boxes
        [false, 0]
      rescue
        [false, 0]
      end

      def storage_max_pokemon(box)
        return [false, 0] unless defined?($PokemonStorage) && $PokemonStorage
        return [true, $PokemonStorage.maxPokemon(box).to_i] if $PokemonStorage.respond_to?(:maxPokemon)
        return [true, $PokemonStorage.max_pokemon(box).to_i] if $PokemonStorage.respond_to?(:max_pokemon)
        current_box = $PokemonStorage[box] if $PokemonStorage.respond_to?(:[])
        return [true, current_box.length.to_i] if current_box && current_box.respond_to?(:length)
        [false, 0]
      rescue
        [false, 0]
      end

      def show_message(text)
        return [false, nil] unless Kernel.respond_to?(:pbMessage)
        [true, Kernel.pbMessage(text)]
      rescue
        [false, nil]
      end

      def show_choice(prompt, commands, default)
        return [false, -1] unless Kernel.respond_to?(:pbMessage)
        [true, Kernel.pbMessage(prompt, commands, default)]
      rescue ArgumentError
        begin
          [true, Kernel.pbMessage(prompt, commands)]
        rescue
          [false, -1]
        end
      rescue
        [false, -1]
      end

      def confirm(prompt)
        return [true, !!Kernel.pbConfirmMessage(prompt)] if Kernel.respond_to?(:pbConfirmMessage)
        choice = show_choice(prompt, ["Yes", "No"], 1)
        return [true, choice[1].to_i == 0] if choice[0]
        [false, false]
      rescue
        [false, false]
      end

      def choose_number(prompt, params)
        return [false, nil] unless Kernel.respond_to?(:pbMessageChooseNumber)
        [true, Kernel.pbMessageChooseNumber(prompt, params)]
      rescue
        [false, nil]
      end

      def play_decision_sound
        return false unless defined?(pbPlayDecisionSE)
        pbPlayDecisionSE
        true
      rescue
        false
      end

      def start_wild_battle(pokemon, species, level)
        return [false, nil] unless defined?(WildBattle) && WildBattle.respond_to?(:start)
        begin
          return [true, WildBattle.start(pokemon, level)] if pokemon
        rescue ArgumentError, TypeError
        end
        [true, WildBattle.start(species, level)]
      rescue
        [false, nil]
      end

      def start_trainer_battle(trainer_type, trainer_name, version)
        return [false, nil] unless defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
        begin
          [true, TrainerBattle.start(trainer_type, trainer_name, version)]
        rescue ArgumentError
          [true, TrainerBattle.start(trainer_type, trainer_name)]
        end
      rescue
        [false, nil]
      end

      def capabilities
        [:player, :pokemon, :storage, :battle, :data, :bag, :input, :ui, :audio, :text, :pc, :map, :moves].select { |name| score(name) > 0 }
      end

      def create_move(move_id)
        return [false, nil] unless defined?(Pokemon) && Pokemon.respond_to?(:const_defined?) && Pokemon.const_defined?(:Move)
        [true, Pokemon::Move.new(move_id)]
      rescue
        [false, nil]
      end

      def learn_move(pokemon, move_id)
        return [true, pokemon.learn_move(move_id) != false] if pokemon && pokemon.respond_to?(:learn_move)
        return [true, pokemon.pbLearnMove(move_id) != false] if pokemon && pokemon.respond_to?(:pbLearnMove)
        return [true, pbLearnMove(pokemon, move_id) != false] if defined?(pbLearnMove)
        [false, false]
      rescue
        [false, false]
      end

      def reset_moves(pokemon)
        return [false, false] unless pokemon
        if pokemon.respond_to?(:reset_moves)
          pokemon.reset_moves
          return [true, true]
        end
        [false, false]
      rescue
        [false, false]
      end

      def restore_pp(pokemon)
        return [false, false] unless pokemon
        if pokemon.respond_to?(:heal_PP)
          pokemon.heal_PP
          return [true, true]
        end
        [false, false]
      rescue
        [false, false]
      end
    end

    class LegacyRecord
    attr_reader :id, :id_number

    def initialize(type, id)
      @type = type
      @id = id
      @id_number = get_id_number(type, id)
    end

    def get_id_number(type, id)
      case type
      when :Species
        if defined?(PBSpecies)
          id.is_a?(Symbol) ? (PBSpecies.const_get(id) rescue 0) : id.to_i
        else
          id.respond_to?(:to_i) ? id.to_i : 0
        end
      when :Item
        if defined?(PBItems)
          id.is_a?(Symbol) ? (PBItems.const_get(id) rescue 0) : id.to_i
        else
          id.respond_to?(:to_i) ? id.to_i : 0
        end
      when :Move
        if defined?(PBMoves)
          id.is_a?(Symbol) ? (PBMoves.const_get(id) rescue 0) : id.to_i
        else
          id.respond_to?(:to_i) ? id.to_i : 0
        end
      when :Ability
        if defined?(PBAbilities)
          id.is_a?(Symbol) ? (PBAbilities.const_get(id) rescue 0) : id.to_i
        else
          id.respond_to?(:to_i) ? id.to_i : 0
        end
      else
        id.respond_to?(:to_i) ? id.to_i : 0
      end
    end

    def is_key_item?
      return false unless @type == :Item
      if defined?(pbIsKeyItem?)
        return pbIsKeyItem?(@id) || pbIsKeyItem?(@id_number)
      end
      false
    end

    def is_important?
      is_key_item?
    end

    def forms
      [0]
    end
  end

  class Legacy < Base

      def id
        :essentials_legacy
      end

      def score(subsystem)
        case subsystem
        when :player
          return 100 if defined?($Trainer) && $Trainer
        when :pokemon
          return 100 if defined?(PokeBattle_Pokemon) && PokeBattle_Pokemon.respond_to?(:new)
        when :storage
          return 70 if defined?($PokemonStorage) && $PokemonStorage
        when :battle
          return 90 if defined?(pbWildBattle) || defined?(pbTrainerBattle)
        when :data
          return 80 if defined?($cache) && $cache
          return 70 if defined?(PBSpecies) || defined?(PBItems) || defined?(PBMoves)
        when :bag
          return 100 if defined?($PokemonBag) && $PokemonBag
        when :input
          return 80 if defined?(Input) && Input.respond_to?(:press?)
        when :ui
          return 90 if Kernel.respond_to?(:pbMessage)
        when :audio
          return 90 if defined?(pbPlayDecisionSE)
        when :text
          return 90 if defined?(pbEnterPlayerName) || defined?(pbEnterPokemonName) || Kernel.respond_to?(:pbMessageFreeText)
        when :pc
          return 90 if defined?(pbPokeCenterPC) || defined?(pbPC) || defined?(pbTrainerPC)
        when :map
          return 90 if defined?($game_temp) && $game_temp
        when :moves
          return 100 if defined?(PBMove)
          return 90 if defined?(pbLearnMove)
        end
        0
      rescue
        0
      end

      def legacy_cache_collection(type)
        return nil unless defined?($cache) && $cache
        mapping = {
          :Species => [:pkmn, :pokemon, :species],
          :Item => [:items, :item, :itemData],
          :Move => [:moves, :move, :moveData],
          :Ability => [:abilities, :ability, :abil],
          :Nature => [:natures, :nature],
          :Type => [:types, :type],
          :Ribbon => [:ribbons, :ribbon],
          :TrainerType => [:trainertypes, :trainer_types, :trainers, :trainerTypes]
        }
        (mapping[type] || []).each do |reader|
          return $cache.send(reader) if $cache.respond_to?(reader)
        end
        nil
      rescue
        nil
      end

      def legacy_record_identifier(record)
        return nil unless record
        return record.id if record.respond_to?(:id)
        return record.ID if record.respond_to?(:ID)
        return record.id_number if record.respond_to?(:id_number)
        return record.species if record.respond_to?(:species)
        nil
      rescue
        nil
      end

      def legacy_cached_record(type, id)
        collection = legacy_cache_collection(type)
        return nil unless collection
        if collection.respond_to?(:[]) && collection.respond_to?(:keys)
          candidates = [id]
          candidates << id.to_s if id.respond_to?(:to_s)
          candidates << id.to_sym if id.respond_to?(:to_sym)
          candidates.each do |candidate|
            begin
              value = collection[candidate]
              return value unless value.nil?
            rescue
            end
          end
        elsif collection.respond_to?(:[]) && id.is_a?(Numeric)
          begin
            value = collection[id.to_i]
            return value unless value.nil?
          rescue
          end
        end
        if collection.respond_to?(:keys) && collection.respond_to?(:each)
          collection.each do |key, record|
            return record if key == id || key.to_s == id.to_s
            record_id = legacy_record_identifier(record)
            return record if record_id == id || (!record_id.nil? && record_id.to_s == id.to_s)
          end
        elsif collection.respond_to?(:each_with_index)
          collection.each_with_index do |record, index|
            return record if id.is_a?(Numeric) && index == id.to_i && !record.nil?
            record_id = legacy_record_identifier(record)
            return record if record_id == id || (!record_id.nil? && record_id.to_s == id.to_s)
          end
        end
        nil
      rescue
        nil
      end

      def data_record(type, id)
        return [false, nil] if id.nil? || id == 0 || id == :None || id == ""
        cached = legacy_cached_record(type, id)
        return [true, cached] if cached
        [true, LegacyRecord.new(type, id)]
      rescue
        [false, nil]
      end

      def player
        return $Trainer.player if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:player)
        return $Trainer if defined?($Trainer) && $Trainer
        nil
      end

      def create_pokemon(species, level)
        return nil unless defined?(PokeBattle_Pokemon)
        begin
          PokeBattle_Pokemon.new(species, level, player)
        rescue ArgumentError
          PokeBattle_Pokemon.new(species, level)
        end
      end

      def recalculate_stats(pokemon)
        return false unless pokemon
        if pokemon.respond_to?(:calcStats)
          pokemon.calcStats
          return true
        end
        if pokemon.respond_to?(:calc_stats)
          pokemon.calc_stats
          return true
        end
        false
      end

      def store_pokemon(pokemon)
        return false unless defined?($PokemonStorage) && $PokemonStorage
        return $PokemonStorage.pbStoreCaught(pokemon) if $PokemonStorage.respond_to?(:pbStoreCaught)
        false
      end

      def add_item(item, quantity)
        return [false, false] unless defined?($PokemonBag) && $PokemonBag
        if $PokemonBag.respond_to?(:pbStoreItem)
          begin
            return [true, !!$PokemonBag.pbStoreItem(item, quantity)]
          rescue ArgumentError
            return [true, !!$PokemonBag.pbStoreItem(item)]
          end
        end
        return [true, !!$PokemonBag.storeItem(item, quantity)] if $PokemonBag.respond_to?(:storeItem)
        return [true, !!$PokemonBag.add(item, quantity)] if $PokemonBag.respond_to?(:add)
        [false, false]
      rescue
        [false, false]
      end

      def remove_item(item, quantity)
        return [false, false] unless defined?($PokemonBag) && $PokemonBag
        if $PokemonBag.respond_to?(:pbDeleteItem)
          begin
            return [true, !!$PokemonBag.pbDeleteItem(item, quantity)]
          rescue ArgumentError
            return [true, !!$PokemonBag.pbDeleteItem(item)]
          end
        end
        return [true, !!$PokemonBag.deleteItem(item, quantity)] if $PokemonBag.respond_to?(:deleteItem)
        return [true, !!$PokemonBag.remove(item, quantity)] if $PokemonBag.respond_to?(:remove)
        [false, false]
      rescue
        [false, false]
      end

      def input_pressing(value)
        return [false, false] unless defined?(Input) && Input.respond_to?(:press?)
        [true, !!Input.press?(value)]
      rescue
        [false, false]
      end

      def storage_max_boxes
        return [false, 0] unless defined?($PokemonStorage) && $PokemonStorage
        return [true, $PokemonStorage.maxBoxes.to_i] if $PokemonStorage.respond_to?(:maxBoxes)
        return [true, $PokemonStorage.boxes.length.to_i] if $PokemonStorage.respond_to?(:boxes) && $PokemonStorage.boxes
        [false, 0]
      rescue
        [false, 0]
      end

      def storage_max_pokemon(box)
        return [false, 0] unless defined?($PokemonStorage) && $PokemonStorage
        return [true, $PokemonStorage.maxPokemon(box).to_i] if $PokemonStorage.respond_to?(:maxPokemon)
        current_box = $PokemonStorage[box] if $PokemonStorage.respond_to?(:[])
        return [true, current_box.length.to_i] if current_box && current_box.respond_to?(:length)
        [false, 0]
      rescue
        [false, 0]
      end

      def show_message(text)
        return [false, nil] unless Kernel.respond_to?(:pbMessage)
        [true, Kernel.pbMessage(text)]
      rescue
        [false, nil]
      end

      def show_choice(prompt, commands, default)
        return [false, -1] unless Kernel.respond_to?(:pbMessage)
        begin
          [true, Kernel.pbMessage(prompt, commands, default)]
        rescue ArgumentError
          [true, Kernel.pbMessage(prompt, commands)]
        end
      rescue
        [false, -1]
      end

      def confirm(prompt)
        return [true, !!Kernel.pbConfirmMessage(prompt)] if Kernel.respond_to?(:pbConfirmMessage)
        choice = show_choice(prompt, ["Yes", "No"], 1)
        return [true, choice[1].to_i == 0] if choice[0]
        [false, false]
      rescue
        [false, false]
      end

      def choose_number(prompt, params)
        return [false, nil] unless Kernel.respond_to?(:pbMessageChooseNumber)
        [true, Kernel.pbMessageChooseNumber(prompt, params)]
      rescue
        [false, nil]
      end

      def play_decision_sound
        return false unless defined?(pbPlayDecisionSE)
        pbPlayDecisionSE
        true
      rescue
        false
      end

      def start_wild_battle(pokemon, species, level)
        return [false, nil] unless defined?(pbWildBattle)
        begin
          return [true, pbWildBattle(species, level)]
        rescue ArgumentError, TypeError
        end
        return [true, pbWildBattle(pokemon)] if pokemon
        [false, nil]
      rescue
        [false, nil]
      end

      def start_trainer_battle(trainer_type, trainer_name, version)
        return [false, nil] unless defined?(pbTrainerBattle)
        attempts = [
          [trainer_type, trainer_name, nil, false, version],
          [trainer_type, trainer_name, nil, false],
          [trainer_type, trainer_name],
          [trainer_type, trainer_name, version]
        ]
        attempts.each do |args|
          begin
            return [true, pbTrainerBattle(*args)]
          rescue ArgumentError, TypeError
          end
        end
        [false, nil]
      rescue
        [false, nil]
      end

      def capabilities
        [:player, :pokemon, :storage, :battle, :data, :bag, :input, :ui, :audio, :text, :pc, :map, :moves].select { |name| score(name) > 0 }
      end

      def create_move(move_id)
        return [false, nil] unless defined?(PBMove)
        [true, PBMove.new(move_id)]
      rescue
        [false, nil]
      end

      def learn_move(pokemon, move_id)
        return [true, pokemon.learnMove(move_id) != false] if pokemon && pokemon.respond_to?(:learnMove)
        return [true, pokemon.pbLearnMove(move_id) != false] if pokemon && pokemon.respond_to?(:pbLearnMove)
        return [true, pbLearnMove(pokemon, move_id) != false] if defined?(pbLearnMove)
        [false, false]
      rescue
        [false, false]
      end

      def reset_moves(pokemon)
        return [false, false] unless pokemon
        if pokemon.respond_to?(:resetMoves)
          pokemon.resetMoves
          return [true, true]
        end
        [false, false]
      rescue
        [false, false]
      end

      def restore_pp(pokemon)
        return [false, false] unless pokemon
        if pokemon.respond_to?(:healPP)
          pokemon.healPP
          return [true, true]
        end
        [false, false]
      rescue
        [false, false]
      end
    end
  end

  class << self
    def engine_adapter_candidates
      @engine_adapter_candidates ||= [EngineAdapters::Modern.new, EngineAdapters::Legacy.new]
    end

    def reset_engine_adapters!
      @engine_adapters = {}
      @engine_adapter_candidates = nil
      true
    end

    def engine_adapter_for(subsystem)
      @engine_adapters ||= {}
      return @engine_adapters[subsystem] if @engine_adapters[subsystem]
      ranked = engine_adapter_candidates.map { |adapter| [adapter.score(subsystem), adapter] }
      selected = ranked.sort_by { |entry| -entry[0].to_i }.first
      adapter = selected && selected[0].to_i > 0 ? selected[1] : EngineAdapters::Base.new
      @engine_adapters[subsystem] = adapter
      adapter
    rescue => e
      log_error("Engine Adapter #{subsystem}", e)
      EngineAdapters::Base.new
    end

    def engine_adapter_summary
      [:player, :pokemon, :storage, :battle, :data, :bag, :input, :ui, :audio, :text, :pc, :map, :moves].map do |subsystem|
        adapter = engine_adapter_for(subsystem)
        "#{subsystem}=#{adapter.id}(score=#{adapter.score(subsystem)})"
      end
    rescue => e
      log_error("Engine Adapter Summary", e)
      []
    end

    def play_decision_sound
      adapter = engine_adapter_for(:audio)
      return true if adapter && adapter.play_decision_sound
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      true
    rescue => e
      log_error("Decision Sound", e)
      false
    end

    def play_cancel_sound
      pbPlayCancelSE if defined?(pbPlayCancelSE)
      true
    rescue => e
      log_error("Cancel Sound", e)
      false
    end

    def play_cursor_sound
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      true
    rescue => e
      log_error("Cursor Sound", e)
      false
    end

    def safe_free_text(prompt, default_text = "", password = false, max_length = 256, context_name = "Free Text")
      # Rejuvenation and Pokemon Z expose a four-argument API shaped as
      # (message, current_text, max_length, window_width), not the modern
      # (message, current_text, password, max_length). Passing false in the
      # third slot silently sets its maximum length to zero.
      legacy_four_argument_text = rejuvenation_engine?
      legacy_four_argument_text ||= respond_to?(:pokemon_z_engine?) && pokemon_z_engine?
      if legacy_four_argument_text && Kernel.respond_to?(:pbMessageFreeText)
        width = defined?(Graphics) && Graphics.respond_to?(:width) ? Graphics.width : 512
        return Kernel.pbMessageFreeText(_INTL(prompt.to_s), default_text.to_s, max_length.to_i, width)
      end
      adapter = engine_adapter_for(:text)
      result = adapter.free_text(_INTL(prompt.to_s), default_text.to_s, !!password, max_length.to_i)
      return result[1] if result && result[0]
      nil
    rescue => e
      log_error(context_name, e)
      nil
    end
