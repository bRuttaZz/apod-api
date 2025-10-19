local settings = require("settings")

local ffi = require("ffi")
local apod = require("apod")

ffi.cdef [[
    typedef struct FILE FILE;

    FILE *fopen(const char *filename, const char *mode);
    int fseek(FILE *stream, long offset, int whence);
    long ftell(FILE *stream);
    int fclose(FILE *stream);

    enum {
        SEEK_SET = 0,
        SEEK_CUR = 1,
        SEEK_END = 2
    };
]]

local _tests = {}
local info = nil

function _tests.completion()
    assert(info ~= nil)
end

function _tests.json_extraction()
    assert(info ~= nil)
    assert(info.img ~= nil)
    assert(info.date ~= nil)
    assert(info.title ~= nil)
    assert(info.description ~= nil)
    assert(info.source ~= nil)
    assert(info.credits ~= nil)
end

function _tests.img_extraction()
    assert(info ~= nil)
    assert(info.img ~= nil)

    local C = ffi.C
    local fname = settings.WWW_DIR .. "/apod-img" .. apod._get_img_extension(info.img)

    local file = C.fopen(fname, 'rb')
    assert(file ~= nil)                       -- open error
    assert(C.fseek(file, 0, C.SEEK_END) == 0) -- fseek failure

    local size = C.ftell(file)
    C.fclose(file)
    assert(size ~= -1)
    assert(size > 0) -- have a valid file size
end

local function main()
    ngx.say("Running tests..")
    info = apod.extract()
    for name, fun in pairs(_tests) do
        ngx.say("test: " .. name .. " ..")
        fun()
        ngx.say("passed: " .. name .. "✅")
    end
    ngx.say("Ok 💯!")
end

main()
