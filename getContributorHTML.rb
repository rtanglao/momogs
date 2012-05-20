require 'rubygems'
require 'cgi'

def get_html_for_contributors(contributors)
  contributor_reply_html = "<ol>"
  contributors.each do |t|
    contributor_reply_html += "<li>" + t[:num_replies].to_s + ",&nbsp;" + 
      createLink("http://getsatisfaction.com/people/" + CGI.escapeHTML(t[:author]), t[:author], 24) + ":"
    t[:links] = t[:links].sort{|b,c|b[:id]<=>c[:id]}
    t[:links].each_with_index do |l,i|
      contributor_reply_html += createLinkWithLinktext(l["url"], l["title"][0..66],
        (i+1).to_s, (i+1).to_s.length) + ":"              
    end
    contributor_reply_html += "</li>\n"
  end
  contributor_reply_html += "</ol>\n"
  return contributor_reply_html
end
