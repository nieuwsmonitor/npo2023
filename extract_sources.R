
library(tidyverse)
library(udpipe)
library(rsyntax)

source("https://raw.githubusercontent.com/vanatteveldt/rsyntax_dutch_quotes/main/dutch_quotes.R")
as.id = function(x) {
  x = as.character(x)
  class(x) <-  c("id_col", x)
  x
}

# Apply to actual texts

amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")
docs = amcat4r::query_documents("npo_tk2023", fields=c("url", "title", "text"), max_pages = 0)

d = docs |> rename(doc_id=.id) |> mutate(text=str_c(title, text, sep="\n\n") |> replace_quotes())
tokens = d |> udpipe('dutch') |> as_tibble() |> add_next_quotes()

annotated = tokens |> annotate_tqueries("quote", queries) 
sources = as_tibble(annotated) |> filter(quote == "source") |> select(doc_id, sentence,sentence, token_id, quote_id, token, lemma, upos) |> 
  mutate(doc_id = as.id(doc_id), quote_id=match(quote_id, unique(quote_id)))

sources |> filter(doc_id == "009baef99e7a7ed8e5f2c1b547148b51dcb354a29fdd0bc21721f76c")|> filter(upos == "PROPN", (lead(upos) != "PROPN") | lead(quote_id) != quote_id)

name_ids = sources |> 
  filter(upos == "PROPN", (lag(upos) != "PROPN") | lag(quote_id) != quote_id) |>
  mutate(name_id = seq_along(quote_id)) |> 
  select(doc_id, sentence, token_id, name_id)

names = left_join(sources, name_ids) |> 
  filter(upos == "PROPN") |> 
  tidyr::fill(name_id) |> 
  group_by(doc_id, name_id) |>
  summarize(last_name=last(token), full_name=str_c(token, collapse=" ")) 

all_names = sources |> filter(upos == "PROPN") |> group_by(lemma) |> summarize(n=n()) |> arrange(-n)
last_names = names |> group_by(last_name) |> summarize(n=n()) |> arrange(-n)
full_names = names |> group_by(full_name) |> summarize(n=n()) |> arrange(-n)

write_csv(full_names,"data/bronnen.csv")
gecodeerd = read_csv("data/bronnen.csv") |> select(-n)

bronnen_gecodeerd = names|>
  left_join(gecodeerd)|>
  mutate(doc_id=as.character(doc_id))

bronnen_gecodeerd2=d_nieuws2|>
  rename(doc_id=unit_id)|>
  left_join(bronnen_gecodeerd)

write_csv(bronnen_gecodeerd2,"data/gecodeerde_bronnen.csv")

# view all quotes
library(tokenbrowser)
categorical_browser(annotated, category=annotated$quote, token_col="token") |> browseURL()

# view a single quote
x = tokens |> filter(doc_id == '0028ec8033bcab44c4638156d9d2d69c92a50c75c313a9b4b5dd672e') |> 
  annotate_tqueries("quote", queries)
categorical_browser(x, category=x$quote, token_col="token") |> browseURL()
x |> filter(str_detect(token, "benadrukte")) |> select(sentence, token)
plot_tree(x, sentence_i=11, lemma, upos, annotation = 'quote')

# test single sentence
udpipe('Dat het niet goed is wordt al lang door Piet gezegd', 'dutch') |> add_column(next_start_quote=T) |> annotate_tqueries("quote", queries) |> plot_tree(token, lemma, annotation='quote')


prop_quotes = sources |> filter(upos == "PROPN") |> select(quote_id)
all_prop_sources = sources |> semi_join(prop_quotes) |> group_by(quote_id) |> summarize(source=str_c(token, collapse=" "))
write_csv(all_prop_sources,"data/bronnen_context.csv")

