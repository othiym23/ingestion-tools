class Mp3InfoFactory
  attr_reader :tag, :version
  
  def initialize(tag)
    @tag = tag
    @version = tag.version
  end
  
  def Mp3InfoFactory.adaptor(tag)
    case tag.version
    when '2.2.0'
      Mp3InfoId3v22Tag.new(tag)
    when '2.3.0'
      Mp3InfoId3v23Tag.new(tag)
    when '2.4.0'
      Mp3InfoId3v24Tag.new(tag)
    else
      raise ArgumentError.new("#{tag.version} is not recognized as a valid ID3V2 tag version")
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
end

class Mp3InfoId3v23Tag < Mp3InfoFactory
  def initialize(tag)
    super(tag)
  end
  
  def track_name
    @tag.TIT2
  end
  
  def track_name=(value)
    @tag.TIT2 = value
  end
  
  def remix_name
    @tag.TIT3
  end
  
  def remix_name=(value)
    @tag.TIT3 = value
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
  
  def featured_artists
    featured = []

    involved_people = @tag.TXXX
    if involved_people
      if involved_people.is_a?(Array)
        involved_people.each do |candidate|
          next unless candidate.description == 'Featured Performer'
          featured << candidate.value
        end
      else
        if 'Featured Performer' == involved_people.description
          featured << involved_people.value
        end
      end
    end
    featured
  end
  
  def featured_artists=(value)
    if value.is_a?(Array)
      value.each do |performer|
        featured_frame = ID3V24::Frame.create_frame('TXXX', performer)
        featured_frame.description = 'Featured Performer'
        @tag.TXXX << featured_frame
      end
    else
      featured_frame = ID3V24::Frame.create_frame('TXXX', value)
      featured_frame.description = 'Featured Performer'
      @tag.TXXX << featured_frame
    end
  end

  def remixer
    @tag.TPE4
  end
  
  def remixer=(value)
    @tag.TPE4 = value
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
    @tag.TCON = value
  end
  
  def compilation?
    @tag.TCMP
  end
  
  def compilation=(value)
    @tag.TCMP = value
  end
  
  def release_date
    @tag.TDRC || @tag.TYER
  end
  
  def release_date=(value)
    @tag.TDRC = value
  end
  
  def comment
    @tag.COMM
  end
  
  def comment=(value)
    @tag.COMM = value
    @tag.COMM.description = ''
  end
  
  def encoder
    @tag.TSSE || @tag.TENC
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
    @tag.UFID = value
    @tag.UFID.namespace = 'http://musicbrainz.org'
  end

  def artist_sort_order
    @tag.XSOP
  end
  
  def artist_sort_order=(value)
    @tag.XSOP = value
  end
  
  def album_image
    @tag.APIC
  end
  
  def album_image=(value)
    @tag.APIC = value
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
    txxx = ID3V24::Frame.create_frame('TXXX', value)
    txxx.encoding = 0 # ISO-8859-1, as per http://musicbrainz.org/docs/specs/metadata_tags.html
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

class Mp3InfoId3v24Tag < Mp3InfoId3v23Tag
  def album_sort_order
    @tag.TSOA
  end
  
  def album_sort_order=(value)
    @tag.TSOA = value
  end
  
  def artist_sort_order
    @tag.TSOP
  end
  
  def artist_sort_order=(value)
    @tag.TSOP = value
  end
  
  def track_sort_order
    @tag.TSOT
  end
  
  def track_sort_order=(value)
    @tag.TSOT = value
  end
  
  def release_date
    @tag.TYER
  end
  
  def release_date=(value)
    @tag.TYER = value
  end
  
  def featured_artists
    featured = []
  
    involved_people = @tag.TIPL
    if involved_people
      if involved_people.is_a?(Array)
        while true
          role_frame = involved_people.shift
          break unless role_frame
          next unless 'Featured Performer' == role_frame.value
  
          featured_candidate = involved_people.shift
          unless featured_candidate && 
                 'Featured Performer' != featured_candidate.value
            raise IOError.new("badly-formatted featured performer list")
          end
  
          featured << featured_candidate.value
        end
      end
    end
    featured
  end
  
  def featured_artists=(value)
    performer_list = []
    if value.is_a?(Array)
      value.each do |performer|
        performer_list << 'Featured Performer'
        performer_list << performer
      end
    else
      performer_list << 'Featured Performer'
      performer_list << value
    end
    @tag.TIPL = performer_list if performer_list.size > 0
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
  
  def remix_name
    @tag.TT3
  end
  
  def remix_name=(value)
    @tag.TT3 = value
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
  
  def featured_artists
    featured = []

    involved_people = @tag.TXX
    if involved_people
      if involved_people.is_a?(Array)
        involved_people.each do |candidate|
          next unless candidate.description == 'Featured Performer'
          featured << candidate.value
        end
      else
        if 'Featured Performer' == involved_people.description
          featured << involved_people.value
        end
      end
    end
    featured
  end
  
  def featured_artists=(value)
    if value.is_a?(Array)
      value.each do |performer|
        featured_frame = ID3V24::Frame.create_frame('TXX', performer)
        featured_frame.description = 'Featured Performer'
        @tag.TXX << featured_frame
      end
    else
      featured_frame = ID3V24::Frame.create_frame('TXX', value)
      featured_frame.description = 'Featured Performer'
      @tag.TXX << featured_frame
    end
  end

  def remixer
    @tag.TP4
  end
  
  def remixer=(value)
    @tag.TP4 = value
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

  def artist_sort_order
    @tag.XSP
  end
  
  def artist_sort_order=(value)
    @tag.XSP = value
  end
  
  def album_image
    @tag.PIC
  end
  
  def album_image=(value)
    @tag.PIC = value
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
