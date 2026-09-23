-- linux
if vim.loader then
    vim.loader.enable()
end

local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

    if fn.empty(fn.glob(install_path)) > 0 then
        print("🔄 Instalando packer.nvim...")
        fn.system({
            'git',
            'clone',
            '--depth',
            '1',
            'https://github.com/wbthomason/packer.nvim',
            install_path
        })
        vim.cmd('packadd packer.nvim')
        return true
    end

    return false
end

local packer_bootstrap = ensure_packer()

------------------------------------------------------------
-- OPÇÕES BÁSICAS
------------------------------------------------------------
vim.deprecate = function() end
--vim.opt.guicursor = "" -- comando que faz com que seja bloco ao inves de linha
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt_local.laststatus = 0
vim.g.mapleader = " "
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt_local.ruler = false
vim.opt_local.showmode = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.timeoutlen = 300
vim.opt.updatetime = 50
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0
vim.o.statusline = " [FILENAME: %t] %= [TYPE: %Y] [LINE: %l/%L : %c] [%p%%] %{Modified_Get()}"
vim.o.laststatus = 2
vim.o.shortmess = vim.o.shortmess .. "atI"
vim.o.cmdheight = 1

vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"

        vim.opt_local.winbar = "%{get(b:, 'netrw_curdir', '')}"
    end,
})

vim.cmd([[
function! Modified_Get()
    return &modified ? '[+]' : ''
endfunction
]])

local function web_search()
    local query = vim.fn.input("Search: ")

    if query == "" then
        return
    end

    local encoded = vim.fn.system({
        "curl",
        "-sG",
        "--data-urlencode",
        "q=" .. query,
        "-o",
        "/dev/null",
        "-w",
        "%{url_effective}",
        "https://html.duckduckgo.com/html/",
    })

    encoded = encoded:gsub("\n$", "")

    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "websearch"

    local width = math.floor(vim.o.columns * 0.80)
    local height = math.floor(vim.o.lines * 0.70)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = " Search: " .. query .. " ",
        title_pos = "center",
    })

    vim.wo[win].cursorline = true
    vim.wo[win].wrap = true

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "",
        "  Searching...",
        "",
    })

    vim.fn.jobstart({
        "curl",
        "-Ls",
        "-A",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/146 Safari/537.36",
        "-e",
        "https://html.duckduckgo.com/",
        "-d",
        "q=" .. query,
        "https://html.duckduckgo.com/html/",
    }, {
        stdout_buffered = true,

        on_stdout = function(_, data)
            if not data or #data == 0 then
                return
            end

            vim.schedule(function()
                local html = table.concat(data, "\n")
                local results = {}

                for block in html:gmatch(
                    '<a rel="nofollow" class="result__a".-</a>'
                ) do
                    local link = block:match(
                        'href="([^"]+)"'
                    )

                    local title = block:match(
                        '>(.-)</a>'
                    )

                    if link and title then
                        title = title:gsub("<[^>]+>", "")

                        title = title:gsub("&amp;", "&")
                        title = title:gsub("&quot;", '"')
                        title = title:gsub("&#x27;", "'")
                        title = title:gsub("&lt;", "<")
                        title = title:gsub("&gt;", ">")

                        table.insert(results, {
                            title = vim.trim(title),
                            link = link,
                        })
                    end
                end

                local lines = {
                    " Results: " .. query,
                    "",
                }

                if #results == 0 then
                    table.insert(lines, " No results.")
                else
                    for i, result in ipairs(results) do
                        table.insert(
                            lines,
                            string.format(" %d. %s", i, result.title)
                        )

                        table.insert(
                            lines,
                            "    " .. result.link
                        )

                        table.insert(lines, "")
                    end
                end

                vim.bo[buf].modifiable = true

                vim.api.nvim_buf_set_lines(
                    buf,
                    0,
                    -1,
                    false,
                    lines
                )

                vim.bo[buf].modifiable = false
            end)
        end,

        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.schedule(function()
                    vim.notify(
                        "Error: " .. table.concat(data, " "),
                        vim.log.levels.ERROR
                    )
                end)
            end
        end,
    })

    vim.keymap.set("n", "q", "<cmd>close<CR>", {
        buffer = buf,
        silent = true,
    })

    vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", {
        buffer = buf,
        silent = true,
    })

    vim.keymap.set("n", "<CR>", function()
        local line = vim.api.nvim_get_current_line()

        local link = line:match("https?://%S+")

        if link then
            vim.fn.jobstart({
                "xdg-open",
                link,
            }, {
                detach = true,
            })
        end
    end, {
        buffer = buf,
        silent = true,
    })
end

