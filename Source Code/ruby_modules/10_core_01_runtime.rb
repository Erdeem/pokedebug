  class << self
    attr_accessor :walk_through_walls
    attr_accessor :no_wild_battles
    attr_accessor :skip_trainer_battles
    attr_accessor :inf_mega

    def initialize_variables
      @walk_through_walls = false
      @no_wild_battles = false
      @skip_trainer_battles = false
      @no_battles = false
      @inf_mega = false
      @processing_hotkey = false
      @menu_open = false
      @menu_session_serial = 0
      @menu_choice_active_depth = 0
      @menu_last_activity_frame = nil
      @menu_input_armed = false
      @menu_input_disarmed_frame = -9999
      @menu_hotkey_latched = false
      @auto_open_menu_once_pending = false
      @auto_open_menu_once_done = false
      @auto_open_menu_frame_counter = 0
      @pokedebug_device_registered = false
      @pokedebug_device_handlers_registered = false
      @pokedebug_device_messages_registered = false
      @pokedebug_device_legacy_storage_id = nil
      @pokedebug_device_bag_identity = nil
      @pokedebug_device_delivery_frame = -9999
      @pokedebug_device_menu_pending = false
      @pokedebug_device_menu_wait_frames = 0
      @mobile_combo_hold_frames = 0
      @mobile_combo_hold_counters = {}
      @last_mobile_combo_label = nil
      @last_battle_heal_frame = -9999
      @battle_heal_input_latched = false
      @quick_actions = [:heal_party, :engine_report, :native_debug, :none]
      @hotkey_config = nil
      @battle_access_config = nil
      load_hotkey_config! if respond_to?(:load_hotkey_config!)
      load_battle_access_config! if respond_to?(:load_battle_access_config!)
      normalize_battle_skip_flags!
    end

    def no_battles
      no_wild_battles_active? && no_trainer_battles_active?
    rescue
      false
    end

    def no_battles=(value)
      enabled = !!value
      @no_wild_battles = enabled
      @skip_trainer_battles = enabled
      @no_battles = enabled
      ensure_runtime_patches! if respond_to?(:ensure_runtime_patches!)
      enabled
    rescue
      false
    end

    def no_wild_battles=(value)
      @no_wild_battles = !!value
      @no_battles = !!(@no_wild_battles && @skip_trainer_battles)
      ensure_runtime_patches! if respond_to?(:ensure_runtime_patches!)
      @no_wild_battles
    rescue
      false
    end

    def skip_trainer_battles=(value)
      @skip_trainer_battles = !!value
      @no_battles = !!(@no_wild_battles && @skip_trainer_battles)
      ensure_runtime_patches! if respond_to?(:ensure_runtime_patches!)
      @skip_trainer_battles
    rescue
      false
    end

    def normalize_battle_skip_flags!
      legacy = defined?(@no_battles) ? !!@no_battles : false
      @no_wild_battles = legacy if @no_wild_battles.nil?
      @skip_trainer_battles = legacy if @skip_trainer_battles.nil?
      @no_wild_battles = false if @no_wild_battles.nil?
      @skip_trainer_battles = false if @skip_trainer_battles.nil?
      @no_battles = !!(@no_wild_battles && @skip_trainer_battles)
      true
    rescue
      false
    end

    def no_wild_battles_active?
      normalize_battle_skip_flags!
      !!@no_wild_battles
    rescue
      false
    end

    def no_trainer_battles_active?
      normalize_battle_skip_flags!
      !!@skip_trainer_battles
    rescue
      false
    end

    def t(hash_or_string, *args)
      language_key = LANG_KEYS[LANG] || LANG
      str = hash_or_string.is_a?(Hash) ? (hash_or_string[language_key] || hash_or_string.values.first || "") : hash_or_string.to_s
      args.each_with_index { |a, i| str = str.gsub("{#{i+1}}", a.to_s) }
      str
    end

    def developer_menu_version
      VERSION
    rescue
      "unknown"
    end

    def developer_log_paths
      paths = []
      begin
        paths << File.join(Dir.pwd, LOG_FILE_NAME)
      rescue
      end
      begin
        paths << LOG_FILE_NAME
      rescue
      end
      paths.compact.uniq
    rescue
      [LOG_FILE_NAME]
    end

    def developer_state_paths
      paths = []
      begin
        paths << File.join(Dir.pwd, STATE_FILE_NAME)
      rescue
      end
      begin
        paths << STATE_FILE_NAME
      rescue
      end
      paths.compact.uniq
    rescue
      [STATE_FILE_NAME]
    end

    def developer_log_path
      developer_log_paths.first || LOG_FILE_NAME
    rescue
      LOG_FILE_NAME
    end

    def developer_state_path
      developer_state_paths.first || STATE_FILE_NAME
    rescue
      STATE_FILE_NAME
    end

    def developer_timestamp_text
      Time.now.strftime("%Y-%m-%d %H:%M:%S")
    rescue
      Time.now.to_s
    end

    def developer_process_id
      Process.pid.to_s
    rescue
      "unknown"
    end

    def normalize_log_context(context_name)
      text = context_name.to_s.strip
      return "Unknown" if text == ""
      text
    rescue
      "Unknown"
    end

    def normalize_log_message(message)
      return "" if message.nil?
      text = message.to_s
      text = text.gsub(/\r\n?/, "\n")
      text
    rescue
      ""
    end

    def write_developer_log_line(text)
      developer_log_paths.each do |path|
        begin
          File.open(path, "a") do |f|
            f.puts(text)
          end
          return true
        rescue
        end
      end
      false
    rescue
      false
    end

    def log_category_for_context(context_name)
      text = context_name.to_s.downcase
      return "battle" if text.include?("battle")
      return "engine" if text.include?("engine") || text.include?("warp") || text.include?("map")
      return "items" if text.include?("item") || text.include?("bag")
      return "party" if text.include?("party") || text.include?("pokemon")
      return "input" if text.include?("hotkey") || text.include?("input")
      return "reports" if text.include?("report") || text.include?("diagnostic")
      "core"
    rescue
      "core"
    end

    def write_developer_log(category, context_name, message, backtrace = nil)
      category_text = category.to_s.strip
      category_text = "core" if category_text == ""
      context_text = normalize_log_context(context_name)
      message_text = normalize_log_message(message)
      prefix = "[#{developer_timestamp_text}] [#{category_text}] [PokeDebug #{developer_menu_version}] [PID #{developer_process_id}] #{context_text}: "
      write_developer_log_line(prefix + message_text)
      if backtrace && !backtrace.empty?
        backtrace.each do |line|
          write_developer_log_line("  #{line}")
        end
      end
      true
    rescue
      false
    end

    def log_state_snapshot(context_name = "State Snapshot")
      snapshot = []
      snapshot << "menu_open=#{@menu_open.inspect}"
      snapshot << "processing_hotkey=#{@processing_hotkey.inspect}"
      snapshot << "mobile_combo_hold_frames=#{@mobile_combo_hold_frames.inspect}"
      snapshot << "pending_map_refresh=#{@pending_map_refresh.inspect}"
      snapshot << "walk_through_walls=#{@walk_through_walls.inspect}"
      snapshot << "no_wild_battles=#{@no_wild_battles.inspect}"
      snapshot << "skip_trainer_battles=#{@skip_trainer_battles.inspect}"
      snapshot << "no_battles=#{no_battles.inspect}"
      snapshot << "inf_mega=#{@inf_mega.inspect}"
      snapshot << "quick_actions=#{Array(@quick_actions).inspect}"
      write_developer_log("reports", context_name, snapshot.join(" | "))
    rescue
      false
    end

    def log_error(context_name, error)
      category = log_category_for_context(context_name)
      message = error && error.respond_to?(:message) ? error.message : error.to_s
      backtrace = error && error.respond_to?(:backtrace) ? error.backtrace : nil
      if message && message.to_s.length > 2000
        message = message.to_s[0, 2000] + "... [error message truncated]"
      end
      backtrace = backtrace[0, 40] if backtrace && backtrace.length > 40
      write_developer_log(category, context_name, message, backtrace)
    end

    def throttled_log_error(context_name, error, cooldown_seconds = 3)
      @throttled_error_log_times ||= {}
      key = context_name.to_s
      now = Time.now.to_f
      last_time = @throttled_error_log_times[key]
      return false if last_time && (now - last_time) < cooldown_seconds.to_f
      @throttled_error_log_times[key] = now
      log_error(context_name, error)
      true
    rescue
      false
    end

    def log_item_debug(message)
      write_developer_log("items", "Item Debug", message.to_s)
    rescue
    end

    def try_call(context_name = nil)
      yield
    rescue => e
      log_error(context_name || "Operation", e)
      nil
    end

    def try_variants(context_name, variants)
      last_error = nil
      variants.each do |variant|
        begin
          return variant.call
        rescue ArgumentError, TypeError, NameError => e
          last_error = e
          next
        rescue Exception => e
          log_error("#{context_name} (Fatal Variant Error)", e)
          return nil
        end
      end
      log_error(context_name, last_error) if last_error
      nil
    rescue => e
      log_error(context_name, e)
      nil
    end

    def safe_execute(context_name = "System")
      yield
    rescue => e
      log_error(context_name, e)
      log_state_snapshot("#{context_name} State")
      Kernel.pbMessage(_INTL("API Failure: {1} (Check log)", context_name))
    end

    def reset_game_data_cache!
      @map_infos = nil
      @system_data = nil
      reset_engine_profile! if respond_to?(:reset_engine_profile!)
    end

    def mark_menu_activity!
      @menu_last_activity_frame = begin
        Graphics.frame_count.to_i
      rescue
        0
      end
      true
    end

    def begin_menu_choice_activity!
      @menu_choice_active_depth = @menu_choice_active_depth.to_i + 1
      mark_menu_activity!
    end

    def end_menu_choice_activity!
      @menu_choice_active_depth = [@menu_choice_active_depth.to_i - 1, 0].max
      mark_menu_activity!
    end

    def menu_choice_active?
      @menu_choice_active_depth.to_i > 0
    rescue
      false
    end

    def menu_inactive_frames
      last_frame = @menu_last_activity_frame
      return 999999 if last_frame.nil?
      current_frame = begin
        Graphics.frame_count.to_i
      rescue
        last_frame.to_i
      end
      [current_frame - last_frame.to_i, 0].max
    rescue
      999999
    end

    def recover_menu_state!(context_name = nil, expected_session = nil)
      if !expected_session.nil? && expected_session.to_i != @menu_session_serial.to_i
        return false
      end
      @menu_session_serial = @menu_session_serial.to_i + 1
      @menu_open = false
      @menu_choice_active_depth = 0
      @menu_last_activity_frame = nil
      @processing_hotkey = false
      @mobile_combo_hold_frames = 0
      @menu_input_armed = false
      @menu_input_disarmed_frame = begin
        Graphics.frame_count
      rescue
        0
      end
      @pending_map_refresh = true
      begin
        reset_game_data_cache!
      rescue
      end
      true
    rescue => e
      log_error(context_name || "Recover Menu State", e)
      false
    end

    def safe_text_message(text, context_name = "Message")
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:ui).show_message(_INTL("{1}", text.to_s))
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      Kernel.pbMessage(_INTL("{1}", text.to_s))
    rescue => e
      log_error(context_name, e)
      recover_menu_state!(context_name)
      nil
    end

    def safe_menu_choice(prompt, commands, default = -1, context_name = "Menu Choice")
      cmds = Array(commands).compact.map { |entry| entry.to_s.strip }.reject { |entry| entry == "" }
      return -1 if cmds.empty?
      tracking_activity = !!@menu_open
      begin_menu_choice_activity! if tracking_activity
      begin
        if respond_to?(:engine_adapter_for)
          adapter_result = engine_adapter_for(:ui).show_choice(_INTL(prompt.to_s), cmds, default)
          return adapter_result[1] if adapter_result && adapter_result[0]
        end
        Kernel.pbMessage(_INTL(prompt.to_s), cmds, default)
      ensure
        end_menu_choice_activity! if tracking_activity
      end
    rescue => e
      log_error(context_name, e)
      recover_menu_state!(context_name)
      -1
    end

    def safe_confirm_message(prompt, context_name = "Confirm Message")
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:ui).confirm(_INTL(prompt.to_s))
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      Kernel.pbConfirmMessage(_INTL(prompt.to_s))
    rescue => e
      log_error(context_name, e)
      recover_menu_state!(context_name)
      false
    end

    def safe_choose_number(prompt, params, context_name = "Choose Number")
      if respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:ui).choose_number(_INTL(prompt.to_s), params)
        return adapter_result[1] if adapter_result && adapter_result[0]
      end
      Kernel.pbMessageChooseNumber(_INTL(prompt.to_s), params)
    rescue => e
      log_error(context_name, e)
      recover_menu_state!(context_name)
      nil
    end

    def safe_delete_file(path, context_name = "Delete File")
      return false if path.nil? || path.to_s.strip == ""
      return false unless File.exist?(path)
      File.delete(path)
      true
    rescue => e
      log_error(context_name, e)
      false
    end

    def clear_runtime_diagnostic_state!(context_name = "Clear Runtime Diagnostic State")
      safe_delete_file(developer_state_path, context_name)
    rescue => e
      log_error(context_name, e)
      false
    end

    def normalize_menu_entries(menu_array)
      Array(menu_array).compact.map do |item|
        next nil unless item.is_a?(Hash)
        label = item[:label].to_s.strip
        action = item[:action]
        next nil if label == ""
        next nil unless action.respond_to?(:call)
        normalized = { :label => label, :action => action }
        if item.key?(:battle_key)
          normalized[:battle_key] = item[:battle_key]
        elsif item.key?(:key)
          normalized[:battle_key] = item[:key]
        end
        normalized
      end.compact
    rescue => e
      log_error("Normalize Menu Entries", e)
      []
    end

    def trigger_hotkey?(symbol_name, constant_name)
      return false unless defined?(Input)
      begin
        return true if Input.trigger?(symbol_name)
      rescue
      end
      begin
        return true if Input.const_defined?(constant_name) && Input.trigger?(Input.const_get(constant_name))
      rescue
      end
      native_key_triggered?(constant_name)
    rescue => e
      log_error("Hotkey #{constant_name}", e)
      false
    end

    def reset_custom_input_states!
      @custom_input_states = {}
      @custom_keyboard_states = {}
      @list_search_physical_pressed = false
      return unless defined?(Input)
      [:ACTION, :SHIFT, :A, :S].each do |sym|
        begin
          @custom_input_states[sym] = Input.press?(sym)
        rescue
        end
      end
      [:A, :SHIFT, :LSHIFT, :RSHIFT, :ACTION, :S].each do |sym|
        begin
          if Input.const_defined?(sym)
            val = Input.const_get(sym)
            @custom_input_states[val] = Input.press?(val)
          end
        rescue
        end
      end
      if defined?(Keyboard)
        [:SHIFT, :LSHIFT, :RSHIFT, :ACTION, :A, :S].each do |sym|
          begin
            @custom_keyboard_states[sym] = Keyboard.press?(sym)
          rescue
          end
          begin
            if Keyboard.const_defined?(sym)
              val = Keyboard.const_get(sym)
              @custom_keyboard_states[val] = Keyboard.press?(val)
            end
          rescue
          end
        end
      end
    end

    def wait_for_key_release
      return unless defined?(Input)
      loop do
        Graphics.update if defined?(Graphics)
        Input.update
        pressed = false
        [:USE, :BACK, :ACTION, :SHIFT, :F8, :F7, :TAB].each do |sym|
          begin
            if Input.press?(sym)
              pressed = true
              break
            end
          rescue
          end
        end
        [:C, :B, :A, :SHIFT].each do |key_sym|
          begin
            if Input.const_defined?(key_sym)
              val = Input.const_get(key_sym)
              if Input.press?(val)
                pressed = true
                break
              end
            end
          rescue
          end
        end
        # Check physical F8 (0x77), F7 (0x76), TAB (0x09)
        [0x77, 0x76, 0x09].each do |vk|
          proc_obj = native_get_async_key_state_proc
          if proc_obj
            begin
              state = proc_obj.call(vk)
              if (state & 0x8000) != 0
                pressed = true
                break
              end
            rescue
            end
          end
        end
        break unless pressed
      end
    end

    def custom_input_trigger?(key)
      return false unless defined?(Input)
      @custom_input_states ||= {}
      pressed = false
      begin
        pressed = Input.press?(key)
      rescue
        return false
      end
      previous = @custom_input_states[key] == true
      @custom_input_states[key] = pressed
      pressed && !previous
    end

    def custom_keyboard_trigger?(key)
      return false unless defined?(Keyboard)
      @custom_keyboard_states ||= {}
      pressed = false
      begin
        pressed = Keyboard.press?(key)
      rescue
        return false
      end
      previous = @custom_keyboard_states[key] == true
      @custom_keyboard_states[key] = pressed
      pressed && !previous
    end

    def list_search_triggered?
      return false unless defined?(Input)

      # Read the held state with a list-local edge latch. Rejuvenation's
      # Input.update can consume its Shift trigger before this menu sees it,
      # while press? and the physical Windows state remain available.
      physical_pressed = native_key_pressed?("SHIFT")
      if !physical_pressed && Input.const_defined?(:D) && Input.respond_to?(:press?)
        begin
          physical_pressed = Input.press?(Input.const_get(:D))
        rescue
        end
      end
      previous_physical = @list_search_physical_pressed == true
      @list_search_physical_pressed = physical_pressed == true
      return true if physical_pressed && !previous_physical

      # Rejuvenation exposes classic RGSS actions and its own editor uses X
      # for list search. Depending on the configured controls, Shift/Run can
      # arrive as A or D instead. Accept all three without involving arrows.
      classic_search_actions = Input.respond_to?(:shiftKeyTriggered?)
      classic_search_actions ||= respond_to?(:pokemon_z_engine?) && pokemon_z_engine?
      if classic_search_actions && Input.respond_to?(:trigger?)
        [:A, :D, :X].each do |name|
          begin
            return true if Input.const_defined?(name) && Input.trigger?(Input.const_get(name))
          rescue
          end
        end
      end

      # Some customized engines remap the physical Shift key (Rejuvenation
      # uses Input::D on desktop and H on JoiPlay). Let the engine resolve its
      # own mapping before trying the generic keyboard fallbacks.
      if Input.respond_to?(:shiftKeyTriggered?)
        begin
          return true if Input.shiftKeyTriggered?
        rescue
        end
      end

      # Search is deliberately bound only to Shift. Do not use Essentials
      # action constants here: their numeric values vary between engines and
      # can collide with directional buttons (notably DOWN).
      if Input.respond_to?(:triggerex?)
        [:LSHIFT, :RSHIFT, :SHIFT].each do |key|
          begin
            return true if Input.triggerex?(key)
          rescue
          end
        end
      end
      return true if native_key_triggered?("SHIFT")

      false
    rescue => e
      log_error("List Search Trigger", e)
      false
    end

    def search_lister_in_place(lister, list)
      return false unless lister && list
      class_name = lister.class.to_s
      if class_name.include?("MapLister")
        prompt = "Search maps (name or ID):"
        context = "Search Maps"
        finder = :map_lister_search_index
      elsif class_name.include?("SpeciesLister")
        prompt = "Search Pokemon (name or Dex number):"
        context = "Search Pokemon"
        finder = :species_lister_search_index
      elsif class_name.include?("ItemLister")
        prompt = "Search items (name or ID):"
        context = "Search Items"
        finder = :item_lister_search_index
      else
        return false
      end
      term = safe_free_text(prompt, "", false, 256, context)
      return true if term.nil? || term.to_s.strip == ""
      found_index = send(finder, lister, term)
      if found_index
        list.index = found_index if list.respond_to?(:index=)
        lister.refresh(found_index) if lister.respond_to?(:refresh)
      else
        safe_text_message("No results matched that search.", "#{context} Empty")
      end
      true
    rescue => e
      log_error("Search Lister In Place", e)
      false
    end



    def list_search_button?(button)
      return false unless defined?(Input)
      return true if Input.const_defined?(:SHIFT) && button == Input.const_get(:SHIFT)
      return true if !Input.const_defined?(:SHIFT) && Input.const_defined?(:ACTION) && button == Input::ACTION
      false
    rescue => e
      log_error("List Search Button", e)
      false
    end

    # New Essentials versions call these ACTION/USE/BACK. Older and custom
    # engines (such as Rejuvenation 14) expose the same actions as A/C/B.
    def list_input_button(*names)
      return nil unless defined?(Input)
      names.each do |name|
        return Input.const_get(name) if Input.const_defined?(name)
      end
      nil
    rescue => e
      log_error("List Input Button", e)
      nil
    end

    def list_input_triggered?(*names)
      button = list_input_button(*names)
      return false if button.nil? || !Input.respond_to?(:trigger?)
      Input.trigger?(button)
    rescue => e
      log_error("List Input Trigger", e)
      false
    end

    def list_confirm_button
      return list_input_button(:C, :USE) if Input.respond_to?(:shiftKeyTriggered?)
      list_input_button(:USE, :C)
    end

    def list_action_button
      return list_input_button(:A, :ACTION) if Input.respond_to?(:shiftKeyTriggered?)
      list_input_button(:ACTION, :A)
    end

    def list_confirm_button?(button)
      expected = list_confirm_button
      !expected.nil? && button == expected
    end

    def list_confirm_triggered?
      return list_input_triggered?(:C, :USE) if Input.respond_to?(:shiftKeyTriggered?)
      list_input_triggered?(:USE, :C)
    end

    def list_cancel_triggered?
      return list_input_triggered?(:B, :BACK) if Input.respond_to?(:shiftKeyTriggered?)
      list_input_triggered?(:BACK, :B)
    end

    def dev_pbListScreenBlock(title, lister)
      species_preview = nil
      viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      viewport.z = 99999
      list = pbListWindow([], Graphics.width / 2)
      list.viewport = viewport if list.respond_to?(:viewport=)
      list.z = 2 if list.respond_to?(:z=)
      title_window = Window_UnformattedTextPokemon.newWithSize(
        title, Graphics.width / 2, 0, Graphics.width / 2, 64, viewport
      )
      title_window.z = 2 if title_window.respond_to?(:z=)
      
      help_window = nil
      begin
        help_text = _INTL("USE: Select   BACK: Cancel   SHIFT: Search")
        help_window = Window_UnformattedTextPokemon.newWithSize(
          help_text, 0, Graphics.height - 64, Graphics.width / 2, 64, viewport
        )
        help_window.z = 2 if help_window.respond_to?(:z=)
      rescue
      end

      lister.setViewport(viewport) if lister.respond_to?(:setViewport)
      selectedmap = -1
      commands = lister.commands
      selindex = lister.startIndex
      if commands.length == 0
        value = lister.value(-1)
        return value
      end
      list.commands = commands if list.respond_to?(:commands=)
      list.index = selindex if list.respond_to?(:index=)
      if lister.class.to_s.include?("SpeciesLister") && respond_to?(:build_species_preview_sprite)
        species_preview = build_species_preview_sprite(viewport)
        update_species_preview_sprite(species_preview, lister.value(selindex)) if respond_to?(:update_species_preview_sprite)
        position_species_preview_sprite(species_preview) if respond_to?(:position_species_preview_sprite)
      end

      # Pokemon Z runs on RGSS1 and can consume Shift before this custom list
      # loop observes it. Open one native text search on entry so Add Pokemon
      # is always searchable; an empty answer leaves the complete list intact.
      if lister.class.to_s.include?("SpeciesLister") && respond_to?(:pokemon_z_engine?) && pokemon_z_engine?
        search_lister_in_place(lister, list)
        selectedmap = list.index rescue selindex
        list.commands = lister.commands if list.respond_to?(:commands=)
        list.index = list.commands.length - 1 if list.index >= list.commands.length
        lister.refresh(list.index) if lister.respond_to?(:refresh)
        if species_preview && respond_to?(:update_species_preview_sprite)
          update_species_preview_sprite(species_preview, lister.value(list.index))
          position_species_preview_sprite(species_preview) if respond_to?(:position_species_preview_sprite)
        end
        wait_for_key_release
        Input.update if defined?(Input)
      end
      
      loop do
        Graphics.update
        Input.update
        list.update if list.respond_to?(:update)
        species_preview.update if species_preview && species_preview.respond_to?(:update)
        current_index = list.index rescue -1
        if current_index != selectedmap
          lister.refresh(current_index) if lister.respond_to?(:refresh)
          if species_preview && respond_to?(:update_species_preview_sprite)
            update_species_preview_sprite(species_preview, lister.value(current_index))
            position_species_preview_sprite(species_preview) if respond_to?(:position_species_preview_sprite)
          end
          selectedmap = current_index
        end
        
        if list_search_triggered?
          search_lister_in_place(lister, list)
          selectedmap = list.index rescue selectedmap
          list.commands = lister.commands if list.respond_to?(:commands=)
          list.index = list.commands.length - 1 if list.index >= list.commands.length
          lister.refresh(list.index) if lister.respond_to?(:refresh)
          if species_preview && respond_to?(:update_species_preview_sprite)
            update_species_preview_sprite(species_preview, lister.value(list.index))
            position_species_preview_sprite(species_preview) if respond_to?(:position_species_preview_sprite)
          end
        elsif list_input_triggered?(:ACTION, :A)
          yield(list_action_button, lister.value(selectedmap))
          list.commands = lister.commands if list.respond_to?(:commands=)
          list.index = list.commands.length - 1 if list.index >= list.commands.length
          lister.refresh(list.index) if lister.respond_to?(:refresh)
        elsif list_cancel_triggered?
          break
        elsif list_confirm_triggered?
          yield(list_confirm_button, lister.value(selectedmap))
          list.commands = lister.commands if list.respond_to?(:commands=)
          list.index = list.commands.length - 1 if list.index >= list.commands.length
          lister.refresh(list.index) if lister.respond_to?(:refresh)
        end
      end
    rescue => e
      log_error("Dev List Screen Block", e)
    ensure
      begin species_preview.dispose if species_preview && (!species_preview.respond_to?(:disposed?) || !species_preview.disposed?); rescue; end
      begin lister.dispose if lister && (!lister.respond_to?(:disposed?) || !lister.disposed?); rescue; end
      begin title_window.dispose if title_window && (!title_window.respond_to?(:disposed?) || !title_window.disposed?); rescue; end
      begin list.dispose if list && (!list.respond_to?(:disposed?) || !list.disposed?); rescue; end
      begin help_window.dispose if help_window && (!help_window.respond_to?(:disposed?) || !help_window.disposed?); rescue; end
      begin viewport.dispose if viewport && (!viewport.respond_to?(:disposed?) || !viewport.disposed?); rescue; end
      begin Input.update if defined?(Input); rescue; end
    end

    def select_from_native_lister(title, lister)
      selected_value = nil
      dev_pbListScreenBlock(title, lister) do |button, value|
        next unless list_confirm_button?(button)
        selected_value = value
        break
      end
      selected_value
    rescue => e
      log_error("Select From Native Lister #{title}", e)
      nil
    end

    def read_keyboard_input_char
      # Check Backspace
      if native_key_triggered?("BACKSPACE") || (defined?(Input) && defined?(Input::BACKSPACE) && Input.trigger?(Input::BACKSPACE))
        return :backspace
      end
      # Check Space
      if native_key_triggered?("SPACE") || (defined?(Input) && defined?(Input::SPACE) && Input.trigger?(Input::SPACE))
        return " "
      end
      # Check letters A-Z
      ("A".."Z").each do |char|
        if native_key_triggered?(char)
          return char.downcase
        end
      end
      # Check numbers 0-9
      ("0".."9").each do |num|
        if native_key_triggered?(num)
          return num
        end
      end
      # Support mkxp-z Keyboard trigger if defined
      if defined?(Keyboard) && Keyboard.respond_to?(:trigger?)
        # A-Z keys
        ("A".."Z").each do |char|
          begin
            const_val = Keyboard.const_get(char.to_sym) rescue nil
            if const_val && Keyboard.trigger?(const_val)
              return char.downcase
            end
          rescue
          end
        end
        # Numbers
        ("0".."9").each do |num|
          begin
            const_val = Keyboard.const_get("N#{num}".to_sym) rescue nil
            const_val ||= Keyboard.const_get("KEY_#{num}".to_sym) rescue nil
            if const_val && Keyboard.trigger?(const_val)
              return num
            end
          rescue
          end
        end
      end
      nil
    rescue
      nil
    end

    def keyboard_virtual_key(key_name)
      name = key_name.to_s.strip.upcase
      return nil if name == ""
      if name.index("F") == 0
        number = name[1..-1].to_i
        return (0x70 + number - 1) if number >= 1 && number <= 24
      end
      return (name.respond_to?(:ord) ? name.ord : name[0]) if name.length == 1 && name >= "A" && name <= "Z"
      return (name.respond_to?(:ord) ? name.ord : name[0]) if name.length == 1 && name >= "0" && name <= "9"
      return 0x08 if name == "BACKSPACE"
      return 0x20 if name == "SPACE"
      return 0x09 if name == "TAB"
      return 0x10 if name == "SHIFT"
      return 0x11 if name == "CTRL" || name == "CONTROL"
      return 0x12 if name == "ALT"
      nil
    rescue
      nil
    end

    def native_get_async_key_state_proc
      return @native_get_async_key_state_proc if defined?(@native_get_async_key_state_proc) && @native_get_async_key_state_proc
      if defined?(Win32API)
        begin
          api = Win32API.new("user32", "GetAsyncKeyState", ["i"], "i")
          @native_get_async_key_state_proc = proc { |vk| api.call(vk) }
          return @native_get_async_key_state_proc
        rescue
        end
        begin
          api = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
          @native_get_async_key_state_proc = proc { |vk| api.call(vk) }
          return @native_get_async_key_state_proc
        rescue
        end
      end
      begin
        require "fiddle/import"
        importer = Module.new do
          extend Fiddle::Importer
          dlload "user32"
          extern "short GetAsyncKeyState(int)"
        end
        @native_get_async_key_state_proc = proc { |vk| importer.GetAsyncKeyState(vk) }
        return @native_get_async_key_state_proc
      rescue LoadError
      rescue StandardError
      end
      nil
    rescue
      @native_get_async_key_state_proc = nil
      nil
    end

    def native_key_pressed?(constant_name)
      vk = keyboard_virtual_key(constant_name)
      return false if vk.nil?
      proc_obj = native_get_async_key_state_proc
      return false unless proc_obj
      state = proc_obj.call(vk)
      (state & 0x8000) != 0
    rescue
      false
    end

    def native_key_triggered?(constant_name)
      @native_key_trigger_states ||= {}
      key = constant_name.to_s.upcase
      pressed = native_key_pressed?(key)
      previous = @native_key_trigger_states[key] == true
      @native_key_trigger_states[key] = pressed
      pressed && !previous
    end


    def hotkey_config_path
      "PokeDebug_Hotkeys.cfg"
    end

    def default_hotkey_config
      {
        :menu => MENU_HOTKEY,
        :walk_through_walls => WTW_HOTKEY,
        :heal_party => HEAL_HOTKEY
      }
    end

    def hotkey_choices
      [
        "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9",
        "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"
      ]
    end

    def normalize_hotkey_name(value)
      name = value.to_s.strip.upcase
      return nil if name == ""
      return nil unless hotkey_choices.include?(name)
      name
    rescue
      nil
    end

    def hotkey_config
      @hotkey_config ||= default_hotkey_config.dup
    end

    def hotkey_name_for(action_id)
      load_hotkey_config! if @hotkey_config.nil?
      value = hotkey_config[action_id]
      value = default_hotkey_config[action_id] if value.nil? || value.to_s.strip == ""
      normalize_hotkey_name(value) || default_hotkey_config[action_id]
    rescue => e
      log_error("Hotkey Name #{action_id}", e)
      default_hotkey_config[action_id]
    end

    def hotkey_symbol_for(action_id)
      hotkey_name_for(action_id).to_sym
    end

    def hotkey_input_constant_for(action_id)
      hotkey_name_for(action_id)
    end

    def write_hotkey_config!
      lines = hotkey_config.keys.sort_by { |key| key.to_s }.map do |key|
        "#{key}=#{hotkey_name_for(key)}"
      end
      File.open(hotkey_config_path, "w") { |f| f.puts(lines.join("\n")) }
      true
    rescue => e
      log_error("Write Hotkey Config", e)
      false
    end

    def load_hotkey_config!
      @hotkey_config = default_hotkey_config.dup
      return @hotkey_config unless File.file?(hotkey_config_path)

      File.readlines(hotkey_config_path).each do |line|
        next if line.nil?
        raw = line.strip
        next if raw == ""
        next if raw.index("#") == 0
        key_text, value_text = raw.split("=", 2)
        next if value_text.nil?
        key = key_text.to_s.strip.downcase.to_sym
        normalized = normalize_hotkey_name(value_text)
        next if normalized.nil?
        @hotkey_config[key] = normalized if default_hotkey_config.key?(key)
      end
      @hotkey_config
    rescue => e
      log_error("Load Hotkey Config", e)
      @hotkey_config = default_hotkey_config.dup
    end

    def reset_hotkeys_to_default!
      @hotkey_config = default_hotkey_config.dup
      write_hotkey_config!
    rescue => e
      log_error("Reset Hotkeys", e)
      false
    end

    def current_message_guard_frame
      Graphics.frame_count
    rescue
      0
    end

    def map_interpreter_actually_running?
      return false unless defined?($game_system) && $game_system
      return false unless $game_system.respond_to?(:map_interpreter)
      interpreter = $game_system.map_interpreter
      interpreter && interpreter.respond_to?(:running?) && interpreter.running?
    rescue
      false
    end

    def visible_message_window_present?
      if defined?($game_message) && $game_message && $game_message.respond_to?(:visible)
        return true if $game_message.visible
      end
      scene = defined?($scene) ? $scene : nil
      return false unless scene
      [:@message_window, :@messagewindow].each do |ivar|
        next unless scene.instance_variable_defined?(ivar)
        window = scene.instance_variable_get(ivar)
        next unless window
        disposed = window.respond_to?(:disposed?) ? window.disposed? : false
        visible = window.respond_to?(:visible) ? window.visible : false
        return true if visible && !disposed
      end
      false
    rescue
      false
    end

    def message_window_flag_actually_busy?
      showing = defined?($game_temp) && $game_temp &&
                $game_temp.respond_to?(:message_window_showing) &&
                $game_temp.message_window_showing
      unless showing
        @orphan_message_flag_frame = nil
        return false
      end
      if visible_message_window_present? || map_interpreter_actually_running?
        @orphan_message_flag_frame = nil
        return true
      end
      @orphan_message_flag_frame ||= current_message_guard_frame
      elapsed = current_message_guard_frame.to_i - @orphan_message_flag_frame.to_i
      return true if elapsed < 300
      begin
        $game_temp.message_window_showing = false if $game_temp.respond_to?(:message_window_showing=)
        write_developer_log("input", "Message Guard", "Recovered orphan message_window_showing after #{elapsed} frames") if respond_to?(:write_developer_log)
      rescue
      end
      @orphan_message_flag_frame = nil
      false
    rescue => e
      throttled_log_error("Message Window Guard", e) if respond_to?(:throttled_log_error)
      false
    end

    def plugin_message_window_busy?
      return false unless defined?($game_temp) && $game_temp
      return true if message_window_flag_actually_busy?
      if $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
        return false if battle_scene_active?
        scene_name = current_scene_name.downcase
        return false if scene_name.include?("map")
        return true
      end
      false
    rescue => e
      log_error("Plugin Message Busy", e)
      false
    end

    def current_scene_name
      return "" unless defined?($scene) && $scene
      $scene.class.to_s
    rescue
      ""
    end

    def battle_scene_active?
      scene_name = current_scene_name.downcase
      return true if scene_name == "scene_battle"
      return true if scene_name == "pokebattle_scene"
      return true if scene_name == "battle_scene"
      return true if scene_name.index("scene_battle::") == 0
      return true if scene_name.index("pokebattle_scene::") == 0
      return true if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_battle) && $game_temp.in_battle
      return true if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:battling) && $PokemonGlobal.battling

      # Several engines keep the last battle object in $battle after returning
      # to the map. A non-nil object alone is therefore not proof that battle UI
      # is active; using it as such permanently filtered the field menu after a
      # battle/cutscene in Rejuvenation.
      if defined?($battle) && !$battle.nil? && scene_name.include?("map")
        unless @lingering_battle_object_logged
          write_developer_log("battle", "Battle Detection", "Ignoring lingering $battle on #{current_scene_name}") if respond_to?(:write_developer_log)
          @lingering_battle_object_logged = true
        end
        return false
      end
      return true if defined?($battle) && !$battle.nil? && !scene_name.include?("map")
      false
    rescue => e
      throttled_log_error("Battle Scene Active", e)
      false
    end

    def allow_map_runtime_update?
      return false unless defined?($game_map) && $game_map
      return false if battle_scene_active?
      true
    rescue => e
      throttled_log_error("Allow Map Runtime Update", e)
      false
    end

    def player_party
      p = get_player
      return [] unless p && p.respond_to?(:party) && p.party
      p.party
    end

    def remove_party_member(pkmn)
      party = player_party
      return false if party.empty?
      if party.respond_to?(:index)
        idx = party.index(pkmn)
        return !!party.delete_at(idx) unless idx.nil?
      end
      return !!party.delete(pkmn) if party.respond_to?(:delete)
      return !!party.Delete(pkmn) if party.respond_to?(:Delete)
      false
    end

    def get_repel_steps
      return $PokemonGlobal.repel if $PokemonGlobal && $PokemonGlobal.respond_to?(:repel)
      return $PokemonGlobal.repelSteps if $PokemonGlobal && $PokemonGlobal.respond_to?(:repelSteps)
      return $PokemonGlobal.repea if $PokemonGlobal && $PokemonGlobal.respond_to?(:repea)
      0
    end

    def set_repel_steps(value)
      if $PokemonGlobal.respond_to?(:repel=)
        $PokemonGlobal.repel = value
      elsif $PokemonGlobal.respond_to?(:repelSteps=)
        $PokemonGlobal.repelSteps = value
      else
        $PokemonGlobal.repea = value if $PokemonGlobal.respond_to?(:repea=)
      end
    end

    def get_map_toggle(*names)
      names.each do |name|
        return $PokemonMap.send(name) if $PokemonMap && $PokemonMap.respond_to?(name)
      end
      nil
    end

    def set_map_toggle(value, *names)
      names.each do |name|
        writer = "#{name}="
        if $PokemonMap && $PokemonMap.respond_to?(writer)
          $PokemonMap.send(writer, value)
          return true
        end
      end
      false
    end

    def safe_const_get(owner, name)
      return nil unless owner && owner.respond_to?(:const_defined?) && owner.const_defined?(name)
      owner.const_get(name)
    rescue
      nil
    end

    def safe_item_name(item, plural = false)
      return "items" if item.nil?
      if defined?(GameData) && safe_const_get(GameData, :Item)
        begin
          obj = GameData::Item.get(item)
          return plural ? obj.name_plural : obj.name
        rescue
        end
      end
      if defined?(PBItems)
        begin
          id = item.is_a?(Symbol) ? PBItems.const_get(item) : item
          name = PBItems.getName(id)
          return plural ? name + "s" : name
        rescue
        end
      end
      item.to_s
    end

    def safe_respond_to?(object, method_name)
      object && object.respond_to?(method_name)
    rescue
      false
    end

    def set_global_toggle(value, *names)
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      names.each do |name|
        writer = "#{name}="
        next unless $PokemonGlobal.respond_to?(writer)
        $PokemonGlobal.send(writer, value)
        return true
      end
      false
    rescue => e
      log_error("Set Global Toggle", e)
      false
    end

    def get_global_value(*names)
      return nil unless defined?($PokemonGlobal) && $PokemonGlobal
      names.each do |name|
        return $PokemonGlobal.send(name) if $PokemonGlobal.respond_to?(name)
      end
      nil
    rescue => e
      log_error("Get Global Value", e)
      nil
    end

    def set_global_value(value, *names)
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      names.each do |name|
        writer = "#{name}="
        next unless $PokemonGlobal.respond_to?(writer)
        $PokemonGlobal.send(writer, value)
        return true
      end
      false
    rescue => e
      log_error("Set Global Value", e)
      false
    end

    def module_has_method?(owner, method_name)
      return false unless owner
      # Building and walking the three complete method arrays is especially
      # expensive on Ruby 1.8/RGSS1 and can recurse through engine-provided
      # Module overrides. Ask Module directly whenever possible.
      return true if owner.respond_to?(:method_defined?) && owner.method_defined?(method_name)
      return true if owner.respond_to?(:private_method_defined?) && owner.private_method_defined?(method_name)
      return true if owner.respond_to?(:protected_method_defined?) && owner.protected_method_defined?(method_name)
      false
    rescue
      begin
        method_text = method_name.to_s
        return true if owner.respond_to?(:method_defined?) && owner.method_defined?(method_text)
        return true if owner.respond_to?(:private_method_defined?) && owner.private_method_defined?(method_text)
        return true if owner.respond_to?(:protected_method_defined?) && owner.protected_method_defined?(method_text)
      rescue
      end
      false
    end

    def safe_singleton_class(object)
      class << object
        self
      end
    rescue
      nil
    end

    def recalc_pokemon_stats(pkmn)
      adapter = engine_adapter_for(:pokemon) if respond_to?(:engine_adapter_for)
      return true if adapter && adapter.recalculate_stats(pkmn)
      if safe_respond_to?(pkmn, :calc_stats)
        pkmn.calc_stats
        return true
      end
      if safe_respond_to?(pkmn, :calcStats)
        pkmn.calcStats
        return true
      end
      false
    rescue => e
      log_error("Recalculate Pokemon Stats", e)
    end

    def numeric_like?(value)
      return true if value.is_a?(Numeric)
      text = value.to_s
      text != "" && text =~ /\A-?\d+\z/
    rescue
      false
    end

    def generic_value_matches?(actual, expected)
      return true if actual == expected
      return false if actual.nil? || expected.nil?
      return true if actual.to_s == expected.to_s
      return true if numeric_like?(actual) && numeric_like?(expected) && actual.to_i == expected.to_i
      false
    rescue => e
      log_error("Generic Value Matches", e)
      false
    end

    def display_value_matches?(actual, expected, formatter = nil)
      return false unless formatter
      actual_text = formatter.call(actual).to_s
      expected_text = formatter.call(expected).to_s
      normalized_item_key(actual_text) == normalized_item_key(expected_text)
    rescue => e
      log_error("Display Value Matches", e)
      false
    end

    def verify_pokemon_value(pkmn, expected, readers = [], formatter = nil)
      return false unless pkmn
      readers.each do |reader|
        begin
          value = reader.is_a?(Proc) ? reader.call(pkmn) : (pkmn.respond_to?(reader) ? pkmn.send(reader) : nil)
          return true if generic_value_matches?(value, expected)
          return true if display_value_matches?(value, expected, formatter)
        rescue => e
          log_error("Verify Pokemon Value #{reader}", e)
        end
      end
      false
    rescue => e
      log_error("Verify Pokemon Value", e)
      false
    end

    def make_alias(alias_name, target_name, owner)
      return false unless owner
      return false unless module_has_method?(owner, target_name)
      return false if runtime_patch_registered?(owner, target_name, false)
      return false if module_has_method?(owner, alias_name)
      owner.send(:alias_method, alias_name, target_name)
      register_runtime_patch(owner, target_name, alias_name, false)
      true
    rescue => e
      log_error("Alias #{target_name}", e)
      false
    end

    def make_singleton_alias(object, alias_name, target_name)
      return false unless object
      eigenclass = safe_singleton_class(object)
      return false unless eigenclass
      return false unless module_has_method?(eigenclass, target_name)
      return false if runtime_patch_registered?(object, target_name, true)
      return false if module_has_method?(eigenclass, alias_name)
      eigenclass.send(:alias_method, alias_name, target_name)
      register_runtime_patch(object, target_name, alias_name, true)
      true
    rescue => e
      log_error("Singleton Alias #{target_name}", e)
      false
    end

    def runtime_patch_registry
      @runtime_patch_registry ||= {}
    end

    def runtime_patch_key(owner, method_name, singleton = false)
      [owner.object_id, method_name.to_sym, singleton ? :singleton : :instance]
    rescue
      [owner.to_s, method_name.to_s, singleton ? :singleton : :instance]
    end

    def runtime_patch_registered?(owner, method_name, singleton = false)
      runtime_patch_registry.has_key?(runtime_patch_key(owner, method_name, singleton))
    rescue
      false
    end

    def register_runtime_patch(owner, method_name, alias_name, singleton = false, metadata = nil)
      key = runtime_patch_key(owner, method_name, singleton)
      return false if runtime_patch_registry.has_key?(key)
      runtime_patch_registry[key] = {
        :owner => owner, :method_name => method_name, :alias_name => alias_name,
        :singleton => singleton, :metadata => metadata
      }
      true
    rescue => e
      log_error("Register Runtime Patch #{method_name}", e)
      false
    end

    def runtime_patch_step_applied?(label)
      runtime_patch_registry.has_key?([:step, label.to_s])
    rescue
      false
    end

    def register_runtime_patch_step(label)
      runtime_patch_registry[[:step, label.to_s]] = { :step => label.to_s, :applied => true }
      true
    rescue
      false
    end

