def computeSyntheticAttributesAndInsertUpdateTopic(topic, id, topicsColl)
  status = topic["status"]
  status_update_time =  topic["last_active_at"]
  existingTopic =  topicsColl.find_one("id" =>id)
  if existingTopic
    if existingTopic.has_key?("synthetic_status_journal") 
      $stderr.printf("ADDING to synthetic_status_journal! current journal size:%d status:%s status_update_time:%s\n", 
        existingTopic["synthetic_status_journal"].length(), status, status_update_time)
      status_update_found = false
      existingTopic["synthetic_status_journal"].each do |journal_element|
        if (journal_element["status_update_time"] <=> status_update_time) == 0
          status_update_found = true
          break
        end
      end
      topic["synthetic_status_journal"] = existingTopic["synthetic_status_journal"]
      if !status_update_found
        $stderr.printf("status update NOT FOUND so adding it to synthetic_status_journal\n")
        topic["synthetic_status_journal"].push({ "status" => status, "status_update_time" => status_update_time })
      else
        $stderr.printf("status update FOUND so just copying OLD synthetic_status_journal\n")
      end
    else
      $stderr.printf("CREATING synthetic_status_journal! status:%s status_update_time:%s\n", status, status_update_time)
      topic["synthetic_status_journal"].push({ "status" => status, "status_update_time" => status_update_time })
    end
    $stderr.printf("UPDATING topic id:%d\n",id)
    topicsColl.update({"id" =>id},topic)
  else
    $stderr.printf("INSERTING topic id:%d\n",id)
    topic["synthetic_status_journal"].push({ "status" => status, "status_update_time" => status_update_time })
    topicsColl.insert(topic)
  end
end
