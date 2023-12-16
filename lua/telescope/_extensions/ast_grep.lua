local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local sorters = require "telescope.sorters"
local utils = require "telescope.utils"

local Path = require "plenary.path"
local flatten = vim.tbl_flatten
local filter = vim.tbl_filter

local is_linux = vim.api.nvim_call_function("has", { "linux" }) == 1

local get_open_filelist = function(grep_open_files, cwd)
    if not grep_open_files then
        return nil
    end

    local bufnrs = filter(function(b)
        if 1 ~= vim.fn.buflisted(b) then
            return false
        end
        return true
    end, vim.api.nvim_list_bufs())
    if not next(bufnrs) then
        return nil
    end

    local filelist = {}
    for _, bufnr in ipairs(bufnrs) do
        local file = vim.api.nvim_buf_get_name(bufnr)
        table.insert(filelist, Path:new(file):make_relative(cwd))
    end
    return filelist
end

local M = {}

---@class setup_opts
---@field command table? command to run
---@field search_dirs table? list of directories to search in
---@field grep_open_files boolean to restrict search to open files
---@field lang string? code language to filter on
---@field cwd string? current working directory
---@field entry_maker function? function to create entry
local setup_opts = {}

M.setup = function(opts)
    setup_opts = vim.tbl_deep_extend("force", setup_opts, opts)
end

local handle_entry_index = function(opts, t, k)
    local override = ((opts or {}).entry_index or {})[k]
    if not override then
        return
    end

    local val, save = override(t, opts)
    if save then
        rawset(t, k, val)
    end
    return val
end

M.gen_from_json = function(opts)
    opts = opts or {}
    local cwd = vim.fn.expand(opts.cwd or vim.loop.cwd() or "")

    local mt_vimgrep_entry

    local disable_devicons = opts.disable_devicons
    local disable_coordinates = opts.disable_coordinates

    local display_string = "%s%s%s"

    mt_vimgrep_entry = {
        cwd = vim.fn.expand(opts.cwd or vim.loop.cwd()),

        display = function(entry)
            local display_filename = utils.transform_path(opts, entry.filename)

            local coordinates = ":"
            if not disable_coordinates then
                if entry.lnum then
                    if entry.col then
                        coordinates = string.format(":%s:%s:", entry.lnum, entry.col)
                    else
                        coordinates = string.format(":%s:", entry.lnum)
                    end
                end
            end

            local display, hl_group, icon = utils.transform_devicons(
                entry.filename,
                string.format(display_string, display_filename, coordinates, entry.text),
                disable_devicons
            )

            if hl_group then
                return display, { { { 0, #icon }, hl_group } }
            else
                return display
            end
        end,

        __index = function(t, k)
            local override = handle_entry_index(opts, t, k)
            if override then
                return override
            end

            local raw = rawget(mt_vimgrep_entry, k)
            if raw then
                return raw
            end

            if k == "path" then
                return Path:new({ cwd, t.filename }):absolute()
            end

            if k == "text" then
                return t.value
            end

            if k == "ordinal" then
                local text = t.text
                return opts.only_sort_text and text or text .. " " .. t.filename
            end
        end,
    }

    return function(line)
        local msg = vim.json.decode(line)
        if msg == nil then
            return
        end

        local raw_text = msg.lines and msg.lines or msg.text
        local text = raw_text:gsub("[\r|\n|\t]", "")
        return setmetatable({
            value = text,
            filename = msg.file,
            lnum = msg.range.start.line + 1,
            lnend = msg.range['end'].line + 1,
            col = msg.range.start.column + 1,
            colend = msg.range['end'].column + 1,
        }, mt_vimgrep_entry)
    end
end

---@param opts setup_opts
M.ast_grep = function(opts)
    local command = opts.command or {
        is_linux and "ast-grep" or "sg",
        "--json=stream",
    }

    vim.tbl_filter(function(x)
        return x ~= "-p" and x~= "--pattern"
    end, command)

    opts = vim.tbl_deep_extend("force", setup_opts, opts or {})
    local search_dirs = opts.search_dirs
    local grep_open_files = opts.grep_open_files
    opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

    local filelist = get_open_filelist(grep_open_files, opts.cwd)
    if search_dirs then
        for i, path in ipairs(search_dirs) do
            search_dirs[i] = vim.fn.expand(path)
        end
    end

    local additional_args = {}
    if opts.lang then
        additional_args[#additional_args + 1] = "-l"
        additional_args[#additional_args + 1] = opts.lang
    end

    local args = flatten { additional_args }

    local command_generator = function(prompt)
        if not prompt or prompt == "" then
            return nil
        end

        local search_list = {}

        if grep_open_files then
            search_list = filelist or {}
        elseif search_dirs then
            search_list = search_dirs
        end

        return flatten { command, "-p", prompt, args, search_list }
    end

    local ast_grepper = finders.new_job(command_generator, opts.entry_maker or M.gen_from_json(opts), nil,
        opts.cwd)

    pickers
        .new(opts, {
            prompt_title = "Ast Grep",
            finder = ast_grepper,
            previewer = conf.grep_previewer(opts),
            sorter = sorters.highlighter_only(opts),
        })
        :find()
end

return require("telescope").register_extension {
    setup = M.setup,
    exports = {
        ast_grep = M.ast_grep,
    },
    health = require("ast_grep_health").check,
}
