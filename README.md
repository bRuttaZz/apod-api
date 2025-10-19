# APOD cache server & API
![smoketest-status](https://github.com/bruttazz/apod-api/actions/workflows/smoketest.yml/badge.svg)


**A dead simple API that scrap, cache and serve APOD (Astronomy Picture of the Day) info from  [nasa](https://apod.nasa.gov/apod/) / [star.ucl](http://www.star.ucl.ac.uk/~apod/apod/)!**

**Inspired from** the activitypub bot, [@apod@reentry.codl.fr](https://reentry.codl.fr/@apod)

### API Endpoints

- GET `/api/v1/apod.json`

### Usage
```sh
curl http://localhost:8000/api/v1/apod.json -s | jq
{
  "credits": "www.star.ucl.ac.uk",
  "img": "http://localhost:8000/api/v1/apod-img.jpg",
  "description": "Put on your red/blue glasses and float next to asteroid 101955 Bennu. Shaped like a spinning toy top with boulders littering its rough surface, the tiny Solar System world is about one Empire State Building (less than 500 metres) across. Frames used to construct this 3D anaglyph were taken by PolyCam on the OSIRIS_REx spacecraft on December 3, 2018 from a distance of about 80 kilometres. With a sample from the asteroid's rocky surface on board, OSIRIS_REx departed Bennu's vicinity in May of 2021. The robotic spacecraft successfully returned the sample to its home world in September of 2023.",
  "title": "3D Bennu",
  "source": "http://www.star.ucl.ac.uk/~apod/apod/",
  "date": "2025-10-19"
}
```

### Env Vars:
- `APOD_PAGE_URL` (defaults to `http://www.star.ucl.ac.uk/~apod/apod/`, compatable with `https://apod.nasa.gov/apod/` (but the site is dead today))
- `SERVICE_BASE_URL` (defaults to empty string, eg: `http://localhost:8000` )
- `APOD_PAGE_MAX_SIZE` (defaults to 50kb) -- to save your server
- `APOD_IMG_MAX_SIZE` (defaults to 10Mb) -- to save your server

### Pre-built docker images:
- `bruttazz/apod-api`

### Live Endpoints
- [https://apod.brutt.site/api/v1/apod.json](https://apod.brutt.site/api/v1/apod.json)

### Credits
All rights reserved to respective sites: [star.ucl](http://www.star.ucl.ac.uk/~apod/apod/) / [nasa](https://apod.nasa.gov/apod/)
