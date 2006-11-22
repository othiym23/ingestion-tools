require 'singleton'
require 'yaml'

require 'ui/album_selection_model'

class IllegalStateError < StandardError; end

class ControllerState
  include Singleton
  attr_writer :model, :context, :control, :status, :logger
  
  def ControllerState.default
    default_instance = instance
    default_instance.model = self.model
    default_instance.context = self.context
    default_instance.control = self.control
    default_instance.status = self.status
    default_instance.logger = self.logger
    
    default_instance
  end
  
  def enter
    @logger.warn("[#{self.class.name}] abstract method 'enter' called")
  end
  
  def exit
    @logger.warn("[#{self.class.name}] abstract method 'exit' called")
  end
  
  def update
    @logger.warn("[#{self.class.name}] abstract method 'update' called")
  end
  
  protected
  
  def self.context
    @@context
  end
  
  def self.context=(new_context)
    @@context = new_context
  end
  
  def self.model
    @@model
  end
  
  def self.model=(new_model)
    @@model = new_model
  end
  
  def self.status
    @@status
  end
  
  def self.status=(new_status)
    @@status = new_status
  end
  
  def self.control
    @@control
  end
  
  def self.control=(new_control)
    @@control = new_control
  end
  
  def self.logger
    @@logger
  end
  
  def self.logger=(new_logger)
    @@logger = new_logger
  end
  
  def pass_the_buck(key)
    @status.message = ''
    @context.addmessage @context.parent, :keypress, key 
  end
end

class AlbumMusicBrainzEditState < ControllerState
  def AlbumMusicBrainzEditState.state_name
    'Edit album-level MusicBrainz metadata'
  end
  
  def prompt_string
    'album [i]d a[r]tist id | release [t]ype [s]tatus [c]ountry | [b]ack: '
  end
  
  def enter
    unless @model.selected
      raise IllegalStateError.new("#{self.class.name} requires an album be selected")
    end
    
    @status.message = 'WARNING: populating this data by hand isn\'t a good idea. Use the matcher.'
    @album_info_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @album_info_pane.visible = false
  end
  
  def update
    @album_info_pane.list = @model.selected.musicbrainz_info_formatted(false, false).split("\n")
    @album_info_pane.update
    @album_info_pane.visible = true unless @album_info_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'i'
      get_musicbrainz_album_id
    when 'r'
      get_musicbrainz_album_artist_id
    when 't'
      get_musicbrainz_album_release_type
    when 's'
      get_musicbrainz_album_release_status
    when 'c'
      get_musicbrainz_album_release_country
    when 'b', 'Q', 'q'
      @context.change_state(EditState)
    else
      @album_info_pane.keypress(key)
    end
  end

  def get_musicbrainz_album_id
    @control.prompt_with_callback('Edit MusicBrainz album metadata', 'MusicBrainz album id: ', @model.selected.musicbrainz_album_id) do |input|
      @model.selected.musicbrainz_album_id = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_musicbrainz_album_artist_id
    @control.prompt_with_callback('Edit MusicBrainz album metadata', 'MusicBrainz album artist id: ', @model.selected.musicbrainz_album_artist_id) do |input|
      @model.selected.musicbrainz_album_artist_id = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_musicbrainz_album_release_type
    @status.message = 'Valid values are "album", "single", "live", "e.p."'
    @control.prompt_with_callback('Edit MusicBrainz album metadata', 'MusicBrainz album release type: ', @model.selected.musicbrainz_album_type) do |input|
      @model.selected.musicbrainz_album_type = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_musicbrainz_album_release_status
    @status.message = 'Valid values are "official", "promotional", or "bootleg"'
    @control.prompt_with_callback('Edit MusicBrainz album metadata', 'MusicBrainz album release status: ', @model.selected.musicbrainz_album_status) do |input|
      @model.selected.musicbrainz_album_status = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_musicbrainz_album_release_country
    @status.message = 'Use two-character ISO country codes (US, UK, JP, DE)'
    @control.prompt_with_callback('Edit MusicBrainz album metadata', 'MusicBrainz album release country: ', @model.selected.musicbrainz_album_release_country) do |input|
      @model.selected.musicbrainz_album_release_country = ('' == input ? nil : input.upcase)
      @context.update
    end
  end
