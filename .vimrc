let s:_tags_cache_dir = '~/tmp/cache/tags'
let s:_note_path_dir = '/home/bak/note'
let s:_draw_it_open = 0

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

function! s:Autocmd_BufWinEnter()
    if expand("%") ==# s:search_result_file
        if s:search_result_cur_line != 0
            call setpos(".", [0, s:search_result_cur_line, 0, 0])
        endif
        nnoremap <buffer> <cr> :call <sid>GotoResultFileCur()<cr>
    endif
endfunction

function! s:Autocmd_VimLeave()
    if filereadable(s:search_result_file)
        call delete(s:search_result_file)
    endif
endfunction

function! s:InitSearchAutocmd()
    augroup reg_search_autocmd
        autocmd!
        autocmd BufWinEnter * call <sid>Autocmd_BufWinEnter()
        autocmd VimLeave * call <sid>Autocmd_VimLeave()
    augroup END
endfunction

"######## search end ##########

function! s:InitBase()

    set clipboard=unnamed
    set mouse=a

    syntax on
    syntax enable

    set nocompatible
    set backspace=indent,eol,start
    set number
    set relativenumber
    set history=100
    set noignorecase
    set nohlsearch
    set wrap
    set noswapfile
    set nowrapscan

    " 如果修改了当前文件没有保存，切换文件的时候不提示保存
    set hidden

    " 如果最大化split窗格的话，其他窗口尽量缩到最小
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

    "自动缩进，既每行的缩进值与上一行相等
    set autoindent

    "缩进的空格数
    set shiftwidth=4

    "制表符在屏幕上显示的宽度*
    set tabstop=4
endfunction

function! s:PlugFzf()
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
endfunction

function! s:PlugDrawIt()
    Plug 'vim-scripts/DrawIt'
endfunction

function! s:PlugTerminal()
    Plug 'PangPangPangPangPang/vim-terminal'
    let g:vs_terminal_custom_height = 20
    let g:vs_terminal_custom_pos = 'top'
endfunction

function! s:PlugFugitive()
    Plug 'tpope/vim-fugitive'
endfunction

