$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../../mp3info/lib')))
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '.')))

require 'mp3info'
require 'adaptor/mp3info_factory'

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
        id3v2 = Mp3InfoFactory.adaptor(mp3info_dao.tag2)

        @track_name = reconcile_value(id3v2.track_name)
        @album_name = reconcile_value(id3v2.album_name)
        @artist_name = reconcile_value(id3v2.artist_name)
        @disc_number, @max_disc_number = reconcile_value(id3v2.disc_set).split('/') if id3v2.disc_set
        raw_sequence = reconcile_value(id3v2.sequence_info).split('/')
        @genre = reconcile_value(id3v2.genre)
        if '1' == reconcile_value(id3v2.compilation?)
          @compilation = true
        else
          @compilation = false
        end
        @release_date = reconcile_value(id3v2.release_date)
        @comment = reconcile_value(id3v2.comment)
        @encoder = reconcile_encoders(id3v2.encoder)
        @unique_id = reconcile_value(id3v2.unique_id)
        id3v2.user_text && reconcile_value_as_list(id3v2.user_text).each do |user_comment|
          case user_comment.description
          when "MusicBrainz Artist Id"
            @musicbrainz_artist_id = user_comment.value
          when "MusicBrainz Album Id"
            @musicbrainz_album_id = user_comment.value
          when "MusicBrainz Album Type"
            @musicbrainz_album_type = user_comment.value
          when "MusicBrainz Album Status"
            @musicbrainz_album_status = user_comment.value
          when "MusicBrainz Album Artist Id"
            @musicbrainz_album_artist_id = user_comment.value
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
  
  def reconcile_value(id3v2_frame)
    if id3v2_frame.is_a? Array
      compacted_array = id3v2_frame.compact.map {|frame| frame.value if frame.respond_to?(:value)}.uniq
      if compacted_array.size == 1
        return compacted_array.first
      else
        # TODO: log a warning
      end
    else
     return id3v2_frame.value if id3v2_frame
    end
  end
  
  def reconcile_encoders(encoder_frame)
    encoder_list = []
    
    if encoder_frame.is_a? Array
      encoder_list = encoder_frame.collect {|frame| frame.value.split(' / ') if frame.respond_to?(:value)}
    else
      encoder_list = encoder_frame.value.split(' / ') if encoder_frame
    end
    
    encoder_list
  end
  
  def reconcile_value_as_list(frame)
    if !frame.is_a? Array
      [frame]
    else
      frame
    end
  end
end