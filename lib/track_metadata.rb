$: << File.expand_path(File.join(File.dirname(__FILE__), '../../mp3info/lib'))

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
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_type
  attr_accessor :musicbrainz_album_status, :musicbrainz_album_release_country
  attr_accessor :unique_id
  
  def initialize(full_path)
    super(full_path)
  end
  
  def TrackId3Metadata.load_from_path(full_path)
    id3 = TrackId3Metadata.new(full_path)
    
    Mp3Info.open(full_path) do |mp3info_dao|
      # Just in case, try prepopulating with ID3v1 data if it's available
      if mp3info_dao.hastag1?
        id3v1 = mp3info_dao.tag1
        id3.track_name = id3v1['title']
        id3.album_name = id3v1['album']
        id3.artist_name = id3v1['artist']
        id3.sequence = id3v1['tracknum']
        id3.genre = id3v1['genre_s']
        id3.release_date = id3v1['year']
        id3.comment = id3v1['comments']
      end
      
      if mp3info_dao.hastag2?
        id3v2 = Mp3InfoFactory.adaptor(mp3info_dao.tag2)

        id3.track_name = reconcile_value(id3v2.track_name)
        id3.album_name = reconcile_value(id3v2.album_name)
        id3.artist_name = reconcile_value(id3v2.artist_name)

        id3.disc_number, id3.max_disc_number = reconcile_value(id3v2.disc_set).split('/') if id3v2.disc_set
        id3.sequence, id3.max_sequence = reconcile_value(id3v2.sequence_info).split('/') if id3v2.sequence_info

        if '1' == reconcile_value(id3v2.compilation?)
          id3.compilation = true
        else
          id3.compilation = false
        end
        id3.release_date = reconcile_value(id3v2.release_date)
        
        id3.comment = reconcile_value(id3v2.comment)
        id3.encoder = reconcile_encoders(id3v2.encoder)
        id3.genre = reconcile_value(id3v2.genre)
        id3.genre = Mp3Info::GENRES[id3.genre.match(/\((\d+)\)/)[1].to_i] if id3.genre && id3.genre != '' && id3.genre.match(/\((\d+)\)/)
        
        id3.unique_id = reconcile_value(id3v2.musicbrainz_track_id)
        id3.musicbrainz_artist_id = reconcile_value(id3v2.musicbrainz_artist_id)
        id3.musicbrainz_album_id = reconcile_value(id3v2.musicbrainz_album_id)
        id3.musicbrainz_album_type = reconcile_value(id3v2.musicbrainz_album_type)
        id3.musicbrainz_album_status = reconcile_value(id3v2.musicbrainz_album_status)
        id3.musicbrainz_album_release_country = reconcile_value(id3v2.musicbrainz_album_release_country)
        id3.musicbrainz_album_artist_id = reconcile_value(id3v2.musicbrainz_album_artist_id)
      end
    end
    
    id3.split_disc_number_from_title!
    id3
  end
  
  def TrackId3Metadata.save_to_path(track, new_path)
    id3 = TrackId3Metadata.new(new_path)
    
    Mp3Info.open(new_path) do |mp3info_dao|
      mp3info_dao.removetag1
      mp3info_dao.removetag2
      
      id3v2 = Mp3InfoFactory.adaptor(mp3info_dao.tag2)

      id3v2.track_name = track.name
      id3v2.album_name = track.disc.album.name
      id3v2.artist_name = track.artist_name

      id3v2.disc_set = "#{track.disc.number}/#{track.disc.album.number_of_discs}"
      id3v2.sequence_info = "#{track.sequence}/#{track.disc.number_of_tracks}"

      id3v2.comment = track.comment
      id3v2.encoder = track.encoder.join(' / ')
      
      id3v2.genre = track.genre
      id3v2.compilation = track.disc.album.compilation
      id3v2.release_date = track.release_date
      
      id3v2.musicbrainz_track_id = track.unique_id
      id3v2.musicbrainz_artist_id = track.musicbrainz_artist_id
      id3v2.musicbrainz_album_id = track.disc.album.musicbrainz_album_id
      id3v2.musicbrainz_album_type = track.disc.album.musicbrainz_album_type
      id3v2.musicbrainz_album_status = track.disc.album.musicbrainz_album_status
      id3v2.musicbrainz_album_release_country = track.disc.album.musicbrainz_album_release_country
      id3v2.musicbrainz_album_artist_id = track.disc.album.musicbrainz_album_artist_id
    end
  end
  
  def TrackId3Metadata.reconcile_value(id3v2_frame)
    if id3v2_frame.is_a? Array
      compacted_array = id3v2_frame.compact.map {|frame| frame.value if frame.respond_to?(:value)}.uniq
      if compacted_array.compact.size == 1
        return compacted_array.first
      else
        # TODO: log a warning
        return compacted_array.first
      end
    else
     return id3v2_frame.value if id3v2_frame
    end
  end
  
  def TrackId3Metadata.reconcile_encoders(encoder_frame)
    encoder_list = []
    
    if encoder_frame.is_a? Array
      encoder_list = encoder_frame.collect {|frame| frame.value.split(' / ') if frame.respond_to?(:value)}
    else
      encoder_list = encoder_frame.value.split(' / ') if encoder_frame
    end
    
    encoder_list
  end
  
  def TrackId3Metadata.reconcile_value_as_list(frame)
    if !frame.is_a? Array
      [frame]
    else
      frame
    end
  end

  def split_disc_number_from_title!
    disc_number_candidate = @album_name.match(/^(.+) [\(\[]?disc ([0-9]+)[\)\]]?$/) if @album_name
    if disc_number_candidate
      @album_name = disc_number_candidate[1]
      @disc_number = disc_number_candidate[2].to_i unless @disc_number
    end
  end
end