end

class AlbumMetadataEditState < ControllerState
  def AlbumMetadataEditState.state_name
    'Edit album-level metadata'
  end
  
  def prompt_string
    '[n]ame [s]ort [a]rtist ([S]ort) [y]ear [g]enre [c]omp? [m]ixed by sub[t]itle [v]ersion [M]usicBrainz [b]ack: '
  end
  
  def enter
    unless @model.selected
      raise IllegalStateError.new("#{self.class.name} requires an album be selected")
    end
    
    @album_info_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @album_info_pane.visible = false
  end
  
  def update
    @album_info_pane.list = @model.selected.album_header_formatted(false, false).split("\n")
    @album_info_pane.update
    @album_info_pane.visible = true unless @album_info_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'n'
      get_album_name
    when 's'
      get_album_sort_order
    when 'a'
      get_album_artist_name
    when 'S'
      get_album_artist_sort_order
    when 'y'
      get_album_release_year
    when 'g'
      get_album_genre
    when 'm'
      get_album_mixed_by
    when 'c'
      toggle_album_compilation
    when 't'
      get_album_subtitle
    when 'v'
      get_album_version
    when 'b', 'Q', 'q'
      @context.change_state(EditState)
    when 'M'
      @context.change_state(AlbumMusicBrainzEditState)
    else
      @album_info_pane.keypress(key)
    end
  end

  def get_album_name
    @status.message = ''
    @control.prompt_with_callback('Edit album metadata', 'album name: ', @model.selected.name) do |input|
      @model.selected.name = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_sort_order
    @status.message = ''
    @control.prompt_with_callback('Edit album metadata', 'sort name: ', @model.selected.sort_order) do |input|
      @model.selected.sort_order = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_subtitle
    @status.message = 'Only some albums have subtitles, generally following colons'
    @control.prompt_with_callback('Edit album metadata', 'subtitle: ', @model.selected.subtitle) do |input|
      @model.selected.subtitle = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_version
    @status.message = 'Use the album version to disambiguate between independent releases'
    @control.prompt_with_callback('Edit album metadata', 'version: ', @model.selected.version_name) do |input|
      @model.selected.version_name = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_genre
    @status.message = 'Automatically propagate the album\'s genre out to the tracks'
    @control.prompt_with_callback('Edit album metadata', 'genre: ', @model.selected.genre) do |input|
      @model.selected.genre = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_artist_name
    @status.message = ''
    @control.prompt_with_callback('Edit album metadata', 'artist name: ', @model.selected.artist_name) do |input|
      @model.selected.artist_name = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_artist_sort_order
    @status.message = ''
    @control.prompt_with_callback('Edit album metadata', 'artist sort name: ', @model.selected.artist_sort_order) do |input|
      @model.selected.artist_sort_order = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_mixed_by
    @status.message = 'Reserve this attribute for continuous mixes.'
    @control.prompt_with_callback('Edit album metadata', 'mixed by: ', @model.selected.mixer) do |input|
      @model.selected.mixer = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_album_release_year
    @status.message = ''
    @control.prompt_with_callback('Edit album metadata', 'album release year: ', @model.selected.release_date) do |input|
      @model.selected.release_date = ('' == input ? nil : input)
      @context.update
    end
  end
  
  def toggle_album_compilation
    if @model.selected.compilation
      @model.selected.compilation = !@model.selected.compilation
      @status.message = 'album was compilation, but now it\'s not'
    else
      @model.selected.compilation = !@model.selected.compilation
      @status.message = 'album wasn\'t a compilation, but now it is'
    end
  end
end

