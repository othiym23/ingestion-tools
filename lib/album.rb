require 'string_utils'

class Album
  attr_accessor :name, :artist_name
  attr_accessor :discs, :number_of_discs
  attr_accessor :genre, :release_date, :compilation, :mixer
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_type, :musicbrainz_album_status, :musicbrainz_album_release_country
  attr_accessor :sort_order
  
  def initialize
    @discs = []
  end
  
  def number_of_tracks
    @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks }
  end
  
  def number_of_tracks_loaded
    tracks.size
  end
  
  def number_of_discs_loaded
    @discs.compact.size
  end
  
  def tracks
    @discs.compact.collect {|disc| disc.tracks}.flatten
  end
  
  # HEURISTIC: this function serves a VERY SPECIFIC function, which is swapping
  # all the encoder fields for my GRIP-encoded tracks into the encoder field
  # from the comments field, where I stashed them.
  def set_encoder_from_comments!
    start_comment = @discs.compact.first.tracks.first.comment
    if start_comment.is_a? Array
      start_comment = start_comment.uniq.join(' / ')
    end

    if start_comment != nil && start_comment != ''
      consistent = true
      
      @discs.compact.each do |disc|
        disc.tracks.each do |track|
          if track.comment != start_comment
            consistent = false
            break
          end
        end
      end
      
      encoder_list = start_comment.split(' / ').compact.select {|encoder| !(encoder =~ /^\s*$/)}
      if consistent && encoder_list && encoder_list.size > 0
        @discs.compact.each do |disc|
          disc.tracks.each do |track|
            track.comment = nil
            if track.encoder.nil?
              track.encoder = []
            end
            track.encoder << encoder_list
          end
        end
      end
    end
  end
  
  def set_mixer!
    if patterns = @name.match(/^(.*) \([Mm]ixed [Bb]y (.*)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @mixer = patterns[2]
    end
  end

  def find_hidden_soundtrack!
    if patterns = @name.match(/^(.*) OST$/)
      @name = patterns[1]
      @genre = 'Soundtrack'

      discs.compact.each do |disc|
        disc.tracks.each do |track|
          track.genre = 'Soundtrack'
        end
      end
    end
  end
  
  def set_sort_order!
    unless @sort_order && '' != @sort_order
      if match_data = @name.match(/\A(The|A|An) (.+)\Z/)
        @sort_order = ('' << match_data[2] << ', ' << match_data[1])
      end
    end
  end
  
  # HEURISTIC: at some point I may switch to using a more sophisticated
  # title-case naming scheme, but the existing archive uses a simple
  # braindamaged scheme of capitalizing all initial characters in names
  def capitalize_names!
    @artist_name = StringUtils.mixed_case(@artist_name)
    @name = StringUtils.mixed_case(@name)
    @genre = StringUtils.mixed_case(@genre)
    @mixer = StringUtils.mixed_case(@mixer)
  end
  
  def display_formatted(simple = false)
    encoders = []
    formatted_album = ''

    formatted_album << "[#{release_date}] #{artist_name}: #{name} (#{genre})\n"
    formatted_album << "    Mixed by #{mixer}\n" if mixer
    formatted_album << "\n"

    discs.compact.each do |disc|
      formatted_album << "  Disc #{disc.number}:\n" if discs.compact.size > 1
      disc.tracks.sort { |first,second| first.sequence <=> second.sequence }.each do |track|
        out = "    #{disc.number}.#{track.sequence}: "
        out << "#{track.artist_name} - " if track.artist_name != artist_name

        unless simple
          out << "#{track.name}\n"
        else
          out << track.reconstituted_name << "\n"
        end

        formatted_album << out

        if !simple
          comments =  track.format_comments

          track_attributes = []
          track_attributes << ["Featured", track.featured_artists.join(', ')] if track.featured_artists.size > 0
          track_attributes << ["Remix", track.remix] if track.remix && track.remix != ''
          track_attributes << ["Genre", track.genre] if track.genre && track.genre != genre
          track_attributes << ["Comments", comments] if comments && comments != ''
          track_attributes << ["Release date", track.release_date] if track.release_date && track.release_date != release_date
          track_attributes << ["Musicbrainz track UUID", track.unique_id] if track.unique_id && track.unique_id != ''
          track_attributes << ["Musicbrainz artist UUID", track.musicbrainz_artist_id] if track.musicbrainz_artist_id && 
                                                                                                  track.musicbrainz_artist_id != '' &&
                                                                                                  track.musicbrainz_artist_id != musicbrainz_album_artist_id
          formatted_album << justify_attribute_list(track_attributes, 6)

          encoders << track.encoder if track.encoder.size > 0
        end
      end
    end

    if !simple && (musicbrainz_album_id || musicbrainz_album_artist_id ||
                   musicbrainz_album_type || musicbrainz_album_status)
      formatted_album << "\nMusicbrainz album info:\n"
      musicbrainz_attributes = []
      musicbrainz_attributes << ["artist UUID", musicbrainz_album_artist_id] if musicbrainz_album_artist_id && '' != musicbrainz_album_artist_id
      musicbrainz_attributes << ["album UUID", musicbrainz_album_id] if musicbrainz_album_id
      musicbrainz_attributes << ["release country", musicbrainz_album_release_country] if musicbrainz_album_release_country
      musicbrainz_attributes << ["status", musicbrainz_album_status] if musicbrainz_album_status
      musicbrainz_attributes << ["type", musicbrainz_album_type] if musicbrainz_album_type

      formatted_album << justify_attribute_list(musicbrainz_attributes)
    end

    if !simple
      encoders = encoders.flatten.compact.uniq
      raw_encoder = encoders.join("\n           ")
      formatted_album << "\nEncoded by #{raw_encoder}\n\n" if raw_encoder && raw_encoder != ''
    end
    
    formatted_album
  end
  
  private
  
  def justify_attribute_list(list, offset = 4)
    out = ''
    max_width = offset + list.max{|l,r| l[0].length <=> r[0].length}[0].length if list.size > 0
    list.each do |attribute|
      out << (' ' * (max_width - attribute[0].length)) << attribute[0] << ': ' << attribute[1] << "\n"
    end
    out
  end
end