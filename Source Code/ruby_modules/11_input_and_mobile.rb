    def input_button_value(symbol_name, constant_name = nil)
      return nil unless defined?(Input)
      return symbol_name if symbol_name.is_a?(Integer)
      return Input.const_get(constant_name) if constant_name && Input.const_defined?(constant_name)
      upper_name = symbol_name.to_s.upcase
      return Input.const_get(upper_name) if Input.const_defined?(upper_name)
      symbol_name
    rescue
      nil
    end

    def input_pressing?(symbol_name, constant_name = nil)
      value = input_button_value(symbol_name, constant_name)
      if !value.nil? && respond_to?(:engine_adapter_for)
        adapter_result = engine_adapter_for(:input).input_pressing(value)
        if adapter_result && adapter_result[0]
          return true if adapter_result[1]
          return native_key_pressed?(constant_name || symbol_name)
        end
      end
      return true if !value.nil? && Input.press?(value)
      native_key_pressed?(constant_name || symbol_name)
    rescue
      false
    end

    def all_input_pressing?(*buttons)
      return false if buttons.empty?
      buttons.all? { |button| input_pressing?(button, button.to_s.upcase) }
    end

    def mobile_menu_combo_definitions
      [
        { :buttons => [:L, :R], :hold => 10, :label => "L + R" },
        { :buttons => [:AUX1, :AUX2], :hold => 10, :label => "AUX1 + AUX2" },
        { :buttons => [:X, :Y], :hold => 12, :label => "X + Y" },
        { :buttons => [:CTRL, :SHIFT], :hold => 12, :label => "CTRL + SHIFT" },
        { :buttons => [:L, :A], :hold => 14, :label => "L + A" },
        { :buttons => [:R, :B], :hold => 14, :label => "R + B" },
        { :buttons => [:A, :B, :C], :hold => 24, :label => "A + B + C" }
      ]
    end

    def mobile_combo_pressed?(combo)
      buttons = combo[:buttons] || []
      return false if buttons.empty?
      all_input_pressing?(*buttons)
    rescue
      false
    end

    def mobile_combo_label(combo)
      combo[:label] || (combo[:buttons] || []).map { |button| button.to_s.upcase }.join(" + ")
    rescue
      "UNKNOWN"
    end

    def joiplay_combo_triggered?
      return false unless defined?(Input)
      @mobile_combo_hold_counters ||= {}
      @last_mobile_combo_label = nil
      triggered = false

      mobile_menu_combo_definitions.each do |combo|
        label = mobile_combo_label(combo)
        if mobile_combo_pressed?(combo)
          @mobile_combo_hold_counters[label] = @mobile_combo_hold_counters.fetch(label, 0).to_i + 1
          next unless @mobile_combo_hold_counters[label] >= combo[:hold].to_i
          @last_mobile_combo_label = label
          triggered = true
          break
        else
          @mobile_combo_hold_counters[label] = 0
        end
      end

      unless triggered
        @mobile_combo_hold_frames = 0
        return false
      end

      @mobile_combo_hold_counters.keys.each { |key| @mobile_combo_hold_counters[key] = 0 }
      true
    rescue => e
      log_error("JoiPlay Combo Trigger", e)
      false
    end

    def menu_triggered?
      triggered = trigger_hotkey?(hotkey_symbol_for(:menu), hotkey_input_constant_for(:menu))
      held = input_pressing?(hotkey_symbol_for(:menu), hotkey_input_constant_for(:menu))
      if held
        fresh_press = !@menu_hotkey_latched
        @menu_hotkey_latched = true
        return true if triggered || fresh_press
      else
        @menu_hotkey_latched = false
        return true if triggered
      end
      joiplay_combo_triggered?
    rescue => e
      throttled_log_error("Menu Trigger", e) if respond_to?(:throttled_log_error)
      false
    end

    def menu_input_held?
      return true if input_pressing?(hotkey_symbol_for(:menu), hotkey_input_constant_for(:menu))
      mobile_menu_combo_definitions.any? { |combo| mobile_combo_pressed?(combo) }
    rescue
      false
    end

    def current_input_frame
      Graphics.frame_count
    rescue
      0
    end

    def mark_menu_input_disarmed!
      @menu_input_armed = false
      @menu_input_disarmed_frame = current_input_frame
      true
    rescue
      @menu_input_armed = false
      false
    end

    def menu_input_rearm_timed_out?
      started = @menu_input_disarmed_frame
      return true if started.nil?
      current_input_frame.to_i - started.to_i >= 120
    rescue
      true
    end

    def rearm_menu_input!
      key = hotkey_input_constant_for(:menu).to_s.upcase
      @native_key_trigger_states ||= {}
      @native_key_trigger_states[key] = native_key_pressed?(key)
      @menu_input_armed = true
      @menu_input_disarmed_frame = nil
      true
    rescue
      @menu_input_armed = true
      true
    end

    def battle_heal_triggered_now?
      return false unless battle_scene_active?
      return false unless battle_heal_hotkey_enabled?
      configured_held = input_pressing?(hotkey_symbol_for(:heal_party), hotkey_input_constant_for(:heal_party))
      fallback_held = native_key_pressed?("F7")
      combo_held = native_key_pressed?("CTRL") && native_key_pressed?("H")
      any_heal_input_held = configured_held || fallback_held || combo_held
      if @battle_heal_input_latched
        @battle_heal_input_latched = false unless any_heal_input_held
        return false
      end
      current_frame = begin
        Graphics.frame_count
      rescue
        0
      end
      frame_gap = current_frame.to_i - (@last_battle_heal_frame || -9999).to_i
      return false if frame_gap < 20

      triggered = false
      trigger_label = nil

      if trigger_hotkey?(hotkey_symbol_for(:heal_party), hotkey_input_constant_for(:heal_party))
        triggered = true
        trigger_label = hotkey_name_for(:heal_party)
      end

      if !triggered && native_key_triggered?("F7")
        triggered = true
        trigger_label = "F7"
      end

      if !triggered && native_key_pressed?("CTRL") && native_key_triggered?("H")
        triggered = true
        trigger_label = "CTRL+H"
      end

      if triggered
        @battle_heal_input_latched = true
        @last_battle_heal_frame = current_frame.to_i
        begin
          File.open("developer_menu_errors.log", "a") { |f| f.puts("[#{Time.now}] Battle Heal Triggered via #{trigger_label}") }
        rescue
        end
        return true
      end
      false
    rescue => e
      throttled_log_error("Battle Heal Trigger", e)
      false
    end

    def allow_hotkey_processing?
      return false if plugin_message_window_busy?
      # Do not let a physical key captured during the RGSS loading/fade
      # sequence open a modal PokeDebug menu before the game globals exist.
      scene_text = current_scene_name.to_s.downcase
      return false if scene_text.index("title") || scene_text.index("intro") ||
                      scene_text.index("load") || scene_text.index("splash")
      if battle_scene_active?
        return true if battle_heal_hotkey_enabled?
        return true if battle_wtw_hotkey_enabled?
        return true if battle_menu_open_allowed?
        return false
      end
      return false unless defined?($game_system) || defined?($scene) || defined?($game_map)
      true
    rescue => e
      throttled_log_error("Allow Hotkey Processing", e)
      false
    end

    def reset_toggles_if_in_title_scene
      return unless defined?($scene) && $scene
      scene_name = $scene.class.name.to_s
      if scene_name.include?("Title") || scene_name.include?("Intro") || scene_name.include?("Load")
        return if @title_scene_reset_done
        @walk_through_walls = false if defined?(@walk_through_walls) && @walk_through_walls
        @no_wild_battles = false if defined?(@no_wild_battles) && @no_wild_battles
        @skip_trainer_battles = false if defined?(@skip_trainer_battles) && @skip_trainer_battles
        @no_battles = false if defined?(@no_battles) && @no_battles
        @inf_mega = false if defined?(@inf_mega) && @inf_mega
        begin
          reset_game_data_cache!
        rescue
        end
        @title_scene_reset_done = true
      else
        @title_scene_reset_done = false
      end
    rescue
    end

    def on_input_update
      return if @processing_hotkey
      return if @menu_open
      begin
        reset_toggles_if_in_title_scene
      rescue
      end
      @processing_hotkey = true
      begin
        safe_execute("Input Update") do
          ensure_runtime_patches!
          if battle_heal_triggered_now?
            play_decision_sound
            heal_party
            next
          end
          menu_requested = menu_triggered?
          unless allow_hotkey_processing?
            if menu_requested && respond_to?(:write_developer_log)
              message_flag = defined?($game_temp) && $game_temp && $game_temp.respond_to?(:message_window_showing) ? $game_temp.message_window_showing : nil
              in_menu = defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_menu) ? $game_temp.in_menu : nil
              write_developer_log("input", "Menu Blocked", "scene=#{current_scene_name} message=#{message_flag.inspect} in_menu=#{in_menu.inspect} interpreter=#{map_interpreter_actually_running?.inspect}")
            end
            return
          end
          if menu_requested && (!battle_scene_active? || battle_menu_open_allowed?)
            play_decision_sound
            @mobile_combo_hold_frames = 0
            mark_menu_input_disarmed!
            show_menu
            next
          end
          if trigger_hotkey?(hotkey_symbol_for(:walk_through_walls), hotkey_input_constant_for(:walk_through_walls)) &&
             (!battle_scene_active? || battle_wtw_hotkey_enabled?)
            toggle_wtw
          end
          if trigger_hotkey?(hotkey_symbol_for(:heal_party), hotkey_input_constant_for(:heal_party)) &&
             (!battle_scene_active? || battle_heal_hotkey_enabled?)
            heal_party
          end
        end
      ensure
        @processing_hotkey = false
      end
    end

    # Independent MKXP heartbeat used when a game replaces or bypasses
    # Input.trigger?/press? during scripted scenes. It only reads the physical
    # menu key and never wraps Input.update, avoiding Rejuvenation's alias loop.
    def on_graphics_hotkey_heartbeat
      return if @graphics_hotkey_heartbeat_running
      @graphics_hotkey_heartbeat_running = true
      begin
        frame = current_input_frame
        if (frame.to_i % 120) == 0
          install_modern_input_hooks! if respond_to?(:install_modern_input_hooks!)
          install_scene_map_heartbeat_hook! if respond_to?(:install_scene_map_heartbeat_hook!)
          ensure_pokedebug_device! if respond_to?(:ensure_pokedebug_device!)
        end
        if respond_to?(:process_pokedebug_device_menu!) && process_pokedebug_device_menu!
          return true
        end

        key = hotkey_input_constant_for(:menu).to_s.upcase
        held = native_key_pressed?(key)
        fresh_press = held && !@graphics_menu_hotkey_latched
        @graphics_menu_hotkey_latched = held
        return false unless fresh_press

        # Synchronize the regular route so the same physical press cannot open
        # a second menu when Input resumes later in the frame.
        @menu_hotkey_latched = true
        if @menu_open
          choice_visible = menu_choice_active? && (visible_message_window_present? || message_window_flag_actually_busy?)
          if choice_visible || menu_inactive_frames < 120
            details = "key=#{key} choice_active=#{menu_choice_active?} choice_visible=#{choice_visible} inactive_frames=#{menu_inactive_frames}"
            write_developer_log("input", "Heartbeat Menu", "Ignored duplicate physical #{details}") if respond_to?(:write_developer_log)
            return false
          end
          details = "key=#{key} choice_active=#{menu_choice_active?} choice_visible=#{choice_visible} inactive_frames=#{menu_inactive_frames} session=#{@menu_session_serial}"
          write_developer_log("input", "Menu Watchdog", "Recovered orphaned menu state #{details}") if respond_to?(:write_developer_log)
          recover_menu_state!("Graphics Heartbeat Orphaned Menu")
        end
        if plugin_message_window_busy?
          write_developer_log("input", "Heartbeat Menu Blocked", "scene=#{current_scene_name} key=#{key}") if respond_to?(:write_developer_log)
          return false
        end
        return false if battle_scene_active? && !battle_menu_open_allowed?
        write_developer_log("input", "Heartbeat Menu", "Opening via physical #{key}") if respond_to?(:write_developer_log)
        play_decision_sound
        show_menu
        true
      rescue => e
        throttled_log_error("Graphics Hotkey Heartbeat", e) if respond_to?(:throttled_log_error)
        false
      ensure
        @graphics_hotkey_heartbeat_running = false
      end
    end

    def show_joiplay_help
      Kernel.pbMessage(_INTL("{1}", t(TR[:mobile_help_text], hotkey_name_for(:menu))))
    rescue => e
      log_error("JoiPlay Help", e)
    end
