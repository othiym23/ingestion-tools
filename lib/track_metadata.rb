$: << File.expand_path(File.join(File.dirname(__FILE__), '../../mp3info/lib'))

require 'iconv'

require 'mp3info'
require 'adaptor/mp3info_factory'

# set of classes meant to encapsulate metainformation in data transfer
# objects about digitally-encoded tracks
class TrackMetadata
  attr_accessor :artist_name, :album_name, :track_name, :full_path
  
  def self.load_from_path(full_path)
    track_metadata = TrackMetadata.new
    track_metadata.full_path = full_path
    track_metadata
  end
  
  protected
  
  def strip_diacritics(string)
    Iconv.iconv('US-ASCII//TRANSLIT', 'UTF-8', string)[0]
  end
end

class TrackPathMetadata < TrackMetadata
  attr_accessor :album_artist_name, :disc_number
  
  def self.load_from_path(full_path)
    track_metadata = TrackPathMetadata.new
    path_elements = File.dirname(full_path).split(File::SEPARATOR)
    track_metadata.album_artist_name = path_elements[-2]
    track_metadata.artist_name = track_metadata.album_artist_name
    track_metadata.album_name = path_elements[-1]
    track_metadata.split_disc_number_from_title!
    
    track_metadata
  end
  
  def TrackPathMetadata.load_from_track(track)
    track_metadata = TrackPathMetadata.new
    
    track_metadata.album_artist_name = track.disc.album.artist_name
    track_metadata.artist_name = track.artist_name
    track_metadata.album_name = track.disc.album.name
    track_metadata.disc_number = track.disc.number

    track_metadata
  end
  
  def artist_directory
    strip_diacritics(@album_artist_name).gsub(/[^A-Za-z0-9 ]/, '')
  end
  
  def disc_directory
    cleaned_album = strip_diacritics(@album_name).gsub(/[^A-Za-z0-9 ]/, '')
    cleaned_album << " disc " << @disc_number.to_s if @disc_number && @disc_number != ''
    cleaned_album
  end
  
  def canonical_path
    File.join(artist_directory, disc_directory)
  end
  
  def compilation?
    'Various Artists' == @album_artist_name
  end
  
  def split_disc_number_from_title!
    disc_number_candidate = @album_name.match(/^(.+) \[?disc ([0-9]+)\]?$/)
    if disc_number_candidate
      @album_name = disc_number_candidate[1]
      @disc_number = disc_number_candidate[2].to_i
    end
  end
  
  def ==(object)
    object.respond_to?(:canonical_path) && canonical_path == object.canonical_path
  end
end

class TrackFilenameMetadata < TrackMetadata
  attr_accessor :sequence

  def TrackFilenameMetadata.load_from_path(full_path)
    track_metadata = TrackFilenameMetadata.new
    track_metadata.full_path = full_path
    filename = File.basename(full_path, '.mp3')
    filename_elements = filename.split(' - ')
    if filename_elements.size == 4
      track_metadata.artist_name = filename_elements[0]
      track_metadata.album_name = filename_elements[1]
      track_metadata.sequence = filename_elements[2]
      track_metadata.track_name = filename_elements[3]
    else
      track_metadata.track_name = filename
    end
    
    track_metadata
  end

  def TrackFilenameMetadata.load_from_track(track)
    track_metadata = TrackFilenameMetadata.new
    
    track_metadata.full_path = track.path
    track_metadata.artist_name = track.artist_name
    track_metadata.album_name = track.disc.album.name
    track_metadata.sequence = track.sequence
    track_metadata.track_name = track.reconstituted_name

    track_metadata
  end
  
  def canonical_filename
    cleaned_artist = strip_diacritics(@artist_name).gsub(/[^A-Za-z0-9 ]/, '')
    cleaned_album = strip_diacritics(@album_name).gsub(/[^A-Za-z0-9 ]/, '')
    cleaned_sequence = "%02d" % @sequence
    cleaned_track = strip_diacritics(@track_name).gsub(/[^A-Za-z0-9 ]/, '')
    [ cleaned_artist, cleaned_album, cleaned_sequence, cleaned_track ].join(' - ') << '.mp3'
  end
end

