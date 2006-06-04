class Mp3InfoFactory
  attr_reader :tag, :version
  
  def initialize(tag)
    @tag = tag
    @version = tag.version
  end
  
  def Mp3InfoFactory.adaptor(tag)
    if tag.version =~ /2\.3/ || tag.version =~ /2\.4/
      Mp3InfoId3v24Tag.new(tag)
    elsif tag.version =~ /2\.2/
      Mp3InfoId3v22Tag.new(tag)
    end
  end

  def musicbrainz_artist_id
    musicbrainz_getter("MusicBrainz Artist Id")
  end
  
  def musicbrainz_artist_id=(value)
    musicbrainz_setter("MusicBrainz Artist Id", value)
  end
  
  def musicbrainz_album_artist_id
    musicbrainz_getter("MusicBrainz Album Artist Id")
  end
  
  def musicbrainz_album_artist_id=(value)
    musicbrainz_setter("MusicBrainz Album Artist Id", value)
  end
  
  def musicbrainz_album_id
    musicbrainz_getter("MusicBrainz Album Id")
  end
  
  def musicbrainz_album_id=(value)
    musicbrainz_setter("MusicBrainz Album Id", value)
  end
  
  def musicbrainz_album_type
    musicbrainz_getter("MusicBrainz Album Type")
  end
  
  def musicbrainz_album_type=(value)
    musicbrainz_setter("MusicBrainz Album Type", value)
  end
  
  def musicbrainz_album_status
    musicbrainz_getter("MusicBrainz Album Status")
  end
  
  def musicbrainz_album_status=(value)
    musicbrainz_setter("MusicBrainz Album Status", value)
  end
  
  def musicbrainz_album_release_country
    musicbrainz_getter("MusicBrainz Album Release Country")
  end
  
  def musicbrainz_album_release_country=(value)
    musicbrainz_setter("MusicBrainz Album Release Country", value)
  end
  
  protected
  
  def musicbrainz_getter(property_name)
    # this is a stub
  end
  
  def musicbrainz_setter(property_name, value)
    # this is a stub
  end
end

class Mp3InfoId3v24Tag < Mp3InfoFactory
  def initialize(tag)
    super(tag)
  end
  
  def track_name
    @tag.TIT2
  end
  
  def track_name=(value)
    @tag.TIT2 = value
  end
  
  def album_name
    @tag.TALB
  end
  
  def album_name=(value)
    @tag.TALB = value
  end
  
  def artist_name
    @tag.TPE1
  end
  
  def artist_name=(value)
    @tag.TPE1 = value
  end
  
  def disc_set
    @tag.TPOS
  end
  
  def disc_set=(value)
    @tag.TPOS = value
  end
  
  def sequence_info
    @tag.TRCK
  end
  
  def sequence_info=(value)
    @tag.TRCK = value
  end
  
  def genre
    @tag.TCON
  end
  
  def genre=(value)
    @tag.TCON
  end
  
  def compilation?
    @tag.TCMP
  end
  
  def compilation=(value)
    @tag.TCMP = value
  end
  
  def release_date
    @tag.TYER
  end
  
  def release_date=(value)
    @tag.TYER = value
  end
  
  def comment
    @tag.COMM
  end
  
  def comment=(value)
    @tag.COMM = value
    @tag.COMM.description = "::AOIOXXYSZ:: Info"
  end
  
  def encoder
    @tag.TENC
  end
  
  def encoder=(value)
    @tag.TENC = "::AOIOXXYSZ:: encoding tools, v1"
    @tag.TSSE = value
  end
  
  def user_text
    @tag.TXXX
  end
  
  def musicbrainz_track_id
    if @tag.UFID && 'http://musicbrainz.org' == @tag.UFID.namespace
      @tag.UFID
    else
      nil
    end
  end
  
  def musicbrainz_track_id=(value)
    @tag.UFI = value
    @tag.UFI.namespace = 'http://musicbrainz.org'
  end

  protected
  
  def musicbrainz_getter(property_name)
    if @tag.TXXX
      if @tag.TXXX.is_a? Array
        @tag.TXXX.select { |frame| property_name == frame.description }
      else
        @tag.TXXX if property_name == @tag.TXXX.description
      end
    end
  end
  
  def musicbrainz_setter(property_name, value)
    txxx = ID3v2Frame.create_frame('TXXX', value)
    txxx.description = property_name

    if @tag.TXXX
      if @tag.TXXX.is_a? Array
        @tag.TXXX << txxx
      else
        @tag.TXXX = [@tag.TXXX, txxx]
      end
    end
  end
end

class Mp3InfoId3v22Tag < Mp3InfoFactory
  def initialize(tag)
    super(tag)
  end
  
  def track_name
    @tag.TT2
  end
  
  def track_name=(value)
    @tag.TT2 = value
  end
  
  def album_name
    @tag.TAL
  end
  
  def album_name=(value)
    @tag.TAL = value
  end
  
  def artist_name
    @tag.TP1
  end
  
  def artist_name=(value)
    @tag.TP1 = value
  end
  
  def disc_set
    @tag.TPA
  end
  
  def disc_set=(value)
    @tag.TPA = value
  end
  
  def sequence_info
    @tag.TRK
  end
  
  def sequence_info=(value)
    @tag.TRK
  end
  
  def genre
    @tag.TCO
  end
  
  def genre=(value)
    @tag.TCO = value
  end
  
  def compilation?
    nil
  end
  
  def compilation=(value)
    nil
  end
  
  def release_date
    @tag.TYE
  end
  
  def release_date=(value)
    @tag.TYE = value
  end
  
  def comment
    @tag.COM
  end
  
  def comment=(value)
    @tag.COM
  end
  
  def encoder
    @tag.TEN
  end
  
  def encoder=(value)
    @tag.TEN = value
  end
  
  def unique_id
    @tag.UFI
  end
  
  def user_text
    @tag.TXX
  end
  
  def musicbrainz_track_id
    if @tag.UFI && 'http://musicbrainz.org' == @tag.UFI.namespace
      @tag.UFI
    else
      nil
    end
  end
  
  def musicbrainz_track_id=(value)
    @tag.UFI = value
    @tag.UFI.namespace = 'http://musicbrainz.org'
  end

  protected
  
  def musicbrainz_getter(property_name)
    if @tag.TXX
      if @tag.TXX.is_a? Array
        @tag.TXX.select { |frame| property_name == frame.description }
      else
        @tag.TXX if property_name == @tag.TXX.description
      end
    end
  end
  
  def musicbrainz_setter(property_name, value)
    txx = ID3v2Frame.create_frame('TXX', value)
    txx.description = property_name

    if @tag.TXX
      if @tag.TXX.is_a? Array
        @tag.TXX << txxx
      else
        @tag.TXX = [@tag.TXX, txx]
      end
    end
  end
end
