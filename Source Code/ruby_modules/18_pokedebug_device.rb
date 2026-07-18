    # JoiPlay-friendly Key Item entry point. This is registered at runtime so
    # no PBS compilation or permanent mutation of the game's data is required.
    POKEDEBUG_DEVICE_ITEM_ID = :POKEDEBUGDEVICE unless const_defined?(:POKEDEBUG_DEVICE_ITEM_ID)
    POKEDEBUG_DEVICE_NAME = "PokeDebug Device" unless const_defined?(:POKEDEBUG_DEVICE_NAME)

    def pokedebug_device_item_id
      POKEDEBUG_DEVICE_ITEM_ID
    end

    def pokedebug_device_item_record
      return nil unless defined?(GameData) && safe_const_get(GameData, :Item)
      item_class = GameData::Item
      begin
        return item_class.try_get(pokedebug_device_item_id) if item_class.respond_to?(:try_get)
      rescue
      end
      begin
        return item_class.get(pokedebug_device_item_id) if item_class.respond_to?(:get)
      rescue
      end
      nil
    rescue => e
      throttled_log_error("PokeDebug Device Item Record", e)
      nil
    end

    # Read-only lookup across both modern GameData and the legacy item stores.
    # This is also useful to diagnostics, which must not mistake a valid
    # $cache/$ItemData registration for a missing item.
    def pokedebug_device_registered_record
      record = pokedebug_device_item_record
      return record if record
      storage_id = pokedebug_device_storage_id
      items = pokedebug_device_legacy_cache_items
      if items
        return items[storage_id] if items.respond_to?(:[]) && items[storage_id]
        return items[pokedebug_device_item_id] if items.respond_to?(:[]) && items[pokedebug_device_item_id]
      end
      items = pokedebug_device_legacy_array_items
      if items && items.respond_to?(:[]) && storage_id.is_a?(Numeric)
        return items[storage_id.to_i]
      end
      nil
    rescue => e
      throttled_log_error("PokeDebug Device Registered Record", e)
      nil
    end

    def next_pokedebug_device_id_number
      maximum = 0
      return 9999 unless defined?(GameData) && safe_const_get(GameData, :Item)
      if GameData::Item.respond_to?(:each)
        GameData::Item.each do |record|
          next unless record && record.respond_to?(:id_number)
          number = record.id_number.to_i
          maximum = number if number > maximum
        end
      end
      maximum + 1
    rescue => e
      throttled_log_error("PokeDebug Device ID Number", e)
      9999
    end

    def register_pokedebug_device_item!
      unless defined?(GameData) && safe_const_get(GameData, :Item)
        return register_pokedebug_device_legacy_item!
      end
      existing_record = pokedebug_device_item_record
      if existing_record
        normalize_pokedebug_device_record!(existing_record)
        register_pokedebug_device_messages!(existing_record)
        return true
      end
      return false unless defined?(GameData) && safe_const_get(GameData, :Item)
      return false unless GameData::Item.respond_to?(:register)

      base_data = {
        :id          => pokedebug_device_item_id,
        :id_number   => next_pokedebug_device_id_number,
        :name        => POKEDEBUG_DEVICE_NAME,
        :name_plural => POKEDEBUG_DEVICE_NAME,
        :pocket      => 8,
        :price       => 0,
        :description => "Use it to open the PokeDebug menu.",
        :field_use   => 2,
        :battle_use  => 0,
        :type        => 6,
        :consumable  => false,
        :flags       => ["KeyItem"]
      }
      variants = []
      variants << base_data
      without_flags = base_data.dup
      without_flags.delete(:flags)
      variants << without_flags
      minimal = without_flags.dup
      minimal.delete(:id_number)
      variants << minimal

      variants.each do |item_data|
        begin
          GameData::Item.register(item_data)
          record = pokedebug_device_item_record
          if record
            normalize_pokedebug_device_record!(record)
            register_pokedebug_device_messages!(record)
            @pokedebug_device_registered = true
            write_developer_log("mobile", "PokeDebug Device registered", record.id.inspect) if respond_to?(:write_developer_log)
            return true
          end
        rescue => e
          throttled_log_error("Register PokeDebug Device variant", e)
        end
      end
      false
    rescue => e
      throttled_log_error("Register PokeDebug Device", e)
      false
    end

    def pokedebug_device_legacy_cache_items
      return nil unless defined?($cache) && $cache && $cache.respond_to?(:items)
      items = $cache.items
      return items if items.is_a?(Hash)
      nil
    rescue
      nil
    end

    def register_pokedebug_device_legacy_cache_item!
      items = pokedebug_device_legacy_cache_items
      return false unless items
      item_id = pokedebug_device_item_id
      if items[item_id]
        normalize_pokedebug_device_legacy_record!(items[item_id])
        @pokedebug_device_legacy_storage_id = item_id
        return true
      end
      item_class = safe_const_get(Object, :ItemData)
      return false unless item_class && item_class.respond_to?(:new)
      data = {
        :name          => POKEDEBUG_DEVICE_NAME,
        :desc          => "Use it to open the PokeDebug menu.",
        :price         => 0,
        :ID            => item_id,
        :keyitem       => true,
        :important     => true,
        :noUse         => false,
        :noUseInBattle => true
      }
      items[item_id] = item_class.new(item_id, data)
      return false unless items[item_id]
      normalize_pokedebug_device_legacy_record!(items[item_id])
      @pokedebug_device_legacy_storage_id = item_id
      write_developer_log("mobile", "PokeDebug Device registered", "legacy cache") if respond_to?(:write_developer_log)
      true
    rescue => e
      throttled_log_error("Register Legacy Cache PokeDebug Device", e)
      false
    end

    def normalize_pokedebug_device_legacy_record!(record)
      return false unless record
      record.instance_variable_set(:@name, POKEDEBUG_DEVICE_NAME)
      record.instance_variable_set(:@desc, "Use it to open the PokeDebug menu.")
      flags = record.instance_variable_get(:@flags)
      if flags.is_a?(Hash)
        flags[:keyitem] = true
        flags[:important] = true
        flags[:noUse] = false
        flags[:noUseInBattle] = true
      end
      true
    rescue => e
      throttled_log_error("Normalize Legacy PokeDebug Device", e)
      false
    end

    def pokedebug_device_legacy_array_items
      if defined?($ItemData) && $ItemData && $ItemData.respond_to?(:[]) && $ItemData.respond_to?(:[]=)
        return $ItemData
      end
      if defined?($cache) && $cache && $cache.respond_to?(:items)
        items = $cache.items
        return items if items && items.respond_to?(:[]) && items.respond_to?(:[]=) && !items.respond_to?(:keys)
      end
      nil
    rescue
      nil
    end

    def pokedebug_legacy_item_index(constant_name, fallback)
      return Object.const_get(constant_name) if Object.const_defined?(constant_name)
      fallback
    rescue
      fallback
    end

    def pokedebug_legacy_numeric_item_id
      pb_items = safe_const_get(Object, :PBItems)
      return nil unless pb_items
      if pb_items.const_defined?(pokedebug_device_item_id)
        existing = pb_items.const_get(pokedebug_device_item_id).to_i
        install_pokedebug_legacy_pbitems_bounds!(pb_items, existing)
        return existing
      end
      maximum = 0
      begin
        maximum = pb_items.maxValue.to_i if pb_items.respond_to?(:maxValue)
        maximum = [maximum, pb_items.getCount.to_i - 1].max if pb_items.respond_to?(:getCount)
      rescue
      end
      items = pokedebug_device_legacy_array_items
      maximum = [maximum, items.length - 1].max if items
      item_number = maximum + 1
      return nil if item_number <= 0 || item_number > 65_535
      pb_items.const_set(pokedebug_device_item_id, item_number)
      install_pokedebug_legacy_pbitems_bounds!(pb_items, item_number)
      item_number
    rescue => e
      throttled_log_error("Legacy PokeDebug Device Numeric ID", e)
      nil
    end

    def install_pokedebug_legacy_pbitems_bounds!(pb_items, item_number)
      return false unless pb_items && item_number.to_i > 0
      eigenclass = class << pb_items; self; end
      unless eigenclass.method_defined?(:_pokedebug_original_maxValue)
        eigenclass.send(:alias_method, :_pokedebug_original_maxValue, :maxValue) if pb_items.respond_to?(:maxValue)
        captured_id = item_number.to_i
        eigenclass.send(:define_method, :maxValue) do
          original = respond_to?(:_pokedebug_original_maxValue) ? _pokedebug_original_maxValue.to_i : 0
          original > captured_id ? original : captured_id
        end
      end
      unless eigenclass.method_defined?(:_pokedebug_original_getCount)
        eigenclass.send(:alias_method, :_pokedebug_original_getCount, :getCount) if pb_items.respond_to?(:getCount)
        captured_count = item_number.to_i + 1
        eigenclass.send(:define_method, :getCount) do
          original = respond_to?(:_pokedebug_original_getCount) ? _pokedebug_original_getCount.to_i : 0
          original > captured_count ? original : captured_count
        end
      end
      true
    rescue => e
      throttled_log_error("Extend Legacy PBItems Bounds", e)
      false
    end

    def register_pokedebug_device_legacy_messages!(item_number)
      return true if @pokedebug_device_messages_registered
      return false unless defined?(MessageTypes)
      message_sets = [
        [:Items, POKEDEBUG_DEVICE_NAME],
        [:ItemPlurals, POKEDEBUG_DEVICE_NAME],
        [:ItemDescriptions, "Use it to open the PokeDebug menu."]
      ]
      registered = true
      message_sets.each do |constant_name, text|
        unless MessageTypes.const_defined?(constant_name)
          registered = false
          next
        end
        type_id = MessageTypes.const_get(constant_name)
        registered = false unless set_pokedebug_legacy_message!(type_id, item_number.to_i, text)
      end
      @pokedebug_device_messages_registered = true if registered
      registered
    rescue => e
      throttled_log_error("Register Legacy PokeDebug Device Messages", e)
      false
    end

    def set_pokedebug_legacy_message!(type_id, item_number, text)
      if MessageTypes.respond_to?(:addMessages)
        messages = Array.new(item_number + 1)
        messages[item_number] = text
        MessageTypes.addMessages(type_id, messages)
      elsif MessageTypes.respond_to?(:setMessages)
        current_count = begin
          MessageTypes.respond_to?(:getCount) ? MessageTypes.getCount(type_id).to_i : 0
        rescue
          0
        end
        length = [current_count, item_number + 1].max
        messages = Array.new(length, "")
        index = 0
        while index < length
          begin
            value = if MessageTypes.respond_to?(:get)
                      MessageTypes.get(type_id, index)
                    elsif defined?(pbGetMessage)
                      pbGetMessage(type_id, index)
                    end
            messages[index] = value.to_s if value
          rescue
          end
          index += 1
        end
        messages[item_number] = text
        MessageTypes.setMessages(type_id, messages)
      else
        return false
      end
      actual = begin
        if MessageTypes.respond_to?(:get)
          MessageTypes.get(type_id, item_number)
        elsif defined?(pbGetMessage)
          pbGetMessage(type_id, item_number)
        end
      rescue
        nil
      end
      actual.to_s == text.to_s
    rescue => e
      throttled_log_error("Set Legacy PokeDebug Message", e)
      false
    end

    def register_pokedebug_device_legacy_numeric_item!
      items = pokedebug_device_legacy_array_items
      item_number = pokedebug_legacy_numeric_item_id
      return false unless item_number

      if items
        record = begin items[item_number] rescue nil end
        if !record || !record.respond_to?(:[]=)
          record = if defined?(SerialRecord) && SerialRecord.respond_to?(:new)
                     SerialRecord.new
                   else
                     Array.new(10, 0)
                   end
        end
        record[pokedebug_legacy_item_index(:ITEMID, 0)] = item_number
        record[pokedebug_legacy_item_index(:ITEMNAME, 1)] = POKEDEBUG_DEVICE_NAME
        record[pokedebug_legacy_item_index(:ITEMPLURAL, 2)] = POKEDEBUG_DEVICE_NAME
        record[pokedebug_legacy_item_index(:ITEMPOCKET, 3)] = 8
        record[pokedebug_legacy_item_index(:ITEMPRICE, 4)] = 0
        record[pokedebug_legacy_item_index(:ITEMDESC, 5)] = "Use it to open the PokeDebug menu."
        record[pokedebug_legacy_item_index(:ITEMUSE, 6)] = 2
        record[pokedebug_legacy_item_index(:ITEMBATTLEUSE, 7)] = 0
        record[pokedebug_legacy_item_index(:ITEMTYPE, 8)] = 6
        record[pokedebug_legacy_item_index(:ITEMMACHINE, 9)] = 0
        items[item_number] = record
      end
      messages_ready = register_pokedebug_device_legacy_messages!(item_number)
      @pokedebug_device_legacy_storage_id = item_number
      write_developer_log("mobile", "PokeDebug Device registered", "legacy numeric #{item_number}; item_array=#{!!items}; messages=#{!!messages_ready}") if respond_to?(:write_developer_log)
      true
    rescue => e
      throttled_log_error("Register Legacy Numeric PokeDebug Device", e)
      false
    end

    def register_pokedebug_device_legacy_item!
      return true if @pokedebug_device_legacy_storage_id
      return true if register_pokedebug_device_legacy_cache_item!
      register_pokedebug_device_legacy_numeric_item!
    rescue => e
      throttled_log_error("Register Legacy PokeDebug Device", e)
      false
    end

    def pokedebug_device_storage_id
      return @pokedebug_device_legacy_storage_id if @pokedebug_device_legacy_storage_id
      pokedebug_device_item_id
    end

    def normalize_pokedebug_device_record!(record)
      return false unless record
      record.instance_variable_set(:@real_name, POKEDEBUG_DEVICE_NAME)
      record.instance_variable_set(:@real_name_plural, POKEDEBUG_DEVICE_NAME)
      record.instance_variable_set(:@real_description, "Use it to open the PokeDebug menu.")
      record.instance_variable_set(:@pocket, 8)
      record.instance_variable_set(:@field_use, 2)
      record.instance_variable_set(:@battle_use, 0)
      record.instance_variable_set(:@type, 6)
      true
    rescue => e
      throttled_log_error("Normalize PokeDebug Device", e)
      false
    end

    def register_pokedebug_device_messages!(record = nil)
      return true if @pokedebug_device_messages_registered
      record ||= pokedebug_device_item_record
      return false unless record && record.respond_to?(:id_number)
      return false unless defined?(MessageTypes) && MessageTypes.respond_to?(:addMessages)
      item_number = record.id_number.to_i
      return false if item_number < 0

      message_sets = []
      message_sets << [:Items, POKEDEBUG_DEVICE_NAME]
      message_sets << [:ItemPlurals, POKEDEBUG_DEVICE_NAME]
      message_sets << [:ItemDescriptions, "Use it to open the PokeDebug menu."]
      message_sets.each do |constant_name, text|
        next unless MessageTypes.const_defined?(constant_name)
        messages = Array.new(item_number + 1)
        messages[item_number] = text
        MessageTypes.addMessages(MessageTypes.const_get(constant_name), messages)
      end
      @pokedebug_device_messages_registered = true
      true
    rescue => e
      throttled_log_error("Register PokeDebug Device Messages", e)
      false
    end

    def pokedebug_device_handler_container(name)
      return nil unless defined?(ItemHandlers)
      safe_const_get(ItemHandlers, name)
    rescue
      nil
    end

    def register_pokedebug_device_handlers!
      from_bag = pokedebug_device_handler_container(:UseFromBag)
      in_field = pokedebug_device_handler_container(:UseInField)
      legacy_handler_api = defined?(ItemHandlers) &&
        (ItemHandlers.respond_to?(:addUseFromBag) || ItemHandlers.respond_to?(:addUseInField))
      return false unless from_bag || in_field || legacy_handler_api
      handler_item = pokedebug_device_storage_id

      @pokedebug_device_in_field_handler ||= proc do |*args|
        ::DeveloperMenu.open_pokedebug_device_menu_now!
        1
      end
      @pokedebug_device_from_bag_handler ||= proc do |*args|
        ::DeveloperMenu.write_developer_log("mobile", "PokeDebug Device selected", "closing bag before field use") if ::DeveloperMenu.respond_to?(:write_developer_log)
        2
      end
      @pokedebug_device_from_bag_fallback_handler ||= proc do |*args|
        ::DeveloperMenu.queue_pokedebug_device_menu!("bag fallback")
        2
      end

      changed = false
      if in_field && in_field.respond_to?(:add)
        current = in_field.respond_to?(:[]) ? in_field[handler_item] : nil
        unless current.equal?(@pokedebug_device_in_field_handler)
          in_field.add(handler_item, @pokedebug_device_in_field_handler)
          changed = true
        end
      end
      if from_bag && from_bag.respond_to?(:add)
        desired = in_field && in_field.respond_to?(:add) ? @pokedebug_device_from_bag_handler : @pokedebug_device_from_bag_fallback_handler
        current = from_bag.respond_to?(:[]) ? from_bag[handler_item] : nil
        unless current.equal?(desired)
          from_bag.add(handler_item, desired)
          changed = true
        end
      end
      if legacy_handler_api
        if !in_field && ItemHandlers.respond_to?(:addUseInField)
          begin
            ItemHandlers.addUseInField(handler_item, @pokedebug_device_in_field_handler)
          rescue ArgumentError
            ItemHandlers.addUseInField(handler_item, &@pokedebug_device_in_field_handler)
          end
          changed = true
        end
        if !from_bag && ItemHandlers.respond_to?(:addUseFromBag)
          desired = ItemHandlers.respond_to?(:addUseInField) ? @pokedebug_device_from_bag_handler : @pokedebug_device_from_bag_fallback_handler
          begin
            ItemHandlers.addUseFromBag(handler_item, desired)
          rescue ArgumentError
            ItemHandlers.addUseFromBag(handler_item, &desired)
          end
          changed = true
        end
      end
      @pokedebug_device_handlers_registered = true
      write_developer_log("mobile", "PokeDebug Device handlers installed", "item=#{handler_item.inspect} from_bag=#{!!from_bag} in_field=#{!!in_field} legacy_api=#{!!legacy_handler_api}") if changed && respond_to?(:write_developer_log)
      true
    rescue => e
      throttled_log_error("Register PokeDebug Device Handlers", e)
      false
    end

    def pokedebug_device_bag
      return $bag if defined?($bag) && $bag
      return $PokemonBag if defined?($PokemonBag) && $PokemonBag
      nil
    rescue
      nil
    end

    def pokedebug_device_in_bag?(bag = nil)
      bag ||= pokedebug_device_bag
      return false unless bag
      item = pokedebug_device_storage_id
      if bag.respond_to?(:contents) && bag.respond_to?(:pockets)
        contents = bag.contents
        pockets = bag.pockets
        quantity = contents.respond_to?(:[]) ? contents[item].to_i : 0
        pocket = pokedebug_device_legacy_pocket(item)
        pocket_items = pockets.respond_to?(:[]) ? pockets[pocket] : nil
        return quantity > 0 && pocket_items.respond_to?(:include?) && pocket_items.include?(item)
      end
      return true if bag.respond_to?(:pbQuantity) && bag.pbQuantity(item).to_i > 0
      return true if bag.respond_to?(:quantity) && bag.quantity(item).to_i > 0
      return true if bag.respond_to?(:has?) && bag.has?(item)
      return true if bag.respond_to?(:hasItem?) && bag.hasItem?(item)
      return true if bag.respond_to?(:pbHasItem?) && bag.pbHasItem?(item)
      return true if bag.respond_to?(:contains?) && bag.contains?(item)
      false
    rescue => e
      throttled_log_error("Check PokeDebug Device Bag", e)
      false
    end

    def pokedebug_device_legacy_pocket(item = nil)
      item ||= pokedebug_device_storage_id
      return pbGetPocket(item).to_i if respond_to?(:pbGetPocket, true)
      return Kernel.pbGetPocket(item).to_i if Kernel.respond_to?(:pbGetPocket, true)
      8
    rescue
      8
    end

    def repair_pokedebug_device_legacy_bag!(bag, item = nil)
      return false unless bag && bag.respond_to?(:contents) && bag.respond_to?(:pockets)
      item ||= pokedebug_device_storage_id
      contents = bag.contents
      pockets = bag.pockets
      return false unless contents.respond_to?(:[]) && contents.respond_to?(:[]=)
      return false unless pockets.respond_to?(:[]) && pockets.respond_to?(:<<)
      pocket = pokedebug_device_legacy_pocket(item)
      pockets << [] while pockets.length <= pocket
      pockets[pocket] = [] if pockets[pocket].nil? && pockets.respond_to?(:[]=)
      target = pockets[pocket]
      return false unless target && target.respond_to?(:include?) && target.respond_to?(:<<)

      contents[item] = 1 if contents[item].to_i < 1
      pockets.each_with_index do |entries, index|
        next if index == pocket || !entries.respond_to?(:delete)
        entries.delete(item)
      end
      target << item unless target.include?(item)
      success = contents[item].to_i > 0 && target.include?(item)
      if success && respond_to?(:write_developer_log)
        write_developer_log("mobile", "PokeDebug Device bag repaired", "bag=#{bag.class} item=#{item.inspect} pocket=#{pocket}")
      end
      success
    rescue => e
      throttled_log_error("Repair Legacy PokeDebug Device Bag", e)
      false
    end

    def give_pokedebug_device!(bag = nil)
      bag ||= pokedebug_device_bag
      return false unless bag
      return true if pokedebug_device_in_bag?(bag)
      item = pokedebug_device_storage_id
      result = nil
      if bag.respond_to?(:add)
        result = bag.add(item, 1)
      elsif bag.respond_to?(:pbStoreItem)
        begin
          result = bag.pbStoreItem(item, 1)
        rescue ArgumentError
          result = bag.pbStoreItem(item)
        end
      elsif bag.respond_to?(:storeItem)
        result = bag.storeItem(item, 1)
      end
      success = pokedebug_device_in_bag?(bag)
      if !success && bag.respond_to?(:contents) && bag.respond_to?(:pockets)
        success = repair_pokedebug_device_legacy_bag!(bag, item)
      end
      write_developer_log("mobile", "PokeDebug Device delivered", bag.class.to_s) if success && respond_to?(:write_developer_log)
      if !success && respond_to?(:write_developer_log)
        quantity = bag.respond_to?(:pbQuantity) ? bag.pbQuantity(item) : nil
        write_developer_log("mobile", "PokeDebug Device delivery failed", "bag=#{bag.class} item=#{item.inspect} result=#{result.inspect} quantity=#{quantity.inspect}")
      end
      success
    rescue => e
      throttled_log_error("Give PokeDebug Device", e)
      false
    end

    def ensure_pokedebug_device!
      return false unless register_pokedebug_device_item!
      register_pokedebug_device_handlers!
      bag = pokedebug_device_bag
      return false unless bag

      bag_identity = bag.object_id
      if @pokedebug_device_bag_identity != bag_identity
        @pokedebug_device_bag_identity = bag_identity
        @pokedebug_device_delivery_frame = -9999
      end
      return true if pokedebug_device_in_bag?(bag)

      frame = defined?(Graphics) && Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0
      return false if frame - @pokedebug_device_delivery_frame.to_i < 120
      @pokedebug_device_delivery_frame = frame
      give_pokedebug_device!(bag)
    rescue => e
      throttled_log_error("Ensure PokeDebug Device", e)
      false
    end

    def queue_pokedebug_device_menu!(source = "item")
      @pokedebug_device_menu_pending = true
      @pokedebug_device_menu_wait_frames = 0
      write_developer_log("mobile", "PokeDebug Device menu queued", "source=#{source} scene=#{current_scene_name} menu_open=#{!!@menu_open}") if respond_to?(:write_developer_log)
      true
    rescue => e
      throttled_log_error("Queue PokeDebug Device Menu", e)
      false
    end

    def open_pokedebug_device_menu_now!
      write_developer_log("mobile", "PokeDebug Device field handler", "scene=#{current_scene_name} menu_open=#{!!@menu_open} choice_active=#{menu_choice_active?}") if respond_to?(:write_developer_log)
      if @menu_open
        recover_menu_state!("PokeDebug Device Orphaned Menu")
      end
      @pokedebug_device_menu_pending = false
      @pokedebug_device_menu_wait_frames = 0
      open_menu_external
    rescue => e
      throttled_log_error("Direct PokeDebug Device Menu", e)
      queue_pokedebug_device_menu!("direct open rescue")
      false
    end

    def pokedebug_map_scene_ready?
      return false unless defined?($scene) && $scene
      return true if defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      scene_name = $scene.class.to_s.downcase
      scene_name == "scene_map" || scene_name[-11, 11] == "::scene_map"
    rescue
      false
    end

    def process_pokedebug_device_menu!
      return false unless @pokedebug_device_menu_pending
      if @menu_open
        return false if menu_choice_active?
        recover_menu_state!("Queued PokeDebug Device Orphaned Menu")
      end
      return false unless pokedebug_map_scene_ready?
      return false if plugin_message_window_busy?
      @pokedebug_device_menu_wait_frames = @pokedebug_device_menu_wait_frames.to_i + 1
      return false if @pokedebug_device_menu_wait_frames < 2
      @pokedebug_device_menu_pending = false
      @pokedebug_device_menu_wait_frames = 0
      write_developer_log("mobile", "PokeDebug Device queued menu opening", "scene=#{current_scene_name}") if respond_to?(:write_developer_log)
      open_menu_external
    rescue => e
      @pokedebug_device_menu_pending = false
      throttled_log_error("Open PokeDebug Device Menu", e)
      false
    end
