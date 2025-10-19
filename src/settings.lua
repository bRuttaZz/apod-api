local _settings = {
    APOD_PAGE_URL = os.getenv("APOD_PAGE_URL") or "http://www.star.ucl.ac.uk/~apod/apod/",
    SERVICE_BASE_URL = os.getenv("SERVICE_BASE_URL") or "",                   -- without trailing slash

    APOD_PAGE_MAX_SIZE = tonumber(os.getenv("APOD_PAGE_MAX_SIZE") or 50000),  -- average ~4397
    APOD_IMG_MAX_SIZE = tonumber(os.getenv("APOD_IMG_MAX_SIZE") or 10000000), -- average ~362026

    WWW_DIR = os.getenv("WWW_DIR") or ".",                                    -- without trailing slash
    API_PREFIX = "/api/v1/"
}
_settings.APOD_HOST = _settings.APOD_PAGE_URL:match("^%w+://([^/]+)")
-- _settings.APOD_INFO_FILE = _settings.WWW_DIR .. "../",

if os.getenv("LOCAL_ENV") then
    package.path = "./deps/lua-htmlparser/src/?.lua;" .. package.path
end

return _settings
