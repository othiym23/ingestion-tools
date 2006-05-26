class Album
  attr_accessor :name, :artist_name
  attr_accessor :discs, :number_of_discs
  attr_accessor :genre, :release_date, :compilation, :mixer
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_type, :musicbrainz_album_status
  
  def initialize
    @discs = []
  end
  
  def number_of_tracks
    @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks }
  end
  
  def number_of_tracks_loaded
    @discs.compact.inject(0) { |sum, disc| sum + disc.number_of_tracks_loaded }
  end
  
  def number_of_discs_loaded
    @discs.compact.size
  end
  
  # this function serves a VERY SPECIFIC function, which is swapping all the
  # encoder fields for my GRIP-encoded tracks into the encoder field from thhe
  # comments field where I stashed them.
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
end