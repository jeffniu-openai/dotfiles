" Repo-aware Vim helpers for Python work in /root/code/openai.

let g:openai_repo_root = "/root/code/openai"

function! s:Normalize(path) abort
  return fnamemodify(a:path, ":p")
endfunction

function! s:InOpenAI(path) abort
  let l:path = s:Normalize(empty(a:path) ? getcwd() : a:path)
  return l:path ==# g:openai_repo_root . "/" || l:path =~# "^" . escape(g:openai_repo_root, "/.") . "/"
endfunction

function! s:RepoRoot() abort
  return g:openai_repo_root
endfunction

function! s:OpenAIRelpath(path) abort
  let l:path = s:Normalize(a:path)
  if s:InOpenAI(l:path)
    return substitute(l:path, "^" . escape(g:openai_repo_root . "/", "/."), "", "")
  endif
  return l:path
endfunction

function! s:RunList(cmd, title, parser) abort
  let l:out = systemlist(a:cmd)
  let l:status = v:shell_error
  if a:parser ==# "ruff"
    let l:qf = s:ParseRuff(l:out)
  elseif a:parser ==# "pyright"
    let l:qf = s:ParsePyright(l:out)
  else
    let l:qf = []
  endif

  call setqflist(l:qf, "r", {"title": a:title})
  if !empty(l:qf)
    copen
    cc
  else
    cclose
    if l:status == 0
      echo a:title . ": clean"
    else
      echo a:title . ": no parseable diagnostics; exit " . l:status
      echom join(l:out, "\n")
    endif
  endif
endfunction

function! s:ParseRuff(lines) abort
  try
    let l:data = json_decode(join(a:lines, "\n"))
  catch
    return []
  endtry

  let l:qf = []
  for l:item in l:data
    let l:loc = get(l:item, "location", {})
    let l:code = get(l:item, "code", "RUFF")
    call add(l:qf, {
          \ "filename": get(l:item, "filename", ""),
          \ "lnum": get(l:loc, "row", 1),
          \ "col": get(l:loc, "column", 1),
          \ "type": "W",
          \ "text": l:code . ": " . get(l:item, "message", ""),
          \ })
  endfor
  return l:qf
endfunction

function! s:ParsePyright(lines) abort
  try
    let l:data = json_decode(join(a:lines, "\n"))
  catch
    return []
  endtry

  let l:qf = []
  for l:item in get(l:data, "generalDiagnostics", [])
    let l:start = get(get(l:item, "range", {}), "start", {})
    let l:severity = get(l:item, "severity", "information")
    let l:type = l:severity ==# "error" ? "E" : l:severity ==# "warning" ? "W" : "I"
    call add(l:qf, {
          \ "filename": get(l:item, "file", ""),
          \ "lnum": get(l:start, "line", 0) + 1,
          \ "col": get(l:start, "character", 0) + 1,
          \ "type": l:type,
          \ "text": l:severity . ": " . substitute(get(l:item, "message", ""), "\n", " ", "g"),
          \ })
  endfor
  return l:qf
endfunction

function! s:Target(args) abort
  if !empty(a:args)
    return a:args
  endif
  if expand("%:p") !=# ""
    return shellescape(expand("%:p"))
  endif
  return "."
endfunction

