#!/bin/sh

ruby -e 'Dir.foreach(".") { |file| require file if file =~ /_test.rb$/ }'
