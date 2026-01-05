local _settings = {
    APOD_PAGE_URL = os.getenv("APOD_PAGE_URL") or
        "https://apod.nasa.gov/apod/" or
        "http://www.star.ucl.ac.uk/~apod/apod/",
    SERVICE_BASE_URL = os.getenv("SERVICE_BASE_URL") or "",                   -- without trailing slash

    APOD_PAGE_MAX_SIZE = tonumber(os.getenv("APOD_PAGE_MAX_SIZE")) or 50000,  -- average ~4397
    APOD_IMG_MAX_SIZE = tonumber(os.getenv("APOD_IMG_MAX_SIZE")) or 10000000, -- average ~362026

    WWW_DIR = os.getenv("WWW_DIR") or ".",                                    -- without trailing slash
    API_PREFIX = "/api/v1/",

    REFRESH_AFTER_HR = tonumber(os.getenv("REFRESH_AFTER_HR")) or 2,
}
_settings.APOD_HOST = _settings.APOD_PAGE_URL:match("^%w+://([^/]+)")
_settings.REFRESH_AFTER_S = _settings.REFRESH_AFTER_HR * 60 * 60

if os.getenv("LOCAL_ENV") then
    package.path = "./deps/lua-htmlparser/src/?.lua;" .. package.path
end

return _settings
