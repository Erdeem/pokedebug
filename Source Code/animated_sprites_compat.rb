ANIMATED_SPRITES_CONFIG = {
  :root => "Graphics/AnimatedBattlers",
  :frame_delay => 1,
  # Fallback anchor inside Rejuvenation's native 200px battler canvas. The
  # normal path measures the original species sprite instead of guessing from
  # type, ability or BattlerY metadata.
  :rejuvenation_fallback_anchor_x => 100,
  :rejuvenation_fallback_anchor_y => 195,
  :log_file => "animated_sprites_error.log",
  :debug_file => "animated_sprites_debug.log",
  :enable_debug_log => false,
  :overrides => {
    # "PIKACHU" => "LUCARIO",
    # "PIKACHU_1" => "LUCARIO_2",
    # "EEVEE" => { :front => "INDIGO_EEVEE", :back => "INDIGO_EEVEE" }
  }
}

module AnimatedSpriteOverrides
  extend self

  FOLDER_MAP = {
    "Graphics/Pokemon/Front/" => "Front",
    "Graphics/Pokemon/Back/" => "Back",
    "Graphics/Pokemon/Front shiny/" => "Front shiny",
    "Graphics/Pokemon/Back shiny/" => "Back shiny"
  }

  def config
    ANIMATED_SPRITES_CONFIG
  end

  def install_runtime_patches
    return true if $animated_sprites_runtime_ready
    patched = false
    modern_ready = false
    if defined?(GameData::Species) &&
       GameData::Species.respond_to?(:front_sprite_filename) &&
       GameData::Species.respond_to?(:back_sprite_filename)
      patch_species_filenames
      patched = true
      modern_ready = true
    end
    if defined?(PokemonSprite)
      patch_rejuvenation_pokemon_sprite
      patched = true
    end
    if defined?(PokemonBattlerSprite)
      patch_rejuvenation_battler_sprite
      patched = true
    end
    $animated_sprites_patched = patched
    rejuvenation_ready = defined?(PokemonSprite) && defined?(PokemonBattlerSprite) &&
                         PokemonSprite.ancestors.include?(RejuvenationPokemonSpritePatch) &&
                         PokemonBattlerSprite.ancestors.include?(RejuvenationPokemonBattlerSpritePatch)
    $animated_sprites_runtime_ready = (modern_ready || rejuvenation_ready) ? true : false
    log_debug("Animated sprite patches checked. root=#{config[:root]} pokemon_sprite=#{defined?(PokemonSprite) ? true : false} battler_sprite=#{defined?(PokemonBattlerSprite) ? true : false}")
    patched
  rescue => e
    log_error(e)
    false
  end

  def patch_animated_bitmap
    # Nova already has PngAnimatedBitmap support for Graphics/AnimatedBattlers.
    # Keep its native canvas fitting/FPS logic; this script only redirects species paths.
  end

  def patch_species_filenames
    singleton = GameData::Species.singleton_class
    return if singleton.method_defined?(:animated_sprites_original_front_sprite_filename)

    singleton.class_eval do
      alias animated_sprites_original_front_sprite_filename front_sprite_filename
      alias animated_sprites_original_back_sprite_filename back_sprite_filename

      def front_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false)
        original = animated_sprites_original_front_sprite_filename(species, form, gender, shiny, shadow)
        AnimatedSpriteOverrides.redirect_species_filename(
          original,
          :species => species, :form => form, :gender => gender, :shiny => shiny, :shadow => shadow, :back => false
        )
      end

      def back_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false)
        original = animated_sprites_original_back_sprite_filename(species, form, gender, shiny, shadow)
        AnimatedSpriteOverrides.redirect_species_filename(
          original,
          :species => species, :form => form, :gender => gender, :shiny => shiny, :shadow => shadow, :back => true
        )
      end
    end
  end

  def patch_rejuvenation_pokemon_sprite
    return if PokemonSprite.ancestors.include?(RejuvenationPokemonSpritePatch)
    PokemonSprite.send(:prepend, RejuvenationPokemonSpritePatch)
  end

  def patch_rejuvenation_battler_sprite
    return if PokemonBattlerSprite.ancestors.include?(RejuvenationPokemonBattlerSpritePatch)
    PokemonBattlerSprite.send(:prepend, RejuvenationPokemonBattlerSpritePatch)
  end

  def animated_bitmap_for_pokemon(pokemon, back = false)
    return nil if pokemon.nil? || pokemon.is_a?(String)
    return nil unless pokemon.respond_to?(:species)
    return nil if pokemon.respond_to?(:isEgg?) && pokemon.isEgg?
    species = pokemon.species.to_s.upcase
    return nil if species == ""
    form = pokemon.respond_to?(:form) ? pokemon.form.to_i : 0
    shiny = if pokemon.respond_to?(:isShiny?)
              pokemon.isShiny?
            elsif pokemon.respond_to?(:shiny?)
              pokemon.shiny?
            else
              false
            end
    female = false
    if pokemon.respond_to?(:gender)
      gender = pokemon.gender
      female = (gender == :F || gender.to_s.upcase == "F")
      female ||= (gender.is_a?(Numeric) && gender.to_i == 1)
    elsif pokemon.respond_to?(:isFemale?)
      female = pokemon.isFemale?
    end

    folder = back ? "Back" : "Front"
    folder += " shiny" if shiny
    stems = []
    if form > 0 && female
      stems << "#{species}_#{form}_female"
      stems << "#{species}_female_#{form}"
    end
    stems << "#{species}_#{form}" if form > 0
    stems << "#{species}_female" if female
    stems << species
    stems.each do |stem|
      candidate = File.join(config[:root], folder, stem).tr("\\", "/")
      resolved = pbResolveBitmap(candidate)
      next unless resolved
      log_debug("rejuvenation-hit species=#{species} form=#{form} female=#{female} shiny=#{shiny} back=#{back} path=#{resolved}")
      # Rejuvenation positions every battler as a 200px canvas and then applies
      # its species metadata. Measure the actual opaque bounds of the native
      # sprite and place the animated sheet on that same visual anchor. This
      # preserves intentional flight height and unusual per-form positioning
      # without maintaining a fragile list of airborne species.
      anchor = native_visual_anchor_for_pokemon(pokemon, back)
      log_debug("rejuvenation-canvas species=#{species} back=#{back} anchor=#{anchor.inspect}")
      return AutoSheetAnimatedBitmap.new(resolved, 0, config[:frame_delay], 200, 2, anchor)
    end
    log_debug("rejuvenation-miss species=#{species} form=#{form} female=#{female} shiny=#{shiny} back=#{back}")
    nil
  rescue => e
    log_error(e)
    nil
  end

  def opaque_bounds(bitmap)
    return nil unless bitmap && !bitmap.disposed?
    return nil unless bitmap.respond_to?(:get_pixel)
    min_x = bitmap.width
    min_y = bitmap.height
    max_x = -1
    max_y = -1
    bitmap.height.times do |y|
      bitmap.width.times do |x|
        pixel = bitmap.get_pixel(x, y)
        alpha = pixel && pixel.respond_to?(:alpha) ? pixel.alpha.to_i : 255
        next if !pixel || alpha <= 0
        min_x = x if x < min_x
        max_x = x if x > max_x
        min_y = y if y < min_y
        max_y = y if y > max_y
      end
    end
    return nil if max_x < min_x || max_y < min_y
    { :left => min_x, :top => min_y, :right => max_x, :bottom => max_y }
  rescue => e
    log_error(e)
    nil
  end

  def native_visual_anchor_for_pokemon(pokemon, back = false)
    fallback = {
      :x => config[:rejuvenation_fallback_anchor_x].to_i,
      :y => config[:rejuvenation_fallback_anchor_y].to_i
    }
    return fallback unless respond_to_native_pokemon_loader?
    cache_key = native_anchor_cache_key(pokemon, back)
    @native_visual_anchor_cache ||= {}
    cached = @native_visual_anchor_cache[cache_key]
    return cached if cached
    native_bitmap = nil
    begin
      # This global loader is Rejuvenation's unpatched static sprite loader;
      # our adapter only wraps PokemonSprite#setPokemonBitmap.
      begin
        native_bitmap = pbLoadPokemonBitmap(pokemon, back, battle: true)
      rescue ArgumentError
        # Older Essentials/Reborn-derived loaders only accept two positional
        # arguments. They already consider $game_temp.in_battle.
        native_bitmap = pbLoadPokemonBitmap(pokemon, back)
      end
      bounds = opaque_bounds(native_bitmap)
      return fallback unless bounds
      anchor = {
        :x => ((bounds[:left] + bounds[:right] + 1) / 2.0).round,
        :y => bounds[:bottom],
        :native_bounds => bounds
      }
      @native_visual_anchor_cache[cache_key] = anchor
      anchor
    ensure
      if native_bitmap && native_bitmap.respond_to?(:dispose)
        disposed = native_bitmap.respond_to?(:disposed?) ? native_bitmap.disposed? : false
        native_bitmap.dispose unless disposed
      end
    end
  rescue => e
    log_error(e)
    fallback
  end

  def native_anchor_cache_key(pokemon, back)
    species = pokemon.respond_to?(:species) ? pokemon.species.to_s : ""
    form = pokemon.respond_to?(:form) ? pokemon.form.to_i : 0
    gender = pokemon.respond_to?(:gender) ? pokemon.gender.to_s : ""
    shiny = pokemon.respond_to?(:isShiny?) ? pokemon.isShiny? : (pokemon.respond_to?(:shiny?) && pokemon.shiny?)
    [species, form, gender, shiny ? 1 : 0, back ? 1 : 0].join("|")
  rescue
    [pokemon.object_id, back ? 1 : 0].join("|")
  end

  def respond_to_native_pokemon_loader?
    Object.private_method_defined?(:pbLoadPokemonBitmap) || Object.method_defined?(:pbLoadPokemonBitmap)
  rescue
    false
  end

  def redirect_species_filename(original, context = {})
    return original if original.nil?

    override = path_from_override(original)
    if override
      log_debug("override-hit species=#{context[:species]} form=#{context[:form]} gender=#{context[:gender]} shiny=#{context[:shiny]} back=#{context[:back]} original=#{original} redirected=#{override}")
      return override
    end

    redirected = resolve_bitmap_path(original)
    if pbResolveBitmap(redirected)
      log_debug("redirect-hit species=#{context[:species]} form=#{context[:form]} gender=#{context[:gender]} shiny=#{context[:shiny]} back=#{context[:back]} original=#{original} redirected=#{redirected}")
      return redirected
    end
    log_debug("redirect-miss species=#{context[:species]} form=#{context[:form]} gender=#{context[:gender]} shiny=#{context[:shiny]} back=#{context[:back]} original=#{original} tried=#{redirected}")
    original
  rescue => e
    log_error(e)
    original
  end

  def resolve_bitmap_path(original)
    normalized = original.to_s.tr("\\", "/")
    override = path_from_override(normalized)
    return override if override

    FOLDER_MAP.each do |source_prefix, target_subfolder|
      next unless normalized.index(source_prefix) == 0

      basename = normalized.sub(/^#{Regexp.escape(source_prefix)}/, '')
      candidate = File.join(config[:root], target_subfolder, basename).tr("\\", "/")
      log_debug("resolve-bitmap source=#{normalized} candidate=#{candidate}")
      return candidate if pbResolveBitmap(candidate)
    end
    normalized
  rescue => e
    log_error(e)
    original
  end

  def path_from_override(original)
    normalized = original.to_s.tr("\\", "/")
    basename = File.basename(normalized)
    stem = File.basename(basename, ".*")
    folder = target_folder_for_path(normalized)
    return nil if folder.nil?

    override = lookup_override(stem)
    return nil if override.nil?

    resolved =
      if override.is_a?(String)
        File.join(config[:root], folder, override)
      elsif override.is_a?(Hash)
        key = folder_key(folder)
        chosen = override[key] || override[key.to_s] || override[:source] || override["source"]
        chosen ? File.join(config[:root], folder, chosen.to_s) : nil
      end

    resolved = resolved ? resolved.tr("\\", "/") : nil
    return resolved if resolved && pbResolveBitmap(resolved)
    log_debug("override-miss stem=#{stem} folder=#{folder} resolved=#{resolved}") if resolved
    nil
  end

  def target_folder_for_path(path)
    normalized = path.to_s.tr("\\", "/")
    FOLDER_MAP.each do |source_prefix, target_subfolder|
      return target_subfolder if normalized.index(source_prefix) == 0
    end
    nil
  end

  def folder_key(folder)
    case folder
    when "Front" then :front
    when "Back" then :back
    when "Front shiny" then :shiny_front
    when "Back shiny" then :shiny_back
    else
      folder.downcase.gsub(" ", "_").to_sym
    end
  end

  def lookup_override(stem)
    overrides = config[:overrides] || {}
    overrides[stem] || overrides[stem.to_sym]
  end

  def animated_battler_path?(path)
    prefix = config[:root].tr("\\", "/") + "/"
    path.to_s.tr("\\", "/").index(prefix) == 0
  end

  def log_debug(message)
    return unless config[:enable_debug_log]
    File.open(config[:debug_file], "a") { |f| f.puts("[#{Time.now}] #{message}") }
  rescue
  end

  def log_error(error)
    File.open(config[:log_file], "a") do |f|
      f.puts("[#{Time.now}] #{error.class}: #{error.message}")
      error.backtrace.each { |line| f.puts("  #{line}") } if error.backtrace
      f.puts
    end
  rescue
  end
end

module RejuvenationPokemonSpritePatch
  def setPokemonBitmap(pokemon, back = false, battle: false)
    animated = AnimatedSpriteOverrides.animated_bitmap_for_pokemon(pokemon, back)
    return super unless animated
    @_iconbitmap.dispose if @_iconbitmap
    @_iconbitmap = animated
    self.bitmap = @_iconbitmap.bitmap
    self.color = Color.new(0, 0, 0, 0)
  end
end

module RejuvenationPokemonBattlerSpritePatch
  def setPokemonBitmap(pokemon, back = false)
    animated = AnimatedSpriteOverrides.animated_bitmap_for_pokemon(pokemon, back)
    return super unless animated
    @_iconbitmap.dispose if @_iconbitmap
    @_iconbitmap = animated
    self.bitmap = @_iconbitmap.bitmap
  end
end

class AutoSheetAnimatedBitmap
  attr_accessor :frames

  def initialize(file, hue = 0, frame_delay = 5, canvas_size = 0, preferred_scale = 1, visual_anchor = nil, preserve_bottom_padding = false)
    @frames = []
    @currentFrame = 0
    @disposed = false
    @timer_start = System.uptime
    @frame_duration = [frame_delay.to_i, 1].max / 20.0

    path = file
    filename = ""
    if file[-1] != "/"
      split_file = file.split(/[\\\/]/)
      filename = split_file.pop
      path = split_file.join("/") + "/"
    end

    # Own this bitmap instead of disposing a shared RPG::Cache entry.  The
    # latter breaks the next instance of the same species in some MKXP builds.
    sheet = Bitmap.new(file)
    sheet.hue_change(hue) if hue.to_i != 0 && sheet.respond_to?(:hue_change)
    if sheet.width > sheet.height && (sheet.width % sheet.height).zero?
      frame_width = sheet.height
      frame_count = sheet.width / frame_width
      # The pack's square frames do not share a visual baseline. Some species
      # have dozens of fully transparent rows below their feet (e.g. Grubbin),
      # while others touch the last row (e.g. Numel). Find the first frame's
      # actual opaque bottom once and keep that baseline for the whole cycle.
      first_frame_bounds = nil
      if canvas_size.to_i > 0 && sheet.respond_to?(:get_pixel)
        min_x = frame_width
        min_y = sheet.height
        max_x = -1
        max_y = -1
        sheet.height.times do |y|
          frame_width.times do |x|
            pixel = sheet.get_pixel(x, y)
            alpha = pixel && pixel.respond_to?(:alpha) ? pixel.alpha.to_i : 255
            next if !pixel || alpha <= 0
            min_x = x if x < min_x
            max_x = x if x > max_x
            min_y = y if y < min_y
            max_y = y if y > max_y
          end
        end
        if max_x >= min_x && max_y >= min_y
          first_frame_bounds = { :left => min_x, :top => min_y, :right => max_x, :bottom => max_y }
        end
      end
      frame_count.times do |i|
        if canvas_size.to_i > 0
          canvas = canvas_size.to_i
          requested_width = frame_width * [preferred_scale.to_i, 1].max
          draw_width = [requested_width, canvas - 8].min
          draw_height = (sheet.height * draw_width.to_f / frame_width).round
          frame = Bitmap.new(canvas, canvas)
          anchor = visual_anchor.is_a?(Hash) ? visual_anchor : {}
          target_x = anchor.key?(:x) ? anchor[:x].to_i : canvas / 2
          target_y = anchor.key?(:y) ? anchor[:y].to_i : canvas - 5
          if first_frame_bounds
            scaled_left = (first_frame_bounds[:left] * draw_width.to_f / frame_width).round
            scaled_right_edge = ((first_frame_bounds[:right] + 1) * draw_width.to_f / frame_width).round
            scaled_center = (scaled_left + scaled_right_edge) / 2.0
            scaled_bottom_edge = ((first_frame_bounds[:bottom] + 1) * draw_height.to_f / sheet.height).round
            dest_x = (target_x - scaled_center).round
            dest_y = target_y + 1 - scaled_bottom_edge
          else
            dest_x = (canvas - draw_width) / 2
            dest_y = canvas - draw_height
          end
          source_rect = Rect.new(i * frame_width, 0, frame_width, sheet.height)
          frame.stretch_blt(Rect.new(dest_x, dest_y, draw_width, draw_height), sheet, source_rect)
        else
          frame = Bitmap.new(frame_width, sheet.height)
          frame.blt(0, 0, sheet, Rect.new(i * frame_width, 0, frame_width, sheet.height))
        end
        @frames << frame
      end
      sheet.dispose
    else
      @frames = [sheet]
    end
  end

  def dispose
    return if @disposed
    @frames.each { |frame| frame.dispose if frame && !frame.disposed? }
    @disposed = true
  end

  def disposed?
    @disposed
  end

  def [](index)
    @frames[index]
  end

  def width
    bitmap.width
  end

  def height
    bitmap.height
  end

  def bitmap
    @frames[@currentFrame]
  end

  def currentIndex
    @currentFrame
  end

  def length
    @frames.length
  end

  def totalFrames
    (@frame_duration * @frames.length * 20).to_i
  end

  def each
    @frames.each { |item| yield item }
  end

  def deanimate
    (1...@frames.length).each { |i| @frames[i].dispose }
    @frames = [@frames[0]]
    @currentFrame = 0
    @frame_duration = 0
    @frames[0]
  end

  def copy
    x = clone
    x.frames = x.frames.clone
    x.frames.each_with_index { |frame, i| x.frames[i] = frame.copy }
    x
  end

  def update
    return if disposed?
    if @frames.length > 1
      @currentFrame = ((System.uptime - @timer_start) / @frame_duration).to_i % @frames.length
    end
  end
end

begin
  module Graphics
    class << self
      unless method_defined?(:animated_sprites_original_update)
        alias animated_sprites_original_update update
      end

      def update
        AnimatedSpriteOverrides.install_runtime_patches
        if defined?(::DeveloperMenu) && ::DeveloperMenu.respond_to?(:on_graphics_hotkey_heartbeat)
          ::DeveloperMenu.on_graphics_hotkey_heartbeat
        end
        animated_sprites_original_update
      end
    end
  end
rescue => e
  AnimatedSpriteOverrides.log_error(e)
end

begin
  AnimatedSpriteOverrides.install_runtime_patches
rescue => e
  AnimatedSpriteOverrides.log_error(e)
end

# Rejuvenation loads its sprite classes from loose scripts after MKXP preload
# scripts have already run, with additional Graphics.update aliases later.
# Trace class/module completion during boot so the adapters are installed at the
# moment their targets become available, independent of Graphics.update aliases.
begin
  if defined?(TracePoint)
    $animated_sprites_boot_trace = TracePoint.new(:end) do
      AnimatedSpriteOverrides.install_runtime_patches
      if defined?(PokemonSprite) && defined?(PokemonBattlerSprite) &&
         PokemonSprite.ancestors.include?(RejuvenationPokemonSpritePatch) &&
         PokemonBattlerSprite.ancestors.include?(RejuvenationPokemonBattlerSpritePatch)
        $animated_sprites_boot_trace.disable
      end
    end
    $animated_sprites_boot_trace.enable
  end
rescue => e
  AnimatedSpriteOverrides.log_error(e)
end
