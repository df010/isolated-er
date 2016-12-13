#!/usr/bin/env ruby
require 'yaml'
require 'erb'

lifecycle_bundles=ARGV.select {|i|
  (!i.to_s.end_with? ".erb") && (!i.to_s.end_with? ".yml")
}

erb=nil
File.open( ARGV[0] ) { |file|
  erb = ERB.new( file.read )
}

File.open(ARGV[1], 'w') do |f|
  f.write erb.result(binding)
end
#puts "Created - #{zip_filename}"
