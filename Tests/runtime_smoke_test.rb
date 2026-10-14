root = File.expand_path("..", File.dirname(__FILE__))
source = File.join(root, "Source Code")

load File.join(source, "00_header.rb")
load File.join(source, "10_core_01_runtime.rb")

def assert(condition, message)
  raise message unless condition
end

assert(defined?(DeveloperMenu), "DeveloperMenu was not defined")
assert(DeveloperMenu::VERSION == "3.1.4", "unexpected runtime version")
assert(DeveloperMenu.developer_menu_version == "3.1.4", "version helper failed")
assert(DeveloperMenu.t(DeveloperMenu::TR[:back]) == "Back/Cancel", "English translation failed")

# Validate all TR keys have complete translations in all 3 supported languages
required_languages = ["English", "Portugues", "Espanol"]
DeveloperMenu::TR.each do |key, translations|
  assert(translations.is_a?(Hash), "TR entry for #{key} must be a Hash")
  required_languages.each do |lang|
    assert(translations.has_key?(lang) && !translations[lang].to_s.empty?, "Missing '#{lang}' translation for TR[:#{key}]")
  end
end

DeveloperMenu.initialize_variables
assert(DeveloperMenu.walk_through_walls == false, "walk-through-walls default changed")
assert(DeveloperMenu.no_wild_battles == false, "wild battle default changed")
assert(DeveloperMenu.skip_trainer_battles == false, "trainer battle default changed")

DeveloperMenu.no_battles = true
assert(DeveloperMenu.no_battles == true, "combined battle toggle failed")
DeveloperMenu.no_battles = false
assert(DeveloperMenu.no_battles == false, "combined battle reset failed")

# Verify loading of full monolithic pokedebug_menu.rb
generated_menu = File.join(source, "pokedebug_menu.rb")
if File.file?(generated_menu)
  old_verbose = $VERBOSE
  $VERBOSE = nil
  begin
    load generated_menu
  ensure
    $VERBOSE = old_verbose
  end
  assert(defined?(DeveloperMenu::EngineAdapters), "EngineAdapters missing from generated menu")
  assert(DeveloperMenu.respond_to?(:on_off_text), "on_off_text helper missing from generated menu")
  assert(DeveloperMenu.on_off_text(true) == "ON", "on_off_text(true) failed")
  assert(DeveloperMenu.on_off_text(false) == "OFF", "on_off_text(false) failed")
  assert(DeveloperMenu.respond_to?(:install_legacy_input_hooks!), "install_legacy_input_hooks! missing")
  assert(DeveloperMenu.respond_to?(:install_graphics_heartbeat_hook!), "install_graphics_heartbeat_hook! missing")
  assert(DeveloperMenu.respond_to?(:on_graphics_frame_heartbeat), "on_graphics_frame_heartbeat missing")
end

puts "Runtime smoke tests passed."