class AlbumYAMLState < ControllerState
  def AlbumYAMLState.state_name
    'View YAML'
  end
  
  def prompt_string
    '[e]dit metadata [h]ide YAML [b]ack: '
  end
  
  def enter
    unless @model.selected
      raise IllegalStateError.new("#{self.class.name} requires an album be selected")
    end
    
    @yaml_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @yaml_pane.visible = false
  end
  
  def update
    @yaml_pane.list = YAML.dump(content).split("\n")
    @yaml_pane.update
    @yaml_pane.visible = true unless @yaml_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'e'
      @status.message = ''
      edit
    when 'h'
      hide
    when 'b', 'Q', 'q'
      prev_mode
    else
      @yaml_pane.keypress(key)
    end
  end
  
  def edit
    @context.change_state(AlbumMetadataEditState)
  end
  
  def hide
    @status.message = ''
    @context.change_state(EditState)
  end
  
  def content
    @model.selected
  end
  
  def prev_mode
    @status.message = "Done with '#{@model.selected.reconstituted_name}'!"
    @model.selected = nil

    if @model.list && @model.list.size > 0
      @context.change_state(BrowseState)
    else
      @context.change_state(StartState)
    end
  end
end

class EncoderListEditState < ControllerState
  def EncoderListEditState.state_name
    'Edit encoder list'
  end
  
  def prompt_string
    '[a]dd [d]elete [b]ack: '
  end
  
  def enter
    unless @model.selected
      raise IllegalStateError.new("#{self.class.name} requires an album be selected")
    end
    
    @encoder_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @encoder_pane.visible = false
  end
  
  def update
    @encoder_pane.list = @model.selected.encoders
    @encoder_pane.update
    @encoder_pane.visible = true unless @encoder_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'a'
      add_encoder
    when 'd'
      @status.message = ''
      delete_encoder
    when 'b', 'Q', 'q'
      @context.change_state(EditState)
    else
      @yaml_pane.keypress(key)
    end
  end
  
  private
  
  def add_encoder
    @status.message = ''
    @control.prompt_with_callback('Edit encoder list', 'New encoder: ', '::AOAIOXXYSZ:: music archive services, v1') do |input|
      @model.selected.tracks.each {|track| track.encoder ||= []; track.encoder += [input] }
      @context.update
    end
  end
  
  def delete_encoder
    @status.message = ''
    @control.prompt_with_callback('Edit encoder list', '# to delete: ', 1.to_s) do |input|
      encoder_number = input.to_i
      encoder_list = @model.selected.encoders
      if encoder_number > 0 && encoder_number <= encoder_list.size
        deleted_string = encoder_list[encoder_number - 1]
        @model.selected.tracks.each {|track| track.encoder -= [deleted_string] if track.encoder }
      end
      @context.update
    end
  end
end

class TrackYAMLState < AlbumYAMLState
  def enter(track)
    unless track
      raise IllegalStateError.new("#{self.class.name} requires a track be selected")
    end
    
    @selected_track = track

    @yaml_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def content
    @selected_track
  end
  
  def hide
    edit
  end

  def edit
    @status.message = ''
    @context.change_state(TrackMetadataEditState, @selected_track)
  end
  
  def prev_mode
    @status.message = "Done viewing YAML for '#{@selected_track.reconstituted_name}'!"
    @context.change_state(EditState)
  end
end

