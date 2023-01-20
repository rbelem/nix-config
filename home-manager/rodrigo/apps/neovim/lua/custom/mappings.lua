-- lua/custom/mappings
local M = {}

-- add this table only when you want to disable default keys
M.disabled = {
  n = {
      ["<leader>h"] = "",
      ["<C-s>"] = ""
  }
}

M.nvimtree = {
  plugin = true,

  n = {
    -- toggle
    ["<leader>a"] = { "<cmd> NvimTreeToggle <CR>", "toggle nvimtree" },
  },
}

return M
