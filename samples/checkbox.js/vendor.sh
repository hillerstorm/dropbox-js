mkdir -p public/lib
curl --fail https://cdnjs.cloudflare.com/ajax/libs/jquery/1.9.1/jquery.min.js \
    > public/lib/jquery.min.js
curl --fail https://cdnjs.cloudflare.com/ajax/libs/jquery/1.9.1/jquery.js \
    > public/lib/jquery.js
curl --fail https://cdnjs.cloudflare.com/ajax/libs/jquery/1.9.1/jquery.min.map \
    > public/lib/jquery.min.map
curl --fail https://cdnjs.cloudflare.com/ajax/libs/coffee-script/1.4.0/coffee-script.min.js \
    > public/lib/coffee-script.js
curl --fail https://cdnjs.cloudflare.com/ajax/libs/less.js/1.3.3/less.min.js \
    > public/lib/less.js
curl --fail https://cdnjs.cloudflare.com/ajax/libs/dropbox.js/0.9.1/dropbox.min.js \
    > public/lib/dropbox.min.js
curl --fail https://cdnjs.cloudflare.com/ajax/libs/dropbox.js/0.9.1/dropbox.js \
    > public/lib/dropbox.js
curl --fail https://cdnjs.cloudflare.com/ajax/libs/dropbox.js/0.9.1/dropbox.min.map \
    > public/lib/dropbox.min.map
