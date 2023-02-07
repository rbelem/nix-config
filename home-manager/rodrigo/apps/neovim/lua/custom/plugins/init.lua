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
        "css",
        "diff",
        "dockerfile",
        "git_rebase",
        "gitattributes",
        "gitcommit",
        "gitignore",
        "go",
        "hcl",
        "html",
        "javascript",
        "json",
        "lua",
        "make",
        "markdown",
        "markdown_inline",
        "nix",
        "python",
        "regex",
        "terraform",
        "toml",
        "typescript",
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
        "codespell",
        "css-lsp",
        "dockerfile-language-server",
        "eslint_d",
        "gitlint",
        "golangci-lint-langserver",
        "goimports",
        "goimports-reviser",
        "gopls",
        "hadolint",
        "json-lsp",
        "lua-language-server",
        "marksman",
        "nil",
        "python-lsp-server",
        "salt-lsp",
        "shfmt",
        "shellcheck",
        "stylua",
        "taplo",
        "terraform-ls",
        "typescript-language-server",
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
