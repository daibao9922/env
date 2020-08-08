let s:_tags_cache_dir = '~/tmp/cache/tags'

"######## search ##############
let s:search_result_file = tempname()
let s:search_result_list = []
let s:search_result_cur_line = 0
let s:search_result_job = job_start(":")
let s:search_result_word = ''
let s:search_path = getcwd()
let s:rg_path = 'rg'
let s:bash_path = 'bash'

function! SearchResultStatusLine()
    if job_status(s:search_result_job) == 'run'
        return '[Search ' . s:search_result_word . '...]'
    else
        return ''
    endif
endfunction

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
    let s:search_result_list = getline(1, '$')
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

function! RgAsyncFinishHandler(channel)
    let s:search_result_curr_line = 0

    if job_status(s:search_result_job) == "run"
        return
    endif

    execute 'view ' . s:search_result_file
    setlocal autoread
    execute "normal /\\%$/;?^>>?2\<cr>"
    
    let s:search_result_list = getline(1, '$')
    let cur_pos = getcurpos()
    let s:search_result_cur_line = cur_pos[1]
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

    let s:search_result_word = a:word
    let s:search_result_job = job_start(['bash', '-c', cmd], {
        \'close_cb': 'RgAsyncFinishHandler'
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

function! s:MapLeader_sl()
    call s:RgWithLineNumber(expand('<cword>'), expand('%'), 0)
endfunction

function! s:MapLeader_ss()
    if job_status(s:search_result_job) == "run"
        call job_stop(s:search_result_job)
    endif
endfunction

function! s:MapLeader_q()
    if filereadable(s:search_result_file)
        execute 'e ' . s:search_result_file
    endif
endfunction

function! s:InitSearchMap()
    nnoremap <leader>r :call <sid>MapLeader_r()<cr>
    nnoremap <leader>R :call <sid>MapLeader_R()<cr>
    nnoremap <leader>sl :call <sid>MapLeader_sl()<cr>
    nnoremap <leader>ss :call <sid>MapLeader_ss()<cr>
    nnoremap <leader>q :call <sid>MapLeader_q()<cr>
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

    set nocompatible
    set backspace=indent,eol,start
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
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
endfunction

function! s:PlugCocNvim()
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
endfunction

function! s:PlugGutentags()
    Plug 'ludovicchabant/vim-gutentags'
    let g:gutentags_project_root = ['.git']
    let g:gutentags_ctags_tagfile = '.tags'
    let g:gutentags_modules = ['ctags']
    let g:gutentags_cache_dir = expand(s:_tags_cache_dir)
    let g:gutentags_ctags_extra_args = [
        \"--c-kinds=+p",
        \ "--fields=+iaS",
        \ "--extra=+q",
        \ "--excmd=number",
        \ "--exclude=*.vim"]
    let gutentags_define_advanced_commands = 0
    let g:gutentags_auto_add_gtags_cscope = 0
    let g:gutentags_generate_on_empty_buffer = 0
endfunction

function! s:PlugYouCompleteMe()
    Plug 'ycm-core/YouCompleteMe', {'for':['c','cpp','python','go','vim','sh']}
    let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
    let g:ycm_semantic_triggers =  {
        \ 'c,cpp,python,go,vim,sh': ['re!\w{2}'],
        \ }
    let g:ycm_error_symbol = '>>'
    let g:ycm_warning_symbol = '>*'
    let g:ycm_always_populate_location_list = 1

    " close preview window
    set completeopt=menu,menuone
    let g:ycm_add_preview_to_completeopt = 0
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

function! s:PlugListToggle()
    Plug 'Valloric/ListToggle'
    let g:lt_location_list_toggle_map = '<leader>tl'
    let g:lt_quickfix_list_toggle_map = '<leader>tq'
endfunction

function! s:PlugColorschemeMolokai()
    set rtp+=~/.vim/plugged/molokai
    Plug 'tomasr/molokai'
    
    set t_Co=256
    set background=dark
    set cursorline
    colorscheme molokai
endfunction

function! s:PlugDirDiff()
    Plug 'will133/vim-dirdiff'
    
    let g:DirDiffExcludes = ".*.swp"
endfunction

function! s:PlugTagbar()
    Plug 'majutsushi/tagbar'
    
    let g:tagbar_type_c = {
        \ 'kinds' : [
            \ 'd:macros:0:0',
            \ 'p:prototypes:0:0',
            \ 'g:enums',
            \ 'e:enumerators:0:0',
            \ 't:typedefs:0:0',
            \ 's:structs',
            \ 'u:unions',
            \ 'm:members:0:0',
            \ 'v:variables:0:0',
            \ 'f:functions',
            \ '?:unknown',
        \],
    \}
    let g:tagbar_left = 1
    let g:tagbar_autofocus = 1
    let g:tagbar_sort = 0
    let g:tagbar_compact = 1
endfunction

function! s:PlugNerdTree()
    Plug 'scrooloose/nerdtree'
    
    let g:NERDTreeWinPos='right'
    let g:NERDTreeChDirMode=1
    let g:NERDTreeShowHidden=1
    let g:NERDTreeShowBookmarks=1
    let g:NERDTreeIgnore=['\.swp$[[file]]', '\.pyc$[[file]]', '\.o$[[file]]']
endfunction

function! s:PlugAsyncRun()
    Plug 'skywind3000/asyncrun.vim'
    
    let g:asyncrun_open = 10
endfunction

function! s:PlugIndentLine()
    Plug 'Yggdroot/indentLine'
    
    let g:indentLine_fileType = ['c', 'cpp', 'python', 'vim']
endfunction

function! s:PlugPythonMode()
    Plug 'klen/python-mode'
    
    let g:pymode_option = 1
    let g:pymode = 1
    let g:pymode_syntax_all = 0
    
    let g:pymode_python = 'python'
endfunction

function! s:PlugFugitive()
    Plug 'tpope/vim-fugitive'
endfunction

function! s:InitPlug()
    call plug#begin('~/.vim/plugged')

    "call s:PlugColorschemeMolokai()
    call s:PlugListToggle()
    call s:PlugDirDiff()
    call s:PlugTagbar()
    call s:PlugNerdTree()
    call s:PlugAsyncRun()
    call s:PlugFzf()
    call s:PlugInterestingWords()
    call s:PlugCocNvim()
    
    if isdirectory("./.git")
        call s:PlugGutentags()
        "call s:PlugYouCompleteMe()
        call s:PlugIndentLine()
        "call s:PlugPythonMode()
        call s:PlugFugitive()
    endif

    call plug#end()
endfunction

function! StatusLineGetPos()
    let pos = getcurpos()
    let all_line_num = line('$')
    let percent = (pos[1] * 100) / all_line_num
    return '[' . string(all_line_num) . ',' . string(percent) . '%][' . string(pos[2]) . ']'
endfunction

function! s:SetStatusLine()
    " 设置状态行显示常用信息
    " %F 完整文件路径名
    " %m 当前缓冲被修改标记
    " %m 当前缓冲只读标记
    " %h 帮助缓冲标记
    " %w 预览缓冲标记
    " %Y 文件类型
    " %b ASCII值
    " %B 十六进制值
    " %l 行数
    " %v 列数
    " %p 当前行数占总行数的的百分比
    " %L 总行数
    " %{...} 评估表达式的值，并用值代替
    " %{"[fenc=".(&fenc==""?&enc:&fenc).((exists("+bomb") && &bomb)?"+":"")."]"} 显示文件编码
    " %{&ff} 显示文件类型
    set statusline=%F%m%r%h%w
    set statusline+=%=
    set statusline+=%{StatusLineGetPos()}
    set statusline+=[%Y]
    set statusline+=%{\"[\".(&fenc==\"\"?&enc:&fenc).((exists(\"+bomb\")\ &&\ &bomb)?\"+\":\"\").\"]\"}
    set statusline+=[%{&ff}]
    set statusline+=%{SearchResultStatusLine()}

    " 设置 laststatus = 0 ，不显式状态行
    " 设置 laststatus = 1 ，仅当窗口多于一个时，显示状态行
    " 设置 laststatus = 2 ，总是显式状态行
    set laststatus=2
endfunction

function! s:GetAllFiles()
    let cmd = 'find
                \ \( -path "./.git" -prune \)
                \ -o \( -path "./.svn" -prune \)
                \ -o \( ! \(
                \     \( -type d \)
                \     -o \( -name "*.a" \)
                \     -o \( -name "*.so" \)
                \     -o \( -name "*.o" \)
                \     -o \( -name "*.pyc" \)
                \     -o \( -name "*.swp" \)
                \ \) \)'
    return cmd
endfunction

function! s:ParseTags(source_file)
    let arg = ''
    let args = {
                \'c': '--language-force=c --c-kinds=+px',
                \'cpp': '--language-force=c++ --c++-kinds=+px',
                \'python': '--language-force=python',
                \'sh': '--language-force=sh',
                \'make': '--language-force=make',
                \'vim': '--language-force=vim',
                \}
    if has_key(args, &filetype)
        let arg = args[&filetype]
    endif
    let ctags_result = system('ctags -x -f - ' . arg . ' ' . a:source_file . ' | awk "NF >= 3 {print \$1, \$3}"')
    return split(ctags_result, '\v\n+')
endfunction

function! s:GetBufferTags()
    let source_file = ''
    let result = []
    if &modified
        let source_file = tempname()
        let all_lines = getline(1, '$')
        call writefile(all_lines, source_file)
        let result = s:ParseTags(source_file)
        call delete(source_file)
    else
        let source_file = expand('%')
        let result = s:ParseTags(source_file)
    endif
    return result
endfunction

function! s:SinkGetBufferTags(lineStr)
    let record = split(a:lineStr, '\v +')
    execute record[1]
    execute 'normal! zz'
endfunction

function! s:MapLeader_lt()
    let opt = {
                \ 'source': s:GetBufferTags(),
                \ 'sink': function('s:SinkGetBufferTags'),
                \ 'down': '50%'
                \}
    call fzf#run(opt)
endfunction

function! s:GetAllTags()
    let tags = split(&l:tags, ',')
    if len(tags) == 0
        return ''
    endif
    if ! filereadable(tags[0])
        return ''
    endif
    let awk_string = 'awk '' '
                \ . ' { '
                \ . ' count = sub("' . getcwd() . '/", "", $2);'
                \ . ' sub(";.*", "", $3);'
                \ . ' if (count > 0)'
                \ . ' {'
                \ . '     print $1, $2, $3; '
                \ . ' }'
                \ . ' }'' '
    return 'cat ' . tags[0] . ' | ' . awk_string
endfunction

function! s:SinkGetAllTags(lineStr)
    let record = split(a:lineStr, '\v +')
    execute 'edit ' . record[1]
    execute record[2]
    execute 'normal! zz'
endfunction

function! s:MapLeader_la()
    let opt = {
                \ 'source': s:GetAllTags(),
                \ 'sink': function('s:SinkGetAllTags'),
                \ 'down': '50%'
                \}
    call fzf#run(opt)
endfunction

function! s:MapLeader_em()
    let ext = expand('%:e')
    let file_name = expand('%:t')
    let result = matchlist(file_name, '\v.+\.')
    if len(result) == 0
        return
    endif

    if ext ==# 'h'
        call fzf#run({
                    \'source': 'find . -name ' .result[0] . 'c -o -name ' . result[0] . 'cpp',
                    \'sink': 'e',
                    \'down': '50%'})
    elseif ext ==# 'c' || ex ==# 'cpp'
                    \'source': 'find . -name ' .result[0] . 'h',
                    \'sink': 'e',
                    \'down': '50%'})
    enddif
