-- since this is just an example spec, don't actually load anything here and return an empty spec

-- every spec file under config.plugins will be loaded automatically by lazy.nvim
--
-- In your plugin files, you can:
-- * add extra plugins
-- * disable/enabled LazyVim plugins
-- * override the configuration of LazyVim plugins

local utils = Config.utils

return {

  { dir = "~/.config/nvim/local/flatblue.nvim", dependencies = "rktjmp/lush.nvim" },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "flatblue",
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = { spelling = true },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.register({
        mode = { "n", "v" },
        ["g"] = { name = "+goto" },
        ["gz"] = { name = "+surround" },
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["<leader>t"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>c"] = { name = "+code" },
        ["<leader>f"] = { name = "+file/find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>gh"] = { name = "+hunks" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>sn"] = { name = "+noice" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>w"] = { name = "+windows" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      })
    end,
  },

  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
      },
      cmdline = {
        view = "cmdline",
      },
      popupmenu = {},
      presets = {
        bottom_search = true,
        command_palette = false,
        long_message_to_split = true,
      },
    },
  },
  -- add symbols-outline
  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = { { "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline" } },
    config = true,
  },

  { "mg979/vim-visual-multi" },

  -- add pyright to lspconfig
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- pyright will be automatically installed with mason and loaded with lspconfig
        pyright = {},
      },
    },
  },

  -- for typescript, LazyVim also includes extra specs to properly setup lspconfig,
  -- treesitter, mason and typescript.nvim. So instead of the above, you can use:
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- add more treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts = vim.tbl_deep_extend("force", opts, {
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-e>",
            node_incremental = "<C-e>",
            scope_incremental = "<nop>",
            node_decremental = "<bs>",
          },
        },
      })
      -- add tsx and treesitter
      vim.list_extend(opts.ensure_installed, {
        "bash",
        "help",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "typescript",
        "vim",
        "yaml",
        "rust",
        "cpp",
      })
    end,
  },

  {
    "folke/zen-mode.nvim",
    keys = {
      {
        "<leader>z",
        "<cmd>ZenMode<CR>",
        mode = "n",
        desc = "Zen Mode",
      },
    },
  },
  {
    "folke/twilight.nvim",
    lazy = true,
    cmd = { "Twilight", "TwilightEnable", "TwilightDisable" },
  },

  {
    "TimUntersberger/neogit",
    cmd = { "Neogit" },
    lazy = true,
    keys = {
      { "<leader>gg", "<cmd>Neogit<CR>", desc = "Neogit" },
    },
    opts = {
      disable_signs = false,
      disable_hint = true,
      disable_context_highlighting = false,
      disable_builtin_notifications = true,
      status = {
        recent_commit_count = 10,
      },
      -- customize displayed signs
      signs = {
        -- { CLOSED, OPENED }
        section = { "", "" },
        item = { "", "" },
        hunk = { "", "" },
      },
      integrations = {
        diffview = true,
      },
      sections = {
        recent = {
          folded = false,
        },
      },
      -- override/add mappings
      mappings = {
        -- modify status buffer mappings
        status = {
          -- Adds a mapping with "B" as key that does the "BranchPopup" command
          ["B"] = "BranchPopup",
        },
      },
    },
  },

  {
    "glepnir/lspsaga.nvim",
    dependencies = { { "nvim-tree/nvim-web-devicons" } },
    cmd = { "Lspsaga" },
    config = function()
      require("lspsaga").setup({
        symbol_in_winbar = {
          enable = false,
        },

        ui = {
          -- Currently, only the round theme exists
          title = true,
          winblend = 0,
          expand = "",
          collapse = "",
          preview = " ",
          code_action = "",
          diagnostic = "",
          incoming = " ",
          outgoing = " ",
          hover = " ",
        },
      })
    end,
    keys = {
      { "gj", "<cmd>Lspsaga lsp_finder<CR>", desc = "LSP Jump" },
      { "<leader>ca", "<cmd>Lspsaga code_actions<CR>", desc = "LSP Code actions" },
    },
  },

  -- add jsonls and schemastore ans setup treesitter for json, json5 and jsonc
  { import = "lazyvim.plugins.extras.lang.json" },

  -- Use <tab> for completion and snippets (supertab)
  -- first: disable default <tab> and <s-tab> behavior in LuaSnip
  {
    "L3MON4D3/LuaSnip",
    keys = function()
      return {}
    end,
  },
  -- then: setup supertab in cmp
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-emoji",
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      local luasnip = require("luasnip")
      local cmp = require("cmp")

      opts.mapping = vim.tbl_extend("force", opts.mapping, {
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
            -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
            -- they way you will only jump inside the snippet region
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      })
    end,
  },

  {
    "ggandor/leap.nvim",
    opts = {
      highlight_unlabeled_phase_one_targets = true,
    },
  },

  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    opts = function()
      local dashboard = require("alpha.themes.dashboard")
      local logo = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
    ]]

      dashboard.section.header.val = vim.split(logo, "\n")
      dashboard.section.buttons.val = {
        dashboard.button("f", " " .. " Find file", ":Telescope find_files <CR>"),
        dashboard.button("n", " " .. " New file", ":ene <BAR> startinsert <CR>"),
        dashboard.button("r", " " .. " Recent files", ":Telescope oldfiles <CR>"),
        dashboard.button("g", " " .. " Find text", ":Telescope live_grep <CR>"),
        dashboard.button("c", " " .. " Config", ":e $MYVIMRC <CR>"),
        dashboard.button("s", "勒" .. " Restore Session", [[:lua require("persistence").load() <cr>]]),
        dashboard.button("l", "鈴" .. " Lazy", ":Lazy<CR>"),
        dashboard.button("q", " " .. " Quit", ":qa<CR>"),
      }
      for _, button in ipairs(dashboard.section.buttons.val) do
        button.opts.hl = "AlphaButtons"
        button.opts.hl_shortcut = "AlphaShortcut"
      end
      dashboard.section.footer.opts.hl = "Type"
      dashboard.section.header.opts.hl = "AlphaHeader"
      dashboard.section.buttons.opts.hl = "AlphaButtons"
      dashboard.opts.layout[1].val = 8
      return dashboard
    end,
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", "Diff view" },
    },
    opts = {
      enhanced_diff_hl = true,
      hooks = {
        ---@param view StandardView
        view_opened = function(view)
          -- Highlight 'DiffChange' as 'DiffDelete' on the left, and 'DiffAdd' on
          -- the right.
          local function post_layout()
            utils.tbl_ensure(view, "winopts.diff2.a")
            utils.tbl_ensure(view, "winopts.diff2.b")
            view.winopts.diff2.a = utils.tbl_union_extend(view.winopts.diff2.a, {
              winhl = {
                "DiffChange:DiffDelete",
                "DiffText:DiffDeleteText",
              },
            })
            view.winopts.diff2.b = utils.tbl_union_extend(view.winopts.diff2.b, {
              winhl = {
                "DiffChange:DiffAdd",
                "DiffText:DiffAddText",
              },
            })
          end

          view.emitter:on("post_layout", post_layout)
          post_layout()
        end,
      },
    },
  },

  { "akinsho/git-conflict.nvim" },

  {
    "Apeiros-46B/qalc.nvim",
    cmd = { "Qalc" },
    opts = {
      set_ft = "qalc",
    },
    config = function(_, opts)
      require("qalc").setup(opts)

      vim.api.nvim_create_autocmd("Filetype", {
        pattern = { "qalc" },
        callback = function()
          require("cmp").setup.buffer({ enabled = false })
        end,
      })
    end,
  },
}
