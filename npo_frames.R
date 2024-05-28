library(annotinder)
library(textdata)
library(boolydict)
library(amcat4r)
library(tidyverse)
library(googlesheets4)

data = readRDS("data/data_tk2023.rds")
googlesheets4::gs4_deauth()
politiek <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = "combi")

data = data |> 
  dict_add(politiek, text_col = 'text', by_label='label', fill = 0)|>
  filter(politiek>0)


tokens = readRDS("data/tokens_tk2023.rds")

tokens = tokens|>
  filter(doc_id %in% data$.id)

saveRDS(tokens,"data/npo_tokens.rds")

googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)



hits = tokens |> 
  dict_add(partijen, text_col = 'token', by_label='label', fill = 0)


focus = hits |> 
  pivot_longer(-doc_id:-upos, names_to = 'party', values_to='nparty') |>
  filter(nparty > 0) |>
  group_by(doc_id) |>
  slice_min(order_by=start, n=1, with_ties = F) |>
  select(doc_id, sentence_id, token_id, party) |>
  add_column(focus=1)


sents=tokens |>
  filter(doc_id %in% focus$doc_id) |>
  left_join(focus) |> 
  left_join(select(focus, doc_id, sentence_id, sentence_focus=focus)) |>
  as_tibble() |>
  mutate(token = if_else(!is.na(focus), str_c("**", token, "**"), token)) |>
  mutate(sent_id=paste0(doc_id,"-",sentence_id))|>
  group_by(doc_id, sent_id) |> 
  summarize(text = str_c(token, collapse=" "),
            sent_text = str_c(if_else(is.na(sentence_focus), "", token), collapse=" ") |> trimws())|>
  mutate(before=ifelse(sent_text !="" & doc_id==lag(doc_id), lag(text), sent_text),
         after=ifelse(sent_text !="" & doc_id==lead(doc_id), lead(text), sent_text),
  )|>
  filter(sent_text !="")

head(sents)
annotinder::backend_connect("https://uva-climate.up.railway.app", username="nelruigrok@nieuwsmonitor.org", .password = "test")

selectie = data|>
  filter(publisher !="NOS.nl")

d2 = sents|>
  filter(doc_id %in% selectie$.id)

d0=d2  
d0$newrow <- sample(7, size = nrow(d0), replace = TRUE)
numbers = 1:7
for (i in numbers){
  name = paste0('f', i)
  name = d0|>
    filter(newrow==i)
}


head(i)
d0
data3=d0|>
  filter(newrow==3)


todo = seq(219:220,1)
artcodings = list()
id=229
for(id in todo) {
  message("* Getting job ",id, " (", length(artcodings)+1, "/", length(todo), ")")
  d = download_annotations(id)
  if (is.null(c)) next
  artcodings[[as.character(id)]] = c
}

table(d$unit_id %in% c$unit_id)

c2 = c|>
  filter(! unit_id %in% d$unit_id)|>
  bind_rows(d,e)

parties = focus|>
  ungroup()|>
  mutate(sent_id = paste0(doc_id,"-",sentence_id))|>
  select(sent_id, party)

c2 = c2|>
  rename(sent_id=unit_id)|>
  left_join(parties)

c2
sents
table(c2$sent_id %in% sents$sent_id)

coded = sents|>
  filter(sent_id %in% c2$sent_id)

coded2 = c2|>
  left_join(coded)|>
  select(sent_id, variable, value, party, before, after, sent_text)

coded3 = coded2|>
  rename(label=value)|>
  mutate(sent_text= gsub("[**]","", sent_text))|>
  mutate(sent_text = trimws(sent_text))|>
  mutate(label_text = if_else(label == "Nee", "issue_no", "issue_yes"))|>
  select(sent_id, sent_text, label, party, before, after, variable, label_text)


coded3|>
  filter(variable=="succes en falen")
  
  
write_csv(sf,"data/npo_sf.csv")
write_csv(conflict,"data/npo_conflict.csv")
write_csv(issues,"data/npo_issue.csv")
write_csv(coded3,"data/npo_coderingen3.csv")

d = read_csv("data/npo_coderingen3.csv")
head(d)


###coded sets 235 and 236
annotinder::backend_connect("https://uva-climate.up.railway.app", username="nelruigrok@nieuwsmonitor.org", .password = "test")
id=235
c_235 = download_annotations(id)
id=236
c_236 = download_annotations(id)

c_tot = c_235|>
  bind_rows(c_236)

sents=read_csv("data/sents_npo.csv")|>
  select(-text)

coded = retext()coded = read_csv("data/npo_coderingen3.csv")
table(c_tot$unit_id %in% coded$sent_id)

library(deeplr)

get_deepl = function(text){
  toEnglish(
    text,
    source_lang = "nl",
    split_sentences = TRUE,
    preserve_formatting = FALSE,
    get_detect = FALSE,
    auth_key = "00abd0d1-c264-4b2b-9101-17f5a9a92b22"
  )
}

add_deepls = function(data, in_column, out_column) {
  if (!out_column %in% colnames(data)) data[[out_column]] = NA_character_
  for (i in seq_along(data[[in_column]])) {
    tryCatch( {
      result = data[[out_column]][i]
      if (is.na(result)) {
        message(i)
        data[i, out_column] <- get_deepl(data[[in_column]][i])
      }}, error = function(e) {warning(str_c("Error in line ", i))})
    
    if (i %% 100 == 0) {
      message(str_c(i, ", saving results as data.rds"))
      saveRDS(data, "data.rds")
    }
  }
  return(data)
}

sents_eng = sents|>
  add_deepls("sent_text", "sent_eng")|>
  add_deepls("before", "before_eng")|>
  add_deepls("after", "after_eng")

sents_eng = sents_eng|>
  select(-sent_text,-after,-before)|>
  rename(sent_text=sent_eng, before=before_eng, after=after_eng)

write_csv(sents_eng,"data/sents_npo_eng.csv")  
