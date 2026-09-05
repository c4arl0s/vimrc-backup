" Keep 5 lines above/below the cursor when scrolling
set scrolloff=5

" Sets how many lines of history VIM has to remember
set history=10000

" Set number line
set number

" set syntax on
syntax on

" Disable compatibility with old Vi to unlock modern Vim features
set nocompatible

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed

" Highlight searches
set hlsearch

:set cursorline

" Custom Commands
command! ToLowercaseAllFile :%s/.*/\L&/gc
command! JoinParagraph normal! vipJ

call plug#begin()

" List your plugins here
Plug 'tpope/vim-sensible'

call plug#end()