class TrackMetadataEditState < ControllerState
  def TrackMetadataEditState.state_name
    'Edit track-level metadata'
  end
  
  def prompt_string
    '[#] [n]ame [s]ort [a]rtist ([S]ort) [r]emix [g]enre [y]ear [f]eat. [c]omment [M]usicBrainz ([Y]AML) [b]ack: '
  end
  
  def enter(track)
    unless track
      raise IllegalStateError.new("#{self.class.name} requires a track be selected")
    end
    
    @selected_track = track
    
    @track_info_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @track_info_pane.visible = false
  end
  
  def update
    @track_info_pane.list = @selected_track.display_formatted(false, false).split("\n")
    @track_info_pane.update
    @track_info_pane.visible = true unless @track_info_pane.visible
  end
  
  def dispatch(key)
    case key
    when '#'
      get_track_sequence
    when 'n'
      get_track_name
    when 's'
      get_track_sort_order
    when 'a'
      get_track_artist_name
    when 'S'
      get_track_artist_sort_order
    when 'y'
      get_track_release_year
    when 'g'
      get_track_genre
    when 'r'
      get_track_remix_name
    when 'c'
      get_track_comment
    when 'f'
      @context.change_state(FeaturedEditState, @selected_track)
    when 'b', 'Q', 'q'
      @status.message = "Done with track '#{@selected_track.name}'!"
      @context.change_state(EditState)
    when 'M'
      @context.change_state(TrackMusicBrainzEditState, @selected_track)
    when 'Y'
      @context.change_state(TrackYAMLState, @selected_track)
    else
      @track_info_pane.keypress(key)
    end
  end

  def get_track_sequence
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'sequence #: ', @selected_track.sequence.to_s) do |input|
      @selected_track.sequence = ('' == input ? 0 : input.to_i)
      @context.update
    end
  end

  def get_track_name
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'name: ', @selected_track.name) do |input|
      @selected_track.name = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_track_sort_order
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'sort name: ', @selected_track.sort_order) do |input|
      @selected_track.sort_order = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_track_release_year
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'artist sort name: ', @selected_track.release_date.to_s) do |input|
      @selected_track.release_date = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_track_artist_name
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'artist name: ', @selected_track.artist_name) do |input|
      @selected_track.artist_name = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_track_artist_sort_order
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'artist sort name: ', @selected_track.artist_sort_order) do |input|
      @selected_track.artist_sort_order = ('' == input ? nil : input)
      @context.update
    end
  end
  
  def get_track_genre
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'genre: ', @selected_track.genre) do |input|
      @selected_track.genre = ('' == input ? nil : input)
      @context.update
    end
  end
  
  def get_track_remix_name
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'remix: ', @selected_track.remix) do |input|
      @selected_track.remix = ('' == input ? nil : input)
      @context.update
    end
  end
  
  def get_track_comment
    @status.message = ''
    @control.prompt_with_callback('Edit track metadata', 'comment: ', @selected_track.format_comments) do |input|
      @selected_track.comment = ('' == input ? nil : input)
      @context.update
    end
  end
end

class TrackMusicBrainzEditState < ControllerState
  def TrackMusicBrainzEditState.state_name
    'Edit track-level MusicBrainz metadata'
  end
  
  def prompt_string
    'track [i]d a[r]tist id [b]ack: '
  end
  
  def enter(track)
    unless track
      raise IllegalStateError.new("#{self.class.name} requires an album be selected")
    end
    
    @selected_track = track
    
    @status.message = 'WARNING: populating this data by hand isn\'t a good idea. Use the matcher.'
    @track_info_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @track_info_pane.visible = false
  end
  
  def update
    @track_info_pane.list = @selected_track.musicbrainz_info_formatted.split("\n")
    @track_info_pane.update
    @track_info_pane.visible = true unless @track_info_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'i'
      get_musicbrainz_track_id
    when 'r'
      get_musicbrainz_track_artist_id
    when 'b', 'Q', 'q'
      @context.change_state(TrackMetadataEditState, @selected_track)
    else
      @track_info_pane.keypress(key)
    end
  end

  def get_musicbrainz_track_id
    @control.prompt_with_callback('Edit MusicBrainz track metadata', 'MusicBrainz track id: ', @selected_track.unique_id) do |input|
      @selected_track.unique_id = ('' == input ? nil : input)
      @context.update
    end
  end

  def get_musicbrainz_track_artist_id
    @control.prompt_with_callback('Edit MusicBrainz track metadata', 'MusicBrainz track artist id: ', @selected_track.musicbrainz_artist_id) do |input|
      @selected_track.musicbrainz_artist_id = ('' == input ? nil : input)
      @context.update
    end
  end
end

