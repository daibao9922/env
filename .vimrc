let s:_tags_cache_dir = '~/tmp/cache/tags'

"######## search ##############
let s:search_result_file = tempname()
let s:search_result_list = []
let s:search_result_cur_line = 0
let s:search_result_job = job_start(":")
let s:search_result_word = ''
let s:search_path = getcwd()
let s:rg_path = '/data/data/com.termux/files/usr/bin/rg'
let s:bash_path = '/data/data/com.termux/files/usr/bin/bash'
let s:search_result_show = 0

function! s:SearchResultCurLineCheck(line)
    if a:line > len(s:search_result_list)
        return [0, []]
    endif
    let words = split(s:search_result_list[a:line - 1], ':')
    if len(words) <= 3 || words[1] < 1 || words[2] < 1
        return [0, []
    endif
    if filereadable(words[0])
        return [1, words]
    endif
    return [0, []]
endfunction

function! s:GotoResultLine(words)
    execute 'e ' . a:words[0]
    execute a:words[1]
    execute 'normal 0' . (a:words[2] - 1) . 'l'
endfunction

function! s:GotoResultFileCur()
    let cur_pos = getpos('.')
    let s:search_result_cur_line = cur_pos[1]
    let check_result = s:SearchResultCurLineCheck(s:search_result_cur_line)
    if ! check_result[0]
        return
    endif
    call s:GotoResultLine(check_result[1])
endfunction

function! s:GotoResultFileNext()
    let old_line = s:search_result_cur_line
    if s:search_result_cur_line >= len(s:search_result_list)
        echo 'No next item !!!'
        return
    endif
    let s:search_result_cur_line = s:search_result_cur_line + 1
    let check_result = s:SearchResultCurLineCheck(s:search_result_cur_line)
    while ! check_result[0]
        if s:search_result_cur_line >= len(s:search_result_list)
            let s:search_result_cur_line = old_line
            echo 'No next item !!!'
            return
        endif
        let s:search_result_cur_line = s:search_result_cur_line + 1
        let check_result = s:SearchResultCurLineCheck(s:search_result_cur_line)
    endwhile

    call s:GotoResultLine(check_result[1])
endfunction

function! s:GotoResultFilePrev()
    let old_line = s:search_result_cur_line
    if s:search_result_cur_line <= 1
        echo 'No prev item !!!'
        return
    endif
    let s:search_result_cur_line = s:search_result_cur_line - 1
    let check_result = s:SearchResultCurLineCheck(s:search_result_cur_line)
    while ! check_result[0]
        if s:search_result_cur_line <= 1
            let s:search_result_cur_line = old_line
            echo 'No prev item !!!'
            return
        endif
        let s:search_result_cur_line = s:search_result_cur_line - 1
        let check_result = s:SearchResultCurLineCheck(s:search_result_cur_line)
    endwhile

    call s:GotoResultLine(check_result[1])
endfunction

function! s:RgAsyncFinishHandler()
    if job_status(s:search_result_job) == "run"
        return
    endif

    if s:search_result_show == 0
        return
    endif
    let s:search_result_show = 0

    let s:search_result_curr_line = 0

    set autoread
    execute 'view ' . s:search_result_file
    execute "normal /\\%$//;?^>>?2\<cr>"
    set noautoread
    
    let s:search_result_list = getline(1, '$')
    let cur_pos = getcurpos()
    let s:search_result_cur_line = cur_pos[1]
endfunction

function! RgAsyncCloseCbHandler(channel)
    call s:RgAsyncFinishHandler()
endfunction

function! RgAsyncExitCbHandler(job, exit_status)
    call s:RgAsyncFinishHandler()
endfunction

function! s:RgAsyncRun(word, path)
    if a:word[0] == "'" || a:word[0] == '"'
        let cmd = s:rg_path . ' -L --no-ignore --column --line-number -H ' . a:word . ' ' . a:path . ' | dos2unix >>' . s:search_result_file
    else
        let cmd = s:rg_path . ' -L --no-ignore --column --line-number -H "\\b' . a:word . '\\b" ' . a:path . ' | dos2unix >>' . s:search_result_file
    endif
    if job_status(s:search_result_job) == "run"
        call job_stop(s:search_result_job)
    endif
    let s:search_result_job = a:word
    let s:search_result_show = 1
    let s:search_result_job = job_start([s:bash_path, '-c', cmd], {
                \'close_cb': 'RgAsyncCloseCbHandler',
                \'exit_cb': 'RgAsyncExitCbHandler'
                \})
endfunction

"word:
"    str
"    str path
function! s:RgWithLineNumber(word, path, bclean)
    let title = ['------------------------------',
                \ '>> ' . a:word,
                \ '------------------------------']
    if a:bclean || !filereadable(s:search_result_file)
        call writefile(title, s:search_result_file, 's')
    else
        call writefile([''] + title, s:search_result_file, 'as')
    endif

    if a:path != ''
        call s:RgAsyncRun(a:word, a:path)
    elseif s:search_path != ''
        call s:RgAsyncRun(a:word, s:search_path)
    else
        echo 'Search path is null!!'
    endif
endfunction

function! s:ChangeSearchPath(path)
    let tmp_path = split(a:path)

    if len(tmp_path) > 0
        let s:search_path = tmp_path[0]
        echo 'Search path change to : ' . s:search_path
    else
        echo 'Current search path is : ' . s:search_path
    endif
endfunction

function! s:MapLeader_r()
    call s:RgWithLineNumber(expand('<cword>'), '', 0)
endfunction

function! s:MapLeader_R()
    call s:RgWithLineNumber(expand('<cword>'), '', 1)
endfunction

function! s:MapLeader_fl()
    call s:RgWithLineNumber(expand('<cword>'), expand('%'), 0)
endfunction

function! s:MapLeader_fs()
    if job_status(s:search_result_job) == "run"
        call job_stop(s:search_result_job)
    endif
endfunction

function! s:MapLeader_fr()
    if filereadable(s:search_result_file)
        execute 'e ' . s:search_result_file
    endif
endfunction

function! s:InitSearchMap()
    nnoremap <leader>r :call <sid>MapLeader_r()<cr>
    nnoremap <leader>R :call <sid>MapLeader_R()<cr>
    nnoremap <leader>fl :call <sid>MapLeader_fl()<cr>
    nnoremap <leader>fs :call <sid>MapLeader_fs()<cr>
    nnoremap <leader>fr :call <sid>MapLeader_fr()<cr>
    nnoremap <C-N> :call <sid>GotoResultFileNext()<cr>
    nnoremap <C-P> :call <sid>GotoResultFilePrev()<cr>
endfunction

function! s:SearchBufWinEnter()
    if expand("%") ==# s:search_result_file
        if s:search_result_cur_line != 0
            call setpos(".", [0, s:search_result_cur_line, 0, 0])
        endif
        nnoremap <buffer> <cr> :call <sid>GotoResultFileCur()<cr>
    endif
endfunction

function! s:InitSearchAutocmd()
    augroup reg_search_autocmd
        autocmd!
        autocmd BufWinEnter * call <sid>SearchBufWinEnter()
endfunction

"######## search end ##########

function! s:InitBase()
    syntax on
    syntax enable

    set t_Co=256
    set background=dark
    set cursorline
    highlight CursorLine cterm=NONE ctermbg=236
    set nocompatible
    set number
    set history=100
    set noignorecase
    set nohlsearch
    set wrap
    set noswapfile
    set nowrapscan
    set mouse=a
    set hidden
    set wmh=0
endfunction

function! s:InitEncoding()
    set enc=utf-8
    set tenc=utf-8
    set fenc=cp936
    set fencs=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
    set ambiwidth=double
endfunction

function! s:InitProgramming()
    set expandtab
    set autoindent
    set shiftwidth=4
    set tabstop=4
endfunction

function! s:PlugFzf()
    Plug 'junegunn/fzf.vim'
endfunction

function! s:PlugGutentags()
    Plug 'ludovicchabant/vim-gutentags'
    let g:gutentags_project_root = ['.git']
    let g:gutentags_ctags_tagfile = '.tags'
    let g:gutentags_modules = ['ctags']
    let g:gutentags_cache_dir = expand(s:_tags_cache_dir)
endfunction

function! s:PlugYouCompleteMe()
    Plug 'ycm-core/YouCompleteMe'
endfunction

function! s:PlugInterestingWords()
    Plug 'lfv89/vim-interestingwords'
    let g:interestingWordsTermColors = []
    let i = 0
    while i < 50
        call add(g:interestingWordsTermColors, '143')
        let i = i + 1
    endwhile
endfunction

function! s:InitPlug()
    call plug#begin('~/.vim/plugged')
    call s:PlugFzf()
    "call s:PlugGutentags()
    "call s:PlugYouCompleteMe()
    call s:PlugInterestingWords()
    call plug#end()
endfunction

function! s:InitMap()
    let g:mapleader = ','
    let g:maplocalleader = '-'
    inoremap jk <esc>
    cnoremap jk <esc>

    call s:InitSearchMap()
endfunction

function! s:InitAutocmd()
    call s:InitSearchAutocmd()
endfunction

function! s:Main()
    call s:InitBase()
    call s:InitEncoding()
    call s:InitProgramming()
    call s:InitPlug()
    call s:InitMap()
    call s:InitAutocmd()
endfunction

call s:Main()
