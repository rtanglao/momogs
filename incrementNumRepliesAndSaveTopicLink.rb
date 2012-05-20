require 'rubygems'
def  increment_num_replies_and_save_topic_link(topic, reply, contributors)
  author = reply["author"]["canonical_name"]
  c = contributors.detect {|c|c[:author] == author}
  if !c.nil?
    $stderr.printf("FOUND author:%s! Incrementing num_replies:%d\n", author,c[:num_replies]) 
    c[:num_replies] += 1
    c[:reply_hh][reply["created_at"].utc.hour] += 1
    existing_link = c[:links].detect{|l|l["url"] == topic["at_sfn"]}
    if existing_link.nil?
      c[:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"][0..66], :id => topic["id"]})
    end
  else
    $stderr.printf("DID NOT FIND author:%s! Adding Author and title:%s, setting num_replies to 1\n", 
      author, topic["subject"]) 
    contributor_array = contributors.push({:author => author,:num_replies => 1, :links => [], :reply_hh => Array.new(24,0) })
    contributor_array[-1][:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"][0..66],  :id => topic["id"]})
    contributor_array[-1][:reply_hh][reply["created_at"].utc.hour] = 1
  end
  return contributors   
end
