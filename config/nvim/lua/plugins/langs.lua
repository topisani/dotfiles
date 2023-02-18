return {
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    dependencies = {
      {
        "theHamsta/nvim-dap-virtual-text",
        config = true,
      },
    },
    config = function()
      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "", linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "", texthl = "", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "", texthl = "", linehl = "", numhl = "" })
      require("dap").defaults.fallback.terminal_win_cmd = "enew"
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dap-repl",
        callback = function()
          require("dap.ext.autocompl").attach()
        end,
      })
      require("which-key").register({
        ["<leader>db"] = { name = "+breakpoints" },
        ["<leader>ds"] = { name = "+steps" },
        ["<leader>dv"] = { name = "+views" },
      })
    end,
    keys = {
      {
        "<leader>dbc",
        '<CMD>lua require("dap").set_breakpoint(vim.ui.input("Breakpoint condition: "))<CR>',
        desc = "conditional breakpoint",
      },
      {
        "<leader>dbl",
        '<CMD>lua require("dap").set_breakpoint(nil, nil, vim.ui.input("Log point message: "))<CR>',
        desc = "logpoint",
      },
      { "<leader>dbr", '<CMD>lua require("dap.breakpoints").clear()<CR>', desc = "remove all" },
      { "<leader>dbs", "<CMD>Telescope dap list_breakpoints<CR>", desc = "show all" },
      { "<leader>dbt", '<CMD>lua require("dap").toggle_breakpoint()<CR>', desc = "toggle breakpoint" },
      { "<leader>dc", '<CMD>lua require("dap").continue()<CR>', desc = "continue" },
      {
        "<leader>de",
        '<CMD>lua require("dap.ui.widgets").hover(nil, { border = "none" })<CR>',
        desc = "expression",
        mode = { "n", "v" },
      },
      { "<leader>dp", '<CMD>lua require("dap").pause()<CR>', desc = "pause" },
      { "<leader>dr", "<CMD>Telescope dap configurations<CR>", desc = "run" },
      { "<leader>dsb", '<CMD>lua require("dap").step_back()<CR>', desc = "step back" },
      { "<leader>dsc", '<CMD>lua require("dap").run_to_cursor()<CR>', desc = "step to cursor" },
      { "<leader>dsi", '<CMD>lua require("dap").step_into()<CR>', desc = "step into" },
      { "<leader>dso", '<CMD>lua require("dap").step_over()<CR>', desc = "step over" },
      { "<leader>dsx", '<CMD>lua require("dap").step_out()<CR>', desc = "step out" },
      { "<leader>dx", '<CMD>lua require("dap").terminate()<CR>', desc = "terminate" },
      {
        "<leader>dvf",
        '<CMD>lua require("dap.ui.widgets").centered_float(require("dap.ui.widgets").frames, { border = "none" })<CR>',
        desc = "show frames",
      },
      {
        "<leader>dvs",
        '<CMD>lua require("dap.ui.widgets").centered_float(require("dap.ui.widgets").scopes, { border = "none" })<CR>',
        desc = "show scopes",
      },
      {
        "<leader>dvt",
        '<CMD>lua require("dap.ui.widgets").centered_float(require("dap.ui.widgets").threads, { border = "none" })<CR>',
        desc = "show threads",
      },
    },
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = { { "mfussenegger/nvim-dap" } },
    config = function()
      require("dapui").setup()
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
    keys = {
      { "<leader>de", "<Cmd>lua require('dapui').eval()<CR>", desc = "Eval" },
      { "<leader>db", "<Cmd>lua require('dap').toggle_breakpoint()<CR>", desc = "Toggle Breakpoint" },
      { "<leader>dc", "<Cmd>lua require('dap').continue()<CR>", desc = "Continue" },
      { "<leader>dn", "<Cmd>lua require('dap').step_over()<CR>", desc = "Step over" },
      { "<leader>ds", "<Cmd>lua require('dap').step_into()<CR>", desc = "Step into" },
    },
  },

  -- extend auto completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "Saecki/crates.nvim",
        event = { "BufRead Cargo.toml" },
        config = true,
      },
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")
      opts.sources = cmp.config.sources(vim.list_extend(opts.sources, {
        { name = "crates" },
      }))
    end,
  },
  -- add rust to treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "rust", "toml" })
    end,
  },
  -- correctly setup mason lsp / dap extensions
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "codelldb", "rust-analyzer", "taplo" })
    end,
  },

  -- correctly setup lspconfig
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- make sure mason installs the server
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                features = "all",
              },
              -- Add clippy lints for Rust.
              checkOnSave = true,
              check = {
                command = "clippy",
                features = "all",
              },
              procMacro = {
                enable = true,
              },
            },
          },
        },
      },
    },
  },
}
