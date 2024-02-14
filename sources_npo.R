###topicmodelling
install.packages('rsyntax', force=T)
library(tidyverse)
library(amcat4r)
library(colorspace)
library(udpipe)


amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")

data=amcat4r::query_documents("npo_tk2023",
                              fields = c('_id', 'date', 'publisher', 'title','text'),
                              max_pages = Inf, scroll='5m')


nos = data|>
  filter(publisher=="NOS.nl")|>
  mutate(text=paste0(title, text))

head(nos)
tokens = nos$text

#hierin zitten de queries voor quotes
#daarna zoeken we eerst de quotes en daarna de clauses

quotes = tokens %>% rsyntax::annotate('quote', rsyntax::alpino_quote_queries())
quotes %<>% rsyntax::annotate("clause", rsyntax:::alpino_clause_queries())

head(quotes)
saveRDS(quotes,"data/quotes_bz.RDS")

quotes=readRDS("data/quotes_bz.RDS")

#####ANALYSES######

#hier selecteren we alleen Named entities en alleen de achternamen!
#hieronder selecteren we de bronnen 
#dat doen we als de ner_id niet gelijk is aan de volgende ner_id.
#op die manier kunnen we bv stef blok als blok alleen meenemen, dus alleen op achternamen.
quotes=readRDS("data/quotes_bz.RDS")

qf = quotes %>% filter(NER == "" | str_detect(lemma, "^[A-Za-z]")) %>% filter(ner_id=="" | ner_id != lead(ner_id))
head(qf)


####LET OP: Hier berekening van gezag per periode.
####META

conn = amcat.connect("https://amcat.nl")
meta = amcat.getarticlemeta(conn,project = 1916, articleset=78102, dateparts=T, columns = c("medium","date", "headline"))
meta = as_tibble(meta)

meta=meta%>%rename(doc_id=id)

qf1=left_join(qf,meta)
head(qf1)

qf2=qf1 %>% filter(NER != "") %>% mutate(positie=case_when(quote == "source" ~ "source", T ~ as.character(clause))) %>% 
  mutate(positie=ifelse(is.na(positie), "geen", positie))%>%group_by(doc_id, medium, date,year,month, week,lemma, positie) %>%dplyr::summarize(n=n()) 

table(qf2$positie)
table(quotes$quote, useNA = "always")

head(qf2,12)



bronnen=read_csv("data/sources.csv")
bronnen
table(bronnen$group)
bronnen=bronnen%>%filter(!group=="" & !group=="Trash")

qf3=qf2%>%left_join(bronnen)
qf3
table(qf3$name, useNA = "always")

qf4=qf3%>%filter(! is.na(group) & !group=="Trash")
qf4=qf3%>%filter(group == "BZ")
head(qf4)

blok=qf4%>%filter(name=="Blok")%>%mutate(n=ifelse(name=="Blok" & date>="2018-03-07", n, 0))
zijlstra=qf4%>%filter(name=="Zijlstra")%>%mutate(n=ifelse(name=="Zijlstra" & date<"2018-02-13", n, 0))
qf4=qf4%>%filter(! name %in% c("Blok","Zijlstra"))

qf4b=bind_rows(qf4,zijlstra,blok)                                


qf5=qf4b %>% spread(positie, n, fill = 0)%>%mutate(ntot=geen+predicate+source+subject, gezag=(source+(0.5*subject))/(ntot))%>%arrange(-gezag)
head(qf5)

qf5%<>%group_by(month,group,name)%>%summarize(predicate=sum(predicate),source=sum(source), subject=sum(subject), 
                                        ntot=(predicate+source+subject), gezag=((source +(0.5*subject))/ntot))

qf6=qf5%>%ungroup()%>%filter(name %in% c("Zijlstra", "Blok", "Kaag", "Buitenlandse Zaken"))%>%select(month, name, gezag)%>%group_by(month, name)%>%dplyr::mutate(gezag=mean(gezag))
qf6

library(lubridate)
library(scales)
ggplot(data=qf6, aes(x=month, y=gezag, group=name, fill=factor(name))) +
  geom_line(aes(color=name), size=1.2)+ 
  scale_x_date(date_breaks = "2 month",labels=date_format("%b-%y")) + 
  xlab("Datum") + 
  ylab("Gemiddeld gezag")




