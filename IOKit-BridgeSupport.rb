#!/usr/bin/env ruby

require 'bundler/setup'

require 'nokogiri'

IOKIT_PATH = '/System/Library/Frameworks/IOKit.framework'
BRIDGESUPPORT_FILE = File.open("#{IOKIT_PATH}/Resources/BridgeSupport/IOKit.bridgesupport")
BRIDGESUPPORT_NOKO = Nokogiri::XML(BRIDGESUPPORT_FILE)
BRIDGESUPPORT_LINES = BRIDGESUPPORT_FILE.tap(&:rewind).readlines
BRIDGESUPPORT_FILE.close

headers = Dir["#{IOKIT_PATH}/Headers/**/*.h"]
headers.map! { |header| File.open(header).read.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') }

functions = BRIDGESUPPORT_NOKO.xpath('//function').to_a
functions.keep_if { |function| function.xpath('retval').empty? }
functions.map! { |function| function['name'] }

functions.keep_if do |function|
  regex = /void\s*#{function}/m
  headers.any? { |header| header.scan(regex).count > 0 }
end

patch_lines = []

functions.each_with_index do |function, i|
  start_index = BRIDGESUPPORT_LINES.index("<function name='#{function}'>\n") + 1
  end_index = BRIDGESUPPORT_LINES.drop(start_index).index("</function>\n") + start_index + 1

  patch_lines << "#{start_index},#{end_index}" + 'c' + "#{start_index+i},#{end_index+i+1}\n"
  BRIDGESUPPORT_LINES[start_index-1..end_index-1].each { |line| patch_lines << "< #{line}" }
  patch_lines << "---\n"
  BRIDGESUPPORT_LINES[start_index-1..end_index-1].each { |line| patch_lines << "> #{line}" }
  patch_lines.insert(-2, "> <retval type='v'/>\n")
end

print patch_lines.join('')
