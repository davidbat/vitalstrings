#!/usr/bin/ruby

require 'thor'

default_date = 20121116

path = File.expand_path("..", __FILE__) + '/aq/lib/aq/hosting/servers'
vitalstrings_path = File.expand_path("../../../", __FILE__) + "1CLICK/vitalstringscode/out/1C2-E-TEST/#{default_date}/output/STANFORD"

def span(qid, vs)
	out = exec("spans.pl -a -s #{qid} #{vs}")
	out.split('\n').each do |line|
		sum, st, ed, len = line.split(' ')




class Score < Thor

	def vitalstring?(str)
		str.include?("/")
	end

	@global_hash = {}
	DIR.glob(vitalstrings_path).each do |full_file_path|
		# 1C2-E-TEST-0001.out
		full_file_name = full_file_path.split("/").last

		# file_name and query_id are equivalent (when used as keys in a hash). We dont use file_name
		# 1C2-E-TEST-0001
		file_name = full_file_name.split(".").first

		# get 0001 out of the file name
		query_id = full_file_name.split("-").last.split(".").first

		@global_hash[query_id] = {}
		open(file).readlines.each do |line|
			line_array = line.split
			length = line_array.length
			# vital strings contain / in the first column
			if vitalstring?(line_array.first)
				vitalstring_id = line_array.first.split('-').last
				vitalstring_id_1, vitalstring_id_2 = vitalstring_id.split("/")
				@global_hash[query_id][vitalstring_id_1] ||= {}
				@global_hash[query_id][vitalstring_id_1][vitalstring_id_2] = line_arry[1..length].inject([]) {|obj,ell| obj << ell unless ell.grep(/^DEP/);obj}
			end
		end
	end

	vs_match = {}
	vs_dont_match = {}
	doc_dont_match = {}

	@global_hash.each do |qid, query|
		query.each do |nid, nugget|
			nugget.each do |vs|
				spans(qid, vs)
			end
		end
	end

end