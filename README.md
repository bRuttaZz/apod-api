**A dead simple API that scrap, cache and serve APOD (Astronomy Picture of the Day) info from  [nasa](https://apod.nasa.gov/apod/) / [star.ucl](http://www.star.ucl.ac.uk/~apod/apod/)!**

Inspired from: [@apod@reentry.codl.fr](https://reentry.codl.fr/@apod)

Usage:
```sh
curl http://127.0.0.1:8000/api/v1/apod/ | jq
{
    "img": "<http url>",
    "description": "",
    "title": "",
    "date": "YYYY-MM-DD",
}
```


Env Vars:
- `APOD_SITE_URL` (defaults: `http://www.star.ucl.ac.uk/~apod/apod/`, compatable with `https://apod.nasa.gov/apod/` (but the site is dead today))

dockers:
  - bruttazz/apod-api

live-apis:
  - apod.brutt.site/api/v1/apod

All rights reserved to respective sites: [star.ucl](http://www.star.ucl.ac.uk/~apod/apod/) / [nasa](https://apod.nasa.gov/apod/)
