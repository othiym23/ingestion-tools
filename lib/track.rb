class Track
  attr_reader :path
  
  attr_accessor :disc, :name, :artist_name
  attr_accessor :sequence, :genre, :comment, :encoder
  attr_accessor :remix, :featured_artists, :release_date
  attr_accessor :unique_id, :musicbrainz_artist_id
  
  def initialize(path)
    @path = path
    @encoder = []
    @featured_artists = []
  end
  
  def set_remix!
    if patterns = @name.match(/^(.*) \[(.*)\](.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Rr]emix)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.* [Mm]ix)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Ee]dit)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Vv]ersion)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Ii]nstrumental)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Vv]ocal)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Oo]riginal)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @remix = patterns[2]
    end
  end
  
  def set_featured_artists!
    if patterns = @name.match(/^(.*) \([Ff](ea)?t\.? (.*)\)(.*)$/)
      @name = patterns[1] + patterns[4]
      @featured_artists << patterns[3]
    end

    if patterns = @artist_name.match(/^(.*) \([Ff](ea)?t. (.*)\)$/)
      @artist_name = patterns[1]
      @featured_artists << patterns[3]
    end
  end
end