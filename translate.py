import requests



r = requests.get("http://localhost:24080/translate", dict(target_lang='en', text='Spreekt u ook Nederlands?'))