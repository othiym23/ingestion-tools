require 'string_utils'

class Album
  attr_accessor :name, :subtitle, :version_name, :artist_name
  attr_accessor :discs, :number_of_discs
  attr_accessor :genre, :release_date, :modification_date, :compilation, :mixer
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_type, :musicbrainz_album_status, :musicbrainz_album_release_country
  attr_accessor :sort_order, :artist_sort_order
  attr_accessor :non_media_files
  
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
  
  def track(disc_number, track_number)
    if @discs[disc_number]
      unsorted_tracks = @discs[disc_number].tracks
      if track_number <= unsorted_tracks.size
        sorted_tracks = unsorted_tracks.sort do |l,r|
          l.sequence <=> r.sequence
        end

        sorted_tracks[track_number - 1]
      end
    end
  end
  
  def genre=(new_genre)
    tracks.each do |track|
      track.genre = new_genre if track.genre == genre
    end
    @genre = new_genre
  end
  
  def artist_name=(new_artist_name)
    tracks.each do |track|
      track.artist_name = new_artist_name if track.artist_name == artist_name
    end
    @artist_name = new_artist_name
  end
  
  def release_date=(new_release_date)
    tracks.each do |track|
      track.release_date = new_release_date if track.release_date == release_date
    end
    @release_date = new_release_date
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
    
    unless @artist_sort_order && '' != @artist_sort_order
      if match_data = @artist_name.match(/\A(The|A|An) (.+)\Z/)
        @artist_sort_order = (match_data[2] << ', ' << match_data[1])
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
    reconstituted << (@name || '<untitled>')
    reconstituted << ': ' << @subtitle if @subtitle
    reconstituted << ' (mixed by ' << @mixer << ')' if @mixer
    reconstituted << ' [' << @version_name << ']' if @version_name
    
    reconstituted
  end

  def display_name
    formatted_album = "#{artist_name}: #{reconstituted_name}"
    formatted_album << " (#{genre})" if genre && '' != genre
    formatted_album << " [#{release_date}]" if release_date && '' != release_date
    formatted_album
  end

  def encoders
    encoder_strings = []

    discs.compact.each do |disc|
      disc.tracks.each do |track|
        encoder_strings << track.encoder if track.encoder && track.encoder.size > 0
      end
    end
    
    encoder_strings.flatten.compact.uniq
  end

  def display_formatted(simple = false, omit = true)
    formatted_album = ''

    formatted_album << album_header_formatted(simple, omit)

    discs.compact.each do |disc|
      formatted_album << "  Disc #{disc.number}:\n" if discs.compact.size > 1
      disc.tracks.sort { |first,second| first.sequence <=> second.sequence }.each do |track|
        formatted_album << track.display_formatted(simple, omit)
      end
    end

    formatted_album << musicbrainz_info_formatted(simple, omit)

    if !simple
      raw_encoder = encoders.join("\n           ")
      formatted_album << "\nEncoded by #{raw_encoder}\n\n" if raw_encoder && raw_encoder != ''
    end
    
    formatted_album
  end
  
  def album_header_formatted(simple = false, omit = true)
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
      album_attributes << ["Year of release", "''"] if !release_date && !omit
      album_attributes << ["Genre", "''"] if !genre && !omit
      album_attributes << ["Album sort", sort_order || "''"] if (sort_order && sort_order != '') || !omit
      album_attributes << ["Artist sort", artist_sort_order || "''"] if (artist_sort_order && artist_sort_order != '') || !omit
      album_attributes << ["Subtitle", subtitle || "''"] if (subtitle && subtitle != '') || !omit
      album_attributes << ["Album version", version_name || "''"] if (version_name && version_name != '') || !omit
      album_attributes << ["Mixed by", mixer || "''"] if (mixer && mixer != '') || !omit

      formatted_album << StringUtils.justify_attribute_list(album_attributes)
    end

    formatted_album << "\n"
    formatted_album
  end
  
  def musicbrainz_info_formatted(simple = false, omit = true)
    formatted_musicbrainz_info = ''
    
    if !simple && ((musicbrainz_album_id && '' != musicbrainz_album_id) ||
                    (musicbrainz_album_artist_id && '' != musicbrainz_album_artist_id) ||
                    (musicbrainz_album_type && '' != musicbrainz_album_type) ||
                    (musicbrainz_album_status && '' != musicbrainz_album_status))
      formatted_musicbrainz_info << "Musicbrainz album info:\n"
      
      musicbrainz_attributes = []
      musicbrainz_attributes << ["artist UUID", musicbrainz_album_artist_id || "''"] if (musicbrainz_album_artist_id && '' != musicbrainz_album_artist_id) || !omit
      musicbrainz_attributes << ["album UUID", musicbrainz_album_id || "''"] if (musicbrainz_album_id && '' != musicbrainz_album_id) || !omit
      musicbrainz_attributes << ["release country", musicbrainz_album_release_country || "''"] if (musicbrainz_album_release_country && '' != musicbrainz_album_release_country) || !omit
      musicbrainz_attributes << ["status", musicbrainz_album_status || "''"] if (musicbrainz_album_status && '' != musicbrainz_album_status) || !omit
      musicbrainz_attributes << ["type", musicbrainz_album_type || "''"] if (musicbrainz_album_type && '' != musicbrainz_album_type) || !omit
      
      formatted_musicbrainz_info << StringUtils.justify_attribute_list(musicbrainz_attributes)
    end
    
    formatted_musicbrainz_info
  end
end