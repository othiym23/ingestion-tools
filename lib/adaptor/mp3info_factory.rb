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
end

class Mp3InfoId3v24Tag < Mp3InfoFactory
  def initialize(tag)
    super(tag)
  end
  
  def track_name
    @tag.TIT2
  end
  
  def album_name
    @tag.TALB
  end
  
  def artist_name
    @tag.TPE1
  end
  
  def disc_set
    @tag.TPOS
  end
  
  def sequence_info
    @tag.TRCK
  end
  
  def genre
    @tag.TCON
  end
  
  def compilation?
    @tag.TCMP
  end
  
  def release_date
    @tag.TYER
  end
  
  def comment
    @tag.COMM
  end
  
  def encoder
    @tag.TENC
  end
  
  def unique_id
    @tag.UFID
  end
  
  def user_text
    @tag.TXXX
  end
end

class Mp3InfoId3v22Tag < Mp3InfoFactory
  def initialize(tag)
    super(tag)
  end
  
  def track_name
    @tag.TT2
  end
  
  def album_name
    @tag.TAL
  end
  
  def artist_name
    @tag.TP1
  end
  
  def disc_set
    @tag.TPA
  end
  
  def sequence_info
    @tag.TRK
  end
  
  def genre
    @tag.TCO
  end
  
  def compilation?
    nil
  end
  
  def release_date
    @tag.TYE
  end
  
  def comment
    @tag.COM
  end
  
  def encoder
    @tag.TEN
  end
  
  def unique_id
    @tag.UFI
  end
  
  def user_text
    @tag.TXX
  end
end