####LET OP:hieronder andere analyse. berekening gezag per groep


qf = quotes %>% filter(NER == "" | str_detect(lemma, "^[A-Za-z]")) %>% filter(ner_id=="" | ner_id != lead(ner_id))
head(qf)
qf1=merge(qf,meta,all.x=T)

qf2=qf1 %>% filter(NER != "") %>% mutate(positie=case_when(quote == "source" ~ "source", T ~ as.character(clause))) %>% 
  mutate(positie=ifelse(is.na(positie), "geen", positie))%>%group_by(doc_id, medium, date,year,month, week,lemma, positie) %>%dplyr::summarize(n=n()) 
qf2

table(qf2$positie)
table(quotes$quote, useNA = "always")

head(qf2,12)


bronnen=read_csv("data/sources.csv")
bronnen
bronnen=bronnen%>%filter(!group=="")
table(bronnen$name)


qf3=qf2%>%left_join(bronnen)
qf3
qf4=qf3%>%filter(! is.na(group) & !group=="Trash")%>%arrange(-ntot)

qf5=qf4 %>% spread(positie, n, fill = 0)%>%mutate(ntot=geen+predicate+source+subject, gezag=(source+(0.5*subject))/(ntot))%>%arrange(-gezag)
head(qf5)

qf6=qf5%>%ungroup()%>%select(ntot,name,group,geen,predicate,source, subject,gezag)%>%
  group_by(group,name)%>%summarize(ntot=sum(ntot),predicate=sum(predicate),source=sum(source),subject=sum(subject),
                             gezag=(source+(0.5*subject))/(ntot))%>%arrange(-ntot)



relations = unique(qf6$group)
fixedcolors = c(BZ="red", Diplomaten='green', Kabinet='blue', Nederland="purple")
missing = setdiff(relations, names(fixedcolors))
missing_colors = colorspace::heat_hcl(n=length(missing))
names(missing_colors) = missing
colors = c(fixedcolors, missing_colors)


library(tidyverse)
#install.packages("ggtern")
library(ggtern)


x = qf6 %>% ungroup %>% arrange(-ntot) %>% head(100)
z = function(x) x / mean(x)
x = bind_cols(x, x %$% ggtern::tlr2xy(data.frame(x=z(subject), y=z(source ), z=z(predicate)/2), ggtern::coord_tern()))
x %<>% mutate(wordsize=corpustools:::rescale_var(ntot, .5, 2.5)) %>% rename(px=x, py=y)
plot.new()
x = bind_cols(x, x %$% wordcloud::wordlayout(px, py, words = name, cex=wordsize) %>% as_tibble())

ggplot(x) + geom_text(aes(x=x,y=y,label=name, size=wordsize, color=group),  hjust="middle", vjust="bottom") +
  theme_void() + theme(legend.position="bottom") + scale_size_continuous(range=c(2, 7), guide = F)


x = qf6 %>% ungroup %>% arrange(-ntot) %>% head(100)
z = function(x) x / mean(x)
plot.new()
x = bind_cols(x, x %$% ggtern::tlr2xy(data.frame(x=z(subject), z=z(source ), y=z(predicate)/2), ggtern::coord_tern()))
x %<>% mutate(wordsize=corpustools:::rescale_var(ntot, .5, 2.5)) %>% rename(px=x, py=y)
x = bind_cols(x, x %$% wordcloud::wordlayout(px, py, words = name, cex=wordsize) %>% as_tibble())

ggplot(x) + geom_text(aes(x=-x,y=-y,label=name, size=wordsize, color=group),  hjust="middle", vjust="bottom") +
  theme_void() + theme(legend.position="bottom") + scale_size_continuous(range=c(2, 7), guide = F)


ggplot(x %>% arrange(ntot)) + geom_label(aes(x=-x,y=-y,label=name, size=wordsize, color=group),  hjust="middle", vjust="bottom") +
  theme_void() + theme(legend.position="bottom") + scale_size_continuous(range=c(2, 7), guide = F)



#####ANALYSE INHOUD VAN QUOTES
library(stm)
library(quanteda)
library(topicmodels)


quotes=readRDS("data/quotes_bz.RDS")

head(quotes)
qf = quotes %>% filter(NER == "" | str_detect(lemma, "^[A-Za-z]")) %>% filter(ner_id=="" | ner_id != lead(ner_id))
head(qf)

