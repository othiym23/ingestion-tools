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

    if patterns = @name.match(/^(.*) [Ff](ea)?t\.? (.*)$/)
      @name = patterns[1]
      @featured_artists << patterns[3]
    end

    if patterns = @name.match(/^(.*) \([Ff]eaturing (.*)\)(.*)$/)
      @name = patterns[1] + patterns[3]
      @featured_artists << patterns[2]
    end

    if patterns = @name.match(/^(.*) [Ff]eaturing (.*)$/)
      @name = patterns[1]
      @featured_artists << patterns[2]
    end

    if patterns = @artist_name.match(/^(.*) \([Ff](ea)?t.? (.*)\)$/)
      @artist_name = patterns[1]
      @featured_artists << patterns[3]
    end

    if patterns = @artist_name.match(/^(.*) [Ff](ea)?t.? (.*)$/)
      @artist_name = patterns[1]
      @featured_artists << patterns[3]
    end

    if patterns = @artist_name.match(/^(.*) [Ww]ith (.*)$/)
      @artist_name = patterns[1]
      @featured_artists << patterns[2]
    end
    
    @featured_artists.collect! { |string| string.split(/, ?/) }
    @featured_artists.flatten!
    @featured_artists.collect! { |string| string.split(/ ?& ?/) }
    @featured_artists.flatten!
    @featured_artists.collect! { |string| string.split(/ and /) }
    @featured_artists.flatten!
  end
  
  def canonicalize_encoders!
     if @encoder
       encoder_list = @encoder.compact.uniq.flatten
       
       encoder_list.collect! do |encoder|
         if 'Exact Audio Copy   (Secure mode)' == encoder
           'Exact Audio Copy (secure mode)'
         end
       end
       
       if 1 == encoder_list.size && 'Exact Audio Copy (secure mode)' == encoder_list.first
         encoder_list << 'lame 3.96.1 --alt-preset standard'
       end
       
       encoder_list << "::AOAIOXXYSZ:: encoding tools, v1"
       
       @encoder = encoder_list
    end
  end
  
  def canonicalize_comments!
    @comment = nil if @comment && @comment.match(/^Track \d+$/)
  end
end