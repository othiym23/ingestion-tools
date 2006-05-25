$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../../mp3info/lib')))

require 'mp3info'

# set of classes meant to encapsulate metainformation in data transfer
# objects about digitally-encoded tracks
class TrackMetadata
  attr_accessor :artist_name, :album_name, :track_name, :full_path
  
  def initialize(full_path)
    @full_path = full_path
  end
end

class TrackPathMetadata < TrackMetadata
  attr_accessor :disc_number
  
  def initialize(full_path)
    super(full_path)
    path_elements = File.dirname(full_path).split(File::SEPARATOR)
    @artist_name = path_elements[-2]
    @album_name = path_elements[-1]
    split_disc_number_from_title!
  end
  
  def compilation?
    'Various Artists' == @artist_name
  end
  
  private
  
  def split_disc_number_from_title!
    disc_number_candidate = @album_name.match(/^(.+) \[?disc ([0-9]+)\]?$/)
    if disc_number_candidate
      @album_name = disc_number_candidate[1]
      @disc_number = disc_number_candidate[2].to_i
    end
  end
end

class TrackFilenameMetadata < TrackMetadata
  attr_accessor :sequence

  def initialize(full_path)
    super(full_path)
    filename = File.basename(full_path, '.mp3')
    filename_elements = filename.split(' - ')
    if filename_elements.size == 4
      @artist_name = filename_elements[0]
      @album_name = filename_elements[1]
      @sequence = filename_elements[2]
      @track_name = filename_elements[3]
    else
      @track_name = filename
    end
  end
end

class TrackId3Metadata < TrackMetadata
  attr_accessor :disc_number, :max_disc_number, :sequence, :max_sequence
  attr_accessor :genre, :release_date, :comment, :encoder, :compilation
  attr_accessor :musicbrainz_artist_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_type, :musicbrainz_album_status
  attr_accessor :unique_id
  
  def initialize(full_path)
    super(full_path)
    Mp3Info.open(full_path) do |mp3info_dao|
      # Just in case, try prepopulating with ID3v1 data if it's available
      if mp3info_dao.hastag1?
        id3v1 = mp3info_dao.tag1
        @track_name = id3v1['title']
        @album_name = id3v1['album']
        @artist_name = id3v1['artist']
        @sequence = id3v1['tracknum']
        @genre = id3v1['genre_s']
        @release_date = id3v1['year']
        @comment = id3v1['comments']
      end
      
      if mp3info_dao.hastag2?
        if mp3info_dao.tag2.version =~ /2\.3/ || mp3info_dao.tag2.version =~ /2\.4/
          id3v23 = mp3info_dao.tag2
          @track_name = id3v23.TIT2
          @album_name = id3v23.TALB
          if @album_name.class == Array
            @album_name = @album_name.first
          end
          @artist_name = id3v23.TPE1
          @disc_number, @max_disc_number = id3v23.TPOS.split('/') if id3v23.TPOS
          raw_sequence = id3v23.TRCK
          if raw_sequence
            if raw_sequence.class == Array
              @sequence, @max_sequence = raw_sequence.first.split('/')
            else
              @sequence, @max_sequence = raw_sequence.split('/')
            end
          end
          @genre = id3v23.TCON
          if '1' == id3v23.TCMP
            @compilation = true
          else
            @compilation = false
          end
          @release_date = id3v23.TYER
          @comment = id3v23.COMM
          @encoder = id3v23.TENC
          @encoder << " / ::AOAIOXXYSZ:: encoding tools" if @encoder
          @unique_id = id3v23.UFID
          id3v23.TXXX && id3v23.TXXX.each do |user_comment|
            user_defined_name, user_defined_value = user_comment.split("\000")
            case user_defined_name
            when "MusicBrainz Artist Id"
              @musicbrainz_artist_id = user_defined_value
            when "MusicBrainz Album Id"
              @musicbrainz_album_id = user_defined_value
            when "MusicBrainz Album Type"
              @musicbrainz_album_type = user_defined_value
            when "MusicBrainz Album Status"
              @musicbrainz_album_status = user_defined_value
            when "MusicBrainz Album Artist Id"
              @musicbrainz_album_artist_id = user_defined_value
            end
          end
        elsif  mp3info_dao.tag2.version =~ /2\.2/
          id3v22 = mp3info_dao.tag2
          @track_name = id3v22.TT2
          @album_name = id3v22.TAL
          if @album_name.class == Array
            @album_name = @album_name.first
          end
          @artist_name = id3v22.TP1
          @disc_number, @max_disc_number = id3v22.TPA.split('/') if id3v22.TPA
          raw_sequence = id3v22.TRK
          if raw_sequence
            if raw_sequence.class == Array
              @sequence, @max_sequence = raw_sequence.first.split('/')
            else
              @sequence, @max_sequence = raw_sequence.split('/')
            end
          end
          @genre = id3v22.TCO
          @release_date = id3v22.TYE
          @comment = id3v22.COM
          @encoder = id3v22.TEN
          @encoder << " / ::AOAIOXXYSZ:: encoding tools" if @encoder
          @unique_id = id3v22.UFI
          id3v22.TXX && id3v22.TXX.each do |user_comment|
            user_defined_name, user_defined_value = user_comment.split("\000")
            case user_defined_name
            when "MusicBrainz Artist Id"
              @musicbrainz_artist_id = user_defined_value
            when "MusicBrainz Album Id"
              @musicbrainz_album_id = user_defined_value
            when "MusicBrainz Album Type"
              @musicbrainz_album_type = user_defined_value
            when "MusicBrainz Album Status"
              @musicbrainz_album_status = user_defined_value
            when "MusicBrainz Album Artist Id"
              @musicbrainz_album_artist_id = user_defined_value
            end
          end
        end

        @genre = Mp3Info::GENRES[@genre.match(/\((\d+)\)/)[1].to_i] if @genre && @genre != '' && @genre.match(/\((\d+)\)/)
      end
    end
    
    split_disc_number_from_title!
  end
  
  private
  
  def split_disc_number_from_title!
    disc_number_candidate = @album_name.match(/^(.+) [\(\[]?disc ([0-9]+)[\)\]]?$/) if @album_name
    if disc_number_candidate
      @album_name = disc_number_candidate[1]
      @disc_number = disc_number_candidate[2].to_i unless @disc_number
    end
  end
end