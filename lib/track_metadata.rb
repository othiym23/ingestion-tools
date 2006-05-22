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
    @disc_number = 1
    split_disc_number_from_title!
  end
  
  def compilation?
    'Various Artists' == @artist_name
  end
  
  private
  
  def split_disc_number_from_title!
    disc_number_candidate = @album_name.match(/^(.+) disc ([0-9]+)$/)
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
    filename_elements = File.basename(full_path, '.mp3').split(' - ')
    @artist_name = filename_elements[0]
    @album_name = filename_elements[1]
    @sequence = filename_elements[2]
    @track_name = filename_elements[3]
  end
end

class TrackId3V2Metadata < TrackMetadata
  attr_accessor :disc_number, :max_disc_number, :sequence, :max_sequence
  attr_accessor :genre, :release_date, :comment, :encoder, :compilation
  attr_accessor :musicbrainz_artist_id, :musicbrainz_album_id, :musicbrainz_album_type, :musicbrainz_album_status
  
  def initialize(full_path)
    super(full_path)
  end
end