function! s:OpenAISetup() abort
  if !s:InOpenAI(expand("%:p") ==# "" ? getcwd() : expand("%:p"))
    return
  endif

  setlocal tags=./tags;,tags;
  setlocal suffixesadd=.py
  setlocal include=^\\s*\\(from\\\|import\\)
  setlocal define=^\\s*\\(def\\\|class\\)\\s

  let b:openai_python = 1
  nnoremap <buffer> <leader>of :OpenAIFiles<CR>
  nnoremap <buffer> <leader>og :OpenAIRg<Space>
  nnoremap <buffer> <leader>or :OpenAIRuff<CR>
  nnoremap <buffer> <leader>oR :OpenAIRuffFix<CR>
  nnoremap <buffer> <leader>op :OpenAIPyright<CR>
  nnoremap <buffer> <leader>ofm :OpenAIFormat<CR>
  nnoremap <buffer> <leader>ot :OpenAITest<CR>
endfunction

function! s:OpenAIRoot(...) abort
  execute "lcd " . fnameescape(s:RepoRoot())
  echo "lcd " . s:RepoRoot()
endfunction

function! s:OpenAIRg(...) abort
  let l:pattern = a:0 && !empty(a:1) ? a:1 : input("rg pattern: ")
  if empty(l:pattern)
    return
  endif
  execute "lcd " . fnameescape(s:RepoRoot())
  execute "silent grep! -- " . shellescape(l:pattern)
  copen
endfunction

function! s:OpenAIFiles(...) abort
  if !executable("rg") || !executable("fzf")
    echoerr "OpenAIFiles needs rg and fzf"
    return
  endif
  let l:query = a:0 ? a:1 : ""
  let l:cmd = "cd " . shellescape(s:RepoRoot())
        \ . " && rg --files --hidden --glob '!.git' --glob '!bazel-*'"
        \ . " | fzf --height=40% --reverse --query " . shellescape(l:query)
  let l:file = substitute(system(l:cmd), "\n$", "", "")
  if v:shell_error == 0 && !empty(l:file)
    execute "edit " . fnameescape(s:RepoRoot() . "/" . l:file)
  endif
endfunction

function! s:OpenAIRuff(args) abort
  if !executable("ruff")
    echoerr "ruff is not executable"
    return
  endif
  execute "lcd " . fnameescape(s:RepoRoot())
  let l:target = s:Target(a:args)
  call s:RunList("ruff check --output-format=json " . l:target, "ruff check " . l:target, "ruff")
endfunction

function! s:OpenAIRuffFix(args) abort
  if !executable("ruff")
    echoerr "ruff is not executable"
    return
  endif
  execute "lcd " . fnameescape(s:RepoRoot())
  let l:target = s:Target(a:args)
  execute "silent !" . "ruff check --fix " . l:target
  if expand("%:p") !=# ""
    checktime
  endif
endfunction

function! s:OpenAIFormat(args) abort
  if expand("%:p") !=# "" && &modified
    write
  endif
  execute "lcd " . fnameescape(s:RepoRoot())
  let l:target = s:Target(a:args)
  if executable("ruff")
    execute "silent !" . "ruff check --fix --select I " . l:target
  endif
  if executable("black")
    execute "silent !" . "black " . l:target
  elseif executable("ruff")
    execute "silent !" . "ruff format " . l:target
  else
    echoerr "OpenAIFormat needs black or ruff"
    return
  endif
  if expand("%:p") !=# ""
    checktime
  endif
endfunction

function! s:OpenAIPyright(args) abort
  if !executable("pyright")
    echoerr "pyright is not executable"
    return
  endif
  execute "lcd " . fnameescape(s:RepoRoot())
  let l:target = s:Target(a:args)
  call s:RunList("pyright --outputjson " . l:target, "pyright " . l:target, "pyright")
endfunction

function! s:OpenAITest(args) abort
  let l:args = empty(a:args) ? shellescape(s:OpenAIRelpath(expand("%:p"))) : a:args
  execute "lcd " . fnameescape(s:RepoRoot())
  botright 15split
  execute "terminal python -m pytest " . l:args
endfunction

function! s:OpenAITags() abort
  if !executable("ctags")
    echoerr "ctags is not executable"
    return
  endif
  execute "lcd " . fnameescape(s:RepoRoot())
  execute "silent !ctags -R --languages=Python --exclude=.git --exclude=bazel-* --exclude=vendor_imports -f tags ."
  echo "updated " . s:RepoRoot() . "/tags"
endfunction

command! -nargs=0 OpenAIRoot call s:OpenAIRoot()
command! -nargs=? OpenAIRg call s:OpenAIRg(<q-args>)
command! -nargs=? OpenAIFiles call s:OpenAIFiles(<q-args>)
command! -nargs=* -complete=file OpenAIRuff call s:OpenAIRuff(<q-args>)
command! -nargs=* -complete=file OpenAIRuffFix call s:OpenAIRuffFix(<q-args>)
command! -nargs=* -complete=file OpenAIFormat call s:OpenAIFormat(<q-args>)
command! -nargs=* -complete=file OpenAIPyright call s:OpenAIPyright(<q-args>)
command! -nargs=* -complete=file OpenAITest call s:OpenAITest(<q-args>)
command! -nargs=0 OpenAITags call s:OpenAITags()

augroup openai_python_repo
  autocmd!
  autocmd BufEnter,BufReadPost,BufNewFile /root/code/openai/* call s:OpenAISetup()
  autocmd FileType python if s:InOpenAI(expand("%:p")) | setlocal keywordprg=pydoc | endif
augroup END

if s:InOpenAI(getcwd())
  call s:OpenAISetup()
endif
