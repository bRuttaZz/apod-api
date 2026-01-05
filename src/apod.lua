local _apod_info_generator = {}

local settings = require("settings")

local ffi = require("ffi")
local htmlparser = require("htmlparser")
local http = require("resty.http")
local cjson = require("cjson")


cjson.encode_escape_forward_slash(false)

ffi.cdef [[
    typedef struct FILE FILE;
    FILE *fopen(const char *path, const char *mode);
    int fclose(FILE *fp);
    size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
]]


-- Get url content
-- @param url string HTTP(s) url string
local function _get_url_content(url)
    local httpc = http.new()
    local res, err = httpc:request_uri(url, {
        ssl_verify = false,
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:144.0) Gecko/20100101 Firefox/144.0",
            ["Host"] = url:match("^%w+://([^/]+)")
        },
    })
    if not res then
        return nil, "APOD Page Request Failed: " .. err
    end
    local status = res.status
    if status ~= 200 then
        return nil, "APOD Page Request Failed with Status Code: " .. status
    end
    return res, ""
end


-- Write content to file (to be served via openresty)
-- @param fname string Filename to write
-- @param content string Data to be write
-- @param mode string file open mode 'w' or 'wb'
local function _write_to_serve_file(fname, content, mode)
    local C = ffi.C
    mode = mode or "w"
    fname = settings.WWW_DIR .. "/" .. fname

    local file = C.fopen(fname, mode)
    if file == nil then
        return nil, "Failed to open file: " .. fname
    end

    local length = #content
    if mode == "wb" then
        content = ffi.cast("const char *", content)
    end
    local bytes_written = C.fwrite(content, length, 1, file)
    C.fclose(file)
    bytes_written = tonumber(bytes_written)
    if bytes_written ~= 1 then
        return nil, "Failed to write data to file: (" .. bytes_written .. ") | " .. fname
    end
    return true, ""
end

-- Extract image extension from url string
-- @param url string URL
function _apod_info_generator._get_img_extension(url)
    url = url:match("^[^?#]+") -- removes query
    local filename = url:match("^.*/([^/]+)$") or url
    local ext = filename:match("%.([a-zA-Z0-9]+)$")
    return ext and "." .. ext:lower() or ""
end

-- Get NASA's APOD html page
-- @returns string html page
function _apod_info_generator.get_page()
    local res, err = _get_url_content(settings.APOD_PAGE_URL)
    if not res then
        return nil, err
    end
    local length = tonumber(res.headers["Content-Length"])
    if not length or tonumber(length) > settings.APOD_PAGE_MAX_SIZE then
        return nil, "APOD Page Response too long: " .. length
    end
    return res.body, ""
end

-- Get NASA's APOD image
-- @param url string url of the image
function _apod_info_generator.get_img(url)
    local res, err = _get_url_content(url)
    if not res then
        return nil, err
    end
    local length = tonumber(res.headers["Content-Length"])
    if not length or tonumber(length) > settings.APOD_IMG_MAX_SIZE then
        return nil, "APOD Page Response too long: " .. length
    end
    return res.body, _apod_info_generator._get_img_extension(url)
end

-- Parse NASA's APOD html page into relevent metadata
-- @param html_str  string HTML string to parse
-- @returns table Table with extracted img, description and title
function _apod_info_generator.parse_page(html_str)
    local outs = { img = nil, description = nil, title = nil }

    -- normalize tag names
    html_str = html_str
        :gsub("<%s*(/?)%s*([%w_:-]+)", function(slash, tag)
            return "<" .. slash .. tag:lower()
        end)
    local root = htmlparser.parse(html_str)

    -- find the image
    local img_tag = root:select("img")[1]
    if img_tag then
        outs.img = img_tag.attributes.src or img_tag.attributes.SRC
    end
    if not outs.img then
        return nil
    else
        -- sanitize img url
        if outs.img:sub(1, 4) ~= "http" then
            if outs.img:sub(1, 1) == "/" then
                outs.img = settings.APOD_PAGE_URL:match("^(https?://[^/]+)") .. outs.img
            else
                local url = settings.APOD_PAGE_URL:match("^[^?]+") or settings.APOD_PAGE_URL
                if url:sub(-1) == "/" then
                    url = url:sub(1, -2)
                end
                outs.img = url .. "/" .. outs.img
            end
        end
    end


    -- extract title
    local center = root:select("center")[2]
    if center then
        local b_ = center:select("b")[1]
        if b_ then
            outs.title = b_:textonly():gsub("%s+", " "):match("^%s*(.-)%s*$")
        end
    end

    -- extract description
    local last_center = root:select("center")[3]
    if last_center then
        local start      = center._closeend + 1
        local end_       = last_center._openstart - 1
        local dscrpt     = root._text:sub(start, end_):gsub("<[^>]*>", "")
        dscrpt           = dscrpt:gsub("Explanation:", ""):gsub("%s+", " ")
        outs.description = dscrpt:match("^%s*(.-)%s*$")
    end

    return outs
end

-- Extract APOD info
function _apod_info_generator.extract()
    local html, err = _apod_info_generator.get_page()
    if not html then
        ngx.log(ngx.ERR, "Error extracing new APOD page: ", err)
        return nil
    end
    local info = _apod_info_generator.parse_page(html)
    if not info then
        ngx.log(ngx.ERR, "Page structure change! Unable to parse content.")
        return nil
    end

    -- get image
    local img, ext = _apod_info_generator.get_img(info.img)
    if not img then
        ngx.log(ngx.ERR, "Error retreiving APOD image: ", ext)
        return nil
    end
    local img_name = "apod-img" .. ext
    local status, err_ = _write_to_serve_file(img_name, img, "wb")
    if not status then
        ngx.log(ngx.ERR, "Error writing IMG to disc: ", err_)
        return nil
    end
    ngx.log(ngx.INFO, "Retrieved new APOD image: ", info.date)

    -- write info
    info.img = settings.SERVICE_BASE_URL .. settings.API_PREFIX .. img_name
    info.date = os.date("%Y-%m-%d-%H-%M-%S")
    info.source = settings.APOD_PAGE_URL
    info.credits = settings.APOD_HOST

    local jsons = cjson.encode(info)
    status, err_ = _write_to_serve_file("apod.json", jsons, "w")
    if not status then
        ngx.log(ngx.ERR, "Error writing JSON to disc: ", err_)
        return nil
    end


    return info
end

return _apod_info_generator