endfunction

function! s:MapLeader_yp()
    let @0 = expand('%:p')
    let @" = @0
    let @* = @0
endfunction

function! s:MapLeader_yn()
    let @0 = expand('%:t')
    let @" = @0
    let @* = @0
endfunction

function! s:MapLeader_f()
    let cmd = ""
    if &filetype == "c" || &filetype == "cpp"
        "let cmd = '?^\s*\(\w\+\s\+\)\{-0,1}\w\+[\* ]\+\zs\w\+\s*\(else\s\+if\s*\)\@<!(\_[^;]\{-})\(\_[^;]\)\{-}{?'
        let cmd = '?^.\{-0,}\zs\w\+\s*\(else\s\+if\s*\)\@<!(\_[^;]\{-})\(\_[^;]\)\{-}{?'
    elseif &filetype == "python"
        let cmd = '?^\s*def\s\+\zs\w\+?'
    elseif &filetype == "sh"
        let cmd = '?^\s*\zs\w\+()'
    elseif &filetype == "vim"
        let cmd = '?^func\%[tion!]\s\+\(\w:\)\=\zs\w\+\s*(?'
    else
        return
    endif
    execute "normal " . cmd . "\<cr>"
endfunction

function! s:InitMap()
    let g:mapleader = ','
    let g:maplocalleader = '-'

    inoremap jk <esc>
    cnoremap jk <esc>

    call s:InitSearchMap()

    nnoremap <leader>0 viw"0p

    nnoremap <leader>d :call <sid>MapLeader_d()<cr>
    nnoremap <leader>D :call <sid>MapLeader_D()<cr>

    nnoremap <leader>ev :e ~/.vimrc<cr>
    nnoremap <leader>em :call <sid>MapLeader_em()<cr>
    nnoremap <leader>ga :GutentagsUpdate!<cr>
    nnoremap <leader>gl :GutentagsUpdate<cr>

    nnoremap <leader>f :call <sid>MapLeader_f()<cr>

    nnoremap <leader>lf :call fzf#run({'source':<sid>GetAllFiles(), 'down':'50%', 'sink':'e'})<cr>
    nnoremap <leader>lb :Buffers<cr>
    nnoremap <leader>ll :BLines<cr>
    nnoremap <leader>lh :Helptags<cr>
    nnoremap <leader>lt :call <sid>MapLeader_lt()<cr>
    nnoremap <leader>la :call <sid>MapLeader_la()<cr>

    nnoremap <leader>yp :call <sid>MapLeader_yp()<cr>
    nnoremap <leader>yn :call <sid>MapLeader_yn()<cr>
    nnoremap <leader>w :w<cr>

    nnoremap <space> @=((foldclosed(line('.')) < 0) ? 'zc' : 'zo')<cr>

    nnoremap <c-h> <c-w>h
    nnoremap <c-j> <c-w>j
    nnoremap <c-k> <c-w>k
    nnoremap <c-l> <c-w>l
    tnoremap <c-h> <c-w>h
    tnoremap <c-j> <c-w>j
    tnoremap <c-k> <c-w>k
    tnoremap <c-l> <c-w>l
