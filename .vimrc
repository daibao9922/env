let s:_tags_cache_dir = '~/tmp/cache/tags'

"######## search ##############
let s:search_result_file = tempname()
let s:search_result_list = []
let s:search_result_cur_line = 0
let s:search_result_job = job_start(":")
let s:search_result_word = ''
let s:search_path = getcwd()
let s:rg_path = '/usr/bin/rg'
let s:bash_path = '/usr/bin/bash'
let s:search_result_show = 0

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

    " setlocal autoread
    setlocal autoread
    execute 'view ' . s:search_result_file
    execute "normal /\\%$//;?^>>?2\<cr>"
    
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
    let g:gutentags_ctags_extra_args = ["--c-kinds=+p",
                \ "--fields=+iaS",
                \ "--extra=+q",
                \ "--excmd=number",
                \ "--exclude=*.vim"]
    let gutentags_define_advanced_commands = 0
    let g:gutentags_auto_add_gtags_cscope = 0
    let g:gutentags_generate_on_empty_buffer = 0
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
    call s:PlugGutentags()
    "call s:PlugYouCompleteMe()
    call s:PlugInterestingWords()
    call plug#end()
endfunction

function! StatusLineGetPos()
    let pos = getcurpos()
    let all_line_num = line('$')
    let percent = (pos[1] * 100) / all_line_num
    return '[' . string(all_line_num) . ',' . string(percent) . '%][' . string(pos[1]) . ',' . string(pos[2]) . ']'
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
    set statusline+=[ft=%Y]
    set statusline+=%{\"[fenc=\".(&fenc==\"\"?&enc:&fenc).((exists(\"+bomb\")\ &&\ &bomb)?\"+\":\"\").\"]\"}
    set statusline+=[ff=%{&ff}]
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

function! s:InitMap()
    let g:mapleader = ','
    let g:maplocalleader = '-'
    inoremap jk <esc>
    cnoremap jk <esc>

    call s:InitSearchMap()

    nnoremap <leader>ev :e ~/.vimrc<cr>

    nnoremap <leader>lf :call fzf#run({'source':<sid>GetAllFiles(), 'down':'50%', 'sink':'e'})<cr>
    nnoremap <leader>lb :Buffers<cr>
    nnoremap <leader>ll :BLines<cr>
    nnoremap <leader>lh :Helptags<cr>
    nnoremap <leader>lt :call <sid>MapLeader_lt()<cr>
    nnoremap <leader>la :call <sid>MapLeader_la()<cr>
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

function! s:Main()
    call s:InitBase()
    call s:InitEncoding()
    call s:InitProgramming()
    call s:InitPlug()
    call s:InitMap()
    call s:InitAutocmd()
    call s:SetStatusLine()
endfunction

call s:Main()
