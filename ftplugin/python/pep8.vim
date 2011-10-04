"=============================================================================
" vim-pep8 - A Python filetype plugin to check pep8 convention.
"
" Before use, please make sure below.
"
" - vim is compiled with python.
" - put pep8 somewhere to be visible from this.
"
" Language:    Python (ft=python)
" Maintainer:  MURAOKA Yusuke <yusuke@jbking.org>
" Version:     0.5
" URL:         http://github.com/jbking/vim-pep8
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"
" Thanks to pyflakes.vim. Almost inspired from you.
"=============================================================================

" Do initialize on each buffer. {{{
augroup plugin-vim-pep8 "{{{
    autocmd! * <buffer>
    autocmd BufEnter,BufWritePost <buffer> call s:Update()
    autocmd CursorHold,CursorHoldI <buffer> call s:Update()
    autocmd InsertLeave <buffer> call s:Update()
    " Clear
    autocmd BufLeave <buffer> call s:Clear()
    " Just getting message at the line.
    autocmd CursorHold,CursorMoved <buffer> call s:GetMessage()
augroup END
" }}}

" In same situation as pyflakes.vim {{{
noremap <buffer> dd dd:Pep8Update<CR>
noremap <buffer> dw dw:Pep8Update<CR>
noremap <buffer> u u:Pep8Update<CR>
noremap <buffer> <C-R> <C-R>:Pep8Update<CR>
" }}}
" }}}

" Do initialize below once. {{{
if exists("s:pep8_ftplugin_loaded")
    finish
endif
let s:pep8_ftplugin_loaded = 1

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" Params. {{{
" The command to be used by this plugin
if !exists("g:pep8_cmd")
  let g:pep8_cmd="pep8"
endif
" Show all occurrences of the same error
if !exists("g:pep8_args")
  let g:pep8_args="-r" 
endif
" Select errors and warnings (e.g. E4,W)
if !exists("g:pep8_select")
  let g:pep8_select=""
endif
" Skip errors and warnings (e.g. E4,W)
if !exists("g:pep8_ignore")
  let g:pep8_ignore=""
endif
let s:match_group = 'Pep8'
" }}}

" Highlight group. {{{
execute 'highlight link ' . s:match_group . ' SpellBad'
" }}}

" Check existing of pep8 command. {{{
python << EOF
import os
import sys
import vim

# First, find the pep8, otherwise finish.
cmd = vim.eval('g:pep8_cmd')

vim.command("let s:pep8_found = 0")
if cmd.startswith(os.path.sep):
    # Absolute path case
    vm.command("let s:pep8_found = %d" % (1 if os.path.isfile(cmd) else 0))
else:
    for path in os.environ['PATH'].split(os.pathsep):
        pep8_path = os.path.join(path, cmd)
        if os.path.isfile(pep8_path):
            vim.command("let s:pep8_found = 1")
            break
EOF

if !s:pep8_found
    echoerr "pep8 not found. install it."
    finish
endif
" }}}

" Initialize. {{{
python << EOF
# Insert the plugin directory as first.
script_dir = os.path.dirname(vim.eval('expand("<sfile>")'))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

# Must be imported
from pep8checker import Pep8Checker

args = vim.eval('string(g:pep8_args)')
select = vim.eval('string(g:pep8_select)')
ignore = vim.eval('string(g:pep8_ignore)')

if select:
    args = args + ' --select=%s' % select

if ignore:
    args = args + ' --ignore=%s' % ignore

pep8_checker = Pep8Checker(cmd, args)

def vim_quote(s):
    return s.replace("'", "''")
EOF
" }}}

" Functions. {{{
function! s:Clear() " {{{
    let matches = getmatches()
    for matchId in matches
        if matchId['group'] == s:match_group
            call matchdelete(matchId['id'])
        endif
    endfor
    if exists('b:pep8_matchedlines')
        unlet b:pep8_matchedlines
    endif
endfunction
" }}}

function! s:Run() " {{{
    if exists('b:pep8_matchedlines')
        call s:Clear()
    endif
    let b:pep8_matchedlines = {}
    python << EOF
for (lineno, description) in pep8_checker.check(vim.current.buffer):
    vim.command("let matchDict = {}")
    vim.command("let matchDict['lineNum'] = " + lineno)
    vim.command("let matchDict['message'] = '%s'" % vim_quote(description))
    vim.command("let matchDict['mID'] = matchadd(s:match_group, '\%" + lineno + "l\\n\@!')")
    vim.command("let b:pep8_matchedlines[" + lineno + "] = matchDict")
EOF
endfunction
" }}}

function! s:GetMessage() " {{{
    " Reset status message.
    echo ""

    let cursorPos = getpos(".")

    " Bail if s:Run() hasn't been called yet.
    if !exists('b:pep8_matchedlines')
        return
    endif

    " if there's a message for the line the cursor is currently on, echo
    " it to the console
    if has_key(b:pep8_matchedlines, cursorPos[1])
        let pep8Match = get(b:pep8_matchedlines, cursorPos[1])
        call s:WideMsg(pep8Match['message'])
    endif
endfunction
" }}}

" WideMsg() prints [long] message up to (&columns-1) length
" guaranteed without "Press Enter" prompt.
function! s:WideMsg(msg) " {{{
    let x=&ruler | let y=&showcmd
    set noruler noshowcmd
    redraw
    let msg=substitute(a:msg, "\n", "", "")
    echo strpart(msg, 0, &columns-1)
    let &ruler=x | let &showcmd=y
endfun
" }}}

function! s:Update() " {{{
    call s:Run()
    call s:GetMessage()
endfunction
" }}}
" }}}

" Commands. {{{
command! Pep8Update :call s:Update()
command! Pep8Clear :call s:Clear()
command! Pep8GetMessage :call s:GetMessage()
" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
" }}}
" __END__
" vim:foldmethod=marker
