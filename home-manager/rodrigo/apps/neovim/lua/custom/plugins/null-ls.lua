local present, null_ls = pcall(require, "null-ls")

if not present then
  return
end

local b = null_ls.builtins

local sources = {
  -- Shell
  b.formatting.shfmt,
  b.formatting.terraform_fmt,
  b.diagnostics.shellcheck.with { diagnostics_format = "#{m} [#{c}]" },
  b.diagnostics.golangci_lint,
}

null_ls.setup {
  debug = true,
  sources = sources,
}
