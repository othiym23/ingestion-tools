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

class TrackId3V2Metadata < TrackMetadata
  attr_accessor :disc_number, :max_disc_number, :sequence, :max_sequence
  attr_accessor :genre, :release_date, :comment, :encoder, :compilation
  attr_accessor :musicbrainz_artist_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_type, :musicbrainz_album_status
  attr_accessor :unique_id
  
  def initialize(full_path)
    super(full_path)
    Mp3Info.open(full_path) do |mp3info_dao|
      if mp3info_dao.hastag2?
        id3v2 = mp3info_dao.tag2
        @track_name = id3v2.TIT2 || id3v2.TT2
        @album_name = id3v2.TALB || id3v2.TAL
        if @album_name.class == Array
          @album_name = @album_name.first
        end
        @artist_name = id3v2.TPE1 || id3v2.TP1
        @disc_number, @max_disc_number = id3v2.TPOS.split('/') if id3v2.TPOS
        raw_sequence = id3v2.TRCK || id3v2.TRK
        if raw_sequence
          if raw_sequence.class == Array
            @sequence, @max_sequence = raw_sequence.first.split('/')
          else
            @sequence, @max_sequence = raw_sequence.split('/')
          end
        end
        @genre = id3v2.TCON || id3v2.TCO
        if '1' == id3v2.TCMP
          @compilation = true
        else
          @compilation = false
        end
        @release_date = id3v2.TYER || id3v2.TYE
        @comment = id3v2.COMM
        @encoder = id3v2.TENC
        @encoder << " / ::AOAIOXXYSZ:: encoding tools" if @encoder
        @unique_id = id3v2.UFID
        id3v2.TXXX && id3v2.TXXX.each do |user_comment|
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