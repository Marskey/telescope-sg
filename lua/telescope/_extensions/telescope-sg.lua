local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local make_entry = require "telescope.make_entry"

local Path = require "plenary.path"
local flatten = vim.tbl_flatten
local filter = vim.tbl_filter

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
---@field search_dirs table? list of directories to search in
---@field grep_open_files boolean to restrict search to open files
---@field lang string? code language to filter on
---@field cwd string? current working directory
---@field entry_maker function? function to create entry
---@field json_output boolean output in json format(not implemented yet, wait ast-grep support one line json output)
local setup_opts = {}

M.setup = function (opts)
    setup_opts = vim.tbl_deep_extend("force", setup_opts, opts)
end

---@param opts setup_opts
M.ast_grep = function(opts)
    local command = {
        "sg",
        "--heading",
        "never",
        "-p",
    }

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
        additional_args[#additional_args + 1] = "-l=" .. opts.lang
    end

    if opts.json_output then
        additional_args[#additional_args + 1] = "--json"
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

        return flatten { command, prompt, args, search_list }
    end

    local ast_grepper
    if not opts.json_output then
        -- to make parse_without_col
        opts.__inverted = true

        ast_grepper = finders.new_job(command_generator, opts.entry_maker or make_entry.gen_from_vimgrep(opts), nil,
            opts.cwd)
        -- wait ast-grep support one line json output
    end

    pickers
        .new(opts, {
            prompt_title = "Ast Grep",
            finder = ast_grepper,
            previewer = conf.grep_previewer(opts),
            sorter = conf.generic_sorter(opts),
        })
        :find()
end

return require("telescope").register_extension {
    setup = M.setup,
    exports = {
        ast_grep = M.ast_grep,
    },
}
