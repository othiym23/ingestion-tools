module StringUtils
  # taken from p. 75 of the Pickaxe, 2 ed.
  def StringUtils.mixed_case(name)
    name.gsub(/\b\w/) { |first| first.upcase }
  end
end