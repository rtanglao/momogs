/* 
  from http://getsatisfaction.com/getsatisfaction/topics/give_me_a_filter_to_see_popular_ideas_but_dont_include_implemented_ideas
   popular, not implemented ideas
   _id:0 means don't retrieve the MongoDB id
  me_too_count: -1 means sort from highest me_toos to lowest me_toos
*/
db.topics.find({style : "idea" , status : { $ne : "complete"}},
  {at_sfn:-1,_id:0,status:-1,me_too_count:-1}).sort({me_too_count:-1}).forEach(printjson)
