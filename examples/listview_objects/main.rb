#!/usr/bin/ruby

# Updated for Gtk3!

# ignore -- this is for development, same as require 'vrlib'
require File.exists?("./../../vrlib/vrlib.rb") ?  "./../../vrlib/vrlib.rb" : "vrlib"

# from require_all gem:
require_rel 'bin/'


ListViewObjectsGUI.new.show_glade()
