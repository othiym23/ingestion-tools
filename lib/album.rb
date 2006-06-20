require 'string_utils'

class Album
  attr_accessor :name, :subtitle, :version_name, :artist_name
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
    @discs.compact.collect{|disc| disc.tracks}.flatten.sort do |l,r|
      disc_equality = l.disc.number <=> r.disc.number
      disc_equality == 0 ? l.sequence <=> r.sequence : disc_equality
    end
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
            encoder_list.each do |element|
              next if element =~ /engiTunNORM/
              track.encoder << element
            end
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
    @subtitle = StringUtils.mixed_case(@subtitle)
    @genre = StringUtils.mixed_case(@genre)
    @mixer = StringUtils.mixed_case(@mixer)
    @version_name = StringUtils.mixed_case(@version_name)
    @version_name.gsub!(/(\A|\s)(Version|Release)\b/) {|string| string.downcase} if @version_name
  end
  
  # HEURISTIC: sometimes I have multiple versions of records and like to
  # differentiate them by tacking the version name onto the title within
  # square brackets
  def set_version_name!
    if patterns = @name.match(/^(.*) \[(.*)\](.*)$/)
      @name = patterns[1] << patterns[3]
      @version_name = patterns[2]
    end
  end
  
  # HEURISTIC: subtitles follow colons, following certain rules
  def set_subtitle!
    if patterns = @name.match(/\A([^\b:]+): (.+)\Z/)
      @name = patterns[1]
      @subtitle = patterns[2]
    end
  end
  
  def reconstituted_name
    reconstituted = ''
    reconstituted << @name
    reconstituted << ': ' << @subtitle if @subtitle
    reconstituted << ' [' << @version_name << ']' if @version_name
    
    reconstituted
  end
  
  def display_formatted(simple = false)
    encoders = []
    formatted_album = ''

    formatted_album << "[#{release_date}] " if release_date
    unless simple
      formatted_album << "#{artist_name}: #{name}"
    else
      formatted_album << "#{artist_name}: #{reconstituted_name}"
    end
    formatted_album << " (#{genre})" if genre
    formatted_album << "\n"
    unless simple
      album_attributes = []
      album_attributes << ["Subtitle:", subtitle] if subtitle
      album_attributes << ["Album version:", version_name] if version_name
      album_attributes << ["Mixed by:", mixer] if mixer
      formatted_album << justify_attribute_list(album_attributes)
    end
    formatted_album << "\n"

    discs.compact.each do |disc|
      formatted_album << "  Disc #{disc.number}:\n" if discs.compact.size > 1
      disc.tracks.sort { |first,second| first.sequence <=> second.sequence }.each do |track|
        out = '    '
        out << "#{disc.number}." if discs.compact.size > 1
        out << "#{track.sequence}: "
        out << "#{track.artist_name} - " if track.artist_name != artist_name

        unless simple
          out << "#{track.name}\n"
        else
          out << track.reconstituted_name << "\n"
        end

        formatted_album << out

        unless simple
          comments =  track.format_comments

          track_attributes = []
          track_attributes << ["Remix", track.remix] if track.remix && track.remix != ''
          track_attributes << ["Genre", track.genre] if track.genre && track.genre != genre
          track_attributes << ["Artist sort", track.artist_sort_order] if track.artist_sort_order
          track_attributes << ["Sort", track.sort_order] if track.sort_order
          track_attributes << ["Featured", track.featured_artists.join(', ')] if track.featured_artists.size > 0
          track_attributes << ["Image", track.image.mime_type] if track.image
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