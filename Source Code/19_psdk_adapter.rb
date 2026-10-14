# Compatibility layer for Pokemon SDK / Pokemon Studio games.
# This file intentionally keeps legacy-compatible syntax because it is bundled
# with the same monolithic runtime used by RGSS1 games.
module DeveloperMenu
  module PSDKCompat
    DEVICE_ITEM_ID = :pokedebug_device
    DEVICE_NAME = "PokeDebug Device"
    DEVICE_DESCRIPTION = "Use it to open the PokeDebug menu."
    TRANSLATIONS = DeveloperMenu.const_get(:TR)

    class NumberParams
      attr_reader :min_value, :max_value, :initial_value, :cancel_value

      def initialize
        @min_value = 0
        @max_value = 999
        @initial_value = 0
        @cancel_value = 0
      end

      def setRange(minimum, maximum)
        @min_value = minimum.to_i
        @max_value = maximum.to_i
      end

      def setInitialValue(value)
        @initial_value = value.to_i
      end

      def setDefaultValue(value)
        setInitialValue(value)
      end

      def setCancelValue(value)
        @cancel_value = value.to_i
      end

      def setNegativesAllowed(_value)
      end
    end

    class PlayerFacade
      def initialize(state)
        @state = state
      end

      def trainer
        @state.respond_to?(:trainer) ? @state.trainer : nil
      end

      def party
        @state.respond_to?(:actors) ? @state.actors : []
      end

      def money
        @state.respond_to?(:money) ? @state.money : 0
      end

      def money=(value)
        @state.money = value if @state.respond_to?(:money=)
      end

      def pokedex
        @state.respond_to?(:pokedex) ? @state.pokedex : nil
      end

      def method_missing(name, *args, &block)
        target = trainer
        return target.send(name, *args, &block) if target && target.respond_to?(name)
        return @state.send(name, *args, &block) if @state.respond_to?(name)
        super
      end

      def respond_to?(name, include_private = false)
        target = trainer
        super || (target && target.respond_to?(name, include_private)) || @state.respond_to?(name, include_private)
      end
    end

    class << self
      def active?
        defined?(PFM) && PFM.respond_to?(:game_state)
      rescue StandardError
        false
      end

      def game_state
        return nil unless active?
        PFM.game_state
      rescue StandardError
        nil
      end

      def current_scene
        defined?($scene) ? $scene : nil
      end

      def message_api_ready?(scene = nil)
        scene ||= current_scene
        return false unless scene
        if scene.respond_to?(:can_display_message_be_called?)
          return false unless scene.can_display_message_be_called?
        end
        if scene.respond_to?(:message_processing?)
          return false if scene.message_processing?
        end
        return false if scene.instance_variable_get(:@still_in_display_message)
        true
      rescue StandardError
        false
      end

      def global_receiver
        @global_receiver ||= Object.new
      end

      def call_global(name, *args, &block)
        receiver = global_receiver
        return receiver.send(name, *args, &block) if receiver.respond_to?(name, true)
        return Kernel.send(name, *args, &block) if Kernel.respond_to?(name, true)
        nil
      end

      def display_message(message, commands = nil, default = -1)
        scene = current_scene
        raise "PSDK scene is not ready" unless scene
        raise "PSDK message API is busy" unless message_api_ready?(scene)
        result = nil
        if commands && !commands.empty?
          start = default.to_i >= 0 ? default.to_i + 1 : 1
          if scene.respond_to?(:display_message_and_wait)
            result = scene.display_message_and_wait(message.to_s, start, *commands)
          elsif scene.respond_to?(:display_message)
            result = scene.display_message(message.to_s, start, *commands)
          else
            raise "Current PSDK scene has no message API"
          end
          return -1 if result.nil? || result.to_i < 0 || result.to_i >= commands.length
          return result.to_i
        else
          return scene.display_message_and_wait(message.to_s) if scene.respond_to?(:display_message_and_wait)
          return scene.display_message(message.to_s) if scene.respond_to?(:display_message)
        end
        raise "Current PSDK scene has no message API"
      end

      def choose_number(params)
        initial = params.respond_to?(:initial_value) ? params.initial_value.to_i : 0
        minimum = params.respond_to?(:min_value) ? params.min_value.to_i : 0
        maximum = params.respond_to?(:max_value) ? params.max_value.to_i : 999
        if defined?(GamePlay) && GamePlay.const_defined?(:NumberInput)
          digits = [minimum.abs.to_s.length, maximum.abs.to_s.length, 1].max
          input = GamePlay::NumberInput.new(initial.to_s, digits)
          value = input.main
          value = value.to_i
          value = minimum if value < minimum
          value = maximum if value > maximum
          return value
        end
        initial
      rescue StandardError
        params.respond_to?(:cancel_value) ? params.cancel_value.to_i : 0
      end

      def enter_text(default_text, max_length)
        if defined?(GamePlay) && GamePlay.const_defined?(:NameInput)
          input = GamePlay::NameInput.new(default_text.to_s, max_length.to_i)
          return input.main
        end
        default_text.to_s
      rescue StandardError
        default_text.to_s
      end

      def game_data
        receiver = global_receiver
        return nil unless receiver.respond_to?(:__game_data, true)
        receiver.send(:__game_data)
      rescue StandardError
        nil
      end

      def device_item_class
        return DeveloperMenu.const_get(:PSDKDeviceItem) if DeveloperMenu.const_defined?(:PSDKDeviceItem)
        return nil unless defined?(Studio) && Studio.const_defined?(:Item)
        klass = Class.new(Studio::Item) do
          define_method(:name) { |*args| DeveloperMenu::PSDKCompat::DEVICE_NAME }
          define_method(:plural_name) { |*args| DeveloperMenu::PSDKCompat::DEVICE_NAME }
          define_method(:exact_name) { |*args| DeveloperMenu::PSDKCompat::DEVICE_NAME }
          define_method(:descr) { |*args| DeveloperMenu::PSDKCompat::DEVICE_DESCRIPTION }
          define_method(:description) { |*args| DeveloperMenu::PSDKCompat::DEVICE_DESCRIPTION }
        end
        DeveloperMenu.const_set(:PSDKDeviceItem, klass)
        klass
      rescue StandardError
        nil
      end

      def register_device_item!
        data = game_data
        klass = device_item_class
        return false unless data && klass && data[:items].respond_to?(:[]=) && data[:items__id].respond_to?(:[]=)
        existing = data[:items][DEVICE_ITEM_ID]
        if existing && existing.respond_to?(:db_symbol) && existing.db_symbol == DEVICE_ITEM_ID
          return register_device_handler!(klass) && validate_device_item!(existing)
        end

        base = data[:items][:town_map] || data[:items][:__undef__]
        return false unless base
        item = klass.allocate
        base.instance_variables.each do |variable|
          item.instance_variable_set(variable, base.instance_variable_get(variable))
        end
        item_id = data[:items__id].length
        position = data[:items].values.inject(0) do |maximum, candidate|
          value = candidate && candidate.instance_variable_get(:@socket).to_i == 5 ? candidate.instance_variable_get(:@position).to_i : 0
          value > maximum ? value : maximum
        end
        item.instance_variable_set(:@id, item_id)
        item.instance_variable_set(:@db_symbol, DEVICE_ITEM_ID)
        item.instance_variable_set(:@icon, base.respond_to?(:icon) ? base.icon : "442")
        item.instance_variable_set(:@price, 0)
        item.instance_variable_set(:@socket, 5)
        item.instance_variable_set(:@position, position + 1)
        item.instance_variable_set(:@is_battle_usable, false)
        item.instance_variable_set(:@is_map_usable, true)
        item.instance_variable_set(:@is_limited, false)
        item.instance_variable_set(:@is_holdable, false)
        item.instance_variable_set(:@fling_power, 0)
        data[:items][DEVICE_ITEM_ID] = item
        data[:items__id][item_id] = item
        register_device_handler!(klass) && validate_device_item!(item)
      rescue StandardError => error
        DeveloperMenu.throttled_log_error("Register PSDK Device Item", error) if DeveloperMenu.respond_to?(:throttled_log_error)
        false
      end

      def validate_device_item!(item)
        return false unless item && item.respond_to?(:name) && item.name.to_s == DEVICE_NAME
        return false unless item.respond_to?(:exact_name) && item.exact_name.to_s == DEVICE_NAME
        return false unless item.respond_to?(:db_symbol) && item.db_symbol == DEVICE_ITEM_ID
        return false unless defined?(PFM::ItemDescriptor) && PFM::ItemDescriptor.respond_to?(:actions)
        actions = PFM::ItemDescriptor.actions(DEVICE_ITEM_ID)
        return false unless actions && actions.respond_to?(:on_use)
        if !@device_validation_logged && DeveloperMenu.respond_to?(:write_developer_log)
          DeveloperMenu.write_developer_log("mobile", "PokeDebug Device validated", "name=#{item.name.inspect} id=#{item.id} socket=#{item.socket}")
          @device_validation_logged = true
        end
        true
      rescue StandardError => error
        DeveloperMenu.throttled_log_error("Validate PSDK Device Item", error) if DeveloperMenu.respond_to?(:throttled_log_error)
        false
      end

      def register_device_handler!(klass = nil)
        return true if @device_handler_registered
        klass ||= device_item_class
        return false unless klass && defined?(PFM::ItemDescriptor) && PFM::ItemDescriptor.respond_to?(:define_bag_use)
        PFM::ItemDescriptor.define_bag_use(klass, true) do |_item, scene|
          scene.instance_variable_set(:@running, false) if scene
          DeveloperMenu.queue_pokedebug_device_menu!("PSDK bag")
          true
        end
        @device_handler_registered = true
        DeveloperMenu.write_developer_log("mobile", "PokeDebug Device handlers installed", "PSDK item=#{DEVICE_ITEM_ID.inspect}") if DeveloperMenu.respond_to?(:write_developer_log)
        true
      rescue StandardError => error
        DeveloperMenu.throttled_log_error("Register PSDK Device Handler", error) if DeveloperMenu.respond_to?(:throttled_log_error)
        false
      end


      def native_debug_only_flag_path
        File.expand_path(File.join("PokeDebug", "native_debug_only.flag"), Dir.pwd)
      end

      def native_debug_only?
        File.file?(native_debug_only_flag_path)
      rescue StandardError
        false
      end

      def install_bag_device_hook!
        return true if native_debug_only?
        return false unless defined?(GamePlay) && GamePlay.const_defined?(:Bag)
        klass = GamePlay.const_get(:Bag)
        return true if klass.method_defined?(:pokedebug_main_without_temporary_device)
        klass.class_eval do
          alias_method :pokedebug_main_without_temporary_device, :main
          def main(*args, &block)
            DeveloperMenu.give_pokedebug_device! if defined?(DeveloperMenu)
            pokedebug_main_without_temporary_device(*args, &block)
          ensure
            DeveloperMenu.remove_pokedebug_device! if defined?(DeveloperMenu)
          end
        end
        DeveloperMenu.write_developer_log("mobile", "PSDK temporary Device hook installed", klass.to_s) if DeveloperMenu.respond_to?(:write_developer_log)
        true
      rescue StandardError => error
        DeveloperMenu.throttled_log_error("Install PSDK Temporary Device Hook", error) if DeveloperMenu.respond_to?(:throttled_log_error)
        false
      end
    end
  end

  module EngineAdapters
    class PSDK < Base
      def id
        :psdk
      end

      def state
        DeveloperMenu::PSDKCompat.game_state
      end

      def score(subsystem)
        return 0 unless DeveloperMenu::PSDKCompat.active?
        return 120 if [:player, :pokemon, :storage, :data, :bag, :input, :ui, :text, :moves].include?(subsystem)
        return 80 if [:audio, :pc, :map].include?(subsystem)
        0
      rescue StandardError
        0
      end

      def player
        return nil unless state
        @player_facade = nil if @player_facade && @player_facade.instance_variable_get(:@state) != state
        @player_facade ||= DeveloperMenu::PSDKCompat::PlayerFacade.new(state)
      end

      def create_pokemon(species, level)
        return nil unless defined?(PFM) && PFM.const_defined?(:Pokemon)
        PFM::Pokemon.new(species, level.to_i)
      rescue StandardError
        nil
      end

      def recalculate_stats(pokemon)
        return false unless pokemon
        pokemon.level_up_stat_refresh if pokemon.respond_to?(:level_up_stat_refresh)
        true
      rescue StandardError
        false
      end

      def store_pokemon(pokemon)
        return false unless state && state.respond_to?(:storage) && state.storage
        state.storage.store(pokemon) != false
      rescue StandardError
        false
      end

      def data_method_for(type, each_entry = false)
        prefix = each_entry ? "each_data_" : "data_"
        suffix = case type
                 when :Species then "creature"
                 when :Item then "item"
                 when :Move then "move"
                 when :Ability then "ability"
                 when :Nature then "nature"
                 when :Type then "type"
                 when :TrainerType then "trainer"
                 else nil
                 end
        suffix ? (prefix + suffix).to_sym : nil
      end

      def data_record(type, id)
        method_name = data_method_for(type, false)
        return [false, nil] unless method_name
        record = DeveloperMenu::PSDKCompat.call_global(method_name, id)
        # PSDK returns its __undef__ database object for an unknown symbol.
        # Treating that sentinel as the requested record made invalid IDs look
        # valid and later caused item/species operations to target __undef__.
        if record && record.respond_to?(:db_symbol) && record.db_symbol == :__undef__ && id != :__undef__
          record = nil
        end
        [true, record]
      rescue StandardError
        [false, nil]
      end

      def data_entries(type)
        method_name = data_method_for(type, true)
        return [false, []] unless method_name
        entries = []
        DeveloperMenu::PSDKCompat.call_global(method_name) { |entry| entries << entry if entry }
        [true, entries]
      rescue StandardError
        [false, []]
      end

      def bag
        state && state.respond_to?(:bag) ? state.bag : nil
      end

      def add_item(item, quantity)
        return [false, false] unless bag && bag.respond_to?(:add_item)
        [true, bag.add_item(item, quantity.to_i) != false]
      rescue StandardError
        [false, false]
      end

      def remove_item(item, quantity)
        return [false, false] unless bag && bag.respond_to?(:remove_item)
        [true, bag.remove_item(item, quantity.to_i) != false]
      rescue StandardError
        [false, false]
      end

      def input_pressing(value)
        return [false, false] unless defined?(Input) && Input.respond_to?(:press?)
        [true, !!Input.press?(value)]
      rescue StandardError
        [false, false]
      end

      def storage_max_boxes
        storage = state && state.respond_to?(:storage) ? state.storage : nil
        return [false, 0] unless storage && storage.respond_to?(:box_count)
        [true, storage.box_count.to_i]
      rescue StandardError
        [false, 0]
      end

      def storage_max_pokemon(box)
        storage = state && state.respond_to?(:storage) ? state.storage : nil
        return [false, 0] unless storage
        if defined?(PFM::Storage) && PFM::Storage.respond_to?(:box_size)
          return [true, PFM::Storage.box_size.to_i]
        end
        content = storage.get_box_content(box) if storage.respond_to?(:get_box_content)
        [!content.nil?, content ? content.length.to_i : 0]
      rescue StandardError
        [false, 0]
      end

      def show_message(text)
        [true, DeveloperMenu::PSDKCompat.display_message(text)]
      rescue StandardError, ScriptError => error
        DeveloperMenu.throttled_log_error("PSDK Show Message", error) if DeveloperMenu.respond_to?(:throttled_log_error)
        [true, nil]
      end

      def show_choice(prompt, commands, default)
        [true, DeveloperMenu::PSDKCompat.display_message(prompt, commands, default)]
      rescue StandardError, ScriptError => error
        DeveloperMenu.throttled_log_error("PSDK Show Choice", error) if DeveloperMenu.respond_to?(:throttled_log_error)
        [true, -1]
      end

      def confirm(prompt)
        choice = show_choice(prompt, ["Yes", "No"], 1)
        [choice[0], choice[0] && choice[1].to_i == 0]
      rescue StandardError
        [false, false]
      end

      def choose_number(_prompt, params)
        [true, DeveloperMenu::PSDKCompat.choose_number(params)]
      rescue StandardError
        [false, nil]
      end

      def enter_player_name(_prompt, default_name, max_length)
        [true, DeveloperMenu::PSDKCompat.enter_text(default_name, max_length)]
      end

      def enter_pokemon_name(_prompt, _pokemon, default_name, max_length)
        [true, DeveloperMenu::PSDKCompat.enter_text(default_name, max_length)]
      end

      def free_text(_prompt, default_text, _password, max_length)
        [true, DeveloperMenu::PSDKCompat.enter_text(default_text, max_length)]
      end

      def open_pc
        return [false, false] unless defined?(GamePlay) && GamePlay.const_defined?(:PokemonStorage)
        scene = GamePlay::PokemonStorage.new
        scene.main
        [true, true]
      rescue StandardError
        [false, false]
      end

      def create_move(move_id)
        return [false, nil] unless defined?(PFM) && PFM.const_defined?(:Skill)
        [true, PFM::Skill.new(move_id)]
      rescue StandardError
        [false, nil]
      end

      def restore_pp(pokemon)
        return [false, false] unless pokemon
        if pokemon.respond_to?(:skills)
          pokemon.skills.compact.each do |skill|
            skill.pp = skill.data.pp if skill.respond_to?(:pp=) && skill.respond_to?(:data) && skill.data.respond_to?(:pp)
          end
          return [true, true]
        end
        [false, false]
      rescue StandardError
        [false, false]
      end

      def capabilities
        [:player, :pokemon, :storage, :data, :bag, :input, :ui, :text, :moves, :pc]
      end
    end
  end