class FeaturedEditState < ControllerState
  def FeaturedEditState.state_name
    'Edit track featured artists'
  end
  
  def prompt_string
    '[a]dd [d]elete [e]dit featured artists [b]ack: '
  end
  
  def enter(track)
    unless track
      raise IllegalStateError.new("#{self.class.name} requires a track to be selected")
    end
    
    @selected_track = track
    
    @featured_pane = @context.get_panel(GenericList)
    @context.set_active
  end
  
  def exit
    @featured_pane.visible = false if @featured_pane
  end
  
  def update
    @featured_pane.content_list = @selected_track.featured_artists
    @featured_pane.update
    @featured_pane.visible = true unless @featured_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'a'
      add_item
    when 'd'
      @status.message = "Deleted #{current_item}"
      @selected_track.featured_artists -= [current_item]
      update
    when 'e', 'C-j', 'C-m'
      edit_item
    when 'b', 'Q', 'q'
      @status.message = 'back to finding albums!'
      @context.change_state(TrackMetadataEditState, @selected_track)
    when ('0'..'9')
      get_line_jump(key)
    else
      @featured_pane.keypress(key)
    end
  end
  
  def current_item
    @featured_pane.current_item
  end
  
  private
  
  def add_item
    @control.prompt_with_callback('Add featured artist', 'new artist: ', '') do |selected|
      @selected_track.featured_artists << selected
      @context.update
    end
  end

  def edit_item
    @control.prompt_with_callback('Edit featured artist', 'artist: ', current_item) do |selected|
      @context.update
    end
  end

  def get_line_jump(key)
    @control.prompt_with_callback('Jump to line', 'line to jump to: ', key) do |selected|
      @featured_pane.focusedentry = selected.to_i - 1
      @context.update
    end
  end
end