vim.keymap.set("n", "<leader>/", web_search, {
    desc = "Web search",
})

local function get_repo_name(cwd)
    local dir = cwd
    while dir and dir ~= "" do
        if vim.uv.fs_stat(dir .. "/.git") then
            return vim.fn.fnamemodify(dir, ":t")
        end
        local parent = vim.fn.fnamemodify(dir, ":h")
        if parent == dir then break end
        dir = parent
    end
    return vim.fn.fnamemodify(cwd, ":t")
end

local function is_diffview_tab(tabnr)
    local ok, tabid = pcall(function() return vim.api.nvim_list_tabpages()[tabnr] end)
    if not ok or not tabid then return false end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabid)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype
        if ft:match("^Diffview") then
            return true
        end
    end

    return false
end

function _G.NvimTabLine()
    local s = ""

    for i = 1, vim.fn.tabpagenr("$") do
        local winnr = vim.fn.tabpagewinnr(i)
        local buflist = vim.fn.tabpagebuflist(i)
        local bufnr = buflist[winnr]
        local cwd = vim.fn.getcwd(-1, i)
        local repo = get_repo_name(cwd)

        local label
        if is_diffview_tab(i) then
            label = "Diff: " .. repo
        else
            local fname = vim.fn.bufname(bufnr)
            fname = (fname ~= "" and vim.fn.fnamemodify(fname, ":t")) or "[No Name]"
            label = repo .. " - " .. fname
        end

        if i == vim.fn.tabpagenr() then
            s = s .. "%#TabLineSel#"
        else
            s = s .. "%#TabLine#"
        end

        s = s .. "%" .. i .. "T" .. " " .. label .. " "
    end

    s = s .. "%#TabLineFill#"
    return s
end

vim.o.tabline = "%!v:lua.NvimTabLine()"

local function setup_autopairs()
    local pairs_map = {
        ['('] = ')',
        ['['] = ']',
        ['{'] = '}',
        ['"'] = '"',
        ["'"] = "'",
        ['`'] = '`',
    }

    local function insert_pair(l, r)
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local before = line:sub(1, col)
        local after = line:sub(col + 1)

        if after:sub(1, 1) == r then
            vim.api.nvim_win_set_cursor(0, { vim.fn.line('.'), col + 1 })
        else
            vim.api.nvim_set_current_line(before .. l .. r .. after)
            vim.api.nvim_win_set_cursor(0, { vim.fn.line('.'), col + 1 })
        end
    end

    for l, r in pairs(pairs_map) do
        vim.keymap.set('i', l, function()
            insert_pair(l, r)
        end, { noremap = true, silent = true })
    end
end

setup_autopairs()

local function setup_dashboard()
    vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("Dashboard", { clear = true }),
        callback = function()
            if vim.fn.argc() > 0 then return end

            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            if #lines > 1 or (#lines == 1 and #lines[1] > 0) then return end

            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].filetype = "dashboard"

            vim.api.nvim_win_set_buf(0, buf)

            local win = 0
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
            vim.opt_local.cursorline = false
            vim.opt_local.cursorcolumn = false
            vim.opt_local.signcolumn = "no"
            vim.opt_local.fillchars = { eob = " " }

            local original_guicursor = vim.o.guicursor
            vim.api.nvim_set_hl(0, "DashboardCursor", { blend = 100, nocombine = true })

            local function hide_cursor()
                vim.opt.guicursor = "a:DashboardCursor"
            end

            local function restore_cursor()
                vim.opt.guicursor = original_guicursor
            end

            hide_cursor()

            vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "VimLeavePre" }, {
                buffer = buf,
                callback = restore_cursor,
            })

            vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
                buffer = buf,
                callback = hide_cursor,
            })

            local logo = {
            }

            local menu = {
                "[n] New File ",
                "[f] Find File",
                "    [e] File Explorer",
                " [wq] Quit     ",
            }

            local width = vim.api.nvim_win_get_width(win)
            local height = vim.api.nvim_win_get_height(win)

            local function center(text_lines)
                local res = {}
                for _, line in ipairs(text_lines) do
                    local pad = math.floor((width - #line) / 2)
                    table.insert(res, string.rep(" ", pad) .. line)
                end
                return res
            end

            local content = {}
            local total_lines = #logo + #menu + 2
            local top_pad = math.floor((height - total_lines) / 2)

            for _ = 1, top_pad do table.insert(content, "") end
            for _, l in ipairs(center(logo)) do table.insert(content, l) end
            table.insert(content, "")
            table.insert(content, "")
            for _, l in ipairs(center(menu)) do table.insert(content, l) end

            vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
            vim.bo[buf].modifiable = false

            local opts = { buffer = buf, noremap = true, silent = true }

            vim.keymap.set("n", "n", function()
                restore_cursor()
                vim.cmd("enew")
            end, opts)

            vim.keymap.set("n", "e", function()
                restore_cursor()
                vim.cmd.Ex()
            end, opts)

            vim.keymap.set("n", "f", function()
                restore_cursor()
                if pcall(require, 'fzf-lua') then
                    require('fzf-lua').files()
                else
                    vim.notify("FZF-Lua não está carregado", vim.log.levels.WARN)
                end
            end, opts)

            vim.keymap.set("n", "wq", ":q!<CR>", opts)
        end,
    })