end

if DeveloperMenu::PSDKCompat.active?
  psdk_translation_table = DeveloperMenu::PSDKCompat::TRANSLATIONS
  DeveloperMenu.const_set(:TR, psdk_translation_table) unless DeveloperMenu.const_defined?(:TR, false)
  Object.const_set(:TR, psdk_translation_table) unless Object.const_defined?(:TR)

  def DeveloperMenu.const_missing(name)
    return DeveloperMenu::PSDKCompat::TRANSLATIONS if name == :TR
    super
  end

  class << DeveloperMenu
    unless method_defined?(:register_pokedebug_device_item_without_psdk!)
      alias_method :register_pokedebug_device_item_without_psdk!, :register_pokedebug_device_item!
    end

    unless method_defined?(:register_pokedebug_device_handlers_without_psdk!)
      alias_method :register_pokedebug_device_handlers_without_psdk!, :register_pokedebug_device_handlers!
    end

    unless method_defined?(:pokedebug_device_storage_id_without_psdk)
      alias_method :pokedebug_device_storage_id_without_psdk, :pokedebug_device_storage_id
    end

    unless method_defined?(:pokedebug_device_item_record_without_psdk)
      alias_method :pokedebug_device_item_record_without_psdk, :pokedebug_device_item_record
    end

    unless method_defined?(:ensure_pokedebug_device_without_psdk!)
      alias_method :ensure_pokedebug_device_without_psdk!, :ensure_pokedebug_device!
    end

    def register_pokedebug_device_item!
      return DeveloperMenu::PSDKCompat.register_device_item! if DeveloperMenu::PSDKCompat.active?
      register_pokedebug_device_item_without_psdk!
    end

    def register_pokedebug_device_handlers!
      return DeveloperMenu::PSDKCompat.register_device_handler! if DeveloperMenu::PSDKCompat.active?
      register_pokedebug_device_handlers_without_psdk!
    end

    def pokedebug_device_storage_id
      return DeveloperMenu::PSDKCompat::DEVICE_ITEM_ID if DeveloperMenu::PSDKCompat.active?
      pokedebug_device_storage_id_without_psdk
    end

    def pokedebug_device_item_record
      if DeveloperMenu::PSDKCompat.active?
        data = DeveloperMenu::PSDKCompat.game_data
        return data[:items][DeveloperMenu::PSDKCompat::DEVICE_ITEM_ID] if data && data[:items]
        return nil
      end
      pokedebug_device_item_record_without_psdk
    rescue StandardError
      nil
    end

    # PSDK must never keep this dynamically registered item in a save. Clean
    # old installations once per loaded bag and only inject it around Bag#main.
    def ensure_pokedebug_device!
      return ensure_pokedebug_device_without_psdk! unless DeveloperMenu::PSDKCompat.active?
      return false unless register_pokedebug_device_item!
      register_pokedebug_device_handlers!
      bag = pokedebug_device_bag
      return false unless bag
      if @psdk_cleaned_device_bag_identity != bag.object_id
        @psdk_cleaned_device_bag_identity = bag.object_id
        remove_pokedebug_device!(bag)
      end
      return true if DeveloperMenu::PSDKCompat.native_debug_only?
      DeveloperMenu::PSDKCompat.install_bag_device_hook!
    rescue StandardError => error
      throttled_log_error("Ensure Temporary PSDK Device", error)
      false
    end
  end
