require 'rubygems'
require 'cgi'

def createLinkWithLinktext(url, title, linktext, length)
  return "<a title=\""+CGI.escapeHTML(title)+"\""+
     " href=\""+ url + "\">"+CGI.escapeHTML(linktext[0..length-1])+"</a>"
end

def createLink(url, title, length)
  return "<a title=\""+CGI.escapeHTML(title) + "\""+
     " href=\""+ url + "\">" + CGI.escapeHTML(title[0..length-1]) + "</a>"
end
