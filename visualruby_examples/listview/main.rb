#!/usr/bin/ruby

my_path = File.expand_path(File.dirname(__FILE__))
if my_path =~ /^\/home\/eric\/vrp\/.*/  
	require File.expand_path(my_path + "../../../../vrlib3") + "/vrlib.rb"  
else
	require "vrlib"
end


#make program output in real time so errors visible in VR.
STDOUT.sync = true
STDERR.sync = true

#everything in these directories will be included
my_path = File.expand_path(File.dirname(__FILE__))

require_all Dir.glob(my_path + "/bin/**/*.rb") 

x = SongListViewGUI.new
x.show

