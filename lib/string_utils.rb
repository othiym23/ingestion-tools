module StringUtils
  # taken from p. 75 of the Pickaxe, 2 ed.
  def StringUtils.mixed_case(name)
    name.gsub(/(\A|\s)\w/) { |first| first.upcase } if name
  end
end