endfunction

function! s:Autocmd_SetHelpOption()
    call setwinvar(bufwinid(""), '&number', 1)
endfunction

function! s:InitAutocmd()
    call s:InitSearchAutocmd()

    augroup reg_autocmd
        autocmd!

        autocmd FileType help call <sid>Autocmd_SetHelpOption()

        " jump to function name
        autocmd FileType c,cpp nnoremap <localleader>f ?\(^\s*\(\w\+\s\+\)\{-0,1}\w\+[\* ]\+\zs\w\+\s*\(else\s\+if\s*\)\@<!(\_[^;]\{-})\(\_[^;]\)\{-}{\)\\|\(^\s*#define\s\+\zs\w\+(\)?<cr><cr>
        autocmd FileType python nnoremap <localleader>f ?^\s*def\s\+\zs\w\+?<cr>
        autocmd FileType sh nnoremap <localleader>f ?^\s*\zs\w\+()<cr>
        autocmd FileType vim nnoremap <localleader>f ?^func\%[tion!]\s\+\(\w:\)\=\zs\w\+\s*(?<cr>
    augroup END
endfunction

function! s:InitCommand()
    command! -bang -nargs=* Rg call s:RgWithLineNumber(<q-args, '', <bang>0)
    command! -bang -nargs=* -complete=dir MySearchPath call s:ChangeSearchPath(<q-args>)
endfunction

"------------ leader d ------------
function! s:cur_is_struct_member(line, col)
    let cur_col = a:col
    while cur_col != 0
        let cur_char = a:line[cur_col]
        if cur_char >=# 'a' && cur_char <=# 'z'
            let cur_col = cur_col - 1
            continue
        endif
        if cur_char >=# 'A' && cur_char <=# 'Z'
            let cur_col = cur_col - 1
            continue
        endif
        if cur_char >=# '0' && cur_char <=# '9'
            let cur_col = cur_col - 1
            continue
        endif
        if cur_char ==# '_'
            let cur_col = cur_col - 1
            continue
        endif
        break
    endwhile
    if cur_col == 0
        return 0
    endif
    if a:line[cur_col] ==# '.'
        return 1
    endif
    if a:line[cur_col] ==# '>' && a:line[cur_col - 1] ==#'-'
        return 1
    endif
    return 0
endfunction

function! s:GotoTagOfType(output_list, type, tag_name)
    let type_count = 0
    let first_line = 1
    let pos = match(a:output_list[0], 'kind')
    if pos < 0
        return 0
    endif

    for str in a:output_list
        if first_line
            let first_line = 0
            continue
        endif
        if str[pos] ==# a:type
            let type_count = type_count + 1
            let tag_index = matchstr(str, '\d\+')
        endif
    endfor
    if type_count == 1
        execute tag_index . 'tag ' . a:tag_name
        return 1
    endif
    return 0
endfunction

function! s:GotoTag(tag_name)
    execute 'redir => output'
    execute 'silent ts ' . a:tag_name
    execute 'redir END'

    let output_list = split(output, "\n")
    if len(output_list) == 0
        return
    endif
    if s:GotoTagOfType(output_list, 'f', a:tag_name)
        return
    endif
    if s:GotoTagOfType(output_list, 'm', a:tag_name)
        return
    endif
    if s:GotoTagOfType(output_list, 'c', a:tag_name)
        return
    endif
    execute "tjump " . a:tag_name
endfunction

function! s:GotoInclude(line)
    let regex_str = '#include \+["<]\(\(.\+/\)*\(.\+\.[ch]\)\)[">]'
    let match_result = matchlist(a:line, regex_str)
    if len(match_result) == 0 || match_result[2] == ''
        return 0
    endif
    call fzf#run({
                \'source':'find . -path *' . match_result[1],
                \'sink': 'e',
                \'down': '50%'})
    return 1
endfunction

function! s:GotoDefinitionC()
    let cur_line = getline(".")
    let col = getcurpos()[2]

    if s:cur_is_struct_member(cur_line, col)
        let old_line_num = line('.')
        YcmCompleter GoToDeclaration
        if old_line_num == line('.')
            call s:GotoTag(expand("<cword>"))
        endif
    elseif s:GotoInclude(cur_line)
        return
    else
        call s:GotoTag(expand("<cword>"))
    endif
endfunction

function! s:GotoDefinitionPython()
    let cur_line = getline(".")
    let col = getcurpos()[2]

    if s:cur_is_struct_member(cur_line, col)
        let old_line_num = line('.')
        YcmCompleter GoToDeclaration
        if old_line_num == line('.')
            call s:GotoTag(expand("<cword>"))
        endif
    else
        call s:GotoTag(expand("<cword>"))
    endif
endfunction

function! s:MapLeader_d()
    if &filetype == 'c' || &filetype == 'cpp'
        call s:GotoDefinitionC()
    elseif &FileType == 'python'
        call s:GotoDefinitionPython()
    else
        call s:GotoTag(expand("<cword>"))
    endif
endfunction

function! s:MapLeader_D()
    YcmCompleter GoToDeclaration
endfunction

"------------ leader d ------------

function! s:Main()
    call s:InitBase()
    call s:InitEncoding()
    call s:InitProgramming()
    call s:InitPlug()
    call s:InitMap()
    call s:InitAutocmd()
    call s:SetStatusLine()
    call s:InitCommand()
endfunction

call s:Main()