class TrackId3Metadata < TrackMetadata
  attr_accessor :disc_number, :max_disc_number, :sequence, :max_sequence
  attr_accessor :genre, :release_date, :comment, :encoder, :compilation
  attr_accessor :remix_name, :remixer, :album_artist_name
  attr_accessor :musicbrainz_artist_id, :musicbrainz_album_artist_id
  attr_accessor :musicbrainz_album_id, :musicbrainz_album_type
  attr_accessor :musicbrainz_album_status, :musicbrainz_album_release_country
  attr_accessor :unique_id
  attr_accessor :track_sort_order, :artist_sort_order, :album_sort_order
  
  def TrackId3Metadata.load_from_path(full_path)
    id3 = TrackId3Metadata.new
    id3.full_path = full_path
    
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
        id3.remix_name = reconcile_value(id3v2.remix_name)
        id3.album_name = reconcile_value(id3v2.album_name)
        id3.artist_name = reconcile_value(id3v2.artist_name)

        id3.disc_number, id3.max_disc_number = reconcile_value(id3v2.disc_set).split('/') if id3v2.disc_set
        id3.sequence, id3.max_sequence = reconcile_value(id3v2.sequence_info).split('/') if id3v2.sequence_info

        id3.compilation = true if '1' == reconcile_value(id3v2.compilation?)
        id3.release_date = reconcile_value(id3v2.release_date)
        
        id3.comment = reconcile_value(id3v2.comment)
        id3.remixer = reconcile_value(id3v2.remixer)
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
        
        id3.artist_sort_order = reconcile_value(id3v2.artist_sort_order)
        id3.album_sort_order = reconcile_value(id3v2.album_sort_order) if id3v2.respond_to?(:album_sort_order=)
        id3.track_sort_order = reconcile_value(id3v2.track_sort_order) if id3v2.respond_to?(:track_sort_order=)
      end
    end
    
    id3.split_disc_number_from_title!
    id3
  end
  
  def TrackId3Metadata.load_from_track(track)
    id3 = TrackId3Metadata.new
    
    disc = track.disc
    album = track.disc.album
    
    id3.full_path = track.path
    id3.track_name = track.reconstituted_name
    id3.remix_name = track.remix
    id3.artist_name = track.artist_name
    id3.sequence = track.sequence
    
    id3.comment = track.comment
    id3.encoder = track.encoder.join(' / ') if track.encoder
    
    id3.genre = track.genre
    id3.compilation = album.compilation
    id3.release_date = track.release_date
    
    id3.unique_id = track.unique_id
    id3.musicbrainz_artist_id = track.musicbrainz_artist_id

    id3.album_name = album.name
    id3.disc_number = disc.number
    id3.max_disc_number = album.number_of_discs

    id3.max_sequence = disc.number_of_tracks

    id3.musicbrainz_album_id = album.musicbrainz_album_id
    id3.musicbrainz_album_type = album.musicbrainz_album_type
    id3.musicbrainz_album_status = album.musicbrainz_album_status
    id3.musicbrainz_album_release_country = album.musicbrainz_album_release_country
    id3.musicbrainz_album_artist_id = album.musicbrainz_album_artist_id

    id3.artist_sort_order = track.artist_sort_order
    id3.album_sort_order = album.sort_order
    id3.track_sort_order = track.sort_order

    id3
  end
  
  def save
    Mp3Info.removetag1(full_path)
    Mp3Info.removetag2(full_path)

    Mp3Info.open(full_path) do |mp3|
      id3v2 = Mp3InfoFactory.adaptor(mp3.tag2)

      id3v2.track_name = track_name if track_name && '' != track_name
      id3v2.remix_name = remix_name if remix_name && '' != remix_name
      id3v2.album_name = album_name if album_name && '' != album_name
      id3v2.artist_name = artist_name if artist_name && '' != artist_name

      id3v2.disc_set = "#{disc_number}/#{max_disc_number}" if disc_number && max_disc_number
      id3v2.sequence_info = "%02d" % sequence if sequence && '' != sequence
      id3v2.sequence_info.value << "/#{"%02d" % max_sequence}" if sequence && '' != sequence && max_sequence && ''!= max_sequence
      
      id3v2.comment = comment if comment && '' != comment
      id3v2.remixer = remixer if remixer && '' != remixer
      id3v2.encoder = encoder if encoder && '' != encoder
      
      id3v2.genre = genre if genre
      id3v2.compilation = compilation if compilation
      id3v2.release_date = release_date if release_date
      
      id3v2.musicbrainz_track_id = unique_id if unique_id
      id3v2.musicbrainz_artist_id = musicbrainz_artist_id if musicbrainz_artist_id
      id3v2.musicbrainz_album_id = musicbrainz_album_id if musicbrainz_album_id
      id3v2.musicbrainz_album_type = musicbrainz_album_type if musicbrainz_album_type
      id3v2.musicbrainz_album_status = musicbrainz_album_status if musicbrainz_album_status
      id3v2.musicbrainz_album_release_country = musicbrainz_album_release_country if musicbrainz_album_release_country
      id3v2.musicbrainz_album_artist_id = musicbrainz_album_artist_id if musicbrainz_album_artist_id

      id3v2.artist_sort_order = artist_sort_order if artist_sort_order && '' != artist_sort_order
      id3v2.album_sort_order = album_sort_order if id3v2.respond_to?(:album_sort_order=) && album_sort_order && '' != album_sort_order
      id3v2.track_sort_order = track_sort_order if id3v2.respond_to?(:track_sort_order=) && track_sort_order && '' != track_sort_order
    end
    
    true
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
      encoder_list << encoder_frame.collect {|frame| frame.value.split(' / ') if frame.respond_to?(:value)}
    else
      encoder_list << encoder_frame.value.split(' / ') if encoder_frame
    end

    encoder_list
  end
  
  def canonical_full_path
    path = TrackPathMetadata.new
    path.album_artist_name = album_artist_name || artist_name
    path.album_name = album_name
    path.disc_number = disc_number if disc_number && max_disc_number && max_disc_number > 1
    
    filename = TrackFilenameMetadata.new
    filename.artist_name = artist_name
    filename.album_name = album_name
    filename.sequence = sequence
    filename.track_name = track_name
    
    File.join(path.canonical_path, filename.canonical_filename)
  end

  def split_disc_number_from_title!
    disc_number_candidate = @album_name.match(/^(.+) [\(\[]?disc ([0-9]+)[\)\]]?$/) if @album_name
    if disc_number_candidate
      @album_name = disc_number_candidate[1]
      @disc_number = disc_number_candidate[2].to_i unless @disc_number
    end
  end
end