qblok=qf%>%filter(token=="Blok" & quote=="source")
head(qblok)
blok=qf%>%filter(quote_id %in% qblok$quote_id)
head(blok)



conn = amcat.connect("https://amcat.nl")
meta = amcat.getarticlemeta(conn,project = 1916, articleset=78102, dateparts=T, columns = c("medium","date", "headline"))
meta = as_tibble(meta)

tokens=blok
tokens=tokens%>%dplyr::rename("id"="doc_id")

#merge
data4=merge(meta,tokens, all.x=TRUE)%>%as_tibble()

data5=data4%>%filter(POS %in% c("noun","name"))

#Tcorpus
tc = tokens_to_tcorpus(data5, doc_col = "id", token_id_col=NULL, meta_cols = c("medium", "date"))

dfm=tc$dfm("lemma")
dfm

#De dfm wordt omgezet tot structural topic model.

docs = quanteda::convert(dfm, to="stm")


#die Meta willen we als dataframe en die noemen we meta2
meta2=(docs$meta)
head(meta2)
class(meta2)




for (col in colnames(meta2)) {
  message(col, ":", class(meta2[[col]]))
}
meta2$id = rownames(meta2)

####STRUCTURAL TOPIC MODELLING
#hieronder maken we een nieuw model m2 waarbij we een STM maken waarbij we du
m = stm(docs$documents, docs$vocab, K = 50, max.em.its = 100, data=docs$meta)



#Hieronder gaan we de topics koppelen aan de artikelen.
head(m$theta)
x = m$theta
head(x)


rownames(x) = rownames(docs$meta)
x=as.data.frame(x)
head(x)
x$id = rownames(x)

#NAMEN GEVEN
labelTopics(m, n=10)



####ANALYSE van ANDERE ACTOREN IN HET NIEUWS 

quotes=readRDS("data/quotes_bz.RDS")

head(quotes)
qf = quotes %>% filter(NER == "" | str_detect(lemma, "^[A-Za-z]")) %>% filter(ner_id=="" | ner_id != lead(ner_id))
head(qf)

#qblok=qf%>%filter(token=="Blok" & quote=="source")
#head(qblok)
#bron=qf%>%filter(doc_id %in% qblok$doc_id)
#head(bron)

bron2=qf %>% filter(NER != "") %>% mutate(positie=case_when(quote == "source" ~ "source", T ~ as.character(clause))) %>% 
  mutate(positie=ifelse(is.na(positie), "geen", positie))%>%group_by(doc_id,lemma, positie) %>%dplyr::summarize(n=n()) 

qf
bron2

bron2=bron2%>%ungroup()%>%filter(positie=="source")


bronnen=read_csv("data/gezag2.csv")
bronnen
bronnen=bronnen%>%filter(!group=="" & !group=="Trash")
table(bronnen$name)

####GROEPEN

bron3=bron2%>%left_join(bronnen)%>%filter(positie=="source" & ! is.na(group))

burger=bron3%>%filter(group=="Burgers")
burger2=qf%>%filter(doc_id %in% burger$doc_id)
View(burger2)

names=bron3%>%ungroup()%>%select(group)%>%group_by(group)%>%dplyr::summarize(tot=length(group))%>%arrange(-tot)
View(names)
bron3=bron3%>%ungroup()%>%filter(group %in% names$group)

net1=bron3%>%ungroup()%>%select(doc_id,group)%>%rename(name2=group)
net1

net=bron3%>%left_join(net1)
net
net2=net%>%ungroup()%>%select(doc_id,group,n,name2)%>%filter(group>name2)

net3=net2%>%group_by(group, name2)%>%summarize(n=n())

g <- graph_from_data_frame(net3, vertices=names, directed=F)
g
table(E(g2)$n)

g2 <- delete.edges(g, which(E(g)$n <=10))


min <- 10

plot(g2, edge.arrow.size=.5, vertex.shape="none", vertex.color="gold", 
     vertex.frame.color="blue", vertex.label.color="blue", 
     vertex.label.cex=corpustools:::rescale_var((V(g2)$tot),1,3), edge.color="#FFBBBB",
     edge.curved=0.2, edge.label=ifelse(E(g2)$n>=min, E(g2)$n, NA),
     edge.width =corpustools:::rescale_var(sqrt(E(g2)$n),1,10)) 

