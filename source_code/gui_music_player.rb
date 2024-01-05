require 'rubygems'
require 'gosu'

module Genre
  POP, CLASSIC, JAZZ, ROCK = *1..4
end

module ZOrder
  BACKGROUND, UI = *0..1
end

SPACING = 100

GENRE_NAMES = ['Null', 'Pop', 'Classic', 'Jazz', 'Rock']

class Album
  attr_accessor :title, :artist, :tracks, :artwork

  def initialize(title, artist, tracks, artwork)
    @title = title
    @artist = artist
    @tracks = tracks
    @artwork = artwork
  end
end

class Track
  attr_accessor :name, :location

  def initialize(name, location)
    @name = name
    @location = location
  end
end

class MusicPlayerMain < Gosu::Window
  def initialize
    super 800, 600
    self.caption = "Music Player"

    @font = Gosu::Font.new(24)
    @current_album = nil
    @current_track = nil

    @albums = []
    load_albums('albums.txt')

    @visible_albums = 3
    @start_album_index = 0
    @total_albums = @albums.length
    @max_tracks_displayed = 5
    @start_track_index = 0
    @progress = 0.0
    @progress_speed = 0.0001
    @repeat_enabled
  end

  def handle_scroll_left
    @start_album_index -= 1 if @start_album_index.positive?
  end

  def handle_scroll_right
    @start_album_index += 1 if (@start_album_index + @visible_albums) < @total_albums
  end
  def load_albums(filename)
    file = File.open(filename, "r")
    num_albums = file.gets.to_i

    num_albums.times do
      title = file.gets.chomp
      artist = file.gets.chomp
      artwork = file.gets.chomp
      num_tracks = file.gets.to_i

      tracks = []
      num_tracks.times do
        track_name = file.gets.chomp
        track_location = file.gets.chomp
        tracks << Track.new(track_name, track_location)
      end

      album = Album.new(title, artist, tracks, artwork)
      @albums << album
    end

    file.close
  end

  def draw
    draw_albums
    draw_tracks if @current_album
    draw_now_playing
    draw_scroll_buttons
    draw_progress_bar if @song&.playing?
    draw_repeat_button
  end

  def update
    @progress += @progress_speed if @progress < 1.0
    if (@song)
      if !@song.playing? && @repeat_enabled
        play_track(@current_track)
      end
    end
  end



  def toggle_repeat
    @repeat_enabled = !@repeat_enabled
  end



  def arrow_clicked?
    arrow_width = 80
    arrow_height = 80
    arrow_y = 250

    left_arrow_x = 10
    right_arrow_x = 700

    mouse_x.between?(left_arrow_x, left_arrow_x + arrow_width) && mouse_y.between?(arrow_y, arrow_y + arrow_height) ||
      mouse_x.between?(right_arrow_x, right_arrow_x + arrow_width) && mouse_y.between?(arrow_y, arrow_y + arrow_height)
  end

  def handle_arrow_click
    handle_scroll_left if mouse_x < 400
    handle_scroll_right if mouse_x > 400
  end


  def draw_scroll_buttons
    arrow_width = 80
    arrow_height = 80
    arrow_y = 250

    left_arrow_x = 10
    right_arrow_x = 700

    left_arrow = Gosu::Image.new('left_arrow.png')
    right_arrow = Gosu::Image.new('right_arrow.png')

    left_arrow.draw(left_arrow_x, arrow_y, ZOrder::UI, arrow_width.to_f / left_arrow.width, arrow_height.to_f / left_arrow.height)
    right_arrow.draw(right_arrow_x, arrow_y, ZOrder::UI, arrow_width.to_f / right_arrow.width, arrow_height.to_f / right_arrow.height)
  end




  def button_down(id)
    case id
    when Gosu::MsLeft
      handle_mouse_click
      handle_track_selection if @current_album
      handle_arrow_click if arrow_clicked?
      handle_up_arrow_click if up_arrow_clicked?
      handle_down_arrow_click if down_arrow_clicked?
      toggle_repeat if mouse_x.between?(520, 670) && mouse_y.between?(400, 440)
    when Gosu::KB_LEFT
      handle_scroll_left
    when Gosu::KB_RIGHT
      handle_scroll_right
    end
  end

  def draw_repeat_button
    button_width = 150
    button_height = 40
    button_x = 520
    button_y = 400
    if mouse_x.between?(button_x, button_x + button_width) && mouse_y.between?(button_y, button_y + button_height)
      draw_rect(button_x, button_y, button_width, button_height, Gosu::Color::GRAY)
    else
      draw_rect(button_x, button_y, button_width, button_height, Gosu::Color::WHITE)
    end
    repeat_text = @repeat_enabled ? 'Repeat: ON' : 'Repeat: OFF'
    @font.draw_text(repeat_text, button_x + 10, button_y + 10, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
  end

  def draw_now_playing
    x = 300
    y = 300
    album_cover_size = 200

    if @current_track || @last_track_info
      track = @current_track
      album = @albums.find { |a| a.tracks.include?(track) }

      if album
        album_artwork = Gosu::Image.new("images/#{album.artwork}") if File.exist?("images/#{album.artwork}")
        if album_artwork
          scale_x = album_cover_size.to_f / album_artwork.width
          scale_y = album_cover_size.to_f / album_artwork.height

          album_artwork.draw_rot(x + album_cover_size / 2, y + album_cover_size / 2, ZOrder::UI, 0, 0.5, 0.5, scale_x, scale_y)
          @last_album_artwork = album_artwork unless @last_album_artwork == album_artwork
        else
          draw_rect(x, y, album_cover_size, album_cover_size, Gosu::Color::GRAY)
        end

        track_info = "#{track.name}\nArtist: #{album.artist}\nAlbum: #{album.title}"
        @font.draw(track_info, x + album_cover_size + 20, y, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)
        @last_track_info = track_info unless @last_track_info == track_info
      end
    else
      draw_rect(x, y, album_cover_size, album_cover_size, Gosu::Color::GRAY)
      track_info = "Nothing is playing"
      @font.draw(track_info, x + album_cover_size + 20, y, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)
    end

    if !@current_track && @last_track_info
      if @last_album_artwork
        scale_x = album_cover_size.to_f / @last_album_artwork.width
        scale_y = album_cover_size.to_f / @last_album_artwork.height
        @last_album_artwork.draw_rot(x + album_cover_size / 2, y + album_cover_size / 2, ZOrder::UI, 0, 0.5, 0.5, scale_x, scale_y)
      end
      @font.draw(@last_track_info, x + album_cover_size + 20, y, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)
    end
  end


  def draw_albums
    x = 50
    y = 50
    album_width = 150
    album_height = 150
    end_index = [@start_album_index + @visible_albums, @total_albums].min

    (@start_album_index...end_index).each do |index|
      album = @albums[index]

      if mouse_x.between?(x, x + album_width) && mouse_y.between?(y, y + album_height)
        draw_rect(x, y, album_width, album_height, Gosu::Color::GRAY)
      else
        if File.exist?("images/#{album.artwork}")
          album_artwork = Gosu::Image.new("images/#{album.artwork}")
          album_artwork.draw_as_quad(x, y, Gosu::Color::WHITE, x + album_width, y, Gosu::Color::WHITE, x, y + album_height, Gosu::Color::WHITE, x + album_width, y + album_height, Gosu::Color::WHITE, ZOrder::UI)
        else
          draw_rect(x, y, album_width, album_height, Gosu::Color::BLUE)
        end
      end

      @font.draw("#{album.title} - #{album.artist}", x, y + album_height + 10, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)

      x += album_width + SPACING
    end
  end

  def draw_tracks
    x = 50
    y = 400
    track_height = 30

    if @current_album
      @font.draw("Tracks for #{@current_album.title}:", x, y - 50, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)

      visible_tracks = @current_album.tracks.slice(@start_track_index, @max_tracks_displayed)

      visible_tracks.each_with_index do |track, index|
        track_y = y + track_height * index
        if mouse_x.between?(x, x + 200) && mouse_y.between?(track_y, track_y + track_height)
          @font.draw("#{@start_track_index + index + 1}. #{track.name}", x, track_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::GRAY)
        else
          @font.draw("#{@start_track_index + index + 1}. #{track.name}", x, track_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::WHITE)
        end
      end

      draw_track_navigation_buttons if @current_album.tracks.length > @max_tracks_displayed
    end
  end

  def draw_progress_bar
    bar_width = 400
    bar_height = 20
    bar_x = 300
    bar_y = 550

    filled_width = (@progress * bar_width).to_i

    draw_rect(bar_x, bar_y, bar_width, bar_height, Gosu::Color::GRAY)
    draw_rect(bar_x, bar_y, filled_width, bar_height, Gosu::Color::GREEN)
  end


  def draw_track_navigation_buttons
    x = 130
    y = 350
    button_width = 35
    button_height = 35

    up_arrow = Gosu::Image.new('up_arrow.png')
    down_arrow = Gosu::Image.new('down_arrow.png')

    if @current_album.tracks.length > @max_tracks_displayed
      up_arrow.draw(x, y - button_height - 10, ZOrder::UI, button_width.to_f / up_arrow.width, button_height.to_f / up_arrow.height)
      down_arrow.draw(x, y + @max_tracks_displayed * 30 + 50, ZOrder::UI, button_width.to_f / down_arrow.width, button_height.to_f / down_arrow.height)
    end
  end

  def handle_up_arrow_click
    @start_track_index -= 1 if @start_track_index.positive?
  end

  def handle_down_arrow_click
    @start_track_index += 1 if (@start_track_index + @max_tracks_displayed) < @current_album.tracks.length
  end



  def needs_cursor?
    true
  end


  def up_arrow_clicked?
    button_width = 35
    button_height = 35
    x = 130
    y = 350 - button_width - 10

    mouse_x.between?(x, x + button_width) && mouse_y.between?(y, y + button_height)
  end

  def down_arrow_clicked?
    x = 130
    y = 350 + @max_tracks_displayed * 30 + 50
    button_width = 35
    button_height = 35

    mouse_x.between?(x, x + button_width) && mouse_y.between?(y, y + button_height)
  end


  def handle_mouse_click
    x = 50
    y = 50
    album_width = 150
    album_height = 150
    end_index = [@start_album_index + @visible_albums, @total_albums].min

    (@start_album_index...end_index).each do |index|
      if mouse_x.between?(x, x + album_width) && mouse_y.between?(y, y + album_height)
        @current_album = @albums[index]
        @current_track = nil
        break
      end

      x += album_width + SPACING
    end
  end



  def handle_track_selection
    return unless @current_album

    x = 50
    y = 400
    track_height = 30

    visible_tracks = @current_album.tracks.slice(@start_track_index, @max_tracks_displayed)

    visible_tracks.each_with_index do |_track, index|
      track_y = y + track_height * index

      if mouse_x.between?(x, x + 200) && mouse_y.between?(track_y, track_y + track_height)
        actual_track_index = @start_track_index + index

        if actual_track_index < @current_album.tracks.length
          @current_track = @current_album.tracks[actual_track_index]
          play_track(@current_track)
          break
        end
      end
    end
  end



  def play_track(track)
    return unless track

    @song.stop if @song&.playing?

    @progress = 0.0

    @song = Gosu::Song.new(track.location)
    @song.play(false)
  end
end

MusicPlayerMain.new.show if __FILE__ == $0