end

require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use {
        'ibhagwan/fzf-lua',
        requires = { 'nvim-lua/plenary.nvim' },
    }
    use {
        'williamboman/mason.nvim',
        tag = 'v1.10.0',
    }
    use { 'tahayvr/matteblack.nvim', as = 'matteblack' }
    use 'xero/miasma.nvim'
    use {
        'nvim-treesitter/nvim-treesitter',
        run = function()
            require('nvim-treesitter.install').update({ with_sync = true })
        end,
    }

    use 'mbbill/undotree'
    use 'tpope/vim-fugitive'
    use 'neovim/nvim-lspconfig'
    use {
        'saghen/blink.cmp',
        tag = 'v1.10.1',
        requires = { 'rafamadriz/friendly-snippets' },
    }
    use 'rose-pine/neovim'
    use 'theprimeagen/harpoon'
    use "sindrets/diffview.nvim"

    use { 'folke/zen-mode.nvim' }
    use { 'eero-lehtinen/oklch-color-picker.nvim' }

    use "folke/which-key.nvim"

    use 'dchinmay2/alabaster.nvim'

    use 'martinsione/darkplus.nvim'

    use 'mg979/vim-visual-multi'

    use {
        'nvim-tree/nvim-tree.lua',
        requires = { 'nvim-tree/nvim-web-devicons' },
    }

    use 'nvim-neotest/nvim-nio'
    use {
        'nvim-neotest/neotest',
        requires = {
            'nvim-lua/plenary.nvim',
            'nvim-treesitter/nvim-treesitter',
            'nvim-neotest/nvim-nio',
            'nvim-neotest/neotest-python',
            'nvim-neotest/neotest-jest',
        },
    }

    use 'stevearc/conform.nvim'

    use 'windwp/nvim-ts-autotag'

    use {
        'folke/trouble.nvim',
        requires = { 'nvim-tree/nvim-web-devicons' },
    }

    use "flaviodelgrosso/min-theme.nvim"

    use {
        'williamboman/mason-lspconfig.nvim',
        tag = 'v1.0.0',
        requires = { 'williamboman/mason.nvim' },
    }

    if packer_bootstrap then
        require('packer').sync()
    end
end)

