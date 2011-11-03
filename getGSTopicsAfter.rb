require 'getGSResponse'
require 'getGSRepliesForTopic'
require 'getGSTagsForTopic'
require 'computeSyntheticAndInsertUpdateTopic'

def getGSTopicsAfter(metrics_start, topicsColl, verbose_logging)
  topic_page = 0
  topic_before_start_time = false
  while true
    topic_page += 1
    skip = false
    topic_url = "products/mozilla_thunderbird/topics.json?sort=recently_active&page=" << "%d" % topic_page << "&limit=30"
    printf(STDERR, "topic_url:%s\n", topic_url)
    begin
      topics = getResponse(topic_url)
    rescue JSON::ParserError
      printf(STDERR, "Parser error in topic:%s\n", topic_url)
      skip = true
    end
    if skip
      skip = false
      next
    end
    topics["data"].each do|topic|
      topic_url = "http://getsatisfaction.com/mozilla_messaging/topics/" + topic["slug"]
      last_active_at = Time.parse(topic["last_active_at"])
      last_active_at = last_active_at.utc
      printf(STDERR, "TOPIC last_active_at:%s\n", last_active_at)
      created_at = Time.parse(topic["created_at"])
      created_at = created_at.utc
      printf(STDERR, "TOPIC created_at:%s\n", last_active_at)
      # JSON only transports string times so convert time to Unix time before putting it into mongo
      topic.delete("last_active_at") 
      topic["last_active_at"] = last_active_at
      topic.delete("created_at") 
      topic["created_at"] = created_at

      if (last_active_at <=> metrics_start) == -1 
        printf(STDERR, "ending getGSTopicsAfter\n")
        topic_before_start_time = true
        break
      end    
      topic["tags_array"] = []
      topic["tag_id_array"] = []
      topic["reply_id_array"] = []
      topic["reply_array"] = []
      topic["fulltext"] = ""
      topic["fulltext_with_tags"] = ""
      topic["tags_str"] = ""
      topic["synthetic_status_journal"] = []
      if verbose_logging
        printf(STDERR, "START*** of topic\n")
        PP::pp(topic,$stderr)
        printf(STDERR, "\nEND*** of topic\n")
      end
      topic_text = topic["subject"].downcase + " " + topic["content"].downcase
      reply_count = topic["reply_count"]  
      printf(STDERR, "reply_count:%d\n", reply_count)
      topic["reply_count"] = reply_count
      topic["fulltext"] = topic_text
      topic["fulltext_with_tags"] = topic_text
      if reply_count != 0
        topic = getGSRepliesForTopic(topic, reply_count, verbose_logging)          
      end # if reply_count != 0
      topic = getGSTagsForTopic(topic, verbose_logging)      
      id = topic["id"]
      computeSyntheticAttributesAndInsertUpdateTopic(topic, id, topicsColl)    
    end # topics["data"].each do|topic|
    if topic_before_start_time
      break
    end
  end # while
end 
