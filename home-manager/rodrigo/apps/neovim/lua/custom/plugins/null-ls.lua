local present, null_ls = pcall(require, "null-ls")

if not present then
  return
end

local b = null_ls.builtins

local sources = {
  b.code_actions.eslint_d,

  b.formatting.deno_fmt,
  b.formatting.gofmt,
  b.formatting.goimports,
  b.formatting.prettier.with { filetypes = { "html", "markdown", "css" } },
  b.formatting.shfmt,
  b.formatting.stylua,
  b.formatting.terraform_fmt,

  b.diagnostics.shellcheck.with { diagnostics_format = "#{m} [#{c}]" },
  b.diagnostics.golangci_lint.with { extra_args = { "--enable-all" } },
}

null_ls.setup {
  debug = true,
  sources = sources,
}