local function post_install_setup()
    setup_dashboard()

    pcall(function()
        require('fzf-lua').setup({
            winopts = {
                height = 0.85,
                width = 0.85,
                row = 0.5,
                col = 0.5,
                border = 'rounded',
            },
            files = {
                prompt = 'Files❯ ',
            },
            grep = {
                prompt = 'Grep❯ ',
            },
        })
    end)

    pcall(function()
        require("mason").setup()
    end)

    pcall(function()
        require('blink.cmp').setup({
            keymap = {
                preset = 'default',
                ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
                ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
                ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
                ['<C-n>'] = { 'select_next', 'fallback' },
                ['<C-p>'] = { 'select_prev', 'fallback' },
                ['<C-e>'] = { 'hide' },
                ['<C-y>'] = { 'accept' },
            },

            completion = {
                documentation = {
                    auto_show = false,
                },
                menu = {
                    auto_show = true,
                    draw = {
                        columns = { { "label", "label_description", gap = 1 } },
                    },
                },
                list = {
                    max_items = 10,
                    selection = {
                        preselect = false,
                        auto_insert = true,
                    },
                },
            },

            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer' },
                providers = {
                    lsp = {
                        name = 'LSP',
                        module = 'blink.cmp.sources.lsp',
                        score_offset = 100,
                    },
                    path = {
                        name = 'Path',
                        module = 'blink.cmp.sources.path',
                        score_offset = 10,
                        opts = {
                            trailing_slash = false,
                            label = 'Path',
                        },
                    },
                    buffer = {
                        name = 'Buffer',
                        module = 'blink.cmp.sources.buffer',
                        score_offset = 5,
                        opts = {
                            min_keyword_length = 2,
                            max_entries = 100,
                        },
                    },
                    snippets = {
                        name = 'Snippets',
                        module = 'blink.cmp.sources.snippets',
                        score_offset = 15,
                    },
                },
            },

            snippets = {
                preset = 'default',
            },

            fuzzy = {
                implementation = 'prefer_rust_with_warning',
            },
        })
    end)

    require("mason-lspconfig").setup({
        ensure_installed = {
            "lua_ls",
            "pyright",
            "vtsls",
        },
        automatic_installation = true,
    })

    local lspconfig = require("lspconfig")
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    require("mason-lspconfig").setup_handlers({
        function(server_name)
            lspconfig[server_name].setup({
                capabilities = capabilities,
            })
        end,

        ["lua_ls"] = function()
            lspconfig.lua_ls.setup({
                capabilities = capabilities,
                settings = {
                    Lua = {
                        diagnostics = {
                            globals = { "vim" },
                        },
                        workspace = {
                            checkThirdParty = false,
                            library = {
                                vim.env.VIMRUNTIME,
                            },
                        },
                        telemetry = {
                            enable = false,
                        },
                    },
                },
            })
        end,

        ["pyright"] = function()
            lspconfig.pyright.setup({
                capabilities = capabilities,
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode = "basic",
                            autoSearchPaths = true,
                            useLibraryCodeForTypes = true,
                        },
                    },
                },
            })
        end,

        ["vtsls"] = function()
            lspconfig.vtsls.setup({
                capabilities = capabilities,
                settings = {
                    typescript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                    javascript = {
                        inlayHints = {
                            includeInlayParameterNameHints = 'all',
                            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                            includeInlayFunctionParameterTypeHints = true,
                            includeInlayVariableTypeHints = true,
                            includeInlayPropertyDeclarationTypeHints = true,
                            includeInlayFunctionLikeReturnTypeHints = true,
                            includeInlayEnumMemberValueHints = true,
                        },
                    },
                },
            })
        end,
    })

    pcall(function()
        local mark = require("harpoon.mark")
        local ui = require("harpoon.ui")

        vim.keymap.set("n", "<leader>a", mark.add_file)
        vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)

        vim.keymap.set("n", "<leader>1", function() ui.nav_file(1) end)
        vim.keymap.set("n", "<leader>2", function() ui.nav_file(2) end)
        vim.keymap.set("n", "<leader>3", function() ui.nav_file(3) end)
        vim.keymap.set("n", "<leader>4", function() ui.nav_file(4) end)
    end)

    pcall(function()
        require('nvim-tree').setup({
            disable_netrw = false,
            hijack_netrw = false,
            hijack_directories = {
                enable = false,
            },
            view = {
                width = 50,
                side = 'left',
            },
            filters = {
                dotfiles = false,
            },
            update_focused_file = {
                enable = true,
            },
        })
    end)

    pcall(function()
        require('neotest').setup({
            adapters = {
                require('neotest-python')({
                    dap = { justMyCode = false },
                    runner = 'pytest',
                }),
                require('neotest-jest')({
                    jestCommand = 'npx jest',
                }),
            },
        })
    end)

    pcall(function()
        require('conform').setup({
            formatters_by_ft = {
                python = { 'ruff_format' },
                javascript = { 'prettierd', 'prettier', stop_after_first = true },
                typescript = { 'prettierd', 'prettier', stop_after_first = true },
                javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
                typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
                json = { 'prettierd', 'prettier', stop_after_first = true },
                css = { 'prettierd', 'prettier', stop_after_first = true },
                lua = { 'stylua' },
            },
            format_on_save = {
                timeout_ms = 1500,
                lsp_format = 'fallback',
            },
        })
    end)

    pcall(function()
        require('nvim-ts-autotag').setup()
    end)

    pcall(function()
        require('trouble').setup()
    end)

    pcall(function()
        require('diffview').setup({
            view = {
                default = {
                    layout = "diff2_horizontal",
                },
                file_history = {
                    layout = "diff2_horizontal",
                },
            },
            panel = {
                position = "left",
                width = 20,
            },
        })
    end)

    pcall(function()
        require("zen-mode").setup({
            plugins = {
                options = { laststatus = 0 },
                tmux = true,
                kitty = { enabled = false, font = "+4" },
                alacritty = { enabled = true, font = "18" },
            },
        })
        vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Zen Mode" })
    end)

    pcall(function()
        require("oklch-color-picker").setup({
            highlight_colors = { enable = true },
            keymaps = { confirm = "<CR>" },
        })
        vim.keymap.set("n", "<leader>cp", function() require("oklch-color-picker").open_picker() end,
            { desc = "Open Color Picker" })
        vim.keymap.set("n", "<leader>cP", function() require("oklch-color-picker").pick_under_cursor() end,
            { desc = "Pick Color Under Cursor" })
    end)

    pcall(function()
        local wk = require("which-key")
        wk.setup({
            preset = "helix",
            delay = 300,
        })

        wk.add({
            -- Grupos principais
            { "<leader>w",       group = "window/write" },
            { "<leader>g",       group = "git" },
            { "<leader>v",       group = "lsp" },

            -- Write / quit / arquivo
            { "<leader>ww",      desc = "Write file" },
            { "<leader>wq",      desc = "Quit" },
            { "<leader>q",       desc = "Close tab" },
            { "<leader>e",       desc = "Explorer (netrw)" },
            { "<leader>n",       desc = "New file" },
            --
            -- Splits e navegação de janela
            { "<leader>wv",      desc = "Vertical split" },
            { "<leader>ws",      desc = "Horizontal split" },
            { "<leader>wh",      desc = "Go to left window" },
            { "<leader>wj",      desc = "Go to below window" },
            { "<leader>wk",      desc = "Go to above window" },
            { "<leader>wl",      desc = "Go to right window" },
            --
            -- Terminal / ferramentas externas
            { "<leader>t",       desc = "Open terminal split (zsh)" },
            { "<leader>i",       desc = "Open agy in vsplit" },
            { "<leader>o",       desc = "Open opencode in vsplit" },
            --
            -- -- Diffview / NvimTree / Undotree
            { "<leader>d",       desc = "Diffview open" },
            { "<leader>b",       desc = "Toggle NvimTree" },
            { "<leader>u",       desc = "Toggle Undotree" },
            --
            -- Tabs
            { "<leader><Tab>",   desc = "Next tab" },
            { "<leader><S-Tab>", desc = "Previous tab" },
            { "<leader>N",       desc = "New tab" },
            --
            -- Git (fugitive + fzf-lua)
            { "<leader>gt",      desc = "Git status (fugitive)" },
            { "<leader>gl",      desc = "Git log (fzf-lua)" },
            { "<leader>gs",      desc = "Git status (fzf-lua)" },
            { "<leader>gd",      desc = "Git branches (fzf-lua)" },
            { "<leader>gb",      desc = "Git file history (fzf-lua)" },
            { "<leader>gg",      desc = "Git Grep (fzf-lua)" },
            { "<leader>gc",      desc = "Git commit" },
            --
            -- -- LSP
            { "<leader>vww",     desc = "Workspace symbol" },
            { "<leader>vd",      desc = "Open diagnostic float" },
            { "<leader>vca",     desc = "Code action" },
            { "<leader>vr",      desc = "LSP references" },
            { "<leader>vrn",     desc = "LSP rename" },
            --
            -- Busca de arquivos / conteúdo (fzf-lua) + seletor de diretórios
            { "<leader>f",       desc = "Find files (fzf-lua)" },
            { "<leader>x",       desc = "Open directory (new tab)" },
            { "<leader>s",       desc = "Fuzzy find in current buffer" },
            { "<leader>a",       desc = "Harpoon: add file" },
            { "<leader>1",       desc = "Harpoon: file 1" },
            { "<leader>2",       desc = "Harpoon: file 2" },
            { "<leader>3",       desc = "Harpoon: file 3" },
            { "<leader>4",       desc = "Harpoon: file 4" },
            --
            { "<leader>T",       desc = "Trouble: diagnostics" },
            { "<leader>lT",      desc = "Trouble: quickfix" },
            -- Comment toggle (modo visual)
            { "<leader>m",       desc = "Toggle comment",              mode = "v" },
        })
    end)

    vim.cmd('hi statusline guibg=NONE')

    -- Keymaps globais
    vim.keymap.set('n', '<leader>ww', ':write<CR>')
    vim.keymap.set('n', '<leader>wq', ':quit<CR>')
    vim.keymap.set('n', '<leader>e', vim.cmd.Ex)
    vim.keymap.set('n', '<leader>n', ':enew<CR>', { desc = 'New File' })
    vim.keymap.set('n', '<leader>q', ':tabclose<CR>')

    vim.keymap.set('n', '<leader>wv', ':vsplit<CR>', { silent = true })
    vim.keymap.set('n', '<leader>ws', ':split<CR>', { silent = true })

    vim.keymap.set('n', '<leader>wh', '<C-w>h')
    vim.keymap.set('n', '<leader>wj', '<C-w>j')
    vim.keymap.set('n', '<leader>wk', '<C-w>k')
    vim.keymap.set('n', '<leader>wl', '<C-w>l')

    vim.keymap.set('n', '<leader>t', ':belowright 12split term://zsh<CR>', { silent = true })

    vim.keymap.set('n', '<leader>i', function()
        vim.cmd('vsplit')
        vim.cmd('wincmd l')
        vim.cmd('vertical resize 50')
        vim.cmd('terminal agy')
    end, { silent = true, desc = 'Open CLI' })

    vim.keymap.set('n', '<leader>o', function()
        vim.cmd('vsplit')
        vim.cmd('wincmd l')
        vim.cmd('vertical resize 50')
        vim.cmd('terminal ~/bin/opencode --model litellm-pr/gemma4-saj')
    end, { silent = true, desc = 'Open CLI' })

    vim.keymap.set('n', '<leader>d', ':DiffviewOpen<CR>', { silent = true, desc = 'Diffview' })
    vim.keymap.set('n', '<leader>b', ':NvimTreeToggle<CR>', { silent = true, desc = 'Toggle NvimTree' })
    vim.keymap.set('n', '<leader><Tab>', ':tabnext<CR>', { silent = true, desc = 'Next tab' })
    vim.keymap.set('n', '<leader><S-Tab>', ':tabprevious<CR>', { silent = true, desc = 'Last tab' })
    vim.keymap.set('n', '<leader>N', ':tabnew<CR>', { silent = true, desc = 'New tab' })

    vim.keymap.set('n', ']e', ':cnext<CR>zz', { silent = true, desc = "Next error" })
    vim.keymap.set('n', '[e', ':cprevious<CR>zz', { silent = true, desc = "Previous error" })
    vim.keymap.set('n', '<leader>co', ':copen<CR>', { silent = true, desc = "Open quickfix" })

    vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)
    vim.keymap.set('n', '<leader>gt', vim.cmd.Git)

    vim.keymap.set('n', '<leader>gl', function()
        require('fzf-lua').git_commits()
    end, { desc = 'Git Log (fzf-lua)' })

    vim.keymap.set('n', '<leader>gs', function()
        require('fzf-lua').git_status()
    end, { desc = 'Git Status (fzf-lua)' })

    vim.keymap.set('n', '<leader>gd', function()
        require('fzf-lua').git_branches()
    end, { desc = 'Git Branches (fzf-lua)' })

    vim.keymap.set('n', '<leader>gb', function()
        require('fzf-lua').git_bcommits()
    end, { desc = 'Git File History (fzf-lua)' })

    vim.keymap.set('n', '<leader>gc', ':Git commit<CR>', { silent = true, desc = 'Git commit' })

    vim.keymap.set('n', '<C-p>', function()
        require('fzf-lua').git_files()
    end, { desc = 'Git Files (fzf-lua)' })

    vim.keymap.set("n", "gd", vim.lsp.buf.definition)
    vim.keymap.set("n", "K", vim.lsp.buf.hover)
    vim.keymap.set("n", "<leader>vww", vim.lsp.buf.workspace_symbol)
    vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_next)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_prev)
    vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action)
    vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references)
    vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename)
    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help)

    -- Neotest
    vim.keymap.set('n', '<leader>vtn', function() require('neotest').run.run() end,
        { desc = 'Test: run nearest' })
    vim.keymap.set('n', '<leader>vtf', function() require('neotest').run.run(vim.fn.expand('%')) end,
        { desc = 'Test: run file' })
    vim.keymap.set('n', '<leader>vts', function() require('neotest').summary.toggle() end,
        { desc = 'Test: toggle summary' })
    vim.keymap.set('n', '<leader>vto', function() require('neotest').output.open({ enter = true }) end,
        { desc = 'Test: open output' })

    -- trouble.nvim
    vim.keymap.set('n', '<leader>T', '<cmd>Trouble diagnostics toggle<CR>', { desc = 'Trouble: diagnostics' })
    vim.keymap.set('n', '<leader>lT', '<cmd>Trouble qflist toggle<CR>', { desc = 'Trouble: quickfix' })

    vim.keymap.set('n', '<leader>f', function()
        require('fzf-lua').files()
    end, { desc = 'FZF Files' })

    vim.keymap.set('n', '<leader><leader>', function()
        require('fzf-lua').live_grep()
    end, { desc = 'FZF Grep' })

    vim.keymap.set('n', '<leader>s', function()
        require('fzf-lua').blines()
    end, { desc = 'Fuzzy find in current buffer' })

    vim.keymap.set('n', '<leader>gg', function()
        require('fzf-lua').live_grep({
            cmd = "git grep --line-number --column --color=always",
            prompt = 'GitGrep❯ ',
        })
    end, { desc = 'Live Grep (git files only)' })

    vim.keymap.set("v", "<leader>m", function()
        local cs = vim.bo.commentstring
        local prefix = cs:match("^(.-)%s*%%s")

        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        if start_line > end_line then
            start_line, end_line = end_line, start_line
        end

        local all_commented = true
        for i = start_line, end_line do
            local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            if not l:match("^%s*" .. vim.pesc(prefix)) then
                all_commented = false
                break
            end
        end

        for i = start_line, end_line do
            local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            local new
            if all_commented then
                new = l:gsub("%s*" .. vim.pesc(prefix) .. "%s?", "", 1)
            else
                local indent = l:match("^(%s*)")
                local rest = l:sub(#indent + 1)
                new = indent .. prefix .. " " .. rest
            end
            vim.api.nvim_buf_set_lines(0, i - 1, i, false, { new })
        end

        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", false)
    end, { desc = "toggle comentário na seleção" })

    ------------------------------------------------------------
    -- KEYMAPS GLOBAIS EXTRAS
    ------------------------------------------------------------
    local set = vim.keymap.set
    local kopts = { noremap = true, silent = true }

    set("n", "ss", ":split<Return>", kopts)
    set("n", "sv", ":vsplit<Return>", kopts)
    set("n", "sx", "<cmd>close<CR>", kopts)

    set("n", "<leader>X", "<cmd>!chmod +x %<CR>", { silent = true, desc = "Make current file executable" })

    set("n", "<C-a>", "gg<S-v>G")

    set({ "n", "o", "x" }, "<s-h>", "^", { desc = "Jump to beginning of line" })
    set({ "n", "o", "x" }, "<s-l>", "g_", { desc = "Jump to end of line" })

    set("n", "<leader>cf", '<cmd>let @+ = expand("%")<CR>', { desc = "Copy File Name" })

    set("n", "<C-u>", "<C-u>zz")
    set("n", "<C-d>", "<C-d>zz")
    set("n", "n", "nzzzv", kopts)
    set("n", "N", "Nzzzv", kopts)

    set("v", "<", "<gv", kopts)
    set("v", ">", ">gv", kopts)

    set("n", "<leader>lw", "<cmd>set wrap!<CR>", kopts)

    set("v", "K", ":m '<-2<CR>gv=gv", { silent = true })
    set("v", "J", ":m '>+1<CR>gv=gv", { silent = true })

    set("n", "x", '"_x', kopts)

    set("n", "<leader>rr", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

    set({ "n", "v" }, "<leader>dd", [["_d]])
    set("x", "p", [["_dP]])

    set("n", "<leader><left>", ":vertical resize +20<cr>")
    set("n", "<leader><right>", ":vertical resize -20<cr>")
    set("n", "<leader><up>", ":resize +10<cr>")
    set("n", "<leader><down>", ":resize -10<cr>")

    set("n", "<Tab>", ":bnext<cr>", kopts)
    set("n", "<S-Tab>", ":bprevious<cr>", kopts)
    set("n", "<leader>bd", ":bdelete!<cr>", kopts)
    set("n", "<leader>bn", "<cmd> enew <cr>", kopts)

    set("n", "<leader>ll", "<cmd>PackerStatus<CR>", { desc = "Open Packer status" })
    set("n", "<leader>lm", "<cmd>Mason<CR>", { desc = "Open Mason LSP installer" })

    --set("n", "<leader><leader>", function() require("fzf-lua").files({ hidden = true }) end, { desc = "Search Files" })
    set("n", "<leader>sh", function() require("fzf-lua").help_tags() end, { desc = "Search Help" })
    set("n", "<leader>sk", function() require("fzf-lua").keymaps() end, { desc = "Search Keymaps" })
    set("n", "<leader>ss", function() require("fzf-lua").builtin() end, { desc = "Search Select" })
    set("n", "<leader>sw", function() require("fzf-lua").grep_cword() end, { desc = "Search Word" })
    set("n", "<leader>sd", function() require("fzf-lua").diagnostics_document() end,
        { desc = "Search Diagnostics (buf)" })
    set("n", "<leader>sD", function() require("fzf-lua").diagnostics_workspace() end,
        { desc = "Search Diagnostics (ws)" })

    set('n', ';s', '<Plug>(VM-Find-Under)', { remap = true, desc = 'Multi-cursor: find under cursor' })
    set('n', ';n', '<Plug>(VM-Add-Cursor-At-Next)', { remap = true, desc = 'Multi-cursor: next occurrence' })
    set('n', ';a', '<Plug>(VM-Select-All)', { remap = true, desc = 'Multi-cursor: select all' })
    --set('n', ';mp', '<Plug>(VM-Remove-Region)', { remap = true, desc = 'Multi-cursor: remove last region' })

    -- vim.keymap.set("n", "<leader>//", function()
    -- local query = vim.fn.input("Google: ")
    --
    -- if query ~= "" then
    -- vim.fn.jobstart({
    -- "xdg-open",
    -- "https://www.google.com/search?q=" .. query,
    -- }, {
    -- detach = true,
    -- })
    -- end
    -- end, { desc = "Pesquisar no Google" })

    local dirs_cache
    local ignored = {
        [".git"] = true,
        ["node_modules"] = true,
        ["dist"] = true,
        ["build"] = true,
        [".cache"] = true,
        [".npm"] = true,
        [".cargo"] = true,
        [".rustup"] = true,
    }

    local function scan_dirs(root, include_hidden)
        local result = {}
        local stack = { root }

        while #stack > 0 do
            local path = stack[#stack]
            stack[#stack] = nil

            local handle = vim.uv.fs_scandir(path)

            if handle then
                while true do
                    local name, type = vim.uv.fs_scandir_next(handle)

                    if not name then
                        break
                    end

                    if type == "directory" then
                        local hidden = name:byte(1) == 46

                        if (include_hidden or not hidden) and not ignored[name] then
                            local dir = path .. "/" .. name

                            result[#result + 1] = dir
                            stack[#stack + 1] = dir
                        end
                    end
                end
            end
        end

        return result
    end

    local function open_dir_picker(new_tab)
        if not dirs_cache then
            local home = vim.env.HOME
            local config = home .. "/.config"

            dirs_cache = scan_dirs(home, false)

            if vim.uv.fs_stat(config) then
                dirs_cache[#dirs_cache + 1] = config

                local config_dirs = scan_dirs(config, true)

                for i = 1, #config_dirs do
                    dirs_cache[#dirs_cache + 1] = config_dirs[i]
                end
            end

            table.sort(dirs_cache)
        end

        require("fzf-lua").fzf_exec(dirs_cache, {
            prompt = "Dirs> ",
            fzf_opts = {
                ["--height"] = "100%",
                ["--layout"] = "reverse",
                ["--border"] = "none",
                ["--margin"] = "0",
                ["--padding"] = "0",
            },

            actions = {
                ["default"] = function(selected)
                    local dir = selected[1]

                    if not dir or dir == "" then
                        return
                    end

                    if new_tab then
                        vim.cmd("tabnew")
                        vim.cmd.tcd(vim.fn.fnameescape(dir))
                    else
                        vim.cmd.cd(vim.fn.fnameescape(dir))
                    end

                    vim.cmd.edit(".")
                end,
            },
        })
    end

    vim.keymap.set("n", "<C-x>", function()
        open_dir_picker(false)
    end, { desc = "Open directory (current tab)" })

    vim.keymap.set("n", "<leader>x", function()
        open_dir_picker(true)
    end, { desc = "Open directory (new tab)" })

    pcall(function()
        require('nvim-treesitter.configs').setup({
            ensure_installed = {
                "lua",
                "vim",
                "vimdoc",
                "bash",
                "json",
                "javascript",
                "typescript",
                "html",
                "css",
                "markdown",
                "elixir",
                "python",
            },
            sync_install = true,
            auto_install = true,
            highlight = {
                enable = true,
            },
            indent = {
                enable = true,
            },
        })
    end)
end

if packer_bootstrap then
    vim.api.nvim_create_autocmd('User', {
        pattern = 'PackerComplete',
        once = true,
        callback = post_install_setup
    })
else
    post_install_setup()
end

local function remove_all_italics()
    for _, group in ipairs(vim.fn.getcompletion('', 'highlight')) do
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group })
        if ok and hl and hl.italic then
            hl.italic = false
            pcall(vim.api.nvim_set_hl, 0, group, hl)
        end
    end
end

function ColorMyPencils(color)
    color = color or "alabaster"
    --color = color or "tema"

    local ok = pcall(vim.cmd.colorscheme, color)
    if not ok then
        return
    end

    remove_all_italics()

    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#b5b5b5" })
    vim.api.nvim_set_hl(0, "MsgArea", { bg = "none" })

    vim.api.nvim_set_hl(0, "TabLine", { bg = "none" })
    vim.api.nvim_set_hl(0, "TabLineFill", { bg = "none" })
    vim.api.nvim_set_hl(0, "WinSeparator", { bg = "none" })
    vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
    vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#b5b5b5" })
    vim.api.nvim_set_hl(0, "MsgArea", { bg = "none" })
end

ColorMyPencils()
