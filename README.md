photobot
========

sync photo to flickr

----

puts all you photos inside the `data` folder. 

the sub folder name would become the album name.

content of `/data/config.json`

    {
      "api_key": "<api key>",
      "api_secret": "<api secrect>",
      "access_token": "<access token>",
      "access_secret": "<access secret>"
    }

you can find the `api_key` and and `api_secret` in you flickr account settings.

the `access_token` and `access_secret` is generated with the `login.rb` cmd.
