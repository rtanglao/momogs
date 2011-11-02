require 'getGSResponse'
def getGSRepliesForTopic(topic, reply_count, verbose_logging)
  reply_page = 1       
  while reply_count > 0
    get_reply_url = "topics/" + topic["slug"] + 
      "/replies.json?sort=recently_created&page=" << "%d" % reply_page << "&limit=30"
    PP::pp(get_reply_url, $stderr)
    skip = false
    begin 
      replies = getResponse(get_reply_url)
    rescue JSON::ParserError
      printf(STDERR, "Parser error in reply:%s\n", get_reply_url)
      reply_count -= 30
      reply_page += 1
      skip = true
    end
    if skip
      skip = false 
      $stderr.printf("JSON error SKIPPING to next page of replies, reply_count:%d\n", reply_count)
      next
    end
    replies["data"].each do|reply|
      if verbose_logging    
        printf(STDE  RR, "START*** of reply\n")
        PP::pp(reply, $stderr)
        printf(STDERR, "\nEND*** of reply\n")
      end
      author = reply["author"]["canonical_name"]
      reply_created_time = Time.parse(reply["created_at"])
      reply_created_time = reply_created_time.utc
      topic_id = reply["topic_id"]
      reply_id = reply["id"]
      printf(STDERR, "RRR: reply created time:%s\n", reply_created_time)
      reply.delete("created_at")
      reply["created_at"] = reply_created_time
      # always get all replies
      topic["fulltext"] = topic["fulltext"] + " " +  reply["content"].downcase
      topic["fulltext_with_tags"] = topic["fulltext"]
      topic["reply_id_array"].push(reply["id"])
      topic["reply_array"].push(reply)
    end # replies ... do
    reply_count -= 30
    reply_page += 1
  end # while reply_count > 0
  return topic
end