class EditState < ControllerState
  def EditState.state_name
    'Album information'
  end
  
  def prompt_string
    'edit [a]lbum, [t]rack or [e]ncoder list, match in [M]usicBrainz, or [A]rchive (get [Y]AML dump) [b]ack: '
  end
  
  def enter
    unless @model.selected
      raise IllegalStateError.new("#{self.class.name} requires an album be selected")
    end
    
    @status.message = "Displaying #{@model.selected.artist_name} - #{@model.selected.reconstituted_name}"
    @album_info_pane = @context.get_panel(FLNSlidingTextReader)
    @context.set_active
  end
  
  def exit
    @album_info_pane.visible = false
  end
  
  def update
    if @model.selected
      @album_info_pane.list = @model.selected.display_formatted(false).split("\n")
      @album_info_pane.update
      @album_info_pane.visible = true unless @album_info_pane.visible
    end
  end
  
  def dispatch(key)
    case key
    when 'a'
      @status.message = ''
      @context.change_state(AlbumMetadataEditState)
    when 'e'
      @status.message = ''
      @context.change_state(EncoderListEditState)
    when 'C'
      @model.selected.tracks.each {|track| track.comment = nil}
      update
    when 'I'
      @model.selected.tracks.each {|track| track.image = nil}
      update
    when 't'
      get_track_to_edit
    when 'Y'
      @status.message = ''
      @context.change_state(AlbumYAMLState)
    when 'M'
      @status.message = 'Matching in MusicBrainz (which might take a while...)'

      candidates = MusicBrainz::MatcherDao.find_album_matches(@model.selected)
      if 1 == candidates.size
        match = candidates.first
        @status.message = "Successful match found against '#{match.artist.name} - #{match.name}'!"
        @status.message = "Populating MusicBrainz metadata for '#{match.artist.name} - #{match.name}'!"
        MusicBrainz::MatcherDao.populate_album_from_match(@model.selected, match)
        @status.message = "MusicBrainz metadata populated."
        update
      elsif 0 == candidates.size
        @status.message = "No matches found! TODO: Plan B goes here."
      else
        @status.message = "Uh-oh, #{candidates.size} matches found. Choosing one!"
        candidate = candidates.detect{|candidate| candidate.release_dates && candidate.release_dates.detect {|date| date['country'] && date['country'] == 'US'}} || candidates.first
        MusicBrainz::MatcherDao.populate_album_from_match(@model.selected, candidate)
        update
      end
    when 'A', 'S'
      @status.message = "Validating '#{@model.selected.reconstituted_name}' to archive"
      @status.message = validate_album(@model.selected)
    when 'b', 'Q', 'q'
      @status.message = "Done with '#{@model.selected.reconstituted_name}'!"
      @model.selected = nil
      
      if @model.list && @model.list.size > 0
        @context.change_state(BrowseState)
      else
        @context.change_state(StartState)
      end
    when ('0'..'9')
      get_track_to_edit(key)
    else
      @album_info_pane.keypress(key)
    end
  end

  def get_track_to_edit(initial_string = '')
    @status.message = 'Enter the track to edit as disc.track (disc number is optional)'
    @control.prompt_with_callback('Choose track to edit', 'disc.track: ', initial_string) do |input|
      disc_number, track_number = input.split('.')
      if nil == track_number
        track_number = disc_number.to_i
        disc_number = 1
      else
        track_number = track_number.to_i
        disc_number = disc_number.to_i
      end
      
      track = @model.selected.track(disc_number, track_number)
      if track
        @status.message = "Editing metadata for '#{track.reconstituted_name}'"
        @context.change_state(TrackMetadataEditState, track)
      else
        @status.message = 'Invalid track!'
        @context.update
      end
    end
  end
  
  def validate_album(album)
    validation_message = nil
    album_genre = Netjuke::GenreDao.find_genre(album.genre)
    unless album_genre
      @control.prompt_with_callback('Validation check failed', 'Genre not found. Override? ', 'n') do |input|
        unless input == 'y'
          validation_message = "'#{album.genre}' isn't one of the current genres in Netjuke."
        else
          archive_album(@model.selected)

          if @model.list && @model.list.size > 0
            @context.change_state(BrowseState)
          else
            @context.change_state(StartState)
          end
          @model.total = Euterpe::Dashboard::Album.count
        end
      end
    else
      archive_album(@model.selected)

      if @model.list && @model.list.size > 0
        @context.change_state(BrowseState)
      else
        @context.change_state(StartState)
      end
      @model.total = Euterpe::Dashboard::Album.count
    end
    
    @context.update
    validation_message
  end
  
  def archive_album(album)
    @status.message = "Archiving #{album.reconstituted_name}..."
    album_dao = AlbumDao.new(ARCHIVE_BASE)
    warnings = album_dao.archive_album(album)
    if warnings
      @status.message = warnings.join(', ')
    else
      @status.message = "HOLY SHIT! Archiving completed without warnings!"
    end
    AlbumDao.purge(album)
    
    @model.selected = nil
    @model.list = @model.list - [album] if @model.list
  end
end

