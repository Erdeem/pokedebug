    def simple_menu_action(label, action = nil, &block)
      final_action = action || block
      { :label => label.to_s, :action => final_action }
    rescue => e
      log_error("Simple Menu Action #{label}", e)
      { :label => label.to_s, :action => proc { } }
    end

    def translated_menu_action(key, action = nil, &block)
      simple_menu_action(t(TR[key]), action, &block)
    rescue => e
      log_error("Translated Menu Action #{key}", e)
      simple_menu_action(key.to_s, action, &block)
    end

    def state_toggle_message(prefix, enabled)
      _INTL("{1}: {2}", prefix.to_s, enabled ? "ON" : "OFF")
    rescue
      "#{prefix}: #{enabled ? 'ON' : 'OFF'}"
    end

    def state_hotkey_message(prefix, enabled, hotkey_name = nil)
      base = state_toggle_message(prefix, enabled)
      return base if hotkey_name.nil? || hotkey_name.to_s.strip == ""
      _INTL("{1} ({2})", base, hotkey_name.to_s)
    rescue
      base = state_toggle_message(prefix, enabled)
      hotkey_name ? "#{base} (#{hotkey_name})" : base
    end

    def action_result_message(action_label, success, success_suffix = "activated!", failure_suffix = "failed.")
      return "#{action_label} #{success_suffix}" if success
      "#{action_label} #{failure_suffix}"
    rescue
      success ? "#{action_label} activated!" : "#{action_label} failed."
    end

    def engine_failure_message(action_text)
      _INTL("Could not {1} on this engine.", action_text.to_s)
    rescue
      "Could not #{action_text} on this engine."
    end

    def unsupported_feature_message(feature_text)
      _INTL("{1} not supported on this engine.", feature_text.to_s)
    rescue
      "#{feature_text} not supported on this engine."
    end

    def report_failure_lines(report_name)
      [_INTL("Could not build {1}.", report_name.to_s)]
    rescue
      ["Could not build #{report_name}."]
    end

    def report_failure_message(report_name)
      Kernel.pbMessage(_INTL("Could not build {1}.", report_name.to_s))
    rescue
      Kernel.pbMessage("Could not build #{report_name}.")
    end

    def menu_back_label
      t(TR[:back])
    rescue
      "Back/Cancel"
    end

    # Compatibility facade for older debug code that expects the Essentials
    # pbShowCommands helper to be available in the current module. Some engines
    # only define it on individual scene classes (Bag, Party, Battle, etc.).
    def pbShowCommands(message, commands, cancel_value = -1, default_value = 0)
      prompt = message.nil? || message.to_s == "" ? _INTL("Choose an option.") : message.to_s
      result = safe_menu_choice(prompt, commands, default_value, "Show Commands")
      return cancel_value if result.nil? || result.to_i < 0
      result.to_i
    rescue => e
      log_error("Show Commands Compatibility", e)
      cancel_value
    end

    def notify_action_result(action_label, success, success_suffix = "activated!", failure_suffix = "failed.")
      safe_text_message(action_result_message(action_label, success, success_suffix, failure_suffix), "Action Result #{action_label}")
      !!success
    rescue => e
      log_error("Notify Action Result #{action_label}", e)
      !!success
    end

    def toggle_runtime_flag_action(label, ivar_name, state_label = nil)
      simple_menu_action(label) do
        current = instance_variable_get(ivar_name)
        instance_variable_set(ivar_name, !current)
        Kernel.pbMessage(state_toggle_message(state_label || label, instance_variable_get(ivar_name)))
      end
    rescue => e
      log_error("Toggle Runtime Flag Action #{label}", e)
      simple_menu_action(label)
    end