function! s:PlugCocNvim()
    Plug 'neoclide/coc.nvim', {'branch': 'release'}

    "------------------- mine ---------------------
    highlight CocErrorFloat ctermbg=39 ctermfg=0
    highlight CocWarningFloat ctermbg=39 ctermfg=0
    highlight Pmenu ctermbg=39 ctermfg=0
    highlight PmenuSel ctermbg=80 ctermfg=0

    "set statusline+=[%{coc#status()}%{get(b:,'coc_current_function', '')}]
    "------------------- mine ---------------------

    " TextEdit might fail if hidden is not set.
    set hidden

    " Some servers have issues with backup files, see #649.
    set nobackup
    set nowritebackup

    " Give more space for displaying messages.
    set cmdheight=2

    " Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
    " delays and poor user experience.
    set updatetime=300

    " Don't pass messages to |ins-completion-menu|.
    set shortmess+=c

    " Always show the signcolumn, otherwise it would shift the text each time
    " diagnostics appear/become resolved.
    if has("patch-8.1.1564")
      " Recently vim can merge signcolumn and number column into one
      set signcolumn=number
    else
      set signcolumn=yes
    endif

    " Use tab for trigger completion with characters ahead and navigate.
    " NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
    " other plugin before putting this into your config.
    "inoremap <silent><expr> <TAB>
    "      \ pumvisible() ? "\<C-n>" :
    "      \ <SID>check_back_space() ? "\<TAB>" :
    "      \ coc#refresh()
    "inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
    inoremap <silent><expr> <C-J>
          \ pumvisible() ? "\<C-n>" :
          \ <SID>check_back_space() ? "\<TAB>" :
          \ coc#refresh()
    inoremap <expr><C-K> pumvisible() ? "\<C-p>" : "\<C-h>"

    function! s:check_back_space() abort
      let col = col('.') - 1
      return !col || getline('.')[col - 1]  =~# '\s'
    endfunction

    " Use <c-space> to trigger completion.
    if has('nvim')
      inoremap <silent><expr> <c-space> coc#refresh()
    else
      inoremap <silent><expr> <c-@> coc#refresh()
    endif

    " Use <cr> to confirm completion, `<C-g>u` means break undo chain at current
    " position. Coc only does snippet and additional edit on confirm.
    " <cr> could be remapped by other vim plugin, try `:verbose imap <CR>`.
    if exists('*complete_info')
      inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
    else
      inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
    endif

    " Use `[g` and `]g` to navigate diagnostics
    " Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
    "nmap <silent> [g <Plug>(coc-diagnostic-prev)
    "nmap <silent> ]g <Plug>(coc-diagnostic-next)
    nmap <silent> g[ <Plug>(coc-diagnostic-prev)
    nmap <silent> g] <Plug>(coc-diagnostic-next)

    " GoTo code navigation.
    nmap <silent> gd <Plug>(coc-definition)
    nmap <silent> gy <Plug>(coc-type-definition)
    nmap <silent> gi <Plug>(coc-implementation)
    nmap <silent> gr <Plug>(coc-references)

    " Use K to show documentation in preview window.
    nnoremap <silent> K :call <SID>show_documentation()<CR>

    function! s:show_documentation()
      if (index(['vim','help'], &filetype) >= 0)
        execute 'h '.expand('<cword>')
      else
        call CocAction('doHover')
      endif
    endfunction

    " Highlight the symbol and its references when holding the cursor.
    " autocmd CursorHold * silent call CocActionAsync('highlight')

    " Symbol renaming.
    "nmap <leader>rn <Plug>(coc-rename)

    " Formatting selected code.
    "xmap <leader>f  <Plug>(coc-format-selected)
    "nmap <leader>f  <Plug>(coc-format-selected)

    augroup mygroup
      autocmd!
      " Setup formatexpr specified filetype(s).
      autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
      " Update signature help on jump placeholder.
      autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
    augroup end

    " Applying codeAction to the selected region.
    " Example: `<leader>aap` for current paragraph
    "xmap <leader>a  <Plug>(coc-codeaction-selected)
    "nmap <leader>a  <Plug>(coc-codeaction-selected)
    "
    "" Remap keys for applying codeAction to the current buffer.
    "nmap <leader>ac  <Plug>(coc-codeaction)
    "" Apply AutoFix to problem on the current line.
    "nmap <leader>qf  <Plug>(coc-fix-current)
    "
    "" Map function and class text objects
    "" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
    "xmap if <Plug>(coc-funcobj-i)
    "omap if <Plug>(coc-funcobj-i)
    "xmap af <Plug>(coc-funcobj-a)
    "omap af <Plug>(coc-funcobj-a)
    "xmap ic <Plug>(coc-classobj-i)
    "omap ic <Plug>(coc-classobj-i)
    "xmap ac <Plug>(coc-classobj-a)
    "omap ac <Plug>(coc-classobj-a)
    "
    "" Use CTRL-S for selections ranges.
    "" Requires 'textDocument/selectionRange' support of LS, ex: coc-tsserver
    "nmap <silent> <C-s> <Plug>(coc-range-select)
    "xmap <silent> <C-s> <Plug>(coc-range-select)
    "
    "" Add `:Format` command to format current buffer.
    "command! -nargs=0 Format :call CocAction('format')
    "
    "" Add `:Fold` command to fold current buffer.
    "command! -nargs=? Fold :call     CocAction('fold', <f-args>)
    "
    "" Add `:OR` command for organize imports of the current buffer.
    "command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

    " Add (Neo)Vim's native statusline support.
    " NOTE: Please see `:h coc-status` for integrations with external plugins that
    " provide custom statusline: lightline.vim, vim-airline.
    " set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

    " Mappings for CoCList
    " Show all diagnostics.
    "nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
    "" Manage extensions.
    "nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
    "" Show commands.
    "nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
    "" Find symbol of current document.
    "nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
    "" Search workspace symbols.
    "nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
    "" Do default action for next item.
    "nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
    "" Do default action for previous item.
    "nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
    "" Resume latest coc list.
    "nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>

endfunction

function! s:GetDefaultTagPath()
    let cur_path = getcwd()
    let tag_name = ''
    for item in split(cur_path, '/')
        let tag_name = tag_name . item . '-'
    endfor
    let tag_path = s:_tags_cache_dir . '/' . tag_name . '.tags'
    return tag_path
endfunction

" 这个函数的目的是为了解决切换到其他目录的文件时，无法访问默认tag的问题
function! s:ForceAddDefaultTag()
    let &tags = &tags . ',' . s:GetDefaultTagPath()
endfunction

function! s:PlugGutentags()
    Plug 'ludovicchabant/vim-gutentags'
    let g:gutentags_project_root = ['.git', '.svn']
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

    if isdirectory('.git') || isdirectory('.svn')
        call s:ForceAddDefaultTag()
    endif
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
    "highlight CursorLine cterm=NONE ctermbg=235
    "highlight CursorLineNr cterm=NONE ctermbg=235
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

function! s:PlugWildFire()
    Plug 'gcmt/wildfire.vim'
endfunction

function! s:PlugSurround()
    Plug 'tpope/vim-surround'
endfunction

function! s:PlugMultipleCursors()
    Plug 'mg979/vim-visual-multi'

    let g:VM_maps = {}
    let g:VM_maps['Find Under']         = '<leader>v'
    let g:VM_maps['Find Subword Under'] = '<leader>v'
endfunction

