" A small, dependable terminal fallback to Cursor.
set nocompatible
set background=dark
colorscheme solarized
let g:solarized_termtrans=1

set encoding=utf-8
set clipboard=unnamed
set backspace=indent,eol,start
set wildmenu
set hidden
set number
set relativenumber
set cursorline
set mouse=a
set scrolloff=3
set tabstop=2
set shiftwidth=2
set expandtab
set list
set listchars=tab:▸\ ,trail:·,nbsp:_
set ignorecase
set smartcase
set incsearch
set hlsearch
set noerrorbells
set nostartofline
set ruler
set title
set showcmd
set laststatus=2
set shortmess+=I
set modeline
set modelines=4
let mapleader=","

let s:state_dir=expand("~/.local/state/vim")
if !isdirectory(s:state_dir)
	call mkdir(s:state_dir, "p", 0700)
endif
for s:subdir in ["backup", "swap", "undo"]
	if !isdirectory(s:state_dir . "/" . s:subdir)
		call mkdir(s:state_dir . "/" . s:subdir, "p", 0700)
	endif
endfor
execute "set backupdir=" . s:state_dir . "/backup//"
execute "set directory=" . s:state_dir . "/swap//"
if exists("&undodir")
	execute "set undodir=" . s:state_dir . "/undo//"
	set undofile
endif
unlet s:subdir
set backup
set backupskip=/tmp/*,/private/tmp/*

syntax enable
filetype plugin indent on

function! StripWhitespace()
	let l:cursor = getpos(".")
	let l:search = getreg("/")
	%s/\s\+$//e
	call setpos(".", l:cursor)
	call setreg("/", l:search)
endfunction
noremap <leader>ss :call StripWhitespace()<CR>
noremap <leader>W :w !sudo tee % >/dev/null<CR>
