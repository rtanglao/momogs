# -*- coding: utf-8 -*-
# Copyright Mark Watson 2008. All rights reserved.
# http://markwatson.com/aiblog/2008/02/my-opencalais-ruby-client-library.html
# Can be used under either the Apache 2 or the LGPL licenses.
# export RUBYLIB=$RUBYLIB:/home/foo/ruby/mylib
# irb
# require calais_client
# s = topic text
# cc = CalaisClient::OpenCalaisTaggedText.new(s)
# pp cc.get_tags
module CalaisClient 
VERSION = '0.0.1'
require 'simple_http'

require "rexml/document"
include REXML

require 'pp'

MY_KEY = ENV["OPEN_CALAIS_KEY"]
raise(StandardError,"Set Open Calais login key in ENV: 'OPEN_CALAIS_KEY'") if !MY_KEY

PARAMS = "&msXML=" + CGI.escape('<c:params xmlns:c="http://s.opencalais.com/1/pred/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><c:processingDirectives c:contentType="text/txt" c:outputFormat="xml/rdf"></c:processingDirectives><c:userDirectives c:allowDistribution="true" c:allowSearch="true" c:externalID="17cabs901" c:submitter="ABC"></c:userDirectives><c:externalMetadata></c:externalMetadata></c:params>')

class OpenCalaisTaggedText
  def initialize text=""
    data = "licenseID=#{MY_KEY}&content=" + CGI.escape(text)
    http = SimpleHttp.new "http://api.opencalais.com/enlighten/calais.asmx/Enlighten"
    @response = CGI.unescapeHTML(http.post(data+PARAMS))
  end
  def get_tags
    h = {}
    index1 = @response.index('terms of service.-->')
    index1 = @response.index('<!--', index1)
    index2 = @response.index('-->', index1)
    txt = @response[index1+4..index2-1]
    lines = txt.split("\n")
    lines.each {|line|
      index = line.index(":")
      h[line[0...index]] = line[index+1..-1].split(',').collect {|x| x.strip} if index
    }
    h
  end 
  def get_semantic_XML
    @response
  end
  def pp_semantic_XML
    Document.new(@response).write($stdout, 0)
  end
end
end