function! s:PlugUltisnips()
    Plug 'SirVer/ultisnips'

    Plug 'honza/vim-snippets'

    let g:UltiSnipsExpandTrigger="<TAB>"
    let g:UltiSnipsJumpForwardTrigger="<TAB>"
    let g:UltiSnipsJumpBackwardTrigger="<TAB>"
endfunction

function! s:InitPlug()
    call plug#begin('~/.vim/plugged')

    call s:PlugColorschemeMolokai()

    "用快捷键打开关闭quickfix窗口
    call s:PlugListToggle()

    "用快捷键打开关闭terminal窗口
    call s:PlugTerminal()

    "侧边栏显示符号
    call s:PlugTagbar()

    "侧边栏显示文件
    call s:PlugNerdTree()

    "回车按范围选中文本
    call s:PlugWildFire()

    "替换边界字符
    call s:PlugSurround()

    "多光标
    call s:PlugMultipleCursors()

    "异步执行
    call s:PlugAsyncRun()

    "模糊匹配
    call s:PlugFzf()

    "高亮单词
    call s:PlugInterestingWords()

    "文件夹比较
    call s:PlugDirDiff()

    "绘图
    call s:PlugDrawIt()

    "代码片段
    call s:PlugUltisnips()

    "自动对仓库中的代码构建tag
    call s:PlugGutentags()

    "LSP
    call s:PlugCocNvim()

    "按照4个空格显示对齐线
    call s:PlugIndentLine()

    "git
    call s:PlugFugitive()

    "call s:PlugPythonMode()

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

function! s:GetAllNoteFiles()
    let cmd = 'find ' . s:_note_path_dir . ' -path "' . s:_note_path_dir . '/.git" -prune -o ! -type d'
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
    elseif &filetype == "rust"
        let cmd = '?\<fn\s\+\zs\w\+('
    elseif &filetype == "lua"
        let cmd = '?^\s*\<function\s\+\zs\w\+('
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

    vnoremap <F5> "+y

    nnoremap <c-h> <c-w>h
    nnoremap <c-j> <c-w>j
    nnoremap <c-k> <c-w>k
    nnoremap <c-l> <c-w>l
    tnoremap <c-h> <c-w>h
    tnoremap <c-j> <c-w>j
    tnoremap <c-k> <c-w>k
    tnoremap <c-l> <c-w>l

    call s:InitSearchMap()

    nnoremap <leader>0 viw"0p

    nnoremap <leader>c :let @+ = @0<cr>

    nnoremap <leader>d :call <sid>MapLeader_d()<cr>

    nnoremap <leader>ev :e ~/.vimrc<cr>
    nnoremap <leader>eb :e ~/.bash_profile<cr>
    nnoremap <leader>em :call <sid>MapLeader_em()<cr>
    nnoremap <leader>ga :GutentagsUpdate!<cr>
    nnoremap <leader>gl :GutentagsUpdate<cr>
    nnoremap <leader>gs :UltiSnipsEdit<cr>

    nnoremap <leader>f :call <sid>MapLeader_f()<cr>

    nnoremap <leader>lf :call fzf#run({'source':<sid>GetAllFiles(), 'down':'50%', 'sink':'e'})<cr>
    nnoremap <leader>ln :call fzf#run({'source':<sid>GetAllNoteFiles(), 'down':'50%', 'sink':'e'})<cr>
    nnoremap <leader>lb :Buffers<cr>
    nnoremap <leader>ll :BLines<cr>
    nnoremap <leader>lh :Helptags<cr>
    nnoremap <leader>lt :call <sid>MapLeader_lt()<cr>
    nnoremap <leader>la :call <sid>MapLeader_la()<cr>

    nnoremap <leader>tn :set relativenumber!<cr>
    nnoremap <leader>th :set hlsearch!<cr>set hlsearch?<cr>
    nnoremap <leader>tw :set wrap!<cr>set wrap?<cr>
    nnoremap <leader>tp :set paste!<cr>:set paste?<cr>
    nnoremap <leader>tt :set TagbarToggle<cr>
    nnoremap <leader>td :set NERDTreeToggle<cr>
    nnoremap <leader>tc :set VSTerminalToggle<cr>
    nnoremap <leader>ti :call <sid>SwitchDrawIt()<cr>

    nnoremap <leader>yp :call <sid>MapLeader_yp()<cr>
    nnoremap <leader>yn :call <sid>MapLeader_yn()<cr>
    nnoremap <leader>w :w<cr>

endfunction

function! s:Autocmd_SetHelpOption()
    call setwinvar(bufwinid(""), '&number', 1)
endfunction

function! s:InitAutocmd()
    call s:InitSearchAutocmd()

    augroup reg_autocmd
        autocmd!
        autocmd FileType help call <sid>Autocmd_SetHelpOption()
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

function! s:MapLeader_d()
    call s:GotoTag(expand("<cword>"))
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
