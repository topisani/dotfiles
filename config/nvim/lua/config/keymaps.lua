-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

local function unmap(mode, lhs)
  vim.api.nvim_del_keymap(mode, lhs)
end

-- Editing commands
-- m to match like kakoune
map({ "v", "n" }, "m", "%")
map({ "v", "n" }, "gh", "g0")
map({ "v", "n" }, "gl", "g$")

-- tabs
unmap("n", "<leader><tab>l")
unmap("n", "<leader><tab>f")
unmap("n", "<leader><tab><tab>")
unmap("n", "<leader><tab>]")
unmap("n", "<leader><tab>d")
unmap("n", "<leader><tab>[")

-- Leader keys
map("n", "<leader><cr>", "<cmd>terminal<cr>")
map("n", "<leader><tab>", "<cmd>Neotree<cr>", { desc = "File tree" })

map("n", "<leader>tl", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "<leader>tf", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader>tt", "<cmd>tabnew<cr>", { desc = "New Tab" })
map("n", "<leader>tn", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader>td", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader>tN", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
map("n", "<leader>tp", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
