" Author: w0rp <devw0rp@gmail.com>
" Description: Preview windows for showing whatever information in.

if !has_key(s:, 'last_list')
    let s:last_list = []
endif

if !has_key(s:, 'last_options')
    let s:last_options = {}
endif

function! ale#preview#SetLastSelection(item_list, options) abort
    let s:last_list = a:item_list
    let s:last_options = {
    \   'open_in': get(a:options, 'open_in', 'current-buffer'),
    \   'use_relative_paths': get(a:options, 'use_relative_paths', 0),
    \}
endfunction

function! ale#preview#ShowAsync(item_list, ...) abort
    let l:options = get(a:000, 0, {})
    call luaeval('require("ale.util").aleFileSelectAsync(_A)', {
        \ 'item_list': a:item_list,
        \ 'options': l:options
        \})
endfunction


" Open a preview window and show some lines in it.
" A second argument can be passed as a Dictionary with options. They are...
"
" filetype  - The filetype to use, defaulting to 'ale-preview'
" stay_here - If 1, stay in the window you came from.
function! ale#preview#Show(lines, ...) abort
    let l:options = get(a:000, 0, {})

    silent pedit ALEPreviewWindow
    wincmd P

    setlocal modifiable
    setlocal noreadonly
    setlocal nobuflisted
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    :%d
    call setline(1, a:lines)
    setlocal nomodifiable
    setlocal readonly
    let &l:filetype = get(l:options, 'filetype', 'ale-preview')

    for l:command in get(l:options, 'commands', [])
        call execute(l:command)
    endfor

    if get(l:options, 'stay_here')
        wincmd p
    endif
endfunction

" Close the preview window if the filetype matches the given one.
function! ale#preview#CloseIfTypeMatches(filetype) abort
    for l:win in getwininfo()
        let l:wintype = gettabwinvar(l:win.tabnr, l:win.winnr, '&filetype')

        if l:wintype is# a:filetype
            silent! pclose!
        endif
    endfor
endfunction

" Show a location selection preview window, given some items.
" Each item should have 'filename', 'line', and 'column' keys.
function! ale#preview#ShowSelection(item_list, ...) abort
    let l:options = get(a:000, 0, {})
    let l:sep = has('win32') ? '\' : '/'
    let l:lines = []

    " Create lines to display to users.
    for l:item in a:item_list
        let l:match = get(l:item, 'match', '')
        let l:filename = l:item.filename

        if get(l:options, 'use_relative_paths')
            let l:cwd = getcwd() " no-custom-checks
            let l:filename = substitute(l:filename, '^' . l:cwd . l:sep, '', '')
        endif

        call add(
        \   l:lines,
        \   l:filename
        \       . ':' . l:item.line
        \       . ':' . l:item.column
        \       . (!empty(l:match) ? ' ' . l:match : ''),
        \)
    endfor

    if has('nvim')
        call ale#preview#ShowAsync(a:item_list, {'filetype': 'ale-preview-selection'})
    else
        call ale#preview#Show(l:lines, {'filetype': 'ale-preview-selection'})
    endif

    let b:ale_preview_item_list = a:item_list
    let b:ale_preview_item_open_in = get(l:options, 'open_in', 'current-buffer')

    " Jump to an index for a previous selection, if set.
    if has_key(l:options, 'jump_to_index')
        let l:pos = getpos('.')
        let l:pos[1] = l:options.jump_to_index + 1
        call setpos('.', l:pos)
    endif

    " Remember preview state, so we can repeat it later.
    call ale#preview#SetLastSelection(a:item_list, l:options)
endfunction

function! ale#preview#RepeatSelection() abort
    if !empty(s:last_list)
        call ale#preview#ShowSelection(s:last_list, s:last_options)
    endif
endfunction

function! s:Open(open_in) abort
    let l:item_list = get(b:, 'ale_preview_item_list', [])
    let l:index = getpos('.')[1] - 1
    let l:item = get(l:item_list, l:index, {})

    if empty(l:item)
        return
    endif

    " Remember an index to jump to when repeating a selection.
    let s:last_options.jump_to_index = l:index

    :q!

    call ale#util#Open(
    \   l:item.filename,
    \   l:item.line,
    \   l:item.column,
    \   {'open_in': a:open_in},
    \)
endfunction

function! ale#preview#OpenSelection() abort
    call s:Open(b:ale_preview_item_open_in)
endfunction

function! ale#preview#OpenSelectionInTab() abort
    call s:Open('tab')
endfunction
