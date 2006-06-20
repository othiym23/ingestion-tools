require 'string_utils'

class Track
  attr_reader :path
  
  attr_accessor :disc, :name, :artist_name
  attr_accessor :sequence, :genre, :comment, :encoder
  attr_accessor :remix, :featured_artists, :release_date
  attr_accessor :unique_id, :musicbrainz_artist_id
  attr_accessor :sort_order, :artist_sort_order
  attr_accessor :image
  
  def initialize(path)
    @path = path
    @encoder = []
    @featured_artists = []
  end
  
  def set_remix!
    if patterns = @name.match(/^(.*) \[(.*)\](.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Rr]emix)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.* [Mm]ix)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Ee]dit)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Vv]ersion)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Ll]ive)\)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Ii]nstrumental)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Vv]ocal)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end

    if patterns = @name.match(/^(.*) \((.*[Oo]riginal)\)(.*)$/)
      @name = patterns[1] << patterns[3]
      @remix = patterns[2]
    end
  end
  
  def set_sort_order!
    unless @sort_order && '' != @sort_order
      if match_data = @name.match(/\A(The|A|An) (.+)\Z/)
        @sort_order = (match_data[2] << ', ' << match_data[1])
      end
    end

    unless @artist_sort_order && '' != @artist_sort_order
      if match_data = @artist_name.match(/\A(The|A|An) (.+)\Z/)
        @artist_sort_order = (match_data[2] << ', ' << match_data[1])
      end
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

    if patterns = @artist_name.match(/^(.*) with (.*)$/)
      @artist_name = patterns[1]
      @featured_artists << patterns[2]
    end
    
    @featured_artists.collect! { |string| string.split(/, ?/) }
    @featured_artists.flatten!
    @featured_artists.collect! { |string| string.split(/ ?& ?/) }
    @featured_artists.flatten!
    @featured_artists.collect! { |string| string.split(/ and /) }
    @featured_artists.flatten!
    @featured_artists.uniq!
  end
  
  def canonicalize_encoders!
    encoder_version_string = "::AOAIOXXYSZ:: encoding tools, v1"
     if @encoder
       encoder_list = @encoder.compact.uniq.flatten
       
       encoder_list.collect! do |encoder|
         if 'Exact Audio Copy   (Secure mode)' == encoder
           'Exact Audio Copy (secure mode)'
         else
           encoder
         end
       end
       
       if 1 == encoder_list.size && 'Exact Audio Copy (secure mode)' == encoder_list.first
         encoder_list << 'lame 3.96.1 --alt-preset standard'
       end
       
       encoder_list << encoder_version_string unless encoder_list.detect { |name| name == encoder_version_string }
       
       @encoder = encoder_list
    end
  end
  
  # HEURISTIC: most programs either can't read or don't use the extra 2.x
  # frames for involved people and remix names, so we need a canonical
  # form for the track name that includes that information:
  #
  # Track Name (feat. Featured Artist) [Named remix]
  def reconstituted_name
    reconstituted = ''
    reconstituted << @name
    reconstituted << " (feat. #{featured_artists.join(', ')})" if featured_artists.size > 0
    reconstituted << " [#{remix}]" if remix && remix != ''
    
    reconstituted
  end
  
  # HEURISTIC: Exact Audio Copy likes to add a totally gratuitous comment
  # indicating which track the MP3 came from on the original CD.
  def canonicalize_comments!
    @comment = nil if @comment && @comment.match(/^Track \d+$/)
  end
  
  def format_comments
    comment_string = ''
    if Array == @comment
      comment_string = @comment.uniq.join(', ')
    else
      comment_string = @comment if @comment && '' != @comment
    end
  end

  # HEURISTIC: at some point I may switch to using a more sophisticated
  # title-case naming scheme, but the existing archive uses a simple
  # braindamaged scheme of capitalizing all initial characters in names
  def capitalize_names!
    @artist_name = StringUtils.mixed_case(@artist_name)
    @name = StringUtils.mixed_case(@name)
    @genre = StringUtils.mixed_case(@genre)
    
    @remix = capitalize_remix_name(@remix)

    @featured_artists.collect! { |artist| StringUtils.mixed_case(artist) }
  end
  
  private
  
  # HEURISTIC: my personal style is to capitalize every remix word *unless*
  # it's one of "mix", "remix", "version",  "edit", "short", "long", "live",
  # "original", "instrumental", "vocal", or "dub"
  def capitalize_remix_name(remix_name)
    if remix_name
      remix = StringUtils.mixed_case(remix_name)
      remix.gsub!(/(\A|\s)(Mix|Remix|Version|Edit)\b/) {|string| string.downcase}
      remix.gsub!(/(\A|\s)(Short|Long|Extended)\b/) {|string| string.downcase}
      remix.gsub!(/(\A|\s)(Live|Original|Instrumental|Vocal|Dub)\b/) {|string| string.downcase}
    end
    
    remix
  end
end