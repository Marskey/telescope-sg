local health = vim.health or require "health"
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error

local is_win = vim.api.nvim_call_function("has", { "win32" }) == 1
local is_linux = vim.api.nvim_call_function("has", { "linux" }) == 1

local optional_dependencies = {
    {
        package = {
            {
                name = is_linux and "ast-grep" or "sg",
                url = "[ast-grep/ast-grep](https://github.com/ast-grep/ast-grep)",
                optional = false,
            },
        },
    },
}

local check_binary_installed = function(package)
    local binaries = package.binaries or { package.name }
    for _, binary in ipairs(binaries) do
        if is_win then
            binary = binary .. ".exe"
        end
        if vim.fn.executable(binary) == 1 then
            local handle = io.popen(binary .. " --version")
            local binary_version = handle:read "*a"
            handle:close()
            return true, binary_version
        end
    end
end

local version_need = "0.10.0"

local check_sg_version = function(version)
    local parse_str_ver = function (str_ver)
        local major, minor, patch = str_ver:match "(%d+)%.(%d+)%.(%d+)"
        return tonumber(major), tonumber(minor), tonumber(patch)
    end

    local major, minor, patch = parse_str_ver(version)
    local major_need, minor_need, patch_need = parse_str_ver(version_need)

    if not major or not minor or not patch then
        return false
    end

    if not major_need or not minor_need or not patch_need then
        return false
    end

    return major > major_need
        or (major == major_need and minor > minor_need)
        or (major == major_need and minor == minor_need and patch >= patch_need)
end

local M = {}

M.check = function()
    for _, opt_dep in pairs(optional_dependencies) do
        for _, package in ipairs(opt_dep.package) do
            local installed, version = check_binary_installed(package)
            if not installed then
                local err_msg = ("%s: not found."):format(package.name)
                if package.optional then
                    warn(("%s %s"):format(err_msg, ("Install %s for extended capabilities"):format(package.url)))
                else
                    error(
                        ("%s %s"):format(
                            err_msg,
                            ("ast-grep picker will not function without %s installed."):format(package.url)
                        )
                    )
                end
            else
                local eol = version:find "\n"
                version = version:sub(1, eol - 1)
                if check_sg_version(version) then
                    ok(("%s: found %s"):format(package.name, version))
                else
                    error(("%s: found %s, but %s needed"):format(package.name, version or "(unknown version)",
                        version_need))
                end
            end
        end
    end
end

return M