end

if DeveloperMenu::PSDKCompat.active?
  ChooseNumberParams = DeveloperMenu::PSDKCompat::NumberParams unless defined?(ChooseNumberParams)

  module Kernel
    unless private_method_defined?(:_INTL)
      def _INTL(text, *args)
        result = text.to_s.dup
        args.each_with_index { |value, index| result = result.gsub("{#{index + 1}}", value.to_s) }
        result
      end
      module_function :_INTL
    end

    unless private_method_defined?(:pbMessage)
      def pbMessage(message, commands = nil, default = -1)
        DeveloperMenu::PSDKCompat.display_message(message, commands, default)
      end
      module_function :pbMessage
    end

    unless private_method_defined?(:pbConfirmMessage)
      def pbConfirmMessage(message)
        pbMessage(message, ["Yes", "No"], 1).to_i == 0
      end
      module_function :pbConfirmMessage
    end

    unless private_method_defined?(:pbShowCommands)
      def pbShowCommands(_window, commands, default = -1, _index = 0)
        pbMessage("Choose:", commands, default)
      end
      module_function :pbShowCommands
    end

    unless private_method_defined?(:pbMessageChooseNumber)
      def pbMessageChooseNumber(_message, params)
        DeveloperMenu::PSDKCompat.choose_number(params)
      end
      module_function :pbMessageChooseNumber
    end
  end

  if defined?(PFM::Pokemon)
    PFM::Pokemon.class_eval do
      alias_method :species, :db_symbol if method_defined?(:db_symbol) && !method_defined?(:species)
      alias_method :totalhp, :max_hp if method_defined?(:max_hp) && !method_defined?(:totalhp)
      alias_method :attack, :atk if method_defined?(:atk) && !method_defined?(:attack)
      alias_method :defense, :dfe if method_defined?(:dfe) && !method_defined?(:defense)
      alias_method :spatk, :ats if method_defined?(:ats) && !method_defined?(:spatk)
      alias_method :spdef, :dfs if method_defined?(:dfs) && !method_defined?(:spdef)
      alias_method :speed, :spd if method_defined?(:spd) && !method_defined?(:speed)
      alias_method :moves, :skills if method_defined?(:skills) && !method_defined?(:moves)
      alias_method :heal, :fully_heal if method_defined?(:fully_heal) && !method_defined?(:heal)
      alias_method :happiness, :loyalty if method_defined?(:loyalty) && !method_defined?(:happiness)
      alias_method :happiness=, :loyalty= if method_defined?(:loyalty=) && !method_defined?(:happiness=)
    end
  end
end
