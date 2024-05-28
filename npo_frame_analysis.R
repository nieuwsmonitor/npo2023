library(amcat4r)

# connect to amcat4
amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")

#Get all data from 3 weeks before the elactions, filter excluding financieel dagblad
data=amcat4r::query_documents("dutch_news_media",
                              fields = c('_id', 'date', 'publisher', 'title','text'),
                              max_pages = Inf, scroll='5m')|>
  filter(date>="2023-11-01" & date<="2023-11-22")|>
  filter(publisher != "fd")

