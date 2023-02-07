local present, null_ls = pcall(require, "null-ls")

if not present then
  return
end

local b = null_ls.builtins

local sources = {
  -- git
  b.diagnostics.gitlint,
  b.code_actions.gitrebase,
  b.code_actions.gitsigns,

  -- go
  b.diagnostics.golangci_lint.with { extra_args = { "--enable-all" } },
  b.formatting.gofmt,
  b.formatting.goimports,

  -- html
  b.formatting.prettier.with { filetypes = { "html", "markdown", "css" } },

  -- javascript
  b.code_actions.eslint_d,
  b.formatting.deno_fmt,

  -- lua
  b.formatting.stylua,

  -- shell
  b.diagnostics.shellcheck.with { diagnostics_format = "#{m} [#{c}]" },
  b.formatting.shfmt,

  -- terraform
  b.formatting.terraform_fmt,
}

null_ls.setup {
  debug = true,
  sources = sources,
}
