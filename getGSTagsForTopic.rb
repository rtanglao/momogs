require 'getGSResponse'
def getGSTagsForTopic(topic, verbose_logging)
  tags_page = 1
  tag_count = 1 # kludge
  first_tag_page = true
  while tag_count > 0         
    get_tags_url = "topics/" + topic["slug"] + "/tags.json?page=" << "%d" % tags_page << "&limit=30"
    PP::pp(get_tags_url, $stderr)
    skip = false
    begin 
      tags = getResponse(get_tags_url)
    rescue JSON::ParserError
      printf(STDERR, "Parser error in HTTP GET of tag url:%s\n", get_tags_url)
      tag_count -= 30
      tags_page += 1
      skip = true
    end
    if skip
      skip = false
      next
    end         
    if first_tag_page
      tag_count = tags["total"]
      topic["tag_count"] = tag_count
      first_tag_page = false
      $stderr.printf("TAG COUNT:%d\n",tag_count)
    end
    if tag_count > 0 
      tags["data"].each do|tag|
        if verbose_logging    
          printf(STDERR, "START*** of tag\n")
          PP::pp(tag, $stderr)
          printf(STDERR, "\nEND*** of tag\n")
        end
        tag_name = tag["name"].downcase
        if tag_name.length < 80
          topic["tags_array"].push(tag_name)
          topic["tag_id_array"].push({ "id" => tag["id"], "name" => tag_name})
          topic["tags_str"] = topic["tags_str"] + tag_name + "~"
          topic["fulltext_with_tags"] = topic["fulltext_with_tags"] + " " + tag_name
        else
          $stderr.printf("SKIPPING >80 character tag:%s!!\n", tag_name)
        end
      end # tags ... do
    end # if tag_count > 0
    tag_count -= 30
    tags_page += 1                   
  end # while tag_count > 0
  return topic
end
