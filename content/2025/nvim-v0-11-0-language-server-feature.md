---
title: "Neovim v0.11.0 からの Language Server の設定"
date: 2025-03-30T02:36:29+0900
draft: false
tags: ["Vim", "技術"]
---
## はじめに
Neovim の v0.11.0 がリリースされました。

https://github.com/neovim/neovim/releases/tag/v0.11.0

色々な機能が追加されています。詳しくは [News-0.11](https://neovim.io/doc/user/news-0.11.html) を参照してください。この記事では、新たに追加された Language Server 周りの機能にフォーカスして紹介します。

## `vim.lsp.config()` と `vim.lsp.enable()`
Neovim v0.11.0 からは、Language Server の設定を行うための `vim.lsp.config()` と、`vim.lsp.enable()` が追加されました。v0.11.0 より前は、Language Server の設定を行うために [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig) をプラグインマネージャーを使って別途インストールして、Language Server の設定を行うのがデファクトスタンダードでした。`vim.lsp.config()` が追加されたことによって、`nvim-lspconfig` ライクに Language Server の設定ができるようになりました。なるべく外部への依存を減らしたい派の人にとっては嬉しいのではないでしょうか?

以下は、私が実際に使っている設定になります。

```lua
-- Configure Language Servers
vim.lsp.config['gopls'] = {
  cmd = { 'gopls' },
  root_markers = {
    'go.mod',
    '.git',
    'go.work'
  },
  filetypes = {
    'go',
    'gomod',
    'gowork',
    'gotmpl'
  },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
}

vim.lsp.config['lua_ls'] = {
  cmd = { 'lua-language-server' },
  root_markers = {
    '.luarc.json',
    '.luarc.jsonc',
    '.luacheckrc',
    '.stylua.toml',
    'stylua.toml',
    'selene.toml',
    'selene.yml',
    '.git',
  },
  filetypes = { 'lua' },
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
        pathStrict = true,
        path = { "?.lua", "?/init.lua" },
      },
      diagnostics = {
        globals = { 'vim' },
      },
      workspace = {
        library = vim.list_extend(vim.api.nvim_get_runtime_file("lua", true), {
          "${3rd}/luv/library",
          "${3rd}/busted/library",
          "${3rd}/luassert/library",
        }),
        checkThirdParty = "Disable",
      },
    },
  }
}

vim.lsp.enable({ 'gopls', 'lua_ls' })

-- Keymaps of LSP
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    -- Disable default keymaps
    vim.bo[ev.buf].omnifunc = nil
    vim.bo[ev.buf].tagfunc = nil
    vim.bo[ev.buf].formatexpr = nil

    -- Set Keymaps
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    local keyopts = { remap = true, silent = true }
    if client:supports_method('textDocument/implementation') then
      vim.keymap.set('n', 'gD', vim.lsp.buf.implementation, keyopts)
    end
    if client:supports_method('textDocument/definition') then
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, keyopts)
    end
    if client:supports_method('textDocument/typeDefinition*') then
      vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, keyopts)
    end
    if client:supports_method('textDocument/references') then
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, keyopts)
    end
    if client:supports_method('textDocument/rename') then
      vim.keymap.set('n', 'gn', vim.lsp.buf.rename, keyopts)
    end
    if client:supports_method('textDocument/codeAction') then
      vim.keymap.set('n', '<Leader>k', vim.lsp.buf.code_action, keyopts)
    end
    if client:supports_method('textDocument/signatureHelp') then
      vim.api.nvim_create_autocmd('CursorHoldI', {
        pattern = '*',
        callback = function()
          vim.lsp.buf.signature_help({ focus = false, silent = true })
        end
      })
    end
  end,
})

-- Auto format on save
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if not client:supports_method('textDocument/willSaveWaitUntil') and client:supports_method('textDocument/formatting') then
      vim.api.nvim_create_autocmd('BufWritePre', {
        buffer = ev.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = ev.buf, id = client.id, timeout_ms = 1000, async = false })
        end
      })
    end
  end
})

-- Diagnostics
vim.diagnostic.config({
  virtual_lines = true,
})
```

上記例では、`gopls` と `lua-language-server` の設定を行なっています。各 Language Server を使えるようにするだけなら、`vim.lsp.config()` と `vim.lsp.enable()` の部分を記述すれば使い始めることができます。[デフォルトのキーマップ](https://neovim.io/doc/user/lsp.html#lsp-defaults)は少々使いづらかったので、`vim.api.nvim_create_autocmd()` と `vim.keymap.set()` を使って変更しています。

## `vim.lsp.completion`
もう 1 つ Language Server 周りので大きな機能追加がありました。Language Server が有効になっている際の補完機能が強化されました。これにより、外部プラグインを使わずに Language Server による自動補完の恩恵を得られるようになりました。

以下は、[ドキュメント](https://neovim.io/doc/user/lsp.html#lsp-attach)からの引用です。

```lua
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, args.buf, {autotrigger = true})
    end
  end,
})
```

上記の例では、Language Server が `textDocument/completion` をサポートしている場合に、補完機能を有効にしています。`vim.lsp.completion.enable()` の第 1 引数に `true` を渡すことで、補完機能を有効にしています。`autotrigger` オプションを `true` にすることで、自動で補完が表示されるようになります。私もこの機能を試してみましたが、スニペットプラグインとの連携させたり、Language Server 以外のソース (ファイルパスやバッファ) からの補完も使いたいので、以前から使っている `nvim-cmp` を引き続き使っています。

## おわりに
Neovim v0.11.0 からの Language Server の設定について紹介しました。ビルトインの機能が強化されたことで、外部プラグインに依存しない設定ができるようになりました。選択肢が増えたのはうれしいですね。ここで紹介した内容が読んでくださった皆様のエディタライフになにか寄与できれば光栄です。
