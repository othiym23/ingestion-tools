class Album
  attr_accessor :name, :artist_name
  attr_accessor :discs, :number_of_discs
  attr_accessor :genre, :release_date, :compilation, :mixer
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_type, :musicbrainz_album_status, :musicbrainz_album_release_country
  
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
  
  def display_formatted
    encoders = []
    formatted_album = ''

    formatted_album << "[#{release_date}] #{artist_name}: #{name} (#{genre})\n"
    formatted_album << "    Mixed by #{mixer}\n" if mixer
    formatted_album << "\n"

    discs.compact.each do |disc|
      formatted_album << "  Disc #{disc.number}:\n" if discs.compact.size > 1
      disc.tracks.sort { |first,second| first.sequence <=> second.sequence }.each do |track|
        comments =  format_comments(track.comment)
        out = "    #{disc.number}.#{track.sequence}: "
        out << "#{track.artist_name} - " if track.artist_name != artist_name
        out << "#{track.name}\n"
        formatted_album << out
        formatted_album << "                     Featured: #{track.featured_artists.join(', ')}\n" if track.featured_artists.size > 0
        formatted_album << "                        Remix: #{track.remix}\n" if track.remix && track.remix != ''
        formatted_album << "                        Genre: #{track.genre}\n" if track.genre && track.genre != genre
        formatted_album << "                     Comments: [#{comments}]\n" if comments && comments != ''
        formatted_album << "                 Release date: #{track.release_date}\n" if track.release_date && track.release_date != release_date
        formatted_album << "       Musicbrainz track UUID: #{track.unique_id}\n" if track.unique_id && track.unique_id != ''
        formatted_album << "      Musicbrainz artist UUID: #{track.musicbrainz_artist_id}\n" if track.musicbrainz_artist_id && 
                                                                                                track.musicbrainz_artist_id != '' &&
                                                                                                track.musicbrainz_artist_id != musicbrainz_album_artist_id
        encoders << track.encoder if track.encoder.size > 0
      end
    end

    if musicbrainz_album_id || musicbrainz_album_artist_id ||
       musicbrainz_album_type || musicbrainz_album_status
      formatted_album << "\nMusicbrainz album info:\n"
      formatted_album << "        artist UUID: #{musicbrainz_album_artist_id}\n" if musicbrainz_album_artist_id && '' != musicbrainz_album_artist_id
      formatted_album << "         album UUID: #{musicbrainz_album_id}\n" if musicbrainz_album_id
      formatted_album << "    release country: #{musicbrainz_album_release_country}\n" if musicbrainz_album_release_country
      formatted_album << "             status: #{musicbrainz_album_status}\n" if musicbrainz_album_status
      formatted_album << "               type: #{musicbrainz_album_type}\n" if musicbrainz_album_type
    end

    encoders = encoders.flatten.compact.uniq
    raw_encoder = encoders.join("\n           ")
    formatted_album << "\nEncoded by #{raw_encoder}\n\n" if raw_encoder && raw_encoder != ''
    
    formatted_album
  end
  
  private
  
  # TODO: move this into the track class
  def format_comments(comments)
    comment_string = ''
    if Array == comments.class
      consolidated = comments.uniq
      if consolidated.size == 1
        comment_string = consolidated[0]
      else
        comment_string = consolidated.join(', ')
      end
    else
      comment_string = comments if comments && '' != comments
    end
  end
end