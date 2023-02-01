return {
  ["neovim/nvim-lspconfig"] = {
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.plugins.lspconfig"
    end,
  },

  ["nvim-treesitter/nvim-treesitter"] = {
    override_options = {
      ensure_installed = {
        "bash",
        "diff",
        "dockerfile",
        "go",
        "hcl",
        "lua",
        "make",
        "nix",
        "python",
        "regex",
        "terraform",
        "toml",
        "yaml",
      }
    }
  },

  ["nvim-tree/nvim-tree.lua"] = {
    override_options = {
      update_focused_file = {
        enable = true,
      },

      git = {
        enable = true,
      },

      renderer = {
        highlight_git = true,
        icons = {
          show = {
            git = true,
          },
        },
      },
    }
  },

  ["williamboman/mason.nvim"] = {
    override_options = {
      ensure_installed = {
        "ansible-language-server",
        "bash-language-server",
        "dockerfile-language-server",
        "golangci-lint-langserver",
        "gopls",
        "lua-language-server",
        "nil",
        "python-lsp-server",
        "salt-lsp",
        "shfmt",
        "shellcheck",
        "terraform-ls",
        "yaml-language-server",
      }
    }
  },

  ["goolord/alpha-nvim"] = {
    disable = false,
    config = function ()
      require'alpha'.setup(require'alpha.themes.dashboard'.config)
    end
  },

  ["Shatur/neovim-session-manager"] = {
    config = function()
      require('session_manager').setup {
        autoload_mode = require('session_manager.config').AutoloadMode.Disabled,
      }
    end,
  },

  ["jose-elias-alvarez/null-ls.nvim"] = {
    after = "nvim-lspconfig",
    config = function()
      require "custom.plugins.null-ls"
    end,
  },
}
