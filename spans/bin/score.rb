#!/usr/bin/ruby

#require 'thor'
require 'pp'



#class Score < Thor
#class Score

#default_date = 20121116
default_date = 'processed'
summary_path =  File.expand_path("../../", __FILE__) + "/data/summarydocuments/"
vitalstrings_path = File.expand_path("../../../", __FILE__) + "/1CLICK/vitalstringscode/out/1C2-E-TEST/#{default_date}/output/STANFORD"
spans_path = File.expand_path("../", __FILE__) + "/spans.pl"
out_path = File.expand_path("../", __FILE__) + "/../out/"
@span_cutoff = 20
@score_cutoff = 0.3

def vitalstring?(str)
  str.include?("/")
end

def spans2(qid, vs, vid)
  puts "processing #{qid}, #{vid} - #{vs}"
  vital_str = vs.join(' ')
  out = `./spans.pl -a -s #{qid} "#{vital_str}"`

  # Vital strings that are not present in any summary
  if out.empty?
    @vs_dont_match ||= {}
    @vs_match["-999"] ||= {}
    @vs_dont_match[vid] = {}
    @vs_match["-999"][vid] ||= {}
    @vs_match["-999"][vid]['smallest'] = [ "-999", "-999" ]
    @vs_match["-999"][vid]['all'] = []
  end

  # Vital strings that match some summaries and summary coverage
  out.split("\n").each do |line|
    sum, len, st, ed = line.split(' ')
    next if len.to_i > @span_cutoff 
    @vs_match[sum] ||= {}
    @vs_match[sum][vid] ||= {}
    @vs_match[sum][vid]['vs'] = vs
    @vs_match[sum][vid]['all'] ||= []

    @sum_cover ||= {}
    @sum_cover[sum] ||= []

    if @vs_match[sum][vid]['smallest'].nil? || @vs_match[sum][vid]['smallest'].last > len.to_i
      @vs_match[sum][vid]['smallest'] = [st.to_i, len.to_i]
    end
    @vs_match[sum][vid]['all'] << [st.to_i, len.to_i]
    @sum_cover[sum] << [st.to_i, len.to_i]
  end

end

if ARGV.length == 0 
  puts "No arguments supplied. Pass at least query id"
  exit 1
end

arg1 = ARGV.first

@global_hash = {}
@vs_match = {}
@vs_dont_match = {}
@sum_cover = {}
puts vitalstrings_path
full_file_path = Dir.glob("#{vitalstrings_path}/*#{arg1}*")
if full_file_path.length != 1 
  puts "Query id needs to exist be unique. Incorrect query id provided."
  exit 1
end
puts "here #{full_file_path}"
full_file_name = full_file_path.first.split("/").last
file_name = full_file_name.split(".").first
query_id = full_file_name.split("-").last.split(".").first
@global_hash[query_id] = {}
open(full_file_path.first).readlines.each do |line|
  line_array = line.split
  puts line_array.inspect
  length = line_array.length
  # vital strings contain / in the first column
  if vitalstring?(line_array.first)
    puts "Vital string is #{line}"
    vitalstring_id = line_array.first
    vitalstring_id_1, vitalstring_id_2 = vitalstring_id.split("/")
    #@global_hash[query_id][vitalstring_id] ||= []
    # check here for duplicates
    puts line_array[1..length].inject([]) {|obj,ell| obj << ell unless ell[/^DEP/];obj}
    @global_hash[query_id][vitalstring_id] = line_array[1..length].inject([]) {|obj,ell| obj << ell unless ell[/^DEP/];obj}
  end
end
@global_hash.each do |qid, query|
  query.each do |vid, vs|
    spans2(qid, vs, vid)
  end
end



  
fd = open(out_path + "#{query_id}", "w")
#fd.write(pp(@vs_match))
#fd.close
#fd = open(out_path + "#{query_id}", "a")
@vs_match.each do |sid, sum|
  sum.each do |vid, vs|
    pp vs
    fd.write("#{sid} #{vid} #{vs['smallest'].join(' ')} #{vs['all'].flatten.join(' ')}\n")
  end
end

@sum_cover.each do |sum, coverage|
  length = 800
  summary = Array.new(length) {0}
  coverage.each do |st, len|
    summary[st..st+len-1] = summary[st..st+len-1].map {|score| score += 1/len}
  end
  # Mark the last block
  summary[length] = @score_cutoff
  st = -1
  ed  = 0
  cur = 0
  summary.each do |score|
    # dont need ed
    st = cur if score < @score_cutoff && st == -1
    if score >= @score_cutoff
      # ed or ed - 1?
      fd.write("#{sum} -999 #{st} #{cur - st}\n") unless st == -1
      st = -1
    end
    cur += 1
  end
end

fd.close
#end