class BrowseState < ControllerState
  def BrowseState.state_name
    'Choose album'
  end
  
  def prompt_string
    if @model.list != @model.narrowed_list
      @logger.info("original album list is [#{@model.list}] and current list is [#{@model.narrowed_list}]")
      '[n]arrow results ([c]lear narrowing) [j]oin albums [p]rocess highlighted album [b]ack: '
    else
      '[n]arrow results [j]oin albums [p]rocess highlighted album [b]ack: '
    end
  end
  
  def enter
    unless @model.narrowed_list
      raise IllegalStateError.new("#{self.class.name} requires a list of albums be available")
    end
    
    @chooser_pane = @context.get_panel(AlbumList)
    @context.set_active
  end
  
  def exit
    @chooser_pane.visible = false if @chooser_pane
  end
  
  def update
    @chooser_pane.album_list = @model.narrowed_list
    @chooser_pane.update
    @chooser_pane.visible = true unless @chooser_pane.visible
  end
  
  def dispatch(key)
    case key
    when 'n'
      get_additional_term
    when 'c'
      @model.clear_narrowing!
      @status.message = "narrowing cleared"
    when 'j'
      join_albums
    when 'p', 'e', 'C-j', 'C-m'
      @status.message = "selected #{current_album.artist_name} - #{current_album.reconstituted_name} for processing"
      @model.selected = current_album
      @context.change_state(EditState)
    when 'b', 'Q', 'q'
      @status.message = 'back to finding albums!'
      @context.change_state(StartState)
    when ('0'..'9')
      get_line_jump(key)
    else
      @chooser_pane.keypress(key)
    end
  end
  
  def current_album
    @chooser_pane.current_album
  end
  
  private
  
  def get_additional_term
    @control.prompt_with_callback('Narrow search', 'additional term: ', '') do |term|
      @model.narrow(term)
      if @model.selected
        @context.change_state(EditState)
      else
        @context.update
      end
    end
  end

  def get_line_jump(key)
    @control.prompt_with_callback('Jump to line', 'line to jump to: ', key) do |selected|
      @chooser_pane.focusedentry = selected.to_i - 1
      @context.update
    end
  end
  
  def join_albums
    @control.prompt_with_callback('Join two albums', 'master,subject: ', '') do |selected|
      master_index, subject_index = selected.split(',').collect{|string| string.to_i}
      master = nil
      subject = nil

      if master_index > 0 && master_index <= @model.list.size
        master = @model.list[master_index - 1]
      end

      if subject_index > 0 && subject_index <= @model.list.size
        subject = @model.list[subject_index - 1]
      end

      @status.message = "Merging #{subject.reconstituted_name} into #{master.reconstituted_name}..." if subject

      unless master && subject
        @status.message = 'Unable to merge because of invalid choice.'
        @context.update
        return
      end
      
      new_master = AlbumDao.merge_albums(master, subject)
      @status.message = "Merge successful!"
      @model.list -= [subject]
      @model.list -= [master]
      @model.list += [new_master]
      @context.update
    end
  end
end

class StartState < ControllerState
  def StartState.state_name
    'Top level'
  end
  
  def prompt_string
    '[f]ind albums [r]andom album [m]ost recent album [q]uit: '
  end
  
  def enter
    @model.reset_list! if @model.list
  end
  
  def dispatch(key)
    case key
    when 'f', '/'
      get_albums
    when 'r'
      random = @context.album_loader.choose_randomly
      if random
        @status.message = "#{random.artist_name} - #{random.reconstituted_name} chosen at random for processing"
        @model.selected = random
        @context.change_state(EditState)
      else
        @status.message = "No random albums found -- wait for next ingestion run!"
      end
    when 'm'
      recent = @context.album_loader.choose_most_recent
      if recent
        @status.message = "#{recent.artist_name} - #{recent.reconstituted_name} is the most recently added album"
        @model.selected = recent
        @context.change_state(EditState)
      else
        @status.message = "No recent albums found -- wait for next ingestion run!"
      end
    when 'Q', 'q'
      @status.message = ''
      @context.addmessage nil, :quitloop, key
    else
      pass_the_buck(key)
    end
  end
  
  private
  
  def get_albums
    @status.message = ''
    @control.prompt_with_callback('Find albums', 'cached metadata search: ', '') do |query|
      @status.message = "searching Euterpe metadata cache for albums mentioning '#{query}'..."

      start_time = Time.now
      query.chomp!
      @model.narrow(query)
      finish_time = Time.now

      time = finish_time - start_time

      found_albums = @model.narrowed_list || [@model.selected] || []
      case found_albums.size
      when 0
        @status.message = "no results (query ran in #{time.to_f} seconds)"
      when 1
        @status.message = "single album found in #{time.to_f} seconds"
        @model.selected = found_albums.first
        @context.change_state(EditState)
        @logger.debug("SearchMode.find_albums found '#{found_albums.first.name}'")
      else
        @status.message = "#{found_albums.size} records found in #{time.to_f} seconds"
        @context.change_state(BrowseState)
        @logger.debug("SearchMode.find_albums found [#{@model.list.map{|album| album.name}.join(', ')}]")
      end
    end
  end
end
